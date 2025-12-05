@tool
class_name IntentParser
extends RefCounted

## Intent Detection for Conversational Game Builder
## Parses user messages to determine what action to take

enum Intent {
	CREATE_WORLD,
	MODIFY_WORLD,
	ADD_OBJECT,
	ADD_CHARACTER,
	ADD_MECHANIC,
	GENERATE_ART,
	RUN_GAME,
	HELP,
	UNKNOWN
}

# Keywords for each intent
const CREATE_KEYWORDS := ["create", "generate", "make", "build", "new", "start"]
const WORLD_KEYWORDS := ["world", "map", "terrain", "level", "land", "scene", "game"]

const MODIFY_KEYWORDS := ["regenerate", "change", "modify", "update", "resize", "adjust", "more", "less", "bigger", "smaller"]

const OBJECT_KEYWORDS := ["tree", "rock", "stone", "bush", "plant", "flower", "house", "cabin", "hut", "building", "tower", "castle", "fort", "path", "road", "bridge", "fence", "wall", "chest", "barrel", "crate"]
const ADD_KEYWORDS := ["add", "place", "put", "spawn", "insert", "create"]

const CHARACTER_KEYWORDS := ["player", "character", "hero", "npc", "enemy", "monster", "villager", "shopkeeper", "guard", "boss"]

const MECHANIC_KEYWORDS := ["can", "should", "able to", "ability", "mechanic", "feature", "when", "if player", "allow", "enable", "let"]
const ACTION_VERBS := ["move", "jump", "attack", "collect", "pick up", "drop", "use", "interact", "talk", "buy", "sell", "craft", "build", "destroy", "cut", "mine", "fish", "swim", "fly", "run", "walk", "dash", "dodge", "block", "heal", "damage", "kill", "die", "respawn"]

const ART_KEYWORDS := ["generate art", "create sprite", "make sprite", "art for", "sprite for", "texture for", "image for", "pixel art"]

const RUN_KEYWORDS := ["run", "play", "test", "launch", "start game", "try it", "execute"]

const HELP_KEYWORDS := ["help", "how do i", "what can", "commands", "tutorial", "guide", "examples"]

# Terrain keywords for world creation
const TERRAIN_KEYWORDS := ["forest", "beach", "ocean", "desert", "snow", "water", "sand", "grass", "river", "lake", "island", "mountain", "jungle", "plains", "meadow", "swamp", "volcano", "cave"]


func parse(message: String) -> Dictionary:
	var lower := message.to_lower().strip_edges()

	# Result structure
	var result := {
		"intent": Intent.UNKNOWN,
		"confidence": 0.0,
		"entities": {},
		"raw": message
	}

	# Check intents in order of specificity
	if _is_help_request(lower):
		result.intent = Intent.HELP
		result.confidence = 0.9
		return result

	if _is_run_request(lower):
		result.intent = Intent.RUN_GAME
		result.confidence = 0.9
		return result

	if _is_art_request(lower):
		result.intent = Intent.GENERATE_ART
		result.confidence = 0.8
		result.entities = _extract_art_entities(lower)
		return result

	if _is_mechanic_request(lower):
		result.intent = Intent.ADD_MECHANIC
		result.confidence = 0.8
		result.entities = _extract_mechanic_entities(lower)
		return result

	if _is_character_request(lower):
		result.intent = Intent.ADD_CHARACTER
		result.confidence = 0.8
		result.entities = _extract_character_entities(lower)
		return result

	if _is_modify_world_request(lower):
		result.intent = Intent.MODIFY_WORLD
		result.confidence = 0.8
		result.entities = _extract_modify_entities(lower)
		return result

	if _is_add_object_request(lower):
		result.intent = Intent.ADD_OBJECT
		result.confidence = 0.8
		result.entities = _extract_object_entities(lower)
		return result

	if _is_world_request(lower):
		result.intent = Intent.CREATE_WORLD
		result.confidence = 0.9
		result.entities = _extract_world_entities(lower)
		return result

	# Low confidence fallback - check if might be a world request
	if _might_be_world_request(lower):
		result.intent = Intent.CREATE_WORLD
		result.confidence = 0.5
		result.entities = _extract_world_entities(lower)

	return result


# ==================== INTENT CHECKS ====================

func _is_help_request(text: String) -> bool:
	for k in HELP_KEYWORDS:
		if k in text:
			return true
	return false


