extends BaseMiniGame

## PRE-32 Лабораторія кольорів — змішуй фарби та отримуй нові кольори!
## Дитина перетягує дві тюбики фарби у миску для змішування.

const TOTAL_ROUNDS: int = 5
const IDLE_HINT_DELAY: float = 5.0
const TUBE_WIDTH: float = 50.0
const TUBE_HEIGHT: float = 90.0
const BOWL_RADIUS: float = 70.0
const DEAL_STAGGER: float = 0.12
const DEAL_DURATION: float = 0.35
const ITEM_SPAWN_Y_OFFSET: float = 100.0
const BOWL_LABEL_OFFSET: Vector2 = Vector2(40, 35)
const TUBE_CORNER_RADIUS: float = 12.0
const SAFETY_TIMEOUT_SEC: float = 120.0

## Рецепти змішування кольорів
## Ключі відсортовані за алфавітом для коректного пошуку
const COLOR_MIXES: Dictionary = {
	## Tier 1 — базове змішування (R1-2)
	"red+yellow": "orange",
	"blue+yellow": "green",
	"blue+red": "purple",
	## Tier 2 — з білим (R3)
	"red+white": "pink",
	"white+yellow": "cream",
	"blue+white": "light_blue",
	## Tier 3 — складніше змішування (R4-5)
	"blue+orange": "brown",
	"purple+yellow": "olive",
	"green+red": "dark_brown",
}

## Кольори для відображення
const COLOR_VALUES: Dictionary = {
	"red": Color("e74c3c"),
	"yellow": Color("f1c40f"),
	"blue": Color("3498db"),
	"white": Color("ecf0f1"),
	"orange": Color("e67e22"),
	"green": Color("27ae60"),
	"purple": Color("8e44ad"),
	"pink": Color("fd79a8"),
	## Tier 2 результуючі кольори
	"cream": Color(1.0, 0.95, 0.8),
	"light_blue": Color(0.5, 0.8, 1.0),
	## Tier 3 результуючі кольори
	"brown": Color(0.55, 0.35, 0.17),
	"olive": Color(0.55, 0.55, 0.15),
	"dark_brown": Color(0.40, 0.26, 0.13),
}

## COLOR_EMOJIS видалено — замінено на IconDraw.color_dot()

var _drag: UniversalDrag = null
var _is_toddler: bool = false
var _round: int = 0
var _correct_mixes: int = 0
var _start_time: float = 0.0

var _tube_items: Array[Node2D] = []
var _bowl: Node2D = null
var _all_round_nodes: Array[Node] = []
var _tube_color: Dictionary = {}
var _tube_origins: Dictionary = {}
var _dropped_colors: Array[String] = []
var _target_color: String = ""
var _target_recipe_key: String = ""
var _used_recipes: Array[String] = []

var _target_label: Label = null
var _bowl_panel: Panel = null
var _idle_timer: SceneTreeTimer = null


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
	if _tube_items.is_empty() or not _bowl:
		return {}
	var tube: Node2D = _tube_items[0]
	return {"type": "drag", "from": tube.global_position, "to": _bowl.global_position}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_dropped_colors.clear()
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	## Обираємо рецепт
	var recipe: Dictionary = _pick_recipe()
	_target_color = recipe.result
	_target_recipe_key = recipe.key
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_target_display(vp)
	_spawn_bowl(vp)
	_spawn_tubes(vp, recipe.colors)


func _pick_recipe() -> Dictionary:
	## Tier-based progression: ранні раунди = прості рецепти (Source: research — primary→secondary→tertiary)
	var tier1: Array[String] = ["red+yellow", "blue+yellow", "blue+red"]
	var tier2: Array[String] = ["red+white", "white+yellow", "blue+white"]
	var tier3: Array[String] = ["blue+orange", "purple+yellow", "green+red"]
	var pool: Array[String] = []
	if _round < 2:
		pool = tier1
	elif _round < 4:
		pool = tier1 + tier2
	else:
		pool = tier1 + tier2 + tier3
	## Обираємо невикористаний рецепт з відповідного пулу
	var available: Array[String] = []
	for k: String in pool:
		if not _used_recipes.has(k):
			available.append(k)
	if available.is_empty():
		_used_recipes.clear()
		for k2: String in pool:
			available.append(k2)
	if available.is_empty():
		push_warning("ColorLab: немає рецептів")
		return {"key": "red+blue", "result": "purple", "colors": ["red", "blue"]}
	var chosen_key: String = available[randi() % available.size()]
	_used_recipes.append(chosen_key)
	var parts: PackedStringArray = chosen_key.split("+")
	var colors: Array[String] = [parts[0], parts[1]]
	return {"key": chosen_key, "result": COLOR_MIXES[chosen_key], "colors": colors}


