extends BaseMiniGame

## Shadow Match — перетягни кольорову тварину на правильний силует.

const MAX_ROUNDS: int = 5
const SHADOW_SCALE: Vector2 = Vector2(0.30, 0.30)
const ANIMAL_SCALE: Vector2 = Vector2(0.35, 0.35)
const SLOT_Y_FACTOR: float = 0.3
const ANIMAL_Y_FACTOR: float = 0.78
const MARGIN_X: float = 0.1
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0

var _is_toddler: bool = false
var _slots_per_round: int = 4
var _drag: UniversalDrag = null
var _current_round: int = 0
var _target_id: String = ""
var _slots: Array[Node2D] = []
var _active_animal: Node2D = null
var _animal_origin: Vector2 = Vector2.ZERO
var _start_time: float = 0.0
var _silhouette_shader: Shader = null
var _used_indices: Array[int] = []
var _idle_timer: SceneTreeTimer = null


func _ready() -> void:
	game_id = "shadow_match"
	bg_theme = "meadow"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_silhouette_shader = load("res://assets/shaders/silhouette.gdshader")
	_drag = UniversalDrag.new(self, $DragTrail if has_node("DragTrail") else null)
	if _is_toddler:
		_drag.snap_radius_override = TODDLER_SNAP_RADIUS
	_drag.item_picked_up.connect(_on_item_picked)
	_drag.item_dropped_on_target.connect(_on_item_dropped_on_target)
	_drag.item_dropped_on_empty.connect(_on_item_dropped_on_empty)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
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


func _generate_round() -> void:
	_cleanup_round()
	if _is_toddler:
		_slots_per_round = _scale_by_round_i(3, 4, _current_round, MAX_ROUNDS)
	else:
		_slots_per_round = _scale_by_round_i(3, 5, _current_round, MAX_ROUNDS)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Обрати тварин за віковою групою
	var indices: Array[int] = _pick_random_indices(_slots_per_round)
	var pairs: Array[Dictionary] = []
	for idx: int in indices:
		pairs.append(GameData.ANIMALS_AND_FOOD[idx])
	## Обрати 1 як target
	var target_pair: Dictionary = pairs[randi() % pairs.size()]
	_target_id = target_pair.name
	## Створити силуети
	var slot_start_x: float = vp.x * MARGIN_X
	var slot_end_x: float = vp.x * (1.0 - MARGIN_X)
	var slot_spacing: float = (slot_end_x - slot_start_x) / float(maxi(_slots_per_round - 1, 1))
	var slot_y: float = vp.y * SLOT_Y_FACTOR
	for i: int in pairs.size():
		var pair: Dictionary = pairs[i]
		var sprite_path: String = "res://assets/sprites/animals/%s.png" % pair.name
		if not ResourceLoader.exists(sprite_path):
			push_warning("ShadowMatch: Missing sprite: " + sprite_path)
			continue
		var tex: Texture2D = load(sprite_path)
		if not tex:
			push_warning("ShadowMatch: текстуру '%s' не знайдено" % sprite_path)
			continue
		var shadow: Sprite2D = Sprite2D.new()
		shadow.texture = tex
		shadow.scale = SHADOW_SCALE
		shadow.name = pair.name
		shadow.position = Vector2(slot_start_x + float(i) * slot_spacing, slot_y)
		## Застосувати шейдер силуету
		if _silhouette_shader:
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = _silhouette_shader
			shadow.material = mat
		add_child(shadow)
		_slots.append(shadow)
	## Створити активну кольорову тварину
	var animal_path: String = "res://assets/sprites/animals/%s.png" % _target_id
	var animal_tex: Texture2D = null
	if not ResourceLoader.exists(animal_path):
		push_warning("ShadowMatch: Missing sprite: " + animal_path)
	else:
		animal_tex = load(animal_path)
	if animal_tex:
		_active_animal = Sprite2D.new()
		_active_animal.texture = animal_tex
		_active_animal.scale = ANIMAL_SCALE
		_animal_origin = Vector2(vp.x / 2.0, vp.y * ANIMAL_Y_FACTOR)
		_active_animal.position = _animal_origin
		_active_animal.name = "ActiveAnimal"
		add_child(_active_animal)
		_active_animal.material = GameData.create_premium_material(
			0.05, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.12, 0.30, 0.25)
	## Каскадний вхід елементів (LAW 29 R3)
	var spawn_nodes: Array = []
	for s: Node2D in _slots:
		spawn_nodes.append(s)
	if _active_animal:
		spawn_nodes.append(_active_animal)
	_staggered_spawn(spawn_nodes, 0.08)
	## Налаштувати drag
	_drag.draggable_items.clear()
	if _active_animal:
		_drag.draggable_items.append(_active_animal)
	_drag.drop_targets.clear()
	for s: Node2D in _slots:
		_drag.drop_targets.append(s)
	var unlock_delay: float = 0.15 if SettingsManager.reduced_motion \
		else float(spawn_nodes.size()) * 0.08 + 0.3
	var tw: Tween = _create_game_tween()
	tw.tween_interval(unlock_delay)
	tw.tween_callback(func() -> void:
		_drag.enabled = true
		_input_locked = false
		_reset_idle_timer())
	## Магнітний асист для тоддлерів
	if _is_toddler and _active_animal:
		_drag.magnetic_assist = true
		for s: Node2D in _slots:
			if s.name == _target_id:
				_drag.set_correct_pairs({_active_animal: s})
				break
	## Анімація появи — staggered fade in
	_animate_round_entrance()
	_reset_idle_timer()


