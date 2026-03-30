extends BaseMiniGame

## Photo Crasher / Фотобомбер — знайди хто влiз у групове фото!
## Toddler: візуально інший (слон серед зайців).
## Preschool: категорійний інтрудер (їжа серед тварин, дике серед домашніх).
## R1: 4 items, obvious. R2: 5. R3: category. R4: 6, subtle. R5: 2 crashers.

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 5
const ITEM_SCALE: Vector2 = Vector2(0.4, 0.4)
const GRID_GAP: float = 40.0
const TAP_RADIUS: float = 110.0
const DEAL_STAGGER: float = 0.12
const DEAL_DURATION: float = 0.45
const TOP_MARGIN: float = 110.0
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0
## Шанс що crasher має "маскування" (вуса/парік-тінт) — падає при знаходженні
const DISGUISE_CHANCE: float = 0.35
const DISGUISE_TINT: Color = Color(0.9, 0.85, 1.0, 1.0)
const CRASHER_EXIT_DURATION: float = 0.5
const APPLAUSE_BOUNCE_SCALE: float = 1.15
## Вхідні напрямки для "позування" — items прилітають з різних сторін
const ENTRY_OFFSETS: Array[Vector2] = [
	Vector2(-300, 0), Vector2(300, 0), Vector2(0, -300),
	Vector2(-200, -200), Vector2(200, -200), Vector2(0, 300),
]

var _is_toddler: bool = false
var _total_rounds: int = 0
var _round: int = 0
var _items: Array[Node2D] = []
var _crashers: Array[Node2D] = []
var _crashers_remaining: int = 0
var _used_indices: Array[int] = []
var _start_time: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _idle_timer: SceneTreeTimer = null
## Кешуємо позиції items для photo-pose повернення після помилкового тапу
var _item_positions: Dictionary = {}
## Трекаємо замасковані crashers
var _disguised_items: Dictionary = {}
## Flash overlay для "camera flash" при початку раунду
var _flash_rect: ColorRect = null
## Polaroid gallery strip — акумулюємо мініатюри після кожного раунду
var _polaroid_strip: Array[Panel] = []
var _polaroid_container: HBoxContainer = null


func _ready() -> void:
	game_id = "odd_one_out"
	_skill_id = "classification"
	bg_theme = "sky"  ## Фотозона під відкритим небом
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
	_rng.randomize()
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_instruction_pill(tr("PHOTO_CRASHER_FIND"), 26)
	_update_round_label("1 / %d" % _total_rounds)
	_build_polaroid_strip()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	var is_tap: bool = false
	if event is InputEventMouseButton:
		is_tap = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		is_tap = event.pressed
	if not is_tap:
		return
	var pos: Vector2 = get_global_mouse_position()
	for item: Node2D in _items:
		if not is_instance_valid(item):
			continue
		if pos.distance_to(item.global_position) < TAP_RADIUS:
			_handle_tap(item)
			return


func _handle_tap(item: Node2D) -> void:
	_input_locked = true
	if _crashers.has(item):
		_handle_correct_crasher(item)
	else:
		_handle_wrong(item)


## Crasher знайдений — "oops" анімація виходу + маска падає (якщо є)
func _handle_correct_crasher(item: Node2D) -> void:
	_register_correct(item)
	VFXManager.spawn_golden_burst(item.global_position)
	_crashers_remaining -= 1
	## Зняти маскування якщо є — "маска падає"
	if _disguised_items.has(item):
		_drop_disguise(item)
	## Embarrassed exit — crasher тікає зі сцени
	_animate_crasher_exit(item)


func _handle_wrong(item: Node2D) -> void:
	if _is_toddler:
		_register_error(item)
	else:
		_errors += 1
		_register_error(item)
	var delay: float = 0.15 if SettingsManager.reduced_motion else 0.3
	var tw: Tween = _create_game_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer()
	)


