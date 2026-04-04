extends BaseMiniGame

## ECE-14 "Лісова тропа / Forest Trail" — проведи тваринку лісовою стежкою!
## 15+ шаблонів шляхів з Bezier-інтерполяцією, scenic spots (водопад, квіти, міст),
## off-trail feedback, perfect run = рідкісний птах.
## Toddler: 3 раунди, широка стежка (80px), без штрафу.
## Preschool: 5 раундів, вужча стежка (50px → 44px), штраф за виходи за межі.

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 5
const PATH_WIDTH_TODDLER: float = 120.0  ## H7: increased from 100→120px for better motor accessibility
const PATH_WIDTH_PRESCHOOL_EASY: float = 50.0
const PATH_WIDTH_PRESCHOOL_HARD: float = 44.0
const TRAIL_WIDTH: float = 10.0
const MARKER_SIZE: float = 40.0
const IDLE_HINT_DELAY: float = 5.0
const WAYPOINT_THRESHOLD: float = 44.0
const SCENIC_SPOT_SIZE: float = 48.0
const SAFETY_TIMEOUT_SEC: float = 120.0
const BEZIER_SEGMENTS: int = 12
const GRASS_TUFT_SPACING: float = 40.0
const OFF_TRAIL_DARKEN_ALPHA: float = 0.18

## Кольори стежки — лісова палітра (LAW 25: не тільки колір розрізняє)
const PATH_COLOR: Color = Color("b5d89a")
const PATH_BORDER_COLOR: Color = Color("6b8e4e")
const TRAIL_COLOR: Color = Color("ffd166")
const START_COLOR: Color = Color("06d6a0")
const END_COLOR: Color = Color("ef476f")
const SCENIC_WATERFALL_COLOR: Color = Color("93c5fd")
const SCENIC_FLOWER_COLOR: Color = Color("f9a8d4")
const SCENIC_BRIDGE_COLOR: Color = Color("d4a574")

const ANIMAL_NAMES: Array[String] = [
	"Bear", "Bunny", "Cat", "Chicken", "Cow", "Crocodile", "Deer",
	"Dog", "Elephant", "Frog", "Goat", "Hedgehog", "Horse",
	"Lion", "Monkey", "Mouse", "Panda", "Penguin", "Squirrel",
]

## 15 шаблонів шляхів (нормалізовані 0..1) — кожен = набір control points для Bezier
const PATH_TEMPLATES: Array[Array] = [
	## --- Прості (4-5 точок, плавні повороти) ---
	[Vector2(0.12, 0.35), Vector2(0.35, 0.25), Vector2(0.55, 0.45), Vector2(0.80, 0.35)],
	[Vector2(0.15, 0.55), Vector2(0.35, 0.35), Vector2(0.60, 0.50), Vector2(0.85, 0.40)],
	[Vector2(0.10, 0.40), Vector2(0.30, 0.60), Vector2(0.55, 0.30), Vector2(0.80, 0.55)],
	[Vector2(0.15, 0.30), Vector2(0.40, 0.50), Vector2(0.65, 0.30), Vector2(0.85, 0.50)],
	[Vector2(0.12, 0.50), Vector2(0.30, 0.30), Vector2(0.50, 0.55), Vector2(0.75, 0.30), Vector2(0.88, 0.50)],
	## --- Середні (5-6 точок, S-криві) ---
	[Vector2(0.10, 0.65), Vector2(0.25, 0.35), Vector2(0.45, 0.60), Vector2(0.65, 0.30), Vector2(0.85, 0.55)],
	[Vector2(0.85, 0.35), Vector2(0.65, 0.55), Vector2(0.45, 0.30), Vector2(0.25, 0.55), Vector2(0.12, 0.40)],
	[Vector2(0.12, 0.45), Vector2(0.30, 0.25), Vector2(0.50, 0.50), Vector2(0.70, 0.25), Vector2(0.88, 0.45)],
	[Vector2(0.15, 0.55), Vector2(0.30, 0.30), Vector2(0.50, 0.60), Vector2(0.70, 0.35), Vector2(0.88, 0.60)],
	[Vector2(0.10, 0.30), Vector2(0.25, 0.55), Vector2(0.40, 0.30), Vector2(0.60, 0.60), Vector2(0.80, 0.35), Vector2(0.90, 0.55)],
	## --- Складні (6-7 точок, петлі) ---
	[Vector2(0.10, 0.50), Vector2(0.25, 0.30), Vector2(0.40, 0.55), Vector2(0.50, 0.25), Vector2(0.65, 0.50), Vector2(0.85, 0.35)],
	[Vector2(0.88, 0.55), Vector2(0.70, 0.30), Vector2(0.55, 0.60), Vector2(0.40, 0.30), Vector2(0.25, 0.55), Vector2(0.10, 0.35)],
	[Vector2(0.12, 0.40), Vector2(0.25, 0.60), Vector2(0.35, 0.30), Vector2(0.50, 0.55), Vector2(0.65, 0.30), Vector2(0.80, 0.55), Vector2(0.90, 0.40)],
	[Vector2(0.15, 0.35), Vector2(0.25, 0.55), Vector2(0.40, 0.25), Vector2(0.55, 0.55), Vector2(0.70, 0.30), Vector2(0.85, 0.55)],
	[Vector2(0.10, 0.55), Vector2(0.20, 0.30), Vector2(0.35, 0.55), Vector2(0.50, 0.30), Vector2(0.65, 0.55), Vector2(0.80, 0.30), Vector2(0.90, 0.50)],
]

