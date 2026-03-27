extends BaseMiniGame

## PRE-30 Квест рыцаря / Knight's Quest — пригодницька карта з лісом та замком!
## Preschool: 4 раунди, 5x5 сітка. Хід конем: Г-подібний (2+1).
##   Зірки = скарби, дружні дракони на порожніх клітинках.
##   Збір обладунків: щит → шолом → меч → плащ. Після 4-го — лицар дружить з драконом.
##   L-move preview при наведенні на валідну клітинку.
## Toddler: "Пригоди коника" — 5 раундів, 3x3 сітка, збирай зірки.
## Показуємо можливі ходи підсвіченими клітинками.
## Лічильник ходів — зірки за ефективність (тільки Preschool).

const TOTAL_ROUNDS: int = 4
const GRID_SIZE: int = 5
const CELL_SIZE: float = 84.0
const IDLE_HINT_DELAY: float = 6.0
const CELL_COLOR_LIGHT: Color = Color(0.78, 0.90, 0.72, 0.98)  ## Лісова полянка
const CELL_COLOR_DARK: Color = Color(0.38, 0.56, 0.32, 0.98)   ## Густий ліс
const HIGHLIGHT_COLOR: Color = Color("fbbf24", 0.92)            ## Золоте підсвічування (скарби)
const KNIGHT_COLOR: Color = Color("4f46e5")
const GOAL_COLOR: Color = Color("fbbf24")
const SAFETY_TIMEOUT_SEC: float = 120.0
## Палітра пригодницької карти
const TRAIL_PREVIEW_COLOR: Color = Color("fbbf24", 0.6)  ## Пунктирний L-шлях (preview)
const TRAIL_DONE_COLOR: Color = Color("22c55e", 0.7)     ## L-шлях після ходу
const DRAGON_COLOR: Color = Color("f97316")               ## Дружній дракон (оранжевий)
const TREE_COLOR: Color = Color("22c55e")                 ## Дерева на порожніх клітинках
const ARMOR_NAMES: Array[String] = ["shield", "helmet", "sword", "cape"]
const ARMOR_COLORS: Array[Color] = [
	Color("6366f1"), Color("a78bfa"), Color("38bdf8"), Color("ef476f"),
]

## Toddler-режим: "Пригоди коника" — збирай зірки на маленькій сітці
const TODDLER_GRID_SIZE: int = 3
const TODDLER_CELL_SIZE: float = 130.0
const TODDLER_TOTAL_ROUNDS: int = 5
const TODDLER_STAR_COLOR: Color = Color("fbbf24")
const TODDLER_HIGHLIGHT_COLOR: Color = Color("fbbf24", 0.88)  ## Золоте підсвічування — скарб
## Кількість зірок на раунд: R1=1, R2=1, R3=2, R4=2, R5=3
const TODDLER_STARS_PER_ROUND: Array[int] = [1, 1, 2, 2, 3]

## Можливі зміщення коня (Г: 2+1)
const KNIGHT_OFFSETS: Array[Vector2i] = [
	Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, -2), Vector2i(-1, 2),
	Vector2i(1, -2), Vector2i(1, 2), Vector2i(2, -1), Vector2i(2, 1),
]

## Toddler: простий рух у 4 сторони (вгору/вниз/вліво/вправо)
const ADJACENT_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
]

var _round: int = 0
var _moves: int = 0
var _min_moves: int = 0
var _total_moves: int = 0
var _total_min_moves: int = 0
var _start_time: float = 0.0

var _knight_pos: Vector2i = Vector2i.ZERO
var _goal_pos: Vector2i = Vector2i.ZERO
var _grid_origin: Vector2 = Vector2.ZERO
var _knight_node: Node2D = null
var _goal_node: Node2D = null
var _highlight_cells: Array[Panel] = []
var _all_round_nodes: Array[Node] = []

var _moves_label: Label = null
var _idle_timer: SceneTreeTimer = null

## Preschool: анімований trail для L-ходу
var _trail_line: Line2D = null

## Toddler-режим
var _is_toddler: bool = false
var _toddler_stars: Array[Vector2i] = []
var _toddler_stars_collected: int = 0
var _toddler_star_nodes: Array[Node2D] = []
var _toddler_grid_origin: Vector2 = Vector2.ZERO

## Пригодницька карта: L-move preview, декоративні дракони, дерева
var _preview_line: Line2D = null
var _decor_nodes: Array[Node2D] = []  ## Дерева + дракони (чистяться в _clear_round)

## Обладунки лицаря: збираються по 1 за раунд (Preschool)
## 0=shield, 1=helmet, 2=sword, 3=cape
var _armor_collected: int = 0
var _armor_hud_icons: Array[Panel] = []
var _armor_hud: HBoxContainer = null


func _ready() -> void:
	game_id = "knight_path"
	bg_theme = "puzzle"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	if not _is_toddler:
		_build_armor_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("KNIGHT_TREASURE_HUNT")
	return tr("KNIGHT_QUEST_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	if _highlight_cells.is_empty():
		return {}
	var cell: Panel = _highlight_cells[0]
	return {"type": "tap", "target": cell.global_position + cell.size * 0.5}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction(), 26)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_moves_label = Label.new()
	_moves_label.add_theme_font_size_override("font_size", 22)
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moves_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_moves_label.position = Vector2(0, _sa_top + 123)
	_moves_label.size = Vector2(vp.x, 22)
	_moves_label.visible = not _is_toddler  ## Toddler не бачить лічильник ходів
	add_child(_moves_label)


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_moves = 0
	if _is_toddler:
		_start_round_toddler()
		return
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_generate_puzzle()
	_spawn_grid()
	_spawn_knight_and_goal()
	_update_moves_label()
	_show_valid_moves()
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.3
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _generate_puzzle() -> void:
	## Старт — випадкова позиція
	_knight_pos = Vector2i(randi() % GRID_SIZE, randi() % GRID_SIZE)
	## Ціль — BFS, прогресивна складність по раундах
	var target_depth: int = _scale_by_round_i(2, 4, _round, TOTAL_ROUNDS)
	_goal_pos = _find_goal_bfs(_knight_pos, target_depth)
	_min_moves = _bfs_distance(_knight_pos, _goal_pos)


