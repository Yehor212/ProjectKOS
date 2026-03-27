extends BaseMiniGame

## "Ресторан Тофі" — годування тварин з двома повноцінними режимами.
##
## Toddler (2-4): Drag їжу до тварини. Тварини слинявляться коли їжа поряд,
## танцюють коли наїлися. Кожні 5 — "Клієнт Дня" зі спарклами.
##
## Preschool (5-7): "Таємничий гість" — силует тварини приходить до ресторану.
## Обери правильну їжу щоб розкрити хто це! Drag їжу до силуету.
## Неправильна їжа — силует хитає головою.

## ============================================================
## Константи
## ============================================================

## Ідентифікатор гри (збігається з game_catalog.gd)
const GAME_ID: String = "hungry_pets"
## Скільки вдалих годувань для мікро-нагороди "Клієнт Дня"
const CUSTOMER_OF_DAY_EVERY: int = 5
## Затримка idle перед першою підказкою (A10)
const IDLE_HINT_DELAY: float = 8.0
## Радіус "snap" зони для drag-and-drop
const DROP_RADIUS: float = 100.0
## Toddler: скільки раундів (пар), progressive
const TD_PAIRS_PER_ROUND: Array[int] = [2, 3, 4]
## Preschool: кількість раундів
const PS_TOTAL_ROUNDS: int = 6


## ============================================================
## Спільні змінні
## ============================================================

var _is_preschool: bool = false
var _cloud_timer: Timer = null
var _start_time_ms: int = 0
var _total_fed: int = 0  ## Загальна кількість накормлених (для "Клієнт Дня")
var _idle_timer: SceneTreeTimer = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## ============================================================
## Toddler mode: RoundManager + DragController + HintSystem
## ============================================================

var _round_manager: RoundManager = null
var _drag_controller: DragController = null
var _hint_system: HintSystem = null


## ============================================================
## Preschool mode: "Таємничий гість" — силует + drag
## ============================================================

var _ps_current_round: int = 0
var _ps_used_indices: Array[int] = []
var _ps_animal_node: Node2D = null
var _ps_animal_idx: int = -1
var _ps_food_cards: Array[Node2D] = []
var _ps_correct_food_name: String = ""
var _ps_is_silhouette: bool = false
var _ps_round_errors: int = 0  ## Помилки у поточному раунді (для scaffolding)
var _ps_dragging_card: Node2D = null
var _ps_drag_offset: Vector2 = Vector2.ZERO
var _ps_card_origins: Dictionary = {}  ## card -> Vector2 (original pos)
var _ps_drop_zone: Vector2 = Vector2.ZERO  ## Центр зони прийому (позиція тварини)


## ============================================================
## _ready — головна точка входу
## ============================================================

func _ready() -> void:
	game_id = GAME_ID
	bg_theme = "meadow"
	super()
	_rng.randomize()
	_start_time_ms = Time.get_ticks_msec()
	_is_preschool = (SettingsManager.age_group == 2)

	_apply_background()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_build_hud()
	_start_ambient_clouds()

	if _is_preschool:
		_setup_preschool()
	else:
		_setup_toddler()

	AnalyticsManager.log_level_start(1)


## ============================================================
## HUD — інструкційна pill (A12: i18n)
## ============================================================

func _build_hud() -> void:
	var text: String = tr("FOOD_TUTORIAL_PRESCHOOL") if _is_preschool else tr("FOOD_TUTORIAL_TODDLER")
	_build_instruction_pill(text, 24)


## A1: Tutorial demo для TutorialSystem (animated hand)
func get_tutorial_demo() -> Dictionary:
	if _is_preschool:
		## Preschool: drag їжу до силуету
		if _ps_food_cards.size() > 0 and is_instance_valid(_ps_food_cards[0]) \
				and is_instance_valid(_ps_animal_node):
			return {"type": "drag", "from": _ps_food_cards[0].global_position,
				"to": _ps_animal_node.global_position}
		return {}
	## Toddler: drag їжу до тварини
	if _round_manager and _round_manager.current_round_food.size() > 0 \
			and _round_manager.current_round_animals.size() > 0:
		var food: Node2D = _round_manager.current_round_food[0]
		var food_type: String = food.get_meta("food_type", "")
		for animal: Node2D in _round_manager.current_round_animals:
			if GameData.find_correct_food_name(animal.name) == food_type:
				return {"type": "drag", "from": food.global_position,
					"to": animal.global_position}
	return {}


