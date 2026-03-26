extends CanvasLayer

## Текстово-числовий когнітивний гейт для батьків (COPPA).
## Генерує 3 випадкові цифри, показує їх словами — батько натискає відповідні на клавіатурі.

signal gate_passed
signal gate_cancelled

const DIGIT_COUNT: int = 3
const NUM_KEYS: Array[String] = [
	"NUM_ZERO", "NUM_ONE", "NUM_TWO", "NUM_THREE", "NUM_FOUR",
	"NUM_FIVE", "NUM_SIX", "NUM_SEVEN", "NUM_EIGHT", "NUM_NINE",
]

var _target_digits: Array[int] = []
var _entered_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	## Grain overlay на parental gate (LAW 28)
	$Overlay.material = GameData.create_premium_material(0.02, 2.0, 0.04, 0.06, 0.03, 0.04, 0.10, "", 0.0, 0.08, 0.18, 0.15)
	## Juicy button squish — keypad + cancel
	for i: int in 10:
		var btn_path: String = "Overlay/PanelContainer/VBoxContainer/KeypadGrid/Btn%d" % i
		var btn_node: Button = get_node_or_null(btn_path) as Button
		if btn_node:
			JuicyEffects.button_press_squish(btn_node, self)
		else:
			push_warning("ParentalGate: button not found at %s" % btn_path)
	JuicyEffects.button_press_squish($Overlay/PanelContainer/VBoxContainer/CancelButton, self)


func show_gate() -> void:
	_target_digits.clear()
	_entered_count = 0
	for i: int in DIGIT_COUNT:
		_target_digits.append(randi_range(0, 9))
	var words: PackedStringArray = PackedStringArray()
	for d: int in _target_digits:
		words.append(tr(NUM_KEYS[d]))
	$Overlay/PanelContainer/VBoxContainer/PromptLabel.text = tr("GATE_TAP_PROMPT") % ", ".join(words)
	## A12: i18n — локалізація інструкції (tscn має hardcoded English)
	$Overlay/PanelContainer/VBoxContainer/InstructionLabel.text = tr("GATE_INSTRUCTION")
	_update_digit_display()
	visible = true
	## Анімація входу: фон fade + панель pop-in
	$Overlay.modulate.a = 0.0
	var panel: PanelContainer = $Overlay/PanelContainer
	## Viewport-relative clamping — не виходити за межі екрану на вузьких пристроях
	var vp_w: float = get_viewport().get_visible_rect().size.x
	var half_w: float = minf(280.0, vp_w * 0.45)
	panel.offset_left = -half_w
	panel.offset_right = half_w
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.5, 0.5)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property($Overlay, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _update_digit_display() -> void:
	var display: String = ""
	for i: int in DIGIT_COUNT:
		if i > 0:
			display += "  "
		if i < _entered_count:
			display += str(_target_digits[i])
		else:
			display += "_"
	$Overlay/PanelContainer/VBoxContainer/DigitsHBox/DigitsLabel.text = display


func _on_keypad_pressed(digit: int) -> void:
	if _entered_count >= DIGIT_COUNT:
		return
	if digit == _target_digits[_entered_count]:
		_entered_count += 1
		AudioManager.play_sfx("click")
		_update_digit_display()
		if _entered_count >= DIGIT_COUNT:
			AudioManager.play_sfx("success")
			_animate_out(func() -> void:
				gate_passed.emit()
				visible = false)
	else:
		AudioManager.play_sfx("error")
		_entered_count = 0
		_update_digit_display()
		_shake_panel()


func _shake_panel() -> void:
	var panel: PanelContainer = $Overlay/PanelContainer
	var origin_x: float = panel.position.x
	var tw: Tween = create_tween()
	tw.tween_property(panel, "position:x", origin_x + 8.0, 0.05)
	tw.tween_property(panel, "position:x", origin_x - 8.0, 0.05)
	tw.tween_property(panel, "position:x", origin_x + 4.0, 0.05)
	tw.tween_property(panel, "position:x", origin_x, 0.05)


func _on_cancel_pressed() -> void:
	_animate_out(func() -> void:
		gate_cancelled.emit()
		visible = false)


func _animate_out(callback: Callable) -> void:
	var panel: PanelContainer = $Overlay/PanelContainer
	panel.pivot_offset = panel.size / 2.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(0.0, 0.0), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property($Overlay, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(callback)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	## Law 17 COPPA: ESC НЕ закриває gate — тільки кнопка Cancel (батьківський контроль)
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
