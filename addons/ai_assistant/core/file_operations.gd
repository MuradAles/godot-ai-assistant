@tool
class_name AIFileOperations
extends RefCounted

## Handles file creation, editing, and deletion for the AI assistant

signal file_created(path: String)
signal file_edited(path: String)
signal file_deleted(path: String)
signal file_error(path: String, error: String)

# Blocked paths - never write to these
const BLOCKED_PATHS: Array[String] = [
	"project.godot",
	"addons/",
	".godot/",
	".git/",
	"plugin.cfg"
]


## Process file operations from AI response (CREATE, EDIT, DELETE)
func process_response(text: String) -> Dictionary:
	var result := {
		"created": [],
		"edited": [],
		"deleted": [],
		"errors": []
	}

	# Process ===FILE: path=== (CREATE/OVERWRITE)
	var created := _process_create_operations(text)
	result["created"] = created

	# Process ===EDIT: path=== (MODIFY EXISTING)
	var edited := _process_edit_operations(text)
	result["edited"] = edited

	# Process ===DELETE: path=== (REMOVE FILE)
	var deleted := _process_delete_operations(text)
	result["deleted"] = deleted

	return result


func _process_create_operations(text: String) -> Array:
	var created: Array = []
	var search_pos := 0

	while true:
		var start_marker := "===FILE: "
		var start_pos := text.find(start_marker, search_pos)
		if start_pos == -1:
			break

		var path_start := start_pos + start_marker.length()
		var path_end := text.find("===", path_start)
		if path_end == -1:
			break

		var file_path := text.substr(path_start, path_end - path_start).strip_edges()

		if _is_blocked(file_path):
			search_pos = path_end + 3
			continue

		var content_start := path_end + 3
		if content_start < text.length() and text[content_start] == "\n":
			content_start += 1

		var end_marker := "===END_FILE==="
		var end_pos := text.find(end_marker, content_start)
		if end_pos == -1:
			search_pos = path_end + 3
			continue

		var file_content := text.substr(content_start, end_pos - content_start).strip_edges()

		if create_file(file_path, file_content):
			created.append(file_path)
			file_created.emit(file_path)
		else:
			file_error.emit(file_path, "Failed to create")

		search_pos = end_pos + end_marker.length()

	return created


func _process_edit_operations(text: String) -> Array:
	var edited: Array = []
	var search_pos := 0

	while true:
		var start_marker := "===EDIT: "
		var start_pos := text.find(start_marker, search_pos)
		if start_pos == -1:
			break

		var path_start := start_pos + start_marker.length()
		var path_end := text.find("===", path_start)
		if path_end == -1:
			break

		var file_path := text.substr(path_start, path_end - path_start).strip_edges()

		if _is_blocked(file_path):
			search_pos = path_end + 3
			continue

		var old_marker := "===OLD==="
		var new_marker := "===NEW==="
		var end_marker := "===END_EDIT==="

		var old_pos := text.find(old_marker, path_end)
		var new_pos := text.find(new_marker, path_end)
		var end_pos := text.find(end_marker, path_end)

		if old_pos == -1 or new_pos == -1 or end_pos == -1:
			search_pos = path_end + 3
			continue

		var old_content := text.substr(old_pos + old_marker.length(), new_pos - old_pos - old_marker.length()).strip_edges()
		var new_content := text.substr(new_pos + new_marker.length(), end_pos - new_pos - new_marker.length()).strip_edges()

		if edit_file(file_path, old_content, new_content):
			edited.append(file_path)
			file_edited.emit(file_path)
		else:
			file_error.emit(file_path, "Failed to edit")

		search_pos = end_pos + end_marker.length()

	return edited


func _process_delete_operations(text: String) -> Array:
	var deleted: Array = []
	var search_pos := 0

	while true:
		var start_marker := "===DELETE: "
		var start_pos := text.find(start_marker, search_pos)
		if start_pos == -1:
			break

		var path_start := start_pos + start_marker.length()
		var path_end := text.find("===", path_start)
		if path_end == -1:
			break

		var file_path := text.substr(path_start, path_end - path_start).strip_edges()

		if _is_blocked(file_path):
			search_pos = path_end + 3
			continue

		if delete_file(file_path):
			deleted.append(file_path)
			file_deleted.emit(file_path)
		else:
			file_error.emit(file_path, "Failed to delete")

		search_pos = path_end + 3

	return deleted


func _is_blocked(file_path: String) -> bool:
	for blocked in BLOCKED_PATHS:
		if file_path.contains(blocked):
			return true
	return false


## Create a file safely
func create_file(file_path: String, content: String) -> bool:
	if _is_blocked(file_path):
		return false

	# Ensure path starts with res://
	if not file_path.begins_with("res://"):
		file_path = "res://" + file_path

	# Create directories if needed
	var dir_path := file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Strip UIDs from .tscn files
	if file_path.ends_with(".tscn"):
		content = strip_uids_from_tscn(content)

	# Write file
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false

	file.store_string(content)
	file.close()
	return true


## Edit a file by replacing old content with new
func edit_file(file_path: String, old_content: String, new_content: String) -> bool:
	if _is_blocked(file_path):
		return false

	if not file_path.begins_with("res://"):
		file_path = "res://" + file_path

	if not FileAccess.file_exists(file_path):
		return false

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false

	var current := file.get_as_text()
	file.close()

	if not current.contains(old_content):
		# Try with normalized whitespace
		var normalized_current := current.replace("\r\n", "\n").strip_edges()
		var normalized_old := old_content.replace("\r\n", "\n").strip_edges()
		if not normalized_current.contains(normalized_old):
			return false
		current = normalized_current
		old_content = normalized_old

	var updated := current.replace(old_content, new_content)

	file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		return false

	file.store_string(updated)
	file.close()
	return true


## Delete a file safely
func delete_file(file_path: String) -> bool:
	if _is_blocked(file_path):
		return false

	if not file_path.begins_with("res://"):
		file_path = "res://" + file_path

	if not FileAccess.file_exists(file_path):
		return false

	return DirAccess.remove_absolute(file_path) == OK


## Strip fake UIDs from .tscn files
func strip_uids_from_tscn(content: String) -> String:
	var result := content
	# Remove uid="uid://..." patterns
	var regex := RegEx.new()
	regex.compile('uid="uid://[^"]*"\\s*')
	result = regex.sub(result, "", true)
	return result
