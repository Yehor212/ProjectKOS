extends Node

## Крос-сесійний трекінг навичок, адаптивна складність, колекція тварин.
## Інтегрується з SettingsManager через get_save_data()/apply_save_data().

## ── Сигнали ──────────────────────────────────────────────────────────────────
signal mastery_changed(skill_id: String, old_level: int, new_level: int)
signal collection_tier_changed(animal_name: String, new_tier: int)
signal milestone_reached(milestone_name: String)

## ── Константи ────────────────────────────────────────────────────────────────
## Рівні майстерності
const MASTERY_UNKNOWN: int = 0       ## Ніколи не грав
const MASTERY_INTRODUCED: int = 1    ## Грав, <50% успіху
const MASTERY_DEVELOPING: int = 2    ## 50-79% успіху
const MASTERY_PROFICIENT: int = 3    ## 80-89% успіху
const MASTERY_MASTERED: int = 4      ## 90%+ протягом 3+ сесій

## Тварини — тіри колекції
const TIER_NONE: int = 0
const TIER_MET: int = 1
const TIER_FED: int = 2
const TIER_BEST_FRIEND: int = 3

## Вікно продуктивності — кількість останніх спроб
const PERFORMANCE_WINDOW_SIZE: int = 7

## Пороги для адаптивної складності
const DIFFICULTY_INCREASE_THRESHOLD: float = 0.80
const DIFFICULTY_DECREASE_THRESHOLD: float = 0.50

## Пороги для рівнів майстерності
const MASTERY_THRESHOLD_INTRODUCED: float = 0.0  ## Будь-яка спроба
const MASTERY_THRESHOLD_DEVELOPING: float = 0.50
const MASTERY_THRESHOLD_PROFICIENT: float = 0.80
const MASTERY_THRESHOLD_MASTERED: float = 0.90
const MASTERY_SESSIONS_FOR_MASTERED: int = 3

## Leitner box інтервали (в сесіях)
const LEITNER_INTERVALS: Array[int] = [1, 2, 5, 14]
const LEITNER_MAX_BOX: int = 3

## ZPD розподіл вибору ігор
const ZPD_WEIGHT: float = 0.60      ## 60% — ігри в зоні розвитку (mastery 1-2)
const MASTERED_WEIGHT: float = 0.20  ## 20% — освоєні ігри (впевненість)
const NEW_WEIGHT: float = 0.20      ## 20% — нові ігри (дослідження)

## ── Дані (зберігаються) ──────────────────────────────────────────────────────
## skill_id -> int (0-4)
var _skill_mastery: Dictionary = {}

## game_id -> Array[bool] (останні PERFORMANCE_WINDOW_SIZE спроб)
var _performance_windows: Dictionary = {}

## skill_id -> int (кількість сесій з успіхом >= порогу)
var _skill_session_counts: Dictionary = {}

## game_id -> int (Leitner box 0-3)
var _leitner_boxes: Dictionary = {}

## game_id -> int (остання сесія, коли грали)
var _leitner_last_session: Dictionary = {}

## animal_name -> int (TIER_NONE..TIER_BEST_FRIEND)
var _collection_tiers: Dictionary = {}

## Лічильник сесій
var _session_count: int = 0

## Дата останньої сесії (для уникнення подвійного рахування)
var _last_session_date: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_increment_session_if_new_day()


## ── Публічний API ────────────────────────────────────────────────────────────

## Записує спробу гравця. Викликається грою після кожного раунду.
func record_attempt(game_id: String, skill_id: String, correct: bool) -> void:
	if game_id.is_empty():
		push_warning("MasteryManager: record_attempt — порожній game_id")
		return
	if skill_id.is_empty():
		push_warning("MasteryManager: record_attempt — порожній skill_id")
		return

	## Оновити вікно продуктивності для гри
	_append_to_window(game_id, correct)

	## Оновити Leitner box
	_update_leitner(game_id, correct)

	## Перерахувати рівень майстерності навички
	_recalculate_mastery(skill_id, game_id)

	SettingsManager.save_settings()


## Повертає поточний рівень майстерності навички (0-4).
func get_mastery_level(skill_id: String) -> int:
	if skill_id.is_empty():
		push_warning("MasteryManager: get_mastery_level — порожній skill_id")
		return MASTERY_UNKNOWN
	return int(_skill_mastery.get(skill_id, MASTERY_UNKNOWN))


