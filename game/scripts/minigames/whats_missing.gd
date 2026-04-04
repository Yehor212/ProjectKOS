extends BaseMiniGame

## "Хто Сховався?" / "Who's Missing?"
## Візуальна робоча пам'ять — Cowan 2001: WM = 3-4 items for ages 5-7.
## PMC 2016: WM training generalizes to non-trained cognitive tasks.
##
## Тварини грають у хованки в парку. Одна тварина тікає.
## Дитина запам'ятовує хто був → знаходить хто зник.
##
## Toddler (2-4): 3 тварини → 1 зникає → тап з 3 варіантів (Cowan: WM=2 for 2-4yo)
## Preschool (4-7): 4-6 тварин → 1 зникає → тап з 4-6 варіантів + дистрактори

const ROUNDS_TODDLER: int = 5
const ROUNDS_PRESCHOOL: int = 6
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0

## Кількість тварин на екрані по раундах (LAW 6: progressive difficulty)
## Toddler: Cowan WM=2 for 2-4yo → start with 3 items (1 to remember)
const TODDLER_COUNTS: Array[int] = [3, 3, 3, 4, 4]
## Preschool: Cowan WM=3-4 for 5-7yo → 4 to 6 items
const PRESCHOOL_COUNTS: Array[int] = [4, 4, 5, 5, 6, 6]

## Час показу тварин (секунди) — зменшується з раундами (A4)
const SHOW_DURATION_TODDLER_EASY: float = 4.0
const SHOW_DURATION_TODDLER_HARD: float = 3.0
const SHOW_DURATION_PRESCHOOL_EASY: float = 3.5
const SHOW_DURATION_PRESCHOOL_HARD: float = 2.0

## Кількість дистракторів у відповіді (Preschool only — зростає з раундами)
const PRESCHOOL_DISTRACTORS: Array[int] = [0, 0, 1, 1, 1, 2]

## Розміри
const ITEM_SIZE_TODDLER: float = 130.0   ## Vatavu 2015: 150px+ for ages 2-4
const ITEM_SIZE_PRESCHOOL: float = 100.0  ## Nacher 2015: 120px+ for ages 4-7
const ANSWER_SIZE_TODDLER: float = 120.0
const ANSWER_SIZE_PRESCHOOL: float = 90.0
const ANSWER_Y_OFFSET: float = 0.78  ## Відсоток від viewport height
const GRID_PADDING: float = 20.0

## Тварини — шлях до PNG спрайтів (19 тварин з GameData)
const ANIMAL_SPRITES: Array[String] = [
	"res://assets/sprites/animals/Bear.png",
	"res://assets/sprites/animals/Bunny.png",
	"res://assets/sprites/animals/Cat.png",
	"res://assets/sprites/animals/Chicken.png",
	"res://assets/sprites/animals/Cow.png",
	"res://assets/sprites/animals/Crocodile.png",
	"res://assets/sprites/animals/Deer.png",
	"res://assets/sprites/animals/Dog.png",
	"res://assets/sprites/animals/Elephant.png",
	"res://assets/sprites/animals/Frog.png",
	"res://assets/sprites/animals/Goat.png",
	"res://assets/sprites/animals/Hedgehog.png",
	"res://assets/sprites/animals/Horse.png",
	"res://assets/sprites/animals/Lion.png",
	"res://assets/sprites/animals/Monkey.png",
	"res://assets/sprites/animals/Mouse.png",
	"res://assets/sprites/animals/Panda.png",
	"res://assets/sprites/animals/Penguin.png",
	"res://assets/sprites/animals/Squirrel.png",
]

## Кольори фонів для item slots (LAW 25: не тільки колір, а й форма)
const SLOT_BG_COLOR: Color = Color("e8f5e9", 0.7)
const SLOT_MISSING_COLOR: Color = Color("fff3e0", 0.8)
const ANSWER_BG_COLOR: Color = Color("e3f2fd", 0.6)
const ANSWER_CORRECT_COLOR: Color = Color("c8e6c9")
const ANSWER_WRONG_COLOR: Color = Color("ffcdd2")
const CLOUD_COLOR: Color = Color("90a4ae", 0.85)

