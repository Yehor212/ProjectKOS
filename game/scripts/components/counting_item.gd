extends Node2D

## Перетягуваний фрукт для лічби — candy circle з тінню, градієнтом і бліком.

const BORDER_WIDTH: float = 3.0
const SHADOW_OFFSET: Vector2 = Vector2(2.0, 4.0)
const SHADOW_COLOR: Color = Color(0, 0, 0, 0.18)
const GLOSS_ALPHA: float = 0.35

var fruit_type: String = ""
var fruit_color: Color = Color.WHITE
var origin_pos: Vector2 = Vector2.ZERO
var item_radius: float = 45.0

var _emoji_label: Label = null


func setup(type: String, emoji: String, color: Color, radius: float) -> void:
	fruit_type = type
	fruit_color = color
	item_radius = radius
	_emoji_label = Label.new()
	_emoji_label.text = emoji
	_emoji_label.add_theme_font_size_override("font_size", int(radius * 1.2))
	_emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_emoji_label.position = Vector2(-radius, -radius)
	_emoji_label.size = Vector2(radius * 2.0, radius * 2.0)
	_emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_emoji_label)
	material = GameData.create_premium_material(
		0.07, 2.0, 0.0, 0.0, 0.04, 0.06, 0.06, "", 0.0, 0.10, 0.22, 0.18)
	queue_redraw()


## Альтернативний setup з іконкою Control замість емоджі-рядка
func setup_with_icon(type: String, icon: Control, color: Color, radius: float) -> void:
	fruit_type = type
	fruit_color = color
	item_radius = radius
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(-radius * 0.5, -radius * 0.5)
	add_child(icon)
	material = GameData.create_premium_material(
		0.07, 2.0, 0.0, 0.0, 0.04, 0.06, 0.06, "", 0.0, 0.10, 0.22, 0.18)
	queue_redraw()


func _draw() -> void:
	## Palette
	var dark: Color = fruit_color.darkened(0.20)
	var darker: Color = fruit_color.darkened(0.35)
	var light: Color = fruit_color.lightened(0.15)
	## Тінь
	draw_circle(SHADOW_OFFSET, item_radius + 1.0, SHADOW_COLOR)
	## Dark base коло
	draw_circle(Vector2.ZERO, item_radius, dark)
	## Light upper half
	draw_circle(Vector2(-item_radius * 0.1, -item_radius * 0.15),
		item_radius * 0.7, light)
	## Градієнтна нижня частина — ще темніша
	var segs: int = 24
	var bottom_pts: PackedVector2Array = PackedVector2Array()
	bottom_pts.append(Vector2(-item_radius, 0.0))
	for i: int in range(segs + 1):
		var angle: float = float(i) / float(segs) * PI
		bottom_pts.append(Vector2(cos(angle), sin(angle)) * item_radius)
	draw_colored_polygon(bottom_pts, darker)
	## Обводка
	draw_arc(Vector2.ZERO, item_radius, 0.0, TAU, 48, darker, BORDER_WIDTH, true)
	## Верхній глянцевий блік — овальна форма
	var gloss_r: float = item_radius * 0.65
	var gloss_y: float = -item_radius * 0.3
	var gloss_pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(segs + 1):
		var angle: float = float(i) / float(segs) * PI + PI
		gloss_pts.append(Vector2(cos(angle) * gloss_r, gloss_y + sin(angle) * gloss_r * 0.4))
	draw_colored_polygon(gloss_pts, Color(1, 1, 1, GLOSS_ALPHA))
	## Маленький круглий відблиск
	draw_circle(Vector2(-item_radius * 0.28, -item_radius * 0.32),
		item_radius * 0.12, Color(1, 1, 1, 0.5))
	## Sparkle
	draw_circle(Vector2(-item_radius * 0.15, -item_radius * 0.42),
		maxf(item_radius * 0.06, 1.5), Color(1, 1, 1, 0.55))
