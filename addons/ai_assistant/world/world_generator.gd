@tool
class_name WorldGenerator
extends RefCounted

## All-in-one world generator for 2D procedural worlds
## Combines terrain noise, WFC structures, and scene building

signal generation_progress(message: String)
signal world_generated(scene_path: String, world_data: Dictionary)

# ==================== ENUMS ====================

enum TerrainType { DEEP_WATER, SHALLOW_WATER, SAND, GRASS, FOREST, DENSE_FOREST, HILLS, MOUNTAIN, SNOW }
enum StructureType { NONE, PATH, HOUSE, TOWER, WALL, TREE, ROCK }
enum WorldType { OPEN_WORLD, SIDE_SCROLLER }
enum WorldTheme { FOREST, DESERT, SNOW, OCEAN, PLAINS }

# ==================== SETTINGS ====================

var world_type: WorldType = WorldType.OPEN_WORLD
var world_theme: WorldTheme = WorldTheme.PLAINS
var width: int = 128
var height: int = 128
var seed_value: int = 0
var tile_size: int = 32  # 32x32 pixel tiles

# Structure sizes (width x height in tiles)
const STRUCTURE_SIZES := {
	StructureType.NONE: Vector2i(0, 0),
	StructureType.PATH: Vector2i(1, 1),
	StructureType.HOUSE: Vector2i(2, 2),
	StructureType.TOWER: Vector2i(2, 3),
	StructureType.WALL: Vector2i(1, 1),
	StructureType.TREE: Vector2i(1, 2),  # 1 wide, 2 tall
	StructureType.ROCK: Vector2i(1, 1)
}

# Track placed structures to avoid overlap
var _structure_map: Dictionary = {}  # Vector2i -> bool

# Noise generators
var elevation_noise: FastNoiseLite
var moisture_noise: FastNoiseLite

# ==================== KEYWORDS FOR DETECTION ====================

const GENERATION_KEYWORDS := ["generate", "create", "make", "build"]
const WORLD_KEYWORDS := ["world", "map", "terrain", "level"]
const OPEN_KEYWORDS := ["open", "top-down", "rpg", "zelda", "explore"]
const SIDE_KEYWORDS := ["platformer", "sidescroller", "terraria", "jump"]

# ==================== PUBLIC API ====================

func is_world_request(message: String) -> bool:
	var lower := message.to_lower()
	var has_gen := false
	var has_world := false
	for k in GENERATION_KEYWORDS:
		if k in lower:
			has_gen = true
			break
	for k in WORLD_KEYWORDS:
		if k in lower:
			has_world = true
			break
	return has_gen and has_world


func parse_request(message: String) -> Dictionary:
	var lower := message.to_lower()
	var result := {
		"type": WorldType.OPEN_WORLD,
		"theme": WorldTheme.PLAINS,
		"needs_type": true,
		"theme_specified": false
	}

	# Detect type
	for k in OPEN_KEYWORDS:
		if k in lower:
			result["type"] = WorldType.OPEN_WORLD
			result["needs_type"] = false
			break
	for k in SIDE_KEYWORDS:
		if k in lower:
			result["type"] = WorldType.SIDE_SCROLLER
			result["needs_type"] = false
			break

	# Detect theme
	if "forest" in lower or "jungle" in lower or "wood" in lower:
		result["theme"] = WorldTheme.FOREST
		result["theme_specified"] = true
	elif "desert" in lower or "sand" in lower or "dune" in lower:
		result["theme"] = WorldTheme.DESERT
		result["theme_specified"] = true
	elif "snow" in lower or "ice" in lower or "frozen" in lower or "winter" in lower:
		result["theme"] = WorldTheme.SNOW
		result["theme_specified"] = true
	elif "ocean" in lower or "island" in lower or "beach" in lower or "tropical" in lower:
		result["theme"] = WorldTheme.OCEAN
		result["theme_specified"] = true
	elif "plain" in lower or "grass" in lower or "meadow" in lower:
		result["theme"] = WorldTheme.PLAINS
		result["theme_specified"] = true

	return result


func get_type_question() -> String:
	return """What type of world would you like?

**1. Open World (Top-down)** - Move in 8 directions (like Zelda)
**2. Side-scroller (Platformer)** - Left/right with jumping (like Terraria)

Just say "open world" or "platformer"!"""


func generate(p_width: int = 128, p_height: int = 128, p_seed: int = 0) -> Dictionary:
	width = p_width
	height = p_height
	seed_value = p_seed if p_seed != 0 else randi()

	generation_progress.emit("Generating terrain...")
	_setup_noise()

	var terrain := _generate_terrain()
	generation_progress.emit("Adding structures...")
	var structures_data := _generate_structures(terrain)

	generation_progress.emit("Building scene...")
	var scene_path := _save_scene(terrain, structures_data)

	var world_data := {
		"terrain": terrain,
		"structures": structures_data.grid,
		"structure_objects": structures_data.objects,
		"width": width,
		"height": height,
		"seed": seed_value,
		"scene_path": scene_path,
		"type": world_type,
		"theme": world_theme,
		"tile_size": tile_size
	}

	generation_progress.emit("Done!")
	world_generated.emit(scene_path, world_data)
	return world_data


