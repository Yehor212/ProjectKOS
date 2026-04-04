class_name SessionTimer
extends Node

## LAW 26: Таймер здоров'я сесії — м'який нагадувач про перерву.
## Після session_limit_minutes безперервної гри показує оверлей.
## Закривається через parental gate (утримання 3 пальців).

const CHECK_INTERVAL: float = 30.0  ## Перевірка кожні 30 секунд

var _elapsed_sec: float = 0.0
var _paused: bool = false
var _overlay_shown: bool = false
var _overlay: CanvasLayer = null
var _gate_active: bool = false
var _gate_progress: float = 0.0
var _gate_bar: ColorRect = null
var _active_touches: Dictionary = {}
const GATE_HOLD_TIME: float = 2.0
const GATE_REQUIRED_TOUCHES: int = 3


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _overlay_shown:
		_process_gate(delta)
		return
	if _paused:
		return
	var limit: int = SettingsManager.session_limit_minutes
	if limit <= 0:
		return  ## Вимкнено
	_elapsed_sec += delta
	var limit_sec: float = float(limit) * 60.0
	if _elapsed_sec >= limit_sec:
		_show_break_overlay()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_paused = false


func _show_break_overlay() -> void:
	if _overlay_shown:
		return
	_overlay_shown = true
	_gate_active = true
	_gate_progress = 0.0
	_active_touches.clear()

	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)

	## Тло
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.1, 0.15, 0.3, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(bg)

	var vp: Vector2 = get_viewport().get_visible_rect().size

	## Іконка «час відпочити» (IconDraw, zero-text, LAW 16)
	var sleepy_icon: Control = IconDraw.sleepy_face(80.0)
	sleepy_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sleepy_center: CenterContainer = CenterContainer.new()
	sleepy_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sleepy_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sleepy_center.offset_top = -120.0
	sleepy_center.offset_bottom = -20.0
	sleepy_center.offset_left = -100.0
	sleepy_center.offset_right = 100.0
	sleepy_center.add_child(sleepy_icon)
	bg.add_child(sleepy_center)

	## М'яка пульсація іконки
	if not SettingsManager.reduced_motion:
		sleepy_center.pivot_offset = Vector2(100, 50)
		var tw: Tween = create_tween().set_loops()
		tw.tween_property(sleepy_center, "scale", Vector2(1.1, 1.1), 1.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sleepy_center, "scale", Vector2.ONE, 1.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	## Підказка для батьків (IconDraw рука)
	var hand_icon: Control = IconDraw.open_hand(40.0)
	hand_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hand_center: CenterContainer = CenterContainer.new()
	hand_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hand_center.offset_top = 20.0
	hand_center.offset_bottom = 80.0
	hand_center.offset_left = -60.0
	hand_center.offset_right = 60.0
	hand_center.add_child(hand_icon)
	bg.add_child(hand_center)

	## Прогрес-бар
	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.15)
	bar_bg.custom_minimum_size = Vector2(200.0, 10.0)
	bar_bg.position = Vector2(vp.x / 2.0 - 100.0, vp.y / 2.0 + 100.0)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(bar_bg)

	_gate_bar = ColorRect.new()
	_gate_bar.color = Color("22c55e")
	_gate_bar.custom_minimum_size = Vector2(200.0, 10.0)
	_gate_bar.position = bar_bg.position
	_gate_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gate_bar.pivot_offset = Vector2(0.0, 5.0)
	_gate_bar.scale = Vector2(0.0, 1.0)
	bg.add_child(_gate_bar)

	get_tree().paused = true


func _input(event: InputEvent) -> void:
	if not _gate_active:
		return
	## Debug bypass: Ctrl+Shift+G для проходження session gate на десктопі
	if OS.is_debug_build() and event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.ctrl_pressed and key.shift_pressed and key.keycode == KEY_G:
			_active_touches = {0: true, 1: true, 2: true}
		elif not key.pressed:
			_active_touches.clear()
			_gate_progress = 0.0
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_active_touches[touch.index] = true
		else:
			_active_touches.erase(touch.index)
			if _active_touches.size() < GATE_REQUIRED_TOUCHES:
				_gate_progress = 0.0
				if _gate_bar:
					_gate_bar.scale = Vector2(0.0, 1.0)


func _process_gate(delta: float) -> void:
	if not _gate_active:
		return
	if _active_touches.size() >= GATE_REQUIRED_TOUCHES:
		_gate_progress += delta
		if _gate_bar:
			var fill: float = clampf(_gate_progress / GATE_HOLD_TIME, 0.0, 1.0)
			_gate_bar.scale = Vector2(fill, 1.0)
		if _gate_progress >= GATE_HOLD_TIME:
			_dismiss_overlay()
	else:
		if _gate_progress > 0.0:
			_gate_progress = 0.0
			if _gate_bar:
				_gate_bar.scale = Vector2(0.0, 1.0)


func _dismiss_overlay() -> void:
	_gate_active = false
	_overlay_shown = false
	_elapsed_sec = 0.0  ## Скинути таймер для нової сесії
	AudioManager.play_sfx("success")
	get_tree().paused = false
	if _overlay:
		_overlay.queue_free()
		_overlay = null
