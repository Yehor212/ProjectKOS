extends BaseMiniGame

## PRE-40 «День Тофі» — встанови час на годиннику, щоб сцена ожила!
## Розбивка екрану: годинник ЗЛІВА + сцена-ілюстрація СПРАВА.
## Toddler: «Обери активність» — дитина бачить сцену (небо, сонце/місяць) і обирає
##   яка активність відповідає цій частині дня. Вчить часову послідовність БЕЗ
##   абстракції годинника. 3 раунди, 3 картки-варіанти (LAW 2).
## Preschool: кнопки +/- з hold-to-spin, 5 раундів (:00 → :30 → :15/:45 → 5хв).
## Наратив: "Розклад Тофі — встанови правильний час!" через tr().

## ---- Константи ----

const TODDLER_ROUNDS: int = 3
const PRESCHOOL_ROUNDS: int = 5
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0

## Геометрія годинника
const CLOCK_RADIUS_T: float = 130.0   ## Toddler — більший для drag
const CLOCK_RADIUS_P: float = 110.0   ## Preschool
const HOUR_HAND_LEN_RATIO: float = 0.52
const MINUTE_HAND_LEN_RATIO: float = 0.72
const HOUR_HAND_WIDTH: float = 7.0
const MINUTE_HAND_WIDTH: float = 4.0
const CLOCK_NUM_OFFSET: float = 22.0
const TICK_OUTER_OFFSET: float = 8.0
const TICK_INNER_OFFSET: float = 14.0

## Кольори годинника
const CLOCK_BG_COLOR: Color = Color("f8f9fa")
const CLOCK_BORDER_COLOR: Color = Color("2d3436")
const HOUR_HAND_COLOR: Color = Color("e74c3c")
const MINUTE_HAND_COLOR: Color = Color("3498db")
const MARK_COLOR: Color = Color("636e72")
const CHECK_COLOR: Color = Color("27ae60")

## Кнопки (Preschool)
const BTN_SIZE: Vector2 = Vector2(80, 60)
const HOLD_REPEAT_DELAY: float = 0.40
const HOLD_REPEAT_INTERVAL: float = 0.12  ## Швидкий spin при утриманні

## Сцена-ілюстрація
const SCENE_PANEL_W: float = 360.0
const SCENE_PANEL_H: float = 280.0
const SCENE_CORNER: int = 24
const GROUND_HEIGHT_RATIO: float = 0.2

## Toddler: картки активностей (tap-to-match)
const TODDLER_CARD_W: float = 160.0
const TODDLER_CARD_H: float = 130.0
const TODDLER_CARD_GAP: float = 24.0
const TODDLER_CARD_COUNT: int = 3  ## LAW 2: min 3 choices

## Активності: розпорядок дня Тофі (7 подій, спільні для обох режимів).
## sky_top/sky_bot — кольори неба; celestial — "sun"/"moon"; cel_y — висота світила (0=top,1=bottom).
const ACTIVITIES: Array[Dictionary] = [
	{"hour": 7,  "icon": "weather",    "label_key": "CLOCK_ACTIVITY_MORNING",
	 "sky_top": Color("ffa07a"), "sky_bot": Color("ffd4a0"),
	 "celestial": "sun", "cel_y": 0.68, "ground": Color("6db36b")},
	{"hour": 8,  "icon": "fork_knife", "label_key": "CLOCK_ACTIVITY_BREAKFAST",
	 "sky_top": Color("87ceeb"), "sky_bot": Color("b8e0f0"),
	 "celestial": "sun", "cel_y": 0.48, "ground": Color("7ec87a")},
	{"hour": 12, "icon": "basket",     "label_key": "CLOCK_ACTIVITY_LUNCH",
	 "sky_top": Color("4a90e2"), "sky_bot": Color("87ceeb"),
	 "celestial": "sun", "cel_y": 0.12, "ground": Color("5cb85c")},
	{"hour": 15, "icon": "star",       "label_key": "CLOCK_ACTIVITY_PLAY",
	 "sky_top": Color("5ba4e6"), "sky_bot": Color("a0d8f0"),
	 "celestial": "sun", "cel_y": 0.32, "ground": Color("6db36b")},
	{"hour": 18, "icon": "home",       "label_key": "CLOCK_ACTIVITY_DINNER",
	 "sky_top": Color("ff7f50"), "sky_bot": Color("ffd166"),
	 "celestial": "sun", "cel_y": 0.72, "ground": Color("5a9a58")},
	{"hour": 20, "icon": "soap",       "label_key": "CLOCK_ACTIVITY_BATH",
	 "sky_top": Color("6b5b95"), "sky_bot": Color("b8a9c9"),
	 "celestial": "moon", "cel_y": 0.30, "ground": Color("3a5a38")},
	{"hour": 21, "icon": "heart",      "label_key": "CLOCK_ACTIVITY_SLEEP",
	 "sky_top": Color("1a1a3e"), "sky_bot": Color("2d3564"),
	 "celestial": "moon", "cel_y": 0.18, "ground": Color("2a4a28")},
	## Нові активності для розширення пулу (7 → 12)
	{"hour": 9,  "icon": "pencil",     "label_key": "CLOCK_ACTIVITY_LEARNING",
	 "sky_top": Color("87ceeb"), "sky_bot": Color("b8e0f0"),
	 "celestial": "sun", "cel_y": 0.40, "ground": Color("7ec87a")},
	{"hour": 10, "icon": "cookie",     "label_key": "CLOCK_ACTIVITY_SNACK",
	 "sky_top": Color("70b8e8"), "sky_bot": Color("a8d4f0"),
	 "celestial": "sun", "cel_y": 0.30, "ground": Color("6db36b")},
	{"hour": 14, "icon": "book",       "label_key": "CLOCK_ACTIVITY_READING",
	 "sky_top": Color("5ba4e6"), "sky_bot": Color("a0d8f0"),
	 "celestial": "sun", "cel_y": 0.25, "ground": Color("5cb85c")},
	{"hour": 16, "icon": "tree",       "label_key": "CLOCK_ACTIVITY_WALK",
	 "sky_top": Color("6bacdc"), "sky_bot": Color("b0d8e8"),
	 "celestial": "sun", "cel_y": 0.50, "ground": Color("68b868")},
	{"hour": 19, "icon": "star",       "label_key": "CLOCK_ACTIVITY_FAMILY",
	 "sky_top": Color("e8856c"), "sky_bot": Color("ffc882"),
	 "celestial": "sun", "cel_y": 0.78, "ground": Color("4a8a48")},
]

