extends BaseMiniGame

## Shadow Theater -- Тофі працює за лаштунками театру тіней.
## Тварини соромляться -- допоможи знайти кожну по тіні, щоб вони вийшли на уклін!
## Дитина перетягує кольорових тварин на відповідні силуети.
## Правильний match: завіса піднімається, тварина кланяється, публіка аплодує.
## Неправильний: тінь хитає пальцем (wag animation).
## R5 фінал: всі matched тварини виходять і танцюють синхронно.

const MAX_ROUNDS: int = 5
const SAFETY_TIMEOUT_SEC: float = 120.0
const SHADOW_Y_CENTER: float = 0.32
const ANIMAL_Y_CENTER: float = 0.78
const STAGE_TOP_Y: float = 0.08
const STAGE_FLOOR_Y: float = 0.56
const MARGIN_X: float = 0.10
const CURTAIN_HEIGHT: float = 0.15
const IDLE_HINT_DELAY: float = 5.0
## Масштаби спрайтів
const SHADOW_SCALE_BASE: Vector2 = Vector2(0.28, 0.28)
const ANIMAL_SCALE_BASE: Vector2 = Vector2(0.32, 0.32)
## Театральні кольори
const CURTAIN_COLOR: Color = Color(0.55, 0.08, 0.12, 0.92)
const CURTAIN_FRINGE: Color = Color(0.85, 0.65, 0.15, 0.95)
const STAGE_FLOOR_COLOR: Color = Color(0.45, 0.28, 0.12, 0.85)
const PELMET_COLOR: Color = Color(0.40, 0.06, 0.10, 0.95)
const SPOTLIGHT_COLOR: Color = Color(1.0, 1.0, 0.85, 0.06)

## Стан гри
var _is_toddler: bool = false
var _drag: UniversalDrag = null
var _current_round: int = 0
var _silhouette_shader: Shader = null
var _used_indices: Array[int] = []
var _start_time: float = 0.0
var _idle_timer: SceneTreeTimer = null

## Раундові дані (очищуються між раундами -- A9)
var _shadow_nodes: Dictionary = {}    ## name -> Sprite2D (силует на сцені)
var _animal_nodes: Dictionary = {}    ## name -> Sprite2D (кольорова тварина знизу)
var _curtain_nodes: Dictionary = {}   ## name -> ColorRect (завіса над силуетом)
var _animal_origins: Dictionary = {}  ## Node2D -> Vector2 (початкові позиції для snap back)
var _matched_names: Array[String] = []  ## імена успішно matched тварин
var _matched_count: int = 0
var _round_target_count: int = 0
var _round_pairs: Array[Dictionary] = []  ## пари поточного раунду
var _shadow_tweens: Array[Tween] = []     ## idle анімації силуетів
var _round_errors_count: int = 0          ## помилки в поточному раунді
## Театральний декор (створюється один раз)
var _stage_floor: ColorRect = null
var _pelmet: ColorRect = null
var _spotlights: Array[Node2D] = []
## Всі matched тварини за всю гру (для фіналу R5)
var _all_matched_sprites: Array[Dictionary] = []  ## {name, position}


func _ready() -> void:
	game_id = "shadow_match"
	bg_theme = "music"  ## Теплий театральний фон
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
	_build_theater_stage()
	_build_instruction_pill(tr("SHADOW_TUTORIAL"), 24)
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


## ---- Театральна сцена (процедурний декор) ----