## ============================================================
## TODDLER MODE — setup + callbacks
## ============================================================

func _setup_toddler() -> void:
	_round_manager = RoundManager.new(self)
	_drag_controller = DragController.new(self, _round_manager)

	_hint_system = HintSystem.new()
	add_child(_hint_system)
	if has_node("HintButton"):
		_hint_system.setup(_round_manager, self, $HintButton)
		JuicyEffects.button_press_squish($HintButton, self)
	else:
		push_warning("FoodGame: HintButton node missing, proceeding without hint button")

	_drag_controller.food_dropped_on_animal.connect(_on_food_dropped_on_animal)
	_drag_controller.food_dropped_on_empty.connect(_on_food_dropped_on_empty)
	_drag_controller.food_picked_up.connect(_on_toddler_interaction)
	_round_manager.game_won.connect(_on_game_won)
	_round_manager.mini_game_finished.connect(_on_mini_game_finished)
	_round_manager.round_started.connect(_on_round_started)

	_round_manager.start_new_round()
	_start_safety_timeout(300.0)  ## 5 хвилин

	## A1: tutorial для нових гравців
	if not ProgressManager.has_seen_tutorial:
		_start_tutorial()
		_drag_controller.food_picked_up.connect(_stop_tutorial_on_pickup, CONNECT_ONE_SHOT)

	_reset_idle_timer()


func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	if _is_preschool:
		_ps_handle_input(event)
		return
	_drag_controller.handle_input(event)


func _process(delta: float) -> void:
	if _input_locked or _game_over:
		return
	if _is_preschool:
		_ps_handle_process(delta)
		return
	_drag_controller.handle_process(delta)
	## Оновлення сну тварин — засинають при бездіяльності
	if _round_manager:
		var animator: AnimalAnimator = _round_manager.get_animator()
		for animal: Node2D in _round_manager.current_round_animals:
			if is_instance_valid(animal):
				animator.update_sleep(animal, delta)


func _on_toddler_interaction() -> void:
	_reset_idle_timer()
	if _hint_system:
		_hint_system.stop_idle_timer()


func _on_food_dropped_on_animal(food: Node2D, animal: Node2D) -> void:
	_input_locked = true
	_drag_controller.clear_highlight()
	var is_correct: bool = _round_manager.try_match(food, animal)
	AnalyticsManager.log_item_match(animal.name, is_correct)

	if is_correct:
		ProgressManager.unlock_animal(animal.name)
		ProgressManager.increment_animals_fed()
		_total_fed += 1
		## A6: Toddler — click+wobble через _register_correct (не error sfx)
		AudioManager.play_sfx("success", 1.0 + mini(_round_manager.current_combo, 10) * 0.05)
		HapticsManager.vibrate_success()
		VFXManager.spawn_success_ripple(animal.global_position, ThemeManager.COLOR_PRIMARY)
		_register_correct()
		_play_td_correct_sequence(animal, food)
	else:
		## A6: тоддлер — м'який зворотній зв'язок, без _errors++
		AudioManager.play_sfx("click")
		HapticsManager.vibrate_light()
		_play_td_wrong_tween(animal)
		_round_manager.return_food_to_origin(food)
		if _hint_system:
			_hint_system.check_error_hint(_round_manager.errors_made)

	_reset_idle_timer()
	if _hint_system:
		_hint_system.start_idle_timer()


func _on_food_dropped_on_empty(food: Node2D) -> void:
	_input_locked = true
	HapticsManager.vibrate_light()
	_round_manager.reset_combo()
	var tween: Tween = _round_manager.return_food_to_origin(food)
	if tween:
		tween.finished.connect(func() -> void: _input_locked = false)
	else:
		_input_locked = false
	_reset_idle_timer()
	if _hint_system:
		_hint_system.start_idle_timer()


func _on_game_won(stats: Dictionary) -> void:
	_game_over = true
	_input_locked = true
	if _hint_system:
		_hint_system.stop_idle_timer()
	## LAW 16: єдине джерело зірок
	var earned: int = _calculate_stars(_errors)
	stats["earned_stars"] = earned
	finish_game(earned, stats)


