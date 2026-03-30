extends BaseMiniGame

## NAR-01 Карти історій / Story Cards — впорядкуй картки в правильну послідовність.
## Toddler: 3 картки, прості рутини (ранок, сон, гра). Drag у слоти 1-2-3.
## Preschool: 4-5 карток, складніші процеси (ріст рослини, пори року).
## R3+ Preschool: додатковий distractor — зайва картка, що не належить до послідовності.
## Коли порядок правильний — анімований slideshow ("міні-фільм").

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 5
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0
const CARD_WIDTH: float = 140.0
const CARD_HEIGHT: float = 100.0
const CARD_WIDTH_TODDLER: float = 180.0
const CARD_HEIGHT_TODDLER: float = 130.0
const SLOT_SPACING: float = 20.0
const DEAL_STAGGER: float = 0.08
const DEAL_DURATION: float = 0.30
const SLIDESHOW_CARD_SEC: float = 1.2
const ANIMAL_SCALE: float = 0.40

## Послідовності — 3 тіри складності (Piaget: від конкретних рутин до абстрактних процесів).
## tier 1 = Toddler-safe (3 картки, щоденні рутини)
## tier 2 = Preschool early (4 картки, природні процеси)
## tier 3 = Preschool late (5 карток, складні наративи)
const SEQUENCES: Array[Dictionary] = [
	## ============ TIER 1: DAILY ROUTINES (ages 2-4, 3 cards) ============
	{"id": "morning", "tier": 1, "cards": ["wake_up", "breakfast", "brush_teeth"],
		"label_key": "STORY_MORNING", "colors": [Color("ffd166"), Color("ff9f1c"), Color("06d6a0")]},
	{"id": "bedtime", "tier": 1, "cards": ["bath", "pajamas", "sleep"],
		"label_key": "STORY_BEDTIME", "colors": [Color("74b9ff"), Color("a29bfe"), Color("6c5ce7")]},
	{"id": "play_outside", "tier": 1, "cards": ["shoes_on", "go_outside", "play"],
		"label_key": "STORY_PLAY", "colors": [Color("55efc4"), Color("00b894"), Color("ffeaa7")]},
	{"id": "meal_time", "tier": 1, "cards": ["hungry", "cook", "eat"],
		"label_key": "STORY_MEAL", "colors": [Color("fab1a0"), Color("e17055"), Color("00cec9")]},
	{"id": "get_dressed", "tier": 1, "cards": ["wake_up", "clothes", "ready"],
		"label_key": "STORY_DRESSED", "colors": [Color("ffd166"), Color("a29bfe"), Color("55efc4")]},
	{"id": "rainy_day", "tier": 1, "cards": ["rain", "umbrella", "puddles"],
		"label_key": "STORY_RAIN", "colors": [Color("74b9ff"), Color("fdcb6e"), Color("81ecec")]},
	## ============ TIER 2: NATURE/PROCESS (ages 4-5, 4 cards) ============
	{"id": "plant_grow", "tier": 2, "cards": ["seed", "water", "sprout", "flower"],
		"label_key": "STORY_PLANT", "colors": [Color("dfe6e9"), Color("74b9ff"), Color("55efc4"), Color("fd79a8")]},
	{"id": "butterfly", "tier": 2, "cards": ["egg", "caterpillar", "cocoon", "butterfly"],
		"label_key": "STORY_BUTTERFLY", "colors": [Color("ffeaa7"), Color("55efc4"), Color("a29bfe"), Color("fd79a8")]},
	{"id": "seasons", "tier": 2, "cards": ["spring", "summer", "autumn", "winter"],
		"label_key": "STORY_SEASONS", "colors": [Color("55efc4"), Color("ffd166"), Color("e17055"), Color("74b9ff")]},
	{"id": "bake_cake", "tier": 2, "cards": ["ingredients", "mix", "oven", "cake"],
		"label_key": "STORY_CAKE", "colors": [Color("dfe6e9"), Color("ffeaa7"), Color("e17055"), Color("fd79a8")]},
	## ============ TIER 3: COMPLEX NARRATIVES (ages 5-7, 5 cards) ============
	{"id": "lost_puppy", "tier": 3, "cards": ["puppy_lost", "search", "found", "hug", "home"],
		"label_key": "STORY_PUPPY",
		"colors": [Color("fab1a0"), Color("ffeaa7"), Color("55efc4"), Color("fd79a8"), Color("a29bfe")]},
	{"id": "build_house", "tier": 3, "cards": ["plan", "foundation", "walls", "roof", "done"],
		"label_key": "STORY_HOUSE",
		"colors": [Color("74b9ff"), Color("dfe6e9"), Color("ffd166"), Color("e17055"), Color("55efc4")]},
]

