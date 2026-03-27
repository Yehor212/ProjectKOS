extends BaseMiniGame

## PRE-28 "Planet Guardian" — допоможи Землі! Сортуй сміття по контейнерах.
## Toddler (2-4): 2 біни (Чисте / Брудне) — конкретні предмети, без абстракції.
## Preschool (4-7): 3-4 біни (папір / пластик / скло / органіка) з іконками.
## Earth face в центрі: sad → neutral → happy → ecstatic з кожним правильним сортуванням.
## 5 раундів, прогресивна складність (A4): більше предметів, більше бінів, швидше.

const TOTAL_ROUNDS: int = 5
const FALL_SPEED_EASY: float = 25.0
const FALL_SPEED_HARD: float = 50.0
const ITEM_SIZE: float = 90.0
const BIN_W: float = 150.0
const BIN_H: float = 130.0
const BIN_CORNER: int = 20
const PICK_RADIUS: float = 80.0
const TILT_FACTOR: float = 0.001
const TILT_MAX: float = 0.4
const TILT_LERP: float = 15.0
const SPAWN_INTERVAL: float = 1.8
const IDLE_HINT_DELAY: float = 5.0
const MAX_ACTIVE_ITEMS: int = 8
const SAFETY_TIMEOUT_SEC: float = 120.0

## Earth mood порогові значення для візуальних станів
const MOOD_SAD: float = 0.25
const MOOD_NEUTRAL: float = 0.50
const MOOD_HAPPY: float = 0.75

## --- Toddler біни: "Чисте" і "Брудне" (конкретне, не абстрактне) ---
const TODDLER_BINS: Array[Dictionary] = [
	{"id": "clean", "label": "ECO_CLEAN", "color": Color("81c784"),
	 "icon": "clean"},
	{"id": "dirty", "label": "ECO_DIRTY", "color": Color("e57373"),
	 "icon": "dirty"},
]

## Toddler предмети: конкретні речі які 2-3 річний впізнає візуально
const TODDLER_ITEMS: Array[Dictionary] = [
	{"id": "toy", "bin_id": "clean", "icon": "toy", "color": Color("64b5f6")},
	{"id": "flower", "bin_id": "clean", "icon": "flower", "color": Color("f06292")},
	{"id": "ball", "bin_id": "clean", "icon": "ball", "color": Color("ffb74d")},
	{"id": "book", "bin_id": "clean", "icon": "book", "color": Color("ba68c8")},
	{"id": "mud", "bin_id": "dirty", "icon": "mud", "color": Color("8d6e63")},
	{"id": "trash_bag", "bin_id": "dirty", "icon": "trash_bag", "color": Color("78909c")},
	{"id": "old_food", "bin_id": "dirty", "icon": "old_food", "color": Color("a1887f")},
	{"id": "broken", "bin_id": "dirty", "icon": "broken", "color": Color("90a4ae")},
]

## --- Preschool біни: класифікація за матеріалом ---
const PRESCHOOL_BINS: Array[Dictionary] = [
	{"id": "paper", "label": "ECO_PAPER", "color": Color("90caf9"),
	 "icon": "paper"},
	{"id": "plastic", "label": "ECO_PLASTIC", "color": Color("ce93d8"),
	 "icon": "plastic"},
	{"id": "glass", "label": "ECO_GLASS", "color": Color("a5d6a7"),
	 "icon": "glass"},
	{"id": "organic", "label": "ECO_ORGANIC", "color": Color("ffcc80"),
	 "icon": "organic"},
]

## Preschool предмети: по категоріях матеріалу
const PRESCHOOL_ITEMS: Array[Dictionary] = [
	{"id": "newspaper", "bin_id": "paper", "icon": "paper", "color": Color("90caf9")},
	{"id": "cardboard", "bin_id": "paper", "icon": "paper", "color": Color("64b5f6")},
	{"id": "bottle", "bin_id": "plastic", "icon": "plastic", "color": Color("ce93d8")},
	{"id": "bag", "bin_id": "plastic", "icon": "plastic", "color": Color("ab47bc")},
	{"id": "jar", "bin_id": "glass", "icon": "glass", "color": Color("a5d6a7")},
	{"id": "cup", "bin_id": "glass", "icon": "glass", "color": Color("66bb6a")},
	{"id": "apple", "bin_id": "organic", "icon": "organic", "color": Color("ffcc80")},
	{"id": "peel", "bin_id": "organic", "icon": "organic", "color": Color("ffa726")},
]

## Difficulty ramp table: [bin_count, item_count] per round per age
## Toddler: завжди 2 біни, зростає кількість предметів
const TODDLER_RAMP: Array[Vector2i] = [
	Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5),
	Vector2i(2, 5), Vector2i(2, 6),
]
## Preschool: від 3 до 4 бінів, зростає кількість предметів
const PRESCHOOL_RAMP: Array[Vector2i] = [
	Vector2i(3, 4), Vector2i(3, 5), Vector2i(4, 5),
	Vector2i(4, 6), Vector2i(4, 7),
]

## --- Стан гри ---
var _is_toddler: bool = false
var _round: int = 0
var _sorted_count: int = 0
var _current_items_count: int = 0
var _start_time: float = 0.0

