# ARCHITECTURE.md — Tofie Play & Learn Adventures

> Godot 4.6 educational game for ages 2–7. 30 minigames, 19 animal-food pairs.
> Last updated: 2026-03-14 (V141)

---

## 1. Project Overview

| Property | Value |
|----------|-------|
| Engine | Godot 4.6 (GDScript) |
| Target | Android (arm64-v8a), landscape 1280×720 |
| Audience | Children 2–7 years old (Toddler 2-4, Preschool 4-7) |
| Content | 30 minigames + 19 animal-food pairs |
| Economy | Stars (1 correct match = 1 star) |
| Languages | en, uk, fr, es |
| Save | Encrypted binary (`user://save.save`) |

### Design Principles (Pediatric UX)

- **Hick's Law**: Max 3 choices per screen (Play, Collection, Playground)
- **Fitts's Law**: Big touch targets (120×120 buttons, 80px snap radius)
- **Encouragement model**: No negative feedback text, gentle head-shake on errors
- **Progressive disclosure**: Parent Zone behind parental gate (3-finger 2-second hold, LAW 27)
- **No text on game screen**: Visual-only matching for pre-readers

---

## 2. Navigation Flow

```
splash_screen.tscn (1.5s branded intro)
        │
        ▼
  main_menu.tscn ◄──────────────────────┐
        │                                │
   ┌────┼────────────┬───────────┐       │
   │    │            │           │       │
 [▶ Play]  [★ Collection]  [♥ Playground]│
   │    │            │           │       │
   │    │  sticker_book.tscn  nursery.tscn
   │    │            │           │       │
   │   [⚙ Parent]   [Back] ─────┘───────┘
   │    │                                │
   │  parental_gate → parent_zone.tscn   │
   │                    │                │
   │                  [Back] ────────────┘
   │                                     │
   ▼                                     │
  food_game.tscn ◄─── [Resume]          │
        │                  ▲             │
   [focus lost]       pause_menu         │
        │              │                 │
        └──► [Pause] ──┤                 │
                       │                 │
                  [Quit to Menu] ────────┘
                                         │
   [game_won / mini_game_finished]       │
        │                                │
   confetti + 3.0s delay ───────────────┘
```

---

## 3. Folder Structure

