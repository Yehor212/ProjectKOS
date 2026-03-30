extends BaseMiniGame

## SEL-01 Зеркало емоцій / Emotion Mirror — розпізнай емоцію тварини та допоможи.
## Toddler: 3 емоції (happy/sad/scared). Перетягни правильну до тварини.
## Preschool: 4 емоції (happy/sad/angry/scared). Після правильної — вибери ДІЮ допомоги.
## 5 раундів, різні тварини та ситуації, емоції малюються кодом.

const ROUNDS_TODDLER: int = 4
const ROUNDS_PRESCHOOL: int = 5
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0
const SITUATION_DISPLAY_SEC_TODDLER: float = 4.0  ## Тоддлерам потрібно більше часу (Scherf et al.)
const SITUATION_DISPLAY_SEC_PRESCHOOL: float = 2.5
const EMOTION_CARD_SIZE: float = 100.0
const ANIMAL_DISPLAY_SCALE: float = 0.38

## Типи емоцій
enum Emotion { HAPPY, SAD, ANGRY, SCARED }

## Типи дій допомоги (Preschool)
enum HelpAction { HUG, TALK, SPACE }

## 24 ситуацій, 3 тіри складності (research: Piaget, CASEL framework).
## tier 1 = базові (раунди 1-2), tier 2 = середні (3-4), tier 3 = складні (5).
const SITUATIONS: Array[Dictionary] = [
	## ============ TIER 1: BASIC (ages 2-4) ============
	{"id": "ice_cream_dropped", "emotion": Emotion.SAD, "tier": 1,
		"best_action": HelpAction.HUG, "instruction_key": "EMOTION_SIT_ICE_CREAM",
		"icon_color": Color(0.95, 0.75, 0.85)},
	{"id": "got_a_gift", "emotion": Emotion.HAPPY, "tier": 1,
		"best_action": HelpAction.TALK, "instruction_key": "EMOTION_SIT_GIFT",
		"icon_color": Color(0.95, 0.85, 0.50)},
	{"id": "scary_thunder", "emotion": Emotion.SCARED, "tier": 1,
		"best_action": HelpAction.HUG, "instruction_key": "EMOTION_SIT_THUNDER",
		"icon_color": Color(0.60, 0.55, 0.80)},
	{"id": "found_favorite_toy", "emotion": Emotion.HAPPY, "tier": 1,
		"best_action": HelpAction.TALK, "instruction_key": "EMOTION_SIT_FOUND_TOY",
		"icon_color": Color(0.90, 0.92, 0.55)},
	{"id": "balloon_popped", "emotion": Emotion.SAD, "tier": 1,
		"best_action": HelpAction.HUG, "instruction_key": "EMOTION_SIT_BALLOON",
		"icon_color": Color(0.80, 0.70, 0.90)},
	{"id": "dark_room", "emotion": Emotion.SCARED, "tier": 1,
		"best_action": HelpAction.HUG, "instruction_key": "EMOTION_SIT_DARK_ROOM",
		"icon_color": Color(0.60, 0.60, 0.75)},
	{"id": "playing_in_puddles", "emotion": Emotion.HAPPY, "tier": 1,
		"best_action": HelpAction.TALK, "instruction_key": "EMOTION_SIT_PUDDLES",
		"icon_color": Color(0.65, 0.85, 0.95)},
	{"id": "toy_taken_away", "emotion": Emotion.ANGRY, "tier": 1,
		"best_action": HelpAction.TALK, "instruction_key": "EMOTION_SIT_TOY_TAKEN",
		"icon_color": Color(0.92, 0.68, 0.62)},
	## ============ TIER 2: INTERMEDIATE (ages 4-5) ============
	{"id": "friend_went_home", "emotion": Emotion.SAD, "tier": 2,
		"best_action": HelpAction.TALK, "instruction_key": "EMOTION_SIT_FRIEND_LEFT",
		"icon_color": Color(0.65, 0.75, 0.90)},
	{"id": "won_a_race", "emotion": Emotion.HAPPY, "tier": 2,
		"best_action": HelpAction.TALK, "instruction_key": "EMOTION_SIT_WON_RACE",
		"icon_color": Color(0.95, 0.90, 0.50)},
	{"id": "not_invited_to_play", "emotion": Emotion.SAD, "tier": 2,
		"best_action": HelpAction.HUG, "instruction_key": "EMOTION_SIT_NOT_INVITED",
		"icon_color": Color(0.72, 0.68, 0.85)},
	{"id": "someone_cut_in_line", "emotion": Emotion.ANGRY, "tier": 2,
		"best_action": HelpAction.TALK, "instruction_key": "EMOTION_SIT_CUT_LINE",
		"icon_color": Color(0.90, 0.65, 0.60)},
	{"id": "strange_shadow", "emotion": Emotion.SCARED, "tier": 2,
		"best_action": HelpAction.HUG, "instruction_key": "EMOTION_SIT_SHADOW",
		"icon_color": Color(0.62, 0.58, 0.78)},
	{"id": "helped_a_friend", "emotion": Emotion.HAPPY, "tier": 2,
		"best_action": HelpAction.HUG, "instruction_key": "EMOTION_SIT_HELPED_FRIEND",
		"icon_color": Color(0.75, 0.92, 0.72)},
	{"id": "drawing_ruined", "emotion": Emotion.SAD, "tier": 2,
		"best_action": HelpAction.TALK, "instruction_key": "EMOTION_SIT_DRAWING_RUINED",
		"icon_color": Color(0.78, 0.72, 0.88)},
	{"id": "pushed_by_someone", "emotion": Emotion.ANGRY, "tier": 2,
		"best_action": HelpAction.SPACE, "instruction_key": "EMOTION_SIT_PUSHED",
		"icon_color": Color(0.88, 0.62, 0.58)},
	## ============ TIER 3: COMPLEX (ages 5-7) ============
	{"id": "someone_else_got_prize", "emotion": Emotion.ANGRY, "tier": 3,
		"best_action": HelpAction.TALK, "instruction_key": "EMOTION_SIT_JEALOUS_PRIZE",
		"icon_color": Color(0.88, 0.70, 0.58)},
	{"id": "lost_in_new_place", "emotion": Emotion.SCARED, "tier": 3,
		"best_action": HelpAction.HUG, "instruction_key": "EMOTION_SIT_LOST_PLACE",
		"icon_color": Color(0.58, 0.55, 0.78)},
	{"id": "broke_friends_toy", "emotion": Emotion.SAD, "tier": 3,
		"best_action": HelpAction.TALK, "instruction_key": "EMOTION_SIT_BROKE_FRIEND_TOY",
		"icon_color": Color(0.75, 0.68, 0.82)},
	{"id": "shared_last_cookie", "emotion": Emotion.HAPPY, "tier": 3,
		"best_action": HelpAction.HUG, "instruction_key": "EMOTION_SIT_SHARED_COOKIE",
		"icon_color": Color(0.92, 0.88, 0.65)},
	{"id": "blamed_unfairly", "emotion": Emotion.ANGRY, "tier": 3,
		"best_action": HelpAction.SPACE, "instruction_key": "EMOTION_SIT_BLAMED",
		"icon_color": Color(0.85, 0.60, 0.55)},
	{"id": "friend_is_crying", "emotion": Emotion.SAD, "tier": 3,
		"best_action": HelpAction.HUG, "instruction_key": "EMOTION_SIT_FRIEND_CRYING",
		"icon_color": Color(0.68, 0.72, 0.88)},
	{"id": "performing_on_stage", "emotion": Emotion.SCARED, "tier": 3,
		"best_action": HelpAction.TALK, "instruction_key": "EMOTION_SIT_STAGE",
		"icon_color": Color(0.72, 0.62, 0.85)},
	{"id": "promise_broken", "emotion": Emotion.ANGRY, "tier": 3,
		"best_action": HelpAction.SPACE, "instruction_key": "EMOTION_SIT_PROMISE_BROKEN",
		"icon_color": Color(0.85, 0.65, 0.62)},
]

