extends BaseMiniGame

## Фруктовий ринок Тофі — наративна лічба!
## Тварина-покупець приходить і показує в thought bubble скільки фруктів хоче.
## Toddler: перетягни N фруктів у кошик тварини. Кожен фрукт — ascending pitch "plop".
## Preschool: тварина показує рівняння візуально, дитина обирає правильну відповідь.

const ITEM_SCENE: PackedScene = preload("res://scenes/components/counting_item.tscn")
const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 5
const ITEM_RADIUS: float = 55.0
const ANSWER_RADIUS: float = 65.0
const TAP_RADIUS: float = 75.0
const DEAL_STAGGER: float = 0.1
const DEAL_DURATION: float = 0.4
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0
## Піджет/Каван: прогресивні дистрактори замість фіксованих 3.
const TODDLER_DISTRACTORS_MIN: int = 0
const TODDLER_DISTRACTORS_MAX: int = 3
const ANSWER_COLORS: Array[Color] = [Color("ff6b6b"), Color("3b82f6"), Color("22c55e")]
## Ascending pitch для plop при кожному правильному фрукті — мюзикальна сходинка
const PLOP_BASE_PITCH: float = 0.8
const PLOP_PITCH_STEP: float = 0.12
## Анімація тварини
const ANIMAL_SCALE: float = 0.25
const ANIMAL_HAPPY_BOUNCE: float = 20.0
const THOUGHT_BUBBLE_RADIUS: float = 40.0
## Фізична метафора: живіт росте при кожному зібраному фрукті
const BELLY_SCALE_STEP: float = 0.03
const BELLY_MAX_EXTRA: float = 0.25
const BELLY_SETTLE_DURATION: float = 0.4
const BELLY_WOBBLE_ANGLE: float = 0.06

const FRUITS: Array[Dictionary] = [
	{"type": "apple", "color": Color("ff6b6b")},
	{"type": "banana", "color": Color("ffd166")},
	{"type": "orange", "color": Color("ff9f1c")},
	{"type": "grape", "color": Color("a855f7")},
	{"type": "watermelon", "color": Color("06d6a0")},
]

## Difficulty ramp config — QUALITATIVE зміни за раундом
## R1: count to 2, один вид фруктів
## R2: count to 3, з'являються distractor фрукти іншого кольору
## R3: count to 4, два види фруктів, потрібен конкретний
## R4: count to 5, 3 дистрактори
## R5: count to 6 (Preschool), фрукти частково сховані за кошиком
const ROUND_CONFIG: Array[Dictionary] = [
	{"min_count": 2, "max_count": 2, "distractor_types": 0, "fruit_types": 1},
	{"min_count": 3, "max_count": 3, "distractor_types": 1, "fruit_types": 1},
	{"min_count": 3, "max_count": 4, "distractor_types": 1, "fruit_types": 2},
	{"min_count": 4, "max_count": 5, "distractor_types": 2, "fruit_types": 2},
	{"min_count": 5, "max_count": 6, "distractor_types": 3, "fruit_types": 2},
]

var _is_toddler_mode: bool = false
var _total_rounds: int = 0
var _round: int = 0
var _start_time: float = 0.0

## Toddler
var _drag: UniversalDrag = null
var _items: Array[Node2D] = []
var _basket: Node2D = null
var _target_count: int = 0
var _current_count: int = 0
var _target_fruit: Dictionary = {}
var _origins: Dictionary = {}

## Preschool
var _answer_nodes: Array[Node2D] = []
var _correct_answer: int = 0

## Тварина-покупець
var _buyer_node: Node2D = null
var _buyer_sprite: Node2D = null
var _thought_bubble: Node2D = null
var _used_animal_indices: Array[int] = []

## Антиповтор фруктів
var _used_fruit_idx: Array[int] = []

## UI
var _counter_label: Label = null
var _equation_label: Label = null
var _idle_timer: SceneTreeTimer = null
var _count_dots: Array[Panel] = []
var _round_errors_local: int = 0
## Ринковий прилавок — фонова декорація
var _market_stall: Node2D = null


