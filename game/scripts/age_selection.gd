extends Control

## Екран вибору вікової групи — онбординг при першому запуску.

const TODDLER_COLOR: Color = ThemeManager.COLOR_PRIMARY
const PRESCHOOL_COLOR: Color = ThemeManager.COLOR_PRESCHOOL
const CARD_MAX_W: float = 260.0
const CARD_H: float = 320.0
const ENTRANCE_DELAY: float = 0.1
const ENTRANCE_DUR: float = 0.5
const _PARENTAL_GATE: PackedScene = preload("res://scenes/ui/parental_gate.tscn")

var _selected_group: int = 0
var _toddler_card: PanelContainer = null
var _preschool_card: PanelContainer = null
var _start_btn: Button = null


func _ready() -> void:
	## Grain overlay на весь UI (LAW 28 — premium texture)
	material = GameData.create_premium_material(0.02, 2.0, 0.0, 0.0, 0.03, 0.04, 0.10, "", 0.0, 0.08, 0.18, 0.15)
	GameData.apply_premium_background($Background as TextureRect, "candy", SettingsManager.reduced_motion)
	GameData.add_bg_elements(self, "candy", SettingsManager.reduced_motion)
	_build_ui()
	_apply_safe_area()
	_animate_entrance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if SettingsManager.is_age_set():
			AudioManager.play_sfx("click")
			_open_parent_zone_gated()


func _build_ui() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Кнопка «Назад» — тільки якщо вік вже було обрано раніше
	if SettingsManager.is_age_set():
		var back_btn: Button = Button.new()
		back_btn.theme_type_variation = &"CircleButton"
		back_btn.custom_minimum_size = Vector2(64, 64)
		IconDraw.icon_in_button(back_btn, IconDraw.arrow_left(28.0))
		back_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		back_btn.offset_left = 24.0
		back_btn.offset_top = 24.0
		back_btn.offset_right = 144.0
		back_btn.offset_bottom = 80.0
		back_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("click")
			_open_parent_zone_gated()
		)
		add_child(back_btn)
		JuicyEffects.button_press_squish(back_btn, self)
	## Заголовок
	var title: Label = Label.new()
	title.text = tr("AGE_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 60.0
	title.offset_bottom = 120.0
	add_child(title)
	## Контейнер карток — обгортка ScrollContainer для маленьких екранів
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 130.0
	scroll.offset_bottom = -140.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box: HBoxContainer = HBoxContainer.new()
	box.set("theme_override_constants/separation", 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	## Адаптивний розмір карток
	var card_w: float = minf(CARD_MAX_W, (vp.x - 24.0 * 3) * 0.5)
	var card_size: Vector2 = Vector2(card_w, CARD_H)
	## Картки
	_toddler_card = _make_card(TODDLER_COLOR, "toddler", "AGE_TODDLER", "AGE_TODDLER_DESC", 1, card_size)
	box.add_child(_toddler_card)
	_preschool_card = _make_card(PRESCHOOL_COLOR, "preschool", "AGE_PRESCHOOL", "AGE_PRESCHOOL_DESC", 2, card_size)
	box.add_child(_preschool_card)
	## Кнопка «Поїхали!»
	_start_btn = Button.new()
	_start_btn.text = tr("AGE_START")
	_start_btn.theme_type_variation = &"AccentButton"
	_start_btn.custom_minimum_size = Vector2(280, 72)
	_start_btn.add_theme_font_size_override("font_size", 28)
	_start_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_start_btn.offset_top = -120.0
	_start_btn.offset_bottom = -48.0
	_start_btn.offset_left = -140.0
	_start_btn.offset_right = 140.0
	_start_btn.disabled = true
	_start_btn.modulate.a = 0.4
	_start_btn.pressed.connect(_on_start_pressed)
	add_child(_start_btn)
	JuicyEffects.button_press_squish(_start_btn, self)


func _make_card(bg_color: Color, icon: String, title_key: String,
		desc_key: String, group: int, card_size: Vector2 = Vector2(260, 320)) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = card_size
	## Candy-style з depth border
	var style: StyleBoxFlat = GameData.candy_panel(bg_color, 28)
	style.border_width_bottom = 8
	style.border_color = bg_color.darkened(0.25)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	## Вміст
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set("theme_override_constants/separation", 12)
	panel.add_child(vbox)
	var icon_ctrl: Control
	match icon:
		"toddler":
			icon_ctrl = IconDraw.building_blocks(80.0, bg_color.lightened(0.3))
		"preschool":
			icon_ctrl = IconDraw.open_book(80.0, bg_color.lightened(0.3))
		_:
			var fallback_lbl: Label = Label.new()
			fallback_lbl.text = icon
			fallback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback_lbl.add_theme_font_size_override("font_size", 80)
			icon_ctrl = fallback_lbl
	icon_ctrl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_ctrl)
	var title_lbl: Label = Label.new()
	title_lbl.text = tr(title_key)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title_lbl)
	var desc_lbl: Label = Label.new()
	desc_lbl.text = tr(desc_key)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 18)
	desc_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)
	## Клік / тап
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_select(group)
		elif event is InputEventScreenTouch and event.pressed:
			_select(group)
	)
	return panel


