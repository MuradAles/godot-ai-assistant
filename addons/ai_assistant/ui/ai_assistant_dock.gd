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
	_add_all_terrain_section()  # Global objects that spawn everywhere
	_add_asset_section("Transitions", _asset_manager.get_transitions(), "transition")
	# Objects are shown under each terrain's spawn list, not separately
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
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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

	# Name label
	var name_lbl := Label.new()
	name_lbl.text = name.capitalize()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

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
	var gen_btn: Button = null
	var regen_btn: Button = null
	var variation_btn: Button = null

	if not is_done:
		gen_btn = Button.new()
		gen_btn.text = "Generate"
		hbox.add_child(gen_btn)
	else:
		regen_btn = Button.new()
		regen_btn.text = "Regen"
		regen_btn.tooltip_text = "Regenerate this asset"
		hbox.add_child(regen_btn)

		# Add "+" button for terrain variations (only for generated terrains)
		if asset_type == "terrain":
			variation_btn = Button.new()
			variation_btn.text = "+"
			variation_btn.tooltip_text = "Generate a variation of this terrain"
			variation_btn.custom_minimum_size.x = 30
			hbox.add_child(variation_btn)

	# Show existing variations count for terrains
	if asset_type == "terrain" and _asset_manager:
		var variations: Array = _asset_manager.get_terrain_variations(name)
		if variations.size() > 0:
			var var_label := Label.new()
			var_label.text = "v" + str(variations.size())
			var_label.add_theme_font_size_override("font_size", 10)
			var_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
			var_label.tooltip_text = str(variations.size()) + " variations"
			hbox.add_child(var_label)

	vbox.add_child(hbox)

	# Editable prompt field
	var prompt_text: String = data.get("prompt", name)
	var prompt_edit := LineEdit.new()
	prompt_edit.text = prompt_text
	prompt_edit.placeholder_text = "Enter prompt for AI generation..."
	prompt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_edit.add_theme_font_size_override("font_size", 11)
	prompt_edit.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	# Save prompt when changed
	prompt_edit.text_changed.connect(_on_prompt_changed.bind(name, asset_type, data))
	vbox.add_child(prompt_edit)

	# Connect buttons after prompt_edit exists so we can pass it
	if gen_btn:
		gen_btn.pressed.connect(_on_generate_asset.bind(name, data, asset_type, gen_btn, prompt_edit))
	if regen_btn:
		regen_btn.pressed.connect(_on_regenerate_asset.bind(name, data, asset_type, regen_btn, prompt_edit))
	if variation_btn:
		variation_btn.pressed.connect(_on_generate_variation.bind(name, data, variation_btn, prompt_edit))

	# Add terrain spawns section (which objects spawn on this terrain)
	if asset_type == "terrain":
		_add_terrain_spawns_ui(vbox, name)

	# Add global spawn controls for objects (add to all terrains / remove from all)
	if asset_type == "object":
		_add_object_global_spawn_ui(vbox, name)

	_asset_container.add_child(vbox)


func _on_generate_asset(name: String, data: Dictionary, asset_type: String, btn: Button, prompt_edit: LineEdit) -> void:
	btn.disabled = true
	btn.text = "..."
	# Use the current prompt from the edit field
	var updated_data := data.duplicate()
	updated_data["prompt"] = prompt_edit.text
	if not _asset_generator.generate_single(name, updated_data, asset_type):
		btn.disabled = false
		btn.text = "Generate"


func _on_regenerate_asset(name: String, data: Dictionary, asset_type: String, btn: Button, prompt_edit: LineEdit) -> void:
	btn.disabled = true
	btn.text = "..."
	# Use the current prompt from the edit field
	var updated_data := data.duplicate()
	updated_data["prompt"] = prompt_edit.text
	if not _asset_generator.regenerate(name, updated_data, asset_type):
		btn.disabled = false
		btn.text = "Regen"


