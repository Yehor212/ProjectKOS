extends BaseMiniGame

## Shape Sorter — геометричний сортер! Toddler: 3 фігури в отвори.
## Preschool: зібрати ракету з деталей (Танграм).

const SHAPE_SCENE: PackedScene = preload("res://scenes/components/shape_item.tscn")
const SLOT_SCENE: PackedScene = preload("res://scenes/components/slot_item.tscn")
const SNAP_DISTANCE: float = 60.0
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0
## Toddler: 3 базові фігури
const TODDLER_ROUNDS: int = 3
const TODDLER_SHAPES_POOL: Array[Dictionary] = [
	{"id": "circle", "type": 0, "color": Color("ef4444"), "size": 50.0},
	{"id": "square", "type": 1, "color": Color("3b82f6"), "size": 45.0},
	{"id": "triangle", "type": 2, "color": Color("22c55e"), "size": 50.0},
	{"id": "diamond", "type": 1, "color": Color("a855f7"), "size": 45.0},
]
## Preschool: 3 конструктори (рандомний вибір для replay value)
const ROCKET_PARTS: Array[Dictionary] = [
	{"id": "body", "type": 3, "color": Color("3b82f6"), "size": 60.0,
		"slot_offset": Vector2(0, 0)},
	{"id": "nose", "type": 2, "color": Color("ef4444"), "size": 40.0,
		"slot_offset": Vector2(0, -100)},
	{"id": "wing_l", "type": 2, "color": Color("fb923c"), "size": 30.0,
		"slot_offset": Vector2(-55, 70), "slot_rotation": 0.785},
	{"id": "wing_r", "type": 2, "color": Color("fb923c"), "size": 30.0,
		"slot_offset": Vector2(55, 70), "slot_rotation": -0.785},
]
const BOAT_PARTS: Array[Dictionary] = [
	{"id": "hull", "type": 3, "color": Color("8b5e3c"), "size": 70.0,
		"slot_offset": Vector2(0, 30)},
	{"id": "cabin", "type": 1, "color": Color("ef4444"), "size": 40.0,
		"slot_offset": Vector2(0, -30)},
	{"id": "mast", "type": 3, "color": Color("ffd166"), "size": 25.0,
		"slot_offset": Vector2(0, -80)},
	{"id": "flag", "type": 2, "color": Color("22c55e"), "size": 25.0,
		"slot_offset": Vector2(20, -100)},
]
const HOUSE_PARTS: Array[Dictionary] = [
	{"id": "walls", "type": 1, "color": Color("fb923c"), "size": 65.0,
		"slot_offset": Vector2(0, 20)},
	{"id": "roof", "type": 2, "color": Color("ef4444"), "size": 55.0,
		"slot_offset": Vector2(0, -55)},
	{"id": "door", "type": 1, "color": Color("8b5e3c"), "size": 30.0,
		"slot_offset": Vector2(0, 50)},
	{"id": "window", "type": 0, "color": Color("3b82f6"), "size": 25.0,
		"slot_offset": Vector2(-25, 0)},
]
const PRESCHOOL_CONSTRUCTORS: Array[Array] = [ROCKET_PARTS, BOAT_PARTS, HOUSE_PARTS]

var _is_toddler: bool = false
var _drag: UniversalDrag = null
var _shapes: Array[Node2D] = []
var _slots: Array[Node2D] = []
var _origins: Dictionary = {}
var _matched: int = 0
var _total: int = 0
var _start_time: float = 0.0
var _idle_timer: SceneTreeTimer = null
var _round: int = 0
var _all_round_nodes: Array[Node] = []


func _ready() -> void:
	game_id = "shape_sorter"
	bg_theme = "candy"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_drag = UniversalDrag.new(self)
	_drag.item_dropped_on_target.connect(_on_dropped_on_target)
	_drag.item_dropped_on_empty.connect(_on_dropped_on_empty)
	if _is_toddler:
		_setup_toddler()
	else:
		_setup_preschool()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func _setup_toddler() -> void:
	_drag.snap_radius_override = TODDLER_SNAP_RADIUS
	_drag.magnetic_assist = true
	_start_toddler_round()


