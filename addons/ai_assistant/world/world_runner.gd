extends Node2D

## Runtime world display and player controller
## This script runs the generated world with optional AI-generated assets
## Supports wang tile transitions between terrain types

@export var world_width: int = 128
@export var world_height: int = 128
@export var world_seed: int = 0
@export var tile_size: int = 16
@export var theme: String = "plains"

var terrain_layer: TileMapLayer
var transition_layer: TileMapLayer  # Layer for transition tiles (above terrain)
var structure_layer: TileMapLayer
var object_sprites: Node2D  # For multi-tile structure sprites
var player: CharacterBody2D
var camera: Camera2D
var is_generating := false

# Asset paths
const ASSET_BASE := "res://assets/"
const MANIFEST_PATH := "res://assets/manifest.json"

# Terrain types from manifest
var _manifest_terrains: Array[String] = []

# Asset cache
var _terrain_textures: Dictionary = {}  # terrain_name -> Texture2D
var _transition_textures: Dictionary = {}  # "from_to" -> Array[Texture2D] (20 wang tiles)
var _object_textures: Dictionary = {}   # object_name -> Array[Texture2D] (multiple variants)

# Wang tile parser
var _wang_tiles: RefCounted = null

# Noise for terrain distribution
var _elevation_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	generate_world()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			world_seed = 0
			generate_world()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()


func generate_world() -> void:
	if is_generating:
		return
	is_generating = true

	_clear()

	var gen_seed := world_seed if world_seed != 0 else randi()
	seed(gen_seed)

	# Load manifest to get requested terrains
	_load_manifest()
	_load_assets()

	# Setup noise
	_setup_noise(gen_seed)

	# Generate terrain using ONLY manifest terrains
	var terrain_data := _generate_terrain_from_manifest()

	# Generate structures
	var structures_data := _generate_structures(terrain_data)

	# Build the visual tilemap
	_build_tilemap_from_manifest(terrain_data, structures_data)
	_spawn_player_on_terrain(terrain_data)
	_setup_camera()
	_update_ui(gen_seed)

	is_generating = false


func _load_manifest() -> void:
	_manifest_terrains.clear()

	if not FileAccess.file_exists(MANIFEST_PATH):
		print("No manifest found, using defaults")
		_manifest_terrains = ["water", "sand", "grass"]
		return

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not file:
		_manifest_terrains = ["water", "sand", "grass"]
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_manifest_terrains = ["water", "sand", "grass"]
		return

	var data: Dictionary = json.data
	var terrain_dict: Dictionary = data.get("terrain", {})

	for terrain_name in terrain_dict.keys():
		_manifest_terrains.append(terrain_name)

	if _manifest_terrains.is_empty():
		_manifest_terrains = ["water", "sand", "grass"]

	print("Loaded manifest terrains: ", _manifest_terrains)


func _setup_noise(p_seed: int) -> void:
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


func _generate_terrain_from_manifest() -> Array:
	var terrain: Array = []
	var num_terrains := _manifest_terrains.size()

	if num_terrains == 0:
		return terrain

	for y in range(world_height):
		var row: Array = []
		for x in range(world_width):
			var e := (_elevation_noise.get_noise_2d(x, y) + 1.0) / 2.0

			# Map elevation to terrain index based on manifest order
			# First terrain (usually water) at low elevation
			# Last terrain at high elevation
			var terrain_idx := int(e * num_terrains)
			terrain_idx = clampi(terrain_idx, 0, num_terrains - 1)

			row.append(terrain_idx)
		terrain.append(row)

	return terrain


func _generate_structures(terrain_data: Array) -> Dictionary:
	var structures_grid: Array = []
	var structure_objects: Array = []

	# Initialize empty grid
	for y in range(world_height):
		var row: Array = []
		for x in range(world_width):
			row.append(0)  # 0 = no structure
		structures_grid.append(row)

	# Place objects on appropriate terrain (not water)
	for y in range(world_height):
		for x in range(world_width):
			var terrain_idx: int = terrain_data[y][x]
			var terrain_name: String = _manifest_terrains[terrain_idx] if terrain_idx < _manifest_terrains.size() else ""

			# Don't place on water
			if terrain_name == "water":
				continue

			var roll := randf()

			# Choose object type based on terrain
			if terrain_name == "sand":
				# Desert/beach terrain - palm trees and rocks
				if roll < 0.015:  # Palm trees on sand
					structure_objects.append({
						"type": 8,  # PALM_TREE
						"x": x,
						"y": y,
						"width": 1,
						"height": 2
					})
				elif roll < 0.02:  # Rocks on sand
					structure_objects.append({
						"type": 6,  # ROCK
						"x": x,
						"y": y,
						"width": 1,
						"height": 1
					})
			elif terrain_name == "forest":
				# Forest terrain - regular trees and bushes
				if roll < 0.04:  # More trees in forest
					structure_objects.append({
						"type": 5,  # TREE
						"x": x,
						"y": y,
						"width": 1,
						"height": 2
					})
				elif roll < 0.06:  # Bushes in forest
					structure_objects.append({
						"type": 7,  # BUSH
						"x": x,
						"y": y,
						"width": 1,
						"height": 1
					})
			else:
				# Other terrain (grass, dirt, etc.)
				if roll < 0.02:  # Trees
					structure_objects.append({
						"type": 5,  # TREE
						"x": x,
						"y": y,
						"width": 1,
						"height": 2
					})
				elif roll < 0.025:  # Rocks
					structure_objects.append({
						"type": 6,  # ROCK
						"x": x,
						"y": y,
						"width": 1,
						"height": 1
					})
				elif roll < 0.03:  # Bushes
					structure_objects.append({
						"type": 7,  # BUSH
						"x": x,
						"y": y,
						"width": 1,
						"height": 1
					})

	return {
		"grid": structures_grid,
		"objects": structure_objects
	}


