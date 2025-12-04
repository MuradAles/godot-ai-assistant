@tool
class_name AssetManager
extends RefCounted

## Manages the asset manifest - adds/removes assets dynamically based on chat

const MANIFEST_PATH := "res://assets/manifest.json"
const ASSETS_ROOT := "res://assets/"

signal manifest_changed

var _manifest: Dictionary = {}


func _init() -> void:
	load_manifest()


func load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_manifest = _create_empty_manifest()
		save_manifest()
		return

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not file:
		_manifest = _create_empty_manifest()
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_manifest = json.data
	else:
		_manifest = _create_empty_manifest()


func save_manifest() -> void:
	_ensure_dir(ASSETS_ROOT)

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_manifest, "\t"))
		file.close()


func _create_empty_manifest() -> Dictionary:
	return {
		"version": "1.0",
		"style": "retro pixel art",
		"tile_size": 32,
		"terrain": {},
		"transitions": {},
		"objects": {},
		"structures": {}
	}


## Clear all assets from manifest (for new world)
func clear() -> void:
	_manifest = _create_empty_manifest()
	save_manifest()
	manifest_changed.emit()


## Add a terrain type needed for this world
func add_terrain(name: String, prompt: String) -> void:
	_manifest.terrain[name] = {
		"generated": false,
		"file": "terrain/" + name + ".png",
		"prompt": prompt
	}
	save_manifest()
	manifest_changed.emit()


## Add a transition between two terrains
func add_transition(from_terrain: String, to_terrain: String, prompt: String) -> void:
	var key := from_terrain + "_" + to_terrain
	_manifest.transitions[key] = {
		"generated": false,
		"file": "terrain/" + key + ".png",
		"prompt": prompt,
		"from": from_terrain,
		"to": to_terrain
	}
	save_manifest()
	manifest_changed.emit()


## Add an object type (trees, rocks, etc)
func add_object(name: String, prompt: String, count: int = 1) -> void:
	if _manifest.objects.has(name):
		_manifest.objects[name].needed += count
	else:
		_manifest.objects[name] = {
			"generated": 0,
			"needed": count,
			"folder": "objects/" + name,
			"prompt": prompt
		}
	save_manifest()
	manifest_changed.emit()


## Add a structure type (houses, towers, etc)
func add_structure(name: String, prompt: String, count: int = 1) -> void:
	if _manifest.structures.has(name):
		_manifest.structures[name].needed += count
	else:
		_manifest.structures[name] = {
			"generated": 0,
			"needed": count,
			"folder": "structures/" + name,
			"prompt": prompt
		}
	save_manifest()
	manifest_changed.emit()


## Mark a terrain as generated
func mark_terrain_generated(name: String) -> void:
	if _manifest.terrain.has(name):
		_manifest.terrain[name].generated = true
		save_manifest()
		manifest_changed.emit()


## Mark a transition as generated
func mark_transition_generated(from_terrain: String, to_terrain: String) -> void:
	var key := from_terrain + "_" + to_terrain
	if _manifest.transitions.has(key):
		_manifest.transitions[key].generated = true
		save_manifest()
		manifest_changed.emit()


## Mark an object as generated (increment count)
func mark_object_generated(name: String) -> void:
	if _manifest.objects.has(name):
		_manifest.objects[name].generated += 1
		save_manifest()
		manifest_changed.emit()


## Mark a structure as generated (increment count)
func mark_structure_generated(name: String) -> void:
	if _manifest.structures.has(name):
		_manifest.structures[name].generated += 1
		save_manifest()
		manifest_changed.emit()


## Get all terrains
func get_terrains() -> Dictionary:
	return _manifest.terrain.duplicate()


## Get all transitions
func get_transitions() -> Dictionary:
	return _manifest.transitions.duplicate()


## Get all objects
func get_objects() -> Dictionary:
	return _manifest.objects.duplicate()


## Get all structures
func get_structures() -> Dictionary:
	return _manifest.structures.duplicate()


## Get the tile size
func get_tile_size() -> int:
	return _manifest.get("tile_size", 32)


## Get the style
func get_style() -> String:
	return _manifest.get("style", "retro pixel art")


## Set the style
func set_style(style: String) -> void:
	_manifest.style = style
	save_manifest()


## Check if any assets are needed
func has_pending_assets() -> bool:
	for t in _manifest.terrain.values():
		if not t.generated:
			return true
	for t in _manifest.transitions.values():
		if not t.generated:
			return true
	for o in _manifest.objects.values():
		if o.generated < o.needed:
			return true
	for s in _manifest.structures.values():
		if s.generated < s.needed:
			return true
	return false


## Get count of pending assets
func get_pending_count() -> int:
	var count := 0
	for t in _manifest.terrain.values():
		if not t.generated:
			count += 1
	for t in _manifest.transitions.values():
		if not t.generated:
			count += 1
	for o in _manifest.objects.values():
		count += max(0, o.needed - o.generated)
	for s in _manifest.structures.values():
		count += max(0, s.needed - s.generated)
	return count


## Ensure a directory exists
func _ensure_dir(path: String) -> void:
	var dir := DirAccess.open("res://")
	if dir:
		var relative := path.replace("res://", "")
		if not dir.dir_exists(relative):
			dir.make_dir_recursive(relative)


## Create folder for an asset type when generating
func ensure_asset_folder(asset_path: String) -> void:
	var folder := asset_path.get_base_dir()
	_ensure_dir(ASSETS_ROOT + folder)


## Get full path for an asset file
func get_asset_path(relative_path: String) -> String:
	return ASSETS_ROOT + relative_path
