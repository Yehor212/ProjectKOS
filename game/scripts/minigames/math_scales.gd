extends BaseMiniGame

## PRE-22 "Tofie's Friends Share" — допоможи тваринам поділити їжу порівну!
## Тварини-друзі сидять з тарілками. Дитина перетягує їжу порівно.
## Очі тварин СТЕЖАТЬ за їжею (eye-tracking tween).
## Нерівний розподіл: сумні/збентежені обличчя. Рівний: всі їдять разом.
## Research: sharing mechanic (Toca Boca), character reactions = reward,
## cause-effect immediate, divisibility guard for solvability.

const TOTAL_ROUNDS: int = 5
const IDLE_HINT_DELAY: float = 5.0
const FOOD_SIZE: float = 56.0
const PLATE_RADIUS: float = 65.0
const ANIMAL_DISPLAY_SCALE: Vector2 = Vector2(0.22, 0.22)
const SAFETY_TIMEOUT_SEC: float = 120.0
const EYE_OFFSET_MAX: float = 6.0  ## Макс зміщення зіниці при eye-tracking

## Явні раунди для Toddler — гарантована подільність (A2, LAW 13)
## [animal_count, food_count]
const TODDLER_ROUNDS: Array[Vector2i] = [
	Vector2i(2, 4),  ## R1: 4/2 = 2 кожному (очевидно)
	Vector2i(2, 4),  ## R2: 4/2 = 2 кожному (повтор для впевненості)
	Vector2i(2, 6),  ## R3: 6/2 = 3 кожному
	Vector2i(2, 6),  ## R4: 6/2 = 3 кожному
	Vector2i(2, 8),  ## R5: 8/2 = 4 кожному
]

## Явні раунди для Preschool — зростаюча складність (A4, LAW 6)
const PRESCHOOL_ROUNDS: Array[Vector2i] = [
	Vector2i(2, 4),  ## R1: 4/2 = 2 кожному (легко)
	Vector2i(2, 6),  ## R2: 6/2 = 3 кожному
	Vector2i(3, 6),  ## R3: 6/3 = 2 кожному (3 тварини!)
	Vector2i(4, 8),  ## R4: 8/4 = 2 кожному (4 тварини!)
	Vector2i(3, 9),  ## R5: 9/3 = 3 кожному (найскладніший)
]

## Пул тварин з відповідною їжею — кожна тварина має свій тип їжі
const FOOD_TYPES: Array[String] = [
	"Apple", "Banana", "Carrot", "Watermelon", "Cheese",
]

## Пул тварин для вибору (не повторюються протягом гри)
const ANIMAL_POOL: Array[String] = [
	"Bunny", "Cat", "Dog", "Bear", "Penguin", "Panda", "Frog",
	"Mouse", "Monkey", "Lion", "Elephant", "Hedgehog", "Squirrel",
]

var _is_toddler: bool = false
var _drag: UniversalDrag = null
var _round: int = 0
var _start_time: float = 0.0

var _food_items: Array[Node2D] = []
var _plate_nodes: Array[Node2D] = []
var _animal_nodes: Array[Node2D] = []
var _eye_nodes: Array[Array] = []  ## Масив пар [left_eye, right_eye] для кожної тварини
var _all_round_nodes: Array[Node] = []
var _food_plate: Dictionary = {}  ## food_node -> plate_index (-1 = купка)
var _plate_counts: Array[int] = []  ## Лічильник їжі на кожній тарілці
var _item_origins: Dictionary = {}  ## food_node -> початкова позиція
var _animal_count: int = 2
var _food_count: int = 4
var _used_animals: Array[int] = []
var _current_food_type: String = "Apple"
var _dragged_food: Node2D = null  ## Поточний перетягуваний предмет для eye-tracking

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
	if _food_items.is_empty() or _plate_nodes.is_empty():
		return {}
	return {
		"type": "drag",
		"from": _food_items[0].global_position,
		"to": _plate_nodes[0].global_position,
	}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_food_plate.clear()
	_plate_counts.clear()
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	## Прогресивна складність з явних таблиць (A4, LAW 6)
	var round_data: Vector2i = _get_round_data(_round)
	_animal_count = round_data.x
	_food_count = round_data.y
	## Вибрати тип їжі для раунду
	_current_food_type = FOOD_TYPES[_round % FOOD_TYPES.size()]
	for i: int in _animal_count:
		_plate_counts.append(0)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_animals(vp)
	_spawn_plates(vp)
	_spawn_food(vp)
	var d: float = ANIM_FAST if SettingsManager.reduced_motion else ANIM_NORMAL
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		if _game_over:
			return
		_input_locked = false
		_drag.enabled = true
		_reset_idle_timer())


