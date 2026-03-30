extends BaseMiniGame

## ECE-02 Фабрика фарб — фарбуй сірі предмети в правильне відро з фарбою!
## Toddler: 3 кольори, статичні предмети, без штрафу, без конвеєра.
## Preschool: 3→5 кольорів (прогресивно), конвеєр рухається, штраф за помилки.
## LAW 25: кожен колір прив'язаний до унікальної ФОРМИ (зірка, ромб, коло, серце, трикутник).
## LAW 1: предмети починають сірими — дія гравця РОЗКРИВАЄ колір.

const TOTAL_ROUNDS: int = 3
const ITEMS_TODDLER_MIN: int = 3
const ITEMS_TODDLER_MAX: int = 5
const ITEMS_PRESCHOOL_MIN: int = 4
const ITEMS_PRESCHOOL_MAX: int = 7
const CONVEYOR_SPEED_MIN: float = 30.0
const CONVEYOR_SPEED_MAX: float = 55.0
const CONVEYOR_Y_FACTOR: float = 0.38
const BUCKET_Y_FACTOR: float = 0.82
const ITEM_SIZE: float = 70.0
const BUCKET_W: float = 150.0
const BUCKET_H: float = 110.0
const BUCKET_CORNER: int = 18
const DEAL_STAGGER: float = 0.15
const DEAL_DURATION: float = 0.35
const PICK_RADIUS: float = 80.0
const TILT_FACTOR: float = 0.001
const TILT_MAX: float = 0.4
const TILT_LERP: float = 15.0
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0
const DANCE_EVERY_N: int = 4  ## Кожен N-й правильно пофарбований предмет "танцює"
const GREY_COLOR: Color = Color(0.55, 0.55, 0.60)
const GREY_BORDER: Color = Color(0.70, 0.70, 0.72, 0.6)
const PAINT_REVEAL_DURATION: float = 0.4
const DRIP_FLASH_DURATION: float = 0.25

## Палітра: колір + унікальна форма (LAW 25: shape + color, не тільки color)
const PALETTE: Array[Dictionary] = [
	{"id": "red", "color": Color("ef4444"), "name_key": "COLOR_RED", "shape": "star"},
	{"id": "blue", "color": Color("3b82f6"), "name_key": "COLOR_BLUE", "shape": "diamond"},
	{"id": "yellow", "color": Color("eab308"), "name_key": "COLOR_YELLOW", "shape": "circle"},
	{"id": "green", "color": Color("22c55e"), "name_key": "COLOR_GREEN", "shape": "heart"},
]
## Додаткові кольори для Preschool у пізніших раундах (A4: прогресивна складність)
const PALETTE_EXTRA: Array[Dictionary] = [
	{"id": "purple", "color": Color("a855f7"), "name_key": "COLOR_PURPLE", "shape": "triangle"},
	{"id": "orange", "color": Color("f97316"), "name_key": "COLOR_ORANGE", "shape": "hexagon"},
]

var _is_toddler: bool = false
var _round: int = 0
var _sorted_count: int = 0
var _total_items: int = 0
var _paint_count: int = 0  ## Глобальний лічильник правильних для "танцю"
var _start_time: float = 0.0

var _dragged: Node2D = null
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_original_z: int = 0
var _last_mouse: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO

var _items: Array[Node2D] = []
var _all_round_nodes: Array[Node] = []
var _item_color_id: Dictionary = {}
var _item_origins: Dictionary = {}
var _item_color_layers: Dictionary = {}  ## item -> color Panel (для анімації фарбування)
var _buckets: Array[Dictionary] = []

var _current_conveyor_speed: float = CONVEYOR_SPEED_MIN
var _idle_timer: SceneTreeTimer = null
var _conveyor_panel: Panel = null
var _narrative_label: Label = null


func _ready() -> void:
	game_id = "color_conveyor"
	_skill_id = "color_sorting"
	bg_theme = "candy"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_build_narrative_label(tr("PAINTER_NEEDS"))
	_build_conveyor_belt()
	_build_buckets()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


