extends Control

## Магазин — гача-бокси (тварини) + фони для головного меню.
## Використовує SettingsManager.buy_background() / equip_background() для фонів.

const GACHA_COST: int = 150
const GACHA_REVEAL_SCENE: PackedScene = preload("res://scenes/ui/gacha_reveal.tscn")
const BG_CARD_MIN_H: float = 160.0
const BG_PREVIEW_H: float = 100.0
const BG_GRID_COLS: int = 3

var _star_label: Label = null
var _gacha_btn: Button = null
var _info_label: Label = null
var _buy_locked: bool = false

## Таби
var _tab_animals: Button = null
var _tab_bgs: Button = null
var _animals_container: Control = null
var _bgs_container: ScrollContainer = null
var _bg_cards: Dictionary = {}  ## {id: {panel, btn, label}}


func _ready() -> void:
	## Grain overlay на весь UI (LAW 28 — premium texture)
	material = GameData.create_premium_material(0.02, 2.0, 0.0, 0.0, 0.03, 0.04, 0.10, "", 0.0, 0.08, 0.18, 0.15)
	_apply_safe_area()
	_apply_background()
	_build_ui()
	_update_ui()
	IconDraw.icon_in_button($BackButton, IconDraw.arrow_left(28.0))
	JuicyEffects.button_press_squish($BackButton, self)
	_animate_entrance()


func _apply_safe_area() -> void:
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	var full: Vector2i = DisplayServer.screen_get_size()
	if sa.size.x == 0 or full.x == 0:
		return
	var top: float = float(sa.position.y)
	if top > 0.0:
		$VBox.offset_top += top


func _apply_background() -> void:
	var bg: TextureRect = $Background as TextureRect
	if not bg:
		return
	GameData.apply_premium_background(bg, "candy", SettingsManager.reduced_motion)


func _build_ui() -> void:
	var vbox: VBoxContainer = $VBox
	## Заголовок
	vbox.get_node("TitleLabel").text = tr("BTN_SHOP")
	_star_label = vbox.get_node("StarLabel")
	## IconDraw зірка перед числом
	var star_icon: Control = IconDraw.star_5pt(18.0)
	star_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	star_icon.offset_left = -22.0
	star_icon.offset_right = 0.0
	_star_label.add_child(star_icon)

	## --- Таб-кнопки ---
	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bar.set("theme_override_constants/separation", 16)
	tab_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Вставити після StarLabel (index 1), перед GachaButton
	var star_idx: int = _star_label.get_index()
	vbox.add_child(tab_bar)
	vbox.move_child(tab_bar, star_idx + 1)

	_tab_animals = Button.new()
	_tab_animals.text = tr("TAB_ANIMALS")
	_tab_animals.theme_type_variation = &"PillButton"
	_tab_animals.custom_minimum_size = Vector2(160, 48)
	_tab_animals.pressed.connect(_show_animals_tab)
	tab_bar.add_child(_tab_animals)
	JuicyEffects.button_press_squish(_tab_animals, self)

	_tab_bgs = Button.new()
	_tab_bgs.text = tr("TAB_BACKGROUNDS")
	_tab_bgs.theme_type_variation = &"PillButton"
	_tab_bgs.custom_minimum_size = Vector2(160, 48)
	_tab_bgs.pressed.connect(_show_bgs_tab)
	tab_bar.add_child(_tab_bgs)
	JuicyEffects.button_press_squish(_tab_bgs, self)

	## --- Контейнер тварин (обгортка існуючих вузлів) ---
	_animals_container = VBoxContainer.new()
	_animals_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_animals_container.set("theme_override_constants/separation", 16)
	_animals_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_animals_container)
	## Переносимо GachaButton та InfoLabel в контейнер тварин
	_gacha_btn = vbox.get_node("GachaButton")
	_info_label = vbox.get_node("InfoLabel")
	_gacha_btn.reparent(_animals_container)
	_info_label.reparent(_animals_container)
	JuicyEffects.button_press_squish(_gacha_btn, self)

	## --- Контейнер фонів ---
	_bgs_container = ScrollContainer.new()
	_bgs_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bgs_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bgs_container.custom_minimum_size = Vector2(0, 340)
	_bgs_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_bgs_container)

	var grid: GridContainer = GridContainer.new()
	grid.columns = BG_GRID_COLS
	grid.set("theme_override_constants/h_separation", 16)
	grid.set("theme_override_constants/v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bgs_container.add_child(grid)
	## mouse_filter IGNORE на grid — не блокувати input до BackButton
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Побудувати картки фонів
	for bg_data: Dictionary in BgCatalog.BACKGROUNDS:
		var card: PanelContainer = _build_bg_card(bg_data)
		grid.add_child(card)

	## Початковий таб — тварини
	_show_animals_tab()


func _build_bg_card(bg_data: Dictionary) -> PanelContainer:
	var id: String = bg_data.id as String
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, BG_CARD_MIN_H)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style: StyleBoxFlat = GameData.candy_panel(Color(0.15, 0.12, 0.2, 0.85), 12)
	card_style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", card_style)

	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.set("theme_override_constants/separation", 4)
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(card_vbox)

	## Прев'ю текстура — розтягується по ширині картки
	var preview: TextureRect = TextureRect.new()
	preview.custom_minimum_size = Vector2(0, BG_PREVIEW_H)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var preview_path: String = BgCatalog.get_preview_path(id)
	if ResourceLoader.exists(preview_path):
		preview.texture = load(preview_path)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(preview)

	## Назва
	var name_lbl: Label = Label.new()
	name_lbl.text = tr(bg_data.name_key as String)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(name_lbl)

	## Кнопка купити / екіпувати
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_on_bg_card_pressed.bind(id))
	JuicyEffects.button_press_squish(btn, self)
	card_vbox.add_child(btn)

	_bg_cards[id] = {"panel": card, "btn": btn, "label": name_lbl}
	return card


