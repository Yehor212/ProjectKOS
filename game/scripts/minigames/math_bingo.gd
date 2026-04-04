extends BaseMiniGame

## PRE-33 Карта скарбів / Treasure Map — знайди клад, розв'язавши рівняння!
## Пірацька карта з сундуками замість клітинок. Розв'яжи рівняння = відкрити сундук.
## Toddler: 2x2 сітка, лічення точок, тап на правильний сундук.
## Preschool: 3x3 сітка, рівняння (додавання, потім віднімання), BINGO лінія = клад.
## При BINGO: папуга пролітає з ключем. Double BINGO: папуга з короною.

const TOTAL_ROUNDS: int = 3
const GRID_SIZE: int = 3
const CHEST_SIZE: float = 100.0
const CHEST_GAP: float = 10.0
const TAP_RADIUS: float = 60.0
const IDLE_HINT_DELAY: float = 5.0
const DEAL_STAGGER: float = 0.1
const DEAL_DURATION: float = 0.35
const SAFETY_TIMEOUT_SEC: float = 120.0

## Toddler-режим — лічення точок на сундуках
const TODDLER_GRID: int = 2
const TODDLER_CHEST_SIZE: float = 180.0
const TODDLER_CHEST_GAP: float = 16.0
const TODDLER_DOT_RADIUS: float = 14.0
const TODDLER_DOT_COLOR: Color = Color("f5cd79")
const TODDLER_ROUNDS: int = 5

## Кольори сундуків (пірацька палітра)
const CHEST_CLOSED: Color = Color("8d6e4a")
const CHEST_OPEN: Color = Color("f7d794")
const CHEST_BORDER: Color = Color("6b4f33")
const CHEST_GLOW: Color = Color("f7d794")
const CHEST_LOCK_COLOR: Color = Color("c9a45c")

## Колір точок у рівнянні для Preschool
const EQ_DOT_COLOR: Color = Color("e17055")
const EQ_DOT_SIZE: float = 18.0

## Палітра карти
const SCROLL_BG: Color = Color("f5e6ca")
const SCROLL_BORDER: Color = Color("c9a45c")
const MAP_DECO_COLOR: Color = Color("d4a76a")
const TEXT_COLOR: Color = Color("3d2c1a")

## Святкування
const BINGO_GOLD: Color = Color("ffd700")
const PARROT_GREEN: Color = Color("00b894")
const CROWN_GOLD: Color = Color("ffd700")

## Прогресивна кількість сундуків для перемоги (LAW 6 / A4)
## R1=5, R2=6, R3=7 (з 9 можливих). BINGO лінія = бонус, не обов'язкова.
const CELLS_TO_WIN: Array[int] = [5, 6, 7]

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
var _bingo_count: int = 0
var _opened_count: int = 0

var _equation_label: PanelContainer = null
var _idle_timer: SceneTreeTimer = null

## Toddler-режим
var _is_toddler: bool = false
var _toddler_correct_idx: int = -1
var _toddler_cells: Array[Node2D] = []