func _on_prompt_changed(new_text: String, name: String, asset_type: String, data: Dictionary) -> void:
	if not _asset_manager:
		return
	# Update the prompt in the manifest
	_asset_manager.update_prompt(name, asset_type, new_text, data)


func _on_generate_variation(name: String, data: Dictionary, btn: Button, prompt_edit: LineEdit) -> void:
	btn.disabled = true
	btn.text = "..."

	# Calculate next variation index
	var existing_variations: Array = _asset_manager.get_terrain_variations(name) if _asset_manager else []
	var next_index: int = existing_variations.size() + 1

	# Create variation data
	var variation_data := data.duplicate()
	variation_data["prompt"] = prompt_edit.text
	variation_data["variation_index"] = next_index

	if not _asset_generator.generate_single(name, variation_data, "terrain_variation"):
		btn.disabled = false
		btn.text = "+"
	else:
		_chat_handler.sys("Generating variation " + str(next_index) + " for " + name, Color.CYAN)


## Add "All Terrain" section - objects that spawn on every terrain
func _add_all_terrain_section() -> void:
	if not _asset_manager:
		return

	var terrains: Dictionary = _asset_manager.get_terrains()
	if terrains.is_empty():
		return

	# Header
	var header := Label.new()
	header.text = "All Terrain (spawns everywhere)"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	_asset_container.add_child(header)

	# Panel container
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.13, 0.1)
	panel_style.set_corner_radius_all(4)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.4, 0.35, 0.2)
	panel_style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Get objects that are on ALL terrains
	var global_objects: Array = _get_global_spawn_objects()
	var available_objects: Dictionary = _asset_manager.get_objects()

	# Header row with add button
	var header_row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Objects on all terrains:"
	label.add_theme_font_size_override("font_size", 11)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(label)

	var add_btn := Button.new()
	add_btn.text = "+ Add"
	add_btn.tooltip_text = "Add object to ALL terrains"
	add_btn.custom_minimum_size = Vector2(50, 22)
	add_btn.pressed.connect(_on_add_global_spawn.bind(vbox, available_objects))
	header_row.add_child(add_btn)
	vbox.add_child(header_row)

	# Show global objects
	if global_objects.is_empty():
		var empty := Label.new()
		empty.text = "(no global objects)"
		empty.add_theme_font_size_override("font_size", 10)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(empty)
	else:
		for obj_name in global_objects:
			_add_global_spawn_row(vbox, obj_name)

	panel.add_child(vbox)
	_asset_container.add_child(panel)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	_asset_container.add_child(spacer)


## Get objects that exist on ALL terrains (intersection)
func _get_global_spawn_objects() -> Array:
	if not _asset_manager:
		return []

	var terrains: Dictionary = _asset_manager.get_terrains()
	if terrains.is_empty():
		return []

	var terrain_names: Array = terrains.keys()
	if terrain_names.is_empty():
		return []

	# Start with objects from first terrain
	var first_terrain: String = terrain_names[0]
	var first_spawns: Array = _asset_manager.get_terrain_objects(first_terrain)
	var global_objects: Array = []

	for spawn in first_spawns:
		global_objects.append(spawn.get("object", ""))

	# Intersect with other terrains
	for i in range(1, terrain_names.size()):
		var terrain_name: String = terrain_names[i]
		var spawns: Array = _asset_manager.get_terrain_objects(terrain_name)
		var spawn_names: Array = []
		for spawn in spawns:
			spawn_names.append(spawn.get("object", ""))

		# Keep only objects that exist in this terrain too
		var new_global: Array = []
		for obj_name in global_objects:
			if obj_name in spawn_names:
				new_global.append(obj_name)
		global_objects = new_global

	return global_objects