## Стан гри
var _is_toddler: bool = false
var _round: int = 0
var _total_rounds: int = 0
var _start_time: float = 0.0
var _current_animals: Array[int] = []  ## Індекси в ANIMAL_SPRITES
var _missing_idx: int = -1  ## Який індекс зник
var _missing_pos: int = -1  ## Яка позиція в _current_animals
var _answer_nodes: Array[Node2D] = []
var _grid_nodes: Array[Node2D] = []
var _cloud_node: Node2D = null
var _phase: String = "show"  ## show → hide → answer → celebrate
var _textures: Dictionary = {}  ## Кеш текстур
var _all_round_nodes: Array[Node] = []


func _ready() -> void:
	game_id = "whats_missing"
	_skill_id = "visual_memory"
	bg_theme = "garden"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_preload_textures()
	_apply_background()
	_build_instruction_pill(get_tutorial_instruction())
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("WHATS_MISSING_TUTORIAL_T")
	return tr("WHATS_MISSING_TUTORIAL_P")


func get_tutorial_demo() -> Dictionary:
	if _answer_nodes.size() > 0:
		for node: Node2D in _answer_nodes:
			if is_instance_valid(node) and node.get_meta("is_correct", false):
				return {"type": "tap", "target": node.global_position}
	return {}


## Кешуємо текстури (preload pattern — LAW 23: no load() in _process)
func _preload_textures() -> void:
	for i: int in ANIMAL_SPRITES.size():
		var path: String = ANIMAL_SPRITES[i]
		if ResourceLoader.exists(path):
			_textures[i] = load(path)
		else:
			push_warning("WhatsMissing: Missing sprite: " + path)


## ========== ROUND LIFECYCLE ==========

func _start_round() -> void:
	_phase = "show"
	_input_locked = true
	_cleanup_round()

	var vp: Vector2 = get_viewport().get_visible_rect().size

	## Обрати тварин для цього раунду
	var counts: Array[int] = TODDLER_COUNTS if _is_toddler else PRESCHOOL_COUNTS
	var count: int = counts[mini(_round, counts.size() - 1)]
	_current_animals = _pick_random_animals(count)

	## Обрати хто зникне
	_missing_pos = randi() % _current_animals.size()
	_missing_idx = _current_animals[_missing_pos]

	## Показати тварин на екрані
	_spawn_grid(vp, count)

	## Дихальна анімація під час показу (A10: idle → pulse)
	_start_item_breathing()

	## Оновити інструкцію
	_update_progress()
	_fade_instruction(_instruction_label, tr("WHATS_MISSING_MEMORIZE"))

	## Час показу: adaptive (LAW 6)
	var show_time: float
	if _is_toddler:
		show_time = _scale_adaptive(SHOW_DURATION_TODDLER_EASY,
			SHOW_DURATION_TODDLER_HARD, _round, _total_rounds)
	else:
		show_time = _scale_adaptive(SHOW_DURATION_PRESCHOOL_EASY,
			SHOW_DURATION_PRESCHOOL_HARD, _round, _total_rounds)

	## Таймер: після показу — ховаємо
	var timer: SceneTreeTimer = get_tree().create_timer(show_time)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and not _game_finished:
			_hide_phase(vp))


