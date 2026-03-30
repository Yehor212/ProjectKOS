class_name UniversalDrag
extends RefCounted

## Універсальний drag-and-drop — працює з будь-якими масивами Node2D.
## Патерн: distance-based detection, kinematic tilt, elastic snap-back.

signal item_picked_up(item: Node2D)
signal item_dropped_on_target(item: Node2D, target: Node2D)
signal item_dropped_on_empty(item: Node2D)

const SNAP_RADIUS: float = 80.0
const TILT_FACTOR: float = 0.001
const TILT_MAX: float = 0.4
const TILT_LERP: float = 15.0
const DRAG_Z: int = 10

signal assist_proximity(target: Node2D, active: bool)

var draggable_items: Array[Node2D] = []
var drop_targets: Array[Node2D] = []
var enabled: bool = true
var snap_radius_override: float = 0.0
var magnetic_assist: bool = false
var _correct_pairs: Dictionary = {}
var _last_glow_target: Node2D = null

## Ghost preview: drop targets пульсують під час drag (industry standard, Endless Alphabet)
var show_drop_hints: bool = true
var _hint_tweens: Array[Tween] = []

var _scene_root: Node2D = null
var _drag_trail: CPUParticles2D = null
var _clicked: Node2D = null
var _offset: Vector2 = Vector2.ZERO
var _original_z: int = 0
var _original_scale: Vector2 = Vector2.ONE
var _last_mouse: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO
var _idle_tweens: Dictionary = {}
var _original_scales: Dictionary = {}
var _glow_tween: Tween = null
var _drag_shadow: Node2D = null
var idle_breathe: bool = true


func _init(scene_root: Node2D, trail: CPUParticles2D = null) -> void:
	_scene_root = scene_root
	_drag_trail = trail
	## Auto-create trail якщо не передано — velocity-responsive particle feedback
	if not _drag_trail and is_instance_valid(scene_root):
		_drag_trail = CPUParticles2D.new()
		_drag_trail.one_shot = false
		_drag_trail.emitting = false
		_drag_trail.amount = 8
		_drag_trail.lifetime = 0.4
		_drag_trail.direction = Vector2.ZERO
		_drag_trail.spread = 180.0
		_drag_trail.initial_velocity_min = 20.0
		_drag_trail.initial_velocity_max = 60.0
		_drag_trail.gravity = Vector2(0, 150)
		_drag_trail.scale_amount_min = 0.4
		_drag_trail.scale_amount_max = 1.0
		_drag_trail.color = Color(1, 1, 1, 0.3)
		_drag_trail.z_index = DRAG_Z - 1
		scene_root.add_child(_drag_trail)


func handle_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		if event.pressed and _clicked == null:
			_try_pick(event.position)
		elif not event.pressed and _clicked != null:
			_drop()
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed and _clicked == null:
			_try_pick(event.position)
		elif not event.pressed and _clicked != null:
			_drop()


func set_correct_pairs(pairs: Dictionary) -> void:
	_correct_pairs = pairs


