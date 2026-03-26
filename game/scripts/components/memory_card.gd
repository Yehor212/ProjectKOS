class_name MemoryCard
extends Node2D

## Компонент картки «Меморі» — текстурована поверхня, candy depth, flip-анімація.
## LAW 28 — Premium Visual Pipeline: multi-layer depth, specular, grain, glow.
## LAW 7 — Sprite Fallback: код-малювання якщо текстура відсутня.

const CARD_WIDTH: float = 160.0
const CARD_HEIGHT: float = 210.0
const SPRITE_SCALE: Vector2 = Vector2(0.26, 0.26)
const BACK_SPRITE_SCALE: Vector2 = Vector2(0.20, 0.20)
const FLIP_HALF_DUR: float = 0.15
const CORNER_RADIUS: int = 18
const SHADOW_SIZE: int = 10
const SHADOW_OFFSET: Vector2 = Vector2(3.0, 6.0)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.30)
const BORDER_WIDTH_PX: int = 3
const BACK_BG_COLOR: Color = Color("4393d6")
const BACK_BG_DARK: Color = Color("2d6ea8")
const FRONT_BG_COLOR: Color = Color("faf7f2")
const FRONT_BG_CREAM: Color = Color("f0ebe0")
const HIGHLIGHT_SCALE: Vector2 = Vector2(1.12, 1.12)
const HIGHLIGHT_BORDER: Color = Color("06d6a0")
const HIGHLIGHT_GLOW: Color = Color("06d6a0", 0.15)
const MATCHED_TINT: Color = Color(0.75, 1.0, 0.75, 0.9)
const MATCHED_SCALE: Vector2 = Vector2(0.92, 0.92)
const MATCHED_BORDER: Color = Color("4ade80")
## Анімація — bounce при flip
const FLIP_BOUNCE_SCALE: float = 1.06
const FLIP_BOUNCE_DUR: float = 0.08
## Idle breathing (reduced_motion = OFF)
const BREATH_SCALE_MIN: float = 0.985
const BREATH_SCALE_MAX: float = 1.015
const BREATH_DURATION: float = 3.0

var card_id: String = ""
var is_face_up: bool = false
var is_matched: bool = false
var is_flipping: bool = false
var is_highlighted: bool = false
var border_color: Color = Color.TRANSPARENT

var _front_sprite: Sprite2D = null
var _back_sprite: Sprite2D = null
var _card_color: Color = FRONT_BG_COLOR
var _breathing_tween: Tween = null


func setup(id: String, front_tex: Texture2D, back_tex: Texture2D,
		face_up: bool = false) -> void:
	card_id = id
	## Сорочка
	_back_sprite = Sprite2D.new()
	_back_sprite.texture = back_tex
	_back_sprite.scale = BACK_SPRITE_SCALE
	add_child(_back_sprite)
	## Лице тварини
	_front_sprite = Sprite2D.new()
	_front_sprite.texture = front_tex
	_front_sprite.scale = SPRITE_SCALE
	add_child(_front_sprite)
	## Toddler mode — картки відкриті одразу
	if face_up:
		_front_sprite.visible = true
		_back_sprite.visible = false
		_card_color = FRONT_BG_COLOR
		is_face_up = true
	else:
		_front_sprite.visible = false
		_back_sprite.visible = true
		_card_color = BACK_BG_COLOR
	## Premium grain material (LAW 28 — candy depth, gloss, inner shadow, rim)
	material = GameData.create_premium_material(
		0.04, 1.5, 0.06, 0.12, 0.10, 0.08, 0.12,
		"", 0.0, 0.15, 0.35, 0.3)
	queue_redraw()
	## Idle breathing — тільки для face-down карток (reduced_motion check)
	if not face_up and not SettingsManager.reduced_motion:
		_start_breathing()


func flip_up() -> Tween:
	is_flipping = true
	_stop_breathing()
	var tw: Tween = create_tween()
	## Фаза 1: стиснути до 0 по X
	tw.tween_property(self, "scale:x", 0.0, FLIP_HALF_DUR)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_back_sprite.visible = false
		_front_sprite.visible = true
		_card_color = FRONT_BG_COLOR
		queue_redraw()
	)
	## Фаза 2: розкрити з bounce overshoot
	if SettingsManager.reduced_motion:
		tw.tween_property(self, "scale:x", 1.0, FLIP_HALF_DUR)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(self, "scale:x", FLIP_BOUNCE_SCALE, FLIP_HALF_DUR)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale:x", 1.0, FLIP_BOUNCE_DUR)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		## Sparkle burst на моменті повного розкриття
		tw.tween_callback(func() -> void:
			VFXManager.spawn_match_sparkle(global_position)
		)
	tw.tween_callback(func() -> void:
		is_face_up = true
		is_flipping = false
	)
	return tw


