# Product Requirements Document (PRD)
# Godot AI Game Generator Plugin

**Version:** 1.0  
**Target Platform:** Godot 4.5  
**Last Updated:** December 2024

---

## 1. Executive Summary

### 1.1 Product Vision
A Godot Editor plugin that enables users to generate playable games by describing them in natural language. The plugin combines Claude AI for code/logic generation with Retro Diffusion's RD-Tile API for asset generation, creating a complete automated game development pipeline.

### 1.2 Core Value Proposition
```
User describes game in plain English
            ↓
Plugin generates playable Godot project
            ↓
User plays immediately
```

### 1.3 Target Users
- Indie game developers wanting rapid prototyping
- Non-programmers interested in game creation
- Educators teaching game development concepts
- Game jam participants needing quick iterations

---

## 2. Product Overview

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  GODOT AI GAME GENERATOR                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Claude    │    │   RD-Tile   │    │   Godot     │     │
│  │   Sonnet    │    │    API      │    │   Engine    │     │
│  │   (Brain)   │    │  (Artist)   │    │  (Output)   │     │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘     │
│         │                  │                  │             │
│         └────────┬─────────┴──────────────────┘             │
│                  │                                          │
│         ┌────────▼────────┐                                 │
│         │  Plugin Core    │                                 │
│         │  (Coordinator)  │                                 │
│         └─────────────────┘                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Plugin Interface Structure

The plugin provides two main tabs:

| Tab | Purpose | Primary API |
|-----|---------|-------------|
| **Chat** | Code generation, scene creation, game logic | Claude API |
| **Assets** | Tileset generation, sprites, visual assets | RD-Tile API |

---

## 3. Functional Requirements

### 3.1 Chat Tab Features

#### 3.1.1 Game Description Input
- Text input field for natural language game descriptions
- Support for multi-line descriptions
- Example prompts/suggestions for new users

#### 3.1.2 AI Analysis & Planning
- Parse user description to identify:
  - Game type (top-down, platformer, etc.)
  - Required terrains and assets
  - Entities (player, NPCs, items)
  - Game mechanics and logic
  - UI requirements

#### 3.1.3 Code Generation
- Generate valid GDScript for Godot 4.5
- Create scene structures (.tscn files)
- Implement game logic (movement, interactions, win/lose conditions)
- Connect signals between nodes

#### 3.1.4 Validation & Retry
- Syntax validation of generated GDScript
- Automatic retry on errors (max 3 attempts)
- Error feedback to Claude for correction

#### 3.1.5 Iterative Updates
- Support follow-up requests ("Add enemies", "Change speed")
- Modify existing generated files
- Preserve user customizations where possible

### 3.2 Assets Tab Features

#### 3.2.1 Tileset Generator
- Text prompt input for terrain description
- Tile size selection (16x16, 32x32)
- Preview of generated tileset
- Save to project functionality

#### 3.2.2 RD-Tile Integration
- Call RD-Tile API with style "tileset"
- Receive 4×5 grid (20 tiles) at 64×80 pixels for 16px tiles
- Consistent wang-style transition format

#### 3.2.3 Automatic TileSet Configuration
- Load generated PNG as TileSetAtlasSource
- Apply pre-mapped peering bits (RD_TILE_MAP)
- Configure terrain sets automatically
- Save as .tres resource

#### 3.2.4 Multi-Terrain Support
- Support terrain pairs (e.g., Water↔Sand, Sand↔Grass)
- Layered TileMapLayer approach for 3+ terrains
- Ring-based generation (terrains never skip layers)

### 3.3 Map Generation Features

#### 3.3.1 Procedural Generation
- FastNoiseLite-based terrain distribution
- Island, continent, or custom layouts
- Configurable thresholds for terrain boundaries

#### 3.3.2 Terrain Auto-Tiling
- Use `set_cells_terrain_connect()` for automatic tile selection
- Godot handles transition tile selection
- Support for multiple terrain layers

---

## 4. Technical Specifications

### 4.1 RD-Tile Tileset Format

#### 4.1.1 Output Specification
```
Dimensions: 64×80 pixels (for 16×16 tiles)
Grid: 4 columns × 5 rows = 20 tiles
Format: PNG with transitions
```

#### 4.1.2 RD_TILE_MAP Peering Configuration

The plugin uses a pre-analyzed mapping of RD-Tile's consistent output format:

