@tool
class_name WorldBuilder
extends RefCounted

## Handles world creation, AI actions, and game state management

signal world_created(path: String)
signal action_executed(action: String, params: Dictionary)
signal status_message(text: String, color: Color)

var _asset_manager: RefCounted
var _game_state: RefCounted
var _script_validator: RefCounted
var _current_world_path := ""

# AI-Driven Conversation State - AI provides all values
var _pending_world := {
	"name": "",
	"theme": "",  # AI provides theme (e.g., "mars", "underwater", "medieval")
	"terrains": [],  # [{name, prompt}] in elevation order
	"size": "medium",
	"objects": [],  # [{name, prompt, count}]
	"features": []
}


func setup(asset_manager: RefCounted, game_state: RefCounted, script_validator: RefCounted) -> void:
	_asset_manager = asset_manager
	_game_state = game_state
	_script_validator = script_validator


func get_pending_world() -> Dictionary:
	return _pending_world


func get_current_world_path() -> String:
	return _current_world_path


## Execute an AI decision
func execute_decision(decision: Dictionary) -> void:
	var action: String = decision.get("action", "chat")
	var params: Dictionary = decision.get("params", {})

	match action:
		"create_world":
			_execute_create_world(params)
		"update_world":
			_execute_update_world(params)
		"finalize_world":
			_execute_finalize_world()
		"add_object":
			_execute_add_object(params)
		"add_character":
			_execute_add_character(params)
		"generate_mechanic":
			action_executed.emit(action, params)
		"run_game":
			action_executed.emit(action, params)
		"chat":
			pass
		_:
			status_message.emit("Unknown action: " + action, Color.YELLOW)


## AI decided to start creating a world
## AI provides: {name, theme, terrains, size, objects, features}
func _execute_create_world(params: Dictionary) -> void:
	_pending_world = {
		"name": params.get("name", ""),
		"theme": params.get("theme", ""),
		"terrains": params.get("terrains", []),
		"size": params.get("size", "medium"),
		"objects": params.get("objects", []),
		"features": params.get("features", [])
	}
	var world_name: String = _pending_world.name if not _pending_world.name.is_empty() else "New World"
	status_message.emit("World configuration started: " + world_name, Color.CYAN)


## AI decided to update the world being built
## Terrains can be strings OR dictionaries with {name, prompt}
func _execute_update_world(params: Dictionary) -> void:
	var new_name: String = params.get("name", "")
	if not new_name.is_empty():
		_pending_world.name = new_name

	var new_theme: String = params.get("theme", "")
	if not new_theme.is_empty():
		_pending_world.theme = new_theme

	var new_size: String = params.get("size", "")
	if not new_size.is_empty():
		_pending_world.size = new_size

	# Terrains can be strings OR {name: "terrain", prompt: "description"}
	var new_terrains: Array = params.get("terrains", [])
	for t in new_terrains:
		var terrain_name: String = ""
		var terrain_prompt: String = ""

		if t is String:
			terrain_name = t
		elif t is Dictionary:
			terrain_name = t.get("name", "")
			terrain_prompt = t.get("prompt", "")

		if terrain_name.is_empty():
			continue

		# Check if terrain already exists
		var found := false
		for existing in _pending_world.terrains:
			var existing_name: String = existing if existing is String else existing.get("name", "")
			if existing_name == terrain_name:
				found = true
				break

		if not found:
			# Store as dict if prompt provided, otherwise just name
			if terrain_prompt.is_empty():
				_pending_world.terrains.append(terrain_name)
			else:
				_pending_world.terrains.append({"name": terrain_name, "prompt": terrain_prompt})
			status_message.emit("Added terrain: " + terrain_name, Color.CYAN)

	var new_objects: Array = params.get("objects", [])
	for obj in new_objects:
		if obj not in _pending_world.objects:
			_pending_world.objects.append(obj)
			status_message.emit("Added object: " + str(obj), Color.CYAN)

	var new_features: Array = params.get("features", [])
	for f in new_features:
		if f not in _pending_world.features:
			_pending_world.features.append(f)
			status_message.emit("Added feature: " + str(f), Color.CYAN)


