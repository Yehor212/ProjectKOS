extends BaseMiniGame

## Майстерня Тофі / Tofie's Workshop — збери істоту/конструктор з фігур.
## Toddler: фігури створюють ІСТОТУ (body parts) -> оживає + silly action.
## Preschool: 8 конструкторів (ракета, лодка, дім, машина, літак, замок, робот, квітка).
## Кожен конструктор -> унікальна 3с celebration анімація.

const SHAPE_SCENE: PackedScene = preload("res://scenes/components/shape_item.tscn")
const SLOT_SCENE: PackedScene = preload("res://scenes/components/slot_item.tscn")
const SNAP_DISTANCE: float = 60.0
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0
const TODDLER_ROUNDS: int = 3
const PRESCHOOL_ROUNDS: int = 3

## --- Toddler: 6 істот, кожна зібрана з геометричних фігур ---
## type: 0=circle, 1=square, 2=triangle, 3=rectangle
## alive_action: яку silly-анімацію грати після збирання
const CREATURE_BUNNY: Dictionary = {
	"name": "bunny", "alive_action": "hop",
	"parts": [
		{"id": "head", "type": 0, "color": Color("f9a8d4"), "size": 45.0,
			"slot_offset": Vector2(0, -60)},
		{"id": "body", "type": 1, "color": Color("f472b6"), "size": 40.0,
			"slot_offset": Vector2(0, 20)},
		{"id": "ear_l", "type": 2, "color": Color("fbb6ce"), "size": 25.0,
			"slot_offset": Vector2(-25, -110)},
	],
}
const CREATURE_CAT: Dictionary = {
	"name": "cat", "alive_action": "purr",
	"parts": [
		{"id": "head", "type": 0, "color": Color("fbbf24"), "size": 42.0,
			"slot_offset": Vector2(0, -55)},
		{"id": "body", "type": 3, "color": Color("f59e0b"), "size": 40.0,
			"slot_offset": Vector2(0, 25)},
		{"id": "tail", "type": 2, "color": Color("d97706"), "size": 22.0,
			"slot_offset": Vector2(55, 30)},
	],
}
const CREATURE_BIRD: Dictionary = {
	"name": "bird", "alive_action": "flap",
	"parts": [
		{"id": "body", "type": 0, "color": Color("60a5fa"), "size": 38.0,
			"slot_offset": Vector2(0, 0)},
		{"id": "wing", "type": 2, "color": Color("93c5fd"), "size": 28.0,
			"slot_offset": Vector2(-50, -5), "slot_rotation": -0.4},
		{"id": "beak", "type": 2, "color": Color("fb923c"), "size": 15.0,
			"slot_offset": Vector2(40, 0), "slot_rotation": 1.57},
	],
}
const CREATURE_FROG: Dictionary = {
	"name": "frog", "alive_action": "jump",
	"parts": [
		{"id": "head", "type": 0, "color": Color("4ade80"), "size": 40.0,
			"slot_offset": Vector2(0, -45)},
		{"id": "body", "type": 1, "color": Color("22c55e"), "size": 42.0,
			"slot_offset": Vector2(0, 20)},
		{"id": "leg_l", "type": 2, "color": Color("16a34a"), "size": 22.0,
			"slot_offset": Vector2(-40, 60)},
		{"id": "leg_r", "type": 2, "color": Color("16a34a"), "size": 22.0,
			"slot_offset": Vector2(40, 60)},
	],
}
const CREATURE_FISH: Dictionary = {
	"name": "fish", "alive_action": "swim",
	"parts": [
		{"id": "body", "type": 0, "color": Color("c084fc"), "size": 42.0,
			"slot_offset": Vector2(0, 0)},
		{"id": "tail", "type": 2, "color": Color("a855f7"), "size": 28.0,
			"slot_offset": Vector2(-55, 0), "slot_rotation": 1.57},
		{"id": "fin_top", "type": 2, "color": Color("d8b4fe"), "size": 18.0,
			"slot_offset": Vector2(0, -45)},
		{"id": "fin_bottom", "type": 2, "color": Color("d8b4fe"), "size": 18.0,
			"slot_offset": Vector2(0, 45), "slot_rotation": 3.14},
	],
}
const CREATURE_ROBO: Dictionary = {
	"name": "robo", "alive_action": "dance",
	"parts": [
		{"id": "head", "type": 1, "color": Color("94a3b8"), "size": 32.0,
			"slot_offset": Vector2(0, -65)},
		{"id": "body", "type": 3, "color": Color("64748b"), "size": 42.0,
			"slot_offset": Vector2(0, 5)},
		{"id": "arm_l", "type": 1, "color": Color("cbd5e1"), "size": 18.0,
			"slot_offset": Vector2(-55, 0)},
		{"id": "arm_r", "type": 1, "color": Color("cbd5e1"), "size": 18.0,
			"slot_offset": Vector2(55, 0)},
		{"id": "hat", "type": 2, "color": Color("ef4444"), "size": 22.0,
			"slot_offset": Vector2(0, -100)},
	],
}

