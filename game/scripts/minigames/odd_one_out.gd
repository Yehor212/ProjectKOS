extends BaseMiniGame

## Odd One Out — знайди зайве!
## Toddler: 3 однакові + 1 інша тварина. Preschool: 3 з категорії + 1 інтрудер.

const TOTAL_ROUNDS: int = 5
const ITEM_SCALE: Vector2 = Vector2(0.4, 0.4)
const GRID_GAP: float = 40.0
const TAP_RADIUS: float = 110.0
const DEAL_STAGGER: float = 0.1
const DEAL_DURATION: float = 0.4
const TOP_BAR_HEIGHT: float = 64.0
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0

var _is_toddler: bool = false
var _round: int = 0
var _items: Array[Node2D] = []
var _odd_item: Node2D = null
var _used_indices: Array[int] = []
var _start_time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _idle_timer: SceneTreeTimer = null
var _narrative_label: Label = null


func _ready() -> void:
	game_id = "odd_one_out"
	bg_theme = "meadow"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_rng.randomize()
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_narrative_label(tr("WHO_IS_HIDING"))
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


## Наратив — "Хто тут заховався?" лейбл зверху
func _build_narrative_label(text: String) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_narrative_label = Label.new()
	_narrative_label.text = text
	_narrative_label.add_theme_font_size_override("font_size", 28)
	_narrative_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_narrative_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narrative_label.position = Vector2(0, TOP_BAR_HEIGHT + 4.0)
	_narrative_label.size = Vector2(vp.x, 40)
	_ui_layer.add_child(_narrative_label)


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
	for item: Node2D in _items:
		if pos.distance_to(item.global_position) < TAP_RADIUS:
			_handle_tap(item)
			return


func _handle_tap(item: Node2D) -> void:
	_input_locked = true
	if item == _odd_item:
		_handle_correct(item)
	else:
		_handle_wrong(item)


func _handle_correct(item: Node2D) -> void:
	_register_correct(item)
	## VFX golden burst при знаходженні зайвого (LAW 28)
	VFXManager.spawn_golden_burst(item.global_position)
	if SettingsManager.reduced_motion:
		var tw_rm: Tween = create_tween()
		tw_rm.tween_interval(0.15)
		tw_rm.tween_callback(_advance_round)
		return
	## Silly dance — rotation wiggle + bounce combo
	var tw: Tween = create_tween()
	tw.tween_property(item, "rotation_degrees", 15.0, 0.08)
	tw.tween_property(item, "rotation_degrees", -15.0, 0.08)
	tw.tween_property(item, "rotation_degrees", 10.0, 0.06)
	tw.tween_property(item, "rotation_degrees", -10.0, 0.06)
	tw.tween_property(item, "rotation_degrees", 0.0, 0.06)
	tw.parallel().tween_property(item, "scale", ITEM_SCALE * 1.3, 0.1)
	tw.tween_property(item, "scale", ITEM_SCALE * 0.85, 0.08)
	tw.tween_property(item, "scale", ITEM_SCALE, 0.12)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_callback(_advance_round)


func _handle_wrong(item: Node2D) -> void:
	if _is_toddler:
		_register_error(item)  ## A11: scaffolding для тоддлера
		## Gentle head shake — "Ні, я тут живу!"
		if not SettingsManager.reduced_motion and is_instance_valid(item):
			var orig_x: float = item.position.x
			var sh: Tween = create_tween()
			sh.tween_property(item, "position:x", orig_x - 8.0, 0.06)
			sh.tween_property(item, "position:x", orig_x + 8.0, 0.06)
			sh.tween_property(item, "position:x", orig_x - 4.0, 0.04)
			sh.tween_property(item, "position:x", orig_x, 0.04)
		var d: float = 0.15 if SettingsManager.reduced_motion else 0.25
		var tw: Tween = create_tween()
		tw.tween_interval(d)
		tw.tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer()
		)
	else:
		_errors += 1
		_register_error(item)
		## Gentle head shake — "Ні, я тут живу!"
		if not SettingsManager.reduced_motion and is_instance_valid(item):
			var orig_x2: float = item.position.x
			var sh2: Tween = create_tween()
			sh2.tween_property(item, "position:x", orig_x2 - 8.0, 0.06)
			sh2.tween_property(item, "position:x", orig_x2 + 8.0, 0.06)
			sh2.tween_property(item, "position:x", orig_x2 - 4.0, 0.04)
			sh2.tween_property(item, "position:x", orig_x2, 0.04)
		var d: float = 0.15 if SettingsManager.reduced_motion else 0.25
		var tw: Tween = create_tween()
		tw.tween_interval(d)
		tw.tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer()
		)


func _advance_round() -> void:
	_clear_round()
	_round += 1
	if _round >= TOTAL_ROUNDS:
		_finish()
	else:
		_start_round()


