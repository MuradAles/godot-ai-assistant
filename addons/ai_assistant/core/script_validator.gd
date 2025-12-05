@tool
class_name ScriptValidator
extends RefCounted

## Validates GDScript code before using it
## Catches syntax errors without executing the code

signal validation_completed(result: Dictionary)


## Validates GDScript code for syntax errors.
## Returns a dictionary with:
## - valid: bool - whether the code is valid
## - error: String - error message if invalid
## - error_line: int - line number of error (-1 if none)
## - script: GDScript - the compiled script if valid
## - warnings: Array - list of potential issues
func validate(code: String) -> Dictionary:
	var result := {
		"valid": false,
		"error": "",
		"error_line": -1,
		"script": null,
		"warnings": []
	}

	# Empty code check
	if code.strip_edges().is_empty():
		result.error = "Code is empty"
		return result

	# Basic syntax checks before compilation
	var pre_check := _pre_validate(code)
	if not pre_check.valid:
		result.error = pre_check.error
		result.error_line = pre_check.line
		return result

	# Try to compile the script
	var script := GDScript.new()
	script.source_code = code

	var error := script.reload()

	if error == OK:
		result.valid = true
		result.script = script
		result.warnings = _check_warnings(code)
	else:
		result.error = _get_error_message(error)
		result.error_line = _find_error_line(code, error)

	validation_completed.emit(result)
	return result


## Validates code and saves it to a file if valid.
## Returns same structure as validate() plus:
## - saved: bool - whether the file was saved
## - path: String - the file path
func validate_and_save(code: String, path: String) -> Dictionary:
	var result := validate(code)
	result["saved"] = false
	result["path"] = path

	if result.valid:
		var dir := path.get_base_dir()
		_ensure_dir(dir)

		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(code)
			file.close()
			result.saved = true
		else:
			result.error = "Failed to save file: " + path
			result.valid = false

	return result


## Quick syntax checks before full compilation.
func _pre_validate(code: String) -> Dictionary:
	var result := {"valid": true, "error": "", "line": -1}
	var lines := code.split("\n")

	# Check for common issues
	var brace_count := 0
	var paren_count := 0
	var bracket_count := 0

	for i in range(lines.size()):
		var line := lines[i]
		var trimmed := line.strip_edges()

		# Count braces/parens
		for c in line:
			match c:
				"{": brace_count += 1
				"}": brace_count -= 1
				"(": paren_count += 1
				")": paren_count -= 1
				"[": bracket_count += 1
				"]": bracket_count -= 1

		# Check for deprecated TileMap usage
		if "TileMap" in line and "TileMapLayer" not in line:
			result.valid = false
			result.error = "Use TileMapLayer instead of TileMap (deprecated in Godot 4.5)"
			result.line = i + 1
			return result

		# Check for old signal syntax
		if ".emit(" in line and "signal" not in line:
			# This is actually correct - signal_name.emit()
			pass
		elif "emit_signal(" in line:
			result.valid = false
			result.error = "Use signal_name.emit() instead of emit_signal() in Godot 4.x"
			result.line = i + 1
			return result

		# Check for old connect syntax
		if ".connect(" in line and "Callable" not in line:
			# Check if using old string-based connect
			if '", self, "' in line or "', self, '" in line:
				result.valid = false
				result.error = "Use button.pressed.connect(_method) instead of old connect syntax"
				result.line = i + 1
				return result

	# Check unbalanced braces
	if brace_count != 0:
		result.valid = false
		result.error = "Unbalanced braces: %d open" % brace_count
		return result

	if paren_count != 0:
		result.valid = false
		result.error = "Unbalanced parentheses: %d open" % paren_count
		return result

	if bracket_count != 0:
		result.valid = false
		result.error = "Unbalanced brackets: %d open" % bracket_count
		return result

	return result


## Check for potential issues that don't prevent compilation.
func _check_warnings(code: String) -> Array:
	var warnings: Array = []
	var lines := code.split("\n")

	for i in range(lines.size()):
		var line := lines[i]
		var trimmed := line.strip_edges()

		# Warning: Using get_node without null check
		if "get_node(" in line and "if" not in line:
			warnings.append({
				"line": i + 1,
				"message": "Consider using get_node_or_null() or checking for null"
			})

		# Warning: Direct child access without checking
		if "$" in line and "if" not in line and "==" not in line:
			# $ is direct node access
			pass  # This is common, skip warning

		# Warning: Using yield (old coroutine syntax)
		if "yield" in trimmed and trimmed.begins_with("yield"):
			warnings.append({
				"line": i + 1,
				"message": "yield is deprecated, use await instead"
			})

		# Warning: Missing type hints
		if "var " in line and ":" not in line and "=" in line:
			# Variable without type hint
			pass  # This is a style preference, skip

	return warnings


## Convert error code to readable message.
func _get_error_message(error: int) -> String:
	match error:
		ERR_PARSE_ERROR:
			return "Syntax error in script"
		ERR_COMPILATION_FAILED:
			return "Compilation failed"
		ERR_INVALID_DATA:
			return "Invalid script data"
		ERR_CANT_CREATE:
			return "Cannot create script"
		ERR_UNAVAILABLE:
			return "Script unavailable"
		_:
			return "Script error: " + error_string(error)


## Try to find the line number of an error.
## GDScript doesn't expose this directly, so we do best effort.
func _find_error_line(code: String, _error: int) -> int:
	# Unfortunately, GDScript.reload() doesn't give us the line number
	# We'd need to parse the error output from console
	return -1


## Ensure a directory exists.
func _ensure_dir(path: String) -> void:
	var dir := DirAccess.open("res://")
	if dir:
		var relative := path.replace("res://", "")
		if not dir.dir_exists(relative):
			dir.make_dir_recursive(relative)


# ==================== HELPER METHODS ====================

## Extract GDScript code from Claude's response.
## Handles markdown code blocks and plain text.
func extract_code_from_response(response: String) -> String:
	var code := response

	# Check for markdown code block
	var gdscript_block := RegEx.new()
	gdscript_block.compile("```(?:gdscript|gd)?\\s*\\n([\\s\\S]*?)\\n```")
	var regex_result := gdscript_block.search(response)
	if regex_result:
		code = regex_result.get_string(1)
	else:
		# Try generic code block
		var generic_block := RegEx.new()
		generic_block.compile("```\\s*\\n([\\s\\S]*?)\\n```")
		regex_result = generic_block.search(response)
		if regex_result:
			code = regex_result.get_string(1)

	return code.strip_edges()


## Format validation result as a readable message.
func format_validation_result(result: Dictionary) -> String:
	if result.valid:
		var msg: String = "✓ Code is valid!"
		if result.warnings.size() > 0:
			msg += "\n\nWarnings:\n"
			for w in result.warnings:
				msg += "- Line %d: %s\n" % [w.line, w.message]
		return msg
	else:
		var error_text: String = result.get("error", "Unknown error")
		var msg: String = "✗ Validation failed\n\nError: " + error_text
		var error_line: int = result.get("error_line", -1)
		if error_line > 0:
			msg += " (line %d)" % error_line
		return msg
