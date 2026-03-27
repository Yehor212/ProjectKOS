extends BaseMiniGame

## PRE-21 Алгоритмічний робот — програмуй рух робота до цілі!
## Побудуй послідовність команд ⬆️⬇️⬅️➡️ та запусти виконання.
## Toddler: 3x3 сітка, 3 раунди, 2-3 кроки. Preschool: 4x4, 4 раунди, 3-5 кроків.
## Preschool раунди 3-4: кнопка x2 (repeat) дублює останню команду.

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 4
const GRID_TODDLER: int = 3
const GRID_PRESCHOOL: int = 4
const CELL_SIZE: float = 70.0
const MOVE_DURATION: float = 0.35
const IDLE_HINT_DELAY: float = 6.0
const CELL_COLOR: Color = Color(0.92, 0.92, 0.98, 0.8)
const CELL_BORDER: Color = Color("a78bfa")
const ROBOT_COLOR: Color = Color("6366f1")
const GOAL_COLOR: Color = Color("ffd166")
const CMD_SIZE: Vector2 = Vector2(68, 68)
const CMD_GAP: float = 10.0
const ACTION_BTN_GAP: float = 20.0
const ACTION_BTN_SIZE: Vector2 = Vector2(140, 56)
const CLEAR_BTN_SIZE: Vector2 = Vector2(56, 56)
## Пастельні кольори напрямків
const DIR_COLORS: Dictionary = {
	"up": Color("93c5fd"), "down": Color("86efac"),
	"left": Color("fdba74"), "right": Color("c4b5fd"),
}
const SAFETY_TIMEOUT_SEC: float = 120.0
const PREVIEW_LINE_COLOR: Color = Color("ffd166", 0.4)
const PREVIEW_LINE_WIDTH: float = 3.0
const DEMO_MOVE_DURATION: float = 0.55  ## Повільніший рух під час демо

## ── Robot personality constants ──
const EYE_RADIUS: float = 5.0
const PUPIL_RADIUS: float = 2.5
const EYE_OFFSET: Vector2 = Vector2(8.0, -6.0)  ## Від центру робота
const EYE_TRACK_RANGE: float = 3.0  ## Макс зміщення зіниці за курсором
const MOUTH_WIDTH: float = 12.0
const MOUTH_Y_OFFSET: float = 6.0  ## Нижче центру робота

## Robot emotion enum (mouth shape)
enum RobotMood { NEUTRAL, HAPPY, CONFUSED, BONK }

## ── Grid theme constants (DECORATIVE — не змінюють pathfinding!) ──
const THEME_NONE: int = 0
const THEME_LAVA: int = 1
const THEME_WATER: int = 2
const LAVA_TINT: Color = Color("ef476f", 0.25)  ## Червоний декоративний оверлей
const WATER_TINT: Color = Color("06d6a0", 0.2)  ## Блакитно-зелений оверлей
const LAVA_ICON_COLOR: Color = Color("ef476f")
const WATER_ICON_COLOR: Color = Color("118ab2")
## Кількість тематичних клітинок за раундом (прогресивно)
const THEMED_CELLS_MIN: int = 1
const THEMED_CELLS_MAX: int = 3

## ── Personality animation constants ──
const WOBBLE_ANGLE: float = 0.15  ## Радіани повороту при зміні напрямку
const STRETCH_SCALE: Vector2 = Vector2(0.85, 1.15)  ## Витягування при русі вперед
const BONK_OFFSET: float = 8.0  ## Пікселі відскоку при ударі в стіну
const BACKFLIP_DURATION: float = 0.6
const SLIDE_PITCH_BASE: float = 0.9  ## Базовий pitch для slide SFX (зростає за кроком)
const SLIDE_PITCH_STEP: float = 0.05  ## Приріст pitch за кожен крок

const DIRECTIONS: Dictionary = {
	"up": Vector2i(0, -1), "down": Vector2i(0, 1),
	"left": Vector2i(-1, 0), "right": Vector2i(1, 0),
}
## Напрямки: іконки створюються через IconDraw.direction_arrow(dir)
## Маппінг напрямків → Kenney текстурні ключі (blue, green, yellow, red)
const DIR_TEXTURE_KEYS: Dictionary = {
	"up": "blue", "down": "green", "left": "yellow", "right": "red",
}

var _is_toddler: bool = false
var _round: int = 0
var _total_rounds: int = 0
var _start_time: float = 0.0
var _grid_size: int = 3

var _robot_pos: Vector2i = Vector2i.ZERO
var _goal_pos: Vector2i = Vector2i.ZERO
var _commands: Array[String] = []
var _executing: bool = false

var _grid_origin: Vector2 = Vector2.ZERO
var _robot_node: Node2D = null
var _goal_node: Node2D = null
var _cmd_display: Array[Panel] = []
var _all_round_nodes: Array[Node] = []

var _play_btn: Button = null
var _clear_btn: Button = null
var _repeat_btn: Button = null
var _cmd_container: Node2D = null
var _idle_timer: SceneTreeTimer = null
var _move_tween: Tween = null  ## Зберігаємо для kill при exit pause

## Feature: Preschool preview dotted line
var _preview_line: Line2D = null

## Feature: Toddler "Follow My Path" demo
var _demo_path: Array[String] = []  ## Очікувана послідовність для toddler replay
var _toddler_replay_idx: int = 0  ## Поточний крок replay у toddler
var _demo_trail: Line2D = null  ## Trail що показується під час демо

## ── Robot face nodes ──
var _left_eye: Control = null
var _right_eye: Control = null
var _left_pupil: Control = null
var _right_pupil: Control = null
var _mouth_ctrl: Control = null
var _robot_mood: int = RobotMood.NEUTRAL
var _cursor_pos: Vector2 = Vector2.ZERO  ## Кешована позиція курсора для очей

## ── Grid theme state ──
var _current_theme: int = THEME_NONE
var _themed_cells: Dictionary = {}  ## Vector2i -> theme_id (декоративні оверлеї)
var _theme_overlays: Array[Node] = []  ## Ноди оверлеїв тем для cleanup

## ── Personality state ──
var _last_move_dir: String = ""  ## Попередній напрямок для wobble detection
var _execution_step: int = 0  ## Поточний крок виконання (для pitch escalation)
var _optimal_length: int = 0  ## BFS optimal path length для bonus detection


func _ready() -> void:
	game_id = "algo_robot"
	bg_theme = "science"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_grid_size = GRID_TODDLER if _is_toddler else GRID_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_cursor_pos = (event as InputEventMouseMotion).position
	elif event is InputEventScreenTouch:
		_cursor_pos = (event as InputEventScreenTouch).position


func _process(_delta: float) -> void:
	_update_eye_tracking()


