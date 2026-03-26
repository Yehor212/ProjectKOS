class_name SplashTrack
extends Control
## Доріжка завантаження — округлений candy progress bar, маскот, зірки, бульбашка.

## Масив спрайтів тварин для рандомного вибору при кожному запуску
const ANIMAL_SPRITES: Array[String] = [
	"res://assets/sprites/animals/Bear.png",
	"res://assets/sprites/animals/Bunny.png",
	"res://assets/sprites/animals/Cat.png",
	"res://assets/sprites/animals/Chicken.png",
	"res://assets/sprites/animals/Cow.png",
	"res://assets/sprites/animals/Crocodile.png",
	"res://assets/sprites/animals/Deer.png",
	"res://assets/sprites/animals/Dog.png",
	"res://assets/sprites/animals/Elephant.png",
	"res://assets/sprites/animals/Frog.png",
	"res://assets/sprites/animals/Goat.png",
	"res://assets/sprites/animals/Hedgehog.png",
	"res://assets/sprites/animals/Horse.png",
	"res://assets/sprites/animals/Lion.png",
	"res://assets/sprites/animals/Monkey.png",
	"res://assets/sprites/animals/Mouse.png",
	"res://assets/sprites/animals/Panda.png",
	"res://assets/sprites/animals/Penguin.png",
	"res://assets/sprites/animals/Squirrel.png",
]

const TRACK_Y: float = 100.0
const MARGIN: float = 30.0
const BAR_HEIGHT: float = 28.0
const BAR_RADIUS: float = 14.0
const FILL_COL: Color = Color("ff9f1c")
const FILL_COL_LIGHT: Color = Color("ffbf5e")
const TRACK_BG: Color = Color(0, 0, 0, 0.12)
const TRACK_BORDER: Color = Color(0, 0, 0, 0.06)
const STAR_POS: Array[float] = [0.33, 0.66, 0.95]
const STAR_RAD: float = 18.0
const MASCOT_SZ: Vector2 = Vector2(100, 100)
const BOUNCE_DUR: float = 0.8
const SHINE_SPEED: float = 1.5

var _progress: float = 0.0
var _mascot_tex: Texture2D = null
var _mascot_pos: Vector2 = Vector2.ZERO
var _mascot_scale: Vector2 = Vector2.ONE
var _mascot_rot: float = 0.0
var _bounce_tw: Tween = null
var _collected: Array[bool] = [false, false, false]
var _is_done: bool = false
var _bubble_text: String = "0%"
var _bubble_col: Color = Color.WHITE
var _mascot_base_y: float = 0.0
var _finish_scale: float = 1.0
var _finish_rot: float = 0.0


func _ready() -> void:
	## Grain overlay (LAW 28 — premium texture)
	material = GameData.create_premium_material(0.03, 2.0, 0.0, 0.0, 0.0, 0.0, 0.15, "", 0.0, 0.08, 0.18, 0.15)
	var path: String = ANIMAL_SPRITES[randi() % ANIMAL_SPRITES.size()]
	_mascot_tex = load(path)
	if not _mascot_tex:
		push_warning("SplashTrack: спрайт тварини не знайдено — %s" % path)
		return
	_mascot_base_y = TRACK_Y - MASCOT_SZ.y - 5.0
	_mascot_pos = Vector2(MARGIN - MASCOT_SZ.x / 2.0, _mascot_base_y)
	_start_bounce()


func _start_bounce() -> void:
	if _bounce_tw and _bounce_tw.is_valid():
		_bounce_tw.kill()
	if not _mascot_tex:
		return
	var dur: float = BOUNCE_DUR * (0.5 if _is_done else 1.0)
	_bounce_tw = create_tween().set_loops()
	_bounce_tw.tween_property(self, "_mascot_scale", Vector2(1.05, 0.9), dur / 2.0)
	_bounce_tw.parallel().tween_property(self, "_mascot_rot", -5.0, dur / 2.0)
	_bounce_tw.parallel().tween_property(self, "_mascot_pos:y", _mascot_base_y - 25.0, dur / 2.0)
	_bounce_tw.tween_property(self, "_mascot_scale", Vector2(0.95, 1.05), dur / 2.0)
	_bounce_tw.parallel().tween_property(self, "_mascot_rot", 5.0, dur / 2.0)
	_bounce_tw.parallel().tween_property(self, "_mascot_pos:y", _mascot_base_y, dur / 2.0)


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_bubble_text = "%d%%" % int(_progress * 100.0)
	if _mascot_tex:
		_mascot_pos.x = lerpf(MARGIN, size.x - MARGIN, _progress) - MASCOT_SZ.x / 2.0
	for i: int in STAR_POS.size():
		if not _collected[i] and _progress >= STAR_POS[i]:
			_collected[i] = true
			AudioManager.play_sfx("coin")
	queue_redraw()


