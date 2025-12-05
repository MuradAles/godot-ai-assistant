# Product Requirements Document (PRD)
# Godot AI Game Generator Plugin

**Version:** 2.0
**Target Platform:** Godot 4.5
**Last Updated:** December 2024

---

## 1. Executive Summary

### 1.1 Product Vision
A conversational AI game builder for Godot. Users describe their game step-by-step in natural language, and the plugin generates a playable game in real-time. The game is always playable with colored placeholders, and AI-generated assets can be added anytime to enhance visuals.

### 1.2 Core Value Proposition
```
User describes game in chat
        ↓
Playable game with colored boxes (instant)
        ↓
User refines: "add trees", "player can swim"
        ↓
Claude generates code for each feature
        ↓
User generates AI art when ready (optional)
        ↓
Polished game with real sprites
```

### 1.3 Key Principles
1. **Always Playable** - Colored placeholders mean the game works immediately
2. **Conversational** - Natural language, not forms or menus
3. **Iterative** - Build piece by piece, test constantly
4. **AI-Powered** - Claude generates all game code, Replicate generates art

### 1.4 Target Users
- Indie game developers wanting rapid prototyping
- Non-programmers interested in game creation
- Educators teaching game development concepts
- Game jam participants needing quick iterations

---

## 2. User Flow

### 2.1 Complete Game Creation Flow

```
┌─────────────────────────────────────────────────────────────┐
│  PHASE 1: MAP GENERATION                                    │
├─────────────────────────────────────────────────────────────┤
│  User: "Create an RPG with a beach and forest"              │
│  Plugin: Generates island map with water → sand → grass     │
│  Result: Colored boxes, immediately playable                │
│                                                             │
│  User: "Regenerate" / "Make it bigger" / "More water"       │
│  Plugin: Adjusts and regenerates                            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  PHASE 2: OBJECTS                                           │
├─────────────────────────────────────────────────────────────┤
│  User: "Add trees in the forest"                            │
│  Plugin: Places tree objects (green rectangles)             │
│                                                             │
│  User: "Add rocks near the water"                           │
│  Plugin: Places rock objects (gray rectangles)              │
│                                                             │
│  User: "Add a house in the center"                          │
│  Plugin: Places house structure                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  PHASE 3: CHARACTERS                                        │
├─────────────────────────────────────────────────────────────┤
│  User: "Create a player character"                          │
│  Plugin: Spawns player with WASD movement (blue rectangle)  │
│                                                             │
│  User: "Add an NPC shopkeeper near the house"               │
│  Plugin: Spawns NPC at location                             │
│                                                             │
│  User: "Add enemies that wander around"                     │
│  Plugin: Claude generates wandering AI script               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  PHASE 4: MECHANICS                                         │
├─────────────────────────────────────────────────────────────┤
│  User: "Player can cut trees and get wood"                  │
│  Plugin: Claude generates interaction + inventory code      │
│                                                             │
│  User: "Player can't swim in deep water"                    │
│  Plugin: Claude generates water collision logic             │
│                                                             │
│  User: "Player can sell wood to shopkeeper"                 │
│  Plugin: Claude generates shop/transaction system           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  ANYTIME: AI ART GENERATION                                 │
├─────────────────────────────────────────────────────────────┤
│  User clicks "Generate Art" for any asset                   │
│  Plugin: Calls Replicate API                                │
│  Result: Colored box replaced with pixel art sprite         │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Flexible Phase Navigation
The phases are guidelines, not strict requirements. User can:
- Add mechanics before finishing objects
- Go back and modify the map after adding characters
- Generate art for some assets while leaving others as placeholders

---

## 3. Technical Architecture

### 3.1 Visual Layer System

```
LAYER 1: Placeholders (Always Available)
┌─────────────────────────────────────┐
│  Terrain: Colored rectangles        │
│  - Water: Blue                      │
│  - Sand: Yellow                     │
│  - Grass: Green                     │
│                                     │
│  Objects: Simple shapes             │
│  - Trees: Green circles on brown    │
│  - Rocks: Gray ovals                │
│  - Houses: Orange rectangles        │
│                                     │
│  Characters: Colored rectangles     │
│  - Player: Blue with face dots      │
│  - NPCs: Various colors             │
└─────────────────────────────────────┘
            ↓ (User generates art)
