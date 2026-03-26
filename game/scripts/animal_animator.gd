class_name AnimalAnimator
extends RefCounted

## State machine для "живих" тварин — керує шейдером animal_alive.gdshader.
## Стани: IDLE, EXCITED, HAPPY, SAD, SLEEPY. Per-animal через meta.

enum State { IDLE, EXCITED, HAPPY, SAD, SLEEPY }

const SLEEP_TIMEOUT: float = 8.0
const BLINK_MIN: float = 3.0
const BLINK_MAX: float = 6.0
const PROXIMITY_RADIUS: float = 150.0

## Per-animal personality — ключі = імена shader uniform, значення = override.
## Пусті {} = всі дефолти шейдера. Blink zone відкалібровано по реальних PNG.
const PERSONALITY: Dictionary = {
	## --- Очі в стандартній зоні (0.18-0.32), мінімальні overrides ---
	"Bear": {},
	"Panda": {"sway_amplitude": 3.5, "breathe_amount": 2.5},
	"Cat": {"ear_wiggle_amount": 1.5, "ear_wiggle_speed": 3.5},
	"Crocodile": {"sway_amplitude": 3.0, "breathe_speed": 0.6},
	## --- Очі трохи нижче → розширити blink_y_max ---
	"Dog": {"blink_y_max": 0.36},
	"Bunny": {"blink_y_max": 0.40, "ear_wiggle_amount": 1.5, "ear_wiggle_speed": 3.0},
	"Cow": {"blink_y_max": 0.36, "sway_amplitude": 3.0, "breathe_amount": 2.5, "breathe_speed": 0.6},
	"Deer": {"blink_y_max": 0.38},
	"Lion": {"blink_y_max": 0.38, "sway_amplitude": 4.0, "head_bob_amount": 1.0},
	"Horse": {"blink_y_max": 0.38, "sway_amplitude": 4.0, "breathe_speed": 0.6},
	"Goat": {"blink_y_max": 0.38, "ear_wiggle_amount": 0.5},
	"Monkey": {"blink_y_max": 0.38, "ear_wiggle_amount": 0.5},
	"Squirrel": {"blink_y_max": 0.38, "breathe_speed": 1.0, "ear_wiggle_amount": 1.2},
	"Chicken": {"blink_y_max": 0.34, "ear_wiggle_amount": 1.8, "ear_wiggle_speed": 3.5, "breathe_speed": 1.0},
	## --- Очі ВИСОКО (Frog) → зона blink вгору ---
	"Frog": {"blink_y_min": 0.08, "blink_y_max": 0.25, "breathe_amount": 3.0, "head_bob_amount": 2.0, "breathe_speed": 1.0},
	## --- Очі НИЗЬКО (Mouse, Hedgehog) → зона blink вниз ---
	"Mouse": {"blink_y_min": 0.30, "blink_y_max": 0.45, "ear_wiggle_amount": 2.0, "ear_wiggle_speed": 3.5, "breathe_speed": 1.2, "sway_amplitude": 6.0},
	"Hedgehog": {"blink_y_min": 0.30, "blink_y_max": 0.45, "ear_wiggle_amount": 0.3, "breathe_amount": 2.5, "sway_amplitude": 3.0},
	## --- Спеціальні типи тіла ---
	"Elephant": {"blink_y_max": 0.38, "sway_amplitude": 3.5, "breathe_amount": 3.0, "breathe_speed": 0.5, "ear_wiggle_amount": 0.3, "head_bob_speed": 0.8},
	"Penguin": {"ear_wiggle_amount": 0.0, "sway_amplitude": 6.0, "sway_frequency": 2.0, "breathe_amount": 2.5, "breathe_speed": 0.7},
}

var _base_material: ShaderMaterial = null
var _scene_root: Node2D = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(scene_root: Node2D) -> void:
	_scene_root = scene_root
	_rng.randomize()
	_base_material = GameData.create_alive_material()


func setup(animal: Node2D) -> void:
	if not _base_material:
		push_warning("AnimalAnimator: alive material відсутній")
		return
	var mat: ShaderMaterial = _base_material.duplicate() as ShaderMaterial
	animal.material = mat
	animal.set_meta("_alive_mat", mat)
	animal.set_meta("_alive_state", State.IDLE)
	animal.set_meta("_sleep_timer", 0.0)
	_apply_personality(animal.name, mat)
	_start_blink_loop(animal)


func _apply_personality(anim_name: String, mat: ShaderMaterial) -> void:
	var params: Dictionary = PERSONALITY.get(anim_name, {})
	for key: String in params:
		mat.set_shader_parameter(key, params[key])


func cleanup(animal: Node2D) -> void:
	var mat: ShaderMaterial = _get_mat(animal)
	if mat:
		mat.set_shader_parameter("squish", 0.0)
		mat.set_shader_parameter("hop", 0.0)
		mat.set_shader_parameter("excitement", 1.0)
		mat.set_shader_parameter("glow_intensity", 0.0)
		mat.set_shader_parameter("blink", 0.0)
		mat.set_shader_parameter("sleep_factor", 0.0)
	animal.set_meta("_alive_state", State.IDLE)
	animal.set_meta("_sleep_timer", 0.0)


