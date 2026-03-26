## Централізований утиліт для код-малюваних UI іконок.
## Кожен метод повертає Control з draw-сигналом — чисті вектори, без PNG/емоджі.
## Використання: var icon := IconDraw.play_triangle(24.0)
class_name IconDraw


## ---- Helpers ----


## Обгортає іконку в CenterContainer всередині кнопки.
## Вся ієрархія має MOUSE_FILTER_IGNORE щоб не красти кліки.
static func icon_in_button(btn: Button, icon: Control) -> void:
	btn.text = ""
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	btn.add_child(center)


## HBox з іконкою + текстом для кнопок типу "Play Resume".
## Повертає HBoxContainer — додати як child до Button (btn.text = "").
static func icon_text_in_button(btn: Button, icon: Control, text: String,
		font_size: int = 28, gap: int = 10) -> void:
	btn.text = ""
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.set("theme_override_constants/separation", gap)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)
	center.add_child(hbox)
	btn.add_child(center)


## Повертає стрілку напрямку за рядковим ключем (up/down/left/right).
static func direction_arrow(dir: String, size: float = 24.0, color: Color = Color.WHITE) -> Control:
	match dir:
		"up": return arrow_up(size, color)
		"down": return arrow_down(size, color)
		"left": return arrow_left(size, color)
		"right": return arrow_right(size, color)
		_:
			push_warning("IconDraw: unknown direction " + dir)
			return arrow_up(size, color)


## ---- Premium Drawing Helpers ----


## Повертає палітру з 6 відтінків для однорідного стилю іконок.
static func _color_palette(base: Color) -> Dictionary:
	return {
		"base": base,
		"light": base.lightened(0.15),
		"lighter": base.lightened(0.30),
		"dark": base.darkened(0.20),
		"darker": base.darkened(0.35),
		"shadow": Color(base.darkened(0.40), 0.20),
	}


## М'яка тінь — 3 кола зі зменшенням альфа.
static func _draw_soft_shadow(ctrl: Control, center: Vector2, radius: float,
		color: Color = Color(0, 0, 0, 0.18),
		offset: Vector2 = Vector2(1.5, 2.5)) -> void:
	ctrl.draw_circle(center + offset, radius + 3.0, Color(color, color.a * 0.28))
	ctrl.draw_circle(center + offset, radius + 1.5, Color(color, color.a * 0.55))
	ctrl.draw_circle(center + offset, radius, Color(color, color.a * 1.0))


## Радіальний градієнт через концентричні кола (зовнішній → внутрішній).
static func _draw_radial_gradient(ctrl: Control, center: Vector2, radius: float,
		inner_color: Color, outer_color: Color, steps: int = 5) -> void:
	for i: int in range(steps, 0, -1):
		var t: float = float(i) / float(steps)
		var r: float = radius * t
		var col: Color = outer_color.lerp(inner_color, 1.0 - t)
		ctrl.draw_circle(center, r, col)


## Глянцевий блік — напівпрозоре біле коло зверху-зліва + спекулярна крапка.
static func _draw_gloss(ctrl: Control, center: Vector2, radius: float,
		intensity: float = 0.35) -> void:
	var gloss_pos: Vector2 = center + Vector2(-radius * 0.28, -radius * 0.28)
	var gloss_r: float = maxf(radius * 0.35, 2.0)
	ctrl.draw_circle(gloss_pos, gloss_r, Color(1, 1, 1, intensity))
	var spec_pos: Vector2 = center + Vector2(-radius * 0.18, -radius * 0.38)
	var spec_r: float = maxf(radius * 0.14, 1.0)
	ctrl.draw_circle(spec_pos, spec_r, Color(1, 1, 1, minf(intensity + 0.15, 0.7)))


## Контурна лінія — антиаліасна дуга навколо форми.
static func _draw_outline(ctrl: Control, center: Vector2, radius: float,
		color: Color, width: float = 1.5) -> void:
	ctrl.draw_arc(center, radius, 0.0, TAU, 24, color, maxf(width, 1.0), true)


## ---- Icon Factory Methods ----


## Pause — Пауза — дві вертикальні смужки з premium pipeline.
static func pause_bars(size: float = 24.0, color: Color = Color.WHITE) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var bar_w: float = size * 0.22
		var bar_h: float = size * 0.7
		var gap: float = size * 0.14
		var y: float = size * 0.15
		var x1: float = size * 0.5 - gap - bar_w
		var x2: float = size * 0.5 + gap
		## 1) Тіні
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		ctrl.draw_rect(Rect2(x1 + sh.x, y + sh.y, bar_w, bar_h), Color(0, 0, 0, 0.18), true)
		ctrl.draw_rect(Rect2(x2 + sh.x, y + sh.y, bar_w, bar_h), Color(0, 0, 0, 0.18), true)
		## 2) Основа — темний
		ctrl.draw_rect(Rect2(x1, y, bar_w, bar_h), pal["dark"], true)
		ctrl.draw_rect(Rect2(x2, y, bar_w, bar_h), pal["dark"], true)
		## 3) Світліший верх — gradient ефект
		ctrl.draw_rect(Rect2(x1, y, bar_w, bar_h * 0.45), pal["light"], true)
		ctrl.draw_rect(Rect2(x2, y, bar_w, bar_h * 0.45), pal["light"], true)
		## 4) Контур
		var lw: float = maxf(size * 0.03, 1.0)
		ctrl.draw_rect(Rect2(x1, y, bar_w, bar_h), pal["darker"], false, lw)
		ctrl.draw_rect(Rect2(x2, y, bar_w, bar_h), pal["darker"], false, lw)
		## 5) Sparkles
		var sp: float = maxf(size * 0.02, 1.0)
		ctrl.draw_circle(Vector2(x1 + bar_w * 0.3, y + bar_h * 0.18), sp, Color(1, 1, 1, 0.45))
		ctrl.draw_circle(Vector2(x2 + bar_w * 0.3, y + bar_h * 0.18), sp, Color(1, 1, 1, 0.45))
	)
	return ctrl


## Play — Плей — трикутник вправо з premium pipeline.
static func play_triangle(size: float = 24.0, color: Color = Color.WHITE) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.22, size * 0.12),
			Vector2(size * 0.84, size * 0.50),
			Vector2(size * 0.22, size * 0.88),
		])
		## 1) Тінь
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			shadow_pts.append(p + sh)
		ctrl.draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.18))
		## 2) Основа — темний
		ctrl.draw_colored_polygon(pts, pal["dark"])
		## 3) Внутрішній світлий трикутник — глибина
		var center: Vector2 = Vector2(size * 0.43, size * 0.50)
		var inner_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			inner_pts.append(center + (p - center) * 0.55)
		ctrl.draw_colored_polygon(inner_pts, pal["light"])
		## 4) Контур
		ctrl.draw_polyline(pts + PackedVector2Array([pts[0]]), pal["darker"],
			maxf(size * 0.03, 1.0), true)
		## 5) Глянц + sparkle
		ctrl.draw_circle(Vector2(size * 0.32, size * 0.30), maxf(size * 0.03, 1.5),
			Color(1, 1, 1, 0.40))
		ctrl.draw_circle(Vector2(size * 0.28, size * 0.24), maxf(size * 0.018, 1.0),
			Color(1, 1, 1, 0.55))
	)
	return ctrl


## Home — Будиночок з червоним дахом, жовтими стінами, синім вікном.
static func home_house(size: float = 24.0, color: Color = Color("FFD166")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var roof_c: Color = Color("ef476f")
		var roof_pal: Dictionary = _color_palette(roof_c)
		## 1) М'яка тінь — під всім будинком
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.55), size * 0.38)
		## 2) Корпус — градієнт стіни (верх світліший, низ темніший)
		ctrl.draw_rect(Rect2(size * 0.18, size * 0.45, size * 0.64, size * 0.47), pal["dark"], true)
		ctrl.draw_rect(Rect2(size * 0.18, size * 0.45, size * 0.64, size * 0.24), pal["base"], true)
		## Дах — тіньовий шар + основний + блік
		var roof_shadow: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.50, size * 0.10),
			Vector2(size * 0.94, size * 0.49),
			Vector2(size * 0.06, size * 0.49),
		])
		ctrl.draw_colored_polygon(roof_shadow, roof_pal["darker"])
		var roof: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.50, size * 0.08),
			Vector2(size * 0.92, size * 0.47),
			Vector2(size * 0.08, size * 0.47),
		])
		ctrl.draw_colored_polygon(roof, roof_pal["base"])
		## Блік на даху
		var roof_hl: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.50, size * 0.08),
			Vector2(size * 0.70, size * 0.28),
			Vector2(size * 0.30, size * 0.28),
		])
		ctrl.draw_colored_polygon(roof_hl, roof_pal["light"])
		## 3) Двері — коричневі з градієнтом
		var door_c: Color = Color("8B6914")
		var door_pal: Dictionary = _color_palette(door_c)
		ctrl.draw_rect(Rect2(size * 0.56, size * 0.58, size * 0.18, size * 0.34),
			door_pal["dark"], true)
		ctrl.draw_rect(Rect2(size * 0.57, size * 0.59, size * 0.08, size * 0.32),
			door_pal["base"], true)
		## Ручка дверей — блискуча
		ctrl.draw_circle(Vector2(size * 0.70, size * 0.76), size * 0.025,
			pal["lighter"])
		ctrl.draw_circle(Vector2(size * 0.70, size * 0.76), size * 0.015,
			Color(1, 1, 1, 0.6))
		## Вікно — блакитне з глянцем
		var win_c: Color = Color("93c5fd")
		ctrl.draw_rect(Rect2(size * 0.26, size * 0.55, size * 0.20, size * 0.18),
			win_c, true)
		## Відблиск на вікні
		ctrl.draw_rect(Rect2(size * 0.27, size * 0.56, size * 0.08, size * 0.07),
			Color(1, 1, 1, 0.35), true)
		## Рама вікна
		var fw: float = maxf(size * 0.02, 1.0)
		ctrl.draw_line(Vector2(size * 0.36, size * 0.55),
			Vector2(size * 0.36, size * 0.73), Color(1, 1, 1, 0.6), fw, true)
		ctrl.draw_line(Vector2(size * 0.26, size * 0.64),
			Vector2(size * 0.46, size * 0.64), Color(1, 1, 1, 0.6), fw, true)
		## 4) Глянцевий блік на стіні
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.46, size * 0.30, size * 0.08),
			Color(1, 1, 1, 0.15), true)
		## 5) Мікро-деталь: блискітки
		var sparkle_r: float = maxf(size * 0.018, 1.0)
		ctrl.draw_circle(Vector2(size * 0.30, size * 0.20), sparkle_r,
			Color(1, 1, 1, 0.50))
		ctrl.draw_circle(Vector2(size * 0.72, size * 0.38), sparkle_r * 0.8,
			Color(1, 1, 1, 0.35))
	)
	return ctrl


## ArrowLeft — Стрілка вліво з premium pipeline.
static func arrow_left(size: float = 24.0, color: Color = Color.WHITE) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.14, 3.0)
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.65, size * 0.15),
			Vector2(size * 0.28, size * 0.50),
			Vector2(size * 0.65, size * 0.85),
		])
		## 1) Тінь
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			shadow_pts.append(p + sh)
		ctrl.draw_polyline(shadow_pts, Color(0, 0, 0, 0.18), w + 1.0, true)
		## 2) Основа — dark
		ctrl.draw_polyline(pts, pal["dark"], w, true)
		## 3) Тонша лінія lighter зверху — градієнт
		ctrl.draw_polyline(pts, pal["light"], maxf(w * 0.45, 1.5), true)
		## 4) Sparkle
		ctrl.draw_circle(Vector2(size * 0.40, size * 0.35), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


## ↑ Стрілка вгору з premium pipeline.
static func arrow_up(size: float = 24.0, color: Color = Color.WHITE) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.14, 3.0)
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.15, size * 0.65),
			Vector2(size * 0.50, size * 0.28),
			Vector2(size * 0.85, size * 0.65),
		])
		## 1) Тінь
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			shadow_pts.append(p + sh)
		ctrl.draw_polyline(shadow_pts, Color(0, 0, 0, 0.18), w + 1.0, true)
		## 2) Основа — dark
		ctrl.draw_polyline(pts, pal["dark"], w, true)
		## 3) Тонша лінія lighter зверху — градієнт
		ctrl.draw_polyline(pts, pal["light"], maxf(w * 0.45, 1.5), true)
		## 4) Sparkle
		ctrl.draw_circle(Vector2(size * 0.35, size * 0.40), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


## ↓ Стрілка вниз з premium pipeline.
static func arrow_down(size: float = 24.0, color: Color = Color.WHITE) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.14, 3.0)
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.15, size * 0.35),
			Vector2(size * 0.50, size * 0.72),
			Vector2(size * 0.85, size * 0.35),
		])
		## 1) Тінь
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			shadow_pts.append(p + sh)
		ctrl.draw_polyline(shadow_pts, Color(0, 0, 0, 0.18), w + 1.0, true)
		## 2) Основа — dark
		ctrl.draw_polyline(pts, pal["dark"], w, true)
		## 3) Тонша лінія lighter зверху — градієнт
		ctrl.draw_polyline(pts, pal["light"], maxf(w * 0.45, 1.5), true)
		## 4) Sparkle
		ctrl.draw_circle(Vector2(size * 0.35, size * 0.55), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


## → Стрілка вправо з premium pipeline.
static func arrow_right(size: float = 24.0, color: Color = Color.WHITE) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.14, 3.0)
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.35, size * 0.15),
			Vector2(size * 0.72, size * 0.50),
			Vector2(size * 0.35, size * 0.85),
		])
		## 1) Тінь
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			shadow_pts.append(p + sh)
		ctrl.draw_polyline(shadow_pts, Color(0, 0, 0, 0.18), w + 1.0, true)
		## 2) Основа — dark
		ctrl.draw_polyline(pts, pal["dark"], w, true)
		## 3) Тонша лінія lighter зверху — градієнт
		ctrl.draw_polyline(pts, pal["light"], maxf(w * 0.45, 1.5), true)
		## 4) Sparkle
		ctrl.draw_circle(Vector2(size * 0.60, size * 0.35), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


## Trash — Кошик з premium pipeline.
static func trash_can(size: float = 24.0, color: Color = Color.WHITE) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.08, 1.5)
		## Корпус — трапеція
		var body: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.25, size * 0.28),
			Vector2(size * 0.75, size * 0.28),
			Vector2(size * 0.70, size * 0.90),
			Vector2(size * 0.30, size * 0.90),
		])
		## 1) Тінь корпусу
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		var shadow_body: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in body:
			shadow_body.append(p + sh)
		ctrl.draw_colored_polygon(shadow_body, Color(0, 0, 0, 0.18))
		## 2) Основа корпусу — dark
		ctrl.draw_colored_polygon(body, pal["dark"])
		## 3) Внутрішній світліший прямокутник — gradient ефект
		ctrl.draw_rect(Rect2(size * 0.32, size * 0.32, size * 0.36, size * 0.28),
			pal["light"], true)
		## 4) Вертикальні лінії на корпусі — деталі
		var line_color: Color = pal["darker"]
		ctrl.draw_line(Vector2(size * 0.42, size * 0.36),
			Vector2(size * 0.41, size * 0.82), line_color, w * 0.7, true)
		ctrl.draw_line(Vector2(size * 0.50, size * 0.36),
			Vector2(size * 0.50, size * 0.82), line_color, w * 0.7, true)
		ctrl.draw_line(Vector2(size * 0.58, size * 0.36),
			Vector2(size * 0.59, size * 0.82), line_color, w * 0.7, true)
		## 5) Контур корпусу
		ctrl.draw_polyline(body + PackedVector2Array([body[0]]), pal["darker"],
			maxf(size * 0.03, 1.0), true)
		## 6) Кришка — горизонтальна лінія
		ctrl.draw_line(Vector2(size * 0.20, size * 0.22),
			Vector2(size * 0.80, size * 0.22), pal["base"], w * 1.2, true)
		## 7) Ручка кришки
		ctrl.draw_line(Vector2(size * 0.38, size * 0.22),
			Vector2(size * 0.38, size * 0.12), pal["base"], w, true)
		ctrl.draw_line(Vector2(size * 0.38, size * 0.12),
			Vector2(size * 0.62, size * 0.12), pal["base"], w, true)
		ctrl.draw_line(Vector2(size * 0.62, size * 0.12),
			Vector2(size * 0.62, size * 0.22), pal["base"], w, true)
		## 8) Sparkles
		var sp: float = maxf(size * 0.02, 1.0)
		ctrl.draw_circle(Vector2(size * 0.35, size * 0.38), sp, Color(1, 1, 1, 0.45))
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.14), sp * 0.8, Color(1, 1, 1, 0.35))
	)
	return ctrl


## ✓ Галочка з premium pipeline.
static func checkmark(size: float = 24.0, color: Color = Color.WHITE) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.14, 3.0)
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.15, size * 0.52),
			Vector2(size * 0.40, size * 0.78),
			Vector2(size * 0.85, size * 0.22),
		])
		## 1) Тінь
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			shadow_pts.append(p + sh)
		ctrl.draw_polyline(shadow_pts, Color(0, 0, 0, 0.18), w + 1.0, true)
		## 2) Основа — dark
		ctrl.draw_polyline(pts, pal["dark"], w, true)
		## 3) Тонша лінія lighter зверху — градієнт
		ctrl.draw_polyline(pts, pal["light"], maxf(w * 0.45, 1.5), true)
		## 4) Sparkle
		ctrl.draw_circle(Vector2(size * 0.35, size * 0.50), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


## Star — Зірка — 5-кутна зірка, заповнена.
static func star_5pt(size: float = 24.0, color: Color = Color("FFD166")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.5
		var outer_r: float = size * 0.45
		var inner_r: float = size * 0.18
		## Генерація зірки
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in 10:
			var angle: float = -PI * 0.5 + float(i) * PI / 5.0
			var r: float = outer_r if i % 2 == 0 else inner_r
			pts.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))
		## 1) Тінь — зсунутий полігон
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		var sh_off: Vector2 = Vector2(maxf(size * 0.03, 1.0), maxf(size * 0.05, 1.5))
		for p: Vector2 in pts:
			shadow_pts.append(p + sh_off)
		ctrl.draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.18))
		## 2) Основна форма — темніший градієнт
		ctrl.draw_colored_polygon(pts, pal.dark)
		## 3) Внутрішня світліша зірка — глибина
		var inner_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			inner_pts.append(Vector2(cx + (p.x - cx) * 0.85, cy + (p.y - cy) * 0.85))
		ctrl.draw_colored_polygon(inner_pts, color)
		## Ще світліша серцевина
		var core_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			core_pts.append(Vector2(cx + (p.x - cx) * 0.55, cy + (p.y - cy) * 0.55))
		ctrl.draw_colored_polygon(core_pts, pal.light)
		## 4) Глянцевий блік зверху-зліва
		var gloss_r: float = maxf(outer_r * 0.30, 2.0)
		ctrl.draw_circle(
			Vector2(cx - outer_r * 0.22, cy - outer_r * 0.30),
			gloss_r, Color(1, 1, 1, 0.32))
		var spec_r: float = maxf(outer_r * 0.12, 1.0)
		ctrl.draw_circle(
			Vector2(cx - outer_r * 0.15, cy - outer_r * 0.38),
			spec_r, Color(1, 1, 1, 0.50))
		## 5) Мікро-деталі — іскорки на верхніх промінях
		var sparkle_r: float = maxf(size * 0.025, 1.0)
		ctrl.draw_circle(
			Vector2(cx, cy - outer_r * 0.80), sparkle_r, Color(1, 1, 1, 0.70))
		ctrl.draw_circle(
			Vector2(cx + outer_r * 0.55, cy - outer_r * 0.25),
			sparkle_r, Color(1, 1, 1, 0.55))
	)
	return ctrl


## Tap — Палець для тапу — коло (кінчик) + тіло.
static func tap_finger(size: float = 24.0, color: Color = Color.WHITE) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var cx: float = size * 0.50
		## Тіло пальця — закруглений прямокутник
		var body_w: float = size * 0.32
		var body_h: float = size * 0.50
		ctrl.draw_rect(Rect2(cx - body_w * 0.5, size * 0.38, body_w, body_h), color, true)
		## Кінчик пальця — коло
		ctrl.draw_circle(Vector2(cx, size * 0.32), size * 0.18, color)
		## Кільце навколо — натяк на "тап"
		var ring_color: Color = Color(color, color.a * 0.35)
		var w: float = maxf(size * 0.06, 1.0)
		ctrl.draw_arc(Vector2(cx, size * 0.32), size * 0.28, 0, TAU, 24, ring_color, w, true)
	)
	return ctrl


## Chevron — Маленький трикутник вниз — для dropdown.
static func dropdown_chevron(size: float = 20.0, color: Color = Color.WHITE) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.20, size * 0.30),
			Vector2(size * 0.80, size * 0.30),
			Vector2(size * 0.50, size * 0.72),
		])
		## 1) Тінь
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			shadow_pts.append(p + sh)
		ctrl.draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.18))
		## 2) Основа
		ctrl.draw_colored_polygon(pts, pal["dark"])
		## 3) Внутрішній світлий — глибина
		var center: Vector2 = Vector2(size * 0.50, size * 0.44)
		var inner_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			inner_pts.append(center + (p - center) * 0.50)
		ctrl.draw_colored_polygon(inner_pts, pal["light"])
		## 4) Контур
		ctrl.draw_polyline(pts + PackedVector2Array([pts[0]]), pal["darker"],
			maxf(size * 0.03, 1.0), true)
	)
	return ctrl


## ---- V144.2: Game & Decorative Icons ----


## ● Кольорова крапка — заповнене коло (premium pipeline).
static func color_dot(size: float = 24.0, color: Color = Color.RED) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var center: Vector2 = Vector2(size * 0.5, size * 0.5)
		var r: float = size * 0.42
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.04, 1.0))
		## 1) Shadow
		ctrl.draw_circle(center + sh, r + 0.5, pal["shadow"])
		## 2) Dark base
		ctrl.draw_circle(center, r, pal["dark"])
		## 3) Light glare (upper-left)
		ctrl.draw_circle(center + Vector2(-r * 0.2, -r * 0.2), r * 0.55, pal["light"])
		## 4) Border
		ctrl.draw_arc(center, r, 0, TAU, 24,
			pal["darker"], maxf(size * 0.06, 1.0), true)
		## 5) Sparkle
		ctrl.draw_circle(center + Vector2(-r * 0.3, -r * 0.35),
			maxf(size * 0.02, 1.0), Color(1, 1, 1, 0.50))
	)
	return ctrl


## LAW 25: Color dot with optional color-blind pattern overlay.
static func color_dot_cb(size: float, color: Color, pattern: String) -> Control:
	var ctrl: Control = color_dot(size, color)
	if pattern.is_empty():
		return ctrl
	var overlay: Control = Control.new()
	overlay.custom_minimum_size = Vector2(size, size)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r: float = size * 0.42
	var c: Vector2 = Vector2(size * 0.5, size * 0.5)
	overlay.draw.connect(func() -> void:
		draw_cb_pattern(overlay, c, r, pattern)
	)
	ctrl.add_child(overlay)
	return ctrl


## LAW 25: Draw color-blind pattern inside circular region on any CanvasItem.
## Called from within _draw() context. `ci` must be the drawing CanvasItem.
static func draw_cb_pattern(ci: CanvasItem, center: Vector2, radius: float,
		pattern: String, color: Color = Color(1, 1, 1, 0.6)) -> void:
	match pattern:
		"stripes":
			_draw_pat_stripes(ci, center, radius, color)
		"dots":
			_draw_pat_dots(ci, center, radius, color)
		"waves":
			_draw_pat_waves(ci, center, radius, color)
		"star":
			_draw_pat_star(ci, center, radius, color)
		"diamond":
			_draw_pat_diamond(ci, center, radius, color)
		"cross":
			_draw_pat_cross(ci, center, radius, color)
		"heart":
			_draw_pat_heart(ci, center, radius, color)
		"ring":
			_draw_pat_ring(ci, center, radius, color)
		"triangle":
			_draw_pat_triangle(ci, center, radius, color)
		"chevron":
			_draw_pat_chevron(ci, center, radius, color)


