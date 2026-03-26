extends BaseMiniGame

## PRE-28 Еко-конвеєр — сортуй сміття в контейнери для переробки!
## 3 раунди x 6 предметів. Папір, пластик, скло, органіка.
## Предмети падають зверху, дитина перетягує їх у правильний контейнер.

const TOTAL_ROUNDS: int = 3
const ITEMS_PER_ROUND: int = 6
const FALL_SPEED: float = 30.0
const ITEM_SIZE: float = 90.0
const BIN_W: float = 150.0
const BIN_H: float = 130.0
const BIN_CORNER: int = 20
const PICK_RADIUS: float = 80.0
const TILT_FACTOR: float = 0.001
const TILT_MAX: float = 0.4
const TILT_LERP: float = 15.0
const SPAWN_INTERVAL: float = 1.8
const IDLE_HINT_DELAY: float = 5.0
const MAX_ACTIVE_ITEMS: int = 8
const SAFETY_TIMEOUT_SEC: float = 90.0

const TRASH_TYPES: Array[Dictionary] = [
	{"id": "paper", "icon": "paper", "label": "ECO_PAPER", "color": Color("90caf9")},
	{"id": "plastic", "icon": "plastic", "label": "ECO_PLASTIC", "color": Color("ce93d8")},
	{"id": "glass", "icon": "glass", "label": "ECO_GLASS", "color": Color("a5d6a7")},
	{"id": "organic", "icon": "organic", "label": "ECO_ORGANIC", "color": Color("ffcc80")},
]

var _is_toddler: bool = false
var _round: int = 0
var _sorted_count: int = 0
var _current_items_count: int = 0
var _start_time: float = 0.0

var _dragged: Node2D = null
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_original_z: int = 0
var _last_mouse: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO

var _items: Array[Node2D] = []
var _all_round_nodes: Array[Node] = []
var _item_type_id: Dictionary = {}
var _bins: Array[Dictionary] = []
var _spawn_queue: Array[Dictionary] = []
var _spawn_timer: float = 0.0
var _spawning: bool = false

var _current_fall_speed: float = FALL_SPEED  ## A4: швидкість падіння зростає з раундом (30→45 px/s)
var _idle_timer: SceneTreeTimer = null
var _narrative_label: Label = null
var _earth_mood: float = 0.0  ## Від 0.0 до 1.0 — настрій планети


func _ready() -> void:
	game_id = "eco_conveyor"
	bg_theme = "meadow"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_build_narrative_label(tr("SAVE_PLANET"))
	_build_bins()
	_start_round()
	## A2: гра ЗАВЖДИ завершується — safety timeout
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


## Наратив — "Врятуй планету!" лейбл з динамічним emoji настрою
func _build_narrative_label(text: String) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_narrative_label = Label.new()
	_narrative_label.text = text
	_narrative_label.add_theme_font_size_override("font_size", 28)
	_narrative_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_narrative_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narrative_label.position = Vector2(0, vp.y * 0.12)
	_narrative_label.size = Vector2(vp.x, 40)
	_ui_layer.add_child(_narrative_label)


## Оновлення настрою Землі — emoji прогресує з кожним правильним сортуванням
func _update_earth_mood() -> void:
	if not is_instance_valid(_narrative_label):
		push_warning("EcoConveyor: _narrative_label freed during mood update")
		return
	var emoji: String = ""
	if _earth_mood < 0.25:
		emoji = ":|"
	elif _earth_mood < 0.5:
		emoji = ":)"
	elif _earth_mood < 0.75:
		emoji = "* *"
	else:
		emoji = "***"
	_narrative_label.text = tr("SAVE_PLANET") + "  " + emoji