func _ready() -> void:
	game_id = "counting"
	_skill_id = "counting"
	bg_theme = "city"  ## Фруктовий ринок = міська тема
	super()
	_is_toddler_mode = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler_mode else ROUNDS_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_market_stall()
	if _is_toddler_mode:
		_drag = UniversalDrag.new(self)
		_drag.snap_radius_override = TODDLER_SNAP_RADIUS
		_drag.item_dropped_on_target.connect(_on_dropped_on_target)
		_drag.item_dropped_on_empty.connect(_on_dropped_on_empty)
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## Ринковий прилавок: дерев'яний прилавок + смугастий тент (awning).
## Робить counting_game візуально схожим на РИНОК, а не просто "фрукти на фоні".
func _build_market_stall() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_market_stall = Node2D.new()
	_market_stall.z_index = -1  ## За ігровими елементами
	add_child(_market_stall)
	## 1) Дерев'яний прилавок (нижня третина) — коричнева панель
	var counter: Panel = Panel.new()
	var counter_y: float = vp.y * 0.88
	var counter_h: float = vp.y * 0.12
	counter.position = Vector2(vp.x * 0.08, counter_y)
	counter.size = Vector2(vp.x * 0.84, counter_h)
	var counter_style: StyleBoxFlat = StyleBoxFlat.new()
	counter_style.bg_color = Color("8d6e63", 0.75)
	counter_style.corner_radius_top_left = 10
	counter_style.corner_radius_top_right = 10
	counter_style.corner_radius_bottom_left = 6
	counter_style.corner_radius_bottom_right = 6
	counter_style.border_color = Color("6d4c41", 0.6)
	counter_style.set_border_width_all(2)
	counter_style.border_width_top = 4
	counter_style.shadow_color = Color(0, 0, 0, 0.15)
	counter_style.shadow_size = 6
	counter_style.shadow_offset = Vector2(0, 3)
	counter.add_theme_stylebox_override("panel", counter_style)
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_market_stall.add_child(counter)
	## Дерев'яна текстура — горизонтальні смуги ("дошки")
	var planks: Control = Control.new()
	planks.position = Vector2(4, 6)
	planks.size = Vector2(vp.x * 0.84 - 8.0, counter_h - 10.0)
	planks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	planks.draw.connect(func() -> void:
		var plank_h: float = (counter_h - 10.0) / 3.0
		for pi: int in 3:
			var py: float = float(pi) * plank_h
			## Чергуємо два відтінки дерева
			var plank_color: Color = Color("a1887f", 0.25) if pi % 2 == 0 \
				else Color("8d6e63", 0.15)
			planks.draw_rect(Rect2(0, py, planks.size.x, plank_h - 1.0), plank_color)
	)
	counter.add_child(planks)
	## 2) Смугастий тент (awning) — над областю фруктів
	var awning: Control = Control.new()
	var awning_x: float = vp.x * 0.08
	var awning_y: float = vp.y * 0.48
	var awning_w: float = vp.x * 0.84
	var awning_h: float = 36.0
	awning.position = Vector2(awning_x, awning_y)
	awning.size = Vector2(awning_w, awning_h)
	awning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	awning.draw.connect(func() -> void:
		## Основа тенту
		awning.draw_rect(Rect2(0, 0, awning_w, awning_h),
			Color("ef5350", 0.55))
		## Білі смуги (чергування червоний/білий)
		var stripe_w: float = 28.0
		var stripe_count: int = int(awning_w / stripe_w) + 1
		for si: int in stripe_count:
			if si % 2 == 0:
				continue  ## Пропускаємо "червоні" — залишаємо bg
			var sx: float = float(si) * stripe_w
			var sw: float = minf(stripe_w, awning_w - sx)
			if sw > 0:
				awning.draw_rect(Rect2(sx, 0, sw, awning_h),
					Color(1, 1, 1, 0.45))
		## Хвилястий низ тенту — трикутні "фестони"
		var festoon_w: float = 20.0
		var festoon_count: int = int(awning_w / festoon_w) + 1
		for fi: int in festoon_count:
			var fx: float = float(fi) * festoon_w
			var fc: Color = Color("ef5350", 0.5) if fi % 2 == 0 \
				else Color(1, 1, 1, 0.4)
			var points: PackedVector2Array = PackedVector2Array([
				Vector2(fx, awning_h),
				Vector2(fx + festoon_w * 0.5, awning_h + 10.0),
				Vector2(fx + festoon_w, awning_h),
			])
			awning.draw_colored_polygon(points, fc)
	)
	_market_stall.add_child(awning)


func _input(event: InputEvent) -> void:
	if _game_over:
		return
	if _is_toddler_mode:
		if _input_locked:
			return
		## R0-1: tap mode (простіший для 2-3 років), R2+: drag mode
		if _round < 2:
			_handle_toddler_tap_input(event)
		else:
			_drag.handle_input(event)
		return
	## Preschool — tap routing
	if _input_locked:
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
	for node: Node2D in _answer_nodes:
		if not is_instance_valid(node) or node.get_meta("disabled", false):
			continue
		if pos.distance_to(node.global_position) < TAP_RADIUS:
			_handle_answer_tap(node)
			return


## Toddler tap mode: тап на фрукт -- він летить до кошика (R0-1)
func _handle_toddler_tap_input(event: InputEvent) -> void:
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
	for item: Node2D in _items:
		if not is_instance_valid(item):
			continue
		if pos.distance_to(item.global_position) < TAP_RADIUS:
			_on_toddler_tap(item)
			return


## Обробка тапу на фрукт у tap mode
func _on_toddler_tap(item: Node2D) -> void:
	if not _target_fruit.has("type"):
		push_warning("CountingGame: _target_fruit missing 'type' in tap handler")
		return
	if item.fruit_type == _target_fruit.get("type", ""):
		_on_dropped_on_target(item, _basket)
	else:
		_register_error(item)
		_reset_idle_timer()


func _process(delta: float) -> void:
	if _is_toddler_mode and _drag and not _input_locked and _round >= 2:
		_drag.handle_process(delta)


## ---- Управління раундами ----


func _start_round() -> void:
	_round_errors_local = 0
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	if _is_toddler_mode:
		_setup_toddler_round()
	else:
		_setup_preschool_round()


func _advance_round() -> void:
	_input_locked = true
	## Зберігти помилки цього раунду для адаптивної складності
	_round_errors.append(_round_errors_local)
	_clear_round()
	_round += 1
	if _round >= _total_rounds:
		_finish()
	else:
		await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(self) or _game_over:
			return
		_start_round()


