extends CanvasLayer

## Шлях сцени при виході — за замовчуванням головне меню, ігри змінюють на hub.
var quit_scene: String = "res://scenes/ui/main_menu.tscn"


var _panel_wrap: PanelContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	## Candy-style панель за кнопками
	var panel_style: StyleBoxFlat = GameData.candy_panel(
		Color(ThemeManager.COLOR_SOFT_NEUTRAL, 0.95), 28)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 4)
	panel_style.border_color = Color(ThemeManager.COLOR_GOLD, 0.3)
	panel_style.set_border_width_all(2)
	_panel_wrap = PanelContainer.new()
	_panel_wrap.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var vp_w: float = get_viewport().get_visible_rect().size.x
	var half_w: float = minf(190.0, vp_w * 0.4)
	_panel_wrap.offset_left = -half_w
	_panel_wrap.offset_right = half_w
	_panel_wrap.offset_top = -170.0
	_panel_wrap.offset_bottom = 170.0
	_panel_wrap.add_theme_stylebox_override("panel", panel_style)
	## Grain overlay на pause panel (LAW 28)
	_panel_wrap.material = GameData.create_premium_material(0.02, 2.0, 0.04, 0.08, 0.03, 0.04, 0.10, "", 0.0, 0.08, 0.18, 0.15)
	$Overlay.add_child(_panel_wrap)
	## Перемістити VBox всередину панелі
	var vbox: VBoxContainer = $Overlay/VBoxContainer
	vbox.reparent(_panel_wrap)
	## CanvasLayer не успадковує тему від root — пропагуємо вручну
	_panel_wrap.theme = get_tree().root.theme
	## Код-малювана іконка паузи замість емоджі
	var pause_label: Label = vbox.get_node("PauseLabel")
	pause_label.text = ""
	var pause_icon: Control = IconDraw.pause_bars(48.0, ThemeManager.COLOR_PRIMARY)
	pause_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_label.add_child(pause_icon)
	pause_label.custom_minimum_size = Vector2(0, 64)
	var resume_btn: Button = vbox.get_node("ResumeButton")
	resume_btn.theme_type_variation = &"AccentButton"
	resume_btn.custom_minimum_size = Vector2(240, 72)
	IconDraw.icon_text_in_button(resume_btn,
		IconDraw.play_triangle(22.0), tr("BTN_RESUME"), 24, 8)
	var quit_btn: Button = vbox.get_node("QuitToMenuButton")
	quit_btn.theme_type_variation = &"SecondaryButton"
	quit_btn.custom_minimum_size = Vector2(240, 72)
	IconDraw.icon_text_in_button(quit_btn,
		IconDraw.home_house(22.0), tr("BTN_MENU"), 24, 8)
	## Juicy button squish
	JuicyEffects.button_press_squish(resume_btn, self)
	JuicyEffects.button_press_squish(quit_btn, self)


func show_pause() -> void:
	visible = true
	get_tree().paused = true
	## Анімація входу: фон fade + панель pop-in
	var overlay: Control = $Overlay
	overlay.modulate.a = 0.0
	_panel_wrap.scale = Vector2(0.5, 0.5)
	_panel_wrap.pivot_offset = _panel_wrap.size / 2.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel_wrap, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _animate_out(callback: Callable) -> void:
	var overlay: Control = $Overlay
	_panel_wrap.pivot_offset = _panel_wrap.size / 2.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_panel_wrap, "scale", Vector2(0.0, 0.0), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(callback)


func _on_resume_pressed() -> void:
	AudioManager.play_sfx("click")
	_animate_out(func() -> void:
		visible = false
		get_tree().paused = false)


func _on_quit_to_menu_pressed() -> void:
	AudioManager.play_sfx("click")
	_animate_out(func() -> void:
		visible = false
		get_tree().paused = false
		SceneManager.goto_scene(quit_scene))
