extends BaseMiniGame

## Візерунки — знайди наступний елемент послідовності.
## Toddler: 2-елементні патерни (ABAB?). Preschool: 2-3 елементні (ABCABC?).
## Наратив: "Чарівник створює візерунки!" — немає спрайту чарівника,
## наратив передається через текст інструкції (tr("WIZARD_PATTERNS")).

const ITEM_SCENE: PackedScene = preload("res://scenes/components/counting_item.tscn")
const TOTAL_ROUNDS: int = 5
const ITEM_RADIUS: float = 52.0
const ANSWER_RADIUS: float = 60.0
const TAP_RADIUS: float = 70.0
const DEAL_STAGGER: float = 0.08
const DEAL_DURATION: float = 0.35
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0

const SHAPES: Array[Dictionary] = [
	{"id": "red", "color": Color("ff6b6b")},
	{"id": "blue", "color": Color("4dabf7")},
	{"id": "star", "color": Color("ffd43b")},
	{"id": "green", "color": Color("51cf66")},
	{"id": "purple", "color": Color("cc5de8")},
	{"id": "orange", "color": Color("ff922b")},
]

var _is_toddler: bool = false
var _round: int = 0
var _start_time: float = 0.0

var _pattern_items: Array[Node2D] = []
var _question_mark: Node2D = null
var _answer_items: Array[Node2D] = []
var _correct_shape: Dictionary = {}
var _idle_timer: SceneTreeTimer = null


func _ready() -> void:
	game_id = "pattern"
	bg_theme = "puzzle"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	## Наративна обгортка: "Чарівник створює візерунки!"
	if _is_toddler:
		return tr("WIZARD_PATTERNS") + " " + tr("PATTERN_TUTORIAL_TODDLER")
	return tr("WIZARD_PATTERNS") + " " + tr("PATTERN_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	for item: Node2D in _answer_items:
		if is_instance_valid(item) and item.get_meta("is_correct", false):
			return {"type": "tap", "target": item.global_position}
	return {}


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
	for item: Node2D in _answer_items:
		if not is_instance_valid(item):
			continue
		if item.get_meta("disabled", false):
			continue
		var tap_r: float = TODDLER_SNAP_RADIUS if _is_toddler else TAP_RADIUS
		if pos.distance_to(item.global_position) < tap_r:
			_handle_tap(item)
			return


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


func _start_round() -> void:
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	var pattern: Dictionary = _generate_pattern()
	_correct_shape = pattern.answer
	_spawn_pattern_row(pattern.sequence)
	_spawn_question_mark(pattern.sequence.size())
	_spawn_answers([pattern.answer, pattern.wrong1, pattern.wrong2])


func _generate_pattern() -> Dictionary:
	var pool: Array[Dictionary] = []
	for s: Dictionary in SHAPES:
		pool.append(s)
	pool.shuffle()

	var unit_size: int = 2
	## Preschool: раунди 0-1 = AB патерн, раунди 2+ = ABC
	if not _is_toddler and _round >= 2:
		unit_size = 3
	var unit: Array[Dictionary] = []
	for i: int in range(unit_size):
		unit.append(pool[i])

	var show_count: int = 4 if _is_toddler else 5
	var total: int = show_count + 1
	var sequence: Array[Dictionary] = []
	for i: int in range(total):
		sequence.append(unit[i % unit_size])

	var answer: Dictionary = sequence[show_count]
	var visible_seq: Array[Dictionary] = sequence.slice(0, show_count)

	## Дистрактори: 1 з патерну + 1 зовнішній
	var wrongs: Array[Dictionary] = []
	for s: Dictionary in unit:
		if s.id != answer.id:
			wrongs.append(s)
	wrongs.shuffle()
	var wrong1: Dictionary = wrongs[0] if not wrongs.is_empty() else pool[unit_size]
	var wrong2: Dictionary = pool[unit_size] if unit_size < pool.size() else pool[0]
	## Перевірити що wrong2 відрізняється від answer і wrong1
	if wrong2.id == answer.id or wrong2.id == wrong1.id:
		for s: Dictionary in pool:
			if s.id != answer.id and s.id != wrong1.id:
				wrong2 = s
				break

	return {"sequence": visible_seq, "answer": answer, "wrong1": wrong1, "wrong2": wrong2}


func _spawn_pattern_row(sequence: Array[Dictionary]) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = sequence.size() + 1  ## +1 для знаку питання
	var spacing: float = vp.x / float(count + 1)
	var y: float = vp.y * 0.35

	for i: int in range(sequence.size()):
		var shape: Dictionary = sequence[i]
		var item: Node2D = ITEM_SCENE.instantiate()
		add_child(item)
		var dot: Control = IconDraw.color_dot(ITEM_RADIUS * 1.2, shape.color)
		item.setup_with_icon(shape.id, dot, shape.color, ITEM_RADIUS)
		var target: Vector2 = Vector2(spacing * float(i + 1), y)
		_deal_item_in(item, target, float(i) * DEAL_STAGGER, false)
		_pattern_items.append(item)


func _spawn_question_mark(seq_count: int) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = seq_count + 1
	var spacing: float = vp.x / float(count + 1)
	var y: float = vp.y * 0.35
	var target: Vector2 = Vector2(spacing * float(seq_count + 1), y)

	_question_mark = ITEM_SCENE.instantiate()
	add_child(_question_mark)
	var q_dot: Control = IconDraw.color_dot(ITEM_RADIUS * 1.2, Color(0.7, 0.6, 0.85, 0.5))
	_question_mark.setup_with_icon("question", q_dot, Color(0.7, 0.6, 0.85, 0.5), ITEM_RADIUS)
	_deal_item_in(_question_mark, target, float(seq_count) * DEAL_STAGGER, false)


func _spawn_answers(choices: Array[Dictionary]) -> void:
	choices.shuffle()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var spacing: float = vp.x / 4.0
	var y: float = vp.y * 0.68
	var total_delay: float = float(_pattern_items.size() + 1) * DEAL_STAGGER

	for i: int in range(choices.size()):
		var shape: Dictionary = choices[i]
		var item: Node2D = ITEM_SCENE.instantiate()
		add_child(item)
		var ans_dot: Control = IconDraw.color_dot(ANSWER_RADIUS * 1.2, shape.color)
		item.setup_with_icon(shape.id, ans_dot, shape.color, ANSWER_RADIUS)
		item.set_meta("is_correct", shape.id == _correct_shape.id)
		item.set_meta("disabled", false)
		item.set_meta("shape_data", shape)
		var target: Vector2 = Vector2(spacing * float(i + 1), y)
		var is_last: bool = (i == choices.size() - 1)
		_deal_item_in(item, target, total_delay + float(i) * DEAL_STAGGER, is_last)
		_answer_items.append(item)


func _deal_item_in(item: Node2D, target: Vector2, delay: float, unlock_on_finish: bool) -> void:
	if SettingsManager.reduced_motion:
		item.position = target
		item.scale = Vector2.ONE
		item.modulate.a = 1.0
		if unlock_on_finish:
			_input_locked = false
			_reset_idle_timer()
		return
	item.position = Vector2(target.x, target.y + 200.0)
	item.scale = Vector2(0.2, 0.2)
	item.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(item, "position", target, DEAL_DURATION)\
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "scale", Vector2.ONE, DEAL_DURATION)\
		.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
	if unlock_on_finish:
		tw.chain().tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer()
		)


