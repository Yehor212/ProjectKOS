extends BaseMiniGame

## Sound Match / Хто так каже? — впізнай тварину за звуком!
## Перша аудіо-орієнтована гра платформи: auditory discrimination.
## Toddler: 3 тварини, 3 раунди, великі зображення, звук грає автоматично.
## Preschool: 4-5 тварин, 5 раундів, R4-5 — тихіший звук (harder listening).
## Наратив: "Хто так каже? Натисни на тваринку!" — тварина радіє при вірній відповіді.

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 5
const ITEM_SCALE_BASE: Vector2 = Vector2(0.42, 0.42)
const GRID_GAP: float = 50.0
const TAP_RADIUS: float = 120.0
const DEAL_STAGGER: float = 0.1
const DEAL_DURATION: float = 0.4
const TOP_MARGIN: float = 130.0
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0
const REPLAY_DELAY: float = 0.6
const SOUND_PLAY_DELAY: float = 0.5
## Гучність для тихого режиму (Preschool R4-5) — зменшення на 12 dB
const QUIET_VOLUME_DB: float = -12.0
const NORMAL_VOLUME_DB: float = 0.0
## Анімація: тварина "танцює" при правильному тапі
const DANCE_SCALE: float = 1.2
const DANCE_ROTATION_DEG: float = 8.0
## Кнопка replay — розмір та позиція
const REPLAY_BTN_SIZE: float = 80.0
## Маппінг тварин -> SFX ідентифікаторів
const ANIMAL_SFX_MAP: Dictionary = {
	"Bunny": "animal_bunny",
	"Dog": "animal_dog",
	"Bear": "animal_bear",
	"Monkey": "animal_monkey",
	"Cat": "animal_cat",
	"Chicken": "animal_chicken",
	"Cow": "animal_cow",
	"Crocodile": "animal_crocodile",
	"Frog": "animal_frog",
	"Deer": "animal_deer",
	"Elephant": "animal_elephant",
	"Horse": "animal_horse",
	"Lion": "animal_lion",
	"Penguin": "animal_penguin",
	"Panda": "animal_panda",
	"Goat": "animal_goat",
	"Mouse": "animal_mouse",
	"Squirrel": "animal_squirrel",
	"Hedgehog": "animal_hedgehog",
}
## SFX шлях для тваринних звуків
const ANIMAL_SFX_DIR: String = "res://assets/audio/sfx/"

var _is_toddler: bool = false
var _total_rounds: int = 0
var _round: int = 0
var _items: Array[Node2D] = []
var _correct_item: Node2D = null
var _correct_animal_name: String = ""
var _used_animals: Array[int] = []
var _start_time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _idle_timer: SceneTreeTimer = null
var _current_round_errors: int = 0
## Replay кнопка (speaker icon)
var _replay_btn: Button = null
## Локальний AudioStreamPlayer для тваринних звуків з контролем гучності
var _animal_player: AudioStreamPlayer = null
## Кешовані звуки тварин (lazy load)
var _animal_sfx_cache: Dictionary = {}
## Поточна гучність (нормальна або тиха для складних раундів)
var _current_volume_db: float = NORMAL_VOLUME_DB


func _ready() -> void:
	game_id = "sound_match"
	_skill_id = "auditory_discrimination"
	bg_theme = "meadow"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_rng.randomize()
	_start_time = Time.get_ticks_msec() / 1000.0
	_setup_animal_player()
	_apply_background()
	_build_instruction_pill(tr("SOUND_MATCH_INSTRUCTION"), 26)
	_update_round_label("1 / %d" % _total_rounds)
	_build_replay_button()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


## Локальний AudioStreamPlayer — дозволяє контролювати гучність тваринних звуків
func _setup_animal_player() -> void:
	_animal_player = AudioStreamPlayer.new()
	_animal_player.bus = &"SFX"
	_animal_player.volume_db = NORMAL_VOLUME_DB
	add_child(_animal_player)


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
	for item: Node2D in _items:
		if not is_instance_valid(item):
			continue
		if pos.distance_to(item.global_position) < TAP_RADIUS:
			_handle_tap(item)
			return


func _handle_tap(item: Node2D) -> void:
	_input_locked = true
	if item == _correct_item:
		_handle_correct(item)
	else:
		_handle_wrong(item)


