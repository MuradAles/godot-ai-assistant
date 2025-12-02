# Godot AI Assistant Plugin

An AI-powered development assistant for Godot Engine, similar to Lovable, that helps users build games using natural language prompts.

## Setup

1. **Download Godot** (if you haven't already):
   - Get the latest version from https://godotengine.org/download
   - No need to build from source!

2. **Create/Open a Godot Project**:
   - Open Godot
   - Create a new project or open an existing one
   - The plugin is already in `addons/ai_assistant/`

3. **Enable the Plugin**:
   - Go to `Project → Project Settings → Plugins`
   - Find "AI Assistant" and enable it
   - The AI Assistant dock will appear in the editor

## Development Workflow

### In Cursor (Your IDE):
1. Edit plugin files in `addons/ai_assistant/`
2. Write GDScript code for AI integration
3. Save files

### In Godot:
1. Godot auto-reloads scripts when you save
2. Test your changes immediately
3. No compilation needed - GDScript is interpreted!

## Project Structure

```
godot-ai-assistant/
├── addons/
│   └── ai_assistant/
│       ├── plugin.cfg          # Plugin configuration
│       ├── plugin.gd           # Main plugin script
│       └── ui/
│           ├── ai_assistant_dock.gd
│           └── ai_assistant_dock.tscn
└── README.md
```

## Next Steps

1. **Integrate AI API**: Connect to OpenAI, Anthropic, or your preferred AI service
2. **Code Generation**: Implement logic to generate GDScript code from prompts
3. **Scene Creation**: Add ability to create scenes/nodes from AI descriptions
4. **File Management**: Auto-create scripts and resources

## Testing

1. Open this project in Godot
2. Enable the plugin
3. Use the AI Assistant dock to test features