func get_summary(world_data: Dictionary) -> String:
	var type_str: String = "Open World" if world_type == WorldType.OPEN_WORLD else "Side-Scroller"
	var theme_str: String = str(WorldTheme.keys()[world_theme]).capitalize()
	return """## World Generated!

**Type:** %s | **Theme:** %s | **Size:** %dx%d | **Seed:** %d

**To Play:** Open `res://addons/ai_assistant/world/world_test.tscn` and press F5
- **WASD** to move, **R** for new world, **ESC** to quit
""" % [type_str, theme_str, world_data.get("width", 128), world_data.get("height", 128), world_data.get("seed", 0)]


# ==================== TERRAIN GENERATION ====================

func _setup_noise() -> void:
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = seed_value
	elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation_noise.frequency = 0.008
	elevation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	elevation_noise.fractal_octaves = 5

	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = seed_value + 1000
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture_noise.frequency = 0.012
	moisture_noise.fractal_octaves = 4

	# Theme adjustments
	match world_theme:
		WorldTheme.DESERT:
			moisture_noise.frequency = 0.02
		WorldTheme.OCEAN:
			elevation_noise.frequency = 0.015


func _generate_terrain() -> Array:
	var terrain: Array = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			var e := (elevation_noise.get_noise_2d(x, y) + 1.0) / 2.0
			var m := (moisture_noise.get_noise_2d(x, y) + 1.0) / 2.0
			row.append(_get_terrain_type(e, m))
		terrain.append(row)
	return terrain


func _get_terrain_type(elevation: float, moisture: float) -> int:
	# Theme-specific terrain generation
	match world_theme:
		WorldTheme.OCEAN:
			# Beach/tropical - lots of water and sand, some forest
			if elevation < 0.45:
				return TerrainType.DEEP_WATER
			if elevation < 0.52:
				return TerrainType.SHALLOW_WATER
			if elevation < 0.60:
				return TerrainType.SAND
			if moisture > 0.5:
				return TerrainType.FOREST
			return TerrainType.SAND

		WorldTheme.DESERT:
			# Desert - mostly sand, some rock
			if elevation < 0.2:
				return TerrainType.DEEP_WATER
			if elevation < 0.25:
				return TerrainType.SHALLOW_WATER
			if elevation > 0.8:
				return TerrainType.MOUNTAIN
			if elevation > 0.65:
				return TerrainType.HILLS
			return TerrainType.SAND

		WorldTheme.FOREST:
			# Forest - lots of trees, some grass
			if elevation < 0.25:
				return TerrainType.DEEP_WATER
			if elevation < 0.32:
				return TerrainType.SHALLOW_WATER
			if elevation < 0.38:
				return TerrainType.SAND
			if elevation > 0.8:
				return TerrainType.MOUNTAIN
			if moisture > 0.3:
				return TerrainType.DENSE_FOREST if moisture > 0.6 else TerrainType.FOREST
			return TerrainType.GRASS

		WorldTheme.SNOW:
			# Snow/ice - frozen terrain
			if elevation < 0.3:
				return TerrainType.DEEP_WATER
			if elevation < 0.38:
				return TerrainType.SHALLOW_WATER
			if elevation > 0.5:
				return TerrainType.SNOW
			return TerrainType.GRASS

		_:  # PLAINS (default)
			if elevation < 0.3:
				return TerrainType.DEEP_WATER
			if elevation < 0.38:
				return TerrainType.SHALLOW_WATER
			if elevation < 0.42:
				return TerrainType.SAND
			if elevation > 0.85:
				return TerrainType.SNOW if moisture > 0.5 else TerrainType.MOUNTAIN
			if elevation > 0.7:
				return TerrainType.HILLS
			if moisture > 0.65:
				return TerrainType.DENSE_FOREST
			if moisture > 0.4:
				return TerrainType.FOREST
			if moisture < 0.25:
				return TerrainType.SAND
			return TerrainType.GRASS


# ==================== STRUCTURE GENERATION (Multi-tile support) ====================

func _generate_structures(terrain: Array) -> Dictionary:
	_structure_map.clear()

	# structures_grid: 2D array of base structure type per cell
	# structure_objects: list of {type, x, y, width, height} for multi-tile rendering
	var structures_grid: Array = []
	var structure_objects: Array = []

	# Initialize empty grid
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(StructureType.NONE)
		structures_grid.append(row)

	# Place structures with size consideration
	for y in range(height):
		for x in range(width):
			if _structure_map.has(Vector2i(x, y)):
				continue  # Already occupied

			var structure := _try_place_structure(terrain, x, y)
			if structure != StructureType.NONE:
				var size: Vector2i = STRUCTURE_SIZES[structure]
				if _can_place_structure(terrain, x, y, size):
					_place_structure(structures_grid, structure_objects, structure, x, y, size)

	return {
		"grid": structures_grid,
		"objects": structure_objects
	}


