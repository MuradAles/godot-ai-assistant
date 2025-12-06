class_name WorldAssets
extends RefCounted

## Handles loading assets from manifest for world rendering

const ASSET_BASE := "res://assets/"
const MANIFEST_PATH := "res://assets/manifest.json"

# Loaded textures
var terrain_textures: Dictionary = {}  # terrain_name -> Texture2D
var terrain_variations: Dictionary = {}  # terrain_name -> Array[Texture2D]
var transition_textures: Dictionary = {}  # "from_to" -> Array[Texture2D]
var transition_grid_sizes: Dictionary = {}  # "from_to" -> Vector2i(cols, rows)
var object_textures: Dictionary = {}  # object_name -> Array[Texture2D]

# Manifest data
var manifest_terrains: Array[String] = []


func clear() -> void:
	terrain_textures.clear()
	terrain_variations.clear()
	transition_textures.clear()
	transition_grid_sizes.clear()
	object_textures.clear()
	manifest_terrains.clear()


## Load terrain order from manifest
func load_manifest() -> void:
	manifest_terrains.clear()

	if not FileAccess.file_exists(MANIFEST_PATH):
		print("No manifest found, using defaults")
		manifest_terrains = ["water", "sand", "grass"]
		return

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not file:
		manifest_terrains = ["water", "sand", "grass"]
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		manifest_terrains = ["water", "sand", "grass"]
		return

	var data: Dictionary = json.data

	# Use terrain_order if available (preserves elevation ordering)
	var terrain_order: Array = data.get("terrain_order", [])
	if terrain_order.size() > 0:
		for terrain_name in terrain_order:
			manifest_terrains.append(terrain_name)
	else:
		# Fallback to terrain dictionary keys (unordered)
		var terrain_dict: Dictionary = data.get("terrain", {})
		for terrain_name in terrain_dict.keys():
			manifest_terrains.append(terrain_name)

	if manifest_terrains.is_empty():
		manifest_terrains = ["water", "sand", "grass"]

	print("[WorldAssets] Loaded terrain order: ", manifest_terrains)


## Load raw manifest data
func load_manifest_data() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data


## Load all assets from manifest
func load_assets() -> void:
	print("[WorldAssets] Loading assets from manifest...")

	var manifest := load_manifest_data()
	var terrain_dict: Dictionary = manifest.get("terrain", {})

	# Load terrain textures - each terrain has its own PNG
	# Use CACHE_MODE_IGNORE to force reload newly generated assets
	for terrain_name in manifest_terrains:
		var terrain_path := ASSET_BASE + "terrain/" + terrain_name + ".png"
		if ResourceLoader.exists(terrain_path):
			terrain_textures[terrain_name] = ResourceLoader.load(terrain_path, "", ResourceLoader.CACHE_MODE_IGNORE)
			print("[WorldAssets] Loaded terrain: ", terrain_path)
		else:
			print("[WorldAssets] Terrain not found: ", terrain_path)

		# Load terrain variations if available
		if terrain_dict.has(terrain_name):
			var t_data: Dictionary = terrain_dict[terrain_name]
			var variations: Array = t_data.get("variations", [])
			if variations.size() > 0:
				var var_textures: Array[Texture2D] = []
				for var_idx in variations:
					# Convert float to int for path (JSON stores numbers as floats)
					var idx_int: int = int(var_idx)
					var var_path := ASSET_BASE + "terrain/" + terrain_name + "_v" + str(idx_int) + ".png"
					print("[WorldAssets] Looking for variation: ", var_path)
					if ResourceLoader.exists(var_path):
						var_textures.append(ResourceLoader.load(var_path, "", ResourceLoader.CACHE_MODE_IGNORE))
						print("[WorldAssets] Loaded terrain variation: ", var_path)
					else:
						print("[WorldAssets] Variation file NOT FOUND: ", var_path)
				if var_textures.size() > 0:
					terrain_variations[terrain_name] = var_textures
					print("[WorldAssets] Total variations loaded for %s: %d (base + %d)" % [terrain_name, var_textures.size() + 1, var_textures.size()])

	# Load object textures from manifest
	# Use CACHE_MODE_IGNORE to force reload newly generated assets
	var objects_dict: Dictionary = manifest.get("objects", {})
	for obj_name in objects_dict.keys():
		var obj_data: Dictionary = objects_dict[obj_name]
		var folder: String = obj_data.get("folder", "objects/" + obj_name)
		var generated: int = obj_data.get("generated", 0)

		if generated > 0:
			var variants: Array[Texture2D] = []
			for i in range(1, generated + 1):
				var idx_str: String = str(i).pad_zeros(2)
				var obj_path: String = ASSET_BASE + folder + "/" + obj_name + "_" + idx_str + ".png"
				if ResourceLoader.exists(obj_path):
					variants.append(ResourceLoader.load(obj_path, "", ResourceLoader.CACHE_MODE_IGNORE))
					print("[WorldAssets] Loaded object variant: ", obj_path)

			if variants.size() > 0:
				object_textures[obj_name] = variants
				print("[WorldAssets] Loaded ", variants.size(), " variants for: ", obj_name)

	# Fallback objects not in manifest
	var fallback_objects := ["tree", "rock", "bush", "palm_tree", "flower", "house", "tower"]
	for obj_name in fallback_objects:
		if object_textures.has(obj_name):
			continue
		var variants: Array[Texture2D] = []
		for i in range(1, 10):
			var idx_str: String = str(i).pad_zeros(2)
			var obj_path: String = ASSET_BASE + "objects/" + obj_name + "/" + obj_name + "_" + idx_str + ".png"
			if ResourceLoader.exists(obj_path):
				variants.append(ResourceLoader.load(obj_path, "", ResourceLoader.CACHE_MODE_IGNORE))
			else:
				break
		if variants.size() > 0:
			object_textures[obj_name] = variants
			print("[WorldAssets] Loaded ", variants.size(), " fallback variants for: ", obj_name)


## Get a random texture for a terrain (base or variation)
func get_terrain_texture(terrain_name: String) -> Texture2D:
	if not terrain_textures.has(terrain_name):
		return null

	var tex: Texture2D = terrain_textures[terrain_name]

	# Randomly pick from variations if available
	if terrain_variations.has(terrain_name):
		var variations: Array = terrain_variations[terrain_name]
		if variations.size() > 0:
			var all_textures: Array = [tex]
			all_textures.append_array(variations)
			tex = all_textures[randi() % all_textures.size()]
			print("[WorldAssets] Randomly picked from ", all_textures.size(), " textures for: ", terrain_name)

	return tex


## Get a random object texture variant
func get_object_texture(obj_name: String) -> Texture2D:
	if not object_textures.has(obj_name):
		return null
	var variants: Array = object_textures[obj_name]
	if variants.size() == 0:
		return null
	return variants[randi() % variants.size()]


## Get fallback color for terrain without texture
func get_terrain_color(terrain_name: String) -> Color:
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