func _handle_tap(item: Node2D) -> void:
	_input_locked = true
	if item.get_meta("is_correct", false):
		_handle_correct(item)
	else:
		_handle_wrong(item)


func _handle_correct(item: Node2D) -> void:
	_register_correct(item)
	## VFX sparkle на правильній відповіді (LAW 28)
	VFXManager.spawn_correct_sparkle(item.global_position)
	## Збільшення правильної відповіді
	if not SettingsManager.reduced_motion:
		var bounce_tw: Tween = create_tween()
		bounce_tw.tween_property(item, "scale", Vector2(1.3, 1.3), 0.1)
		bounce_tw.tween_property(item, "scale", Vector2(0.85, 0.85), 0.08)
		bounce_tw.tween_property(item, "scale", Vector2.ONE, 0.12)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	## Заповнити знак питання правильним елементом
	if is_instance_valid(_question_mark):
		var qpos: Vector2 = _question_mark.global_position
		VFXManager.spawn_premium_celebration(qpos)
		var fill: Node2D = ITEM_SCENE.instantiate()
		add_child(fill)
		var fill_dot: Control = IconDraw.color_dot(ITEM_RADIUS * 1.2, _correct_shape.color)
		fill.setup_with_icon(_correct_shape.id, fill_dot,
			_correct_shape.color, ITEM_RADIUS)
		if SettingsManager.reduced_motion:
			fill.position = _question_mark.position
			fill.scale = Vector2.ONE
			fill.modulate.a = 1.0
			_question_mark.modulate.a = 0.0
		else:
			fill.position = item.global_position
			fill.scale = Vector2(0.5, 0.5)
			fill.modulate.a = 0.0
			var fill_tw: Tween = create_tween().set_parallel(true)
			fill_tw.tween_property(fill, "position", _question_mark.position, 0.3)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			fill_tw.tween_property(fill, "scale", Vector2.ONE, 0.3)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			fill_tw.tween_property(fill, "modulate:a", 1.0, 0.15)
			fill_tw.tween_property(_question_mark, "modulate:a", 0.0, 0.15)
		_pattern_items.append(fill)

	## Затухання неправильних відповідей
	if not SettingsManager.reduced_motion:
		for ans: Node2D in _answer_items:
			if is_instance_valid(ans) and ans != item:
				create_tween().tween_property(ans, "modulate:a", 0.3, 0.2)

	## Переможний танець — елементи візерунку послідовно хитаються (rotation wobble)
	_play_victory_dance()

	var tw: Tween = create_tween()
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.9
	tw.tween_interval(d)
	tw.tween_callback(_advance_round)