## AI decided to finalize and create the world
## NO hardcoded assumptions - AI provides everything:
## - terrains: [{name, prompt}] in elevation order (first = lowest, last = highest)
## - objects: [{name, prompt, count}] with AI-generated prompts
## - transitions: auto-generated between adjacent terrains only
func _execute_finalize_world() -> void:
	status_message.emit("Creating world...", Color.CYAN)

	# AI must provide terrains - no fallback
	if _pending_world.terrains.is_empty():
		status_message.emit("No terrains specified! AI must provide terrain data.", Color.RED)
		return

	var size: int = 128
	match _pending_world.size:
		"small": size = 64
		"medium": size = 128
		"large": size = 256

	if _asset_manager:
		_asset_manager.clear()

	# Extract terrain data - AI provides order (array order = elevation order)
	# AI MUST provide prompts - no hardcoded fallbacks
	var terrain_names: Array[String] = []
	var terrain_prompts: Dictionary = {}  # name -> prompt

	for t in _pending_world.get("terrains", []):
		var terrain_name: String = ""
		var terrain_prompt: String = ""

		if t is String:
			terrain_name = t
			# AI didn't provide prompt - use generic description
			terrain_prompt = terrain_name + " terrain, top-down view"
		elif t is Dictionary:
			terrain_name = t.get("name", "")
			terrain_prompt = t.get("prompt", terrain_name + " terrain, top-down view")

		if not terrain_name.is_empty():
			terrain_names.append(terrain_name)
			terrain_prompts[terrain_name] = terrain_prompt

	# Add terrains to manifest (order preserved from AI)
	if _asset_manager:
		_asset_manager.set_terrain_order(terrain_names)

		for terrain_name in terrain_names:
			var terrain_prompt: String = terrain_prompts.get(terrain_name, "")
			_asset_manager.add_terrain(terrain_name, terrain_prompt)
			status_message.emit("Terrain: " + terrain_name, Color.CYAN)

		# Add transitions between adjacent terrains only
		var terrain_count: int = terrain_names.size()
		for i in range(terrain_count - 1):
			var from_t: String = terrain_names[i]
			var to_t: String = terrain_names[i + 1]
			var trans_prompt: String = from_t + " to " + to_t + " transition, top-down view"
			_asset_manager.add_transition(from_t, to_t, trans_prompt)

		# Add objects - AI provides name and optionally prompt/count
		var objects_array: Array = _pending_world.get("objects", [])
		for obj in objects_array:
			var obj_name: String = ""
			var obj_prompt: String = ""
			var obj_count: int = 5

			if obj is String:
				obj_name = obj
				obj_prompt = obj + ", top-down view, game sprite"
			elif obj is Dictionary:
				obj_name = obj.get("name", "")
				obj_prompt = obj.get("prompt", obj_name + ", top-down view, game sprite")
				obj_count = obj.get("count", 5)

			if not obj_name.is_empty():
				_asset_manager.add_object(obj_name, obj_prompt, obj_count)

	var world_name: String = _pending_world.get("name", "Untitled")
	var world_theme: String = _pending_world.get("theme", "plains")
	var world_terrains: Array[String] = terrain_names
	var world_objects: Array = _pending_world.get("objects", [])

	_create_world_folder(world_name, world_theme, world_terrains)

	if _game_state:
		_game_state.set_world({
			"width": size,
			"height": size,
			"seed": 0,
			"theme": world_theme,
			"type": "open_world",
			"terrains": world_terrains
		})
		_game_state.set_project_name(world_name)

		for obj in world_objects:
			# Objects can be strings or {name, prompt, count} dictionaries
			var obj_name: String = ""
			var obj_count: int = 5
			if obj is String:
				obj_name = obj
			elif obj is Dictionary:
				obj_name = obj.get("name", "")
				obj_count = obj.get("count", 5)
			if not obj_name.is_empty():
				_game_state.add_object(obj_name, obj_count, "scattered")

	var pending_count: int = 0
	if _asset_manager:
		pending_count = _asset_manager.get_pending_count()

	status_message.emit("✓ World created: " + world_name + " (" + str(size) + "x" + str(size) + " tiles)", Color.GREEN)
	status_message.emit(str(pending_count) + " assets pending - generate them in Assets tab", Color.CYAN)

	# Reset pending world
	_pending_world = {
		"name": "",
		"theme": "",
		"terrains": [],
		"size": "medium",
		"objects": [],
		"features": []
	}

	world_created.emit(_current_world_path)


## AI decided to add objects to existing world
## Objects can be strings OR {name, prompt, count} dictionaries
func _execute_add_object(params: Dictionary) -> void:
	if not _game_state or not _game_state.has_world():
		status_message.emit("Create a world first!", Color.YELLOW)
		return

	var objects: Array = params.get("objects", [])
	var default_count: int = params.get("count", 5)
	var location: String = params.get("location", "")

	for obj in objects:
		var obj_name: String = ""
		var obj_prompt: String = ""
		var obj_count: int = default_count

		if obj is String:
			obj_name = obj
			obj_prompt = obj + ", top-down view, game sprite"
		elif obj is Dictionary:
			obj_name = obj.get("name", "")
			obj_prompt = obj.get("prompt", obj_name + ", top-down view, game sprite")
			obj_count = obj.get("count", default_count)

		if obj_name.is_empty():
			continue

		if _game_state:
			_game_state.add_object(obj_name, obj_count, location)
		if _asset_manager:
			_asset_manager.add_object(obj_name, obj_prompt, obj_count)
		status_message.emit("Added " + str(obj_count) + " " + obj_name, Color.CYAN)

	action_executed.emit("add_object", params)