```gdscript
const RD_TILE_MAP = {
    # Water tiles (terrain 0)
    0:  {pos: Vector2i(0,0), terrain: 0, ...},  # Solid water
    1:  {pos: Vector2i(1,0), terrain: 0, ...},  # BR corner sand
    2:  {pos: Vector2i(2,0), terrain: 0, ...},  # R+B edge sand
    3:  {pos: Vector2i(3,0), terrain: 0, ...},  # BL corner sand
    4:  {pos: Vector2i(0,1), terrain: 0, ...},  # Solid water (var)
    8:  {pos: Vector2i(0,2), terrain: 0, ...},  # Solid water (var)
    9:  {pos: Vector2i(1,2), terrain: 0, ...},  # T+TR edge sand
    11: {pos: Vector2i(3,2), terrain: 0, ...},  # T+L corner sand
    15: {pos: Vector2i(3,3), terrain: 0, ...},  # TR+BL corners
    19: {pos: Vector2i(3,4), terrain: 0, ...},  # TL+BR corners
    
    # Sand tiles (terrain 1)
    5:  {pos: Vector2i(1,1), terrain: 1, ...},  # TL+BL water
    6:  {pos: Vector2i(2,1), terrain: 1, ...},  # Solid sand
    7:  {pos: Vector2i(3,1), terrain: 1, ...},  # TR+BR water
    10: {pos: Vector2i(2,2), terrain: 1, ...},  # BL+BR water
    12: {pos: Vector2i(0,3), terrain: 1, ...},  # Solid sand (var)
    13: {pos: Vector2i(1,3), terrain: 1, ...},  # BR water
    14: {pos: Vector2i(2,3), terrain: 1, ...},  # BL water
    16: {pos: Vector2i(0,4), terrain: 1, ...},  # Solid sand (var)
    17: {pos: Vector2i(1,4), terrain: 1, ...},  # TR water
    18: {pos: Vector2i(2,4), terrain: 1, ...},  # TL water
}
```

#### 4.1.3 Peering Bit Values
Each tile includes 8 directional peering bits:
- `top`, `right`, `bottom`, `left` (cardinal)
- `top_left`, `top_right`, `bottom_left`, `bottom_right` (corners)

Values: `0` = terrain 0 (outside), `1` = terrain 1 (inside)

### 4.2 Godot 4.5 API Usage

#### 4.2.1 TileMapLayer (NOT deprecated TileMap)
```gdscript
var layer = TileMapLayer.new()
layer.tile_set = tileset_resource
layer.set_cells_terrain_connect(cells, terrain_set, terrain)
```

#### 4.2.2 TileSet Terrain Configuration
```gdscript
# Create terrain set
tileset.add_terrain_set()
tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)

# Add terrains
tileset.add_terrain(0)  # terrain_set 0, terrain 0
tileset.add_terrain(0)  # terrain_set 0, terrain 1

# Set peering bits on TileData
var tile_data = atlas_source.get_tile_data(Vector2i(col, row), 0)
tile_data.terrain_set = 0
tile_data.terrain = terrain_id
tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, value)
```

#### 4.2.3 FastNoiseLite for Procedural Generation
```gdscript
var noise = FastNoiseLite.new()
noise.seed = randi()
noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
noise.frequency = 0.04

var value = noise.get_noise_2d(x, y)  # Returns -1 to 1
value = (value + 1.0) / 2.0  # Normalize to 0-1
```

### 4.3 Multi-Terrain Layering System

For 3+ terrains, use stacked TileMapLayers:

```
Terrain Order (bottom to top):
  Layer 0: Water (base, fills all)
  Layer 1: Sand (transparent where no sand)
  Layer 2: Grass (transparent where no grass)

Noise Thresholds:
  value < 0.3  → Water
  value < 0.6  → Sand
  value >= 0.6 → Grass

Rule: Adjacent terrains only (Water↔Sand↔Grass)
      Water never directly touches Grass
```

---

## 5. External API Specifications

### 5.1 Claude API Integration

#### 5.1.1 Endpoint
```
POST https://api.anthropic.com/v1/messages
```

#### 5.1.2 Model
```
claude-sonnet-4-20250514
```

#### 5.1.3 System Prompt Requirements
- Godot 4.5 specific syntax
- GDScript best practices
- Scene structure guidelines
- Signal connection patterns

### 5.2 RD-Tile API Integration

#### 5.2.1 Endpoint (via Replicate)
```
POST https://api.replicate.com/v1/predictions
Model: retro-diffusion/rd-tile
```

#### 5.2.2 Tileset Request Format
```json
{
    "style": "tileset",
    "width": 16,
    "height": 16,
    "prompt": "terrain description here",
    "num_images": 1
}
```