## Drag стан
var _dragged: Node2D = null
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_original_z: int = 0
var _last_mouse: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO

## Ігрові ноди та колекції
var _items: Array[Node2D] = []
var _all_round_nodes: Array[Node] = []
var _item_bin_id: Dictionary = {}  ## Node2D -> bin_id (String)
var _bins: Array[Dictionary] = []  ## rect, id, panel
var _bin_panels: Array[Node] = []  ## Окремий tracking для cleanup
var _bin_labels: Array[Node] = []
var _bin_icons: Array[Node] = []
var _spawn_queue: Array[Dictionary] = []
var _spawn_timer: float = 0.0
var _spawning: bool = false
var _current_fall_speed: float = FALL_SPEED_EASY

## Кешовані текстури chip (LAW 28: preload замість load у _process chain)
var _chip_cache: Dictionary = {}

## Idle та narrative
var _idle_timer: SceneTreeTimer = null
var _earth_node: Node2D = null
var _earth_mood: float = 0.0  ## 0.0 (сумна) → 1.0 (щаслива)
var _flower_nodes: Array[Node2D] = []  ## Квіти що виростають на 100%


func _ready() -> void:
	game_id = "eco_conveyor"
	_skill_id = "classification"
	bg_theme = "meadow"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_start_time = Time.get_ticks_msec() / 1000.0
	_preload_chip_textures()
	_apply_background()
	_build_hud()
	_build_earth_face()
	_build_bins_for_round()
	_start_round()
	## A2: гра ЗАВЖДИ завершується — safety timeout (LAW 14)
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


## Preload chip текстур один раз, щоб не викликати load() з _process chain
func _preload_chip_textures() -> void:
	var chip_names: Array[String] = [
		"chipBlueWhite", "chipRedWhite", "chipGreenWhite",
		"chipWhite",
	]
	for chip_name: String in chip_names:
		var path: String = "res://assets/textures/kenney/boardgame/%s.png" % chip_name
		if ResourceLoader.exists(path):
			_chip_cache[path] = load(path)
		else:
			push_warning("EcoConveyor: chip texture not found at preload: %s" % path)


## --- Tutorial (A1) ---

