extends BaseMiniGame

## Phonics Pop — Лопни правильний пузир!
## Голос каже фонему (звук букви), дитина тапає пузир з потрібною літерою.
## Toddler: 3 статичних пузирі, звук автоматично + replay, знайомі літери.
## Preschool: 4-5 пузирів, що повільно летять угору, звук грає раз.
## Наратив: "Тофі вчить букви! Лопни правильний пузир!"
## Навичка: phonemic_awareness (зв'язок літера-звук).

const ROUNDS_TODDLER: int = 5  ## Was 3 → 30-60s sessions too short for 2-3yo
const ROUNDS_PRESCHOOL: int = 5
const SAFETY_TIMEOUT_SEC: float = 120.0
const IDLE_HINT_DELAY: float = 5.0
const REPLAY_DELAY: float = 0.6
const SOUND_PLAY_DELAY: float = 0.5

## Розміри пузирів (базові, масштабуються для toddler)
const BUBBLE_RADIUS_BASE: float = 65.0
const BUBBLE_GAP: float = 40.0
const TOP_MARGIN: float = 130.0
const TAP_RADIUS: float = 80.0
const DEAL_STAGGER: float = 0.12
const DEAL_DURATION: float = 0.45

## Replay кнопка
const REPLAY_BTN_SIZE: float = 80.0

## Швидкість піднімання пузирів (Preschool) — пікселів за секунду
const FLOAT_SPEED_MIN: float = 15.0
const FLOAT_SPEED_MAX: float = 35.0
## Горизонтальне хитання (sinusoid) для органічного руху
const WOBBLE_AMP: float = 12.0
const WOBBLE_SPEED: float = 1.5

## Кольори пузирів — пастельні, LAW 25: колір + літера = подвійне кодування
const BUBBLE_COLORS: Array[Color] = [
	Color(0.55, 0.80, 0.98, 0.85),  ## блакитний
	Color(0.75, 0.92, 0.65, 0.85),  ## зелений
	Color(0.98, 0.80, 0.55, 0.85),  ## жовтий
	Color(0.92, 0.65, 0.80, 0.85),  ## рожевий
	Color(0.80, 0.70, 0.95, 0.85),  ## фіолетовий
]
## Обрис (яскравіший) для контрасту
const BUBBLE_BORDER_COLORS: Array[Color] = [
	Color(0.30, 0.60, 0.85),
	Color(0.40, 0.75, 0.35),
	Color(0.85, 0.65, 0.25),
	Color(0.80, 0.35, 0.55),
	Color(0.55, 0.40, 0.80),
]

## Літери за категоріями раундів
const CONSONANTS: Array[String] = ["B", "D", "M", "S", "T", "N", "P", "K", "L", "R"]
const VOWELS: Array[String] = ["A", "E", "I", "O", "U"]
## Toddler: тільки найпростіші (знайомі) літери
const TODDLER_POOL: Array[String] = ["A", "B", "C", "M", "S"]

## Стан гри
var _is_toddler: bool = false
var _total_rounds: int = 0
var _round: int = 0
var _bubbles: Array[Node2D] = []
var _correct_bubble: Node2D = null
var _correct_letter: String = ""
var _used_letters: Array[String] = []
var _start_time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _idle_timer: SceneTreeTimer = null
var _current_round_errors: int = 0
var _replay_btn: Button = null
## Visual hint — показує цільову літеру для dual coding + sound-off accessibility
var _target_hint_label: Label = null
## Phoneme audio player
var _phoneme_player: AudioStreamPlayer = null
var _phoneme_cache: Dictionary = {}
## Прапорець руху пузирів (Preschool)
var _bubbles_floating: bool = false
## Час початку для wobble
var _wobble_time: float = 0.0
## Швидкості пузирів (індивідуальні для кожного)
var _bubble_speeds: Dictionary = {}
## Фази wobble для кожного пузиря (щоб не хитались синхронно)
var _bubble_phases: Dictionary = {}


