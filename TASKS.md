# Implementation Tasks
# Godot AI Game Generator Plugin

**Target:** Godot 4.5  
**Structure:** Phase-based with dependencies

---

## Phase Overview

| Phase | Name | Tasks | Dependencies |
|-------|------|-------|--------------|
| 1 | Plugin Foundation | 5 | None |
| 2 | RD-Tile Integration | 6 | Phase 1 |
| 3 | TileSet Builder | 7 | Phase 2 |
| 4 | Map Generator | 5 | Phase 3 |
| 5 | Claude Integration | 6 | Phase 1 |
| 6 | Scene Builder | 5 | Phase 5 |
| 7 | Full Pipeline | 4 | All |
| 8 | Polish & Testing | 4 | Phase 7 |

---

## Phase 1: Plugin Foundation

### Task 1.1: Create Plugin Structure
**Priority:** Critical  
**Estimated Time:** 1 hour

Create the basic addon folder structure:

```
addons/ai_game_generator/
├── plugin.cfg
├── plugin.gd
├── ui/
├── core/
├── data/
└── templates/
```

**Acceptance Criteria:**
- [ ] Plugin appears in Godot's plugin list
- [ ] Plugin can be enabled/disabled without errors
- [ ] Folder structure matches specification

**Files to Create:**
- `addons/ai_game_generator/plugin.cfg`
- `addons/ai_game_generator/plugin.gd`

---

### Task 1.2: Create Main Dock UI
**Priority:** Critical  
**Estimated Time:** 2 hours

Create the main dock panel with tab container:

```
┌─────────────────────────────┐
│  AI Game Generator          │
├─────────────────────────────┤
│  [Chat]  [Assets]           │
├─────────────────────────────┤
│                             │
│  (Tab content here)         │
│                             │
└─────────────────────────────┘
```

**Acceptance Criteria:**
- [ ] Dock appears in editor when plugin enabled
- [ ] Two tabs: Chat and Assets
- [ ] Tab switching works correctly
- [ ] UI scales properly

**Files to Create:**
- `ui/main_dock.tscn`
- `ui/main_dock.gd`

---

### Task 1.3: Create Chat Tab UI
**Priority:** Critical  
**Estimated Time:** 2 hours

Chat interface with message history and input:

```
┌─────────────────────────────┐
│  Message History            │
│  ┌───────────────────────┐  │
│  │ User: Make a player   │  │
│  │ AI: ✓ Created...      │  │
│  └───────────────────────┘  │
├─────────────────────────────┤
│  ┌───────────────────────┐  │
│  │ Type message...       │  │
│  └───────────────────────┘  │
│  [Send] [Generate Game]     │
└─────────────────────────────┘
```

**Acceptance Criteria:**
- [ ] Scrollable message history
- [ ] Text input field
- [ ] Send button (or Enter key)
- [ ] Generate Game button
- [ ] Loading indicator

**Files to Create:**
- `ui/chat_tab.tscn`
- `ui/chat_tab.gd`

---

### Task 1.4: Create Assets Tab UI
**Priority:** Critical  
**Estimated Time:** 2 hours

Asset generation interface:

```
┌─────────────────────────────┐
│  TILESET GENERATOR          │
├─────────────────────────────┤
│  Prompt:                    │
│  ┌───────────────────────┐  │
│  │ beach sand and water  │  │
│  └───────────────────────┘  │
│                             │
│  Tile Size: [16x16 ▼]       │
│                             │
│  [Generate Tileset]         │
├─────────────────────────────┤
│  PREVIEW:                   │
│  ┌─────────┐                │
│  │ (image) │  Status: Ready │
│  └─────────┘                │
│                             │
│  [Save to Project]          │
└─────────────────────────────┘
```

**Acceptance Criteria:**
- [ ] Prompt text input
- [ ] Tile size dropdown (16x16, 32x32)
- [ ] Generate button with loading state
- [ ] Preview area for generated tileset
- [ ] Save to Project button

**Files to Create:**
- `ui/assets_tab.tscn`
- `ui/assets_tab.gd`

---

### Task 1.5: Settings & API Key Management
**Priority:** High  
**Estimated Time:** 1 hour

Secure storage for API keys:

**Acceptance Criteria:**
- [ ] Settings dialog/section for API keys
- [ ] Claude API key input
- [ ] Replicate API key input
- [ ] Keys saved to EditorSettings (not project)
- [ ] Keys never logged or exposed

