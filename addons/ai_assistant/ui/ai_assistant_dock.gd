@tool
extends Control

## AI Assistant Dock - Chat + Assets tabs
## Chat analyzes user input and populates manifest dynamically

# UI References
var _tab_container: TabContainer
var _prompt_input: TextEdit
var _send_button: Button
var _chat_scroll: ScrollContainer
var _chat_container: VBoxContainer
var _clear_button: Button
var _settings_button: Button
var _asset_container: VBoxContainer
var _generate_all_btn: Button
var _run_world_btn: Button
var _asset_status: Label

var _plugin_reference: EditorPlugin = null
var _settings_dialog: Window = null

# State
var _is_processing := false
var _api_key := ""
var _replicate_key := ""
var _ai_model := "claude-sonnet-4-5-20250929"
var _setup_done := false
var _current_world_path := ""  # Path to the current world scene

const AI_MODELS := {
	"Claude Sonnet 4.5": "claude-sonnet-4-5-20250929",
	"Claude Opus 4.5": "claude-opus-4-5-20251101"
}

# Components
var _asset_manager: RefCounted = null
var _replicate_client: RefCounted = null
var _ai_stream: RefCounted = null

# Streaming
var _stream_rtl: RichTextLabel = null
var _stream_content := ""


func _ready() -> void:
	if not _setup_done:
		_setup()


func _setup() -> void:
	if _setup_done:
		return
	_setup_done = true

	_load_components()
	_find_ui_nodes()
	_connect_signals()
	_load_settings()
	_refresh_assets_tab()


func _load_components() -> void:
	# Asset Manager
	var AMScript = load("res://addons/ai_assistant/core/asset_manager.gd")
	if AMScript:
		_asset_manager = AMScript.new()
		_asset_manager.manifest_changed.connect(_refresh_assets_tab)

	# Replicate Client
	var RCScript = load("res://addons/ai_assistant/api/replicate_client.gd")
	if RCScript:
		_replicate_client = RCScript.new()
		_replicate_client.generation_progress.connect(_on_gen_progress)
		_replicate_client.generation_completed.connect(_on_gen_completed)
		_replicate_client.generation_error.connect(_on_gen_error)

	# AI Streaming (for chat)
	var StreamScript = load("res://addons/ai_assistant/core/ai_streaming.gd")
	if StreamScript:
		_ai_stream = StreamScript.new()
		_ai_stream.chunk_received.connect(_on_stream_chunk)
		_ai_stream.stream_finished.connect(_on_stream_finished)
		_ai_stream.stream_error.connect(_on_stream_error)


func _find_ui_nodes() -> void:
	_tab_container = _find("TabContainer") as TabContainer
	_prompt_input = _find("PromptInput") as TextEdit
	_send_button = _find("SendButton") as Button
	_chat_scroll = _find("ChatScroll") as ScrollContainer
	_chat_container = _find("ChatContainer") as VBoxContainer
	_clear_button = _find("ClearButton") as Button
	_settings_button = _find("SettingsButton") as Button
	_asset_container = _find("AssetContainer") as VBoxContainer
	_generate_all_btn = _find("GenerateAllBtn") as Button
	_run_world_btn = _find("RunWorldBtn") as Button
	_asset_status = _find("AssetStatus") as Label


func _connect_signals() -> void:
	if _send_button:
		_send_button.pressed.connect(_on_send_pressed)
	if _clear_button:
		_clear_button.pressed.connect(_clear_chat)
	if _settings_button:
		_settings_button.pressed.connect(_open_settings)
	if _generate_all_btn:
		_generate_all_btn.pressed.connect(_generate_all_assets)
	if _run_world_btn:
		_run_world_btn.pressed.connect(_run_world)


func _find(node_name: String) -> Node:
	return find_child(node_name, true, false)


# ==================== CHAT ====================

func _on_send_pressed() -> void:
	if not _prompt_input:
		return

	var text := _prompt_input.text.strip_edges()
	if text.is_empty():
		return

	if _is_processing:
		_sys("Still processing...", Color.YELLOW)
		return

	_prompt_input.text = ""
	_msg(text, true)

	# Check for world generation keywords
	if _is_world_request(text):
		_handle_world_request(text)
		return

	# Regular AI chat
	if _api_key.is_empty():
		_sys("Set API key in Settings first!", Color.RED)
		return

	_call_ai(text)


