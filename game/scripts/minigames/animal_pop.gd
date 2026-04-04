extends BaseMiniGame

## "Злови Тваринку!" / "Catch the Animal!"
## Тварини визирають з нірок. Тап = злови (friendly, не whack!).
## Diamond 2013: executive function = #1 school readiness predictor.
##
## Toddler (2-4): 4 нірки, тварини визирають повільно, всіх можна ловити.
## Preschool (4-7): 6 нірок + "сплячі" тварини (НЕ ТАПАЙ!) = inhibitory control.
## На хвилінку тварин стає більше, і вони з'являються швидше (A4).

const ROUNDS_TODDLER: int = 5
const ROUNDS_PRESCHOOL: int = 5
const SAFETY_TIMEOUT_SEC: float = 120.0
const IDLE_HINT_DELAY: float = 5.0

## Кількість нірок
const HOLES_TODDLER: int = 4  ## 2x2 grid
const HOLES_PRESCHOOL: int = 6  ## 2x3 grid

## Тварин за раунд
const POPS_PER_ROUND_TODDLER: Array[int] = [4, 5, 5, 6, 7]
const POPS_PER_ROUND_PRESCHOOL: Array[int] = [5, 6, 7, 8, 9]

## Час видимості тварини (секунди) — A4: зменшується з раундами
const VISIBLE_TIME_TODDLER_EASY: float = 3.0
const VISIBLE_TIME_TODDLER_HARD: float = 2.0
const VISIBLE_TIME_PRESCHOOL_EASY: float = 2.5
const VISIBLE_TIME_PRESCHOOL_HARD: float = 1.2

## Інтервал між появами (секунди)
const SPAWN_INTERVAL_TODDLER_EASY: float = 2.0
const SPAWN_INTERVAL_TODDLER_HARD: float = 1.2
const SPAWN_INTERVAL_PRESCHOOL_EASY: float = 1.5
const SPAWN_INTERVAL_PRESCHOOL_HARD: float = 0.7

## Шанс "сплячої" тварини (Preschool inhibitory control)
## Diamond 2013: go/no-go task develops ages 4-7
const SLEEPY_CHANCE_BY_ROUND: Array[float] = [0.0, 0.15, 0.2, 0.25, 0.3]

## Розміри
const HOLE_SIZE_TODDLER: float = 150.0   ## Vatavu 2015: 150px for toddlers
const HOLE_SIZE_PRESCHOOL: float = 110.0  ## Nacher 2015: 110px for preschool
const HOLE_DEPTH: float = 40.0  ## Глибина нірки (visual offset)

## Кольори
const HOLE_COLOR: Color = Color("5d4037")
const HOLE_RIM_COLOR: Color = Color("795548")
const HOLE_SHADOW_COLOR: Color = Color("3e2723")
const SLEEPY_OVERLAY: Color = Color("b3e5fc", 0.4)
const GRASS_COLOR: Color = Color("66bb6a")

## Тварини
const ANIMAL_SPRITES: Array[String] = [
	"res://assets/sprites/animals/Bear.png",
	"res://assets/sprites/animals/Bunny.png",
	"res://assets/sprites/animals/Cat.png",
	"res://assets/sprites/animals/Dog.png",
	"res://assets/sprites/animals/Frog.png",
	"res://assets/sprites/animals/Hedgehog.png",
	"res://assets/sprites/animals/Mouse.png",
	"res://assets/sprites/animals/Panda.png",
	"res://assets/sprites/animals/Penguin.png",
	"res://assets/sprites/animals/Squirrel.png",
]

## Стан
var _is_toddler: bool = false
var _round: int = 0
var _total_rounds: int = 0
var _start_time: float = 0.0
var _holes: Array[Dictionary] = []  ## {node, pos, occupied, animal_node}
var _pops_remaining: int = 0
var _pops_caught: int = 0
var _spawn_timer: Timer = null
var _score: int = 0
var _textures: Dictionary = {}
var _all_round_nodes: Array[Node] = []
var _active_animals: Array[Dictionary] = []  ## {hole_idx, node, is_sleepy, timer_id}