func get_tutorial_instruction() -> String:
	if _is_toddler:
		return tr("ECO_TODDLER_TUTORIAL")
	return tr("ECO_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	if _items.is_empty() or _bins.is_empty():
		return {}
	var item: Node2D = _items[0]
	if not is_instance_valid(item):
		push_warning("EcoConveyor: tutorial demo item freed")
		return {}
	var bin_id: String = _item_bin_id.get(item, "")
	if bin_id.is_empty():
		push_warning("EcoConveyor: tutorial demo item has no bin_id")
		return {}
	for bin: Dictionary in _bins:
		if bin.get("id", "") == bin_id:
			var bin_rect: Rect2 = bin.get("rect", Rect2())
			return {"type": "drag", "from": item.global_position,
				"to": bin_rect.get_center()}
	return {}


## --- HUD ---

func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## --- Earth Face (центральний наративний елемент) ---

func _build_earth_face() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_earth_node = Node2D.new()
	_earth_node.position = Vector2(vp.x * 0.5, vp.y * 0.18)
	_earth_node.z_index = 1
	add_child(_earth_node)
	## Підключаємо рендер через draw callback
	var earth_visual: Control = Control.new()
	earth_visual.custom_minimum_size = Vector2(120, 120)
	earth_visual.size = Vector2(120, 120)
	earth_visual.position = Vector2(-60, -60)
	earth_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	earth_visual.draw.connect(_draw_earth.bind(earth_visual))
	_earth_node.add_child(earth_visual)


## Малюємо Землю процедурно: коло + очі + рот залежно від _earth_mood
func _draw_earth(ctrl: Control) -> void:
	var cx: float = 60.0
	var cy: float = 60.0
	var r: float = 50.0

	## Тіло Землі — блакитно-зелений
	ctrl.draw_circle(Vector2(cx, cy), r + 3.0, Color(0, 0, 0, 0.15))  ## Тінь
	ctrl.draw_circle(Vector2(cx, cy), r, Color("4fc3f7"))  ## Океан
	## Зелені "континенти"
	ctrl.draw_circle(Vector2(cx - 15, cy - 10), 18.0, Color("66bb6a"))
	ctrl.draw_circle(Vector2(cx + 20, cy + 5), 14.0, Color("81c784"))
	ctrl.draw_circle(Vector2(cx - 5, cy + 18), 12.0, Color("a5d6a7"))

	## Очі — змінюються за настроєм
	var eye_l: Vector2 = Vector2(cx - 14, cy - 8)
	var eye_r: Vector2 = Vector2(cx + 14, cy - 8)
	var eye_size: float = 6.0

	if _earth_mood < MOOD_SAD:
		## Сумні очі — опущені
		ctrl.draw_circle(eye_l, eye_size, Color.WHITE)
		ctrl.draw_circle(eye_r, eye_size, Color.WHITE)
		ctrl.draw_circle(eye_l + Vector2(0, 2), 3.0, Color("37474f"))
		ctrl.draw_circle(eye_r + Vector2(0, 2), 3.0, Color("37474f"))
		## Сльози
		ctrl.draw_circle(eye_l + Vector2(-3, 8), 2.0, Color("4fc3f7", 0.7))
		ctrl.draw_circle(eye_r + Vector2(3, 8), 2.0, Color("4fc3f7", 0.7))
	elif _earth_mood < MOOD_HAPPY:
		## Нейтральні/нормальні очі
		ctrl.draw_circle(eye_l, eye_size, Color.WHITE)
		ctrl.draw_circle(eye_r, eye_size, Color.WHITE)
		ctrl.draw_circle(eye_l, 3.0, Color("37474f"))
		ctrl.draw_circle(eye_r, 3.0, Color("37474f"))
	else:
		## Щасливі очі — блискучі
		ctrl.draw_circle(eye_l, eye_size, Color.WHITE)
		ctrl.draw_circle(eye_r, eye_size, Color.WHITE)
		ctrl.draw_circle(eye_l + Vector2(0, -1), 3.5, Color("37474f"))
		ctrl.draw_circle(eye_r + Vector2(0, -1), 3.5, Color("37474f"))
		## Блік в очах
		ctrl.draw_circle(eye_l + Vector2(1.5, -2.5), 1.5, Color.WHITE)
		ctrl.draw_circle(eye_r + Vector2(1.5, -2.5), 1.5, Color.WHITE)

	## Рот — змінюється за настроєм
	var mouth_y: float = cy + 12.0
	if _earth_mood < MOOD_SAD:
		## Сумний рот — дуга вниз
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in 13:
			var t: float = float(i) / 12.0
			var angle: float = PI + t * PI
			pts.append(Vector2(cx + cos(angle) * 12.0, mouth_y - 4.0 + sin(angle) * 5.0))
		if pts.size() >= 2:
			ctrl.draw_polyline(pts, Color("37474f"), 2.5)
	elif _earth_mood < MOOD_NEUTRAL:
		## Нейтральний рот — пряма лінія
		ctrl.draw_line(Vector2(cx - 10, mouth_y), Vector2(cx + 10, mouth_y),
			Color("37474f"), 2.5)
	elif _earth_mood < MOOD_HAPPY:
		## Посмішка — дуга вгору
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in 13:
			var t: float = float(i) / 12.0
			var angle: float = t * PI
			pts.append(Vector2(cx + cos(angle) * 12.0 - 12.0 + 24.0 * t,
				mouth_y + sin(angle) * 5.0))
		if pts.size() >= 2:
			ctrl.draw_polyline(pts, Color("37474f"), 2.5)
	else:
		## Ecstatic — широка посмішка + рум'янець
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in 13:
			var t: float = float(i) / 12.0
			var angle: float = t * PI
			pts.append(Vector2(cx - 15.0 + 30.0 * t,
				mouth_y + sin(angle) * 8.0))
		if pts.size() >= 2:
			ctrl.draw_polyline(pts, Color("37474f"), 3.0)
		## Рожеві щічки
		ctrl.draw_circle(Vector2(cx - 22, cy + 5), 6.0, Color("f48fb1", 0.4))
		ctrl.draw_circle(Vector2(cx + 22, cy + 5), 6.0, Color("f48fb1", 0.4))

	## Глянцевий блік на Землі
	ctrl.draw_circle(Vector2(cx - 15, cy - 20), 8.0, Color(1, 1, 1, 0.25))


## Перемалювати Earth face (після зміни _earth_mood)
func _redraw_earth() -> void:
	if not is_instance_valid(_earth_node):
		push_warning("EcoConveyor: _earth_node freed during redraw")
		return
	if _earth_node.get_child_count() > 0:
		var visual: Control = _earth_node.get_child(0) as Control
		if is_instance_valid(visual):
			visual.queue_redraw()


## Оновити настрій Землі після правильного сортування
func _update_earth_mood_on_correct() -> void:
	## Обчислюємо приріст: кожне correct sort додає пропорційну частку
	if _current_items_count > 0:
		var increment: float = 1.0 / float(_current_items_count * TOTAL_ROUNDS)
		_earth_mood = clampf(_earth_mood + increment * 3.0, 0.0, 1.0)
	_redraw_earth()
	## Bounce анімація Землі
	if is_instance_valid(_earth_node) and not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween()
		tw.tween_property(_earth_node, "scale", Vector2(1.15, 1.15), 0.1)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_earth_node, "scale", Vector2.ONE, 0.15)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Earth "кашляє" при помилці — wobble анімація
func _earth_cough() -> void:
	if not is_instance_valid(_earth_node) or SettingsManager.reduced_motion:
		return
	var orig_pos: Vector2 = _earth_node.position
	var tw: Tween = _create_game_tween()
	tw.tween_property(_earth_node, "position:x", orig_pos.x - 5.0, 0.04)
	tw.tween_property(_earth_node, "position:x", orig_pos.x + 5.0, 0.04)
	tw.tween_property(_earth_node, "position:x", orig_pos.x - 3.0, 0.03)
	tw.tween_property(_earth_node, "position:x", orig_pos.x, 0.03)