## Типи scenic spots (мікро-подій на waypoints)
enum ScenicType { WATERFALL, FLOWER_MEADOW, BRIDGE }

var _is_toddler: bool = false
var _round: int = 0
var _total_rounds: int = 0
var _start_time: float = 0.0
var _was_off_path: bool = false
var _tracing: bool = false
var _path_width: float = 80.0

var _bezier_points: Array[Vector2] = []
var _current_wp: int = 0
var _path_line: Line2D = null
var _path_border: Line2D = null
var _trail_line: Line2D = null
var _mover: Sprite2D = null
var _start_marker: Node2D = null
var _end_marker: Node2D = null
var _darken_overlay: ColorRect = null
var _all_round_nodes: Array[Node] = []
var _scenic_nodes: Array[Node2D] = []
var _scenic_spots: Array[Dictionary] = []
var _used_paths: Array[int] = []
var _used_animals: Array[int] = []
var _grass_tufts: Array[Node2D] = []
var _off_trail_active: bool = false

var _idle_timer: SceneTreeTimer = null


func _ready() -> void:
	game_id = "safe_maze"
	_skill_id = "fine_motor"
	bg_theme = "forest"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_path_width = PATH_WIDTH_TODDLER if _is_toddler else PATH_WIDTH_PRESCHOOL_EASY
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_create_darken_overlay()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("MAZE_TUTORIAL_TODDLER")
	return tr("MAZE_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _bezier_points.size() < 2:
		push_warning("SafeMaze: get_tutorial_demo — not enough bezier points")
		return {}
	return {"type": "drag", "from": _bezier_points[0], "to": _bezier_points[mini(1, _bezier_points.size() - 1)]}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Darken overlay для off-trail ----

func _create_darken_overlay() -> void:
	_darken_overlay = ColorRect.new()
	_darken_overlay.color = Color(0.0, 0.05, 0.0, 0.0)
	_darken_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_darken_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_darken_overlay.z_index = -1
	add_child(_darken_overlay)


## ---- Bezier curve generation ----

func _bezier_interpolate(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t_clamped: float = clampf(t, 0.0, 1.0)
	var u: float = 1.0 - t_clamped
	return u * u * u * p0 + 3.0 * u * u * t_clamped * p1 + 3.0 * u * t_clamped * t_clamped * p2 + t_clamped * t_clamped * t_clamped * p3


func _generate_bezier_path(control_pts: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if control_pts.size() < 2:
		push_warning("SafeMaze: _generate_bezier_path — < 2 control points")
		return result
	if control_pts.size() == 2:
		## Пряма лінія
		for seg: int in BEZIER_SEGMENTS + 1:
			var t: float = float(seg) / float(maxi(BEZIER_SEGMENTS, 1))
			result.append(control_pts[0].lerp(control_pts[1], t))
		return result
	## Catmull-Rom -> Bezier: гладка крива через всі точки
	for i: int in control_pts.size() - 1:
		var p0: Vector2 = control_pts[maxi(i - 1, 0)]
		var p1: Vector2 = control_pts[i]
		var p2: Vector2 = control_pts[mini(i + 1, control_pts.size() - 1)]
		var p3: Vector2 = control_pts[mini(i + 2, control_pts.size() - 1)]
		## Catmull-Rom tangents -> Bezier control points
		var c1: Vector2 = p1 + (p2 - p0) / 6.0
		var c2: Vector2 = p2 - (p3 - p1) / 6.0
		var segments: int = maxi(BEZIER_SEGMENTS, 1)
		for seg: int in segments:
			var t: float = float(seg) / float(segments)
			result.append(_bezier_interpolate(p1, c1, c2, p2, t))
	## Додати останню точку
	result.append(control_pts[control_pts.size() - 1])
	return result


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_current_wp = 0
	_tracing = false
	_was_off_path = false
	_off_trail_active = false
	## A4: Прогресивна складність — стежка звужується в пізніших раундах
	if not _is_toddler:
		_path_width = _scale_adaptive(
			PATH_WIDTH_PRESCHOOL_EASY, PATH_WIDTH_PRESCHOOL_HARD, _round, _total_rounds)
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var template: Array = _pick_path()
	## A4: Складніші шляхи в пізніших раундах — більше точок
	var pts_to_use: int = _scale_adaptive_i(
		maxi(4, template.size() - 2), template.size(), _round, _total_rounds)
	pts_to_use = clampi(pts_to_use, 3, template.size())
	var control_pts: Array[Vector2] = []
	for idx: int in pts_to_use:
		if idx < template.size():
			var pt: Vector2 = template[idx]
			## Безпечна зона: Y від 0.18 до 0.85, щоб не перекривати UI
			control_pts.append(Vector2(
				pt.x * vp.x,
				clampf(pt.y, 0.18, 0.85) * vp.y))
	_bezier_points = _generate_bezier_path(control_pts)
	if _bezier_points.size() < 2:
		push_warning("SafeMaze: Bezier path empty, skipping round")
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round()
		return
	_spawn_path()
	_spawn_grass_tufts()
	_spawn_scenic_spots()
	_spawn_markers()
	_spawn_mover()
	_orchestrated_entrance(_all_round_nodes as Array, 0.04, false, "pop")
	var d: float = ANIM_FAST if SettingsManager.reduced_motion else ANIM_SLOW + 0.1
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_input_locked = false
		_reset_idle_timer())


func _pick_path() -> Array:
	if _used_paths.size() >= PATH_TEMPLATES.size():
		_used_paths.clear()
	var idx: int = randi() % PATH_TEMPLATES.size()
	var attempts: int = 0
	while _used_paths.has(idx) and attempts < PATH_TEMPLATES.size() * 2:
		idx = randi() % PATH_TEMPLATES.size()
		attempts += 1
	_used_paths.append(idx)
	if idx >= 0 and idx < PATH_TEMPLATES.size():
		return PATH_TEMPLATES[idx]
	push_warning("SafeMaze: _pick_path fallback to template 0")
	return PATH_TEMPLATES[0]


func _pick_animal() -> String:
	if _used_animals.size() >= ANIMAL_NAMES.size():
		_used_animals.clear()
	var idx: int = randi() % ANIMAL_NAMES.size()
	var attempts: int = 0
	while _used_animals.has(idx) and attempts < ANIMAL_NAMES.size() * 2:
		idx = randi() % ANIMAL_NAMES.size()
		attempts += 1
	_used_animals.append(idx)
	if idx >= 0 and idx < ANIMAL_NAMES.size():
		return ANIMAL_NAMES[idx]
	push_warning("SafeMaze: _pick_animal fallback")
	return ANIMAL_NAMES[0]


## ---- Візуалізація стежки ----

func _spawn_path() -> void:
	## Бордюр стежки — товщий, темніший, під основною лінією
	_path_border = Line2D.new()
	_path_border.width = _path_width + 8.0
	_path_border.default_color = PATH_BORDER_COLOR
	_path_border.joint_mode = Line2D.LINE_JOINT_ROUND
	_path_border.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_path_border.end_cap_mode = Line2D.LINE_CAP_ROUND
	for wp: Vector2 in _bezier_points:
		_path_border.add_point(wp)
	add_child(_path_border)
	_all_round_nodes.append(_path_border)

	## Основна стежка
	_path_line = Line2D.new()
	_path_line.width = _path_width
	_path_line.default_color = PATH_COLOR
	_path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	for wp: Vector2 in _bezier_points:
		_path_line.add_point(wp)
	add_child(_path_line)
	_all_round_nodes.append(_path_line)

	## Пунктирна центральна лінія (візуальний маркер стежки)
	var center_line: Line2D = Line2D.new()
	center_line.width = 3.0
	center_line.default_color = Color(1, 1, 1, 0.25)
	center_line.joint_mode = Line2D.LINE_JOINT_ROUND
	## Додаємо точки з кроком для "пунктиру"
	var dash_on: bool = true
	for i: int in _bezier_points.size():
		if i % 4 == 0:
			dash_on = not dash_on
		if dash_on and i < _bezier_points.size():
			center_line.add_point(_bezier_points[i])
		elif center_line.get_point_count() > 1:
			add_child(center_line)
			_all_round_nodes.append(center_line)
			center_line = Line2D.new()
			center_line.width = 3.0
			center_line.default_color = Color(1, 1, 1, 0.25)
			center_line.joint_mode = Line2D.LINE_JOINT_ROUND
	if center_line.get_point_count() > 1:
		add_child(center_line)
		_all_round_nodes.append(center_line)

	## Trail — слід, який малює дитина
	_trail_line = Line2D.new()
	_trail_line.width = TRAIL_WIDTH
	_trail_line.default_color = TRAIL_COLOR
	_trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail_line)
	_all_round_nodes.append(_trail_line)


## ---- Трав'яні пучки уздовж стежки (декоративні) ----

func _spawn_grass_tufts() -> void:
	_grass_tufts.clear()
	if _bezier_points.size() < 4:
		push_warning("SafeMaze: _spawn_grass_tufts — not enough points for grass")
		return
	## Крок = кожен N-й bezier point, щоб травинки не були надто густими
	var step: int = maxi(int(float(_bezier_points.size()) / 12.0), 3)
	var i: int = 0
	while i < _bezier_points.size():
		var pt: Vector2 = _bezier_points[i]
		## Зсув перпендикулярно стежці
		var tangent: Vector2 = Vector2.RIGHT
		if i + 1 < _bezier_points.size():
			tangent = (_bezier_points[i + 1] - pt).normalized()
		elif i > 0:
			tangent = (pt - _bezier_points[i - 1]).normalized()
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		var side: float = -1.0 if (i / step) % 2 == 0 else 1.0
		var tuft_pos: Vector2 = pt + normal * (_path_width * 0.5 + 8.0) * side
		var tuft: Node2D = _create_grass_tuft(tuft_pos)
		_all_round_nodes.append(tuft)
		_grass_tufts.append(tuft)
		i += step


func _create_grass_tuft(pos: Vector2) -> Node2D:
	var tuft: Node2D = Node2D.new()
	tuft.position = pos
	add_child(tuft)
	## Малюємо 3 травинки через _draw
	var drawer: Control = Control.new()
	drawer.custom_minimum_size = Vector2(16, 20)
	drawer.position = Vector2(-8, -18)
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.draw.connect(func() -> void:
		var green1: Color = Color("4a8c3f")
		var green2: Color = Color("6bb85e")
		drawer.draw_line(Vector2(4, 18), Vector2(2, 2), green1, 2.0)
		drawer.draw_line(Vector2(8, 18), Vector2(10, 0), green2, 2.0)
		drawer.draw_line(Vector2(12, 18), Vector2(14, 4), green1, 1.5))
	tuft.add_child(drawer)
	return tuft


## ---- Scenic Spots (мікро-події на waypoints) ----

func _spawn_scenic_spots() -> void:
	_scenic_spots.clear()
	for node: Node2D in _scenic_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_scenic_nodes.clear()
	## 1-2 scenic spots на раунд, на рівновіддалених точках вздовж стежки
	var num_spots: int = _scale_adaptive_i(1, 2, _round, _total_rounds)
	if _bezier_points.size() < 6:
		push_warning("SafeMaze: not enough bezier points for scenic spots")
		return
	var available_types: Array[int] = [
		ScenicType.WATERFALL, ScenicType.FLOWER_MEADOW, ScenicType.BRIDGE]
	for s_idx: int in num_spots:
		## Розміщуємо scenic spots у середній частині шляху
		var frac: float = 0.3 + 0.4 * float(s_idx) / float(maxi(num_spots, 1))
		var bp_idx: int = clampi(
			int(frac * float(_bezier_points.size() - 1)), 1, _bezier_points.size() - 2)
		var spot_pos: Vector2 = _bezier_points[bp_idx]
		var type_idx: int = available_types[s_idx % available_types.size()]
		var spot_data: Dictionary = {
			"type": type_idx,
			"position": spot_pos,
			"bp_index": bp_idx,
			"triggered": false,
		}
		_scenic_spots.append(spot_data)
		var spot_node: Node2D = _create_scenic_spot(spot_pos, type_idx)
		_scenic_nodes.append(spot_node)
		_all_round_nodes.append(spot_node)


func _create_scenic_spot(pos: Vector2, scenic_type: int) -> Node2D:
	var spot: Node2D = Node2D.new()
	spot.position = pos
	add_child(spot)
	var icon: Control
	var spot_color: Color
	match scenic_type:
		ScenicType.WATERFALL:
			spot_color = SCENIC_WATERFALL_COLOR
			icon = IconDraw.bubble(SCENIC_SPOT_SIZE * 0.7, spot_color)
		ScenicType.FLOWER_MEADOW:
			spot_color = SCENIC_FLOWER_COLOR
			icon = IconDraw.heart(SCENIC_SPOT_SIZE * 0.7, spot_color)
		ScenicType.BRIDGE:
			spot_color = SCENIC_BRIDGE_COLOR
			icon = IconDraw.home_house(SCENIC_SPOT_SIZE * 0.7, spot_color)
		_:
			spot_color = SCENIC_FLOWER_COLOR
			icon = IconDraw.heart(SCENIC_SPOT_SIZE * 0.7, spot_color)
	icon.position = Vector2(-SCENIC_SPOT_SIZE * 0.35, -SCENIC_SPOT_SIZE * 0.35)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate.a = 0.5
	spot.add_child(icon)
	## Панелька-підкладка для scenic spot
	var panel: Panel = Panel.new()
	panel.size = Vector2(SCENIC_SPOT_SIZE, SCENIC_SPOT_SIZE)
	panel.position = Vector2(-SCENIC_SPOT_SIZE * 0.5, -SCENIC_SPOT_SIZE * 0.5)
	panel.add_theme_stylebox_override("panel",
		GameData.candy_circle(spot_color.darkened(0.2), SCENIC_SPOT_SIZE * 0.5))
	panel.modulate.a = 0.35
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot.add_child(panel)
	spot.move_child(panel, 0)
	return spot


func _trigger_scenic_spot(spot_idx: int) -> void:
	if spot_idx < 0 or spot_idx >= _scenic_spots.size():
		push_warning("SafeMaze: _trigger_scenic_spot — invalid index %d" % spot_idx)
		return
	if _scenic_spots[spot_idx].get("triggered", false):
		return
	_scenic_spots[spot_idx]["triggered"] = true
	var spot_type: int = int(_scenic_spots[spot_idx].get("type", 0))
	var spot_pos: Vector2 = _scenic_spots[spot_idx].get("position", Vector2.ZERO) as Vector2
	AudioManager.play_sfx_varied("pop", 0.15)
	HapticsManager.vibrate_light()
	## Розкрити scenic spot іконку
	if spot_idx < _scenic_nodes.size():
		var node: Node2D = _scenic_nodes[spot_idx]
		if is_instance_valid(node):
			var reveal_tw: Tween = _create_game_tween()
			reveal_tw.tween_property(node, "scale", Vector2(1.3, 1.3), 0.15)
			reveal_tw.tween_property(node, "scale", Vector2.ONE, 0.2)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			## Зробити іконку яскравішою
			for child: Node in node.get_children():
				if child is Control:
					var fade_tw: Tween = _create_game_tween()
					fade_tw.tween_property(child, "modulate:a", 1.0, 0.3)
	## Мікро-подія за типом
	match spot_type:
		ScenicType.WATERFALL:
			VFXManager.spawn_correct_sparkle(spot_pos)
		ScenicType.FLOWER_MEADOW:
			VFXManager.spawn_correct_sparkle(spot_pos + Vector2(0, -15))
		ScenicType.BRIDGE:
			## Міст "хитається" — тваринка bounce
			if _mover and is_instance_valid(_mover) and not SettingsManager.reduced_motion:
				var bridge_tw: Tween = _create_game_tween()
				bridge_tw.tween_property(_mover, "rotation_degrees", 5.0, 0.1)
				bridge_tw.tween_property(_mover, "rotation_degrees", -5.0, 0.12)
				bridge_tw.tween_property(_mover, "rotation_degrees", 0.0, 0.1)\
					.set_trans(Tween.TRANS_SINE)


## ---- Маркери старту/фінішу ----

func _spawn_markers() -> void:
	if _bezier_points.size() < 2:
		push_warning("SafeMaze: _spawn_markers — not enough bezier points")
		return
	_start_marker = _create_marker(_bezier_points[0], START_COLOR, "flag")
	_all_round_nodes.append(_start_marker)
	_end_marker = _create_marker(_bezier_points[_bezier_points.size() - 1], END_COLOR, "star")
	_all_round_nodes.append(_end_marker)


func _create_marker(pos: Vector2, color: Color, icon_id: String) -> Node2D:
	var marker: Node2D = Node2D.new()
	marker.position = pos
	add_child(marker)
	var panel: Panel = Panel.new()
	panel.size = Vector2(MARKER_SIZE, MARKER_SIZE)
	panel.position = Vector2(-MARKER_SIZE * 0.5, -MARKER_SIZE * 0.5)
	var style: StyleBoxFlat = GameData.candy_circle(color, MARKER_SIZE * 0.5)
	panel.add_theme_stylebox_override("panel", style)
	## LAW 28: Grain overlay
	panel.material = GameData.create_premium_material(
		0.04, 2.0, 0.0, 0.0, 0.0, 0.04, 0.10, "", 0.0, 0.10, 0.22, 0.18)
	marker.add_child(panel)
	var icon_ctrl: Control
	if icon_id == "star":
		icon_ctrl = IconDraw.star_5pt(MARKER_SIZE * 0.65, color)
	else:
		icon_ctrl = IconDraw.flag(MARKER_SIZE * 0.65, color)
	icon_ctrl.position = Vector2(-MARKER_SIZE * 0.32, -MARKER_SIZE * 0.32)
	icon_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(icon_ctrl)
	return marker


## ---- Спавн тваринки ----

func _spawn_mover() -> void:
	## A8: fallback — спробувати кілька тварин якщо спрайт відсутній
	var tex: Texture2D = null
	for _attempt: int in ANIMAL_NAMES.size():
		var animal: String = _pick_animal()
		var tex_path: String = "res://assets/sprites/animals/%s.png" % animal
		if ResourceLoader.exists(tex_path):
			tex = load(tex_path)
			if tex:
				break
		push_warning("SafeMaze: missing sprite: " + tex_path)
	if not tex:
		push_warning("SafeMaze: no animal sprite found, using fallback marker")
		## LAW 7: fallback — замість тваринки створюємо кольорове коло
		_mover = Sprite2D.new()
		var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color("06d6a0"))
		_mover.texture = ImageTexture.create_from_image(img)
		_mover.scale = Vector2(0.5, 0.5)
	else:
		_mover = Sprite2D.new()
		_mover.texture = tex
		_mover.scale = Vector2(0.20, 0.20)
	if _bezier_points.size() > 0:
		_mover.position = _bezier_points[0]
	add_child(_mover)
	_all_round_nodes.append(_mover)


