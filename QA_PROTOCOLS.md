# QA Protocols — ProjectKOS "Tofie Play & Learn Adventures"

> Правила якості коду для запобігання регресіям. Кожна зміна ПОВИННА проходити ці перевірки.

> **Cross-references to Game Design Laws (GAME_DESIGN_LAWS.md)**:
> - QA #2 (Await Safety) → **LAW 20**
> - QA #6 (Array Access) → **LAW 13** (Numeric Safety)
> - QA #7 (Save Data Validation) → **LAW 22**
> - QA #9 (Touch Targets) → **LAW 18** + V5 (Accessibility)
> - QA #10 (VFX Lifecycle) → **LAW 21**
> - QA #1,3,4,5,8 — best practices, enforced on code review

---

## 1. Silent Returns

**Кожен ранній `return` ПОВИНЕН мати `push_warning()`** — жодних мовчазних відмов.

```gdscript
# ❌ ЗАБОРОНЕНО
if stars < cost:
    return false

# ✅ ПРАВИЛЬНО
if stars < cost:
    push_warning("ProgressManager: недостатньо зірок (%d < %d)" % [stars, cost])
    return false
```

---

## 2. Await Safety

**Кожен `await` ПОВИНЕН супроводжуватися `is_instance_valid()`** для нод, що використовуються після нього.

```gdscript
# ❌ ЗАБОРОНЕНО
await get_tree().process_frame
_icon_label.pivot_offset = _icon_label.size / 2.0

# ✅ ПРАВИЛЬНО
await get_tree().process_frame
if not is_instance_valid(_icon_label):
    return
_icon_label.pivot_offset = _icon_label.size / 2.0
```

---

## 3. File Write Safety

**Кожен запис файлу ПОВИНЕН перевіряти return value** та мати fallback.

```gdscript
# ❌ ЗАБОРОНЕНО
DirAccess.rename_absolute(tmp_path, save_path)

# ✅ ПРАВИЛЬНО
var err: Error = DirAccess.rename_absolute(tmp_path, save_path)
if err != OK:
    push_error("rename failed (error %d)" % err)
    # fallback — прямий запис
```

---

## 4. Save Debounce

**Операції збереження ПОВИННІ бути дебаунсені** — dirty flag + deferred write, НІКОЛИ inline.

- `save_settings()` лише встановлює `_save_dirty = true`
- `_process()` перевіряє dirty flag і викликає `_do_save()`
- `_notification(PAUSED)` — примусовий `_do_save()` напряму

---

## 5. Screen Navigation

**Кожен екран ПОВИНЕН обробляти `ui_cancel`:**
- Навігація назад, або
- Показати діалог, або
- Явно споживати з коментарем чому

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        _navigate_back()  # ← НЕ порожній обробник!
```

---

## 6. Array Access

**Доступ до масиву `[N]` ПОВИНЕН мати перевірку `.size() > N`** — або `.get()` з default.

```gdscript
# ❌ ЗАБОРОНЕНО
return [pool[0], pool[1]]

# ✅ ПРАВИЛЬНО
if pool.size() < 2:
    push_warning("pool < 2, fallback")
    return [correct + 1, correct + 2]
return [pool[0], pool[1]]
```

---

## 7. Save Data Validation

**Числові значення з файлів збереження ПОВИННІ бути clamped.**

```gdscript
# ❌ ЗАБОРОНЕНО
stars = int(data.get("stars", 0))

# ✅ ПРАВИЛЬНО
stars = maxi(0, int(data.get("stars", 0)))
```

---

## 8. Safe Area

**Всі екрани ПОВИННІ застосовувати safe area margins** на краях, що торкаються меж пристрою.

```gdscript
var sa: Rect2i = DisplayServer.get_display_safe_area()
var full: Vector2i = DisplayServer.screen_get_size()
# Обчислити margins: left, top, right, bottom
```

---

## 9. Touch Targets

**Touch targets ПОВИННІ бути >= 48x48 px** — ідеально 56px+ на мобільних.

---

## 10. VFX Lifecycle

**VFX частинки ПОВИННІ відстежуватися** та очищатися при зміні сцени.

- Додавати до `_active_particles[]` при spawn
- Видаляти при timer cleanup
- `_cleanup_all_particles()` при зміні сцени

---

## Чекліст перед PR

- [ ] Жоден early return без push_warning
- [ ] Жоден await без is_instance_valid після нього
- [ ] Жоден file write без error check
- [ ] Всі числові значення з save clamped
- [ ] Кожен екран обробляє ui_cancel
- [ ] Touch targets >= 48px
- [ ] Safe area applied на edge elements
- [ ] LAW 28: Всі нові `_draw()` мають 4+ шари глибини (shadow, dark, light, sparkle)
- [ ] LAW 28: Всі нові UI-контроли мають theme_type_variation або premium StyleBox
- [ ] LAW 28: Всі `draw_arc()`/`draw_polyline()` контури мають `antialiased = true`
- [ ] LAW 28: Нові ігрові об'єкти мають `material = GameData.create_grain_material()`
