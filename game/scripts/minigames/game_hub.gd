extends Control

## Хаб вибору ігор — сітка 2x5 з красивими картками та каскадною появою.

const GAME_CARD_SCENE: PackedScene = preload("res://scenes/ui/game_card.tscn")
const CASCADE_DELAY: float = 0.07
const CASCADE_SCALE_DUR: float = 0.45
const CASCADE_FADE_DUR: float = 0.25
const CASCADE_SLIDE_DIST: float = 40.0
const TITLE_COLOR: Color = ThemeManager.COLOR_GOLD

const INFO_PANEL_W: float = 380.0
const INFO_PANEL_H: float = 500.0
const INFO_PANEL_MARGIN: float = 20.0
const INFO_SLIDE_DUR: float = 0.3

var _cards: Array[Control] = []
var _buttons_disabled: bool = false
var _scroll_hint: Control = null
var _session_timer: SessionTimer = null
var _star_label: Label = null
var _info_panel: Panel = null
var _info_dimmer: ColorRect = null
var _info_panel_animating: bool = false
var _info_panel_data: Dictionary = {}


func _ready() -> void:
	## BGM — відновити гучність після міні-гри
	AudioManager.play_bgm("bgm_loop")
	AudioManager.restore_bgm()
	## LAW 26: Таймер здоров'я сесії (одиночний — переживає scene changes)
	if not get_tree().root.has_node("SessionTimer"):
		_session_timer = SessionTimer.new()
		_session_timer.name = "SessionTimer"
		get_tree().root.add_child.call_deferred(_session_timer)
	_apply_safe_area()
	$HeaderBar/TitleLabel.text = tr("TITLE_GAME_HUB")
	## BackButton — soft circle (єдиний стиль з головним меню)
	var back_btn: Button = $HeaderBar/BackButton
	back_btn.custom_minimum_size = Vector2(64, 64)
	back_btn.add_theme_stylebox_override("normal", ThemeManager.make_soft_style(
		ThemeManager.COLOR_PRIMARY, ThemeManager.COLOR_PRIMARY_DEPTH, 999, false))
	back_btn.add_theme_stylebox_override("hover", ThemeManager.make_soft_style(
		ThemeManager.COLOR_PRIMARY.lightened(0.05), ThemeManager.COLOR_PRIMARY_DEPTH, 999, false))
	back_btn.add_theme_stylebox_override("pressed", ThemeManager.make_soft_style(
		ThemeManager.COLOR_PRIMARY, ThemeManager.COLOR_PRIMARY_DEPTH, 999, true))
	back_btn.add_theme_stylebox_override("disabled", ThemeManager.make_soft_style(
		Color(0.4, 0.4, 0.4, 0.5), Color(0.25, 0.25, 0.25, 0.5), 999))
	back_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	IconDraw.icon_in_button(back_btn, IconDraw.arrow_left(28.0))
	var star_ctrl: Control = IconDraw.star_5pt(24.0)
	star_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HeaderBar/StarBar/StarIcon.add_child(star_ctrl)
	## UX-01: Лічильник зірок в gold pill — зберегти ref ДО reparent
	_star_label = $HeaderBar/StarBar/StarLabel
	_star_label.text = "0"
	var star_pill: PanelContainer = PanelContainer.new()
	star_pill.add_theme_stylebox_override("panel", GameData.star_pill())
	var star_bar: HBoxContainer = $HeaderBar/StarBar
	star_bar.get_parent().add_child(star_pill)
	star_bar.get_parent().move_child(star_pill, star_bar.get_index())
	star_bar.reparent(star_pill)
	_build_collection_button()
	_populate_cards()
	_animate_title()
	_animate_star_counter()
	_build_scroll_hint()
	_apply_premium_bg()
	_start_cloud_parallax()
	## Juicy button squish
	JuicyEffects.button_press_squish($HeaderBar/BackButton, self)
	## Відкладаємо анімацію входу карток — GridContainer має спершу виконати layout
	call_deferred("_animate_cards_entrance")
	call_deferred("_check_scroll_overflow")


