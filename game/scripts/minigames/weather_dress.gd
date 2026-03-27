extends BaseMiniGame

## ECE-12 "Одень Тофі" — paper-doll dress-up за погодою.
## Тофі стоїть у центрі. Фон: анімована погода.
## Одяг drag-drop НА Тофі → snap до body zone.
## Неправильний одяг → Тофі дрожить / потіє.
## Правильно → святкова анімація.
## Toddler: 3 раунди, простіша погода, 3 вибори.
## Preschool: 5 раундів, складніша погода, до 7 виборів.

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 5
const DEAL_STAGGER: float = 0.12
const DEAL_DURATION: float = 0.35
const IDLE_HINT_DELAY: float = 5.0
const SLOT_SIZE: Vector2 = Vector2(90, 90)
const SLOT_CORNER: int = 16
const SAFETY_TIMEOUT_SEC: float = 120.0

## Зони тіла Тофі — кожна зона приймає визначені типи одягу
enum BodyZone { HEAD, BODY, LEGS, HANDS, ACCESSORY }

## Яка зона приймає який одяг (LAW 17: dict guard — compile-time)
const CLOTHING_ZONE: Dictionary = {
	"hat": BodyZone.HEAD,
	"sunglasses": BodyZone.HEAD,
	"coat": BodyZone.BODY,
	"jacket": BodyZone.BODY,
	"raincoat": BodyZone.BODY,
	"shorts": BodyZone.LEGS,
	"boots": BodyZone.LEGS,
	"mittens": BodyZone.HANDS,
	"scarf": BodyZone.HANDS,
	"umbrella": BodyZone.ACCESSORY,
}

## Зсув одягу відносно центру Тофі (куди snap-ується одяг при правильному drop)
const ZONE_OFFSETS: Dictionary = {
	BodyZone.HEAD: Vector2(0, -100),
	BodyZone.BODY: Vector2(0, -20),
	BodyZone.LEGS: Vector2(0, 60),
	BodyZone.HANDS: Vector2(-55, -10),
	BodyZone.ACCESSORY: Vector2(60, -30),
}

## Кольори зон для drop target підсвітки (LAW 25: shape + color)
const ZONE_COLORS: Dictionary = {
	BodyZone.HEAD: Color("ffd166", 0.3),
	BodyZone.BODY: Color("06d6a0", 0.3),
	BodyZone.LEGS: Color("118ab2", 0.3),
	BodyZone.HANDS: Color("ef476f", 0.3),
	BodyZone.ACCESSORY: Color("073b4c", 0.3),
}

## Розмір зон для snap
const ZONE_SIZES: Dictionary = {
	BodyZone.HEAD: Vector2(70, 50),
	BodyZone.BODY: Vector2(80, 60),
	BodyZone.LEGS: Vector2(70, 50),
	BodyZone.HANDS: Vector2(50, 50),
	BodyZone.ACCESSORY: Vector2(50, 60),
}

## Погоди з коректним/неправильним одягом
const WEATHERS: Array[Dictionary] = [
	{"id": "sunny", "icon": "sun", "key": "WEATHER_SUNNY",
		"correct": ["sunglasses", "hat", "shorts"],
		"wrong": ["scarf", "mittens", "boots", "coat"]},
	{"id": "rainy", "icon": "rain", "key": "WEATHER_RAINY",
		"correct": ["umbrella", "raincoat", "boots"],
		"wrong": ["sunglasses", "shorts", "hat", "mittens"]},
	{"id": "snowy", "icon": "snowflake", "key": "WEATHER_SNOWY",
		"correct": ["scarf", "mittens", "coat", "boots"],
		"wrong": ["shorts", "sunglasses", "umbrella"]},
	{"id": "windy", "icon": "wind", "key": "WEATHER_WINDY",
		"correct": ["jacket", "hat", "scarf"],
		"wrong": ["shorts", "sunglasses", "umbrella", "mittens"]},
	{"id": "cloudy", "icon": "cloud", "key": "WEATHER_CLOUDY",
		"correct": ["jacket", "hat", "umbrella"],
		"wrong": ["sunglasses", "shorts", "mittens", "scarf"]},
	{"id": "stormy", "icon": "storm", "key": "WEATHER_STORMY",
		"correct": ["raincoat", "boots", "umbrella"],
		"wrong": ["sunglasses", "hat", "shorts", "scarf"]},
	{"id": "hot", "icon": "sun", "key": "WEATHER_HOT",
		"correct": ["sunglasses", "hat", "shorts"],
		"wrong": ["coat", "scarf", "mittens", "boots"]},
	{"id": "foggy", "icon": "cloud", "key": "WEATHER_FOGGY",
		"correct": ["jacket", "boots", "scarf"],
		"wrong": ["shorts", "sunglasses", "hat", "umbrella"]},
]

