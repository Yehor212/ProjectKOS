---
description: Gameplay logic rules — applies to game/scripts/**/*.gd
---

# Gameplay Logic Rules (12 Axioms)

## Every Game Must Have

- Clear SKILL it develops (shapes, counting, colors, matching, spatial reasoning)
- Micro-reward cycle: action -> reward in 3-5 seconds
- Progressive difficulty (LAW 6): each round HARDER than previous
- Win condition reachable in finite steps (Axiom A2)
- Tutorial animation showing first step WITHOUT text (Axiom A1)

## Age Split (Axiom A3)

- Toddler (2-4): magnetic assist, larger targets, always 5 stars, no error penalty
- Preschool (4-7): standard targets, star formula, error counting, harder content
- If game serves BOTH: use `SettingsManager.age_group` to branch

## Error Handling by Age

- Toddler (Axiom A6): `AudioManager.play_sfx("click")`, gentle wobble, NO \_errors increment
- Preschool (Axiom A7): `_errors += 1`, `_register_error()`, `play_sfx("error")`, vibrate, smoke VFX

## Scaffolding (Axiom A11)

- Toddler: after 2 consecutive errors -> show correct answer with animation
- Preschool: after 3 consecutive errors -> show correct answer
- Use `_hint_system.check_error_hint(_round_manager.errors_made)`

## Idle Escalation (Axiom A10)

- Level 0 (5s idle): gentle pulse on correct answer
- Level 1 (10s idle): stronger pulse + glow
- Level 2 (15s idle): tutorial hand animation pointing to answer

## Content Pool

- Each game must have enough content for 4-5 sessions without repetition
- Use `_used_indices` to track shown items within session
- Reset pool when exhausted (not mid-session)

## Impossible States (Axiom A8)

- If texture not found: `ResourceLoader.exists()` -> fallback or skip round
- If array empty: guard with `.size()` check -> push_warning + graceful exit
- If timer fires after scene change: `is_instance_valid()` guard
- NEVER show blank/broken screen to child
