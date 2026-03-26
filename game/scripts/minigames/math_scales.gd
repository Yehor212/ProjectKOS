extends BaseMiniGame

## PRE-22 "Поділись порівну!" — допоможи тваринам поділити їжу!
## Тварини сидять з тарілками. Дитина розділяє яблука порівну.
## Research: sharing mechanic (Toca Boca), character reactions = reward, cause-effect immediate.

const TOTAL_ROUNDS: int = 5
const IDLE_HINT_DELAY: float = 5.0
const APPLE_SIZE: float = 60.0
const PLATE_RADIUS: float = 65.0
const ANIMAL_DISPLAY_SCALE: Vector2 = Vector2(0.22, 0.22)
const SAFETY_TIMEOUT_SEC: float = 120.0

## Масив тварин для кожного раунду (не повторюються)
const ANIMAL_POOL: Array[String] = [
	"Bunny", "Cat", "Dog", "Bear", "Penguin", "Panda", "Frog",
	"Mouse", "Monkey", "Lion", "Elephant", "Hedgehog", "Squirrel",
]

var _is_toddler: bool = false
var _drag: UniversalDrag = null
var _round: int = 0
var _start_time: float = 0.0

var _apple_items: Array[Node2D] = []
var _plate_nodes: Array[Node2D] = []
var _animal_nodes: Array[Node2D] = []
var _all_round_nodes: Array[Node] = []
var _apple_plate: Dictionary = {}  ## apple_node → plate_index (-1 = pile)
var _plate_counts: Array[int] = []  ## count per plate
var _item_origins: Dictionary = {}
var _animal_count: int = 2
var _apple_count: int = 4
var _used_animals: Array[int] = []

var _idle_timer: SceneTreeTimer = null


func _ready() -> void:
	game_id = "math_scales"
	bg_theme = "city"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
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
	return tr("SCALES_SHARE_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	if _apple_items.is_empty() or _plate_nodes.is_empty():
		return {}
	return {"type": "drag", "from": _apple_items[0].global_position, "to": _plate_nodes[0].global_position}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_apple_plate.clear()
	_plate_counts.clear()
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	## Прогресивна складність (A4)
	if _is_toddler:
		_animal_count = 2
		_apple_count = _scale_by_round_i(2, 6, _round, TOTAL_ROUNDS)
		## Toddler: завжди ділиться порівну
		_apple_count = _apple_count - (_apple_count % _animal_count)
		if _apple_count < 2:
			_apple_count = 2
	else:
		_animal_count = _scale_by_round_i(2, 3, _round, TOTAL_ROUNDS)
		_apple_count = _scale_by_round_i(4, 9, _round, TOTAL_ROUNDS)
	for i: int in _animal_count:
		_plate_counts.append(0)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_animals(vp)
	_spawn_plates(vp)
	_spawn_apples(vp)
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.3
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_drag.enabled = true
		_reset_idle_timer())


func _pick_animals(count: int) -> Array[String]:
	var result: Array[String] = []
	for i: int in count:
		if _used_animals.size() >= ANIMAL_POOL.size():
			_used_animals.clear()
		var idx: int = randi() % ANIMAL_POOL.size()
		while _used_animals.has(idx):
			idx = randi() % ANIMAL_POOL.size()
		_used_animals.append(idx)
		result.append(ANIMAL_POOL[idx])
	return result


func _spawn_animals(vp: Vector2) -> void:
	var names: Array[String] = _pick_animals(_animal_count)
	var spacing: float = vp.x / float(_animal_count + 1)
	var animal_y: float = vp.y * 0.28
	for i: int in _animal_count:
		var tex_path: String = "res://assets/sprites/animals/%s.png" % names[i]
		var animal: Node2D = Node2D.new()
		animal.position = Vector2(spacing * float(i + 1), animal_y)
		add_child(animal)
		if ResourceLoader.exists(tex_path):
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = load(tex_path)
			sprite.scale = ANIMAL_DISPLAY_SCALE
			animal.add_child(sprite)
		## Обличчя-емоція (починає нейтральне)
		var face_label: Label = Label.new()
		face_label.text = "😐"
		face_label.add_theme_font_size_override("font_size", 28)
		face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face_label.position = Vector2(-15, -70)
		face_label.size = Vector2(30, 30)
		animal.add_child(face_label)
		animal.set_meta("face_label", face_label)
		animal.set_meta("animal_name", names[i])
		_animal_nodes.append(animal)
		_all_round_nodes.append(animal)


