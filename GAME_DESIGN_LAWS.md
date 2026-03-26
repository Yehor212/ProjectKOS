# Game Design Laws — ProjectKOS (30 Minigames, Ages 2-7)

> 30 законів — обов'язкові для ВСІХ мін-ігор. Порушення = баг.
> Створено 2026-03-07. Оновлено 2026-03-18 (+LAW 30: intent alchemy).

---

## LAW 1 — GRAYSCALE BEFORE COLOR
Будь-яка гра типу "розмальовка" ЗОБОВ'ЯЗАНА показувати об'єкт у чорно-білому (десатурованому) стані.
Дія гравця РОЗКРИВАЄ колір. Забороняється показувати кольоровий об'єкт який потім "стає яскравішим".

**Реалізація**: `ShaderMaterial` з `uniform float saturation` (0.0 → 1.0).

---

## LAW 2 — MINIMUM 3 CHOICES
Будь-яка гра на вибір/відповідність ЗОБОВ'ЯЗАНА мати ≥3 варіанти.
2 варіанти = 50% шанс вгадати без розуміння. 3+ варіанти = необхідність думати.

**Приклад**: shadow_match Toddler повинен показувати ≥3 силуети, не 2.

---

## LAW 3 — VISUAL DISTINCTION
Всі інтерактивні елементи ЗОБОВ'ЯЗАНІ бути ВІЗУАЛЬНО ВІДМІННИМИ.
Заборонено: два варіанти з однаковим emoji/іконкою/формою.

**Перевірка**: Якщо гравець не може відрізнити A від B БЕЗ ЧИТАННЯ — це баг.

---

## LAW 4 — TEXT NEVER OVERLAPS
Текстові мітки ЗОБОВ'ЯЗАНІ мати гарантований Y-відступ.
`instruction_label` повинен ЗАКІНЧУВАТИСЯ до початку `round_label`. Мінімум 4px gap.

**Формула**: `round_label.position.y >= instruction_label.position.y + instruction_label.size.y + 4`

---

## LAW 5 — BACKGROUND REQUIRED
Кожна гра ЗОБОВ'ЯЗАНА мати тематичний фон через `bg_theme`.
Сірий/дефолтний фон = баг. Фон повинен відповідати тематиці гри.

**Доступні теми**: meadow, forest, ocean, science, space, city, puzzle, music.
**Реалізація**: `base_minigame.gd:_apply_background()` з `BG_THEME_GRADIENTS` + `_draw_background_layers()` (PNG елементи з `assets/backgrounds/elements/`).

---

## LAW 6 — PROGRESSIVE DIFFICULTY
Кожен раунд ЗОБОВ'ЯЗАНИЙ бути складнішим за попередній.
Більше елементів, швидша швидкість, більше варіантів.

**Реалізація**: `_scale_by_round_i(min, max, round, total)` або `_scale_by_round()`.
**Заборонено**: `randi() % N` для визначення складності.

---

## LAW 7 — SPRITE FALLBACK
Якщо текстура не завантажується — гра ЗОБОВ'ЯЗАНА:
1. Пропустити раунд (`_round += 1; _start_round()`)
2. АБО використати fallback-текстуру
3. НІКОЛИ не показувати порожній екран.

**Перевірка**: `if not ResourceLoader.exists(path): push_warning(); [skip/fallback]`

---

## LAW 8 — STANDARD STAR FORMULA
Формула зірок ЄДИНА для всього проєкту:

| Тип | Формула |
|-----|---------|
| Toddler | `earned = 5` (завжди) |
| Preschool | `earned = clampi(5 - _errors / 2, 1, 5)` |
| Creative | `earned = 5` (завжди) |

**Заборонено**: `TOTAL_ROUNDS - _errors`, `5 - _errors`, або будь-яка інша варіація.

---

## LAW 9 — ROUND HYGIENE
ВСІ тимчасові дані ЗОБОВ'ЯЗАНІ очищуватися між раундами:
- Масиви елементів (`.clear()`)
- Словники стану (`.clear()`)
- Ноди (`.queue_free()` ПІСЛЯ видалення з Dictionary)
- Лічильники (= 0)

**Правило**: Dictionary entry ERASE перед `queue_free()`.

---

## LAW 10 — PALETTE LABELS
Інтерфейси вибору кольору ПОВИННІ мати мітки для навчальної цінності:
- Emoji (🔴🟢🔵🟡) або
- Текст через `tr()` для i18n

**Мета**: Дитина 2-7 років ВЧИТЬСЯ назви кольорів під час гри.

---

---

## LAW 11 — NO ORPHAN NODES
При перезаписі змінної що тримає посилання на Node, СТАРИЙ Node ЗОБОВ'ЯЗАНИЙ бути freed.

**Приклад бага**: BaseMiniGame створює `_instruction_label` на CanvasLayer → гра перезаписує `_instruction_label = Label.new()` → старий label orphan у сцені → подвійний текст.

