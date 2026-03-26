class_name ExitConfirmOverlay
extends CanvasLayer

## Підтвердження виходу — два великих іконкових кнопки (без тексту).
## LAW 27: Parental gate — утримання 3 пальців 2 секунди для виходу.

signal confirmed_exit
signal cancelled

const BTN_SIZE: float = 96.0
const ICON_SIZE: float = 48.0
const BTN_GAP: float = 48.0
const GATE_HOLD_TIME: float = 2.0  ## Час утримання 3 пальців (секунди)
const GATE_REQUIRED_TOUCHES: int = 3  ## Мінімум пальців для parental gate

var _overlay: ColorRect = null
var _resume_btn: Button = null
var _exit_btn: Button = null
## Parental gate стан
var _gate_active: bool = false
var _gate_progress: float = 0.0
var _gate_label: Control = null
var _gate_progress_bar: Panel = null
var _gate_bg: Panel = null
var _gate_cancel_btn: Button = null  ## Кнопка скасування gate (для desktop)
var _active_touches: Dictionary = {}  ## touch_index → true


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	## Напівпрозоре тло
	_overlay = ColorRect.new()
	var overlay: ColorRect = _overlay
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	## Grain overlay на exit confirm (LAW 28)
	overlay.material = GameData.create_premium_material(0.02, 2.0, 0.04, 0.06, 0.03, 0.04, 0.10, "", 0.0, 0.08, 0.18, 0.15)
	add_child(overlay)

	## Центрований контейнер
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.set("theme_override_constants/separation", int(BTN_GAP))
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(hbox)

	## Кнопка «Продовжити» — зелена з іконкою play
	_resume_btn = _make_icon_button("green", IconDraw.play_triangle(36.0))
	_resume_btn.pressed.connect(_on_resume)
	hbox.add_child(_resume_btn)
	JuicyEffects.button_press_squish(_resume_btn, self)

	## Кнопка «Вийти» — червона зі стрілкою назад
	_exit_btn = _make_icon_button("red", IconDraw.arrow_left(36.0))
	_exit_btn.pressed.connect(_on_exit_pressed)
	hbox.add_child(_exit_btn)
	JuicyEffects.button_press_squish(_exit_btn, self)


func show_dialog() -> void:
	_gate_active = false
	_gate_progress = 0.0
	_active_touches.clear()
	visible = true
	get_tree().paused = true
	## Показати кнопки, сховати gate
	if _gate_label:
		_gate_label.visible = false
	if _gate_progress_bar:
		_gate_progress_bar.visible = false
	if _gate_bg:
		_gate_bg.visible = false
	if _gate_cancel_btn:
		_gate_cancel_btn.visible = false
	_resume_btn.visible = true
	_exit_btn.visible = true
	## Анімація входу: фон fade + кнопки stagger pop-in
	_overlay.modulate.a = 0.0
	_resume_btn.scale = Vector2.ZERO
	_resume_btn.pivot_offset = Vector2(BTN_SIZE, BTN_SIZE) / 2.0
	_exit_btn.scale = Vector2.ZERO
	_exit_btn.pivot_offset = Vector2(BTN_SIZE, BTN_SIZE) / 2.0
	var tw: Tween = create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(_resume_btn, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_exit_btn, "scale", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(0.1)


func _animate_out(callback: Callable) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_resume_btn, "scale", Vector2.ZERO, 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_exit_btn, "scale", Vector2.ZERO, 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_overlay, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(callback)


func _on_resume() -> void:
	AudioManager.play_sfx("click")
	_gate_active = false
	_animate_out(func() -> void:
		visible = false
		get_tree().paused = false
		cancelled.emit())


func _on_exit_pressed() -> void:
	## LAW 27: Показати parental gate замість негайного виходу
	AudioManager.play_sfx("click")
	_gate_active = true
	_gate_progress = 0.0
	_active_touches.clear()
	## Сховати кнопки, показати gate інструкцію
	_resume_btn.visible = false
	_exit_btn.visible = false
	_ensure_gate_ui()
	_gate_label.visible = true
	_gate_progress_bar.visible = true
	_gate_bg.visible = true
	_gate_progress_bar.scale = Vector2(0.0, 1.0)
	if _gate_cancel_btn:
		_gate_cancel_btn.visible = true


## Створити UI елементи parental gate (лінивий init)
func _ensure_gate_ui() -> void:
	if _gate_label:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Іконка 3 пальців (IconDraw, zero-text підхід)
	var hand_icon: Control = IconDraw.open_hand(64.0)
	hand_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gate_label = CenterContainer.new()
	_gate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gate_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_gate_label.offset_top = -80.0
	_gate_label.offset_bottom = 0.0
	_gate_label.offset_left = -100.0
	_gate_label.offset_right = 100.0
	_gate_label.add_child(hand_icon)
	_overlay.add_child(_gate_label)
	## Прогрес-бар (candy pill з depth — LAW 28)
	_gate_bg = Panel.new()
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(1, 1, 1, 0.12)
	bg_style.set_corner_radius_all(8)
	bg_style.anti_aliasing_size = 1.0
	bg_style.set_border_width_all(1)
	bg_style.border_color = Color(1, 1, 1, 0.08)
	_gate_bg.add_theme_stylebox_override("panel", bg_style)
	_gate_bg.custom_minimum_size = Vector2(240.0, 16.0)
	_gate_bg.position = Vector2(vp.x / 2.0 - 120.0, vp.y / 2.0 + 30.0)
	_gate_bg.size = Vector2(240.0, 16.0)
	_gate_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_gate_bg)
	_gate_progress_bar = Panel.new()
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = ThemeManager.COLOR_SUCCESS.lightened(0.06)
	fill_style.set_corner_radius_all(8)
	fill_style.anti_aliasing_size = 1.0
	fill_style.border_width_bottom = 2
	fill_style.border_width_left = 1
	fill_style.border_width_right = 1
	fill_style.border_width_top = 0
	fill_style.border_color = ThemeManager.COLOR_SUCCESS.darkened(0.22)
	fill_style.shadow_color = Color(ThemeManager.COLOR_SUCCESS.darkened(0.5), 0.3)
	fill_style.shadow_size = 2
	fill_style.shadow_offset = Vector2(0, 1)
	_gate_progress_bar.add_theme_stylebox_override("panel", fill_style)
	_gate_progress_bar.custom_minimum_size = Vector2(240.0, 16.0)
	_gate_progress_bar.size = Vector2(240.0, 16.0)
	_gate_progress_bar.position = _gate_bg.position
	_gate_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gate_progress_bar.pivot_offset = Vector2(0.0, 8.0)
	_gate_progress_bar.scale = Vector2(0.0, 1.0)
	_overlay.add_child(_gate_progress_bar)
	## Кнопка скасування gate — повертає до resume/exit кнопок
	_gate_cancel_btn = _make_icon_button("green", IconDraw.play_triangle(28.0))
	_gate_cancel_btn.position = Vector2(vp.x / 2.0 - BTN_SIZE / 2.0, vp.y / 2.0 + 64.0)
	_gate_cancel_btn.pressed.connect(_cancel_gate)
	_gate_cancel_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(_gate_cancel_btn)
	JuicyEffects.button_press_squish(_gate_cancel_btn, self)


