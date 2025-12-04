# 2D Platformer Game - Godot 4

## Features
- **Player Movement**: Smooth left/right movement with arrow keys
- **Double Jump**: Jump once on ground, once in mid-air
- **Physics**: Realistic gravity and collision detection
- **Camera**: Smooth following camera
- **Respawn System**: Player respawns if falling off the map
- **Debug UI**: Shows velocity, jump count, and grounded state

## Controls
- **Arrow Keys** (← →): Move left and right
- **SPACE**: Jump (press again in air for double jump)
- **ESC** or **R**: Restart level

## Project Structure

### Scripts (`res://scripts/`)
- **player.gd**: Player controller with movement, jumping, and double jump
- **game_camera.gd**: Smooth camera that follows the player
- **game_manager.gd**: Manages respawning and level state
- **tile_map_manager.gd**: Utility functions for tile interactions
- **ui_controller.gd**: Updates debug UI and handles restart input

### Scenes (`res://scenes/`)
- **player.tscn**: Player character with collision and visuals
- **game_level.tscn**: Main playable level with platforms
- **tile_platform.tscn**: Tilemap template (for creating new levels)

## How to Play
1. Open `game_level.tscn` in Godot 4
2. Press F5 or click Run to play
3. Use arrow keys to move and SPACE to jump
4. Test the double jump by jumping while in mid-air

## Extending the Game

### Adding Enemies
Create a new script inheriting from `CharacterBody2D` and add enemy logic. The project structure supports easy addition of new game objects.

### Adding Coins/Collectibles
1. Create a new scene with an Area2D node
2. Add a script that detects player collision
3. Emit signals when collected to update score

### Creating New Levels
1. Duplicate `game_level.tscn`
2. Edit the TileMap to create new platform layouts
3. Move the SpawnPoint marker to set starting position
4. Adjust the `death_y` value in GameManager if needed

### Adding More Mechanics
- **Wall Jump**: Check `is_on_wall()` in player.gd
- **Dash**: Add a dash cooldown timer and velocity boost
- **Enemies**: Create patrol patterns using Path2D or simple AI
- **Moving Platforms**: Use AnimatableBody2D with AnimationPlayer

## Technical Notes
- Uses Godot 4.x physics engine
- Tile size: 64x64 pixels
- Player size: 32x32 pixels
- Gravity: 980 units/s² (standard earth-like gravity)
- Jump velocity: -500 (negative Y is up in Godot)
- Movement speed: 300 units/second

## Next Steps
The code is organized to make it easy to add:
- Multiple levels with scene transitions
- Enemy AI with patrol and chase behaviors
- Collectible items (coins, power-ups)
- Health system and player damage
- Sound effects and background music
- Particle effects for jumps and landings
- Animated sprites instead of colored rectangles