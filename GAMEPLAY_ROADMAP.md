# GAMEPLAY ROADMAP — Повне переосмислення логіки та геймплею

> **ОСТАННЄ ОНОВЛЕННЯ**: 2026-03-21 (повне оновлення всіх секцій)
> Цей документ — стратегічний blueprint для досягнення App Store Featured якості.
> Кожна рекомендація підкріплена дослідженнями. Кожна гра проаналізована індивідуально.
> "Не бійся все ламати та створювати заново."
> **ПОВНА ЗАБОРОНА НА СПРОЩЕННЯ.** Toddler-режим = ПОВНОЦІННА ГРА з іншою механікою, НЕ "легша версія".

### ПРОГРЕС РЕАЛІЗАЦІЇ

| Tier | Елементів | Завершено | Статус |
|------|----------|----------|--------|
| **Tier 1** (A3/A4 critical) | 7 | 7 | ✅ **100%** |
| **Tier 2** (Content + scaffolding) | 5 | 5 | ✅ **100%** |
| **Tier 3** (Polish) | 8 | 8 | ✅ **100%** |
| **VFX** (reduced_motion + gradients) | 2 | 2 | ✅ **100%** |
| **Tier 4** (VFX extras) | 3 | 2 | ✅ 67% (drag-start done, combo existed, round transition deferred) |
| **Tier 5** (Deep gameplay audit) | 8 | 8 | ✅ **100%** |
| **Total implemented** | **32/33** | **32** | ✅ **97%** |

### КЛЮЧОВІ ДОСЯГНЕННЯ
- **A3 violations**: 6 → **0** (6 нових повноцінних ігор створено)
- **A4 violations**: 1 → **0** (size_sort progressive ratio)
- **A11 missing**: 3 → **0** (scaffolding в sorting, math_scales, pattern_builder)
- **A10 Lvl2 missing**: 3 → **0** (tutorial hand в shadow_match, shape_sorter, memory_cards)
- **VFX reduced_motion**: 18 gaps → **0** (guards на всі spawn functions)
- **Content pools**: spelling 4→12, color_lab 6→9 (tier-based), weather 6→8
- **Touch targets**: color_pop 35→45dp, cash_register T 88dp

### CRITICAL BUG FIXES (знайдені через visual testing)
- ~~_staggered_spawn перезаписує scale на Vector2.ONE~~ ✅ FIXED — тепер зберігає original_scale
- ~~_orchestrated_entrance перезаписує scale~~ ✅ FIXED — анімує до original_scale
- ~~UniversalDrag._original_scales = Vector2.ONE~~ ✅ FIXED — зберігає item.scale
- ~~Blink (моргання) тварин~~ ✅ REMOVED за запитом
- ~~shadow_match ANIMAL_SCALE занадто великий~~ ✅ FIXED 0.4→0.35

### РЕАЛІЗОВАНО ДОДАТКОВО (Tier 4-5)
- ~~Drag-start VFX~~ ✅ DONE (spawn_snap_pulse on universal_drag pickup)
- ~~Combo/streak VFX~~ ✅ Already existed in BaseMiniGame (_streak_count + JuicyEffects.combo_vfx)
- ~~weather_dress Toddler choices~~ ✅ ITEMS_TODDLER 2→3 (LAW 2 compliance)
- ~~compare_game Preschool "equal"~~ ✅ 3rd choice + content repetition tracking
- ~~counting_game content tracking~~ ✅ _pick_unused_fruit_idx() додано
- ~~Animation speed Toddler~~ ✅ 1.4× multiplier in _staggered_spawn + _orchestrated_entrance
- ~~color_lab distractor pool~~ ✅ Secondary colors added for Tier 3 rounds
- Round transition VFX — per-game (30 files), LOW priority, defer

### ЗАЛИШИЛОСЬ (FUTURE — окремі сесії)
- 4 нові ігри: emotion_mirror, story_cards, sound_match, mirror_draw
- Voice-over recording (28+ files × 4 мови)
- color_lab redesign (show 3-4 tubes, pick 2 — gameplay change)
- Round transition VFX (30 files)

---

## 1. ФІЛОСОФІЯ — Що робить дитячу гру ВЕЛИКОЮ

### 1.1 Ключові принципи (research-backed)