## ---- Стан гри ----

var _round: int = 0
var _start_time: float = 0.0
var _is_toddler: bool = false
var _total_rounds: int = 5

## Поточна активність раунду
var _current_activity: Dictionary = {}
var _used_indices: Array[int] = []

## Час: цільовий і поточний
var _target_hour: int = 7
var _target_minute: int = 0
var _current_hour: int = 12
var _current_minute: int = 0
var _prev_drag_hour: int = -1  ## Для запобігання спаму SFX при drag

## Нодi раунду (очищуються між раундами)
var _all_round_nodes: Array[Node] = []
var _clock_face: Node2D = null
var _hour_line: Line2D = null
var _minute_line: Line2D = null
var _scene_panel: Panel = null
var _scene_overlay: ColorRect = null  ## Сірий оверлей — зникає при правильній відповіді
var _scene_icon_node: Control = null
var _activity_label: Label = null

## Drag стан (Preschool drag — збережено для сумісності, Toddler більше не використовує)
var _dragging: bool = false
var _clock_center_global: Vector2 = Vector2.ZERO
var _active_clock_radius: float = 130.0

## Toddler: картки активностей
var _toddler_cards: Array[Node2D] = []
var _toddler_correct_idx: int = -1

## Hold-to-spin стан (Preschool)
var _hold_callback: Callable = Callable()
var _hold_active: bool = false
var _hold_timer: SceneTreeTimer = null

## Tween refs
var _hour_tween: Tween = null
var _minute_tween: Tween = null

## Idle timer
var _idle_timer: SceneTreeTimer = null


## ---- Ініціалізація ----


func _ready() -> void:
	game_id = "analog_clock"
	_skill_id = "time_telling"
	bg_theme = "city"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = TODDLER_ROUNDS if _is_toddler else PRESCHOOL_ROUNDS
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("CLOCK_TODDLER_MATCH")
	return tr("TOFIE_SCHEDULE") + " " + tr("CLOCK_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	if _is_toddler:
		## Toddler: tap демо — показуємо де натиснути (правильна картка)
		if _toddler_correct_idx >= 0 and _toddler_correct_idx < _toddler_cards.size():
			var card: Node2D = _toddler_cards[_toddler_correct_idx]
			if is_instance_valid(card):
				return {"type": "tap", "target": card.global_position}
		return {}
	if not _clock_face or not is_instance_valid(_clock_face):
		return {}
	return {"type": "tap", "target": _clock_face.global_position + Vector2(0, _active_clock_radius + 40.0)}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


func _on_exit_pause() -> void:
	_stop_hold_repeat()
	_dragging = false


## ---- Input ----
## Обидва режими використовують Button.pressed:
## Toddler: tap-картки активностей; Preschool: кнопки +/- та check.
## Drag годинної стрілки видалено з Toddler (замінено на tap-to-match).


func _unhandled_input(event: InputEvent) -> void:
	super(event)


func _try_start_drag(pos: Vector2) -> void:
	if _clock_center_global == Vector2.ZERO:
		push_warning("analog_clock: drag — clock center not set")
		return
	var delta: Vector2 = pos - _clock_center_global
	## Дозволяємо drag якщо палець всередині годинника + невеликий запас
	if delta.length() > _active_clock_radius * 1.4:
		return  ## Палець за межами годинника — ігнорувати
	_dragging = true
	_prev_drag_hour = _current_hour
	_update_drag(pos)
	get_viewport().set_input_as_handled()


func _update_drag(pos: Vector2) -> void:
	if not _dragging:
		push_warning("analog_clock: _update_drag called without active drag")
		return
	var delta: Vector2 = pos - _clock_center_global
	if delta.length() < 5.0:
		return  ## Занадто близько до центру — ігноруємо (мертва зона)
	## Кут: 0 = right (3 o'clock), перетворюємо так що 12 o'clock = 0 градусів
	var angle_deg: float = rad_to_deg(atan2(delta.y, delta.x)) + 90.0
	if angle_deg < 0.0:
		angle_deg += 360.0
	## 360 градусів / 12 годин = 30 градусів на годину
	var hour_float: float = angle_deg / 30.0
	var hour: int = int(roundf(hour_float)) % 12
	if hour == 0:
		hour = 12
	_current_hour = hour
	## Тактильний клік тільки при зміні години (запобігання спаму)
	if _current_hour != _prev_drag_hour:
		AudioManager.play_sfx("click")
		HapticsManager.vibrate_light()
		_prev_drag_hour = _current_hour
	_update_hands_immediate()


func _try_end_drag() -> void:
	if not _dragging:
		return  ## Не було активного drag — нормальний стан
	_dragging = false
	if _input_locked or _game_over:
		push_warning("analog_clock: drag ended while locked/game_over")
		return
	## Перевірка відповіді після відпускання
	if _current_hour == _target_hour:
		_input_locked = true
		_handle_correct()
	else:
		_handle_wrong_toddler()


## ---- Раунди ----


func _start_round() -> void:
	_input_locked = true
	if _is_toddler:
		_start_round_toddler()
		return
	## ---- Preschool path (незмінний) ----
	_current_hour = 12
	_current_minute = 0
	_prev_drag_hour = -1
	## Обираємо активність
	_current_activity = _pick_activity()
	_target_hour = _current_activity.get("hour", 7) as int
	if _target_hour > 12:
		_target_hour -= 12  ## 12-годинний формат для годинника
	## Хвилини (Preschool: прогресивна точність)
	_target_minute = _generate_target_minute()
	## UI
	var instruction: String = tr(_current_activity.get("label_key", "") as String)
	_fade_instruction(_instruction_label, instruction)
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	## Побудова екрану
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_clock(vp)
	_spawn_scene_panel(vp)
	_spawn_buttons(vp)
	_staggered_spawn(_all_round_nodes, 0.08)
	_update_hands_immediate()
	## Затримка перед активацією вводу
	var delay: float = 0.15 if SettingsManager.reduced_motion else 0.45
	var tw: Tween = _create_game_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_input_locked = false
		_reset_idle_timer())


## ---- Toddler: «Обери активність за сценою» ----


