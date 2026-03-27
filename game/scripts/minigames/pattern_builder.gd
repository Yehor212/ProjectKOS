extends BaseMiniGame

## Бусы для друзів / Bead Necklace — нанизуй бусини на ожерелье для друга-тварини.
## Паттерн видний на нитці, одна бусина пропущена (?).
## Drag правильну бусину з лотка -> бусина встає на місце з click + sparkle.
## Коли ожерелье готове -> тварина надіває його і крутиться від радості.

const TOTAL_ROUNDS: int = 5
const SAFETY_TIMEOUT_SEC: float = 120.0
const BEAD_RADIUS: float = 34.0
const TRAY_BEAD_RADIUS: float = 40.0
const STRING_Y: float = 0.38  ## Відносна Y позиція нитки (від viewport)
const TRAY_Y: float = 0.72  ## Відносна Y позиція лотка
const DEAL_STAGGER: float = 0.07
const DEAL_DURATION: float = 0.30
const IDLE_HINT_DELAY: float = 5.0
const ANIMAL_SCALE: float = 0.55
const STRING_SAG: float = 30.0  ## Провисання нитки (catenary ефект)

## Бусини — кожна форма має УНІКАЛЬНИЙ колір для LAW 25 (colorblind safe).
## id використовується для ідентифікації, shape визначає форму малювання.
const BEAD_DEFS: Array[Dictionary] = [
	{"id": "star", "shape": "star", "color": Color("ffd43b"), "label": "BEAD_STAR"},
	{"id": "heart", "shape": "heart", "color": Color("ff6b6b"), "label": "BEAD_HEART"},
	{"id": "diamond", "shape": "diamond", "color": Color("4dabf7"), "label": "BEAD_DIAMOND"},
	{"id": "circle", "shape": "circle", "color": Color("51cf66"), "label": "BEAD_CIRCLE"},
	{"id": "triangle", "shape": "triangle", "color": Color("ff922b"), "label": "BEAD_TRIANGLE"},
	{"id": "flower", "shape": "flower", "color": Color("cc5de8"), "label": "BEAD_FLOWER"},
]

## Типи паттернів за складністю (A4: difficulty ramp)
const PATTERN_TYPES: Array[Array] = [
	[0, 1],           ## AB
	[0, 1],           ## AB (довший)
	[0, 1, 2],        ## ABC
	[0, 0, 1, 1],     ## AABB
	[0, 1, 0, 2],     ## ABAC (distractor pattern)
]

var _is_toddler: bool = false
var _round: int = 0
var _start_time: float = 0.0
var _drag: UniversalDrag = null
var _origins: Dictionary = {}  ## BeadItem -> Vector2 (snap-back origins)

var _string_node: Node2D = null  ## Нитка ожерелья
var _bead_nodes: Array[Node2D] = []  ## Бусини на нитці
var _slot_node: Node2D = null  ## Пропущена бусина (?) — drop target
var _tray_nodes: Array[Node2D] = []  ## Бусини в лотку (draggable)
var _animal_node: Node2D = null  ## Тварина-друг
var _correct_bead_def: Dictionary = {}  ## Правильна бусина для поточного раунду
var _slot_position: Vector2 = Vector2.ZERO
var _bead_positions: Array[Vector2] = []  ## Позиції всіх бусин на нитці

var _idle_timer: SceneTreeTimer = null
var _used_animal_indices: Array[int] = []  ## Уникальні тварини між раундами
var _round_errors_count: int = 0  ## Помилки в поточному раунді (для ZPD)