func _apply_safe_area() -> void:
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	var full: Vector2i = DisplayServer.screen_get_size()
	if sa.size.x == 0 or full.x == 0:
		return
	var left: float = float(sa.position.x)
	var top: float = float(sa.position.y)
	var right: float = float(full.x - sa.end.x)
	$HeaderBar.offset_left = maxf($HeaderBar.offset_left, left + 8.0)
	$HeaderBar.offset_right = minf($HeaderBar.offset_right, -(right + 8.0))
	$HeaderBar.offset_top = maxf($HeaderBar.offset_top, top + 4.0)
	$ScrollContainer.offset_top = maxf($ScrollContainer.offset_top, top + 72.0)


func _build_collection_button() -> void:
	## Кнопка "Collection" — відкриває екран колекції тварин
	var btn: Button = Button.new()
	btn.text = tr("BTN_COLLECTION")
	btn.custom_minimum_size = Vector2(120, 48)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", ThemeManager.make_soft_style(
		ThemeManager.COLOR_GOLD, ThemeManager.COLOR_GOLD_DEPTH, 16, false))
	btn.add_theme_stylebox_override("hover", ThemeManager.make_soft_style(
		ThemeManager.COLOR_GOLD.lightened(0.05), ThemeManager.COLOR_GOLD_DEPTH, 16, false))
	btn.add_theme_stylebox_override("pressed", ThemeManager.make_soft_style(
		ThemeManager.COLOR_GOLD, ThemeManager.COLOR_GOLD_DEPTH, 16, true))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_on_collection_pressed)
	## Додаємо перед Spacer щоб кнопка була поруч з заголовком
	var spacer: Control = $HeaderBar/Spacer
	$HeaderBar.add_child(btn)
	$HeaderBar.move_child(btn, spacer.get_index())
	JuicyEffects.button_press_squish(btn, self)


func _on_collection_pressed() -> void:
	if _buttons_disabled or _info_panel_animating:
		return
	_buttons_disabled = true
	AudioManager.play_sfx("click")
	SceneManager.goto_scene("res://scenes/ui/collection_screen.tscn")


func _populate_cards() -> void:
	var grid: GridContainer = $ScrollContainer/GridContainer
	var group: int = SettingsManager.age_group
	var games: Array[Dictionary] = GameCatalog.get_all_games_sorted(group)
	if games.size() < 10:
		push_warning("GameHub: FALLBACK — отримано лише %d ігор (age=%d), показуємо всі" % [games.size(), group])
		games = GameCatalog.GAMES.duplicate()
	for data: Dictionary in games:
		var card: Control = GAME_CARD_SCENE.instantiate()
		grid.add_child(card)
		var is_recommended: bool = GameCatalog.is_game_recommended(data, group)
		card.setup(data, is_recommended)
		card.pressed.connect(_on_card_pressed)
		_cards.append(card)


func _animate_title() -> void:
	var title: Label = $HeaderBar/TitleLabel
	title.pivot_offset = title.size / 2.0
	if SettingsManager.reduced_motion:
		title.scale = Vector2.ONE
		title.modulate.a = 1.0
		return
	title.scale = Vector2.ZERO
	title.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(title, "scale", Vector2(1.15, 1.15), 0.5)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(title, "modulate:a", 1.0, 0.3)
	tw.chain().tween_property(title, "scale", Vector2.ONE, 0.2)


func _animate_cards_entrance() -> void:
	if SettingsManager.reduced_motion:
		for card: Control in _cards:
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
		return
	for i: int in _cards.size():
		var card: Control = _cards[i]
		card.pivot_offset = card.size / 2.0
		card.scale = Vector2(0.3, 0.3)
		card.modulate.a = 0.0
		## Зсув вниз для slide-up ефекту
		var base_y: float = card.position.y
		card.position.y = base_y + CASCADE_SLIDE_DIST
		var delay: float = float(i) * CASCADE_DELAY
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(card, "scale", Vector2(1.04, 1.04),
			CASCADE_SCALE_DUR).set_delay(delay)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0,
			CASCADE_FADE_DUR).set_delay(delay)
		tw.tween_property(card, "position:y", base_y,
			CASCADE_SCALE_DUR * 0.8).set_delay(delay)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(card, "scale", Vector2.ONE, 0.12)\
			.set_trans(Tween.TRANS_CUBIC)