## ---- Input: tracing ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	if event is InputEventMouseButton:
		if event.pressed:
			_try_start_trace(event.position)
		else:
			_stop_trace()
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_try_start_trace(event.position)
		else:
			_stop_trace()
	elif event is InputEventMouseMotion and _tracing:
		_trace_move(event.position)
	elif event is InputEventScreenDrag and _tracing and event.index == 0:
		_trace_move(event.position)


func _try_start_trace(pos: Vector2) -> void:
	if _bezier_points.size() == 0:
		push_warning("SafeMaze: _try_start_trace — no bezier points")
		return
	## Починати можна тільки біля старту або поточної позиції тваринки
	var target: Vector2
	if _mover and is_instance_valid(_mover):
		target = _mover.position
	else:
		target = _bezier_points[0]
	if pos.distance_to(target) < _path_width * 1.2:
		_tracing = true
		if is_instance_valid(_trail_line):
			_trail_line.add_point(pos)
		_reset_idle_timer()


func _stop_trace() -> void:
	_tracing = false
	## Зняти off-trail darken якщо активний
	if _off_trail_active:
		_set_off_trail(false)


func _trace_move(pos: Vector2) -> void:
	if not _tracing:
		return
	if is_instance_valid(_trail_line):
		_trail_line.add_point(pos)
	## Рухаємо тваринку
	if _mover and is_instance_valid(_mover):
		_mover.position = pos
	_reset_idle_timer()
	## Перевірити scenic spots
	_check_scenic_spots(pos)
	## Перевірити чи дійшли до кінця стежки
	if _bezier_points.size() > 1:
		var end_pos: Vector2 = _bezier_points[_bezier_points.size() - 1]
		if pos.distance_to(end_pos) < WAYPOINT_THRESHOLD:
			_on_path_complete()
			return
	## Off-trail check
	var min_dist: float = _distance_to_path(pos)
	var off_threshold: float = _path_width * 0.65
	if min_dist > off_threshold:
		if not _off_trail_active:
			_set_off_trail(true)
		if not _is_toddler:
			## A7: Preschool — рахуємо помилку
			if not _was_off_path:
				_errors += 1
				_register_error(_mover if _mover else null)
				_was_off_path = true
				AudioManager.play_sfx("error")
				HapticsManager.vibrate_light()
				if _mover and is_instance_valid(_mover):
					VFXManager.spawn_error_smoke(_mover.global_position)
		else:
			## A6: Toddler — м'який feedback, без штрафу
			if not _was_off_path:
				_was_off_path = true
				AudioManager.play_sfx("click")
				if _mover and is_instance_valid(_mover) and not SettingsManager.reduced_motion:
					var wobble_tw: Tween = _create_game_tween()
					wobble_tw.tween_property(_mover, "rotation_degrees", 8.0, 0.08)
					wobble_tw.tween_property(_mover, "rotation_degrees", -8.0, 0.1)
					wobble_tw.tween_property(_mover, "rotation_degrees", 0.0, 0.08)
	else:
		if _off_trail_active:
			_set_off_trail(false)
		_was_off_path = false


