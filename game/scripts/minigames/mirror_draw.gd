extends BaseMiniGame

## ECE-34 "Дзеркальне малювання / Mirror Draw" — домалюй дзеркальну половинку!
## Narrative: чарівне дзеркало розбилось! Половинки зображень зникли. Допоможи відновити!
## Toddler: 3 раунди, товстий пензель (20px), auto-mirror, завжди 5 зірок.
## Preschool: 5 раундів, тонший пензель (12px), dot-to-dot, оцінка за точність.

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 5
const BRUSH_TODDLER: float = 20.0
const BRUSH_PRESCHOOL: float = 12.0
const IDLE_HINT_DELAY: float = 6.0
const SAFETY_TIMEOUT_SEC: float = 300.0  ## Креативна гра — довший timeout (LAW 14)
const MIN_POINTS_DRAWN: int = 8  ## Мінімум точок для завершення раунду
const GUIDE_DOT_RADIUS: float = 8.0
const GUIDE_DOT_HIT_RADIUS_T: float = 40.0  ## Toddler tolerance (A3)
const GUIDE_DOT_HIT_RADIUS_P: float = 20.0  ## Preschool tolerance (A3)
const MIRROR_LINE_WIDTH: float = 3.0
const TEMPLATE_LINE_WIDTH: float = 4.0
const TEMPLATE_ALPHA: float = 0.35  ## Прозорість шаблону зліва
const DONE_MIN_COVERAGE_T: float = 0.3  ## Toddler: 30% покриття для "Done"
const DONE_MIN_COVERAGE_P: float = 0.5  ## Preschool: 50% покриття
## Кольори малювання (веселка — для кожного раунду свій)
const DRAW_COLORS: Array[Color] = [
	Color("ef476f"), Color("06d6a0"), Color("118ab2"),
	Color("ffd166"), Color("a78bfa"), Color("fb923c"),
	Color("38bdf8"), Color("f472b6"), Color("4ecdc4"), Color("e599f7"),
]
## Колір шаблону (ліва половина)
const TEMPLATE_COLOR: Color = Color(0.6, 0.5, 0.9, 0.5)
## Колір дзеркальних штрихів
const MIRROR_STROKE_COLOR: Color = Color(0.5, 0.8, 1.0, 0.7)

## 10+ шаблонів — кожен масив точок відносно center_y, нормалізовано [0..1] по ширині правої половини.
## Точки задані як Array[Vector2] в normalized space: x=[0..1] (від центру до правого краю),
## y=[0..1] (від верху до низу ігрової зони).
## Під час гри конвертуються в екранні координати.
const TEMPLATE_NAMES: Array[String] = [
	"butterfly", "face", "tree", "house", "star",
	"heart", "snowflake", "flower", "car", "cat",
]

## Назви шаблонів для tr() — ключі перекладу
const TEMPLATE_TR_KEYS: Array[String] = [
	"MIRROR_DRAW_BUTTERFLY", "MIRROR_DRAW_FACE", "MIRROR_DRAW_TREE",
	"MIRROR_DRAW_HOUSE", "MIRROR_DRAW_STAR", "MIRROR_DRAW_HEART",
	"MIRROR_DRAW_SNOWFLAKE", "MIRROR_DRAW_FLOWER", "MIRROR_DRAW_CAR",
	"MIRROR_DRAW_CAT",
]

var _is_toddler: bool = false
var _round: int = 0
var _total_rounds: int = 0
var _start_time: float = 0.0

## Малювання
var _drawing: bool = false
var _current_line: Line2D = null
var _mirror_line: Line2D = null
var _strokes: Array[Line2D] = []
var _mirror_strokes: Array[Line2D] = []
var _draw_color: Color = Color.WHITE
var _brush_width: float = 20.0

## Геометрія
var _center_x: float = 640.0  ## Вертикальна вісь симетрії
var _play_area_top: float = 100.0
var _play_area_bottom: float = 650.0

## Шаблон та guide dots
var _template_points: Array[Vector2] = []  ## Точки шаблону в екранних координатах (ліва половина)
var _guide_dots: Array[Node2D] = []  ## Dot nodes на правій половині (Preschool)
var _dots_hit: Array[bool] = []  ## Які dots вже покриті малюванням
var _template_line_node: Line2D = null  ## Лінія шаблону зліва
var _mirror_line_visual: Line2D = null  ## Вертикальна лінія дзеркала

