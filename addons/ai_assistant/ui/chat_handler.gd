@tool
class_name ChatHandler
extends RefCounted

## Handles chat UI, AI streaming, and conversation persistence

signal message_added(rtl: RichTextLabel, is_user: bool)
signal system_message(text: String, color: Color)
signal scroll_requested

var _chat_container: VBoxContainer
var _chat_scroll: ScrollContainer
var _game_state: RefCounted
var _ai_stream: RefCounted
var _api_key := ""
var _ai_model := "claude-sonnet-4-5-20250929"

# Streaming state
var _stream_rtl: RichTextLabel = null
var _stream_content := ""
var _is_processing := false
var _awaiting_ai_decision := false
var _pending_mechanic := ""

# Callbacks
var _on_ai_decision: Callable
var _on_mechanic_generated: Callable


func setup(chat_container: VBoxContainer, chat_scroll: ScrollContainer, game_state: RefCounted) -> void:
	_chat_container = chat_container
	_chat_scroll = chat_scroll
	_game_state = game_state

	# Load AI streaming
	var StreamScript = load("res://addons/ai_assistant/core/ai_streaming.gd")
	if StreamScript and StreamScript.can_instantiate():
		_ai_stream = StreamScript.new()
		_ai_stream.chunk_received.connect(_on_stream_chunk)
		_ai_stream.stream_finished.connect(_on_stream_finished)
		_ai_stream.stream_error.connect(_on_stream_error)


func set_api_key(key: String) -> void:
	_api_key = key


func set_model(model: String) -> void:
	_ai_model = model


func set_decision_callback(callback: Callable) -> void:
	_on_ai_decision = callback


func set_mechanic_callback(callback: Callable) -> void:
	_on_mechanic_generated = callback


func is_processing() -> bool:
	return _is_processing


func set_processing(value: bool) -> void:
	_is_processing = value


## Send a chat message and get AI decision
func send_message(text: String, pending_world: Dictionary) -> void:
	if text.is_empty():
		return

	if _is_processing:
		_sys("Still processing...", Color.YELLOW)
		return

	msg(text, true)

	if _api_key.is_empty():
		_sys("Set Claude API key in Settings first!", Color.RED)
		return

	_call_ai_for_decision(text, pending_world)


## Call AI to interpret user message and decide what to do
func _call_ai_for_decision(user_message: String, pending_world: Dictionary) -> void:
	_is_processing = true
	_awaiting_ai_decision = true

	_stream_rtl = msg("", false)
	_stream_content = ""

	# Build context
	var context := ""
	if _game_state:
		context = _game_state.get_context_for_claude()

	# Build pending world context if building
	var pending_context := ""
	if not pending_world.name.is_empty() or pending_world.terrains.size() > 0:
		pending_context = "\n\nCURRENT WORLD BEING BUILT:\n"
		pending_context += "- Name: " + (pending_world.name if not pending_world.name.is_empty() else "(not set)") + "\n"
		pending_context += "- Theme: " + str(pending_world.theme) + "\n"
		pending_context += "- Size: " + str(pending_world.size) + "\n"
		pending_context += "- Terrains: " + (", ".join(pending_world.terrains) if pending_world.terrains.size() > 0 else "(none)") + "\n"
		pending_context += "- Objects: " + (", ".join(pending_world.objects) if pending_world.objects.size() > 0 else "(none)") + "\n"
		pending_context += "- Features: " + (", ".join(pending_world.features) if pending_world.features.size() > 0 else "(none)") + "\n"

	var system_prompt := _build_system_prompt(context, pending_context)
	var messages := [{"role": "user", "content": user_message}]

	if _ai_stream:
		_ai_stream.start_stream(_api_key, "anthropic", _ai_model, messages, system_prompt)


func _build_system_prompt(context: String, pending_context: String) -> String:
	return """You are the AI brain of a Godot game builder. Analyze the user's message and respond with BOTH:
1. A friendly conversational response to the user
2. A JSON action block that the system will execute

AVAILABLE ACTIONS:
- create_world: Start building a new world
- update_world: Add terrains, objects, or features to the world being built
- finalize_world: Actually create the world when user is ready
- add_object: Add objects to an existing world
- add_character: Add player or NPC
- generate_mechanic: Generate GDScript code for a game mechanic
- run_game: Start/test the game
- chat: Just conversation, no action needed

RESPONSE FORMAT:
Write your friendly response first, then on a new line add:
```json
{"action": "ACTION_NAME", "params": {...}}
```

PARAMS BY ACTION:
- create_world: {"name": "World Name", "theme": "forest/desert/snow/ocean/plains", "size": "small/medium/large", "terrains": ["water", "sand", "grass", "forest", "snow"], "objects": ["tree", "rock", "house"], "features": ["crafting", "combat", "inventory"]}
- update_world: {"terrains": [], "objects": [], "features": [], "size": "", "name": ""} (only include what's being added/changed)
- finalize_world: {} (no params needed)
- add_object: {"objects": ["tree"], "count": 5, "location": "forest"}
- add_character: {"type": "player/npc/enemy", "behavior": "stationary/wander/patrol"}
- generate_mechanic: {"description": "player can cut trees"}
- run_game: {}
- chat: {}

RULES:
1. Be conversational but ACTION-ORIENTED - prefer doing things over asking questions
2. When user describes a world, extract ALL details and START BUILDING immediately
3. IMPORTANT: If a world is already being built (see CURRENT WORLD BEING BUILT below), and user says anything like "create", "build", "make", "ok", "yes", "do it", "go ahead", "sounds good" - use finalize_world IMMEDIATELY
4. Don't ask unnecessary questions - infer sensible defaults and proceed
5. Infer things naturally - "cozy forest" means forest theme with trees
6. Always include the JSON block at the end

""" + context + pending_context