static func _draw_pat_stripes(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	## 3 diagonal lines clipped to circle
	var w: float = maxf(r * 0.08, 2.0)
	for offset: float in [-r * 0.35, 0.0, r * 0.35]:
		## Line: y = x + offset (45 deg diagonal, in local coords relative to center)
		## Intersect with circle: x^2 + (x + offset)^2 = r^2 → solve for x
		var disc: float = 2.0 * r * r - offset * offset
		if disc <= 0.0:
			continue
		var half: float = sqrt(disc) * 0.5
		var x1: float = -half - offset * 0.5
		var x2: float = half - offset * 0.5
		ci.draw_line(c + Vector2(x1, x1 + offset), c + Vector2(x2, x2 + offset), col, w, true)


static func _draw_pat_dots(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	## 5 dots in quincunx pattern
	var dr: float = maxf(r * 0.12, 3.0)
	var spread: float = r * 0.4
	ci.draw_circle(c, dr, col)
	ci.draw_circle(c + Vector2(-spread, -spread), dr, col)
	ci.draw_circle(c + Vector2(spread, -spread), dr, col)
	ci.draw_circle(c + Vector2(-spread, spread), dr, col)
	ci.draw_circle(c + Vector2(spread, spread), dr, col)


static func _draw_pat_waves(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	## 3 horizontal wavy lines
	var w: float = maxf(r * 0.07, 2.0)
	for y_off: float in [-r * 0.3, 0.0, r * 0.3]:
		var pts: PackedVector2Array = PackedVector2Array()
		var half_w: float = sqrt(maxf(r * r - y_off * y_off, 0.0)) * 0.85
		var steps: int = 12
		for i: int in range(steps + 1):
			var t: float = float(i) / float(steps)
			var x: float = lerpf(-half_w, half_w, t)
			var y: float = y_off + sin(t * TAU * 1.5) * r * 0.1
			pts.append(c + Vector2(x, y))
		if pts.size() >= 2:
			ci.draw_polyline(pts, col, w, true)


static func _draw_pat_star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	## 5-point star
	var pts: PackedVector2Array = PackedVector2Array()
	var outer: float = r * 0.45
	var inner: float = r * 0.2
	for i: int in 10:
		var angle: float = float(i) * TAU / 10.0 - PI * 0.5
		var dist: float = outer if i % 2 == 0 else inner
		pts.append(c + Vector2(cos(angle), sin(angle)) * dist)
	ci.draw_colored_polygon(pts, col)


static func _draw_pat_diamond(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	## Rhombus
	var s: float = r * 0.45
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(s * 0.7, 0),
		c + Vector2(0, s), c + Vector2(-s * 0.7, 0),
	])
	ci.draw_colored_polygon(pts, col)


static func _draw_pat_cross(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var w: float = maxf(r * 0.1, 2.5)
	var arm: float = r * 0.4
	ci.draw_line(c + Vector2(-arm, 0), c + Vector2(arm, 0), col, w, true)
	ci.draw_line(c + Vector2(0, -arm), c + Vector2(0, arm), col, w, true)


static func _draw_pat_heart(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	## Approximate heart shape
	var s: float = r * 0.35
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 24:
		var t: float = float(i) / 24.0 * TAU
		var x: float = s * (16.0 * pow(sin(t), 3)) / 16.0
		var y: float = -s * (13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)) / 16.0
		pts.append(c + Vector2(x, y))
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)


static func _draw_pat_ring(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var w: float = maxf(r * 0.1, 2.0)
	ci.draw_arc(c, r * 0.35, 0.0, TAU, 24, col, w, true)


static func _draw_pat_triangle(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var s: float = r * 0.4
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(0, -s),
		c + Vector2(s * 0.866, s * 0.5),
		c + Vector2(-s * 0.866, s * 0.5),
	])
	ci.draw_colored_polygon(pts, col)


static func _draw_pat_chevron(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var w: float = maxf(r * 0.1, 2.5)
	var arm: float = r * 0.35
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(-arm, -arm * 0.5),
		c + Vector2(0, arm * 0.5),
		c + Vector2(arm, -arm * 0.5),
	])
	ci.draw_polyline(pts, col, w, true)


## Монета з числом — коло + цифра по центру.
static func coin_number(size: float = 24.0, number: int = 1,
		color: Color = Color.WHITE) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl: Label = Label.new()
	lbl.text = str(number)
	lbl.add_theme_font_size_override("font_size", int(size * 0.5))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(size, size)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(lbl)
	ctrl.draw.connect(func() -> void:
		ctrl.draw_arc(Vector2(size * 0.5, size * 0.5), size * 0.42, 0, TAU, 24,
			color, maxf(size * 0.08, 1.5), true)
	)
	return ctrl


## Heart — Серце — преміум 5-шарове з глибиною.
static func heart(size: float = 24.0, color: Color = Color("ff6b6b")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var r: float = size * 0.22
		var lc: Vector2 = Vector2(cx - r, size * 0.35)
		var rc: Vector2 = Vector2(cx + r, size * 0.35)
		var bottom: PackedVector2Array = PackedVector2Array([
			Vector2(cx - r * 2, size * 0.40),
			Vector2(cx + r * 2, size * 0.40),
			Vector2(cx, size * 0.88),
		])
		## 1) М'яка тінь
		var sh: Vector2 = Vector2(maxf(size * 0.03, 1.0), maxf(size * 0.05, 1.5))
		var sh_col: Color = Color(0, 0, 0, 0.18)
		ctrl.draw_circle(lc + sh, r, sh_col)
		ctrl.draw_circle(rc + sh, r, sh_col)
		var sh_bottom: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in bottom:
			sh_bottom.append(p + sh)
		ctrl.draw_colored_polygon(sh_bottom, sh_col)
		## 2) Зовнішній шар — темний
		ctrl.draw_circle(lc, r, pal.dark)
		ctrl.draw_circle(rc, r, pal.dark)
		ctrl.draw_colored_polygon(bottom, pal.dark)
		## 3) Середній шар — базовий колір (трохи менший)
		var mid_s: float = 0.88
		ctrl.draw_circle(lc, r * mid_s, color)
		ctrl.draw_circle(rc, r * mid_s, color)
		var mid_bottom: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in bottom:
			mid_bottom.append(Vector2(cx + (p.x - cx) * mid_s, size * 0.40 + (p.y - size * 0.40) * mid_s))
		ctrl.draw_colored_polygon(mid_bottom, color)
		## Внутрішній шар — світліший (серцевина)
		var inn_s: float = 0.60
		ctrl.draw_circle(lc, r * inn_s, pal.light)
		ctrl.draw_circle(rc, r * inn_s, pal.light)
		## 4) Глянцевий блік — на лівій половині
		var gloss_r: float = maxf(r * 0.40, 2.0)
		ctrl.draw_circle(
			Vector2(cx - r * 0.8, size * 0.32),
			gloss_r, Color(1, 1, 1, 0.30))
		var spec_r: float = maxf(r * 0.18, 1.0)
		ctrl.draw_circle(
			Vector2(cx - r * 0.6, size * 0.28),
			spec_r, Color(1, 1, 1, 0.50))
		## 5) Пульсуючий контур — зовнішній обвід
		var outline_w: float = maxf(size * 0.03, 1.0)
		ctrl.draw_arc(lc, r, 0, TAU, 16, Color(1, 1, 1, 0.15), outline_w, true)
		ctrl.draw_arc(rc, r, 0, TAU, 16, Color(1, 1, 1, 0.15), outline_w, true)
	)
	return ctrl


## Gear — Шестерня — коло + зубці.
static func gear(size: float = 24.0, color: Color = Color("b8c0cc")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.5
		var outer_r: float = size * 0.42
		var inner_r: float = size * 0.30
		var teeth: int = 8
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(cx, cy), outer_r)
		## 2) Зубці з градієнтом
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in teeth * 2:
			var angle: float = float(i) * PI / float(teeth)
			var r: float = outer_r if i % 2 == 0 else inner_r
			pts.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))
		ctrl.draw_colored_polygon(pts, pal["dark"])
		## Внутрішній диск — радіальний градієнт
		_draw_radial_gradient(ctrl, Vector2(cx, cy), inner_r, pal["light"], pal["base"], 5)
		## Внутрішнє кільце — темніше
		ctrl.draw_circle(Vector2(cx, cy), size * 0.18, pal["darker"])
		## Отвір в центрі
		_draw_radial_gradient(ctrl, Vector2(cx, cy), size * 0.10, pal["base"], pal["darker"], 4)
		## 3) Контур
		_draw_outline(ctrl, Vector2(cx, cy), outer_r, pal["darker"], maxf(size * 0.03, 1.0))
		## 4) Глянцевий блік
		_draw_gloss(ctrl, Vector2(cx, cy), outer_r, 0.30)
		## 5) Мікро-деталь: блискітки на зубцях
		var sparkle_r: float = maxf(size * 0.018, 1.0)
		ctrl.draw_circle(Vector2(cx - size * 0.30, cy - size * 0.18), sparkle_r,
			Color(1, 1, 1, 0.50))
		ctrl.draw_circle(Vector2(cx + size * 0.22, cy - size * 0.28), sparkle_r * 0.8,
			Color(1, 1, 1, 0.35))
	)
	return ctrl


## Cart — Візок — корпус + колеса.
static func cart(size: float = 24.0, color: Color = Color("FFD166")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.08, 1.5)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.50), size * 0.35)
		## 2) Корпус — трапеція з тіньовим шаром
		var body_shadow: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.16, size * 0.27),
			Vector2(size * 0.86, size * 0.27),
			Vector2(size * 0.79, size * 0.67),
			Vector2(size * 0.26, size * 0.67),
		])
		ctrl.draw_colored_polygon(body_shadow, pal["darker"])
		var body: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.15, size * 0.25),
			Vector2(size * 0.85, size * 0.25),
			Vector2(size * 0.78, size * 0.65),
			Vector2(size * 0.25, size * 0.65),
		])
		ctrl.draw_colored_polygon(body, pal["base"])
		## Верхня зона — світліша
		var body_top: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.15, size * 0.25),
			Vector2(size * 0.85, size * 0.25),
			Vector2(size * 0.82, size * 0.42),
			Vector2(size * 0.20, size * 0.42),
		])
		ctrl.draw_colored_polygon(body_top, pal["light"])
		## 3) Ручка — коричнева з палітрою
		var handle_c: Color = Color("8B6914")
		ctrl.draw_line(Vector2(size * 0.10, size * 0.18),
			Vector2(size * 0.25, size * 0.40), handle_c, w, true)
		## Колеса — з градієнтом
		var wheel_pal: Dictionary = _color_palette(Color("6c757d"))
		_draw_radial_gradient(ctrl, Vector2(size * 0.35, size * 0.78), size * 0.09,
			wheel_pal["light"], wheel_pal["dark"], 4)
		_draw_radial_gradient(ctrl, Vector2(size * 0.68, size * 0.78), size * 0.09,
			wheel_pal["light"], wheel_pal["dark"], 4)
		## Осі коліс — глянцеві
		ctrl.draw_circle(Vector2(size * 0.35, size * 0.78), size * 0.03,
			Color(1, 1, 1, 0.6))
		ctrl.draw_circle(Vector2(size * 0.68, size * 0.78), size * 0.03,
			Color(1, 1, 1, 0.6))
		## 4) Глянцевий блік
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.27, size * 0.30, size * 0.08),
			Color(1, 1, 1, 0.18), true)
		## 5) Мікро-деталь: блискітки
		var sparkle_r: float = maxf(size * 0.018, 1.0)
		ctrl.draw_circle(Vector2(size * 0.30, size * 0.32), sparkle_r,
			Color(1, 1, 1, 0.50))
		ctrl.draw_circle(Vector2(size * 0.70, size * 0.42), sparkle_r * 0.7,
			Color(1, 1, 1, 0.30))
	)
	return ctrl


## Robot — Робот — голова + очі + антена з зеленим світлом.
static func robot_head(size: float = 24.0, color: Color = Color("6366f1")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.05, 1.0)
		## 1) Антена — стрижень
		ctrl.draw_line(Vector2(size * 0.5, size * 0.22),
			Vector2(size * 0.5, size * 0.12), pal.light, w, true)
		## Антена — 3-кільцевий градієнт свічення
		var ant_c: Vector2 = Vector2(size * 0.5, size * 0.09)
		var glow_col: Color = Color("22c55e")
		ctrl.draw_circle(ant_c, maxf(size * 0.09, 3.0), Color(glow_col, 0.15))
		ctrl.draw_circle(ant_c, maxf(size * 0.07, 2.5), Color(glow_col, 0.30))
		ctrl.draw_circle(ant_c, maxf(size * 0.05, 2.0), Color(glow_col, 0.55))
		ctrl.draw_circle(ant_c, maxf(size * 0.03, 1.5), glow_col)
		## Спекулярний блік на антені
		ctrl.draw_circle(ant_c + Vector2(-size * 0.015, -size * 0.02),
			maxf(size * 0.012, 1.0), Color(1, 1, 1, 0.6))
		## 2) М'яка тінь голови
		ctrl.draw_rect(Rect2(size * 0.22, size * 0.25, size * 0.60, size * 0.45),
			Color(0, 0, 0, 0.15), true)
		## 3) Голова — основа з градієнтом (ліва сторона світліша)
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.22, size * 0.60, size * 0.45), pal.base, true)
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.22, size * 0.30, size * 0.45), pal.light, true)
		## Нижня частина голови — темніша
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.52, size * 0.60, size * 0.15), pal.dark, true)
		## 4) Глянець на голові — широка смуга
		ctrl.draw_rect(Rect2(size * 0.22, size * 0.24, size * 0.56, size * 0.10),
			Color(1, 1, 1, 0.18), true)
		## Сканлайн на екрані (мікро-деталь) — горизонтальні лінії
		var scan_w: float = maxf(size * 0.02, 0.5)
		for si: int in 4:
			var sy: float = size * (0.30 + float(si) * 0.055)
			ctrl.draw_line(Vector2(size * 0.22, sy), Vector2(size * 0.78, sy),
				Color(1, 1, 1, 0.06), scan_w, true)
		## Контур голови
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.22, size * 0.60, size * 0.45),
			pal.darker, false, maxf(w * 0.5, 1.0))
		## Очі — білі з зіницями та бліком
		ctrl.draw_circle(Vector2(size * 0.36, size * 0.40), size * 0.08, Color.WHITE)
		ctrl.draw_circle(Vector2(size * 0.64, size * 0.40), size * 0.08, Color.WHITE)
		ctrl.draw_circle(Vector2(size * 0.38, size * 0.39), size * 0.04, Color("2d3436"))
		ctrl.draw_circle(Vector2(size * 0.66, size * 0.39), size * 0.04, Color("2d3436"))
		## Блік на зіницях
		ctrl.draw_circle(Vector2(size * 0.37, size * 0.38), maxf(size * 0.015, 1.0),
			Color(1, 1, 1, 0.7))
		ctrl.draw_circle(Vector2(size * 0.65, size * 0.38), maxf(size * 0.015, 1.0),
			Color(1, 1, 1, 0.7))
		## Рот — зубці
		ctrl.draw_line(Vector2(size * 0.35, size * 0.56),
			Vector2(size * 0.65, size * 0.56), Color("2d3436"), maxf(size * 0.03, 1.0), true)
		## Зубці на роті — вертикальні штрихи
		for ti: int in 4:
			var tx: float = size * (0.40 + float(ti) * 0.07)
			ctrl.draw_line(Vector2(tx, size * 0.54), Vector2(tx, size * 0.58),
				Color("2d3436"), maxf(size * 0.015, 0.5), true)
		## Тіло — з градієнтом
		ctrl.draw_rect(Rect2(size * 0.28, size * 0.70, size * 0.44, size * 0.22),
			pal.dark, true)
		ctrl.draw_rect(Rect2(size * 0.28, size * 0.70, size * 0.22, size * 0.22),
			pal.base, true)
		## Глянець на тілі
		ctrl.draw_rect(Rect2(size * 0.28, size * 0.70, size * 0.44, size * 0.06),
			Color(1, 1, 1, 0.12), true)
		## 5) Болти по боках — з глянцем
		var bolt_col: Color = Color("b8c0cc")
		var bolt_r: float = maxf(size * 0.035, 1.5)
		ctrl.draw_circle(Vector2(size * 0.14, size * 0.40), bolt_r, bolt_col)
		ctrl.draw_circle(Vector2(size * 0.86, size * 0.40), bolt_r, bolt_col)
		## Болт глянець
		ctrl.draw_circle(Vector2(size * 0.135, size * 0.39), maxf(bolt_r * 0.35, 1.0),
			Color(1, 1, 1, 0.45))
		ctrl.draw_circle(Vector2(size * 0.855, size * 0.39), maxf(bolt_r * 0.35, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


## 🧺 Кошик — трапеція + дугова ручка.
static func basket(size: float = 24.0, color: Color = Color("d4a574")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.06, 1.0)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.60), size * 0.30)
		## 2) Ручка — дуга з глибиною
		ctrl.draw_arc(Vector2(size * 0.5, size * 0.38), size * 0.22,
			PI, 0, 16, pal["darker"], w * 2.0, true)
		ctrl.draw_arc(Vector2(size * 0.5, size * 0.38), size * 0.22,
			PI, 0, 16, pal["light"], w * 1.2, true)
		## Корпус — тіньовий шар + основний
		var body_s: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.19, size * 0.40),
			Vector2(size * 0.83, size * 0.40),
			Vector2(size * 0.73, size * 0.90),
			Vector2(size * 0.29, size * 0.90),
		])
		ctrl.draw_colored_polygon(body_s, pal["darker"])
		var body: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.18, size * 0.38),
			Vector2(size * 0.82, size * 0.38),
			Vector2(size * 0.72, size * 0.88),
			Vector2(size * 0.28, size * 0.88),
		])
		ctrl.draw_colored_polygon(body, pal["base"])
		## Верхня зона — світліша
		var body_top: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.18, size * 0.38),
			Vector2(size * 0.82, size * 0.38),
			Vector2(size * 0.80, size * 0.52),
			Vector2(size * 0.20, size * 0.52),
		])
		ctrl.draw_colored_polygon(body_top, pal["light"])
		## 3) Горизонтальні плетіння — темніші
		ctrl.draw_line(Vector2(size * 0.22, size * 0.52),
			Vector2(size * 0.78, size * 0.52), pal["dark"], w * 0.7, true)
		ctrl.draw_line(Vector2(size * 0.25, size * 0.68),
			Vector2(size * 0.75, size * 0.68), pal["dark"], w * 0.7, true)
		## 4) Глянцевий блік
		ctrl.draw_rect(Rect2(size * 0.22, size * 0.40, size * 0.28, size * 0.08),
			Color(1, 1, 1, 0.18), true)
		## 5) Мікро-деталь: блискітки
		var sparkle_r: float = maxf(size * 0.018, 1.0)
		ctrl.draw_circle(Vector2(size * 0.35, size * 0.45), sparkle_r,
			Color(1, 1, 1, 0.45))
		ctrl.draw_circle(Vector2(size * 0.65, size * 0.58), sparkle_r * 0.7,
			Color(1, 1, 1, 0.30))
	)
	return ctrl


## MoneyBag — Мішок грошей — мішок + символ $.
static func money_bag(size: float = 24.0, color: Color = Color("FFD166")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.58
		var r: float = size * 0.34
		var w: float = maxf(size * 0.06, 1.0)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(cx, cy), r)
		## 2) Базова форма — 3-кільцевий градієнт
		_draw_radial_gradient(ctrl, Vector2(cx, cy), r, pal["light"], pal["dark"], 6)
		_draw_outline(ctrl, Vector2(cx, cy), r, pal["darker"], maxf(size * 0.03, 1.0))
		## 3) Зав'язка з глибиною
		ctrl.draw_line(Vector2(size * 0.38, size * 0.28),
			Vector2(cx, size * 0.18), pal["dark"], w, true)
		ctrl.draw_line(Vector2(size * 0.62, size * 0.28),
			Vector2(cx, size * 0.18), pal["dark"], w, true)
		## Вузлик зверху
		ctrl.draw_circle(Vector2(cx, size * 0.20), maxf(size * 0.05, 1.5), pal["base"])
		ctrl.draw_circle(Vector2(cx, size * 0.20), maxf(size * 0.03, 1.0), pal["light"])
		## 4) Глянцевий блік
		_draw_gloss(ctrl, Vector2(cx, cy), r, 0.30)
		## 5) $ ембос-ефект (тінь + світлий шар)
		var emboss_w: float = maxf(w * 1.4, 1.5)
		var sh_off: Vector2 = Vector2(size * 0.01, size * 0.02)
		ctrl.draw_line(Vector2(cx, size * 0.42) + sh_off,
			Vector2(cx, size * 0.76) + sh_off, pal["darker"], emboss_w, true)
		ctrl.draw_arc(Vector2(cx, size * 0.52) + sh_off, size * 0.10,
			PI * 0.3, PI * 1.2, 10, pal["darker"], emboss_w, true)
		ctrl.draw_arc(Vector2(cx, size * 0.65) + sh_off, size * 0.10,
			PI * 1.3, PI * 2.2, 10, pal["darker"], emboss_w, true)
		ctrl.draw_line(Vector2(cx, size * 0.42),
			Vector2(cx, size * 0.76), pal["lighter"], emboss_w * 0.8, true)
		ctrl.draw_arc(Vector2(cx, size * 0.52), size * 0.10,
			PI * 0.3, PI * 1.2, 10, pal["lighter"], emboss_w * 0.8, true)
		ctrl.draw_arc(Vector2(cx, size * 0.65), size * 0.10,
			PI * 1.3, PI * 2.2, 10, pal["lighter"], emboss_w * 0.8, true)
		## Мікро-деталь: блискітки монет
		var sparkle_r: float = maxf(size * 0.02, 1.0)
		ctrl.draw_circle(Vector2(size * 0.34, size * 0.48), sparkle_r,
			Color(1, 1, 1, 0.55))
		ctrl.draw_circle(Vector2(size * 0.64, size * 0.52), sparkle_r * 0.8,
			Color(1, 1, 1, 0.40))
		ctrl.draw_circle(Vector2(size * 0.42, size * 0.72), sparkle_r * 0.7,
			Color(1, 1, 1, 0.35))
	)
	return ctrl


## Beaker — Колба/пробірка — конічна форма + рідина.
static func beaker(size: float = 24.0, color: Color = Color("a78bfa")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		## 1) М'яка тінь під колбою
		_draw_soft_shadow(ctrl, Vector2(cx, size * 0.75), size * 0.28)
		## 2) Горлечко з градієнтом
		ctrl.draw_rect(Rect2(size * 0.40, size * 0.08, size * 0.20, size * 0.25), pal["light"], true)
		ctrl.draw_rect(Rect2(size * 0.40, size * 0.08, size * 0.20, size * 0.04), pal["lighter"], true)
		## Тіло — трапеція з glass tint
		var body: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.38, size * 0.33),
			Vector2(size * 0.62, size * 0.33),
			Vector2(size * 0.78, size * 0.88),
			Vector2(size * 0.22, size * 0.88),
		])
		ctrl.draw_colored_polygon(body, pal["base"])
		## 3) Glass tint градієнт — світліша смуга зліва
		var glass_highlight: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.38, size * 0.33),
			Vector2(size * 0.48, size * 0.33),
			Vector2(size * 0.44, size * 0.85),
			Vector2(size * 0.24, size * 0.85),
		])
		ctrl.draw_colored_polygon(glass_highlight, Color(pal["lighter"], 0.3))
		## Контур колби
		var outline_w: float = maxf(size * 0.025, 1.0)
		ctrl.draw_polyline(PackedVector2Array([
			Vector2(size * 0.40, size * 0.08),
			Vector2(size * 0.38, size * 0.33),
			Vector2(size * 0.22, size * 0.88),
			Vector2(size * 0.78, size * 0.88),
			Vector2(size * 0.62, size * 0.33),
			Vector2(size * 0.60, size * 0.08),
		]), pal["darker"], outline_w, true)
		## Рідина внизу
		var liquid: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.30, size * 0.65),
			Vector2(size * 0.70, size * 0.65),
			Vector2(size * 0.76, size * 0.85),
			Vector2(size * 0.24, size * 0.85),
		])
		ctrl.draw_colored_polygon(liquid, pal["light"])
		## 4) Rim highlight — блік на горлечку
		ctrl.draw_line(Vector2(size * 0.40, size * 0.08),
			Vector2(size * 0.60, size * 0.08), Color(1, 1, 1, 0.5),
			maxf(size * 0.02, 1.0), true)
		## 5) Мікро-деталь: бульбашки x3
		var bub_r: float = maxf(size * 0.025, 1.0)
		ctrl.draw_circle(Vector2(size * 0.42, size * 0.72), bub_r,
			Color(1, 1, 1, 0.45))
		ctrl.draw_circle(Vector2(size * 0.55, size * 0.68), bub_r * 0.7,
			Color(1, 1, 1, 0.35))
		ctrl.draw_circle(Vector2(size * 0.48, size * 0.78), bub_r * 0.55,
			Color(1, 1, 1, 0.30))
	)
	return ctrl