```
game/
├── project.godot
├── default_bus_layout.tres       # Audio buses: Master → SFX
├── export_presets.cfg            # Android export
├── scenes/
│   ├── main/                    # food_game.tscn, nursery.tscn
│   ├── ui/                      # main_menu, pause_menu, sticker_book, parent_zone, parental_gate, splash_screen
│   ├── animals/                 # 19× Animal.tscn (Sprite2D + texture)
│   ├── food/                    # 19× Food.tscn (Sprite2D + texture)
│   ├── entities/                # floating_cloud.tscn
│   ├── autoloads/               # vfx_manager.tscn
│   └── vfx/                     # confetti_particles.tscn
├── scripts/
│   ├── food_game.gd             # Game orchestrator — signals, UI, tweens, bg
│   ├── game_data.gd             # Static data: 19 pairs, constants, lookups
│   ├── round_manager.gd         # Rounds, spawning, matching, difficulty, pooling
│   ├── drag_controller.gd       # Mouse/touch/keyboard input, drag trail
│   ├── main_menu.gd             # Home Hub: Play + Collection + Playground + Parent
│   ├── pause_menu.gd            # Pause overlay (resume / quit)
│   ├── sticker_book.gd          # Collection grid (unlocked/locked animals)
│   ├── nursery.gd               # Playground — tap animals to interact
│   ├── parent_zone.gd           # Parent Zone — stats, settings, export/import
│   ├── parental_gate.gd         # COPPA cognitive gate (math question)
│   ├── splash_screen.gd         # Branded studio intro animation
│   ├── tutorial_overlay.gd      # FTUE animated hand overlay
│   ├── floating_cloud.gd        # Decorative drifting cloud
│   ├── mini_game_launcher.gd    # Integration bridge for parent app
│   ├── components/
│   │   ├── hint_system.gd       # Anti-churn: idle timer + error-based hints
│   │   ├── save_transfer.gd     # Clipboard-based save export/import
│   │   ├── ui_popper.gd         # Elastic pop-in/pop-out animation
│   │   ├── splash_track.gd     # Loading track with mascot, stars, progress bubble
│   │   └── splash_deco.gd      # SVG-like decorations for splash (gamepad, planet, lollipops)
│   ├── autoloads/
│   │   ├── theme_manager.gd     # Global GUI theme (Nunito Bold font)
│   │   ├── scene_manager.gd     # Fade-to-black scene transitions
│   │   ├── progress_manager.gd  # Stars, animals, records, achievements, hints
│   │   ├── reward_manager.gd   # Daily rewards, login streaks, quest data
│   │   ├── settings_manager.gd  # Volume, language, backgrounds, save coordination
│   │   ├── analytics_manager.gd # Telemetry stub (console prints)
│   │   ├── audio_manager.gd     # Polyphonic 8-pool SFX player
│   │   ├── haptics_manager.gd   # Vibration feedback (mobile)
│   │   └── vfx_manager.gd       # Particle spawners (confetti, match, tap)
│   └── tools/
│       └── convert_to_animated.gd
├── tests/
│   ├── run_all_tests.gd         # Headless CLI runner (6 suites)
│   ├── test_law_compliance.gd   # Static code analysis (30 laws, 48 tests)
│   ├── test_star_formula.gd     # Star formula unit tests
│   ├── test_base_contract.gd    # BaseMiniGame contract tests
│   ├── test_catalog_integrity.gd # GameCatalog validation
│   ├── test_game_data.gd
│   └── test_round_manager.gd
└── assets/
    ├── sprites/{animals,food}/  # 512×512 PNGs
    ├── backgrounds/             # Background images
    ├── branding/                # tofie_logo.png (splash only)
    ├── audio/{sfx,bgm}/        # WAV files
    ├── fonts/                   # Nunito-Bold.ttf (OFL)
    ├── shaders/                 # 9 canvas_item shaders (candy_grain, bg_animated, animal_alive, card_shimmer, circle_wipe, bubble_wobble, sway, bg_parallax_layer, silhouette)
    ├── icons/                   # App icon
    └── translations/            # translations.csv (4 languages)
```

**Rules:**
- Scenes in `scenes/`, scripts in `scripts/`, assets in `assets/`
- PascalCase for `.tscn` and sprite PNGs, snake_case for `.gd`
- No files in project root — use the correct subdirectory

---

## 4. Script Architecture

### 4.1 Autoloads (9)

| Autoload | Script | Purpose |
|----------|--------|---------|
| `ThemeManager` | `autoloads/theme_manager.gd` | Global GUI theme (Nunito Bold) |
| `SceneManager` | `autoloads/scene_manager.gd` | Fade-to-black transitions via `call_deferred` |
| `ProgressManager` | `autoloads/progress_manager.gd` | Stars, animals, records, achievements, hints |
| `RewardManager` | `autoloads/reward_manager.gd` | Daily rewards, login streaks, quest data |
| `SettingsManager` | `autoloads/settings_manager.gd` | Volume, language, backgrounds, save coordination |
| `AnalyticsManager` | `autoloads/analytics_manager.gd` | Telemetry stub (console prints in debug) |
| `AudioManager` | `autoloads/audio_manager.gd` | String-keyed SFX: `play_sfx("success", pitch)` |
| `HapticsManager` | `autoloads/haptics_manager.gd` | `vibrate_success()`, `vibrate_light()` |
| `VFXManager` | `autoloads/vfx_manager.tscn` | `spawn_confetti()`, `spawn_match_particles()`, `spawn_tap_stars()` |

### 4.2 Core Game Logic (4 scripts)

