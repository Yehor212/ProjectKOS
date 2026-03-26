extends BaseMiniGame

## Sorting — перетягни тварин до правильного середовища.
## Toddler: 2 категорії, 4 тварини. Preschool: 3 категорії, 6 тварин.

const TOTAL_ROUNDS: int = 3
const ITEMS_PER_CAT: int = 2
const ITEM_SIZE: float = 110.0
const ITEM_SPRITE_SCALE: Vector2 = Vector2(0.42, 0.42)
const ZONE_CORNER_RADIUS: int = 20
const ZONE_GAP: float = 30.0
const DEAL_STAGGER: float = 0.08
const DEAL_DURATION: float = 0.35
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0
const PICK_RADIUS: float = 80.0
const TILT_FACTOR: float = 0.001
const TILT_MAX: float = 0.4
const TILT_LERP: float = 15.0

const HABITATS: Array[Dictionary] = [
	{"id": "forest", "icon": "pine_tree", "color": Color("22c55e"),
	 "animals": ["Bear", "Deer", "Squirrel", "Hedgehog", "Bunny", "Frog", "Mouse"]},
	{"id": "farm", "icon": "home_house", "color": Color("f97316"),
	 "animals": ["Dog", "Cat", "Chicken", "Cow", "Horse", "Goat"]},
	{"id": "jungle", "icon": "palm_tree", "color": Color("a855f7"),
	 "animals": ["Monkey", "Elephant", "Lion", "Panda", "Crocodile", "Penguin"]},
]

var _is_toddler: bool = false
var _round: int = 0
var _sorted_count: int = 0
var _total_items: int = 0
var _start_time: float = 0.0

var _dragged: Node2D = null
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_original_z: int = 0
var _last_mouse: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO

var _items: Array[Node2D] = []
var _all_round_nodes: Array[Node] = []
var _item_data: Dictionary = {}
var _item_origins: Dictionary = {}
var _zones: Array[Dictionary] = []

var _idle_timer: SceneTreeTimer = null
var _narrative_label: Label = null


func _ready() -> void:
	game_id = "sorting"
	bg_theme = "beach"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_build_narrative_label(tr("GOING_HOME"))
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