## Clock — Циферблат годинника — коло + стрілки.
static func clock_face(size: float = 24.0, color: Color = Color("f5f5f5")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var cx: float = size * 0.5
		var cy: float = size * 0.5
		var r: float = size * 0.40
		var w: float = maxf(size * 0.06, 1.0)
		var center: Vector2 = Vector2(cx, cy)
		var gold: Color = Color("FFD166")
		var gold_pal: Dictionary = _color_palette(gold)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, center, r + size * 0.04)
		## 2) Градієнтний безель — 3 кільця (темне → золоте → світле)
		ctrl.draw_circle(center, r + size * 0.06, gold_pal["darker"])
		ctrl.draw_circle(center, r + size * 0.04, gold_pal["base"])
		ctrl.draw_circle(center, r + size * 0.02, gold_pal["light"])
		## Циферблат — радіальний градієнт (краї трохи темніші)
		_draw_radial_gradient(ctrl, center, r, color, color.darkened(0.08), 4)
		## 3) Хвилинні позначки — 12 штук
		for i: int in 12:
			var angle: float = float(i) * PI / 6.0 - PI * 0.5
			var is_main: bool = i % 3 == 0
			var mark_start: float = 0.82 if is_main else 0.87
			var mark_w: float = w * (0.9 if is_main else 0.5)
			var p1: Vector2 = Vector2(cx + r * mark_start * cos(angle), cy + r * mark_start * sin(angle))
			var p2: Vector2 = Vector2(cx + r * 0.95 * cos(angle), cy + r * 0.95 * sin(angle))
			ctrl.draw_line(p1, p2, Color("2d3436"), mark_w, true)
		## Годинна стрілка — чорна
		ctrl.draw_line(center,
			Vector2(cx, cy - r * 0.50), Color("2d3436"), w * 1.3, true)
		## Хвилинна стрілка — чорна тонша
		ctrl.draw_line(center,
			Vector2(cx + r * 0.65, cy - r * 0.15), Color("2d3436"), w * 0.8, true)
		## Секундна стрілка — червона
		ctrl.draw_line(center,
			Vector2(cx - r * 0.20, cy + r * 0.40), Color("ef476f"), w * 0.5, true)
		## 4) Центральний "дорогоцінний камінь" — градієнтна крапка
		var jewel_r: float = maxf(size * 0.05, 2.0)
		ctrl.draw_circle(center, jewel_r + maxf(size * 0.01, 0.5), gold_pal["darker"])
		_draw_radial_gradient(ctrl, center, jewel_r, gold_pal["lighter"], gold_pal["base"], 3)
		## Спекулярний блік на дорогоцінному камені
		ctrl.draw_circle(
			Vector2(cx - jewel_r * 0.3, cy - jewel_r * 0.3),
			maxf(jewel_r * 0.35, 1.0), Color(1, 1, 1, 0.55))
		## 5) Глянцевий блік на склі
		_draw_gloss(ctrl, center, r, 0.18)
	)
	return ctrl


## Shirt — Футболка — корпус + рукави + комір.
static func shirt(size: float = 24.0, color: Color = Color("38bdf8")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.55), size * 0.35)
		## 2) Тінь — offset polygon
		var body_shadow: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.32, size * 0.22),
			Vector2(size * 0.14, size * 0.37),
			Vector2(size * 0.24, size * 0.42),
			Vector2(size * 0.30, size * 0.32),
			Vector2(size * 0.30, size * 0.90),
			Vector2(size * 0.74, size * 0.90),
			Vector2(size * 0.74, size * 0.32),
			Vector2(size * 0.80, size * 0.42),
			Vector2(size * 0.90, size * 0.37),
			Vector2(size * 0.72, size * 0.22),
		])
		ctrl.draw_colored_polygon(body_shadow, pal["darker"])
		## Тіло — основний колір
		var body: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.30, size * 0.20),
			Vector2(size * 0.12, size * 0.35),
			Vector2(size * 0.22, size * 0.40),
			Vector2(size * 0.28, size * 0.30),
			Vector2(size * 0.28, size * 0.88),
			Vector2(size * 0.72, size * 0.88),
			Vector2(size * 0.72, size * 0.30),
			Vector2(size * 0.78, size * 0.40),
			Vector2(size * 0.88, size * 0.35),
			Vector2(size * 0.70, size * 0.20),
		])
		ctrl.draw_colored_polygon(body, pal["base"])
		## Верхня зона — світліша (плечі)
		var shoulders: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.30, size * 0.20),
			Vector2(size * 0.12, size * 0.35),
			Vector2(size * 0.22, size * 0.40),
			Vector2(size * 0.28, size * 0.30),
			Vector2(size * 0.28, size * 0.45),
			Vector2(size * 0.72, size * 0.45),
			Vector2(size * 0.72, size * 0.30),
			Vector2(size * 0.78, size * 0.40),
			Vector2(size * 0.88, size * 0.35),
			Vector2(size * 0.70, size * 0.20),
		])
		ctrl.draw_colored_polygon(shoulders, pal["light"])
		## 3) Комір — V-подібний вирізок
		var neck_w: float = maxf(size * 0.04, 1.0)
		ctrl.draw_line(Vector2(size * 0.38, size * 0.20),
			Vector2(size * 0.50, size * 0.35), pal["dark"], neck_w, true)
		ctrl.draw_line(Vector2(size * 0.62, size * 0.20),
			Vector2(size * 0.50, size * 0.35), pal["dark"], neck_w, true)
		## 4) Глянець на плечі — ширший
		ctrl.draw_rect(Rect2(size * 0.30, size * 0.22, size * 0.40, size * 0.10),
			Color(1, 1, 1, 0.18), true)
		## 5) Мікро-деталь: блискітки + шви
		var sparkle_r: float = maxf(size * 0.018, 1.0)
		ctrl.draw_circle(Vector2(size * 0.36, size * 0.28), sparkle_r,
			Color(1, 1, 1, 0.50))
		ctrl.draw_circle(Vector2(size * 0.64, size * 0.55), sparkle_r * 0.7,
			Color(1, 1, 1, 0.30))
	)
	return ctrl


## Gift — Подарунок — коробка + стрічка + бантик.
static func gift_box(size: float = 24.0, color: Color = Color("ff6b6b")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var ribbon: Color = Color("FFD166")
		var ribbon_pal: Dictionary = _color_palette(ribbon)
		var w: float = maxf(size * 0.06, 1.0)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.60), size * 0.35)
		## 2) Коробка — градієнт (верх світліший)
		ctrl.draw_rect(Rect2(size * 0.15, size * 0.40, size * 0.70, size * 0.50), pal["dark"], true)
		ctrl.draw_rect(Rect2(size * 0.15, size * 0.40, size * 0.70, size * 0.25), pal["base"], true)
		## Кришка — з бліком
		ctrl.draw_rect(Rect2(size * 0.12, size * 0.32, size * 0.76, size * 0.12), pal["light"], true)
		## 3) Стрічка вертикальна — з тіньовою стороною
		ctrl.draw_line(Vector2(size * 0.50, size * 0.32),
			Vector2(size * 0.50, size * 0.90), ribbon_pal["dark"], w * 1.8, true)
		ctrl.draw_line(Vector2(size * 0.50, size * 0.32),
			Vector2(size * 0.50, size * 0.90), ribbon_pal["base"], w * 1.2, true)
		## Стрічка горизонтальна
		ctrl.draw_line(Vector2(size * 0.15, size * 0.60),
			Vector2(size * 0.85, size * 0.60), ribbon_pal["dark"], w * 1.8, true)
		ctrl.draw_line(Vector2(size * 0.15, size * 0.60),
			Vector2(size * 0.85, size * 0.60), ribbon_pal["base"], w * 1.2, true)
		## Бантик — з градієнтом та глянцем
		_draw_radial_gradient(ctrl, Vector2(size * 0.42, size * 0.25), size * 0.07,
			ribbon_pal["lighter"], ribbon_pal["base"], 4)
		_draw_radial_gradient(ctrl, Vector2(size * 0.58, size * 0.25), size * 0.07,
			ribbon_pal["lighter"], ribbon_pal["base"], 4)
		## Вузлик банту
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.25), size * 0.03,
			ribbon_pal["darker"])
		## 4) Глянцевий блік на коробці
		ctrl.draw_rect(Rect2(size * 0.18, size * 0.42, size * 0.28, size * 0.08),
			Color(1, 1, 1, 0.18), true)
		## 5) Мікро-деталь: блискітки
		var sparkle_r: float = maxf(size * 0.018, 1.0)
		ctrl.draw_circle(Vector2(size * 0.30, size * 0.50), sparkle_r,
			Color(1, 1, 1, 0.50))
		ctrl.draw_circle(Vector2(size * 0.72, size * 0.68), sparkle_r * 0.8,
			Color(1, 1, 1, 0.35))
	)
	return ctrl


## Sleepy — Сонне обличчя — коло + закриті очі + Zzz.
static func sleepy_face(size: float = 24.0, color: Color = Color("b8c0cc")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var cx: float = size * 0.5
		var cy: float = size * 0.5
		## Обличчя
		ctrl.draw_circle(Vector2(cx, cy), size * 0.40, color)
		## Закриті очі — дуги
		var w: float = maxf(size * 0.05, 1.0)
		var ec: Color = Color(0.2, 0.2, 0.3)
		ctrl.draw_arc(Vector2(cx - size * 0.14, cy - size * 0.05),
			size * 0.08, PI, 0, 8, ec, w, true)
		ctrl.draw_arc(Vector2(cx + size * 0.14, cy - size * 0.05),
			size * 0.08, PI, 0, 8, ec, w, true)
		## Рот — маленька дуга
		ctrl.draw_arc(Vector2(cx, cy + size * 0.12),
			size * 0.08, 0.2, PI - 0.2, 8, ec, w * 0.8, true)
		## Zzz
		var zc: Color = Color("a78bfa")
		ctrl.draw_line(Vector2(size * 0.68, size * 0.12),
			Vector2(size * 0.82, size * 0.12), zc, w, true)
		ctrl.draw_line(Vector2(size * 0.82, size * 0.12),
			Vector2(size * 0.68, size * 0.22), zc, w, true)
		ctrl.draw_line(Vector2(size * 0.68, size * 0.22),
			Vector2(size * 0.82, size * 0.22), zc, w, true)
	)
	return ctrl


## Hand — Відкрита долоня — 5 пальців.
static func open_hand(size: float = 24.0, color: Color = Color.WHITE) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		## Долоня
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.58), size * 0.25, color)
		## П'ять пальців — прямокутники з закругленням
		var fw: float = size * 0.10
		var fh: float = size * 0.22
		var _angles: Array[float] = [-0.45, -0.2, 0.0, 0.2, 0.45]
		var offsets: Array[float] = [0.24, 0.32, 0.35, 0.32, 0.24]
		for i: int in 5:
			var ox: float = size * (0.25 + float(i) * 0.125)
			var oy: float = size * offsets[i]
			ctrl.draw_rect(Rect2(ox - fw * 0.5, oy - fh, fw, fh), color, true)
			ctrl.draw_circle(Vector2(ox, oy - fh), fw * 0.5, color)
	)
	return ctrl


## Flag — Прапорець — палка + яскравий прапор з шаховим візерунком.
static func flag(size: float = 24.0, color: Color = Color("22c55e")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.06, 1.0)
		var pole_col: Color = Color("8B6914")
		var pole_pal: Dictionary = _color_palette(pole_col)
		## 1) М'яка тінь під прапором
		ctrl.draw_rect(Rect2(size * 0.30, size * 0.15, size * 0.52, size * 0.35),
			Color(0, 0, 0, 0.12), true)
		## 2) Палка — з деревним градієнтом
		ctrl.draw_line(Vector2(size * 0.25, size * 0.10),
			Vector2(size * 0.25, size * 0.90), pole_pal.dark, w * 1.8, true)
		ctrl.draw_line(Vector2(size * 0.24, size * 0.10),
			Vector2(size * 0.24, size * 0.90), pole_pal.base, w * 0.8, true)
		## Текстура деревини — горизонтальні штрихи
		for gi: int in 5:
			var gy: float = size * (0.20 + float(gi) * 0.14)
			ctrl.draw_line(Vector2(size * 0.22, gy), Vector2(size * 0.28, gy),
				Color(pole_pal.darker, 0.3), maxf(w * 0.3, 0.5), true)
		## Кулька на верхівці — з глянцем
		var ball_c: Vector2 = Vector2(size * 0.25, size * 0.10)
		ctrl.draw_circle(ball_c, size * 0.045, Color("FFD166"))
		ctrl.draw_circle(ball_c + Vector2(-size * 0.01, -size * 0.01),
			maxf(size * 0.015, 1.0), Color(1, 1, 1, 0.5))
		## 3) Прапор — основа
		ctrl.draw_rect(Rect2(size * 0.28, size * 0.12, size * 0.52, size * 0.35),
			pal.base, true)
		## Шахова клітинка — темніша версія
		ctrl.draw_rect(Rect2(size * 0.28, size * 0.12, size * 0.26, size * 0.175), pal.dark, true)
		ctrl.draw_rect(Rect2(size * 0.54, size * 0.295, size * 0.26, size * 0.175), pal.dark, true)
		## 4) Хвиляста світла смуга (wave highlight)
		ctrl.draw_rect(Rect2(size * 0.28, size * 0.22, size * 0.52, size * 0.06),
			Color(1, 1, 1, 0.18), true)
		## Глянець на верхній частині прапора
		ctrl.draw_rect(Rect2(size * 0.28, size * 0.12, size * 0.52, size * 0.06),
			Color(1, 1, 1, 0.12), true)
		## 5) Контур прапора
		ctrl.draw_rect(Rect2(size * 0.28, size * 0.12, size * 0.52, size * 0.35),
			pal.darker, false, maxf(w * 0.4, 1.0))
	)
	return ctrl


## PineTree — Ялинка — трикутна крона + стовбур.
static func pine_tree(size: float = 24.0, color: Color = Color("22c55e")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var trunk_c: Color = Color("8B6914")
		var trunk_pal: Dictionary = _color_palette(trunk_c)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.55), size * 0.32)
		## Стовбур — з градієнтом
		ctrl.draw_rect(Rect2(size * 0.42, size * 0.68, size * 0.16, size * 0.24),
			trunk_pal["dark"], true)
		ctrl.draw_rect(Rect2(size * 0.44, size * 0.68, size * 0.06, size * 0.24),
			trunk_pal["light"], true)
		## 2) Нижній ярус — найширший, темніший
		var t3: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.50, size * 0.32),
			Vector2(size * 0.85, size * 0.72),
			Vector2(size * 0.15, size * 0.72),
		])
		ctrl.draw_colored_polygon(t3, pal["dark"])
		## Середній ярус
		var t2: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.50, size * 0.18),
			Vector2(size * 0.76, size * 0.55),
			Vector2(size * 0.24, size * 0.55),
		])
		ctrl.draw_colored_polygon(t2, pal["base"])
		## Верхній ярус — найсвітліший
		var t1: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.50, size * 0.06),
			Vector2(size * 0.68, size * 0.38),
			Vector2(size * 0.32, size * 0.38),
		])
		ctrl.draw_colored_polygon(t1, pal["light"])
		## 3) Внутрішні бліки на ярусах
		var t1_hl: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.50, size * 0.06),
			Vector2(size * 0.58, size * 0.22),
			Vector2(size * 0.40, size * 0.22),
		])
		ctrl.draw_colored_polygon(t1_hl, pal["lighter"])
		## 4) Глянцевий блік на верхівці
		ctrl.draw_circle(Vector2(size * 0.46, size * 0.18), size * 0.04,
			Color(1, 1, 1, 0.30))
		## 5) Мікро-деталь: снігові блискітки
		var sparkle_r: float = maxf(size * 0.02, 1.0)
		ctrl.draw_circle(Vector2(size * 0.38, size * 0.32), sparkle_r,
			Color(1, 1, 1, 0.55))
		ctrl.draw_circle(Vector2(size * 0.60, size * 0.50), sparkle_r * 0.8,
			Color(1, 1, 1, 0.40))
		ctrl.draw_circle(Vector2(size * 0.32, size * 0.60), sparkle_r * 0.7,
			Color(1, 1, 1, 0.30))
	)
	return ctrl


## PalmTree — Пальма — стовбур + листки.
static func palm_tree(size: float = 24.0, color: Color = Color("22c55e")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.06, 1.5)
		var trunk_c: Color = Color("8B6914")
		var trunk_pal: Dictionary = _color_palette(trunk_c)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.55), size * 0.30)
		## 2) Стовбур — з градієнтом
		ctrl.draw_line(Vector2(size * 0.49, size * 0.40),
			Vector2(size * 0.51, size * 0.90), trunk_pal["darker"], w * 2.5, true)
		ctrl.draw_line(Vector2(size * 0.48, size * 0.40),
			Vector2(size * 0.50, size * 0.90), trunk_pal["base"], w * 2, true)
		ctrl.draw_line(Vector2(size * 0.47, size * 0.42),
			Vector2(size * 0.49, size * 0.88), trunk_pal["light"], w * 0.8, true)
		## 3) Листки — з градієнтом (темна основа, світлий кінець)
		var top: Vector2 = Vector2(size * 0.48, size * 0.38)
		ctrl.draw_line(top, Vector2(size * 0.15, size * 0.25), pal["dark"], w * 2.0, true)
		ctrl.draw_line(top, Vector2(size * 0.15, size * 0.25), pal["base"], w * 1.2, true)
		ctrl.draw_line(top, Vector2(size * 0.82, size * 0.20), pal["dark"], w * 2.0, true)
		ctrl.draw_line(top, Vector2(size * 0.82, size * 0.20), pal["base"], w * 1.2, true)
		ctrl.draw_line(top, Vector2(size * 0.10, size * 0.50), pal["dark"], w * 1.6, true)
		ctrl.draw_line(top, Vector2(size * 0.10, size * 0.50), pal["light"], w * 0.9, true)
		ctrl.draw_line(top, Vector2(size * 0.85, size * 0.45), pal["dark"], w * 1.6, true)
		ctrl.draw_line(top, Vector2(size * 0.85, size * 0.45), pal["light"], w * 0.9, true)
		## 4) Кокоси — з глянцем
		_draw_radial_gradient(ctrl, Vector2(size * 0.45, size * 0.42), size * 0.04,
			trunk_pal["light"], trunk_pal["dark"], 3)
		_draw_radial_gradient(ctrl, Vector2(size * 0.52, size * 0.40), size * 0.04,
			trunk_pal["light"], trunk_pal["dark"], 3)
		## 5) Мікро-деталь: блискітки на листках
		var sparkle_r: float = maxf(size * 0.018, 1.0)
		ctrl.draw_circle(Vector2(size * 0.25, size * 0.30), sparkle_r,
			Color(1, 1, 1, 0.45))
		ctrl.draw_circle(Vector2(size * 0.75, size * 0.28), sparkle_r * 0.8,
			Color(1, 1, 1, 0.35))
	)
	return ctrl


## Drum — Барабан — циліндр + палички.
static func drum(size: float = 24.0, color: Color = Color("f97316")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.05, 1.0)
		var cx: float = size * 0.50
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(cx, size * 0.55), size * 0.32)
		## 2) Корпус — градієнт зверху-вниз
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.30, size * 0.60, size * 0.45), pal["dark"], true)
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.30, size * 0.60, size * 0.22), pal["base"], true)
		## Верхній овал — світліший
		ctrl.draw_arc(Vector2(cx, size * 0.30), size * 0.30,
			PI, 0, 12, pal["light"], w * 1.5, true)
		ctrl.draw_line(Vector2(size * 0.20, size * 0.30),
			Vector2(size * 0.80, size * 0.30), pal["light"], w, true)
		## Нижній овал — темніший
		ctrl.draw_arc(Vector2(cx, size * 0.75), size * 0.30,
			0, PI, 12, pal["darker"], w, true)
		## 3) Палички — кремові з глянцем
		var stick_c: Color = Color("f5f0e0")
		ctrl.draw_line(Vector2(size * 0.30, size * 0.12),
			Vector2(size * 0.55, size * 0.35), stick_c, w, true)
		ctrl.draw_line(Vector2(size * 0.70, size * 0.12),
			Vector2(size * 0.45, size * 0.35), stick_c, w, true)
		## Кінчики паличок
		ctrl.draw_circle(Vector2(size * 0.30, size * 0.12), size * 0.03, Color.WHITE)
		ctrl.draw_circle(Vector2(size * 0.70, size * 0.12), size * 0.03, Color.WHITE)
		## 4) Глянцевий блік на корпусі
		ctrl.draw_rect(Rect2(size * 0.24, size * 0.32, size * 0.28, size * 0.10),
			Color(1, 1, 1, 0.18), true)
		## 5) Мікро-деталь: блискітки
		var sparkle_r: float = maxf(size * 0.018, 1.0)
		ctrl.draw_circle(Vector2(size * 0.34, size * 0.40), sparkle_r,
			Color(1, 1, 1, 0.45))
		ctrl.draw_circle(Vector2(size * 0.62, size * 0.50), sparkle_r * 0.8,
			Color(1, 1, 1, 0.30))
	)
	return ctrl


## Guitar — Гітара — корпус-8 + гриф.
static func guitar(size: float = 24.0, color: Color = Color("f97316")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.60), size * 0.26)
		## 2) Корпус — два кола з градієнтом
		_draw_radial_gradient(ctrl, Vector2(size * 0.50, size * 0.68), size * 0.22,
			pal["light"], pal["dark"], 5)
		_draw_radial_gradient(ctrl, Vector2(size * 0.50, size * 0.52), size * 0.16,
			pal["light"], pal["base"], 4)
		## Гриф — градієнт
		ctrl.draw_rect(Rect2(size * 0.46, size * 0.10, size * 0.08, size * 0.40),
			pal["darker"], true)
		ctrl.draw_rect(Rect2(size * 0.47, size * 0.10, size * 0.04, size * 0.40),
			pal["dark"], true)
		## Головка
		ctrl.draw_rect(Rect2(size * 0.43, size * 0.06, size * 0.14, size * 0.08),
			pal["darker"], true)
		## Струнний отвір — градієнт
		_draw_radial_gradient(ctrl, Vector2(size * 0.50, size * 0.68), size * 0.07,
			Color(0, 0, 0, 0.15), Color(0, 0, 0, 0.40), 4)
		## 3) Контур корпусу
		_draw_outline(ctrl, Vector2(size * 0.50, size * 0.68), size * 0.22,
			pal["darker"], maxf(size * 0.025, 1.0))
		## 4) Глянцевий блік
		_draw_gloss(ctrl, Vector2(size * 0.50, size * 0.60), size * 0.20, 0.28)
		## 5) Мікро-деталь: блискітки
		var sparkle_r: float = maxf(size * 0.018, 1.0)
		ctrl.draw_circle(Vector2(size * 0.40, size * 0.58), sparkle_r,
			Color(1, 1, 1, 0.45))
		ctrl.draw_circle(Vector2(size * 0.56, size * 0.78), sparkle_r * 0.7,
			Color(1, 1, 1, 0.30))
	)
	return ctrl