func _find_goal_bfs(start: Vector2i, depth: int) -> Vector2i:
	## Знайти всі клітинки на відстані depth ходів
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = 0
	var at_depth: Array[Vector2i] = []
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var d: int = visited[pos]
		if d == depth:
			at_depth.append(pos)
			continue
		if d > depth:
			continue
		for offset: Vector2i in KNIGHT_OFFSETS:
			var npos: Vector2i = pos + offset
			if npos.x >= 0 and npos.x < GRID_SIZE and \
				npos.y >= 0 and npos.y < GRID_SIZE and \
				not visited.has(npos):
				visited[npos] = d + 1
				queue.append(npos)
	if at_depth.is_empty():
		## Fallback — будь-яка клітинка не на старті
		for key: Vector2i in visited:
			if key != start:
				at_depth.append(key)
	at_depth.shuffle()
	return at_depth[0] if not at_depth.is_empty() else Vector2i(GRID_SIZE - 1, GRID_SIZE - 1)


func _bfs_distance(from: Vector2i, to: Vector2i) -> int:
	if from == to:
		return 0
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [from]
	visited[from] = 0
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		for offset: Vector2i in KNIGHT_OFFSETS:
			var npos: Vector2i = pos + offset
			if npos == to:
				return visited[pos] + 1
			if npos.x >= 0 and npos.x < GRID_SIZE and \
				npos.y >= 0 and npos.y < GRID_SIZE and \
				not visited.has(npos):
				visited[npos] = visited[pos] + 1
				queue.append(npos)
	return 99


func _spawn_grid() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var total: float = float(GRID_SIZE) * CELL_SIZE
	_grid_origin = Vector2((vp.x - total) * 0.5, 100.0)
	## Текстурна дошка під сіткою — лісова текстура
	var board_pad: float = 12.0
	var board: TextureRect = TextureRect.new()
	board.size = Vector2(total + board_pad * 2.0, total + board_pad * 2.0)
	board.position = _grid_origin - Vector2(board_pad, board_pad)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var board_tex_path: String = "res://assets/textures/backtiles/backtile_08.png"
	if ResourceLoader.exists(board_tex_path):
		board.texture = load(board_tex_path)
	board.modulate = Color(0.85, 0.95, 0.80, 0.25)  ## Зеленуватий відтінок — ліс
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	_all_round_nodes.append(board)
	var idx: int = 0
	var grid_cells: Array[Panel] = []
	for row: int in GRID_SIZE:
		for col: int in GRID_SIZE:
			var cell: Panel = Panel.new()
			cell.size = Vector2(CELL_SIZE - 4.0, CELL_SIZE - 4.0)
			cell.position = _grid_origin + Vector2(
				float(col) * CELL_SIZE + 2.0, float(row) * CELL_SIZE + 2.0)
			var is_light: bool = (row + col) % 2 == 0
			var style: StyleBoxFlat = GameData.candy_cell(
				CELL_COLOR_LIGHT if is_light else CELL_COLOR_DARK, 10)
			cell.add_theme_stylebox_override("panel", style)
			## Tile текстура на клітинках — зелені/оранжеві для лісу (LAW 28)
			var tile_color: String = "green" if is_light else "orange"
			var tile_path: String = "res://assets/textures/tiles/%s/tile_%02d.png" % [tile_color, (idx % 10) + 1]
			cell.material = GameData.create_premium_material(
				0.03, 2.0, 0.03, 0.06, 0.04, 0.03, 0.05, tile_path, 0.2, 0.08, 0.20, 0.18)
			cell.pivot_offset = cell.size / 2.0
			cell.scale = Vector2.ZERO
			add_child(cell)
			_all_round_nodes.append(cell)
			grid_cells.append(cell)
			idx += 1
	_staggered_spawn(grid_cells, 0.04)
	## Декорації лісової карти: дерева + дракони на порожніх клітинках
	_spawn_map_decorations()


func _cell_center(grid_pos: Vector2i) -> Vector2:
	return _grid_origin + Vector2(
		float(grid_pos.x) * CELL_SIZE + CELL_SIZE * 0.5,
		float(grid_pos.y) * CELL_SIZE + CELL_SIZE * 0.5)


func _spawn_knight_and_goal() -> void:
	## Ціль — скарб (зірка/діамант)
	_goal_node = Node2D.new()
	_goal_node.position = _cell_center(_goal_pos)
	_goal_node.z_index = 2
	add_child(_goal_node)
	var goal_panel: Panel = Panel.new()
	var gsz: float = CELL_SIZE * 0.7
	goal_panel.size = Vector2(gsz, gsz)
	goal_panel.position = Vector2(-gsz * 0.5, -gsz * 0.5)
	var gs: StyleBoxFlat = GameData.candy_circle(GOAL_COLOR, gsz * 0.5, true)
	goal_panel.add_theme_stylebox_override("panel", gs)
	goal_panel.material = GameData.create_premium_material(
		0.05, 2.0, 0.04, 0.08, 0.04, 0.03, 0.05, "", 0.0, 0.12, 0.30, 0.25) ## Premium overlay (LAW 28)
	_goal_node.add_child(goal_panel)
	## HQ текстура зірки (скарб) замість code-drawn
	var star_tex_path: String = "res://assets/textures/game_icons/icon_star.png"
	if ResourceLoader.exists(star_tex_path):
		var star_tex: Texture2D = load(star_tex_path)
		var star_sz: float = gsz * 0.8
		var star_ctrl: Control = Control.new()
		star_ctrl.size = Vector2(star_sz, star_sz)
		star_ctrl.position = Vector2(-gsz * 0.4, -gsz * 0.4)
		star_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star_ctrl.draw.connect(func() -> void:
			star_ctrl.draw_texture_rect(star_tex, Rect2(Vector2.ZERO, Vector2(star_sz, star_sz)), false)
		)
		_goal_node.add_child(star_ctrl)
	else:
		var goal_icon: Control = IconDraw.diamond(gsz * 0.7, GOAL_COLOR)
		goal_icon.position = Vector2(-gsz * 0.5, -gsz * 0.5)
		goal_icon.size = Vector2(gsz, gsz)
		_goal_node.add_child(goal_icon)
	_all_round_nodes.append(_goal_node)
	_pulse_goal()
	## Кінь
	_knight_node = Node2D.new()
	_knight_node.position = _cell_center(_knight_pos)
	add_child(_knight_node)
	var knight_panel: Panel = Panel.new()
	var ksz: float = CELL_SIZE * 0.7
	knight_panel.size = Vector2(ksz, ksz)
	knight_panel.position = Vector2(-ksz * 0.5, -ksz * 0.5)
	var ks: StyleBoxFlat = GameData.candy_cell(KNIGHT_COLOR, 12)
	knight_panel.add_theme_stylebox_override("panel", ks)
	knight_panel.material = GameData.create_premium_material(
		0.04, 2.0, 0.04, 0.06, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.25, 0.20) ## Premium overlay (LAW 28)
	_knight_node.add_child(knight_panel)
	## HQ текстура коня замість code-drawn
	var knight_tex_path: String = "res://assets/textures/game_icons/icon_knight.png"
	if ResourceLoader.exists(knight_tex_path):
		var knight_tex: Texture2D = load(knight_tex_path)
		var knight_sz: float = ksz * 0.8
		var knight_ctrl: Control = Control.new()
		knight_ctrl.size = Vector2(knight_sz, knight_sz)
		knight_ctrl.position = Vector2(-ksz * 0.4, -ksz * 0.4)
		knight_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		knight_ctrl.draw.connect(func() -> void:
			knight_ctrl.draw_texture_rect(knight_tex, Rect2(Vector2.ZERO, Vector2(knight_sz, knight_sz)), false)
		)
		_knight_node.add_child(knight_ctrl)
	else:
		var knight_icon: Control = IconDraw.chess_knight(ksz * 0.7, KNIGHT_COLOR)
		knight_icon.position = Vector2(-ksz * 0.5, -ksz * 0.5)
		knight_icon.size = Vector2(ksz, ksz)
		_knight_node.add_child(knight_icon)
	_all_round_nodes.append(_knight_node)