func _handle_correct(item: Node2D) -> void:
	_register_correct(item)
	_current_round_errors = 0
	VFXManager.spawn_golden_burst(item.global_position)
	## Тварина "танцює" від радості при правильній відповіді
	_animate_happy_dance(item)


func _handle_wrong(item: Node2D) -> void:
	_current_round_errors += 1
	if not _is_toddler:
		_errors += 1
	_register_error(item)
	## A11: scaffolding — після 2 (Toddler) або 3 (Preschool) помилок показуємо відповідь
	var threshold: int = 2 if _is_toddler else 3
	if _current_round_errors >= threshold:
		_show_answer_scaffold()
		return
	var delay: float = 0.15 if SettingsManager.reduced_motion else 0.3
	var tw: Tween = _create_game_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_input_locked = false
		_reset_idle_timer()
	)


## A11: показати правильну відповідь — пульсувати + програти звук повторно
func _show_answer_scaffold() -> void:
	if not is_instance_valid(_correct_item):
		push_warning("SoundMatch: _correct_item freed during scaffold")
		_input_locked = false
		return
	## Пульсація правильної тварини
	_pulse_node(_correct_item, 1.3)
	## Повторити звук для закріплення зв'язку звук-тварина
	_play_animal_sound(_correct_animal_name)
	var tw: Tween = _create_game_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_input_locked = false
		_reset_idle_timer()
	)


## Тварина танцює при правильній відповіді — bounce + rotation + confetti
func _animate_happy_dance(item: Node2D) -> void:
	if not is_instance_valid(item):
		push_warning("SoundMatch: item freed during happy dance")
		_advance_round()
		return
	if SettingsManager.reduced_motion:
		_on_dance_complete()
		return
	var orig_scale: Vector2 = item.scale
	var tw: Tween = _create_game_tween()
	## Танець: bounce вгору + wobble ліво-право (як тварина радіє)
	tw.tween_property(item, "scale", orig_scale * DANCE_SCALE, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "rotation_degrees", DANCE_ROTATION_DEG, 0.08)
	tw.tween_property(item, "rotation_degrees", -DANCE_ROTATION_DEG, 0.08)
	tw.tween_property(item, "rotation_degrees", DANCE_ROTATION_DEG * 0.5, 0.06)
	tw.tween_property(item, "rotation_degrees", 0.0, 0.06)
	tw.tween_property(item, "scale", orig_scale, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	tw.tween_callback(_on_dance_complete)


func _on_dance_complete() -> void:
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


func _start_round() -> void:
	_input_locked = true
	_current_round_errors = 0
	_correct_item = null
	_correct_animal_name = ""
	## Визначити кількість варіантів для цього раунду (LAW 6 / A4)
	var choice_count: int = _get_choice_count()
	## Визначити гучність (Preschool R4-5 = тихіше)
	_current_volume_db = _get_round_volume()
	_animal_player.volume_db = _current_volume_db
	## Оновити інструкцію
	if is_instance_valid(_instruction_label):
		var key: String = "SOUND_MATCH_INSTRUCTION"
		if not _is_toddler and _round >= _total_rounds - 2:
			key = "SOUND_MATCH_LISTEN_CAREFULLY"
		_fade_instruction(_instruction_label, tr(key))
	## Обрати тварин та створити елементи
	var indices: Array[int] = _pick_animal_indices(choice_count)
	## A8: fallback guard
	if indices.size() < 2:
		push_warning("SoundMatch: недостатньо тварин для раунду, skip")
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round()
		return
	## Перша тварина = правильна відповідь
	var correct_idx: int = indices[0]
	var correct_data: Dictionary = GameData.ANIMALS_AND_FOOD[correct_idx]
	_correct_animal_name = correct_data.get("name", "")
	## Створити items
	_create_animal_items(indices, correct_idx)
	## A8: guard — якщо items порожні
	if _items.size() == 0:
		push_warning("SoundMatch: no items created, skipping round")
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round()
		return
	## Розставити та анімувати появу
	_deal_items()
	## Програти звук після появи items (з затримкою)
	var sound_delay: float = SOUND_PLAY_DELAY
	if not SettingsManager.reduced_motion:
		sound_delay += float(_items.size()) * DEAL_STAGGER + DEAL_DURATION
	var sound_tw: Tween = _create_game_tween()
	sound_tw.tween_interval(sound_delay)
	sound_tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_play_animal_sound(_correct_animal_name)
		## Показати replay кнопку
		_show_replay_button()
	)