**Files to Create:**
- `ui/settings_dialog.tscn` (or section in main dock)
- `core/settings_manager.gd`

---

## Phase 2: RD-Tile Integration

### Task 2.1: HTTP Request Wrapper
**Priority:** Critical  
**Estimated Time:** 2 hours

Create reusable HTTP request handler:

```gdscript
class_name APIRequest

signal request_completed(result: Dictionary)
signal request_failed(error: String)

func post(url: String, headers: Array, body: Dictionary) -> void
func get(url: String, headers: Array) -> void
```

**Acceptance Criteria:**
- [ ] POST requests work
- [ ] GET requests work
- [ ] Async/await pattern
- [ ] Error handling
- [ ] Timeout handling

**Files to Create:**
- `core/api_request.gd`

---

### Task 2.2: RD-Tile API Client
**Priority:** Critical  
**Estimated Time:** 3 hours

Wrapper for Replicate's RD-Tile API:

```gdscript
class_name RDTileAPI

func generate_tileset(prompt: String, tile_size: int) -> Dictionary
func get_prediction_status(prediction_id: String) -> Dictionary
func download_image(url: String) -> Image
```

**Acceptance Criteria:**
- [ ] Create prediction request
- [ ] Poll for completion
- [ ] Download result image
- [ ] Handle rate limits
- [ ] Return structured result

**Files to Create:**
- `core/rdtile_api.gd`

---

### Task 2.3: RD-Tile Request Builder
**Priority:** High  
**Estimated Time:** 1 hour

Build properly formatted requests:

```gdscript
func build_tileset_request(prompt: String, size: int) -> Dictionary:
    return {
        "style": "tileset",
        "width": size,
        "height": size,
        "prompt": prompt,
        "num_images": 1
    }
```

**Acceptance Criteria:**
- [ ] Tileset request format correct
- [ ] Supports 16x16 and 32x32
- [ ] Validates inputs

**Files to Create:**
- Part of `core/rdtile_api.gd`

---

### Task 2.4: Image Download & Save
**Priority:** High  
**Estimated Time:** 2 hours

Download generated images and save to project:

**Acceptance Criteria:**
- [ ] Download from Replicate delivery URL
- [ ] Convert to Godot Image
- [ ] Save as PNG to res://assets/tilesets/
- [ ] Handle download failures
- [ ] Report progress

**Files to Create:**
- `core/image_downloader.gd`

---

### Task 2.5: Assets Tab Integration
**Priority:** High  
**Estimated Time:** 2 hours

Connect UI to RD-Tile API:

**Acceptance Criteria:**
- [ ] Generate button calls API
- [ ] Loading state during generation
- [ ] Preview shows result
- [ ] Error messages displayed
- [ ] Success feedback

**Files to Modify:**
- `ui/assets_tab.gd`

---

### Task 2.6: Tileset Preview Display
**Priority:** Medium  
**Estimated Time:** 1 hour

Show generated tileset in preview area:

**Acceptance Criteria:**
- [ ] Display 64x80 image scaled appropriately
- [ ] Show tile grid overlay (optional)
- [ ] Clear previous preview on new generation

**Files to Modify:**
- `ui/assets_tab.gd`
- `ui/assets_tab.tscn`

---

## Phase 3: TileSet Builder

### Task 3.1: RD_TILE_MAP Data Structure
**Priority:** Critical  
**Estimated Time:** 1 hour

Create the peering bit mapping constant:

```gdscript
const RD_TILE_MAP = {
    0: {
        "pos": Vector2i(0, 0),
        "terrain": 0,
        "top": 0, "right": 0, "bottom": 0, "left": 0,
        "top_left": 0, "top_right": 0, "bottom_left": 0, "bottom_right": 0
    },
    # ... all 20 tiles
}
```

**Acceptance Criteria:**
- [ ] All 20 tiles mapped
- [ ] Correct terrain assignments
- [ ] Correct peering bit values
- [ ] Validated against RD-Tile output

**Files to Create:**
- `data/rd_tile_map.gd`

---

### Task 3.2: TileSet Resource Creator
**Priority:** Critical  
**Estimated Time:** 3 hours

Create TileSet resource from image:

```gdscript
func create_tileset(image_path: String, terrain_names: Array) -> TileSet:
    var tileset = TileSet.new()
    tileset.tile_size = Vector2i(16, 16)
    
    # Add atlas source
    var source = TileSetAtlasSource.new()
    source.texture = load(image_path)
    source.texture_region_size = Vector2i(16, 16)
    
    # Create tiles
    for row in 5:
        for col in 4:
            source.create_tile(Vector2i(col, row))
    
    tileset.add_source(source)
    return tileset
```

**Acceptance Criteria:**
- [ ] Create TileSet from PNG
- [ ] Correct tile size configuration
- [ ] All 20 tiles created in atlas
- [ ] Resource can be saved

**Files to Create:**
- `core/tileset_builder.gd`

---

### Task 3.3: Terrain Set Configuration
**Priority:** Critical  
**Estimated Time:** 2 hours

Configure terrain set with two terrains:

```gdscript
func setup_terrain_set(tileset: TileSet, terrain_names: Array) -> void:
    tileset.add_terrain_set()
    tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
    
    for i in terrain_names.size():
        tileset.add_terrain(0)
        tileset.set_terrain_name(0, i, terrain_names[i])
```

**Acceptance Criteria:**
- [ ] Terrain set created with correct mode
- [ ] Two terrains added
- [ ] Terrain names set
- [ ] Mode is MATCH_CORNERS_AND_SIDES

**Files to Modify:**
- `core/tileset_builder.gd`

---

### Task 3.4: Peering Bit Application
**Priority:** Critical  
**Estimated Time:** 3 hours

Apply RD_TILE_MAP peering bits to all tiles:

```gdscript
func apply_peering_bits(tileset: TileSet, source_id: int) -> void:
    var source = tileset.get_source(source_id) as TileSetAtlasSource
    
    for tile_idx in RD_TILE_MAP:
        var data = RD_TILE_MAP[tile_idx]
        var tile_data = source.get_tile_data(data["pos"], 0)
        
        tile_data.terrain_set = 0
        tile_data.terrain = data["terrain"]
        
        tile_data.set_terrain_peering_bit(
            TileSet.CELL_NEIGHBOR_TOP_SIDE, data["top"])
        tile_data.set_terrain_peering_bit(
            TileSet.CELL_NEIGHBOR_RIGHT_SIDE, data["right"])
        # ... all 8 directions
```

**Acceptance Criteria:**
- [ ] All 20 tiles configured
- [ ] Correct terrain assignment per tile
- [ ] All 8 peering bits set per tile
- [ ] No errors during application

**Files to Modify:**
- `core/tileset_builder.gd`

---

### Task 3.5: TileSet Resource Saving
**Priority:** High  
**Estimated Time:** 1 hour

Save TileSet as .tres file:

```gdscript
func save_tileset(tileset: TileSet, path: String) -> Error:
    return ResourceSaver.save(tileset, path)
```

**Acceptance Criteria:**
- [ ] Saves to res://tilesets/
- [ ] .tres format
- [ ] Unique filename generation
- [ ] Handles existing files

**Files to Modify:**
- `core/tileset_builder.gd`

---

### Task 3.6: Assets Tab Save Integration
**Priority:** High  
**Estimated Time:** 2 hours

Connect Save button to TileSet builder:

**Acceptance Criteria:**
- [ ] Save button creates TileSet
- [ ] Both PNG and .tres saved
- [ ] Success/failure feedback
- [ ] Files appear in FileSystem dock

**Files to Modify:**
- `ui/assets_tab.gd`

---

### Task 3.7: Multi-Terrain Support
**Priority:** Medium  
**Estimated Time:** 3 hours

Support generating multiple terrain pairs:

```gdscript
# User generates:
# 1. Water ↔ Sand tileset
# 2. Sand ↔ Grass tileset

# Plugin creates:
# - water_sand_tileset.tres
# - sand_grass_tileset.tres
```

**Acceptance Criteria:**
- [ ] UI supports adding terrain pairs
- [ ] Each pair generates separate tileset
- [ ] Naming convention consistent
- [ ] Terrains linked for layering

**Files to Modify:**
- `ui/assets_tab.tscn`
- `ui/assets_tab.gd`
- `core/tileset_builder.gd`

---

## Phase 4: Map Generator

### Task 4.1: FastNoiseLite Wrapper
**Priority:** High  
**Estimated Time:** 1 hour

Configurable noise generator:

```gdscript
class_name TerrainNoise

var noise: FastNoiseLite

func _init(seed: int = -1):
    noise = FastNoiseLite.new()
    noise.seed = seed if seed >= 0 else randi()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    noise.frequency = 0.04

func get_value(x: int, y: int) -> float:
    var value = noise.get_noise_2d(x, y)
    return (value + 1.0) / 2.0  # Normalize 0-1
```

**Acceptance Criteria:**
- [ ] Configurable seed
- [ ] Configurable frequency
- [ ] Returns normalized 0-1 values
- [ ] Reproducible with same seed

**Files to Create:**
- `core/terrain_noise.gd`

---

### Task 4.2: Terrain Cell Classifier
**Priority:** High  
**Estimated Time:** 2 hours

Assign terrain types based on noise:

```gdscript
func classify_terrain(value: float, thresholds: Array) -> int:
    # thresholds = [0.3, 0.6] for 3 terrains
    for i in thresholds.size():
        if value < thresholds[i]:
            return i
    return thresholds.size()
```

**Acceptance Criteria:**
- [ ] Supports 2-4 terrains
- [ ] Configurable thresholds
- [ ] Returns terrain index
- [ ] Edge cases handled

**Files to Create:**
- `core/map_generator.gd`

---

### Task 4.3: Island Layout Generator
**Priority:** High  
**Estimated Time:** 3 hours

Generate island-shaped terrain distribution:

```gdscript
func generate_island(width: int, height: int) -> Dictionary:
    var cells = {0: [], 1: [], 2: []}  # terrain_id: [cells]
    var center = Vector2(width / 2, height / 2)
    var max_dist = center.length()
    
    for x in range(width):
        for y in range(height):
            var dist = Vector2(x, y).distance_to(center) / max_dist
            var noise_val = terrain_noise.get_value(x, y)
            var value = dist * 0.7 + (1.0 - noise_val) * 0.3
            
            var terrain = classify_terrain(value, [0.4, 0.7])
            cells[terrain].append(Vector2i(x, y))
    
    return cells
```

**Acceptance Criteria:**
- [ ] Island shape (water at edges)
- [ ] Noise-based natural edges
- [ ] Configurable size
- [ ] Ring-based terrain (no terrain skipping)

**Files to Modify:**
- `core/map_generator.gd`

---

### Task 4.4: TileMapLayer Generator
**Priority:** Critical  
**Estimated Time:** 3 hours

Create TileMapLayer with terrain applied:

```gdscript
func create_tilemap_layer(
    cells: Array[Vector2i], 
    tileset: TileSet,
    terrain_set: int,
    terrain: int
) -> TileMapLayer:
    var layer = TileMapLayer.new()
    layer.tile_set = tileset
    layer.set_cells_terrain_connect(cells, terrain_set, terrain)
    return layer
```

**Acceptance Criteria:**
- [ ] Creates TileMapLayer node
- [ ] Assigns tileset
- [ ] Applies terrain to cells
- [ ] Godot auto-selects transition tiles

**Files to Modify:**
- `core/map_generator.gd`

---

### Task 4.5: Multi-Layer Map Assembly
**Priority:** High  
**Estimated Time:** 2 hours

Assemble multiple layers for 3+ terrains:

```gdscript
func generate_layered_map(
    width: int, 
    height: int,
    tilesets: Array[TileSet]
) -> Node2D:
    var root = Node2D.new()
    root.name = "Map"
    
    var terrain_cells = generate_island(width, height)
    
    # Layer 0: Base (water)
    var water_layer = create_tilemap_layer(...)
    water_layer.z_index = 0
    root.add_child(water_layer)
    
    # Layer 1: Sand
    var sand_layer = create_tilemap_layer(...)
    sand_layer.z_index = 1
    root.add_child(sand_layer)
    
    return root
```

**Acceptance Criteria:**
- [ ] Multiple TileMapLayer nodes
- [ ] Correct z_index ordering
- [ ] Proper terrain assignment per layer
- [ ] Seamless visual result

**Files to Modify:**
- `core/map_generator.gd`

---

## Phase 5: Claude Integration

### Task 5.1: Claude API Client
**Priority:** Critical  
**Estimated Time:** 3 hours

Wrapper for Anthropic's Claude API:

```gdscript
class_name ClaudeAPI

const API_URL = "https://api.anthropic.com/v1/messages"
const MODEL = "claude-sonnet-4-20250514"

func send_message(messages: Array, system: String) -> Dictionary
```