| Script | Responsibility | Allowed to access |
|--------|---------------|-------------------|
| `game_data.gd` | Static data, constants, translation keys, lookup functions | Nothing (pure data, `class_name GameData`) |
| `round_manager.gd` | Round lifecycle, spawning, matching, difficulty, object pooling | `GameData` |
| `drag_controller.gd` | Mouse/touch/keyboard input, drag state, highlight, trail | `RoundManager` (read-only state) |
| `food_game.gd` | Scene orchestrator, UI, tweens, particles, bg shader, hints | Everything (via signals) |

### 4.3 UI Screens (6 scripts)

| Script | Scene | Purpose |
|--------|-------|---------|
| `main_menu.gd` | `ui/main_menu.tscn` | Home Hub: animated title, Play/Collection/Playground, parental gate |
| `pause_menu.gd` | `ui/pause_menu.tscn` | Pause overlay (Resume / Quit) |
| `sticker_book.gd` | `ui/sticker_book.tscn` | Animal collection grid (sway shader on unlocked) |
| `parent_zone.gd` | `ui/parent_zone.tscn` | Stats dashboard + settings + export/import |
| `parental_gate.gd` | `ui/parental_gate.tscn` | Parental gate (3-finger 2-second hold, LAW 27) |
| `splash_screen.gd` | `ui/splash_screen.tscn` | Branded studio intro with particles |

### 4.4 Components (19 scripts)

| Script | Purpose |
|--------|---------|
| `hint_system.gd` | Idle timer (5s) + error-count hints for stuck players |
| `save_transfer.gd` | Clipboard-based save export/import (Base64 JSON) |
| `ui_popper.gd` | Elastic scale pop-in/pop-out for UI elements |
| `splash_track.gd` | Loading track: mascot, stars, progress bubble (`_draw()`) |
| `splash_deco.gd` | SVG-like decorations: gamepad, planet, lollipops (`_draw()`) |
| `dev_console.gd` | Debug-only dev tools (add stars, unlock all, reset) |
| `tutorial_system.gd` | Step-based FTUE controller |
| `tutorial_hand.gd` | Animated tutorial hand pointer |
| `juicy_effects.gd` | Squish, pulse, shake, combo effects |
| `universal_drag.gd` | Shared drag engine for all drag-based minigames |
| `session_timer.gd` | LAW 26 session wellness timer (20min default) |
| `icon_draw.gd` | Code-drawn icon system (all game icons via `_draw()`) |
| `shape_item.gd` | Shape item for shape-matching games |
| `bubble.gd` | Bubble component for bubble-pop minigame |
| `musician.gd` | Musician component for music games |
| `counting_item.gd` | Counting item for number games |
| `slot_item.gd` | Slot/drop target for sorting games |
| `exit_confirm.gd` | Exit confirmation overlay |
| `memory_card.gd` | Card component for memory card game |

### 4.5 Communication Rules

- Scripts communicate via **signals**, not direct method calls
- `game_data.gd` uses `class_name GameData` — no autoload needed
- `round_manager.gd` and `drag_controller.gd` receive dependencies via constructor
- UI-touching code stays ONLY in scene orchestrators (`food_game.gd`, screen scripts)
- All UI text must go through `tr()` with keys from `translations.csv`

---

## 5. GDScript Coding Standards

### 5.1 Type Hints (REQUIRED)

```gdscript
# GOOD
var current_round_animals: Array[Node2D] = []
func _find_food(name: String) -> String:

# BAD
var current_round_animals = []
func _find_food(name):
```

### 5.2 Constants Over Magic Numbers

```gdscript
const ANIMAL_Y_FACTOR: float = 0.3
const MAX_ROUNDS: int = 10
```

### 5.3 Error Handling

- `push_warning()` for recoverable issues
- `push_error()` for programming errors
- Never silently return — always log why

### 5.4 Memory Management

- Always `erase()` dictionary entries BEFORE `queue_free()`
- Clear tracking collections in round transitions
- Object pooling: `recycle_animal()` / `recycle_food()` instead of `queue_free()` during gameplay

### 5.5 Bounds Checking

- Always `is_empty()` before accessing `[0]`
- Validate array access from external logic

