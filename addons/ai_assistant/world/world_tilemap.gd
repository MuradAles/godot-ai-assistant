class_name WorldTilemap
extends RefCounted

## Handles TileMap and TileSet creation for world rendering

const ASSET_BASE := "res://assets/"

var _assets: WorldAssets
var _transitions: WorldTransitions
var _tile_size: int


func setup(assets: WorldAssets, transitions: WorldTransitions, tile_size: int) -> void:
	_assets = assets
	_transitions = transitions
	_tile_size = tile_size


## Create main terrain tileset from manifest
## Now includes multiple variation tiles per terrain
func create_terrain_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(_tile_size, _tile_size)

	var t_src := TileSetAtlasSource.new()
	t_src.texture = _make_terrain_atlas()
	t_src.texture_region_size = Vector2i(_tile_size, _tile_size)
	ts.add_source(t_src, 0)

	# Create tiles for each terrain type AND each variation
	var num_terrains := _assets.manifest_terrains.size()
	var total_cols := num_terrains * VARIATIONS_PER_TERRAIN
	for col in range(total_cols):
		t_src.create_tile(Vector2i(col, 0))

	return ts


## Number of variation slots per terrain in the atlas
const VARIATIONS_PER_TERRAIN := 4

## Create terrain atlas texture from loaded assets
## Atlas layout: [terrain0_v0, terrain0_v1, terrain0_v2, terrain0_v3, terrain1_v0, ...]
func _make_terrain_atlas() -> ImageTexture:
	var num_terrains := _assets.manifest_terrains.size()
	if num_terrains == 0:
		num_terrains = 1

	# Create atlas with space for variations (4 columns per terrain)
	var total_cols := num_terrains * VARIATIONS_PER_TERRAIN
	var img := Image.create(_tile_size * total_cols, _tile_size, false, Image.FORMAT_RGBA8)

	for i in range(_assets.manifest_terrains.size()):
		var terrain_name: String = _assets.manifest_terrains[i]
		var base_col := i * VARIATIONS_PER_TERRAIN

		# Get base texture and all variations
		var all_textures: Array[Texture2D] = _get_all_terrain_textures(terrain_name)

		# Fill all variation slots
		for v in range(VARIATIONS_PER_TERRAIN):
			var col := base_col + v
			var tex: Texture2D = null

			if v < all_textures.size():
				tex = all_textures[v]
			elif all_textures.size() > 0:
				# Reuse textures if we have fewer than VARIATIONS_PER_TERRAIN
				tex = all_textures[v % all_textures.size()]

			if tex:
				var loaded_img: Image = tex.get_image()
				if loaded_img.get_width() != _tile_size or loaded_img.get_height() != _tile_size:
					loaded_img.resize(_tile_size, _tile_size, Image.INTERPOLATE_NEAREST)

				# Copy into atlas at this column
				for py in range(_tile_size):
					for px in range(_tile_size):
						var pixel_color := loaded_img.get_pixel(px, py)
						img.set_pixel(col * _tile_size + px, py, pixel_color)
			else:
				# Fallback: colored placeholder with slight variation
				var color := _assets.get_terrain_color(terrain_name)
				var variation_offset := v * 0.02  # Slight color shift per variation
				for py in range(_tile_size):
					for px in range(_tile_size):
						var c := color
						c.r = clampf(c.r + randf_range(-0.03, 0.03) + variation_offset, 0, 1)
						c.g = clampf(c.g + randf_range(-0.03, 0.03), 0, 1)
						c.b = clampf(c.b + randf_range(-0.03, 0.03) - variation_offset, 0, 1)
						img.set_pixel(col * _tile_size + px, py, c)

		print("[WorldTilemap] Atlas: %s has %d unique textures (filling %d slots)" % [terrain_name, all_textures.size(), VARIATIONS_PER_TERRAIN])

	return ImageTexture.create_from_image(img)


## Get all available textures for a terrain (base + variations)
func _get_all_terrain_textures(terrain_name: String) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []

	# Get base texture
	if _assets.terrain_textures.has(terrain_name):
		textures.append(_assets.terrain_textures[terrain_name])

	# Get variations
	if _assets.terrain_variations.has(terrain_name):
		var variations: Array = _assets.terrain_variations[terrain_name]
		for tex in variations:
			if tex is Texture2D:
				textures.append(tex)

	return textures


## Create tileset for transition tiles (wang tiles)
func create_transition_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(_tile_size, _tile_size)

	var manifest := _assets.load_manifest_data()
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
					var tex_width: int = trans_tex.get_width()
					var tex_height: int = trans_tex.get_height()
					var cols: int = tex_width / _tile_size
					var rows: int = tex_height / _tile_size

					print("[WorldTilemap] Transition %s: %dx%d, grid: %dx%d tiles" % [trans_key, tex_width, tex_height, cols, rows])

					if cols <= 0 or rows <= 0:
						push_warning("[WorldTilemap] Invalid transition texture size: " + trans_key)
						continue

					# Store grid size
					_assets.transition_grid_sizes[trans_key] = Vector2i(cols, rows)

					# Parse wang tileset
					var tiles := _transitions.parse_wang_tileset(trans_tex, _tile_size, cols, rows)
					_assets.transition_textures[trans_key] = tiles

					# Create atlas source
					var t_src := TileSetAtlasSource.new()
					t_src.texture = trans_tex
					t_src.texture_region_size = Vector2i(_tile_size, _tile_size)
					ts.add_source(t_src, source_id)

					# Create tiles
					for row in range(rows):
						for col in range(cols):
							t_src.create_tile(Vector2i(col, row))

					print("[WorldTilemap] Loaded transition: ", trans_key, " as source ", source_id)
					source_id += 1

	return ts


