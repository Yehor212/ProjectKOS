extends BaseMiniGame

## ECE-12 Кліматичний гардероб — одягни тваринку за погодою!
## Toddler: 2 одяги, 3 раунди. Preschool: 3 одяги, 4 раунди.

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 5
const ITEMS_TODDLER: int = 3  ## LAW 2: мінімум 3 вибори (research: 2 = OK для toddler, але 3 = краще для learning)
const ITEMS_PRESCHOOL: int = 3
const DEAL_STAGGER: float = 0.12
const DEAL_DURATION: float = 0.35
const IDLE_HINT_DELAY: float = 5.0
const SLOT_SIZE: Vector2 = Vector2(90, 90)
const SLOT_CORNER: int = 16
const SLOT_BG: Color = Color(1.0, 0.97, 0.88, 0.6)
const SLOT_BORDER: Color = Color("ffd166")
const SAFETY_TIMEOUT_SEC: float = 120.0

## Погода та відповідний одяг (IconDraw-based UI)
const WEATHERS: Array[Dictionary] = [
	{"id": "sunny", "icon": "sun", "key": "WEATHER_SUNNY",
		"correct": ["sunglasses", "hat", "shorts"],
		"wrong": ["scarf", "mittens", "boots"]},
	{"id": "rainy", "icon": "rain", "key": "WEATHER_RAINY",
		"correct": ["umbrella", "raincoat", "boots"],
		"wrong": ["sunglasses", "shorts", "hat"]},
	{"id": "snowy", "icon": "snowflake", "key": "WEATHER_SNOWY",
		"correct": ["scarf", "mittens", "coat"],
		"wrong": ["shorts", "sunglasses", "umbrella"]},
	{"id": "windy", "icon": "wind", "key": "WEATHER_WINDY",
		"correct": ["jacket", "hat", "scarf"],
		"wrong": ["shorts", "sunglasses", "umbrella"]},
	## Розширений пул погод — 8 варіантів для ≥5 унікальних сесій
	{"id": "cloudy", "icon": "cloud", "key": "WEATHER_CLOUDY",
		"correct": ["jacket", "hat", "umbrella"],
		"wrong": ["sunglasses", "shorts", "mittens"]},
	{"id": "stormy", "icon": "storm", "key": "WEATHER_STORMY",
		"correct": ["raincoat", "boots", "umbrella"],
		"wrong": ["sunglasses", "hat", "shorts"]},
	{"id": "hot", "icon": "sun", "key": "WEATHER_HOT",
		"correct": ["sunglasses", "hat", "shorts"],
		"wrong": ["coat", "scarf", "mittens"]},
	{"id": "foggy", "icon": "cloud", "key": "WEATHER_FOGGY",
		"correct": ["jacket", "boots", "scarf"],
		"wrong": ["shorts", "sunglasses", "hat"]},
]

## Іконки одягу — ID для IconDraw методів
const CLOTHING_ICONS: Dictionary = {
	"sunglasses": "sunglasses", "hat": "hat", "shorts": "shorts",
	"scarf": "scarf", "mittens": "mittens", "boots": "boots",
	"umbrella": "umbrella", "raincoat": "raincoat", "coat": "coat",
	"jacket": "jacket",
}

var _is_toddler: bool = false
var _drag: UniversalDrag = null
var _round: int = 0
var _total_rounds: int = 0
var _matched: int = 0
var _total: int = 0
var _start_time: float = 0.0

var _clothing_items: Array[Node2D] = []
var _drop_zone: Node2D = null
var _all_round_nodes: Array[Node] = []
var _item_correct: Dictionary = {}
var _item_origins: Dictionary = {}
var _used_weathers: Array[int] = []

