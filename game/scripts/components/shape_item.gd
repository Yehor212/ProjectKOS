extends Node2D

## Перетягувана геометрична фігура — програмна графіка через _draw().

enum ShapeType { CIRCLE = 0, SQUARE = 1, TRIANGLE = 2, RECTANGLE = 3 }

const BORDER_WIDTH: float = 3.0

var shape_id: String = ""
var shape_type: int = ShapeType.CIRCLE
var shape_color: Color = Color.RED
var shape_size: float = 50.0
var origin_pos: Vector2 = Vector2.ZERO


func setup(id: String, type: int, color: Color, sz: float) -> void:
	shape_id = id
	shape_type = type
	shape_color = color
	shape_size = sz
	material = GameData.create_premium_material(0.06, 2.0, 0.0, 0.0, 0.04, 0.06, 0.06, "", 0.0, 0.08, 0.18, 0.15)
	queue_redraw()


func _draw() -> void:
	var dark: Color = shape_color.darkened(0.20)
	var darker: Color = shape_color.darkened(0.35)
	var light: Color = shape_color.lightened(0.15)
	var sh: Vector2 = Vector2(2.0, 3.0)
	var shadow_c: Color = Color(0, 0, 0, 0.18)
	match shape_type:
		ShapeType.CIRCLE:
			## Shadow
			draw_circle(sh, shape_size + 1.0, shadow_c)
			## Dark base
			draw_circle(Vector2.ZERO, shape_size, dark)
			## Light upper glare
			draw_circle(Vector2(-shape_size * 0.15, -shape_size * 0.2),
				shape_size * 0.65, light)
			## Border
			draw_arc(Vector2.ZERO, shape_size, 0.0, TAU, 48, darker, BORDER_WIDTH, true)
		ShapeType.SQUARE:
			var r: Rect2 = Rect2(-shape_size, -shape_size,
				shape_size * 2.0, shape_size * 2.0)
			## Shadow
			draw_rect(Rect2(r.position + sh, r.size), shadow_c)
			## Dark base
			draw_rect(r, dark)
			## Light top half
			draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0,
				r.size.x - 2.0, r.size.y * 0.45), light)
			## Border
			draw_rect(r, darker, false, BORDER_WIDTH)
		ShapeType.TRIANGLE:
			var pts: PackedVector2Array = _triangle_points(shape_size)
			## Shadow
			var shadow_pts: PackedVector2Array = PackedVector2Array()
			for pt: Vector2 in pts:
				shadow_pts.append(pt + sh)
			draw_colored_polygon(shadow_pts, shadow_c)
			## Dark base
			draw_colored_polygon(pts, dark)
			## Light inner triangle (60%)
			var inner_pts: PackedVector2Array = PackedVector2Array()
			for pt: Vector2 in pts:
				inner_pts.append(pt * 0.6 + Vector2(0, -shape_size * 0.08))
			draw_colored_polygon(inner_pts, light)
			## Border
			draw_polyline(pts + PackedVector2Array([pts[0]]), darker, BORDER_WIDTH, true)
		ShapeType.RECTANGLE:
			var r: Rect2 = Rect2(-shape_size * 0.6, -shape_size,
				shape_size * 1.2, shape_size * 2.0)
			## Shadow
			draw_rect(Rect2(r.position + sh, r.size), shadow_c)
			## Dark base
			draw_rect(r, dark)
			## Light top half
			draw_rect(Rect2(r.position.x + 1.0, r.position.y + 1.0,
				r.size.x - 2.0, r.size.y * 0.4), light)
			## Border
			draw_rect(r, darker, false, BORDER_WIDTH)
	## Глянцевий відблиск
	draw_circle(Vector2(-shape_size * 0.3, -shape_size * 0.3),
		shape_size * 0.15, Color(1, 1, 1, 0.4))
	## Sparkle
	draw_circle(Vector2(-shape_size * 0.15, -shape_size * 0.4),
		maxf(shape_size * 0.06, 1.5), Color(1, 1, 1, 0.55))


static func _triangle_points(sz: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -sz),
		Vector2(-sz, sz),
		Vector2(sz, sz),
	])
