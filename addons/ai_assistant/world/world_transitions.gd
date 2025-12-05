class_name WorldTransitions
extends RefCounted

## Handles Wang tile transitions between terrain types

# RetroDiffusion 4x5 Wang tile layout -> Wang index mapping
const RD_LAYOUT := [
	[0,  1,  3,  2],
	[0,  5, 15, 10],
	[0,  4, 12,  8],
	[15, 14, 13,  6],
	[15, 11,  7,  9],
]

# Wang index -> RetroDiffusion atlas coordinates (primary tiles)
const WANG_TO_RD: Dictionary = {
	0:  Vector2i(0, 0),   # Full outside
	1:  Vector2i(1, 0),   # BR corner inside
	2:  Vector2i(3, 0),   # BL corner inside
	3:  Vector2i(2, 0),   # Bottom edge inside
	4:  Vector2i(1, 2),   # TR corner inside
	5:  Vector2i(1, 1),   # Right edge inside
	6:  Vector2i(3, 3),   # Diagonal TR-BL
	7:  Vector2i(2, 4),   # Missing TL corner
	8:  Vector2i(3, 2),   # TL corner inside
	9:  Vector2i(3, 4),   # Diagonal TL-BR
	10: Vector2i(3, 1),   # Left edge inside
	11: Vector2i(1, 4),   # Missing TR corner
	12: Vector2i(2, 2),   # Top edge inside
	13: Vector2i(2, 3),   # Missing BL corner
	14: Vector2i(1, 3),   # Missing BR corner
	15: Vector2i(2, 1),   # Full inside
}


## Calculate Wang tile index based on which neighbors have the inside terrain
## terrain_data: 2D array of terrain indices
## x, y: position to calculate transition for
## inside_terrain_idx: the "inside" terrain that creeps into corners
func calculate_wang_index(terrain_data: Array, x: int, y: int, inside_terrain_idx: int) -> int:
	var height: int = terrain_data.size()
	var width: int = terrain_data[0].size() if height > 0 else 0

	# Check all 8 neighbors for inside terrain
	var north_inside := false
	var east_inside := false
	var south_inside := false
	var west_inside := false
	var nw_inside := false
	var ne_inside := false
	var sw_inside := false
	var se_inside := false

	# Cardinal checks
	if y > 0:
		north_inside = terrain_data[y - 1][x] == inside_terrain_idx
	if x + 1 < width:
		east_inside = terrain_data[y][x + 1] == inside_terrain_idx
	if y + 1 < height:
		south_inside = terrain_data[y + 1][x] == inside_terrain_idx
	if x > 0:
		west_inside = terrain_data[y][x - 1] == inside_terrain_idx

	# Diagonal checks
	if x > 0 and y > 0:
		nw_inside = terrain_data[y - 1][x - 1] == inside_terrain_idx
	if x + 1 < width and y > 0:
		ne_inside = terrain_data[y - 1][x + 1] == inside_terrain_idx
	if x > 0 and y + 1 < height:
		sw_inside = terrain_data[y + 1][x - 1] == inside_terrain_idx
	if x + 1 < width and y + 1 < height:
		se_inside = terrain_data[y + 1][x + 1] == inside_terrain_idx

	# Convert to corner values
	var tl: int = 1 if (north_inside or west_inside or nw_inside) else 0
	var tr: int = 1 if (north_inside or east_inside or ne_inside) else 0
	var bl: int = 1 if (south_inside or west_inside or sw_inside) else 0
	var br: int = 1 if (south_inside or east_inside or se_inside) else 0

	# Wang index formula: (TL × 8) + (TR × 4) + (BL × 2) + BR
	return (tl * 8) + (tr * 4) + (bl * 2) + br


## Get Wang tile atlas coordinates from wang index
func get_wang_tile_coords(wang_index: int, grid_cols: int = 4, grid_rows: int = 5) -> Vector2i:
	# Use the WANG_TO_RD lookup for standard 4x5 RetroDiffusion layout
	if grid_cols == 4 and grid_rows == 5:
		return WANG_TO_RD.get(wang_index, Vector2i(0, 0))

	# For non-standard grids, calculate position from RD_LAYOUT
	for row in range(mini(grid_rows, 5)):
		for col in range(mini(grid_cols, 4)):
			if RD_LAYOUT[row][col] == wang_index:
				return Vector2i(col, row)

	return Vector2i(0, 0)


## Find all cells that need transition tiles between terrain pairs
func get_transition_cells(terrain_data: Array, terrain_names: Array[String], available_transitions: Dictionary) -> Dictionary:
	var cells: Dictionary = {}  # Vector2i -> {from_idx, to_idx, trans_key, wang_index}
	var width: int = terrain_data[0].size() if terrain_data.size() > 0 else 0
	var height: int = terrain_data.size()

	# Check every cell for transitions
	for y in range(height):
		for x in range(width):
			var current_idx: int = terrain_data[y][x]
			var current_terrain: String = terrain_names[current_idx] if current_idx < terrain_names.size() else ""

			# Check ALL 8 neighbors for different terrain
			var neighbor_terrains: Dictionary = {}
			var dirs: Array[Vector2i] = [
				Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
				Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
			]

			for dir: Vector2i in dirs:
				var nx: int = x + dir.x
				var ny: int = y + dir.y
				if nx >= 0 and nx < width and ny >= 0 and ny < height:
					var neighbor_idx: int = terrain_data[ny][nx]
					if neighbor_idx != current_idx:
						var neighbor_terrain: String = terrain_names[neighbor_idx] if neighbor_idx < terrain_names.size() else ""
						neighbor_terrains[neighbor_terrain] = neighbor_idx

			# For each neighboring terrain type, check if we have a transition tileset
			for neighbor_terrain in neighbor_terrains.keys():
				var neighbor_idx: int = neighbor_terrains[neighbor_terrain]

				var trans_key: String = current_terrain + "_" + neighbor_terrain
				var reverse_key: String = neighbor_terrain + "_" + current_terrain

				if available_transitions.has(trans_key) or available_transitions.has(reverse_key):
					var from_idx: int
					var to_idx: int
					var used_key: String

					if available_transitions.has(trans_key):
						used_key = trans_key
						from_idx = current_idx
						to_idx = neighbor_idx
					else:
						used_key = reverse_key
						from_idx = neighbor_idx
						to_idx = current_idx

					# Only place on cells with the OUTSIDE terrain
					if current_idx != to_idx:
						continue

					var wang_index := calculate_wang_index(terrain_data, x, y, from_idx)

					# Skip fully outside (0) or fully inside (15)
					if wang_index == 0 or wang_index == 15:
						continue

					cells[Vector2i(x, y)] = {
						"from_idx": from_idx,
						"to_idx": to_idx,
						"trans_key": used_key,
						"wang_index": wang_index
					}
					break  # Only one transition per cell

	return cells


## Parse a wang tileset image into individual tile textures
func parse_wang_tileset(tileset_texture: Texture2D, tile_size: int, cols: int = 4, rows: int = 5) -> Array[Texture2D]:
	var tiles: Array[Texture2D] = []
	var img := tileset_texture.get_image()

	for row in range(rows):
		for col in range(cols):
			var tile_img := Image.create(tile_size, tile_size, false, img.get_format())
			var src_x := col * tile_size
			var src_y := row * tile_size

			for py in range(tile_size):
				for px in range(tile_size):
					if src_x + px < img.get_width() and src_y + py < img.get_height():
						tile_img.set_pixel(px, py, img.get_pixel(src_x + px, src_y + py))

			tiles.append(ImageTexture.create_from_image(tile_img))

	return tiles