func _build_tilemap_from_manifest(terrain_data: Array, structures_data: Dictionary) -> void:
	var tileset := _create_manifest_tileset()

	terrain_layer = TileMapLayer.new()
	terrain_layer.name = "Terrain"
	terrain_layer.tile_set = tileset
	add_child(terrain_layer)

	# Transition layer sits between terrain and structures
	transition_layer = TileMapLayer.new()
	transition_layer.name = "Transitions"
	transition_layer.tile_set = _create_transition_tileset()
	transition_layer.z_index = 0  # Same level as terrain, rendered after
	add_child(transition_layer)

	structure_layer = TileMapLayer.new()
	structure_layer.name = "Structures"
	structure_layer.tile_set = tileset
	structure_layer.z_index = 1
	add_child(structure_layer)

	object_sprites = Node2D.new()
	object_sprites.name = "ObjectSprites"
	object_sprites.z_index = 2
	add_child(object_sprites)

	# First, identify which cells need transitions and which transitions are available
	var transition_cells := _get_transition_cells(terrain_data)

	# Place terrain tiles (skip cells that will have transitions)
	for y in range(world_height):
		for x in range(world_width):
			var cell_key := Vector2i(x, y)
			if not transition_cells.has(cell_key):
				var terrain_idx: int = terrain_data[y][x]
				terrain_layer.set_cell(cell_key, 0, Vector2i(terrain_idx, 0))

	# Place transition tiles where terrain types meet
	_place_transition_tiles(terrain_data, transition_cells)

	# Place structure sprites
	var structure_objects: Array = structures_data.get("objects", [])
	_place_structure_sprites_manifest(structure_objects)


func _create_manifest_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)

	# Create terrain atlas from manifest terrains
	var t_src := TileSetAtlasSource.new()
	t_src.texture = _make_manifest_terrain_texture()
	t_src.texture_region_size = Vector2i(tile_size, tile_size)
	ts.add_source(t_src, 0)

	# Create tiles for each terrain type
	for i in range(_manifest_terrains.size()):
		t_src.create_tile(Vector2i(i, 0))

	return ts


func _make_manifest_terrain_texture() -> ImageTexture:
	var num_terrains := _manifest_terrains.size()
	if num_terrains == 0:
		num_terrains = 1

	var img := Image.create(tile_size * num_terrains, tile_size, false, Image.FORMAT_RGBA8)

	for i in range(_manifest_terrains.size()):
		var terrain_name: String = _manifest_terrains[i]

		# Check if we have a generated texture for this terrain
		if _terrain_textures.has(terrain_name):
			var loaded_tex: Texture2D = _terrain_textures[terrain_name]
			var loaded_img: Image = loaded_tex.get_image()

			# Resize if needed to match tile_size
			if loaded_img.get_width() != tile_size or loaded_img.get_height() != tile_size:
				loaded_img.resize(tile_size, tile_size, Image.INTERPOLATE_NEAREST)

			# Copy the loaded terrain image into the atlas
			for py in range(tile_size):
				for px in range(tile_size):
					var pixel_color := loaded_img.get_pixel(px, py)
					img.set_pixel(i * tile_size + px, py, pixel_color)

			print("[World] Using generated texture for terrain: ", terrain_name)
		else:
			# Fallback: colored placeholder
			var color := _get_terrain_color_by_name(terrain_name)
			for py in range(tile_size):
				for px in range(tile_size):
					var c := color
					c.r = clampf(c.r + randf_range(-0.03, 0.03), 0, 1)
					c.g = clampf(c.g + randf_range(-0.03, 0.03), 0, 1)
					c.b = clampf(c.b + randf_range(-0.03, 0.03), 0, 1)
					img.set_pixel(i * tile_size + px, py, c)

			print("[World] Using placeholder for terrain: ", terrain_name)

	return ImageTexture.create_from_image(img)