func _pulse_goal() -> void:
	if not is_instance_valid(_goal_node):
		return
	if SettingsManager.reduced_motion:
		return
	var tw: Tween = _create_game_tween().set_loops()
	tw.tween_property(_goal_node, "scale", Vector2(1.08, 1.08), 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_goal_node, "scale", Vector2.ONE, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_moves_label() -> void:
	_moves_label.text = tr("KNIGHT_MOVES") % [_moves, _min_moves]


## ---- Показ допустимих ходів ----

func _show_valid_moves() -> void:
	_clear_highlights()
	_clear_preview_line()
	for offset: Vector2i in KNIGHT_OFFSETS:
		var target: Vector2i = _knight_pos + offset
		if target.x < 0 or target.x >= GRID_SIZE or \
			target.y < 0 or target.y >= GRID_SIZE:
			continue
		var cell: Panel = Panel.new()
		var sz: float = CELL_SIZE - 6.0
		cell.size = Vector2(sz, sz)
		cell.position = _grid_origin + Vector2(
			float(target.x) * CELL_SIZE + 3.0,
			float(target.y) * CELL_SIZE + 3.0)
		var style: StyleBoxFlat = GameData.candy_cell(HIGHLIGHT_COLOR, 10, true)
		style.border_color = Color("fbbf24", 0.9)
		style.set_border_width_all(2)
		style.shadow_color = Color("fbbf24", 0.3)
		style.shadow_size = 8
		cell.add_theme_stylebox_override("panel", style)
		cell.material = GameData.create_premium_material(
			0.03, 2.0, 0.03, 0.06, 0.04, 0.03, 0.05, "", 0.0, 0.08, 0.20, 0.18) ## Premium overlay (LAW 28)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(_on_highlight_input.bind(target))
		## L-шлях preview при наведенні (Preschool)
		cell.mouse_entered.connect(_show_l_preview.bind(target))
		cell.mouse_exited.connect(_clear_preview_line)
		add_child(cell)
		_highlight_cells.append(cell)
		_all_round_nodes.append(cell)


func _clear_highlights() -> void:
	_clear_preview_line()
	for cell: Panel in _highlight_cells:
		if is_instance_valid(cell):
			cell.queue_free()
	_highlight_cells.clear()


## ---- Input ----

func _on_highlight_input(event: InputEvent, target_pos: Vector2i) -> void:
	if _input_locked or _game_over:
		return
	if event is InputEventMouseButton and event.pressed and \
		event.button_index == MOUSE_BUTTON_LEFT:
		_move_knight_to(target_pos)
	elif event is InputEventScreenTouch and event.pressed and event.index == 0:
		_move_knight_to(target_pos)


func _move_knight_to(target_pos: Vector2i) -> void:
	_input_locked = true
	var old_pos: Vector2i = _knight_pos
	var old_dist: int = _bfs_distance(_knight_pos, _goal_pos)
	_knight_pos = target_pos
	_moves += 1
	_update_moves_label()
	AudioManager.play_sfx("whoosh")  ## Свист при кожному ході лицаря
	var new_dist: int = _bfs_distance(_knight_pos, _goal_pos)
	## Субоптимальний хід: не наблизився до цілі → A7 + A11 scaffolding
	if new_dist > 0 and new_dist >= old_dist:
		if not _is_toddler:
			_errors += 1
		_register_error(_knight_node)
	else:
		_register_correct(_knight_node)
		## VFX sparkle на правильному ході (LAW 28)
		VFXManager.spawn_correct_sparkle(_cell_center(target_pos))
	_clear_highlights()
	## Preschool: анімований trail L-ходу
	_spawn_l_move_trail(old_pos, target_pos)
	var target_px: Vector2 = _cell_center(target_pos)
	if SettingsManager.reduced_motion:
		_knight_node.position = target_px
		_knight_node.scale = Vector2.ONE
		if _knight_pos == _goal_pos:
			_on_puzzle_solved()
		else:
			_show_valid_moves()
			_input_locked = false
			_reset_idle_timer()
		return
	var tw: Tween = _create_game_tween()
	## Стиснення перед стрибком
	tw.tween_property(_knight_node, "scale", Vector2(1.2, 0.8), 0.08)
	## Стрибок з розтягуванням
	tw.tween_property(_knight_node, "position", target_px, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_knight_node, "scale", Vector2(0.85, 1.15), 0.12)
	## Приземлення
	tw.tween_property(_knight_node, "scale", Vector2(1.15, 0.85), 0.06)
	tw.tween_property(_knight_node, "scale", Vector2.ONE, 0.1)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if _knight_pos == _goal_pos:
			_on_puzzle_solved()
		else:
			_show_valid_moves()
			_input_locked = false
			_reset_idle_timer())