func _start_round() -> void:
	if _is_toddler:
		_generate_toddler_round()
	else:
		_generate_preschool_round()
	_deal_items()


func _generate_toddler_round() -> void:
	var indices: Array[int] = _pick_indices(2)
	var majority_scene: PackedScene = GameData.ANIMALS_AND_FOOD[indices[0]].animal_scene
	var odd_scene: PackedScene = GameData.ANIMALS_AND_FOOD[indices[1]].animal_scene
	var majority_count: int = _scale_by_round_i(3, 5, _round, TOTAL_ROUNDS)
	for i: int in range(majority_count):
		_items.append(_create_item(majority_scene))
	_odd_item = _create_item(odd_scene)
	_items.append(_odd_item)
	_items.shuffle()


func _generate_preschool_round() -> void:
	var majority_count: int = _scale_by_round_i(3, 5, _round, TOTAL_ROUNDS)
	var indices: Array[int] = _pick_indices(majority_count + 1)
	## A8: guard — якщо індексів менше ніж потрібно, зменшуємо majority_count
	if indices.size() < 2:
		push_warning("OddOneOut: недостатньо індексів, fallback")
		indices = _pick_indices(4)
	majority_count = mini(majority_count, indices.size() - 1)
	var use_animals: bool = _rng.randi() % 2 == 0
	for i: int in range(majority_count):
		var data: Dictionary = GameData.ANIMALS_AND_FOOD[indices[i]]
		var scene: PackedScene = data.animal_scene if use_animals else data.food_scene
		_items.append(_create_item(scene))
	var odd_data: Dictionary = GameData.ANIMALS_AND_FOOD[indices[majority_count]]
	var odd_scene: PackedScene = odd_data.food_scene if use_animals else odd_data.animal_scene
	_odd_item = _create_item(odd_scene)
	_items.append(_odd_item)
	_items.shuffle()


func _create_item(scene: PackedScene) -> Node2D:
	var item: Node2D = scene.instantiate()
	item.scale = ITEM_SCALE
	add_child(item)
	item.material = GameData.create_premium_material(
		0.05, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.12, 0.28, 0.22)
	return item


func _deal_items() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var item_size: float = 512.0 * ITEM_SCALE.x
	var cx: float = vp.x * 0.5
	var cy: float = (vp.y + TOP_BAR_HEIGHT) * 0.5
	var total: int = _items.size()
	## Динамічна сітка: 2 стовпці для 4, 3 для 5-6
	var cols: int = 2 if total <= 4 else 3
	@warning_ignore("integer_division")
	var rows: int = (total + cols - 1) / cols
	var cell: float = item_size + GRID_GAP
	var grid_w: float = float(cols) * cell
	var grid_h: float = float(rows) * cell
	var positions: Array[Vector2] = []
	for idx: int in range(total):
		var c: int = idx % cols
		@warning_ignore("integer_division")
		var r: int = idx / cols
		positions.append(Vector2(
			cx - grid_w * 0.5 + cell * (float(c) + 0.5),
			cy - grid_h * 0.5 + cell * (float(r) + 0.5)))
	for i: int in range(_items.size()):
		var item: Node2D = _items[i]
		var target: Vector2 = positions[i]
		if SettingsManager.reduced_motion:
			item.position = target
			item.scale = ITEM_SCALE
			item.modulate.a = 1.0
			if i == _items.size() - 1:
				_input_locked = false
				_reset_idle_timer()
		else:
			item.position = Vector2(target.x, -200.0)
			item.scale = Vector2(0.2, 0.2)
			item.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = create_tween().set_parallel(true)
			tw.tween_property(item, "position", target, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "scale", ITEM_SCALE, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
			if i == _items.size() - 1:
				tw.chain().tween_callback(func() -> void:
					_input_locked = false
					_reset_idle_timer()
				)


func _clear_round() -> void:
	for item: Node2D in _items:
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()
	_odd_item = null


func _finish() -> void:
	_game_over = true
	_input_locked = true
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": TOTAL_ROUNDS, "earned_stars": earned})


func _pick_indices(count: int) -> Array[int]:
	var available: Array[int] = []
	for i: int in range(GameData.ANIMALS_AND_FOOD.size()):
		if not _used_indices.has(i):
			available.append(i)
	if available.size() < count:
		_used_indices.clear()
		available.clear()
		for i: int in range(GameData.ANIMALS_AND_FOOD.size()):
			available.append(i)
	available.shuffle()
	var picked: Array[int] = []
	for i: int in range(mini(count, available.size())):
		picked.append(available[i])
		_used_indices.append(available[i])
	return picked


func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over or not is_instance_valid(_odd_item):
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	_pulse_node(_odd_item, 1.2)
	_reset_idle_timer()


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("ODD_TUTORIAL_TODDLER")
	return tr("ODD_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if not is_instance_valid(_odd_item):
		return {}
	return {"type": "tap", "target": _odd_item.global_position}