func _is_world_request(text: String) -> bool:
	var lower := text.to_lower()
	var gen_words := ["create", "generate", "make", "build", "want", "need", "give"]
	var world_words := ["world", "map", "terrain", "level", "land", "scene"]
	var terrain_words := ["forest", "beach", "ocean", "desert", "snow", "water", "sand", "grass", "river", "lake", "island", "mountain"]

	var has_gen := false
	var has_world := false
	var has_terrain := false

	for w in gen_words:
		if w in lower:
			has_gen = true
			break

	for w in world_words:
		if w in lower:
			has_world = true
			break

	for w in terrain_words:
		if w in lower:
			has_terrain = true
			break

	# Trigger if: (gen + world) OR (gen + terrain) OR (just multiple terrains mentioned)
	if has_gen and has_world:
		return true
	if has_gen and has_terrain:
		return true
	# If user mentions 2+ terrain types, assume they want a world
	var terrain_count := 0
	for w in terrain_words:
		if w in lower:
			terrain_count += 1
	if terrain_count >= 2:
		return true

	return false


func _handle_world_request(text: String) -> void:
	_sys("Analyzing world request...", Color.CYAN)

	# Clear old assets
	if _asset_manager:
		_asset_manager.clear()

	# Parse what terrains/objects are mentioned
	var lower := text.to_lower()

	# Determine world name and theme from request
	var world_name := _extract_world_name(lower)
	var theme := _determine_theme(lower)

	# Detect terrain types - order matters for transitions!
	var terrains: Array[String] = []

	# Beach/ocean implies water + sand
	if "beach" in lower or "ocean" in lower or "island" in lower or "tropical" in lower:
		if "water" not in terrains:
			terrains.append("water")
		if "sand" not in terrains:
			terrains.append("sand")

	# Explicit water
	if "water" in lower or "sea" in lower or "lake" in lower or "river" in lower:
		if "water" not in terrains:
			terrains.append("water")

	# Explicit sand/desert
	if "sand" in lower or "desert" in lower or "dune" in lower:
		if "sand" not in terrains:
			terrains.append("sand")

	# Grass/plains
	if "grass" in lower or "plain" in lower or "meadow" in lower or "field" in lower:
		if "grass" not in terrains:
			terrains.append("grass")

	# Forest (from trees keyword too)
	if "forest" in lower or "tree" in lower or "wood" in lower or "jungle" in lower:
		if "forest" not in terrains:
			terrains.append("forest")

	# Snow/ice
	if "snow" in lower or "ice" in lower or "frozen" in lower or "winter" in lower:
		if "snow" not in terrains:
			terrains.append("snow")

	# Default if nothing detected
	if terrains.is_empty():
		terrains = ["water", "sand", "grass"]

	# Add terrains to manifest
	for t in terrains:
		var prompt := _get_terrain_prompt(t)
		_asset_manager.add_terrain(t, prompt)

	# Add transitions between adjacent terrains
	for i in range(terrains.size()):
		var next_i := (i + 1) % terrains.size()
		var from_t := terrains[i]
		var to_t := terrains[next_i]
		var prompt := from_t + " to " + to_t + " transition, shoreline edge"
		_asset_manager.add_transition(from_t, to_t, prompt)

	# Detect objects
	if "tree" in lower or "forest" in lower or "palm" in lower:
		var tree_prompt := "pixel art tree"
		if "palm" in lower:
			tree_prompt = "palm tree, tropical"
		elif "pine" in lower or "snow" in lower:
			tree_prompt = "pine tree, evergreen"
		_asset_manager.add_object("tree", tree_prompt, 3)

	if "rock" in lower or "stone" in lower or "boulder" in lower:
		_asset_manager.add_object("rock", "rock boulder, natural stone", 2)

	if "bush" in lower or "plant" in lower or "flower" in lower:
		_asset_manager.add_object("plant", "bush flower plant, vegetation", 2)

	# Detect structures
	if "house" in lower or "cabin" in lower or "hut" in lower or "building" in lower or "village" in lower:
		_asset_manager.add_structure("house", "small house cottage cabin", 2)

	if "tower" in lower or "castle" in lower or "fort" in lower:
		_asset_manager.add_structure("tower", "stone tower fortress", 1)

	# CREATE THE WORLD FOLDER AND SCENE
	_create_world_folder(world_name, theme, terrains)

	# Show summary
	var pending: int = _asset_manager.get_pending_count()
	_msg("Created world: **" + world_name + "**\nTheme: " + theme + "\nTerrains: " + ", ".join(terrains) + "\n\n**" + str(pending) + " assets needed.** Generate them in Assets tab, then click 'Run World'!", false)

	# Switch to assets tab
	if _tab_container:
		_tab_container.current_tab = 1

	_refresh_assets_tab()


