extends BaseMiniGame

## ECE-07 Магнітні пазли-половинки — з'єднай половинки тварин!
## Toddler: 2 пари за раунд, 4 раунди. Preschool: 3 пари, 4 раунди.

const TOTAL_ROUNDS: int = 4
const PAIRS_TODDLER: int = 2
const PAIRS_PRESCHOOL: int = 3
const DEAL_STAGGER: float = 0.12
const DEAL_DURATION: float = 0.35
const IDLE_HINT_DELAY: float = 5.0
const HALF_W: float = 128.0
const HALF_H: float = 256.0
const SPRITE_REGION_LEFT: Rect2 = Rect2(0, 0, 256, 512)
const SPRITE_REGION_RIGHT: Rect2 = Rect2(256, 0, 256, 512)
const SPRITE_SCALE: Vector2 = Vector2(0.40, 0.40)
const TARGET_BG_COLOR: Color = Color(0.93, 0.88, 0.98, 0.7)
const TARGET_BORDER: Color = Color("a78bfa")
const TARGET_CORNER: int = 14
const SNAP_GLOW: Color = Color("a78bfa", 0.4)
const SAFETY_TIMEOUT_SEC: float = 120.0

const ANIMAL_NAMES: Array[String] = [
	"Bear", "Bunny", "Cat", "Chicken", "Cow", "Crocodile", "Deer",
	"Dog", "Elephant", "Frog", "Goat", "Hedgehog", "Horse",
	"Lion", "Monkey", "Mouse", "Panda", "Penguin", "Squirrel",
]

var _is_toddler: bool = false
var _drag: UniversalDrag = null
var _round: int = 0
var _matched: int = 0
var _total: int = 0
var _start_time: float = 0.0

var _right_halves: Array[Node2D] = []
var _left_targets: Array[Node2D] = []
var _all_round_nodes: Array[Node] = []
var _half_animal: Dictionary = {}
var _target_animal: Dictionary = {}
var _item_origins: Dictionary = {}
var _used_indices: Array[int] = []

var _idle_timer: SceneTreeTimer = null


