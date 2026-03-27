extends BaseMiniGame

## Forest Concert — лісовий концерт з СПРАВЖНІМИ нотами!
## Toddler: вільна гра (sandbox) — тап музикантів створює ноти, кожні 4 тапи авто-replay.
## Preschool: Simon Says з мелодіями — ноти C, E, G, A утворюють впізнавані мотиви.
## Кожен музикант = одна нота ксилофону (pitch-shifted "pop" SFX).

const MUSICIAN_SCENE: PackedScene = preload("res://scenes/components/musician.tscn")

## 4 музиканти з НАСТОЯЩИМИ нотами (ксилофон C-E-G-A)
const MUSICIANS_DATA: Array[Dictionary] = [
	{"animal": "Bear", "color": Color("ef4444"), "note": "C", "pitch": 1.0, "icon": "drum"},
	{"animal": "Cat", "color": Color("3b82f6"), "note": "E", "pitch": 1.26, "icon": "guitar"},
	{"animal": "Elephant", "color": Color("eab308"), "note": "G", "pitch": 1.5, "icon": "trumpet"},
	{"animal": "Chicken", "color": Color("22c55e"), "note": "A", "pitch": 1.68, "icon": "microphone"},
]

## Мелодичні послідовності для Preschool (не випадкові! — впізнавані мотиви)
## Індекси: 0=C, 1=E, 2=G, 3=A
const MELODIES: Array[Array] = [
	[0, 0, 2, 2],            ## Рівень 1: C-C-G-G (Twinkle Twinkle мотив)
	[0, 1, 2, 1, 0],         ## Рівень 2: C-E-G-E-C (арпеджіо вгору-вниз)
	[2, 1, 0, 1, 2, 2],      ## Рівень 3: G-E-C-E-G-G (Mary Had a Little Lamb мотив)
	[0, 0, 2, 2, 3, 3, 2],   ## Рівень 4: C-C-G-G-A-A-G (Twinkle повний)
	[3, 2, 1, 0, 1, 2, 3, 3],## Рівень 5: A-G-E-C-E-G-A-A (низхідний + висхідний)
]

## Simon Says параметри (preschool)
const SHOW_INTERVAL: float = 0.55
const SHOW_DURATION: float = 0.4
const MAX_LEVELS: int = 5

## Toddler параметри
const TODDLER_TAP_GOAL: int = 12
const TODDLER_REPLAY_EVERY: int = 4
const TODDLER_AUTO_FINISH_SEC: float = 60.0

const IDLE_HINT_DELAY: float = 6.0
const SAFETY_TIMEOUT_SEC: float = 120.0

var _is_toddler: bool = false
var _musicians: Array[Node2D] = []

## Preschool (Simon Says)
var _sequence: Array[int] = []
var _player_index: int = 0
var _is_showing: bool = false
var _current_level: int = 0

## Toddler (sandbox)
var _toddler_taps: int = 0
var _toddler_history: Array[int] = []

## UI
var _idle_timer: SceneTreeTimer = null
var _start_time: float = 0.0
var _progress_dots: Array[Panel] = []
var _progress_container: HBoxContainer = null
var _note_label: Label = null


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
	var s: float = _ui_scale()
	if _is_toddler:
		## Кнопка "Далі" для toddler
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
	## Мітка ноти — показує яку ноту зараз граємо (навчальна цінність)
	_note_label = Label.new()
	_note_label.text = ""
	_note_label.add_theme_font_size_override("font_size", int(32.0 * s))
	_note_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_note_label.offset_top = -80.0 * s
	_note_label.offset_bottom = -40.0 * s
	_ui_layer.add_child(_note_label)