**Правило**: Перед `var_name = SomeNode.new()`, якщо `var_name` вже тримає Node:
```gdscript
if var_name and is_instance_valid(var_name):
    var_name.queue_free()
```

**Або**: база НЕ створює те, що діти перевизначають (принцип override, не duplicate).

---

## LAW 12 — COMPILE VERIFICATION
Після кожної зміни коду ЗОБОВ'ЯЗАНА бути перевірка що файл компілюється.

**Правило**: Перед викликом будь-якого методу батьківського класу — звірити його ТОЧНЕ ім'я та сигнатуру.

**Приклад бага**: `_scale_by_round_f()` не існує в BaseMiniGame (правильно: `_scale_by_round()`).
**Доступні методи BaseMiniGame**: `_scale_by_round(float, float, int, int) -> float`, `_scale_by_round_i(int, int, int, int) -> int`.

---

## LAW 13 — NUMERIC SAFETY (THE DIVISION LAW)
Кожна операція ділення ЗОБОВ'ЯЗАНА мати guard від нульового дільника.

**Правила**:
- Float: `maxf(divisor, 1.0)` або `if divisor < 0.001: return fallback`
- Int: `maxi(divisor, 1)` або `if divisor == 0: return fallback`
- Масив: `if index >= 0 and index < array.size()` перед `array[index]`
- Словник: `.has(key)` або `.get(key, default)` перед `dict[key]`

**Приклад бага**: `safe_maze.gd:311` — `ap.dot(ab) / ab.dot(ab)` де `ab = Vector2.ZERO` → div/0 → NaN.

---

## LAW 14 — TIMEOUT GUARANTEE (THE WATCHDOG LAW)
Кожна мінігра ЗОБОВ'ЯЗАНА мати safety timeout.

**Правило**:
```gdscript
const SAFETY_TIMEOUT_SEC: float = 120.0  ## Стандарт: 120с, creative: 300с
## В _ready():
_start_safety_timeout(SAFETY_TIMEOUT_SEC)
```

**Значення**: 120с для звичайних ігор, 300с для creative (sensory_sandbox, smart_coloring).
**Приклад бага**: `gravity_orbits.gd` — нескінченний retry без таймауту → softlock.

---

## LAW 15 — COUNT-AFTER-CREATE (THE SYNC LAW)
Лічильники елементів ЗОБОВ'ЯЗАНІ встановлюватись ПІСЛЯ створення, не до.

**Правило**: Якщо створення може впасти (відсутній спрайт):
1. НЕ встановлювати `_total = expected_count` заздалегідь
2. Інкрементувати лічильник ТІЛЬКИ при успішному `add_child()`
3. Після циклу: `if _total <= 0: push_warning(); _skip_round()`

**Приклад бага**: `sorting_game.gd` — `_total_items = cat_count * items_per_cat` до спавну, missing sprites → softlock.

---

## LAW 16 — CENTRALIZED STAR FORMULA (THE SINGLE-SOURCE LAW)
Зірки рахує ТІЛЬКИ `BaseMiniGame._calculate_stars(penalty: int) -> int`.

**Канонічна формула**:
| Тип | Результат |
|-----|-----------|
| Toddler (age_group == 1) | `5` (завжди) |
| Preschool | `clampi(5 - penalty / 2, 1, 5)` |
| Creative | `5` (завжди) |

**ЗАБОРОНЕНО**: `5 - _errors / 2` без clampi, `TOTAL_ROUNDS - _errors / 2`, будь-яка inline формула.
**Enforcement**: `test_law_compliance.gd` перевіряє що кожна гра викликає `_calculate_stars()`.

---

## LAW 17 — DICTIONARY GUARD (THE .has() LAW)
Прямий доступ `dict[key]` ЗАБОРОНЕНИЙ (крім compile-time або щойно вставлених ключів).

**Правило**: Використовувати `.get(key, default)` або `if dict.has(key):`
**Патерн**: Особливо в drop-callbacks де item може бути вже оброблений:
```gdscript
## ЗАБОРОНЕНО:
_origins[item]
## ПРАВИЛЬНО:
if _origins.has(item):
    _drag.snap_back(item, _origins[item])
```

**Приклад бага**: `counting_game.gd:309` — `_origins[item]` без .has() → KeyError crash.

---

## LAW 18 — WEBGL 2.0 QUALITY BASELINE (THE RENDERER LAW)
Весь візуальний дизайн ЗОБОВ'ЯЗАНИЙ проходити через **Compatibility renderer** (OpenGL 3.3 / ES 3.0 = WebGL 2.0).

**Філософія**: Якщо гра виглядає бездоганно на найслабшому рендерері — вона гарантовано працює **скрізь**: Android (low-end), iOS, Web, Desktop. Це не компроміс якості — це **доказ якості**.