LAYER 2: AI-Generated Sprites
┌─────────────────────────────────────┐
│  Replicate API generates:           │
│  - Terrain tiles (seamless)         │
│  - Object sprites (transparent bg)  │
│  - Character sprites                │
│                                     │
│  Sprites replace placeholders       │
│  Game logic unchanged               │
└─────────────────────────────────────┘
```

### 3.2 Memory Bank (JSON State)

All game state persisted in `res://game_project.json`:

```json
{
  "version": "1.0",
  "project_name": "My RPG",
  "created_at": "2024-12-04T10:00:00Z",
  "updated_at": "2024-12-04T12:30:00Z",

  "world": {
    "width": 128,
    "height": 128,
    "seed": 12345,
    "theme": "beach",
    "terrains": ["water", "sand", "grass"],
    "generated": true
  },

  "objects": {
    "trees": {
      "count": 50,
      "placement": "forest_areas",
      "sprite_generated": false
    },
    "rocks": {
      "count": 20,
      "placement": "near_water",
      "sprite_generated": true,
      "sprite_path": "res://assets/objects/rock.png"
    }
  },

  "characters": {
    "player": {
      "name": "Hero",
      "spawn": "center",
      "sprite_generated": false,
      "abilities": ["move", "interact"],
      "script_path": "res://scripts/player.gd"
    },
    "npcs": [
      {
        "id": "shopkeeper",
        "name": "Bob",
        "position": [64, 64],
        "behavior": "stationary",
        "dialogue": true
      }
    ]
  },

  "mechanics": [
    {
      "id": "tree_cutting",
      "description": "Player can cut trees to get wood",
      "script_path": "res://scripts/mechanics/tree_cutting.gd",
      "enabled": true
    },
    {
      "id": "inventory",
      "description": "Player has inventory for items",
      "script_path": "res://scripts/mechanics/inventory.gd",
      "enabled": true
    }
  ],

  "conversation_history": [
    {"role": "user", "content": "Create an RPG with beach and forest"},
    {"role": "assistant", "content": "Created island world with water, sand, grass..."}
  ]
}
```

### 3.3 Claude Code Generation

Claude generates ALL game code. No templates.

**System Prompt Requirements:**
- Godot 4.5 GDScript syntax
- Use `TileMapLayer` (not deprecated `TileMap`)
- Use `@export` for exposed variables
- Use `signal_name.emit()` for signals
- Proper node paths and scene structure

**Code Generation Flow:**
```
1. User request: "Player can cut trees"
2. Plugin sends to Claude with:
   - System prompt (Godot 4.5 knowledge)
   - Current game state (from memory bank)
   - Specific request
3. Claude returns GDScript code
4. Plugin validates syntax (GDScript.reload())
5. If error: Send error back to Claude, retry (max 3)
6. If success: Save script, attach to node
7. Update memory bank
```

### 3.4 Map Generation

Uses FastNoiseLite for procedural terrain:

```gdscript
# Terrain distribution based on elevation
# Low elevation = water (edges)
# Mid elevation = sand (transition)
# High elevation = grass/forest (center)

# Island-style: Distance from center affects elevation
var center = Vector2(width/2, height/2)
var distance = position.distance_to(center) / max_distance
var elevation = noise.get_noise_2d(x, y) - distance * 0.5

# Terrain thresholds
if elevation < 0.3: return WATER
if elevation < 0.45: return SAND
return GRASS
```

**Terrain Transitions:**
- Adjacent terrains only (water ↔ sand ↔ grass)
- No skipping (water never touches grass directly)
- Transitions rendered via Replicate-generated tilesets

