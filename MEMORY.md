# MEMORY.md — ProjectKOS Session Memory

> Этот файл хранит ключевые решения и состояние между сессиями Claude Code.
> Обновляй после каждой значимой сессии.

## Текущее состояние
- **Версия**: V141 (ARCHITECTURE.md)
- **Реализовано игр**: 28/30 (+ food_game = 29)
- **Roadmap прогресс**: 32/33 (97%)
- **Test baseline**: 47+ тестов
- **Агентов**: 13 (все Opus 4.6)

## Известные проблемы
- Все 28 игр механически правильные, но СКУЧНЫЕ (нет WOW-эффекта)
- Социально-эмоциональное развитие: 0 игр (критический gap)
- Грамотность: только 1 игра (spelling_blocks)
- BaseMiniGame: 1887 строк (tech debt, но рефакторить опасно)
- AnalyticsManager: stub (только console.log)
- Voice-over: не записан (28+ файлов x 4 языка)

## Принятые решения
- [2026-03-26] Все агенты переведены на Opus 4.6 (были Sonnet)
- [2026-03-26] gameplay-architect получил мандат на ПОЛНЫЙ редизайн всех игр
- [2026-03-26] Добавлен vector-animator (вместо visual-artist) с фокусом на эмоции
- [2026-03-26] Добавлены 5 новых агентов: content-curator, i18n-guardian, performance-profiler, accessibility-advisor, release-manager
- [2026-03-26] Добавлены PostToolUse и Stop хуки
- [2026-03-26] Создана система skills (/game-qa, /postflight, /new-game, /add-animal)

## Что НЕ трогать
- Кнопки главного меню, паузы, настроек (заказчику нравятся)
- Фоны игр (заказчику нравятся)
- 30 Laws и 12 Axioms (нарушение = баг)
- BaseMiniGame публичный API (расширять можно, ломать нельзя)
