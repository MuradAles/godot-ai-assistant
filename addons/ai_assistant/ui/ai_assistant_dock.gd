@tool
extends Control

## AI Assistant Dock - Chat + Assets tabs
## Uses modular components for chat, assets, world building, and settings

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
var _setup_done := false

# Modular components
var _chat_handler: ChatHandler
var _asset_generator: RefCounted
var _world_builder: WorldBuilder
var _settings_manager: SettingsManager
var _asset_manager: RefCounted
var _game_state: RefCounted
var _intent_parser: RefCounted
var _script_validator: RefCounted


func _ready() -> void:
	if not _setup_done:
		_setup()


func _setup() -> void:
	if _setup_done:
		return
	_setup_done = true

	_load_components()
	_find_ui_nodes()
	_setup_modules()
	_connect_signals()
	_settings_manager.load_settings()
	_apply_settings()
	_refresh_assets_tab()
	_chat_handler.restore_history()


func _load_components() -> void:
	# Game State (Memory Bank)
	var GSScript = load("res://addons/ai_assistant/core/game_state.gd")
	if GSScript and GSScript.can_instantiate():
		_game_state = GSScript.new()

	# Intent Parser
	var IPScript = load("res://addons/ai_assistant/core/intent_parser.gd")
	if IPScript and IPScript.can_instantiate():
		_intent_parser = IPScript.new()

	# Script Validator
	var SVScript = load("res://addons/ai_assistant/core/script_validator.gd")
	if SVScript and SVScript.can_instantiate():
		_script_validator = SVScript.new()

	# Asset Manager
	var AMScript = load("res://addons/ai_assistant/core/asset_manager.gd")
	if AMScript and AMScript.can_instantiate():
		_asset_manager = AMScript.new()
		_asset_manager.manifest_changed.connect(_refresh_assets_tab)


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


func _setup_modules() -> void:
	# Settings Manager
	_settings_manager = SettingsManager.new()
	_settings_manager.setup(self)
	_settings_manager.settings_saved.connect(_on_settings_saved)

	# Chat Handler
	_chat_handler = ChatHandler.new()
	_chat_handler.setup(_chat_container, _chat_scroll, _game_state)
	_chat_handler.scroll_requested.connect(_scroll_chat)
	_chat_handler.set_decision_callback(_on_ai_decision)
	_chat_handler.set_mechanic_callback(_on_mechanic_generated)

	# Asset Generator (load explicitly to avoid class_name caching issues in @tool scripts)
	var AssetGenScript = load("res://addons/ai_assistant/ui/asset_generator.gd")
	if AssetGenScript:
		_asset_generator = AssetGenScript.new()
		_asset_generator.setup(_asset_manager, self)
		_asset_generator.generation_status_changed.connect(_on_gen_status)
		_asset_generator.asset_saved.connect(_on_asset_saved)
		_asset_generator.generation_error.connect(_on_gen_error)
		_asset_generator.assets_refreshed.connect(_refresh_assets_tab)
	else:
		push_error("[AI Plugin] Failed to load asset_generator.gd")

	# World Builder
	_world_builder = WorldBuilder.new()
	_world_builder.setup(_asset_manager, _game_state, _script_validator)
	_world_builder.world_created.connect(_on_world_created)
	_world_builder.action_executed.connect(_on_action_executed)
	_world_builder.status_message.connect(_on_status_message)


func _connect_signals() -> void:
	if _send_button:
		_send_button.pressed.connect(_on_send_pressed)
	if _clear_button:
		_clear_button.pressed.connect(_on_clear_pressed)
	if _settings_button:
		_settings_button.pressed.connect(_on_settings_pressed)
	if _generate_all_btn:
		_generate_all_btn.pressed.connect(_on_generate_all_pressed)
	if _run_world_btn:
		_run_world_btn.pressed.connect(_on_run_world_pressed)


func _apply_settings() -> void:
	_chat_handler.set_api_key(_settings_manager.api_key)
	_chat_handler.set_model(_settings_manager.ai_model)
	if _asset_generator:
		_asset_generator.set_replicate_key(_settings_manager.replicate_key)


func _find(node_name: String) -> Node:
	return find_child(node_name, true, false)


# ==================== EVENT HANDLERS ====================

func _on_send_pressed() -> void:
	if not _prompt_input:
		return

	var text := _prompt_input.text.strip_edges()
	if text.is_empty():
		return

	_prompt_input.text = ""
	_send_button.disabled = true
	_chat_handler.send_message(text, _world_builder.get_pending_world())