func _ready() -> void:
	game_id = "phonics_pop"
	_skill_id = "phonemic_awareness"
	bg_theme = "candy"  ## Яскравий, грайливий стиль для phonics
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_rng.randomize()
	_start_time = Time.get_ticks_msec() / 1000.0
	_setup_phoneme_player()
	_apply_background()
	_build_instruction_pill(tr("PHONICS_POP_INSTRUCTION"), 26)
	_update_round_label("1 / %d" % _total_rounds)
	_build_replay_button()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


## Локальний AudioStreamPlayer для фонем
func _setup_phoneme_player() -> void:
	_phoneme_player = AudioStreamPlayer.new()
	_phoneme_player.bus = &"SFX"
	_phoneme_player.volume_db = 0.0
	add_child(_phoneme_player)


func _process(delta: float) -> void:
	if _game_over or not _bubbles_floating:
		return
	_wobble_time += delta
	## Пузирі повільно піднімаються (Preschool)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	for bubble: Node2D in _bubbles:
		if not is_instance_valid(bubble):
			continue
		var speed: float = _bubble_speeds.get(bubble, FLOAT_SPEED_MIN)
		var phase: float = _bubble_phases.get(bubble, 0.0)
		## Піднімання
		bubble.position.y -= speed * delta
		## Горизонтальне хитання (синусоїда)
		bubble.position.x += sin(_wobble_time * WOBBLE_SPEED + phase) * WOBBLE_AMP * delta
		## Якщо пузир вилетів зверху — повернути вниз (не втратити гру)
		if bubble.position.y < -100.0:
			bubble.position.y = vp.y + 80.0


func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	var is_tap: bool = false
	if event is InputEventMouseButton:
		is_tap = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		is_tap = event.pressed
	if not is_tap:
		return
	var pos: Vector2 = get_global_mouse_position()
	var radius: float = _toddler_scale(TAP_RADIUS)
	for bubble: Node2D in _bubbles:
		if not is_instance_valid(bubble):
			continue
		if pos.distance_to(bubble.global_position) < radius:
			_handle_tap(bubble)
			return


func _handle_tap(bubble: Node2D) -> void:
	_input_locked = true
	if bubble == _correct_bubble:
		_handle_correct(bubble)
	else:
		_handle_wrong(bubble)


func _handle_correct(bubble: Node2D) -> void:
	_register_correct(bubble)
	_current_round_errors = 0
	## Пузир лопається з VFX!
	VFXManager.spawn_golden_burst(bubble.global_position)
	_animate_pop(bubble)


func _handle_wrong(bubble: Node2D) -> void:
	_current_round_errors += 1
	if not _is_toddler:
		_errors += 1
	_register_error(bubble)
	## A11: scaffolding
	var threshold: int = 2 if _is_toddler else 3
	if _current_round_errors >= threshold:
		_show_answer_scaffold()
		return
	## Невірний пузир — wobble + розблокувати input
	_animate_wrong_wobble(bubble)


## A11: показати правильну відповідь
func _show_answer_scaffold() -> void:
	if not is_instance_valid(_correct_bubble):
		push_warning("PhonicsPop: _correct_bubble freed during scaffold")
		_input_locked = false
		return
	## Пульсація правильного пузиря
	_pulse_node(_correct_bubble, 1.3)
	## Повторити фонему для закріплення
	_play_phoneme(_correct_letter)
	var tw: Tween = _create_game_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_input_locked = false
		_reset_idle_timer()
	)


## Анімація лопання пузиря — scale up + fade out + шматочки
func _animate_pop(bubble: Node2D) -> void:
	if not is_instance_valid(bubble):
		push_warning("PhonicsPop: bubble freed during pop animation")
		_advance_round()
		return
	if SettingsManager.reduced_motion:
		_on_pop_complete()
		return
	_bubbles_floating = false  ## Зупинити рух на час анімації
	var orig_scale: Vector2 = bubble.scale
	var tw: Tween = _create_game_tween()
	## Пузир росте і зникає (лопається!)
	tw.tween_property(bubble, "scale", orig_scale * 1.5, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.08)
	tw.tween_interval(0.3)
	tw.tween_callback(_on_pop_complete)