## Пул від простих (3 parts) до складних (5 parts) — для прогресивної складності
const CREATURES_3_PARTS: Array[Dictionary] = [CREATURE_BUNNY, CREATURE_CAT, CREATURE_BIRD]
const CREATURES_4_PARTS: Array[Dictionary] = [CREATURE_FROG, CREATURE_FISH]
const CREATURES_5_PARTS: Array[Dictionary] = [CREATURE_ROBO]

## --- Preschool: 8 конструкторів ---
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
const CAR_PARTS: Array[Dictionary] = [
	{"id": "chassis", "type": 3, "color": Color("ef4444"), "size": 60.0,
		"slot_offset": Vector2(0, 0)},
	{"id": "roof", "type": 1, "color": Color("dc2626"), "size": 35.0,
		"slot_offset": Vector2(0, -55)},
	{"id": "wheel_l", "type": 0, "color": Color("1e293b"), "size": 22.0,
		"slot_offset": Vector2(-45, 50)},
	{"id": "wheel_r", "type": 0, "color": Color("1e293b"), "size": 22.0,
		"slot_offset": Vector2(45, 50)},
	{"id": "window", "type": 1, "color": Color("93c5fd"), "size": 20.0,
		"slot_offset": Vector2(0, -50)},
]
const AIRPLANE_PARTS: Array[Dictionary] = [
	{"id": "fuselage", "type": 3, "color": Color("f8fafc"), "size": 55.0,
		"slot_offset": Vector2(0, 0)},
	{"id": "wing_l", "type": 2, "color": Color("60a5fa"), "size": 35.0,
		"slot_offset": Vector2(-65, 10), "slot_rotation": 0.5},
	{"id": "wing_r", "type": 2, "color": Color("60a5fa"), "size": 35.0,
		"slot_offset": Vector2(65, 10), "slot_rotation": -0.5},
	{"id": "tail", "type": 2, "color": Color("f97316"), "size": 25.0,
		"slot_offset": Vector2(0, 60)},
	{"id": "nose", "type": 0, "color": Color("ef4444"), "size": 18.0,
		"slot_offset": Vector2(0, -60)},
]
const CASTLE_PARTS: Array[Dictionary] = [
	{"id": "base", "type": 1, "color": Color("d6d3d1"), "size": 65.0,
		"slot_offset": Vector2(0, 25)},
	{"id": "tower_l", "type": 3, "color": Color("a8a29e"), "size": 30.0,
		"slot_offset": Vector2(-55, -30)},
	{"id": "tower_r", "type": 3, "color": Color("a8a29e"), "size": 30.0,
		"slot_offset": Vector2(55, -30)},
	{"id": "roof_l", "type": 2, "color": Color("7c3aed"), "size": 22.0,
		"slot_offset": Vector2(-55, -75)},
	{"id": "roof_r", "type": 2, "color": Color("7c3aed"), "size": 22.0,
		"slot_offset": Vector2(55, -75)},
	{"id": "gate", "type": 0, "color": Color("78350f"), "size": 25.0,
		"slot_offset": Vector2(0, 55)},
]
const ROBOT_PARTS: Array[Dictionary] = [
	{"id": "cpu", "type": 1, "color": Color("94a3b8"), "size": 35.0,
		"slot_offset": Vector2(0, -60)},
	{"id": "torso", "type": 3, "color": Color("475569"), "size": 50.0,
		"slot_offset": Vector2(0, 10)},
	{"id": "arm_l", "type": 3, "color": Color("64748b"), "size": 20.0,
		"slot_offset": Vector2(-60, 5)},
	{"id": "arm_r", "type": 3, "color": Color("64748b"), "size": 20.0,
		"slot_offset": Vector2(60, 5)},
	{"id": "antenna", "type": 2, "color": Color("ef4444"), "size": 15.0,
		"slot_offset": Vector2(0, -95)},
]
const FLOWER_PARTS: Array[Dictionary] = [
	{"id": "center", "type": 0, "color": Color("fbbf24"), "size": 30.0,
		"slot_offset": Vector2(0, -40)},
	{"id": "petal_l", "type": 0, "color": Color("f472b6"), "size": 22.0,
		"slot_offset": Vector2(-35, -55)},
	{"id": "petal_r", "type": 0, "color": Color("f472b6"), "size": 22.0,
		"slot_offset": Vector2(35, -55)},
	{"id": "petal_t", "type": 0, "color": Color("fb7185"), "size": 22.0,
		"slot_offset": Vector2(0, -75)},
	{"id": "stem", "type": 3, "color": Color("22c55e"), "size": 35.0,
		"slot_offset": Vector2(0, 25)},
	{"id": "leaf", "type": 2, "color": Color("4ade80"), "size": 18.0,
		"slot_offset": Vector2(25, 15), "slot_rotation": -0.5},
]

