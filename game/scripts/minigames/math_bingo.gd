extends BaseMiniGame

## PRE-33 Математичне Бінго — розв'яжи рівняння та збери лінію!
## Сітка 3x3 з числами, дитина шукає відповідь на рівняння.
## Toddler: "Лічи та знаходь" — візуальна гра з точками на сітці 2x2.

const TOTAL_ROUNDS: int = 3
const GRID_SIZE: int = 3
const CELL_SIZE: float = 90.0
const CELL_GAP: float = 8.0
const TAP_RADIUS: float = 48.0
const IDLE_HINT_DELAY: float = 5.0
const DEAL_STAGGER: float = 0.08
const DEAL_DURATION: float = 0.3
const SAFETY_TIMEOUT_SEC: float = 120.0

## Toddler-режим — візуальне лічення точок
const TODDLER_GRID: int = 2
const TODDLER_CELL_SIZE: float = 180.0
const TODDLER_CELL_GAP: float = 16.0
const TODDLER_DOT_RADIUS: float = 12.0
const TODDLER_DOT_COLOR: Color = Color("6c5ce7")
const TODDLER_ROUNDS: int = 5

## Кольори клітинок
const CELL_DEFAULT: Color = Color("e8dff5")
const CELL_MARKED: Color = Color("00b894")
const CELL_BORDER: Color = Color("c5b3e6")
const CELL_CORRECT_FLASH: Color = Color("55efc4")
const BINGO_GOLD: Color = Color("ffd700")

## Колір точок у рівнянні для Preschool
const EQ_DOT_COLOR: Color = Color("e17055")
const EQ_DOT_SIZE: float = 18.0

## Лінії для перевірки BINGO (індекси 0-8 у сітці 3x3)
const BINGO_LINES: Array[Array] = [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],  ## горизонтальні
	[0, 3, 6], [1, 4, 7], [2, 5, 8],  ## вертикальні
	[0, 4, 8], [2, 4, 6],              ## діагональні
]

var _round: int = 0
var _start_time: float = 0.0

var _grid_cells: Array[Node2D] = []
var _cell_values: Array[int] = []
var _cell_marked: Array[bool] = []
var _cell_panels: Array[Panel] = []
var _all_round_nodes: Array[Node] = []
var _correct_answer: int = 0
var _equations_solved: int = 0

var _equation_label: PanelContainer = null
var _idle_timer: SceneTreeTimer = null

## Toddler-режим
var _is_toddler: bool = false
var _toddler_correct_idx: int = -1
var _toddler_cells: Array[Node2D] = []


func _ready() -> void:
	game_id = "math_bingo"
	bg_theme = "puzzle"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("BINGO_TUTORIAL_TODDLER")
	return tr("BINGO_PARTY")