## AI decided to add a character
## AI provides: {type, name, behavior, prompt, abilities, spawn}
func _execute_add_character(params: Dictionary) -> void:
	if not _game_state or not _game_state.has_world():
		status_message.emit("Create a world first!", Color.YELLOW)
		return

	var char_type: String = params.get("type", "npc")
	var char_name: String = params.get("name", char_type.capitalize())
	var behavior: String = params.get("behavior", "stationary")
	var char_prompt: String = params.get("prompt", char_name + " character, top-down view, game sprite")
	var abilities: Array = params.get("abilities", ["move"])
	var spawn: String = params.get("spawn", "center")

	if char_type == "player":
		if _game_state and _game_state.has_player():
			status_message.emit("Player already exists!", Color.YELLOW)
			return
		if _game_state:
			_game_state.set_player({
				"name": char_name,
				"spawn": spawn,
				"abilities": abilities
			})
		status_message.emit("Player created: " + char_name, Color.GREEN)
	else:
		if _game_state:
			_game_state.add_npc({
				"name": char_name,
				"behavior": behavior,
				"position": [64, 64]
			})
		status_message.emit(char_name + " added with " + behavior + " behavior", Color.GREEN)

	if _asset_manager:
		_asset_manager.add_object(char_type, char_prompt, 1)

	action_executed.emit("add_character", params)


func _create_world_folder(world_name: String, theme: String, terrains: Array[String]) -> void:
	var folder_path := "res://game/" + world_name + "/"
	var scene_path := folder_path + "world.tscn"

	var dir := DirAccess.open("res://")
	if dir:
		var rel_folder := "game/" + world_name
		if not dir.dir_exists(rel_folder):
			dir.make_dir_recursive(rel_folder)

	var scene_content := _generate_world_scene(theme)

	var abs_path := ProjectSettings.globalize_path(scene_path)
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	if file:
		file.store_string(scene_content)
		file.close()
		status_message.emit("Created: " + scene_path, Color.GREEN)
	else:
		status_message.emit("Failed to create world scene!", Color.RED)
		return

	_current_world_path = scene_path


func _generate_world_scene(theme: String) -> String:
	var ts: int = _asset_manager.get_tile_size() if _asset_manager else 16
	return """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/ai_assistant/world/world_runner.gd" id="1"]

[node name="World" type="Node2D"]
script = ExtResource("1")
world_width = 128
world_height = 128
world_seed = 0
tile_size = """ + str(ts) + """
theme = \"""" + theme + """\"

[node name="UI" type="CanvasLayer" parent="."]

[node name="Instructions" type="Label" parent="UI"]
offset_left = 10.0
offset_top = 10.0
offset_right = 400.0
offset_bottom = 80.0
text = "WASD - Move | R - New World | ESC - Quit"

[node name="SeedLabel" type="Label" parent="UI"]
offset_left = 10.0
offset_top = 40.0
offset_right = 300.0
offset_bottom = 70.0
text = "Seed: -"
"""


## Validate and save a mechanic script
func validate_and_save_mechanic(response: String, description: String) -> Dictionary:
	if not _script_validator:
		return {"success": false, "error": "Script validator not loaded"}

	var code: String = _script_validator.extract_code_from_response(response)
	if code.is_empty():
		return {"success": false, "error": "No code found in response"}

	var result: Dictionary = _script_validator.validate(code)

	if result.valid:
		var mechanic_id := _generate_mechanic_id(description)
		var script_path := "res://scripts/mechanics/" + mechanic_id + ".gd"

		var save_result: Dictionary = _script_validator.validate_and_save(code, script_path)

		if save_result.saved:
			if _game_state:
				_game_state.add_mechanic(description, script_path)
			return {"success": true, "path": script_path, "warnings": result.warnings}
		else:
			return {"success": false, "error": save_result.error}

	return {"success": false, "error": result.error}


func _generate_mechanic_id(description: String) -> String:
	var words := description.to_lower().split(" ")
	var id_parts: Array[String] = []
	for word in words:
		var clean := word.strip_edges()
		if clean.length() > 2 and clean not in ["the", "and", "can", "with", "player"]:
			id_parts.append(clean)
			if id_parts.size() >= 3:
				break
	if id_parts.is_empty():
		return "mechanic_" + str(randi() % 10000)
	return "_".join(id_parts)
