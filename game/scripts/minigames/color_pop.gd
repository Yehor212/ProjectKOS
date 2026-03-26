extends BaseMiniGame

## Color Pop — лопай пузирі! Toddler: все підряд. Preschool: тільки цільовий колір.

const BUBBLE_SCENE: PackedScene = preload("res://scenes/components/bubble.tscn")
const GAME_DURATION: float = 45.0
const MARGIN_X: float = 100.0
const COLORS: Array[Color] = [
	Color("ef4444"), Color("3b82f6"), Color("22c55e"),
	Color("eab308"), Color("a855f7"),
]
const COLOR_KEYS: Array[String] = [
	"COLOR_RED", "COLOR_BLUE", "COLOR_GREEN", "COLOR_YELLOW", "COLOR_PURPLE",
]
const COLOR_IDS: Array[String] = ["red", "blue", "green", "yellow", "purple"]
const TARGET_CHANGE_INTERVAL: float = 10.0
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0
## Toddler params
const TODDLER_SPAWN_INTERVAL: float = 1.5
const TODDLER_SPEED_MIN: float = 80.0
const TODDLER_SPEED_MAX: float = 120.0
const TODDLER_RADIUS: float = 65.0
## Preschool params
const PRESCHOOL_SPAWN_INTERVAL: float = 0.7
const PRESCHOOL_SPEED_MIN: float = 120.0
const PRESCHOOL_SPEED_MAX: float = 200.0
const PRESCHOOL_RADIUS: float = 45.0

var _is_toddler: bool = false
var _score: int = 0
var _speed_multiplier: float = 1.0
var _target_color_idx: int = 0
var _start_time: float = 0.0
var _bubbles: Array[Node2D] = []
var _spawn_timer: Timer = null
var _target_timer: Timer = null
var _idle_timer: SceneTreeTimer = null

## UI
var _score_label: Label = null
var _target_label: Label = null
var _target_circle: _ColorCircle = null
var _timer_bar: ProgressBar = null


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


var _warned_low_time: bool = false