func _spawn_target_display(vp: Vector2) -> void:
	## Контейнер для кольорової точки + назви кольору
	var container: HBoxContainer = HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.position = Vector2(0, vp.y * 0.17)
	container.size = Vector2(vp.x, 50)
	add_child(container)
	_all_round_nodes.append(container)
	## Кольорова точка через IconDraw (LAW 25: pattern overlay)
	var _cb_pat: String = GameData.get_cb_pattern(_target_color) if SettingsManager.color_blind_mode else ""
	var dot: Control = IconDraw.color_dot_cb(36.0, COLOR_VALUES.get(_target_color, Color.GRAY), _cb_pat)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(dot)
	## Назва кольору
	_target_label = Label.new()
	_target_label.text = "  %s" % tr("COLOR_" + _target_color.to_upper())
	_target_label.add_theme_font_size_override("font_size", 36)
	_target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(_target_label)


func _spawn_bowl(vp: Vector2) -> void:
	_bowl = Node2D.new()
	_bowl.position = Vector2(vp.x * 0.5, vp.y * 0.45)
	add_child(_bowl)
	## Миска для змішування
	_bowl_panel = Panel.new()
	_bowl_panel.size = Vector2(BOWL_RADIUS * 2, BOWL_RADIUS * 2)
	_bowl_panel.position = Vector2(-BOWL_RADIUS, -BOWL_RADIUS)
	var style: StyleBoxFlat = GameData.candy_circle(Color(0.9, 0.9, 0.9, 0.8), BOWL_RADIUS)
	style.border_color = Color("b2bec3")
	style.set_border_width_all(3)
	_bowl_panel.add_theme_stylebox_override("panel", style)
	## Premium overlay + текстура (LAW 28)
	var bowl_tex: String = "res://assets/textures/backtiles/backtile_12.png"
	_bowl_panel.material = GameData.create_premium_material(0.04, 2.0, 0.06, 0.08, 0.06, 0.05, 0.08, bowl_tex, 0.15, 0.10, 0.22, 0.18)
	_bowl.add_child(_bowl_panel)
	## HQ текстура колби замість code-drawn
	var beaker_tex_path: String = "res://assets/textures/game_icons/icon_beaker.png"
	var beaker_draw_size: Vector2 = Vector2(BOWL_LABEL_OFFSET.x * 2, BOWL_LABEL_OFFSET.y * 2)
	var beaker_icon: Control
	if ResourceLoader.exists(beaker_tex_path):
		var beaker_tex: Texture2D = load(beaker_tex_path)
		beaker_icon = Control.new()
		beaker_icon.draw.connect(func() -> void:
			beaker_icon.draw_texture_rect(beaker_tex, Rect2(Vector2.ZERO, beaker_draw_size), false)
		)
	else:
		beaker_icon = IconDraw.beaker(48.0)
	beaker_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beaker_icon.position = Vector2(-BOWL_LABEL_OFFSET.x, -BOWL_LABEL_OFFSET.y)
	beaker_icon.size = beaker_draw_size
	_bowl.add_child(beaker_icon)
	_drag.drop_targets.append(_bowl)
	_all_round_nodes.append(_bowl)