## Кількість варіантів за раундом та віком
func _get_choice_count() -> int:
	if _is_toddler:
		return 3  ## Toddler: завжди 3 (LAW 2: мінімум 3 варіанти)
	## Preschool: R1-2=4, R3-5=5 (stepped)
	return _scale_stepped_i(4, 5, _round, _total_rounds)


## Гучність звуку за раундом — Preschool R4-5 тихіше (harder listening)
func _get_round_volume() -> float:
	if _is_toddler:
		return NORMAL_VOLUME_DB
	## Preschool: поступове зменшення в останніх 2 раундах
	if _round >= _total_rounds - 2:
		return QUIET_VOLUME_DB
	return NORMAL_VOLUME_DB


## Обрати N унікальних індексів з ANIMALS_AND_FOOD (anti-repeat)
func _pick_animal_indices(count: int) -> Array[int]:
	var pool_size: int = GameData.ANIMALS_AND_FOOD.size()
	if pool_size == 0:
		push_warning("SoundMatch: ANIMALS_AND_FOOD порожній")
		return []
	## Доступні індекси (без вже використаних правильних тварин)
	var available: Array[int] = []
	for i: int in range(pool_size):
		if not _used_animals.has(i):
			available.append(i)
	## Якщо замало — скинути використані
	if available.size() < count:
		_used_animals.clear()
		available.clear()
		for i: int in range(pool_size):
			available.append(i)
	available.shuffle()
	## Перший = правильна відповідь, решта = дистрактори
	var picked: Array[int] = []
	for i: int in range(mini(count, available.size())):
		picked.append(available[i])
	## Запам'ятати правильну тварину
	if picked.size() > 0:
		_used_animals.append(picked[0])
	return picked


## Створити Node2D тварин з ANIMALS_AND_FOOD
func _create_animal_items(indices: Array[int], correct_idx: int) -> void:
	for idx: int in indices:
		## A8: bounds check
		if idx < 0 or idx >= GameData.ANIMALS_AND_FOOD.size():
			push_warning("SoundMatch: index %d out of bounds" % idx)
			continue
		var data: Dictionary = GameData.ANIMALS_AND_FOOD[idx]
		var scene: PackedScene = data.get("animal_scene")
		if not scene:
			push_warning("SoundMatch: animal_scene відсутня для index %d" % idx)
			continue
		var item: Node2D = scene.instantiate()
		var scale_factor: float = TODDLER_SCALE if _is_toddler else 1.0
		item.scale = ITEM_SCALE_BASE * scale_factor
		item.set_meta("animal_index", idx)
		item.set_meta("animal_name", data.get("name", ""))
		add_child(item)
		## LAW 28: premium material
		item.material = GameData.create_premium_material(
			0.05, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.12, 0.28, 0.22)
		_items.append(item)
		if idx == correct_idx:
			_correct_item = item