## Crasher embarrassed exit — зменшується + з'їжджає вниз + "oops" повертається
func _animate_crasher_exit(item: Node2D) -> void:
	if SettingsManager.reduced_motion:
		_on_crasher_exited(item)
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tw: Tween = _create_game_tween()
	## Embarrassed wobble — "ой, мене спіймали!"
	tw.tween_property(item, "rotation_degrees", 12.0, 0.08)
	tw.tween_property(item, "rotation_degrees", -12.0, 0.08)
	tw.tween_property(item, "rotation_degrees", 0.0, 0.06)
	## Shrink + slide down off screen
	tw.set_parallel(true)
	tw.tween_property(item, "scale", Vector2(0.1, 0.1), CRASHER_EXIT_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(item, "position:y", vp.y + 100.0, CRASHER_EXIT_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(item, "modulate:a", 0.0, CRASHER_EXIT_DURATION * 0.8)
	tw.set_parallel(false)
	tw.tween_callback(_on_crasher_exited.bind(item))


func _on_crasher_exited(item: Node2D) -> void:
	if not is_instance_valid(self):
		return
	## Прибрати crasher з масиву items
	if _items.has(item):
		_items.erase(item)
	if _crashers.has(item):
		_crashers.erase(item)
	if _disguised_items.has(item):
		_disguised_items.erase(item)
	if _item_positions.has(item):
		_item_positions.erase(item)
	if is_instance_valid(item):
		item.queue_free()
	## Група аплодує — bounce решта items
	_animate_group_applause()
	if _crashers_remaining <= 0:
		## Всіх crashers знайдено — advance
		var delay: float = 0.1 if SettingsManager.reduced_motion else 0.6
		var advance_tw: Tween = _create_game_tween()
		advance_tw.tween_interval(delay)
		advance_tw.tween_callback(_advance_round)
	else:
		## Є ще crashers — unlock input
		var delay: float = 0.1 if SettingsManager.reduced_motion else 0.4
		var unlock_tw: Tween = _create_game_tween()
		unlock_tw.tween_interval(delay)
		unlock_tw.tween_callback(func() -> void:
			_input_locked = false
			_reset_idle_timer()
		)


## Група "аплодує" — items підстрибують (bounce effect)
func _animate_group_applause() -> void:
	if SettingsManager.reduced_motion:
		return
	for item: Node2D in _items:
		if not is_instance_valid(item):
			continue
		if _crashers.has(item):
			continue
		var tw: Tween = _create_game_tween()
		var orig_scale: Vector2 = item.scale
		var delay: float = _rng.randf_range(0.0, 0.15)
		tw.tween_property(item, "scale", orig_scale * APPLAUSE_BOUNCE_SCALE, 0.1)\
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(item, "scale", orig_scale, 0.15)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## "Маска падає" — зняти тінт disguise
func _drop_disguise(item: Node2D) -> void:
	if not is_instance_valid(item):
		return
	if SettingsManager.reduced_motion:
		item.modulate = Color.WHITE
		return
	var tw: Tween = _create_game_tween()
	tw.tween_property(item, "modulate", Color.WHITE, 0.2)


## Побудувати HBoxContainer для polaroid strip угорі екрану
func _build_polaroid_strip() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_polaroid_container = HBoxContainer.new()
	_polaroid_container.position = Vector2(vp.x * 0.5 - 180.0, 8.0)
	_polaroid_container.size = Vector2(360.0, 66.0)
	_polaroid_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_polaroid_container.add_theme_constant_override("separation", 8)
	_polaroid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_polaroid_container)


## Додати polaroid мініатюру після знайденого crasher
func _add_polaroid_thumbnail(round_num: int) -> void:
	if not is_instance_valid(_polaroid_container):
		push_warning("OddOneOut: _polaroid_container freed before polaroid add")
		return
	var polaroid: Panel = Panel.new()
	polaroid.custom_minimum_size = Vector2(56, 62)
	var pol_style: StyleBoxFlat = StyleBoxFlat.new()
	pol_style.bg_color = Color(1.0, 0.99, 0.96, 0.92)
	pol_style.set_corner_radius_all(4)
	pol_style.shadow_color = Color(0, 0, 0, 0.18)
	pol_style.shadow_size = 4
	pol_style.shadow_offset = Vector2(1, 2)
	pol_style.border_color = Color(0.85, 0.82, 0.78, 0.6)
	pol_style.set_border_width_all(1)
	## Нижня частина товщі — як у полароїда
	pol_style.set_content_margin_all(3)
	pol_style.content_margin_bottom = 12
	polaroid.add_theme_stylebox_override("panel", pol_style)
	polaroid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## "Фото" область — темніший внутрішній квадрат
	var photo: Panel = Panel.new()
	photo.position = Vector2(4, 3)
	photo.size = Vector2(48, 38)
	var photo_style: StyleBoxFlat = StyleBoxFlat.new()
	## Чергуємо теплі кольори для різних раундів (LAW 3: visual distinction)
	var photo_colors: Array[Color] = [
		Color("e3f2fd"), Color("fce4ec"), Color("e8f5e9"),
		Color("fff3e0"), Color("f3e5f5"),
	]
	var safe_idx: int = clampi(round_num, 0, photo_colors.size() - 1)
	photo_style.bg_color = photo_colors[safe_idx]
	photo_style.set_corner_radius_all(2)
	photo.add_theme_stylebox_override("panel", photo_style)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	polaroid.add_child(photo)
	## Номер раунду на "фото"
	var num_label: Label = Label.new()
	num_label.text = str(round_num + 1)
	num_label.add_theme_font_size_override("font_size", 24)
	num_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35, 0.7))
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_label.position = Vector2(0, 0)
	num_label.size = Vector2(48, 38)
	num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.add_child(num_label)
	## Checkmark зірочка внизу поляроїда
	var check: Label = Label.new()
	check.text = "*"
	check.add_theme_font_size_override("font_size", 14)
	check.add_theme_color_override("font_color", Color("66bb6a", 0.8))
	check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	check.position = Vector2(4, 42)
	check.size = Vector2(48, 16)
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	polaroid.add_child(check)
	_polaroid_container.add_child(polaroid)
	_polaroid_strip.append(polaroid)
	## Поява з анімацією (squash & stretch)
	if not SettingsManager.reduced_motion:
		polaroid.pivot_offset = Vector2(28, 31)
		polaroid.scale = Vector2(0.0, 0.0)
		polaroid.modulate.a = 0.0
		var tw: Tween = _create_game_tween().set_parallel(true)
		tw.tween_property(polaroid, "scale", Vector2.ONE, 0.35)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(polaroid, "modulate:a", 1.0, 0.2)


