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


## Generate structure placements based on terrain
## Returns {grid: 2D array, objects: Array of object data}
func generate_structures(terrain_data: Array, terrain_names: Array[String]) -> Dictionary:
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

	# Place objects on appropriate terrain (not water)
	for y in range(height):
		for x in range(width):
			var terrain_idx: int = terrain_data[y][x]
			var terrain_name: String = terrain_names[terrain_idx] if terrain_idx < terrain_names.size() else ""

			# Don't place on water
			if terrain_name == "water":
				continue

			var roll := randf()

			# Choose object type based on terrain
			if terrain_name == "sand":
				if roll < 0.015:
					structure_objects.append(_make_structure(8, x, y, 1, 2))  # PALM_TREE
				elif roll < 0.02:
					structure_objects.append(_make_structure(6, x, y, 1, 1))  # ROCK
			elif terrain_name == "forest":
				if roll < 0.04:
					structure_objects.append(_make_structure(5, x, y, 1, 2))  # TREE
				elif roll < 0.06:
					structure_objects.append(_make_structure(7, x, y, 1, 1))  # BUSH
			else:
				# Other terrain (grass, dirt, etc.)
				if roll < 0.02:
					structure_objects.append(_make_structure(5, x, y, 1, 2))  # TREE
				elif roll < 0.025:
					structure_objects.append(_make_structure(6, x, y, 1, 1))  # ROCK
				elif roll < 0.03:
					structure_objects.append(_make_structure(7, x, y, 1, 1))  # BUSH

	return {
		"grid": structures_grid,
		"objects": structure_objects
	}


func _make_structure(type: int, x: int, y: int, w: int, h: int) -> Dictionary:
	return {"type": type, "x": x, "y": y, "width": w, "height": h}


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
