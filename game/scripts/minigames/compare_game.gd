extends BaseMiniGame

## Голодні друзі — два тварини-друзі, у кожного тарілка з їжею.
## Дитина визначає "де більше / менше / рівно" і тапає потрібну сторону.
## Correct → тварина з БІЛЬШОЮ кількістю ДІЛИТЬСЯ з іншою (teaching sharing!).
## Toddler R1-R5: тільки "more", прості числа (1 vs 3, 2 vs 4, ...).
## Preschool: R1-R2 more, R3 less, R4 equal, R5 mixed.

const ITEM_SCENE: PackedScene = preload("res://scenes/components/counting_item.tscn")
const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 5
const ITEM_RADIUS: float = 36.0
const DEAL_STAGGER: float = 0.08
const DEAL_DURATION: float = 0.35
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0
const ANIMAL_SCALE: float = 0.22
const PLATE_RADIUS: float = 56.0
const SHARE_FLY_DURATION: float = 0.45

## Типи порівняння для скриптованого плану раундів
enum CompareType { MORE, LESS, EQUAL }

const FRUITS: Array[Dictionary] = [
	{"type": "apple", "color": Color("ff6b6b")},
	{"type": "banana", "color": Color("ffd166")},
	{"type": "orange", "color": Color("ff9f1c")},
	{"type": "grape", "color": Color("a855f7")},
	{"type": "watermelon", "color": Color("06d6a0")},
]

var _is_toddler: bool = false
var _total_rounds: int = 0
var _round: int = 0
var _start_time: float = 0.0
var _compare_type: CompareType = CompareType.MORE
var _correct_side: int = 0  ## 0=ліва, 1=права, 2=рівно

## Тварини-друзі (лівий та правий)
var _left_animal: Node2D = null
var _right_animal: Node2D = null
var _left_plate: Node2D = null
var _right_plate: Node2D = null
var _left_items: Array[Node2D] = []
var _right_items: Array[Node2D] = []
var _left_count: int = 0
var _right_count: int = 0

## Антиповтор тварин між раундами
var _used_animal_indices: Array[int] = []
var _used_fruit_idx: Array[int] = []

## UI елементи
var _vs_label: Label = null
var _left_tap: Panel = null
var _right_tap: Panel = null
var _equal_tap: Panel = null
var _idle_timer: SceneTreeTimer = null
var _narrative_label: Label = null

## Скриптований план раундів — A4: progressive difficulty
var _round_plan: Array[CompareType] = []


func _ready() -> void:
	game_id = "compare"
	_skill_id = "comparison"
	bg_theme = "meadow"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_round_plan()
	_build_hud()
	_build_narrative_label(tr("COMPARE_WHO_HAS_MORE"))
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