func _clear_round() -> void:
	## LAW 9/A9: round hygiene — очищення ВСІХ тимчасових даних
	for item: Node2D in _items:
		if is_instance_valid(item):
			_origins.erase(item)
			item.queue_free()
	_items.clear()
	if _drag:
		_drag.draggable_items.clear()
		_drag.drop_targets.clear()
		_drag.clear_drag()
	if is_instance_valid(_basket):
		_basket.queue_free()
		_basket = null
	_counter_label = null  ## дочірній вузол _basket, звільняється разом
	_count_dots.clear()
	for node: Node2D in _answer_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_answer_nodes.clear()
	if is_instance_valid(_equation_label):
		_equation_label.queue_free()
		_equation_label = null
	## Очистити покупця
	if is_instance_valid(_buyer_node):
		_buyer_node.queue_free()
		_buyer_node = null
	_buyer_sprite = null
	_thought_bubble = null
	_current_count = 0


## ---- Тварина-покупець ----


## Вибрати випадкову тварину з GameData.ANIMALS_AND_FOOD без повторів у сесії.
func _pick_buyer_index() -> int:
	var pool_size: int = GameData.ANIMALS_AND_FOOD.size()
	if pool_size == 0:
		push_warning("CountingGame: ANIMALS_AND_FOOD is empty, fallback to 0")
		return 0
	if _used_animal_indices.size() >= pool_size:
		_used_animal_indices.clear()
	var available: Array[int] = []
	for i: int in pool_size:
		if i not in _used_animal_indices:
			available.append(i)
	if available.is_empty():
		push_warning("CountingGame: animal pool empty after filter, fallback")
		return randi() % pool_size
	available.shuffle()
	var idx: int = available[0]
	_used_animal_indices.append(idx)
	return idx


## Спавнити тварину-покупця з thought bubble
func _spawn_buyer(vp: Vector2, target_count: int) -> void:
	_buyer_node = Node2D.new()
	_buyer_node.position = Vector2(vp.x * 0.15, vp.y * 0.42)
	add_child(_buyer_node)

	## Інстанціювати спрайт тварини з GameData
	var buyer_idx: int = _pick_buyer_index()
	var animal_data: Dictionary = GameData.ANIMALS_AND_FOOD[buyer_idx]
	if animal_data.has("animal_scene") and animal_data.get("animal_scene") != null:
		_buyer_sprite = animal_data.animal_scene.instantiate()
		_buyer_sprite.scale = Vector2(ANIMAL_SCALE, ANIMAL_SCALE)
		_buyer_sprite.position = Vector2.ZERO
		_buyer_node.add_child(_buyer_sprite)
	else:
		## LAW 7: sprite fallback — жодного порожнього екрану
		push_warning("CountingGame: animal_scene missing for buyer, using basket icon fallback")
		var fallback: Control = IconDraw.basket(80.0)
		fallback.position = Vector2(-40, -40)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_buyer_node.add_child(fallback)

	## Thought bubble з кількістю
	_thought_bubble = Node2D.new()
	_thought_bubble.position = Vector2(50.0, -60.0)
	_buyer_node.add_child(_thought_bubble)
	_draw_thought_bubble(_thought_bubble, target_count)

	## Анімація входу покупця (зліва за екран -> позиція)
	if not SettingsManager.reduced_motion:
		var target_pos: Vector2 = _buyer_node.position
		_buyer_node.position = Vector2(-120.0, target_pos.y)
		_buyer_node.modulate.a = 0.0
		var tw: Tween = _create_game_tween().set_parallel(true)
		tw.tween_property(_buyer_node, "position", target_pos, 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_buyer_node, "modulate:a", 1.0, 0.3)


