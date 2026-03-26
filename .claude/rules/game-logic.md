# GDScript Game Logic (Positive Rules)

1. Always use type hints: `func foo(x: int) -> void:`
2. Always guard arrays: `if pool.size() > 0:` before access
3. Always guard dicts: `dict.get(key, default)` or `.has(key)`
4. Always guard division: `if denominator != 0:`
5. Always check validity after await: `if not is_instance_valid(node): return`
6. Always use `_calculate_stars(_errors)` for star computation
7. Always `push_warning()` on every early return
8. Always `erase()` from dict before `queue_free()`
9. Always use `_scale_by_round_i()` for progressive difficulty
10. Always call `_start_safety_timeout()` in every minigame