func _ready() -> void:
	game_id = "pattern"
	bg_theme = "candy"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_setup_drag()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("BEAD_NECKLACE_TUTORIAL_TODDLER")
	return tr("BEAD_NECKLACE_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	## A1: Показати drag від правильної бусини до слота
	if _tray_nodes.size() > 0 and is_instance_valid(_slot_node):
		for bead: Node2D in _tray_nodes:
			if is_instance_valid(bead) and bead.get_meta("is_correct", false):
				return {"type": "drag", "from": bead.global_position,
					"to": _slot_node.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


func _setup_drag() -> void:
	_drag = UniversalDrag.new(self)
	_drag.item_picked_up.connect(_on_bead_picked)
	_drag.item_dropped_on_target.connect(_on_bead_dropped)
	_drag.item_dropped_on_empty.connect(_on_bead_missed)
	if _is_toddler:
		_drag.magnetic_assist = true
		_drag.snap_radius_override = TODDLER_SNAP_RADIUS


func _on_bead_picked(_item: Node2D) -> void:
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()


func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_input(event)


func _physics_process(delta: float) -> void:
	super(delta)
	if not _input_locked and not _game_over:
		_drag.handle_process(delta)


## ---- Раунд lifecycle ----


func _start_round() -> void:
	_input_locked = true
	_round_errors_count = 0
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])

	## Генерація паттерну для поточного раунду
	var pattern_data: Dictionary = _generate_round_data()
	_correct_bead_def = pattern_data.get("answer", {})
	if _correct_bead_def.is_empty():
		push_warning("PatternBuilder: empty correct_bead_def, advancing")
		_advance_round()
		return

	## Розмістити нитку + бусини
	_spawn_string_and_beads(pattern_data)

	## Розмістити тварину-друга
	_spawn_animal()

	## Розмістити лоток з бусинами
	_spawn_tray(pattern_data)


func _generate_round_data() -> Dictionary:
	## A3: вікова розвилка + A4: difficulty ramp
	var pattern_idx: int
	if _is_toddler:
		## Toddler: тільки AB паттерни, перші 2 типи
		pattern_idx = mini(_round, 1)
	else:
		## Preschool: повна прогресія 0-4
		pattern_idx = clampi(_round, 0, PATTERN_TYPES.size() - 1)

	if pattern_idx < 0 or pattern_idx >= PATTERN_TYPES.size():
		push_warning("PatternBuilder: pattern_idx out of bounds, clamping")
		pattern_idx = 0
	var unit_template: Array = PATTERN_TYPES[pattern_idx]
	var unit_size: int = 0
	for idx: int in unit_template:
		if idx >= unit_size:
			unit_size = idx + 1

	## Вибрати унікальні бусини для цього раунду
	var pool: Array[Dictionary] = []
	for def: Dictionary in BEAD_DEFS:
		pool.append(def)
	pool.shuffle()

	if pool.size() < unit_size:
		push_warning("PatternBuilder: not enough bead types, need %d have %d" % [unit_size, pool.size()])
		unit_size = pool.size()
	var unit_beads: Array[Dictionary] = []
	for i: int in range(unit_size):
		if i < pool.size():
			unit_beads.append(pool[i])

	## LAW 6: кількість бусин зростає з раундами
	var bead_count: int
	if _is_toddler:
		bead_count = _scale_by_round_i(4, 6, _round, TOTAL_ROUNDS)
	else:
		bead_count = _scale_by_round_i(4, 7, _round, TOTAL_ROUNDS)

	## Побудувати послідовність бусин
	var sequence: Array[Dictionary] = []
	for i: int in range(bead_count):
		var tmpl_idx: int = i % maxi(unit_template.size(), 1)
		var bead_idx: int = unit_template[tmpl_idx]
		if bead_idx < unit_beads.size():
			sequence.append(unit_beads[bead_idx])
		elif unit_beads.size() > 0:
			sequence.append(unit_beads[0])

	## Вибрати позицію пропущеної бусини (не першу і не останню для ясності)
	var missing_idx: int
	if sequence.size() <= 2:
		missing_idx = maxi(sequence.size() - 1, 0)
	else:
		## Пропуск у другій половині для кращої читабельності паттерну
		missing_idx = _scale_by_round_i(
			maxi(sequence.size() / 2, 1),
			maxi(sequence.size() - 2, 1),
			_round, TOTAL_ROUNDS)
		missing_idx = clampi(missing_idx, 1, maxi(sequence.size() - 1, 1))

	var answer: Dictionary = {}
	if missing_idx >= 0 and missing_idx < sequence.size():
		answer = sequence[missing_idx]
	elif sequence.size() > 0:
		push_warning("PatternBuilder: missing_idx out of range, using last bead")
		answer = sequence[sequence.size() - 1]
		missing_idx = sequence.size() - 1

	## LAW 2: мінімум 3 вибори у лотку
	var distractor_count: int
	if _is_toddler:
		distractor_count = _scale_by_round_i(1, 2, _round, TOTAL_ROUNDS)
	else:
		distractor_count = _scale_by_round_i(2, 4, _round, TOTAL_ROUNDS)
	distractor_count = maxi(distractor_count, 2)  ## LAW 2: мінімум 3 вибори (1 correct + 2 wrong)

	## Зібрати дистрактори — інші бусини, що НЕ є правильною відповіддю
	var distractors: Array[Dictionary] = []
	for def: Dictionary in BEAD_DEFS:
		if def.get("id", "") != answer.get("id", ""):
			distractors.append(def)
	distractors.shuffle()
	var choices: Array[Dictionary] = [answer]
	for i: int in range(mini(distractor_count, distractors.size())):
		choices.append(distractors[i])
	choices.shuffle()

	return {
		"sequence": sequence,
		"missing_idx": missing_idx,
		"answer": answer,
		"choices": choices,
	}


