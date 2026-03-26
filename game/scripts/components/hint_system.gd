class_name HintSystem
extends Node

## Система підказок — показує пульсацію правильної тварини при бездіяльності
## або після кількох помилок. Керує кнопкою підказки та інвентарем.

const IDLE_TIMEOUT: float = 5.0
const ERROR_THRESHOLD: int = 2
const PULSE_SCALE_FACTOR: float = 1.1
const PULSE_DURATION: float = 0.3
const PULSE_LOOPS: int = 3

var _round_manager: RoundManager = null
var _scene_root: Node2D = null
var _hint_button: Button = null
var _idle_timer: Timer = null
var _round_start_errors: int = 0
var _hint_tween: Tween = null


func setup(round_manager: RoundManager, scene_root: Node2D, hint_button: Button) -> void:
	_round_manager = round_manager
	_scene_root = scene_root
	_hint_button = hint_button

	_idle_timer = Timer.new()
	_idle_timer.wait_time = IDLE_TIMEOUT
	_idle_timer.one_shot = true
	_idle_timer.timeout.connect(_on_idle_timer_timeout)
	add_child(_idle_timer)

	if _hint_button:
		_hint_button.pressed.connect(_on_hint_button_pressed)

	update_hint_button()


func start_idle_timer() -> void:
	if _idle_timer:
		_idle_timer.start()


func stop_idle_timer() -> void:
	if _idle_timer:
		_idle_timer.stop()


func on_round_started() -> void:
	_round_start_errors = _round_manager.errors_made
	start_idle_timer()


func check_error_hint(current_errors: int) -> void:
	if current_errors - _round_start_errors >= ERROR_THRESHOLD:
		show_hint()


func show_hint() -> void:
	if _round_manager.current_round_food.size() == 0:
		push_warning("HintSystem: немає їжі для підказки")
		return
	var food: Node2D = _round_manager.current_round_food[0]
	if not is_instance_valid(food):
		push_warning("HintSystem: food[0] не валідний")
		return
	var food_type: String = food.get_meta("food_type")
	for animal: Node2D in _round_manager.current_round_animals:
		if GameData.find_correct_food_name(animal.name) == food_type:
			_pulse_hint(animal)
			return


func update_hint_button() -> void:
	if not _hint_button:
		push_warning("HintSystem: кнопка підказки не задана")
		return
	_hint_button.text = tr("LBL_HINT") % ProgressManager.inventory_hints
	_hint_button.disabled = ProgressManager.inventory_hints <= 0


func _on_idle_timer_timeout() -> void:
	if _scene_root and not _scene_root.get("_game_finished"):
		show_hint()


func _on_hint_button_pressed() -> void:
	if ProgressManager.use_hint():
		show_hint()
		update_hint_button()


func _pulse_hint(target: Node2D) -> void:
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	var base_scale: Vector2 = target.scale
	_hint_tween = _scene_root.create_tween()
	_hint_tween.set_loops(PULSE_LOOPS)
	_hint_tween.tween_property(target, "scale", base_scale * PULSE_SCALE_FACTOR, PULSE_DURATION)
	_hint_tween.tween_property(target, "scale", base_scale, PULSE_DURATION)