func _pick_random_indices(count: int) -> Array[int]:
	var all: Array[int] = []
	for i: int in GameData.ANIMALS_AND_FOOD.size():
		if not _used_indices.has(i):
			all.append(i)
	all.shuffle()
	if all.size() < count:
		_used_indices.clear()
		all.clear()
		for i: int in GameData.ANIMALS_AND_FOOD.size():
			all.append(i)
		all.shuffle()
	var picked: Array[int] = []
	for i: int in mini(count, all.size()):
		picked.append(all[i])
		_used_indices.append(all[i])
	return picked


func _animate_round_entrance() -> void:
	if SettingsManager.reduced_motion:
		for slot: Node2D in _slots:
			slot.modulate.a = 1.0
			slot.scale = SHADOW_SCALE
		if _active_animal:
			_active_animal.modulate.a = 1.0
		return
	for i: int in _slots.size():
		var slot: Node2D = _slots[i]
		slot.modulate.a = 0.0
		slot.scale = SHADOW_SCALE * 0.5
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(slot, "modulate:a", 1.0, 0.3).set_delay(float(i) * 0.1)
		tw.tween_property(slot, "scale", SHADOW_SCALE, 0.3).set_delay(float(i) * 0.1)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _active_animal:
		_active_animal.modulate.a = 0.0
		var delay: float = float(_slots.size()) * 0.1
		var tw: Tween = create_tween()
		tw.tween_property(_active_animal, "modulate:a", 1.0, 0.3).set_delay(delay)


func _on_item_picked(_item: Node2D) -> void:
	AudioManager.play_sfx("click")
	_reset_idle_timer()


func _on_item_dropped_on_target(item: Node2D, target: Node2D) -> void:
	_input_locked = true
	_drag.enabled = false
	if target.name == _target_id:
		_handle_correct(item, target)
	else:
		_handle_wrong(item, target)


func _on_item_dropped_on_empty(item: Node2D) -> void:
	_drag.snap_back(item, _animal_origin)