## Кумедна реакція: предмет "виплюнутий" при неправильному біні.
## Лише scale squish — position і rotation анімує _snap_back_to_conveyor.
func _play_funny_bin_spit(item: Node2D) -> void:
	if not is_instance_valid(item) or SettingsManager.reduced_motion:
		return
	var spit_tw: Tween = _create_game_tween()
	## Scale squish: предмет "стискується" як від удару об бін і пружинить назад
	spit_tw.tween_property(item, "scale", Vector2(1.25, 0.75), 0.06)
	spit_tw.tween_property(item, "scale", Vector2(0.85, 1.15), 0.06)
	spit_tw.tween_property(item, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## Кольоровий тінт — "не те місце!"
	spit_tw.parallel().tween_property(item, "modulate", Color(1.2, 0.85, 0.85), 0.08)
	spit_tw.tween_property(item, "modulate", Color.WHITE, 0.2)
	AudioManager.play_sfx("whoosh", 1.2)


## Кумедна Earth реакція — "кашляє" з підскоком + стисненням.
func _earth_cough_funny() -> void:
	if not is_instance_valid(_earth_node) or SettingsManager.reduced_motion:
		return
	var orig_pos: Vector2 = _earth_node.position
	var tw: Tween = _create_game_tween()
	## Підскік вгору — наче кашляє
	tw.tween_property(_earth_node, "position:y", orig_pos.y - 8.0, 0.06)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_earth_node, "position:y", orig_pos.y, 0.08)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	## Squish — як від кашлю
	tw.parallel().tween_property(_earth_node, "scale", Vector2(1.1, 0.9), 0.06)
	tw.tween_property(_earth_node, "scale", Vector2(0.95, 1.05), 0.06)
	tw.tween_property(_earth_node, "scale", Vector2.ONE, 0.1)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## Shake по X (класичний кашель)
	tw.parallel().tween_property(_earth_node, "position:x", orig_pos.x - 4.0, 0.04)
	tw.tween_property(_earth_node, "position:x", orig_pos.x + 4.0, 0.04)
	tw.tween_property(_earth_node, "position:x", orig_pos.x, 0.03)
	AudioManager.play_sfx("pop", 0.7)


## --- Будуємо біни відповідно до раунду та віку ---

func _build_bins_for_round() -> void:
	## Очистити попередні біни (LAW 11: no orphans)
	_cleanup_bin_nodes()
	_bins.clear()

	var ramp: Array[Vector2i] = TODDLER_RAMP if _is_toddler else PRESCHOOL_RAMP
	var round_idx: int = clampi(_round, 0, ramp.size() - 1)
	var bin_count: int = ramp[round_idx].x
	var all_bins: Array[Dictionary] = TODDLER_BINS.duplicate() if _is_toddler \
		else PRESCHOOL_BINS.duplicate()

	## A8: fallback якщо bin_count > available bins
	bin_count = mini(bin_count, all_bins.size())
	if bin_count <= 0:
		push_warning("EcoConveyor: bin_count=0, fallback to 2")
		bin_count = mini(2, all_bins.size())

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var spacing: float = vp.x / float(bin_count + 1)
	var bin_y: float = vp.y * 0.82
	var active_bins: Array[Dictionary] = all_bins.slice(0, bin_count)

	for i: int in active_bins.size():
		var b: Dictionary = active_bins[i]
		var x: float = spacing * float(i + 1) - BIN_W * 0.5
		var rect: Rect2 = Rect2(x, bin_y - BIN_H * 0.5, BIN_W, BIN_H)

		## Фон контейнера
		var panel: Panel = Panel.new()
		panel.position = Vector2(x, bin_y - BIN_H * 0.5)
		panel.size = Vector2(BIN_W, BIN_H)
		var style: StyleBoxFlat = GameData.candy_panel(
			Color(b.get("color", Color.WHITE), 0.80), BIN_CORNER)
		style.border_color = Color(b.get("color", Color.WHITE), 0.90)
		style.set_border_width_all(3)
		style.border_width_bottom = 5
		panel.add_theme_stylebox_override("panel", style)

		## Premium overlay + текстура (LAW 28)
		var tile_colors: Array[String] = ["green", "pink", "blue", "orange"]
		var tile_idx: int = i % tile_colors.size()
		var tile_path: String = "res://assets/textures/tiles/%s/tile_03.png" % tile_colors[tile_idx]
		panel.material = GameData.create_premium_material(
			0.05, 2.0, 0.04, 0.08, 0.06, 0.05, 0.08, tile_path, 0.18, 0.12, 0.28, 0.22)
		add_child(panel)
		_bin_panels.append(panel)

		## Глянцевий блік контейнера
		var bin_gloss: Panel = Panel.new()
		bin_gloss.position = Vector2(4.0, 4.0)
		bin_gloss.size = Vector2(BIN_W - 8.0, BIN_H * 0.32)
		var gloss_s: StyleBoxFlat = StyleBoxFlat.new()
		gloss_s.bg_color = Color(1, 1, 1, 0.18)
		gloss_s.corner_radius_top_left = BIN_CORNER
		gloss_s.corner_radius_top_right = BIN_CORNER
		@warning_ignore("integer_division")
		gloss_s.corner_radius_bottom_left = BIN_CORNER / 2
		@warning_ignore("integer_division")
		gloss_s.corner_radius_bottom_right = BIN_CORNER / 2
		bin_gloss.add_theme_stylebox_override("panel", gloss_s)
		bin_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(bin_gloss)

		## Іконка контейнера (LAW 25: іконка + колір для color-blind safe)
		var icon_id: String = b.get("icon", "paper")
		var bin_icon: Control = _create_bin_icon(icon_id, 44.0)
		bin_icon.position = Vector2(x + (BIN_W - 44.0) * 0.5, bin_y - BIN_H * 0.5 + 10)
		bin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bin_icon)
		_bin_icons.append(bin_icon)

		## Підпис контейнера (A12: i18n через tr())
		var name_lbl: Label = Label.new()
		name_lbl.text = tr(b.get("label", ""))
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		name_lbl.position = Vector2(x, bin_y + BIN_H * 0.5 - 36)
		name_lbl.size = Vector2(BIN_W, 36)
		add_child(name_lbl)
		_bin_labels.append(name_lbl)

		_bins.append({"rect": rect, "id": b.get("id", ""), "panel": panel})

	## Premium стагерована поява контейнерів
	var canvas_items: Array[CanvasItem] = []
	for bin: Dictionary in _bins:
		var bp: Panel = bin.get("panel", null) as Panel
		if is_instance_valid(bp):
			canvas_items.append(bp as CanvasItem)
	_staggered_spawn(canvas_items, 0.12)


