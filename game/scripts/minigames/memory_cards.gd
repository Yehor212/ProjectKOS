extends BaseMiniGame

## "Прятки в лесу / Hide and Seek" — тварини ховаються за об'єктами лісу.
## Toddler: напівпрозорі укриття (силует тварини видно) — тап 2 однакові.
## Preschool: непрозорі укриття (класичний memory), peek тривалість зменшується.
## Кожна знайдена пара: тварини вибігають до центру і "обіймаються".

const CARD_SCENE: PackedScene = preload("res://scenes/components/memory_card.tscn")
const BACK_TEX_PATH: String = "res://assets/branding/tofie_logo.png"
const DEAL_STAGGER: float = 0.1
const DEAL_DURATION: float = 0.4
const CARD_GAP: float = 20.0
const TOP_BAR_HEIGHT: float = 64.0
const IDLE_HINT_DELAY: float = 5.0
const VICTORY_STAGGER: float = 0.08
const SAFETY_TIMEOUT_SEC: float = 120.0
const CELEBRATION_MEET_DUR: float = 0.5
const CELEBRATION_HUG_DUR: float = 0.6

## Hiding spot types — малюються як декоративні overlay на картках (inner class _HidingSpotNode)
enum HidingSpot { TREE, BUSH, ROCK, FLOWER }

## -- Difficulty ramp (LAW 6, A4) --
## Toddler: 3 раунди, сітка росте, укриття напівпрозорі
const TODDLER_ROUNDS: int = 3
const TODDLER_GRIDS: Array[Vector2i] = [
	Vector2i(3, 2),  ## R1: 3 пари
	Vector2i(3, 2),  ## R2: 3 пари, укриття менш прозорі
	Vector2i(4, 2),  ## R3: 4 пари
]
## Toddler overlay прозорість: від дуже прозорого до менш прозорого
const TODDLER_ALPHA_EASY: float = 0.30
const TODDLER_ALPHA_HARD: float = 0.50

## Preschool: 5 раундів, сітка росте, peek duration зменшується
const PRESCHOOL_ROUNDS: int = 5
const PRESCHOOL_GRIDS: Array[Vector2i] = [
	Vector2i(3, 2),  ## R1: 3 пари
	Vector2i(4, 2),  ## R2: 4 пари
	Vector2i(4, 3),  ## R3: 6 пар
	Vector2i(4, 3),  ## R4: 6 пар, схожі тварини
	Vector2i(4, 4),  ## R5: 8 пар
]
const PEEK_DURATION_EASY: float = 1.5
const PEEK_DURATION_HARD: float = 0.6

var _grid_cols: int = 3
var _grid_rows: int = 2
var _pairs_count: int = 3
var _is_toddler_mode: bool = false

var _cards: Array[Node2D] = []
var _hiding_overlays: Dictionary = {}  ## card -> Node2D overlay
var _flipped: Array[Node2D] = []
var _matched_count: int = 0
var _start_time: float = 0.0
var _back_tex: Texture2D = null
var _used_indices: Array[int] = []
var _idle_timer: SceneTreeTimer = null
var _round: int = 0
var _total_rounds: int = 1
var _peek_duration: float = PEEK_DURATION_EASY
var _celebration_nodes: Array[Node2D] = []  ## Тимчасові ноди святкування


func _ready() -> void:
	game_id = "memory"
	bg_theme = "forest"
	super()
	_is_toddler_mode = (SettingsManager.age_group == 1)
	_total_rounds = TODDLER_ROUNDS if _is_toddler_mode else PRESCHOOL_ROUNDS
	if ResourceLoader.exists(BACK_TEX_PATH):
		_back_tex = load(BACK_TEX_PATH)
	else:
		push_warning("MemoryCards: Missing back texture: " + BACK_TEX_PATH)
	_start_time = Time.get_ticks_msec() / 1000.0
	_apply_background()
	_build_hud()
	_start_round()
	_start_safety_timeout(SAFETY_TIMEOUT_SEC)