## Наратив — "Фабрика фарб потребує допомоги!" лейбл
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
		return tr("CONVEYOR_TUTORIAL_TODDLER")
	return tr("CONVEYOR_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _items.is_empty() or _buckets.is_empty():
		return {}
	var item: Node2D = _items[0]
	var color_id: String = _item_color_id.get(item, "")
	if color_id.is_empty():
		push_warning("ColorConveyor: get_tutorial_demo — item has no color_id")
		return {}
	for bucket: Dictionary in _buckets:
		if bucket.get("color_id", "") == color_id:
			var rect: Rect2 = bucket.get("rect", Rect2())
			return {"type": "drag", "from": item.global_position, "to": rect.get_center()}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Конвеєрна стрічка (декорація) ----

func _build_conveyor_belt() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var belt_y: float = vp.y * CONVEYOR_Y_FACTOR - 20.0
	_conveyor_panel = Panel.new()
	_conveyor_panel.position = Vector2(40, belt_y)
	_conveyor_panel.size = Vector2(vp.x - 80, 60)
	var style: StyleBoxFlat = GameData.candy_panel(Color(0.3, 0.3, 0.35, 0.75), 16)
	style.border_color = Color(1, 1, 1, 0.15)
	_conveyor_panel.add_theme_stylebox_override("panel", style)
	_conveyor_panel.material = GameData.create_premium_material(
		0.04, 2.0, 0.04, 0.06, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
	add_child(_conveyor_panel)


## ---- Відра з фарбою ----

func _build_buckets() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var colors: Array[Dictionary] = _get_full_palette()
	var count: int = colors.size()
	if count == 0:
		push_warning("ColorConveyor: _build_buckets — empty palette")
		return
	var spacing: float = vp.x / float(count + 1)
	var bucket_y: float = vp.y * BUCKET_Y_FACTOR
	for i: int in count:
		var c: Dictionary = colors[i]
		var x: float = spacing * float(i + 1) - BUCKET_W * 0.5
		var rect: Rect2 = Rect2(x, bucket_y - BUCKET_H * 0.5, BUCKET_W, BUCKET_H)
		## Фон відра з фарбою
		var panel: Panel = Panel.new()
		panel.position = Vector2(x, bucket_y - BUCKET_H * 0.5)
		panel.size = Vector2(BUCKET_W, BUCKET_H)
		var style: StyleBoxFlat = GameData.candy_cell(Color(c.color, 0.80), BUCKET_CORNER, true)
		style.border_color = Color(c.color, 0.85)
		style.set_border_width_all(3)
		panel.add_theme_stylebox_override("panel", style)
		panel.material = GameData.create_premium_material(
			0.05, 2.0, 0.04, 0.08, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
		add_child(panel)
		## Іконка форми + колір-блайнд паттерн (LAW 25: shape + pattern overlay)
		var shape_icon: Control = _create_shape_icon(c.get("shape", "circle"), 32.0, c.color)
		shape_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape_icon.position = Vector2(x + (BUCKET_W - 32.0) * 0.5, bucket_y - BUCKET_H * 0.5 + 12)
		add_child(shape_icon)
		## Кольорова точка з CB паттерном (додатковий LAW 25 маркер)
		var bsk_pat: String = GameData.get_cb_pattern(c.id) if SettingsManager.color_blind_mode else ""
		var dot: Control = IconDraw.color_dot_cb(24.0, c.color, bsk_pat)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(x + (BUCKET_W - 24.0) * 0.5, bucket_y - BUCKET_H * 0.5 + 48)
		add_child(dot)
		## Підпис кольору (LAW 10)
		var name_lbl: Label = Label.new()
		name_lbl.text = tr(c.get("name_key", ""))
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		name_lbl.position = Vector2(x, bucket_y + BUCKET_H * 0.5 - 36)
		name_lbl.size = Vector2(BUCKET_W, 36)
		add_child(name_lbl)
		_buckets.append({"rect": rect, "color_id": c.id, "panel": panel})


## Повна палітра для відер — завжди всі 5 кольорів для Preschool
func _get_full_palette() -> Array[Dictionary]:
	if _is_toddler:
		return PALETTE.duplicate()
	var full: Array[Dictionary] = PALETTE.duplicate()
	full.append_array(PALETTE_EXTRA)
	return full


## Палітра предметів для поточного раунду (Preschool: 3 кольори -> 5 поступово)
func _get_round_palette() -> Array[Dictionary]:
	if _is_toddler:
		return PALETTE.duplicate()
	var base: Array[Dictionary] = PALETTE.duplicate()
	## Раунд 0: 3 кольори. Раунд 1: +green. Раунд 2: +purple.
	var extras_to_add: int = mini(_round, PALETTE_EXTRA.size())
	for i: int in extras_to_add:
		if i < PALETTE_EXTRA.size():
			base.append(PALETTE_EXTRA[i])
	return base


## ---- Раунди ----

func _start_round() -> void:
	_sorted_count = 0
	_input_locked = true
	## A4: швидкість конвеєра зростає (тільки Preschool)
	if not _is_toddler:
		_current_conveyor_speed = _scale_stepped(
			CONVEYOR_SPEED_MIN, CONVEYOR_SPEED_MAX, _round, TOTAL_ROUNDS)
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	var palette: Array[Dictionary] = _get_round_palette()
	if palette.is_empty():
		push_warning("ColorConveyor: _start_round — empty palette, skipping")
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		return
	## A4: прогресивна складність — більше предметів у пізніших раундах
	var per_round: int
	if _is_toddler:
		per_round = _scale_stepped_i(ITEMS_TODDLER_MIN, ITEMS_TODDLER_MAX, _round, TOTAL_ROUNDS)
	else:
		per_round = _scale_stepped_i(ITEMS_PRESCHOOL_MIN, ITEMS_PRESCHOOL_MAX, _round, TOTAL_ROUNDS)
	_total_items = per_round
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	## Генеруємо набір предметів з рівним розподілом кольорів
	var toy_entries: Array[Dictionary] = []
	for j: int in per_round:
		toy_entries.append(palette[j % palette.size()])
	toy_entries.shuffle()
	_spawn_items(toy_entries)


func _spawn_items(toy_entries: Array[Dictionary]) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = toy_entries.size()
	if count == 0:
		push_warning("ColorConveyor: _spawn_items — empty entries")
		_input_locked = false
		return
	var conveyor_y: float = vp.y * CONVEYOR_Y_FACTOR
	var spacing: float = (vp.x - 160.0) / float(maxi(count, 1))
	var start_x: float = 80.0 + spacing * 0.5
	for i: int in count:
		var c: Dictionary = toy_entries[i]
		var target: Vector2 = Vector2(start_x + spacing * float(i), conveyor_y)
		var item: Node2D = _create_unpainted_item(c)
		_item_color_id[item] = c.id
		_item_origins[item] = target
		## Deal анімація (зверху вниз на стрічку)
		if SettingsManager.reduced_motion:
			item.position = target
			item.modulate.a = 1.0
			if i == count - 1:
				_input_locked = false
				_reset_idle_timer()
		else:
			item.position = Vector2(target.x, -80.0)
			item.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = _create_game_tween().set_parallel(true)
			tw.tween_property(item, "position", target, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
			if i == count - 1:
				tw.chain().tween_callback(func() -> void:
					_input_locked = false
					_reset_idle_timer())


## Створити СІРИЙ (непофарбований) предмет з формою (LAW 1: grayscale before color)
func _create_unpainted_item(c: Dictionary) -> Node2D:
	var node: Node2D = Node2D.new()
	add_child(node)
	## Сіре тло (непофарбований стан)
	var grey_bg: Panel = Panel.new()
	grey_bg.size = Vector2(ITEM_SIZE, ITEM_SIZE)
	grey_bg.position = Vector2(-ITEM_SIZE * 0.5, -ITEM_SIZE * 0.5)
	var grey_style: StyleBoxFlat = GameData.candy_circle(GREY_COLOR, ITEM_SIZE * 0.5)
	grey_style.border_color = GREY_BORDER
	grey_style.set_border_width_all(3)
	grey_bg.add_theme_stylebox_override("panel", grey_style)
	grey_bg.material = GameData.create_premium_material(
		0.04, 2.0, 0.0, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
	node.add_child(grey_bg)
	## Кольорове тло (схований — розкривається при фарбуванні)
	var color_bg: Panel = Panel.new()
	color_bg.size = Vector2(ITEM_SIZE, ITEM_SIZE)
	color_bg.position = Vector2(-ITEM_SIZE * 0.5, -ITEM_SIZE * 0.5)
	var color_style: StyleBoxFlat = GameData.candy_circle(c.color, ITEM_SIZE * 0.5)
	color_style.border_color = Color(1, 1, 1, 0.5)
	color_style.set_border_width_all(3)
	color_bg.add_theme_stylebox_override("panel", color_style)
	color_bg.material = GameData.create_premium_material(
		0.04, 2.0, 0.0, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
	color_bg.modulate.a = 0.0  ## Початково сховано — LAW 1: grayscale state
	node.add_child(color_bg)
	## Форма поверх (біла, видима на обох фонах) (LAW 25: shape + color)
	var shape_id: String = c.get("shape", "circle")
	var shape_overlay: Control = _create_shape_overlay(shape_id, ITEM_SIZE * 0.55)
	shape_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape_overlay.position = Vector2(-ITEM_SIZE * 0.275, -ITEM_SIZE * 0.275)
	node.add_child(shape_overlay)
	## CB паттерн overlay (LAW 25)
	if SettingsManager.color_blind_mode:
		var pat: String = GameData.get_cb_pattern(c.id)
		if not pat.is_empty():
			var cb_dot: Control = IconDraw.color_dot_cb(24.0, Color(1, 1, 1, 0.5), pat)
			cb_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cb_dot.position = Vector2(-12.0, -12.0)
			node.add_child(cb_dot)
	_items.append(node)
	_all_round_nodes.append(node)
	_item_color_layers[node] = color_bg
	return node


## Створити іконку форми для відра (кольорова)
func _create_shape_icon(shape_id: String, size: float, color: Color) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.size = Vector2(size, size)
	var half: float = size * 0.5
	var r: float = size * 0.4
	ctrl.draw.connect(func() -> void:
		_draw_shape(ctrl, shape_id, Vector2(half, half), r, color)
	)
	return ctrl


## Створити overlay форми для предмета (біла, напівпрозора)
func _create_shape_overlay(shape_id: String, size: float) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.size = Vector2(size, size)
	var half: float = size * 0.5
	var r: float = size * 0.38
	ctrl.draw.connect(func() -> void:
		_draw_shape(ctrl, shape_id, Vector2(half, half), r, Color(1, 1, 1, 0.85))
	)
	return ctrl


## Малювати геометричну фігуру на CanvasItem
func _draw_shape(ci: CanvasItem, shape_id: String, center: Vector2, radius: float,
		color: Color) -> void:
	match shape_id:
		"star":
			_draw_star(ci, center, radius, color)
		"diamond":
			_draw_diamond(ci, center, radius, color)
		"circle":
			ci.draw_arc(center, radius, 0, TAU, 32, color, maxf(radius * 0.18, 2.0), true)
			ci.draw_circle(center, radius * 0.35, color)
		"heart":
			_draw_heart(ci, center, radius, color)
		"triangle":
			_draw_triangle(ci, center, radius, color)
		_:
			ci.draw_circle(center, radius, color)


func _draw_star(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var angle: float = -PI * 0.5 + TAU * float(i) / 10.0
		var r: float = radius if i % 2 == 0 else radius * 0.45
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	ci.draw_colored_polygon(points, color)


func _draw_diamond(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(center + Vector2(0, -radius))       ## Верх
	points.append(center + Vector2(radius * 0.65, 0))  ## Право
	points.append(center + Vector2(0, radius))          ## Низ
	points.append(center + Vector2(-radius * 0.65, 0))  ## Ліво
	ci.draw_colored_polygon(points, color)


func _draw_heart(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 32
	for i: int in steps:
		var t: float = TAU * float(i) / float(steps)
		## Параметрична формула серця
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(center + Vector2(x, y) * radius / 18.0)
	ci.draw_colored_polygon(points, color)


func _draw_triangle(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 3:
		var angle: float = -PI * 0.5 + TAU * float(i) / 3.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	ci.draw_colored_polygon(points, color)


## ---- Input & drag ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _dragged:
			_try_pick()
		elif not event.pressed and _dragged:
			_try_drop()
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed and not _dragged:
			_try_pick()
		elif not event.pressed and _dragged:
			_try_drop()


func _process(delta: float) -> void:
	## Конвеєр — рух тільки для Preschool
	if not _is_toddler and not _game_over:
		var vp_w: float = get_viewport().get_visible_rect().size.x
		for item: Node2D in _items:
			if not is_instance_valid(item) or item == _dragged:
				continue
			item.position.x += _current_conveyor_speed * delta
			## Предмет доїхав до кінця -> повертаємо на початок
			if item.position.x > vp_w + ITEM_SIZE:
				item.position.x = -ITEM_SIZE
				_item_origins[item] = item.position
	## Drag processing
	if not _dragged:
		return
	var mouse: Vector2 = get_global_mouse_position()
	_drag_velocity = (mouse - _last_mouse) / maxf(delta, 0.001)
	_last_mouse = mouse
	_dragged.global_position = mouse + _drag_offset
	var rot: float = clampf(_drag_velocity.x * TILT_FACTOR, -TILT_MAX, TILT_MAX)
	_dragged.rotation = lerpf(_dragged.rotation, rot, TILT_LERP * delta)
	## Підсвітка відер при наведенні
	for bucket: Dictionary in _buckets:
		var p: Panel = bucket.get("panel", null) as Panel
		if not p:
			continue
		if bucket.get("rect", Rect2()).has_point(_dragged.global_position):
			p.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			p.modulate = Color.WHITE


func _try_pick() -> void:
	var mouse: Vector2 = get_global_mouse_position()
	var best: Node2D = null
	var pick_r: float = TODDLER_SNAP_RADIUS if _is_toddler else PICK_RADIUS
	var best_dist: float = pick_r
	for item: Node2D in _items:
		if not is_instance_valid(item):
			continue
		var d: float = mouse.distance_to(item.global_position)
		if d < best_dist:
			best_dist = d
			best = item
	if not best:
		return
	_dragged = best
	_drag_offset = best.global_position - mouse
	_drag_original_z = best.z_index
	_last_mouse = mouse
	_drag_velocity = Vector2.ZERO
	best.z_index = 10
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	if not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween()
		tw.tween_property(best, "scale", Vector2(0.85, 1.15), 0.06)
		tw.tween_property(best, "scale", Vector2.ONE, 0.06)


func _try_drop() -> void:
	if not _dragged:
		return
	var item: Node2D = _dragged
	var drop_pos: Vector2 = item.global_position
	_dragged = null
	item.z_index = _drag_original_z
	## Squish при кидку
	if not SettingsManager.reduced_motion:
		var sq: Tween = _create_game_tween()
		sq.tween_property(item, "scale", Vector2(1.2, 0.8), 0.06)
		sq.tween_property(item, "scale", Vector2.ONE, 0.08)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## Скинути підсвітку всіх відер
	for bucket: Dictionary in _buckets:
		var p: Panel = bucket.get("panel", null) as Panel
		if p:
			p.modulate = Color.WHITE
	## Перевірити кожне відро
	for bucket: Dictionary in _buckets:
		if bucket.get("rect", Rect2()).has_point(drop_pos):
			if _item_color_id.get(item, "") == bucket.get("color_id", ""):
				_handle_paint_correct(item, bucket)
			else:
				_handle_paint_wrong(item, bucket)
			return
	## Magnetic assist для тоддлерів — snap до найближчого відра
	if _is_toddler:
		var nearest_bucket: Dictionary = {}
		var nearest_dist: float = TODDLER_SNAP_RADIUS
		for bucket: Dictionary in _buckets:
			var center: Vector2 = bucket.get("rect", Rect2()).get_center()
			var d: float = drop_pos.distance_to(center)
			if d < nearest_dist:
				nearest_dist = d
				nearest_bucket = bucket
		if not nearest_bucket.is_empty():
			if _item_color_id.get(item, "") == nearest_bucket.get("color_id", ""):
				_handle_paint_correct(item, nearest_bucket)
			else:
				_handle_paint_wrong(item, nearest_bucket)
			return
	_snap_back(item)


## ---- Feedback: правильне фарбування ----

func _handle_paint_correct(item: Node2D, bucket: Dictionary) -> void:
	_register_correct(item)
	_items.erase(item)
	_sorted_count += 1
	_paint_count += 1
	## Відро підстрибує
	if not SettingsManager.reduced_motion:
		var panel: Panel = bucket.get("panel", null) as Panel
		if panel:
			var orig_y: float = panel.position.y
			var tw_b: Tween = _create_game_tween()
			tw_b.tween_property(panel, "position:y", orig_y - 15.0, 0.1)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_b.tween_property(panel, "position:y", orig_y, 0.15)\
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	## Анімація фарбування: сірий -> кольоровий (LAW 1 reveal)
	var color_layer: Panel = _item_color_layers.get(item, null) as Panel
	if SettingsManager.reduced_motion:
		if is_instance_valid(color_layer):
			color_layer.modulate.a = 1.0
		_after_paint_complete(item)
		return
	## Splash VFX на позиції предмета
	var splash_color: Color = _get_color_by_id(bucket.get("color_id", ""))
	VFXManager.spawn_success_ripple(item.global_position, splash_color)
	## Плавне розкриття кольору
	if is_instance_valid(color_layer):
		var reveal_tw: Tween = _create_game_tween()
		reveal_tw.tween_property(color_layer, "modulate:a", 1.0, PAINT_REVEAL_DURATION)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		## Кожен DANCE_EVERY_N-й — танець (bounce + spin) перед зникненням
		if _paint_count % DANCE_EVERY_N == 0:
			reveal_tw.tween_callback(_animate_dance.bind(item))
		else:
			reveal_tw.tween_callback(_animate_fly_away.bind(item))
	else:
		_after_paint_complete(item)


## Танцювальна анімація для кожного N-го предмета
func _animate_dance(item: Node2D) -> void:
	if not is_instance_valid(item):
		_after_paint_complete(item)
		return
	var tw: Tween = _create_game_tween()
	## Bounce вверх-вниз 3 рази
	var orig_y: float = item.position.y
	@warning_ignore("unused_variable")
	for bounce_i: int in 3:
		tw.tween_property(item, "position:y", orig_y - 25.0, 0.1)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(item, "position:y", orig_y, 0.1)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	## Спін
	tw.parallel().tween_property(item, "rotation_degrees", 360.0, 0.6)\
		.from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	## Зникнення після танцю
	tw.tween_callback(_animate_fly_away.bind(item))


## Предмет летить до "мольберту" (правий верхній кут) та зникає
func _animate_fly_away(item: Node2D) -> void:
	if not is_instance_valid(item):
		_after_paint_complete(item)
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var corner: Vector2 = Vector2(vp.x - 60.0, 60.0)
	var tw: Tween = _create_game_tween()
	tw.tween_property(item, "global_position", corner, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(item, "scale", Vector2(0.2, 0.2), 0.3)
	tw.parallel().tween_property(item, "rotation_degrees", 360.0, 0.3)
	tw.tween_property(item, "modulate:a", 0.0, 0.1)
	tw.tween_callback(func() -> void:
		_item_color_id.erase(item)
		_item_origins.erase(item)
		_item_color_layers.erase(item)
		if is_instance_valid(item):
			item.queue_free())
	## VFX sparkle на мольберті (LAW 28)
	VFXManager.spawn_correct_sparkle(corner)
	tw.tween_callback(func() -> void: _after_paint_complete(item))


## Перевірка завершення раунду після зникнення предмета
func _after_paint_complete(_item: Node2D) -> void:
	if _sorted_count >= _total_items:
		_on_round_complete()
	else:
		_reset_idle_timer()


## ---- Feedback: неправильне фарбування ----

func _handle_paint_wrong(item: Node2D, bucket: Dictionary) -> void:
	if not _is_toddler:
		_errors += 1
		_register_error(item)
	else:
		_register_error(item)  ## A11: scaffolding для тоддлера (без _errors += 1)
	## "Фарба стікає" — короткий кольоровий спалах, потім назад у сірий
	if not SettingsManager.reduced_motion:
		var color_layer: Panel = _item_color_layers.get(item, null) as Panel
		if is_instance_valid(color_layer):
			var wrong_color: Color = _get_color_by_id(bucket.get("color_id", ""))
			## Тимчасово показати чужий колір через modulate (стікає)
			var wrong_style: StyleBoxFlat = GameData.candy_circle(wrong_color, ITEM_SIZE * 0.5)
			wrong_style.border_color = Color(wrong_color, 0.5)
			wrong_style.set_border_width_all(3)
			color_layer.add_theme_stylebox_override("panel", wrong_style)
			var drip_tw: Tween = _create_game_tween()
			drip_tw.tween_property(color_layer, "modulate:a", 0.6, DRIP_FLASH_DURATION * 0.3)
			drip_tw.tween_property(color_layer, "modulate:a", 0.0, DRIP_FLASH_DURATION * 0.7)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			drip_tw.tween_callback(func() -> void:
				if is_instance_valid(color_layer):
					## Відновити правильний кольоровий стиль для майбутнього фарбування
					var correct_id: String = _item_color_id.get(item, "")
					var correct_color: Color = _get_color_by_id(correct_id)
					var correct_style: StyleBoxFlat = GameData.candy_circle(correct_color, ITEM_SIZE * 0.5)
					correct_style.border_color = Color(1, 1, 1, 0.5)
					correct_style.set_border_width_all(3)
					color_layer.add_theme_stylebox_override("panel", correct_style))
	_snap_back(item)


func _snap_back(item: Node2D) -> void:
	if not _item_origins.has(item):
		push_warning("ColorConveyor: _snap_back — _item_origins не містить item")
		return
	if SettingsManager.reduced_motion:
		item.position = _item_origins[item]
		item.rotation = 0.0
		return
	var tw: Tween = _create_game_tween()
	tw.tween_property(item, "position", _item_origins[item], 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "rotation", 0.0, 0.15)


## ---- Допоміжна функція: колір за ID ----

func _get_color_by_id(color_id: String) -> Color:
	for entry: Dictionary in PALETTE:
		if entry.get("id", "") == color_id:
			return entry.color
	for entry: Dictionary in PALETTE_EXTRA:
		if entry.get("id", "") == color_id:
			return entry.color
	push_warning("ColorConveyor: _get_color_by_id — unknown id: " + color_id)
	return GREY_COLOR


## ---- Управління раундами ----

func _on_round_complete() -> void:
	_input_locked = true
	_play_round_celebration()
	## "Шедевр" лейбл
	if not SettingsManager.reduced_motion:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var master_lbl: Label = Label.new()
		master_lbl.text = tr("PAINTER_MASTERPIECE")
		master_lbl.add_theme_font_size_override("font_size", 36)
		master_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1.0))
		master_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		master_lbl.position = Vector2(vp.x * 0.2, vp.y * 0.4)
		master_lbl.size = Vector2(vp.x * 0.6, 50)
		master_lbl.scale = Vector2.ZERO
		add_child(master_lbl)
		var m_tw: Tween = _create_game_tween()
		m_tw.tween_property(master_lbl, "scale", Vector2(1.2, 1.2), 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		m_tw.tween_property(master_lbl, "scale", Vector2.ONE, 0.15)
		m_tw.tween_interval(0.5)
		m_tw.tween_property(master_lbl, "modulate:a", 0.0, 0.3)
		m_tw.tween_callback(master_lbl.queue_free)
	## Записати помилки раунду для адаптивної складності
	_record_round_errors(_errors)
	var d: float = 0.15 if SettingsManager.reduced_motion else 1.2
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


func _clear_round() -> void:
	## LAW 9 + LAW 11: erase з dict ПЕРЕД queue_free
	for node: Node in _all_round_nodes:
		_item_color_id.erase(node)
		_item_origins.erase(node)
		_item_color_layers.erase(node)
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_items.clear()
	_item_color_id.clear()
	_item_origins.clear()
	_item_color_layers.clear()


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": TOTAL_ROUNDS, "earned_stars": earned})


## ---- Idle hint ----

func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over or _items.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	for item: Node2D in _items:
		if is_instance_valid(item):
			_pulse_node(item, 1.15)
			break
	_reset_idle_timer()
