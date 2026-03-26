# Промт для Claude — ProjectKOS

> Скопіюй в Claude Code сесію ProjectKOS. Короткий = ефективний (research: quality drops with instruction count).

---

полный цикл

Ти працюєш над "Tofie Play & Learn Adventures" — дитяча освітня гра, Godot 4.6, діти 2-7 років.

## Правила (ПОРУШЕННЯ = БАГ)

1. **ДУМАЙ ПЕРЕД КОДОМ**: `<thinking>` блок з аналізом 30 законів (GAME_DESIGN_LAWS.md) та 12 аксіом (GAME_DESIGN_BIBLE.md). Без цього — не пиши код.

2. **ТРИ ТИПИ РАССУЖДЕНИЯ**:
   - ДЕДУКЦІЯ: "З LAW 13 (Numeric Safety) для ЦІЄЇ задачі слідує [X]"
   - АБДУКЦІЯ: "Симптоми [A,B] → найкраще пояснення: [root cause]"
   - ІНДУКЦІЯ: "В існуючих іграх паттерн [X] → для нової гри [Y]"

3. **КОЖНА ГРА РОЗВИВАЄ КОНКРЕТНУ НАВИЧКУ**: назви її ПЕРЕД початком роботи. Якщо не можеш — СТОП, подумай глибше.

4. **GAMEPLAY LOOP = LEARNING LOOP**: гра і навчання НЕ розділені. Дитина вчиться ГРАЮЧИ, не "відповідаючи на тест". Micro-reward кожні 3-5 секунд. (Research: variable rewards reduce errors by 49%)

5. **TODDLER (2-4) ≠ PRESCHOOL (4-7)**: Toddler = ЗАВЖДИ 5 зірок, БЕЗ покарання, magnetic assist. Preschool = формула зірок, error tracking, складніший контент.

6. **АНТИ-ПАТЕРНИ** (ЗАБОРОНЕНО):
   - `pool[0]` без `pool.size()` check (LAW 13)
   - `dict[key]` без `.has()` (LAW 17)
   - await без `is_instance_valid()` (LAW 20)
   - Хардкоджені зірки замість `_calculate_stars()` (LAW 16)
   - `return` без `push_warning()` (QA #1)
   - TODO/FIXME в коміті

7. **ПЕРЕД COMMIT**: таблиця 30 законів (✅/❌), 12 аксіом, тести.

## Ключові файли (ПРОЧИТАЙ)

- `ARCHITECTURE.md` — структура проекту
- `GAME_DESIGN_LAWS.md` — 30 законів
- `GAME_DESIGN_BIBLE.md` — 12 аксіом + аудит 30 ігор
- `BaseMiniGame.gd` — 70+ helpers (1874 рядки)
- `QA_PROTOCOLS.md` — правила якості

## Філософія

Кожна гра = замкнутий автомат з чіткими правилами. Якщо правило неможливо пояснити 3-річній дитині за 5 секунд анімації — правило зламане.

Якщо потрібно ЗЛАМАТИ і ПЕРЕРОБИТИ щоб гра стала справжньою — РОБИ. Не спрощуй. Не залишай наполовину. Кожна гра повинна бути ПРОДУМАНОЮ від початку до кінця — з логікою, прогресією, і справжнім розвитком дитини.

Sources:

- [HumanLayer: Writing a good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md)
- [Arize: CLAUDE.md Best Practices](https://arize.com/blog/claude-md-best-practices-learned-from-optimizing-claude-code-with-prompt-learning/)
- [Gameplay Loop Methodology (ResearchGate)](https://www.researchgate.net/publication/337869698)
- [Game-Based Learning Meta-Analysis (Frontiers)](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2024.1307881/full)
- [PromptHub: Prompt Engineering for Agents](https://www.prompthub.us/blog/prompt-engineering-for-ai-agents)
- [Augment Code: 11 Prompting Techniques](https://www.augmentcode.com/blog/how-to-build-your-agent-11-prompting-techniques-for-better-ai-agents)