func _get_terrain_color_by_name(terrain_name: String) -> Color:
	match terrain_name:
		"water":
			return Color(0.1, 0.3, 0.7)
		"sand":
			return Color(0.9, 0.85, 0.6)
		"grass":
			return Color(0.3, 0.6, 0.2)
		"forest":
			return Color(0.15, 0.4, 0.15)
		"snow":
			return Color(0.95, 0.95, 1.0)
		"desert":
			return Color(0.85, 0.7, 0.4)
		"mountain", "rock":
			return Color(0.5, 0.5, 0.5)
		"dirt":
			return Color(0.55, 0.4, 0.25)
		_:
			return Color(0.5, 0.5, 0.5)


## Create tileset for transition tiles (wang tiles)
## Each transition type gets 20 tiles in a 4x5 grid
func _create_transition_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)

	# Load transition tilesets from manifest
	var manifest := _load_manifest_data()
	var transitions: Dictionary = manifest.get("transitions", {})

	var source_id := 0
	for trans_key in transitions.keys():
		var trans_data: Dictionary = transitions[trans_key]
		var generated: bool = trans_data.get("generated", false)

		if generated:
			var file_path: String = trans_data.get("file", "")
			var trans_path: String = ASSET_BASE + file_path
			if ResourceLoader.exists(trans_path):
				var trans_tex: Texture2D = load(trans_path)
				if trans_tex:
					# Parse the 4x5 wang tileset
					var tiles := _parse_wang_tileset(trans_tex)
					_transition_textures[trans_key] = tiles

					# Create atlas source for this transition
					var t_src := TileSetAtlasSource.new()
					t_src.texture = trans_tex
					t_src.texture_region_size = Vector2i(tile_size, tile_size)
					ts.add_source(t_src, source_id)

					# Create all 20 tiles in the 4x5 grid
					for row in range(5):
						for col in range(4):
							t_src.create_tile(Vector2i(col, row))

					print("[World] Loaded transition tileset: ", trans_key, " as source ", source_id)
					source_id += 1

	return ts


## Parse a wang tileset image (64x80 for 16px tiles) into individual tiles
func _parse_wang_tileset(tileset_texture: Texture2D) -> Array[Texture2D]:
	var tiles: Array[Texture2D] = []
	var img := tileset_texture.get_image()

	var cols := 4
	var rows := 5

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


## Get cells that need transition tiles and have available tilesets
func _get_transition_cells(terrain_data: Array) -> Dictionary:
	var cells: Dictionary = {}  # Vector2i -> transition info
	var manifest := _load_manifest_data()
	var transitions: Dictionary = manifest.get("transitions", {})

	# Build available transitions set
	var available_transitions: Dictionary = {}
	for trans_key in transitions.keys():
		var trans_data: Dictionary = transitions[trans_key]
		if trans_data.get("generated", false):
			available_transitions[trans_key] = true

	# Find cells at terrain boundaries with available transitions
	for y in range(world_height):
		for x in range(world_width):
			var current_idx: int = terrain_data[y][x]
			var current_terrain: String = _manifest_terrains[current_idx] if current_idx < _manifest_terrains.size() else ""
			var neighbors := _get_different_neighbors(terrain_data, x, y, current_idx)

			if neighbors.size() > 0:
				var neighbor_idx: int = neighbors[0]["terrain_idx"]
				var neighbor_terrain: String = _manifest_terrains[neighbor_idx] if neighbor_idx < _manifest_terrains.size() else ""

				var trans_key := current_terrain + "_" + neighbor_terrain
				var reverse_key := neighbor_terrain + "_" + current_terrain

				if available_transitions.has(trans_key) or available_transitions.has(reverse_key):
					cells[Vector2i(x, y)] = {
						"current": current_terrain,
						"neighbor": neighbor_terrain,
						"neighbors": neighbors
					}

	return cells


## Place transition tiles where different terrains meet
## Transition tiles REPLACE base terrain (not overlay)
func _place_transition_tiles(terrain_data: Array, transition_cells: Dictionary) -> void:
	var manifest := _load_manifest_data()
	var transitions: Dictionary = manifest.get("transitions", {})

	# Build a map of transition keys to source IDs
	var transition_sources: Dictionary = {}
	var source_id := 0
	for trans_key in transitions.keys():
		var trans_data: Dictionary = transitions[trans_key]
		if trans_data.get("generated", false):
			transition_sources[trans_key] = source_id
			source_id += 1

	# Place transition tiles
	for cell_pos in transition_cells.keys():
		var cell_info: Dictionary = transition_cells[cell_pos]
		var current_terrain: String = cell_info["current"]
		var neighbor_terrain: String = cell_info["neighbor"]
		var neighbors: Array = cell_info["neighbors"]

		# Try both directions for transition key
		var trans_key := current_terrain + "_" + neighbor_terrain
		var reverse_key := neighbor_terrain + "_" + current_terrain

		var used_key := ""
		var is_reverse := false

		if transition_sources.has(trans_key):
			used_key = trans_key
		elif transition_sources.has(reverse_key):
			used_key = reverse_key
			is_reverse = true

		if not used_key.is_empty():
			var src_id: int = transition_sources[used_key]
			var edge_mask := _calculate_edge_mask(neighbors, is_reverse)
			var tile_coords := _edge_mask_to_tile_coords(edge_mask)

			# Place in transition layer (which replaces terrain at this position)
			transition_layer.set_cell(cell_pos, src_id, tile_coords)


