extends BaseMiniGame

## ECE-20 Сенсорна пісочниця — вільне неонове малювання!
## Toddler: товстий пензель, авто-зміна кольору. Preschool: палітра + тонший пензель.
## Без раундів — вільне творчість з таймером.

const GAME_DURATION_TODDLER: float = 90.0
const GAME_DURATION_PRESCHOOL: float = 120.0
const BRUSH_TODDLER: float = 20.0
const BRUSH_PRESCHOOL: float = 12.0
const NEON_GLOW: float = 3.0
const COLOR_CYCLE_SPEED: float = 0.4
const IDLE_HINT_DELAY: float = 6.0
const PALETTE_SIZE: float = 64.0
const PALETTE_GAP: float = 10.0
const SAFETY_TIMEOUT_SEC: float = 300.0

const NEON_COLORS: Array[Color] = [
	Color("ff6b6b"), Color("ffd166"), Color("06d6a0"),
	Color("118ab2"), Color("a78bfa"), Color("f472b6"),
	Color("fb923c"), Color("38bdf8"),
]
## COLOR_EMOJIS видалено — замінено на IconDraw.color_dot()

var _is_toddler: bool = false
var _start_time: float = 0.0
var _drawing: bool = false
var _game_duration: float = 45.0

var _current_color_idx: int = 0
var _current_color: Color = Color("ff6b6b")
var _brush_width: float = 20.0
var _current_line: Line2D = null
var _canvas: Node2D = null
var _timer_label: Label = null
var _palette_buttons: Array[Panel] = []
var _all_nodes: Array[Node] = []
var _stroke_count: int = 0

var _idle_timer: SceneTreeTimer = null
var _game_timer: float = 0.0
var _warned_low_time: bool = false


func _ready() -> void:
	game_id = "sensory_sandbox"
	_skill_id = "sensory_exploration"
	bg_theme = "sky"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_game_duration = GAME_DURATION_TODDLER if _is_toddler else GAME_DURATION_PRESCHOOL
	_brush_width = BRUSH_TODDLER if _is_toddler else BRUSH_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_game_timer = _game_duration
	_apply_background()
	_build_hud()
	_spawn_canvas()
	if not _is_toddler:
		_spawn_palette()
		_orchestrated_entrance(_palette_buttons as Array, 0.06, false, "pop")
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.55
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("SANDBOX_TUTORIAL_TODDLER")
	return tr("SANDBOX_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return {"type": "tap", "target": Vector2(vp.x * 0.5, vp.y * 0.45)}


func _build_hud() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_build_instruction_pill(get_tutorial_instruction())
	## Таймер
	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 24)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	_timer_label.position = Vector2(0, _sa_top + 104)
	_timer_label.size = Vector2(vp.x, 30)
	add_child(_timer_label)


func _spawn_canvas() -> void:
	_canvas = Node2D.new()
	add_child(_canvas)
	_all_nodes.append(_canvas)
	## Текстурований фон полотна для малювання
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var canvas_bg: TextureRect = TextureRect.new()
	canvas_bg.size = Vector2(vp.x - 32.0, vp.y * 0.75)
	canvas_bg.position = Vector2(16.0, 16.0)
	canvas_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	canvas_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var canvas_tex_path: String = "res://assets/textures/backtiles/backtile_14.png"
	if ResourceLoader.exists(canvas_tex_path):
		canvas_bg.texture = load(canvas_tex_path)
	canvas_bg.modulate = Color(1, 1, 1, 0.12)
	canvas_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas_bg)
	_all_nodes.append(canvas_bg)