func _build_scroll_hint() -> void:
	## UX-10: Анімований індикатор прокрутки (стрілка вниз)
	var chevron: Control = IconDraw.dropdown_chevron(24.0, Color(1, 1, 1, 0.6))
	chevron.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	chevron.offset_top = -40.0
	chevron.offset_left = -12.0
	chevron.offset_right = 12.0
	_scroll_hint = chevron
	add_child(_scroll_hint)
	## Пульсуюча анімація
	if not SettingsManager.reduced_motion:
		var tw: Tween = create_tween().set_loops()
		tw.tween_property(_scroll_hint, "modulate:a", 0.3, 0.8)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_scroll_hint, "modulate:a", 0.8, 0.8)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _check_scroll_overflow() -> void:
	var grid: GridContainer = $ScrollContainer/GridContainer
	if grid.size.y <= $ScrollContainer.size.y:
		## Контент вміщується — ховаємо індикатор
		if _scroll_hint:
			_scroll_hint.visible = false
	else:
		$ScrollContainer.get_v_scroll_bar().value_changed.connect(_on_scroll)


func _on_scroll(_value: float) -> void:
	if _scroll_hint and _scroll_hint.visible:
		if SettingsManager.reduced_motion:
			_scroll_hint.visible = false
			return
		var tw: Tween = create_tween()
		tw.tween_property(_scroll_hint, "modulate:a", 0.0, 0.3)
		tw.finished.connect(func() -> void:
			if is_instance_valid(_scroll_hint):
				_scroll_hint.visible = false)