## Get list of neighbors with different terrain
func _get_different_neighbors(terrain_data: Array, x: int, y: int, current_idx: int) -> Array:
	var neighbors: Array = []

	# Check 4 cardinal directions: top, right, bottom, left
	var dirs := [
		{"dx": 0, "dy": -1, "edge": "top"},
		{"dx": 1, "dy": 0, "edge": "right"},
		{"dx": 0, "dy": 1, "edge": "bottom"},
		{"dx": -1, "dy": 0, "edge": "left"}
	]

	for dir in dirs:
		var nx: int = x + dir["dx"]
		var ny: int = y + dir["dy"]

		if nx >= 0 and nx < world_width and ny >= 0 and ny < world_height:
			var neighbor_idx: int = terrain_data[ny][nx]
			if neighbor_idx != current_idx:
				neighbors.append({
					"edge": dir["edge"],
					"terrain_idx": neighbor_idx,
					"x": nx,
					"y": ny
				})

	return neighbors


## Calculate edge mask for wang tile selection
## Returns a 4-bit mask: Top(8) Right(4) Bottom(2) Left(1)
func _calculate_edge_mask(neighbors: Array, is_reverse: bool) -> int:
	var mask := 0

	for neighbor in neighbors:
		var edge: String = neighbor["edge"]
		match edge:
			"top":
				mask |= 8
			"right":
				mask |= 4
			"bottom":
				mask |= 2
			"left":
				mask |= 1

	# If using reverse transition, invert the mask
	if is_reverse:
		mask = (~mask) & 0b1111

	return mask


## Convert edge mask to tile coordinates in the 4x5 wang tileset
## rd-tile tileset_advanced layout (based on observation):
## Row 0: Base terrain A variations
## Row 1-3: Transition tiles with various edge combinations
## Row 4: Base terrain B variations
##
## Edge mask: Top(8) Right(4) Bottom(2) Left(1) = which edges touch OTHER terrain
func _edge_mask_to_tile_coords(edge_mask: int) -> Vector2i:
	# rd-tile uses a blob/marching-squares style layout
	# This mapping is approximate based on observed tileset output
	# The tileset has 4 cols x 5 rows = 20 tiles

	match edge_mask:
		# No transition needed - use full terrain A (top-left)
		0b0000:
			return Vector2i(0, 0)

		# Single edge transitions
		0b1000:  # Top edge different
			return Vector2i(1, 2)
		0b0100:  # Right edge different
			return Vector2i(2, 1)
		0b0010:  # Bottom edge different
			return Vector2i(1, 1)
		0b0001:  # Left edge different
			return Vector2i(0, 1)

		# Corner transitions (two adjacent edges)
		0b1100:  # Top + Right
			return Vector2i(3, 2)
		0b0110:  # Right + Bottom
			return Vector2i(3, 1)
		0b0011:  # Bottom + Left
			return Vector2i(0, 2)
		0b1001:  # Top + Left
			return Vector2i(2, 2)

		# Opposite edges (channel)
		0b1010:  # Top + Bottom
			return Vector2i(1, 3)
		0b0101:  # Left + Right
			return Vector2i(2, 3)

		# Three edges (peninsula into other terrain)
		0b1110:  # Top + Right + Bottom
			return Vector2i(3, 3)
		0b0111:  # Right + Bottom + Left
			return Vector2i(0, 3)
		0b1011:  # Top + Bottom + Left
			return Vector2i(1, 4)
		0b1101:  # Top + Right + Left
			return Vector2i(2, 4)

		# All edges different - use full terrain B (bottom-right area)
		0b1111:
			return Vector2i(3, 4)

		# Default fallback
		_:
			return Vector2i(0, 0)


func _place_structure_sprites_manifest(structure_objects: Array) -> void:
	for obj in structure_objects:
		var obj_type: int = obj["type"]
		var x: int = obj["x"]
		var y: int = obj["y"]
		var w: int = obj["width"]
		var h: int = obj["height"]

		var sprite := Sprite2D.new()
		sprite.name = "Structure_%d_%d" % [x, y]

		# Get texture
		var tex: Texture2D = _get_structure_texture_manifest(obj_type, w, h)
		sprite.texture = tex

		# Position
		sprite.position = Vector2(
			x * tile_size + (w * tile_size) / 2.0,
			y * tile_size + tile_size / 2.0
		)
		sprite.offset = Vector2(0, -tex.get_height() / 2.0 + tile_size / 2.0)
		sprite.z_index = y

		object_sprites.add_child(sprite)