## Trumpet — Труба — конічна труба + розтруб.
static func trumpet(size: float = 24.0, color: Color = Color("FFD166")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.05, 1.0)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.55, size * 0.50), size * 0.30)
		## 2) Трубка — з градієнтом (тінь + основна + блік)
		ctrl.draw_line(Vector2(size * 0.15, size * 0.52),
			Vector2(size * 0.60, size * 0.52), pal["darker"], w * 3.5, true)
		ctrl.draw_line(Vector2(size * 0.15, size * 0.50),
			Vector2(size * 0.60, size * 0.50), pal["base"], w * 3, true)
		ctrl.draw_line(Vector2(size * 0.15, size * 0.48),
			Vector2(size * 0.60, size * 0.48), pal["light"], w * 1.5, true)
		## Розтруб — з градієнтом
		var bell_s: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.59, size * 0.36),
			Vector2(size * 0.89, size * 0.26),
			Vector2(size * 0.89, size * 0.76),
			Vector2(size * 0.59, size * 0.66),
		])
		ctrl.draw_colored_polygon(bell_s, pal["darker"])
		var bell: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.58, size * 0.35),
			Vector2(size * 0.88, size * 0.25),
			Vector2(size * 0.88, size * 0.75),
			Vector2(size * 0.58, size * 0.65),
		])
		ctrl.draw_colored_polygon(bell, pal["base"])
		## Верхня половина розтрубу — світліша
		var bell_hl: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.58, size * 0.35),
			Vector2(size * 0.88, size * 0.25),
			Vector2(size * 0.88, size * 0.50),
			Vector2(size * 0.58, size * 0.50),
		])
		ctrl.draw_colored_polygon(bell_hl, pal["light"])
		## 3) Клапани — з глянцем
		_draw_radial_gradient(ctrl, Vector2(size * 0.30, size * 0.42), size * 0.04,
			pal["lighter"], pal["base"], 3)
		_draw_radial_gradient(ctrl, Vector2(size * 0.40, size * 0.42), size * 0.04,
			pal["lighter"], pal["base"], 3)
		_draw_radial_gradient(ctrl, Vector2(size * 0.50, size * 0.42), size * 0.04,
			pal["lighter"], pal["base"], 3)
		## 4) Глянцевий блік на розтрубі
		ctrl.draw_circle(Vector2(size * 0.78, size * 0.38), size * 0.04,
			Color(1, 1, 1, 0.30))
		## 5) Мікро-деталь: блискітки
		var sparkle_r: float = maxf(size * 0.018, 1.0)
		ctrl.draw_circle(Vector2(size * 0.72, size * 0.32), sparkle_r,
			Color(1, 1, 1, 0.50))
		ctrl.draw_circle(Vector2(size * 0.82, size * 0.55), sparkle_r * 0.7,
			Color(1, 1, 1, 0.35))
	)
	return ctrl


## Mic — Мікрофон — сфера + стійка.
static func microphone(size: float = 24.0, color: Color = Color("b8c0cc")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.06, 1.0)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.28), size * 0.22)
		## 2) Голівка — радіальний градієнт
		_draw_radial_gradient(ctrl, Vector2(size * 0.50, size * 0.28), size * 0.20,
			pal["lighter"], pal["dark"], 5)
		## Сітка — трохи темніша
		var gc: Color = pal["darker"]
		ctrl.draw_line(Vector2(size * 0.38, size * 0.22),
			Vector2(size * 0.62, size * 0.22), gc, w * 0.5, true)
		ctrl.draw_line(Vector2(size * 0.35, size * 0.30),
			Vector2(size * 0.65, size * 0.30), gc, w * 0.5, true)
		## 3) Контур голівки
		_draw_outline(ctrl, Vector2(size * 0.50, size * 0.28), size * 0.20,
			pal["darker"], maxf(size * 0.025, 1.0))
		## 4) Глянцевий блік
		_draw_gloss(ctrl, Vector2(size * 0.50, size * 0.28), size * 0.20, 0.32)
		## Стійка — з градієнтом
		ctrl.draw_line(Vector2(size * 0.50, size * 0.48),
			Vector2(size * 0.50, size * 0.78), pal["dark"], w * 1.5, true)
		ctrl.draw_line(Vector2(size * 0.50, size * 0.48),
			Vector2(size * 0.50, size * 0.62), pal["light"], w * 0.8, true)
		## Підставка
		ctrl.draw_line(Vector2(size * 0.35, size * 0.82),
			Vector2(size * 0.65, size * 0.82), pal["base"], w * 1.5, true)
		## 5) Мікро-деталь: блискітки
		var sparkle_r: float = maxf(size * 0.018, 1.0)
		ctrl.draw_circle(Vector2(size * 0.42, size * 0.20), sparkle_r,
			Color(1, 1, 1, 0.50))
		ctrl.draw_circle(Vector2(size * 0.56, size * 0.34), sparkle_r * 0.7,
			Color(1, 1, 1, 0.30))
	)
	return ctrl


## Sun — Сонце — коло + промені.
static func sun_icon(size: float = 24.0, color: Color = Color("FFD166")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.5
		var center: Vector2 = Vector2(cx, cy)
		var w: float = maxf(size * 0.06, 1.0)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, center, size * 0.22, Color(0, 0, 0, 0.12))
		## 2) 8 променів — з кінчиковими бліками
		for i: int in 8:
			var angle: float = float(i) * PI / 4.0
			var inner_r: float = size * 0.28
			var outer_r: float = size * 0.42
			var tip_pos: Vector2 = Vector2(cx + cos(angle) * outer_r, cy + sin(angle) * outer_r)
			ctrl.draw_line(
				Vector2(cx + cos(angle) * inner_r, cy + sin(angle) * inner_r),
				tip_pos, pal.base, w, true)
			## Кінчик променя — світліша крапка
			ctrl.draw_circle(tip_pos, maxf(w * 0.8, 1.0), pal.lighter)
		## 3) 4-кільцевий градієнт ядра
		_draw_radial_gradient(ctrl, center, size * 0.22, pal.lighter, pal.dark, 6)
		## 4) Глянцевий блік на ядрі
		_draw_gloss(ctrl, center, size * 0.22, 0.30)
		## 5) Мікро-деталі — heat shimmer dots
		ctrl.draw_circle(Vector2(cx - size * 0.06, cy + size * 0.30),
			maxf(size * 0.015, 1.0), Color(pal.lighter, 0.35))
		ctrl.draw_circle(Vector2(cx + size * 0.10, cy + size * 0.32),
			maxf(size * 0.012, 1.0), Color(pal.lighter, 0.25))
		ctrl.draw_circle(Vector2(cx + size * 0.02, cy - size * 0.33),
			maxf(size * 0.010, 1.0), Color(pal.lighter, 0.20))
		## Контур ядра
		_draw_outline(ctrl, center, size * 0.22, pal.dark, maxf(w * 0.5, 1.0))
	)
	return ctrl


## Rain — Дощ — хмара + краплі з premium pipeline.
static func rain_icon(size: float = 24.0, color: Color = Color("93c5fd")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## 1) Тінь хмари
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.34), size * 0.22)
		## 2) Хмара — dark база + light верх
		ctrl.draw_circle(Vector2(size * 0.35, size * 0.32), size * 0.15, pal["dark"])
		ctrl.draw_circle(Vector2(size * 0.55, size * 0.28), size * 0.18, pal["dark"])
		ctrl.draw_circle(Vector2(size * 0.70, size * 0.34), size * 0.12, pal["dark"])
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.32, size * 0.58, size * 0.12), pal["dark"], true)
		## 3) Світліший верх — градієнт
		ctrl.draw_circle(Vector2(size * 0.55, size * 0.26), size * 0.12, pal["light"])
		## 4) Краплі з палітрою
		var w: float = maxf(size * 0.05, 1.0)
		var dc: Color = Color("3b82f6")
		var dc_pal: Dictionary = _color_palette(dc)
		ctrl.draw_line(Vector2(size * 0.30, size * 0.55),
			Vector2(size * 0.25, size * 0.72), dc_pal["dark"], w, true)
		ctrl.draw_line(Vector2(size * 0.50, size * 0.55),
			Vector2(size * 0.45, size * 0.72), dc_pal["dark"], w, true)
		ctrl.draw_line(Vector2(size * 0.70, size * 0.55),
			Vector2(size * 0.65, size * 0.72), dc_pal["dark"], w, true)
		## 5) Sparkle
		ctrl.draw_circle(Vector2(size * 0.42, size * 0.24), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


## Snowflake — Сніжинка з premium pipeline.
static func snowflake(size: float = 24.0, color: Color = Color("93c5fd")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.5
		var r: float = size * 0.38
		var w: float = maxf(size * 0.06, 1.0)
		## 1) Тінь — зсунуті лінії
		var sh: Vector2 = Vector2(maxf(size * 0.03, 1.0), maxf(size * 0.05, 1.5))
		for i: int in 3:
			var angle: float = float(i) * PI / 3.0
			ctrl.draw_line(
				Vector2(cx + cos(angle) * r + sh.x, cy + sin(angle) * r + sh.y),
				Vector2(cx - cos(angle) * r + sh.x, cy - sin(angle) * r + sh.y),
				Color(0, 0, 0, 0.15), w, true)
		## 2) Основні промені — dark
		for i: int in 3:
			var angle: float = float(i) * PI / 3.0
			ctrl.draw_line(
				Vector2(cx + cos(angle) * r, cy + sin(angle) * r),
				Vector2(cx - cos(angle) * r, cy - sin(angle) * r),
				pal["dark"], w, true)
		## 3) Тонші промені — light overlay
		for i: int in 3:
			var angle: float = float(i) * PI / 3.0
			ctrl.draw_line(
				Vector2(cx + cos(angle) * r, cy + sin(angle) * r),
				Vector2(cx - cos(angle) * r, cy - sin(angle) * r),
				pal["light"], maxf(w * 0.45, 1.0), true)
		## 4) Крапки на кінцях — lighter
		for i: int in 6:
			var angle: float = float(i) * PI / 3.0
			ctrl.draw_circle(
				Vector2(cx + cos(angle) * r, cy + sin(angle) * r),
				size * 0.04, pal["lighter"])
		## 5) Центральний sparkle
		ctrl.draw_circle(Vector2(cx, cy), maxf(size * 0.03, 1.0), Color(1, 1, 1, 0.50))
	)
	return ctrl


## Cloud — Хмара з premium pipeline.
static func cloud_icon(size: float = 24.0, color: Color = Color("b8c0cc")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## 1) Тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.46), size * 0.24)
		## 2) Хмара — dark база
		ctrl.draw_circle(Vector2(size * 0.35, size * 0.45), size * 0.18, pal["dark"])
		ctrl.draw_circle(Vector2(size * 0.55, size * 0.38), size * 0.22, pal["dark"])
		ctrl.draw_circle(Vector2(size * 0.72, size * 0.46), size * 0.14, pal["dark"])
		ctrl.draw_rect(Rect2(size * 0.17, size * 0.46, size * 0.66, size * 0.18), pal["dark"], true)
		## 3) Світліший верх — градієнт
		ctrl.draw_circle(Vector2(size * 0.55, size * 0.36), size * 0.14, pal["light"])
		ctrl.draw_circle(Vector2(size * 0.35, size * 0.42), size * 0.10, pal["light"])
		## 4) Sparkle
		ctrl.draw_circle(Vector2(size * 0.42, size * 0.34), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


## Storm — Гроза з premium pipeline.
static func storm_icon(size: float = 24.0, color: Color = Color("64748b")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## 1) Тінь хмари
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.32), size * 0.22)
		## 2) Хмара — dark
		ctrl.draw_circle(Vector2(size * 0.35, size * 0.30), size * 0.15, pal["dark"])
		ctrl.draw_circle(Vector2(size * 0.55, size * 0.25), size * 0.18, pal["dark"])
		ctrl.draw_circle(Vector2(size * 0.70, size * 0.32), size * 0.12, pal["dark"])
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.30, size * 0.55, size * 0.12), pal["dark"], true)
		## 3) Світліший верх хмари
		ctrl.draw_circle(Vector2(size * 0.55, size * 0.23), size * 0.11, pal["light"])
		## 4) Блискавка — smooth multi-segment з glow
		var bolt_c: Color = Color("FFD166")
		var bolt_w: float = maxf(size * 0.06, 2.0)
		var bolt_pts: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.50, size * 0.42),
			Vector2(size * 0.44, size * 0.54),
			Vector2(size * 0.54, size * 0.52),
			Vector2(size * 0.42, size * 0.68),
			Vector2(size * 0.55, size * 0.64),
			Vector2(size * 0.45, size * 0.82),
		])
		## Зовнішнє glow (широкий напівпрозорий)
		for i: int in range(bolt_pts.size() - 1):
			ctrl.draw_line(bolt_pts[i], bolt_pts[i + 1],
				Color(bolt_c, 0.2), bolt_w * 3.5, true)
		## Середній glow
		for i: int in range(bolt_pts.size() - 1):
			ctrl.draw_line(bolt_pts[i], bolt_pts[i + 1],
				Color(bolt_c, 0.45), bolt_w * 2.0, true)
		## Основна лінія
		for i: int in range(bolt_pts.size() - 1):
			ctrl.draw_line(bolt_pts[i], bolt_pts[i + 1],
				bolt_c, bolt_w, true)
		## Яскраве ядро (білий центр)
		for i: int in range(bolt_pts.size() - 1):
			ctrl.draw_line(bolt_pts[i], bolt_pts[i + 1],
				Color(1, 1, 0.9, 0.8), bolt_w * 0.4, true)
		## 5) Sparkle на точках зламу
		for pt: Vector2 in bolt_pts:
			ctrl.draw_circle(pt, maxf(size * 0.015, 0.8),
				Color(1, 1, 1, 0.5))
	)
	return ctrl


## Wind — Вітер з premium pipeline.
static func wind_icon(size: float = 24.0, color: Color = Color("93c5fd")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.06, 1.0)
		## 1) Тіні ліній
		var sh: Vector2 = Vector2(maxf(size * 0.03, 1.0), maxf(size * 0.04, 1.0))
		ctrl.draw_line(Vector2(size * 0.15 + sh.x, size * 0.35 + sh.y),
			Vector2(size * 0.75 + sh.x, size * 0.35 + sh.y), Color(0, 0, 0, 0.12), w, true)
		ctrl.draw_line(Vector2(size * 0.20 + sh.x, size * 0.50 + sh.y),
			Vector2(size * 0.82 + sh.x, size * 0.50 + sh.y), Color(0, 0, 0, 0.12), w, true)
		ctrl.draw_line(Vector2(size * 0.25 + sh.x, size * 0.65 + sh.y),
			Vector2(size * 0.68 + sh.x, size * 0.65 + sh.y), Color(0, 0, 0, 0.12), w, true)
		## 2) Основні лінії — dark
		ctrl.draw_line(Vector2(size * 0.15, size * 0.35),
			Vector2(size * 0.75, size * 0.35), pal["dark"], w, true)
		ctrl.draw_arc(Vector2(size * 0.75, size * 0.30), size * 0.05,
			PI * 0.5, -PI * 0.5, 8, pal["dark"], w, true)
		ctrl.draw_line(Vector2(size * 0.20, size * 0.50),
			Vector2(size * 0.82, size * 0.50), pal["dark"], w, true)
		ctrl.draw_arc(Vector2(size * 0.82, size * 0.45), size * 0.05,
			PI * 0.5, -PI * 0.5, 8, pal["dark"], w, true)
		ctrl.draw_line(Vector2(size * 0.25, size * 0.65),
			Vector2(size * 0.68, size * 0.65), pal["dark"], w, true)
		ctrl.draw_arc(Vector2(size * 0.68, size * 0.60), size * 0.05,
			PI * 0.5, -PI * 0.5, 8, pal["dark"], w, true)
		## 3) Тонші лінії lighter зверху
		ctrl.draw_line(Vector2(size * 0.15, size * 0.35),
			Vector2(size * 0.75, size * 0.35), pal["light"], maxf(w * 0.4, 1.0), true)
		ctrl.draw_line(Vector2(size * 0.20, size * 0.50),
			Vector2(size * 0.82, size * 0.50), pal["light"], maxf(w * 0.4, 1.0), true)
		ctrl.draw_line(Vector2(size * 0.25, size * 0.65),
			Vector2(size * 0.68, size * 0.65), pal["light"], maxf(w * 0.4, 1.0), true)
		## 4) Sparkle
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.42), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.40))
	)
	return ctrl


## Clothing icons: Окуляри, Кепка, Шорти, Шарф, Рукавички,
## Чоботи, Парасолька, Дощовик, Пальто, Куртка.
## Кожен — спрощений candy-стиль для розпізнавання дітьми.

static func sunglasses_icon(size: float = 24.0, color: Color = Color("1e293b")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.06, 1.0)
		## 1) Тіні лінз
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.50), size * 0.20)
		## 2) Лінзи — dark + глянц
		ctrl.draw_circle(Vector2(size * 0.32, size * 0.50), size * 0.16, pal["dark"])
		ctrl.draw_circle(Vector2(size * 0.68, size * 0.50), size * 0.16, pal["dark"])
		## 3) Блік на лінзах
		ctrl.draw_circle(Vector2(size * 0.28, size * 0.45), size * 0.06, pal["light"])
		ctrl.draw_circle(Vector2(size * 0.64, size * 0.45), size * 0.06, pal["light"])
		## 4) Міст + дужки
		ctrl.draw_line(Vector2(size * 0.42, size * 0.46),
			Vector2(size * 0.58, size * 0.46), pal["base"], w, true)
		ctrl.draw_line(Vector2(size * 0.16, size * 0.46),
			Vector2(size * 0.08, size * 0.40), pal["base"], w, true)
		ctrl.draw_line(Vector2(size * 0.84, size * 0.46),
			Vector2(size * 0.92, size * 0.40), pal["base"], w, true)
		## 5) Sparkle
		ctrl.draw_circle(Vector2(size * 0.26, size * 0.42), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.50))
	)
	return ctrl


static func cap_icon(size: float = 24.0, color: Color = Color("3b82f6")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## 1) Тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.48), size * 0.30)
		## 2) Купол — dark
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.42), size * 0.28, pal["dark"])
		ctrl.draw_rect(Rect2(size * 0.22, size * 0.42, size * 0.56, size * 0.16), pal["dark"], true)
		## 3) Блік на куполі
		ctrl.draw_circle(Vector2(size * 0.42, size * 0.36), size * 0.12, pal["light"])
		## 4) Козирок — darker
		ctrl.draw_rect(Rect2(size * 0.12, size * 0.55, size * 0.76, size * 0.10),
			pal["darker"], true)
		## 5) Sparkle
		ctrl.draw_circle(Vector2(size * 0.38, size * 0.34), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


static func shorts_icon(size: float = 24.0, color: Color = Color("93c5fd")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var body: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.18, size * 0.25),
			Vector2(size * 0.82, size * 0.25),
			Vector2(size * 0.82, size * 0.50),
			Vector2(size * 0.62, size * 0.75),
			Vector2(size * 0.52, size * 0.50),
			Vector2(size * 0.48, size * 0.50),
			Vector2(size * 0.38, size * 0.75),
			Vector2(size * 0.18, size * 0.50),
		])
		## 1) Тінь
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		var shadow_body: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in body:
			shadow_body.append(p + sh)
		ctrl.draw_colored_polygon(shadow_body, Color(0, 0, 0, 0.18))
		## 2) Основа — dark
		ctrl.draw_colored_polygon(body, pal["dark"])
		## 3) Градієнт — верхня частина lighter
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.26, size * 0.60, size * 0.12), pal["light"], true)
		## 4) Контур
		ctrl.draw_polyline(body + PackedVector2Array([body[0]]), pal["darker"],
			maxf(size * 0.03, 1.0), true)
		## 5) Sparkle
		ctrl.draw_circle(Vector2(size * 0.35, size * 0.32), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.40))
	)
	return ctrl


static func scarf_icon(size: float = 24.0, color: Color = Color("ef476f")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## 1) Тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.55, size * 0.50), size * 0.25)
		## 2) Обмотка — dark
		ctrl.draw_rect(Rect2(size * 0.18, size * 0.30, size * 0.64, size * 0.14), pal["dark"], true)
		## 3) Кінець 1 — dark
		ctrl.draw_rect(Rect2(size * 0.65, size * 0.44, size * 0.15, size * 0.40), pal["dark"], true)
		## 4) Кінець 2 — darker
		ctrl.draw_rect(Rect2(size * 0.55, size * 0.44, size * 0.12, size * 0.32),
			pal["darker"], true)
		## 5) Блік на обмотці
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.31, size * 0.30, size * 0.06), pal["light"], true)
		## 6) Смужки
		var w: float = maxf(size * 0.04, 1.0)
		ctrl.draw_line(Vector2(size * 0.68, size * 0.55),
			Vector2(size * 0.78, size * 0.55), pal["lighter"], w, true)
		ctrl.draw_line(Vector2(size * 0.68, size * 0.68),
			Vector2(size * 0.78, size * 0.68), pal["lighter"], w, true)
		## 7) Sparkle
		ctrl.draw_circle(Vector2(size * 0.30, size * 0.32), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


static func mittens_icon(size: float = 24.0, color: Color = Color("93c5fd")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## 1) Тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.45, size * 0.50), size * 0.24)
		## 2) Тіло — dark
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.40), size * 0.22, pal["dark"])
		ctrl.draw_rect(Rect2(size * 0.32, size * 0.40, size * 0.36, size * 0.38), pal["dark"], true)
		## 3) Великий палець — dark
		ctrl.draw_circle(Vector2(size * 0.30, size * 0.45), size * 0.10, pal["dark"])
		## 4) Блік — lighter зверху
		ctrl.draw_circle(Vector2(size * 0.46, size * 0.35), size * 0.10, pal["light"])
		## 5) Манжета — lighter
		ctrl.draw_rect(Rect2(size * 0.30, size * 0.72, size * 0.40, size * 0.12),
			pal["lighter"], true)
		## 6) Sparkle
		ctrl.draw_circle(Vector2(size * 0.40, size * 0.32), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


static func boots_icon(size: float = 24.0, color: Color = Color("8B6914")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## 1) Тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.60), size * 0.28)
		## 2) Халява — dark
		ctrl.draw_rect(Rect2(size * 0.35, size * 0.15, size * 0.25, size * 0.45), pal["dark"], true)
		## 3) Підошва — dark
		var sole: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.28, size * 0.60),
			Vector2(size * 0.60, size * 0.60),
			Vector2(size * 0.75, size * 0.72),
			Vector2(size * 0.78, size * 0.82),
			Vector2(size * 0.22, size * 0.82),
			Vector2(size * 0.22, size * 0.72),
		])
		ctrl.draw_colored_polygon(sole, pal["dark"])
		## 4) Блік на халяві
		ctrl.draw_rect(Rect2(size * 0.37, size * 0.18, size * 0.10, size * 0.20), pal["light"], true)
		## 5) Підошва (темна) — darker
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.78, size * 0.60, size * 0.08),
			pal["darker"], true)
		## 6) Sparkle
		ctrl.draw_circle(Vector2(size * 0.40, size * 0.22), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.40))
	)
	return ctrl


static func umbrella_icon(size: float = 24.0, color: Color = Color("ef476f")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.06, 1.0)
		## 1) Тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.40), size * 0.28)
		## 2) Купол — dark
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.30), size * 0.25, pal["dark"])
		ctrl.draw_rect(Rect2(size * 0.25, size * 0.30, size * 0.50, size * 0.12), pal["dark"], true)
		## 3) Блік на куполі
		ctrl.draw_circle(Vector2(size * 0.42, size * 0.25), size * 0.10, pal["light"])
		## 4) Ручка з палітрою
		var handle_c: Color = Color("8B6914")
		var handle_pal: Dictionary = _color_palette(handle_c)
		ctrl.draw_line(Vector2(size * 0.50, size * 0.40),
			Vector2(size * 0.50, size * 0.80), handle_pal["dark"], w * 1.2, true)
		ctrl.draw_line(Vector2(size * 0.50, size * 0.40),
			Vector2(size * 0.50, size * 0.80), handle_pal["light"], maxf(w * 0.4, 1.0), true)
		## 5) Гачок
		ctrl.draw_arc(Vector2(size * 0.56, size * 0.80), size * 0.06,
			0, PI, 8, handle_pal["dark"], w, true)
		## 6) Sparkle
		ctrl.draw_circle(Vector2(size * 0.38, size * 0.22), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.50))
	)
	return ctrl


