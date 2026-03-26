extends BaseMiniGame

## ECE-09 Інтелектуальна розмальовка — малюй по тварині кольоровим пензлем!
## Toddler: 3 раунди, 4 кольори, товстий пензель, завжди 5 зірок.
## Preschool: 4 раунди, 6 кольорів, тонший пензель, завжди 5 зірок (креативна гра, A5).

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 4
const BRUSH_TODDLER: float = 28.0
const BRUSH_PRESCHOOL: float = 16.0
const MIN_STROKES_DONE: int = 4
const IDLE_HINT_DELAY: float = 6.0
const PALETTE_SIZE: float = 56.0
const PALETTE_GAP: float = 14.0
const SAFETY_TIMEOUT_SEC: float = 300.0

const COLORS_TODDLER: Array[Color] = [
	Color("ef476f"), Color("06d6a0"), Color("118ab2"), Color("ffd166"),
]
const COLORS_PRESCHOOL: Array[Color] = [
	Color("ef476f"), Color("06d6a0"), Color("118ab2"),
	Color("ffd166"), Color("a78bfa"), Color("fb923c"),
]
## LAW 25: Color IDs for color-blind pattern mapping (parallel to COLORS_ arrays)
const COLOR_IDS_T: Array[String] = ["pink", "green", "blue", "yellow"]
const COLOR_IDS_P: Array[String] = ["pink", "green", "blue", "yellow", "purple", "orange"]

const ANIMAL_NAMES: Array[String] = [
	"Bear", "Bunny", "Cat", "Chicken", "Cow", "Crocodile", "Deer",
	"Dog", "Elephant", "Frog", "Goat", "Hedgehog", "Horse",
	"Lion", "Monkey", "Mouse", "Panda", "Penguin", "Squirrel",
]

var _is_toddler: bool = false
var _round: int = 0
var _total_rounds: int = 0
var _start_time: float = 0.0

var _current_color: Color = Color.RED
var _brush_width: float = 28.0
var _drawing: bool = false
var _current_line: Line2D = null
var _strokes: Array[Line2D] = []
var _used_colors: Dictionary = {}
var _stroke_count: int = 0
var _min_strokes_round: int = MIN_STROKES_DONE

var _canvas: Node2D = null
var _silhouette: Sprite2D = null
var _palette_buttons: Array[Panel] = []
var _done_btn: Button = null
var _all_round_nodes: Array[Node] = []
var _used_animals: Array[int] = []

var _idle_timer: SceneTreeTimer = null


func _ready() -> void:
	game_id = "smart_coloring"
	bg_theme = "sky"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_brush_width = BRUSH_TODDLER if _is_toddler else BRUSH_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("COLORING_TUTORIAL_TODDLER")
	return tr("COLORING_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if not is_instance_valid(_silhouette):
		return {}
	return {"type": "tap", "target": _silhouette.global_position}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction(), 24)


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_stroke_count = 0
	_strokes.clear()
	_used_colors.clear()
	## A4: прогресивна складність — тонший пензель і більше штрихів у пізніших раундах
	var base_brush: float = BRUSH_TODDLER if _is_toddler else BRUSH_PRESCHOOL
	_brush_width = _scale_by_round(base_brush, base_brush * 0.65, _round, _total_rounds)
	_min_strokes_round = _scale_by_round_i(MIN_STROKES_DONE, MIN_STROKES_DONE + 4, _round, _total_rounds)
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	var animal: String = _pick_animal()
	if not _spawn_canvas(animal):
		return  ## _skip_round вже заплановано через call_deferred
	_spawn_palette()
	_spawn_done_button()
	_orchestrated_entrance(_all_round_nodes as Array, 0.06, false, "pop")
	## Unlock після короткої затримки
	var unlock_d: float = 0.15 if SettingsManager.reduced_motion else 0.55
	var tw: Tween = _create_game_tween()
	tw.tween_interval(unlock_d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _pick_animal() -> String:
	if _used_animals.size() >= ANIMAL_NAMES.size():
		_used_animals.clear()
	var idx: int = randi() % ANIMAL_NAMES.size()
	while _used_animals.has(idx):
		idx = randi() % ANIMAL_NAMES.size()
	_used_animals.append(idx)
	return ANIMAL_NAMES[idx]


func _spawn_canvas(animal_name: String) -> bool:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Контейнер для малювання — створюємо завжди
	_canvas = Node2D.new()
	add_child(_canvas)
	_all_round_nodes.append(_canvas)
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if not ResourceLoader.exists(tex_path):
		push_warning("SmartColoring: Missing sprite: " + tex_path)
		## A8: fallback — спробувати будь-яку іншу тварину
		var found: bool = false
		for fallback_name: String in ANIMAL_NAMES:
			if fallback_name == animal_name:
				continue
			var fb_path: String = "res://assets/sprites/animals/%s.png" % fallback_name
			if ResourceLoader.exists(fb_path):
				tex_path = fb_path
				found = true
				break
		if not found:
			push_warning("SmartColoring: No animal textures found — skipping round")
			call_deferred("_skip_round")
			return false
	var tex: Texture2D = load(tex_path)
	if not tex:
		push_warning("SmartColoring: текстуру '%s' не вдалось завантажити" % tex_path)
		call_deferred("_skip_round")
		return false
	## Силует тварини — чорно-білий (десатурований shader)
	_silhouette = Sprite2D.new()
	_silhouette.texture = tex
	_silhouette.position = Vector2(vp.x * 0.5, vp.y * 0.45)
	_silhouette.scale = Vector2(0.55, 0.55)
	_silhouette.modulate = Color(1.0, 1.0, 1.0, 0.6)
	## Grayscale shader — LAW 1: колір розкривається ПІСЛЯ малювання
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item;\nuniform float saturation : hint_range(0.0, 1.0) = 0.0;\nvoid fragment() {\n\tvec4 col = texture(TEXTURE, UV);\n\tfloat gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));\n\tcol.rgb = mix(vec3(gray), col.rgb, saturation);\n\tCOLOR = col * COLOR;\n}"
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	_silhouette.material = mat
	add_child(_silhouette)
	_all_round_nodes.append(_silhouette)
	return true