func _start_round_toddler() -> void:
	_toddler_cards.clear()
	_toddler_correct_idx = -1
	## Обираємо правильну активність
	_current_activity = _pick_activity()
	## Обираємо 2 дистрактори (інший celestial АБО інший час доби)
	var correct_idx_in_pool: int = _used_indices[_used_indices.size() - 1] if _used_indices.size() > 0 else 0
	var distractors: Array[Dictionary] = _pick_distractors(correct_idx_in_pool, TODDLER_CARD_COUNT - 1)
	## Формуємо масив варіантів і перемішуємо
	var choices: Array[Dictionary] = [_current_activity]
	for d: Dictionary in distractors:
		choices.append(d)
	## Перемішуємо (Fisher-Yates)
	for i: int in range(choices.size() - 1, 0, -1):
		var j: int = randi_range(0, i)
		var tmp: Dictionary = choices[i]
		choices[i] = choices[j]
		choices[j] = tmp
	## Знаходимо індекс правильної відповіді після перемішування
	for i: int in choices.size():
		if choices[i].get("hour", -1) == _current_activity.get("hour", -2):
			_toddler_correct_idx = i
			break
	## UI: інструкція — «Що робить Тофі?» (без годин, без абстракцій)
	_fade_instruction(_instruction_label, tr("CLOCK_TODDLER_MATCH"))
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	## Побудова екрану: сцена зверху (по центру) + картки знизу
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_toddler_scene(vp)
	_spawn_toddler_activity_cards(vp, choices)
	_staggered_spawn(_all_round_nodes, 0.08)
	## Затримка перед активацією вводу
	var delay: float = 0.15 if SettingsManager.reduced_motion else 0.45
	var tw: Tween = _create_game_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_input_locked = false
		_reset_idle_timer())