## Анімація невірного тапу — wobble + розблокувати
func _animate_wrong_wobble(bubble: Node2D) -> void:
	if not is_instance_valid(bubble):
		push_warning("PhonicsPop: bubble freed during wrong wobble")
		_input_locked = false
		return
	if SettingsManager.reduced_motion:
		_input_locked = false
		_reset_idle_timer()
		return
	var tw: Tween = _create_game_tween()
	tw.tween_property(bubble, "rotation_degrees", 8.0, 0.06)
	tw.tween_property(bubble, "rotation_degrees", -8.0, 0.06)
	tw.tween_property(bubble, "rotation_degrees", 4.0, 0.04)
	tw.tween_property(bubble, "rotation_degrees", 0.0, 0.04)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_input_locked = false
		_reset_idle_timer()
	)


func _on_pop_complete() -> void:
	if not is_instance_valid(self):
		return
	_advance_round()


func _advance_round() -> void:
	if _game_over:
		return
	_record_round_errors(_current_round_errors)
	_clear_round()
	_round += 1
	if _round >= _total_rounds:
		_finish()
	else:
		_update_round_label("%d / %d" % [_round + 1, _total_rounds])
		_start_round()


## ---- Запуск раунду ----

func _start_round() -> void:
	_input_locked = true
	_current_round_errors = 0
	_correct_bubble = null
	_correct_letter = ""
	_bubbles_floating = false
	_wobble_time = 0.0
	_bubble_speeds.clear()
	_bubble_phases.clear()

	## Кількість варіантів (LAW 2 / A4)
	var choice_count: int = _get_choice_count()

	## Оновити інструкцію
	if is_instance_valid(_instruction_label):
		var key: String = "PHONICS_POP_INSTRUCTION"
		if not _is_toddler and _round >= 3:
			key = "PHONICS_POP_LISTEN_CAREFULLY"
		_fade_instruction(_instruction_label, tr(key))

	## Обрати літери для раунду
	var letters: Array[String] = _pick_round_letters(choice_count)
	## A8: fallback guard
	if letters.size() < 3:
		push_warning("PhonicsPop: insufficient letters for round, skip")
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round()
		return

	## Перша літера = правильна відповідь
	_correct_letter = letters[0]

	## Створити пузирі
	_create_bubbles(letters)
	## A8: guard
	if _bubbles.size() == 0:
		push_warning("PhonicsPop: no bubbles created, skipping round")
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round()
		return

	## Розставити та анімувати
	_deal_bubbles()

	## Програти фонему після появи пузирів
	var sound_delay: float = SOUND_PLAY_DELAY
	if not SettingsManager.reduced_motion:
		sound_delay += float(_bubbles.size()) * DEAL_STAGGER + DEAL_DURATION
	var sound_tw: Tween = _create_game_tween()
	sound_tw.tween_interval(sound_delay)
	sound_tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_play_phoneme(_correct_letter)
		_show_replay_button()
		## Preschool: пузирі починають рухатись після звуку
		if not _is_toddler:
			_bubbles_floating = true
		else:
			## Toddler: gentle bobbing замість руху
			_start_toddler_bobbing()
	)


## Toddler idle bobbing — пузирі ніжно гойдаються на місці
func _start_toddler_bobbing() -> void:
	if SettingsManager.reduced_motion:
		return
	for bubble: Node2D in _bubbles:
		if not is_instance_valid(bubble):
			continue
		var base_y: float = bubble.position.y
		var amp: float = 5.0 + randf() * 3.0  ## 5-8px амплітуда
		var dur: float = 0.8 + randf() * 0.4  ## 0.8-1.2s період
		var tw: Tween = _create_game_tween().set_loops()
		tw.tween_property(bubble, "position:y", base_y - amp, dur)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(bubble, "position:y", base_y + amp, dur)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Кількість варіантів за раундом та віком