## Повертає (animal_count, food_count) для поточного раунду з явної таблиці.
## Гарантує подільність (A2) — ніколи неможливий раунд.
func _get_round_data(round_idx: int) -> Vector2i:
	var table: Array[Vector2i] = PRESCHOOL_ROUNDS
	if _is_toddler:
		table = TODDLER_ROUNDS
	if round_idx >= 0 and round_idx < table.size():
		return table[round_idx]
	## Fallback: останній раунд таблиці (LAW 7)
	if table.size() > 0:
		push_warning("Scales: round %d out of table range, using last entry" % round_idx)
		return table[table.size() - 1]
	push_warning("Scales: empty round table, using fallback 2/4")
	return Vector2i(2, 4)


## ---- Вибір тварин (без повторів) ----

func _pick_animals(count: int) -> Array[String]:
	var result: Array[String] = []
	for i: int in count:
		if _used_animals.size() >= ANIMAL_POOL.size():
			_used_animals.clear()
		var idx: int = randi() % maxi(ANIMAL_POOL.size(), 1)
		var attempts: int = 0
		while _used_animals.has(idx) and attempts < ANIMAL_POOL.size():
			idx = (idx + 1) % maxi(ANIMAL_POOL.size(), 1)
			attempts += 1
		_used_animals.append(idx)
		result.append(ANIMAL_POOL[idx])
	return result


## ---- Спавн тварин з очима ----

func _spawn_animals(vp: Vector2) -> void:
	var names: Array[String] = _pick_animals(_animal_count)
	var spacing: float = vp.x / float(_animal_count + 1)
	var animal_y: float = vp.y * 0.28
	for i: int in _animal_count:
		var animal: Node2D = Node2D.new()
		animal.position = Vector2(spacing * float(i + 1), animal_y)
		add_child(animal)
		## Спрайт тварини (LAW 7: fallback)
		var tex_path: String = "res://assets/sprites/animals/%s.png" % names[i]
		if ResourceLoader.exists(tex_path):
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = load(tex_path)
			sprite.scale = ANIMAL_DISPLAY_SCALE
			animal.add_child(sprite)
		else:
			push_warning("Scales: animal sprite not found: %s" % tex_path)
		## Обличчя-емоція (починає нейтральне) — окремий label
		var face_label: Label = Label.new()
		face_label.text = "😐"
		face_label.add_theme_font_size_override("font_size", 28)
		face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face_label.position = Vector2(-15, -80)
		face_label.size = Vector2(30, 30)
		animal.add_child(face_label)
		animal.set_meta("face_label", face_label)
		animal.set_meta("animal_name", names[i])
		## Очі для eye-tracking — два маленькі кружки
		var eye_pair: Array = _create_eyes(animal)
		_eye_nodes.append(eye_pair)
		_animal_nodes.append(animal)
		_all_round_nodes.append(animal)


## Створює пару очей (ліве + праве) як дітей тварини.
## Повертає [left_pupil, right_pupil] для eye-tracking.
func _create_eyes(parent: Node2D) -> Array:
	var eye_y: float = -45.0
	var eye_spacing: float = 16.0
	var eye_radius: float = 8.0
	var pupil_radius: float = 3.5
	var left_eye: Node2D = _make_single_eye(
		Vector2(-eye_spacing, eye_y), eye_radius, pupil_radius)
	parent.add_child(left_eye)
	var right_eye: Node2D = _make_single_eye(
		Vector2(eye_spacing, eye_y), eye_radius, pupil_radius)
	parent.add_child(right_eye)
	var left_pupil: Node2D = left_eye.get_meta("pupil", null)
	var right_pupil: Node2D = right_eye.get_meta("pupil", null)
	return [left_pupil, right_pupil]


