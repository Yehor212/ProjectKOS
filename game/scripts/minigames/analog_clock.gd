extends BaseMiniGame

## PRE-40 Аналоговий годинник — встанови стрілки на потрібний час!
## Дитина натискає кнопки щоб виставити години та хвилини.
## Наратив: "Розклад Тофі — який зараз час?" — через tr("TOFIE_SCHEDULE").

const TOTAL_ROUNDS: int = 5
const IDLE_HINT_DELAY: float = 5.0
const CLOCK_RADIUS: float = 100.0
const HOUR_HAND_LEN: float = 55.0
const MINUTE_HAND_LEN: float = 80.0
const HOUR_HAND_WIDTH: float = 6.0
const MINUTE_HAND_WIDTH: float = 4.0
const CLOCK_BG_COLOR: Color = Color("f8f9fa")
const CLOCK_BORDER_COLOR: Color = Color("2d3436")
const HOUR_HAND_COLOR: Color = Color("e74c3c")
const MINUTE_HAND_COLOR: Color = Color("3498db")
const MARK_COLOR: Color = Color("636e72")
const BTN_SIZE: Vector2 = Vector2(80, 60)
const CLOCK_NUM_OFFSET: float = 22.0
const TICK_OUTER_RADIUS: float = 8.0
const TICK_INNER_RADIUS: float = 14.0
const BTN_H_GAP: float = 85.0
const SAFETY_TIMEOUT_SEC: float = 120.0
const HOLD_REPEAT_DELAY: float = 0.45  ## Затримка перед першим повтором при утриманні
const HOLD_REPEAT_INTERVAL: float = 0.3  ## Інтервал авто-інкременту при утриманні

## Мапа активностей до емодзі-іконок для святкування (час дня -> візуальний зв'язок)
const ACTIVITY_EMOJI_MAP: Dictionary = {
	"morning": "weather",     ## ранок
	"breakfast": "fork_knife", ## сніданок
	"lunch": "basket",        ## обід
	"play": "star",           ## гра
	"dinner": "home",         ## вечеря
	"bath": "soap",           ## купання
	"sleep": "heart",         ## сон
}

## Toddler — "Який час?" — пул активностей денного розпорядку
const TODDLER_ACTIVITIES: Array[Dictionary] = [
	{"hour": 7, "icon": "weather", "label_key": "CLOCK_ACTIVITY_MORNING"},       ## ☀ ранок
	{"hour": 8, "icon": "fork_knife", "label_key": "CLOCK_ACTIVITY_BREAKFAST"},   ## 🍴 сніданок
	{"hour": 12, "icon": "basket", "label_key": "CLOCK_ACTIVITY_LUNCH"},          ## 🧺 обід
	{"hour": 15, "icon": "star", "label_key": "CLOCK_ACTIVITY_PLAY"},             ## ⭐ гра
	{"hour": 18, "icon": "home", "label_key": "CLOCK_ACTIVITY_DINNER"},           ## 🏠 вечеря
	{"hour": 20, "icon": "soap", "label_key": "CLOCK_ACTIVITY_BATH"},             ## 🧼 купання
	{"hour": 21, "icon": "heart", "label_key": "CLOCK_ACTIVITY_SLEEP"},           ## 💤 сон
]
const TODDLER_CLOCK_RADIUS: float = 100.0  ## 200dp діаметр
const TODDLER_HOUR_HAND_LEN: float = 55.0
const TODDLER_HOUR_HAND_WIDTH: float = 7.0
const TODDLER_CLOCK_GAP: float = 20.0

var _round: int = 0
var _start_time: float = 0.0
var _is_toddler: bool = false
var _toddler_used_indices: Array[int] = []

## Поточний і цільовий час
var _target_hour: int = 0
var _target_minute: int = 0
var _current_hour: int = 12
var _current_minute: int = 0

var _all_round_nodes: Array[Node] = []
var _clock_face: Node2D = null
var _hour_line: Line2D = null
var _minute_line: Line2D = null
var _center_dot: Panel = null
var _hour_tween: Tween = null
var _minute_tween: Tween = null

var _target_label: Label = null
var _current_label: Label = null
var _idle_timer: SceneTreeTimer = null

## Hold-to-increment стан (Preschool only)
var _hold_callback: Callable = Callable()
var _hold_timer: SceneTreeTimer = null
var _hold_active: bool = false


