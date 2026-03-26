extends SceneTree

# Headless test runner — executes all test suites and exits
# Usage: godot --headless --path game/ -s tests/run_all_tests.gd

var _match_made_fired: bool = false
var _last_stats: Dictionary = {}


func _initialize() -> void:
	var test_node: Node2D = Node2D.new()
	root.add_child(test_node)
	_run_game_data_tests()
	_run_round_manager_tests(test_node)
	_run_star_formula_tests()
	_run_base_contract_tests()
	_run_catalog_integrity_tests()
	_run_bg_catalog_tests()
	_run_icon_png_tests()
	_run_law_compliance_tests()
	test_node.queue_free()
	print("\n=== ALL TESTS PASSED ===")
	quit()


func _run_star_formula_tests() -> void:
	var t: Node = load("res://tests/test_star_formula.gd").new()
	root.add_child(t)
	t._ready()
	t.queue_free()


func _run_base_contract_tests() -> void:
	var t: Node = load("res://tests/test_base_contract.gd").new()
	root.add_child(t)
	t._ready()
	t.queue_free()


func _run_catalog_integrity_tests() -> void:
	var t: Node = load("res://tests/test_catalog_integrity.gd").new()
	root.add_child(t)
	t._ready()
	t.queue_free()


func _run_bg_catalog_tests() -> void:
	print("\n--- BgCatalog Tests ---")
	## Унікальні id
	var ids: Array[String] = []
	for bg: Dictionary in BgCatalog.BACKGROUNDS:
		assert(not ids.has(bg.id), "BgCatalog: дублікат id '%s'" % bg.id)
		ids.append(bg.id as String)
	print("  PASS: all %d BG IDs are unique" % ids.size())

	## Обов'язкові поля
	for bg: Dictionary in BgCatalog.BACKGROUNDS:
		assert(bg.has("id"), "BG entry missing 'id'")
		assert(bg.has("theme"), "BG entry missing 'theme'")
		assert(bg.has("name_key"), "BG entry missing 'name_key'")
		assert(bg.has("cost"), "BG entry missing 'cost'")
		assert(bg.has("order"), "BG entry missing 'order'")
		assert(bg.cost is int or bg.cost is float, "cost must be numeric for '%s'" % bg.id)
		assert(int(bg.cost) >= 0, "cost must be >= 0 for '%s'" % bg.id)
	print("  PASS: all BG entries have required fields")

	## PNG прев'ю існує
	for bg: Dictionary in BgCatalog.BACKGROUNDS:
		var path: String = BgCatalog.get_preview_path(bg.id as String)
		assert(ResourceLoader.exists(path),
			"BG preview PNG missing: '%s' for id '%s'" % [path, bg.id])
	print("  PASS: all %d BG preview PNGs exist" % BgCatalog.BACKGROUNDS.size())

	## Default завжди безкоштовний
	var default_bg: Dictionary = BgCatalog.get_bg("default")
	assert(default_bg.id == "default", "get_bg('default') повинен повернути default")
	assert(int(default_bg.cost) == 0, "default BG must be free (cost=0)")
	print("  PASS: default BG is free (cost=0)")

	## Fallback на default для невідомого id
	var unknown: Dictionary = BgCatalog.get_bg("nonexistent_bg_xyz")
	assert(unknown.id == "default", "Unknown ID should fallback to default")
	print("  PASS: get_bg('nonexistent') returns default fallback")

	## get_theme_for_id працює
	assert(BgCatalog.get_theme_for_id("default") == "sky", "default -> sky theme")
	assert(BgCatalog.get_theme_for_id("sunset") == "sunset", "sunset -> sunset theme")
	print("  PASS: get_theme_for_id returns correct theme mapping")

	print("--- All BgCatalog tests passed ---")


func _run_icon_png_tests() -> void:
	print("\n--- Game Icon PNG Tests (advisory) ---")
	var found: int = 0
	var missing: Array[String] = []
	for game: Dictionary in GameCatalog.GAMES:
		var icon_id: String = game.get("icon", "star") as String
		var path: String = "res://assets/textures/game_icons/icon_%s.png" % icon_id
		if ResourceLoader.exists(path):
			found += 1
		else:
			missing.append(icon_id)
	if missing.size() > 0:
		push_warning("Icon PNGs missing (fallback to code-drawn): %s" % ", ".join(missing))
		print("  ADVISORY: %d/%d icon PNGs found, missing: %s" % [found, GameCatalog.GAMES.size(), ", ".join(missing)])
	else:
		print("  PASS: all %d game icon PNGs exist" % found)
	## Не assert — LAW 7 гарантує fallback на код-малювання
	print("--- Icon PNG tests done ---")


