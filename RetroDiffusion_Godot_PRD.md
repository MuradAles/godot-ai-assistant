# Product Requirements Document
# RetroDiffusion Tileset Integration for Godot 4.5

**Version:** 1.0  
**Date:** December 2024  
**Author:** Claude  
**Project:** 2D Terrain Generation System

---

## 1. Overview

### 1.1 Purpose
Integrate RetroDiffusion AI-generated tilesets into Godot 4.5's terrain system for automatic tile placement during procedural map generation.

### 1.2 Goals
- Use RetroDiffusion's 4×5 (20 tile) output format
- Automatic terrain transitions (no manual tile placement)
- Support multiple terrain pairs (sand↔water, dirt↔sand, etc.)
- Runtime map generation with correct autotiling

### 1.3 Non-Goals
- Three-way transitions (sand+water+dirt meeting at one point)
- 47-tile blob format support
- Manual tile painting workflow

---

## 2. Technical Specification

### 2.1 Wang Tile System

Each tile represents a 2×2 corner configuration:

```
┌────┬────┐
│ TL │ TR │   TL = Top-Left     (bit value: 8)
├────┼────┤   TR = Top-Right    (bit value: 4)
│ BL │ BR │   BL = Bottom-Left  (bit value: 2)
└────┴────┘   BR = Bottom-Right (bit value: 1)
```

**Tile Index Formula:**
```
index = (TL × 8) + (TR × 4) + (BL × 2) + (BR × 1)
```

Where each corner is:
- `0` = Outside material (e.g., water)
- `1` = Inside material (e.g., sand)

### 2.2 All 16 Tile Configurations

| Index | Binary | TL | TR | BL | BR | Description |
|-------|--------|----|----|----|----|-------------|
| 0     | 0000   | 0  | 0  | 0  | 0  | Full outside |
| 1     | 0001   | 0  | 0  | 0  | 1  | BR corner inside |
| 2     | 0010   | 0  | 0  | 1  | 0  | BL corner inside |
| 3     | 0011   | 0  | 0  | 1  | 1  | Bottom edge inside |
| 4     | 0100   | 0  | 1  | 0  | 0  | TR corner inside |
| 5     | 0101   | 0  | 1  | 0  | 1  | Right edge inside |
| 6     | 0110   | 0  | 1  | 1  | 0  | Diagonal TR-BL |
| 7     | 0111   | 0  | 1  | 1  | 1  | Missing TL corner |
| 8     | 1000   | 1  | 0  | 0  | 0  | TL corner inside |
| 9     | 1001   | 1  | 0  | 0  | 1  | Diagonal TL-BR |
| 10    | 1010   | 1  | 0  | 1  | 0  | Left edge inside |
| 11    | 1011   | 1  | 0  | 1  | 1  | Missing TR corner |
| 12    | 1100   | 1  | 1  | 0  | 0  | Top edge inside |
| 13    | 1101   | 1  | 1  | 0  | 1  | Missing BL corner |
| 14    | 1110   | 1  | 1  | 1  | 0  | Missing BR corner |
| 15    | 1111   | 1  | 1  | 1  | 1  | Full inside |

### 2.3 Visual Reference

```
Index 0:    Index 1:    Index 2:    Index 3:
░░░░░░░░    ░░░░░░░░    ░░░░░░░░    ░░░░░░░░
░░░░░░░░    ░░░░░░░░    ░░░░░░░░    ░░░░░░░░
░░░░░░░░    ░░░░░░██    ██░░░░░░    ████████
░░░░░░░░    ░░░░░░██    ██░░░░░░    ████████

Index 4:    Index 5:    Index 6:    Index 7:
░░░░░░██    ░░░░░░██    ░░░░░░██    ░░░░░░██
░░░░░░██    ░░░░░░██    ░░░░░░██    ░░░░████
░░░░░░░░    ░░░░░░██    ██░░░░░░    ████████
░░░░░░░░    ░░░░░░██    ██░░░░░░    ████████

Index 8:    Index 9:    Index 10:   Index 11:
██░░░░░░    ██░░░░░░    ██░░░░░░    ██░░░░░░
██░░░░░░    ██░░░░░░    ██░░░░░░    ████░░░░
░░░░░░░░    ░░░░░░██    ██░░░░░░    ████████
░░░░░░░░    ░░░░░░██    ██░░░░░░    ████████

Index 12:   Index 13:   Index 14:   Index 15:
████████    ████████    ████████    ████████
████████    ████████    ████████    ████████
░░░░░░░░    ░░░░░░██    ██░░░░░░    ████████
░░░░░░░░    ░░░░░░██    ██░░░░░░    ████████

░ = Outside material    █ = Inside material
```

