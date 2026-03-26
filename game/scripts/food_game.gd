extends BaseMiniGame

var _round_manager: RoundManager = null
var _drag_controller: DragController = null
var _cloud_timer: Timer = null
var _hint_system: HintSystem = null

## --- Preschool mode: "Шеф-кухар для тварин" ---
var _is_preschool: bool = false
var _ps_current_round: int = 0
const _PS_TOTAL_ROUNDS: int = 5
var _ps_used_indices: Array[int] = []  ## Індекси вже використаних тварин
var _ps_animal_node: Node2D = null  ## Поточна тварина зліва
var _ps_food_cards: Array[Node2D] = []  ## Картки їжі справа
var _ps_correct_food_name: String = ""  ## Правильна їжа для поточного раунду
var _ps_start_time_ms: int = 0
var _ps_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Силуетний шейдер для R5
var _ps_silhouette_shader: Shader = null


func _ready() -> void:
	game_id = "hungry_pets"
	bg_theme = "meadow"
	super()
	_is_preschool = (SettingsManager.age_group == 2)

	if _is_preschool:
		_setup_preschool()
		return

	## --- Toddler mode (існуючий код без змін) ---
	_round_manager = RoundManager.new(self)
	_drag_controller = DragController.new(self, _round_manager)

	_hint_system = HintSystem.new()
	add_child(_hint_system)
	_hint_system.setup(_round_manager, self, $HintButton)
	JuicyEffects.button_press_squish($HintButton, self)

	_drag_controller.food_dropped_on_animal.connect(_on_food_dropped_on_animal)
	_drag_controller.food_dropped_on_empty.connect(_on_food_dropped_on_empty)
	_drag_controller.food_picked_up.connect(_hint_system.stop_idle_timer)
	_round_manager.game_won.connect(_on_game_won)
	_round_manager.mini_game_finished.connect(_on_mini_game_finished)
	_round_manager.round_started.connect(_on_round_started)

	_apply_background()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_round_manager.start_new_round()
	_start_safety_timeout(300.0)  ## 5 хвилин — toddler matching 19 пар
	AnalyticsManager.log_level_start(1)
	if not ProgressManager.has_seen_tutorial:
		_start_tutorial()
		_drag_controller.food_picked_up.connect(_stop_tutorial_on_pickup, CONNECT_ONE_SHOT)
	_cloud_timer = Timer.new()
	_cloud_timer.wait_time = randf_range(8.0, 15.0)
	_cloud_timer.one_shot = true
	_cloud_timer.timeout.connect(_on_cloud_timer_timeout)
	add_child(_cloud_timer)
	_cloud_timer.start()


func _input(event: InputEvent) -> void:
	if _input_locked:
		return
	if _is_preschool:
		return  ## Preschool використовує кнопки, не drag
	_drag_controller.handle_input(event)


func _process(delta: float) -> void:
	if _input_locked:
		return
	if _is_preschool:
		return  ## Preschool не має drag/sleep логіки
	_drag_controller.handle_process(delta)
	## Оновлення сну тварин — засинають при бездіяльності
	var animator: AnimalAnimator = _round_manager.get_animator()
	for animal: Node2D in _round_manager.current_round_animals:
		animator.update_sleep(animal, delta)



func _on_food_dropped_on_animal(food: Node2D, animal: Node2D) -> void:
	_input_locked = true
	_drag_controller.clear_highlight()
	var is_correct: bool = _round_manager.try_match(food, animal)
	AnalyticsManager.log_item_match(animal.name, is_correct)
	if is_correct:
		ProgressManager.unlock_animal(animal.name)
		ProgressManager.increment_animals_fed()
		AudioManager.play_sfx("success", 1.0 + mini(_round_manager.current_combo, 10) * 0.05)
		HapticsManager.vibrate_success()
		VFXManager.spawn_success_ripple(animal.global_position, ThemeManager.COLOR_PRIMARY)
		_register_correct()
		_play_correct_tween(animal, food)
	else:
		## A6: тоддлер — м'який зворотній зв'язок (без sfx("error"))
		AudioManager.play_sfx("click")
		HapticsManager.vibrate_light()
		_play_wrong_tween(animal)
		_round_manager.return_food_to_origin(food)
		_hint_system.check_error_hint(_round_manager.errors_made)
	_hint_system.start_idle_timer()


