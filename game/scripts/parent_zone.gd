extends Control

## Батьківська зона — статистика дитини, налаштування, експорт/імпорт.

const SECTION_STAGGER: float = 0.08
const SECTION_DUR: float = 0.35

func _ready() -> void:
	## Grain overlay на весь UI (LAW 28 — premium texture)
	material = GameData.create_premium_material(0.02, 2.0, 0.0, 0.0, 0.03, 0.04, 0.10, "", 0.0, 0.08, 0.18, 0.15)
	GameData.apply_premium_background($Background as TextureRect, "arctic", SettingsManager.reduced_motion)
	## V167: Settings screen — тільки градієнт + grain, без декоративних елементів
	## (дерева/пагорби заважають читабельності Labels/Sliders/CheckButtons)
	_apply_safe_area()
	_setup_labels()
	_update_stats()
	_setup_settings()
	IconDraw.icon_in_button($BackButton, IconDraw.arrow_left(28.0))
	## Juicy button squish
	JuicyEffects.button_press_squish($BackButton, self)
	JuicyEffects.button_press_squish($ScrollContainer/VBox/ChangeAgeButton, self)
	JuicyEffects.button_press_squish($ScrollContainer/VBox/ExportButton, self)
	JuicyEffects.button_press_squish($ScrollContainer/VBox/ImportButton, self)
	JuicyEffects.button_press_squish($ScrollContainer/VBox/RateAppButton, self)
	JuicyEffects.button_press_squish($ScrollContainer/VBox/PrivacyButton, self)
	_animate_entrance()


func _apply_safe_area() -> void:
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	var full: Vector2i = DisplayServer.screen_get_size()
	if sa.size.x == 0 or full.x == 0:
		return
	var top: float = float(sa.position.y)
	if top > 0.0:
		$ScrollContainer.offset_top += top


func _setup_labels() -> void:
	$ScrollContainer/VBox/TitleLabel.text = tr("LBL_PARENT_ZONE")
	$ScrollContainer/VBox/StatsHeader.text = tr("LBL_STATS_HEADER")
	$ScrollContainer/VBox/SettingsHeader.text = tr("BTN_SETTINGS")
	$ScrollContainer/VBox/VolumeLabel.text = tr("LBL_SFX_VOLUME")
	$ScrollContainer/VBox/BgmLabel.text = tr("LBL_BGM_VOLUME")
	$ScrollContainer/VBox/VibrationCheck.text = tr("BTN_VIBRATION")
	$ScrollContainer/VBox/ReducedMotionCheck.text = tr("BTN_REDUCED_MOTION")
	$ScrollContainer/VBox/ColorBlindCheck.text = tr("BTN_COLOR_BLIND")
	_update_session_label()
	$ScrollContainer/VBox/ExportButton.text = tr("BTN_EXPORT")
	$ScrollContainer/VBox/ImportButton.text = tr("BTN_IMPORT")
	$ScrollContainer/VBox/RateAppButton.text = tr("BTN_RATE")
	$ScrollContainer/VBox/PrivacyButton.text = tr("BTN_PRIVACY")
	$ScrollContainer/VBox/ChangeAgeButton.text = tr("BTN_CHANGE_AGE")
	if SettingsManager.has_rated_app:
		$ScrollContainer/VBox/RateAppButton.visible = false
	## Показати поточну вікову групу
	var age_text: String = ""
	if SettingsManager.age_group == 1:
		age_text = tr("AGE_TODDLER")
	elif SettingsManager.age_group == 2:
		age_text = tr("AGE_PRESCHOOL")
	if not age_text.is_empty():
		$ScrollContainer/VBox/AgeLabel.text = tr("LBL_CURRENT_AGE") % age_text
	else:
		$ScrollContainer/VBox/AgeLabel.text = ""
	## IconDraw зірка перед StarsLabel
	var stars_lbl: Label = $ScrollContainer/VBox/StarsLabel
	if not stars_lbl.has_node("StarIcon"):
		var star_icon: Control = IconDraw.star_5pt(18.0)
		star_icon.name = "StarIcon"
		star_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		star_icon.offset_left = -22.0
		star_icon.offset_right = 0.0
		stars_lbl.add_child(star_icon)