func _update_bg_cards() -> void:
	var equipped_id: String = SettingsManager.current_bg
	for bg_data: Dictionary in BgCatalog.BACKGROUNDS:
		var id: String = bg_data.id as String
		if not _bg_cards.has(id):
			continue
		var btn: Button = _bg_cards[id].btn as Button
		var cost: int = bg_data.cost as int
		var owned: bool = SettingsManager.unlocked_backgrounds.has(id)
		if owned and id == equipped_id:
			btn.text = tr("LBL_EQUIPPED")
			btn.disabled = true
			btn.theme_type_variation = &"SecondaryButton"
		elif owned:
			btn.text = tr("LBL_EQUIP")
			btn.disabled = false
			btn.theme_type_variation = &"PillButton"
		else:
			btn.text = tr("BTN_BUY_BG") % cost
			btn.disabled = false
			btn.theme_type_variation = &"AccentButton"


func _on_bg_card_pressed(id: String) -> void:
	if _buy_locked:
		return
	var bg_data: Dictionary = BgCatalog.get_bg(id)
	var owned: bool = SettingsManager.unlocked_backgrounds.has(id)
	if owned:
		## Екіпувати
		SettingsManager.equip_background(id)
		AudioManager.play_sfx("click")
		_update_bg_cards()
		return
	## Купити
	var cost: int = bg_data.cost as int
	if ProgressManager.stars < cost:
		_show_bg_not_enough(id)
		return
	_buy_locked = true
	if not SettingsManager.buy_background(id, cost):
		_buy_locked = false
		return
	AudioManager.play_sfx("coin")
	_update_ui()
	_update_bg_cards()
	## Святкова анімація картки (LAW 28 — anticipation; reduced_motion safe)
	if _bg_cards.has(id):
		var panel: PanelContainer = _bg_cards[id].panel as PanelContainer
		if SettingsManager.reduced_motion:
			_buy_locked = false
		else:
			panel.pivot_offset = panel.size / 2.0
			var tw: Tween = create_tween()
			tw.tween_property(panel, "scale", Vector2(1.15, 1.15), 0.2)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(panel, "scale", Vector2.ONE, 0.15)
			tw.tween_callback(func() -> void: _buy_locked = false)


func _show_bg_not_enough(id: String) -> void:
	AudioManager.play_sfx("error")
	if not _bg_cards.has(id):
		return
	if SettingsManager.reduced_motion:
		return
	var panel: PanelContainer = _bg_cards[id].panel as PanelContainer
	var orig_x: float = panel.position.x
	var tw: Tween = create_tween()
	tw.tween_property(panel, "position:x", orig_x + 6.0, 0.05)
	tw.tween_property(panel, "position:x", orig_x - 6.0, 0.05)
	tw.tween_property(panel, "position:x", orig_x, 0.05)


func _show_animals_tab() -> void:
	_animals_container.visible = true
	_bgs_container.visible = false
	_tab_animals.modulate = Color.WHITE
	_tab_bgs.modulate = Color(1, 1, 1, 0.5)


func _show_bgs_tab() -> void:
	_animals_container.visible = false
	_bgs_container.visible = true
	_tab_animals.modulate = Color(1, 1, 1, 0.5)
	_tab_bgs.modulate = Color.WHITE
	_update_bg_cards()
	## Каскадний вхід карток (LAW 28 — anticipation)
	if not SettingsManager.reduced_motion:
		var idx: int = 0
		for bg_data: Dictionary in BgCatalog.BACKGROUNDS:
			var id: String = bg_data.id as String
			if not _bg_cards.has(id):
				continue
			var panel: PanelContainer = _bg_cards[id].panel as PanelContainer
			panel.modulate.a = 0.0
			panel.pivot_offset = panel.size / 2.0
			panel.scale = Vector2(0.8, 0.8)
			var delay: float = float(idx) * 0.04
			var tw: Tween = create_tween().set_parallel(true)
			tw.tween_property(panel, "modulate:a", 1.0, 0.2).set_delay(delay)
			tw.tween_property(panel, "scale", Vector2.ONE, 0.25)\
				.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			idx += 1


