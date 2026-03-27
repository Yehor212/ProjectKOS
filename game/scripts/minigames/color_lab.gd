extends BaseMiniGame

## Чарівні зілля — тварина-пацієнт хвора, потрібно зварити зілля потрібного кольору!
## Дитина перетягує 2 пробірки у котел → котел бурлить, змінює колір →
## правильне зілля → тварина випиває і "зцілюється" кольоровим сяйвом.
## 16 рецептів — достатньо для 3+ сесій без повторів.

const TOTAL_ROUNDS: int = 5
const IDLE_HINT_DELAY: float = 5.0
const TUBE_WIDTH: float = 62.0
const TUBE_HEIGHT: float = 90.0
const CAULDRON_RADIUS: float = 75.0
const DEAL_STAGGER: float = 0.12
const DEAL_DURATION: float = 0.35
const ITEM_SPAWN_Y_OFFSET: float = 100.0
const TUBE_CORNER_RADIUS: float = 12.0
const SAFETY_TIMEOUT_SEC: float = 120.0
const ANIMAL_SCALE: float = 0.65
const ANIMAL_SICK_COLOR: Color = Color(0.55, 0.55, 0.55, 1.0)
const CAULDRON_BUBBLE_COUNT: int = 5

## 16 рецептів змішування кольорів — 4 тіри складності
## Ключі відсортовані за алфавітом для коректного пошуку
const COLOR_MIXES: Dictionary = {
	## Tier 1 — базове змішування (R0-1): primary -> secondary
	"red+yellow": "orange",
	"blue+yellow": "green",
	"blue+red": "purple",
	## Tier 2 — з білим (R2-3): primary + white -> pastel
	"red+white": "pink",
	"white+yellow": "cream",
	"blue+white": "light_blue",
	## Tier 3 — secondary combos (R4-5): secondary + primary -> tertiary
	"blue+orange": "brown",
	"green+yellow": "lime",
	"orange+red": "scarlet",
	"green+red": "dark_brown",
	## Tier 4 — advanced (R6+): pastel + secondary
	"orange+white": "peach",
	"purple+white": "lavender",
	"green+white": "mint",
	"purple+yellow": "olive",
	"pink+yellow": "salmon",
	"blue+pink": "lavender_blue",
}

## Кольори для відображення
const COLOR_VALUES: Dictionary = {
	## Базові (primary)
	"red": Color("e74c3c"),
	"yellow": Color("f1c40f"),
	"blue": Color("3498db"),
	"white": Color("ecf0f1"),
	## Secondary
	"orange": Color("e67e22"),
	"green": Color("27ae60"),
	"purple": Color("8e44ad"),
	"pink": Color("fd79a8"),
	## Tier 2 результати
	"cream": Color(1.0, 0.95, 0.8),
	"light_blue": Color(0.5, 0.8, 1.0),
	## Tier 3 результати
	"brown": Color(0.55, 0.35, 0.17),
	"lime": Color(0.6, 0.9, 0.2),
	"scarlet": Color(0.9, 0.2, 0.1),
	"dark_brown": Color(0.40, 0.26, 0.13),
	## Tier 4 результати
	"peach": Color(1.0, 0.85, 0.7),
	"lavender": Color(0.78, 0.64, 0.96),
	"mint": Color(0.6, 0.95, 0.75),
	"olive": Color(0.55, 0.55, 0.15),
	"salmon": Color(1.0, 0.65, 0.55),
	"lavender_blue": Color(0.6, 0.55, 0.95),
}

var _drag: UniversalDrag = null
var _is_toddler: bool = false
var _round: int = 0
var _correct_mixes: int = 0
var _start_time: float = 0.0

var _tube_items: Array[Node2D] = []
var _cauldron: Node2D = null
var _cauldron_panel: Panel = null
var _all_round_nodes: Array[Node] = []
var _tube_color: Dictionary = {}
var _tube_origins: Dictionary = {}
var _dropped_colors: Array[String] = []
var _target_color: String = ""
var _target_recipe_key: String = ""
var _used_recipes: Array[String] = []
var _used_animal_indices: Array[int] = []

var _animal_node: Node2D = null
var _animal_sprite: Node2D = null
var _thought_bubble: Node2D = null
var _target_label: Label = null
var _idle_timer: SceneTreeTimer = null
var _bubble_nodes: Array[Node2D] = []