func _get_structure_texture_manifest(structure_type: int, w: int, h: int) -> Texture2D:
	var type_names := {5: "tree", 6: "rock", 7: "bush", 8: "palm_tree"}
	var type_name: String = type_names.get(structure_type, "")

	if type_name != "" and _object_textures.has(type_name):
		var variants: Array = _object_textures[type_name]
		if variants.size() > 0:
			# Pick a random variant
			var variant_idx := randi() % variants.size()
			return variants[variant_idx]

	# Fallback placeholder
	return _make_placeholder_structure_manifest(structure_type, w, h)


func _make_placeholder_structure_manifest(structure_type: int, w: int, h: int) -> ImageTexture:
	var pw: int = w * tile_size
	var ph: int = h * tile_size
	var img := Image.create(pw, ph, false, Image.FORMAT_RGBA8)

	match structure_type:
		5:  # TREE
			var trunk_color := Color(0.4, 0.25, 0.15)
			img.fill_rect(Rect2i(pw / 3, ph * 2 / 3, pw / 3, ph / 3), trunk_color)
			var foliage_color := Color(0.15, 0.5, 0.15)
			var cx: int = pw / 2
			var cy: int = ph / 3
			var radius: int = mini(pw, ph * 2 / 3) / 2 - 2
			for py in range(ph * 2 / 3):
				for px in range(pw):
					var dx: float = px - cx
					var dy: float = py - cy
					if dx * dx + dy * dy < radius * radius:
						img.set_pixel(px, py, foliage_color)
		6:  # ROCK
			var rock_color := Color(0.5, 0.5, 0.55)
			var cx: int = pw / 2
			var cy: int = ph / 2
			for py in range(ph):
				for px in range(pw):
					var dx: float = (px - cx) * 1.2
					var dy: float = py - cy
					if dx * dx + dy * dy < (pw / 2 - 2) * (pw / 2 - 2):
						img.set_pixel(px, py, rock_color)
		_:
			img.fill_rect(Rect2i(0, 0, pw, ph), Color(0.5, 0.5, 0.5))

	return ImageTexture.create_from_image(img)


func _spawn_player_on_terrain(terrain_data: Array) -> void:
	player = CharacterBody2D.new()
	player.name = "Player"

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"

	if _object_textures.has("player"):
		sprite.texture = _object_textures["player"]
	else:
		# Fallback player sprite
		var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
		img.fill_rect(Rect2i(4, 8, 8, 14), Color(0.2, 0.6, 1.0))
		for py in range(8):
			for px in range(3, 13):
				var dx: float = px - 8
				var dy: float = py - 4
				if dx * dx + dy * dy < 16:
					img.set_pixel(px, py, Color(0.9, 0.75, 0.6))
		img.set_pixel(6, 4, Color.WHITE)
		img.set_pixel(9, 4, Color.WHITE)
		img.set_pixel(6, 5, Color.BLACK)
		img.set_pixel(9, 5, Color.BLACK)
		sprite.texture = ImageTexture.create_from_image(img)

	player.add_child(sprite)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	player.add_child(col)

	# Find spawn position (not on water)
	player.position = _find_spawn_on_terrain(terrain_data)

	# Movement script
	var code := """
extends CharacterBody2D
var speed := 150.0
func _ready(): _setup_input()
func _physics_process(_d):
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"): dir.y -= 1
	if Input.is_action_pressed("move_down"): dir.y += 1
	if Input.is_action_pressed("move_left"): dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	velocity = dir.normalized() * speed
	move_and_slide()
	if dir.x != 0: $Sprite2D.flip_h = dir.x < 0
func _setup_input():
	for act in ["move_up", "move_down", "move_left", "move_right"]:
		if not InputMap.has_action(act): InputMap.add_action(act)
	_add_key("move_up", KEY_W); _add_key("move_up", KEY_UP)
	_add_key("move_down", KEY_S); _add_key("move_down", KEY_DOWN)
	_add_key("move_left", KEY_A); _add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D); _add_key("move_right", KEY_RIGHT)
func _add_key(action, key):
	var ev := InputEventKey.new()
	ev.keycode = key
	InputMap.action_add_event(action, ev)
"""
	var script := GDScript.new()
	script.source_code = code
	script.reload()
	player.set_script(script)

	add_child(player)
	player.z_index = 10


func _find_spawn_on_terrain(terrain_data: Array) -> Vector2:
	var cx := world_width / 2
	var cy := world_height / 2

	# Find a non-water tile near center
	for r in range(max(world_width, world_height) / 2):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var x := cx + dx
				var y := cy + dy
				if x >= 0 and x < world_width and y >= 0 and y < world_height:
					var terrain_idx: int = terrain_data[y][x]
					var terrain_name: String = _manifest_terrains[terrain_idx] if terrain_idx < _manifest_terrains.size() else ""
					if terrain_name != "water":
						return Vector2(x * tile_size + tile_size / 2, y * tile_size + tile_size / 2)

	return Vector2(cx * tile_size, cy * tile_size)


