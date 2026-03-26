extends BaseMiniGame

## "Голодна планета" — Hungry Planet!
## Планета = ЖИВИЙ ПЕРСОНАЖ з обличчям (emoji). Дитина ловить зірки та годує планету.
## Планета реагує ЕМОЦІЯМИ: очікування → їсть → щаслива → повна.
## Тап будь-куди = реакція. Тап планету = хихикає. Тап зірку = ловить.
## Кожні 3 улови — нова прикраса (кільце → місяць → корона → аура → СУПЕРПЛАНЕТА).
##
## Toddler (2-4): великі повільні зірки, тап = завжди успіх, без астероїдів.
## Preschool (4-7): швидші зірки + астероїди, золоті зірки = ×2.

const TOTAL_ROUNDS: int = 5
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0

## ---- Кольори ----
const PLANET_COLOR: Color = Color("6366f1")
const PLANET_FACE_COLOR: Color = Color(1, 1, 1, 0.95)
const STAR_COLOR: Color = Color("ffd166")
const SILVER_STAR_COLOR: Color = Color("e8eaf6")
const GOLD_STAR_COLOR: Color = Color("ffaa00")
const ASTEROID_COLOR: Color = Color("888888")
const RING_COLOR: Color = Color("ffd166")
const MOON_COLOR: Color = Color("e8eaf6")
const CROWN_COLOR: Color = Color("ffaa00")
const AURA_COLOR: Color = Color("a78bfa")

## ---- Розміри ----
const PLANET_RADIUS_TODDLER: float = 90.0
const PLANET_RADIUS_PRESCHOOL: float = 60.0
const STAR_TOUCH_RADIUS: float = 40.0

## ---- Швидкості (px/s) ----
const TODDLER_SPEED_MIN: float = 40.0
const TODDLER_SPEED_MAX: float = 60.0
const PRESCHOOL_SPEED_MIN: float = 70.0
const PRESCHOOL_SPEED_MAX: float = 110.0

## ---- Зірки на екрані одночасно ----
const TODDLER_STAR_COUNTS: Array[int] = [3, 3, 4, 4, 4]
const PRESCHOOL_STAR_COUNTS: Array[int] = [4, 5, 5, 6, 6]

## ---- Зірки для завершення раунду ----
const TODDLER_CATCHES_NEEDED: Array[int] = [3, 3, 4, 4, 5]
const PRESCHOOL_CATCHES_NEEDED: Array[int] = [5, 5, 6, 7, 8]

## ---- Астероїди (Preschool) ----
const PRESCHOOL_ASTEROID_COUNTS: Array[int] = [1, 1, 2, 2, 2]

## ---- Шанс появи різних типів зірок ----
const GOLD_STAR_CHANCE: float = 0.15
const SILVER_STAR_CHANCE: float = 0.20

## ---- Спавн ----
const SPAWN_MARGIN: float = 60.0
const OFFSCREEN_BUFFER: float = 80.0

## ---- Обертання зірок (рад/с) ----
const STAR_ROTATION_SPEED: float = 1.05  ## ~60°/s
const STAR_WOBBLE_AMP: float = 6.0  ## Амплітуда хитання по Y
const STAR_WOBBLE_FREQ: float = 2.0  ## Частота хитання

## ---- Емодзі обличчя планети ----
const FACE_WAITING: String = "😐"
const FACE_EXCITED: String = "😮"
const FACE_EATING: String = "😋"
const FACE_HAPPY: String = "😊"
const FACE_FULL: String = "🤩"
const FACE_SCARED: String = "😨"

## ---- Типи зірок ----
enum StarType { NORMAL, SILVER, GOLD }

## ---- Змінні стану ----
var _round: int = 0
var _start_time: float = 0.0
var _is_toddler: bool = false
var _game_time: float = 0.0  ## Загальний час для wobble/rotation

## Планета
var _planet_node: Node2D = null
var _planet_face: Label = null
var _planet_radius: float = 60.0
var _planet_center: Vector2 = Vector2.ZERO
var _breath_tween: Tween = null

## Прикраси планети
var _accessory_ring: Node2D = null
var _accessory_moon: Node2D = null
var _accessory_crown: Node2D = null
var _accessory_aura: Node2D = null
var _accessory_level: int = 0  ## 0-5: скільки прикрас показано

## Зірки та астероїди
## {node: Node2D, velocity: Vector2, type: StarType|"asteroid", size: float, base_y: float, phase: float}
var _floating_items: Array[Dictionary] = []

## Раундовий стан
var _catches_this_round: int = 0
var _catches_needed: int = 3
var _total_catches: int = 0  ## Сумарно за всю гру

## Лічильник зловлених
var _catch_label: Label = null

## Відстеження всіх створених нод для очищення
var _all_round_nodes: Array[Node] = []

## Idle hint timer
var _idle_timer: SceneTreeTimer = null

## Текстура зірки (кешована)
var _star_texture: Texture2D = null
var _has_star_texture: bool = false

## Прапорець анімації годування (блокує повторний catch під час fly-to-planet)
var _feeding_in_progress: bool = false