## Add a row for a global spawn object
func _add_global_spawn_row(container: VBoxContainer, obj_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	# Check if generated
	var is_generated := false
	var obj_data: Dictionary = {}
	var file_path := ""
	if _asset_manager:
		var objects: Dictionary = _asset_manager.get_objects()
		if objects.has(obj_name):
			obj_data = objects[obj_name]
			is_generated = obj_data.get("generated", 0) > 0
			var folder: String = obj_data.get("folder", "objects/" + obj_name)
			file_path = folder + "/" + obj_name + "_01.png"

	# Thumbnail
	var thumb := Panel.new()
	thumb.custom_minimum_size = Vector2(24, 24)
	var thumb_style := StyleBoxFlat.new()
	thumb_style.bg_color = Color(0.2, 0.2, 0.2)
	thumb_style.set_corner_radius_all(3)
	thumb.add_theme_stylebox_override("panel", thumb_style)

	if is_generated and not file_path.is_empty():
		var full_path := "res://assets/" + file_path
		if ResourceLoader.exists(full_path):
			var tex := load(full_path) as Texture2D
			if tex:
				var tex_rect := TextureRect.new()
				tex_rect.texture = tex
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
				thumb.add_child(tex_rect)
	row.add_child(thumb)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = obj_name
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	# Gen/Regen button
	var gen_btn := Button.new()
	gen_btn.text = "Regen" if is_generated else "Gen"
	gen_btn.custom_minimum_size = Vector2(50, 22)
	gen_btn.pressed.connect(_on_generate_spawn_object.bind(obj_name, obj_data, gen_btn, is_generated))
	row.add_child(gen_btn)

	# Remove from all button
	var remove_btn := Button.new()
	remove_btn.text = "×"
	remove_btn.tooltip_text = "Remove from ALL terrains"
	remove_btn.custom_minimum_size = Vector2(24, 22)
	remove_btn.pressed.connect(_on_remove_global_spawn.bind(obj_name))
	row.add_child(remove_btn)

	container.add_child(row)


## Add dialog for global spawn
func _on_add_global_spawn(container: VBoxContainer, available_objects: Dictionary) -> void:
	var dialog := Window.new()
	dialog.title = "Add Object to All Terrains"
	dialog.size = Vector2i(280, 140)
	dialog.transient = true
	dialog.exclusive = true

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10

	var dropdown := OptionButton.new()
	dropdown.add_item("-- Select or type below --", 0)
	var idx := 1
	for obj_name in available_objects.keys():
		dropdown.add_item(obj_name, idx)
		idx += 1
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(dropdown)

	var custom_input := LineEdit.new()
	custom_input.placeholder_text = "Or type new: flower, coin..."
	custom_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(custom_input)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func(): dialog.queue_free())
	btn_row.add_child(cancel_btn)

	var add_btn := Button.new()
	add_btn.text = "Add to All"
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_btn.pressed.connect(_on_confirm_global_spawn.bind(dropdown, custom_input, dialog, available_objects))
	btn_row.add_child(add_btn)

	vbox.add_child(btn_row)
	dialog.add_child(vbox)

	add_child(dialog)
	dialog.popup_centered()


## Confirm adding global spawn
func _on_confirm_global_spawn(dropdown: OptionButton, custom_input: LineEdit, dialog: Window, available_objects: Dictionary) -> void:
	var obj_name := ""
	var custom_text := custom_input.text.strip_edges()
	if not custom_text.is_empty():
		obj_name = custom_text.to_lower().replace(" ", "_")
	elif dropdown.selected > 0:
		obj_name = dropdown.get_item_text(dropdown.selected)

	if obj_name.is_empty():
		_chat_handler.sys("Enter an object name", Color.YELLOW)
		return

	# Add to manifest if new
	if not available_objects.has(obj_name):
		var default_prompt := obj_name + ", top-down pixel art game sprite"
		_asset_manager.add_object(obj_name, default_prompt, 1)

	# Add to ALL terrains
	var terrains: Dictionary = _asset_manager.get_terrains()
	var added := 0
	for terrain_name in terrains.keys():
		var spawns: Array = _asset_manager.get_terrain_objects(terrain_name)
		var exists := false
		for spawn in spawns:
			if spawn.get("object") == obj_name:
				exists = true
				break
		if not exists:
			_asset_manager.add_terrain_object(terrain_name, obj_name, 2.0)
			added += 1

	if added > 0:
		_chat_handler.sys("Added " + obj_name + " to " + str(added) + " terrains", Color.GREEN)
	else:
		_chat_handler.sys(obj_name + " already on all terrains", Color.YELLOW)

	dialog.queue_free()
	_refresh_assets_tab()


