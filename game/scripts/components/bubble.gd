class_name Bubble
extends Node2D

## Компонент пузиря для Color Pop — Area2D tap + wobble shader + pop анімація.

const DEFAULT_RADIUS: float = 40.0
const HIGHLIGHT_OFFSET: Vector2 = Vector2(-0.3, -0.3)
const HIGHLIGHT_RADIUS_FACTOR: float = 0.25

signal popped(bubble_instance: Node2D)

var bubble_color: Color = Color.WHITE
var _speed: float = 100.0
var _radius: float = DEFAULT_RADIUS
var _popped: bool = false
var _cb_pattern: String = ""


func setup(color: Color, speed: float, radius: float = DEFAULT_RADIUS) -> void:
	bubble_color = color
	_speed = speed
	_radius = radius
	## LAW 25: Color-blind pattern overlay
	if SettingsManager.color_blind_mode:
		_cb_pattern = GameData.get_cb_pattern_for_color(color)
	## Area2D + CircleShape2D (патерн з floating_cloud.gd)
	var area: Area2D = Area2D.new()
	area.input_pickable = true
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.input_event.connect(_on_area_input)
	## Wobble shader
	var shader: Shader = load("res://assets/shaders/bubble_wobble.gdshader")
	if shader:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("grain_tex", GameData._get_grain_texture())
		mat.set_shader_parameter("grain_intensity", 0.0)  ## Grain вимкнений глобально
		mat.set_shader_parameter("iridescence", 0.3)
		material = mat
	queue_redraw()


func _process(delta: float) -> void:
	position.y -= _speed * delta
	if position.y < -_radius * 2.0:
		queue_free()


func _draw() -> void:
	## Тіло пузиря (напівпрозоре)
	draw_circle(Vector2.ZERO, _radius, Color(bubble_color, 0.45))
	## Darker bottom half — градієнтна глибина
	var dark_c: Color = Color(bubble_color.darkened(0.15), 0.25)
	var segs: int = 20
	var bottom_pts: PackedVector2Array = PackedVector2Array()
	bottom_pts.append(Vector2(-_radius, 0.0))
	for i: int in range(segs + 1):
		var angle: float = float(i) / float(segs) * PI
		bottom_pts.append(Vector2(cos(angle), sin(angle)) * _radius)
	draw_colored_polygon(bottom_pts, dark_c)
	## Обводка
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(bubble_color, 0.7), 2.0, true)
	## Відблиск (маленьке біле коло зверху-зліва)
	var hl_pos: Vector2 = HIGHLIGHT_OFFSET * _radius
	draw_circle(hl_pos, _radius * HIGHLIGHT_RADIUS_FACTOR, Color(1, 1, 1, 0.6))
	## Sparkle — менший відблиск
	draw_circle(hl_pos + Vector2(_radius * 0.15, _radius * 0.1),
		_radius * 0.08, Color(1, 1, 1, 0.45))
	## LAW 25: Color-blind pattern overlay
	if not _cb_pattern.is_empty():
		IconDraw.draw_cb_pattern(self, Vector2.ZERO, _radius, _cb_pattern)


func pop() -> void:
	if _popped:
		return
	_popped = true
	set_process(false)
	popped.emit(self)
	AudioManager.play_sfx("click", randf_range(1.2, 1.5))
	HapticsManager.vibrate_light()
	VFXManager.spawn_bubble_pop(global_position, bubble_color)
	## Анімація зникнення
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.08)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.1)
	tw.finished.connect(queue_free)


func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _popped:
		return
	if event is InputEventMouseButton and event.pressed:
		pop()
	elif event is InputEventScreenTouch and event.pressed:
		pop()