**Acceptance Criteria:**
- [ ] Correct API format
- [ ] System prompt support
- [ ] Message history support
- [ ] Error handling
- [ ] Response parsing

**Files to Create:**
- `core/claude_api.gd`

---

### Task 5.2: System Prompt for Godot 4.5
**Priority:** Critical  
**Estimated Time:** 2 hours

Create comprehensive system prompt:

```
You are a Godot 4.5 game generator. Generate valid GDScript and scene structures.

Rules:
- Use TileMapLayer (NOT deprecated TileMap)
- Use @export for exposed variables
- Use signal syntax: signal_name.emit()
- Scene structure uses .tscn format
...
```

**Acceptance Criteria:**
- [ ] Covers Godot 4.5 specifics
- [ ] Prevents deprecated API usage
- [ ] Includes code style guidelines
- [ ] Tested with sample requests

**Files to Create:**
- `data/system_prompt.gd` (or .txt)

---

### Task 5.3: Game Analysis Prompt
**Priority:** High  
**Estimated Time:** 2 hours

Prompt for analyzing game descriptions:

```
Analyze this game request and return JSON:
{
    "game_type": "top_down_rpg",
    "terrains": [...],
    "entities": [...],
    "scripts": [...],
    "ui": [...]
}
```

**Acceptance Criteria:**
- [ ] Structured JSON output
- [ ] Identifies all components
- [ ] Reasonable defaults for missing info
- [ ] Handles ambiguous requests

**Files to Create:**
- `data/analysis_prompt.gd`

---

### Task 5.4: Script Generator Prompt
**Priority:** High  
**Estimated Time:** 2 hours

Prompt for generating GDScript:

```
Generate GDScript for Godot 4.5:
- Class name: {class_name}
- Purpose: {purpose}
- Features: {features}

Return ONLY valid GDScript code.
```

**Acceptance Criteria:**
- [ ] Generates valid GDScript
- [ ] Follows Godot 4.5 patterns
- [ ] Includes necessary signals
- [ ] Proper export annotations

**Files to Create:**
- `data/script_prompt.gd`

---

### Task 5.5: GDScript Validator
**Priority:** Critical  
**Estimated Time:** 3 hours

Validate generated scripts:

```gdscript
func validate_script(code: String) -> Dictionary:
    var script = GDScript.new()
    script.source_code = code
    var error = script.reload()
    
    return {
        "valid": error == OK,
        "error": error_string(error) if error != OK else ""
    }
```

**Acceptance Criteria:**
- [ ] Detects syntax errors
- [ ] Returns error details
- [ ] Doesn't execute code
- [ ] Works in editor context

**Files to Create:**
- `core/script_validator.gd`

---

### Task 5.6: Retry Loop Implementation
**Priority:** High  
**Estimated Time:** 2 hours

Automatic retry on validation failure:

```gdscript
func generate_with_retry(prompt: String, max_attempts: int = 3) -> String:
    for attempt in max_attempts:
        var code = await claude_api.generate_script(prompt)
        var result = validator.validate_script(code)
        
        if result.valid:
            return code
        
        prompt = add_error_context(prompt, result.error)
    
    return ""  # Failed after retries
```

**Acceptance Criteria:**
- [ ] Retries up to 3 times
- [ ] Includes error in retry prompt
- [ ] Reports final failure
- [ ] Tracks attempt count

**Files to Create:**
- `core/generation_pipeline.gd`

---

## Phase 6: Scene Builder

### Task 6.1: Scene Structure Parser
**Priority:** High  
**Estimated Time:** 2 hours

Parse Claude's scene structure output:

```gdscript
func parse_scene_structure(json: Dictionary) -> Node:
    # JSON format:
    # {
    #     "name": "Player",
    #     "type": "CharacterBody2D",
    #     "children": [
    #         {"name": "Sprite2D", "type": "Sprite2D", ...}
    #     ]
    # }
```

**Acceptance Criteria:**
- [ ] Creates node hierarchy
- [ ] Sets node properties
- [ ] Handles all common node types
- [ ] Error handling for invalid structure

**Files to Create:**
- `core/scene_builder.gd`

---

### Task 6.2: Node Property Setter
**Priority:** High  
**Estimated Time:** 2 hours

Apply properties to created nodes:

```gdscript
func apply_properties(node: Node, properties: Dictionary) -> void:
    for prop in properties:
        if node.has_property(prop):
            node.set(prop, properties[prop])
```