func _start_toddler_round() -> void:
	_clear_round()
	_matched = 0
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Прогресивна складність: 2→3→4 фігури
	var shape_count: int = _scale_by_round_i(2, TODDLER_SHAPES_POOL.size(), _round, TODDLER_ROUNDS)
	var round_shapes: Array[Dictionary] = []
	var pool: Array[Dictionary] = TODDLER_SHAPES_POOL.duplicate()
	pool.shuffle()
	for i: int in mini(shape_count, pool.size()):
		round_shapes.append(pool[i])
	_total = round_shapes.size()
	var spacing: float = vp.x / (_total + 1)
	## Слоти зверху
	var slot_y: float = vp.y * 0.3
	for i: int in range(_total):
		var data: Dictionary = round_shapes[i]
		var sz: float = _toddler_scale(data.size)
		var slot: Node2D = SLOT_SCENE.instantiate()
		add_child(slot)
		slot.position = Vector2(spacing * (i + 1), slot_y)
		## Piaget: color+shape redundancy — слот тонується кольором фігури
		slot.setup(data.id, data.type, sz + 5.0, data.color)
		_slots.append(slot)
		_drag.drop_targets.append(slot)
		_all_round_nodes.append(slot)
	## Фігури знизу (shuffled)
	var indices: Array[int] = []
	for i: int in range(_total):
		indices.append(i)
	indices.shuffle()
	var shape_y: float = vp.y * 0.75
	for i: int in range(_total):
		var data: Dictionary = round_shapes[indices[i]]
		var sz: float = _toddler_scale(data.size)
		var scaled_data: Dictionary = data.duplicate()
		scaled_data.size = sz
		_spawn_shape(scaled_data, Vector2(spacing * (i + 1), shape_y))
	## Магнітний асист
	var pairs: Dictionary = {}
	for shape: Node2D in _shapes:
		for slot: Node2D in _slots:
			if slot.expected_id == shape.shape_id:
				pairs[shape] = slot
				break
	_drag.set_correct_pairs(pairs)
	_staggered_spawn(_slots + _shapes)
	_reset_idle_timer()


func _setup_preschool() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = Vector2(vp.x * 0.5, vp.y * 0.4)
	## Рандомний вибір конструктора (ракета/кораблик/будиночок)
	var parts: Array[Dictionary] = PRESCHOOL_CONSTRUCTORS.pick_random().duplicate()
	_total = parts.size()
	## Слоти (чертеж конструктора)
	for data: Dictionary in parts:
		var slot: Node2D = SLOT_SCENE.instantiate()
		add_child(slot)
		slot.position = center + data.slot_offset
		if data.has("slot_rotation"):
			slot.rotation = data.slot_rotation
		slot.setup(data.id, data.type, data.size + 5.0)
		_slots.append(slot)
		_drag.drop_targets.append(slot)
	## Фігури знизу (shuffled)
	var shuffled: Array[Dictionary] = parts.duplicate()
	shuffled.shuffle()
	var shape_y: float = vp.y * 0.82
	var spacing: float = vp.x / (_total + 1)
	for i: int in range(_total):
		_spawn_shape(shuffled[i], Vector2(spacing * (i + 1), shape_y))
	_staggered_spawn(_slots + _shapes)
	_reset_idle_timer()


func _spawn_shape(data: Dictionary, pos: Vector2) -> void:
	var shape: Node2D = SHAPE_SCENE.instantiate()
	add_child(shape)
	shape.position = pos
	shape.setup(data.id, data.type, data.color, data.size)
	shape.origin_pos = pos
	_shapes.append(shape)
	_origins[shape] = pos
	_drag.draggable_items.append(shape)
	_all_round_nodes.append(shape)


func _clear_round() -> void:
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			_drag.draggable_items.erase(node)
			_drag.drop_targets.erase(node)
			node.queue_free()
	_all_round_nodes.clear()
	_shapes.clear()
	_slots.clear()
	_origins.clear()


## ---- Input ----

func _input(event: InputEvent) -> void:
	if _game_over or _input_locked:
		return
	_drag.handle_input(event)


func _process(delta: float) -> void:
	_drag.handle_process(delta)
	_update_slot_highlights()


func _update_slot_highlights() -> void:
	for slot: Node2D in _slots:
		if slot.is_filled:
			continue
		var near: bool = false
		for shape: Node2D in _drag.draggable_items:
			if not is_instance_valid(shape):
				continue
			if shape.global_position.distance_to(slot.global_position) < SNAP_DISTANCE:
				near = true
				break
		slot.set_highlighted(near)


## ---- Drop handling ----