func _input(event: InputEvent) -> void:
	if not _gate_active:
		return
	## Відстежувати кількість одночасних дотиків
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_active_touches[touch.index] = true
		else:
			_active_touches.erase(touch.index)
			## Якщо відпустили — скинути прогрес
			if _active_touches.size() < GATE_REQUIRED_TOUCHES:
				_gate_progress = 0.0
				if _gate_progress_bar:
					_gate_progress_bar.scale = Vector2(0.0, 1.0)


func _process(delta: float) -> void:
	if not _gate_active:
		return
	if _active_touches.size() >= GATE_REQUIRED_TOUCHES:
		_gate_progress += delta
		if _gate_progress_bar:
			var fill: float = clampf(_gate_progress / GATE_HOLD_TIME, 0.0, 1.0)
			_gate_progress_bar.scale = Vector2(fill, 1.0)
		if _gate_progress >= GATE_HOLD_TIME:
			## Gate пройдено — вийти
			_gate_active = false
			AudioManager.play_sfx("success")
			_resume_btn.visible = true
			_exit_btn.visible = true
			if _gate_label:
				_gate_label.visible = false
			if _gate_cancel_btn:
				_gate_cancel_btn.visible = false
			if _gate_progress_bar:
				_gate_progress_bar.visible = false
			if _gate_bg:
				_gate_bg.visible = false
			_animate_out(func() -> void:
				visible = false
				get_tree().paused = false
				confirmed_exit.emit())
	else:
		## Недостатньо пальців — скидаємо прогрес
		if _gate_progress > 0.0:
			_gate_progress = 0.0
			if _gate_progress_bar:
				_gate_progress_bar.scale = Vector2(0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	## ESC/Back скасовує gate або закриває діалог (LAW 27: діти не знають ESC)
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _gate_active:
			_cancel_gate()
		else:
			_on_resume()


func _cancel_gate() -> void:
	_gate_active = false
	_gate_progress = 0.0
	_active_touches.clear()
	AudioManager.play_sfx("click")
	if _gate_label:
		_gate_label.visible = false
	if _gate_progress_bar:
		_gate_progress_bar.visible = false
		_gate_progress_bar.scale = Vector2(0.0, 1.0)
	if _gate_bg:
		_gate_bg.visible = false
	if _gate_cancel_btn:
		_gate_cancel_btn.visible = false
	_resume_btn.visible = true
	_exit_btn.visible = true


func _make_icon_button(color_key: String, icon: Control) -> Button:
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
	btn.text = ""
	## Soft кругла кнопка — єдиний стиль з головним меню
	var color: Color = ThemeManager.COLOR_PRIMARY if color_key == "green" else ThemeManager.COLOR_SECONDARY
	var depth: Color = ThemeManager.COLOR_PRIMARY_DEPTH if color_key == "green" else ThemeManager.COLOR_SECONDARY_DEPTH
	btn.add_theme_stylebox_override("normal",
		ThemeManager.make_soft_style(color, depth, 999, false))
	btn.add_theme_stylebox_override("hover",
		ThemeManager.make_soft_style(color.lightened(0.05), depth, 999, false))
	btn.add_theme_stylebox_override("pressed",
		ThemeManager.make_soft_style(color, depth, 999, true))
	## Код-малювана іконка
	IconDraw.icon_in_button(btn, icon)
	return btn
