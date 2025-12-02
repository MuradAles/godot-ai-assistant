@tool
extends Control

@onready var prompt_input: TextEdit = $VBoxContainer/PromptInput
@onready var generate_button: Button = $VBoxContainer/GenerateButton
@onready var output_display: RichTextLabel = $VBoxContainer/OutputDisplay
@onready var toggle_docks_button: Button = $VBoxContainer/ToggleDocksButton
@onready var import_folder_button: Button = $VBoxContainer/ImportFolderButton

var plugin_reference: EditorPlugin = null
var folder_dialog: EditorFileDialog = null

func _ready() -> void:
	print("[AI Assistant Dock] Ready")
	if generate_button:
		generate_button.pressed.connect(_on_generate_pressed)
	if toggle_docks_button:
		toggle_docks_button.pressed.connect(_on_toggle_docks_pressed)
	if import_folder_button:
		import_folder_button.pressed.connect(_on_import_folder_pressed)

func set_plugin_reference(plugin: EditorPlugin) -> void:
	plugin_reference = plugin

# ============== FOLDER IMPORT ==============

func _on_import_folder_pressed() -> void:
	# Create folder dialog if it doesn't exist
	if not folder_dialog:
		folder_dialog = EditorFileDialog.new()
		folder_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
		folder_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
		folder_dialog.title = "Select folder to import to assets/"
		folder_dialog.dir_selected.connect(_on_folder_selected)
		add_child(folder_dialog)
	
	folder_dialog.popup_centered_ratio(0.7)

func _on_folder_selected(path: String) -> void:
	if path.is_empty():
		return
	
	output_display.text = "Importing folder: " + path + "\n"
	_import_folder(path)

func _import_folder(source_folder: String) -> void:
	# Ensure assets folder exists in project
	var project_dir = DirAccess.open("res://")
	if not project_dir:
		output_display.text += "ERROR: Cannot access project folder\n"
		return
	
	if not project_dir.dir_exists("assets"):
		var err = project_dir.make_dir("assets")
		if err != OK:
			output_display.text += "ERROR: Cannot create assets/ folder\n"
			return
		output_display.text += "Created assets/ folder\n"
	
	# Open source folder
	var source_dir = DirAccess.open(source_folder)
	if not source_dir:
		output_display.text += "ERROR: Cannot open source folder\n"
		return
	
	# Copy all files from source folder to assets/
	var copied_count = 0
	source_dir.list_dir_begin()
	var item = source_dir.get_next()
	
	while item != "":
		if item.begins_with("."):
			item = source_dir.get_next()
			continue
		
		var source_path = source_folder + "/" + item
		var dest_path = "res://assets/" + item
		
		# Check if it's a file (not a directory)
		if not source_dir.current_is_dir():
			# Copy file
			var result = _copy_file(source_path, dest_path)
			if result:
				output_display.text += "Imported: " + item + "\n"
				copied_count += 1
			else:
				output_display.text += "Failed: " + item + "\n"
		else:
			# It's a subdirectory - copy it recursively
			var sub_count = _copy_directory(source_path, "res://assets/" + item)
			if sub_count > 0:
				output_display.text += "Imported folder: " + item + "/ (" + str(sub_count) + " files)\n"
				copied_count += sub_count
		
		item = source_dir.get_next()
	
	source_dir.list_dir_end()
	
	# Refresh filesystem so Godot sees the new files
	if plugin_reference:
		var ei = plugin_reference.get_editor_interface()
		if ei:
			ei.get_resource_filesystem().scan()
	
	output_display.text += "\nDone! Imported " + str(copied_count) + " file(s) to assets/\n"

func _copy_file(source_path: String, dest_path: String) -> bool:
	# Read source file
	var source_file = FileAccess.open(source_path, FileAccess.READ)
	if not source_file:
		return false
	
	var content = source_file.get_buffer(source_file.get_length())
	source_file.close()
	
	# Write to destination
	var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
	if not dest_file:
		return false
	
	dest_file.store_buffer(content)
	dest_file.close()
	return true

func _copy_directory(source_path: String, dest_path: String) -> int:
	# Create destination directory
	var project_dir = DirAccess.open("res://")
	if not project_dir:
		return 0
	
	# Convert dest_path from res:// to relative path for make_dir_recursive
	var relative_dest = dest_path.replace("res://", "")
	project_dir.make_dir_recursive(relative_dest)
	
	# Open source directory
	var source_dir = DirAccess.open(source_path)
	if not source_dir:
		return 0
	
	var copied_count = 0
	source_dir.list_dir_begin()
	var item = source_dir.get_next()
	
	while item != "":
		if item.begins_with("."):
			item = source_dir.get_next()
			continue
		
		var src = source_path + "/" + item
		var dst = dest_path + "/" + item
		
		if not source_dir.current_is_dir():
			if _copy_file(src, dst):
				copied_count += 1
		else:
			copied_count += _copy_directory(src, dst)
		
		item = source_dir.get_next()
	
	source_dir.list_dir_end()
	return copied_count

# ============== BUTTON HANDLERS ==============

func _on_generate_pressed() -> void:
	var prompt = prompt_input.text
	if prompt.is_empty():
		return
	output_display.text = "Generating code for: " + prompt

func _on_toggle_docks_pressed() -> void:
	if plugin_reference:
		plugin_reference.toggle_docks_visibility()
		if toggle_docks_button:
			if plugin_reference.docks_hidden:
				toggle_docks_button.text = "Show Docks"
			else:
				toggle_docks_button.text = "Hide Docks"