static func raincoat_icon(size: float = 24.0, color: Color = Color("fbbf24")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var body: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.32, size * 0.15),
			Vector2(size * 0.15, size * 0.30),
			Vector2(size * 0.22, size * 0.35),
			Vector2(size * 0.28, size * 0.25),
			Vector2(size * 0.28, size * 0.85),
			Vector2(size * 0.72, size * 0.85),
			Vector2(size * 0.72, size * 0.25),
			Vector2(size * 0.78, size * 0.35),
			Vector2(size * 0.85, size * 0.30),
			Vector2(size * 0.68, size * 0.15),
		])
		## 1) Тінь
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		var shadow_body: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in body:
			shadow_body.append(p + sh)
		ctrl.draw_colored_polygon(shadow_body, Color(0, 0, 0, 0.18))
		## 2) Основа — dark
		ctrl.draw_colored_polygon(body, pal["dark"])
		## 3) Блік — верхня частина
		ctrl.draw_rect(Rect2(size * 0.30, size * 0.20, size * 0.40, size * 0.15), pal["light"], true)
		## 4) Контур
		ctrl.draw_polyline(body + PackedVector2Array([body[0]]), pal["darker"],
			maxf(size * 0.03, 1.0), true)
		## 5) Ґудзики — darker
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.40), size * 0.03, pal["darker"])
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.55), size * 0.03, pal["darker"])
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.70), size * 0.03, pal["darker"])
		## 6) Sparkle
		ctrl.draw_circle(Vector2(size * 0.38, size * 0.22), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


static func coat_icon(size: float = 24.0, color: Color = Color("64748b")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var body: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.32, size * 0.12),
			Vector2(size * 0.12, size * 0.28),
			Vector2(size * 0.20, size * 0.35),
			Vector2(size * 0.28, size * 0.22),
			Vector2(size * 0.28, size * 0.88),
			Vector2(size * 0.72, size * 0.88),
			Vector2(size * 0.72, size * 0.22),
			Vector2(size * 0.80, size * 0.35),
			Vector2(size * 0.88, size * 0.28),
			Vector2(size * 0.68, size * 0.12),
		])
		## 1) Тінь
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		var shadow_body: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in body:
			shadow_body.append(p + sh)
		ctrl.draw_colored_polygon(shadow_body, Color(0, 0, 0, 0.18))
		## 2) Основа — dark
		ctrl.draw_colored_polygon(body, pal["dark"])
		## 3) Блік — верхня частина
		ctrl.draw_rect(Rect2(size * 0.30, size * 0.18, size * 0.40, size * 0.18), pal["light"], true)
		## 4) Контур
		ctrl.draw_polyline(body + PackedVector2Array([body[0]]), pal["darker"],
			maxf(size * 0.03, 1.0), true)
		## 5) Комір — lighter
		ctrl.draw_rect(Rect2(size * 0.35, size * 0.12, size * 0.30, size * 0.10), pal["lighter"], true)
		## 6) Sparkle
		ctrl.draw_circle(Vector2(size * 0.40, size * 0.20), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.40))
	)
	return ctrl


static func jacket_icon(size: float = 24.0, color: Color = Color("3b82f6")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var body: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.30, size * 0.18),
			Vector2(size * 0.14, size * 0.32),
			Vector2(size * 0.22, size * 0.38),
			Vector2(size * 0.28, size * 0.28),
			Vector2(size * 0.28, size * 0.82),
			Vector2(size * 0.72, size * 0.82),
			Vector2(size * 0.72, size * 0.28),
			Vector2(size * 0.78, size * 0.38),
			Vector2(size * 0.86, size * 0.32),
			Vector2(size * 0.70, size * 0.18),
		])
		## 1) Тінь
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.06, 1.5))
		var shadow_body: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in body:
			shadow_body.append(p + sh)
		ctrl.draw_colored_polygon(shadow_body, Color(0, 0, 0, 0.18))
		## 2) Основа — dark
		ctrl.draw_colored_polygon(body, pal["dark"])
		## 3) Блік
		ctrl.draw_rect(Rect2(size * 0.30, size * 0.22, size * 0.40, size * 0.15), pal["light"], true)
		## 4) Контур
		ctrl.draw_polyline(body + PackedVector2Array([body[0]]), pal["darker"],
			maxf(size * 0.03, 1.0), true)
		## 5) Блискавка — gold з палітрою
		var zc: Color = Color("FFD166")
		var zpal: Dictionary = _color_palette(zc)
		var w: float = maxf(size * 0.04, 1.0)
		ctrl.draw_line(Vector2(size * 0.50, size * 0.22),
			Vector2(size * 0.50, size * 0.78), zpal["dark"], w, true)
		ctrl.draw_line(Vector2(size * 0.50, size * 0.22),
			Vector2(size * 0.50, size * 0.78), zpal["light"], maxf(w * 0.4, 1.0), true)
		## 6) Sparkle
		ctrl.draw_circle(Vector2(size * 0.38, size * 0.24), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.45))
	)
	return ctrl


## ---- Catalog-Only Icons ----


static func fork_knife(size: float = 24.0, color: Color = Color("c0c0c0")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var w: float = maxf(size * 0.06, 1.0)
		var pal: Dictionary = _color_palette(color)
		var handle: Color = Color("8B6914")
		var handle_light: Color = Color("A67C1A")
		var _handle_dark: Color = Color("6B5210")
		## Тінь під приборами
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.52), size * 0.32,
			Color(0, 0, 0, 0.15))
		## Виделка — зубці з градієнтом (темніший → світліший)
		ctrl.draw_line(Vector2(size * 0.22, size * 0.15),
			Vector2(size * 0.22, size * 0.38), pal.dark, w * 1.0, true)
		ctrl.draw_line(Vector2(size * 0.30, size * 0.15),
			Vector2(size * 0.30, size * 0.38), pal.base, w * 1.0, true)
		ctrl.draw_line(Vector2(size * 0.38, size * 0.15),
			Vector2(size * 0.38, size * 0.38), pal.light, w * 1.0, true)
		## З'єднувач зубців
		ctrl.draw_rect(Rect2(size * 0.22, size * 0.36, size * 0.16, size * 0.10),
			pal.base, true)
		## Блік на з'єднувачі
		ctrl.draw_rect(Rect2(size * 0.22, size * 0.36, size * 0.16, size * 0.04),
			Color(1, 1, 1, 0.20), true)
		## Ручка виделки — градієнт дерева
		ctrl.draw_line(Vector2(size * 0.30, size * 0.46),
			Vector2(size * 0.30, size * 0.85), handle, w * 1.6, true)
		ctrl.draw_line(Vector2(size * 0.29, size * 0.48),
			Vector2(size * 0.29, size * 0.83), handle_light, w * 0.4, true)
		## Ніж — лезо з тінню
		var blade_shadow: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.62, size * 0.17),
			Vector2(size * 0.76, size * 0.17),
			Vector2(size * 0.76, size * 0.52),
			Vector2(size * 0.62, size * 0.57),
		])
		ctrl.draw_colored_polygon(blade_shadow, pal.dark)
		## Лезо — основне
		var blade: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.60, size * 0.15),
			Vector2(size * 0.74, size * 0.15),
			Vector2(size * 0.74, size * 0.50),
			Vector2(size * 0.60, size * 0.55),
		])
		ctrl.draw_colored_polygon(blade, pal.base)
		## Металевий градієнт на лезі (2 смуги)
		ctrl.draw_line(Vector2(size * 0.62, size * 0.17),
			Vector2(size * 0.62, size * 0.48), pal.lighter, w * 0.8, true)
		ctrl.draw_line(Vector2(size * 0.65, size * 0.17),
			Vector2(size * 0.65, size * 0.46), Color(1, 1, 1, 0.30), w * 0.5, true)
		## Ручка ножа — градієнт дерева
		ctrl.draw_line(Vector2(size * 0.67, size * 0.55),
			Vector2(size * 0.67, size * 0.85), handle, w * 1.6, true)
		ctrl.draw_line(Vector2(size * 0.66, size * 0.57),
			Vector2(size * 0.66, size * 0.83), handle_light, w * 0.4, true)
		## Іскорка на кінчику ножа
		ctrl.draw_circle(Vector2(size * 0.72, size * 0.17), maxf(size * 0.025, 1.0),
			Color(1, 1, 1, 0.6))
	)
	return ctrl


static func ghost(size: float = 24.0, color: Color = Color("e8eaf6")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## Тінь під привидом
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.55), size * 0.30,
			Color(0.4, 0.3, 0.6, 0.18))
		## Тіло — голова (градієнт)
		_draw_radial_gradient(ctrl, Vector2(size * 0.50, size * 0.38), size * 0.28,
			pal.lighter, pal.base, 4)
		## Тіло — корпус
		ctrl.draw_rect(Rect2(size * 0.22, size * 0.38, size * 0.56, size * 0.35),
			pal.base, true)
		## Градієнт на корпусі — темніший знизу
		ctrl.draw_rect(Rect2(size * 0.22, size * 0.58, size * 0.56, size * 0.15),
			pal.dark, true)
		## Хвиля внизу
		var wave: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.22, size * 0.73),
			Vector2(size * 0.32, size * 0.85),
			Vector2(size * 0.42, size * 0.73),
			Vector2(size * 0.50, size * 0.85),
			Vector2(size * 0.58, size * 0.73),
			Vector2(size * 0.68, size * 0.85),
			Vector2(size * 0.78, size * 0.73),
		])
		ctrl.draw_colored_polygon(wave, pal.dark)
		## Глянцевий блік зверху
		_draw_gloss(ctrl, Vector2(size * 0.50, size * 0.38), size * 0.28, 0.30)
		## Очі — великі милі з зіницями та блікам
		var eye_c: Color = Color("2d3436")
		ctrl.draw_circle(Vector2(size * 0.38, size * 0.40), size * 0.09, eye_c)
		ctrl.draw_circle(Vector2(size * 0.62, size * 0.40), size * 0.09, eye_c)
		## Зіниці — великі для милоти
		ctrl.draw_circle(Vector2(size * 0.40, size * 0.38), size * 0.035,
			Color(1, 1, 1, 0.95))
		ctrl.draw_circle(Vector2(size * 0.64, size * 0.38), size * 0.035,
			Color(1, 1, 1, 0.95))
		## Другий блік в очах — менший
		ctrl.draw_circle(Vector2(size * 0.36, size * 0.42), maxf(size * 0.015, 1.0),
			Color(1, 1, 1, 0.6))
		ctrl.draw_circle(Vector2(size * 0.60, size * 0.42), maxf(size * 0.015, 1.0),
			Color(1, 1, 1, 0.6))
		## Рум'янець — рожеві щічки з градієнтом
		_draw_radial_gradient(ctrl, Vector2(size * 0.28, size * 0.50), size * 0.06,
			Color("ffb5a7", 0.55), Color("ffb5a7", 0.0), 3)
		_draw_radial_gradient(ctrl, Vector2(size * 0.72, size * 0.50), size * 0.06,
			Color("ffb5a7", 0.55), Color("ffb5a7", 0.0), 3)
		## Ротик — маленький О
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.52), size * 0.04,
			Color("2d3436", 0.4))
		## Іскорка на лобі
		ctrl.draw_circle(Vector2(size * 0.55, size * 0.22), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.5))
	)
	return ctrl


static func brain(size: float = 24.0, color: Color = Color("ff6b6b")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var w: float = maxf(size * 0.04, 1.0)
		var pal: Dictionary = _color_palette(color)
		## Тінь під мозком
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.50), size * 0.32,
			Color(0.6, 0.1, 0.1, 0.18))
		## 4 долі мозку — градієнтні
		_draw_radial_gradient(ctrl, Vector2(size * 0.38, size * 0.38), size * 0.22,
			pal.light, pal.base, 4)
		_draw_radial_gradient(ctrl, Vector2(size * 0.62, size * 0.38), size * 0.22,
			pal.light, pal.dark, 4)
		_draw_radial_gradient(ctrl, Vector2(size * 0.38, size * 0.56), size * 0.18,
			pal.base, pal.dark, 3)
		_draw_radial_gradient(ctrl, Vector2(size * 0.62, size * 0.56), size * 0.18,
			pal.base, pal.dark, 3)
		## Борозни — зігнуті лінії (darker)
		var lc: Color = pal.darker
		ctrl.draw_line(Vector2(size * 0.50, size * 0.18),
			Vector2(size * 0.50, size * 0.73), lc, w, true)
		ctrl.draw_arc(Vector2(size * 0.38, size * 0.38), size * 0.14,
			-0.5, 1.2, 8, lc, w, true)
		ctrl.draw_arc(Vector2(size * 0.62, size * 0.38), size * 0.14,
			PI - 1.2, PI + 0.5, 8, lc, w, true)
		## Додаткові борозни для текстури
		ctrl.draw_arc(Vector2(size * 0.42, size * 0.52), size * 0.08,
			0.3, 1.5, 6, lc, w * 0.7, true)
		ctrl.draw_arc(Vector2(size * 0.58, size * 0.52), size * 0.08,
			PI - 1.5, PI - 0.3, 6, lc, w * 0.7, true)
		## Глянцевий блік зверху-зліва
		_draw_gloss(ctrl, Vector2(size * 0.38, size * 0.34), size * 0.18, 0.25)
		## Іскорка — "eureka" момент
		ctrl.draw_circle(Vector2(size * 0.68, size * 0.22), maxf(size * 0.025, 1.0),
			Color(1, 1, 0.7, 0.7))
	)
	return ctrl


static func bubble(size: float = 24.0, color: Color = Color("93c5fd")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## Тінь під бульбашкою
		_draw_soft_shadow(ctrl, Vector2(size * 0.48, size * 0.50), size * 0.30,
			Color(0.2, 0.4, 0.7, 0.15))
		## Основна сфера — радіальний градієнт
		_draw_radial_gradient(ctrl, Vector2(size * 0.48, size * 0.46), size * 0.32,
			pal.lighter, pal.dark, 5)
		## Контурне коло — скляний ефект
		_draw_outline(ctrl, Vector2(size * 0.48, size * 0.46), size * 0.32,
			Color(1, 1, 1, 0.15), maxf(size * 0.02, 1.0))
		## Великий глянцевий блік
		_draw_gloss(ctrl, Vector2(size * 0.48, size * 0.42), size * 0.28, 0.40)
		## Веселковий дугоподібний відблиск
		ctrl.draw_arc(Vector2(size * 0.48, size * 0.46), size * 0.22,
			PI * 0.6, PI * 1.1, 8, Color("e599f7", 0.25),
			maxf(size * 0.03, 1.0), true)
		## Маленький рожевий відблиск знизу-справа
		ctrl.draw_circle(Vector2(size * 0.62, size * 0.58), size * 0.04,
			Color("e599f7", 0.35))
		## Супутня бульбашка 1 — з градієнтом
		_draw_radial_gradient(ctrl, Vector2(size * 0.78, size * 0.22), size * 0.09,
			pal.lighter, pal.base, 3)
		ctrl.draw_circle(Vector2(size * 0.76, size * 0.19), maxf(size * 0.025, 1.0),
			Color(1, 1, 1, 0.5))
		## Супутня бульбашка 2 — зовсім маленька
		ctrl.draw_circle(Vector2(size * 0.82, size * 0.38), size * 0.04,
			pal.light)
		ctrl.draw_circle(Vector2(size * 0.81, size * 0.37), maxf(size * 0.015, 1.0),
			Color(1, 1, 1, 0.4))
	)
	return ctrl


static func diamond(size: float = 24.0, color: Color = Color("3b82f6")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var top: Vector2 = Vector2(size * 0.50, size * 0.10)
		var right: Vector2 = Vector2(size * 0.85, size * 0.45)
		var bottom: Vector2 = Vector2(size * 0.50, size * 0.90)
		var left_pt: Vector2 = Vector2(size * 0.15, size * 0.45)
		var center: Vector2 = Vector2(size * 0.50, size * 0.45)
		## Тінь — зміщений силует
		var sh_off: Vector2 = Vector2(2, 3)
		ctrl.draw_colored_polygon(PackedVector2Array([
			top + sh_off, right + sh_off, bottom + sh_off, left_pt + sh_off]),
			Color(0, 0, 0, 0.12))
		## 4 грані з багатшою освітленістю
		ctrl.draw_colored_polygon(PackedVector2Array([top, right, center]),
			pal.lighter)
		ctrl.draw_colored_polygon(PackedVector2Array([top, left_pt, center]),
			pal.light)
		ctrl.draw_colored_polygon(PackedVector2Array([bottom, right, center]),
			pal.dark)
		ctrl.draw_colored_polygon(PackedVector2Array([bottom, left_pt, center]),
			pal.darker)
		## Внутрішні грані — лінії для об'єму
		var w: float = maxf(size * 0.02, 1.0)
		ctrl.draw_line(top, center, Color(1, 1, 1, 0.25), w, true)
		ctrl.draw_line(left_pt, center, Color(1, 1, 1, 0.12), w, true)
		ctrl.draw_line(right, center, Color(0, 0, 0, 0.10), w, true)
		ctrl.draw_line(bottom, center, Color(0, 0, 0, 0.15), w, true)
		## Веселковий рефракційний відблиск
		ctrl.draw_circle(Vector2(size * 0.40, size * 0.38), maxf(size * 0.04, 1.5),
			Color("a78bfa", 0.30))
		ctrl.draw_circle(Vector2(size * 0.58, size * 0.52), maxf(size * 0.03, 1.0),
			Color("38bdf8", 0.25))
		## Іскорка на верхівці — зірочка
		ctrl.draw_circle(top + Vector2(size * 0.06, size * 0.04), maxf(size * 0.03, 1.0),
			Color(1, 1, 1, 0.8))
		ctrl.draw_circle(top + Vector2(-size * 0.04, size * 0.06), maxf(size * 0.018, 1.0),
			Color(1, 1, 1, 0.5))
	)
	return ctrl


static func numbers_icon(size: float = 24.0, _color: Color = Color("FFD166")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var w: float = maxf(size * 0.06, 1.5)
		var y0: float = size * 0.28
		var y1: float = size * 0.72
		var ymid: float = size * 0.50
		## Тінь під цифрами
		_draw_soft_shadow(ctrl, Vector2(size * 0.48, size * 0.52), size * 0.30,
			Color(0, 0, 0, 0.12))
		## "1" — червона з тінню
		var c1: Color = Color("ef476f")
		var c1_dark: Color = c1.darkened(0.25)
		var x1: float = size * 0.18
		ctrl.draw_line(Vector2(x1 + 1, y0 + 1), Vector2(x1 + 1, y1 + 1),
			c1_dark, w * 1.5, true)
		ctrl.draw_line(Vector2(x1, y0), Vector2(x1, y1), c1, w * 1.3, true)
		ctrl.draw_line(Vector2(x1 - size * 0.06, y0 + size * 0.08),
			Vector2(x1, y0), c1, w * 0.8, true)
		## Блік на "1"
		ctrl.draw_line(Vector2(x1 - maxf(size * 0.01, 0.5), y0 + size * 0.04),
			Vector2(x1 - maxf(size * 0.01, 0.5), ymid),
			c1.lightened(0.25), w * 0.4, true)
		## "2" — зелена з тінню
		var c2: Color = Color("22c55e")
		var c2_dark: Color = c2.darkened(0.25)
		var x2: float = size * 0.46
		ctrl.draw_arc(Vector2(x2, y0 + size * 0.10), size * 0.10,
			PI + 0.3, TAU + 0.3, 10, c2_dark, w * 1.1, true)
		ctrl.draw_arc(Vector2(x2, y0 + size * 0.10), size * 0.10,
			PI + 0.3, TAU + 0.3, 10, c2, w, true)
		ctrl.draw_line(Vector2(x2 + size * 0.10, ymid),
			Vector2(x2 - size * 0.10, y1), c2, w, true)
		ctrl.draw_line(Vector2(x2 - size * 0.10, y1),
			Vector2(x2 + size * 0.10, y1), c2, w, true)
		## "3" — синя з тінню
		var c3: Color = Color("3b82f6")
		var c3_dark: Color = c3.darkened(0.25)
		var x3: float = size * 0.76
		ctrl.draw_arc(Vector2(x3, y0 + size * 0.12), size * 0.10,
			-PI * 0.7, PI * 0.7, 10, c3_dark, w * 1.1, true)
		ctrl.draw_arc(Vector2(x3, y0 + size * 0.12), size * 0.10,
			-PI * 0.7, PI * 0.7, 10, c3, w, true)
		ctrl.draw_arc(Vector2(x3, y1 - size * 0.12), size * 0.10,
			-PI * 0.7, PI * 0.7, 10, c3_dark, w * 1.1, true)
		ctrl.draw_arc(Vector2(x3, y1 - size * 0.12), size * 0.10,
			-PI * 0.7, PI * 0.7, 10, c3, w, true)
		## Декоративна іскорка між цифрами
		ctrl.draw_circle(Vector2(size * 0.32, size * 0.22), maxf(size * 0.02, 1.0),
			Color("FFD166", 0.6))
		ctrl.draw_circle(Vector2(size * 0.62, size * 0.20), maxf(size * 0.015, 1.0),
			Color("FFD166", 0.5))
	)
	return ctrl


static func puzzle_piece(size: float = 24.0, color: Color = Color("a78bfa")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(size * 0.45, size * 0.55), size * 0.32,
			Color(0.3, 0.2, 0.5, 0.18))
		## Основа — градієнт зверху вниз (2 зони)
		ctrl.draw_rect(Rect2(size * 0.18, size * 0.28, size * 0.54, size * 0.27),
			pal.light, true)
		ctrl.draw_rect(Rect2(size * 0.18, size * 0.55, size * 0.54, size * 0.27),
			pal.base, true)
		## Виступ зверху — градієнтний
		_draw_radial_gradient(ctrl, Vector2(size * 0.45, size * 0.28), size * 0.10,
			pal.lighter, pal.light, 3)
		## Виступ справа — градієнтний
		_draw_radial_gradient(ctrl, Vector2(size * 0.72, size * 0.55), size * 0.10,
			pal.lighter, pal.light, 3)
		## Заглиблення зліва — темний з глибиною
		_draw_radial_gradient(ctrl, Vector2(size * 0.18, size * 0.55), size * 0.08,
			pal.darker, pal.dark, 3)
		## Глянцевий блік зверху
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.30, size * 0.48, size * 0.12),
			Color(1, 1, 1, 0.18), true)
		## Лінія деталізації — розділювач
		ctrl.draw_line(Vector2(size * 0.20, size * 0.55),
			Vector2(size * 0.70, size * 0.55), pal.dark, maxf(size * 0.015, 1.0), true)
		## Іскорка
		ctrl.draw_circle(Vector2(size * 0.62, size * 0.35), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.5))
	)
	return ctrl


static func magnifier(size: float = 24.0, color: Color = Color("c0c0c0")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.07, 1.5)
		var cx: float = size * 0.42
		var cy: float = size * 0.42
		var r: float = size * 0.22
		var center: Vector2 = Vector2(cx, cy)
		var handle_color: Color = Color("8B6914")
		var handle_pal: Dictionary = _color_palette(handle_color)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, center, r, Color(0, 0, 0, 0.18))
		## 2) Лінза — 3-кільцевий градієнт (зовнішній → внутрішній)
		ctrl.draw_circle(center, r, Color("93c5fd", 0.20))
		ctrl.draw_circle(center, r * 0.72, Color("bfdbfe", 0.25))
		ctrl.draw_circle(center, r * 0.42, Color("dbeafe", 0.30))
		## 3) Обідок — срібний товстий з глибиною
		ctrl.draw_arc(center, r, 0, TAU, 20, pal.dark, w * 1.8, true)
		ctrl.draw_arc(center, r, 0, TAU, 20, pal.base, w * 1.5, true)
		## Блік на обідку — верхня дуга
		ctrl.draw_arc(center, r, PI * 1.1, PI * 1.8, 8,
			pal.lighter, w * 0.7, true)
		## 4) Глянець на лінзі
		_draw_gloss(ctrl, Vector2(cx - size * 0.03, cy - size * 0.04), r * 0.8, 0.30)
		## Ручка — тінь
		ctrl.draw_line(Vector2(size * 0.60, size * 0.60),
			Vector2(size * 0.84, size * 0.84), handle_pal.darker, w * 2.5, true)
		## Ручка — основна
		ctrl.draw_line(Vector2(size * 0.58, size * 0.58),
			Vector2(size * 0.82, size * 0.82), handle_color, w * 2.0, true)
		## Ручка — wood grain (2 лінії текстури)
		ctrl.draw_line(Vector2(size * 0.62, size * 0.62),
			Vector2(size * 0.78, size * 0.78), handle_pal.light, maxf(w * 0.4, 0.8), true)
		ctrl.draw_line(Vector2(size * 0.65, size * 0.63),
			Vector2(size * 0.81, size * 0.79), handle_pal.dark, maxf(w * 0.3, 0.6), true)
		## 5) Мікро-деталі — lens flare іскорка
		ctrl.draw_circle(Vector2(cx - size * 0.08, cy - size * 0.08),
			maxf(size * 0.025, 1.0), Color(1, 1, 1, 0.6))
		ctrl.draw_circle(Vector2(cx + size * 0.05, cy - size * 0.10),
			maxf(size * 0.015, 0.8), Color(1, 1, 1, 0.4))
	)
	return ctrl