### 5.6 Dynamic Screen Coordinates

```gdscript
var size: Vector2 = scene_root.get_viewport_rect().size
var x: float = size.x * (float(index) + 1.0) / (float(count) + 1.0)
```

Never hardcode positions.

### 5.7 Programmatic Animations

- Use `create_tween()`, NOT `AnimationPlayer` for procedural effects
- Always `is_instance_valid()` in tween callbacks before `queue_free()`
- Kill existing tweens before starting new ones on the same property
- Capture `base_scale` before tweening

### 5.8 Node Identity via Metadata

- Animal identity: `animal.name = data.name` (unique per GameData entry)
- Food identity: `food.set_meta("food_type", name)` (avoid name collisions)

### 5.9 Script Size Limit

- Utility scripts: ~120 lines. Minigames: ~300 lines soft limit (median ~400, BaseMiniGame 631)
- If 3+ unrelated concerns → split

---

## 6. Naming Conventions

| What | Convention | Example |
|------|-----------|---------|
| Scene files (.tscn) | PascalCase | `Bunny.tscn` |
| Script files (.gd) | snake_case | `round_manager.gd` |
| Class names | PascalCase | `class_name RoundManager` |
| Variables | snake_case | `current_round_animals` |
| Constants | UPPER_SNAKE_CASE | `MAX_ROUNDS` |
| Sprite PNGs | PascalCase | `Bunny.png` |
| Signal names | snake_case | `game_won` |

---

## 7. Adding New Content

### Adding an animal-food pair:

1. Add PNGs to `assets/sprites/animals/` and `assets/sprites/food/`
2. Create `.tscn` in `scenes/animals/` and `scenes/food/`
3. Add one line to `GameData.ANIMALS_AND_FOOD`:
   ```gdscript
   {"name": "Tiger", "animal_scene": preload("res://scenes/animals/Tiger.tscn"), "food_scene": preload("res://scenes/food/Steak.tscn")},
   ```
4. No other files need modification

**RULE:** Every animal MUST have a unique food_scene. Food names must NOT collide with animal names.

### Current 19 pairings:

Bunny→Carrot, Dog→Bone, Bear→Honey, Monkey→Banana, Cat→Fish, Chicken→Wheat, Cow→Grass, Crocodile→Drumstick, Frog→Mosquito, Deer→Leaf, Elephant→Watermelon, Horse→Hay, Lion→Meat, Penguin→Shrimp, Panda→Bamboo, Goat→Cabbage, Mouse→Cheese, Squirrel→Walnut, Hedgehog→Apple

---

## 8. Key Systems

### 8.1 Dynamic Difficulty

| Rounds played | Pairs on screen |
|--------------|----------------|
| 0–2 | 3 |
| 3–6 | 4 |
| 7+ | 5 |

Dynamic sprite scale: 0.6→0.45→0.35 for animals, 0.3→0.3→0.25 for food.

### 8.2 Object Pooling

`round_manager.gd` pools Sprite2D nodes:
- `_get_or_create(pool, scene)` — reuse from pool or instantiate
- `recycle_animal()` / `recycle_food()` — reset + return to pool
- Prevents GC stutters on mobile

### 8.3 Combo System

- `current_combo` increments on correct match, resets on error/miss
- Combo ≥ 3: background brightens, SFX pitch increases
- No text feedback — visual-only for children

### 8.4 Hint System

- Idle timer: 5s without interaction → pulse the correct animal
- Error threshold: 3+ errors in round → auto-hint
- Manual hints: `HintButton` with limited uses (`inventory_hints`)

### 8.5 Day/Night Cycle

- System clock: 7PM–6:59AM → `Color(0.5, 0.5, 0.7)` tint
- Checked once at scene start

### 8.6 Scene Transitions

- Fade-to-black (0.2s out → change → 0.2s in)
- Input locked via `MOUSE_FILTER_STOP` during transition
- Node-bound tweens auto-kill on scene free

### 8.7 Encrypted Save