func get_tutorial_instruction() -> String:
	return tr("ECO_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	if _items.is_empty() or _bins.is_empty():
		return {}
	var item: Node2D = _items[0]
	var type_id: String = _item_type_id.get(item, "")
	for bin: Dictionary in _bins:
		if bin.type_id == type_id:
			return {"type": "drag", "from": item.global_position, "to": bin.rect.get_center()}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


func _build_bins() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = TRASH_TYPES.size()
	var spacing: float = vp.x / float(count + 1)
	var bin_y: float = vp.y * 0.82
	for i: int in count:
		var t: Dictionary = TRASH_TYPES[i]
		var x: float = spacing * float(i + 1) - BIN_W * 0.5
		var rect: Rect2 = Rect2(x, bin_y - BIN_H * 0.5, BIN_W, BIN_H)
		## Фон контейнера
		var panel: Panel = Panel.new()
		panel.position = Vector2(x, bin_y - BIN_H * 0.5)
		panel.size = Vector2(BIN_W, BIN_H)
		var style: StyleBoxFlat = GameData.candy_panel(Color(t.color, 0.80), BIN_CORNER)
		style.border_color = Color(t.color, 0.90)
		style.set_border_width_all(3)
		style.border_width_bottom = 5
		panel.add_theme_stylebox_override("panel", style)
		## Premium overlay + текстура плитки (LAW 28)
		var bin_tile_colors: Array[String] = ["blue", "pink", "green", "orange"]
		var bin_tile_path: String = "res://assets/textures/tiles/%s/tile_03.png" % bin_tile_colors[i % 4]
		panel.material = GameData.create_premium_material(
			0.05, 2.0, 0.04, 0.08, 0.06, 0.05, 0.08, bin_tile_path, 0.18, 0.12, 0.28, 0.22)
		add_child(panel)
		## Глянцевий блік контейнера
		var bin_gloss: Panel = Panel.new()
		bin_gloss.position = Vector2(4.0, 4.0)
		bin_gloss.size = Vector2(BIN_W - 8.0, BIN_H * 0.32)
		var gloss_s: StyleBoxFlat = StyleBoxFlat.new()
		gloss_s.bg_color = Color(1, 1, 1, 0.18)
		gloss_s.corner_radius_top_left = BIN_CORNER
		gloss_s.corner_radius_top_right = BIN_CORNER
		@warning_ignore("integer_division")
		gloss_s.corner_radius_bottom_left = BIN_CORNER / 2
		@warning_ignore("integer_division")
		gloss_s.corner_radius_bottom_right = BIN_CORNER / 2
		bin_gloss.add_theme_stylebox_override("panel", gloss_s)
		bin_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(bin_gloss)
		## Іконка контейнера — збільшена
		var bin_icon: Control = IconDraw.trash_icon(t.icon, 44.0)
		bin_icon.position = Vector2(x + (BIN_W - 44.0) * 0.5, bin_y - BIN_H * 0.5 + 10)
		bin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bin_icon)
		## Підпис контейнера — чіткіший
		var name_lbl: Label = Label.new()
		name_lbl.text = tr(t.label)
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		name_lbl.position = Vector2(x, bin_y + BIN_H * 0.5 - 36)
		name_lbl.size = Vector2(BIN_W, 36)
		add_child(name_lbl)
		_bins.append({"rect": rect, "type_id": t.id, "panel": panel})
	## Premium стагерована поява контейнерів
	var bin_panels: Array[CanvasItem] = []
	for b: Dictionary in _bins:
		if b.has("panel") and is_instance_valid(b.panel):
			bin_panels.append(b.panel as CanvasItem)
	_staggered_spawn(bin_panels, 0.12)


## ---- Раунди ----

