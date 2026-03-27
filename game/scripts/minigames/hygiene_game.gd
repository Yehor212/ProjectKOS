extends BaseMiniGame

## ECE-11 Купання! / Bath Time! — вибери інструмент і витри бруд з тваринки.
## Toddler: губка (wipe gesture), одна велика область, будь-який тип плями.
## Preschool: 3 інструменти (губка/спрей/рушник) для різних типів плям.
## Щекотливі місця → хіхікання. Холодна вода → тремтіння.
## Після очистки: before/after порівняння, ідеальний раунд → святкування.

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 4
const WIPE_RADIUS_TODDLER: float = 80.0
const WIPE_RADIUS_PRESCHOOL: float = 55.0
const SPOT_SIZE_MIN: float = 24.0
const SPOT_SIZE_MAX: float = 40.0
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0
const TICKLISH_CHANCE: float = 0.2
const COLD_REACTION_CHANCE: float = 0.25

## Типи плям — кожен має свій колір та потрібний інструмент
enum StainType { DIRT, PAINT, FOOD }
enum ToolType { SPONGE, SPRAY, TOWEL }

## Палітра кольорів для типів плям (LAW 25: не лише колір — є мітки)
const DIRT_COLORS: Array[Color] = [
	Color(0.55, 0.40, 0.25, 0.80),
	Color(0.50, 0.45, 0.30, 0.75),
	Color(0.45, 0.35, 0.20, 0.85),
]
const PAINT_COLORS: Array[Color] = [
	Color(0.30, 0.50, 0.85, 0.80),
	Color(0.85, 0.30, 0.35, 0.80),
	Color(0.30, 0.75, 0.45, 0.80),
]
const FOOD_COLORS: Array[Color] = [
	Color(0.90, 0.60, 0.20, 0.75),
	Color(0.85, 0.75, 0.25, 0.75),
	Color(0.80, 0.45, 0.20, 0.80),
]

## Маппінг стейн -> правильний інструмент
const STAIN_TOOL_MAP: Dictionary = {
	StainType.DIRT: ToolType.SPONGE,
	StainType.PAINT: ToolType.SPRAY,
	StainType.FOOD: ToolType.TOWEL,
}

## Кількість плям (min/max для прогресії)
const SPOTS_TODDLER_MIN: int = 3
const SPOTS_TODDLER_MAX: int = 5
const SPOTS_PRESCHOOL_MIN: int = 5
const SPOTS_PRESCHOOL_MAX: int = 9

const ANIMAL_NAMES: Array[String] = [
	"Bear", "Bunny", "Cat", "Chicken", "Cow", "Crocodile", "Deer",
	"Dog", "Elephant", "Frog", "Goat", "Hedgehog", "Horse",
	"Lion", "Monkey", "Mouse", "Panda", "Penguin", "Squirrel",
]

var _is_toddler: bool = false
var _round: int = 0
var _total_rounds: int = 0
var _start_time: float = 0.0
var _wiping: bool = false
var _wipe_radius: float = 80.0

var _spots: Array[Node2D] = []
var _cleaned: int = 0
var _total_spots: int = 0
var _animal_sprite: Sprite2D = null
var _progress_bar: Panel = null
var _progress_fill: Panel = null
var _all_round_nodes: Array[Node] = []
var _used_animals: Array[int] = []

var _current_round_errors: int = 0
var _idle_timer: SceneTreeTimer = null
var _sponge_cursor: Control = null
var _initial_modulate: float = 0.45

## Інструменти (Preschool)
var _selected_tool: int = ToolType.SPONGE
var _tool_buttons: Array[Button] = []
var _tool_panel: HBoxContainer = null

## Реакції тварини
var _giggle_cooldown: float = 0.0


