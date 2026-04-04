extends BaseMiniGame

## ECE-07 Зеркальна магія / Mirror Magic
## Злий волшебник заточив тварин у розбитих дзеркалах.
## Перетягни праву половинку до лівої — дзеркало збереться, тварина оживе.
## Усі звільнені тварини збираються внизу. В кінці — святкування.
##
## Toddler: R1=1, R2=2, R3=2, R4=2 пари. Preschool: R1=1, R2=2, R3=2, R4=3 пари.
## A3: вікова розвилка. A4: прогресивна складність (більше пар, менший розмір, поворот).

const ROUNDS_TODDLER: int = 3   ## Toddler needs fewer rounds (shorter attention)
const ROUNDS_PRESCHOOL: int = 5  ## Preschool benefits from more rounds + rotation challenge
const DEAL_STAGGER: float = 0.12
const DEAL_DURATION: float = 0.35
const IDLE_HINT_DELAY: float = 5.0
const HALF_W: float = 128.0
const HALF_H: float = 256.0
const SPRITE_REGION_LEFT: Rect2 = Rect2(0, 0, 256, 512)
const SPRITE_REGION_RIGHT: Rect2 = Rect2(256, 0, 256, 512)
const SAFETY_TIMEOUT_SEC: float = 120.0
## Розмір спрайту зменшується по раундах (A4: прогресивна складність)
const SCALE_BASE: Vector2 = Vector2(0.42, 0.42)
const SCALE_SMALL: Vector2 = Vector2(0.34, 0.34)
## Дзеркальна рамка
const MIRROR_BG_COLOR: Color = Color(0.85, 0.88, 0.96, 0.75)
const MIRROR_BORDER: Color = Color("7eb8da")
const MIRROR_CORNER: int = 16


const ANIMAL_NAMES: Array[String] = [
	"Bear", "Bunny", "Cat", "Chicken", "Cow", "Crocodile", "Deer",
	"Dog", "Elephant", "Frog", "Goat", "Hedgehog", "Horse",
	"Lion", "Monkey", "Mouse", "Panda", "Penguin", "Squirrel",
]

var _is_toddler: bool = false
var _total_rounds: int = 4
var _drag: UniversalDrag = null
var _round: int = 0
var _matched: int = 0
var _total: int = 0
var _start_time: float = 0.0

var _right_halves: Array[Node2D] = []
var _left_targets: Array[Node2D] = []
var _all_round_nodes: Array[Node] = []
var _half_animal: Dictionary = {}
var _target_animal: Dictionary = {}
var _item_origins: Dictionary = {}
var _used_indices: Array[int] = []
## Звільнені тварини — маленькі іконки внизу екрану (наратив)
var _freed_animals: Array[Control] = []
var _freed_container: HBoxContainer = null
## Поворот правих половинок (R4 Preschool)
var _rotated_items: Dictionary = {}

var _idle_timer: SceneTreeTimer = null


