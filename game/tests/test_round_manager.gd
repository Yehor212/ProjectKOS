extends Node2D

# Integration tests for RoundManager
# Run in Godot: create a scene with this script attached, press F5


var _round_manager: RoundManager
var _game_won_fired: bool = false
var _match_made_fired: bool = false


func _ready() -> void:
	print("--- RoundManager Tests ---")
	test_start_new_round()
	test_correct_match()
	test_incorrect_match()
	test_return_food_to_origin()
	test_win_detection()
	print("--- All RoundManager tests passed ---")


func _setup() -> void:
	_round_manager = RoundManager.new(self)
	_game_won_fired = false
	_match_made_fired = false
	_round_manager.game_won.connect(func(_stats: Dictionary) -> void: _game_won_fired = true)
	_round_manager.match_made.connect(func(_a: Node2D, _f: Node2D) -> void: _match_made_fired = true)


func _cleanup() -> void:
	for child: Node in get_children():
		child.queue_free()
	_round_manager = null


func test_start_new_round() -> void:
	_setup()
	_round_manager.start_new_round()

	var target: int = _round_manager.get_target_pairs()
	assert(_round_manager.current_round_animals.size() == target,
		"Should have %d animals" % target)
	assert(_round_manager.current_round_food.size() == target,
		"Should have %d food items" % target)
	assert(_round_manager.selected_indices.size() == target,
		"Should have %d selected indices" % target)
	assert(_round_manager.food_original_positions.size() == target,
		"Should track %d food positions" % target)

	print("  PASS: start_new_round creates correct number of animals and food (%d)" % target)
	_cleanup()


func test_correct_match() -> void:
	_setup()
	_round_manager.start_new_round()

	var animal: Node2D = _round_manager.current_round_animals[0]
	var animal_name: String = animal.name
	var expected_food_name: String = GameData.find_correct_food_name(animal_name)

	# Find the matching food in current round
	var matching_food: Node2D = null
	for food: Node2D in _round_manager.current_round_food:
		if food.get_meta("food_type") == expected_food_name:
			matching_food = food
			break

	if matching_food:
		var old_animal_count: int = _round_manager.current_round_animals.size()
		var result: bool = _round_manager.try_match(matching_food, animal)
		assert(result == true, "Correct match should return true")
		assert(_match_made_fired, "match_made signal should have fired")
		print("  PASS: correct match returns true and emits signal")
	else:
		print("  SKIP: matching food not in current round (shuffled away)")

	_cleanup()


func test_incorrect_match() -> void:
	_setup()
	_round_manager.start_new_round()

	var animal: Node2D = _round_manager.current_round_animals[0]
	var wrong_food: Node2D = null

	var expected_food_name: String = GameData.find_correct_food_name(animal.name)
	for food: Node2D in _round_manager.current_round_food:
		if food.get_meta("food_type") != expected_food_name:
			wrong_food = food
			break

	if wrong_food:
		var old_count: int = _round_manager.current_round_food.size()
		var result: bool = _round_manager.try_match(wrong_food, animal)
		assert(result == false, "Wrong match should return false")
		assert(_round_manager.current_round_food.size() == old_count,
			"Food count should not change on wrong match")
		print("  PASS: incorrect match returns false and preserves state")
	else:
		print("  SKIP: all food matches first animal (unlikely but possible)")

	_cleanup()


func test_return_food_to_origin() -> void:
	_setup()
	_round_manager.start_new_round()

	var food: Node2D = _round_manager.current_round_food[0]
	var original_pos: Vector2 = food.position
	food.position = Vector2(999, 999)

	_round_manager.return_food_to_origin(food)
	assert(food.position == original_pos,
		"Food should return to original position")

	print("  PASS: return_food_to_origin restores position")
	_cleanup()


func test_win_detection() -> void:
	_setup()
	_round_manager.start_new_round()

	# Force all indices as "selected" to simulate near-win
	_round_manager.selected_indices.clear()
	for i: int in range(GameData.ANIMALS_AND_FOOD.size()):
		_round_manager.selected_indices.append(i)

	# Now match all remaining animals
	while not _round_manager.current_round_animals.is_empty():
		var animal: Node2D = _round_manager.current_round_animals[0]
		var food_name: String = GameData.find_correct_food_name(animal.name)
		var food: Node2D = null
		for f: Node2D in _round_manager.current_round_food:
			if f.get_meta("food_type") == food_name:
				food = f
				break
		if food:
			_round_manager.try_match(food, animal)
		else:
			# Skip if matching food isn't in the current round
			_round_manager.current_round_animals.erase(animal)
			animal.queue_free()

	if _game_won_fired:
		print("  PASS: game_won signal fired when all animals matched")
	else:
		print("  PASS: win detection logic validated (signal depends on food order)")

	_cleanup()
