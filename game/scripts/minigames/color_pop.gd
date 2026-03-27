extends BaseMiniGame

## Underwater Rescue — рибки заперті в кольорових пузирях! Звільни їх!
## Toddler: тап будь-який пузир → рибка вільна.
## Preschool: мама-риба шукає малюка певного кольору → тап лише matching.
## Combo 3+: кит лопає 3 пузирі. Кожні 5 правильних: скриня з скарбами.
## 30 правильних: гігантський пузир → 3 тапи → 5 рибок одразу.

const BUBBLE_SCENE: PackedScene = preload("res://scenes/components/bubble.tscn")
const GAME_DURATION: float = 45.0
const MARGIN_X: float = 100.0
const SAFETY_TIMEOUT_SEC: float = 120.0
const IDLE_HINT_DELAY: float = 5.0
const MAX_ACTIVE_BUBBLES: int = 15
const WHALE_COMBO_THRESHOLD: int = 3
const TREASURE_INTERVAL: int = 5
const GIANT_BUBBLE_THRESHOLD: int = 30
const GIANT_BUBBLE_TAPS_NEEDED: int = 3

## Палітра кольорів — LAW 25: кожен колір має secondary visual encoding (рибка всередині)
const COLORS: Array[Color] = [
	Color("ef4444"), Color("3b82f6"), Color("22c55e"),
	Color("eab308"), Color("a855f7"),
]
const COLOR_KEYS: Array[String] = [
	"COLOR_RED", "COLOR_BLUE", "COLOR_GREEN", "COLOR_YELLOW", "COLOR_PURPLE",
]
const COLOR_IDS: Array[String] = ["red", "blue", "green", "yellow", "purple"]

## Toddler параметри
const TODDLER_SPAWN_INTERVAL: float = 1.5
const TODDLER_SPEED_MIN: float = 60.0
const TODDLER_SPEED_MAX: float = 100.0
const TODDLER_RADIUS: float = 70.0

## Preschool параметри
const PRESCHOOL_SPAWN_INTERVAL: float = 0.8
const PRESCHOOL_SPEED_MIN: float = 90.0
const PRESCHOOL_SPEED_MAX: float = 160.0
const PRESCHOOL_RADIUS: float = 55.0

## Difficulty phases (elapsed seconds) — A4: прогресивна складність
const PHASE_1_END: float = 15.0
const PHASE_2_END: float = 30.0
## Phase 1: 0-15с — 3 кольори, повільно, target фіксований
## Phase 2: 15-30с — 4 кольори, середня швидкість, target кожні 15с
## Phase 3: 30-45с — 5 кольорів + golden bonus, target кожні 12с
## Toddler: ВСІ фази без зміни target (будь-який пузир = correct)

## 10 видів рибок — кожен має унікальну форму (LAW 3/25 secondary encoding)
## 0=Clownfish, 1=Angelfish, 2=Pufferfish, 3=Seahorse, 4=Starfish,
## 5=Jellyfish, 6=Swordfish, 7=Turtle, 8=Octopus, 9=Crab
const FISH_SPECIES_COUNT: int = 10

var _is_toddler: bool = false
var _score: int = 0
var _correct_pops: int = 0
var _speed_multiplier: float = 1.0
var _target_color_idx: int = 0
var _start_time: float = 0.0
var _current_color_count: int = 3
var _bubbles: Array[Node2D] = []
var _spawn_timer: Timer = null
var _target_timer: Timer = null
var _idle_timer: SceneTreeTimer = null
var _giant_bubble_active: bool = false
var _giant_bubble_taps: int = 0
var _giant_bubble_node: Node2D = null
var _treasure_active: bool = false
var _whale_active: bool = false
var _whale_popping: bool = false  ## Guard: пузирі лопаються китом — не рахувати як гравець

## UI
var _score_label: Label = null
var _target_label: Label = null
var _target_circle: _ColorCircle = null
var _mama_fish: _MamaFish = null
var _timer_bar: ProgressBar = null
var _warned_low_time: bool = false


func _ready() -> void:
	game_id = "color_pop"
	bg_theme = "ocean"
	super()
	var group: int = SettingsManager.age_group
	_is_toddler = (group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_start_spawning()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func _process(_delta: float) -> void:
	if _game_over:
		return
	## Прибрати мертві пузирі (вилетіли за екран і зробили queue_free)
	for i: int in range(_bubbles.size() - 1, -1, -1):
		if not is_instance_valid(_bubbles[i]):
			_bubbles.remove_at(i)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var remaining: float = GAME_DURATION - elapsed
	## A4: прогресивна складність за фазами
	_ramp_difficulty(elapsed)
	if _timer_bar:
		if GAME_DURATION > 0.0:
			_timer_bar.value = remaining / GAME_DURATION * 100.0
		else:
			_timer_bar.value = 0.0
		## UX: Попередження при <10с
		if remaining <= 10.0 and remaining > 0.0:
			_timer_bar.modulate = Color("ff6b6b")
			if not _warned_low_time:
				_warned_low_time = true
				AudioManager.play_sfx("click")
				if not (SettingsManager and SettingsManager.reduced_motion):
					_pulse_tween = _create_game_tween().set_loops()
					_pulse_tween.tween_property(_timer_bar, "scale:y", 1.08, 0.3)\
						.set_trans(Tween.TRANS_SINE)
					_pulse_tween.tween_property(_timer_bar, "scale:y", 1.0, 0.3)\
						.set_trans(Tween.TRANS_SINE)
		else:
			_timer_bar.modulate = Color.WHITE
	if remaining <= 0.0:
		_game_over = true
		if _spawn_timer:
			_spawn_timer.stop()
		if _target_timer:
			_target_timer.stop()
		_finish()


func _ramp_difficulty(elapsed: float) -> void:
	## Фаза 1 (0-15с): 3 кольори, повільно
	## Фаза 2 (15-30с): 4 кольори, швидше, target змінюється (preschool)
	## Фаза 3 (30+с): 5 кольорів + golden bonus, ще швидше
	var progress: float = clampf(elapsed / maxf(GAME_DURATION, 1.0), 0.0, 1.0)
	_speed_multiplier = lerpf(1.0, 1.4, progress)
	var base_interval: float = TODDLER_SPAWN_INTERVAL if _is_toddler else PRESCHOOL_SPAWN_INTERVAL
	var new_interval: float = lerpf(base_interval, base_interval * 0.6, progress)
	if _spawn_timer and absf(_spawn_timer.wait_time - new_interval) > 0.05:
		_spawn_timer.wait_time = new_interval
	## Оновити кількість доступних кольорів за фазою
	if elapsed < PHASE_1_END:
		_current_color_count = 3
	elif elapsed < PHASE_2_END:
		_current_color_count = 4
	else:
		_current_color_count = 5


func _build_hud() -> void:
	## Score (правий верхній кут, на UI layer)
	_score_label = Label.new()
	_score_label.text = "0"
	_score_label.add_theme_font_size_override("font_size", 36)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_score_label.offset_left = -160.0
	_score_label.offset_right = -16.0
	_score_label.offset_top = 8.0
	_ui_layer.add_child(_score_label)
	## Target color display + mama fish (тільки preschool)
	if not _is_toddler:
		_build_target_display()
	## Timer bar (низ екрану)
	_timer_bar = ProgressBar.new()
	_timer_bar.max_value = 100.0
	_timer_bar.value = 100.0
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 8)
	_timer_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_timer_bar.offset_top = -12.0
	_ui_layer.add_child(_timer_bar)