func _build_theater_stage() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Підлога сцени -- дерев'яна дошка
	_stage_floor = ColorRect.new()
	_stage_floor.color = STAGE_FLOOR_COLOR
	_stage_floor.position = Vector2(0.0, vp.y * STAGE_FLOOR_Y)
	_stage_floor.size = Vector2(vp.x, vp.y * 0.06)
	_stage_floor.z_index = 1
	add_child(_stage_floor)
	## Золота смужка на краю сцени
	var gold_strip: ColorRect = ColorRect.new()
	gold_strip.color = CURTAIN_FRINGE
	gold_strip.position = Vector2(0.0, vp.y * STAGE_FLOOR_Y - 3.0)
	gold_strip.size = Vector2(vp.x, 6.0)
	gold_strip.z_index = 2
	add_child(gold_strip)
	## Верхній ламбрекен
	_pelmet = ColorRect.new()
	_pelmet.color = PELMET_COLOR
	_pelmet.position = Vector2(0.0, vp.y * STAGE_TOP_Y - 10.0)
	_pelmet.size = Vector2(vp.x, 28.0)
	_pelmet.z_index = 3
	add_child(_pelmet)
	## Золотий бордюр ламбрекена
	var pelmet_gold: ColorRect = ColorRect.new()
	pelmet_gold.color = CURTAIN_FRINGE
	pelmet_gold.position = Vector2(0.0, vp.y * STAGE_TOP_Y + 15.0)
	pelmet_gold.size = Vector2(vp.x, 5.0)
	pelmet_gold.z_index = 4
	add_child(pelmet_gold)
	## Прожектори (2 кола світла на сцені)
	for side_x: float in [0.25, 0.75]:
		var spot: Sprite2D = Sprite2D.new()
		## Конус світла через модуляцію
		spot.modulate = SPOTLIGHT_COLOR
		spot.position = Vector2(vp.x * side_x, vp.y * SHADOW_Y_CENTER)
		spot.z_index = 0
		add_child(spot)
		_spotlights.append(spot)


## ---- Генерація раунду ----

