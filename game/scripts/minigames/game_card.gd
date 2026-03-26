extends Control

## Картка міні-гри — flat-style з круглим фоном іконки,
## shimmer для заблокованих, floating icon та VFX.

signal pressed(game_id: String)

const CARD_RADIUS: int = 20
const FLOAT_AMP: float = 3.0
const FLOAT_DUR: float = 2.0
const SHIMMER_OFFSET_MAX: float = 4.0
const JIGGLE_INTERVAL_MIN: float = 6.0
const JIGGLE_INTERVAL_MAX: float = 10.0
const ICON_BG_SIZE: float = 72.0
const ICON_DRAW_SIZE: float = 60.0
var _game_data: Dictionary = {}
var _is_unlocked: bool = false
var _is_recommended: bool = true
var _float_tween: Tween = null
var _shimmer_overlay: ColorRect = null
var _pulse_tween: Tween = null
var _jiggle_timer: Timer = null
var _icon_ctrl: Control = null
var _icon_bg: Control = null
var _icon_container: Control = null
var _icon_bg_base_y: float = 0.0
var _icon_ctrl_base_y: float = 0.0
var _press_locked: bool = false


func setup(data: Dictionary, recommended: bool = true) -> void:
	_game_data = data
	_is_unlocked = data.get("unlocked", false)
	_is_recommended = recommended
	custom_minimum_size = Vector2(0, 140)
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## Панель з flat-style
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "CardPanel"
	var card_color: Color = data.get("color", Color.WHITE)
	if not _is_unlocked:
		card_color = card_color.lerp(Color(0.5, 0.5, 0.5), 0.5)
	panel.add_theme_stylebox_override("panel", _make_card_style(card_color))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	## HBox — іконка + інфо
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.set("theme_override_constants/separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	## Контейнер іконки
	_icon_container = Control.new()
	_icon_container.custom_minimum_size = Vector2(84, 84)
	_icon_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_container.clip_contents = true
	_icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_icon_container)

	## Круглий фон — bare Control з draw_circle (без Panel/clip_contents)
	var circle_center: Vector2 = Vector2(42.0, 42.0)
	var circle_radius: float = ICON_BG_SIZE / 2.0
	var bg_color: Color = Color(0.22, 0.24, 0.28, 0.9)
	var border_c: Color = card_color.lightened(0.1)
	if not _is_unlocked:
		bg_color = Color(0.35, 0.35, 0.38, 0.7)
		border_c = Color(0.5, 0.5, 0.5, 0.5)
	_icon_bg = Control.new()
	_icon_bg.custom_minimum_size = Vector2(84, 84)
	_icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_bg.draw.connect(func() -> void:
		## Тінь
		_icon_bg.draw_circle(circle_center + Vector2(0, 2), circle_radius, Color(0, 0, 0, 0.15))
		## Коло-фон
		_icon_bg.draw_circle(circle_center, circle_radius, bg_color)
		## Бордер
		_icon_bg.draw_arc(circle_center, circle_radius - 1.5, 0.0, TAU, 48, border_c, 3.0, true)
	)
	_icon_container.add_child(_icon_bg)

	## Іконка гри — сиблінг після _icon_bg (рендериться зверху)
	var icon_pos: float = (84.0 - ICON_DRAW_SIZE) / 2.0
	_icon_ctrl = IconDraw.game_icon(data.get("icon", "star"), ICON_DRAW_SIZE)
	_icon_ctrl.position = Vector2(icon_pos, icon_pos)
	_icon_ctrl.size = Vector2(ICON_DRAW_SIZE, ICON_DRAW_SIZE)
	_icon_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _is_unlocked:
		_icon_ctrl.modulate = Color(0.6, 0.6, 0.6, 0.8)
	_icon_container.add_child(_icon_ctrl)

	## Інфо — назва + бейдж статусу
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	var name_label: Label = Label.new()
	name_label.text = tr(data.get("name_key", ""))
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _is_unlocked:
		name_label.modulate.a = 0.8
	vbox.add_child(name_label)

	var badge: Label = Label.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _is_unlocked and _is_recommended:
		badge.text = tr("BADGE_PLAY")
		badge.add_theme_color_override("font_color", ThemeManager.COLOR_PRIMARY)
	elif _is_unlocked and not _is_recommended:
		badge.text = tr("BADGE_PLAY")
		badge.add_theme_color_override("font_color", ThemeManager.COLOR_BADGE_LOCKED)
	else:
		badge.text = tr("BADGE_COMING_SOON")
		badge.add_theme_color_override("font_color", ThemeManager.COLOR_SECONDARY)
	badge.add_theme_font_size_override("font_size", 20)
	vbox.add_child(badge)

	## Played indicator — зірочка для зіграних ігор (LAW 28 depth feedback)
	var gid: String = data.get("id", "")
	if _is_unlocked and gid != "" and ProgressManager.has_played_game(gid):
		var played_hbox: HBoxContainer = HBoxContainer.new()
		played_hbox.set("theme_override_constants/separation", 4)
		played_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var played_star: Control = IconDraw.star_5pt(14.0, Color("FFD166"))
		played_hbox.add_child(played_star)
		var played_label: Label = Label.new()
		played_label.text = tr("BADGE_PLAYED")
		played_label.add_theme_font_size_override("font_size", 16)
		played_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		played_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		played_hbox.add_child(played_label)
		vbox.add_child(played_hbox)

	## Non-recommended unlocked: трохи приглушений вигляд
	if _is_unlocked and not _is_recommended:
		modulate = Color(0.85, 0.85, 0.88, 1.0)

	## Shimmer для заблокованих (лише якщо анімації увімкнені)
	if not SettingsManager.reduced_motion:
		if not _is_unlocked:
			_setup_shimmer(panel)
			_setup_jiggle()
		else:
			_start_icon_float()
			if _is_recommended:
				_start_badge_pulse(badge)

	## Обробка натискання
	gui_input.connect(_on_gui_input)