func _hide_phase(vp: Vector2) -> void:
	_phase = "hide"
	_fade_instruction(_instruction_label, tr("WHATS_MISSING_HIDING"))
	## Хмара закриває екран (LAW 28: premium transition)
	_cloud_node = Node2D.new()
	_cloud_node.z_index = 5
	_cloud_node.position = Vector2(vp.x * 0.5, vp.y * 0.4)
	_cloud_node.scale = Vector2(0.1, 0.1)
	_cloud_node.modulate = Color(1, 1, 1, 0)
	var vp_ref: Vector2 = vp
	_cloud_node.draw.connect(func() -> void:
		## Велика хмара з кількох кіл
		for j: int in 5:
			var cx: float = float(j - 2) * vp_ref.x * 0.18
			var cy: float = sin(float(j) * 0.9) * 30.0
			_cloud_node.draw_circle(Vector2(cx, cy), vp_ref.y * 0.35, CLOUD_COLOR))
	add_child(_cloud_node)
	_all_round_nodes.append(_cloud_node)

	var tw: Tween = _create_game_tween()
	tw.tween_property(_cloud_node, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_cloud_node, "modulate:a", 1.0, 0.3)

	## Після хмари — прибрати зниклу тварину і показати відповіді
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self) or _game_finished:
			return
		_remove_missing_animal()
		## Хмара відкривається
		var tw2: Tween = _create_game_tween()
		tw2.tween_property(_cloud_node, "scale", Vector2(0.05, 0.05), 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw2.parallel().tween_property(_cloud_node, "modulate:a", 0.0, 0.3)
		tw2.tween_callback(func() -> void:
			if not is_instance_valid(self) or _game_finished:
				return
			if is_instance_valid(_cloud_node):
				_cloud_node.queue_free()
			_answer_phase(vp)))


func _remove_missing_animal() -> void:
	## Прибрати тварину з grid + показати "?" на її місці
	if _missing_pos >= 0 and _missing_pos < _grid_nodes.size():
		var node: Node2D = _grid_nodes[_missing_pos]
		if is_instance_valid(node):
			## Замінити на знак "?" (порожній слот)
			for child: Node in node.get_children():
				child.queue_free()
			var item_sz: float = ITEM_SIZE_TODDLER if _is_toddler else ITEM_SIZE_PRESCHOOL
			var q_label: Label = Label.new()
			q_label.text = "?"
			q_label.add_theme_font_size_override("font_size", int(item_sz * 0.6))
			q_label.add_theme_color_override("font_color", Color("ff8a65"))
			q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			q_label.size = Vector2(item_sz, item_sz)
			q_label.position = Vector2(-item_sz * 0.5, -item_sz * 0.5)
			node.add_child(q_label)
			## Пульсація на порожньому слоті
			if not SettingsManager.reduced_motion:
				var pw: Tween = _create_game_tween()
				pw.set_loops()
				pw.tween_property(node, "scale", Vector2(1.05, 1.05), 0.6) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				pw.tween_property(node, "scale", Vector2.ONE, 0.6) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _answer_phase(vp: Vector2) -> void:
	_phase = "answer"
	_fade_instruction(_instruction_label, tr("WHATS_MISSING_WHO"))

	## Побудувати лінійку відповідей внизу
	var answer_sz: float = ANSWER_SIZE_TODDLER if _is_toddler else ANSWER_SIZE_PRESCHOOL

	## Варіанти: всі тварини раунду + дистрактори (Preschool)
	var answer_indices: Array[int] = _current_animals.duplicate()
	if not _is_toddler:
		var distractor_counts: Array[int] = PRESCHOOL_DISTRACTORS
		var num_distractors: int = distractor_counts[mini(_round, distractor_counts.size() - 1)]
		var available: Array[int] = []
		for i: int in ANIMAL_SPRITES.size():
			if not _current_animals.has(i):
				available.append(i)
		available.shuffle()
		for d: int in mini(num_distractors, available.size()):
			answer_indices.append(available[d])
	answer_indices.shuffle()

	var total_w: float = float(answer_indices.size()) * (answer_sz + GRID_PADDING)
	var start_x: float = (vp.x - total_w) * 0.5 + answer_sz * 0.5
	var answer_y: float = vp.y * ANSWER_Y_OFFSET

	for i: int in answer_indices.size():
		var idx: int = answer_indices[i]
		var node: Node2D = _create_answer_item(idx, answer_sz, idx == _missing_idx)
		node.position = Vector2(start_x + float(i) * (answer_sz + GRID_PADDING), answer_y)
		## Entrance animation — pop in from below
		node.position.y += 80.0
		node.modulate = Color(1, 1, 1, 0)
		add_child(node)
		_answer_nodes.append(node)
		_all_round_nodes.append(node)
		if not SettingsManager.reduced_motion:
			var tw: Tween = _create_game_tween()
			tw.tween_property(node, "position:y", answer_y, 0.3) \
				.set_delay(float(i) * 0.08) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(node, "modulate:a", 1.0, 0.2) \
				.set_delay(float(i) * 0.08)
	## Unlock input after all answers animate in
	var unlock_delay: float = float(answer_indices.size()) * 0.08 + 0.3
	get_tree().create_timer(unlock_delay).timeout.connect(func() -> void:
		if is_instance_valid(self) and not _game_finished:
			_input_locked = false)
	_start_idle_timer()


