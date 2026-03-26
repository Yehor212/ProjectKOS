extends BaseMiniGame

## Memory Cards — адаптивна гра: toddler (відкриті) / preschool (закриті).

const CARD_SCENE: PackedScene = preload("res://scenes/components/memory_card.tscn")
const BACK_TEX_PATH: String = "res://assets/branding/tofie_logo.png"
const DEAL_STAGGER: float = 0.1
const DEAL_DURATION: float = 0.4
const MISMATCH_PAUSE: float = 1.5
const CARD_GAP: float = 20.0
const TOP_BAR_HEIGHT: float = 64.0
const IDLE_HINT_DELAY: float = 5.0
const VICTORY_STAGGER: float = 0.08
const SAFETY_TIMEOUT_SEC: float = 120.0

const TODDLER_ROUNDS: int = 3
const PRESCHOOL_ROUNDS: int = 2
const TODDLER_GRIDS: Array[Vector2i] = [Vector2i(3, 2), Vector2i(3, 2), Vector2i(4, 2)]
const PRESCHOOL_GRIDS: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 3)]

var _grid_cols: int = 3
var _grid_rows: int = 2
var _pairs_count: int = 3
var _is_toddler: bool = false

var _cards: Array[Node2D] = []
var _flipped: Array[Node2D] = []
var _matched_count: int = 0
var _start_time: float = 0.0
var _back_tex: Texture2D = null
var _used_indices: Array[int] = []
var _idle_timer: SceneTreeTimer = null
var _round: int = 0
var _total_rounds: int = 1

## _progress_label замінено на _round_label (з BaseMiniGame via _build_instruction_pill)


