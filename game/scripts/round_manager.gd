class_name RoundManager
extends RefCounted

# Dynamic scale to prevent overlap at higher item counts (512px sprites)
const _SCALE_BY_COUNT: Dictionary = {
	3: {"animal": Vector2(0.25, 0.25), "food": Vector2(0.18, 0.18)},
	4: {"animal": Vector2(0.20, 0.20), "food": Vector2(0.15, 0.15)},
	5: {"animal": Vector2(0.17, 0.17), "food": Vector2(0.12, 0.12)},
}

signal round_started
signal match_made(animal: Node2D, food: Node2D)
signal game_won(stats: Dictionary)
signal mini_game_finished(stats: Dictionary)
signal combo_changed(new_combo: int)

var current_round_animals: Array[Node2D] = []
var current_round_food: Array[Node2D] = []
var food_original_positions: Dictionary[Node2D, Vector2] = {}
var selected_indices: Array[int] = []
var rounds_played: int = 0
var errors_made: int = 0
var current_combo: int = 0
var max_combo: int = 0
var earned_stars: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _scene_root: Node2D
var _start_time_ms: int = 0
var _animal_pool: Dictionary = {}
var _food_pool: Dictionary = {}
var _sway_material: ShaderMaterial = null
var _animator: AnimalAnimator = null


func _init(scene_root: Node2D) -> void:
	_scene_root = scene_root
	_rng.randomize()
	_sway_material = GameData.create_sway_material()
	_animator = AnimalAnimator.new(scene_root)


func get_animator() -> AnimalAnimator:
	return _animator


func get_target_pairs() -> int:
	if rounds_played < 3:
		return 3
	elif rounds_played < 7:
		return 4
	else:
		return 5


func start_new_round() -> void:
	_cleanup_current_round()
	if _start_time_ms == 0:
		_start_time_ms = Time.get_ticks_msec()

	var target: int = get_target_pairs()
	assert(GameData.ANIMALS_AND_FOOD.size() >= target,
		"Pool too small: need %d, have %d" % [target, GameData.ANIMALS_AND_FOOD.size()])
	if GameData.ANIMALS_AND_FOOD.size() < target:
		push_warning("RoundManager: not enough animals — need %d, have %d" % [target, GameData.ANIMALS_AND_FOOD.size()])
		return

	selected_indices = []
	var attempts: int = 0
	while selected_indices.size() < target and attempts < 100:
		attempts += 1
		var idx: int = _rng.randi_range(0, GameData.ANIMALS_AND_FOOD.size() - 1)
		if selected_indices.has(idx):
			continue
		selected_indices.append(idx)

	var food_indices: Array[int] = []
	for idx: int in selected_indices:
		food_indices.append(idx)
	food_indices.shuffle()
	# Derangement: ensure no food is directly below its paired animal
	var max_derange: int = 20
	while _has_aligned_pair(selected_indices, food_indices) and max_derange > 0:
		food_indices.shuffle()
		max_derange -= 1

	for i: int in range(target):
		_spawn_animal(GameData.ANIMALS_AND_FOOD[selected_indices[i]], _get_spawn_position(i, target, GameData.ANIMAL_Y_FACTOR), target)
		_spawn_food(GameData.ANIMALS_AND_FOOD[food_indices[i]], _get_spawn_position(i, target, GameData.FOOD_Y_FACTOR), target)

	round_started.emit()


func try_match(food: Node2D, target_animal: Node2D) -> bool:
	var expected_food: String = GameData.find_correct_food_name(target_animal.name)
	if food.get_meta("food_type") != expected_food:
		errors_made += 1
		current_combo = 0
		combo_changed.emit(0)
		return false

	food_original_positions.erase(food)
	current_round_animals.erase(target_animal)
	current_round_food.erase(food)

	rounds_played += 1
	current_combo += 1
	if current_combo > max_combo:
		max_combo = current_combo
	earned_stars += 1
	combo_changed.emit(current_combo)

	if rounds_played >= GameData.MAX_ROUNDS:
		mini_game_finished.emit(_get_stats())
	elif current_round_animals.is_empty() and _all_animals_used():
		game_won.emit(_get_stats())

	match_made.emit(target_animal, food)
	return true