## Кольори емоцій (LAW 25: не лише колір — є мітки-форми та текст)
const EMOTION_COLORS: Dictionary = {
	Emotion.HAPPY: Color(0.98, 0.85, 0.30),
	Emotion.SAD: Color(0.45, 0.65, 0.90),
	Emotion.ANGRY: Color(0.90, 0.35, 0.35),
	Emotion.SCARED: Color(0.70, 0.55, 0.85),
}

const EMOTION_LABEL_KEYS: Dictionary = {
	Emotion.HAPPY: "EMOTION_HAPPY",
	Emotion.SAD: "EMOTION_SAD",
	Emotion.ANGRY: "EMOTION_ANGRY",
	Emotion.SCARED: "EMOTION_SCARED",
}

const ACTION_LABEL_KEYS: Dictionary = {
	HelpAction.HUG: "EMOTION_ACTION_HUG",
	HelpAction.TALK: "EMOTION_ACTION_TALK",
	HelpAction.SPACE: "EMOTION_ACTION_SPACE",
}

const ACTION_COLORS: Dictionary = {
	HelpAction.HUG: Color(0.95, 0.70, 0.75),
	HelpAction.TALK: Color(0.70, 0.85, 0.95),
	HelpAction.SPACE: Color(0.80, 0.90, 0.70),
}

const ANIMAL_NAMES: Array[String] = [
	"Bear", "Bunny", "Cat", "Dog", "Elephant",
	"Frog", "Lion", "Monkey", "Panda", "Penguin",
]

var _is_toddler: bool = false
var _round: int = 0
var _total_rounds: int = 0
var _start_time: float = 0.0

var _current_situation: Dictionary = {}
var _correct_emotion: int = Emotion.HAPPY
var _phase: int = 0  ## 0 = ситуація, 1 = вибір емоції, 2 = дія (Preschool)

