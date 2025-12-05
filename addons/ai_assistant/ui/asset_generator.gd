@tool
class_name AssetGenerator
extends RefCounted

## Handles asset generation using Replicate API with parallel support

signal generation_status_changed(status: String)
signal asset_saved(file_path: String)
signal generation_error(error: String)
signal assets_refreshed

var _asset_manager: RefCounted
var _replicate_key := ""
var _parent_node: Node  # Node to attach HTTP requests to

# Parallel generation state
var _active_generations: int = 0
var _max_parallel: int = 5
var _active_clients: Array = []


func setup(asset_manager: RefCounted, parent_node: Node) -> void:
	_asset_manager = asset_manager
	_parent_node = parent_node


func set_replicate_key(key: String) -> void:
	_replicate_key = key


func has_replicate_key() -> bool:
	return not _replicate_key.is_empty()


func get_active_count() -> int:
	return _active_generations


## Start a single asset generation
func generate_single(name: String, data: Dictionary, asset_type: String) -> bool:
	if _replicate_key.is_empty():
		generation_error.emit("Set Replicate API key in Settings!")
		return false

	# Terrain tiles are extracted from transitions
	if asset_type == "terrain":
		generation_error.emit("Terrains are extracted from transitions automatically!")
		return false

	_start_generation(name, data, asset_type)
	return true


## Regenerate an existing asset
func regenerate(name: String, data: Dictionary, asset_type: String) -> bool:
	if _replicate_key.is_empty():
		generation_error.emit("Set Replicate API key in Settings!")
		return false

	if asset_type == "terrain":
		generation_error.emit("Terrains are extracted from transitions. Regenerate the transition instead!")
		return false

	# Reset the generated flag in manifest
	if _asset_manager:
		match asset_type:
			"transition":
				var from_t: String = data.get("from", "")
				var to_t: String = data.get("to", "")
				_asset_manager.reset_transition(from_t, to_t)
				_asset_manager.reset_terrain(from_t)
				_asset_manager.reset_terrain(to_t)
			"object":
				_asset_manager.reset_object(name)
			"structure":
				_asset_manager.reset_structure(name)

	_start_generation(name, data, asset_type)
	return true


## Generate all pending assets
func generate_all() -> int:
	if _replicate_key.is_empty():
		generation_error.emit("Set Replicate API key in Settings first!")
		return 0

	if not _asset_manager:
		return 0

	var started := 0

	# Transitions (will also extract terrain tiles)
	for key in _asset_manager.get_transitions():
		var data: Dictionary = _asset_manager.get_transitions()[key]
		if not data.get("generated", false):
			_start_generation(key, data, "transition")
			started += 1

	# Objects
	for key in _asset_manager.get_objects():
		var data: Dictionary = _asset_manager.get_objects()[key]
		var generated: int = data.get("generated", 0)
		var needed: int = data.get("needed", 1)
		for i in range(generated, needed):
			var data_copy := data.duplicate()
			data_copy["generated"] = i
			_start_generation(key, data_copy, "object")
			started += 1

	# Structures
	for key in _asset_manager.get_structures():
		var data: Dictionary = _asset_manager.get_structures()[key]
		var generated: int = data.get("generated", 0)
		var needed: int = data.get("needed", 1)
		for i in range(generated, needed):
			var data_copy := data.duplicate()
			data_copy["generated"] = i
			_start_generation(key, data_copy, "structure")
			started += 1

	return started


func _start_generation(name: String, data: Dictionary, asset_type: String) -> void:
	var RCScript = load("res://addons/ai_assistant/api/replicate_client.gd")
	if not RCScript:
		generation_error.emit("Failed to load Replicate client")
		return

	var client: RefCounted = RCScript.new()
	_active_clients.append(client)

	client.generation_progress.connect(_on_progress)
	client.generation_completed.connect(_on_completed.bind(client))
	client.generation_error.connect(_on_error.bind(client))
	client.setup(_replicate_key, _parent_node)

	_active_generations += 1
	_update_status()

	var prompt: String = data.get("prompt", name)
	var tile_size: int = _asset_manager.get_tile_size() if _asset_manager else 32

	match asset_type:
		"terrain":
			client.generate_terrain(name, prompt, tile_size)
		"transition":
			var from_t: String = data.get("from", "")
			var to_t: String = data.get("to", "")
			var from_image := ""
			var to_image := ""
			if _asset_manager:
				var terrains: Dictionary = _asset_manager.get_terrains()
				if terrains.has(from_t):
					var from_data: Dictionary = terrains[from_t]
					if from_data.get("generated", false):
						var from_file: String = from_data.get("file", "")
						from_image = _asset_manager.get_asset_path(from_file)
				if terrains.has(to_t):
					var to_data: Dictionary = terrains[to_t]
					if to_data.get("generated", false):
						var to_file: String = to_data.get("file", "")
						to_image = _asset_manager.get_asset_path(to_file)
			client.generate_transition(from_t, to_t, prompt, tile_size, from_image, to_image)
		"object":
			var idx: int = data.get("generated", 0) + 1
			client.generate_object(name, prompt, tile_size, idx)
		"structure":
			var idx: int = data.get("generated", 0) + 1
			client.generate_structure(name, prompt, tile_size, idx)