func _on_mini_game_finished(stats: Dictionary) -> void:
	_game_over = true
	_input_locked = true
	if _hint_system:
		_hint_system.stop_idle_timer()
	var earned: int = _calculate_stars(_errors)
	stats["earned_stars"] = earned
	finish_game(earned, stats)


func _on_round_started() -> void:
	_input_locked = false
	if _hint_system:
		_hint_system.on_round_started()
	_reset_idle_timer()


## Правильна відповідь Toddler: happy dance + "жування" + сердечки + recycle
func _play_td_correct_sequence(animal: Node2D, food: Node2D) -> void:
	if is_instance_valid(animal):
		_round_manager.get_animator().play_happy(animal)

	## "Клієнт Дня" — мікро-нагорода кожні N годувань
	var is_customer_of_day: bool = (_total_fed % CUSTOMER_OF_DAY_EVERY == 0) and _total_fed > 0

	var tween: Tween = _create_game_tween()
	tween.tween_interval(0.8)
	tween.tween_callback(func() -> void:
		## Сердечки після годування
		if is_instance_valid(animal):
			VFXManager.spawn_correct_sparkle(animal.global_position + Vector2(0, -40))

		## "Клієнт Дня" — додаткові спарклі + золотий вибух
		if is_customer_of_day and is_instance_valid(animal):
			VFXManager.spawn_golden_burst(animal.global_position)
			JuicyEffects.screen_shake(self, 4.0)
	)
	tween.tween_interval(0.4)
	tween.tween_callback(func() -> void:
		if is_instance_valid(animal):
			_round_manager.recycle_animal(animal)
		if is_instance_valid(food):
			_round_manager.recycle_food(food)
		if not _game_over:
			_round_manager.add_new_pair_if_needed()
			_input_locked = false
	)


func _play_td_wrong_tween(animal: Node2D) -> void:
	if is_instance_valid(animal):
		_round_manager.get_animator().play_sad(animal)
	var tween: Tween = _create_game_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func() -> void: _input_locked = false)


## ============================================================
## PRESCHOOL MODE — "Таємничий гість"
## ============================================================

func _setup_preschool() -> void:
	## Сховати елементи Toddler-режиму
	if has_node("HintButton"):
		$HintButton.visible = false
	if has_node("TutorialOverlay"):
		$TutorialOverlay.visible = false

	_start_safety_timeout(180.0)  ## 3 хвилини для 6 раундів
	_ps_start_round()


## Кількість варіантів їжі для поточного раунду (A4: difficulty ramp)
func _ps_get_options_count() -> int:
	## R0-R1: 3 варіанти, R2-R5: 4 варіанти (LAW 2: min 3)
	return _scale_by_round_i(3, 4, _ps_current_round, PS_TOTAL_ROUNDS)


## Чи використовувати силует для поточного раунду (A4: складніше)
func _ps_use_silhouette() -> bool:
	## R0: повний колір (тренування), R1+: силует
	return _ps_current_round >= 1


## Очищення Preschool-раунду (A9: round hygiene)
func _ps_cleanup_round() -> void:
	_ps_dragging_card = null
	_ps_drag_offset = Vector2.ZERO
	if is_instance_valid(_ps_animal_node):
		_ps_animal_node.queue_free()
	_ps_animal_node = null
	_ps_animal_idx = -1
	for card: Node2D in _ps_food_cards:
		if is_instance_valid(card):
			card.queue_free()
	_ps_food_cards.clear()
	_ps_card_origins.clear()
	_ps_correct_food_name = ""
	_ps_is_silhouette = false
	_ps_round_errors = 0


## Обрати тварину, що ще не використовувалась (A8: fallback якщо всі вичерпані)
func _ps_pick_animal_index() -> int:
	var available: Array[int] = []
	for i: int in range(GameData.ANIMALS_AND_FOOD.size()):
		if not _ps_used_indices.has(i):
			available.append(i)
	if available.is_empty():
		push_warning("FoodGame Preschool: всі тварини використані, скидаємо пул")
		_ps_used_indices.clear()
		for i: int in range(GameData.ANIMALS_AND_FOOD.size()):
			available.append(i)
	if available.is_empty():
		push_warning("FoodGame Preschool: ANIMALS_AND_FOOD порожній, неможливо обрати")
		return 0
	var pick: int = _rng.randi_range(0, available.size() - 1)
	return available[pick]