func _start_round() -> void:
	_sorted_count = 0
	_input_locked = true
	_spawning = true
	_spawn_timer = 0.0
	## A4: швидкість падіння зростає від 30 до 45 px/s за 3 раунди
	_current_fall_speed = _scale_by_round(FALL_SPEED, 45.0, _round, TOTAL_ROUNDS)
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	## Генеруємо чергу предметів — рівний розподіл категорій
	_spawn_queue.clear()
	## Прогресивна складність: менше предметів в ранніх раундах
	_current_items_count = _scale_by_round_i(4, ITEMS_PER_ROUND, _round, TOTAL_ROUNDS)
	var items_count: int = _current_items_count
	var queue: Array[Dictionary] = []
	for j: int in items_count:
		queue.append(TRASH_TYPES[j % TRASH_TYPES.size()])
	queue.shuffle()
	_spawn_queue = queue
	## Спавнимо перший предмет одразу
	_spawn_next_item()
	var start_d: float = 0.15 if SettingsManager.reduced_motion else 0.4
	var tw: Tween = create_tween()
	tw.tween_interval(start_d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _spawn_next_item() -> void:
	if _spawn_queue.is_empty():
		_spawning = false
		return
	if _items.size() >= MAX_ACTIVE_ITEMS:
		return
	var t: Dictionary = _spawn_queue.pop_front()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var x: float = randf_range(80.0, vp.x - 80.0)
	var item: Node2D = _create_trash_item(t)
	item.position = Vector2(x, -ITEM_SIZE)
	_item_type_id[item] = t.id
	_items.append(item)
	_all_round_nodes.append(item)
	## Плавна поява предмета
	if not (SettingsManager and SettingsManager.reduced_motion):
		item.scale = Vector2.ZERO
		item.modulate.a = 0.0
		var etw: Tween = create_tween().set_parallel(true)
		etw.tween_property(item, "scale", Vector2.ONE, 0.2)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		etw.tween_property(item, "modulate:a", 1.0, 0.15)


func _create_trash_item(t: Dictionary) -> Node2D:
	var node: Node2D = Node2D.new()
	add_child(node)
	## Кругле тло
	var bg: Panel = Panel.new()
	bg.size = Vector2(ITEM_SIZE, ITEM_SIZE)
	bg.position = Vector2(-ITEM_SIZE * 0.5, -ITEM_SIZE * 0.5)
	var style: StyleBoxFlat = GameData.candy_circle(t.color, ITEM_SIZE * 0.5)
	style.border_color = Color(1, 1, 1, 0.55)
	style.set_border_width_all(3)
	style.border_width_bottom = 5
	bg.add_theme_stylebox_override("panel", style)
	## Premium overlay (LAW 28)
	bg.material = GameData.create_premium_material(
		0.05, 2.0, 0.04, 0.08, 0.06, 0.05, 0.08, "", 0.0, 0.12, 0.25, 0.20)
	node.add_child(bg)
	## HQ текстура фішки (kenney boardgame chip) для глибини
	var chip_map: Dictionary = {
		"paper": "chipBlueWhite", "plastic": "chipRedWhite",
		"glass": "chipGreenWhite", "organic": "chipWhite",
	}
	var chip_name: String = chip_map.get(t.id, "chipWhite")
	var chip_path: String = "res://assets/textures/kenney/boardgame/%s.png" % chip_name
	if ResourceLoader.exists(chip_path):
		var chip_tex: Texture2D = load(chip_path)
		var chip_sz: float = ITEM_SIZE * 0.9
		var chip_ctrl: Control = Control.new()
		chip_ctrl.size = Vector2(chip_sz, chip_sz)
		chip_ctrl.position = Vector2(-ITEM_SIZE * 0.45, -ITEM_SIZE * 0.45)
		chip_ctrl.modulate = Color(1, 1, 1, 0.5)
		chip_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip_ctrl.draw.connect(func() -> void:
			chip_ctrl.draw_texture_rect(chip_tex, Rect2(Vector2.ZERO, Vector2(chip_sz, chip_sz)), false)
		)
		node.add_child(chip_ctrl)
	## Глянцевий блік на кулі
	var gloss: Panel = Panel.new()
	var gl_w: float = ITEM_SIZE * 0.7
	var gl_h: float = ITEM_SIZE * 0.35
	gloss.size = Vector2(gl_w, gl_h)
	gloss.position = Vector2(-gl_w * 0.5, -ITEM_SIZE * 0.45)
	var gl_s: StyleBoxFlat = StyleBoxFlat.new()
	gl_s.bg_color = Color(1, 1, 1, 0.28)
	gl_s.set_corner_radius_all(int(gl_h * 0.5))
	gloss.add_theme_stylebox_override("panel", gl_s)
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(gloss)
	## Іконка — збільшена для читабельності
	var icon_sz: float = ITEM_SIZE * 0.5
	var icon: Control = IconDraw.trash_icon(t.icon, icon_sz)
	icon.position = Vector2(-icon_sz * 0.5, -icon_sz * 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(icon)
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
	## Падіння предметів зверху
	if not _game_over:
		var vp_h: float = get_viewport().get_visible_rect().size.y
		for item: Node2D in _items:
			if not is_instance_valid(item) or item == _dragged:
				continue
			item.position.y += _current_fall_speed * delta
			## Предмет долетів до низу
			if item.position.y > vp_h + ITEM_SIZE:
				if _is_toddler:
					## A6: toddler — м'яко повертаємо нагору, без покарання
					item.position.y = -ITEM_SIZE
					item.position.x = randf_range(80.0, get_viewport().get_visible_rect().size.x - 80.0)
				else:
					## A7: preschool — пропущений предмет = помилка, гра прогресує
					_errors += 1
					_register_error(item)
					_item_type_id.erase(item)
					_items.erase(item)
					_sorted_count += 1
					item.queue_free()
					AudioManager.play_sfx("error")
					HapticsManager.vibrate_light()
					if _sorted_count >= _current_items_count:
						_on_round_complete()
					break
	## Спавн нових предметів з інтервалом
	if _spawning and not _spawn_queue.is_empty():
		_spawn_timer += delta
		if _spawn_timer >= SPAWN_INTERVAL:
			_spawn_timer = 0.0
			_spawn_next_item()
	## Drag processing
	if not _dragged:
		return
	var mouse: Vector2 = get_global_mouse_position()
	_drag_velocity = (mouse - _last_mouse) / maxf(delta, 0.001)
	_last_mouse = mouse
	_dragged.global_position = mouse + _drag_offset
	var rot: float = clampf(_drag_velocity.x * TILT_FACTOR, -TILT_MAX, TILT_MAX)
	_dragged.rotation = lerpf(_dragged.rotation, rot, TILT_LERP * delta)
	## Підсвітка контейнерів
	for bin: Dictionary in _bins:
		var p: Panel = bin.panel
		if bin.rect.has_point(_dragged.global_position):
			p.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			p.modulate = Color.WHITE


func _try_pick() -> void:
	var mouse: Vector2 = get_global_mouse_position()
	var best: Node2D = null
	var best_dist: float = PICK_RADIUS
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
	## Скинути підсвітку
	for bin: Dictionary in _bins:
		bin.panel.modulate = Color.WHITE
	## Перевірити контейнери
	for bin: Dictionary in _bins:
		if bin.rect.has_point(drop_pos):
			if _item_type_id.get(item, "") == bin.type_id:
				_handle_correct(item, bin)
			else:
				_handle_wrong(item)
			return
	## Не потрапив — snap back на конвеєр
	_snap_back_to_conveyor(item)


## ---- Feedback ----

func _handle_correct(item: Node2D, bin: Dictionary) -> void:
	_register_correct(item)
	_item_type_id.erase(item)
	_items.erase(item)
	_sorted_count += 1
	## Earth mood зростає з кожним правильним сортуванням
	_earth_mood = clampf(_earth_mood + 0.1, 0.0, 1.0)
	_update_earth_mood()
	## VFX sparkle на вдалому сортуванні (LAW 28)
	VFXManager.spawn_correct_sparkle(item.global_position)
	## Контейнер підстрибує (bounce)
	if not SettingsManager.reduced_motion:
		var panel: Panel = bin.panel
		var orig_y: float = panel.position.y
		var tw_b: Tween = create_tween()
		tw_b.tween_property(panel, "position:y", orig_y - 15.0, 0.1)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_b.tween_property(panel, "position:y", orig_y, 0.15)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	## Предмет летить у контейнер і зникає
	var center: Vector2 = Vector2(bin.rect.get_center().x, bin.rect.get_center().y)
	if SettingsManager.reduced_motion:
		item.global_position = center
		item.modulate.a = 0.0
		item.queue_free()
		if _sorted_count >= _current_items_count:
			_on_round_complete()
		else:
			_reset_idle_timer()
	else:
		var tw: Tween = create_tween()
		tw.tween_property(item, "global_position", center, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(item, "scale", Vector2(0.3, 0.3), 0.2)
		tw.parallel().tween_property(item, "modulate:a", 0.0, 0.15).set_delay(0.1)
		tw.parallel().tween_property(item, "rotation", 0.0, 0.1)
		tw.tween_callback(item.queue_free)
		if _sorted_count >= _current_items_count:
			tw.chain().tween_callback(_on_round_complete)
		else:
			_reset_idle_timer()


func _handle_wrong(item: Node2D) -> void:
	if _is_toddler:
		_register_error(item)  ## A11: scaffolding для тоддлера
	else:
		_errors += 1
		_register_error(item)
	_snap_back_to_conveyor(item)


func _snap_back_to_conveyor(item: Node2D) -> void:
	## Повертаємо предмет нагору на конвеєр
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var target_pos: Vector2 = Vector2(item.position.x, vp.y * 0.3)
	if SettingsManager.reduced_motion:
		item.position = target_pos
		item.rotation = 0.0
		return
	var tw: Tween = create_tween()
	tw.tween_property(item, "position", target_pos, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "rotation", 0.0, 0.15)


## ---- Round management ----

func _on_round_complete() -> void:
	_input_locked = true
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	## Показати фінальний настрій Землі для раунду
	_update_earth_mood()
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
			_item_type_id.erase(node)
			node.queue_free()
	_all_round_nodes.clear()
	_items.clear()
	_item_type_id.clear()
	_spawn_queue.clear()


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": TOTAL_ROUNDS, "earned_stars": earned})


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