## Розкласти тварин на екрані — горизонтальний ряд з jitter
func _deal_items() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var scale_factor: float = TODDLER_SCALE if _is_toddler else 1.0
	var item_size: float = 512.0 * ITEM_SCALE_BASE.x * scale_factor
	var total: int = _items.size()
	if total == 0:
		push_warning("SoundMatch: _deal_items called with 0 items")
		return
	## Перемішати порядок показу (щоб правильна не завжди зліва)
	_items.shuffle()
	## Горизонтальне розташування з центром екрану
	var cell: float = item_size + GRID_GAP
	var total_width: float = float(total) * cell
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5 + TOP_MARGIN * 0.15  ## Трохи нижче центру для replay кнопки
	var positions: Array[Vector2] = []
	for i: int in range(total):
		var x: float = cx - total_width * 0.5 + cell * (float(i) + 0.5)
		## Невелике випадкове зміщення для живості
		var jitter_y: float = _rng.randf_range(-10.0, 10.0)
		positions.append(Vector2(x, cy + jitter_y))
	## Анімована поява кожного елемента
	for i: int in range(total):
		if i >= _items.size():
			break
		var item: Node2D = _items[i]
		if not is_instance_valid(item):
			continue
		var target: Vector2 = positions[i]
		if SettingsManager.reduced_motion:
			item.position = target
			item.modulate.a = 1.0
		else:
			## Поява знизу — "вистрибують" на сцену
			item.position = Vector2(target.x, vp.y + 100.0)
			item.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = _create_game_tween().set_parallel(true)
			tw.tween_property(item, "position", target, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
			tw.tween_property(item, "scale", item.scale, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			if i == total - 1:
				tw.set_parallel(false)
				## Input розблокується ПІСЛЯ звуку (в _start_round)
				## Тут тільки фіксуємо що анімація завершена


## ---- Replay кнопка ----

## Створити replay кнопку (speaker icon) на UI layer
func _build_replay_button() -> void:
	var s: float = _ui_scale()
	_replay_btn = Button.new()
	_replay_btn.theme_type_variation = &"CircleButton"
	_replay_btn.custom_minimum_size = Vector2(REPLAY_BTN_SIZE * s, REPLAY_BTN_SIZE * s)
	_replay_btn.text = ""
	_replay_btn.visible = false  ## Прихована до першого звуку
	_replay_btn.pressed.connect(_on_replay_pressed)
	## Music note icon для "програй звук" (немає speaker в IconDraw)
	IconDraw.icon_in_button(_replay_btn, IconDraw.music_note(32.0 * s))
	## Позиція: центр-верх, під instruction pill
	_replay_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_replay_btn.offset_top = _sa_top + 140.0 * s
	_replay_btn.offset_left = -REPLAY_BTN_SIZE * s * 0.5
	_replay_btn.offset_right = REPLAY_BTN_SIZE * s * 0.5
	JuicyEffects.button_press_squish(_replay_btn, self)
	JuicyEffects.button_hover_scale(_replay_btn, self)
	_ui_layer.add_child(_replay_btn)


func _show_replay_button() -> void:
	if is_instance_valid(_replay_btn):
		_replay_btn.visible = true
		## Bounce-in анімація для привертання уваги
		if not SettingsManager.reduced_motion:
			_replay_btn.pivot_offset = _replay_btn.size / 2.0
			_replay_btn.scale = Vector2(0.3, 0.3)
			var tw: Tween = _create_game_tween()
			tw.tween_property(_replay_btn, "scale", Vector2(1.1, 1.1), 0.2)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(_replay_btn, "scale", Vector2.ONE, 0.1)
		## Розблокувати input після появи кнопки
		_input_locked = false
		_reset_idle_timer()


func _hide_replay_button() -> void:
	if is_instance_valid(_replay_btn):
		_replay_btn.visible = false


func _on_replay_pressed() -> void:
	if _game_over or _correct_animal_name.is_empty():
		return
	AudioManager.play_sfx("click")
	_play_animal_sound(_correct_animal_name)
	## Pulse кнопку для feedback
	if is_instance_valid(_replay_btn) and not SettingsManager.reduced_motion:
		_replay_btn.pivot_offset = _replay_btn.size / 2.0
		var tw: Tween = _create_game_tween()
		tw.tween_property(_replay_btn, "scale", Vector2(1.15, 1.15), 0.08)
		tw.tween_property(_replay_btn, "scale", Vector2.ONE, 0.12)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## ---- Звук тварини ----

## Програти звук тварини з контролем гучності
func _play_animal_sound(animal_name: String) -> void:
	if animal_name.is_empty():
		push_warning("SoundMatch: порожнє ім'я тварини для звуку")
		return
	if not is_instance_valid(_animal_player):
		push_warning("SoundMatch: _animal_player freed")
		return
	var sfx_id: String = ANIMAL_SFX_MAP.get(animal_name, "")
	if sfx_id.is_empty():
		push_warning("SoundMatch: немає SFX маппінгу для '%s', fallback to click" % animal_name)
		AudioManager.play_sfx("click")
		return
	## Спробувати завантажити з кешу або з диску
	var stream: AudioStream = _get_animal_stream(sfx_id)
	if not stream:
		## Fallback: pitch-shifted існуючий SFX (кожна тварина = унікальний звук)
		_play_animal_fallback(animal_name)
		return
	_animal_player.stream = stream
	_animal_player.volume_db = _current_volume_db
	_animal_player.pitch_scale = 1.0
	_animal_player.play()


## Fallback: кожна тварина = унікальний pitch існуючого SFX (до появи реальних записів)
const _ANIMAL_VOICE_MAP: Dictionary = {
	## Маленькі милі — pop (високий)
	"Bunny": {"sfx": "pop", "pitch": 1.8},
	"Mouse": {"sfx": "pop", "pitch": 1.5},
	"Squirrel": {"sfx": "pop", "pitch": 1.6},
	"Hedgehog": {"sfx": "pop", "pitch": 1.3},
	## Домашні — bounce
	"Dog": {"sfx": "bounce", "pitch": 0.7},
	"Cat": {"sfx": "bounce", "pitch": 1.0},
	## Ферма — chomp
	"Chicken": {"sfx": "chomp", "pitch": 1.2},
	"Cow": {"sfx": "chomp", "pitch": 0.5},
	"Goat": {"sfx": "chomp", "pitch": 0.8},
	"Horse": {"sfx": "chomp", "pitch": 0.6},
	## Великі дикі — whoosh (низький)
	"Bear": {"sfx": "whoosh", "pitch": 0.4},
	"Lion": {"sfx": "whoosh", "pitch": 0.5},
	"Crocodile": {"sfx": "whoosh", "pitch": 0.45},
	"Elephant": {"sfx": "whoosh", "pitch": 0.35},
	## Грайливі — giggle
	"Monkey": {"sfx": "giggle", "pitch": 1.2},
	"Frog": {"sfx": "giggle", "pitch": 1.4},
	"Penguin": {"sfx": "giggle", "pitch": 0.9},
	"Panda": {"sfx": "giggle", "pitch": 0.7},
	"Deer": {"sfx": "giggle", "pitch": 0.8},
}


func _play_animal_fallback(animal_name: String) -> void:
	var voice: Dictionary = _ANIMAL_VOICE_MAP.get(animal_name, {"sfx": "click", "pitch": 1.0})
	var sfx_name: String = voice.get("sfx", "click") as String
	var pitch: float = voice.get("pitch", 1.0) as float
	AudioManager.play_sfx(sfx_name, pitch)


## Lazy load тваринного SFX з кешуванням
func _get_animal_stream(sfx_id: String) -> AudioStream:
	## Перевірити кеш
	if _animal_sfx_cache.has(sfx_id):
		return _animal_sfx_cache.get(sfx_id)
	## Спробувати завантажити .wav
	var path_wav: String = ANIMAL_SFX_DIR + sfx_id + ".wav"
	if ResourceLoader.exists(path_wav):
		var stream: AudioStream = load(path_wav)
		_animal_sfx_cache[sfx_id] = stream
		return stream
	## Спробувати .ogg
	var path_ogg: String = ANIMAL_SFX_DIR + sfx_id + ".ogg"
	if ResourceLoader.exists(path_ogg):
		var stream: AudioStream = load(path_ogg)
		_animal_sfx_cache[sfx_id] = stream
		return stream
	## Не знайдено
	_animal_sfx_cache[sfx_id] = null
	return null


## ---- Round cleanup ----

## Очистити раунд — LAW 9 round hygiene, LAW 11 no orphans
func _clear_round() -> void:
	_hide_replay_button()
	## Зупинити звук тварини з попереднього раунду
	if is_instance_valid(_animal_player) and _animal_player.playing:
		_animal_player.stop()
	for item: Node2D in _items:
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()
	_correct_item = null
	_correct_animal_name = ""
	_current_round_errors = 0


func _finish() -> void:
	_game_over = true
	_input_locked = true
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
	## Level 0-1: пульсувати правильну тварину + повторити звук
	if level < 2 and is_instance_valid(_correct_item):
		_pulse_node(_correct_item, 1.2)
		_play_animal_sound(_correct_animal_name)
	## Level 2: tutorial hand (handled by _advance_idle_hint -> tutorial_sys)
	_reset_idle_timer()


## ---- Tutorial — A1: zero-text onboarding ----

func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("SOUND_MATCH_TUTORIAL_TODDLER")
	return tr("SOUND_MATCH_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	## Показати replay кнопку та правильну тварину для demo
	if is_instance_valid(_replay_btn) and _replay_btn.visible:
		return {"type": "tap", "target": _replay_btn.global_position + _replay_btn.size / 2.0}
	if is_instance_valid(_correct_item):
		return {"type": "tap", "target": _correct_item.global_position}
	return {}