## Preschool пул: 4-part, 5-part, 6-part конструктори (для прогресивної складності)
const CONSTRUCTORS_4: Array[Array] = [ROCKET_PARTS, BOAT_PARTS, HOUSE_PARTS, CAR_PARTS]
const CONSTRUCTORS_5: Array[Array] = [AIRPLANE_PARTS, ROBOT_PARTS]
const CONSTRUCTORS_6: Array[Array] = [CASTLE_PARTS, FLOWER_PARTS]

## Celebration IDs — маппінг першого part.id конструктора до типу анімації
const CONSTRUCTOR_CELEBRATION: Dictionary = {
	"body": "rocket", "hull": "boat", "walls": "house", "chassis": "car",
	"fuselage": "airplane", "base": "castle", "cpu": "robot", "center": "flower",
}

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
var _used_creature_names: Array[String] = []
var _used_constructor_ids: Array[String] = []
var _current_creature_action: String = ""
var _current_constructor_id: String = ""


func _ready() -> void:
	game_id = "shape_sorter"
	bg_theme = "candy"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_drag = UniversalDrag.new(self)
	_drag.item_dropped_on_target.connect(_on_dropped_on_target)
	_drag.item_dropped_on_empty.connect(_on_dropped_on_empty)
	if _is_toddler:
		_setup_toddler()
	else:
		_setup_preschool()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Toddler ----

func _setup_toddler() -> void:
	_drag.snap_radius_override = TODDLER_SNAP_RADIUS
	_drag.magnetic_assist = true
	_start_toddler_round()


func _start_toddler_round() -> void:
	_clear_round()
	_matched = 0
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## A4: прогресивна складність — 3->4->5 деталей істоти
	var target_count: int = _scale_by_round_i(3, 5, _round, TODDLER_ROUNDS)
	var creature: Dictionary = _pick_creature_for_round(target_count)
	var parts: Array = creature.get("parts", [])
	if parts.size() == 0:
		push_warning("ShapeSorter: creature has no parts, skipping round")
		_round += 1
		if _round >= TODDLER_ROUNDS:
			_finish()
		else:
			_start_toddler_round()
		return
	_current_creature_action = creature.get("alive_action", "hop")
	_total = parts.size()
	var center: Vector2 = Vector2(vp.x * 0.5, vp.y * 0.35)
	## Слоти (креслення істоти)
	for i: int in range(_total):
		if i >= parts.size():
			break
		var data: Dictionary = parts[i]
		var sz: float = _toddler_scale(data.get("size", 40.0))
		var slot: Node2D = SLOT_SCENE.instantiate()
		add_child(slot)
		slot.position = center + data.get("slot_offset", Vector2.ZERO)
		if data.has("slot_rotation"):
			slot.rotation = data.get("slot_rotation", 0.0)
		## Piaget: color+shape redundancy для toddler
		slot.setup(data.get("id", ""), data.get("type", 0), sz + 5.0, data.get("color", Color.RED))
		_slots.append(slot)
		_drag.drop_targets.append(slot)
		_all_round_nodes.append(slot)
	## Фігури знизу (shuffled)
	var shuffled_parts: Array = parts.duplicate()
	shuffled_parts.shuffle()
	var shape_y: float = vp.y * 0.78
	var spacing: float = vp.x / (maxi(_total, 1) + 1)
	for i: int in range(mini(shuffled_parts.size(), _total)):
		var data: Dictionary = shuffled_parts[i]
		var sz: float = _toddler_scale(data.get("size", 40.0))
		var scaled_data: Dictionary = data.duplicate()
		scaled_data["size"] = sz
		_spawn_shape(scaled_data, Vector2(spacing * (i + 1), shape_y))
	## LAW 15: count after create
	_total = mini(_shapes.size(), _slots.size())
	if _total <= 0:
		push_warning("ShapeSorter: no shapes/slots created, finishing")
		_finish()
		return
	## Магнітний асист
	var pairs: Dictionary = {}
	for shape: Node2D in _shapes:
		for slot: Node2D in _slots:
			if is_instance_valid(slot) and is_instance_valid(shape):
				if slot.expected_id == shape.shape_id:
					pairs[shape] = slot
					break
	_drag.set_correct_pairs(pairs)
	_staggered_spawn(_slots + _shapes)
	_reset_idle_timer()
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TODDLER_ROUNDS])