## Тофі — кольори частин тіла (premium LAW 28)
const TOFIE_BODY_COLOR: Color = Color("ffdab9")     ## Персиковий
const TOFIE_HEAD_COLOR: Color = Color("ffe4c4")      ## Світліший
const TOFIE_EYE_COLOR: Color = Color("2d3436")       ## Темні очі
const TOFIE_SMILE_COLOR: Color = Color("e17055")      ## Теплий рот
const TOFIE_CHEEK_COLOR: Color = Color("fab1a0", 0.5) ## Рум'янець

var _is_toddler: bool = false
var _drag: UniversalDrag = null
var _round: int = 0
var _total_rounds: int = 0
var _matched: int = 0
var _total: int = 0
var _start_time: float = 0.0

var _clothing_items: Array[Node2D] = []
var _all_round_nodes: Array[Node] = []
var _item_correct: Dictionary = {}       ## item -> bool (правильний для погоди?)
var _item_origins: Dictionary = {}       ## item -> Vector2 (початкова позиція)
var _item_clothing_id: Dictionary = {}   ## item -> String (id одягу)
var _used_weathers: Array[int] = []
var _current_weather: Dictionary = {}

## Тофі та зони
var _tofie_node: Node2D = null
var _tofie_center: Vector2 = Vector2.ZERO
var _zone_targets: Dictionary = {}  ## BodyZone -> Node2D
var _worn_items: Dictionary = {}    ## BodyZone -> Node2D (одягнені речі)

## Погодні ефекти
var _weather_particles: CPUParticles2D = null
var _weather_display: HBoxContainer = null

var _idle_timer: SceneTreeTimer = null