func _on_puzzle_solved() -> void:
	_register_correct(_knight_node)
	_total_moves += _moves
	_total_min_moves += _min_moves
	AudioManager.play_sfx("coin")  ## Скарб знайдено!
	## VFX: використовуємо позицію коня як fallback (toddler не має _goal_node)
	var vfx_pos: Vector2
	if is_instance_valid(_goal_node):
		vfx_pos = _goal_node.global_position
	elif _is_toddler and is_instance_valid(_knight_node):
		vfx_pos = _knight_node.global_position
	else:
		vfx_pos = _toddler_cell_center(_knight_pos) if _is_toddler else _cell_center(_knight_pos)
	VFXManager.spawn_match_sparkle(vfx_pos)
	VFXManager.spawn_premium_celebration(vfx_pos)
	## Переможний танець коня: bounce + rotate
	_animate_knight_victory_dance()
	## Обладунок за раунд (Preschool): щит → шолом → меч → плащ
	if not _is_toddler and _armor_collected < ARMOR_NAMES.size():
		_award_armor_piece()
	var total: int = TODDLER_TOTAL_ROUNDS if _is_toddler else TOTAL_ROUNDS
	var d2: float = 0.15 if SettingsManager.reduced_motion else 0.8
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d2)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= total:
			_finish()
		else:
			_start_round())


## ---- Round management ----

func _clear_round() -> void:
	_clear_highlights()
	_clear_preview_line()
	## Очистити trail, якщо є
	if is_instance_valid(_trail_line):
		_trail_line.queue_free()
	_trail_line = null
	## Очистити декоративні елементи (дерева, дракони)
	for decor: Node2D in _decor_nodes:
		if is_instance_valid(decor):
			decor.queue_free()
	_decor_nodes.clear()
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_highlight_cells.clear()
	_knight_node = null
	_goal_node = null
	_toddler_star_nodes.clear()
	_toddler_stars.clear()
	_toddler_stars_collected = 0


func _finish() -> void:
	_game_over = true
	_input_locked = true
	## Preschool: фінальна сцена — лицар у повному обладунку дружить з драконом
	if not _is_toddler and _armor_collected >= ARMOR_NAMES.size():
		_animate_dragon_friend_finale()
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var total: int = TODDLER_TOTAL_ROUNDS if _is_toddler else TOTAL_ROUNDS
	## Toddler завжди отримує 5 зірок (A6 — помилки не рахуються)
	var earned: int = 5 if _is_toddler else _calculate_stars(_total_moves - _total_min_moves)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": total, "earned_stars": earned,
		"armor_collected": _armor_collected})


## ---- Toddler mode: "Пригоди коника" ----

func _start_round_toddler() -> void:
	var total: int = TODDLER_TOTAL_ROUNDS
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, total])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	## Кінь завжди стартує з центру 3x3 сітки
	_knight_pos = Vector2i(1, 1)
	## Генерація зірок
	var star_count: int = TODDLER_STARS_PER_ROUND[mini(_round, TODDLER_STARS_PER_ROUND.size() - 1)]
	_toddler_stars = _generate_toddler_stars(star_count)
	_toddler_stars_collected = 0
	## Побудова сітки та об'єктів
	_spawn_toddler_grid()
	_spawn_toddler_knight()
	_spawn_toddler_stars()
	_show_toddler_valid_moves()
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.3
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _generate_toddler_stars(count: int) -> Array[Vector2i]:
	## Розмістити зірки на досяжних позиціях (1-2 ходи від коня, 4-direction)
	var result: Array[Vector2i] = []
	var reachable: Array[Vector2i] = []
	## BFS від позиції коня, глибина до 2, простий рух (ADJACENT_OFFSETS)
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [_knight_pos]
	visited[_knight_pos] = 0
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var depth: int = visited[pos]
		if depth > 0:
			reachable.append(pos)
		if depth >= 2:
			continue
		for offset: Vector2i in ADJACENT_OFFSETS:
			var npos: Vector2i = pos + offset
			if npos.x >= 0 and npos.x < TODDLER_GRID_SIZE and \
				npos.y >= 0 and npos.y < TODDLER_GRID_SIZE and \
				not visited.has(npos):
				visited[npos] = depth + 1
				queue.append(npos)
	reachable.shuffle()
	for i: int in mini(count, reachable.size()):
		result.append(reachable[i])
	if result.is_empty():
		## Fallback: будь-яка клітинка, що не є конем
		for row: int in TODDLER_GRID_SIZE:
			for col: int in TODDLER_GRID_SIZE:
				var pos: Vector2i = Vector2i(col, row)
				if pos != _knight_pos:
					result.append(pos)
					if result.size() >= count:
						break
			if result.size() >= count:
				break
		push_warning("knight_path: toddler stars fallback — не знайшли BFS-досяжних клітинок")
	return result


func _spawn_toddler_grid() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var total_sz: float = float(TODDLER_GRID_SIZE) * TODDLER_CELL_SIZE
	_toddler_grid_origin = Vector2((vp.x - total_sz) * 0.5, 140.0)
	## Текстурна дошка під сіткою
	var board_pad: float = 14.0
	var board: TextureRect = TextureRect.new()
	board.size = Vector2(total_sz + board_pad * 2.0, total_sz + board_pad * 2.0)
	board.position = _toddler_grid_origin - Vector2(board_pad, board_pad)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var board_tex_path: String = "res://assets/textures/backtiles/backtile_08.png"
	if ResourceLoader.exists(board_tex_path):
		board.texture = load(board_tex_path)
	board.modulate = Color(0.85, 0.95, 0.80, 0.3)  ## Зеленуватий відтінок — ліс
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	_all_round_nodes.append(board)
	var idx: int = 0
	var grid_cells: Array[Panel] = []
	for row: int in TODDLER_GRID_SIZE:
		for col: int in TODDLER_GRID_SIZE:
			var cell: Panel = Panel.new()
			cell.size = Vector2(TODDLER_CELL_SIZE - 4.0, TODDLER_CELL_SIZE - 4.0)
			cell.position = _toddler_grid_origin + Vector2(
				float(col) * TODDLER_CELL_SIZE + 2.0, float(row) * TODDLER_CELL_SIZE + 2.0)
			var is_light: bool = (row + col) % 2 == 0
			var style: StyleBoxFlat = GameData.candy_cell(
				CELL_COLOR_LIGHT if is_light else CELL_COLOR_DARK, 14)
			cell.add_theme_stylebox_override("panel", style)
			## Tile текстура на клітинках — зелені/оранжеві для лісу (LAW 28)
			var tile_color: String = "green" if is_light else "orange"
			var tile_path: String = "res://assets/textures/tiles/%s/tile_%02d.png" % [tile_color, (idx % 10) + 1]
			cell.material = GameData.create_premium_material(
				0.03, 2.0, 0.03, 0.06, 0.04, 0.03, 0.05, tile_path, 0.2, 0.08, 0.20, 0.18)
			cell.pivot_offset = cell.size / 2.0
			cell.scale = Vector2.ZERO
			add_child(cell)
			_all_round_nodes.append(cell)
			grid_cells.append(cell)
			idx += 1
	_staggered_spawn(grid_cells, 0.04)


