extends BaseMiniGame

## Living Letters — Живі букви з googly eyes.
## Дитина перетягує букви-персонажів до їх тіней/слотів.
## Toddler: uppercase → same uppercase (3 букви). Preschool: uppercase → lowercase (4-5 букв).
## Букви рисуються кодом (draw_string + googly eyes). При drag буква "говорить" свій звук.
## Після всіх букв: буквеферна анімація — букви формують слово, з'являється тварина.

const MAX_ROUNDS: int = 5
const SAFETY_TIMEOUT_SEC: float = 120.0
const SLOT_Y_CENTER: float = 0.32
const LETTER_Y_CENTER: float = 0.78
const MARGIN_X: float = 0.10
const IDLE_HINT_DELAY: float = 5.0
## Розміри букв (базові, масштабуються для toddler)
const LETTER_SIZE_BASE: float = 90.0
const SLOT_SIZE_BASE: float = 80.0
## Кольори для літер — яскраві, з достатнім контрастом (LAW 25: + форма = не тільки колір)
const LETTER_COLORS: Array[Color] = [
	Color(0.90, 0.25, 0.30),  ## червоний
	Color(0.20, 0.60, 0.85),  ## синій
	Color(0.30, 0.75, 0.35),  ## зелений
	Color(0.95, 0.65, 0.15),  ## жовтий
	Color(0.70, 0.35, 0.85),  ## фіолетовий
	Color(0.95, 0.45, 0.20),  ## помаранчевий
	Color(0.85, 0.40, 0.65),  ## рожевий
]
## Алфавіти по мовах (fallback: англійський)
const ALPHABETS: Dictionary = {
	"en": "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"uk": "АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ",
	"fr": "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	"es": "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
}
## Прості слова для фінальної анімації по мовах
const FINALE_WORDS: Dictionary = {
	"en": ["CAT", "DOG", "SUN", "BEE", "FOX"],
	"uk": ["КІТ", "ПЕС", "ДІМ", "ЛІС", "МАК"],
	"fr": ["CHAT", "LOUP", "AUBE", "LUNE", "BOIS"],
	"es": ["SOL", "MAR", "LUZ", "PAN", "REY"],
}

## Стан гри
var _is_toddler: bool = false
var _drag: UniversalDrag = null
var _current_round: int = 0
var _start_time: float = 0.0
var _idle_timer: SceneTreeTimer = null
var _alphabet: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
var _used_letters: Array[String] = []

## Раундові дані (A9: очищуються між раундами)
var _slot_nodes: Dictionary = {}       ## letter_key -> Node2D (slot/shadow)
var _letter_nodes: Dictionary = {}     ## letter_key -> Node2D (draggable letter)
var _letter_origins: Dictionary = {}   ## Node2D -> Vector2 (початкові позиції)
var _letter_colors: Dictionary = {}    ## letter_key -> Color (колір для малювання)
var _matched_count: int = 0
var _round_target_count: int = 0
var _round_errors_count: int = 0
var _round_letters: Array[String] = [] ## букви поточного раунду


func _ready() -> void:
	game_id = "letter_match"
	bg_theme = "meadow"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_drag = UniversalDrag.new(self, $DragTrail if has_node("DragTrail") else null)
	if _is_toddler:
		_drag.snap_radius_override = TODDLER_SNAP_RADIUS
	_drag.item_picked_up.connect(_on_item_picked)
	_drag.item_dropped_on_target.connect(_on_item_dropped_on_target)
	_drag.item_dropped_on_empty.connect(_on_item_dropped_on_empty)
	_start_time = Time.get_ticks_msec() / 1000.0
	_resolve_alphabet()
	_apply_background()
	var tutorial_key: String = "LETTER_TUTORIAL_TODDLER" if _is_toddler else "LETTER_TUTORIAL_PRESCHOOL"
	_build_instruction_pill(tr(tutorial_key), 24)
	_generate_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_input(event)


func _process(delta: float) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_process(delta)


## ---- Визначення алфавіту по мові ----