func _on_food_dropped_on_empty(food: Node2D) -> void:
	_input_locked = true
	HapticsManager.vibrate_light()
	_round_manager.reset_combo()
	var tween: Tween = _round_manager.return_food_to_origin(food)
	if tween:
		tween.finished.connect(func(): _input_locked = false)
	else:
		_input_locked = false
	_hint_system.start_idle_timer()


func _on_game_won(stats: Dictionary) -> void:
	_game_over = true
	_input_locked = true
	_hint_system.stop_idle_timer()
	## LAW 16: єдине джерело зірок — _calculate_stars()
	var earned: int = _calculate_stars(_errors)
	stats["earned_stars"] = earned
	finish_game(earned, stats)


func _on_mini_game_finished(stats: Dictionary) -> void:
	_game_over = true
	_input_locked = true
	_hint_system.stop_idle_timer()
	## LAW 16: єдине джерело зірок — _calculate_stars()
	var earned: int = _calculate_stars(_errors)
	stats["earned_stars"] = earned
	finish_game(earned, stats)


func _on_viewport_resized() -> void:
	if _game_over:
		return
	if _is_preschool:
		_ps_reposition_ui()
		return
	_round_manager.reposition_all()



func _play_correct_tween(animal: Node2D, food: Node2D) -> void:
	_round_manager.get_animator().play_happy(animal)
	## Затримка для шейдерної анімації, потім recycle
	var tween: Tween = create_tween()
	tween.tween_interval(0.8)
	tween.finished.connect(func() -> void:
		if is_instance_valid(animal):
			_round_manager.recycle_animal(animal)
		if is_instance_valid(food):
			_round_manager.recycle_food(food)
		if not _game_over:
			_round_manager.add_new_pair_if_needed()
			_input_locked = false
	)


func _play_wrong_tween(animal: Node2D) -> void:
	_round_manager.get_animator().play_sad(animal)
	var tween: Tween = create_tween()
	tween.tween_interval(0.5)
	tween.finished.connect(func() -> void:
		_input_locked = false
	)


func _on_cloud_timer_timeout() -> void:
	if _game_over:
		return
	var cloud_path: String = "res://scenes/entities/floating_cloud.tscn"
	if not ResourceLoader.exists(cloud_path):
		push_warning("FoodGame: Missing cloud scene: " + cloud_path)
		return
	var cloud_scene: PackedScene = load(cloud_path)
	if cloud_scene:
		var cloud: Node2D = cloud_scene.instantiate()
		cloud.position = Vector2(-100, randf_range(30, 200))
		add_child(cloud)
	_cloud_timer.wait_time = randf_range(8.0, 15.0)
	_cloud_timer.start()


func _on_round_started() -> void:
	_input_locked = false  ## Розблокувати ввід після початку раунду
	_hint_system.on_round_started()




func _start_tutorial() -> void:
	if _round_manager.current_round_food.size() == 0:
		push_warning("FoodGame: no food for tutorial")
		return
	var food: Node2D = _round_manager.current_round_food[0]
	if not is_instance_valid(food):
		push_warning("FoodGame: food[0] invalid for tutorial")
		return
	var food_type: String = food.get_meta("food_type")
	for animal: Node2D in _round_manager.current_round_animals:
		if GameData.find_correct_food_name(animal.name) == food_type:
			$TutorialOverlay.start(food.position, animal.position)
			return


func _stop_tutorial_on_pickup() -> void:
	if $TutorialOverlay.visible:
		ProgressManager.has_seen_tutorial = true
		SettingsManager.save_settings()
		$TutorialOverlay.stop()