func _spawn_string_and_beads(data: Dictionary) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sequence: Array = data.get("sequence", [])
	var missing_idx: int = data.get("missing_idx", 0)

	if sequence.size() == 0:
		push_warning("PatternBuilder: empty sequence in _spawn_string_and_beads")
		return

	## Розрахувати позиції бусин на нитці
	var count: int = sequence.size()
	var margin_x: float = vp.x * 0.15
	var total_width: float = vp.x - margin_x * 2.0
	var spacing: float = total_width / maxf(float(count - 1), 1.0)
	var base_y: float = vp.y * STRING_Y

	_bead_positions.clear()
	for i: int in range(count):
		## Catenary sag — параболічне провисання нитки
		var t: float = float(i) / maxf(float(count - 1), 1.0)
		var sag: float = STRING_SAG * (4.0 * t * (1.0 - t))  ## Парабола: 0 на краях, max в центрі
		var pos: Vector2 = Vector2(margin_x + spacing * float(i), base_y + sag)
		_bead_positions.append(pos)

	## Намалювати нитку
	_string_node = Node2D.new()
	_string_node.z_index = 0
	add_child(_string_node)
	var positions_copy: Array[Vector2] = _bead_positions.duplicate()
	_string_node.draw.connect(func() -> void:
		if positions_copy.size() < 2:
			return
		## Основна нитка — товста м'яка лінія
		var string_color: Color = Color("d4a574")
		var shadow_color: Color = Color(0, 0, 0, 0.12)
		## Тінь нитки
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for pos: Vector2 in positions_copy:
			shadow_pts.append(pos + Vector2(1.5, 2.5))
		if shadow_pts.size() >= 2:
			_string_node.draw_polyline(shadow_pts, shadow_color, 5.0, true)
		## Нитка
		var pts: PackedVector2Array = PackedVector2Array()
		for pos: Vector2 in positions_copy:
			pts.append(pos)
		if pts.size() >= 2:
			_string_node.draw_polyline(pts, string_color, 3.5, true)
			## Блік нитки
			_string_node.draw_polyline(pts, Color(1, 1, 1, 0.15), 1.5, true)
	)
	_string_node.queue_redraw()

	## Розмістити бусини + слот
	var stagger_idx: int = 0
	for i: int in range(count):
		if i < 0 or i >= _bead_positions.size():
			continue
		var pos: Vector2 = _bead_positions[i]
		if i == missing_idx:
			## Слот — пропущена бусина
			_slot_node = _create_slot_node(pos, sequence[i])
			add_child(_slot_node)
			_slot_position = pos
			_deal_node_in(_slot_node, pos, float(stagger_idx) * DEAL_STAGGER, false)
		else:
			## Бусина на нитці
			var bead_def: Dictionary = sequence[i]
			var bead: Node2D = _create_bead_node(bead_def, BEAD_RADIUS, false)
			add_child(bead)
			_deal_node_in(bead, pos, float(stagger_idx) * DEAL_STAGGER, false)
			_bead_nodes.append(bead)
		stagger_idx += 1