func _handle_wrong(item: Node2D) -> void:
	if _is_toddler:
		_register_error(item)  ## A11: scaffolding для тоддлера
		## Ніжне хитання головою — не каральне, просто зворотній зв'язок (A6)
		_play_gentle_head_shake(item)
		var tw: Tween = create_tween()
		var d: float = 0.15 if SettingsManager.reduced_motion else 0.3
		tw.tween_interval(d)
		tw.tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer()
		)
	else:
		_errors += 1
		_register_error(item)
		item.modulate = Color(0.5, 0.5, 0.5)
		item.set_meta("disabled", true)
		## Хитання головою — зворотній зв'язок про помилку (A7)
		_play_gentle_head_shake(item)
		if SettingsManager.reduced_motion:
			_input_locked = false
			_reset_idle_timer()
		else:
			var orig_x: float = item.position.x
			var tw: Tween = create_tween()
			tw.tween_property(item, "position:x", orig_x - 6.0, 0.06)
			tw.tween_property(item, "position:x", orig_x + 6.0, 0.06)
			tw.tween_property(item, "position:x", orig_x - 3.0, 0.04)
			tw.tween_property(item, "position:x", orig_x, 0.04)
			tw.tween_callback(func() -> void:
				_input_locked = false
				_reset_idle_timer()
			)


## ---- Святкові анімації ----


## Переможний танець: елементи візерунку послідовно робить rotation wobble
func _play_victory_dance() -> void:
	if SettingsManager.reduced_motion:
		return
	var idx: int = 0
	for item: Node2D in _pattern_items:
		if not is_instance_valid(item):
			continue
		var delay: float = float(idx) * 0.08
		var dance_tw: Tween = create_tween()
		dance_tw.tween_interval(delay)
		dance_tw.tween_property(item, "rotation", deg_to_rad(12.0), 0.1)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		dance_tw.tween_property(item, "rotation", deg_to_rad(-12.0), 0.15)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		dance_tw.tween_property(item, "rotation", deg_to_rad(6.0), 0.1)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		dance_tw.tween_property(item, "rotation", 0.0, 0.1)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		idx += 1


## Ніжне хитання головою — не каральне, підходить і для тоддлерів (A6)
func _play_gentle_head_shake(item: Node2D) -> void:
	if SettingsManager.reduced_motion:
		return
	if not is_instance_valid(item):
		push_warning("Pattern: gentle_head_shake — item invalid")
		return
	var shake_tw: Tween = create_tween()
	shake_tw.tween_property(item, "rotation", deg_to_rad(-5.0), 0.06)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shake_tw.tween_property(item, "rotation", deg_to_rad(5.0), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shake_tw.tween_property(item, "rotation", deg_to_rad(-3.0), 0.06)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shake_tw.tween_property(item, "rotation", 0.0, 0.06)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _advance_round() -> void:
	_clear_round()
	_round += 1
	if _round >= TOTAL_ROUNDS:
		_finish()
	else:
		_start_round()


func _clear_round() -> void:
	for item: Node2D in _pattern_items:
		if is_instance_valid(item):
			item.queue_free()
	_pattern_items.clear()
	if is_instance_valid(_question_mark):
		_question_mark.queue_free()
	_question_mark = null
	for item: Node2D in _answer_items:
		if is_instance_valid(item):
			item.queue_free()
	_answer_items.clear()
	_correct_shape = {}


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": TOTAL_ROUNDS, "earned_stars": earned})


## ---- A11: scaffolding підказка — підсвітити правильний елемент після серії помилок ----

func _show_scaffold_hint() -> void:
	super()
	for item: Node2D in _answer_items:
		if not is_instance_valid(item):
			continue
		if item.get_meta("is_correct", false) and not item.get_meta("disabled", false):
			_pulse_node(item, 1.3)
			## Тимчасове яскраве підсвічування (1.5 сек)
			var orig_mod: Color = item.modulate
			item.modulate = Color(1.4, 1.4, 1.0, 1.0)
			var hint_tw: Tween = create_tween()
			hint_tw.tween_property(item, "modulate", orig_mod, 1.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			return
	push_warning("Pattern: scaffolding — правильну відповідь не знайдено")


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
	## Пульсація правильної відповіді
	for item: Node2D in _answer_items:
		if is_instance_valid(item) and item.get_meta("is_correct", false):
			_pulse_node(item, 1.2)
			break
	_reset_idle_timer()