var _animal_node: Node2D = null
var _situation_icon: Node2D = null
var _emotion_cards: Array[Node2D] = []
var _action_buttons: Array[Button] = []
var _action_panel: HBoxContainer = null
var _all_round_nodes: Array[Node] = []
var _used_situations: Array[int] = []
var _used_animals: Array[int] = []

var _drag: UniversalDrag = null
var _drop_zone: Node2D = null
var _idle_timer: SceneTreeTimer = null
var _current_round_errors: int = 0


func _ready() -> void:
	game_id = "emotion_mirror"
	bg_theme = "garden"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_drag = UniversalDrag.new(self)
	_drag.item_dropped_on_target.connect(_on_emotion_dropped)
	_drag.item_dropped_on_empty.connect(_on_emotion_missed)
	if _is_toddler:
		_drag.magnetic_assist = true
		_drag.snap_radius_override = TODDLER_SNAP_RADIUS
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func _process(delta: float) -> void:
	if _drag and not _input_locked and not _game_over:
		_drag.handle_process(delta)


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if _input_locked or _game_over:
		return
	if _phase == 1 and _drag:
		_drag.handle_input(event)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("EMOTION_TUTORIAL_TODDLER")
	return tr("EMOTION_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _emotion_cards.size() > 0 and is_instance_valid(_emotion_cards[0]):
		for card: Node2D in _emotion_cards:
			if is_instance_valid(card) and card.has_meta("emotion_type"):
				if int(card.get_meta("emotion_type")) == _correct_emotion:
					if _drop_zone and is_instance_valid(_drop_zone):
						return {
							"type": "drag",
							"from": card.global_position,
							"to": _drop_zone.global_position,
						}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_phase = 0
	_current_round_errors = 0
	_clear_round_nodes()
	_emotion_cards.clear()
	if _drag:
		_drag.clear_drag()
		_drag.draggable_items.clear()
		_drag.drop_targets.clear()

	_current_situation = _pick_situation()
	_correct_emotion = int(_current_situation.get("emotion", Emotion.HAPPY))

	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	var sit_key: String = _current_situation.get("instruction_key", "EMOTION_SIT_ICE_CREAM")
	_fade_instruction(_instruction_label, tr(sit_key))

	var animal_name: String = _pick_animal()
	_spawn_animal(animal_name)
	_spawn_situation_icon()
	_animate_situation_entrance()


func _pick_situation() -> Dictionary:
	if SITUATIONS.size() == 0:
		push_warning("EmotionMirror: SITUATIONS порожній — fallback")
		return {
			"id": "fallback", "emotion": Emotion.HAPPY, "tier": 1,
			"best_action": HelpAction.HUG, "instruction_key": "EMOTION_SIT_ICE_CREAM",
			"icon_color": Color.WHITE,
		}
	if _used_situations.size() >= SITUATIONS.size():
		_used_situations.clear()
	## Tier filtering (LAW 6: progressive difficulty, A4: difficulty ramp)
	var min_tier: int = 1
	var max_tier: int = 1
	if _is_toddler:
		max_tier = 1  ## Toddler: тільки tier 1 (базові емоції)
	else:
		if _round < 2:
			max_tier = 2  ## Preschool R1-2: tier 1-2
		else:
			max_tier = 3  ## Preschool R3+: tier 1-3
		if _round >= 3:
			min_tier = 2  ## Пізні раунди: пропустити тривіальний tier 1
	## Фільтруємо по тіру
	var available: Array[int] = []
	for i: int in SITUATIONS.size():
		if _used_situations.has(i):
			continue
		var tier: int = int(SITUATIONS[i].get("tier", 1))
		if tier >= min_tier and tier <= max_tier:
			available.append(i)
	## Fallback: якщо tier filter занадто суворий — усі невикористані (A8)
	if available.size() == 0:
		for i: int in SITUATIONS.size():
			if not _used_situations.has(i):
				available.append(i)
	## Second fallback: скинути все
	if available.size() == 0:
		push_warning("EmotionMirror: всі ситуації використані, скидаємо")
		_used_situations.clear()
		for i: int in SITUATIONS.size():
			available.append(i)
	var idx: int = available[randi() % available.size()]
	_used_situations.append(idx)
	return SITUATIONS[idx]


func _pick_animal() -> String:
	if ANIMAL_NAMES.size() == 0:
		push_warning("EmotionMirror: ANIMAL_NAMES порожній")
		return "Bear"
	if _used_animals.size() >= ANIMAL_NAMES.size():
		_used_animals.clear()
	var idx: int = randi() % ANIMAL_NAMES.size()
	var attempts: int = 0
	while _used_animals.has(idx) and attempts < ANIMAL_NAMES.size():
		idx = (idx + 1) % ANIMAL_NAMES.size()
		attempts += 1
	_used_animals.append(idx)
	return ANIMAL_NAMES[idx]


func _spawn_animal(animal_name: String) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if not ResourceLoader.exists(tex_path):
		push_warning("EmotionMirror: Missing sprite: " + tex_path)
		tex_path = "res://assets/sprites/animals/Bear.png"
		if not ResourceLoader.exists(tex_path):
			push_warning("EmotionMirror: Fallback sprite теж відсутній, skip round")
			_advance_round()
			return
	var tex: Texture2D = load(tex_path)
	if not tex:
		push_warning("EmotionMirror: текстуру '%s' не вдалося завантажити" % tex_path)
		_advance_round()
		return

	_animal_node = Node2D.new()
	_animal_node.position = Vector2(vp.x * 0.5, vp.y * 0.38)
	add_child(_animal_node)
	_all_round_nodes.append(_animal_node)

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(ANIMAL_DISPLAY_SCALE, ANIMAL_DISPLAY_SCALE)
	_animal_node.add_child(sprite)

	## Drop zone (невидимий, для drag detection)
	_drop_zone = Node2D.new()
	_drop_zone.position = _animal_node.position
	add_child(_drop_zone)
	_all_round_nodes.append(_drop_zone)
	if _drag:
		_drag.drop_targets = [_drop_zone]


func _spawn_situation_icon() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var icon_color: Color = _current_situation.get("icon_color", Color.WHITE)
	_situation_icon = Node2D.new()
	_situation_icon.position = Vector2(vp.x * 0.5 + 120.0, vp.y * 0.28)
	add_child(_situation_icon)
	_all_round_nodes.append(_situation_icon)

	## Малюємо іконку ситуації кодом (bubble з кольором)
	var bubble: Panel = Panel.new()
	var bubble_size: float = 64.0
	bubble.size = Vector2(bubble_size, bubble_size)
	bubble.position = Vector2(-bubble_size * 0.5, -bubble_size * 0.5)
	bubble.add_theme_stylebox_override("panel",
		GameData.candy_circle(icon_color, bubble_size * 0.5, false))
	bubble.material = GameData.create_premium_material(
		0.03, 2.0, 0.0, 0.0, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
	GameData.add_gloss(bubble, 8)
	_situation_icon.add_child(bubble)

	## Мітка ситуації (емоджі-like символ, LAW 25: не тільки колір)
	var sit_label: Label = Label.new()
	var sit_id: String = _current_situation.get("id", "")
	sit_label.text = _get_situation_symbol(sit_id)
	sit_label.add_theme_font_size_override("font_size", 28)
	sit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sit_label.size = Vector2(bubble_size, bubble_size)
	sit_label.position = Vector2(-bubble_size * 0.5, -bubble_size * 0.5)
	_situation_icon.add_child(sit_label)


func _get_situation_symbol(sit_id: String) -> String:
	## LAW 25: символ як вторинний канал (+ = happy, ! = sad, ~ = scared, X = angry)
	match sit_id:
		## Tier 1
		"ice_cream_dropped": return "!"
		"got_a_gift": return "+"
		"scary_thunder": return "~"
		"found_favorite_toy": return "+"
		"balloon_popped": return "!"
		"dark_room": return "~"
		"playing_in_puddles": return "+"
		"toy_taken_away": return "X"
		## Tier 2
		"friend_went_home": return "!"
		"won_a_race": return "+"
		"not_invited_to_play": return "!"
		"someone_cut_in_line": return "X"
		"strange_shadow": return "~"
		"helped_a_friend": return "+"
		"drawing_ruined": return "!"
		"pushed_by_someone": return "X"
		## Tier 3
		"someone_else_got_prize": return "X"
		"lost_in_new_place": return "~"
		"broke_friends_toy": return "!"
		"shared_last_cookie": return "+"
		"blamed_unfairly": return "X"
		"friend_is_crying": return "!"
		"performing_on_stage": return "~"
		"promise_broken": return "X"
		_: return "?"


func _animate_situation_entrance() -> void:
	if not is_instance_valid(_situation_icon):
		push_warning("EmotionMirror: _situation_icon freed before entrance")
		_show_emotion_choices()
		return

	_situation_icon.scale = Vector2.ZERO
	_situation_icon.modulate.a = 0.0

	if SettingsManager.reduced_motion:
		_situation_icon.scale = Vector2.ONE
		_situation_icon.modulate.a = 1.0
		## Затримка перед показом емоцій (A3: тоддлерам більше часу)
		var display_sec: float = SITUATION_DISPLAY_SEC_TODDLER if _is_toddler else SITUATION_DISPLAY_SEC_PRESCHOOL
		get_tree().create_timer(display_sec).timeout.connect(func() -> void:
			if is_instance_valid(self) and not _game_over:
				_show_emotion_choices())
		return

	var tw: Tween = _create_game_tween()
	tw.set_parallel(true)
	tw.tween_property(_situation_icon, "scale", Vector2(1.2, 1.2), ANIM_NORMAL)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_situation_icon, "modulate:a", 1.0, ANIM_FAST)
	tw.chain().tween_property(_situation_icon, "scale", Vector2.ONE, ANIM_FAST)
	var display_sec: float = SITUATION_DISPLAY_SEC_TODDLER if _is_toddler else SITUATION_DISPLAY_SEC_PRESCHOOL
	tw.chain().tween_interval(display_sec)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(self) and not _game_over:
			_show_emotion_choices())