func _check_scenic_spots(pos: Vector2) -> void:
	for i: int in _scenic_spots.size():
		if _scenic_spots[i].get("triggered", false):
			continue
		var spot_pos: Vector2 = _scenic_spots[i].get("position", Vector2.ZERO) as Vector2
		if pos.distance_to(spot_pos) < WAYPOINT_THRESHOLD * 1.2:
			_trigger_scenic_spot(i)


func _set_off_trail(active: bool) -> void:
	_off_trail_active = active
	if not is_instance_valid(_darken_overlay):
		push_warning("SafeMaze: _set_off_trail — darken overlay freed")
		return
	if SettingsManager.reduced_motion:
		_darken_overlay.color.a = OFF_TRAIL_DARKEN_ALPHA if active else 0.0
		return
	var target_alpha: float = OFF_TRAIL_DARKEN_ALPHA if active else 0.0
	var darken_tw: Tween = _create_game_tween()
	darken_tw.tween_property(_darken_overlay, "color:a", target_alpha, 0.25)
	## Тваринка зменшується (нервує) при off-trail
	if _mover and is_instance_valid(_mover):
		var target_scale: Vector2 = Vector2(0.16, 0.16) if active else Vector2(0.20, 0.20)
		var mover_tw: Tween = _create_game_tween()
		mover_tw.tween_property(_mover, "scale", target_scale, 0.2)\
			.set_trans(Tween.TRANS_SINE)


