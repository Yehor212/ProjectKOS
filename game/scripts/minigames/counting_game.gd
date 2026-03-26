extends BaseMiniGame

## Count with Tofie — лічба! Toddler: збери N фруктів у кошик.
## Preschool: розв'яжи рівняння (додавання).

const ITEM_SCENE: PackedScene = preload("res://scenes/components/counting_item.tscn")
const TOTAL_ROUNDS: int = 5
const ITEM_RADIUS: float = 45.0
const ANSWER_RADIUS: float = 55.0
const TAP_RADIUS: float = 65.0
const DEAL_STAGGER: float = 0.1
const DEAL_DURATION: float = 0.4
const IDLE_HINT_DELAY: float = 5.0
## Piaget/Cowan: прогресивні дистрактори замість фіксованих 3.
## Round 1 = 0 (найпростіше для 2-3 років, WM ~1-1.5 об'єкта).
const TODDLER_DISTRACTORS_MIN: int = 0
const TODDLER_DISTRACTORS_MAX: int = 3
const ANSWER_COLORS: Array[Color] = [Color("ff6b6b"), Color("3b82f6"), Color("22c55e")]
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

## Toddler
var _drag: UniversalDrag = null
var _items: Array[Node2D] = []
var _basket: Node2D = null
var _target_count: int = 0
var _current_count: int = 0
var _target_fruit: Dictionary = {}
var _origins: Dictionary = {}

## Preschool
var _answer_nodes: Array[Node2D] = []
var _correct_answer: int = 0

## Антиповтор фруктів у межах сесії
var _used_fruit_idx: Array[int] = []

## UI
var _counter_label: Label = null
var _equation_label: Label = null
var _idle_timer: SceneTreeTimer = null
var _count_dots: Array[Panel] = []


func _ready() -> void:
	game_id = "counting"
	bg_theme = "meadow"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	if _is_toddler:
		_drag = UniversalDrag.new(self)
		_drag.snap_radius_override = TODDLER_SNAP_RADIUS
		_drag.item_dropped_on_target.connect(_on_dropped_on_target)
		_drag.item_dropped_on_empty.connect(_on_dropped_on_empty)
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


func _input(event: InputEvent) -> void:
	if _game_over:
		return
	if _is_toddler:
		if not _input_locked:
			_drag.handle_input(event)
		return
	## Preschool — tap routing (патерн: odd_one_out)
	if _input_locked:
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
	for node: Node2D in _answer_nodes:
		if not is_instance_valid(node) or node.get_meta("disabled", false):
			continue
		if pos.distance_to(node.global_position) < TAP_RADIUS:
			_handle_answer_tap(node)
			return


func _process(delta: float) -> void:
	if _is_toddler and _drag and not _input_locked:
		_drag.handle_process(delta)


## ---- Управління раундами ----


func _start_round() -> void:
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	if _is_toddler:
		_setup_toddler_round()
	else:
		_setup_preschool_round()


func _advance_round() -> void:
	_input_locked = true
	_clear_round()
	_round += 1
	if _round >= TOTAL_ROUNDS:
		_finish()
	else:
		await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(self) or _game_over:
			return
		_start_round()


func _clear_round() -> void:
	for item: Node2D in _items:
		if is_instance_valid(item):
			_origins.erase(item)
			item.queue_free()
	_items.clear()
	if _drag:
		_drag.draggable_items.clear()
		_drag.drop_targets.clear()
		_drag.clear_drag()
	if is_instance_valid(_basket):
		_basket.queue_free()
		_basket = null
	_counter_label = null  ## дочірній вузол _basket, звільняється разом
	for node: Node2D in _answer_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_answer_nodes.clear()
	if is_instance_valid(_equation_label):
		_equation_label.queue_free()
		_equation_label = null


## ---- Toddler: збери фрукти у кошик ----


