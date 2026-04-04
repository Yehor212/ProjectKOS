extends Control

## Home Hub — мінімальний дитячий екран: PLAY + Колекція + Майданчик + Батьківська зона.

const _PARENTAL_GATE: PackedScene = preload("res://scenes/ui/parental_gate.tscn")

var _play_pulse: Tween = null
var _title_pulse: Tween = null
var _star_label: Label = null


func _ready() -> void:
	## BGM — фонова музика з головного меню
	AudioManager.play_bgm("bgm_loop")
	AudioManager.restore_bgm()
	## Grain overlay на весь UI (LAW 28 — premium texture)
	material = GameData.create_premium_material(0.02, 2.0, 0.0, 0.0, 0.0, 0.04, 0.12, "", 0.0, 0.08, 0.18, 0.15)
	## Головне меню завжди використовує meadow тему для найкращого вигляду
	var _bg_theme: String = "meadow"
	GameData.apply_premium_background($Background as TextureRect, _bg_theme, SettingsManager.reduced_motion)
	GameData.add_bg_elements(self, _bg_theme, SettingsManager.reduced_motion)
	_add_clouds()
	_apply_safe_area()
	## Кнопки — м'який плоский стиль (soft candy, як на референсі)
	_apply_soft($CenterVBox/PlayButton, ThemeManager.COLOR_PRIMARY, ThemeManager.COLOR_PRIMARY_DEPTH)
	_apply_soft($CenterVBox/IconBar/CollectionButton, ThemeManager.COLOR_PRIMARY, ThemeManager.COLOR_PRIMARY_DEPTH)
	_apply_soft($CenterVBox/IconBar/ShopButton, ThemeManager.COLOR_PRIMARY, ThemeManager.COLOR_PRIMARY_DEPTH)
	_apply_soft($CenterVBox/IconBar/PlaygroundButton, ThemeManager.COLOR_PRIMARY, ThemeManager.COLOR_PRIMARY_DEPTH)
	_apply_soft($ParentLockButton, ThemeManager.COLOR_SECONDARY, ThemeManager.COLOR_SECONDARY_DEPTH, 999)
	$ParentLockButton.custom_minimum_size = Vector2(72, 72)
	## IconDraw іконки замість емоджі/тексту в кнопках
	IconDraw.icon_in_button($ParentLockButton, IconDraw.gear(36.0))
	IconDraw.icon_in_button($CenterVBox/IconBar/CollectionButton, IconDraw.star_5pt(44.0))
	IconDraw.icon_in_button($CenterVBox/IconBar/ShopButton, IconDraw.cart(44.0))
	IconDraw.icon_in_button($CenterVBox/IconBar/PlaygroundButton, IconDraw.heart(44.0))
	## Код-малювані іконки: зірка в лічильнику + play в кнопці
	var star_ctrl: Control = IconDraw.star_5pt(28.0)
	star_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$StarBar/StarIcon.add_child(star_ctrl)
	IconDraw.icon_in_button($CenterVBox/PlayButton, IconDraw.play_triangle(56.0))
	## Star counter — gold pill. Зберегти ref ДО reparent
	_star_label = $StarBar/StarLabel
	var star_pill: PanelContainer = PanelContainer.new()
	star_pill.add_theme_stylebox_override("panel", GameData.star_pill())
	var star_bar: HBoxContainer = $StarBar
	star_bar.get_parent().add_child(star_pill)
	star_pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	star_pill.offset_left = star_bar.offset_left
	star_pill.offset_top = star_bar.offset_top
	star_bar.reparent(star_pill)
	star_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## UX-01: Оновити лічильник зірок
	_star_label.text = str(ProgressManager.stars)
	## UX-02: Щоденна нагорода
	var daily: int = RewardManager.check_daily_reward()
	if daily > 0:
		_star_label.text = str(ProgressManager.stars)
		call_deferred("_show_daily_reward", daily)
	for btn: Button in [$CenterVBox/PlayButton, $CenterVBox/IconBar/CollectionButton,
			$CenterVBox/IconBar/ShopButton, $CenterVBox/IconBar/PlaygroundButton,
			$ParentLockButton]:
		btn.pivot_offset = btn.size / 2.0
		btn.button_down.connect(_animate_button_press.bind(btn))

	## Juicy button squish
	JuicyEffects.button_press_squish($CenterVBox/PlayButton, self)
	JuicyEffects.button_press_squish($CenterVBox/IconBar/CollectionButton, self)
	JuicyEffects.button_press_squish($CenterVBox/IconBar/ShopButton, self)
	JuicyEffects.button_press_squish($CenterVBox/IconBar/PlaygroundButton, self)
	JuicyEffects.button_press_squish($ParentLockButton, self)

	## UX-09: Підписи до іконок
	_add_icon_label($CenterVBox/IconBar/CollectionButton, tr("BTN_COLLECTION"))
	_add_icon_label($CenterVBox/IconBar/ShopButton, tr("BTN_SHOP"))
	_add_icon_label($CenterVBox/IconBar/PlaygroundButton, tr("BTN_NURSERY"))

	## Каскадна поява кнопок IconBar
	_animate_icon_bar_entrance()

	# Анімація заголовку — pop-in
	var title: Label = $CenterVBox/TitleLabel
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2.ZERO
	title.modulate.a = 0.0

	var title_tw: Tween = create_tween().set_parallel(true)
	title_tw.tween_property(title, "scale", Vector2(1.15, 1.15), 0.5)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	title_tw.tween_property(title, "modulate:a", 1.0, 0.3)
	title_tw.chain().tween_property(title, "scale", Vector2.ONE, 0.2)
	title_tw.chain().tween_callback(_start_title_effects)

	# Субтитр — затримана поява з depth treatment
	var subtitle: Label = $CenterVBox/SubtitleLabel
	subtitle.text = tr("SPLASH_SUBTITLE")
	subtitle.add_theme_constant_override("outline_size", 3)
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.15))
	subtitle.modulate.a = 0.0
	create_tween().tween_property(subtitle, "modulate:a", 1.0, 0.6).set_delay(0.4)

	# Пульсація кнопки Play з rotation wobble для привертання уваги дитини
	var play_btn: Button = $CenterVBox/PlayButton
	play_btn.pivot_offset = play_btn.size / 2.0
	play_btn.scale = Vector2.ZERO
	play_btn.modulate.a = 0.0
	## Pop-in кнопки Play
	var play_entrance: Tween = create_tween().set_parallel(true)
	play_entrance.tween_property(play_btn, "scale", Vector2(1.1, 1.1), 0.4)\
		.set_delay(0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	play_entrance.tween_property(play_btn, "modulate:a", 1.0, 0.25).set_delay(0.3)
	play_entrance.chain().tween_property(play_btn, "scale", Vector2.ONE, 0.1)
	play_entrance.chain().tween_callback(_start_play_pulse)

	## Floating decos вимкнені (користувач: прибрати рухомі частинки)




func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_exit_dialog()


func _show_exit_dialog() -> void:
	## Вихід з додатка — тільки через батьківський шлюз (Law 16)
	var gate: CanvasLayer = _PARENTAL_GATE.instantiate()
	add_child(gate)
	gate.gate_passed.connect(func() -> void:
		gate.queue_free()
		get_tree().quit()
	)
	gate.gate_cancelled.connect(func() -> void: gate.queue_free())
	gate.show_gate()


func _apply_safe_area() -> void:
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	var full: Vector2i = DisplayServer.screen_get_size()
	if sa.size.x == 0 or full.x == 0:
		return
	var left: float = float(sa.position.x)
	var top: float = float(sa.position.y)
	var right: float = float(full.x - sa.end.x)
	## StarBar — лівий верхній кут
	$StarBar.offset_left += left
	$StarBar.offset_top += top
	## ParentLockButton — правий верхній кут
	$ParentLockButton.offset_right -= right
	$ParentLockButton.offset_left -= right
	$ParentLockButton.offset_top += top


func _add_icon_label(btn: Button, text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_top = -22.0
	btn.add_child(lbl)




func _animate_icon_bar_entrance() -> void:
	var buttons: Array[Button] = [
		$CenterVBox/IconBar/CollectionButton,
		$CenterVBox/IconBar/ShopButton,
		$CenterVBox/IconBar/PlaygroundButton,
	]
	for i: int in buttons.size():
		var btn: Button = buttons[i]
		btn.pivot_offset = btn.size / 2.0
		btn.scale = Vector2.ZERO
		btn.modulate.a = 0.0
		var delay: float = 0.5 + float(i) * 0.12
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.35)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "modulate:a", 1.0, 0.2).set_delay(delay)
		tw.chain().tween_property(btn, "scale", Vector2.ONE, 0.1)


