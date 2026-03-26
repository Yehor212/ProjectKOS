extends BaseMiniGame

## Forest Orchestra — музичний оркестр! Toddler: пісочниця. Preschool: Simon Says.

const MUSICIAN_SCENE: PackedScene = preload("res://scenes/components/musician.tscn")
const MUSICIANS_DATA: Array[Dictionary] = [
	{"animal": "Bear", "color": Color("ef4444"), "sfx": "click", "pitch": 0.5, "icon": "drum"},
	{"animal": "Cat", "color": Color("3b82f6"), "sfx": "success", "pitch": 1.3, "icon": "guitar"},
	{"animal": "Elephant", "color": Color("eab308"), "sfx": "coin", "pitch": 0.7, "icon": "trumpet"},
	{"animal": "Chicken", "color": Color("22c55e"), "sfx": "success", "pitch": 1.8, "icon": "microphone"},
]
## Simon Says params (preschool)
const SEQUENCE_START: int = 2
const SEQUENCE_MAX: int = 6
const SHOW_INTERVAL: float = 0.7
const SHOW_DURATION: float = 0.5
const MAX_ERRORS: int = 3
const MAX_LEVELS: int = 5

const IDLE_HINT_DELAY: float = 6.0
const TODDLER_AUTO_FINISH_SEC: float = 45.0
const SAFETY_TIMEOUT_SEC: float = 120.0

var _is_toddler: bool = false
var _musicians: Array[Node2D] = []
## Preschool (Simon Says)
var _sequence: Array[int] = []
var _player_index: int = 0
var _is_showing: bool = false
var _current_level: int = 0
var _score: int = 0
## UI
var _level_label: Label = null
var _idle_timer: SceneTreeTimer = null
var _start_time: float = 0.0
var _progress_dots: Array[Panel] = []
var _progress_container: HBoxContainer = null


func _ready() -> void:
	game_id = "music"
	bg_theme = "meadow"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_apply_background()
	_start_time = Time.get_ticks_msec() / 1000.0
	_build_hud()
	_place_musicians()
	_reset_idle_timer()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)
	if _is_toddler:
		## A2: гра ЗАВЖДИ завершується — авто-фініш через таймер
		get_tree().create_timer(TODDLER_AUTO_FINISH_SEC).timeout.connect(
			func() -> void:
				if not _game_over:
					_on_toddler_done())
	else:
		_start_simon_says()


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())
	if _is_toddler:
		## Кнопка «Далі» для toddler
		var s: float = _ui_scale()
		var done_btn: Button = Button.new()
		done_btn.theme_type_variation = &"SecondaryButton"
		IconDraw.icon_in_button(done_btn, IconDraw.checkmark(24.0 * s))
		done_btn.custom_minimum_size = Vector2(120.0 * s, 56.0 * s)
		done_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		done_btn.offset_left = -140.0 * s
		done_btn.offset_right = -16.0 * s
		done_btn.offset_top = -72.0 * s
		done_btn.pressed.connect(_on_toddler_done)
		_ui_layer.add_child(done_btn)
		JuicyEffects.button_press_squish(done_btn, self)
	else:
		## Preschool: score label
		_level_label = Label.new()
		_level_label.text = "0"
		_level_label.add_theme_font_size_override("font_size", 36)
		_level_label.add_theme_color_override("font_color", Color.WHITE)
		_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_level_label.offset_left = -160.0
		_level_label.offset_right = -16.0
		_level_label.offset_top = 8.0
		_ui_layer.add_child(_level_label)


func _place_musicians() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var spacing: float = vp.x / (MUSICIANS_DATA.size() + 1)
	for i: int in range(MUSICIANS_DATA.size()):
		var data: Dictionary = MUSICIANS_DATA[i]
		var musician: Node2D = MUSICIAN_SCENE.instantiate()
		add_child(musician)
		var target_y: float = vp.y * 0.5
		musician.setup(i, data.animal, data.color,
			data.sfx, data.pitch, data.icon)
		musician.played.connect(_on_musician_played)
		_musicians.append(musician)
		## Вхідна анімація — стрибок зверху
		if SettingsManager.reduced_motion:
			musician.position = Vector2(spacing * (i + 1), target_y)
		else:
			musician.position = Vector2(spacing * (i + 1), -100.0)
			var tw: Tween = create_tween()
			tw.tween_property(musician, "position:y", target_y, 0.4 + i * 0.1)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_musician_played(musician: Node2D) -> void:
	if _game_over or _input_locked:
		return
	_reset_idle_timer()
	if _is_toddler:
		return
	if _is_showing:
		return
	## Preschool: Simon Says перевірка
	if _sequence.is_empty():
		return
	if _player_index >= _sequence.size():
		return
	var expected: int = _sequence[_player_index]
	if musician.musician_id == expected:
		var m_color: Color = MUSICIANS_DATA[musician.musician_id].color if musician.musician_id < MUSICIANS_DATA.size() else Color(0.5, 0.8, 1.0)
		VFXManager.spawn_note_particles(musician.global_position, m_color)
		_fill_dot(_player_index, Color("06d6a0"))
		_player_index += 1
		if _player_index >= _sequence.size():
			## Правильно! Наступний рівень
			_register_correct(musician)
			_score += _sequence.size()
			if _level_label:
				_level_label.text = "%d" % _score
			VFXManager.spawn_premium_celebration(
				get_viewport().get_visible_rect().size / 2.0)
			_next_level()
	else:
		## Помилка
		_errors += 1
		_register_error(musician)
		if _errors >= MAX_ERRORS:
			_game_over = true
			_finish()
		else:
			## Повторити послідовність
			_show_sequence()