func _spawn_animal() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size

	## Вибрати унікальну тварину для цього раунду
	var animal_idx: int = -1
	var attempts: int = 0
	while attempts < 30:
		var candidate: int = randi() % maxi(GameData.ANIMALS_AND_FOOD.size(), 1)
		if not _used_animal_indices.has(candidate):
			animal_idx = candidate
			break
		attempts += 1

	## Fallback: якщо всі тварини використані — скинути і вибрати будь-яку
	if animal_idx < 0:
		_used_animal_indices.clear()
		animal_idx = randi() % maxi(GameData.ANIMALS_AND_FOOD.size(), 1)

	if animal_idx < 0 or animal_idx >= GameData.ANIMALS_AND_FOOD.size():
		push_warning("PatternBuilder: invalid animal_idx %d" % animal_idx)
		return

	_used_animal_indices.append(animal_idx)
	var pair: Dictionary = GameData.ANIMALS_AND_FOOD[animal_idx]
	if not pair.has("animal_scene"):
		push_warning("PatternBuilder: animal pair missing animal_scene")
		return

	var scene: PackedScene = pair.get("animal_scene")
	if scene == null:
		push_warning("PatternBuilder: animal_scene is null")
		return

	_animal_node = scene.instantiate()
	_animal_node.scale = Vector2(ANIMAL_SCALE, ANIMAL_SCALE)
	## Тварина справа від нитки — чекає ожерелье
	_animal_node.position = Vector2(vp.x * 0.88, vp.y * STRING_Y + 20.0)
	_animal_node.z_index = 2
	add_child(_animal_node)

	## Entrance анімація для тварини
	if not SettingsManager.reduced_motion and is_instance_valid(_animal_node):
		_animal_node.modulate.a = 0.0
		_animal_node.scale = Vector2(ANIMAL_SCALE * 0.3, ANIMAL_SCALE * 0.3)
		var atw: Tween = _create_game_tween().set_parallel(true)
		atw.tween_property(_animal_node, "modulate:a", 1.0, 0.3).set_delay(0.2)
		atw.tween_property(_animal_node, "scale",
			Vector2(ANIMAL_SCALE, ANIMAL_SCALE), 0.4)\
			.set_delay(0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _spawn_tray(data: Dictionary) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var choices: Array = data.get("choices", [])

	if choices.size() == 0:
		push_warning("PatternBuilder: empty choices in _spawn_tray")
		_input_locked = false
		return

	var choice_count: int = choices.size()
	var tray_spacing: float = vp.x / float(choice_count + 1)
	var tray_y: float = vp.y * TRAY_Y
	var total_bead_delay: float = float(_bead_positions.size()) * DEAL_STAGGER

	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	_origins.clear()

	for i: int in range(choice_count):
		var bead_def: Dictionary = choices[i]
		var bead: Node2D = _create_bead_node(bead_def, TRAY_BEAD_RADIUS, true)
		add_child(bead)

		var is_correct: bool = bead_def.get("id", "") == _correct_bead_def.get("id", "")
		bead.set_meta("is_correct", is_correct)
		bead.set_meta("bead_def", bead_def)
		bead.set_meta("disabled", false)

		var target_pos: Vector2 = Vector2(tray_spacing * float(i + 1), tray_y)
		var is_last: bool = (i == choice_count - 1)
		_deal_node_in(bead, target_pos,
			total_bead_delay + float(i) * DEAL_STAGGER, is_last)
		_origins[bead] = target_pos
		_tray_nodes.append(bead)
		_drag.draggable_items.append(bead)

	## Drop target = слот
	if is_instance_valid(_slot_node):
		_drag.drop_targets.append(_slot_node)
		## Магнітний асист для тоддлерів — прив'язати правильну бусину до слоту
		if _is_toddler:
			for bead: Node2D in _tray_nodes:
				if is_instance_valid(bead) and bead.get_meta("is_correct", false):
					_drag.set_correct_pairs({bead: _slot_node})
					break


## ---- Створення нод ----


func _create_bead_node(bead_def: Dictionary, radius: float, is_interactive: bool) -> Node2D:
	var bead: Node2D = Node2D.new()
	var shape_id: String = bead_def.get("shape", "circle")
	var color: Color = bead_def.get("color", Color.WHITE)
	var r: float = _toddler_scale(radius) if is_interactive else radius

	## Premium grain material (LAW 28)
	if is_interactive:
		bead.material = GameData.create_grain_material()

	bead.draw.connect(_draw_bead.bind(bead, shape_id, color, r))
	bead.queue_redraw()
	return bead


func _draw_bead(bead: Node2D, shape_id: String, color: Color, radius: float) -> void:
	## LAW 28: Premium visual pipeline — 4+ шари (малюємо прямо на Node2D)
	var pal: Dictionary = IconDraw._color_palette(color)
	var center: Vector2 = Vector2.ZERO
	var dark_col: Color = pal.get("dark", color.darkened(0.2))
	var shadow_offset: Vector2 = Vector2(1.5, 2.5)

	## Шар 1: М'яка тінь (3 кола зі зменшенням альфа)
	var shadow_base: Color = Color(0, 0, 0, 0.18)
	bead.draw_circle(center + shadow_offset, radius + 3.0, Color(shadow_base, shadow_base.a * 0.28))
	bead.draw_circle(center + shadow_offset, radius + 1.5, Color(shadow_base, shadow_base.a * 0.55))
	bead.draw_circle(center + shadow_offset, radius, shadow_base)

	## Шар 2: Основна форма (dark base)
	_draw_shape(bead, shape_id, center, radius, dark_col)

	## Шар 3: Основна форма (base color) — трохи менша зі зміщенням для об'єму
	var inner_r: float = radius * 0.88
	_draw_shape(bead, shape_id, center + Vector2(-1, -1), inner_r, color)

	## Шар 4: Глянцевий блік + спекулярна крапка
	var gloss_pos: Vector2 = center + Vector2(-radius * 0.28, -radius * 0.28)
	var gloss_r: float = maxf(radius * 0.35, 2.0)
	bead.draw_circle(gloss_pos, gloss_r, Color(1, 1, 1, 0.35))
	var spec_pos: Vector2 = center + Vector2(-radius * 0.18, -radius * 0.38)
	var spec_r: float = maxf(radius * 0.14, 1.0)
	bead.draw_circle(spec_pos, spec_r, Color(1, 1, 1, 0.5))

	## Отвір для нитки (маленьке коло в центрі)
	bead.draw_circle(center, radius * 0.1, Color(0, 0, 0, 0.25))
	bead.draw_circle(center + Vector2(-0.5, -0.5), radius * 0.07, Color(1, 1, 1, 0.2))


## Уніфікований малювальник форм для будь-якого shape_id
func _draw_shape(node: Node2D, shape_id: String, center: Vector2,
		radius: float, color: Color) -> void:
	match shape_id:
		"star":
			_draw_star_shape(node, center, radius, color)
		"heart":
			_draw_heart_shape(node, center, radius, color)
		"diamond":
			_draw_diamond_shape(node, center, radius, color)
		"circle":
			node.draw_circle(center, radius, color)
		"triangle":
			_draw_triangle_shape(node, center, radius, color)
		"flower":
			_draw_flower_shape(node, center, radius, color)
		_:
			node.draw_circle(center, radius, color)


func _draw_star_shape(node: Node2D, center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(10):
		var angle: float = -PI / 2.0 + float(i) * TAU / 10.0
		var r: float = radius if i % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	if points.size() >= 3:
		node.draw_polygon(points, [color])


func _draw_heart_shape(node: Node2D, center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 32
	for i: int in range(steps):
		var t: float = float(i) / float(steps) * TAU
		## Параметричне рівняння серця
		var x: float = 16.0 * pow(sin(t), 3)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(center + Vector2(x, y) * radius / 18.0)
	if points.size() >= 3:
		node.draw_polygon(points, [color])


func _draw_diamond_shape(node: Node2D, center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -radius),       ## Верх
		center + Vector2(radius * 0.7, 0),  ## Право
		center + Vector2(0, radius),         ## Низ
		center + Vector2(-radius * 0.7, 0),  ## Ліво
	])
	node.draw_polygon(points, [color])


func _draw_triangle_shape(node: Node2D, center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(3):
		var angle: float = -PI / 2.0 + float(i) * TAU / 3.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if points.size() >= 3:
		node.draw_polygon(points, [color])


func _draw_flower_shape(node: Node2D, center: Vector2, radius: float, color: Color) -> void:
	## 6 пелюсток + центральне коло
	var petal_r: float = radius * 0.45
	for i: int in range(6):
		var angle: float = float(i) * TAU / 6.0
		var petal_center: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.5
		node.draw_circle(petal_center, petal_r, color)
	## Центр квітки (світліший)
	node.draw_circle(center, radius * 0.3, color.lightened(0.25))


func _create_slot_node(_pos: Vector2, bead_def: Dictionary) -> Node2D:
	## Слот — контурна версія правильної бусини (LAW 28: inward depth)
	var slot: Node2D = Node2D.new()
	var color: Color = bead_def.get("color", Color.WHITE)
	var r: float = BEAD_RADIUS

	slot.draw.connect(func() -> void:
		## Внутрішня тінь (darkened rim)
		var rim_color: Color = Color(0, 0, 0, 0.08)
		slot.draw_circle(Vector2.ZERO, r + 3.0, rim_color)
		## Основне коло слоту — напівпрозоре
		var slot_color: Color = Color(color, 0.2)
		slot.draw_circle(Vector2.ZERO, r, slot_color)
		## Пунктирний контур — пульсуюча підказка
		var outline_color: Color = Color(color, 0.5)
		var dash_count: int = 16
		for i: int in range(dash_count):
			if i % 2 == 0:
				var a1: float = float(i) * TAU / float(dash_count)
				var a2: float = float(i + 1) * TAU / float(dash_count)
				var p1: Vector2 = Vector2(cos(a1), sin(a1)) * r
				var p2: Vector2 = Vector2(cos(a2), sin(a2)) * r
				slot.draw_line(p1, p2, outline_color, 2.5, true)
		## Знак питання в центрі
		slot.draw_string(ThemeDB.fallback_font, Vector2(-8, 8),
			"?", HORIZONTAL_ALIGNMENT_CENTER, -1, 28,
			Color(color, 0.6))
	)
	slot.queue_redraw()
	return slot


## ---- Анімація deal-in ----


func _deal_node_in(node: Node2D, target: Vector2, delay: float, unlock_on_finish: bool) -> void:
	if SettingsManager.reduced_motion:
		node.position = target
		node.scale = Vector2.ONE
		node.modulate.a = 1.0
		if unlock_on_finish:
			_input_locked = false
			_reset_idle_timer()
		return

	node.position = Vector2(target.x, target.y + 180.0)
	node.scale = Vector2(0.2, 0.2)
	node.modulate.a = 0.0
	var tw: Tween = _create_game_tween().set_parallel(true)
	tw.tween_property(node, "position", target, DEAL_DURATION)\
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, DEAL_DURATION)\
		.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.2).set_delay(delay)
	## Pop sound при появі кожної бусини (staggered)
	var pop_tw: Tween = _create_game_tween()
	pop_tw.tween_interval(delay + DEAL_DURATION * 0.5)
	pop_tw.tween_callback(func() -> void:
		if is_instance_valid(self):
			AudioManager.play_sfx("pop"))
	if unlock_on_finish:
		tw.chain().tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer()
		)