func _ready() -> void:
	game_id = "weather_dress"
	bg_theme = "arctic"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_drag = UniversalDrag.new(self)
	if _is_toddler:
		_drag.snap_radius_override = TODDLER_SNAP_RADIUS
	_drag.item_picked_up.connect(_on_picked)
	_drag.item_dropped_on_target.connect(_on_dropped_target)
	_drag.item_dropped_on_empty.connect(_on_dropped_empty)
	_build_hud()
	_build_tofie()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("DRESS_TUTORIAL_TODDLER")
	return tr("DRESS_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _clothing_items.is_empty() or _zone_targets.is_empty():
		return {}
	for item: Node2D in _clothing_items:
		if not is_instance_valid(item):
			continue
		if _item_correct.get(item, false):
			var clothing_id: String = _item_clothing_id.get(item, "")
			var zone: int = CLOTHING_ZONE.get(clothing_id, BodyZone.BODY)
			var target: Node2D = _zone_targets.get(zone)
			if target and is_instance_valid(target):
				return {"type": "drag", "from": item.global_position, "to": target.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Дисплей погоди: іконка + текст (над Тофі)
	_weather_display = HBoxContainer.new()
	_weather_display.alignment = BoxContainer.ALIGNMENT_CENTER
	_weather_display.set("theme_override_constants/separation", 12)
	_weather_display.position = Vector2(0, 140)
	_weather_display.size = Vector2(vp.x, 60)
	add_child(_weather_display)


## ---- Тофі (paper-doll персонаж) ----

func _build_tofie() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_tofie_center = Vector2(vp.x * 0.5, vp.y * 0.42)
	_tofie_node = Node2D.new()
	_tofie_node.position = _tofie_center
	add_child(_tofie_node)
	## Тофі малюється через TofieDrawer
	var drawer: TofieDrawer = TofieDrawer.new()
	_tofie_node.add_child(drawer)
	## Створити drop zone targets для кожної зони тіла
	for zone_id: int in ZONE_OFFSETS:
		var offset: Vector2 = ZONE_OFFSETS.get(zone_id, Vector2.ZERO)
		var zone_size: Vector2 = ZONE_SIZES.get(zone_id, Vector2(60, 60))
		var zone_node: Node2D = Node2D.new()
		zone_node.position = _tofie_center + offset
		add_child(zone_node)
		## Напівпрозора зона (LAW 25: shape + колір для розрізнення)
		var zone_bg: Panel = Panel.new()
		zone_bg.size = zone_size
		zone_bg.position = Vector2(-zone_size.x * 0.5, -zone_size.y * 0.5)
		var zone_style: StyleBoxFlat = StyleBoxFlat.new()
		zone_style.bg_color = ZONE_COLORS.get(zone_id, Color(1, 1, 1, 0.2))
		zone_style.set_corner_radius_all(12)
		zone_style.border_color = ZONE_COLORS.get(zone_id, Color(1, 1, 1, 0.3)).lightened(0.3)
		zone_style.border_color.a = 0.5
		zone_style.set_border_width_all(2)
		zone_bg.add_theme_stylebox_override("panel", zone_style)
		zone_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone_bg.modulate.a = 0.0  ## Приховані — показуються при drag
		zone_node.add_child(zone_bg)
		zone_node.set_meta("zone_panel", zone_bg)
		zone_node.set_meta("zone_id", zone_id)
		_zone_targets[zone_id] = zone_node
		_drag.drop_targets.append(zone_node)


## ---- Раунди ----

func _start_round() -> void:
	_matched = 0
	_input_locked = true
	_worn_items.clear()
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	var weather: Dictionary = _pick_weather()
	_current_weather = weather
	_update_weather_display(weather)
	_spawn_weather_particles(weather)
	## Прогресивна складність (LAW 6, A4)
	var correct_count: int = _scale_by_round_i(2, 3, _round, _total_rounds)
	var wrong_count: int = _scale_by_round_i(1, 4, _round, _total_rounds)
	## LAW 2: мінімум 3 вибори
	if correct_count + wrong_count < 3:
		wrong_count = 3 - correct_count
	var correct_items: Array = weather.get("correct", []).slice(0, correct_count)
	var wrong_items: Array = weather.get("wrong", []).slice(0, wrong_count)
	_total = correct_items.size()
	## LAW 15: count-after-create — _total встановлений з correct_items.size()
	if _total <= 0:
		push_warning("WeatherDress: _total = 0 після slice — fallback до 2")
		correct_items = weather.get("correct", ["hat", "shorts"]).slice(0, 2)
		_total = correct_items.size()
	_spawn_clothing(correct_items, wrong_items)
	## Показати зони (fade in)
	_show_zone_hints(true)


func _pick_weather() -> Dictionary:
	if WEATHERS.is_empty():
		push_warning("WeatherDress: WEATHERS порожній — критичний fallback")
		return {"id": "sunny", "icon": "sun", "key": "WEATHER_SUNNY",
			"correct": ["hat", "shorts"], "wrong": ["coat"]}
	if _used_weathers.size() >= WEATHERS.size():
		_used_weathers.clear()
	var idx: int = randi() % WEATHERS.size()
	var attempts: int = 0
	while _used_weathers.has(idx) and attempts < WEATHERS.size() * 2:
		idx = randi() % WEATHERS.size()
		attempts += 1
	_used_weathers.append(idx)
	return WEATHERS[idx]


func _update_weather_display(weather: Dictionary) -> void:
	if not is_instance_valid(_weather_display):
		push_warning("WeatherDress: _weather_display невалідний")
		return
	for child: Node in _weather_display.get_children():
		child.queue_free()
	var icon_id: String = weather.get("icon", "sun")
	var w_icon: Control = _weather_icon(icon_id, 40.0)
	w_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_display.add_child(w_icon)
	var w_lbl: Label = Label.new()
	w_lbl.text = tr(weather.get("key", "WEATHER_SUNNY"))
	w_lbl.add_theme_font_size_override("font_size", 48)
	_weather_display.add_child(w_lbl)


## ---- Погодні частинки (CPUParticles2D, LAW 18/21) ----

func _spawn_weather_particles(weather: Dictionary) -> void:
	_clear_weather_particles()
	var weather_id: String = weather.get("id", "sunny")
	## Сонячна / спекотна / хмарна — без частинок
	if weather_id in ["sunny", "hot", "cloudy"]:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_weather_particles = CPUParticles2D.new()
	_weather_particles.z_index = -1  ## За Тофі
	_weather_particles.position = Vector2(vp.x * 0.5, -20.0)
	_weather_particles.emitting = true
	_weather_particles.amount = 30
	_weather_particles.lifetime = 3.0
	_weather_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_weather_particles.emission_rect_extents = Vector2(vp.x * 0.5, 10.0)
	match weather_id:
		"rainy", "stormy":
			## Краплі дощу
			_weather_particles.direction = Vector2(0, 1)
			_weather_particles.gravity = Vector2(0, 400)
			_weather_particles.initial_velocity_min = 100.0
			_weather_particles.initial_velocity_max = 200.0
			_weather_particles.scale_amount_min = 1.5
			_weather_particles.scale_amount_max = 3.0
			_weather_particles.color = Color("93c5fd", 0.6)
			if weather_id == "stormy":
				_weather_particles.amount = 50
				_weather_particles.gravity = Vector2(50, 500)
		"snowy":
			## Сніжинки
			_weather_particles.direction = Vector2(0.2, 1)
			_weather_particles.gravity = Vector2(10, 40)
			_weather_particles.initial_velocity_min = 20.0
			_weather_particles.initial_velocity_max = 50.0
			_weather_particles.scale_amount_min = 2.0
			_weather_particles.scale_amount_max = 4.0
			_weather_particles.color = Color(1, 1, 1, 0.7)
			_weather_particles.spread = 30.0
		"windy":
			## Вітер — горизонтальні лінії
			_weather_particles.direction = Vector2(1, 0.1)
			_weather_particles.gravity = Vector2(200, 20)
			_weather_particles.initial_velocity_min = 150.0
			_weather_particles.initial_velocity_max = 300.0
			_weather_particles.scale_amount_min = 2.0
			_weather_particles.scale_amount_max = 4.0
			_weather_particles.color = Color("b8c0cc", 0.4)
			_weather_particles.spread = 10.0
		"foggy":
			## Легкий туман
			_weather_particles.direction = Vector2(0.5, 0.1)
			_weather_particles.gravity = Vector2(5, 2)
			_weather_particles.initial_velocity_min = 10.0
			_weather_particles.initial_velocity_max = 30.0
			_weather_particles.scale_amount_min = 8.0
			_weather_particles.scale_amount_max = 15.0
			_weather_particles.color = Color(1, 1, 1, 0.15)
			_weather_particles.amount = 15
			_weather_particles.lifetime = 5.0
	add_child(_weather_particles)
	_all_round_nodes.append(_weather_particles)


func _clear_weather_particles() -> void:
	if is_instance_valid(_weather_particles):
		_weather_particles.emitting = false
		_weather_particles.queue_free()
	_weather_particles = null


## ---- Одяг (spawning) ----

func _spawn_clothing(correct: Array, wrong: Array) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var all_items: Array[String] = []
	for c: Variant in correct:
		all_items.append(str(c))
	for w: Variant in wrong:
		all_items.append(str(w))
	all_items.shuffle()
	var count: int = all_items.size()
	if count <= 0:
		push_warning("WeatherDress: 0 clothing items — неможливий стан")
		return
	var spacing: float = vp.x / float(count + 1)
	var item_y: float = vp.y * 0.82
	for i: int in count:
		var clothing_id: String = all_items[i]
		var is_correct: bool = correct.has(clothing_id)
		var item: Node2D = Node2D.new()
		add_child(item)
		## Фон картки (LAW 28: premium panel)
		var bg: Panel = Panel.new()
		bg.size = SLOT_SIZE
		bg.position = Vector2(-SLOT_SIZE.x * 0.5, -SLOT_SIZE.y * 0.5)
		var style: StyleBoxFlat = GameData.candy_panel(Color("fff8e1"), SLOT_CORNER)
		bg.add_theme_stylebox_override("panel", style)
		bg.material = GameData.create_premium_material(
			0.04, 2.0, 0.03, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		GameData.add_gloss(bg, 10)
		item.add_child(bg)
		## Іконка одягу (IconDraw)
		var clothing_icon: Control = _clothing_icon(clothing_id, 36.0)
		clothing_icon.position = Vector2(-18.0, -18.0)
		clothing_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(clothing_icon)
		## Мітка зони (LAW 25: secondary visual encoding)
		var zone_id: int = CLOTHING_ZONE.get(clothing_id, BodyZone.BODY)
		var zone_label: Label = Label.new()
		zone_label.text = _zone_name(zone_id)
		zone_label.add_theme_font_size_override("font_size", 24)
		zone_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 0.8))
		zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		zone_label.position = Vector2(-SLOT_SIZE.x * 0.5, SLOT_SIZE.y * 0.3)
		zone_label.size = Vector2(SLOT_SIZE.x, 20)
		item.add_child(zone_label)
		var target: Vector2 = Vector2(spacing * float(i + 1), item_y)
		_item_correct[item] = is_correct
		_item_origins[item] = target
		_item_clothing_id[item] = clothing_id
		_clothing_items.append(item)
		_drag.draggable_items.append(item)
		_all_round_nodes.append(item)
		## Deal анімація (LAW 23: input locked)
		if SettingsManager.reduced_motion:
			item.position = target
			item.modulate.a = 1.0
			if i == count - 1:
				_input_locked = false
				_drag.enabled = true
				_reset_idle_timer()
		else:
			item.position = Vector2(target.x, vp.y + 100.0)
			item.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = _create_game_tween().set_parallel(true)
			tw.tween_property(item, "position", target, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
			if i == count - 1:
				tw.chain().tween_callback(func() -> void:
					_input_locked = false
					_drag.enabled = true
					_reset_idle_timer())


## ---- Input ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_input(event)


func _process(delta: float) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_process(delta)


## ---- Drop / drag callbacks ----

func _on_picked(_item: Node2D) -> void:
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	_show_zone_hints(true)


func _on_dropped_target(item: Node2D, target: Node2D) -> void:
	if _game_over:
		return
	var is_correct: bool = _item_correct.get(item, false)
	var clothing_id: String = _item_clothing_id.get(item, "")
	var expected_zone: int = CLOTHING_ZONE.get(clothing_id, BodyZone.BODY)
	var target_zone: int = target.get_meta("zone_id") if target.has_meta("zone_id") else -1
	if is_correct and target_zone == expected_zone:
		_handle_correct(item, target)
	elif is_correct and target_zone != expected_zone:
		## Правильний одяг, але не та зона — snap back без помилки
		_drag.snap_back(item, _item_origins.get(item, item.position))
		_animate_zone_hint(expected_zone)
	else:
		_handle_wrong(item)
	_show_zone_hints(false)


func _on_dropped_empty(item: Node2D) -> void:
	_drag.snap_back(item, _item_origins.get(item, item.position))
	_show_zone_hints(false)


func _handle_correct(item: Node2D, target: Node2D) -> void:
	_register_correct(item)
	VFXManager.spawn_success_ripple(item.global_position, Color(0.4, 1.0, 0.4))
	_item_correct.erase(item)
	_item_origins.erase(item)
	_item_clothing_id.erase(item)
	_drag.draggable_items.erase(item)
	_clothing_items.erase(item)
	_matched += 1
	var zone_id: int = target.get_meta("zone_id") if target.has_meta("zone_id") else BodyZone.BODY
	_worn_items[zone_id] = item
	## Одяг snap-ується до зони на Тофі
	if SettingsManager.reduced_motion:
		item.global_position = target.global_position
		item.scale = Vector2(0.8, 0.8)
		if _matched >= _total:
			_on_round_complete()
		else:
			_reset_idle_timer()
		return
	var tw: Tween = _create_game_tween().set_parallel(true)
	tw.tween_property(item, "global_position", target.global_position, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "scale", Vector2(0.8, 0.8), 0.2)
	## Тофі "радіє" — маленький bounce
	if is_instance_valid(_tofie_node):
		var tofie_tw: Tween = _create_game_tween()
		tofie_tw.tween_property(_tofie_node, "scale", Vector2(1.05, 0.95), 0.1)
		tofie_tw.tween_property(_tofie_node, "scale", Vector2(0.98, 1.02), 0.1)
		tofie_tw.tween_property(_tofie_node, "scale", Vector2.ONE, 0.1)
	if _matched >= _total:
		tw.chain().tween_callback(_on_round_complete)
	else:
		_reset_idle_timer()


func _handle_wrong(item: Node2D) -> void:
	if _is_toddler:
		_register_error(item)  ## A6: м'який фідбек, A11: scaffolding
	else:
		_errors += 1  ## A7: preschool рахує помилки
		_register_error(item)
	_drag.snap_back(item, _item_origins.get(item, item.position))
	## Тофі "реагує" на неправильний одяг
	_animate_tofie_reaction()


## Тофі дрожить (холодна погода + неправильний одяг) або виражає незгоду
func _animate_tofie_reaction() -> void:
	if not is_instance_valid(_tofie_node) or SettingsManager.reduced_motion:
		return
	var orig_x: float = _tofie_node.position.x
	var tw: Tween = _create_game_tween()
	## Тремтіння
	tw.tween_property(_tofie_node, "position:x", orig_x - 4.0, 0.04)
	tw.tween_property(_tofie_node, "position:x", orig_x + 4.0, 0.04)
	tw.tween_property(_tofie_node, "position:x", orig_x - 3.0, 0.04)
	tw.tween_property(_tofie_node, "position:x", orig_x + 3.0, 0.04)
	tw.tween_property(_tofie_node, "position:x", orig_x - 2.0, 0.03)
	tw.tween_property(_tofie_node, "position:x", orig_x, 0.03)
	## Тимчасовий червонуватий відтінок (gentle)
	tw.parallel().tween_property(_tofie_node, "modulate", Color(1.15, 0.9, 0.9), 0.1)
	tw.tween_property(_tofie_node, "modulate", Color.WHITE, 0.3)


## Зона блимає щоб показати де правильна зона (при drop на неправильну зону)
func _animate_zone_hint(zone_id: int) -> void:
	var target: Node2D = _zone_targets.get(zone_id)
	if not target or not is_instance_valid(target):
		push_warning("WeatherDress: zone target %d невалідний" % zone_id)
		return
	var panel: Panel = target.get_meta("zone_panel") if target.has_meta("zone_panel") else null
	if not panel or not is_instance_valid(panel):
		return
	if SettingsManager.reduced_motion:
		return
	var tw: Tween = _create_game_tween()
	tw.tween_property(panel, "modulate:a", 0.8, 0.15)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)


## Показати/приховати drop zone hints
func _show_zone_hints(show: bool) -> void:
	for zone_id: int in _zone_targets:
		var target: Node2D = _zone_targets.get(zone_id)
		if not target or not is_instance_valid(target):
			continue
		## Не показувати зони де вже одягнено
		if _worn_items.has(zone_id):
			continue
		var panel: Variant = target.get_meta("zone_panel") if target.has_meta("zone_panel") else null
		if panel and is_instance_valid(panel):
			if SettingsManager.reduced_motion:
				panel.modulate.a = 0.5 if show else 0.0
			else:
				var tw: Tween = _create_game_tween()
				tw.tween_property(panel, "modulate:a", 0.5 if show else 0.0, 0.2)


## ---- Round management ----

func _on_round_complete() -> void:
	_input_locked = true
	_drag.enabled = false
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_correct_sparkle(get_viewport().get_visible_rect().size / 2.0)
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	## Тофі святкує — bounce + walk away
	_animate_tofie_celebration()
	var round_d: float = 0.15 if SettingsManager.reduced_motion else 1.2
	var tw: Tween = _create_game_tween()
	tw.tween_interval(round_d)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):  ## LAW 20: await safety
			return
		_clear_round()
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round())