func _advance_round() -> void:
	if _game_over:
		return
	## Додати polaroid перед очисткою раунду
	_add_polaroid_thumbnail(_round)
	_clear_round()
	_round += 1
	if _round >= _total_rounds:
		_finish()
	else:
		_update_round_label("%d / %d" % [_round + 1, _total_rounds])
		_start_round()


func _start_round() -> void:
	var crasher_count: int = 1
	## R5 (round index 4): два crashers!
	if _round >= _total_rounds - 1:
		crasher_count = 2
		if is_instance_valid(_instruction_label):
			_instruction_label.text = tr("PHOTO_CRASHER_FIND_TWO")
	elif is_instance_valid(_instruction_label):
		_instruction_label.text = tr("PHOTO_CRASHER_FIND")
	if _is_toddler:
		_generate_toddler_round(crasher_count)
	else:
		_generate_preschool_round(crasher_count)
	## A8: guard — якщо items порожні через fallback failures
	if _items.size() == 0:
		push_warning("OddOneOut: no items created, skipping round")
		_round += 1
		if _round >= _total_rounds:
			_finish()
		else:
			_start_round()
		return
	_deal_items()
	_fire_camera_flash()


## Toddler: візуально інша тварина серед однакових
func _generate_toddler_round(crasher_count: int) -> void:
	## Кількість majority items зростає з раундами (LAW 6 / A4)
	var majority_count: int = _scale_stepped_i(3, 5, _round, _total_rounds)
	var total_unique: int = 1 + crasher_count
	var indices: Array[int] = _pick_indices(total_unique)
	## A8: fallback guard
	if indices.size() < total_unique:
		push_warning("OddOneOut: недостатньо індексів для toddler round")
		indices = _pick_indices(maxi(total_unique, 2))
	if indices.size() < 2:
		push_warning("OddOneOut: critical fallback — недостатньо даних")
		return
	## Majority — всі одного виду
	var majority_data: Dictionary = GameData.ANIMALS_AND_FOOD[indices[0]]
	var majority_scene: PackedScene = majority_data.get("animal_scene")
	if not majority_scene:
		push_warning("OddOneOut: majority animal_scene відсутня")
		return
	for i: int in range(majority_count):
		var item: Node2D = _create_item(majority_scene)
		if item:
			_items.append(item)
	## Crashers — інші тварини
	for c: int in range(crasher_count):
		var c_idx: int = mini(1 + c, indices.size() - 1)
		var crasher_data: Dictionary = GameData.ANIMALS_AND_FOOD[indices[c_idx]]
		var crasher_scene: PackedScene = crasher_data.get("animal_scene")
		if not crasher_scene:
			push_warning("OddOneOut: crasher animal_scene відсутня")
			continue
		var crasher: Node2D = _create_item(crasher_scene)
		if crasher:
			_items.append(crasher)
			_crashers.append(crasher)
			_maybe_apply_disguise(crasher)
	_crashers_remaining = _crashers.size()
	_items.shuffle()