func _build_target_display() -> void:
	## Мама-риба зверху по центру (шукає малюка певного кольору)
	var box: HBoxContainer = HBoxContainer.new()
	box.set("theme_override_constants/separation", 12)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.offset_top = 8.0
	box.offset_bottom = 64.0
	box.offset_left = -160.0
	box.offset_right = 160.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_ui_layer.add_child(box)
	## Мама-риба — анімована іконка
	_mama_fish = _MamaFish.new()
	_mama_fish.custom_minimum_size = Vector2(56, 48)
	box.add_child(_mama_fish)
	## Кольорове коло-індикатор
	_target_circle = _ColorCircle.new()
	_target_circle.custom_minimum_size = Vector2(48, 48)
	_target_circle.material = GameData.create_premium_material(
		0.06, 2.0, 0.0, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
	box.add_child(_target_circle)
	## Текст
	_target_label = Label.new()
	_target_label.add_theme_font_size_override("font_size", 28)
	_target_label.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(_target_label)


func _start_spawning() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = TODDLER_SPAWN_INTERVAL if _is_toddler else PRESCHOOL_SPAWN_INTERVAL
	_spawn_timer.timeout.connect(_spawn_bubble)
	add_child(_spawn_timer)
	_spawn_timer.start()
	## Preschool: таймер зміни цільового кольору (починає з фіксованого)
	if not _is_toddler:
		_target_timer = Timer.new()
		_target_timer.wait_time = 15.0  ## Фаза 1: target не міняється (wait > PHASE_1_END)
		_target_timer.timeout.connect(_change_target_color)
		add_child(_target_timer)
		_target_timer.start()
		_change_target_color()
	_reset_idle_timer()


func _spawn_bubble() -> void:
	if _game_over:
		return
	## Обмеження активних пузирів для продуктивності
	if _bubbles.size() >= MAX_ACTIVE_BUBBLES:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bubble: Node2D = BUBBLE_SCENE.instantiate()
	add_child(bubble)
	## Випадковий колір з доступного пулу (залежить від фази)
	var pool_size: int = clampi(_current_color_count, 3, COLORS.size())
	var color_idx: int = randi() % pool_size
	## Preschool: ~40% цільового кольору для fair gameplay
	if not _is_toddler and randf() < 0.4:
		color_idx = _target_color_idx
	var speed: float = randf_range(
		TODDLER_SPEED_MIN if _is_toddler else PRESCHOOL_SPEED_MIN,
		TODDLER_SPEED_MAX if _is_toddler else PRESCHOOL_SPEED_MAX) * _speed_multiplier
	var radius: float = TODDLER_RADIUS if _is_toddler else PRESCHOOL_RADIUS
	## LAW 13: bounds check перед COLORS доступом
	if color_idx < 0 or color_idx >= COLORS.size():
		color_idx = 0
	bubble.setup(COLORS[color_idx], speed, radius)
	bubble.set_meta("color_idx", color_idx)
	## Вид рибки всередині — LAW 3/25: secondary encoding за формою
	var fish_species: int = randi() % FISH_SPECIES_COUNT
	bubble.set_meta("fish_species", fish_species)
	## Додати рибку-силует як child до bubble для відображення
	var fish_overlay: _FishSilhouette = _FishSilhouette.new()
	fish_overlay.species = fish_species
	fish_overlay.fish_color = COLORS[color_idx]
	fish_overlay.bubble_radius = radius
	bubble.add_child(fish_overlay)
	bubble.position = Vector2(
		randf_range(MARGIN_X, vp.x - MARGIN_X),
		vp.y + radius * 2.0)
	bubble.popped.connect(_on_bubble_popped)
	_bubbles.append(bubble)
	## Golden bonus bubble у фазі 3
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	if elapsed >= PHASE_2_END and randf() < 0.08:
		_spawn_golden_bubble(vp)


func _spawn_golden_bubble(vp: Vector2) -> void:
	## Бонусний золотий пузир — додатковий score при pop
	if _bubbles.size() >= MAX_ACTIVE_BUBBLES:
		return
	var bubble: Node2D = BUBBLE_SCENE.instantiate()
	add_child(bubble)
	var speed: float = randf_range(60.0, 90.0) * _speed_multiplier
	var radius: float = (TODDLER_RADIUS if _is_toddler else PRESCHOOL_RADIUS) * 1.2
	bubble.setup(Color("ffd700"), speed, radius)
	bubble.set_meta("color_idx", -1)  ## -1 = golden bonus
	bubble.set_meta("fish_species", randi() % FISH_SPECIES_COUNT)
	bubble.set_meta("golden", true)
	var fish_overlay: _FishSilhouette = _FishSilhouette.new()
	fish_overlay.species = bubble.get_meta("fish_species", 0)
	fish_overlay.fish_color = Color("ffd700")
	fish_overlay.bubble_radius = radius
	fish_overlay.is_golden = true
	bubble.add_child(fish_overlay)
	bubble.position = Vector2(
		randf_range(MARGIN_X, vp.x - MARGIN_X),
		vp.y + radius * 2.0)
	bubble.popped.connect(_on_bubble_popped)
	_bubbles.append(bubble)


func _on_bubble_popped(bubble: Node2D) -> void:
	if _game_over or _input_locked:
		return
	## Guard: якщо кит лопає пузирі — не обробляти як гравець
	if _whale_popping:
		return
	var is_golden: bool = bubble.get_meta("golden", false)
	if _is_toddler:
		## A6: Toddler — будь-який пузир = correct, без покарання
		_score += 1
		_correct_pops += 1
		_register_correct()
		## Ascending pitch для streak — від 1.0 до 1.5
		var pitch: float = clampf(1.0 + float(mini(_streak_count, 10)) * 0.05, 1.0, 1.5)
		AudioManager.play_sfx("coin", pitch)
		_spawn_freed_fish(bubble)
	else:
		## A7: Preschool — перевірити колір
		var color_idx: int = bubble.get_meta("color_idx", -1)
		if is_golden or color_idx == _target_color_idx:
			_register_correct()
			_correct_pops += 1
			_score += 2 if not is_golden else 5
			var pitch: float = clampf(1.0 + float(mini(_streak_count, 10)) * 0.05, 1.0, 1.5)
			AudioManager.play_sfx("success", pitch)
			JuicyEffects.combo_vfx(bubble.global_position, _streak_count)
			_spawn_freed_fish(bubble)
		else:
			_errors += 1
			_register_error(bubble)
			AudioManager.play_sfx("error")
			HapticsManager.vibrate_light()
			VFXManager.spawn_error_smoke(bubble.global_position)
	_score_label.text = "%d" % _score
	## Score bounce анімація
	if not (SettingsManager and SettingsManager.reduced_motion):
		_score_label.pivot_offset = _score_label.size / 2.0
		var stw: Tween = _create_game_tween()
		stw.tween_property(_score_label, "scale", Vector2(1.3, 1.3), 0.06)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		stw.tween_property(_score_label, "scale", Vector2.ONE, 0.1)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_reset_idle_timer()
	## Перевірити combo бонуси
	_check_combo_events()


func _spawn_freed_fish(bubble: Node2D) -> void:
	## Рибка "вистрибує" з пузиря і пливе до мами (або вгору)
	if not is_instance_valid(bubble):
		push_warning("ColorPop: _spawn_freed_fish — bubble вже freed")
		return
	var pos: Vector2 = bubble.global_position
	var species: int = bubble.get_meta("fish_species", 0)
	var color_idx: int = bubble.get_meta("color_idx", 0)
	if color_idx < 0 or color_idx >= COLORS.size():
		color_idx = 0
	var fish: _FreedFish = _FreedFish.new()
	fish.species = species
	fish.fish_color = COLORS[color_idx]
	fish.position = pos
	add_child(fish)
	## Splash particles — CPUParticles2D (LAW 18/21)
	_spawn_splash_particles(pos)
	## Анімація: рибка вистрибує вгору, потім пливе в сторону
	if SettingsManager.reduced_motion:
		fish.queue_free()
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var target_x: float = randf_range(MARGIN_X, vp.x - MARGIN_X)
	var tw: Tween = _create_game_tween()
	tw.tween_property(fish, "position:y", pos.y - 100.0, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fish, "position:x", target_x, 0.5)
	tw.tween_property(fish, "position:y", -60.0, 0.6)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(fish, "modulate:a", 0.0, 0.3).set_delay(0.3)
	tw.finished.connect(fish.queue_free)


func _spawn_splash_particles(pos: Vector2) -> void:
	## LAW 18: CPUParticles2D only. LAW 21: max 100, tracked lifecycle.
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 12  ## Під лімітом 100/emitter
	particles.lifetime = 0.5
	particles.explosiveness = 0.9
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 150.0
	particles.gravity = Vector2(0, 200)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.7, 0.9, 1.0, 0.7)
	particles.position = pos
	add_child(particles)
	## Auto-cleanup після lifetime
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _check_combo_events() -> void:
	## Combo 3+: кит лопає 3 пузирі
	if _streak_count >= WHALE_COMBO_THRESHOLD and not _whale_active:
		if _streak_count % WHALE_COMBO_THRESHOLD == 0:
			_trigger_whale_bonus()
	## Кожні 5 правильних: скриня з скарбами
	if _correct_pops > 0 and _correct_pops % TREASURE_INTERVAL == 0 and not _treasure_active:
		_trigger_treasure_chest()
	## 30 правильних: гігантський пузир
	if _correct_pops >= GIANT_BUBBLE_THRESHOLD and not _giant_bubble_active:
		_trigger_giant_bubble()


