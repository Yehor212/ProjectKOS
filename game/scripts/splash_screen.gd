extends Control

## Анімований сплеш-скрін — плаваючий заголовок, маскот на доріжці,
## зірки з конфеті, декорації по кутах, перехід до головного меню.

const LOAD_DURATION: float = 3.5
const TITLE_FLOAT_AMP: float = 15.0
const TITLE_FLOAT_SPEED: float = 2.1
const TITLE_ROT_AMP: float = 2.0
const DECO_FLOAT_AMP: float = 30.0
const DECO_ROT_AMP: float = 20.0
const FINISH_DELAY: float = 0.5
const DECO_SPEEDS: Array[float] = [6.0, 7.0, 8.0, 5.5]

var _title: Label = null
var _title_base_y: float = 0.0
var _track: SplashTrack = null
var _decos: Array[SplashDeco] = []
var _deco_base_y: Array[float] = []
var _done: bool = false


func _ready() -> void:
	## Фон — sky текстура замість одноколірного
	var bg: TextureRect = $Background as TextureRect
	if bg:
		var sky_path: String = "res://assets/backgrounds/themes/bg_sky.png"
		if ResourceLoader.exists(sky_path):
			bg.texture = load(sky_path)
	## Grain overlay на весь UI (LAW 28 — premium texture)
	material = GameData.create_premium_material(0.02, 2.0, 0.0, 0.0, 0.03, 0.04, 0.10, "", 0.0, 0.08, 0.18, 0.15)
	_apply_safe_area()
	# Заголовок
	_title = $TitleLabel
	_title.pivot_offset = _title.size / 2.0
	_title_base_y = _title.position.y
	_title.scale = Vector2.ZERO
	_title.rotation_degrees = -15.0
	_title.modulate.a = 0.0

	# Субтитр
	$SubtitleLabel.text = tr("SPLASH_SUBTITLE")
	$SubtitleLabel.modulate.a = 0.0

	# Декорації
	_decos = [$DecoTL, $DecoTR, $DecoBL, $DecoBR]
	for d: SplashDeco in _decos:
		_deco_base_y.append(d.position.y)

	# Доріжка прогресу
	_track = $SplashTrack

	# Назва студії — slide up + fade in
	$StudioFromLabel.modulate.a = 0.0
	$StudioFromLabel.position.y += 20.0
	$StudioNameLabel.modulate.a = 0.0
	$StudioNameLabel.position.y += 20.0

	# Анімація появи
	_animate_title_in()
	create_tween().tween_property($SubtitleLabel, "modulate:a", 1.0, 0.6).set_delay(0.5)
	var studio_tw: Tween = create_tween().set_parallel(true)
	studio_tw.tween_property($StudioFromLabel, "modulate:a", 1.0, 0.5).set_delay(0.8)
	studio_tw.tween_property($StudioFromLabel, "position:y",
		$StudioFromLabel.position.y - 20.0, 0.5)\
		.set_delay(0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	studio_tw.tween_property($StudioNameLabel, "modulate:a", 1.0, 0.5).set_delay(1.0)
	studio_tw.tween_property($StudioNameLabel, "position:y",
		$StudioNameLabel.position.y - 20.0, 0.5)\
		.set_delay(1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_start_loading()


func _process(_delta: float) -> void:
	if SettingsManager.reduced_motion:
		return
	var time: float = Time.get_ticks_msec() / 1000.0

	# Плавання заголовку
	if _title:
		_title.position.y = _title_base_y + sin(time * TITLE_FLOAT_SPEED) * TITLE_FLOAT_AMP
		_title.rotation_degrees = sin(time * TITLE_FLOAT_SPEED * 0.7) * TITLE_ROT_AMP

	# Плавання декорацій
	for i: int in _decos.size():
		var spd: float = TAU / DECO_SPEEDS[i]
		var dir: float = -1.0 if i % 2 == 1 else 1.0
		_decos[i].position.y = _deco_base_y[i] + sin(time * spd) * DECO_FLOAT_AMP
		_decos[i].rotation_degrees = sin(time * spd * 0.8) * DECO_ROT_AMP * dir


func _animate_title_in() -> void:
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_title, "scale", Vector2(1.2, 1.2), 0.6)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "rotation_degrees", 0.0, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "modulate:a", 1.0, 0.3)
	tw.chain().tween_property(_title, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _start_loading() -> void:
	var tw: Tween = create_tween()
	tw.tween_method(_on_progress_step, 0.0, 1.0, LOAD_DURATION)
	tw.finished.connect(_on_loading_done)


func _on_progress_step(value: float) -> void:
	_track.set_progress(value)


func _on_loading_done() -> void:
	set_process(false)
	_track.set_done()
	_done = true
	## Показати "Tap to play!" з пульсацією
	var tap_label: Label = Label.new()
	tap_label.text = tr("SPLASH_TAP")
	tap_label.add_theme_font_size_override("font_size", 24)
	tap_label.add_theme_color_override("font_color", Color(0.51, 0.22, 0.93, 0.8))
	tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tap_label.offset_top = -80.0
	tap_label.offset_bottom = -40.0
	tap_label.modulate.a = 0.0
	add_child(tap_label)
	## Fade in + пульсація
	var tw: Tween = create_tween()
	tw.tween_property(tap_label, "modulate:a", 1.0, 0.3)
	tw.chain()
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(tap_label, "modulate:a", 0.4, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(tap_label, "modulate:a", 1.0, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	## Чекаємо на tap/click від користувача (без авто-переходу)
	## _unhandled_input() обробляє touch/click → _navigate_next()


func _input(event: InputEvent) -> void:
	if not _done:
		return
	if event is InputEventMouseButton and event.pressed:
		_navigate_next()
	elif event is InputEventScreenTouch and event.pressed:
		_navigate_next()
	elif event is InputEventKey and event.pressed:
		_navigate_next()


func _apply_safe_area() -> void:
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	var full: Vector2i = DisplayServer.screen_get_size()
	if sa.size.x == 0 or full.x == 0:
		return
	var top: float = float(sa.position.y)
	var bottom: float = float(full.y - sa.end.y)
	if top > 0.0 and is_instance_valid($TitleLabel):
		$TitleLabel.offset_top += top
	if bottom > 0.0 and is_instance_valid($SplashTrack):
		$SplashTrack.offset_bottom -= bottom


func _navigate_next() -> void:
	if not _done:
		return
	_done = false
	if SettingsManager.is_age_set():
		SceneManager.goto_scene("res://scenes/ui/main_menu.tscn")
	else:
		SceneManager.goto_scene("res://scenes/ui/age_selection.tscn")