func set_done() -> void:
	_is_done = true
	_bubble_text = tr("SPLASH_LETS_GO")
	_bubble_col = Color("06d6a0")
	_start_bounce()
	var pulse: Tween = create_tween().set_loops()
	var cb: Callable = func(t: float) -> void:
		_finish_scale = lerpf(1.0, 1.15, t)
		_finish_rot = lerpf(-10.0, 10.0, t)
		queue_redraw()
	pulse.tween_method(cb, 0.0, 1.0, 0.75)
	pulse.tween_method(cb, 1.0, 0.0, 0.75)


func _draw() -> void:
	var l_x: float = MARGIN
	var r_x: float = size.x - MARGIN
	var bar_y: float = TRACK_Y - BAR_HEIGHT * 0.5
	var bar_w: float = r_x - l_x
	## Фон треку — округлений прямокутник з тінню
	_draw_rounded_rect(Vector2(l_x, bar_y + 2.0), Vector2(bar_w, BAR_HEIGHT),
		BAR_RADIUS, Color(0, 0, 0, 0.08))
	_draw_rounded_rect(Vector2(l_x, bar_y), Vector2(bar_w, BAR_HEIGHT),
		BAR_RADIUS, TRACK_BG)
	## Рамка
	_draw_rounded_border(Vector2(l_x, bar_y), Vector2(bar_w, BAR_HEIGHT),
		BAR_RADIUS, TRACK_BORDER, 1.5)
	## Заповнення — округлений прямокутник
	if _progress > 0.01:
		var fill_w: float = bar_w * _progress
		## Основне заповнення
		_draw_rounded_rect(Vector2(l_x, bar_y), Vector2(fill_w, BAR_HEIGHT),
			BAR_RADIUS, FILL_COL)
		## Верхній блік — світліша смуга зверху
		if fill_w > BAR_RADIUS * 2.0:
			_draw_rounded_rect(Vector2(l_x + 2.0, bar_y + 2.0),
				Vector2(fill_w - 4.0, BAR_HEIGHT * 0.4),
				BAR_RADIUS - 2.0, FILL_COL_LIGHT)
		## Анімований блік (shine sweep)
		var shine_t: float = fmod(Time.get_ticks_msec() / 1000.0 * SHINE_SPEED, 1.0)
		var shine_x: float = l_x + fill_w * shine_t
		var shine_w: float = minf(40.0, fill_w * 0.3)
		if shine_x + shine_w <= l_x + fill_w:
			_draw_rounded_rect(Vector2(shine_x, bar_y + 3.0),
				Vector2(shine_w, BAR_HEIGHT - 6.0),
				(BAR_HEIGHT - 6.0) * 0.5, Color(1, 1, 1, 0.25))
	## Маскот — малюється ДО зірок
	if _mascot_tex:
		var mc: Vector2 = _mascot_pos + MASCOT_SZ / 2.0
		draw_set_transform(mc, deg_to_rad(_mascot_rot), _mascot_scale)
		draw_texture_rect(_mascot_tex, Rect2(-MASCOT_SZ / 2.0, MASCOT_SZ), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	## Зірки
	for i: int in STAR_POS.size():
		var sx: float = lerpf(l_x, r_x, STAR_POS[i])
		if _collected[i]:
			_draw_star_collected(Vector2(sx, TRACK_Y), STAR_RAD)
		else:
			_draw_star(Vector2(sx, TRACK_Y), STAR_RAD, FILL_COL)
	## Фінальна зірка
	if _is_done:
		draw_set_transform(Vector2(r_x, TRACK_Y),
			deg_to_rad(_finish_rot), Vector2(_finish_scale, _finish_scale))
		_draw_star(Vector2.ZERO, STAR_RAD * 1.8, Color("ffd166"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_star(Vector2(r_x, TRACK_Y), STAR_RAD * 1.8, Color("ffd166"))
	## Бульбашка
	_draw_bubble(Vector2(lerpf(l_x, r_x, _progress), TRACK_Y - MASCOT_SZ.y - 30.0))


func _draw_rounded_rect(pos: Vector2, sz: Vector2, radius: float, color: Color) -> void:
	var r: float = minf(radius, minf(sz.x, sz.y) * 0.5)
	if r < 1.0:
		draw_rect(Rect2(pos, sz), color)
		return
	## Центральний прямокутник
	draw_rect(Rect2(pos.x + r, pos.y, sz.x - r * 2.0, sz.y), color)
	## Лівий прямокутник
	draw_rect(Rect2(pos.x, pos.y + r, r, sz.y - r * 2.0), color)
	## Правий прямокутник
	draw_rect(Rect2(pos.x + sz.x - r, pos.y + r, r, sz.y - r * 2.0), color)
	## 4 кути — півкола
	draw_circle(Vector2(pos.x + r, pos.y + r), r, color)
	draw_circle(Vector2(pos.x + sz.x - r, pos.y + r), r, color)
	draw_circle(Vector2(pos.x + r, pos.y + sz.y - r), r, color)
	draw_circle(Vector2(pos.x + sz.x - r, pos.y + sz.y - r), r, color)


func _draw_rounded_border(pos: Vector2, sz: Vector2, radius: float,
		color: Color, width: float) -> void:
	var r: float = minf(radius, minf(sz.x, sz.y) * 0.5)
	## Верхня/нижня лінії
	draw_line(Vector2(pos.x + r, pos.y), Vector2(pos.x + sz.x - r, pos.y),
		color, width)
	draw_line(Vector2(pos.x + r, pos.y + sz.y), Vector2(pos.x + sz.x - r, pos.y + sz.y),
		color, width)
	## Ліва/права лінії
	draw_line(Vector2(pos.x, pos.y + r), Vector2(pos.x, pos.y + sz.y - r),
		color, width)
	draw_line(Vector2(pos.x + sz.x, pos.y + r), Vector2(pos.x + sz.x, pos.y + sz.y - r),
		color, width)
	## 4 дуги
	draw_arc(Vector2(pos.x + r, pos.y + r), r, PI, PI * 1.5, 12, color, width, true)
	draw_arc(Vector2(pos.x + sz.x - r, pos.y + r), r, PI * 1.5, TAU, 12, color, width, true)
	draw_arc(Vector2(pos.x + r, pos.y + sz.y - r), r, PI * 0.5, PI, 12, color, width, true)
	draw_arc(Vector2(pos.x + sz.x - r, pos.y + sz.y - r), r, 0, PI * 0.5, 12, color, width, true)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	## Тінь
	_draw_star_shape(center + Vector2(1.5, 2.5), radius, Color(0, 0, 0, 0.15))
	## Основна зірка
	_draw_star_shape(center, radius, color)
	## Верхній блік
	_draw_star_shape(center + Vector2(0, -radius * 0.1), radius * 0.55,
		Color(1, 1, 1, 0.3))


func _draw_star_collected(center: Vector2, radius: float) -> void:
	## Зібрана зірка — золота з відблиском і premium depth
	_draw_star_shape(center + Vector2(1.5, 2.5), radius, Color(0, 0, 0, 0.15))
	_draw_star_shape(center, radius, Color("e6b800"))
	_draw_star_shape(center, radius * 0.92, Color("ffd166"))
	_draw_star_shape(center + Vector2(0, -radius * 0.15), radius * 0.5,
		Color(1, 1, 1, 0.45))
	## Sparkle
	draw_circle(center + Vector2(-radius * 0.25, -radius * 0.3),
		maxf(radius * 0.12, 1.5), Color(1, 1, 1, 0.6))


func _draw_star_shape(center: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var angle: float = -PI / 2.0 + float(i) * TAU / 10.0
		var rad: float = radius if i % 2 == 0 else radius * 0.42
		pts.append(center + Vector2(cos(angle), sin(angle)) * rad)
	draw_colored_polygon(pts, color)


func _draw_bubble(pos: Vector2) -> void:
	var w: float = 90.0 if not _is_done else 130.0
	var h: float = 36.0
	var cr: float = h / 2.0
	var ry: float = pos.y - h
	## Тінь бульбашки
	_draw_rounded_rect(Vector2(pos.x - w / 2.0, ry + 2.0), Vector2(w, h),
		cr, Color(0, 0, 0, 0.1))
	## Основна бульбашка
	_draw_rounded_rect(Vector2(pos.x - w / 2.0, ry), Vector2(w, h), cr, _bubble_col)
	## Хвостик
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - 7.0, pos.y - 2.0),
		Vector2(pos.x + 7.0, pos.y - 2.0),
		Vector2(pos.x, pos.y + 8.0)
	]), _bubble_col)
	## Верхній блік
	_draw_rounded_rect(Vector2(pos.x - w / 2.0 + 4.0, ry + 3.0),
		Vector2(w - 8.0, h * 0.35), cr - 3.0, Color(1, 1, 1, 0.2))
	## Текст
	var font: Font = get_theme_default_font()
	var tc: Color = Color.WHITE if _is_done else FILL_COL
	draw_string(font, Vector2(pos.x - w / 2.0 + 4.0, pos.y - 11.0),
		_bubble_text, HORIZONTAL_ALIGNMENT_CENTER, int(w) - 8, 18, tc)
