extends CanvasLayer

## Оверлей «Рівень пройдено!» — premium celebration з canvas-ефектами:
## Зоряний дощ, літаючі зірки до лічильника, screen flash, multi-wave конфетті,
## пульсуючий заголовок, каскадна поява елементів.

const BACKDROP_FADE: float = 0.3
const STAR_SPIN_DUR: float = 0.7
const COUNTER_DUR: float = 0.8
const GOLD: Color = Color("FFD166")
const STAR_FLY_COUNT: int = 5
const FLASH_COLOR: Color = Color(1.0, 0.95, 0.7, 0.35)

var _earned: int = 0
var _star_count_label: Label = null
var _star_count_box: HBoxContainer = null
var _continue_pressed: bool = false


func _ready() -> void:
	layer = 50
	## Viewport-relative panel — не кліпається на маленьких екранах
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var panel: PanelContainer = $CenterPanel
	var half_w: float = minf(160.0, vp.x * 0.42)
	var half_h: float = minf(200.0, vp.y * 0.42)
	panel.offset_left = -half_w
	panel.offset_right = half_w
	panel.offset_top = -half_h
	panel.offset_bottom = half_h
	$CenterPanel/VBox/TitleLabel.text = tr("TITLE_LEVEL_COMPLETE")
	## Код-малювана зірка замість PNG
	var big_star_icon: Control = IconDraw.star_5pt(80.0)
	big_star_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CenterPanel/VBox/BigStar.add_child(big_star_icon)
	var count_star_icon: Control = IconDraw.star_5pt(32.0)
	count_star_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CenterPanel/VBox/StarCountBox/StarCountIcon.add_child(count_star_icon)
	var cont_btn: Button = $CenterPanel/VBox/ContinueButton
	cont_btn.theme_type_variation = &"AccentButton"
	cont_btn.custom_minimum_size = Vector2(280, 72)
	IconDraw.icon_text_in_button(cont_btn,
		IconDraw.arrow_right(22.0), tr("BTN_CONTINUE"), 24, 8)
	## Premium candy panel — consistent з design system
	var style: StyleBoxFlat = GameData.candy_panel(
		Color(Color("FDFBF7"), 0.95), 28)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	style.border_color = Color(GOLD, 0.4)
	style.set_border_width_all(2)
	style.set_content_margin_all(36)
	$CenterPanel.add_theme_stylebox_override("panel", style)
	## Grain overlay на celebration panel (LAW 28)
	$CenterPanel.material = GameData.create_premium_material(0.02, 2.0, 0.04, 0.10, 0.04, 0.05, 0.12, "", 0.0, 0.08, 0.18, 0.15)
	## Зберегти посилання ДО reparent ($ шляхи зміняться)
	_star_count_label = $CenterPanel/VBox/StarCountBox/StarCountLabel
	_star_count_box = $CenterPanel/VBox/StarCountBox
	## Star count pill — gold-tinted
	var pill_wrap: PanelContainer = PanelContainer.new()
	pill_wrap.add_theme_stylebox_override("panel", GameData.star_pill())
	_star_count_box.get_parent().add_child(pill_wrap)
	_star_count_box.get_parent().move_child(pill_wrap, _star_count_box.get_index())
	_star_count_box.reparent(pill_wrap)
	## Juicy button squish
	JuicyEffects.button_press_squish(cont_btn, self)


func show_results(earned_stars: int) -> void:
	_earned = earned_stars
	_fade_backdrop()
	_animate_title_entrance()
	_animate_counter()
	_enable_continue_delayed()
	if _earned > 0 and not SettingsManager.reduced_motion:
		_screen_flash()
		_spawn_celebration_particles()
		_animate_star()
		_spawn_flying_stars()
		## Victory zoom pulse на центральну панель (0.6с delay для staging)
		var center_panel: Control = $CenterPanel
		if is_instance_valid(center_panel):
			center_panel.pivot_offset = center_panel.size / 2.0
			get_tree().create_timer(0.6).timeout.connect(func() -> void:
				if is_instance_valid(center_panel):
					JuicyEffects.victory_zoom_pulse(center_panel, self))


