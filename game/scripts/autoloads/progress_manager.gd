extends Node

## Прогрес гравця — зірки, тварини, рекорди, щоденні квести, підказки.

var stars: int = 0
var unlocked_animals: Array = []
var best_time_sec: int = 9999
var best_errors: int = 9999
var total_animals_fed: int = 0
var achievement_100_fed: bool = false
var games_played: int = 0
var has_seen_tutorial: bool = false
var highest_level_unlocked: int = 1
var inventory_hints: int = 3
var games_played_today: int = 0
var daily_quest_completed: bool = false
var _played_games: Array[String] = []

## Колекція стікерів — animal_name -> {games_earned: Array, total_stars: int}
var sticker_collection: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func get_save_data() -> Dictionary:
	return {
		"stars": stars,
		"unlocked_animals": unlocked_animals,
		"best_time_sec": best_time_sec,
		"best_errors": best_errors,
		"total_animals_fed": total_animals_fed,
		"achievement_100_fed": achievement_100_fed,
		"games_played": games_played,
		"has_seen_tutorial": has_seen_tutorial,
		"highest_level_unlocked": highest_level_unlocked,
		"inventory_hints": inventory_hints,
		"games_played_today": games_played_today,
		"daily_quest_completed": daily_quest_completed,
		"played_games": _played_games,
		"sticker_collection": sticker_collection.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> void:
	stars = maxi(0, int(data.get("stars", data.get("coins", 0))))
	unlocked_animals = data.get("unlocked_animals", [])
	best_time_sec = maxi(0, int(data.get("best_time_sec", 9999)))
	best_errors = maxi(0, int(data.get("best_errors", 9999)))
	total_animals_fed = maxi(0, int(data.get("total_animals_fed", 0)))
	achievement_100_fed = data.get("achievement_100_fed", false)
	games_played = maxi(0, int(data.get("games_played", 0)))
	has_seen_tutorial = data.get("has_seen_tutorial", false)
	highest_level_unlocked = maxi(1, int(data.get("highest_level_unlocked", 1)))
	inventory_hints = maxi(0, int(data.get("inventory_hints", 3)))
	games_played_today = maxi(0, int(data.get("games_played_today", 0)))
	daily_quest_completed = data.get("daily_quest_completed", false)
	var pg: Array = data.get("played_games", [])
	_played_games.clear()
	for g: Variant in pg:
		_played_games.append(str(g))

	## LAW 22: Валідація sticker_collection — corrupted save не зламає гру
	var loaded_stickers: Variant = data.get("sticker_collection", {})
	sticker_collection = loaded_stickers if loaded_stickers is Dictionary else {}


func has_played_game(gid: String) -> bool:
	return _played_games.has(gid)


func mark_game_played(gid: String) -> void:
	if not _played_games.has(gid):
		_played_games.append(gid)
		SettingsManager.save_settings()


func add_stars(amount: int) -> void:
	stars = maxi(0, stars + amount)
	SettingsManager.save_settings()


func unlock_animal(animal_name: String) -> bool:
	if unlocked_animals.has(animal_name):
		push_warning("ProgressManager: тварина '%s' вже розблокована" % animal_name)
		return false
	unlocked_animals.append(animal_name)
	SettingsManager.save_settings()
	return true


func is_animal_unlocked(animal_name: String) -> bool:
	return unlocked_animals.has(animal_name)


func check_new_record(time_sec: int, errors: int) -> bool:
	if errors < best_errors or (errors == best_errors and time_sec < best_time_sec):
		best_errors = errors
		best_time_sec = time_sec
		SettingsManager.save_settings()
		return true
	return false


func increment_animals_fed() -> bool:
	total_animals_fed += 1
	if total_animals_fed >= 100 and not achievement_100_fed:
		achievement_100_fed = true
		add_stars(500)
		return true
	SettingsManager.save_settings()
	return false


func increment_games_played() -> bool:
	games_played += 1
	games_played_today += 1
	if games_played_today == 3 and not daily_quest_completed:
		daily_quest_completed = true
		add_stars(300)
		return true
	SettingsManager.save_settings()
	return false


func buy_hints(amount: int, cost: int) -> bool:
	if stars < cost:
		push_warning("ProgressManager: недостатньо зірок для підказок (%d < %d)" % [stars, cost])
		return false
	add_stars(-cost)
	inventory_hints += amount
	SettingsManager.save_settings()
	return true


func use_hint() -> bool:
	if inventory_hints <= 0:
		push_warning("ProgressManager: немає підказок для використання")
		return false
	inventory_hints -= 1
	SettingsManager.save_settings()
	return true


## ── Стікери (колекція нагород за 3+ зірки) ─────────────────────────────────

## Нагороджує стікером за тварину. Повертає true якщо НОВА тварина (перший раз).
func earn_sticker(animal_name: String, game_id: String, stars: int) -> bool:
	if animal_name.is_empty():
		push_warning("ProgressManager: earn_sticker — порожнє animal_name")
		return false
	if game_id.is_empty():
		push_warning("ProgressManager: earn_sticker — порожній game_id")
		return false

	var is_new: bool = not sticker_collection.has(animal_name)
	var entry: Dictionary = sticker_collection.get(animal_name, {"games_earned": [], "total_stars": 0})

	## Додаємо game_id лише якщо ще не зароблений у цій грі
	var games: Array = entry.get("games_earned", [])
	if not games.has(game_id):
		games.append(game_id)
	entry["games_earned"] = games
	entry["total_stars"] = int(entry.get("total_stars", 0)) + stars
	sticker_collection[animal_name] = entry
	SettingsManager.save_settings()
	return is_new


## Кількість унікальних тварин зі стікерами.
func get_sticker_count() -> int:
	return sticker_collection.size()


## Чи є стікер для конкретної тварини.
func has_sticker(animal_name: String) -> bool:
	return sticker_collection.has(animal_name)