## ========== INPUT ==========

func _input(event: InputEvent) -> void:
	if _input_locked or _game_finished or _phase != "answer":
		return
	var pos: Vector2 = Vector2.ZERO
	var tapped: bool = false
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
		pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and event.pressed and event.index == 0:
		tapped = true
		pos = (event as InputEventScreenTouch).position
	if not tapped:
		return
	_reset_idle_timer()
	var answer_sz: float = ANSWER_SIZE_TODDLER if _is_toddler else ANSWER_SIZE_PRESCHOOL
	var tap_r: float = answer_sz * 0.6  ## Generous tap zone
	for node: Node2D in _answer_nodes:
		if not is_instance_valid(node) or node.get_meta("used", false):
			continue
		if pos.distance_to(node.global_position) <= tap_r:
			_handle_answer_tap(node)
			return


func _handle_answer_tap(node: Node2D) -> void:
	_input_locked = true
	var is_correct: bool = node.get_meta("is_correct", false)
	if is_correct:
		_handle_correct_answer(node)
	else:
		_handle_wrong_answer(node)


func _handle_correct_answer(node: Node2D) -> void:
	_phase = "celebrate"
	node.set_meta("used", true)
	_register_correct(node)
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()

	## Тварина повертається на своє місце
	if _missing_pos >= 0 and _missing_pos < _grid_nodes.size():
		var grid_node: Node2D = _grid_nodes[_missing_pos]
		if is_instance_valid(grid_node):
			## Прибрати "?" і показати тварину назад
			for child: Node in grid_node.get_children():
				child.queue_free()
			_add_animal_sprite_to_node(grid_node, _missing_idx,
				ITEM_SIZE_TODDLER if _is_toddler else ITEM_SIZE_PRESCHOOL)
			## Bounce анімація повернення
			grid_node.scale = Vector2(0.3, 0.3)
			var tw: Tween = _create_game_tween()
			tw.tween_property(grid_node, "scale", Vector2(1.1, 1.1), 0.25) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(grid_node, "scale", Vector2.ONE, 0.15)

	## Sparkle на правильній відповіді
	VFXManager.spawn_correct_sparkle(node.global_position)

	## Наступний раунд або завершення
	get_tree().create_timer(CELEBRATION_DELAY).timeout.connect(func() -> void:
		if not is_instance_valid(self) or _game_finished:
			return
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round())


func _handle_wrong_answer(node: Node2D) -> void:
	node.set_meta("used", true)
	_register_error(node)

	## Прибрати неправильну відповідь (fade out)
	var tw: Tween = _create_game_tween()
	tw.tween_property(node, "modulate:a", 0.3, 0.2)

	## Scaffolding: Toddler 2 errors, Preschool 3 errors → show answer (A11)
	var scaffold_threshold: int = 2 if _is_toddler else 3
	if _consecutive_errors >= scaffold_threshold:
		_show_correct_answer()
	else:
		_input_locked = false


func _show_correct_answer() -> void:
	## Підсвітити правильну відповідь (A11: scaffolding)
	for node: Node2D in _answer_nodes:
		if not is_instance_valid(node):
			continue
		if node.get_meta("is_correct", false):
			## Пульсація + підсвітка
			var tw: Tween = _create_game_tween()
			tw.tween_property(node, "scale", Vector2(1.2, 1.2), 0.2)
			tw.tween_property(node, "scale", Vector2.ONE, 0.2)
			tw.tween_property(node, "scale", Vector2(1.2, 1.2), 0.2)
			tw.tween_callback(func() -> void:
				if is_instance_valid(self) and not _game_finished:
					_handle_correct_answer(node))
			return


