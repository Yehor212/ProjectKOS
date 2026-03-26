extends BaseMiniGame

## PRE-35 Буквені блоки — перетягни літери щоб скласти слово!
## 5 раундів. Показуємо зображення тварини + порожні слоти.
## Правильна літера в правильному слоті → зелений. Неправильна → snap back.
## Використовує UniversalDrag для перетягування літер.

const TOTAL_ROUNDS: int = 5
const SLOT_SIZE: float = 52.0
const SLOT_GAP: float = 8.0
const LETTER_SIZE: float = 56.0
const LETTER_GAP: float = 12.0
const EXTRA_WRONG_LETTERS: int = 3
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0

## Ключі перекладу — tr() поверне слово потрібною мовою (uk: "КІТ", en: "CAT")
const WORD_KEYS: Array[String] = [
	"SPELL_CAT", "SPELL_DOG", "SPELL_COW", "SPELL_HEN",
	"SPELL_BEAR", "SPELL_FROG", "SPELL_DEER", "SPELL_GOAT",
	"SPELL_LION", "SPELL_PANDA", "SPELL_HORSE", "SPELL_MOUSE",
	"SPELL_CHICKEN", "SPELL_PENGUIN", "SPELL_ELEPHANT",
	"SPELL_SQUIRREL", "SPELL_HEDGEHOG", "SPELL_CROCODILE",
]
const WORD_IMAGES: Dictionary = {
	"SPELL_CAT": "Cat", "SPELL_DOG": "Dog", "SPELL_COW": "Cow",
	"SPELL_HEN": "Chicken", "SPELL_BEAR": "Bear", "SPELL_FROG": "Frog",
	"SPELL_DEER": "Deer", "SPELL_GOAT": "Goat", "SPELL_LION": "Lion",
	"SPELL_PANDA": "Panda", "SPELL_HORSE": "Horse", "SPELL_MOUSE": "Mouse",
	"SPELL_CHICKEN": "Chicken", "SPELL_PENGUIN": "Penguin",
	"SPELL_ELEPHANT": "Elephant", "SPELL_SQUIRREL": "Squirrel",
	"SPELL_HEDGEHOG": "Hedgehog", "SPELL_CROCODILE": "Crocodile",
}
const SLOT_EMPTY_COLOR: Color = Color(0.93, 0.88, 0.98, 0.6)
const SLOT_CORRECT_COLOR: Color = Color("06d6a0", 0.7)
const SLOT_BORDER_COLOR: Color = Color("a78bfa")
const LETTER_BG_COLOR: Color = Color("6366f1")

var _drag: UniversalDrag = null
var _round: int = 0
var _start_time: float = 0.0
var _current_word: String = ""
var _current_word_key: String = ""
var _current_slot_idx: int = 0

var _slots: Array[Panel] = []
var _slot_nodes: Array[Node2D] = []
var _letter_nodes: Array[Node2D] = []
var _all_round_nodes: Array[Node] = []
var _letter_char: Dictionary = {}
var _letter_origins: Dictionary = {}
var _used_words: Array[int] = []
var _image_sprite: Sprite2D = null

var _idle_timer: SceneTreeTimer = null

## ---- Toddler mode: "Хто це?" ----
var _is_toddler: bool = false
var _toddler_cards: Array[Node2D] = []
var _toddler_correct_idx: int = -1
const TODDLER_CARD_W: float = 160.0
const TODDLER_CARD_H: float = 120.0
const TODDLER_IMAGE_SIZE: float = 300.0