## Вибір істоти за цільовою кількістю деталей (3/4/5), без повторів
func _pick_creature_for_round(target_count: int) -> Dictionary:
	var pool: Array[Dictionary] = []
	if target_count <= 3:
		pool = CREATURES_3_PARTS.duplicate()
	elif target_count == 4:
		pool = CREATURES_4_PARTS.duplicate()
	else:
		pool = CREATURES_5_PARTS.duplicate()
	## Фільтруємо використані
	var available: Array[Dictionary] = []
	for c: Dictionary in pool:
		if not _used_creature_names.has(c.get("name", "")):
			available.append(c)
	## A8: fallback — якщо всі використані, скидаємо та беремо з повного пулу
	if available.size() == 0:
		available = pool.duplicate()
	if available.size() == 0:
		push_warning("ShapeSorter: no creatures available, using fallback bunny")
		return CREATURE_BUNNY
	available.shuffle()
	var chosen: Dictionary = available[0]
	_used_creature_names.append(chosen.get("name", ""))
	return chosen


## ---- Preschool ----

func _setup_preschool() -> void:
	_start_preschool_round()


func _start_preschool_round() -> void:
	_clear_round()
	_matched = 0
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = Vector2(vp.x * 0.5, vp.y * 0.38)
	## A4: прогресивна складність — 4->5->6 деталей
	var target_count: int = _scale_by_round_i(4, 6, _round, PRESCHOOL_ROUNDS)
	var parts: Array[Dictionary] = _pick_constructor_for_round(target_count)
	if parts.size() == 0:
		push_warning("ShapeSorter: constructor has no parts, skipping round")
		_round += 1
		if _round >= PRESCHOOL_ROUNDS:
			_finish()
		else:
			_start_preschool_round()
		return
	_total = parts.size()
	## Визначити тип конструктора за першою деталлю
	if parts.size() > 0:
		var first_id: String = parts[0].get("id", "")
		_current_constructor_id = CONSTRUCTOR_CELEBRATION.get(first_id, "rocket")
	## Слоти (креслення конструктора)
	for data: Dictionary in parts:
		var slot: Node2D = SLOT_SCENE.instantiate()
		add_child(slot)
		slot.position = center + data.get("slot_offset", Vector2.ZERO)
		if data.has("slot_rotation"):
			slot.rotation = data.get("slot_rotation", 0.0)
		slot.setup(data.get("id", ""), data.get("type", 0), data.get("size", 40.0) + 5.0)
		_slots.append(slot)
		_drag.drop_targets.append(slot)
		_all_round_nodes.append(slot)
	## Фігури знизу (shuffled)
	var shuffled: Array[Dictionary] = parts.duplicate()
	shuffled.shuffle()
	var shape_y: float = vp.y * 0.82
	var spacing: float = vp.x / (maxi(_total, 1) + 1)
	for i: int in range(shuffled.size()):
		_spawn_shape(shuffled[i], Vector2(spacing * (i + 1), shape_y))
	## LAW 15: count after create
	_total = mini(_shapes.size(), _slots.size())
	if _total <= 0:
		push_warning("ShapeSorter: no shapes/slots created, finishing")
		_finish()
		return
	_staggered_spawn(_slots + _shapes)
	_reset_idle_timer()
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, PRESCHOOL_ROUNDS])