| Принцип | Джерело | Застосування |
|---------|---------|-------------|
| **Gameplay = Learning** | [Frontiers Meta-Analysis](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2024.1307881/full): g=.67 cognitive effect | Гра і навчання НЕ розділені. Дитина вчиться ГРАЮЧИ |
| **Zone of Proximal Development** | [GamersLearn ZPD](https://www.gamerslearn.com/design/challenge-and-zpd-in-video-games): stair-step difficulty | Складність = трохи вище поточного рівня дитини |
| **Show Don't Tell** | [Gapsy UX for Kids](https://gapsystudio.com/blog/ux-design-for-kids/): text = invisible noise | Для 3-5 років текст = шум. Анімація + звук + жести |
| **Micro-Reward 3-5 sec** | [GameAnalytics Juice](https://www.gameanalytics.com/blog/squeezing-more-juice-out-of-your-game-design) | Дія → негайний відгук (звук + анімація + VFX) |
| **Positive Only (Toddler)** | GAME_DESIGN_LAWS LAW A6 | Toddler 2-4: НІКОЛИ помилка. Тільки м'яке перенаправлення |
| **Mastery Over Reward** | [Akendi Rewards](https://www.akendi.com/blog/how-to-create-a-reward-system-that-actually-works/) | Нагороди прив'язані до прогресу, не до випадковості |
| **Toca Boca Simplicity** | [Toca Boca Philosophy](https://www.oreateai.com/blog/beyond-the-screen-the-playful-philosophy-behind-toca-bocas-digital-worlds/) | Мінімум опцій, shallow navigation, reduce cognitive load |
| **Sago Mini Calm** | Sago Mini design: softer sounds, slower animations | Спокійний ритм = фокус + менше відволікань |

### 1.2 Золоте правило

> Якщо механіку неможливо пояснити 3-річній дитині за 5 секунд анімації — механіка зламана.

---

## 2. ТЕХНІЧНІ СТАНДАРТИ — Кожен нюанс

### 2.1 Touch Targets

| Вік | Мінімум | Рекомендовано | Джерело |
|-----|---------|---------------|---------|
| 2-3 роки | 15mm (≈85dp) | 20mm (≈115dp) | [NN/g Touch Targets](https://www.nngroup.com/articles/touch-target-size/) |
| 3-5 років | 12mm (≈68dp) | 15mm (≈85dp) | [ScienceDirect Touch 3-6](https://www.sciencedirect.com/science/article/abs/pii/S1071581914001426) |
| 5-7 років | 9mm (≈48dp) | 12mm (≈68dp) | Android Material Design Guidelines |

**Правило**: Toddler buttons = МІНІМУМ 80×80dp. Preschool = МІНІМУМ 60×60dp.
**Spacing**: між кнопками ≥8dp (андроїд) або ≥6dp (Apple).

### 2.2 Текстури

| Тип | Розмір | Формат | Чому |
|-----|--------|--------|------|
| Тварини (основні) | 512×512 | PNG lossless | Чіткість на великих екранах, VRAM compress artifacts на <512 |
| Їжа/предмети | 256×256 | PNG lossless | Менший екранний розмір, lossless для чистих країв |
| Іконки ігор | 256×256 | PNG lossless | Чіткість в hub, gradient quality |
| Частинки (particles) | 32×32 | PNG lossless | Research: 16-32px sweet spot для mobile particles |
| Фони | 1280×720 | ASTC 4×4 або lossy WebP 85% | Великий розмір, VRAM compression виправданий |
| UI елементи | 128×128 | PNG lossless | Кнопки, бейджі — потрібна чіткість |

**Правило**: VRAM compression (ASTC/ETC2) тільки для текстур ≥512px. Для менших — lossless PNG.
Джерело: [Android Textures](https://developer.android.com/games/optimize/textures), [Godot Proposals #7119](https://github.com/godotengine/godot-proposals/issues/7119)

### 2.3 Анімації та тайминг

| Елемент | Тривалість | Easing | Чому |
|---------|-----------|--------|------|
| Tap feedback | ≤50ms | - | [NN/g Response Time](https://www.nngroup.com/articles/response-times-3-important-limits/) |
| Success pop | 0.15-0.3s | EASE_OUT_BACK | Source #8: quadratic = soft feel |
| Error wobble | 0.2-0.3s | EASE_IN_OUT_SINE | М'яке, не лякаюче |
| Round transition | 0.5-0.8s | EASE_IN_OUT_CUBIC | Плавний перехід, не різкий |
| Celebration cascade | 1.5-3.0s | Staggered layers | Source #10: delay layering |
| Idle hint Level 0 | 5s delay, 0.5s pulse | EASE_IN_OUT_SINE | Ненав'язливе |
| Idle hint Level 2 | 15s delay, tutorial hand | LINEAR + pulse | Чітке направлення |
| Card deal-in | 0.3-0.5s stagger | EASE_OUT_CUBIC | Anticipation principle |

**Правило**: Toddler animations = 1.5× slower ніж Preschool. Дитина 2-3 років відстежує рух повільніше.
Джерело: [PMC Animation EF](https://pmc.ncbi.nlm.nih.gov/articles/PMC8392582/), [Frontiers Visual Attention](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2022.1069478/full)

### 2.4 Звук

| Подія | Тип звуку | Характеристики |
|-------|-----------|---------------|
| Правильна відповідь | Jingle/fanfare | Мажор, висхідна мелодія, 0.3-0.5s |
| Помилка (Preschool) | М'який "oop" | НЕ harsh buzzer. Gentle descending tone |
| Помилка (Toddler) | Click/pop | Нейтральний, не негативний |
| Tap на елемент | Pop/click | Миттєвий, ≤50ms |
| Drag pickup | Soft whoosh | Тактильний feedback |
| Drop на target | Snap/thud | Підтвердження |
| Level complete | Fanfare + confetti sound | 1.5-2.0s, мажорна мелодія |
| Idle hint | Gentle chime | Привертає увагу, не лякає |

**Правило**: Кожна дія = звук + візуал. 50% мотивації = звук (Source: [SciencePress Sound Design](https://www.scitepress.org/Papers/2025/135044/135044.pdf)).

### 2.5 Взаємодія (Interaction Design)

| Жест | Toddler (2-4) | Preschool (4-7) | Джерело |
|------|--------------|-----------------|---------|
| Tap | 71% success rate | 90%+ | [PMC Toddler Scrolling](https://pmc.ncbi.nlm.nih.gov/articles/PMC4969291/) |
| Drag | 41% (need magnetic assist) | 57% | [NN/g Physical Dev](https://www.nngroup.com/articles/children-ux-physical-development/) |
| Swipe | 20% (too complex) | 50% | Research: requires steady pressure |
| Pinch | 10% (avoid) | 30% (avoid) | Not developmentally appropriate |

**Правило**: Toddler = tap + drag з magnetic assist. Preschool = tap + drag + slide. НІКОЛИ pinch/zoom.
Dragging ТОЧНІШЕ ніж tapping для number tasks (Source: [ScienceDirect Drag vs Tap](https://www.sciencedirect.com/science/article/abs/pii/S0022096524001292)).

---

## 3. ПО-ІГРОВИЙ АУДИТ ТА РЕДИЗАЙН — Всі 30 ігор

### Легенда статусів:
- ✅ Добре реалізовано
- ⚠️ Потребує покращення
- ❌ Критична проблема
- 🆕 Потрібен новий режим

---

### 3.1 SHADOW MATCH (Матч тіней)
**Навичка**: Розпізнавання форм, просторове мислення
**Вік**: Toddler-only | **Раунди**: 5

| Аспект | Статус | Поточний стан | Рекомендація |
|--------|--------|--------------|-------------|
| A3 (Age Fork) | ✅ FIXED | Code already had T/P fork. Catalog fixed TODDLER→ALL | game_catalog.gd |
| A4 (Progression) | ⚠️ | 3→4 силуети (мінімальна) | Minor — progression exists, could be steeper |
| A10 (Idle Lvl2) | ✅ FIXED | Level 2: golden flash 1.3× scale on correct slot | shadow_match.gd |
| Touch targets | ✅ | Силуети великі | OK |
| Content | ✅ | 19 тварин | Достатньо для 4+ сесій |

---

### 3.2 SHAPE SORTER (Сортер фігур)
**Навичка**: Розпізнавання форм, збірка
**Вік**: Обидва | **T**: 3 раунди, **P**: 1 раунд (rocket)

| Аспект | Статус | Поточний стан | Рекомендація |
|--------|--------|--------------|-------------|
| A3 (Age Fork) | ✅ | T: сортер, P: Tangram-rocket | Різні механіки — ОК |
| A4 (Progression) | ✅ | T: 2→4 фігури | OK |
| Cognitive jump | ⚠️ | P = Tangram (різко складніше) | TODO: P round 1 = easy rocket |
| Content P | ⚠️ | 1 rocket = 1 сесія | TODO: 2-3 rocket designs |
| A10 (Idle Lvl2) | ✅ FIXED | Level 2: golden flash on shape+slot | shape_sorter.gd |

---

### 3.3 COUNTING GAME (Рахуємо з Тофі)
**Навичка**: Кількісне мислення, базова арифметика
**Вік**: Обидва | **Раунди**: 5

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| A3 | ✅ | T: drag N fruits, P: tap answer |
| A4 | ✅ | T: 1-3→3-5, P: 3/2→6/4 |
| Milestone alignment | ✅ | 2-3yo: know "two". 3-4yo: count to 10 |
| Touch targets | ✅ | Fruits + answer buttons large |
| All | ✅ | Одна з найкраще реалізованих ігор |

---

### 3.4 COLOR POP (Лопаємо бульбашки)
**Навичка**: Дискримінація кольорів, реакція
**Вік**: Обидва | **Раунди**: 1 (45s)

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| A3 | ✅ | T: будь-яка бульбашка, P: тільки target color |
| A4 | ✅ | Швидкість зростає |
| A10 | ⚠️ | Reaction game — idle hint less relevant | Low priority |
| Touch targets | ✅ FIXED | PRESCHOOL_RADIUS = 45dp (was 35dp) | Research: ≥15mm |

---

### 3.5 MEMORY CARDS (Карти пам'яті)
**Навичка**: Короткочасна пам'ять, паттерн-матчинг
**Вік**: Обидва | **T**: 3 раунди, **P**: 2 раунди

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| A3 | ✅ | T: відкриті карти, P: закриті |
| A4 | ✅ | Grid зростає |
| A10 (Idle Lvl2) | ✅ FIXED | Level 2: golden flash on both matching cards | memory_cards.gd |
| Content | ✅ | 19 тварин, _used_indices |

---

### 3.6 HUNGRY PETS (Голодні улюбленці)
**Навичка**: Асоціація тварина-їжа
**Вік**: ✅ Обидва (FIXED) | **Раунди**: T: Dynamic, P: 5

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| A3 | ✅ FIXED | P mode "Шеф-кухар": animal+3-4 food cards, tap correct, silhouette R5 | AgeCategory.ALL |
| A4 | ✅ | 3→4→5 пар |
| Content | ✅ | 19 пар |
| **Preschool design** | 🆕 | - | **ПОВНОЦІННА ГРА "Шеф-кухар для тварин"**: Тварина сидить за столом. Меню показує 3-4 страви (зображення). Одна правильна (біологічна пара), інші — дистрактори. Drag правильну страву на стіл → тварина їсть + happy анімація. Прогресія: R1 = 3 варіанти (1 схожий дистрактор), R5 = 4 варіанти (2 схожих). Помилки рахуються. Це самостійна гра про ГОДУВАННЯ, не спрощений matching |

---

### 3.7 SORTING GAME (Сортування хабітатів)
**Навичка**: Класифікація, екологічні знання
**Вік**: Обидва | **Раунди**: 3

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| A3 | ✅ | T: 2 категорії, P: 3 |
| A11 | ✅ FIXED | _show_scaffold_hint() override: пульсує правильний habitat zone | Gold flash + 1.5s highlight |
| Content | ✅ | Forest(7), Farm(6), Jungle(6) |

---

### 3.8 SIZE SORT (Сортування розмірів)
**Навичка**: Порівняння розмірів, впорядкування
**Вік**: Обидва | **Раунди**: 4

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| A4 | ✅ FIXED | ROUND_SPRITE_SCALES[4]: R0=×3.2, R1=×2.3, R2=×1.9, R3=×1.5 | Progressive ratio |
| A3 | ✅ | T: 2 розміри, P: 3 |
| Touch targets | ✅ | Платформи великі |
| Content | ✅ | 19 тварин |

---

### 3.9 COMPARE GAME (Що більше?)
**Навичка**: Кількісне порівняння
**Вік**: Обидва | **Раунди**: 5

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| Все | ✅ | Одна з найкраще реалізованих ігор |
| Milestone | ✅ | 2-3yo: match identical. 3-4yo: compare sizes |

---

### 3.10 PATTERN BUILDER (Конструктор паттернів)
**Навичка**: Логічне мислення, патерн-завершення
**Вік**: Обидва | **Раунди**: 5

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| A3 | ✅ | T: AB, P: AB→ABC |
| A4 | ✅ | Зростає складність патерну |
| A11 | ✅ FIXED | _show_scaffold_hint(): pulses correct answer with highlight | pattern_builder.gd |

---

### 3.11 ODD ONE OUT (Лишній)
**Навичка**: Класифікація, виявлення outlier
**Вік**: Обидва | **Раунди**: 5

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| Все | ✅ | Добре реалізовано |
| A10 | ✅ | Has idle timer 5s + pulse hint | Verified in audit |

---

### 3.12 MATH BINGO (Математичне BINGO)
**Навичка**: Арифметика, стратегічне мислення
**Вік**: ✅ Обидва (FIXED) | **T**: 5 раундів (2×2 dots), **P**: 3 раунди (3×3)

| Аспект | Статус | Деталі |
|--------|--------|--------|
| A3 | ✅ FIXED | T: "Лічи та знаходь" — 2×2 dots grid, dice patterns, 180dp cells |
| A1 | ✅ | T: dots замість цифр (zero-text). P: рівняння (text = inherent to skill) |
| Milestone | ✅ | T: numbers 1-4 (matches 3-4yo). P: addition/subtraction (matches 5-7yo) |
| **Toddler design** | 🆕 | - | **ПОВНОЦІННА ГРА "Лічи та знаходь"**: 2×2 grid з картинками (1 яблуко, 2 яблука, 3 яблука, 4 яблука). Тофі каже "Знайди ТРИ яблука!" (озвучення + 3 яблука на екрані зліва). Tap правильну клітинку → celebration. Прогресія: R1 = числа 1-3 (очевидні), R2 = числа 1-4, R3 = додавання через візуал ("скільки разом?" з двома групами). Це самостійна гра про ЛІЧБУ ЧЕРЕЗ ОБРАЗИ, не спрощене BINGO |

---

### 3.13 SPELLING BLOCKS (Блоки для написання)
**Навичка**: Читання, послідовність літер
**Вік**: ✅ Обидва (FIXED) | **Раунди**: 5

| Аспект | Статус | Деталі |
|--------|--------|--------|
| A3 | ✅ FIXED | T: "Хто це?" — animal recognition, 2-3 cards, tap matching |
| Content | ✅ FIXED | 4→12 слів (CAT,DOG,COW,HEN,PIG,BEE,FOX,OWL,ANT,BUG,FLY,SUN) | i18n keys додані |
| A4 | ✅ | Дистрактори 1→3 |
| **Toddler "Хто це?"** | ✅ IMPLEMENTED | R1-2: 2 cards, R3-4: 3 cards, R5: audio-only | Tap animal matching top image |

---

### 3.14 CASH REGISTER (Каса)
**Навичка**: Розуміння грошей, додавання
**Вік**: Обидва (T planned) | **Раунди**: 5

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| A3 | ✅ FIXED | T mode: coins=1 only, prices 1-3, 88dp coins, magnetic assist | AgeCategory.ALL |
| A4 | ✅ | EASY→HARD |
| Milestone | ✅ | 5-7yo: basic addition |

---

### 3.15 COLOR CONVEYOR (Кольорова логістика)
**Навичка**: Дискримінація кольорів, сортування
**Вік**: Обидва | **Раунди**: 3

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| All | ✅ | Добре реалізовано |
| Content | ✅ FIXED | P: 5 кольорів (R,B,Y,G,Purple) progressive per round | color_conveyor.gd |

---

### 3.16 ECO CONVEYOR (Еко-конвеєр)
**Навичка**: Переробка, категоризація
**Вік**: Обидва | **Раунди**: 3

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| All | ✅ | Добре |
| A4 | ✅ FIXED | Speed scaling 30→45px/s progressive per round | eco_conveyor.gd |

---

### 3.17 MAGNETIC HALVES (Магнітні пазли-половинки)
**Навичка**: Просторове мислення, завершення форми
**Вік**: Обидва | **Раунди**: 4

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| All | ✅ | Добре реалізовано |

---

### 3.18 WEATHER DRESS (Кліматичний гардероб)
**Навичка**: Причинно-наслідкові зв'язки
**Вік**: Обидва | **T**: 3, **P**: 4-5 раундів

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| Content | ✅ FIXED | 8 погод (sunny,rainy,snowy,windy,cloudy,stormy,hot,foggy) | weather_dress.gd |
| A4 | ✅ | Дистрактори зростають |
| Items Toddler | ✅ FIXED | ITEMS_TODDLER 2→3 (LAW 2 compliance) | 3 correct clothing per weather |

---

### 3.19 MATH SCALES (Математичні ваги)
**Навичка**: Арифметика, баланс/рівність
**Вік**: Обидва | **Раунди**: 5

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| A11 | ✅ FIXED | _show_scaffold_hint(): finds best weight, pulses with green highlight | math_scales.gd |
| All other | ✅ | Добре |

---

### 3.20 ANALOG CLOCK (Аналоговий годинник)
**Навичка**: Читання часу, цифрова грамотність
**Вік**: ✅ Обидва (FIXED) | **Раунди**: 5

| Аспект | Статус | Деталі |
|--------|--------|--------|
| A3 | ✅ FIXED | T: "Який час?" — 7 activities, 3 clocks (200dp), tap correct, hour hand only |
| A4 | ✅ | :00→:30 |
| **Toddler design** | 🆕 | - | **ПОВНОЦІННА ГРА "Який час?"**: Тофі каже "Час обідати! Покажи 12 годин!" (озвучення + іконка їжі). 3 великих годинники (80dp+) з різним часом. Tap правильний → годинник дзвонить + celebration. Кожен раунд = нова активність (обід, сон, прогулянка) з іконкою. Прогресія: R1-3 = очевидні різниці (3:00 vs 9:00 vs 12:00), R4-5 = ближчі (2:00 vs 3:00 vs 6:00). Це самостійна гра про РОЗПОРЯДОК ДНЯ, не спрощений clock-reading |

---

### 3.21 FOREST ORCHESTRA (Лісовий оркестр)
**Навичка**: Слухова обробка, послідовна пам'ять
**Вік**: Обидва | **T**: sandbox 45s, **P**: Simon Says 5 lvl

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| A3 | ✅ | T: free tap, P: Simon Says |
| A4 | ✅ | Sequence 2→6 |
| All | ✅ | Добре |

---

### 3.22 COLOR LAB (Лабораторія кольорів)
**Навичка**: Змішування кольорів, хімія (базова)
**Вік**: Обидва | **Раунди**: 4

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| Content | ✅ FIXED | 9 recipes (3 tiers), tier-based progression, expanded distractor pool | color_lab.gd |
| A3 | ✅ | T: magnetic, P: error count |
| Distractor pool | ✅ FIXED | R4+: secondary colors (orange, green, purple) as distractors | Pedagogically correct |

---

### 3.23 HYGIENE GAME (Гігієнічні рутини)
**Навичка**: Самообслуговування, гігієна
**Вік**: Обидва | **T**: 3, **P**: 4 раунди

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| All | ✅ | Добре |
| Mechanic | ✅ FIXED | 5 missed wipes = 1 error P (was 8, more fair) | hygiene_game.gd |

---

### 3.24 KNIGHT PATH (Шлях коня)
**Навичка**: Шахова логіка, пошук шляху
**Вік**: ✅ Обидва (FIXED) | **T**: 5 раундів (3×3), **P**: 4 раунди (5×5)

| Аспект | Статус | Деталі |
|--------|--------|--------|
| A3 | ✅ FIXED | T: "Пригоди коника" — 3×3, star collection, all moves highlighted |
| A4 | ✅ | BFS depth 2→4 |
| **Toddler design** | 🆕 | - | **ПОВНОЦІННА ГРА "Пригоди коника"**: 3×3 grid з яскравими клітинками. Конник стрибає (L-shaped анімація). Мета: зібрати 3 зірки. Кожен допустимий хід = яскрава клітинка з анімацією "тут можна!". Tap → конник стрибає з juice-анімацією. Раунд завершується коли всі зірки зібрані. Прогресія: R1 = 1 зірка (2 ходи), R2 = 2 зірки, R3 = 3 зірки. Це самостійна гра про РУХАННЯ ПО КЛІТИНКАХ, не спрощений chess |

---

### 3.25 ALGO ROBOT (Алгоритмічний робот)
**Навичка**: Обчислювальне мислення, програмування послідовностей
**Вік**: Обидва | **T**: 3, **P**: 4 раунди

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| All | ✅ | Добре реалізовано |
| A3 | ✅ | T: 3×3 2-3 кроки, P: 4×4 + ×2 button |

---

### 3.26 SAFE MAZE (Безпечний лабіринт)
**Навичка**: Дрібна моторика, слідування шляху
**Вік**: Обидва | **T**: 3, **P**: 4 раунди

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| All | ✅ | Добре |
| A4 | ✅ | Ширина 60→36px (P) |

---

### 3.27 GRAVITY ORBITS (Гравітаційні орбіти)
**Навичка**: Фізична інтуїція, імпульсний контроль
**Вік**: ✅ Обидва (FIXED) | **T**: 5 раундів (catch), **P**: 5 раундів (orbit)

| Аспект | Статус | Деталі |
|--------|--------|--------|
| A3 | ✅ FIXED | T: "Космічний улов" — timing catch, 180dp planet, 1.3× tap radius |
| A4 | ✅ | Orbital zone narrows |
| **Toddler design** | 🆕 | - | **ПОВНОЦІННА ГРА "Космічний улов"**: Планета в центрі. Зірочки падають з різних боків. Tap на зірочку коли вона поряд з планетою → планета "з'їдає" її (scale+glow анімація). Кожна зірка = micro-reward. Прогресія: R1 = повільно, великі зірки, R5 = швидше, менші. Це самостійна reaction game про ЛОВЛЕННЯ, не спрощена фізика орбіт |

---

### 3.28 SMART COLORING (Інтелектуальна розмальовка)
**Навичка**: Креативність, дрібна моторика
**Вік**: Обидва | **T**: 3, **P**: 4 раунди

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| All | ✅ | Добре. Creative = always 5⭐ |
| LAW 1 | ✅ | Grayscale → color reveal |

---

### 3.29 SENSORY SANDBOX (Сенсорна пісочниця)
**Навичка**: Креативність, сенсорне дослідження
**Вік**: Обидва | **Раунди**: 1 (long session)

| Аспект | Статус | Рекомендація |
|--------|--------|-------------|
| All | ✅ | Добре. Creative = always 5⭐ |
| T | ✅ | Auto color-cycle, 90s |
| P | ✅ | 8 neon colors, 120s |

---

### 3.30 Інші ігри (відсутні в аудиті вище)
**compare_game, note_particles, snap_pulse** — вже покриті як частини інших ігор або standalone ефектів.

---

## 4. ВІК-ВІДПОВІДНИЙ ДИЗАЙН — Milestone-Mapped Mechanics

### 4.1 Toddler (2-4 роки) — Когнітивні milestones

| Вік | Milestone | Ігри що це розвивають |
|-----|-----------|----------------------|
| 2-3 | Матчинг ідентичних | shadow_match, memory_cards (open) |
| 2-3 | Сортування за кольором | color_conveyor (T), color_pop (T: any) |
| 2-3 | Знає "два" | counting_game (T: 1-3 items) |
| 3-4 | Лічба до 10 | counting_game (T: 3-5), 🆕 math_bingo (T) |
| 3-4 | Розпізнавання форм | shape_sorter, pattern_builder (AB) |
| 3-4 | Порівняння розмірів | size_sort, compare_game |
| 3-4 | Асоціації | hungry_pets, weather_dress, sorting_game |

### 4.2 Preschool (4-7 років) — Когнітивні milestones

| Вік | Milestone | Ігри що це розвивають |
|-----|-----------|----------------------|
| 4-5 | Лічба до 20 | counting_game (P), cash_register |
| 4-5 | Ідентифікація патернів | pattern_builder (ABC), odd_one_out |
| 4-5 | Порівняння розмірів | size_sort (P: 3 sizes), compare_game (P: more/less) |
| 5-7 | Базова арифметика | math_bingo, math_scales, cash_register |
| 5-7 | Читання/написання | spelling_blocks |
| 5-7 | Час | analog_clock |
| 5-7 | Логіка/алгоритми | algo_robot (×2), knight_path |
| 5-7 | Фізика | gravity_orbits |

### 4.3 Правила для кожної вікової групи

**Toddler (2-4)**:
- Завжди 5 зірок (A5)
- Помилки НЕ рахуються (A6)
- Magnetic assist на drag (41% success rate)
- Touch targets ≥80dp (15mm+)
- Анімації 1.5× повільніші
- Scaffolding: після 2 помилок → показати відповідь (A11)
- Тільки tap + assisted drag
- Звук "click" на помилку (не "error")

**Preschool (4-7)**:
- Формула зірок: clampi(5 - errors/2, 1, 5) (A5)
- Помилки рахуються через _register_error() (A7)
- Без magnetic assist
- Touch targets ≥60dp (12mm+)
- Стандартна швидкість анімацій
- Scaffolding: після 3 помилок → показати відповідь (A11)
- Tap + drag + slide
- Звук "error" + вібрація + smoke VFX

---

## 5. РОЗШИРЕННЯ КОНТЕНТУ — Replay Value

### 5.1 Критичні пулы (вичерпуються за 1-2 сесії)

| Гра | Поточний пул | Сесії до повторення | Цільовий пул | Зусилля |
|-----|-------------|---------------------|-------------|---------|
| spelling_blocks | 8 слів | ~2 | 20 слів | MEDIUM (i18n × 4 мови) |
| color_lab | 4 рецепти | ~1 | 9 рецептів (3 tiers) | LOW (logic only) |
| weather_dress | 4 погоди | ~1 | 8 погод | LOW (assets + logic) |

### 5.2 Середні пули

| Гра | Пул | Сесій | Рекомендація |
|-----|-----|-------|-------------|
| shadow_match | 19 тварин | ~4 | Додати 8-10 нових силуетів (предмети, транспорт) |
| safe_maze | 95 комбо | ~6 | OK, додати ще 3 шаблони шляхів |
| memory_cards | 19 тварин | ~5 | Додати іконки їжі як альтернативні пари |

### 5.3 Безкінечні пули (не потребують розширення)

color_pop, counting_game, compare_game, math_bingo, math_scales, pattern_builder, algo_robot, knight_path, gravity_orbits, sensory_sandbox

### 5.4 Стратегія розширення контенту

**Принцип**: Кожна гра повинна мати ≥5 сесій унікального контенту.
**Формула**: Pool Size / Items Per Session ≥ 5.

---

## 6. СИСТЕМА НАГОРОД ТА МОТИВАЦІЇ — Етичний дизайн

### 6.1 Поточна система
- Зірки 1-5 за результат (Toddler = завжди 5)
- VFX celebration cascade на завершення рівня
- Gacha-reveal для нових тварин
- Progress tracking per game

### 6.2 Рекомендації (research-backed)

| Елемент | Поточний | Рекомендований | Чому |
|---------|----------|---------------|------|
| Зірки | Результат-based | + "Effort stars" для Toddler | Mastery > reward ([Akendi](https://www.akendi.com/blog/how-to-create-a-reward-system-that-actually-works/)) |
| Combo | ✅ EXISTS | _streak_count + combo_vfx (×3: tap_stars, ×5: golden_burst, ×8+: rainbow_ring) + pitch bend audio | Already in BaseMiniGame |
| Collection | Gacha animals | + Stickers per game theme | Tangible progress per skill domain |
| Session end | Abrupt | Friendly goodbye animation + "See you later!" | [Zero to Three](https://www.zerotothree.org/resource/screen-time-recommendations-for-children-under-six/): smooth transition |
| Daily play | Немає | "Welcome back" with progress recap | Intrinsic motivation via progress visibility |

### 6.3 Що ЗАБОРОНЕНО (ethical)

- ❌ Infinite reward loops
- ❌ Fake scarcity ("Limited time!")
- ❌ FOMO ("Your friends already have...")
- ❌ Dark patterns (misleading buttons)
- ❌ Variable ratio on rewards (addiction risk)
- ❌ Punishment for NOT playing
- ❌ Ads, in-app purchases targeting children

---

## 7. ДОСТУПНІСТЬ (Accessibility)

### 7.1 Color-Blind Safe (LAW 25)

- Ніколи не використовувати ТІЛЬКИ колір для передачі інформації
- Завжди додавати: форму, іконку, текстуру, або анімацію як secondary encoding
- 4 color games мають pattern overlay ✅
- Contrast ratio ≥ 4.5:1 для тексту (WCAG AA)

### 7.2 Motor Impaired

- Touch targets для Toddler: ≥80dp (accommodates developing motor)
- Magnetic assist на drag (Toddler)
- No time pressure на Toddler games (крім color_pop free mode)
- Generous hit zones (tap within 20dp of target = success for Toddler)

### 7.3 Reduced Motion (SettingsManager)

- Всі tweens перевіряють `SettingsManager.reduced_motion` ✅
- VFX spawn calls — ✅ ВСІ 18 функцій захищені reduced_motion guard (FIXED)
- Dissolve/circle_wipe transitions skip animation if reduced_motion ✅

### 7.4 Internationalization (i18n — LAW A12)

- 4 мови: en, uk, fr, es
- Весь текст через `tr()` ✅
- spelling_blocks content expansion ПОТРЕБУЄ i18n для всіх нових слів
- Number formatting: locale-aware
- Right-to-left: не підтримується (не потрібно для поточних мов)

---

## 8. STORE COMPLIANCE

### 8.1 Google Play Families Policy (mandatory March 2025)

- [x] No PII collection
- [x] Parental gate (3-finger 2-second)
- [x] No ads
- [x] No in-app purchases targeting children
- [x] Age-appropriate content
- [ ] ⚠️ Verify target audience declaration in Play Console
- [ ] ⚠️ Verify Data Safety section accuracy

### 8.2 Apple Kids Category

- [x] No third-party tracking
- [x] Parental gate for external links
- [x] Age-appropriate content
- [ ] ⚠️ Update age rating questionnaire for new categories (by Jan 2026)

### 8.3 COPPA/GDPR-K

- [x] No personal data collection
- [x] Analytics = stub (no real tracking)
- [x] Random encryption key for save data
- [x] No device identifiers transmitted

---

## 9. ПРІОРИТЕТНА ДОРОЖНЯ КАРТА — Ordered by Impact × Effort

### Tier 1: CRITICAL (A3 violations — broken axioms) ✅ ЗАВЕРШЕНО
**Зусилля**: ~80-120 LOC кожен | **Impact**: 20% портфеля недоступно

| # | Гра | Fix | Статус | Нова гра |
|---|-----|-----|--------|----------|
| 1 | size_sort | A4: progression ×3.2→×1.5 | ✅ DONE | — |
| 2 | hungry_pets | A3: Preschool "Шеф-кухар" | ✅ DONE | Tap correct food from 3-4 |
| 3 | analog_clock | A3: Toddler "Який час?" | ✅ DONE | Daily routine + 3 clocks |
| 4 | math_bingo | A3: Toddler "Лічи та знаходь" | ✅ DONE | 2×2 dots grid counting |
| 5 | spelling_blocks | A3: Toddler "Хто це?" + content 4→12 | ✅ DONE | Animal recognition cards |
| 6 | knight_path | A3: Toddler "Пригоди коника" | ✅ DONE | 3×3 star collection |
| 7 | gravity_orbits | A3: Toddler "Космічний улов" | ✅ DONE | Timing catch game |

### Tier 2: HIGH (Content exhaustion + missing features) ✅ ЗАВЕРШЕНО
**Зусилля**: ~40-80 LOC кожен | **Impact**: Replay value + UX quality

| # | Fix | Статус | Файл |
|---|-----|--------|------|
| 8 | color_lab: expand 6→9 recipes (3 tiers) | ✅ DONE | color_lab.gd |
| 9 | weather_dress: expand 6→8 weathers (+hot, foggy) | ✅ DONE | weather_dress.gd |
| 10 | sorting_game: add scaffolding | ✅ DONE | sorting_game.gd |
| 11 | math_scales: add scaffolding | ✅ DONE | math_scales.gd |
| 12 | pattern_builder: add scaffolding | ✅ DONE | pattern_builder.gd |

### Tier 3: MEDIUM (Polish + consistency) ✅ ЗАВЕРШЕНО
**Зусилля**: ~20-40 LOC кожен | **Impact**: Professional polish

| # | Fix | Статус | Файл |
|---|-----|--------|------|
| 13 | shadow_match: A10 Lvl2 tutorial hand | ✅ DONE | shadow_match.gd |
| 14 | shape_sorter: A10 Lvl2 + correct hint | ✅ DONE | shape_sorter.gd |
| 15 | memory_cards: A10 Lvl2 pair highlight | ✅ DONE | memory_cards.gd |
| 16 | color_pop: enlarge touch target 35→45dp | ✅ DONE | color_pop.gd |
| 17 | eco_conveyor: speed scaling 30→45px/s | ✅ DONE | eco_conveyor.gd |
| 18 | hygiene_game: reduce miss threshold 8→5 | ✅ DONE | hygiene_game.gd |
| 19 | color_conveyor: add green/purple for P | ✅ DONE | color_conveyor.gd |
| 20 | cash_register: Toddler mode (coin 1 only, prices 1-3, 88dp) | ✅ DONE | cash_register.gd |

### VFX Compliance ✅ ЗАВЕРШЕНО
| Fix | Статус |
|-----|--------|
| reduced_motion guards (18 functions) | ✅ DONE |
| Gradient enrichment (15 gradients → 4-5 stops) | ✅ DONE |
| Drag-start VFX (spawn_snap_pulse on pickup) | ✅ DONE |
| Combo/streak VFX (already in BaseMiniGame) | ✅ EXISTS |
| Round transition VFX (per-game, low priority) | ⏳ Deferred |

### Tier 4: FUTURE (New games)
| # | Гра | Навичка | Priority |
|---|-----|---------|----------|
| 21 | emotion_mirror | Emotional intelligence | HIGH |
| 22 | story_cards | Narrative thinking | MEDIUM |
| 23 | sound_match | Auditory discrimination | MEDIUM |
| 24 | mirror_draw | Symmetry/spatial | LOW |

---

## 10. QUALITY GATES — Що означає "Готово"

### 10.1 Per-Game Checklist

Кожна гра вважається "готовою" коли:

- [ ] A1: Zero-text onboarding (animated hand shows first action)
- [ ] A2: Win condition reachable (no deadlock possible)
- [ ] A3: Age fork (Toddler AND Preschool have different mechanics)
- [ ] A4: Progressive difficulty (each round harder)
- [ ] A5: Star formula (T=5, P=clampi(5-errors/2,1,5))
- [ ] A6: Toddler errors NOT counted (click sound, gentle wobble)
- [ ] A7: Preschool errors counted (_register_error)
- [ ] A8: Impossible state fallback (guards, ResourceLoader.exists)
- [ ] A9: Round hygiene (all temp data cleared)
- [ ] A10: Idle escalation (3 levels: pulse → stronger → tutorial hand)
- [ ] A11: Scaffolding (2T/3P errors → show answer)
- [ ] A12: i18n (all text via tr())
- [ ] Touch targets ≥80dp (T) / ≥60dp (P)
- [ ] Content pool ≥5 unique sessions
- [ ] VFX: celebration + correct feedback + error feedback
- [ ] Sound: every action has audio feedback
- [ ] Tests: PASS in CI suite

### 10.2 Project-Wide Quality Gate

- [ ] ALL 30 games pass per-game checklist
- [ ] 48+ tests PASS (LAW 29 R7 baseline)
- [ ] 0 parse errors
- [ ] COPPA/Google Families/Apple Kids compliant
- [ ] 4 languages (en, uk, fr, es)
- [ ] Reduced motion respected everywhere
- [ ] Color-blind safe (secondary encoding)

---

## ДЖЕРЕЛА

### VFX & Performance
1. [Godot CPUParticles2D Docs](https://docs.godotengine.org/en/stable/classes/class_cpuparticles2d.html)
2. [RealTimeVFX — Mobile Performance](https://realtimevfx.com/t/performance-optimization-for-mobile-games/24644)
3. [VFX Programming Guide 2025](https://generalistprogrammer.com/tutorials/game-particle-effects-complete-vfx-programming-guide-2025)
4. [Toxigon — Godot 4 Particles](https://toxigon.com/godot-4-particle-systems-guide)
5. [Android Textures](https://developer.android.com/games/optimize/textures)

### Game Design & Education
6. [Frontiers Meta-Analysis](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2024.1307881/full)
7. [PMC Serious Games Framework](https://pmc.ncbi.nlm.nih.gov/articles/PMC10963373/)
8. [Springer Preschool Game Design](https://link.springer.com/article/10.1007/s11042-024-19803-7)
9. [GamersLearn ZPD](https://www.gamerslearn.com/design/challenge-and-zpd-in-video-games)
10. [Toca Boca Philosophy](https://www.oreateai.com/blog/beyond-the-screen-the-playful-philosophy-behind-toca-bocas-digital-worlds/)

### UX & Interaction
11. [NN/g Touch Targets](https://www.nngroup.com/articles/touch-target-size/)
12. [ScienceDirect Touch 3-6](https://www.sciencedirect.com/science/article/abs/pii/S1071581914001426)
13. [NN/g Physical Development](https://www.nngroup.com/articles/children-ux-physical-development/)
14. [Gapsy UX for Kids](https://gapsystudio.com/blog/ux-design-for-kids/)
15. [Ungrammary Kids UX](https://www.ungrammary.com/post/designing-for-kids-ux-design-tips-for-children-apps)

### Psychology & Development
16. [Frontiers Visual Attention](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2022.1069478/full)
17. [PMC Animation EF](https://pmc.ncbi.nlm.nih.gov/articles/PMC8392582/)
18. [PMC Toddler Scrolling](https://pmc.ncbi.nlm.nih.gov/articles/PMC4969291/)
19. [Help Me Grow Milestones](https://helpmegrowmn.org/HMG/DevelopMilestone/CognitiveMilestones/index.html)
20. [Funexpected Math Milestones](https://funexpectedapps.com/en/blog-posts/math-learning-milestones-ages-3-to-7-explained)

### Rewards & Ethics
21. [Akendi Reward Systems](https://www.akendi.com/blog/how-to-create-a-reward-system-that-actually-works/)
22. [ScienceDirect Addiction](https://www.sciencedirect.com/science/article/pii/S0306460323000217)

### Sound & Audio
23. [SciencePress Sound Design](https://www.scitepress.org/Papers/2025/135044/135044.pdf)
24. [ScienceDirect Constructive Feedback Sound](https://www.sciencedirect.com/science/article/abs/pii/S2212868923000181)

### Game Feel & Juice
25. [GameAnalytics Juice](https://www.gameanalytics.com/blog/squeezing-more-juice-out-of-your-game-design)
26. [Blood Moon Juice](https://www.bloodmooninteractive.com/articles/juice.html)
27. [Cascading Animation Timing](https://johndechancie.com/visual-layer-timing-in-cascading-animation-design/)

### Store & Compliance
28. [Google Play Families](https://support.google.com/googleplay/android-developer/answer/9893335)
29. [Apple Kids](https://developer.apple.com/kids/)
30. [Zero to Three Screen Time](https://www.zerotothree.org/resource/screen-time-recommendations-for-children-under-six/)

---

## 11. PERFORMANCE BUDGET — На кожну гру

### 11.1 Загальні ліміти (target: Android 7+, low-end 2017)

| Метрика | Ліміт | Обґрунтування |
|---------|-------|--------------|
| FPS | ≥55 stable (target 60) | Діти чутливі до stuttering — сприймають як "зламане" |
| Частинки на екрані | ≤150 одночасно | Source #6: 200-500 max, ми target low-end |
| Активних emitters | ≤5 одночасно | Source #3: CPU cost scales with emitter count |
| Пам'ять текстур | ≤64MB VRAM | Low-end Android 7 має ~256MB shared |
| Draw calls per frame | ≤100 | gl_compatibility batches, але ліміт для safety |
| GDScript frame budget | ≤4ms _process() | Залишає 12ms для rendering (60fps = 16.6ms) |
| Розмір APK | ≤80MB (base) | Google Play instant delivery threshold |
| Час завантаження сцени | ≤2s | Дитина втрачає увагу при довшому wait |

### 11.2 Per-game particle budget

| Ефект | Max particles | Max emitters | Lifetime cap |
|-------|-------------|-------------|-------------|
| Tap feedback | 16 | 1 | 0.6s |
| Correct answer | 28 (12 sparkle + 16 ripple) | 2 | 0.6s |
| Error smoke | 14 | 1 | 0.8s |
| Level celebration | 120 (across 6 effects) | 5 | 2.0s |
| Confetti rain | 60 (2 waves × 30) | 2 | 1.8s |
| Idle hint glow | 0 (shader only) | 0 | continuous |

---

## 12. FONT & TEXT STANDARDS

### 12.1 Розміри шрифтів по віку

| Елемент | Toddler (2-4) | Preschool (4-7) | Обґрунтування |
|---------|--------------|-----------------|--------------|
| Game title | 48sp | 36sp | Pre-literate потребує великий текст для розпізнавання |
| Button label | 32sp | 24sp | Touch target includes text |
| Score/stars | 40sp | 32sp | Повинно бути видно з відстані руки |
| Math equations | N/A | 36sp | Цифри повинні бути чіткі |
| Instruction text | N/A (voice only) | 24sp | Toddler = тільки озвучення, Preschool = текст + озвучення |

### 12.2 Шрифтові правила

- **Font weight**: Bold для всього ігрового UI (thin шрифти нечитабельні для дітей)
- **Font family**: Rounded sans-serif (Nunito, Comfortaa) — м'які форми = friendly
- **Contrast**: Text on bg ≥ 4.5:1 (WCAG AA). На кольорових фонах — білий текст з тінню
- **Text shadow**: Обов'язковий drop shadow (2px offset, 50% opacity) для читабельності на animated backgrounds
- **Numbers**: Tabular (monospace) figures для лічильників та score — щоб цифри не "стрибали"
- **Letter spacing**: +5% для дітей 2-4 (research: wider spacing improves letter recognition)
- **Line height**: 1.4× для multi-line text

---

## 13. COMBO & STREAK SYSTEM — Ескалація нагород

### 13.1 Дизайн (ethical, mastery-based)

```
Правильна відповідь #1: spawn_correct_sparkle (standard)
Правильна відповідь #2: spawn_correct_sparkle + pitch up +5%
Правильна відповідь #3: spawn_correct_sparkle + spawn_success_ripple + pitch up +10%
Правильна відповідь #5: spawn_golden_burst (premium) + pitch up +15%
Правильна відповідь #7+: spawn_premium_celebration (full cascade) + max pitch
Помилка: reset combo to 0, NO punishment VFX for Toddler
```

### 13.2 Правила

- Combo counter = `_consecutive_correct: int` в BaseMiniGame
- Combo VFX = ДОДАТКОВІ, не замінюючі (standard VFX + combo bonus)
- Combo sound = pitch bend: `AudioManager.play_sfx("correct", 1.0 + _consecutive_correct * 0.05)`
- Toddler: combo завжди рахується (бо помилки не рахуються), але VFX escalation та ж сама
- Combo НЕ впливає на зірки (зірки = тільки через _errors)
- Reset при помилці (Preschool) або при зміні раунду

### 13.3 Обґрунтування

- Source #8 (GameAnalytics): "variable rewards increase engagement"
- НЕ variable ratio (addiction risk) — це EFFORT-based escalation
- Дитина бачить: "я роблю серію правильних → ефекти стають КРАСИВІШИМИ"
- Це intrinsic motivation через visible mastery (Source #21)

---

## 14. ROUND TRANSITION EXPERIENCE

### 14.1 Поточний стан

Між раундами: dissolve.gdshader fade → new content appears. Без VFX, без звуку.

### 14.2 Рекомендований потік

```
Раунд завершено:
  T+0.0s: spawn_correct_sparkle на останній правильній відповіді
  T+0.3s: Dissolve fade-out починається (circle_wipe або dissolve)
  T+0.5s: Soft chime sound "round complete"
  T+0.8s: Dissolve fade-in з новим контентом
  T+1.0s: New content fully visible
  T+1.2s: Card deal-in animation (якщо є карти/предмети)
  T+1.5s: Input enabled, idle timer restarts

Останній раунд:
  T+0.0s: spawn_premium_celebration (full cascade)
  T+0.5s: Level complete overlay slides in
  T+0.8s: Stars animate in (pop-in 1→2→3→4→5)
  T+1.5s: "Молодець!" text + character celebration
```

### 14.3 Звукова палітра

| Подія | Звук | Тривалість |
|-------|------|-----------|
| Round complete | Ascending 3-note chime (C-E-G) | 0.4s |
| Last round complete | Fanfare (full scale C-E-G-C) | 0.8s |
| Dissolve transition | Soft whoosh | 0.3s |
| New content appear | Gentle pop | 0.2s |

---

## 15. AUDIO DESIGN SPECIFICATION — Повна звукова карта

### 15.1 Звукові категорії

| Категорія | Кількість | Формат | Bitrate |
|-----------|----------|--------|---------|
| UI sounds (tap, swipe, button) | 8-10 | OGG Vorbis | 96kbps |
| Correct answer variations | 4-5 | OGG Vorbis | 128kbps |
| Error sound (Preschool) | 2-3 | OGG Vorbis | 96kbps |
| Neutral sound (Toddler error) | 2-3 | OGG Vorbis | 96kbps |
| Celebration fanfares | 3-4 | OGG Vorbis | 128kbps |
| Ambient per theme | 12 | OGG Vorbis | 64kbps (loop) |
| Character voice (Tofie) | 20-30 per language | OGG Vorbis | 128kbps |

### 15.2 Дизайн-правила звуку

- **Randomization**: Для кожної категорії 2-4 варіації → random pick (Source #12: GameDev Academy)
- **Pitch variation**: ±5% random pitch на repeat sounds (запобігає monotonness)
- **Spatial**: Mono for UI, потенційно stereo panning для celebration effects
- **Volume**: UI = 0.7, Music = 0.4, SFX = 0.8, Voice = 1.0 (voice завжди пріоритет)
- **Ducking**: Music volume ×0.3 коли voice грає
- **Silent mode**: Гра повинна бути повністю playable WITHOUT sound (visual-first design)

### 15.3 Голосові підказки (Toddler-critical)

| Тригер | Текст (uk) | Коли |
|--------|-----------|------|
| Game start | "Давай пограємо!" | Перший кадр гри |
| Correct answer | "Молодець!" / "Чудово!" / "Так!" | Random з 3 варіантів |
| Error (Toddler) | "Спробуй ще раз!" | М'яко, не карально |
| Idle hint Lvl1 | "Подивись сюди!" | 5s idle |
| Idle hint Lvl2 | "Ось тут!" (+ tutorial hand) | 15s idle |
| Level complete | "Ти — зірка!" | Після celebration |
| Scaffolding | "Я допоможу! Ось правильна відповідь!" | Після 2T/3P помилок |

**i18n**: Всі голосові підказки × 4 мови (en, uk, fr, es) = 28-40 audio файлів на мову.

---

## 16. TESTING & VERIFICATION STRATEGY

### 16.1 Автоматичне тестування (CI)

| Тест | Що перевіряє | Baseline |
|------|-------------|---------|
| LAW 12 (parse) | Всі 33 скрипти компілюються | 33/33 |
| LAW 29 R7 (ratchet) | Кількість тестів ≥ baseline | ≥48 |
| A5 (star formula) | T=5, P=clampi(5-errors/2,1,5) | PASS |
| A8 (fallback) | ResourceLoader.exists guards | 26+ files |
| QA#10 (VFX lifecycle) | All particles tracked | PASS |

### 16.2 Manual Visual Testing (per-game)

Для КОЖНОЇ гри після зміни:

```
[ ] Запустити гру на Android device або emulator
[ ] Toddler mode: пройти 1 повний цикл (всі раунди)
[ ] Preschool mode: пройти 1 повний цикл
[ ] Перевірити: VFX видно та красиво?
[ ] Перевірити: touch targets достатньо великі? (палець не промахується)
[ ] Перевірити: анімації плавні? (нема stuttering)
[ ] Перевірити: звуки синхронні з візуалом?
[ ] Перевірити: idle hint з'являється через 5s?
[ ] Перевірити: scaffolding працює після 2T/3P помилок?
[ ] Перевірити: celebration cascade на останньому раунді?
[ ] Screenshot "before" та "after" для Quality Ratchet
```

### 16.3 Screenshot Testing (автоматизація)

MCP `screen-capture` tool для порівняння:
1. Запустити гру → дочекатись стабільного кадру → screenshot
2. Зробити дію → screenshot результату
3. Порівняти з baseline screenshot
4. Якщо delta > threshold → flag for review

### 16.4 Performance Testing

```
[ ] FPS counter enabled (Godot debug monitor)
[ ] Play celebration effect → FPS не падає нижче 55
[ ] 5 emitters одночасно → FPS stable
[ ] Memory profiler: VRAM usage під час gameplay
[ ] Launch time: < 2s до першого інтерактивного кадру
```

---

## 17. VFX COMPLETION ROADMAP — Статус

### 17.1 Gradient Enrichment ✅ ЗАВЕРШЕНО

Всі 15 градієнтів збагачені до 4-5 stops. Pattern: bright → lighter → white glow → warm fade → transparent.

### 17.2 Missing VFX — Статус

| Де | Що | Статус |
|----|-----|--------|
| Drag start | spawn_snap_pulse on pickup | ✅ DONE (universal_drag.gd) |
| Drag over target | Particle trail / target pulse | ⏳ Future |
| Drag reject | Smoke puff при snap-back | ⏳ Future |
| Round transition | Sparkle during dissolve | ⏳ Future (30 files) |
| Combo streak | _streak_count + combo_vfx in BaseMiniGame | ✅ EXISTS |
| Menu transitions | Soft particles on open/close | ⏳ Future |

### 17.3 reduced_motion compliance ✅ ЗАВЕРШЕНО

**Статус**: ВСІ 18 spawn_*() функцій мають `if SettingsManager.reduced_motion: return` guard.

Це СИСТЕМНИЙ fix: 1 рядок на кожну з 18 функцій = 18 LOC.
Альтернатива: guard на call site в кожній мініграі (30+ файлів) — гірше.

---

## 18. КОНКРЕТНІ ПАРАМЕТРИ НОВИХ TODDLER-РЕЖИМІВ

### 18.1 "Пригоди коника" (knight_path Toddler)

```
Grid: 3×3 (cell size 200×200dp)
Knight texture: 128×128px, cute cartoon horse
Star texture: 64×64px, animated pulse (glow_pulse shader)
Valid moves: highlighted GREEN (Color("06d6a0"), scale pulse 1.0→1.1)
Invalid moves: dimmed (modulate 0.3)

Round 1: 1 зірка, BFS depth=1 (knight 1 move from star)
Round 2: 1 зірка, BFS depth=2 (knight 2 moves, PATH shown)
Round 3: 2 зірки, BFS depth=1 each (collect both)
Round 4: 2 зірки, BFS depth=2 (path partially shown)
Round 5: 3 зірки, BFS depth=1-2 (no path shown, all valid moves highlighted)

Animation: Knight JUMPS (scale 1→0.8→1.2→1.0, position tween 0.4s EASE_OUT_BACK)
Correct: spawn_correct_sparkle + "Гоп!" sound
All stars collected: spawn_premium_celebration
Errors: NOT counted (Toddler A6), knight wobbles back, click sound
Touch target per cell: 200×200dp (≥15mm on any device)
```

### 18.2 "Космічний улов" (gravity_orbits Toddler)

```
Planet: 180×180dp центр, animated breathing (scale 1.0→1.05, 2s cycle)
Stars: 60×60dp, spawn on circle radius 250dp, move along arc
Star speed: R1=50px/s, R5=100px/s
Catch window: R1=1.2s, R5=0.6s (time star is in "catch zone")
Catch zone: 90° arc around planet (visual: golden glow sector)

Round 1: 1 зірка, slow, huge catch zone
Round 2: 2 зірки, slow
Round 3: 3 зірки, medium speed
Round 4: 3 зірки, medium, smaller catch zone (60°)
Round 5: 4 зірки, faster

Tap planet when star is in zone → planet "eats" star (scale pulse + glow)
Miss: star passes → NO penalty (Toddler A6), star re-spawns
All stars caught: spawn_premium_celebration
Touch target: entire planet (180dp = 30mm+, massive)
```

### 18.3 "Який час?" (analog_clock Toddler)

```
Layout: 3 clock images (200×200dp each), horizontal row
Each clock: clear hour hand only (NO minute hand for Toddler)
Activity icon: 100×100dp above target clock

Activities pool: [
    {time: 7, icon: "sunrise", voice: "Ранок! Сім годин!"},
    {time: 8, icon: "breakfast", voice: "Час снідати! Вісім годин!"},
    {time: 12, icon: "lunch", voice: "Обід! Дванадцять годин!"},
    {time: 15, icon: "play", voice: "Час гратися! Три години!"},
    {time: 18, icon: "dinner", voice: "Вечеря! Шість годин!"},
    {time: 20, icon: "bath", voice: "Час купатися! Вісім вечора!"},
    {time: 21, icon: "sleep", voice: "Спатоньки! Дев'ять годин!"},
]

Round 1-2: 3 clocks, hours differ by ≥3 (e.g., 7, 12, 20)
Round 3-4: 3 clocks, hours differ by ≥2 (e.g., 7, 9, 12)
Round 5: 3 clocks, hours differ by 1 (e.g., 7, 8, 9) — hard

Correct: clock rings (rotation wobble + chime) + activity icon celebration
Error: NOT counted (Toddler), clock gentle shake
Touch target per clock: 200dp (≥15mm)
i18n: voice files × 4 languages × 7 activities = 28 audio files per language
```

### 18.4 "Лічи та знаходь" (math_bingo Toddler)

```
Layout: 2×2 grid (250×250dp cells, huge)
Each cell: dots/items image (1-4 items, concrete objects: apples, stars, balls)
Question: Tofie voice "Знайди ТРИ!" + 3 items displayed top-left

Round 1: numbers 1-3, items are IDENTICAL (all apples)
Round 2: numbers 1-4, items identical
Round 3: numbers 1-4, items MIXED (apples and stars mixed)
Round 4: "Скільки разом?" — show 2 groups (2 apples + 1 apple = ?)
Round 5: "Скільки разом?" — larger groups (3+2=?)

Correct: cell pulses green + spawn_correct_sparkle + "Так! ТРИ!"
Error: NOT counted, cell wobbles, "Спробуй ще!"
Touch target: 250dp per cell (≥20mm, massive)
No text/numbers displayed — ТІЛЬКИ dots/items (zero-text for pre-literate)
```

### 18.5 "Хто це?" (spelling_blocks Toddler)

```
Layout: Animal image 300×300dp top-center
Options: 2-3 cards (180×120dp) bottom row, each with animal image + name

Round 1: 2 cards, very different animals (cat vs elephant)
Round 2: 2 cards, somewhat similar (cat vs dog)
Round 3: 3 cards, different (cat vs dog vs fish)
Round 4: 3 cards, similar (cat vs rabbit vs hamster)
Round 5: 3 cards, audio-only ("Знайди КОТА!" — no image shown top)

Correct: card flies to center + spawn_match_sparkle + animal sound
Error: NOT counted, card wobbles back
Touch target: 180×120dp (≥12mm height, ≥15mm width)

Voice: Tofie says animal name on start of each round
i18n: animal names × 4 languages + voice
```

### 18.6 "Шеф-кухар для тварин" (hungry_pets Preschool)

```
Layout: Animal at table (left, 250dp), Menu (right, 3-4 food cards 120×120dp)
Animal has speech bubble with "?" (hungry face)

Round 1: 3 foods, 1 correct (biological pair), 2 unrelated distractors
Round 2: 3 foods, 1 correct, 1 related distractor (e.g., banana for monkey, also plantain)
Round 3: 4 foods, 1 correct, 2 related + 1 unrelated
Round 4: 4 foods, 1 correct, 3 related (hard)
Round 5: 4 foods, animal shown as SILHOUETTE (guess animal + food)

Correct: drag food to table → animal eats (happy animation) + celebration
Error: _register_error(), smoke VFX, food snaps back, "Ні, спробуй інше!"
Stars: clampi(5 - errors/2, 1, 5)
Touch target per food: 120dp (≥10mm)

Content: 19 animal-food pairs from GameData, _used_indices prevents repeat
```

---

## 19. PER-GAME TOUCH TARGET AUDIT

### 19.1 Поточні проблемні місця (з тестів QA#9)

| Файл | Константа | Значення | Мінімум | Статус |
|------|-----------|---------|---------|--------|
| analog_clock.gd:20 | TICK_OUTER_RADIUS | 8dp | N/A | ℹ️ Decorative tick marks, not touch targets. Toddler mode uses 200dp clocks |
| color_pop.gd:28 | PRESCHOOL_RADIUS | 45dp | 48dp | ✅ FIXED (was 35dp) |
| compare_game.gd:8 | ITEM_RADIUS | 38dp | 48dp | ⚠️ Збільшити до 50dp |
| counting_game.gd:8 | ITEM_RADIUS | 45dp | 48dp | ⚠️ Збільшити до 50dp |
| gravity_orbits.gd:14 | PLANET_RADIUS | 40dp | 60dp | ⚠️ Збільшити до 65dp |
| gravity_orbits.gd:15 | SAT_RADIUS | 14dp | N/A | ℹ️ Preschool visual only (physics sim). Toddler mode uses 180dp planet tap target |
| pattern_builder.gd:8 | ITEM_RADIUS | 40dp | 48dp | ⚠️ Збільшити до 50dp |
| sorting_game.gd:10 | ZONE_CORNER_RADIUS | 20dp | N/A | Це corner, не target |

### 19.2 Рекомендовані мінімуми

| Тип елемента | Toddler | Preschool |
|-------------|---------|-----------|
| Primary button | 80dp | 60dp |
| Game item (tap target) | 70dp | 50dp |
| Card/tile | 100dp | 80dp |
| Drag handle | 80dp (+ magnetic 20dp assist zone) | 60dp |
| Back/settings button | 48dp | 48dp |

---

## 20. PRIVACY & LEGAL COMPLIANCE (Деталі)

### 20.1 Google Play Data Safety Section

| Питання | Відповідь | Обґрунтування |
|---------|----------|--------------|
| Does app collect data? | No | Analytics = stub, no real collection |
| Does app share data? | No | Zero third-party SDKs |
| Is data encrypted? | Yes | save.save uses random key |
| Can users request deletion? | Yes | Uninstall deletes all data |
| Data types collected | None | No PII, no device ID, no usage analytics |

### 20.2 Privacy Policy (обов'язковий для обох store)

Повинна містити:
- [ ] Заява що додаток НЕ збирає персональні дані
- [ ] Заява що додаток НЕ містить реклами
- [ ] Заява що додаток НЕ містить in-app purchases
- [ ] Контактна інформація розробника
- [ ] Опис parental gate mechanism
- [ ] Пояснення що save data зберігається ТІЛЬКИ локально
- [ ] Відповідність COPPA та GDPR-K
- URL: має бути доступний публічно (наприклад, GitHub Pages або landing page)

### 20.3 Age Rating Questionnaire

| Платформа | Rating | Обґрунтування |
|-----------|--------|--------------|
| Google Play | Everyone (E) | Нема violence, нема gambling, нема mature content |
| Apple App Store | 4+ | Найнижча категорія, відповідає контенту |
| PEGI | 3 | Suitable for all ages |

---

## 21. I18N CONTENT EXPANSION PLAN

### 21.1 spelling_blocks — Нові слова (8→20)

| # | EN | UK | FR | ES | Letters |
|---|----|----|----|----|---------|
| 1 | CAT | КІТ | CHAT | GATO | 3-4 |
| 2 | DOG | ПЕС | CHIEN | PERRO | 3-5 |
| 3 | COW | КОРОВА | VACHE | VACA | 3-6 |
| 4 | PIG | СВИНЯ | COCHON | CERDO | 3-6 |
| 5 | HEN | КУРКА | POULE | GALLINA | 3-7 |
| 6 | BEE | БДЖОЛА | ABEILLE | ABEJA | 3-7 |
| 7 | FOX | ЛИС | RENARD | ZORRO | 3-6 |
| 8 | OWL | СОВА | HIBOU | BÚHO | 3-5 |
| 9 | RAM | БАРАН | BÉLIER | CARNERO | 3-7 |
| 10 | ANT | МУРАХА | FOURMI | HORMIGA | 3-7 |
| 11 | BAT | КАЖАН | CHAUVE | MURCIÉLAGO | 3-11 |
| 12 | BUG | ЖУК | INSECTE | BICHO | 3-7 |
| 13 | CUB | ВЕДМЕЖА | OURSON | CACHORRO | 3-8 |
| 14 | EEL | ВУГОР | ANGUILLE | ANGUILA | 3-8 |
| 15 | FLY | МУХА | MOUCHE | MOSCA | 3-6 |
| 16 | JAM | ДЖЕМ | CONFITURE | MERMELADA | 3-9 |
| 17 | MOP | ШВАБРА | BALAI | FREGONA | 3-7 |
| 18 | SUN | СОНЦЕ | SOLEIL | SOL | 3-6 |
| 19 | BUS | АВТОБУС | BUS | AUTOBÚS | 3-7 |
| 20 | CUP | ЧАШКА | TASSE | TAZA | 3-6 |

**Важливо**: FR/ES слова довші → difficulty auto-scales з довжиною слова.

### 21.2 color_lab — Нові рецепти (4→9)

| # | Інгредієнти | Результат | Tier |
|---|------------|----------|------|
| 1 | Red + Yellow | Orange | 1 (basic) |
| 2 | Blue + Yellow | Green | 1 |
| 3 | Red + Blue | Purple | 1 |
| 4 | Red + White | Pink | 2 |
| 5 | Blue + White | Light Blue | 2 |
| 6 | Yellow + White | Cream | 2 |
| 7 | Orange + Blue | Brown | 3 (advanced) |
| 8 | Purple + Yellow | Olive | 3 |
| 9 | Green + Red | Dark Brown | 3 |

### 21.3 weather_dress — Нові погоди (4→8)

| # | Погода | Одяг (correct) | Дистрактор |
|---|--------|---------------|------------|
| 1 | ☀️ Сонячно | Футболка, шорти, кепка | Куртка, парасолька |
| 2 | 🌧️ Дощ | Дощовик, парасолька, гумаки | Шорти, сонцезахисні |
| 3 | ❄️ Сніг | Куртка, шапка, рукавиці | Футболка, шорти |
| 4 | 💨 Вітер | Вітровка, шарф | Парасолька, купальник |
| 5 | 🌫️ Туман | Яскравий жилет, куртка | Сонцезахисні, шорти |
| 6 | ⛈️ Гроза | Дощовик, гумаки, парасолька | Кепка, футболка |
| 7 | 🌡️ Спека | Купальник, сонцезахисні, кепка | Куртка, шарф |
| 8 | 🍂 Осінь | Светр, чоботи, парасолька | Купальник, шорти |
