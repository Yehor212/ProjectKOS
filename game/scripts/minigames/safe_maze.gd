extends BaseMiniGame

## ECE-14 Безпечний лабіринт — проведи тваринку по стежці!
## Toddler: 3 раунди, широка стежка, без штрафу.
## Preschool: 4 раунди, вужча стежка, штраф за виходи за межі.

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 4
const PATH_WIDTH_TODDLER: float = 60.0
const PATH_WIDTH_PRESCHOOL: float = 36.0
const TRAIL_WIDTH: float = 8.0
const MARKER_SIZE: float = 36.0
const IDLE_HINT_DELAY: float = 5.0
const WAYPOINT_THRESHOLD: float = 40.0
const PATH_COLOR: Color = Color("b3e5fc")
const PATH_BORDER_COLOR: Color = Color("4fc3f7")
const TRAIL_COLOR: Color = Color("06d6a0")
const START_COLOR: Color = Color("ffd166")
const END_COLOR: Color = Color("ef476f")
const SAFETY_TIMEOUT_SEC: float = 120.0

const ANIMAL_NAMES: Array[String] = [
	"Bear", "Bunny", "Cat", "Chicken", "Cow", "Crocodile", "Deer",
	"Dog", "Elephant", "Frog", "Goat", "Hedgehog", "Horse",
	"Lion", "Monkey", "Mouse", "Panda", "Penguin", "Squirrel",
]

## Шаблони шляхів — точки відносно viewport (0..1)
const PATH_TEMPLATES: Array[Array] = [
	[Vector2(0.2, 0.3), Vector2(0.5, 0.25), Vector2(0.8, 0.4), Vector2(0.7, 0.65), Vector2(0.4, 0.7)],
	[Vector2(0.15, 0.5), Vector2(0.35, 0.3), Vector2(0.55, 0.5), Vector2(0.75, 0.3), Vector2(0.85, 0.6)],
	[Vector2(0.2, 0.7), Vector2(0.3, 0.4), Vector2(0.5, 0.5), Vector2(0.7, 0.35), Vector2(0.8, 0.6)],
	[Vector2(0.15, 0.35), Vector2(0.4, 0.55), Vector2(0.6, 0.3), Vector2(0.85, 0.5)],
	[Vector2(0.8, 0.3), Vector2(0.6, 0.5), Vector2(0.4, 0.35), Vector2(0.2, 0.6), Vector2(0.3, 0.75)],
]

var _is_toddler: bool = false
var _round: int = 0
var _total_rounds: int = 0
var _start_time: float = 0.0
var _was_off_path: bool = false
var _tracing: bool = false
var _path_width: float = 60.0

var _waypoints: Array[Vector2] = []
var _current_wp: int = 0
var _path_line: Line2D = null
var _trail_line: Line2D = null
var _mover: Sprite2D = null
var _start_marker: Node2D = null
var _end_marker: Node2D = null
var _all_round_nodes: Array[Node] = []
var _used_paths: Array[int] = []
var _used_animals: Array[int] = []

var _idle_timer: SceneTreeTimer = null


func _ready() -> void:
	game_id = "safe_maze"
	bg_theme = "puzzle"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	## Початкова ширина (оновлюється кожен раунд)
	_path_width = PATH_WIDTH_TODDLER if _is_toddler else PATH_WIDTH_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("MAZE_TUTORIAL_TODDLER")
	return tr("MAZE_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _waypoints.size() < 2:
		return {}
	return {"type": "drag", "from": _waypoints[0], "to": _waypoints[1]}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_current_wp = 0
	_tracing = false
	## Прогресивна складність: стежка звужується в пізніших раундах (P)
	if not _is_toddler:
		_path_width = _scale_by_round(50.0, PATH_WIDTH_PRESCHOOL, _round, _total_rounds)
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var template: Array = _pick_path()
	_waypoints.clear()
	for pt: Vector2 in template:
		_waypoints.append(Vector2(pt.x * vp.x, pt.y * vp.y))
	_spawn_path()
	_spawn_markers()
	_spawn_mover()
	_orchestrated_entrance(_all_round_nodes as Array, 0.06, false, "pop")
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.55
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _pick_path() -> Array:
	if _used_paths.size() >= PATH_TEMPLATES.size():
		_used_paths.clear()
	var idx: int = randi() % PATH_TEMPLATES.size()
	while _used_paths.has(idx):
		idx = randi() % PATH_TEMPLATES.size()
	_used_paths.append(idx)
	return PATH_TEMPLATES[idx]


func _pick_animal() -> String:
	if _used_animals.size() >= ANIMAL_NAMES.size():
		_used_animals.clear()
	var idx: int = randi() % ANIMAL_NAMES.size()
	while _used_animals.has(idx):
		idx = randi() % ANIMAL_NAMES.size()
	_used_animals.append(idx)
	return ANIMAL_NAMES[idx]


func _spawn_path() -> void:
	_path_line = Line2D.new()
	_path_line.width = _path_width
	_path_line.default_color = PATH_COLOR
	_path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_path_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	for wp: Vector2 in _waypoints:
		_path_line.add_point(wp)
	add_child(_path_line)
	_all_round_nodes.append(_path_line)
	## Бордюр стежки (товщий, темніший, під основною лінією)
	var border: Line2D = Line2D.new()
	border.width = _path_width + 6.0
	border.default_color = PATH_BORDER_COLOR
	border.joint_mode = Line2D.LINE_JOINT_ROUND
	border.begin_cap_mode = Line2D.LINE_CAP_ROUND
	border.end_cap_mode = Line2D.LINE_CAP_ROUND
	for wp: Vector2 in _waypoints:
		border.add_point(wp)
	add_child(border)
	move_child(border, _path_line.get_index())
	_all_round_nodes.append(border)
	## Trail — слід, який малює дитина
	_trail_line = Line2D.new()
	_trail_line.width = TRAIL_WIDTH
	_trail_line.default_color = TRAIL_COLOR
	_trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail_line)
	_all_round_nodes.append(_trail_line)


