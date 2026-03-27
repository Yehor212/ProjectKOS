extends BaseMiniGame

## ECE-01 "Семейне фото" — розсортуй сім'ю (тато/мама/малюк) за розміром на стільці для фото!
## Toddler: 2 розміри (великий + малий). Preschool: 3 (великий + середній + малий).
## Наратив: кожен раунд — нова тваринна сім'я сідає на стільці для групового фото.
## Після правильного розміщення — камера "клацає", спалах, фото у рамці.
## Фінал: галерея фоток на стіні перед підрахунком зірок.

const TOTAL_ROUNDS: int = 4
const DEAL_STAGGER: float = 0.1
const DEAL_DURATION: float = 0.35
const IDLE_HINT_DELAY: float = 5.0
const SAFETY_TIMEOUT_SEC: float = 120.0

## Кольори стільця — теплі дерев'яні тони (LAW 25: розрізняємо за РОЗМІРОМ, не кольором)
const CHAIR_COLOR: Color = Color("d4a574")
const CHAIR_BACK_COLOR: Color = Color("c49464")
const CHAIR_BORDER: Color = Color("a07044")
const CHAIR_CORNER: int = 14

## Кольори рамки фото
const FRAME_COLOR: Color = Color("f0e6d4")
const FRAME_BORDER_COLOR: Color = Color("c4a888")

## Flash камери
const FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 0.7)
const FLASH_DURATION: float = 0.15

## Розміри стільців та фонів айтемів
const SIZES_ALL: Array[String] = ["big", "medium", "small"]
const SIZES_TWO: Array[String] = ["big", "small"]

## Прогресивна складність (A4 FIX): кожен раунд — окрема конфігурація
## size_count: скільки розмірів, scales: масштаби спрайтів
## R0: 2 розміри, ratio 3.2x (очевидно). R3: 3 розміри, ratio 1.5x (складно)
const ROUND_CONFIG: Array[Dictionary] = [
	{
		"size_count": 2,
		"scales": {"big": Vector2(0.48, 0.48), "small": Vector2(0.15, 0.15)},
	},
	{
		"size_count": 2,
		"scales": {"big": Vector2(0.42, 0.42), "small": Vector2(0.18, 0.18)},
	},
	{
		"size_count": 3,
		"scales": {"big": Vector2(0.38, 0.38), "medium": Vector2(0.27, 0.27), "small": Vector2(0.20, 0.20)},
	},
	{
		"size_count": 3,
		"scales": {"big": Vector2(0.34, 0.34), "medium": Vector2(0.27, 0.27), "small": Vector2(0.23, 0.23)},
	},
]

## Toddler: простіший ramp — 3 розміри лише на R4 (A3: age fork)
const ROUND_CONFIG_TODDLER: Array[Dictionary] = [
	{
		"size_count": 2,
		"scales": {"big": Vector2(0.48, 0.48), "small": Vector2(0.15, 0.15)},
	},
	{
		"size_count": 2,
		"scales": {"big": Vector2(0.42, 0.42), "small": Vector2(0.18, 0.18)},
	},
	{
		"size_count": 2,
		"scales": {"big": Vector2(0.38, 0.38), "small": Vector2(0.20, 0.20)},
	},
	{
		"size_count": 3,
		"scales": {"big": Vector2(0.34, 0.34), "medium": Vector2(0.27, 0.27), "small": Vector2(0.23, 0.23)},
	},
]

## Розміри стільців (сидіння + спинка)
const CHAIR_SEAT_SIZES: Dictionary = {
	"big": Vector2(150, 60),
	"medium": Vector2(110, 45),
	"small": Vector2(80, 35),
}
const CHAIR_BACK_SIZES: Dictionary = {
	"big": Vector2(130, 70),
	"medium": Vector2(95, 55),
	"small": Vector2(65, 40),
}

## Розміри фону для draggable айтемів
const ITEM_BG_SIZES: Dictionary = {
	"big": 130.0,
	"medium": 95.0,
	"small": 70.0,
}

## Мініатюра фото для галереї
const GALLERY_THUMB_SIZE: Vector2 = Vector2(120, 90)
const GALLERY_FRAME_BORDER: int = 4