func get_tutorial_demo() -> Dictionary:
	if _is_toddler:
		if _toddler_correct_idx >= 0 and _toddler_correct_idx < _toddler_cells.size():
			var cell: Node2D = _toddler_cells[_toddler_correct_idx]
			if is_instance_valid(cell):
				return {"type": "tap", "target": cell.global_position}
		return {}
	if _grid_cells.is_empty():
		return {}
	## Шукаємо клітинку з правильною відповіддю
	for i: int in _cell_values.size():
		if _cell_values[i] == _correct_answer and not _cell_marked[i]:
			return {"type": "tap", "target": _grid_cells[i].global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	if _is_toddler:
		_start_round_toddler()
		return
	_input_locked = true
	_equations_solved = 0
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_grid(vp)
	_generate_equation()
	## Затримка перед активацією вводу
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.5
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _spawn_grid(vp: Vector2) -> void:
	## Генеруємо 9 унікальних чисел від 1 до 9
	_cell_values.clear()
	_cell_marked.clear()
	_grid_cells.clear()
	_cell_panels.clear()
	var numbers: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	numbers.shuffle()
	for i: int in 9:
		_cell_values.append(numbers[i])
		_cell_marked.append(false)
	## Розміщуємо сітку по центру
	var grid_total: float = CELL_SIZE * float(GRID_SIZE) + CELL_GAP * float(GRID_SIZE - 1)
	var start_x: float = (vp.x - grid_total) * 0.5
	var start_y: float = vp.y * 0.35
	## Текстурна гральна дошка під сіткою
	var board_pad: float = 16.0
	var board: TextureRect = TextureRect.new()
	board.size = Vector2(grid_total + board_pad * 2.0, grid_total + board_pad * 2.0)
	board.position = Vector2(start_x - board_pad, start_y - board_pad)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var board_tex_path: String = "res://assets/textures/backtiles/backtile_05.png"
	if ResourceLoader.exists(board_tex_path):
		board.texture = load(board_tex_path)
	board.modulate = Color(1, 1, 1, 0.18)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	_all_round_nodes.append(board)
	for i: int in 9:
		@warning_ignore("integer_division")
		var row: int = i / GRID_SIZE
		var col: int = i % GRID_SIZE
		var cell: Node2D = Node2D.new()
		var pos_x: float = start_x + float(col) * (CELL_SIZE + CELL_GAP) + CELL_SIZE * 0.5
		var pos_y: float = start_y + float(row) * (CELL_SIZE + CELL_GAP) + CELL_SIZE * 0.5
		cell.position = Vector2(pos_x, pos_y)
		add_child(cell)
		## Фон клітинки
		var panel: Panel = Panel.new()
		panel.size = Vector2(CELL_SIZE, CELL_SIZE)
		panel.position = Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.5)
		var style: StyleBoxFlat = GameData.candy_cell(CELL_DEFAULT, 12, true)
		style.border_color = CELL_BORDER
		panel.add_theme_stylebox_override("panel", style)
		## Grain overlay + текстура плитки (LAW 28)
		var cell_tile: String = "res://assets/textures/tiles/pink/tile_%02d.png" % ((i % 5) + 1)
		panel.material = GameData.create_premium_material(0.03, 2.0, 0.03, 0.0, 0.04, 0.03, 0.05, cell_tile, 0.2, 0.10, 0.22, 0.18)
		GameData.add_gloss(panel, 10)
		cell.add_child(panel)
		_cell_panels.append(panel)
		## Число
		var lbl: Label = Label.new()
		lbl.text = str(_cell_values[i])
		lbl.add_theme_font_size_override("font_size", 36)
		lbl.add_theme_color_override("font_color", Color("3d3d5c"))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(-CELL_SIZE * 0.5, -CELL_SIZE * 0.5)
		lbl.size = Vector2(CELL_SIZE, CELL_SIZE)
		cell.add_child(lbl)
		## Deal анімація
		if SettingsManager.reduced_motion:
			cell.scale = Vector2.ONE
			cell.modulate.a = 1.0
		else:
			cell.scale = Vector2(0.2, 0.2)
			cell.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = create_tween().set_parallel(true)
			tw.tween_property(cell, "scale", Vector2.ONE, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(cell, "modulate:a", 1.0, 0.2).set_delay(delay)
		_grid_cells.append(cell)
		_all_round_nodes.append(cell)
	_staggered_spawn(_cell_panels, 0.05)


func _generate_equation() -> void:
	## Генеруємо рівняння з відповіддю що є на сітці та ще не позначена
	var available: Array[int] = []
	for i: int in _cell_values.size():
		if not _cell_marked[i]:
			available.append(_cell_values[i])
	if available.is_empty():
		push_warning("MathBingo: немає доступних чисел для рівняння")
		return
	_correct_answer = available[randi() % available.size()]
	## A8: guard — відповідь має бути >= 2, щоб b не дорівнював 0
	if _correct_answer < 2:
		var filtered: Array[int] = available.filter(func(v: int) -> bool: return v >= 2)
		if not filtered.is_empty():
			_correct_answer = filtered[randi() % filtered.size()]
	## Створюємо рівняння: a + b = answer або a - b = answer
	var a: int = 0
	var b: int = 0
	var op: String = "+"
	## Прогресивна складність: раунд 1 = тільки додавання, пізніші — і віднімання
	var sub_chance: float = _scale_by_round(0.0, 0.5, _round, TOTAL_ROUNDS)
	if _correct_answer > 2 and randf() < sub_chance:
		## Віднімання — обмежуємо b щоб a <= 12
		b = randi_range(1, mini(_correct_answer - 1, 3))
		a = _correct_answer + b
		op = "-"
	else:
		## Додавання
		a = randi_range(1, maxi(_correct_answer - 1, 1))
		b = _correct_answer - a
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if _equation_label and is_instance_valid(_equation_label):
		_all_round_nodes.erase(_equation_label)
		_equation_label.queue_free()
	## Панель-підкладка для рівняння (candy look замість плаваючого тексту)
	var eq_panel: PanelContainer = PanelContainer.new()
	var eq_style: StyleBoxFlat = GameData.candy_panel(Color("e8dff5"), 16)
	eq_style.content_margin_left = 32
	eq_style.content_margin_right = 32
	eq_style.content_margin_top = 10
	eq_style.content_margin_bottom = 10
	eq_panel.add_theme_stylebox_override("panel", eq_style)
	eq_panel.material = GameData.create_premium_material(0.03, 2.0, 0.04, 0.08, 0.04, 0.03, 0.06, "", 0.0, 0.10, 0.22, 0.18)
	GameData.add_gloss(eq_panel, 12)
	## Візуальне рівняння: точки замість цифр (Preschool)
	var eq_hbox: HBoxContainer = HBoxContainer.new()
	eq_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	eq_hbox.add_theme_constant_override("separation", 6)
	## Ліва частина: a точок
	_add_equation_dots(eq_hbox, a, EQ_DOT_COLOR)
	## Оператор
	var op_lbl: Label = Label.new()
	op_lbl.text = "  %s  " % op
	op_lbl.add_theme_font_size_override("font_size", 38)
	op_lbl.add_theme_color_override("font_color", Color("3d3d5c"))
	eq_hbox.add_child(op_lbl)
	## Права частина: b точок
	_add_equation_dots(eq_hbox, b, EQ_DOT_COLOR)
	## "= ?"
	var eq_q_lbl: Label = Label.new()
	eq_q_lbl.text = "  =  ?"
	eq_q_lbl.add_theme_font_size_override("font_size", 38)
	eq_q_lbl.add_theme_color_override("font_color", Color("3d3d5c"))
	eq_hbox.add_child(eq_q_lbl)
	eq_panel.add_child(eq_hbox)
	eq_panel.position = Vector2(vp.x * 0.2, vp.y * 0.75)
	eq_panel.size = Vector2(vp.x * 0.6, 70)
	add_child(eq_panel)
	_all_round_nodes.append(eq_panel)
	_equation_label = eq_panel  ## зберігаємо посилання на панель для cleanup між рівняннями


## ---- Input ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	var is_tap: bool = false
	if event is InputEventMouseButton:
		is_tap = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		is_tap = event.pressed
	if not is_tap:
		return
	var pos: Vector2 = get_global_mouse_position()
	## Toddler — перевіряємо _toddler_cells замість _grid_cells
	if _is_toddler:
		_handle_toddler_input(pos)
		return
	for i: int in _grid_cells.size():
		var cell: Node2D = _grid_cells[i]
		if not is_instance_valid(cell):
			continue
		if _cell_marked[i]:
			continue
		if pos.distance_to(cell.global_position) < TAP_RADIUS:
			_handle_cell_tap(i)
			return


func _handle_cell_tap(idx: int) -> void:
	var value: int = _cell_values[idx]
	if value == _correct_answer:
		_handle_correct(idx)
	else:
		_handle_wrong(idx)


func _handle_correct(idx: int) -> void:
	_register_correct(_grid_cells[idx])
	_cell_marked[idx] = true
	_equations_solved += 1
	## Позначаємо клітинку зеленою
	_update_cell_color(idx, CELL_MARKED)
	## Перевіряємо чи є BINGO
	if _check_bingo():
		_input_locked = true
		AudioManager.play_sfx("success")
		HapticsManager.vibrate_success()
		VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
		var d2: float = 0.15 if SettingsManager.reduced_motion else 1.0
		var tw: Tween = create_tween()
		tw.tween_interval(d2)
		tw.tween_callback(func() -> void:
			_clear_round()
			_round += 1
			if _round >= TOTAL_ROUNDS:
				_finish()
			else:
				_start_round())
	else:
		_highlight_near_wins()
		_generate_equation()
		_reset_idle_timer()


func _highlight_near_wins() -> void:
	## Пульсація ліній де 2 з 3 клітинок позначені (близько до BINGO)
	for line: Array in BINGO_LINES:
		var marked_count: int = 0
		var unmarked_idx: int = -1
		for cell_idx: int in line:
			if _cell_marked[cell_idx]:
				marked_count += 1
			else:
				unmarked_idx = cell_idx
		if marked_count == GRID_SIZE - 1 and unmarked_idx >= 0:
			if unmarked_idx < _grid_cells.size():
				var cell: Node2D = _grid_cells[unmarked_idx]
				if is_instance_valid(cell) and not SettingsManager.reduced_motion:
					var tw: Tween = create_tween()
					tw.tween_property(cell, "modulate", Color(1.3, 1.2, 0.8), 0.3)
					tw.tween_property(cell, "modulate", Color.WHITE, 0.3)
					tw.tween_property(cell, "modulate", Color(1.3, 1.2, 0.8), 0.3)
					tw.tween_property(cell, "modulate", Color.WHITE, 0.3)


func _handle_wrong(idx: int) -> void:
	_input_locked = true
	_errors += 1
	_register_error(_grid_cells[idx])
	## Тремтіння клітинки
	var cell: Node2D = _grid_cells[idx]
	if SettingsManager.reduced_motion:
		var tw_rm: Tween = create_tween()
		tw_rm.tween_interval(0.15)
		tw_rm.tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer())
		return
	var orig_x: float = cell.position.x
	var tw: Tween = create_tween()
	tw.tween_property(cell, "position:x", orig_x - 6.0, 0.06)
	tw.tween_property(cell, "position:x", orig_x + 6.0, 0.06)
	tw.tween_property(cell, "position:x", orig_x - 3.0, 0.04)
	tw.tween_property(cell, "position:x", orig_x, 0.04)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _update_cell_color(idx: int, color: Color) -> void:
	if idx < 0 or idx >= _cell_panels.size():
		push_warning("MathBingo: _update_cell_color idx %d поза межами" % idx)
		return
	var panel: Panel = _cell_panels[idx]
	if not is_instance_valid(panel):
		push_warning("MathBingo: невалідна панель для клітинки %d" % idx)
		return
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	style.bg_color = color
	panel.add_theme_stylebox_override("panel", style)