func _finish() -> void:
	_game_over = true
	var time_sec: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var stars: int = _calculate_stars(_errors)
	_current_animal_name = ""  ## Немає конкретної тварини
	finish_game(stars, {
		"time_sec": time_sec,
		"errors": _errors,
		"rounds_played": _round,
		"earned_stars": stars,
	})


## ========== VISUAL CONSTRUCTION ==========

func _spawn_grid(vp: Vector2, count: int) -> void:
	var item_sz: float = ITEM_SIZE_TODDLER if _is_toddler else ITEM_SIZE_PRESCHOOL
	## Розрахунок сітки — центрування в верхній 2/3 екрану
	var cols: int
	if count <= 3:
		cols = count
	elif count <= 4:
		cols = 2
	else:
		cols = 3
	@warning_ignore("integer_division")
	var rows: int = (count + cols - 1) / cols
	var total_w: float = float(cols) * (item_sz + GRID_PADDING)
	var total_h: float = float(rows) * (item_sz + GRID_PADDING)
	var start_x: float = (vp.x - total_w) * 0.5 + item_sz * 0.5 + GRID_PADDING * 0.5
	var start_y: float = (vp.y * 0.55 - total_h) * 0.5 + item_sz * 0.5 + 60.0

	for i: int in count:
		@warning_ignore("integer_division")
		var col: int = i % cols
		@warning_ignore("integer_division")
		var row: int = i / cols
		var pos: Vector2 = Vector2(
			start_x + float(col) * (item_sz + GRID_PADDING),
			start_y + float(row) * (item_sz + GRID_PADDING))

		var node: Node2D = _create_grid_item(_current_animals[i], item_sz)
		node.position = pos
		## Entrance animation — bounce in
		node.scale = Vector2.ZERO
		add_child(node)
		_grid_nodes.append(node)
		_all_round_nodes.append(node)
		if not SettingsManager.reduced_motion:
			var tw: Tween = _create_game_tween()
			tw.tween_property(node, "scale", Vector2(1.05, 1.05),
				ANIM_NORMAL).set_delay(float(i) * 0.1) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(node, "scale", Vector2.ONE, ANIM_FAST)
		else:
			node.scale = Vector2.ONE


func _create_grid_item(animal_idx: int, sz: float) -> Node2D:
	var node: Node2D = Node2D.new()
	## Фон слота (округлений прямокутник)
	var bg: Node2D = Node2D.new()
	var sz_ref: float = sz
	bg.draw.connect(func() -> void:
		## Тінь (LAW 28)
		bg.draw_rect(Rect2(-sz_ref * 0.52 + 2, -sz_ref * 0.52 + 3,
			sz_ref * 1.04, sz_ref * 1.04), Color(0, 0, 0, 0.1), true)
		## Фон
		bg.draw_rect(Rect2(-sz_ref * 0.52, -sz_ref * 0.52,
			sz_ref * 1.04, sz_ref * 1.04), SLOT_BG_COLOR, true))
	node.add_child(bg)
	_add_animal_sprite_to_node(node, animal_idx, sz)
	return node


func _add_animal_sprite_to_node(node: Node2D, animal_idx: int, sz: float) -> void:
	var tex: Texture2D = _textures.get(animal_idx) as Texture2D
	if not tex:
		## LAW 7: sprite fallback — procedural placeholder
		var fallback: Node2D = Node2D.new()
		var sz_ref: float = sz
		fallback.draw.connect(func() -> void:
			fallback.draw_circle(Vector2.ZERO, sz_ref * 0.35, Color("a5d6a7"))
			fallback.draw_circle(Vector2.ZERO, sz_ref * 0.15, Color("81c784")))
		node.add_child(fallback)
		return
	var ctrl: Control = Control.new()
	ctrl.size = Vector2(sz * 0.85, sz * 0.85)
	ctrl.position = Vector2(-sz * 0.425, -sz * 0.425)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex_ref: Texture2D = tex
	var sz_ref: float = sz
	ctrl.draw.connect(func() -> void:
		ctrl.draw_texture_rect(tex_ref,
			Rect2(Vector2.ZERO, Vector2(sz_ref * 0.85, sz_ref * 0.85)), false))
	node.add_child(ctrl)


