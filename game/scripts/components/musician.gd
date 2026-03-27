extends Node2D

## Музикант — тварина на кольоровій платформі, грає звук при тапі.
## Area2D + input_event для multitouch. Squash-stretch анімація.

signal played(musician_instance: Node2D)

const PLATFORM_RADIUS: float = 70.0
const SPRITE_SCALE: Vector2 = Vector2(0.35, 0.35)
const SQUASH_SCALE: Vector2 = Vector2(1.3, 0.7)
const STRETCH_SCALE: Vector2 = Vector2(0.85, 1.15)

var musician_id: int = 0
var instrument_color: Color = Color.WHITE
var sfx_name: String = "click"
var sfx_pitch: float = 1.0
var _is_playing: bool = false
var _sprite: Sprite2D = null


func setup(id: int, animal_name: String, color: Color,
		sound_name: String, pitch: float, label_text: String) -> void:
	musician_id = id
	instrument_color = color
	sfx_name = sound_name
	sfx_pitch = maxf(pitch, 0.1)  ## LAW 13: guard pitch > 0
	material = GameData.create_premium_material(0.06, 2.0, 0.0, 0.0, 0.04, 0.06, 0.06, "", 0.0, 0.08, 0.18, 0.15)
	queue_redraw()
	## Спрайт тварини
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if not ResourceLoader.exists(tex_path):
		push_warning("Musician: спрайт '%s' не знайдено" % tex_path)
	else:
		var tex: Texture2D = load(tex_path)
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.scale = SPRITE_SCALE
		_sprite.position.y = -20.0
		add_child(_sprite)
	## Area2D для тапу
	var area: Area2D = Area2D.new()
	area.input_pickable = true
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = PLATFORM_RADIUS
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.input_event.connect(_on_area_input)
	## Іконка інструменту (IconDraw замість emoji)
	var icon_ctrl: Control = _instrument_icon(label_text, 28.0)
	icon_ctrl.position = Vector2(-14, PLATFORM_RADIUS + 5)
	icon_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_ctrl)


static func _instrument_icon(id: String, size: float) -> Control:
	match id:
		"drum": return IconDraw.drum(size)
		"guitar": return IconDraw.guitar(size)
		"trumpet": return IconDraw.trumpet(size)
		"microphone": return IconDraw.microphone(size)
		_:
			push_warning("Musician: невідомий instrument icon id: " + id)
			return IconDraw.drum(size)


func _draw() -> void:
	## Тінь платформи
	draw_circle(Vector2(2, 3), PLATFORM_RADIUS + 1.0, Color(0, 0, 0, 0.10))
	## Кольорова платформа-коло — darker outer ring
	draw_circle(Vector2.ZERO, PLATFORM_RADIUS, Color(instrument_color.darkened(0.15), 0.35))
	## Lighter inner circle
	draw_circle(Vector2(0, -PLATFORM_RADIUS * 0.05), PLATFORM_RADIUS * 0.75,
		Color(instrument_color.lightened(0.10), 0.25))
	## Border
	draw_arc(Vector2.ZERO, PLATFORM_RADIUS, 0.0, TAU, 48,
		Color(instrument_color, 0.6), 3.0, true)
	## Sparkle
	draw_circle(Vector2(-PLATFORM_RADIUS * 0.3, -PLATFORM_RADIUS * 0.35),
		maxf(PLATFORM_RADIUS * 0.06, 1.5), Color(1, 1, 1, 0.45))


func play_sound() -> void:
	if _is_playing:
		return
	_is_playing = true
	played.emit(self)
	AudioManager.play_sfx(sfx_name, sfx_pitch)
	HapticsManager.vibrate_light()
	VFXManager.spawn_note_particles(
		global_position + Vector2(0, -40), instrument_color)
	## Squash-stretch анімація
	if _sprite:
		var tw: Tween = create_tween()
		tw.tween_property(_sprite, "scale", SQUASH_SCALE * SPRITE_SCALE, 0.06)
		tw.tween_property(_sprite, "scale", STRETCH_SCALE * SPRITE_SCALE, 0.08)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sprite, "scale", SPRITE_SCALE, 0.15)
		tw.finished.connect(func() -> void: _is_playing = false)
	else:
		_is_playing = false


## Підсвітка для Simon Says (preschool) — грає звук + яскравість
func highlight(duration: float = 0.5) -> void:
	play_sound()
	modulate = Color(1.5, 1.5, 1.5)
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, duration * 0.4)\
		.set_delay(duration * 0.6)


func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _is_playing:
		return
	if event is InputEventMouseButton and event.pressed:
		play_sound()
	elif event is InputEventScreenTouch and event.pressed:
		play_sound()