func _ready() -> void:
	game_id = "animal_pop"
	_skill_id = "reaction_speed"
	bg_theme = "garden"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_preload_textures()
	_apply_background()
	_build_instruction_pill(get_tutorial_instruction())
	_build_holes()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("ANIMAL_POP_TUTORIAL_T")
	return tr("ANIMAL_POP_TUTORIAL_P")


func get_tutorial_demo() -> Dictionary:
	for data: Dictionary in _active_animals:
		var node: Node2D = data.get("node") as Node2D
		if node and is_instance_valid(node) and not data.get("is_sleepy", false):
			return {"type": "tap", "target": node.global_position}
	return {}


func _preload_textures() -> void:
	for i: int in ANIMAL_SPRITES.size():
		if ResourceLoader.exists(ANIMAL_SPRITES[i]):
			_textures[i] = load(ANIMAL_SPRITES[i])
		else:
			push_warning("AnimalPop: Missing sprite: " + ANIMAL_SPRITES[i])


## ========== HOLES SETUP ==========

func _build_holes() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var num_holes: int = HOLES_TODDLER if _is_toddler else HOLES_PRESCHOOL
	var hole_sz: float = HOLE_SIZE_TODDLER if _is_toddler else HOLE_SIZE_PRESCHOOL
	var cols: int = 2 if _is_toddler else 3
	@warning_ignore("integer_division")
	var rows: int = num_holes / cols
	var gap_x: float = hole_sz * 1.6
	var gap_y: float = hole_sz * 1.4
	var total_w: float = float(cols - 1) * gap_x
	var total_h: float = float(rows - 1) * gap_y
	var start_x: float = (vp.x - total_w) * 0.5
	var start_y: float = (vp.y - total_h) * 0.5 + 30.0

	for i: int in num_holes:
		var col: int = i % cols
		@warning_ignore("integer_division")
		var row: int = i / cols
		var pos: Vector2 = Vector2(
			start_x + float(col) * gap_x,
			start_y + float(row) * gap_y)
		var hole_node: Node2D = _create_hole_visual(hole_sz)
		hole_node.position = pos
		add_child(hole_node)
		_holes.append({
			"node": hole_node,
			"pos": pos,
			"occupied": false,
			"size": hole_sz,
		})


func _create_hole_visual(sz: float) -> Node2D:
	var node: Node2D = Node2D.new()
	node.z_index = 0
	var sz_ref: float = sz
	## Pre-generate grass points (randf inside _draw changes on redraw)
	var grass_pts: PackedVector2Array = PackedVector2Array()
	grass_pts.append(Vector2(-sz * 0.6, HOLE_DEPTH - 5))
	for j: int in 8:
		var gx: float = -sz * 0.6 + float(j) * sz * 0.15 + randf() * 5.0
		var gy: float = HOLE_DEPTH - 12.0 - randf() * 8.0
		grass_pts.append(Vector2(gx, gy))
	grass_pts.append(Vector2(sz * 0.6, HOLE_DEPTH - 5))
	grass_pts.append(Vector2(sz * 0.6, HOLE_DEPTH + 15))
	grass_pts.append(Vector2(-sz * 0.6, HOLE_DEPTH + 15))
	node.draw.connect(func() -> void:
		## Тінь нірки
		node.draw_ellipse(Vector2(2, HOLE_DEPTH + 3),
			sz_ref * 0.55, sz_ref * 0.3, HOLE_SHADOW_COLOR)
		## Нірка (еліпс)
		node.draw_ellipse(Vector2(0, HOLE_DEPTH),
			sz_ref * 0.52, sz_ref * 0.28, HOLE_COLOR)
		## Обідок
		node.draw_arc(Vector2(0, HOLE_DEPTH), sz_ref * 0.52, PI, TAU,
			24, HOLE_RIM_COLOR, 3.0, true)
		## Трава поверх (приховує нижню частину тварини)
		node.draw_colored_polygon(grass_pts, GRASS_COLOR))
	return node


## ========== ROUND LIFECYCLE ==========