## ── Оновлення зіниць — слідкують за курсором/пальцем ──
func _update_eye_tracking() -> void:
	if not is_instance_valid(_robot_node):
		return
	if not is_instance_valid(_left_pupil) or not is_instance_valid(_right_pupil):
		return
	var robot_global: Vector2 = _robot_node.global_position
	var dir_to_cursor: Vector2 = (_cursor_pos - robot_global).normalized()
	var offset: Vector2 = dir_to_cursor * EYE_TRACK_RANGE
	_left_pupil.position = Vector2(-PUPIL_RADIUS, -PUPIL_RADIUS) + offset
	_right_pupil.position = Vector2(-PUPIL_RADIUS, -PUPIL_RADIUS) + offset


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("ALGO_TUTORIAL_TODDLER")
	return tr("ALGO_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	## Підказка — тап на першу потрібну команду (напрямок до цілі)
	var diff: Vector2i = _goal_pos - _robot_pos
	var first_dir: String = ""
	if abs(diff.x) >= abs(diff.y):
		first_dir = "right" if diff.x > 0 else "left"
	else:
		first_dir = "down" if diff.y > 0 else "up"
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var dirs: Array[String] = ["left", "up", "down", "right"]
	var idx: int = dirs.find(first_dir)
	if idx < 0:
		return {}
	var grid_bottom: float = _grid_origin.y + float(_grid_size) * CELL_SIZE + 20.0
	var btn_y: float = grid_bottom + 40.0
	var total_w: float = float(dirs.size()) * (CMD_SIZE.x + CMD_GAP)
	var start_x: float = (vp.x - total_w) * 0.5
	var btn_center: Vector2 = Vector2(
		start_x + float(idx) * (CMD_SIZE.x + CMD_GAP) + CMD_SIZE.x * 0.5,
		btn_y + CMD_SIZE.y * 0.5)
	return {"type": "tap", "target": btn_center}


func _build_hud() -> void:
	_build_instruction_pill(tr("ROBOT_LOST_HELP"), 26)


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_commands.clear()
	_cmd_display.clear()
	_executing = false
	_demo_path.clear()
	_toddler_replay_idx = 0
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_select_grid_theme()
	_generate_puzzle()
	## Обчислити optimal path для bonus detection
	_optimal_length = _compute_solution_path(_robot_pos, _goal_pos).size()
	_spawn_grid()
	_spawn_themed_overlays()
	_spawn_robot_and_goal()
	_spawn_robot_face()
	_spawn_command_buttons()
	_spawn_action_buttons()
	## Preschool: створити preview line (порожню)
	if not _is_toddler:
		_spawn_preview_line()
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.3
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		if _is_toddler:
			## Toddler: спочатку демо шляху, потім replay
			_run_toddler_demo()
		else:
			_input_locked = false
			_reset_idle_timer())


func _generate_puzzle() -> void:
	_robot_pos = Vector2i(0, 0)
	## Ціль — рандомна позиція не на старті
	## Прогресивна складність: більше кроків у пізніших раундах
	var steps: int = _scale_by_round_i(2, 3, _round, _total_rounds) if _is_toddler \
		else _scale_by_round_i(2, 5, _round, _total_rounds)
	var pos: Vector2i = Vector2i.ZERO
	for _i: int in steps:
		var dirs: Array[String] = ["up", "down", "left", "right"]
		dirs.shuffle()
		for d: String in dirs:
			var new_pos: Vector2i = pos + DIRECTIONS.get(d, Vector2i.ZERO)
			if new_pos.x >= 0 and new_pos.x < _grid_size and \
				new_pos.y >= 0 and new_pos.y < _grid_size and \
				new_pos != Vector2i.ZERO:
				pos = new_pos
				break
	if pos == Vector2i.ZERO:
		pos = Vector2i(_grid_size - 1, _grid_size - 1)
	_goal_pos = pos
	## Toddler: обчислити демо-шлях (BFS найкоротший)
	if _is_toddler:
		_demo_path = _compute_solution_path(_robot_pos, _goal_pos)


## ── Вибір декоративної теми сітки (прогресивно за раундами, LAW 6) ──
func _select_grid_theme() -> void:
	_themed_cells.clear()
	## Toddler: без тем (чиста сітка). Preschool раунд 0: теж чиста.
	if _is_toddler or _round == 0:
		_current_theme = THEME_NONE
		return
	## Прогресивно: раунд 1 = lava, раунд 2+ = water або змішано
	if _round == 1:
		_current_theme = THEME_LAVA
	else:
		_current_theme = [THEME_LAVA, THEME_WATER][randi() % 2]
	## Кількість декоративних клітинок зростає з раундом
	var count: int = _scale_by_round_i(THEMED_CELLS_MIN, THEMED_CELLS_MAX, _round, _total_rounds)
	var candidates: Array[Vector2i] = []
	for row: int in _grid_size:
		for col: int in _grid_size:
			var pos: Vector2i = Vector2i(col, row)
			## Не ставимо тему на старт і ціль
			if pos != Vector2i.ZERO and pos != _goal_pos:
				candidates.append(pos)
	candidates.shuffle()
	var placed: int = 0
	for pos: Vector2i in candidates:
		if placed >= count:
			break
		_themed_cells[pos] = _current_theme
		placed += 1


## ── Спавн декоративних оверлеїв на тематичні клітинки ──
## DECORATIVE ONLY — не змінюють pathfinding (LAW 25: іконка + колір)
func _spawn_themed_overlays() -> void:
	for cell_pos: Vector2i in _themed_cells:
		var theme_id: int = _themed_cells.get(cell_pos, THEME_NONE)
		if theme_id == THEME_NONE:
			continue
		var center: Vector2 = _cell_center(cell_pos)
		## Кольоровий оверлей
		var overlay: Panel = Panel.new()
		var sz: float = CELL_SIZE - 6.0
		overlay.size = Vector2(sz, sz)
		overlay.position = Vector2(center.x - sz * 0.5, center.y - sz * 0.5)
		var tint: Color = LAVA_TINT if theme_id == THEME_LAVA else WATER_TINT
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = tint
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		overlay.add_theme_stylebox_override("panel", style)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)
		_all_round_nodes.append(overlay)
		_theme_overlays.append(overlay)
		## Іконка теми (LAW 25: не тільки колір — додаємо форму)
		var icon_ctrl: Control = Control.new()
		var icon_sz: float = 18.0
		icon_ctrl.size = Vector2(icon_sz, icon_sz)
		icon_ctrl.position = Vector2(center.x - icon_sz * 0.5, center.y - icon_sz * 0.5)
		icon_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if theme_id == THEME_LAVA:
			## Трикутник вогню (LAW 25: форма + колір)
			icon_ctrl.draw.connect(func() -> void:
				var pts: PackedVector2Array = PackedVector2Array([
					Vector2(icon_sz * 0.5, 0.0),
					Vector2(icon_sz, icon_sz),
					Vector2(0.0, icon_sz)])
				icon_ctrl.draw_colored_polygon(pts, LAVA_ICON_COLOR))
		else:
			## Хвилі води (LAW 25: форма + колір)
			icon_ctrl.draw.connect(func() -> void:
				for wave_i: int in 3:
					var y: float = float(wave_i) * 6.0 + 3.0
					icon_ctrl.draw_line(
						Vector2(0.0, y), Vector2(icon_sz, y),
						WATER_ICON_COLOR, 2.0))
		add_child(icon_ctrl)
		_all_round_nodes.append(icon_ctrl)
		_theme_overlays.append(icon_ctrl)