func _update_ui() -> void:
	_star_label.text = " %d" % ProgressManager.stars
	var all_unlocked: bool = _are_all_animals_unlocked()
	if all_unlocked:
		_gacha_btn.text = tr("MSG_ALL_UNLOCKED")
		_gacha_btn.disabled = true
	else:
		_gacha_btn.text = tr("BTN_GACHA") % GACHA_COST
		_gacha_btn.disabled = ProgressManager.stars < GACHA_COST
	_info_label.text = ""


func _on_gacha_pressed() -> void:
	if _buy_locked:
		return
	if ProgressManager.stars < GACHA_COST:
		_show_not_enough()
		return
	var animal: String = _pick_random_locked_animal()
	if animal.is_empty():
		_info_label.text = tr("MSG_ALL_UNLOCKED")
		return
	_buy_locked = true
	ProgressManager.add_stars(-GACHA_COST)
	ProgressManager.unlock_animal(animal)
	AudioManager.play_sfx("coin")
	var reveal: CanvasLayer = GACHA_REVEAL_SCENE.instantiate()
	add_child(reveal)
	reveal.reveal_animal(animal)
	reveal.reveal_closed.connect(func() -> void:
		_buy_locked = false
		_update_ui()
	)


func _pick_random_locked_animal() -> String:
	var locked: Array[String] = []
	for pair: Dictionary in GameData.ANIMALS_AND_FOOD:
		if not ProgressManager.is_animal_unlocked(pair.name):
			locked.append(pair.name)
	if locked.is_empty():
		return ""
	return locked[randi() % locked.size()]


func _are_all_animals_unlocked() -> bool:
	for pair: Dictionary in GameData.ANIMALS_AND_FOOD:
		if not ProgressManager.is_animal_unlocked(pair.name):
			return false
	return true


func _animate_entrance() -> void:
	## Заголовок — pop-in
	var title: Label = $VBox/TitleLabel
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2.ZERO
	title.modulate.a = 0.0
	if SettingsManager.reduced_motion:
		title.scale = Vector2.ONE
		title.modulate.a = 1.0
	else:
		var t_tw: Tween = create_tween().set_parallel(true)
		t_tw.tween_property(title, "scale", Vector2(1.1, 1.1), 0.5)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t_tw.tween_property(title, "modulate:a", 1.0, 0.3)
		t_tw.chain().tween_property(title, "scale", Vector2.ONE, 0.15)
	## Зірки — count-up
	var target_stars: int = ProgressManager.stars
	if target_stars > 0 and not SettingsManager.reduced_motion:
		_star_label.text = " 0"
		var count_cb: Callable = func(val: float) -> void:
			if is_instance_valid(_star_label):
				_star_label.text = " %d" % int(val)
		var s_tw: Tween = create_tween()
		s_tw.tween_method(count_cb, 0.0, float(target_stars), 0.6).set_delay(0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	## Кнопка гачі — bounce entrance
	if not SettingsManager.reduced_motion:
		_gacha_btn.pivot_offset = _gacha_btn.size / 2.0
		_gacha_btn.scale = Vector2.ZERO
		_gacha_btn.modulate.a = 0.0
		var g_tw: Tween = create_tween().set_parallel(true)
		g_tw.tween_property(_gacha_btn, "scale", Vector2(1.08, 1.08), 0.45)\
			.set_delay(0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		g_tw.tween_property(_gacha_btn, "modulate:a", 1.0, 0.2).set_delay(0.25)
		g_tw.chain().tween_property(_gacha_btn, "scale", Vector2.ONE, 0.1)
		if not _gacha_btn.disabled:
			g_tw.chain().tween_callback(func() -> void:
				var pulse: Tween = create_tween().set_loops()
				pulse.tween_property(_gacha_btn, "scale", Vector2(1.04, 1.04), 0.9)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				pulse.tween_property(_gacha_btn, "scale", Vector2.ONE, 0.9)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			)


func _show_not_enough() -> void:
	_info_label.text = tr("SHOP_NOT_ENOUGH")
	AudioManager.play_sfx("error")
	var orig_x: float = _gacha_btn.position.x
	var tw: Tween = create_tween()
	tw.tween_property(_gacha_btn, "position:x", orig_x + 8.0, 0.05)
	tw.tween_property(_gacha_btn, "position:x", orig_x - 8.0, 0.05)
	tw.tween_property(_gacha_btn, "position:x", orig_x, 0.05)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	AudioManager.play_sfx("click")
	var tw: Tween = create_tween()
	if is_instance_valid(_gacha_btn) and not SettingsManager.reduced_motion:
		_gacha_btn.pivot_offset = _gacha_btn.size / 2.0
		tw.tween_property(_gacha_btn, "scale", Vector2.ZERO, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		SceneManager.goto_scene("res://scenes/ui/main_menu.tscn"))