func _ready() -> void:
	game_id = "magnetic_halves"
	_skill_id = "part_whole"
	bg_theme = "puzzle"
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
	_build_freed_bar()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("MIRROR_TUTORIAL_TODDLER")
	return tr("MIRROR_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _right_halves.is_empty() or _left_targets.is_empty():
		return {}
	## Знайти першу праву половинку та відповідний лівий таргет
	for item: Node2D in _right_halves:
		if not is_instance_valid(item):
			continue
		var animal: String = _half_animal.get(item, "")
		for target: Node2D in _left_targets:
			if is_instance_valid(target) and _target_animal.get(target, "") == animal:
				return {"type": "drag", "from": item.global_position, "to": target.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## Контейнер для звільнених тварин — розташований внизу екрану на UI layer
func _build_freed_bar() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_freed_container = HBoxContainer.new()
	_freed_container.set("theme_override_constants/separation", 8)
	_freed_container.alignment = BoxContainer.ALIGNMENT_CENTER
	## Позиціювання внизу по центру (абсолютні координати)
	_freed_container.position = Vector2(vp.x * 0.5 - 240.0, vp.y - 70.0)
	_freed_container.size = Vector2(480.0, 60.0)
	if _ui_layer:
		_ui_layer.add_child(_freed_container)
	else:
		add_child(_freed_container)


## ---- Раунди ----

func _start_round() -> void:
	_matched = 0
	_input_locked = true
	_rotated_items.clear()

	## Складність по раундах (A4):
	## R1: 1 пара (тюторіал). R2: 2 пари. R3: 2 пари менші. R4(P): 3 пари + поворот.
	var pairs: int = _get_round_pairs()
	var current_scale: Vector2 = _get_round_scale()

	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	_fade_instruction(_instruction_label, get_tutorial_instruction())

	var animals: Array[String] = _pick_animals(pairs)
	_spawn_left_targets(animals, current_scale)
	_spawn_right_halves(animals, current_scale)

	## A8: _total = фактична кількість спавнених таргетів (не запланована)
	_total = _left_targets.size()
	if _total == 0:
		push_warning("MagneticHalves: жодна пара не створена, пропускаємо раунд")
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round()
		return

	## Магнітний асист для тоддлерів
	if _is_toddler:
		_drag.magnetic_assist = true
		var mag_pairs: Dictionary = {}
		for item: Node2D in _right_halves:
			var anim_name: String = _half_animal.get(item, "")
			for target: Node2D in _left_targets:
				if _target_animal.get(target, "") == anim_name:
					mag_pairs[item] = target
					break
		_drag.set_correct_pairs(mag_pairs)


## Кількість пар за раунд (A3 + A4)
func _get_round_pairs() -> int:
	if _is_toddler:
		## Toddler: R1=1, R2=2, R3=2, R4=2
		if _round == 0:
			return 1
		return 2
	## Preschool: R1=1, R2=2, R3=2, R4=3
	if _round == 0:
		return 1
	if _round <= 2:
		return 2
	return 3


## Масштаб спрайтів за раунд (A4: менші спрайти = складніше)
func _get_round_scale() -> Vector2:
	if _round <= 1:
		return SCALE_BASE
	return SCALE_SMALL


## Чи потрібен поворот у цьому раунді (Preschool R4)
func _is_rotation_round() -> bool:
	return not _is_toddler and _round >= 3


func _pick_animals(count: int) -> Array[String]:
	var result: Array[String] = []
	if _used_indices.size() + count > ANIMAL_NAMES.size():
		_used_indices.clear()
	for i: int in count:
		var idx: int = randi() % ANIMAL_NAMES.size()
		var attempts: int = 0
		while _used_indices.has(idx) and attempts < ANIMAL_NAMES.size():
			idx = randi() % ANIMAL_NAMES.size()
			attempts += 1
		_used_indices.append(idx)
		if idx < ANIMAL_NAMES.size():
			result.append(ANIMAL_NAMES[idx])
	return result


func _spawn_left_targets(animals: Array[String], sprite_scale: Vector2) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = animals.size()
	if count == 0:
		push_warning("MagneticHalves: _spawn_left_targets — порожній масив тварин")
		return
	var spacing: float = (vp.y - 220.0) / float(count + 1)
	var start_y: float = 160.0
	var target_x: float = vp.x * 0.25

	for i: int in count:
		var animal: String = animals[i]
		var tex_path: String = "res://assets/sprites/animals/%s.png" % animal
		if not ResourceLoader.exists(tex_path):
			push_warning("MagneticHalves: Missing sprite: " + tex_path)
			continue
		var tex: Texture2D = load(tex_path)
		if not tex:
			push_warning("MagneticHalves: текстуру '%s' не знайдено" % tex_path)
			continue

		var target: Node2D = Node2D.new()
		target.position = Vector2(target_x, start_y + spacing * float(i + 1))
		add_child(target)

		## Дзеркальна рамка — напівпрозора з сяйвом
		var bg: Panel = Panel.new()
		var bg_w: float = HALF_W * sprite_scale.x + 24.0
		var bg_h: float = HALF_H * sprite_scale.y + 24.0
		bg.size = Vector2(bg_w, bg_h)
		bg.position = Vector2(-bg_w * 0.5, -bg_h * 0.5)
		var style: StyleBoxFlat = GameData.candy_panel(MIRROR_BG_COLOR, MIRROR_CORNER)
		style.border_color = MIRROR_BORDER
		style.set_border_width_all(3)
		bg.add_theme_stylebox_override("panel", style)
		## Grain overlay (LAW 28)
		bg.material = GameData.create_premium_material(
			0.04, 2.0, 0.04, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		GameData.add_gloss(bg, MIRROR_CORNER)
		target.add_child(bg)

		## Ліва половина тварини (привид у дзеркалі — напівпрозора, злегка синювата)
		var hint_sprite: Sprite2D = Sprite2D.new()
		hint_sprite.texture = tex
		hint_sprite.region_enabled = true
		hint_sprite.region_rect = SPRITE_REGION_LEFT
		hint_sprite.scale = sprite_scale
		hint_sprite.modulate = Color(0.85, 0.9, 1.0, 0.25)
		hint_sprite.name = "HintSprite"
		target.add_child(hint_sprite)

		## Тріщини дзеркала — декоративні лінії (LAW 25: не тільки кольором)
		var crack_line: Line2D = _create_mirror_crack(bg_w, bg_h)
		target.add_child(crack_line)

		target.set_meta("is_filled", false)
		_left_targets.append(target)
		_target_animal[target] = animal
		_drag.drop_targets.append(target)
		_all_round_nodes.append(target)

	_staggered_spawn(_left_targets, 0.08)


## Декоративні тріщини дзеркала
func _create_mirror_crack(w: float, h: float) -> Line2D:
	var line: Line2D = Line2D.new()
	line.width = 1.5
	line.default_color = Color(0.7, 0.75, 0.85, 0.4)
	line.antialiased = true
	## Проста діагональна тріщина
	line.add_point(Vector2(-w * 0.15, -h * 0.35))
	line.add_point(Vector2(w * 0.05, -h * 0.05))
	line.add_point(Vector2(-w * 0.1, h * 0.15))
	line.add_point(Vector2(w * 0.08, h * 0.3))
	return line


func _spawn_right_halves(animals: Array[String], sprite_scale: Vector2) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = animals.size()
	if count == 0:
		push_warning("MagneticHalves: _spawn_right_halves — порожній масив тварин")
		return

	## Перемішуємо порядок правих половинок
	var shuffled: Array[String] = animals.duplicate()
	shuffled.shuffle()

	var spacing: float = (vp.y - 220.0) / float(count + 1)
	var start_y: float = 160.0
	var item_x: float = vp.x * 0.75
	var use_rotation: bool = _is_rotation_round()

	for i: int in count:
		var animal: String = shuffled[i]
		var tex_path: String = "res://assets/sprites/animals/%s.png" % animal
		if not ResourceLoader.exists(tex_path):
			push_warning("MagneticHalves: Missing sprite: " + tex_path)
			continue
		var tex: Texture2D = load(tex_path)
		if not tex:
			push_warning("MagneticHalves: текстуру '%s' не знайдено" % tex_path)
			continue

		var item: Node2D = Node2D.new()
		add_child(item)

		## Кругле біле тло
		var bg_sz: float = maxf(HALF_W, HALF_H) * sprite_scale.x + 16.0
		var bg: Panel = Panel.new()
		bg.size = Vector2(bg_sz, bg_sz)
		bg.position = Vector2(-bg_sz * 0.5, -bg_sz * 0.5)
		bg.add_theme_stylebox_override("panel",
			GameData.candy_circle(Color("fff8e1"), bg_sz * 0.4))
		## Grain + gloss (LAW 28)
		bg.material = GameData.create_premium_material(
			0.04, 2.0, 0.04, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		GameData.add_gloss(bg, 10)
		item.add_child(bg)

		## Права половина тварини
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = tex
		sprite.region_enabled = true
		sprite.region_rect = SPRITE_REGION_RIGHT
		sprite.scale = sprite_scale
		item.add_child(sprite)

		var target_pos: Vector2 = Vector2(item_x, start_y + spacing * float(i + 1))
		_half_animal[item] = animal
		_item_origins[item] = target_pos
		_right_halves.append(item)
		_drag.draggable_items.append(item)
		_all_round_nodes.append(item)

		## R4 Preschool: повернути одну половинку для додаткової складності (A4)
		var initial_rotation: float = 0.0
		if use_rotation and i == 0:
			initial_rotation = deg_to_rad(15.0)
			_rotated_items[item] = initial_rotation

		## Deal анімація
		if SettingsManager.reduced_motion:
			item.position = target_pos
			item.modulate.a = 1.0
			item.rotation = initial_rotation
			if i == count - 1:
				_input_locked = false
				_drag.enabled = true
				_start_idle_breathing(_drag.draggable_items)
				_reset_idle_timer()
		else:
			item.position = Vector2(vp.x + 100.0, target_pos.y)
			item.modulate.a = 0.0
			item.rotation = initial_rotation
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = _create_game_tween().set_parallel(true)
			tw.tween_property(item, "position", target_pos, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
			if i == count - 1:
				tw.chain().tween_callback(func() -> void:
					_input_locked = false
					_drag.enabled = true
					_start_idle_breathing(_drag.draggable_items)
					_reset_idle_timer())


## ---- Input ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_input(event)


func _process(_delta: float) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_process(_delta)


## ---- Drop ----

func _on_picked(_item: Node2D) -> void:
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()


func _on_dropped_target(item: Node2D, target: Node2D) -> void:
	if _game_over:
		return
	var item_animal: String = _half_animal.get(item, "")
	var target_animal_name: String = _target_animal.get(target, "")
	if item_animal == target_animal_name and not target.get_meta("is_filled", false):
		_handle_correct(item, target)
	else:
		_handle_wrong(item)


func _on_dropped_empty(item: Node2D) -> void:
	_drag.snap_back(item, _item_origins.get(item, item.position))


func _handle_correct(item: Node2D, target: Node2D) -> void:
	_register_correct(item)
	target.set_meta("is_filled", true)
	_drag.draggable_items.erase(item)
	_right_halves.erase(item)
	_matched += 1
	item.z_index = 0

	var animal_name: String = _half_animal.get(item, "")
	var sprite_scale: Vector2 = _get_round_scale()

	## Магнітний snap — правий до лівого
	var offset_x: float = HALF_W * sprite_scale.x * 2.0
	var snap_pos: Vector2 = target.global_position + Vector2(offset_x, 0)

	if SettingsManager.reduced_motion:
		item.global_position = snap_pos
		item.rotation = 0.0
		## Дзеркало зібралося — зробити hint повністю видимим
		_reveal_mirror(target)
		## Тріщини зникають
		_hide_crack_lines(target)
		_add_freed_animal_icon(animal_name)
		if _matched >= _total:
			_on_round_complete()
		else:
			_reset_idle_timer()
		return

	## Анімація: snap + обертання до 0 + розкриття дзеркала
	var tw: Tween = _create_game_tween()
	tw.tween_property(item, "global_position", snap_pos, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "rotation", 0.0, 0.15)

	## Дзеркало зібралось — тварина "оживає"
	tw.tween_callback(func() -> void:
		if not is_instance_valid(target):
			return
		_reveal_mirror(target)
		_hide_crack_lines(target)
		## Burst sparkles при зборці дзеркала
		VFXManager.spawn_match_sparkle(target.global_position)
		VFXManager.spawn_correct_sparkle(target.global_position)
		AudioManager.play_sfx("snap")
	)

	## Scale bounce — тварина "прокидається"
	tw.tween_callback(func() -> void:
		if not is_instance_valid(target):
			return
		_animate_awakening(target)
	)

	## Додати звільнену тварину після анімації
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void:
		_add_freed_animal_icon(animal_name)
		if _matched >= _total:
			_on_round_complete()
		else:
			_reset_idle_timer()
	)


## Розкрити дзеркало — ліва половинка стає повністю видимою
func _reveal_mirror(target: Node2D) -> void:
	if not is_instance_valid(target):
		push_warning("MagneticHalves: _reveal_mirror — target freed")
		return
	for child: Node in target.get_children():
		if child is Sprite2D and child.name == "HintSprite":
			var sp: Sprite2D = child as Sprite2D
			if SettingsManager.reduced_motion:
				sp.modulate = Color(1, 1, 1, 1.0)
			else:
				var reveal_tw: Tween = _create_game_tween()
				reveal_tw.tween_property(sp, "modulate", Color(1, 1, 1, 1.0), 0.3)\
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Сховати тріщини дзеркала після зборки
func _hide_crack_lines(target: Node2D) -> void:
	if not is_instance_valid(target):
		push_warning("MagneticHalves: _hide_crack_lines — target freed")
		return
	for child: Node in target.get_children():
		if child is Line2D:
			if SettingsManager.reduced_motion:
				child.visible = false
			else:
				var fade_tw: Tween = _create_game_tween()
				fade_tw.tween_property(child, "modulate:a", 0.0, 0.2)
				fade_tw.tween_callback(func() -> void:
					if is_instance_valid(child):
						child.visible = false)


## Анімація "пробудження" тварини — scale bounce
func _animate_awakening(target: Node2D) -> void:
	if not is_instance_valid(target):
		push_warning("MagneticHalves: _animate_awakening — target freed")
		return
	var aw_tw: Tween = _create_game_tween()
	aw_tw.tween_property(target, "scale", Vector2(1.15, 1.15), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	aw_tw.tween_property(target, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Додати маленьку іконку звільненої тварини внизу екрану
func _add_freed_animal_icon(animal_name: String) -> void:
	if not is_instance_valid(_freed_container):
		push_warning("MagneticHalves: _freed_container freed")
		return
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if not ResourceLoader.exists(tex_path):
		push_warning("MagneticHalves: freed icon missing: " + tex_path)
		return
	var tex: Texture2D = load(tex_path)
	if not tex:
		push_warning("MagneticHalves: freed icon load failed: " + tex_path)
		return
	var icon: TextureRect = TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_freed_container.add_child(icon)
	_freed_animals.append(icon)

	## Поява з анімацією
	if not SettingsManager.reduced_motion:
		icon.modulate.a = 0.0
		icon.scale = Vector2(0.3, 0.3)
		icon.pivot_offset = Vector2(24, 24)
		var icon_tw: Tween = _create_game_tween()
		icon_tw.tween_property(icon, "modulate:a", 1.0, 0.2)
		icon_tw.parallel().tween_property(icon, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _handle_wrong(item: Node2D) -> void:
	if _is_toddler:
		_register_error(item)  ## A11: scaffolding для тоддлера
	else:
		_errors += 1
		_register_error(item)
	_drag.snap_back(item, _item_origins.get(item, item.position))


## ---- Round management ----

func _on_round_complete() -> void:
	_input_locked = true
	_drag.enabled = false
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.8
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round())


func _clear_round() -> void:
	## A9: повне очищення між раундами
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			## Erase from dicts BEFORE queue_free
			_half_animal.erase(node)
			_target_animal.erase(node)
			_item_origins.erase(node)
			_rotated_items.erase(node)
			node.queue_free()
	_all_round_nodes.clear()
	_right_halves.clear()
	_left_targets.clear()
	_half_animal.clear()
	_target_animal.clear()
	_item_origins.clear()
	_rotated_items.clear()
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	_drag.clear_drag()


func _finish() -> void:
	_game_over = true
	_input_locked = true

	## Фінальна святкова анімація звільнених тварин
	if not SettingsManager.reduced_motion and _freed_animals.size() > 0:
		_play_finale_animation()

	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	## Невеличка затримка для фіналу, потім показати результат
	var finale_delay: float = 0.0 if SettingsManager.reduced_motion else 1.2
	get_tree().create_timer(finale_delay).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		finish_game(earned, {"time_sec": elapsed, "errors": _errors,
			"rounds_played": _total_rounds, "earned_stars": earned}))


## Фінальна анімація — усі звільнені тварини підстрибують (святкування)
func _play_finale_animation() -> void:
	for i: int in _freed_animals.size():
		var icon: Control = _freed_animals[i]
		if not is_instance_valid(icon):
			continue
		var delay: float = float(i) * 0.1
		var bounce_tw: Tween = _create_game_tween()
		bounce_tw.tween_interval(delay)
		bounce_tw.tween_property(icon, "scale", Vector2(1.3, 1.3), 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bounce_tw.tween_property(icon, "scale", Vector2.ONE, 0.2)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## Sparkle burst на всіх звільнених
	var vp: Vector2 = get_viewport().get_visible_rect().size
	VFXManager.spawn_golden_burst(Vector2(vp.x * 0.5, vp.y - 50.0))


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
	if _input_locked or _game_over or _right_halves.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	for item: Node2D in _right_halves:
		if is_instance_valid(item):
			_pulse_node(item, 1.15)
			break
	_reset_idle_timer()