func _ready() -> void:
	game_id = "color_lab"
	bg_theme = "science"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_drag = UniversalDrag.new(self)
	if _is_toddler:
		_drag.magnetic_assist = true
		_drag.snap_radius_override = TODDLER_SNAP_RADIUS
	_drag.item_picked_up.connect(_on_picked)
	_drag.item_dropped_on_target.connect(_on_dropped_target)
	_drag.item_dropped_on_empty.connect(_on_dropped_empty)
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	return tr("COLOR_LAB_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	if _tube_items.is_empty() or not _cauldron:
		return {}
	var tube: Node2D = _tube_items[0]
	return {"type": "drag", "from": tube.global_position, "to": _cauldron.global_position}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_dropped_colors.clear()
	_bubble_nodes.clear()
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	## Обираємо рецепт
	var recipe: Dictionary = _pick_recipe()
	_target_color = recipe.result
	_target_recipe_key = recipe.key
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_animal_patient(vp)
	_spawn_cauldron(vp)
	_spawn_tubes(vp, recipe.colors)


func _pick_recipe() -> Dictionary:
	## Tier-based progression: ранні раунди = прості рецепти
	var tier1: Array[String] = ["red+yellow", "blue+yellow", "blue+red"]
	var tier2: Array[String] = ["red+white", "white+yellow", "blue+white"]
	var tier3: Array[String] = ["blue+orange", "green+yellow", "orange+red", "green+red"]
	var tier4: Array[String] = ["orange+white", "purple+white", "green+white",
		"purple+yellow", "pink+yellow", "blue+pink"]

	var pool: Array[String] = []
	if _round < 2:
		pool = tier1
	elif _round < 4:
		pool = tier1 + tier2
	else:
		pool = tier1 + tier2 + tier3
		if not _is_toddler:
			pool = pool + tier4

	## Обираємо невикористаний рецепт з відповідного пулу
	var available: Array[String] = []
	for k: String in pool:
		if not _used_recipes.has(k):
			available.append(k)
	if available.is_empty():
		_used_recipes.clear()
		for k2: String in pool:
			available.append(k2)
	## LAW 13 / A8: fallback на випадок порожнього пулу
	if available.is_empty():
		push_warning("ColorLab: no recipes available, using fallback")
		return {"key": "red+yellow", "result": "orange", "colors": ["red", "yellow"]}
	var chosen_key: String = available[randi() % available.size()]
	_used_recipes.append(chosen_key)
	var parts: PackedStringArray = chosen_key.split("+")
	if parts.size() < 2:
		push_warning("ColorLab: malformed recipe key '%s'" % chosen_key)
		return {"key": "red+yellow", "result": "orange", "colors": ["red", "yellow"]}
	var colors: Array[String] = [parts[0], parts[1]]
	return {"key": chosen_key, "result": COLOR_MIXES.get(chosen_key, "orange"), "colors": colors}


## ---- Тварина-пацієнт ----

func _spawn_animal_patient(vp: Vector2) -> void:
	_animal_node = Node2D.new()
	_animal_node.position = Vector2(vp.x * 0.15, vp.y * 0.45)
	add_child(_animal_node)
	_all_round_nodes.append(_animal_node)

	## Обираємо тварину (без повторів поспіль)
	var animal_count: int = GameData.ANIMALS_AND_FOOD.size()
	if animal_count <= 0:
		push_warning("ColorLab: ANIMALS_AND_FOOD empty, using fallback")
		_spawn_animal_fallback()
		_spawn_thought_bubble(vp)
		return

	var idx: int = randi() % animal_count
	## Уникаємо повторів
	var attempts: int = 0
	while _used_animal_indices.has(idx) and attempts < animal_count:
		idx = (idx + 1) % animal_count
		attempts += 1
	if _used_animal_indices.size() >= animal_count:
		_used_animal_indices.clear()
	_used_animal_indices.append(idx)

	var animal_data: Dictionary = GameData.ANIMALS_AND_FOOD[idx]
	## LAW 7: sprite fallback
	if animal_data.has("animal_scene") and animal_data.get("animal_scene") != null:
		_animal_sprite = animal_data.animal_scene.instantiate()
		_animal_sprite.scale = Vector2(ANIMAL_SCALE, ANIMAL_SCALE)
		_animal_sprite.position = Vector2.ZERO
		## "Хворий" стан — десатурація
		_animal_sprite.modulate = ANIMAL_SICK_COLOR
		_animal_node.add_child(_animal_sprite)
	else:
		push_warning("ColorLab: animal_scene missing for idx %d, using fallback" % idx)
		_spawn_animal_fallback()

	_spawn_thought_bubble(vp)

	## Анімація входу тварини
	if not SettingsManager.reduced_motion:
		var target_pos: Vector2 = _animal_node.position
		_animal_node.position = Vector2(-100.0, target_pos.y)
		_animal_node.modulate.a = 0.0
		var tw: Tween = _create_game_tween()
		tw.set_parallel(true)
		tw.tween_property(_animal_node, "position", target_pos, 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_animal_node, "modulate:a", 1.0, 0.3)


func _spawn_animal_fallback() -> void:
	## LAW 7: fallback — кольорова іконка замість порожнього екрану
	var fallback: Control = IconDraw.beaker(80.0)
	fallback.position = Vector2(-40, -40)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_animal_node.add_child(fallback)


func _spawn_thought_bubble(_vp: Vector2) -> void:
	## "Думка" тварини — який колір зілля потрібен
	_thought_bubble = Node2D.new()
	_thought_bubble.position = Vector2(60.0, -70.0)
	_animal_node.add_child(_thought_bubble)

	## Фон бульбашки думки
	var bubble_bg: Panel = Panel.new()
	bubble_bg.size = Vector2(90, 50)
	bubble_bg.position = Vector2(-45, -25)
	var bubble_style: StyleBoxFlat = StyleBoxFlat.new()
	bubble_style.bg_color = Color(1.0, 1.0, 1.0, 0.85)
	bubble_style.corner_radius_top_left = 14
	bubble_style.corner_radius_top_right = 14
	bubble_style.corner_radius_bottom_left = 14
	bubble_style.corner_radius_bottom_right = 14
	bubble_style.border_color = Color("b2bec3")
	bubble_style.set_border_width_all(2)
	bubble_bg.add_theme_stylebox_override("panel", bubble_style)
	_thought_bubble.add_child(bubble_bg)

	## Кольорова точка цільового кольору (LAW 25: CB pattern overlay)
	var cb_pat: String = GameData.get_cb_pattern(_target_color) if SettingsManager.color_blind_mode else ""
	var dot: Control = IconDraw.color_dot_cb(28.0, COLOR_VALUES.get(_target_color, Color.GRAY), cb_pat)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.position = Vector2(-14.0, -14.0)
	_thought_bubble.add_child(dot)

	## Назва цільового кольору під бульбашкою (LAW 10: навчальна цінність)
	_target_label = Label.new()
	var color_key: String = "COLOR_" + _target_color.to_upper()
	_target_label.text = tr(color_key)
	_target_label.add_theme_font_size_override("font_size", 24)
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.position = Vector2(-45, 30)
	_target_label.size = Vector2(90, 30)
	_thought_bubble.add_child(_target_label)

	## Пульсація бульбашки для привернення уваги
	if not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween().set_loops(0)
		tw.tween_property(_thought_bubble, "scale", Vector2(1.08, 1.08), 0.8)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_thought_bubble, "scale", Vector2.ONE, 0.8)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## ---- Котел ----

