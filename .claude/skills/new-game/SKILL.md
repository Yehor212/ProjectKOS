---
name: new-game
description: "Scaffold a new minigame: .gd script, .tscn scene, catalog entry, translations"
---

# New Game Scaffold

Create all required files for a new minigame.

## Required Information (ask user if not provided)
1. **Game ID** (snake_case): e.g. `emotion_mirror`
2. **Display name**: e.g. "Emotion Mirror"
3. **Skill developed**: e.g. "emotion recognition"
4. **Age group**: TODDLER / PRESCHOOL / ALL
5. **Mechanic**: TAP / DRAG / DRAW / MIX
6. **Number of rounds**: 3-5
7. **bg_theme**: meadow / forest / ocean / science / space / city / puzzle / music

## Files Created
1. `game/scripts/minigames/[game_id].gd` — extends BaseMiniGame, with all required overrides
2. `game/scenes/main/[game_id].tscn` — scene with script attached
3. Entry in `game_catalog.gd` GAMES array
4. Translation keys in `translations.csv` (4 languages, placeholder text)
5. Entry in GAME_DESIGN_BIBLE.md (template with axiom checklist)

## Template .gd structure
```gdscript
extends BaseMiniGame

const TOTAL_ROUNDS: int = 3
const SAFETY_TIMEOUT_SEC: float = 30.0
const BG_THEME: String = "meadow"

func _ready() -> void:
    super._ready()
    _start_safety_timeout()

func _start_round() -> void:
    super._start_round()
    _cleanup_round()
    # Round setup here

func _cleanup_round() -> void:
    # Clear temp data (A9 Round Hygiene)
    pass

func _finish() -> void:
    var stars := _calculate_stars(_errors)
    super._finish()

func get_tutorial_instruction() -> String:
    return tr("GAME_ID_TUTORIAL")

func get_tutorial_demo() -> Dictionary:
    return {}
```

## Post-scaffold
- Run /game-qa on the new file
- Verify compile
- Add to test coverage
