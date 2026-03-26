extends BaseMiniGame

## ECE-11 Гігієнічні рутини — витри бруд з тваринки!
## Toddler: 3 раунди, 5 плям, широкий пензель. Preschool: 4 раунди, 8 плям.

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 4
const SPOTS_TODDLER: int = 5
const SPOTS_PRESCHOOL: int = 8
const WIPE_RADIUS_TODDLER: float = 70.0
const WIPE_RADIUS_PRESCHOOL: float = 50.0
const SPOT_SIZE_MIN: float = 22.0
const SPOT_SIZE_MAX: float = 38.0
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0

const DIRT_COLORS: Array[Color] = [
	Color(0.55, 0.40, 0.25, 0.75),
	Color(0.50, 0.45, 0.30, 0.70),
	Color(0.45, 0.35, 0.20, 0.80),
	Color(0.60, 0.50, 0.35, 0.65),
]

const ANIMAL_NAMES: Array[String] = [
	"Bear", "Bunny", "Cat", "Chicken", "Cow", "Crocodile", "Deer",
	"Dog", "Elephant", "Frog", "Goat", "Hedgehog", "Horse",
	"Lion", "Monkey", "Mouse", "Panda", "Penguin", "Squirrel",
]

var _is_toddler: bool = false
var _round: int = 0
var _total_rounds: int = 0
var _start_time: float = 0.0
var _wiping: bool = false
var _wipe_radius: float = 70.0

var _spots: Array[Node2D] = []
var _cleaned: int = 0
var _total_spots: int = 0
var _animal_sprite: Sprite2D = null
var _progress_bar: Panel = null
var _progress_fill: Panel = null
var _all_round_nodes: Array[Node] = []
var _used_animals: Array[int] = []

var _missed_spots: int = 0
var _idle_timer: SceneTreeTimer = null
var _sponge_cursor: Control = null
var _initial_modulate: float = 0.45