func _toddler_cell_center(grid_pos: Vector2i) -> Vector2:
	return _toddler_grid_origin + Vector2(
		float(grid_pos.x) * TODDLER_CELL_SIZE + TODDLER_CELL_SIZE * 0.5,
		float(grid_pos.y) * TODDLER_CELL_SIZE + TODDLER_CELL_SIZE * 0.5)


func _spawn_toddler_knight() -> void:
	_knight_node = Node2D.new()
	_knight_node.position = _toddler_cell_center(_knight_pos)
	_knight_node.z_index = 2  ## Лицар завжди поверх клітинок та highlights
	add_child(_knight_node)
	var ksz: float = TODDLER_CELL_SIZE * 0.7
	var knight_panel: Panel = Panel.new()
	knight_panel.size = Vector2(ksz, ksz)
	knight_panel.position = Vector2(-ksz * 0.5, -ksz * 0.5)
	var ks: StyleBoxFlat = GameData.candy_cell(KNIGHT_COLOR, 14)
	knight_panel.add_theme_stylebox_override("panel", ks)
	knight_panel.material = GameData.create_premium_material(
		0.04, 2.0, 0.04, 0.06, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.25, 0.20)
	_knight_node.add_child(knight_panel)
	## HQ текстура коня
	var knight_tex_path: String = "res://assets/textures/game_icons/icon_knight.png"
	if ResourceLoader.exists(knight_tex_path):
		var knight_tex: Texture2D = load(knight_tex_path)
		var knight_sz: float = ksz * 0.8
		var knight_ctrl: Control = Control.new()
		knight_ctrl.size = Vector2(knight_sz, knight_sz)
		knight_ctrl.position = Vector2(-ksz * 0.4, -ksz * 0.4)
		knight_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		knight_ctrl.draw.connect(func() -> void:
			knight_ctrl.draw_texture_rect(knight_tex, Rect2(Vector2.ZERO, Vector2(knight_sz, knight_sz)), false)
		)
		_knight_node.add_child(knight_ctrl)
	else:
		var knight_icon: Control = IconDraw.chess_knight(ksz * 0.7, KNIGHT_COLOR)
		knight_icon.position = Vector2(-ksz * 0.5, -ksz * 0.5)
		knight_icon.size = Vector2(ksz, ksz)
		_knight_node.add_child(knight_icon)
	_all_round_nodes.append(_knight_node)


func _spawn_toddler_stars() -> void:
	_toddler_star_nodes.clear()
	for star_pos: Vector2i in _toddler_stars:
		var star_node: Node2D = Node2D.new()
		star_node.position = _toddler_cell_center(star_pos)
		add_child(star_node)
		var gsz: float = TODDLER_CELL_SIZE * 0.6
		var star_panel: Panel = Panel.new()
		star_panel.size = Vector2(gsz, gsz)
		star_panel.position = Vector2(-gsz * 0.5, -gsz * 0.5)
		var gs: StyleBoxFlat = GameData.candy_circle(TODDLER_STAR_COLOR, gsz * 0.5, true)
		star_panel.add_theme_stylebox_override("panel", gs)
		star_panel.material = GameData.create_premium_material(
			0.05, 2.0, 0.04, 0.08, 0.04, 0.03, 0.05, "", 0.0, 0.12, 0.30, 0.25)
		star_node.add_child(star_panel)
		## HQ текстура зірки
		var star_tex_path: String = "res://assets/textures/game_icons/icon_star.png"
		if ResourceLoader.exists(star_tex_path):
			var star_tex: Texture2D = load(star_tex_path)
			var star_sz: float = gsz * 0.8
			var star_ctrl: Control = Control.new()
			star_ctrl.size = Vector2(star_sz, star_sz)
			star_ctrl.position = Vector2(-gsz * 0.4, -gsz * 0.4)
			star_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			star_ctrl.draw.connect(func() -> void:
				star_ctrl.draw_texture_rect(star_tex, Rect2(Vector2.ZERO, Vector2(star_sz, star_sz)), false)
			)
			star_node.add_child(star_ctrl)
		else:
			var star_icon: Control = IconDraw.star_5pt(gsz * 0.7, TODDLER_STAR_COLOR)
			star_icon.position = Vector2(-gsz * 0.5, -gsz * 0.5)
			star_icon.size = Vector2(gsz, gsz)
			star_node.add_child(star_icon)
		_toddler_star_nodes.append(star_node)
		_all_round_nodes.append(star_node)
		## Пульсація зірки
		_pulse_toddler_star(star_node)