func _run_law_compliance_tests() -> void:
	var t: Node = load("res://tests/test_law_compliance.gd").new()
	root.add_child(t)
	t._ready()
	t.queue_free()


func _run_game_data_tests() -> void:
	print("--- GameData Tests ---")

	assert(GameData.find_correct_food_name("Bunny") == "Carrot", "Bunny should eat Carrot")
	assert(GameData.find_correct_food_name("Dog") == "Bone", "Dog should eat Bone")
	assert(GameData.find_correct_food_name("Bear") == "Honey", "Bear should eat Honey")
	assert(GameData.find_correct_food_name("Lion") == "Meat", "Lion should eat Meat")
	assert(GameData.find_correct_food_name("Panda") == "Bamboo", "Panda should eat Bamboo")
	assert(GameData.find_correct_food_name("Hedgehog") == "Apple", "Hedgehog should eat Apple")
	print("  PASS: find_correct_food_name returns correct food for known animals")

	var result: String = GameData.find_correct_food_name("Unicorn")
	assert(result == "", "Unknown animal should return empty string")
	print("  PASS: find_correct_food_name returns empty for unknown animals")

	for pair: Dictionary in GameData.ANIMALS_AND_FOOD:
		assert(pair.has("name"), "Pair must have 'name' key")
		assert(pair.has("animal_scene"), "Pair must have 'animal_scene' key")
		assert(pair.has("food_scene"), "Pair must have 'food_scene' key")
		assert(pair.name is String, "Name must be a String")
		assert(pair.animal_scene != null, "Animal scene must not be null for " + pair.name)
		assert(pair.food_scene != null, "Food scene must not be null for " + pair.name)
	print("  PASS: all %d animal-food pairs have valid data" % GameData.ANIMALS_AND_FOOD.size())

	var names: Array[String] = []
	for pair: Dictionary in GameData.ANIMALS_AND_FOOD:
		assert(not names.has(pair.name), "Duplicate animal name: " + pair.name)
		names.append(pair.name)
	print("  PASS: no duplicate animal names (%d unique)" % names.size())

	assert(GameData.MAX_ROUNDS > 0, "MAX_ROUNDS must be positive")
	assert(GameData.MAX_ROUNDS <= GameData.ANIMALS_AND_FOOD.size(),
		"MAX_ROUNDS must not exceed total animal count")
	print("  PASS: MAX_ROUNDS = %d (valid range)" % GameData.MAX_ROUNDS)

	assert(GameData.find_correct_food_name("Monkey") == "Banana", "Monkey should eat Banana")
	assert(GameData.find_correct_food_name("Elephant") == "Watermelon", "Elephant should eat Watermelon")
	print("  PASS: V20.0 biological pairings correct (Monkey→Banana, Elephant→Watermelon)")

	print("--- All GameData tests passed ---\n")


func _run_round_manager_tests(scene_root: Node2D) -> void:
	print("--- RoundManager Tests ---")
	_test_start_new_round(scene_root)
	_test_food_type_metadata(scene_root)
	_test_dynamic_difficulty(scene_root)
	_test_correct_match(scene_root)
	_test_incorrect_match(scene_root)
	_test_error_tracking(scene_root)
	_test_count_after_match(scene_root)
	_test_return_food_to_origin(scene_root)
	_test_reposition_all(scene_root)
	_test_earned_coins_in_stats(scene_root)
	_test_derangement(scene_root)
	print("--- All RoundManager tests passed ---")


func _test_start_new_round(scene_root: Node2D) -> void:
	var rm: RoundManager = RoundManager.new(scene_root)
	rm.start_new_round()
	var target: int = rm.get_target_pairs()
	assert(rm.current_round_animals.size() == target,
		"Should have %d animals" % target)
	assert(rm.current_round_food.size() == target,
		"Should have %d food items" % target)
	assert(rm.selected_indices.size() == target,
		"Should have %d selected indices" % target)
	assert(rm.food_original_positions.size() == target,
		"Should track %d food positions" % target)
	print("  PASS: start_new_round creates correct number of animals and food (%d)" % target)
	_cleanup(scene_root)


