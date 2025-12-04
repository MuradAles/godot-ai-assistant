@tool
class_name ReplicateClient
extends RefCounted

## Replicate API client for Retro Diffusion tile generation
## Uses rd-tile for tilesets, transitions, and objects

signal generation_started(prediction_id: String)
signal generation_progress(status: String)
signal generation_completed(image_data: PackedByteArray, asset_info: Dictionary)
signal generation_error(error: String)

const API_BASE := "https://api.replicate.com/v1"

# rd-tile model - use model name for latest version
const RD_TILE_MODEL := "retro-diffusion/rd-tile"

var _api_key := ""
var _node_parent: Node
var _current_prediction_id := ""
var _current_asset_info: Dictionary = {}


func setup(api_key: String, parent_node: Node) -> void:
	_api_key = api_key
	_node_parent = parent_node


func has_api_key() -> bool:
	return not _api_key.is_empty()


## Generate a base terrain tileset
func generate_terrain(terrain_name: String, prompt: String, tile_size: int = 32) -> void:
	var full_prompt := prompt + ", seamless tile texture, top-down 2D RPG, pixel art, game asset"

	_current_asset_info = {
		"type": "terrain",
		"name": terrain_name,
		"file": "terrain/" + terrain_name + ".png"
	}

	# Don't specify style - let API use default
	_start_prediction({
		"prompt": full_prompt,
		"width": tile_size,
		"height": tile_size
	})


## Generate a transition tileset between two terrains
func generate_transition(from_terrain: String, to_terrain: String, prompt: String, tile_size: int = 32) -> void:
	var key := from_terrain + "_" + to_terrain
	var full_prompt := from_terrain + " blending into " + to_terrain + ", terrain transition edge, seamless tile, top-down 2D RPG, pixel art, game asset"

	_current_asset_info = {
		"type": "transition",
		"name": key,
		"from": from_terrain,
		"to": to_terrain,
		"file": "terrain/" + key + ".png"
	}

	_start_prediction({
		"prompt": full_prompt,
		"width": tile_size,
		"height": tile_size
	})


## Generate an object (tree, rock, etc)
func generate_object(object_name: String, prompt: String, tile_size: int = 32, index: int = 1) -> void:
	var full_prompt := prompt + ", single game sprite, top-down 2D RPG, pixel art, transparent background"
	var filename := object_name + "_" + str(index).pad_zeros(2) + ".png"

	_current_asset_info = {
		"type": "object",
		"name": object_name,
		"index": index,
		"file": "objects/" + object_name + "/" + filename
	}

	_start_prediction({
		"prompt": full_prompt,
		"width": tile_size,
		"height": tile_size * 2
	})


## Generate a structure (house, tower, etc)
func generate_structure(structure_name: String, prompt: String, tile_size: int = 32, index: int = 1) -> void:
	var full_prompt := prompt + ", building game sprite, top-down 2D RPG, pixel art, transparent background"
	var filename := structure_name + "_" + str(index).pad_zeros(2) + ".png"

	_current_asset_info = {
		"type": "structure",
		"name": structure_name,
		"index": index,
		"file": "structures/" + structure_name + "/" + filename
	}

	_start_prediction({
		"prompt": full_prompt,
		"width": tile_size * 2,
		"height": tile_size * 2
	})


func _start_prediction(input: Dictionary) -> void:
	if _api_key.is_empty():
		generation_error.emit("No Replicate API key set")
		return

	if not _node_parent or not is_instance_valid(_node_parent):
		generation_error.emit("No parent node for HTTP requests")
		return

	var http := HTTPRequest.new()
	_node_parent.add_child(http)
	http.request_completed.connect(_on_prediction_started.bind(http))

	# Use model endpoint for latest version
	var url := API_BASE + "/models/" + RD_TILE_MODEL + "/predictions"
	var headers := PackedStringArray([
		"Authorization: Bearer " + _api_key,
		"Content-Type: application/json",
		"Prefer: wait"
	])

	var body := JSON.stringify({
		"input": input
	})

	generation_progress.emit("Starting generation...")
	var error := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		http.queue_free()
		generation_error.emit("Failed to start request: " + str(error))


func _on_prediction_started(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		generation_error.emit("HTTP request failed: " + str(result))
		return

	if response_code != 200 and response_code != 201:
		var error_text := body.get_string_from_utf8()
		generation_error.emit("API error " + str(response_code) + ": " + error_text.left(200))
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		generation_error.emit("Failed to parse response")
		return

	var data: Dictionary = json.data
	var status: String = data.get("status", "")
	_current_prediction_id = data.get("id", "")

	generation_started.emit(_current_prediction_id)

	# Check if already completed (with Prefer: wait header)
	if status == "succeeded":
		_handle_success(data)
	elif status == "failed" or status == "canceled":
		generation_error.emit("Generation " + status + ": " + str(data.get("error", "Unknown")))
	else:
		# Need to poll
		generation_progress.emit("Processing...")
		_poll_after_delay(2.0)


func _poll_after_delay(seconds: float) -> void:
	if not _node_parent or not is_instance_valid(_node_parent):
		return

	var timer := _node_parent.get_tree().create_timer(seconds)
	timer.timeout.connect(_poll_prediction)


func _poll_prediction() -> void:
	if _current_prediction_id.is_empty():
		return

	if not _node_parent or not is_instance_valid(_node_parent):
		generation_error.emit("Parent node invalid")
		return

	var http := HTTPRequest.new()
	_node_parent.add_child(http)
	http.request_completed.connect(_on_poll_result.bind(http))

	var url := API_BASE + "/predictions/" + _current_prediction_id
	var headers := PackedStringArray([
		"Authorization: Bearer " + _api_key
	])

	http.request(url, headers, HTTPClient.METHOD_GET)


func _on_poll_result(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		generation_error.emit("Poll failed: " + str(response_code))
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		generation_error.emit("Failed to parse poll response")
		return

	var data: Dictionary = json.data
	var status: String = data.get("status", "")

	match status:
		"succeeded":
			_handle_success(data)
		"failed", "canceled":
			generation_error.emit("Generation " + status + ": " + str(data.get("error", "Unknown")))
		_:
			generation_progress.emit("Processing... (" + status + ")")
			_poll_after_delay(2.0)


func _handle_success(data: Dictionary) -> void:
	var output = data.get("output")
	var image_url := ""

	if output is Array and output.size() > 0:
		image_url = output[0]
	elif output is String:
		image_url = output

	if image_url.is_empty():
		generation_error.emit("No output image URL")
		return

	generation_progress.emit("Downloading image...")
	_download_image(image_url)


func _download_image(url: String) -> void:
	if not _node_parent or not is_instance_valid(_node_parent):
		generation_error.emit("Parent node invalid")
		return

	var http := HTTPRequest.new()
	_node_parent.add_child(http)
	http.request_completed.connect(_on_image_downloaded.bind(http))
	http.request(url)


func _on_image_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		generation_error.emit("Download failed: " + str(response_code))
		return

	generation_completed.emit(body, _current_asset_info)
	_current_prediction_id = ""
	_current_asset_info = {}


func cancel() -> void:
	_current_prediction_id = ""
	_current_asset_info = {}