## Один очний орган: білий кружок (склера) + чорний кружок (зіниця).
func _make_single_eye(pos: Vector2, eye_r: float, pupil_r: float) -> Node2D:
	var eye_root: Node2D = Node2D.new()
	eye_root.position = pos
	## Склера — біла з тонким контуром
	var sclera: Panel = Panel.new()
	sclera.size = Vector2(eye_r * 2, eye_r * 2)
	sclera.position = Vector2(-eye_r, -eye_r)
	var sclera_style: StyleBoxFlat = GameData.candy_circle(
		Color(1.0, 1.0, 1.0, 0.95), eye_r, false)
	sclera_style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	sclera_style.set_border_width_all(1)
	sclera.add_theme_stylebox_override("panel", sclera_style)
	sclera.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eye_root.add_child(sclera)
	## Зіниця — чорна рухома
	var pupil: Node2D = Node2D.new()
	var pupil_panel: Panel = Panel.new()
	pupil_panel.size = Vector2(pupil_r * 2, pupil_r * 2)
	pupil_panel.position = Vector2(-pupil_r, -pupil_r)
	var pupil_style: StyleBoxFlat = GameData.candy_circle(
		Color(0.1, 0.1, 0.1, 1.0), pupil_r, false)
	pupil_panel.add_theme_stylebox_override("panel", pupil_style)
	pupil_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pupil.add_child(pupil_panel)
	## Блік на зіниці (LAW 28)
	var glint: Panel = Panel.new()
	glint.size = Vector2(2.0, 2.0)
	glint.position = Vector2(-pupil_r * 0.4, -pupil_r * 0.4)
	var glint_style: StyleBoxFlat = StyleBoxFlat.new()
	glint_style.bg_color = Color(1, 1, 1, 0.7)
	glint_style.set_corner_radius_all(1)
	glint.add_theme_stylebox_override("panel", glint_style)
	glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pupil.add_child(glint)
	eye_root.add_child(pupil)
	eye_root.set_meta("pupil", pupil)
	return eye_root


## ---- Спавн тарілок ----