func get_tutorial_instruction() -> String:
	if _is_toddler_mode:
		return tr("MEMORY_TUTORIAL_TODDLER")
	return tr("MEMORY_TUTORIAL_PRESCHOOL")


func get_tutorial_demo() -> Dictionary:
	for card: Node2D in _cards:
		if not card.is_matched:
			return {"type": "tap", "target": card.global_position}
	return {}


func _build_hud() -> void:
	_build_instruction_pill(get_tutorial_instruction())
	_update_progress()


## ---------- Round lifecycle ----------

func _start_round() -> void:
	_matched_count = 0
	_flipped.clear()
	_input_locked = true

	## Прогресивна складність — сітка росте з кожним раундом (LAW 6)
	var grids: Array[Vector2i] = TODDLER_GRIDS if _is_toddler_mode else PRESCHOOL_GRIDS
	var grid: Vector2i = grids[mini(_round, grids.size() - 1)]
	_grid_cols = grid.x
	_grid_rows = grid.y
	@warning_ignore("integer_division")
	_pairs_count = (_grid_cols * _grid_rows) / 2

	## Peek duration для Preschool зменшується з раундами (A4)
	if not _is_toddler_mode:
		_peek_duration = _scale_by_round(
			PEEK_DURATION_EASY, PEEK_DURATION_HARD, _round, _total_rounds)

	_update_progress()
	_deal_cards()


func _update_progress() -> void:
	if _round_label:
		_update_round_label(tr("MEMORY_PAIRS_FOUND") % [_matched_count, _pairs_count])


func _advance_round() -> void:
	_round += 1
	## Зберегти помилки раунду для адаптивної складності
	_round_errors.append(_errors)
	if _round >= _total_rounds:
		_finish()
	else:
		_clear_round()
		_start_round()


func _clear_round() -> void:
	## A9: Round hygiene — очистити ВСЕ тимчасове
	## Видалити overlay ноди ДО карток (LAW 11)
	for card_key: Variant in _hiding_overlays.keys():
		var overlay: Node2D = _hiding_overlays[card_key]
		if is_instance_valid(overlay):
			overlay.queue_free()
	_hiding_overlays.clear()

	## Видалити celebration ноди
	for node: Node2D in _celebration_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_celebration_nodes.clear()

	## Видалити картки
	for card: Node2D in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()
	_flipped.clear()


func _finish() -> void:
	_game_over = true
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _start_time
	var earned: int = _calculate_stars(_errors)
	var stats: Dictionary = {
		"time_sec": elapsed,
		"errors": _errors,
		"rounds_played": _total_rounds,
		"earned_stars": earned,
	}
	finish_game(earned, stats)


## ---------- Dealing cards ----------