func _start_round() -> void:
	_input_locked = true
	_cleanup_active_animals()

	var pops: Array[int] = POPS_PER_ROUND_TODDLER if _is_toddler else POPS_PER_ROUND_PRESCHOOL
	_pops_remaining = pops[mini(_round, pops.size() - 1)]
	_pops_caught = 0

	_update_instruction()

	## Затримка перед стартом раунду
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if not is_instance_valid(self) or _game_finished:
			return
		_input_locked = false
		_start_spawning())


func _start_spawning() -> void:
	if _spawn_timer:
		_spawn_timer.stop()
		_spawn_timer.queue_free()
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	var interval: float
	if _is_toddler:
		interval = _scale_adaptive(SPAWN_INTERVAL_TODDLER_EASY,
			SPAWN_INTERVAL_TODDLER_HARD, _round, _total_rounds)
	else:
		interval = _scale_adaptive(SPAWN_INTERVAL_PRESCHOOL_EASY,
			SPAWN_INTERVAL_PRESCHOOL_HARD, _round, _total_rounds)
	_spawn_timer.wait_time = interval
	_spawn_timer.timeout.connect(_spawn_animal)
	add_child(_spawn_timer)
	_spawn_timer.start()
	_start_idle_timer()
	## Перший спавн одразу
	_spawn_animal()


func _spawn_animal() -> void:
	if _game_finished or _pops_remaining <= 0:
		if _spawn_timer:
			_spawn_timer.stop()
		return

	## Знайти вільну нірку
	var free_holes: Array[int] = []
	for i: int in _holes.size():
		if not _holes[i].get("occupied", false):
			free_holes.append(i)
	if free_holes.is_empty():
		push_warning("AnimalPop: all holes occupied, skipping spawn")
		return

	var hole_idx: int = free_holes.pick_random()
	_holes[hole_idx]["occupied"] = true
	_pops_remaining -= 1

	## Чи це "сонна" тварина? (Preschool only)
	var is_sleepy: bool = false
	if not _is_toddler:
		var sleepy_chances: Array[float] = SLEEPY_CHANCE_BY_ROUND
		var chance: float = sleepy_chances[mini(_round, sleepy_chances.size() - 1)]
		is_sleepy = randf() < chance

	## Створити тварину
	var hole_data: Dictionary = _holes[hole_idx]
	var hole_pos: Vector2 = hole_data.get("pos", Vector2.ZERO) as Vector2
	var hole_sz: float = hole_data.get("size", 110.0) as float
	var animal_idx: int = randi() % _textures.size()
	var animal_node: Node2D = _create_animal_node(animal_idx, hole_sz, is_sleepy)
	animal_node.position = hole_pos + Vector2(0, HOLE_DEPTH)
	animal_node.z_index = 1
	## Починає під ніркою
	animal_node.position.y += hole_sz * 0.4
	animal_node.modulate = Color(1, 1, 1, 0)
	add_child(animal_node)

	var animal_data: Dictionary = {
		"hole_idx": hole_idx,
		"node": animal_node,
		"is_sleepy": is_sleepy,
		"caught": false,
	}
	_active_animals.append(animal_data)
	_all_round_nodes.append(animal_node)

	## Pop up анімація
	var target_y: float = hole_pos.y - hole_sz * 0.15
	var tw: Tween = _create_game_tween()
	tw.tween_property(animal_node, "position:y", target_y, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(animal_node, "modulate:a", 1.0, 0.15)

	## Audio cue (subtle)
	AudioManager.play_sfx("click", randf_range(0.9, 1.1))

	## Timer: тварина ховається назад
	var visible_time: float
	if _is_toddler:
		visible_time = _scale_adaptive(VISIBLE_TIME_TODDLER_EASY,
			VISIBLE_TIME_TODDLER_HARD, _round, _total_rounds)
	else:
		visible_time = _scale_adaptive(VISIBLE_TIME_PRESCHOOL_EASY,
			VISIBLE_TIME_PRESCHOOL_HARD, _round, _total_rounds)

	get_tree().create_timer(visible_time).timeout.connect(func() -> void:
		if is_instance_valid(self) and not _game_finished:
			_hide_animal(animal_data))


func _hide_animal(data: Dictionary) -> void:
	if data.get("caught", false):
		return  ## Вже злов лена
	var node: Node2D = data.get("node") as Node2D
	var hole_idx: int = data.get("hole_idx", -1) as int
	if not node or not is_instance_valid(node):
		if hole_idx >= 0 and hole_idx < _holes.size():
			_holes[hole_idx]["occupied"] = false
		return
	## Slide down
	var tw: Tween = _create_game_tween()
	tw.tween_property(node, "position:y", node.position.y + 80.0, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "modulate:a", 0.0, 0.15).set_delay(0.05)
	tw.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
		if hole_idx >= 0 and hole_idx < _holes.size():
			_holes[hole_idx]["occupied"] = false
		_active_animals.erase(data)
		## Не зловив = miss (Toddler: не рахується як помилка)
		if not _is_toddler and not data.get("is_sleepy", false):
			pass  ## Misses не рахуються як помилки — лише тапи на sleepy
		_check_round_complete())