## Швидкий золотий спалах екрану — "wow" ефект при відкритті.
func _screen_flash() -> void:
	var flash: ColorRect = ColorRect.new()
	flash.color = FLASH_COLOR
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 100
	add_child(flash)
	var tw: Tween = create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(flash.queue_free)


func _fade_backdrop() -> void:
	var backdrop: ColorRect = $Backdrop
	backdrop.modulate.a = 0.0
	if SettingsManager.reduced_motion:
		backdrop.modulate.a = 1.0
		return
	create_tween().tween_property(backdrop, "modulate:a", 1.0, BACKDROP_FADE)


## Багатофазне святкування — веселкове кільце + фонтан + іскри.
func _spawn_celebration_particles() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Фаза 1 — веселкове кільце + золотий вибух по центру
	VFXManager.spawn_rainbow_ring(vp / 2.0)
	VFXManager.spawn_golden_burst(vp / 2.0)
	## Фаза 2 — фонтан феєрверків знизу (0.4с)
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		VFXManager.spawn_firework_fountain(Vector2(vp.x * 0.5, vp.y * 0.85))
	)
	## Фаза 3 — іскристі спалахи у випадкових позиціях (0.9с)
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		for j: int in 3:
			var rand_pos: Vector2 = Vector2(
				randf_range(vp.x * 0.2, vp.x * 0.8),
				randf_range(vp.y * 0.2, vp.y * 0.5))
			VFXManager.spawn_sparkle_pop(rand_pos)
	)


