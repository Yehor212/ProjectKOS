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
	_generate_puzzle()
	_spawn_grid()
	_spawn_robot_and_goal()
	_spawn_command_buttons()
	_spawn_action_buttons()
	## Preschool: створити preview line (порожню)
	if not _is_toddler:
		_spawn_preview_line()
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.3
	var tw: Tween = create_tween()
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
	var tw: Tween = create_tween()
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
	var tw: Tween = create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		## Повернути робота на старт
		_robot_pos = Vector2i.ZERO
		if is_instance_valid(_robot_node):
			if SettingsManager.reduced_motion:
				_robot_node.position = _cell_center(Vector2i.ZERO)
			else:
				var back_tw: Tween = create_tween()
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
		var tw: Tween = create_tween()
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
		var tw: Tween = create_tween()
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
		## Вдарився в стіну
		_on_puzzle_failed()
		return
	_robot_pos = new_pos
	var target: Vector2 = _cell_center(new_pos)
	HapticsManager.vibrate_light()
	if SettingsManager.reduced_motion:
		_robot_node.position = target
		_execute_commands(idx + 1)
		return
	_move_tween = create_tween()
	_move_tween.tween_property(_robot_node, "position", target, MOVE_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_move_tween.tween_callback(func() -> void: _execute_commands(idx + 1))


func _on_puzzle_solved() -> void:
	_register_correct(_robot_node)
	if is_instance_valid(_goal_node):
		VFXManager.spawn_premium_celebration(_goal_node.global_position)
	## Robot dance: spin + scale bounce (замість просто celebration)
	_play_robot_dance()
	var d: float = 0.15 if SettingsManager.reduced_motion else 1.0
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round())


## Robot dance: spin 360° + scale bounce 1.0→1.3→1.0 при success.
func _play_robot_dance() -> void:
	if not is_instance_valid(_robot_node):
		push_warning("AlgoRobot: _play_robot_dance — robot freed")
		return
	if SettingsManager.reduced_motion:
		return
	var dance_tw: Tween = create_tween().set_parallel(true)
	## Spin: rotation 0 → 2*PI за 0.5с
	dance_tw.tween_property(_robot_node, "rotation",
		TAU, 0.5)\
		.from(0.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	## Scale bounce: 1.0 → 1.3 → 1.0
	var scale_tw: Tween = create_tween()
	scale_tw.tween_property(_robot_node, "scale",
		Vector2(1.3, 1.3), 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tw.tween_property(_robot_node, "scale",
		Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _on_puzzle_failed() -> void:
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
		_reset_idle_timer()
		return
	var tw: Tween = create_tween()
	tw.tween_property(_robot_node, "position", _cell_center(Vector2i.ZERO), 0.3)
	tw.tween_callback(func() -> void:
		_commands.clear()
		_update_cmd_display()
		_executing = false
		_input_locked = false
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
