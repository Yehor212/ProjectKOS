extends BaseMiniGame

## Магазин Тофі — покупець-тварина приходить з гаманцем, обирає товар на полиці.
## Дитина перетягує монети з гаманця на прилавок щоб заплатити точну ціну.
## Ка-чинг! Чек друкується, товар йде в пакет. Переплата — продавець повертає зайве.

const ROUNDS_TODDLER: int = 3
const ROUNDS_PRESCHOOL: int = 5
const IDLE_HINT_DELAY: float = 5.0
const COIN_SIZE: float = 64.0
const TODDLER_COIN_SIZE: float = 90.0
const DEAL_STAGGER: float = 0.1
const DEAL_DURATION: float = 0.35
const SAFETY_TIMEOUT_SEC: float = 120.0

## Зони розміщення (відносні координати viewport)
const SHELF_Y_RATIO: float = 0.18
const COUNTER_Y_RATIO: float = 0.50
const WALLET_Y_RATIO: float = 0.82
const CUSTOMER_X_RATIO: float = 0.15
const PRODUCT_X_RATIO: float = 0.50
const COUNTER_X_RATIO: float = 0.65

## Розміри елементів
const PRODUCT_SIZE: Vector2 = Vector2(100, 100)
const CUSTOMER_SIZE: Vector2 = Vector2(120, 120)
const COUNTER_SIZE: Vector2 = Vector2(200, 100)
const PRICE_TAG_SIZE: Vector2 = Vector2(60, 40)
const BAG_SIZE: Vector2 = Vector2(80, 100)
const RECEIPT_WIDTH: float = 50.0

## Номінали монет та їхні кольори (LAW 25: номінал завжди видно числом)
const COIN_VALUES: Array[int] = [1, 2, 5]
const COIN_COLORS: Dictionary = {
	1: Color("ffd166"),  ## Золотий
	2: Color("a8dadc"),  ## Блакитний
	5: Color("e76f51"),  ## Теракотовий
}

## Toddler: лише монети по 1, великі touch targets, ціни 1-3
const TODDLER_COIN_VALUES: Array[int] = [1]
const TODDLER_PRICE_MIN: int = 1
const TODDLER_PRICE_MAX: int = 3

## Preschool: всі номінали, ціни прогресивно зростають
const PRESCHOOL_PRICE_EASY: int = 3
const PRESCHOOL_PRICE_HARD: int = 12

## Товари магазину — використовуємо наявні food спрайти
const SHOP_PRODUCTS: Array[Dictionary] = [
	{"sprite": "Apple", "color": Color("e74c3c")},
	{"sprite": "Banana", "color": Color("f1c40f")},
	{"sprite": "Carrot", "color": Color("e67e22")},
	{"sprite": "Watermelon", "color": Color("27ae60")},
	{"sprite": "Honey", "color": Color("f39c12")},
	{"sprite": "Cheese", "color": Color("f4d03f")},
	{"sprite": "Fish", "color": Color("3498db")},
	{"sprite": "Walnut", "color": Color("8b6914")},
]

## Покупці — використовуємо наявні animal спрайти
const SHOP_CUSTOMERS: Array[String] = [
	"Bunny", "Cat", "Dog", "Frog", "Mouse",
	"Hedgehog", "Squirrel", "Penguin", "Panda", "Monkey",
]

var _is_toddler: bool = false
var _total_rounds: int = 0
var _drag: UniversalDrag = null
var _round: int = 0
var _target_price: int = 0
var _current_sum: int = 0
var _start_time: float = 0.0

## Ноди поточного раунду
var _coin_items: Array[Node2D] = []
var _all_round_nodes: Array[Node] = []
var _coin_value: Dictionary = {}
var _coin_origins: Dictionary = {}
var _counter_node: Node2D = null
var _product_node: Node2D = null
var _customer_node: Node2D = null
var _bag_node: Node2D = null
var _price_label: Label = null
var _sum_label: Label = null

## Стан idle
var _idle_timer: SceneTreeTimer = null

## Пул використаних товарів/покупців щоб уникнути повторів поспіль
var _used_products: Array[int] = []
var _used_customers: Array[int] = []