## Наратив — "Допоможи тваринам знайти дім!" лейбл
func _build_narrative_label(text: String) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_narrative_label = Label.new()
	_narrative_label.text = text
	_narrative_label.add_theme_font_size_override("font_size", 28)
	_narrative_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_narrative_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narrative_label.position = Vector2(0, vp.y * 0.08)
	_narrative_label.size = Vector2(vp.x, 40)
	_ui_layer.add_child(_narrative_label)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("SORTING_TUTORIAL_TODDLER")
	return tr("SORTING_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _items.is_empty() or _zones.is_empty():
		return {}
	var item: Node2D = _items[0]
	var cat_id: String = _item_data.get(item, "")
	for zone: Dictionary in _zones:
		if zone.category_id == cat_id:
			return {"type": "drag", "from": item.global_position, "to": zone.rect.get_center()}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Round logic ----

func _start_round() -> void:
	_sorted_count = 0
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	var cat_count: int = 2 if _is_toddler else 3
	## Прогресивна складність: більше тварин на категорію в пізніших раундах
	var items_per_cat: int = _scale_by_round_i(1, ITEMS_PER_CAT, _round, TOTAL_ROUNDS)
	_total_items = cat_count * items_per_cat
	var cats: Array[Dictionary] = HABITATS.duplicate()
	cats.shuffle()
	var selected: Array[Dictionary] = []
	for i: int in cat_count:
		selected.append(cats[i])
	var animals: Array[Dictionary] = []
	for cat: Dictionary in selected:
		var pool: Array = cat.animals.duplicate()
		pool.shuffle()
		for j: int in mini(items_per_cat, pool.size()):
			animals.append({"name": pool[j], "category_id": cat.id})
	animals.shuffle()
	_spawn_zones(selected)
	_spawn_items(animals)
	## Guard: якщо жоден спрайт не завантажився — пропускаємо раунд (A8)
	if _total_items <= 0:
		push_warning("Sorting: жоден елемент не створено — пропускаємо раунд")
		_on_round_complete()


func _spawn_zones(cats: Array[Dictionary]) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = cats.size()
	var zone_w: float = 240.0 if count == 3 else 280.0
	var zone_h: float = vp.y * 0.35
	var total_w: float = zone_w * float(count) + ZONE_GAP * float(count - 1)
	var start_x: float = (vp.x - total_w) * 0.5
	var zone_y: float = vp.y * 0.18
	for i: int in count:
		var cat: Dictionary = cats[i]
		var x: float = start_x + float(i) * (zone_w + ZONE_GAP)
		var rect: Rect2 = Rect2(x, zone_y, zone_w, zone_h)
		## Фон зони — сучасний candy-стиль з тінню та градієнтом
		var panel: Panel = Panel.new()
		panel.position = Vector2(x, zone_y)
		panel.size = Vector2(zone_w, zone_h)
		var style: StyleBoxFlat = GameData.candy_cell(Color(cat.color, 0.82), 20, true)
		style.border_color = Color(cat.color, 0.9)
		style.set_border_width_all(3)
		style.set_content_margin_all(12)
		panel.add_theme_stylebox_override("panel", style)
		panel.material = GameData.create_premium_material(
			0.04, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.25, 0.20)  ## Premium overlay (LAW 28)
		add_child(panel)
		_all_round_nodes.append(panel)
		## Верхній блік — дитина panel, щоб успадковувала scale/modulate
		var gloss: Panel = Panel.new()
		gloss.position = Vector2(4.0, 4.0)
		gloss.size = Vector2(zone_w - 8.0, zone_h * 0.3)
		var gloss_style: StyleBoxFlat = StyleBoxFlat.new()
		gloss_style.bg_color = Color(1, 1, 1, 0.12)
		gloss_style.corner_radius_top_left = 24
		gloss_style.corner_radius_top_right = 24
		gloss_style.corner_radius_bottom_left = 12
		gloss_style.corner_radius_bottom_right = 12
		gloss.add_theme_stylebox_override("panel", gloss_style)
		gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(gloss)
		## Іконка середовища (IconDraw) — дитина panel
		var habitat_icon: Control = _habitat_icon(cat.icon, 56.0)
		habitat_icon.position = Vector2(zone_w * 0.5 - 28.0, 20.0)
		habitat_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(habitat_icon)
		## Назва категорії — дитина panel
		var name_lbl: Label = Label.new()
		name_lbl.text = tr("SORTING_CAT_%s" % cat.id.to_upper())
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		name_lbl.position = Vector2(0, 74)
		name_lbl.size = Vector2(zone_w, 30)
		panel.add_child(name_lbl)
		## Staggered zone entrance — діти успадковують transform (V3: reduced_motion)
		if not SettingsManager.reduced_motion:
			var zone_delay: float = float(i) * 0.1
			panel.pivot_offset = panel.size * 0.5
			panel.scale = Vector2(0.5, 0.5)
			panel.modulate.a = 0.0
			var ztw: Tween = _create_game_tween().set_parallel(true)
			ztw.tween_property(panel, "scale", Vector2.ONE, 0.3)\
				.set_delay(zone_delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ztw.tween_property(panel, "modulate:a", 1.0, 0.2).set_delay(zone_delay)
		_zones.append({"rect": rect, "category_id": cat.id, "panel": panel})


func _spawn_items(animals: Array[Dictionary]) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = animals.size()
	var spacing: float = vp.x / float(count + 1)
	var item_y: float = vp.y * 0.78
	for i: int in count:
		var data: Dictionary = animals[i]
		var target: Vector2 = Vector2(spacing * float(i + 1), item_y)
		var item: Node2D = _create_item(data.name)
		if not item:
			_total_items -= 1
			continue
		_item_data[item] = data.category_id
		_item_origins[item] = target
		## Deal анімація
		if SettingsManager.reduced_motion:
			item.position = target
			item.scale = Vector2.ONE
			item.modulate.a = 1.0
		else:
			item.position = Vector2(target.x, vp.y + 100.0)
			item.scale = Vector2(0.3, 0.3)
			item.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = create_tween().set_parallel(true)
			tw.tween_property(item, "position", target, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "scale", Vector2.ONE, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
	## Розблокувати після всіх анімацій deal (не залежить від останнього елемента)
	if _total_items > 0:
		var unlock_delay: float = 0.15 if SettingsManager.reduced_motion else (float(count - 1) * DEAL_STAGGER + DEAL_DURATION)
		var unlock_tw: Tween = create_tween()
		unlock_tw.tween_interval(unlock_delay)
		unlock_tw.tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer())


func _create_item(animal_name: String) -> Node2D:
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if not ResourceLoader.exists(tex_path):
		push_warning("Sorting: Missing sprite: " + tex_path)
		return null
	var tex: Texture2D = load(tex_path)
	if not tex:
		push_warning("Sorting: текстуру '%s' не знайдено" % tex_path)
		return null
	var node: Node2D = Node2D.new()
	add_child(node)
	## Кругле біле тло з тінню та глянцем
	var bg: Panel = Panel.new()
	bg.size = Vector2(ITEM_SIZE, ITEM_SIZE)
	bg.position = Vector2(-ITEM_SIZE * 0.5, -ITEM_SIZE * 0.5)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.set_corner_radius_all(int(ITEM_SIZE * 0.5))
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	style.border_color = Color(0, 0, 0, 0.12)
	style.set_border_width_all(3)
	style.border_width_bottom = 5
	bg.add_theme_stylebox_override("panel", style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.material = GameData.create_premium_material(
		0.03, 2.0, 0.03, 0.08, 0.04, 0.03, 0.06, "", 0.0, 0.08, 0.18, 0.15)
	node.add_child(bg)
	## Верхній глянцевий блік
	var gloss: Panel = Panel.new()
	gloss.size = Vector2(ITEM_SIZE - 12.0, ITEM_SIZE * 0.38)
	gloss.position = Vector2(-ITEM_SIZE * 0.5 + 6.0, -ITEM_SIZE * 0.5 + 4.0)
	var g_style: StyleBoxFlat = StyleBoxFlat.new()
	g_style.bg_color = Color(1, 1, 1, 0.35)
	g_style.corner_radius_top_left = int(ITEM_SIZE * 0.4)
	g_style.corner_radius_top_right = int(ITEM_SIZE * 0.4)
	g_style.corner_radius_bottom_left = int(ITEM_SIZE * 0.2)
	g_style.corner_radius_bottom_right = int(ITEM_SIZE * 0.2)
	gloss.add_theme_stylebox_override("panel", g_style)
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(gloss)
	## Спрайт тварини
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = ITEM_SPRITE_SCALE
	node.add_child(sprite)
	_items.append(node)
	_all_round_nodes.append(node)
	return node


## ---- Input & drag ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _dragged:
			_try_pick()
		elif not event.pressed and _dragged:
			_try_drop()
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed and not _dragged:
			_try_pick()
		elif not event.pressed and _dragged:
			_try_drop()


func _process(delta: float) -> void:
	if not _dragged:
		return
	var mouse: Vector2 = get_global_mouse_position()
	_drag_velocity = (mouse - _last_mouse) / maxf(delta, 0.001)
	_last_mouse = mouse
	_dragged.global_position = mouse + _drag_offset
	## Кінематичний нахил
	var rot: float = clampf(_drag_velocity.x * TILT_FACTOR, -TILT_MAX, TILT_MAX)
	_dragged.rotation = lerpf(_dragged.rotation, rot, TILT_LERP * delta)
	## Підсвітка зон
	for zone: Dictionary in _zones:
		var p: Panel = zone.panel
		if zone.rect.has_point(_dragged.global_position):
			p.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			p.modulate = Color.WHITE


func _try_pick() -> void:
	var mouse: Vector2 = get_global_mouse_position()
	var best: Node2D = null
	var pick_r: float = TODDLER_SNAP_RADIUS if _is_toddler else PICK_RADIUS
	var best_dist: float = pick_r
	for item: Node2D in _items:
		if not is_instance_valid(item):
			continue
		var d: float = mouse.distance_to(item.global_position)
		if d < best_dist:
			best_dist = d
			best = item
	if not best:
		return
	_dragged = best
	_drag_offset = best.global_position - mouse
	_drag_original_z = best.z_index
	_last_mouse = mouse
	_drag_velocity = Vector2.ZERO
	best.z_index = 10
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	if not SettingsManager.reduced_motion:
		var tw: Tween = create_tween()
		tw.tween_property(best, "scale", Vector2(0.85, 1.15), 0.06)
		tw.tween_property(best, "scale", Vector2.ONE, 0.06)


func _try_drop() -> void:
	if not _dragged:
		return
	var item: Node2D = _dragged
	var drop_pos: Vector2 = item.global_position
	_dragged = null
	item.z_index = _drag_original_z
	## Squish
	if not SettingsManager.reduced_motion:
		var sq: Tween = create_tween()
		sq.tween_property(item, "scale", Vector2(1.2, 0.8), 0.06)
		sq.tween_property(item, "scale", Vector2.ONE, 0.08)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## Скинути підсвітку зон
	for zone: Dictionary in _zones:
		zone.panel.modulate = Color.WHITE
	## Перевірити зони
	for zone: Dictionary in _zones:
		if zone.rect.has_point(drop_pos):
			if _item_data.get(item, "") == zone.category_id:
				_handle_correct(item, zone)
			else:
				_handle_wrong(item)
			return
	## Magnetic assist для тоддлерів — snap до найближчої зони
	if _is_toddler:
		var nearest_zone: Dictionary = {}
		var nearest_dist: float = TODDLER_SNAP_RADIUS
		for zone: Dictionary in _zones:
			var center: Vector2 = zone.rect.get_center()
			var d: float = drop_pos.distance_to(center)
			if d < nearest_dist:
				nearest_dist = d
				nearest_zone = zone
		if not nearest_zone.is_empty():
			if _item_data.get(item, "") == nearest_zone.category_id:
				_handle_correct(item, nearest_zone)
			else:
				_handle_wrong(item)
			return
	_snap_back(item)


## ---- Feedback ----

func _handle_correct(item: Node2D, zone: Dictionary) -> void:
	_register_correct(item)
	VFXManager.spawn_success_ripple(item.global_position, Color(0.4, 1.0, 0.6, 0.6))
	_items.erase(item)
	_sorted_count += 1
	var center: Vector2 = zone.rect.get_center()
	var offset: Vector2 = Vector2(randf_range(-25, 25), randf_range(10, 40))
	## Zone lights up briefly — modulate flash
	var panel: Panel = zone.get("panel") as Panel
	if is_instance_valid(panel) and not SettingsManager.reduced_motion:
		var flash_tw: Tween = create_tween()
		flash_tw.tween_property(panel, "modulate", Color(1.5, 1.5, 1.0, 1.0), 0.1)
		flash_tw.tween_property(panel, "modulate", Color.WHITE, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if SettingsManager.reduced_motion:
		item.global_position = center + offset
		item.scale = Vector2(0.75, 0.75)
		item.rotation = 0.0
		if _sorted_count >= _total_items:
			_on_round_complete()
		else:
			_reset_idle_timer()
		return
	var tw: Tween = create_tween()
	tw.tween_property(item, "global_position", center + offset, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "scale", Vector2(0.75, 0.75), 0.25)
	tw.parallel().tween_property(item, "rotation", 0.0, 0.15)
	## VFX sparkle на місці приземлення (LAW 28)
	VFXManager.spawn_correct_sparkle(center + offset)
	if _sorted_count >= _total_items:
		tw.chain().tween_callback(_on_round_complete)
	else:
		_reset_idle_timer()


func _handle_wrong(item: Node2D) -> void:
	if _is_toddler:
		_register_error(item)  ## A11: scaffolding для тоддлера
	else:
		_errors += 1
		_register_error(item)
	var origin: Vector2 = _item_origins.get(item, item.position)
	if SettingsManager.reduced_motion:
		item.position = origin
		item.rotation = 0.0
		return
	var tw: Tween = create_tween()
	tw.tween_property(item, "position", origin, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "rotation", 0.0, 0.15)


func _snap_back(item: Node2D) -> void:
	if not _item_origins.has(item):
		push_warning("Sorting: _item_origins не містить item")
		return
	if SettingsManager.reduced_motion:
		item.position = _item_origins[item]
		item.rotation = 0.0
		return
	var tw: Tween = create_tween()
	tw.tween_property(item, "position", _item_origins[item], 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "rotation", 0.0, 0.15)


## ---- Round management ----

func _on_round_complete() -> void:
	_input_locked = true
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	## Group celebration — all zones flash
	if not SettingsManager.reduced_motion:
		for zone: Dictionary in _zones:
			var zp: Panel = zone.get("panel") as Panel
			if is_instance_valid(zp):
				var z_tw: Tween = create_tween()
				z_tw.tween_property(zp, "modulate", Color(1.5, 1.5, 1.0, 1.0), 0.15)
				z_tw.tween_property(zp, "modulate", Color.WHITE, 0.5)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var round_d: float = 0.15 if SettingsManager.reduced_motion else 0.8
	var tw: Tween = create_tween()
	tw.tween_interval(round_d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


func _clear_round() -> void:
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_items.clear()
	_item_data.clear()
	_item_origins.clear()
	_zones.clear()


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": TOTAL_ROUNDS, "earned_stars": earned})


## ---- IconDraw хелпер ----

static func _habitat_icon(id: String, size: float) -> Control:
	match id:
		"pine_tree": return IconDraw.pine_tree(size)
		"home_house": return IconDraw.home_house(size)
		"palm_tree": return IconDraw.palm_tree(size)
		_:
			push_warning("Sorting: невідомий habitat icon id: " + id)
			return IconDraw.pine_tree(size)


## ---- A11: scaffolding підказка — підсвітити правильну зону після серії помилок ----

func _show_scaffold_hint() -> void:
	super()
	## Знайти перший валідний елемент та його правильну зону
	var target_item: Node2D = null
	for item: Node2D in _items:
		if is_instance_valid(item):
			target_item = item
			break
	if not target_item:
		push_warning("Sorting: scaffolding — немає валідних елементів для підказки")
		return
	var cat_id: String = _item_data.get(target_item, "")
	if cat_id.is_empty():
		push_warning("Sorting: scaffolding — не знайдено категорію для елемента")
		return
	for zone: Dictionary in _zones:
		if zone.category_id == cat_id:
			var panel: Panel = zone.panel
			if is_instance_valid(panel):
				_pulse_node(panel, 1.12)
				## Додаткова кольорова підказка — тимчасове підсвічування (1.5 сек)
				var orig_mod: Color = panel.modulate
				panel.modulate = Color(1.4, 1.4, 1.0, 1.0)
				var hint_tw: Tween = create_tween()
				hint_tw.tween_property(panel, "modulate", orig_mod, 1.5)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			break


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
	if _input_locked or _game_over or _items.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	for item: Node2D in _items:
		if is_instance_valid(item):
			_pulse_node(item, 1.15)
			break
	_reset_idle_timer()