## Обрати дистрактори — неправильні їжі (LAW 13: bounded loop)
func _ps_pick_distractors(correct_idx: int, count: int) -> Array[int]:
	var pool_size: int = GameData.ANIMALS_AND_FOOD.size()
	if pool_size <= 1:
		push_warning("FoodGame Preschool: недостатньо тварин для дистракторів")
		return []
	var result: Array[int] = []
	var attempts: int = 0
	while result.size() < count and attempts < 100:
		attempts += 1
		var idx: int = _rng.randi_range(0, pool_size - 1)
		if idx == correct_idx or result.has(idx):
			continue
		result.append(idx)
	return result


## Запуск нового Preschool-раунду
func _ps_start_round() -> void:
	_ps_cleanup_round()
	_input_locked = true

	if _ps_current_round >= PS_TOTAL_ROUNDS:
		push_warning("FoodGame Preschool: спроба почати раунд понад ліміт")
		_ps_finish_game()
		return

	## Оновити round label
	_update_round_label(tr("ROUND_N") % [_ps_current_round + 1, PS_TOTAL_ROUNDS])

	## Обрати тварину
	_ps_animal_idx = _ps_pick_animal_index()
	_ps_used_indices.append(_ps_animal_idx)

	if _ps_animal_idx < 0 or _ps_animal_idx >= GameData.ANIMALS_AND_FOOD.size():
		push_warning("FoodGame Preschool: невалідний індекс тварини %d" % _ps_animal_idx)
		_ps_finish_game()
		return

	var pair: Dictionary = GameData.ANIMALS_AND_FOOD[_ps_animal_idx]
	_ps_correct_food_name = GameData.get_food_name_from_scene(pair.get("food_scene"))

	## Створити спрайт тварини
	var animal_scene: PackedScene = pair.get("animal_scene")
	if not animal_scene:
		push_warning("FoodGame Preschool: animal_scene відсутня для індексу %d" % _ps_animal_idx)
		_ps_finish_game()
		return
	_ps_animal_node = animal_scene.instantiate()
	_ps_animal_node.name = pair.get("name", "Unknown")
	add_child(_ps_animal_node)

	## Силует: затемнити тварину (graceful degradation якщо шейдера немає)
	_ps_is_silhouette = _ps_use_silhouette()
	if _ps_is_silhouette:
		_ps_apply_silhouette(_ps_animal_node)

	## Зібрати набір їжі: 1 правильна + дистрактори
	var options_count: int = _ps_get_options_count()
	var distractor_indices: Array[int] = _ps_pick_distractors(_ps_animal_idx, options_count - 1)
	var food_indices: Array[int] = [_ps_animal_idx]
	food_indices.append_array(distractor_indices)

	## Перемішати (Fisher-Yates)
	_ps_shuffle_array(food_indices)

	## Створити draggable картки їжі
	for i: int in range(food_indices.size()):
		if food_indices[i] < 0 or food_indices[i] >= GameData.ANIMALS_AND_FOOD.size():
			push_warning("FoodGame Preschool: невалідний food index %d" % food_indices[i])
			continue
		var food_pair: Dictionary = GameData.ANIMALS_AND_FOOD[food_indices[i]]
		var food_scene: PackedScene = food_pair.get("food_scene")
		if not food_scene:
			push_warning("FoodGame Preschool: food_scene відсутня")
			continue
		var food_name: String = GameData.get_food_name_from_scene(food_scene)
		var card: Node2D = _ps_create_food_card(food_scene, food_name)
		add_child(card)
		_ps_food_cards.append(card)

	## LAW 2: гарантувати мінімум 3 варіанти
	if _ps_food_cards.size() < 3:
		push_warning("FoodGame Preschool: менше 3 карток їжі (%d)" % _ps_food_cards.size())

	## Позиціонування
	_ps_reposition_ui()
	_ps_drop_zone = _ps_animal_node.position if is_instance_valid(_ps_animal_node) else Vector2.ZERO

	## Анімація появи (каскад)
	_ps_animate_entrance()

	## Розблокувати ввід після анімації
	var unlock_tw: Tween = _create_game_tween()
	unlock_tw.tween_interval(0.5)
	unlock_tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer()
	)