func _spawn_cauldron(vp: Vector2) -> void:
	_cauldron = Node2D.new()
	_cauldron.position = Vector2(vp.x * 0.5, vp.y * 0.45)
	add_child(_cauldron)

	## Основа котла
	_cauldron_panel = Panel.new()
	_cauldron_panel.size = Vector2(CAULDRON_RADIUS * 2, CAULDRON_RADIUS * 2)
	_cauldron_panel.position = Vector2(-CAULDRON_RADIUS, -CAULDRON_RADIUS)
	var style: StyleBoxFlat = GameData.candy_circle(Color(0.25, 0.25, 0.3, 0.9), CAULDRON_RADIUS)
	style.border_color = Color("636e72")
	style.set_border_width_all(4)
	_cauldron_panel.add_theme_stylebox_override("panel", style)
	## Premium overlay (LAW 28)
	var cauldron_tex: String = "res://assets/textures/backtiles/backtile_12.png"
	if ResourceLoader.exists(cauldron_tex):
		_cauldron_panel.material = GameData.create_premium_material(
			0.04, 2.0, 0.06, 0.08, 0.06, 0.05, 0.08, cauldron_tex, 0.15, 0.10, 0.22, 0.18)
	_cauldron.add_child(_cauldron_panel)

	## HQ іконка котла
	var beaker_tex_path: String = "res://assets/textures/game_icons/icon_beaker.png"
	var icon_size: Vector2 = Vector2(50, 50)
	var beaker_icon: Control
	if ResourceLoader.exists(beaker_tex_path):
		var beaker_tex: Texture2D = load(beaker_tex_path)
		beaker_icon = Control.new()
		var _captured_tex: Texture2D = beaker_tex
		var _captured_size: Vector2 = icon_size
		beaker_icon.draw.connect(func() -> void:
			beaker_icon.draw_texture_rect(_captured_tex, Rect2(Vector2.ZERO, _captured_size), false)
		)
	else:
		beaker_icon = IconDraw.beaker(48.0)
	beaker_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beaker_icon.position = Vector2(-25, -25)
	beaker_icon.size = icon_size
	_cauldron.add_child(beaker_icon)

	## Бульбашки "бурління" котла (анімовані)
	if not SettingsManager.reduced_motion:
		_spawn_cauldron_bubbles()

	_drag.drop_targets.append(_cauldron)
	_all_round_nodes.append(_cauldron)


