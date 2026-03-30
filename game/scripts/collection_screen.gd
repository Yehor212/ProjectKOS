extends Control

## Екран колекції "Село Тофі" — 19 тварин у сітці 4x5 з рівнями дружби.
## Тір 0: темний силует. Тір 1 (Met): кольоровий + пульс.
## Тір 2 (Fed): кольоровий + бронзова рамка. Тір 3 (Best Friend): золота рамка + дихання.

const GRID_COLUMNS: int = 4
const CARD_SIZE: Vector2 = Vector2(140, 170)
const SPRITE_SIZE: float = 100.0
const SILHOUETTE_COLOR: Color = Color(0.15, 0.15, 0.15, 1.0)
const BRONZE_COLOR: Color = Color(0.80, 0.50, 0.20, 1.0)
const GOLD_COLOR: Color = Color(1.0, 0.84, 0.0, 1.0)
const PULSE_DUR: float = 1.2
const BREATH_DUR: float = 2.4
const CASCADE_DELAY: float = 0.06
const CASCADE_FADE_DUR: float = 0.25

## Маппінг ім'я тварини -> ключ перекладу
const ANIMAL_TR_KEYS: Dictionary = {
	"Bunny": "ANIMAL_BUNNY", "Dog": "ANIMAL_DOG", "Bear": "ANIMAL_BEAR",
	"Monkey": "ANIMAL_MONKEY", "Cat": "ANIMAL_CAT", "Chicken": "ANIMAL_CHICKEN",
	"Cow": "ANIMAL_COW", "Crocodile": "ANIMAL_CROCODILE", "Frog": "ANIMAL_FROG",
	"Deer": "ANIMAL_DEER", "Elephant": "ANIMAL_ELEPHANT", "Horse": "ANIMAL_HORSE",
	"Lion": "ANIMAL_LION", "Penguin": "ANIMAL_PENGUIN", "Panda": "ANIMAL_PANDA",
	"Goat": "ANIMAL_GOAT", "Mouse": "ANIMAL_MOUSE", "Squirrel": "ANIMAL_SQUIRREL",
	"Hedgehog": "ANIMAL_HEDGEHOG",
}

## Маппінг тірів -> ключ перекладу для badge
const TIER_TR_KEYS: Dictionary = {
	0: "VILLAGE_TIER_UNKNOWN",
	1: "VILLAGE_TIER_MET",
	2: "VILLAGE_TIER_FED",
	3: "VILLAGE_TIER_BEST_FRIEND",
}

var _cards: Array[PanelContainer] = []
var _buttons_disabled: bool = false


func _ready() -> void:
	$HeaderBar/TitleLabel.text = tr("TITLE_VILLAGE")
	_style_back_button()
	_apply_premium_bg()
	_build_progress_pills()
	_populate_grid()
	JuicyEffects.button_press_squish($HeaderBar/BackButton, self)
	call_deferred("_animate_cards_entrance")


func _style_back_button() -> void:
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


func _apply_premium_bg() -> void:
	var bg: TextureRect = $Background
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -2
	GameData.apply_premium_background(bg, "meadow", SettingsManager.reduced_motion)
	GameData.add_bg_elements(self, "meadow", SettingsManager.reduced_motion)


func _build_progress_pills() -> void:
	var bar: HBoxContainer = $HeaderBar/ProgressBar
	var met_count: int = MasteryManager.get_animals_at_tier(MasteryManager.TIER_MET)
	var fed_count: int = MasteryManager.get_animals_at_tier(MasteryManager.TIER_FED)
	var best_count: int = MasteryManager.get_animals_at_tier(MasteryManager.TIER_BEST_FRIEND)

	## Стікери — кількість зібраних тварин
	var sticker_count: int = ProgressManager.get_sticker_count()
	var total_animals: int = maxi(GameData.ANIMALS_AND_FOOD.size(), 1)
	_add_pill(bar, tr("STICKER_COUNT") % [sticker_count, total_animals],
		Color(1.0, 0.72, 0.0, 1.0), sticker_count)

	_add_pill(bar, tr("VILLAGE_MET") % met_count, ThemeManager.COLOR_PRIMARY, met_count)
	_add_pill(bar, tr("VILLAGE_FED") % fed_count, BRONZE_COLOR, fed_count)
	_add_pill(bar, tr("VILLAGE_BEST_FRIEND") % best_count, GOLD_COLOR, best_count)


