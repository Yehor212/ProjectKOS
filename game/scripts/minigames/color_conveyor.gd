extends BaseMiniGame

## ECE-02 Кольорова логістика — сортуй іграшки з конвеєра в кольорові кошики!
## Toddler: 2 кольори, нерухомий ряд, без штрафу. Preschool: 3 кольори, конвеєр, штраф.

const TOTAL_ROUNDS: int = 3
const ITEMS_TODDLER: int = 4
const ITEMS_PRESCHOOL: int = 6
const CONVEYOR_SPEED: float = 40.0
const CONVEYOR_Y_FACTOR: float = 0.38
const BASKET_Y_FACTOR: float = 0.82
const ITEM_SIZE: float = 70.0
const BASKET_W: float = 150.0
const BASKET_H: float = 110.0
const BASKET_CORNER: int = 18
const DEAL_STAGGER: float = 0.15
const DEAL_DURATION: float = 0.35
const PICK_RADIUS: float = 80.0
const TILT_FACTOR: float = 0.001
const TILT_MAX: float = 0.4
const TILT_LERP: float = 15.0
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0

const PALETTE: Array[Dictionary] = [
	{"id": "red", "color": Color("ef4444"), "name_key": "COLOR_RED"},
	{"id": "blue", "color": Color("3b82f6"), "name_key": "COLOR_BLUE"},
	{"id": "yellow", "color": Color("eab308"), "name_key": "COLOR_YELLOW"},
]
## Додаткові кольори для Preschool у пізніших раундах (A4: прогресивна складність)
const PALETTE_EXTRA: Array[Dictionary] = [
	{"id": "green", "color": Color("22c55e"), "name_key": "COLOR_GREEN"},
	{"id": "purple", "color": Color("a855f7"), "name_key": "COLOR_PURPLE"},
]

var _is_toddler: bool = false
var _round: int = 0
var _score: int = 0
var _sorted_count: int = 0
var _total_items: int = 0
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
var _baskets: Array[Dictionary] = []

var _current_conveyor_speed: float = CONVEYOR_SPEED  ## A4: швидкість конвеєра зростає з раундом (тільки Preschool)
var _idle_timer: SceneTreeTimer = null
var _conveyor_panel: Panel = null
var _narrative_label: Label = null


func _ready() -> void:
	game_id = "color_conveyor"
	bg_theme = "candy"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_build_narrative_label(tr("PAINTER_NEEDS"))
	_build_conveyor_belt()
	_build_baskets()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


## Наратив — "Художник малює картину!" лейбл
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
	if _items.is_empty() or _baskets.is_empty():
		return {}
	var item: Node2D = _items[0]
	var color_id: String = _item_color_id.get(item, "")
	for basket: Dictionary in _baskets:
		if basket.color_id == color_id:
			return {"type": "drag", "from": item.global_position, "to": basket.rect.get_center()}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


func _build_conveyor_belt() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var belt_y: float = vp.y * CONVEYOR_Y_FACTOR - 20.0
	_conveyor_panel = Panel.new()
	_conveyor_panel.position = Vector2(40, belt_y)
	_conveyor_panel.size = Vector2(vp.x - 80, 60)
	var style: StyleBoxFlat = GameData.candy_panel(Color(0.3, 0.3, 0.35, 0.75), 16)
	style.border_color = Color(1, 1, 1, 0.15)
	_conveyor_panel.add_theme_stylebox_override("panel", style)
	_conveyor_panel.material = GameData.create_premium_material(0.04, 2.0, 0.04, 0.06, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)  ## Grain overlay (LAW 28)
	add_child(_conveyor_panel)


func _build_baskets() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var colors: Array[Dictionary] = _get_palette()
	var count: int = colors.size()
	var spacing: float = vp.x / float(count + 1)
	var basket_y: float = vp.y * BASKET_Y_FACTOR
	for i: int in count:
		var c: Dictionary = colors[i]
		var x: float = spacing * float(i + 1) - BASKET_W * 0.5
		var rect: Rect2 = Rect2(x, basket_y - BASKET_H * 0.5, BASKET_W, BASKET_H)
		## Фон кошика
		var panel: Panel = Panel.new()
		panel.position = Vector2(x, basket_y - BASKET_H * 0.5)
		panel.size = Vector2(BASKET_W, BASKET_H)
		var style: StyleBoxFlat = GameData.candy_cell(Color(c.color, 0.80), BASKET_CORNER, true)
		style.border_color = Color(c.color, 0.85)
		style.set_border_width_all(3)
		panel.add_theme_stylebox_override("panel", style)
		panel.material = GameData.create_premium_material(0.05, 2.0, 0.04, 0.08, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)  ## Grain overlay (LAW 28)
		add_child(panel)
		## Кольорова точка кошика через IconDraw (LAW 25: pattern overlay)
		var _bsk_pat: String = GameData.get_cb_pattern(c.id) if SettingsManager.color_blind_mode else ""
		var dot: Control = IconDraw.color_dot_cb(36.0, c.color, _bsk_pat)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(x + (BASKET_W - 36.0) * 0.5, basket_y - BASKET_H * 0.5 + 17)
		add_child(dot)
		## Підпис кольору
		var name_lbl: Label = Label.new()
		name_lbl.text = tr(c.name_key)
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		name_lbl.position = Vector2(x, basket_y + BASKET_H * 0.5 - 36)
		name_lbl.size = Vector2(BASKET_W, 36)
		add_child(name_lbl)
		_baskets.append({"rect": rect, "color_id": c.id, "panel": panel})