## Повертає зсув складності для гри: -1 (легше), 0 (норма), +1 (складніше).
func get_difficulty_offset(game_id: String) -> int:
	if game_id.is_empty():
		push_warning("MasteryManager: get_difficulty_offset — порожній game_id")
		return 0
	var rate: float = _calculate_success_rate(game_id)
	## Немає даних — залишити стандартну складність
	if rate < 0.0:
		return 0
	if rate >= DIFFICULTY_INCREASE_THRESHOLD:
		return 1
	if rate < DIFFICULTY_DECREASE_THRESHOLD:
		return -1
	return 0


## Обирає наступну гру з доступних за ZPD-розподілом.
func pick_next_game(available_games: Array[String]) -> String:
	if available_games.size() == 0:
		push_warning("MasteryManager: pick_next_game — порожній масив ігор")
		return ""

	## Категоризуємо ігри
	var zpd_games: Array[String] = []      ## mastery 1-2 (зона розвитку)
	var mastered_games: Array[String] = []  ## mastery 3-4
	var new_games: Array[String] = []       ## mastery 0

	for gid: String in available_games:
		var skill: String = _get_skill_for_game(gid)
		var level: int = get_mastery_level(skill)
		if level == MASTERY_UNKNOWN:
			new_games.append(gid)
		elif level <= MASTERY_DEVELOPING:
			zpd_games.append(gid)
		else:
			mastered_games.append(gid)

	## Фільтр: тільки ігри, які потрібно повторити за Leitner
	var due_games: Array[String] = _filter_due_games(available_games)
	## Якщо є прострочені ігри з Leitner — пріоритет їм
	if due_games.size() > 0:
		return due_games[randi() % due_games.size()]

	## Зважений випадковий вибір за ZPD-розподілом
	var roll: float = randf()
	if roll < ZPD_WEIGHT and zpd_games.size() > 0:
		return zpd_games[randi() % zpd_games.size()]
	elif roll < ZPD_WEIGHT + MASTERED_WEIGHT and mastered_games.size() > 0:
		return mastered_games[randi() % mastered_games.size()]
	elif new_games.size() > 0:
		return new_games[randi() % new_games.size()]

	## Фолбек — будь-яка доступна гра
	return available_games[randi() % available_games.size()]


## Повертає тір колекції тварини (0-3).
func get_collection_tier(animal_name: String) -> int:
	if animal_name.is_empty():
		push_warning("MasteryManager: get_collection_tier — порожнє ім'я тварини")
		return TIER_NONE
	return int(_collection_tiers.get(animal_name, TIER_NONE))


## Реєструє взаємодію з твариною. interaction: "meet", "feed", "bond".
func record_animal_interaction(animal_name: String, interaction: String) -> void:
	if animal_name.is_empty():
		push_warning("MasteryManager: record_animal_interaction — порожнє ім'я")
		return
	if interaction.is_empty():
		push_warning("MasteryManager: record_animal_interaction — порожня взаємодія")
		return

	var current_tier: int = get_collection_tier(animal_name)
	var new_tier: int = current_tier

	match interaction:
		"meet", "played":
			if current_tier < TIER_MET:
				new_tier = TIER_MET
		"feed":
			if current_tier < TIER_FED:
				new_tier = TIER_FED
		"bond":
			new_tier = TIER_BEST_FRIEND
		_:
			push_warning("MasteryManager: невідома взаємодія '%s'" % interaction)
			return

	if new_tier != current_tier:
		_collection_tiers[animal_name] = new_tier
		collection_tier_changed.emit(animal_name, new_tier)
		_check_collection_milestones()
		SettingsManager.save_settings()


## Повертає загальну кількість сесій.
func get_session_count() -> int:
	return _session_count


## Повертає кількість тварин на конкретному тірі або вище.
func get_animals_at_tier(min_tier: int) -> int:
	var count: int = 0
	for tier: Variant in _collection_tiers.values():
		if int(tier) >= min_tier:
			count += 1
	return count


## Повертає Leitner box для гри (0-3).
func get_leitner_box(game_id: String) -> int:
	return int(_leitner_boxes.get(game_id, 0))


## ── Серіалізація (інтеграція з SettingsManager) ─────────────────────────────