func _spawn_markers() -> void:
	## Старт маркер
	_start_marker = _create_marker(_waypoints[0], START_COLOR, "flag")
	_all_round_nodes.append(_start_marker)
	## Фініш маркер
	_end_marker = _create_marker(_waypoints[_waypoints.size() - 1], END_COLOR, "star")
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
	## Grain overlay (LAW 28)
	panel.material = GameData.create_premium_material(0.04, 2.0, 0.0, 0.0, 0.0, 0.04, 0.10, "", 0.0, 0.10, 0.22, 0.18)
	marker.add_child(panel)
	var icon_ctrl: Control
	if icon_id == "star":
		icon_ctrl = IconDraw.star_5pt(MARKER_SIZE * 0.6, color)
	else:
		icon_ctrl = IconDraw.flag(MARKER_SIZE * 0.6, color)
	icon_ctrl.position = Vector2(-MARKER_SIZE * 0.3, -MARKER_SIZE * 0.3)
	icon_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(icon_ctrl)
	return marker


func _spawn_mover() -> void:
	## A8: fallback — спробувати інші тварини якщо спрайт відсутній
	var tex: Texture2D = null
	for _attempt: int in ANIMAL_NAMES.size():
		var animal: String = _pick_animal()
		var tex_path: String = "res://assets/sprites/animals/%s.png" % animal
		if ResourceLoader.exists(tex_path):
			tex = load(tex_path)
			if tex:
				break
		push_warning("SafeMaze: Missing sprite: " + tex_path)
	if not tex:
		push_warning("SafeMaze: жоден спрайт тварини не знайдено, пропускаємо mover")
		return
	_mover = Sprite2D.new()
	_mover.texture = tex
	_mover.scale = Vector2(0.18, 0.18)
	_mover.position = _waypoints[0]
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
			_tracing = false
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_try_start_trace(event.position)
		else:
			_tracing = false
	elif event is InputEventMouseMotion and _tracing:
		_trace_move(event.position)
	elif event is InputEventScreenDrag and _tracing and event.index == 0:
		_trace_move(event.position)


func _try_start_trace(pos: Vector2) -> void:
	## Починати можна тільки біля старту або поточного waypoint
	var target: Vector2 = _waypoints[_current_wp]
	if pos.distance_to(target) < _path_width:
		_tracing = true
		_trail_line.add_point(pos)


func _trace_move(pos: Vector2) -> void:
	if not _tracing:
		return
	_trail_line.add_point(pos)
	## Рухаємо тваринку
	if _mover:
		_mover.position = pos
	## Перевірити чи дійшли до наступного waypoint
	if _current_wp < _waypoints.size() - 1:
		var next_wp: Vector2 = _waypoints[_current_wp + 1]
		if pos.distance_to(next_wp) < WAYPOINT_THRESHOLD:
			_current_wp += 1
			HapticsManager.vibrate_light()
			## Перевірити чи фініш
			if _current_wp >= _waypoints.size() - 1:
				_on_path_complete()
	## Перевірити чи палець далеко від стежки (preschool)
	if not _is_toddler:
		var min_dist: float = _distance_to_path(pos)
		if min_dist > _path_width * 0.7:
			if not _was_off_path:
				_errors += 1
				_register_error(_mover if _mover else null)
				_was_off_path = true
				AudioManager.play_sfx("error")
				HapticsManager.vibrate_light()
				if _mover:
					VFXManager.spawn_error_smoke(_mover.global_position)
		else:
			_was_off_path = false


func _distance_to_path(pos: Vector2) -> float:
	var min_d: float = 99999.0
	for i: int in _waypoints.size() - 1:
		var a: Vector2 = _waypoints[i]
		var b: Vector2 = _waypoints[i + 1]
		var d: float = _point_to_segment_dist(pos, a, b)
		if d < min_d:
			min_d = d
	return min_d


func _point_to_segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.dot(ab)
	if len_sq < 0.001:
		return p.distance_to(a)
	var ap: Vector2 = p - a
	var t: float = clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return p.distance_to(closest)


func _on_path_complete() -> void:
	_register_correct()
	_tracing = false
	_input_locked = true
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_premium_celebration(_waypoints[_waypoints.size() - 1])
	## Тваринка стрибає на фініші
	if _mover and not SettingsManager.reduced_motion:
		var tw: Tween = create_tween()
		tw.tween_property(_mover, "scale", Vector2(0.22, 0.14), 0.1)
		tw.tween_property(_mover, "scale", Vector2(0.18, 0.18), 0.15)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var tw2: Tween = create_tween()
	var d2: float = 0.15 if SettingsManager.reduced_motion else 1.0
	tw2.tween_interval(d2)
	tw2.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round())


## ---- Round management ----

func _clear_round() -> void:
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_waypoints.clear()
	_path_line = null
	_trail_line = null
	_mover = null
	_start_marker = null
	_end_marker = null
	_was_off_path = false
	_tracing = false


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": _total_rounds, "earned_stars": earned})


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
	if _start_marker and is_instance_valid(_start_marker):
		_pulse_node(_start_marker, 1.3)
	_reset_idle_timer()