## Іконка біна: для toddler — чисте/брудне, для preschool — матеріал
func _create_bin_icon(icon_id: String, icon_size: float) -> Control:
	match icon_id:
		"clean":
			return IconDraw.star_5pt(icon_size, Color("81c784"))
		"dirty":
			return IconDraw.trash_can(icon_size, Color("e57373"))
		"paper", "plastic", "glass", "organic":
			return IconDraw.trash_icon(icon_id, icon_size)
		_:
			push_warning("EcoConveyor: unknown bin icon '%s'" % icon_id)
			return IconDraw.trash_icon("paper", icon_size)


## Очистити bin-related ноди (LAW 11: no orphans)
func _cleanup_bin_nodes() -> void:
	for panel: Node in _bin_panels:
		if is_instance_valid(panel):
			panel.queue_free()
	_bin_panels.clear()
	for icon: Node in _bin_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	_bin_icons.clear()
	for lbl: Node in _bin_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_bin_labels.clear()


## --- Раунди ---

func _start_round() -> void:
	_sorted_count = 0
	_input_locked = true
	_spawning = true
	_spawn_timer = 0.0

	## Перебудувати біни якщо кількість змінилась між раундами (A4)
	var ramp: Array[Vector2i] = TODDLER_RAMP if _is_toddler else PRESCHOOL_RAMP
	var round_idx: int = clampi(_round, 0, ramp.size() - 1)
	var expected_bin_count: int = ramp[round_idx].x
	if _bins.size() != expected_bin_count:
		_build_bins_for_round()

	## A4: швидкість падіння зростає від easy до hard за 5 раундів
	_current_fall_speed = _scale_by_round(FALL_SPEED_EASY, FALL_SPEED_HARD,
		_round, TOTAL_ROUNDS)

	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, TOTAL_ROUNDS])
	_fade_instruction(_instruction_label, get_tutorial_instruction())

	## Генеруємо чергу предметів — рівний розподіл по бінах
	_spawn_queue.clear()
	_current_items_count = ramp[round_idx].y

	var item_pool: Array[Dictionary] = _get_item_pool()
	if item_pool.is_empty():
		push_warning("EcoConveyor: item pool empty, fallback to first available")
		item_pool = TODDLER_ITEMS.duplicate() if _is_toddler \
			else PRESCHOOL_ITEMS.duplicate()

	## Фільтруємо items щоб включити тільки ті що мають відповідний bin
	var active_bin_ids: Array[String] = []
	for bin: Dictionary in _bins:
		active_bin_ids.append(bin.get("id", ""))

	var valid_items: Array[Dictionary] = []
	for item: Dictionary in item_pool:
		if active_bin_ids.has(item.get("bin_id", "")):
			valid_items.append(item)

	## A8: fallback якщо фільтр лишив 0 предметів
	if valid_items.is_empty():
		push_warning("EcoConveyor: no valid items for round %d, using unfiltered" % _round)
		valid_items = item_pool.duplicate()

	var queue: Array[Dictionary] = []
	for j: int in _current_items_count:
		if valid_items.size() > 0:
			queue.append(valid_items[j % valid_items.size()])
	queue.shuffle()
	_spawn_queue = queue

	## Спавнимо перший предмет одразу
	_spawn_next_item()

	var start_d: float = ANIM_FAST if SettingsManager.reduced_motion else ANIM_NORMAL
	var tw: Tween = _create_game_tween()
	tw.tween_interval(start_d)
	tw.tween_callback(func() -> void:
		_input_locked = false
		_reset_idle_timer())


## Повертає пул предметів для поточного віку
func _get_item_pool() -> Array[Dictionary]:
	if _is_toddler:
		return TODDLER_ITEMS.duplicate()
	return PRESCHOOL_ITEMS.duplicate()


