# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot Engine plugin that provides an AI-powered game development assistant. Users can describe a game world in natural language, and the plugin generates procedural 2D worlds with AI-generated pixel art assets via the RetroDiffusion API.

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

### Core Components

```
addons/ai_assistant/
├── plugin.gd                    # EditorPlugin entry point
├── core/
│   ├── asset_manager.gd         # Manifest management (terrains, objects, transitions)
│   └── game_state.gd            # World state and chat history
├── api/
│   ├── replicate_client.gd      # RetroDiffusion API integration
│   └── claude_client.gd         # Claude AI for chat/world building
├── ui/
│   ├── ai_assistant_dock.gd     # Main dock UI with tabs (Chat, Assets, Settings)
│   ├── asset_generator.gd       # Orchestrates asset generation
│   └── chat_handler.gd          # Chat UI and AI response parsing
└── world/
    ├── world_runner.gd          # Runtime world display and player
    ├── world_assets.gd          # Asset loading from manifest
    ├── world_terrain.gd         # Procedural terrain generation (noise-based)
    ├── world_tilemap.gd         # TileMap building with variations
    └── world_transitions.gd     # Wang tile transition system
```

### Key Systems

**Asset Manifest** (`res://assets/manifest.json`):
- Stores all terrain, transition, object, and structure definitions
- Tracks generation status (generated/pending)
- Contains prompts for RetroDiffusion API
- Object sizes in tiles (width × height)
- Terrain spawn configurations (what objects appear on each terrain)

**RetroDiffusion API** (`replicate_client.gd`):
- Generates pixel art assets via Replicate API
- Styles: `single_tile`, `tileset_advanced`, `tile_object`, `scene_object`
- Terrain tiles: 16-64px single tiles
- Transitions: 4×5 Wang tile tilesets
- Objects: Sized by tiles (e.g., 2×4 tiles = 32×64px at 16px tile_size)

**World Generation** (`world_runner.gd`):
- Procedural terrain using FastNoiseLite
- Terrain elevation mapping (first terrain = lowest, last = highest)
- Random terrain variations (4 variations per terrain type)
- Wang tile transitions between adjacent terrains
- Object spawning based on terrain spawn rates

### Wang Tile System

Transitions use 4×5 Wang tilesets (16 tiles for all edge/corner combinations):
- `world_transitions.gd`: Calculates Wang index from neighbor analysis
- Y-axis is flipped to match RetroDiffusion tileset orientation
- `WANG_TO_RD` lookup maps Wang indices to atlas coordinates

### Object Sizing

Object sizes are specified in **tiles**, not pixels:
- Size `2×4` at `16px tile_size` = `32×64px` generated image
- Max sizes: `tile_object` (≤96×96px), `scene_object` (≤384×384px)
- Spinbox max: 24 tiles (384px at 16px)

## Important GDScript Conventions

- Use `@tool` annotation at top of scripts that run in the editor
- Use `@onready` for node references to ensure nodes exist before access
- Always use typed GDScript (`: Type`) for better error checking
- Signal connections: `button.pressed.connect(_on_button_pressed)`
- Use `res://` for resource paths (not absolute filesystem paths)
- File access: Use `FileAccess.open()` and `DirAccess.open()`

## Common Development Tasks

### Adding a New Asset Type
1. Add to manifest structure in `asset_manager.gd`
2. Add generation method in `replicate_client.gd`
3. Add case in `asset_generator.gd` `_start_generation()`
4. Add UI controls in `ai_assistant_dock.gd`

### Modifying Terrain Generation
- Noise parameters: `world_terrain.gd` `setup_noise()`
- Elevation mapping: `generate_terrain()`
- Spawn rates: Stored in manifest under `terrain[name].spawns`

### Debugging World Generation
- Check console for `[World]`, `[Replicate]`, `[WorldTilemap]` prefixed logs
- Wang index distribution logged when placing transitions
- Asset loading status logged per terrain/object

## Project Structure

```
res://
├── assets/                      # Generated assets (from manifest)
│   ├── terrain/                 # Terrain tiles
│   ├── transitions/             # Wang tile tilesets
│   ├── objects/                 # Object sprites (tree/, rock/, etc.)
│   └── manifest.json            # Asset definitions
├── addons/ai_assistant/         # Plugin code
└── project.godot                # Godot project config
```

## Current Features

- Chat-based world creation ("make a volcanic world with lava and crystals")
- Procedural terrain with noise-based elevation
- AI-generated pixel art via RetroDiffusion
- Wang tile transitions between terrain types
- Terrain variations (4 per type) with random placement
- Configurable object spawning per terrain (% chance per tile)
- Object size control (width × height in tiles)
- "All Terrain" global objects that spawn everywhere
- Live world preview with player movement (WASD/arrows)