## Обрати N дистракторів, що візуально відрізняються від правильної відповіді (LAW 3)
func _pick_distractors(correct_pool_idx: int, count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	## LAW 13: bounds guard
	if correct_pool_idx < 0 or correct_pool_idx >= ACTIVITIES.size():
		push_warning("analog_clock: distractor — invalid correct_pool_idx %d" % correct_pool_idx)
		correct_pool_idx = 0
	var correct_celestial: String = ACTIVITIES[correct_pool_idx].get("celestial", "") as String
	var correct_icon: String = ACTIVITIES[correct_pool_idx].get("icon", "") as String
	## Пріоритет: інший celestial (день vs ніч) та інша іконка
	var candidates: Array[int] = []
	for i: int in ACTIVITIES.size():
		if i == correct_pool_idx:
			continue
		var icon: String = ACTIVITIES[i].get("icon", "") as String
		if icon == correct_icon:
			continue  ## LAW 3: візуальна відмінність — не повторювати іконку
		candidates.append(i)
	## Якщо недостатньо кандидатів — послаблюємо фільтр
	if candidates.size() < count:
		push_warning("analog_clock: distractor pool too small (%d), relaxing filter" % candidates.size())
		candidates.clear()
		for i: int in ACTIVITIES.size():
			if i != correct_pool_idx:
				candidates.append(i)
	## Перемішуємо і беремо перших count
	candidates.shuffle()
	for i: int in mini(count, candidates.size()):
		result.append(ACTIVITIES[candidates[i]])
	## Fallback: якщо все ще недостатньо (LAW 7: не порожній екран)
	while result.size() < count:
		push_warning("analog_clock: not enough distractors, reusing pool")
		var fallback_idx: int = randi_range(0, ACTIVITIES.size() - 1)
		if fallback_idx != correct_pool_idx:
			result.append(ACTIVITIES[fallback_idx])
	return result


## Сцена-ілюстрація для Toddler — по центру зверху (без годинника!)
func _spawn_toddler_scene(vp: Vector2) -> void:
	var pw: float = minf(SCENE_PANEL_W * 1.2, vp.x * 0.65)
	var ph: float = minf(SCENE_PANEL_H * 0.85, vp.y * 0.48)
	var panel_x: float = (vp.x - pw) * 0.5
	var panel_y: float = vp.y * 0.08
	## Основна панель з закругленими кутами
	_scene_panel = Panel.new()
	_scene_panel.position = Vector2(panel_x, panel_y)
	_scene_panel.size = Vector2(pw, ph)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.set_corner_radius_all(SCENE_CORNER)
	panel_style.bg_color = _current_activity.get("sky_bot", Color.CORNFLOWER_BLUE) as Color
	panel_style.border_color = Color(1, 1, 1, 0.3)
	panel_style.set_border_width_all(3)
	panel_style.anti_aliasing_size = 1.5
	_scene_panel.add_theme_stylebox_override("panel", panel_style)
	_scene_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(_scene_panel)
	_all_round_nodes.append(_scene_panel)
	## Градієнт неба
	var sky_top: Color = _current_activity.get("sky_top", Color.SKY_BLUE) as Color
	var sky_bot: Color = _current_activity.get("sky_bot", Color.CORNFLOWER_BLUE) as Color
	var sky_gradient: GradientTexture2D = GradientTexture2D.new()
	var grad: Gradient = Gradient.new()
	grad.set_color(0, sky_top)
	grad.set_color(1, sky_bot)
	sky_gradient.gradient = grad
	sky_gradient.fill_from = Vector2(0, 0)
	sky_gradient.fill_to = Vector2(0, 1)
	sky_gradient.width = 4
	sky_gradient.height = 4
	var sky_rect: TextureRect = TextureRect.new()
	sky_rect.texture = sky_gradient
	sky_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky_rect.position = Vector2.ZERO
	sky_rect.size = Vector2(pw, ph * (1.0 - GROUND_HEIGHT_RATIO))
	_scene_panel.add_child(sky_rect)
	## Земля
	var ground_color: Color = _current_activity.get("ground", Color("5cb85c")) as Color
	var ground_h: float = ph * GROUND_HEIGHT_RATIO
	var ground: ColorRect = ColorRect.new()
	ground.color = ground_color
	ground.position = Vector2(0, ph - ground_h)
	ground.size = Vector2(pw, ground_h)
	_scene_panel.add_child(ground)
	## Пагорб
	var hill: ColorRect = ColorRect.new()
	hill.color = ground_color.lightened(0.15)
	hill.position = Vector2(pw * 0.2, ph - ground_h - 15)
	hill.size = Vector2(pw * 0.6, 20)
	_scene_panel.add_child(hill)
	## Небесне тіло: сонце або місяць
	var celestial_type: String = _current_activity.get("celestial", "sun") as String
	var cel_y_norm: float = _current_activity.get("cel_y", 0.3) as float
	var cel_y: float = cel_y_norm * ph * (1.0 - GROUND_HEIGHT_RATIO)
	var cel_x: float = pw * 0.75
	if celestial_type == "sun":
		_spawn_sun(Vector2(cel_x, cel_y), 34.0)
	else:
		_spawn_moon(Vector2(cel_x, cel_y), 26.0)
	## Зірки для нічних сцен
	var target_24h: int = _current_activity.get("hour", 7) as int
	if target_24h >= 20:
		_spawn_stars(pw, ph)
	## Сірий оверлей — «сцена ще не ожила» (зникає при правильній відповіді)
	_scene_overlay = ColorRect.new()
	_scene_overlay.color = Color(0.2, 0.2, 0.25, 0.45)
	_scene_overlay.position = Vector2.ZERO
	_scene_overlay.size = Vector2(pw, ph)
	_scene_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_panel.add_child(_scene_overlay)


## 3 картки активностей знизу (Toddler tap-to-match)
func _spawn_toddler_activity_cards(vp: Vector2, choices: Array[Dictionary]) -> void:
	var total_w: float = TODDLER_CARD_W * choices.size() + TODDLER_CARD_GAP * (choices.size() - 1)
	var start_x: float = (vp.x - total_w) * 0.5 + TODDLER_CARD_W * 0.5
	var card_y: float = vp.y * 0.72 + TODDLER_CARD_H * 0.5
	for i: int in choices.size():
		var activity: Dictionary = choices[i]
		var is_correct: bool = (i == _toddler_correct_idx)
		var pos_x: float = start_x + float(i) * (TODDLER_CARD_W + TODDLER_CARD_GAP)
		var card: Node2D = _spawn_single_activity_card(
			Vector2(pos_x, card_y), activity, is_correct, i)
		_toddler_cards.append(card)


## Одна картка активності: іконка + назва + невидима кнопка
func _spawn_single_activity_card(pos: Vector2, activity: Dictionary,
		is_correct: bool, card_idx: int) -> Node2D:
	var card: Node2D = Node2D.new()
	card.position = pos
	card.name = "ActivityCard_%d" % card_idx
	add_child(card)
	_all_round_nodes.append(card)
	## Панель-фон картки (candy depth, LAW 28)
	var panel: Panel = Panel.new()
	panel.size = Vector2(TODDLER_CARD_W, TODDLER_CARD_H)
	panel.position = Vector2(-TODDLER_CARD_W * 0.5, -TODDLER_CARD_H * 0.5)
	var bg_color: Color = Color(0.95, 0.95, 1.0, 0.9)
	var style: StyleBoxFlat = GameData.candy_panel(bg_color, 18)
	style.border_color = Color(0.7, 0.72, 0.8, 0.6)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	panel.material = GameData.create_premium_material(
		0.04, 2.0, 0.03, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.08, 0.18, 0.15)
	GameData.add_gloss(panel, 12)
	card.add_child(panel)
	## Іконка активності (по центру верхньої частини картки)
	var icon_id: String = activity.get("icon", "star") as String
	var icon_size: float = 48.0
	var icon_node: Control = IconDraw.game_icon(icon_id, icon_size)
	if icon_node:
		icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_node.position = Vector2(
			(TODDLER_CARD_W - icon_size) * 0.5 - TODDLER_CARD_W * 0.5,
			-TODDLER_CARD_H * 0.5 + 12.0)
		card.add_child(icon_node)
	## Назва активності (нижня частина картки, через tr() — A12)
	var label_key: String = activity.get("label_key", "") as String
	## Спрощена назва для Toddler: лише активність, без годин
	var display_text: String = _toddler_activity_name(label_key)
	var lbl: Label = Label.new()
	lbl.text = display_text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.2, 0.15, 0.35))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size = Vector2(TODDLER_CARD_W - 8, 44.0)
	lbl.position = Vector2(-TODDLER_CARD_W * 0.5 + 4, TODDLER_CARD_H * 0.5 - 50.0)
	card.add_child(lbl)
	## Невидима кнопка поверх всієї картки (tap target >= 80px, QA #9)
	var btn: Button = Button.new()
	btn.flat = true
	btn.size = Vector2(TODDLER_CARD_W, TODDLER_CARD_H)
	btn.position = Vector2(-TODDLER_CARD_W * 0.5, -TODDLER_CARD_H * 0.5)
	btn.modulate.a = 0.0
	btn.pressed.connect(_on_activity_card_tapped.bind(card_idx))
	card.add_child(btn)
	## Meta для scaffolding та перевірки
	card.set_meta("correct", is_correct)
	card.set_meta("card_idx", card_idx)
	return card


## Отримати спрощену назву активності для Toddler (без годин)
func _toddler_activity_name(label_key: String) -> String:
	## Повна локалізована назва містить годину (e.g. "Breakfast! 8 o'clock!")
	## Для Toddler повертаємо тільки назву активності через окремий ключ
	var short_key: String = label_key + "_SHORT"
	var short_text: String = tr(short_key)
	## Якщо короткий ключ існує — використовуємо його; інакше fallback на повний
	if short_text != short_key:
		return short_text
	## Fallback: повна назва (все ще через tr())
	return tr(label_key)


## ---- Toddler: обробка тапу по картці ----


func _on_activity_card_tapped(idx: int) -> void:
	if _input_locked or _game_over:
		push_warning("analog_clock: card tap ignored — input locked or game over")
		return
	if idx < 0 or idx >= _toddler_cards.size():
		push_warning("analog_clock: invalid card index %d" % idx)
		return
	var card: Node2D = _toddler_cards[idx]
	if not is_instance_valid(card):
		push_warning("analog_clock: card %d already freed" % idx)
		return
	var is_correct: bool = card.get_meta("correct", false)
	if is_correct:
		_input_locked = true
		_register_correct(card)
		## Сцена «оживає» — прибираємо оверлей
		_animate_scene_alive()
		VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
		var delay: float = 0.15 if SettingsManager.reduced_motion else 1.0
		var tw: Tween = _create_game_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(self):
				return
			_clear_round()
			_round += 1
			if _round >= _total_rounds:
				_finish()
			else:
				_start_round())
	else:
		## A6: Toddler помилка — НЕ рахуємо _errors, м'який wobble
		_register_error(card)
		_reset_idle_timer()