---

## 3. RetroDiffusion Format

### 3.1 Input Format
- **Dimensions:** 4 columns × 5 rows = 20 tiles
- **Tile size:** 16×16 or 32×32 pixels
- **Image size:** (tile_size × 4) × (tile_size × 5)
  - 16px tiles → 64×80 pixels
  - 32px tiles → 128×160 pixels

### 3.2 RetroDiffusion Layout to Wang Index Mapping

```
RetroDiffusion 4×5 Grid:

         Col 0    Col 1    Col 2    Col 3
         ─────────────────────────────────
Row 0:     0        1        3        2
Row 1:     0        5       15       10
Row 2:     0        4       12        8
Row 3:    15       14       13        6
Row 4:    15       11        7        9
```

### 3.3 Duplicate Tiles
RetroDiffusion provides 20 tiles, but only 16 unique Wang indices:

| Index | Count | Locations (row, col) |
|-------|-------|---------------------|
| 0     | 3     | (0,0), (1,0), (2,0) |
| 15    | 3     | (1,2), (3,0), (4,0) |
| Others| 1     | Single location each |

**Recommendation:** Use duplicates for texture variation with probability weighting.

### 3.4 Coordinate to Index Lookup Table

```gdscript
const RD_TO_WANG: Dictionary = {
    Vector2i(0, 0): 0,   Vector2i(1, 0): 1,   Vector2i(2, 0): 3,   Vector2i(3, 0): 2,
    Vector2i(0, 1): 0,   Vector2i(1, 1): 5,   Vector2i(2, 1): 15,  Vector2i(3, 1): 10,
    Vector2i(0, 2): 0,   Vector2i(1, 2): 4,   Vector2i(2, 2): 12,  Vector2i(3, 2): 8,
    Vector2i(0, 3): 15,  Vector2i(1, 3): 14,  Vector2i(2, 3): 13,  Vector2i(3, 3): 6,
    Vector2i(0, 4): 15,  Vector2i(1, 4): 11,  Vector2i(2, 4): 7,   Vector2i(3, 4): 9,
}
```

### 3.5 Index to Coordinate Lookup Table (Primary Tiles)

```gdscript
const WANG_TO_RD: Dictionary = {
    0:  Vector2i(0, 0),   # or (0,1) or (0,2) for variation
    1:  Vector2i(1, 0),
    2:  Vector2i(3, 0),
    3:  Vector2i(2, 0),
    4:  Vector2i(1, 2),
    5:  Vector2i(1, 1),
    6:  Vector2i(3, 3),
    7:  Vector2i(2, 4),
    8:  Vector2i(3, 2),
    9:  Vector2i(3, 4),
    10: Vector2i(3, 1),
    11: Vector2i(1, 4),
    12: Vector2i(2, 2),
    13: Vector2i(2, 3),
    14: Vector2i(1, 3),
    15: Vector2i(2, 1),  # or (0,3) or (0,4) for variation
}
```

---

## 4. Implementation

### 4.1 Project Structure

```
project/
├── addons/
│   └── retrodiffusion_terrain/
│       ├── plugin.cfg
│       ├── rd_terrain.gd           # Main terrain handler
│       └── rd_tileset_setup.gd     # Editor script for setup
├── assets/
│   └── tilesets/
│       ├── sand_water.png          # RetroDiffusion output
│       ├── sand_dirt.png
│       └── dirt_water.png
├── resources/
│   └── terrain_tileset.tres        # Configured TileSet
└── scenes/
    └── world.tscn                  # TileMapLayers
```

### 4.2 Scene Structure

```
World (Node2D)
├── WaterLayer (TileMapLayer)       # Base layer - fill with water
│   └── TileSet: terrain_tileset.tres
├── SandLayer (TileMapLayer)        # Sand↔Water transitions  
│   └── TileSet: terrain_tileset.tres
└── DirtLayer (TileMapLayer)        # Dirt↔Sand transitions
    └── TileSet: terrain_tileset.tres
```

### 4.3 TileSet Configuration

```gdscript
# Terrain Set 0: Match Corners mode
# Terrain 0: Outside (water) - Color: Cyan
# Terrain 1: Inside (sand) - Color: Brown
```

**Peering Bits per Tile:**

For Godot's "Match Corners and Sides" mode, set these bits based on Wang index:

```gdscript
func get_peering_bits(wang_index: int) -> Dictionary:
    var br = wang_index & 1
    var bl = (wang_index >> 1) & 1
    var tr = (wang_index >> 2) & 1
    var tl = (wang_index >> 3) & 1
    
    return {
        "top_left_corner": tl,
        "top_right_corner": tr,
        "bottom_left_corner": bl,
        "bottom_right_corner": br,
        "top_side": 1 if (tl == 1 and tr == 1) else 0,
        "bottom_side": 1 if (bl == 1 and br == 1) else 0,
        "left_side": 1 if (tl == 1 and bl == 1) else 0,
        "right_side": 1 if (tr == 1 and br == 1) else 0,
    }
```

---

## 5. Runtime API

### 5.1 Calculate Tile Index from Neighbors

```gdscript
## Calculate Wang tile index based on 4 corner neighbors
## terrain_map: Dictionary[Vector2i, int] where 1 = inside, 0 = outside
## pos: Position to calculate tile for

func calculate_wang_index(terrain_map: Dictionary, pos: Vector2i) -> int:
    # Check 4 corners (offset by -1,-1 to get surrounding cells)
    var tl = 1 if terrain_map.get(pos + Vector2i(-1, -1), 0) == 1 else 0
    var tr = 1 if terrain_map.get(pos + Vector2i(0, -1), 0) == 1 else 0
    var bl = 1 if terrain_map.get(pos + Vector2i(-1, 0), 0) == 1 else 0
    var br = 1 if terrain_map.get(pos, 0) == 1 else 0
    
    return (tl * 8) + (tr * 4) + (bl * 2) + br
```

### 5.2 Get Tile Atlas Coordinates

```gdscript
const WANG_TO_RD: Dictionary = {
    0:  Vector2i(0, 0),
    1:  Vector2i(1, 0),
    2:  Vector2i(3, 0),
    3:  Vector2i(2, 0),
    4:  Vector2i(1, 2),
    5:  Vector2i(1, 1),
    6:  Vector2i(3, 3),
    7:  Vector2i(2, 4),
    8:  Vector2i(3, 2),
    9:  Vector2i(3, 4),
    10: Vector2i(3, 1),
    11: Vector2i(1, 4),
    12: Vector2i(2, 2),
    13: Vector2i(2, 3),
    14: Vector2i(1, 3),
    15: Vector2i(2, 1),
}

func get_tile_coords(wang_index: int) -> Vector2i:
    return WANG_TO_RD.get(wang_index, Vector2i(0, 0))
```

### 5.3 Generate Map with Autotiling

```gdscript
## Generate terrain tiles from a binary map
## binary_map: Dictionary[Vector2i, int] where 1 = terrain, 0 = empty
## tilemap: TileMapLayer to place tiles on
## source_id: Atlas source ID in tileset

func generate_terrain(binary_map: Dictionary, tilemap: TileMapLayer, source_id: int = 0):
    # Find bounds
    var min_pos = Vector2i.MAX
    var max_pos = Vector2i.MIN
    
    for pos in binary_map.keys():
        min_pos.x = min(min_pos.x, pos.x)
        min_pos.y = min(min_pos.y, pos.y)
        max_pos.x = max(max_pos.x, pos.x)
        max_pos.y = max(max_pos.y, pos.y)
    
    # Generate display tiles (offset by 1 to cover edges)
    for x in range(min_pos.x, max_pos.x + 2):
        for y in range(min_pos.y, max_pos.y + 2):
            var display_pos = Vector2i(x, y)
            var wang_index = calculate_wang_index(binary_map, display_pos)
            
            # Skip fully empty tiles (index 0)
            if wang_index == 0:
                continue
            
            var atlas_coords = get_tile_coords(wang_index)
            tilemap.set_cell(display_pos, source_id, atlas_coords)
```

### 5.4 Using Godot's Built-in Terrain System

```gdscript
## Alternative: Use Godot's terrain API (after tileset is configured)

func generate_with_godot_terrain(cells: Array[Vector2i], tilemap: TileMapLayer):
    # terrain_set = 0, terrain = 1 (inside)
    tilemap.set_cells_terrain_connect(cells, 0, 1)

func erase_terrain(cells: Array[Vector2i], tilemap: TileMapLayer):
    # terrain = -1 means erase
    tilemap.set_cells_terrain_connect(cells, 0, -1)
```

---

## 6. Multi-Terrain Setup

### 6.1 Layer Architecture

For multiple terrain pairs without three-way transitions:

```
Layer Stack (bottom to top):
─────────────────────────────
Layer 3: Dirt      (uses Dirt↔Sand tileset)
Layer 2: Sand      (uses Sand↔Water tileset)  
Layer 1: Water     (base fill, single tile)
```

### 6.2 Terrain Pair Requirements