func _animate_star() -> void:
	var star: Control = $CenterPanel/VBox/BigStar
	star.pivot_offset = star.size / 2.0
	star.scale = Vector2.ZERO
	star.rotation = 0.0
	star.modulate = Color(GOLD, 1.0)
	var tw: Tween = create_tween().set_parallel(true)
	## Масштаб із ефектом "вибуху"
	tw.tween_property(star, "scale", Vector2(1.5, 1.5), STAR_SPIN_DUR * 0.6)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(star, "rotation", TAU, STAR_SPIN_DUR)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	## Стиснення до нормального розміру
	tw.chain().tween_property(star, "scale", Vector2(0.9, 0.9), 0.1)
	tw.chain().tween_property(star, "scale", Vector2(1.1, 1.1), 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(star, "scale", Vector2.ONE, 0.1)
	## Дихальна пульсація
	tw.chain().tween_callback(func() -> void:
		var pulse: Tween = create_tween().set_loops()
		pulse.tween_property(star, "scale", Vector2(1.08, 1.08), 1.0)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(star, "scale", Vector2.ONE, 1.0)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)


## Заголовок — cascade entrance з кольоровим переливом.
func _animate_title_entrance() -> void:
	var title: Label = $CenterPanel/VBox/TitleLabel
	title.pivot_offset = title.size / 2.0
	if SettingsManager.reduced_motion:
		title.scale = Vector2.ONE
		title.modulate.a = 1.0
		return
	title.scale = Vector2(0.5, 0.5)
	title.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(title, "scale", Vector2(1.1, 1.1), 0.5)\
		.set_delay(0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(title, "modulate:a", 1.0, 0.3).set_delay(0.3)
	tw.chain().tween_property(title, "scale", Vector2.ONE, 0.15)
	## Ніжна пульсація заголовку
	tw.chain().tween_callback(func() -> void:
		var pulse: Tween = create_tween().set_loops()
		pulse.tween_property(title, "scale", Vector2(1.03, 1.03), 1.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(title, "scale", Vector2.ONE, 1.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)


func _animate_counter() -> void:
	var label: Label = _star_count_label
	label.pivot_offset = label.size / 2.0
	var count_box: HBoxContainer = _star_count_box
	count_box.pivot_offset = count_box.size / 2.0
	if SettingsManager.reduced_motion:
		label.modulate.a = 1.0
		count_box.scale = Vector2.ONE
		label.text = "+%d" % _earned
		AudioManager.play_sfx("coin")
		return
	label.modulate.a = 0.0
	count_box.scale = Vector2.ZERO
	## Pop-in лічильника
	var pop_tw: Tween = create_tween()
	pop_tw.tween_interval(0.6)
	pop_tw.tween_property(count_box, "scale", Vector2(1.2, 1.2), 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(count_box, "scale", Vector2.ONE, 0.1)
	if _earned <= 0:
		label.text = "+0"
		label.modulate.a = 1.0
		return
	label.modulate.a = 1.0
	## Лічення з bounce на кожне число
	var count_cb: Callable = func(val: float) -> void:
		var current: int = int(val)
		if is_instance_valid(label):
			label.text = "+%d" % current
	var tw: Tween = create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(AudioManager.play_sfx.bind("coin"))
	tw.tween_method(count_cb, 0.0, float(_earned), COUNTER_DUR)
	## Bounce при фінальному числі
	tw.tween_property(label, "scale", Vector2(1.3, 1.3), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector2.ONE, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Літаючі зірочки — летять з центру до лічильника зірок (top bar).
func _spawn_flying_stars() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = vp / 2.0
	## Ціль — верхній правий кут (де лічильник зірок)
	var target: Vector2 = Vector2(vp.x * 0.85, 30.0)
	for i: int in mini(STAR_FLY_COUNT, _earned):
		var star: Control = IconDraw.star_5pt(24.0)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.modulate = GOLD
		star.modulate.a = 0.0
		star.position = center + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		star.pivot_offset = Vector2(12, 12)
		star.z_index = 90
		add_child(star)
		var delay: float = 1.2 + float(i) * 0.15
		var tw: Tween = create_tween().set_parallel(true)
		## Fade in
		tw.tween_property(star, "modulate:a", 1.0, 0.15).set_delay(delay)
		## Політ до лічильника (arc через control point)
		var mid: Vector2 = Vector2(
			lerpf(center.x, target.x, 0.5) + randf_range(-80, 80),
			minf(center.y, target.y) - randf_range(40, 120))
		var fly_dur: float = 0.5
		var bezier_fly: Callable = func(t: float) -> void:
			if is_instance_valid(star):
				var p1: Vector2 = center.lerp(mid, t)
				var p2: Vector2 = mid.lerp(target, t)
				star.position = p1.lerp(p2, t)
		tw.tween_method(bezier_fly, 0.0, 1.0, fly_dur)\
			.set_delay(delay + 0.15)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		## Обертання під час польоту
		tw.tween_property(star, "rotation", TAU * 2.0, fly_dur)\
			.set_delay(delay + 0.15)
		## Зменшення при наближенні до цілі
		tw.tween_property(star, "scale", Vector2(0.3, 0.3), fly_dur * 0.3)\
			.set_delay(delay + 0.15 + fly_dur * 0.7)
		## Самознищення
		tw.chain().tween_callback(star.queue_free)


func _enable_continue_delayed() -> void:
	var btn: Button = $CenterPanel/VBox/ContinueButton
	btn.disabled = true
	btn.pivot_offset = btn.size / 2.0
	if SettingsManager.reduced_motion:
		btn.modulate.a = 1.0
		btn.scale = Vector2.ONE
		## Коротка затримка для UX, потім увімкнути кнопку
		var tw_rm: Tween = create_tween()
		tw_rm.tween_interval(0.5)
		tw_rm.tween_callback(func() -> void: btn.disabled = false)
		return
	btn.modulate.a = 0.0
	btn.scale = Vector2(0.8, 0.8)
	var tw: Tween = create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(btn, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.1)
	tw.tween_callback(func() -> void: btn.disabled = false)
	## Пульсація кнопки після появи
	tw.tween_callback(func() -> void:
		var pulse: Tween = create_tween().set_loops()
		pulse.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.8)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(btn, "scale", Vector2.ONE, 0.8)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)


func _on_continue_pressed() -> void:
	if _continue_pressed:
		return
	_continue_pressed = true
	$CenterPanel/VBox/ContinueButton.disabled = true
	AudioManager.play_sfx("click")
	## Pop-out перед переходом
	var popper: UIPopper = $CenterPanel/UIPopper
	if is_instance_valid(popper):
		popper.pop_out(func() -> void:
			SceneManager.goto_scene("res://scenes/ui/game_hub.tscn"))
	else:
		SceneManager.goto_scene("res://scenes/ui/game_hub.tscn")