func _ready() -> void:
	game_id = "cash_register"
	_skill_id = "money_counting"
	bg_theme = "city"
	super()
	_is_toddler = (SettingsManager.age_group == 1)
	_total_rounds = ROUNDS_TODDLER if _is_toddler else ROUNDS_PRESCHOOL
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
		return tr("SHOP_TUTORIAL_TODDLER")
	return tr("SHOP_TUTORIAL")


func get_tutorial_demo() -> Dictionary:
	if _coin_items.is_empty() or not is_instance_valid(_counter_node):
		push_warning("CashRegister: get_tutorial_demo — coins empty or counter freed")
		return {}
	var coin: Node2D = _coin_items[0]
	if not is_instance_valid(coin):
		push_warning("CashRegister: get_tutorial_demo — coin freed")
		return {}
	return {"type": "drag", "from": coin.global_position, "to": _counter_node.global_position}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())


## ---- Раунди ----

func _start_round() -> void:
	_input_locked = true
	_current_sum = 0
	_fade_instruction(_instruction_label, get_tutorial_instruction())
	_update_round_label(tr("COUNTING_ROUND") % [_round + 1, _total_rounds])

	## Обираємо ціну для раунду (LAW 6: прогресивна складність)
	if _is_toddler:
		_target_price = _scale_adaptive_i(
			TODDLER_PRICE_MIN, TODDLER_PRICE_MAX, _round, _total_rounds)
	else:
		_target_price = _scale_adaptive_i(
			PRESCHOOL_PRICE_EASY, PRESCHOOL_PRICE_HARD, _round, _total_rounds)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	_spawn_customer(vp)
	_spawn_product(vp)
	_spawn_counter(vp)
	_spawn_bag(vp)
	_spawn_coins(vp)


## ---- Покупець-тварина (ліворуч) ----

func _spawn_customer(vp: Vector2) -> void:
	_customer_node = Node2D.new()
	var cx: float = vp.x * CUSTOMER_X_RATIO
	var cy: float = vp.y * COUNTER_Y_RATIO
	_customer_node.position = Vector2(cx, cy)
	add_child(_customer_node)
	_all_round_nodes.append(_customer_node)

	## Обираємо покупця без повтору (LAW 3: візуальна різноманітність)
	var idx: int = _pick_unique_index(SHOP_CUSTOMERS.size(), _used_customers)
	var animal_name: String = SHOP_CUSTOMERS[idx]
	var sprite_path: String = "res://assets/sprites/animals/%s.png" % animal_name

	var sz: float = CUSTOMER_SIZE.x
	if _is_toddler:
		sz *= 1.3

	if ResourceLoader.exists(sprite_path):
		var tex: Texture2D = load(sprite_path)
		var ctrl: Control = Control.new()
		ctrl.size = Vector2(sz, sz)
		ctrl.position = Vector2(-sz * 0.5, -sz * 0.5)
		ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var local_sz: float = sz
		ctrl.draw.connect(func() -> void:
			if is_instance_valid(ctrl):
				ctrl.draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(local_sz, local_sz)), false))
		_customer_node.add_child(ctrl)
	else:
		push_warning("CashRegister: текстура покупця '%s' не знайдена — fallback" % sprite_path)
		_draw_fallback_circle(_customer_node, sz, Color("a0c8ff"))

	## Мітка "покупець" з емоджі гаманця (A12: i18n, LAW 25: не тільки колір)
	var wallet_lbl: Label = Label.new()
	wallet_lbl.text = tr("SHOP_WALLET")
	wallet_lbl.add_theme_font_size_override("font_size", 24)
	wallet_lbl.add_theme_color_override("font_color", Color.WHITE)
	wallet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wallet_lbl.position = Vector2(-sz * 0.5, sz * 0.5 + 4.0)
	wallet_lbl.size = Vector2(sz, 24)
	wallet_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_customer_node.add_child(wallet_lbl)

	## Вхідна анімація покупця (зліва)
	if not SettingsManager.reduced_motion:
		_customer_node.position.x = -sz
		_customer_node.modulate.a = 0.0
		var tw: Tween = _create_game_tween()
		tw.set_parallel(true)
		tw.tween_property(_customer_node, "position:x", cx, 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_customer_node, "modulate:a", 1.0, 0.3)


## ---- Товар на полиці (центр-верх) ----