func _on_dropped_on_target(item: Node2D, target: Node2D) -> void:
	if _game_over:
		return
	if item.shape_id == target.expected_id and not target.is_filled:
		## Правильне місце!
		_register_correct(item)
		target.is_filled = true
		target.queue_redraw()
		_drag.draggable_items.erase(item)
		item.global_position = target.global_position
		item.rotation = target.rotation
		_matched += 1
		if _matched >= _total:
			_win()
	else:
		## Не підходить
		if _is_toddler:
			_register_error(item)  ## A11: scaffolding для тоддлера
		else:
			_errors += 1
			_register_error(item)
		_drag.snap_back(item, _origins.get(item, item.position))
	_reset_idle_timer()


func _on_dropped_on_empty(item: Node2D) -> void:
	_drag.snap_back(item, _origins.get(item, item.position))
	_reset_idle_timer()


## ---- Win ----

func _win() -> void:
	_game_over = true
	if _is_toddler:
		_toddler_win()
	else:
		_rocket_blast_off()


func _toddler_win() -> void:
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size / 2.0)
	AudioManager.play_sfx("success", 1.2)
	HapticsManager.vibrate_success()
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self) or _game_finished:
		return
	_round += 1
	if _round >= TODDLER_ROUNDS:
		_finish()
	else:
		_game_over = false
		_input_locked = false
		_start_toddler_round()


func _rocket_blast_off() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Групуємо деталі ракети
	var rocket: Node2D = Node2D.new()
	rocket.position = Vector2(vp.x * 0.5, vp.y * 0.4)
	add_child(rocket)
	_all_round_nodes.append(rocket)
	for shape: Node2D in _shapes:
		var gpos: Vector2 = shape.global_position
		shape.reparent(rocket)
		shape.global_position = gpos
	VFXManager.spawn_premium_celebration(vp / 2.0)
	AudioManager.play_sfx("success", 0.8)
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self) or _game_finished:
		return
	## Ракета злітає!
	if SettingsManager.reduced_motion:
		rocket.position.y = -300.0
		rocket.scale = Vector2(0.5, 1.5)
		_finish()
		return
	var tw: Tween = create_tween()
	tw.tween_property(rocket, "position:y", -300.0, 1.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(rocket, "scale", Vector2(0.5, 1.5), 1.2)
	tw.finished.connect(_finish)


## ---- Finish ----

func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	var rounds: int = TODDLER_ROUNDS if _is_toddler else 1
	var stats: Dictionary = {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": rounds,
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
	if _game_over or _input_locked:
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		## A10 Lvl2: tutorial hand — показати правильну пару фігура→слот
		var demo: Dictionary = get_tutorial_demo()
		if demo.has("from") and demo.has("to"):
			var from_pos: Vector2 = demo.get("from", Vector2.ZERO)
			var to_pos: Vector2 = demo.get("to", Vector2.ZERO)
			## Знайти фігуру та слот і пульсувати обидва
			for shape: Node2D in _shapes:
				if is_instance_valid(shape) and shape.global_position.distance_to(from_pos) < 10.0:
					_pulse_node(shape, 1.3)
					break
			for slot: Node2D in _slots:
				if is_instance_valid(slot) and slot.global_position.distance_to(to_pos) < 10.0:
					_pulse_node(slot, 1.3)
					## Яскравий flash на правильному слоті
					if not SettingsManager.reduced_motion:
						var flash_tw: Tween = create_tween()
						flash_tw.tween_property(slot, "modulate", Color(1.5, 1.3, 0.7, 1.0), 0.15)
						flash_tw.tween_property(slot, "modulate", Color.WHITE, 0.3)
					break
		_reset_idle_timer()
		return
	## Пульсація першої доступної фігури
	for shape: Node2D in _shapes:
		if is_instance_valid(shape) and shape in _drag.draggable_items:
			_pulse_node(shape, 1.15)
			break
	_reset_idle_timer()


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("SHAPES_TUTORIAL_TODDLER")
	return tr("SHAPES_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _shapes.is_empty() or _slots.is_empty():
		return {}
	## Знайти першу незайняту фігуру та відповідний слот
	for shape: Node2D in _shapes:
		if not is_instance_valid(shape) or not (shape in _drag.draggable_items):
			continue
		for slot: Node2D in _slots:
			if is_instance_valid(slot) and not slot.is_filled and slot.expected_id == shape.shape_id:
				return {"type": "drag", "from": shape.global_position, "to": slot.global_position}
	return {}