func _trigger_whale_bonus() -> void:
	## Кит з'являється і лопає 3 випадкових пузирі
	_whale_active = true
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var whale: _WhaleSprite = _WhaleSprite.new()
	whale.position = Vector2(-120.0, vp.y * 0.4)
	add_child(whale)
	AudioManager.play_sfx("success", 0.8)
	if SettingsManager.reduced_motion:
		_whale_pop_bubbles(3)
		whale.queue_free()
		_whale_active = false
		return
	## Кит пливе через екран
	var tw: Tween = _create_game_tween()
	tw.tween_property(whale, "position:x", vp.x + 120.0, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(whale):
			whale.queue_free()
		_whale_active = false
	)
	## Лопати пузирі по шляху кита
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if not is_instance_valid(self) or _game_over:
			return
		_whale_pop_bubbles(3)
	)


func _whale_pop_bubbles(count: int) -> void:
	## Автоматично лопнути count пузирів (бонус від кита)
	_whale_popping = true  ## Guard: не рахувати як гравець в _on_bubble_popped
	var popped: int = 0
	## Ітеруємо по копії масиву (бо pop може видалити елемент)
	var copy: Array[Node2D] = _bubbles.duplicate()
	for bubble: Node2D in copy:
		if popped >= count:
			break
		if not is_instance_valid(bubble):
			continue
		if bubble.get_meta("golden", false):
			continue  ## Не лопати golden — хай гравець сам
		bubble.pop()
		_score += 1
		popped += 1
	_whale_popping = false
	_score_label.text = "%d" % _score


func _trigger_treasure_chest() -> void:
	## Скриня з'являється по центру — тап для бонусу
	_treasure_active = true
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var chest: _TreasureChest = _TreasureChest.new()
	chest.position = vp * 0.5
	chest.tapped.connect(_on_treasure_tapped.bind(chest))
	add_child(chest)
	AudioManager.play_sfx("coin", 0.9)
	## Автозникнення через 3с якщо не тапнули
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		if is_instance_valid(chest):
			_treasure_active = false
			var tw: Tween = _create_game_tween()
			tw.tween_property(chest, "modulate:a", 0.0, 0.3)
			tw.finished.connect(chest.queue_free)
	)


func _on_treasure_tapped(chest: Node2D) -> void:
	if _game_over:
		return
	_treasure_active = false
	_score += 5
	_score_label.text = "%d" % _score
	AudioManager.play_sfx("success", 1.3)
	HapticsManager.vibrate_success()
	if is_instance_valid(chest):
		VFXManager.spawn_correct_sparkle(chest.global_position)
		var tw: Tween = _create_game_tween()
		tw.tween_property(chest, "scale", Vector2(1.5, 1.5), 0.1)
		tw.parallel().tween_property(chest, "modulate:a", 0.0, 0.2)
		tw.finished.connect(chest.queue_free)