## ---- Drag-and-drop callbacks ----


func _on_bead_dropped(item: Node2D, target: Node2D) -> void:
	if not is_instance_valid(item) or not is_instance_valid(target):
		push_warning("PatternBuilder: dropped item or target invalid")
		return
	if item.get_meta("disabled", false):
		push_warning("PatternBuilder: dropped disabled bead")
		return

	_input_locked = true
	if item.get_meta("is_correct", false):
		_handle_correct_drop(item)
	else:
		_handle_wrong_drop(item)


func _on_bead_missed(item: Node2D) -> void:
	if not is_instance_valid(item):
		push_warning("PatternBuilder: missed item invalid")
		return
	## Snap back до вихідної позиції
	if _origins.has(item):
		_drag.snap_back(item, _origins[item])


func _handle_correct_drop(item: Node2D) -> void:
	AudioManager.play_sfx("success")
	_register_correct(item)
	VFXManager.spawn_success_ripple(item.global_position, Color(0.4, 1.0, 0.4))

	## Перемістити бусину на позицію слоту
	var correct_bead: Node2D = _create_bead_node(_correct_bead_def, BEAD_RADIUS, false)
	add_child(correct_bead)

	if SettingsManager.reduced_motion:
		correct_bead.position = _slot_position
		correct_bead.scale = Vector2.ONE
		correct_bead.modulate.a = 1.0
		if is_instance_valid(item):
			item.modulate.a = 0.0
	else:
		correct_bead.position = item.global_position
		correct_bead.scale = Vector2(0.5, 0.5)
		correct_bead.modulate.a = 0.0

		var snap_tw: Tween = _create_game_tween().set_parallel(true)
		snap_tw.tween_property(correct_bead, "position", _slot_position, 0.25)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		snap_tw.tween_property(correct_bead, "scale", Vector2.ONE, 0.25)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		snap_tw.tween_property(correct_bead, "modulate:a", 1.0, 0.12)

		## Зникнення оригінальної бусини з лотка
		if is_instance_valid(item):
			_create_game_tween().tween_property(item, "modulate:a", 0.0, 0.15)

	_bead_nodes.append(correct_bead)

	## Приховати слот
	if is_instance_valid(_slot_node):
		if SettingsManager.reduced_motion:
			_slot_node.modulate.a = 0.0
		else:
			_create_game_tween().tween_property(_slot_node, "modulate:a", 0.0, 0.15)

	## VFX sparkle на місці
	VFXManager.spawn_correct_sparkle(_slot_position)

	## Зникнення неправильних бусин з лотка
	if not SettingsManager.reduced_motion:
		for tray_bead: Node2D in _tray_nodes:
			if is_instance_valid(tray_bead) and tray_bead != item:
				_create_game_tween().tween_property(tray_bead, "modulate:a", 0.3, 0.2)

	## Тварина радіє — celebration spin + хвиля бусин
	_play_animal_celebration()
	_play_bead_wave()
	AudioManager.play_sfx("reward")
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size / 2.0)

	## Перехід до наступного раунду
	var delay: float = 0.15 if SettingsManager.reduced_motion else 1.2
	var advance_tw: Tween = _create_game_tween()
	advance_tw.tween_interval(delay)
	advance_tw.tween_callback(_advance_round)