func _place_musicians() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = MUSICIANS_DATA.size()
	if count == 0:
		push_warning("ForestOrchestra: MUSICIANS_DATA порожній")
		return
	var spacing: float = vp.x / float(count + 1)
	for i: int in range(count):
		var data: Dictionary = MUSICIANS_DATA[i]
		var musician: Node2D = MUSICIAN_SCENE.instantiate()
		add_child(musician)
		var target_y: float = vp.y * 0.5
		musician.setup(i, data.get("animal", "Bear"), data.get("color", Color.WHITE),
			"pop", data.get("pitch", 1.0), data.get("icon", "drum"))
		musician.played.connect(_on_musician_played)
		_musicians.append(musician)
		## Вхідна анімація — стрибок зверху
		if SettingsManager.reduced_motion:
			musician.position = Vector2(spacing * float(i + 1), target_y)
		else:
			musician.position = Vector2(spacing * float(i + 1), -100.0)
			var tw: Tween = _create_game_tween()
			tw.tween_property(musician, "position:y", target_y, 0.4 + float(i) * 0.1)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_musician_played(musician: Node2D) -> void:
	if _game_over or _input_locked:
		return
	_reset_idle_timer()
	## Показати назву ноти
	var m_id: int = musician.musician_id
	if m_id >= 0 and m_id < MUSICIANS_DATA.size():
		var note_name: String = MUSICIANS_DATA[m_id].get("note", "")
		_flash_note_label(note_name, MUSICIANS_DATA[m_id].get("color", Color.WHITE))
	if _is_toddler:
		_handle_toddler_tap(musician)
		return
	if _is_showing:
		return
	## Preschool: Simon Says перевірка
	_handle_preschool_tap(musician)


## -- Toddler: вільна гра (sandbox) --

func _handle_toddler_tap(musician: Node2D) -> void:
	_toddler_taps += 1
	_toddler_history.append(musician.musician_id)
	## Візуальний фідбек при кожному тапі
	var tap_color: Color = Color.WHITE
	if musician.musician_id >= 0 and musician.musician_id < MUSICIANS_DATA.size():
		tap_color = MUSICIANS_DATA[musician.musician_id].get("color", Color.WHITE)
	VFXManager.spawn_success_ripple(musician.global_position, tap_color)
	## Досягнуто мету — концерт! (перевіряємо ПЕРЕД replay щоб уникнути race condition)
	if _toddler_taps >= TODDLER_TAP_GOAL:
		_play_concert_finale()
		return
	## Кожні TODDLER_REPLAY_EVERY тапів — авто-replay того що дитина зіграла
	if _toddler_taps > 0 and _toddler_taps % TODDLER_REPLAY_EVERY == 0:
		_replay_toddler_melody()


func _replay_toddler_melody() -> void:
	if _toddler_history.size() < TODDLER_REPLAY_EVERY:
		push_warning("ForestOrchestra: недостатньо тапів для replay")
		return
	_input_locked = true
	if _instruction_label:
		_fade_instruction(_instruction_label, tr("MUSIC_LISTEN_BACK"))
	## Відтворити останні TODDLER_REPLAY_EVERY нот
	var start_idx: int = maxi(_toddler_history.size() - TODDLER_REPLAY_EVERY, 0)
	var replay_seq: Array[int] = []
	for i: int in range(start_idx, _toddler_history.size()):
		if i >= 0 and i < _toddler_history.size():
			replay_seq.append(_toddler_history[i])
	_play_sequence_animated(replay_seq, func() -> void:
		if not is_instance_valid(self) or _game_over:
			return
		_input_locked = false
		if _instruction_label:
			_fade_instruction(_instruction_label, tr("MUSIC_TUTORIAL_TODDLER")))


func _play_concert_finale() -> void:
	if _game_over:
		return
	_game_over = true
	_input_locked = true
	if _instruction_label:
		_fade_instruction(_instruction_label, tr("MUSIC_CONCERT"))
	## Фінальний концерт — всі музиканти грають послідовно
	var concert_seq: Array[int] = [0, 1, 2, 3, 2, 1, 0, 2]
	_play_sequence_animated(concert_seq, func() -> void:
		if not is_instance_valid(self):
			return
		_play_success_sequence()
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
		finish_game(5, {"time_sec": elapsed, "errors": 0,
			"rounds_played": 1, "earned_stars": 5}))


func _on_toddler_done() -> void:
	if _game_over:
		return
	_play_concert_finale()


## -- Preschool: Simon Says з мелодіями --