## Намалювати thought bubble з числом всередині
func _draw_thought_bubble(parent: Node2D, count: int) -> void:
	## Хмаринка думки — білий овал з хвостиком
	var bubble_bg: Control = Control.new()
	bubble_bg.custom_minimum_size = Vector2(THOUGHT_BUBBLE_RADIUS * 2.4, THOUGHT_BUBBLE_RADIUS * 2.0)
	bubble_bg.position = Vector2(-THOUGHT_BUBBLE_RADIUS * 1.2, -THOUGHT_BUBBLE_RADIUS * 1.0)
	bubble_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble_radius: float = THOUGHT_BUBBLE_RADIUS
	bubble_bg.draw.connect(func() -> void:
		var cx: float = bubble_radius * 1.2
		var cy: float = bubble_radius
		## Тінь хмаринки
		bubble_bg.draw_circle(Vector2(cx + 2, cy + 3), bubble_radius * 1.1,
			Color(0, 0, 0, 0.10))
		## Основне тіло
		bubble_bg.draw_circle(Vector2(cx, cy), bubble_radius * 1.1,
			Color(1, 1, 1, 0.92))
		## Глянцевий верх
		bubble_bg.draw_circle(Vector2(cx - bubble_radius * 0.15, cy - bubble_radius * 0.2),
			bubble_radius * 0.6, Color(1, 1, 1, 0.98))
		## Хвостик — маленькі кружечки вниз-вліво
		bubble_bg.draw_circle(Vector2(cx - bubble_radius * 0.7, cy + bubble_radius * 0.9),
			bubble_radius * 0.2, Color(1, 1, 1, 0.90))
		bubble_bg.draw_circle(Vector2(cx - bubble_radius * 0.9, cy + bubble_radius * 1.2),
			bubble_radius * 0.12, Color(1, 1, 1, 0.85))
	)
	parent.add_child(bubble_bg)

	## Число всередині bubble — великий шрифт
	var number_label: Label = Label.new()
	number_label.text = str(count)
	number_label.add_theme_font_size_override("font_size", 32)
	number_label.add_theme_color_override("font_color", Color("2d3436"))
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.position = Vector2(-THOUGHT_BUBBLE_RADIUS * 0.7, -THOUGHT_BUBBLE_RADIUS * 0.5)
	number_label.size = Vector2(THOUGHT_BUBBLE_RADIUS * 2.0, THOUGHT_BUBBLE_RADIUS * 1.2)
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(number_label)

	## Крапки під числом — візуальне підкріплення для pre-numerate дітей (A1)
	if count <= 6:
		var dots_spacing: float = 12.0
		var dots_w: float = float(count) * dots_spacing
		var dot_start_x: float = THOUGHT_BUBBLE_RADIUS * 0.5 - dots_w * 0.5 + dots_spacing * 0.5
		for di: int in count:
			var dot: Control = Control.new()
			dot.custom_minimum_size = Vector2(8, 8)
			dot.position = Vector2(
				dot_start_x + float(di) * dots_spacing - 4.0,
				THOUGHT_BUBBLE_RADIUS * 0.55
			)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.draw.connect(func() -> void:
				dot.draw_circle(Vector2(4, 4), 3.5, Color("2d3436", 0.7))
			)
			parent.add_child(dot)

	## Pulse анімація thought bubble
	if not SettingsManager.reduced_motion:
		_thought_bubble.scale = Vector2(0.3, 0.3)
		_thought_bubble.modulate.a = 0.0
		var tw: Tween = _create_game_tween().set_parallel(true)
		tw.tween_property(_thought_bubble, "scale", Vector2.ONE, 0.35)\
			.set_delay(0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_thought_bubble, "modulate:a", 1.0, 0.2).set_delay(0.3)


