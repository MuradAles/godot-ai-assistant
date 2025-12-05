# Implementation Tasks
# Godot AI Game Generator Plugin

**Target:** Godot 4.5
**Approach:** Conversational game builder with layered quality (placeholders → AI art)

---

## Quick Progress

```
Phase 1: Foundation       [████████████] 100%  DONE
Phase 2: Memory Bank      [██████████  ]  85%  MOSTLY DONE
Phase 3: Conversation     [██████████  ]  90%  MOSTLY DONE
Phase 4: Map Generation   [██████      ]  50%  PARTIAL
Phase 5: Objects/Chars    [██          ]  20%  PARTIAL
Phase 6: Claude Code Gen  [██████      ]  50%  PARTIAL
Phase 7: Asset Generation [████        ]  30%  PARTIAL
Phase 8: Polish/Testing   [            ]   0%  TODO
```

---

## Phase 1: Foundation [DONE]

- [x] Plugin structure (`plugin.gd`, `plugin.cfg`)
- [x] Dock UI with Chat + Assets tabs
- [x] Settings dialog with API key storage
- [x] Claude streaming client (`ai_streaming.gd`)
- [x] Replicate client (`replicate_client.gd`)
- [x] Asset manifest system (`asset_manager.gd`)
- [x] World generator with FastNoiseLite (`world_generator.gd`)
- [x] World runner with player movement (`world_runner.gd`)

---

## Phase 2: Memory Bank (Game State) [DONE]

### Task 2.1: Create GameState Manager
- [x] Create `core/game_state.gd`
- [x] State persists to `res://game_project.json`
- [x] Load state on plugin init
- [x] Auto-save on every change
- [x] Generate context summary for Claude prompts

### Task 2.2: Integrate GameState with Dock
- [x] Dock loads state on `_ready()`
- [x] World creation updates state
- [ ] Object/character additions update state
- [ ] Assets tab reads from state
- [x] State survives plugin reload

### Task 2.3: Conversation History
- [x] User messages saved with timestamp
- [x] Assistant responses saved
- [x] History displayed on reload
- [x] Clear history option

---

## Phase 3: Conversation Flow [PARTIAL]

### Task 3.1: Intent Detection
- [x] Detect CREATE_WORLD intent ("create", "generate", "make" + "world", "map")
- [x] Detect MODIFY_WORLD intent ("regenerate", "bigger", "smaller", "more", "less")
- [x] Detect ADD_OBJECT intent ("add" + "tree", "rock", "house", "path")
- [x] Detect ADD_CHARACTER intent ("player", "npc", "enemy", "character")
- [x] Detect ADD_MECHANIC intent ("can", "should", "ability", "able to")
- [x] Detect GENERATE_ART intent ("generate art", "create sprite")
- [x] Detect RUN_GAME intent ("run", "play", "test")
- [x] Handle UNKNOWN intent gracefully
- [ ] Handle compound requests ("create world with trees")

### Task 3.2: Response Generator
- [x] Handler for CREATE_WORLD
- [x] Handler for MODIFY_WORLD
- [x] Handler for ADD_OBJECT
- [x] Handler for ADD_CHARACTER
- [x] Handler for ADD_MECHANIC (calls Claude)
- [x] Handler for GENERATE_ART
- [x] Handler for RUN_GAME
- [x] Clear feedback messages to user
- [x] State updated after each action

### Task 3.3: Guided Prompts
- [x] Help message when intent unclear
- [x] Example commands for each action type
- [x] Welcome message for new users

---

## Phase 4: Map Generation [PARTIAL]

### Task 4.1: Basic Map Generation (DONE)
- [x] FastNoiseLite terrain distribution
- [x] Island-style generation (water at edges)
- [x] Multiple terrain types (water, sand, grass, forest, snow)
- [x] Colored placeholder tiles
- [x] Player spawning on valid terrain