func reposition_all(smooth: bool = false) -> void:
	var total: int = current_round_animals.size()
	for i: int in range(total):
		current_round_animals[i].scale = _get_scale_for_count(total, false)
		var new_pos: Vector2 = _get_spawn_position(i, total, GameData.ANIMAL_Y_FACTOR)
		if smooth:
			_scene_root.create_tween().tween_property(current_round_animals[i], "position", new_pos, 0.3)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			current_round_animals[i].position = new_pos
		_animator.notify_interaction(current_round_animals[i])
	for i: int in range(current_round_food.size()):
		current_round_food[i].scale = _get_scale_for_count(total, true)
		var new_pos: Vector2 = _get_spawn_position(i, total, GameData.FOOD_Y_FACTOR)
		if smooth:
			_scene_root.create_tween().tween_property(current_round_food[i], "position", new_pos, 0.3)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			current_round_food[i].position = new_pos
		food_original_positions[current_round_food[i]] = new_pos


func reset_combo() -> void:
	if current_combo > 0:
		current_combo = 0
		combo_changed.emit(0)


func add_new_pair_if_needed() -> void:
	if not _all_animals_used() and current_round_animals.size() < get_target_pairs():
		_add_new_animal_and_food()


func return_food_to_origin(food: Node2D) -> Tween:
	if food and food_original_positions.has(food):
		var tween: Tween = _scene_root.create_tween()
		tween.tween_property(food, "position", food_original_positions[food], 0.3)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return tween
	return null


func _get_stats() -> Dictionary:
	var elapsed_ms: int = Time.get_ticks_msec() - _start_time_ms
	return {"time_sec": elapsed_ms / 1000.0, "errors": errors_made, "rounds_played": rounds_played, "earned_stars": earned_stars, "max_combo": max_combo}


func _all_animals_used() -> bool:
	for i: int in range(GameData.ANIMALS_AND_FOOD.size()):
		if not selected_indices.has(i):
			return false
	return true


func _add_new_animal_and_food() -> void:
	var target: int = get_target_pairs()

	var available_indices: Array[int] = []
	for i: int in range(GameData.ANIMALS_AND_FOOD.size()):
		if not selected_indices.has(i):
			available_indices.append(i)

	if available_indices.is_empty():
		return

	# Add pairs until we reach target count or run out of available animals
	while current_round_animals.size() < target and not available_indices.is_empty():
		var pick: int = _rng.randi_range(0, available_indices.size() - 1)
		var new_idx: int = available_indices[pick]
		available_indices.remove_at(pick)
		selected_indices.append(new_idx)
		var data: Dictionary = GameData.ANIMALS_AND_FOOD[new_idx]
		var spawn_index: int = current_round_animals.size()
		_spawn_animal(data, _get_spawn_position(spawn_index, target, GameData.ANIMAL_Y_FACTOR), target, true)
		_spawn_food(data, _get_spawn_position(spawn_index, target, GameData.FOOD_Y_FACTOR), target, true)

	# Shuffle food order to prevent vertical alignment with animals
	current_round_food.shuffle()
	reposition_all(true)


func _has_aligned_pair(animal_indices: Array[int], food_indices_arr: Array[int]) -> bool:
	for i: int in range(mini(animal_indices.size(), food_indices_arr.size())):
		if animal_indices[i] == food_indices_arr[i]:
			return true
	return false


func _get_scale_for_count(total_items: int, is_food: bool) -> Vector2:
	var key: String = "food" if is_food else "animal"
	if _SCALE_BY_COUNT.has(total_items):
		return _SCALE_BY_COUNT[total_items][key]
	return _SCALE_BY_COUNT[5][key]