func _ready() -> void:
	game_id = "math_bingo"
	_skill_id = "arithmetic"
	bg_theme = "ocean"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("TREASURE_TUTORIAL_TODDLER")
	return tr("TREASURE_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	if _is_toddler:
		if _toddler_correct_idx >= 0 and _toddler_correct_idx < _toddler_cells.size():
			var cell: Node2D = _toddler_cells[_toddler_correct_idx]
			if is_instance_valid(cell):
				return {"type": "tap", "target": cell.global_position}
		return {}
	if _grid_cells.is_empty():
		return {}
	## Шукаємо сундук з правильною відповіддю
	for i: int in _cell_values.size():
		if i < _cell_marked.size() and _cell_values[i] == _correct_answer and not _cell_marked[i]:
			if i < _grid_cells.size():
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
	_bingo_count = 0
	_opened_count = 0
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_map_board(vp)
	_spawn_grid(vp)
	_generate_equation()
	## Затримка перед активацією вводу
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.5
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _spawn_map_board(vp: Vector2) -> void:
	## Текстурна пірацька карта під сіткою
	var grid_total: float = CHEST_SIZE * float(GRID_SIZE) + CHEST_GAP * float(GRID_SIZE - 1)
	var board_pad: float = 24.0
	var start_x: float = (vp.x - grid_total) * 0.5
	var start_y: float = vp.y * 0.28

	## Пергаментний фон карти
	var board: Panel = Panel.new()
	board.size = Vector2(grid_total + board_pad * 2.0, grid_total + board_pad * 2.0)
	board.position = Vector2(start_x - board_pad, start_y - board_pad)
	var board_style: StyleBoxFlat = GameData.candy_panel(SCROLL_BG, 16)
	board_style.border_color = SCROLL_BORDER
	board_style.border_width_bottom = 3
	board_style.border_width_left = 3
	board_style.border_width_right = 3
	board_style.border_width_top = 3
	board.add_theme_stylebox_override("panel", board_style)
	board.material = GameData.create_premium_material(
		0.04, 2.0, 0.03, 0.0, 0.04, 0.03, 0.06, "", 0.0, 0.08, 0.18, 0.12)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	_all_round_nodes.append(board)

	## Декоративний компас у кутку карти (лейбл "N" з стрілкою)
	var compass: Label = Label.new()
	compass.text = "N"
	compass.add_theme_font_size_override("font_size", 24)
	compass.add_theme_color_override("font_color", MAP_DECO_COLOR)
	compass.position = Vector2(start_x + grid_total + board_pad - 30.0, start_y - board_pad + 6.0)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(compass)
	_all_round_nodes.append(compass)


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
	var grid_total: float = CHEST_SIZE * float(GRID_SIZE) + CHEST_GAP * float(GRID_SIZE - 1)
	var start_x: float = (vp.x - grid_total) * 0.5
	var start_y: float = vp.y * 0.28
	for i: int in 9:
		@warning_ignore("integer_division")
		var row: int = i / GRID_SIZE
		var col: int = i % GRID_SIZE
		var cell: Node2D = Node2D.new()
		var pos_x: float = start_x + float(col) * (CHEST_SIZE + CHEST_GAP) + CHEST_SIZE * 0.5
		var pos_y: float = start_y + float(row) * (CHEST_SIZE + CHEST_GAP) + CHEST_SIZE * 0.5
		cell.position = Vector2(pos_x, pos_y)
		add_child(cell)
		## Фон сундука (candy style з пірацькою палітрою)
		var panel: Panel = Panel.new()
		panel.size = Vector2(CHEST_SIZE, CHEST_SIZE)
		panel.position = Vector2(-CHEST_SIZE * 0.5, -CHEST_SIZE * 0.5)
		var style: StyleBoxFlat = GameData.candy_cell(CHEST_CLOSED, 14, true)
		style.border_color = CHEST_BORDER
		style.border_width_bottom = 3
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		panel.add_theme_stylebox_override("panel", style)
		## Текстура + grain overlay (LAW 28)
		var cell_tile: String = "res://assets/textures/tiles/pink/tile_%02d.png" % ((i % 5) + 1)
		panel.material = GameData.create_premium_material(
			0.04, 2.0, 0.03, 0.0, 0.04, 0.03, 0.06,
			cell_tile, 0.15, 0.10, 0.22, 0.18)
		GameData.add_gloss(panel, 10)
		cell.add_child(panel)
		_cell_panels.append(panel)
		## Замочок (декоративна мітка закритого сундука)
		var lock_icon: Label = Label.new()
		lock_icon.name = "LockIcon"
		lock_icon.text = "X"
		lock_icon.add_theme_font_size_override("font_size", 24)
		lock_icon.add_theme_color_override("font_color", CHEST_LOCK_COLOR)
		lock_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_icon.position = Vector2(-CHEST_SIZE * 0.5, -CHEST_SIZE * 0.5 + 2.0)
		lock_icon.size = Vector2(CHEST_SIZE, 22.0)
		lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(lock_icon)
		## Число всередині сундука
		var lbl: Label = Label.new()
		lbl.text = str(_cell_values[i])
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.add_theme_color_override("font_color", TEXT_COLOR)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(-CHEST_SIZE * 0.5, -CHEST_SIZE * 0.5 + 10.0)
		lbl.size = Vector2(CHEST_SIZE, CHEST_SIZE)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(lbl)
		## Deal анімація
		if SettingsManager.reduced_motion:
			cell.scale = Vector2.ONE
			cell.modulate.a = 1.0
		else:
			cell.scale = Vector2(0.2, 0.2)
			cell.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = _create_game_tween().set_parallel(true)
			tw.tween_property(cell, "scale", Vector2.ONE, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(cell, "modulate:a", 1.0, 0.2).set_delay(delay)
		_grid_cells.append(cell)
		_all_round_nodes.append(cell)
	_staggered_spawn(_cell_panels, 0.05)


func _generate_equation() -> void:
	## Генеруємо рівняння з відповіддю що є на сітці та ще не відкрита
	var available: Array[int] = []
	for i: int in _cell_values.size():
		if i < _cell_marked.size() and not _cell_marked[i]:
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
	## Прогресивна складність (LAW 6 / A4): раунд 1 = тільки додавання, пізніші — і віднімання
	var sub_chance: float = _scale_adaptive(0.0, 0.5, _round, TOTAL_ROUNDS)
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
	## Пірацький сувій з рівнянням (scroll panel)
	var eq_panel: PanelContainer = PanelContainer.new()
	var eq_style: StyleBoxFlat = GameData.candy_panel(SCROLL_BG, 16)
	eq_style.border_color = SCROLL_BORDER
	eq_style.border_width_bottom = 2
	eq_style.border_width_left = 2
	eq_style.border_width_right = 2
	eq_style.border_width_top = 2
	eq_style.content_margin_left = 32
	eq_style.content_margin_right = 32
	eq_style.content_margin_top = 10
	eq_style.content_margin_bottom = 10
	eq_panel.add_theme_stylebox_override("panel", eq_style)
	eq_panel.material = GameData.create_premium_material(
		0.04, 2.0, 0.04, 0.06, 0.04, 0.03, 0.06, "", 0.0, 0.10, 0.20, 0.16)
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
	op_lbl.add_theme_color_override("font_color", TEXT_COLOR)
	op_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eq_hbox.add_child(op_lbl)
	## Права частина: b точок
	_add_equation_dots(eq_hbox, b, EQ_DOT_COLOR)
	## "= ?"
	var eq_q_lbl: Label = Label.new()
	eq_q_lbl.text = "  =  ?"
	eq_q_lbl.add_theme_font_size_override("font_size", 38)
	eq_q_lbl.add_theme_color_override("font_color", TEXT_COLOR)
	eq_q_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eq_hbox.add_child(eq_q_lbl)
	eq_panel.add_child(eq_hbox)
	eq_panel.position = Vector2(vp.x * 0.2, vp.y * 0.75)
	eq_panel.size = Vector2(vp.x * 0.6, 70)
	add_child(eq_panel)
	_all_round_nodes.append(eq_panel)
	_equation_label = eq_panel


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
		if i >= _cell_marked.size():
			push_warning("MathBingo: cell index %d >= _cell_marked size %d" % [i, _cell_marked.size()])
			continue
		if _cell_marked[i]:
			continue
		if pos.distance_to(cell.global_position) < TAP_RADIUS:
			_handle_cell_tap(i)
			return


func _handle_cell_tap(idx: int) -> void:
	if idx < 0 or idx >= _cell_values.size():
		push_warning("MathBingo: _handle_cell_tap idx %d поза межами" % idx)
		return
	var value: int = _cell_values[idx]
	if value == _correct_answer:
		_handle_correct(idx)
	else:
		_handle_wrong(idx)


func _handle_correct(idx: int) -> void:
	if idx < 0 or idx >= _grid_cells.size():
		push_warning("MathBingo: _handle_correct idx %d поза межами" % idx)
		return
	_register_correct(_grid_cells[idx])
	_cell_marked[idx] = true
	_equations_solved += 1
	_opened_count += 1
	## Відкриваємо сундук — змінюємо колір на золотий
	_open_chest(idx)
	## BINGO лінія = БОНУС (не обов'язкова для перемоги)
	## Piaget: стратегічне планування 3-в-ряд = concrete operational (7+),
	## а наша аудиторія = preoperational (4-7). Перемога = відкрити достатньо сундуків.
	var new_bingo: bool = _check_bingo()
	if new_bingo:
		_bingo_count += 1
		## Бонусне святкування: папуга пролітає з ключем
		AudioManager.play_sfx("success")
		HapticsManager.vibrate_success()
		_spawn_parrot_flyby(_bingo_count >= 2)
	## Перевіряємо ПЕРЕМОГУ: відкрито достатньо сундуків
	var cells_needed: int = _get_cells_to_win()
	if _opened_count >= cells_needed:
		_input_locked = true
		VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
		if not new_bingo:
			## Якщо BINGO не було, граємо success sfx тут
			AudioManager.play_sfx("success")
			HapticsManager.vibrate_success()
		var d2: float = 0.15 if SettingsManager.reduced_motion else 1.2
		var tw: Tween = _create_game_tween()
		tw.tween_interval(d2)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(self):
				return
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


## Кількість сундуків для перемоги в поточному раунді (LAW 6: прогресивна складність)
func _get_cells_to_win() -> int:
	if _round >= 0 and _round < CELLS_TO_WIN.size():
		return CELLS_TO_WIN[_round]
	push_warning("MathBingo: _round %d поза межами CELLS_TO_WIN, fallback 7" % _round)
	return 7


func _open_chest(idx: int) -> void:
	## Анімація відкривання сундука — змінюємо колір + scale pop
	_update_cell_color(idx, CHEST_OPEN)
	## Ховаємо замочок
	if idx >= 0 and idx < _grid_cells.size():
		var cell: Node2D = _grid_cells[idx]
		if is_instance_valid(cell):
			var lock_node: Node = cell.get_node_or_null("LockIcon")
			if lock_node and is_instance_valid(lock_node):
				lock_node.visible = false
	## Scale pop + золотий burst
	if idx >= 0 and idx < _grid_cells.size():
		var cell: Node2D = _grid_cells[idx]
		if not is_instance_valid(cell):
			push_warning("MathBingo: невалідний сундук %d при відкриванні" % idx)
			return
		if not SettingsManager.reduced_motion:
			var tw: Tween = _create_game_tween()
			tw.tween_property(cell, "scale", Vector2(1.2, 1.2), 0.12)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(cell, "scale", Vector2.ONE, 0.15)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		VFXManager.spawn_golden_burst(cell.global_position)


func _highlight_near_wins() -> void:
	## Пульсація ліній де 2 з 3 сундуків відкриті (близько до BINGO)
	for line: Array in BINGO_LINES:
		var marked_count: int = 0
		var unmarked_idx: int = -1
		for cell_idx: int in line:
			if cell_idx >= 0 and cell_idx < _cell_marked.size() and _cell_marked[cell_idx]:
				marked_count += 1
			else:
				unmarked_idx = cell_idx
		if marked_count == GRID_SIZE - 1 and unmarked_idx >= 0:
			if unmarked_idx < _grid_cells.size():
				var cell: Node2D = _grid_cells[unmarked_idx]
				if is_instance_valid(cell) and not SettingsManager.reduced_motion:
					var tw: Tween = _create_game_tween()
					tw.tween_property(cell, "modulate", Color(1.3, 1.2, 0.8), 0.3)
					tw.tween_property(cell, "modulate", Color.WHITE, 0.3)
					tw.tween_property(cell, "modulate", Color(1.3, 1.2, 0.8), 0.3)
					tw.tween_property(cell, "modulate", Color.WHITE, 0.3)


func _handle_wrong(idx: int) -> void:
	if idx < 0 or idx >= _grid_cells.size():
		push_warning("MathBingo: _handle_wrong idx %d поза межами" % idx)
		return
	_input_locked = true
	_errors += 1
	## _register_error обробляє: scaffolding (A11), audio/haptics/VFX (A7), wobble анімацію
	_register_error(_grid_cells[idx])
	## Розблокуємо ввід після короткої затримки
	var unlock_delay: float = 0.15 if SettingsManager.reduced_motion else 0.3
	var tw: Tween = _create_game_tween()
	tw.tween_interval(unlock_delay)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _update_cell_color(idx: int, color: Color) -> void:
	if idx < 0 or idx >= _cell_panels.size():
		push_warning("MathBingo: _update_cell_color idx %d поза межами" % idx)
		return
	var panel: Panel = _cell_panels[idx]
	if not is_instance_valid(panel):
		push_warning("MathBingo: невалідна панель для сундука %d" % idx)
		return
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	style.bg_color = color
	panel.add_theme_stylebox_override("panel", style)


func _check_bingo() -> bool:
	for line: Array in BINGO_LINES:
		var all_marked: bool = true
		for cell_idx: int in line:
			if cell_idx < 0 or cell_idx >= _cell_marked.size():
				all_marked = false
				break
			if not _cell_marked[cell_idx]:
				all_marked = false
				break
		if all_marked:
			## Підсвічуємо виграшну лінію золотим
			for cell_idx: int in line:
				_update_cell_color(cell_idx, BINGO_GOLD)
			_animate_bingo_line(line)
			return true
	return false


func _animate_bingo_line(line: Array) -> void:
	## Послідовний scale pop + золотий burst для кожного сундука виграшної лінії
	for i: int in line.size():
		var cell_idx: int = line[i]
		if cell_idx < 0 or cell_idx >= _grid_cells.size():
			push_warning("MathBingo: bingo line cell_idx %d поза межами" % cell_idx)
			continue
		var cell: Node2D = _grid_cells[cell_idx]
		if not is_instance_valid(cell):
			push_warning("MathBingo: невалідний сундук %d при bingo анімації" % cell_idx)
			continue
		var delay: float = float(i) * 0.12
		if not SettingsManager.reduced_motion:
			var tw: Tween = _create_game_tween()
			tw.tween_interval(delay)
			tw.tween_property(cell, "scale", Vector2(1.3, 1.3), 0.12)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(cell, "scale", Vector2.ONE, 0.15)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		## Золотий burst у позиції кожного сундука
		VFXManager.spawn_golden_burst(cell.global_position)
	## Екранний flash
	if not SettingsManager.reduced_motion:
		_screen_flash()
	## Показуємо святковий label
	_spawn_treasure_label()


func _screen_flash() -> void:
	## Короткий золотий flash по всьому екрану
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1, 0.95, 0.7, 0.3)
	flash.size = vp
	flash.position = Vector2.ZERO
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	_all_round_nodes.append(flash)
	var tw: Tween = _create_game_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		if is_instance_valid(flash):
			_all_round_nodes.erase(flash)
			flash.queue_free())