## Набори тварин — 19 наявних спрайтів
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
var _chairs: Array[Node2D] = []
var _all_round_nodes: Array[Node] = []
var _item_size: Dictionary = {}
var _chair_size: Dictionary = {}
var _item_origins: Dictionary = {}
var _used_animals: Array[int] = []

var _idle_timer: SceneTreeTimer = null
var _narrative_label: Label = null

## Збережені дані для фото-галереї (animal_name + розміри)
var _gallery_photos: Array[Dictionary] = []
var _current_round_animal: String = ""


func _ready() -> void:
	game_id = "size_sort"
	_skill_id = "seriation"
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
	_build_narrative_label(tr("FAMILY_PHOTO_NARRATIVE"))
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


## Наратив — "Розсади сім'ю для фото!" лейбл зверху
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
	if _items.is_empty() or _chairs.is_empty():
		return {}
	var item: Node2D = _items[0]
	var sid: String = _item_size.get(item, "")
	if sid.is_empty():
		push_warning("SizeSort: tutorial demo — item has no size id")
		return {}
	for chair: Node2D in _chairs:
		if _chair_size.get(chair, "") == sid:
			return {"type": "drag", "from": item.global_position, "to": chair.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Утиліта: конфіг раунду з bounds check (LAW 13) ----

func _get_round_config(round_idx: int) -> Dictionary:
	var cfg_array: Array[Dictionary] = ROUND_CONFIG_TODDLER if _is_toddler else ROUND_CONFIG
	var safe_idx: int = clampi(round_idx, 0, cfg_array.size() - 1)
	return cfg_array[safe_idx]


func _get_round_sizes(round_idx: int) -> Array[String]:
	var cfg: Dictionary = _get_round_config(round_idx)
	var count: int = int(cfg.get("size_count", 2))
	if count >= 3:
		return SIZES_ALL.duplicate()
	return SIZES_TWO.duplicate()


## ---- Раунди ----

func _start_round() -> void:
	_matched = 0
	_input_locked = true
	var sizes: Array[String] = _get_round_sizes(_round)
	_total = sizes.size()
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	var animal_name: String = _pick_animal()
	_current_round_animal = animal_name
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_spawn_chairs(sizes)
	if not _spawn_items(animal_name, sizes):
		push_warning("SizeSort: item spawn failed, skipping round")
		_total = 0
		_on_round_complete()


func _pick_animal() -> String:
	if _used_animals.size() >= ANIMAL_SETS.size():
		_used_animals.clear()
	var idx: int = randi() % maxi(ANIMAL_SETS.size(), 1)
	var attempts: int = 0
	while _used_animals.has(idx) and attempts < ANIMAL_SETS.size():
		idx = randi() % maxi(ANIMAL_SETS.size(), 1)
		attempts += 1
	_used_animals.append(idx)
	if idx >= 0 and idx < ANIMAL_SETS.size() and ANIMAL_SETS[idx].size() > 0:
		return ANIMAL_SETS[idx][0]
	push_warning("SizeSort: animal pick fallback to Penguin")
	return "Penguin"


## ---- Стільці (drop targets) ----

func _spawn_chairs(sizes: Array[String]) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var count: int = sizes.size()
	if count == 0:
		push_warning("SizeSort: zero sizes for chairs")
		return
	var spacing: float = vp.x / float(count + 1)
	var chair_y: float = vp.y * 0.38
	## Стільці завжди за порядком: big -> medium -> small (зліва направо)
	for i: int in count:
		var sid: String = sizes[i]
		var seat_sz: Vector2 = CHAIR_SEAT_SIZES.get(sid, Vector2(110, 45))
		var back_sz: Vector2 = CHAIR_BACK_SIZES.get(sid, Vector2(95, 55))
		var chair: Node2D = Node2D.new()
		chair.position = Vector2(spacing * float(i + 1), chair_y)
		add_child(chair)
		## Спинка стільця (верхня частина)
		var back_panel: Panel = Panel.new()
		back_panel.size = back_sz
		back_panel.position = Vector2(-back_sz.x * 0.5, -back_sz.y - seat_sz.y * 0.3)
		var back_style: StyleBoxFlat = GameData.candy_cell(CHAIR_BACK_COLOR, CHAIR_CORNER, true)
		back_style.border_color = CHAIR_BORDER
		back_style.set_border_width_all(2)
		back_panel.add_theme_stylebox_override("panel", back_style)
		chair.add_child(back_panel)
		## Сидіння стільця (нижня частина)
		var seat_panel: Panel = Panel.new()
		seat_panel.size = seat_sz
		seat_panel.position = Vector2(-seat_sz.x * 0.5, -seat_sz.y * 0.5)
		var seat_style: StyleBoxFlat = GameData.candy_cell(CHAIR_COLOR, CHAIR_CORNER, true)
		seat_style.border_color = CHAIR_BORDER
		seat_style.set_border_width_all(2)
		seat_panel.add_theme_stylebox_override("panel", seat_style)
		## Grain overlay (LAW 28)
		seat_panel.material = GameData.create_premium_material(
			0.04, 2.0, 0.04, 0.0, 0.04, 0.03, 0.05, "", 0.0, 0.10, 0.22, 0.18)
		chair.add_child(seat_panel)
		## Підпис розміру під стільцем (LAW 25: текст + розмір для accessibility)
		var lbl: Label = Label.new()
		lbl.text = tr("SIZE_%s" % sid.to_upper())
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		lbl.position = Vector2(-seat_sz.x * 0.5, seat_sz.y * 0.5 + 8)
		lbl.size = Vector2(seat_sz.x, 30)
		chair.add_child(lbl)
		chair.set_meta("is_filled", false)
		_chairs.append(chair)
		_chair_size[chair] = sid
		_drag.drop_targets.append(chair)
		_all_round_nodes.append(chair)


## ---- Draggable тварини ----

func _spawn_items(animal_name: String, sizes: Array[String]) -> bool:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if not ResourceLoader.exists(tex_path):
		push_warning("SizeSort: missing sprite: " + tex_path)
		return false
	var tex: Texture2D = load(tex_path)
	if not tex:
		push_warning("SizeSort: texture load failed: " + tex_path)
		return false
	var count: int = sizes.size()
	if count == 0:
		push_warning("SizeSort: zero sizes for items")
		return false
	## Перемішуємо позиції щоб не збігалися з порядком стільців
	var indices: Array[int] = []
	for i: int in count:
		indices.append(i)
	indices.shuffle()
	var spacing: float = vp.x / float(count + 1)
	var item_y: float = vp.y * 0.78
	var cfg: Dictionary = _get_round_config(_round)
	var round_scales: Dictionary = cfg.get("scales", {})
	for i: int in count:
		var sid: String = sizes[indices[i]]
		var bg_sz: float = ITEM_BG_SIZES.get(sid, 95.0)
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
		sprite.scale = round_scales.get(sid, Vector2(0.27, 0.27))
		item.add_child(sprite)
		var target: Vector2 = Vector2(spacing * float(i + 1), item_y)
		_item_size[item] = sid
		_item_origins[item] = target
		_items.append(item)
		_drag.draggable_items.append(item)
		_all_round_nodes.append(item)
		## Deal-in анімація
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
			var tw: Tween = _create_game_tween().set_parallel(true)
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
	var cs_id: String = _chair_size.get(target, "")
	if is_id == cs_id and not target.get_meta("is_filled", false):
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
	## Магнітний snap до стільця
	var tw: Tween = _create_game_tween()
	tw.tween_property(item, "global_position", target.global_position, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "rotation", 0.0, 0.15)
	if _matched >= _total:
		tw.chain().tween_callback(_on_round_complete)
	else:
		_reset_idle_timer()


func _handle_wrong(item: Node2D) -> void:
	if _is_toddler:
		_register_error(item)  ## A6/A11: toddler — gentle wobble, scaffolding after 2
	else:
		_errors += 1
		_register_error(item)  ## A7/A11: preschool — error count + scaffolding after 3
	_drag.snap_back(item, _item_origins.get(item, item.position))


## ---- Камера: спалах та "клац" ----

func _play_camera_flash() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var flash: ColorRect = ColorRect.new()
	flash.color = FLASH_COLOR
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(flash)
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	if SettingsManager.reduced_motion:
		flash.queue_free()
		VFXManager.spawn_premium_celebration(vp * 0.5)
		return
	var tw: Tween = _create_game_tween()
	tw.tween_property(flash, "color:a", 0.0, FLASH_DURATION * 2.0)
	tw.tween_callback(flash.queue_free)
	VFXManager.spawn_premium_celebration(vp * 0.5)


## ---- Збереження "фото" для галереї (збираємо дані, не ноди) ----

func _save_round_photo(animal_name: String, sizes: Array[String]) -> void:
	_gallery_photos.append({
		"animal": animal_name,
		"sizes": sizes.duplicate(),
		"round": _round,
	})


## ---- Round management ----

func _on_round_complete() -> void:
	_input_locked = true
	_drag.enabled = false
	## Зберегти фото-дані для галереї ДО очищення нодів
	var current_animal: String = _get_current_animal_name()
	var current_sizes: Array[String] = _get_round_sizes(_round)
	_save_round_photo(current_animal, current_sizes)
	## Камера "клацає" — flash ефект
	_play_camera_flash()
	## "Клац!" лейбл
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if not SettingsManager.reduced_motion:
		var click_label: Label = Label.new()
		click_label.text = tr("FAMILY_PHOTO_CLICK")
		click_label.add_theme_font_size_override("font_size", 48)
		click_label.add_theme_color_override("font_color", Color(1, 0.95, 0.5, 1.0))
		click_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		click_label.position = Vector2(vp.x * 0.3, vp.y * 0.15)
		click_label.size = Vector2(vp.x * 0.4, 60)
		click_label.scale = Vector2.ZERO
		add_child(click_label)
		var label_tw: Tween = _create_game_tween()
		label_tw.tween_property(click_label, "scale", Vector2(1.2, 1.2), 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		label_tw.tween_property(click_label, "scale", Vector2.ONE, 0.15)
		label_tw.tween_interval(0.6)
		label_tw.tween_property(click_label, "modulate:a", 0.0, 0.3)
		label_tw.tween_callback(click_label.queue_free)
	## Перехід до наступного раунду після паузи
	if SettingsManager.reduced_motion:
		var rm_tw: Tween = _create_game_tween()
		rm_tw.tween_interval(0.3)
		rm_tw.tween_callback(func() -> void:
			_clear_round()
			_round += 1
			if _round >= TOTAL_ROUNDS:
				_show_gallery()
			else:
				_start_round())
		return
	## Фото "їде" вгору (елементи зменшуються і зникають)
	var shrink_tw: Tween = _create_game_tween()
	shrink_tw.tween_interval(0.5)
	for node: Node in _all_round_nodes:
		if is_instance_valid(node) and node is Node2D:
			shrink_tw.parallel().tween_property(node, "scale",
				Vector2(0.3, 0.3), 0.6)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			shrink_tw.parallel().tween_property(node, "modulate:a",
				0.0, 0.5).set_delay(0.1)
	shrink_tw.tween_interval(0.3)
	shrink_tw.tween_callback(func() -> void:
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_show_gallery()
		else:
			_start_round())


func _get_current_animal_name() -> String:
	return _current_round_animal


func _clear_round() -> void:
	## LAW 9/A9: erase dict entries BEFORE queue_free (LAW 17 safe)
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			_item_size.erase(node)
			_chair_size.erase(node)
			_item_origins.erase(node)
			node.queue_free()
	_all_round_nodes.clear()
	_items.clear()
	_chairs.clear()
	_item_size.clear()
	_chair_size.clear()
	_item_origins.clear()
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	_drag.clear_drag()


## ---- Галерея фоток (фінальна анімація) ----

func _show_gallery() -> void:
	_input_locked = true
	if _gallery_photos.is_empty():
		push_warning("SizeSort: no gallery photos to show")
		_finish()
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	## Наратив: "Фото галерея!"
	if is_instance_valid(_narrative_label):
		_narrative_label.text = tr("FAMILY_PHOTO_GALLERY")
	## Створити рамки фоток по центру
	var photo_count: int = _gallery_photos.size()
	var total_width: float = float(photo_count) * (GALLERY_THUMB_SIZE.x + 20.0) - 20.0
	var start_x: float = (vp.x - total_width) * 0.5
	var gallery_y: float = vp.y * 0.45
	var gallery_nodes: Array[Node2D] = []
	for i: int in photo_count:
		var photo_data: Dictionary = _gallery_photos[i]
		var frame: Node2D = _build_gallery_frame(photo_data, i)
		frame.position = Vector2(
			start_x + float(i) * (GALLERY_THUMB_SIZE.x + 20.0) + GALLERY_THUMB_SIZE.x * 0.5,
			gallery_y)
		## Каскадна поява
		if not SettingsManager.reduced_motion:
			frame.scale = Vector2.ZERO
			frame.modulate.a = 0.0
			var delay: float = float(i) * 0.2
			var ftw: Tween = _create_game_tween()
			ftw.tween_property(frame, "scale", Vector2(1.1, 1.1), 0.3)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ftw.parallel().tween_property(frame, "modulate:a", 1.0, 0.2).set_delay(delay)
			ftw.tween_property(frame, "scale", Vector2.ONE, 0.15)
		add_child(frame)
		gallery_nodes.append(frame)
	## Затримка перед фінішем
	var finish_delay: float = 0.3 + float(photo_count) * 0.2 + 1.5
	var finish_tw: Tween = _create_game_tween()
	finish_tw.tween_interval(finish_delay)
	finish_tw.tween_callback(func() -> void:
		## Очистити галерею
		for gnode: Node2D in gallery_nodes:
			if is_instance_valid(gnode):
				gnode.queue_free()
		_finish())


func _build_gallery_frame(photo_data: Dictionary, index: int) -> Node2D:
	var frame_node: Node2D = Node2D.new()
	## Рамка (Panel з бордером)
	var frame_panel: Panel = Panel.new()
	var total_sz: Vector2 = GALLERY_THUMB_SIZE + Vector2(
		float(GALLERY_FRAME_BORDER * 2), float(GALLERY_FRAME_BORDER * 2))
	frame_panel.size = total_sz
	frame_panel.position = Vector2(-total_sz.x * 0.5, -total_sz.y * 0.5)
	var frame_style: StyleBoxFlat = GameData.candy_cell(FRAME_COLOR, 8, true)
	frame_style.border_color = FRAME_BORDER_COLOR
	frame_style.set_border_width_all(GALLERY_FRAME_BORDER)
	frame_panel.add_theme_stylebox_override("panel", frame_style)
	frame_panel.material = GameData.create_premium_material(
		0.03, 2.0, 0.04, 0.0, 0.03, 0.02, 0.04, "", 0.0, 0.08, 0.18, 0.15)
	frame_node.add_child(frame_panel)
	## Мініатюрний спрайт тварини у рамці
	var animal_name: String = str(photo_data.get("animal", "Penguin"))
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path)
		if tex:
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = tex
			## Масштабуємо щоб вписатися в рамку
			var tex_size: Vector2 = tex.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				var fit_scale: float = minf(
					GALLERY_THUMB_SIZE.x * 0.6 / tex_size.x,
					GALLERY_THUMB_SIZE.y * 0.6 / tex_size.y)
				sprite.scale = Vector2(fit_scale, fit_scale)
			frame_node.add_child(sprite)
	## Номер фото знизу
	var num_label: Label = Label.new()
	num_label.text = str(index + 1)
	num_label.add_theme_font_size_override("font_size", 16)
	num_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4, 0.8))
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.position = Vector2(-total_sz.x * 0.5, total_sz.y * 0.5 + 2)
	num_label.size = Vector2(total_sz.x, 24)
	frame_node.add_child(num_label)
	return frame_node


## ---- Фініш ----

func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": TOTAL_ROUNDS, "earned_stars": earned})


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
