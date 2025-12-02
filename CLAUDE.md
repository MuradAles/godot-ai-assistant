# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot Engine plugin that provides an AI-powered development assistant for game development, similar to Lovable. The plugin integrates into the Godot editor as a dock panel.

## Development Environment

**Engine**: Godot 4.5 (Forward Plus renderer)
**Language**: GDScript
**Plugin Location**: `addons/ai_assistant/`

## Testing the Plugin

Since this is a Godot editor plugin, you cannot run traditional test commands. Instead:

1. Open the project in Godot Engine
2. The plugin should auto-enable (already configured in `project.godot`)
3. If not enabled: Go to `Project → Project Settings → Plugins` and enable "AI Assistant"
4. The AI Assistant dock appears in the right panel of the editor
5. Make changes to `.gd` files - Godot auto-reloads scripts on save

**No compilation or build step required** - GDScript is interpreted.

## Architecture

### Plugin System

The plugin follows Godot's EditorPlugin architecture:

- `plugin.gd`: Main plugin script extending `EditorPlugin`
  - Manages plugin lifecycle (`_enter_tree()`, `_exit_tree()`)
  - Instantiates and adds the dock UI to `DOCK_SLOT_RIGHT_UR`
  - Passes self-reference to dock for accessing editor interface
  - Implements dock visibility toggling via `toggle_docks_visibility()`

- `ui/ai_assistant_dock.tscn` + `ui/ai_assistant_dock.gd`: The dock UI
  - Scene-based UI with VBoxContainer layout
  - Key nodes: `PromptInput` (TextEdit), `GenerateButton`, `OutputDisplay` (RichTextLabel)
  - Receives plugin reference via `set_plugin_reference()` to access editor APIs

### Key Plugin Features

**Dock Visibility Toggle**: The plugin can hide/show other editor docks (Scene, Inspector, FileSystem, etc.) while keeping the AI Assistant, game viewport, and bottom panel visible. This is done by traversing the editor's node tree to find TabContainers and selectively hiding them.

**Folder Import**: The dock includes functionality to import external folders into the project's `assets/` directory with recursive copying of files and subdirectories. After import, it triggers `get_resource_filesystem().scan()` to refresh Godot's filesystem view.

### Plugin Communication Pattern

```
plugin.gd (EditorPlugin)
    ↓ reference passed via set_plugin_reference()
ai_assistant_dock.gd (Control)
    ↓ can call plugin methods like toggle_docks_visibility()
    ↓ can access editor via plugin.get_editor_interface()
```

## Important GDScript Conventions

- Use `@tool` annotation at top of scripts that run in the editor
- Use `@onready` for node references to ensure nodes exist before access
- Always use typed GDScript (`: Type`) for better error checking
- Signal connections: `button.pressed.connect(_on_button_pressed)`
- Use `res://` for resource paths (not absolute filesystem paths)
- File access: Use `FileAccess.open()` and `DirAccess.open()`

## Task Management (Taskmaster)

This project uses **Taskmaster-AI** for task tracking. Tasks are stored in `.taskmaster/tasks/tasks.json`.

### Common Commands

```bash
# View all tasks
task-master list

# See next task to work on
task-master next

# View specific task details
task-master show <id>

# Start working on a task
task-master set-status --id=<id> --status=in-progress

# Mark task as done
task-master set-status --id=<id> --status=done

# Expand a task into subtasks
task-master expand --id=<id>
```

### Current Progress

- **Completed**: Plugin skeleton, dock UI, basic layout (Tasks 11-16)
- **Next**: Settings dialog, AI API integration (Tasks 17-22)

### Task Dependencies

Tasks have dependencies - complete prerequisite tasks first. Use `task-master list` to see which tasks are ready to work on.

## Next Development Steps

The plugin foundation is complete. Next priorities:
1. **Settings Dialog** (Task 18-19): API key input, provider/model selection
2. **AI Client** (Task 20-22): Claude and OpenAI API integration
3. **Response Parser** (Task 23): Extract code blocks from AI responses
4. **Script Generator** (Task 30): Write .gd files to project
5. **Scene Generator** (Task 33): Create .tscn files programmatically