### Task 4.2: Clean Up World Runner
- [ ] Refactor `world_runner.gd` (currently 800+ lines)
- [ ] Extract terrain generation to separate methods
- [ ] Remove duplicate placeholder code
- [ ] Add proper typing throughout
- [ ] File under 400 lines

### Task 4.3: Map Modification Support
- [ ] "Regenerate" with new seed
- [ ] "Make it bigger" increases size
- [ ] "Make it smaller" decreases size
- [ ] "More water" adjusts thresholds
- [ ] "More forest" adjusts thresholds
- [ ] Preserve objects/characters on regenerate

---

## Phase 5: Objects & Characters

### Task 5.1: Object Placement System
- [ ] Place trees on grass/forest terrain
- [ ] Place rocks near water/hills
- [ ] Place houses on grass
- [ ] Place paths (connect locations)
- [ ] Collision detection (no overlap)
- [ ] "Add X trees" respects count
- [ ] "Add trees to forest" respects location
- [ ] Track objects in game state

### Task 5.2: Character System
- [x] Player with WASD movement (basic exists)
- [ ] Player spawn location configurable
- [ ] Create NPC at position
- [ ] NPC "stationary" behavior
- [ ] NPC "wander" behavior
- [ ] NPC "patrol" behavior
- [ ] Characters tracked in state
- [ ] Placeholder sprites (colored rectangles)

### Task 5.3: Character Behaviors via Claude
- [ ] Build behavior prompt with context
- [ ] Send to Claude for code generation
- [ ] Validate generated script
- [ ] Retry on failure (max 3)
- [ ] Attach script to character
- [ ] Notify user of result

---

## Phase 6: Claude Code Generation

### Task 6.1: Script Validator [DONE]
**Priority:** Critical

Validate GDScript before using:

```gdscript
class_name ScriptValidator
extends RefCounted

func validate(code: String) -> Dictionary:
    var script = GDScript.new()
    script.source_code = code
    var error = script.reload()

    return {
        "valid": error == OK,
        "error": error_string(error) if error != OK else "",
        "script": script if error == OK else null
    }
```

**Acceptance Criteria:**
- [x] Detects syntax errors
- [x] Returns meaningful error messages
- [x] Doesn't execute code during validation
- [x] Works in editor context

---

### Task 6.2: Mechanic Generator [PARTIAL]
**Priority:** Critical

Generate game mechanics via Claude:

```gdscript
func generate_mechanic(description: String) -> void:
    # description: "Player can cut trees and get wood"

    var context = game_state.get_context_for_claude()
    var prompt = _build_mechanic_prompt(description, context)

    var code = await _call_claude(prompt)
    var result = validator.validate(code)

    if not result.valid:
        # Retry with error context
        code = await _retry_with_error(prompt, result.error)
        result = validator.validate(code)

    if result.valid:
        var path = _save_script(code, description)
        _inject_mechanic(path)
        game_state.add_mechanic(description, path)
        _notify_success(description)
    else:
        _notify_failure(description, result.error)
```

**Acceptance Criteria:**
- [x] Claude receives game context
- [x] Generated code is validated
- [ ] Up to 3 retry attempts
- [x] Successful mechanics saved and injected
- [x] User notified of result

---

### Task 6.3: Code Injection
**Priority:** High

Attach generated scripts to nodes:

```gdscript
func inject_mechanic(script_path: String) -> void:
    # Analyze script to determine where it should attach
    # - Player scripts → Player node
    # - Interaction scripts → Interactable objects
    # - Global scripts → Autoload

    var script = load(script_path)
    var target = _determine_target(script)
    target.set_script(script)
```

**Acceptance Criteria:**
- [ ] Scripts attached to correct nodes
- [ ] Existing scripts not overwritten (extend instead)
- [ ] Signals connected if needed
- [ ] Hot reload works

---

### Task 6.4: System Prompt Refinement
**Priority:** High

Update `prompts/system_prompt.md` for code generation:

```markdown
You are a Godot 4.5 GDScript generator.

RULES:
1. Use TileMapLayer (NOT TileMap - deprecated)
2. Use @export for configurable properties
3. Use signal.emit() syntax
4. Return ONLY valid GDScript, no explanations
5. Include necessary extends statement
6. Handle edge cases (null checks, bounds)

CURRENT GAME STATE:
{context}

Generate code for: {request}
```

**Acceptance Criteria:**
- [ ] Godot 4.5 specifics covered
- [ ] Common mistakes prevented
- [ ] Context placeholder for game state
- [ ] Clear output format

---

## Phase 7: Asset Generation [POLISH]

### Task 7.1: Art Generation Flow
**Priority:** High

Streamline the art generation UX:

```gdscript
func generate_art_for(asset_type: String, asset_name: String) -> void:
    # asset_type: "terrain", "object", "character"
    # asset_name: "grass", "tree", "player"

    var prompt = _build_art_prompt(asset_type, asset_name)
    _show_generating_status(asset_name)

    var image = await replicate_client.generate(prompt)
    _save_and_apply_texture(asset_type, asset_name, image)

    game_state.mark_asset_generated(asset_type, asset_name)
    _refresh_world_visuals()
```

**Acceptance Criteria:**
- [ ] One-click generation per asset
- [ ] Progress feedback
- [ ] Auto-refresh world after generation
- [ ] State tracks which assets have art

---

### Task 7.2: Texture Replacement
**Priority:** High

Replace placeholder colors with generated textures:

```gdscript
func apply_texture(asset_type: String, name: String, texture: Texture2D) -> void:
    match asset_type:
        "terrain":
            _update_terrain_tileset(name, texture)
        "object":
            _update_object_sprites(name, texture)
        "character":
            _update_character_sprite(name, texture)
```

**Acceptance Criteria:**
- [ ] Terrain textures update tilemap
- [ ] Object textures update sprites
- [ ] Character textures update sprites
- [ ] No game logic changes needed

---

## Phase 8: Polish & Testing

### Task 8.1: Error Handling
**Priority:** High

Comprehensive error handling throughout:

- API failures (Claude, Replicate)
- Invalid user input
- Script validation failures
- File system errors

**Acceptance Criteria:**
- [ ] No unhandled exceptions
- [ ] User-friendly error messages
- [ ] Retry suggestions where applicable
- [ ] Errors logged for debugging

---

### Task 8.2: UX Polish
**Priority:** Medium

Improve user experience:

- Loading indicators during API calls
- Success confirmations
- Keyboard shortcuts (Enter to send)
- Auto-scroll chat

**Acceptance Criteria:**
- [ ] Clear visual feedback for all actions
- [ ] No UI freezing during operations
- [ ] Intuitive controls

---

### Task 8.3: Testing Scenarios
**Priority:** High

Manual test cases:

1. [ ] Create world from scratch
2. [ ] Add objects to world
3. [ ] Create player character
4. [ ] Add simple mechanic ("player moves faster")
5. [ ] Add complex mechanic ("player can cut trees")
6. [ ] Generate art for terrain
7. [ ] Generate art for character
8. [ ] Regenerate map (preserve objects)
9. [ ] Close and reopen (state persists)
10. [ ] API failure recovery

---

## Implementation Priority

### Immediate (This Session):
1. Task 2.1: GameState Manager
2. Task 3.1: Intent Detection
3. Task 6.1: Script Validator

### Next Session:
4. Task 3.2: Response Generator
5. Task 5.1: Object Placement
6. Task 6.2: Mechanic Generator

### Following:
7. Phase 4 polish
8. Phase 7 polish
9. Phase 8 testing

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Claude generates invalid code | Retry loop with error feedback (max 3) |
| Replicate API slow/fails | Show progress, allow cancel, cache results |
| State corruption | Validate JSON on load, backup previous |
| Complex mechanics fail | Start simple, build complexity gradually |