func _get_palette() -> Array[Dictionary]:
	## Preschool: базова палітра + додаткові кольори
	if not _is_toddler:
		var full: Array[Dictionary] = PALETTE.duplicate()
		full.append_array(PALETTE_EXTRA)
		return full
	return PALETTE.duplicate()


## Палітра предметів для поточного раунду (Preschool: 3 кольори → 5 поступово)
func _get_round_palette() -> Array[Dictionary]:
	if _is_toddler:
		return PALETTE.duplicate()
	var base: Array[Dictionary] = PALETTE.duplicate()
	## Раунд 0: 3 кольори. Раунд 1: +green. Раунд 2: +purple.
	var extras_to_add: int = mini(_round, PALETTE_EXTRA.size())
	for i: int in extras_to_add:
		base.append(PALETTE_EXTRA[i])
	return base


## ---- Раунди ----

func _start_round() -> void:
	_sorted_count = 0
	_input_locked = true
	## A4: швидкість конвеєра зростає від CONVEYOR_SPEED до CONVEYOR_SPEED*1.5 для Preschool
	if not _is_toddler:
		_current_conveyor_speed = _scale_by_round(CONVEYOR_SPEED, CONVEYOR_SPEED * 1.5, _round, TOTAL_ROUNDS)
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	var palette: Array[Dictionary] = _get_round_palette()
	## Прогресивна складність: більше іграшок у пізніших раундах
	var per_round: int = _scale_by_round_i(3, ITEMS_TODDLER, _round, TOTAL_ROUNDS) if _is_toddler \
		else _scale_by_round_i(4, ITEMS_PRESCHOOL, _round, TOTAL_ROUNDS)
	_total_items = per_round
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	## Генеруємо кольорові іграшки з рівним розподілом
	var toy_colors: Array[Dictionary] = []
	for j: int in per_round:
		toy_colors.append(palette[j % palette.size()])
	toy_colors.shuffle()
	_spawn_items(toy_colors)