func _handle_preschool_tap(musician: Node2D) -> void:
	if _sequence.is_empty():
		push_warning("ForestOrchestra: _sequence порожня під час preschool tap")
		return
	if _player_index >= _sequence.size():
		push_warning("ForestOrchestra: _player_index за межами _sequence")
		return
	var expected: int = _sequence[_player_index]
	if musician.musician_id == expected:
		## Правильна нота!
		var m_color: Color = Color(0.5, 0.8, 1.0)
		if musician.musician_id >= 0 and musician.musician_id < MUSICIANS_DATA.size():
			m_color = MUSICIANS_DATA[musician.musician_id].get("color", m_color)
		VFXManager.spawn_note_particles(musician.global_position, m_color)
		_fill_dot(_player_index, Color("06d6a0"))
		_player_index += 1
		if _player_index >= _sequence.size():
			## Вся послідовність правильна! Наступний рівень
			_register_correct(musician)
			_play_round_celebration(musician.global_position)
			_update_round_label(tr("MUSIC_LEVEL") + " %d/%d" % [
				mini(_current_level + 1, MAX_LEVELS), MAX_LEVELS])
			_next_level()
	else:
		## Помилка — неправильна нота
		_errors += 1
		_register_error(musician)
		## Повторити послідовність
		_player_index = 0
		_show_sequence()


func _start_simon_says() -> void:
	_current_level = 0
	_sequence.clear()
	_errors = 0
	_update_round_label(tr("MUSIC_LEVEL") + " 1/%d" % MAX_LEVELS)
	_next_level()


func _next_level() -> void:
	_input_locked = true
	if _current_level >= MAX_LEVELS:
		## Всі рівні пройдені — концерт!
		_game_over = true
		_play_preschool_finale()
		return
	_is_showing = true
	## Побудувати послідовність з MELODIES (LAW 6: прогресивна складність)
	_sequence.clear()
	if _current_level >= 0 and _current_level < MELODIES.size():
		var melody: Array = MELODIES[_current_level]
		for note_idx: Variant in melody:
			var idx: int = int(note_idx)
			if idx >= 0 and idx < _musicians.size():
				_sequence.append(idx)
	## Fallback: якщо мелодія порожня — випадкова послідовність
	if _sequence.is_empty():
		push_warning("ForestOrchestra: мелодія для рівня %d порожня, fallback" % _current_level)
		var seq_len: int = _scale_by_round_i(2, 6, _current_level, MAX_LEVELS)
		for _i: int in range(seq_len):
			if _musicians.size() > 0:
				_sequence.append(randi() % _musicians.size())
	_build_progress_dots(_sequence.size())
	_current_level += 1
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self) or _game_over:
		return
	_show_sequence()


func _show_sequence() -> void:
	_is_showing = true
	_player_index = 0
	_input_locked = true
	if _instruction_label:
		_fade_instruction(_instruction_label, tr("MUSIC_WATCH"))
	## Показати всі ноти з пунктирним ефектом
	for i: int in range(_sequence.size()):
		await get_tree().create_timer(SHOW_INTERVAL).timeout
		if not is_instance_valid(self) or _game_over:
			return
		if _sequence[i] >= 0 and _sequence[i] < _musicians.size():
			_musicians[_sequence[i]].highlight(SHOW_DURATION)
			## Показати назву ноти
			if _sequence[i] >= 0 and _sequence[i] < MUSICIANS_DATA.size():
				var note_name: String = MUSICIANS_DATA[_sequence[i]].get("note", "")
				_flash_note_label(note_name, MUSICIANS_DATA[_sequence[i]].get("color", Color.WHITE))
		var dot_color: Color = Color.WHITE
		if _sequence[i] >= 0 and _sequence[i] < MUSICIANS_DATA.size():
			dot_color = MUSICIANS_DATA[_sequence[i]].get("color", Color.WHITE)
		_fill_dot(i, dot_color)
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