## Call AI to generate a game mechanic
func call_ai_for_mechanic(description: String) -> void:
	_is_processing = true
	_pending_mechanic = description

	_stream_rtl = msg("", false)
	_stream_content = ""

	var context := ""
	if _game_state:
		context = _game_state.get_context_for_claude()

	var system_prompt := """You are a Godot 4.5 GDScript generator.

RULES:
1. Use TileMapLayer (NOT TileMap - deprecated)
2. Use @export for configurable properties
3. Use signal_name.emit() syntax
4. Return ONLY valid GDScript code wrapped in ```gdscript code blocks
5. Include necessary extends statement
6. Handle edge cases (null checks, bounds)

""" + context + """

Generate GDScript code for the requested mechanic. Wrap the code in ```gdscript blocks."""

	var messages := [{"role": "user", "content": "Generate GDScript code for: " + description}]

	if _ai_stream:
		_ai_stream.start_stream(_api_key, "anthropic", _ai_model, messages, system_prompt)


func _on_stream_chunk(text: String) -> void:
	_stream_content += text
	if _stream_rtl:
		_stream_rtl.text = "[b]AI:[/b] " + _stream_content


func _on_stream_finished(full_response: String) -> void:
	_is_processing = false

	# Check if we were generating a mechanic
	if not _pending_mechanic.is_empty():
		if _on_mechanic_generated.is_valid():
			_on_mechanic_generated.call(full_response, _pending_mechanic)
		_pending_mechanic = ""
		return

	# Check if we were waiting for AI decision
	if _awaiting_ai_decision:
		_awaiting_ai_decision = false
		_parse_and_execute_ai_decision(full_response)


func _on_stream_error(error: String) -> void:
	_sys("Error: " + error, Color.RED)
	_is_processing = false


## Parse AI response and execute the action
func _parse_and_execute_ai_decision(response: String) -> void:
	# Extract JSON from response
	var json_regex := RegEx.new()
	json_regex.compile("```json\\s*\\n?([\\s\\S]*?)\\n?```")
	var match_result := json_regex.search(response)

	if not match_result:
		return

	var json_str: String = match_result.get_string(1).strip_edges()

	var json := JSON.new()
	var error := json.parse(json_str)
	if error != OK:
		_sys("Failed to parse AI decision: " + json.get_error_message(), Color.YELLOW)
		return

	var decision: Dictionary = json.data

	if _on_ai_decision.is_valid():
		_on_ai_decision.call(decision)


## Add a message to the chat
func msg(text: String, is_user: bool, save: bool = true) -> RichTextLabel:
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
	scroll_requested.emit()

	if save and text.length() > 0:
		_save_message(text, is_user)

	message_added.emit(rtl, is_user)
	return rtl


## Add a system message
func _sys(text: String, color: Color = Color.ORANGE) -> void:
	if not _chat_container:
		return
	var lbl := Label.new()
	lbl.text = "> " + text
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_container.add_child(lbl)
	scroll_requested.emit()
	system_message.emit(text, color)


func sys(text: String, color: Color = Color.ORANGE) -> void:
	_sys(text, color)


func clear() -> void:
	if _chat_container:
		for child in _chat_container.get_children():
			child.queue_free()
	if _game_state:
		_game_state.clear_conversation_history()


func restore_history() -> void:
	if not _game_state or not _chat_container:
		return

	var history: Array = _game_state.get_conversation_history()
	if history.is_empty():
		show_welcome()
		return

	for entry in history:
		var role: String = entry.get("role", "")
		var content: String = entry.get("content", "")
		if role == "user":
			msg(content, true, false)
		elif role == "assistant":
			msg(content, false, false)


func show_welcome() -> void:
	_sys("Welcome! I'm your AI game builder.", Color.CYAN)
	_sys("Just describe what you want in natural language:", Color.GRAY)
	_sys("  \"I want a cozy forest with trees and a crafting system\"", Color.GRAY)
	_sys("  \"Add some rocks and make the world bigger\"", Color.GRAY)
	_sys("  \"Player should be able to collect items\"", Color.GRAY)


func _save_message(content: String, is_user: bool) -> void:
	if _game_state:
		var role := "user" if is_user else "assistant"
		_game_state.add_message(role, content)