func _extract_world_name(text: String) -> String:
	# Extract a name from the request
	var words := text.split(" ")
	var name_parts: Array[String] = []

	for word in words:
		if word in ["create", "generate", "make", "build", "a", "an", "the", "world", "map", "with", "and", "some"]:
			continue
		if word.length() > 2:
			name_parts.append(word)
		if name_parts.size() >= 2:
			break

	if name_parts.is_empty():
		return "world_" + str(randi() % 10000)

	return "_".join(name_parts)


func _determine_theme(text: String) -> String:
	if "beach" in text or "ocean" in text or "tropical" in text:
		return "beach"
	if "forest" in text or "wood" in text:
		return "forest"
	if "desert" in text or "sand" in text:
		return "desert"
	if "snow" in text or "ice" in text or "frozen" in text:
		return "snow"
	if "plain" in text or "grass" in text or "meadow" in text:
		return "plains"
	return "plains"


func _create_world_folder(world_name: String, theme: String, terrains: Array[String]) -> void:
	var folder_path := "res://game/" + world_name + "/"
	var scene_path := folder_path + "world.tscn"

	# Create folder
	var dir := DirAccess.open("res://")
	if dir:
		var rel_folder := "game/" + world_name
		if not dir.dir_exists(rel_folder):
			dir.make_dir_recursive(rel_folder)

	# Create world scene file
	var scene_content := _generate_world_scene(theme)

	var abs_path := ProjectSettings.globalize_path(scene_path)
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	if file:
		file.store_string(scene_content)
		file.close()
		_sys("Created: " + scene_path, Color.GREEN)
	else:
		_sys("Failed to create world scene!", Color.RED)
		return

	_current_world_path = scene_path

	# Refresh filesystem
	var editor := _get_editor_interface()
	if editor:
		editor.get_resource_filesystem().scan()