func _on_clear_pressed() -> void:
	_chat_handler.clear()
	_chat_handler.show_welcome()


func _on_settings_pressed() -> void:
	_settings_manager.open_dialog()


func _on_generate_all_pressed() -> void:
	if not _asset_generator:
		_chat_handler.sys("Asset generator not loaded!", Color.RED)
		return
	var started: int = _asset_generator.generate_all()
	if started > 0:
		_chat_handler.sys("Started " + str(started) + " parallel generations", Color.CYAN)
	else:
		_chat_handler.sys("All assets already generated!", Color.GREEN)


func _on_run_world_pressed() -> void:
	_run_world()


func _on_settings_saved(api_key: String, replicate_key: String, ai_model: String) -> void:
	_apply_settings()
	_chat_handler.sys("Settings saved! Using " + _settings_manager.get_model_display_name(), Color.GREEN)


func _on_ai_decision(decision: Dictionary) -> void:
	_send_button.disabled = false
	_world_builder.execute_decision(decision)

	# Handle special actions that need UI changes
	var action: String = decision.get("action", "")
	if action == "finalize_world":
		if _tab_container:
			_tab_container.current_tab = 1
		_refresh_assets_tab()


func _on_mechanic_generated(response: String, description: String) -> void:
	_send_button.disabled = false
	var result := _world_builder.validate_and_save_mechanic(response, description)

	if result.success:
		_chat_handler.sys("Mechanic saved: " + result.path, Color.GREEN)
		var warnings: Array = result.get("warnings", [])
		for w in warnings:
			_chat_handler.sys("Warning line %d: %s" % [w.line, w.message], Color.YELLOW)

		var editor := _get_editor_interface()
		if editor:
			editor.get_resource_filesystem().scan()
	else:
		_chat_handler.sys("Failed: " + result.error, Color.RED)


func _on_world_created(path: String) -> void:
	if _tab_container:
		_tab_container.current_tab = 1
	_refresh_assets_tab()


func _on_action_executed(action: String, params: Dictionary) -> void:
	match action:
		"run_game":
			_run_world()
		"generate_mechanic":
			var description: String = params.get("description", "")
			if not description.is_empty():
				_chat_handler.sys("Generating mechanic: " + description, Color.CYAN)
				_chat_handler.call_ai_for_mechanic(description)
		"add_object", "add_character":
			_refresh_assets_tab()


func _on_status_message(text: String, color: Color) -> void:
	_chat_handler.sys(text, color)


func _on_gen_status(status: String) -> void:
	if _asset_status:
		_asset_status.text = status


func _on_asset_saved(file_path: String) -> void:
	_chat_handler.sys("Saved: " + file_path, Color.GREEN)
	var editor := _get_editor_interface()
	if editor:
		editor.get_resource_filesystem().scan()


func _on_gen_error(error: String) -> void:
	_chat_handler.sys("Generation error: " + error, Color.RED)
	if "401" in error or "Unauthorized" in error:
		_chat_handler.sys("Check your Replicate API key in Settings", Color.YELLOW)
	elif "422" in error:
		_chat_handler.sys("Invalid request - model may have changed", Color.YELLOW)
	elif "No Replicate API key" in error:
		_chat_handler.sys("Go to Settings (gear icon) and enter your Replicate API key", Color.YELLOW)


func _scroll_chat() -> void:
	if _chat_scroll:
		await get_tree().process_frame
		_chat_scroll.scroll_vertical = 99999


# ==================== ASSETS TAB ====================

func _refresh_assets_tab() -> void:
	if not _asset_container or not _asset_manager:
		return

	for child in _asset_container.get_children():
		child.queue_free()

	_add_asset_section("Terrain", _asset_manager.get_terrains(), "terrain")
	_add_asset_section("Transitions", _asset_manager.get_transitions(), "transition")
	_add_asset_section("Objects", _asset_manager.get_objects(), "object")
	_add_asset_section("Structures", _asset_manager.get_structures(), "structure")

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

	var header := Label.new()
	if asset_type == "terrain":
		header.text = title + " (generate first, then transitions)"
	else:
		header.text = title
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_asset_container.add_child(header)

	for key in assets:
		var data: Dictionary = assets[key]
		_add_asset_item(key, data, asset_type)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	_asset_container.add_child(spacer)