## ---- Відстань до стежки ----

func _distance_to_path(pos: Vector2) -> float:
	var min_d: float = 99999.0
	if _bezier_points.size() < 2:
		push_warning("SafeMaze: _distance_to_path — not enough bezier points")
		return min_d
	## Перевіряємо кожен сегмент Bezier-стежки
	for i: int in _bezier_points.size() - 1:
		var a: Vector2 = _bezier_points[i]
		var b: Vector2 = _bezier_points[i + 1]
		var d: float = _point_to_segment_dist(pos, a, b)
		if d < min_d:
			min_d = d
	return min_d


func _point_to_segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.dot(ab)
	## LAW 13: guard zero-length segment
	if len_sq < 0.001:
		return p.distance_to(a)
	var ap: Vector2 = p - a
	var t: float = clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return p.distance_to(closest)


## ---- Завершення шляху ----

func _on_path_complete() -> void:
	_register_correct()
	_tracing = false
	_input_locked = true
	_set_off_trail(false)
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	if _bezier_points.size() > 0:
		VFXManager.spawn_premium_celebration(_bezier_points[_bezier_points.size() - 1])
	## Тваринка стрибає на фініші
	if _mover and is_instance_valid(_mover) and not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween()
		tw.tween_property(_mover, "scale", Vector2(0.24, 0.16), 0.1)
		tw.tween_property(_mover, "scale", Vector2(0.20, 0.20), 0.15)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	## Perfect run check: рідкісний птах!
	if _errors == 0 and _round == _total_rounds - 1:
		_spawn_perfect_run_reward()
	var tw2: Tween = _create_game_tween()
	var d2: float = ANIM_FAST if SettingsManager.reduced_motion else CELEBRATION_DELAY
	tw2.tween_interval(d2)
	tw2.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_clear_round()
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round())