func _handle_wrong_drop(item: Node2D) -> void:
	_round_errors_count += 1

	if _is_toddler:
		## A6: Toddler — без штрафу, м'який зворотній зв'язок
		_register_error(item)
	else:
		## A7: Preschool — _errors += 1
		_errors += 1
		_register_error(item)
		item.modulate = Color(0.5, 0.5, 0.5, 0.7)
		item.set_meta("disabled", true)
		## Прибрати з draggable
		var idx: int = _drag.draggable_items.find(item)
		if idx >= 0:
			_drag.draggable_items.remove_at(idx)

	## Snap back
	if _origins.has(item):
		_drag.snap_back(item, _origins[item])

	## Розблокувати input
	var unlock_delay: float = 0.1 if SettingsManager.reduced_motion else 0.35
	var unlock_tw: Tween = _create_game_tween()
	unlock_tw.tween_interval(unlock_delay)
	unlock_tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer()
	)


## ---- Святкові анімації ----


func _play_animal_celebration() -> void:
	## Тварина радіє: підскік + обертання (catwalk strut)
	if not is_instance_valid(_animal_node):
		return
	if SettingsManager.reduced_motion:
		return

	var orig_pos: Vector2 = _animal_node.position
	var orig_rot: float = _animal_node.rotation

	var dance_tw: Tween = _create_game_tween()
	## Підскік
	dance_tw.tween_property(_animal_node, "position:y", orig_pos.y - 30.0, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dance_tw.tween_property(_animal_node, "position:y", orig_pos.y, 0.2)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	## Обертання від радості
	dance_tw.tween_property(_animal_node, "rotation", deg_to_rad(360.0), 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dance_tw.tween_property(_animal_node, "rotation", orig_rot, 0.01)
	## Ще один підскік
	dance_tw.tween_property(_animal_node, "position:y", orig_pos.y - 15.0, 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dance_tw.tween_property(_animal_node, "position:y", orig_pos.y, 0.15)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Переможний танець бусин на нитці — rotation wobble хвилею
func _play_bead_wave() -> void:
	if SettingsManager.reduced_motion:
		return
	var idx: int = 0
	for bead: Node2D in _bead_nodes:
		if not is_instance_valid(bead):
			continue
		var delay: float = float(idx) * 0.06
		var wave_tw: Tween = _create_game_tween()
		wave_tw.tween_interval(delay)
		wave_tw.tween_property(bead, "rotation", deg_to_rad(10.0), 0.08)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wave_tw.tween_property(bead, "rotation", deg_to_rad(-10.0), 0.12)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wave_tw.tween_property(bead, "rotation", 0.0, 0.08)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		idx += 1


## ---- Раунд management ----


func _advance_round() -> void:
	_record_round_errors(_round_errors_count)
	_clear_round()
	_round += 1
	if _round >= TOTAL_ROUNDS:
		_finish()
	else:
		_start_round()


func _clear_round() -> void:
	## A9: Round hygiene — очистити ВСІ тимчасові дані
	_drag.clear_drag()
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()

	## Очистити origins ПЕРЕД queue_free (LAW 9: erase before free)
	_origins.clear()

	for bead: Node2D in _bead_nodes:
		if is_instance_valid(bead):
			bead.queue_free()
	_bead_nodes.clear()

	if is_instance_valid(_slot_node):
		_slot_node.queue_free()
	_slot_node = null

	for bead: Node2D in _tray_nodes:
		if is_instance_valid(bead):
			bead.queue_free()
	_tray_nodes.clear()

	if is_instance_valid(_string_node):
		_string_node.queue_free()
	_string_node = null

	if is_instance_valid(_animal_node):
		_animal_node.queue_free()
	_animal_node = null

	_correct_bead_def = {}
	_bead_positions.clear()
	_slot_position = Vector2.ZERO
	_round_errors_count = 0


func _finish() -> void:
	_game_over = true
	_input_locked = true
	_drag.enabled = false
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size / 2.0)

	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)

	finish_game(earned, {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": TOTAL_ROUNDS,
		"earned_stars": earned,
	})


## ---- A11: Scaffolding — підсвітити правильну бусину ----


func _show_scaffold_hint() -> void:
	super()
	for bead: Node2D in _tray_nodes:
		if not is_instance_valid(bead):
			continue
		if bead.get_meta("is_correct", false) and not bead.get_meta("disabled", false):
			_pulse_node(bead, 1.3)
			## Тимчасове яскраве підсвічування (1.5 сек)
			var orig_mod: Color = bead.modulate
			bead.modulate = Color(1.4, 1.4, 1.0, 1.0)
			var hint_tw: Tween = _create_game_tween()
			hint_tw.tween_property(bead, "modulate", orig_mod, 1.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			return
	push_warning("PatternBuilder: scaffolding — correct bead not found in tray")


## ---- A10: Idle escalation ----


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
		## Level 2+: tutorial hand показується через super._advance_idle_hint
		_reset_idle_timer()
		return
	## Level 0-1: пульсація правильної бусини
	for bead: Node2D in _tray_nodes:
		if is_instance_valid(bead) and bead.get_meta("is_correct", false):
			_pulse_node(bead, 1.2)
			break
	_reset_idle_timer()


## ---- Cleanup on exit ----


func _on_exit_pause() -> void:
	_drag.enabled = false
	_drag.clear_drag()