func _create_answer_item(animal_idx: int, sz: float, is_correct: bool) -> Node2D:
	var node: Node2D = Node2D.new()
	node.set_meta("is_correct", is_correct)
	node.set_meta("animal_idx", animal_idx)
	## Фон (круглий — відрізняється від grid прямокутників для clarity)
	var bg: Node2D = Node2D.new()
	var sz_ref: float = sz
	bg.draw.connect(func() -> void:
		bg.draw_circle(Vector2(1.5, 2.0), sz_ref * 0.52, Color(0, 0, 0, 0.1))
		bg.draw_circle(Vector2.ZERO, sz_ref * 0.52, ANSWER_BG_COLOR))
	node.add_child(bg)
	_add_animal_sprite_to_node(node, animal_idx, sz * 0.85)
	return node


## ========== HELPERS ==========

func _pick_random_animals(count: int) -> Array[int]:
	## Обрати N різних тварин (LAW 13: bounds check)
	var available: Array[int] = []
	for i: int in ANIMAL_SPRITES.size():
		if _textures.has(i):
			available.append(i)
	if available.size() == 0:
		push_warning("WhatsMissing: no textures loaded, using indices 0..%d" % (count - 1))
		var fallback: Array[int] = []
		for i: int in count:
			fallback.append(i)
		return fallback
	available.shuffle()
	var result: Array[int] = []
	for i: int in mini(count, available.size()):
		result.append(available[i])
	return result


func _cleanup_round() -> void:
	## A9: round hygiene — прибрати все
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_grid_nodes.clear()
	_answer_nodes.clear()
	_current_animals.clear()
	_missing_idx = -1
	_missing_pos = -1
	_consecutive_errors = 0


func _update_progress() -> void:
	var text: String = "%d / %d" % [_round + 1, _total_rounds]
	if _instruction_label and is_instance_valid(_instruction_label):
		pass  ## Progress shown via round label


func _start_item_breathing() -> void:
	## A10: idle breathing — items pulse gently while visible
	if SettingsManager.reduced_motion:
		return
	for node: Node2D in _grid_nodes:
		if not is_instance_valid(node):
			continue
		var tw: Tween = _create_game_tween()
		tw.set_loops()
		var phase: float = randf_range(0, 1.0)
		tw.tween_property(node, "scale", Vector2(1.02, 1.02),
			0.8 + phase).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(node, "scale", Vector2.ONE,
			0.8 + phase).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## ========== IDLE TIMER ==========

var _idle_timer: SceneTreeTimer = null

func _start_idle_timer() -> void:
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and not _game_finished and _phase == "answer":
			_idle_hint())


func _reset_idle_timer() -> void:
	_idle_timer = null
	_start_idle_timer()


func _idle_hint() -> void:
	## A10: idle escalation — підказка де правильна відповідь
	_idle_hint_level += 1
	for node: Node2D in _answer_nodes:
		if not is_instance_valid(node):
			continue
		if node.get_meta("is_correct", false) and not node.get_meta("used", false):
			if _idle_hint_level >= 3:
				## Level 3: tutorial hand
				_show_tutorial_hand_at(node.global_position)
			elif _idle_hint_level >= 2:
				## Level 2: stronger pulse
				var tw: Tween = _create_game_tween()
				tw.tween_property(node, "scale", Vector2(1.15, 1.15), 0.3)
				tw.tween_property(node, "scale", Vector2.ONE, 0.3)
			else:
				## Level 1: gentle pulse
				var tw: Tween = _create_game_tween()
				tw.tween_property(node, "scale", Vector2(1.08, 1.08), 0.4)
				tw.tween_property(node, "scale", Vector2.ONE, 0.4)
			break


func _show_tutorial_hand_at(pos: Vector2) -> void:
	if _tutorial_sys and is_instance_valid(_tutorial_sys):
		_tutorial_sys.show_hint(pos)
