class_name WorldTerrain
extends RefCounted

## Handles procedural terrain generation using noise

var _elevation_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite


func setup_noise(p_seed: int) -> void:
	_elevation_noise = FastNoiseLite.new()
	_elevation_noise.seed = p_seed
	_elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_elevation_noise.frequency = 0.01
	_elevation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_elevation_noise.fractal_octaves = 4

	_moisture_noise = FastNoiseLite.new()
	_moisture_noise.seed = p_seed + 1000
	_moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moisture_noise.frequency = 0.015
	_moisture_noise.fractal_octaves = 3


## Generate terrain data from manifest terrains
## Returns 2D array of terrain indices based on elevation
func generate_terrain(width: int, height: int, terrain_names: Array[String]) -> Array:
	var terrain: Array = []
	var num_terrains := terrain_names.size()

	if num_terrains == 0:
		return terrain

	for y in range(height):
		var row: Array = []
		for x in range(width):
			var e := (_elevation_noise.get_noise_2d(x, y) + 1.0) / 2.0

			# Map elevation to terrain index based on manifest order
			# First terrain at low elevation, last at high elevation
			var terrain_idx := int(e * num_terrains)
			terrain_idx = clampi(terrain_idx, 0, num_terrains - 1)

			row.append(terrain_idx)
		terrain.append(row)

	return terrain


## Object sizes from manifest (set by world_runner before generation)
var _object_sizes: Dictionary = {}


## Set object sizes from manifest
func set_object_sizes(sizes: Dictionary) -> void:
	_object_sizes = sizes


## Generate structure placements based on terrain and manifest spawn rates
## manifest_terrain: Dictionary of terrain data from manifest with "spawns" arrays
## Returns {grid: 2D array, objects: Array of object data}
func generate_structures(terrain_data: Array, terrain_names: Array[String], manifest_terrain: Dictionary = {}) -> Dictionary:
	var width: int = terrain_data[0].size() if terrain_data.size() > 0 else 0
	var height: int = terrain_data.size()

	var structures_grid: Array = []
	var structure_objects: Array = []

	# Initialize empty grid
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(0)
		structures_grid.append(row)

	# Build spawn config per terrain from manifest
	var spawn_config: Dictionary = _build_spawn_config(terrain_names, manifest_terrain)

	# Place objects based on terrain spawn configuration
	for y in range(height):
		for x in range(width):
			var terrain_idx: int = terrain_data[y][x]
			var terrain_name: String = terrain_names[terrain_idx] if terrain_idx < terrain_names.size() else ""

			# Skip if no spawns configured for this terrain
			if not spawn_config.has(terrain_name):
				continue

			var roll := randf() * 100.0  # 0-100 for percentage comparison

			# Check each spawn in order by percent (cumulative)
			var cumulative := 0.0
			var spawns: Array = spawn_config[terrain_name]
			for spawn in spawns:
				cumulative += spawn.percent
				if roll < cumulative:
					var obj_name: String = spawn.object
					var obj_size: Vector2i = _get_object_size(obj_name)
					# Pass object name directly so tilemap can load any texture
					structure_objects.append(_make_structure_named(obj_name, x, y, obj_size.x, obj_size.y))
					break

	return {
		"grid": structures_grid,
		"objects": structure_objects
	}


## Build spawn configuration dictionary from manifest terrain data
func _build_spawn_config(terrain_names: Array[String], manifest_terrain: Dictionary) -> Dictionary:
	var config: Dictionary = {}

	for terrain_name in terrain_names:
		if manifest_terrain.has(terrain_name):
			var terrain_data: Dictionary = manifest_terrain[terrain_name]
			var spawns: Array = terrain_data.get("spawns", [])
			if not spawns.is_empty():
				config[terrain_name] = spawns

	# Fallback to hardcoded defaults if no spawn config in manifest
	if config.is_empty():
		config = _get_default_spawn_config()

	return config


## Get fallback spawn config when manifest has no spawns defined
func _get_default_spawn_config() -> Dictionary:
	return {
		"sand": [
			{"object": "palm_tree", "percent": 1.5},
			{"object": "rock", "percent": 0.5}
		],
		"forest": [
			{"object": "tree", "percent": 4.0},
			{"object": "bush", "percent": 2.0}
		],
		"grass": [
			{"object": "tree", "percent": 2.0},
			{"object": "rock", "percent": 0.5},
			{"object": "bush", "percent": 0.5}
		]
	}


## Map object name to type ID for structure placement
func _get_object_type(obj_name: String) -> int:
	match obj_name.to_lower():
		"tree": return 5
		"rock": return 6
		"bush": return 7
		"palm_tree": return 8
		_: return 5  # Default to tree


## Get object size (width, height) for structure placement
## Uses manifest sizes if available, otherwise falls back to defaults
func _get_object_size(obj_name: String) -> Vector2i:
	# Check manifest sizes first
	if _object_sizes.has(obj_name):
		var obj_data: Dictionary = _object_sizes[obj_name]
		var w: int = obj_data.get("width", 1)
		var h: int = obj_data.get("height", 1)
		return Vector2i(w, h)

	# Fallback defaults for common objects
	match obj_name.to_lower():
		"tree", "palm_tree": return Vector2i(1, 2)
		"rock", "bush": return Vector2i(1, 1)
		_: return Vector2i(1, 1)


func _make_structure(type: int, x: int, y: int, w: int, h: int) -> Dictionary:
	return {"type": type, "x": x, "y": y, "width": w, "height": h}


func _make_structure_named(obj_name: String, x: int, y: int, w: int, h: int) -> Dictionary:
	return {"name": obj_name, "x": x, "y": y, "width": w, "height": h}


## Find a spawn position on non-water terrain near center
func find_spawn_position(terrain_data: Array, terrain_names: Array[String], tile_size: int) -> Vector2:
	var height: int = terrain_data.size()
	var width: int = terrain_data[0].size() if height > 0 else 0
	var cx := width / 2
	var cy := height / 2

	for r in range(max(width, height) / 2):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var x := cx + dx
				var y := cy + dy
				if x >= 0 and x < width and y >= 0 and y < height:
					var terrain_idx: int = terrain_data[y][x]
					var terrain_name: String = terrain_names[terrain_idx] if terrain_idx < terrain_names.size() else ""
					if terrain_name != "water":
						return Vector2(x * tile_size + tile_size / 2, y * tile_size + tile_size / 2)

	return Vector2(cx * tile_size, cy * tile_size)
