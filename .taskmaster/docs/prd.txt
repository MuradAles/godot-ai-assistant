# Product Requirements Document (PRD)
# AI Game Builder for Godot
## "Lovable for Game Development"

**Document Version:** 2.0  
**Date:** December 2025  
**Author:** [Your Name]  
**Project Type:** Godot Engine Plugin (Brownfield Development)

---

## Executive Summary

AI Game Builder is an intelligent plugin for Godot Engine that enables users to create games through natural language conversation—without writing any code. Think of it as **"Lovable for Godot"** or **"Cursor for game development."**

Users describe what they want ("create a player that can double jump"), and the AI generates complete, working game elements—scenes, scripts, animations, and configurations. The AI deeply understands Godot's architecture, knows how to set up shadows, physics, animations, and can optimize performance.

This project fulfills the **Uncharted Territory Challenge** by forking the Godot Engine repository (90,000+ stars) and extending it with a novel AI-powered game development interface using GDScript—a new language for the developer.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Problem Statement](#2-problem-statement)
3. [Goals & Objectives](#3-goals--objectives)
4. [Target Users](#4-target-users)
5. [User Stories](#5-user-stories)
6. [Feature Requirements](#6-feature-requirements)
7. [Model Selection & API Integration](#7-model-selection--api-integration)
8. [Asset Handling System](#8-asset-handling-system)
9. [AI Capabilities - What It "Knows"](#9-ai-capabilities---what-it-knows)
10. [User Experience & Workflow](#10-user-experience--workflow)
11. [Technical Architecture](#11-technical-architecture)
12. [Memory Bank System](#12-memory-bank-system)
13. [Success Metrics](#13-success-metrics)
14. [Development Timeline](#14-development-timeline)
15. [Risks & Mitigations](#15-risks--mitigations)
16. [Future Roadmap](#16-future-roadmap)
17. [Appendix](#17-appendix)

---

## 1. Project Overview

### 1.1 What We're Building

An AI-powered editor plugin for Godot 4.5 that transforms natural language into functional games. The AI acts as an expert Godot developer that:

- **Knows** how to build games (scenes, scripts, physics, animations)
- **Knows** what to save (correct file formats, proper locations)
- **Knows** how to run (tells user how to test, configures properly)
- **Knows** optimization (efficient code, proper node types)
- **Remembers** everything built (memory bank system)

### 1.2 The "Lovable for Godot" Vision

| Lovable (Web Apps) | AI Game Builder (Games) |
|-------------------|-------------------------|
| Describe UI → React code | Describe game → GDScript + Scenes |
| Knows React/HTML/CSS | Knows GDScript/Nodes/Physics |
| Creates files automatically | Creates .tscn and .gd files |
| Live preview | Press F5 to play |
| Remembers context | Memory Bank system |
| Iterative refinement | "Make jump higher" works |

### 1.3 Challenge Requirements Compliance

| Requirement | How We Meet It |
|-------------|----------------|
| Fork substantial repo (1000+ stars) | Godot Engine (~90,000 stars) ✅ |
| New programming language | GDScript (Python-like, game-focused) ✅ |
| New ecosystem | Godot Engine, EditorPlugin API ✅ |
| Non-trivial feature | AI integration + scene generation + memory system ✅ |
| Production-ready | Fully functional, documented, demoed ✅ |

### 1.4 Technology Stack

| Component | Technology |
|-----------|------------|
| Plugin Language | GDScript |
| Engine | Godot 4.5 |
| AI Providers | Claude (Anthropic), OpenAI |
| AI Models | Claude Opus 4.5, Claude Sonnet 4.5, GPT-5, GPT-4o |
| Data Storage | JSON (Memory Bank) |
| File Formats | .tscn (scenes), .gd (scripts) |

---

## 2. Problem Statement

### 2.1 The Problem

Game development has a steep learning curve. Even with beginner-friendly engines like Godot, users must learn:

- Programming concepts (variables, functions, loops)
- GDScript syntax and patterns
- Godot's node system and scene architecture
- Physics, input handling, collision detection
- Animation systems and sprite sheet setup
- UI systems, signals, and state management

**This creates a barrier** that stops many people from making their game ideas reality.

### 2.2 Who This Affects

- **Complete beginners** who want to make games
- **Designers/Artists** who have ideas but can't code
- **Hobbyists** who want quick prototypes
- **Educators** teaching game concepts
- **Experienced devs** who want faster iteration

### 2.3 Current Solutions & Their Gaps

| Existing Solution | Limitation |
|-------------------|------------|
| Godot tutorials | Still requires coding knowledge |
| Visual scripting | Removed in Godot 4, was still complex |
| AI code assistants (Copilot) | Helps coders, not non-coders |
| No-code game makers | Limited, not professional-grade |
| Existing Godot AI plugins | Code assistance only, not full generation |

### 2.4 Our Solution

An AI layer that:
- Understands game development deeply
- Translates natural language to complete game elements
- Handles all technical details (physics, animations, etc.)
- Remembers context across the entire project
- Works with user-provided assets (sprite sheets, images)
- Enables iterative refinement through conversation

---

## 3. Goals & Objectives

### 3.1 Primary Goal

**Enable anyone to build a simple game through conversation, without writing a single line of code.**

### 3.2 Core Objectives

| Objective | Success Criteria |
|-----------|------------------|
| Zero-code game creation | User creates playable game without coding |
| Deep Godot knowledge | AI correctly uses nodes, physics, animations |
| Asset support | AI uses user-provided sprite sheets correctly |
| Context awareness | AI remembers what was built, enables iteration |
| Quality output | Generated code follows Godot best practices |
| Multiple AI providers | User chooses their preferred model |

### 3.3 Non-Goals (Out of Scope for MVP)

- ❌ AI-generated images/sprites (future: Retro Diffusion)
- ❌ AI-generated audio/music
- ❌ AI-generated 3D models
- ❌ Full game generation from single prompt
- ❌ Multiplayer/networking features
- ❌ Visual node-based programming (blueprints)

---

## 4. Target Users

### 4.1 Primary Persona: "The Dreamer"

**Name:** Alex  
**Background:** Has game ideas, watches game dev videos, never coded  
**Goal:** Create a simple platformer game  
**Pain Point:** Every tutorial assumes coding knowledge  
**Need:** Step-by-step guidance that doesn't require code

**Example Request:**
> "I want to make a platformer where you collect coins and avoid enemies"

### 4.2 Secondary Persona: "The Artist"

**Name:** Jordan  
**Background:** Pixel artist, has sprite sheets ready, no coding skills  
**Goal:** See their art come to life in a game  
**Pain Point:** Art is done but can't make it interactive  
**Need:** Tool that uses their assets without coding

**Example Request:**
> "Use my character_sheet.png (32x32 frames) for a player that walks and jumps"

### 4.3 Tertiary Persona: "The Prototyper"

**Name:** Sam  
**Background:** Game designer at studio, knows some coding  
**Goal:** Rapid prototype to test game feel  
**Pain Point:** Takes too long to code basic mechanics  
**Need:** Fast iteration, focus on design not implementation

**Example Request:**
> "Create a twin-stick shooter prototype with 3 enemy types"

---

## 5. User Stories

### 5.1 Core User Stories (MVP)

#### US-1: First Game Element
> **As a** complete beginner  
> **I want to** describe a game character in plain English  
> **So that** I can see it appear in my game without coding

**Acceptance Criteria:**
- [ ] User types "create a player that moves and jumps"
- [ ] System generates Player.tscn with CharacterBody2D
- [ ] System generates player.gd with movement script
- [ ] Player appears in scene tree, ready to test
- [ ] Memory bank records the player was created

#### US-2: Use My Sprite Sheet
> **As an** artist with existing assets  
> **I want to** use my sprite sheet without manual configuration  
> **So that** I can see my art animated in the game

**Acceptance Criteria:**
- [ ] User says "use hero.png for my character"
- [ ] System detects image dimensions (e.g., 192x32)
- [ ] System suggests likely frame size (e.g., 32x32)
- [ ] User confirms or corrects
- [ ] System sets up animations with correct frames

#### US-3: Iterative Refinement
> **As a** user building a game  
> **I want to** refine elements through conversation  
> **So that** I can adjust my game without understanding code

**Acceptance Criteria:**
- [ ] User says "make the player jump higher"
- [ ] System finds player in memory bank
- [ ] System identifies jump_velocity property
- [ ] System modifies the value
- [ ] Change is reflected immediately

#### US-4: Building on Context
> **As a** user with existing game elements  
> **I want** the AI to remember what I've built  
> **So that** new elements work together correctly

**Acceptance Criteria:**
- [ ] User previously created "Player"
- [ ] User says "add coins for the player to collect"
- [ ] System creates Coin scene with collision
- [ ] System references existing Player for interaction
- [ ] Score system integrates with Player

#### US-5: Choose AI Model
> **As a** user with API access  
> **I want to** choose my preferred AI model  
> **So that** I can use the model that works best for me

**Acceptance Criteria:**
- [ ] Settings panel shows provider dropdown (Anthropic/OpenAI)
- [ ] Model dropdown shows available models
- [ ] API key field with masked input
- [ ] Test connection button
- [ ] Settings persist between sessions

### 5.2 Extended User Stories (Post-MVP)

- US-6: Preview game in editor panel
- US-7: Undo/redo AI changes
- US-8: Export with documentation
- US-9: Generate assets with Retro Diffusion

---

## 6. Feature Requirements

### 6.1 MVP Features (Must Have)

#### F1: Chat Interface
| Aspect | Requirement |
|--------|-------------|
| Location | Bottom panel (alongside Output, Debugger) |
| Input | Multi-line text field with send button |
| Output | Scrollable message history with formatting |
| Styling | Matches Godot editor theme |
| Loading | Shows indicator while AI processing |

#### F2: Multi-Model AI Integration
| Aspect | Requirement |
|--------|-------------|
| Providers | Anthropic (Claude), OpenAI |
| Models | Claude Opus 4.5, Claude Sonnet 4.5, GPT-5, GPT-4o |
| Selection | Dropdown in settings |
| Switching | Can change model anytime |
| Fallback | Clear error if API fails |

#### F3: Script Generation
| Aspect | Requirement |
|--------|-------------|
| Output | Valid GDScript files (.gd) |
| Quality | Follows Godot 4.x conventions |
| Location | Saved to res://scripts/ |
| Validation | Syntax check before saving |
| Best Practices | Proper signals, exports, typing |

#### F4: Scene Generation
| Aspect | Requirement |
|--------|-------------|
| Output | Valid scene files (.tscn) |
| Nodes | Correct types for purpose |
| Hierarchy | Proper parent/child structure |
| Properties | Appropriate default values |
| Scripts | Attached to relevant nodes |

#### F5: Asset Integration
| Aspect | Requirement |
|--------|-------------|
| Sprite Sheets | Supports single-image sheets |
| Detection | Auto-detects image dimensions |
| Frame Guessing | Suggests common sizes (16, 32, 64) |
| User Confirm | Asks user to verify frame size |
| Animations | Sets up AnimatedSprite2D or AnimationPlayer |

#### F6: Memory Bank
| Aspect | Requirement |
|--------|-------------|
| Persistence | Survives editor restarts |
| Content | Tracks all elements, properties, relationships |
| Context | Passed to AI with each request |
| Format | JSON for easy inspection |

### 6.2 Should Have Features

#### F7: Project Context Awareness
- Detect currently open scene
- Know which node is selected
- Understand project structure

#### F8: Modification Support
- Edit existing scripts via chat
- Update scene properties
- Rename/reorganize elements

#### F9: Smart Suggestions
- Suggest next steps after creation
- Offer common game elements
- Recommend optimizations

### 6.3 Nice to Have Features

#### F10: Game Preview Panel
- Embedded SubViewport for testing
- Quick play button

#### F11: Conversation History
- Save/load past conversations
- Search through history

---

## 7. Model Selection & API Integration

### 7.1 Supported Models

| Provider | Model | Best For |
|----------|-------|----------|
| Anthropic | Claude Opus 4.5 | Complex reasoning, best quality |
| Anthropic | Claude Sonnet 4.5 | Good balance of speed/quality |
| OpenAI | GPT-5 | Latest capabilities |
| OpenAI | GPT-4o | Fast, multimodal |

### 7.2 Settings UI

```
┌─────────────────────────────────────────────────────┐
│              AI GAME BUILDER SETTINGS                │
├─────────────────────────────────────────────────────┤
│                                                     │
│  AI Provider                                        │
│  ┌─────────────────────────────────────┐           │
│  │ Anthropic (Claude)              ▼   │           │
│  └─────────────────────────────────────┘           │
│                                                     │
│  Model                                              │
│  ┌─────────────────────────────────────┐           │
│  │ Claude Sonnet 4.5               ▼   │           │
│  └─────────────────────────────────────┘           │
│  ┌─────────────────────────────────────┐           │
│  │ Claude Opus 4.5     (Best quality)  │           │
│  │ Claude Sonnet 4.5   (Recommended)   │ ◄─────────│
│  │ GPT-5               (Latest)        │           │
│  │ GPT-4o              (Fast)          │           │
│  └─────────────────────────────────────┘           │
│                                                     │
│  API Key                                            │
│  ┌─────────────────────────────────────┐           │
│  │ ••••••••••••••••••••••••••••••••   │           │
│  └─────────────────────────────────────┘           │
│                                                     │
│  ┌───────────────────┐  ┌───────────────────┐     │
│  │  Test Connection  │  │       Save        │     │
│  └───────────────────┘  └───────────────────┘     │
│                                                     │
│  Status: ✓ Connected successfully                  │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 7.3 API Endpoints

| Provider | Endpoint | Auth Header |
|----------|----------|-------------|
| Anthropic | `api.anthropic.com/v1/messages` | `x-api-key` |
| OpenAI | `api.openai.com/v1/chat/completions` | `Authorization: Bearer` |

### 7.4 Request Structure

**Claude API:**
```json
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 4096,
  "system": "[System prompt with Godot knowledge + Memory Bank]",
  "messages": [
    {"role": "user", "content": "[User request]"}
  ]
}
```

**OpenAI API:**
```json
{
  "model": "gpt-5",
  "messages": [
    {"role": "system", "content": "[System prompt]"},
    {"role": "user", "content": "[User request]"}
  ]
}
```

### 7.5 Settings Storage

| Setting | Location | Reason |
|---------|----------|--------|
| API Key | EditorSettings | Secure, outside project |
| Provider | EditorSettings | User preference |
| Model | EditorSettings | User preference |

**EditorSettings keeps API keys safe** - they're stored in the user's Godot config directory, never in the project (so they won't end up in version control).

---

## 8. Asset Handling System

### 8.1 Core Principle

**Users provide assets → AI uses them correctly**

No AI generation of images in MVP. Future integration with Retro Diffusion planned.

### 8.2 Supported Asset Types

| Asset Type | Format | AI Capability |
|------------|--------|---------------|
| Sprite Sheet | .png (single image) | Auto-detect frames, setup animations |
| Separate Frames | multiple .png files | Create AnimatedSprite2D |
| Static Sprites | .png | Assign to Sprite2D |
| Tilesets | .png | Setup TileMap |
| Audio | .wav, .ogg, .mp3 | Assign to AudioStreamPlayer |

### 8.3 Sprite Sheet Auto-Detection

#### Step 1: Load Image Dimensions
```
User uploads: hero_sheet.png

AI Detects:
├── Total size: 192x64 pixels
├── File name: hero_sheet.png
└── Location: res://assets/hero_sheet.png
```

#### Step 2: Calculate Possible Frame Sizes
```
Trying common sizes against 192x64:

16x16: 192÷16=12 ✓, 64÷16=4 ✓ → 12×4 grid (48 frames)
32x32: 192÷32=6 ✓, 64÷32=2 ✓ → 6×2 grid (12 frames) ← LIKELY
64x64: 192÷64=3 ✓, 64÷64=1 ✓ → 3×1 grid (3 frames)
48x48: 192÷48=4 ✓, 64÷48=✗ → Doesn't fit evenly

Best guess: 32x32 (most common, fits well)
```

#### Step 3: Ask User to Confirm
```
AI: "📊 Analyzing hero_sheet.png...

     Image size: 192x64 pixels
     
     I think this is:
     → 32x32 frames (12 frames in 6×2 grid)
     
     Is this correct?
     
     Or tell me: 'it's 16x16' or 'it's 64x64'"

User: "Yes, and row 1 is walk, row 2 is jump"

AI: "✓ Setting up animations:
     • walk: frames 0-5 (top row)
     • jump: frames 6-11 (bottom row)
     
     Creating Player with AnimatedSprite2D..."
```

### 8.4 Asset Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    ASSET WORKFLOW                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. USER ADDS ASSET TO PROJECT                              │
│     Copies hero.png to res://assets/                        │
│                                                             │
│                    ▼                                        │
│                                                             │
│  2. USER REFERENCES IN CHAT                                 │
│     "Use hero.png for my player"                            │
│                                                             │
│                    ▼                                        │
│                                                             │
│  3. PLUGIN ANALYZES                                         │
│     ├── Read image dimensions                               │
│     ├── Calculate possible frame sizes                      │
│     └── Determine best guess                                │
│                                                             │
│                    ▼                                        │
│                                                             │
│  4. AI ASKS FOR CONFIRMATION                                │
│     "Looks like 32x32 frames. Correct?"                     │
│                                                             │
│                    ▼                                        │
│                                                             │
│  5. USER CONFIRMS OR CORRECTS                               │
│     "Yes" or "No, it's 16x16"                               │
│                                                             │
│                    ▼                                        │
│                                                             │
│  6. AI CONFIGURES PROPERLY                                  │
│     ├── Sets hframes/vframes                                │
│     ├── Creates animations                                  │
│     ├── Attaches to correct node                            │
│     └── Updates memory bank                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 8.5 Placeholder System

When user has no assets yet:

```
User: "Create a player character"

AI: "✓ Created Player with placeholder!

    Using: Temporary blue rectangle (32x32)
    
    Files:
    • scenes/Player.tscn
    • scripts/player.gd
    
    ⚠️ No sprite assigned yet.
    
    To add your art:
    1. Add sprite to res://assets/
    2. Tell me: 'Use [filename] for the player'
    
    Press F5 to test (works with placeholder)!"
```

### 8.6 Animation Configuration

User can describe animations in natural language:

```
User: "First 4 frames are idle, next 6 are walk, last 2 are jump"

AI Interprets:
├── idle: frames 0-3, loop: true, fps: 6
├── walk: frames 4-9, loop: true, fps: 10
└── jump: frames 10-11, loop: false, fps: 8
```

Or with a simple format:

```
User: "4 idle, 6 walk, 2 jump"

AI: "Got it! Setting up:
     • idle: 4 frames (0-3)
     • walk: 6 frames (4-9)
     • jump: 2 frames (10-11)"
```

---

## 9. AI Capabilities - What It "Knows"

### 9.1 The AI Deeply Understands Godot

This is what makes the plugin "Lovable for Godot" - the AI isn't just generating random code. It knows:

### 9.2 Node Types & When to Use Them

```
AI KNOWLEDGE: NODES
├── CharacterBody2D → Player/enemies that move with physics
├── StaticBody2D → Platforms, walls (don't move)
├── RigidBody2D → Objects affected by physics (crates, balls)
├── Area2D → Detection zones (coins, triggers)
├── Sprite2D → Display images
├── AnimatedSprite2D → Animated images
├── CollisionShape2D → Define collision boundaries
├── Camera2D → Follow player, screen limits
├── TileMap → Level building with tiles
├── CanvasLayer → UI that stays on screen
├── AudioStreamPlayer2D → Spatial sound
└── ... (all Godot nodes)
```

### 9.3 Physics & Collision

```
AI KNOWLEDGE: PHYSICS
├── Collision layers (what can hit what)
├── Collision masks (what to detect)
├── Physics materials (bounce, friction)
├── move_and_slide() vs move_and_collide()
├── Raycasting for detection
├── Gravity and velocity handling
└── One-way platforms
```

### 9.4 Shadows & Lighting

```
AI KNOWLEDGE: LIGHTING (2D)
├── DirectionalLight2D → Sun-like light
├── PointLight2D → Local light source
├── Shadows → Enable with shadow_enabled = true
├── CanvasModulate → Scene-wide color tint
├── Light masks → What gets lit
└── Normal maps → Depth illusion

AI KNOWLEDGE: LIGHTING (3D)
├── DirectionalLight3D → Sun with shadows
├── OmniLight3D → Point light
├── SpotLight3D → Flashlight effect
├── Environment → Ambient, fog, glow
├── Shadow quality settings
└── Baked vs realtime lighting
```

### 9.5 Optimization

```
AI KNOWLEDGE: OPTIMIZATION
├── Object pooling (reuse bullets/particles)
├── Proper node types (StaticBody vs RigidBody)
├── Collision layer organization
├── LOD (Level of Detail)
├── Texture compression
├── Efficient GDScript patterns
├── call_deferred for safe operations
├── Signals instead of polling
└── Autoloads for managers
```

### 9.6 Animation Systems

```
AI KNOWLEDGE: ANIMATION
├── AnimationPlayer → Timeline-based animation
├── AnimatedSprite2D → Frame-based sprite animation
├── SpriteFrames resource → Animation library
├── Sprite sheets → hframes/vframes setup
├── Animation blending
├── Callbacks and signals
└── State machine patterns
```

### 9.7 What AI CAN Do (MVP)

| Capability | Example |
|------------|---------|
| Create scenes | "Create a player scene" |
| Write scripts | Full GDScript with best practices |
| Setup physics | Collision layers, bodies, detection |
| Configure lighting | Shadows, lights, environment |
| Use assets | Sprite sheets, images, audio |
| Setup animations | From sprite sheets or separate frames |
| Build UI | Menus, HUD, buttons |
| Optimize code | Object pooling, efficient patterns |
| Configure input | Keyboard, controller, touch |
| Connect signals | Events between nodes |
| Create tilemaps | Level building setup |

### 9.8 What AI CANNOT Do (MVP)

| Limitation | Reason |
|------------|--------|
| Generate images | Needs image AI (future: Retro Diffusion) |
| Generate 3D models | Needs 3D AI |
| Generate audio | Needs audio AI |
| Edit image pixels | Not in scope |
| Complex shaders | Basic only in MVP |

---

## 10. User Experience & Workflow

### 10.1 First-Time Setup

```
┌─────────────────────────────────────────────────────────────┐
│                   FIRST TIME SETUP                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. INSTALL PLUGIN                                          │
│     Copy addons/ai_game_builder/ to project                 │
│                                                             │
│  2. ENABLE PLUGIN                                           │
│     Project Settings → Plugins → Enable                     │
│                                                             │
│  3. OPEN AI PANEL                                           │
│     Panel appears in bottom dock                            │
│                                                             │
│  4. CONFIGURE API                                           │
│     ┌─────────────────────────────────────────┐            │
│     │  Welcome to AI Game Builder! 🎮          │            │
│     │                                          │            │
│     │  To get started, configure your AI:     │            │
│     │                                          │            │
│     │  Provider: [Anthropic ▼]                │            │
│     │  Model: [Claude Sonnet 4.5 ▼]           │            │
│     │  API Key: [••••••••••••••]              │            │
│     │                                          │            │
│     │  [Test Connection]  [Save]              │            │
│     └─────────────────────────────────────────┘            │
│                                                             │
│  5. START BUILDING                                          │
│     "Describe what you want to build..."                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 10.2 Main Interaction Loop

```
┌─────────────────────────────────────────────────────────────┐
│                    MAIN WORKFLOW                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  STEP 1: USER DESCRIBES                                     │
│  ───────────────────────                                    │
│  "Create a platformer player with double jump"              │
│                                                             │
│                    ▼                                        │
│                                                             │
│  STEP 2: AI PLANS                                           │
│  ────────────────────                                       │
│  AI determines:                                             │
│  ├── Need CharacterBody2D (for physics)                    │
│  ├── Need Sprite2D or placeholder                          │
│  ├── Need CollisionShape2D                                 │
│  ├── Script needs: velocity, gravity, double jump logic    │
│  └── Check memory: any existing assets to use?             │
│                                                             │
│                    ▼                                        │
│                                                             │
│  STEP 3: AI GENERATES                                       │
│  ─────────────────────                                      │
│  Creates files:                                             │
│  ├── res://scenes/Player.tscn                              │
│  ├── res://scripts/player.gd                               │
│  └── Updates memory_bank.json                              │
│                                                             │
│                    ▼                                        │
│                                                             │
│  STEP 4: AI RESPONDS                                        │
│  ─────────────────────                                      │
│  "✓ Created Player with double jump!                       │
│                                                             │
│   Files created:                                            │
│   • scenes/Player.tscn                                     │
│   • scripts/player.gd                                      │
│                                                             │
│   Features:                                                 │
│   • Move: Arrow keys or A/D                                │
│   • Jump: Space (can jump again in air!)                   │
│   • Speed: 300, Jump: -400                                 │
│                                                             │
│   Press F6 to test!                                        │
│                                                             │
│   What's next?                                              │
│   • Add platforms                                          │
│   • Add coins to collect                                   │
│   • Add enemies"                                           │
│                                                             │
│                    ▼                                        │
│                                                             │
│  STEP 5: USER TESTS                                         │
│  ───────────────────                                        │
│  Opens Player.tscn, presses F6                             │
│  Character moves and double jumps!                         │
│                                                             │
│                    ▼                                        │
│                                                             │
│  STEP 6: USER ITERATES                                      │
│  ─────────────────────                                      │
│  "Make the jump floatier"                                  │
│  "Add my sprite hero.png"                                  │
│  "Now add platforms"                                       │
│  (Loop back to Step 1)                                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 10.3 Example Complete Session

```
USER: I want to make a simple platformer

AI: Great! Let's build it step by step. 
    What should the player be able to do?
    • Move left/right
    • Jump
    • Double jump
    • Wall jump
    
    Or describe your own!

USER: Move and jump is fine

AI: ✓ Created Player!

    Files:
    • scenes/Player.tscn
    • scripts/player.gd
    
    Controls:
    • Arrows or A/D: Move
    • Space: Jump
    
    ⚠️ Using placeholder (blue rectangle)
    To add your sprite: "use [filename] for player"
    
    Press F6 to test!
    
    Next suggestions:
    • Add platforms to jump on
    • Add collectible coins
    • Add your own sprite

USER: Add platforms

AI: ✓ Created Platform and Level!

    Files:
    • scenes/Platform.tscn (reusable)
    • scenes/Level1.tscn (with Player + 5 platforms)
    
    Open Level1.tscn and press F5 to play!

USER: The jump feels too weak

AI: ✓ Updated player.gd

    Changed:
    • jump_velocity: -400 → -500
    
    Jump is now 25% stronger. Try it!
    
    Want more? "make jump even higher" or 
    tell me specific value: "set jump to -600"

USER: I have a sprite sheet hero.png

AI: 📊 Analyzing hero.png...

    Image size: 192x32 pixels
    
    I think this is:
    → 32x32 frames (6 frames total)
    
    Is this correct?
    What are the animations?
    e.g., "4 walk, 2 jump" or "all walk"

USER: Yes, 4 walk and 2 jump

AI: ✓ Updated Player with hero.png!

    Animations configured:
    • walk: frames 0-3, 10 FPS, loops
    • jump: frames 4-5, 8 FPS, no loop
    
    Auto-switching:
    • Moving → plays "walk"
    • Jumping → plays "jump"
    • Idle → shows frame 0
    
    Press F5 to see your hero in action!

USER: Add coins to collect

AI: ✓ Created Coin and Score system!

    Files:
    • scenes/Coin.tscn (with rotation animation)
    • scripts/coin.gd (collect + disappear)
    • scripts/game_manager.gd (tracks score)
    
    Updated:
    • Level1.tscn (added 5 coins)
    • Added score display (top-left)
    
    Coins give 10 points each.
    Press F5 to play!
```

### 10.4 UI Layout in Editor

```
┌─────────────────────────────────────────────────────────────────────┐
│  GODOT EDITOR                                                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────┐ ┌─────────────────────────────────┐ ┌──────────────┐  │
│  │  Scene   │ │                                 │ │  Inspector   │  │
│  │  Tree    │ │         2D/3D Viewport          │ │              │  │
│  │          │ │                                 │ │  [Node       │  │
│  │  Level1  │ │    ┌─────────────────────┐     │ │   properties]│  │
│  │  ├ Player│ │    │                     │     │ │              │  │
│  │  ├ Platf.│ │    │    [Game View]      │     │ │              │  │
│  │  └ Coins │ │    │                     │     │ │              │  │
│  │          │ │    └─────────────────────┘     │ │              │  │
│  └──────────┘ └─────────────────────────────────┘ └──────────────┘  │
│                                                                      │
│  ┌──────────┐ ┌─────────────────────────────────────────────────────┐
│  │FileSystem│ │ Output │ Debugger │ AI Game Builder ◄━━━━━━━━━━━━━│ │
│  │          │ ├─────────────────────────────────────────────────────┤
│  │ assets/  │ │                                                     │
│  │ ├ hero.pn│ │  🤖 AI: Welcome! Describe what you want to build.  │
│  │ scenes/  │ │                                                     │
│  │ ├ Player │ │  You: Create a player that can move and jump       │
│  │ ├ Level1 │ │                                                     │
│  │ scripts/ │ │  🤖 AI: ✓ Created Player!                          │
│  │ ├ player │ │     Files: Player.tscn, player.gd                  │
│  │          │ │     Press F6 to test!                               │
│  │          │ │                                                     │
│  │          │ │  You: Make jump higher                              │
│  │          │ │                                                     │
│  │          │ │  🤖 AI: ✓ Updated! Jump: -400 → -500               │
│  │          │ │                                                     │
│  │          │ │  ┌─────────────────────────────────────┐ ┌────────┐│
│  │          │ │  │ Type your message...                │ │  Send  ││
│  │          │ │  └─────────────────────────────────────┘ └────────┘│
│  └──────────┘ └─────────────────────────────────────────────────────┘
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 11. Technical Architecture

### 11.1 High-Level System Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GODOT EDITOR                                  │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    AI GAME BUILDER PLUGIN                      │  │
│  │                                                                │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐               │  │
│  │  │  CHAT UI   │  │ AI CLIENT  │  │MEMORY BANK │               │  │
│  │  │            │  │            │  │            │               │  │
│  │  │ • Input    │  │ • Claude   │  │ • Elements │               │  │
│  │  │ • Messages │  │ • OpenAI   │  │ • Context  │               │  │
│  │  │ • Settings │  │ • Parser   │  │ • History  │               │  │
│  │  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘               │  │
│  │        │               │               │                       │  │
│  │        └───────────────┼───────────────┘                       │  │
│  │                        │                                       │  │
│  │                        ▼                                       │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │                 GENERATION ENGINE                        │  │  │
│  │  │                                                          │  │  │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │  │
│  │  │  │   SCRIPT     │  │    SCENE     │  │    ASSET     │   │  │  │
│  │  │  │  GENERATOR   │  │  GENERATOR   │  │  ANALYZER    │   │  │  │
│  │  │  │              │  │              │  │              │   │  │  │
│  │  │  │  • .gd files │  │  • .tscn     │  │  • Detect    │   │  │  │
│  │  │  │  • Validate  │  │  • Nodes     │  │  • Configure │   │  │  │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘   │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  │                        │                                       │  │
│  └────────────────────────┼───────────────────────────────────────┘  │
│                           ▼                                          │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    GODOT FILE SYSTEM                           │  │
│  │                                                                │  │
│  │  res://scenes/    res://scripts/    res://assets/    user://  │  │
│  │  └ Player.tscn    └ player.gd       └ hero.png       └ memory │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                │ HTTPS API Calls
                                ▼
            ┌─────────────────────────────────────┐
            │         AI PROVIDER                  │
            │                                      │
            │  ┌─────────────┐  ┌─────────────┐   │
            │  │  Anthropic  │  │   OpenAI    │   │
            │  │  Claude API │  │   GPT API   │   │
            │  └─────────────┘  └─────────────┘   │
            │                                      │
            └─────────────────────────────────────┘
```

### 11.2 Plugin File Structure

```
addons/ai_game_builder/
│
├── plugin.cfg                      # Plugin metadata
├── plugin.gd                       # Main EditorPlugin entry
│
├── ui/
│   ├── chat_panel.tscn            # Chat interface (visual layout)
│   ├── chat_panel.gd              # Chat logic
│   ├── message_bubble.tscn        # Single message display
│   ├── settings_dialog.tscn       # Settings popup
│   └── settings_dialog.gd         # Settings logic
│
├── api/
│   ├── ai_client.gd               # Base API client
│   ├── claude_provider.gd         # Anthropic implementation
│   ├── openai_provider.gd         # OpenAI implementation
│   └── response_parser.gd         # Parse AI responses
│
├── memory/
│   ├── memory_bank.gd             # Main memory manager
│   ├── element_tracker.gd         # Track game elements
│   └── context_builder.gd         # Build prompts with context
│
├── generators/
│   ├── script_generator.gd        # Create .gd files
│   ├── scene_generator.gd         # Create .tscn files
│   ├── node_builder.gd            # Build node hierarchies
│   └── code_validator.gd          # Validate generated code
│
├── assets/
│   ├── asset_analyzer.gd          # Detect sprite dimensions
│   └── animation_setup.gd         # Configure animations
│
├── prompts/
│   ├── system_prompt.md           # Base AI instructions
│   └── godot_knowledge.md         # Godot-specific context
│
└── resources/
    └── icons/
        └── plugin_icon.svg        # Icon for editor
```

### 11.3 Data Flow

```
USER INPUT
    │
    ▼
┌───────────────┐
│   Chat UI     │ ─── User types message
└───────┬───────┘
        │
        ▼
┌───────────────┐
│Context Builder│ ─── Adds memory bank context
└───────┬───────┘
        │
        ▼
┌───────────────┐     ┌───────────────┐
│  AI Client    │────▶│  AI Provider  │ ─── API call
└───────┬───────┘     └───────┬───────┘
        │                     │
        │◀────────────────────┘ Response
        │
        ▼
┌───────────────┐
│Response Parser│ ─── Extract actions from response
└───────┬───────┘
        │
        ├─────────────────┬─────────────────┐
        ▼                 ▼                 ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│Script Generator│ │Scene Generator│ │ Memory Bank   │
│               │ │               │ │   Update      │
│ • Write .gd   │ │ • Write .tscn │ │ • Track new   │
│ • Validate    │ │ • Set nodes   │ │   elements    │
└───────┬───────┘ └───────┬───────┘ └───────────────┘
        │                 │
        ▼                 ▼
┌─────────────────────────────────────────┐
│           FILE SYSTEM                    │
│   res://scripts/    res://scenes/        │
└─────────────────────────────────────────┘
        │
        ▼
┌───────────────┐
│   Chat UI     │ ─── Show result to user
└───────────────┘
```

---

## 12. Memory Bank System

### 12.1 Purpose

The Memory Bank solves a critical problem: **AI models have no memory between requests.**

Without context, when user says "make the player jump higher," AI doesn't know:
- What player?
- What's the current jump value?
- Where's the script file?

The Memory Bank tracks everything the AI has built.

### 12.2 Storage Location

```
user://ai_game_builder/
├── memory_bank.json           # Main project memory
├── conversation_history.json  # Past conversations
└── settings.json              # User preferences
```

**Why `user://`?** 
- Persists between sessions
- Writable (unlike `res://` in some cases)
- User-specific

### 12.3 Memory Bank Schema

```json
{
  "project": {
    "name": "My Platformer",
    "type": "2d_platformer",
    "created": "2025-12-01T10:00:00Z",
    "last_modified": "2025-12-01T14:30:00Z"
  },
  
  "elements": {
    "player": {
      "id": "elem_001",
      "type": "character",
      "scene_path": "res://scenes/Player.tscn",
      "script_path": "res://scripts/player.gd",
      "node_type": "CharacterBody2D",
      "created": "2025-12-01T10:05:00Z",
      "modified": "2025-12-01T10:30:00Z",
      "properties": {
        "speed": {
          "value": 300,
          "type": "float",
          "line": 5
        },
        "jump_velocity": {
          "value": -500,
          "type": "float",
          "line": 6
        }
      },
      "capabilities": ["move", "jump", "double_jump"],
      "sprite": {
        "path": "res://assets/hero.png",
        "frame_size": [32, 32],
        "hframes": 6,
        "vframes": 1,
        "animations": {
          "walk": {"frames": [0,1,2,3], "fps": 10, "loop": true},
          "jump": {"frames": [4,5], "fps": 8, "loop": false}
        }
      }
    },
    
    "coin": {
      "id": "elem_002",
      "type": "collectible",
      "scene_path": "res://scenes/Coin.tscn",
      "script_path": "res://scripts/coin.gd",
      "node_type": "Area2D",
      "properties": {
        "value": {"value": 10, "type": "int"}
      },
      "interacts_with": ["player"]
    },
    
    "platform": {
      "id": "elem_003",
      "type": "environment",
      "scene_path": "res://scenes/Platform.tscn",
      "node_type": "StaticBody2D"
    }
  },
  
  "scenes": {
    "level1": {
      "path": "res://scenes/Level1.tscn",
      "is_main": true,
      "contains": ["player", "coin", "platform"]
    }
  },
  
  "systems": {
    "score": {
      "enabled": true,
      "manager": "res://scripts/game_manager.gd",
      "current_value": 0
    },
    "health": {
      "enabled": false
    }
  },
  
  "recent_context": {
    "last_action": "Updated player jump_velocity to -500",
    "last_element": "player",
    "suggestions": [
      "Add enemies",
      "Add health system",
      "Create game over screen"
    ]
  }
}
```

### 12.4 Context Injection

When sending prompts to AI, include relevant context:

```
SYSTEM PROMPT + MEMORY CONTEXT:

"You are an expert Godot 4.5 game developer...

CURRENT PROJECT: My Platformer

EXISTING ELEMENTS:
- player: CharacterBody2D at res://scenes/Player.tscn
  Properties: speed=300, jump_velocity=-500
  Sprite: hero.png (32x32, 6 frames)
  Capabilities: move, jump, double_jump

- coin: Area2D at res://scenes/Coin.tscn
  Properties: value=10
  Interacts with: player

- platform: StaticBody2D

SYSTEMS:
- Score: Enabled (game_manager.gd)
- Health: Not implemented

RECENT: Just updated player jump_velocity to -500

USER REQUEST: [their message here]"
```

### 12.5 Memory Update Triggers

| Event | Action |
|-------|--------|
| Script created | Add element to memory |
| Scene created | Add to scenes, link elements |
| Property modified | Update element.properties |
| Element deleted | Remove from memory |
| Session start | Load from disk |
| Every change | Auto-save |

---

## 13. Success Metrics

### 13.1 MVP Success Criteria

| Metric | Target |
|--------|--------|
| Create element via chat | ✅ Working |
| Generated code is valid | >90% first attempt |
| Memory persists restart | ✅ Working |
| Asset detection works | >80% accuracy |
| Iteration works ("jump higher") | ✅ Working |
| Multiple models work | Claude + OpenAI |

### 13.2 User Experience Metrics

| Metric | Target |
|--------|--------|
| Time to first game element | <3 minutes |
| Messages to playable game | <10 |
| User understands output | Clear feedback |

### 13.3 Challenge Evaluation Alignment

| Criteria | Evidence |
|----------|----------|
| Brownfield Mastery | Clean EditorPlugin integration |
| Technical Achievement | AI + Memory + Generation pipeline |
| Learning Velocity | Daily logs showing GDScript learning |
| Software Quality | Stable, handles errors |
| Ambition | Novel AI game-building interface |

---

## 14. Development Timeline

### 14.1 Seven-Day Plan

#### Day 1: Setup & Foundation
- [ ] Fork Godot Engine repository
- [ ] Set up development environment
- [ ] Create plugin skeleton
- [ ] Add basic bottom panel UI
- [ ] Learn GDScript fundamentals
- [ ] Document in brainlift log

#### Day 2: API Integration
- [ ] Implement Claude API client
- [ ] Implement OpenAI API client
- [ ] Create settings dialog (provider, model, key)
- [ ] Test API connections
- [ ] Add model selection dropdown

#### Day 3: Script Generation
- [ ] Implement script generator
- [ ] Create first working generation: "create player"
- [ ] Add file writing and validation
- [ ] Test with different requests

#### Day 4: Scene Generation
- [ ] Implement scene generator
- [ ] Build node hierarchies
- [ ] Connect scripts to scenes
- [ ] Test full generation flow

#### Day 5: Memory Bank & Assets
- [ ] Implement Memory Bank system
- [ ] Add context injection to prompts
- [ ] Implement asset analyzer (sprite sheet detection)
- [ ] Test iteration ("make jump higher")

#### Day 6: Polish & Testing
- [ ] Add error handling throughout
- [ ] Improve UI (loading states, formatting)
- [ ] Test edge cases
- [ ] Fix bugs
- [ ] Add animation setup from sprite sheets

#### Day 7: Documentation & Demo
- [ ] Write comprehensive README
- [ ] Create architecture documentation
- [ ] Record 5-minute demo video
- [ ] Final testing
- [ ] Prepare submission

---

## 15. Risks & Mitigations

### 15.1 Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| GDScript learning curve | High | Use AI to help learn, start simple |
| AI generates invalid code | High | Add validation, error recovery |
| API rate limits | Medium | Implement backoff, caching |
| Complex scenes fail | Medium | Start with simple scenes |
| Memory bank corruption | Medium | Validation on load, backups |

### 15.2 Schedule Risks

| Risk | Mitigation |
|------|------------|
| Underestimated complexity | Clear MVP scope, cut features if needed |
| Debug time overruns | Build in buffer, simplify |

---

## 16. Future Roadmap

### 16.1 Post-MVP Features

**Phase 2: Enhanced Assets**
- Retro Diffusion integration for sprite generation
- Better placeholder graphics
- Audio generation

**Phase 3: Advanced Features**
- Game preview panel in editor
- Undo/redo for AI changes
- Template library
- Community sharing

**Phase 4: Intelligence**
- AI vision for better sprite detection
- Learning from user corrections
- Project-wide optimization suggestions

---

## 17. Appendix

### 17.1 Glossary

| Term | Definition |
|------|------------|
| GDScript | Godot's Python-like scripting language |
| EditorPlugin | Godot's API for extending the editor |
| Scene (.tscn) | Text file containing node hierarchy |
| Node | Basic building block in Godot |
| @tool | Annotation to run script in editor |
| Memory Bank | JSON storage for project context |
| Sprite Sheet | Single image containing multiple animation frames |
| hframes/vframes | Horizontal/vertical frame count in sprite |

### 17.2 Reference Links

- Godot Engine: https://godotengine.org
- Godot Docs: https://docs.godotengine.org
- Claude API: https://docs.anthropic.com
- OpenAI API: https://platform.openai.com/docs

### 17.3 Challenge Checklist

- [ ] Fork substantial repo (1000+ stars)
- [ ] New programming language (GDScript)
- [ ] Understand existing architecture
- [ ] Non-trivial feature addition
- [ ] Production-ready quality
- [ ] Clear commit history
- [ ] README documentation
- [ ] Architecture explanation
- [ ] Setup instructions
- [ ] Demo video (5 minutes)
- [ ] Daily brainlift logs

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Dec 2025 | Initial PRD |
| 2.0 | Dec 2025 | Added: Model selection, asset handling, sprite detection, full AI capabilities, expanded workflows |

---

**End of Document**