## A4: Скриптований план раундів — передбачуваний наратив замість рандому
func _build_round_plan() -> void:
	if _is_toddler:
		## Toddler: завжди "more" — найпростіше завдання
		_round_plan = [
			CompareType.MORE, CompareType.MORE, CompareType.MORE,
			CompareType.MORE, CompareType.MORE,
		]
	else:
		## Preschool: наратив від простого до складного
		## R1-R2: more (знайомство), R3: less (новий виклик), R4: equal (сюрприз!), R5: mixed
		_round_plan = [
			CompareType.MORE, CompareType.MORE,
			CompareType.LESS,
			CompareType.EQUAL,
			CompareType.MORE,  ## R5 — буде random в _generate_round
		]


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


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("COMPARE_TUTORIAL_TODDLER")
	return tr("COMPARE_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _correct_side == 2:
		## Equal — вказати на кнопку "="
		if is_instance_valid(_equal_tap) and _equal_tap.visible:
			return {"type": "tap", "target": _equal_tap.position + _equal_tap.size * 0.5}
		return {}
	var correct_items: Array[Node2D] = _left_items if _correct_side == 0 else _right_items
	if correct_items.is_empty():
		return {}
	return {"type": "tap", "target": correct_items[0].global_position}


func _build_hud() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_build_instruction_pill(get_tutorial_instruction())
	## VS label по центру між тваринами
	_vs_label = Label.new()
	_vs_label.text = tr("COMPARE_VS")
	_vs_label.add_theme_font_size_override("font_size", 48)
	_vs_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vs_label.position = Vector2(vp.x * 0.5 - 50, vp.y * 0.44)
	_vs_label.size = Vector2(100, 60)
	add_child(_vs_label)

	## Кнопки тапу — LAW 2: мінімум 3 вибори
	var tap_w: float = vp.x * 0.28
	var tap_h: float = 64.0
	var tap_y: float = vp.y * 0.82
	## Ліва кнопка — зелена
	_left_tap = _create_tap_button(
		Vector2(vp.x * 0.22 - tap_w * 0.5, tap_y),
		Vector2(tap_w, tap_h),
		Color("06d6a0", 0.7))
	var left_icon: Control = IconDraw.tap_finger(28.0)
	left_icon.position = Vector2((tap_w - 28.0) * 0.5, (tap_h - 28.0) * 0.5)
	_left_tap.add_child(left_icon)
	add_child(_left_tap)

	## Права кнопка — зелена
	_right_tap = _create_tap_button(
		Vector2(vp.x * 0.78 - tap_w * 0.5, tap_y),
		Vector2(tap_w, tap_h),
		Color("06d6a0", 0.7))
	var right_icon: Control = IconDraw.tap_finger(28.0)
	right_icon.position = Vector2((tap_w - 28.0) * 0.5, (tap_h - 28.0) * 0.5)
	_right_tap.add_child(right_icon)
	add_child(_right_tap)

	## Центральна кнопка "Рівно" — жовта (LAW 2: 3-й вибір)
	var eq_w: float = minf(tap_w * 0.55, vp.x * 0.18)
	_equal_tap = _create_tap_button(
		Vector2(vp.x * 0.5 - eq_w * 0.5, tap_y),
		Vector2(eq_w, tap_h),
		Color("ffd166", 0.7))
	var eq_lbl: Label = Label.new()
	eq_lbl.text = "="
	eq_lbl.add_theme_font_size_override("font_size", 32)
	eq_lbl.add_theme_color_override("font_color", Color.WHITE)
	eq_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eq_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eq_lbl.position = Vector2.ZERO
	eq_lbl.size = Vector2(eq_w, tap_h)
	_equal_tap.add_child(eq_lbl)
	add_child(_equal_tap)
	## Toddler: ховаємо кнопку "рівно" — вони не порівнюють рівність
	_equal_tap.visible = false


## Фабрика tap-кнопок — DRY для лівої/правої/рівної
func _create_tap_button(pos: Vector2, btn_size: Vector2, color: Color) -> Panel:
	var panel: Panel = Panel.new()
	panel.size = btn_size
	panel.position = pos
	panel.add_theme_stylebox_override("panel",
		GameData.candy_panel(color, 20))
	panel.material = GameData.create_premium_material(
		0.04, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
	return panel


func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	var is_tap: bool = false
	if event is InputEventMouseButton:
		is_tap = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		is_tap = event.pressed
	if not is_tap:
		return
	var pos: Vector2 = get_global_mouse_position()
	var side: int = -1
	if _left_tap and Rect2(_left_tap.position, _left_tap.size).has_point(pos):
		side = 0
	elif _right_tap and Rect2(_right_tap.position, _right_tap.size).has_point(pos):
		side = 1
	elif _equal_tap and _equal_tap.visible and Rect2(_equal_tap.position, _equal_tap.size).has_point(pos):
		side = 2
	if side == -1:
		return
	_input_locked = true
	if side == _correct_side:
		_handle_correct(side)
	else:
		_handle_wrong(side)


func _start_round() -> void:
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	## Скинути наратив на початковий текст (після "They share!" попереднього раунду)
	if is_instance_valid(_narrative_label):
		_narrative_label.text = tr("COMPARE_WHO_HAS_MORE")
	_generate_round()
	_spawn_animals_and_food()


func _generate_round() -> void:
	## Визначити тип порівняння з плану раундів
	if _round < _round_plan.size():
		_compare_type = _round_plan[_round]
	else:
		push_warning("CompareGame: round %d beyond plan, fallback to MORE" % _round)
		_compare_type = CompareType.MORE

	## Preschool R5 (останній раунд): випадковий тип — mixed challenge
	if not _is_toddler and _round == _total_rounds - 1:
		var types: Array[CompareType] = [CompareType.MORE, CompareType.LESS, CompareType.EQUAL]
		_compare_type = types[randi() % types.size()]
		## A8 guard: якщо EQUAL обрано, але кнопка недоступна — fallback
		if _compare_type == CompareType.EQUAL and (not _equal_tap or not _equal_tap.visible):
			push_warning("CompareGame: EQUAL selected but _equal_tap unavailable, fallback MORE")
			_compare_type = CompareType.MORE

	## Прогресивна складність — числа ростуть з раундами (LAW 6)
	var lo: int = 1 if _is_toddler else _scale_stepped_i(1, 2, _round, _total_rounds)
	var hi: int = _scale_stepped_i(3, 5, _round, _total_rounds) if _is_toddler \
		else _scale_stepped_i(4, 7, _round, _total_rounds)

	## Генерація кількостей за типом порівняння
	match _compare_type:
		CompareType.EQUAL:
			_left_count = randi_range(lo, hi)
			_right_count = _left_count
			_correct_side = 2
			_fade_instruction(_instruction_label, tr("COMPARE_EQUAL_OR_NOT"))
		CompareType.MORE:
			_left_count = randi_range(lo, hi)
			_right_count = randi_range(lo, hi)
			## Гарантувати нерівність
			_ensure_unequal(lo, hi)
			_correct_side = 0 if _left_count > _right_count else 1
			_fade_instruction(_instruction_label, tr("COMPARE_WHICH_MORE"))
		CompareType.LESS:
			_left_count = randi_range(lo, hi)
			_right_count = randi_range(lo, hi)
			_ensure_unequal(lo, hi)
			_correct_side = 0 if _left_count < _right_count else 1
			_fade_instruction(_instruction_label, tr("COMPARE_WHICH_FEWER"))

	## Показати/сховати кнопку "рівно"
	if _equal_tap:
		if _is_toddler:
			_equal_tap.visible = false
		else:
			## Preschool: показати з R3 (коли з'являється equal раунд)
			_equal_tap.visible = (_round >= 2)


## Гарантувати нерівність лівої та правої кількостей
func _ensure_unequal(lo: int, hi: int) -> void:
	var safety: int = 0
	while _right_count == _left_count and safety < 20:
		_right_count = randi_range(lo, hi)
		safety += 1
	if _right_count == _left_count:
		_right_count = _left_count + (1 if _left_count < hi else -1)
		push_warning("CompareGame: fallback нерівність — force different counts")


## Спавн двох тварин-друзів та їхніх тарілок з їжею
func _spawn_animals_and_food() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var left_cx: float = vp.x * 0.22
	var right_cx: float = vp.x * 0.78
	var animal_y: float = vp.y * 0.38
	var plate_y: float = vp.y * 0.58

	## Вибрати двох різних тварин
	var left_idx: int = _pick_unused_animal_idx()
	var right_idx: int = _pick_unused_animal_idx()
	## Гарантувати різних тварин (LAW 3: visual distinction)
	if right_idx == left_idx:
		var pool_size: int = GameData.ANIMALS_AND_FOOD.size()
		if pool_size > 1:
			right_idx = (left_idx + 1) % pool_size

	## Спавн лівої тварини
	_left_animal = _spawn_animal_at(left_idx, Vector2(left_cx, animal_y))
	## Спавн правої тварини
	_right_animal = _spawn_animal_at(right_idx, Vector2(right_cx, animal_y))

	## Тарілки (візуальна основа для їжі)
	_left_plate = _draw_plate(Vector2(left_cx, plate_y))
	add_child(_left_plate)
	_right_plate = _draw_plate(Vector2(right_cx, plate_y))
	add_child(_right_plate)

	## Вибір фрукта для тарілок
	var fruit_a_idx: int = _pick_unused_fruit_idx()
	var fruit: Dictionary = FRUITS[fruit_a_idx]

	## Спавн їжі на тарілки з deal анімацією
	var total_items: int = _left_count + _right_count
	var idx: int = 0
	for pos: Vector2 in _plate_positions(_left_count, Vector2(left_cx, plate_y)):
		var item: Node2D = ITEM_SCENE.instantiate()
		add_child(item)
		item.setup_with_icon(fruit.type,
			IconDraw.fruit_icon(fruit.type, ITEM_RADIUS * 1.2),
			fruit.color, ITEM_RADIUS)
		_deal_item_in(item, pos, idx, total_items)
		_left_items.append(item)
		idx += 1
	for pos: Vector2 in _plate_positions(_right_count, Vector2(right_cx, plate_y)):
		var item: Node2D = ITEM_SCENE.instantiate()
		add_child(item)
		item.setup_with_icon(fruit.type,
			IconDraw.fruit_icon(fruit.type, ITEM_RADIUS * 1.2),
			fruit.color, ITEM_RADIUS)
		_deal_item_in(item, pos, idx, total_items)
		_right_items.append(item)
		idx += 1


## Спавн тварини з GameData за індексом
func _spawn_animal_at(animal_idx: int, pos: Vector2) -> Node2D:
	var container: Node2D = Node2D.new()
	container.position = pos
	add_child(container)

	var pool_size: int = GameData.ANIMALS_AND_FOOD.size()
	if pool_size == 0:
		push_warning("CompareGame: ANIMALS_AND_FOOD порожній, fallback icon")
		var fallback: Control = IconDraw.fruit_icon("apple", 64.0)
		fallback.position = Vector2(-32, -32)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(fallback)
		return container

	var safe_idx: int = clampi(animal_idx, 0, pool_size - 1)
	var data: Dictionary = GameData.ANIMALS_AND_FOOD[safe_idx]
	if data.has("animal_scene") and data.get("animal_scene") != null:
		var sprite: Node2D = data.animal_scene.instantiate()
		sprite.scale = Vector2(ANIMAL_SCALE, ANIMAL_SCALE)
		sprite.position = Vector2.ZERO
		container.add_child(sprite)
	else:
		## LAW 7: sprite fallback
		push_warning("CompareGame: animal_scene null for idx %d, fallback icon" % safe_idx)
		var fallback: Control = IconDraw.fruit_icon("apple", 64.0)
		fallback.position = Vector2(-32, -32)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(fallback)

	## Анімація входу
	if not SettingsManager.reduced_motion:
		var target_pos: Vector2 = container.position
		container.modulate.a = 0.0
		container.position = Vector2(target_pos.x, target_pos.y + 60.0)
		var tw: Tween = _create_game_tween().set_parallel(true)
		tw.tween_property(container, "position", target_pos, 0.4)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(container, "modulate:a", 1.0, 0.3)

	return container


## Малюємо тарілку — овальний контейнер для їжі
func _draw_plate(center: Vector2) -> Node2D:
	var plate: Node2D = Node2D.new()
	plate.position = center
	## Малюємо овал через draw callback
	plate.draw.connect(func() -> void:
		## Тінь тарілки
		plate.draw_circle(Vector2(2, 4), PLATE_RADIUS + 2.0, Color(0, 0, 0, 0.12))
		## Основа тарілки — світла
		plate.draw_circle(Vector2.ZERO, PLATE_RADIUS, Color(0.95, 0.92, 0.88, 0.85))
		## Внутрішній край — трохи темніший
		plate.draw_arc(Vector2.ZERO, PLATE_RADIUS, 0.0, TAU, 48,
			Color(0.82, 0.78, 0.72, 0.6), 2.5, true)
		## Блік зверху
		plate.draw_circle(Vector2(-PLATE_RADIUS * 0.2, -PLATE_RADIUS * 0.25),
			PLATE_RADIUS * 0.35, Color(1, 1, 1, 0.25))
	)
	plate.queue_redraw()
	return plate


## Позиції їжі на тарілці — коло навколо центру
func _plate_positions(count: int, center: Vector2) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions
	if count == 1:
		positions.append(center)
		return positions
	var spread: float = PLATE_RADIUS * 0.55
	var angle_step: float = TAU / float(count)
	for i: int in range(count):
		var angle: float = angle_step * float(i) - PI * 0.5
		var jitter: Vector2 = Vector2(randf_range(-4, 4), randf_range(-4, 4))
		positions.append(center + Vector2(cos(angle), sin(angle)) * spread + jitter)
	return positions


func _handle_correct(side: int) -> void:
	## Реєстрація — SFX + VFX
	var correct_items: Array[Node2D] = _get_items_for_side(side)
	if not correct_items.is_empty():
		_register_correct(correct_items[0])
	else:
		_register_correct()

	## Celebration VFX
	var winners: Array[Node2D] = _get_items_for_side(side)
	if not winners.is_empty():
		VFXManager.spawn_premium_celebration(winners[0].global_position)
		for w: Node2D in winners:
			if is_instance_valid(w):
				VFXManager.spawn_correct_sparkle(w.global_position)

	## Happy dance для переможців
	if not SettingsManager.reduced_motion:
		for item: Node2D in winners:
			if is_instance_valid(item):
				var tw: Tween = _create_game_tween()
				tw.tween_property(item, "scale", Vector2(1.3, 1.3), 0.1)
				tw.tween_property(item, "rotation_degrees", 8.0, 0.06)
				tw.tween_property(item, "rotation_degrees", -8.0, 0.06)
				tw.tween_property(item, "rotation_degrees", 0.0, 0.06)
				tw.tween_property(item, "scale", Vector2.ONE, 0.15)\
					.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	## Анімація "ділення" — їжа летить від більшого до меншого
	var share_delay: float = 0.4 if not SettingsManager.reduced_motion else 0.1
	var delay_tw: Tween = _create_game_tween()
	delay_tw.tween_interval(share_delay)
	delay_tw.tween_callback(_animate_sharing)


## Анімація ділення -- "teaching sharing" момент.
## Фізична метафора: предмет ФІЗИЧНО летить від більшої купи до меншої.
## Обидві тварини радіють -- вчимося ділитися через gameplay.
func _animate_sharing() -> void:
	if _game_over:
		return
	## Визначити "більшу" та "меншу" сторону
	var bigger_items: Array[Node2D] = _left_items if _left_count > _right_count else _right_items
	var smaller_items: Array[Node2D] = _right_items if _left_count > _right_count else _left_items
	var bigger_animal: Node2D = _left_animal if _left_count > _right_count else _right_animal
	var smaller_animal: Node2D = _right_animal if _left_count > _right_count else _left_animal

	## Рівно -- обидва раді, без ділення
	if _left_count == _right_count:
		_animate_both_happy()
		return

	## Знайти target позицію -- до "меншої" тварини
	var target_pos: Vector2 = Vector2.ZERO
	if is_instance_valid(smaller_animal):
		target_pos = smaller_animal.position + Vector2(0, 30)
	elif not smaller_items.is_empty() and is_instance_valid(smaller_items[0]):
		target_pos = smaller_items[0].position
	else:
		_advance_round_delayed()
		return

	## Один предмет летить від більшої купи до меншої тварини
	if bigger_items.is_empty():
		_advance_round_delayed()
		return
	var shared_item: Node2D = bigger_items[-1]
	if not is_instance_valid(shared_item):
		_advance_round_delayed()
		return

	if SettingsManager.reduced_motion:
		if is_instance_valid(shared_item):
			shared_item.position = target_pos
		_show_sharing_label()
		_advance_round_delayed()
		return

	## "Дай" кивок від тварини-дарувальника перед польотом
	if is_instance_valid(bigger_animal):
		var nod_tw: Tween = _create_game_tween()
		nod_tw.tween_property(bigger_animal, "rotation", 0.08, 0.1)
		nod_tw.tween_property(bigger_animal, "rotation", 0.0, 0.1)

	## Анімація польоту
	var fly_tw: Tween = _create_game_tween()
	fly_tw.tween_property(shared_item, "position", target_pos, SHARE_FLY_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly_tw.parallel().tween_property(shared_item, "scale",
		Vector2(1.4, 1.4), SHARE_FLY_DURATION * 0.4)
	fly_tw.tween_property(shared_item, "scale", Vector2.ONE, SHARE_FLY_DURATION * 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	fly_tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_show_sharing_label()
		## Обидві тварини радіють -- вони тепер fair!
		_animate_both_happy_after_share(bigger_animal, smaller_animal)
		_advance_round_delayed()
	)


## Анімація для рівних — обидва щасливі
func _animate_both_happy() -> void:
	if not SettingsManager.reduced_motion:
		for animal: Node2D in [_left_animal, _right_animal]:
			if is_instance_valid(animal):
				var orig_y: float = animal.position.y
				var tw: Tween = _create_game_tween()
				tw.tween_property(animal, "position:y",
					orig_y - 12.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(animal, "position:y",
					orig_y, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_show_sharing_label()
	_advance_round_delayed()


## Фізична метафора: обидві тварини радіють ПІСЛЯ ділення -- вони тепер fair.
## Giver гордий, receiver вдячний -- вчимо empathy через тіло.
func _animate_both_happy_after_share(giver: Node2D, receiver: Node2D) -> void:
	if SettingsManager.reduced_motion:
		return
	## Receiver: радісний стрибок + sparkle
	if is_instance_valid(receiver):
		var recv_tw: Tween = _create_game_tween()
		var recv_y: float = receiver.position.y
		recv_tw.tween_property(receiver, "position:y",
			recv_y - 18.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		recv_tw.tween_property(receiver, "position:y",
			recv_y, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		VFXManager.spawn_heart_particles(receiver.position)
	## Giver: гордий кивок + менший стрибок (задоволений собою)
	if is_instance_valid(giver):
		var give_tw: Tween = _create_game_tween()
		var give_y: float = giver.position.y
		give_tw.tween_property(giver, "position:y",
			give_y - 10.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		give_tw.tween_property(giver, "position:y",
			give_y, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		## Squish ефект задоволення
		give_tw.tween_property(giver, "scale", Vector2(1.12, 0.92), 0.06)
		give_tw.tween_property(giver, "scale", Vector2.ONE, 0.14)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Показати "Вони діляться!" лейбл
func _show_sharing_label() -> void:
	if is_instance_valid(_narrative_label):
		if _left_count == _right_count:
			_narrative_label.text = tr("COMPARE_FRIENDS_HAPPY")
		else:
			_narrative_label.text = tr("COMPARE_SHARING")


func _advance_round_delayed() -> void:
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.6
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d)
	tw.tween_callback(_advance_round)


func _handle_wrong(side: int) -> void:
	var items: Array[Node2D] = _get_items_for_side(side)
	if _is_toddler:
		## A6: Toddler — немає покарання, м'який wobble
		_register_error(items[0] if not items.is_empty() else null)
		AudioManager.play_sfx("click")
		if not SettingsManager.reduced_motion:
			for item: Node2D in items:
				if is_instance_valid(item):
					var tw: Tween = _create_game_tween()
					tw.tween_property(item, "rotation", 0.1, 0.06)
					tw.tween_property(item, "rotation", -0.1, 0.06)
					tw.tween_property(item, "rotation", 0.0, 0.06)
		_unlock_input_delayed(0.15 if SettingsManager.reduced_motion else 0.2)
	else:
		## A7: Preschool — помилка рахується
		_errors += 1
		_register_error(items[0] if not items.is_empty() else null)
		AudioManager.play_sfx("error")
		HapticsManager.vibrate_light()
		if not items.is_empty() and is_instance_valid(items[0]):
			VFXManager.spawn_error_smoke(items[0].global_position)
		if not SettingsManager.reduced_motion:
			for item: Node2D in items:
				if is_instance_valid(item):
					var orig_x: float = item.position.x
					var tw: Tween = _create_game_tween()
					tw.tween_property(item, "position:x", orig_x - 6.0, 0.06)
					tw.tween_property(item, "position:x", orig_x + 6.0, 0.06)
					tw.tween_property(item, "position:x", orig_x - 3.0, 0.04)
					tw.tween_property(item, "position:x", orig_x, 0.04)
		_unlock_input_delayed(0.15 if SettingsManager.reduced_motion else 0.25)


## Розблокувати input після затримки
func _unlock_input_delayed(delay: float) -> void:
	var tw: Tween = _create_game_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


## Повернути items для side (0=ліва, 1=права, 2=обидві)
func _get_items_for_side(side: int) -> Array[Node2D]:
	if side == 0:
		return _left_items
	elif side == 1:
		return _right_items
	else:
		## side 2 (equal) — повертаємо всі items
		var combined: Array[Node2D] = []
		combined.append_array(_left_items)
		combined.append_array(_right_items)
		return combined


func _advance_round() -> void:
	_input_locked = true
	_clear_round()
	_round += 1
	if _round >= _total_rounds:
		_finish()
	else:
		_start_round()


## A9: Round hygiene — очистити всі тимчасові ноди
func _clear_round() -> void:
	for item: Node2D in _left_items:
		if is_instance_valid(item):
			item.queue_free()
	_left_items.clear()
	for item: Node2D in _right_items:
		if is_instance_valid(item):
			item.queue_free()
	_right_items.clear()
	if is_instance_valid(_left_animal):
		_left_animal.queue_free()
	_left_animal = null
	if is_instance_valid(_right_animal):
		_right_animal.queue_free()
	_right_animal = null
	if is_instance_valid(_left_plate):
		_left_plate.queue_free()
	_left_plate = null
	if is_instance_valid(_right_plate):
		_right_plate.queue_free()
	_right_plate = null
	_left_count = 0
	_right_count = 0


func _deal_item_in(item: Node2D, pos: Vector2, idx: int, total: int) -> void:
	if SettingsManager.reduced_motion:
		item.position = pos
		item.scale = Vector2.ONE
		item.modulate.a = 1.0
		if idx == total - 1:
			_input_locked = false
			_reset_idle_timer()
		return
	item.position = Vector2(pos.x, pos.y + 150.0)
	item.scale = Vector2(0.2, 0.2)
	item.modulate.a = 0.0
	var delay: float = float(idx) * DEAL_STAGGER
	var tw: Tween = _create_game_tween().set_parallel(true)
	tw.tween_property(item, "position", pos, DEAL_DURATION)\
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "scale", Vector2.ONE, DEAL_DURATION)\
		.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
	if idx == total - 1:
		tw.chain().tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer())


## ---- Антиповтор тварин ----


func _pick_unused_animal_idx() -> int:
	var pool_size: int = GameData.ANIMALS_AND_FOOD.size()
	if pool_size == 0:
		push_warning("CompareGame: ANIMALS_AND_FOOD порожній")
		return 0
	if _used_animal_indices.size() >= pool_size:
		_used_animal_indices.clear()
	var available: Array[int] = []
	for i: int in pool_size:
		if i not in _used_animal_indices:
			available.append(i)
	if available.is_empty():
		push_warning("CompareGame: пул тварин порожній, fallback")
		return randi() % pool_size
	available.shuffle()
	var idx: int = available[0]
	_used_animal_indices.append(idx)
	return idx


## ---- Антиповтор фруктів ----


func _pick_unused_fruit_idx() -> int:
	if _used_fruit_idx.size() >= FRUITS.size():
		_used_fruit_idx.clear()
	var available: Array[int] = []
	for i: int in FRUITS.size():
		if i not in _used_fruit_idx:
			available.append(i)
	if available.is_empty():
		push_warning("CompareGame: пул фруктів порожній, fallback")
		return randi() % FRUITS.size()
	available.shuffle()
	var idx: int = available[0]
	_used_fruit_idx.append(idx)
	return idx


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": _total_rounds, "earned_stars": earned})


func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over:
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	var correct_items: Array[Node2D] = _get_items_for_side(_correct_side)
	for item: Node2D in correct_items:
		if is_instance_valid(item):
			_pulse_node(item, 1.2)
	_reset_idle_timer()