static func pencil(size: float = 24.0, color: Color = Color("FFD166")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var eraser_color: Color = Color("ff6b6b")
		var eraser_pal: Dictionary = _color_palette(eraser_color)
		## 1) М'яка тінь під олівцем
		_draw_soft_shadow(ctrl, Vector2(size * 0.48, size * 0.50), size * 0.22,
			Color(0, 0, 0, 0.16), Vector2(2.0, 2.5))
		## 2) Тінь тіла — глибина
		ctrl.draw_rect(Rect2(size * 0.42, size * 0.17, size * 0.20, size * 0.55),
			pal.darker, true)
		## Тіло — основна заливка
		ctrl.draw_rect(Rect2(size * 0.38, size * 0.15, size * 0.20, size * 0.55),
			pal.base, true)
		## 3) Градієнт/глибина — ліва світла полоска + права темна
		ctrl.draw_rect(Rect2(size * 0.38, size * 0.15, size * 0.06, size * 0.55),
			pal.light, true)
		ctrl.draw_rect(Rect2(size * 0.54, size * 0.15, size * 0.04, size * 0.55),
			pal.dark, true)
		## Wood grain — 2 тонкі текстурні лінії
		ctrl.draw_line(Vector2(size * 0.44, size * 0.16),
			Vector2(size * 0.44, size * 0.69), pal.lighter, maxf(size * 0.008, 0.5), true)
		ctrl.draw_line(Vector2(size * 0.50, size * 0.16),
			Vector2(size * 0.50, size * 0.69), pal.dark, maxf(size * 0.006, 0.5), true)
		## Вістря — дерев'яна частина
		var tip: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.38, size * 0.70),
			Vector2(size * 0.58, size * 0.70),
			Vector2(size * 0.48, size * 0.88),
		])
		ctrl.draw_colored_polygon(tip, Color("8B6914"))
		## Вістря — тінь (права грань)
		ctrl.draw_line(Vector2(size * 0.54, size * 0.70),
			Vector2(size * 0.48, size * 0.87), Color("6B4F10"), maxf(size * 0.015, 0.8), true)
		## Графіт на кінчику
		ctrl.draw_line(Vector2(size * 0.48, size * 0.84),
			Vector2(size * 0.48, size * 0.88), Color("444444"),
			maxf(size * 0.04, 1.0), true)
		## Обідок (феруля) — срібна смужка з градієнтом
		ctrl.draw_rect(Rect2(size * 0.37, size * 0.10, size * 0.22, size * 0.06),
			Color("a0a0a0"), true)
		ctrl.draw_rect(Rect2(size * 0.37, size * 0.10, size * 0.22, size * 0.03),
			Color("d0d0d0"), true)
		## Гумка — основна
		ctrl.draw_rect(Rect2(size * 0.39, size * 0.06, size * 0.18, size * 0.06),
			eraser_color, true)
		## 4) Глянець на гумці
		ctrl.draw_rect(Rect2(size * 0.39, size * 0.06, size * 0.18, size * 0.025),
			eraser_pal.lighter, true)
		## 5) Мікро-деталі — іскорка графіту
		ctrl.draw_circle(Vector2(size * 0.48, size * 0.86),
			maxf(size * 0.015, 0.8), Color(1, 1, 1, 0.5))
		## Маленька іскорка на тілі
		ctrl.draw_circle(Vector2(size * 0.40, size * 0.22),
			maxf(size * 0.012, 0.6), Color(1, 1, 1, 0.35))
	)
	return ctrl


static func music_note(size: float = 24.0, color: Color = Color("2d3436")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var w: float = maxf(size * 0.06, 1.0)
		var pal: Dictionary = _color_palette(color)
		var gold: Color = Color("FFD166")
		var gold_pal: Dictionary = _color_palette(gold)
		## Тінь під нотою
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.55), size * 0.28,
			Color(0, 0, 0, 0.12))
		## Стеблинка — золотий градієнт (темніший знизу)
		ctrl.draw_line(Vector2(size * 0.59, size * 0.16),
			Vector2(size * 0.59, size * 0.69), gold_pal["dark"], w * 1.8, true)
		ctrl.draw_line(Vector2(size * 0.58, size * 0.15),
			Vector2(size * 0.58, size * 0.68), gold_pal["base"], w * 1.5, true)
		## Блік на стеблинці
		ctrl.draw_line(Vector2(size * 0.57, size * 0.18),
			Vector2(size * 0.57, size * 0.50), gold_pal["lighter"], w * 0.4, true)
		## Нота — головка з градієнтом
		_draw_radial_gradient(ctrl, Vector2(size * 0.46, size * 0.72), size * 0.14,
			pal["light"], pal["dark"], 4)
		## Глянець на головці
		_draw_gloss(ctrl, Vector2(size * 0.46, size * 0.70), size * 0.12, 0.25)
		## Прапорець — золотий з тінню
		var flag_shadow: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.59, size * 0.16),
			Vector2(size * 0.79, size * 0.23),
			Vector2(size * 0.79, size * 0.33),
			Vector2(size * 0.59, size * 0.29),
		])
		ctrl.draw_colored_polygon(flag_shadow, gold_pal["dark"])
		var flag_main: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.58, size * 0.15),
			Vector2(size * 0.78, size * 0.22),
			Vector2(size * 0.78, size * 0.32),
			Vector2(size * 0.58, size * 0.28),
		])
		ctrl.draw_colored_polygon(flag_main, gold_pal["base"])
		## Блік на прапорці — діагональна смуга
		ctrl.draw_line(Vector2(size * 0.60, size * 0.17),
			Vector2(size * 0.74, size * 0.22), gold_pal["lighter"], w * 0.6, true)
		## Маленькі нотки-іскорки
		ctrl.draw_circle(Vector2(size * 0.28, size * 0.30), maxf(size * 0.02, 1.0),
			gold_pal["light"])
		ctrl.draw_circle(Vector2(size * 0.78, size * 0.50), maxf(size * 0.015, 1.0),
			gold_pal["light"])
	)
	return ctrl


static func cycle_arrows(size: float = 24.0, color: Color = Color("22c55e")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.07, 1.5)
		var center: Vector2 = Vector2(size * 0.5, size * 0.5)
		var arc_r: float = size * 0.28
		## 1) М'яка тінь — тіньові дуги
		_draw_soft_shadow(ctrl, center, arc_r, Color(0, 0, 0, 0.14))
		## Тіньові дуги (зміщені)
		ctrl.draw_arc(center + Vector2(1.5, 2.0), arc_r,
			-PI * 0.3, PI * 0.8, 14, pal.shadow, w * 1.2, true)
		ctrl.draw_arc(center + Vector2(1.5, 2.0), arc_r,
			PI * 0.7, PI * 1.8, 14, pal.shadow, w * 1.2, true)
		## 2) Основні дуги — темна підкладка для глибини
		ctrl.draw_arc(center, arc_r,
			-PI * 0.3, PI * 0.8, 16, pal.dark, w * 1.3, true)
		ctrl.draw_arc(center, arc_r,
			PI * 0.7, PI * 1.8, 16, pal.dark, w * 1.3, true)
		## Основні дуги — яскраві
		ctrl.draw_arc(center, arc_r,
			-PI * 0.3, PI * 0.8, 16, pal.base, w, true)
		ctrl.draw_arc(center, arc_r,
			PI * 0.7, PI * 1.8, 16, pal.base, w, true)
		## 3) Градієнт/блік на дугах — світліша внутрішня дуга
		ctrl.draw_arc(center, arc_r * 0.92,
			-PI * 0.2, PI * 0.4, 8, pal.lighter, w * 0.4, true)
		ctrl.draw_arc(center, arc_r * 0.92,
			PI * 0.8, PI * 1.4, 8, pal.lighter, w * 0.4, true)
		## 4) Стрілки — тінь + основа + глянець
		var pts1_shadow: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.73, size * 0.30),
			Vector2(size * 0.84, size * 0.40),
			Vector2(size * 0.66, size * 0.40),
		])
		ctrl.draw_colored_polygon(pts1_shadow, pal.darker)
		var pts1: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.72, size * 0.28),
			Vector2(size * 0.82, size * 0.38),
			Vector2(size * 0.65, size * 0.38),
		])
		ctrl.draw_colored_polygon(pts1, pal.dark)
		## Блік на стрілці 1
		ctrl.draw_line(Vector2(size * 0.72, size * 0.30),
			Vector2(size * 0.74, size * 0.36), pal.lighter, maxf(w * 0.4, 0.6), true)
		var pts2_shadow: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.29, size * 0.74),
			Vector2(size * 0.19, size * 0.64),
			Vector2(size * 0.36, size * 0.64),
		])
		ctrl.draw_colored_polygon(pts2_shadow, pal.darker)
		var pts2: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.28, size * 0.72),
			Vector2(size * 0.18, size * 0.62),
			Vector2(size * 0.35, size * 0.62),
		])
		ctrl.draw_colored_polygon(pts2, pal.dark)
		## Блік на стрілці 2
		ctrl.draw_line(Vector2(size * 0.28, size * 0.70),
			Vector2(size * 0.26, size * 0.64), pal.lighter, maxf(w * 0.4, 0.6), true)
		## 5) Мікро-деталі — motion trail dots
		ctrl.draw_circle(Vector2(size * 0.30, size * 0.32),
			maxf(size * 0.018, 0.8), Color(pal.light, 0.5))
		ctrl.draw_circle(Vector2(size * 0.38, size * 0.24),
			maxf(size * 0.013, 0.6), Color(pal.light, 0.4))
		ctrl.draw_circle(Vector2(size * 0.70, size * 0.68),
			maxf(size * 0.018, 0.8), Color(pal.light, 0.5))
		ctrl.draw_circle(Vector2(size * 0.62, size * 0.76),
			maxf(size * 0.013, 0.6), Color(pal.light, 0.4))
	)
	return ctrl


static func scales(size: float = 24.0, color: Color = Color("FFD166")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.06, 1.0)
		var pole_color: Color = Color("8B6914")
		var pole_pal: Dictionary = _color_palette(pole_color)
		var pan_l: Vector2 = Vector2(size * 0.22, size * 0.45)
		var pan_r: Vector2 = Vector2(size * 0.78, size * 0.45)
		## 1) М'яка тінь під підставкою
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.82), size * 0.20,
			Color(0, 0, 0, 0.16), Vector2(1.0, 2.0))
		## 2) Стовп — тінь + основна
		ctrl.draw_line(Vector2(size * 0.52, size * 0.17),
			Vector2(size * 0.52, size * 0.82), pole_pal.darker, w * 1.8, true)
		ctrl.draw_line(Vector2(size * 0.50, size * 0.15),
			Vector2(size * 0.50, size * 0.80), pole_color, w * 1.5, true)
		## Блік на стовпі
		ctrl.draw_line(Vector2(size * 0.49, size * 0.18),
			Vector2(size * 0.49, size * 0.75), pole_pal.light, maxf(w * 0.3, 0.5), true)
		## 3) Коромисло — градієнт (темна підкладка + світла)
		ctrl.draw_line(Vector2(size * 0.15, size * 0.32),
			Vector2(size * 0.85, size * 0.32), pal.darker, w * 1.5, true)
		ctrl.draw_line(Vector2(size * 0.15, size * 0.30),
			Vector2(size * 0.85, size * 0.30), pal.base, w * 1.2, true)
		ctrl.draw_line(Vector2(size * 0.20, size * 0.29),
			Vector2(size * 0.80, size * 0.29), pal.lighter, maxf(w * 0.3, 0.5), true)
		## Ланцюги — тонкі золоті
		ctrl.draw_line(Vector2(size * 0.15, size * 0.30),
			Vector2(size * 0.10, size * 0.45), pal.dark, w * 0.6, true)
		ctrl.draw_line(Vector2(size * 0.29, size * 0.30),
			Vector2(size * 0.34, size * 0.45), pal.dark, w * 0.6, true)
		ctrl.draw_line(Vector2(size * 0.85, size * 0.30),
			Vector2(size * 0.90, size * 0.45), pal.dark, w * 0.6, true)
		ctrl.draw_line(Vector2(size * 0.71, size * 0.30),
			Vector2(size * 0.66, size * 0.45), pal.dark, w * 0.6, true)
		## 4) Чаші — 2-кільцевий градієнт кожна
		## Ліва чаша
		ctrl.draw_arc(pan_l, size * 0.12, 0, PI, 10, pal.dark, w * 1.5, true)
		ctrl.draw_arc(pan_l, size * 0.12, 0, PI, 10, pal.light, w * 1.2, true)
		ctrl.draw_arc(pan_l, size * 0.08, 0.2, PI * 0.8, 6, pal.lighter, w * 0.5, true)
		## Права чаша
		ctrl.draw_arc(pan_r, size * 0.12, 0, PI, 10, pal.dark, w * 1.5, true)
		ctrl.draw_arc(pan_r, size * 0.12, 0, PI, 10, pal.light, w * 1.2, true)
		ctrl.draw_arc(pan_r, size * 0.08, 0.2, PI * 0.8, 6, pal.lighter, w * 0.5, true)
		## Підставка — градієнт
		ctrl.draw_rect(Rect2(size * 0.35, size * 0.82, size * 0.30, size * 0.06),
			pal.dark, true)
		ctrl.draw_rect(Rect2(size * 0.35, size * 0.80, size * 0.30, size * 0.06),
			pal.base, true)
		ctrl.draw_rect(Rect2(size * 0.36, size * 0.80, size * 0.28, size * 0.025),
			pal.lighter, true)
		## Навершя — з градієнтом
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.15), size * 0.05, pal.dark)
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.15), size * 0.04, pal.base)
		## 5) Мікро-деталі — fulcrum jewel (іскорка на навершя)
		ctrl.draw_circle(Vector2(size * 0.49, size * 0.14),
			maxf(size * 0.015, 0.8), Color(1, 1, 1, 0.6))
		## Блікі на чашах
		ctrl.draw_circle(Vector2(size * 0.18, size * 0.47),
			maxf(size * 0.012, 0.6), Color(1, 1, 1, 0.4))
		ctrl.draw_circle(Vector2(size * 0.74, size * 0.47),
			maxf(size * 0.012, 0.6), Color(1, 1, 1, 0.4))
	)
	return ctrl


static func folder_icon(size: float = 24.0, color: Color = Color("FFD166")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## 1) М'яка тінь під папкою
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.58), size * 0.30,
			Color(0, 0, 0, 0.15), Vector2(1.5, 2.5))
		## Білий папір ззаду (видно зверху)
		ctrl.draw_rect(Rect2(size * 0.16, size * 0.34, size * 0.72, size * 0.42),
			Color("f5f5f5"), true)
		## Paper edge detail — лінії на папері
		ctrl.draw_line(Vector2(size * 0.22, size * 0.44),
			Vector2(size * 0.80, size * 0.44), Color("e0e0e0"), maxf(size * 0.01, 0.5), true)
		ctrl.draw_line(Vector2(size * 0.22, size * 0.52),
			Vector2(size * 0.75, size * 0.52), Color("e0e0e0"), maxf(size * 0.01, 0.5), true)
		ctrl.draw_line(Vector2(size * 0.22, size * 0.60),
			Vector2(size * 0.65, size * 0.60), Color("e8e8e8"), maxf(size * 0.01, 0.5), true)
		## 2) Вкладка (tab) — тінь + основа
		ctrl.draw_rect(Rect2(size * 0.13, size * 0.24, size * 0.30, size * 0.12),
			pal.darker, true)
		ctrl.draw_rect(Rect2(size * 0.12, size * 0.22, size * 0.30, size * 0.12),
			pal.base, true)
		## 3) Tab gradient — світліша верхня половина
		ctrl.draw_rect(Rect2(size * 0.12, size * 0.22, size * 0.30, size * 0.05),
			pal.light, true)
		## 2) Тіло папки — основне
		ctrl.draw_rect(Rect2(size * 0.12, size * 0.32, size * 0.76, size * 0.48),
			pal.base, true)
		## Згин зверху — темніший
		ctrl.draw_rect(Rect2(size * 0.12, size * 0.32, size * 0.76, size * 0.08),
			pal.dark, true)
		## 3) Градієнт на тілі — нижня частина темніша
		ctrl.draw_rect(Rect2(size * 0.12, size * 0.68, size * 0.76, size * 0.12),
			pal.dark, true)
		## 4) Глянець — верхня смуга
		ctrl.draw_rect(Rect2(size * 0.14, size * 0.42, size * 0.72, size * 0.08),
			Color(1, 1, 1, 0.14), true)
		## 5) Мікро-деталі — clasp dot (замочок)
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.34),
			maxf(size * 0.025, 1.0), pal.darker)
		ctrl.draw_circle(Vector2(size * 0.50, size * 0.34),
			maxf(size * 0.018, 0.8), pal.lighter)
		## Іскорка на замочку
		ctrl.draw_circle(Vector2(size * 0.49, size * 0.33),
			maxf(size * 0.008, 0.5), Color(1, 1, 1, 0.55))
	)
	return ctrl


static func ruler(size: float = 24.0, color: Color = Color("FFD166")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.04, 1.0)
		var red: Color = Color("ef476f")
		## 1) М'яка тінь під лінійкою
		_draw_soft_shadow(ctrl, Vector2(size * 0.50, size * 0.52), size * 0.28,
			Color(0, 0, 0, 0.16), Vector2(1.5, 2.5))
		## Тінь тіла (зміщена)
		ctrl.draw_rect(Rect2(size * 0.17, size * 0.33, size * 0.70, size * 0.40),
			pal.darker, true)
		## 2) Тіло — основна заливка
		ctrl.draw_rect(Rect2(size * 0.15, size * 0.30, size * 0.70, size * 0.40),
			pal.base, true)
		## 3) Wood gradient — верхня полоса світліша, нижня темніша
		ctrl.draw_rect(Rect2(size * 0.15, size * 0.30, size * 0.70, size * 0.13),
			pal.light, true)
		ctrl.draw_rect(Rect2(size * 0.15, size * 0.58, size * 0.70, size * 0.12),
			pal.dark, true)
		## Wood grain — тонкі горизонтальні лінії текстури
		ctrl.draw_line(Vector2(size * 0.16, size * 0.45),
			Vector2(size * 0.84, size * 0.45), pal.light, maxf(size * 0.006, 0.5), true)
		ctrl.draw_line(Vector2(size * 0.16, size * 0.55),
			Vector2(size * 0.84, size * 0.55), pal.dark, maxf(size * 0.006, 0.5), true)
		## Позначки — червоні з тінню
		for i: int in 5:
			var x: float = size * (0.22 + float(i) * 0.13)
			var h: float = size * 0.15 if i % 2 == 0 else size * 0.10
			## Тінь позначки
			ctrl.draw_line(Vector2(x + 0.5, size * 0.31),
				Vector2(x + 0.5, size * 0.31 + h), red.darkened(0.3), w * 1.2, true)
			## Основна позначка
			ctrl.draw_line(Vector2(x, size * 0.30),
				Vector2(x, size * 0.30 + h), red, w, true)
		## 4) Глянець зверху
		ctrl.draw_rect(Rect2(size * 0.15, size * 0.30, size * 0.70, size * 0.10),
			Color(1, 1, 1, 0.15), true)
		## 5) Мікро-деталі — highlight ticks на кожній другій позначці
		for i: int in 3:
			var x: float = size * (0.22 + float(i * 2) * 0.13)
			ctrl.draw_circle(Vector2(x, size * 0.30),
				maxf(size * 0.012, 0.6), Color(1, 1, 1, 0.45))
		## Іскорка в кутку
		ctrl.draw_circle(Vector2(size * 0.80, size * 0.34),
			maxf(size * 0.015, 0.8), Color(1, 1, 1, 0.35))
	)
	return ctrl


static func factory(size: float = 24.0, color: Color = Color("b8c0cc")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var w: float = maxf(size * 0.06, 1.0)
		## 1) М'яка тінь під будівлею
		ctrl.draw_rect(Rect2(size * 0.17, size * 0.43, size * 0.70, size * 0.48),
			Color(0, 0, 0, 0.15), true)
		## 2) Будівля — основа з градієнтом (знизу темніше)
		ctrl.draw_rect(Rect2(size * 0.15, size * 0.40, size * 0.70, size * 0.48), pal.base, true)
		ctrl.draw_rect(Rect2(size * 0.15, size * 0.64, size * 0.70, size * 0.24), pal.dark, true)
		## Дах — темніший з обводкою
		ctrl.draw_rect(Rect2(size * 0.15, size * 0.40, size * 0.70, size * 0.08), pal.darker, true)
		ctrl.draw_line(Vector2(size * 0.15, size * 0.48), Vector2(size * 0.85, size * 0.48),
			pal.dark, maxf(w * 0.5, 1.0), true)
		## 3) Димар з градієнтом
		var chimney_pal: Dictionary = _color_palette(Color("ef476f"))
		ctrl.draw_rect(Rect2(size * 0.65, size * 0.15, size * 0.12, size * 0.25),
			chimney_pal.dark, true)
		ctrl.draw_rect(Rect2(size * 0.65, size * 0.15, size * 0.06, size * 0.25),
			chimney_pal.base, true)
		ctrl.draw_rect(Rect2(size * 0.65, size * 0.15, size * 0.12, size * 0.05),
			chimney_pal.lighter, true)
		## Дим — білі кульки з прозорістю
		ctrl.draw_circle(Vector2(size * 0.71, size * 0.12), size * 0.07,
			Color(1, 1, 1, 0.25))
		ctrl.draw_circle(Vector2(size * 0.71, size * 0.12), size * 0.05,
			Color(1, 1, 1, 0.55))
		ctrl.draw_circle(Vector2(size * 0.66, size * 0.06), size * 0.05,
			Color(1, 1, 1, 0.20))
		ctrl.draw_circle(Vector2(size * 0.66, size * 0.06), size * 0.035,
			Color(1, 1, 1, 0.45))
		ctrl.draw_circle(Vector2(size * 0.62, size * 0.02), size * 0.025,
			Color(1, 1, 1, 0.30))
		## 4) Вікна — блакитні з глянцем
		var win: Color = Color("93c5fd")
		var win_pal: Dictionary = _color_palette(win)
		ctrl.draw_rect(Rect2(size * 0.22, size * 0.52, size * 0.14, size * 0.12), win, true)
		ctrl.draw_rect(Rect2(size * 0.42, size * 0.52, size * 0.14, size * 0.12), win, true)
		## Віконний глянець — біла смуга зверху
		ctrl.draw_rect(Rect2(size * 0.22, size * 0.52, size * 0.14, size * 0.04),
			Color(1, 1, 1, 0.30), true)
		ctrl.draw_rect(Rect2(size * 0.42, size * 0.52, size * 0.14, size * 0.04),
			Color(1, 1, 1, 0.30), true)
		## Віконні рами
		ctrl.draw_rect(Rect2(size * 0.22, size * 0.52, size * 0.14, size * 0.12),
			win_pal.dark, false, maxf(w * 0.4, 1.0))
		ctrl.draw_rect(Rect2(size * 0.42, size * 0.52, size * 0.14, size * 0.12),
			win_pal.dark, false, maxf(w * 0.4, 1.0))
		## Двері — з градієнтом
		ctrl.draw_rect(Rect2(size * 0.62, size * 0.60, size * 0.14, size * 0.28),
			pal.darker, true)
		ctrl.draw_rect(Rect2(size * 0.62, size * 0.60, size * 0.07, size * 0.28),
			pal.dark, true)
		## Ручка на дверях
		ctrl.draw_circle(Vector2(size * 0.73, size * 0.74), maxf(size * 0.02, 1.0),
			Color("FFD166"))
		## 5) Деталь — шестерня (мікро-деталь)
		var gear_cx: float = size * 0.35
		var gear_cy: float = size * 0.73
		var gear_r: float = maxf(size * 0.05, 2.0)
		ctrl.draw_circle(Vector2(gear_cx, gear_cy), gear_r, pal.darker)
		ctrl.draw_circle(Vector2(gear_cx, gear_cy), gear_r * 0.5, pal.lighter)
		for gi: int in 6:
			var angle: float = float(gi) * PI / 3.0
			ctrl.draw_line(
				Vector2(gear_cx + cos(angle) * gear_r * 0.6, gear_cy + sin(angle) * gear_r * 0.6),
				Vector2(gear_cx + cos(angle) * gear_r * 1.3, gear_cy + sin(angle) * gear_r * 1.3),
				pal.darker, maxf(w * 0.5, 1.0), true)
		## Глянець на будівлі
		ctrl.draw_rect(Rect2(size * 0.15, size * 0.40, size * 0.70, size * 0.10),
			Color(1, 1, 1, 0.10), true)
	)
	return ctrl


