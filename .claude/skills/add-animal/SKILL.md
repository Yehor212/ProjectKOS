---
name: add-animal
description: "Add a new animal-food pair: sprites, scenes, GameData entry, translations"
---

# Add Animal-Food Pair

## Required Information (ask user if not provided)
1. **Animal name** (PascalCase): e.g. `Tiger`
2. **Food name** (PascalCase): e.g. `Steak`
3. Animal sprite path or generate placeholder
4. Food sprite path or generate placeholder

## Files Created/Modified
1. `game/assets/sprites/animals/[Animal].png` — 512x512 PNG
2. `game/assets/sprites/food/[Food].png` — 256x256 PNG
3. `game/scenes/animals/[Animal].tscn` — Sprite2D scene
4. `game/scenes/food/[Food].tscn` — Sprite2D scene
5. Add entry to `GameData.ANIMALS_AND_FOOD` in `game_data.gd`
6. Add translation keys to `translations.csv`:
   - `ANIMAL_[UPPER]` — en, uk, fr, es
   - `FOOD_[UPPER]` — en, uk, fr, es

## Rules
- Every animal MUST have a unique food
- Food names MUST NOT collide with animal names
- Animal sprite: 512x512 PNG, transparent background, centered
- Food sprite: 256x256 PNG, transparent background, centered
- Both must be culturally appropriate for all 4 target cultures

## Scene template (.tscn)
```
[gd_scene format=3]
[node name="[Name]" type="Sprite2D"]
texture = preload("res://game/assets/sprites/[category]/[Name].png")
```

## Post-add
- Verify GameData entry is correct
- Verify translations exist for all 4 languages
- Verify sprites are within size budget