**Acceptance Criteria:**
- [ ] Sets basic properties (position, scale, etc.)
- [ ] Handles resource properties (texture, script)
- [ ] Type conversion as needed
- [ ] Skips invalid properties

**Files to Modify:**
- `core/scene_builder.gd`

---

### Task 6.3: Script Attachment
**Priority:** High  
**Estimated Time:** 1 hour

Attach generated scripts to nodes:

```gdscript
func attach_script(node: Node, script_path: String) -> void:
    var script = load(script_path)
    node.set_script(script)
```

**Acceptance Criteria:**
- [ ] Loads script from path
- [ ] Attaches to correct node
- [ ] Handles missing scripts
- [ ] Verifies script compatibility

**Files to Modify:**
- `core/scene_builder.gd`

---

### Task 6.4: Signal Connection
**Priority:** Medium  
**Estimated Time:** 2 hours

Connect signals between nodes:

```gdscript
func connect_signals(scene: Node, connections: Array) -> void:
    for conn in connections:
        var source = scene.get_node(conn.source)
        var target = scene.get_node(conn.target)
        source.connect(conn.signal, target[conn.method])
```

**Acceptance Criteria:**
- [ ] Connects signals by path
- [ ] Handles missing nodes gracefully
- [ ] Supports common signal patterns
- [ ] Error reporting

**Files to Modify:**
- `core/scene_builder.gd`

---

### Task 6.5: PackedScene Saving
**Priority:** High  
**Estimated Time:** 1 hour

Save assembled scene to file:

```gdscript
func save_scene(root: Node, path: String) -> Error:
    # Set owner for all children
    set_owner_recursive(root, root)
    
    var scene = PackedScene.new()
    scene.pack(root)
    return ResourceSaver.save(scene, path)

func set_owner_recursive(node: Node, owner: Node) -> void:
    for child in node.get_children():
        child.owner = owner
        set_owner_recursive(child, owner)
```

**Acceptance Criteria:**
- [ ] All nodes included in save
- [ ] .tscn format
- [ ] Owner properly set
- [ ] File appears in FileSystem

**Files to Modify:**
- `core/scene_builder.gd`

---

## Phase 7: Full Pipeline

### Task 7.1: Generation Orchestrator
**Priority:** Critical  
**Estimated Time:** 4 hours

Coordinate entire generation process:

```gdscript
class_name GenerationOrchestrator

signal progress_updated(stage: String, percent: int)
signal generation_complete(success: bool)

func generate_game(description: String) -> void:
    # 1. Analyze with Claude
    emit_signal("progress_updated", "Analyzing...", 10)
    var plan = await analyze_request(description)
    
    # 2. Generate assets
    emit_signal("progress_updated", "Creating assets...", 30)
    var assets = await generate_assets(plan)
    
    # 3. Build tilesets
    emit_signal("progress_updated", "Building tilesets...", 50)
    var tilesets = await build_tilesets(assets)
    
    # 4. Generate map
    emit_signal("progress_updated", "Generating map...", 60)
    var map = await generate_map(tilesets, plan.map)
    
    # 5. Generate scripts
    emit_signal("progress_updated", "Writing scripts...", 70)
    var scripts = await generate_scripts(plan)
    
    # 6. Build scenes
    emit_signal("progress_updated", "Building scenes...", 85)
    var scenes = await build_scenes(plan, scripts)
    
    # 7. Assemble main scene
    emit_signal("progress_updated", "Finalizing...", 95)
    await assemble_main_scene(map, scenes)
    
    emit_signal("generation_complete", true)
```

**Acceptance Criteria:**
- [ ] Coordinates all subsystems
- [ ] Progress reporting
- [ ] Error handling at each stage
- [ ] Rollback on failure

**Files to Create:**
- `core/generation_orchestrator.gd`

---

### Task 7.2: Chat Tab Full Integration
**Priority:** Critical  
**Estimated Time:** 3 hours

Connect Chat UI to orchestrator:

**Acceptance Criteria:**
- [ ] Send triggers analysis
- [ ] Generate Game triggers full pipeline
- [ ] Progress shown in UI
- [ ] Results displayed in chat
- [ ] Errors shown clearly

**Files to Modify:**
- `ui/chat_tab.gd`

---

### Task 7.3: Main Scene Assembly
**Priority:** High  
**Estimated Time:** 2 hours

Create final playable Main.tscn:

```gdscript
func assemble_main_scene(map: Node2D, entities: Array) -> void:
    var main = Node2D.new()
    main.name = "Main"
    
    main.add_child(map)
    
    var entities_node = Node2D.new()
    entities_node.name = "Entities"
    main.add_child(entities_node)
    
    for entity in entities:
        entities_node.add_child(entity.instantiate())
    
    save_scene(main, "res://Main.tscn")
```

**Acceptance Criteria:**
- [ ] Proper node hierarchy
- [ ] All components included
- [ ] Saves as project entry point
- [ ] Playable with F5

**Files to Modify:**
- `core/generation_orchestrator.gd`

---

### Task 7.4: Project Configuration
**Priority:** Medium  
**Estimated Time:** 1 hour

Update project.godot if needed:

```gdscript
func configure_project() -> void:
    # Set main scene
    ProjectSettings.set_setting(
        "application/run/main_scene", 
        "res://Main.tscn"
    )
    
    # Add input actions if needed
    if not InputMap.has_action("interact"):
        # Add interact action
```

**Acceptance Criteria:**
- [ ] Main scene set
- [ ] Required input actions exist
- [ ] Settings saved
- [ ] Project ready to run

**Files to Modify:**
- `core/generation_orchestrator.gd`

---

## Phase 8: Polish & Testing

### Task 8.1: Error Handling & User Feedback
**Priority:** High  
**Estimated Time:** 3 hours

Comprehensive error handling:

**Acceptance Criteria:**
- [ ] All API errors caught
- [ ] User-friendly error messages
- [ ] Retry suggestions where applicable
- [ ] No crashes from bad input

**Files to Modify:**
- All core/*.gd files
- All ui/*.gd files

---

### Task 8.2: Progress UI Polish
**Priority:** Medium  
**Estimated Time:** 2 hours

Improve loading/progress display:

**Acceptance Criteria:**
- [ ] Smooth progress bar
- [ ] Stage descriptions
- [ ] Cancel button (if possible)
- [ ] Time estimate (optional)

**Files to Modify:**
- `ui/chat_tab.gd`
- `ui/assets_tab.gd`

---

### Task 8.3: Testing Suite
**Priority:** High  
**Estimated Time:** 4 hours

Create test scenarios:

**Test Cases:**
- [ ] Simple 2-terrain tileset generation
- [ ] 3-terrain layered map
- [ ] Player with movement script
- [ ] NPC with dialogue
- [ ] Full game generation
- [ ] Error recovery
- [ ] API failure handling

**Files to Create:**
- `tests/test_tileset_builder.gd`
- `tests/test_map_generator.gd`
- `tests/test_generation_pipeline.gd`

---

### Task 8.4: Documentation
**Priority:** Medium  
**Estimated Time:** 2 hours

User documentation:

**Content:**
- [ ] Installation guide
- [ ] Quick start tutorial
- [ ] API key setup
- [ ] Example prompts
- [ ] Troubleshooting

**Files to Create:**
- `README.md`
- `docs/QUICKSTART.md`
- `docs/TROUBLESHOOTING.md`

---

## Task Dependencies Graph

```
Phase 1 (Foundation)
    │
    ├──→ Phase 2 (RD-Tile) ──→ Phase 3 (TileSet) ──→ Phase 4 (Map)
    │                                                      │
    └──→ Phase 5 (Claude) ──→ Phase 6 (Scene Builder) ────┤
                                                          │
                                                          ▼
                                                    Phase 7 (Pipeline)
                                                          │
                                                          ▼
                                                    Phase 8 (Polish)
```

---

## Estimated Timeline

| Phase | Tasks | Est. Hours | Dependencies |
|-------|-------|------------|--------------|
| 1 | 5 | 8 hours | None |
| 2 | 6 | 11 hours | Phase 1 |
| 3 | 7 | 15 hours | Phase 2 |
| 4 | 5 | 11 hours | Phase 3 |
| 5 | 6 | 14 hours | Phase 1 |
| 6 | 5 | 8 hours | Phase 5 |
| 7 | 4 | 10 hours | All |
| 8 | 4 | 11 hours | Phase 7 |
| **Total** | **42** | **88 hours** | |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| RD-Tile format changes | Version lock API, detect format |
| Claude generates invalid code | Retry loop with error feedback |
| Godot API changes | Pin to 4.5, monitor deprecations |
| API rate limits | Implement backoff, queue requests |
| Large map performance | Chunk generation, lazy loading |