func _ready() -> void:
	game_id = "hygiene"
	bg_theme = "ocean"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_wipe_radius = WIPE_RADIUS_TODDLER if _is_toddler else WIPE_RADIUS_PRESCHOOL
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("HYGIENE_TUTORIAL_TODDLER")
	return tr("HYGIENE_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	for spot: Node2D in _spots:
		if is_instance_valid(spot) and not spot.get_meta("is_clean", false):
			return {"type": "tap", "target": spot.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_cleaned = 0
	_missed_spots = 0
	_spots.clear()
	## Прогресивна складність: більше плям у пізніших раундах
	_total_spots = _scale_by_round_i(3, SPOTS_TODDLER, _round, _total_rounds) if _is_toddler \
		else _scale_by_round_i(5, SPOTS_PRESCHOOL, _round, _total_rounds)
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	var animal: String = _pick_animal()
	_spawn_animal(animal)
	_spawn_spots()
	_spawn_progress_bar()
	var start_d: float = 0.15 if SettingsManager.reduced_motion else 0.4
	var tw: Tween = create_tween()
	tw.tween_interval(start_d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


func _pick_animal() -> String:
	if _used_animals.size() >= ANIMAL_NAMES.size():
		_used_animals.clear()
	var idx: int = randi() % ANIMAL_NAMES.size()
	while _used_animals.has(idx):
		idx = randi() % ANIMAL_NAMES.size()
	_used_animals.append(idx)
	return ANIMAL_NAMES[idx]


func _spawn_animal(animal_name: String) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if not ResourceLoader.exists(tex_path):
		push_warning("HygieneGame: Missing sprite: " + tex_path)
		return
	var tex: Texture2D = load(tex_path)
	if not tex:
		push_warning("HygieneGame: текстуру '%s' не знайдено" % tex_path)
		return
	_animal_sprite = Sprite2D.new()
	_animal_sprite.texture = tex
	_animal_sprite.position = Vector2(vp.x * 0.5, vp.y * 0.45)
	_animal_sprite.scale = Vector2(0.42, 0.42)  ## Зменшено для кращого viewport fit
	## Тварина починає брудною (затемнена) — прогресивне освітлення
	_animal_sprite.modulate = Color(_initial_modulate, _initial_modulate, _initial_modulate, 1.0)
	add_child(_animal_sprite)
	_all_round_nodes.append(_animal_sprite)
	## Курсор-губка (IconDraw замість emoji — A12 consistency)
	_sponge_cursor = IconDraw.soap(40.0)
	_sponge_cursor.visible = false
	_sponge_cursor.z_index = 10
	_sponge_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sponge_cursor)
	_all_round_nodes.append(_sponge_cursor)


func _spawn_spots() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = Vector2(vp.x * 0.5, vp.y * 0.45)
	var spread: float = 100.0
	for i: int in _total_spots:
		var spot: Node2D = Node2D.new()
		var angle: float = randf() * TAU
		var dist: float = randf_range(20.0, spread)
		spot.position = center + Vector2(cos(angle), sin(angle)) * dist
		add_child(spot)
		## Кружечок бруду
		var sz: float = randf_range(SPOT_SIZE_MIN, SPOT_SIZE_MAX)
		var panel: Panel = Panel.new()
		panel.size = Vector2(sz, sz)
		panel.position = Vector2(-sz * 0.5, -sz * 0.5)
		panel.add_theme_stylebox_override("panel",
			GameData.candy_circle(DIRT_COLORS[randi() % DIRT_COLORS.size()], sz * 0.5, false))
		## Grain overlay (LAW 28)
		panel.material = GameData.create_premium_material(0.04, 2.0, 0.0, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		GameData.add_gloss(panel, 8)
		spot.add_child(panel)
		spot.set_meta("is_clean", false)
		_spots.append(spot)
		_all_round_nodes.append(spot)
	_staggered_spawn(_spots, 0.06)


func _spawn_progress_bar() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bar_w: float = 200.0
	var bar_h: float = 16.0
	var bar_x: float = (vp.x - bar_w) * 0.5
	var bar_y: float = vp.y - 60.0
	## Фон прогрес-бару
	_progress_bar = Panel.new()
	_progress_bar.size = Vector2(bar_w, bar_h)
	_progress_bar.position = Vector2(bar_x, bar_y)
	_progress_bar.add_theme_stylebox_override("panel",
		GameData.candy_panel(Color(0.36, 0.42, 0.75, 0.25), 10, false))
	## Grain overlay (LAW 28 V162)
	_progress_bar.material = GameData.create_premium_material(0.03, 2.0, 0.0, 0.0, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
	add_child(_progress_bar)
	_all_round_nodes.append(_progress_bar)
	## Заповнення
	_progress_fill = Panel.new()
	_progress_fill.size = Vector2(0, bar_h)
	_progress_fill.position = Vector2(bar_x, bar_y)
	_progress_fill.add_theme_stylebox_override("panel",
		GameData.candy_panel(Color("06d6a0"), 10, true))
	## Grain + gloss overlay (LAW 28 V162)
	_progress_fill.material = GameData.create_premium_material(0.03, 2.0, 0.04, 0.08, 0.04, 0.03, 0.06, "", 0.0, 0.10, 0.22, 0.18)
	GameData.add_gloss(_progress_fill, 6)
	add_child(_progress_fill)
	_all_round_nodes.append(_progress_fill)


func _update_progress() -> void:
	if not _progress_fill or not _progress_bar:
		return
	var ratio: float = float(_cleaned) / maxf(float(_total_spots), 1.0)
	var target_w: float = _progress_bar.size.x * ratio
	if SettingsManager.reduced_motion:
		_progress_fill.size.x = target_w
	else:
		var tw: Tween = create_tween()
		tw.tween_property(_progress_fill, "size:x", target_w, 0.2)


## ---- Input: витирання ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		if event.pressed:
			_wiping = true
			_try_wipe(event.position)
			_move_sponge(event.position, true)
		else:
			_wiping = false
			_move_sponge(event.position, false)
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_wiping = true
			_try_wipe(event.position)
			_move_sponge(event.position, true)
		else:
			_wiping = false
			_move_sponge(event.position, false)
	elif event is InputEventMouseMotion and _wiping:
		_try_wipe(event.position)
		_move_sponge(event.position, true)
	elif event is InputEventScreenDrag and _wiping and event.index == 0:
		_try_wipe(event.position)
		_move_sponge(event.position, true)


func _move_sponge(pos: Vector2, show: bool) -> void:
	if _sponge_cursor and is_instance_valid(_sponge_cursor):
		var was_hidden: bool = not _sponge_cursor.visible
		_sponge_cursor.visible = show
		_sponge_cursor.position = Vector2(pos.x - 20.0, pos.y - 44.0)
		## Bounce при першій появі
		if show and was_hidden \
				and not (SettingsManager and SettingsManager.reduced_motion):
			_sponge_cursor.scale = Vector2(0.5, 0.5)
			var stw: Tween = create_tween()
			stw.tween_property(_sponge_cursor, "scale", Vector2(1.1, 1.1), 0.1)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			stw.tween_property(_sponge_cursor, "scale", Vector2.ONE, 0.06)


func _try_wipe(pos: Vector2) -> void:
	var any_cleaned: bool = false
	for spot: Node2D in _spots:
		if not is_instance_valid(spot):
			continue
		if spot.get_meta("is_clean", false):
			continue
		if pos.distance_to(spot.global_position) < _wipe_radius:
			_clean_spot(spot)
			any_cleaned = true
	if any_cleaned:
		_reset_idle_timer()
	elif not _is_toddler:
		_missed_spots += 1
		if _missed_spots >= 5:
			_missed_spots = 0
			_errors += 1
			## Знайти першу брудну пляму для error VFX
			var dirty_spot: Node2D = null
			for s: Node2D in _spots:
				if is_instance_valid(s) and not s.get_meta("is_clean", false):
					dirty_spot = s
					break
			_register_error(dirty_spot)


func _clean_spot(spot: Node2D) -> void:
	spot.set_meta("is_clean", true)
	_cleaned += 1
	_register_correct()
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	VFXManager.spawn_sparkle_pop(spot.global_position)
	## Анімація зникнення плями
	if SettingsManager.reduced_motion:
		spot.modulate.a = 0.0
		_update_progress()
		_brighten_animal()
		if _cleaned >= _total_spots:
			_on_round_complete()
	else:
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(spot, "scale", Vector2(1.5, 1.5), 0.25)
		tw.tween_property(spot, "modulate:a", 0.0, 0.25)
		_update_progress()
		## Прогресивне освітлення тварини
		_brighten_animal()
		if _cleaned >= _total_spots:
			tw.chain().tween_callback(_on_round_complete)


func _brighten_animal() -> void:
	if not _animal_sprite or not is_instance_valid(_animal_sprite):
		return
	## Лінійна інтерполяція від _initial_modulate до 1.0
	var ratio: float = clampf(float(_cleaned) / float(maxi(_total_spots, 1)), 0.0, 1.0)
	var brightness: float = lerpf(_initial_modulate, 1.0, ratio)
	if SettingsManager.reduced_motion:
		_animal_sprite.modulate = Color(brightness, brightness, brightness, 1.0)
	else:
		var tw: Tween = create_tween()
		tw.tween_property(_animal_sprite, "modulate",
			Color(brightness, brightness, brightness, 1.0), 0.3)


## ---- Round management ----

func _on_round_complete() -> void:
	_input_locked = true
	_wiping = false
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	## Тварина блискуче чиста!
	if _animal_sprite and not SettingsManager.reduced_motion:
		var tw: Tween = create_tween()
		tw.tween_property(_animal_sprite, "scale", Vector2(0.47, 0.47), 0.15)
		tw.tween_property(_animal_sprite, "scale", Vector2(0.42, 0.42), 0.15)
	var round_d: float = 0.15 if SettingsManager.reduced_motion else 1.0
	var tw2: Tween = create_tween()
	tw2.tween_interval(round_d)
	tw2.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round())


func _clear_round() -> void:
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_spots.clear()
	_animal_sprite = null
	_progress_bar = null
	_progress_fill = null


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": _total_rounds, "earned_stars": earned})


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
	if _input_locked or _game_over or _spots.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	for spot: Node2D in _spots:
		if is_instance_valid(spot) and not spot.get_meta("is_clean", false):
			_pulse_node(spot, 1.3)
			break
	_reset_idle_timer()