## Вибір конструктора за цільовою кількістю деталей, без повторів в сесії
func _pick_constructor_for_round(target_count: int) -> Array[Dictionary]:
	var pool: Array[Array] = []
	if target_count <= 4:
		pool = CONSTRUCTORS_4.duplicate()
	elif target_count == 5:
		pool = CONSTRUCTORS_5.duplicate()
	else:
		pool = CONSTRUCTORS_6.duplicate()
	## Фільтруємо використані
	var available: Array[Array] = []
	for c: Array in pool:
		if c.size() > 0:
			var first_part: Dictionary = c[0] as Dictionary
			var first_id: String = first_part.get("id", "")
			var cid: String = CONSTRUCTOR_CELEBRATION.get(first_id, first_id)
			if not _used_constructor_ids.has(cid):
				available.append(c)
	## A8: fallback
	if available.size() == 0:
		available = pool.duplicate()
	if available.size() == 0:
		push_warning("ShapeSorter: no constructors available, using fallback rocket")
		return ROCKET_PARTS.duplicate()
	available.shuffle()
	var chosen: Array = available[0]
	if chosen.size() > 0:
		var chosen_first: Dictionary = chosen[0] as Dictionary
		var first_id: String = chosen_first.get("id", "")
		_used_constructor_ids.append(CONSTRUCTOR_CELEBRATION.get(first_id, first_id))
	var result: Array[Dictionary] = []
	for item: Dictionary in chosen:
		result.append(item)
	return result


## ---- Shared: spawn / clear / input ----

func _spawn_shape(data: Dictionary, pos: Vector2) -> void:
	var shape: Node2D = SHAPE_SCENE.instantiate()
	add_child(shape)
	shape.position = pos
	shape.setup(
		data.get("id", ""),
		data.get("type", 0),
		data.get("color", Color.RED),
		data.get("size", 40.0))
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
			## LAW 9/11: erase from dict BEFORE queue_free
			if _origins.has(node):
				_origins.erase(node)
			node.queue_free()
	_all_round_nodes.clear()
	_shapes.clear()
	_slots.clear()
	_origins.clear()


func _input(event: InputEvent) -> void:
	if _game_over or _input_locked:
		return
	_drag.handle_input(event)


func _process(delta: float) -> void:
	_drag.handle_process(delta)
	_update_slot_highlights()


func _update_slot_highlights() -> void:
	for slot: Node2D in _slots:
		if not is_instance_valid(slot) or slot.is_filled:
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
	if not is_instance_valid(item) or not is_instance_valid(target):
		push_warning("ShapeSorter: item or target invalid in drop callback")
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
			_register_error(item)  ## A6/A11: scaffolding для тоддлера, без _errors
		else:
			_errors += 1  ## A7: preschool рахує помилки
			_register_error(item)
		_drag.snap_back(item, _origins.get(item, item.position))
	_reset_idle_timer()


func _on_dropped_on_empty(item: Node2D) -> void:
	if not is_instance_valid(item):
		push_warning("ShapeSorter: invalid item in empty-drop callback")
		return
	_drag.snap_back(item, _origins.get(item, item.position))
	_reset_idle_timer()


## ---- Win ----

func _win() -> void:
	_game_over = true
	_input_locked = true
	if _is_toddler:
		_toddler_creature_alive()
	else:
		_preschool_celebration()


## ---- Toddler: істота оживає! ----

func _toddler_creature_alive() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Групуємо деталі в одну ноду
	var creature: Node2D = Node2D.new()
	creature.position = Vector2(vp.x * 0.5, vp.y * 0.35)
	add_child(creature)
	_all_round_nodes.append(creature)
	for shape: Node2D in _shapes:
		if is_instance_valid(shape):
			var gpos: Vector2 = shape.global_position
			shape.reparent(creature)
			shape.global_position = gpos
	_play_round_celebration(creature.global_position)
	## Silly action анімація
	if not SettingsManager.reduced_motion:
		_animate_creature_alive(creature, _current_creature_action)
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self) or _game_finished:
		return
	_record_round_errors(_consecutive_errors)
	_round += 1
	if _round >= TODDLER_ROUNDS:
		_finish()
	else:
		_game_over = false
		_input_locked = false
		_start_toddler_round()