func _spawn_product(vp: Vector2) -> void:
	_product_node = Node2D.new()
	var px: float = vp.x * PRODUCT_X_RATIO
	var py: float = vp.y * SHELF_Y_RATIO + 48.0
	_product_node.position = Vector2(px, py)
	add_child(_product_node)
	_all_round_nodes.append(_product_node)

	## Обираємо товар без повтору
	var idx: int = _pick_unique_index(SHOP_PRODUCTS.size(), _used_products)
	var product: Dictionary = SHOP_PRODUCTS[idx]
	var sprite_name: String = product.get("sprite", "Apple")
	var sprite_path: String = "res://assets/sprites/food/%s.png" % sprite_name

	var sz: float = PRODUCT_SIZE.x
	if _is_toddler:
		sz *= 1.2

	## Полиця (підкладка під товар)
	var shelf_bg: Panel = Panel.new()
	var shelf_w: float = sz * 1.6
	shelf_bg.size = Vector2(shelf_w, sz * 1.2)
	shelf_bg.position = Vector2(-shelf_w * 0.5, -sz * 0.3)
	var shelf_style: StyleBoxFlat = GameData.candy_panel(Color("4a3728"), 16)
	shelf_style.border_color = Color("8b6914")
	shelf_style.set_border_width_all(2)
	shelf_bg.add_theme_stylebox_override("panel", shelf_style)
	shelf_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_product_node.add_child(shelf_bg)

	## Спрайт товару
	if ResourceLoader.exists(sprite_path):
		var tex: Texture2D = load(sprite_path)
		var ctrl: Control = Control.new()
		ctrl.size = Vector2(sz, sz)
		ctrl.position = Vector2(-sz * 0.5, -sz * 0.5 + 8.0)
		ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var local_sz: float = sz
		ctrl.draw.connect(func() -> void:
			if is_instance_valid(ctrl):
				ctrl.draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(local_sz, local_sz)), false))
		ctrl.material = GameData.create_premium_material(
			0.04, 2.0, 0.04, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		_product_node.add_child(ctrl)
	else:
		push_warning("CashRegister: текстура товару '%s' не знайдена — fallback" % sprite_path)
		_draw_fallback_circle(_product_node, sz, product.get("color", Color.MAGENTA))

	## Цінник (LAW 25: число + колір для доступності)
	var tag: Panel = Panel.new()
	tag.size = PRICE_TAG_SIZE
	tag.position = Vector2(sz * 0.3, -sz * 0.1)
	var tag_style: StyleBoxFlat = GameData.candy_panel(Color("fff8e0"), 8)
	tag_style.border_color = Color("e8a040")
	tag_style.set_border_width_all(2)
	tag.add_theme_stylebox_override("panel", tag_style)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_product_node.add_child(tag)

	_price_label = Label.new()
	_price_label.text = "%d" % _target_price
	var price_font_sz: int = 28 if _is_toddler else 22
	_price_label.add_theme_font_size_override("font_size", price_font_sz)
	_price_label.add_theme_color_override("font_color", Color("4A2C0A"))
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_price_label.position = Vector2.ZERO
	_price_label.size = PRICE_TAG_SIZE
	_price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(_price_label)


## ---- Прилавок (дропзона, центр) ----

func _spawn_counter(vp: Vector2) -> void:
	_counter_node = Node2D.new()
	_counter_node.position = Vector2(vp.x * COUNTER_X_RATIO, vp.y * COUNTER_Y_RATIO)
	add_child(_counter_node)
	_all_round_nodes.append(_counter_node)

	## Візуалізація прилавку
	var bg: Panel = Panel.new()
	bg.size = COUNTER_SIZE
	bg.position = Vector2(-COUNTER_SIZE.x * 0.5, -COUNTER_SIZE.y * 0.5)
	var style: StyleBoxFlat = GameData.candy_panel(Color("3d3d5c"), 20)
	style.border_color = Color("ffd166")
	style.set_border_width_all(3)
	bg.add_theme_stylebox_override("panel", style)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Grain overlay (LAW 28)
	bg.material = GameData.create_premium_material(
		0.04, 2.0, 0.04, 0.06, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
	GameData.add_gloss(bg, 14)
	_counter_node.add_child(bg)

	## Лічильник поточної суми на прилавку
	_sum_label = Label.new()
	_sum_label.text = "0 / %d" % _target_price
	var sum_font_sz: int = 28 if _is_toddler else 22
	_sum_label.add_theme_font_size_override("font_size", sum_font_sz)
	_sum_label.add_theme_color_override("font_color", Color.WHITE)
	_sum_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sum_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sum_label.position = Vector2(-COUNTER_SIZE.x * 0.5, -COUNTER_SIZE.y * 0.5)
	_sum_label.size = COUNTER_SIZE
	_sum_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter_node.add_child(_sum_label)

	_drag.drop_targets.append(_counter_node)


## ---- Пакет для покупки (праворуч від прилавку) ----

func _spawn_bag(vp: Vector2) -> void:
	_bag_node = Node2D.new()
	_bag_node.position = Vector2(vp.x * 0.85, vp.y * COUNTER_Y_RATIO + 10.0)
	_bag_node.modulate.a = 0.4
	add_child(_bag_node)
	_all_round_nodes.append(_bag_node)

	## Малюємо пакет (code-drawn, без залежності від спрайту)
	var bag_ctrl: Control = Control.new()
	bag_ctrl.size = BAG_SIZE
	bag_ctrl.position = Vector2(-BAG_SIZE.x * 0.5, -BAG_SIZE.y * 0.5)
	bag_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_ctrl.draw.connect(func() -> void:
		if not is_instance_valid(bag_ctrl):
			return
		## Тіло пакету
		var body_rect: Rect2 = Rect2(Vector2(5, 20), Vector2(BAG_SIZE.x - 10, BAG_SIZE.y - 25))
		bag_ctrl.draw_rect(body_rect, Color("8b6914"), true)
		bag_ctrl.draw_rect(body_rect, Color("6b4c10"), false, 2.0)
		## Ручки пакету
		bag_ctrl.draw_arc(Vector2(BAG_SIZE.x * 0.5, 20), 18.0, PI, TAU, 16, Color("6b4c10"), 2.5))
	_bag_node.add_child(bag_ctrl)

	## Мітка
	var bag_lbl: Label = Label.new()
	bag_lbl.text = tr("SHOP_BAG")
	bag_lbl.add_theme_font_size_override("font_size", 24)
	bag_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	bag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag_lbl.position = Vector2(-BAG_SIZE.x * 0.5, BAG_SIZE.y * 0.5 + 4.0)
	bag_lbl.size = Vector2(BAG_SIZE.x, 20)
	bag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_node.add_child(bag_lbl)


## ---- Монети з гаманця (нижня зона) ----

func _spawn_coins(vp: Vector2) -> void:
	var coins: Array[int] = _generate_coin_set(_target_price)
	coins.shuffle()
	var count: int = coins.size()
	if count == 0:
		push_warning("CashRegister: _generate_coin_set повернув порожній масив — fallback")
		coins = [1]
		count = 1
	var spacing: float = vp.x / float(maxi(count + 1, 2))
	var coin_y: float = vp.y * WALLET_Y_RATIO
	var sz: float = TODDLER_COIN_SIZE if _is_toddler else COIN_SIZE

	for i: int in count:
		var val: int = coins[i]
		var item: Node2D = Node2D.new()
		add_child(item)

		## Текстурна монета (HQ спрайт якщо доступний)
		var coin_frame: int = {1: 1, 2: 4, 5: 7}.get(val, 1)
		var coin_tex_path: String = "res://assets/textures/coins/coin_%02d.png" % coin_frame
		var coin_ctrl: Control = Control.new()
		coin_ctrl.size = Vector2(sz, sz)
		coin_ctrl.position = Vector2(-sz * 0.5, -sz * 0.5)
		coin_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if ResourceLoader.exists(coin_tex_path):
			var coin_tex: Texture2D = load(coin_tex_path)
			var local_sz: float = sz
			coin_ctrl.draw.connect(func() -> void:
				if is_instance_valid(coin_ctrl):
					coin_ctrl.draw_texture_rect(
						coin_tex, Rect2(Vector2.ZERO, Vector2(local_sz, local_sz)), false))
		else:
			push_warning("CashRegister: текстура монети '%s' не знайдена — fallback" % coin_tex_path)
			var fallback_color: Color = COIN_COLORS.get(val, Color.YELLOW)
			var local_sz: float = sz
			coin_ctrl.draw.connect(func() -> void:
				if is_instance_valid(coin_ctrl):
					coin_ctrl.draw_circle(Vector2(local_sz * 0.5, local_sz * 0.5),
						local_sz * 0.45, fallback_color))

		## Grain overlay (LAW 28)
		coin_ctrl.material = GameData.create_premium_material(
			0.05, 2.0, 0.04, 0.0, 0.06, 0.05, 0.08, "", 0.0, 0.10, 0.22, 0.18)
		item.add_child(coin_ctrl)

		## Номінал (LAW 25: завжди число, не тільки колір)
		var font_sz: int = 32 if _is_toddler else 24
		var num_lbl: Label = Label.new()
		num_lbl.text = str(val)
		num_lbl.add_theme_font_size_override("font_size", font_sz)
		num_lbl.add_theme_color_override("font_color", COIN_COLORS.get(val, Color.WHITE))
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
				_start_idle_breathing(_drag.draggable_items)
				_reset_idle_timer()
		else:
			item.position = Vector2(target_pos.x, vp.y + 100.0)
			item.modulate.a = 0.0
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = _create_game_tween().set_parallel(true)
			tw.tween_property(item, "position", target_pos, DEAL_DURATION)\
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(item, "modulate:a", 1.0, 0.2).set_delay(delay)
			if i == count - 1:
				tw.chain().tween_callback(func() -> void:
					_input_locked = false
					_drag.enabled = true
					_start_idle_breathing(_drag.draggable_items)
					_reset_idle_timer())

		_coin_value[item] = val
		_coin_origins[item] = target_pos
		_coin_items.append(item)
		_drag.draggable_items.append(item)
		_all_round_nodes.append(item)

	_staggered_spawn(_coin_items, 0.08)


## Генерація набору монет (гарантовано покриває суму + зайві для вибору)
func _generate_coin_set(target: int) -> Array[int]:
	var result: Array[int] = []
	var remaining: int = maxi(target, 1)

	if _is_toddler:
		## Toddler: лише монети по 1 (A3: вікова розвилка)
		for _i: int in remaining:
			result.append(1)
		## Додаємо 1-2 зайві для вибору (LAW 2: мінімум 3 варіанти)
		var extras: int = randi_range(1, maxi(3 - remaining, 1))
		for _j: int in extras:
			result.append(1)
		return result

	## Preschool: мікс номіналів
	var available: Array[int] = COIN_VALUES.duplicate()
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

	## Додаємо зайві монети (2-4 штуки)
	var extras: int = randi_range(2, 4)
	for _i: int in extras:
		if available.size() > 0:
			result.append(available[randi() % available.size()])
		else:
			result.append(1)
	return result


## ---- Input ----

func _input(event: InputEvent) -> void:
	if _input_locked or _game_over:
		return  ## Нормальний guard — не логуємо (LAW 23: input lock)
	_drag.handle_input(event)


func _process(delta: float) -> void:
	if _input_locked or _game_over:
		return  ## Нормальний guard — не логуємо (LAW 23: input lock)
	_drag.handle_process(delta)


func _on_picked(_item: Node2D) -> void:
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()


func _on_dropped_target(item: Node2D, _target: Node2D) -> void:
	if _game_over:
		push_warning("CashRegister: _on_dropped_target ignored — game over")
		return
	var val: int = _coin_value.get(item, 0)
	var new_sum: int = _current_sum + val

	if new_sum > _target_price:
		## Переплата — продавець ввічливо повертає монету
		_handle_overpay(item)
		return

	## Прийняти монету
	_current_sum = new_sum
	_register_correct(item)
	VFXManager.spawn_success_ripple(
		_counter_node.global_position if is_instance_valid(_counter_node)
		else get_viewport().get_visible_rect().size * 0.5,
		Color("ffd166"))

	if is_instance_valid(_sum_label):
		_sum_label.text = "%d / %d" % [_current_sum, _target_price]

	## Видаляємо монету з drag-системи (LAW 9: erase перед queue_free)
	_drag.draggable_items.erase(item)
	_coin_items.erase(item)

	## Анімація монети до прилавку
	if SettingsManager.reduced_motion:
		if is_instance_valid(item) and is_instance_valid(_counter_node):
			item.global_position = _counter_node.global_position
		if is_instance_valid(item):
			item.modulate.a = 0.3
		if _current_sum == _target_price:
			_on_round_complete()
		else:
			_reset_idle_timer()
		return

	var tw: Tween = _create_game_tween()
	if is_instance_valid(item) and is_instance_valid(_counter_node):
		tw.tween_property(item, "global_position",
			_counter_node.global_position, 0.2)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(item, "modulate:a", 0.3, 0.2)
	if _current_sum == _target_price:
		tw.chain().tween_callback(_on_round_complete)
	else:
		_reset_idle_timer()


func _on_dropped_empty(item: Node2D) -> void:
	var origin: Vector2 = _coin_origins.get(item, Vector2.ZERO)
	if origin == Vector2.ZERO and is_instance_valid(item):
		origin = item.position
	_drag.snap_back(item, origin)


## ---- Переплата ----

func _handle_overpay(item: Node2D) -> void:
	if _is_toddler:
		## A6: тоддлер — ні штрафу, м'який feedback
		_register_error(item)
	else:
		## A7: прешкільник — помилка рахується
		_errors += 1
		_register_error(item)

	## Повертаємо монету на місце
	var origin: Vector2 = _coin_origins.get(item, Vector2.ZERO)
	if origin == Vector2.ZERO and is_instance_valid(item):
		origin = item.position
	_drag.snap_back(item, origin)

	## Повідомлення про переплату
	if is_instance_valid(_sum_label):
		var original_text: String = _sum_label.text
		_sum_label.text = tr("SHOP_OVERPAY")
		_sum_label.add_theme_color_override("font_color", Color("e76f51"))
		if not SettingsManager.reduced_motion:
			var restore_tw: Tween = _create_game_tween()
			restore_tw.tween_interval(0.8)
			restore_tw.tween_callback(func() -> void:
				if is_instance_valid(_sum_label):
					_sum_label.text = original_text
					_sum_label.add_theme_color_override("font_color", Color.WHITE))

	_reset_idle_timer()


## ---- Управління раундами ----

func _on_round_complete() -> void:
	_input_locked = true
	_drag.enabled = false

	## Ка-чинг! (фірмовий звук покупки)
	AudioManager.play_sfx("ka_ching")
	HapticsManager.vibrate_success()

	## Анімація: чек друкується + товар летить у пакет
	_animate_purchase_sequence()


func _animate_purchase_sequence() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size

	## 1. Друк чеку (маленький білий прямокутник виїжджає з прилавку)
	var receipt: Node2D = Node2D.new()
	add_child(receipt)
	_all_round_nodes.append(receipt)
	var counter_pos: Vector2 = _counter_node.global_position if is_instance_valid(_counter_node) \
		else vp * 0.5
	receipt.position = counter_pos

	var receipt_ctrl: Control = Control.new()
	receipt_ctrl.size = Vector2(RECEIPT_WIDTH, 0)
	receipt_ctrl.position = Vector2(-RECEIPT_WIDTH * 0.5, -COUNTER_SIZE.y * 0.5)
	receipt_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt_ctrl.draw.connect(func() -> void:
		if is_instance_valid(receipt_ctrl):
			receipt_ctrl.draw_rect(
				Rect2(Vector2.ZERO, receipt_ctrl.size), Color("fffef0"), true)
			receipt_ctrl.draw_rect(
				Rect2(Vector2.ZERO, receipt_ctrl.size), Color("c0c0c0"), false, 1.0))
	receipt.add_child(receipt_ctrl)

	if not SettingsManager.reduced_motion:
		var tw: Tween = _create_game_tween()
		tw.tween_property(receipt_ctrl, "size:y", 40.0, 0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			if is_instance_valid(receipt_ctrl):
				receipt_ctrl.queue_redraw())
		tw.tween_interval(0.2)

		## 2. Товар летить у пакет
		if is_instance_valid(_product_node) and is_instance_valid(_bag_node):
			tw.tween_property(_product_node, "global_position",
				_bag_node.global_position, 0.4)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_product_node, "scale",
				Vector2(0.3, 0.3), 0.4)
		## Пакет стає яскравим
		if is_instance_valid(_bag_node):
			tw.tween_property(_bag_node, "modulate:a", 1.0, 0.2)

		## 3. Святкування
		tw.tween_callback(func() -> void:
			if not is_instance_valid(self):
				return
			VFXManager.spawn_premium_celebration(vp * 0.5))

		## 4. Пауза і наступний раунд
		tw.tween_interval(0.5)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(self):
				return
			_advance_to_next_round())
	else:
		## Reduced motion: миттєво
		if is_instance_valid(_bag_node):
			_bag_node.modulate.a = 1.0
		_advance_to_next_round()


