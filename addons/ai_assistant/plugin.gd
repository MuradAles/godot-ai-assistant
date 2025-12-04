@tool
extends EditorPlugin

# AI Assistant Plugin for Godot
# Provides AI-powered code generation and game development assistance

var ai_assistant_dock: Control
var ai_assistant_ui: Control
var docks_hidden: bool = false
var editor_interface: EditorInterface
var hidden_docks = []  # Store references to hidden docks

func _enter_tree() -> void:
	print("[AI Plugin] _enter_tree called")
	editor_interface = get_editor_interface()

	# Create the AI Assistant dock
	var dock_scene = load("res://addons/ai_assistant/ui/ai_assistant_dock.tscn")
	print("[AI Plugin] dock_scene loaded: ", dock_scene != null)

	if dock_scene:
		ai_assistant_dock = dock_scene.instantiate()
		print("[AI Plugin] dock instantiated: ", ai_assistant_dock != null)

		# Add to dock first so the node is in the tree
		add_control_to_dock(DOCK_SLOT_RIGHT_UR, ai_assistant_dock)
		print("[AI Plugin] dock added to editor")

		# Set plugin reference
		ai_assistant_dock.set("_plugin_reference", self)
		print("[AI Plugin] plugin reference set")
	else:
		# Fallback: create a simple label if scene doesn't exist
		print("[AI Plugin] ERROR: Could not load dock scene!")
		ai_assistant_dock = Label.new()
		ai_assistant_dock.text = "AI Assistant\n(UI loading...)"
		add_control_to_dock(DOCK_SLOT_RIGHT_UR, ai_assistant_dock)

	# Add menu items
	add_tool_menu_item("AI Assistant Settings", _open_settings)

	print("AI Assistant plugin loaded!")

func _exit_tree() -> void:
	# Clean up
	remove_control_from_docks(ai_assistant_dock)
	ai_assistant_dock.queue_free()
	
	remove_tool_menu_item("AI Assistant Settings")
	
	print("AI Assistant plugin unloaded!")

func _enable_plugin() -> void:
	# Called when plugin is enabled
	pass

func _disable_plugin() -> void:
	# Called when plugin is disabled
	pass

func _open_settings() -> void:
	# Open plugin settings dialog through the dock
	if ai_assistant_dock and ai_assistant_dock.has_method("_on_settings_pressed"):
		ai_assistant_dock._on_settings_pressed()
	else:
		print("Opening AI Assistant settings...")

func toggle_docks_visibility() -> void:
	docks_hidden = !docks_hidden
	
	# Use alternative method to hide/show docks
	_toggle_docks_alternative(!docks_hidden)
	var status = "hidden" if docks_hidden else "shown"
	print("Docks ", status)

func _toggle_docks_alternative(visible: bool) -> void:
	# Hide entire dock containers (boxes/panels), not just tabs
	# Keep: Game viewport (center), AI Assistant (right), Output/Terminal (bottom)
	var base = editor_interface.get_base_control()
	if not base:
		return
	
	# Find all TabContainers (these are the dock boxes/panels)
	var tab_containers = _find_nodes_by_class(base, "TabContainer")
	
	for tab_container in tab_containers:
		# Check if this TabContainer is in the bottom panel (Output/Terminal area)
		# We want to keep bottom panel visible, so skip it entirely
		var parent = tab_container.get_parent()
		if parent:
			var parent_name = str(parent.name).to_lower()
			var parent_class = parent.get_class().to_lower()
			# Check if it's in the bottom panel area - skip it
			if "bottom" in parent_name or "bottom" in parent_class:
				continue
		
		# Check if this TabContainer has the docks we want to hide
		var has_target_docks = false
		var has_ai_assistant = false
		var tab_count = tab_container.get_tab_count()
		
		for i in range(tab_count):
			var tab_title = tab_container.get_tab_title(i)
			# Check if it has AI Assistant (we want to keep this)
			if "AI" in tab_title or "Assistant" in tab_title:
				has_ai_assistant = true
			# Check if it has docks we want to hide
			if tab_title in ["Scene", "Import", "FileSystem", "Inspector", "Node", "History"]:
				has_target_docks = true
		
		# If this container has target docks but NOT AI Assistant, hide the entire container
		if has_target_docks and not has_ai_assistant:
			# Hide the entire TabContainer (the whole box/panel)
			tab_container.visible = visible
			# Also try to hide the parent split container
			if parent and parent.get_class() != "EditorNode":
				parent.visible = visible

func _find_nodes_by_class(node: Node, target_class: String):
	var results = []
	if node.get_class() == target_class:
		results.append(node)
	for child in node.get_children():
		results.append_array(_find_nodes_by_class(child, target_class))
	return results