func _clear() -> void:
	if terrain_layer:
		terrain_layer.queue_free()
	if transition_layer:
		transition_layer.queue_free()
	if structure_layer:
		structure_layer.queue_free()
	if object_sprites:
		object_sprites.queue_free()
	if player:
		player.queue_free()
	_terrain_textures.clear()
	_transition_textures.clear()
	_object_textures.clear()
	_manifest_terrains.clear()


func _build_tilemap(data: Dictionary, gen) -> void:
	# Load any available generated assets
	_load_assets()

	var tileset := _create_tileset(gen)

	terrain_layer = TileMapLayer.new()
	terrain_layer.name = "Terrain"
	terrain_layer.tile_set = tileset
	add_child(terrain_layer)

	structure_layer = TileMapLayer.new()
	structure_layer.name = "Structures"
	structure_layer.tile_set = tileset
	structure_layer.z_index = 1
	add_child(structure_layer)

	# Object sprites container for multi-tile structures
	object_sprites = Node2D.new()
	object_sprites.name = "ObjectSprites"
	object_sprites.z_index = 2
	add_child(object_sprites)

	var terrain: Array = data["terrain"]
	var structures: Array = data["structures"]
	var structure_objects: Array = data.get("structure_objects", [])

	# Place terrain tiles
	for y in range(world_height):
		for x in range(world_width):
			terrain_layer.set_cell(Vector2i(x, y), 0, Vector2i(terrain[y][x], 0))

	# Place structure tiles (for 1x1 structures like paths)
	for y in range(world_height):
		for x in range(world_width):
			var s: int = structures[y][x]
			if s > 0 and s == gen.StructureType.PATH:
				structure_layer.set_cell(Vector2i(x, y), 1, Vector2i(s, 0))

	# Place multi-tile structures as sprites
	_place_structure_sprites(structure_objects, gen)


func _create_tileset(gen) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)

	# Terrain tiles
	var t_src := TileSetAtlasSource.new()
	t_src.texture = _make_terrain_texture(gen)
	t_src.texture_region_size = Vector2i(tile_size, tile_size)
	ts.add_source(t_src, 0)
	for i in range(9):
		t_src.create_tile(Vector2i(i, 0))

	# Structure tiles
	var s_src := TileSetAtlasSource.new()
	s_src.texture = _make_structure_texture(gen)
	s_src.texture_region_size = Vector2i(tile_size, tile_size)
	ts.add_source(s_src, 1)
	for i in range(7):
		s_src.create_tile(Vector2i(i, 0))

	return ts


func _make_terrain_texture(gen) -> ImageTexture:
	# Check if we have a generated terrain tileset
	if _terrain_textures.has("tileset"):
		var loaded_tex: Texture2D = _terrain_textures["tileset"]
		# If it's already an ImageTexture, return it
		if loaded_tex is ImageTexture:
			return loaded_tex
		# Otherwise convert
		var img: Image = loaded_tex.get_image()
		return ImageTexture.create_from_image(img)

	# Fallback: create colored placeholder terrain
	var img := Image.create(tile_size * 9, tile_size, false, Image.FORMAT_RGBA8)
	for i in range(9):
		var color: Color = gen.get_terrain_color(i)
		for py in range(tile_size):
			for px in range(tile_size):
				var c := color
				c.r = clampf(c.r + randf_range(-0.03, 0.03), 0, 1)
				c.g = clampf(c.g + randf_range(-0.03, 0.03), 0, 1)
				c.b = clampf(c.b + randf_range(-0.03, 0.03), 0, 1)
				img.set_pixel(i * tile_size + px, py, c)
	return ImageTexture.create_from_image(img)


func _make_structure_texture(gen) -> ImageTexture:
	var img := Image.create(tile_size * 7, tile_size, false, Image.FORMAT_RGBA8)
	for i in range(7):
		var color: Color = gen.get_structure_color(i)
		img.fill_rect(Rect2i(i * tile_size, 0, tile_size, tile_size), color)
	return ImageTexture.create_from_image(img)