func _generate_round() -> void:
	_cleanup_round()
	var round_cfg: Dictionary = _get_round_config(_current_round)
	var slot_count: int = round_cfg.get("slots", 3)
	var has_anim: bool = round_cfg.get("animation", false)
	var rotation_deg: float = round_cfg.get("rotation", 0.0)
	var overlap_offset: float = round_cfg.get("overlap", 0.0)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Обрати тварин
	var indices: Array[int] = _pick_random_indices(slot_count)
	_round_pairs.clear()
	for idx: int in indices:
		if idx >= 0 and idx < GameData.ANIMALS_AND_FOOD.size():
			_round_pairs.append(GameData.ANIMALS_AND_FOOD[idx])
	## Fallback: недостатньо тварин (LAW 7/A8)
	if _round_pairs.size() < 3:
		push_warning("ShadowMatch: Not enough animals, resetting used indices")
		_used_indices.clear()
		indices = _pick_random_indices(slot_count)
		_round_pairs.clear()
		for idx: int in indices:
			if idx >= 0 and idx < GameData.ANIMALS_AND_FOOD.size():
				_round_pairs.append(GameData.ANIMALS_AND_FOOD[idx])
	if _round_pairs.is_empty():
		push_warning("ShadowMatch: No pairs available, finishing game")
		finish_game(_calculate_stars(_errors), {"time_sec": 0.0, "errors": _errors, "rounds_played": 0, "earned_stars": _calculate_stars(_errors)})
		return
	_round_target_count = _round_pairs.size()
	_matched_count = 0
	## Розрахувати позиції
	var actual_count: int = _round_pairs.size()
	var slot_start_x: float = vp.x * MARGIN_X
	var slot_end_x: float = vp.x * (1.0 - MARGIN_X)
	var spacing: float = (slot_end_x - slot_start_x) / float(maxi(actual_count - 1, 1))
	var shadow_y: float = vp.y * SHADOW_Y_CENTER
	var animal_y: float = vp.y * ANIMAL_Y_CENTER
	## Масштаб відповідно до віку
	var s_scale: Vector2 = SHADOW_SCALE_BASE
	var a_scale: Vector2 = ANIMAL_SCALE_BASE
	if _is_toddler:
		s_scale = SHADOW_SCALE_BASE * 1.15
		a_scale = ANIMAL_SCALE_BASE * 1.15
	## Перемішати порядок тварин знизу (щоб не збігалось з силуетами)
	var shuffled_pairs: Array[Dictionary] = _round_pairs.duplicate()
	shuffled_pairs.shuffle()
	var spawn_nodes: Array = []
	## Створити силуети на сцені
	for i: int in _round_pairs.size():
		var pair: Dictionary = _round_pairs[i]
		var aname: String = pair.get("name", "")
		if aname.is_empty():
			push_warning("ShadowMatch: pair missing 'name' key")
			continue
		var sprite_path: String = "res://assets/sprites/animals/%s.png" % aname
		if not ResourceLoader.exists(sprite_path):
			push_warning("ShadowMatch: Missing sprite: " + sprite_path)
			continue
		var tex: Texture2D = load(sprite_path)
		if not tex:
			push_warning("ShadowMatch: Failed to load texture: " + sprite_path)
			continue
		## Силует
		var shadow: Sprite2D = Sprite2D.new()
		shadow.texture = tex
		shadow.scale = s_scale
		shadow.name = aname
		var sx: float = slot_start_x + float(i) * spacing
		## Overlap offset для R5
		if overlap_offset > 0.0 and i > 0 and i == _round_pairs.size() - 1:
			sx -= overlap_offset
		shadow.position = Vector2(sx, shadow_y)
		shadow.z_index = 2
		## Rotation для R4+ (тільки Preschool)
		if rotation_deg > 0.0 and i == _round_pairs.size() - 1 and not _is_toddler:
			shadow.rotation_degrees = rotation_deg
		## Шейдер силуету
		if _silhouette_shader:
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = _silhouette_shader
			mat.set_shader_parameter("tint_color", Color(0.05, 0.03, 0.08, 0.80))
			shadow.material = mat
		add_child(shadow)
		_shadow_nodes[aname] = shadow
		spawn_nodes.append(shadow)
		## Завіса над силуетом (піднімається при match)
		var curtain: ColorRect = ColorRect.new()
		var curtain_w: float = 100.0
		if tex:
			curtain_w = tex.get_width() * s_scale.x + 30.0
		var curtain_h: float = vp.y * CURTAIN_HEIGHT
		curtain.color = CURTAIN_COLOR
		curtain.size = Vector2(curtain_w, curtain_h)
		curtain.position = Vector2(sx - curtain_w * 0.5, shadow_y - curtain_h - 20.0)
		curtain.z_index = 5
		add_child(curtain)
		_curtain_nodes[aname] = curtain
		## Idle анімація силуетів (R2+)
		if has_anim and not SettingsManager.reduced_motion:
			_start_shadow_idle_anim(shadow, i)
	## Створити кольорові тварини знизу (перемішаний порядок)
	for i: int in shuffled_pairs.size():
		var pair: Dictionary = shuffled_pairs[i]
		var aname: String = pair.get("name", "")
		if aname.is_empty():
			continue
		var sprite_path: String = "res://assets/sprites/animals/%s.png" % aname
		if not ResourceLoader.exists(sprite_path):
			push_warning("ShadowMatch: Missing animal sprite: " + sprite_path)
			continue
		var tex: Texture2D = load(sprite_path)
		if not tex:
			push_warning("ShadowMatch: Failed to load animal: " + sprite_path)
			continue
		var animal: Sprite2D = Sprite2D.new()
		animal.texture = tex
		animal.scale = a_scale
		animal.name = aname
		var ax: float = slot_start_x + float(i) * spacing
		animal.position = Vector2(ax, animal_y)
		animal.z_index = 6
		## Premium material для кольорових тварин (LAW 28)
		animal.material = GameData.create_premium_material(
			0.05, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.12, 0.30, 0.25)
		add_child(animal)
		_animal_nodes[aname] = animal
		_animal_origins[animal] = animal.position
		spawn_nodes.append(animal)
	## Перевірка: чи створено достатньо пар (LAW 15)
	var valid_shadow_count: int = _shadow_nodes.size()
	var valid_animal_count: int = _animal_nodes.size()
	if valid_shadow_count == 0 or valid_animal_count == 0:
		push_warning("ShadowMatch: No valid pairs created, finishing")
		finish_game(_calculate_stars(_errors), {"time_sec": 0.0, "errors": _errors, "rounds_played": 0, "earned_stars": _calculate_stars(_errors)})
		return
	_round_target_count = mini(valid_shadow_count, valid_animal_count)
	## Каскадна поява (LAW 29)
	_staggered_spawn(spawn_nodes, 0.08)
	## Налаштувати drag
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	for key: String in _animal_nodes:
		if _animal_nodes.has(key):
			var node: Node2D = _animal_nodes[key]
			if is_instance_valid(node):
				_drag.draggable_items.append(node)
	for key: String in _shadow_nodes:
		if _shadow_nodes.has(key):
			var node: Node2D = _shadow_nodes[key]
			if is_instance_valid(node):
				_drag.drop_targets.append(node)
	## Магнітний асист для тоддлерів
	if _is_toddler:
		_drag.magnetic_assist = true
		var pairs_dict: Dictionary = {}
		for key: String in _animal_nodes:
			if _animal_nodes.has(key) and _shadow_nodes.has(key):
				pairs_dict[_animal_nodes[key]] = _shadow_nodes[key]
		if not pairs_dict.is_empty():
			_drag.set_correct_pairs(pairs_dict)
	## Unlock input після анімації
	var unlock_delay: float = 0.15 if SettingsManager.reduced_motion \
		else float(spawn_nodes.size()) * 0.08 + 0.4
	var tw: Tween = _create_game_tween()
	tw.tween_interval(unlock_delay)
	tw.tween_callback(func() -> void:
		if _game_over:
			return
		_drag.enabled = true
		_input_locked = false
		_reset_idle_timer())
	## Оновити HUD
	_update_round_label(tr("COUNTING_ROUND") % [_current_round + 1, MAX_ROUNDS])
	_reset_idle_timer()