## Застосувати силует до тварини (темний модулятор, graceful degradation)
func _ps_apply_silhouette(node: Node2D) -> void:
	if not is_instance_valid(node):
		push_warning("FoodGame Preschool: невалідний node для силуету")
		return
	## Шейдер силуету — якщо є, використовуємо, інакше просто затемнюємо
	var shader_path: String = "res://assets/shaders/silhouette.gdshader"
	if ResourceLoader.exists(shader_path):
		var shader: Shader = load(shader_path)
		if shader:
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = shader
			## R4+: частково прихований силует (більш темний)
			var darkness: float = _scale_by_round(0.25, 0.12, _ps_current_round, PS_TOTAL_ROUNDS)
			mat.set_shader_parameter("silhouette_color", Color(darkness, darkness, darkness + 0.05, 1.0))
			node.material = mat
			return
	## Fallback: modulate до темного кольору (без шейдера)
	node.modulate = Color(0.12, 0.12, 0.15, 1.0)


## Розкрити тварину з силуету (анімація кольору)
func _ps_reveal_silhouette(node: Node2D) -> Tween:
	if not is_instance_valid(node):
		push_warning("FoodGame Preschool: невалідний node для reveal")
		return null
	var tween: Tween = _create_game_tween()
	## Зняти шейдер і анімувати modulate до білого
	node.material = null
	node.modulate = Color(0.12, 0.12, 0.15, 1.0)
	tween.tween_property(node, "modulate", Color.WHITE, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween


## Створити draggable картку їжі для Preschool
func _ps_create_food_card(food_scene: PackedScene, food_name: String) -> Node2D:
	var container: Node2D = Node2D.new()
	container.set_meta("food_name", food_name)
	container.set_meta("disabled", false)

	## Спрайт їжі
	var food_sprite: Node2D = food_scene.instantiate()
	food_sprite.scale = Vector2(0.3, 0.3)
	container.add_child(food_sprite)

	## Фонова "тарілка" — Area2D для зручного drag detection
	var area: Area2D = Area2D.new()
	area.name = "ClickArea"
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 60.0  ## >= 80px touch target (LAW touch targets)
	shape.shape = circle
	area.add_child(shape)
	container.add_child(area)

	return container


## Preschool drag handling — вхідні події
func _ps_handle_input(event: InputEvent) -> void:
	if _game_over or _input_locked:
		return

	## Touch/mouse press/release — початок або кінець drag
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = false
		var pos: Vector2 = Vector2.ZERO
		if event is InputEventScreenTouch:
			pressed = event.pressed
			pos = event.position
		elif event is InputEventMouseButton:
			pressed = event.pressed
			pos = event.position

		if pressed:
			_ps_try_start_drag(pos)
		else:
			if _ps_dragging_card:
				_ps_try_drop(pos)
				_ps_dragging_card = null
		return

	## Touch/mouse drag — оновлення позиції під пальцем
	if _ps_dragging_card and is_instance_valid(_ps_dragging_card):
		var drag_pos: Vector2 = Vector2.ZERO
		if event is InputEventScreenDrag:
			drag_pos = event.position
		elif event is InputEventMouseMotion:
			drag_pos = event.position
		else:
			return
		_ps_dragging_card.position = drag_pos + _ps_drag_offset


func _ps_handle_process(_delta: float) -> void:
	pass  ## Drag оновлюється через _ps_handle_input (InputEventScreenDrag/MouseMotion)


## Спроба почати drag картки
func _ps_try_start_drag(touch_pos: Vector2) -> void:
	for card: Node2D in _ps_food_cards:
		if not is_instance_valid(card):
			continue
		if card.get_meta("disabled", false):
			continue
		var dist: float = touch_pos.distance_to(card.global_position)
		if dist < 80.0:  ## Touch target radius
			_ps_dragging_card = card
			_ps_drag_offset = card.position - touch_pos
			## Візуальний feedback — збільшити при підйомі
			var tw: Tween = _create_game_tween()
			tw.tween_property(card, "scale", Vector2(1.15, 1.15), ANIM_FAST)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_reset_idle_timer()
			return


## Спроба drop картки — перевірити чи потрапила в зону тварини
func _ps_try_drop(drop_pos: Vector2) -> void:
	if not is_instance_valid(_ps_dragging_card):
		push_warning("FoodGame Preschool: dragging card invalid at drop")
		return

	## Повернути масштаб
	var scale_tw: Tween = _create_game_tween()
	scale_tw.tween_property(_ps_dragging_card, "scale", Vector2.ONE, ANIM_FAST)

	var card: Node2D = _ps_dragging_card
	var tapped_name: String = card.get_meta("food_name", "")
	var dist_to_animal: float = drop_pos.distance_to(_ps_drop_zone)

	if dist_to_animal > DROP_RADIUS:
		## Промахнувся мимо тварини — повернути картку на місце
		_ps_return_card_to_origin(card)
		return

	## Потрапив у зону тварини — перевірити відповідність
	var is_correct: bool = (tapped_name == _ps_correct_food_name)
	var animal_name: String = _ps_animal_node.name if is_instance_valid(_ps_animal_node) else "unknown"
	AnalyticsManager.log_item_match(animal_name, is_correct)

	if is_correct:
		_ps_on_correct(card)
	else:
		_ps_on_wrong(card)

	_reset_idle_timer()


## Повернути картку на оригінальну позицію (smooth)
func _ps_return_card_to_origin(card: Node2D) -> void:
	if not is_instance_valid(card):
		push_warning("FoodGame Preschool: невалідна картка для повернення")
		return
	var origin: Vector2 = _ps_card_origins.get(card, card.position)
	var tw: Tween = _create_game_tween()
	tw.tween_property(card, "position", origin, ANIM_NORMAL)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Preschool: правильна відповідь — розкрити силует + перехід
func _ps_on_correct(card: Node2D) -> void:
	_input_locked = true
	_total_fed += 1

	if is_instance_valid(_ps_animal_node):
		ProgressManager.unlock_animal(_ps_animal_node.name)
	ProgressManager.increment_animals_fed()

	## Реєстрація правильної — без node (feedback кастомний нижче)
	_register_correct()

	## Анімація розкриття силуету
	var reveal_tw: Tween = null
	if _ps_is_silhouette and is_instance_valid(_ps_animal_node):
		reveal_tw = _ps_reveal_silhouette(_ps_animal_node)

	## Звуковий + візуальний feedback
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	if is_instance_valid(_ps_animal_node):
		VFXManager.spawn_success_ripple(_ps_animal_node.global_position, ThemeManager.COLOR_PRIMARY)

	## Затемнити неправильні картки, підсвітити правильну
	for c: Node2D in _ps_food_cards:
		if not is_instance_valid(c):
			continue
		if c == card:
			var tw: Tween = _create_game_tween()
			tw.tween_property(c, "modulate", Color(0.5, 1.0, 0.5, 1.0), 0.2)
		else:
			var tw: Tween = _create_game_tween()
			tw.tween_property(c, "modulate:a", 0.3, 0.3)

	## Happy dance тварини після розкриття
	var dance_tw: Tween = _create_game_tween()
	dance_tw.tween_interval(0.6)
	dance_tw.tween_callback(func() -> void:
		if is_instance_valid(_ps_animal_node):
			## Bounce — імітація щасливого стрибка
			var orig_pos: Vector2 = _ps_animal_node.position
			var bounce: Tween = _create_game_tween()
			bounce.tween_property(_ps_animal_node, "position:y",
				orig_pos.y - 20.0, 0.15)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			bounce.tween_property(_ps_animal_node, "position:y",
				orig_pos.y, 0.15)\
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			## Сердечки
			VFXManager.spawn_correct_sparkle(
				_ps_animal_node.global_position + Vector2(0, -40))
	)

	## "Клієнт Дня"
	if _total_fed > 0 and _total_fed % CUSTOMER_OF_DAY_EVERY == 0:
		var vp: Vector2 = get_viewport_rect().size
		dance_tw.tween_callback(func() -> void:
			VFXManager.spawn_golden_burst(vp / 2.0)
			JuicyEffects.screen_shake(self, 4.0)
		)

	## Перехід до наступного раунду
	dance_tw.tween_interval(0.8)
	dance_tw.tween_callback(func() -> void:
		_ps_current_round += 1
		if _ps_current_round >= PS_TOTAL_ROUNDS:
			_ps_finish_game()
		else:
			_ps_start_round()
	)


## Preschool: неправильна відповідь — A7: error sfx + smoke + vibration + лічильник
func _ps_on_wrong(card: Node2D) -> void:
	_input_locked = true
	_errors += 1
	_ps_round_errors += 1

	## A7: Preschool error registration — без node (feedback кастомний нижче)
	## A11: scaffold через _register_error -> _show_scaffold_hint
	_register_error()

	## A7: error sfx + smoke + vibration (кастомний feedback для Preschool)
	AudioManager.play_sfx("error")
	HapticsManager.vibrate_light()
	if is_instance_valid(card):
		VFXManager.spawn_error_smoke(card.global_position)

	## Силует хитає головою (wobble)
	if is_instance_valid(_ps_animal_node):
		var wobble_tw: Tween = _create_game_tween()
		wobble_tw.tween_property(_ps_animal_node, "rotation", deg_to_rad(6.0), 0.06)
		wobble_tw.tween_property(_ps_animal_node, "rotation", deg_to_rad(-6.0), 0.12)
		wobble_tw.tween_property(_ps_animal_node, "rotation", deg_to_rad(3.0), 0.08)
		wobble_tw.tween_property(_ps_animal_node, "rotation", 0.0, 0.06)

	## Вимкнути цю картку (затемнити + disabled)
	if is_instance_valid(card):
		card.set_meta("disabled", true)
		var dim_tw: Tween = _create_game_tween()
		dim_tw.tween_property(card, "modulate", Color(0.4, 0.4, 0.4, 0.5), 0.3)

	## Розблокувати ввід через затримку
	var unlock: Tween = _create_game_tween()
	unlock.tween_interval(0.4)
	unlock.tween_callback(func() -> void:
		_input_locked = false
		## Перевірити чи залишились активні картки
		var active_count: int = 0
		for c: Node2D in _ps_food_cards:
			if is_instance_valid(c) and not c.get_meta("disabled", false):
				active_count += 1
		## Якщо залишилась лише 1 картка (правильна) — автоматично пройти
		if active_count <= 1:
			_ps_auto_reveal_last()
	)


## Авто-розкриття, коли залишилась лише 1 картка (graceful UX)
func _ps_auto_reveal_last() -> void:
	for card: Node2D in _ps_food_cards:
		if is_instance_valid(card) and not card.get_meta("disabled", false):
			_ps_on_correct(card)
			return


## Завершення Preschool-гри
func _ps_finish_game() -> void:
	_game_over = true
	_input_locked = true
	var elapsed_ms: int = Time.get_ticks_msec() - _start_time_ms
	## LAW 13: guard division
	var time_sec: float = float(elapsed_ms) / 1000.0
	var stats: Dictionary = {
		"time_sec": time_sec,
		"errors": _errors,
		"rounds_played": _ps_current_round,
	}
	## LAW 16: єдине джерело зірок
	var earned: int = _calculate_stars(_errors)
	stats["earned_stars"] = earned
	finish_game(earned, stats)


## Позиціонування Preschool UI — тварина зліва, їжа справа
func _ps_reposition_ui() -> void:
	var vp_size: Vector2 = get_viewport_rect().size

	## Тварина: ліва частина, по центру
	if is_instance_valid(_ps_animal_node):
		_ps_animal_node.position = Vector2(vp_size.x * 0.25, vp_size.y * 0.48)
		var animal_scale: float = (vp_size.x * 0.18) / 512.0
		_ps_animal_node.scale = Vector2(animal_scale, animal_scale)

	## Картки їжі: права частина, рівномірно по вертикалі
	var card_count: int = _ps_food_cards.size()
	if card_count == 0:
		return
	var right_x: float = vp_size.x * 0.72
	var card_area_top: float = vp_size.y * 0.18
	var card_area_bottom: float = vp_size.y * 0.82
	## LAW 13: guard division by zero
	var spacing: float = 0.0
	if card_count > 1:
		spacing = (card_area_bottom - card_area_top) / float(card_count - 1)

	for i: int in range(card_count):
		var card: Node2D = _ps_food_cards[i]
		if not is_instance_valid(card):
			continue
		var y_pos: float = card_area_top + spacing * float(i) if card_count > 1 else vp_size.y * 0.5
		card.position = Vector2(right_x, y_pos)
		_ps_card_origins[card] = card.position


## Каскадна анімація появи Preschool
func _ps_animate_entrance() -> void:
	if SettingsManager.reduced_motion:
		return
	## Тварина — з'являється зліва (зберігаємо колір силуету)
	if is_instance_valid(_ps_animal_node):
		var target_pos: Vector2 = _ps_animal_node.position
		var target_modulate: Color = _ps_animal_node.modulate
		_ps_animal_node.position.x -= 200.0
		_ps_animal_node.modulate.a = 0.0
		var tween_a: Tween = _create_game_tween()
		tween_a.set_parallel(true)
		tween_a.tween_property(_ps_animal_node, "position", target_pos, 0.35)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween_a.tween_property(_ps_animal_node, "modulate:a", target_modulate.a, 0.25)

	## Картки — каскад справа
	for i: int in range(_ps_food_cards.size()):
		var card: Node2D = _ps_food_cards[i]
		if not is_instance_valid(card):
			continue
		var target_pos: Vector2 = card.position
		card.position.x += 150.0
		card.modulate.a = 0.0
		var tween_c: Tween = _create_game_tween()
		tween_c.tween_interval(0.1 + 0.08 * float(i))
		tween_c.set_parallel(true)
		tween_c.tween_property(card, "position", target_pos, 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween_c.tween_property(card, "modulate:a", 1.0, 0.2)


## Fisher-Yates shuffle для Array[int]
func _ps_shuffle_array(arr: Array[int]) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: int = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## ============================================================
## Спільні функції — viewport resize, clouds, idle, tutorial
## ============================================================

func _on_viewport_resized() -> void:
	if _game_over:
		return
	if _is_preschool:
		_ps_reposition_ui()
		return
	if _round_manager:
		_round_manager.reposition_all()


## Атмосферні хмарки (спільні для обох режимів)
func _start_ambient_clouds() -> void:
	_cloud_timer = Timer.new()
	_cloud_timer.wait_time = randf_range(8.0, 15.0)
	_cloud_timer.one_shot = true
	_cloud_timer.timeout.connect(_on_cloud_timer_timeout)
	add_child(_cloud_timer)
	_cloud_timer.start()


func _on_cloud_timer_timeout() -> void:
	if _game_over:
		return
	var cloud_path: String = "res://scenes/entities/floating_cloud.tscn"
	if not ResourceLoader.exists(cloud_path):
		push_warning("FoodGame: Missing cloud scene: " + cloud_path)
		_cloud_timer.wait_time = randf_range(8.0, 15.0)
		_cloud_timer.start()
		return
	var cloud_scene: PackedScene = load(cloud_path)
	if cloud_scene:
		var cloud: Node2D = cloud_scene.instantiate()
		cloud.position = Vector2(-100, randf_range(30, 200))
		add_child(cloud)
	if is_instance_valid(_cloud_timer):
		_cloud_timer.wait_time = randf_range(8.0, 15.0)
		_cloud_timer.start()


## A10: Idle escalation — 3 рівні (pulse -> stronger -> tutorial hand)
func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_on_idle_timeout):
			_idle_timer.timeout.disconnect(_on_idle_timeout)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_on_idle_timeout)