static func soap(size: float = 24.0, color: Color = Color("93c5fd")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## 1) М'яка тінь під милом
		ctrl.draw_rect(Rect2(size * 0.21, size * 0.39, size * 0.64, size * 0.40),
			Color(0, 0, 0, 0.14), true)
		## 2) Мило — основа з градієнтом
		ctrl.draw_rect(Rect2(size * 0.18, size * 0.35, size * 0.64, size * 0.40), pal.base, true)
		## Нижня половина мила — темніша
		ctrl.draw_rect(Rect2(size * 0.18, size * 0.55, size * 0.64, size * 0.20), pal.dark, true)
		## 3) Глянець на милі — верхня смуга
		ctrl.draw_rect(Rect2(size * 0.20, size * 0.37, size * 0.60, size * 0.10),
			Color(1, 1, 1, 0.20), true)
		## Крайове свічення (edge glow) — ліва та права сторони
		ctrl.draw_rect(Rect2(size * 0.18, size * 0.35, size * 0.03, size * 0.40),
			Color(1, 1, 1, 0.12), true)
		ctrl.draw_rect(Rect2(size * 0.79, size * 0.35, size * 0.03, size * 0.40),
			Color(1, 1, 1, 0.08), true)
		## Контур мила
		ctrl.draw_rect(Rect2(size * 0.18, size * 0.35, size * 0.64, size * 0.40),
			pal.darker, false, maxf(size * 0.03, 1.0))
		## 4) Бульбашки — з 2-кільцевим градієнтом кожна
		## Велика бульбашка
		var b1_c: Vector2 = Vector2(size * 0.38, size * 0.26)
		var b1_r: float = maxf(size * 0.09, 3.0)
		ctrl.draw_circle(b1_c, b1_r, Color(1, 1, 1, 0.25))
		ctrl.draw_circle(b1_c, b1_r * 0.75, Color(1, 1, 1, 0.45))
		_draw_outline(ctrl, b1_c, b1_r, Color(1, 1, 1, 0.35), maxf(size * 0.02, 0.5))
		_draw_gloss(ctrl, b1_c, b1_r, 0.45)
		## Середня бульбашка
		var b2_c: Vector2 = Vector2(size * 0.55, size * 0.20)
		var b2_r: float = maxf(size * 0.07, 2.5)
		ctrl.draw_circle(b2_c, b2_r, Color(1, 1, 1, 0.20))
		ctrl.draw_circle(b2_c, b2_r * 0.70, Color(1, 1, 1, 0.40))
		_draw_outline(ctrl, b2_c, b2_r, Color(1, 1, 1, 0.30), maxf(size * 0.02, 0.5))
		_draw_gloss(ctrl, b2_c, b2_r, 0.40)
		## Маленька бульбашка
		var b3_c: Vector2 = Vector2(size * 0.64, size * 0.28)
		var b3_r: float = maxf(size * 0.05, 2.0)
		ctrl.draw_circle(b3_c, b3_r, Color(1, 1, 1, 0.18))
		ctrl.draw_circle(b3_c, b3_r * 0.65, Color(1, 1, 1, 0.38))
		_draw_gloss(ctrl, b3_c, b3_r, 0.35)
		## 5) Пінні крапки (foam dots) — мікро-деталі
		ctrl.draw_circle(Vector2(size * 0.30, size * 0.32), maxf(size * 0.018, 1.0),
			Color(1, 1, 1, 0.40))
		ctrl.draw_circle(Vector2(size * 0.72, size * 0.22), maxf(size * 0.014, 1.0),
			Color(1, 1, 1, 0.30))
		ctrl.draw_circle(Vector2(size * 0.48, size * 0.14), maxf(size * 0.012, 1.0),
			Color(1, 1, 1, 0.25))
		ctrl.draw_circle(Vector2(size * 0.25, size * 0.18), maxf(size * 0.010, 1.0),
			Color(1, 1, 1, 0.20))
	)
	return ctrl


static func palette(size: float = 24.0, color: Color = Color("f5f0e8")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var center: Vector2 = Vector2(size * 0.50, size * 0.50)
		## 1) М'яка тінь палітри
		_draw_soft_shadow(ctrl, center, size * 0.38, Color(0, 0, 0, 0.14))
		## 2) Палітра — кремова з градієнтом
		_draw_radial_gradient(ctrl, center, size * 0.38, pal.lighter, pal.dark, 5)
		## 3) Контур палітри
		_draw_outline(ctrl, center, size * 0.38, pal.darker, maxf(size * 0.03, 1.0))
		## 4) Глянець на палітрі
		_draw_gloss(ctrl, center, size * 0.38, 0.20)
		## Фарби — яскраві крапки з глянцем
		var paint_positions: Array[Vector2] = [
			Vector2(size * 0.35, size * 0.33),
			Vector2(size * 0.55, size * 0.28),
			Vector2(size * 0.68, size * 0.42),
			Vector2(size * 0.40, size * 0.58),
			Vector2(size * 0.60, size * 0.58),
		]
		var paint_colors: Array[Color] = [
			Color("ef476f"), Color("3b82f6"), Color("22c55e"),
			Color("FFD166"), Color("a78bfa"),
		]
		var paint_radii: Array[float] = [
			size * 0.07, size * 0.07, size * 0.07, size * 0.07, size * 0.06,
		]
		for pi: int in paint_positions.size():
			var pc: Vector2 = paint_positions[pi]
			var pr: float = maxf(paint_radii[pi], 2.0)
			var pcol: Color = paint_colors[pi]
			## Тінь під фарбою
			ctrl.draw_circle(pc + Vector2(0.5, 1.0), pr, Color(pcol.darkened(0.3), 0.3))
			## Фарба з градієнтом
			ctrl.draw_circle(pc, pr, pcol)
			ctrl.draw_circle(pc, pr * 0.6, pcol.lightened(0.15))
			## Блік на фарбі
			ctrl.draw_circle(pc + Vector2(-pr * 0.25, -pr * 0.25),
				maxf(pr * 0.3, 1.0), Color(1, 1, 1, 0.40))
		## 5) Отвір для пальця — з градієнтом
		var hole_c: Vector2 = Vector2(size * 0.28, size * 0.62)
		var hole_r: float = maxf(size * 0.07, 2.5)
		_draw_radial_gradient(ctrl, hole_c, hole_r, Color("c4b8a0"), Color("d4c8b0"), 4)
		_draw_outline(ctrl, hole_c, hole_r, pal.darker, maxf(size * 0.02, 0.5))
	)
	return ctrl


static func recycle_icon(size: float = 24.0, color: Color = Color("22c55e")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.5
		var r: float = size * 0.28
		var w: float = maxf(size * 0.07, 1.5)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(cx, cy), r)
		## 2) Дуги з 2-тоновим градієнтом (тінь + основна)
		ctrl.draw_arc(Vector2(cx, cy), r,
			-PI * 0.5, PI * 0.3, 12, pal["dark"], w * 1.3, true)
		ctrl.draw_arc(Vector2(cx, cy), r,
			-PI * 0.5, PI * 0.3, 12, pal["light"], w, true)
		ctrl.draw_arc(Vector2(cx, cy), r,
			PI * 0.5, PI * 1.3, 12, pal["dark"], w * 1.3, true)
		ctrl.draw_arc(Vector2(cx, cy), r,
			PI * 0.5, PI * 1.3, 12, pal["light"], w, true)
		ctrl.draw_arc(Vector2(cx, cy), r,
			PI * 1.5, PI * 2.3, 12, pal["dark"], w * 1.3, true)
		ctrl.draw_arc(Vector2(cx, cy), r,
			PI * 1.5, PI * 2.3, 12, pal["light"], w, true)
		## 3) Стрілки з градієнтом (база + блік)
		var a1: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.72, size * 0.30),
			Vector2(size * 0.82, size * 0.40),
			Vector2(size * 0.68, size * 0.40),
		])
		ctrl.draw_colored_polygon(a1, pal["dark"])
		ctrl.draw_colored_polygon(PackedVector2Array([
			Vector2(size * 0.73, size * 0.32),
			Vector2(size * 0.79, size * 0.38),
			Vector2(size * 0.70, size * 0.38),
		]), pal["lighter"])
		var a2: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.28, size * 0.70),
			Vector2(size * 0.18, size * 0.60),
			Vector2(size * 0.32, size * 0.60),
		])
		ctrl.draw_colored_polygon(a2, pal["dark"])
		ctrl.draw_colored_polygon(PackedVector2Array([
			Vector2(size * 0.27, size * 0.68),
			Vector2(size * 0.21, size * 0.62),
			Vector2(size * 0.31, size * 0.62),
		]), pal["lighter"])
		var a3: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.50, size * 0.18),
			Vector2(size * 0.42, size * 0.28),
			Vector2(size * 0.58, size * 0.28),
		])
		ctrl.draw_colored_polygon(a3, pal["dark"])
		ctrl.draw_colored_polygon(PackedVector2Array([
			Vector2(size * 0.50, size * 0.20),
			Vector2(size * 0.44, size * 0.27),
			Vector2(size * 0.56, size * 0.27),
		]), pal["lighter"])
		## 4) Глянцевий блік
		_draw_gloss(ctrl, Vector2(cx, cy), r, 0.22)
		## 5) Мікро-деталь: leaf dot (зелена крапка-листочок)
		var leaf_r: float = maxf(size * 0.03, 1.0)
		ctrl.draw_circle(Vector2(cx, cy), leaf_r, pal["lighter"])
		ctrl.draw_circle(Vector2(cx - leaf_r * 0.4, cy - leaf_r * 0.4),
			leaf_r * 0.5, Color(1, 1, 1, 0.4))
	)
	return ctrl


static func chess_knight(size: float = 24.0, color: Color = Color("5c4033")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		## 1) М'яка тінь під фігурою
		_draw_soft_shadow(ctrl, Vector2(size * 0.5, size * 0.78), size * 0.25)
		## 2) Підставка з градієнтом
		ctrl.draw_rect(Rect2(size * 0.26, size * 0.81, size * 0.48, size * 0.09),
			pal["darker"], true)
		ctrl.draw_rect(Rect2(size * 0.28, size * 0.80, size * 0.44, size * 0.04),
			pal["dark"], true)
		ctrl.draw_line(Vector2(size * 0.28, size * 0.80),
			Vector2(size * 0.72, size * 0.80), pal["lighter"],
			maxf(size * 0.015, 1.0), true)
		## Тіло коня — основний полігон
		var body: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.35, size * 0.80),
			Vector2(size * 0.65, size * 0.80),
			Vector2(size * 0.62, size * 0.50),
			Vector2(size * 0.68, size * 0.35),
			Vector2(size * 0.60, size * 0.18),
			Vector2(size * 0.45, size * 0.12),
			Vector2(size * 0.32, size * 0.22),
			Vector2(size * 0.28, size * 0.40),
			Vector2(size * 0.38, size * 0.50),
		])
		ctrl.draw_colored_polygon(body, pal["base"])
		## 3) Блік — передня сторона (глибина)
		var highlight: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.34, size * 0.22),
			Vector2(size * 0.40, size * 0.50),
			Vector2(size * 0.35, size * 0.78),
			Vector2(size * 0.30, size * 0.50),
		])
		ctrl.draw_colored_polygon(highlight, pal["light"])
		## Тіньова сторона (задня частина)
		var shadow_side: PackedVector2Array = PackedVector2Array([
			Vector2(size * 0.55, size * 0.78),
			Vector2(size * 0.65, size * 0.78),
			Vector2(size * 0.62, size * 0.50),
			Vector2(size * 0.68, size * 0.35),
			Vector2(size * 0.60, size * 0.20),
		])
		ctrl.draw_colored_polygon(shadow_side, pal["dark"])
		## 4) Wood grain текстура — тонкі лінії
		var grain_w: float = maxf(size * 0.012, 0.5)
		var grain_col: Color = Color(pal["dark"], 0.25)
		ctrl.draw_line(Vector2(size * 0.38, size * 0.35),
			Vector2(size * 0.58, size * 0.30), grain_col, grain_w, true)
		ctrl.draw_line(Vector2(size * 0.36, size * 0.50),
			Vector2(size * 0.60, size * 0.48), grain_col, grain_w, true)
		ctrl.draw_line(Vector2(size * 0.37, size * 0.65),
			Vector2(size * 0.62, size * 0.63), grain_col, grain_w, true)
		## 5) Мікро-деталі: грива
		var mane_w: float = maxf(size * 0.02, 1.0)
		ctrl.draw_line(Vector2(size * 0.52, size * 0.14),
			Vector2(size * 0.58, size * 0.22), pal["darker"], mane_w, true)
		ctrl.draw_line(Vector2(size * 0.55, size * 0.18),
			Vector2(size * 0.62, size * 0.28), pal["darker"], mane_w, true)
		ctrl.draw_line(Vector2(size * 0.58, size * 0.24),
			Vector2(size * 0.65, size * 0.32), pal["darker"], mane_w, true)
		## Око з глибиною
		ctrl.draw_circle(Vector2(size * 0.48, size * 0.25), size * 0.045,
			Color(1, 1, 1, 0.85))
		ctrl.draw_circle(Vector2(size * 0.48, size * 0.25), size * 0.025,
			Color("2d3436"))
		ctrl.draw_circle(Vector2(size * 0.47, size * 0.24), maxf(size * 0.01, 0.5),
			Color(1, 1, 1, 0.6))
		## Ніздря
		ctrl.draw_circle(Vector2(size * 0.34, size * 0.32), maxf(size * 0.015, 0.8),
			pal["darker"])
	)
	return ctrl


static func target(size: float = 24.0, color: Color = Color("ef476f")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.5
		var white: Color = Color("f5f5f5")
		var white_pal: Dictionary = _color_palette(white)
		## 1) М'яка тінь за мішенню
		_draw_soft_shadow(ctrl, Vector2(cx, cy), size * 0.38)
		## 2) Кільця з градієнтами (зовнішнє → внутрішнє)
		_draw_radial_gradient(ctrl, Vector2(cx, cy), size * 0.38,
			pal["base"], pal["dark"], 5)
		_draw_radial_gradient(ctrl, Vector2(cx, cy), size * 0.30,
			white_pal["base"], white_pal["dark"], 4)
		_draw_radial_gradient(ctrl, Vector2(cx, cy), size * 0.22,
			pal["light"], pal["dark"], 4)
		_draw_radial_gradient(ctrl, Vector2(cx, cy), size * 0.14,
			white_pal["base"], white_pal["dark"], 3)
		## 3) Центральна крапка — 3-кільцевий градієнт
		_draw_radial_gradient(ctrl, Vector2(cx, cy), size * 0.07,
			pal["lighter"], pal["darker"], 4)
		## 4) Контури кілець
		var ring_w: float = maxf(size * 0.015, 0.8)
		_draw_outline(ctrl, Vector2(cx, cy), size * 0.38, pal["darker"], ring_w)
		_draw_outline(ctrl, Vector2(cx, cy), size * 0.30, Color(0.8, 0.8, 0.8, 0.4), ring_w * 0.7)
		_draw_outline(ctrl, Vector2(cx, cy), size * 0.22, pal["darker"], ring_w * 0.7)
		## 5) Глянцевий блік
		_draw_gloss(ctrl, Vector2(cx, cy), size * 0.36, 0.25)
	)
	return ctrl


static func letters_icon(size: float = 24.0, _color: Color = Color("3b82f6")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var w: float = maxf(size * 0.07, 1.5)
		## Кольори літер
		var ca: Color = Color("ef476f")
		var ca_dark: Color = ca.darkened(0.30)
		var ca_light: Color = ca.lightened(0.25)
		var cb: Color = Color("3b82f6")
		var cb_dark: Color = cb.darkened(0.30)
		var cb_light: Color = cb.lightened(0.25)
		var ax: float = size * 0.28
		var sh: float = maxf(size * 0.02, 0.8)
		## 1) Тінь "A" — зсунутий темний штрих
		var sh_off: Vector2 = Vector2(sh, sh)
		ctrl.draw_line(Vector2(ax, size * 0.72) + sh_off,
			Vector2(ax - size * 0.12, size * 0.72) + sh_off, ca_dark, w, true)
		ctrl.draw_line(Vector2(ax - size * 0.12, size * 0.72) + sh_off,
			Vector2(ax, size * 0.22) + sh_off, ca_dark, w * 1.2, true)
		ctrl.draw_line(Vector2(ax, size * 0.22) + sh_off,
			Vector2(ax + size * 0.12, size * 0.72) + sh_off, ca_dark, w * 1.2, true)
		## 2) Основний штрих "A"
		ctrl.draw_line(Vector2(ax, size * 0.72), Vector2(ax - size * 0.12, size * 0.72),
			ca, w, true)
		ctrl.draw_line(Vector2(ax - size * 0.12, size * 0.72), Vector2(ax, size * 0.22),
			ca, w * 1.2, true)
		ctrl.draw_line(Vector2(ax, size * 0.22), Vector2(ax + size * 0.12, size * 0.72),
			ca, w * 1.2, true)
		ctrl.draw_line(Vector2(ax - size * 0.06, size * 0.52),
			Vector2(ax + size * 0.06, size * 0.52), ca, w * 0.8, true)
		## 3) Світлий блік "A" — зсунутий вгору-вліво
		var hl_off: Vector2 = Vector2(-sh * 0.5, -sh * 0.5)
		ctrl.draw_line(Vector2(ax - size * 0.12, size * 0.72) + hl_off,
			Vector2(ax, size * 0.22) + hl_off, ca_light, maxf(w * 0.4, 1.0), true)
		## Тінь "a"
		var bx: float = size * 0.65
		var by: float = size * 0.55
		ctrl.draw_arc(Vector2(bx, by + size * 0.08) + sh_off, size * 0.10,
			0, TAU, 10, cb_dark, w, true)
		ctrl.draw_line(Vector2(bx + size * 0.10, by - size * 0.02) + sh_off,
			Vector2(bx + size * 0.10, by + size * 0.18) + sh_off, cb_dark, w, true)
		## 4) Основний штрих "a"
		ctrl.draw_arc(Vector2(bx, by + size * 0.08), size * 0.10,
			0, TAU, 10, cb, w, true)
		ctrl.draw_line(Vector2(bx + size * 0.10, by - size * 0.02),
			Vector2(bx + size * 0.10, by + size * 0.18), cb, w, true)
		## Світлий блік "a"
		ctrl.draw_arc(Vector2(bx, by + size * 0.08) + hl_off, size * 0.10,
			-PI * 0.5, PI * 0.3, 6, cb_light, maxf(w * 0.4, 1.0), true)
		## 5) Декоративна крапка між літерами
		var dot_r: float = maxf(size * 0.03, 1.2)
		ctrl.draw_circle(Vector2(size * 0.47, size * 0.75), dot_r, Color("FFD166"))
		ctrl.draw_circle(
			Vector2(size * 0.47 - dot_r * 0.3, size * 0.75 - dot_r * 0.3),
			maxf(dot_r * 0.4, 0.8), Color(1, 1, 1, 0.45))
	)
	return ctrl


static func planet(size: float = 24.0, color: Color = Color("a78bfa")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.5
		var center: Vector2 = Vector2(cx, cy)
		var pr: float = size * 0.28
		var w: float = maxf(size * 0.04, 1.0)
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, center, pr)
		## 2) Сфера — 4-кільцевий радіальний градієнт
		_draw_radial_gradient(ctrl, center, pr, pal.light, pal.darker, 6)
		## 3) Кратери — темні плями з підсвіткою
		var crater1_c: Vector2 = Vector2(cx + size * 0.08, cy + size * 0.06)
		var crater1_r: float = maxf(size * 0.06, 1.5)
		ctrl.draw_circle(crater1_c, crater1_r, pal.darker)
		ctrl.draw_circle(
			Vector2(crater1_c.x - crater1_r * 0.3, crater1_c.y - crater1_r * 0.3),
			maxf(crater1_r * 0.4, 0.8), Color(1, 1, 1, 0.12))
		var crater2_c: Vector2 = Vector2(cx - size * 0.10, cy - size * 0.04)
		var crater2_r: float = maxf(size * 0.04, 1.2)
		ctrl.draw_circle(crater2_c, crater2_r, pal.dark)
		## Атмосферне свічення — зовнішній ореол
		ctrl.draw_arc(center, pr + maxf(size * 0.02, 1.0),
			0, TAU, 20, Color(pal.lighter, 0.20), maxf(size * 0.03, 1.0), true)
		ctrl.draw_arc(center, pr + maxf(size * 0.04, 1.5),
			0, TAU, 20, Color(pal.lighter, 0.10), maxf(size * 0.02, 0.8), true)
		## 4) Градієнтне кільце — 3 дуги з різною яскравістю
		var ring_r: float = size * 0.40
		ctrl.draw_arc(center, ring_r,
			-0.3, PI * 0.5, 12, pal.dark, w * 1.2, true)
		ctrl.draw_arc(center, ring_r,
			PI * 0.5 - 0.3, PI * 0.5, 12, color, w * 1.5, true)
		ctrl.draw_arc(center, ring_r,
			PI - 0.3, PI * 0.5 + 0.3, 12, pal.lighter, w * 1.8, true)
		## 5) Глянцевий блік на сфері
		_draw_gloss(ctrl, center, pr, 0.28)
	)
	return ctrl


static func weather_sun(size: float = 24.0, color: Color = Color("FFD166")) -> Control:
	return sun_icon(size, color)


## ---- Fruit Icons ----


## Apple — червоне яблуко з листочком і стеблом.
static func apple(size: float = 24.0, color: Color = Color("ff6b6b")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.55
		var r: float = size * 0.32
		## 1) Тінь
		_draw_soft_shadow(ctrl, Vector2(cx, cy), r)
		## 2) Тіло — dark
		ctrl.draw_circle(Vector2(cx, cy), r, pal["dark"])
		## 3) Блік — light зверху-зліва
		ctrl.draw_circle(Vector2(cx - r * 0.25, cy - r * 0.25), r * 0.45, pal["light"])
		## 4) Стебло
		var stem_w: float = maxf(size * 0.04, 1.5)
		ctrl.draw_line(Vector2(cx, cy - r), Vector2(cx, cy - r - size * 0.12),
			Color("8B4513"), stem_w)
		## 5) Листочок з палітрою
		var leaf_c: Color = Color("4CAF50")
		var leaf_pal: Dictionary = _color_palette(leaf_c)
		var leaf_pts: PackedVector2Array = PackedVector2Array([
			Vector2(cx, cy - r - size * 0.08),
			Vector2(cx + size * 0.12, cy - r - size * 0.18),
			Vector2(cx + size * 0.04, cy - r - size * 0.02),
		])
		ctrl.draw_colored_polygon(leaf_pts, leaf_pal["base"])
		## 6) Sparkle
		ctrl.draw_circle(Vector2(cx - r * 0.20, cy - r * 0.30), maxf(size * 0.02, 1.0),
			Color(1, 1, 1, 0.50))
	)
	return ctrl