func _deal_cards() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var card_data: Array[Dictionary] = []
	var indices: Array[int] = _pick_random_indices(_pairs_count)

	for idx: int in indices:
		if idx >= 0 and idx < GameData.ANIMALS_AND_FOOD.size():
			card_data.append(GameData.ANIMALS_AND_FOOD[idx])

	## Fallback: якщо набрали менше ніж потрібно (A8)
	if card_data.size() < 1:
		push_warning("MemoryCards: не вдалося набрати card_data — пропускаємо раунд")
		_advance_round()
		return

	## Створити пари (кожну тварину x 2)
	var pairs: Array[Dictionary] = []
	for entry: Dictionary in card_data:
		pairs.append(entry)
		pairs.append(entry)
	pairs.shuffle()

	## Згенерувати hiding spot типи для кожної позиції
	var spot_types: Array[int] = _generate_hiding_spots(pairs.size())

	## Обрахувати сітку
	var total_w: float = float(_grid_cols) * MemoryCard.CARD_WIDTH \
		+ float(_grid_cols - 1) * CARD_GAP
	var total_h: float = float(_grid_rows) * MemoryCard.CARD_HEIGHT \
		+ float(_grid_rows - 1) * CARD_GAP
	var origin_x: float = (vp.x - total_w) * 0.5 + MemoryCard.CARD_WIDTH * 0.5
	var origin_y: float = (vp.y - total_h + TOP_BAR_HEIGHT) * 0.5 \
		+ MemoryCard.CARD_HEIGHT * 0.5

	## Інстанціювати картки
	for i: int in pairs.size():
		var pair: Dictionary = pairs[i]
		var animal_name: String = pair.get("name", "")
		if animal_name.is_empty():
			push_warning("MemoryCards: pair without name at index %d" % i)
			continue
		var col: int = i % _grid_cols
		@warning_ignore("integer_division")
		var row: int = i / _grid_cols
		var target: Vector2 = Vector2(
			origin_x + float(col) * (MemoryCard.CARD_WIDTH + CARD_GAP),
			origin_y + float(row) * (MemoryCard.CARD_HEIGHT + CARD_GAP))

		var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
		if not ResourceLoader.exists(tex_path):
			push_warning("MemoryCards: Missing sprite: " + tex_path)
			continue
		var front_tex: Texture2D = load(tex_path)
		if not front_tex:
			push_warning("MemoryCards: текстуру '%s' не вдалося завантажити" % tex_path)
			continue

		var card: Node2D = CARD_SCENE.instantiate()
		add_child(card)

		## Toddler: картки відкриті (face_up=true), Preschool: закриті
		card.setup(animal_name, front_tex, _back_tex, _is_toddler_mode)
		_cards.append(card)

		## Toddler: додати напівпрозоре укриття поверх картки
		if _is_toddler_mode and spot_types.size() > 0:
			var spot_type: int = spot_types[mini(i, spot_types.size() - 1)]
			_add_hiding_overlay(card, spot_type)

		## Анімація deal — стартує з правого боку з дугою (LAW 28 premium)
		if SettingsManager.reduced_motion:
			card.position = target
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
			if i == pairs.size() - 1:
				_input_locked = false
				_reset_idle_timer()
		else:
			## Стартова позиція — з правого боку за екраном
			card.position = Vector2(vp.x + 120.0, vp.y * 0.3)
			card.scale = Vector2(0.6, 0.6)
			card.modulate.a = 0.0
			card.rotation = 0.15
			var delay: float = float(i) * DEAL_STAGGER
			var tw: Tween = _create_game_tween().set_parallel(true)
			tw.tween_property(card, "position", target, DEAL_DURATION) \
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "scale", Vector2.ONE, DEAL_DURATION) \
				.set_delay(delay).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "modulate:a", 1.0, 0.15).set_delay(delay)
			tw.tween_property(card, "rotation", 0.0, DEAL_DURATION * 0.8) \
				.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			## Розблокувати після останньої картки
			if i == pairs.size() - 1:
				tw.chain().tween_callback(func() -> void:
					_input_locked = false
					_reset_idle_timer()
				)

	## Перерахувати пари за реально створеними картками (LAW 15, A8)
	@warning_ignore("integer_division")
	_pairs_count = _cards.size() / 2
	if _pairs_count <= 0:
		push_warning("MemoryCards: жодна картка не створена — пропускаємо раунд")
		_advance_round()


## ---------- Hiding spot overlay (Toddler) ----------

func _add_hiding_overlay(card: Node2D, spot_type: int) -> void:
	var overlay: _HidingSpotNode = _HidingSpotNode.new()
	overlay.spot_type = spot_type

	## Прозорість залежить від раунду — стає менш прозорою (A4 difficulty ramp)
	var alpha: float = _scale_by_round(
		TODDLER_ALPHA_EASY, TODDLER_ALPHA_HARD, _round, _total_rounds)
	overlay.modulate.a = alpha
	overlay.z_index = 1  ## Поверх спрайту тварини

	card.add_child(overlay)
	_hiding_overlays[card] = overlay