func _make_card_style(bg_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(CARD_RADIUS)
	style.border_width_bottom = 2
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = bg_color.darkened(0.15)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	style.shadow_color = Color(bg_color.darkened(0.3), 0.20)
	style.anti_aliasing_size = 1.2
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _setup_shimmer(_parent: Control) -> void:
	var shimmer: ColorRect = ColorRect.new()
	shimmer.name = "ShimmerOverlay"
	shimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = load("res://assets/shaders/card_shimmer.gdshader")
	if shader:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		## Десинхронізація між картками — TIME-based, не потрібен tween
		mat.set_shader_parameter("time_offset", randf_range(0.0, SHIMMER_OFFSET_MAX))
		## Перламутрові кольори: warm gold → cool silver-blue
		mat.set_shader_parameter("warm_color", Color(1.0, 0.92, 0.75, 0.22))
		mat.set_shader_parameter("cool_color", Color(0.85, 0.92, 1.0, 0.18))
		mat.set_shader_parameter("edge_intensity", 0.12)
		shimmer.material = mat
		add_child(shimmer)
		_shimmer_overlay = shimmer


func _setup_jiggle() -> void:
	_jiggle_timer = Timer.new()
	_jiggle_timer.one_shot = true
	_jiggle_timer.wait_time = randf_range(JIGGLE_INTERVAL_MIN, JIGGLE_INTERVAL_MAX)
	_jiggle_timer.timeout.connect(_do_jiggle)
	add_child(_jiggle_timer)
	_jiggle_timer.start()


func _do_jiggle() -> void:
	if not _icon_container or not is_instance_valid(_icon_container):
		return
	_icon_container.pivot_offset = _icon_container.size / 2.0
	var tw: Tween = create_tween()
	tw.tween_property(_icon_container, "rotation", deg_to_rad(-3.0), 0.06)
	tw.tween_property(_icon_container, "rotation", deg_to_rad(3.0), 0.06)
	tw.tween_property(_icon_container, "rotation", deg_to_rad(-1.5), 0.04)
	tw.tween_property(_icon_container, "rotation", 0.0, 0.04)
	_jiggle_timer.wait_time = randf_range(JIGGLE_INTERVAL_MIN, JIGGLE_INTERVAL_MAX)
	_jiggle_timer.start()


func _start_icon_float() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_icon_bg) or not is_instance_valid(_icon_ctrl):
		return
	_icon_bg_base_y = _icon_bg.position.y
	_icon_ctrl_base_y = _icon_ctrl.position.y
	_float_tween = create_tween().set_loops()
	_float_tween.set_parallel(true)
	_float_tween.tween_property(_icon_bg, "position:y",
		_icon_bg_base_y - FLOAT_AMP, FLOAT_DUR / 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(_icon_ctrl, "position:y",
		_icon_ctrl_base_y - FLOAT_AMP, FLOAT_DUR / 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.chain().set_parallel(true)
	_float_tween.tween_property(_icon_bg, "position:y",
		_icon_bg_base_y + FLOAT_AMP, FLOAT_DUR / 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(_icon_ctrl, "position:y",
		_icon_ctrl_base_y + FLOAT_AMP, FLOAT_DUR / 2.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_badge_pulse(badge: Label) -> void:
	await get_tree().process_frame
	if not is_instance_valid(badge):
		return
	badge.pivot_offset = badge.size / 2.0
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(badge, "scale", Vector2(1.05, 1.05), 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(badge, "scale", Vector2.ONE, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_press()
	elif event is InputEventScreenTouch and event.pressed:
		_handle_press()


func _handle_press() -> void:
	if _press_locked:
		return
	_press_locked = true
	AudioManager.play_sfx("click")
	pivot_offset = size / 2.0
	if SettingsManager.reduced_motion:
		if _is_unlocked:
			pressed.emit(_game_data.get("id", ""))
		return
	var tw: Tween = create_tween()
	if _is_unlocked:
		## Premium squish + bounce
		tw.tween_property(self, "scale", Vector2(0.92, 0.92), 0.06)
		tw.tween_property(self, "scale", Vector2(1.03, 1.03), 0.1)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.08)
		## VFX — зірочки при натисканні
		var center: Vector2 = global_position + size / 2.0
		VFXManager.spawn_tap_stars(center)
		tw.finished.connect(func() -> void:
			pressed.emit(_game_data.get("id", "")))
	else:
		## Locked elastic bounce
		tw.tween_property(self, "scale", Vector2(1.06, 1.06), 0.08)
		tw.tween_property(self, "scale", Vector2.ONE, 0.15)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