## ========== INPUT ==========

func _input(event: InputEvent) -> void:
	if _input_locked or _game_finished:
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

	## Перевіряємо чи тапнули на тварину
	var best_data: Dictionary = {}
	var best_dist: float = INF
	for data: Dictionary in _active_animals:
		if data.get("caught", false):
			continue
		var node: Node2D = data.get("node") as Node2D
		if not node or not is_instance_valid(node):
			continue
		var hole_idx: int = data.get("hole_idx", -1) as int
		if hole_idx < 0 or hole_idx >= _holes.size():
			continue
		var hole_sz: float = _holes[hole_idx].get("size", 110.0) as float
		var tap_r: float = hole_sz * 0.6  ## Generous
		var dist: float = pos.distance_to(node.global_position)
		if dist <= tap_r and dist < best_dist:
			best_dist = dist
			best_data = data
	if best_data.is_empty():
		return
	_handle_tap(best_data)


func _handle_tap(data: Dictionary) -> void:
	var node: Node2D = data.get("node") as Node2D
	var is_sleepy: bool = data.get("is_sleepy", false)

	if is_sleepy:
		## Тапнув сонну тварину — помилка! (Preschool inhibitory control)
		data["caught"] = true
		_register_error(node)
		AudioManager.play_sfx("error")
		HapticsManager.vibrate_light()
		## Тварина прокидається і сердиться
		if node and is_instance_valid(node):
			if SettingsManager.reduced_motion:
				_release_hole(data)
			else:
				var tw: Tween = _create_game_tween()
				tw.tween_property(node, "rotation", 0.1, 0.05)
				tw.tween_property(node, "rotation", -0.1, 0.1)
				tw.tween_property(node, "rotation", 0.0, 0.05)
				tw.tween_property(node, "modulate:a", 0.0, 0.3)
				tw.tween_callback(func() -> void:
					_release_hole(data))
	else:
		## Злов тварину! (correct)
		data["caught"] = true
		_pops_caught += 1
		_register_correct(node)
		AudioManager.play_sfx("success", randf_range(0.9, 1.2))
		HapticsManager.vibrate_light()
		VFXManager.spawn_correct_sparkle(node.global_position)
		## Bounce + disappear
		if node and is_instance_valid(node):
			var tw: Tween = _create_game_tween()
			tw.tween_property(node, "scale", Vector2(1.3, 1.3), 0.1)
			tw.tween_property(node, "position:y", node.position.y + 100.0, 0.2) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(node, "modulate:a", 0.0, 0.15).set_delay(0.05)
			tw.tween_callback(func() -> void:
				_release_hole(data))
		_check_round_complete()


func _release_hole(data: Dictionary) -> void:
	var hole_idx: int = data.get("hole_idx", -1) as int
	if hole_idx >= 0 and hole_idx < _holes.size():
		_holes[hole_idx]["occupied"] = false
	var node: Node2D = data.get("node") as Node2D
	if node and is_instance_valid(node):
		node.queue_free()
	_active_animals.erase(data)


func _check_round_complete() -> void:
	if _pops_remaining > 0 or not _active_animals.is_empty():
		return
	## Раунд завершено
	if _spawn_timer:
		_spawn_timer.stop()
	_round += 1
	if _round >= _total_rounds:
		_finish()
	else:
		get_tree().create_timer(ROUND_DELAY).timeout.connect(func() -> void:
			if is_instance_valid(self) and not _game_finished:
				_start_round())