## ---- Конфігурація складності по раундах (A4 qualitative difficulty ramp) ----

func _get_round_config(round_idx: int) -> Dictionary:
	## Toddler: простіша прогресія, без rotation/overlap
	if _is_toddler:
		match round_idx:
			0: return {"slots": 3, "animation": false, "rotation": 0.0, "overlap": 0.0}
			1: return {"slots": 3, "animation": false, "rotation": 0.0, "overlap": 0.0}
			2: return {"slots": 3, "animation": true, "rotation": 0.0, "overlap": 0.0}
			3: return {"slots": 4, "animation": true, "rotation": 0.0, "overlap": 0.0}
			_: return {"slots": 4, "animation": true, "rotation": 0.0, "overlap": 0.0}
	## Preschool: повна якісна прогресія
	match round_idx:
		0: return {"slots": 3, "animation": false, "rotation": 0.0, "overlap": 0.0}
		1: return {"slots": 3, "animation": true, "rotation": 0.0, "overlap": 0.0}
		2: return {"slots": 4, "animation": true, "rotation": 0.0, "overlap": 0.0}
		3: return {"slots": 4, "animation": true, "rotation": 15.0, "overlap": 0.0}
		_: return {"slots": 5, "animation": true, "rotation": 0.0, "overlap": 40.0}


## ---- Idle анімація силуетів (R2+: walk cycle, breathe, bob) ----

func _start_shadow_idle_anim(shadow: Sprite2D, idx: int) -> void:
	if not is_instance_valid(shadow):
		return
	var orig_pos: Vector2 = shadow.position
	var orig_rot: float = shadow.rotation_degrees
	## Різні типи анімацій за індексом
	var anim_type: int = idx % 3
	var tw: Tween = create_tween().set_loops()
	match anim_type:
		0:  ## Повільна ходьба (коливання X)
			tw.tween_property(shadow, "position:x", orig_pos.x - 8.0, 1.2)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(shadow, "position:x", orig_pos.x + 8.0, 1.2)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(shadow, "position:x", orig_pos.x, 0.8)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		1:  ## Підскоки (коливання Y)
			tw.tween_property(shadow, "position:y", orig_pos.y - 12.0, 0.4)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(shadow, "position:y", orig_pos.y, 0.4)\
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_interval(1.5)
		2:  ## Легке хитання (rotation)
			tw.tween_property(shadow, "rotation_degrees", orig_rot - 5.0, 0.8)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(shadow, "rotation_degrees", orig_rot + 5.0, 0.8)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(shadow, "rotation_degrees", orig_rot, 0.6)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shadow_tweens.append(tw)


## ---- Вибір тварин без повторів ----

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


## ---- Drag-drop callbacks ----

func _on_item_picked(_item: Node2D) -> void:
	AudioManager.play_sfx("click")
	_reset_idle_timer()


func _on_item_dropped_on_target(item: Node2D, target: Node2D) -> void:
	if not is_instance_valid(item) or not is_instance_valid(target):
		push_warning("ShadowMatch: item or target freed during drop")
		return
	_input_locked = true
	_drag.enabled = false
	## Перевірити match: ім'я тварини == ім'я силуету
	if item.name == target.name:
		_handle_correct_match(item, target)
	else:
		_handle_wrong_match(item, target)