func _add_pill(parent: HBoxContainer, text: String, color: Color, count: int) -> void:
	var pill: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	## Підсвітка якщо є прогрес, приглушений якщо 0
	var alpha: float = 0.85 if count > 0 else 0.45
	style.bg_color = Color(color, alpha)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.anti_aliasing_size = 1.2
	if count > 0:
		style.border_width_bottom = 2
		style.border_color = color.darkened(0.25)
	pill.add_theme_stylebox_override("panel", style)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(label)
	parent.add_child(pill)


func _populate_grid() -> void:
	var grid: GridContainer = $ScrollContainer/GridContainer
	var animals: Array[Dictionary] = GameData.ANIMALS_AND_FOOD

	if animals.size() == 0:
		push_warning("CollectionScreen: ANIMALS_AND_FOOD порожній — нічого відображати")
		return

	for i: int in animals.size():
		var pair: Dictionary = animals[i]
		var animal_name: String = pair.get("name", "")
		if animal_name.is_empty():
			push_warning("CollectionScreen: тварина без імені на індексі %d" % i)
			continue
		var tier: int = MasteryManager.get_collection_tier(animal_name)
		var card: PanelContainer = _build_animal_card(animal_name, tier)
		grid.add_child(card)
		_cards.append(card)


func _build_animal_card(animal_name: String, tier: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Стиль картки залежить від тіру
	var card_bg: Color = Color(1.0, 1.0, 1.0, 0.92)
	var border_color: Color = Color(0.85, 0.85, 0.85, 1.0)
	var border_width: int = 1
	if tier >= 3:
		border_color = GOLD_COLOR
		border_width = 3
	elif tier >= 2:
		border_color = BRONZE_COLOR
		border_width = 2

	var style: StyleBoxFlat = GameData.candy_panel(card_bg, 16, true)
	style.border_color = border_color
	style.set_border_width_all(border_width)
	if tier >= 2:
		## Посилена тінь для рамки
		style.shadow_size = 12
		style.shadow_color = Color(border_color, 0.3)
		style.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", style)

	## VBox всередині картки
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	## Контейнер для спрайту (центрований)
	var sprite_holder: CenterContainer = CenterContainer.new()
	sprite_holder.custom_minimum_size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
	sprite_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sprite_holder)

	## Завантаження спрайту (LAW 7: fallback)
	var sprite_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	var tex_rect: TextureRect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ResourceLoader.exists(sprite_path):
		tex_rect.texture = load(sprite_path)
	else:
		push_warning("CollectionScreen: спрайт '%s' не знайдено, fallback placeholder" % sprite_path)
		## LAW 7: Placeholder — кольоровий квадрат замість порожнечі
		var placeholder: StyleBoxFlat = StyleBoxFlat.new()
		placeholder.bg_color = Color(0.7, 0.7, 0.7, 0.5)
		placeholder.set_corner_radius_all(12)
		var ph_panel: Panel = Panel.new()
		ph_panel.custom_minimum_size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
		ph_panel.add_theme_stylebox_override("panel", placeholder)
		ph_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite_holder.add_child(ph_panel)

	## Тір 0: силует (модулят)
	if tier == 0:
		tex_rect.modulate = SILHOUETTE_COLOR
	else:
		tex_rect.modulate = Color.WHITE

	sprite_holder.add_child(tex_rect)

	## Ім'я тварини (або "???" для невідомих)
	var name_label: Label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tier > 0:
		var tr_key: String = ANIMAL_TR_KEYS.get(animal_name, "")
		if tr_key.is_empty():
			push_warning("CollectionScreen: немає ключа перекладу для '%s'" % animal_name)
			name_label.text = animal_name
		else:
			name_label.text = tr(tr_key)
		name_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 1.0))
	else:
		name_label.text = tr("VILLAGE_TIER_UNKNOWN")
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
	vbox.add_child(name_label)

	## Бейдж тіру (LAW 25: текстовий бейдж — не тільки колір)
	if tier > 0:
		var badge: Label = Label.new()
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 24)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tier_key: String = TIER_TR_KEYS.get(tier, "VILLAGE_TIER_UNKNOWN")
		badge.text = tr(tier_key)
		var badge_color: Color = ThemeManager.COLOR_PRIMARY
		if tier == 2:
			badge_color = BRONZE_COLOR
		elif tier == 3:
			badge_color = GOLD_COLOR
		badge.add_theme_color_override("font_color", badge_color)
		vbox.add_child(badge)

	## Стікер-зірка: якщо тварина має стікер, малюємо золоту зірку у верхньому правому куті
	## LAW 25: зірка + текст "стікер" в badge — не тільки колір
	if ProgressManager.has_sticker(animal_name):
		var star_label: Label = Label.new()
		star_label.text = "★"
		star_label.add_theme_font_size_override("font_size", 28)
		star_label.add_theme_color_override("font_color", GOLD_COLOR)
		star_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## Позиціонування: overlay поверх картки (PanelContainer підтримує anchors)
		card.add_child(star_label)
		star_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		star_label.offset_right = -4.0
		star_label.offset_top = 2.0

	## Анімації по тіру (лише якщо reduced_motion вимкнено)
	if not SettingsManager.reduced_motion:
		if tier == 1:
			_animate_pulse(tex_rect)
		elif tier == 3:
			_animate_breathing(tex_rect)

	return card