func handle_process(delta: float) -> void:
	## Автоматичний breathe для idle елементів
	if idle_breathe and _clicked == null and enabled \
			and not (SettingsManager and SettingsManager.reduced_motion):
		for item: Node2D in draggable_items:
			if not is_instance_valid(item) or not item.visible:
				continue
			## Пропустити предмети під час stagger анімації (scale ще не стабільний)
			if item.scale.length() < 1.3 and item.scale.length() > 0.0 \
					and absf(item.scale.x - 1.0) < 0.05:
				if not _original_scales.has(item):
					_original_scales[item] = item.scale  ## Зберігаємо РЕАЛЬНИЙ scale, не ONE
				if not _idle_tweens.has(item):
					_start_breathe_for(item)
	if _clicked == null or not enabled:
		return
	var mouse: Vector2 = _scene_root.get_global_mouse_position()
	_drag_velocity = (mouse - _last_mouse) / maxf(delta, 0.001)
	_last_mouse = mouse
	_clicked.global_position = mouse + _offset
	## Магнітний асист — лагідне притягування до правильної цілі (тоддлер)
	if magnetic_assist and _correct_pairs.has(_clicked):
		var correct_t: Node2D = _correct_pairs[_clicked]
		if is_instance_valid(correct_t):
			var radius: float = snap_radius_override if snap_radius_override > 0.0 else SNAP_RADIUS
			var dist: float = _clicked.global_position.distance_to(correct_t.global_position)
			if dist < radius * 0.7:
				_clicked.global_position = _clicked.global_position.lerp(
					correct_t.global_position, 0.3 * delta * 10.0)
				_offset = _clicked.global_position - mouse
				if _last_glow_target != correct_t:
					if _last_glow_target:
						assist_proximity.emit(_last_glow_target, false)
						_kill_glow_tween()
					assist_proximity.emit(correct_t, true)
					_last_glow_target = correct_t
					_start_glow_tween(correct_t)
			elif _last_glow_target == correct_t:
				assist_proximity.emit(correct_t, false)
				_kill_glow_tween()
				_last_glow_target = null
	## Кінематичний нахил
	var rot: float = clampf(_drag_velocity.x * TILT_FACTOR, -TILT_MAX, TILT_MAX)
	_clicked.rotation = lerpf(_clicked.rotation, rot, TILT_LERP * delta)
	## Оновити trail — velocity-responsive particle feedback
	if _drag_trail:
		_drag_trail.global_position = _clicked.global_position
		var speed: float = _drag_velocity.length()
		_drag_trail.emitting = speed > 20.0
		_drag_trail.amount = clampi(int(speed / 40.0), 4, 16)
		_drag_trail.initial_velocity_max = clampf(speed * 0.3, 30.0, 100.0)
	## Shadow follows item with increasing offset (lift effect)
	if _drag_shadow and is_instance_valid(_drag_shadow):
		_drag_shadow.global_position = _clicked.global_position + Vector2(3, 12)
		_drag_shadow.scale = Vector2(1.15, 0.7)
		_drag_shadow.modulate.a = 0.8


func snap_back(item: Node2D, origin: Vector2) -> Tween:
	var tw: Tween = _scene_root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(item, "global_position", origin, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "rotation", 0.0, 0.2)
	return tw


func clear_drag() -> void:
	stop_all_breathe()
	_kill_glow_tween()
	_original_scales.clear()
	if _clicked:
		_clicked.z_index = _original_z
		_clicked = null
	if _drag_trail:
		_drag_trail.emitting = false
	if _drag_shadow and is_instance_valid(_drag_shadow):
		_drag_shadow.queue_free()
		_drag_shadow = null


func start_idle_breathe() -> void:
	if not idle_breathe:
		return
	if SettingsManager and SettingsManager.reduced_motion:
		return
	for item: Node2D in draggable_items:
		if not is_instance_valid(item):
			continue
		_start_breathe_for(item)