**Правила**:
1. `project.godot` → `renderer/rendering_method = "gl_compatibility"` (ЗАВЖДИ)
2. **ЗАБОРОНЕНО**: `GPUParticles2D` / `GPUParticles3D` (тільки `CPUParticles2D`)
3. **ЗАБОРОНЕНО**: Compute shaders, SSAO, SSR, SDFGI, Volumetric Fog, GI Probes
4. **Шейдери**: тільки `shader_type canvas_item` + базовий GLSL (vertex/fragment). Без `shader_type spatial` з PBR
5. **Текстури**: ETC2/ASTC компресія (мобільні GPU). Без BCn-only форматів
6. **Перевірка**: кожен новий шейдер/VFX тестується з `--rendering-method gl_compatibility`

**5 стовпів якості через обмеження**:
| Стовп | Що забезпечує | Як |
|-------|--------------|-----|
| Universality | Працює на 99% пристроїв | GL Compatibility = мінімальний спільний знаменник |
| Performance | 60 FPS на $100 телефонах | CPU particles + прості шейдери = легковаговий pipeline |
| Web-readiness | Готовність до web export | Compatibility → WebGL 2.0 автоматично |
| Shader clarity | Чисті, зрозумілі шейдери | Без Vulkan-магії = легко аудитити та підтримувати |
| Future-proof | Вперед-сумісність | WebGPU (Godot 5.x) буде надмножиною GL Compatibility |

**Приклад порушення**: Розробник додає `GPUParticles2D` з compute-based collision → гра крашиться на WebGL 2.0 та старих Android.

---

## LAW 19 — DUAL GATE PHILOSOPHY (THE PHILOSOPHY LAW)
Код НЕ МОЖЕ бути написаний без проходження **Воріт Входу** і НЕ МОЖЕ бути визнаний готовим без проходження **Воріт Виходу**.

**Філософія**: Хірург не різає без діагнозу. Хірург не зашиває без перевірки. Код між двома воротами — хірургічна операція. Без воріт — різанина наосліп.

---

### ВОРОТА ВХОДУ (PRE-FLIGHT) — перед КОЖНОЮ зміною коду

Обов'язковий `<thinking>` блок з 4 секціями:

**1. ЧОМУ? (Intent & Root Cause)**
- Яку проблему вирішуємо? Чи це СИМПТОМ чи ПРИЧИНА? (→ LAW 21 Root Cause)
- Чи є це в GAME_DESIGN_BIBLE.md? Яка гра, який розділ?
- Хто просить цю зміну — користувач, аудит, баг?

**2. ЩО? (Scope & Impact)**
- Які файли будуть змінені? Перелік з обґрунтуванням
- Які системи торкнуться? (autoloads, signals, тести)
- Чи є залежні файли, що потребують синхронної зміни? (`.gd` + `.tscn` — LAW 22)

**3. ЯК? (Implementation Plan)**
- Покроковий технічний план (не більше 8 кроків)
- Для кожного кроку: файл → рядок → зміна
- Які закони (1-28) КРИТИЧНІ для цієї зміни?