func _spawn_treasure_label() -> void:
	## "КЛАД!" label що з'являється з масштабуванням по центру екрану
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var lbl: Label = Label.new()
	lbl.text = tr("TREASURE_FOUND")
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.add_theme_color_override("font_color", BINGO_GOLD)
	lbl.add_theme_color_override("font_outline_color", TEXT_COLOR)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(400, 100)
	lbl.position = Vector2((vp.x - 400.0) * 0.5, vp.y * 0.12)
	lbl.pivot_offset = Vector2(200, 50)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	_all_round_nodes.append(lbl)
	if SettingsManager.reduced_motion:
		lbl.scale = Vector2.ONE
		lbl.modulate.a = 1.0
	else:
		lbl.scale = Vector2(0.1, 0.1)
		lbl.modulate.a = 0.0
		var tw: Tween = _create_game_tween().set_parallel(true)
		tw.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.25)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 1.0, 0.2)
		tw.chain().tween_property(lbl, "scale", Vector2.ONE, 0.15)


func _spawn_parrot_flyby(is_double_bingo: bool) -> void:
	## Папуга пролітає зліва направо з ключем (або короною при double BINGO)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var parrot: Node2D = Node2D.new()
	parrot.position = Vector2(-80.0, vp.y * 0.2)
	add_child(parrot)
	_all_round_nodes.append(parrot)
	## Тіло папуги (зелений овал)
	var body: Panel = Panel.new()
	body.size = Vector2(50.0, 36.0)
	body.position = Vector2(-25.0, -18.0)
	body.add_theme_stylebox_override("panel", GameData.candy_circle(PARROT_GREEN, 18.0, true))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parrot.add_child(body)
	## Дзьоб (маленький жовтий трикутник — апроксимуємо невеликим rect)
	var beak: Panel = Panel.new()
	beak.size = Vector2(12.0, 8.0)
	beak.position = Vector2(25.0, -4.0)
	beak.add_theme_stylebox_override("panel", GameData.candy_cell(BINGO_GOLD, 3, false))
	beak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parrot.add_child(beak)
	## Предмет — ключ або корона
	var item_lbl: Label = Label.new()
	if is_double_bingo:
		item_lbl.text = tr("TREASURE_CROWN")
	else:
		item_lbl.text = tr("TREASURE_KEY")
	item_lbl.add_theme_font_size_override("font_size", 28)
	item_lbl.add_theme_color_override("font_color", CROWN_GOLD)
	item_lbl.add_theme_color_override("font_outline_color", TEXT_COLOR)
	item_lbl.add_theme_constant_override("outline_size", 3)
	item_lbl.position = Vector2(-20.0, 18.0)
	item_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parrot.add_child(item_lbl)
	## Анімація прольоту
	if SettingsManager.reduced_motion:
		parrot.position = Vector2(vp.x * 0.5, vp.y * 0.2)
	else:
		var tw: Tween = _create_game_tween()
		tw.tween_property(parrot, "position:x", vp.x + 80.0, 1.0)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		## Легкий синусоїдний рух по вертикалі
		tw.parallel().tween_property(parrot, "position:y", vp.y * 0.15, 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(parrot, "position:y", vp.y * 0.25, 0.5)\
			.set_delay(0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
	_opened_count = 0


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var total: int = TODDLER_ROUNDS if _is_toddler else TOTAL_ROUNDS
	var earned: int = _calculate_stars(_errors)
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
	## Toddler — пульсуємо правильний сундук
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
	## Підказуємо — пульсуємо сундук з правильною відповіддю
	for i: int in _cell_values.size():
		if i < _cell_marked.size() and _cell_values[i] == _correct_answer and not _cell_marked[i]:
			if i < _grid_cells.size():
				var cell: Node2D = _grid_cells[i]
				if is_instance_valid(cell):
					_pulse_node(cell, 1.15)
			break
	_reset_idle_timer()


## ---- Toddler: "Карта скарбів" — візуальне лічення точок на сундуках ----

## Розклад точок як на гральному кубику (зміщення відносно центру)
const _DOT_LAYOUTS: Dictionary = {
	1: [Vector2(0, 0)],
	2: [Vector2(-20, 0), Vector2(20, 0)],
	3: [Vector2(0, -22), Vector2(-20, 18), Vector2(20, 18)],
	4: [Vector2(-20, -20), Vector2(20, -20), Vector2(-20, 20), Vector2(20, 20)],
}


func _start_round_toddler() -> void:
	_input_locked = true
	_toddler_cells.clear()
	_toddler_correct_idx = -1
	var total_rounds: int = TODDLER_ROUNDS
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, total_rounds])
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Визначаємо цільову кількість залежно від раунду (A4: difficulty ramp)
	var max_count: int = _scale_adaptive_i(3, 4, _round, TODDLER_ROUNDS)
	var target: int = randi_range(1, max_count)
	_correct_answer = target
	## Чи це "раунд додавання" (R4-R5)?
	var is_addition: bool = (_round >= 3)
	var add_a: int = 0
	var add_b: int = 0
	if is_addition and target >= 2:
		add_a = randi_range(1, target - 1)
		add_b = target - add_a
	## Генеруємо 3 дистрактори (всі різні, всі != target)
	var counts: Array[int] = [target]
	var pool: Array[int] = []
	for n: int in range(1, max_count + 1):
		if n != target:
			pool.append(n)
	pool.shuffle()
	## Потрібно 3 дистрактори, але pool може бути менший — допускаємо повтори в крайньому випадку (A8)
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
		if idx < counts.size():
			shuffled.append(counts[idx])
	_toddler_correct_idx = indices.find(0)
	## Пергаментний фон для Toddler карти
	var grid_total: float = TODDLER_CHEST_SIZE * float(TODDLER_GRID) + TODDLER_CHEST_GAP * float(TODDLER_GRID - 1)
	var start_x: float = (vp.x - grid_total) * 0.5
	var start_y: float = vp.y * 0.28
	## Текстурна підкладка — пірацька карта
	var board_pad: float = 24.0
	var board: Panel = Panel.new()
	board.size = Vector2(grid_total + board_pad * 2.0, grid_total + board_pad * 2.0)
	board.position = Vector2(start_x - board_pad, start_y - board_pad)
	var board_style: StyleBoxFlat = GameData.candy_panel(SCROLL_BG, 16)
	board_style.border_color = SCROLL_BORDER
	board_style.border_width_bottom = 3
	board_style.border_width_left = 3
	board_style.border_width_right = 3
	board_style.border_width_top = 3
	board.add_theme_stylebox_override("panel", board_style)
	board.material = GameData.create_premium_material(
		0.04, 2.0, 0.03, 0.0, 0.04, 0.03, 0.06, "", 0.0, 0.08, 0.18, 0.12)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	_all_round_nodes.append(board)
	## Спавнимо 4 сундуки
	for i: int in 4:
		if i >= shuffled.size():
			push_warning("MathBingo toddler: shuffled size %d < expected 4" % shuffled.size())
			break
		@warning_ignore("integer_division")
		var row: int = i / TODDLER_GRID
		var col: int = i % TODDLER_GRID
		var pos_x: float = start_x + float(col) * (TODDLER_CHEST_SIZE + TODDLER_CHEST_GAP) + TODDLER_CHEST_SIZE * 0.5
		var pos_y: float = start_y + float(row) * (TODDLER_CHEST_SIZE + TODDLER_CHEST_GAP) + TODDLER_CHEST_SIZE * 0.5
		_spawn_toddler_chest(Vector2(pos_x, pos_y), shuffled[i], i)
	## Запитання зверху
	_spawn_toddler_question(vp, target, is_addition, add_a, add_b)
	## Затримка перед активацією вводу
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.5
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _spawn_toddler_chest(pos: Vector2, count: int, cell_idx: int) -> void:
	var cell: Node2D = Node2D.new()
	cell.position = pos
	add_child(cell)
	## Фон сундука (пірацька палітра)
	var panel: Panel = Panel.new()
	panel.size = Vector2(TODDLER_CHEST_SIZE, TODDLER_CHEST_SIZE)
	panel.position = Vector2(-TODDLER_CHEST_SIZE * 0.5, -TODDLER_CHEST_SIZE * 0.5)
	var style: StyleBoxFlat = GameData.candy_cell(CHEST_CLOSED, 18, true)
	style.border_color = CHEST_BORDER
	style.border_width_bottom = 3
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	panel.add_theme_stylebox_override("panel", style)
	## Grain overlay (LAW 28)
	var cell_tile: String = "res://assets/textures/tiles/pink/tile_%02d.png" % ((cell_idx % 5) + 1)
	panel.material = GameData.create_premium_material(
		0.04, 2.0, 0.03, 0.0, 0.04, 0.03, 0.06,
		cell_tile, 0.15, 0.10, 0.22, 0.18)
	GameData.add_gloss(panel, 14)
	cell.add_child(panel)
	## Малюємо точки на сундуку
	_draw_dots(cell, count, Vector2.ZERO)
	## Deal анімація
	if SettingsManager.reduced_motion:
		cell.scale = Vector2.ONE
		cell.modulate.a = 1.0
	else:
		cell.scale = Vector2(0.2, 0.2)
		cell.modulate.a = 0.0
		var delay: float = float(cell_idx) * DEAL_STAGGER
		var tw: Tween = _create_game_tween().set_parallel(true)
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
	## Панель запитання — пірацький сувій
	var q_panel: PanelContainer = PanelContainer.new()
	var q_style: StyleBoxFlat = GameData.candy_panel(SCROLL_BG, 16)
	q_style.border_color = SCROLL_BORDER
	q_style.border_width_bottom = 2
	q_style.border_width_left = 2
	q_style.border_width_right = 2
	q_style.border_width_top = 2
	q_style.content_margin_left = 24
	q_style.content_margin_right = 24
	q_style.content_margin_top = 12
	q_style.content_margin_bottom = 12
	q_panel.add_theme_stylebox_override("panel", q_style)
	q_panel.material = GameData.create_premium_material(
		0.04, 2.0, 0.04, 0.06, 0.04, 0.03, 0.06, "", 0.0, 0.10, 0.20, 0.16)
	GameData.add_gloss(q_panel, 12)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	if is_addition and add_a > 0 and add_b > 0:
		## Додавання: показуємо точки + "+" + точки + "= ?"
		_add_question_dots(hbox, add_a)
		var plus_lbl: Label = Label.new()
		plus_lbl.text = " + "
		plus_lbl.add_theme_font_size_override("font_size", 36)
		plus_lbl.add_theme_color_override("font_color", TEXT_COLOR)
		plus_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(plus_lbl)
		_add_question_dots(hbox, add_b)
		var eq_lbl: Label = Label.new()
		eq_lbl.text = " = ?"
		eq_lbl.add_theme_font_size_override("font_size", 36)
		eq_lbl.add_theme_color_override("font_color", TEXT_COLOR)
		eq_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(eq_lbl)
	else:
		## Звичайний раунд: показуємо точки + tr("TREASURE_FIND_COUNT")
		_add_question_dots(hbox, target)
		var find_lbl: Label = Label.new()
		find_lbl.text = "  %s" % tr("TREASURE_FIND_COUNT")
		find_lbl.add_theme_font_size_override("font_size", 32)
		find_lbl.add_theme_color_override("font_color", TEXT_COLOR)
		find_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(find_lbl)
	q_panel.add_child(hbox)
	q_panel.position = Vector2(vp.x * 0.1, vp.y * 0.78)
	q_panel.size = Vector2(vp.x * 0.8, 80)
	add_child(q_panel)
	_all_round_nodes.append(q_panel)