## Тофі радіє після повного одягання — bounce і малий "dance"
func _animate_tofie_celebration() -> void:
	if not is_instance_valid(_tofie_node) or SettingsManager.reduced_motion:
		return
	var tw: Tween = _create_game_tween()
	tw.tween_property(_tofie_node, "position:y",
		_tofie_node.position.y - 20.0, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_tofie_node, "position:y",
		_tofie_center.y, 0.3)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_tofie_node, "scale", Vector2(1.08, 0.92), 0.1)
	tw.tween_property(_tofie_node, "scale", Vector2(0.95, 1.05), 0.1)
	tw.tween_property(_tofie_node, "scale", Vector2.ONE, 0.15)


func _clear_round() -> void:
	## LAW 9: erase dict entries BEFORE queue_free (LAW 17 pattern)
	for item: Node in _all_round_nodes:
		_item_correct.erase(item)
		_item_origins.erase(item)
		_item_clothing_id.erase(item)
		if is_instance_valid(item):
			item.queue_free()
	_all_round_nodes.clear()
	_clothing_items.clear()
	_item_correct.clear()
	_item_origins.clear()
	_item_clothing_id.clear()
	_worn_items.clear()
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	_drag.clear_drag()
	_clear_weather_particles()
	## Перезареєструвати зони як drop targets (Тофі зберігається між раундами)
	for zone_id: int in _zone_targets:
		var target: Node2D = _zone_targets.get(zone_id)
		if target and is_instance_valid(target):
			_drag.drop_targets.append(target)
			## Скинути зони
			var panel: Variant = target.get_meta("zone_panel") if target.has_meta("zone_panel") else null
			if panel and is_instance_valid(panel):
				panel.modulate.a = 0.0
	## Скинути Тофі до нормального стану
	if is_instance_valid(_tofie_node):
		_tofie_node.position = _tofie_center
		_tofie_node.scale = Vector2.ONE
		_tofie_node.modulate = Color.WHITE


