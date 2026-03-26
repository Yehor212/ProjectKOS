class_name DragController
extends RefCounted

signal food_dropped_on_animal(food: Node2D, animal: Node2D)
signal food_dropped_on_empty(food: Node2D)
signal food_picked_up

const _HIGHLIGHT_SCALE_FACTOR: float = 1.15
const _SNAP_RADIUS: float = 80.0
const _EXCITEMENT_RADIUS: float = 150.0
const _EXCITEMENT_AWAY_RADIUS: float = 200.0

var _scene_root: Node2D
var _round_manager: RoundManager

var _clicked: Node2D = null
var _offset: Vector2 = Vector2()
var _clicked_base_scale: Vector2 = Vector2.ONE

var _selected_food_index: int = 0
var _selected_animal_index: int = 0
var _keyboard_mode: bool = false

var _highlight_tweens: Array[Tween] = []
var _highlighted_food: Node2D = null
var _highlighted_animal: Node2D = null
var _food_base_scale: Vector2 = Vector2.ONE
var _animal_base_scale: Vector2 = Vector2.ONE
var _drag_trail: CPUParticles2D = null
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO
var _wobbled_animals: Dictionary = {}  ## Guard — одна wobble анімація за drag


func _init(scene_root: Node2D, round_manager: RoundManager) -> void:
	_scene_root = scene_root
	_round_manager = round_manager
	_drag_trail = scene_root.get_node_or_null("DragTrail") as CPUParticles2D
	## Auto-create trail якщо не знайдено у сцені
	if not _drag_trail:
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
		_drag_trail.z_index = 9
		_scene_root.add_child(_drag_trail)


func handle_input(event: InputEvent) -> void:
	if _scene_root.get_tree().paused:
		return
	if event is InputEventScreenTouch and event.index != 0:
		return
	if event is InputEventScreenDrag and event.index != 0:
		return
	if event is InputEventMouseButton and event.pressed:
		_keyboard_mode = false
		_update_highlight()
		_handle_mouse_press()
	elif event is InputEventMouseButton and not event.pressed:
		_handle_mouse_release()
	if event is InputEventKey and event.pressed:
		_handle_key_press(event)


func clear_highlight() -> void:
	_keyboard_mode = false
	_update_highlight()


func handle_process(delta: float) -> void:
	if _scene_root.get_tree().paused:
		return
	if _clicked:
		var mouse_pos: Vector2 = _scene_root.get_global_mouse_position()
		_clicked.global_position = mouse_pos + _offset
		if _drag_trail:
			_drag_trail.global_position = _clicked.global_position
		## Kinematic tilt: faster horizontal drag = more rotation
		if delta > 0.0:
			_drag_velocity = (mouse_pos - _last_mouse_pos) / delta
		_last_mouse_pos = mouse_pos
		var target_rot: float = clampf(_drag_velocity.x * 0.001, -0.4, 0.4)
		_clicked.rotation = lerpf(_clicked.rotation, target_rot, 15.0 * delta)
		## Velocity-responsive trail
		if _drag_trail:
			var speed: float = _drag_velocity.length()
			_drag_trail.emitting = speed > 20.0
			_drag_trail.amount = clampi(int(speed / 40.0), 4, 16)
			_drag_trail.initial_velocity_max = clampf(speed * 0.3, 30.0, 100.0)
		_update_proximity_excitement()
	else:
		_last_mouse_pos = _scene_root.get_global_mouse_position()
		_drag_velocity = Vector2.ZERO


func _handle_key_press(event: InputEventKey) -> void:
	var food_count: int = _round_manager.current_round_food.size()
	var animal_count: int = _round_manager.current_round_animals.size()
	if food_count == 0 or animal_count == 0:
		push_warning("DragController: arrays empty, skipping key press")
		return

	_clamp_indices()
	_keyboard_mode = true

	match event.keycode:
		KEY_LEFT:
			_selected_food_index = wrapi(_selected_food_index - 1, 0, food_count)
		KEY_RIGHT:
			_selected_food_index = wrapi(_selected_food_index + 1, 0, food_count)
		KEY_UP:
			_selected_animal_index = wrapi(_selected_animal_index - 1, 0, animal_count)
		KEY_DOWN:
			_selected_animal_index = wrapi(_selected_animal_index + 1, 0, animal_count)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_try_keyboard_match()
		_:
			return

	_clamp_indices()
	_update_highlight()


func _try_keyboard_match() -> void:
	var food: Node2D = _round_manager.current_round_food[_selected_food_index]
	var animal: Node2D = _round_manager.current_round_animals[_selected_animal_index]
	food_dropped_on_animal.emit(food, animal)

	_clamp_indices()