func _get_choice_count() -> int:
	if _is_toddler:
		return 3  ## LAW 2: мінімум 3
	## Preschool: R1-2=4, R3-5=5
	return _scale_adaptive_i(4, 5, _round, _total_rounds)


## Обрати літери для раунду за категорією
func _pick_round_letters(count: int) -> Array[String]:
	var pool: Array[String] = _get_round_pool()
	if pool.size() == 0:
		push_warning("PhonicsPop: empty letter pool")
		return []

	## Прибрати вже використані (anti-repeat)
	var available: Array[String] = []
	for letter: String in pool:
		if not _used_letters.has(letter):
			available.append(letter)
	## Якщо замало — скинути використані
	if available.size() < count:
		_used_letters.clear()
		available = pool.duplicate()

	available.shuffle()
	var picked: Array[String] = []
	for i: int in range(mini(count, available.size())):
		picked.append(available[i])
	## Запам'ятати правильну літеру (перша)
	if picked.size() > 0:
		_used_letters.append(picked[0])
	return picked


## Пул літер за поточним раундом (A4: progressive difficulty)
func _get_round_pool() -> Array[String]:
	if _is_toddler:
		return TODDLER_POOL.duplicate()
	## Preschool: R1-2 consonants, R3-4 vowels, R5 mixed
	if _round < 2:
		return CONSONANTS.duplicate()
	elif _round < 4:
		return VOWELS.duplicate()
	else:
		## Mixed: всі
		var mixed: Array[String] = []
		mixed.append_array(CONSONANTS)
		mixed.append_array(VOWELS)
		return mixed


## ---- Створення пузирів ----

func _create_bubbles(letters: Array[String]) -> void:
	for i: int in letters.size():
		var letter: String = letters[i]
		var color_idx: int = i % BUBBLE_COLORS.size()
		var bubble: Node2D = _BubbleNode.new()
		var radius: float = _toddler_scale(BUBBLE_RADIUS_BASE)
		bubble.set_meta("letter", letter)
		bubble.set_meta("bubble_radius", radius)
		bubble.set_meta("bubble_color", BUBBLE_COLORS[color_idx])
		bubble.set_meta("border_color", BUBBLE_BORDER_COLORS[color_idx])
		bubble.set_meta("is_correct", letter == _correct_letter)
		## Preschool R3+: uppercase+lowercase mix для дистракторів
		var display: String = letter
		if not _is_toddler and _round >= 2 and letter != _correct_letter:
			## 50% шанс показати lowercase для дистрактора
			if _rng.randf() > 0.5:
				display = letter.to_lower()
		bubble.set_meta("display_letter", display)
		add_child(bubble)
		## LAW 28: premium material
		bubble.material = GameData.create_premium_material(
			0.04, 2.0, 0.03, 0.05, 0.05, 0.04, 0.06, "", 0.0, 0.10, 0.25, 0.20)
		_bubbles.append(bubble)
		if letter == _correct_letter:
			_correct_bubble = bubble
		## Preschool: індивідуальна швидкість для кожного пузиря
		_bubble_speeds[bubble] = _rng.randf_range(FLOAT_SPEED_MIN, FLOAT_SPEED_MAX)
		_bubble_phases[bubble] = _rng.randf_range(0.0, TAU)