## ---- Perfect run reward ----

func _spawn_perfect_run_reward() -> void:
	if _bezier_points.size() == 0:
		push_warning("SafeMaze: _spawn_perfect_run_reward — no bezier points")
		return
	var end_pos: Vector2 = _bezier_points[_bezier_points.size() - 1]
	## Рідкісний птах = зірка + sparkle + golden burst
	VFXManager.spawn_golden_burst(end_pos + Vector2(0, -40))
	VFXManager.spawn_correct_sparkle(end_pos + Vector2(20, -50))
	AudioManager.play_sfx_varied("star", 0.12)
	## Іконка птаха (pine_tree як стилізований птах на дереві)
	var bird_icon: Control = IconDraw.pine_tree(36.0, Color("22c55e"))
	bird_icon.position = end_pos + Vector2(-18, -70)
	bird_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bird_icon.modulate.a = 0.0
	add_child(bird_icon)
	_all_round_nodes.append(bird_icon)
	if not SettingsManager.reduced_motion:
		var bird_tw: Tween = _create_game_tween()
		bird_tw.tween_property(bird_icon, "modulate:a", 1.0, 0.3)
		bird_tw.tween_property(bird_icon, "position:y", bird_icon.position.y - 20.0, 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		bird_icon.modulate.a = 1.0


## ---- Round management ----

func _clear_round() -> void:
	## A9: Round hygiene — все очищуємо
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_scenic_nodes.clear()
	_scenic_spots.clear()
	_grass_tufts.clear()
	_bezier_points.clear()
	_path_line = null
	_path_border = null
	_trail_line = null
	_mover = null
	_start_marker = null
	_end_marker = null
	_was_off_path = false
	_tracing = false
	_off_trail_active = false
	_current_wp = 0


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": _total_rounds,
		"earned_stars": earned,
	})


## ---- Idle hint (A10) ----

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
		## A11: Scaffolding — показати відповідь (TutorialSystem)
		_reset_idle_timer()
		return
	## A10 level 0-1: pulse start marker або mover
	if _mover and is_instance_valid(_mover):
		_pulse_node(_mover, 1.3)
	elif _start_marker and is_instance_valid(_start_marker):
		_pulse_node(_start_marker, 1.3)
	_reset_idle_timer()