## BFS найкоротший шлях між двома позиціями на сітці.
## Повертає Array[String] напрямків.
func _compute_solution_path(from: Vector2i, to: Vector2i) -> Array[String]:
	if from == to:
		push_warning("AlgoRobot: _compute_solution_path — from == to")
		return []
	var queue: Array[Dictionary] = [{"pos": from, "path": [] as Array[String]}]
	var visited: Dictionary = {from: true}
	while queue.size() > 0:
		var current: Dictionary = queue.pop_front()
		var cpos: Vector2i = current.get("pos", Vector2i.ZERO)
		var cpath: Array = current.get("path", [])
		for dir_name: String in DIRECTIONS:
			var delta: Vector2i = DIRECTIONS.get(dir_name, Vector2i.ZERO)
			var npos: Vector2i = cpos + delta
			if npos.x < 0 or npos.x >= _grid_size or npos.y < 0 or npos.y >= _grid_size:
				continue
			if visited.has(npos):
				continue
			var npath: Array[String] = []
			for s: String in cpath:
				npath.append(s)
			npath.append(dir_name)
			if npos == to:
				return npath
			visited[npos] = true
			queue.append({"pos": npos, "path": npath})
	## Fallback — прямий шлях (не повинно статися)
	push_warning("AlgoRobot: BFS failed, using direct path")
	var result: Array[String] = []
	var diff: Vector2i = to - from
	for _ix: int in absi(diff.x):
		result.append("right" if diff.x > 0 else "left")
	for _iy: int in absi(diff.y):
		result.append("down" if diff.y > 0 else "up")
	return result


func _spawn_grid() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var total: float = float(_grid_size) * CELL_SIZE
	_grid_origin = Vector2((vp.x - total) * 0.5, 140.0)
	## Текстурна гральна дошка під сіткою
	var board_pad: float = 10.0
	var board: TextureRect = TextureRect.new()
	board.size = Vector2(total + board_pad * 2.0, total + board_pad * 2.0)
	board.position = _grid_origin - Vector2(board_pad, board_pad)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var board_tex_path: String = "res://assets/textures/backtiles/backtile_10.png"
	if ResourceLoader.exists(board_tex_path):
		board.texture = load(board_tex_path)
	board.modulate = Color(1, 1, 1, 0.15)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	_all_round_nodes.append(board)
	var grid_cells: Array[Panel] = []
	var cell_idx: int = 0
	for row: int in _grid_size:
		for col: int in _grid_size:
			var cell: Panel = Panel.new()
			cell.size = Vector2(CELL_SIZE - 4.0, CELL_SIZE - 4.0)
			cell.position = _grid_origin + Vector2(
				float(col) * CELL_SIZE + 2.0, float(row) * CELL_SIZE + 2.0)
			var style: StyleBoxFlat = GameData.candy_cell(CELL_COLOR, 10)
			style.border_color = CELL_BORDER
			cell.add_theme_stylebox_override("panel", style)
			## Tile текстура (LAW 28)
			var cell_tile: String = "res://assets/textures/tiles/blue/tile_%02d.png" % ((cell_idx % 5) + 1)
			cell.material = GameData.create_premium_material(0.03, 2.0, 0.03, 0.0, 0.04, 0.03, 0.05, cell_tile, 0.15, 0.10, 0.22, 0.18)
			add_child(cell)
			_all_round_nodes.append(cell)
			grid_cells.append(cell)
			cell_idx += 1
	_staggered_spawn(grid_cells, 0.06)


func _cell_center(grid_pos: Vector2i) -> Vector2:
	return _grid_origin + Vector2(
		float(grid_pos.x) * CELL_SIZE + CELL_SIZE * 0.5,
		float(grid_pos.y) * CELL_SIZE + CELL_SIZE * 0.5)


func _spawn_robot_and_goal() -> void:
	## Ціль
	_goal_node = Node2D.new()
	_goal_node.position = _cell_center(_goal_pos)
	add_child(_goal_node)
	var goal_panel: Panel = Panel.new()
	var gsz: float = CELL_SIZE * 0.6
	goal_panel.size = Vector2(gsz, gsz)
	goal_panel.position = Vector2(-gsz * 0.5, -gsz * 0.5)
	goal_panel.add_theme_stylebox_override("panel",
		GameData.candy_circle(GOAL_COLOR, gsz * 0.5))
	goal_panel.material = GameData.create_premium_material(0.05, 2.0, 0.04, 0.08, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18) ## Grain overlay (LAW 28)
	_goal_node.add_child(goal_panel)
	var goal_icon: Control = IconDraw.star_5pt(gsz * 0.65, GOAL_COLOR)
	goal_icon.position = Vector2(-gsz * 0.5 + gsz * 0.18, -gsz * 0.5 + gsz * 0.18)
	_goal_node.add_child(goal_icon)
	_all_round_nodes.append(_goal_node)
	## Робот
	_robot_node = Node2D.new()
	_robot_node.position = _cell_center(_robot_pos)
	add_child(_robot_node)
	var robot_panel: Panel = Panel.new()
	var rsz: float = CELL_SIZE * 0.55
	robot_panel.size = Vector2(rsz, rsz)
	robot_panel.position = Vector2(-rsz * 0.5, -rsz * 0.5)
	robot_panel.add_theme_stylebox_override("panel",
		GameData.candy_panel(ROBOT_COLOR, 14))
	robot_panel.material = GameData.create_premium_material(0.04, 2.0, 0.04, 0.06, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18) ## Grain overlay (LAW 28)
	_robot_node.add_child(robot_panel)
	## HQ текстура робота замість code-drawn
	var robot_tex_path: String = "res://assets/textures/game_icons/icon_robot.png"
	if ResourceLoader.exists(robot_tex_path):
		var robot_tex: Texture2D = load(robot_tex_path)
		var robot_icon_sz: float = rsz * 0.8
		var robot_ctrl: Control = Control.new()
		robot_ctrl.size = Vector2(robot_icon_sz, robot_icon_sz)
		robot_ctrl.position = Vector2(-rsz * 0.4, -rsz * 0.4)
		robot_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		robot_ctrl.draw.connect(func() -> void:
			robot_ctrl.draw_texture_rect(robot_tex, Rect2(Vector2.ZERO, Vector2(robot_icon_sz, robot_icon_sz)), false)
		)
		_robot_node.add_child(robot_ctrl)
	else:
		var robot_icon: Control = IconDraw.robot_head(rsz * 0.7, ROBOT_COLOR)
		robot_icon.position = Vector2(-rsz * 0.35, -rsz * 0.35)
		robot_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_robot_node.add_child(robot_icon)
	_all_round_nodes.append(_robot_node)