## Remove object from all terrains
func _on_remove_global_spawn(obj_name: String) -> void:
	var terrains: Dictionary = _asset_manager.get_terrains()
	var removed := 0
	for terrain_name in terrains.keys():
		var spawns: Array = _asset_manager.get_terrain_objects(terrain_name)
		for spawn in spawns:
			if spawn.get("object") == obj_name:
				_asset_manager.remove_terrain_object(terrain_name, obj_name)
				removed += 1
				break

	if removed > 0:
		_chat_handler.sys("Removed " + obj_name + " from " + str(removed) + " terrains", Color.GRAY)
	_refresh_assets_tab()


## Add UI for configuring which objects spawn on a terrain
func _add_terrain_spawns_ui(container: VBoxContainer, terrain_name: String) -> void:
	if not _asset_manager:
		return

	var spawns: Array = _asset_manager.get_terrain_objects(terrain_name)
	var available_objects: Dictionary = _asset_manager.get_objects()

	# Main container with border/background
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.12)
	panel_style.set_corner_radius_all(4)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.25, 0.25, 0.25)
	panel_style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", panel_style)

	var spawns_box := VBoxContainer.new()
	spawns_box.add_theme_constant_override("separation", 4)

	# Header row
	var header_hbox := HBoxContainer.new()
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var spawns_label := Label.new()
	spawns_label.text = "Objects on this terrain:"
	spawns_label.add_theme_font_size_override("font_size", 11)
	spawns_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	spawns_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spawns_label)

	var add_spawn_btn := Button.new()
	add_spawn_btn.text = "+ Add"
	add_spawn_btn.tooltip_text = "Add object that spawns on this terrain"
	add_spawn_btn.custom_minimum_size = Vector2(50, 22)
	add_spawn_btn.pressed.connect(_on_add_terrain_spawn.bind(terrain_name, spawns_box, available_objects))
	header_hbox.add_child(add_spawn_btn)

	spawns_box.add_child(header_hbox)

	# Show existing spawns or empty message
	if spawns.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(no objects - click + Add)"
		empty_label.add_theme_font_size_override("font_size", 10)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		spawns_box.add_child(empty_label)
	else:
		for spawn in spawns:
			var obj_name: String = spawn.get("object", "")
			var percent: float = spawn.get("percent", 1.0)
			_add_spawn_row(spawns_box, terrain_name, obj_name, percent)

	panel.add_child(spawns_box)
	container.add_child(panel)


