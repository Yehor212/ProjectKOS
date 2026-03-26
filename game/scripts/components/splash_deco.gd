class_name SplashDeco
extends Control

## Декоративна SVG-подібна фігура для сплеш-скріну.
## Малюється через _draw() без зовнішніх текстур.

enum Shape { GAMEPAD, PLANET, LOLLIPOP_A, LOLLIPOP_B }

@export var shape_type: Shape = Shape.GAMEPAD

const COL_YELLOW: Color = Color("ffd166")
const COL_GREEN: Color = Color("06d6a0")
const COL_PINK: Color = Color("ffb5a7")
const COL_LAVENDER: Color = Color("ffcbf2")
const COL_DARK: Color = Color("333333")
const DASH_COUNT: int = 10


func _ready() -> void:
	pivot_offset = size / 2.0
	## Grain overlay (LAW 28 — premium texture)
	material = GameData.create_premium_material(0.04, 2.0, 0.0, 0.0, 0.0, 0.0, 0.15, "", 0.0, 0.08, 0.18, 0.15)


func _draw() -> void:
	match shape_type:
		Shape.GAMEPAD:
			_draw_gamepad()
		Shape.PLANET:
			_draw_planet()
		Shape.LOLLIPOP_A:
			_draw_lollipop(COL_PINK, COL_LAVENDER)
		Shape.LOLLIPOP_B:
			_draw_lollipop(COL_LAVENDER, COL_PINK)


func _draw_gamepad() -> void:
	var body_rect: Rect2 = Rect2(0.0, size.y * 0.2, size.x, size.y * 0.6)
	## Shadow body
	var sb_sh: StyleBoxFlat = StyleBoxFlat.new()
	sb_sh.bg_color = Color(0, 0, 0, 0.12)
	sb_sh.set_corner_radius_all(int(size.y * 0.4))
	draw_style_box(sb_sh, Rect2(body_rect.position + Vector2(2, 3), body_rect.size))
	## Dark base body
	var sb_dark: StyleBoxFlat = StyleBoxFlat.new()
	sb_dark.bg_color = COL_YELLOW.darkened(0.15)
	sb_dark.set_corner_radius_all(int(size.y * 0.4))
	draw_style_box(sb_dark, body_rect)
	## Light highlight (top half)
	var sb_light: StyleBoxFlat = StyleBoxFlat.new()
	sb_light.bg_color = COL_YELLOW.lightened(0.12)
	sb_light.set_corner_radius_all(int(size.y * 0.35))
	draw_style_box(sb_light, Rect2(body_rect.position.x + 2.0, body_rect.position.y + 2.0,
		body_rect.size.x - 4.0, body_rect.size.y * 0.45))
	## Темні кнопки з глибиною
	var cy: float = size.y * 0.5
	draw_circle(Vector2(size.x * 0.3, cy), size.x * 0.07 + 1.0, Color(0, 0, 0, 0.3))
	draw_circle(Vector2(size.x * 0.3, cy), size.x * 0.07, COL_DARK)
	draw_circle(Vector2(size.x * 0.7, cy - 3.0), size.x * 0.05, COL_DARK)
	draw_circle(Vector2(size.x * 0.82, cy + 3.0), size.x * 0.05, COL_DARK)
	## Sparkle
	draw_circle(Vector2(size.x * 0.15, size.y * 0.28), 2.0, Color(1, 1, 1, 0.45))


func _draw_planet() -> void:
	var cx: float = size.x / 2.0
	var cy: float = size.y / 2.0
	var r: float = minf(size.x, size.y) * 0.38
	## Shadow
	draw_circle(Vector2(cx + 2, cy + 2), r + 1.0, Color(0, 0, 0, 0.10))
	## Dark base planet
	draw_circle(Vector2(cx, cy), r, COL_GREEN.darkened(0.15))
	## Light glare (upper-left)
	draw_circle(Vector2(cx - r * 0.2, cy - r * 0.2), r * 0.6, COL_GREEN.lightened(0.12))
	## Жовте кільце — нахилений еліпс (rotate -20°)
	var pts: PackedVector2Array = PackedVector2Array()
	var ring_rx: float = r * 1.5
	var ring_ry: float = r * 0.33
	var tilt: float = deg_to_rad(-20.0)
	for i: int in 33:
		var a: float = float(i) * TAU / 32.0
		var px: float = cos(a) * ring_rx
		var py: float = sin(a) * ring_ry
		pts.append(Vector2(cx + px * cos(tilt) - py * sin(tilt),
			cy + px * sin(tilt) + py * cos(tilt)))
	## Shadow ring
	var shadow_ring: PackedVector2Array = PackedVector2Array()
	for pt: Vector2 in pts:
		shadow_ring.append(pt + Vector2(1.5, 1.5))
	draw_polyline(shadow_ring, Color(0, 0, 0, 0.12), 4.0, true)
	## Main ring
	draw_polyline(pts, COL_YELLOW, 3.0, true)
	## Sparkle
	draw_circle(Vector2(cx - r * 0.3, cy - r * 0.35), 2.0, Color(1, 1, 1, 0.50))


func _draw_lollipop(body_col: Color, dash_col: Color) -> void:
	var cx: float = size.x / 2.0
	var r: float = minf(size.x, size.y) * 0.33
	var center_y: float = r + 2.0
	var center: Vector2 = Vector2(cx, center_y)
	## Stick shadow
	draw_line(Vector2(cx + 1.5, center_y + r * 0.5 + 2.0), Vector2(cx * 0.7 + 1.5, size.y + 2.0),
		Color(0, 0, 0, 0.10), 5.0, true)
	## Біла паличка
	draw_line(Vector2(cx, center_y + r * 0.5), Vector2(cx * 0.7, size.y),
		Color.WHITE, 4.0, true)
	## Shadow circle
	draw_circle(center + Vector2(2, 2), r + 1.0, Color(0, 0, 0, 0.10))
	## Dark base circle
	draw_circle(center, r, body_col.darkened(0.12))
	## Light upper glare
	draw_circle(center + Vector2(-r * 0.15, -r * 0.2), r * 0.55,
		body_col.lightened(0.15))
	## Пунктирна спіраль (дешеві дуги)
	var inner_r: float = r * 0.6
	var dash_a: float = TAU / float(DASH_COUNT * 2)
	for i: int in DASH_COUNT:
		var start: float = float(i) * dash_a * 2.0
		draw_arc(center, inner_r, start, start + dash_a,
			8, dash_col, 3.0, true)
	## Sparkle
	draw_circle(center + Vector2(-r * 0.3, -r * 0.35), 2.0, Color(1, 1, 1, 0.50))