## Place terrain tiles on layer with random variations
func place_terrain_tiles(layer: TileMapLayer, terrain_data: Array) -> void:
	var height: int = terrain_data.size()
	var width: int = terrain_data[0].size() if height > 0 else 0

	for y in range(height):
		for x in range(width):
			var terrain_idx: int = terrain_data[y][x]
			# Calculate base column for this terrain (each terrain has VARIATIONS_PER_TERRAIN columns)
			var base_col := terrain_idx * VARIATIONS_PER_TERRAIN
			# Pick a random variation
			var variation := randi() % VARIATIONS_PER_TERRAIN
			layer.set_cell(Vector2i(x, y), 0, Vector2i(base_col + variation, 0))


## Place transition tiles on layer
func place_transition_tiles(layer: TileMapLayer, terrain_data: Array, transition_cells: Dictionary) -> void:
	var manifest := _assets.load_manifest_data()
	var transitions: Dictionary = manifest.get("transitions", {})

	# Build map of transition keys to source IDs
	var transition_sources: Dictionary = {}
	var source_id := 0
	for trans_key in transitions.keys():
		var trans_data: Dictionary = transitions[trans_key]
		if trans_data.get("generated", false):
			transition_sources[trans_key] = source_id
			source_id += 1

	# Place each transition tile
	for cell_pos in transition_cells.keys():
		var cell_info: Dictionary = transition_cells[cell_pos]
		var trans_key: String = cell_info["trans_key"]
		var wang_index: int = cell_info["wang_index"]

		if not transition_sources.has(trans_key):
			continue

		var src_id: int = transition_sources[trans_key]
		var grid_size: Vector2i = _assets.transition_grid_sizes.get(trans_key, Vector2i(4, 5))
		var tile_coords := _transitions.get_wang_tile_coords(wang_index, grid_size.x, grid_size.y)

		layer.set_cell(cell_pos, src_id, tile_coords)


## Place structure sprites on container
func place_structure_sprites(container: Node2D, structure_objects: Array) -> void:
	for obj in structure_objects:
		var x: int = obj["x"]
		var y: int = obj["y"]
		var w: int = obj["width"]
		var h: int = obj["height"]

		# Support both new format (name) and old format (type)
		var obj_name: String = obj.get("name", "")
		if obj_name.is_empty():
			# Legacy support: convert type ID to name
			var obj_type: int = obj.get("type", 5)
			var type_names := {5: "tree", 6: "rock", 7: "bush", 8: "palm_tree"}
			obj_name = type_names.get(obj_type, "tree")

		var sprite := Sprite2D.new()
		sprite.name = "Structure_%d_%d_%s" % [x, y, obj_name]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		var tex: Texture2D = _get_structure_texture_by_name(obj_name, w, h)
		sprite.texture = tex

		sprite.position = Vector2(
			x * _tile_size + (w * _tile_size) / 2.0,
			y * _tile_size + _tile_size / 2.0
		)
		sprite.offset = Vector2(0, -tex.get_height() / 2.0 + _tile_size / 2.0)
		sprite.z_index = y

		container.add_child(sprite)


## Get texture for any object by name
func _get_structure_texture_by_name(obj_name: String, w: int, h: int) -> Texture2D:
	# Try to get from assets (works for any generated object)
	var tex := _assets.get_object_texture(obj_name)
	if tex:
		return tex

	# Fallback placeholder
	return _make_placeholder_structure_named(obj_name, w, h)


func _get_structure_texture(structure_type: int, w: int, h: int) -> Texture2D:
	var type_names := {5: "tree", 6: "rock", 7: "bush", 8: "palm_tree"}
	var type_name: String = type_names.get(structure_type, "")

	if type_name != "":
		var tex := _assets.get_object_texture(type_name)
		if tex:
			return tex

	# Fallback placeholder
	return _make_placeholder_structure(structure_type, w, h)


func _make_placeholder_structure(structure_type: int, w: int, h: int) -> ImageTexture:
	var pw: int = w * _tile_size
	var ph: int = h * _tile_size
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


## Create placeholder for any named object
func _make_placeholder_structure_named(obj_name: String, w: int, h: int) -> ImageTexture:
	var pw: int = w * _tile_size
	var ph: int = h * _tile_size
	var img := Image.create(pw, ph, false, Image.FORMAT_RGBA8)

	# Generate a unique color based on object name
	var hash_val := obj_name.hash()
	var hue := fmod(abs(hash_val) / 1000000.0, 1.0)
	var color := Color.from_hsv(hue, 0.6, 0.7)

	# Draw a simple circular/oval shape
	var cx: int = pw / 2
	var cy: int = ph / 2
	var rx: int = pw / 2 - 2
	var ry: int = ph / 2 - 2

	for py in range(ph):
		for px in range(pw):
			var dx: float = float(px - cx) / rx
			var dy: float = float(py - cy) / ry
			if dx * dx + dy * dy < 1.0:
				img.set_pixel(px, py, color)

	return ImageTexture.create_from_image(img)
