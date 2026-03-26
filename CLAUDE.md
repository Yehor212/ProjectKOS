# ProjectKOS — Tofie Play & Learn Adventures

## Stack

Godot 4.6.1 + GDScript + Android (arm64-v8a, landscape 1280x720)
Target audience: children 2-7 (Toddler 2-4, Preschool 4-7)
30 minigames + 19 animal-food pairs + 4 languages (en, uk, fr, es)

## Architecture

Read ARCHITECTURE.md before any code changes. It is the single source of truth.
`BaseMiniGame` = base class for ALL games. Every game extends it.
Autoloads: GameData, AudioManager, ProgressManager, SettingsManager, AnalyticsManager, HapticsManager, VFXManager, SceneManager

### Agent System (13 agents, all Opus 4.6)
BUILDERS: gameplay-architect, vector-animator, sound-designer, asset-pipeline, content-curator
GUARDIANS: law-enforcer, ux-guardian, i18n-guardian, performance-profiler
ADVISORS: logic-auditor, accessibility-advisor
VERIFIER: integration-tester
TEAM LEAD: release-manager

## 30 Game Design Laws

Read GAME_DESIGN_LAWS.md — 30 laws, violation = bug. Key laws:
- LAW 2: Minimum 3 choices per screen
- LAW 6: Progressive difficulty (every round harder than previous)
- LAW 7: Sprite fallback (never show empty screen)
- LAW 8: Standard star formula (Toddler: always 5, Preschool: clampi(5 - errors/2, 1, 5))
- LAW 13: Numeric safety (no division by zero, no array out of bounds)
- LAW 16: Centralized star formula (ONLY _calculate_stars(), no hardcoded values)
- LAW 17: Dictionary guard (always .has() or .get() before access)
- LAW 20: Await safety (is_instance_valid() after EVERY await)
- LAW 25: Color-blind safe (don't use color alone for information)
- LAW 27: Parental gate (3-finger 2-second hold)

## 12 Axioms (GAME_DESIGN_BIBLE.md)

Every game MUST satisfy ALL 12 axioms:
A1: Entry — player understands what to do WITHOUT text (animated hand shows first step)
A2: Exit — game ALWAYS ends (reachable win condition)
A3: Age split — Toddler and Preschool have DIFFERENT difficulty
A4: Progression — difficulty increases from round 1 to last
A5: Star formula — Toddler: ALWAYS 5. Preschool: standard formula
A6: Toddler errors — no penalty, "click" sound, gentle wobble
A7: Preschool errors — _errors += 1, "error" sound, vibration, smoke VFX
A8: Impossible states — game CANNOT hang (fallbacks for missing textures, empty arrays)
A9: Round hygiene — all temp data cleared between rounds
A10: Idle escalation — 3 levels: pulse -> stronger -> tutorial hand
A11: Scaffolding — Toddler: 2 errors -> show answer. Preschool: 3 errors -> show answer
A12: I18n — ALL text through tr(). No hardcoded strings

## Conventions

- GDScript: type hints on ALL functions (`func foo(x: int) -> void:`)
- Every early `return` MUST have `push_warning()` (QA #1)
- `snake_case` for variables/functions, `PascalCase` for classes/scenes
- Assets: `res://game/assets/` (textures, audio, sprites, fonts, shaders)
- Scenes: `res://game/scenes/` (animals, food, main, ui, vfx, components)
- Scripts: `res://game/scripts/` (per-game + autoloads + components)

## Enforcement

Hooks in `.claude/hooks/` enforce quality gates:
- `commit-gate.cjs` (PreToolUse Bash) — BLOCKS commit without postflight (HMAC)
- `fullcycle-flag.cjs` (UserPromptSubmit) — detects triggers, generates HMAC tokens
- `preflight-inject.cjs` (UserPromptSubmit) — injects 11-check self-reflection protocol

PRE-FLIGHT: `<thinking>` block with 11 checks before ANY code change.
Reasoning types: CHECK 1=DEDUCTION, CHECK 3=ABDUCTION, CHECK 4=INDUCTION.
POST-FLIGHT: 30-law compliance + 12 axiom checks + evidence.

### Skills (invocable via /command)
- `/game-qa [file]` — Quick 30 Laws + 12 Axioms check
- `/postflight` — Automated POST-FLIGHT with evidence
- `/new-game` — Scaffold new minigame
- `/add-animal` — Add animal-food pair

### New Hooks
- PostToolUse: post-edit-validator (advisory warnings for .gd)
- PostToolUse: scene-validator (blocks GPUParticles2D in .tscn)
- Stop: stop-guard (blocks stop without postflight if code was changed)

## Safety

- COPPA: NO personal data, NO third-party tracking
- Parental gate: 3-finger 2-second hold (LAW 27)
- Session limits: SettingsManager.session_limit_minutes
- Encrypted save: `user://save.save`

## Key Anti-Patterns (NEVER do)

- Access array without bounds check: `pool[0]` -> use `if pool.size() > 0:`
- Access dict without guard: `dict[key]` -> use `dict.get(key, default)` or `.has()`
- Await without validity check: always `if is_instance_valid(node):` after await
- Hardcode star values: always use `_calculate_stars(_errors)`
- Silent returns: every early `return` needs `push_warning()`
- Leave TODO/FIXME in committed code
- Division without zero guard: always check denominator

## Game Design Philosophy

Every game must:
1. Develop a SPECIFIC skill (shapes, counting, colors, matching, spatial reasoning)
2. Be explainable to a 3-year-old in 5 seconds of animation (The Logic Law)
3. Have micro-reward cycle of 3-5 seconds (action -> immediate visual reward)
4. Use POSITIVE reinforcement only (no punishment for toddlers)
5. Progress from easy to hard within each session
6. Be playable with sound OFF (visual feedback primary)
7. Support BOTH drag-drop AND keyboard navigation
