extends BaseMiniGame

## ECE-01 Просторова сортировка — розсортуй тварин за розміром!
## Toddler: 2 розміри (великий + малий). Preschool: 3 (великий + середній + малий).

const TOTAL_ROUNDS: int = 4
const DEAL_STAGGER: float = 0.1
const DEAL_DURATION: float = 0.35
const IDLE_HINT_DELAY: float = 5.0
const PLATFORM_COLOR: Color = Color("b3e5fc")
const PLATFORM_BORDER: Color = Color("4fc3f7")
const PLATFORM_CORNER: int = 20
const SAFETY_TIMEOUT_SEC: float = 120.0

## Масштаби спрайтів та платформ під кожен розмір
const SIZES_ALL: Array[String] = ["big", "medium", "small"]
const SIZES_TODDLER: Array[String] = ["big", "small"]
## Прогресивні масштаби — різниця між розмірами ЗМЕНШУЄТЬСЯ з кожним раундом (A4)
## R0: дуже очевидна різниця, R3: ледь помітна (research: stair-step difficulty, ZPD)
const ROUND_SPRITE_SCALES: Array[Dictionary] = [
	{"big": Vector2(0.48, 0.48), "medium": Vector2(0.30, 0.30), "small": Vector2(0.15, 0.15)},  ## R0: ratio ×3.2
	{"big": Vector2(0.42, 0.42), "medium": Vector2(0.28, 0.28), "small": Vector2(0.18, 0.18)},  ## R1: ratio ×2.3
	{"big": Vector2(0.38, 0.38), "medium": Vector2(0.27, 0.27), "small": Vector2(0.20, 0.20)},  ## R2: ratio ×1.9
	{"big": Vector2(0.34, 0.34), "medium": Vector2(0.27, 0.27), "small": Vector2(0.23, 0.23)},  ## R3: ratio ×1.5
]
const PLATFORM_SIZES: Dictionary = {
	"big": Vector2(160, 120),
	"medium": Vector2(120, 90),
	"small": Vector2(85, 65),
}
const ITEM_BG_SIZES: Dictionary = {
	"big": 130.0,
	"medium": 95.0,
	"small": 70.0,
}

## Набори тварин — використовуємо наявні спрайти
const ANIMAL_SETS: Array[Array] = [
	["Penguin"], ["Bear"], ["Cat"], ["Dog"], ["Bunny"],
	["Lion"], ["Elephant"], ["Monkey"], ["Frog"], ["Mouse"],
	["Horse"], ["Cow"], ["Goat"], ["Chicken"], ["Hedgehog"],
	["Deer"], ["Crocodile"], ["Panda"], ["Squirrel"],
]

var _is_toddler: bool = false
var _drag: UniversalDrag = null
var _round: int = 0
var _matched: int = 0
var _total: int = 0
var _start_time: float = 0.0

var _items: Array[Node2D] = []
var _platforms: Array[Node2D] = []
var _all_round_nodes: Array[Node] = []
var _item_size: Dictionary = {}
var _platform_size: Dictionary = {}
var _item_origins: Dictionary = {}
var _used_animals: Array[int] = []

var _idle_timer: SceneTreeTimer = null
var _narrative_label: Label = null


func _ready() -> void:
	game_id = "size_sort"
	bg_theme = "candy"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_drag = UniversalDrag.new(self)
	if _is_toddler:
		_drag.snap_radius_override = TODDLER_SNAP_RADIUS
	_drag.item_picked_up.connect(_on_picked)
	_drag.item_dropped_on_target.connect(_on_dropped_target)
	_drag.item_dropped_on_empty.connect(_on_dropped_empty)
	_build_hud()
	_build_narrative_label(tr("TRAIN_SEATS"))
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


## Наратив — "Посади тварин у паровозик!" лейбл
func _build_narrative_label(text: String) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_narrative_label = Label.new()
	_narrative_label.text = text
	_narrative_label.add_theme_font_size_override("font_size", 28)
	_narrative_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_narrative_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narrative_label.position = Vector2(0, vp.y * 0.12)
	_narrative_label.size = Vector2(vp.x, 40)
	_ui_layer.add_child(_narrative_label)