## Preschool: категорійний інтрудер (їжа серед тварин, або навпаки)
func _generate_preschool_round(crasher_count: int) -> void:
	var majority_count: int = _scale_stepped_i(3, 5, _round, _total_rounds)
	var total_needed: int = majority_count + crasher_count
	var indices: Array[int] = _pick_indices(total_needed)
	## A8: guard
	if indices.size() < 2:
		push_warning("OddOneOut: preschool fallback — недостатньо індексів")
		indices = _pick_indices(maxi(total_needed, 4))
	majority_count = mini(majority_count, maxi(indices.size() - crasher_count, 1))
	## Majority: тварини. Crasher: їжа (або навпаки)
	var use_animals_for_majority: bool = _rng.randi() % 2 == 0
	for i: int in range(majority_count):
		if i >= indices.size():
			break
		var data: Dictionary = GameData.ANIMALS_AND_FOOD[indices[i]]
		var scene_key: String = "animal_scene" if use_animals_for_majority else "food_scene"
		var scene: PackedScene = data.get(scene_key)
		if not scene:
			push_warning("OddOneOut: preschool majority scene відсутня")
			continue
		var item: Node2D = _create_item(scene)
		if item:
			_items.append(item)
	## Crashers — з протилежної категорії
	var crasher_scene_key: String = "food_scene" if use_animals_for_majority else "animal_scene"
	for c: int in range(crasher_count):
		var c_idx: int = majority_count + c
		if c_idx >= indices.size():
			c_idx = indices.size() - 1
		if c_idx < 0:
			push_warning("OddOneOut: no valid crasher index")
			continue
		var crasher_data: Dictionary = GameData.ANIMALS_AND_FOOD[indices[c_idx]]
		var crasher_scene: PackedScene = crasher_data.get(crasher_scene_key)
		if not crasher_scene:
			push_warning("OddOneOut: preschool crasher scene відсутня")
			continue
		var crasher: Node2D = _create_item(crasher_scene)
		if crasher:
			_items.append(crasher)
			_crashers.append(crasher)
			_maybe_apply_disguise(crasher)
	_crashers_remaining = _crashers.size()
	_items.shuffle()


## Створити item з premium матеріалом (LAW 28)
func _create_item(scene: PackedScene) -> Node2D:
	if not scene:
		push_warning("OddOneOut: null scene passed to _create_item")
		return null
	var item: Node2D = scene.instantiate()
	var scale_factor: float = 1.0
	if _is_toddler:
		scale_factor = TODDLER_SCALE
	item.scale = ITEM_SCALE * scale_factor
	add_child(item)
	item.material = GameData.create_premium_material(
		0.05, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.12, 0.28, 0.22)
	return item


## Маскування crasher — тонкий тінт "disguise" що падає при знаходженні
func _maybe_apply_disguise(item: Node2D) -> void:
	if _rng.randf() > DISGUISE_CHANCE:
		return
	if not is_instance_valid(item):
		return
	item.modulate = DISGUISE_TINT
	## Невелике обертання — "парік перекосився"
	item.rotation_degrees = _rng.randf_range(-6.0, 6.0)
	_disguised_items[item] = true