func _spawn_cauldron_bubbles() -> void:
	## Невеликі кружечки що рухаються вверх — імітація бурління
	for i: int in CAULDRON_BUBBLE_COUNT:
		var bubble: Node2D = Node2D.new()
		var bx: float = randf_range(-CAULDRON_RADIUS * 0.5, CAULDRON_RADIUS * 0.5)
		bubble.position = Vector2(bx, randf_range(-10.0, 20.0))
		bubble.modulate.a = 0.4
		_cauldron.add_child(bubble)
		_bubble_nodes.append(bubble)
		_all_round_nodes.append(bubble)

		var dot: Control = IconDraw.color_dot(randf_range(6.0, 12.0), Color(0.7, 0.7, 0.8, 0.5))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.add_child(dot)

		## Нескінченна анімація бульбашки
		var delay: float = randf_range(0.0, 2.0)
		var dur: float = randf_range(1.5, 3.0)
		var tw: Tween = _create_game_tween().set_loops(0)
		tw.tween_property(bubble, "position:y", bubble.position.y - 40.0, dur)\
			.set_delay(delay).set_trans(Tween.TRANS_SINE)
		tw.tween_property(bubble, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func() -> void:
			if is_instance_valid(bubble):
				bubble.position.y = randf_range(-10.0, 20.0)
				bubble.modulate.a = 0.4)


## ---- Пробірки ----