func _generate_world_scene(theme: String) -> String:
	return """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/ai_assistant/world/world_runner.gd" id="1"]

[node name="World" type="Node2D"]
script = ExtResource("1")
world_width = 128
world_height = 128
world_seed = 0
tile_size = 32
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


func _get_terrain_prompt(terrain: String) -> String:
	match terrain:
		"water":
			return "blue ocean water, waves, deep sea"
		"sand":
			return "beach sand, golden yellow, sandy"
		"grass":
			return "green grass, meadow, lush"
		"forest":
			return "forest floor, dirt, leaves, undergrowth"
		"snow":
			return "white snow, ice, frozen ground"
		_:
			return terrain + " terrain"


func _msg(text: String, is_user: bool) -> RichTextLabel:
	if not _chat_container:
		return null

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.bg_color = Color(0.2, 0.4, 0.7, 0.5) if is_user else Color(0.2, 0.5, 0.3, 0.5)
	panel.add_theme_stylebox_override("panel", style)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.selection_enabled = true
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.text = ("[b]You:[/b] " if is_user else "[b]AI:[/b] ") + text
	panel.add_child(rtl)

	_chat_container.add_child(panel)
	_scroll_chat()
	return rtl


func _sys(text: String, color: Color = Color.ORANGE) -> void:
	if not _chat_container:
		return
	var lbl := Label.new()
	lbl.text = "> " + text
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_container.add_child(lbl)
	_scroll_chat()


func _scroll_chat() -> void:
	if _chat_scroll:
		await get_tree().process_frame
		_chat_scroll.scroll_vertical = 99999


func _clear_chat() -> void:
	if _chat_container:
		for child in _chat_container.get_children():
			child.queue_free()


# ==================== AI STREAMING ====================

func _call_ai(prompt: String) -> void:
	_is_processing = true
	if _send_button:
		_send_button.disabled = true

	_stream_rtl = _msg("", false)
	_stream_content = ""

	var system_prompt := "You are a helpful Godot game development assistant. Help the user create games. When they describe a world, identify what terrain types, objects, and structures they need."

	var messages := [{"role": "user", "content": prompt}]

	if _ai_stream:
		_ai_stream.start_stream(_api_key, "anthropic", _ai_model, messages, system_prompt)


func _on_stream_chunk(text: String) -> void:
	_stream_content += text
	if _stream_rtl:
		_stream_rtl.text = "[b]AI:[/b] " + _stream_content


func _on_stream_finished(full_response: String) -> void:
	_is_processing = false
	if _send_button:
		_send_button.disabled = false


func _on_stream_error(error: String) -> void:
	_sys("Error: " + error, Color.RED)
	_is_processing = false
	if _send_button:
		_send_button.disabled = false


# ==================== ASSETS TAB ====================

func _refresh_assets_tab() -> void:
	if not _asset_container or not _asset_manager:
		return

	# Clear existing
	for child in _asset_container.get_children():
		child.queue_free()

	# Add sections
	_add_asset_section("Terrain", _asset_manager.get_terrains(), "terrain")
	_add_asset_section("Transitions", _asset_manager.get_transitions(), "transition")
	_add_asset_section("Objects", _asset_manager.get_objects(), "object")
	_add_asset_section("Structures", _asset_manager.get_structures(), "structure")

	# Update status
	var pending: int = _asset_manager.get_pending_count()
	if _asset_status:
		if pending > 0:
			_asset_status.text = str(pending) + " assets to generate"
		else:
			_asset_status.text = "All assets generated!"

	if _generate_all_btn:
		_generate_all_btn.visible = pending > 0


func _add_asset_section(title: String, assets: Dictionary, asset_type: String) -> void:
	if assets.is_empty():
		return

	# Section header
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_asset_container.add_child(header)

	# Asset items
	for key in assets:
		var data: Dictionary = assets[key]
		_add_asset_item(key, data, asset_type)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	_asset_container.add_child(spacer)


func _add_asset_item(name: String, data: Dictionary, asset_type: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Status icon
	var status := Label.new()
	var is_done := false

	if asset_type in ["terrain", "transition"]:
		is_done = data.get("generated", false)
	else:
		is_done = data.get("generated", 0) >= data.get("needed", 1)

	status.text = "[OK]" if is_done else "[  ]"
	status.add_theme_color_override("font_color", Color.GREEN if is_done else Color.GRAY)
	status.custom_minimum_size.x = 40
	hbox.add_child(status)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = name.capitalize()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	# Generate button
	if not is_done:
		var btn := Button.new()
		btn.text = "Generate"
		btn.pressed.connect(_on_generate_asset.bind(name, data, asset_type, btn))
		hbox.add_child(btn)

	_asset_container.add_child(hbox)


func _on_generate_asset(name: String, data: Dictionary, asset_type: String, btn: Button) -> void:
	if not _replicate_client:
		_sys("Replicate client not loaded", Color.RED)
		return

	if _replicate_key.is_empty():
		_sys("Set Replicate API key in Settings!", Color.RED)
		return

	btn.disabled = true
	btn.text = "..."

	_replicate_client.setup(_replicate_key, self)

	var prompt: String = data.get("prompt", name)
	var tile_size: int = _asset_manager.get_tile_size() if _asset_manager else 32

	match asset_type:
		"terrain":
			_replicate_client.generate_terrain(name, prompt, tile_size)
		"transition":
			var from_t: String = data.get("from", "")
			var to_t: String = data.get("to", "")
			_replicate_client.generate_transition(from_t, to_t, prompt, tile_size)
		"object":
			var idx: int = data.get("generated", 0) + 1
			_replicate_client.generate_object(name, prompt, tile_size, idx)
		"structure":
			var idx: int = data.get("generated", 0) + 1
			_replicate_client.generate_structure(name, prompt, tile_size, idx)


func _generate_all_assets() -> void:
	_sys("Generate All not implemented yet - click individual buttons", Color.YELLOW)


func _run_world() -> void:
	var editor := _get_editor_interface()
	if not editor:
		_sys("Cannot run - editor interface not available", Color.RED)
		return

	# Use current world path, or fallback to default
	var scene_path := _current_world_path
	if scene_path.is_empty():
		scene_path = "res://game/world.tscn"

	if not ResourceLoader.exists(scene_path):
		_sys("World scene not found at " + scene_path + "\nCreate a world first using chat!", Color.RED)
		return

	_sys("Launching: " + scene_path, Color.CYAN)
	editor.play_custom_scene(scene_path)


func _on_gen_progress(status: String) -> void:
	if _asset_status:
		_asset_status.text = status


func _on_gen_completed(image_data: PackedByteArray, asset_info: Dictionary) -> void:
	var asset_type: String = asset_info.get("type", "")
	var name: String = asset_info.get("name", "")
	var file_path: String = asset_info.get("file", "")

	if file_path.is_empty():
		_sys("No file path for asset", Color.RED)
		return

	# Ensure folder exists
	if _asset_manager:
		_asset_manager.ensure_asset_folder(file_path)

	# Save file
	var full_path := "res://assets/" + file_path
	var abs_path := ProjectSettings.globalize_path(full_path)

	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	if not file:
		_sys("Failed to save: " + file_path, Color.RED)
		return

	file.store_buffer(image_data)
	file.close()

	# Update manifest
	if _asset_manager:
		match asset_type:
			"terrain":
				_asset_manager.mark_terrain_generated(name)
			"transition":
				var from_t: String = asset_info.get("from", "")
				var to_t: String = asset_info.get("to", "")
				_asset_manager.mark_transition_generated(from_t, to_t)
			"object":
				_asset_manager.mark_object_generated(name)
			"structure":
				_asset_manager.mark_structure_generated(name)

	_sys("Saved: " + file_path, Color.GREEN)

	# Refresh Godot filesystem
	var editor := _get_editor_interface()
	if editor:
		editor.get_resource_filesystem().scan()

	_refresh_assets_tab()


func _on_gen_error(error: String) -> void:
	_sys("Generation error: " + error, Color.RED)
	_refresh_assets_tab()


# ==================== SETTINGS ====================

func _open_settings() -> void:
	if _settings_dialog and is_instance_valid(_settings_dialog):
		_settings_dialog.popup_centered()
		return

	_settings_dialog = Window.new()
	_settings_dialog.title = "AI Assistant Settings"
	_settings_dialog.size = Vector2i(400, 350)
	_settings_dialog.close_requested.connect(func(): _settings_dialog.hide())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_settings_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# AI API Key
	vbox.add_child(_make_label("Claude API Key:"))
	var key_input := LineEdit.new()
	key_input.secret = true
	key_input.text = _api_key
	key_input.placeholder_text = "sk-ant-..."
	vbox.add_child(key_input)

	# AI Model Selection
	vbox.add_child(_make_label("AI Model:"))
	var model_select := OptionButton.new()
	var idx := 0
	var selected_idx := 0
	for model_name in AI_MODELS:
		model_select.add_item(model_name)
		if AI_MODELS[model_name] == _ai_model:
			selected_idx = idx
		idx += 1
	model_select.selected = selected_idx
	vbox.add_child(model_select)

	# Replicate API Key
	vbox.add_child(_make_label("Replicate API Key (for assets):"))
	var rep_input := LineEdit.new()
	rep_input.secret = true
	rep_input.text = _replicate_key
	rep_input.placeholder_text = "r8_..."
	vbox.add_child(rep_input)

	# Save button
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(func():
		_api_key = key_input.text
		_replicate_key = rep_input.text
		var selected_name: String = model_select.get_item_text(model_select.selected)
		_ai_model = AI_MODELS.get(selected_name, "claude-sonnet-4-5-20250929")
		_save_settings()
		_settings_dialog.hide()
		_sys("Settings saved! Using " + selected_name, Color.GREEN)
	)
	vbox.add_child(save_btn)

	add_child(_settings_dialog)
	_settings_dialog.popup_centered()


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	return lbl


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://ai_assistant_settings.cfg") == OK:
		_api_key = cfg.get_value("settings", "api_key", "")
		_replicate_key = cfg.get_value("settings", "replicate_key", "")
		_ai_model = cfg.get_value("settings", "ai_model", "claude-sonnet-4-5-20250929")


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "api_key", _api_key)
	cfg.set_value("settings", "replicate_key", _replicate_key)
	cfg.set_value("settings", "ai_model", _ai_model)
	cfg.save("user://ai_assistant_settings.cfg")


# ==================== HELPERS ====================

func set_plugin_reference(p: EditorPlugin) -> void:
	_plugin_reference = p


func _get_editor_interface() -> EditorInterface:
	if _plugin_reference and is_instance_valid(_plugin_reference):
		return _plugin_reference.get_editor_interface()
	return null