## Символи для кожної карткової ілюстрації (LAW 25: не лише колір — є символ + номер).
## Кожна карта має унікальний symbol для ідентифікації без залежності від кольору.
const CARD_SYMBOLS: Dictionary = {
	## Tier 1
	"wake_up": "*",    "breakfast": "#",  "brush_teeth": "~",
	"bath": "~",       "pajamas": "%",    "sleep": "z",
	"shoes_on": "^",   "go_outside": ">", "play": "+",
	"hungry": "?",     "cook": "#",       "eat": "+",
	"clothes": "%",    "ready": "!",
	"rain": "~",       "umbrella": "^",   "puddles": "+",
	## Tier 2
	"seed": ".",       "water": "~",      "sprout": "|",    "flower": "*",
	"egg": "o",        "caterpillar": "=", "cocoon": "O",   "butterfly": "V",
	"spring": "*",     "summer": "#",     "autumn": "%",    "winter": ".",
	"ingredients": "#", "mix": "@",       "oven": "^",      "cake": "!",
	## Tier 3
	"puppy_lost": "?", "search": ">",    "found": "!",     "hug": "+",  "home": "#",
	"plan": ".",       "foundation": "=", "walls": "|",     "roof": "^", "done": "!",
}

## Distractor карти (tier 3 / R3+) — зайві картки, що не належать до послідовності.
const DISTRACTOR_CARDS: Array[Dictionary] = [
	{"id": "distractor_rocket", "symbol": "R", "color": Color("636e72"), "label_key": "STORY_CARD_ROCKET"},
	{"id": "distractor_fish", "symbol": "F", "color": Color("00cec9"), "label_key": "STORY_CARD_FISH"},
	{"id": "distractor_moon", "symbol": "M", "color": Color("6c5ce7"), "label_key": "STORY_CARD_MOON"},
	{"id": "distractor_hat", "symbol": "H", "color": Color("e17055"), "label_key": "STORY_CARD_HAT"},
]

var _is_toddler: bool = false
var _round: int = 0
var _total_rounds: int = 0
var _start_time: float = 0.0

var _current_sequence: Dictionary = {}
var _card_count: int = 3
var _has_distractor: bool = false

## UI елементи раунду
var _slot_nodes: Array[Node2D] = []      ## Нумеровані слоти зверху
var _card_nodes: Array[Node2D] = []      ## Картки внизу (draggable)
var _placed_cards: Dictionary = {}       ## slot_index -> card Node2D
var _all_round_nodes: Array[Node] = []   ## Для очистки між раундами
var _animal_node: Node2D = null
var _origins: Dictionary = {}            ## card -> Vector2 (snap-back позиції)

var _drag: UniversalDrag = null
var _idle_timer: SceneTreeTimer = null
var _round_errors_count: int = 0
var _used_sequences: Array[int] = []
var _used_animal_indices: Array[int] = []
var _slideshow_playing: bool = false


func _ready() -> void:
	game_id = "story_cards"
	_skill_id = "narrative_sequencing"
	bg_theme = "garden"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_setup_drag()
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func _process(delta: float) -> void:
	if _drag and not _input_locked and not _game_over and not _slideshow_playing:
		_drag.handle_process(delta)