## Banana — жовтий банан у формі півмісяця (premium pipeline).
static func banana_fruit(size: float = 24.0, color: Color = Color("ffd166")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.5
		var r: float = size * 0.3
		var w: float = maxf(size * 0.14, 3.0)
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.04, 1.0))
		var center: Vector2 = Vector2(cx + size * 0.05, cy)
		## 1) Shadow arc
		ctrl.draw_arc(center + sh, r, 0.4, PI + 0.2, 20, pal["shadow"], w + 1.0, true)
		## 2) Dark base arc
		ctrl.draw_arc(center, r, 0.4, PI + 0.2, 20, pal["dark"], w, true)
		## 3) Light overlay arc (thinner)
		ctrl.draw_arc(center - Vector2(0, size * 0.02), r, 0.5, PI, 18,
			pal["light"], maxf(w * 0.5, 2.0), true)
		## 4) Tip — dark dot
		var tip_r: float = maxf(size * 0.04, 1.5)
		var start_x: float = cx + size * 0.05 + r * cos(0.4)
		var start_y: float = cy + r * sin(0.4)
		ctrl.draw_circle(Vector2(start_x, start_y), tip_r, pal["darker"])
		## 5) Sparkle
		ctrl.draw_circle(Vector2(cx - size * 0.05, cy - r * 0.4),
			maxf(size * 0.02, 1.0), Color(1, 1, 1, 0.45))
	)
	return ctrl


## Orange — апельсин з точкою зверху і листочком (premium pipeline).
static func orange_fruit(size: float = 24.0, color: Color = Color("ff9f1c")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.55
		var r: float = size * 0.32
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.04, 1.0))
		## 1) Soft shadow
		ctrl.draw_circle(Vector2(cx, cy) + sh, r + 1.0, pal["shadow"])
		## 2) Dark base body
		ctrl.draw_circle(Vector2(cx, cy), r, pal["dark"])
		## 3) Light glare (upper-left)
		ctrl.draw_circle(Vector2(cx - r * 0.25, cy - r * 0.25), r * 0.55, pal["light"])
		## 4) Пупок — darker dot
		ctrl.draw_circle(Vector2(cx, cy - r + size * 0.04), maxf(size * 0.03, 1.0),
			pal["darker"])
		## 5) Листочок з палітрою
		var leaf_c: Color = Color("66BB6A")
		var leaf_pal: Dictionary = _color_palette(leaf_c)
		var leaf_pts: PackedVector2Array = PackedVector2Array([
			Vector2(cx - size * 0.02, cy - r),
			Vector2(cx + size * 0.12, cy - r - size * 0.14),
			Vector2(cx + size * 0.06, cy - r + size * 0.02),
		])
		ctrl.draw_colored_polygon(leaf_pts, leaf_pal["dark"])
		## Inner lighter leaf
		var inner_leaf: PackedVector2Array = PackedVector2Array([
			Vector2(cx, cy - r + size * 0.01),
			Vector2(cx + size * 0.09, cy - r - size * 0.10),
			Vector2(cx + size * 0.05, cy - r + size * 0.01),
		])
		ctrl.draw_colored_polygon(inner_leaf, leaf_pal["light"])
		## 6) Sparkle
		ctrl.draw_circle(Vector2(cx - r * 0.30, cy - r * 0.35),
			maxf(size * 0.02, 1.0), Color(1, 1, 1, 0.50))
	)
	return ctrl


## Grape — гроно винограду з 5 ягід у трикутному патерні (premium pipeline).
static func grape_cluster(size: float = 24.0, color: Color = Color("a855f7")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var berry_r: float = size * 0.11
		var gap: float = size * 0.20
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.04, 1.0))
		var glare_r: float = berry_r * 0.45
		var glare_off: Vector2 = Vector2(-berry_r * 0.25, -berry_r * 0.30)
		## Berry positions
		var positions: Array[Vector2] = [
			Vector2(cx, size * 0.3),
			Vector2(cx - gap * 0.5, size * 0.3 + gap * 0.85),
			Vector2(cx + gap * 0.5, size * 0.3 + gap * 0.85),
			Vector2(cx - gap * 0.25, size * 0.3 + gap * 1.7),
			Vector2(cx + gap * 0.25, size * 0.3 + gap * 1.7),
		]
		## 1) Shadow circles
		for pos: Vector2 in positions:
			ctrl.draw_circle(pos + sh, berry_r + 0.5, pal["shadow"])
		## 2) Dark base berries
		for pos: Vector2 in positions:
			ctrl.draw_circle(pos, berry_r, pal["dark"])
		## 3) Light glare on each berry
		for pos: Vector2 in positions:
			ctrl.draw_circle(pos + glare_off, glare_r, pal["light"])
		## 4) Stem з палітрою
		var stem_c: Color = Color("8B4513")
		var stem_pal: Dictionary = _color_palette(stem_c)
		var stem_w: float = maxf(size * 0.03, 1.0)
		ctrl.draw_line(
			Vector2(cx, size * 0.3 - berry_r) + sh,
			Vector2(cx, size * 0.12) + sh,
			stem_pal["shadow"], stem_w)
		ctrl.draw_line(
			Vector2(cx, size * 0.3 - berry_r),
			Vector2(cx, size * 0.12),
			stem_pal["dark"], stem_w)
		## 5) Sparkle on top berry
		ctrl.draw_circle(positions[0] + glare_off * 0.5,
			maxf(size * 0.02, 1.0), Color(1, 1, 1, 0.50))
	)
	return ctrl


## Watermelon — скибка кавуна (зелена шкірка, рожева м'якоть, насіння) (premium pipeline).
static func watermelon_slice(size: float = 24.0, color: Color = Color("06d6a0")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.6
		var r: float = size * 0.36
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.04, 1.0))
		## 1) Shadow rind
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(17):
			var angle: float = PI + (float(i) / 16.0) * PI
			shadow_pts.append(Vector2(cx + r * cos(angle), cy + r * sin(angle)) + sh)
		ctrl.draw_colored_polygon(shadow_pts, pal["shadow"])
		## 2) Dark rind base
		var rind_pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(17):
			var angle: float = PI + (float(i) / 16.0) * PI
			rind_pts.append(Vector2(cx + r * cos(angle), cy + r * sin(angle)))
		ctrl.draw_colored_polygon(rind_pts, pal["dark"])
		## 3) Light rind top
		var light_rind: PackedVector2Array = PackedVector2Array()
		for i: int in range(17):
			var angle: float = PI + (float(i) / 16.0) * PI
			light_rind.append(Vector2(cx + r * 0.95 * cos(angle), cy + r * 0.95 * sin(angle) - size * 0.01))
		ctrl.draw_colored_polygon(light_rind, pal["light"])
		## 4) Flesh з палітрою
		var flesh_c: Color = Color("ff6b81")
		var flesh_pal: Dictionary = _color_palette(flesh_c)
		var flesh_r: float = r * 0.82
		var flesh_pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(17):
			var angle: float = PI + (float(i) / 16.0) * PI
			flesh_pts.append(Vector2(cx + flesh_r * cos(angle), cy + flesh_r * sin(angle)))
		ctrl.draw_colored_polygon(flesh_pts, flesh_pal["dark"])
		## Inner lighter flesh
		var inner_r: float = flesh_r * 0.7
		var inner_pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(17):
			var angle: float = PI + (float(i) / 16.0) * PI
			inner_pts.append(Vector2(cx + inner_r * cos(angle), cy + inner_r * sin(angle) - size * 0.02))
		ctrl.draw_colored_polygon(inner_pts, flesh_pal["light"])
		## 5) Seeds — darker dots
		var seed_r: float = maxf(size * 0.025, 1.0)
		var seed_c: Color = Color("333333")
		ctrl.draw_circle(Vector2(cx - size * 0.1, cy - size * 0.08), seed_r, seed_c)
		ctrl.draw_circle(Vector2(cx + size * 0.1, cy - size * 0.08), seed_r, seed_c)
		ctrl.draw_circle(Vector2(cx, cy - size * 0.16), seed_r, seed_c)
		## 6) Sparkle
		ctrl.draw_circle(Vector2(cx - r * 0.3, cy - r * 0.4),
			maxf(size * 0.02, 1.0), Color(1, 1, 1, 0.45))
	)
	return ctrl


## ---- Trash Icons ----


## Paper — аркуш паперу зі загнутим кутом і лініями тексту (premium pipeline).
static func paper_sheet(size: float = 24.0, color: Color = Color("90caf9")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var x0: float = size * 0.2
		var y0: float = size * 0.1
		var w: float = size * 0.6
		var h: float = size * 0.78
		var fold: float = size * 0.14
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.04, 1.0))
		## Sheet shape
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(x0, y0),
			Vector2(x0 + w - fold, y0),
			Vector2(x0 + w, y0 + fold),
			Vector2(x0 + w, y0 + h),
			Vector2(x0, y0 + h),
		])
		## 1) Shadow sheet
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for pt: Vector2 in pts:
			shadow_pts.append(pt + sh)
		ctrl.draw_colored_polygon(shadow_pts, pal["shadow"])
		## 2) Dark base sheet
		ctrl.draw_colored_polygon(pts, pal["dark"])
		## 3) Light top area
		ctrl.draw_rect(Rect2(x0 + 1.0, y0 + 1.0, w - fold - 1.0, h * 0.4), pal["light"])
		## 4) Fold triangle — darker
		var fold_pts: PackedVector2Array = PackedVector2Array([
			Vector2(x0 + w - fold, y0),
			Vector2(x0 + w, y0 + fold),
			Vector2(x0 + w - fold, y0 + fold),
		])
		ctrl.draw_colored_polygon(fold_pts, pal["darker"])
		## 5) Text lines — darker color
		var line_w: float = maxf(size * 0.03, 1.0)
		for i: int in range(3):
			var ly: float = y0 + size * 0.28 + float(i) * size * 0.16
			ctrl.draw_line(
				Vector2(x0 + size * 0.08, ly),
				Vector2(x0 + w - size * 0.08, ly),
				pal["darker"], line_w)
		## 6) Outline
		ctrl.draw_polyline(pts, pal["darker"], maxf(size * 0.02, 1.0), true)
		## 7) Sparkle
		ctrl.draw_circle(Vector2(x0 + size * 0.12, y0 + size * 0.12),
			maxf(size * 0.02, 1.0), Color(1, 1, 1, 0.45))
	)
	return ctrl


## Plastic — пластикова пляшка з горлечком і корпусом (premium pipeline).
static func plastic_bottle(size: float = 24.0, color: Color = Color("ce93d8")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.04, 1.0))
		var neck_w: float = size * 0.14
		var neck_h: float = size * 0.18
		var cap_w: float = size * 0.18
		var cap_h: float = size * 0.08
		var body_w: float = size * 0.38
		var body_h: float = size * 0.52
		var body_y: float = size * 0.1 + neck_h
		## 1) Shadow body
		ctrl.draw_rect(Rect2(cx - body_w * 0.5 + sh.x, body_y + sh.y,
			body_w, body_h), pal["shadow"])
		## 2) Dark base body
		ctrl.draw_rect(Rect2(cx - body_w * 0.5, body_y,
			body_w, body_h), pal["dark"])
		## 3) Light gradient top half
		ctrl.draw_rect(Rect2(cx - body_w * 0.5 + 1.0, body_y + 1.0,
			body_w * 0.5, body_h * 0.4), pal["light"])
		## 4) Neck — base color
		ctrl.draw_rect(Rect2(cx - neck_w * 0.5, size * 0.1,
			neck_w, neck_h), pal["base"])
		## 5) Cap — darker
		ctrl.draw_rect(Rect2(cx - cap_w * 0.5, size * 0.06,
			cap_w, cap_h), pal["darker"])
		## 6) Label — lighter stripe
		var label_h: float = size * 0.12
		ctrl.draw_rect(Rect2(cx - body_w * 0.5 + size * 0.02,
			body_y + body_h * 0.35,
			body_w - size * 0.04, label_h), pal["lighter"])
		## 7) Body outline
		var lw: float = maxf(size * 0.02, 1.0)
		ctrl.draw_rect(Rect2(cx - body_w * 0.5, body_y,
			body_w, body_h), pal["darker"], false, lw)
		## 8) Sparkle
		ctrl.draw_circle(Vector2(cx - body_w * 0.25, body_y + body_h * 0.15),
			maxf(size * 0.02, 1.0), Color(1, 1, 1, 0.45))
	)
	return ctrl


## Glass — скляна чашка (трапеція, ширша зверху + ніжка) (premium pipeline).
static func glass_cup(size: float = 24.0, color: Color = Color("a5d6a7")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var top_w: float = size * 0.44
		var bot_w: float = size * 0.26
		var cup_top: float = size * 0.12
		var cup_bot: float = size * 0.62
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.04, 1.0))
		## Cup shape
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(cx - top_w * 0.5, cup_top),
			Vector2(cx + top_w * 0.5, cup_top),
			Vector2(cx + bot_w * 0.5, cup_bot),
			Vector2(cx - bot_w * 0.5, cup_bot),
		])
		## 1) Shadow cup
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for pt: Vector2 in pts:
			shadow_pts.append(pt + sh)
		ctrl.draw_colored_polygon(shadow_pts, pal["shadow"])
		## 2) Dark base cup
		ctrl.draw_colored_polygon(pts, pal["dark"])
		## 3) Light glare stripe (left side)
		var glare_pts: PackedVector2Array = PackedVector2Array([
			Vector2(cx - top_w * 0.5 + size * 0.04, cup_top + 2.0),
			Vector2(cx - top_w * 0.5 + size * 0.14, cup_top + 2.0),
			Vector2(cx - bot_w * 0.5 + size * 0.10, cup_bot - 2.0),
			Vector2(cx - bot_w * 0.5 + size * 0.02, cup_bot - 2.0),
		])
		ctrl.draw_colored_polygon(glare_pts, pal["light"])
		## 4) Cup outline
		var lw: float = maxf(size * 0.02, 1.0)
		ctrl.draw_polyline(pts, pal["darker"], lw, true)
		## 5) Stem — darker
		var stem_w: float = maxf(size * 0.04, 1.5)
		ctrl.draw_line(Vector2(cx, cup_bot), Vector2(cx, size * 0.78),
			pal["darker"], stem_w)
		## 6) Base — darker
		var base_w: float = size * 0.28
		ctrl.draw_line(
			Vector2(cx - base_w * 0.5, size * 0.78),
			Vector2(cx + base_w * 0.5, size * 0.78),
			pal["darker"], stem_w)
		## 7) Sparkle
		ctrl.draw_circle(Vector2(cx - top_w * 0.2, cup_top + size * 0.08),
			maxf(size * 0.02, 1.0), Color(1, 1, 1, 0.50))
	)
	return ctrl


## Organic — органічне лушпиння (вигнута органічна форма) (premium pipeline).
static func organic_peel(size: float = 24.0, color: Color = Color("ffcc80")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var pal: Dictionary = _color_palette(color)
		var cx: float = size * 0.5
		var cy: float = size * 0.5
		var sh: Vector2 = Vector2(maxf(size * 0.04, 1.0), maxf(size * 0.04, 1.0))
		## Organic shape points
		var pts: PackedVector2Array = PackedVector2Array()
		pts.append(Vector2(cx - size * 0.28, cy + size * 0.05))
		pts.append(Vector2(cx - size * 0.2, cy - size * 0.18))
		pts.append(Vector2(cx - size * 0.05, cy - size * 0.25))
		pts.append(Vector2(cx + size * 0.12, cy - size * 0.2))
		pts.append(Vector2(cx + size * 0.25, cy - size * 0.08))
		pts.append(Vector2(cx + size * 0.28, cy + size * 0.1))
		pts.append(Vector2(cx + size * 0.15, cy + size * 0.22))
		pts.append(Vector2(cx - size * 0.05, cy + size * 0.25))
		pts.append(Vector2(cx - size * 0.22, cy + size * 0.18))
		## 1) Shadow
		var shadow_pts: PackedVector2Array = PackedVector2Array()
		for pt: Vector2 in pts:
			shadow_pts.append(pt + sh)
		ctrl.draw_colored_polygon(shadow_pts, pal["shadow"])
		## 2) Dark base
		ctrl.draw_colored_polygon(pts, pal["dark"])
		## 3) Light inner highlight
		var inner_pts: PackedVector2Array = PackedVector2Array()
		for pt: Vector2 in pts:
			var dir: Vector2 = (Vector2(cx, cy) - pt).normalized()
			inner_pts.append(pt + dir * size * 0.04)
		ctrl.draw_colored_polygon(inner_pts, pal["light"])
		## 4) Veins — darker lines
		var vein_w: float = maxf(size * 0.02, 1.0)
		ctrl.draw_line(
			Vector2(cx - size * 0.18, cy),
			Vector2(cx + size * 0.18, cy),
			pal["darker"], vein_w)
		ctrl.draw_line(
			Vector2(cx - size * 0.05, cy - size * 0.15),
			Vector2(cx + size * 0.05, cy + size * 0.15),
			pal["darker"], vein_w)
		## 5) Outline
		ctrl.draw_polyline(pts, pal["darker"], maxf(size * 0.02, 1.0), true)
		## 6) Sparkle
		ctrl.draw_circle(Vector2(cx - size * 0.10, cy - size * 0.12),
			maxf(size * 0.02, 1.0), Color(1, 1, 1, 0.45))
	)
	return ctrl


## ---- Fruit & Trash Dispatchers ----


## Повертає іконку фрукта за рядковим ID.
static func fruit_icon(fruit_type: String, size: float = 24.0) -> Control:
	match fruit_type:
		"apple": return apple(size)
		"banana": return banana_fruit(size)
		"orange": return orange_fruit(size)
		"grape": return grape_cluster(size)
		"watermelon": return watermelon_slice(size)
		_:
			push_warning("IconDraw.fruit_icon: unknown fruit_type '%s'" % fruit_type)
			return apple(size)


## Повертає іконку сміття за рядковим ID.
static func trash_icon(trash_id: String, size: float = 24.0) -> Control:
	match trash_id:
		"paper": return paper_sheet(size)
		"plastic": return plastic_bottle(size)
		"glass": return glass_cup(size)
		"organic": return organic_peel(size)
		_:
			push_warning("IconDraw.trash_icon: unknown trash_id '%s'" % trash_id)
			return paper_sheet(size)


## Кубики — іконка для Toddler (малюки).
## 3 кольорові блоки L-подібним розташуванням із candy-глибиною.
static func building_blocks(size: float = 64.0, color: Color = Color("FF6B6B")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var s: float = size
		var block_w: float = s * 0.32
		var block_h: float = s * 0.28
		var colors: Array[Color] = [
			color,                        ## Червоний
			Color("4ECDC4"),              ## Бірюзовий
			Color("FFE66D"),              ## Жовтий
		]
		## Позиції блоків (L-подібне розташування)
		var positions: Array[Vector2] = [
			Vector2(s * 0.15, s * 0.60),  ## Нижній лівий
			Vector2(s * 0.50, s * 0.60),  ## Нижній правий
			Vector2(s * 0.15, s * 0.30),  ## Верхній лівий
		]
		for i: int in 3:
			var pal: Dictionary = _color_palette(colors[i])
			var pos: Vector2 = positions[i]
			## 1) Тінь
			ctrl.draw_rect(Rect2(pos.x + 2.0, pos.y + 3.0, block_w, block_h),
				Color(0, 0, 0, 0.15), true)
			## 2) Основа
			ctrl.draw_rect(Rect2(pos.x, pos.y, block_w, block_h), pal["base"], true)
			## 3) Глибина — нижній край темніший
			ctrl.draw_rect(Rect2(pos.x, pos.y + block_h * 0.75, block_w, block_h * 0.25),
				pal["dark"], true)
			## 4) Блік — верхній край
			ctrl.draw_rect(Rect2(pos.x + 2.0, pos.y + 2.0, block_w - 4.0, block_h * 0.2),
				pal["lighter"], true)
			## 5) Контур
			ctrl.draw_rect(Rect2(pos.x, pos.y, block_w, block_h),
				pal["darker"], false, maxf(s * 0.02, 1.0))
	)
	return ctrl


## Відкрита книга — іконка для Preschool (дошкільнята).
## Дві розкриті сторінки з лініями тексту та кольоровою обкладинкою.
static func open_book(size: float = 64.0, color: Color = Color("5B86E5")) -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(size, size)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.draw.connect(func() -> void:
		var s: float = size
		var pal: Dictionary = _color_palette(color)
		var cx: float = s * 0.50
		## 1) М'яка тінь
		_draw_soft_shadow(ctrl, Vector2(cx, s * 0.58), s * 0.30)
		## 2) Обкладинка (задній фон) — кольорова
		ctrl.draw_rect(Rect2(s * 0.10, s * 0.22, s * 0.80, s * 0.58),
			pal["dark"], true)
		## 3) Ліва сторінка — кремова
		var page_color: Color = Color("FFF8E7")
		ctrl.draw_rect(Rect2(s * 0.12, s * 0.24, s * 0.36, s * 0.52), page_color, true)
		## 4) Права сторінка — трохи темніша (тінь від згину)
		ctrl.draw_rect(Rect2(s * 0.52, s * 0.24, s * 0.36, s * 0.52),
			page_color.darkened(0.04), true)
		## 5) Лінії тексту на лівій сторінці
		var line_col: Color = Color(0.7, 0.7, 0.65, 0.5)
		var lw: float = maxf(s * 0.015, 1.0)
		for j: int in 4:
			var ly: float = s * (0.34 + j * 0.10)
			ctrl.draw_line(Vector2(s * 0.16, ly), Vector2(s * 0.44, ly), line_col, lw, true)
		## 6) Лінії тексту на правій сторінці
		for j: int in 4:
			var ly: float = s * (0.34 + j * 0.10)
			ctrl.draw_line(Vector2(s * 0.56, ly), Vector2(s * 0.84, ly), line_col, lw, true)
		## 7) Корінець книги
		ctrl.draw_line(Vector2(cx, s * 0.22), Vector2(cx, s * 0.76),
			pal["darker"], maxf(s * 0.03, 1.5), true)
		## 8) Блік на обкладинці зверху
		ctrl.draw_line(Vector2(s * 0.12, s * 0.24), Vector2(s * 0.88, s * 0.24),
			pal["lighter"], maxf(s * 0.02, 1.0), true)
	)
	return ctrl


## ---- Game Icon Dispatcher ----


## Повертає іконку за рядковим ID (для game_catalog.gd).
## Спочатку шукає HQ PNG-текстуру (LAW 28), fallback на код-малювання (LAW 7).
static func game_icon(icon_id: String, size: float = 56.0) -> Control:
	## HQ PNG-іконка (LAW 28 — Premium Visual Pipeline)
	var _png_path: String = "res://assets/textures/game_icons/icon_%s.png" % icon_id
	if ResourceLoader.exists(_png_path):
		var _tex: Texture2D = load(_png_path)
		var ctrl: Control = Control.new()
		ctrl.custom_minimum_size = Vector2(size, size)
		ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.draw.connect(func() -> void:
			ctrl.draw_texture_rect(_tex, Rect2(Vector2.ZERO, Vector2(size, size)), false)
		)
		return ctrl
	## Fallback: код-малювана іконка (LAW 7 — Sprite Fallback)
	match icon_id:
		"fork_knife": return fork_knife(size)
		"ghost": return ghost(size)
		"brain": return brain(size)
		"bubble": return bubble(size)
		"diamond": return diamond(size)
		"numbers": return numbers_icon(size)
		"puzzle": return puzzle_piece(size)
		"magnifier": return magnifier(size)
		"pencil": return pencil(size)
		"music_note": return music_note(size)
		"cycle": return cycle_arrows(size)
		"scales": return scales(size)
		"folder": return folder_icon(size)
		"ruler": return ruler(size)
		"factory": return factory(size)
		"soap": return soap(size)
		"weather": return sun_icon(size)
		"flag": return flag(size)
		"palette": return palette(size)
		"robot": return robot_head(size)
		"money": return money_bag(size)
		"recycle": return recycle_icon(size)
		"knight": return chess_knight(size)
		"beaker": return beaker(size)
		"target": return target(size)
		"letters": return letters_icon(size)
		"planet": return planet(size)
		"clock": return clock_face(size)
		"star": return star_5pt(size)
		"heart": return heart(size)
		"gear": return gear(size)
		"cart": return cart(size)
		"home": return home_house(size)
		"pine_tree": return pine_tree(size)
		"palm_tree": return palm_tree(size)
		"drum": return drum(size)
		"guitar": return guitar(size)
		"trumpet": return trumpet(size)
		"microphone": return microphone(size)
		"basket": return basket(size)
		"shirt": return shirt(size)
		"gift": return gift_box(size)
		"checkmark": return checkmark(size)
		"blocks": return building_blocks(size)
		"book": return open_book(size)
		_:
			push_warning("IconDraw.game_icon: unknown id '%s'" % icon_id)
			return star_5pt(size)