func _spawn_palette() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var colors: Array[Color] = COLORS_TODDLER if _is_toddler else COLORS_PRESCHOOL
	var count: int = colors.size()
	var total_w: float = float(count) * PALETTE_SIZE + float(count - 1) * PALETTE_GAP
	var start_x: float = (vp.x - total_w) * 0.5
	var palette_y: float = vp.y - 90.0
	_palette_buttons.clear()
	for i: int in count:
		var color: Color = colors[i]
		var btn: Panel = Panel.new()
		btn.size = Vector2(PALETTE_SIZE, PALETTE_SIZE)
		btn.position = Vector2(start_x + float(i) * (PALETTE_SIZE + PALETTE_GAP), palette_y)
		var style: StyleBoxFlat = GameData.candy_circle(color, PALETTE_SIZE * 0.5)
		btn.add_theme_stylebox_override("panel", style)
		## Grain overlay (LAW 28)
		btn.material = GameData.create_premium_material(0.04, 2.0, 0.0, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		btn.set_meta("color", color)
		btn.set_meta("index", i)
		## LAW 10 + LAW 25: мітка кольору з pattern overlay
		var _ids: Array[String] = COLOR_IDS_T if _is_toddler else COLOR_IDS_P
		var _pal_pat: String = GameData.get_cb_pattern(_ids[i]) if SettingsManager.color_blind_mode else ""
		var dot: Control = IconDraw.color_dot_cb(16.0, color, _pal_pat)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2((PALETTE_SIZE - 16.0) * 0.5, (PALETTE_SIZE - 16.0) * 0.5)
		btn.add_child(dot)
		## LAW 10: Підпис кольору для навчання
		var color_label: Label = Label.new()
		var color_key: String = "COLOR_%s" % _ids[i].to_upper()
		color_label.text = tr(color_key)
		color_label.add_theme_font_size_override("font_size", 20)
		color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		color_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		color_label.position = Vector2(0, PALETTE_SIZE + 2.0)
		color_label.size = Vector2(PALETTE_SIZE, 18)
		color_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(color_label)
		add_child(btn)
		_palette_buttons.append(btn)
		_all_round_nodes.append(btn)
	## Виділити перший колір за замовчуванням
	_current_color = colors[0]
	_highlight_palette(0)


func _highlight_palette(selected_idx: int) -> void:
	for i: int in _palette_buttons.size():
		var btn: Panel = _palette_buttons[i]
		var color: Color = btn.get_meta("color") as Color
		var style: StyleBoxFlat = GameData.candy_circle(color, PALETTE_SIZE * 0.5)
		if i == selected_idx:
			style.border_color = Color.WHITE
			style.set_border_width_all(4)
			style.shadow_color = Color(0, 0, 0, 0.35)
			style.shadow_size = 6
		else:
			style.border_color = Color(0, 0, 0, 0.1)
			style.set_border_width_all(1)
			style.shadow_color = Color(0, 0, 0, 0.15)
			style.shadow_size = 3
		style.shadow_offset = Vector2(1, 3)
		btn.add_theme_stylebox_override("panel", style)


func _spawn_done_button() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var s: float = _ui_scale()
	_done_btn = Button.new()
	_done_btn.theme_type_variation = &"SecondaryButton"
	IconDraw.icon_in_button(_done_btn, IconDraw.checkmark(28.0 * s))
	_done_btn.size = Vector2(70.0 * s, 70.0 * s)
	## Над палітрою (palette_y = vp.y - 90) з зазором 16px
	var palette_top: float = vp.y - 90.0
	_done_btn.position = Vector2(vp.x - 90.0 * s, palette_top - 70.0 * s - 16.0)
	_done_btn.visible = false
	_done_btn.pressed.connect(_on_done_pressed)
	add_child(_done_btn)
	JuicyEffects.button_press_squish(_done_btn, self)
	_all_round_nodes.append(_done_btn)


## ---- Input: малювання ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	var pos: Vector2 = Vector2.ZERO
	var pressed: bool = false
	var released: bool = false
	if event is InputEventMouseButton:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion and _drawing:
		_add_point(event.position)
		return
	elif event is InputEventScreenDrag and _drawing and event.index == 0:
		_add_point(event.position)
		return
	else:
		return
	if pressed:
		## Перевірити чи натиснуто на палітру
		if _try_select_palette(pos):
			return
		_start_stroke(pos)
	elif released and _drawing:
		_end_stroke()


func _try_select_palette(pos: Vector2) -> bool:
	for btn: Panel in _palette_buttons:
		var rect: Rect2 = Rect2(btn.position, btn.size)
		if rect.has_point(pos):
			var color: Color = btn.get_meta("color") as Color
			var idx: int = btn.get_meta("index") as int
			_current_color = color
			_highlight_palette(idx)
			AudioManager.play_sfx("click")
			return true
	return false


func _start_stroke(pos: Vector2) -> void:
	_drawing = true
	_current_line = Line2D.new()
	_current_line.width = _brush_width
	_current_line.default_color = _current_color
	_current_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_current_line.add_point(pos)
	_canvas.add_child(_current_line)
	HapticsManager.vibrate_light()


func _add_point(pos: Vector2) -> void:
	if _current_line and _drawing:
		if _current_line.get_point_count() >= 500:
			_end_stroke()
			_start_stroke(pos)
			return
		## Мінімальна відстань між точками для плавності
		if _current_line.get_point_count() == 0:
			_current_line.add_point(pos)
		else:
			var last: Vector2 = _current_line.get_point_position(
				_current_line.get_point_count() - 1)
			if pos.distance_to(last) > 4.0:
				_current_line.add_point(pos)


func _end_stroke() -> void:
	_drawing = false
	if _current_line and _current_line.get_point_count() > 1:
		_strokes.append(_current_line)
		_stroke_count += 1
		var color_key: String = _current_color.to_html(false)
		_used_colors[color_key] = true
		## Показати кнопку "Готово" після достатньої кількості штрихів
		if _stroke_count >= _min_strokes_round and _done_btn and not _done_btn.visible:
			_done_btn.visible = true
			if not SettingsManager.reduced_motion:
				var tw: Tween = create_tween()
				tw.tween_property(_done_btn, "modulate:a", 1.0, 0.3)
			else:
				_done_btn.modulate.a = 1.0
		_reset_idle_timer()
	elif _current_line:
		_current_line.queue_free()
	_current_line = null


func _on_done_pressed() -> void:
	if _input_locked or _game_over:
		return
	_input_locked = true
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	## Плавне розкриття кольору — LAW 1 (saturation 0→1)
	if _silhouette:
		if not SettingsManager.reduced_motion:
			var tw: Tween = create_tween().set_parallel(true)
			if _silhouette.material is ShaderMaterial:
				tw.tween_property(_silhouette.material, "shader_parameter/saturation", 1.0, 0.8)\
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(_silhouette, "modulate:a", 1.0, 0.5)
		else:
			if _silhouette.material is ShaderMaterial:
				_silhouette.material.set_shader_parameter("saturation", 1.0)
			_silhouette.modulate.a = 1.0
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var round_d: float = 0.15 if SettingsManager.reduced_motion else 1.2
	var tw2: Tween = create_tween()
	tw2.tween_interval(round_d)
	tw2.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round())


## ---- Round management ----

## A8: graceful skip якщо текстура тварини відсутня
func _skip_round() -> void:
	_clear_round()
	_round += 1
	if _round >= _total_rounds:
		_finish()
	else:
		_start_round()


func _clear_round() -> void:
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_strokes.clear()
	_palette_buttons.clear()
	_canvas = null
	_silhouette = null
	_done_btn = null
	_current_line = null
	_drawing = false


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	## Креативна гра — завжди 5 зірок (аксіома A5)
	var earned: int = _calculate_stars(0)
	finish_game(earned, {"time_sec": elapsed, "errors": 0,
		"rounds_played": _total_rounds, "strokes": _stroke_count,
		"colors_used": _used_colors.size(), "earned_stars": earned})


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
	## Підказка: пульсація палітри
	if not _palette_buttons.is_empty():
		var btn: Panel = _palette_buttons[0]
		if is_instance_valid(btn):
			_pulse_node(btn, 1.2)
	_reset_idle_timer()