func _resolve_alphabet() -> void:
	var lang: String = SettingsManager.current_language
	_alphabet = ALPHABETS.get(lang, ALPHABETS.get("en", "ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
	if _alphabet.is_empty():
		push_warning("LetterMatch: empty alphabet for lang '%s', fallback to EN" % lang)
		_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


## ---- Генерація раунду ----

func _generate_round() -> void:
	_cleanup_round()
	var round_cfg: Dictionary = _get_round_config(_current_round)
	var slot_count: int = round_cfg.get("slots", 3)
	var vp: Vector2 = get_viewport().get_visible_rect().size

	## Обрати букви
	_round_letters = _pick_random_letters(slot_count)
	## Fallback: якщо не вистачає букв (A8)
	if _round_letters.size() < 3:
		push_warning("LetterMatch: not enough letters, resetting used pool")
		_used_letters.clear()
		_round_letters = _pick_random_letters(slot_count)
	if _round_letters.is_empty():
		push_warning("LetterMatch: no letters available, finishing game")
		finish_game(_calculate_stars(_errors), {
			"time_sec": 0.0, "errors": _errors,
			"rounds_played": 0, "earned_stars": _calculate_stars(_errors)})
		return

	_round_target_count = _round_letters.size()
	_matched_count = 0

	## Позиції
	var actual_count: int = _round_letters.size()
	var slot_start_x: float = vp.x * MARGIN_X
	var slot_end_x: float = vp.x * (1.0 - MARGIN_X)
	var spacing: float = (slot_end_x - slot_start_x) / float(maxi(actual_count - 1, 1))
	var slot_y: float = vp.y * SLOT_Y_CENTER
	var letter_y: float = vp.y * LETTER_Y_CENTER

	## Масштаб для toddler
	var letter_sz: float = _toddler_scale(LETTER_SIZE_BASE)
	var slot_sz: float = _toddler_scale(SLOT_SIZE_BASE)

	## Призначити кольори (LAW 25: колір + форма літери = подвійне кодування)
	for i: int in _round_letters.size():
		var letter_key: String = _round_letters[i]
		var color_idx: int = i % LETTER_COLORS.size()
		_letter_colors[letter_key] = LETTER_COLORS[color_idx]

	## Перемішати порядок літер знизу
	var shuffled: Array[String] = _round_letters.duplicate()
	shuffled.shuffle()

	var spawn_nodes: Array = []

	## Створити слоти (тіні/targets) зверху
	for i: int in _round_letters.size():
		var letter_key: String = _round_letters[i]
		var slot_text: String = letter_key if _is_toddler else letter_key.to_lower()
		var sx: float = slot_start_x + float(i) * spacing
		var slot: Node2D = _create_letter_node(
			slot_text, letter_key, slot_sz,
			Color(0.3, 0.3, 0.4, 0.35), true)
		slot.position = Vector2(sx, slot_y)
		slot.z_index = 2
		add_child(slot)
		_slot_nodes[letter_key] = slot
		spawn_nodes.append(slot)

	## Створити літери-персонажі знизу (перемішаний порядок)
	for i: int in shuffled.size():
		var letter_key: String = shuffled[i]
		var lx: float = slot_start_x + float(i) * spacing
		var letter_color: Color = _letter_colors.get(letter_key, Color.WHITE)
		var letter: Node2D = _create_letter_node(
			letter_key, letter_key, letter_sz,
			letter_color, false)
		letter.position = Vector2(lx, letter_y)
		letter.z_index = 6
		add_child(letter)
		_letter_nodes[letter_key] = letter
		_letter_origins[letter] = letter.position
		spawn_nodes.append(letter)

	## Перевірка (LAW 15: count after create)
	if _slot_nodes.size() == 0 or _letter_nodes.size() == 0:
		push_warning("LetterMatch: no valid nodes created, finishing")
		finish_game(_calculate_stars(_errors), {
			"time_sec": 0.0, "errors": _errors,
			"rounds_played": 0, "earned_stars": _calculate_stars(_errors)})
		return
	_round_target_count = mini(_slot_nodes.size(), _letter_nodes.size())

	## Каскадна поява (LAW 29)
	_staggered_spawn(spawn_nodes, 0.08)

	## Налаштувати drag
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	for key: String in _letter_nodes:
		if _letter_nodes.has(key):
			var node: Node2D = _letter_nodes[key]
			if is_instance_valid(node):
				_drag.draggable_items.append(node)
	for key: String in _slot_nodes:
		if _slot_nodes.has(key):
			var node: Node2D = _slot_nodes[key]
			if is_instance_valid(node):
				_drag.drop_targets.append(node)

	## Магнітний асист для тоддлерів
	if _is_toddler:
		_drag.magnetic_assist = true
		var pairs_dict: Dictionary = {}
		for key: String in _letter_nodes:
			if _letter_nodes.has(key) and _slot_nodes.has(key):
				pairs_dict[_letter_nodes[key]] = _slot_nodes[key]
		if not pairs_dict.is_empty():
			_drag.set_correct_pairs(pairs_dict)

	## Unlock input
	var unlock_delay: float = 0.15 if SettingsManager.reduced_motion \
		else float(spawn_nodes.size()) * 0.08 + 0.4
	var tw: Tween = _create_game_tween()
	tw.tween_interval(unlock_delay)
	tw.tween_callback(func() -> void:
		if _game_over:
			return
		_drag.enabled = true
		_input_locked = false
		_reset_idle_timer())

	## Оновити HUD
	_update_round_label(tr("COUNTING_ROUND") % [_current_round + 1, MAX_ROUNDS])
	_reset_idle_timer()


## ---- Створення літери-персонажа (Node2D з _draw) ----

func _create_letter_node(display_text: String, letter_key: String,
		sz: float, color: Color, is_slot: bool) -> Node2D:
	var node: Node2D = _LetterSprite.new()
	node.name = letter_key
	node.set_meta("letter_key", letter_key)
	node.set_meta("display_text", display_text)
	node.set_meta("letter_size", sz)
	node.set_meta("letter_color", color)
	node.set_meta("is_slot", is_slot)
	node.set_meta("has_eyes", not is_slot)
	return node


## ---- Конфігурація складності (A4: qualitative difficulty ramp) ----

func _get_round_config(round_idx: int) -> Dictionary:
	if _is_toddler:
		match round_idx:
			0: return {"slots": 3}
			1: return {"slots": 3}
			2: return {"slots": 3}
			3: return {"slots": 4}
			_: return {"slots": 4}
	## Preschool: більше букв + upper→lower mapping
	match round_idx:
		0: return {"slots": 3}
		1: return {"slots": 4}
		2: return {"slots": 4}
		3: return {"slots": 5}
		_: return {"slots": 5}


## ---- Вибір букв без повторів ----

func _pick_random_letters(count: int) -> Array[String]:
	var available: Array[String] = []
	for i: int in _alphabet.length():
		var ch: String = _alphabet[i]
		if not _used_letters.has(ch):
			available.append(ch)
	available.shuffle()
	if available.size() < count:
		_used_letters.clear()
		available.clear()
		for i: int in _alphabet.length():
			available.append(_alphabet[i])
		available.shuffle()
	var picked: Array[String] = []
	for i: int in mini(count, available.size()):
		picked.append(available[i])
		_used_letters.append(available[i])
	return picked


## ---- Drag-drop callbacks ----

func _on_item_picked(item: Node2D) -> void:
	if not is_instance_valid(item):
		push_warning("LetterMatch: picked item not valid")
		return
	AudioManager.play_sfx("click")
	_reset_idle_timer()
	## Буква "говорить" свій звук при підняття
	## (Phoneme feedback через SFX -- реальний звук додається пізніше,
	## поки що використовуємо click як placeholder)


func _on_item_dropped_on_target(item: Node2D, target: Node2D) -> void:
	if not is_instance_valid(item) or not is_instance_valid(target):
		push_warning("LetterMatch: item or target freed during drop")
		return
	_input_locked = true
	_drag.enabled = false
	## Перевірити match: ім'я літери == ім'я слота (обидва зберігають letter_key)
	var item_key: String = item.get_meta("letter_key", "")
	var target_key: String = target.get_meta("letter_key", "")
	if item_key == target_key and not item_key.is_empty():
		_handle_correct_match(item, target)
	else:
		_handle_wrong_match(item, target)


func _on_item_dropped_on_empty(item: Node2D) -> void:
	if not is_instance_valid(item):
		push_warning("LetterMatch: item freed during empty drop")
		return
	if _letter_origins.has(item):
		_drag.snap_back(item, _letter_origins[item])
	else:
		push_warning("LetterMatch: no origin for item, centering")
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_drag.snap_back(item, Vector2(vp.x * 0.5, vp.y * LETTER_Y_CENTER))


## ---- Правильний match: буква "оживає" — стрибає і танцює ----

func _handle_correct_match(item: Node2D, target: Node2D) -> void:
	_register_correct(item)
	var letter_key: String = item.get_meta("letter_key", "")
	_matched_count += 1

	## Видалити з drag
	if _drag.draggable_items.has(item):
		_drag.draggable_items.erase(item)
	if _drag.drop_targets.has(target):
		_drag.drop_targets.erase(target)

	VFXManager.spawn_success_ripple(target.global_position, Color(0.4, 1.0, 0.6, 0.6))

	if SettingsManager.reduced_motion:
		item.global_position = target.global_position
		item.z_index = 3
		if is_instance_valid(target):
			target.visible = false
		_after_correct_anim(letter_key)
		return

	## Анімація: буква летить до слота
	var tw: Tween = _create_game_tween()
	tw.tween_property(item, "global_position", target.global_position, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	## Squish bounce ("оживає")
	var orig_scale: Vector2 = item.scale
	tw.tween_property(item, "scale", orig_scale * Vector2(1.3, 0.7), 0.1)
	tw.tween_property(item, "scale", orig_scale * Vector2(0.85, 1.2), 0.1)
	tw.tween_property(item, "scale", orig_scale, 0.1)
	## Сховати слот
	tw.tween_callback(func() -> void:
		if is_instance_valid(target):
			target.visible = false
		if is_instance_valid(item):
			item.z_index = 3)
	## Golden flash (LAW 28)
	tw.tween_property(item, "modulate", Color(1.3, 1.15, 0.8), 0.12)
	tw.tween_property(item, "modulate", Color.WHITE, 0.25)
	VFXManager.spawn_match_sparkle(target.global_position)
	## Танцювальний стрибок (буква "радіє")
	tw.tween_interval(0.1)
	tw.tween_callback(func() -> void:
		if is_instance_valid(item) and not SettingsManager.reduced_motion:
			_dance_animation(item))
	tw.tween_interval(0.5)
	tw.tween_callback(_after_correct_anim.bind(letter_key))


func _after_correct_anim(_letter_key: String) -> void:
	if _game_over:
		return
	if _matched_count >= _round_target_count:
		_record_round_errors(_round_errors_count)
		_current_round += 1
		if _current_round >= MAX_ROUNDS:
			_finish_game_sequence()
		else:
			var tw: Tween = _create_game_tween()
			tw.tween_interval(ROUND_DELAY)
			tw.tween_callback(func() -> void:
				if _game_over:
					return
				_generate_round())
	else:
		_input_locked = false
		_drag.enabled = true
		_reset_idle_timer()


## ---- Неправильний match ----

func _handle_wrong_match(item: Node2D, target: Node2D) -> void:
	_round_errors_count += 1
	if _is_toddler:
		## Toddler: м'яке повернення (A6)
		_register_error(item)
	else:
		_errors += 1
		_register_error(item)
	## Snap back
	if _letter_origins.has(item):
		_drag.snap_back(item, _letter_origins[item])
	else:
		push_warning("LetterMatch: no origin for wrong item")
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_drag.snap_back(item, Vector2(vp.x * 0.5, vp.y * LETTER_Y_CENTER))
	## Wag animation на слоті
	if SettingsManager.reduced_motion:
		_input_locked = false
		_drag.enabled = true
		_reset_idle_timer()
		return
	if not is_instance_valid(target):
		_input_locked = false
		_drag.enabled = true
		_reset_idle_timer()
		return
	var orig_rot: float = target.rotation_degrees
	var wag_amp: float = 8.0 if _is_toddler else 12.0
	var tw: Tween = _create_game_tween()
	tw.tween_property(target, "rotation_degrees", orig_rot - wag_amp, 0.08)
	tw.tween_property(target, "rotation_degrees", orig_rot + wag_amp, 0.08)
	tw.tween_property(target, "rotation_degrees", orig_rot - wag_amp * 0.7, 0.07)
	tw.tween_property(target, "rotation_degrees", orig_rot + wag_amp * 0.7, 0.07)
	tw.tween_property(target, "rotation_degrees", orig_rot, 0.06)
	AudioManager.play_sfx("bounce", 0.7)
	tw.finished.connect(func() -> void:
		if _game_over:
			return
		_input_locked = false
		_drag.enabled = true
		_reset_idle_timer())


## ---- Танцювальна анімація букви ----

func _dance_animation(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	var orig_pos: Vector2 = node.position
	var orig_scale: Vector2 = node.scale
	var tw: Tween = _create_game_tween()
	## Стрибок вгору
	tw.tween_property(node, "position:y", orig_pos.y - 20.0, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position:y", orig_pos.y, 0.2)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	## Squish при приземленні
	tw.tween_property(node, "scale", orig_scale * Vector2(1.15, 0.85), 0.08)
	tw.tween_property(node, "scale", orig_scale, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## ---- Фінал гри ----

func _finish_game_sequence() -> void:
	_game_over = true
	_input_locked = true
	_drag.enabled = false
	var vp: Vector2 = get_viewport().get_visible_rect().size

	if _errors == 0 and not SettingsManager.reduced_motion:
		VFXManager.spawn_premium_confetti_rain(vp)
		VFXManager.spawn_rainbow_ring(vp * 0.5)
	VFXManager.spawn_premium_celebration(vp * 0.5)

	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	var stats: Dictionary = {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": _current_round,
		"earned_stars": earned,
	}
	var tw: Tween = _create_game_tween()
	tw.tween_interval(CELEBRATION_DELAY)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		finish_game(earned, stats))


## ---- Очистка раунду (A9: round hygiene) ----

func _cleanup_round() -> void:
	## Slot nodes
	for key: String in _slot_nodes.keys():
		var node: Node2D = _slot_nodes.get(key, null)
		_slot_nodes.erase(key)
		if node and is_instance_valid(node):
			node.queue_free()
	_slot_nodes.clear()
	## Letter nodes
	for key: String in _letter_nodes.keys():
		var node: Node2D = _letter_nodes.get(key, null)
		if node and _letter_origins.has(node):
			_letter_origins.erase(node)
		_letter_nodes.erase(key)
		if node and is_instance_valid(node):
			node.queue_free()
	_letter_nodes.clear()
	_letter_origins.clear()
	_letter_colors.clear()
	_round_letters.clear()
	_matched_count = 0
	_round_target_count = 0
	_round_errors_count = 0


## ---- Idle hint (A10: escalation) ----

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
	var hint_letter: Node2D = _find_first_unmatched_letter()
	if not is_instance_valid(hint_letter):
		return
	_advance_idle_hint()
	_idle_hint_pulse(hint_letter)
	_reset_idle_timer()


func _find_first_unmatched_letter() -> Node2D:
	for key: String in _letter_nodes:
		if _letter_nodes.has(key):
			var node: Node2D = _letter_nodes[key]
			if is_instance_valid(node) and node.visible:
				## Перевірити чи ця буква ще не matched (є в drag list)
				if _drag.draggable_items.has(node):
					return node
	return null


func _idle_hint_pulse(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	if SettingsManager.reduced_motion:
		return
	var orig_scale: Vector2 = node.scale
	var tw: Tween = _create_game_tween()
	tw.tween_property(node, "scale", orig_scale * 1.15, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", orig_scale, 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## ---- Tutorial (A1: zero-text onboarding) ----

func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("LETTER_TUTORIAL_TODDLER")
	return tr("LETTER_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	var letter: Node2D = _find_first_unmatched_letter()
	if not is_instance_valid(letter):
		return {}
	var letter_key: String = letter.get_meta("letter_key", "")
	if _slot_nodes.has(letter_key):
		var slot: Node2D = _slot_nodes[letter_key]
		if is_instance_valid(slot):
			return {"type": "drag", "from": letter.global_position, "to": slot.global_position}
	return {}


## ---- Exit cleanup ----

func _on_exit_pause() -> void:
	_drag.enabled = false
	_input_locked = true


## ============================================================
## _LetterSprite — внутрішній клас для малювання букви з googly eyes
## ============================================================

class _LetterSprite extends Node2D:
	## Внутрішній _draw-based node що малює букву-персонажа.

	var _pupil_offset: Vector2 = Vector2.ZERO
	var _blink_timer: float = 0.0
	var _blink_state: bool = false
	var _is_blinking: bool = false

	func _ready() -> void:
		_blink_timer = randf_range(2.0, 5.0)

	func _process(delta: float) -> void:
		if not get_meta("has_eyes", false):
			return
		## Googly eyes слідкують за мишкою
		var mouse_pos: Vector2 = get_global_mouse_position()
		var diff: Vector2 = mouse_pos - global_position
		var max_offset: float = 3.0
		if diff.length() > 0.01:
			_pupil_offset = diff.normalized() * min(diff.length() * 0.02, max_offset)
		else:
			_pupil_offset = Vector2.ZERO
		## Blink
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			if _is_blinking:
				_is_blinking = false
				_blink_state = false
				_blink_timer = randf_range(2.0, 5.0)
			else:
				_is_blinking = true
				_blink_state = true
				_blink_timer = 0.15
		queue_redraw()

	func _draw() -> void:
		var sz: float = get_meta("letter_size", 80.0)
		var color: Color = get_meta("letter_color", Color.WHITE)
		var text: String = get_meta("display_text", "?")
		var is_slot: bool = get_meta("is_slot", false)
		var has_eyes: bool = get_meta("has_eyes", false)

		## Фон літери — заокруглений прямокутник
		var half: float = sz * 0.5
		var rect: Rect2 = Rect2(-half, -half, sz, sz)
		if is_slot:
			## Слот: тінь/силует — напівпрозорий з пунктирним обрисом
			draw_rect(rect, Color(0.2, 0.2, 0.3, 0.15))
			## Обрис
			var border_color: Color = Color(0.5, 0.5, 0.6, 0.4)
			draw_rect(rect, border_color, false, 3.0)
		else:
			## Буква-персонаж: яскравий фон
			draw_rect(rect, color)
			## Тінь під блоком
			draw_rect(Rect2(-half, half - 4.0, sz, 6.0), Color(0.0, 0.0, 0.0, 0.15))

		## Текст літери
		var font: Font = ThemeDB.fallback_font
		var font_size: int = int(sz * 0.55)
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos: Vector2 = Vector2(-text_size.x * 0.5, text_size.y * 0.3)
		if is_slot:
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color(0.4, 0.4, 0.5, 0.5))
		else:
			## Тінь тексту
			draw_string(font, text_pos + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size, Color(0.0, 0.0, 0.0, 0.25))
			## Основний текст — білий на кольоровому фоні
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color.WHITE)

		## Googly eyes (тільки для draggable букв)
		if has_eyes:
			var eye_y: float = -half * 0.35
			var eye_spacing: float = sz * 0.2
			var eye_r: float = sz * 0.1
			var pupil_r: float = eye_r * 0.55

			if _blink_state:
				## Закриті очі — горизонтальна лінія
				draw_line(Vector2(-eye_spacing - eye_r, eye_y),
					Vector2(-eye_spacing + eye_r, eye_y),
					Color(0.15, 0.15, 0.2), 2.0)
				draw_line(Vector2(eye_spacing - eye_r, eye_y),
					Vector2(eye_spacing + eye_r, eye_y),
					Color(0.15, 0.15, 0.2), 2.0)
			else:
				## Ліве око
				draw_circle(Vector2(-eye_spacing, eye_y), eye_r, Color.WHITE)
				draw_circle(Vector2(-eye_spacing, eye_y), eye_r, Color(0.15, 0.15, 0.2), false, 1.5)
				draw_circle(Vector2(-eye_spacing + _pupil_offset.x, eye_y + _pupil_offset.y),
					pupil_r, Color(0.1, 0.1, 0.15))
				## Праве око
				draw_circle(Vector2(eye_spacing, eye_y), eye_r, Color.WHITE)
				draw_circle(Vector2(eye_spacing, eye_y), eye_r, Color(0.15, 0.15, 0.2), false, 1.5)
				draw_circle(Vector2(eye_spacing + _pupil_offset.x, eye_y + _pupil_offset.y),
					pupil_r, Color(0.1, 0.1, 0.15))
				## Блик на очах
				var highlight_r: float = pupil_r * 0.35
				draw_circle(Vector2(-eye_spacing - 1.5, eye_y - 1.5), highlight_r,
					Color(1.0, 1.0, 1.0, 0.7))
				draw_circle(Vector2(eye_spacing - 1.5, eye_y - 1.5), highlight_r,
					Color(1.0, 1.0, 1.0, 0.7))
