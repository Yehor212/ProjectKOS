---
description: GDScript coding patterns — applies to **/*.gd
---

# GDScript Patterns (30 Laws Enforcement)

## Numeric Safety (LAW 13)

- NEVER divide without zero guard: `if denominator != 0:` or `if ab.length_squared() > 0.0001:`
- NEVER access array without bounds: `if pool.size() >= 2: pool[0]` not bare `pool[0]`
- NEVER use `randi() % 0` — always guard modulo operand

## Dictionary Guard (LAW 17)

- NEVER `dict[key]` without `.has()` or `.get(key, default)`
- Prefer `dict.get(key, fallback)` over `if dict.has(key): dict[key]`

## Await Safety (LAW 20)

- After EVERY `await`: `if not is_instance_valid(node): return`
- After `await get_tree().create_timer(N).timeout`: check node still exists
- After `await tween.finished`: check both subject and target validity

## Star Formula (LAW 16)

- ONLY use `_calculate_stars(_errors)` from BaseMiniGame
- NEVER hardcode `var earned: int = 5` or any star value directly

## Input Lock (LAW 23)

- Set `_input_locked = true` before async operations
- Reset `_input_locked = false` ONLY after animation/tween completes
- Guard `_input()` and `_process()` with `if _input_locked: return`

## Type Hints

- ALL function parameters: `func foo(bar: int, baz: String) -> void:`
- ALL variables where type isn't obvious: `var speed: float = 100.0`
- Return types on ALL functions: `-> void`, `-> int`, `-> Array[Node2D]`

## Silent Returns (QA #1)

- Every early `return` MUST have `push_warning("ClassName: reason")`
- Pattern: `if condition: push_warning("..."); return`

## Round Hygiene (LAW 9)

- `_cleanup_round()` must clear: arrays, dictionaries, timers, flags
- Erase dict entries BEFORE queue_free (LAW 11)
- Pattern: `_origins.erase(item); item.queue_free()`

## Node Lifecycle (LAW 11)

- Use `queue_free()` not `free()`
- Remove from tracking structures BEFORE freeing
- Check `is_instance_valid()` before accessing potentially freed nodes