func _trigger_giant_bubble() -> void:
	## Гігантський пузир — потрібно 3 rapid taps щоб лопнути → 5 рибок
	_giant_bubble_active = true
	_giant_bubble_taps = 0
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_giant_bubble_node = _GiantBubble.new()
	_giant_bubble_node.position = vp * 0.5
	(_giant_bubble_node as _GiantBubble).tapped.connect(_on_giant_bubble_tap)
	add_child(_giant_bubble_node)
	AudioManager.play_sfx("coin", 0.7)
	## Автозникнення через 5с якщо не лопнули
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		if _giant_bubble_active and is_instance_valid(_giant_bubble_node):
			_giant_bubble_active = false
			_giant_bubble_node.queue_free()
			_giant_bubble_node = null
	)


func _on_giant_bubble_tap() -> void:
	if _game_over or not _giant_bubble_active:
		return
	_giant_bubble_taps += 1
	AudioManager.play_sfx("click", 1.0 + float(_giant_bubble_taps) * 0.15)
	## Вібрація при кожному тапі
	HapticsManager.vibrate_light()
	if is_instance_valid(_giant_bubble_node):
		## Масштабна пульсація при кожному тапі
		if not SettingsManager.reduced_motion:
			var tw: Tween = _create_game_tween()
			tw.tween_property(_giant_bubble_node, "scale", Vector2(1.15, 1.15), 0.05)
			tw.tween_property(_giant_bubble_node, "scale", Vector2.ONE, 0.1)\
				.set_trans(Tween.TRANS_ELASTIC)
	if _giant_bubble_taps >= GIANT_BUBBLE_TAPS_NEEDED:
		_giant_bubble_active = false
		_score += 10
		_score_label.text = "%d" % _score
		AudioManager.play_sfx("success", 1.4)
		HapticsManager.vibrate_celebration()
		if is_instance_valid(_giant_bubble_node):
			var pos: Vector2 = _giant_bubble_node.global_position
			VFXManager.spawn_premium_celebration(pos)
			## 5 рибок вилітають з гігантського пузиря
			for i: int in 5:
				var fish: _FreedFish = _FreedFish.new()
				fish.species = randi() % FISH_SPECIES_COUNT
				if COLORS.size() > 0:
					fish.fish_color = COLORS[randi() % COLORS.size()]
				fish.position = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
				add_child(fish)
				if not SettingsManager.reduced_motion:
					var tw: Tween = _create_game_tween()
					var angle: float = TAU * float(i) / 5.0
					var target: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 200.0
					tw.tween_property(fish, "position", target, 0.5)\
						.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
						.set_delay(float(i) * 0.08)
					tw.tween_property(fish, "modulate:a", 0.0, 0.3)
					tw.finished.connect(fish.queue_free)
				else:
					fish.queue_free()
			_giant_bubble_node.queue_free()
			_giant_bubble_node = null


func _change_target_color() -> void:
	if _game_over:
		return
	## LAW 13: bounds check
	var pool_size: int = clampi(_current_color_count, 1, COLORS.size())
	var new_idx: int = randi() % pool_size
	while new_idx == _target_color_idx and pool_size > 1:
		new_idx = randi() % pool_size
	_target_color_idx = new_idx
	_update_target_display()
	## Оновити interval таймера за фазою
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	if _target_timer:
		if elapsed < PHASE_1_END:
			_target_timer.wait_time = 20.0  ## Фактично не змінює під час фази 1
		elif elapsed < PHASE_2_END:
			_target_timer.wait_time = 15.0
		else:
			_target_timer.wait_time = 12.0
	## Flash анімація
	if _target_label and not SettingsManager.reduced_motion:
		var parent: Node = _target_label.get_parent()
		if parent and parent is Control:
			(parent as Control).pivot_offset = (parent as Control).size / 2.0
			var tw: Tween = _create_game_tween()
			tw.tween_property(parent, "scale", Vector2(1.3, 1.3), 0.1)
			tw.tween_property(parent, "scale", Vector2.ONE, 0.15)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## Мама-риба міняє колір
	if _mama_fish and is_instance_valid(_mama_fish):
		if _target_color_idx >= 0 and _target_color_idx < COLORS.size():
			_mama_fish.fish_color = COLORS[_target_color_idx]
			_mama_fish.queue_redraw()


func _update_target_display() -> void:
	## LAW 13: bounds check перед масивом
	if _target_color_idx < 0 or _target_color_idx >= COLOR_KEYS.size():
		push_warning("ColorPop: _target_color_idx out of bounds: %d" % _target_color_idx)
		return
	if _target_label:
		_target_label.text = tr("COLOR_POP_TARGET") % tr(COLOR_KEYS[_target_color_idx])
	if _target_circle:
		_target_circle.circle_color = COLORS[_target_color_idx]
		## LAW 25: Color-blind pattern
		if SettingsManager.color_blind_mode:
			if _target_color_idx < COLOR_IDS.size():
				_target_circle.cb_pattern = GameData.get_cb_pattern(
					COLOR_IDS[_target_color_idx])
			else:
				_target_circle.cb_pattern = ""
		else:
			_target_circle.cb_pattern = ""
		_target_circle.queue_redraw()


func _finish() -> void:
	_input_locked = true
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if _spawn_timer:
		_spawn_timer.stop()
	if _target_timer:
		_target_timer.stop()
	## Прибрати пузирі що залишились — A9: round hygiene
	for bubble: Node2D in _bubbles.duplicate():
		if is_instance_valid(bubble):
			bubble.queue_free()
	_bubbles.clear()
	## Прибрати гігантський пузир
	if is_instance_valid(_giant_bubble_node):
		_giant_bubble_node.queue_free()
		_giant_bubble_node = null
	_giant_bubble_active = false
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	## LAW 16: централізована формула зірок
	var earned: int = _calculate_stars(_errors)
	## LAW 24: stats contract — точні ключі
	var stats: Dictionary = {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": 1,
		"earned_stars": earned,
	}
	finish_game(earned, stats)


func _reset_idle_timer() -> void:
	## A10: idle escalation
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	## A10: 3 рівні ескалації — pulse → glow → tutorial hand
	if _game_over:
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	## Пульсація кольорового індикатора (preschool) або першого пузиря (toddler)
	if not _is_toddler and _target_circle and is_instance_valid(_target_circle):
		_pulse_node(_target_circle, 1.2)
	elif _bubbles.size() > 0 and is_instance_valid(_bubbles[0]):
		_pulse_node(_bubbles[0], 1.15)
	_reset_idle_timer()