func _ready() -> void:
	game_id = "gravity_orbits"
	bg_theme = "space"
	_is_toddler = (SettingsManager.age_group == 1)
	_planet_radius = PLANET_RADIUS_TODDLER if _is_toddler else PLANET_RADIUS_PRESCHOOL
	super()
	_start_time = Time.get_ticks_msec() / 1000.0
	## Кешуємо текстуру зірки (LAW 7: sprite fallback)
	var star_tex_path: String = "res://assets/sprites/particles/star_04.png"
	if ResourceLoader.exists(star_tex_path):
		_star_texture = load(star_tex_path)
		_has_star_texture = true
	_apply_background()
	_build_hud()
	_start_round()
	## A2: гра ЗАВЖДИ завершується — safety timeout
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("ORBITS_TODDLER_TUTORIAL")
	return tr("ORBITS_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	## Показуємо tutorial hand на першій зірці
	for item: Dictionary in _floating_items:
		var node: Node2D = item.get("node") as Node2D
		var item_type: Variant = item.get("type", StarType.NORMAL)
		if node and is_instance_valid(node) and item_type != "asteroid":
			return {"type": "tap", "target": node.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ========== РАУНДИ ==========

func _start_round() -> void:
	_input_locked = true
	_catches_this_round = 0
	_feeding_in_progress = false
	var r: int = clampi(_round, 0, TOTAL_ROUNDS - 1)

	## Встановити кількість потрібних зловлених
	if _is_toddler:
		if r < TODDLER_CATCHES_NEEDED.size():
			_catches_needed = TODDLER_CATCHES_NEEDED[r]
		else:
			push_warning("gravity_orbits: TODDLER_CATCHES_NEEDED out of bounds, fallback")
			_catches_needed = 5
	else:
		if r < PRESCHOOL_CATCHES_NEEDED.size():
			_catches_needed = PRESCHOOL_CATCHES_NEEDED[r]
		else:
			push_warning("gravity_orbits: PRESCHOOL_CATCHES_NEEDED out of bounds, fallback")
			_catches_needed = 8

	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	_fade_instruction(_instruction_label, get_tutorial_instruction())

	var vp: Vector2 = get_viewport().get_visible_rect().size
	_planet_center = Vector2(vp.x * 0.5, vp.y * 0.5)

	## Планета в центрі (живий персонаж!)
	_spawn_planet(vp)

	## Лічильник зловлених
	_spawn_catch_label(vp)

	## Зірки
	var star_count: int = _get_star_count(r)
	_floating_items.clear()
	for i: int in star_count:
		_spawn_star(vp)

	## Астероїди (Preschool only)
	if not _is_toddler:
		var asteroid_count: int = _get_asteroid_count(r)
		for i: int in asteroid_count:
			_spawn_asteroid(vp)

	## Оркестрована поява
	_orchestrated_entrance(_all_round_nodes as Array, 0.07, false, "pop")
	var start_d: float = 0.15 if SettingsManager.reduced_motion else 0.55
	var tw: Tween = _create_game_tween()
	tw.tween_interval(start_d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _get_star_count(r: int) -> int:
	if _is_toddler:
		if r < TODDLER_STAR_COUNTS.size():
			return TODDLER_STAR_COUNTS[r]
		push_warning("gravity_orbits: TODDLER_STAR_COUNTS out of bounds, fallback")
		return 4
	else:
		if r < PRESCHOOL_STAR_COUNTS.size():
			return PRESCHOOL_STAR_COUNTS[r]
		push_warning("gravity_orbits: PRESCHOOL_STAR_COUNTS out of bounds, fallback")
		return 6


func _get_asteroid_count(r: int) -> int:
	if r < PRESCHOOL_ASTEROID_COUNTS.size():
		return PRESCHOOL_ASTEROID_COUNTS[r]
	push_warning("gravity_orbits: PRESCHOOL_ASTEROID_COUNTS out of bounds, fallback")
	return 2


## ========== ПЛАНЕТА (ЖИВИЙ ПЕРСОНАЖ) ==========

func _spawn_planet(vp: Vector2) -> void:
	_planet_node = Node2D.new()
	_planet_node.position = _planet_center
	add_child(_planet_node)

	var r: float = _planet_radius
	var sz: float = r * 2.0

	## Candy circle panel — тіло планети
	var panel: Panel = Panel.new()
	panel.size = Vector2(sz, sz)
	panel.position = Vector2(-r, -r)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",
		GameData.candy_circle(PLANET_COLOR, r))
	panel.material = GameData.create_premium_material(
		0.04, 2.0, 0.06, 0.10, 0.06, 0.05, 0.10, "", 0.0, 0.15, 0.30, 0.22)
	_planet_node.add_child(panel)

	## HQ текстура планети (якщо є)
	var planet_tex_path: String = "res://assets/textures/game_icons/icon_planet.png"
	if ResourceLoader.exists(planet_tex_path):
		var planet_tex: Texture2D = load(planet_tex_path)
		var icon_sz: float = sz * 0.85
		var tex_ctrl: Control = Control.new()
		tex_ctrl.size = Vector2(icon_sz, icon_sz)
		tex_ctrl.position = Vector2(-icon_sz * 0.5, -icon_sz * 0.5)
		tex_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_ctrl.draw.connect(func() -> void:
			tex_ctrl.draw_texture_rect(planet_tex,
				Rect2(Vector2.ZERO, Vector2(icon_sz, icon_sz)), false))
		_planet_node.add_child(tex_ctrl)
	else:
		## Fallback: IconDraw планета (LAW 7)
		var icon: Control = IconDraw.planet(r * 1.2, PLANET_COLOR.lightened(0.3))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(-r * 0.6, -r * 0.6)
		_planet_node.add_child(icon)

	## ОБЛИЧЧЯ — Label з emoji, центр планети
	_planet_face = Label.new()
	var face_size: int = int(r * 1.0) if _is_toddler else int(r * 0.85)
	_planet_face.add_theme_font_size_override("font_size", face_size)
	_planet_face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_planet_face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_planet_face.text = FACE_WAITING
	## Позиціонуємо по центру планети
	var face_rect: float = r * 1.4
	_planet_face.size = Vector2(face_rect, face_rect)
	_planet_face.position = Vector2(-face_rect * 0.5, -face_rect * 0.5)
	_planet_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_planet_node.add_child(_planet_face)

	## Відновити прикраси з попередніх раундів
	_restore_accessories()

	## Дихальна анімація (масштаб 1.0 ↔ 1.03)
	_start_breath_animation()

	_all_round_nodes.append(_planet_node)


func _start_breath_animation() -> void:
	if SettingsManager.reduced_motion:
		return
	if not _planet_node or not is_instance_valid(_planet_node):
		push_warning("gravity_orbits: _start_breath — планета недоступна")
		return
	if _breath_tween and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = create_tween()
	_breath_tween.set_loops()
	_breath_tween.tween_property(_planet_node, "scale", Vector2(1.03, 1.03), 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(_planet_node, "scale", Vector2.ONE, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Встановити обличчя планети (emoji)
func _set_planet_face(face: String) -> void:
	if _planet_face and is_instance_valid(_planet_face):
		_planet_face.text = face


## ========== ПРИКРАСИ ПЛАНЕТИ ==========

## Відновити прикраси після зміни раунду (бо _clear_round видаляє ноди)
func _restore_accessories() -> void:
	if not _planet_node or not is_instance_valid(_planet_node):
		push_warning("gravity_orbits: _restore_accessories — планета недоступна")
		return
	_accessory_ring = null
	_accessory_moon = null
	_accessory_crown = null
	_accessory_aura = null
	if _accessory_level >= 1:
		_add_ring_accessory()
	if _accessory_level >= 2:
		_add_moon_accessory()
	if _accessory_level >= 3:
		_add_crown_accessory()
	if _accessory_level >= 4:
		_add_aura_accessory()
	if _accessory_level >= 5:
		_apply_golden_glow()


## Нагородити новою прикрасою після раунду
func _award_accessory(level: int) -> void:
	_accessory_level = level
	if not _planet_node or not is_instance_valid(_planet_node):
		push_warning("gravity_orbits: _award_accessory — планета недоступна")
		return
	match level:
		1:
			_add_ring_accessory()
			_animate_accessory_appear(_accessory_ring)
		2:
			_add_moon_accessory()
			_animate_accessory_appear(_accessory_moon)
		3:
			_add_crown_accessory()
			_animate_accessory_appear(_accessory_crown)
		4:
			_add_aura_accessory()
			_animate_accessory_appear(_accessory_aura)
		5:
			_apply_golden_glow()


func _add_ring_accessory() -> void:
	if _accessory_ring and is_instance_valid(_accessory_ring):
		push_warning("gravity_orbits: _add_ring — вже існує")
		return
	_accessory_ring = Node2D.new()
	_accessory_ring.z_index = -1
	var ring_r: float = _planet_radius + 18.0
	_accessory_ring.draw.connect(func() -> void:
		## Кільце навколо планети (Saturn-like)
		_accessory_ring.draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48,
			RING_COLOR, 3.0, true))
	_planet_node.add_child(_accessory_ring)


func _add_moon_accessory() -> void:
	if _accessory_moon and is_instance_valid(_accessory_moon):
		push_warning("gravity_orbits: _add_moon — вже існує")
		return
	_accessory_moon = Node2D.new()
	var moon_dist: float = _planet_radius + 30.0
	_accessory_moon.position = Vector2(moon_dist, -moon_dist * 0.5)
	_accessory_moon.draw.connect(func() -> void:
		## Маленький місяць
		_accessory_moon.draw_circle(Vector2.ZERO, 10.0, MOON_COLOR)
		## Кратер
		_accessory_moon.draw_circle(Vector2(-3, -2), 3.0, MOON_COLOR.darkened(0.15)))
	_planet_node.add_child(_accessory_moon)
	## Обертання місяця навколо планети
	if not SettingsManager.reduced_motion:
		var orbit_tw: Tween = create_tween()
		orbit_tw.set_loops()
		orbit_tw.tween_method(func(angle: float) -> void:
			if is_instance_valid(_accessory_moon):
				_accessory_moon.position = Vector2(
					cos(angle) * moon_dist,
					sin(angle) * moon_dist * 0.4), 0.0, TAU, 6.0)


func _add_crown_accessory() -> void:
	if _accessory_crown and is_instance_valid(_accessory_crown):
		push_warning("gravity_orbits: _add_crown — вже існує")
		return
	_accessory_crown = Node2D.new()
	_accessory_crown.position = Vector2(0, -_planet_radius - 10.0)
	_accessory_crown.draw.connect(func() -> void:
		## Корона зі спіцями (трикутники)
		var crown_w: float = 30.0
		var crown_h: float = 20.0
		var points: PackedVector2Array = PackedVector2Array([
			Vector2(-crown_w, 0),
			Vector2(-crown_w * 0.6, -crown_h),
			Vector2(-crown_w * 0.2, -crown_h * 0.4),
			Vector2(0, -crown_h * 1.2),
			Vector2(crown_w * 0.2, -crown_h * 0.4),
			Vector2(crown_w * 0.6, -crown_h),
			Vector2(crown_w, 0),
		])
		_accessory_crown.draw_colored_polygon(points, CROWN_COLOR)
		## Блиск на кінчиках
		_accessory_crown.draw_circle(Vector2(0, -crown_h * 1.2), 3.0, Color.WHITE))
	_planet_node.add_child(_accessory_crown)


func _add_aura_accessory() -> void:
	if _accessory_aura and is_instance_valid(_accessory_aura):
		push_warning("gravity_orbits: _add_aura — вже існує")
		return
	_accessory_aura = Node2D.new()
	_accessory_aura.z_index = -2
	var aura_r: float = _planet_radius + 35.0
	_accessory_aura.draw.connect(func() -> void:
		## Райдужна аура (кілька кольорових кілець)
		var colors: Array[Color] = [
			Color("ff6b6b"), Color("ffd166"), Color("22c55e"),
			Color("3b82f6"), Color("a855f7"),
		]
		for i: int in colors.size():
			var ring_radius: float = aura_r + float(i) * 4.0
			_accessory_aura.draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48,
				Color(colors[i], 0.35), 2.0, true))
	_planet_node.add_child(_accessory_aura)


func _apply_golden_glow() -> void:
	if not _planet_node or not is_instance_valid(_planet_node):
		push_warning("gravity_orbits: _apply_golden_glow — планета недоступна")
		return
	_planet_node.modulate = Color(1.1, 1.0, 0.85, 1.0)


func _animate_accessory_appear(node: Node2D) -> void:
	if not node or not is_instance_valid(node):
		push_warning("gravity_orbits: _animate_accessory_appear — нода недоступна")
		return
	if SettingsManager.reduced_motion:
		return
	node.scale = Vector2.ZERO
	node.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(node, "scale", Vector2(1.3, 1.3), 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(node, "modulate:a", 1.0, 0.15)
	tw.tween_property(node, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## ========== ЛІЧИЛЬНИК ЗЛОВЛЕНИХ ==========

func _spawn_catch_label(vp: Vector2) -> void:
	_catch_label = Label.new()
	_catch_label.add_theme_font_size_override("font_size", 32)
	_catch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_catch_label.position = Vector2(0, vp.y * 0.82)
	_catch_label.size = Vector2(vp.x, 50)
	_catch_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_update_catch_label()
	add_child(_catch_label)
	_all_round_nodes.append(_catch_label)


func _update_catch_label() -> void:
	if _catch_label and is_instance_valid(_catch_label):
		_catch_label.text = "%d / %d" % [_catches_this_round, _catches_needed]


## ========== СПАВН ЗІРОК ==========

func _spawn_star(vp: Vector2) -> void:
	## Визначити тип: gold (P only, 15%), silver (20%), normal (решта)
	var star_type: int = StarType.NORMAL
	if not _is_toddler and randf() < GOLD_STAR_CHANCE:
		star_type = StarType.GOLD
	elif randf() < SILVER_STAR_CHANCE:
		star_type = StarType.SILVER

	var star_node: Node2D = Node2D.new()

	## Розмір: Toddler = 100dp, Preschool = 70dp, Gold = 80dp
	var star_sz: float
	if _is_toddler:
		star_sz = 100.0
	elif star_type == StarType.GOLD:
		star_sz = 80.0
	else:
		star_sz = 70.0
	var half_sz: float = star_sz * 0.5

	## Визуал зірки
	if _has_star_texture and _star_texture:
		var tex_ctrl: Control = Control.new()
		tex_ctrl.size = Vector2(star_sz, star_sz)
		tex_ctrl.position = Vector2(-half_sz, -half_sz)
		tex_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex_ref: Texture2D = _star_texture
		var sz_ref: float = star_sz
		tex_ctrl.draw.connect(func() -> void:
			tex_ctrl.draw_texture_rect(tex_ref,
				Rect2(Vector2.ZERO, Vector2(sz_ref, sz_ref)), false))
		star_node.add_child(tex_ctrl)
	else:
		## Fallback: IconDraw зірка (LAW 7)
		var color: Color
		match star_type:
			StarType.GOLD:
				color = GOLD_STAR_COLOR
			StarType.SILVER:
				color = SILVER_STAR_COLOR
			_:
				color = STAR_COLOR
		var icon: Control = IconDraw.star_5pt(half_sz, color)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(-half_sz * 0.5, -half_sz * 0.5)
		star_node.add_child(icon)

	## Модулейт для типу зірки
	match star_type:
		StarType.GOLD:
			star_node.modulate = Color(1.0, 0.85, 0.3, 1.0)
		StarType.SILVER:
			star_node.modulate = Color(0.9, 0.92, 1.0, 1.0)

	## Позиція + швидкість
	var pos_vel: Dictionary = _random_entry_position_and_velocity(vp, star_sz)
	star_node.position = pos_vel.get("position", Vector2(vp.x * 0.5, vp.y * 0.5)) as Vector2
	var velocity: Vector2 = pos_vel.get("velocity", Vector2(50, 30)) as Vector2

	add_child(star_node)
	_all_round_nodes.append(star_node)

	_floating_items.append({
		"node": star_node,
		"velocity": velocity,
		"type": star_type,
		"size": star_sz,
		"base_y": star_node.position.y,
		"phase": randf() * TAU,  ## Випадкова фаза для wobble
	})


## ========== СПАВН АСТЕРОЇДІВ (Preschool only) ==========

func _spawn_asteroid(vp: Vector2) -> void:
	var asteroid_node: Node2D = Node2D.new()
	var asteroid_sz: float = 48.0
	var half_sz: float = asteroid_sz * 0.5

	## Сірий круг через candy_circle
	var panel: Panel = Panel.new()
	panel.size = Vector2(asteroid_sz, asteroid_sz)
	panel.position = Vector2(-half_sz, -half_sz)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",
		GameData.candy_circle(ASTEROID_COLOR, half_sz))
	panel.material = GameData.create_premium_material(
		0.04, 2.0, 0.0, 0.0, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
	asteroid_node.add_child(panel)

	## "Кратери" — декоративні темні круги
	var crater_draw: Node2D = Node2D.new()
	crater_draw.draw.connect(func() -> void:
		crater_draw.draw_circle(Vector2(-6, -4), 5.0, ASTEROID_COLOR.darkened(0.2))
		crater_draw.draw_circle(Vector2(8, 6), 3.5, ASTEROID_COLOR.darkened(0.15))
		crater_draw.draw_circle(Vector2(2, -10), 2.5, ASTEROID_COLOR.darkened(0.18)))
	asteroid_node.add_child(crater_draw)

	## Позиція + швидкість
	var pos_vel: Dictionary = _random_entry_position_and_velocity(vp, asteroid_sz, 1.15)
	asteroid_node.position = pos_vel.get("position", Vector2(vp.x * 0.5, vp.y * 0.5)) as Vector2
	var velocity: Vector2 = pos_vel.get("velocity", Vector2(60, 40)) as Vector2

	add_child(asteroid_node)
	_all_round_nodes.append(asteroid_node)

	_floating_items.append({
		"node": asteroid_node,
		"velocity": velocity,
		"type": "asteroid",
		"size": asteroid_sz,
		"base_y": asteroid_node.position.y,
		"phase": randf() * TAU,
	})


## ========== ГЕНЕРАЦІЯ ПОЗИЦІЇ ТА ШВИДКОСТІ ==========

func _random_entry_position_and_velocity(vp: Vector2, item_size: float,
		speed_mult: float = 1.0) -> Dictionary:
	## Зірка з'являється з одного краю екрану та летить під м'яким кутом
	var speed_min: float = TODDLER_SPEED_MIN if _is_toddler else PRESCHOOL_SPEED_MIN
	var speed_max: float = TODDLER_SPEED_MAX if _is_toddler else PRESCHOOL_SPEED_MAX
	## Прогресивна складність: швидкість зростає з раундом (LAW 6)
	var round_factor: float = _scale_by_round(0.0, 1.0, _round, TOTAL_ROUNDS)
	var speed: float = lerpf(speed_min, speed_max, round_factor) * speed_mult

	## Випадковий край: 0=left, 1=right, 2=top, 3=bottom
	var edge: int = randi_range(0, 3)
	var pos: Vector2 = Vector2.ZERO
	var angle: float = 0.0
	var margin: float = item_size * 0.5 + OFFSCREEN_BUFFER

	match edge:
		0:  ## Лівий край → направо
			pos = Vector2(-margin, randf_range(SPAWN_MARGIN, vp.y - SPAWN_MARGIN))
			angle = randf_range(-0.4, 0.4)
		1:  ## Правий край → наліво
			pos = Vector2(vp.x + margin, randf_range(SPAWN_MARGIN, vp.y - SPAWN_MARGIN))
			angle = randf_range(PI - 0.4, PI + 0.4)
		2:  ## Верхній край → вниз
			pos = Vector2(randf_range(SPAWN_MARGIN, vp.x - SPAWN_MARGIN), -margin)
			angle = randf_range(PI * 0.5 - 0.4, PI * 0.5 + 0.4)
		3:  ## Нижній край → вгору
			pos = Vector2(randf_range(SPAWN_MARGIN, vp.x - SPAWN_MARGIN), vp.y + margin)
			angle = randf_range(-PI * 0.5 - 0.4, -PI * 0.5 + 0.4)

	var velocity: Vector2 = Vector2(cos(angle), sin(angle)) * speed
	return {"position": pos, "velocity": velocity}


## ========== РУХ ЗІРОК (_process) ==========

func _process(delta: float) -> void:
	if _game_over:
		return
	_game_time += delta
	if not _input_locked:
		_move_floating_items(delta)
		_check_offscreen_items()


func _move_floating_items(delta: float) -> void:
	for item: Dictionary in _floating_items:
		var node: Node2D = item.get("node") as Node2D
		if not node or not is_instance_valid(node):
			continue
		var vel: Vector2 = item.get("velocity", Vector2.ZERO) as Vector2
		var item_type: Variant = item.get("type", StarType.NORMAL)

		## Базовий рух
		node.position += vel * delta

		## Обертання та хитання — тільки для зірок (не астероїдів)
		if item_type != "asteroid":
			## Обертання
			var rot_dir: float = 1.0 if vel.x >= 0.0 else -1.0
			node.rotation += STAR_ROTATION_SPEED * rot_dir * delta
			## Синусоїдальне хитання по Y
			var phase: float = item.get("phase", 0.0) as float
			var wobble_offset: float = sin(_game_time * STAR_WOBBLE_FREQ + phase) * STAR_WOBBLE_AMP
			node.position.y += wobble_offset * delta
		else:
			## Астероїди: повільне обертання
			node.rotation += 0.3 * delta


func _check_offscreen_items() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var max_dist: float = OFFSCREEN_BUFFER + 120.0

	## Збираємо елементи, що вилетіли за екран
	var to_respawn: Array[Dictionary] = []
	for item: Dictionary in _floating_items:
		var node: Node2D = item.get("node") as Node2D
		if not node or not is_instance_valid(node):
			continue
		var pos: Vector2 = node.position
		if pos.x < -max_dist or pos.x > vp.x + max_dist \
				or pos.y < -max_dist or pos.y > vp.y + max_dist:
			to_respawn.append(item)

	## Респавн — видаляємо стару ноду, створюємо нову
	for item: Dictionary in to_respawn:
		var node: Node2D = item.get("node") as Node2D
		var item_type: Variant = item.get("type", StarType.NORMAL)
		## Видаляємо стару (LAW 11: erase BEFORE queue_free)
		_floating_items.erase(item)
		if node and is_instance_valid(node):
			_all_round_nodes.erase(node)
			node.queue_free()
		## Створюємо нову (якщо гра ще активна)
		if not _game_over:
			if item_type == "asteroid":
				_spawn_asteroid(vp)
			else:
				_spawn_star(vp)


## ========== INPUT: ОБРОБКА ТАПІВ ==========

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return

	var tap_pos: Vector2 = Vector2.ZERO
	var tapped: bool = false

	if event is InputEventMouseButton and event.pressed and \
			event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
		tap_pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and event.pressed and event.index == 0:
		tapped = true
		tap_pos = (event as InputEventScreenTouch).position

	if not tapped:
		return

	_reset_idle_timer()

	## Спочатку шукаємо об'єкт під тапом (зірка або астероїд)
	var best_item: Dictionary = {}
	var best_dist: float = INF
	for item: Dictionary in _floating_items:
		var node: Node2D = item.get("node") as Node2D
		if not node or not is_instance_valid(node):
			continue
		var item_size: float = item.get("size", 70.0) as float
		var touch_r: float = maxf(STAR_TOUCH_RADIUS, item_size * 0.5)
		var dist: float = tap_pos.distance_to(node.global_position)
		if dist <= touch_r and dist < best_dist:
			best_dist = dist
			best_item = item

	if not best_item.is_empty():
		## Тапнули на об'єкт
		var item_type: Variant = best_item.get("type", StarType.NORMAL)
		if item_type == "asteroid":
			_handle_asteroid_tap(best_item)
		else:
			_catch_star(best_item)
		return

	## Перевіряємо чи тапнули на планету
	if _planet_node and is_instance_valid(_planet_node):
		var planet_dist: float = tap_pos.distance_to(_planet_node.global_position)
		if planet_dist <= _planet_radius * 1.2:
			_handle_planet_tap()
			return

	## Тап у порожній простір — іскри! (Tap anywhere = reaction)
	_handle_empty_tap(tap_pos)


## ========== ТАП У ПОРОЖНЄ МІСЦЕ ==========

func _handle_empty_tap(pos: Vector2) -> void:
	## Спавнимо іскри (3-5 маленьких sparkle)
	VFXManager.spawn_snap_pulse(pos, Color(1, 1, 1, 0.5))
	## Тихий звук дотику
	AudioManager.play_sfx_varied("click", 0.25)


## ========== ТАП НА ПЛАНЕТУ ==========

func _handle_planet_tap() -> void:
	if not _planet_node or not is_instance_valid(_planet_node):
		push_warning("gravity_orbits: _handle_planet_tap — планета недоступна")
		return

	## Планета хихикає: bounce + SFX + sparkle
	AudioManager.play_sfx_varied("click", 0.2)
	HapticsManager.vibrate_light()
	VFXManager.spawn_snap_pulse(_planet_node.global_position, PLANET_COLOR.lightened(0.3))

	## Радісне обличчя на мить
	_set_planet_face(FACE_HAPPY)

	if not SettingsManager.reduced_motion:
		var bounce_tw: Tween = create_tween()
		bounce_tw.tween_property(_planet_node, "scale", Vector2(1.12, 0.92), 0.08) \
			.set_trans(Tween.TRANS_SINE)
		bounce_tw.tween_property(_planet_node, "scale", Vector2(0.95, 1.08), 0.08) \
			.set_trans(Tween.TRANS_SINE)
		bounce_tw.tween_property(_planet_node, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		bounce_tw.tween_callback(func() -> void:
			if is_instance_valid(_planet_face):
				_set_planet_face(FACE_WAITING))


## ========== ЛОВЛЯ ЗІРКИ (core loop) ==========

func _catch_star(item: Dictionary) -> void:
	if _feeding_in_progress:
		push_warning("gravity_orbits: _catch_star — годування ще в процесі")
		return
	var node: Node2D = item.get("node") as Node2D
	if not node or not is_instance_valid(node):
		push_warning("gravity_orbits: _catch_star — зірка вже недоступна")
		return

	var star_type: int = item.get("type", StarType.NORMAL) as int
	var catch_pos: Vector2 = node.global_position

	## Видаляємо з масиву ПЕРЕД анімацією (LAW 11)
	_floating_items.erase(item)

	## SFX залежить від типу зірки
	match star_type:
		StarType.GOLD:
			AudioManager.play_sfx("success", 1.2)
		StarType.SILVER:
			AudioManager.play_sfx("coin", 1.1)
		_:
			AudioManager.play_sfx("coin")
	HapticsManager.vibrate_light()

	## Зірка ЗАМОРОЖУЄТЬСЯ (зупиняється)
	## Потім ЛЕТИТЬ до планети (arc motion)
	_feeding_in_progress = true

	if SettingsManager.reduced_motion:
		## Без анімації — миттєвий catch
		_all_round_nodes.erase(node)
		node.queue_free()
		_on_star_eaten(star_type)
		return

	## 1. Заморозити + pop
	var freeze_tw: Tween = create_tween()
	freeze_tw.tween_property(node, "scale", Vector2(1.3, 1.3), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## Іскри в місці тапу
	VFXManager.spawn_correct_sparkle(catch_pos)

	## 2. Летить до планети (0.3s arc)
	var target_pos: Vector2 = _planet_center
	## Bezier-like arc через mid-point (вище за пряму лінію)
	var mid_y: float = minf(catch_pos.y, target_pos.y) - 50.0
	var mid_point: Vector2 = Vector2(
		(catch_pos.x + target_pos.x) * 0.5,
		mid_y)

	## Планета відкриває рот
	_set_planet_face(FACE_EXCITED)

	var fly_tw: Tween = create_tween()
	fly_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	## Рух по дузі через 2 етапи
	fly_tw.tween_property(node, "position", mid_point, 0.15)
	fly_tw.tween_property(node, "position", target_pos, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	## Зменшення під час польоту
	fly_tw.parallel().tween_property(node, "scale", Vector2(0.3, 0.3), 0.3)
	## Обертання під час польоту
	fly_tw.parallel().tween_property(node, "rotation", node.rotation + TAU, 0.3)

	fly_tw.tween_callback(func() -> void:
		if is_instance_valid(node):
			_all_round_nodes.erase(node)
			node.queue_free()
		if not is_instance_valid(self):
			return
		_on_star_eaten(star_type))


## Коли зірка долетіла до планети
func _on_star_eaten(star_type: int) -> void:
	_feeding_in_progress = false

	## Планета ЇСТ: обличчя + scale pop + "ням" ефект
	_set_planet_face(FACE_EATING)

	if _planet_node and is_instance_valid(_planet_node) and not SettingsManager.reduced_motion:
		var eat_tw: Tween = create_tween()
		eat_tw.tween_property(_planet_node, "scale", Vector2(1.15, 1.15), 0.08) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		eat_tw.tween_property(_planet_node, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		eat_tw.tween_callback(func() -> void:
			if is_instance_valid(self):
				_set_planet_face(FACE_HAPPY)
				## Повернути waiting face через 0.5s
				var reset_tw: Tween = create_tween()
				reset_tw.tween_interval(0.5)
				reset_tw.tween_callback(func() -> void:
					if is_instance_valid(self) and not _game_over:
						_set_planet_face(FACE_WAITING)))

	## Підрахунок
	var catch_value: int = 2 if star_type == StarType.GOLD else 1
	_catches_this_round += catch_value
	_total_catches += catch_value
	_update_catch_label()

	## Кожні 3 улови — перевірка на нову прикрасу
	_check_accessory_milestone()

	## Перевірити завершення раунду
	if _catches_this_round >= _catches_needed:
		_on_round_complete()
		return

	## Спавнимо заміну зірки після затримки
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var delay_tw: Tween = create_tween()
	delay_tw.tween_interval(0.4)
	delay_tw.tween_callback(func() -> void:
		if _game_over or _input_locked:
			return
		if not is_instance_valid(self):
			return
		_spawn_star(vp))


## Перевірка milestone для прикрас (кожні 3 улови)
func _check_accessory_milestone() -> void:
	## Рівні прикрас: 3, 6, 9, 12, 15 сумарних уловів
	var new_level: int = clampi(_total_catches / 3, 0, 5)
	if new_level > _accessory_level:
		_award_accessory(new_level)
		## VFX святкування нової прикраси
		if _planet_node and is_instance_valid(_planet_node):
			VFXManager.spawn_correct_sparkle(_planet_node.global_position)
			AudioManager.play_sfx("success", 1.1)


## ========== ТАП НА АСТЕРОЇД (Preschool) ==========

func _handle_asteroid_tap(item: Dictionary) -> void:
	var node: Node2D = item.get("node") as Node2D
	if not node or not is_instance_valid(node):
		push_warning("gravity_orbits: _handle_asteroid_tap — астероїд вже недоступний")
		return

	if _is_toddler:
		## A6: Toddler — без штрафу, м'який звук + wobble
		AudioManager.play_sfx("click")
		HapticsManager.vibrate_light()
		if not SettingsManager.reduced_motion:
			var wobble_tw: Tween = create_tween()
			wobble_tw.tween_property(node, "rotation", 0.15, 0.06)
			wobble_tw.tween_property(node, "rotation", -0.15, 0.06)
			wobble_tw.tween_property(node, "rotation", 0.0, 0.08)
		return

	## Preschool: помилка (A7)
	_errors += 1
	_register_error(node)

	## Планета ЗЛЯКАЛАСЬ
	_set_planet_face(FACE_SCARED)
	## Планета тремтить
	if _planet_node and is_instance_valid(_planet_node) and not SettingsManager.reduced_motion:
		var scared_tw: Tween = create_tween()
		scared_tw.tween_property(_planet_node, "position",
			_planet_center + Vector2(-8, 0), 0.04)
		scared_tw.tween_property(_planet_node, "position",
			_planet_center + Vector2(8, 0), 0.04)
		scared_tw.tween_property(_planet_node, "position",
			_planet_center + Vector2(-4, 0), 0.04)
		scared_tw.tween_property(_planet_node, "position",
			_planet_center, 0.06)
		scared_tw.tween_interval(0.3)
		scared_tw.tween_callback(func() -> void:
			if is_instance_valid(self) and not _game_over:
				_set_planet_face(FACE_WAITING))


## ========== ЗАВЕРШЕННЯ РАУНДУ ==========

func _on_round_complete() -> void:
	_register_correct()
	_input_locked = true

	## Планета щаслива! Happy dance
	_set_planet_face(FACE_FULL)

	if _planet_node and is_instance_valid(_planet_node):
		VFXManager.spawn_premium_celebration(_planet_node.global_position)

		## Happy dance: rotation wobble
		if not SettingsManager.reduced_motion:
			var dance_tw: Tween = create_tween()
			dance_tw.tween_property(_planet_node, "rotation", 0.12, 0.1)
			dance_tw.tween_property(_planet_node, "rotation", -0.12, 0.1)
			dance_tw.tween_property(_planet_node, "rotation", 0.08, 0.08)
			dance_tw.tween_property(_planet_node, "rotation", -0.08, 0.08)
			dance_tw.tween_property(_planet_node, "rotation", 0.0, 0.12) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()

	var success_d: float = 0.15 if SettingsManager.reduced_motion else 0.8
	var tw: Tween = create_tween()
	tw.tween_interval(success_d)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


## ========== ОЧИЩЕННЯ РАУНДУ ==========

func _clear_round() -> void:
	## Зупинити дихання перед видаленням
	if _breath_tween and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = null

	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_floating_items.clear()
	_catches_this_round = 0
	_feeding_in_progress = false
	_planet_node = null
	_planet_face = null
	_catch_label = null
	_accessory_ring = null
	_accessory_moon = null
	_accessory_crown = null
	_accessory_aura = null


## ========== ЗАВЕРШЕННЯ ГРИ ==========

func _finish() -> void:
	_game_over = true
	_input_locked = true

	## Фінальне обличчя — СУПЕРПЛАНЕТА
	_set_planet_face(FACE_FULL)

	if _planet_node and is_instance_valid(_planet_node):
		## Золоте сяйво
		_planet_node.modulate = Color(1.15, 1.05, 0.85, 1.0)
		VFXManager.spawn_premium_celebration(_planet_node.global_position)
		## Фінальний happy dance (ширший)
		if not SettingsManager.reduced_motion:
			var final_tw: Tween = create_tween()
			final_tw.tween_property(_planet_node, "scale", Vector2(1.2, 1.2), 0.15) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			final_tw.tween_property(_planet_node, "rotation", 0.2, 0.1)
			final_tw.tween_property(_planet_node, "rotation", -0.2, 0.1)
			final_tw.tween_property(_planet_node, "rotation", 0.0, 0.15) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			final_tw.tween_property(_planet_node, "scale", Vector2.ONE, 0.2) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": TOTAL_ROUNDS,
		"earned_stars": earned,
	})


## ========== IDLE HINT ==========

func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over:
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	## Пульсуємо першу доступну зірку — підказка тапнути
	for item: Dictionary in _floating_items:
		var node: Node2D = item.get("node") as Node2D
		var item_type: Variant = item.get("type", StarType.NORMAL)
		if node and is_instance_valid(node) and item_type != "asteroid":
			_pulse_node(node, 1.15)
			break
	_reset_idle_timer()


## ========== SCAFFOLD HINT (A11) ==========

func _show_scaffold_hint() -> void:
	if _tutorial_sys:
		_tutorial_sys.show_scaffold_hint()
