class_name GameCatalog
extends RefCounted

## Статичний реєстр усіх 30 міні-ігор платформи.
## Кожна гра має унікальний колір, іконку та ключ перекладу.

## Вікові категорії:
## ALL = доступно всім (2-7 років)
## TODDLER = 2-4 роки (прості ігри, великі елементи, м'який feedback)
## PRESCHOOL = 5-7 років (складніші ігри, потребують читання/лічби)
## OVERLAP = 3-5 років (підходить обом групам, але з різною складністю)
enum AgeCategory { ALL = 0, TODDLER = 1, PRESCHOOL = 2, OVERLAP = 3 }

const GAMES: Array[Dictionary] = [
	{
		"id": "hungry_pets",
		"name_key": "GAME_HUNGRY_PETS",
		"desc_key": "DESC_HUNGRY_PETS",
		"skill_key": "SKILL_HUNGRY_PETS",
		"icon": "fork_knife",
		"color": Color("06d6a0"),
		"scene_path": "res://scenes/main/food_game.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "shadow_match",
		"name_key": "GAME_SHADOW_MATCH",
		"desc_key": "DESC_SHADOW_MATCH",
		"skill_key": "SKILL_SHADOW_MATCH",
		"icon": "ghost",
		"color": Color("7b68ee"),
		"scene_path": "res://scenes/main/shadow_match.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "memory",
		"name_key": "GAME_MEMORY",
		"desc_key": "DESC_MEMORY",
		"skill_key": "SKILL_MEMORY",
		"icon": "brain",
		"color": Color("ff6b6b"),
		"scene_path": "res://scenes/main/memory_cards.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "color_pop",
		"name_key": "GAME_COLOR_POP",
		"desc_key": "DESC_COLOR_POP",
		"skill_key": "SKILL_COLOR_POP",
		"icon": "bubble",
		"color": Color("ffd166"),
		"scene_path": "res://scenes/main/color_pop.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "shape_sorter",
		"name_key": "GAME_SHAPE_SORTER",
		"desc_key": "DESC_SHAPE_SORTER",
		"skill_key": "SKILL_SHAPE_SORTER",
		"icon": "diamond",
		"color": Color("ff9f1c"),
		"scene_path": "res://scenes/main/shape_sorter.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "counting",
		"name_key": "GAME_COUNTING",
		"desc_key": "DESC_COUNTING",
		"skill_key": "SKILL_COUNTING",
		"icon": "numbers",
		"color": Color("4ecdc4"),
		"scene_path": "res://scenes/main/counting_game.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "magnetic_halves",
		"name_key": "GAME_PUZZLE",
		"desc_key": "DESC_MAGNETIC_HALVES",
		"skill_key": "SKILL_MAGNETIC_HALVES",
		"icon": "puzzle",
		"color": Color("a78bfa"),
		"scene_path": "res://scenes/main/magnetic_halves.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "odd_one_out",
		"name_key": "GAME_ODD_ONE_OUT",
		"desc_key": "DESC_ODD_ONE_OUT",
		"skill_key": "SKILL_ODD_ONE_OUT",
		"icon": "magnifier",
		"color": Color("f472b6"),
		"scene_path": "res://scenes/main/odd_one_out.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "smart_coloring",
		"name_key": "GAME_TRACING",
		"desc_key": "DESC_SMART_COLORING",
		"skill_key": "SKILL_SMART_COLORING",
		"icon": "pencil",
		"color": Color("38bdf8"),
		"scene_path": "res://scenes/main/smart_coloring.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "music",
		"name_key": "GAME_MUSIC",
		"desc_key": "DESC_MUSIC",
		"skill_key": "SKILL_MUSIC",
		"icon": "music_note",
		"color": Color("fb923c"),
		"scene_path": "res://scenes/main/forest_orchestra.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "pattern",
		"name_key": "GAME_PATTERN",
		"desc_key": "DESC_PATTERN",
		"skill_key": "SKILL_PATTERN",
		"icon": "cycle",
		"color": Color("e599f7"),
		"scene_path": "res://scenes/main/pattern_builder.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "compare",
		"name_key": "GAME_COMPARE",
		"desc_key": "DESC_COMPARE",
		"skill_key": "SKILL_COMPARE",
		"icon": "scales",
		"color": Color("118ab2"),
		"scene_path": "res://scenes/main/compare_game.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "sorting",
		"name_key": "GAME_SORTING",
		"desc_key": "DESC_SORTING",
		"skill_key": "SKILL_SORTING",
		"icon": "folder",
		"color": Color("6366f1"),
		"scene_path": "res://scenes/main/sorting_game.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "size_sort",
		"name_key": "GAME_SIZE_SORT",
		"desc_key": "DESC_SIZE_SORT",
		"skill_key": "SKILL_SIZE_SORT",
		"icon": "ruler",
		"color": Color("4fc3f7"),
		"scene_path": "res://scenes/main/size_sort.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "color_conveyor",
		"name_key": "GAME_COLOR_CONVEYOR",
		"desc_key": "DESC_COLOR_CONVEYOR",
		"skill_key": "SKILL_COLOR_CONVEYOR",
		"icon": "factory",
		"color": Color("ef476f"),
		"scene_path": "res://scenes/main/color_conveyor.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "hygiene",
		"name_key": "GAME_HYGIENE",
		"desc_key": "DESC_HYGIENE",
		"skill_key": "SKILL_HYGIENE",
		"icon": "soap",
		"color": Color("81ecec"),
		"scene_path": "res://scenes/main/hygiene_game.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "weather_dress",
		"name_key": "GAME_WEATHER_DRESS",
		"desc_key": "DESC_WEATHER_DRESS",
		"skill_key": "SKILL_WEATHER_DRESS",
		"icon": "weather",
		"color": Color("74b9ff"),
		"scene_path": "res://scenes/main/weather_dress.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "safe_maze",
		"name_key": "GAME_SAFE_MAZE",
		"desc_key": "DESC_SAFE_MAZE",
		"skill_key": "SKILL_SAFE_MAZE",
		"icon": "flag",
		"color": Color("55efc4"),
		"scene_path": "res://scenes/main/safe_maze.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "sensory_sandbox",
		"name_key": "GAME_SENSORY_SANDBOX",
		"desc_key": "DESC_SENSORY_SANDBOX",
		"skill_key": "SKILL_SENSORY_SANDBOX",
		"icon": "palette",
		"color": Color("6c5ce7"),
		"scene_path": "res://scenes/main/sensory_sandbox.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "algo_robot",
		"name_key": "GAME_ALGO_ROBOT",
		"desc_key": "DESC_ALGO_ROBOT",
		"skill_key": "SKILL_ALGO_ROBOT",
		"icon": "robot",
		"color": Color("636e72"),
		"scene_path": "res://scenes/main/algo_robot.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "math_scales",
		"name_key": "GAME_MATH_SCALES",
		"desc_key": "DESC_MATH_SCALES",
		"skill_key": "SKILL_MATH_SCALES",
		"icon": "scales",
		"color": Color("00b894"),
		"scene_path": "res://scenes/main/math_scales.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "cash_register",
		"name_key": "GAME_CASH_REGISTER",
		"desc_key": "DESC_CASH_REGISTER",
		"skill_key": "SKILL_CASH_REGISTER",
		"icon": "money",
		"color": Color("fdcb6e"),
		"scene_path": "res://scenes/main/cash_register.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "eco_conveyor",
		"name_key": "GAME_ECO_CONVEYOR",
		"desc_key": "DESC_ECO_CONVEYOR",
		"skill_key": "SKILL_ECO_CONVEYOR",
		"icon": "recycle",
		"color": Color("00cec9"),
		"scene_path": "res://scenes/main/eco_conveyor.tscn",
		"unlocked": true,
		"age": AgeCategory.OVERLAP,
	},
	{
		"id": "knight_path",
		"name_key": "GAME_KNIGHT_PATH",
		"desc_key": "DESC_KNIGHT_PATH",
		"skill_key": "SKILL_KNIGHT_PATH",
		"icon": "knight",
		"color": Color("2d3436"),
		"scene_path": "res://scenes/main/knight_path.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "color_lab",
		"name_key": "GAME_COLOR_LAB",
		"desc_key": "DESC_COLOR_LAB",
		"skill_key": "SKILL_COLOR_LAB",
		"icon": "beaker",
		"color": Color("e17055"),
		"scene_path": "res://scenes/main/color_lab.tscn",
		"unlocked": true,
		"age": AgeCategory.OVERLAP,
	},
	{
		"id": "math_bingo",
		"name_key": "GAME_MATH_BINGO",
		"desc_key": "DESC_MATH_BINGO",
		"skill_key": "SKILL_MATH_BINGO",
		"icon": "target",
		"color": Color("fab1a0"),
		"scene_path": "res://scenes/main/math_bingo.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "spelling_blocks",
		"name_key": "GAME_SPELLING",
		"desc_key": "DESC_SPELLING_BLOCKS",
		"skill_key": "SKILL_SPELLING_BLOCKS",
		"icon": "letters",
		"color": Color("81ecec"),
		"scene_path": "res://scenes/main/spelling_blocks.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "gravity_orbits",
		"name_key": "GAME_GRAVITY_ORBITS",
		"desc_key": "DESC_GRAVITY_ORBITS",
		"skill_key": "SKILL_GRAVITY_ORBITS",
		"icon": "planet",
		"color": Color("0984e3"),
		"scene_path": "res://scenes/main/gravity_orbits.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
	{
		"id": "analog_clock",
		"name_key": "GAME_ANALOG_CLOCK",
		"desc_key": "DESC_ANALOG_CLOCK",
		"skill_key": "SKILL_ANALOG_CLOCK",
		"icon": "clock",
		"color": Color("dfe6e9"),
		"scene_path": "res://scenes/main/analog_clock.tscn",
		"unlocked": true,
		"age": AgeCategory.ALL,
	},
]


## Повертає ВСІ ігри, відсортовані за релевантністю для вікової групи.
## Рекомендовані (age match) — спочатку, решта — після. Нічого не ховаємо.
static func get_all_games_sorted(group: int) -> Array[Dictionary]:
	var recommended: Array[Dictionary] = []
	var others: Array[Dictionary] = []
	for game: Dictionary in GAMES:
		var cat: int = game.get("age", AgeCategory.ALL)
		if _is_recommended(cat, group):
			recommended.append(game)
		else:
			others.append(game)
	var result: Array[Dictionary] = []
	result.append_array(recommended)
	result.append_array(others)
	if result.size() != GAMES.size():
		push_warning("GameCatalog: очікували %d ігор, отримали %d" % [GAMES.size(), result.size()])
		return GAMES.duplicate()
	return result


## Чи гра рекомендована для цієї вікової групи.
static func is_game_recommended(game: Dictionary, group: int) -> bool:
	var cat: int = game.get("age", AgeCategory.ALL)
	return _is_recommended(cat, group)


static func _is_recommended(cat: int, group: int) -> bool:
	if cat == AgeCategory.ALL:
		return true
	if cat == group:
		return true
	if cat == AgeCategory.OVERLAP:
		return true
	return false


## Legacy wrapper — повертає ВСІ ігри (не фільтрує).
static func get_games_for_age(group: int) -> Array[Dictionary]:
	return get_all_games_sorted(group)


static func get_game_by_id(id: String) -> Dictionary:
	for game: Dictionary in GAMES:
		if game.id == id:
			return game
	push_warning("GameCatalog: гру '%s' не знайдено" % id)
	return {}
