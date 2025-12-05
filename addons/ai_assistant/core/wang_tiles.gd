@tool
class_name WangTiles
extends RefCounted

## Wang Tile Parser for rd-tile tileset_advanced output
## rd-tile outputs a 4x5 grid (20 tiles) for transitions between two terrains
## This class extracts individual tiles and provides lookup by edge configuration

# Tileset dimensions from rd-tile tileset_advanced
const GRID_COLS := 4
const GRID_ROWS := 5
const TILE_COUNT := 20

# Edge configuration bits (which edges touch the "from" terrain vs "to" terrain)
# Using 4-bit mask: Top, Right, Bottom, Left (TRBL)
# 0 = "from" terrain on that edge, 1 = "to" terrain on that edge
enum Edge {
	TOP = 8,     # 1000
	RIGHT = 4,   # 0100
	BOTTOM = 2,  # 0010
	LEFT = 1     # 0001
}

# Cache of parsed tilesets: key -> Array of 20 Texture2D tiles
var _tileset_cache: Dictionary = {}

# Mapping from edge mask (0-15) to tile index in the 4x5 grid
# This is the standard rd-tile wang tile layout
# Index = row * 4 + col
var _edge_to_tile_index: Dictionary = {
	# Full "from" terrain (no "to" edges)
	0b0000: 0,   # All edges are "from" terrain

	# Single edge transitions
	0b1000: 1,   # Top edge is "to"
	0b0100: 2,   # Right edge is "to"
	0b0010: 3,   # Bottom edge is "to"
	0b0001: 4,   # Left edge is "to"

	# Corner transitions (two adjacent edges)
	0b1100: 5,   # Top + Right
	0b0110: 6,   # Right + Bottom
	0b0011: 7,   # Bottom + Left
	0b1001: 8,   # Left + Top

	# Opposite edge transitions
	0b1010: 9,   # Top + Bottom
	0b0101: 10,  # Right + Left

	# Three edge transitions
	0b1110: 11,  # Top + Right + Bottom
	0b0111: 12,  # Right + Bottom + Left
	0b1011: 13,  # Bottom + Left + Top
	0b1101: 14,  # Left + Top + Right

	# Full "to" terrain (all edges)
	0b1111: 15,  # All edges are "to" terrain

	# Additional tiles in 4x5 grid (indices 16-19) are variations/corners
	# We'll use them for inner corners
}


## Parse a tileset image (64x80 for 16px tiles) into individual tile textures
func parse_tileset(tileset_image: Image, tile_size: int) -> Array[Texture2D]:
	var tiles: Array[Texture2D] = []

	var expected_width := tile_size * GRID_COLS
	var expected_height := tile_size * GRID_ROWS

	# Verify dimensions
	if tileset_image.get_width() != expected_width or tileset_image.get_height() != expected_height:
		push_warning("[WangTiles] Unexpected tileset size: %dx%d, expected %dx%d" % [
			tileset_image.get_width(), tileset_image.get_height(),
			expected_width, expected_height
		])
		# Try to work with it anyway

	# Extract each tile from the grid
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var tile_img := Image.create(tile_size, tile_size, false, tileset_image.get_format())

			# Copy pixels from tileset to individual tile
			var src_x := col * tile_size
			var src_y := row * tile_size

			for py in range(tile_size):
				for px in range(tile_size):
					if src_x + px < tileset_image.get_width() and src_y + py < tileset_image.get_height():
						tile_img.set_pixel(px, py, tileset_image.get_pixel(src_x + px, src_y + py))

			tiles.append(ImageTexture.create_from_image(tile_img))

	return tiles


## Load and cache a transition tileset from file
func load_transition_tileset(tileset_path: String, tile_size: int) -> Array[Texture2D]:
	if _tileset_cache.has(tileset_path):
		return _tileset_cache[tileset_path]

	if not FileAccess.file_exists(tileset_path):
		push_warning("[WangTiles] Tileset not found: " + tileset_path)
		return []

	var texture: Texture2D = load(tileset_path)
	if not texture:
		push_warning("[WangTiles] Failed to load tileset: " + tileset_path)
		return []

	var tiles := parse_tileset(texture.get_image(), tile_size)
	_tileset_cache[tileset_path] = tiles

	print("[WangTiles] Loaded %d tiles from: %s" % [tiles.size(), tileset_path])
	return tiles


## Get the tile index for a given edge configuration
## edge_mask: 4-bit mask (TRBL) indicating which edges touch the "to" terrain
func get_tile_index(edge_mask: int) -> int:
	edge_mask = edge_mask & 0b1111  # Ensure 4 bits only

	if _edge_to_tile_index.has(edge_mask):
		return _edge_to_tile_index[edge_mask]

	# Fallback to closest match or center tile
	return 0


## Calculate edge mask based on neighboring terrain types
## Returns which edges of this cell touch the "to" terrain
## terrain_grid: 2D array of terrain indices
## x, y: position to check
## from_terrain_idx: the "from" terrain index
## to_terrain_idx: the "to" terrain index
func calculate_edge_mask(terrain_grid: Array, x: int, y: int, from_terrain_idx: int, to_terrain_idx: int) -> int:
	var width: int = terrain_grid[0].size() if terrain_grid.size() > 0 else 0
	var height: int = terrain_grid.size()

	var mask := 0

	# Check top neighbor
	if y > 0:
		var top_terrain: int = terrain_grid[y - 1][x]
		if top_terrain == to_terrain_idx:
			mask |= Edge.TOP

	# Check right neighbor
	if x < width - 1:
		var right_terrain: int = terrain_grid[y][x + 1]
		if right_terrain == to_terrain_idx:
			mask |= Edge.RIGHT

	# Check bottom neighbor
	if y < height - 1:
		var bottom_terrain: int = terrain_grid[y + 1][x]
		if bottom_terrain == to_terrain_idx:
			mask |= Edge.BOTTOM

	# Check left neighbor
	if x > 0:
		var left_terrain: int = terrain_grid[y][x - 1]
		if left_terrain == to_terrain_idx:
			mask |= Edge.LEFT

	return mask


## Check if a cell needs a transition tile
## Returns true if at least one neighbor is a different terrain
func needs_transition(terrain_grid: Array, x: int, y: int) -> bool:
	var width: int = terrain_grid[0].size() if terrain_grid.size() > 0 else 0
	var height: int = terrain_grid.size()
	var current: int = terrain_grid[y][x]

	# Check all 4 neighbors
	if y > 0 and terrain_grid[y - 1][x] != current:
		return true
	if x < width - 1 and terrain_grid[y][x + 1] != current:
		return true
	if y < height - 1 and terrain_grid[y + 1][x] != current:
		return true
	if x > 0 and terrain_grid[y][x - 1] != current:
		return true

	return false


## Get the transition key for two terrain types (e.g., "grass_dirt")
func get_transition_key(from_terrain: String, to_terrain: String) -> String:
	return from_terrain + "_" + to_terrain


## Clear the cache (call when assets are regenerated)
func clear_cache() -> void:
	_tileset_cache.clear()