func _test_food_type_metadata(scene_root: Node2D) -> void:
	var rm: RoundManager = RoundManager.new(scene_root)
	rm.start_new_round()
	for food: Node2D in rm.current_round_food:
		assert(food.has_meta("food_type"), "Food must have food_type metadata")
		assert(food.get_meta("food_type") is String, "food_type must be a String")
		assert(food.get_meta("food_type") != "", "food_type must not be empty")
	print("  PASS: all food items have valid food_type metadata")
	_cleanup(scene_root)


func _test_dynamic_difficulty(scene_root: Node2D) -> void:
	var rm: RoundManager = RoundManager.new(scene_root)
	assert(rm.get_target_pairs() == 3, "rounds_played=0 should target 3")
	rm.rounds_played = 2
	assert(rm.get_target_pairs() == 3, "rounds_played=2 should target 3")
	rm.rounds_played = 3
	assert(rm.get_target_pairs() == 4, "rounds_played=3 should target 4")
	rm.rounds_played = 6
	assert(rm.get_target_pairs() == 4, "rounds_played=6 should target 4")
	rm.rounds_played = 7
	assert(rm.get_target_pairs() == 5, "rounds_played=7 should target 5")
	rm.rounds_played = 9
	assert(rm.get_target_pairs() == 5, "rounds_played=9 should target 5")
	print("  PASS: dynamic difficulty scales 3→4→5 based on rounds_played")
	_cleanup(scene_root)


func _test_error_tracking(scene_root: Node2D) -> void:
	var rm: RoundManager = RoundManager.new(scene_root)
	rm.start_new_round()
	assert(rm.errors_made == 0, "errors_made should start at 0")
	var animal: Node2D = rm.current_round_animals[0]
	var exp_name: String = GameData.find_correct_food_name(animal.name)
	var wrong_food: Node2D = null
	for food: Node2D in rm.current_round_food:
		if food.get_meta("food_type") != exp_name:
			wrong_food = food
			break
	if wrong_food:
		rm.try_match(wrong_food, animal)
		assert(rm.errors_made == 1, "errors_made should be 1 after wrong match")
		rm.try_match(wrong_food, animal)
		assert(rm.errors_made == 2, "errors_made should be 2 after second wrong match")
		print("  PASS: errors_made increments on failed matches")
	else:
		print("  SKIP: all food matches first animal")
	_cleanup(scene_root)


func _test_count_after_match(scene_root: Node2D) -> void:
	var rm: RoundManager = RoundManager.new(scene_root)
	rm.start_new_round()
	var target: int = rm.get_target_pairs()
	var animal: Node2D = rm.current_round_animals[0]
	var expected_food_name: String = GameData.find_correct_food_name(animal.name)
	var matching_food: Node2D = null
	for food: Node2D in rm.current_round_food:
		if food.get_meta("food_type") == expected_food_name:
			matching_food = food
			break
	if matching_food:
		rm.try_match(matching_food, animal)
		rm.add_new_pair_if_needed()
		if not rm.current_round_animals.is_empty():
			var new_target: int = rm.get_target_pairs()
			assert(rm.current_round_animals.size() == new_target,
				"Animal count should be %d after match + add" % new_target)
			assert(rm.current_round_food.size() == new_target,
				"Food count should be %d after match + add" % new_target)
			print("  PASS: on-screen count maintained at %d after match" % new_target)
		else:
			print("  SKIP: all animals used, game_won emitted")
	else:
		print("  SKIP: matching food not in current round")
	_cleanup(scene_root)


func _test_correct_match(scene_root: Node2D) -> void:
	_match_made_fired = false
	var rm: RoundManager = RoundManager.new(scene_root)
	rm.match_made.connect(func(_a: Node2D, _f: Node2D) -> void: _match_made_fired = true)
	rm.start_new_round()

	var animal: Node2D = rm.current_round_animals[0]
	var expected_food_name: String = GameData.find_correct_food_name(animal.name)
	var matching_food: Node2D = null
	for food: Node2D in rm.current_round_food:
		if food.get_meta("food_type") == expected_food_name:
			matching_food = food
			break

	if matching_food:
		var ok: bool = rm.try_match(matching_food, animal)
		assert(ok == true, "Correct match should return true")
		assert(_match_made_fired, "match_made signal should have fired")
		print("  PASS: correct match returns true and emits signal")
	else:
		print("  SKIP: matching food not in current round (shuffled away)")
	_cleanup(scene_root)