func _handle_correct(item: Node2D, target: Node2D) -> void:
	_register_correct(item)
	VFXManager.spawn_success_ripple(target.global_position, Color(0.4, 1.0, 0.6, 0.6))
	if SettingsManager.reduced_motion:
		item.global_position = target.global_position
		item.scale = SHADOW_SCALE
		target.modulate = Color.WHITE
		var tw_rm: Tween = create_tween()
		tw_rm.tween_interval(0.15)
		tw_rm.finished.connect(_on_correct_finished)
		return
	## Тварина летить до силуету
	var tw: Tween = create_tween()
	tw.tween_property(item, "global_position", target.global_position, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "scale", SHADOW_SCALE, 0.2)
	tw.parallel().tween_property(target, "modulate", Color.WHITE, 0.2)
	## Squish bounce
	tw.tween_property(item, "scale", SHADOW_SCALE * Vector2(1.3, 0.7), 0.08)
	tw.tween_property(item, "scale", SHADOW_SCALE * Vector2(0.8, 1.2), 0.08)
	tw.tween_property(item, "scale", SHADOW_SCALE, 0.08)
	## Golden flash на силуеті (LAW 28 premium feedback)
	tw.tween_property(target, "modulate", Color(1.3, 1.15, 0.8), 0.12)
	tw.tween_property(target, "modulate", Color.WHITE, 0.25)
	## VFX sparkle на місці збігу
	VFXManager.spawn_match_sparkle(target.global_position)
	tw.tween_interval(0.3)
	tw.finished.connect(_on_correct_finished)


func _on_correct_finished() -> void:
	_current_round += 1
	if _current_round >= MAX_ROUNDS:
		_game_over = true
		_input_locked = true
		VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
		var earned: int = _calculate_stars(_errors)
		var stats: Dictionary = {
			"time_sec": elapsed,
			"errors": _errors,
			"rounds_played": _current_round,
			"earned_stars": earned,
		}
		finish_game(earned, stats)
	else:
		_generate_round()


func _handle_wrong(item: Node2D, target: Node2D) -> void:
	if _is_toddler:
		## Toddler: м'яке повернення без звуку помилки (A6)
		## Але _register_error() потрібен для scaffolding (A11)
		_register_error(item)
	else:
		_errors += 1
		_register_error(item)
	## Snap back тварину
	_drag.snap_back(item, _animal_origin)
	if SettingsManager.reduced_motion:
		_input_locked = false
		_drag.enabled = true
		_reset_idle_timer()
	else:
		## Силует трясе
		var orig_x: float = target.position.x
		var tw: Tween = create_tween()
		tw.tween_property(target, "position:x", orig_x - 6.0, 0.08)
		tw.tween_property(target, "position:x", orig_x + 6.0, 0.08)
		tw.tween_property(target, "position:x", orig_x - 3.0, 0.06)
		tw.tween_property(target, "position:x", orig_x, 0.06)
		tw.finished.connect(func() -> void:
			_input_locked = false
			_drag.enabled = true
			_reset_idle_timer()
		)


func _cleanup_round() -> void:
	for slot: Node2D in _slots:
		if is_instance_valid(slot):
			slot.queue_free()
	_slots.clear()
	if _active_animal and is_instance_valid(_active_animal):
		_active_animal.queue_free()
		_active_animal = null
	_drag.clear_drag()
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()


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
	if _input_locked or _game_over or not is_instance_valid(_active_animal):
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		## A10 Lvl2: tutorial hand — показати правильну відповідь чітко
		var demo: Dictionary = get_tutorial_demo()
		if demo.has("to"):
			var target_pos: Vector2 = demo.get("to", Vector2.ZERO)
			for slot: Node2D in _slots:
				if is_instance_valid(slot) and slot.global_position.distance_to(target_pos) < 10.0:
					_pulse_node(slot, 1.3)
					## Яскравий flash на правильному силуеті
					if not SettingsManager.reduced_motion:
						var flash_tw: Tween = create_tween()
						flash_tw.tween_property(slot, "modulate", Color(1.5, 1.3, 0.7, 1.0), 0.15)
						flash_tw.tween_property(slot, "modulate", Color.WHITE, 0.3)
					break
		_pulse_node(_active_animal, 1.3)
		_reset_idle_timer()
		return
	## Пульсація активної тварини
	_pulse_node(_active_animal, 1.15)
	_reset_idle_timer()


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("SHADOW_TUTORIAL_TODDLER")
	return tr("SHADOW_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	if not is_instance_valid(_active_animal) or _slots.is_empty():
		return {}
	## Знайти правильний слот для активної тварини
	for slot: Node2D in _slots:
		if is_instance_valid(slot) and slot.name == _target_id:
			return {"type": "drag", "from": _active_animal.global_position, "to": slot.global_position}
	return {}