## Canvas та вузли
var _canvas: Node2D = null
var _done_btn: Button = null
var _all_round_nodes: Array[Node] = []
var _used_templates: Array[int] = []  ## Для уникнення повторів

## Preschool: точність
var _total_guide_dots: int = 0
var _dots_covered: int = 0

var _idle_timer: SceneTreeTimer = null


func _ready() -> void:
	game_id = "mirror_draw"
	_skill_id = "spatial_symmetry"
	bg_theme = "puzzle"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_center_x = vp.x * 0.5
	_play_area_top = _sa_top + 90.0
	_play_area_bottom = vp.y - 80.0
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("MIRROR_DRAW_TUTORIAL_TODDLER")
	return tr("MIRROR_DRAW_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	## Tutorial hand: малюємо на правій половині
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return {"type": "swipe", "from": Vector2(_center_x + 80.0, vp.y * 0.35),
		"to": Vector2(_center_x + 200.0, vp.y * 0.55)}


func _build_hud() -> void:
	_build_instruction_pill(tr("MIRROR_DRAW_NARRATIVE"), 24)


## ---- Генерація шаблонів ----

## Повертає масив точок для шаблону (нормалізовані координати [0..1])
## x: відстань від дзеркала (0=центр, 1=край), y: вертикальна позиція (0=верх, 1=низ)
func _get_template_points(template_name: String) -> Array[Vector2]:
	match template_name:
		"butterfly":
			return [
				Vector2(0.05, 0.3), Vector2(0.15, 0.15), Vector2(0.35, 0.1),
				Vector2(0.55, 0.18), Vector2(0.65, 0.3), Vector2(0.55, 0.42),
				Vector2(0.35, 0.48), Vector2(0.55, 0.55), Vector2(0.65, 0.68),
				Vector2(0.5, 0.78), Vector2(0.3, 0.82), Vector2(0.15, 0.75),
				Vector2(0.05, 0.6),
			]
		"face":
			return [
				Vector2(0.05, 0.35), Vector2(0.1, 0.2), Vector2(0.25, 0.1),
				Vector2(0.45, 0.08), Vector2(0.6, 0.15), Vector2(0.65, 0.3),
				Vector2(0.6, 0.5), Vector2(0.55, 0.65), Vector2(0.4, 0.78),
				Vector2(0.25, 0.85), Vector2(0.1, 0.75), Vector2(0.05, 0.55),
			]
		"tree":
			return [
				Vector2(0.05, 0.85), Vector2(0.05, 0.65), Vector2(0.3, 0.55),
				Vector2(0.15, 0.5), Vector2(0.4, 0.38), Vector2(0.2, 0.32),
				Vector2(0.45, 0.2), Vector2(0.25, 0.15), Vector2(0.1, 0.08),
			]
		"house":
			return [
				Vector2(0.05, 0.85), Vector2(0.05, 0.45), Vector2(0.15, 0.45),
				Vector2(0.4, 0.45), Vector2(0.4, 0.85), Vector2(0.4, 0.45),
				Vector2(0.55, 0.3), Vector2(0.45, 0.18), Vector2(0.2, 0.08),
				Vector2(0.05, 0.18),
			]
		"star":
			return [
				Vector2(0.05, 0.42), Vector2(0.25, 0.38), Vector2(0.35, 0.12),
				Vector2(0.45, 0.38), Vector2(0.7, 0.42), Vector2(0.5, 0.58),
				Vector2(0.55, 0.82), Vector2(0.35, 0.68), Vector2(0.1, 0.82),
				Vector2(0.2, 0.58),
			]
		"heart":
			return [
				Vector2(0.05, 0.4), Vector2(0.05, 0.25), Vector2(0.15, 0.12),
				Vector2(0.3, 0.1), Vector2(0.45, 0.18), Vector2(0.55, 0.3),
				Vector2(0.5, 0.48), Vector2(0.35, 0.65), Vector2(0.15, 0.82),
				Vector2(0.05, 0.9),
			]
		"snowflake":
			return [
				Vector2(0.05, 0.5), Vector2(0.2, 0.42), Vector2(0.15, 0.28),
				Vector2(0.2, 0.42), Vector2(0.4, 0.35), Vector2(0.5, 0.2),
				Vector2(0.4, 0.35), Vector2(0.55, 0.5), Vector2(0.4, 0.65),
				Vector2(0.55, 0.5), Vector2(0.2, 0.58), Vector2(0.15, 0.72),
				Vector2(0.2, 0.58), Vector2(0.05, 0.5),
			]
		"flower":
			return [
				Vector2(0.05, 0.85), Vector2(0.05, 0.6), Vector2(0.15, 0.52),
				Vector2(0.05, 0.45), Vector2(0.15, 0.35), Vector2(0.3, 0.3),
				Vector2(0.4, 0.2), Vector2(0.35, 0.35), Vector2(0.45, 0.45),
				Vector2(0.35, 0.52), Vector2(0.15, 0.52),
			]
		"car":
			return [
				Vector2(0.05, 0.65), Vector2(0.05, 0.5), Vector2(0.15, 0.5),
				Vector2(0.25, 0.35), Vector2(0.45, 0.3), Vector2(0.6, 0.35),
				Vector2(0.65, 0.5), Vector2(0.7, 0.5), Vector2(0.7, 0.65),
				Vector2(0.55, 0.65), Vector2(0.45, 0.72), Vector2(0.35, 0.65),
				Vector2(0.15, 0.65), Vector2(0.1, 0.72),
			]
		"cat":
			return [
				Vector2(0.05, 0.55), Vector2(0.05, 0.35), Vector2(0.1, 0.2),
				Vector2(0.2, 0.08), Vector2(0.3, 0.18), Vector2(0.35, 0.3),
				Vector2(0.45, 0.25), Vector2(0.55, 0.3), Vector2(0.5, 0.42),
				Vector2(0.4, 0.48), Vector2(0.3, 0.55), Vector2(0.25, 0.7),
				Vector2(0.15, 0.82), Vector2(0.05, 0.85),
			]
		_:
			push_warning("MirrorDraw: unknown template '%s', fallback to butterfly" % template_name)
			return _get_template_points("butterfly")
	## Unreachable — кожна гілка match вже повертає значення
	return []


## Конвертувати нормалізовану точку в екранні координати (ЛІВА половина)
func _normalized_to_screen_left(p: Vector2) -> Vector2:
	var half_w: float = _center_x
	var area_h: float = _play_area_bottom - _play_area_top
	## Ліва сторона: x від центру до лівого краю (інвертовано)
	var screen_x: float = _center_x - p.x * half_w * 0.85
	var screen_y: float = _play_area_top + p.y * area_h
	return Vector2(screen_x, screen_y)


## Конвертувати нормалізовану точку в екранні координати (ПРАВА половина — guide dots)
func _normalized_to_screen_right(p: Vector2) -> Vector2:
	var half_w: float = _center_x
	var area_h: float = _play_area_bottom - _play_area_top
	## Права сторона: x від центру до правого краю
	var screen_x: float = _center_x + p.x * half_w * 0.85
	var screen_y: float = _play_area_top + p.y * area_h
	return Vector2(screen_x, screen_y)


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_drawing = false
	_strokes.clear()
	_mirror_strokes.clear()
	_guide_dots.clear()
	_dots_hit.clear()
	_dots_covered = 0
	_total_guide_dots = 0
	_current_line = null
	_mirror_line = null

	## A4: прогресивна складність
	_brush_width = _scale_adaptive(
		BRUSH_TODDLER if _is_toddler else BRUSH_PRESCHOOL,
		(BRUSH_TODDLER * 0.7) if _is_toddler else (BRUSH_PRESCHOOL * 0.7),
		_round, _total_rounds)
	_draw_color = DRAW_COLORS[_round % DRAW_COLORS.size()]

	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	_fade_instruction(_instruction_label, get_tutorial_instruction())

	## Вибрати шаблон (без повторів у сесії)
	var template_name: String = _pick_template()
	_template_points = _get_template_points(template_name)

	if _template_points.is_empty():
		push_warning("MirrorDraw: template '%s' has no points — skipping round" % template_name)
		call_deferred("_skip_round")
		return

	## Створити canvas
	_canvas = Node2D.new()
	add_child(_canvas)
	_all_round_nodes.append(_canvas)

	## Намалювати вертикальну лінію дзеркала
	_spawn_mirror_line()

	## Намалювати шаблон зліва
	_spawn_template_left()

	## Preschool: guide dots на правій половині
	if not _is_toddler:
		_spawn_guide_dots()

	## Кнопка "Готово"
	_spawn_done_button()

	## Orchestrated entrance
	_orchestrated_entrance(_all_round_nodes as Array, 0.06, false, "pop")

	## Unlock input після входу
	var unlock_d: float = 0.15 if SettingsManager.reduced_motion else 0.55
	var tw: Tween = _create_game_tween()
	tw.tween_interval(unlock_d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _pick_template() -> String:
	if _used_templates.size() >= TEMPLATE_NAMES.size():
		_used_templates.clear()
	var idx: int = randi() % TEMPLATE_NAMES.size()
	var attempts: int = 0
	while _used_templates.has(idx) and attempts < 30:
		idx = randi() % TEMPLATE_NAMES.size()
		attempts += 1
	_used_templates.append(idx)
	return TEMPLATE_NAMES[idx]


## Вертикальна дзеркальна лінія по центру
func _spawn_mirror_line() -> void:
	_mirror_line_visual = Line2D.new()
	_mirror_line_visual.width = MIRROR_LINE_WIDTH
	_mirror_line_visual.default_color = Color(1, 1, 1, 0.4)
	_mirror_line_visual.add_point(Vector2(_center_x, _play_area_top - 20.0))
	_mirror_line_visual.add_point(Vector2(_center_x, _play_area_bottom + 20.0))
	## Пунктирна лінія — через сегменти
	_mirror_line_visual.antialiased = true
	_canvas.add_child(_mirror_line_visual)
	_all_round_nodes.append(_mirror_line_visual)


## Шаблон на лівій половині — напівпрозора лінія
func _spawn_template_left() -> void:
	_template_line_node = Line2D.new()
	_template_line_node.width = TEMPLATE_LINE_WIDTH
	_template_line_node.default_color = TEMPLATE_COLOR
	_template_line_node.joint_mode = Line2D.LINE_JOINT_ROUND
	_template_line_node.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_template_line_node.end_cap_mode = Line2D.LINE_CAP_ROUND
	_template_line_node.antialiased = true
	## Конвертувати нормалізовані точки в екранні (ліва половина)
	for p: Vector2 in _template_points:
		var screen_p: Vector2 = _normalized_to_screen_left(p)
		_template_line_node.add_point(screen_p)
	## A4: зменшити alpha в пізніших раундах (складніше зрозуміти шаблон)
	var alpha: float = _scale_adaptive(TEMPLATE_ALPHA, TEMPLATE_ALPHA * 0.5, _round, _total_rounds)
	_template_line_node.default_color.a = alpha
	_canvas.add_child(_template_line_node)
	_all_round_nodes.append(_template_line_node)


## Guide dots на правій половині (Preschool: dot-to-dot)
func _spawn_guide_dots() -> void:
	## A4: менше dots = складніше (потрібно здогадуватись де малювати)
	var dot_count: int = _template_points.size()
	## В останніх раундах показуємо менше dots
	var show_ratio: float = _scale_adaptive(1.0, 0.5, _round, _total_rounds)
	var dots_to_show: int = maxi(int(float(dot_count) * show_ratio), 3)  ## LAW 13: мінімум 3
	## Визначити які точки показувати (рівномірно розподілені)
	var step: float = float(dot_count) / maxf(float(dots_to_show), 1.0)  ## LAW 13
	var shown_indices: Array[int] = []
	var fi: float = 0.0
	while shown_indices.size() < dots_to_show and fi < float(dot_count):
		var idx: int = mini(int(fi), dot_count - 1)
		if not shown_indices.has(idx):
			shown_indices.append(idx)
		fi += step

	_total_guide_dots = shown_indices.size()
	_dots_hit.resize(_total_guide_dots)
	for i: int in _total_guide_dots:
		_dots_hit[i] = false

	for di: int in shown_indices.size():
		if shown_indices[di] < 0 or shown_indices[di] >= _template_points.size():
			continue  ## LAW 13: bounds check
		var norm_p: Vector2 = _template_points[shown_indices[di]]
		var screen_p: Vector2 = _normalized_to_screen_right(norm_p)
		var dot: Node2D = _create_guide_dot(screen_p, di)
		_canvas.add_child(dot)
		_guide_dots.append(dot)
		_all_round_nodes.append(dot)


## Створити guide dot — коло з пульсуючою анімацією
func _create_guide_dot(pos: Vector2, index: int) -> Node2D:
	var dot: Node2D = Node2D.new()
	dot.position = pos
	dot.set_meta("dot_index", index)

	## Dots рендеряться через MirrorDraw._draw() — Node2D тільки для позиції
	dot.set_meta("radius", GUIDE_DOT_RADIUS)
	dot.set_meta("color", Color(1, 1, 1, 0.6))
	dot.z_index = 5

	## Pulse анімація для dot (A10: idle hint)
	if not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween()
		tw.set_loops()
		tw.tween_property(dot, "scale", Vector2(1.2, 1.2), 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) \
			.set_delay(float(index) * 0.1)
		tw.tween_property(dot, "scale", Vector2.ONE, 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	return dot


## Кнопка "Готово" — з'являється після достатнього покриття
func _spawn_done_button() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var s: float = _ui_scale()
	_done_btn = Button.new()
	_done_btn.theme_type_variation = &"SecondaryButton"
	IconDraw.icon_in_button(_done_btn, IconDraw.checkmark(28.0 * s))
	_done_btn.size = Vector2(70.0 * s, 70.0 * s)
	_done_btn.position = Vector2(vp.x - 90.0 * s, _play_area_bottom - 60.0 * s)
	_done_btn.visible = false
	_done_btn.pressed.connect(_on_done_pressed)
	add_child(_done_btn)
	JuicyEffects.button_press_squish(_done_btn, self)
	_all_round_nodes.append(_done_btn)


## ---- Input: малювання ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	var pos: Vector2 = Vector2.ZERO
	var pressed: bool = false
	var released: bool = false
	if event is InputEventMouseButton:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion and _drawing:
		_add_point(event.position)
		return
	elif event is InputEventScreenDrag and _drawing and event.index == 0:
		_add_point(event.position)
		return
	else:
		return
	## Обмежити малювання правою половиною
	if pressed and pos.x > _center_x:
		_start_stroke(pos)
	elif released and _drawing:
		_end_stroke()


func _start_stroke(pos: Vector2) -> void:
	if not is_instance_valid(_canvas):
		push_warning("MirrorDraw: _start_stroke called without valid canvas")
		return
	_drawing = true
	## Штрих гравця (права половина)
	_current_line = Line2D.new()
	_current_line.width = _brush_width
	_current_line.default_color = _draw_color
	_current_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_current_line.antialiased = true
	_current_line.z_index = 10
	_current_line.add_point(pos)
	_canvas.add_child(_current_line)

	## Дзеркальний штрих (ліва половина) — auto-mirror
	_mirror_line = Line2D.new()
	_mirror_line.width = _brush_width
	_mirror_line.default_color = MIRROR_STROKE_COLOR if not _is_toddler else _draw_color
	_mirror_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_mirror_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_mirror_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_mirror_line.antialiased = true
	_mirror_line.z_index = 10
	var mirror_pos: Vector2 = _mirror_point(pos)
	_mirror_line.add_point(mirror_pos)
	_canvas.add_child(_mirror_line)

	## Audio: pop при кожному штриху
	AudioManager.play_sfx_varied("pop", 0.2)
	HapticsManager.vibrate_light()


func _add_point(pos: Vector2) -> void:
	if not _drawing or not is_instance_valid(_current_line):
		push_warning("MirrorDraw: _add_point called without active stroke")
		return

	## Обмежити позицію правою половиною
	pos.x = maxf(pos.x, _center_x + 5.0)

	## LAW 13: обмежити кількість точок (performance)
	if _current_line.get_point_count() >= 500:
		_end_stroke()
		_start_stroke(pos)
		return

	## Мінімальна відстань між точками для плавності
	if _current_line.get_point_count() > 0:
		var last: Vector2 = _current_line.get_point_position(
			_current_line.get_point_count() - 1)
		if pos.distance_to(last) < 4.0:
			return

	_current_line.add_point(pos)

	## Дзеркальна точка
	if is_instance_valid(_mirror_line):
		var mirror_pos: Vector2 = _mirror_point(pos)
		_mirror_line.add_point(mirror_pos)

	## Preschool: перевірити чи покрито guide dot
	if not _is_toddler:
		_check_guide_dot_coverage(pos)

	## Показати кнопку Done після достатнього покриття
	_check_done_visibility()


func _end_stroke() -> void:
	_drawing = false
	if is_instance_valid(_current_line) and _current_line.get_point_count() > 1:
		_strokes.append(_current_line)
	elif is_instance_valid(_current_line):
		_current_line.queue_free()
	if is_instance_valid(_mirror_line) and _mirror_line.get_point_count() > 1:
		_mirror_strokes.append(_mirror_line)
	elif is_instance_valid(_mirror_line):
		_mirror_line.queue_free()
	_current_line = null
	_mirror_line = null
	_reset_idle_timer()


## Дзеркальне відображення точки відносно центральної лінії
func _mirror_point(pos: Vector2) -> Vector2:
	return Vector2(2.0 * _center_x - pos.x, pos.y)


## Preschool: перевірити чи штрих покриває guide dot
func _check_guide_dot_coverage(draw_pos: Vector2) -> void:
	var hit_radius: float = _scale_adaptive(
		GUIDE_DOT_HIT_RADIUS_P, GUIDE_DOT_HIT_RADIUS_P * 0.6,
		_round, _total_rounds)  ## A4: менший radius = складніше
	for i: int in _guide_dots.size():
		if i >= _dots_hit.size():
			break  ## LAW 13: bounds safety
		if _dots_hit[i]:
			continue
		var dot: Node2D = _guide_dots[i]
		if not is_instance_valid(dot):
			continue
		if draw_pos.distance_to(dot.position) <= hit_radius:
			_dots_hit[i] = true
			_dots_covered += 1
			## Feedback: dot зеленіє та зникає
			_animate_dot_hit(dot)
			## Audio: coin SFX при кожному попаданні
			AudioManager.play_sfx_varied("coin", 0.15)
			HapticsManager.vibrate_light()


## Анімація попадання в guide dot
func _animate_dot_hit(dot: Node2D) -> void:
	if not is_instance_valid(dot):
		return
	if SettingsManager.reduced_motion:
		dot.modulate = Color(0.2, 1.0, 0.4, 0.3)
		return
	var tw: Tween = _create_game_tween()
	tw.tween_property(dot, "scale", Vector2(1.5, 1.5), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(dot, "modulate", Color(0.2, 1.0, 0.4, 0.3), 0.2)
	tw.tween_property(dot, "scale", Vector2(0.8, 0.8), 0.2)
	## VFX: маленький sparkle
	VFXManager.spawn_match_sparkle(dot.global_position)


## Перевірити чи достатньо покриття для показу кнопки Done
func _check_done_visibility() -> void:
	if not is_instance_valid(_done_btn) or _done_btn.visible:
		return
	var coverage: float = _get_coverage_ratio()
	var threshold: float = DONE_MIN_COVERAGE_T if _is_toddler else DONE_MIN_COVERAGE_P
	if coverage >= threshold:
		_done_btn.visible = true
		if not SettingsManager.reduced_motion:
			_done_btn.modulate.a = 0.0
			var tw: Tween = _create_game_tween()
			tw.tween_property(_done_btn, "modulate:a", 1.0, 0.3)
		else:
			_done_btn.modulate.a = 1.0


## Підрахувати покриття (0.0 .. 1.0)
func _get_coverage_ratio() -> float:
	if _is_toddler:
		## Toddler: покриття = кількість намальованих точок / MIN_POINTS_DRAWN
		var total_points: int = 0
		for line: Line2D in _strokes:
			if is_instance_valid(line):
				total_points += line.get_point_count()
		return clampf(float(total_points) / float(maxi(MIN_POINTS_DRAWN, 1)), 0.0, 1.0)
	else:
		## Preschool: покриття = dots covered / total dots
		if _total_guide_dots <= 0:
			return 1.0  ## LAW 13: zero guard
		return clampf(float(_dots_covered) / float(_total_guide_dots), 0.0, 1.0)


## ---- Done та раундовий менеджмент ----

func _on_done_pressed() -> void:
	if _input_locked or _game_over:
		return
	_input_locked = true
	_drawing = false
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()

	## Reveal анімація: дзеркальні штрихи яскравіють, шаблон зникає
	_play_reveal_animation()


## Reveal: шаблон зникає, дзеркальні штрихи стають яскравими, малюнок "оживає"
func _play_reveal_animation() -> void:
	if SettingsManager.reduced_motion:
		## Без анімації — одразу далі
		_play_round_celebration(get_viewport().get_visible_rect().size * 0.5)
		var tw: Tween = _create_game_tween()
		tw.tween_interval(0.5)
		tw.tween_callback(_proceed_after_round)
		return

	var tw: Tween = _create_game_tween()

	## 1. Шаблон зникає
	if is_instance_valid(_template_line_node):
		tw.tween_property(_template_line_node, "modulate:a", 0.0, 0.4)

	## 2. Дзеркальні штрихи стають яскравими (якщо Preschool — вони були блідими)
	for ml: Line2D in _mirror_strokes:
		if is_instance_valid(ml):
			tw.parallel().tween_property(ml, "default_color", _draw_color, 0.4)

	## 3. Sparkle celebration
	tw.tween_callback(func() -> void:
		_play_round_celebration(get_viewport().get_visible_rect().size * 0.5))

	## 4. Пауза і перехід
	tw.tween_interval(CELEBRATION_DELAY)
	tw.tween_callback(_proceed_after_round)


func _proceed_after_round() -> void:
	_clear_round()
	_round += 1
	if _round >= _total_rounds:
		_finish()
	else:
		_start_round()


## A8: skip round при проблемах
func _skip_round() -> void:
	push_warning("MirrorDraw: skipping round %d" % _round)
	_clear_round()
	_round += 1
	if _round >= _total_rounds:
		_finish()
	else:
		_start_round()


## A9: раундова гігієна — очистити ВСЕ
func _clear_round() -> void:
	_kill_all_tweens()
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_strokes.clear()
	_mirror_strokes.clear()
	_guide_dots.clear()
	_dots_hit.clear()
	_canvas = null
	_template_line_node = null
	_mirror_line_visual = null
	_done_btn = null
	_current_line = null
	_mirror_line = null
	_drawing = false
	_dots_covered = 0
	_total_guide_dots = 0


func _finish() -> void:
	_game_over = true
	_input_locked = true
	## MasteryManager: запис завершення
	MasteryManager.record_attempt(game_id, _skill_id, true)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	## A5: Toddler — завжди 5. Preschool — creative = завжди 5 (bible spec: "creative, завжди 5")
	var earned: int = _calculate_stars(0)
	finish_game(earned, {"time_sec": elapsed, "errors": 0,
		"rounds_played": _total_rounds, "earned_stars": earned})


## ---- _draw для guide dots (рендеримо кола через _draw) ----

func _draw() -> void:
	## LAW 28 exempt — guide dots are minimal gameplay markers, not premium UI
	## Малюємо guide dots як кола (без зовнішніх текстур)
	for dot: Node2D in _guide_dots:
		if not is_instance_valid(dot):
			continue
		var idx: int = dot.get_meta("dot_index") if dot.has_meta("dot_index") else -1
		if idx < 0:
			continue
		var is_hit: bool = false
		if idx >= 0 and idx < _dots_hit.size():
			is_hit = _dots_hit[idx]
		var color: Color = Color(0.2, 1.0, 0.4, 0.3) if is_hit else Color(1, 1, 1, 0.6)
		## Конвертувати dot.position з global в local (Node2D._draw працює в local space)
		var local_pos: Vector2 = to_local(dot.global_position)
		draw_circle(local_pos, GUIDE_DOT_RADIUS, color)
		## Зовнішнє кільце
		var ring_color: Color = Color(1, 1, 1, 0.25) if not is_hit else Color(0.2, 1.0, 0.4, 0.15)
		draw_arc(local_pos, GUIDE_DOT_RADIUS + 3.0, 0.0, TAU, 32, ring_color, 2.0)


func _process(_delta: float) -> void:
	## Перемалювати dots
	if not _guide_dots.is_empty():
		queue_redraw()


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
	if _input_locked or _game_over:
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	## Підказка: пульсація першого непокритого guide dot або mirror line
	if not _is_toddler and not _guide_dots.is_empty():
		for i: int in _guide_dots.size():
			if i < _dots_hit.size() and not _dots_hit[i]:
				if is_instance_valid(_guide_dots[i]):
					_pulse_node(_guide_dots[i], 1.3)
					break
	elif is_instance_valid(_mirror_line_visual):
		_pulse_node(_mirror_line_visual, 1.1)
	_reset_idle_timer()


## ---- Exit pause: очистити стан малювання ----

func _on_exit_pause() -> void:
	_drawing = false
	_current_line = null
	_mirror_line = null