func _ready() -> void:
	game_id = "magnetic_halves"
	bg_theme = "puzzle"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_drag = UniversalDrag.new(self)
	if _is_toddler:
		_drag.snap_radius_override = TODDLER_SNAP_RADIUS
	_drag.item_picked_up.connect(_on_picked)
	_drag.item_dropped_on_target.connect(_on_dropped_target)
	_drag.item_dropped_on_empty.connect(_on_dropped_empty)
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("PUZZLE_TUTORIAL_TODDLER")
	return tr("PUZZLE_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _right_halves.is_empty() or _left_targets.is_empty():
		return {}
	## Знайти першу праву половинку та відповідний лівий таргет
	for item: Node2D in _right_halves:
		if not is_instance_valid(item):
			continue
		var animal: String = _half_animal.get(item, "")
		for target: Node2D in _left_targets:
			if is_instance_valid(target) and _target_animal.get(target, "") == animal:
				return {"type": "drag", "from": item.global_position, "to": target.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	_matched = 0
	_input_locked = true
	## Прогресивна складність: більше пар у пізніших раундах
	var pairs: int = _scale_by_round_i(1, PAIRS_TODDLER, _round, TOTAL_ROUNDS) if _is_toddler \
		else _scale_by_round_i(2, PAIRS_PRESCHOOL, _round, TOTAL_ROUNDS)
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	var animals: Array[String] = _pick_animals(pairs)
	_spawn_left_targets(animals)
	_spawn_right_halves(animals)
	## A8: _total = фактична кількість спавнених таргетів (не запланована)
	_total = _left_targets.size()
	if _total == 0:
		push_warning("MagneticHalves: жодна пара не створена, пропускаємо раунд")
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round()
		return
	## Магнітний асист для тоддлерів
	if _is_toddler:
		_drag.magnetic_assist = true
		var mag_pairs: Dictionary = {}
		for item: Node2D in _right_halves:
			var anim_name: String = _half_animal.get(item, "")
			for target: Node2D in _left_targets:
				if _target_animal.get(target, "") == anim_name:
					mag_pairs[item] = target
					break
		_drag.set_correct_pairs(mag_pairs)


func _pick_animals(count: int) -> Array[String]:
	var result: Array[String] = []
	if _used_indices.size() + count > ANIMAL_NAMES.size():
		_used_indices.clear()
	for i: int in count:
		var idx: int = randi() % ANIMAL_NAMES.size()
		while _used_indices.has(idx):
			idx = randi() % ANIMAL_NAMES.size()
		_used_indices.append(idx)
		result.append(ANIMAL_NAMES[idx])
	return result


func _spawn_left_targets(animals: Array[String]) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = animals.size()
	var spacing: float = (vp.y - 200.0) / float(count + 1)
	var start_y: float = 160.0
	var target_x: float = vp.x * 0.25
	for i: int in count:
		var animal: String = animals[i]
		var tex_path: String = "res://assets/sprites/animals/%s.png" % animal
		if not ResourceLoader.exists(tex_path):
			push_warning("MagneticHalves: Missing sprite: " + tex_path)
			continue
		var tex: Texture2D = load(tex_path)
		if not tex:
			push_warning("MagneticHalves: текстуру '%s' не знайдено" % tex_path)
			continue
		var target: Node2D = Node2D.new()
		target.position = Vector2(target_x, start_y + spacing * float(i + 1))
		add_child(target)
		## Напівпрозорий фон-підказка
		var bg: Panel = Panel.new()
		var bg_w: float = HALF_W * SPRITE_SCALE.x + 20.0
		var bg_h: float = HALF_H * SPRITE_SCALE.y + 20.0
		bg.size = Vector2(bg_w, bg_h)
		bg.position = Vector2(-bg_w * 0.5, -bg_h * 0.5)
		var style: StyleBoxFlat = GameData.candy_panel(TARGET_BG_COLOR, TARGET_CORNER)
		style.border_color = TARGET_BORDER
		style.set_border_width_all(2)
		bg.add_theme_stylebox_override("panel", style)
		## Grain overlay (LAW 28)
		bg.material = GameData.create_premium_material(0.04, 2.0, 0.04, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		GameData.add_gloss(bg, 10)
		target.add_child(bg)
		## Ліва половина тварини (напівпрозора підказка)
		var hint_sprite: Sprite2D = Sprite2D.new()
		hint_sprite.texture = tex
		hint_sprite.region_enabled = true
		hint_sprite.region_rect = SPRITE_REGION_LEFT
		hint_sprite.scale = SPRITE_SCALE
		hint_sprite.modulate = Color(1, 1, 1, 0.25)
		target.add_child(hint_sprite)
		target.set_meta("is_filled", false)
		_left_targets.append(target)
		_target_animal[target] = animal
		_drag.drop_targets.append(target)
		_all_round_nodes.append(target)
	_staggered_spawn(_left_targets, 0.08)


func _spawn_right_halves(animals: Array[String]) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = animals.size()
	## Перемішуємо порядок правих половинок
	var shuffled: Array[String] = animals.duplicate()
	shuffled.shuffle()
	var spacing: float = (vp.y - 200.0) / float(count + 1)
	var start_y: float = 160.0
	var item_x: float = vp.x * 0.75
	for i: int in count:
		var animal: String = shuffled[i]
		var tex_path: String = "res://assets/sprites/animals/%s.png" % animal
		if not ResourceLoader.exists(tex_path):
			push_warning("MagneticHalves: Missing sprite: " + tex_path)
			continue
		var tex: Texture2D = load(tex_path)
		if not tex:
			push_warning("MagneticHalves: текстуру '%s' не знайдено" % tex_path)
			continue
		var item: Node2D = Node2D.new()
		add_child(item)
		## Кругле біле тло
		var bg_sz: float = maxf(HALF_W, HALF_H) * SPRITE_SCALE.x + 16.0
		var bg: Panel = Panel.new()
		bg.size = Vector2(bg_sz, bg_sz)
		bg.position = Vector2(-bg_sz * 0.5, -bg_sz * 0.5)
		bg.add_theme_stylebox_override("panel",
			GameData.candy_circle(Color("fff8e1"), bg_sz * 0.4))
		## Grain + gloss (LAW 28 V162)
		bg.material = GameData.create_premium_material(0.04, 2.0, 0.04, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		GameData.add_gloss(bg, 10)
		item.add_child(bg)
		## Права половина тварини
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = tex
		sprite.region_enabled = true
		sprite.region_rect = SPRITE_REGION_RIGHT
		sprite.scale = SPRITE_SCALE
		item.add_child(sprite)
		var target_pos: Vector2 = Vector2(item_x, start_y + spacing * float(i + 1))
		_half_animal[item] = animal
		_item_origins[item] = target_pos
		_right_halves.append(item)
		_drag.draggable_items.append(item)
		_all_round_nodes.append(item)
		## Deal анімація
		if SettingsManager.reduced_motion:
			item.position = target_pos
			item.modulate.a = 1.0
			if i == count - 1:
				_input_locked = false
				_drag.enabled = true
				_reset_idle_timer()
		else:
			item.position = Vector2(vp.x + 100.0, target_pos.y)
			item.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = create_tween().set_parallel(true)
			tw.tween_property(item, "position", target_pos, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
			if i == count - 1:
				tw.chain().tween_callback(func() -> void:
					_input_locked = false
					_drag.enabled = true
					_reset_idle_timer())


## ---- Input ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_input(event)


func _process(delta: float) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_process(delta)


## ---- Drop ----

func _on_picked(_item: Node2D) -> void:
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()


func _on_dropped_target(item: Node2D, target: Node2D) -> void:
	if _game_over:
		return
	var item_animal: String = _half_animal.get(item, "")
	var target_animal: String = _target_animal.get(target, "")
	if item_animal == target_animal and not target.get_meta("is_filled", false):
		_handle_correct(item, target)
	else:
		_handle_wrong(item)


func _on_dropped_empty(item: Node2D) -> void:
	_drag.snap_back(item, _item_origins.get(item, item.position))


func _handle_correct(item: Node2D, target: Node2D) -> void:
	_register_correct(item)
	target.set_meta("is_filled", true)
	_drag.draggable_items.erase(item)
	_right_halves.erase(item)
	_matched += 1
	item.z_index = 0
	## Магнітний snap — правий до лівого
	var offset_x: float = HALF_W * SPRITE_SCALE.x * 2.0
	var snap_pos: Vector2 = target.global_position + Vector2(offset_x, 0)
	if SettingsManager.reduced_motion:
		item.global_position = snap_pos
		item.rotation = 0.0
		for child: Node in target.get_children():
			if child is Sprite2D:
				(child as Sprite2D).modulate.a = 1.0
		if _matched >= _total:
			_on_round_complete()
		else:
			_reset_idle_timer()
		return
	var tw: Tween = create_tween()
	tw.tween_property(item, "global_position", snap_pos, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "rotation", 0.0, 0.15)
	## Зробити підказку повністю видимою
	for child: Node in target.get_children():
		if child is Sprite2D:
			var sp: Sprite2D = child as Sprite2D
			create_tween().tween_property(sp, "modulate:a", 1.0, 0.2)
	if _matched >= _total:
		tw.chain().tween_callback(_on_round_complete)
	else:
		_reset_idle_timer()


func _handle_wrong(item: Node2D) -> void:
	if _is_toddler:
		_register_error(item)  ## A11: scaffolding для тоддлера
	else:
		_errors += 1
		_register_error(item)
	_drag.snap_back(item, _item_origins.get(item, item.position))


## ---- Round management ----

func _on_round_complete() -> void:
	_input_locked = true
	_drag.enabled = false
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.8
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


func _clear_round() -> void:
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_right_halves.clear()
	_left_targets.clear()
	_half_animal.clear()
	_target_animal.clear()
	_item_origins.clear()
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	_drag.clear_drag()


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
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
	if _input_locked or _game_over or _right_halves.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	for item: Node2D in _right_halves:
		if is_instance_valid(item):
			_pulse_node(item, 1.15)
			break
	_reset_idle_timer()