func _spawn_next_item() -> void:
	if _spawn_queue.is_empty():
		_spawning = false
		return
	if _items.size() >= MAX_ACTIVE_ITEMS:
		return
	var item_data: Dictionary = _spawn_queue.pop_front()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var x: float = randf_range(80.0, vp.x - 80.0)
	var item: Node2D = _create_trash_item(item_data)
	item.position = Vector2(x, -ITEM_SIZE)
	_item_bin_id[item] = item_data.get("bin_id", "")
	_items.append(item)
	_all_round_nodes.append(item)
	## Плавна поява предмета
	if not (SettingsManager and SettingsManager.reduced_motion):
		item.scale = Vector2.ZERO
		item.modulate.a = 0.0
		var etw: Tween = _create_game_tween().set_parallel(true)
		etw.tween_property(item, "scale", Vector2.ONE, 0.2)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		etw.tween_property(item, "modulate:a", 1.0, 0.15)


func _create_trash_item(item_data: Dictionary) -> Node2D:
	var node: Node2D = Node2D.new()
	add_child(node)
	var item_color: Color = item_data.get("color", Color.WHITE)

	## Кругле тло
	var bg: Panel = Panel.new()
	bg.size = Vector2(ITEM_SIZE, ITEM_SIZE)
	bg.position = Vector2(-ITEM_SIZE * 0.5, -ITEM_SIZE * 0.5)
	var style: StyleBoxFlat = GameData.candy_circle(item_color, ITEM_SIZE * 0.5)
	style.border_color = Color(1, 1, 1, 0.55)
	style.set_border_width_all(3)
	style.border_width_bottom = 5
	bg.add_theme_stylebox_override("panel", style)
	## Premium overlay (LAW 28)
	bg.material = GameData.create_premium_material(
		0.05, 2.0, 0.04, 0.08, 0.06, 0.05, 0.08, "", 0.0, 0.12, 0.25, 0.20)
	node.add_child(bg)

	## HQ текстура фішки (kenney boardgame chip) для глибини
	var chip_map: Dictionary = {
		"paper": "chipBlueWhite", "plastic": "chipRedWhite",
		"glass": "chipGreenWhite", "organic": "chipWhite",
		"clean": "chipGreenWhite", "dirty": "chipRedWhite",
	}
	var bin_id: String = item_data.get("bin_id", "")
	var chip_name: String = chip_map.get(bin_id, "chipWhite")
	var chip_path: String = "res://assets/textures/kenney/boardgame/%s.png" % chip_name
	var chip_tex: Texture2D = _chip_cache.get(chip_path, null) as Texture2D
	if chip_tex == null and ResourceLoader.exists(chip_path):
		push_warning("EcoConveyor: chip cache miss for %s, fallback load" % chip_path)
		chip_tex = load(chip_path)
	if chip_tex:
		var chip_sz: float = ITEM_SIZE * 0.9
		var chip_ctrl: Control = Control.new()
		chip_ctrl.size = Vector2(chip_sz, chip_sz)
		chip_ctrl.position = Vector2(-ITEM_SIZE * 0.45, -ITEM_SIZE * 0.45)
		chip_ctrl.modulate = Color(1, 1, 1, 0.5)
		chip_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip_ctrl.draw.connect(func() -> void:
			chip_ctrl.draw_texture_rect(chip_tex,
				Rect2(Vector2.ZERO, Vector2(chip_sz, chip_sz)), false)
		)
		node.add_child(chip_ctrl)

	## Глянцевий блік на кулі
	var gloss: Panel = Panel.new()
	var gl_w: float = ITEM_SIZE * 0.7
	var gl_h: float = ITEM_SIZE * 0.35
	gloss.size = Vector2(gl_w, gl_h)
	gloss.position = Vector2(-gl_w * 0.5, -ITEM_SIZE * 0.45)
	var gl_s: StyleBoxFlat = StyleBoxFlat.new()
	gl_s.bg_color = Color(1, 1, 1, 0.28)
	gl_s.set_corner_radius_all(int(gl_h * 0.5))
	gloss.add_theme_stylebox_override("panel", gl_s)
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(gloss)

	## Іконка предмета (LAW 25: іконка для visual distinction)
	var icon_id: String = item_data.get("icon", "paper")
	var icon_sz: float = ITEM_SIZE * 0.5
	var icon: Control = _create_item_icon(icon_id, icon_sz)
	icon.position = Vector2(-icon_sz * 0.5, -icon_sz * 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(icon)
	return node


## Створює іконку для предмета — toddler має конкретні іконки
func _create_item_icon(icon_id: String, icon_size: float) -> Control:
	match icon_id:
		"paper", "plastic", "glass", "organic":
			return IconDraw.trash_icon(icon_id, icon_size)
		"toy":
			return IconDraw.building_blocks(icon_size)
		"flower":
			return IconDraw.apple(icon_size, Color("f06292"))
		"ball":
			return IconDraw.color_dot(icon_size, Color("ffb74d"))
		"book":
			return IconDraw.open_book(icon_size)
		"mud":
			return IconDraw.color_dot(icon_size, Color("8d6e63"))
		"trash_bag":
			return IconDraw.trash_can(icon_size, Color("78909c"))
		"old_food":
			return IconDraw.organic_peel(icon_size)
		"broken":
			return IconDraw.glass_cup(icon_size)
		_:
			push_warning("EcoConveyor: unknown item icon '%s'" % icon_id)
			return IconDraw.trash_icon("paper", icon_size)


## --- Input & drag ---

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _dragged:
			_try_pick()
		elif not event.pressed and _dragged:
			_try_drop()
	elif event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed and not _dragged:
			_try_pick()
		elif not event.pressed and _dragged:
			_try_drop()


func _process(delta: float) -> void:
	## Падіння предметів зверху
	if not _game_over:
		var vp_h: float = get_viewport().get_visible_rect().size.y
		for item: Node2D in _items:
			if not is_instance_valid(item) or item == _dragged:
				continue
			item.position.y += _current_fall_speed * delta
			## Предмет долетів до низу
			if item.position.y > vp_h + ITEM_SIZE:
				if _is_toddler:
					## A6: toddler — м'яко повертаємо нагору, без покарання
					item.position.y = -ITEM_SIZE
					item.position.x = randf_range(80.0,
						get_viewport().get_visible_rect().size.x - 80.0)
				else:
					## A7: preschool — пропущений предмет = помилка
					_errors += 1
					_register_error(item)
					_item_bin_id.erase(item)  ## LAW 17/LAW 9: erase BEFORE queue_free
					_items.erase(item)
					_sorted_count += 1
					item.queue_free()
					_earth_cough()
					if _sorted_count >= _current_items_count:
						_on_round_complete()
					break

	## Спавн нових предметів з інтервалом
	if _spawning and not _spawn_queue.is_empty():
		_spawn_timer += delta
		if _spawn_timer >= SPAWN_INTERVAL:
			_spawn_timer = 0.0
			_spawn_next_item()

	## Drag processing
	if not _dragged:
		return
	var mouse: Vector2 = get_global_mouse_position()
	_drag_velocity = (mouse - _last_mouse) / maxf(delta, 0.001)
	_last_mouse = mouse
	_dragged.global_position = mouse + _drag_offset
	var rot: float = clampf(_drag_velocity.x * TILT_FACTOR, -TILT_MAX, TILT_MAX)
	_dragged.rotation = lerpf(_dragged.rotation, rot, TILT_LERP * delta)

	## Підсвітка контейнерів при наведенні
	for bin: Dictionary in _bins:
		var p: Panel = bin.get("panel", null) as Panel
		if not is_instance_valid(p):
			continue
		if bin.get("rect", Rect2()).has_point(_dragged.global_position):
			p.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			p.modulate = Color.WHITE


func _try_pick() -> void:
	var mouse: Vector2 = get_global_mouse_position()
	var best: Node2D = null
	var best_dist: float = PICK_RADIUS
	for item: Node2D in _items:
		if not is_instance_valid(item):
			continue
		var d: float = mouse.distance_to(item.global_position)
		if d < best_dist:
			best_dist = d
			best = item
	if not best:
		return
	_dragged = best
	_drag_offset = best.global_position - mouse
	_drag_original_z = best.z_index
	_last_mouse = mouse
	_drag_velocity = Vector2.ZERO
	best.z_index = 10
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	if not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween()
		tw.tween_property(best, "scale", Vector2(0.85, 1.15), 0.06)
		tw.tween_property(best, "scale", Vector2.ONE, 0.06)


func _try_drop() -> void:
	if not _dragged:
		return
	var item: Node2D = _dragged
	var drop_pos: Vector2 = item.global_position
	_dragged = null
	item.z_index = _drag_original_z

	## Squish при відпусканні
	if not SettingsManager.reduced_motion:
		var sq: Tween = _create_game_tween()
		sq.tween_property(item, "scale", Vector2(1.2, 0.8), 0.06)
		sq.tween_property(item, "scale", Vector2.ONE, 0.08)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	## Скинути підсвітку контейнерів
	for bin: Dictionary in _bins:
		var p: Panel = bin.get("panel", null) as Panel
		if is_instance_valid(p):
			p.modulate = Color.WHITE

	## Перевірити контейнери
	for bin: Dictionary in _bins:
		var bin_rect: Rect2 = bin.get("rect", Rect2())
		if bin_rect.has_point(drop_pos):
			var item_target: String = _item_bin_id.get(item, "")
			if item_target == bin.get("id", ""):
				_handle_correct(item, bin)
			else:
				_handle_wrong(item)
			return

	## Не потрапив в жоден бін — snap back
	_snap_back_to_conveyor(item)


## --- Feedback ---

func _handle_correct(item: Node2D, bin: Dictionary) -> void:
	_register_correct(item)
	_item_bin_id.erase(item)  ## LAW 17/LAW 9: erase before queue_free
	_items.erase(item)
	_sorted_count += 1

	## Earth mood зростає з кожним правильним сортуванням
	_update_earth_mood_on_correct()

	## VFX sparkle (LAW 28)
	VFXManager.spawn_correct_sparkle(item.global_position)

	## Контейнер підстрибує
	if not SettingsManager.reduced_motion:
		var panel: Panel = bin.get("panel", null) as Panel
		if is_instance_valid(panel):
			var orig_y: float = panel.position.y
			var tw_b: Tween = _create_game_tween()
			tw_b.tween_property(panel, "position:y", orig_y - 15.0, 0.1)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_b.tween_property(panel, "position:y", orig_y, 0.15)\
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	## Предмет летить у контейнер і зникає
	var bin_rect: Rect2 = bin.get("rect", Rect2())
	var center: Vector2 = bin_rect.get_center()
	if SettingsManager.reduced_motion:
		item.global_position = center
		item.modulate.a = 0.0
		item.queue_free()
		if _sorted_count >= _current_items_count:
			_on_round_complete()
		else:
			_reset_idle_timer()
	else:
		var tw: Tween = _create_game_tween()
		tw.tween_property(item, "global_position", center, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(item, "scale", Vector2(0.3, 0.3), 0.2)
		tw.parallel().tween_property(item, "modulate:a", 0.0, 0.15).set_delay(0.1)
		tw.parallel().tween_property(item, "rotation", 0.0, 0.1)
		tw.tween_callback(item.queue_free)
		if _sorted_count >= _current_items_count:
			tw.chain().tween_callback(_on_round_complete)
		else:
			_reset_idle_timer()


func _handle_wrong(item: Node2D) -> void:
	if _is_toddler:
		## A6: toddler — немає покарання, м'який feedback
		_register_error(item)  ## A11: scaffolding tracker
	else:
		## A7: preschool — лічильник помилок
		_errors += 1
		_register_error(item)
	## Кумедна реакція: предмет "виплюнутий" вгору з біна + Earth кашляє
	_play_funny_bin_spit(item)
	_earth_cough_funny()
	_snap_back_to_conveyor(item)


func _snap_back_to_conveyor(item: Node2D) -> void:
	if not is_instance_valid(item):
		push_warning("EcoConveyor: snap_back item freed")
		return
	## Повертаємо предмет нагору на конвеєр
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var target_pos: Vector2 = Vector2(item.position.x, vp.y * 0.3)
	if SettingsManager.reduced_motion:
		item.position = target_pos
		item.rotation = 0.0
		return
	var tw: Tween = _create_game_tween()
	tw.tween_property(item, "position", target_pos, 0.3)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(item, "rotation", 0.0, 0.15)


## --- Round management ---

func _on_round_complete() -> void:
	_input_locked = true
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_premium_celebration(get_viewport().get_visible_rect().size * 0.5)

	## Оновити Earth mood після раунду
	_redraw_earth()

	var round_d: float = ANIM_FAST if SettingsManager.reduced_motion else ROUND_DELAY
	var tw: Tween = _create_game_tween()
	tw.tween_interval(round_d)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_clear_round()
		_round += 1
		if _round >= TOTAL_ROUNDS:
			_finish()
		else:
			_start_round())


func _clear_round() -> void:
	## A9: Round hygiene — очистити ВСЕ тимчасове
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			_item_bin_id.erase(node)  ## LAW 9: erase BEFORE queue_free
			node.queue_free()
	_all_round_nodes.clear()
	_items.clear()
	_item_bin_id.clear()
	_spawn_queue.clear()


func _finish() -> void:
	_game_over = true
	_input_locked = true

	## Ecstatic Earth при перемозі — максимальний mood
	_earth_mood = 1.0
	_redraw_earth()

	## Квіти виростають навколо Землі при перемозі (narrative reward)
	if is_instance_valid(_earth_node) and not SettingsManager.reduced_motion:
		_spawn_victory_flowers()

	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)  ## LAW 16: centralized formula
	finish_game(earned, {"time_sec": elapsed, "errors": _errors,
		"rounds_played": TOTAL_ROUNDS, "earned_stars": earned})