func _check_bingo() -> bool:
	for line: Array in BINGO_LINES:
		var all_marked: bool = true
		for cell_idx: int in line:
			if not _cell_marked[cell_idx]:
				all_marked = false
				break
		if all_marked:
			## Підсвічуємо виграшну лінію
			for cell_idx: int in line:
				_update_cell_color(cell_idx, CELL_CORRECT_FLASH)
			_animate_bingo_line(line)
			return true
	return false


func _animate_bingo_line(line: Array) -> void:
	## Послідовний scale pop + золотий burst для кожної клітинки виграшної лінії
	for i: int in line.size():
		var cell_idx: int = line[i]
		if cell_idx < 0 or cell_idx >= _grid_cells.size():
			push_warning("MathBingo: bingo line cell_idx %d поза межами" % cell_idx)
			continue
		var cell: Node2D = _grid_cells[cell_idx]
		if not is_instance_valid(cell):
			push_warning("MathBingo: невалідна клітинка %d при bingo анімації" % cell_idx)
			continue
		var delay: float = float(i) * 0.1
		if not SettingsManager.reduced_motion:
			var tw: Tween = create_tween()
			tw.tween_interval(delay)
			tw.tween_property(cell, "scale", Vector2(1.3, 1.3), 0.12)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(cell, "scale", Vector2.ONE, 0.15)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		## Золотий burst у позиції кожної клітинки
		VFXManager.spawn_golden_burst(cell.global_position)
	## Екранний pulse (білий flash 50ms)
	if not SettingsManager.reduced_motion:
		_screen_flash()
	## Показуємо "БІНГО!" label з масштабуванням
	_spawn_bingo_label()