func _generate_target_minute() -> int:
	if _is_toddler:
		return 0
	## Preschool: прогресивна точність за раундами (A4 — difficulty ramp)
	## R0-R1: :00 | R2: :00/:30 | R3: :00/:15/:30/:45 | R4: будь-яка 5-хвилинна мітка
	if _round < 2:
		return 0
	elif _round == 2:
		return [0, 30].pick_random()
	elif _round == 3:
		return [0, 15, 30, 45].pick_random()
	else:
		return (randi_range(0, 11)) * 5


func _pick_activity() -> Dictionary:
	## Пул без повторів (A9 — round hygiene)
	if _used_indices.size() >= ACTIVITIES.size():
		_used_indices.clear()
	var available: Array[int] = []
	## Toddler: додатково фільтруємо колізії 12h-формату (8am vs 8pm)
	var used_12h_hours: Array[int] = []
	if _is_toddler:
		for ui: int in _used_indices:
			if ui >= 0 and ui < ACTIVITIES.size():
				var h: int = ACTIVITIES[ui].get("hour", 0) as int
				if h > 12:
					h -= 12
				used_12h_hours.append(h)
	for i: int in ACTIVITIES.size():
		if i in _used_indices:
			continue
		if _is_toddler:
			var h: int = ACTIVITIES[i].get("hour", 0) as int
			if h > 12:
				h -= 12
			if h in used_12h_hours:
				continue
		available.append(i)
	if available.is_empty():
		push_warning("analog_clock: activities pool empty — fallback to first")
		return ACTIVITIES[0]
	var idx: int = available.pick_random()
	_used_indices.append(idx)
	return ACTIVITIES[idx]


## ---- Годинник (ліва сторона) ----