## Квіти навколо Землі при перемозі — візуальна нагорода
func _spawn_victory_flowers() -> void:
	if not is_instance_valid(_earth_node):
		push_warning("EcoConveyor: _earth_node freed before victory flowers")
		return
	var flower_colors: Array[Color] = [
		Color("f06292"), Color("ffb74d"), Color("ba68c8"),
		Color("4fc3f7"), Color("81c784"),
	]
	for i: int in flower_colors.size():
		var angle: float = float(i) * TAU / float(flower_colors.size()) - PI * 0.5
		var radius: float = 70.0
		var pos: Vector2 = Vector2(cos(angle) * radius, sin(angle) * radius)
		var flower: Node2D = Node2D.new()
		flower.position = _earth_node.position + pos
		flower.scale = Vector2.ZERO
		add_child(flower)
		_flower_nodes.append(flower)

		## Малюємо квітку
		var fc: Color = flower_colors[i]
		var fctrl: Control = Control.new()
		fctrl.custom_minimum_size = Vector2(30, 30)
		fctrl.size = Vector2(30, 30)
		fctrl.position = Vector2(-15, -15)
		fctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fctrl.draw.connect(func() -> void:
			## Пелюстки
			for p: int in 5:
				var a: float = float(p) * TAU / 5.0
				var petal_pos: Vector2 = Vector2(15 + cos(a) * 8, 15 + sin(a) * 8)
				fctrl.draw_circle(petal_pos, 6.0, fc)
			## Серцевина
			fctrl.draw_circle(Vector2(15, 15), 4.0, Color("ffeb3b"))
		)
		flower.add_child(fctrl)

		## Анімація появи з затримкою
		var tw: Tween = _create_game_tween()
		tw.tween_interval(0.1 * float(i))
		tw.tween_property(flower, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## --- Idle hint (A10) ---

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
