extends Node2D

## Слот (отвір) для фігури — напівпрозорий силует з підсвіткою при наближенні.

const HOLE_COLOR: Color = Color(0.15, 0.15, 0.15, 0.35)
const HIGHLIGHT_COLOR: Color = Color(1.0, 1.0, 0.5, 0.5)
const BORDER_COLOR: Color = Color(0.4, 0.4, 0.4, 0.6)
const BORDER_HIGHLIGHT: Color = Color(1.0, 1.0, 0.6, 0.8)
const BORDER_WIDTH: float = 2.5

var expected_id: String = ""
var slot_type: int = 0
var slot_size: float = 55.0
var is_filled: bool = false
var is_highlighted: bool = false
## Piaget: color+shape redundancy для toddler (2-4 роки).
## Коли задано — слот тонується кольором фігури, допомагаючи дитині
## matching по кольору (домінантний канал у 2-4 роки) паралельно з формою.
var hint_color: Color = Color.TRANSPARENT


func setup(id: String, type: int, sz: float, color_hint: Color = Color.TRANSPARENT) -> void:
	expected_id = id
	slot_type = type
	slot_size = sz
	hint_color = color_hint
	## Grain overlay (LAW 28)
	material = GameData.create_premium_material(0.05, 2.0, 0.0, 0.0, 0.04, 0.06, 0.06, "", 0.0, 0.08, 0.18, 0.15)
	queue_redraw()


func set_highlighted(on: bool) -> void:
	if is_highlighted == on:
		return
	is_highlighted = on
	queue_redraw()


func _draw() -> void:
	if is_filled:
		return
	var fill: Color
	var border: Color
	if hint_color.a > 0.01:
		## Piaget tinted slot — кольорова підказка для toddler
		fill = Color(hint_color.lightened(0.2), 0.5) if is_highlighted else Color(hint_color, 0.25)
		border = Color(hint_color.darkened(0.1), 0.8) if is_highlighted else Color(hint_color.darkened(0.2), 0.5)
	else:
		fill = HIGHLIGHT_COLOR if is_highlighted else HOLE_COLOR
		border = BORDER_HIGHLIGHT if is_highlighted else BORDER_COLOR
	## Внутрішня глибина: темніший зовнішній обідок + світліший центр
	var fill_inner: Color = Color(fill, minf(fill.a + 0.08, 0.8))
	var fill_inner_light: Color = Color(fill.lightened(0.15), minf(fill.a + 0.05, 0.6))
	match slot_type:
		0:  ## CIRCLE
			## Outer darker rim (inward shadow)
			draw_circle(Vector2.ZERO, slot_size, fill_inner)
			## Inner lighter center
			draw_circle(Vector2(0, -slot_size * 0.05), slot_size * 0.75, fill_inner_light)
			## Border
			draw_arc(Vector2.ZERO, slot_size, 0.0, TAU, 48, border, BORDER_WIDTH, true)
			## Inner edge shadow arc (top)
			draw_arc(Vector2.ZERO, slot_size - BORDER_WIDTH, PI * 0.8, PI * 1.2, 12,
				Color(0, 0, 0, 0.12), BORDER_WIDTH * 0.5, true)
		1:  ## SQUARE
			var r: Rect2 = Rect2(-slot_size, -slot_size,
				slot_size * 2.0, slot_size * 2.0)
			draw_rect(r, fill_inner)
			## Lighter inner rect
			draw_rect(Rect2(r.position.x + slot_size * 0.2, r.position.y + slot_size * 0.15,
				r.size.x - slot_size * 0.4, r.size.y - slot_size * 0.4), fill_inner_light)
			draw_rect(r, border, false, BORDER_WIDTH)
		2:  ## TRIANGLE
			var pts: PackedVector2Array = PackedVector2Array([
				Vector2(0, -slot_size),
				Vector2(-slot_size, slot_size),
				Vector2(slot_size, slot_size),
			])
			draw_colored_polygon(pts, fill_inner)
			## Lighter inner triangle (65%)
			var inner_pts: PackedVector2Array = PackedVector2Array()
			for pt: Vector2 in pts:
				inner_pts.append(pt * 0.65 + Vector2(0, slot_size * 0.05))
			draw_colored_polygon(inner_pts, fill_inner_light)
			draw_polyline(pts + PackedVector2Array([pts[0]]), border, BORDER_WIDTH, true)
		3:  ## RECTANGLE
			var r: Rect2 = Rect2(-slot_size * 0.6, -slot_size,
				slot_size * 1.2, slot_size * 2.0)
			draw_rect(r, fill_inner)
			draw_rect(Rect2(r.position.x + slot_size * 0.15, r.position.y + slot_size * 0.12,
				r.size.x - slot_size * 0.3, r.size.y - slot_size * 0.3), fill_inner_light)
			draw_rect(r, border, false, BORDER_WIDTH)