## ============================================================
## PRESCHOOL MODE — "Шеф-кухар для тварин"
## Тап-механіка: тварина зліва, 3-4 картки їжі справа.
## Повністю автономний від RoundManager/DragController.
## ============================================================


## Ініціалізація Preschool-режиму
func _setup_preschool() -> void:
	_ps_rng.randomize()
	_ps_start_time_ms = Time.get_ticks_msec()
	## Сховати HintButton — Preschool не використовує HintSystem
	if has_node("HintButton"):
		$HintButton.visible = false
	## Завантажити силуетний шейдер для R5
	var shader_path: String = "res://assets/shaders/silhouette.gdshader"
	if ResourceLoader.exists(shader_path):
		_ps_silhouette_shader = load(shader_path)
	_apply_background()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_start_safety_timeout(180.0)  ## 3 хвилини — preschool 5 раундів
	AnalyticsManager.log_level_start(1)
	## Запустити хмарки — атмосфера спільна для обох режимів
	_cloud_timer = Timer.new()
	_cloud_timer.wait_time = randf_range(8.0, 15.0)
	_cloud_timer.one_shot = true
	_cloud_timer.timeout.connect(_on_cloud_timer_timeout)
	add_child(_cloud_timer)
	_cloud_timer.start()
	## Перший раунд
	_ps_start_round()


## Очищення поточного Preschool-раунду
func _ps_cleanup_round() -> void:
	if is_instance_valid(_ps_animal_node):
		_ps_animal_node.queue_free()
	_ps_animal_node = null
	for card: Node2D in _ps_food_cards:
		if is_instance_valid(card):
			card.queue_free()
	_ps_food_cards.clear()
	_ps_correct_food_name = ""


## Кількість карток їжі для поточного раунду
func _ps_get_options_count() -> int:
	## R1-2: 3 варіанти, R3-5: 4 варіанти
	if _ps_current_round < 2:
		return 3
	return 4


## Обрати випадковий індекс тварини, що ще не використовувалась
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
	var pick: int = _ps_rng.randi_range(0, available.size() - 1)
	return available[pick]


## Обрати дистрактори (неправильні їжі) для поточного раунду
func _ps_pick_distractors(correct_idx: int, count: int) -> Array[int]:
	var result: Array[int] = []
	var attempts: int = 0
	while result.size() < count and attempts < 100:
		attempts += 1
		var idx: int = _ps_rng.randi_range(0, GameData.ANIMALS_AND_FOOD.size() - 1)
		if idx == correct_idx or result.has(idx):
			continue
		result.append(idx)
	return result


## Запустити новий Preschool-раунд
func _ps_start_round() -> void:
	_ps_cleanup_round()
	_input_locked = true

	if _ps_current_round >= _PS_TOTAL_ROUNDS:
		push_warning("FoodGame Preschool: спроба почати раунд понад ліміт")
		return

	## Обрати тварину
	var animal_idx: int = _ps_pick_animal_index()
	_ps_used_indices.append(animal_idx)
	var pair: Dictionary = GameData.ANIMALS_AND_FOOD[animal_idx]
	_ps_correct_food_name = GameData.get_food_name_from_scene(pair.food_scene)

	## Створити спрайт тварини
	var animal_scene: PackedScene = pair.animal_scene
	_ps_animal_node = animal_scene.instantiate()
	_ps_animal_node.name = pair.name
	add_child(_ps_animal_node)

	## R5: силует тварини (складніше розпізнавання)
	if _ps_current_round >= 4 and _ps_silhouette_shader:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = _ps_silhouette_shader
		mat.set_shader_parameter("silhouette_color", Color(0.15, 0.15, 0.2, 1.0))
		_ps_animal_node.material = mat

	## Зібрати набір їжі: 1 правильна + дистрактори
	var options_count: int = _ps_get_options_count()
	var distractor_indices: Array[int] = _ps_pick_distractors(animal_idx, options_count - 1)
	var food_indices: Array[int] = [animal_idx]
	food_indices.append_array(distractor_indices)

	## Перемішати порядок їжі
	var shuffled: Array[int] = food_indices.duplicate()
	_ps_shuffle_array(shuffled)

	## Створити картки їжі як тап-кнопки
	for i: int in range(shuffled.size()):
		var food_pair: Dictionary = GameData.ANIMALS_AND_FOOD[shuffled[i]]
		var food_name: String = GameData.get_food_name_from_scene(food_pair.food_scene)
		var card: Node2D = _ps_create_food_card(food_pair.food_scene, food_name)
		add_child(card)
		_ps_food_cards.append(card)

	## Позиціонування елементів
	_ps_reposition_ui()

	## Анімація появи (каскад)
	_ps_animate_entrance()

	## Розблокувати ввід після анімації
	var unlock_tween: Tween = create_tween()
	unlock_tween.tween_interval(0.4)
	unlock_tween.finished.connect(func() -> void:
		_input_locked = false
	)