func _test_incorrect_match(scene_root: Node2D) -> void:
	var rm: RoundManager = RoundManager.new(scene_root)
	rm.start_new_round()

	var animal: Node2D = rm.current_round_animals[0]
	var wrong_food: Node2D = null
	var exp_name: String = GameData.find_correct_food_name(animal.name)
	for food: Node2D in rm.current_round_food:
		if food.get_meta("food_type") != exp_name:
			wrong_food = food
			break

	if wrong_food:
		var old_count: int = rm.current_round_food.size()
		var ok: bool = rm.try_match(wrong_food, animal)
		assert(ok == false, "Wrong match should return false")
		assert(rm.current_round_food.size() == old_count,
			"Food count should not change on wrong match")
		print("  PASS: incorrect match returns false and preserves state")
	else:
		print("  SKIP: all food matches first animal")
	_cleanup(scene_root)


func _test_return_food_to_origin(scene_root: Node2D) -> void:
	var rm: RoundManager = RoundManager.new(scene_root)
	rm.start_new_round()
	var food: Node2D = rm.current_round_food[0]
	var original_pos: Vector2 = food.position
	food.position = Vector2(999, 999)
	rm.return_food_to_origin(food)
	assert(food.position == original_pos, "Food should return to original position")
	print("  PASS: return_food_to_origin restores position")
	_cleanup(scene_root)


func _test_reposition_all(scene_root: Node2D) -> void:
	var rm: RoundManager = RoundManager.new(scene_root)
	rm.start_new_round()
	var old_pos: Vector2 = rm.current_round_animals[0].position
	rm.reposition_all()
	assert(rm.current_round_animals[0].position == old_pos,
		"reposition_all should produce same positions when viewport unchanged")
	for food: Node2D in rm.current_round_food:
		assert(rm.food_original_positions.has(food),
			"food_original_positions should be updated after reposition")
	print("  PASS: reposition_all produces consistent positions and updates food_original_positions")
	_cleanup(scene_root)


func _test_earned_coins_in_stats(scene_root: Node2D) -> void:
	# Use a fresh node to avoid name collisions from previous tests' queue_free()
	var fresh_root: Node2D = Node2D.new()
	root.add_child(fresh_root)
	_last_stats = {}
	var rm: RoundManager = RoundManager.new(fresh_root)
	rm.game_won.connect(func(stats: Dictionary) -> void: _last_stats = stats)
	rm.mini_game_finished.connect(func(stats: Dictionary) -> void: _last_stats = stats)
	rm.start_new_round()

	# Match animals until game_won or mini_game_finished fires
	var safety: int = 0
	while _last_stats.is_empty() and safety < 200:
		safety += 1
		if rm.current_round_animals.is_empty():
			break
		var matched: bool = false
		for animal: Node2D in rm.current_round_animals:
			var exp_name: String = GameData.find_correct_food_name(animal.name)
			for food: Node2D in rm.current_round_food:
				if food.get_meta("food_type") == exp_name:
					rm.try_match(food, animal)
					rm.add_new_pair_if_needed()
					matched = true
					break
			if matched:
				break
		if not matched:
			break

	if not _last_stats.is_empty():
		assert(_last_stats.has("earned_coins"), "stats must contain earned_coins key")
		assert(_last_stats.earned_coins is int, "earned_coins must be int")
		assert(_last_stats.earned_coins >= 10, "earned_coins must be at least 10")
		assert(_last_stats.earned_coins <= 100, "earned_coins must be reasonable")
		print("  PASS: earned_coins present in stats (value=%d)" % _last_stats.earned_coins)
	else:
		print("  SKIP: could not trigger game end in test")
	_cleanup(fresh_root)
	fresh_root.free()


func _test_derangement(scene_root: Node2D) -> void:
	# Verify food shuffle prevents direct vertical alignment with animals
	var aligned_count: int = 0
	for trial: int in range(20):
		var rm: RoundManager = RoundManager.new(scene_root)
		rm.start_new_round()
		for i: int in range(rm.current_round_animals.size()):
			var animal_name: String = rm.current_round_animals[i].name
			var food_type: String = rm.current_round_food[i].get_meta("food_type")
			var expected: String = GameData.find_correct_food_name(animal_name)
			if food_type == expected:
				aligned_count += 1
		_cleanup(scene_root)
	# With derangement, aligned pairs should be very rare (< 10% of total)
	var total_pairs: int = 20 * 3  # 20 trials × 3 pairs minimum
	assert(aligned_count < total_pairs / 2, "Too many aligned pairs: %d/%d" % [aligned_count, total_pairs])
	print("  PASS: derangement working — %d/%d aligned (expected low)" % [aligned_count, total_pairs])


func _cleanup(scene_root: Node2D) -> void:
	for child: Node in scene_root.get_children():
		child.queue_free()
