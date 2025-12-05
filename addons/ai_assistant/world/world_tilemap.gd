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
func create_terrain_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(_tile_size, _tile_size)

	var t_src := TileSetAtlasSource.new()
	t_src.texture = _make_terrain_atlas()
	t_src.texture_region_size = Vector2i(_tile_size, _tile_size)
	ts.add_source(t_src, 0)

	# Create tiles for each terrain type
	for i in range(_assets.manifest_terrains.size()):
		t_src.create_tile(Vector2i(i, 0))

	return ts


## Create terrain atlas texture from loaded assets
func _make_terrain_atlas() -> ImageTexture:
	var num_terrains := _assets.manifest_terrains.size()
	if num_terrains == 0:
		num_terrains = 1

	var img := Image.create(_tile_size * num_terrains, _tile_size, false, Image.FORMAT_RGBA8)

	for i in range(_assets.manifest_terrains.size()):
		var terrain_name: String = _assets.manifest_terrains[i]

		# Get texture (may be random variation)
		var tex: Texture2D = _assets.get_terrain_texture(terrain_name)

		if tex:
			var loaded_img: Image = tex.get_image()

			# Resize if needed
			if loaded_img.get_width() != _tile_size or loaded_img.get_height() != _tile_size:
				loaded_img.resize(_tile_size, _tile_size, Image.INTERPOLATE_NEAREST)

			# Copy into atlas
			for py in range(_tile_size):
				for px in range(_tile_size):
					var pixel_color := loaded_img.get_pixel(px, py)
					img.set_pixel(i * _tile_size + px, py, pixel_color)

			print("[WorldTilemap] Using generated texture for terrain: ", terrain_name)
		else:
			# Fallback: colored placeholder
			var color := _assets.get_terrain_color(terrain_name)
			for py in range(_tile_size):
				for px in range(_tile_size):
					var c := color
					c.r = clampf(c.r + randf_range(-0.03, 0.03), 0, 1)
					c.g = clampf(c.g + randf_range(-0.03, 0.03), 0, 1)
					c.b = clampf(c.b + randf_range(-0.03, 0.03), 0, 1)
					img.set_pixel(i * _tile_size + px, py, c)

			print("[WorldTilemap] Using placeholder for terrain: ", terrain_name)

	return ImageTexture.create_from_image(img)


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


## Place terrain tiles on layer
func place_terrain_tiles(layer: TileMapLayer, terrain_data: Array) -> void:
	var height: int = terrain_data.size()
	var width: int = terrain_data[0].size() if height > 0 else 0

	for y in range(height):
		for x in range(width):
			var terrain_idx: int = terrain_data[y][x]
			layer.set_cell(Vector2i(x, y), 0, Vector2i(terrain_idx, 0))


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
		var obj_type: int = obj["type"]
		var x: int = obj["x"]
		var y: int = obj["y"]
		var w: int = obj["width"]
		var h: int = obj["height"]

		var sprite := Sprite2D.new()
		sprite.name = "Structure_%d_%d" % [x, y]

		var tex: Texture2D = _get_structure_texture(obj_type, w, h)
		sprite.texture = tex

		sprite.position = Vector2(
			x * _tile_size + (w * _tile_size) / 2.0,
			y * _tile_size + _tile_size / 2.0
		)
		sprite.offset = Vector2(0, -tex.get_height() / 2.0 + _tile_size / 2.0)
		sprite.z_index = y

		container.add_child(sprite)


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