func _ready() -> void:
	game_id = "analog_clock"
	bg_theme = "city"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	## Наративна обгортка: "Розклад Тофі — який зараз час?"
	return tr("TOFIE_SCHEDULE") + " " + tr("CLOCK_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	if not _clock_face or not is_instance_valid(_clock_face):
		return {}
	return {"type": "tap", "target": _clock_face.global_position + Vector2(0, -CLOCK_RADIUS * 0.5)}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	if _is_toddler:
		_start_round_toddler()
		return
	_input_locked = true
	_current_hour = 12
	_current_minute = 0
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	## Генеруємо цільовий час
	_generate_target_time()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_target_display(vp)
	_spawn_clock(vp)
	_spawn_buttons(vp)
	_staggered_spawn(_all_round_nodes, 0.08)
	_update_hands()
	## Затримка перед активацією
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.4
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _generate_target_time() -> void:
	_target_hour = randi_range(1, 12)
	## Раунди 0-2: тільки повні години; 3: :00 або :30; 4+: всі чверті (:00/:15/:30/:45)
	if _round < 3:
		_target_minute = 0
	elif _round == 3:
		_target_minute = [0, 30].pick_random()
	else:
		_target_minute = [0, 15, 30, 45].pick_random()


func _spawn_target_display(vp: Vector2) -> void:
	var target_hbox: HBoxContainer = HBoxContainer.new()
	target_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	target_hbox.set("theme_override_constants/separation", 12)
	target_hbox.position = Vector2(0, vp.y * 0.16)
	target_hbox.size = Vector2(vp.x, 55)
	add_child(target_hbox)
	_all_round_nodes.append(target_hbox)
	var clock_icon: Control = IconDraw.clock_face(32.0)
	clock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_hbox.add_child(clock_icon)
	_target_label = Label.new()
	_target_label.text = _format_time(_target_hour, _target_minute)
	_target_label.add_theme_font_size_override("font_size", 40)
	target_hbox.add_child(_target_label)


func _spawn_clock(vp: Vector2) -> void:
	var center: Vector2 = Vector2(vp.x * 0.5, vp.y * 0.42)
	_clock_face = Node2D.new()
	_clock_face.position = center
	add_child(_clock_face)
	_all_round_nodes.append(_clock_face)
	## Фон циферблату
	var bg: Panel = Panel.new()
	var diameter: float = CLOCK_RADIUS * 2.0
	bg.size = Vector2(diameter, diameter)
	bg.position = Vector2(-CLOCK_RADIUS, -CLOCK_RADIUS)
	var style: StyleBoxFlat = GameData.candy_circle(CLOCK_BG_COLOR, CLOCK_RADIUS)
	style.border_color = CLOCK_BORDER_COLOR
	style.set_border_width_all(4)
	bg.add_theme_stylebox_override("panel", style)
	## Premium overlay + текстура годинника (LAW 28)
	var clock_tex: String = "res://assets/textures/backtiles/backtile_02.png"
	bg.material = GameData.create_premium_material(0.04, 2.0, 0.06, 0.08, 0.04, 0.03, 0.05, clock_tex, 0.15, 0.10, 0.22, 0.18)
	_clock_face.add_child(bg)
	## Числа на циферблаті (1-12)
	for h: int in range(1, 13):
		var angle: float = deg_to_rad(float(h) * 30.0 - 90.0)
		var num_r: float = CLOCK_RADIUS - CLOCK_NUM_OFFSET
		var num_pos: Vector2 = Vector2(cos(angle) * num_r, sin(angle) * num_r)
		var lbl: Label = Label.new()
		lbl.text = str(h)
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", MARK_COLOR)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = num_pos + Vector2(-12, -12)
		lbl.size = Vector2(24, 24)
		_clock_face.add_child(lbl)
	## Поділки на циферблаті
	for m: int in range(0, 60, 5):
		var angle: float = deg_to_rad(float(m) * 6.0 - 90.0)
		var outer_r: float = CLOCK_RADIUS - TICK_OUTER_RADIUS
		var inner_r: float = CLOCK_RADIUS - TICK_INNER_RADIUS
		var tick: Line2D = Line2D.new()
		tick.add_point(Vector2(cos(angle) * inner_r, sin(angle) * inner_r))
		tick.add_point(Vector2(cos(angle) * outer_r, sin(angle) * outer_r))
		tick.width = 2.0
		tick.default_color = MARK_COLOR
		_clock_face.add_child(tick)
	## Годинна стрілка
	_hour_line = Line2D.new()
	_hour_line.add_point(Vector2.ZERO)
	_hour_line.add_point(Vector2.ZERO)
	_hour_line.width = HOUR_HAND_WIDTH
	_hour_line.default_color = HOUR_HAND_COLOR
	_clock_face.add_child(_hour_line)
	## Хвилинна стрілка
	_minute_line = Line2D.new()
	_minute_line.add_point(Vector2.ZERO)
	_minute_line.add_point(Vector2.ZERO)
	_minute_line.width = MINUTE_HAND_WIDTH
	_minute_line.default_color = MINUTE_HAND_COLOR
	_clock_face.add_child(_minute_line)
	## Центральна крапка
	var dot_size: float = 10.0
	_center_dot = Panel.new()
	_center_dot.size = Vector2(dot_size, dot_size)
	_center_dot.position = Vector2(-dot_size * 0.5, -dot_size * 0.5)
	_center_dot.add_theme_stylebox_override("panel", GameData.candy_circle(CLOCK_BORDER_COLOR, dot_size * 0.5, false))
	_clock_face.add_child(_center_dot)
	## Поточний час під годинником
	_current_label = Label.new()
	_current_label.add_theme_font_size_override("font_size", 28)
	_current_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current_label.position = Vector2(vp.x * 0.5 - 60, vp.y * 0.42 + CLOCK_RADIUS + 16)
	_current_label.size = Vector2(120, 40)
	add_child(_current_label)
	_all_round_nodes.append(_current_label)


func _spawn_buttons(vp: Vector2) -> void:
	var btn_y: float = vp.y * 0.78
	var center_x: float = vp.x * 0.5
	var h_gap: float = BTN_H_GAP
	var m_gap: float = BTN_H_GAP
	## Кнопки годин (ліворуч)
	var hour_x: float = center_x - h_gap - m_gap * 0.5
	var hour_plus_cb: Callable = func() -> void: _adjust_hour(1)
	var hour_minus_cb: Callable = func() -> void: _adjust_hour(-1)
	_create_button(tr("CLOCK_PLUS_HOUR"), Vector2(hour_x - BTN_SIZE.x * 0.5, btn_y - BTN_SIZE.y - 5),
		Color("e74c3c"), hour_plus_cb, hour_plus_cb)
	_create_button(tr("CLOCK_MINUS_HOUR"), Vector2(hour_x - BTN_SIZE.x * 0.5, btn_y + 5),
		Color("c0392b"), hour_minus_cb, hour_minus_cb)
	## Кнопки хвилин (праворуч)
	var min_x: float = center_x + h_gap + m_gap * 0.5
	var min_plus_cb: Callable = func() -> void: _adjust_minute(5)
	var min_minus_cb: Callable = func() -> void: _adjust_minute(-5)
	_create_button(tr("CLOCK_PLUS_MIN"), Vector2(min_x - BTN_SIZE.x * 0.5, btn_y - BTN_SIZE.y - 5),
		Color("3498db"), min_plus_cb, min_plus_cb)
	_create_button(tr("CLOCK_MINUS_MIN"), Vector2(min_x - BTN_SIZE.x * 0.5, btn_y + 5),
		Color("2980b9"), min_minus_cb, min_minus_cb)
	## Кнопка перевірки (по центру) — код-малювана галочка (без hold)
	var check_btn: Button = _create_button("", Vector2(center_x - BTN_SIZE.x * 0.5, btn_y - BTN_SIZE.y * 0.5),
		Color("27ae60"), _check_answer)
	IconDraw.icon_in_button(check_btn, IconDraw.checkmark(22.0))


func _create_button(text: String, pos: Vector2, color: Color, callback: Callable, hold_cb: Callable = Callable()) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = BTN_SIZE
	btn.add_theme_font_size_override("font_size", 20)
	## Soft кнопки — єдиний стиль з головним меню
	btn.add_theme_stylebox_override("normal", ThemeManager.make_soft_style(color, color.darkened(0.2), 16, false))
	btn.add_theme_stylebox_override("hover", ThemeManager.make_soft_style(color.lightened(0.05), color.darkened(0.15), 16, false))
	btn.add_theme_stylebox_override("pressed", ThemeManager.make_soft_style(color, color.darkened(0.2), 16, true))
	btn.material = GameData.create_premium_material(0.04, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)  ## Grain overlay (LAW 28)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(func() -> void:
		if not _input_locked and not _game_over:
			callback.call())
	## Hold-to-increment: Preschool кнопки +Hour/-Hour/+Min/-Min авто-повторюють при утриманні
	if hold_cb.is_valid() and not _is_toddler:
		btn.button_down.connect(func() -> void:
			_start_hold_repeat(hold_cb))
		btn.button_up.connect(_stop_hold_repeat)
	add_child(btn)
	JuicyEffects.button_press_squish(btn, self)
	_all_round_nodes.append(btn)
	return btn