| Pair         | RetroDiffusion Tileset | Tile Count |
|--------------|------------------------|------------|
| Sand↔Water   | sand_water.png         | 20 (16 unique) |
| Dirt↔Sand    | dirt_sand.png          | 20 (16 unique) |
| Dirt↔Water   | dirt_water.png         | 20 (16 unique) |

### 6.3 Generation Order

```gdscript
func generate_world():
    # 1. Fill base layer with water
    fill_layer(water_layer, water_tile)
    
    # 2. Generate sand areas (transitions to water automatically)
    var sand_cells = generate_sand_positions()
    generate_terrain(sand_cells, sand_layer, SAND_WATER_ATLAS)
    
    # 3. Generate dirt areas on top (transitions to sand)
    var dirt_cells = generate_dirt_positions()
    generate_terrain(dirt_cells, dirt_layer, DIRT_SAND_ATLAS)
```

---

## 7. TileSet Setup Script

### 7.1 Editor Script for Automatic Configuration

```gdscript
@tool
extends EditorScript

const TILESET_PATH = "res://resources/terrain_tileset.tres"
const TILE_SIZE = 16  # or 32

const RD_LAYOUT = [
    [0,  1,  3,  2],
    [0,  5, 15, 10],
    [0,  4, 12,  8],
    [15, 14, 13,  6],
    [15, 11,  7,  9],
]

func _run():
    var tileset = load(TILESET_PATH) as TileSet
    if not tileset:
        push_error("Could not load tileset")
        return
    
    # Create terrain set
    if tileset.get_terrain_sets_count() == 0:
        tileset.add_terrain_set()
    
    tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
    
    # Add terrains
    while tileset.get_terrains_count(0) < 2:
        tileset.add_terrain(0)
    
    tileset.set_terrain_name(0, 0, "Outside")
    tileset.set_terrain_name(0, 1, "Inside")
    
    # Get atlas source
    var source = tileset.get_source(0) as TileSetAtlasSource
    
    # Configure each tile
    for row in range(5):
        for col in range(4):
            var atlas_coords = Vector2i(col, row)
            var wang_index = RD_LAYOUT[row][col]
            
            var tile_data = source.get_tile_data(atlas_coords, 0)
            if not tile_data:
                continue
            
            tile_data.terrain_set = 0
            _set_peering_bits(tile_data, wang_index)
    
    ResourceSaver.save(tileset, TILESET_PATH)
    print("Tileset configured!")


func _set_peering_bits(tile_data: TileData, wang_index: int):
    var br = wang_index & 1
    var bl = (wang_index >> 1) & 1
    var tr = (wang_index >> 2) & 1
    var tl = (wang_index >> 3) & 1
    
    # Corners
    tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, tl)
    tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, tr)
    tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, bl)
    tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, br)
    
    # Sides
    tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, 
        1 if (tl == 1 and tr == 1) else 0)
    tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, 
        1 if (bl == 1 and br == 1) else 0)
    tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, 
        1 if (tl == 1 and bl == 1) else 0)
    tile_data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, 
        1 if (tr == 1 and br == 1) else 0)
```

---

## 8. Testing Checklist

### 8.1 Visual Tests
- [ ] Single isolated tile renders correctly (index 15)
- [ ] 2×2 square of terrain renders correctly
- [ ] L-shaped terrain has correct corners
- [ ] Diagonal patterns work (indices 6, 9)
- [ ] All 16 tile types appear correctly

### 8.2 Edge Cases
- [ ] Terrain at map edge (0,0)
- [ ] Single-tile islands
- [ ] Single-tile holes in terrain
- [ ] Adjacent different terrain types (multi-layer)

### 8.3 Performance
- [ ] 100×100 map generates < 100ms
- [ ] 1000×1000 map generates < 2s
- [ ] Runtime modification updates correctly

---

## 9. Appendix

### 9.1 Quick Reference Card

```
WANG INDEX FORMULA:
index = (TL × 8) + (TR × 4) + (BL × 2) + BR

RETRODIFFUSION LAYOUT:
     C0   C1   C2   C3
R0:   0    1    3    2
R1:   0    5   15   10
R2:   0    4   12    8
R3:  15   14   13    6
R4:  15   11    7    9

GODOT API:
tilemap.set_cells_terrain_connect(cells, terrain_set, terrain_id)
tilemap.set_cell(pos, source_id, atlas_coords)
```

### 9.2 Useful Links
- RetroDiffusion: https://retrodiffusion.ai/
- TileMapDual Plugin: https://github.com/pablogila/TileMapDual
- Godot TileSet Docs: https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html
- Wang Tiles Explanation: https://dev.to/joestrout/wang-2-corner-tiles-544k

---

## 10. Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0     | Dec 2024 | Initial PRD |

