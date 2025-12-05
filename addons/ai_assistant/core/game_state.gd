@tool
class_name GameState
extends RefCounted

## Memory Bank - Persists all game state to JSON
## Survives plugin reloads, provides context to Claude

const STATE_PATH := "res://game_project.json"
const BACKUP_PATH := "res://game_project.backup.json"

signal state_changed
signal world_changed
signal objects_changed
signal characters_changed
signal mechanics_changed

var _state: Dictionary = {}
var _dirty: bool = false


func _init() -> void:
	load_state()


# ==================== PERSISTENCE ====================

func load_state() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		_state = _create_empty_state()
		return

	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if not file:
		push_warning("GameState: Could not open state file")
		_state = _create_empty_state()
		return

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_warning("GameState: JSON parse error - %s" % json.get_error_message())
		_try_restore_backup()
		return

	_state = json.data
	_migrate_if_needed()


func save_state() -> void:
	# Create backup of existing state first
	if FileAccess.file_exists(STATE_PATH):
		var existing := FileAccess.open(STATE_PATH, FileAccess.READ)
		if existing:
			var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup:
				backup.store_string(existing.get_as_text())
				backup.close()
			existing.close()

	# Update timestamp
	_state.updated_at = Time.get_datetime_string_from_system()

	# Save state
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_state, "\t"))
		file.close()
		_dirty = false
	else:
		push_error("GameState: Could not save state file")


func _try_restore_backup() -> void:
	if FileAccess.file_exists(BACKUP_PATH):
		var backup := FileAccess.open(BACKUP_PATH, FileAccess.READ)
		if backup:
			var json := JSON.new()
			if json.parse(backup.get_as_text()) == OK:
				_state = json.data
				push_warning("GameState: Restored from backup")
				return
	_state = _create_empty_state()


func _create_empty_state() -> Dictionary:
	return {
		"version": "1.0",
		"project_name": "New Game",
		"created_at": Time.get_datetime_string_from_system(),
		"updated_at": Time.get_datetime_string_from_system(),

		"world": {
			"width": 0,
			"height": 0,
			"seed": 0,
			"theme": "",
			"type": "",
			"terrains": [],
			"generated": false
		},

		"objects": {},

		"characters": {
			"player": null,
			"npcs": []
		},

		"mechanics": [],

		"conversation_history": []
	}


func _migrate_if_needed() -> void:
	# Handle version upgrades
	var version: String = _state.get("version", "0.0")
	if version == "1.0":
		return  # Current version

	# Add migration logic for future versions here
	_state.version = "1.0"
	save_state()


# ==================== WORLD STATE ====================

func has_world() -> bool:
	return _state.world.get("generated", false)


func set_world(world_data: Dictionary) -> void:
	# Handle theme - can be string or int
	var theme_value = world_data.get("theme", "plains")
	var theme_str: String = theme_value if theme_value is String else _theme_to_string(theme_value)

	# Handle type - can be string or int
	var type_value = world_data.get("type", "open_world")
	var type_str: String = type_value if type_value is String else _type_to_string(type_value)

	_state.world = {
		"width": world_data.get("width", 128),
		"height": world_data.get("height", 128),
		"seed": world_data.get("seed", 0),
		"theme": theme_str,
		"type": type_str,
		"terrains": world_data.get("terrains", []),
		"generated": true
	}
	save_state()
	world_changed.emit()
	state_changed.emit()


func get_world() -> Dictionary:
	return _state.world.duplicate()


func clear_world() -> void:
	_state.world = {
		"width": 0,
		"height": 0,
		"seed": 0,
		"theme": "",
		"type": "",
		"terrains": [],
		"generated": false
	}
	save_state()
	world_changed.emit()
	state_changed.emit()


func _theme_to_string(theme: int) -> String:
	match theme:
		0: return "forest"
		1: return "desert"
		2: return "snow"
		3: return "ocean"
		4: return "plains"
		_: return "plains"


func _type_to_string(type: int) -> String:
	match type:
		0: return "open_world"
		1: return "side_scroller"
		_: return "open_world"


# ==================== OBJECTS STATE ====================

func add_object(name: String, count: int = 1, placement: String = "") -> void:
	if not _state.objects.has(name):
		_state.objects[name] = {
			"count": 0,
			"placement": placement,
			"sprite_generated": false,
			"sprite_path": ""
		}

	_state.objects[name].count += count
	if placement:
		_state.objects[name].placement = placement

	save_state()
	objects_changed.emit()
	state_changed.emit()


func get_objects() -> Dictionary:
	return _state.objects.duplicate(true)


func get_object(name: String) -> Dictionary:
	return _state.objects.get(name, {}).duplicate()


func remove_object(name: String) -> void:
	_state.objects.erase(name)
	save_state()
	objects_changed.emit()
	state_changed.emit()


func mark_object_sprite_generated(name: String, path: String) -> void:
	if _state.objects.has(name):
		_state.objects[name].sprite_generated = true
		_state.objects[name].sprite_path = path
		save_state()
		objects_changed.emit()
		state_changed.emit()


# ==================== CHARACTERS STATE ====================

func set_player(player_data: Dictionary) -> void:
	_state.characters.player = {
		"name": player_data.get("name", "Player"),
		"spawn": player_data.get("spawn", "center"),
		"sprite_generated": false,
		"sprite_path": "",
		"abilities": player_data.get("abilities", ["move"]),
		"script_path": player_data.get("script_path", "")
	}
	save_state()
	characters_changed.emit()
	state_changed.emit()