func _animate_pulse(target: Control) -> void:
	## Тір 1 "Met" — м'який пульс модуляції
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(target, "modulate:a", 0.7, PULSE_DUR * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, "modulate:a", 1.0, PULSE_DUR * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_breathing(target: Control) -> void:
	## Тір 3 "Best Friend" — idle дихання (масштаб)
	## Відкладаємо — pivot_offset потребує реального розміру після layout
	call_deferred("_deferred_breathing", target)


func _deferred_breathing(target: Control) -> void:
	if not is_instance_valid(target):
		push_warning("CollectionScreen: target знищений перед breathing анімацією")
		return
	var sz: Vector2 = target.size
	if sz.x < 1.0:
		sz = Vector2(SPRITE_SIZE, SPRITE_SIZE)
	target.pivot_offset = sz / 2.0
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(target, "scale", Vector2(1.04, 1.04), BREATH_DUR * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, "scale", Vector2.ONE, BREATH_DUR * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _animate_cards_entrance() -> void:
	if SettingsManager.reduced_motion:
		for card: PanelContainer in _cards:
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
		return
	for i: int in _cards.size():
		var card: PanelContainer = _cards[i]
		card.pivot_offset = card.size / 2.0
		card.scale = Vector2(0.3, 0.3)
		card.modulate.a = 0.0
		var delay: float = float(i) * CASCADE_DELAY
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(card, "scale", Vector2(1.03, 1.03), 0.4)\
			.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, CASCADE_FADE_DUR)\
			.set_delay(delay)
		tw.chain().tween_property(card, "scale", Vector2.ONE, 0.1)\
			.set_trans(Tween.TRANS_CUBIC)


func _on_back_pressed() -> void:
	if _buttons_disabled:
		return
	_buttons_disabled = true
	AudioManager.play_sfx("click")
	SceneManager.goto_scene("res://scenes/ui/game_hub.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
