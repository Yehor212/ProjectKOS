extends Node2D

## Floating cloud collectible — drifts across screen, awards 1 coin on tap.

var _speed: float = 0.0


func _ready() -> void:
	_speed = randf_range(60.0, 80.0)
	z_index = -1
	var area: Area2D = Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 40.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.input_event.connect(_on_area_input_event)
	material = GameData.create_premium_material(0.04, 3.0, 0.0, 0.0, 0.0, 0.04, 0.10, "", 0.0, 0.08, 0.18, 0.15)


func _draw() -> void:
	var sh: Vector2 = Vector2(2, 2)
	var shadow_c: Color = Color(0, 0, 0, 0.06)
	## Shadow circles
	draw_circle(Vector2(-20, 0) + sh, 28.0, shadow_c)
	draw_circle(Vector2(10, -8) + sh, 24.0, shadow_c)
	draw_circle(Vector2(20, 5) + sh, 20.0, shadow_c)
	## Dark base
	var col: Color = Color(1, 1, 1, 0.55)
	draw_circle(Vector2(-20, 0), 28.0, col)
	draw_circle(Vector2(10, -8), 24.0, col)
	draw_circle(Vector2(20, 5), 20.0, col)
	## Light highlights (smaller, brighter)
	var hl: Color = Color(1, 1, 1, 0.75)
	draw_circle(Vector2(-24, -6), 14.0, hl)
	draw_circle(Vector2(6, -14), 12.0, hl)
	draw_circle(Vector2(16, 0), 10.0, hl)
	## Sparkle — LAW 28
	draw_circle(Vector2(-26, -10), 2.5, Color(1, 1, 1, 0.9))


func _process(delta: float) -> void:
	position.x += _speed * delta
	if position.x > 1400:
		queue_free()


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_collect()
	elif event is InputEventScreenTouch and event.pressed:
		_collect()


func _collect() -> void:
	set_process(false)
	ProgressManager.add_stars(1)
	AudioManager.play_sfx("coin")
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.finished.connect(queue_free)