func _on_item_dropped_on_empty(item: Node2D) -> void:
	if not is_instance_valid(item):
		push_warning("ShadowMatch: item freed during empty drop")
		return
	if _animal_origins.has(item):
		_drag.snap_back(item, _animal_origins[item])
	else:
		push_warning("ShadowMatch: no origin for item, centering")
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_drag.snap_back(item, Vector2(vp.x * 0.5, vp.y * ANIMAL_Y_CENTER))


## ---- Правильний match: завіса піднімається, тварина кланяється ----

func _handle_correct_match(item: Node2D, target: Node2D) -> void:
	_register_correct(item)
	var aname: String = str(item.name)
	_matched_names.append(aname)
	_matched_count += 1
	## Зберегти для фіналу
	_all_matched_sprites.append({"name": aname, "position": target.global_position})
	## Видалити тварину з drag (вже matched)
	if _drag.draggable_items.has(item):
		_drag.draggable_items.erase(item)
	if _drag.drop_targets.has(target):
		_drag.drop_targets.erase(target)
	## Анімація: тварина летить до силуету
	VFXManager.spawn_success_ripple(target.global_position, Color(0.4, 1.0, 0.6, 0.6))
	if SettingsManager.reduced_motion:
		item.global_position = target.global_position
		item.scale = target.scale
		item.z_index = 3
		## Зняти шейдер силуету -- показати справжню тварину
		if is_instance_valid(target):
			target.visible = false
		## Підняти завісу (instant)
		_raise_curtain_instant(aname)
		_after_correct_anim(aname)
		return
	var tw: Tween = _create_game_tween()
	## Тварина летить до позиції силуету
	tw.tween_property(item, "global_position", target.global_position, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "scale", target.scale, 0.25)
	## Squish bounce (кланяється)
	var bow_scale: Vector2 = target.scale
	tw.tween_property(item, "scale", bow_scale * Vector2(1.3, 0.7), 0.1)
	tw.tween_property(item, "scale", bow_scale * Vector2(0.85, 1.2), 0.1)
	tw.tween_property(item, "scale", bow_scale, 0.1)
	## Сховати силует -- тварина тепер видима
	tw.tween_callback(func() -> void:
		if is_instance_valid(target):
			target.visible = false
		if is_instance_valid(item):
			item.z_index = 3)
	## Golden flash (LAW 28 premium feedback)
	tw.tween_property(item, "modulate", Color(1.3, 1.15, 0.8), 0.12)
	tw.tween_property(item, "modulate", Color.WHITE, 0.25)
	VFXManager.spawn_match_sparkle(target.global_position)
	## Завіса піднімається
	tw.tween_callback(_raise_curtain.bind(aname))
	## Тварина кланяється ще раз
	tw.tween_interval(0.15)
	tw.tween_callback(func() -> void:
		if is_instance_valid(item) and not SettingsManager.reduced_motion:
			_bow_animation(item))
	tw.tween_interval(0.5)
	tw.tween_callback(_after_correct_anim.bind(aname))


func _after_correct_anim(_aname: String) -> void:
	if _game_over:
		return
	## Перевірити чи раунд завершено
	if _matched_count >= _round_target_count:
		_record_round_errors(_round_errors_count)
		_current_round += 1
		if _current_round >= MAX_ROUNDS:
			_finish_game_sequence()
		else:
			## Затримка перед наступним раундом
			var tw: Tween = _create_game_tween()
			tw.tween_interval(ROUND_DELAY)
			tw.tween_callback(func() -> void:
				if _game_over:
					return
				_generate_round())
	else:
		## Ще є тварини для match -- unlock input
		_input_locked = false
		_drag.enabled = true
		_reset_idle_timer()


## ---- Неправильний match: тінь хитає "пальцем" ----