func _setup_toddler_round() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_current_count = 0
	## Обрати фрукт та кількість (без повторів у межах сесії)
	var fruit_idx: int = _pick_unused_fruit_idx()
	_target_fruit = FRUITS[fruit_idx]
	var min_count: int = _scale_by_round_i(1, 3, _round, TOTAL_ROUNDS)
	var max_count: int = _scale_by_round_i(3, 5, _round, TOTAL_ROUNDS)
	_target_count = randi_range(min_count, max_count)
	## Обрати інший фрукт для відволікачів
	var dist_idx: int = (fruit_idx + 1 + randi() % maxi(FRUITS.size() - 1, 1)) % FRUITS.size()
	var distractor: Dictionary = FRUITS[dist_idx]
	_fade_instruction(_instruction_label, tr("COUNTING_GIVE_TOFIE") % [_target_count, tr("FRUIT_" + _target_fruit.type.to_upper())])
	## Кошик (дропзона)
	_basket = Node2D.new()
	_basket.position = Vector2(vp.x * 0.5, vp.y * 0.32)
	add_child(_basket)
	var basket_icon: Control = IconDraw.basket(60.0)
	basket_icon.position = Vector2(-30, -35)
	basket_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_basket.add_child(basket_icon)
	_counter_label = Label.new()
	_counter_label.text = tr("COUNTING_COUNTER") % [0, _target_count]
	_counter_label.add_theme_font_size_override("font_size", 26)
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.position = Vector2(-60, 50)
	_counter_label.size = Vector2(120, 35)
	## Piaget: приховати текстовий лічильник "0/3" для pre-numerate дітей (2-3 роки).
	## Progress dots залишаються як візуальний індикатор прогресу.
	_counter_label.visible = _is_preschool
	_basket.add_child(_counter_label)
	## Візуальні крапки прогресу лічби
	_count_dots.clear()
	var dot_y: float = 85.0
	var dot_spacing: float = 22.0
	var dots_w: float = float(_target_count) * dot_spacing
	var dot_start_x: float = -dots_w * 0.5 + dot_spacing * 0.5
	for di: int in _target_count:
		var dot: Panel = Panel.new()
		dot.size = Vector2(14, 14)
		dot.position = Vector2(dot_start_x + float(di) * dot_spacing - 7.0, dot_y)
		dot.add_theme_stylebox_override("panel", GameData.candy_circle(Color(1, 1, 1, 0.3), 7.0, false))
		## Grain overlay (LAW 28)
		dot.material = GameData.create_premium_material(0.03, 2.0, 0.0, 0.0, 0.0, 0.04, 0.10, "", 0.0, 0.10, 0.22, 0.18)
		_basket.add_child(dot)
		_count_dots.append(dot)
	_drag.drop_targets.append(_basket)
	## Спавн фруктів
	var fruit_list: Array[Dictionary] = []
	for _i: int in range(_target_count):
		fruit_list.append(_target_fruit)
	var distractor_count: int = _scale_by_round_i(TODDLER_DISTRACTORS_MIN, TODDLER_DISTRACTORS_MAX, _round, TOTAL_ROUNDS)
	for _i: int in range(distractor_count):
		fruit_list.append(distractor)
	fruit_list.shuffle()
	var total: int = fruit_list.size()
	var cols: int = mini(total, 4)
	var area_w: float = vp.x * 0.8
	var area_h: float = vp.y * 0.32
	var start_x: float = vp.x * 0.1
	var start_y: float = vp.y * 0.58
	var cell_w: float = area_w / float(cols)
	@warning_ignore("integer_division")
	var rows: int = (total + cols - 1) / cols
	var cell_h: float = area_h / float(maxi(rows, 1))
	for i: int in range(total):
		var data: Dictionary = fruit_list[i]
		var col: int = i % cols
		@warning_ignore("integer_division")
		var row: int = i / cols
		var jitter: Vector2 = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		var pos: Vector2 = Vector2(
			start_x + cell_w * (float(col) + 0.5),
			start_y + cell_h * (float(row) + 0.5)
		) + jitter
		var item: Node2D = ITEM_SCENE.instantiate()
		add_child(item)
		item.setup_with_icon(data.type, IconDraw.fruit_icon(data.type, ITEM_RADIUS * 1.2), data.color, ITEM_RADIUS)
		item.origin_pos = pos
		_items.append(item)
		_origins[item] = pos
		_drag.draggable_items.append(item)
		_deal_item_in(item, pos, i, total)