func get_save_data() -> Dictionary:
	return {
		"mastery_skill_mastery": _skill_mastery.duplicate(),
		"mastery_performance_windows": _serialize_windows(),
		"mastery_skill_session_counts": _skill_session_counts.duplicate(),
		"mastery_leitner_boxes": _leitner_boxes.duplicate(),
		"mastery_leitner_last_session": _leitner_last_session.duplicate(),
		"mastery_collection_tiers": _collection_tiers.duplicate(),
		"mastery_session_count": _session_count,
		"mastery_last_session_date": _last_session_date,
	}


func apply_save_data(data: Dictionary) -> void:
	## LAW 22: Валідація — corrupted save не зламає гру
	var loaded_mastery: Variant = data.get("mastery_skill_mastery", {})
	_skill_mastery = loaded_mastery if loaded_mastery is Dictionary else {}

	var loaded_windows: Variant = data.get("mastery_performance_windows", {})
	if loaded_windows is Dictionary:
		_deserialize_windows(loaded_windows)
	else:
		push_warning("MasteryManager: performance_windows corrupted, resetting")
		_performance_windows = {}

	var loaded_sessions: Variant = data.get("mastery_skill_session_counts", {})
	_skill_session_counts = loaded_sessions if loaded_sessions is Dictionary else {}

	var loaded_leitner: Variant = data.get("mastery_leitner_boxes", {})
	_leitner_boxes = loaded_leitner if loaded_leitner is Dictionary else {}

	var loaded_leitner_last: Variant = data.get("mastery_leitner_last_session", {})
	_leitner_last_session = loaded_leitner_last if loaded_leitner_last is Dictionary else {}

	var loaded_collection: Variant = data.get("mastery_collection_tiers", {})
	_collection_tiers = loaded_collection if loaded_collection is Dictionary else {}

	_session_count = maxi(0, int(data.get("mastery_session_count", 0)))
	_last_session_date = str(data.get("mastery_last_session_date", ""))


## ── Внутрішні методи ─────────────────────────────────────────────────────────

## Інкремент сесії якщо новий день (або перший запуск).
func _increment_session_if_new_day() -> void:
	var today: String = Time.get_date_string_from_system()
	if today != _last_session_date:
		_session_count += 1
		_last_session_date = today


## Додає результат у вікно продуктивності гри (max PERFORMANCE_WINDOW_SIZE).
func _append_to_window(game_id: String, correct: bool) -> void:
	if not _performance_windows.has(game_id):
		_performance_windows[game_id] = []
	var window: Array = _performance_windows[game_id]
	window.append(correct)
	## Обрізаємо до розміру вікна
	while window.size() > PERFORMANCE_WINDOW_SIZE:
		window.pop_front()


## Розраховує відсоток успіху для гри. Повертає -1.0 якщо даних немає.
func _calculate_success_rate(game_id: String) -> float:
	if not _performance_windows.has(game_id):
		return -1.0
	var window: Array = _performance_windows[game_id]
	if window.size() == 0:
		return -1.0
	var correct_count: int = 0
	for entry: Variant in window:
		if entry == true:
			correct_count += 1
	## LAW 13: window.size() гарантовано > 0 тут (перевірено вище)
	return float(correct_count) / float(window.size())


## Перераховує рівень майстерності навички на основі продуктивності.
func _recalculate_mastery(skill_id: String, game_id: String) -> void:
	var old_level: int = get_mastery_level(skill_id)
	var rate: float = _calculate_success_rate(game_id)

	## Немає даних — навичка тепер "Introduced" (гравець спробував)
	if rate < 0.0:
		if old_level == MASTERY_UNKNOWN:
			_skill_mastery[skill_id] = MASTERY_INTRODUCED
			mastery_changed.emit(skill_id, old_level, MASTERY_INTRODUCED)
		return

	var new_level: int = MASTERY_INTRODUCED

	if rate >= MASTERY_THRESHOLD_MASTERED:
		## Потрібно 3+ сесій з високим результатом
		var session_hits: int = int(_skill_session_counts.get(skill_id, 0))
		if rate >= MASTERY_THRESHOLD_PROFICIENT:
			## Рахуємо цю сесію як успішну
			_skill_session_counts[skill_id] = session_hits + 1
			session_hits += 1
		if session_hits >= MASTERY_SESSIONS_FOR_MASTERED:
			new_level = MASTERY_MASTERED
		else:
			new_level = MASTERY_PROFICIENT
	elif rate >= MASTERY_THRESHOLD_PROFICIENT:
		new_level = MASTERY_PROFICIENT
		## Також рахуємо сесію
		var session_hits: int = int(_skill_session_counts.get(skill_id, 0))
		_skill_session_counts[skill_id] = session_hits + 1
	elif rate >= MASTERY_THRESHOLD_DEVELOPING:
		new_level = MASTERY_DEVELOPING
	else:
		new_level = MASTERY_INTRODUCED

	## Майстерність тільки зростає (не падає) — дитина не повинна "втрачати" прогрес
	if new_level > old_level:
		_skill_mastery[skill_id] = new_level
		mastery_changed.emit(skill_id, old_level, new_level)


