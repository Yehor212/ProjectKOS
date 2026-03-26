extends BaseMiniGame

## Порівняння — яка група більша чи менша?
## Toddler: завжди "більше", однаковий фрукт, 1-4. Preschool: більше/менше, різні фрукти, 2-7.

const ITEM_SCENE: PackedScene = preload("res://scenes/components/counting_item.tscn")
const TOTAL_ROUNDS: int = 5
const ITEM_RADIUS: float = 52.0
const DEAL_STAGGER: float = 0.08
const DEAL_DURATION: float = 0.35
const IDLE_HINT_DELAY: float = 5.0
const CLUSTER_SPREAD: float = 80.0
const SAFETY_TIMEOUT_SEC: float = 120.0

const FRUITS: Array[Dictionary] = [
	{"type": "apple", "color": Color("ff6b6b")},
	{"type": "banana", "color": Color("ffd166")},
	{"type": "orange", "color": Color("ff9f1c")},
	{"type": "grape", "color": Color("a855f7")},
	{"type": "watermelon", "color": Color("06d6a0")},
]

var _is_toddler: bool = false
var _round: int = 0
var _start_time: float = 0.0

var _ask_more: bool = true
var _correct_side: int = 0
var _left_items: Array[Node2D] = []
var _right_items: Array[Node2D] = []

## Антиповтор фруктів між раундами
var _used_fruit_idx: Array[int] = []

var _vs_label: Label = null
var _left_tap: Panel = null
var _right_tap: Panel = null
var _equal_tap: Panel = null  ## Preschool R3+: кнопка "рівно" (LAW 2: 3-й вибір)
var _idle_timer: SceneTreeTimer = null
var _direction_icon: Control = null
var _narrative_label: Label = null


func _ready() -> void:
	game_id = "compare"
	bg_theme = "meadow"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_build_narrative_label(tr("WHO_ATE_MORE"))
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