func flip_down() -> Tween:
	is_flipping = true
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale:x", 0.0, FLIP_HALF_DUR)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_front_sprite.visible = false
		_back_sprite.visible = true
		_card_color = BACK_BG_COLOR
		queue_redraw()
	)
	tw.tween_property(self, "scale:x", 1.0, FLIP_HALF_DUR)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		is_face_up = false
		is_flipping = false
		## Відновити дихання для face-down
		if not SettingsManager.reduced_motion and not is_matched:
			_start_breathing()
	)
	return tw


func set_highlighted(on: bool) -> void:
	if is_highlighted == on:
		return
	is_highlighted = on
	if on:
		border_color = HIGHLIGHT_BORDER
		_stop_breathing()
		var tw: Tween = create_tween()
		tw.tween_property(self, "scale", HIGHLIGHT_SCALE, 0.15)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		border_color = Color.TRANSPARENT
		var tw: Tween = create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.12)
	queue_redraw()


func set_matched() -> void:
	is_matched = true
	is_highlighted = false
	border_color = MATCHED_BORDER
	_stop_breathing()
	queue_redraw()
	## Золоте свічення → shrink до matched scale
	var tw: Tween = create_tween()
	if not SettingsManager.reduced_motion:
		## Золотий glow flash
		tw.tween_property(self, "modulate", Color(1.2, 1.1, 0.8, 1.0), 0.15)
		tw.tween_property(self, "modulate", MATCHED_TINT, 0.25)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(self, "modulate", MATCHED_TINT, 0.3)
	tw.set_parallel(true)
	tw.tween_property(self, "scale", MATCHED_SCALE, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_add_checkmark)


func _add_checkmark() -> void:
	var check: Control = IconDraw.checkmark(36.0, Color("4ade80"))
	check.position = Vector2(-18.0, -CARD_HEIGHT * 0.5 + 7.0)
	check.modulate.a = 0.0
	add_child(check)
	var tw: Tween = create_tween()
	tw.tween_property(check, "modulate:a", 1.0, 0.2)
	if not SettingsManager.reduced_motion:
		tw.set_parallel(true)
		tw.tween_property(check, "scale", Vector2(1.3, 1.3), 0.1)
		tw.chain().tween_property(check, "scale", Vector2.ONE, 0.12)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func contains_point(world_pos: Vector2) -> bool:
	var local: Vector2 = world_pos - global_position
	return absf(local.x) <= CARD_WIDTH * 0.5 and absf(local.y) <= CARD_HEIGHT * 0.5