func _dissolve_hiding_overlay(card: Node2D) -> void:
	if not _hiding_overlays.has(card):
		push_warning("MemoryCards: overlay not found for card — already dissolved")
		return
	var overlay: Node2D = _hiding_overlays[card]
	if not is_instance_valid(overlay):
		push_warning("MemoryCards: overlay freed before dissolve")
		_hiding_overlays.erase(card)
		return
	## Плавне розчинення укриття — тварину "знайдено"
	var tw: Tween = _create_game_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
	)
	_hiding_overlays.erase(card)


func _generate_hiding_spots(count: int) -> Array[int]:
	## Розподілити типи укриттів рівномірно з варіацією
	var types: Array[int] = []
	var available: Array[int] = [
		HidingSpot.TREE, HidingSpot.BUSH, HidingSpot.ROCK, HidingSpot.FLOWER]
	for i: int in count:
		types.append(available[i % available.size()])
	types.shuffle()
	return types


## ---------- Input handling ----------

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
	var mouse: Vector2 = get_global_mouse_position()
	_try_tap(mouse)


func _try_tap(pos: Vector2) -> void:
	for card: Node2D in _cards:
		if card.is_matched:
			continue
		if not card.contains_point(pos):
			continue
		if _is_toddler_mode:
			_try_tap_toddler(card)
		else:
			_try_tap_preschool(card)
		return


## -- Toddler: картки відкриті, тап = виділення, 2 однакові = пара --

func _try_tap_toddler(card: Node2D) -> void:
	## Та сама картка натиснута двічі — зняти виділення
	if _flipped.size() == 1 and card == _flipped[0]:
		card.set_highlighted(false)
		_flipped.clear()
		_reset_idle_timer()
		return
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	if _flipped.is_empty():
		## Перший вибір — highlight
		card.set_highlighted(true)
		_flipped.append(card)
		_reset_idle_timer()
	else:
		## Другий вибір — evaluate
		_input_locked = true
		card.set_highlighted(true)
		_flipped.append(card)
		var d: float = 0.15 if SettingsManager.reduced_motion else 0.2
		var tw: Tween = _create_game_tween()
		tw.tween_interval(d)
		tw.tween_callback(_evaluate)


## -- Preschool: класичний memory з peek duration --

func _try_tap_preschool(card: Node2D) -> void:
	if card.is_face_up or card.is_flipping:
		push_warning("MemoryCards: preschool tap ignored — card already face up or flipping")
		return
	if _flipped.size() == 1 and card == _flipped[0]:
		push_warning("MemoryCards: preschool tap ignored — same card tapped twice")
		return
	AudioManager.play_sfx("click")
	HapticsManager.vibrate_light()
	_flipped.append(card)
	var tw: Tween = card.flip_up()
	if _flipped.size() == 2:
		_input_locked = true
		tw.finished.connect(_evaluate)


## ---------- Evaluation ----------

func _evaluate() -> void:
	if _flipped.size() < 2:
		push_warning("MemoryCards: _flipped < 2 при evaluate")
		return
	var card_a: Node2D = _flipped[0]
	var card_b: Node2D = _flipped[1]
	if not is_instance_valid(card_a) or not is_instance_valid(card_b):
		push_warning("MemoryCards: картка freed до evaluate")
		_flipped.clear()
		_input_locked = false
		return
	if card_a.card_id == card_b.card_id:
		_handle_match()
	else:
		_handle_mismatch()


## ---------- Match handling ----------