func _input(event: InputEvent) -> void:
	if _input_locked or _game_over or _slideshow_playing:
		return
	if _drag:
		_drag.handle_input(event)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("STORY_TUTORIAL_TODDLER")
	return tr("STORY_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	## A1: Показати drag від першої невстановленої картки до першого порожнього слота
	if _card_nodes.size() > 0 and _slot_nodes.size() > 0:
		var first_card: Node2D = null
		for card: Node2D in _card_nodes:
			if is_instance_valid(card) and card.visible:
				first_card = card
				break
		var first_empty_slot: Node2D = null
		for i: int in _slot_nodes.size():
			if not _placed_cards.has(i) and is_instance_valid(_slot_nodes[i]):
				first_empty_slot = _slot_nodes[i]
				break
		if first_card and first_empty_slot:
			return {"type": "drag", "from": first_card.global_position,
				"to": first_empty_slot.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


func _setup_drag() -> void:
	_drag = UniversalDrag.new(self)
	_drag.item_picked_up.connect(_on_card_picked)
	_drag.item_dropped_on_target.connect(_on_card_dropped)
	_drag.item_dropped_on_empty.connect(_on_card_missed)
	if _is_toddler:
		_drag.magnetic_assist = true
		_drag.snap_radius_override = TODDLER_SNAP_RADIUS


func _on_card_picked(_item: Node2D) -> void:
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()


func _on_exit_pause() -> void:
	if _drag:
		_drag.clear_drag()


## ---- Раунд lifecycle ----


func _start_round() -> void:
	_input_locked = true
	_round_errors_count = 0
	_slideshow_playing = false
	_placed_cards.clear()
	_clear_round_nodes()

	if _drag:
		_drag.clear_drag()
		_drag.draggable_items.clear()
		_drag.drop_targets.clear()
	_origins.clear()

	_current_sequence = _pick_sequence()
	var cards_arr: Array = _current_sequence.get("cards", [])
	_card_count = cards_arr.size()

	## A3: вікова розвилка — Preschool R3+ має distractor
	_has_distractor = (not _is_toddler and _round >= 2 and _card_count >= 4)

	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	var label_key: String = _current_sequence.get("label_key", "STORY_MORNING")
	_fade_instruction(_instruction_label, tr(label_key))

	## Побудувати слоти
	_spawn_slots()
	## Побудувати картки (перемішані)
	_spawn_cards()
	## Тварина-компаньйон
	_spawn_animal()


func _pick_sequence() -> Dictionary:
	if SEQUENCES.size() == 0:
		push_warning("StoryCards: SEQUENCES порожній — fallback")
		return {"id": "fallback", "tier": 1, "cards": ["wake_up", "breakfast", "brush_teeth"],
			"label_key": "STORY_MORNING", "colors": [Color.WHITE, Color.WHITE, Color.WHITE]}

	if _used_sequences.size() >= SEQUENCES.size():
		_used_sequences.clear()

	## Tier filter (LAW 6: progressive difficulty, A4: difficulty ramp)
	var min_tier: int = 1
	var max_tier: int = 1
	if _is_toddler:
		max_tier = 1  ## Toddler: тільки tier 1 (прості рутини, 3 картки)
	else:
		if _round < 2:
			max_tier = 2  ## Preschool R1-2: tier 1-2
		else:
			max_tier = 3  ## Preschool R3+: tier 1-3
		if _round >= 3:
			min_tier = 2  ## Пізні раунди: без тривіальних

	## Фільтруємо по тіру та невикористаних
	var available: Array[int] = []
	for i: int in SEQUENCES.size():
		if _used_sequences.has(i):
			continue
		var tier: int = int(SEQUENCES[i].get("tier", 1))
		if tier >= min_tier and tier <= max_tier:
			available.append(i)

	## A8 Fallback: якщо tier filter занадто суворий — усі невикористані
	if available.size() == 0:
		for i: int in SEQUENCES.size():
			if not _used_sequences.has(i):
				available.append(i)

	## Second fallback: скинути все
	if available.size() == 0:
		push_warning("StoryCards: всі послідовності використані, скидаємо")
		_used_sequences.clear()
		for i: int in SEQUENCES.size():
			available.append(i)

	if available.size() == 0:
		push_warning("StoryCards: critical — no sequences available")
		return SEQUENCES[0]

	var idx: int = available[randi() % available.size()]
	_used_sequences.append(idx)
	return SEQUENCES[idx]


func _spawn_slots() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var s: float = _ui_scale()
	var cw: float = (CARD_WIDTH_TODDLER if _is_toddler else CARD_WIDTH) * s
	var ch: float = (CARD_HEIGHT_TODDLER if _is_toddler else CARD_HEIGHT) * s
	var spacing: float = SLOT_SPACING * s

	var total_width: float = float(_card_count) * cw + float(_card_count - 1) * spacing
	var start_x: float = (vp.x - total_width) * 0.5 + cw * 0.5
	var slot_y: float = _sa_top + 130.0 * s

	_slot_nodes.clear()
	for i: int in _card_count:
		var slot: Node2D = Node2D.new()
		slot.position = Vector2(start_x + float(i) * (cw + spacing), slot_y)
		slot.set_meta("slot_index", i)
		add_child(slot)
		_slot_nodes.append(slot)
		_all_round_nodes.append(slot)

		## Візуальне оформлення слота: dashed border + номер
		var slot_bg: Panel = Panel.new()
		slot_bg.size = Vector2(cw, ch)
		slot_bg.position = Vector2(-cw * 0.5, -ch * 0.5)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.08)
		style.border_color = Color(1, 1, 1, 0.3)
		style.set_border_width_all(int(2.0 * s))
		style.set_corner_radius_all(int(12.0 * s))
		slot_bg.add_theme_stylebox_override("panel", style)
		slot.add_child(slot_bg)

		## Номер слота (LAW 25: текст + позиція, не лише колір)
		var num_label: Label = Label.new()
		num_label.text = str(i + 1)
		num_label.add_theme_font_size_override("font_size", int(28.0 * s))
		num_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_label.size = Vector2(cw, ch)
		num_label.position = Vector2(-cw * 0.5, -ch * 0.5)
		slot.add_child(num_label)

	## Deal animation для слотів
	_orchestrated_entrance(_slot_nodes, 0.06, false)


func _spawn_cards() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var s: float = _ui_scale()
	var cw: float = (CARD_WIDTH_TODDLER if _is_toddler else CARD_WIDTH) * s
	var ch: float = (CARD_HEIGHT_TODDLER if _is_toddler else CARD_HEIGHT) * s
	var spacing: float = SLOT_SPACING * s

	var cards_arr: Array = _current_sequence.get("cards", [])
	var colors_arr: Array = _current_sequence.get("colors", [])

	## Побудувати масив карток (correct + optional distractor)
	var card_defs: Array[Dictionary] = []
	for i: int in cards_arr.size():
		var card_id: String = str(cards_arr[i]) if i < cards_arr.size() else "unknown"
		var card_color: Color = colors_arr[i] if i < colors_arr.size() else Color.WHITE
		card_defs.append({
			"card_id": card_id,
			"correct_index": i,
			"color": card_color,
			"is_distractor": false,
		})

	## Preschool R3+: додати distractor
	if _has_distractor and DISTRACTOR_CARDS.size() > 0:
		var d: Dictionary = DISTRACTOR_CARDS[randi() % DISTRACTOR_CARDS.size()]
		card_defs.append({
			"card_id": d.get("id", "distractor"),
			"correct_index": -1,
			"color": d.get("color", Color.GRAY),
			"is_distractor": true,
			"symbol": d.get("symbol", "X"),
		})

	## Перемішати
	card_defs.shuffle()

	## Позиціонування карток внизу
	var total_cards: int = card_defs.size()
	var total_width: float = float(total_cards) * cw + float(maxi(total_cards - 1, 0)) * spacing
	var start_x: float = (vp.x - total_width) * 0.5 + cw * 0.5
	var card_y: float = vp.y * 0.72

	_card_nodes.clear()
	var stagger_offset: float = float(_card_count) * DEAL_STAGGER + 0.15

	for i: int in total_cards:
		var def: Dictionary = card_defs[i]
		var card: Node2D = _create_card_node(def, cw, ch, s)
		var target_pos: Vector2 = Vector2(start_x + float(i) * (cw + spacing), card_y)
		card.set_meta("card_def", def)
		card.set_meta("origin_pos", target_pos)
		card.set_meta("disabled", false)
		add_child(card)
		_card_nodes.append(card)
		_all_round_nodes.append(card)
		_origins[card] = target_pos

		## Deal animation
		var is_last: bool = (i == total_cards - 1)
		_deal_card_in(card, target_pos, stagger_offset + float(i) * DEAL_STAGGER, is_last)

	## Налаштувати drag
	if _drag:
		_drag.draggable_items = _card_nodes.duplicate()
		var slot_targets: Array[Node2D] = []
		for slot: Node2D in _slot_nodes:
			if is_instance_valid(slot):
				slot_targets.append(slot)
		_drag.drop_targets = slot_targets


func _create_card_node(def: Dictionary, w: float, h: float, s: float) -> Node2D:
	var card: Node2D = Node2D.new()
	var card_color: Color = def.get("color", Color.WHITE)
	var card_id: String = def.get("card_id", "unknown")
	var is_distractor: bool = def.get("is_distractor", false)

	## Фон картки — rounded rectangle з кольором послідовності
	var bg_panel: Panel = Panel.new()
	bg_panel.size = Vector2(w, h)
	bg_panel.position = Vector2(-w * 0.5, -h * 0.5)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = card_color
	style.set_corner_radius_all(int(14.0 * s))
	## Subtle border для візуального виділення
	style.border_color = Color(0, 0, 0, 0.12)
	style.set_border_width_all(int(2.0 * s))
	bg_panel.add_theme_stylebox_override("panel", style)
	## Premium матеріал (LAW 28)
	bg_panel.material = GameData.create_premium_material(
		0.03, 2.0, 0.0, 0.0, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
	GameData.add_gloss(bg_panel, 8)
	card.add_child(bg_panel)

	## Символ картки (LAW 25: не лише колір — має символ для ідентифікації)
	var symbol: String = ""
	if is_distractor:
		symbol = def.get("symbol", "X")
	else:
		symbol = CARD_SYMBOLS.get(card_id, "?")
	var sym_label: Label = Label.new()
	sym_label.text = symbol
	sym_label.add_theme_font_size_override("font_size", int(36.0 * s))
	sym_label.add_theme_color_override("font_color", Color(0, 0, 0, 0.5))
	sym_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sym_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sym_label.size = Vector2(w, h * 0.6)
	sym_label.position = Vector2(-w * 0.5, -h * 0.5)
	card.add_child(sym_label)

	## Назва картки — перекладена (під символом)
	var name_key: String = "STORY_CARD_%s" % card_id.to_upper()
	var name_label: Label = Label.new()
	name_label.text = tr(name_key)
	name_label.add_theme_font_size_override("font_size", int(14.0 * s))
	name_label.add_theme_color_override("font_color", Color(0, 0, 0, 0.6))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(w, h * 0.3)
	name_label.position = Vector2(-w * 0.5, h * 0.12)
	card.add_child(name_label)

	## Distractor має хрестик-мітку (LAW 25: додатковий visual cue)
	if is_distractor:
		var cross: Label = Label.new()
		cross.text = "?"
		cross.add_theme_font_size_override("font_size", int(16.0 * s))
		cross.add_theme_color_override("font_color", Color(0.5, 0.2, 0.2, 0.4))
		cross.size = Vector2(24.0 * s, 24.0 * s)
		cross.position = Vector2(w * 0.5 - 20.0 * s, -h * 0.5 + 4.0 * s)
		card.add_child(cross)

	return card


func _deal_card_in(node: Node2D, target: Vector2, delay: float, unlock_on_finish: bool) -> void:
	if SettingsManager.reduced_motion:
		node.position = target
		node.scale = Vector2.ONE
		node.modulate.a = 1.0
		if unlock_on_finish:
			_input_locked = false
			_reset_idle_timer()
		return

	node.position = Vector2(target.x, target.y + 160.0)
	node.scale = Vector2(0.2, 0.2)
	node.modulate.a = 0.0
	var tw: Tween = _create_game_tween().set_parallel(true)
	tw.tween_property(node, "position", target, DEAL_DURATION)\
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, DEAL_DURATION)\
		.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.2).set_delay(delay)
	if unlock_on_finish:
		var stw: Tween = _create_game_tween()
		stw.tween_interval(delay + DEAL_DURATION + 0.05)
		stw.tween_callback(func() -> void:
			if is_instance_valid(self):
				_input_locked = false
				_reset_idle_timer())