## ── Спавн обличчя робота (очі + рот) як дочірніх вузлів _robot_node ──
func _spawn_robot_face() -> void:
	if not is_instance_valid(_robot_node):
		push_warning("AlgoRobot: _spawn_robot_face — robot_node invalid")
		return
	## Ліве око (біле коло + зіниця)
	_left_eye = Control.new()
	_left_eye.size = Vector2(EYE_RADIUS * 2.0, EYE_RADIUS * 2.0)
	_left_eye.position = Vector2(-EYE_OFFSET.x - EYE_RADIUS, EYE_OFFSET.y - EYE_RADIUS)
	_left_eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_eye.z_index = 3
	_left_eye.draw.connect(func() -> void:
		_left_eye.draw_circle(Vector2(EYE_RADIUS, EYE_RADIUS), EYE_RADIUS, Color.WHITE)
		_left_eye.draw_arc(Vector2(EYE_RADIUS, EYE_RADIUS), EYE_RADIUS, 0.0, TAU, 24, Color(0.3, 0.3, 0.4), 1.0))
	_robot_node.add_child(_left_eye)
	## Ліва зіниця
	_left_pupil = Control.new()
	_left_pupil.size = Vector2(PUPIL_RADIUS * 2.0, PUPIL_RADIUS * 2.0)
	_left_pupil.position = Vector2(-PUPIL_RADIUS, -PUPIL_RADIUS)
	_left_pupil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_pupil.z_index = 4
	_left_pupil.draw.connect(func() -> void:
		_left_pupil.draw_circle(Vector2(PUPIL_RADIUS, PUPIL_RADIUS), PUPIL_RADIUS, Color(0.15, 0.15, 0.2)))
	_left_eye.add_child(_left_pupil)
	## Праве око
	_right_eye = Control.new()
	_right_eye.size = Vector2(EYE_RADIUS * 2.0, EYE_RADIUS * 2.0)
	_right_eye.position = Vector2(EYE_OFFSET.x - EYE_RADIUS, EYE_OFFSET.y - EYE_RADIUS)
	_right_eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_eye.z_index = 3
	_right_eye.draw.connect(func() -> void:
		_right_eye.draw_circle(Vector2(EYE_RADIUS, EYE_RADIUS), EYE_RADIUS, Color.WHITE)
		_right_eye.draw_arc(Vector2(EYE_RADIUS, EYE_RADIUS), EYE_RADIUS, 0.0, TAU, 24, Color(0.3, 0.3, 0.4), 1.0))
	_robot_node.add_child(_right_eye)
	## Права зіниця
	_right_pupil = Control.new()
	_right_pupil.size = Vector2(PUPIL_RADIUS * 2.0, PUPIL_RADIUS * 2.0)
	_right_pupil.position = Vector2(-PUPIL_RADIUS, -PUPIL_RADIUS)
	_right_pupil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_pupil.z_index = 4
	_right_pupil.draw.connect(func() -> void:
		_right_pupil.draw_circle(Vector2(PUPIL_RADIUS, PUPIL_RADIUS), PUPIL_RADIUS, Color(0.15, 0.15, 0.2)))
	_right_eye.add_child(_right_pupil)
	## Рот — керується через _robot_mood
	_mouth_ctrl = Control.new()
	_mouth_ctrl.size = Vector2(MOUTH_WIDTH, 8.0)
	_mouth_ctrl.position = Vector2(-MOUTH_WIDTH * 0.5, MOUTH_Y_OFFSET)
	_mouth_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mouth_ctrl.z_index = 3
	_mouth_ctrl.draw.connect(_draw_robot_mouth)
	_robot_node.add_child(_mouth_ctrl)
	_set_robot_mood(RobotMood.NEUTRAL)


## Малюємо рот залежно від настрою
func _draw_robot_mouth() -> void:
	if not is_instance_valid(_mouth_ctrl):
		return
	var w: float = MOUTH_WIDTH
	var h: float = 8.0
	match _robot_mood:
		RobotMood.HAPPY:
			## Усмішка — дуга вниз
			_mouth_ctrl.draw_arc(Vector2(w * 0.5, 0.0), w * 0.4, 0.2, PI - 0.2, 16, Color(0.2, 0.2, 0.3), 2.0)
		RobotMood.CONFUSED:
			## Здивований О
			_mouth_ctrl.draw_arc(Vector2(w * 0.5, h * 0.5), 3.5, 0.0, TAU, 12, Color(0.2, 0.2, 0.3), 2.0)
		RobotMood.BONK:
			## Хвиляста лінія (біль)
			var pts: PackedVector2Array = PackedVector2Array()
			for xi: int in 6:
				var xf: float = float(xi) * w / 5.0
				var yf: float = h * 0.5 + sin(float(xi) * 2.5) * 3.0
				pts.append(Vector2(xf, yf))
			if pts.size() >= 2:
				_mouth_ctrl.draw_polyline(pts, Color(0.2, 0.2, 0.3), 2.0)
		_:
			## Neutral — пряма лінія
			_mouth_ctrl.draw_line(Vector2(w * 0.2, h * 0.5), Vector2(w * 0.8, h * 0.5), Color(0.3, 0.3, 0.4), 2.0)


## Зміна настрою робота з перемальовкою рота
func _set_robot_mood(mood: int) -> void:
	_robot_mood = mood
	if is_instance_valid(_mouth_ctrl):
		_mouth_ctrl.queue_redraw()