## Silly-анімація залежно від типу істоти
func _animate_creature_alive(creature: Node2D, action: String) -> void:
	if not is_instance_valid(creature):
		return
	var tw: Tween = _create_game_tween()
	match action:
		"hop":
			## Стрибки зайчика
			tw.tween_property(creature, "position:y", creature.position.y - 60.0, 0.25)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(creature, "position:y", creature.position.y, 0.2)\
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_property(creature, "position:y", creature.position.y - 40.0, 0.2)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(creature, "position:y", creature.position.y, 0.2)\
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"purr":
			## Кіт мурчить (покачування)
			tw.tween_property(creature, "rotation", 0.08, 0.15)
			tw.tween_property(creature, "rotation", -0.08, 0.15)
			tw.tween_property(creature, "rotation", 0.06, 0.12)
			tw.tween_property(creature, "rotation", -0.06, 0.12)
			tw.tween_property(creature, "rotation", 0.0, 0.1)
		"flap":
			## Пташка махає крилами (scale pulsing)
			for _i: int in 3:
				tw.tween_property(creature, "scale", Vector2(1.15, 0.9), 0.12)
				tw.tween_property(creature, "scale", Vector2(0.9, 1.1), 0.12)
			tw.tween_property(creature, "scale", Vector2.ONE, 0.1)
		"jump":
			## Жаба стрибає високо
			tw.tween_property(creature, "position:y", creature.position.y - 80.0, 0.3)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(creature, "scale", Vector2(1.2, 0.8), 0.1)
			tw.tween_property(creature, "position:y", creature.position.y, 0.3)\
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_property(creature, "scale", Vector2.ONE, 0.15)
		"swim":
			## Рибка пливе хвилею
			tw.tween_property(creature, "position:x", creature.position.x + 50.0, 0.4)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(creature, "rotation", 0.15, 0.2)
			tw.tween_property(creature, "position:x", creature.position.x - 50.0, 0.4)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(creature, "rotation", -0.15, 0.2)
			tw.tween_property(creature, "position:x", creature.position.x, 0.2)
			tw.tween_property(creature, "rotation", 0.0, 0.1)
		"dance":
			## Робот танцює
			tw.tween_property(creature, "scale", Vector2(1.1, 0.9), 0.1)
			tw.tween_property(creature, "scale", Vector2(0.9, 1.1), 0.1)
			tw.tween_property(creature, "rotation", 0.1, 0.08)
			tw.tween_property(creature, "rotation", -0.1, 0.08)
			tw.tween_property(creature, "scale", Vector2(1.1, 0.9), 0.1)
			tw.tween_property(creature, "scale", Vector2(0.9, 1.1), 0.1)
			tw.tween_property(creature, "rotation", 0.0, 0.08)
			tw.tween_property(creature, "scale", Vector2.ONE, 0.1)
		_:
			## Дефолт: покачування
			tw.tween_property(creature, "scale", Vector2(1.15, 0.85), 0.15)
			tw.tween_property(creature, "scale", Vector2.ONE, 0.2)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## ---- Preschool: celebrations ----

func _preschool_celebration() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Групуємо деталі
	var construct: Node2D = Node2D.new()
	construct.position = Vector2(vp.x * 0.5, vp.y * 0.38)
	add_child(construct)
	_all_round_nodes.append(construct)
	for shape: Node2D in _shapes:
		if is_instance_valid(shape):
			var gpos: Vector2 = shape.global_position
			shape.reparent(construct)
			shape.global_position = gpos
	_play_round_celebration(construct.global_position)
	## Унікальна celebration анімація
	if not SettingsManager.reduced_motion:
		_animate_constructor_celebration(construct, _current_constructor_id)
	await get_tree().create_timer(3.0).timeout
	if not is_instance_valid(self) or _game_finished:
		return
	_record_round_errors(_consecutive_errors)
	_round += 1
	if _round >= PRESCHOOL_ROUNDS:
		_finish()
	else:
		_game_over = false
		_input_locked = false
		_start_preschool_round()