#### 5.2.3 Response Format
```json
{
    "output": ["https://replicate.delivery/.../output_0.png"],
    "status": "succeeded"
}
```

---

## 6. File Structure

### 6.1 Plugin Structure
```
addons/ai_game_generator/
├── plugin.cfg
├── plugin.gd                    # Main EditorPlugin
├── ui/
│   ├── main_dock.tscn          # Tab container
│   ├── main_dock.gd
│   ├── chat_tab.tscn           # Chat interface
│   ├── chat_tab.gd
│   ├── assets_tab.tscn         # Assets interface
│   └── assets_tab.gd
├── core/
│   ├── claude_api.gd           # Claude API wrapper
│   ├── rdtile_api.gd           # RD-Tile API wrapper
│   ├── tileset_builder.gd      # TileSet creation & peering bits
│   ├── map_generator.gd        # Procedural map generation
│   ├── scene_builder.gd        # Scene/node creation
│   └── script_validator.gd     # GDScript validation
├── data/
│   └── rd_tile_map.gd          # RD_TILE_MAP constant
└── templates/
    ├── player_movement.gd      # Common script templates
    └── npc_dialogue.gd
```

### 6.2 Generated Project Structure
```
res://
├── assets/
│   ├── tilesets/               # Generated PNG files
│   └── sprites/                # Generated sprite files
├── tilesets/
│   └── *.tres                  # TileSet resources
├── scripts/
│   └── *.gd                    # Generated GDScript files
├── scenes/
│   ├── entities/               # Player, NPC, Item scenes
│   └── maps/                   # Generated map scenes
└── Main.tscn                   # Entry point scene
```

---

## 7. User Workflows

### 7.1 Complete Game Generation Flow

```
1. User opens plugin
2. User types: "RPG on tropical island with NPCs"
3. Plugin → Claude: Analyze request
4. Claude returns: Asset list + code plan
5. Plugin shows plan to user
6. User clicks [Generate]
7. Plugin → RD-Tile: Generate tilesets
8. Plugin: Create TileSet resources with peering bits
9. Plugin: Generate map with FastNoiseLite
10. Plugin → Claude: Generate scripts
11. Plugin: Validate scripts
12. Plugin: Create scenes, connect signals
13. Plugin: Save all files
14. User clicks [Play] → Game runs
```

### 7.2 Asset-Only Generation Flow

```
1. User clicks Assets tab
2. User types: "volcanic rock and lava"
3. User selects tile size: 16x16
4. User clicks [Generate Tileset]
5. Plugin → RD-Tile: Request tileset
6. Plugin: Show preview
7. User clicks [Save to Project]
8. Plugin: Create TileSet with peering bits
9. Plugin: Save PNG + .tres files
```

---

## 8. Success Criteria

### 8.1 Functional Success
- [ ] Generate playable game from text description in <2 minutes
- [ ] Tileset transitions render correctly with no visual gaps
- [ ] Generated GDScript passes syntax validation
- [ ] Multi-terrain maps generate with proper layering

### 8.2 Technical Success
- [ ] All Godot 4.5 APIs used correctly
- [ ] RD-Tile peering bit mapping 100% accurate
- [ ] No deprecated API usage (TileMap vs TileMapLayer)
- [ ] Resource files save and load correctly

### 8.3 User Experience Success
- [ ] Plugin UI intuitive without documentation
- [ ] Clear progress feedback during generation
- [ ] Meaningful error messages on failure
- [ ] Generated code readable and modifiable

---

## 9. Constraints & Limitations

### 9.1 Known Limitations
- Maximum 2 terrains per tileset (RD-Tile constraint)
- 3+ terrains require layered approach
- No 3-way terrain transitions (e.g., where sand, water, and grass all meet)
- API rate limits apply (Claude & Replicate)

### 9.2 Out of Scope for v1.0
- 3D game generation
- Custom shader generation
- Audio/music generation
- Multiplayer networking code
- Mobile-specific optimizations

---

## 10. Glossary

| Term | Definition |
|------|------------|
| **Peering Bits** | Values that tell Godot what terrain to expect in each direction |
| **Wang Tiles** | 16-tile format for 2-terrain edge transitions |
| **Blob Tiles** | 47-tile format including corner transitions |
| **RD-Tile** | Retro Diffusion's tile generation API |
| **Terrain Set** | A group of related terrains in a TileSet |
| **TileMapLayer** | Godot 4.3+ node for tile-based maps (replaces TileMap) |