## Анімація щасливої реакції тварини при завершенні раунду
func _animate_buyer_happy() -> void:
	if not is_instance_valid(_buyer_node):
		return
	if SettingsManager.reduced_motion:
		return
	## Сховати thought bubble
	if is_instance_valid(_thought_bubble):
		var hide_tw: Tween = _create_game_tween()
		hide_tw.tween_property(_thought_bubble, "modulate:a", 0.0, 0.2)
	## Happy bounce — тварина підстрибує
	var bounce_tw: Tween = _create_game_tween()
	var orig_y: float = _buyer_node.position.y
	bounce_tw.tween_property(_buyer_node, "position:y",
		orig_y - ANIMAL_HAPPY_BOUNCE, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce_tw.tween_property(_buyer_node, "position:y",
		orig_y, 0.2)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	## Squish ефект (стиснення-розтягнення)
	bounce_tw.set_parallel(false)
	var squish_tw: Tween = _create_game_tween()
	squish_tw.tween_property(_buyer_node, "scale", Vector2(1.2, 0.85), 0.08)
	squish_tw.tween_property(_buyer_node, "scale", Vector2(0.9, 1.15), 0.1)
	squish_tw.tween_property(_buyer_node, "scale", Vector2.ONE, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Backflip анімація при perfect round (0 помилок)
func _animate_buyer_backflip() -> void:
	if not is_instance_valid(_buyer_node):
		return
	if SettingsManager.reduced_motion:
		return
	var orig_y: float = _buyer_node.position.y
	var flip_tw: Tween = _create_game_tween()
	## Стрибок вгору + обертання 360
	flip_tw.set_parallel(true)
	flip_tw.tween_property(_buyer_node, "position:y",
		orig_y - 60.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flip_tw.tween_property(_buyer_node, "rotation",
		-TAU, 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	## Приземлення
	flip_tw.chain().set_parallel(true)
	flip_tw.tween_property(_buyer_node, "position:y",
		orig_y, 0.25)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	flip_tw.tween_property(_buyer_node, "rotation", 0.0, 0.01)
	## Squish при приземленні
	flip_tw.chain().set_parallel(false)
	flip_tw.tween_property(_buyer_node, "scale", Vector2(1.3, 0.7), 0.06)
	flip_tw.tween_property(_buyer_node, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Кумедна реакція покупця на неправильний фрукт — здивоване обличчя + wobble.
## Toddler: ніжний wobble (менша амплітуда). Preschool: виразніша реакція.
## Параметр include_item_bounce: false коли snap_back вже рухає item (toddler drag),
## true для preschool tap-mode де snap_back не використовується.
func _play_funny_wrong_fruit(item: Node2D, include_item_bounce: bool = true) -> void:
	if SettingsManager.reduced_motion:
		return
	## Покупець робить здивоване обличчя: очі ширше (scale Y up) + rotation wobble
	if is_instance_valid(_buyer_node):
		var amp: float = 5.0 if _is_toddler_mode else 10.0
		var buyer_tw: Tween = _create_game_tween()
		buyer_tw.tween_property(_buyer_node, "scale", Vector2(0.9, 1.15), 0.1)
		buyer_tw.tween_property(_buyer_node, "rotation_degrees", amp, 0.08)
		buyer_tw.tween_property(_buyer_node, "rotation_degrees", -amp, 0.08)
		buyer_tw.tween_property(_buyer_node, "rotation_degrees", amp * 0.5, 0.06)
		buyer_tw.tween_property(_buyer_node, "rotation_degrees", 0.0, 0.06)
		buyer_tw.tween_property(_buyer_node, "scale", Vector2.ONE, 0.15)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## Фрукт відскакує як м'яч — bounce physics (лише коли snap_back не конфліктує)
	if include_item_bounce and is_instance_valid(item):
		var bounce_h: float = 25.0 if _is_toddler_mode else 45.0
		var orig_y: float = item.position.y
		var fruit_tw: Tween = _create_game_tween()
		fruit_tw.tween_property(item, "position:y", orig_y - bounce_h, 0.1)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fruit_tw.tween_property(item, "position:y", orig_y, 0.12)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		fruit_tw.tween_property(item, "scale", Vector2(1.2, 0.8), 0.05)
		fruit_tw.tween_property(item, "scale", Vector2.ONE, 0.1)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("bounce", 1.3)


## Фізична метафора: живіт тварини збільшується після кожного правильного фрукта.
## Дитина БАЧИТЬ, скільки вже зібрано, без абстрактного лічильника.
func _animate_belly_grow() -> void:
	if not is_instance_valid(_buyer_node):
		push_warning("CountingGame: _buyer_node invalid in _animate_belly_grow")
		return
	if SettingsManager.reduced_motion:
		var target: float = 1.0 + minf(float(_current_count) * BELLY_SCALE_STEP, BELLY_MAX_EXTRA)
		_buyer_node.scale = Vector2(target, target)
		return
	var target_scale: float = 1.0 + minf(float(_current_count) * BELLY_SCALE_STEP, BELLY_MAX_EXTRA)
	var tw: Tween = _create_game_tween()
	## Спочатку squish вширину (як ковтнув), потім рівномірне збільшення
	tw.tween_property(_buyer_node, "scale",
		Vector2(target_scale + 0.04, target_scale - 0.03), 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_buyer_node, "scale",
		Vector2(target_scale, target_scale), 0.12)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Задоволена реакція: тварина потирає живіт (wobble) і повертається до scale 1.0.
func _animate_belly_settle() -> void:
	if not is_instance_valid(_buyer_node):
		push_warning("CountingGame: _buyer_node invalid in _animate_belly_settle")
		return
	if SettingsManager.reduced_motion:
		_buyer_node.scale = Vector2.ONE
		_buyer_node.rotation = 0.0
		return
	var tw: Tween = _create_game_tween()
	## Потирання живота -- rotation wobble
	tw.tween_property(_buyer_node, "rotation", BELLY_WOBBLE_ANGLE, 0.1)
	tw.tween_property(_buyer_node, "rotation", -BELLY_WOBBLE_ANGLE, 0.1)
	tw.tween_property(_buyer_node, "rotation", BELLY_WOBBLE_ANGLE * 0.5, 0.08)
	tw.tween_property(_buyer_node, "rotation", 0.0, 0.08)
	## Живіт повертається до норми
	tw.tween_property(_buyer_node, "scale",
		Vector2(1.08, 0.94), 0.1)
	tw.tween_property(_buyer_node, "scale", Vector2.ONE, BELLY_SETTLE_DURATION)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## ---- Toddler: збери фрукти у кошик тварини ----


func _setup_toddler_round() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_current_count = 0

	## Конфіг раунду (A4: progressive difficulty)
	var config: Dictionary = _get_round_config()
	var min_count: int = config.get("min_count", 2)
	var max_count: int = config.get("max_count", 3)
	_target_count = randi_range(min_count, max_count)

	## Обрати фрукт без повторів
	var fruit_idx: int = _pick_unused_fruit_idx()
	_target_fruit = FRUITS[fruit_idx]

	## Обрати дистрактор
	var dist_count: int = config.get("distractor_types", 0)
	var distractor_fruits: Array[Dictionary] = []
	if dist_count > 0:
		for di: int in mini(dist_count, FRUITS.size() - 1):
			var d_idx: int = (fruit_idx + 1 + di) % FRUITS.size()
			distractor_fruits.append(FRUITS[d_idx])

	## Спавнити покупця з thought bubble
	_spawn_buyer(vp, _target_count)

	## Інструкція (A12: i18n)
	var fruit_name: String = tr("FRUIT_" + _target_fruit.get("type", "apple").to_upper())
	_fade_instruction(_instruction_label, tr("COUNTING_GIVE_TOFIE") % [_target_count, fruit_name])

	## Кошик (дропзона) — справа від тварини
	_basket = Node2D.new()
	_basket.position = Vector2(vp.x * 0.5, vp.y * 0.35)
	add_child(_basket)
	var basket_icon: Control = IconDraw.basket(70.0)
	basket_icon.position = Vector2(-35, -35)
	basket_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_basket.add_child(basket_icon)

	## Лічильник (прихований для тоддлерів — pre-numerate)
	_counter_label = Label.new()
	_counter_label.text = tr("COUNTING_COUNTER") % [0, _target_count]
	_counter_label.add_theme_font_size_override("font_size", 26)
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.position = Vector2(-60, 55)
	_counter_label.size = Vector2(120, 35)
	_counter_label.visible = not _is_toddler_mode
	_basket.add_child(_counter_label)

	## Візуальні крапки прогресу лічби (для pre-numerate дітей)
	_count_dots.clear()
	var dot_y: float = 85.0
	var dot_spacing: float = 22.0
	var dots_w: float = float(_target_count) * dot_spacing
	var dot_start_x: float = -dots_w * 0.5 + dot_spacing * 0.5
	for di: int in _target_count:
		var dot: Panel = Panel.new()
		dot.size = Vector2(14, 14)
		dot.position = Vector2(dot_start_x + float(di) * dot_spacing - 7.0, dot_y)
		dot.add_theme_stylebox_override("panel",
			GameData.candy_circle(Color(1, 1, 1, 0.3), 7.0, false))
		## Grain overlay (LAW 28)
		dot.material = GameData.create_premium_material(
			0.03, 2.0, 0.0, 0.0, 0.0, 0.04, 0.10, "", 0.0, 0.10, 0.22, 0.18)
		_basket.add_child(dot)
		_count_dots.append(dot)
	_drag.drop_targets.append(_basket)

	## Спавн фруктів — правильні + дистрактори
	var fruit_list: Array[Dictionary] = []
	for _i: int in range(_target_count):
		fruit_list.append(_target_fruit)
	## Дистрактори — по 1-2 кожного типу
	for dist_fruit: Dictionary in distractor_fruits:
		var d_amount: int = randi_range(1, 2)
		for _j: int in range(d_amount):
			fruit_list.append(dist_fruit)
	fruit_list.shuffle()

	## LAW 15: count-after-create — підрахунок ПІСЛЯ створення
	var total: int = fruit_list.size()
	if total == 0:
		push_warning("CountingGame: fruit_list empty, forcing 1 target fruit")
		fruit_list.append(_target_fruit)
		total = 1
	var cols: int = mini(total, 4)
	var area_w: float = vp.x * 0.6
	var area_h: float = vp.y * 0.32
	var start_x: float = vp.x * 0.25
	var start_y: float = vp.y * 0.58
	var cell_w: float = area_w / float(maxi(cols, 1))
	@warning_ignore("integer_division")
	var rows: int = (total + cols - 1) / maxi(cols, 1)
	var cell_h: float = area_h / float(maxi(rows, 1))
	var created_count: int = 0
	for i: int in range(total):
		if i >= fruit_list.size():
			push_warning("CountingGame: index %d out of bounds for fruit_list" % i)
			break
		var data: Dictionary = fruit_list[i]
		var col: int = i % maxi(cols, 1)
		@warning_ignore("integer_division")
		var row: int = i / maxi(cols, 1)
		var jitter: Vector2 = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		var pos: Vector2 = Vector2(
			start_x + cell_w * (float(col) + 0.5),
			start_y + cell_h * (float(row) + 0.5)
		) + jitter
		var item: Node2D = ITEM_SCENE.instantiate()
		add_child(item)
		var fruit_type: String = data.get("type", "apple")
		item.setup_with_icon(fruit_type,
			IconDraw.fruit_icon(fruit_type, ITEM_RADIUS * 1.2),
			data.get("color", Color.WHITE), ITEM_RADIUS)
		item.origin_pos = pos
		_items.append(item)
		_origins[item] = pos
		_drag.draggable_items.append(item)
		_deal_item_in(item, pos, i, total)
		created_count += 1

	## LAW 15: перевірка після створення
	if created_count == 0:
		push_warning("CountingGame: no items created, advancing round")
		_advance_round()


func _on_dropped_on_target(item: Node2D, _target: Node2D) -> void:
	if _game_over:
		return
	if not _target_fruit.has("type"):
		push_warning("CountingGame: _target_fruit missing type in drop handler")
		return
	if item.fruit_type == _target_fruit.get("type", ""):
		## Правильний фрукт — ascending pitch plop замість стандартного SFX!
		## Передаємо null в _register_correct щоб уникнути автоматичного audio feedback,
		## бо ми хочемо кастомний ascending pitch.
		_register_correct(null)
		var pitch: float = PLOP_BASE_PITCH + float(_current_count) * PLOP_PITCH_STEP
		AudioManager.play_sfx("success", pitch)
		HapticsManager.vibrate_success()
		if is_instance_valid(item):
			_animate_correct_item(item)
		_current_count += 1
		## Фізична метафора: живіт росте з кожним фруктом
		_animate_belly_grow()
		if is_instance_valid(_counter_label):
			_counter_label.text = tr("COUNTING_COUNTER") % [_current_count, _target_count]
		## Заповнити крапку прогресу
		var dot_idx: int = _current_count - 1
		if dot_idx >= 0 and dot_idx < _count_dots.size():
			var dot: Panel = _count_dots[dot_idx]
			if is_instance_valid(dot):
				dot.add_theme_stylebox_override("panel",
					GameData.candy_circle(_target_fruit.get("color", Color.WHITE), 7.0, false))
		## Вилучити з drag системи ПЕРЕД queue_free (LAW 9)
		_drag.draggable_items.erase(item)
		_origins.erase(item)
		## Зникнення в кошик з анімацією
		if SettingsManager.reduced_motion:
			item.global_position = _basket.global_position if is_instance_valid(_basket) \
				else item.global_position
			item.modulate.a = 0.0
			_items.erase(item)
			if is_instance_valid(item):
				item.queue_free()
		else:
			var basket_pos: Vector2 = _basket.global_position if is_instance_valid(_basket) \
				else item.global_position
			var tw: Tween = _create_game_tween().set_parallel(true)
			tw.tween_property(item, "global_position", basket_pos, 0.25)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.tween_property(item, "scale", Vector2(0.2, 0.2), 0.25)
			tw.tween_property(item, "modulate:a", 0.0, 0.2).set_delay(0.05)
			tw.chain().tween_callback(func() -> void:
				_items.erase(item)
				if is_instance_valid(item):
					item.queue_free())
			## Squish кошика
			if is_instance_valid(_basket):
				var bsq: Tween = _create_game_tween()
				bsq.tween_property(_basket, "scale", Vector2(1.15, 0.9), 0.08)
				bsq.tween_property(_basket, "scale", Vector2.ONE, 0.12)\
					.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		## Перевірка завершення раунду
		if _current_count >= _target_count:
			_input_locked = true
			## Фізична метафора: задоволений живіт (wobble + settle)
			_animate_belly_settle()
			## Реакція тварини: happy dance або backflip
			if _round_errors_local == 0:
				_animate_buyer_backflip()
			else:
				_animate_buyer_happy()
			if is_instance_valid(_basket):
				VFXManager.spawn_premium_celebration(_basket.global_position)
			var delay_d: float = 0.15 if SettingsManager.reduced_motion else 0.8
			var delay: Tween = _create_game_tween()
			delay.tween_interval(delay_d)
			delay.tween_callback(_advance_round)
		else:
			_reset_idle_timer()
	else:
		## Неправильний фрукт
		_round_errors_local += 1
		if not _is_toddler_mode:
			_errors += 1
		_register_error(item)
		_play_funny_wrong_fruit(item, false)  ## false: snap_back рухає item
		if _origins.has(item):
			_drag.snap_back(item, _origins[item])
		_reset_idle_timer()


func _on_dropped_on_empty(item: Node2D) -> void:
	if _origins.has(item):
		_drag.snap_back(item, _origins[item])


## ---- Preschool: рівняння з візуалізацією ----


func _setup_preschool_round() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size

	## Конфіг раунду (A4: progressive difficulty)
	var config: Dictionary = _get_round_config()
	var max_target: int = config.get("max_count", 4)
	## Генерація рівняння
	var a: int = randi_range(1, maxi(max_target - 2, 1))
	var b: int = randi_range(1, maxi(max_target - a, 1))
	_correct_answer = a + b
	_target_count = _correct_answer

	## Спавнити покупця
	_spawn_buyer(vp, _correct_answer)

	## Інструкція (A12: i18n)
	_fade_instruction(_instruction_label, tr("COUNTING_TUTORIAL_PRESCHOOL"))

	## Рівняння — великий текст посередині
	_equation_label = Label.new()
	_equation_label.text = "%d  +  %d  =  ?" % [a, b]
	_equation_label.add_theme_font_size_override("font_size", 56)
	_equation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equation_label.position = Vector2(vp.x * 0.2, vp.y * 0.28)
	_equation_label.size = Vector2(vp.x * 0.6, 70)
	add_child(_equation_label)

	## Відповіді (LAW 2: мінімум 3 вибори)
	var answers: Array[int] = [_correct_answer]
	answers.append_array(_generate_wrong_answers(_correct_answer))
	answers.shuffle()
	var spacing: float = vp.x / float(answers.size() + 1)
	var btn_y: float = vp.y * 0.65
	for i: int in range(answers.size()):
		var node: Node2D = ITEM_SCENE.instantiate()
		add_child(node)
		node.setup("answer", str(answers[i]), ANSWER_COLORS[mini(i, ANSWER_COLORS.size() - 1)],
			ANSWER_RADIUS)
		node.set_meta("is_correct", answers[i] == _correct_answer)
		node.set_meta("disabled", false)
		var pos: Vector2 = Vector2(spacing * float(i + 1), btn_y)
		_answer_nodes.append(node)
		_deal_item_in(node, pos, i, answers.size())


func _handle_answer_tap(node: Node2D) -> void:
	_input_locked = true
	if node.get_meta("is_correct", false):
		_register_correct(node)
		VFXManager.spawn_premium_celebration(node.global_position)
		## Фізична метафора: живіт росте + settle для preschool
		_current_count = _target_count
		_animate_belly_grow()
		_animate_belly_settle()
		## Реакція тварини
		if _round_errors_local == 0:
			_animate_buyer_backflip()
		else:
			_animate_buyer_happy()
		if not SettingsManager.reduced_motion:
			var tw: Tween = _create_game_tween()
			tw.tween_property(node, "scale", Vector2(1.4, 1.4), 0.15)
			tw.tween_property(node, "scale", Vector2(1.2, 1.2), 0.1)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			for other: Node2D in _answer_nodes:
				if other != node and is_instance_valid(other):
					_create_game_tween().tween_property(other, "modulate:a", 0.3, 0.3)
			tw.tween_interval(0.6)
			tw.tween_callback(_advance_round)
		else:
			var tw_d: Tween = _create_game_tween()
			tw_d.tween_interval(0.15)
			tw_d.tween_callback(_advance_round)
	else:
		_errors += 1
		_round_errors_local += 1
		_register_error(node)
		_play_funny_wrong_fruit(node)
		node.set_meta("disabled", true)
		node.modulate = Color(0.5, 0.5, 0.5)
		if not SettingsManager.reduced_motion:
			var orig_x: float = node.position.x
			var tw: Tween = _create_game_tween()
			tw.tween_property(node, "position:x", orig_x - 6.0, 0.06)
			tw.tween_property(node, "position:x", orig_x + 6.0, 0.06)
			tw.tween_property(node, "position:x", orig_x - 3.0, 0.04)
			tw.tween_property(node, "position:x", orig_x, 0.04)
			tw.tween_callback(func() -> void:
				_input_locked = false
				_reset_idle_timer())
		else:
			_input_locked = false
			_reset_idle_timer()


func _generate_wrong_answers(correct: int) -> Array[int]:
	var pool: Array[int] = []
	for v: int in range(maxi(1, correct - 3), correct + 4):
		if v != correct and v > 0:
			pool.append(v)
	pool.shuffle()
	if pool.size() < 2:
		push_warning("CountingGame: wrong answer pool < 2, fallback")
		return [correct + 1, correct + 2]
	return [pool[0], pool[1]]


## ---- Конфігурація раунду (A4: difficulty ramp) ----


func _get_round_config() -> Dictionary:
	if _round >= 0 and _round < ROUND_CONFIG.size():
		return ROUND_CONFIG[_round]
	## Fallback — останній раунд (LAW 8: impossible state)
	if ROUND_CONFIG.size() > 0:
		return ROUND_CONFIG[ROUND_CONFIG.size() - 1]
	push_warning("CountingGame: ROUND_CONFIG empty, fallback defaults")
	return {"min_count": 2, "max_count": 3, "distractor_types": 0, "fruit_types": 1}


## ---- Антиповтор фруктів ----


func _pick_unused_fruit_idx() -> int:
	if _used_fruit_idx.size() >= FRUITS.size():
		_used_fruit_idx.clear()
	var available: Array[int] = []
	for i: int in FRUITS.size():
		if i not in _used_fruit_idx:
			available.append(i)
	if available.is_empty():
		push_warning("CountingGame: fruit pool empty, fallback")
		if FRUITS.size() > 0:
			return randi() % FRUITS.size()
		return 0
	available.shuffle()
	var idx: int = available[0]
	_used_fruit_idx.append(idx)
	return idx


## ---- Спільне ----


func _deal_item_in(item: Node2D, pos: Vector2, idx: int, total: int) -> void:
	if SettingsManager.reduced_motion:
		item.position = pos
		item.scale = Vector2.ONE
		item.modulate.a = 1.0
		if idx == total - 1:
			_input_locked = false
			_start_idle_breathing(_drag.draggable_items)
			_reset_idle_timer()
		return
	item.position = Vector2(pos.x, -200.0)
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
			_start_idle_breathing(_drag.draggable_items)
			_reset_idle_timer())


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	## LAW 24: stats contract — обов'язкові ключі
	var stats: Dictionary = {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": _total_rounds,
		"earned_stars": earned,
	}
	finish_game(earned, stats)


func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


## A10: idle escalation — 3 рівні: pulse -> glow -> tutorial hand
func _show_idle_hint() -> void:
	if _input_locked or _game_over:
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		## Рівень 2+ — tutorial hand показується через _advance_idle_hint()
		_reset_idle_timer()
		return
	if _is_toddler_mode:
		## Pulse на першому правильному фрукті
		for item: Node2D in _items:
			if is_instance_valid(item) and item.fruit_type == _target_fruit.get("type", ""):
				_pulse_node(item, 1.2)
				break
	else:
		## Pulse на правильній відповіді
		for node: Node2D in _answer_nodes:
			if is_instance_valid(node) and node.get_meta("is_correct", false):
				_pulse_node(node, 1.2)
				break
	_reset_idle_timer()


## A1: tutorial instruction — zero-text onboarding, текст лише як підтримка
func get_tutorial_instruction() -> String:
	if _is_toddler_mode:
		return tr("COUNTING_TUTORIAL_TODDLER")
	return tr("COUNTING_TUTORIAL_PRESCHOOL")


## Tutorial demo — дані для анімованої руки-підказки (A1)
func get_tutorial_demo() -> Dictionary:
	if _is_toddler_mode:
		## Перетягнути перший правильний фрукт у кошик
		for item: Node2D in _items:
			if is_instance_valid(item) and item.fruit_type == _target_fruit.get("type", ""):
				if is_instance_valid(_basket):
					return {"type": "drag", "from": item.global_position,
						"to": _basket.global_position}
	else:
		## Натиснути правильну відповідь
		for node: Node2D in _answer_nodes:
			if is_instance_valid(node) and node.get_meta("is_correct", false):
				return {"type": "tap", "target": node.global_position}
	return {}