## ---- Керування часом ----

func _adjust_hour(delta: int) -> void:
	_current_hour += delta
	if _current_hour > 12:
		_current_hour = 1
	elif _current_hour < 1:
		_current_hour = 12
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	_update_hands()
	_reset_idle_timer()


func _adjust_minute(delta: int) -> void:
	_current_minute += delta
	if _current_minute >= 60:
		_current_minute = 0
	elif _current_minute < 0:
		_current_minute = 55
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	_update_hands()
	_reset_idle_timer()


## ---- Hold-to-increment: авто-повтор при утриманні кнопки (Preschool) ----


func _start_hold_repeat(cb: Callable) -> void:
	_hold_active = true
	_hold_callback = cb
	## Перший повтор після затримки HOLD_REPEAT_DELAY
	_hold_timer = get_tree().create_timer(HOLD_REPEAT_DELAY)
	_hold_timer.timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		_hold_repeat_tick())


func _hold_repeat_tick() -> void:
	if not _hold_active or _input_locked or _game_over:
		_stop_hold_repeat()
		return
	if _hold_callback.is_valid():
		_hold_callback.call()
	## Наступний тік через HOLD_REPEAT_INTERVAL
	_hold_timer = get_tree().create_timer(HOLD_REPEAT_INTERVAL)
	_hold_timer.timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		_hold_repeat_tick())