## ---- Drop handling ----


func _on_card_dropped(item: Node2D, target: Node2D) -> void:
	if not is_instance_valid(item) or not is_instance_valid(target):
		push_warning("StoryCards: dropped item or target invalid")
		return
	if item.get_meta("disabled", false):
		push_warning("StoryCards: dropped disabled card")
		return

	var slot_index: int = int(target.get_meta("slot_index", -1))
	if slot_index < 0 or slot_index >= _card_count:
		push_warning("StoryCards: invalid slot_index %d" % slot_index)
		_snap_card_back(item)
		return

	## Перевірити чи слот вже зайнятий
	if _placed_cards.has(slot_index):
		## Слот зайнятий — snap back
		_snap_card_back(item)
		return

	var def: Dictionary = item.get_meta("card_def", {})
	var is_distractor: bool = def.get("is_distractor", false)

	## Distractor картка у слот — це помилка
	if is_distractor:
		_handle_wrong_placement(item)
		return

	var correct_index: int = int(def.get("correct_index", -1))

	if correct_index == slot_index:
		_handle_correct_placement(item, target, slot_index)
	else:
		_handle_wrong_placement(item)


func _handle_correct_placement(item: Node2D, target: Node2D, slot_index: int) -> void:
	_input_locked = true
	AudioManager.play_sfx("success")
	_register_correct(item)

	## Помістити картку в слот
	_placed_cards[slot_index] = item
	item.set_meta("disabled", true)

	## Анімація: картка летить у слот
	if _drag:
		_drag.draggable_items.erase(item)

	if SettingsManager.reduced_motion:
		item.position = target.position
		_check_round_complete()
		return

	var tw: Tween = _create_game_tween()
	tw.tween_property(item, "position", target.position, ANIM_NORMAL)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self):
			VFXManager.spawn_correct_sparkle(target.position)
			_check_round_complete())