## Створити картку їжі з кнопкою для тапу
func _ps_create_food_card(food_scene: PackedScene, food_name: String) -> Node2D:
	var container: Node2D = Node2D.new()
	container.set_meta("food_name", food_name)

	## Спрайт їжі
	var food_sprite: Node2D = food_scene.instantiate()
	food_sprite.scale = Vector2(0.3, 0.3)
	container.add_child(food_sprite)

	## Невидима кнопка поверх спрайту для обробки тапу
	var btn: Button = Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(120, 120)
	btn.position = Vector2(-60, -60)  ## Центрування кнопки
	btn.modulate = Color(1, 1, 1, 0)  ## Повністю прозора
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_ps_on_food_tapped.bind(container))
	container.add_child(btn)

	return container


## Обробка тапу на картку їжі
func _ps_on_food_tapped(card: Node2D) -> void:
	if _input_locked or _game_over:
		return
	_input_locked = true

	var tapped_name: String = card.get_meta("food_name", "")
	var is_correct: bool = (tapped_name == _ps_correct_food_name)

	AnalyticsManager.log_item_match(_ps_animal_node.name if is_instance_valid(_ps_animal_node) else "unknown", is_correct)

	if is_correct:
		## Правильна відповідь
		if is_instance_valid(_ps_animal_node):
			ProgressManager.unlock_animal(_ps_animal_node.name)
		ProgressManager.increment_animals_fed()
		_register_correct(card)
		_ps_animate_correct(card)
	else:
		## Помилка — рахується, картка вимикається
		_errors += 1
		_register_error(card)
		_ps_animate_wrong(card)