func _spawn_items(toy_colors: Array[Dictionary]) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = toy_colors.size()
	var conveyor_y: float = vp.y * CONVEYOR_Y_FACTOR
	var spacing: float = (vp.x - 160.0) / float(maxi(count, 1))
	var start_x: float = 80.0 + spacing * 0.5
	for i: int in count:
		var c: Dictionary = toy_colors[i]
		var target: Vector2 = Vector2(start_x + spacing * float(i), conveyor_y)
		var item: Node2D = _create_toy(c)
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
			var tw: Tween = create_tween().set_parallel(true)
			tw.tween_property(item, "position", target, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
			if i == count - 1:
				tw.chain().tween_callback(func() -> void:
					_input_locked = false
					_reset_idle_timer())


func _create_toy(c: Dictionary) -> Node2D:
	var node: Node2D = Node2D.new()
	add_child(node)
	## Кругле кольорове тло
	var bg: Panel = Panel.new()
	bg.size = Vector2(ITEM_SIZE, ITEM_SIZE)
	bg.position = Vector2(-ITEM_SIZE * 0.5, -ITEM_SIZE * 0.5)
	var style: StyleBoxFlat = GameData.candy_circle(c.color, ITEM_SIZE * 0.5)
	style.border_color = Color(1, 1, 1, 0.5)
	style.set_border_width_all(3)
	bg.add_theme_stylebox_override("panel", style)
	bg.material = GameData.create_premium_material(0.04, 2.0, 0.0, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)  ## Grain overlay (LAW 28)
	node.add_child(bg)
	## Кольорова точка через IconDraw (LAW 25: pattern overlay)
	var _item_pat: String = GameData.get_cb_pattern(c.id) if SettingsManager.color_blind_mode else ""
	var dot: Control = IconDraw.color_dot_cb(32.0, c.color, _item_pat)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.position = Vector2(-16.0, -16.0)
	node.add_child(dot)
	_items.append(node)
	_all_round_nodes.append(node)
	return node


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
	## Конвеєр — рух тільки для preschool
	if not _is_toddler and not _game_over:
		var vp_w: float = get_viewport().get_visible_rect().size.x
		for item: Node2D in _items:
			if not is_instance_valid(item) or item == _dragged:
				continue
			item.position.x += _current_conveyor_speed * delta
			## Іграшка доїхала до кінця → повертаємо на початок
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
	## Підсвітка кошиків
	for basket: Dictionary in _baskets:
		var p: Panel = basket.panel
		if basket.rect.has_point(_dragged.global_position):
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
		var tw: Tween = create_tween()
		tw.tween_property(best, "scale", Vector2(0.85, 1.15), 0.06)
		tw.tween_property(best, "scale", Vector2.ONE, 0.06)


func _try_drop() -> void:
	if not _dragged:
		return
	var item: Node2D = _dragged
	var drop_pos: Vector2 = item.global_position
	_dragged = null
	item.z_index = _drag_original_z
	## Squish
	if not SettingsManager.reduced_motion:
		var sq: Tween = create_tween()
		sq.tween_property(item, "scale", Vector2(1.2, 0.8), 0.06)
		sq.tween_property(item, "scale", Vector2.ONE, 0.08)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## Скинути підсвітку кошиків
	for basket: Dictionary in _baskets:
		basket.panel.modulate = Color.WHITE
	## Перевірити кошики
	for basket: Dictionary in _baskets:
		if basket.rect.has_point(drop_pos):
			if _item_color_id.get(item, "") == basket.color_id:
				_handle_correct(item, basket)
			else:
				_handle_wrong(item)
			return
	## Magnetic assist для тоддлерів — snap до найближчого кошика
	if _is_toddler:
		var nearest_basket: Dictionary = {}
		var nearest_dist: float = TODDLER_SNAP_RADIUS
		for basket: Dictionary in _baskets:
			var center: Vector2 = basket.rect.get_center()
			var d: float = drop_pos.distance_to(center)
			if d < nearest_dist:
				nearest_dist = d
				nearest_basket = basket
		if not nearest_basket.is_empty():
			if _item_color_id.get(item, "") == nearest_basket.color_id:
				_handle_correct(item, nearest_basket)
			else:
				_handle_wrong(item)
			return
	_snap_back(item)


## ---- Feedback ----

func _handle_correct(item: Node2D, basket: Dictionary) -> void:
	_register_correct(item)
	_items.erase(item)
	_sorted_count += 1
	_score += 1
	## Кошик підстрибує
	if not SettingsManager.reduced_motion:
		var panel: Panel = basket.panel
		var orig_y: float = panel.position.y
		var tw_b: Tween = create_tween()
		tw_b.tween_property(panel, "position:y", orig_y - 15.0, 0.1)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_b.tween_property(panel, "position:y", orig_y, 0.15)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	## "Brush stroke" — іграшка летить до кутка (мольберт) перед зникненням
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var corner: Vector2 = Vector2(vp.x - 60.0, 60.0)  ## Правий верхній кут — "мольберт"
	if SettingsManager.reduced_motion:
		item.global_position = corner
		item.modulate.a = 0.0
		item.queue_free()
		if _sorted_count >= _total_items:
			_on_round_complete()
		else:
			_reset_idle_timer()
		return
	var tw: Tween = create_tween()
	tw.tween_property(item, "global_position", corner, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(item, "scale", Vector2(0.2, 0.2), 0.3)
	tw.parallel().tween_property(item, "rotation_degrees", 360.0, 0.3)
	tw.tween_property(item, "modulate:a", 0.0, 0.1)
	tw.tween_callback(item.queue_free)
	## VFX sparkle на мольберті (LAW 28)
	VFXManager.spawn_correct_sparkle(corner)
	if _sorted_count >= _total_items:
		tw.chain().tween_callback(_on_round_complete)
	else:
		_reset_idle_timer()


func _handle_wrong(item: Node2D) -> void:
	if not _is_toddler:
		_errors += 1
		_register_error(item)
	else:
		_register_error(item)  ## A11: scaffolding для тоддлера
	_snap_back(item)


func _snap_back(item: Node2D) -> void:
	if not _item_origins.has(item):
		push_warning("Conveyor: _item_origins не містить item")
		return
	if SettingsManager.reduced_motion:
		item.position = _item_origins[item]
		item.rotation = 0.0
		return
	var tw: Tween = create_tween()
	tw.tween_property(item, "position", _item_origins[item], 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "rotation", 0.0, 0.15)


## ---- Round management ----

func _on_round_complete() -> void:
	_input_locked = true
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	VFXManager.spawn_premium_celebration(vp * 0.5)
	## "Masterpiece" лейбл з star burst
	if not SettingsManager.reduced_motion:
		var master_lbl: Label = Label.new()
		master_lbl.text = tr("PAINTER_MASTERPIECE")
		master_lbl.add_theme_font_size_override("font_size", 36)
		master_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1.0))
		master_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		master_lbl.position = Vector2(vp.x * 0.2, vp.y * 0.4)
		master_lbl.size = Vector2(vp.x * 0.6, 50)
		master_lbl.scale = Vector2.ZERO
		add_child(master_lbl)
		var m_tw: Tween = create_tween()
		m_tw.tween_property(master_lbl, "scale", Vector2(1.2, 1.2), 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		m_tw.tween_property(master_lbl, "scale", Vector2.ONE, 0.15)
		m_tw.tween_interval(0.5)
		m_tw.tween_property(master_lbl, "modulate:a", 0.0, 0.3)
		m_tw.tween_callback(master_lbl.queue_free)
		VFXManager.spawn_correct_sparkle(Vector2(vp.x - 60.0, 60.0))
	var d: float = 0.15 if SettingsManager.reduced_motion else 1.2
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


func _clear_round() -> void:
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_items.clear()
	_item_color_id.clear()
	_item_origins.clear()


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
