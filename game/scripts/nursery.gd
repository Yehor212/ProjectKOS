extends Node2D

## Майданчик — тваринки гуляють, реагують на дотик (без монет).

const CLICK_COOLDOWN: float = 2.0
const MIN_SCALE: float = 0.25
const MAX_SCALE: float = 0.38
const MARGIN_X: float = 100.0
const MARGIN_Y_TOP: float = 100.0
const MARGIN_Y_BOTTOM: float = 100.0
const LOCKED_MODULATE: Color = Color(0.0, 0.0, 0.0, 0.3)
const CLICK_AREA_RADIUS: float = 120.0
const ENTRANCE_STAGGER: float = 0.1
const ENTRANCE_DUR: float = 0.5

var _cooldowns: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _animator: AnimalAnimator = null
var _animal_sprites: Array[Node2D] = []


func _ready() -> void:
	_rng.randomize()
	_animator = AnimalAnimator.new(self)
	_apply_background()
	## Juicy button squish
	JuicyEffects.button_press_squish($BackButton, self)
	## A12: i18n — локалізація кнопки (tscn має hardcoded "Main Menu")
	$BackButton.text = tr("BTN_MENU")
	_spawn_animals()
	_animate_entrance()


func _apply_background() -> void:
	var bg: TextureRect = $Background as TextureRect
	if not bg:
		return
	## Premium background з grain (LAW 28)
	GameData.apply_premium_background(bg, "garden", SettingsManager.reduced_motion)
	GameData.add_bg_elements(self, "garden", SettingsManager.reduced_motion)


func _spawn_animals() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	for pair: Dictionary in GameData.ANIMALS_AND_FOOD:
		var animal_name: String = pair.name
		var is_unlocked: bool = ProgressManager.is_animal_unlocked(animal_name)

		var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
		if not ResourceLoader.exists(tex_path):
			push_warning("Nursery: текстура '%s' не знайдена" % tex_path)
			continue

		var strip_path: String = "res://assets/sprites/animals/%s_idle.png" % animal_name
		var sprite: Node2D
		if ResourceLoader.exists(strip_path):
			var anim: AnimatedSprite2D = AnimatedSprite2D.new()
			anim.sprite_frames = GameData.create_sprite_frames_from_strip(strip_path)
			anim.play("idle")
			sprite = anim
		else:
			var s2d: Sprite2D = Sprite2D.new()
			s2d.texture = load(tex_path)
			sprite = s2d
		sprite.name = animal_name

		var rand_x: float = _rng.randf_range(MARGIN_X, viewport_size.x - MARGIN_X)
		var rand_y: float = _rng.randf_range(MARGIN_Y_TOP, viewport_size.y - MARGIN_Y_BOTTOM)
		sprite.position = Vector2(rand_x, rand_y)

		var rand_scale: float = _rng.randf_range(MIN_SCALE, MAX_SCALE)
		sprite.scale = Vector2(rand_scale, rand_scale)

		if is_unlocked:
			sprite.modulate = Color.WHITE
			add_child(sprite)
			_animator.setup(sprite)
			_add_click_area(sprite, animal_name)
			_animal_sprites.append(sprite)
		else:
			sprite.modulate = LOCKED_MODULATE
			add_child(sprite)
			_animal_sprites.append(sprite)


func _animate_entrance() -> void:
	## Стагерована поява тваринок — pop-in з elastic bounce
	for i: int in _animal_sprites.size():
		var sprite: Node2D = _animal_sprites[i]
		var saved_scale: Vector2 = sprite.scale
		var saved_modulate: Color = sprite.modulate
		sprite.scale = Vector2.ZERO
		sprite.modulate.a = 0.0
		var delay: float = float(i) * ENTRANCE_STAGGER
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(sprite, "scale", saved_scale * 1.15, ENTRANCE_DUR)\
			.set_delay(delay)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "modulate:a", saved_modulate.a, 0.2)\
			.set_delay(delay)
		tw.chain().tween_property(sprite, "scale", saved_scale, 0.12)


func _add_click_area(sprite: Node2D, animal_name: String) -> void:
	var area: Area2D = Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = CLICK_AREA_RADIUS
	shape.shape = circle
	area.add_child(shape)
	sprite.add_child(area)
	area.input_event.connect(_on_animal_input.bind(animal_name, sprite))


func _on_animal_input(_viewport: Node, event: InputEvent, _shape_idx: int,
		animal_name: String, sprite: Node2D) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		if not (event is InputEventScreenTouch and event.pressed):
			return

	var now: float = Time.get_ticks_msec() / 1000.0
	if _cooldowns.has(animal_name):
		if now - _cooldowns[animal_name] < CLICK_COOLDOWN:
			return
	_cooldowns[animal_name] = now

	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	VFXManager.spawn_heart_particles(sprite.global_position)
	_animator.play_happy(sprite)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	AudioManager.play_sfx("click")
	## Тваринки зникають перед переходом
	for i: int in _animal_sprites.size():
		var sprite: Node2D = _animal_sprites[i]
		if is_instance_valid(sprite):
			var tw: Tween = create_tween()
			tw.tween_property(sprite, "scale", Vector2.ZERO, 0.2)\
				.set_delay(float(i) * 0.03)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		SceneManager.goto_scene("res://scenes/ui/main_menu.tscn"))