**4. А ЯКЩО НІ? (Devil's Advocate)**
- Топ-2 причини чому ця імплементація може зламатися
- Як код ПРЕВЕНТИВНО вирішує кожну?
- Що станеться з дитиною 3 років якщо цей код впаде?

---

### ВОРОТА ВИХОДУ (POST-FLIGHT) — після КОЖНОЇ зміни коду

Обов'язковий блок верифікації з 5 перевірками:

**V1. КОМПІЛЯЦІЯ (Compile Gate)**
- Чи компілюється кожен змінений файл? (LAW 12)
- Чи існують всі викликані методи батьківського класу?
- Evidence: список методів з сигнатурами

**V2. ЗАКОНИ (Law Gate)**
- Перевірити ВСІ 30 законів для кожного зміненого файлу
- Особлива увага: LAW 11 (orphan nodes), LAW 13 (div/0), LAW 17 (dict guard), LAW 28 (flat visual elements)
- Evidence: `PASS`/`FAIL` для кожного закону

**V3. АКСІОМИ (Axiom Gate)**
- Перевірити 12 аксіом (A1-A12) для кожної зміненої гри
- Evidence: таблиця аксіом з результатами

**V4. DUAL-SOURCE (Scene Gate — LAW 22)**
- Grep змінених ідентифікаторів у `.gd` І `.tscn`
- Чи немає orphan-посилань у сценах?
- Evidence: результат grep

**V5. РЕГРЕСІЯ (Regression Gate)**
- Чи не зламано суміжні системи?
- Чи збережена візуальна якість? (CXO Law 1 — ZERO REGRESSION)
- Чи пройдуть тести? (`test_law_compliance.gd`)
- Evidence: перелік перевірених суміжних файлів

---

### ФОРМАТ EVIDENCE

Кожен PASS у Воротах ЗОБОВ'ЯЗАНИЙ мати evidence:
```
✅ V1 COMPILE: method `_scale_by_round_i(int,int,int,int)` — існує в base_minigame.gd:45
✅ V2 LAW 17: `_origins.get(item, Vector2.ZERO)` — dict guard на рядку 128
❌ V3 A4: FAIL — складність НЕ зростає між раундами → ПОТРЕБУЄ ФІКСУ
```

**Без evidence = FAIL. FAIL = код НЕ ГОТОВИЙ.**

---

### ФІЛОСОФСЬКІ ПРИНЦИПИ

| Принцип | Значення |
|---------|----------|
| **Measure Twice, Cut Once** | Аналіз ДО коду дешевший за debug ПІСЛЯ |
| **The Child Test** | Якщо 3-річна дитина натисне не туди — що станеться? |
| **Occam's Scalpel** | Найпростіше рішення що проходить всі ворота = найкраще |
| **Zero Ambiguity** | Якщо є сумнів — це баг. Якщо "може працює" — це не працює |
| **Ratchet Rule** | Якість тільки ВГОРУ. Кожен коміт краще попереднього |

**Приклад порушення**: Розробник одразу пише код без `<thinking>` блоку → пропускає LAW 17 (dict guard) → KeyError crash у дитини → P1 баг який міг бути попереджений за 30 секунд аналізу.

---

## LAW 20 — AWAIT SAFETY (THE RESURRECTION LAW)
Після КОЖНОГО `await` ЗОБОВ'ЯЗАНА бути перевірка валідності нод, що використовуються далі.
`await` віддає контроль — ноди МОЖУТЬ бути freed поки корутіна спить.

**Правила**:
1. Після `await get_tree().create_timer(N).timeout` — перевірити `_game_over` guard
2. Після будь-якого `await` — перевірити `is_instance_valid(node)` для нод що використовуються далі
3. Виняток: `await` в `_ready()` до старту ігрової логіки (layout wait)

**Приклад бага**:
```gdscript
## ❌ ЗАБОРОНЕНО:
await get_tree().create_timer(1.0).timeout
_musicians[_sequence[i]].highlight()  ## Node може бути freed!

## ✅ ПРАВИЛЬНО:
await get_tree().create_timer(1.0).timeout
if _game_over or not is_instance_valid(self):
    return
_musicians[_sequence[i]].highlight()
```

**Evidence**: 4 порушення (forest_orchestra:187, shape_sorter:249,272, counting_game:139).

---

## LAW 21 — VFX LIFECYCLE (THE PARTICLE LAW)
Кожен спавн `CPUParticles2D` ЗОБОВ'ЯЗАНИЙ бути відстежений та очищений.

**Правила**:
1. Кожна частинка додається до `_active_particles[]` при спавні
2. Кожна частинка має cleanup timer (`lifetime + CLEANUP_MARGIN`)
3. Всі частинки очищуються при зміні сцени (`_cleanup_all_particles()`)
4. Timer callbacks що створюють VFX MUST перевіряти `get_tree().current_scene` перед спавном
5. Tween для VFX MUST бути створений на `VFXManager` (autoload), НЕ на `scene` (може бути freed)

**Приклад бага**:
```gdscript
## ❌ ЗАБОРОНЕНО (tween на scene):
var tw: Tween = scene.create_tween()
tw.chain().tween_callback(spark.queue_free)  ## scene freed → orphan spark

## ✅ ПРАВИЛЬНО (tween на VFXManager):
var tw: Tween = create_tween()  ## VFXManager is autoload, never freed
tw.chain().tween_callback(spark.queue_free)
```

**Evidence**: spawn_firework_fountain (timer callback), spawn_gift_unwrap (scene tween).

---

## LAW 22 — SAVE DATA VALIDATION (THE TRUST-NOTHING LAW)
Числові значення з файлів збереження ЗОБОВ'ЯЗАНІ бути **validated при ЗАВАНТАЖЕННІ**.
Corrupted save не повинен зламати гру.

**Правила**:
1. Float: `clampf(data.get("key", default), min, max)` — ЗАВЖДИ clamp
2. Int: `clampi(data.get("key", default), min, max)` — ЗАВЖДИ clamp
3. String: перевірити проти списку допустимих значень (`if value not in VALID_LIST: value = default`)
4. Array: перевірити тип елементів та розмір (`if arr.size() > MAX: arr.resize(MAX)`)

**Приклад бага**:
```gdscript
## ❌ ЗАБОРОНЕНО (raw load без validation):
sfx_volume = data.get("sfx_volume", 1.0)  ## Corrupted save: 9999.0 → audio blast

## ✅ ПРАВИЛЬНО:
sfx_volume = clampf(data.get("sfx_volume", 1.0), 0.0, 1.0)
```

**Evidence**: settings_manager.gd:92-94 loads sfx_volume, language, unlocked_backgrounds без validation.

---

## LAW 23 — INPUT LOCK DISCIPLINE (THE PATIENCE LAW)
Input ЗОБОВ'ЯЗАНИЙ бути locked (`_input_locked = true`) під час будь-яких non-interactive фаз.

**Правила**:
1. Lock при staggered spawn анімаціях
2. Lock при round transition delays (`await`)
3. Lock при celebration/finish sequences
4. Lock при scene transition fade
5. Unlock ТІЛЬКИ коли гравець МОЖЕ і ПОВИНЕН діяти
6. Кожна мінігра ЗОБОВ'ЯЗАНА мати `var _input_locked: bool = true` (initial lock до deal animation)

**Приклад бага**:
```gdscript
## ❌ ЗАБОРОНЕНО (input під час transition):
await get_tree().create_timer(1.0).timeout  ## Гравець може натиснути!
_start_round()

## ✅ ПРАВИЛЬНО:
_input_locked = true
await get_tree().create_timer(1.0).timeout
_start_round()  ## _start_round() unlocks at the end
```

**Evidence**: forest_orchestra.gd — немає `_input_locked`, гравець може натиснути під час await.

---

## LAW 24 — STATS CONTRACT (THE HANDSHAKE LAW)
Кожен виклик `finish_game(earned, stats)` ЗОБОВ'ЯЗАНИЙ передати dict з **точними** ключами.

**Обов'язкові ключі**:
```gdscript
var stats: Dictionary = {
    "time_sec": Time.get_ticks_msec() / 1000.0 - _start_time,
    "errors": _errors,
    "rounds_played": MAX_ROUNDS,  ## або _current_round
    "earned_stars": earned
}
finish_game(earned, stats)
```

**Правила**:
1. ЗАБОРОНЕНО пропускати ключі (BaseMiniGame використовує `.get("key", 9999)` — default = broken analytics)
2. `"earned_stars"` в dict MUST дорівнювати `earned` (1st param)
3. ЗАБОРОНЕНО передавати некоректні типи (`"errors": "none"` замість `0`)

**Приклад бага**: forest_orchestra:221 — `earned_stars` дублюється в dict І 1st param з різними значеннями.

---

## LAW 25 — COLOR-BLIND SAFE (THE SHAPE LAW)
Кожен інтерактивний елемент, що використовує колір як дискримінатор, ЗОБОВ'ЯЗАНИЙ мати **вторинну ознаку розрізнення**: форма, іконка, патерн або текстовий лейбл.

**Філософія**: 8% хлопчиків мають дальтонізм. Гра на «вибери червоний» без додаткової ознаки = НЕДОСТУПНА для ~1 з 12 гравців. Колір — прикраса, не інформація.

**Правила**:
1. ЗАБОРОНЕНО: «натисни на червону кульку» де кульки відрізняються ТІЛЬКИ кольором
2. ОБОВ'ЯЗКОВО: кожен колір має вторинну ознаку (форма контуру, emoji, штрихування, мітка `tr()`)
3. При `SettingsManager.color_blind_mode == true` — показувати вторинні ознаки примусово
4. Без color_blind_mode — вторинні ознаки бажані, але не обов'язкові

**Уражені ігри**: color_pop, color_lab, color_conveyor, smart_coloring — потребують secondary visual encoding.

**Приклад**:
```gdscript
## ❌ ЗАБОРОНЕНО (тільки колір):
bubble.color = Color.RED

## ✅ ПРАВИЛЬНО (колір + форма):
bubble.color = Color.RED
bubble.shape_outline = "circle"  ## Або іконка, або патерн
if SettingsManager.color_blind_mode:
    bubble.show_label(tr("COLOR_RED"))
```

---

## LAW 26 — SESSION WELLNESS (THE HEALTH LAW)
Після безперервної гри протягом `session_limit_minutes` (20хв за замовчуванням) ЗОБОВ'ЯЗАНИЙ з'явитися м'який оверлей «час відпочити».

**Філософія**: Дитина 2-7 років не контролює час. Педіатричні рекомендації обмежують безперервний screen time 20-30 хвилинами. Ми — відповідальний додаток, не казино.

**Правила**:
1. Таймер починається при старті додатку, скидається при фокус-аут/паузі
2. Оверлей м'який: анімація (персонаж позіхає), БЕЗ негативного фідбеку
3. Оверлей закривається ТІЛЬКИ через parental gate (LAW 27)
4. Налаштування в `SettingsManager.session_limit_minutes` (15/20/30/0=вимкнено)
5. Дефолт = 20 хвилин

**Реалізація**: `session_timer.gd` компонент, інтегрований у game hub.

---

## LAW 27 — PARENTAL GATE (THE CONTAINMENT LAW)
Вихід із гри, доступ до налаштувань та будь-які дії за межами ігрового пісочниці ЗОБОВ'ЯЗАНІ проходити через **нетривіальний parental gate**.

**Філософія**: COPPA 2025 (ефективний квітень 2026) вимагає containment — дитина не може випадково вийти з безпечного середовища. Один тап на кнопку «Вихід» = порушення.

**Правила**:
1. Parental gate = дія, нездійсненна для тоддлера: утримання 3 пальців протягом 2 секунд
2. Zero-text: жодного тексту в gate (сумісно з A1 — дитина розуміє інтерфейс без тексту)
3. Gate спрацьовує на: вихід із гри, перехід до налаштувань, зовнішні посилання
4. Gate НЕ спрацьовує на: вибір гри, gameplay, пауза/resume

**Чому 3 пальці на 2 секунди**:
- Тоддлер (2-4): не може координувати 3 пальці одночасно протягом 2с
- Дорослий: виконує без зусиль
- Нульовий текст: сумісно з LAW 16 (Zero-Text Autonomy)
- Не потребує складної математики (що вимагало б тексту)

**Реалізація**: `ExitConfirmOverlay` — Resume (велика зелена) + Exit (маленька сіра) → при натисканні Exit → показати gate «утримайте 3 пальці 2с» → gate пройдено → вихід.

---

## LAW 28 — PREMIUM VISUAL PIPELINE (THE CANDY DEPTH LAW)
Кожен візуальний елемент, намальований процедурно (`_draw()`) або створений як UI-контрол, ЗОБОВ'ЯЗАНИЙ мати багатошарову глибину. Плоскі одноколірні фігури ЗАБОРОНЕНІ.

**Філософія**: Дитячий мозок сприймає об'ємні, "смачні" форми як привабливі та інтерактивні. Плоский кольоровий круг — це UI-компонент для дорослого SaaS. Цукерковий круг з тінню, бліком і блискіткою — це іграшка, до якої хочеться торкнутися. Ми робимо іграшки, не дашборди.

**Індустріальний контекст (2025-2026)**: Claymorphism / Neo-Skeuomorphism — домінантний тренд для дитячих додатків: яскраві пастелі, об'ємні 3D-кнопки, candy-like surfaces. Top kids apps (Khan Academy Kids, Lingokids, Sago Mini) використовують: bright colors, rounded corners, soft shadows, press feedback.

**Правила**:

1. **Іконки/фігури** (`draw_circle`, `draw_rect`, `draw_polygon`) — мінімум 4 шари:
   - **Шар 1 — Тінь**: `Color(0, 0, 0, 0.10..0.18)` зі зміщенням `Vector2(2, 3)`
   - **Шар 2 — Темна основа**: `color.darkened(0.15..0.20)`
   - **Шар 3 — Світлий блік**: `color.lightened(0.15..0.30)` або `Color(1, 1, 1, 0.2..0.4)`
   - **Шар 4 — Блискітка (sparkle)**: `draw_circle(sparkle_pos, radius * 0.06..0.12, Color(1, 1, 1, 0.45..0.7))`
   - *Опціонально*: контур (border arc) та радіальний градієнт

2. **Слоти/отвори** (inward depth):
   - Внутрішня тінь (darkened rim) + Світліший центр (lightened fill) + Контур

3. **UI-контроли** (Button, ProgressBar, Panel):
   - `StyleBoxFlat` з `shadow_size > 0`, `corner_radius > 0`, `border_width > 0`
   - АБО `theme_type_variation` на ThemeManager стиль (Button, SecondaryButton, CircleButton, PillButton, AccentButton)
   - АБО `GameData.candy_panel()` helper

4. **Напівпрозорі елементи**: shadow alpha масштабується пропорційно до alpha елемента

5. **Anti-aliased контури**: Всі `draw_arc()` та `draw_polyline()` з контурами ЗОБОВ'ЯЗАНІ мати `antialiased = true`. Зубчасті лінії сприймаються дітьми як "зламані" елементи та знижують perceived quality.

6. **Стандартний helper**: `IconDraw._color_palette(base_color)` → `{base, light, lighter, dark, darker, shadow}`

7. **Текстура поверхні**: Інтерактивні ігрові об'єкти (`_draw()`) ПОВИННІ мати `material = GameData.create_grain_material()` для тактильної якості поверхні. Гладка цифрова поверхня без мікро-текстури = cheap mobile game feel. Виключення: слоти/отвори (slot_item), HUD-індикатори, декоративні елементи splash screen.

**ЗАБОРОНЕНО**:
```gdscript
## ❌ ЗАБОРОНЕНО — flat single-color (LAW 28 violation):
draw_circle(center, radius, Color.RED)

## ❌ ЗАБОРОНЕНО — unstyled UI control (LAW 28 violation):
var bar: ProgressBar = ProgressBar.new()
add_child(bar)  ## Дефолтний Godot стиль!

## ❌ ЗАБОРОНЕНО — button без theme variation (LAW 28 violation):
## [node name="MyButton" type="Button"]  ## Без theme_type_variation і без script override

## ✅ ПРАВИЛЬНО — premium circle:
var pal: Dictionary = IconDraw._color_palette(Color.RED)
IconDraw._draw_soft_shadow(self, center, radius)
draw_circle(center, radius, pal["dark"])
draw_circle(center + Vector2(-radius * 0.2, -radius * 0.2), radius * 0.5, pal["light"])
draw_circle(center + Vector2(-radius * 0.3, -radius * 0.35), maxf(radius * 0.1, 1.0), Color(1, 1, 1, 0.5))

## ✅ ПРАВИЛЬНО — themed button:
## [node name="MyButton" type="Button"]
## theme_type_variation = &"AccentButton"
```

**Виключення**: Елементи позначені `## LAW 28 exempt:` з обґрунтуванням (напр., debug-only trigger).

**Evidence**: 11+ файлів вже використовують pipeline (icon_draw.gd, shape_item.gd, counting_item.gd, slot_item.gd, bubble.gd, splash_track.gd, splash_deco.gd, musician.gd, floating_cloud.gd, color_pop.gd, gravity_orbits.gd). Закон кодифікує існуючу практику.

---

## ENFORCEMENT

При аудиті кожна гра перевіряється проти ВСІХ 30 законів (25 per-game + 4 project-wide).
Автоматична перевірка: `godot --headless --path game/ -s tests/run_all_tests.gd`
Порушення будь-якого закону = баг відповідної severity:

| Закон | Severity при порушенні |
|-------|----------------------|
| LAW 1-3 | P0 (game-breaking logic) |
| LAW 4-5 | P1 (visual/UX broken) |
| LAW 6-8 | P1 (gameplay quality) |
| LAW 9-10 | P2 (data/educational) |
| LAW 11 | P0 (orphan nodes = memory leak + visual bug) |
| LAW 12 | P0 (compile error = game won't load) |
| LAW 13 | P1 (crash on div/0 or KeyError) |
| LAW 14 | P0 (softlock — game hangs forever) |
| LAW 15 | P0 (softlock — count desync) |
| LAW 16 | P1 (wrong star count) |
| LAW 17 | P1 (crash on missing key) |
| LAW 18 | P0 (cross-platform breakage) |
| LAW 19 | P1 (process violation — unverified code) |
| LAW 20 | P0 (crash on freed node after await) |
| LAW 21 | P1 (orphan particles, memory leak) |
| LAW 22 | P1 (corrupted save breaks experience) |
| LAW 23 | P1 (race condition, double input) |
| LAW 24 | P2 (analytics data corruption) |
| LAW 25 | P2 (accessibility — color-blind exclusion) |
| LAW 26 | P2 (child welfare — session health) |
| LAW 27 | P1 (COPPA compliance — containment failure) |
| LAW 28 | P1 (visual regression — flat procedural drawing / unstyled UI control) |
| LAW 29 | P0 (quality regression — ratchet floor violation) |

---

## LAW 29 — QUALITY RATCHET (THE IRREVERSIBILITY LAW)

> "Movement in one direction is possible, but the other direction is stopped."
> — Quality Ratchet pattern (LeadDev)

Візуальна та анімаційна якість — RATCHET. Вона ТІЛЬКИ зростає, НІКОЛИ не падає.
Будь-яка зміна що зменшує кількість VFX, grain, animations, або depth = P0 баг.

**Філософія**: Якість — це CONTRACT з користувачем. Дитина звикла до блискучих кнопок,
cascade-анімацій, конфеті. Забрати це = зрада очікувань. В індустрії (Netflix, Spotify,
Duolingo) це називається "delight regression" — апдейт що робить продукт ГІРШИМ.
Це гірше за баг — це втрата довіри.

**Зв'язок**: LAW 19 (Dual Gate) = філософія. LAW 29 = enforcement machine.

---

### R1 — MONOTONIC QUALITY (Metric Floors)

Кожна quality метрика має **floor** — мінімальне значення.
`actual < floor` = тест FAIL = CI блокує.

| Метрика | Напрям | Baseline | Вимірювання |
|---------|--------|----------|-------------|
| grain_coverage | ↑ up | 66 | Count `create_grain_material(` across all .gd |
| stagger_coverage | ↑ up | 12 | Count files with `_staggered_spawn(` |
| ripple_coverage | ↑ up | 5 | Count files with `spawn_success_ripple(` in minigames/ |
| minigame_count | ↑ up | 30 | Count .gd files in minigames/ |
| test_count | ↑ up | 18 | Count `func test_` in test suite |
| animation_conflicts | ↓ down | 0 | Files with BOTH stagger AND deal_item_in |

**Auto-tightening**: Коли actual > floor → `RATCHET: metric improved N→M, update baseline!`
**Override**: Легітимне зменшення (видалення obsolete гри) потребує `## OVERRIDE: reason (date)`.

---

### R2 — ANIMATION OWNERSHIP (One Pipeline Per Property)

Кожна property (scale, modulate, position) ноди може бути animated тільки ОДНИМ pipeline.

**ЗАБОРОНЕНО**:
```gdscript
## ❌ ЗАБОРОНЕНО — подвійна анімація (LAW 29 R2):
_deal_item_in(item)           ## Анімує scale + modulate
_staggered_spawn(_items)      ## ТАКОЖ анімує scale + modulate → КОНФЛІКТ!
```

**ПРАВИЛЬНО**: Обрати ОДНУ систему:
```gdscript
## ✅ ПРАВИЛЬНО — тільки deal_item_in (кастомна анімація):
_deal_item_in(item)

## ✅ ПРАВИЛЬНО — тільки stagger (стандартна каскадна):
_staggered_spawn(_items, 0.08)
```

**Перевірка**: Перед додаванням будь-якої анімації → grep файл для existing tweens на ті ж properties.

**Реальний кейс**: Phase 3 (V140) — додали `_staggered_spawn()` до 15 ігор, 6 з них ВЖЕ мали
`_deal_item_in()`. Подвійні tweens на scale+modulate = візуальний баг (items flash/jitter).

---

### R3 — COVERAGE LOCK (Baseline Preservation)

Baseline зафіксований як constants в `test_law_compliance.gd`.
Тест рахує фактичну кількість і FAIL якщо < baseline.

Baseline оновлюється ТІЛЬКИ ВГОРУ — коли нова feature додає coverage.

---

### R4 — STALENESS DETECTION (Self-Triggering)

| Тригер | Warning | FAIL |
|--------|---------|------|
| Нові .gd файли без grain | 1 uncovered | 3+ uncovered |
| Нова мінігра без stagger | Print advisory | — |
| Actual > floor на >20% | "Tighten baseline!" | — |

Тест виявляє нові файли автоматично — при додаванні нової мінігри без
grain/stagger/ripple виводить попередження.

---

### R5 — GRADUATION PIPELINE (Advisory → Assertion)

Advisory тести (push_warning) переходять у hard assertions (assert) коли
досягають 0 порушень протягом 2 тижнів.

| Advisory | Статус | Graduate |
|----------|--------|----------|
| LAW 17 dict bracket | push_warning | 0 violations → assert |
| LAW 20 await guard | push_warning | 0 violations → assert |
| LAW 28 grain _draw() | push_warning | 0 → READY |
| LAW 29 animation conflict | assert | Already hard |

---

### R6 — EVIDENCE CHAIN (Irrefutable Proof)

Кожна верифікація ЗОБОВ'ЯЗАНА мати evidence:
- `file:line` reference
- `grep count` output
- `test output` quotation

**ЗАБОРОНЕНО**: "Виглядає ок", "Should be fine", "Перевірив" без цитати.

---

### R7 — COMPLETENESS PROOF (100% Scope)

Кожен аудит ЗОБОВ'ЯЗАНИЙ перевірити 100% declared scope.

**Протокол**:
1. DECLARE scope: "Перевіряю N файлів"
2. ENUMERATE: кожен файл ✅/❌ з evidence
3. PROVE: `checked / declared == 1.0`
4. "Все файли" → enumerate explicitly. Implicit scope ЗАБОРОНЕНО.

**Anti-pattern**: "Перевірив основні файли" = FAIL (скільки? які? evidence?)

---

## LAW 30 — INTENT ALCHEMY (REQUEST TRANSMUTATION)
Severity: P0 | Enforcement: Manual

Кожен запит користувача ЗОБОВ'ЯЗАНИЙ пройти 5 стовпів трансмутації ДО Pre-Flight:

| Стовп | Назва | Суть |
|-------|-------|------|
| A | DECODE | Що мав на увазі? Неявний контекст. Критерії успіху |
| B | PHILOSOPHIZE | ЧОМУ це важливо? Кореневий мотив (5 Чому) |
| C | EMBODY | Яка роль експерта? Детальна для дизайну, проста для коду |
| D | EXPAND | Що НЕ сказано але ПОТРІБНО? Суміжні вимоги. Пропозиції |
| E | REFLECT | Чи вірний трансмутований намір? Пропорційність. Підтвердження |

Порядок: LAW 30 (A→E) → Pre-Flight (P0-P7) → Scale → Code.

Наукова база: Grice (1975) — прагматичний висновок; MIRROR (2025) — +21% від внутрішнього
монологу; MAPS (2025) — +13.3% від багатошарової рефлексії; Meta-Prompting (2024) —
структура > зміст; ExpertPrompting (2024) — детальні ролі >> прості.

Антипаттерн: "Fix textures" → grain overlay замість візуального оверхолу (V145, 3 сесії rework).
