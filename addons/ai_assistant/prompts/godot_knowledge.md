# Godot 4.5 Knowledge Base

## Node Types and Usage

### Physics Bodies (2D/3D)
- **CharacterBody2D/3D**: For player/enemy characters with custom physics
  - Use `move_and_slide()` for movement
  - Access `velocity` property directly
  - Use `is_on_floor()`, `is_on_wall()`, `is_on_ceiling()` for collision checks

- **RigidBody2D/3D**: For physics-driven objects (balls, crates, ragdolls)
  - Use `apply_force()`, `apply_impulse()` for movement
  - Set `gravity_scale`, `mass`, `friction` properties

- **StaticBody2D/3D**: For immovable objects (platforms, walls)
  - Add CollisionShape2D/3D as child
  - No script needed for basic collision

- **Area2D/3D**: For detection zones (collectibles, triggers, damage zones)
  - Connect `body_entered`, `body_exited` signals
  - Use layers/masks for filtering

### UI Nodes (Control)
- **Control**: Base for all UI elements
- **Label**: Display text
- **Button**: Clickable button, use `pressed` signal
- **TextEdit**: Multi-line text input
- **LineEdit**: Single-line text input
- **ProgressBar**: Health bars, loading progress
- **TextureRect**: Display images
- **Panel/PanelContainer**: Styled backgrounds
- **VBoxContainer/HBoxContainer**: Automatic layout
- **MarginContainer**: Add padding
- **ScrollContainer**: Scrollable content

### Animation
- **AnimatedSprite2D**: Frame-based sprite animation
  - Requires `SpriteFrames` resource
  - Use `play()`, `stop()`, `animation` property

- **AnimationPlayer**: General-purpose animation
  - Animate any property on any node
  - Use `play()`, `queue()`, connect `animation_finished`

- **AnimationTree**: Complex animation state machines
  - Use with AnimationNodeStateMachine

### Audio
- **AudioStreamPlayer**: Non-positional audio (music, UI sounds)
- **AudioStreamPlayer2D/3D**: Positional audio
- Use `play()`, `stop()`, `stream` property

## Common Patterns

### Player Movement (2D Platformer)
```gdscript
extends CharacterBody2D

const SPEED := 300.0
const JUMP_VELOCITY := -400.0

func _physics_process(delta: float) -> void:
    # Gravity
    if not is_on_floor():
        velocity += get_gravity() * delta

    # Jump
    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = JUMP_VELOCITY

    # Horizontal movement
    var direction := Input.get_axis("ui_left", "ui_right")
    if direction:
        velocity.x = direction * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)

    move_and_slide()
```

### Top-Down Movement
```gdscript
extends CharacterBody2D

const SPEED := 200.0

func _physics_process(delta: float) -> void:
    var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    velocity = input_direction * SPEED
    move_and_slide()
```

### Collectible Item
```gdscript
extends Area2D

signal collected

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        collected.emit()
        queue_free()
```

### Health System
```gdscript
extends Node

signal health_changed(new_health: int)
signal died

@export var max_health := 100
var current_health: int

func _ready() -> void:
    current_health = max_health

func take_damage(amount: int) -> void:
    current_health = maxi(0, current_health - amount)
    health_changed.emit(current_health)
    if current_health <= 0:
        died.emit()

func heal(amount: int) -> void:
    current_health = mini(max_health, current_health + amount)
    health_changed.emit(current_health)
```

### Singleton/Autoload Pattern
```gdscript
# GameManager.gd (add to Project Settings > AutoLoad)
extends Node

var score := 0
var high_score := 0

func add_score(points: int) -> void:
    score += points
    if score > high_score:
        high_score = score

func reset() -> void:
    score = 0
```

### Scene Switching
```gdscript
# In any script
get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Or with packed scene
var scene := preload("res://scenes/level.tscn")
get_tree().change_scene_to_packed(scene)
```

### Spawning Objects
```gdscript
var enemy_scene := preload("res://scenes/enemy.tscn")

func spawn_enemy(position: Vector2) -> void:
    var enemy := enemy_scene.instantiate()
    enemy.position = position
    add_child(enemy)
```

## Input Handling

### Input Actions (recommended)
```gdscript
# In Project Settings > Input Map, define actions like:
# - "move_left", "move_right", "jump", "attack"

if Input.is_action_pressed("move_right"):
    # Held down
    pass

if Input.is_action_just_pressed("jump"):
    # Just pressed this frame
    pass

if Input.is_action_just_released("attack"):
    # Just released this frame
    pass
```

### Built-in UI Actions
- `ui_accept`: Enter/Space
- `ui_cancel`: Escape
- `ui_left/right/up/down`: Arrow keys
- `ui_focus_next`: Tab
- `ui_focus_prev`: Shift+Tab

## Signals Best Practices

### Defining Signals
```gdscript
signal health_changed(new_health: int)
signal item_collected(item_type: String, value: int)
```

### Connecting Signals
```gdscript
# In code (preferred)
func _ready() -> void:
    $Button.pressed.connect(_on_button_pressed)
    $Area2D.body_entered.connect(_on_body_entered)

# With custom parameters
func _ready() -> void:
    for button in $Buttons.get_children():
        button.pressed.connect(_on_button_pressed.bind(button.name))
```

### Emitting Signals
```gdscript
health_changed.emit(current_health)
item_collected.emit("coin", 10)
```

## File Paths

- `res://` - Project resources (read-only in export)
- `user://` - User data directory (persistent, writable)

```gdscript
# Save game data
var save_file := FileAccess.open("user://save.json", FileAccess.WRITE)
save_file.store_string(JSON.stringify(data))
save_file.close()

# Load game data
if FileAccess.file_exists("user://save.json"):
    var load_file := FileAccess.open("user://save.json", FileAccess.READ)
    var data := JSON.parse_string(load_file.get_as_text())
    load_file.close()
```

## Common Gotchas

1. **Use `@onready` for node references**
   ```gdscript
   @onready var sprite := $Sprite2D  # Gets node after _ready()
   ```

2. **Use `@export` for inspector variables**
   ```gdscript
   @export var speed := 200.0
   @export var enemy_scene: PackedScene
   ```

3. **Physics in `_physics_process()`, visuals in `_process()`**

4. **Always type your variables for better error catching**
   ```gdscript
   var score: int = 0
   var player_name: String = ""
   var items: Array[Item] = []
   ```

5. **Use `queue_free()` not `free()` to safely delete nodes**

6. **Check for null before accessing nodes**
   ```gdscript
   if player and is_instance_valid(player):
       player.take_damage(10)
   ```