func _clamp_indices() -> void:
	var food_max: int = maxi(_round_manager.current_round_food.size() - 1, 0)
	_selected_food_index = clampi(_selected_food_index, 0, food_max)
	var animal_max: int = maxi(_round_manager.current_round_animals.size() - 1, 0)
	_selected_animal_index = clampi(_selected_animal_index, 0, animal_max)


func _update_highlight() -> void:
	for tw: Tween in _highlight_tweens:
		if tw.is_valid():
			tw.kill()
	_highlight_tweens.clear()

	if _highlighted_food and is_instance_valid(_highlighted_food):
		_highlighted_food.scale = _food_base_scale
	if _highlighted_animal and is_instance_valid(_highlighted_animal):
		_highlighted_animal.scale = _animal_base_scale
	_highlighted_food = null
	_highlighted_animal = null

	if not _keyboard_mode:
		return

	if not _round_manager.current_round_food.is_empty():
		_highlighted_food = _round_manager.current_round_food[_selected_food_index]
		_food_base_scale = _highlighted_food.scale
		var tw: Tween = _highlighted_food.create_tween()
		tw.tween_property(_highlighted_food, "scale", _food_base_scale * _HIGHLIGHT_SCALE_FACTOR, 0.1)
		_highlight_tweens.append(tw)
	if not _round_manager.current_round_animals.is_empty():
		_highlighted_animal = _round_manager.current_round_animals[_selected_animal_index]
		_animal_base_scale = _highlighted_animal.scale
		var tw: Tween = _highlighted_animal.create_tween()
		tw.tween_property(_highlighted_animal, "scale", _animal_base_scale * _HIGHLIGHT_SCALE_FACTOR, 0.1)
		_highlight_tweens.append(tw)



func _handle_mouse_press() -> void:
	var mouse_pos: Vector2 = _scene_root.get_global_mouse_position()
	var best: Node2D = null
	var best_dist: float = _SNAP_RADIUS
	for food_item: Node2D in _round_manager.current_round_food:
		var d: float = mouse_pos.distance_to(food_item.global_position)
		if d < best_dist:
			best_dist = d
			best = food_item
	if not best:
		return
	if _clicked:
		_round_manager.return_food_to_origin(_clicked)
	_clicked = best
	_clicked_base_scale = best.scale
	_offset = best.global_position - mouse_pos
	_last_mouse_pos = mouse_pos
	_drag_velocity = Vector2.ZERO
	food_picked_up.emit()
	best.z_index = 10
	_scene_root.move_child(best, _scene_root.get_child_count() - 1)
	var tw: Tween = _scene_root.create_tween()
	tw.tween_property(best, "scale", _clicked_base_scale * Vector2(0.8, 1.2), 0.1)
	if _drag_trail:
		_drag_trail.global_position = best.global_position
		_drag_trail.emitting = true


func _handle_mouse_release() -> void:
	if not _clicked:
		return
	_clear_all_excitement()
	_wobbled_animals.clear()
	if _drag_trail:
		_drag_trail.emitting = false
	_clicked.z_index = 0
	var drop_tw: Tween = _scene_root.create_tween()
	drop_tw.tween_property(_clicked, "scale", _clicked_base_scale * Vector2(1.3, 0.7), 0.08)
	drop_tw.tween_property(_clicked, "scale", _clicked_base_scale, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	drop_tw.parallel().tween_property(_clicked, "rotation", 0.0, 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	var target_animal: Node2D = _find_animal_under_food()
	if target_animal:
		food_dropped_on_animal.emit(_clicked, target_animal)
	else:
		food_dropped_on_empty.emit(_clicked)
	_clicked = null


func _find_animal_under_food() -> Node2D:
	var best: Node2D = null
	var best_dist: float = _SNAP_RADIUS
	for animal: Node2D in _round_manager.current_round_animals:
		var d: float = _clicked.global_position.distance_to(animal.global_position)
		if d < best_dist:
			best_dist = d
			best = animal
	return best


func _update_proximity_excitement() -> void:
	var animator: AnimalAnimator = _round_manager.get_animator()
	if not animator:
		return
	for animal: Node2D in _round_manager.current_round_animals:
		var dist: float = _clicked.global_position.distance_to(animal.global_position)
		if dist < _EXCITEMENT_RADIUS:
			animator.set_excited(animal, true)
			if not _wobbled_animals.has(animal):
				_wobbled_animals[animal] = true
				JuicyEffects.touch_wobble(animal, _scene_root, 0.4)
		elif dist > _EXCITEMENT_AWAY_RADIUS:
			animator.set_excited(animal, false)
			_wobbled_animals.erase(animal)


func _clear_all_excitement() -> void:
	var animator: AnimalAnimator = _round_manager.get_animator()
	if not animator:
		return
	for animal: Node2D in _round_manager.current_round_animals:
		animator.set_excited(animal, false)