## 3-секундна celebration для кожного типу конструктора
func _animate_constructor_celebration(construct: Node2D, cid: String) -> void:
	if not is_instance_valid(construct):
		return
	var tw: Tween = _create_game_tween()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	match cid:
		"rocket":
			## Ракета злітає через зірки
			AudioManager.play_sfx("success", 0.8)
			tw.tween_property(construct, "position:y", -300.0, 1.5)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(construct, "scale", Vector2(0.6, 1.4), 1.5)
			tw.tween_callback(func() -> void:
				if is_instance_valid(self):
					VFXManager.spawn_sparkle_pop(Vector2(vp.x * 0.5, vp.y * 0.2)))
		"boat":
			## Лодка пливе через екран
			tw.tween_property(construct, "position:x", vp.x + 200.0, 2.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			## Хвилеподібне покачування
			tw.parallel().tween_property(construct, "rotation", 0.06, 0.5)
			tw.tween_property(construct, "rotation", -0.06, 0.5)
			tw.tween_property(construct, "rotation", 0.04, 0.4)
		"house":
			## Дім: вітаючий рух + блиск вікон
			tw.tween_property(construct, "scale", Vector2(1.1, 1.1), 0.3)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(construct, "scale", Vector2.ONE, 0.2)
			tw.tween_callback(func() -> void:
				if is_instance_valid(self):
					VFXManager.spawn_golden_burst(construct.global_position + Vector2(0, -40)))
			tw.tween_property(construct, "modulate", Color(1.2, 1.1, 0.9), 0.3)
			tw.tween_property(construct, "modulate", Color.WHITE, 0.5)
		"car":
			## Машина їде вправо зі зменшенням (перспектива)
			tw.tween_property(construct, "position:x", vp.x + 200.0, 2.0)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(construct, "scale", Vector2(0.5, 0.5), 2.0)
		"airplane":
			## Літак злітає по діагоналі
			tw.tween_property(construct, "rotation", -0.3, 0.3)
			tw.tween_property(construct, "position",
				Vector2(vp.x + 200.0, -200.0), 2.0)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(construct, "scale", Vector2(0.4, 0.4), 2.0)
		"castle":
			## Замок: феєрверки з двох башт
			tw.tween_property(construct, "scale", Vector2(1.05, 1.05), 0.3)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func() -> void:
				if is_instance_valid(self):
					VFXManager.spawn_firework_fountain(
						construct.global_position + Vector2(-55, -75))
					VFXManager.spawn_firework_fountain(
						construct.global_position + Vector2(55, -75)))
			tw.tween_property(construct, "scale", Vector2.ONE, 0.3)
		"flower":
			## Квітка розцвітає (пульсація + sparkle)
			tw.tween_property(construct, "scale", Vector2(1.3, 1.3), 0.5)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(construct, "scale", Vector2.ONE, 0.3)
			tw.tween_callback(func() -> void:
				if is_instance_valid(self):
					VFXManager.spawn_heart_particles(construct.global_position))
		"robot":
			## Робот танцює
			tw.tween_property(construct, "rotation", 0.15, 0.15)
			tw.tween_property(construct, "rotation", -0.15, 0.15)
			tw.tween_property(construct, "scale", Vector2(1.15, 0.85), 0.12)
			tw.tween_property(construct, "scale", Vector2(0.85, 1.15), 0.12)
			tw.tween_property(construct, "rotation", 0.1, 0.12)
			tw.tween_property(construct, "rotation", -0.1, 0.12)
			tw.tween_property(construct, "rotation", 0.0, 0.1)
			tw.tween_property(construct, "scale", Vector2.ONE, 0.15)
			tw.tween_callback(func() -> void:
				if is_instance_valid(self):
					VFXManager.spawn_sparkle_pop(construct.global_position))
		_:
			## Дефолт: покачування + sparkle
			tw.tween_property(construct, "scale", Vector2(1.2, 0.85), 0.2)
			tw.tween_property(construct, "scale", Vector2.ONE, 0.3)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## ---- Finish ----

func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	var rounds: int = TODDLER_ROUNDS if _is_toddler else PRESCHOOL_ROUNDS
	var stats: Dictionary = {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": rounds,
		"earned_stars": earned,
	}
	finish_game(earned, stats)


## ---- Idle hint system (A10) ----

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
		## A10 Lvl2: tutorial hand — показати правильну пару фігура->слот
		var demo: Dictionary = get_tutorial_demo()
		if demo.has("from") and demo.has("to"):
			var from_pos: Vector2 = demo.get("from", Vector2.ZERO)
			var to_pos: Vector2 = demo.get("to", Vector2.ZERO)
			for shape: Node2D in _shapes:
				if is_instance_valid(shape) and shape.global_position.distance_to(from_pos) < 10.0:
					_pulse_node(shape, 1.3)
					break
			for slot: Node2D in _slots:
				if is_instance_valid(slot) and slot.global_position.distance_to(to_pos) < 10.0:
					_pulse_node(slot, 1.3)
					if not SettingsManager.reduced_motion:
						var flash_tw: Tween = _create_game_tween()
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


## ---- Tutorial (A1) ----

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
