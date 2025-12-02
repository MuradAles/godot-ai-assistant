# AI Game Builder - Task Tracker
## "Lovable for Godot"

**Project Start Date:** _______________  
**Target Completion:** 7 Days  
**Current Day:** _______________

---

## Progress Overview

| Day | Focus | Status |
|-----|-------|--------|
| Day 1 | Setup & Foundation | ⬜ Not Started |
| Day 2 | API Integration | ⬜ Not Started |
| Day 3 | Script Generation | ⬜ Not Started |
| Day 4 | Scene Generation | ⬜ Not Started |
| Day 5 | Memory Bank & Assets | ⬜ Not Started |
| Day 6 | Polish & Testing | ⬜ Not Started |
| Day 7 | Documentation & Demo | ⬜ Not Started |

**Status Key:** ⬜ Not Started | 🟡 In Progress | ✅ Complete | ❌ Blocked

---

## Pre-Development Setup

### Environment Setup
- [ ] Install Godot 4.5.1 (standard version, NOT .NET)
- [ ] Create GitHub account (if needed)
- [ ] Get Claude API key from console.anthropic.com
- [ ] Get OpenAI API key from platform.openai.com (optional)
- [ ] Install code editor (VS Code, or use Godot's built-in)
- [ ] Install Git

### Repository Setup
- [ ] Fork Godot Engine: github.com/godotengine/godot
- [ ] Clone fork to local machine
- [ ] Create new branch for plugin development
- [ ] Test that Godot project opens correctly

---

## Day 1: Setup & Foundation

### 1.1 Plugin Skeleton
- [ ] Create folder: `addons/ai_game_builder/`
- [ ] Create `plugin.cfg` with metadata
- [ ] Create `plugin.gd` main entry point
- [ ] Add `@tool` annotation
- [ ] Implement `_enter_tree()` function
- [ ] Implement `_exit_tree()` function
- [ ] Test: Plugin appears in Project Settings → Plugins
- [ ] Test: Plugin can be enabled/disabled

### 1.2 Basic UI Panel
- [ ] Create `ui/` folder
- [ ] Create `chat_panel.tscn` (visual layout)
- [ ] Create `chat_panel.gd` (logic)
- [ ] Add VBoxContainer for layout
- [ ] Add ScrollContainer for messages
- [ ] Add TextEdit for input
- [ ] Add Button for send
- [ ] Register panel with `add_control_to_bottom_panel()`
- [ ] Test: Panel appears in bottom dock
- [ ] Test: Can type in input field
- [ ] Test: Send button is clickable

### 1.3 Learn GDScript Basics
- [ ] Understand `var` declarations
- [ ] Understand `func` definitions
- [ ] Understand `extends` keyword
- [ ] Understand `@tool` annotation
- [ ] Understand `@onready` annotation
- [ ] Understand `signal` system
- [ ] Understand `preload()` vs `load()`
- [ ] Write test script that prints to console

### 1.4 Documentation
- [ ] Create brainlift log for Day 1
- [ ] Document setup process
- [ ] Note any issues encountered
- [ ] List AI prompts used for learning

### Day 1 Checklist
- [ ] Plugin skeleton complete
- [ ] Basic UI visible in editor
- [ ] Can interact with UI elements
- [ ] Brainlift log written
- [ ] Code committed to Git

---

## Day 2: API Integration

### 2.1 API Client Base
- [ ] Create `api/` folder
- [ ] Create `ai_client.gd` base class
- [ ] Add HTTPRequest node handling
- [ ] Implement request queue system
- [ ] Add error handling for network failures
- [ ] Add timeout handling

### 2.2 Claude Provider
- [ ] Create `api/claude_provider.gd`
- [ ] Implement Anthropic API endpoint
- [ ] Add proper headers (x-api-key, anthropic-version)
- [ ] Format request body correctly
- [ ] Parse response JSON
- [ ] Extract text from response
- [ ] Handle API errors (rate limit, invalid key, etc.)
- [ ] Test: Successful API call returns response

### 2.3 OpenAI Provider
- [ ] Create `api/openai_provider.gd`
- [ ] Implement OpenAI API endpoint
- [ ] Add proper headers (Authorization: Bearer)
- [ ] Format request body correctly
- [ ] Parse response JSON
- [ ] Extract text from response
- [ ] Handle API errors
- [ ] Test: Successful API call returns response

### 2.4 Settings Dialog
- [ ] Create `ui/settings_dialog.tscn`
- [ ] Create `ui/settings_dialog.gd`
- [ ] Add Provider dropdown (Anthropic, OpenAI)
- [ ] Add Model dropdown (changes based on provider)
- [ ] Add API Key input (masked with secret=true)
- [ ] Add "Test Connection" button
- [ ] Add "Save" button
- [ ] Store settings in EditorSettings (secure)
- [ ] Load settings on plugin start
- [ ] Test: Settings persist after restart

### 2.5 Model Selection
- [ ] Claude Opus 4.5 option works
- [ ] Claude Sonnet 4.5 option works
- [ ] GPT-5 option works
- [ ] GPT-4o option works
- [ ] Model selection persists
- [ ] Switching models works mid-session

### 2.6 Connect UI to API
- [ ] Send button triggers API call
- [ ] User message sent to selected provider
- [ ] Response displayed in chat panel
- [ ] Loading indicator while waiting
- [ ] Error messages display properly

### 2.7 Documentation
- [ ] Create brainlift log for Day 2
- [ ] Document API integration approach
- [ ] Note any issues with providers
- [ ] List AI prompts used

### Day 2 Checklist
- [ ] Claude API working
- [ ] OpenAI API working
- [ ] Settings dialog complete
- [ ] Model selection working
- [ ] Chat sends/receives messages
- [ ] Brainlift log written
- [ ] Code committed to Git

---

## Day 3: Script Generation

### 3.1 Response Parser
- [ ] Create `api/response_parser.gd`
- [ ] Define response format (actions, messages)
- [ ] Parse "create script" actions
- [ ] Parse "modify script" actions
- [ ] Extract code blocks from response
- [ ] Handle malformed responses gracefully

### 3.2 Script Generator
- [ ] Create `generators/` folder
- [ ] Create `generators/script_generator.gd`
- [ ] Implement file writing with FileAccess
- [ ] Save scripts to `res://scripts/` folder
- [ ] Create folder if doesn't exist
- [ ] Call `EditorInterface.get_resource_filesystem().scan()`
- [ ] Test: Script file appears in FileSystem dock

### 3.3 Code Validator
- [ ] Create `generators/code_validator.gd`
- [ ] Write code to temp file
- [ ] Attempt to load as script
- [ ] Check for syntax errors
- [ ] Return success/failure with error message
- [ ] Add safety check for dangerous operations

### 3.4 System Prompt
- [ ] Create `prompts/` folder
- [ ] Create `prompts/system_prompt.md`
- [ ] Define AI role (Godot expert)
- [ ] Add GDScript syntax rules
- [ ] Add Godot 4.x conventions
- [ ] Add response format instructions
- [ ] Add node type knowledge
- [ ] Test: AI generates valid GDScript

### 3.5 First Working Generation
- [ ] User says "create a player"
- [ ] AI generates CharacterBody2D script
- [ ] Script includes movement code
- [ ] Script includes jump code
- [ ] Script saved to res://scripts/player.gd
- [ ] Script is valid (no syntax errors)
- [ ] User can attach to node and test

### 3.6 Test Various Generations
- [ ] "Create enemy that follows player"
- [ ] "Create coin that can be collected"
- [ ] "Create moving platform"
- [ ] "Create simple UI with score"
- [ ] All generate valid code

### 3.7 Documentation
- [ ] Create brainlift log for Day 3
- [ ] Document script generation approach
- [ ] Note prompt engineering discoveries
- [ ] List example prompts that work well

### Day 3 Checklist
- [ ] Response parser working
- [ ] Script generator saves files
- [ ] Code validation prevents errors
- [ ] System prompt produces good output
- [ ] Multiple script types generate correctly
- [ ] Brainlift log written
- [ ] Code committed to Git

---

## Day 4: Scene Generation

### 4.1 Node Builder
- [ ] Create `generators/node_builder.gd`
- [ ] Create nodes programmatically (Node.new())
- [ ] Set node names
- [ ] Set node properties
- [ ] Add child nodes
- [ ] Set owner for saving (critical!)
- [ ] Test: Can build node hierarchy in memory

### 4.2 Scene Generator
- [ ] Create `generators/scene_generator.gd`
- [ ] Use PackedScene.pack() to create scene
- [ ] Use ResourceSaver.save() to write file
- [ ] Save scenes to `res://scenes/` folder
- [ ] Attach scripts to nodes
- [ ] Call filesystem scan after saving
- [ ] Test: Scene file appears in FileSystem

### 4.3 Common Scene Templates
- [ ] Player scene (CharacterBody2D + Sprite + Collision)
- [ ] Enemy scene (CharacterBody2D + Sprite + Collision)
- [ ] Coin scene (Area2D + Sprite + Collision)
- [ ] Platform scene (StaticBody2D + Sprite + Collision)
- [ ] Level scene (Node2D with instances)

### 4.4 Update Response Parser
- [ ] Parse "create scene" actions
- [ ] Parse node hierarchy from response
- [ ] Parse property assignments
- [ ] Parse script attachments

### 4.5 Full Generation Flow
- [ ] User: "Create a player that can move and jump"
- [ ] AI generates scene structure
- [ ] Scene generator creates Player.tscn
- [ ] Script generator creates player.gd
- [ ] Script attached to scene
- [ ] Both files appear in FileSystem
- [ ] User can open scene and press F6 to test

### 4.6 Test Scene Generation
- [ ] Generate player scene
- [ ] Generate enemy scene
- [ ] Generate collectible scene
- [ ] Generate level with multiple elements
- [ ] All scenes open without errors

### 4.7 Documentation
- [ ] Create brainlift log for Day 4
- [ ] Document scene generation approach
- [ ] Note node hierarchy patterns
- [ ] List working scene templates

### Day 4 Checklist
- [ ] Node builder creates hierarchies
- [ ] Scene generator saves .tscn files
- [ ] Scripts attach to scenes correctly
- [ ] Common templates work
- [ ] Full generation flow complete
- [ ] Brainlift log written
- [ ] Code committed to Git

---

## Day 5: Memory Bank & Assets

### 5.1 Memory Bank Core
- [ ] Create `memory/` folder
- [ ] Create `memory/memory_bank.gd`
- [ ] Define JSON schema for project data
- [ ] Implement save to `user://ai_game_builder/`
- [ ] Implement load on plugin start
- [ ] Create folder if doesn't exist
- [ ] Handle missing/corrupt file gracefully

### 5.2 Element Tracking
- [ ] Track when element created
- [ ] Track scene path
- [ ] Track script path
- [ ] Track node type
- [ ] Track properties (speed, jump, etc.)
- [ ] Track capabilities (move, jump, etc.)
- [ ] Update memory after each generation

### 5.3 Context Builder
- [ ] Create `memory/context_builder.gd`
- [ ] Build context string from memory
- [ ] Include project name
- [ ] Include existing elements summary
- [ ] Include recent actions
- [ ] Add to system prompt before API call
- [ ] Test: AI knows about existing elements

### 5.4 Iteration Support
- [ ] User: "make player jump higher"
- [ ] AI finds player in memory
- [ ] AI identifies jump_velocity property
- [ ] AI modifies the correct value
- [ ] Script file updated
- [ ] Memory bank updated
- [ ] Test: Multiple iterations work

### 5.5 Asset Analyzer
- [ ] Create `assets/asset_analyzer.gd`
- [ ] Load image and get dimensions
- [ ] Calculate possible frame sizes (16, 32, 48, 64)
- [ ] Check which sizes divide evenly
- [ ] Return best guess with alternatives
- [ ] Test: Correctly analyzes sprite sheets

### 5.6 Asset Integration Flow
- [ ] User: "use hero.png for player"
- [ ] Plugin finds res://assets/hero.png
- [ ] Analyzer detects dimensions
- [ ] AI asks user to confirm frame size
- [ ] User confirms or corrects
- [ ] AI sets up Sprite2D with correct hframes/vframes
- [ ] Memory bank tracks sprite info

### 5.7 Animation Setup
- [ ] Create `assets/animation_setup.gd`
- [ ] User: "first 4 frames walk, next 2 jump"
- [ ] Parse animation definitions
- [ ] Create AnimatedSprite2D or AnimationPlayer
- [ ] Set frame ranges, FPS, looping
- [ ] Connect animations to player states
- [ ] Test: Animations play correctly

### 5.8 Documentation
- [ ] Create brainlift log for Day 5
- [ ] Document memory bank design
- [ ] Document asset detection approach
- [ ] Note JSON schema decisions

### Day 5 Checklist
- [ ] Memory bank saves/loads
- [ ] Elements tracked correctly
- [ ] Context injected into prompts
- [ ] Iteration ("jump higher") works
- [ ] Asset analyzer detects dimensions
- [ ] Sprite sheets configured correctly
- [ ] Animations set up from user description
- [ ] Brainlift log written
- [ ] Code committed to Git

---

## Day 6: Polish & Testing

### 6.1 Error Handling
- [ ] API key missing → clear message
- [ ] API key invalid → clear message
- [ ] Network error → retry option
- [ ] Rate limited → wait and retry
- [ ] Invalid AI response → graceful recovery
- [ ] File write error → user notification
- [ ] No errors crash the plugin

### 6.2 UI Improvements
- [ ] Loading spinner while AI thinking
- [ ] Disable send button while processing
- [ ] Format AI responses nicely
- [ ] Syntax highlight code blocks (if possible)
- [ ] Show file paths as clickable (if possible)
- [ ] Settings button in panel
- [ ] Clear chat button

### 6.3 User Feedback
- [ ] Success messages (✓ Created...)
- [ ] Warning messages (⚠️ Using placeholder...)
- [ ] Error messages (❌ Failed to...)
- [ ] Next step suggestions
- [ ] How to test instructions (Press F5...)

### 6.4 Edge Cases
- [ ] Empty message sent
- [ ] Very long message sent
- [ ] Special characters in names
- [ ] File already exists
- [ ] Invalid asset path
- [ ] No assets in project
- [ ] Corrupt memory bank

### 6.5 Testing Checklist
- [ ] Fresh install works
- [ ] Plugin enable/disable works
- [ ] Settings persist correctly
- [ ] Claude API end-to-end works
- [ ] OpenAI API end-to-end works
- [ ] Simple player creation works
- [ ] Complex multi-element creation works
- [ ] Iteration/modification works
- [ ] Sprite sheet detection works
- [ ] Animation setup works
- [ ] Memory persists restart

### 6.6 Performance
- [ ] Plugin doesn't slow editor
- [ ] Large responses handled
- [ ] Memory bank doesn't grow too large
- [ ] No memory leaks (check _exit_tree cleanup)

### 6.7 Documentation
- [ ] Create brainlift log for Day 6
- [ ] Document bugs found and fixed
- [ ] Note performance considerations
- [ ] List remaining known issues

### Day 6 Checklist
- [ ] All error cases handled
- [ ] UI polished and clear
- [ ] User feedback helpful
- [ ] Edge cases don't crash
- [ ] All tests pass
- [ ] Performance acceptable
- [ ] Brainlift log written
- [ ] Code committed to Git

---

## Day 7: Documentation & Demo

### 7.1 README.md
- [ ] Project title and description
- [ ] Screenshot/GIF of plugin in action
- [ ] What repo was forked (Godot Engine)
- [ ] What was built (AI Game Builder)
- [ ] Features list
- [ ] Requirements (Godot 4.5, API key)
- [ ] Installation steps
- [ ] Configuration steps
- [ ] Usage examples
- [ ] Technical architecture overview
- [ ] Contributing guidelines
- [ ] License information

### 7.2 Architecture Documentation
- [ ] System diagram
- [ ] Component descriptions
- [ ] Data flow explanation
- [ ] File structure
- [ ] Key design decisions
- [ ] Memory bank schema

### 7.3 Setup Guide
- [ ] Step-by-step installation
- [ ] Screenshots for each step
- [ ] API key setup instructions
- [ ] Troubleshooting common issues

### 7.4 Demo Video (5 minutes)
- [ ] Introduction (who you are, what this is)
- [ ] What repo was forked and why
- [ ] Show the plugin in Godot
- [ ] Demo: Create player from chat
- [ ] Demo: Add sprite sheet
- [ ] Demo: Iterate on game element
- [ ] Demo: Build simple game
- [ ] Technical architecture walkthrough
- [ ] How AI accelerated development
- [ ] Reflection on learning GDScript
- [ ] Video exported and uploaded

### 7.5 Brainlift Compilation
- [ ] Compile all daily logs
- [ ] Add summary of journey
- [ ] Highlight key learnings
- [ ] List all AI prompts used
- [ ] Reflect on challenges overcome

### 7.6 Final Submission
- [ ] All code committed and pushed
- [ ] README complete
- [ ] Architecture docs complete
- [ ] Brainlift logs complete
- [ ] Demo video uploaded
- [ ] Repo URL ready to share
- [ ] Final test on clean clone

### Day 7 Checklist
- [ ] README.md complete
- [ ] Architecture documented
- [ ] Setup guide complete
- [ ] Demo video recorded
- [ ] Demo video uploaded
- [ ] Brainlift compiled
- [ ] Final commit pushed
- [ ] Submission ready

---

## Challenge Deliverables Checklist

### Required Deliverables
- [ ] Forked GitHub repository (Godot Engine)
- [ ] Clear commit history
- [ ] Clean project structure
- [ ] Working software (deployed or runnable)
- [ ] Core features work end-to-end

### README Must Include
- [ ] Original repo link
- [ ] What you built
- [ ] Architecture overview
- [ ] Setup + run steps
- [ ] Technical decisions explained

### Brainlift Documentation
- [ ] Daily logs
- [ ] AI prompts used
- [ ] Learning breakthroughs
- [ ] Technical decisions
- [ ] Challenges & solutions

### Demo Video (5 min)
- [ ] Project introduction
- [ ] Forked repo explanation
- [ ] Feature walkthrough
- [ ] Technical architecture
- [ ] AI acceleration examples
- [ ] Learning reflection

---

## Quick Reference

### Key Paths
```
Plugin:      addons/ai_game_builder/
Scenes:      res://scenes/
Scripts:     res://scripts/
Assets:      res://assets/
Memory:      user://ai_game_builder/
```

### Key Files
```
plugin.cfg           - Plugin metadata
plugin.gd            - Main entry point
chat_panel.gd        - UI logic
ai_client.gd         - API calls
memory_bank.gd       - Context storage
script_generator.gd  - Create .gd files
scene_generator.gd   - Create .tscn files
asset_analyzer.gd    - Detect sprites
```

### Commands to Remember
```gdscript
# Refresh filesystem after creating files
EditorInterface.get_resource_filesystem().scan()

# Add panel to bottom dock
add_control_to_bottom_panel(panel, "AI Builder")

# Store settings securely
EditorInterface.get_editor_settings().set_setting("ai/key", value)

# Set owner for scene saving (CRITICAL!)
child_node.owner = root_node
```

---

## Notes & Blockers

### Current Blockers
_Write any blockers here:_
1. 
2. 
3. 

### Ideas for Later
_Write ideas for post-MVP here:_
1. 
2. 
3. 

### Questions to Research
_Write questions to look up here:_
1. 
2. 
3. 

---

**Last Updated:** _______________

**Current Status:** _______________