func _update_stats() -> void:
	$ScrollContainer/VBox/GamesLabel.text = tr("LBL_GAMES_PLAYED") % ProgressManager.games_played
	$ScrollContainer/VBox/FedLabel.text = tr("LBL_ANIMALS_FED") % ProgressManager.total_animals_fed
	var unlocked: int = ProgressManager.unlocked_animals.size()
	$ScrollContainer/VBox/UnlockedLabel.text = tr("LBL_ANIMALS_UNLOCKED") % [unlocked, GameData.ANIMALS_AND_FOOD.size()]
	if ProgressManager.best_time_sec < 9999:
		var mins: int = ProgressManager.best_time_sec / 60
		var secs: int = ProgressManager.best_time_sec % 60
		$ScrollContainer/VBox/BestTimeLabel.text = tr("LBL_BEST_TIME") % [mins, secs]
	else:
		$ScrollContainer/VBox/BestTimeLabel.visible = false
	## Оновити лічильник зірок (IconDraw зірка додається в _ready)
	$ScrollContainer/VBox/StarsLabel.text = " %d" % ProgressManager.stars


func _animate_entrance() -> void:
	var vbox: VBoxContainer = $ScrollContainer/VBox
	## Заголовок — fade-in (scale анімація конфліктує з VBox layout)
	var title: Label = $ScrollContainer/VBox/TitleLabel
	title.modulate.a = 0.0
	var t_tw: Tween = create_tween()
	t_tw.tween_property(title, "modulate:a", 1.0, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	## Каскадна поява секцій — всі дочірні елементи крім заголовка
	## УВАГА: position.y НЕ анімуємо — VBoxContainer керує позиціями дітей,
	## пряме встановлення position.y конфліктує з layout_mode=2.
	var idx: int = 0
	for child: Node in vbox.get_children():
		if child == title or not child is Control:
			continue
		var ctrl: Control = child as Control
		ctrl.modulate.a = 0.0
		var delay: float = 0.3 + float(idx) * SECTION_STAGGER
		var tw: Tween = create_tween()
		tw.tween_property(ctrl, "modulate:a", 1.0, SECTION_DUR)\
			.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		idx += 1
	## Зірки count-up
	var stars_label: Label = $ScrollContainer/VBox/StarsLabel
	var target_stars: int = ProgressManager.stars
	if target_stars > 0:
		stars_label.text = " 0"
		var count_cb: Callable = func(val: float) -> void:
			if is_instance_valid(stars_label):
				stars_label.text = " %d" % int(val)
		var s_tw: Tween = create_tween()
		s_tw.tween_method(count_cb, 0.0, float(target_stars), 0.7)\
			.set_delay(0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _setup_settings() -> void:
	$ScrollContainer/VBox/VolumeSlider.value = SettingsManager.sfx_volume
	$ScrollContainer/VBox/BgmSlider.value = SettingsManager.bgm_volume
	$ScrollContainer/VBox/VibrationCheck.button_pressed = SettingsManager.haptics_enabled
	$ScrollContainer/VBox/ReducedMotionCheck.button_pressed = SettingsManager.reduced_motion
	$ScrollContainer/VBox/ColorBlindCheck.button_pressed = SettingsManager.color_blind_mode
	$ScrollContainer/VBox/SessionSlider.value = float(SettingsManager.session_limit_minutes)
	var option: OptionButton = $ScrollContainer/VBox/LanguageOption
	option.clear()
	option.add_item("English", 0)
	option.add_item("Українська", 1)
	option.add_item("Français", 2)
	option.add_item("Español", 3)
	var idx: int = SettingsManager.LOCALES.find(SettingsManager.current_language)
	if idx >= 0:
		option.select(idx)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_volume_slider_value_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value)


func _on_language_option_item_selected(index: int) -> void:
	if index >= 0 and index < SettingsManager.LOCALES.size():
		SettingsManager.set_language(SettingsManager.LOCALES[index])
	## Оновити тексти без повторного replace_by
	_setup_labels()
	_update_stats()


func _on_vibration_toggled(enabled: bool) -> void:
	AudioManager.play_sfx("click")
	SettingsManager.haptics_enabled = enabled
	SettingsManager.save_settings()


func _on_reduced_motion_toggled(enabled: bool) -> void:
	AudioManager.play_sfx("click")
	SettingsManager.reduced_motion = enabled
	SettingsManager.save_settings()


func _on_bgm_slider_value_changed(value: float) -> void:
	SettingsManager.set_bgm_volume(value)


func _on_color_blind_toggled(enabled: bool) -> void:
	AudioManager.play_sfx("click")
	SettingsManager.color_blind_mode = enabled
	SettingsManager.save_settings()


func _on_session_slider_value_changed(value: float) -> void:
	SettingsManager.session_limit_minutes = int(value)
	SettingsManager.save_settings()
	_update_session_label()


func _update_session_label() -> void:
	var mins: int = SettingsManager.session_limit_minutes
	if mins == 0:
		$ScrollContainer/VBox/SessionLabel.text = tr("LBL_SESSION_OFF")
	else:
		$ScrollContainer/VBox/SessionLabel.text = tr("LBL_SESSION_LIMIT") % mins


func _on_export_pressed() -> void:
	_show_status(SaveTransfer.do_export())


func _on_import_pressed() -> void:
	var msg: String = SaveTransfer.do_import()
	if msg.is_empty():
		get_tree().reload_current_scene()
		return
	_show_status(msg)


func _on_rate_app_pressed() -> void:
	## COPPA: кожне зовнішнє посилання потребує окремий parental gate
	var gate: CanvasLayer = preload("res://scenes/ui/parental_gate.tscn").instantiate()
	add_child(gate)
	gate.gate_passed.connect(func() -> void:
		gate.queue_free()
		SettingsManager.set_app_rated()
		var market_url: String = "market://details?id=com.projectkos.foodgame"
		var web_url: String = "https://play.google.com/store/apps/details?id=com.projectkos.foodgame"
		if OS.shell_open(market_url) != OK:
			OS.shell_open(web_url)
		$ScrollContainer/VBox/RateAppButton.visible = false
	)
	gate.gate_cancelled.connect(func() -> void: gate.queue_free())
	gate.show_gate()


func _on_change_age_pressed() -> void:
	AudioManager.play_sfx("click")
	SceneManager.goto_scene("res://scenes/ui/age_selection.tscn")


func _on_privacy_pressed() -> void:
	## COPPA: кожне зовнішнє посилання потребує окремий parental gate
	var gate: CanvasLayer = preload("res://scenes/ui/parental_gate.tscn").instantiate()
	add_child(gate)
	gate.gate_passed.connect(func() -> void:
		gate.queue_free()
		OS.shell_open("https://projectkos.github.io/privacy")
	)
	gate.gate_cancelled.connect(func() -> void: gate.queue_free())
	gate.show_gate()


func _show_status(key: String) -> void:
	$ScrollContainer/VBox/StatusLabel.text = tr(key)
	$ScrollContainer/VBox/StatusLabel.visible = true


func _on_back_pressed() -> void:
	AudioManager.play_sfx("click")
	var popper: UIPopper = $ScrollContainer/VBox.get_node_or_null("UIPopper") as UIPopper
	if popper:
		popper.pop_out(func() -> void: SceneManager.goto_scene("res://scenes/ui/main_menu.tscn"))
	else:
		SceneManager.goto_scene("res://scenes/ui/main_menu.tscn")