func _start_breathe_for(item: Node2D) -> void:
	_stop_breathe_for(item)
	## Базуємо на збереженому scale (не ONE — тварини мають scale ≠ 1.0)
	var base_scale: Vector2 = _original_scales.get(item, item.scale)
	item.scale = base_scale
	var tw: Tween = _scene_root.create_tween().set_loops()
	var delay: float = randf_range(0.0, 1.5)
	tw.tween_interval(delay)
	tw.tween_property(item, "scale", base_scale * 1.04, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(item, "scale", base_scale, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tweens[item] = tw


func _stop_breathe_for(item: Node2D) -> void:
	if _idle_tweens.has(item):
		var old_tw: Tween = _idle_tweens[item]
		if old_tw and old_tw.is_valid():
			old_tw.kill()
		_idle_tweens.erase(item)


func _start_glow_tween(target: Node2D) -> void:
	_kill_glow_tween()
	if SettingsManager and SettingsManager.reduced_motion:
		return
	if not is_instance_valid(target):
		return
	var base_s: Vector2 = target.scale  ## Зберігаємо РЕАЛЬНИЙ scale target
	_glow_tween = _scene_root.create_tween().set_loops()
	_glow_tween.tween_property(target, "scale", base_s * 1.05, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_property(target, "scale", base_s, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_glow_tween() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = null


func stop_all_breathe() -> void:
	for item: Node2D in _idle_tweens.keys():
		_stop_breathe_for(item)
	_idle_tweens.clear()


func _try_pick(screen_pos: Vector2) -> void:
	var mouse: Vector2 = _scene_root.get_global_mouse_position()
	var best: Node2D = null
	var radius: float = snap_radius_override if snap_radius_override > 0.0 else SNAP_RADIUS
	var best_dist: float = radius
	for item: Node2D in draggable_items:
		if not is_instance_valid(item) or not item.visible:
			continue
		var d: float = mouse.distance_to(item.global_position)
		if d < best_dist:
			best_dist = d
			best = item
	if best == null:
		return
	_stop_breathe_for(best)
	_clicked = best
	_offset = best.global_position - mouse
	_original_z = best.z_index
	_original_scale = best.scale
	_last_mouse = mouse
	best.z_index = DRAG_Z
	## Dynamic drag shadow — detaches and grows when lifted (premium 2.5D)
	if is_instance_valid(_scene_root):
		_drag_shadow = Node2D.new()
		_drag_shadow.z_index = DRAG_Z - 2
		_scene_root.add_child(_drag_shadow)
		_drag_shadow.global_position = best.global_position + Vector2(0, 8)
		_drag_shadow.draw.connect(func() -> void:
			if not is_instance_valid(_drag_shadow):
				return
			var sz: float = 40.0
			_drag_shadow.draw_circle(Vector2.ZERO, sz, Color(0, 0, 0, 0.12))
			_drag_shadow.draw_circle(Vector2.ZERO, sz * 0.6, Color(0, 0, 0, 0.06))
		)
		_drag_shadow.queue_redraw()
	## Particle feedback при захваті (research: "every tap = sound + wiggle + pop")
	VFXManager.spawn_snap_pulse(best.global_position)
	## Squish pick-up з anticipation (squash down → stretch up → settle)
	var tw: Tween = _scene_root.create_tween()
	tw.tween_property(best, "scale", _original_scale * Vector2(1.1, 0.9), 0.04)
	tw.tween_property(best, "scale", _original_scale * Vector2(0.85, 1.15), 0.06)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(best, "scale", _original_scale, 0.08)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_start_drop_hints()
	item_picked_up.emit(best)


func _drop() -> void:
	if _clicked == null:
		return
	if _last_glow_target:
		assist_proximity.emit(_last_glow_target, false)
		_kill_glow_tween()
		_last_glow_target = null
	_stop_drop_hints()
	var item: Node2D = _clicked
	_clicked = null
	item.z_index = _original_z
	item.rotation = 0.0
	if _drag_trail:
		_drag_trail.emitting = false
	## Cleanup drag shadow
	if _drag_shadow and is_instance_valid(_drag_shadow):
		_drag_shadow.queue_free()
		_drag_shadow = null
	## Squish drop
	var tw: Tween = _scene_root.create_tween()
	tw.tween_property(item, "scale", _original_scale * Vector2(1.3, 0.7), 0.06)
	tw.tween_property(item, "scale", _original_scale, 0.08)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## Знайти target
	var target: Node2D = _find_target(item.global_position)
	if target:
		_stop_breathe_for(item)
		VFXManager.spawn_snap_pulse(item.global_position)
		JuicyEffects.touch_wobble(target, _scene_root, 0.6)
		item_dropped_on_target.emit(item, target)
	else:
		item_dropped_on_empty.emit(item)
		## Перезапустити breathe після snap-back
		if idle_breathe:
			_scene_root.get_tree().create_timer(0.4).timeout.connect(
				func() -> void:
					if is_instance_valid(item) and item.visible:
						_start_breathe_for(item)
			)


## ---- Ghost preview: drop targets пульсують під час drag ----


func _start_drop_hints() -> void:
	_stop_drop_hints()
	if not show_drop_hints:
		return
	for t: Node2D in drop_targets:
		if not is_instance_valid(t) or not t.visible:
			continue
		if not is_instance_valid(_scene_root):
			continue
		var tw: Tween = _scene_root.create_tween().set_loops()
		tw.tween_property(t, "modulate:a", 0.5, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(t, "modulate:a", 1.0, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_hint_tweens.append(tw)


func _stop_drop_hints() -> void:
	for tw: Tween in _hint_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_hint_tweens.clear()
	for t: Node2D in drop_targets:
		if is_instance_valid(t):
			t.modulate.a = 1.0


func _find_target(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var radius: float = snap_radius_override if snap_radius_override > 0.0 else SNAP_RADIUS
	var best_dist: float = radius
	for t: Node2D in drop_targets:
		if not is_instance_valid(t) or not t.visible:
			continue
		var d: float = pos.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best = t
	return best