func _screen_flash() -> void:
	## Короткий білий flash по всьому екрану (50ms)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.35)
	flash.size = vp
	flash.position = Vector2.ZERO
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	_all_round_nodes.append(flash)
	var tw: Tween = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free())


func _spawn_bingo_label() -> void:
	## "БІНГО!" label що з'являється з масштабуванням по центру екрану
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var lbl: Label = Label.new()
	lbl.text = tr("BINGO_CELEBRATION")
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", BINGO_GOLD)
	lbl.add_theme_color_override("font_outline_color", Color("3d3d5c"))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(400, 100)
	lbl.position = Vector2((vp.x - 400.0) * 0.5, vp.y * 0.15)
	lbl.pivot_offset = Vector2(200, 50)
	add_child(lbl)
	_all_round_nodes.append(lbl)
	if SettingsManager.reduced_motion:
		lbl.scale = Vector2.ONE
		lbl.modulate.a = 1.0
	else:
		lbl.scale = Vector2(0.1, 0.1)
		lbl.modulate.a = 0.0
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(lbl, "scale", Vector2(1.1, 1.1), 0.25)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.2)
		tw.chain().tween_property(lbl, "scale", Vector2.ONE, 0.15)


## ---- Управління раундами ----

func _clear_round() -> void:
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_grid_cells.clear()
	_cell_values.clear()
	_cell_marked.clear()
	_cell_panels.clear()
	_toddler_cells.clear()
	_toddler_correct_idx = -1
	_equation_label = null


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var total: int = TODDLER_ROUNDS if _is_toddler else TOTAL_ROUNDS
	var earned: int = 5 if _is_toddler else _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": total, "earned_stars": earned})


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
	## Toddler — пульсуємо правильну клітинку
	if _is_toddler:
		if _toddler_cells.is_empty():
			return
		var level_t: int = _advance_idle_hint()
		if level_t >= 2:
			_reset_idle_timer()
			return
		if _toddler_correct_idx >= 0 and _toddler_correct_idx < _toddler_cells.size():
			var cell_t: Node2D = _toddler_cells[_toddler_correct_idx]
			if is_instance_valid(cell_t):
				_pulse_node(cell_t, 1.15)
		_reset_idle_timer()
		return
	if _grid_cells.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	## Підказуємо — пульсуємо клітинку з правильною відповіддю
	for i: int in _cell_values.size():
		if _cell_values[i] == _correct_answer and not _cell_marked[i]:
			var cell: Node2D = _grid_cells[i]
			if is_instance_valid(cell):
				_pulse_node(cell, 1.15)
			break
	_reset_idle_timer()