func _ready() -> void:
	game_id = "spelling_blocks"
	bg_theme = "puzzle"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_drag = UniversalDrag.new(self)
	_drag.item_picked_up.connect(_on_picked)
	_drag.item_dropped_on_target.connect(_on_dropped_target)
	_drag.item_dropped_on_empty.connect(_on_dropped_empty)
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("SPELLING_TUTORIAL_TODDLER")
	return tr("SPELLING_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	if _is_toddler:
		## Підказка для тоддлера — тап на правильну картку
		if _toddler_correct_idx >= 0 and _toddler_correct_idx < _toddler_cards.size():
			var card: Node2D = _toddler_cards[_toddler_correct_idx]
			if is_instance_valid(card):
				return {"type": "tap", "position": card.global_position}
		return {}
	if _letter_nodes.is_empty() or _slot_nodes.is_empty():
		return {}
	if _current_slot_idx >= _current_word.length():
		return {}
	var expected: String = _current_word[_current_slot_idx]
	for node: Node2D in _letter_nodes:
		if _letter_char.get(node, "") == expected:
			var slot: Node2D = _slot_nodes[_current_slot_idx]
			return {"type": "drag", "from": node.global_position, "to": slot.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_current_slot_idx = 0
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	if _is_toddler:
		_start_round_toddler()
		return
	## Обрати слово
	_current_word_key = _pick_word_key()
	_current_word = tr(_current_word_key).to_upper()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_image(vp)
	_spawn_slots(vp)
	_spawn_letters(vp)
	var unlock_d: float = 0.15 if SettingsManager.reduced_motion else 0.4
	var tw: Tween = create_tween()
	tw.tween_interval(unlock_d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_drag.enabled = true
		_reset_idle_timer())


func _pick_word_key() -> String:
	if _used_words.size() >= WORD_KEYS.size():
		_used_words.clear()
	var idx: int = randi() % WORD_KEYS.size()
	while _used_words.has(idx):
		idx = randi() % WORD_KEYS.size()
	_used_words.append(idx)
	return WORD_KEYS[idx]


func _spawn_image(vp: Vector2) -> void:
	var animal_name: String = WORD_IMAGES.get(_current_word_key, "Cat")
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if not ResourceLoader.exists(tex_path):
		push_warning("SpellingBlocks: teksturu '%s' ne znajdeno" % tex_path)
		return
	var tex: Texture2D = load(tex_path)
	_image_sprite = Sprite2D.new()
	_image_sprite.texture = tex
	_image_sprite.scale = Vector2(0.35, 0.35)
	_image_sprite.position = Vector2(vp.x * 0.5, vp.y * 0.32)
	_image_sprite.material = GameData.create_premium_material(
		0.04, 2.0, 0.03, 0.06, 0.05, 0.04, 0.08, "", 0.0, 0.10, 0.22, 0.18)
	add_child(_image_sprite)
	_all_round_nodes.append(_image_sprite)
	## Анімація появи
	if not SettingsManager.reduced_motion:
		_image_sprite.modulate.a = 0.0
		_image_sprite.scale = Vector2(0.2, 0.2)
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(_image_sprite, "modulate:a", 1.0, 0.3)
		tw.tween_property(_image_sprite, "scale", Vector2(0.35, 0.35), 0.3)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _spawn_slots(vp: Vector2) -> void:
	_slots.clear()
	_slot_nodes.clear()
	var word_len: int = _current_word.length()
	var total_w: float = float(word_len) * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
	var start_x: float = (vp.x - total_w) * 0.5
	var slot_y: float = vp.y * 0.55
	_drag.drop_targets.clear()
	for i: int in word_len:
		## Слот — Node2D обгортка для drop target
		var slot_wrapper: Node2D = Node2D.new()
		slot_wrapper.position = Vector2(
			start_x + float(i) * (SLOT_SIZE + SLOT_GAP) + SLOT_SIZE * 0.5,
			slot_y + SLOT_SIZE * 0.5)
		slot_wrapper.name = "Slot_%d" % i
		add_child(slot_wrapper)
		_slot_nodes.append(slot_wrapper)
		_all_round_nodes.append(slot_wrapper)
		## Візуальна панель слоту
		var panel: Panel = Panel.new()
		panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		panel.position = Vector2(-SLOT_SIZE * 0.5, -SLOT_SIZE * 0.5)
		var style: StyleBoxFlat = GameData.candy_panel(SLOT_EMPTY_COLOR, 14, false)
		style.border_color = SLOT_BORDER_COLOR
		style.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", style)
		## Grain overlay (LAW 28)
		panel.material = GameData.create_premium_material(
			0.04, 2.0, 0.03, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.08, 0.18, 0.15)
		GameData.add_gloss(panel, 10)
		slot_wrapper.add_child(panel)
		_slots.append(panel)
		## Тільки перший слот є drop target (послідовний ввід)
		if i == 0:
			_drag.drop_targets.append(slot_wrapper)
	_staggered_spawn(_slot_nodes, 0.06)


func _spawn_letters(vp: Vector2) -> void:
	_letter_nodes.clear()
	_letter_char.clear()
	_letter_origins.clear()
	_drag.draggable_items.clear()
	## Зібрати літери: правильні + зайві
	var correct_letters: Array[String] = []
	for c: String in _current_word:
		correct_letters.append(c)
	var wrong_pool: Array[String] = []
	## A8: збираємо алфавіт з УСІХ перекладених слів (працює для будь-якої мови)
	var char_set: Dictionary = {}
	for wk: String in WORD_KEYS:
		var translated: String = tr(wk).to_upper()
		for ch2: String in translated:
			if not correct_letters.has(ch2):
				char_set[ch2] = true
	## Fallback: якщо char_set порожній, використовуємо SPELLING_ALPHABET
	if char_set.is_empty():
		var alphabet: String = tr("SPELLING_ALPHABET")
		if alphabet == "SPELLING_ALPHABET" or alphabet.length() > 40:
			alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		for ch3: String in alphabet:
			if not correct_letters.has(ch3):
				char_set[ch3] = true
	for ch4: String in char_set.keys():
		wrong_pool.append(ch4)
	wrong_pool.shuffle()
	var extra: Array[String] = []
	## Прогресивна складність: менше зайвих літер на початку
	var extra_count: int = _scale_by_round_i(1, EXTRA_WRONG_LETTERS, _round, TOTAL_ROUNDS)
	for i: int in mini(extra_count, wrong_pool.size()):
		extra.append(wrong_pool[i])
	var all_letters: Array[String] = correct_letters.duplicate()
	all_letters.append_array(extra)
	## Перемішати
	var shuffled: Array[String] = all_letters.duplicate()
	shuffled.shuffle()
	## Розмістити внизу
	var count: int = shuffled.size()
	var total_w: float = float(count) * (LETTER_SIZE + LETTER_GAP) - LETTER_GAP
	var start_x: float = (vp.x - total_w) * 0.5
	var letter_y: float = vp.y * 0.78
	for i: int in count:
		var ch: String = shuffled[i]
		var node: Node2D = Node2D.new()
		add_child(node)
		## Фон літери
		var bg: Panel = Panel.new()
		bg.size = Vector2(LETTER_SIZE, LETTER_SIZE)
		bg.position = Vector2(-LETTER_SIZE * 0.5, -LETTER_SIZE * 0.5)
		var style: StyleBoxFlat = GameData.candy_panel(LETTER_BG_COLOR, 16)
		style.border_color = Color(1, 1, 1, 0.4)
		style.set_border_width_all(2)
		bg.add_theme_stylebox_override("panel", style)
		## Premium overlay (LAW 28)
		bg.material = GameData.create_premium_material(
			0.05, 2.0, 0.04, 0.06, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.25, 0.20)
		GameData.add_gloss(bg, 10)
		node.add_child(bg)
		## Текст літери
		var lbl: Label = Label.new()
		lbl.text = ch
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(-LETTER_SIZE * 0.5, -LETTER_SIZE * 0.5)
		lbl.size = Vector2(LETTER_SIZE, LETTER_SIZE)
		node.add_child(lbl)
		var target_pos: Vector2 = Vector2(
			start_x + float(i) * (LETTER_SIZE + LETTER_GAP) + LETTER_SIZE * 0.5,
			letter_y)
		node.position = target_pos
		_letter_char[node] = ch
		_letter_origins[node] = target_pos
		_letter_nodes.append(node)
		_drag.draggable_items.append(node)
		_all_round_nodes.append(node)
	_staggered_spawn(_letter_nodes, 0.08)


## ---- Input ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	if _is_toddler:
		_handle_toddler_input(event)
		return
	_drag.handle_input(event)


func _process(delta: float) -> void:
	if _input_locked or _game_over:
		return
	if _is_toddler:
		return
	_drag.handle_process(delta)


func _on_picked(_item: Node2D) -> void:
	AudioManager.play_sfx("click")
	_reset_idle_timer()


func _on_dropped_target(item: Node2D, _target: Node2D) -> void:
	if _game_over:
		return
	var ch: String = _letter_char.get(item, "")
	var expected: String = _current_word[_current_slot_idx]
	if ch == expected:
		_handle_correct_letter(item)
	else:
		_handle_wrong_letter(item)


func _on_dropped_empty(item: Node2D) -> void:
	var origin: Vector2 = _letter_origins.get(item, item.position)
	_drag.snap_back(item, origin)


## ---- Feedback ----

func _handle_correct_letter(item: Node2D) -> void:
	_register_correct(item)
	_input_locked = true
	_drag.enabled = false
	## Літера летить в слот
	var slot: Node2D = _slot_nodes[_current_slot_idx]
	if SettingsManager.reduced_motion:
		item.global_position = slot.global_position
	var tw: Tween = create_tween()
	if not SettingsManager.reduced_motion:
		tw.tween_property(item, "global_position", slot.global_position, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		JuicyEffects.arrival_pulse(slot, self)
		VFXManager.spawn_correct_sparkle(slot.global_position)
		## Зробити слот зеленим + пульс-анімація
		var cs: StyleBoxFlat = GameData.candy_panel(SLOT_CORRECT_COLOR, 14, false)
		cs.border_color = Color("06d6a0")
		cs.set_border_width_all(2)
		var correct_panel: Panel = _slots[_current_slot_idx]
		correct_panel.add_theme_stylebox_override("panel", cs)
		if not SettingsManager.reduced_motion and is_instance_valid(correct_panel):
			correct_panel.modulate = Color(1.6, 1.6, 1.6, 1.0)
			var pulse_tw: Tween = create_tween()
			pulse_tw.tween_property(correct_panel, "modulate", Color.WHITE, 0.3)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		## Прибрати літеру з draggable
		_drag.draggable_items.erase(item)
		_letter_char.erase(item)
		_letter_origins.erase(item)
		_letter_nodes.erase(item)
		_current_slot_idx += 1
		if _current_slot_idx >= _current_word.length():
			_on_word_complete()
		else:
			## Оновити drop target на наступний слот
			_drag.drop_targets.clear()
			_drag.drop_targets.append(_slot_nodes[_current_slot_idx])
			_input_locked = false
			_drag.enabled = true
			_reset_idle_timer())


func _handle_wrong_letter(item: Node2D) -> void:
	_errors += 1
	_register_error(item)
	var origin: Vector2 = _letter_origins.get(item, item.position)
	_drag.snap_back(item, origin)
	_reset_idle_timer()


func _on_word_complete() -> void:
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	## Звук нагороди за зібране слово (reward.wav)
	AudioManager.play_sfx("reward")
	var round_d: float = 0.15 if SettingsManager.reduced_motion else 0.8
	var tw: Tween = create_tween()
	tw.tween_interval(round_d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


## ---- Round management ----

func _clear_round() -> void:
	if not _is_toddler:
		_drag.clear_drag()
		_drag.draggable_items.clear()
		_drag.drop_targets.clear()
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			_letter_char.erase(node)
			_letter_origins.erase(node)
			node.queue_free()
	_all_round_nodes.clear()
	_slots.clear()
	_slot_nodes.clear()
	_letter_nodes.clear()
	_letter_char.clear()
	_letter_origins.clear()
	_image_sprite = null
	_toddler_cards.clear()
	_toddler_correct_idx = -1


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = 5 if _is_toddler else _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": TOTAL_ROUNDS, "earned_stars": earned})


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
	if _input_locked or _game_over:
		return
	if _is_toddler:
		## Підказка для тоддлера — пульсувати правильну картку
		if _toddler_correct_idx >= 0 and _toddler_correct_idx < _toddler_cards.size():
			var card: Node2D = _toddler_cards[_toddler_correct_idx]
			if is_instance_valid(card):
				_pulse_node(card, 1.2)
		_reset_idle_timer()
		return
	if _letter_nodes.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	## Підказка — правильна літера пульсує
	var expected: String = _current_word[_current_slot_idx] if _current_slot_idx < _current_word.length() else ""
	for node: Node2D in _letter_nodes:
		if is_instance_valid(node) and _letter_char.get(node, "") == expected:
			_pulse_node(node, 1.2)
			break
	_reset_idle_timer()


## ---- Toddler mode: "Хто це?" ----


## Почати раунд для тоддлера — показати зображення тварини + картки вибору
func _start_round_toddler() -> void:
	_current_word_key = _pick_word_key()
	var animal_name: String = WORD_IMAGES.get(_current_word_key, "Cat")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## R0-1 = 2 картки, R2-4 = 3 картки
	var option_count: int = 2 if _round < 2 else 3
	## Зібрати дистрактори — інші тварини, відмінні від правильної
	var distractors: Array[String] = _pick_distractors(_current_word_key, option_count - 1)
	## Побудувати масив варіантів (правильна + дистрактори), перемішати
	var options: Array[Dictionary] = []
	options.append({"word_key": _current_word_key, "animal": animal_name, "correct": true})
	for dk: String in distractors:
		var d_animal: String = WORD_IMAGES.get(dk, "Cat")
		options.append({"word_key": dk, "animal": d_animal, "correct": false})
	options.shuffle()
	## Запам'ятати індекс правильної картки
	_toddler_correct_idx = -1
	for i: int in options.size():
		if options[i].correct:
			_toddler_correct_idx = i
			break
	## Показати зображення тварини зверху (якщо не аудіо-раунд R4)
	if _round < 4:
		_spawn_toddler_image(vp, animal_name)
	## Розмістити картки знизу
	var total_w: float = float(option_count) * (TODDLER_CARD_W + 16.0) - 16.0
	var start_x: float = (vp.x - total_w) * 0.5 + TODDLER_CARD_W * 0.5
	var card_y: float = vp.y * 0.75
	_toddler_cards.clear()
	for i: int in options.size():
		var opt: Dictionary = options[i]
		var pos: Vector2 = Vector2(start_x + float(i) * (TODDLER_CARD_W + 16.0), card_y)
		var card: Node2D = _spawn_toddler_card(
			pos, opt.word_key, opt.animal, opt.correct, i)
		_toddler_cards.append(card)
	_staggered_spawn(_toddler_cards, 0.08)
	## Розблокувати ввід після анімації
	var unlock_d: float = 0.15 if SettingsManager.reduced_motion else 0.4
	var tw: Tween = create_tween()
	tw.tween_interval(unlock_d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


## Показати велике зображення тварини зверху (тоддлер)
func _spawn_toddler_image(vp: Vector2, animal_name: String) -> void:
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if not ResourceLoader.exists(tex_path):
		push_warning("SpellingBlocks toddler: teksturu '%s' ne znajdeno" % tex_path)
		return
	var tex: Texture2D = load(tex_path)
	_image_sprite = Sprite2D.new()
	_image_sprite.texture = tex
	## Масштабувати до ~300dp
	var tex_size: Vector2 = Vector2(tex.get_width(), tex.get_height())
	var scale_f: float = TODDLER_IMAGE_SIZE / maxf(tex_size.x, tex_size.y)
	_image_sprite.scale = Vector2(scale_f, scale_f)
	_image_sprite.position = Vector2(vp.x * 0.5, vp.y * 0.32)
	_image_sprite.material = GameData.create_premium_material(
		0.04, 2.0, 0.03, 0.06, 0.05, 0.04, 0.08, "", 0.0, 0.10, 0.22, 0.18)
	add_child(_image_sprite)
	_all_round_nodes.append(_image_sprite)
	## Анімація появи
	if not SettingsManager.reduced_motion:
		_image_sprite.modulate.a = 0.0
		var target_scale: Vector2 = _image_sprite.scale
		_image_sprite.scale = target_scale * 0.6
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(_image_sprite, "modulate:a", 1.0, 0.3)
		tw.tween_property(_image_sprite, "scale", target_scale, 0.3)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Створити картку вибору (тоддлер): спрайт тварини + підпис
func _spawn_toddler_card(pos: Vector2, word_key: String, animal_name: String,
		is_correct: bool, card_idx: int) -> Node2D:
	var card: Node2D = Node2D.new()
	card.position = pos
	card.name = "ToddlerCard_%d" % card_idx
	add_child(card)
	_all_round_nodes.append(card)
	## Фонова панель
	var panel: Panel = Panel.new()
	panel.size = Vector2(TODDLER_CARD_W, TODDLER_CARD_H)
	panel.position = Vector2(-TODDLER_CARD_W * 0.5, -TODDLER_CARD_H * 0.5)
	var style: StyleBoxFlat = GameData.candy_panel(Color(0.95, 0.92, 1.0, 0.85), 18)
	style.border_color = SLOT_BORDER_COLOR
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	panel.material = GameData.create_premium_material(
		0.04, 2.0, 0.03, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.08, 0.18, 0.15)
	GameData.add_gloss(panel, 12)
	card.add_child(panel)
	## Спрайт тварини (~80dp висота)
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = tex
		var tex_size: Vector2 = Vector2(tex.get_width(), tex.get_height())
		var s: float = 80.0 / maxf(tex_size.x, tex_size.y)
		sprite.scale = Vector2(s, s)
		sprite.position = Vector2(0.0, -16.0)
		card.add_child(sprite)
	## Підпис — ім'я тварини
	var lbl: Label = Label.new()
	lbl.text = tr(word_key)
	lbl.add_theme_font_size_override("font_size", 26)  ## Research: ≥24sp for kids readability
	lbl.add_theme_color_override("font_color", Color(0.2, 0.15, 0.35))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(TODDLER_CARD_W, 28.0)
	lbl.position = Vector2(-TODDLER_CARD_W * 0.5, TODDLER_CARD_H * 0.5 - 32.0)
	card.add_child(lbl)
	## Невидима кнопка для тапу
	var btn: Button = Button.new()
	btn.flat = true
	btn.size = Vector2(TODDLER_CARD_W, TODDLER_CARD_H)
	btn.position = Vector2(-TODDLER_CARD_W * 0.5, -TODDLER_CARD_H * 0.5)
	btn.modulate.a = 0.0
	btn.pressed.connect(_on_toddler_card_tapped.bind(card_idx))
	card.add_child(btn)
	## Зберегти мета-дані на ноді
	card.set_meta("correct", is_correct)
	card.set_meta("card_idx", card_idx)
	return card


## Обробка натискання на картку тоддлера
func _on_toddler_card_tapped(idx: int) -> void:
	if _input_locked or _game_over:
		return
	if idx < 0 or idx >= _toddler_cards.size():
		push_warning("SpellingBlocks: невалідний індекс картки %d" % idx)
		return
	var card: Node2D = _toddler_cards[idx]
	if not is_instance_valid(card):
		push_warning("SpellingBlocks: картка %d вже знищена" % idx)
		return
	var is_correct: bool = card.get_meta("correct", false)
	if is_correct:
		_input_locked = true
		_register_correct(card)
		VFXManager.spawn_match_sparkle(card.global_position)
		AudioManager.play_sfx("success")
		HapticsManager.vibrate_success()
		## Звук нагороди (reward.wav)
		AudioManager.play_sfx("reward")
		## Перехід до наступного раунду
		var round_d: float = 0.15 if SettingsManager.reduced_motion else 0.6
		var tw: Tween = create_tween()
		tw.tween_interval(round_d)
		tw.tween_callback(func() -> void:
			_clear_round()
			_round += 1
			if _round >= TOTAL_ROUNDS:
				_finish()
			else:
				_start_round())
	else:
		## Неправильна відповідь — м'який wobble, без лічильника помилок (A6)
		AudioManager.play_sfx("click")
		if not SettingsManager.reduced_motion:
			var tw: Tween = create_tween()
			tw.tween_property(card, "position:x", card.position.x - 8.0, 0.06)
			tw.tween_property(card, "position:x", card.position.x + 8.0, 0.06)
			tw.tween_property(card, "position:x", card.position.x, 0.06)
		_reset_idle_timer()


## Обробка тач/клік вводу для тоддлера (fallback якщо Button не зловив)
func _handle_toddler_input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch and not event is InputEventMouseButton:
		return
	var pressed: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = event.pressed
		pos = event.position
	elif event is InputEventMouseButton:
		pressed = event.pressed
		pos = event.position
	if not pressed:
		return
	## Перевірити чи тап потрапив на картку
	for i: int in _toddler_cards.size():
		var card: Node2D = _toddler_cards[i]
		if not is_instance_valid(card):
			continue
		var rect: Rect2 = Rect2(
			card.global_position - Vector2(TODDLER_CARD_W * 0.5, TODDLER_CARD_H * 0.5),
			Vector2(TODDLER_CARD_W, TODDLER_CARD_H))
		if rect.has_point(pos):
			_on_toddler_card_tapped(i)
			return


## Обрати дистрактори — випадкові тварини відмінні від правильної
func _pick_distractors(correct_key: String, count: int) -> Array[String]:
	var pool: Array[String] = []
	for wk: String in WORD_KEYS:
		if wk != correct_key:
			pool.append(wk)
	pool.shuffle()
	var result: Array[String] = []
	for i: int in mini(count, pool.size()):
		result.append(pool[i])
	return result