func _animate_button_press(button: Button) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.9, 0.9), 0.07)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)


func _start_play_pulse() -> void:
	var play_btn: Button = $CenterVBox/PlayButton
	play_btn.pivot_offset = play_btn.size / 2.0
	_play_pulse = create_tween().set_loops()
	## Scale pulse + мікро-поворот для живості
	_play_pulse.tween_property(play_btn, "scale", Vector2(1.06, 1.06), 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play_pulse.parallel().tween_property(play_btn, "rotation",
		deg_to_rad(1.5), 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play_pulse.tween_property(play_btn, "scale", Vector2.ONE, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play_pulse.parallel().tween_property(play_btn, "rotation",
		deg_to_rad(-1.5), 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play_pulse.tween_property(play_btn, "rotation", 0.0, 0.4)\
		.set_trans(Tween.TRANS_SINE)


func _start_title_effects() -> void:
	# Дихання заголовку
	var title: Label = $CenterVBox/TitleLabel
	_title_pulse = create_tween().set_loops()
	_title_pulse.tween_property(title, "scale", Vector2(1.04, 1.04), 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_pulse.tween_property(title, "scale", Vector2.ONE, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _show_daily_reward(amount: int) -> void:
	## UX-02: Premium daily reward celebration — canvas ефекти
	var vp: Vector2 = get_viewport().get_visible_rect().size

	## Screen flash — золотий спалах
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1.0, 0.95, 0.7, 0.3)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var flash_tw: Tween = create_tween()
	flash_tw.tween_property(flash, "color:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flash_tw.finished.connect(flash.queue_free)

	## Overlay з затемненням
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	create_tween().tween_property(overlay, "color:a", 0.5, 0.3)

	## Candy-панель по центру замість простого VBox
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var half_w: float = minf(160.0, vp.x * 0.35)
	var half_h: float = minf(140.0, vp.y * 0.3)
	panel.offset_left = -half_w
	panel.offset_right = half_w
	panel.offset_top = -half_h
	panel.offset_bottom = half_h
	panel.add_theme_stylebox_override("panel",
		GameData.candy_panel(Color("2d1b69"), 28))
	panel.pivot_offset = Vector2(half_w, half_h)
	panel.scale = Vector2.ZERO
	panel.modulate.a = 0.0
	overlay.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set("theme_override_constants/separation", 16)
	panel.add_child(box)

	## Подарунок (IconDraw замість емоджі)
	var gift_icon: Control = IconDraw.gift_box(64.0)
	gift_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gift_center: CenterContainer = CenterContainer.new()
	gift_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gift_center.custom_minimum_size = Vector2(72, 72)
	gift_center.add_child(gift_icon)
	gift_center.modulate.a = 0.0
	box.add_child(gift_center)
	var gift_label: Control = gift_center  ## alias для анімації

	## Текст нагороди (IconDraw зірка замість емоджі)
	var reward_hbox: HBoxContainer = HBoxContainer.new()
	reward_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_hbox.set("theme_override_constants/separation", 8)
	reward_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_hbox.modulate.a = 0.0
	var reward_text_lbl: Label = Label.new()
	reward_text_lbl.text = "+%d" % amount
	reward_text_lbl.add_theme_font_size_override("font_size", 48)
	reward_text_lbl.add_theme_color_override("font_color", Color("FFD166"))
	reward_text_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	reward_text_lbl.add_theme_constant_override("shadow_offset_x", 2)
	reward_text_lbl.add_theme_constant_override("shadow_offset_y", 2)
	reward_text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_hbox.add_child(reward_text_lbl)
	var reward_star: Control = IconDraw.star_5pt(36.0)
	reward_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_hbox.add_child(reward_star)
	box.add_child(reward_hbox)
	var reward_label: Control = reward_hbox  ## alias для анімації

	## Підпис
	var msg_label: Label = Label.new()
	var reward_text: String = tr("MSG_DAILY_REWARD")
	msg_label.text = reward_text % amount if reward_text.contains("%") else reward_text
	msg_label.add_theme_font_size_override("font_size", 22)
	msg_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.modulate.a = 0.0
	box.add_child(msg_label)

	## === АНІМАЦІЯ ===
	## Фаза 1: Панель pop-in
	var tw: Tween = create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(panel, "scale", Vector2(1.1, 1.1), 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.12)

	## Фаза 2: Подарунок з'являється + хитання
	tw.tween_property(gift_label, "modulate:a", 1.0, 0.15)
	tw.tween_callback(func() -> void:
		gift_label.pivot_offset = gift_label.size / 2.0
		gift_label.scale = Vector2(0.3, 0.3))
	tw.tween_property(gift_label, "scale", Vector2(1.4, 1.4), 0.35)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(gift_label, "scale", Vector2(1.1, 1.1), 0.1)
	## Хитання подарунку
	tw.tween_property(gift_label, "rotation", deg_to_rad(-10.0), 0.05)
	tw.tween_property(gift_label, "rotation", deg_to_rad(10.0), 0.05)
	tw.tween_property(gift_label, "rotation", deg_to_rad(-6.0), 0.04)
	tw.tween_property(gift_label, "rotation", deg_to_rad(6.0), 0.04)
	tw.tween_property(gift_label, "rotation", deg_to_rad(-2.0), 0.03)
	tw.tween_property(gift_label, "rotation", 0.0, 0.03)
	tw.tween_property(gift_label, "scale", Vector2.ONE, 0.08)

	## Фаза 3: Текст +N + зірка — burst pop-in + SFX
	tw.tween_callback(func() -> void: AudioManager.play_sfx("coin"))
	tw.tween_property(reward_label, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_callback(func() -> void:
		reward_label.pivot_offset = reward_label.size / 2.0
		reward_label.scale = Vector2(0.3, 0.3))
	tw.parallel().tween_property(reward_label, "scale", Vector2(1.15, 1.15), 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(reward_label, "scale", Vector2.ONE, 0.1)

	## Фаза 4: Підпис
	tw.tween_property(msg_label, "modulate:a", 1.0, 0.3)

	## Gift unwrap + веселкове кільце (унікальне для daily reward)
	VFXManager.spawn_gift_unwrap(vp / 2.0)
	VFXManager.spawn_golden_burst(vp / 2.0)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if is_instance_valid(self):
			VFXManager.spawn_rainbow_ring(vp / 2.0))

	## Зоряний дощ (тепер унікальний тільки для daily reward)
	_spawn_reward_star_rain(overlay, vp)

	## Автозакриття через 3с або по тапу
	var _closing: Array[bool] = [false]
	var close: Callable = func() -> void:
		if _closing[0] or not is_instance_valid(overlay):
			return
		_closing[0] = true
		## Pop-out панелі
		if is_instance_valid(panel):
			var close_tw: Tween = create_tween()
			close_tw.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.08)
			close_tw.tween_property(panel, "scale", Vector2(0.0, 0.0), 0.2)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			close_tw.parallel().tween_property(overlay, "color:a", 0.0, 0.25)
			close_tw.finished.connect(overlay.queue_free)
		else:
			overlay.queue_free()
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close.call()
		elif event is InputEventScreenTouch and event.pressed:
			close.call()
	)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			close.call())


## Зоряний дощ для daily reward — маленькі золоті зірочки падають зверху.
func _spawn_reward_star_rain(parent: Control, vp: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	for i: int in 6:
		var sz: float = randf_range(14.0, 24.0)
		var star: Control = IconDraw.star_5pt(sz)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.modulate = Color(Color("FFD166"), 0.0)
		var start_x: float = randf_range(vp.x * 0.15, vp.x * 0.85)
		star.position = Vector2(start_x, -sz)
		star.pivot_offset = Vector2(sz / 2.0, sz / 2.0)
		star.rotation = randf_range(0.0, TAU)
		parent.add_child(star)
		var delay: float = randf_range(0.2, 1.0)
		var fall_dur: float = randf_range(1.2, 2.5)
		var end_y: float = randf_range(vp.y * 0.4, vp.y + sz)
		var stw: Tween = create_tween().set_parallel(true)
		stw.tween_property(star, "position:y", end_y, fall_dur)\
			.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		stw.tween_property(star, "position:x",
			start_x + randf_range(-40.0, 40.0), fall_dur)\
			.set_delay(delay).set_trans(Tween.TRANS_SINE)
		stw.tween_property(star, "rotation",
			star.rotation + randf_range(TAU, TAU * 2.0), fall_dur)\
			.set_delay(delay)
		stw.tween_property(star, "modulate:a", randf_range(0.5, 0.8), 0.25)\
			.set_delay(delay)
		stw.chain().tween_property(star, "modulate:a", 0.0, 0.3)
		stw.chain().tween_callback(star.queue_free)


func _disable_buttons() -> void:
	$CenterVBox/PlayButton.disabled = true
	$CenterVBox/IconBar/CollectionButton.disabled = true
	$CenterVBox/IconBar/ShopButton.disabled = true
	$CenterVBox/IconBar/PlaygroundButton.disabled = true
	$ParentLockButton.disabled = true
	if _play_pulse and _play_pulse.is_valid():
		_play_pulse.kill()
	if _title_pulse and _title_pulse.is_valid():
		_title_pulse.kill()


func _on_play_pressed() -> void:
	AudioManager.play_sfx("click")
	_disable_buttons()
	SceneManager.goto_scene("res://scenes/ui/game_hub.tscn")


func _on_collection_pressed() -> void:
	AudioManager.play_sfx("click")
	_disable_buttons()
	SceneManager.goto_scene("res://scenes/ui/sticker_book.tscn")


func _on_shop_pressed() -> void:
	AudioManager.play_sfx("click")
	_disable_buttons()
	SceneManager.goto_scene("res://scenes/ui/shop_menu.tscn")


func _on_playground_pressed() -> void:
	AudioManager.play_sfx("click")
	_disable_buttons()
	SceneManager.goto_scene("res://scenes/main/nursery.tscn")


func _on_parent_lock_pressed() -> void:
	AudioManager.play_sfx("click")
	var gate: CanvasLayer = _PARENTAL_GATE.instantiate()
	add_child(gate)
	gate.gate_passed.connect(func() -> void:
		gate.queue_free()
		_disable_buttons()
		SceneManager.goto_scene("res://scenes/ui/parent_zone.tscn")
	)
	gate.gate_cancelled.connect(func() -> void: gate.queue_free())
	gate.show_gate()


func _apply_soft(btn: Button, color: Color, depth: Color, corner: int = ThemeManager.CANDY_RADIUS) -> void:
	btn.add_theme_stylebox_override("normal", ThemeManager.make_soft_style(color, depth, corner, false))
	btn.add_theme_stylebox_override("hover", ThemeManager.make_soft_style(color.lightened(0.05), depth, corner, false))
	btn.add_theme_stylebox_override("pressed", ThemeManager.make_soft_style(color, depth, corner, true))
	btn.add_theme_stylebox_override("disabled", ThemeManager.make_soft_style(color.darkened(0.2), depth, corner, false))
	## Focus — прозорий щоб не перебивав soft стиль
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _add_clouds() -> void:
	var cloud_path: String = "res://assets/backgrounds/elements/rx_cloud1.png"
	if not ResourceLoader.exists(cloud_path):
		push_warning("main_menu: rx_cloud1.png not found, skipping clouds")
		return
	var cloud_tex: Texture2D = load(cloud_path)
	var configs: Array[Dictionary] = [
		{"pos": Vector2(80, 30), "scale": Vector2(0.9, 0.9), "alpha": 0.85},
		{"pos": Vector2(550, 10), "scale": Vector2(1.15, 1.15), "alpha": 0.75},
		{"pos": Vector2(1020, 45), "scale": Vector2(0.7, 0.7), "alpha": 0.80},
	]
	for cfg: Dictionary in configs:
		var cloud: TextureRect = TextureRect.new()
		cloud.texture = cloud_tex
		cloud.position = cfg.pos
		cloud.scale = cfg.scale
		cloud.modulate.a = cfg.alpha
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloud.z_index = -2
		add_child(cloud)