func _spawn_plates(vp: Vector2) -> void:
	var spacing: float = vp.x / float(_animal_count + 1)
	var plate_y: float = vp.y * 0.48
	for i: int in _animal_count:
		var plate: Node2D = Node2D.new()
		plate.position = Vector2(spacing * float(i + 1), plate_y)
		add_child(plate)
		## Кругла тарілка
		var panel: Panel = Panel.new()
		panel.size = Vector2(PLATE_RADIUS * 2, PLATE_RADIUS * 2)
		panel.position = Vector2(-PLATE_RADIUS, -PLATE_RADIUS)
		var style: StyleBoxFlat = GameData.candy_circle(Color(1.0, 0.98, 0.92, 0.9), PLATE_RADIUS)
		style.border_color = Color("ffd166")
		style.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", style)
		panel.material = GameData.create_premium_material(0.04, 2.0, 0.04, 0.0, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
		plate.add_child(panel)
		## Лічильник яблук на тарілці
		var count_lbl: Label = Label.new()
		count_lbl.text = "0"
		count_lbl.add_theme_font_size_override("font_size", 24)
		count_lbl.add_theme_color_override("font_color", Color("5c6bc0"))
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.position = Vector2(-20, PLATE_RADIUS + 4)
		count_lbl.size = Vector2(40, 30)
		plate.add_child(count_lbl)
		plate.set_meta("count_label", count_lbl)
		plate.set_meta("plate_index", i)
		_plate_nodes.append(plate)
		_drag.drop_targets.append(plate)
		_all_round_nodes.append(plate)


func _spawn_apples(vp: Vector2) -> void:
	var count: int = _apple_count
	var cols: int = mini(count, 5)
	var rows: int = ceili(float(count) / float(cols))
	var gap: float = APPLE_SIZE + 8.0
	var start_x: float = vp.x * 0.5 - (float(cols) - 1.0) * gap * 0.5
	var start_y: float = vp.y * 0.72
	for i: int in count:
		var col: int = i % cols
		var row: int = i / cols
		var apple: Node2D = Node2D.new()
		add_child(apple)
		## Червоне яблуко (кружок)
		var bg: Panel = Panel.new()
		bg.size = Vector2(APPLE_SIZE, APPLE_SIZE)
		bg.position = Vector2(-APPLE_SIZE * 0.5, -APPLE_SIZE * 0.5)
		var style: StyleBoxFlat = GameData.candy_circle(Color("e74c3c"), APPLE_SIZE * 0.5)
		bg.add_theme_stylebox_override("panel", style)
		bg.material = GameData.create_premium_material(0.06, 2.0, 0.06, 0.08, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		GameData.add_gloss(bg, 8)
		apple.add_child(bg)
		## Листочок зверху
		var leaf: Label = Label.new()
		leaf.text = "🍎"
		leaf.add_theme_font_size_override("font_size", 20)
		leaf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		leaf.position = Vector2(-12, -12)
		leaf.size = Vector2(24, 24)
		apple.add_child(leaf)
		var target_pos: Vector2 = Vector2(start_x + float(col) * gap, start_y + float(row) * gap)
		apple.position = target_pos
		_apple_plate[apple] = -1  ## -1 = в купці
		_item_origins[apple] = target_pos
		_apple_items.append(apple)
		_drag.draggable_items.append(apple)
		_all_round_nodes.append(apple)
	_staggered_spawn(_apple_items, 0.06)


## ---- Обличчя тварин (реальний час) ----

func _update_faces() -> void:
	if _animal_count <= 0:
		return
	@warning_ignore("integer_division")
	var fair_share: int = _apple_count / _animal_count
	var placed_total: int = 0
	for c: int in _plate_counts:
		placed_total += c
	for i: int in _animal_count:
		if i >= _animal_nodes.size():
			continue
		var animal: Node2D = _animal_nodes[i]
		if not is_instance_valid(animal):
			continue
		var face: Label = animal.get_meta("face_label", null) as Label
		if not face:
			continue
		var count: int = _plate_counts[i] if i < _plate_counts.size() else 0
		## Emoji faces: реакція в реальному часі
		if placed_total == _apple_count:
			## Всі яблука розкладені
			if count == fair_share:
				face.text = "😊"  ## Щаслива — отримала порівну
			elif count > fair_share:
				face.text = "😅"  ## Збентежена — отримала забагато
			else:
				face.text = "😢"  ## Сумна — отримала замало
		elif count > 0:
			face.text = "😊"  ## Отримала хоча б щось
		else:
			face.text = "😐"  ## Чекає


## ---- Input ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_input(event)


func _process(delta: float) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_process(delta)


func _on_picked(_item: Node2D) -> void:
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()


## ---- Drop ----

func _on_dropped_target(item: Node2D, target: Node2D) -> void:
	if _game_over or _input_locked:
		return
	var plate_idx: int = target.get_meta("plate_index", -1)
	if plate_idx < 0 or plate_idx >= _plate_counts.size():
		push_warning("Scales: invalid plate index %d" % plate_idx)
		_drag.snap_back(item, _item_origins.get(item, item.position))
		return
	_apple_plate[item] = plate_idx
	_plate_counts[plate_idx] += 1
	## Оновити лічильник на тарілці
	var count_lbl: Label = target.get_meta("count_label", null) as Label
	if count_lbl:
		count_lbl.text = str(_plate_counts[plate_idx])
	_drag.draggable_items.erase(item)
	AudioManager.play_sfx("coin")
	HapticsManager.vibrate_light()
	## Анімація snap до тарілки
	if SettingsManager.reduced_motion:
		item.global_position = target.global_position + Vector2(randf_range(-20, 20), randf_range(-15, 15))
		item.modulate.a = 0.7
		_update_faces()
		_check_completion()
		return
	var tw: Tween = create_tween()
	var offset: Vector2 = Vector2(randf_range(-20, 20), randf_range(-15, 15))
	tw.tween_property(item, "global_position", target.global_position + offset, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "modulate:a", 0.7, 0.15)
	tw.chain().tween_callback(func() -> void:
		_update_faces()
		_check_completion())


func _on_dropped_empty(item: Node2D) -> void:
	## Якщо яблуко було на тарілці — повернути
	var old_plate: int = _apple_plate.get(item, -1)
	if old_plate >= 0 and old_plate < _plate_counts.size():
		_plate_counts[old_plate] -= 1
		if _plate_counts[old_plate] < 0:
			_plate_counts[old_plate] = 0
		## Оновити лічильник
		if old_plate < _plate_nodes.size():
			var count_lbl: Label = _plate_nodes[old_plate].get_meta("count_label", null) as Label
			if count_lbl:
				count_lbl.text = str(_plate_counts[old_plate])
	_apple_plate[item] = -1
	_drag.snap_back(item, _item_origins.get(item, item.position))
	_update_faces()


## ---- Перевірка завершення ----

func _check_completion() -> void:
	## Перевірити чи ВСІ яблука розкладені
	var all_placed: bool = true
	for apple: Node2D in _apple_items:
		if _apple_plate.get(apple, -1) < 0:
			all_placed = false
			break
	if not all_placed:
		_reset_idle_timer()
		return
	## Всі яблука розкладені — перевірити чи порівну
	if _animal_count <= 0:
		push_warning("Scales: _animal_count = 0")
		return
	@warning_ignore("integer_division")
	var fair_share: int = _apple_count / _animal_count
	var remainder: int = _apple_count % _animal_count
	var is_fair: bool = true
	for i: int in _animal_count:
		var count: int = _plate_counts[i] if i < _plate_counts.size() else 0
		## Допускаємо ±1 якщо є залишок
		if remainder > 0:
			if count < fair_share or count > fair_share + 1:
				is_fair = false
				break
		else:
			if count != fair_share:
				is_fair = false
				break
	if is_fair:
		_on_shared_equally()
	else:
		_on_unfair_share()


func _on_shared_equally() -> void:
	_register_correct()
	_input_locked = true
	_drag.enabled = false
	## Всі тварини ЩАСЛИВІ — танцюють!
	for animal: Node2D in _animal_nodes:
		if is_instance_valid(animal):
			var face: Label = animal.get_meta("face_label", null) as Label
			if face:
				face.text = "🥳"
			if not SettingsManager.reduced_motion:
				var dance: Tween = create_tween().set_loops(3)
				dance.tween_property(animal, "rotation", 0.1, 0.1)
				dance.tween_property(animal, "rotation", -0.1, 0.1)
				dance.tween_property(animal, "rotation", 0.0, 0.1)
			VFXManager.spawn_match_sparkle(animal.global_position)
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	var d2: float = 0.15 if SettingsManager.reduced_motion else 1.0
	var tw: Tween = create_tween()
	tw.tween_interval(d2)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


func _on_unfair_share() -> void:
	if _is_toddler:
		## Toddler: м'яке повернення — тварини трохи сумні, яблука повертаються
		_register_error()
		## Повернути ВСІ яблука в купку
		for apple: Node2D in _apple_items:
			if not is_instance_valid(apple):
				continue
			var old_plate: int = _apple_plate.get(apple, -1)
			if old_plate >= 0:
				apple.modulate.a = 1.0
				if not _drag.draggable_items.has(apple):
					_drag.draggable_items.append(apple)
			_apple_plate[apple] = -1
			_drag.snap_back(apple, _item_origins.get(apple, apple.position))
		for i: int in _plate_counts.size():
			_plate_counts[i] = 0
		for plate: Node2D in _plate_nodes:
			if is_instance_valid(plate):
				var count_lbl: Label = plate.get_meta("count_label", null) as Label
				if count_lbl:
					count_lbl.text = "0"
		_update_faces()
		var d3: float = 0.15 if SettingsManager.reduced_motion else 0.5
		var tw: Tween = create_tween()
		tw.tween_interval(d3)
		tw.tween_callback(func() -> void:
			_input_locked = false
			_drag.enabled = true
			_reset_idle_timer())
	else:
		## Preschool: помилка + рестарт раунду
		_errors += 1
		_register_error()
		var d4: float = 0.15 if SettingsManager.reduced_motion else 0.6
		var tw: Tween = create_tween()
		tw.tween_interval(d4)
		tw.tween_callback(func() -> void:
			if _game_over:
				return
			_clear_round()
			_start_round())


func _clear_round() -> void:
	_apple_plate.clear()
	_item_origins.clear()
	_apple_items.clear()
	_plate_nodes.clear()
	_animal_nodes.clear()
	_plate_counts.clear()
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	_drag.clear_drag()


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": TOTAL_ROUNDS, "earned_stars": earned})


## ---- A11: scaffolding — підсвітити тарілку з найменшою кількістю ----

func _show_scaffold_hint() -> void:
	super()
	if _plate_counts.is_empty():
		push_warning("Scales: scaffolding — немає тарілок")
		return
	var min_idx: int = 0
	var min_val: int = _plate_counts[0]
	for i: int in range(1, _plate_counts.size()):
		if _plate_counts[i] < min_val:
			min_val = _plate_counts[i]
			min_idx = i
	if min_idx < _plate_nodes.size() and is_instance_valid(_plate_nodes[min_idx]):
		_pulse_node(_plate_nodes[min_idx], 1.2)


func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over or _apple_items.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	for item: Node2D in _apple_items:
		if is_instance_valid(item) and _apple_plate.get(item, -1) < 0:
			_pulse_node(item, 1.15)
			break
	_reset_idle_timer()
