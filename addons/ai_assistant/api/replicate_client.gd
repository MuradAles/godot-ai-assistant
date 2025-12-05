@tool
class_name ReplicateClient
extends RefCounted

## Replicate API client for pixel art generation
## Uses retro-diffusion/rd-tile for proper pixel art tiles
## Each instance handles ONE generation request (for parallel support)
##
## rd-tile styles:
## - tileset: Full tilesets from a single prompt (wang-style combinations)
## - tileset_advanced: Transitions between two terrains (uses extra_prompt)
## - single_tile: Detailed single tile texture (64x64 recommended)
## - tile_object: Small sprites like trees, rocks (up to 96x96)
## - scene_object: Large sprites like buildings (up to 384x384)

signal generation_started(prediction_id: String)
signal generation_progress(status: String)
signal generation_completed(image_data: PackedByteArray, asset_info: Dictionary)
signal generation_error(error: String)

const API_BASE := "https://api.replicate.com/v1"

# rd-tile - specialized for pixel art tile generation
const RD_TILE_MODEL := "retro-diffusion/rd-tile"

var _api_key := ""
var _node_parent: Node

# Per-instance state for this specific generation
var _prediction_id := ""
var _asset_info: Dictionary = {}


func setup(api_key: String, parent_node: Node) -> void:
	_api_key = api_key
	_node_parent = parent_node


func has_api_key() -> bool:
	return not _api_key.is_empty()


## Generate a base terrain tile
## Uses 'single_tile' for fast generation (tileset would take 30-60s)
## rd-tile supports 16-384px tiles
func generate_terrain(terrain_name: String, prompt: String, tile_size: int = 16) -> void:
	var full_prompt := prompt + ", pixel art, seamless tileable texture, top-down rpg terrain, no borders, no grid lines, continuous pattern"

	_asset_info = {
		"type": "terrain",
		"name": terrain_name,
		"file": "terrain/" + terrain_name + ".png"
	}

	# Use requested tile_size (rd-tile minimum is 16px)
	var gen_size := maxi(tile_size, 16)
	_start_prediction({
		"prompt": full_prompt,
		"style": "single_tile",
		"width": gen_size,
		"height": gen_size
	})


## Generate a transition tileset between two terrains
## Uses 'tileset_advanced' for proper wang-style transitions between two terrains
## If from_image_path and to_image_path are provided, uses them as input_image and extra_input_image
## for better matching transitions based on existing terrain textures
## Output: Wang-style tileset (4x5 grid = 20 tiles) at tile_size * 4 x tile_size * 5
## For 16px tiles: outputs 64x80 image containing 20 transition tiles
func generate_transition(from_terrain: String, to_terrain: String, prompt: String, tile_size: int = 16, from_image_path: String = "", to_image_path: String = "") -> void:
	var key := from_terrain + "_" + to_terrain

	# For tileset_advanced: prompt = first terrain, extra_prompt = second terrain
	# Add seamless/borderless instructions for clean transitions
	var from_prompt := from_terrain + " terrain, pixel art, seamless tileable, top-down rpg, no borders, no grid lines, smooth transition"
	var to_prompt := to_terrain + " terrain, pixel art, seamless tileable, top-down rpg, no borders, no grid lines, smooth transition"

	_asset_info = {
		"type": "transition",
		"name": key,
		"from": from_terrain,
		"to": to_terrain,
		"file": "terrain/" + key + ".png",
		"tile_size": tile_size  # Store for later parsing
	}

	# tileset_advanced generates a wang-style tileset (4x5 grid)
	# rd-tile minimum is 16px per tile
	var gen_size := maxi(tile_size, 16)

	var prediction_input := {
		"prompt": from_prompt,
		"extra_prompt": to_prompt,
		"style": "tileset_advanced",
		"width": gen_size,
		"height": gen_size
	}

	# If we have existing terrain images, use them for better matching transitions
	if not from_image_path.is_empty() and FileAccess.file_exists(from_image_path):
		var from_base64 := _image_to_data_uri(from_image_path)
		if not from_base64.is_empty():
			prediction_input["input_image"] = from_base64
			print("[Replicate] Using input_image from: " + from_image_path)

	if not to_image_path.is_empty() and FileAccess.file_exists(to_image_path):
		var to_base64 := _image_to_data_uri(to_image_path)
		if not to_base64.is_empty():
			prediction_input["extra_input_image"] = to_base64
			print("[Replicate] Using extra_input_image from: " + to_image_path)

	_start_prediction(prediction_input)


## Convert an image file to a data URI (base64 encoded)
func _image_to_data_uri(image_path: String) -> String:
	var file := FileAccess.open(image_path, FileAccess.READ)
	if not file:
		push_warning("[Replicate] Could not open image: " + image_path)
		return ""

	var bytes := file.get_buffer(file.get_length())
	file.close()

	var base64 := Marshalls.raw_to_base64(bytes)

	# Determine MIME type from extension
	var ext := image_path.get_extension().to_lower()
	var mime := "image/png"
	if ext == "jpg" or ext == "jpeg":
		mime = "image/jpeg"
	elif ext == "webp":
		mime = "image/webp"

	return "data:" + mime + ";base64," + base64