func _spawn_command_buttons() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var grid_bottom: float = _grid_origin.y + float(_grid_size) * CELL_SIZE + 20.0
	## Команди стрічка
	_cmd_container = Node2D.new()
	_cmd_container.position = Vector2(0, grid_bottom)
	add_child(_cmd_container)
	_all_round_nodes.append(_cmd_container)
	## Кнопки напрямків — кольорові кола
	var dirs: Array[String] = ["left", "up", "down", "right"]
	var btn_y: float = grid_bottom + 40.0
	var total_w: float = float(dirs.size()) * (CMD_SIZE.x + CMD_GAP)
	var start_x: float = (vp.x - total_w) * 0.5
	for i: int in dirs.size():
		var d: String = dirs[i]
		var col: Color = DIR_COLORS.get(d, ROBOT_COLOR)
		var btn: Button = Button.new()
		btn.text = ""
		btn.size = CMD_SIZE
		btn.position = Vector2(start_x + float(i) * (CMD_SIZE.x + CMD_GAP), btn_y)
		## Soft circle кнопки — єдиний стиль з головним меню
		btn.add_theme_stylebox_override("normal", ThemeManager.make_soft_style(col, col.darkened(0.2), 999, false))
		btn.add_theme_stylebox_override("hover", ThemeManager.make_soft_style(col.lightened(0.05), col.darkened(0.15), 999, false))
		btn.add_theme_stylebox_override("pressed", ThemeManager.make_soft_style(col, col.darkened(0.2), 999, true))
		IconDraw.icon_in_button(btn, IconDraw.direction_arrow(d, 28.0))
		btn.pressed.connect(_on_cmd_pressed.bind(d))
		add_child(btn)
		JuicyEffects.button_press_squish(btn, self)
		_all_round_nodes.append(btn)
	## x2 кнопка повтору — тільки Preschool, раунди 2+
	if not _is_toddler and _round >= 2:
		_repeat_btn = Button.new()
		_repeat_btn.text = ""
		IconDraw.icon_in_button(_repeat_btn, IconDraw.cycle_arrows(28.0))
		_repeat_btn.size = CMD_SIZE
		_repeat_btn.position = Vector2(
			start_x + float(dirs.size()) * (CMD_SIZE.x + CMD_GAP), btn_y)
		_repeat_btn.theme_type_variation = &"CircleButton"
		_repeat_btn.pressed.connect(_on_repeat_pressed)
		add_child(_repeat_btn)
		JuicyEffects.button_press_squish(_repeat_btn, self)
		_all_round_nodes.append(_repeat_btn)


func _spawn_action_buttons() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Позиціюємо відносно нижнього краю кнопок напрямків (не сітки)
	var grid_bottom: float = _grid_origin.y + float(_grid_size) * CELL_SIZE + 20.0
	var dir_btn_y: float = grid_bottom + 40.0
	var action_y: float = dir_btn_y + CMD_SIZE.y + ACTION_BTN_GAP
	## Центруємо Play + Clear разом з зазором між ними
	var total_btn_w: float = ACTION_BTN_SIZE.x + ACTION_BTN_GAP + CLEAR_BTN_SIZE.x
	var start_x: float = (vp.x - total_btn_w) * 0.5
	## Play — gold accent pill
	_play_btn = Button.new()
	_play_btn.theme_type_variation = &"AccentButton"
	_play_btn.custom_minimum_size = ACTION_BTN_SIZE
	_play_btn.size = ACTION_BTN_SIZE
	IconDraw.icon_text_in_button(_play_btn,
		IconDraw.play_triangle(20.0), tr("BTN_PLAY"), 24, 8)
	_play_btn.position = Vector2(start_x, action_y)
	_play_btn.pressed.connect(_on_play_pressed)
	add_child(_play_btn)
	JuicyEffects.button_press_squish(_play_btn, self)
	_all_round_nodes.append(_play_btn)
	## Clear — glass circle (SecondaryButton — менш помітна, бо деструктивна)
	_clear_btn = Button.new()
	_clear_btn.theme_type_variation = &"SecondaryButton"
	_clear_btn.custom_minimum_size = CLEAR_BTN_SIZE
	_clear_btn.size = CLEAR_BTN_SIZE
	IconDraw.icon_in_button(_clear_btn, IconDraw.trash_can(24.0))
	_clear_btn.position = Vector2(start_x + ACTION_BTN_SIZE.x + ACTION_BTN_GAP, action_y)
	_clear_btn.pressed.connect(_on_clear_pressed)
	add_child(_clear_btn)
	JuicyEffects.button_press_squish(_clear_btn, self)
	_all_round_nodes.append(_clear_btn)


func _update_cmd_display() -> void:
	for p: Panel in _cmd_display:
		if is_instance_valid(p):
			p.queue_free()
	_cmd_display.clear()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var grid_bottom: float = _grid_origin.y + float(_grid_size) * CELL_SIZE + 12.0
	var item_size: float = 36.0
	var item_gap: float = 4.0
	var total_w: float = float(_commands.size()) * (item_size + item_gap)
	var start_x: float = (vp.x - total_w) * 0.5
	for i: int in _commands.size():
		var d: String = _commands[i]
		var col: Color = DIR_COLORS.get(d, ROBOT_COLOR)
		var cmd_panel: Panel = Panel.new()
		cmd_panel.size = Vector2(item_size, item_size)
		cmd_panel.position = Vector2(start_x + float(i) * (item_size + item_gap), grid_bottom)
		cmd_panel.add_theme_stylebox_override("panel",
			GameData.candy_circle(col, item_size * 0.5, false))
		cmd_panel.material = GameData.create_premium_material(0.04, 2.0, 0.0, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18) ## Grain overlay (LAW 28)
		var cmd_icon: Control = IconDraw.direction_arrow(d, item_size * 0.55)
		cmd_icon.position = Vector2(item_size * 0.22, item_size * 0.22)
		cmd_panel.add_child(cmd_icon)
		add_child(cmd_panel)
		_cmd_display.append(cmd_panel)
		_all_round_nodes.append(cmd_panel)


## ---- Preview line (Preschool) ----

## Створити Line2D для preview шляху — додається на сітку.
func _spawn_preview_line() -> void:
	if is_instance_valid(_preview_line):
		_preview_line.queue_free()
	_preview_line = Line2D.new()
	_preview_line.default_color = PREVIEW_LINE_COLOR
	_preview_line.width = PREVIEW_LINE_WIDTH
	_preview_line.z_index = 1  ## Поверх клітинок, під роботом
	add_child(_preview_line)
	_all_round_nodes.append(_preview_line)


## Оновити preview line на основі поточних _commands.
func _update_preview_line() -> void:
	if not is_instance_valid(_preview_line):
		return
	_preview_line.clear_points()
	if _commands.is_empty():
		return
	var pos: Vector2i = Vector2i.ZERO  ## Робот завжди стартує з (0,0)
	_preview_line.add_point(_cell_center(pos))
	for cmd: String in _commands:
		var delta: Vector2i = DIRECTIONS.get(cmd, Vector2i.ZERO)
		var new_pos: Vector2i = pos + delta
		## Перевірка меж — якщо виходить за сітку, зупиняємо
		if new_pos.x < 0 or new_pos.x >= _grid_size or \
			new_pos.y < 0 or new_pos.y >= _grid_size:
			break
		pos = new_pos
		_preview_line.add_point(_cell_center(pos))


## Очистити preview line.
func _clear_preview_line() -> void:
	if is_instance_valid(_preview_line):
		_preview_line.clear_points()


## ---- Toddler demo path ----