## Розставити пузирі — горизонтально з невеликим jitter
func _deal_bubbles() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var radius: float = _toddler_scale(BUBBLE_RADIUS_BASE)
	var total: int = _bubbles.size()
	if total == 0:
		push_warning("PhonicsPop: _deal_bubbles called with 0 bubbles")
		return
	## Перемішати порядок (щоб правильний не завжди зліва)
	_bubbles.shuffle()
	## Горизонтальне розташування
	var cell: float = radius * 2.0 + BUBBLE_GAP
	var total_width: float = float(total) * cell
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5 + TOP_MARGIN * 0.1
	## Toddler: статичні, чуть нижче центру
	if _is_toddler:
		cy = vp.y * 0.55
	for i: int in range(total):
		if i >= _bubbles.size():
			break
		var bubble: Node2D = _bubbles[i]
		if not is_instance_valid(bubble):
			continue
		var target_x: float = cx - total_width * 0.5 + cell * (float(i) + 0.5)
		var jitter_y: float = _rng.randf_range(-15.0, 15.0)
		var target: Vector2 = Vector2(target_x, cy + jitter_y)
		if SettingsManager.reduced_motion:
			bubble.position = target
			bubble.modulate.a = 1.0
		else:
			## Пузирі "виринають" знизу
			bubble.position = Vector2(target.x, vp.y + 100.0)
			bubble.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = _create_game_tween().set_parallel(true)
			tw.tween_property(bubble, "position", target, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(bubble, "modulate:a", 1.0, 0.2).set_delay(delay)
			tw.tween_property(bubble, "scale", Vector2.ONE, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## ---- Replay кнопка ----

func _build_replay_button() -> void:
	var s: float = _ui_scale()
	_replay_btn = Button.new()
	_replay_btn.theme_type_variation = &"CircleButton"
	_replay_btn.custom_minimum_size = Vector2(REPLAY_BTN_SIZE * s, REPLAY_BTN_SIZE * s)
	_replay_btn.text = ""
	_replay_btn.visible = false
	_replay_btn.pressed.connect(_on_replay_pressed)
	IconDraw.icon_in_button(_replay_btn, IconDraw.music_note(32.0 * s))
	_replay_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_replay_btn.offset_top = _sa_top + 140.0 * s
	_replay_btn.offset_left = -REPLAY_BTN_SIZE * s * 0.5
	_replay_btn.offset_right = REPLAY_BTN_SIZE * s * 0.5
	JuicyEffects.button_press_squish(_replay_btn, self)
	JuicyEffects.button_hover_scale(_replay_btn, self)
	_ui_layer.add_child(_replay_btn)
	## Target hint label — dual coding (Mayer): audio phoneme + visual letter
	## Accessibility: makes game playable with sound OFF (WCAG 2.2, EAA June 2025)
	_target_hint_label = Label.new()
	_target_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_target_hint_label.add_theme_font_size_override("font_size", int(48.0 * s))
	_target_hint_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 0.95))
	_target_hint_label.add_theme_constant_override("outline_size", int(6.0 * s))
	_target_hint_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.3, 0.8))
	_target_hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_target_hint_label.offset_top = _sa_top + 190.0 * s
	_target_hint_label.visible = false
	_ui_layer.add_child(_target_hint_label)


func _show_replay_button() -> void:
	if is_instance_valid(_replay_btn):
		_replay_btn.visible = true
		if not SettingsManager.reduced_motion:
			_replay_btn.pivot_offset = _replay_btn.size / 2.0
			_replay_btn.scale = Vector2(0.3, 0.3)
			var tw: Tween = _create_game_tween()
			tw.tween_property(_replay_btn, "scale", Vector2(1.1, 1.1), 0.2)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_replay_btn, "scale", Vector2.ONE, 0.1)
		## Розблокувати input
		_input_locked = false
		_reset_idle_timer()
	## Показати visual hint (dual coding: audio phoneme + visual letter)
	_show_target_hint()


func _show_target_hint() -> void:
	if not is_instance_valid(_target_hint_label) or _correct_letter.is_empty():
		return
	## Показати цільову літеру великим шрифтом: "Знайди: B"
	_target_hint_label.text = tr("PHONICS_FIND") + " " + _correct_letter
	_target_hint_label.visible = true
	_target_hint_label.modulate.a = 0.0
	if not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween()
		tw.tween_property(_target_hint_label, "modulate:a", 1.0, 0.3).set_delay(0.5)
	else:
		_target_hint_label.modulate.a = 1.0