func _on_idle_timeout() -> void:
	if _game_over or _input_locked:
		return
	## A10: escalation через BaseMiniGame._advance_idle_hint()
	_advance_idle_hint()
	## Перезапустити timer для наступного рівня
	_reset_idle_timer()


## Toddler tutorial — показати руку на першій парі
func _start_tutorial() -> void:
	if not _round_manager:
		push_warning("FoodGame: _round_manager null for tutorial")
		return
	if _round_manager.current_round_food.size() == 0:
		push_warning("FoodGame: no food for tutorial")
		return
	var food: Node2D = _round_manager.current_round_food[0]
	if not is_instance_valid(food):
		push_warning("FoodGame: food[0] invalid for tutorial")
		return
	var food_type: String = food.get_meta("food_type", "")
	if food_type.is_empty():
		push_warning("FoodGame: food has no food_type meta")
		return
	for animal: Node2D in _round_manager.current_round_animals:
		if not is_instance_valid(animal):
			continue
		if GameData.find_correct_food_name(animal.name) == food_type:
			if has_node("TutorialOverlay"):
				$TutorialOverlay.start(food.position, animal.position)
			return


func _stop_tutorial_on_pickup() -> void:
	if has_node("TutorialOverlay") and $TutorialOverlay.visible:
		ProgressManager.has_seen_tutorial = true
		SettingsManager.save_settings()
		$TutorialOverlay.stop()