func _finish() -> void:
	_game_over = true
	_input_locked = true
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size / 2.0)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": _total_rounds, "earned_stars": earned})


## ---- IconDraw хелпери ----

static func _weather_icon(id: String, size: float) -> Control:
	match id:
		"sun": return IconDraw.sun_icon(size)
		"rain": return IconDraw.rain_icon(size)
		"snowflake": return IconDraw.snowflake(size)
		"wind": return IconDraw.wind_icon(size)
		"cloud": return IconDraw.cloud_icon(size)
		"storm": return IconDraw.storm_icon(size)
		_:
			push_warning("WeatherDress: невідомий weather icon id: " + id)
			return IconDraw.sun_icon(size)


static func _clothing_icon(id: String, size: float) -> Control:
	match id:
		"sunglasses": return IconDraw.sunglasses_icon(size)
		"hat": return IconDraw.cap_icon(size)
		"shorts": return IconDraw.shorts_icon(size)
		"scarf": return IconDraw.scarf_icon(size)
		"mittens": return IconDraw.mittens_icon(size)
		"boots": return IconDraw.boots_icon(size)
		"umbrella": return IconDraw.umbrella_icon(size)
		"raincoat": return IconDraw.raincoat_icon(size)
		"coat": return IconDraw.coat_icon(size)
		"jacket": return IconDraw.jacket_icon(size)
		_:
			push_warning("WeatherDress: невідомий clothing icon id: " + id)
			return IconDraw.shirt(size)