## ---- Toddler: "Лічи та знаходь" — візуальне лічення точок ----

## Розклад точок як на гральному кубику (зміщення відносно центру)
const _DOT_LAYOUTS: Dictionary = {
	1: [Vector2(0, 0)],
	2: [Vector2(-18, 0), Vector2(18, 0)],
	3: [Vector2(0, -20), Vector2(-18, 16), Vector2(18, 16)],
	4: [Vector2(-18, -18), Vector2(18, -18), Vector2(-18, 18), Vector2(18, 18)],
}

## Текстові назви чисел для запитання
const _COUNT_NAMES: Array[String] = ["", "ОДНУ", "ДВІ", "ТРИ", "ЧОТИРИ"]


func _start_round_toddler() -> void:
	_input_locked = true
	_toddler_cells.clear()
	_toddler_correct_idx = -1
	var total_rounds: int = TODDLER_ROUNDS
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, total_rounds])
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Визначаємо цільову кількість залежно від раунду
	var max_count: int = 3 if _round < 3 else 4
	var target: int = randi_range(1, max_count)
	_correct_answer = target
	## Чи це "раунд додавання" (R4-R5)?
	var is_addition: bool = (_round >= 3)
	var add_a: int = 0
	var add_b: int = 0
	if is_addition and target >= 2:
		add_a = randi_range(1, target - 1)
		add_b = target - add_a
	## Генеруємо 3 дистрактори (всі різні, всі ≠ target)
	var counts: Array[int] = [target]
	var pool: Array[int] = []
	for n: int in range(1, max_count + 1):
		if n != target:
			pool.append(n)
	pool.shuffle()
	## Потрібно 3 дистрактори, але pool може бути менший — допускаємо повтори в крайньому випадку
	var needed: int = 3
	var di: int = 0
	while counts.size() < 4 and di < needed:
		if di < pool.size():
			counts.append(pool[di])
		else:
			## Якщо пул вичерпано — додаємо числа що відрізняються від target
			var fallback: int = (target % max_count) + 1
			if fallback == target:
				fallback = (fallback % max_count) + 1
			counts.append(fallback)
		di += 1
	## Перемішуємо та запам'ятовуємо де правильна відповідь
	var indices: Array[int] = [0, 1, 2, 3]
	indices.shuffle()
	var shuffled: Array[int] = []
	for idx: int in indices:
		shuffled.append(counts[idx])
	_toddler_correct_idx = indices.find(0)
	## Сітка 2×2 по центру
	var grid_total: float = TODDLER_CELL_SIZE * float(TODDLER_GRID) + TODDLER_CELL_GAP * float(TODDLER_GRID - 1)
	var start_x: float = (vp.x - grid_total) * 0.5
	var start_y: float = vp.y * 0.32
	## Текстурна підкладка
	var board_pad: float = 20.0
	var board: TextureRect = TextureRect.new()
	board.size = Vector2(grid_total + board_pad * 2.0, grid_total + board_pad * 2.0)
	board.position = Vector2(start_x - board_pad, start_y - board_pad)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var board_tex_path: String = "res://assets/textures/backtiles/backtile_05.png"
	if ResourceLoader.exists(board_tex_path):
		board.texture = load(board_tex_path)
	board.modulate = Color(1, 1, 1, 0.18)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	_all_round_nodes.append(board)
	## Спавнимо 4 клітинки
	for i: int in 4:
		@warning_ignore("integer_division")
		var row: int = i / TODDLER_GRID
		var col: int = i % TODDLER_GRID
		var pos_x: float = start_x + float(col) * (TODDLER_CELL_SIZE + TODDLER_CELL_GAP) + TODDLER_CELL_SIZE * 0.5
		var pos_y: float = start_y + float(row) * (TODDLER_CELL_SIZE + TODDLER_CELL_GAP) + TODDLER_CELL_SIZE * 0.5
		_spawn_toddler_cell(Vector2(pos_x, pos_y), shuffled[i], i)
	## Запитання зверху
	_spawn_toddler_question(vp, target, is_addition, add_a, add_b)
	## Затримка перед активацією вводу
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.5
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _spawn_toddler_cell(pos: Vector2, count: int, cell_idx: int) -> void:
	var cell: Node2D = Node2D.new()
	cell.position = pos
	add_child(cell)
	## Фон клітинки (candy style)
	var panel: Panel = Panel.new()
	panel.size = Vector2(TODDLER_CELL_SIZE, TODDLER_CELL_SIZE)
	panel.position = Vector2(-TODDLER_CELL_SIZE * 0.5, -TODDLER_CELL_SIZE * 0.5)
	var style: StyleBoxFlat = GameData.candy_cell(CELL_DEFAULT, 18, true)
	style.border_color = CELL_BORDER
	panel.add_theme_stylebox_override("panel", style)
	## Grain overlay (LAW 28)
	var cell_tile: String = "res://assets/textures/tiles/pink/tile_%02d.png" % ((cell_idx % 5) + 1)
	panel.material = GameData.create_premium_material(0.03, 2.0, 0.03, 0.0, 0.04, 0.03, 0.05, cell_tile, 0.2, 0.10, 0.22, 0.18)
	GameData.add_gloss(panel, 14)
	cell.add_child(panel)
	## Малюємо точки
	_draw_dots(cell, count, Vector2.ZERO)
	## Deal анімація
	if SettingsManager.reduced_motion:
		cell.scale = Vector2.ONE
		cell.modulate.a = 1.0
	else:
		cell.scale = Vector2(0.2, 0.2)
		cell.modulate.a = 0.0
		var delay: float = float(cell_idx) * DEAL_STAGGER
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(cell, "scale", Vector2.ONE, DEAL_DURATION)\
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(cell, "modulate:a", 1.0, 0.2).set_delay(delay)
	_toddler_cells.append(cell)
	_all_round_nodes.append(cell)