func _draw() -> void:
	var rect: Rect2 = Rect2(-CARD_WIDTH * 0.5, -CARD_HEIGHT * 0.5,
		CARD_WIDTH, CARD_HEIGHT)
	## Шар 1: Основна картка з candy depth
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = _card_color
	sb.set_corner_radius_all(CORNER_RADIUS)
	sb.anti_aliasing_size = 1.5
	## Volumetric candy depth — lit top, dark bottom lip
	sb.border_width_bottom = 4
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 0
	sb.border_color = _card_color.darkened(0.20)
	## Тінь
	sb.shadow_color = SHADOW_COLOR
	sb.shadow_size = SHADOW_SIZE
	sb.shadow_offset = SHADOW_OFFSET
	## Виділення — кольоровий бордер
	if border_color.a > 0.0:
		sb.border_color = border_color
		sb.set_border_width_all(BORDER_WIDTH_PX)
		## Glow ореол при highlight
		if is_highlighted:
			var glow_rect: Rect2 = rect.grow(4.0)
			var glow_sb: StyleBoxFlat = StyleBoxFlat.new()
			glow_sb.bg_color = HIGHLIGHT_GLOW
			glow_sb.set_corner_radius_all(CORNER_RADIUS + 4)
			glow_sb.anti_aliasing_size = 3.0
			draw_style_box(glow_sb, glow_rect)
	draw_style_box(sb, rect)
	## Шар 2: Внутрішня рамка (тонка лінія для глибини)
	var inner_rect: Rect2 = rect.grow(-6.0)
	var inner_sb: StyleBoxFlat = StyleBoxFlat.new()
	inner_sb.bg_color = Color.TRANSPARENT
	inner_sb.set_corner_radius_all(CORNER_RADIUS - 4)
	inner_sb.set_border_width_all(1)
	inner_sb.border_color = Color(1, 1, 1, 0.08) if is_face_up else Color(1, 1, 1, 0.12)
	draw_style_box(inner_sb, inner_rect)
	## Шар 3: Глянцевий блік — верхня частина (LAW 28 — premium specularity)
	var gloss_rect: Rect2 = Rect2(rect.position.x + 5.0, rect.position.y + 4.0,
		rect.size.x - 10.0, rect.size.y * 0.30)
	var gloss_sb: StyleBoxFlat = StyleBoxFlat.new()
	gloss_sb.bg_color = Color(1, 1, 1, 0.14)
	gloss_sb.corner_radius_top_left = CORNER_RADIUS - 3
	gloss_sb.corner_radius_top_right = CORNER_RADIUS - 3
	gloss_sb.corner_radius_bottom_left = 8
	gloss_sb.corner_radius_bottom_right = 8
	gloss_sb.anti_aliasing_size = 1.0
	draw_style_box(gloss_sb, gloss_rect)
	## Шар 4: Sparkle — відблиски зверху-зліва (2 точки для реалізму)
	draw_circle(Vector2(-CARD_WIDTH * 0.28, -CARD_HEIGHT * 0.32),
		maxf(CARD_WIDTH * 0.035, 2.0), Color(1, 1, 1, 0.50))
	draw_circle(Vector2(-CARD_WIDTH * 0.18, -CARD_HEIGHT * 0.28),
		maxf(CARD_WIDTH * 0.018, 1.0), Color(1, 1, 1, 0.35))
	## Шар 5: Додатковий декор для сорочки (face-down)
	if not is_face_up and not is_matched:
		## Декоративна ромбоподібна рамка — pattern на сорочці
		var pattern_rect: Rect2 = rect.grow(-14.0)
		var pattern_sb: StyleBoxFlat = StyleBoxFlat.new()
		pattern_sb.bg_color = Color.TRANSPARENT
		pattern_sb.set_corner_radius_all(CORNER_RADIUS - 6)
		pattern_sb.set_border_width_all(2)
		pattern_sb.border_color = Color(1, 1, 1, 0.15)
		draw_style_box(pattern_sb, pattern_rect)
		## Мікро-точки (candy dots pattern) — 4 точки в кутах
		var dot_offset: float = 24.0
		var dot_size: float = 3.0
		var dot_color: Color = Color(1, 1, 1, 0.18)
		draw_circle(Vector2(-CARD_WIDTH * 0.5 + dot_offset, -CARD_HEIGHT * 0.5 + dot_offset), dot_size, dot_color)
		draw_circle(Vector2(CARD_WIDTH * 0.5 - dot_offset, -CARD_HEIGHT * 0.5 + dot_offset), dot_size, dot_color)
		draw_circle(Vector2(-CARD_WIDTH * 0.5 + dot_offset, CARD_HEIGHT * 0.5 - dot_offset), dot_size, dot_color)
		draw_circle(Vector2(CARD_WIDTH * 0.5 - dot_offset, CARD_HEIGHT * 0.5 - dot_offset), dot_size, dot_color)
	## Шар 6: Subtle gradient overlay на лицевій стороні (ivory → cream)
	if is_face_up and not is_matched:
		var grad_rect: Rect2 = Rect2(rect.position.x + 3.0,
			rect.position.y + rect.size.y * 0.6,
			rect.size.x - 6.0, rect.size.y * 0.38)
		var grad_sb: StyleBoxFlat = StyleBoxFlat.new()
		grad_sb.bg_color = Color(0.0, 0.0, 0.0, 0.03)
		grad_sb.corner_radius_bottom_left = CORNER_RADIUS - 2
		grad_sb.corner_radius_bottom_right = CORNER_RADIUS - 2
		draw_style_box(grad_sb, grad_rect)


## ---- Idle breathing animation ----

func _start_breathing() -> void:
	if _breathing_tween and _breathing_tween.is_valid():
		return
	_breathing_tween = create_tween().set_loops()
	_breathing_tween.tween_property(self, "scale",
		Vector2(BREATH_SCALE_MAX, BREATH_SCALE_MAX), BREATH_DURATION * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breathing_tween.tween_property(self, "scale",
		Vector2(BREATH_SCALE_MIN, BREATH_SCALE_MIN), BREATH_DURATION * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_breathing() -> void:
	if _breathing_tween and _breathing_tween.is_valid():
		_breathing_tween.kill()
		_breathing_tween = null