func _handle_match() -> void:
	_register_correct(_flipped[0])

	## Premium match VFX (LAW 28) — sparkle на обох + ripple
	for card: Node2D in _flipped:
		if is_instance_valid(card):
			VFXManager.spawn_match_sparkle(card.global_position)
			VFXManager.spawn_success_ripple(card.global_position, Color("06d6a0"))

	## Juicy squish bounce на обох картках
	for card: Node2D in _flipped:
		card.set_highlighted(false)
		if not SettingsManager.reduced_motion:
			var tw: Tween = _create_game_tween()
			tw.tween_property(card, "scale", Vector2(1.25, 0.75), 0.07)
			tw.tween_property(card, "scale", Vector2(0.85, 1.15), 0.07)
			tw.tween_property(card, "scale", Vector2(1.05, 0.95), 0.05)
			tw.tween_property(card, "scale", Vector2.ONE, 0.05)

	## Toddler: розчинити укриття
	if _is_toddler_mode:
		for card: Node2D in _flipped:
			_dissolve_hiding_overlay(card)

	_flipped[0].set_matched()
	_flipped[1].set_matched()

	## Святкування: тварини "зустрічаються" по центру між картками
	_play_pair_celebration(_flipped[0], _flipped[1])

	_matched_count += 1
	_update_progress()
	_flipped.clear()

	if _matched_count >= _pairs_count:
		## Затримка для celebration анімації перед victory
		var delay: float = 0.15 if SettingsManager.reduced_motion \
			else CELEBRATION_MEET_DUR + CELEBRATION_HUG_DUR + 0.3
		var tw: Tween = _create_game_tween()
		tw.tween_interval(delay)
		tw.tween_callback(_play_victory)
	else:
		_input_locked = false
		_reset_idle_timer()


## ---------- Pair celebration: тварини "зустрічаються" ----------

func _play_pair_celebration(card_a: Node2D, card_b: Node2D) -> void:
	if not is_instance_valid(card_a) or not is_instance_valid(card_b):
		push_warning("MemoryCards: card freed before celebration")
		return

	var animal_name: String = card_a.card_id
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if not ResourceLoader.exists(tex_path):
		push_warning("MemoryCards: celebration sprite missing: " + tex_path)
		return
	var tex: Texture2D = load(tex_path)
	if not tex:
		push_warning("MemoryCards: celebration texture load failed: " + tex_path)
		return

	var midpoint: Vector2 = (card_a.global_position + card_b.global_position) * 0.5

	## Спавн двох тварин — "вибігають" з карток до центру
	var sprite_a: Sprite2D = Sprite2D.new()
	sprite_a.texture = tex
	sprite_a.scale = Vector2(0.18, 0.18)
	sprite_a.global_position = card_a.global_position
	sprite_a.modulate.a = 0.0
	sprite_a.z_index = 5
	add_child(sprite_a)
	_celebration_nodes.append(sprite_a)

	var sprite_b: Sprite2D = Sprite2D.new()
	sprite_b.texture = tex
	sprite_b.scale = Vector2(0.18, 0.18)
	sprite_b.flip_h = true  ## Дзеркально — дивляться одне на одне
	sprite_b.global_position = card_b.global_position
	sprite_b.modulate.a = 0.0
	sprite_b.z_index = 5
	add_child(sprite_b)
	_celebration_nodes.append(sprite_b)

	if SettingsManager.reduced_motion:
		sprite_a.global_position = midpoint + Vector2(-20.0, 0.0)
		sprite_b.global_position = midpoint + Vector2(20.0, 0.0)
		sprite_a.modulate.a = 1.0
		sprite_b.modulate.a = 1.0
		## Зникнення після паузи
		var fade_tw: Tween = _create_game_tween()
		fade_tw.tween_interval(0.8)
		fade_tw.tween_callback(func() -> void:
			if is_instance_valid(sprite_a):
				sprite_a.queue_free()
			if is_instance_valid(sprite_b):
				sprite_b.queue_free()
		)
		return

	## Фаза 1: вибігають до midpoint
	var tw_a: Tween = _create_game_tween().set_parallel(true)
	tw_a.tween_property(sprite_a, "global_position",
		midpoint + Vector2(-20.0, 0.0), CELEBRATION_MEET_DUR) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_a.tween_property(sprite_a, "modulate:a", 1.0, 0.15)
	tw_a.tween_property(sprite_a, "scale",
		Vector2(0.24, 0.24), CELEBRATION_MEET_DUR) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var tw_b: Tween = _create_game_tween().set_parallel(true)
	tw_b.tween_property(sprite_b, "global_position",
		midpoint + Vector2(20.0, 0.0), CELEBRATION_MEET_DUR) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_b.tween_property(sprite_b, "modulate:a", 1.0, 0.15)
	tw_b.tween_property(sprite_b, "scale",
		Vector2(0.24, 0.24), CELEBRATION_MEET_DUR) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	## Фаза 2: "обійми" — bounce до одне одного і назад + серця
	tw_a.chain().tween_property(sprite_a, "global_position",
		midpoint + Vector2(-5.0, 0.0), CELEBRATION_HUG_DUR * 0.3) \
		.set_trans(Tween.TRANS_SINE)
	tw_a.tween_property(sprite_a, "global_position",
		midpoint + Vector2(-18.0, -10.0), CELEBRATION_HUG_DUR * 0.4) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw_a.tween_callback(func() -> void:
		if is_instance_valid(sprite_a):
			VFXManager.spawn_match_sparkle(midpoint)
	)

	tw_b.chain().tween_property(sprite_b, "global_position",
		midpoint + Vector2(5.0, 0.0), CELEBRATION_HUG_DUR * 0.3) \
		.set_trans(Tween.TRANS_SINE)
	tw_b.tween_property(sprite_b, "global_position",
		midpoint + Vector2(18.0, -10.0), CELEBRATION_HUG_DUR * 0.4) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	## Фаза 3: зникнення після "зустрічі"
	tw_a.tween_property(sprite_a, "modulate:a", 0.0, 0.3)
	tw_a.tween_callback(func() -> void:
		if is_instance_valid(sprite_a):
			sprite_a.queue_free()
	)
	tw_b.tween_property(sprite_b, "modulate:a", 0.0, 0.3)
	tw_b.tween_callback(func() -> void:
		if is_instance_valid(sprite_b):
			sprite_b.queue_free()
	)


