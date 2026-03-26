extends Node

## Тести цілісності GameCatalog — всі 29 ігор мають валідні дані


func _ready() -> void:
	print("--- GameCatalog Integrity Tests ---")
	test_unique_ids()
	test_required_fields()
	test_valid_age_category()
	test_scenes_exist()
	print("--- All GameCatalog Integrity tests passed ---")


func test_unique_ids() -> void:
	var ids: Array[String] = []
	for game: Dictionary in GameCatalog.GAMES:
		assert(not ids.has(game.id), "Duplicate game ID: " + game.id)
		ids.append(game.id)
	assert(ids.size() >= 27, "Expected at least 27 games, got %d" % ids.size())
	print("  PASS: all %d game IDs are unique" % ids.size())


func test_required_fields() -> void:
	for game: Dictionary in GameCatalog.GAMES:
		assert(game.has("id"), "Game missing 'id'")
		assert(game.has("name_key"), "Game '%s' missing 'name_key'" % game.id)
		assert(game.has("scene_path"), "Game '%s' missing 'scene_path'" % game.id)
		assert(game.has("age"), "Game '%s' missing 'age'" % game.id)
		assert(game.has("icon"), "Game '%s' missing 'icon'" % game.id)
		assert(game.has("color"), "Game '%s' missing 'color'" % game.id)
		assert(game.id is String and game.id.length() > 0, "Game ID must be non-empty string")
	print("  PASS: all games have required fields (id, name_key, scene_path, age, icon, color)")


func test_valid_age_category() -> void:
	var valid_ages: Array[int] = [
		GameCatalog.AgeCategory.ALL,
		GameCatalog.AgeCategory.TODDLER,
		GameCatalog.AgeCategory.PRESCHOOL,
		GameCatalog.AgeCategory.OVERLAP,
	]
	for game: Dictionary in GameCatalog.GAMES:
		assert(valid_ages.has(game.age), "Game '%s' has invalid age: %d" % [game.id, game.age])
	print("  PASS: all games have valid AgeCategory")


func test_scenes_exist() -> void:
	var missing: Array[String] = []
	for game: Dictionary in GameCatalog.GAMES:
		if not ResourceLoader.exists(game.scene_path):
			missing.append("%s: %s" % [game.id, game.scene_path])
	assert(missing.is_empty(), "Missing scene files: " + ", ".join(missing))
	print("  PASS: all %d scene files exist" % GameCatalog.GAMES.size())