func _spawn_plates(vp: Vector2) -> void:
	var spacing: float = vp.x / float(_animal_count + 1)
	var plate_y: float = vp.y * 0.50
	for i: int in _animal_count:
		var plate: Node2D = Node2D.new()
		plate.position = Vector2(spacing * float(i + 1), plate_y)
		add_child(plate)
		## Кругла тарілка (LAW 28: candy depth)
		var panel: Panel = Panel.new()
		panel.size = Vector2(PLATE_RADIUS * 2, PLATE_RADIUS * 2)
		panel.position = Vector2(-PLATE_RADIUS, -PLATE_RADIUS)
		var style: StyleBoxFlat = GameData.candy_circle(
			Color(1.0, 0.98, 0.92, 0.9), PLATE_RADIUS)
		style.border_color = Color("ffd166")
		style.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", style)
		panel.material = GameData.create_premium_material(
			0.04, 2.0, 0.04, 0.0, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
		plate.add_child(panel)
		## Лічильник їжі на тарілці
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


## ---- Спавн їжі ----

func _spawn_food(vp: Vector2) -> void:
	var count: int = _food_count
	var cols: int = mini(count, 5)
	var rows: int = 1
	if cols > 0:
		rows = ceili(float(count) / float(cols))
	var gap: float = FOOD_SIZE + 10.0
	var start_x: float = vp.x * 0.5 - (float(cols) - 1.0) * gap * 0.5
	var start_y: float = vp.y * 0.72
	var tex_path: String = "res://assets/sprites/food/%s.png" % _current_food_type
	var food_tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		food_tex = load(tex_path)
	else:
		push_warning("Scales: food sprite not found: %s, using fallback Apple" % tex_path)
		var fallback_path: String = "res://assets/sprites/food/Apple.png"
		if ResourceLoader.exists(fallback_path):
			food_tex = load(fallback_path)
	for i: int in count:
		var col: int = i % maxi(cols, 1)
		var row: int = 0
		if cols > 0:
			@warning_ignore("integer_division")
			row = i / cols
		var food_node: Node2D = Node2D.new()
		add_child(food_node)
		if food_tex:
			## Спрайт їжі з масштабом
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = food_tex
			var tex_size: float = maxf(food_tex.get_width(), 1.0)
			var desired_scale: float = FOOD_SIZE / tex_size
			sprite.scale = Vector2(desired_scale, desired_scale)
			food_node.add_child(sprite)
		else:
			## Fallback: кольоровий кружок (LAW 7: ніколи порожній екран)
			var bg: Panel = Panel.new()
			bg.size = Vector2(FOOD_SIZE, FOOD_SIZE)
			bg.position = Vector2(-FOOD_SIZE * 0.5, -FOOD_SIZE * 0.5)
			var fallback_style: StyleBoxFlat = GameData.candy_circle(
				Color("e74c3c"), FOOD_SIZE * 0.5)
			bg.add_theme_stylebox_override("panel", fallback_style)
			bg.material = GameData.create_premium_material(
				0.06, 2.0, 0.06, 0.08, 0.06, 0.05, 0.08,
				"", 0.0, 0.10, 0.22, 0.18)
			GameData.add_gloss(bg, 8)
			food_node.add_child(bg)
		var target_pos: Vector2 = Vector2(
			start_x + float(col) * gap,
			start_y + float(row) * gap)
		food_node.position = target_pos
		_food_plate[food_node] = -1  ## -1 = в купці
		_item_origins[food_node] = target_pos
		_food_items.append(food_node)
		_drag.draggable_items.append(food_node)
		_all_round_nodes.append(food_node)
	_staggered_spawn(_food_items, 0.06)


## ---- Eye-tracking: зіниці стежать за перетягуваним предметом ----

func _process(delta: float) -> void:
	if _game_over:
		return
	_drag.handle_process(delta)
	## Eye-tracking — зіниці дивляться на перетягуваний предмет
	var look_target: Vector2 = Vector2.ZERO
	if _dragged_food and is_instance_valid(_dragged_food):
		look_target = _dragged_food.global_position
	for i: int in _animal_nodes.size():
		if i >= _eye_nodes.size():
			continue
		var animal: Node2D = _animal_nodes[i]
		if not is_instance_valid(animal):
			continue
		var pair: Array = _eye_nodes[i]
		if pair.size() < 2:
			continue
		for eye_idx: int in 2:
			var pupil: Node2D = pair[eye_idx] as Node2D
			if not is_instance_valid(pupil):
				continue
			if look_target != Vector2.ZERO:
				## Напрямок від ока до їжі — обмежене зміщення зіниці
				var eye_global: Vector2 = pupil.get_parent().global_position
				var dir: Vector2 = (look_target - eye_global).normalized()
				pupil.position = dir * EYE_OFFSET_MAX
			else:
				## Повернути зіниці в центр
				pupil.position = pupil.position.lerp(Vector2.ZERO, delta * 5.0)


## ---- Обличчя тварин (реальний час) ----

func _update_faces() -> void:
	if _animal_count <= 0:
		push_warning("Scales: _update_faces — _animal_count = 0")
		return
	@warning_ignore("integer_division")
	var fair_share: int = _food_count / maxi(_animal_count, 1)
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
		## Emoji: реакція в реальному часі на розподіл
		if placed_total == _food_count:
			## Всі предмети розкладені — показати результат
			if count == fair_share:
				face.text = "😊"  ## Щаслива — порівну
			elif count > fair_share:
				face.text = "😅"  ## Збентежена — забагато
			else:
				face.text = "😢"  ## Сумна — замало
		elif count > 0:
			face.text = "😊"  ## Отримала хоча б щось
		else:
			face.text = "😐"  ## Чекає


## ---- Input ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_input(event)


func _on_picked(item: Node2D) -> void:
	_dragged_food = item
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()


## ---- Drop на тарілку ----

func _on_dropped_target(item: Node2D, target: Node2D) -> void:
	_dragged_food = null
	if _game_over or _input_locked:
		return
	var plate_idx: int = target.get_meta("plate_index", -1)
	if plate_idx < 0 or plate_idx >= _plate_counts.size():
		push_warning("Scales: invalid plate index %d" % plate_idx)
		_drag.snap_back(item, _item_origins.get(item, item.position))
		return
	## Якщо предмет вже на тарілці — зняти з попередньої
	var old_plate: int = _food_plate.get(item, -1)
	if old_plate >= 0 and old_plate < _plate_counts.size():
		_plate_counts[old_plate] = maxi(_plate_counts[old_plate] - 1, 0)
		## Оновити лічильник старої тарілки
		if old_plate < _plate_nodes.size():
			var old_lbl: Label = _plate_nodes[old_plate].get_meta(
				"count_label", null) as Label
			if old_lbl:
				old_lbl.text = str(_plate_counts[old_plate])
	_food_plate[item] = plate_idx
	_plate_counts[plate_idx] += 1
	## Оновити лічильник на тарілці
	var count_lbl: Label = target.get_meta("count_label", null) as Label
	if count_lbl:
		count_lbl.text = str(_plate_counts[plate_idx])
	## Видалити з draggable поки на тарілці
	_drag.draggable_items.erase(item)
	AudioManager.play_sfx("coin")
	HapticsManager.vibrate_light()
	## Анімація snap до тарілки
	if SettingsManager.reduced_motion:
		item.global_position = target.global_position + Vector2(
			randf_range(-20, 20), randf_range(-15, 15))
		item.modulate.a = 0.7
		_update_faces()
		_check_completion()
		return
	var tw: Tween = create_tween()
	var offset: Vector2 = Vector2(randf_range(-20, 20), randf_range(-15, 15))
	tw.tween_property(item, "global_position",
		target.global_position + offset, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "modulate:a", 0.7, 0.15)
	tw.chain().tween_callback(func() -> void:
		if not is_instance_valid(item):
			return
		_update_faces()
		_check_completion())


## ---- Drop на порожнє місце (повернення) ----

func _on_dropped_empty(item: Node2D) -> void:
	_dragged_food = null
	var old_plate: int = _food_plate.get(item, -1)
	if old_plate >= 0 and old_plate < _plate_counts.size():
		_plate_counts[old_plate] = maxi(_plate_counts[old_plate] - 1, 0)
		## Оновити лічильник
		if old_plate < _plate_nodes.size():
			var lbl: Label = _plate_nodes[old_plate].get_meta(
				"count_label", null) as Label
			if lbl:
				lbl.text = str(_plate_counts[old_plate])
	_food_plate[item] = -1
	if not _drag.draggable_items.has(item):
		_drag.draggable_items.append(item)
	item.modulate.a = 1.0
	_drag.snap_back(item, _item_origins.get(item, item.position))
	_update_faces()
	_reset_idle_timer()


## ---- Перевірка завершення ----

func _check_completion() -> void:
	## Перевірити чи ВСІ предмети розкладені
	var all_placed: bool = true
	for food: Node2D in _food_items:
		if _food_plate.get(food, -1) < 0:
			all_placed = false
			break
	if not all_placed:
		_reset_idle_timer()
		return
	## Всі розкладені — перевірити рівність
	if _animal_count <= 0:
		push_warning("Scales: _check_completion — _animal_count = 0")
		return
	@warning_ignore("integer_division")
	var fair_share: int = _food_count / maxi(_animal_count, 1)
	var is_fair: bool = true
	for i: int in _animal_count:
		var count: int = _plate_counts[i] if i < _plate_counts.size() else 0
		if count != fair_share:
			is_fair = false
			break
	if is_fair:
		_on_shared_equally()
	else:
		_on_unfair_share()


## ---- Успіх: рівний розподіл ----

func _on_shared_equally() -> void:
	_register_correct()
	_input_locked = true
	_drag.enabled = false
	## Всі тварини ЩАСЛИВІ + "їдять" разом
	for idx: int in _animal_nodes.size():
		var animal: Node2D = _animal_nodes[idx]
		if not is_instance_valid(animal):
			continue
		var face: Label = animal.get_meta("face_label", null) as Label
		if face:
			face.text = "🥳"
		if not SettingsManager.reduced_motion:
			## Танок радості (LAW 28: premium feel)
			var dance: Tween = create_tween().set_loops(3)
			dance.tween_property(animal, "rotation", 0.1, 0.1)
			dance.tween_property(animal, "rotation", -0.1, 0.1)
			dance.tween_property(animal, "rotation", 0.0, 0.1)
		VFXManager.spawn_match_sparkle(animal.global_position)
	## Eating animation: ascending pitch crunch для perfect round
	_play_eating_sequence()
	VFXManager.spawn_premium_celebration(
		get_viewport().get_visible_rect().size * 0.5)
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	var delay: float = ANIM_FAST if SettingsManager.reduced_motion else 1.2
	var tw: Tween = create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if _game_over:
			return
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


## Анімація їжі: їжа зменшується послідовно з ascending pitch "crunch".
func _play_eating_sequence() -> void:
	if SettingsManager.reduced_motion:
		return
	for plate_idx: int in _plate_nodes.size():
		if plate_idx >= _plate_nodes.size():
			continue
		var plate: Node2D = _plate_nodes[plate_idx]
		if not is_instance_valid(plate):
			continue
		## Знайти їжу на цій тарілці та анімувати зменшення
		var eat_delay: float = 0.15 * float(plate_idx)
		for food: Node2D in _food_items:
			if not is_instance_valid(food):
				continue
			if _food_plate.get(food, -1) == plate_idx:
				var eat_tw: Tween = create_tween()
				eat_tw.tween_interval(eat_delay)
				eat_tw.tween_property(food, "scale",
					Vector2(0.3, 0.3), 0.2)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				eat_tw.tween_property(food, "modulate:a", 0.0, 0.1)
		## SFX "crunch" зі зростаючим pitch
		var crunch_pitch: float = 0.8 + 0.15 * float(plate_idx)
		get_tree().create_timer(eat_delay + 0.1).timeout.connect(
			func() -> void:
				if not is_instance_valid(self):
					return
				AudioManager.play_sfx("click", crunch_pitch))


## ---- Помилка: нерівний розподіл ----

func _on_unfair_share() -> void:
	_input_locked = true
	_drag.enabled = false
	if _is_toddler:
		## Toddler (A6): м'яке повернення — тварини сумні, їжа повертається
		_register_error()
		_return_all_food_to_pile()
		var d3: float = ANIM_FAST if SettingsManager.reduced_motion else ANIM_SLOW
		var tw: Tween = create_tween()
		tw.tween_interval(d3)
		tw.tween_callback(func() -> void:
			if _game_over:
				return
			_input_locked = false
			_drag.enabled = true
			_reset_idle_timer())
	else:
		## Preschool (A7): помилка + рестарт раунду
		_errors += 1
		_register_error()
		## Анімація "shiver" сумних тварин
		if not SettingsManager.reduced_motion:
			for animal: Node2D in _animal_nodes:
				if is_instance_valid(animal):
					var shiver: Tween = create_tween()
					shiver.tween_property(animal, "position:x",
						animal.position.x - 4, 0.05)
					shiver.tween_property(animal, "position:x",
						animal.position.x + 4, 0.05)
					shiver.tween_property(animal, "position:x",
						animal.position.x, 0.05)
		var d4: float = ANIM_FAST if SettingsManager.reduced_motion else 0.6
		var tw: Tween = create_tween()
		tw.tween_interval(d4)
		tw.tween_callback(func() -> void:
			if _game_over:
				return
			_clear_round()
			_start_round())


## Повертає ВСЮ їжу в купку (Toddler reset).
func _return_all_food_to_pile() -> void:
	for food: Node2D in _food_items:
		if not is_instance_valid(food):
			continue
		var old_plate: int = _food_plate.get(food, -1)
		if old_plate >= 0:
			food.modulate.a = 1.0
			food.scale = Vector2.ONE
			if not _drag.draggable_items.has(food):
				_drag.draggable_items.append(food)
		_food_plate[food] = -1
		_drag.snap_back(food, _item_origins.get(food, food.position))
	for i: int in _plate_counts.size():
		_plate_counts[i] = 0
	## Оновити лічильники тарілок
	for plate: Node2D in _plate_nodes:
		if not is_instance_valid(plate):
			continue
		var count_lbl: Label = plate.get_meta("count_label", null) as Label
		if count_lbl:
			count_lbl.text = "0"
	_update_faces()


## ---- Очищення раунду (A9: round hygiene) ----

func _clear_round() -> void:
	## Erase dict entries BEFORE queue_free (LAW 9)
	_dragged_food = null
	_food_plate.clear()
	_item_origins.clear()
	_food_items.clear()
	_plate_nodes.clear()
	_animal_nodes.clear()
	_eye_nodes.clear()
	_plate_counts.clear()
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	_drag.clear_drag()


## ---- Завершення гри ----

func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": TOTAL_ROUNDS,
		"earned_stars": earned,
	})


