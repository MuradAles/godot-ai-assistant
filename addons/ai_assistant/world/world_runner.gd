extends Node2D

## Runtime world display and player controller
## Uses modular components for terrain, assets, transitions, and tilemap building

@export var world_width: int = 128
@export var world_height: int = 128
@export var world_seed: int = 0
@export var tile_size: int = 16
@export var camera_zoom: float = 3.0
@export var theme: String = "plains"

# Scene nodes
var terrain_layer: TileMapLayer
var transition_layer: TileMapLayer
var structure_layer: TileMapLayer
var object_sprites: Node2D
var player: CharacterBody2D
var camera: Camera2D

var is_generating := false

# Modular components
var _assets: WorldAssets
var _terrain: WorldTerrain
var _transitions: WorldTransitions
var _tilemap: WorldTilemap


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_init_modules()
	generate_world()


func _init_modules() -> void:
	_assets = WorldAssets.new()
	_terrain = WorldTerrain.new()
	_transitions = WorldTransitions.new()
	_tilemap = WorldTilemap.new()
	_tilemap.setup(_assets, _transitions, tile_size)


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

	# Load assets from manifest
	_assets.load_manifest()
	_assets.load_assets()

	# Setup terrain generator
	_terrain.setup_noise(gen_seed)

	# Generate terrain data
	var terrain_data := _terrain.generate_terrain(world_width, world_height, _assets.manifest_terrains)

	# Generate structures using manifest spawn rates
	var manifest_data := _assets.load_manifest_data()
	var manifest_terrain: Dictionary = manifest_data.get("terrain", {})
	var manifest_objects: Dictionary = manifest_data.get("objects", {})
	_terrain.set_object_sizes(manifest_objects)
	var structures_data := _terrain.generate_structures(terrain_data, _assets.manifest_terrains, manifest_terrain)

	# Build the visual tilemap
	_build_tilemap(terrain_data, structures_data)

	# Spawn player
	_spawn_player(terrain_data)

	# Setup camera
	_setup_camera()

	# Update UI
	_update_ui(gen_seed)

	is_generating = false


func _build_tilemap(terrain_data: Array, structures_data: Dictionary) -> void:
	# Create terrain layer
	terrain_layer = TileMapLayer.new()
	terrain_layer.name = "Terrain"
	terrain_layer.tile_set = _tilemap.create_terrain_tileset()
	add_child(terrain_layer)

	# Create transition layer
	transition_layer = TileMapLayer.new()
	transition_layer.name = "Transitions"
	transition_layer.tile_set = _tilemap.create_transition_tileset()
	transition_layer.z_index = 1
	add_child(transition_layer)

	# Create structure layer
	structure_layer = TileMapLayer.new()
	structure_layer.name = "Structures"
	structure_layer.tile_set = terrain_layer.tile_set
	structure_layer.z_index = 2
	add_child(structure_layer)

	# Create object sprites container
	object_sprites = Node2D.new()
	object_sprites.name = "ObjectSprites"
	object_sprites.z_index = 3
	add_child(object_sprites)

	# Place terrain tiles
	_tilemap.place_terrain_tiles(terrain_layer, terrain_data)

	# Find and place transition tiles
	var manifest := _assets.load_manifest_data()
	var transitions: Dictionary = manifest.get("transitions", {})
	var available_transitions: Dictionary = {}
	for trans_key in transitions.keys():
		if transitions[trans_key].get("generated", false):
			available_transitions[trans_key] = true

	var transition_cells := _transitions.get_transition_cells(terrain_data, _assets.manifest_terrains, available_transitions)
	print("[World] Found %d cells needing Wang tile transitions" % transition_cells.size())

	# Log wang index distribution
	var wang_counts: Dictionary = {}
	for cell_pos in transition_cells.keys():
		var wang_idx: int = transition_cells[cell_pos]["wang_index"]
		wang_counts[wang_idx] = wang_counts.get(wang_idx, 0) + 1
	print("[World] Wang index distribution: ", wang_counts)

	_tilemap.place_transition_tiles(transition_layer, terrain_data, transition_cells)

	# Place structure sprites
	var structure_objects: Array = structures_data.get("objects", [])
	_tilemap.place_structure_sprites(object_sprites, structure_objects)


func _spawn_player(terrain_data: Array) -> void:
	player = CharacterBody2D.new()
	player.name = "Player"

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"

	var player_tex := _assets.get_object_texture("player")
	if player_tex:
		sprite.texture = player_tex
	else:
		sprite.texture = _create_player_sprite()

	player.add_child(sprite)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	col.shape = shape
	player.add_child(col)

	player.position = _terrain.find_spawn_position(terrain_data, _assets.manifest_terrains, tile_size)

	# Add movement script
	var script := GDScript.new()
	script.source_code = _get_player_script()
	script.reload()
	player.set_script(script)

	add_child(player)
	player.z_index = 10


func _create_player_sprite() -> ImageTexture:
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
	return ImageTexture.create_from_image(img)


func _get_player_script() -> String:
	return """
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


func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(camera_zoom, camera_zoom)
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
		terrains_label.text = "Terrains: " + ", ".join(_assets.manifest_terrains)


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

	if _assets:
		_assets.clear()