## Add a row for a single spawn configuration with thumbnail and generate button
func _add_spawn_row(container: VBoxContainer, terrain_name: String, obj_name: String, percent: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Check if object asset is generated
	var obj_data: Dictionary = {}
	var is_generated := false
	var file_path := ""
	if _asset_manager:
		var objects: Dictionary = _asset_manager.get_objects()
		if objects.has(obj_name):
			obj_data = objects[obj_name]
			is_generated = obj_data.get("generated", 0) > 0
			var folder: String = obj_data.get("folder", "objects/" + obj_name)
			file_path = folder + "/" + obj_name + "_01.png"

	# Thumbnail (24x24)
	var thumb := Panel.new()
	thumb.custom_minimum_size = Vector2(24, 24)
	var thumb_style := StyleBoxFlat.new()
	thumb_style.bg_color = Color(0.2, 0.2, 0.2)
	thumb_style.set_corner_radius_all(3)
	thumb.add_theme_stylebox_override("panel", thumb_style)

	if is_generated and not file_path.is_empty():
		var full_path := "res://assets/" + file_path
		if ResourceLoader.exists(full_path):
			var tex := load(full_path) as Texture2D
			if tex:
				var tex_rect := TextureRect.new()
				tex_rect.texture = tex
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
				thumb.add_child(tex_rect)
	row.add_child(thumb)

	# Object name label
	var obj_label := Label.new()
	obj_label.text = obj_name
	obj_label.add_theme_font_size_override("font_size", 11)
	obj_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	obj_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(obj_label)

	# Percent spinbox
	var spin := SpinBox.new()
	spin.min_value = 0.1
	spin.max_value = 100.0
	spin.step = 0.1
	spin.value = percent
	spin.suffix = "%"
	spin.custom_minimum_size.x = 70
	spin.tooltip_text = "Spawn chance per tile"
	spin.value_changed.connect(_on_spawn_percent_changed.bind(terrain_name, obj_name))
	row.add_child(spin)

	# Size controls (WxH)
	var obj_size: Vector2i = _asset_manager.get_object_size(obj_name) if _asset_manager else Vector2i(1, 1)

	var size_container := HBoxContainer.new()
	size_container.add_theme_constant_override("separation", 2)

	var w_spin := SpinBox.new()
	w_spin.min_value = 1
	w_spin.max_value = 24  # Up to 24 tiles (384px at 16px tile_size)
	w_spin.step = 1
	w_spin.value = obj_size.x
	w_spin.custom_minimum_size.x = 45
	w_spin.tooltip_text = "Width in tiles"
	w_spin.value_changed.connect(_on_object_size_changed.bind(obj_name, true))
	size_container.add_child(w_spin)

	var x_label := Label.new()
	x_label.text = "×"
	x_label.add_theme_font_size_override("font_size", 10)
	size_container.add_child(x_label)

	var h_spin := SpinBox.new()
	h_spin.min_value = 1
	h_spin.max_value = 24  # Up to 24 tiles (384px at 16px tile_size)
	h_spin.step = 1
	h_spin.value = obj_size.y
	h_spin.custom_minimum_size.x = 45
	h_spin.tooltip_text = "Height in tiles"
	h_spin.value_changed.connect(_on_object_size_changed.bind(obj_name, false))
	size_container.add_child(h_spin)

	row.add_child(size_container)

	# Generate/Regen button
	var gen_btn := Button.new()
	if is_generated:
		gen_btn.text = "Regen"
		gen_btn.tooltip_text = "Regenerate asset for " + obj_name
	else:
		gen_btn.text = "Gen"
		gen_btn.tooltip_text = "Generate asset for " + obj_name
	gen_btn.custom_minimum_size = Vector2(50, 22)
	gen_btn.pressed.connect(_on_generate_spawn_object.bind(obj_name, obj_data, gen_btn, is_generated))
	row.add_child(gen_btn)

	# Remove button
	var remove_btn := Button.new()
	remove_btn.text = "×"
	remove_btn.tooltip_text = "Remove " + obj_name + " from " + terrain_name
	remove_btn.custom_minimum_size = Vector2(24, 22)
	remove_btn.pressed.connect(_on_remove_terrain_spawn.bind(terrain_name, obj_name))
	row.add_child(remove_btn)

	container.add_child(row)


## Generate or regenerate asset for a spawn object
func _on_generate_spawn_object(obj_name: String, obj_data: Dictionary, btn: Button, is_regen: bool = false) -> void:
	if not _asset_generator:
		_chat_handler.sys("Asset generator not loaded!", Color.RED)
		return

	btn.disabled = true
	btn.text = "..."

	# Ensure object exists in manifest with default prompt if needed
	if obj_data.is_empty():
		obj_data = {"prompt": obj_name + ", top-down pixel art game sprite", "folder": "objects/" + obj_name, "generated": 0, "needed": 1}
		if _asset_manager:
			_asset_manager.add_object(obj_name, obj_data.get("prompt", ""), 1)

	# Reset if regenerating
	if is_regen and _asset_manager:
		_asset_manager.reset_object(obj_name)

	if _asset_generator.generate_single(obj_name, obj_data, "object"):
		var action := "Regenerating" if is_regen else "Generating"
		_chat_handler.sys(action + " " + obj_name + "...", Color.CYAN)
	else:
		btn.disabled = false
		btn.text = "Regen" if is_regen else "Gen"
		_chat_handler.sys("Failed to start generation - check API key", Color.YELLOW)


## Handler for "+" button to add a new spawn - simple dialog
func _on_add_terrain_spawn(terrain_name: String, container: VBoxContainer, available_objects: Dictionary) -> void:
	var dialog := Window.new()
	dialog.title = "Add Object to " + terrain_name.capitalize()
	dialog.size = Vector2i(280, 140)
	dialog.transient = true
	dialog.exclusive = true

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10

	# Dropdown for existing objects OR type new
	var dropdown := OptionButton.new()
	dropdown.add_item("-- Select or type below --", 0)
	var idx := 1
	for obj_name in available_objects.keys():
		dropdown.add_item(obj_name, idx)
		idx += 1
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(dropdown)

	# Custom input for new objects
	var custom_input := LineEdit.new()
	custom_input.placeholder_text = "Or type new: mushroom, crystal..."
	custom_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(custom_input)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func(): dialog.queue_free())
	btn_row.add_child(cancel_btn)

	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_btn.pressed.connect(_on_add_spawn_confirmed_simple.bind(terrain_name, dropdown, custom_input, dialog, available_objects))
	btn_row.add_child(add_btn)

	vbox.add_child(btn_row)
	dialog.add_child(vbox)

	add_child(dialog)
	dialog.popup_centered()