func _spawn_tubes(vp: Vector2, recipe_colors: Array[String]) -> void:
	## Тюбики: 2 правильних + прогресивні відволікачі (A1)
	## Tier 1-2: primary pool, Tier 3: + secondary для відволікачів (research: primary→secondary→tertiary)
	var all_colors: Array[String] = ["red", "yellow", "blue", "white"]
	if _round >= 4:
		all_colors.append_array(["orange", "green", "purple"])
	var tubes: Array[String] = recipe_colors.duplicate()
	var max_tubes: int = _scale_by_round_i(3, all_colors.size(), _round, TOTAL_ROUNDS)
	## Додаємо відволікачі
	for c: String in all_colors:
		if tubes.size() >= max_tubes:
			break
		if not tubes.has(c):
			tubes.append(c)
	tubes.shuffle()
	var count: int = tubes.size()
	var spacing: float = vp.x / float(count + 1)
	var tube_y: float = vp.y * 0.78
	for i: int in count:
		var color_name: String = tubes[i]
		var item: Node2D = Node2D.new()
		add_child(item)
		## Тюбик — прямокутник з закругленням
		var bg: Panel = Panel.new()
		bg.size = Vector2(TUBE_WIDTH, TUBE_HEIGHT)
		bg.position = Vector2(-TUBE_WIDTH * 0.5, -TUBE_HEIGHT * 0.5)
		bg.add_theme_stylebox_override("panel",
			GameData.candy_panel(COLOR_VALUES.get(color_name, Color.GRAY),
				int(TUBE_CORNER_RADIUS)))
		## Premium overlay + текстура тюбика (LAW 28)
		var tube_tile: String = "res://assets/textures/tiles/yellow/tile_%02d.png" % ((i % 5) + 1)
		bg.material = GameData.create_premium_material(0.05, 2.0, 0.04, 0.06, 0.04, 0.03, 0.05, tube_tile, 0.15, 0.10, 0.22, 0.18)
		item.add_child(bg)
		## Кольорова точка через IconDraw (LAW 25: pattern overlay)
		var _tube_pat: String = GameData.get_cb_pattern(color_name) if SettingsManager.color_blind_mode else ""
		var dot: Control = IconDraw.color_dot_cb(24.0, COLOR_VALUES.get(color_name, Color.GRAY), _tube_pat)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(-12.0, -12.0 + (TUBE_HEIGHT - 24.0) * 0.1)
		item.add_child(dot)
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
			var tw: Tween = create_tween().set_parallel(true)
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
	_dropped_colors.append(color_name)
	_drag.draggable_items.erase(item)
	_tube_items.erase(item)
	AudioManager.play_sfx("coin")
	HapticsManager.vibrate_light()
	## Анімація зникнення у миску
	## Змінюємо колір миски — показуємо перший колір
	if _dropped_colors.size() == 1:
		_tint_bowl(COLOR_VALUES.get(color_name, Color.GRAY))
	if SettingsManager.reduced_motion:
		item.global_position = _bowl.global_position
		item.modulate.a = 0.0
		if _dropped_colors.size() >= 2:
			_input_locked = true
			_check_mix()
		else:
			_reset_idle_timer()
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(item, "global_position", _bowl.global_position, 0.25)\
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


func _tint_bowl(color: Color) -> void:
	if _bowl_panel:
		var style: StyleBoxFlat = _bowl_panel.get_theme_stylebox("panel").duplicate()
		style.bg_color = color.lightened(0.3)
		_bowl_panel.add_theme_stylebox_override("panel", style)


func _check_mix() -> void:
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
	_register_correct(_bowl)
	_correct_mixes += 1
	## Показуємо результуючий колір
	var mixed_color: Color = COLOR_VALUES.get(_target_color, Color.WHITE)
	_tint_bowl(mixed_color)
	VFXManager.spawn_success_ripple(_bowl.global_position, mixed_color)
	VFXManager.spawn_premium_celebration(_bowl.global_position)
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.8
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


func _handle_wrong_mix() -> void:
	if _is_toddler:
		_register_error(_bowl)
	else:
		_errors += 1
		_register_error(_bowl)
	## Скидаємо раунд — спробуй ще раз
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.5
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_dropped_colors.clear()
		_start_round())


## ---- Управління раундами ----

func _clear_round() -> void:
	_tube_color.clear()
	_tube_origins.clear()
	_tube_items.clear()
	_dropped_colors.clear()
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_bowl = null
	_bowl_panel = null
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