## ---- Simon Says flow ----

func _start_simon_says() -> void:
	_current_level = 0
	_sequence.clear()
	_next_level()


func _next_level() -> void:
	_current_level += 1
	_input_locked = true
	if _current_level > MAX_LEVELS:
		_game_over = true
		_finish()
		return
	_is_showing = true
	var seq_len: int = mini(SEQUENCE_START + _current_level - 1, SEQUENCE_MAX)
	_sequence.clear()
	for i: int in range(seq_len):
		_sequence.append(randi() % _musicians.size())
	_build_progress_dots(seq_len)
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self) or _game_over:
		return
	_show_sequence()


func _show_sequence() -> void:
	_is_showing = true
	_player_index = 0
	if _instruction_label:
		_fade_instruction(_instruction_label, tr("MUSIC_WATCH"))
	for i: int in range(_sequence.size()):
		await get_tree().create_timer(SHOW_INTERVAL).timeout
		if not is_instance_valid(self) or _game_over:
			return
		_musicians[_sequence[i]].highlight(SHOW_DURATION)
		_fill_dot(i, MUSICIANS_DATA[_sequence[i]].color)
	await get_tree().create_timer(SHOW_DURATION + 0.2).timeout
	if not is_instance_valid(self) or _game_over:
		return
	## Скидаємо точки перед ходом гравця
	for j: int in _progress_dots.size():
		_fill_dot(j, Color(1, 1, 1, 0.25))
	_is_showing = false
	_input_locked = false
	if _instruction_label:
		_fade_instruction(_instruction_label, tr("MUSIC_YOUR_TURN"))


## ---- Finish ----

func _on_toddler_done() -> void:
	if _game_over:
		return
	_game_over = true
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	finish_game(5, {"time_sec": elapsed, "errors": 0, "rounds_played": 1,
		"earned_stars": 5})


func _finish() -> void:
	_input_locked = true
	var is_win: bool = _errors < MAX_ERRORS
	if is_win:
		AudioManager.play_sfx("success")
		HapticsManager.vibrate_success()
		VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	var stats: Dictionary = {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": _current_level,
		"earned_stars": earned,
	}
	finish_game(earned, stats)


## ---- Прогрес-індикатор послідовності ----

func _build_progress_dots(count: int) -> void:
	if _progress_container and is_instance_valid(_progress_container):
		_progress_container.queue_free()
	_progress_dots.clear()
	_progress_container = HBoxContainer.new()
	_progress_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_progress_container.set("theme_override_constants/separation", 8)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_progress_container.position = Vector2(vp.x * 0.5 - float(count) * 14.0, vp.y * 0.20)  ## Нижче HUD zone (research: top 15% = HUD)
	_progress_container.size = Vector2(float(count) * 28.0, 20)
	add_child(_progress_container)
	for _i: int in count:
		var dot: Panel = Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.add_theme_stylebox_override("panel", GameData.candy_circle(Color(1, 1, 1, 0.25), 8.0, false))
		## Grain overlay (LAW 28)
		dot.material = GameData.create_premium_material(0.03, 2.0, 0.0, 0.0, 0.0, 0.04, 0.10, "", 0.0, 0.10, 0.22, 0.18)
		_progress_container.add_child(dot)
		_progress_dots.append(dot)


func _fill_dot(idx: int, color: Color) -> void:
	if idx < 0 or idx >= _progress_dots.size():
		return
	var dot: Panel = _progress_dots[idx]
	if not is_instance_valid(dot):
		return
	dot.add_theme_stylebox_override("panel", GameData.candy_circle(color, 8.0, false))


## ---- Idle hint ----

func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _game_over or _is_showing or _musicians.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	## Пульсація випадкового музиканта
	var idx: int = randi() % _musicians.size()
	var m: Node2D = _musicians[idx]
	if is_instance_valid(m):
		_pulse_node(m, 1.15)
	_reset_idle_timer()


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("MUSIC_TUTORIAL_TODDLER")
	return tr("MUSIC_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _musicians.is_empty():
		return {}
	return {"type": "tap", "target": _musicians[0].global_position}