func _play_preschool_finale() -> void:
	_input_locked = true
	if _instruction_label:
		_fade_instruction(_instruction_label, tr("MUSIC_CONCERT"))
	## Фінальний концерт — Twinkle Twinkle повна мелодія
	var finale_seq: Array[int] = [0, 0, 2, 2, 3, 3, 2, 1, 1, 0]
	_play_sequence_animated(finale_seq, func() -> void:
		if not is_instance_valid(self):
			return
		_play_success_sequence()
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
		var earned: int = _calculate_stars(_errors)
		var stats: Dictionary = {
			"time_sec": elapsed,
			"errors": _errors,
			"rounds_played": _current_level,
			"earned_stars": earned,
		}
		finish_game(earned, stats))


## -- Спільні утиліти --

## Анімоване програвання послідовності нот з callback при завершенні
func _play_sequence_animated(seq: Array[int], on_done: Callable) -> void:
	if seq.is_empty():
		push_warning("ForestOrchestra: порожня послідовність для replay")
		on_done.call()
		return
	_input_locked = true
	var delay: float = 0.0
	for i: int in range(seq.size()):
		var note_idx: int = seq[i]
		if note_idx < 0 or note_idx >= _musicians.size():
			continue
		var musician_ref: Node2D = _musicians[note_idx]
		## Відкладений виклик через SceneTreeTimer
		get_tree().create_timer(delay).timeout.connect(
			func() -> void:
				if is_instance_valid(musician_ref) and not _game_over:
					musician_ref.highlight(SHOW_DURATION)
					if note_idx >= 0 and note_idx < MUSICIANS_DATA.size():
						_flash_note_label(
							MUSICIANS_DATA[note_idx].get("note", ""),
							MUSICIANS_DATA[note_idx].get("color", Color.WHITE)))
		delay += SHOW_INTERVAL
	## Callback після завершення всієї послідовності
	get_tree().create_timer(delay + SHOW_DURATION + 0.3).timeout.connect(
		func() -> void:
			if is_instance_valid(self):
				on_done.call())


## Показати назву ноти з fade-out ефектом
func _flash_note_label(note_name: String, color: Color) -> void:
	if not is_instance_valid(_note_label):
		return
	_note_label.text = note_name
	_note_label.add_theme_color_override("font_color", Color(color, 0.9))
	_note_label.modulate.a = 1.0
	if not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween()
		tw.tween_property(_note_label, "modulate:a", 0.3, 0.8)\
			.set_delay(0.4)


## -- Прогрес-індикатор послідовності --

func _build_progress_dots(count: int) -> void:
	if _progress_container and is_instance_valid(_progress_container):
		_progress_container.queue_free()
	_progress_dots.clear()
	if count <= 0:
		push_warning("ForestOrchestra: count <= 0 для progress dots")
		return
	_progress_container = HBoxContainer.new()
	_progress_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_progress_container.set("theme_override_constants/separation", 8)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_progress_container.position = Vector2(
		vp.x * 0.5 - float(count) * 14.0, vp.y * 0.20)
	_progress_container.size = Vector2(float(count) * 28.0, 20)
	add_child(_progress_container)
	for _i: int in count:
		var dot: Panel = Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.add_theme_stylebox_override("panel",
			GameData.candy_circle(Color(1, 1, 1, 0.25), 8.0, false))
		dot.material = GameData.create_premium_material(
			0.03, 2.0, 0.0, 0.0, 0.0, 0.04, 0.10, "", 0.0, 0.10, 0.22, 0.18)
		_progress_container.add_child(dot)
		_progress_dots.append(dot)


func _fill_dot(idx: int, color: Color) -> void:
	if idx < 0 or idx >= _progress_dots.size():
		return
	var dot: Panel = _progress_dots[idx]
	if not is_instance_valid(dot):
		return
	dot.add_theme_stylebox_override("panel",
		GameData.candy_circle(color, 8.0, false))


## -- Idle hint (A10) --

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
	## Пульсація випадкового музиканта (або правильного для preschool)
	var idx: int = 0
	if not _is_toddler and _player_index >= 0 and _player_index < _sequence.size():
		## Preschool: підказка — пульсуємо правильного музиканта
		idx = _sequence[_player_index]
	else:
		idx = randi() % _musicians.size()
	if idx >= 0 and idx < _musicians.size():
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