- `FileAccess.open_encrypted_with_pass()` + `store_var()` / `get_var()`
- Key: Random encryption key (COPPA-safe — no hardware IDs, no `OS.get_unique_id()`)
- Stored: stars, records, unlocks, settings, achievements, hint inventory

### 8.8 Audio

- Polyphonic 8-pool via `AudioManager.play_sfx("success", pitch)`
- BGM with ducking: `-12dB` on match, recover over 1.5s
- Audio buses: Master → SFX

---

## 9. Integration (Parent App)

```gdscript
var instance: Node2D = MiniGameLauncher.launch_food_game(self)
instance.finished.connect(_on_food_game_done)

func _on_food_game_done(stats: Dictionary) -> void:
    # stats keys: time_sec, errors, rounds_played, earned_stars
    pass
```

| Property | Value |
|----------|-------|
| Entry point | `MiniGameLauncher.launch_food_game(parent: Node) -> Node2D` |
| Public signal | `finished(stats: Dictionary)` |
| Auto-cleanup | `queue_free()` after 2.0s |
| Dependencies | None (`class_name`, no autoload) |

---

## 10. Mobile Specifics

- **Focus loss**: `NOTIFICATION_WM_WINDOW_FOCUS_OUT` → show pause menu
- **Multi-touch safety**: Only primary finger (index 0) for drag
- **Haptics**: 50ms success, 30ms light tap
- **Safe area**: 48px min inset from edges (notch protection)
- **Touch emulation**: Mouse↔Touch bidirectional
- **Back button**: `ui_cancel` → context-appropriate action per screen
- **VRAM compression**: ETC2/ASTC enabled
- **Orientation**: Landscape locked
- **Resolution**: 1280×720, stretch `canvas_items`, aspect `expand`

---

## 11. Verification Checklist

- [ ] Type hints on ALL declarations
- [ ] No magic numbers — use `const`
- [ ] Files in correct directory (PascalCase scenes, snake_case scripts)
- [ ] `erase()` before `queue_free()`
- [ ] `is_empty()` before `[0]`
- [ ] `push_warning()` on all early returns
- [ ] `is_instance_valid()` in tween callbacks
- [ ] Input locked during animations, unlocked in `finished`
- [ ] All UI text uses `tr()` from `translations.csv`
- [ ] New strings added to all 4 languages
- [ ] Scripts under ~120 lines
- [ ] Headless tests pass: `godot --headless --path game/ -s tests/run_all_tests.gd`

---

## 12. Android Export

| Property | Value |
|----------|-------|
| Package ID | `com.kosgames.animalpuzzle` |
| Architecture | arm64-v8a |
| App icon | `res://assets/icons/icon.png` |
| Exclude | `tests/*` |

---

## 13. Localization

- File: `assets/translations/translations.csv` (4 languages: en, uk, fr, es)
- All UI text via `tr("KEY")`, translation keys in `UPPER_SNAKE_CASE`
- `GameData.TEXT_*` constants hold keys, orchestrator calls `tr()`
- Adding language: add column to CSV, no code changes
- Adding string: add row to CSV, use `tr("NEW_KEY")` in script

---

## 14. Security & Compliance

- Dev console gated behind `OS.is_debug_build()`
- Parental gate (COPPA) before Parent Zone
- Encrypted save with random encryption key (COPPA-safe, no hardware IDs)
- Zero network permissions
- Debug prints wrapped in `OS.is_debug_build()`
- Privacy policy: `game/PRIVACY_POLICY.md`

---

## 15. Design Laws & QA

- **GAME_DESIGN_LAWS.md**: 30 laws (LAW 1-30) mandatory for all minigames
- **QA_PROTOCOLS.md**: 10 code quality protocols for PR checklist
- **GAME_DESIGN_BIBLE.md**: 30 game specs with 12 axioms (A1-A12)
- Test runner: `godot --headless --path game/ -s tests/run_all_tests.gd`
- Law enforcement: `test_law_compliance.gd` — 48 static analysis tests (30 laws + 12 axioms + QA)