func _is_run_request(text: String) -> bool:
	for k in RUN_KEYWORDS:
		if k in text:
			return true
	return false


func _is_art_request(text: String) -> bool:
	for k in ART_KEYWORDS:
		if k in text:
			return true
	return false


func _is_mechanic_request(text: String) -> bool:
	# Check for action verbs with mechanic keywords
	var has_mechanic_keyword := false
	var has_action_verb := false

	for k in MECHANIC_KEYWORDS:
		if k in text:
			has_mechanic_keyword = true
			break

	for v in ACTION_VERBS:
		if v in text:
			has_action_verb = true
			break

	# "player can jump" or "allow swimming" patterns
	if has_mechanic_keyword and has_action_verb:
		return true

	# "when player..." pattern
	if "when " in text and ("player" in text or "character" in text):
		return true

	return false


func _is_character_request(text: String) -> bool:
	var has_add := false
	var has_character := false

	for k in ADD_KEYWORDS + CREATE_KEYWORDS:
		if k in text:
			has_add = true
			break

	for k in CHARACTER_KEYWORDS:
		if k in text:
			has_character = true
			break

	return has_add and has_character


func _is_modify_world_request(text: String) -> bool:
	for k in MODIFY_KEYWORDS:
		if k in text:
			return true
	return false


func _is_add_object_request(text: String) -> bool:
	var has_add := false
	var has_object := false

	for k in ADD_KEYWORDS:
		if k in text:
			has_add = true
			break

	for k in OBJECT_KEYWORDS:
		if k in text:
			has_object = true
			break

	return has_add and has_object


func _is_world_request(text: String) -> bool:
	var has_create := false
	var has_world := false

	for k in CREATE_KEYWORDS:
		if k in text:
			has_create = true
			break

	for k in WORLD_KEYWORDS:
		if k in text:
			has_world = true
			break

	if has_create and has_world:
		return true

	# Also trigger if create + terrain
	var has_terrain := false
	for k in TERRAIN_KEYWORDS:
		if k in text:
			has_terrain = true
			break

	return has_create and has_terrain


func _might_be_world_request(text: String) -> bool:
	# Count terrain keywords - if 2+, probably a world request
	var terrain_count := 0
	for k in TERRAIN_KEYWORDS:
		if k in text:
			terrain_count += 1
	return terrain_count >= 2


# ==================== ENTITY EXTRACTION ====================

func _extract_world_entities(text: String) -> Dictionary:
	var entities := {
		"terrains": [],
		"theme": "",
		"size": "medium"
	}

	# Extract terrains
	for t in TERRAIN_KEYWORDS:
		if t in text:
			entities.terrains.append(t)

	# Determine theme
	if "beach" in text or "ocean" in text or "tropical" in text or "island" in text:
		entities.theme = "ocean"
	elif "forest" in text or "jungle" in text or "wood" in text:
		entities.theme = "forest"
	elif "desert" in text or "dune" in text:
		entities.theme = "desert"
	elif "snow" in text or "ice" in text or "frozen" in text or "winter" in text:
		entities.theme = "snow"
	else:
		entities.theme = "plains"

	# Determine size
	if "large" in text or "big" in text or "huge" in text:
		entities.size = "large"
	elif "small" in text or "tiny" in text:
		entities.size = "small"

	return entities


func _extract_modify_entities(text: String) -> Dictionary:
	var entities := {
		"action": "",
		"target": "",
		"amount": ""
	}

	if "bigger" in text or "larger" in text:
		entities.action = "increase_size"
	elif "smaller" in text:
		entities.action = "decrease_size"
	elif "more" in text:
		entities.action = "increase"
		# Find what to increase
		for t in TERRAIN_KEYWORDS:
			if t in text:
				entities.target = t
				break
	elif "less" in text or "fewer" in text:
		entities.action = "decrease"
		for t in TERRAIN_KEYWORDS:
			if t in text:
				entities.target = t
				break
	elif "regenerate" in text or "new seed" in text:
		entities.action = "regenerate"

	return entities