## Анімація правильної відповіді + перехід до наступного раунду
func _ps_animate_correct(card: Node2D) -> void:
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()

	## Масштабування + fade тварини (вона наїлась)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if is_instance_valid(_ps_animal_node):
		tween.tween_property(_ps_animal_node, "scale",
			_ps_animal_node.scale * 1.15, 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	## Підсвітка правильної картки
	if is_instance_valid(card):
		tween.tween_property(card, "modulate", Color(0.5, 1.0, 0.5, 1.0), 0.2)
	tween.set_parallel(false)
	tween.tween_interval(0.6)
	tween.finished.connect(func() -> void:
		_ps_current_round += 1
		if _ps_current_round >= _PS_TOTAL_ROUNDS:
			_ps_finish_game()
		else:
			_ps_start_round()
	)


## Анімація неправильної відповіді — вимкнути картку, не блокувати гру
func _ps_animate_wrong(card: Node2D) -> void:
	AudioManager.play_sfx("error")
	HapticsManager.vibrate_light()

	## Smoke VFX на позиції неправильної картки
	if is_instance_valid(card):
		VFXManager.spawn_error_smoke(card.global_position)

	## Wobble + затемнення неправильної картки
	var tween: Tween = create_tween()
	if is_instance_valid(card):
		tween.tween_property(card, "rotation", deg_to_rad(8.0), 0.05)
		tween.tween_property(card, "rotation", deg_to_rad(-8.0), 0.1)
		tween.tween_property(card, "rotation", 0.0, 0.05)
		tween.tween_property(card, "modulate", Color(0.4, 0.4, 0.4, 0.5), 0.3)
	tween.finished.connect(func() -> void:
		## Вимкнути кнопку в картці після помилки
		if is_instance_valid(card):
			var btn: Button = _ps_find_button(card)
			if btn:
				btn.disabled = true
		_input_locked = false
	)


## Знайти Button у контейнері картки
func _ps_find_button(card: Node2D) -> Button:
	for child: Node in card.get_children():
		if child is Button:
			return child as Button
	return null


## Завершення Preschool-гри
func _ps_finish_game() -> void:
	_game_over = true
	_input_locked = true
	var elapsed_ms: int = Time.get_ticks_msec() - _ps_start_time_ms
	var stats: Dictionary = {
		"time_sec": elapsed_ms / 1000.0,
		"errors": _errors,
		"rounds_played": _ps_current_round,
	}
	var earned: int = _calculate_stars(_errors)
	stats["earned_stars"] = earned
	finish_game(earned, stats)


## Позиціонування Preschool UI — тварина зліва, їжа справа
func _ps_reposition_ui() -> void:
	var vp_size: Vector2 = get_viewport_rect().size

	## Тварина: ліва частина екрану, по центру вертикально
	if is_instance_valid(_ps_animal_node):
		_ps_animal_node.position = Vector2(vp_size.x * 0.22, vp_size.y * 0.45)
		## Масштаб ~180dp (пропорційний, не домінує екран)
		var animal_scale: float = (vp_size.x * 0.16) / 512.0
		_ps_animal_node.scale = Vector2(animal_scale, animal_scale)

	## Картки їжі: права частина, рівномірно по вертикалі
	var card_count: int = _ps_food_cards.size()
	if card_count == 0:
		return
	var right_x: float = vp_size.x * 0.7
	var card_area_top: float = vp_size.y * 0.15
	var card_area_bottom: float = vp_size.y * 0.85
	var spacing: float = (card_area_bottom - card_area_top) / maxf(1.0, float(card_count - 1)) if card_count > 1 else 0.0

	for i: int in range(card_count):
		var card: Node2D = _ps_food_cards[i]
		if not is_instance_valid(card):
			continue
		var y_pos: float = card_area_top + spacing * float(i) if card_count > 1 else vp_size.y * 0.5
		card.position = Vector2(right_x, y_pos)


## Каскадна анімація появи елементів
func _ps_animate_entrance() -> void:
	## Тварина — з'являється зліва
	if is_instance_valid(_ps_animal_node):
		var target_pos: Vector2 = _ps_animal_node.position
		_ps_animal_node.position.x -= 200.0
		_ps_animal_node.modulate.a = 0.0
		var tween_a: Tween = create_tween()
		tween_a.set_parallel(true)
		tween_a.tween_property(_ps_animal_node, "position", target_pos, 0.35)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween_a.tween_property(_ps_animal_node, "modulate:a", 1.0, 0.25)

	## Картки — з'являються каскадом справа
	for i: int in range(_ps_food_cards.size()):
		var card: Node2D = _ps_food_cards[i]
		if not is_instance_valid(card):
			continue
		var target_pos: Vector2 = card.position
		card.position.x += 150.0
		card.modulate.a = 0.0
		var tween_c: Tween = create_tween()
		tween_c.tween_interval(0.1 + 0.08 * float(i))  ## Каскадна затримка
		tween_c.set_parallel(true)
		tween_c.tween_property(card, "position", target_pos, 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween_c.tween_property(card, "modulate:a", 1.0, 0.2)


## Fisher-Yates shuffle для Array[int] (GDScript .shuffle() не гарантує тип)
func _ps_shuffle_array(arr: Array[int]) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = _ps_rng.randi_range(0, i)
		var tmp: int = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
