class_name TutorialSystem
extends Node

## Керує показом TutorialHand — автоматично при першому запуску + при idle.

const IDLE_TIMEOUT: float = 8.0
const STARTUP_DELAY: float = 1.0

var _hand: TutorialHand = null
var _idle_timer: Timer = null
var _game: BaseMiniGame = null
var _demo_data: Dictionary = {}


func setup(game: BaseMiniGame) -> void:
	_game = game
	_hand = TutorialHand.new()
	game.add_child(_hand)
	## Idle timer
	_idle_timer = Timer.new()
	_idle_timer.wait_time = IDLE_TIMEOUT
	_idle_timer.one_shot = true
	_idle_timer.timeout.connect(_on_idle_timeout)
	add_child(_idle_timer)
	## Запуск з невеликою затримкою (позиції мають встигнути сформуватися)
	var startup: SceneTreeTimer = game.get_tree().create_timer(STARTUP_DELAY)
	startup.timeout.connect(_on_startup)
	## Автоматичне виявлення вводу — зупиняє руку при дотику/кліку
	set_process_input(true)


func _on_startup() -> void:
	if not is_instance_valid(_game) or _game._game_finished:
		return
	_demo_data = _game.get_tutorial_demo()
	if _demo_data.is_empty():
		return
	## Перший запуск гри — показати одразу
	if not ProgressManager.has_played_game(_game.game_id):
		_show_demo()
	_idle_timer.start()


func _on_idle_timeout() -> void:
	if not is_instance_valid(_game) or _game._game_finished:
		return
	## Оновити позиції (можуть змінитися між раундами)
	_demo_data = _game.get_tutorial_demo()
	if not _demo_data.is_empty():
		_show_demo()


func _show_demo() -> void:
	if _hand:
		_hand.start_demo(_demo_data)


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_game) or _game._game_finished:
		return
	var is_press: bool = false
	if event is InputEventMouseButton and event.pressed:
		is_press = true
	elif event is InputEventScreenTouch and event.pressed and event.index == 0:
		is_press = true
	if is_press:
		on_player_input()


func on_player_input() -> void:
	if _hand and _hand.visible:
		_hand.stop()
	reset_idle()


func reset_idle() -> void:
	if _idle_timer and is_instance_valid(_game) and not _game._game_finished:
		_idle_timer.start()


## Scaffold підказка — примусовий показ руки з оновленими позиціями.
func show_scaffold_hint() -> void:
	if not is_instance_valid(_game) or _game._game_finished:
		return
	_demo_data = _game.get_tutorial_demo()
	if not _demo_data.is_empty():
		_show_demo()