var _weather_container: HBoxContainer = null
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
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("DRESS_TUTORIAL_TODDLER")
	return tr("DRESS_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _clothing_items.is_empty() or not _drop_zone:
		return {}
	for item: Node2D in _clothing_items:
		if is_instance_valid(item) and _item_correct.get(item, false):
			return {"type": "drag", "from": item.global_position, "to": _drop_zone.global_position}
	return {}


func _build_hud() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_build_instruction_pill(get_tutorial_instruction())
	_weather_container = HBoxContainer.new()
	_weather_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_weather_container.set("theme_override_constants/separation", 12)
	_weather_container.position = Vector2(0, 140)
	_weather_container.size = Vector2(vp.x, 60)
	add_child(_weather_container)


## ---- Раунди ----

func _start_round() -> void:
	_matched = 0
	_input_locked = true
	var item_count: int = ITEMS_TODDLER if _is_toddler else ITEMS_PRESCHOOL
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	var weather: Dictionary = _pick_weather()
	## Оновити weather display: іконка + текст
	for child: Node in _weather_container.get_children():
		child.queue_free()
	var w_icon: Control = _weather_icon(weather.icon, 40.0)
	w_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_container.add_child(w_icon)
	var w_lbl: Label = Label.new()
	w_lbl.text = tr(weather.key)
	w_lbl.add_theme_font_size_override("font_size", 48)
	_weather_container.add_child(w_lbl)
	var correct_items: Array = weather.correct.slice(0, item_count)
	## Прогресивна складність: ранні раунди менше відволікачів
	var wrong_count: int = _scale_by_round_i(1, item_count, _round, _total_rounds)
	var wrong_items: Array = weather.wrong.slice(0, wrong_count)
	_total = correct_items.size()
	_spawn_drop_zone()
	_spawn_clothing(correct_items, wrong_items)


func _pick_weather() -> Dictionary:
	if _used_weathers.size() >= WEATHERS.size():
		_used_weathers.clear()
	var idx: int = randi() % WEATHERS.size()
	while _used_weathers.has(idx):
		idx = randi() % WEATHERS.size()
	_used_weathers.append(idx)
	return WEATHERS[idx]


func _spawn_drop_zone() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_drop_zone = Node2D.new()
	_drop_zone.position = Vector2(vp.x * 0.5, vp.y * 0.42)
	add_child(_drop_zone)
	## Велике коло для drop
	var sz: float = 140.0
	var panel: Panel = Panel.new()
	panel.size = Vector2(sz, sz)
	panel.position = Vector2(-sz * 0.5, -sz * 0.5)
	var style: StyleBoxFlat = GameData.candy_circle(Color(1.0, 0.97, 0.88, 0.35), sz * 0.5)
	style.border_color = SLOT_BORDER
	style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)
	## Grain + gloss (LAW 28 V162)
	panel.material = GameData.create_premium_material(0.04, 2.0, 0.04, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
	GameData.add_gloss(panel, 12)
	_drop_zone.add_child(panel)
	## Іконка одягу в дропзоні
	var drop_icon: Control = IconDraw.shirt(40.0)
	drop_icon.position = Vector2(-20.0, -20.0)
	drop_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone.add_child(drop_icon)
	_drag.drop_targets.append(_drop_zone)
	_all_round_nodes.append(_drop_zone)


func _spawn_clothing(correct: Array, wrong: Array) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var all_items: Array[String] = []
	for c: String in correct:
		all_items.append(c)
	for w: String in wrong:
		all_items.append(w)
	all_items.shuffle()
	var count: int = all_items.size()
	var spacing: float = vp.x / float(count + 1)
	var item_y: float = vp.y * 0.78
	for i: int in count:
		var clothing_id: String = all_items[i]
		var is_correct: bool = correct.has(clothing_id)
		var icon_id: String = CLOTHING_ICONS.get(clothing_id, "sunglasses")
		var item: Node2D = Node2D.new()
		add_child(item)
		## Фон
		var bg: Panel = Panel.new()
		bg.size = SLOT_SIZE
		bg.position = Vector2(-SLOT_SIZE.x * 0.5, -SLOT_SIZE.y * 0.5)
		var style: StyleBoxFlat = GameData.candy_panel(Color("fff8e1"), SLOT_CORNER)
		bg.add_theme_stylebox_override("panel", style)
		## Grain overlay (LAW 28)
		bg.material = GameData.create_premium_material(0.04, 2.0, 0.03, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		GameData.add_gloss(bg, 10)
		item.add_child(bg)
		## Іконка одягу (IconDraw)
		var clothing_icon: Control = _clothing_icon(icon_id, 36.0)
		clothing_icon.position = Vector2(-18.0, -18.0)
		clothing_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(clothing_icon)
		var target: Vector2 = Vector2(spacing * float(i + 1), item_y)
		_item_correct[item] = is_correct
		_item_origins[item] = target
		_clothing_items.append(item)
		_drag.draggable_items.append(item)
		_all_round_nodes.append(item)
		## Deal анімація
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
			var tw: Tween = create_tween().set_parallel(true)
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


## ---- Drop ----

func _on_picked(_item: Node2D) -> void:
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()


func _on_dropped_target(item: Node2D, _target: Node2D) -> void:
	if _game_over:
		return
	var is_correct: bool = _item_correct.get(item, false)
	if is_correct:
		_handle_correct(item)
	else:
		_handle_wrong(item)


func _on_dropped_empty(item: Node2D) -> void:
	_drag.snap_back(item, _item_origins.get(item, item.position))


func _handle_correct(item: Node2D) -> void:
	_register_correct(item)
	_drag.draggable_items.erase(item)
	_clothing_items.erase(item)
	_matched += 1
	## Одяг зникає з ефектом
	if SettingsManager.reduced_motion:
		item.global_position = _drop_zone.global_position
		item.scale = Vector2(0.3, 0.3)
		item.modulate.a = 0.0
		if _matched >= _total:
			_on_round_complete()
		else:
			_reset_idle_timer()
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(item, "global_position", _drop_zone.global_position, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "scale", Vector2(0.3, 0.3), 0.25)
	tw.tween_property(item, "modulate:a", 0.0, 0.2).set_delay(0.15)
	if _matched >= _total:
		tw.chain().tween_callback(_on_round_complete)
	else:
		_reset_idle_timer()


func _handle_wrong(item: Node2D) -> void:
	if _is_toddler:
		_register_error(item)  ## A11: scaffolding для тоддлера
	else:
		_errors += 1
		_register_error(item)
	_drag.snap_back(item, _item_origins.get(item, item.position))
	## Animated consequence: дропзона "тремтить" показуючи що одяг не підходить
	_animate_wrong_consequence()


## Animated consequence: дропзона тремтить + тимчасово червоніє при неправильному одязі
func _animate_wrong_consequence() -> void:
	if not is_instance_valid(_drop_zone) or SettingsManager.reduced_motion:
		return
	var orig_x: float = _drop_zone.position.x
	var tw: Tween = create_tween()
	## Тремтіння (cold shiver effect)
	tw.tween_property(_drop_zone, "position:x", orig_x - 5.0, 0.04)
	tw.tween_property(_drop_zone, "position:x", orig_x + 5.0, 0.04)
	tw.tween_property(_drop_zone, "position:x", orig_x - 3.0, 0.04)
	tw.tween_property(_drop_zone, "position:x", orig_x + 3.0, 0.04)
	tw.tween_property(_drop_zone, "position:x", orig_x, 0.04)
	## Тимчасовий червоний відтінок (gentle, не страшний)
	tw.parallel().tween_property(_drop_zone, "modulate", Color(1.2, 0.85, 0.85), 0.1)
	tw.tween_property(_drop_zone, "modulate", Color.WHITE, 0.3)


## ---- Round management ----

func _on_round_complete() -> void:
	_input_locked = true
	_drag.enabled = false
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var round_d: float = 0.15 if SettingsManager.reduced_motion else 0.8
	var tw: Tween = create_tween()
	tw.tween_interval(round_d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round())


func _clear_round() -> void:
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_clothing_items.clear()
	_item_correct.clear()
	_item_origins.clear()
	_drop_zone = null
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	_drag.clear_drag()


func _finish() -> void:
	_game_over = true
	_input_locked = true
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


## ---- Idle hint ----

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
	for item: Node2D in _clothing_items:
		if is_instance_valid(item) and _item_correct.get(item, false):
			_pulse_node(item, 1.15)
			break
	_reset_idle_timer()