func has_player() -> bool:
	return _state.characters.player != null


func get_player() -> Dictionary:
	if _state.characters.player:
		return _state.characters.player.duplicate()
	return {}


func add_npc(npc_data: Dictionary) -> void:
	var npc := {
		"id": npc_data.get("id", "npc_%d" % _state.characters.npcs.size()),
		"name": npc_data.get("name", "NPC"),
		"position": npc_data.get("position", [0, 0]),
		"behavior": npc_data.get("behavior", "stationary"),
		"sprite_generated": false,
		"sprite_path": "",
		"script_path": npc_data.get("script_path", "")
	}
	_state.characters.npcs.append(npc)
	save_state()
	characters_changed.emit()
	state_changed.emit()


func get_npcs() -> Array:
	return _state.characters.npcs.duplicate(true)


func get_npc(id: String) -> Dictionary:
	for npc in _state.characters.npcs:
		if npc.id == id:
			return npc.duplicate()
	return {}


func remove_npc(id: String) -> void:
	for i in range(_state.characters.npcs.size()):
		if _state.characters.npcs[i].id == id:
			_state.characters.npcs.remove_at(i)
			save_state()
			characters_changed.emit()
			state_changed.emit()
			return


# ==================== MECHANICS STATE ====================

func add_mechanic(description: String, script_path: String) -> void:
	var mechanic := {
		"id": _generate_mechanic_id(description),
		"description": description,
		"script_path": script_path,
		"enabled": true,
		"created_at": Time.get_datetime_string_from_system()
	}
	_state.mechanics.append(mechanic)
	save_state()
	mechanics_changed.emit()
	state_changed.emit()


func get_mechanics() -> Array:
	return _state.mechanics.duplicate(true)


func get_mechanic(id: String) -> Dictionary:
	for m in _state.mechanics:
		if m.id == id:
			return m.duplicate()
	return {}


func toggle_mechanic(id: String, enabled: bool) -> void:
	for m in _state.mechanics:
		if m.id == id:
			m.enabled = enabled
			save_state()
			mechanics_changed.emit()
			state_changed.emit()
			return


func remove_mechanic(id: String) -> void:
	for i in range(_state.mechanics.size()):
		if _state.mechanics[i].id == id:
			_state.mechanics.remove_at(i)
			save_state()
			mechanics_changed.emit()
			state_changed.emit()
			return


func _generate_mechanic_id(description: String) -> String:
	# Generate a simple ID from description
	var words := description.to_lower().split(" ")
	var id_parts: Array[String] = []
	for word in words:
		var clean := word.strip_edges()
		if clean.length() > 2 and clean not in ["the", "and", "can", "with"]:
			id_parts.append(clean)
			if id_parts.size() >= 3:
				break
	return "_".join(id_parts) if id_parts.size() > 0 else "mechanic_%d" % _state.mechanics.size()


# ==================== CONVERSATION HISTORY ====================

func add_message(role: String, content: String) -> void:
	_state.conversation_history.append({
		"role": role,
		"content": content,
		"timestamp": Time.get_datetime_string_from_system()
	})
	# Keep last 50 messages to avoid bloat
	if _state.conversation_history.size() > 50:
		_state.conversation_history = _state.conversation_history.slice(-50)
	save_state()
	state_changed.emit()


func get_conversation_history() -> Array:
	return _state.conversation_history.duplicate(true)


func clear_conversation_history() -> void:
	_state.conversation_history = []
	save_state()
	state_changed.emit()


# ==================== CONTEXT FOR CLAUDE ====================

func get_context_for_claude() -> String:
	var context := "CURRENT GAME STATE:\n"

	# World info
	if has_world():
		var w: Dictionary = _state.world
		context += "- World: %s %s, %dx%d tiles, seed %d\n" % [
			w.get("theme", ""), w.get("type", ""), w.get("width", 0), w.get("height", 0), w.get("seed", 0)
		]
		var terrains: Array = w.get("terrains", [])
		context += "- Terrains: %s\n" % ", ".join(terrains)
	else:
		context += "- World: Not generated yet\n"

	# Objects
	if _state.objects.size() > 0:
		context += "- Objects:\n"
		for obj_name in _state.objects:
			var obj: Dictionary = _state.objects[obj_name]
			context += "  - %s: %d placed in %s\n" % [obj_name, obj.get("count", 0), obj.get("placement", "")]

	# Characters
	if has_player():
		var p: Dictionary = _state.characters.player
		var abilities: Array = p.get("abilities", [])
		context += "- Player: %s, abilities: %s\n" % [p.get("name", "Player"), ", ".join(abilities)]

	var npcs := get_npcs()
	if npcs.size() > 0:
		context += "- NPCs: %d total\n" % npcs.size()
		for npc in npcs:
			context += "  - %s (%s): %s behavior\n" % [npc.name, npc.id, npc.behavior]

	# Mechanics
	var mechanics := get_mechanics()
	if mechanics.size() > 0:
		context += "- Mechanics:\n"
		for m in mechanics:
			var status := "enabled" if m.enabled else "disabled"
			context += "  - %s (%s)\n" % [m.description, status]

	return context


# ==================== PROJECT INFO ====================

func get_project_name() -> String:
	return _state.get("project_name", "New Game")


func set_project_name(name: String) -> void:
	_state.project_name = name
	save_state()
	state_changed.emit()


# ==================== FULL RESET ====================

func reset() -> void:
	_state = _create_empty_state()
	save_state()
	state_changed.emit()
