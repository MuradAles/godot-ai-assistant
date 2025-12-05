@tool
class_name SettingsManager
extends RefCounted

## Handles settings dialog, loading, and saving

signal settings_saved(api_key: String, replicate_key: String, ai_model: String)

const SETTINGS_PATH := "user://ai_assistant_settings.cfg"

const AI_MODELS := {
	"Claude Sonnet 4.5": "claude-sonnet-4-5-20250929",
	"Claude Opus 4.5": "claude-opus-4-5-20251101"
}

var _settings_dialog: Window = null
var _parent_node: Node

# Current settings
var api_key := ""
var replicate_key := ""
var ai_model := "claude-sonnet-4-5-20250929"


func setup(parent_node: Node) -> void:
	_parent_node = parent_node


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		api_key = cfg.get_value("settings", "api_key", "")
		replicate_key = cfg.get_value("settings", "replicate_key", "")
		ai_model = cfg.get_value("settings", "ai_model", "claude-sonnet-4-5-20250929")


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "api_key", api_key)
	cfg.set_value("settings", "replicate_key", replicate_key)
	cfg.set_value("settings", "ai_model", ai_model)
	cfg.save(SETTINGS_PATH)


func open_dialog() -> void:
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
	key_input.text = api_key
	key_input.placeholder_text = "sk-ant-..."
	vbox.add_child(key_input)

	# AI Model Selection
	vbox.add_child(_make_label("AI Model:"))
	var model_select := OptionButton.new()
	var idx := 0
	var selected_idx := 0
	for model_name in AI_MODELS:
		model_select.add_item(model_name)
		if AI_MODELS[model_name] == ai_model:
			selected_idx = idx
		idx += 1
	model_select.selected = selected_idx
	vbox.add_child(model_select)

	# Replicate API Key
	vbox.add_child(_make_label("Replicate API Key (for assets):"))
	var rep_input := LineEdit.new()
	rep_input.secret = true
	rep_input.text = replicate_key
	rep_input.placeholder_text = "r8_..."
	vbox.add_child(rep_input)

	# Save button
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(func():
		api_key = key_input.text
		replicate_key = rep_input.text
		var selected_name: String = model_select.get_item_text(model_select.selected)
		ai_model = AI_MODELS.get(selected_name, "claude-sonnet-4-5-20250929")
		save_settings()
		_settings_dialog.hide()
		settings_saved.emit(api_key, replicate_key, ai_model)
	)
	vbox.add_child(save_btn)

	_parent_node.add_child(_settings_dialog)
	_settings_dialog.popup_centered()


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	return lbl


func get_model_display_name() -> String:
	for name in AI_MODELS:
		if AI_MODELS[name] == ai_model:
			return name
	return "Unknown"