func _extract_object_entities(text: String) -> Dictionary:
	var entities := {
		"objects": [],
		"count": 1,
		"location": ""
	}

	# Extract object types
	for o in OBJECT_KEYWORDS:
		if o in text:
			entities.objects.append(o)

	# Extract count (look for numbers)
	var regex := RegEx.new()
	regex.compile("(\\d+)\\s*(tree|rock|house|bush|plant|tower|path)")
	var result := regex.search(text)
	if result:
		entities.count = int(result.get_string(1))

	# Extract location
	if "forest" in text:
		entities.location = "forest"
	elif "water" in text or "beach" in text or "shore" in text:
		entities.location = "water_edge"
	elif "center" in text or "middle" in text:
		entities.location = "center"
	elif "edge" in text or "border" in text:
		entities.location = "edge"

	return entities


func _extract_character_entities(text: String) -> Dictionary:
	var entities := {
		"type": "",
		"name": "",
		"behavior": "stationary",
		"location": ""
	}

	# Extract character type
	if "player" in text:
		entities.type = "player"
	elif "enemy" in text or "monster" in text:
		entities.type = "enemy"
		entities.behavior = "wander"
	elif "shopkeeper" in text or "merchant" in text:
		entities.type = "npc"
		entities.behavior = "stationary"
	elif "guard" in text:
		entities.type = "npc"
		entities.behavior = "patrol"
	elif "npc" in text or "villager" in text:
		entities.type = "npc"
	else:
		entities.type = "npc"

	# Extract behavior
	if "wander" in text or "walk around" in text:
		entities.behavior = "wander"
	elif "patrol" in text:
		entities.behavior = "patrol"
	elif "follow" in text:
		entities.behavior = "follow"
	elif "stationary" in text or "stand" in text or "stay" in text:
		entities.behavior = "stationary"

	# Extract location
	if "house" in text or "shop" in text:
		entities.location = "near_structure"
	elif "forest" in text:
		entities.location = "forest"
	elif "center" in text:
		entities.location = "center"

	return entities


func _extract_mechanic_entities(text: String) -> Dictionary:
	var entities := {
		"description": text,
		"actions": [],
		"target": ""
	}

	# Extract action verbs
	for v in ACTION_VERBS:
		if v in text:
			entities.actions.append(v)

	# Determine what the mechanic affects
	if "tree" in text:
		entities.target = "tree"
	elif "enemy" in text or "monster" in text:
		entities.target = "enemy"
	elif "npc" in text:
		entities.target = "npc"
	elif "item" in text:
		entities.target = "item"
	elif "water" in text:
		entities.target = "terrain"

	return entities


func _extract_art_entities(text: String) -> Dictionary:
	var entities := {
		"asset_type": "",
		"asset_name": ""
	}

	# Determine what to generate art for
	for t in TERRAIN_KEYWORDS:
		if t in text:
			entities.asset_type = "terrain"
			entities.asset_name = t
			return entities

	for o in OBJECT_KEYWORDS:
		if o in text:
			entities.asset_type = "object"
			entities.asset_name = o
			return entities

	for c in CHARACTER_KEYWORDS:
		if c in text:
			entities.asset_type = "character"
			entities.asset_name = c
			return entities

	return entities


# ==================== HELPERS ====================

static func intent_to_string(intent: Intent) -> String:
	match intent:
		Intent.CREATE_WORLD: return "CREATE_WORLD"
		Intent.MODIFY_WORLD: return "MODIFY_WORLD"
		Intent.ADD_OBJECT: return "ADD_OBJECT"
		Intent.ADD_CHARACTER: return "ADD_CHARACTER"
		Intent.ADD_MECHANIC: return "ADD_MECHANIC"
		Intent.GENERATE_ART: return "GENERATE_ART"
		Intent.RUN_GAME: return "RUN_GAME"
		Intent.HELP: return "HELP"
		_: return "UNKNOWN"


func get_help_text() -> String:
	return """## Available Commands

**Create World:**
- "Create a forest world"
- "Make an island with beaches"
- "Generate a snowy mountain map"

**Modify World:**
- "Make it bigger"
- "More forest please"
- "Regenerate with a new seed"

**Add Objects:**
- "Add 10 trees to the forest"
- "Place rocks near the water"
- "Add a house in the center"

**Add Characters:**
- "Create a player character"
- "Add an enemy that wanders around"
- "Place an NPC shopkeeper near the house"

**Add Mechanics:**
- "Player can cut trees"
- "Allow the player to swim"
- "When player touches enemy, take damage"

**Generate Art:**
- "Generate art for the grass terrain"
- "Create a sprite for the player"

**Run Game:**
- "Run the game"
- "Test it"
- "Play"
"""