## ---- A11: scaffolding — підсвітити тарілку з найменшою кількістю ----

func _show_scaffold_hint() -> void:
	super()
	if _plate_counts.is_empty():
		push_warning("Scales: scaffolding — немає тарілок")
		return
	## Знайти тарілку з найменшою кількістю їжі
	var min_idx: int = 0
	var min_val: int = _plate_counts[0]
	for i: int in range(1, _plate_counts.size()):
		if i < _plate_counts.size() and _plate_counts[i] < min_val:
			min_val = _plate_counts[i]
			min_idx = i
	if min_idx < _plate_nodes.size() and is_instance_valid(_plate_nodes[min_idx]):
		_pulse_node(_plate_nodes[min_idx], 1.2)
	## Також пульсувати нерозкладену їжу
	for food: Node2D in _food_items:
		if is_instance_valid(food) and _food_plate.get(food, -1) < 0:
			_pulse_node(food, 1.15)
			break


## ---- A10: idle escalation — 3 рівні підказок ----

func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over or _food_items.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		## Level 2+: tutorial hand показується через _advance_idle_hint
		_reset_idle_timer()
		return
	## Level 0-1: пульсація нерозкладених предметів
	for item: Node2D in _food_items:
		if is_instance_valid(item) and _food_plate.get(item, -1) < 0:
			_pulse_node(item, 1.15)
			break
	_reset_idle_timer()