func _spawn_palette() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = NEON_COLORS.size()
	var total_w: float = float(count) * PALETTE_SIZE + float(count - 1) * PALETTE_GAP
	var start_x: float = (vp.x - total_w) * 0.5
	var palette_y: float = vp.y - 70.0
	for i: int in count:
		var color: Color = NEON_COLORS[i]
		var btn: Panel = Panel.new()
		btn.size = Vector2(PALETTE_SIZE, PALETTE_SIZE)
		btn.position = Vector2(start_x + float(i) * (PALETTE_SIZE + PALETTE_GAP), palette_y)
		var style: StyleBoxFlat = GameData.candy_circle(color, PALETTE_SIZE * 0.5)
		style.shadow_color = color * Color(1, 1, 1, 0.5)
		btn.add_theme_stylebox_override("panel", style)
		## Grain overlay (LAW 28)
		btn.material = GameData.create_premium_material(0.04, 2.0, 0.0, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		btn.set_meta("color_idx", i)
		## LAW 10: мітка кольору для навчальної цінності — IconDraw.color_dot()
		var dot: Control = IconDraw.color_dot(16.0, color)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2((PALETTE_SIZE - 16.0) * 0.5, (PALETTE_SIZE - 16.0) * 0.5)
		btn.add_child(dot)
		add_child(btn)
		_palette_buttons.append(btn)
		_all_nodes.append(btn)
	_highlight_palette(0)


func _highlight_palette(selected_idx: int) -> void:
	for i: int in _palette_buttons.size():
		var btn: Panel = _palette_buttons[i]
		var color: Color = NEON_COLORS[i]
		var style: StyleBoxFlat = GameData.candy_circle(color, PALETTE_SIZE * 0.5)
		if i == selected_idx:
			style.border_color = Color.WHITE
			style.set_border_width_all(3)
		else:
			style.border_color = Color(0, 0, 0, 0)
			style.set_border_width_all(0)
		style.shadow_color = color * Color(1, 1, 1, 0.4)
		style.shadow_size = 5
		btn.add_theme_stylebox_override("panel", style)


## ---- Process: таймер + автозміна кольору ----

func _process(delta: float) -> void:
	if _game_over or _input_locked:
		return
	_game_timer -= delta
	if _game_timer <= 0.0:
		_finish()
		return
	var secs: int = int(ceil(_game_timer))
	_timer_label.text = "%d" % secs
	## UX-19: Попередження при <10с
	if _game_timer <= 10.0:
		_timer_label.add_theme_color_override("font_color", Color("ff6b6b"))
		if not _warned_low_time:
			_warned_low_time = true
			AudioManager.play_sfx("click")
	## Toddler: авто-зміна кольору з часом
	if _is_toddler and _drawing:
		var time: float = Time.get_ticks_msec() / 1000.0
		var idx: int = int(time * COLOR_CYCLE_SPEED) % NEON_COLORS.size()
		if idx != _current_color_idx:
			_current_color_idx = idx
			_current_color = NEON_COLORS[idx]
			if _current_line:
				_current_line.default_color = _current_color


## ---- Input: малювання ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	if event is InputEventMouseButton:
		if event.pressed:
			if not _is_toddler and _try_select_palette(event.position):
				return
			_start_stroke(event.position)
		else:
			_end_stroke()
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			if not _is_toddler and _try_select_palette(event.position):
				return
			_start_stroke(event.position)
		else:
			_end_stroke()
	elif event is InputEventMouseMotion and _drawing:
		_add_point(event.position)
	elif event is InputEventScreenDrag and _drawing and event.index == 0:
		_add_point(event.position)


func _try_select_palette(pos: Vector2) -> bool:
	for btn: Panel in _palette_buttons:
		var rect: Rect2 = Rect2(btn.position, btn.size)
		if rect.has_point(pos):
			var idx: int = btn.get_meta("color_idx") as int
			_current_color_idx = idx
			_current_color = NEON_COLORS[idx]
			_highlight_palette(idx)
			AudioManager.play_sfx("click")
			return true
	return false


func _start_stroke(pos: Vector2) -> void:
	_drawing = true
	AudioManager.play_sfx("click")
	_current_line = Line2D.new()
	_current_line.width = _brush_width
	_current_line.default_color = _current_color
	_current_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_current_line.add_point(pos)
	_canvas.add_child(_current_line)
	HapticsManager.vibrate_light()
	_stroke_count += 1
	## Ambient sparkle на першому мазку — привітальний wow-ефект
	if _stroke_count == 1 and not SettingsManager.reduced_motion:
		VFXManager.spawn_correct_sparkle(pos)
	_reset_idle_timer()


func _add_point(pos: Vector2) -> void:
	if _current_line and _drawing:
		if _current_line.get_point_count() >= 500:
			_end_stroke()
			_start_stroke(pos)
			return
		if _current_line.get_point_count() == 0:
			_current_line.add_point(pos)
		else:
			var last: Vector2 = _current_line.get_point_position(
				_current_line.get_point_count() - 1)
			if pos.distance_to(last) > 3.0:
				_current_line.add_point(pos)


func _end_stroke() -> void:
	_drawing = false
	if _current_line and _current_line.get_point_count() < 2:
		_current_line.queue_free()
	_current_line = null


## ---- Finish ----

func _finish() -> void:
	_game_over = true
	_input_locked = true
	_drawing = false
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	## Завжди 5 зірок — це вільне творчість
	var earned: int = _calculate_stars(0)
	finish_game(earned, {"time_sec": elapsed, "errors": 0,
		"rounds_played": 1, "strokes": _stroke_count, "earned_stars": earned})


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
	## Підказка: пульсація інструкції
	if _instruction_label and not SettingsManager.reduced_motion:
		var tw: Tween = create_tween()
		tw.tween_property(_instruction_label, "modulate:a", 0.4, 0.3)
		tw.tween_property(_instruction_label, "modulate:a", 1.0, 0.3)
	_reset_idle_timer()


## ---- Background ----

func _apply_background() -> void:
	super()
	## Темний фон для неонового ефекту
	if has_node("Background"):
		$Background.modulate = Color(0.15, 0.12, 0.2, 1.0)
