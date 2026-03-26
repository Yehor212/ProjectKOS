extends Control

const CASCADE_DELAY: float = 0.06
const CASCADE_DUR: float = 0.4

var _sway_material: ShaderMaterial = null
var _grid_items: Array[TextureRect] = []


func _ready() -> void:
	## Grain overlay на весь UI (LAW 28 — premium texture)
	material = GameData.create_premium_material(0.02, 2.0, 0.0, 0.0, 0.03, 0.04, 0.10, "", 0.0, 0.08, 0.18, 0.15)
	GameData.apply_premium_background($Background as TextureRect, "forest", SettingsManager.reduced_motion)
	GameData.add_bg_elements(self, "forest", SettingsManager.reduced_motion, 0.5)
	_apply_safe_area()
	_sway_material = GameData.create_sway_material()
	$VBoxContainer/TitleLabel.text = tr("TITLE_COLLECTION")
	IconDraw.icon_in_button($BackButton, IconDraw.arrow_left(28.0))
	## Juicy button squish
	JuicyEffects.button_press_squish($BackButton, self)
	_populate_grid()
	_animate_entrance()


func _apply_safe_area() -> void:
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	var full: Vector2i = DisplayServer.screen_get_size()
	if sa.size.x == 0 or full.x == 0:
		return
	var top: float = float(sa.position.y)
	if top > 0.0:
		$VBoxContainer.offset_top += top


func _populate_grid() -> void:
	var grid: GridContainer = $VBoxContainer/ScrollContainer/GridContainer
	for pair: Dictionary in GameData.ANIMALS_AND_FOOD:
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(120, 120)
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex_path: String = "res://assets/sprites/animals/%s.png" % pair.name
		if ResourceLoader.exists(tex_path):
			tex_rect.texture = load(tex_path)
		var unlocked: bool = ProgressManager.is_animal_unlocked(pair.name)
		if unlocked:
			if _sway_material:
				tex_rect.material = _sway_material
			tex_rect.gui_input.connect(_on_sticker_tapped.bind(tex_rect))
		else:
			tex_rect.modulate = Color(0.4, 0.4, 0.4, 0.6)
		grid.add_child(tex_rect)
		_grid_items.append(tex_rect)


func _animate_entrance() -> void:
	## Заголовок — pop-in
	var title: Label = $VBoxContainer/TitleLabel
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2.ZERO
	title.modulate.a = 0.0
	var t_tw: Tween = create_tween().set_parallel(true)
	t_tw.tween_property(title, "scale", Vector2(1.1, 1.1), 0.5)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t_tw.tween_property(title, "modulate:a", 1.0, 0.3)
	t_tw.chain().tween_property(title, "scale", Vector2.ONE, 0.15)
	## Каскадна поява стікерів
	call_deferred("_cascade_grid_entrance")


func _cascade_grid_entrance() -> void:
	for i: int in _grid_items.size():
		var item: TextureRect = _grid_items[i]
		var saved_modulate: Color = item.modulate
		item.pivot_offset = item.size / 2.0
		item.scale = Vector2(0.3, 0.3)
		item.modulate.a = 0.0
		var delay: float = float(i) * CASCADE_DELAY
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(item, "scale", Vector2(1.05, 1.05), CASCADE_DUR)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(item, "modulate:a", saved_modulate.a, 0.2)\
			.set_delay(delay)
		tw.chain().tween_property(item, "scale", Vector2.ONE, 0.1)


func _on_sticker_tapped(event: InputEvent, tex: TextureRect) -> void:
	var is_tap: bool = false
	if event is InputEventMouseButton and event.pressed:
		is_tap = true
	elif event is InputEventScreenTouch and event.pressed:
		is_tap = true
	if not is_tap:
		return
	AudioManager.play_sfx("click")
	var base: Vector2 = tex.scale
	var tw: Tween = create_tween()
	tw.tween_property(tex, "scale", base * Vector2(1.3, 0.7), 0.08)
	tw.tween_property(tex, "scale", base * Vector2(0.8, 1.2), 0.08)
	tw.tween_property(tex, "scale", base, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	AudioManager.play_sfx("click")
	var popper: UIPopper = $VBoxContainer.get_node_or_null("UIPopper") as UIPopper
	if popper:
		popper.pop_out(func() -> void: SceneManager.goto_scene("res://scenes/ui/main_menu.tscn"))
	else:
		SceneManager.goto_scene("res://scenes/ui/main_menu.tscn")