func _show_emotion_choices() -> void:
	_phase = 1
	_fade_instruction(_instruction_label, tr("EMOTION_PICK_FEELING"))
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var emotions: Array[int] = _get_emotions_for_round()

	## Позиціонування карточок внизу
	var total_width: float = float(emotions.size()) * (EMOTION_CARD_SIZE + 20.0) - 20.0
	var start_x: float = (vp.x - total_width) * 0.5 + EMOTION_CARD_SIZE * 0.5
	var card_y: float = vp.y * 0.78

	for i: int in emotions.size():
		var emo: int = emotions[i]
		var card: Node2D = _create_emotion_card(emo)
		card.position = Vector2(start_x + float(i) * (EMOTION_CARD_SIZE + 20.0), card_y)
		card.set_meta("emotion_type", emo)
		card.set_meta("origin_pos", card.position)
		add_child(card)
		_emotion_cards.append(card)
		_all_round_nodes.append(card)

	if _drag:
		_drag.draggable_items = _emotion_cards.duplicate()
		## Correct pairs для magnetic assist (Toddler)
		if _is_toddler and _drop_zone:
			var pairs: Dictionary = {}
			for card: Node2D in _emotion_cards:
				if is_instance_valid(card) and card.has_meta("emotion_type"):
					if int(card.get_meta("emotion_type")) == _correct_emotion:
						pairs[card] = _drop_zone
			_drag.set_correct_pairs(pairs)

	_orchestrated_entrance(_emotion_cards, 0.08, true)
	_reset_idle_timer()