func _add_asset_item(name: String, data: Dictionary, asset_type: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var is_done := false
	if asset_type in ["terrain", "transition"]:
		is_done = data.get("generated", false)
	else:
		is_done = data.get("generated", 0) >= data.get("needed", 1)

	# Thumbnail
	var thumb_container := Panel.new()
	thumb_container.custom_minimum_size = Vector2(32, 32)
	var thumb_style := StyleBoxFlat.new()
	thumb_style.bg_color = Color(0.15, 0.15, 0.15)
	thumb_style.set_corner_radius_all(4)
	thumb_container.add_theme_stylebox_override("panel", thumb_style)

	var file_path: String = data.get("file", "")
	if file_path.is_empty() and asset_type in ["object", "structure"]:
		var folder: String = data.get("folder", "")
		if not folder.is_empty():
			var gen_count: int = data.get("generated", 0)
			if gen_count > 0:
				file_path = folder + "/" + name + "_01.png"

	if is_done and not file_path.is_empty():
		var full_path := "res://assets/" + file_path
		if ResourceLoader.exists(full_path):
			var tex := load(full_path) as Texture2D
			if tex:
				var tex_rect := TextureRect.new()
				tex_rect.texture = tex
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
				thumb_container.add_child(tex_rect)

	hbox.add_child(thumb_container)

	var spacer := Control.new()
	spacer.custom_minimum_size.x = 8
	hbox.add_child(spacer)

	# Name and prompt info
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = name.capitalize()
	info_vbox.add_child(name_lbl)

	var prompt_text: String = data.get("prompt", "")
	if not prompt_text.is_empty():
		var prompt_lbl := Label.new()
		prompt_lbl.text = prompt_text.left(40) + ("..." if prompt_text.length() > 40 else "")
		prompt_lbl.add_theme_font_size_override("font_size", 10)
		prompt_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		info_vbox.add_child(prompt_lbl)

	hbox.add_child(info_vbox)

	# Status indicator
	var status := Label.new()
	if asset_type in ["object", "structure"]:
		var gen_count: int = data.get("generated", 0)
		var needed: int = data.get("needed", 1)
		status.text = str(gen_count) + "/" + str(needed)
		status.add_theme_color_override("font_color", Color.GREEN if is_done else Color.YELLOW)
	else:
		status.text = "OK" if is_done else ""
		status.add_theme_color_override("font_color", Color.GREEN)
	status.custom_minimum_size.x = 40
	hbox.add_child(status)

	# Buttons - all asset types can be generated/regenerated
	if not is_done:
		var btn := Button.new()
		btn.text = "Generate"
		btn.pressed.connect(_on_generate_asset.bind(name, data, asset_type, btn))
		hbox.add_child(btn)
	else:
		var regen_btn := Button.new()
		regen_btn.text = "Regen"
		regen_btn.tooltip_text = "Regenerate this asset"
		regen_btn.pressed.connect(_on_regenerate_asset.bind(name, data, asset_type, regen_btn))
		hbox.add_child(regen_btn)

	_asset_container.add_child(hbox)


func _on_generate_asset(name: String, data: Dictionary, asset_type: String, btn: Button) -> void:
	btn.disabled = true
	btn.text = "..."
	if not _asset_generator.generate_single(name, data, asset_type):
		btn.disabled = false
		btn.text = "Generate"


func _on_regenerate_asset(name: String, data: Dictionary, asset_type: String, btn: Button) -> void:
	btn.disabled = true
	btn.text = "..."
	if not _asset_generator.regenerate(name, data, asset_type):
		btn.disabled = false
		btn.text = "Regen"


# ==================== WORLD RUNNER ====================

func _run_world() -> void:
	var editor := _get_editor_interface()
	if not editor:
		_chat_handler.sys("Cannot run - editor interface not available", Color.RED)
		return

	var scene_path := _world_builder.get_current_world_path()
	if scene_path.is_empty():
		scene_path = "res://game/world.tscn"

	if not ResourceLoader.exists(scene_path):
		_chat_handler.sys("World scene not found at " + scene_path + "\nCreate a world first using chat!", Color.RED)
		return

	_chat_handler.sys("Launching: " + scene_path, Color.CYAN)
	editor.play_custom_scene(scene_path)


# ==================== HELPERS ====================

func set_plugin_reference(p: EditorPlugin) -> void:
	_plugin_reference = p


func _get_editor_interface() -> EditorInterface:
	if _plugin_reference and is_instance_valid(_plugin_reference):
		return _plugin_reference.get_editor_interface()
	return null