func _handle_wrong_match(item: Node2D, target: Node2D) -> void:
	_round_errors_count += 1
	if _is_toddler:
		## Toddler: м'яке повернення (A6)
		_register_error(item)
	else:
		_errors += 1
		_register_error(item)
	## Snap back тварину
	if _animal_origins.has(item):
		_drag.snap_back(item, _animal_origins[item])
	else:
		push_warning("ShadowMatch: no origin for wrong item")
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_drag.snap_back(item, Vector2(vp.x * 0.5, vp.y * ANIMAL_Y_CENTER))
	## Wag animation на силуеті (тінь хитає пальцем)
	if SettingsManager.reduced_motion:
		_input_locked = false
		_drag.enabled = true
		_reset_idle_timer()
		return
	if not is_instance_valid(target):
		_input_locked = false
		_drag.enabled = true
		_reset_idle_timer()
		return
	var orig_rot: float = target.rotation_degrees
	var tw: Tween = _create_game_tween()
	tw.tween_property(target, "rotation_degrees", orig_rot - 10.0, 0.1)
	tw.tween_property(target, "rotation_degrees", orig_rot + 10.0, 0.1)
	tw.tween_property(target, "rotation_degrees", orig_rot - 6.0, 0.08)
	tw.tween_property(target, "rotation_degrees", orig_rot + 6.0, 0.08)
	tw.tween_property(target, "rotation_degrees", orig_rot, 0.06)
	tw.finished.connect(func() -> void:
		if _game_over:
			return
		_input_locked = false
		_drag.enabled = true
		_reset_idle_timer())


## ---- Завіса анімація ----