func _spawn_clock(vp: Vector2) -> void:
	_active_clock_radius = CLOCK_RADIUS_T if _is_toddler else CLOCK_RADIUS_P
	var radius: float = _active_clock_radius
	var center: Vector2 = Vector2(vp.x * 0.25, vp.y * 0.50)
	_clock_center_global = center
	_clock_face = Node2D.new()
	_clock_face.position = center
	add_child(_clock_face)
	_all_round_nodes.append(_clock_face)
	## Фон циферблату — кругла панель з candy depth (LAW 28)
	var diameter: float = radius * 2.0
	var bg: Panel = Panel.new()
	bg.size = Vector2(diameter, diameter)
	bg.position = Vector2(-radius, -radius)
	var style: StyleBoxFlat = GameData.candy_circle(CLOCK_BG_COLOR, radius)
	style.border_color = CLOCK_BORDER_COLOR
	style.set_border_width_all(4)
	bg.add_theme_stylebox_override("panel", style)
	bg.material = GameData.create_premium_material(
		0.04, 2.0, 0.06, 0.08, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
	_clock_face.add_child(bg)
	## Числа на циферблаті
	var show_all_numbers: bool = not _is_toddler
	var numbers_to_show: Array[int] = []
	if show_all_numbers:
		for h: int in range(1, 13):
			numbers_to_show.append(h)
	else:
		## Toddler: тільки 12, 3, 6, 9 — менше візуального навантаження
		numbers_to_show = [12, 3, 6, 9]
	for h: int in numbers_to_show:
		var angle: float = deg_to_rad(float(h % 12) * 30.0 - 90.0)
		var num_r: float = radius - CLOCK_NUM_OFFSET
		var num_pos: Vector2 = Vector2(cos(angle) * num_r, sin(angle) * num_r)
		var lbl: Label = Label.new()
		lbl.text = str(h)
		lbl.add_theme_font_size_override("font_size", 24 if _is_toddler else 22)
		lbl.add_theme_color_override("font_color", MARK_COLOR)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = num_pos + Vector2(-12, -12)
		lbl.size = Vector2(24, 24)
		_clock_face.add_child(lbl)
	## Поділки на циферблаті (кожні 5 хвилин)
	for m: int in range(0, 60, 5):
		var angle: float = deg_to_rad(float(m) * 6.0 - 90.0)
		var outer_r: float = radius - TICK_OUTER_OFFSET
		var inner_r: float = radius - TICK_INNER_OFFSET
		var tick: Line2D = Line2D.new()
		tick.add_point(Vector2(cos(angle) * inner_r, sin(angle) * inner_r))
		tick.add_point(Vector2(cos(angle) * outer_r, sin(angle) * outer_r))
		tick.width = 2.0
		tick.default_color = MARK_COLOR
		_clock_face.add_child(tick)
	## Годинна стрілка
	_hour_line = Line2D.new()
	_hour_line.add_point(Vector2.ZERO)
	_hour_line.add_point(Vector2.ZERO)
	_hour_line.width = HOUR_HAND_WIDTH
	_hour_line.default_color = HOUR_HAND_COLOR
	_clock_face.add_child(_hour_line)
	## Хвилинна стрілка (тільки Preschool)
	if not _is_toddler:
		_minute_line = Line2D.new()
		_minute_line.add_point(Vector2.ZERO)
		_minute_line.add_point(Vector2.ZERO)
		_minute_line.width = MINUTE_HAND_WIDTH
		_minute_line.default_color = MINUTE_HAND_COLOR
		_clock_face.add_child(_minute_line)
	## Центральна крапка
	var dot_size: float = 12.0
	var dot: Panel = Panel.new()
	dot.size = Vector2(dot_size, dot_size)
	dot.position = Vector2(-dot_size * 0.5, -dot_size * 0.5)
	dot.add_theme_stylebox_override("panel",
		GameData.candy_circle(CLOCK_BORDER_COLOR, dot_size * 0.5, false))
	_clock_face.add_child(dot)
	## Підпис поточного часу під годинником
	var time_label: Label = Label.new()
	time_label.add_theme_font_size_override("font_size", 28)
	time_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.text = _format_time(_current_hour, _current_minute)
	time_label.position = Vector2(center.x - 60, center.y + radius + 14)
	time_label.size = Vector2(120, 40)
	time_label.name = "CurrentTimeLabel"
	add_child(time_label)
	_all_round_nodes.append(time_label)


## ---- Панель-сцена (права сторона) ----


func _spawn_scene_panel(vp: Vector2) -> void:
	var panel_x: float = vp.x * 0.52
	var panel_y: float = vp.y * 0.18
	var pw: float = minf(SCENE_PANEL_W, vp.x * 0.44)
	var ph: float = minf(SCENE_PANEL_H, vp.y * 0.65)
	## Основна панель з закругленими кутами
	_scene_panel = Panel.new()
	_scene_panel.position = Vector2(panel_x, panel_y)
	_scene_panel.size = Vector2(pw, ph)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.set_corner_radius_all(SCENE_CORNER)
	panel_style.bg_color = _current_activity.get("sky_bot", Color.CORNFLOWER_BLUE) as Color
	panel_style.border_color = Color(1, 1, 1, 0.3)
	panel_style.set_border_width_all(2)
	panel_style.anti_aliasing_size = 1.5
	_scene_panel.add_theme_stylebox_override("panel", panel_style)
	_scene_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(_scene_panel)
	_all_round_nodes.append(_scene_panel)
	## Градієнт неба — верхня частина панелі
	var sky_top: Color = _current_activity.get("sky_top", Color.SKY_BLUE) as Color
	var sky_bot: Color = _current_activity.get("sky_bot", Color.CORNFLOWER_BLUE) as Color
	var sky_gradient: GradientTexture2D = GradientTexture2D.new()
	var grad: Gradient = Gradient.new()
	grad.set_color(0, sky_top)
	grad.set_color(1, sky_bot)
	sky_gradient.gradient = grad
	sky_gradient.fill_from = Vector2(0, 0)
	sky_gradient.fill_to = Vector2(0, 1)
	sky_gradient.width = 4
	sky_gradient.height = 4
	var sky_rect: TextureRect = TextureRect.new()
	sky_rect.texture = sky_gradient
	sky_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky_rect.position = Vector2.ZERO
	sky_rect.size = Vector2(pw, ph * (1.0 - GROUND_HEIGHT_RATIO))
	_scene_panel.add_child(sky_rect)
	## Земля — нижня смуга
	var ground_color: Color = _current_activity.get("ground", Color("5cb85c")) as Color
	var ground_h: float = ph * GROUND_HEIGHT_RATIO
	var ground: ColorRect = ColorRect.new()
	ground.color = ground_color
	ground.position = Vector2(0, ph - ground_h)
	ground.size = Vector2(pw, ground_h)
	_scene_panel.add_child(ground)
	## Пагорб — м'яка хвиля між небом і землею
	var hill: ColorRect = ColorRect.new()
	hill.color = ground_color.lightened(0.15)
	hill.position = Vector2(pw * 0.2, ph - ground_h - 15)
	hill.size = Vector2(pw * 0.6, 20)
	_scene_panel.add_child(hill)
	## Небесне тіло: сонце або місяць
	var celestial_type: String = _current_activity.get("celestial", "sun") as String
	var cel_y_norm: float = _current_activity.get("cel_y", 0.3) as float
	var cel_y: float = cel_y_norm * ph * (1.0 - GROUND_HEIGHT_RATIO)
	var cel_x: float = pw * 0.75
	if celestial_type == "sun":
		_spawn_sun(Vector2(cel_x, cel_y), 30.0)
	else:
		_spawn_moon(Vector2(cel_x, cel_y), 22.0)
	## Зірки для нічних сцен (20:00+)
	var target_24h: int = _current_activity.get("hour", 7) as int
	if target_24h >= 20:
		_spawn_stars(pw, ph)
	## Іконка активності — по центру сцени
	var icon_id: String = _current_activity.get("icon", "star") as String
	var icon_size: float = 56.0
	_scene_icon_node = IconDraw.game_icon(icon_id, icon_size)
	if _scene_icon_node:
		_scene_icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scene_icon_node.position = Vector2(
			(pw - icon_size) * 0.5,
			(ph - ground_h - icon_size) * 0.55)
		_scene_panel.add_child(_scene_icon_node)
	## Назва активності під панеллю
	_activity_label = Label.new()
	_activity_label.text = tr(_current_activity.get("label_key", "") as String)
	_activity_label.add_theme_font_size_override("font_size", 26)
	_activity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_activity_label.position = Vector2(panel_x, panel_y + ph + 8)
	_activity_label.size = Vector2(pw, 36)
	add_child(_activity_label)
	_all_round_nodes.append(_activity_label)
	## Сірий оверлей поверх сцени — "сцена ще не ожила"
	_scene_overlay = ColorRect.new()
	_scene_overlay.color = Color(0.2, 0.2, 0.25, 0.45)
	_scene_overlay.position = Vector2.ZERO
	_scene_overlay.size = Vector2(pw, ph)
	_scene_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_panel.add_child(_scene_overlay)


## Сонце — кругла жовта панель з промінням
func _spawn_sun(pos: Vector2, size: float) -> void:
	if not is_instance_valid(_scene_panel):
		push_warning("analog_clock: _spawn_sun — scene panel invalid")
		return
	var sun: Control = IconDraw.sun_icon(size, Color("FFD166"))
	if sun:
		sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sun.position = pos - Vector2(size * 0.5, size * 0.5)
		_scene_panel.add_child(sun)


## Місяць — жовтий напівмісяць (використовуємо IconDraw fallback)
func _spawn_moon(pos: Vector2, size: float) -> void:
	if not is_instance_valid(_scene_panel):
		push_warning("analog_clock: _spawn_moon — scene panel invalid")
		return
	## Місяць: малюємо як Control з custom draw
	var moon: Control = Control.new()
	moon.custom_minimum_size = Vector2(size, size)
	moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moon.position = pos - Vector2(size * 0.5, size * 0.5)
	var captured_size: float = size
	moon.draw.connect(func() -> void:
		## Повне коло — жовте
		var center: Vector2 = Vector2(captured_size * 0.5, captured_size * 0.5)
		var r: float = captured_size * 0.45
		moon.draw_circle(center, r, Color("f0e68c"))
		## Вирізка — зміщене темне коло для ефекту напівмісяця
		moon.draw_circle(center + Vector2(r * 0.4, -r * 0.1), r * 0.85,
			Color("1a1a3e"))
	)
	_scene_panel.add_child(moon)


## Зірки — маленькі точки у верхній частині неба
func _spawn_stars(pw: float, ph: float) -> void:
	if not is_instance_valid(_scene_panel):
		push_warning("analog_clock: _spawn_stars — scene panel invalid")
		return
	var star_count: int = 12
	var sky_h: float = ph * (1.0 - GROUND_HEIGHT_RATIO) - 10.0
	for i: int in star_count:
		var sx: float = randf_range(15.0, pw - 15.0)
		var sy: float = randf_range(8.0, sky_h)
		var star_dot: ColorRect = ColorRect.new()
		var star_size: float = randf_range(2.0, 4.0)
		star_dot.size = Vector2(star_size, star_size)
		star_dot.position = Vector2(sx, sy)
		star_dot.color = Color(1, 1, 0.85, randf_range(0.5, 0.9))
		star_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scene_panel.add_child(star_dot)


## ---- Кнопки (Preschool) ----


func _spawn_buttons(vp: Vector2) -> void:
	var clock_center_x: float = vp.x * 0.25
	var btn_y: float = vp.y * 0.50 + _active_clock_radius + 50.0
	var gap: float = 75.0
	## Кнопки годин (ліворуч від годинника)
	var hour_x: float = clock_center_x - gap
	var h_plus: Callable = func() -> void: _adjust_hour(1)
	var h_minus: Callable = func() -> void: _adjust_hour(-1)
	_create_ctrl_button(tr("CLOCK_PLUS_HOUR"),
		Vector2(hour_x - BTN_SIZE.x * 0.5, btn_y), HOUR_HAND_COLOR, h_plus, h_plus)
	_create_ctrl_button(tr("CLOCK_MINUS_HOUR"),
		Vector2(hour_x - BTN_SIZE.x * 0.5, btn_y + BTN_SIZE.y + 6),
		HOUR_HAND_COLOR.darkened(0.15), h_minus, h_minus)
	## Кнопки хвилин (праворуч від годинника)
	var min_x: float = clock_center_x + gap
	var m_plus: Callable = func() -> void: _adjust_minute(5)
	var m_minus: Callable = func() -> void: _adjust_minute(-5)
	_create_ctrl_button(tr("CLOCK_PLUS_MIN"),
		Vector2(min_x - BTN_SIZE.x * 0.5, btn_y), MINUTE_HAND_COLOR, m_plus, m_plus)
	_create_ctrl_button(tr("CLOCK_MINUS_MIN"),
		Vector2(min_x - BTN_SIZE.x * 0.5, btn_y + BTN_SIZE.y + 6),
		MINUTE_HAND_COLOR.darkened(0.15), m_minus, m_minus)
	## Кнопка перевірки (по центру під годинником)
	var check_btn: Button = _create_ctrl_button("",
		Vector2(clock_center_x - BTN_SIZE.x * 0.5, btn_y + (BTN_SIZE.y + 6) * 0.5),
		CHECK_COLOR, _check_answer)
	IconDraw.icon_in_button(check_btn, IconDraw.checkmark(22.0))


func _create_ctrl_button(text: String, pos: Vector2, color: Color,
		callback: Callable, hold_cb: Callable = Callable()) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = BTN_SIZE
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_stylebox_override("normal",
		ThemeManager.make_soft_style(color, color.darkened(0.2), 16, false))
	btn.add_theme_stylebox_override("hover",
		ThemeManager.make_soft_style(color.lightened(0.05), color.darkened(0.15), 16, false))
	btn.add_theme_stylebox_override("pressed",
		ThemeManager.make_soft_style(color, color.darkened(0.2), 16, true))
	btn.material = GameData.create_premium_material(
		0.04, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(func() -> void:
		if not _input_locked and not _game_over:
			callback.call())
	## Hold-to-spin: авто-повтор при утриманні
	if hold_cb.is_valid():
		btn.button_down.connect(func() -> void:
			_start_hold_repeat(hold_cb))
		btn.button_up.connect(_stop_hold_repeat)
	add_child(btn)
	JuicyEffects.button_press_squish(btn, self)
	_all_round_nodes.append(btn)
	return btn


## ---- Керування часом (Preschool) ----


func _adjust_hour(delta: int) -> void:
	_current_hour += delta
	if _current_hour > 12:
		_current_hour = 1
	elif _current_hour < 1:
		_current_hour = 12
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	_update_hands_animated()
	_reset_idle_timer()


func _adjust_minute(delta: int) -> void:
	_current_minute += delta
	if _current_minute >= 60:
		_current_minute = 0
	elif _current_minute < 0:
		_current_minute = 55
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	_update_hands_animated()
	_reset_idle_timer()


## ---- Hold-to-spin ----


func _start_hold_repeat(cb: Callable) -> void:
	_hold_active = true
	_hold_callback = cb
	_hold_timer = get_tree().create_timer(HOLD_REPEAT_DELAY)
	_hold_timer.timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		_hold_repeat_tick())


func _hold_repeat_tick() -> void:
	if not _hold_active or _input_locked or _game_over:
		_stop_hold_repeat()
		return  ## Hold перервано — стан змінився
	if _hold_callback.is_valid():
		_hold_callback.call()
	_hold_timer = get_tree().create_timer(HOLD_REPEAT_INTERVAL)
	_hold_timer.timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		_hold_repeat_tick())