func _update_status() -> void:
	if _active_generations > 0:
		generation_status_changed.emit("Generating... (" + str(_active_generations) + " active)")
	else:
		var pending: int = _asset_manager.get_pending_count() if _asset_manager else 0
		if pending > 0:
			generation_status_changed.emit(str(pending) + " assets to generate")
		else:
			generation_status_changed.emit("All assets generated!")


func _on_progress(status: String) -> void:
	generation_status_changed.emit(status)


func _on_completed(image_data: PackedByteArray, asset_info: Dictionary, client: RefCounted) -> void:
	var idx := _active_clients.find(client)
	if idx >= 0:
		_active_clients.remove_at(idx)

	_active_generations = max(0, _active_generations - 1)

	var asset_type: String = asset_info.get("type", "")
	var asset_name: String = asset_info.get("name", "")
	var file_path: String = asset_info.get("file", "")

	if file_path.is_empty():
		generation_error.emit("No file path for asset")
		_update_status()
		assets_refreshed.emit()
		return

	# Build absolute path
	var full_path := "res://assets/" + file_path
	var abs_path := ProjectSettings.globalize_path(full_path)

	# Ensure folder exists
	var folder_abs := abs_path.get_base_dir()
	var dir := DirAccess.open(ProjectSettings.globalize_path("res://"))
	if dir:
		if not dir.dir_exists(folder_abs):
			dir.make_dir_recursive(folder_abs)

	# Save file
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	if not file:
		generation_error.emit("Failed to save: " + file_path)
		_update_status()
		assets_refreshed.emit()
		return

	file.store_buffer(image_data)
	file.close()

	# Update manifest
	if _asset_manager:
		match asset_type:
			"terrain":
				_asset_manager.mark_terrain_generated(asset_name)
			"transition":
				var from_t: String = asset_info.get("from", "")
				var to_t: String = asset_info.get("to", "")
				_asset_manager.mark_transition_generated(from_t, to_t)
				_extract_terrains_from_transition(image_data, from_t, to_t)
			"object":
				_asset_manager.mark_object_generated(asset_name)
			"structure":
				_asset_manager.mark_structure_generated(asset_name)

	asset_saved.emit(file_path)
	_update_status()
	assets_refreshed.emit()


func _on_error(error: String, client: RefCounted) -> void:
	var idx := _active_clients.find(client)
	if idx >= 0:
		_active_clients.remove_at(idx)

	_active_generations = max(0, _active_generations - 1)
	generation_error.emit(error)
	_update_status()
	assets_refreshed.emit()


## Extract pure terrain tiles from a transition tileset (4x5 wang grid)
## rd-tile tileset_advanced layout:
##   - Top-left (0,0) = pure "extra_prompt" terrain (the "to" terrain)
##   - Bottom-right (3,4) = pure "prompt" terrain (the "from" terrain)
func _extract_terrains_from_transition(image_data: PackedByteArray, from_terrain: String, to_terrain: String) -> void:
	var img := Image.new()
	var err := img.load_png_from_buffer(image_data)
	if err != OK:
		print("[Assets] Failed to load transition image for extraction")
		return

	var tile_w: int = img.get_width() / 4
	var tile_h: int = img.get_height() / 5

	print("[Assets] Extracting terrains from transition, tile size: ", tile_w, "x", tile_h)

	# rd-tile puts "prompt" (from_terrain) at BOTTOM-RIGHT (3,4)
	# and "extra_prompt" (to_terrain) at TOP-LEFT (0,0)
	_extract_and_save_terrain_tile(img, to_terrain, 0, 0, tile_w, tile_h)
	_extract_and_save_terrain_tile(img, from_terrain, 3, 4, tile_w, tile_h)


func _extract_and_save_terrain_tile(tileset_img: Image, terrain_name: String, col: int, row: int, tile_w: int, tile_h: int) -> void:
	if _asset_manager:
		var terrains: Dictionary = _asset_manager.get_terrains()
		if terrains.has(terrain_name):
			var terrain_data: Dictionary = terrains[terrain_name]
			if terrain_data.get("generated", false):
				print("[Assets] Terrain already generated, skipping: ", terrain_name)
				return

	var tile_img := Image.create(tile_w, tile_h, false, tileset_img.get_format())

	var src_x := col * tile_w
	var src_y := row * tile_h

	for py in range(tile_h):
		for px in range(tile_w):
			if src_x + px < tileset_img.get_width() and src_y + py < tileset_img.get_height():
				var pixel := tileset_img.get_pixel(src_x + px, src_y + py)
				tile_img.set_pixel(px, py, pixel)

	var terrain_path := "res://assets/terrain/" + terrain_name + ".png"
	var abs_path := ProjectSettings.globalize_path(terrain_path)

	var folder_abs := abs_path.get_base_dir()
	var dir := DirAccess.open(ProjectSettings.globalize_path("res://"))
	if dir:
		if not dir.dir_exists(folder_abs):
			dir.make_dir_recursive(folder_abs)

	var save_err := tile_img.save_png(abs_path)
	if save_err != OK:
		print("[Assets] Failed to save extracted terrain: ", terrain_name, " error: ", save_err)
		return

	print("[Assets] Extracted terrain from transition: ", terrain_name)

	if _asset_manager:
		_asset_manager.mark_terrain_generated(terrain_name)