## Запуск демонстрації шляху для toddler — робот рухається повільно + trail.
func _run_toddler_demo() -> void:
	_input_locked = true
	_fade_instruction(_instruction_label, tr("ROBOT_LOST_HELP"))
	## Створити trail Line2D для демо
	_demo_trail = Line2D.new()
	_demo_trail.default_color = Color("6366f1", 0.35)
	_demo_trail.width = 4.0
	_demo_trail.z_index = 1
	add_child(_demo_trail)
	_all_round_nodes.append(_demo_trail)
	_demo_trail.add_point(_cell_center(_robot_pos))
	if _demo_path.is_empty():
		push_warning("AlgoRobot: _run_toddler_demo — demo_path empty")
		_input_locked = false
		_reset_idle_timer()
		return
	_execute_demo_step(0)


## Рекурсивне виконання одного кроку демо.
func _execute_demo_step(idx: int) -> void:
	if idx >= _demo_path.size():
		## Демо завершено — повернути робота на старт та розблокувати input
		_on_demo_complete()
		return
	if not is_instance_valid(_robot_node):
		push_warning("AlgoRobot: _execute_demo_step — robot freed")
		return
	var dir: String = _demo_path[idx]
	var delta: Vector2i = DIRECTIONS.get(dir, Vector2i.ZERO)
	var new_pos: Vector2i = _robot_pos + delta
	## Bounds guard
	if new_pos.x < 0 or new_pos.x >= _grid_size or \
		new_pos.y < 0 or new_pos.y >= _grid_size:
		push_warning("AlgoRobot: demo step out of bounds")
		_on_demo_complete()
		return
	_robot_pos = new_pos
	var target: Vector2 = _cell_center(new_pos)
	if SettingsManager.reduced_motion:
		_robot_node.position = target
		if is_instance_valid(_demo_trail):
			_demo_trail.add_point(target)
		_execute_demo_step(idx + 1)
		return
	var tw: Tween = _create_game_tween()
	tw.tween_property(_robot_node, "position", target, DEMO_MOVE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_demo_trail):
			_demo_trail.add_point(target)
		if not is_instance_valid(_robot_node):
			push_warning("AlgoRobot: robot freed during demo")
			return
		_execute_demo_step(idx + 1))


## Демо завершено — повернути робота, показати інструкцію, розблокувати.
func _on_demo_complete() -> void:
	## Невелика пауза щоб дитина побачила фінальну позицію
	var tw: Tween = _create_game_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		## Повернути робота на старт
		_robot_pos = Vector2i.ZERO
		if is_instance_valid(_robot_node):
			if SettingsManager.reduced_motion:
				_robot_node.position = _cell_center(Vector2i.ZERO)
			else:
				var back_tw: Tween = _create_game_tween()
				back_tw.tween_property(_robot_node, "position",
					_cell_center(Vector2i.ZERO), 0.3)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		## Прибрати trail
		if is_instance_valid(_demo_trail):
			_demo_trail.queue_free()
		_demo_trail = null
		## Переключити інструкцію
		_fade_instruction(_instruction_label, get_tutorial_instruction())
		_toddler_replay_idx = 0
		_input_locked = false
		_reset_idle_timer())


## ---- Commands ----

func _on_cmd_pressed(dir: String) -> void:
	if _input_locked or _game_over or _executing:
		return
	## Toddler "Follow My Path" — перевірка replay послідовності
	if _is_toddler and _demo_path.size() > 0:
		_handle_toddler_replay(dir)
		return
	var max_cmds: int = 5 if _is_toddler else (10 if _round >= 2 else 8)
	if _commands.size() >= max_cmds:
		return
	_commands.append(dir)
	AudioManager.play_sfx("click")
	_update_cmd_display()
	## Preschool: оновити preview line
	if not _is_toddler:
		_update_preview_line()
	_reset_idle_timer()


## Toddler "Follow My Path" — обробка натискання напрямку під час replay.
## A6: помилки не інкрементують _errors.
func _handle_toddler_replay(dir: String) -> void:
	if _toddler_replay_idx >= _demo_path.size():
		push_warning("AlgoRobot: _handle_toddler_replay — idx out of bounds")
		return
	var expected: String = _demo_path[_toddler_replay_idx]
	if dir == expected:
		## Правильний крок — рухаємо робота
		AudioManager.play_sfx("click")
		_commands.append(dir)
		_update_cmd_display()
		var delta: Vector2i = DIRECTIONS.get(dir, Vector2i.ZERO)
		var new_pos: Vector2i = _robot_pos + delta
		## Bounds guard
		if new_pos.x < 0 or new_pos.x >= _grid_size or \
			new_pos.y < 0 or new_pos.y >= _grid_size:
			push_warning("AlgoRobot: replay step out of bounds")
			return
		_robot_pos = new_pos
		_input_locked = true
		var target: Vector2 = _cell_center(new_pos)
		if SettingsManager.reduced_motion:
			if is_instance_valid(_robot_node):
				_robot_node.position = target
			_toddler_replay_idx += 1
			_check_toddler_replay_complete()
			return
		var tw: Tween = _create_game_tween()
		tw.tween_property(_robot_node, "position", target, MOVE_DURATION)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(_robot_node):
				push_warning("AlgoRobot: robot freed during replay")
				return
			_toddler_replay_idx += 1
			_check_toddler_replay_complete())
	else:
		## Неправильний крок — gentle feedback (A6: no _errors increment)
		_register_error(_robot_node)
		## Snap back: повернути робота на старт + очистити введені команди
		_input_locked = true
		_robot_pos = Vector2i.ZERO
		_commands.clear()
		_update_cmd_display()
		_toddler_replay_idx = 0
		if SettingsManager.reduced_motion:
			if is_instance_valid(_robot_node):
				_robot_node.position = _cell_center(Vector2i.ZERO)
			_input_locked = false
			_reset_idle_timer()
			return
		var tw: Tween = _create_game_tween()
		tw.tween_property(_robot_node, "position",
			_cell_center(Vector2i.ZERO), 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer())
	_reset_idle_timer()


## Перевірити чи toddler завершив replay повністю.
func _check_toddler_replay_complete() -> void:
	if _toddler_replay_idx >= _demo_path.size():
		## Весь шлях повторено правильно!
		_on_puzzle_solved()
	else:
		_input_locked = false
		_reset_idle_timer()


func _on_clear_pressed() -> void:
	if _input_locked or _game_over or _executing:
		return
	_commands.clear()
	_update_cmd_display()
	## Preschool: очистити preview line
	if not _is_toddler:
		_clear_preview_line()
	## Toddler replay: скинути прогрес
	if _is_toddler and _demo_path.size() > 0:
		_toddler_replay_idx = 0
		_robot_pos = Vector2i.ZERO
		if is_instance_valid(_robot_node):
			_robot_node.position = _cell_center(Vector2i.ZERO)
	AudioManager.play_sfx("click")