func _try_place_structure(terrain: Array, x: int, y: int) -> int:
	var terrain_type: int = terrain[y][x]
	var rand := randf()

	match terrain_type:
		TerrainType.GRASS:
			if rand < 0.008:  # Reduced chance since houses are bigger
				return StructureType.HOUSE
			if rand < 0.03:
				return StructureType.PATH
		TerrainType.FOREST, TerrainType.DENSE_FOREST:
			if rand < 0.12:
				return StructureType.TREE
		TerrainType.HILLS:
			if rand < 0.05:
				return StructureType.ROCK
			if rand < 0.06:
				return StructureType.TOWER

	return StructureType.NONE


func _can_place_structure(terrain: Array, x: int, y: int, size: Vector2i) -> bool:
	# Check if all tiles in the structure footprint are valid
	for dy in range(size.y):
		for dx in range(size.x):
			var px := x + dx
			var py := y - dy  # Structures grow upward (y - dy)

			# Bounds check
			if px < 0 or px >= width or py < 0 or py >= height:
				return false

			# Already occupied check
			if _structure_map.has(Vector2i(px, py)):
				return false

			# Terrain compatibility (don't place on water)
			var t: int = terrain[py][px]
			if t == TerrainType.DEEP_WATER or t == TerrainType.SHALLOW_WATER:
				return false

	return true


func _place_structure(grid: Array, objects: Array, structure: int, x: int, y: int, size: Vector2i) -> void:
	# Mark all tiles as occupied
	for dy in range(size.y):
		for dx in range(size.x):
			var px := x + dx
			var py := y - dy
			if py >= 0 and py < height and px >= 0 and px < width:
				_structure_map[Vector2i(px, py)] = true
				# Mark grid (base tile gets the type, others get a marker)
				if dx == 0 and dy == 0:
					grid[py][px] = structure
				else:
					grid[py][px] = -structure  # Negative = part of multi-tile

	# Add to objects list for rendering
	objects.append({
		"type": structure,
		"x": x,
		"y": y,
		"width": size.x,
		"height": size.y
	})


# ==================== SCENE BUILDING ====================

func _save_scene(terrain: Array, structures_data: Dictionary) -> String:
	var scene_path := "res://addons/ai_assistant/world/world_test.tscn"

	# Create scene content
	var tscn := """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/ai_assistant/world/world_runner.gd" id="1"]

[node name="WorldTest" type="Node2D"]
script = ExtResource("1")
world_width = %d
world_height = %d
world_seed = %d
tile_size = %d

[node name="UI" type="CanvasLayer" parent="."]

[node name="Instructions" type="Label" parent="UI"]
offset_left = 10.0
offset_top = 10.0
offset_right = 400.0
offset_bottom = 80.0
text = "WASD - Move | R - New World | ESC - Quit"

[node name="SeedLabel" type="Label" parent="UI"]
offset_left = 10.0
offset_top = 80.0
offset_right = 300.0
offset_bottom = 110.0
text = "Seed: %d"
""" % [width, height, seed_value, tile_size, seed_value]

	var file := FileAccess.open(scene_path, FileAccess.WRITE)
	if file:
		file.store_string(tscn)
		file.close()

	return scene_path


# ==================== TERRAIN COLORS ====================

static func get_terrain_color(t: int) -> Color:
	match t:
		TerrainType.DEEP_WATER: return Color(0.1, 0.2, 0.5)
		TerrainType.SHALLOW_WATER: return Color(0.2, 0.4, 0.7)
		TerrainType.SAND: return Color(0.9, 0.85, 0.6)
		TerrainType.GRASS: return Color(0.3, 0.7, 0.3)
		TerrainType.FOREST: return Color(0.2, 0.5, 0.2)
		TerrainType.DENSE_FOREST: return Color(0.1, 0.35, 0.15)
		TerrainType.HILLS: return Color(0.5, 0.45, 0.35)
		TerrainType.MOUNTAIN: return Color(0.4, 0.4, 0.45)
		TerrainType.SNOW: return Color(0.95, 0.95, 1.0)
	return Color.MAGENTA


static func get_structure_color(s: int) -> Color:
	match s:
		StructureType.NONE: return Color.TRANSPARENT
		StructureType.PATH: return Color(0.6, 0.5, 0.3)
		StructureType.HOUSE: return Color(0.8, 0.4, 0.2)
		StructureType.TOWER: return Color(0.5, 0.5, 0.6)
		StructureType.WALL: return Color(0.45, 0.45, 0.5)
		StructureType.TREE: return Color(0.15, 0.4, 0.15)
		StructureType.ROCK: return Color(0.5, 0.5, 0.55)
	return Color.TRANSPARENT