func _on_dropped_on_target(item: Node2D, _target: Node2D) -> void:
	if _game_over:
		return
	if item.fruit_type == _target_fruit.type:
		## Правильний фрукт!
		_register_correct(item)
		_current_count += 1
		_counter_label.text = tr("COUNTING_COUNTER") % [_current_count, _target_count]
		## Заповнити крапку прогресу
		var dot_idx: int = _current_count - 1
		if dot_idx >= 0 and dot_idx < _count_dots.size():
			var dot: Panel = _count_dots[dot_idx]
			if is_instance_valid(dot):
				dot.add_theme_stylebox_override("panel", GameData.candy_circle(_target_fruit.color, 7.0, false))
		_drag.draggable_items.erase(item)
		_origins.erase(item)
		## Зникнення в кошик
		if SettingsManager.reduced_motion:
			item.global_position = _basket.global_position
			item.modulate.a = 0.0
			_items.erase(item)
			if is_instance_valid(item):
				item.queue_free()
		else:
			var tw: Tween = create_tween().set_parallel(true)
			tw.tween_property(item, "global_position", _basket.global_position, 0.25)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.tween_property(item, "scale", Vector2(0.2, 0.2), 0.25)
			tw.tween_property(item, "modulate:a", 0.0, 0.2).set_delay(0.05)
			tw.chain().tween_callback(func() -> void:
				_items.erase(item)
				if is_instance_valid(item):
					item.queue_free())
			## Squish кошика
			var bsq: Tween = create_tween()
			bsq.tween_property(_basket, "scale", Vector2(1.15, 0.9), 0.08)
			bsq.tween_property(_basket, "scale", Vector2.ONE, 0.12)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		if _current_count >= _target_count:
			_input_locked = true
			VFXManager.spawn_premium_celebration(_basket.global_position)
			var delay_d: float = 0.15 if SettingsManager.reduced_motion else 0.6
			var delay: Tween = create_tween()
			delay.tween_interval(delay_d)
			delay.tween_callback(_advance_round)
		else:
			_reset_idle_timer()
	else:
		## Неправильний фрукт
		if _is_toddler:
			_register_error(item)  ## A11: scaffolding для тоддлера
		else:
			_errors += 1
			_register_error(item)
		if _origins.has(item):
			_drag.snap_back(item, _origins[item])
		_reset_idle_timer()


func _on_dropped_on_empty(item: Node2D) -> void:
	if _origins.has(item):
		_drag.snap_back(item, _origins[item])


## ---- Preschool: рівняння ----


func _setup_preschool_round() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_fade_instruction(_instruction_label, tr("COUNTING_TUTORIAL_PRESCHOOL"))
	## Генерація рівняння
	var max_a: int = _scale_by_round_i(3, 6, _round, TOTAL_ROUNDS)
	var max_b: int = _scale_by_round_i(2, 4, _round, TOTAL_ROUNDS)
	var a: int = randi_range(1, max_a)
	var b: int = randi_range(1, max_b)
	_correct_answer = a + b
	_equation_label = Label.new()
	_equation_label.text = "%d  +  %d  =  ?" % [a, b]
	_equation_label.add_theme_font_size_override("font_size", 64)
	_equation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equation_label.position = Vector2(0, vp.y * 0.25)
	_equation_label.size = Vector2(vp.x, 80)
	add_child(_equation_label)
	## Відповіді
	var answers: Array[int] = [_correct_answer]
	answers.append_array(_generate_wrong_answers(_correct_answer))
	answers.shuffle()
	var spacing: float = vp.x / float(answers.size() + 1)
	var btn_y: float = vp.y * 0.65
	for i: int in range(answers.size()):
		var node: Node2D = ITEM_SCENE.instantiate()
		add_child(node)
		node.setup("answer", str(answers[i]), ANSWER_COLORS[i], ANSWER_RADIUS)
		node.set_meta("is_correct", answers[i] == _correct_answer)
		node.set_meta("disabled", false)
		var pos: Vector2 = Vector2(spacing * float(i + 1), btn_y)
		_answer_nodes.append(node)
		_deal_item_in(node, pos, i, answers.size())