## ---------- Mismatch handling ----------

func _handle_mismatch() -> void:
	if _is_toddler_mode:
		_handle_mismatch_toddler()
	else:
		_handle_mismatch_preschool()


func _handle_mismatch_toddler() -> void:
	## М'який фідбек без штрафу (A6), але з scaffolding (A11)
	_register_error(_flipped[0])
	_flipped[0].set_highlighted(false)
	_flipped[1].set_highlighted(false)
	_flipped.clear()
	_input_locked = false
	_reset_idle_timer()


func _handle_mismatch_preschool() -> void:
	_errors += 1
	_register_error(_flipped[0])

	## Gentle red flash + shake (LAW 28 — м'який, не агресивний)
	if not SettingsManager.reduced_motion:
		for card: Node2D in _flipped:
			## Червоний flash (0.2s)
			var flash_tw: Tween = _create_game_tween()
			flash_tw.tween_property(card, "modulate",
				Color(1.3, 0.85, 0.85, 1.0), 0.1)
			flash_tw.tween_property(card, "modulate", Color.WHITE, 0.15)
			## Shake
			var orig_x: float = card.position.x
			var tw_shake: Tween = _create_game_tween()
			tw_shake.tween_property(card, "position:x", orig_x - 5.0, 0.06)
			tw_shake.tween_property(card, "position:x", orig_x + 5.0, 0.06)
			tw_shake.tween_property(card, "position:x", orig_x - 2.5, 0.05)
			tw_shake.tween_property(card, "position:x", orig_x, 0.05)

	## Пауза — дитина запам'ятовує позиції
	var d2: float = 0.15 if SettingsManager.reduced_motion else _peek_duration
	var tw: Tween = _create_game_tween()
	tw.tween_interval(d2)
	tw.tween_callback(func() -> void:
		if _flipped.size() < 2:
			push_warning("MemoryCards: _flipped < 2 при flip_down")
			return
		if is_instance_valid(_flipped[0]):
			_flipped[0].flip_down()
		if is_instance_valid(_flipped[1]):
			_flipped[1].flip_down()
	)
	tw.tween_interval(MemoryCard.FLIP_HALF_DUR * 2.0 + 0.05)
	tw.tween_callback(func() -> void:
		_flipped.clear()
		_input_locked = false
		_reset_idle_timer()
	)


