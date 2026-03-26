extends BaseMiniGame

## PRE-27 Касовий апарат — порахуй монетки до потрібної суми!
## Дитина перетягує монети різного номіналу на касу.

const TOTAL_ROUNDS: int = 5
const IDLE_HINT_DELAY: float = 5.0
const COIN_SIZE: float = 60.0
const DEAL_STAGGER: float = 0.1
const DEAL_DURATION: float = 0.35
const REGISTER_Y_RATIO: float = 0.32
const REGISTER_SIZE: Vector2 = Vector2(180, 120)
const COIN_ROW_Y_RATIO: float = 0.78
const COIN_SPAWN_Y_OFFSET: float = 100.0
const SAFETY_TIMEOUT_SEC: float = 120.0

## Номінали монет та їхні кольори
const COIN_VALUES: Array[int] = [1, 2, 5]
const COIN_COLORS: Dictionary = {
	1: Color("ffd166"),
	2: Color("a8dadc"),
	5: Color("e76f51"),
}

## Toddler: лише номінал 1, великі монети (≥80dp), ціни 1-3
const TODDLER_COIN_SIZE: float = 88.0
const TODDLER_PRICES: Array[int] = [1, 2, 3]
const TODDLER_COIN_VALUES: Array[int] = [1]

## Можливі ціни для кожного раунду
const PRICES_EASY: Array[int] = [3, 4, 5, 6, 7]
const PRICES_HARD: Array[int] = [8, 9, 10, 11, 12]

var _is_toddler: bool = false
var _drag: UniversalDrag = null
var _round: int = 0
var _target_price: int = 0
var _current_sum: int = 0
var _start_time: float = 0.0

var _coin_items: Array[Node2D] = []
var _register: Node2D = null
var _all_round_nodes: Array[Node] = []
var _coin_value: Dictionary = {}
var _coin_origins: Dictionary = {}

var _price_label: Label = null
var _sum_label: Label = null
var _idle_timer: SceneTreeTimer = null