## Simple add spawn - just name, generate button is on the row
func _on_add_spawn_confirmed_simple(terrain_name: String, dropdown: OptionButton, custom_input: LineEdit, dialog: Window, available_objects: Dictionary) -> void:
	var obj_name := ""

	# Check custom input first
	var custom_text := custom_input.text.strip_edges()
	if not custom_text.is_empty():
		obj_name = custom_text.to_lower().replace(" ", "_")
	elif dropdown.selected > 0:
		obj_name = dropdown.get_item_text(dropdown.selected)

	if obj_name.is_empty():
		_chat_handler.sys("Enter an object name", Color.YELLOW)
		return

	# Check if already on this terrain
	var existing: Array = _asset_manager.get_terrain_objects(terrain_name)
	for spawn in existing:
		if spawn.get("object") == obj_name:
			_chat_handler.sys(obj_name + " already on " + terrain_name, Color.YELLOW)
			dialog.queue_free()
			return

	# Add to manifest if new object
	if not available_objects.has(obj_name):
		var default_prompt := obj_name + ", top-down pixel art game sprite"
		_asset_manager.add_object(obj_name, default_prompt, 1)

	# Add spawn to terrain
	_asset_manager.add_terrain_object(terrain_name, obj_name, 2.0)
	_chat_handler.sys("Added " + obj_name + " to " + terrain_name, Color.GREEN)

	dialog.queue_free()
	_refresh_assets_tab()


## Handler for percent spinbox change
func _on_spawn_percent_changed(value: float, terrain_name: String, obj_name: String) -> void:
	if _asset_manager:
		_asset_manager.set_terrain_object_percent(terrain_name, obj_name, value)


## Handler for object size change
func _on_object_size_changed(value: float, obj_name: String, is_width: bool) -> void:
	if not _asset_manager:
		return
	var current_size: Vector2i = _asset_manager.get_object_size(obj_name)
	var new_w: int = int(value) if is_width else current_size.x
	var new_h: int = int(value) if not is_width else current_size.y
	_asset_manager.set_object_size(obj_name, new_w, new_h)