func _load_assets() -> void:
	print("[World] Loading assets from manifest...")

	# Load terrain textures from manifest - each terrain has its own PNG
	for terrain_name in _manifest_terrains:
		var terrain_path := ASSET_BASE + "terrain/" + terrain_name + ".png"
		if ResourceLoader.exists(terrain_path):
			_terrain_textures[terrain_name] = load(terrain_path)
			print("[World] Loaded terrain: ", terrain_path)
		else:
			print("[World] Terrain not found: ", terrain_path)

	# Load object textures from manifest structure
	# Objects are stored in objects/<name>/<name>_01.png, _02.png, etc.
	var manifest := _load_manifest_data()
	var objects_dict: Dictionary = manifest.get("objects", {})

	for obj_name in objects_dict.keys():
		var obj_data: Dictionary = objects_dict[obj_name]
		var folder: String = obj_data.get("folder", "objects/" + obj_name)
		var generated: int = obj_data.get("generated", 0)

		# Load ALL generated variants
		if generated > 0:
			var variants: Array[Texture2D] = []
			for i in range(1, generated + 1):
				var idx_str: String = str(i).pad_zeros(2)
				var obj_path: String = ASSET_BASE + folder + "/" + obj_name + "_" + idx_str + ".png"
				if ResourceLoader.exists(obj_path):
					variants.append(load(obj_path))
					print("[World] Loaded object variant: ", obj_path)

			if variants.size() > 0:
				_object_textures[obj_name] = variants
				print("[World] Loaded ", variants.size(), " variants for: ", obj_name)

	# Also try common object names that might not be in manifest
	var fallback_objects := ["tree", "rock", "bush", "palm_tree", "flower", "house", "tower"]
	for obj_name in fallback_objects:
		if _object_textures.has(obj_name):
			continue
		# Try to find any variants
		var variants: Array[Texture2D] = []
		for i in range(1, 10):  # Check up to 10 variants
			var idx_str: String = str(i).pad_zeros(2)
			var obj_path: String = ASSET_BASE + "objects/" + obj_name + "/" + obj_name + "_" + idx_str + ".png"
			if ResourceLoader.exists(obj_path):
				variants.append(load(obj_path))
			else:
				break  # Stop when we don't find one
		if variants.size() > 0:
			_object_textures[obj_name] = variants
			print("[World] Loaded ", variants.size(), " fallback variants for: ", obj_name)


func _load_manifest_data() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data


func _place_structure_sprites(structure_objects: Array, gen) -> void:
	for obj in structure_objects:
		var obj_type: int = obj["type"]
		var x: int = obj["x"]
		var y: int = obj["y"]
		var w: int = obj["width"]
		var h: int = obj["height"]

		var sprite := Sprite2D.new()
		sprite.name = "Structure_%d_%d" % [x, y]

		# Get texture - use generated asset or fallback to colored placeholder
		var tex: Texture2D = _get_structure_texture(obj_type, w, h, gen)
		sprite.texture = tex

		# Position at bottom-center of structure footprint
		# y is the bottom tile, structure grows upward
		sprite.position = Vector2(
			x * tile_size + (w * tile_size) / 2.0,
			y * tile_size + tile_size / 2.0
		)

		# Anchor at bottom center
		sprite.offset = Vector2(0, -tex.get_height() / 2.0 + tile_size / 2.0)

		# Y-sort based on bottom position for proper layering
		sprite.z_index = y

		object_sprites.add_child(sprite)


func _get_structure_texture(structure_type: int, w: int, h: int, gen) -> Texture2D:
	# Map structure type to asset name
	var type_names := {
		2: "house",   # StructureType.HOUSE
		3: "tower",   # StructureType.TOWER
		5: "tree",    # StructureType.TREE
		6: "rock",    # StructureType.ROCK
		7: "bush",
		8: "palm_tree"
	}

	var type_name: String = type_names.get(structure_type, "")

	# Check if we have a generated asset (now an array of variants)
	if type_name != "" and _object_textures.has(type_name):
		var variants: Array = _object_textures[type_name]
		if variants.size() > 0:
			# Pick a random variant
			var variant_idx := randi() % variants.size()
			return variants[variant_idx]

	# Fallback: create colored placeholder
	return _make_placeholder_structure(structure_type, w, h, gen)