func _select(group: int) -> void:
	if _selected_group == group:
		return
	_selected_group = group
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	## Анімація вибору
	var chosen: PanelContainer = _toddler_card if group == 1 else _preschool_card
	var other: PanelContainer = _preschool_card if group == 1 else _toddler_card
	chosen.pivot_offset = chosen.size / 2.0
	other.pivot_offset = other.size / 2.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(chosen, "scale", Vector2(1.1, 1.1), 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(chosen, "modulate", Color.WHITE, 0.15)
	tw.tween_property(other, "scale", Vector2(0.9, 0.9), 0.2)
	tw.tween_property(other, "modulate", Color(1, 1, 1, 0.5), 0.15)
	## Показати кнопку
	if _start_btn.disabled:
		_start_btn.disabled = false
		_start_btn.modulate.a = 1.0
		_start_btn.pivot_offset = _start_btn.size / 2.0
		_start_btn.scale = Vector2.ZERO
		var btn_tw: Tween = create_tween()
		btn_tw.tween_property(_start_btn, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_start_pressed() -> void:
	if _selected_group == 0:
		push_warning("AgeSelection: група не обрана")
		return
	AudioManager.play_sfx("click")
	_start_btn.disabled = true
	SettingsManager.set_age_group(_selected_group)
	SceneManager.goto_scene("res://scenes/ui/main_menu.tscn")


func _animate_entrance() -> void:
	for i: int in [0, 1]:
		var card: PanelContainer = _toddler_card if i == 0 else _preschool_card
		card.pivot_offset = card.size / 2.0
		card.scale = Vector2.ZERO
		card.modulate.a = 0.0
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(card, "scale", Vector2.ONE, ENTRANCE_DUR)\
			.set_delay(float(i) * ENTRANCE_DELAY)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.2)\
			.set_delay(float(i) * ENTRANCE_DELAY)


func _apply_safe_area() -> void:
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	var full: Vector2i = DisplayServer.screen_get_size()
	if sa.size.x == 0 or full.x == 0:
		return
	var top: float = float(sa.position.y)
	var bottom: float = float(full.y - sa.end.y)
	## Відступ зверху для notch
	if top > 0.0:
		for child: Node in get_children():
			if child is Control:
				(child as Control).offset_top += top
	## Відступ знизу для gesture bar / нижнього нотча
	if bottom > 0.0 and is_instance_valid(_start_btn):
		_start_btn.offset_bottom -= bottom
		_start_btn.offset_top -= bottom


func _open_parent_zone_gated() -> void:
	var gate: CanvasLayer = _PARENTAL_GATE.instantiate()
	add_child(gate)
	gate.gate_passed.connect(func() -> void:
		gate.queue_free()
		SceneManager.goto_scene("res://scenes/ui/parent_zone.tscn")
	)
	gate.gate_cancelled.connect(func() -> void: gate.queue_free())
	gate.show_gate()