## Handler for removing a spawn
func _on_remove_terrain_spawn(terrain_name: String, obj_name: String) -> void:
	if _asset_manager:
		_asset_manager.remove_terrain_object(terrain_name, obj_name)
		_chat_handler.sys("Removed " + obj_name + " from " + terrain_name, Color.GRAY)
	_refresh_assets_tab()


## Add UI for objects to spawn on all terrains globally
func _add_object_global_spawn_ui(container: VBoxContainer, obj_name: String) -> void:
	if not _asset_manager:
		return

	var terrains: Dictionary = _asset_manager.get_terrains()
	if terrains.is_empty():
		return

	# Count how many terrains this object spawns on
	var spawn_count := 0
	var terrain_list: Array[String] = []
	for terrain_name in terrains.keys():
		var spawns: Array = _asset_manager.get_terrain_objects(terrain_name)
		for spawn in spawns:
			if spawn.get("object") == obj_name:
				spawn_count += 1
				terrain_list.append(terrain_name)
				break

	# Container with border
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.15)
	panel_style.set_corner_radius_all(4)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.2, 0.25, 0.3)
	panel_style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", panel_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Status label
	var status_label := Label.new()
	if spawn_count == 0:
		status_label.text = "Spawns on: none"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		status_label.text = "Spawns on: " + ", ".join(terrain_list)
		status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(status_label)

	# + button (add to all terrains)
	var add_all_btn := Button.new()
	add_all_btn.text = "+"
	add_all_btn.tooltip_text = "Add " + obj_name + " to ALL terrains (2% each)"
	add_all_btn.custom_minimum_size = Vector2(28, 22)
	add_all_btn.pressed.connect(_on_add_object_to_all_terrains.bind(obj_name))
	hbox.add_child(add_all_btn)

	# - button (remove from all terrains)
	var remove_all_btn := Button.new()
	remove_all_btn.text = "−"
	remove_all_btn.tooltip_text = "Remove " + obj_name + " from ALL terrains"
	remove_all_btn.custom_minimum_size = Vector2(28, 22)
	remove_all_btn.disabled = spawn_count == 0
	remove_all_btn.pressed.connect(_on_remove_object_from_all_terrains.bind(obj_name))
	hbox.add_child(remove_all_btn)

	panel.add_child(hbox)
	container.add_child(panel)


## Add object to all terrains at default percent
func _on_add_object_to_all_terrains(obj_name: String) -> void:
	if not _asset_manager:
		return

	var terrains: Dictionary = _asset_manager.get_terrains()
	var added_count := 0

	for terrain_name in terrains.keys():
		# Check if already exists
		var spawns: Array = _asset_manager.get_terrain_objects(terrain_name)
		var already_exists := false
		for spawn in spawns:
			if spawn.get("object") == obj_name:
				already_exists = true
				break

		if not already_exists:
			_asset_manager.add_terrain_object(terrain_name, obj_name, 2.0)
			added_count += 1

	if added_count > 0:
		_chat_handler.sys("Added " + obj_name + " to " + str(added_count) + " terrains at 2%", Color.GREEN)
	else:
		_chat_handler.sys(obj_name + " already on all terrains", Color.YELLOW)

	_refresh_assets_tab()


## Remove object from all terrains
func _on_remove_object_from_all_terrains(obj_name: String) -> void:
	if not _asset_manager:
		return

	var terrains: Dictionary = _asset_manager.get_terrains()
	var removed_count := 0

	for terrain_name in terrains.keys():
		var spawns: Array = _asset_manager.get_terrain_objects(terrain_name)
		for spawn in spawns:
			if spawn.get("object") == obj_name:
				_asset_manager.remove_terrain_object(terrain_name, obj_name)
				removed_count += 1
				break

	if removed_count > 0:
		_chat_handler.sys("Removed " + obj_name + " from " + str(removed_count) + " terrains", Color.GRAY)

	_refresh_assets_tab()


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