## Локалізована назва зони (A12: i18n)
static func _zone_name(zone: int) -> String:
	match zone:
		BodyZone.HEAD: return tr("ZONE_HEAD")
		BodyZone.BODY: return tr("ZONE_BODY")
		BodyZone.LEGS: return tr("ZONE_LEGS")
		BodyZone.HANDS: return tr("ZONE_HANDS")
		BodyZone.ACCESSORY: return tr("ZONE_ACCESSORY")
		_: return ""


## ---- Idle hint (A10) ----

func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over or _clothing_items.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	## Підсвітити перший правильний item
	for item: Node2D in _clothing_items:
		if is_instance_valid(item) and _item_correct.get(item, false):
			_pulse_node(item, 1.15)
			break
	_reset_idle_timer()


## ---- TofieDrawer — внутрішній клас для малювання персонажа ----

class TofieDrawer extends Node2D:

	## Малює Тофі як paper-doll (LAW 28: premium multi-layer)
	func _draw() -> void:
		## Тінь під Тофі
		draw_ellipse(Vector2(0, 85), Vector2(40, 10), Color(0, 0, 0, 0.12))
		## Ноги
		_draw_leg(Vector2(-18, 45), Vector2(14, 45))
		_draw_leg(Vector2(18, 45), Vector2(14, 45))
		## Тіло (закруглений торс)
		_draw_body(Vector2(0, 10), Vector2(44, 60))
		## Руки
		_draw_arm(Vector2(-38, 0), Vector2(12, 40))
		_draw_arm(Vector2(38, 0), Vector2(12, 40))
		## Голова (велика для дитячих пропорцій)
		_draw_head(Vector2(0, -55), 35.0)

	func _draw_head(center: Vector2, radius: float) -> void:
		## Тінь
		draw_circle(center + Vector2(2, 3), radius + 1.0, Color(0, 0, 0, 0.10))
		## Основа голови
		draw_circle(center, radius, Color("ffe4c4"))
		## Світлий блік (LAW 28: depth)
		draw_circle(center + Vector2(-radius * 0.25, -radius * 0.25),
			radius * 0.5, Color("fff5e6", 0.6))
		## Sparkle
		draw_circle(center + Vector2(-radius * 0.3, -radius * 0.35),
			maxf(radius * 0.08, 1.0), Color(1, 1, 1, 0.5))
		## Очі
		var eye_y: float = center.y - 5.0
		var eye_dist: float = 12.0
		draw_circle(Vector2(center.x - eye_dist, eye_y), 5.0, Color("2d3436"))
		draw_circle(Vector2(center.x + eye_dist, eye_y), 5.0, Color("2d3436"))
		## Блиски в очах
		draw_circle(Vector2(center.x - eye_dist + 2, eye_y - 2), 1.8, Color(1, 1, 1, 0.8))
		draw_circle(Vector2(center.x + eye_dist + 2, eye_y - 2), 1.8, Color(1, 1, 1, 0.8))
		## Рум'янець (LAW 28: premium detail)
		draw_circle(Vector2(center.x - 18, center.y + 5), 6.0, Color("fab1a0", 0.35))
		draw_circle(Vector2(center.x + 18, center.y + 5), 6.0, Color("fab1a0", 0.35))
		## Посмішка
		var smile_pts: PackedVector2Array = PackedVector2Array()
		for a: int in range(-40, 41, 10):
			var rad: float = deg_to_rad(float(a))
			smile_pts.append(Vector2(center.x + cos(rad) * 10.0, center.y + 10.0 + sin(rad) * 4.0))
		if smile_pts.size() >= 2:
			draw_polyline(smile_pts, Color("e17055"), 2.0, true)
		## Вушка (маленькі трикутні — Тофі = лисичка-персонаж)
		var left_ear: PackedVector2Array = PackedVector2Array([
			Vector2(center.x - radius * 0.6, center.y - radius * 0.7),
			Vector2(center.x - radius * 0.85, center.y - radius * 1.3),
			Vector2(center.x - radius * 0.2, center.y - radius * 0.85),
		])
		var right_ear: PackedVector2Array = PackedVector2Array([
			Vector2(center.x + radius * 0.6, center.y - radius * 0.7),
			Vector2(center.x + radius * 0.85, center.y - radius * 1.3),
			Vector2(center.x + radius * 0.2, center.y - radius * 0.85),
		])
		draw_colored_polygon(left_ear, Color("ffcc80"))
		draw_colored_polygon(right_ear, Color("ffcc80"))
		## Внутрішня частина вушок (LAW 28: depth detail)
		var left_inner: PackedVector2Array = PackedVector2Array([
			Vector2(center.x - radius * 0.55, center.y - radius * 0.75),
			Vector2(center.x - radius * 0.75, center.y - radius * 1.15),
			Vector2(center.x - radius * 0.3, center.y - radius * 0.85),
		])
		var right_inner: PackedVector2Array = PackedVector2Array([
			Vector2(center.x + radius * 0.55, center.y - radius * 0.75),
			Vector2(center.x + radius * 0.75, center.y - radius * 1.15),
			Vector2(center.x + radius * 0.3, center.y - radius * 0.85),
		])
		draw_colored_polygon(left_inner, Color("ffab91", 0.6))
		draw_colored_polygon(right_inner, Color("ffab91", 0.6))
		## Ніс (маленький трикутник)
		var nose: PackedVector2Array = PackedVector2Array([
			Vector2(center.x, center.y + 2),
			Vector2(center.x - 3, center.y + 6),
			Vector2(center.x + 3, center.y + 6),
		])
		draw_colored_polygon(nose, Color("2d3436", 0.7))

	func _draw_body(center: Vector2, size: Vector2) -> void:
		var rect: Rect2 = Rect2(center - size * 0.5, size)
		## Тінь (LAW 28)
		draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.10), true)
		## Основа
		draw_rect(rect, Color("ffdab9"), true)
		## Блік
		var highlight_rect: Rect2 = Rect2(rect.position + Vector2(4, 4),
			Vector2(rect.size.x * 0.4, rect.size.y * 0.5))
		draw_rect(highlight_rect, Color("fff5e6", 0.4), true)

	func _draw_leg(center: Vector2, size: Vector2) -> void:
		var rect: Rect2 = Rect2(center - Vector2(size.x * 0.5, 0), size)
		draw_rect(Rect2(rect.position + Vector2(1, 2), rect.size), Color(0, 0, 0, 0.08), true)
		draw_rect(rect, Color("ffc8a0"), true)
		## "Черевик" внизу
		var shoe_rect: Rect2 = Rect2(
			Vector2(rect.position.x - 2, rect.end.y - 10),
			Vector2(size.x + 4, 10))
		draw_rect(shoe_rect, Color("8B6914"), true)

	func _draw_arm(center: Vector2, size: Vector2) -> void:
		var rect: Rect2 = Rect2(center - size * 0.5, size)
		draw_rect(Rect2(rect.position + Vector2(1, 2), rect.size), Color(0, 0, 0, 0.08), true)
		draw_rect(rect, Color("ffd0a8"), true)

	## Допоміжна — малює еліпс через polygon approximation
	func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
		var points: PackedVector2Array = PackedVector2Array()
		var segments: int = 24
		for i: int in segments:
			var angle: float = TAU * float(i) / float(segments)
			points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
		if points.size() >= 3:
			draw_colored_polygon(points, color)