func _add_question_dots(container: HBoxContainer, count: int) -> void:
	## Додає count кружечків у HBoxContainer як мініатюрні точки
	var clamped: int = clampi(count, 0, 6)
	for _i: int in clamped:
		var dot: Panel = Panel.new()
		var dot_sz: float = 22.0
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
	## Перевіряємо тап по сундуках — зона тапу = половина розміру сундука
	var tap_dist: float = TODDLER_CHEST_SIZE * 0.5
	for i: int in _toddler_cells.size():
		var cell: Node2D = _toddler_cells[i]
		if not is_instance_valid(cell):
			continue
		if pos.distance_to(cell.global_position) < tap_dist:
			_on_toddler_chest_tapped(i)
			return


func _on_toddler_chest_tapped(idx: int) -> void:
	if idx == _toddler_correct_idx:
		## Правильно! Відкриваємо сундук
		if idx >= 0 and idx < _toddler_cells.size():
			_register_correct(_toddler_cells[idx])
		AudioManager.play_sfx("success")
		HapticsManager.vibrate_success()
		if idx >= 0 and idx < _toddler_cells.size():
			var cell_pos: Vector2 = _toddler_cells[idx].global_position
			VFXManager.spawn_premium_celebration(cell_pos)
			VFXManager.spawn_golden_burst(cell_pos)
		## Scale pop на правильному сундуку
		if idx >= 0 and idx < _toddler_cells.size():
			var cell_node: Node2D = _toddler_cells[idx]
			if is_instance_valid(cell_node) and not SettingsManager.reduced_motion:
				var pop_tw: Tween = _create_game_tween()
				pop_tw.tween_property(cell_node, "scale", Vector2(1.25, 1.25), 0.12)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				pop_tw.tween_property(cell_node, "scale", Vector2.ONE, 0.15)
		_input_locked = true
		var d2: float = 0.15 if SettingsManager.reduced_motion else 0.8
		var tw: Tween = _create_game_tween()
		tw.tween_interval(d2)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(self):
				return
			_clear_round()
			_round += 1
			if _round >= TODDLER_ROUNDS:
				_finish()
			else:
				_start_round_toddler())
	else:
		## Помилка — м'який wobble, БЕЗ збільшення _errors (A6: Toddler no penalty)
		## _register_error обробляє: scaffolding (A11), click звук + wobble для Toddler
		if idx < 0 or idx >= _toddler_cells.size():
			push_warning("MathBingo toddler: idx %d поза межами _toddler_cells" % idx)
			return
		var cell: Node2D = _toddler_cells[idx]
		if not is_instance_valid(cell):
			push_warning("MathBingo toddler: невалідний сундук %d" % idx)
			return
		_register_error(cell)