func _on_repeat_pressed() -> void:
	if _input_locked or _game_over or _executing:
		return
	if _commands.is_empty():
		return
	var max_cmds: int = 10
	if _commands.size() >= max_cmds:
		return
	var last_cmd: String = _commands[_commands.size() - 1]
	_commands.append(last_cmd)
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	_update_cmd_display()
	## Preschool: оновити preview line
	if not _is_toddler:
		_update_preview_line()
	_reset_idle_timer()


func _on_play_pressed() -> void:
	if _input_locked or _game_over or _executing or _commands.is_empty():
		return
	_executing = true
	_input_locked = true
	_execution_step = 0
	_last_move_dir = ""
	_set_robot_mood(RobotMood.NEUTRAL)
	## Preschool: прибрати preview line при запуску
	_clear_preview_line()
	_execute_commands(0)


func _execute_commands(idx: int) -> void:
	if idx >= _commands.size():
		## Перевірити чи робот на цілі
		if _robot_pos == _goal_pos:
			_on_puzzle_solved()
		else:
			_on_puzzle_failed()
		return
	var dir: String = _commands[idx]
	var delta_pos: Vector2i = DIRECTIONS.get(dir, Vector2i.ZERO)
	var new_pos: Vector2i = _robot_pos + delta_pos
	if new_pos.x < 0 or new_pos.x >= _grid_size or \
		new_pos.y < 0 or new_pos.y >= _grid_size:
		## Вдарився в стіну — bonk animation
		_play_wall_bonk(dir)
		return
	_robot_pos = new_pos
	var target: Vector2 = _cell_center(new_pos)
	_execution_step += 1
	## Audio: slide SFX з зростаючим pitch за кроком
	var pitch: float = SLIDE_PITCH_BASE + float(_execution_step) * SLIDE_PITCH_STEP
	AudioManager.play_sfx("slide", clampf(pitch, 0.8, 1.5))
	HapticsManager.vibrate_light()
	## Personality: wobble при зміні напрямку, stretch при русі вперед
	var direction_changed: bool = _last_move_dir != "" and _last_move_dir != dir
	_last_move_dir = dir
	## Перевірка декоративної клітинки — щасливий на воді, нейтральний на лаві
	if _themed_cells.has(new_pos):
		var cell_theme: int = _themed_cells.get(new_pos, THEME_NONE)
		if cell_theme == THEME_LAVA:
			_set_robot_mood(RobotMood.CONFUSED)
		elif cell_theme == THEME_WATER:
			_set_robot_mood(RobotMood.HAPPY)
	else:
		_set_robot_mood(RobotMood.NEUTRAL)
	if SettingsManager.reduced_motion:
		if is_instance_valid(_robot_node):
			_robot_node.position = target
		_execute_commands(idx + 1)
		return
	_move_tween = _create_game_tween()
	## Personality animation: wobble при повороті
	if direction_changed and is_instance_valid(_robot_node):
		var wobble_dir: float = 1.0 if dir in ["right", "down"] else -1.0
		_move_tween.tween_property(_robot_node, "rotation",
			WOBBLE_ANGLE * wobble_dir, 0.08)\
			.set_trans(Tween.TRANS_SINE)
		_move_tween.tween_property(_robot_node, "rotation", 0.0, 0.08)\
			.set_trans(Tween.TRANS_SINE)
	## Personality animation: stretch при русі вперед
	if is_instance_valid(_robot_node):
		_move_tween.tween_property(_robot_node, "scale",
			STRETCH_SCALE, MOVE_DURATION * 0.3)\
			.set_trans(Tween.TRANS_SINE)
	_move_tween.tween_property(_robot_node, "position", target, MOVE_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	## Повернути масштаб до нормального
	if is_instance_valid(_robot_node):
		_move_tween.tween_property(_robot_node, "scale",
			Vector2.ONE, MOVE_DURATION * 0.3)\
			.set_trans(Tween.TRANS_SINE)
	_move_tween.tween_callback(func() -> void:
		if not is_instance_valid(_robot_node):
			push_warning("AlgoRobot: robot freed during execution")
			return
		_execute_commands(idx + 1))


## ── Wall bonk animation — робот вдаряється в стіну та відскакує ──
func _play_wall_bonk(dir: String) -> void:
	_set_robot_mood(RobotMood.BONK)
	AudioManager.play_sfx("error")
	HapticsManager.vibrate_error()
	if not is_instance_valid(_robot_node):
		push_warning("AlgoRobot: _play_wall_bonk — robot freed")
		_on_puzzle_failed()
		return
	if SettingsManager.reduced_motion:
		_on_puzzle_failed()
		return
	## Bonk: рух до стіни на BONK_OFFSET пікселів, потім назад
	var bonk_delta: Vector2 = Vector2(
		DIRECTIONS.get(dir, Vector2i.ZERO).x,
		DIRECTIONS.get(dir, Vector2i.ZERO).y).normalized() * BONK_OFFSET
	var original_pos: Vector2 = _robot_node.position
	var bonk_tw: Tween = _create_game_tween()
	bonk_tw.tween_property(_robot_node, "position",
		original_pos + bonk_delta, 0.08)\
		.set_trans(Tween.TRANS_SINE)
	## Shake rotation
	bonk_tw.tween_property(_robot_node, "rotation", 0.12, 0.05)
	bonk_tw.tween_property(_robot_node, "rotation", -0.12, 0.05)
	bonk_tw.tween_property(_robot_node, "rotation", 0.0, 0.05)
	## Повернутися назад
	bonk_tw.tween_property(_robot_node, "position",
		original_pos, 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bonk_tw.tween_callback(func() -> void:
		if not is_instance_valid(_robot_node):
			push_warning("AlgoRobot: robot freed during bonk")
			return
		_on_puzzle_failed())


func _on_puzzle_solved() -> void:
	_set_robot_mood(RobotMood.HAPPY)
	_register_correct(_robot_node)
	## VFX: success ripple на позиції цілі
	if is_instance_valid(_goal_node):
		VFXManager.spawn_success_ripple(_goal_node.global_position, GOAL_COLOR)
		VFXManager.spawn_premium_celebration(_goal_node.global_position)
	AudioManager.play_sfx("success")
	## Optimal path bonus: backflip якщо розв'язав за мінімум кроків
	var is_optimal: bool = _optimal_length > 0 and _commands.size() == _optimal_length
	if is_optimal:
		_play_robot_backflip()
	else:
		_play_robot_dance()
	var d: float = 0.15 if SettingsManager.reduced_motion else 1.2
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round())


## Robot dance: themed victory per grid theme.
## THEME_NONE: spin + scale bounce. LAVA: fiery shake. WATER: wave wiggle.
func _play_robot_dance() -> void:
	if not is_instance_valid(_robot_node):
		push_warning("AlgoRobot: _play_robot_dance — robot freed")
		return
	if SettingsManager.reduced_motion:
		return
	match _current_theme:
		THEME_LAVA:
			_play_lava_victory()
		THEME_WATER:
			_play_water_victory()
		_:
			_play_default_victory()


## Default victory: spin 360 + scale bounce
func _play_default_victory() -> void:
	if not is_instance_valid(_robot_node):
		push_warning("AlgoRobot: _play_default_victory — robot freed")
		return
	var dance_tw: Tween = _create_game_tween().set_parallel(true)
	dance_tw.tween_property(_robot_node, "rotation",
		TAU, 0.5)\
		.from(0.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var scale_tw: Tween = _create_game_tween()
	scale_tw.tween_property(_robot_node, "scale",
		Vector2(1.3, 1.3), 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tw.tween_property(_robot_node, "scale",
		Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## Lava victory: швидкі tremor-shake + яскравий scale pop
func _play_lava_victory() -> void:
	if not is_instance_valid(_robot_node):
		push_warning("AlgoRobot: _play_lava_victory — robot freed")
		return
	var tw: Tween = _create_game_tween()
	## Tremor shake — 3 швидких нахили
	for shake_i: int in 3:
		var angle: float = 0.18 * (1.0 if shake_i % 2 == 0 else -1.0)
		tw.tween_property(_robot_node, "rotation", angle, 0.06)
	tw.tween_property(_robot_node, "rotation", 0.0, 0.06)
	## Scale pop: 1.0 -> 1.4 -> 1.0 (fiery burst)
	tw.tween_property(_robot_node, "scale",
		Vector2(1.4, 1.4), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_robot_node, "scale",
		Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Water victory: плавні хвилі — коливання вліво-вправо + м'який bounce
func _play_water_victory() -> void:
	if not is_instance_valid(_robot_node):
		push_warning("AlgoRobot: _play_water_victory — robot freed")
		return
	var original_x: float = _robot_node.position.x
	var tw: Tween = _create_game_tween()
	## Wave wiggle — 2 повні хвилі
	for wave_i: int in 4:
		var offset_x: float = 6.0 * (1.0 if wave_i % 2 == 0 else -1.0)
		tw.tween_property(_robot_node, "position:x",
			original_x + offset_x, 0.1)\
			.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_robot_node, "position:x", original_x, 0.1)\
		.set_trans(Tween.TRANS_SINE)
	## Soft scale bounce
	tw.tween_property(_robot_node, "scale",
		Vector2(1.15, 1.25), 0.15)\
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_robot_node, "scale",
		Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_SINE)


## ── Backflip за optimal path: подвійний spin + вертикальний стрибок ──
func _play_robot_backflip() -> void:
	if not is_instance_valid(_robot_node):
		push_warning("AlgoRobot: _play_robot_backflip — robot freed")
		return
	if SettingsManager.reduced_motion:
		return
	AudioManager.play_sfx("reward")
	var original_y: float = _robot_node.position.y
	var flip_tw: Tween = _create_game_tween().set_parallel(true)
	## Подвійний spin (2 * TAU)
	flip_tw.tween_property(_robot_node, "rotation",
		TAU * 2.0, BACKFLIP_DURATION)\
		.from(0.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	## Вертикальний стрибок: вгору на 30px, потім назад
	var jump_tw: Tween = _create_game_tween()
	jump_tw.tween_property(_robot_node, "position:y",
		original_y - 30.0, BACKFLIP_DURATION * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	jump_tw.tween_property(_robot_node, "position:y",
		original_y, BACKFLIP_DURATION * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	## Scale: squash-stretch під час стрибка
	var squash_tw: Tween = _create_game_tween()
	squash_tw.tween_property(_robot_node, "scale",
		Vector2(0.8, 1.3), BACKFLIP_DURATION * 0.25)
	squash_tw.tween_property(_robot_node, "scale",
		Vector2(1.2, 0.85), BACKFLIP_DURATION * 0.25)
	squash_tw.tween_property(_robot_node, "scale",
		Vector2(0.9, 1.15), BACKFLIP_DURATION * 0.25)
	squash_tw.tween_property(_robot_node, "scale",
		Vector2.ONE, BACKFLIP_DURATION * 0.25)


func _on_puzzle_failed() -> void:
	_set_robot_mood(RobotMood.CONFUSED)
	if _is_toddler:
		_register_error(_robot_node)  ## A11: scaffolding для тоддлера
	else:
		_errors += 1
		_register_error(_robot_node)
	## Preschool: очистити preview line
	_clear_preview_line()
	## Повернути робота на старт
	_robot_pos = Vector2i.ZERO
	if SettingsManager.reduced_motion:
		if is_instance_valid(_robot_node):
			_robot_node.position = _cell_center(Vector2i.ZERO)
		_commands.clear()
		_update_cmd_display()
		_executing = false
		_input_locked = false
		_set_robot_mood(RobotMood.NEUTRAL)
		_reset_idle_timer()
		return
	var tw: Tween = _create_game_tween()
	tw.tween_property(_robot_node, "position", _cell_center(Vector2i.ZERO), 0.3)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(_robot_node):
			push_warning("AlgoRobot: robot freed during fail reset")
			return
		_commands.clear()
		_update_cmd_display()
		_executing = false
		_input_locked = false
		_set_robot_mood(RobotMood.NEUTRAL)
		_reset_idle_timer())


## ---- Exit pause cleanup ----

func _on_exit_pause() -> void:
	if not _executing:
		return
	## Kill active move tween — інакше callback chain заморожена через paused tree
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null
	_executing = false
	_input_locked = false
	_robot_pos = Vector2i.ZERO
	if is_instance_valid(_robot_node):
		_robot_node.position = _cell_center(Vector2i.ZERO)
		_robot_node.rotation = 0.0
		_robot_node.scale = Vector2.ONE
	_commands.clear()
	_update_cmd_display()
	_clear_preview_line()
	_toddler_replay_idx = 0
	_set_robot_mood(RobotMood.NEUTRAL)
	_last_move_dir = ""
	_execution_step = 0


## ---- Round management ----

func _clear_round() -> void:
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_cmd_display.clear()
	_commands.clear()
	_demo_path.clear()
	_toddler_replay_idx = 0
	_robot_node = null
	_goal_node = null
	_cmd_container = null
	_play_btn = null
	_clear_btn = null
	_repeat_btn = null
	_preview_line = null
	_demo_trail = null
	## Cleanup personality state (A9: round hygiene)
	_left_eye = null
	_right_eye = null
	_left_pupil = null
	_right_pupil = null
	_mouth_ctrl = null
	_robot_mood = RobotMood.NEUTRAL
	_themed_cells.clear()
	_theme_overlays.clear()
	_last_move_dir = ""
	_execution_step = 0
	_optimal_length = 0


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
	if _goal_node and is_instance_valid(_goal_node):
		_pulse_node(_goal_node, 1.2)
	_reset_idle_timer()