func _animate_star_counter() -> void:
	var label: Label = _star_label
	var target: int = ProgressManager.stars
	if target <= 0:
		label.text = "0"
		return
	if SettingsManager.reduced_motion:
		label.text = str(target)
		return
	var update_label: Callable = func(val: float) -> void:
		if is_instance_valid(label):
			label.text = str(int(val))
	var tw: Tween = create_tween()
	tw.tween_method(update_label, 0.0, float(target), 0.6).set_delay(0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_card_pressed(game_id: String) -> void:
	if _buttons_disabled or _info_panel_animating:
		return
	var data: Dictionary = GameCatalog.get_game_by_id(game_id)
	if data.is_empty():
		push_warning("GameHub: гру '%s' не знайдено" % game_id)
		return
	## Якщо панель вже відкрита для іншої гри — закрити і відкрити нову
	if is_instance_valid(_info_panel):
		_close_info_panel()
		await get_tree().create_timer(INFO_SLIDE_DUR + 0.05).timeout
		if not is_instance_valid(self):
			push_warning("GameHub: сцена знищена під час очікування")
			return
	_show_info_panel(data)


func _launch_game(data: Dictionary) -> void:
	## Запуск гри — витягнуто з _on_card_pressed
	var scene_path: String = data.get("scene_path", "")
	if scene_path.is_empty():
		push_warning("GameHub: шлях сцени порожній для '%s'" % data.get("id", "?"))
		return
	_buttons_disabled = true
	_disable_all()
	SceneManager.goto_scene(scene_path)


## ---------- INFO PANEL ----------

func _show_info_panel(data: Dictionary) -> void:
	_info_panel_data = data
	var vp: Vector2 = get_viewport_rect().size
	var game_color: Color = data.get("color", Color.WHITE)
	var name_key: String = data.get("name_key", "")
	var desc_key: String = data.get("desc_key", "")
	var skill_key: String = data.get("skill_key", "")

	## Dimmer — напівпрозорий фон для закриття по тапу поза панеллю
	_info_dimmer = ColorRect.new()
	_info_dimmer.color = Color(0, 0, 0, 0.35)
	_info_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_info_dimmer.z_index = 10
	_info_dimmer.gui_input.connect(_on_dimmer_input)
	add_child(_info_dimmer)

	## Panel (НЕ PanelContainer — free-form layout для close button position)
	_info_panel = Panel.new()
	_info_panel.custom_minimum_size = Vector2(INFO_PANEL_W, INFO_PANEL_H)
	_info_panel.size = Vector2(INFO_PANEL_W, INFO_PANEL_H)
	var panel_x: float = vp.x - INFO_PANEL_W - INFO_PANEL_MARGIN
	var panel_y: float = vp.y * 0.15
	_info_panel.position = Vector2(panel_x, panel_y)
	_info_panel.z_index = 11

	## Стиль панелі — solid white з тінню для контрасту та читабельності
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(1.0, 1.0, 1.0, 0.98)
	panel_style.set_corner_radius_all(20)
	panel_style.set_content_margin_all(20)
	panel_style.shadow_color = Color(0, 0, 0, 0.25)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(2, 4)
	panel_style.border_color = Color(0.85, 0.85, 0.85, 1.0)
	panel_style.set_border_width_all(1)
	_info_panel.add_theme_stylebox_override("panel", panel_style)

	## NOTE: NO grain material on info panel — it washes out text readability

	## VBoxContainer для контенту — positioned with margins inside Panel
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 6)
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(INFO_PANEL_W - 40, INFO_PANEL_H - 40)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.add_child(vbox)

	## 1. Назва гри
	var title_label: Label = Label.new()
	title_label.text = tr(name_key) if name_key != "" else data.get("id", "")
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", game_color.darkened(0.3))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_label)

	## 2. Розділювач
	var divider: ColorRect = ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.8, 0.8, 0.8, 1.0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	## 3. "Що робити:" — заголовок секції
	var what_label: Label = Label.new()
	what_label.text = tr("INFO_WHAT_TO_DO")
	what_label.add_theme_font_size_override("font_size", 20)
	what_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	what_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(what_label)

	## 4. Опис гри
	var desc_label: Label = Label.new()
	desc_label.text = tr(desc_key) if desc_key != "" else ""
	desc_label.add_theme_font_size_override("font_size", 22)
	desc_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)

	## 5. Spacer
	var spacer1: Control = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 16)
	spacer1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer1)

	## 6. "Розвиває:" — заголовок секції
	var skill_header: Label = Label.new()
	skill_header.text = tr("INFO_DEVELOPS")
	skill_header.add_theme_font_size_override("font_size", 20)
	skill_header.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	skill_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(skill_header)

	## 7. Навичка
	var skill_label: Label = Label.new()
	skill_label.text = tr(skill_key) if skill_key != "" else ""
	skill_label.add_theme_font_size_override("font_size", 22)
	skill_label.add_theme_color_override("font_color", Color("0a8a5e"))
	skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(skill_label)

	## 8. Spacer
	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 24)
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer2)

	## 9. Кнопка "ГРАТИ!"
	var play_btn: Button = Button.new()
	play_btn.text = tr("BADGE_PLAY")
	play_btn.custom_minimum_size = Vector2(200, 50)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_btn.add_theme_font_size_override("font_size", 24)
	play_btn.add_theme_color_override("font_color", Color.WHITE)
	play_btn.add_theme_stylebox_override("normal", ThemeManager.make_soft_style(
		ThemeManager.COLOR_PRIMARY, ThemeManager.COLOR_PRIMARY_DEPTH, 16, false))
	play_btn.add_theme_stylebox_override("hover", ThemeManager.make_soft_style(
		ThemeManager.COLOR_PRIMARY.lightened(0.05), ThemeManager.COLOR_PRIMARY_DEPTH, 16, false))
	play_btn.add_theme_stylebox_override("pressed", ThemeManager.make_soft_style(
		ThemeManager.COLOR_PRIMARY, ThemeManager.COLOR_PRIMARY_DEPTH, 16, true))
	play_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	play_btn.pressed.connect(_on_info_play_pressed)
	vbox.add_child(play_btn)

	## 10. Кнопка закриття "✕" — child of Panel (Panel підтримує free positioning)
	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.size = Vector2(40, 40)
	close_btn.position = Vector2(INFO_PANEL_W - 48, 8)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	var close_style: StyleBoxFlat = StyleBoxFlat.new()
	close_style.bg_color = Color(0.92, 0.92, 0.92, 1.0)
	close_style.set_corner_radius_all(20)
	close_style.set_content_margin_all(0)
	close_btn.add_theme_stylebox_override("normal", close_style)
	var close_hover: StyleBoxFlat = close_style.duplicate()
	close_hover.bg_color = Color(0.85, 0.85, 0.85, 1.0)
	close_btn.add_theme_stylebox_override("hover", close_hover)
	var close_pressed: StyleBoxFlat = close_style.duplicate()
	close_pressed.bg_color = Color(0.75, 0.75, 0.75, 1.0)
	close_btn.add_theme_stylebox_override("pressed", close_pressed)
	close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_btn.pressed.connect(_on_info_close_pressed)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_panel.add_child(close_btn)

	add_child(_info_panel)

	## Анімація slide-in справа
	_info_panel_animating = true
	if SettingsManager.reduced_motion:
		_info_panel_animating = false
	else:
		var start_x: float = vp.x
		_info_panel.position.x = start_x
		var tw: Tween = create_tween()
		tw.tween_property(_info_panel, "position:x", panel_x, INFO_SLIDE_DUR)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.finished.connect(func() -> void:
			_info_panel_animating = false)

	AudioManager.play_sfx("click")