func _ready() -> void:
	game_id = "memory"
	bg_theme = "sky"
	super()
	var group: int = SettingsManager.age_group
	_is_toddler = (group == 1)
	_total_rounds = TODDLER_ROUNDS if _is_toddler else PRESCHOOL_ROUNDS
	if ResourceLoader.exists(BACK_TEX_PATH):
		_back_tex = load(BACK_TEX_PATH)
	else:
		push_warning("MemoryCards: Missing back texture: " + BACK_TEX_PATH)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("MEMORY_TUTORIAL_TODDLER")
	return tr("MEMORY_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	for card: Node2D in _cards:
		if not card.is_matched:
			return {"type": "tap", "target": card.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())
	_update_progress()


func _start_round() -> void:
	_matched_count = 0
	_flipped.clear()
	_input_locked = true
	## Прогресивна складність — сітка росте з кожним раундом
	var grids: Array[Vector2i] = TODDLER_GRIDS if _is_toddler else PRESCHOOL_GRIDS
	var grid: Vector2i = grids[mini(_round, grids.size() - 1)]
	_grid_cols = grid.x
	_grid_rows = grid.y
	@warning_ignore("integer_division")
	_pairs_count = (_grid_cols * _grid_rows) / 2
	_update_progress()
	_deal_cards()


func _update_progress() -> void:
	if _round_label:
		_update_round_label(tr("MEMORY_PAIRS_FOUND") % [_matched_count, _pairs_count])


func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	var is_tap: bool = false
	if event is InputEventMouseButton:
		is_tap = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		is_tap = event.pressed
	if not is_tap:
		return
	var mouse: Vector2 = get_global_mouse_position()
	_try_tap(mouse)


func _try_tap(pos: Vector2) -> void:
	for card: Node2D in _cards:
		if card.is_matched:
			continue
		if not card.contains_point(pos):
			continue
		if _is_toddler:
			_try_tap_toddler(card)
		else:
			_try_tap_preschool(card)
		return


func _try_tap_toddler(card: Node2D) -> void:
	## Та сама картка натиснута двічі — зняти виділення
	if _flipped.size() == 1 and card == _flipped[0]:
		card.set_highlighted(false)
		_flipped.clear()
		_reset_idle_timer()
		return
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	if _flipped.is_empty():
		## Перший вибір — highlight
		card.set_highlighted(true)
		_flipped.append(card)
		_reset_idle_timer()
	else:
		## Другий вибір — evaluate
		_input_locked = true
		card.set_highlighted(true)
		_flipped.append(card)
		var d: float = 0.15 if SettingsManager.reduced_motion else 0.2
		var tw: Tween = create_tween()
		tw.tween_interval(d)
		tw.tween_callback(_evaluate)


func _try_tap_preschool(card: Node2D) -> void:
	if card.is_face_up or card.is_flipping:
		return
	if _flipped.size() == 1 and card == _flipped[0]:
		return
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	_flipped.append(card)
	var tw: Tween = card.flip_up()
	if _flipped.size() == 2:
		_input_locked = true
		tw.finished.connect(_evaluate)


func _evaluate() -> void:
	if _flipped.size() < 2:
		push_warning("MemoryCards: _flipped < 2 при evaluate")
		return
	var card_a: Node2D = _flipped[0]
	var card_b: Node2D = _flipped[1]
	if not is_instance_valid(card_a) or not is_instance_valid(card_b):
		push_warning("MemoryCards: картка freed до evaluate")
		_flipped.clear()
		_input_locked = false
		return
	if card_a.card_id == card_b.card_id:
		_handle_match()
	else:
		_handle_mismatch()


func _handle_match() -> void:
	_register_correct(_flipped[0])
	## Premium match VFX (LAW 28) — sparkle на обох + ripple
	for card: Node2D in _flipped:
		if is_instance_valid(card):
			VFXManager.spawn_match_sparkle(card.global_position)
			VFXManager.spawn_success_ripple(card.global_position, Color("06d6a0"))
	## Juicy squish bounce на обох картках
	for card: Node2D in _flipped:
		card.set_highlighted(false)
		if not SettingsManager.reduced_motion:
			var tw: Tween = create_tween()
			tw.tween_property(card, "scale", Vector2(1.25, 0.75), 0.07)
			tw.tween_property(card, "scale", Vector2(0.85, 1.15), 0.07)
			tw.tween_property(card, "scale", Vector2(1.05, 0.95), 0.05)
			tw.tween_property(card, "scale", Vector2.ONE, 0.05)
	_flipped[0].set_matched()
	_flipped[1].set_matched()
	_matched_count += 1
	_update_progress()
	_flipped.clear()
	if _matched_count >= _pairs_count:
		_play_victory()
	else:
		_input_locked = false
		_reset_idle_timer()


func _handle_mismatch() -> void:
	if _is_toddler:
		_handle_mismatch_toddler()
	else:
		_handle_mismatch_preschool()


func _handle_mismatch_toddler() -> void:
	## М'який фідбек без штрафу (A6), але з scaffolding (A11)
	_register_error(_flipped[0])
	_flipped[0].set_highlighted(false)
	_flipped[1].set_highlighted(false)
	_flipped.clear()
	_input_locked = false
	_reset_idle_timer()


func _handle_mismatch_preschool() -> void:
	_errors += 1
	_register_error(_flipped[0])
	## Gentle red flash + shake (LAW 28 — м'який, не агресивний)
	if not SettingsManager.reduced_motion:
		for card: Node2D in _flipped:
			## Червоний flash (0.2s) — м'який, не карає
			var flash_tw: Tween = create_tween()
			flash_tw.tween_property(card, "modulate", Color(1.3, 0.85, 0.85, 1.0), 0.1)
			flash_tw.tween_property(card, "modulate", Color.WHITE, 0.15)
			## Shake
			var orig_x: float = card.position.x
			var tw_shake: Tween = create_tween()
			tw_shake.tween_property(card, "position:x", orig_x - 5.0, 0.06)
			tw_shake.tween_property(card, "position:x", orig_x + 5.0, 0.06)
			tw_shake.tween_property(card, "position:x", orig_x - 2.5, 0.05)
			tw_shake.tween_property(card, "position:x", orig_x, 0.05)
	## Пауза 1.0s — дитина запам'ятовує!
	var d2: float = 0.15 if SettingsManager.reduced_motion else MISMATCH_PAUSE
	var tw: Tween = create_tween()
	tw.tween_interval(d2)
	tw.tween_callback(func() -> void:
		if _flipped.is_empty():
			push_warning("MemoryCards: _flipped порожній при flip_down")
			return
		_flipped[0].flip_down()
		_flipped[1].flip_down()
	)
	tw.tween_interval(MemoryCard.FLIP_HALF_DUR * 2.0 + 0.05)
	tw.tween_callback(func() -> void:
		_flipped.clear()
		_input_locked = false
		_reset_idle_timer()
	)


func _play_victory() -> void:
	_input_locked = true
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Premium celebration (LAW 28) — багатошарове святкування
	VFXManager.spawn_premium_celebration(vp * 0.5)
	## Картки танцюють по черзі з golden glow
	if not SettingsManager.reduced_motion:
		for i: int in range(_cards.size()):
			var card: Node2D = _cards[i]
			if not is_instance_valid(card):
				continue
			var delay: float = float(i) * VICTORY_STAGGER
			var tw: Tween = create_tween()
			tw.tween_interval(delay)
			## Golden flash per card
			tw.tween_property(card, "modulate", Color(1.2, 1.1, 0.7, 1.0), 0.08)
			tw.tween_property(card, "scale", Vector2(1.15, 0.85), 0.08)
			tw.tween_property(card, "scale", Vector2(0.9, 1.1), 0.08)
			tw.tween_property(card, "modulate", MemoryCard.MATCHED_TINT, 0.1)
			tw.tween_property(card, "scale", MemoryCard.MATCHED_SCALE, 0.12)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## Фініш або наступний раунд після танцю
	var d3: float = 0.15 if SettingsManager.reduced_motion else float(_cards.size()) * VICTORY_STAGGER + 0.8
	var finish_tw: Tween = create_tween()
	finish_tw.tween_interval(d3)
	finish_tw.tween_callback(_advance_round)


func _advance_round() -> void:
	_round += 1
	if _round >= _total_rounds:
		_finish()
	else:
		_clear_round()
		_start_round()


func _clear_round() -> void:
	for card: Node2D in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()


func _finish() -> void:
	_game_over = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	var stats: Dictionary = {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": _total_rounds,
		"earned_stars": earned,
	}
	finish_game(earned, stats)


func _deal_cards() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var card_data: Array[Dictionary] = []
	var indices: Array[int] = _pick_random_indices(_pairs_count)
	for idx: int in indices:
		card_data.append(GameData.ANIMALS_AND_FOOD[idx])
	## Створити пари (кожну тварину x 2)
	var pairs: Array[Dictionary] = []
	for entry: Dictionary in card_data:
		pairs.append(entry)
		pairs.append(entry)
	pairs.shuffle()
	## Обрахувати сітку
	var total_w: float = float(_grid_cols) * MemoryCard.CARD_WIDTH\
		+ float(_grid_cols - 1) * CARD_GAP
	var total_h: float = float(_grid_rows) * MemoryCard.CARD_HEIGHT\
		+ float(_grid_rows - 1) * CARD_GAP
	var origin_x: float = (vp.x - total_w) * 0.5 + MemoryCard.CARD_WIDTH * 0.5
	var origin_y: float = (vp.y - total_h + TOP_BAR_HEIGHT) * 0.5\
		+ MemoryCard.CARD_HEIGHT * 0.5
	## Інстанціювати картки
	for i: int in pairs.size():
		var pair: Dictionary = pairs[i]
		@warning_ignore("integer_division")
		var col: int = i % _grid_cols
		@warning_ignore("integer_division")
		var row: int = i / _grid_cols
		var target: Vector2 = Vector2(
			origin_x + float(col) * (MemoryCard.CARD_WIDTH + CARD_GAP),
			origin_y + float(row) * (MemoryCard.CARD_HEIGHT + CARD_GAP))
		var tex_path: String = "res://assets/sprites/animals/%s.png" % pair.name
		if not ResourceLoader.exists(tex_path):
			push_warning("MemoryCards: Missing sprite: " + tex_path)
			continue
		var front_tex: Texture2D = load(tex_path)
		if not front_tex:
			push_warning("MemoryCards: текстуру '%s' не знайдено" % tex_path)
			continue
		var card: Node2D = CARD_SCENE.instantiate()
		add_child(card)
		card.setup(pair.name, front_tex, _back_tex, _is_toddler)
		_cards.append(card)
		## Анімація deal — стартує з правого боку з дугою (LAW 28 premium)
		if SettingsManager.reduced_motion:
			card.position = target
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
			if i == pairs.size() - 1:
				_input_locked = false
				_reset_idle_timer()
		else:
			## Стартова позиція — з правого боку за екраном, трохи вище
			card.position = Vector2(vp.x + 120.0, vp.y * 0.3)
			card.scale = Vector2(0.6, 0.6)
			card.modulate.a = 0.0
			card.rotation = 0.15
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = create_tween().set_parallel(true)
			tw.tween_property(card, "position", target, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", Vector2.ONE, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "modulate:a", 1.0, 0.15).set_delay(delay)
			tw.tween_property(card, "rotation", 0.0, DEAL_DURATION * 0.8)\
				.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			## Розблокувати після останньої картки
			if i == pairs.size() - 1:
				tw.chain().tween_callback(func() -> void:
					_input_locked = false
					_reset_idle_timer()
				)
	## Перерахувати пари за реально створеними картками (A8: fallback)
	@warning_ignore("integer_division")
	_pairs_count = _cards.size() / 2
	if _pairs_count <= 0:
		push_warning("MemoryCards: жодна картка не створена — пропускаємо раунд")
		_advance_round()


func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _matched_count >= _pairs_count:
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		## A10 Lvl2: tutorial hand — виділити валідну пару дуже чітко
		var hint_id: String = ""
		for card: Node2D in _cards:
			if not card.is_matched:
				hint_id = card.card_id
				break
		if not hint_id.is_empty():
			for card: Node2D in _cards:
				if card.card_id == hint_id and not card.is_matched:
					_pulse_node(card, 1.3)
					## Яскравий golden flash щоб привернути увагу
					if not SettingsManager.reduced_motion:
						var flash_tw: Tween = create_tween()
						flash_tw.tween_property(card, "modulate", Color(1.5, 1.3, 0.7, 1.0), 0.15)
						flash_tw.tween_property(card, "modulate", Color.WHITE, 0.3)
		_reset_idle_timer()
		return
	## Знайти першу непройдену пару для підказки
	var hint_id2: String = ""
	for card: Node2D in _cards:
		if not card.is_matched:
			hint_id2 = card.card_id
			break
	if hint_id2.is_empty():
		return
	## Пульсувати обидві картки пари
	for card: Node2D in _cards:
		if card.card_id == hint_id2 and not card.is_matched:
			_pulse_node(card, 1.15)
	_reset_idle_timer()


func _pick_random_indices(count: int) -> Array[int]:
	var all: Array[int] = []
	for i: int in GameData.ANIMALS_AND_FOOD.size():
		if not _used_indices.has(i):
			all.append(i)
	all.shuffle()
	if all.size() < count:
		_used_indices.clear()
		all.clear()
		for i: int in GameData.ANIMALS_AND_FOOD.size():
			all.append(i)
		all.shuffle()
	var picked: Array[int] = []
	for i: int in mini(count, all.size()):
		picked.append(all[i])
		_used_indices.append(all[i])
	return picked
