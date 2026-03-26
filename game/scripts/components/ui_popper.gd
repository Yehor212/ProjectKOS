class_name UIPopper
extends Node

## Еластична анімація появи/зникнення для UI-панелей.
## Додайте як дочірній вузол до Control. Автоматично запускає pop_in().

const POP_IN_DURATION: float = 0.6
const POP_OUT_DURATION: float = 0.3

var _target: Control = null
var _tween: Tween = null


func _ready() -> void:
	_target = get_parent() as Control
	if not _target:
		push_warning("UIPopper: батьківський вузол не є Control")
		return
	call_deferred("_initialize")


func _initialize() -> void:
	_target.pivot_offset = _target.size / 2.0
	_target.scale = Vector2.ZERO
	pop_in()


func pop_in() -> void:
	if not _target:
		push_warning("UIPopper: немає цільового вузла для pop_in")
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = _target.create_tween()
	_tween.tween_property(_target, "scale", Vector2.ONE, POP_IN_DURATION)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func pop_out(callback: Callable = Callable()) -> void:
	if not _target:
		push_warning("UIPopper: немає цільового вузла для pop_out")
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = _target.create_tween()
	_tween.tween_property(_target, "scale", Vector2.ZERO, POP_OUT_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if callback.is_valid():
		_tween.finished.connect(callback)