func _raise_curtain(aname: String) -> void:
	if not _curtain_nodes.has(aname):
		return
	var curtain: ColorRect = _curtain_nodes[aname]
	if not is_instance_valid(curtain):
		return
	var target_y: float = curtain.position.y - curtain.size.y - 20.0
	var tw: Tween = _create_game_tween()
	tw.tween_property(curtain, "position:y", target_y, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(curtain, "modulate:a", 0.0, 0.3)
	AudioManager.play_sfx("success", 1.1)


func _raise_curtain_instant(aname: String) -> void:
	if not _curtain_nodes.has(aname):
		return
	var curtain: ColorRect = _curtain_nodes[aname]
	if not is_instance_valid(curtain):
		return
	curtain.modulate.a = 0.0


## ---- Анімація уклону ----

func _bow_animation(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	var orig_scale: Vector2 = node.scale
	var tw: Tween = _create_game_tween()
	## Нахил вперед (squash Y)
	tw.tween_property(node, "scale", Vector2(orig_scale.x * 1.1, orig_scale.y * 0.75), 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	## Повернення
	tw.tween_property(node, "scale", orig_scale, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## ---- Фінал гри ----

func _finish_game_sequence() -> void:
	_game_over = true
	_input_locked = true
	_drag.enabled = false
	_kill_shadow_tweens()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Фінальна святкова послідовність
	if _errors == 0 and not SettingsManager.reduced_motion:
		## 0 помилок: преміум святкування з конфеті
		VFXManager.spawn_premium_confetti_rain(vp)
		VFXManager.spawn_rainbow_ring(vp * 0.5)
	VFXManager.spawn_premium_celebration(vp * 0.5)
	## R5 фінал: танець всіх matched тварин
	if not SettingsManager.reduced_motion:
		_finale_dance()
	## Рахуємо зірки та завершуємо
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	var stats: Dictionary = {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": _current_round,
		"earned_stars": earned,
	}
	## Затримка для фінальної анімації
	var tw: Tween = _create_game_tween()
	tw.tween_interval(CELEBRATION_DELAY)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		finish_game(earned, stats))


## ---- Фінальний танець (всі matched тварини синхронно) ----

func _finale_dance() -> void:
	## Зібрати всі видимі matched тварини з поточного раунду
	var dancers: Array[Node2D] = []
	for key: String in _animal_nodes:
		if _animal_nodes.has(key):
			var node: Node2D = _animal_nodes[key]
			if is_instance_valid(node) and node.visible:
				dancers.append(node)
	## Додати тварини з попередніх раундів що ще на сцені
	for child: Node in get_children():
		if child is Sprite2D and not (child as Sprite2D).name.begins_with("@") \
				and child.visible and child.z_index == 3 \
				and not dancers.has(child):
			dancers.append(child as Node2D)
	if dancers.is_empty():
		return
	## Синхронний танець: всі підстрибують та хитаються
	for i: int in dancers.size():
		var dancer: Node2D = dancers[i]
		if not is_instance_valid(dancer):
			continue
		var orig_pos: Vector2 = dancer.position
		var orig_scale: Vector2 = dancer.scale
		var delay: float = float(i) * 0.1
		var tw: Tween = _create_game_tween()
		## Підстрибнути вгору
		tw.tween_property(dancer, "position:y", orig_pos.y - 20.0, 0.25)\
			.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(dancer, "position:y", orig_pos.y, 0.25)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		## Хитання
		tw.tween_property(dancer, "rotation_degrees", -8.0, 0.15)
		tw.tween_property(dancer, "rotation_degrees", 8.0, 0.15)
		tw.tween_property(dancer, "rotation_degrees", 0.0, 0.1)
		## Squish
		tw.tween_property(dancer, "scale", orig_scale * Vector2(1.2, 0.8), 0.1)
		tw.tween_property(dancer, "scale", orig_scale, 0.15)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		## Sparkle на кожному танцюристі
		tw.tween_callback(func() -> void:
			if is_instance_valid(dancer):
				VFXManager.spawn_correct_sparkle(dancer.global_position))


## ---- Очищення раунду (A9) ----

func _cleanup_round() -> void:
	_kill_shadow_tweens()
	## Очистити shadow nodes
	for key: String in _shadow_nodes.keys():
		var node: Node2D = _shadow_nodes.get(key, null)
		_shadow_nodes.erase(key)
		if node and is_instance_valid(node):
			node.queue_free()
	_shadow_nodes.clear()
	## Очистити animal nodes
	for key: String in _animal_nodes.keys():
		var node: Node2D = _animal_nodes.get(key, null)
		## Видалити з origins ПЕРЕД queue_free (LAW 9)
		if node and _animal_origins.has(node):
			_animal_origins.erase(node)
		_animal_nodes.erase(key)
		if node and is_instance_valid(node):
			node.queue_free()
	_animal_nodes.clear()
	_animal_origins.clear()
	## Очистити curtain nodes
	for key: String in _curtain_nodes.keys():
		var node: ColorRect = _curtain_nodes.get(key, null)
		_curtain_nodes.erase(key)
		if node and is_instance_valid(node):
			node.queue_free()
	_curtain_nodes.clear()
	## Скинути стан раунду
	_matched_names.clear()
	_matched_count = 0
	_round_target_count = 0
	_round_pairs.clear()
	_round_errors_count = 0
	## Очистити drag
	_drag.clear_drag()
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()


func _kill_shadow_tweens() -> void:
	for tw: Tween in _shadow_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_shadow_tweens.clear()


## ---- Idle hint (A10) ----

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
	## Знайти першу не-matched тварину
	var hint_animal: Node2D = _find_first_unmatched_animal()
	if not is_instance_valid(hint_animal):
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		## A10 рівень 2: tutorial hand -- показати правильну відповідь
		var hint_name: String = str(hint_animal.name)
		if _shadow_nodes.has(hint_name):
			var shadow: Node2D = _shadow_nodes[hint_name]
			if is_instance_valid(shadow):
				_pulse_node(shadow, 1.3)
		_pulse_node(hint_animal, 1.3)
		_reset_idle_timer()
		return
	## Рівень 0-1: пульсація тварин
	_pulse_node(hint_animal, 1.15)
	_reset_idle_timer()


func _find_first_unmatched_animal() -> Node2D:
	for key: String in _animal_nodes:
		if not _matched_names.has(key) and _animal_nodes.has(key):
			var node: Node2D = _animal_nodes[key]
			if is_instance_valid(node) and node.visible:
				return node
	return null


## ---- Tutorial ----

func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("SHADOW_TUTORIAL_TODDLER")
	return tr("SHADOW_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	## Знайти першу не-matched тварину та її shadow
	var animal: Node2D = _find_first_unmatched_animal()
	if not is_instance_valid(animal):
		return {}
	var aname: String = str(animal.name)
	if _shadow_nodes.has(aname):
		var shadow: Node2D = _shadow_nodes[aname]
		if is_instance_valid(shadow):
			return {"type": "drag", "from": animal.global_position, "to": shadow.global_position}
	return {}