func _stop_hold_repeat() -> void:
	_hold_active = false
	_hold_callback = Callable()


## ---- Відображення стрілок ----


## Миттєве оновлення (для drag) — без tween анімації
func _update_hands_immediate() -> void:
	var radius: float = _active_clock_radius
	if is_instance_valid(_hour_line):
		var h_len: float = radius * HOUR_HAND_LEN_RATIO
		var h_angle: float = deg_to_rad(
			float(_current_hour % 12) * 30.0 + float(_current_minute) * 0.5 - 90.0)
		_hour_line.set_point_position(1,
			Vector2(cos(h_angle) * h_len, sin(h_angle) * h_len))
	if is_instance_valid(_minute_line):
		var m_len: float = radius * MINUTE_HAND_LEN_RATIO
		var m_angle: float = deg_to_rad(float(_current_minute) * 6.0 - 90.0)
		_minute_line.set_point_position(1,
			Vector2(cos(m_angle) * m_len, sin(m_angle) * m_len))
	_update_time_label()


## Анімоване оновлення (для кнопок) — плавне переміщення стрілок
func _update_hands_animated() -> void:
	var radius: float = _active_clock_radius
	if SettingsManager.reduced_motion:
		_update_hands_immediate()
		return  ## Reduced motion — без анімації стрілок
	## Годинна стрілка
	if is_instance_valid(_hour_line):
		var h_len: float = radius * HOUR_HAND_LEN_RATIO
		var h_angle: float = deg_to_rad(
			float(_current_hour % 12) * 30.0 + float(_current_minute) * 0.5 - 90.0)
		var h_target: Vector2 = Vector2(cos(h_angle) * h_len, sin(h_angle) * h_len)
		if _hour_tween and _hour_tween.is_valid():
			_hour_tween.kill()
		var h_from: Vector2 = _hour_line.get_point_position(1)
		_hour_tween = _create_game_tween()
		_hour_tween.tween_method(_set_hour_pos, h_from, h_target, 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	## Хвилинна стрілка
	if is_instance_valid(_minute_line):
		var m_len: float = radius * MINUTE_HAND_LEN_RATIO
		var m_angle: float = deg_to_rad(float(_current_minute) * 6.0 - 90.0)
		var m_target: Vector2 = Vector2(cos(m_angle) * m_len, sin(m_angle) * m_len)
		if _minute_tween and _minute_tween.is_valid():
			_minute_tween.kill()
		var m_from: Vector2 = _minute_line.get_point_position(1)
		_minute_tween = _create_game_tween()
		_minute_tween.tween_method(_set_minute_pos, m_from, m_target, 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_time_label()


func _set_hour_pos(v: Vector2) -> void:
	if is_instance_valid(_hour_line):
		_hour_line.set_point_position(1, v)


func _set_minute_pos(v: Vector2) -> void:
	if is_instance_valid(_minute_line):
		_minute_line.set_point_position(1, v)


func _update_time_label() -> void:
	var lbl: Label = get_node_or_null("CurrentTimeLabel") as Label
	if is_instance_valid(lbl):
		lbl.text = _format_time(_current_hour, _current_minute)


func _format_time(hour: int, minute: int) -> String:
	return "%d:%02d" % [hour, minute]


## ---- Перевірка відповіді ----


func _check_answer() -> void:
	if _input_locked or _game_over:
		push_warning("analog_clock: _check_answer ignored — locked/game_over")
		return
	_input_locked = true
	var hour_ok: bool = (_current_hour == _target_hour)
	var minute_ok: bool = (_current_minute == _target_minute)
	if hour_ok and minute_ok:
		_handle_correct()
	else:
		_handle_wrong()


func _handle_correct() -> void:
	_stop_hold_repeat()
	_dragging = false
	## Реєстрація правильної відповіді (SFX, VFX, streak)
	if is_instance_valid(_clock_face):
		_register_correct(_clock_face)
	else:
		_register_correct()
	## Сцена оживає: прибираємо сірий оверлей
	_animate_scene_alive()
	## Святкування
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var delay: float = 0.15 if SettingsManager.reduced_motion else 1.0
	var tw: Tween = _create_game_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_clear_round()
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round())


## Preschool помилка — рахуємо (A7)
func _handle_wrong() -> void:
	_stop_hold_repeat()
	_errors += 1
	if is_instance_valid(_clock_face):
		_register_error(_clock_face)
	else:
		_register_error()
	var unlock_delay: float = 0.15 if SettingsManager.reduced_motion else 0.3
	var tw: Tween = _create_game_tween()
	tw.tween_interval(unlock_delay)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_input_locked = false
		_reset_idle_timer())