## Оновлює Leitner box для гри.
func _update_leitner(game_id: String, correct: bool) -> void:
	var current_box: int = int(_leitner_boxes.get(game_id, 0))
	if correct:
		## Просування вгору (max = LEITNER_MAX_BOX)
		_leitner_boxes[game_id] = mini(current_box + 1, LEITNER_MAX_BOX)
	else:
		## Повернення до box 0
		_leitner_boxes[game_id] = 0
	_leitner_last_session[game_id] = _session_count


## Фільтрує ігри, які "прострочені" за Leitner-розкладом.
func _filter_due_games(available_games: Array[String]) -> Array[String]:
	var due: Array[String] = []
	for gid: String in available_games:
		if not _leitner_boxes.has(gid):
			continue  ## Ще не грали — не Leitner-кандидат
		var box: int = int(_leitner_boxes.get(gid, 0))
		var last_session: int = int(_leitner_last_session.get(gid, 0))
		var interval: int = LEITNER_INTERVALS[0]
		if box >= 0 and box < LEITNER_INTERVALS.size():
			interval = LEITNER_INTERVALS[box]
		var sessions_since: int = _session_count - last_session
		if sessions_since >= interval:
			due.append(gid)
	return due


## Визначає skill_id для гри через GameCatalog.
func _get_skill_for_game(game_id: String) -> String:
	var game: Dictionary = GameCatalog.get_game_by_id(game_id)
	if game.size() == 0:
		push_warning("MasteryManager: _get_skill_for_game — гру '%s' не знайдено" % game_id)
		return game_id  ## Фолбек: використовуємо game_id як skill_id
	return game.get("skill_key", game_id)


## Перевіряє досягнення колекції.
func _check_collection_milestones() -> void:
	var met_count: int = get_animals_at_tier(TIER_MET)
	var fed_count: int = get_animals_at_tier(TIER_FED)
	var best_count: int = get_animals_at_tier(TIER_BEST_FRIEND)

	if met_count >= 5:
		milestone_reached.emit("explorer_5")
	if met_count >= 19:
		milestone_reached.emit("explorer_all")
	if fed_count >= 10:
		milestone_reached.emit("feeder_10")
	if fed_count >= 19:
		milestone_reached.emit("feeder_all")
	if best_count >= 5:
		milestone_reached.emit("best_friend_5")
	if best_count >= 19:
		milestone_reached.emit("best_friend_all")


## ── Серіалізація вікон продуктивності ────────────────────────────────────────
## Зберігаємо як Dictionary[String, Array] де Array містить bool-и.

func _serialize_windows() -> Dictionary:
	var result: Dictionary = {}
	for game_id: String in _performance_windows:
		var window: Array = _performance_windows[game_id]
		## Конвертуємо в масив int для надійної серіалізації
		var serialized: Array[int] = []
		for entry: Variant in window:
			serialized.append(1 if entry == true else 0)
		result[game_id] = serialized
	return result


func _deserialize_windows(data: Dictionary) -> void:
	_performance_windows = {}
	for game_id: Variant in data:
		var gid: String = str(game_id)
		var serialized: Variant = data[game_id]
		if not serialized is Array:
			push_warning("MasteryManager: window для '%s' не є Array, пропускаємо" % gid)
			continue
		var window: Array = []
		for entry: Variant in serialized:
			window.append(int(entry) == 1)
		## Обрізаємо на випадок corrupted збереження
		while window.size() > PERFORMANCE_WINDOW_SIZE:
			window.pop_front()
		_performance_windows[gid] = window