func _advance_to_next_round() -> void:
	_clear_round()
	_round += 1
	if _round >= _total_rounds:
		_finish()
	else:
		_start_round()


func _clear_round() -> void:
	## LAW 9: Повна гігієна раунду — erase dict BEFORE queue_free (LAW 11)
	_coin_value.clear()
	_coin_origins.clear()
	_coin_items.clear()
	for node: Node in _all_round_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_all_round_nodes.clear()
	_counter_node = null
	_product_node = null
	_customer_node = null
	_bag_node = null
	_price_label = null
	_sum_label = null
	_drag.draggable_items.clear()
	_drag.drop_targets.clear()
	_drag.clear_drag()
	_kill_all_tweens()


func _finish() -> void:
	_game_over = true
	_input_locked = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	finish_game(earned, {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": _total_rounds,
		"earned_stars": earned,
	})


## ---- Idle hint (A10: 3-рівнева ескалація) ----

func _reset_idle_timer() -> void:
	if _game_over:
		return  ## Нормальний guard — гра завершена
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _game_over or _coin_items.is_empty():
		return  ## Нормальний guard — немає чого підказувати
	var level: int = _advance_idle_hint()

	if level >= 2:
		## A10 Lvl2+: tutorial hand — показує правильну монету та прилавок
		var demo: Dictionary = get_tutorial_demo()
		if demo.has("from") and demo.has("to"):
			var from_pos: Vector2 = demo.get("from", Vector2.ZERO)
			for item: Node2D in _coin_items:
				if is_instance_valid(item) \
						and item.global_position.distance_to(from_pos) < 10.0:
					_pulse_node(item, 1.3)
					if not SettingsManager.reduced_motion:
						var flash_tw: Tween = _create_game_tween()
						flash_tw.tween_property(item, "modulate",
							Color(1.5, 1.3, 0.7, 1.0), 0.15)
						flash_tw.tween_property(item, "modulate", Color.WHITE, 0.3)
					break
			## Пульсувати прилавок
			if is_instance_valid(_counter_node):
				_pulse_node(_counter_node, 1.15)
		_reset_idle_timer()
		return

	## Lvl0-1: пульсування першої доступної монети
	for item: Node2D in _coin_items:
		if is_instance_valid(item):
			_pulse_node(item, 1.15)
			break
	_reset_idle_timer()


## ---- Утиліти ----

## Обирає унікальний індекс з масиву, уникаючи повторів
func _pick_unique_index(pool_size: int, used: Array[int]) -> int:
	if pool_size <= 0:
		push_warning("CashRegister: _pick_unique_index — pool_size = 0")
		return 0
	if used.size() >= pool_size:
		used.clear()
	var idx: int = randi() % pool_size
	var attempts: int = 0
	while used.has(idx) and attempts < pool_size:
		idx = (idx + 1) % pool_size
		attempts += 1
	used.append(idx)
	return idx


## Fallback коло при відсутності спрайту (LAW 7)
func _draw_fallback_circle(parent: Node2D, sz: float, color: Color) -> void:
	var ctrl: Control = Control.new()
	ctrl.size = Vector2(sz, sz)
	ctrl.position = Vector2(-sz * 0.5, -sz * 0.5)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var local_sz: float = sz
	var local_color: Color = color
	ctrl.draw.connect(func() -> void:
		if is_instance_valid(ctrl):
			ctrl.draw_circle(
				Vector2(local_sz * 0.5, local_sz * 0.5), local_sz * 0.45, local_color))
	parent.add_child(ctrl)
