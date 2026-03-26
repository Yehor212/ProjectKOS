extends Node2D

## Безсловесний туторіал — рука показує drag-and-drop з press/release анімацією.

const PRESS_SCALE: Vector2 = Vector2(0.7, 0.7)
const RELEASE_SCALE: Vector2 = Vector2(1.0, 1.0)
const MOVE_DURATION: float = 1.2
const PAUSE_DURATION: float = 0.4

var _active: bool = false


func _ready() -> void:
	## Код-малювана іконка замість емоджі
	var hand: Control = IconDraw.tap_finger(48.0, Color("FFD166"))
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HandLabel.add_child(hand)


func start(food_pos: Vector2, animal_pos: Vector2) -> void:
	_active = true
	visible = true
	$HandLabel.position = food_pos + Vector2(0, -40)
	$HandLabel.scale = RELEASE_SCALE
	$HintLabel.position = Vector2(_get_viewport_center_x(), 10)
	$HintLabel.text = tr("MSG_TUTORIAL")
	_run_loop(food_pos + Vector2(0, -40), animal_pos + Vector2(0, -40))


func stop() -> void:
	_active = false
	visible = false


func _get_viewport_center_x() -> float:
	return get_viewport_rect().size.x / 2.0 - 100.0


func _run_loop(from: Vector2, to: Vector2) -> void:
	if not _active:
		return
	$HandLabel.position = from
	$HandLabel.scale = RELEASE_SCALE
	var tween: Tween = create_tween()
	tween.tween_property($HandLabel, "scale", PRESS_SCALE, 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property($HandLabel, "position", to, MOVE_DURATION)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property($HandLabel, "scale", RELEASE_SCALE, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(PAUSE_DURATION)
	tween.finished.connect(func() -> void: _run_loop(from, to))