func _get_emotions_for_round() -> Array[int]:
	var result: Array[int] = []
	## Завжди включаємо правильну емоцію
	result.append(_correct_emotion)

	if _is_toddler:
		## Toddler: 3 емоції (LAW 2: мінімум 3 вибори)
		var pool: Array[int] = [Emotion.HAPPY, Emotion.SAD, Emotion.SCARED]
		pool.erase(_correct_emotion)
		pool.shuffle()
		while result.size() < 3 and pool.size() > 0:
			result.append(pool.pop_back())
	else:
		## Preschool: 4 емоції (всі)
		var pool: Array[int] = [Emotion.HAPPY, Emotion.SAD, Emotion.ANGRY, Emotion.SCARED]
		pool.erase(_correct_emotion)
		pool.shuffle()
		while result.size() < 4 and pool.size() > 0:
			result.append(pool.pop_back())

	## Перемішуємо щоб правильна не завжди першою
	result.shuffle()
	return result


func _create_emotion_card(emo: int) -> Node2D:
	var card: Node2D = Node2D.new()
	var s: float = _ui_scale()
	var card_size: float = EMOTION_CARD_SIZE * s

	## Фон картки
	var bg_panel: Panel = Panel.new()
	bg_panel.size = Vector2(card_size, card_size)
	bg_panel.position = Vector2(-card_size * 0.5, -card_size * 0.5)
	var emo_color: Color = EMOTION_COLORS.get(emo, Color.WHITE)
	bg_panel.add_theme_stylebox_override("panel",
		GameData.candy_circle(emo_color, card_size * 0.5, false))
	bg_panel.material = GameData.create_premium_material(
		0.03, 2.0, 0.0, 0.0, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
	GameData.add_gloss(bg_panel, 8)
	card.add_child(bg_panel)

	## Малюємо обличчя емоції кодом (очі + рот + брови)
	var face_node: Node2D = Node2D.new()
	face_node.name = "Face"
	card.add_child(face_node)
	_draw_emotion_face(face_node, emo, card_size)

	## Текстова мітка під карткою (LAW 25: не лише колір, є текст)
	var label_key: String = EMOTION_LABEL_KEYS.get(emo, "EMOTION_HAPPY")
	var lbl: Label = Label.new()
	lbl.text = tr(label_key)
	lbl.add_theme_font_size_override("font_size", int(16.0 * s))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(card_size, 24.0 * s)
	lbl.position = Vector2(-card_size * 0.5, card_size * 0.45)
	card.add_child(lbl)

	return card


func _draw_emotion_face(parent: Node2D, emo: int, card_size: float) -> void:
	var eye_r: float = card_size * 0.06
	var eye_spacing: float = card_size * 0.15
	var eye_y: float = -card_size * 0.08

	## Ліве око
	var left_eye: Panel = Panel.new()
	left_eye.size = Vector2(eye_r * 2.0, eye_r * 2.0)
	left_eye.position = Vector2(-eye_spacing - eye_r, eye_y - eye_r)
	left_eye.add_theme_stylebox_override("panel",
		GameData.candy_circle(Color(0.15, 0.15, 0.15), eye_r, false))
	parent.add_child(left_eye)

	## Праве око
	var right_eye: Panel = Panel.new()
	right_eye.size = Vector2(eye_r * 2.0, eye_r * 2.0)
	right_eye.position = Vector2(eye_spacing - eye_r, eye_y - eye_r)
	right_eye.add_theme_stylebox_override("panel",
		GameData.candy_circle(Color(0.15, 0.15, 0.15), eye_r, false))
	parent.add_child(right_eye)

	## Scared: овальні очі (більші)
	if emo == Emotion.SCARED:
		left_eye.size = Vector2(eye_r * 2.5, eye_r * 3.0)
		left_eye.position = Vector2(-eye_spacing - eye_r * 1.25, eye_y - eye_r * 1.5)
		right_eye.size = Vector2(eye_r * 2.5, eye_r * 3.0)
		right_eye.position = Vector2(eye_spacing - eye_r * 1.25, eye_y - eye_r * 1.5)

	## Рот
	var mouth_y: float = card_size * 0.1
	var mouth_w: float = card_size * 0.2
	var mouth_h: float = card_size * 0.06

	var mouth: Panel = Panel.new()
	match emo:
		Emotion.HAPPY:
			## Посмішка — широка дуга (імітація через rounded rect знизу)
			mouth.size = Vector2(mouth_w, mouth_h * 2.0)
			mouth.position = Vector2(-mouth_w * 0.5, mouth_y)
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = Color(0.15, 0.15, 0.15)
			sb.corner_radius_bottom_left = int(mouth_w * 0.5)
			sb.corner_radius_bottom_right = int(mouth_w * 0.5)
			sb.corner_radius_top_left = 0
			sb.corner_radius_top_right = 0
			mouth.add_theme_stylebox_override("panel", sb)
		Emotion.SAD:
			## Перевернута дуга (вигнутий вниз)
			mouth.size = Vector2(mouth_w, mouth_h * 2.0)
			mouth.position = Vector2(-mouth_w * 0.5, mouth_y + mouth_h)
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = Color(0.15, 0.15, 0.15)
			sb.corner_radius_top_left = int(mouth_w * 0.5)
			sb.corner_radius_top_right = int(mouth_w * 0.5)
			sb.corner_radius_bottom_left = 0
			sb.corner_radius_bottom_right = 0
			mouth.add_theme_stylebox_override("panel", sb)
		Emotion.ANGRY:
			## Злий рот — маленький прямокутник
			mouth.size = Vector2(mouth_w * 0.7, mouth_h)
			mouth.position = Vector2(-mouth_w * 0.35, mouth_y + mouth_h * 0.5)
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = Color(0.15, 0.15, 0.15)
			sb.corner_radius_top_left = 2
			sb.corner_radius_top_right = 2
			sb.corner_radius_bottom_left = 2
			sb.corner_radius_bottom_right = 2
			mouth.add_theme_stylebox_override("panel", sb)
		Emotion.SCARED:
			## О-подібний рот (круглий)
			var o_size: float = mouth_h * 2.5
			mouth.size = Vector2(o_size, o_size)
			mouth.position = Vector2(-o_size * 0.5, mouth_y)
			mouth.add_theme_stylebox_override("panel",
				GameData.candy_circle(Color(0.15, 0.15, 0.15), o_size * 0.5, false))
	parent.add_child(mouth)

	## Брови
	var brow_w: float = card_size * 0.12
	var brow_h: float = card_size * 0.025
	var brow_y: float = eye_y - eye_r * 2.5

	if emo == Emotion.ANGRY:
		## Нахилені брови (злість) — V-форма через 2 прямокутники
		var left_brow: Panel = Panel.new()
		left_brow.size = Vector2(brow_w, brow_h)
		left_brow.position = Vector2(-eye_spacing - brow_w * 0.5, brow_y)
		left_brow.rotation = 0.3
		left_brow.add_theme_stylebox_override("panel", _flat_rect(Color(0.15, 0.15, 0.15)))
		parent.add_child(left_brow)

		var right_brow: Panel = Panel.new()
		right_brow.size = Vector2(brow_w, brow_h)
		right_brow.position = Vector2(eye_spacing - brow_w * 0.5, brow_y)
		right_brow.rotation = -0.3
		right_brow.add_theme_stylebox_override("panel", _flat_rect(Color(0.15, 0.15, 0.15)))
		parent.add_child(right_brow)
	elif emo == Emotion.SAD:
		## Піднесені брови (сум) — ^-форма
		var left_brow: Panel = Panel.new()
		left_brow.size = Vector2(brow_w, brow_h)
		left_brow.position = Vector2(-eye_spacing - brow_w * 0.5, brow_y)
		left_brow.rotation = -0.25
		left_brow.add_theme_stylebox_override("panel", _flat_rect(Color(0.15, 0.15, 0.15)))
		parent.add_child(left_brow)

		var right_brow: Panel = Panel.new()
		right_brow.size = Vector2(brow_w, brow_h)
		right_brow.position = Vector2(eye_spacing - brow_w * 0.5, brow_y)
		right_brow.rotation = 0.25
		right_brow.add_theme_stylebox_override("panel", _flat_rect(Color(0.15, 0.15, 0.15)))
		parent.add_child(right_brow)
	elif emo == Emotion.SCARED:
		## Підняті рівні брови (страх)
		var left_brow: Panel = Panel.new()
		left_brow.size = Vector2(brow_w, brow_h)
		left_brow.position = Vector2(-eye_spacing - brow_w * 0.5, brow_y - brow_h)
		left_brow.add_theme_stylebox_override("panel", _flat_rect(Color(0.15, 0.15, 0.15)))
		parent.add_child(left_brow)

		var right_brow: Panel = Panel.new()
		right_brow.size = Vector2(brow_w, brow_h)
		right_brow.position = Vector2(eye_spacing - brow_w * 0.5, brow_y - brow_h)
		right_brow.add_theme_stylebox_override("panel", _flat_rect(Color(0.15, 0.15, 0.15)))
		parent.add_child(right_brow)


func _flat_rect(c: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = c
	return sb


## ---- Drag callbacks ----

func _on_emotion_dropped(item: Node2D, _target: Node2D) -> void:
	if _phase != 1 or _game_over:
		return
	_input_locked = true
	if _drag:
		_drag.enabled = false

	var chosen_emo: int = int(item.get_meta("emotion_type", -1))
	if chosen_emo == _correct_emotion:
		_handle_correct_emotion(item)
	else:
		_handle_wrong_emotion(item)


func _on_emotion_missed(item: Node2D) -> void:
	if _phase != 1 or _game_over:
		return
	## Snap back до оригінальної позиції
	var origin: Vector2 = item.get_meta("origin_pos", item.position) as Vector2
	if _drag:
		_drag.snap_back(item, origin)
	_reset_idle_timer()


func _handle_correct_emotion(card: Node2D) -> void:
	_consecutive_errors = 0
	_streak_count += 1
	_play_round_celebration(card.global_position)

	## Тварина киває (підтвердження)
	_animate_animal_nod()

	## Записуємо спробу (correct)
	MasteryManager.record_attempt(game_id, "emotional_recognition", true)

	if _is_toddler:
		## Toddler: одразу наступний раунд
		var tw: Tween = _create_game_tween()
		tw.tween_interval(CELEBRATION_DELAY)
		tw.tween_callback(func() -> void:
			if is_instance_valid(self) and not _game_over:
				_advance_round())
	else:
		## Preschool: фаза дій допомоги
		var tw: Tween = _create_game_tween()
		tw.tween_interval(ROUND_DELAY)
		tw.tween_callback(func() -> void:
			if is_instance_valid(self) and not _game_over:
				_show_action_phase())


func _handle_wrong_emotion(card: Node2D) -> void:
	_current_round_errors += 1
	if not _is_toddler:
		_errors += 1
	_register_error(card)

	## Записуємо спробу (помилка)
	MasteryManager.record_attempt(game_id, "emotional_recognition", false)

	## Тварина хитає головою (ні)
	_animate_animal_head_shake()

	## Snap back
	var origin: Vector2 = card.get_meta("origin_pos", card.position) as Vector2
	if _drag:
		_drag.snap_back(card, origin)

	## Розблокувати input для наступної спроби
	var tw: Tween = _create_game_tween()
	tw.tween_interval(ANIM_SLOW)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self) and not _game_over:
			_input_locked = false
			if _drag:
				_drag.enabled = true
			_reset_idle_timer())