func _draw_dots(parent: Node2D, count: int, center: Vector2) -> void:
	## Отримуємо розклад точок (1-4)
	var clamped: int = clampi(count, 1, 4)
	var layout: Array = _DOT_LAYOUTS.get(clamped, [Vector2.ZERO])
	for offset: Vector2 in layout:
		var dot: Panel = Panel.new()
		var dot_size: float = TODDLER_DOT_RADIUS * 2.0
		dot.size = Vector2(dot_size, dot_size)
		dot.position = center + offset - Vector2(TODDLER_DOT_RADIUS, TODDLER_DOT_RADIUS)
		dot.add_theme_stylebox_override("panel",
			GameData.candy_circle(TODDLER_DOT_COLOR, TODDLER_DOT_RADIUS, false))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(dot)


func _spawn_toddler_question(vp: Vector2, target: int, is_addition: bool,
		add_a: int, add_b: int) -> void:
	## Панель запитання зверху
	var q_panel: PanelContainer = PanelContainer.new()
	var q_style: StyleBoxFlat = GameData.candy_panel(Color("e8dff5"), 16)
	q_style.content_margin_left = 24
	q_style.content_margin_right = 24
	q_style.content_margin_top = 12
	q_style.content_margin_bottom = 12
	q_panel.add_theme_stylebox_override("panel", q_style)
	q_panel.material = GameData.create_premium_material(0.03, 2.0, 0.04, 0.08, 0.04, 0.03, 0.06, "", 0.0, 0.10, 0.22, 0.18)
	GameData.add_gloss(q_panel, 12)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	if is_addition and add_a > 0 and add_b > 0:
		## Додавання: показуємо "● ● + ● = ?"
		_add_question_dots(hbox, add_a)
		var plus_lbl: Label = Label.new()
		plus_lbl.text = " + "
		plus_lbl.add_theme_font_size_override("font_size", 36)
		plus_lbl.add_theme_color_override("font_color", Color("3d3d5c"))
		hbox.add_child(plus_lbl)
		_add_question_dots(hbox, add_b)
		var eq_lbl: Label = Label.new()
		eq_lbl.text = " = ?"
		eq_lbl.add_theme_font_size_override("font_size", 36)
		eq_lbl.add_theme_color_override("font_color", Color("3d3d5c"))
		hbox.add_child(eq_lbl)
	else:
		## Звичайний раунд: показуємо точки + "Знайди ТРИ!"
		_add_question_dots(hbox, target)
		var name_text: String = _COUNT_NAMES[clampi(target, 1, 4)]
		var find_lbl: Label = Label.new()
		find_lbl.text = "  Знайди %s!" % name_text
		find_lbl.add_theme_font_size_override("font_size", 32)
		find_lbl.add_theme_color_override("font_color", Color("3d3d5c"))
		hbox.add_child(find_lbl)
	q_panel.add_child(hbox)
	q_panel.position = Vector2(vp.x * 0.1, vp.y * 0.78)
	q_panel.size = Vector2(vp.x * 0.8, 80)
	add_child(q_panel)
	_all_round_nodes.append(q_panel)