func _hide_target_hint() -> void:
	if is_instance_valid(_target_hint_label):
		_target_hint_label.visible = false


func _hide_replay_button() -> void:
	if is_instance_valid(_replay_btn):
		_replay_btn.visible = false
	_hide_target_hint()


func _on_replay_pressed() -> void:
	if _game_over or _correct_letter.is_empty():
		return
	AudioManager.play_sfx("click")
	_play_phoneme(_correct_letter)
	if is_instance_valid(_replay_btn) and not SettingsManager.reduced_motion:
		_replay_btn.pivot_offset = _replay_btn.size / 2.0
		var tw: Tween = _create_game_tween()
		tw.tween_property(_replay_btn, "scale", Vector2(1.15, 1.15), 0.08)
		tw.tween_property(_replay_btn, "scale", Vector2.ONE, 0.12)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## ---- Phoneme audio ----

## Програти фонему літери
func _play_phoneme(letter: String) -> void:
	if letter.is_empty():
		push_warning("PhonicsPop: empty letter for phoneme")
		return
	if not is_instance_valid(_phoneme_player):
		push_warning("PhonicsPop: _phoneme_player freed")
		return
	var sfx_id: String = "phoneme_%s" % letter.to_lower()
	## Спробувати AudioManager (основний шлях)
	## Fallback: завантажити з файлу
	var stream: AudioStream = _get_phoneme_stream(sfx_id)
	if stream:
		_phoneme_player.stream = stream
		_phoneme_player.play()
	else:
		## Fallback: музична нота з унікальним pitch per letter (до появи записів)
		_play_phoneme_fallback(letter)


## Fallback: кожна буква = унікальна нота (note_c/e/g/a + pitch)
const _LETTER_TONE_MAP: Dictionary = {
	## Голосні — note_a
	"a": {"note": "note_a", "pitch": 1.0},
	"e": {"note": "note_a", "pitch": 1.2},
	"i": {"note": "note_a", "pitch": 1.4},
	"o": {"note": "note_a", "pitch": 0.8},
	"u": {"note": "note_a", "pitch": 0.9},
	## Ранні приголосні — note_c
	"b": {"note": "note_c", "pitch": 0.7},
	"d": {"note": "note_c", "pitch": 0.8},
	"m": {"note": "note_c", "pitch": 1.0},
	"n": {"note": "note_c", "pitch": 1.1},
	"p": {"note": "note_c", "pitch": 1.3},
	## Пізні приголосні — note_e
	"s": {"note": "note_e", "pitch": 1.0},
	"t": {"note": "note_e", "pitch": 0.8},
	"k": {"note": "note_e", "pitch": 0.7},
	"l": {"note": "note_e", "pitch": 1.1},
	"r": {"note": "note_e", "pitch": 0.9},
	## C = окремо
	"c": {"note": "note_g", "pitch": 1.0},
}


func _play_phoneme_fallback(letter: String) -> void:
	var key: String = letter.to_lower()
	var tone: Dictionary = _LETTER_TONE_MAP.get(key, {"note": "note_c", "pitch": 1.0})
	var note_name: String = tone.get("note", "note_c") as String
	var pitch: float = tone.get("pitch", 1.0) as float
	## Завантажити ноту з файлу (note_c.wav існує!)
	var note_path: String = "res://assets/audio/sfx/%s.wav" % note_name
	if ResourceLoader.exists(note_path):
		var stream: AudioStream = load(note_path)
		_phoneme_player.stream = stream
		_phoneme_player.pitch_scale = pitch
		_phoneme_player.play()
	else:
		push_warning("PhonicsPop: note '%s' not found, fallback click" % note_name)
		AudioManager.play_sfx("click")