func _finish() -> void:
	_game_over = true
	if _spawn_timer:
		_spawn_timer.stop()
		_spawn_timer.queue_free()
		_spawn_timer = null
	var time_sec: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var stars: int = _calculate_stars(_errors)
	finish_game(stars, {
		"time_sec": time_sec,
		"errors": _errors,
		"rounds_played": _round,
		"earned_stars": stars,
		"caught": _pops_caught,
	})


## ========== VISUAL HELPERS ==========

func _create_animal_node(animal_idx: int, hole_sz: float, is_sleepy: bool) -> Node2D:
	var node: Node2D = Node2D.new()
	var sprite_sz: float = hole_sz * 0.7
	var tex: Texture2D = _textures.get(animal_idx) as Texture2D
	if tex:
		var ctrl: Control = Control.new()
		ctrl.size = Vector2(sprite_sz, sprite_sz)
		ctrl.position = Vector2(-sprite_sz * 0.5, -sprite_sz * 0.8)
		ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex_ref: Texture2D = tex
		var sz_ref: float = sprite_sz
		ctrl.draw.connect(func() -> void:
			ctrl.draw_texture_rect(tex_ref,
				Rect2(Vector2.ZERO, Vector2(sz_ref, sz_ref)), false))
		node.add_child(ctrl)
	else:
		## LAW 7: fallback
		var fb: Node2D = Node2D.new()
		var sz_ref: float = sprite_sz
		fb.draw.connect(func() -> void:
			fb.draw_circle(Vector2(0, -sz_ref * 0.3), sz_ref * 0.35, Color("a5d6a7")))
		node.add_child(fb)

	## Sleepy overlay — "Zzz" + blue tint (LAW 25: not just color, also symbol)
	if is_sleepy:
		node.modulate = Color(0.85, 0.85, 1.0, 1.0)
		var zzz: Label = Label.new()
		zzz.text = "💤"
		zzz.add_theme_font_size_override("font_size", int(hole_sz * 0.25))
		zzz.position = Vector2(sprite_sz * 0.2, -sprite_sz * 0.9)
		node.add_child(zzz)
	return node


func _cleanup_active_animals() -> void:
	for data: Dictionary in _active_animals:
		var node: Node2D = data.get("node") as Node2D
		if node and is_instance_valid(node):
			node.queue_free()
	_active_animals.clear()
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	for hole: Dictionary in _holes:
		hole["occupied"] = false


func _update_instruction() -> void:
	if _is_toddler:
		_fade_instruction(_instruction_label, tr("ANIMAL_POP_CATCH"))
	else:
		_fade_instruction(_instruction_label, tr("ANIMAL_POP_CATCH_NOT_SLEEPY"))


## ========== IDLE HINT (A10) ==========

var _idle_timer: SceneTreeTimer = null

func _start_idle_timer() -> void:
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and not _game_finished:
			_idle_hint())


func _reset_idle_timer() -> void:
	_idle_timer = null
	_start_idle_timer()


func _idle_hint() -> void:
	## A10: підсвітити активну (не-сонну) тварину
	_idle_hint_level += 1
	for data: Dictionary in _active_animals:
		if data.get("caught", false) or data.get("is_sleepy", false):
			continue
		var node: Node2D = data.get("node") as Node2D
		if not node or not is_instance_valid(node):
			continue
		if _idle_hint_level >= 3:
			_show_tutorial_hand_at(node.global_position)
		elif not SettingsManager.reduced_motion:
			var tw: Tween = _create_game_tween()
			var scale_amt: float = 1.15 if _idle_hint_level >= 2 else 1.08
			tw.tween_property(node, "scale", Vector2(scale_amt, scale_amt), 0.3)
			tw.tween_property(node, "scale", Vector2.ONE, 0.3)
		break


func _show_tutorial_hand_at(pos: Vector2) -> void:
	if _tutorial_sys and is_instance_valid(_tutorial_sys):
		_tutorial_sys.show_hint(pos)