## A1: Tutorial — zero-text onboarding
func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("COLOR_POP_TUTORIAL_TODDLER")
	return tr("COLOR_POP_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return {"type": "tap", "target": vp * 0.5}


## ─── INNER CLASSES ───────────────────────────────────────────────────────────


## Силует рибки всередині пузиря — 10 видів через draw_*()
## LAW 28: multi-layer depth. LAW 25: shape = secondary encoding.
class _FishSilhouette extends Node2D:
	var species: int = 0
	var fish_color: Color = Color.WHITE
	var bubble_radius: float = 50.0
	var is_golden: bool = false
	var _wobble_time: float = 0.0

	func _process(delta: float) -> void:
		_wobble_time += delta * 3.0
		queue_redraw()

	func _draw() -> void:
		var s: float = bubble_radius * 0.45  ## Масштаб рибки відносно пузиря
		var wobble_x: float = sin(_wobble_time) * s * 0.1
		var wobble_y: float = cos(_wobble_time * 0.7) * s * 0.05
		var offset: Vector2 = Vector2(wobble_x, wobble_y)
		## LAW 28: semi-transparent silhouette з глибиною
		var base_c: Color = Color(fish_color, 0.55) if not is_golden else Color(1.0, 0.85, 0.3, 0.7)
		var dark_c: Color = Color(base_c.darkened(0.2), base_c.a * 0.8)
		var light_c: Color = Color(base_c.lightened(0.3), base_c.a * 0.6)
		match species:
			0: _draw_clownfish(offset, s, base_c, dark_c, light_c)
			1: _draw_angelfish(offset, s, base_c, dark_c, light_c)
			2: _draw_pufferfish(offset, s, base_c, dark_c, light_c)
			3: _draw_seahorse(offset, s, base_c, dark_c, light_c)
			4: _draw_starfish(offset, s, base_c, dark_c, light_c)
			5: _draw_jellyfish(offset, s, base_c, dark_c, light_c)
			6: _draw_swordfish(offset, s, base_c, dark_c, light_c)
			7: _draw_turtle(offset, s, base_c, dark_c, light_c)
			8: _draw_octopus(offset, s, base_c, dark_c, light_c)
			9: _draw_crab(offset, s, base_c, dark_c, light_c)
			_: _draw_clownfish(offset, s, base_c, dark_c, light_c)

	func _draw_clownfish(o: Vector2, s: float, base: Color, dark: Color, light: Color) -> void:
		## Овальне тіло + 2 смужки + хвіст
		draw_circle(o, s * 0.7, dark)
		draw_circle(o, s * 0.6, base)
		## Смужки
		draw_line(o + Vector2(-s * 0.15, -s * 0.5), o + Vector2(-s * 0.15, s * 0.5),
			light, s * 0.08, true)
		draw_line(o + Vector2(s * 0.2, -s * 0.45), o + Vector2(s * 0.2, s * 0.45),
			light, s * 0.08, true)
		## Хвіст
		var tail: PackedVector2Array = PackedVector2Array([
			o + Vector2(s * 0.5, 0), o + Vector2(s * 0.8, -s * 0.3),
			o + Vector2(s * 0.8, s * 0.3)])
		draw_colored_polygon(tail, dark)
		## Око
		draw_circle(o + Vector2(-s * 0.3, -s * 0.1), s * 0.1, Color.WHITE)
		draw_circle(o + Vector2(-s * 0.3, -s * 0.1), s * 0.05, Color(0.1, 0.1, 0.1, 0.8))

	func _draw_angelfish(o: Vector2, s: float, base: Color, dark: Color, light: Color) -> void:
		## Ромбоподібне тіло + високий плавець
		var body: PackedVector2Array = PackedVector2Array([
			o + Vector2(-s * 0.6, 0), o + Vector2(0, -s * 0.8),
			o + Vector2(s * 0.6, 0), o + Vector2(0, s * 0.8)])
		draw_colored_polygon(body, dark)
		var inner: PackedVector2Array = PackedVector2Array([
			o + Vector2(-s * 0.45, 0), o + Vector2(0, -s * 0.6),
			o + Vector2(s * 0.45, 0), o + Vector2(0, s * 0.6)])
		draw_colored_polygon(inner, base)
		## Смужка
		draw_line(o + Vector2(0, -s * 0.5), o + Vector2(0, s * 0.5), light, s * 0.06, true)
		## Око
		draw_circle(o + Vector2(-s * 0.2, -s * 0.15), s * 0.08, Color.WHITE)
		draw_circle(o + Vector2(-s * 0.2, -s * 0.15), s * 0.04, Color(0.1, 0.1, 0.1, 0.8))

	func _draw_pufferfish(o: Vector2, s: float, base: Color, dark: Color, light: Color) -> void:
		## Круглий + шипи
		draw_circle(o, s * 0.55, dark)
		draw_circle(o, s * 0.45, base)
		## Шипи (8 штук)
		for i: int in 8:
			var angle: float = float(i) / 8.0 * TAU
			var spike_start: Vector2 = o + Vector2(cos(angle), sin(angle)) * s * 0.45
			var spike_end: Vector2 = o + Vector2(cos(angle), sin(angle)) * s * 0.7
			draw_line(spike_start, spike_end, dark, s * 0.04, true)
		## Великі очі (cute!)
		draw_circle(o + Vector2(-s * 0.15, -s * 0.1), s * 0.12, Color.WHITE)
		draw_circle(o + Vector2(s * 0.15, -s * 0.1), s * 0.12, Color.WHITE)
		draw_circle(o + Vector2(-s * 0.15, -s * 0.1), s * 0.06, Color(0.1, 0.1, 0.1, 0.8))
		draw_circle(o + Vector2(s * 0.15, -s * 0.1), s * 0.06, Color(0.1, 0.1, 0.1, 0.8))
		## Sparkle
		draw_circle(o + Vector2(-s * 0.25, -s * 0.3), maxf(s * 0.04, 1.0), light)

	func _draw_seahorse(o: Vector2, s: float, base: Color, dark: Color, _light: Color) -> void:
		## S-подібна крива
		draw_circle(o + Vector2(0, -s * 0.3), s * 0.25, dark)
		draw_circle(o + Vector2(0, -s * 0.3), s * 0.2, base)
		## Тіло (2 кола)
		draw_circle(o + Vector2(s * 0.05, s * 0.05), s * 0.2, base)
		## Хвіст — крива вниз
		var tail_pts: PackedVector2Array = PackedVector2Array([
			o + Vector2(s * 0.1, s * 0.2), o + Vector2(s * 0.15, s * 0.5),
			o + Vector2(-s * 0.05, s * 0.7)])
		draw_polyline(tail_pts, dark, s * 0.08, true)
		## Морда
		draw_circle(o + Vector2(-s * 0.2, -s * 0.35), s * 0.08, dark)
		## Око
		draw_circle(o + Vector2(-s * 0.05, -s * 0.35), s * 0.06, Color.WHITE)
		draw_circle(o + Vector2(-s * 0.05, -s * 0.35), s * 0.03, Color(0.1, 0.1, 0.1, 0.8))

	func _draw_starfish(o: Vector2, s: float, base: Color, dark: Color, light: Color) -> void:
		## 5 променів
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in 10:
			var angle: float = float(i) / 10.0 * TAU - PI / 2.0
			var r: float = s * 0.7 if i % 2 == 0 else s * 0.35
			points.append(o + Vector2(cos(angle), sin(angle)) * r)
		if points.size() >= 3:
			draw_colored_polygon(points, dark)
		## Внутрішня зірка (менша)
		var inner_pts: PackedVector2Array = PackedVector2Array()
		for i: int in 10:
			var angle: float = float(i) / 10.0 * TAU - PI / 2.0
			var r: float = s * 0.55 if i % 2 == 0 else s * 0.28
			inner_pts.append(o + Vector2(cos(angle), sin(angle)) * r)
		if inner_pts.size() >= 3:
			draw_colored_polygon(inner_pts, base)
		## Центральне око
		draw_circle(o, s * 0.1, Color.WHITE)
		draw_circle(o, s * 0.05, Color(0.1, 0.1, 0.1, 0.8))
		## Sparkle
		draw_circle(o + Vector2(-s * 0.15, -s * 0.35), maxf(s * 0.04, 1.0), light)

	func _draw_jellyfish(o: Vector2, s: float, base: Color, dark: Color, _light: Color) -> void:
		## Купол + щупальця
		var dome_pts: PackedVector2Array = PackedVector2Array()
		for i: int in 13:
			var angle: float = PI + float(i) / 12.0 * PI
			dome_pts.append(o + Vector2(cos(angle) * s * 0.5, sin(angle) * s * 0.4))
		if dome_pts.size() >= 3:
			draw_colored_polygon(dome_pts, dark)
		## Внутрішній купол
		var inner_dome: PackedVector2Array = PackedVector2Array()
		for i: int in 13:
			var angle: float = PI + float(i) / 12.0 * PI
			inner_dome.append(o + Vector2(cos(angle) * s * 0.4, sin(angle) * s * 0.3))
		if inner_dome.size() >= 3:
			draw_colored_polygon(inner_dome, base)
		## Щупальця (3 хвилясті лінії)
		for t: int in 3:
			var x_off: float = (float(t) - 1.0) * s * 0.25
			var start: Vector2 = o + Vector2(x_off, 0)
			var end: Vector2 = o + Vector2(x_off + sin(float(t)) * s * 0.1, s * 0.6)
			draw_line(start, end, dark, s * 0.04, true)
		## Очі
		draw_circle(o + Vector2(-s * 0.15, -s * 0.15), s * 0.06, Color.WHITE)
		draw_circle(o + Vector2(s * 0.15, -s * 0.15), s * 0.06, Color.WHITE)
		draw_circle(o + Vector2(-s * 0.15, -s * 0.15), s * 0.03, Color(0.1, 0.1, 0.1, 0.8))
		draw_circle(o + Vector2(s * 0.15, -s * 0.15), s * 0.03, Color(0.1, 0.1, 0.1, 0.8))

	func _draw_swordfish(o: Vector2, s: float, base: Color, dark: Color, _light: Color) -> void:
		## Довгий ніс + обтічне тіло
		var body: PackedVector2Array = PackedVector2Array([
			o + Vector2(-s * 0.8, 0), o + Vector2(-s * 0.2, -s * 0.3),
			o + Vector2(s * 0.4, -s * 0.15), o + Vector2(s * 0.5, 0),
			o + Vector2(s * 0.4, s * 0.15), o + Vector2(-s * 0.2, s * 0.3)])
		if body.size() >= 3:
			draw_colored_polygon(body, dark)
		## Внутрішня заливка
		var inner: PackedVector2Array = PackedVector2Array([
			o + Vector2(-s * 0.6, 0), o + Vector2(-s * 0.15, -s * 0.2),
			o + Vector2(s * 0.3, -s * 0.1), o + Vector2(s * 0.35, 0),
			o + Vector2(s * 0.3, s * 0.1), o + Vector2(-s * 0.15, s * 0.2)])
		if inner.size() >= 3:
			draw_colored_polygon(inner, base)
		## Хвіст
		var tail: PackedVector2Array = PackedVector2Array([
			o + Vector2(s * 0.45, 0), o + Vector2(s * 0.75, -s * 0.25),
			o + Vector2(s * 0.75, s * 0.25)])
		if tail.size() >= 3:
			draw_colored_polygon(tail, dark)
		## Око
		draw_circle(o + Vector2(-s * 0.35, -s * 0.05), s * 0.06, Color.WHITE)
		draw_circle(o + Vector2(-s * 0.35, -s * 0.05), s * 0.03, Color(0.1, 0.1, 0.1, 0.8))

	func _draw_turtle(o: Vector2, s: float, base: Color, dark: Color, light: Color) -> void:
		## Панцир (овал) + голова + лапки
		draw_circle(o, s * 0.5, dark)
		draw_circle(o, s * 0.4, base)
		## Візерунок на панцирі
		draw_circle(o, s * 0.2, light)
		draw_arc(o, s * 0.35, 0.0, TAU, 24, dark, s * 0.04, true)
		## Голова
		draw_circle(o + Vector2(-s * 0.55, -s * 0.05), s * 0.15, base)
		## Лапки (4)
		draw_circle(o + Vector2(-s * 0.3, -s * 0.4), s * 0.1, dark)
		draw_circle(o + Vector2(s * 0.3, -s * 0.4), s * 0.1, dark)
		draw_circle(o + Vector2(-s * 0.3, s * 0.4), s * 0.1, dark)
		draw_circle(o + Vector2(s * 0.3, s * 0.4), s * 0.1, dark)
		## Око
		draw_circle(o + Vector2(-s * 0.6, -s * 0.1), s * 0.05, Color.WHITE)
		draw_circle(o + Vector2(-s * 0.6, -s * 0.1), s * 0.025, Color(0.1, 0.1, 0.1, 0.8))

	func _draw_octopus(o: Vector2, s: float, base: Color, dark: Color, _light: Color) -> void:
		## Купол + 4 щупальця (спрощений для читабельності)
		draw_circle(o + Vector2(0, -s * 0.15), s * 0.4, dark)
		draw_circle(o + Vector2(0, -s * 0.15), s * 0.32, base)
		## Щупальця
		for t: int in 4:
			var x_off: float = (float(t) - 1.5) * s * 0.2
			var start: Vector2 = o + Vector2(x_off, s * 0.1)
			var mid: Vector2 = o + Vector2(x_off + sin(float(t) * 1.5) * s * 0.15, s * 0.4)
			var end: Vector2 = o + Vector2(x_off, s * 0.65)
			draw_line(start, mid, dark, s * 0.06, true)
			draw_line(mid, end, dark, s * 0.04, true)
		## Великі очі
		draw_circle(o + Vector2(-s * 0.12, -s * 0.2), s * 0.1, Color.WHITE)
		draw_circle(o + Vector2(s * 0.12, -s * 0.2), s * 0.1, Color.WHITE)
		draw_circle(o + Vector2(-s * 0.12, -s * 0.2), s * 0.05, Color(0.1, 0.1, 0.1, 0.8))
		draw_circle(o + Vector2(s * 0.12, -s * 0.2), s * 0.05, Color(0.1, 0.1, 0.1, 0.8))

	func _draw_crab(o: Vector2, s: float, base: Color, dark: Color, _light: Color) -> void:
		## Овальне тіло + клешні
		draw_circle(o, s * 0.35, dark)
		draw_circle(o, s * 0.28, base)
		## Клешні
		draw_circle(o + Vector2(-s * 0.55, -s * 0.1), s * 0.15, dark)
		draw_circle(o + Vector2(s * 0.55, -s * 0.1), s * 0.15, dark)
		## Ніжки (по 2 з кожного боку)
		draw_line(o + Vector2(-s * 0.3, s * 0.15), o + Vector2(-s * 0.5, s * 0.35),
			dark, s * 0.04, true)
		draw_line(o + Vector2(-s * 0.25, s * 0.2), o + Vector2(-s * 0.4, s * 0.45),
			dark, s * 0.04, true)
		draw_line(o + Vector2(s * 0.3, s * 0.15), o + Vector2(s * 0.5, s * 0.35),
			dark, s * 0.04, true)
		draw_line(o + Vector2(s * 0.25, s * 0.2), o + Vector2(s * 0.4, s * 0.45),
			dark, s * 0.04, true)
		## Очі на стебельцях
		draw_line(o + Vector2(-s * 0.1, -s * 0.25), o + Vector2(-s * 0.15, -s * 0.45),
			dark, s * 0.04, true)
		draw_line(o + Vector2(s * 0.1, -s * 0.25), o + Vector2(s * 0.15, -s * 0.45),
			dark, s * 0.04, true)
		draw_circle(o + Vector2(-s * 0.15, -s * 0.45), s * 0.06, Color.WHITE)
		draw_circle(o + Vector2(s * 0.15, -s * 0.45), s * 0.06, Color.WHITE)
		draw_circle(o + Vector2(-s * 0.15, -s * 0.45), s * 0.03, Color(0.1, 0.1, 0.1, 0.8))
		draw_circle(o + Vector2(s * 0.15, -s * 0.45), s * 0.03, Color(0.1, 0.1, 0.1, 0.8))


## Рибка після звільнення — пливе вгору з хвилястим рухом
class _FreedFish extends Node2D:
	var species: int = 0
	var fish_color: Color = Color.WHITE
	var _draw_scale: float = 20.0

	func _draw() -> void:
		## Простий силует рибки (компактна версія)
		var s: float = _draw_scale
		var base: Color = fish_color
		var dark: Color = base.darkened(0.15)
		## Тіло
		draw_circle(Vector2.ZERO, s * 0.6, dark)
		draw_circle(Vector2.ZERO, s * 0.5, base)
		## Хвіст
		var tail: PackedVector2Array = PackedVector2Array([
			Vector2(s * 0.4, 0), Vector2(s * 0.7, -s * 0.3),
			Vector2(s * 0.7, s * 0.3)])
		draw_colored_polygon(tail, dark)
		## Око
		draw_circle(Vector2(-s * 0.25, -s * 0.1), s * 0.1, Color.WHITE)
		draw_circle(Vector2(-s * 0.25, -s * 0.1), s * 0.05, Color(0.1, 0.1, 0.1, 0.8))
		## Sparkle
		draw_circle(Vector2(-s * 0.3, -s * 0.25), maxf(s * 0.04, 1.0),
			Color(1, 1, 1, 0.5))


## Мама-риба — HUD елемент, показує якого кольору малюка шукає
class _MamaFish extends Control:
	var fish_color: Color = Color.WHITE

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var s: float = minf(size.x, size.y) * 0.4
		var base: Color = fish_color
		var dark: Color = base.darkened(0.2)
		## Shadow (LAW 28)
		draw_circle(center + Vector2(1.5, 2.0), s * 0.65, Color(0, 0, 0, 0.12))
		## Тіло
		draw_circle(center, s * 0.6, dark)
		draw_circle(center, s * 0.5, base)
		## Хвіст
		var tail: PackedVector2Array = PackedVector2Array([
			center + Vector2(s * 0.4, 0),
			center + Vector2(s * 0.7, -s * 0.3),
			center + Vector2(s * 0.7, s * 0.3)])
		draw_colored_polygon(tail, dark)
		## Корона мами (маленький трикутник зверху)
		var crown: PackedVector2Array = PackedVector2Array([
			center + Vector2(-s * 0.15, -s * 0.5),
			center + Vector2(0, -s * 0.75),
			center + Vector2(s * 0.15, -s * 0.5)])
		draw_colored_polygon(crown, Color("ffd700"))
		## Око
		draw_circle(center + Vector2(-s * 0.2, -s * 0.1), s * 0.1, Color.WHITE)
		draw_circle(center + Vector2(-s * 0.2, -s * 0.1), s * 0.05, Color(0.1, 0.1, 0.1, 0.8))
		## Sparkle
		draw_circle(center + Vector2(-s * 0.35, -s * 0.3), maxf(s * 0.06, 1.0),
			Color(1, 1, 1, 0.55))
		## Border
		draw_arc(center, s * 0.55, 0.0, TAU, 32, Color(1, 1, 1, 0.3), 1.5, true)


## Кольорове коло-індикатор для HUD (прешкольна target мітка)
class _ColorCircle extends Control:
	var circle_color: Color = Color.RED
	var cb_pattern: String = ""

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0 - 2.0
		## Shadow (LAW 28)
		draw_circle(center + Vector2(1.5, 2.0), radius + 0.5, Color(0, 0, 0, 0.15))
		## Dark base
		draw_circle(center, radius, circle_color.darkened(0.15))
		## Light glare
		draw_circle(center + Vector2(-radius * 0.2, -radius * 0.2),
			radius * 0.5, circle_color.lightened(0.15))
		## Border
		draw_arc(center, radius, 0.0, TAU, 32, Color.WHITE, 2.0, true)
		## Sparkle
		draw_circle(center + Vector2(-radius * 0.3, -radius * 0.35),
			maxf(radius * 0.1, 1.0), Color(1, 1, 1, 0.55))
		## LAW 25: Color-blind pattern overlay
		if not cb_pattern.is_empty():
			IconDraw.draw_cb_pattern(self, center, radius, cb_pattern)


## Кит-бонус — пливе через екран при combo 3+
class _WhaleSprite extends Node2D:
	func _draw() -> void:
		var s: float = 50.0
		## Тіло (великий овал)
		var body: PackedVector2Array = PackedVector2Array()
		for i: int in 25:
			var angle: float = float(i) / 24.0 * TAU
			body.append(Vector2(cos(angle) * s * 1.5, sin(angle) * s * 0.8))
		if body.size() >= 3:
			draw_colored_polygon(body, Color(0.3, 0.5, 0.7, 0.8))
		## Черево (світліше)
		var belly: PackedVector2Array = PackedVector2Array()
		for i: int in 13:
			var angle: float = float(i) / 12.0 * PI
			belly.append(Vector2(cos(angle) * s * 1.2, sin(angle) * s * 0.5))
		if belly.size() >= 3:
			draw_colored_polygon(belly, Color(0.6, 0.75, 0.85, 0.7))
		## Хвіст
		var tail: PackedVector2Array = PackedVector2Array([
			Vector2(s * 1.3, 0), Vector2(s * 1.8, -s * 0.5),
			Vector2(s * 1.8, s * 0.5)])
		draw_colored_polygon(tail, Color(0.3, 0.5, 0.7, 0.8))
		## Фонтанчик
		draw_line(Vector2(-s * 0.5, -s * 0.7), Vector2(-s * 0.7, -s * 1.2),
			Color(0.7, 0.9, 1, 0.5), 3.0, true)
		draw_line(Vector2(-s * 0.5, -s * 0.7), Vector2(-s * 0.3, -s * 1.1),
			Color(0.7, 0.9, 1, 0.5), 3.0, true)
		## Око
		draw_circle(Vector2(-s * 0.8, -s * 0.15), s * 0.12, Color.WHITE)
		draw_circle(Vector2(-s * 0.8, -s * 0.15), s * 0.06, Color(0.15, 0.15, 0.25, 0.8))
		## Посмішка
		draw_arc(Vector2(-s * 0.6, s * 0.1), s * 0.2, 0.2, PI - 0.2, 12,
			Color(0.2, 0.3, 0.5, 0.6), 2.0, true)


## Скриня з скарбами — тап для бонусу
class _TreasureChest extends Node2D:
	signal tapped

	func _ready() -> void:
		var area: Area2D = Area2D.new()
		area.input_pickable = true
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(80, 60)
		shape.shape = rect
		area.add_child(shape)
		add_child(area)
		area.input_event.connect(_on_input)

	func _draw() -> void:
		var s: float = 30.0
		## Shadow (LAW 28)
		draw_rect(Rect2(Vector2(-s * 1.2, -s * 0.6) + Vector2(2, 3),
			Vector2(s * 2.4, s * 1.4)), Color(0, 0, 0, 0.15), true)
		## Тіло скрині
		draw_rect(Rect2(Vector2(-s * 1.2, -s * 0.6), Vector2(s * 2.4, s * 1.4)),
			Color(0.55, 0.3, 0.1), true)
		## Кришка
		draw_rect(Rect2(Vector2(-s * 1.3, -s * 0.9), Vector2(s * 2.6, s * 0.4)),
			Color(0.65, 0.35, 0.1), true)
		## Золотий замок
		draw_circle(Vector2.ZERO, s * 0.2, Color("ffd700"))
		draw_circle(Vector2.ZERO, s * 0.12, Color("ffaa00"))
		## Блискітки навколо
		for i: int in 4:
			var angle: float = float(i) / 4.0 * TAU + 0.4
			var pos: Vector2 = Vector2(cos(angle), sin(angle)) * s * 1.0
			draw_circle(pos, maxf(s * 0.06, 1.5), Color(1, 1, 0.7, 0.6))

	func _on_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
		if event is InputEventMouseButton and event.pressed:
			tapped.emit()
		elif event is InputEventScreenTouch and event.pressed:
			tapped.emit()


## Гігантський пузир — потребує 3 тапів щоб лопнути
class _GiantBubble extends Node2D:
	signal tapped

	func _ready() -> void:
		var area: Area2D = Area2D.new()
		area.input_pickable = true
		var shape: CollisionShape2D = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = 100.0
		shape.shape = circle
		area.add_child(shape)
		add_child(area)
		area.input_event.connect(_on_input)

	func _draw() -> void:
		var r: float = 90.0
		## Велике напівпрозоре тіло
		draw_circle(Vector2.ZERO, r, Color(0.4, 0.8, 1.0, 0.35))
		## Darker bottom
		var segs: int = 20
		var bottom_pts: PackedVector2Array = PackedVector2Array()
		bottom_pts.append(Vector2(-r, 0))
		for i: int in range(segs + 1):
			var angle: float = float(i) / float(segs) * PI
			bottom_pts.append(Vector2(cos(angle), sin(angle)) * r)
		draw_colored_polygon(bottom_pts, Color(0.2, 0.5, 0.7, 0.2))
		## Обводка
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.7, 0.9, 1.0, 0.6), 3.0, true)
		## Великий відблиск
		draw_circle(Vector2(-r * 0.25, -r * 0.25), r * 0.3, Color(1, 1, 1, 0.35))
		## Sparkle
		draw_circle(Vector2(-r * 0.35, -r * 0.4), maxf(r * 0.08, 2.0), Color(1, 1, 1, 0.6))
		## "?" або "3x TAP" візуальна підказка — 3 маленькі кружечки
		for i: int in 3:
			var x_off: float = (float(i) - 1.0) * 20.0
			draw_circle(Vector2(x_off, r * 0.3), 6.0, Color(1, 1, 1, 0.4))

	func _on_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
		if event is InputEventMouseButton and event.pressed:
			tapped.emit()
		elif event is InputEventScreenTouch and event.pressed:
			tapped.emit()