func _make_placeholder_structure(structure_type: int, w: int, h: int, gen) -> ImageTexture:
	var pw: int = w * tile_size
	var ph: int = h * tile_size
	var img := Image.create(pw, ph, false, Image.FORMAT_RGBA8)

	var color: Color = gen.get_structure_color(structure_type)

	# Draw a simple shape based on type
	match structure_type:
		2:  # HOUSE - draw a house shape
			# Body
			img.fill_rect(Rect2i(2, ph / 3, pw - 4, ph * 2 / 3 - 2), color)
			# Roof
			var roof_color := color.darkened(0.2)
			for row in range(ph / 3):
				var indent: int = row * pw / (ph / 3) / 2
				for col in range(indent, pw - indent):
					img.set_pixel(col, row, roof_color)
			# Door
			img.fill_rect(Rect2i(pw / 3, ph * 2 / 3, pw / 3, ph / 3 - 2), color.darkened(0.4))

		3:  # TOWER - draw a tower shape
			# Body
			img.fill_rect(Rect2i(4, ph / 4, pw - 8, ph * 3 / 4 - 2), color)
			# Top
			img.fill_rect(Rect2i(2, 2, pw - 4, ph / 4), color.lightened(0.1))
			# Window
			img.fill_rect(Rect2i(pw / 3, ph / 2, pw / 3, pw / 3), color.darkened(0.5))

		5:  # TREE - draw a tree shape
			# Trunk
			var trunk_color := Color(0.4, 0.25, 0.15)
			img.fill_rect(Rect2i(pw / 3, ph * 2 / 3, pw / 3, ph / 3), trunk_color)
			# Foliage (circle-ish)
			var foliage_color := color
			var cx: int = pw / 2
			var cy: int = ph / 3
			var radius: int = mini(pw, ph * 2 / 3) / 2 - 2
			for py in range(ph * 2 / 3):
				for px in range(pw):
					var dx: float = px - cx
					var dy: float = py - cy
					if dx * dx + dy * dy < radius * radius:
						img.set_pixel(px, py, foliage_color)

		6:  # ROCK - draw a rock shape
			var cx: int = pw / 2
			var cy: int = ph / 2
			for py in range(ph):
				for px in range(pw):
					var dx: float = (px - cx) * 1.2
					var dy: float = py - cy
					if dx * dx + dy * dy < (pw / 2 - 2) * (pw / 2 - 2):
						var noise_val: float = randf_range(-0.05, 0.05)
						var c := color
						c.r = clampf(c.r + noise_val, 0, 1)
						c.g = clampf(c.g + noise_val, 0, 1)
						c.b = clampf(c.b + noise_val, 0, 1)
						img.set_pixel(px, py, c)

		_:  # Default colored rectangle
			img.fill_rect(Rect2i(0, 0, pw, ph), color)

	return ImageTexture.create_from_image(img)


func _spawn_player(data: Dictionary) -> void:
	player = CharacterBody2D.new()
	player.name = "Player"

	# Sprite - use generated asset if available
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"

	if _object_textures.has("player"):
		sprite.texture = _object_textures["player"]
	else:
		# Fallback: simple colored player
		var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
		# Body
		img.fill_rect(Rect2i(4, 8, 8, 14), Color(0.2, 0.6, 1.0))
		# Head
		for py in range(8):
			for px in range(3, 13):
				var dx: float = px - 8
				var dy: float = py - 4
				if dx * dx + dy * dy < 16:
					img.set_pixel(px, py, Color(0.9, 0.75, 0.6))
		# Eyes
		img.set_pixel(6, 4, Color.WHITE)
		img.set_pixel(9, 4, Color.WHITE)
		img.set_pixel(6, 5, Color.BLACK)
		img.set_pixel(9, 5, Color.BLACK)
		sprite.texture = ImageTexture.create_from_image(img)

	player.add_child(sprite)

	# Collision
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	player.add_child(col)

	# Position on grass
	player.position = _find_spawn(data)

	# Movement script
	var code := """
extends CharacterBody2D
var speed := 150.0
func _ready(): _setup_input()
func _physics_process(_d):
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"): dir.y -= 1
	if Input.is_action_pressed("move_down"): dir.y += 1
	if Input.is_action_pressed("move_left"): dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	velocity = dir.normalized() * speed
	move_and_slide()
	if dir.x != 0: $Sprite2D.flip_h = dir.x < 0
func _setup_input():
	for act in ["move_up", "move_down", "move_left", "move_right"]:
		if not InputMap.has_action(act): InputMap.add_action(act)
	_add_key("move_up", KEY_W); _add_key("move_up", KEY_UP)
	_add_key("move_down", KEY_S); _add_key("move_down", KEY_DOWN)
	_add_key("move_left", KEY_A); _add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D); _add_key("move_right", KEY_RIGHT)
func _add_key(action, key):
	var ev := InputEventKey.new()
	ev.keycode = key
	InputMap.action_add_event(action, ev)
"""
	var script := GDScript.new()
	script.source_code = code
	script.reload()
	player.set_script(script)

	add_child(player)
	player.z_index = 10


func _find_spawn(data: Dictionary) -> Vector2:
	var terrain: Array = data["terrain"]
	var cx := world_width / 2
	var cy := world_height / 2

	for r in range(max(world_width, world_height) / 2):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var x := cx + dx
				var y := cy + dy
				if x >= 0 and x < world_width and y >= 0 and y < world_height:
					if terrain[y][x] == 3:  # GRASS
						return Vector2(x * tile_size + tile_size / 2, y * tile_size + tile_size / 2)

	return Vector2(cx * tile_size, cy * tile_size)


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position_smoothing_enabled = true
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = world_width * tile_size
	camera.limit_bottom = world_height * tile_size
	player.add_child(camera)
	camera.make_current()


func _update_ui(seed_val: int) -> void:
	var label := get_node_or_null("UI/SeedLabel")
	if label:
		label.text = "Seed: %d" % seed_val

	var terrains_label := get_node_or_null("UI/TerrainsLabel")
	if terrains_label:
		terrains_label.text = "Terrains: " + ", ".join(_manifest_terrains)