## Generate an object (tree, rock, etc)
## Uses 'tile_object' style - max 96x96 pixels
func generate_object(object_name: String, prompt: String, tile_size: int = 32, index: int = 1) -> void:
	var full_prompt := prompt + ", pixel art sprite, transparent background, top-down rpg asset"
	var filename := object_name + "_" + str(index).pad_zeros(2) + ".png"

	_asset_info = {
		"type": "object",
		"name": object_name,
		"index": index,
		"file": "objects/" + object_name + "/" + filename
	}

	# tile_object max is 96x96, clamp to safe values
	var obj_width := mini(tile_size * 2, 96)
	var obj_height := mini(tile_size * 2, 96)

	_start_prediction({
		"prompt": full_prompt,
		"style": "tile_object",
		"width": obj_width,
		"height": obj_height
	})


## Generate a structure (house, tower, etc)
## Uses 'scene_object' style - up to 384x384 pixels
func generate_structure(structure_name: String, prompt: String, tile_size: int = 32, index: int = 1) -> void:
	var full_prompt := prompt + ", pixel art building, transparent background, top-down rpg asset"
	var filename := structure_name + "_" + str(index).pad_zeros(2) + ".png"

	_asset_info = {
		"type": "structure",
		"name": structure_name,
		"index": index,
		"file": "structures/" + structure_name + "/" + filename
	}

	# scene_object allows larger sizes up to 384x384
	var struct_size := mini(tile_size * 4, 128)

	_start_prediction({
		"prompt": full_prompt,
		"style": "scene_object",
		"width": struct_size,
		"height": struct_size
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

	# Set longer timeout for tileset generation (120 seconds)
	http.timeout = 120.0

	# Store asset_info in http's metadata so it survives async callbacks
	http.set_meta("asset_info", _asset_info.duplicate())
	http.request_completed.connect(_on_prediction_started.bind(http))

	# Use rd-tile model endpoint
	var url := API_BASE + "/models/" + RD_TILE_MODEL + "/predictions"

	# Don't use "Prefer: wait" for tileset styles - they take too long (30-60s)
	# Instead, we'll poll for completion
	# tileset and tileset_advanced take longer, so poll instead of wait
	var style: String = input.get("style", "single_tile")
	var use_wait := style in ["single_tile", "tile_object", "scene_object"]
	# tileset_advanced can take 30-60s, must poll

	var headers := PackedStringArray([
		"Authorization: Bearer " + _api_key,
		"Content-Type: application/json"
	])
	if use_wait:
		headers.append("Prefer: wait")

	# rd-tile parameters
	var width: int = input.get("width", 32)
	var height: int = input.get("height", 32)
	# style already defined above for header decision

	# Clamp dimensions to rd-tile limits (16-384)
	width = clampi(width, 16, 384)
	height = clampi(height, 16, 384)

	var rd_tile_input := {
		"prompt": input.get("prompt", "pixel art game asset"),
		"style": style,
		"width": width,
		"height": height,
		"num_images": 1
	}

	# Add extra_prompt for tileset_advanced (terrain transitions)
	var extra_prompt: String = input.get("extra_prompt", "")
	if not extra_prompt.is_empty():
		rd_tile_input["extra_prompt"] = extra_prompt

	# Add input_image for image-to-image generation (tileset_advanced)
	var input_image: String = input.get("input_image", "")
	if not input_image.is_empty():
		rd_tile_input["input_image"] = input_image

	# Add extra_input_image for tileset_advanced (second terrain texture)
	var extra_input_image: String = input.get("extra_input_image", "")
	if not extra_input_image.is_empty():
		rd_tile_input["extra_input_image"] = extra_input_image

	var body := JSON.stringify({
		"input": rd_tile_input
	})

	# Show appropriate message based on style
	var asset_name: String = _asset_info.get("name", "asset")
	var style_msg := asset_name + ": generating..."
	if style == "tileset":
		style_msg = asset_name + ": generating wang tileset (30-60s)..."
	elif style == "tileset_advanced":
		style_msg = asset_name + ": generating transition tileset (30-60s)..."
	generation_progress.emit(style_msg)
	print("[Replicate] Calling rd-tile API for: " + str(_asset_info.get("name", "unknown")))
	print("[Replicate]   Style: " + style + ", Size: " + str(width) + "x" + str(height))
	print("[Replicate]   Using Prefer:wait = " + str(use_wait))

	var error := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		http.queue_free()
		generation_error.emit("Failed to start request: " + str(error))


func _on_prediction_started(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	# Get asset_info from http metadata
	var asset_info: Dictionary = http.get_meta("asset_info", {})
	http.queue_free()

	print("[Replicate] Response code: " + str(response_code) + " for " + str(asset_info.get("name", "unknown")))

	if result != HTTPRequest.RESULT_SUCCESS:
		print("[Replicate] HTTP failed with result: " + str(result))
		generation_error.emit("HTTP request failed: " + str(result))
		return

	if response_code != 200 and response_code != 201:
		var error_text := body.get_string_from_utf8()
		print("[Replicate] API error: " + error_text)
		generation_error.emit("API error " + str(response_code) + ": " + error_text.left(200))
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		print("[Replicate] Failed to parse JSON response")
		generation_error.emit("Failed to parse response")
		return

	var data: Dictionary = json.data
	var status: String = data.get("status", "")
	var prediction_id: String = data.get("id", "")

	print("[Replicate] Prediction status: " + status + ", id: " + prediction_id + " for " + str(asset_info.get("name", "")))
	generation_started.emit(prediction_id)

	# Check if already completed (with Prefer: wait header)
	if status == "succeeded":
		_handle_success(data, asset_info)
	elif status == "failed" or status == "canceled":
		var err_msg: String = str(data.get("error", "Unknown"))
		print("[Replicate] Generation failed: " + err_msg)
		generation_error.emit("Generation " + status + ": " + err_msg)
	else:
		# Need to poll - pass asset_info and prediction_id
		var name_str: String = asset_info.get("name", "asset")
		generation_progress.emit(name_str + ": " + status + "...")
		_poll_after_delay(2.0, prediction_id, asset_info)


func _poll_after_delay(seconds: float, prediction_id: String, asset_info: Dictionary) -> void:
	if not _node_parent or not is_instance_valid(_node_parent):
		return

	var timer := _node_parent.get_tree().create_timer(seconds)
	timer.timeout.connect(_poll_prediction.bind(prediction_id, asset_info))


func _poll_prediction(prediction_id: String, asset_info: Dictionary) -> void:
	if prediction_id.is_empty():
		return

	if not _node_parent or not is_instance_valid(_node_parent):
		generation_error.emit("Parent node invalid")
		return

	var http := HTTPRequest.new()
	_node_parent.add_child(http)
	http.set_meta("asset_info", asset_info)
	http.set_meta("prediction_id", prediction_id)
	http.request_completed.connect(_on_poll_result.bind(http))

	var url := API_BASE + "/predictions/" + prediction_id
	var headers := PackedStringArray([
		"Authorization: Bearer " + _api_key
	])

	http.request(url, headers, HTTPClient.METHOD_GET)


func _on_poll_result(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	var asset_info: Dictionary = http.get_meta("asset_info", {})
	var prediction_id: String = http.get_meta("prediction_id", "")
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

	var name_str: String = asset_info.get("name", "asset")

	match status:
		"succeeded":
			_handle_success(data, asset_info)
		"failed", "canceled":
			generation_error.emit("Generation " + status + ": " + str(data.get("error", "Unknown")))
		_:
			generation_progress.emit(name_str + ": " + status + "...")
			_poll_after_delay(2.0, prediction_id, asset_info)


func _handle_success(data: Dictionary, asset_info: Dictionary) -> void:
	var output = data.get("output")
	var image_url := ""

	print("[Replicate] Generation succeeded for: " + str(asset_info.get("name", "unknown")))

	# rd-tile returns output as array of URLs
	if output is Array and output.size() > 0:
		image_url = output[0]
	elif output is String:
		image_url = output

	if image_url.is_empty():
		print("[Replicate] No output URL found in response")
		generation_error.emit("No output image URL")
		return

	print("[Replicate] Downloading from: " + image_url.left(80) + "...")
	generation_progress.emit("Downloading image...")
	_download_image(image_url, asset_info)


func _download_image(url: String, asset_info: Dictionary) -> void:
	if not _node_parent or not is_instance_valid(_node_parent):
		generation_error.emit("Parent node invalid")
		return

	var http := HTTPRequest.new()
	_node_parent.add_child(http)
	http.set_meta("asset_info", asset_info)
	http.request_completed.connect(_on_image_downloaded.bind(http))

	var error := http.request(url)
	if error != OK:
		http.queue_free()
		print("[Replicate] Download request failed: " + str(error))
		generation_error.emit("Failed to download image")


func _on_image_downloaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	var asset_info: Dictionary = http.get_meta("asset_info", {})
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[Replicate] Download failed: result=" + str(result) + ", code=" + str(response_code))
		generation_error.emit("Download failed: " + str(response_code))
		return

	print("[Replicate] Image downloaded for " + str(asset_info.get("name", "unknown")) + ", size: " + str(body.size()) + " bytes")
	generation_completed.emit(body, asset_info)


func cancel() -> void:
	_prediction_id = ""
	_asset_info = {}