## ---------- Victory sequence ----------

func _play_victory() -> void:
	_input_locked = true
	var vp: Vector2 = get_viewport().get_visible_rect().size

	## Premium celebration (LAW 28) — багатошарове святкування
	VFXManager.spawn_premium_celebration(vp * 0.5)

	## Картки танцюють по черзі з golden glow
	if not SettingsManager.reduced_motion:
		for i: int in range(_cards.size()):
			var card: Node2D = _cards[i]
			if not is_instance_valid(card):
				continue
			var delay: float = float(i) * VICTORY_STAGGER
			var tw: Tween = _create_game_tween()
			tw.tween_interval(delay)
			## Golden flash per card
			tw.tween_property(card, "modulate",
				Color(1.2, 1.1, 0.7, 1.0), 0.08)
			tw.tween_property(card, "scale",
				Vector2(1.15, 0.85), 0.08)
			tw.tween_property(card, "scale",
				Vector2(0.9, 1.1), 0.08)
			tw.tween_property(card, "modulate",
				MemoryCard.MATCHED_TINT, 0.1)
			tw.tween_property(card, "scale",
				MemoryCard.MATCHED_SCALE, 0.12) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	## Фініш або наступний раунд після танцю
	var d3: float = 0.15 if SettingsManager.reduced_motion \
		else float(_cards.size()) * VICTORY_STAGGER + 0.8
	var finish_tw: Tween = _create_game_tween()
	finish_tw.tween_interval(d3)
	finish_tw.tween_callback(_advance_round)


## ---------- Idle hint (A10: 3-level escalation) ----------

func _reset_idle_timer() -> void:
	if _game_over:
		push_warning("MemoryCards: idle timer reset ignored — game over")
		return
	if _idle_timer and _idle_timer.time_left > 0:
		if _idle_timer.timeout.is_connected(_show_idle_hint):
			_idle_timer.timeout.disconnect(_show_idle_hint)
	_idle_timer = get_tree().create_timer(IDLE_HINT_DELAY)
	_idle_timer.timeout.connect(_show_idle_hint)


func _show_idle_hint() -> void:
	if _input_locked or _matched_count >= _pairs_count:
		push_warning("MemoryCards: idle hint skipped — input locked or all matched")
		return
	var level: int = _advance_idle_hint()

	## Знайти першу непройдену пару для підказки
	var hint_id: String = ""
	for card: Node2D in _cards:
		if not card.is_matched:
			hint_id = card.card_id
			break
	if hint_id.is_empty():
		return

	if level >= 2:
		## A10 Lvl2: tutorial hand — виділити валідну пару яскраво
		for card: Node2D in _cards:
			if card.card_id == hint_id and not card.is_matched:
				_pulse_node(card, 1.3)
				## Яскравий golden flash
				if not SettingsManager.reduced_motion:
					var flash_tw: Tween = _create_game_tween()
					flash_tw.tween_property(card, "modulate",
						Color(1.5, 1.3, 0.7, 1.0), 0.15)
					flash_tw.tween_property(card, "modulate",
						Color.WHITE, 0.3)
		_reset_idle_timer()
		return

	## Lvl 0-1: пульсувати обидві картки пари
	for card: Node2D in _cards:
		if card.card_id == hint_id and not card.is_matched:
			_pulse_node(card, 1.15)
	_reset_idle_timer()


## ---------- Index picker (unique animals per round) ----------

func _pick_random_indices(count: int) -> Array[int]:
	var pool_size: int = GameData.ANIMALS_AND_FOOD.size()
	if pool_size <= 0:
		push_warning("MemoryCards: ANIMALS_AND_FOOD порожній")
		return []
	var all: Array[int] = []
	for i: int in pool_size:
		if not _used_indices.has(i):
			all.append(i)
	all.shuffle()
	if all.size() < count:
		_used_indices.clear()
		all.clear()
		for i: int in pool_size:
			all.append(i)
		all.shuffle()
	var picked: Array[int] = []
	for i: int in mini(count, all.size()):
		picked.append(all[i])
		_used_indices.append(all[i])
	return picked