## ---- Action phase (Preschool) ----

func _show_action_phase() -> void:
	_phase = 2
	_fade_instruction(_instruction_label, tr("EMOTION_PICK_ACTION"))

	## Прибираємо картки емоцій
	for card: Node2D in _emotion_cards:
		if is_instance_valid(card):
			var tw: Tween = _create_game_tween()
			tw.tween_property(card, "modulate:a", 0.0, ANIM_FAST)
			tw.tween_callback(card.queue_free)
	_emotion_cards.clear()

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var s: float = _ui_scale()
	_action_panel = HBoxContainer.new()
	_action_panel.set("theme_override_constants/separation", int(16.0 * s))
	var panel_w: float = 320.0 * s
	_action_panel.position = Vector2((vp.x - panel_w) * 0.5, vp.y * 0.72)
	_action_panel.z_index = 5
	add_child(_action_panel)
	_all_round_nodes.append(_action_panel)

	var actions: Array[int] = [HelpAction.HUG, HelpAction.TALK, HelpAction.SPACE]
	_action_buttons.clear()

	for act: int in actions:
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(90.0 * s, 80.0 * s)
		var key: String = ACTION_LABEL_KEYS.get(act, "EMOTION_ACTION_HUG")
		btn.text = tr(key)
		btn.add_theme_font_size_override("font_size", int(16.0 * s))
		var act_color: Color = ACTION_COLORS.get(act, Color.WHITE)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = act_color
		sb.corner_radius_top_left = 16
		sb.corner_radius_top_right = 16
		sb.corner_radius_bottom_left = 16
		sb.corner_radius_bottom_right = 16
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		sb.content_margin_top = 8.0
		sb.content_margin_bottom = 8.0
		btn.add_theme_stylebox_override("normal", sb)
		btn.material = GameData.create_premium_material(
			0.03, 2.0, 0.0, 0.0, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
		var action_type: int = act
		btn.pressed.connect(_on_action_selected.bind(action_type))
		_action_panel.add_child(btn)
		_action_buttons.append(btn)
		JuicyEffects.button_press_squish(btn, self)

	_orchestrated_entrance(_action_buttons, 0.08, true)
	_reset_idle_timer()


func _on_action_selected(action: int) -> void:
	if _phase != 2 or _input_locked or _game_over:
		return
	_input_locked = true
	AudioManager.play_sfx("click")

	var best: int = int(_current_situation.get("best_action", HelpAction.HUG))
	if action == best:
		_play_round_celebration(_animal_node.global_position if is_instance_valid(_animal_node) else get_viewport().get_visible_rect().size * 0.5)
		_animate_animal_nod()
		MasteryManager.record_attempt(game_id, "empathy_action", true)
	else:
		## Не найкраща дія, але все одно прийнятно (м'який feedback)
		## Не рахуємо як помилку — дії всі "хороші", просто одна найкраща
		AudioManager.play_sfx("bounce")
		MasteryManager.record_attempt(game_id, "empathy_action", false)
		## Підсвітити найкращу дію
		_highlight_best_action(best)

	var tw: Tween = _create_game_tween()
	tw.tween_interval(CELEBRATION_DELAY)
	tw.tween_callback(func() -> void:
		if is_instance_valid(self) and not _game_over:
			_advance_round())


func _highlight_best_action(best: int) -> void:
	var actions: Array[int] = [HelpAction.HUG, HelpAction.TALK, HelpAction.SPACE]
	for i: int in mini(actions.size(), _action_buttons.size()):
		if not is_instance_valid(_action_buttons[i]):
			continue
		if actions[i] == best:
			var tw: Tween = _create_game_tween()
			tw.tween_property(_action_buttons[i], "modulate",
				Color(1.0, 1.0, 0.7, 1.0), ANIM_FAST)
			tw.tween_property(_action_buttons[i], "modulate",
				Color.WHITE, ANIM_NORMAL)
		else:
			_action_buttons[i].modulate = Color(0.6, 0.6, 0.6, 0.7)


## ---- Animal animations ----

func _animate_animal_nod() -> void:
	if not is_instance_valid(_animal_node):
		push_warning("EmotionMirror: _animal_node freed before nod")
		return
	if SettingsManager.reduced_motion:
		return
	var tw: Tween = _create_game_tween()
	tw.tween_property(_animal_node, "position:y",
		_animal_node.position.y - 15.0, 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_animal_node, "position:y",
		_animal_node.position.y, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_animal_node, "position:y",
		_animal_node.position.y - 8.0, 0.10)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_animal_node, "position:y",
		_animal_node.position.y, 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _animate_animal_head_shake() -> void:
	if not is_instance_valid(_animal_node):
		push_warning("EmotionMirror: _animal_node freed before head shake")
		return
	if SettingsManager.reduced_motion:
		return
	var tw: Tween = _create_game_tween()
	var orig_x: float = _animal_node.position.x
	tw.tween_property(_animal_node, "position:x", orig_x - 10.0, 0.06)
	tw.tween_property(_animal_node, "position:x", orig_x + 10.0, 0.12)
	tw.tween_property(_animal_node, "position:x", orig_x - 6.0, 0.10)
	tw.tween_property(_animal_node, "position:x", orig_x, 0.08)


## ---- Round management ----

func _advance_round() -> void:
	_round_errors.append(_current_round_errors)
	_round += 1
	if _round >= _total_rounds:
		_finish()
	else:
		_start_round()


func _clear_round_nodes() -> void:
	if _drag:
		_drag.clear_drag()
	for node: Node in _all_round_nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			node.queue_free()
	_all_round_nodes.clear()
	_action_buttons.clear()
	_emotion_cards.clear()
	_animal_node = null
	_situation_icon = null
	_drop_zone = null
	_action_panel = null


func _finish() -> void:
	_game_over = true
	_input_locked = true
	if _drag:
		_drag.clear_drag()
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": _total_rounds, "earned_stars": earned})


## ---- Idle hint (A10) ----

func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _game_over or _input_locked:
		return
	var level: int = _advance_idle_hint()
	if level < 2 and _phase == 1:
		## Пульсація правильної картки
		for card: Node2D in _emotion_cards:
			if is_instance_valid(card) and card.has_meta("emotion_type"):
				if int(card.get_meta("emotion_type")) == _correct_emotion:
					if not SettingsManager.reduced_motion:
						var tw: Tween = _create_game_tween()
						tw.tween_property(card, "scale", Vector2(1.15, 1.15), 0.3)\
							.set_trans(Tween.TRANS_SINE)
						tw.tween_property(card, "scale", Vector2.ONE, 0.3)\
							.set_trans(Tween.TRANS_SINE)
					break
	_reset_idle_timer()


func _on_exit_pause() -> void:
	if _drag:
		_drag.clear_drag()