## Lazy load фонеми з кешуванням
func _get_phoneme_stream(sfx_id: String) -> AudioStream:
	if _phoneme_cache.has(sfx_id):
		return _phoneme_cache.get(sfx_id)
	## Спробувати .wav
	var path_wav: String = "res://assets/audio/sfx/%s.wav" % sfx_id
	if ResourceLoader.exists(path_wav):
		var stream: AudioStream = load(path_wav)
		_phoneme_cache[sfx_id] = stream
		return stream
	## Спробувати .ogg
	var path_ogg: String = "res://assets/audio/sfx/%s.ogg" % sfx_id
	if ResourceLoader.exists(path_ogg):
		var stream: AudioStream = load(path_ogg)
		_phoneme_cache[sfx_id] = stream
		return stream
	## Не знайдено
	_phoneme_cache[sfx_id] = null
	return null


## ---- Round cleanup ---- LAW 9 / A9

func _clear_round() -> void:
	_hide_replay_button()
	_bubbles_floating = false
	if is_instance_valid(_phoneme_player) and _phoneme_player.playing:
		_phoneme_player.stop()
	for bubble: Node2D in _bubbles:
		if is_instance_valid(bubble):
			_bubble_speeds.erase(bubble)
			_bubble_phases.erase(bubble)
			bubble.queue_free()
	_bubbles.clear()
	_correct_bubble = null
	_correct_letter = ""
	_current_round_errors = 0


func _finish() -> void:
	_game_over = true
	_input_locked = true
	_bubbles_floating = false
	_hide_replay_button()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": _total_rounds,
		"earned_stars": earned,
	})


## ---- Idle hints — A10 ----

func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over:
		return
	var level: int = _advance_idle_hint()
	## Level 0-1: пульсувати правильний пузир + повторити фонему
	if level < 2 and is_instance_valid(_correct_bubble):
		_pulse_node(_correct_bubble, 1.2)
		_play_phoneme(_correct_letter)
	_reset_idle_timer()


## ---- Tutorial — A1: zero-text onboarding ----

func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("PHONICS_POP_TUTORIAL_TODDLER")
	return tr("PHONICS_POP_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	## Показати replay кнопку та правильний пузир
	if is_instance_valid(_replay_btn) and _replay_btn.visible:
		return {"type": "tap", "target": _replay_btn.global_position + _replay_btn.size / 2.0}
	if is_instance_valid(_correct_bubble):
		return {"type": "tap", "target": _correct_bubble.global_position}
	return {}


## ---- Exit pause (для ExitConfirmOverlay) ----

func _on_exit_pause() -> void:
	_bubbles_floating = false


## ---- Inner class: _BubbleNode ----
## Малює пузир з літерою всередині через _draw (кодовий рендерінг)

class _BubbleNode extends Node2D:
	func _draw() -> void:
		var radius: float = get_meta("bubble_radius", 65.0)
		var color: Color = get_meta("bubble_color", Color(0.55, 0.80, 0.98, 0.85))
		var border: Color = get_meta("border_color", Color(0.30, 0.60, 0.85))
		var letter: String = get_meta("display_letter", "?")

		## Тіло пузиря — заповнене коло
		draw_circle(Vector2.ZERO, radius, color)
		## Обрис — тонка лінія
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, border, 3.0)
		## Блік (specular highlight) — маленьке біле коло зверху-зліва
		var highlight_pos: Vector2 = Vector2(-radius * 0.3, -radius * 0.35)
		var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.45)
		draw_circle(highlight_pos, radius * 0.22, highlight_color)
		## Другий блік менший
		var highlight2_pos: Vector2 = Vector2(-radius * 0.15, -radius * 0.5)
		draw_circle(highlight2_pos, radius * 0.1, Color(1.0, 1.0, 1.0, 0.3))

		## Літера всередині пузиря
		var font: Font = ThemeDB.fallback_font
		var font_size: int = int(radius * 0.9)
		var text_size: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = Vector2(-text_size.x * 0.5, text_size.y * 0.35)
		## Тінь літери
		draw_string(font, text_pos + Vector2(2, 2), letter,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.2))
		## Літера — темний колір для контрасту на пастельному тлі
		draw_string(font, text_pos, letter,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.15, 0.15, 0.25))