func _handle_wrong_placement(item: Node2D) -> void:
	## A6/A7: вікова обробка помилок
	if not _is_toddler:
		_errors += 1
	_round_errors_count += 1
	_register_error(item)
	_snap_card_back(item)
	_input_locked = false
	_reset_idle_timer()


func _snap_card_back(item: Node2D) -> void:
	if not is_instance_valid(item):
		push_warning("StoryCards: snap_back — item freed")
		return
	if _origins.has(item):
		_drag.snap_back(item, _origins[item])
	else:
		push_warning("StoryCards: no origin for card, using current position")


func _on_card_missed(item: Node2D) -> void:
	if not is_instance_valid(item):
		push_warning("StoryCards: missed item invalid")
		return
	_snap_card_back(item)


## ---- Round completion ----


func _check_round_complete() -> void:
	## Перевірити чи всі слоти заповнені
	if _placed_cards.size() < _card_count:
		_input_locked = false
		_reset_idle_timer()
		return

	## Всі слоти заповнені — запустити slideshow!
	_input_locked = true
	_play_slideshow()


func _play_slideshow() -> void:
	## "Міні-фільм": картки одна за одною збільшуються по центру з crossfade.
	_slideshow_playing = true
	_fade_instruction(_instruction_label, tr("STORY_PLAYING"))

	## Сховати оригінальні слоти та картки
	for slot: Node2D in _slot_nodes:
		if is_instance_valid(slot):
			slot.modulate.a = 0.3

	## Зібрати картки у правильному порядку
	var ordered_cards: Array[Node2D] = []
	for i: int in _card_count:
		if _placed_cards.has(i):
			ordered_cards.append(_placed_cards[i])

	if ordered_cards.size() == 0:
		push_warning("StoryCards: no ordered cards for slideshow")
		_advance_round()
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = Vector2(vp.x * 0.5, vp.y * 0.45)

	if SettingsManager.reduced_motion:
		## Без анімації — просто показати результат і перейти
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if is_instance_valid(self) and not _game_over:
				_slideshow_playing = false
				_celebrate_and_advance())
		return

	## Анімований slideshow — кожна картка виїжджає по центру
	var tw: Tween = _create_game_tween()
	for i: int in ordered_cards.size():
		var card: Node2D = ordered_cards[i]
		if not is_instance_valid(card):
			continue
		## Фаза 1: збільшити і перемістити в центр
		tw.tween_property(card, "position", center, 0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(card, "scale", Vector2(1.5, 1.5), 0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(card, "z_index", 10 + i, 0.0)
		## Тримати на екрані
		tw.tween_interval(SLIDESHOW_CARD_SEC)
		## Фаза 2: зменшити та відсунути (крім останньої)
		if i < ordered_cards.size() - 1:
			tw.tween_property(card, "scale", Vector2(0.8, 0.8), 0.2)
			tw.parallel().tween_property(card, "modulate:a", 0.3, 0.2)

	## Після slideshow — святкування
	tw.tween_interval(0.3)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self) and not _game_over:
			_slideshow_playing = false
			_celebrate_and_advance())