func _add_question_dots(container: HBoxContainer, count: int) -> void:
	## Додає count кружечків у HBoxContainer як мініатюрні точки
	for _i: int in count:
		var dot: Panel = Panel.new()
		var dot_sz: float = 20.0
		dot.custom_minimum_size = Vector2(dot_sz, dot_sz)
		dot.size = Vector2(dot_sz, dot_sz)
		dot.add_theme_stylebox_override("panel",
			GameData.candy_circle(TODDLER_DOT_COLOR, dot_sz * 0.5, false))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(dot)


func _add_equation_dots(container: HBoxContainer, count: int, color: Color) -> void:
	## Додає count кружечків у HBoxContainer для Preschool рівняння
	var clamped: int = clampi(count, 0, 12)
	for _i: int in clamped:
		var dot: Panel = Panel.new()
		dot.custom_minimum_size = Vector2(EQ_DOT_SIZE, EQ_DOT_SIZE)
		dot.size = Vector2(EQ_DOT_SIZE, EQ_DOT_SIZE)
		dot.add_theme_stylebox_override("panel",
			GameData.candy_circle(color, EQ_DOT_SIZE * 0.5, false))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(dot)


## ---- Toddler input ----

func _handle_toddler_input(pos: Vector2) -> void:
	## Перевіряємо тап по клітинках — зона тапу = половина розміру клітинки
	var tap_dist: float = TODDLER_CELL_SIZE * 0.5
	for i: int in _toddler_cells.size():
		var cell: Node2D = _toddler_cells[i]
		if not is_instance_valid(cell):
			continue
		if pos.distance_to(cell.global_position) < tap_dist:
			_on_toddler_cell_tapped(i)
			return