func _stop_hold_repeat() -> void:
	_hold_active = false
	_hold_callback = Callable()


func _update_hands() -> void:
	if not _hour_line or not _minute_line:
		return
	## Годинна стрілка — враховуємо хвилини для плавного руху
	var hour_angle: float = deg_to_rad(
		float(_current_hour % 12) * 30.0 + float(_current_minute) * 0.5 - 90.0)
	var hour_end: Vector2 = Vector2(cos(hour_angle) * HOUR_HAND_LEN,
		sin(hour_angle) * HOUR_HAND_LEN)
	## Плавна анімація стрілок замість миттєвого переміщення
	if not (SettingsManager and SettingsManager.reduced_motion):
		if _hour_tween and _hour_tween.is_valid():
			_hour_tween.kill()
		var h_from: Vector2 = _hour_line.get_point_position(1)
		_hour_tween = create_tween()
		_hour_tween.tween_method(_set_hour_hand_pos, h_from, hour_end, 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_hour_line.set_point_position(1, hour_end)
	## Хвилинна стрілка
	var minute_angle: float = deg_to_rad(float(_current_minute) * 6.0 - 90.0)
	var minute_end: Vector2 = Vector2(cos(minute_angle) * MINUTE_HAND_LEN,
		sin(minute_angle) * MINUTE_HAND_LEN)
	if not (SettingsManager and SettingsManager.reduced_motion):
		if _minute_tween and _minute_tween.is_valid():
			_minute_tween.kill()
		var m_from: Vector2 = _minute_line.get_point_position(1)
		_minute_tween = create_tween()
		_minute_tween.tween_method(_set_minute_hand_pos, m_from, minute_end, 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_minute_line.set_point_position(1, minute_end)
	## Оновити підпис поточного часу
	if _current_label:
		_current_label.text = _format_time(_current_hour, _current_minute)


func _set_hour_hand_pos(v: Vector2) -> void:
	if is_instance_valid(_hour_line):
		_hour_line.set_point_position(1, v)


func _set_minute_hand_pos(v: Vector2) -> void:
	if is_instance_valid(_minute_line):
		_minute_line.set_point_position(1, v)


func _check_answer() -> void:
	if _input_locked or _game_over:
		return
	_input_locked = true
	var hour_match: bool = (_current_hour == _target_hour)
	var minute_match: bool = (_current_minute == _target_minute)
	if hour_match and minute_match:
		_handle_correct()
	else:
		_handle_wrong()


func _handle_correct() -> void:
	_stop_hold_repeat()
	if _clock_face:
		_register_correct(_clock_face)
		_animate_correct_item(_clock_face)
	else:
		_register_correct()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	## Святкування: показати іконку активності біля годинника з bounce-масштабуванням
	_spawn_activity_celebration()
	var d: float = 0.15 if SettingsManager.reduced_motion else 1.0
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


func _handle_wrong() -> void:
	_stop_hold_repeat()
	_errors += 1
	if _clock_face:
		_register_error(_clock_face)
	else:
		_register_error()
	## Тремтіння годинника
	if _clock_face and not SettingsManager.reduced_motion:
		var orig_x: float = _clock_face.position.x
		var tw: Tween = create_tween()
		tw.tween_property(_clock_face, "position:x", orig_x - 8.0, 0.06)
		tw.tween_property(_clock_face, "position:x", orig_x + 8.0, 0.06)
		tw.tween_property(_clock_face, "position:x", orig_x - 4.0, 0.04)
		tw.tween_property(_clock_face, "position:x", orig_x, 0.04)
	var unlock_d: float = 0.15 if SettingsManager.reduced_motion else 0.25
	var unlock_tw: Tween = create_tween()
	unlock_tw.tween_interval(unlock_d)
	unlock_tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


## ---- Святкова анімація активності ----


## Визначити іконку активності за цільовою годиною (час дня -> візуальний контекст)
func _get_activity_icon_for_hour(hour: int) -> String:
	if hour >= 5 and hour <= 7:
		return "weather"      ## ранок
	elif hour >= 8 and hour <= 9:
		return "fork_knife"   ## сніданок
	elif hour >= 11 and hour <= 13:
		return "basket"       ## обід
	elif hour >= 14 and hour <= 16:
		return "star"         ## гра
	elif hour >= 17 and hour <= 19:
		return "home"         ## вечеря
	elif hour >= 20 and hour <= 21:
		return "soap"         ## купання
	else:
		return "heart"        ## сон / інше


## Показати іконку активності біля годинника з bounce-масштабуванням
func _spawn_activity_celebration() -> void:
	if not is_instance_valid(_clock_face):
		push_warning("analog_clock: celebration — clock_face invalid")
		return
	var icon_name: String = _get_activity_icon_for_hour(_target_hour)
	var icon_ctrl: Control = IconDraw.game_icon(icon_name, 48.0)
	if not icon_ctrl:
		push_warning("analog_clock: celebration — icon_ctrl null for " + icon_name)
		return
	icon_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Позиція: справа від годинника, трохи вище центру
	var offset: Vector2 = Vector2(CLOCK_RADIUS + 40.0, -CLOCK_RADIUS * 0.5)
	icon_ctrl.position = offset - Vector2(24.0, 24.0)
	_clock_face.add_child(icon_ctrl)
	## Bounce-масштабування: починається з 0, bounce до фінального розміру
	if SettingsManager.reduced_motion:
		icon_ctrl.scale = Vector2.ONE
		icon_ctrl.modulate.a = 1.0
	else:
		icon_ctrl.scale = Vector2.ZERO
		icon_ctrl.modulate.a = 0.0
		var cel_tw: Tween = create_tween().set_parallel(true)
		cel_tw.tween_property(icon_ctrl, "scale", Vector2(1.3, 1.3), 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		cel_tw.tween_property(icon_ctrl, "modulate:a", 1.0, 0.15)
		cel_tw.chain().tween_property(icon_ctrl, "scale", Vector2.ONE, 0.15)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _format_time(hour: int, minute: int) -> String:
	return "%d:%02d" % [hour, minute]


## ---- Управління раундами ----

func _clear_round() -> void:
	_stop_hold_repeat()
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_clock_face = null
	_hour_line = null
	_minute_line = null
	_center_dot = null
	_target_label = null
	_current_label = null


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = 5 if _is_toddler else _calculate_stars(_errors)
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
	if _input_locked or _game_over:
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	## Підказка — пульсуємо годинник
	if _clock_face and is_instance_valid(_clock_face):
		_pulse_node(_clock_face, 1.08)
	_reset_idle_timer()


## ---- Toddler Mode: «Який час?» — денний розпорядок ----

func _start_round_toddler() -> void:
	_input_locked = true
	_fade_instruction(_instruction_label, tr("CLOCK_TODDLER_INSTRUCTION"))
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Обираємо активність, яку ще не використовували
	var activity: Dictionary = _pick_toddler_activity()
	var target_hour: int = activity["hour"] as int
	## Генеруємо дистрактори
	var distractor_hours: Array[int] = _generate_toddler_distractors(target_hour)
	## Збираємо три години та перемішуємо
	var hours: Array[int] = [target_hour]
	hours.append_array(distractor_hours)
	hours.shuffle()
	## Показуємо назву активності зверху
	_spawn_toddler_activity_label(vp, activity)
	## Розташовуємо 3 годинники горизонтально
	var total_width: float = 3.0 * TODDLER_CLOCK_RADIUS * 2.0 + 2.0 * TODDLER_CLOCK_GAP
	var start_x: float = (vp.x - total_width) * 0.5 + TODDLER_CLOCK_RADIUS
	var clock_y: float = vp.y * 0.52
	for i: int in 3:
		var cx: float = start_x + float(i) * (TODDLER_CLOCK_RADIUS * 2.0 + TODDLER_CLOCK_GAP)
		var is_correct: bool = (hours[i] == target_hour)
		_spawn_toddler_clock(Vector2(cx, clock_y), hours[i], is_correct)
	_staggered_spawn(_all_round_nodes, 0.08)
	## Затримка перед активацією вводу
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.4
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _pick_toddler_activity() -> Dictionary:
	## Якщо всі використані — скидаємо пул
	if _toddler_used_indices.size() >= TODDLER_ACTIVITIES.size():
		_toddler_used_indices.clear()
	var available: Array[int] = []
	for i: int in TODDLER_ACTIVITIES.size():
		if i not in _toddler_used_indices:
			available.append(i)
	if available.is_empty():
		push_warning("analog_clock: toddler activities pool empty — fallback")
		return TODDLER_ACTIVITIES[0]
	var idx: int = available.pick_random()
	_toddler_used_indices.append(idx)
	return TODDLER_ACTIVITIES[idx]


func _generate_toddler_distractors(target: int) -> Array[int]:
	var min_diff: int = 3 if _round < 3 else 1
	var candidates: Array[int] = []
	for h: int in range(1, 13):
		var diff: int = absi(h - target)
		## Враховуємо обгортку 12-годинного циферблату
		diff = mini(diff, 12 - diff)
		if diff >= min_diff:
			candidates.append(h)
	candidates.shuffle()
	var result: Array[int] = []
	if candidates.size() >= 2:
		result.append(candidates[0])
		result.append(candidates[1])
	else:
		## Fallback — якщо недостатньо кандидатів, беремо будь-які різні від target
		push_warning("analog_clock: недостатньо дистракторів, fallback")
		for h: int in range(1, 13):
			if h != target and h not in result:
				result.append(h)
			if result.size() >= 2:
				break
	return result


func _spawn_toddler_activity_label(vp: Vector2, activity: Dictionary) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.set("theme_override_constants/separation", 12)
	hbox.position = Vector2(0, vp.y * 0.16)
	hbox.size = Vector2(vp.x, 55)
	add_child(hbox)
	_all_round_nodes.append(hbox)
	## Іконка активності
	var icon_name: String = activity.get("icon", "clock") as String
	var icon_ctrl: Control = IconDraw.game_icon(icon_name, 40.0)
	if icon_ctrl:
		icon_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon_ctrl)
	## Текстова мітка активності
	var lbl: Label = Label.new()
	lbl.text = tr(activity.get("label_key", "") as String)
	lbl.add_theme_font_size_override("font_size", 36)
	hbox.add_child(lbl)


func _spawn_toddler_clock(pos: Vector2, hour: int, is_correct: bool) -> void:
	var clock: Node2D = Node2D.new()
	clock.position = pos
	add_child(clock)
	_all_round_nodes.append(clock)
	## Фон циферблату — кругла панель
	var diameter: float = TODDLER_CLOCK_RADIUS * 2.0
	var bg: Panel = Panel.new()
	bg.size = Vector2(diameter, diameter)
	bg.position = Vector2(-TODDLER_CLOCK_RADIUS, -TODDLER_CLOCK_RADIUS)
	var style: StyleBoxFlat = GameData.candy_circle(CLOCK_BG_COLOR, TODDLER_CLOCK_RADIUS)
	style.border_color = CLOCK_BORDER_COLOR
	style.set_border_width_all(3)
	bg.add_theme_stylebox_override("panel", style)
	bg.material = GameData.create_premium_material(0.04, 2.0, 0.06, 0.08, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
	clock.add_child(bg)
	## Спрощені числа — тільки 12, 3, 6, 9
	var simple_hours: Array[int] = [12, 3, 6, 9]
	for h: int in simple_hours:
		var angle: float = deg_to_rad(float(h % 12) * 30.0 - 90.0)
		var num_r: float = TODDLER_CLOCK_RADIUS - CLOCK_NUM_OFFSET
		var num_pos: Vector2 = Vector2(cos(angle) * num_r, sin(angle) * num_r)
		var num_lbl: Label = Label.new()
		num_lbl.text = str(h)
		num_lbl.add_theme_font_size_override("font_size", 24)  ## Research: ≥24sp for kids, Toddler clocks need clear numbers
		num_lbl.add_theme_color_override("font_color", MARK_COLOR)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_lbl.position = num_pos + Vector2(-12, -12)
		num_lbl.size = Vector2(24, 24)
		clock.add_child(num_lbl)
	## Годинна стрілка (ТІЛЬКИ вона — без хвилинної)
	var hour_angle: float = deg_to_rad(float(hour % 12) * 30.0 - 90.0)
	var hour_end: Vector2 = Vector2(cos(hour_angle) * TODDLER_HOUR_HAND_LEN,
		sin(hour_angle) * TODDLER_HOUR_HAND_LEN)
	var hand: Line2D = Line2D.new()
	hand.add_point(Vector2.ZERO)
	hand.add_point(hour_end)
	hand.width = TODDLER_HOUR_HAND_WIDTH
	hand.default_color = HOUR_HAND_COLOR
	clock.add_child(hand)
	## Центральна крапка
	var dot_size: float = 10.0
	var dot: Panel = Panel.new()
	dot.size = Vector2(dot_size, dot_size)
	dot.position = Vector2(-dot_size * 0.5, -dot_size * 0.5)
	dot.add_theme_stylebox_override("panel", GameData.candy_circle(CLOCK_BORDER_COLOR, dot_size * 0.5, false))
	clock.add_child(dot)
	## Невидима кнопка для натискання — покриває весь годинник (≥15мм touch target)
	var touch_btn: Button = Button.new()
	touch_btn.position = Vector2(-TODDLER_CLOCK_RADIUS, -TODDLER_CLOCK_RADIUS)
	touch_btn.size = Vector2(diameter, diameter)
	touch_btn.flat = true
	touch_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	touch_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	touch_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	touch_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	touch_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	touch_btn.pressed.connect(func() -> void:
		if not _input_locked and not _game_over:
			_on_toddler_clock_tapped(is_correct, clock))
	clock.add_child(touch_btn)


func _on_toddler_clock_tapped(is_correct: bool, clock: Node2D) -> void:
	if _input_locked or _game_over:
		push_warning("analog_clock: toddler tap ignored — locked/over")
		return
	_input_locked = true
	if is_correct:
		_register_correct(clock)
		VFXManager.spawn_premium_celebration(clock.global_position)
		var d: float = 0.15 if SettingsManager.reduced_motion else 0.8
		var tw: Tween = create_tween()
		tw.tween_interval(d)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(self):
				return
			_clear_round()
			_round += 1
			if _round >= TOTAL_ROUNDS:
				_finish()
			else:
				_start_round_toddler())
	else:
		## Toddler помилки НЕ рахуються (A6)
		AudioManager.play_sfx("click")
		HapticsManager.vibrate_light()
		## Ніжне тремтіння годинника
		if is_instance_valid(clock) and not SettingsManager.reduced_motion:
			var orig_x: float = clock.position.x
			var wobble_tw: Tween = create_tween()
			wobble_tw.tween_property(clock, "position:x", orig_x - 6.0, 0.05)
			wobble_tw.tween_property(clock, "position:x", orig_x + 6.0, 0.05)
			wobble_tw.tween_property(clock, "position:x", orig_x - 3.0, 0.04)
			wobble_tw.tween_property(clock, "position:x", orig_x, 0.04)
		var unlock_d: float = 0.15 if SettingsManager.reduced_motion else 0.25
		var unlock_tw: Tween = create_tween()
		unlock_tw.tween_interval(unlock_d)
		unlock_tw.tween_callback(func() -> void:
			if not is_instance_valid(self):
				return
			_input_locked = false
			_reset_idle_timer())