## Розкласти items на сцені — "photo pose" анімація (LAW 23: input locked)
func _deal_items() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var scale_factor: float = 1.0
	if _is_toddler:
		scale_factor = TODDLER_SCALE
	var item_size: float = 512.0 * ITEM_SCALE.x * scale_factor
	var cx: float = vp.x * 0.5
	var cy: float = (vp.y + TOP_MARGIN) * 0.5
	var total: int = _items.size()
	if total == 0:
		push_warning("OddOneOut: _deal_items called with 0 items")
		return
	## Динамічна сітка: 2 стовпці для 4, 3 для 5-6+ (LAW 2: min 3 choices)
	var cols: int = 2 if total <= 4 else 3
	@warning_ignore("integer_division")
	var rows: int = (total + cols - 1) / cols
	var cell: float = item_size + GRID_GAP
	var grid_w: float = float(cols) * cell
	var grid_h: float = float(rows) * cell
	var positions: Array[Vector2] = []
	for idx: int in range(total):
		var c: int = idx % cols
		@warning_ignore("integer_division")
		var r: int = idx / cols
		## Невелике випадкове зміщення для "неформального фото" відчуття
		var jitter: Vector2 = Vector2(
			_rng.randf_range(-8.0, 8.0),
			_rng.randf_range(-6.0, 6.0)
		)
		positions.append(Vector2(
			cx - grid_w * 0.5 + cell * (float(c) + 0.5),
			cy - grid_h * 0.5 + cell * (float(r) + 0.5)) + jitter)
	for i: int in range(total):
		if i >= _items.size():
			break
		var item: Node2D = _items[i]
		if not is_instance_valid(item):
			continue
		var target: Vector2 = positions[i]
		_item_positions[item] = target
		if SettingsManager.reduced_motion:
			item.position = target
			item.modulate.a = 1.0 if not _disguised_items.has(item) else DISGUISE_TINT.a
			if i == total - 1:
				_input_locked = false
				_start_idle_breathing(_items)
				_reset_idle_timer()
		else:
			## Photo pose entry — items прилітають з різних боків
			var entry_offset: Vector2 = ENTRY_OFFSETS[i % ENTRY_OFFSETS.size()]
			item.position = target + entry_offset
			item.modulate.a = 0.0
			## Невелике випадкове обертання при вході — "позування"
			var pose_rotation: float = _rng.randf_range(-5.0, 5.0)
			if _disguised_items.has(item):
				pose_rotation = item.rotation_degrees
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = _create_game_tween().set_parallel(true)
			tw.tween_property(item, "position", target, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "scale", item.scale, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
			tw.tween_property(item, "rotation_degrees", pose_rotation, DEAL_DURATION * 0.8)\
				.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			if i == total - 1:
				tw.set_parallel(false)
				tw.tween_callback(func() -> void:
					_input_locked = false
					_start_idle_breathing(_items)
					_reset_idle_timer()
				)


## Camera flash — short white overlay для фото-нарративу
func _fire_camera_flash() -> void:
	if SettingsManager.reduced_motion:
		return
	if is_instance_valid(_flash_rect):
		_flash_rect.queue_free()
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.25)
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_flash_rect)
	var tw: Tween = _create_game_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_flash_rect):
			_flash_rect.queue_free()
			_flash_rect = null
	)


## Очистити раунд — LAW 9 round hygiene, LAW 11 no orphans
func _clear_round() -> void:
	## Erase з dictionaries ПЕРЕД queue_free (LAW 9)
	for item: Node2D in _items:
		if _item_positions.has(item):
			_item_positions.erase(item)
		if _disguised_items.has(item):
			_disguised_items.erase(item)
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()
	_crashers.clear()
	_crashers_remaining = 0
	_item_positions.clear()
	_disguised_items.clear()
	if is_instance_valid(_flash_rect):
		_flash_rect.queue_free()
		_flash_rect = null


func _finish() -> void:
	_game_over = true
	_input_locked = true
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": _total_rounds,
		"earned_stars": earned,
	})


## Обрати N унікальних індексів з ANIMALS_AND_FOOD (LAW 13: bounds safety)
func _pick_indices(count: int) -> Array[int]:
	var pool_size: int = GameData.ANIMALS_AND_FOOD.size()
	if pool_size == 0:
		push_warning("OddOneOut: ANIMALS_AND_FOOD порожній")
		return []
	var available: Array[int] = []
	for i: int in range(pool_size):
		if not _used_indices.has(i):
			available.append(i)
	if available.size() < count:
		_used_indices.clear()
		available.clear()
		for i: int in range(pool_size):
			available.append(i)
	available.shuffle()
	var picked: Array[int] = []
	for i: int in range(mini(count, available.size())):
		picked.append(available[i])
		_used_indices.append(available[i])
	return picked


## Idle hint — пульсувати перший невідомий crasher (A10)
func _reset_idle_timer() -> void:
	if _game_over:
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over:
		return
	## Знайти перший валідний crasher для підказки
	var hint_target: Node2D = null
	for crasher: Node2D in _crashers:
		if is_instance_valid(crasher):
			hint_target = crasher
			break
	if not hint_target:
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		## Level 2+: tutorial hand — покаже точку для тапу
		_reset_idle_timer()
		return
	_pulse_node(hint_target, 1.2)
	_reset_idle_timer()


## Tutorial — A1: zero-text onboarding
func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("ODD_TUTORIAL_TODDLER")
	return tr("ODD_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	## Показати де перший crasher для demo тапу
	for crasher: Node2D in _crashers:
		if is_instance_valid(crasher):
			return {"type": "tap", "target": crasher.global_position}
	return {}
