extends Node

## LAW 26: Тести канонічної формули зірок
## Перевіряє _calculate_stars() з BaseMiniGame


func _ready() -> void:
	print("--- Star Formula Tests ---")
	test_toddler_always_5()
	test_preschool_zero_errors()
	test_preschool_standard_errors()
	test_preschool_clamp_min()
	test_preschool_clamp_extreme()
	print("--- All Star Formula tests passed ---")


func test_toddler_always_5() -> void:
	## Toddler завжди отримує 5 зірок незалежно від помилок
	SettingsManager.age_group = 1
	var bm: BaseMiniGame = BaseMiniGame.new()
	assert(bm._calculate_stars(0) == 5, "Toddler 0 errors → 5")
	assert(bm._calculate_stars(5) == 5, "Toddler 5 errors → 5")
	assert(bm._calculate_stars(100) == 5, "Toddler 100 errors → 5")
	bm.free()
	print("  PASS: toddler always gets 5 stars")


func test_preschool_zero_errors() -> void:
	SettingsManager.age_group = 2
	var bm: BaseMiniGame = BaseMiniGame.new()
	assert(bm._calculate_stars(0) == 5, "Preschool 0 errors → 5")
	assert(bm._calculate_stars(1) == 5, "Preschool 1 error → 5")
	bm.free()
	print("  PASS: preschool 0-1 errors → 5 stars")


func test_preschool_standard_errors() -> void:
	SettingsManager.age_group = 2
	var bm: BaseMiniGame = BaseMiniGame.new()
	assert(bm._calculate_stars(2) == 4, "Preschool 2 errors → 4")
	assert(bm._calculate_stars(4) == 3, "Preschool 4 errors → 3")
	assert(bm._calculate_stars(6) == 2, "Preschool 6 errors → 2")
	bm.free()
	print("  PASS: preschool standard error tiers correct")


func test_preschool_clamp_min() -> void:
	SettingsManager.age_group = 2
	var bm: BaseMiniGame = BaseMiniGame.new()
	assert(bm._calculate_stars(8) == 1, "Preschool 8 errors → 1")
	assert(bm._calculate_stars(10) == 1, "Preschool 10 errors → 1")
	bm.free()
	print("  PASS: preschool clamps to minimum 1 star")


func test_preschool_clamp_extreme() -> void:
	SettingsManager.age_group = 2
	var bm: BaseMiniGame = BaseMiniGame.new()
	assert(bm._calculate_stars(999) == 1, "Preschool 999 errors → 1")
	bm.free()
	print("  PASS: preschool extreme errors → 1 star (no negative)")
