extends Node

# Unit tests for GameData
# Run in Godot: create a scene with this script attached, press F5


func _ready() -> void:
	print("--- GameData Tests ---")
	test_find_correct_food_name()
	test_find_food_for_unknown_animal()
	test_all_animals_have_food()
	test_no_duplicate_animal_names()
	test_max_rounds_constant()
	print("--- All GameData tests passed ---")


func test_find_correct_food_name() -> void:
	assert(GameData.find_correct_food_name("Bunny") == "Carrot", "Bunny should eat Carrot")
	assert(GameData.find_correct_food_name("Dog") == "Bone", "Dog should eat Bone")
	assert(GameData.find_correct_food_name("Bear") == "Honey", "Bear should eat Honey")
	assert(GameData.find_correct_food_name("Lion") == "Meat", "Lion should eat Meat")
	assert(GameData.find_correct_food_name("Panda") == "Bamboo", "Panda should eat Bamboo")
	assert(GameData.find_correct_food_name("Hedgehog") == "Apple", "Hedgehog should eat Apple")
	print("  PASS: find_correct_food_name returns correct food for known animals")


func test_find_food_for_unknown_animal() -> void:
	var result: String = GameData.find_correct_food_name("Unicorn")
	assert(result == "", "Unknown animal should return empty string")
	print("  PASS: find_correct_food_name returns empty for unknown animals")


func test_all_animals_have_food() -> void:
	for pair: Dictionary in GameData.ANIMALS_AND_FOOD:
		assert(pair.has("name"), "Pair must have 'name' key")
		assert(pair.has("animal_scene"), "Pair must have 'animal_scene' key")
		assert(pair.has("food_scene"), "Pair must have 'food_scene' key")
		assert(pair.name is String, "Name must be a String")
		assert(pair.animal_scene != null, "Animal scene must not be null for " + pair.name)
		assert(pair.food_scene != null, "Food scene must not be null for " + pair.name)
	print("  PASS: all %d animal-food pairs have valid data" % GameData.ANIMALS_AND_FOOD.size())


func test_no_duplicate_animal_names() -> void:
	var names: Array[String] = []
	for pair: Dictionary in GameData.ANIMALS_AND_FOOD:
		assert(not names.has(pair.name), "Duplicate animal name: " + pair.name)
		names.append(pair.name)
	print("  PASS: no duplicate animal names (%d unique)" % names.size())


func test_max_rounds_constant() -> void:
	assert(GameData.MAX_ROUNDS > 0, "MAX_ROUNDS must be positive")
	assert(GameData.MAX_ROUNDS <= GameData.ANIMALS_AND_FOOD.size(),
		"MAX_ROUNDS must not exceed total animal count")
	print("  PASS: MAX_ROUNDS = %d (valid range)" % GameData.MAX_ROUNDS)