func _get_spawn_position(index: int, total_items: int, y_factor: float) -> Vector2:
	var size: Vector2 = _scene_root.get_viewport_rect().size
	var max_width: float = size.x * 0.8
	var spacing: float = max_width / maxf(1.0, float(total_items))
	var start_x: float = (size.x - spacing * float(total_items - 1)) / 2.0
	var x: float = start_x + spacing * float(index)
	var y: float = size.y * y_factor
	return Vector2(x, y)




func recycle_animal(animal: Node2D) -> void:
	_animator.cleanup(animal)
	animal.visible = false
	animal.modulate = Color.WHITE
	animal.rotation = 0.0
	animal.scale = Vector2(0.35, 0.35)
	animal.z_index = 0
	var scene: PackedScene = animal.get_meta("_pool_scene", null)
	if scene:
		if not _animal_pool.has(scene):
			_animal_pool[scene] = []
		_animal_pool[scene].append(animal)


func recycle_food(food: Node2D) -> void:
	var label: Node = food.get_node_or_null("FoodLabel")
	if label:
		label.queue_free()
	food.visible = false
	food.modulate = Color.WHITE
	food.rotation = 0.0
	food.scale = Vector2(0.25, 0.25)
	food.z_index = 0
	var scene: PackedScene = food.get_meta("_pool_scene", null)
	if scene:
		if not _food_pool.has(scene):
			_food_pool[scene] = []
		_food_pool[scene].append(food)


func _get_or_create(pool: Dictionary, scene: PackedScene) -> Node2D:
	if pool.has(scene) and not pool[scene].is_empty():
		var node: Node2D = pool[scene].pop_back()
		return node
	var node: Node2D = scene.instantiate()
	node.set_meta("_pool_scene", scene)
	_scene_root.add_child(node)
	return node


func _spawn_animal(data: Dictionary, pos: Vector2, total_items: int, fade_in: bool = false) -> void:
	var scene: PackedScene = data.animal_scene
	var animal: Node2D = _get_or_create(_animal_pool, scene)
	animal.name = data.name
	animal.position = pos
	animal.scale = _get_scale_for_count(total_items, false)
	animal.visible = true
	animal.modulate = Color.WHITE
	_try_start_animation(animal)
	current_round_animals.append(animal)
	_animator.setup(animal)
	if fade_in:
		animal.modulate.a = 0.0
		_scene_root.create_tween().tween_property(animal, "modulate:a", 1.0, 0.3)


func _spawn_food(data: Dictionary, pos: Vector2, total_items: int, fade_in: bool = false) -> void:
	var scene: PackedScene = data.food_scene
	var food: Node2D = _get_or_create(_food_pool, scene)
	var food_name: String = GameData.get_food_name_from_scene(data.food_scene)
	food.set_meta("food_type", food_name)
	food.position = pos
	food.scale = _get_scale_for_count(total_items, true)
	food.visible = true
	food.modulate = Color.WHITE
	if fade_in:
		food.modulate.a = 0.0
		_scene_root.create_tween().tween_property(food, "modulate:a", 1.0, 0.3)
	current_round_food.append(food)
	food_original_positions[food] = food.position
	if _sway_material:
		food.material = _sway_material


func _cleanup_current_round() -> void:
	for animal: Node2D in current_round_animals:
		if is_instance_valid(animal):
			recycle_animal(animal)
	for food: Node2D in current_round_food:
		if is_instance_valid(food):
			recycle_food(food)
	current_round_animals.clear()
	current_round_food.clear()
	food_original_positions.clear()


func _try_start_animation(node: Node2D) -> void:
	if node is AnimatedSprite2D:
		var anim_sprite: AnimatedSprite2D = node as AnimatedSprite2D
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
			anim_sprite.play("idle")


func start_idle_bob(animal: Node2D) -> void:
	## Deprecated — анімація тепер в animal_alive.gdshader
	_animator.notify_interaction(animal)


func kill_idle_bob(_animal: Node2D) -> void:
	## Deprecated — анімація тепер в animal_alive.gdshader
	pass