## Наратив — "Хто з'їв більше?" лейбл
func _build_narrative_label(text: String) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_narrative_label = Label.new()
	_narrative_label.text = text
	_narrative_label.add_theme_font_size_override("font_size", 28)
	_narrative_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_narrative_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narrative_label.position = Vector2(0, vp.y * 0.12)
	_narrative_label.size = Vector2(vp.x, 40)
	_ui_layer.add_child(_narrative_label)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("COMPARE_TUTORIAL_TODDLER")
	return tr("COMPARE_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	var correct_items: Array[Node2D] = _left_items if _correct_side == 0 else _right_items
	if correct_items.is_empty():
		return {}
	return {"type": "tap", "target": correct_items[0].global_position}


func _build_hud() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_build_instruction_pill(get_tutorial_instruction())
	_vs_label = Label.new()
	_vs_label.text = tr("COMPARE_VS")
	_vs_label.add_theme_font_size_override("font_size", 48)
	_vs_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	_vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vs_label.position = Vector2(vp.x * 0.5 - 50, vp.y * 0.48)
	_vs_label.size = Vector2(100, 60)
	add_child(_vs_label)
	## Tap targets — видимі кнопки замість невидимого тапу по половині екрану
	var tap_w: float = vp.x * 0.35
	var tap_h: float = 64.0
	var tap_y: float = vp.y * 0.78
	_left_tap = Panel.new()
	_left_tap.size = Vector2(tap_w, tap_h)
	_left_tap.position = Vector2(vp.x * 0.25 - tap_w * 0.5, tap_y)
	_left_tap.add_theme_stylebox_override("panel",
		GameData.candy_panel(Color("06d6a0", 0.7), 20))
	## Grain overlay (LAW 28)
	_left_tap.material = GameData.create_premium_material(0.04, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
	var left_icon: Control = IconDraw.tap_finger(28.0)
	left_icon.position = Vector2((tap_w - 28.0) * 0.5, (tap_h - 28.0) * 0.5)
	_left_tap.add_child(left_icon)
	add_child(_left_tap)
	_right_tap = Panel.new()
	_right_tap.size = Vector2(tap_w, tap_h)
	_right_tap.position = Vector2(vp.x * 0.75 - tap_w * 0.5, tap_y)
	_right_tap.add_theme_stylebox_override("panel",
		GameData.candy_panel(Color("06d6a0", 0.7), 20))
	## Grain overlay (LAW 28)
	_right_tap.material = GameData.create_premium_material(0.04, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
	var right_icon: Control = IconDraw.tap_finger(28.0)
	right_icon.position = Vector2((tap_w - 28.0) * 0.5, (tap_h - 28.0) * 0.5)
	_right_tap.add_child(right_icon)
	add_child(_right_tap)
	## Preschool: кнопка "Рівно" по центру (LAW 2: 3-й вибір, вчить рівність)
	if not _is_toddler:
		_equal_tap = Panel.new()
		## Ширина = проміжок між left та right кнопками мінус відступи (щоб не перекривались)
		var eq_w: float = minf(tap_w * 0.45, vp.x * 0.15)
		_equal_tap.size = Vector2(eq_w, tap_h)
		_equal_tap.position = Vector2(vp.x * 0.5 - eq_w * 0.5, tap_y + tap_h + 16.0)
		_equal_tap.add_theme_stylebox_override("panel",
			GameData.candy_panel(Color("ffd166", 0.7), 20))
		_equal_tap.material = GameData.create_premium_material(0.04, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		var eq_lbl: Label = Label.new()
		eq_lbl.text = "="
		eq_lbl.add_theme_font_size_override("font_size", 32)
		eq_lbl.add_theme_color_override("font_color", Color.WHITE)
		eq_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		eq_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		eq_lbl.position = Vector2.ZERO
		eq_lbl.size = Vector2(minf(tap_w * 0.45, vp.x * 0.15), tap_h)
		_equal_tap.add_child(eq_lbl)
		add_child(_equal_tap)
		_equal_tap.visible = false  ## Показується тільки коли потрібно (R3+)


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
	var pos: Vector2 = get_global_mouse_position()
	## Визначити сторону через tap target панелі (не невидимий поділ екрану)
	var side: int = -1
	if _left_tap and Rect2(_left_tap.position, _left_tap.size).has_point(pos):
		side = 0
	elif _right_tap and Rect2(_right_tap.position, _right_tap.size).has_point(pos):
		side = 1
	elif _equal_tap and _equal_tap.visible and Rect2(_equal_tap.position, _equal_tap.size).has_point(pos):
		side = 2  ## "Рівно"
	if side == -1:
		return
	_input_locked = true
	if side == _correct_side:
		_handle_correct(side)
	else:
		_handle_wrong(side)


func _start_round() -> void:
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	_generate_round()
	_spawn_groups()


func _generate_round() -> void:
	if _is_toddler:
		_ask_more = true
	else:
		_ask_more = (randi() % 2 == 0)
	## Прогресивна складність: ранні раунди — очевидна різниця, пізні — ближчі числа
	var lo: int = 1 if _is_toddler else _scale_by_round_i(1, 2, _round, TOTAL_ROUNDS)
	var hi: int = _scale_by_round_i(3, 5, _round, TOTAL_ROUNDS) if _is_toddler \
		else _scale_by_round_i(4, 7, _round, TOTAL_ROUNDS)
	var left: int = randi_range(lo, hi)
	var right: int = randi_range(lo, hi)
	## Preschool R3+: 25% шанс на "рівно" — вчить поняттю рівності (research: 3rd choice for LAW 2)
	var allow_equal: bool = (not _is_toddler and _round >= 3 and randf() < 0.25)
	if not allow_equal:
		var safety: int = 0
		while right == left and safety < 20:
			right = randi_range(lo, hi)
			safety += 1
		if right == left:
			right = left + (1 if left < hi else -1)
			push_warning("CompareGame: не вдалося згенерувати різні кількості")
	## Показати/сховати кнопку "рівно" для Preschool R3+
	if _equal_tap:
		_equal_tap.visible = (not _is_toddler and _round >= 3)
	if left == right:
		## Рівно — правильна відповідь = центральна кнопка (side 2)
		_correct_side = 2
		_fade_instruction(_instruction_label, tr("COMPARE_EQUAL_OR_NOT"))
		_update_direction_icon(true)
	elif _ask_more:
		_correct_side = 0 if left > right else 1
		_fade_instruction(_instruction_label, tr("COMPARE_WHICH_MORE"))
		_update_direction_icon(true)
	else:
		_correct_side = 0 if left < right else 1
		_fade_instruction(_instruction_label, tr("COMPARE_WHICH_FEWER"))
		_update_direction_icon(false)
	_spawn_group_items(left, right)


func _update_direction_icon(is_up: bool) -> void:
	if is_instance_valid(_direction_icon):
		_direction_icon.queue_free()
	_direction_icon = IconDraw.arrow_up(24.0, Color("FF6B6B")) if is_up else IconDraw.arrow_down(24.0, Color("4ECDC4"))
	if is_instance_valid(_instruction_label):
		## Позиція — зліва від інструкції
		var lbl_pos: Vector2 = _instruction_label.global_position
		_direction_icon.position = Vector2(lbl_pos.x - 32.0, lbl_pos.y + 4.0)
		_ui_layer.add_child(_direction_icon)


func _spawn_group_items(left_count: int, right_count: int) -> void:
	## Вибір фруктів без повторів між раундами
	var fruit_a_idx: int = _pick_unused_fruit_idx()
	var left_fruit: Dictionary = FRUITS[fruit_a_idx]
	var right_fruit: Dictionary
	if _is_toddler:
		right_fruit = left_fruit
	else:
		var fruit_b_idx: int = (fruit_a_idx + 1 + randi() % maxi(FRUITS.size() - 1, 1)) % FRUITS.size()
		right_fruit = FRUITS[fruit_b_idx]
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var cy: float = vp.y * 0.52
	var idx: int = 0
	var total: int = left_count + right_count
	for pos: Vector2 in _cluster_positions(left_count, Vector2(vp.x * 0.25, cy)):
		var item: Node2D = ITEM_SCENE.instantiate()
		add_child(item)
		item.setup_with_icon(left_fruit.type, IconDraw.fruit_icon(left_fruit.type, ITEM_RADIUS * 1.2), left_fruit.color, ITEM_RADIUS)
		_deal_item_in(item, pos, idx, total)
		_left_items.append(item)
		idx += 1
	for pos: Vector2 in _cluster_positions(right_count, Vector2(vp.x * 0.75, cy)):
		var item: Node2D = ITEM_SCENE.instantiate()
		add_child(item)
		item.setup_with_icon(right_fruit.type, IconDraw.fruit_icon(right_fruit.type, ITEM_RADIUS * 1.2), right_fruit.color, ITEM_RADIUS)
		_deal_item_in(item, pos, idx, total)
		_right_items.append(item)
		idx += 1


func _spawn_groups() -> void:
	pass  ## Логіка об'єднана в _spawn_group_items для компактності


func _cluster_positions(count: int, center: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count == 1:
		positions.append(center)
		return positions
	var angle_step: float = TAU / float(count)
	var radius: float = CLUSTER_SPREAD * (0.35 + 0.12 * float(count))
	for i: int in range(count):
		var angle: float = angle_step * float(i) - PI * 0.5
		var jitter: Vector2 = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		positions.append(center + Vector2(cos(angle), sin(angle)) * radius + jitter)
	return positions


func _handle_correct(side: int) -> void:
	## side 0=ліва, 1=права, 2=рівно (обидві)
	var correct_items: Array[Node2D] = _left_items if side == 0 else (_right_items if side == 1 else _left_items)
	if not correct_items.is_empty():
		_register_correct(correct_items[0])
	else:
		_register_correct()
	var winners: Array[Node2D] = _left_items + _right_items if side == 2 else (_left_items if side == 0 else _right_items)
	var losers: Array[Node2D] = [] if side == 2 else (_right_items if side == 0 else _left_items)
	if not winners.is_empty():
		VFXManager.spawn_premium_celebration(winners[0].global_position)
		## Hearts VFX на переможців
		for w: Node2D in winners:
			if is_instance_valid(w):
				VFXManager.spawn_correct_sparkle(w.global_position)
	for item: Node2D in winners:
		if is_instance_valid(item):
			_animate_correct_item(item)
	if not SettingsManager.reduced_motion:
		## Happy dance — bounce + rotation wiggle для переможців
		for item: Node2D in winners:
			if is_instance_valid(item):
				var tw: Tween = create_tween()
				tw.tween_property(item, "scale", Vector2(1.3, 1.3), 0.1)
				tw.tween_property(item, "rotation_degrees", 8.0, 0.06)
				tw.tween_property(item, "rotation_degrees", -8.0, 0.06)
				tw.tween_property(item, "rotation_degrees", 0.0, 0.06)
				tw.tween_property(item, "scale", Vector2.ONE, 0.15)\
					.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		## Losers — surprised gentle shake (no punishment)
		for item: Node2D in losers:
			if is_instance_valid(item):
				var orig_x: float = item.position.x
				var sh: Tween = create_tween()
				sh.tween_property(item, "position:x", orig_x - 5.0, 0.05)
				sh.tween_property(item, "position:x", orig_x + 5.0, 0.05)
				sh.tween_property(item, "position:x", orig_x, 0.05)
				sh.tween_property(item, "modulate:a", 0.3, 0.3)
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.7
	var delay_tw: Tween = create_tween()
	delay_tw.tween_interval(d)
	delay_tw.tween_callback(_advance_round)


func _handle_wrong(side: int) -> void:
	## side 2 = "equal" button tapped wrongly — анімація обох сторін
	var items: Array[Node2D] = _left_items + _right_items if side == 2 else (_left_items if side == 0 else _right_items)
	if _is_toddler:
		_register_error(items[0] if not items.is_empty() else null)  ## A11: scaffolding для тоддлера
		AudioManager.play_sfx("click")
		if not SettingsManager.reduced_motion:
			for item: Node2D in items:
				if is_instance_valid(item):
					var tw: Tween = create_tween()
					tw.tween_property(item, "rotation", 0.1, 0.06)
					tw.tween_property(item, "rotation", -0.1, 0.06)
					tw.tween_property(item, "rotation", 0.0, 0.06)
		var unlock_d: float = 0.15 if SettingsManager.reduced_motion else 0.2
		var unlock_tw: Tween = create_tween()
		unlock_tw.tween_interval(unlock_d)
		unlock_tw.tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer())
	else:
		_errors += 1
		_register_error(items[0] if not items.is_empty() else null)
		AudioManager.play_sfx("error")
		HapticsManager.vibrate_light()
		if not items.is_empty():
			VFXManager.spawn_error_smoke(items[0].global_position)
		if not SettingsManager.reduced_motion:
			for item: Node2D in items:
				if is_instance_valid(item):
					var orig_x: float = item.position.x
					var tw: Tween = create_tween()
					tw.tween_property(item, "position:x", orig_x - 6.0, 0.06)
					tw.tween_property(item, "position:x", orig_x + 6.0, 0.06)
					tw.tween_property(item, "position:x", orig_x - 3.0, 0.04)
					tw.tween_property(item, "position:x", orig_x, 0.04)
		var unlock_d2: float = 0.15 if SettingsManager.reduced_motion else 0.25
		var unlock_tw: Tween = create_tween()
		unlock_tw.tween_interval(unlock_d2)
		unlock_tw.tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer())


func _advance_round() -> void:
	_input_locked = true
	_clear_round()
	_round += 1
	if _round >= TOTAL_ROUNDS:
		_finish()
	else:
		_start_round()


func _clear_round() -> void:
	for item: Node2D in _left_items:
		if is_instance_valid(item):
			item.queue_free()
	_left_items.clear()
	for item: Node2D in _right_items:
		if is_instance_valid(item):
			item.queue_free()
	_right_items.clear()


func _deal_item_in(item: Node2D, pos: Vector2, idx: int, total: int) -> void:
	if SettingsManager.reduced_motion:
		item.position = pos
		item.scale = Vector2.ONE
		item.modulate.a = 1.0
		if idx == total - 1:
			_input_locked = false
			_reset_idle_timer()
		return
	item.position = Vector2(pos.x, pos.y + 200.0)
	item.scale = Vector2(0.2, 0.2)
	item.modulate.a = 0.0
	var delay: float = float(idx) * DEAL_STAGGER
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(item, "position", pos, DEAL_DURATION)\
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "scale", Vector2.ONE, DEAL_DURATION)\
		.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
	if idx == total - 1:
		tw.chain().tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer())


## ---- Антиповтор фруктів ----


func _pick_unused_fruit_idx() -> int:
	## Вибирає індекс фрукта, якого ще не було. Скидає пул при вичерпанні.
	if _used_fruit_idx.size() >= FRUITS.size():
		_used_fruit_idx.clear()
	var available: Array[int] = []
	for i: int in FRUITS.size():
		if i not in _used_fruit_idx:
			available.append(i)
	if available.is_empty():
		push_warning("CompareGame: пул фруктів порожній, fallback")
		return randi() % FRUITS.size()
	available.shuffle()
	var idx: int = available[0]
	_used_fruit_idx.append(idx)
	return idx


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": TOTAL_ROUNDS, "earned_stars": earned})


func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over:
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	var correct_items: Array[Node2D] = _left_items if _correct_side == 0 else _right_items
	for item: Node2D in correct_items:
		if is_instance_valid(item):
			_pulse_node(item, 1.2)
	_reset_idle_timer()