func _ready() -> void:
	game_id = "hygiene"
	bg_theme = "ocean"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_wipe_radius = WIPE_RADIUS_TODDLER if _is_toddler else WIPE_RADIUS_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	if not _is_toddler:
		_build_tool_palette()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func _process(delta: float) -> void:
	if _giggle_cooldown > 0.0:
		_giggle_cooldown -= delta


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("HYGIENE_TUTORIAL_TODDLER")
	return tr("HYGIENE_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	for spot: Node2D in _spots:
		if is_instance_valid(spot) and not spot.get_meta("is_clean", false):
			return {"type": "tap", "target": spot.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Палітра інструментів (Preschool) ----

func _build_tool_palette() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_tool_panel = HBoxContainer.new()
	_tool_panel.set("theme_override_constants/separation", 12)
	_tool_panel.position = Vector2(vp.x * 0.5 - 150.0, vp.y - 100.0)
	_tool_panel.z_index = 5

	var tool_data: Array[Dictionary] = [
		{"type": ToolType.SPONGE, "label_key": "HYGIENE_TOOL_SPONGE", "color": Color(0.55, 0.78, 0.95)},
		{"type": ToolType.SPRAY, "label_key": "HYGIENE_TOOL_SPRAY", "color": Color(0.68, 0.85, 0.96)},
		{"type": ToolType.TOWEL, "label_key": "HYGIENE_TOOL_TOWEL", "color": Color(0.96, 0.88, 0.78)},
	]

	for td: Dictionary in tool_data:
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(90.0, 80.0)
		btn.text = tr(td.get("label_key", ""))
		btn.add_theme_font_size_override("font_size", 16)
		var tool_type: int = td.get("type", ToolType.SPONGE)
		btn.pressed.connect(_on_tool_selected.bind(tool_type))
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = td.get("color", Color.WHITE)
		sb.corner_radius_top_left = 12
		sb.corner_radius_top_right = 12
		sb.corner_radius_bottom_left = 12
		sb.corner_radius_bottom_right = 12
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		sb.content_margin_top = 6.0
		sb.content_margin_bottom = 6.0
		btn.add_theme_stylebox_override("normal", sb)
		## Grain overlay (LAW 28)
		btn.material = GameData.create_premium_material(
			0.03, 2.0, 0.0, 0.0, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
		_tool_panel.add_child(btn)
		_tool_buttons.append(btn)
		JuicyEffects.button_press_squish(btn, self)

	add_child(_tool_panel)
	## Підсвітити стартовий інструмент
	_highlight_selected_tool()


func _on_tool_selected(tool_type: int) -> void:
	if _input_locked or _game_over:
		return
	_selected_tool = tool_type
	AudioManager.play_sfx("click")
	_highlight_selected_tool()
	_update_cursor_icon()


func _highlight_selected_tool() -> void:
	for i: int in _tool_buttons.size():
		if not is_instance_valid(_tool_buttons[i]):
			continue
		var btn: Button = _tool_buttons[i]
		if i == _selected_tool:
			btn.modulate = Color.WHITE
			if not SettingsManager.reduced_motion:
				var tw: Tween = _create_game_tween()
				tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1)\
					.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(btn, "scale", Vector2.ONE, 0.08)
		else:
			btn.modulate = Color(0.7, 0.7, 0.7, 0.85)
			btn.scale = Vector2.ONE


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_cleaned = 0
	_current_round_errors = 0
	_spots.clear()
	## Прогресивна складність (LAW 6 / A4)
	_total_spots = _scale_by_round_i(
		SPOTS_TODDLER_MIN, SPOTS_TODDLER_MAX, _round, _total_rounds
	) if _is_toddler else _scale_by_round_i(
		SPOTS_PRESCHOOL_MIN, SPOTS_PRESCHOOL_MAX, _round, _total_rounds
	)
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	var animal: String = _pick_animal()
	_spawn_animal(animal)
	_spawn_spots()
	_spawn_progress_bar()
	var start_d: float = ANIM_FAST if SettingsManager.reduced_motion else ANIM_NORMAL
	var tw: Tween = _create_game_tween()
	tw.tween_interval(start_d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _pick_animal() -> String:
	if ANIMAL_NAMES.size() == 0:
		push_warning("HygieneGame: ANIMAL_NAMES порожній")
		return "Bear"
	if _used_animals.size() >= ANIMAL_NAMES.size():
		_used_animals.clear()
	var idx: int = randi() % ANIMAL_NAMES.size()
	var attempts: int = 0
	while _used_animals.has(idx) and attempts < ANIMAL_NAMES.size():
		idx = (idx + 1) % ANIMAL_NAMES.size()
		attempts += 1
	_used_animals.append(idx)
	return ANIMAL_NAMES[idx]


func _spawn_animal(animal_name: String) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if not ResourceLoader.exists(tex_path):
		push_warning("HygieneGame: Missing sprite: " + tex_path)
		## LAW 7: fallback — спробувати Bear
		tex_path = "res://assets/sprites/animals/Bear.png"
		if not ResourceLoader.exists(tex_path):
			push_warning("HygieneGame: Fallback sprite теж відсутній, skip round")
			_round += 1
			if _round >= _total_rounds:
				_finish()
			else:
				_start_round()
			return
	var tex: Texture2D = load(tex_path)
	if not tex:
		push_warning("HygieneGame: текстуру '%s' не вдалося завантажити" % tex_path)
		return
	_animal_sprite = Sprite2D.new()
	_animal_sprite.texture = tex
	## Зміщення вгору якщо preschool (місце для tool palette знизу)
	var y_offset: float = 0.42 if _is_toddler else 0.38
	_animal_sprite.position = Vector2(vp.x * 0.5, vp.y * y_offset)
	_animal_sprite.scale = Vector2(0.42, 0.42)
	## Тварина починає брудною (затемнена) — прогресивне освітлення
	_animal_sprite.modulate = Color(_initial_modulate, _initial_modulate, _initial_modulate, 1.0)
	add_child(_animal_sprite)
	_all_round_nodes.append(_animal_sprite)
	## Курсор-губка
	_sponge_cursor = IconDraw.soap(40.0)
	_sponge_cursor.visible = false
	_sponge_cursor.z_index = 10
	_sponge_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sponge_cursor)
	_all_round_nodes.append(_sponge_cursor)


func _spawn_spots() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var y_offset: float = 0.42 if _is_toddler else 0.38
	var center: Vector2 = Vector2(vp.x * 0.5, vp.y * y_offset)
	## Збільшений spread для пізніших раундів (LAW 6)
	var spread: float = _scale_by_round(80.0, 120.0, _round, _total_rounds)
	## Розподіл типів плям по раунду
	var stain_types: Array[int] = _generate_stain_types()

	for i: int in _total_spots:
		var spot: Node2D = Node2D.new()
		var angle: float = randf() * TAU
		var dist: float = randf_range(25.0, spread)
		spot.position = center + Vector2(cos(angle), sin(angle)) * dist
		add_child(spot)
		## Тип плями
		var stain_idx: int = clampi(i, 0, stain_types.size() - 1) if stain_types.size() > 0 else 0
		var stain_type: int = stain_types[stain_idx] if stain_idx < stain_types.size() else StainType.DIRT
		spot.set_meta("stain_type", stain_type)
		spot.set_meta("is_clean", false)
		## Щекотливе місце (рандом)
		spot.set_meta("ticklish", randf() < TICKLISH_CHANCE)
		## Кружечок бруду з кольором за типом
		var sz: float = randf_range(SPOT_SIZE_MIN, SPOT_SIZE_MAX)
		var panel: Panel = Panel.new()
		panel.size = Vector2(sz, sz)
		panel.position = Vector2(-sz * 0.5, -sz * 0.5)
		var spot_color: Color = _get_stain_color(stain_type)
		panel.add_theme_stylebox_override("panel",
			GameData.candy_circle(spot_color, sz * 0.5, false))
		## Grain overlay (LAW 28)
		panel.material = GameData.create_premium_material(
			0.04, 2.0, 0.0, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		GameData.add_gloss(panel, 8)
		spot.add_child(panel)
		## Маленька мітка типу плями для Preschool (LAW 25: не лише колір)
		if not _is_toddler:
			var type_label: Label = Label.new()
			type_label.text = _get_stain_emoji(stain_type)
			type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			type_label.add_theme_font_size_override("font_size", 14)
			type_label.position = Vector2(-sz * 0.3, -sz * 0.3)
			type_label.size = Vector2(sz * 0.6, sz * 0.6)
			spot.add_child(type_label)
		_spots.append(spot)
		_all_round_nodes.append(spot)
	_staggered_spawn(_spots, 0.06)


func _generate_stain_types() -> Array[int]:
	## Toddler: тільки бруд (один тип)
	## Preschool: мікс типів — гарантуємо мінімум 1 кожного типу
	var types: Array[int] = []
	if _is_toddler:
		for i: int in _total_spots:
			types.append(StainType.DIRT)
	else:
		## Гарантуємо мінімум по 1 кожного типу (якщо вистачає плям)
		var available_types: Array[int] = [StainType.DIRT, StainType.PAINT, StainType.FOOD]
		for t: int in available_types:
			if types.size() < _total_spots:
				types.append(t)
		## Решту заповнюємо рандомом
		while types.size() < _total_spots:
			types.append(available_types[randi() % available_types.size()])
		## Перемішуємо
		types.shuffle()
	return types


func _get_stain_color(stain_type: int) -> Color:
	match stain_type:
		StainType.PAINT:
			if PAINT_COLORS.size() > 0:
				return PAINT_COLORS[randi() % PAINT_COLORS.size()]
		StainType.FOOD:
			if FOOD_COLORS.size() > 0:
				return FOOD_COLORS[randi() % FOOD_COLORS.size()]
	## Default: DIRT
	if DIRT_COLORS.size() > 0:
		return DIRT_COLORS[randi() % DIRT_COLORS.size()]
	return Color(0.55, 0.40, 0.25, 0.80)


func _get_stain_emoji(stain_type: int) -> String:
	## Невеликий символ-підказка (LAW 25: color-blind accessibility)
	match stain_type:
		StainType.PAINT:
			return "~"
		StainType.FOOD:
			return "o"
	return "."


func _spawn_progress_bar() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bar_w: float = 220.0
	var bar_h: float = 16.0
	var bar_x: float = (vp.x - bar_w) * 0.5
	var bar_y: float = vp.y - 55.0 if _is_toddler else vp.y - 115.0
	## Фон прогрес-бару
	_progress_bar = Panel.new()
	_progress_bar.size = Vector2(bar_w, bar_h)
	_progress_bar.position = Vector2(bar_x, bar_y)
	_progress_bar.add_theme_stylebox_override("panel",
		GameData.candy_panel(Color(0.36, 0.42, 0.75, 0.25), 10, false))
	_progress_bar.material = GameData.create_premium_material(
		0.03, 2.0, 0.0, 0.0, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
	add_child(_progress_bar)
	_all_round_nodes.append(_progress_bar)
	## Заповнення
	_progress_fill = Panel.new()
	_progress_fill.size = Vector2(0, bar_h)
	_progress_fill.position = Vector2(bar_x, bar_y)
	_progress_fill.add_theme_stylebox_override("panel",
		GameData.candy_panel(Color("06d6a0"), 10, true))
	_progress_fill.material = GameData.create_premium_material(
		0.03, 2.0, 0.04, 0.08, 0.04, 0.03, 0.06, "", 0.0, 0.10, 0.22, 0.18)
	GameData.add_gloss(_progress_fill, 6)
	add_child(_progress_fill)
	_all_round_nodes.append(_progress_fill)


func _update_progress() -> void:
	if not is_instance_valid(_progress_fill) or not is_instance_valid(_progress_bar):
		push_warning("HygieneGame: progress bar nodes invalid")
		return
	var ratio: float = float(_cleaned) / maxf(float(_total_spots), 1.0)
	var target_w: float = _progress_bar.size.x * ratio
	if SettingsManager.reduced_motion:
		_progress_fill.size.x = target_w
	else:
		var tw: Tween = _create_game_tween()
		tw.tween_property(_progress_fill, "size:x", target_w, 0.2)


## ---- Input: витирання ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	if event is InputEventMouseButton:
		if event.pressed:
			_wiping = true
			_try_wipe(event.position)
			_move_sponge(event.position, true)
		else:
			_wiping = false
			_move_sponge(event.position, false)
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_wiping = true
			_try_wipe(event.position)
			_move_sponge(event.position, true)
		else:
			_wiping = false
			_move_sponge(event.position, false)
	elif event is InputEventMouseMotion and _wiping:
		_try_wipe(event.position)
		_move_sponge(event.position, true)
	elif event is InputEventScreenDrag and _wiping and event.index == 0:
		_try_wipe(event.position)
		_move_sponge(event.position, true)


func _move_sponge(pos: Vector2, show: bool) -> void:
	if not is_instance_valid(_sponge_cursor):
		return
	var was_hidden: bool = not _sponge_cursor.visible
	_sponge_cursor.visible = show
	_sponge_cursor.position = Vector2(pos.x - 20.0, pos.y - 44.0)
	## Bounce при першій появі
	if show and was_hidden and not SettingsManager.reduced_motion:
		_sponge_cursor.scale = Vector2(0.5, 0.5)
		var stw: Tween = _create_game_tween()
		stw.tween_property(_sponge_cursor, "scale", Vector2(1.1, 1.1), 0.1)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		stw.tween_property(_sponge_cursor, "scale", Vector2.ONE, 0.06)


func _try_wipe(pos: Vector2) -> void:
	var any_cleaned: bool = false
	for spot: Node2D in _spots:
		if not is_instance_valid(spot):
			continue
		if spot.get_meta("is_clean", false):
			continue
		if pos.distance_to(spot.global_position) < _wipe_radius:
			## Toddler: губка працює на все
			if _is_toddler:
				_clean_spot(spot)
				any_cleaned = true
			else:
				## Preschool: перевірка відповідності інструменту
				var stain_type: int = spot.get_meta("stain_type", StainType.DIRT)
				var required_tool: int = STAIN_TOOL_MAP.get(stain_type, ToolType.SPONGE)
				if _selected_tool == required_tool:
					_clean_spot(spot)
					any_cleaned = true
				else:
					## Неправильний інструмент — помилка
					_on_wrong_tool(spot)
					return
	if any_cleaned:
		_reset_idle_timer()


func _on_wrong_tool(spot: Node2D) -> void:
	_errors += 1
	_current_round_errors += 1
	_register_error(spot)
	## Підказка: показати який інструмент потрібен
	var stain_type: int = spot.get_meta("stain_type", StainType.DIRT)
	var needed_tool: int = STAIN_TOOL_MAP.get(stain_type, ToolType.SPONGE)
	_flash_tool_hint(needed_tool)


func _flash_tool_hint(tool_type: int) -> void:
	## Пульс потрібної кнопки — привернути увагу дитини (A11 scaffolding)
	if tool_type < 0 or tool_type >= _tool_buttons.size():
		push_warning("HygieneGame: tool_type %d out of range" % tool_type)
		return
	var btn: Button = _tool_buttons[tool_type]
	if not is_instance_valid(btn):
		push_warning("HygieneGame: tool button invalid")
		return
	if not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween()
		tw.tween_property(btn, "modulate", Color(1.0, 1.0, 0.5, 1.0), 0.15)
		tw.tween_property(btn, "modulate", Color.WHITE if tool_type == _selected_tool \
			else Color(0.7, 0.7, 0.7, 0.85), 0.15)
		tw.tween_property(btn, "modulate", Color(1.0, 1.0, 0.5, 1.0), 0.15)
		tw.tween_property(btn, "modulate", Color.WHITE if tool_type == _selected_tool \
			else Color(0.7, 0.7, 0.7, 0.85), 0.15)


func _clean_spot(spot: Node2D) -> void:
	spot.set_meta("is_clean", true)
	_cleaned += 1
	_register_correct()
	AudioManager.play_sfx("swipe")
	HapticsManager.vibrate_light()
	VFXManager.spawn_sparkle_pop(spot.global_position)
	## Перевірка щекотливого місця
	if spot.get_meta("ticklish", false):
		_trigger_ticklish_reaction()
	## Перевірка реакції на холод (spray на будь-яку пляму)
	if _selected_tool == ToolType.SPRAY and randf() < COLD_REACTION_CHANCE:
		_trigger_cold_reaction()
	## Анімація зникнення плями
	if SettingsManager.reduced_motion:
		spot.modulate.a = 0.0
		_update_progress()
		_brighten_animal()
		if _cleaned >= _total_spots:
			_on_round_complete()
	else:
		var tw: Tween = _create_game_tween().set_parallel(true)
		tw.tween_property(spot, "scale", Vector2(1.5, 1.5), 0.25)
		tw.tween_property(spot, "modulate:a", 0.0, 0.25)
		_update_progress()
		_brighten_animal()
		if _cleaned >= _total_spots:
			tw.chain().tween_callback(_on_round_complete)


## ---- Реакції тварини ----

func _trigger_ticklish_reaction() -> void:
	if _giggle_cooldown > 0.0:
		return
	_giggle_cooldown = 1.5
	AudioManager.play_sfx("bounce")
	if not is_instance_valid(_animal_sprite):
		return
	if SettingsManager.reduced_motion:
		return
	## Хіхікання — швидкі мікро-повороти
	var tw: Tween = _create_game_tween()
	tw.tween_property(_animal_sprite, "rotation_degrees", 3.0, 0.05)
	tw.tween_property(_animal_sprite, "rotation_degrees", -3.0, 0.05)
	tw.tween_property(_animal_sprite, "rotation_degrees", 2.0, 0.05)
	tw.tween_property(_animal_sprite, "rotation_degrees", -2.0, 0.05)
	tw.tween_property(_animal_sprite, "rotation_degrees", 0.0, 0.05)
	## Бульбашки VFX
	VFXManager.spawn_bubble_pop(_animal_sprite.global_position + Vector2(0, -40), Color("93c5fd"))


func _trigger_cold_reaction() -> void:
	if not is_instance_valid(_animal_sprite):
		return
	if SettingsManager.reduced_motion:
		return
	AudioManager.play_sfx("pop")
	## Тремтіння — горизонтальне тряс
	var orig_x: float = _animal_sprite.position.x
	var tw: Tween = _create_game_tween()
	tw.tween_property(_animal_sprite, "position:x", orig_x + 4.0, 0.03)
	tw.tween_property(_animal_sprite, "position:x", orig_x - 4.0, 0.03)
	tw.tween_property(_animal_sprite, "position:x", orig_x + 3.0, 0.03)
	tw.tween_property(_animal_sprite, "position:x", orig_x - 3.0, 0.03)
	tw.tween_property(_animal_sprite, "position:x", orig_x, 0.04)


func _brighten_animal() -> void:
	if not is_instance_valid(_animal_sprite):
		push_warning("HygieneGame: _animal_sprite invalid in _brighten_animal")
		return
	## Лінійна інтерполяція від _initial_modulate до 1.0 (LAW 13: maxf guard)
	var ratio: float = clampf(float(_cleaned) / maxf(float(_total_spots), 1.0), 0.0, 1.0)
	var brightness: float = lerpf(_initial_modulate, 1.0, ratio)
	if SettingsManager.reduced_motion:
		_animal_sprite.modulate = Color(brightness, brightness, brightness, 1.0)
	else:
		var tw: Tween = _create_game_tween()
		tw.tween_property(_animal_sprite, "modulate",
			Color(brightness, brightness, brightness, 1.0), 0.3)


func _update_cursor_icon() -> void:
	## Оновити курсор за обраним інструментом
	if not is_instance_valid(_sponge_cursor):
		return
	## Видалити старий курсор та замінити
	var old_pos: Vector2 = _sponge_cursor.position
	var old_visible: bool = _sponge_cursor.visible
	_sponge_cursor.queue_free()
	_all_round_nodes.erase(_sponge_cursor)
	match _selected_tool:
		ToolType.SPRAY:
			_sponge_cursor = IconDraw.bubble(40.0, Color("68b5e8"))
		ToolType.TOWEL:
			_sponge_cursor = _create_towel_icon(40.0)
		_:
			_sponge_cursor = IconDraw.soap(40.0)
	_sponge_cursor.visible = old_visible
	_sponge_cursor.position = old_pos
	_sponge_cursor.z_index = 10
	_sponge_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sponge_cursor)
	_all_round_nodes.append(_sponge_cursor)


func _create_towel_icon(icon_size: float) -> Control:
	## Простий рушник-іконка (прямокутник з заокругленими кутами)
	var container: Control = Control.new()
	container.custom_minimum_size = Vector2(icon_size, icon_size)
	container.size = Vector2(icon_size, icon_size)
	var panel: Panel = Panel.new()
	panel.size = Vector2(icon_size * 0.7, icon_size * 0.5)
	panel.position = Vector2(icon_size * 0.15, icon_size * 0.25)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.88, 0.78)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_color = Color(0.85, 0.75, 0.60)
	panel.add_theme_stylebox_override("panel", sb)
	container.add_child(panel)
	return container


## ---- Round management ----

func _on_round_complete() -> void:
	_input_locked = true
	_wiping = false
	## Before/After ефект — тварина "блищить"
	_play_before_after_effect()
	## Святкування
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	VFXManager.spawn_premium_celebration(vp * 0.5)
	## Ідеальний раунд (preschool без помилок) — додаткове святкування
	if not _is_toddler and _current_round_errors == 0:
		_play_perfect_round_celebration()
	## Тварина блискуче чиста — bounce
	if is_instance_valid(_animal_sprite) and not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween()
		tw.tween_property(_animal_sprite, "scale", Vector2(0.47, 0.47), 0.15)
		tw.tween_property(_animal_sprite, "scale", Vector2(0.42, 0.42), 0.15)
	var round_d: float = ANIM_FAST if SettingsManager.reduced_motion else CELEBRATION_DELAY
	var tw2: Tween = _create_game_tween()
	tw2.tween_interval(round_d)
	tw2.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round())


func _play_before_after_effect() -> void:
	## Короткий flash "before" (силует) -> "after" (чиста тварина)
	if not is_instance_valid(_animal_sprite):
		return
	if SettingsManager.reduced_motion:
		return
	## Flash ефект: тварина стає яскраво-білою на мить, потім нормальна
	var tw: Tween = _create_game_tween()
	tw.tween_property(_animal_sprite, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.15)
	tw.tween_property(_animal_sprite, "modulate", Color.WHITE, 0.3)


func _play_perfect_round_celebration() -> void:
	## Ідеальний раунд — додаткові ефекти
	if not is_instance_valid(_animal_sprite):
		return
	AudioManager.play_sfx("star")
	VFXManager.spawn_sparkle_pop(_animal_sprite.global_position)
	VFXManager.spawn_heart_particles(_animal_sprite.global_position + Vector2(0, -30))
	## "Халат" ефект — golden glow навколо тварини
	if not SettingsManager.reduced_motion:
		var glow: Panel = Panel.new()
		var glow_size: float = 120.0
		glow.size = Vector2(glow_size, glow_size)
		glow.position = _animal_sprite.position - Vector2(glow_size * 0.5, glow_size * 0.5)
		glow.add_theme_stylebox_override("panel",
			GameData.candy_circle(Color(1.0, 0.85, 0.3, 0.25), glow_size * 0.5, false))
		glow.z_index = -1
		add_child(glow)
		_all_round_nodes.append(glow)
		var tw: Tween = _create_game_tween()
		tw.tween_property(glow, "modulate:a", 0.0, 0.8)


func _clear_round() -> void:
	## A9: Round hygiene — очищення всіх тимчасових нодів
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_spots.clear()
	_animal_sprite = null
	_sponge_cursor = null
	_progress_bar = null
	_progress_fill = null
	_current_round_errors = 0
	_giggle_cooldown = 0.0


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": _total_rounds, "earned_stars": earned})


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
	if _input_locked or _game_over or _spots.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	for spot: Node2D in _spots:
		if is_instance_valid(spot) and not spot.get_meta("is_clean", false):
			_pulse_node(spot, 1.3)
			## Preschool: також підсвітити потрібний інструмент
			if not _is_toddler:
				var stain_type: int = spot.get_meta("stain_type", StainType.DIRT)
				var needed_tool: int = STAIN_TOOL_MAP.get(stain_type, ToolType.SPONGE)
				_flash_tool_hint(needed_tool)
			break
	_reset_idle_timer()