func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("SIZE_SORT_TUTORIAL_TODDLER")
	return tr("SIZE_SORT_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	if _items.is_empty() or _platforms.is_empty():
		return {}
	var item: Node2D = _items[0]
	var sid: String = _item_size.get(item, "")
	for platform: Node2D in _platforms:
		if _platform_size.get(platform, "") == sid:
			return {"type": "drag", "from": item.global_position, "to": platform.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	_matched = 0
	_input_locked = true
	## Прогресивна складність (A4)
	var sizes: Array[String]
	if _is_toddler:
		## T: раунди 0-1 = 2 розміри (великий+малий), раунди 2-3 = 3 розміри
		@warning_ignore("integer_division")
		if _round < TOTAL_ROUNDS / 2:
			sizes = SIZES_TODDLER
		else:
			sizes = SIZES_ALL
	else:
		var size_count: int = _scale_by_round_i(2, SIZES_ALL.size(), _round, TOTAL_ROUNDS)
		sizes = SIZES_ALL.slice(0, size_count)
	_total = sizes.size()
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	var animal_name: String = _pick_animal()
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_spawn_platforms(sizes)
	if not _spawn_items(animal_name, sizes):
		push_warning("SizeSort: не вдалося створити предмети, пропускаємо раунд")
		_total = 0
		_on_round_complete()


func _pick_animal() -> String:
	if _used_animals.size() >= ANIMAL_SETS.size():
		_used_animals.clear()
	var idx: int = randi() % ANIMAL_SETS.size()
	while _used_animals.has(idx):
		idx = randi() % ANIMAL_SETS.size()
	_used_animals.append(idx)
	return ANIMAL_SETS[idx][0]


func _spawn_platforms(sizes: Array[String]) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = sizes.size()
	var spacing: float = vp.x / float(count + 1)
	var platform_y: float = vp.y * 0.35
	## Платформи завжди за порядком: big → small (зліва направо)
	for i: int in count:
		var sid: String = sizes[i]
		var psize: Vector2 = PLATFORM_SIZES[sid]
		var platform: Node2D = Node2D.new()
		platform.position = Vector2(spacing * float(i + 1), platform_y)
		add_child(platform)
		## Овальний фон платформи
		var panel: Panel = Panel.new()
		panel.size = psize
		panel.position = Vector2(-psize.x * 0.5, -psize.y * 0.5)
		var style: StyleBoxFlat = GameData.candy_cell(PLATFORM_COLOR, PLATFORM_CORNER, true)
		style.border_color = PLATFORM_BORDER
		style.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", style)
		## Grain overlay (LAW 28)
		panel.material = GameData.create_premium_material(0.04, 2.0, 0.04, 0.0, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
		platform.add_child(panel)
		## Підпис розміру під платформою
		var lbl: Label = Label.new()
		lbl.text = tr("SIZE_%s" % sid.to_upper())
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		lbl.position = Vector2(-psize.x * 0.5, psize.y * 0.5 + 8)
		lbl.size = Vector2(psize.x, 30)
		platform.add_child(lbl)
		platform.set_meta("is_filled", false)
		_platforms.append(platform)
		_platform_size[platform] = sid
		_drag.drop_targets.append(platform)
		_all_round_nodes.append(platform)


func _spawn_items(animal_name: String, sizes: Array[String]) -> bool:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if not ResourceLoader.exists(tex_path):
		push_warning("SizeSort: Missing sprite: " + tex_path)
		return false
	var tex: Texture2D = load(tex_path)
	if not tex:
		push_warning("SizeSort: текстуру '%s' не знайдено" % tex_path)
		return false
	var count: int = sizes.size()
	## Перемішуємо позиції щоб не збігалися з платформами
	var indices: Array[int] = []
	for i: int in count:
		indices.append(i)
	indices.shuffle()
	var spacing: float = vp.x / float(count + 1)
	var item_y: float = vp.y * 0.78
	for i: int in count:
		var sid: String = sizes[indices[i]]
		var bg_sz: float = ITEM_BG_SIZES[sid]
		var item: Node2D = Node2D.new()
		add_child(item)
		## Кругле біле тло
		var bg: Panel = Panel.new()
		bg.size = Vector2(bg_sz, bg_sz)
		bg.position = Vector2(-bg_sz * 0.5, -bg_sz * 0.5)
		var style: StyleBoxFlat = GameData.candy_circle(Color.WHITE, bg_sz * 0.5)
		bg.add_theme_stylebox_override("panel", style)
		item.add_child(bg)
		## Спрайт тварини
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = tex
		var round_scales: Dictionary = ROUND_SPRITE_SCALES[clampi(_round, 0, ROUND_SPRITE_SCALES.size() - 1)]
		sprite.scale = round_scales.get(sid, Vector2(0.27, 0.27))
		item.add_child(sprite)
		var target: Vector2 = Vector2(spacing * float(i + 1), item_y)
		_item_size[item] = sid
		_item_origins[item] = target
		_items.append(item)
		_drag.draggable_items.append(item)
		_all_round_nodes.append(item)
		## Deal анімація
		if SettingsManager.reduced_motion:
			item.position = target
			item.modulate.a = 1.0
			if i == count - 1:
				_input_locked = false
				_drag.enabled = true
				_reset_idle_timer()
		else:
			item.position = Vector2(target.x, vp.y + 100.0)
			item.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = create_tween().set_parallel(true)
			tw.tween_property(item, "position", target, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
			if i == count - 1:
				tw.chain().tween_callback(func() -> void:
					_input_locked = false
					_drag.enabled = true
					_reset_idle_timer())
	_staggered_spawn(_items, 0.08)
	return true


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


## ---- Drop ----

func _on_dropped_target(item: Node2D, target: Node2D) -> void:
	if _game_over:
		return
	var is_id: String = _item_size.get(item, "")
	var ps_id: String = _platform_size.get(target, "")
	if is_id == ps_id and not target.get_meta("is_filled", false):
		_handle_correct(item, target)
	else:
		_handle_wrong(item)


func _on_dropped_empty(item: Node2D) -> void:
	_drag.snap_back(item, _item_origins.get(item, item.position))


func _handle_correct(item: Node2D, target: Node2D) -> void:
	_register_correct(item)
	target.set_meta("is_filled", true)
	_drag.draggable_items.erase(item)
	_items.erase(item)
	_matched += 1
	if SettingsManager.reduced_motion:
		item.global_position = target.global_position
		item.rotation = 0.0
		if _matched >= _total:
			_on_round_complete()
		else:
			_reset_idle_timer()
		return
	## Магнітний snap до платформи
	var tw: Tween = create_tween()
	tw.tween_property(item, "global_position", target.global_position, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "rotation", 0.0, 0.15)
	if _matched >= _total:
		tw.chain().tween_callback(_on_round_complete)
	else:
		_reset_idle_timer()


func _handle_wrong(item: Node2D) -> void:
	if _is_toddler:
		_register_error(item)  ## A11: scaffolding для тоддлера
	else:
		_errors += 1
		_register_error(item)
	_drag.snap_back(item, _item_origins.get(item, item.position))


## ---- Round management ----

func _on_round_complete() -> void:
	_input_locked = true
	_drag.enabled = false
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	if SettingsManager.reduced_motion:
		VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)
		var tw_rm: Tween = create_tween()
		tw_rm.tween_interval(0.15)
		tw_rm.tween_callback(func() -> void:
			_clear_round()
			_round += 1
			if _round >= TOTAL_ROUNDS:
				_finish()
			else:
				_start_round())
		return
	## Train departs animation — платформи + предмети їдуть вправо
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## "TOOT!" лейбл — масштабується та зникає
	var toot: Label = Label.new()
	toot.text = tr("TRAIN_TOOT")
	toot.add_theme_font_size_override("font_size", 48)
	toot.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1.0))
	toot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toot.position = Vector2(vp.x * 0.3, vp.y * 0.15)
	toot.size = Vector2(vp.x * 0.4, 60)
	toot.scale = Vector2.ZERO
	add_child(toot)
	var toot_tw: Tween = create_tween()
	toot_tw.tween_property(toot, "scale", Vector2(1.2, 1.2), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	toot_tw.tween_property(toot, "scale", Vector2.ONE, 0.15)
	toot_tw.tween_interval(0.6)
	toot_tw.tween_property(toot, "modulate:a", 0.0, 0.3)
	toot_tw.tween_callback(toot.queue_free)
	## Все їде вправо за екран
	var depart_tw: Tween = create_tween()
	depart_tw.tween_interval(0.3)
	for node: Node in _all_round_nodes:
		if is_instance_valid(node) and node is Node2D:
			depart_tw.parallel().tween_property(node, "position:x",
				(node as Node2D).position.x + 1500.0, 2.0)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	depart_tw.tween_callback(func() -> void:
		VFXManager.spawn_premium_celebration(vp * 0.5)
	)
	depart_tw.tween_interval(0.5)
	depart_tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


func _clear_round() -> void:
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_items.clear()
	_platforms.clear()
	_item_size.clear()
	_platform_size.clear()
	_item_origins.clear()
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
	if _input_locked or _game_over or _items.is_empty():
		return
	var level: int = _advance_idle_hint()
	if level >= 2:
		_reset_idle_timer()
		return
	for item: Node2D in _items:
		if is_instance_valid(item):
			_pulse_node(item, 1.15)
			break
	_reset_idle_timer()
