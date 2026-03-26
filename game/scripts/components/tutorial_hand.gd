class_name TutorialHand
extends Node2D

## Універсальна рука-підказка — показує перший крок без слів.
## Типи: "drag" (from->to), "tap" (пульсація на цілі).

const PRESS_SCALE: Vector2 = Vector2(0.7, 0.7)
const RELEASE_SCALE: Vector2 = Vector2(1.0, 1.0)
const MOVE_DURATION: float = 1.2
const PAUSE_BEFORE: float = 0.3
const PAUSE_AFTER: float = 0.6
const HAND_FONT_SIZE: int = 48

var _active: bool = false
var _hand: Control = null
var _tween: Tween = null
var _hand_center: Vector2 = Vector2.ZERO  ## Центр іконки для позиціювання


func _ready() -> void:
	visible = false
	z_index = 100
	_hand = IconDraw.tap_finger(float(HAND_FONT_SIZE), Color("FFD166"))
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.pivot_offset = _hand.custom_minimum_size * 0.5
	_hand_center = _hand.custom_minimum_size * 0.5
	add_child(_hand)


func start_demo(data: Dictionary) -> void:
	if data.is_empty():
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_active = true
	visible = true
	modulate.a = 0.0
	var fade_tw: Tween = create_tween()
	fade_tw.tween_property(self, "modulate:a", 1.0, 0.2)
	var demo_type: String = data.get("type", "")
	match demo_type:
		"drag":
			_run_drag_loop(data.get("from", Vector2.ZERO), data.get("to", Vector2.ZERO))
		"tap":
			_run_tap_loop(data.get("target", Vector2.ZERO))
		_:
			push_warning("TutorialHand: невідомий тип '%s'" % demo_type)
			stop()


func stop() -> void:
	_active = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	var fade_tw: Tween = create_tween()
	fade_tw.tween_property(self, "modulate:a", 0.0, 0.15)
	fade_tw.tween_callback(func() -> void: visible = false)


func _run_drag_loop(from: Vector2, to: Vector2) -> void:
	if not _active:
		return
	_hand.position = from - _hand_center
	_hand.scale = RELEASE_SCALE
	_tween = create_tween()
	_tween.tween_interval(PAUSE_BEFORE)
	_tween.tween_property(_hand, "scale", PRESS_SCALE, 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_hand, "position", to - _hand_center, MOVE_DURATION)\
		.set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_hand, "scale", RELEASE_SCALE, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(PAUSE_AFTER)
	_tween.finished.connect(func() -> void:
		if is_instance_valid(self) and _active:
			_run_drag_loop(from, to))


func _run_tap_loop(target: Vector2) -> void:
	if not _active:
		return
	_hand.position = target - _hand_center
	_hand.scale = RELEASE_SCALE
	_tween = create_tween()
	_tween.tween_interval(PAUSE_BEFORE)
	_tween.tween_property(_hand, "scale", PRESS_SCALE, 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_hand, "scale", RELEASE_SCALE, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(PAUSE_AFTER)
	_tween.finished.connect(func() -> void:
		if is_instance_valid(self) and _active:
			_run_tap_loop(target))