func _process(_delta: float) -> void:
	if _game_over:
		return
	## Прибрати мертві пузирі (вилетіли за екран і зробили queue_free)
	for i: int in range(_bubbles.size() - 1, -1, -1):
		if not is_instance_valid(_bubbles[i]):
			_bubbles.remove_at(i)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var remaining: float = GAME_DURATION - elapsed
	## A4: прогресивна складність — зменшуємо інтервал спавну з часом
	_ramp_difficulty(elapsed)
	if _timer_bar:
		_timer_bar.value = remaining / GAME_DURATION * 100.0
		## UX-19: Попередження при <10с
		if remaining <= 10.0 and remaining > 0.0:
			_timer_bar.modulate = Color("ff6b6b")
			if not _warned_low_time:
				_warned_low_time = true
				AudioManager.play_sfx("click")
				## Пульсація таймера при мало часу
				if not (SettingsManager and SettingsManager.reduced_motion):
					_pulse_tween = create_tween().set_loops()
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
	## Від 0% до 100% часу: інтервал спавну -40%, швидкість +40%
	var progress: float = clampf(elapsed / GAME_DURATION, 0.0, 1.0)
	_speed_multiplier = lerpf(1.0, 1.4, progress)
	var base_interval: float = TODDLER_SPAWN_INTERVAL if _is_toddler else PRESCHOOL_SPAWN_INTERVAL
	var new_interval: float = lerpf(base_interval, base_interval * 0.6, progress)
	if _spawn_timer and absf(_spawn_timer.wait_time - new_interval) > 0.05:
		_spawn_timer.wait_time = new_interval


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
	## Target color display (тільки preschool)
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
	## Контейнер по центру зверху
	var box: HBoxContainer = HBoxContainer.new()
	box.set("theme_override_constants/separation", 12)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.offset_top = 8.0
	box.offset_bottom = 64.0
	box.offset_left = -120.0
	box.offset_right = 120.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_ui_layer.add_child(box)
	## Кольорове коло-індикатор
	_target_circle = _ColorCircle.new()
	_target_circle.custom_minimum_size = Vector2(48, 48)
	## Grain overlay (LAW 28)
	_target_circle.material = GameData.create_premium_material(0.06, 2.0, 0.0, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
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
	## Preschool: таймер зміни цільового кольору
	if not _is_toddler:
		_target_timer = Timer.new()
		_target_timer.wait_time = TARGET_CHANGE_INTERVAL
		_target_timer.timeout.connect(_change_target_color)
		add_child(_target_timer)
		_target_timer.start()
		_change_target_color()
	_reset_idle_timer()


func _spawn_bubble() -> void:
	if _game_over:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bubble: Node2D = BUBBLE_SCENE.instantiate()
	add_child(bubble)
	## Випадковий колір (preschool: ~40% цільового)
	var color_idx: int = randi() % COLORS.size()
	if not _is_toddler and randf() < 0.4:
		color_idx = _target_color_idx
	var speed: float = randf_range(
		TODDLER_SPEED_MIN if _is_toddler else PRESCHOOL_SPEED_MIN,
		TODDLER_SPEED_MAX if _is_toddler else PRESCHOOL_SPEED_MAX) * _speed_multiplier
	var radius: float = TODDLER_RADIUS if _is_toddler else PRESCHOOL_RADIUS
	bubble.setup(COLORS[color_idx], speed, radius)
	bubble.set_meta("color_idx", color_idx)
	bubble.position = Vector2(
		randf_range(MARGIN_X, vp.x - MARGIN_X),
		vp.y + radius * 2.0)
	bubble.popped.connect(_on_bubble_popped)
	_bubbles.append(bubble)


func _on_bubble_popped(bubble: Node2D) -> void:
	if _game_over or _input_locked:
		return
	if _is_toddler:
		## Streak кожні 3 попи занадто часто для тоддлера — рахуємо лише кожен 5-й
		_score += 1
		if _score % 5 == 0:
			_register_correct()
		AudioManager.play_sfx("coin")
		JuicyEffects.combo_vfx(bubble.global_position, _streak_count)
		_spawn_animal_reward(bubble.global_position)
	else:
		var color_idx: int = bubble.get_meta("color_idx", -1)
		if color_idx == _target_color_idx:
			_register_correct()
			_score += 2
			JuicyEffects.combo_vfx(bubble.global_position, _streak_count)
			AudioManager.play_sfx("success")
		else:
			_errors += 1
			_register_error(bubble)
			AudioManager.play_sfx("error")
			HapticsManager.vibrate_light()
			VFXManager.spawn_error_smoke(bubble.global_position)
	_score_label.text = "%d" % _score
	## Score bounce
	if not (SettingsManager and SettingsManager.reduced_motion):
		_score_label.pivot_offset = _score_label.size / 2.0
		var stw: Tween = create_tween()
		stw.tween_property(_score_label, "scale", Vector2(1.3, 1.3), 0.06)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		stw.tween_property(_score_label, "scale", Vector2.ONE, 0.1)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_reset_idle_timer()


func _spawn_animal_reward(pos: Vector2) -> void:
	var idx: int = randi() % GameData.ANIMALS_AND_FOOD.size()
	var pair: Dictionary = GameData.ANIMALS_AND_FOOD[idx]
	var tex_path: String = "res://assets/sprites/animals/%s.png" % pair.name
	if not ResourceLoader.exists(tex_path):
		push_warning("ColorPop: текстуру '%s' не знайдено" % tex_path)
		return
	var tex: Texture2D = load(tex_path)
	if not tex:
		push_warning("ColorPop: текстуру '%s' не знайдено" % tex_path)
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(0.2, 0.2)
	sprite.position = pos
	add_child(sprite)
	## Вилітає вгору, потім падає
	if SettingsManager.reduced_motion:
		sprite.queue_free()
		return
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "position:y", pos.y - 80.0, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:y", pos.y + 400.0, 0.8)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sprite, "rotation", randf_range(-1.0, 1.0), 0.8)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.finished.connect(sprite.queue_free)


func _change_target_color() -> void:
	if _game_over:
		return
	var new_idx: int = randi() % COLORS.size()
	while new_idx == _target_color_idx and COLORS.size() > 1:
		new_idx = randi() % COLORS.size()
	_target_color_idx = new_idx
	_update_target_display()
	## Flash анімація
	if _target_label and not SettingsManager.reduced_motion:
		var parent: Node = _target_label.get_parent()
		if parent:
			parent.pivot_offset = parent.size / 2.0
			var tw: Tween = create_tween()
			tw.tween_property(parent, "scale", Vector2(1.3, 1.3), 0.1)
			tw.tween_property(parent, "scale", Vector2.ONE, 0.15)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _update_target_display() -> void:
	if _target_label:
		_target_label.text = tr("COLOR_POP_TARGET") % tr(COLOR_KEYS[_target_color_idx])
	if _target_circle:
		_target_circle.circle_color = COLORS[_target_color_idx]
		## LAW 25: Update pattern for color-blind mode
		if SettingsManager.color_blind_mode:
			_target_circle.cb_pattern = GameData.get_cb_pattern(COLOR_IDS[_target_color_idx])
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
	## Прибрати пузирі що залишились
	for bubble: Node2D in _bubbles.duplicate():
		if is_instance_valid(bubble):
			bubble.queue_free()
	_bubbles.clear()
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	var stats: Dictionary = {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": 1,
		"earned_stars": earned,
	}
	finish_game(earned, stats)


func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _game_over:
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	## Пульсація кольорового індикатора (preschool) або інструкції (toddler)
	if not _is_toddler and _target_circle and is_instance_valid(_target_circle):
		_pulse_node(_target_circle, 1.2)
	elif _instruction_label and is_instance_valid(_instruction_label):
		_pulse_node(_instruction_label, 1.1)
	_reset_idle_timer()


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("COLOR_POP_TUTORIAL_TODDLER")
	return tr("COLOR_POP_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return {"type": "tap", "target": vp * 0.5}


## Внутрішній клас — кольорове коло-індикатор для HUD
class _ColorCircle extends Control:
	var circle_color: Color = Color.RED
	var cb_pattern: String = ""

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0 - 2.0
		## Shadow
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