func _celebrate_and_advance() -> void:
	## Анімація тварини: стрибок радості
	if is_instance_valid(_animal_node) and not SettingsManager.reduced_motion:
		var atw: Tween = _create_game_tween()
		atw.tween_property(_animal_node, "position:y",
			_animal_node.position.y - 30.0, 0.15)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		atw.tween_property(_animal_node, "position:y",
			_animal_node.position.y, 0.2)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size / 2.0)
	AudioManager.play_sfx("success")

	get_tree().create_timer(CELEBRATION_DELAY).timeout.connect(func() -> void:
		if is_instance_valid(self) and not _game_over:
			_advance_round())


## ---- Animal companion ----


func _spawn_animal() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size

	## Вибрати унікальну тварину
	var animal_idx: int = -1
	var attempts: int = 0
	while attempts < 30:
		var candidate: int = randi() % maxi(GameData.ANIMALS_AND_FOOD.size(), 1)
		if not _used_animal_indices.has(candidate):
			animal_idx = candidate
			break
		attempts += 1

	## Fallback: скинути і вибрати будь-яку (A8)
	if animal_idx < 0:
		_used_animal_indices.clear()
		animal_idx = randi() % maxi(GameData.ANIMALS_AND_FOOD.size(), 1)

	if animal_idx < 0 or animal_idx >= GameData.ANIMALS_AND_FOOD.size():
		push_warning("StoryCards: invalid animal_idx %d" % animal_idx)
		return

	_used_animal_indices.append(animal_idx)
	var pair: Dictionary = GameData.ANIMALS_AND_FOOD[animal_idx]
	if not pair.has("animal_scene"):
		push_warning("StoryCards: animal pair missing animal_scene")
		return

	var scene: PackedScene = pair.get("animal_scene")
	if scene == null:
		push_warning("StoryCards: animal_scene is null")
		return

	_animal_node = scene.instantiate()
	_animal_node.scale = Vector2(ANIMAL_SCALE, ANIMAL_SCALE)
	## Тварина зліва — спостерігає за грою
	_animal_node.position = Vector2(vp.x * 0.08, vp.y * 0.45)
	_animal_node.z_index = 2
	add_child(_animal_node)
	_all_round_nodes.append(_animal_node)

	## Entrance анімація
	if not SettingsManager.reduced_motion and is_instance_valid(_animal_node):
		_animal_node.modulate.a = 0.0
		_animal_node.scale = Vector2(ANIMAL_SCALE * 0.3, ANIMAL_SCALE * 0.3)
		var atw: Tween = _create_game_tween().set_parallel(true)
		atw.tween_property(_animal_node, "modulate:a", 1.0, 0.3).set_delay(0.2)
		atw.tween_property(_animal_node, "scale",
			Vector2(ANIMAL_SCALE, ANIMAL_SCALE), 0.4)\
			.set_delay(0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## ---- Round management ----


func _advance_round() -> void:
	_record_round_errors(_round_errors_count)
	_round += 1
	if _round >= _total_rounds:
		_finish()
	else:
		_start_round()


func _clear_round_nodes() -> void:
	if _drag:
		_drag.clear_drag()
		_drag.draggable_items.clear()
		_drag.drop_targets.clear()

	## LAW 9: erase before free
	_origins.clear()
	_placed_cards.clear()

	for node: Node in _all_round_nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			node.queue_free()
	_all_round_nodes.clear()
	_slot_nodes.clear()
	_card_nodes.clear()
	_animal_node = null


func _finish() -> void:
	_game_over = true
	_input_locked = true
	if _drag:
		_drag.enabled = false

	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)

	finish_game(earned, {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": _total_rounds,
		"earned_stars": earned,
	})


## ---- Idle hint (A10) ----


func _reset_idle_timer() -> void:
	if _game_over or _slideshow_playing:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _game_over or _input_locked or _slideshow_playing:
		return
	var level: int = _advance_idle_hint()
	if level < 2:
		## Пульсація першого незайнятого слота
		for i: int in _slot_nodes.size():
			if not _placed_cards.has(i) and is_instance_valid(_slot_nodes[i]):
				_pulse_node(_slot_nodes[i], 1.2)
				break
	_reset_idle_timer()