## Toddler помилка — НЕ рахуємо (A6), м'який зворотний зв'язок
func _handle_wrong_toddler() -> void:
	## A6: no penalty — використовуємо _register_error для scaffolding, але _errors не інкрементуємо
	if is_instance_valid(_clock_face):
		_register_error(_clock_face)
	else:
		_register_error()
	_reset_idle_timer()


## ---- Анімація «сцена оживає» ----


func _animate_scene_alive() -> void:
	## Прибираємо сірий оверлей — сцена стає яскравою
	if is_instance_valid(_scene_overlay):
		if SettingsManager.reduced_motion:
			_scene_overlay.color.a = 0.0
		else:
			var tw: Tween = _create_game_tween()
			tw.tween_property(_scene_overlay, "color:a", 0.0, 0.4)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	## Bounce іконки активності
	if is_instance_valid(_scene_icon_node) and not SettingsManager.reduced_motion:
		var orig_scale: Vector2 = _scene_icon_node.scale
		var tw2: Tween = _create_game_tween()
		tw2.tween_property(_scene_icon_node, "scale", orig_scale * 1.4, 0.15)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(_scene_icon_node, "scale", orig_scale, 0.2)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## Sparkle на панелі сцени
	if is_instance_valid(_scene_panel):
		var panel_center: Vector2 = _scene_panel.global_position + _scene_panel.size * 0.5
		VFXManager.spawn_correct_sparkle(panel_center)


## ---- Управління раундами ----


func _clear_round() -> void:
	_stop_hold_repeat()
	_dragging = false
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_clock_face = null
	_hour_line = null
	_minute_line = null
	_scene_panel = null
	_scene_overlay = null
	_scene_icon_node = null
	_activity_label = null
	## Toddler card state (A9: round hygiene)
	_toddler_cards.clear()
	_toddler_correct_idx = -1


func _finish() -> void:
	_game_over = true
	_input_locked = true
	_dragging = false
	_stop_hold_repeat()
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": _total_rounds,
		"earned_stars": earned,
	})


## ---- Idle hint (A10: ескалація) ----


func _reset_idle_timer() -> void:
	if _game_over:
		push_warning("analog_clock: idle timer reset ignored — game over")
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over:
		push_warning("analog_clock: idle hint skipped — locked/game_over")
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		## Tutorial hand через base (A10 level 2+)
		_reset_idle_timer()
		return
	## Пульсуємо: Toddler — правильну картку, Preschool — годинник (A10 level 0-1)
	if _is_toddler:
		if _toddler_correct_idx >= 0 and _toddler_correct_idx < _toddler_cards.size():
			var hint_card: Node2D = _toddler_cards[_toddler_correct_idx]
			if is_instance_valid(hint_card):
				_pulse_node(hint_card, 1.08)
	elif is_instance_valid(_clock_face):
		_pulse_node(_clock_face, 1.08)
	_reset_idle_timer()