func _ready() -> void:
	game_id = "cash_register"
	bg_theme = "city"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_drag = UniversalDrag.new(self)
	if _is_toddler:
		_drag.snap_radius_override = TODDLER_SNAP_RADIUS
		_drag.magnetic_assist = true
	_drag.item_picked_up.connect(_on_picked)
	_drag.item_dropped_on_target.connect(_on_dropped_target)
	_drag.item_dropped_on_empty.connect(_on_dropped_empty)
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("REGISTER_TUTORIAL_TODDLER")
	return tr("REGISTER_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	if _coin_items.is_empty() or not _register:
		return {}
	var coin: Node2D = _coin_items[0]
	return {"type": "drag", "from": coin.global_position, "to": _register.global_position}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_current_sum = 0
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	## Обираємо ціну для раунду залежно від вікової групи
	var pool: Array[int]
	if _is_toddler:
		pool = TODDLER_PRICES
	elif _round < 3:
		pool = PRICES_EASY
	else:
		pool = PRICES_HARD
	_target_price = pool[randi() % pool.size()]
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_register(vp)
	_spawn_coins(vp)


func _spawn_register(vp: Vector2) -> void:
	## Касовий апарат — дропзона
	_register = Node2D.new()
	_register.position = Vector2(vp.x * 0.5, vp.y * REGISTER_Y_RATIO)
	add_child(_register)
	## Фон каси
	var bg: Panel = Panel.new()
	bg.size = REGISTER_SIZE
	bg.position = Vector2(-REGISTER_SIZE.x * 0.5, -REGISTER_SIZE.y * 0.5)
	var style: StyleBoxFlat = GameData.candy_panel(Color("3d3d5c"), 24)
	style.border_color = Color("ffd166")
	style.set_border_width_all(3)
	bg.add_theme_stylebox_override("panel", style)
	## Grain overlay (LAW 28)
	bg.material = GameData.create_premium_material(0.04, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
	GameData.add_gloss(bg, 14)
	_register.add_child(bg)
	## Цінник
	_price_label = Label.new()
	_price_label.text = "%d" % _target_price
	_price_label.add_theme_font_size_override("font_size", 38)
	_price_label.add_theme_color_override("font_color", Color("ffd166"))
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.position = Vector2(-80, -45)
	_price_label.size = Vector2(160, 50)
	_register.add_child(_price_label)
	## Лічильник поточної суми
	_sum_label = Label.new()
	_sum_label.text = "0 / %d" % _target_price
	_sum_label.add_theme_font_size_override("font_size", 24)
	_sum_label.add_theme_color_override("font_color", Color.WHITE)
	_sum_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sum_label.position = Vector2(-70, 15)
	_sum_label.size = Vector2(140, 35)
	_register.add_child(_sum_label)
	_drag.drop_targets.append(_register)
	_all_round_nodes.append(_register)


func _spawn_coins(vp: Vector2) -> void:
	## Генеруємо набір монет — достатньо щоб зібрати суму
	var coins: Array[int] = _generate_coin_set(_target_price)
	coins.shuffle()
	var count: int = coins.size()
	var spacing: float = vp.x / float(count + 1)
	var coin_y: float = vp.y * COIN_ROW_Y_RATIO
	## Toddler: збільшені монети для кращого touch target (≥80dp)
	var sz: float = TODDLER_COIN_SIZE if _is_toddler else COIN_SIZE
	for i: int in count:
		var val: int = coins[i]
		var item: Node2D = Node2D.new()
		add_child(item)
		## Текстурна монета — HQ спрайт замість code-drawn
		var coin_frame: int = {1: 1, 2: 4, 5: 7}.get(val, 1)
		var coin_tex_path: String = "res://assets/textures/coins/coin_%02d.png" % coin_frame
		var coin_ctrl: Control = Control.new()
		coin_ctrl.size = Vector2(sz, sz)
		coin_ctrl.position = Vector2(-sz * 0.5, -sz * 0.5)
		coin_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(coin_tex_path):
			var coin_tex: Texture2D = load(coin_tex_path)
			var _sz: float = sz  ## Локальна копія для замикання
			coin_ctrl.draw.connect(func() -> void:
				coin_ctrl.draw_texture_rect(coin_tex, Rect2(Vector2.ZERO, Vector2(_sz, _sz)), false)
			)
		else:
			push_warning("cash_register: текстура монети '%s' не знайдена" % coin_tex_path)
		## Grain overlay (LAW 28)
		coin_ctrl.material = GameData.create_premium_material(0.05, 2.0, 0.04, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		item.add_child(coin_ctrl)
		## Номінал монети — кольоровий текст по центру
		var font_sz: int = 32 if _is_toddler else 24
		var num_lbl: Label = Label.new()
		num_lbl.text = str(val)
		num_lbl.add_theme_font_size_override("font_size", font_sz)
		num_lbl.add_theme_color_override("font_color", COIN_COLORS[val])
		num_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
		num_lbl.add_theme_constant_override("shadow_offset_x", 1)
		num_lbl.add_theme_constant_override("shadow_offset_y", 1)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_lbl.position = Vector2(-sz * 0.5, -sz * 0.5)
		num_lbl.size = Vector2(sz, sz)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(num_lbl)
		var target_pos: Vector2 = Vector2(spacing * float(i + 1), coin_y)
		## Deal анімація
		if SettingsManager.reduced_motion:
			item.position = target_pos
			item.modulate.a = 1.0
			if i == count - 1:
				_input_locked = false
				_drag.enabled = true
				_reset_idle_timer()
		else:
			item.position = Vector2(target_pos.x, vp.y + COIN_SPAWN_Y_OFFSET)
			item.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = create_tween().set_parallel(true)
			tw.tween_property(item, "position", target_pos, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
			if i == count - 1:
				tw.chain().tween_callback(func() -> void:
					_input_locked = false
					_drag.enabled = true
					_reset_idle_timer())
		_coin_value[item] = val
		_coin_origins[item] = target_pos
		_coin_items.append(item)
		_drag.draggable_items.append(item)
		_all_round_nodes.append(item)
	_staggered_spawn(_coin_items, 0.08)


func _generate_coin_set(target: int) -> Array[int]:
	## Генеруємо монети що гарантовано дозволяють зібрати суму
	var result: Array[int] = []
	var remaining: int = target
	if _is_toddler:
		## Toddler: лише монети номіналом 1
		for _i: int in target:
			result.append(1)
		## Додаємо 1-2 зайві монети (теж 1)
		var extras: int = randi_range(1, 2)
		for _j: int in extras:
			result.append(1)
		return result
	## Спочатку — монети що складають суму
	while remaining > 0:
		if remaining >= 5 and randf() > 0.3:
			result.append(5)
			remaining -= 5
		elif remaining >= 2 and randf() > 0.3:
			result.append(2)
			remaining -= 2
		else:
			result.append(1)
			remaining -= 1
	## Додаємо кілька зайвих монет для вибору
	var extras: int = randi_range(2, 4)
	for _i: int in extras:
		result.append(COIN_VALUES[randi() % COIN_VALUES.size()])
	return result


## ---- Input ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_input(event)


func _process(delta: float) -> void:
	if _input_locked or _game_over:
		return
	_drag.handle_process(delta)


func _on_picked(_item: Node2D) -> void:
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()


func _on_dropped_target(item: Node2D, _target: Node2D) -> void:
	if _game_over:
		return
	var val: int = _coin_value.get(item, 0)
	var new_sum: int = _current_sum + val
	if new_sum > _target_price:
		## Переплата — помилка, скидаємо раунд
		_handle_overpay(item)
		return
	## Прийняти монету
	_register_correct(item)
	VFXManager.spawn_success_ripple(_register.global_position, Color("ffd166"))
	_current_sum = new_sum
	_sum_label.text = "%d / %d" % [_current_sum, _target_price]
	_drag.draggable_items.erase(item)
	_coin_items.erase(item)
	## Магнітний snap до каси
	if SettingsManager.reduced_motion:
		item.global_position = _register.global_position
		item.modulate.a = 0.3
		if _current_sum == _target_price:
			_on_round_complete()
		else:
			_reset_idle_timer()
		return
	var tw: Tween = create_tween()
	tw.tween_property(item, "global_position", _register.global_position, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(item, "modulate:a", 0.3, 0.2)
	if _current_sum == _target_price:
		tw.chain().tween_callback(_on_round_complete)
	else:
		_reset_idle_timer()


func _on_dropped_empty(item: Node2D) -> void:
	_drag.snap_back(item, _coin_origins.get(item, item.position))


func _handle_overpay(item: Node2D) -> void:
	if _is_toddler:
		_register_error(item)  ## A11: scaffolding для тоддлера
	else:
		_errors += 1
		_register_error(item)
	## Повертаємо лише цю монету, раунд продовжується
	_drag.snap_back(item, _coin_origins.get(item, item.position))
	_reset_idle_timer()


## ---- Управління раундами ----

func _on_round_complete() -> void:
	_input_locked = true
	_drag.enabled = false
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var d: float = 0.15 if SettingsManager.reduced_motion else 0.8
	var tw: Tween = create_tween()
	tw.tween_interval(d)
	tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


func _clear_round() -> void:
	_coin_value.clear()
	_coin_origins.clear()
	_coin_items.clear()
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_register = null
	_price_label = null
	_sum_label = null
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	_drag.clear_drag()


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": TOTAL_ROUNDS, "earned_stars": earned})


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
	if _input_locked or _game_over or _coin_items.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		## A10 Lvl2: tutorial hand — показати правильну монету та касу
		var demo: Dictionary = get_tutorial_demo()
		if demo.has("from") and demo.has("to"):
			var from_pos: Vector2 = demo.get("from", Vector2.ZERO)
			## Знайти монету що відповідає demo позиції
			for item: Node2D in _coin_items:
				if is_instance_valid(item) and item.global_position.distance_to(from_pos) < 10.0:
					_pulse_node(item, 1.3)
					## Яскравий flash на монеті
					if not SettingsManager.reduced_motion:
						var flash_tw: Tween = create_tween()
						flash_tw.tween_property(item, "modulate", Color(1.5, 1.3, 0.7, 1.0), 0.15)
						flash_tw.tween_property(item, "modulate", Color.WHITE, 0.3)
					break
			## Пульсувати касу теж
			if is_instance_valid(_register):
				_pulse_node(_register, 1.15)
		_reset_idle_timer()
		return
	for item: Node2D in _coin_items:
		if is_instance_valid(item):
			_pulse_node(item, 1.15)
			break
	_reset_idle_timer()