func _pulse_toddler_star(star_node: Node2D) -> void:
	if not is_instance_valid(star_node):
		return
	if SettingsManager.reduced_motion:
		return
	var tw: Tween = _create_game_tween().set_loops()
	tw.tween_property(star_node, "scale", Vector2(1.1, 1.1), 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(star_node, "scale", Vector2.ONE, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _show_toddler_valid_moves() -> void:
	_clear_highlights()
	for offset: Vector2i in ADJACENT_OFFSETS:
		var target: Vector2i = _knight_pos + offset
		if target.x < 0 or target.x >= TODDLER_GRID_SIZE or \
			target.y < 0 or target.y >= TODDLER_GRID_SIZE:
			continue
		var cell: Panel = Panel.new()
		var sz: float = TODDLER_CELL_SIZE - 6.0
		cell.size = Vector2(sz, sz)
		cell.position = _toddler_grid_origin + Vector2(
			float(target.x) * TODDLER_CELL_SIZE + 3.0,
			float(target.y) * TODDLER_CELL_SIZE + 3.0)
		## Золота підсвітка для Toddler — скарб (LAW 25: + контрастна обводка)
		var style: StyleBoxFlat = GameData.candy_cell(TODDLER_HIGHLIGHT_COLOR, 14, true)
		style.border_color = Color("f59e0b", 0.9)
		style.set_border_width_all(3)
		style.shadow_color = Color("f59e0b", 0.35)
		style.shadow_size = 10
		cell.add_theme_stylebox_override("panel", style)
		cell.material = GameData.create_premium_material(
			0.03, 2.0, 0.03, 0.06, 0.04, 0.03, 0.05, "", 0.0, 0.08, 0.20, 0.18)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(_on_toddler_highlight_input.bind(target))
		add_child(cell)
		_highlight_cells.append(cell)
		_all_round_nodes.append(cell)


func _on_toddler_highlight_input(event: InputEvent, target_pos: Vector2i) -> void:
	if _input_locked or _game_over:
		return
	if event is InputEventMouseButton and event.pressed and \
		event.button_index == MOUSE_BUTTON_LEFT:
		_move_toddler_knight(target_pos)
	elif event is InputEventScreenTouch and event.pressed and event.index == 0:
		_move_toddler_knight(target_pos)


func _move_toddler_knight(target_pos: Vector2i) -> void:
	_input_locked = true
	_knight_pos = target_pos
	_moves += 1
	AudioManager.play_sfx("whoosh")  ## Свист при кожному ході
	## Toddler: будь-який валідний хід = "правильний" (A6)
	_register_correct(_knight_node)
	VFXManager.spawn_correct_sparkle(_toddler_cell_center(target_pos))
	_clear_highlights()
	## Перевірка: чи є скарб на цій клітинці
	var collected_star: bool = false
	for i: int in _toddler_stars.size():
		if _toddler_stars[i] == target_pos:
			collected_star = true
			_toddler_stars_collected += 1
			AudioManager.play_sfx("coin")  ## Скарб зібрано!
			## Анімація "скриня відкривається" (scale pop) + видалити зірку
			if i < _toddler_star_nodes.size() and is_instance_valid(_toddler_star_nodes[i]):
				VFXManager.spawn_correct_sparkle(_toddler_cell_center(target_pos))
				VFXManager.spawn_match_sparkle(_toddler_star_nodes[i].global_position)
				_animate_treasure_collect(_toddler_star_nodes[i])
			## Позначити зірку як зібрану (зсув за межі сітки)
			_toddler_stars[i] = Vector2i(-99, -99)
			break
	var target_px: Vector2 = _toddler_cell_center(target_pos)
	## Анімація стрибка коня: стиснення → стрибок → приземлення (EASE_OUT_BACK)
	if SettingsManager.reduced_motion:
		_knight_node.position = target_px
		_knight_node.scale = Vector2.ONE
		_after_toddler_move(collected_star)
		return
	var tw: Tween = _create_game_tween()
	## Стиснення перед стрибком
	tw.tween_property(_knight_node, "scale", Vector2(1.0, 0.8), 0.08)
	## Стрибок із EASE_OUT_BACK для juice
	tw.tween_property(_knight_node, "position", target_px, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_knight_node, "scale", Vector2(0.8, 1.2), 0.15)
	## Приземлення — пружний ефект
	tw.tween_property(_knight_node, "scale", Vector2(1.2, 0.85), 0.08)
	tw.tween_property(_knight_node, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_after_toddler_move.bind(collected_star))


func _after_toddler_move(collected_star: bool) -> void:
	## Усі зірки зібрані → лицар піднімає трофей + раунд завершено
	if _toddler_stars_collected >= _toddler_stars.size():
		var vfx_pos: Vector2 = _knight_node.global_position if is_instance_valid(_knight_node) else _toddler_cell_center(_knight_pos)
		VFXManager.spawn_premium_celebration(vfx_pos)
		_animate_knight_trophy()
		_on_puzzle_solved()
		return
	## Ще є зірки — показати можливі ходи та продовжити
	_show_toddler_valid_moves()
	_input_locked = false
	_reset_idle_timer()


## ---- Treasure collection animation (Toddler) ----

func _animate_treasure_collect(star_node: Node2D) -> void:
	## Scale pop: зірка збільшується як скриня, потім зникає
	if not is_instance_valid(star_node):
		push_warning("knight_path: star_node invalid in _animate_treasure_collect")
		return
	if SettingsManager.reduced_motion:
		star_node.queue_free()
		return
	var tw: Tween = _create_game_tween()
	tw.tween_property(star_node, "scale", Vector2(1.5, 1.5), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(star_node, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		if is_instance_valid(star_node):
			star_node.queue_free())


## ---- Knight trophy celebration (Toddler — усі зірки зібрано) ----

func _animate_knight_trophy() -> void:
	## Лицар робить "переможний танець": хитання (rotation wobble) + bounce
	if not is_instance_valid(_knight_node):
		push_warning("knight_path: _knight_node invalid in _animate_knight_trophy")
		return
	if SettingsManager.reduced_motion:
		return
	var tw: Tween = _create_game_tween()
	## Rotation wobble
	tw.tween_property(_knight_node, "rotation_degrees", 12.0, 0.1)
	tw.tween_property(_knight_node, "rotation_degrees", -12.0, 0.15)
	tw.tween_property(_knight_node, "rotation_degrees", 8.0, 0.1)
	tw.tween_property(_knight_node, "rotation_degrees", 0.0, 0.12)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## ---- Preschool L-move trail animation ----

func _spawn_l_move_trail(from_pos: Vector2i, to_pos: Vector2i) -> void:
	## Показати L-подібний trail від старту через проміжну точку до кінця
	if SettingsManager.reduced_motion:
		return
	## Обчислити проміжну точку L-ходу (спочатку горизонтально, потім вертикально)
	var intermediate: Vector2i = Vector2i(to_pos.x, from_pos.y)
	var p0: Vector2 = _cell_center(from_pos)
	var p1: Vector2 = _cell_center(intermediate)
	var p2: Vector2 = _cell_center(to_pos)
	## Очистити попередній trail
	if is_instance_valid(_trail_line):
		_trail_line.queue_free()
		_trail_line = null
	_trail_line = Line2D.new()
	_trail_line.width = 4.0
	_trail_line.default_color = TRAIL_DONE_COLOR
	_trail_line.add_point(p0)
	_trail_line.add_point(p1)
	_trail_line.add_point(p2)
	_trail_line.z_index = 1
	add_child(_trail_line)
	_all_round_nodes.append(_trail_line)
	## Згасання trail через 0.5с
	var tw: Tween = _create_game_tween()
	tw.tween_interval(0.15)
	tw.tween_property(_trail_line, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_trail_line):
			_trail_line.queue_free()
			_trail_line = null)


## ---- Knight victory dance (both modes) ----

func _animate_knight_victory_dance() -> void:
	## Bounce + rotate для переможного святкування
	if not is_instance_valid(_knight_node):
		push_warning("knight_path: _knight_node invalid in _animate_knight_victory_dance")
		return
	if SettingsManager.reduced_motion:
		return
	var tw: Tween = _create_game_tween()
	## Bounce вгору
	var base_y: float = _knight_node.position.y
	tw.tween_property(_knight_node, "position:y", base_y - 20.0, 0.15)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_knight_node, "rotation_degrees", 15.0, 0.15)
	## Bounce вниз + rotate назад
	tw.tween_property(_knight_node, "position:y", base_y, 0.2)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_knight_node, "rotation_degrees", -10.0, 0.2)
	## Settle
	tw.tween_property(_knight_node, "rotation_degrees", 0.0, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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
	## Підсвічені клітинки пульсують
	if not SettingsManager.reduced_motion:
		for cell: Panel in _highlight_cells:
			if is_instance_valid(cell):
				var tw: Tween = _create_game_tween()
				tw.tween_property(cell, "modulate", Color(1.4, 1.4, 1.4, 1.0), 0.2)
				tw.tween_property(cell, "modulate", Color.WHITE, 0.2)
	_reset_idle_timer()


## ---- L-move preview при наведенні (Preschool) ----

func _show_l_preview(target_pos: Vector2i) -> void:
	## Пунктирний L-шлях від коня до цільової клітинки при hover
	_clear_preview_line()
	if _input_locked or _game_over:
		return
	## Обчислити проміжну точку L-ходу (горизонтально → вертикально)
	var intermediate: Vector2i = Vector2i(target_pos.x, _knight_pos.y)
	var p0: Vector2 = _cell_center(_knight_pos)
	var p1: Vector2 = _cell_center(intermediate)
	var p2: Vector2 = _cell_center(target_pos)
	_preview_line = Line2D.new()
	_preview_line.width = 3.0
	_preview_line.default_color = TRAIL_PREVIEW_COLOR
	_preview_line.add_point(p0)
	_preview_line.add_point(p1)
	_preview_line.add_point(p2)
	_preview_line.z_index = 3
	## Пунктирна текстура — чергуємо opacity вздовж лінії
	var faded: Color = Color(TRAIL_PREVIEW_COLOR.r, TRAIL_PREVIEW_COLOR.g,
		TRAIL_PREVIEW_COLOR.b, 0.1)
	var dash_gradient: Gradient = Gradient.new()
	dash_gradient.set_color(0, TRAIL_PREVIEW_COLOR)
	dash_gradient.add_point(0.45, TRAIL_PREVIEW_COLOR)
	dash_gradient.add_point(0.55, faded)
	dash_gradient.set_color(1, faded)
	_preview_line.gradient = dash_gradient
	add_child(_preview_line)


func _clear_preview_line() -> void:
	if is_instance_valid(_preview_line):
		_preview_line.queue_free()
	_preview_line = null


## ---- Декорації лісової карти (дерева + дракони) ----

func _spawn_map_decorations() -> void:
	## Розмістити дерева та дракона на вільних клітинках (не knight, не goal, не valid moves)
	var occupied: Dictionary = {}
	occupied[_knight_pos] = true
	occupied[_goal_pos] = true
	## Знайти валідні ходи — теж не декоруємо
	for offset: Vector2i in KNIGHT_OFFSETS:
		var mv: Vector2i = _knight_pos + offset
		if mv.x >= 0 and mv.x < GRID_SIZE and mv.y >= 0 and mv.y < GRID_SIZE:
			occupied[mv] = true
	var free_cells: Array[Vector2i] = []
	for row: int in GRID_SIZE:
		for col: int in GRID_SIZE:
			var pos: Vector2i = Vector2i(col, row)
			if not occupied.has(pos):
				free_cells.append(pos)
	free_cells.shuffle()
	## Дерева: 2-4 на вільних клітинках
	var tree_count: int = mini(free_cells.size(), _scale_by_round_i(2, 4, _round, TOTAL_ROUNDS))
	for i: int in tree_count:
		if i >= free_cells.size():
			break
		_spawn_tree_decor(free_cells[i])
	## Дракон (Preschool): 1 дружній дракон на вільній клітинці, починаючи з раунду 1
	if not _is_toddler and _round >= 1:
		var dragon_idx: int = tree_count
		if dragon_idx < free_cells.size():
			_spawn_dragon_decor(free_cells[dragon_idx])


func _spawn_tree_decor(grid_pos: Vector2i) -> void:
	## Декоративне дерево на клітинці — code-drawn (IconDraw.pine_tree)
	var tree_node: Node2D = Node2D.new()
	var center: Vector2 = _cell_center(grid_pos)
	tree_node.position = center
	tree_node.z_index = 1
	add_child(tree_node)
	var tsz: float = CELL_SIZE * 0.5
	var tree_icon: Control = IconDraw.pine_tree(tsz, TREE_COLOR)
	tree_icon.position = Vector2(-tsz * 0.5, -tsz * 0.5)
	tree_icon.size = Vector2(tsz, tsz)
	tree_icon.modulate = Color(1.0, 1.0, 1.0, 0.6)  ## Напівпрозорий — не відволікає
	tree_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_node.add_child(tree_icon)
	_decor_nodes.append(tree_node)
	_all_round_nodes.append(tree_node)


func _spawn_dragon_decor(grid_pos: Vector2i) -> void:
	## Дружній дракон — декоративний елемент (оранжевий, не блокує рух)
	var dragon_node: Node2D = Node2D.new()
	var center: Vector2 = _cell_center(grid_pos)
	dragon_node.position = center
	dragon_node.z_index = 1
	add_child(dragon_node)
	var dsz: float = CELL_SIZE * 0.55
	## Використовуємо circle bg + ghost як "дракон" + тематичний колір
	var dragon_panel: Panel = Panel.new()
	dragon_panel.size = Vector2(dsz, dsz)
	dragon_panel.position = Vector2(-dsz * 0.5, -dsz * 0.5)
	var ds: StyleBoxFlat = GameData.candy_circle(DRAGON_COLOR, dsz * 0.5, true)
	dragon_panel.add_theme_stylebox_override("panel", ds)
	dragon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dragon_node.add_child(dragon_panel)
	## Іконка "дракон" — ghost як стилізований дракон (дружній)
	var dragon_icon: Control = IconDraw.ghost(dsz * 0.7, DRAGON_COLOR)
	dragon_icon.position = Vector2(-dsz * 0.5, -dsz * 0.5)
	dragon_icon.size = Vector2(dsz, dsz)
	dragon_icon.modulate = Color(1.0, 1.0, 1.0, 0.85)
	dragon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dragon_node.add_child(dragon_icon)
	_decor_nodes.append(dragon_node)
	_all_round_nodes.append(dragon_node)
	## Легка пульсація дракона — "дихає"
	if not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween().set_loops()
		tw.tween_property(dragon_node, "scale", Vector2(1.06, 1.06), 1.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(dragon_node, "scale", Vector2.ONE, 1.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## ---- Armor HUD (Preschool) ----

func _build_armor_hud() -> void:
	## Панель обладунків під instruction pill — 4 слоти: shield, helmet, sword, cape
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_armor_hud = HBoxContainer.new()
	_armor_hud.set("theme_override_constants/separation", 8)
	_armor_hud.alignment = BoxContainer.ALIGNMENT_CENTER
	_armor_hud.position = Vector2(vp.x * 0.5 - 100.0, _sa_top + 56)
	_armor_hud.size = Vector2(200.0, 36.0)
	add_child(_armor_hud)
	_armor_hud_icons.clear()
	for i: int in ARMOR_NAMES.size():
		var slot: Panel = Panel.new()
		slot.custom_minimum_size = Vector2(32, 32)
		var slot_style: StyleBoxFlat = GameData.candy_circle(
			Color(0.3, 0.3, 0.3, 0.3), 16.0, false)
		slot.add_theme_stylebox_override("panel", slot_style)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_armor_hud.add_child(slot)
		## Іконка обладунку (ще не зібраний — сірий)
		var icon: Control = _create_armor_icon(i, 22.0, Color(0.5, 0.5, 0.5, 0.4))
		icon.position = Vector2(5, 5)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_armor_hud_icons.append(slot)


func _create_armor_icon(index: int, sz: float, color: Color) -> Control:
	## Іконки обладунків: shield=diamond, helmet=star, sword=arrow, cape=flag
	match index:
		0:  ## Shield — діамант
			return IconDraw.diamond(sz, color)
		1:  ## Helmet — зірка
			return IconDraw.star_5pt(sz, color)
		2:  ## Sword — стрілка вгору
			return IconDraw.arrow_up(sz, color)
		3:  ## Cape — прапор
			return IconDraw.flag(sz, color)
		_:
			push_warning("knight_path: unknown armor index %d" % index)
			return IconDraw.star_5pt(sz, color)


func _award_armor_piece() -> void:
	## Нагородити лицаря обладунком за поточний раунд
	if _armor_collected >= ARMOR_NAMES.size():
		push_warning("knight_path: all armor already collected")
		return
	var piece_idx: int = _armor_collected
	_armor_collected += 1
	AudioManager.play_sfx("reward")  ## Звук нагороди за обладунок
	## Оновити HUD: зробити іконку яскравою
	if piece_idx < _armor_hud_icons.size():
		var slot: Panel = _armor_hud_icons[piece_idx]
		if is_instance_valid(slot):
			## Видалити стару сіру іконку, додати яскраву
			for child: Node in slot.get_children():
				child.queue_free()
			var bright_style: StyleBoxFlat = GameData.candy_circle(
				ARMOR_COLORS[piece_idx], 16.0, true)
			slot.add_theme_stylebox_override("panel", bright_style)
			var icon: Control = _create_armor_icon(
				piece_idx, 22.0, ARMOR_COLORS[piece_idx])
			icon.position = Vector2(5, 5)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon)
			## Анімація: scale pop при отриманні
			if not SettingsManager.reduced_motion:
				slot.pivot_offset = slot.size / 2.0
				var tw: Tween = _create_game_tween()
				tw.tween_property(slot, "scale", Vector2(1.5, 1.5), 0.12)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(slot, "scale", Vector2.ONE, 0.2)\
					.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				## VFX sparkle на слоті
				VFXManager.spawn_correct_sparkle(
					slot.global_position + slot.size * 0.5)


## ---- Dragon-friend фінальна сцена (Preschool, усі 4 обладунки зібрано) ----

func _animate_dragon_friend_finale() -> void:
	## Лицар у повних обладунках "перемагає" дракона → дракон стає другом
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = vp * 0.5
	## Дракон з'являється з правого боку
	var dragon_finale: Node2D = Node2D.new()
	dragon_finale.position = Vector2(center.x + 80.0, center.y)
	dragon_finale.z_index = 10
	dragon_finale.modulate = Color(1.0, 1.0, 1.0, 0.0)  ## Починає невидимим
	add_child(dragon_finale)
	var dsz: float = 64.0
	var dragon_bg: Panel = Panel.new()
	dragon_bg.size = Vector2(dsz, dsz)
	dragon_bg.position = Vector2(-dsz * 0.5, -dsz * 0.5)
	var ds: StyleBoxFlat = GameData.candy_circle(DRAGON_COLOR, dsz * 0.5, true)
	dragon_bg.add_theme_stylebox_override("panel", ds)
	dragon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dragon_finale.add_child(dragon_bg)
	var dragon_icon: Control = IconDraw.ghost(dsz * 0.7, DRAGON_COLOR)
	dragon_icon.position = Vector2(-dsz * 0.5, -dsz * 0.5)
	dragon_icon.size = Vector2(dsz, dsz)
	dragon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dragon_finale.add_child(dragon_icon)
	if not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween()
		## Дракон з'являється
		tw.tween_property(dragon_finale, "modulate:a", 1.0, 0.3)
		## Дракон підстрибує від радості (став другом!)
		var base_y: float = dragon_finale.position.y
		tw.tween_property(dragon_finale, "position:y", base_y - 15.0, 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(dragon_finale, "position:y", base_y, 0.2)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		## Святкування — конфеті
		tw.tween_callback(func() -> void:
			VFXManager.spawn_premium_celebration(center))
		## Згасання
		tw.tween_interval(1.0)
		tw.tween_property(dragon_finale, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func() -> void:
			if is_instance_valid(dragon_finale):
				dragon_finale.queue_free())
	else:
		dragon_finale.modulate = Color(1.0, 1.0, 1.0, 1.0)
		VFXManager.spawn_premium_celebration(center)
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if is_instance_valid(dragon_finale):
				dragon_finale.queue_free())