func _spawn_tubes(vp: Vector2, recipe_colors: Array[String]) -> void:
	## Пробірки: 2 правильних + прогресивні відволікачі (A1, A4)
	var all_colors: Array[String] = ["red", "yellow", "blue", "white"]
	if _round >= 3:
		all_colors.append_array(["orange", "green", "purple"])
	if _round >= 4 and not _is_toddler:
		all_colors.append_array(["pink"])

	var tubes: Array[String] = recipe_colors.duplicate()
	## LAW 2: мінімум 3 варіанти. LAW 6: прогресивна складність
	var max_tubes: int = _scale_by_round_i(3, maxi(all_colors.size(), 3), _round, TOTAL_ROUNDS)
	## Додаємо відволікачі
	for c: String in all_colors:
		if tubes.size() >= max_tubes:
			break
		if not tubes.has(c):
			tubes.append(c)
	tubes.shuffle()

	var count: int = tubes.size()
	if count <= 0:
		push_warning("ColorLab: zero tubes, using fallback")
		tubes = recipe_colors.duplicate()
		tubes.append("white")
		count = tubes.size()
	var spacing: float = vp.x / float(maxi(count + 1, 2))
	var tube_y: float = vp.y * 0.80

	for i: int in count:
		var color_name: String = tubes[i]
		var item: Node2D = Node2D.new()
		add_child(item)

		## Пробірка — прямокутник з закругленням
		var bg: Panel = Panel.new()
		bg.size = Vector2(TUBE_WIDTH, TUBE_HEIGHT)
		bg.position = Vector2(-TUBE_WIDTH * 0.5, -TUBE_HEIGHT * 0.5)
		bg.add_theme_stylebox_override("panel",
			GameData.candy_panel(COLOR_VALUES.get(color_name, Color.GRAY),
				int(TUBE_CORNER_RADIUS)))
		## Premium overlay (LAW 28)
		var tube_tile: String = "res://assets/textures/tiles/yellow/tile_%02d.png" % ((i % 5) + 1)
		if ResourceLoader.exists(tube_tile):
			bg.material = GameData.create_premium_material(
				0.05, 2.0, 0.04, 0.06, 0.04, 0.03, 0.05, tube_tile, 0.15, 0.10, 0.22, 0.18)
		item.add_child(bg)

		## Кольорова точка (LAW 25: CB pattern overlay)
		var tube_pat: String = GameData.get_cb_pattern(color_name) if SettingsManager.color_blind_mode else ""
		var dot: Control = IconDraw.color_dot_cb(24.0, COLOR_VALUES.get(color_name, Color.GRAY), tube_pat)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(-12.0, -12.0 + (TUBE_HEIGHT - 24.0) * 0.1)
		item.add_child(dot)

		## Мітка кольору під пробіркою (LAW 10: навчальна цінність, A12: i18n)
		var tube_label: Label = Label.new()
		var tube_color_key: String = "COLOR_" + color_name.to_upper()
		tube_label.text = tr(tube_color_key)
		tube_label.add_theme_font_size_override("font_size", 16)
		tube_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tube_label.position = Vector2(-TUBE_WIDTH * 0.5, TUBE_HEIGHT * 0.5 + 2.0)
		tube_label.size = Vector2(TUBE_WIDTH, 20)
		item.add_child(tube_label)

		var target_pos: Vector2 = Vector2(spacing * float(i + 1), tube_y)

		## Deal анімація
		if SettingsManager.reduced_motion:
			item.position = target_pos
			item.modulate.a = 1.0
			if i == count - 1:
				_input_locked = false
				_drag.enabled = true
				_reset_idle_timer()
		else:
			item.position = Vector2(target_pos.x, vp.y + ITEM_SPAWN_Y_OFFSET)
			item.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = _create_game_tween().set_parallel(true)
			tw.tween_property(item, "position", target_pos, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
			if i == count - 1:
				tw.chain().tween_callback(func() -> void:
					_input_locked = false
					_drag.enabled = true
					_reset_idle_timer())

		_tube_color[item] = color_name
		_tube_origins[item] = target_pos
		_tube_items.append(item)
		_drag.draggable_items.append(item)
		_all_round_nodes.append(item)


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


func _on_dropped_target(item: Node2D, _target: Node2D) -> void:
	if _game_over:
		return
	var color_name: String = _tube_color.get(item, "")
	if color_name.is_empty():
		push_warning("ColorLab: dropped item has no color mapping")
		return
	_dropped_colors.append(color_name)
	_drag.draggable_items.erase(item)
	_tube_items.erase(item)
	AudioManager.play_sfx("coin")
	HapticsManager.vibrate_light()

	## Змінюємо колір котла — показуємо перший колір
	if _dropped_colors.size() == 1:
		_tint_cauldron(COLOR_VALUES.get(color_name, Color.GRAY))

	## Анімація зникнення у котел
	if SettingsManager.reduced_motion:
		item.global_position = _cauldron.global_position
		item.modulate.a = 0.0
		if _dropped_colors.size() >= 2:
			_input_locked = true
			_check_mix()
		else:
			_reset_idle_timer()
		return

	var tw: Tween = _create_game_tween().set_parallel(true)
	tw.tween_property(item, "global_position", _cauldron.global_position, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(item, "scale", Vector2(0.3, 0.3), 0.25)
	tw.tween_property(item, "modulate:a", 0.0, 0.2).set_delay(0.05)

	## Перевіряємо після другого кольору
	if _dropped_colors.size() >= 2:
		_input_locked = true
		tw.chain().tween_callback(_check_mix)
	else:
		_reset_idle_timer()


func _on_dropped_empty(item: Node2D) -> void:
	_drag.snap_back(item, _tube_origins.get(item, item.position))


## ---- Візуальні ефекти котла ----

func _tint_cauldron(color: Color) -> void:
	if not is_instance_valid(_cauldron_panel):
		push_warning("ColorLab: _cauldron_panel invalid in _tint_cauldron")
		return
	var style: StyleBoxFlat = _cauldron_panel.get_theme_stylebox("panel").duplicate()
	style.bg_color = color.lightened(0.2)
	_cauldron_panel.add_theme_stylebox_override("panel", style)


func _animate_cauldron_bubbling(color: Color) -> void:
	## Бурління котла — бульбашки міняють колір на результуючий
	for bubble: Node2D in _bubble_nodes:
		if is_instance_valid(bubble):
			bubble.modulate = color.lightened(0.3)


## ---- Перевірка суміші ----

func _check_mix() -> void:
	if _dropped_colors.size() < 2:
		push_warning("ColorLab: _check_mix called with <2 colors")
		return
	## Складаємо ключ — сортуємо кольори для правильного порядку
	var sorted: Array[String] = _dropped_colors.duplicate()
	sorted.sort()
	var key_a: String = "%s+%s" % [sorted[0], sorted[1]]
	var key_b: String = "%s+%s" % [_dropped_colors[0], _dropped_colors[1]]
	var result: String = ""
	if COLOR_MIXES.has(key_a):
		result = COLOR_MIXES[key_a]
	elif COLOR_MIXES.has(key_b):
		result = COLOR_MIXES[key_b]

	if result == _target_color:
		_handle_correct_mix()
	else:
		_handle_wrong_mix()


func _handle_correct_mix() -> void:
	_register_correct(_cauldron)
	_correct_mixes += 1

	## Показуємо результуючий колір у котлі
	var mixed_color: Color = COLOR_VALUES.get(_target_color, Color.WHITE)
	_tint_cauldron(mixed_color)
	_animate_cauldron_bubbling(mixed_color)
	VFXManager.spawn_success_ripple(_cauldron.global_position, mixed_color)

	if SettingsManager.reduced_motion:
		## Швидкий шлях без анімацій
		_heal_animal_instant()
		VFXManager.spawn_premium_celebration(_cauldron.global_position)
		var tw: Tween = _create_game_tween()
		tw.tween_interval(ANIM_FAST)
		tw.tween_callback(_advance_after_correct)
		return

	## Анімація: зілля "летить" від котла до тварини
	var potion_orb: Node2D = _create_potion_orb(mixed_color)
	if not is_instance_valid(potion_orb):
		push_warning("ColorLab: failed to create potion orb")
		_heal_animal_instant()
		_advance_after_correct()
		return
	add_child(potion_orb)
	_all_round_nodes.append(potion_orb)
	potion_orb.global_position = _cauldron.global_position

	var target_pos: Vector2 = _animal_node.global_position if is_instance_valid(_animal_node) \
		else Vector2(200, 300)

	var tw: Tween = _create_game_tween()
	tw.tween_property(potion_orb, "global_position", target_pos, 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(potion_orb, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		if is_instance_valid(potion_orb):
			_all_round_nodes.erase(potion_orb)
			potion_orb.queue_free()
		_heal_animal_animated())
	tw.tween_interval(CELEBRATION_DELAY)
	tw.tween_callback(_advance_after_correct)


func _create_potion_orb(color: Color) -> Node2D:
	## Створюємо кольорову кульку зілля
	var orb: Node2D = Node2D.new()
	var cb_pat: String = GameData.get_cb_pattern(_target_color) if SettingsManager.color_blind_mode else ""
	var dot: Control = IconDraw.color_dot_cb(30.0, color, cb_pat)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.position = Vector2(-15, -15)
	orb.add_child(dot)
	return orb


func _heal_animal_animated() -> void:
	## Тварина "зцілюється" — кольорове сяйво + відновлення кольору
	if not is_instance_valid(_animal_node):
		push_warning("ColorLab: _animal_node invalid in _heal_animal_animated")
		return
	var heal_color: Color = COLOR_VALUES.get(_target_color, Color.WHITE)
	VFXManager.spawn_premium_celebration(_animal_node.global_position, heal_color)
	VFXManager.spawn_heart_particles(_animal_node.global_position)

	if is_instance_valid(_animal_sprite):
		var tw: Tween = _create_game_tween()
		## Спалах кольору зілля
		tw.tween_property(_animal_sprite, "modulate", heal_color.lightened(0.5), 0.2)\
			.set_trans(Tween.TRANS_CUBIC)
		## Повернення до здорового стану
		tw.tween_property(_animal_sprite, "modulate", Color.WHITE, 0.4)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		## Радісний стрибок
		var orig_y: float = _animal_node.position.y
		tw.set_parallel(true)
		tw.tween_property(_animal_node, "position:y", orig_y - 20.0, 0.15)\
			.set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_animal_node, "position:y", orig_y, 0.25)\
			.set_delay(0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		## Збільшення і повернення
		tw.tween_property(_animal_node, "scale", Vector2(1.15, 1.15), 0.15)\
			.set_delay(0.2)
		tw.tween_property(_animal_node, "scale", Vector2.ONE, 0.25)\
			.set_delay(0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _heal_animal_instant() -> void:
	## Без анімації — просто повертаємо колір
	if is_instance_valid(_animal_sprite):
		_animal_sprite.modulate = Color.WHITE


func _advance_after_correct() -> void:
	_clear_round()
	_round += 1
	if _round >= TOTAL_ROUNDS:
		_finish()
	else:
		_start_round()


func _handle_wrong_mix() -> void:
	## A6: Toddler — без штрафу. A7: Preschool — лічильник помилок
	if not _is_toddler:
		_errors += 1
	_register_error(_cauldron)

	## Котел "пихає" димом
	if is_instance_valid(_cauldron):
		VFXManager.spawn_error_smoke(_cauldron.global_position)

	## Скидаємо лише пробірки — тварина і котел залишаються
	var d: float = ANIM_FAST if SettingsManager.reduced_motion else ANIM_SLOW
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_reset_tubes_only())


func _reset_tubes_only() -> void:
	## Очищаємо лише пробірки та стан драгу — котел і тварина залишаються
	for item: Node2D in _tube_items:
		if is_instance_valid(item):
			_tube_color.erase(item)
			_tube_origins.erase(item)
			_drag.draggable_items.erase(item)
			_all_round_nodes.erase(item)
			item.queue_free()
	_tube_items.clear()
	_tube_color.clear()
	_tube_origins.clear()
	_dropped_colors.clear()
	_drag.draggable_items.clear()
	_drag.clear_drag()

	## Повертаємо котел до нейтрального кольору
	_tint_cauldron(Color(0.25, 0.25, 0.3, 0.9))

	## Перегенеруємо пробірки з тим самим рецептом
	var recipe: Dictionary = _rebuild_current_recipe()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_tubes(vp, recipe.colors)


func _rebuild_current_recipe() -> Dictionary:
	## Відтворюємо поточний рецепт для retry
	var parts: PackedStringArray = _target_recipe_key.split("+")
	if parts.size() < 2:
		push_warning("ColorLab: malformed _target_recipe_key '%s'" % _target_recipe_key)
		return {"key": "red+yellow", "result": "orange", "colors": ["red", "yellow"]}
	var colors: Array[String] = [parts[0], parts[1]]
	return {"key": _target_recipe_key, "result": _target_color, "colors": colors}


## ---- Управління раундами (A9: round hygiene) ----

func _clear_round() -> void:
	## LAW 9: erase() from dict BEFORE queue_free()
	for item: Node2D in _tube_items:
		if _tube_color.has(item):
			_tube_color.erase(item)
		if _tube_origins.has(item):
			_tube_origins.erase(item)
	_tube_color.clear()
	_tube_origins.clear()
	_tube_items.clear()
	_dropped_colors.clear()
	_bubble_nodes.clear()
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_cauldron = null
	_cauldron_panel = null
	_animal_node = null
	_animal_sprite = null
	_thought_bubble = null
	_target_label = null
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	_drag.clear_drag()


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": TOTAL_ROUNDS, "earned_stars": earned,
		"correct_mixes": _correct_mixes})


## ---- Idle hint (A10: idle escalation) ----

func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over or _tube_items.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	for item: Node2D in _tube_items:
		if is_instance_valid(item):
			_pulse_node(item, 1.15)
			break
	_reset_idle_timer()