## ---------- Hiding spot drawing (inner class) ----------
class _HidingSpotNode extends Node2D:
	var spot_type: int = 0  ## HidingSpot enum value

	func _draw() -> void:
		var hw: float = MemoryCard.CARD_WIDTH * 0.5
		var hh: float = MemoryCard.CARD_HEIGHT * 0.5

		match spot_type:
			0:  ## TREE — зелений трикутник + коричневий стовбур
				## Стовбур
				var trunk_color: Color = Color("8B5E3C")
				draw_rect(Rect2(-8.0, 10.0, 16.0, hh - 15.0), trunk_color)
				## Крона — три шари зеленого
				var green: Color = Color("3d8c3d")
				var pts_bottom: PackedVector2Array = PackedVector2Array([
					Vector2(-hw * 0.8, 15.0),
					Vector2(hw * 0.8, 15.0),
					Vector2(0.0, -hh * 0.3)])
				draw_colored_polygon(pts_bottom, green.darkened(0.1))
				var pts_mid: PackedVector2Array = PackedVector2Array([
					Vector2(-hw * 0.65, -5.0),
					Vector2(hw * 0.65, -5.0),
					Vector2(0.0, -hh * 0.6)])
				draw_colored_polygon(pts_mid, green)
				var pts_top: PackedVector2Array = PackedVector2Array([
					Vector2(-hw * 0.45, -25.0),
					Vector2(hw * 0.45, -25.0),
					Vector2(0.0, -hh * 0.85)])
				draw_colored_polygon(pts_top, green.lightened(0.1))

			1:  ## BUSH — зелений еліпс з варіаціями
				var bush_color: Color = Color("5aad5a")
				## Основний кущ — кілька кіл
				draw_circle(Vector2(0.0, 5.0), hw * 0.6, bush_color)
				draw_circle(Vector2(-hw * 0.3, -5.0), hw * 0.45, bush_color.lightened(0.08))
				draw_circle(Vector2(hw * 0.3, -5.0), hw * 0.45, bush_color.lightened(0.05))
				draw_circle(Vector2(0.0, -20.0), hw * 0.35, bush_color.lightened(0.12))
				## Стебло
				draw_rect(Rect2(-4.0, hw * 0.4, 8.0, 20.0), Color("6B4226"))

			2:  ## ROCK — сірий округлий камінь
				var rock_color: Color = Color("8c8c8c")
				## Основний камінь — еліпс знизу
				draw_circle(Vector2(0.0, 10.0), hw * 0.7, rock_color)
				## Верхня частина — світліша
				draw_circle(Vector2(-5.0, -10.0), hw * 0.5, rock_color.lightened(0.1))
				## Блік
				draw_circle(Vector2(-hw * 0.25, -hw * 0.2),
					hw * 0.15, Color(1, 1, 1, 0.2))

			3:  ## FLOWER — великий квітка
				var petal_color: Color = Color("e88cbc")
				var center_color: Color = Color("FFD700")
				## Пелюстки — 6 кіл навколо центру
				var petal_r: float = hw * 0.35
				var dist: float = hw * 0.32
				for i: int in 6:
					var angle: float = float(i) * TAU / 6.0
					var px: float = cos(angle) * dist
					var py: float = sin(angle) * dist - 5.0
					var c: Color = petal_color.lightened(
						0.05 * float(i % 3))
					draw_circle(Vector2(px, py), petal_r, c)
				## Центр квітки
				draw_circle(Vector2(0.0, -5.0), hw * 0.22, center_color)
				## Стебло
				draw_rect(Rect2(-3.0, hw * 0.4, 6.0, hh - 10.0),
					Color("4a8c3d"))