func _on_toddler_cell_tapped(idx: int) -> void:
	if idx == _toddler_correct_idx:
		## Правильно!
		_register_correct(_toddler_cells[idx])
		AudioManager.play_sfx("success")
		HapticsManager.vibrate_success()
		var cell_pos: Vector2 = _toddler_cells[idx].global_position
		VFXManager.spawn_premium_celebration(cell_pos)
		VFXManager.spawn_golden_burst(cell_pos)
		## Scale pop на правильній клітинці
		var cell_node: Node2D = _toddler_cells[idx]
		if is_instance_valid(cell_node) and not SettingsManager.reduced_motion:
			var pop_tw: Tween = create_tween()
			pop_tw.tween_property(cell_node, "scale", Vector2(1.25, 1.25), 0.12)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop_tw.tween_property(cell_node, "scale", Vector2.ONE, 0.15)
		_input_locked = true
		var d2: float = 0.15 if SettingsManager.reduced_motion else 0.8
		var tw: Tween = create_tween()
		tw.tween_interval(d2)
		tw.tween_callback(func() -> void:
			_clear_round()
			_round += 1
			if _round >= TODDLER_ROUNDS:
				_finish()
			else:
				_start_round_toddler())
	else:
		## Помилка — м'який wobble, БЕЗ збільшення _errors (A6)
		AudioManager.play_sfx("click")
		var cell: Node2D = _toddler_cells[idx]
		if not is_instance_valid(cell):
			push_warning("MathBingo toddler: невалідна клітинка %d" % idx)
			return
		if SettingsManager.reduced_motion:
			return
		var orig_x: float = cell.position.x
		var tw: Tween = create_tween()
		tw.tween_property(cell, "position:x", orig_x - 8.0, 0.06)
		tw.tween_property(cell, "position:x", orig_x + 8.0, 0.06)
		tw.tween_property(cell, "position:x", orig_x - 4.0, 0.04)
		tw.tween_property(cell, "position:x", orig_x, 0.04)