func _handle_answer_tap(node: Node2D) -> void:
	_input_locked = true
	if node.get_meta("is_correct"):
		_register_correct(node)
		VFXManager.spawn_premium_celebration(node.global_position)
		if not SettingsManager.reduced_motion:
			var tw: Tween = create_tween()
			tw.tween_property(node, "scale", Vector2(1.4, 1.4), 0.15)
			tw.tween_property(node, "scale", Vector2(1.2, 1.2), 0.1)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			for other: Node2D in _answer_nodes:
				if other != node and is_instance_valid(other):
					create_tween().tween_property(other, "modulate:a", 0.3, 0.3)
			tw.tween_interval(0.5)
			tw.tween_callback(_advance_round)
		else:
			var tw_d: Tween = create_tween()
			tw_d.tween_interval(0.15)
			tw_d.tween_callback(_advance_round)
	else:
		_errors += 1
		_register_error(node)
		node.set_meta("disabled", true)
		node.modulate = Color(0.5, 0.5, 0.5)
		if not SettingsManager.reduced_motion:
			var orig_x: float = node.position.x
			var tw: Tween = create_tween()
			tw.tween_property(node, "position:x", orig_x - 6.0, 0.06)
			tw.tween_property(node, "position:x", orig_x + 6.0, 0.06)
			tw.tween_property(node, "position:x", orig_x - 3.0, 0.04)
			tw.tween_property(node, "position:x", orig_x, 0.04)
			tw.tween_callback(func() -> void:
				_input_locked = false
				_reset_idle_timer())
		else:
			_input_locked = false
			_reset_idle_timer()


func _generate_wrong_answers(correct: int) -> Array[int]:
	var pool: Array[int] = []
	for v: int in range(maxi(2, correct - 3), correct + 4):
		if v != correct and v > 0:
			pool.append(v)
	pool.shuffle()
	if pool.size() < 2:
		push_warning("CountingGame: пул неправильних відповідей < 2, fallback")
		return [correct + 1, correct + 2]
	return [pool[0], pool[1]]


## ---- Антиповтор фруктів ----


func _pick_unused_fruit_idx() -> int:
	## Вибирає індекс фрукта, якого ще не було в цій сесії. Скидає пул при вичерпанні.
	if _used_fruit_idx.size() >= FRUITS.size():
		_used_fruit_idx.clear()
	var available: Array[int] = []
	for i: int in FRUITS.size():
		if i not in _used_fruit_idx:
			available.append(i)
	if available.is_empty():
		push_warning("CountingGame: пул фруктів порожній, fallback")
		return randi() % FRUITS.size()
	available.shuffle()
	var idx: int = available[0]
	_used_fruit_idx.append(idx)
	return idx


## ---- Спільне ----


func _deal_item_in(item: Node2D, pos: Vector2, idx: int, total: int) -> void:
	if SettingsManager.reduced_motion:
		item.position = pos
		item.scale = Vector2.ONE
		item.modulate.a = 1.0
		if idx == total - 1:
			_input_locked = false
			_reset_idle_timer()
		return
	item.position = Vector2(pos.x, -200.0)
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


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	var stats: Dictionary = {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": TOTAL_ROUNDS,
		"earned_stars": earned,
	}
	finish_game(earned, stats)


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
	if _is_toddler:
		for item: Node2D in _items:
			if is_instance_valid(item) and item.fruit_type == _target_fruit.type:
				_pulse_node(item, 1.2)
				break
	else:
		for node: Node2D in _answer_nodes:
			if is_instance_valid(node) and node.get_meta("is_correct", false):
				_pulse_node(node, 1.2)
				break
	_reset_idle_timer()


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("COUNTING_TUTORIAL_TODDLER")
	return tr("COUNTING_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _is_toddler:
		## Перетягнути перший правильний фрукт у кошик
		for item: Node2D in _items:
			if is_instance_valid(item) and item.fruit_type == _target_fruit.type:
				if is_instance_valid(_basket):
					return {"type": "drag", "from": item.global_position, "to": _basket.global_position}
	else:
		## Натиснути правильну відповідь
		for node: Node2D in _answer_nodes:
			if is_instance_valid(node) and node.get_meta("is_correct", false):
				return {"type": "tap", "target": node.global_position}
	return {}
