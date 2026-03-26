extends Node

## Тести контракту BaseMiniGame — pure functions без UI


func _ready() -> void:
	print("--- BaseMiniGame Contract Tests ---")
	test_round_progress()
	test_round_progress_edge()
	test_scale_by_round()
	test_scale_by_round_i()
	print("--- All BaseMiniGame Contract tests passed ---")


func test_round_progress() -> void:
	var bm: BaseMiniGame = BaseMiniGame.new()
	assert(absf(bm._round_progress(0, 5) - 0.0) < 0.001, "Round 0/5 → 0.0")
	assert(absf(bm._round_progress(2, 5) - 0.5) < 0.001, "Round 2/5 → 0.5")
	assert(absf(bm._round_progress(4, 5) - 1.0) < 0.001, "Round 4/5 → 1.0")
	bm.free()
	print("  PASS: _round_progress standard cases")


func test_round_progress_edge() -> void:
	var bm: BaseMiniGame = BaseMiniGame.new()
	## div/0 guard: total <= 1 → 0.0
	assert(absf(bm._round_progress(0, 1) - 0.0) < 0.001, "Total=1 → 0.0 (guard)")
	assert(absf(bm._round_progress(0, 0) - 0.0) < 0.001, "Total=0 → 0.0 (guard)")
	## Clamp: негативний раунд
	assert(bm._round_progress(-1, 5) >= 0.0, "Negative round → clamped ≥ 0")
	bm.free()
	print("  PASS: _round_progress edge cases (div/0, negative)")


func test_scale_by_round() -> void:
	var bm: BaseMiniGame = BaseMiniGame.new()
	assert(absf(bm._scale_by_round(1.0, 2.0, 0, 5) - 1.0) < 0.001, "Round 0 → easy_val")
	assert(absf(bm._scale_by_round(1.0, 2.0, 4, 5) - 2.0) < 0.001, "Last round → hard_val")
	assert(absf(bm._scale_by_round(1.0, 2.0, 2, 5) - 1.5) < 0.001, "Mid round → lerp")
	bm.free()
	print("  PASS: _scale_by_round interpolation")


func test_scale_by_round_i() -> void:
	var bm: BaseMiniGame = BaseMiniGame.new()
	assert(bm._scale_by_round_i(3, 6, 0, 5) == 3, "Int: round 0 → 3")
	assert(bm._scale_by_round_i(3, 6, 4, 5) == 6, "Int: last round → 6")
	assert(bm._scale_by_round_i(3, 6, 2, 5) == 5, "Int: mid round → 5 (rounded)")
	bm.free()
	print("  PASS: _scale_by_round_i integer interpolation")