func set_excited(animal: Node2D, on: bool) -> void:
	var mat: ShaderMaterial = _get_mat(animal)
	if not mat:
		return
	var state: int = animal.get_meta("_alive_state", State.IDLE)
	if on and (state == State.IDLE or state == State.SLEEPY):
		if state == State.SLEEPY:
			_wake_up(animal)
		animal.set_meta("_alive_state", State.EXCITED)
		var tw: Tween = _scene_root.create_tween().set_parallel(true)
		tw.tween_property(mat, "shader_parameter/excitement", 2.0, 0.2)
		tw.tween_property(mat, "shader_parameter/glow_intensity", 0.4, 0.2)
	elif not on and state == State.EXCITED:
		animal.set_meta("_alive_state", State.IDLE)
		var tw: Tween = _scene_root.create_tween().set_parallel(true)
		tw.tween_property(mat, "shader_parameter/excitement", 1.0, 0.3)
		tw.tween_property(mat, "shader_parameter/glow_intensity", 0.0, 0.3)


func play_happy(animal: Node2D) -> void:
	var mat: ShaderMaterial = _get_mat(animal)
	if not mat:
		return
	notify_interaction(animal)
	animal.set_meta("_alive_state", State.HAPPY)
	## Squish + hop + glow flash
	var tw: Tween = _scene_root.create_tween()
	tw.tween_property(mat, "shader_parameter/squish", -0.3, 0.06)
	tw.tween_property(mat, "shader_parameter/hop", 15.0, 0.1)
	tw.parallel().tween_property(mat, "shader_parameter/squish", 0.2, 0.08)
	tw.parallel().tween_property(mat, "shader_parameter/glow_intensity", 0.6, 0.1)
	tw.tween_property(mat, "shader_parameter/hop", 0.0, 0.2)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "shader_parameter/squish", 0.0, 0.15)
	tw.tween_property(mat, "shader_parameter/glow_intensity", 0.0, 0.4)
	tw.finished.connect(func() -> void:
		if is_instance_valid(animal):
			animal.set_meta("_alive_state", State.IDLE)
	)


func play_sad(animal: Node2D) -> void:
	var mat: ShaderMaterial = _get_mat(animal)
	if not mat:
		return
	notify_interaction(animal)
	animal.set_meta("_alive_state", State.SAD)
	## Excitement spike = shake effect
	var tw: Tween = _scene_root.create_tween()
	tw.tween_property(mat, "shader_parameter/excitement", 3.0, 0.05)
	tw.tween_property(mat, "shader_parameter/excitement", 1.0, 0.4)
	tw.finished.connect(func() -> void:
		if is_instance_valid(animal):
			animal.set_meta("_alive_state", State.IDLE)
	)


func update_sleep(animal: Node2D, delta: float) -> void:
	if not is_instance_valid(animal) or not animal.visible:
		return
	var state: int = animal.get_meta("_alive_state", State.IDLE)
	if state != State.IDLE:
		return
	var timer: float = animal.get_meta("_sleep_timer", 0.0) + delta
	animal.set_meta("_sleep_timer", timer)
	if timer >= SLEEP_TIMEOUT:
		_fall_asleep(animal)


func notify_interaction(animal: Node2D) -> void:
	animal.set_meta("_sleep_timer", 0.0)
	var state: int = animal.get_meta("_alive_state", State.IDLE)
	if state == State.SLEEPY:
		_wake_up(animal)


func is_sleeping(animal: Node2D) -> bool:
	return animal.get_meta("_alive_state", State.IDLE) == State.SLEEPY


func _fall_asleep(animal: Node2D) -> void:
	var mat: ShaderMaterial = _get_mat(animal)
	if not mat:
		return
	animal.set_meta("_alive_state", State.SLEEPY)
	var tw: Tween = _scene_root.create_tween()
	tw.tween_property(mat, "shader_parameter/sleep_factor", 1.0, 2.0)
	tw.parallel().tween_property(mat, "shader_parameter/blink", 0.7, 2.0)


func _wake_up(animal: Node2D) -> void:
	var mat: ShaderMaterial = _get_mat(animal)
	if not mat:
		return
	animal.set_meta("_alive_state", State.IDLE)
	animal.set_meta("_sleep_timer", 0.0)
	var tw: Tween = _scene_root.create_tween().set_parallel(true)
	tw.tween_property(mat, "shader_parameter/sleep_factor", 0.0, 0.5)
	tw.tween_property(mat, "shader_parameter/blink", 0.0, 0.3)


func _start_blink_loop(animal: Node2D) -> void:
	if not is_instance_valid(animal):
		return
	if not _scene_root.is_inside_tree():
		push_warning("AnimalAnimator: scene_root not in tree, skipping blink")
		return
	var delay: float = _rng.randf_range(BLINK_MIN, BLINK_MAX)
	_scene_root.get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_instance_valid(animal) or not animal.visible:
			return
		var mat: ShaderMaterial = _get_mat(animal)
		if not mat:
			return
		var state: int = animal.get_meta("_alive_state", State.IDLE)
		if state == State.SLEEPY:
			_start_blink_loop(animal)
			return
		var tw: Tween = _scene_root.create_tween()
		tw.tween_property(mat, "shader_parameter/blink", 1.0, 0.06)
		tw.tween_property(mat, "shader_parameter/blink", 0.0, 0.06)
		tw.finished.connect(func() -> void:
			_start_blink_loop(animal)
		)
	)


func _get_mat(animal: Node2D) -> ShaderMaterial:
	if not is_instance_valid(animal):
		return null
	return animal.get_meta("_alive_mat", null) as ShaderMaterial