---

## 4. Plugin Structure

### 4.1 File Structure
```
addons/ai_assistant/
├── plugin.cfg
├── plugin.gd                    # Main EditorPlugin
├── ui/
│   ├── ai_assistant_dock.tscn   # Main dock UI
│   └── ai_assistant_dock.gd     # Chat + Assets tabs
├── core/
│   ├── game_state.gd            # Memory bank manager
│   ├── ai_streaming.gd          # Claude API streaming
│   ├── script_validator.gd      # GDScript validation
│   ├── code_injector.gd         # Attach scripts to nodes
│   └── asset_manager.gd         # Track generated assets
├── api/
│   └── replicate_client.gd      # Replicate API for art
├── world/
│   ├── world_generator.gd       # Noise-based terrain
│   └── world_runner.gd          # Runtime world display
└── prompts/
    ├── system_prompt.md         # Claude system prompt
    └── godot_knowledge.md       # Godot 4.5 reference
```

### 4.2 Generated Project Structure
```
res://
├── game_project.json            # Memory bank
├── Main.tscn                    # Entry point
├── assets/
│   ├── terrain/                 # Generated terrain sprites
│   ├── objects/                 # Tree, rock, house sprites
│   └── characters/              # Player, NPC sprites
├── scripts/
│   ├── player.gd                # Player controller
│   ├── npc.gd                   # NPC behaviors
│   └── mechanics/               # Feature scripts
│       ├── tree_cutting.gd
│       ├── inventory.gd
│       └── shop.gd
└── scenes/
    ├── Player.tscn
    ├── NPC.tscn
    └── objects/
        ├── Tree.tscn
        └── Rock.tscn
```

---

## 5. External APIs

### 5.1 Claude API (Code Generation)

```
Endpoint: https://api.anthropic.com/v1/messages
Models: claude-sonnet-4-5-20250929, claude-opus-4-5-20251101

Used for:
- Understanding user intent
- Generating GDScript code
- Creating game mechanics
- Conversation and guidance
```

### 5.2 Replicate API (Art Generation)

```
Endpoint: https://api.replicate.com/v1/predictions
Model: retro-diffusion/rd-tile

Used for:
- Terrain tile sprites
- Object sprites (trees, rocks, houses)
- Character sprites

Prompt style:
"pixel art [object], top-down RPG game asset, transparent background"
```

---

## 6. Success Criteria

### 6.1 Core Functionality
- [ ] User can create playable game from chat in < 2 minutes
- [ ] Colored placeholder world generates instantly
- [ ] Claude generates valid GDScript for mechanics
- [ ] Script validation catches errors before crashing
- [ ] Memory bank persists all state across sessions

### 6.2 User Experience
- [ ] Conversation feels natural, not like filling forms
- [ ] Game is always playable at every step
- [ ] Clear feedback on what was created/changed
- [ ] Easy to iterate ("make it bigger", "add more trees")

### 6.3 Code Quality
- [ ] Generated GDScript follows Godot 4.5 best practices
- [ ] No deprecated API usage
- [ ] Scripts are readable and modifiable by user
- [ ] Clean separation of concerns (player.gd, inventory.gd, etc.)

---

## 7. Out of Scope (v1.0)

- 3D game generation
- Multiplayer networking
- Audio/music generation
- Custom shaders
- Mobile export optimization
- Complex AI pathfinding (A* etc.)

---

## 8. Glossary

| Term | Definition |
|------|------------|
| **Memory Bank** | JSON file storing all game state |
| **Placeholder** | Colored shape representing an object before AI art |
| **Mechanic** | Game feature with code (inventory, combat, etc.) |
| **Code Injection** | Attaching generated scripts to scene nodes |
| **Terrain Ring** | Concentric terrain distribution (water outside, land inside) |
| **TileMapLayer** | Godot 4.5 node for tile-based maps |