func _close_info_panel() -> void:
	if not is_instance_valid(_info_panel):
		push_warning("GameHub: _close_info_panel — панель вже не існує")
		return
	if _info_panel_animating:
		return
	_info_panel_animating = true
	_info_panel_data = {}

	## Видалити dimmer (close button = child of panel, freed with it)
	if is_instance_valid(_info_dimmer):
		_info_dimmer.queue_free()
		_info_dimmer = null

	if SettingsManager.reduced_motion:
		_info_panel.queue_free()
		_info_panel = null
		_info_panel_animating = false
		return

	var vp_x: float = get_viewport_rect().size.x
	var tw: Tween = create_tween()
	tw.tween_property(_info_panel, "position:x", vp_x, INFO_SLIDE_DUR)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.finished.connect(func() -> void:
		if is_instance_valid(_info_panel):
			_info_panel.queue_free()
			_info_panel = null
		_info_panel_animating = false)


func _on_info_play_pressed() -> void:
	if _info_panel_animating or _buttons_disabled:
		return
	var data: Dictionary = _info_panel_data
	if data.is_empty():
		push_warning("GameHub: _on_info_play_pressed — дані гри порожні")
		return
	## Закрити панель і запустити гру
	if is_instance_valid(_info_dimmer):
		_info_dimmer.queue_free()
		_info_dimmer = null
	if is_instance_valid(_info_panel):
		_info_panel.queue_free()
		_info_panel = null
	_info_panel_data = {}
	_launch_game(data)


func _on_info_close_pressed() -> void:
	AudioManager.play_sfx("click")
	_close_info_panel()


func _on_dimmer_input(event: InputEvent) -> void:
	if _info_panel_animating:
		return
	var is_tap: bool = false
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		is_tap = true
	elif event is InputEventScreenTouch and event.pressed:
		is_tap = true
	if is_tap:
		get_viewport().set_input_as_handled()
		_close_info_panel()


func _disable_all() -> void:
	for card: Control in _cards:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_premium_bg() -> void:
	## Замінити статичний SkyBackground на premium градієнт з шейдером
	var sky: ColorRect = $SkyBackground
	if is_instance_valid(sky):
		sky.visible = false
	var bg: TextureRect = TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -2
	add_child(bg)
	move_child(bg, 0)
	GameData.apply_premium_background(bg, "ocean", SettingsManager.reduced_motion)
	GameData.add_bg_elements(self, "ocean", SettingsManager.reduced_motion)


func _start_cloud_parallax() -> void:
	var cloud: TextureRect = $CloudLayer
	if not is_instance_valid(cloud) or not cloud.texture:
		return
	if SettingsManager and SettingsManager.reduced_motion:
		return
	var drift: float = cloud.texture.get_width() * 0.3
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(cloud, "position:x", -drift, 20.0)\
		.set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(cloud, "position:x", 0.0, 20.0)\
		.set_trans(Tween.TRANS_LINEAR)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		## Якщо інфо-панель відкрита — закрити її замість виходу
		if is_instance_valid(_info_panel) and not _info_panel_animating:
			_close_info_panel()
			return
		_on_back_pressed()


func _on_back_pressed() -> void:
	if _buttons_disabled:
		return
	_buttons_disabled = true
	AudioManager.play_sfx("click")
	SceneManager.goto_scene("res://scenes/ui/main_menu.tscn")
