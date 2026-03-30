class_name BaseMiniGame
extends Node2D

## Базовий клас для всіх міні-ігор платформи.
## Програмно створює UI-оверлей: кнопка «Назад», лічильник зірок, пауза.
## Дочірні класи перевизначають get_tutorial_instruction() та ігрову логіку.

signal finished(stats: Dictionary)

const LEVEL_COMPLETE_SCENE: PackedScene = preload(
	"res://scenes/ui/level_complete_overlay.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload(
	"res://scenes/ui/pause_menu.tscn")
const HUB_PATH: String = "res://scenes/ui/game_hub.tscn"
const REFERENCE_HEIGHT: float = 800.0
const TODDLER_SCALE: float = 1.4
const TODDLER_SNAP_RADIUS: float = 140.0  ## NNGroup: 2-3yo need 2cm+ touch targets
## Стандартизовані тривалості анімацій — замість магічних чисел по всіх іграх
const ANIM_FAST: float = 0.15
const ANIM_NORMAL: float = 0.3
const ANIM_SLOW: float = 0.5
const ROUND_DELAY: float = 0.8
const CELEBRATION_DELAY: float = 1.2

var game_id: String = ""
var _skill_id: String = ""  ## MasteryManager: навичка, що тренується (встановлюється дочірнім класом)
var _current_animal_name: String = ""  ## Ім'я тварини для стікерів (встановлюється дочірнім класом)
var difficulty_level: int = 1
var bg_theme: String = "default"
var _game_finished: bool = false
var _ui_layer: CanvasLayer = null
var _star_label: Label = null
var _pause_menu: CanvasLayer = null
var _exit_confirm: ExitConfirmOverlay = null
var _tutorial_sys: TutorialSystem = null
var _instruction_label: Label = null
var _sa_top: float = 0.0  ## Safe area top inset (для пристроїв з нотчем)
var _idle_hint_level: int = 0
var _consecutive_errors: int = 0
var _streak_count: int = 0
var _active_tweens: Array[Tween] = []  ## Реєстр tweens для автоочистки
var _round_label_tween: Tween = null  ## Dedicated tween for round label bounce (spam-safe)
var _round_errors: Array[int] = []  ## Помилки по раундах для адаптивної складності (ZPD)
var _input_locked: bool = true  ## Блокування вводу під час анімацій (LAW 23)
var _bg_node: TextureRect = null  ## Посилання на Background для ripple shader
@warning_ignore("unused_private_class_variable")
var _game_over: bool = false  ## Прапорець завершення гри (використовується в дочірніх класах)
@warning_ignore("unused_private_class_variable")
var _errors: int = 0  ## Лічильник помилок гравця (використовується в дочірніх класах)
const STREAK_THRESHOLD: int = 3
## Музична лестниця: C-D-E-F-G-A-B — ascending pitch для streak серії
const PITCH_SCALE: Array[float] = [1.0, 1.122, 1.26, 1.335, 1.498, 1.682, 1.888]


func _ready() -> void:
	_game_over = false
	_errors = 0
	_sa_top = float(_get_safe_margins().position.y)
	## Тематичне BGM за типом гри (3 треки: animals, numbers, colors)
	var _bgm_map: Dictionary = {
		"meadow": "bgm_animals", "forest": "bgm_animals", "garden": "bgm_animals",
		"candy": "bgm_colors", "ocean": "bgm_colors", "sky": "bgm_colors",
		"city": "bgm_numbers", "science": "bgm_numbers", "puzzle": "bgm_numbers",
	}
	var bgm_track: String = _bgm_map.get(bg_theme, "bgm_loop")
	AudioManager.play_bgm(bgm_track)
	_build_ui_layer()
	_build_pause_menu()
	_build_exit_confirm()
	_setup_tutorial()
	_play_entrance_animation()
	## Deferred premium UI pass — runs after all children _ready() complete
	get_tree().process_frame.connect(_deferred_premium_ui_pass, CONNECT_ONE_SHOT)


func _physics_process(_delta: float) -> void:
	pass


func _build_ui_layer() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	var s: float = _ui_scale()
	var sa: Rect2i = _get_safe_margins()
	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = float(sa.position.y)
	top_bar.offset_left = float(sa.position.x)
	top_bar.offset_right = -float(sa.size.x)
	top_bar.offset_bottom = float(sa.position.y) + 64.0 * s
	top_bar.set("theme_override_constants/separation", int(12.0 * s))

	## Кнопка «Назад» з іконкою стрілки — glass circle
	var back_btn: Button = Button.new()
	back_btn.theme_type_variation = &"CircleButton"
	back_btn.custom_minimum_size = Vector2(64.0 * s, 64.0 * s)
	back_btn.text = ""
	back_btn.pressed.connect(_on_back_pressed)
	IconDraw.icon_in_button(back_btn, IconDraw.arrow_left(28.0 * s))
	top_bar.add_child(back_btn)
	JuicyEffects.button_press_squish(back_btn, self)
	JuicyEffects.button_hover_scale(back_btn, self)

	## Кнопка «Пауза» — glass circle з двома білими смужками
	var pause_btn: Button = Button.new()
	pause_btn.theme_type_variation = &"CircleButton"
	pause_btn.custom_minimum_size = Vector2(64.0 * s, 64.0 * s)
	pause_btn.text = ""
	pause_btn.pressed.connect(func() -> void:
		if not _game_finished and _pause_menu:
			AudioManager.play_sfx("click")
			_pause_menu.show_pause()
	)
	var pause_center: CenterContainer = CenterContainer.new()
	pause_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pause_bars: HBoxContainer = HBoxContainer.new()
	pause_bars.set("theme_override_constants/separation", int(6.0 * s))
	pause_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _i: int in 2:
		var bar: ColorRect = ColorRect.new()
		bar.custom_minimum_size = Vector2(6.0 * s, 24.0 * s)
		bar.color = Color.WHITE
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pause_bars.add_child(bar)
	pause_center.add_child(pause_bars)
	pause_btn.add_child(pause_center)
	top_bar.add_child(pause_btn)
	JuicyEffects.button_press_squish(pause_btn, self)
	JuicyEffects.button_hover_scale(pause_btn, self)

	## Спейсер — розтягує простір між кнопками і зірками
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	## Лічильник зірок — праворуч (золотиста pill: іконка + число)
	var star_pill: PanelContainer = PanelContainer.new()
	star_pill.add_theme_stylebox_override("panel", GameData.star_pill())
	var star_bar: HBoxContainer = HBoxContainer.new()
	star_bar.set("theme_override_constants/separation", int(6.0 * s))
	star_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	var star_icon: Control = IconDraw.star_5pt(28.0 * s)
	star_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_bar.add_child(star_icon)
	_star_label = Label.new()
	_star_label.text = str(ProgressManager.stars)
	_star_label.add_theme_font_size_override("font_size", int(28.0 * s))
	star_bar.add_child(_star_label)
	star_pill.add_child(star_bar)
	top_bar.add_child(star_pill)

	## Grain overlay на UI (LAW 28 — premium texture)
	top_bar.material = GameData.create_premium_material(
		0.02, 2.0, 0.06, 0.08, 0.0, 0.04, 0.0, "", 0.0, 0.08, 0.18, 0.15)
	_ui_layer.add_child(top_bar)
	## NOTE: _instruction_label НЕ створюється тут — кожна гра створює свій
	## у _build_hud() з потрібним позиціонуванням. Раніше тут створювався
	## дублікат на CanvasLayer 10, що накладався на label гри (25/30 ігор).


var _round_label: Label = null
var _instruction_pill: PanelContainer = null


## Централізована pill для інструкції + раунду — замінює дубльований код у 25 іграх.
## Дочірні класи викликають у _build_hud() замість 10-15 рядків ручного UI.
func _build_instruction_pill(text: String = "", font_size: int = 24) -> void:
	var s: float = _ui_scale()
	_instruction_pill = PanelContainer.new()
	_instruction_pill.add_theme_stylebox_override("panel", GameData.instruction_pill())
	_instruction_pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_instruction_pill.offset_top = _sa_top + 72.0 * s

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set("theme_override_constants/separation", int(2.0 * s))
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_instruction_pill.add_child(vbox)

	_instruction_label = Label.new()
	_instruction_label.add_theme_font_size_override("font_size", int(float(font_size) * s))
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_instruction_label)

	_round_label = Label.new()
	_round_label.add_theme_font_size_override("font_size", int(24.0 * s))
	_round_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_round_label)

	## Grain overlay на instruction pill (LAW 28)
	_instruction_pill.material = GameData.create_premium_material(
		0.02, 2.0, 0.04, 0.06, 0.0, 0.05, 0.0, "", 0.0, 0.08, 0.18, 0.15)
	_ui_layer.add_child(_instruction_pill)
	## Text reveal — typewriter effect після додавання до дерева
	JuicyEffects.text_reveal(_instruction_label, text, self)


func _build_pause_menu() -> void:
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	_pause_menu.quit_scene = HUB_PATH
	add_child(_pause_menu)


func _build_exit_confirm() -> void:
	_exit_confirm = ExitConfirmOverlay.new()
	_exit_confirm.confirmed_exit.connect(func() -> void:
		SceneManager.goto_scene(HUB_PATH))
	add_child(_exit_confirm)


func _on_back_pressed() -> void:
	if _game_finished:
		push_warning("BaseMiniGame: _on_back_pressed ignored — game already finished")
		return
	AudioManager.play_sfx("click")
	_on_exit_pause()  ## Virtual hook — дочірні класи очищують стан перед паузою
	if _exit_confirm:
		_exit_confirm.show_dialog()
	else:
		SceneManager.goto_scene(HUB_PATH)


## Дочірні класи override для очищення стану при паузі (exit confirm).
## Вирішує deadlock: tween заморожений через get_tree().paused = true,
## callback ніколи не спрацює, _executing = true назавжди.
func _on_exit_pause() -> void:
	pass


func _setup_tutorial() -> void:
	_tutorial_sys = TutorialSystem.new()
	add_child(_tutorial_sys)
	_tutorial_sys.setup(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT \
			or what == NOTIFICATION_APPLICATION_PAUSED:
		if not _game_finished and _pause_menu:
			_pause_menu.show_pause()


func _exit_tree() -> void:
	## Гарантуємо відновлення time_scale при виході зі сцени (hit-stop safety net)
	if not is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _game_finished:
		if _pause_menu:
			_pause_menu.show_pause()
		get_viewport().set_input_as_handled()


## Завершити гру — зберегти зірки, показати оверлей, конфетті.
func finish_game(earned_stars: int, stats: Dictionary = {}) -> void:
	if _game_finished:
		return
	_game_finished = true
	_kill_all_tweens()

	## Зберегти прогрес
	ProgressManager.mark_game_played(game_id)
	if earned_stars > 0:
		ProgressManager.add_stars(earned_stars)
	var quest_done: bool = ProgressManager.increment_games_played()

	## UX-03: Тост досягнення — щоденний квест
	if quest_done:
		_show_achievement_toast(tr("MSG_QUEST_COMPLETE"))

	var time_sec: int = int(stats.get("time_sec", 9999))
	var errors: int = int(stats.get("errors", 9999))
	ProgressManager.check_new_record(time_sec, errors)

	## Стікер-нагорода: 3+ зірки + тварина задана -> earn_sticker
	if earned_stars >= 3 and not _current_animal_name.is_empty():
		var is_new_sticker: bool = ProgressManager.earn_sticker(
			_current_animal_name, game_id, earned_stars)
		if is_new_sticker:
			_show_achievement_toast(tr("MSG_NEW_STICKER"))

	## Святковий вібровідгук (research: celebration pattern 400+200+400мс)
	HapticsManager.vibrate_celebration()

	## Аналітика
	AnalyticsManager.log_level_complete(
		int(stats.get("rounds_played", 0)),
		float(stats.get("time_sec", 0.0)),
		errors
	)

	## Оновити лічильник зірок з анімацією
	if _star_label:
		var old_stars: int = ProgressManager.stars - earned_stars
		_star_label.text = str(old_stars)
		_star_label.pivot_offset = _star_label.size / 2.0
		if earned_stars > 0:
			if SettingsManager.reduced_motion:
				if is_instance_valid(_star_label):
					_star_label.text = str(ProgressManager.stars)
			else:
				var count_up: Callable = func(val: float) -> void:
					if is_instance_valid(_star_label):
						_star_label.text = str(int(val))
				var stw: Tween = create_tween()
				stw.tween_method(count_up, float(old_stars),
					float(ProgressManager.stars), 0.5).set_delay(1.5)
				stw.tween_property(_star_label, "scale", Vector2(1.3, 1.3), 0.1)
				stw.tween_property(_star_label, "scale", Vector2.ONE, 0.15)\
					.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	## Сигнал
	finished.emit(stats)

	## Золотий flash — wow-момент при перемозі
	if earned_stars > 0 and _ui_layer \
			and not (SettingsManager and SettingsManager.reduced_motion):
		var flash: ColorRect = ColorRect.new()
		flash.color = Color(1.0, 0.95, 0.7, 0.15)
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui_layer.add_child(flash)
		var ftw: Tween = create_tween()
		ftw.tween_property(flash, "color:a", 0.0, 0.3)
		ftw.finished.connect(flash.queue_free)
		## Victory shake — масштабується за зірками
		if earned_stars >= 1:
			JuicyEffects.screen_shake(self, 2.0 + float(earned_stars))
		var vp: Vector2 = get_viewport().get_visible_rect().size
		if earned_stars >= 2:
			VFXManager.spawn_correct_sparkle(vp / 2.0)
		if earned_stars >= 3:
			VFXManager.spawn_golden_burst(vp / 2.0)
		if earned_stars >= 4:
			VFXManager.spawn_firework_fountain(Vector2(vp.x * 0.3, vp.y * 0.6))
			VFXManager.spawn_firework_fountain(Vector2(vp.x * 0.7, vp.y * 0.6))
		if earned_stars >= 5:
			VFXManager.spawn_rainbow_ring(vp / 2.0)
			VFXManager.spawn_premium_confetti_rain(vp)

	## Каскадний SFX зірок перед overlay — build-up ефект
	var delay: float = 0.0
	if earned_stars > 0:
		for i: int in mini(earned_stars, 5):
			get_tree().create_timer(0.08 * float(i)).timeout.connect(
				func() -> void: AudioManager.play_sfx_varied("star", 0.12))
		delay = 0.08 * float(mini(earned_stars, 5)) + 0.15

	## Показати оверлей з затримкою для build-up
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		var overlay: CanvasLayer = LEVEL_COMPLETE_SCENE.instantiate()
		add_child(overlay)
		overlay.show_results(earned_stars)
	)


## V168: Per-game ілюстрований фон — окремі ігри використовують інший PNG ніж їх тема.
## Це дозволяє кожній грі мати унікальний фон навіть при спільній темі.
## Ключ = game_id, значення = суфікс файлу bg_{value}.png (або .jpg).
const _BG_GAME_THEME_OVERRIDE: Dictionary = {
	"forest_orchestra": "forest_night",   ## Зачарований ліс для нічного оркестру
	"smart_coloring": "sunset",           ## Магічний сутінковий ліс для мистецтва
	"analog_clock": "arctic_village",     ## Затишне село — структурований час
	"cash_register": "arctic_night",      ## Нічний ярмарок — покупки
	"knight_path": "forest_night",        ## Зачарований ліс — квест лицаря
	"hygiene": "underwater",              ## Підводний світ — вода і чистота
	"safe_maze": "castle",                ## Замок — пригодницький лабіринт
	"sensory_sandbox": "beach",           ## Пляж — вільне малювання на піску
}


## Premium 5-точкові градієнти для 12 тем фону.
## Кожен масив: [top, 0.25, 0.5, 0.75, bottom] для багатого градієнту.
const BG_THEME_GRADIENTS: Dictionary = {
	"default": [Color("b8f0a0"), Color("8edb6a"), Color("6cc44a"), Color("55a835"), Color("3d8c1f")],
	"meadow": [Color("b8f0a0"), Color("8edb6a"), Color("6cc44a"), Color("55a835"), Color("3d8c1f")],
	"forest": [Color("6bc88e"), Color("4a9f6e"), Color("2d6a4f"), Color("1e5038"), Color("132e20")],
	"ocean": [Color("c0e8ff"), Color("80c8f0"), Color("4aa8e0"), Color("2580c0"), Color("1560a0")],
	"science": [Color("f0e6ff"), Color("d4baf0"), Color("b88edd"), Color("8c6abf"), Color("5c3d99")],
	"space": [Color("3a4878"), Color("2a3660"), Color("1b2548"), Color("111a35"), Color("080e1e")],
	"city": [Color("fff8ed"), Color("ffe8c8"), Color("ffd4a0"), Color("e8b880"), Color("c49060")],
	"puzzle": [Color("f0e4ff"), Color("dcc8f5"), Color("c4a8e8"), Color("a888d8"), Color("8866c8")],
	"music": [Color("fff6e0"), Color("ffe4b0"), Color("ffd080"), Color("e8a860"), Color("c88040")],
	"garden": [Color("ffeef0"), Color("ffc8d0"), Color("f0a0b0"), Color("d88898"), Color("b87080")],
	"candy": [Color("fff0f8"), Color("ffe0cc"), Color("ffd0a0"), Color("f0b888"), Color("e0a070")],
	"arctic": [Color("e8f4ff"), Color("c0ddf5"), Color("98c8ea"), Color("78b0d8"), Color("5898c8")],
	"sunset": [Color("ffd4a0"), Color("ff9060"), Color("e86050"), Color("b84070"), Color("682878")],
	"castle": [Color("b8f0a0"), Color("90d870"), Color("60c050"), Color("48a838"), Color("308020")],
	"beach": [Color("c0e8ff"), Color("a0d8f0"), Color("f0e8a0"), Color("e8d080"), Color("d0b060")],
}

## Параметри шейдера bg_animated для кожної теми.
const BG_SHADER_PARAMS: Dictionary = {
	"meadow": {"bokeh_count": 4.0, "bokeh_size": 0.08, "bokeh_intensity": 0.22,
		"bokeh_color": Color(1, 1, 0.9, 0.18), "bokeh_color_2": Color(0.95, 0.9, 0.5, 0.15),
		"bokeh_speed": 0.15, "gradient_shift": 0.015, "gradient_speed": 0.4,
		"vignette_strength": 0.12, "chromatic_aberration": 0.008,
		"pattern_type": 1, "pattern_intensity": 0.04, "pattern_scale": 20.0,
		"theme_id": 0, "detail_intensity": 0.08, "detail_scale": 15.0, "detail_speed": 0.15,
		"detail_color": Color(1, 1, 0.8, 0.12),
		"highlight_pos": Vector2(0.82, 0.08), "highlight_radius": 0.25, "highlight_intensity": 0.12,
		"highlight_color": Color(1, 1, 0.7, 0.2), "horizon_glow": 0.05, "horizon_y": 0.85,
		"horizon_color": Color(0.8, 1, 0.6, 0.1)},
	"forest": {"bokeh_count": 3.0, "bokeh_size": 0.06, "bokeh_intensity": 0.20,
		"bokeh_color": Color(0.56, 0.93, 0.56, 0.20), "bokeh_color_2": Color(0.8, 1, 0.6, 0.15),
		"bokeh_speed": 0.1, "gradient_shift": 0.01, "gradient_speed": 0.3,
		"vignette_strength": 0.15, "chromatic_aberration": 0.010,
		"pattern_type": 0, "pattern_intensity": 0.03, "pattern_scale": 20.0,
		"theme_id": 1, "detail_intensity": 0.10, "detail_scale": 8.0, "detail_speed": 0.08,
		"detail_color": Color(1, 0.95, 0.6, 0.15),
		"highlight_pos": Vector2(0.75, 0.10), "highlight_radius": 0.20, "highlight_intensity": 0.08,
		"highlight_color": Color(1, 1, 0.7, 0.15), "horizon_glow": 0.04, "horizon_y": 0.82,
		"horizon_color": Color(0.5, 0.8, 0.4, 0.08)},
	"ocean": {"bokeh_count": 6.0, "bokeh_size": 0.07, "bokeh_intensity": 0.25,
		"bokeh_color": Color(1, 1, 1, 0.22), "bokeh_color_2": Color(0.5, 0.9, 1, 0.18),
		"bokeh_speed": 0.12, "gradient_shift": 0.015, "gradient_speed": 0.35,
		"vignette_strength": 0.10, "chromatic_aberration": 0.006,
		"pattern_type": 2, "pattern_intensity": 0.08, "pattern_scale": 12.0,
		"theme_id": 2, "detail_intensity": 0.12, "detail_scale": 10.0, "detail_speed": 0.20,
		"detail_color": Color(0.7, 0.9, 1, 0.15),
		"highlight_pos": Vector2(0.80, 0.05), "highlight_radius": 0.30, "highlight_intensity": 0.10,
		"highlight_color": Color(1, 1, 0.9, 0.18), "horizon_glow": 0.08, "horizon_y": 0.70,
		"horizon_color": Color(0.8, 0.95, 1, 0.12)},
	"science": {"bokeh_count": 6.0, "bokeh_size": 0.06, "bokeh_intensity": 0.24,
		"bokeh_color": Color(0.85, 0.71, 0.99, 0.20), "bokeh_color_2": Color(0.6, 0.4, 1, 0.15),
		"bokeh_speed": 0.12, "gradient_shift": 0.012, "gradient_speed": 0.35,
		"vignette_strength": 0.12, "chromatic_aberration": 0.008,
		"pattern_type": 1, "pattern_intensity": 0.06, "pattern_scale": 25.0,
		"theme_id": 3, "detail_intensity": 0.06, "detail_scale": 20.0, "detail_speed": 0.10,
		"detail_color": Color(0.8, 0.6, 1, 0.10),
		"highlight_pos": Vector2(0.50, 0.50), "highlight_radius": 0.35, "highlight_intensity": 0.06,
		"highlight_color": Color(0.8, 0.7, 1, 0.12), "horizon_glow": 0.0, "horizon_y": 0.75,
		"horizon_color": Color(1, 1, 1, 0.1)},
	"space": {"bokeh_count": 8.0, "bokeh_size": 0.04, "bokeh_intensity": 0.30,
		"bokeh_color": Color(1.0, 0.93, 0.73, 0.25), "bokeh_color_2": Color(0.6, 0.5, 1, 0.20),
		"bokeh_speed": 0.08, "gradient_shift": 0.008, "gradient_speed": 0.2,
		"vignette_strength": 0.20, "chromatic_aberration": 0.015,
		"pattern_type": 0, "pattern_intensity": 0.0, "pattern_scale": 20.0,
		"theme_id": 4, "detail_intensity": 0.15, "detail_scale": 30.0, "detail_speed": 0.05,
		"detail_color": Color(1, 1, 1, 0.20),
		"highlight_pos": Vector2(0.50, 0.50), "highlight_radius": 0.0, "highlight_intensity": 0.0,
		"highlight_color": Color(1, 1, 1, 0.1), "horizon_glow": 0.0, "horizon_y": 0.75,
		"horizon_color": Color(1, 1, 1, 0.1)},
	"city": {"bokeh_count": 4.0, "bokeh_size": 0.07, "bokeh_intensity": 0.20,
		"bokeh_color": Color(1, 0.94, 0.85, 0.16), "bokeh_color_2": Color(1, 0.85, 0.6, 0.14),
		"bokeh_speed": 0.12, "gradient_shift": 0.012, "gradient_speed": 0.35,
		"vignette_strength": 0.10, "chromatic_aberration": 0.006,
		"pattern_type": 0, "pattern_intensity": 0.04, "pattern_scale": 20.0,
		"theme_id": 5, "detail_intensity": 0.10, "detail_scale": 12.0, "detail_speed": 0.0,
		"detail_color": Color(0.2, 0.15, 0.3, 0.25),
		"highlight_pos": Vector2(0.85, 0.06), "highlight_radius": 0.25, "highlight_intensity": 0.08,
		"highlight_color": Color(1, 1, 0.8, 0.15), "horizon_glow": 0.06, "horizon_y": 0.78,
		"horizon_color": Color(1, 0.9, 0.7, 0.10)},
	"puzzle": {"bokeh_count": 5.0, "bokeh_size": 0.07, "bokeh_intensity": 0.22,
		"bokeh_color": Color(0.77, 0.71, 0.99, 0.18), "bokeh_color_2": Color(0.9, 0.6, 1, 0.15),
		"bokeh_speed": 0.12, "gradient_shift": 0.012, "gradient_speed": 0.35,
		"vignette_strength": 0.12, "chromatic_aberration": 0.008,
		"pattern_type": 1, "pattern_intensity": 0.05, "pattern_scale": 20.0,
		"theme_id": 6, "detail_intensity": 0.06, "detail_scale": 8.0, "detail_speed": 0.12,
		"detail_color": Color(0.7, 0.5, 1, 0.10),
		"highlight_pos": Vector2(0.50, 0.50), "highlight_radius": 0.20, "highlight_intensity": 0.06,
		"highlight_color": Color(0.8, 0.7, 1, 0.12), "horizon_glow": 0.0, "horizon_y": 0.75,
		"horizon_color": Color(1, 1, 1, 0.1)},
	"music": {"bokeh_count": 5.0, "bokeh_size": 0.08, "bokeh_intensity": 0.24,
		"bokeh_color": Color(1.0, 0.82, 0.4, 0.20), "bokeh_color_2": Color(1, 0.6, 0.3, 0.16),
		"bokeh_speed": 0.12, "gradient_shift": 0.012, "gradient_speed": 0.35,
		"vignette_strength": 0.10, "chromatic_aberration": 0.006,
		"pattern_type": 2, "pattern_intensity": 0.06, "pattern_scale": 8.0,
		"theme_id": 7, "detail_intensity": 0.10, "detail_scale": 6.0, "detail_speed": 0.25,
		"detail_color": Color(1, 0.8, 0.3, 0.12),
		"highlight_pos": Vector2(0.50, 0.50), "highlight_radius": 0.20, "highlight_intensity": 0.06,
		"highlight_color": Color(1, 0.9, 0.5, 0.12), "horizon_glow": 0.0, "horizon_y": 0.75,
		"horizon_color": Color(1, 1, 1, 0.1)},
	"garden": {"bokeh_count": 6.0, "bokeh_size": 0.07, "bokeh_intensity": 0.24,
		"bokeh_color": Color(1.0, 0.75, 0.8, 0.20), "bokeh_color_2": Color(1, 0.5, 0.7, 0.16),
		"bokeh_speed": 0.12, "gradient_shift": 0.012, "gradient_speed": 0.35,
		"vignette_strength": 0.10, "chromatic_aberration": 0.006,
		"pattern_type": 1, "pattern_intensity": 0.06, "pattern_scale": 18.0,
		"theme_id": 8, "detail_intensity": 0.08, "detail_scale": 12.0, "detail_speed": 0.10,
		"detail_color": Color(1, 0.7, 0.8, 0.12),
		"highlight_pos": Vector2(0.80, 0.08), "highlight_radius": 0.22, "highlight_intensity": 0.08,
		"highlight_color": Color(1, 0.9, 0.8, 0.15), "horizon_glow": 0.04, "horizon_y": 0.85,
		"horizon_color": Color(1, 0.8, 0.7, 0.08)},
	"candy": {"bokeh_count": 7.0, "bokeh_size": 0.08, "bokeh_intensity": 0.28,
		"bokeh_color": Color(1.0, 0.56, 0.75, 0.22), "bokeh_color_2": Color(1, 0.8, 0.4, 0.18),
		"bokeh_speed": 0.15, "gradient_shift": 0.015, "gradient_speed": 0.4,
		"vignette_strength": 0.08, "chromatic_aberration": 0.005,
		"pattern_type": 1, "pattern_intensity": 0.07, "pattern_scale": 15.0,
		"theme_id": 9, "detail_intensity": 0.08, "detail_scale": 8.0, "detail_speed": 0.15,
		"detail_color": Color(1, 0.5, 0.7, 0.10),
		"highlight_pos": Vector2(0.50, 0.50), "highlight_radius": 0.18, "highlight_intensity": 0.06,
		"highlight_color": Color(1, 0.8, 0.9, 0.12), "horizon_glow": 0.0, "horizon_y": 0.75,
		"horizon_color": Color(1, 1, 1, 0.1)},
	"arctic": {"bokeh_count": 6.0, "bokeh_size": 0.06, "bokeh_intensity": 0.22,
		"bokeh_color": Color(1, 1, 1, 0.20), "bokeh_color_2": Color(0.8, 0.9, 1, 0.16),
		"bokeh_speed": 0.1, "gradient_shift": 0.01, "gradient_speed": 0.3,
		"vignette_strength": 0.10, "chromatic_aberration": 0.008,
		"pattern_type": 0, "pattern_intensity": 0.04, "pattern_scale": 20.0,
		"theme_id": 10, "detail_intensity": 0.12, "detail_scale": 20.0, "detail_speed": 0.12,
		"detail_color": Color(1, 1, 1, 0.15),
		"highlight_pos": Vector2(0.80, 0.06), "highlight_radius": 0.30, "highlight_intensity": 0.10,
		"highlight_color": Color(1, 1, 1, 0.18), "horizon_glow": 0.06, "horizon_y": 0.80,
		"horizon_color": Color(0.9, 0.95, 1, 0.10)},
	"sunset": {"bokeh_count": 6.0, "bokeh_size": 0.08, "bokeh_intensity": 0.26,
		"bokeh_color": Color(1.0, 0.85, 0.5, 0.22), "bokeh_color_2": Color(1, 0.5, 0.6, 0.18),
		"bokeh_speed": 0.12, "gradient_shift": 0.02, "gradient_speed": 0.3,
		"vignette_strength": 0.18, "chromatic_aberration": 0.012,
		"pattern_type": 2, "pattern_intensity": 0.05, "pattern_scale": 10.0,
		"theme_id": 11, "detail_intensity": 0.08, "detail_scale": 6.0, "detail_speed": 0.08,
		"detail_color": Color(1, 0.6, 0.3, 0.12),
		"highlight_pos": Vector2(0.50, 0.85), "highlight_radius": 0.35, "highlight_intensity": 0.18,
		"highlight_color": Color(1, 0.7, 0.4, 0.25), "horizon_glow": 0.12, "horizon_y": 0.80,
		"horizon_color": Color(1, 0.6, 0.3, 0.15)},
	"castle": {"bokeh_count": 4.0, "bokeh_size": 0.07, "bokeh_intensity": 0.20,
		"bokeh_color": Color(0.9, 1, 0.8, 0.18), "bokeh_color_2": Color(0.6, 0.95, 0.5, 0.15),
		"bokeh_speed": 0.12, "gradient_shift": 0.015, "gradient_speed": 0.35,
		"vignette_strength": 0.12, "chromatic_aberration": 0.008,
		"pattern_type": 0, "pattern_intensity": 0.03, "pattern_scale": 18.0,
		"theme_id": 0, "detail_intensity": 0.08, "detail_scale": 12.0, "detail_speed": 0.12,
		"detail_color": Color(0.9, 1, 0.7, 0.12),
		"highlight_pos": Vector2(0.80, 0.10), "highlight_radius": 0.22, "highlight_intensity": 0.10,
		"highlight_color": Color(1, 1, 0.8, 0.18), "horizon_glow": 0.04, "horizon_y": 0.85,
		"horizon_color": Color(0.6, 0.9, 0.5, 0.08)},
	"beach": {"bokeh_count": 5.0, "bokeh_size": 0.08, "bokeh_intensity": 0.22,
		"bokeh_color": Color(1, 1, 0.9, 0.20), "bokeh_color_2": Color(0.6, 0.9, 1, 0.16),
		"bokeh_speed": 0.14, "gradient_shift": 0.018, "gradient_speed": 0.35,
		"vignette_strength": 0.10, "chromatic_aberration": 0.008,
		"pattern_type": 1, "pattern_intensity": 0.04, "pattern_scale": 15.0,
		"theme_id": 3, "detail_intensity": 0.08, "detail_scale": 10.0, "detail_speed": 0.10,
		"detail_color": Color(1, 1, 0.8, 0.12),
		"highlight_pos": Vector2(0.50, 0.15), "highlight_radius": 0.28, "highlight_intensity": 0.12,
		"highlight_color": Color(1, 1, 0.7, 0.20), "horizon_glow": 0.06, "horizon_y": 0.70,
		"horizon_color": Color(0.3, 0.8, 1, 0.10)},
}

## Конфігурація частинок за темою — direction, gravity, amount, color.
const BG_PARTICLE_CONFIGS: Dictionary = {
	"meadow": {"amount": 8, "color": Color(0.6, 0.95, 0.3, 0.06),
		"direction": Vector2(0, -1), "gravity": Vector2(0, -15), "spread": 40.0},
	"forest": {"amount": 6, "color": Color(0.4, 0.8, 0.3, 0.08),
		"direction": Vector2(0, 1), "gravity": Vector2(0, 8), "spread": 50.0},
	"ocean": {"amount": 8, "color": Color(0.7, 0.9, 1.0, 0.08),
		"direction": Vector2(0, -1), "gravity": Vector2(0, -12), "spread": 30.0},
	"science": {"amount": 6, "color": Color(0.75, 0.6, 1.0, 0.1),
		"direction": Vector2(0, -1), "gravity": Vector2(0, -8), "spread": 60.0},
	"space": {"amount": 4, "color": Color(1.0, 0.95, 0.6, 0.12),
		"direction": Vector2(1, 0), "gravity": Vector2(0, 0), "spread": 90.0},
	"city": {"amount": 6, "color": Color(1.0, 0.95, 0.85, 0.06),
		"direction": Vector2(0, -1), "gravity": Vector2(0, -10), "spread": 40.0},
	"puzzle": {"amount": 6, "color": Color(0.7, 0.55, 0.9, 0.08),
		"direction": Vector2(0, -1), "gravity": Vector2(0, -10), "spread": 45.0},
	"music": {"amount": 8, "color": Color(1.0, 0.85, 0.4, 0.08),
		"direction": Vector2(0, -1), "gravity": Vector2(0, -12), "spread": 35.0},
	"garden": {"amount": 8, "color": Color(1.0, 0.75, 0.8, 0.08),
		"direction": Vector2(1, 0), "gravity": Vector2(2, -5), "spread": 50.0},
	"candy": {"amount": 10, "color": Color(1.0, 0.7, 0.85, 0.08),
		"direction": Vector2(0, -1), "gravity": Vector2(0, -8), "spread": 45.0},
	"arctic": {"amount": 10, "color": Color(1, 1, 1, 0.1),
		"direction": Vector2(0, 1), "gravity": Vector2(0, 8), "spread": 60.0},
	"sunset": {"amount": 6, "color": Color(1.0, 0.8, 0.5, 0.08),
		"direction": Vector2(0, -1), "gravity": Vector2(0, -10), "spread": 40.0},
	"castle": {"amount": 6, "color": Color(0.7, 0.95, 0.5, 0.06),
		"direction": Vector2(0, -1), "gravity": Vector2(0, -12), "spread": 40.0},
	"beach": {"amount": 8, "color": Color(1.0, 1.0, 0.85, 0.07),
		"direction": Vector2(1, 0), "gravity": Vector2(3, -5), "spread": 50.0},
}


## Застосувати фон — 5-точковий градієнт + шейдер + декор за bg_theme.
## Дочірній клас може перевизначити для власного фону.
func _apply_background() -> void:
	if not has_node("Background"):
		push_warning(game_id + ": Background node відсутній")
		return
	var bg: TextureRect = $Background as TextureRect
	if not bg:
		push_warning(game_id + ": Background не є TextureRect")
		return
	_bg_node = bg
	## V168: per-game ілюстрований фон → per-theme PNG → градієнт
	var theme_key: String = bg_theme if BG_THEME_GRADIENTS.has(bg_theme) else "meadow"
	## Пріоритет: per-game override → per-theme fallback
	var bg_key: String = _BG_GAME_THEME_OVERRIDE.get(game_id, theme_key)
	var theme_png_path: String = "res://assets/backgrounds/themes/bg_%s.png" % bg_key
	## Підтримка .jpg як альтернатива .png
	if not ResourceLoader.exists(theme_png_path):
		var jpg_path: String = "res://assets/backgrounds/themes/bg_%s.jpg" % bg_key
		if ResourceLoader.exists(jpg_path):
			theme_png_path = jpg_path
	var _has_illustrated_bg: bool = false
	if ResourceLoader.exists(theme_png_path):
		bg.texture = load(theme_png_path)
		_has_illustrated_bg = true
	else:
		## Fallback: програмний градієнт
		var colors: Array = BG_THEME_GRADIENTS[theme_key]
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, colors[0])
		if colors.size() >= 5:
			gradient.add_point(0.25, colors[1])
			gradient.add_point(0.5, colors[2])
			gradient.add_point(0.75, colors[3])
			gradient.set_color(1, colors[4])
		elif colors.size() >= 3:
			gradient.add_point(0.5, colors[1])
			gradient.set_color(1, colors[2])
		else:
			gradient.set_color(1, colors[1])
		var grad_tex: GradientTexture2D = GradientTexture2D.new()
		grad_tex.gradient = gradient
		grad_tex.fill_from = Vector2(0.0, 0.0)
		grad_tex.fill_to = Vector2(0.0, 1.0)
		grad_tex.width = 4
		grad_tex.height = 4
		bg.texture = grad_tex
	## Гарантувати повне покриття viewport
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	## Розмір viewport напряму — set_deferred щоб не конфліктувати з anchors
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	bg.set_deferred("size", vp_size)
	bg.position = Vector2.ZERO
	## Premium анімований шейдер
	## V167: для ілюстрованих фонів — вимкнути gradient_shift (зсуває зображення)
	_apply_bg_shader(bg, theme_key, _has_illustrated_bg)
	## V167: PNG елементи ТІЛЬКИ для градієнтних фонів
	## Ілюстровані фони вже мають дерева/хмари/пагорби нарисовані у зображенні
	if not _has_illustrated_bg:
		_draw_background_layers(theme_key, vp_size)
		_animate_bg_tweens(theme_key)
	## Floating decos та ambient particles вимкнені (рухомі частинки прибрані)


## Фонові шари — PNG елементи з assets/backgrounds/elements/.
## Органічні форми (хвилясті пагорби, хмари) замість плоских Panel shapes.
## Без GPU шейдерів (LAW 18). Всі TextureRect як діти сцени (LAW 11).
func _draw_background_layers(theme: String, vp: Vector2) -> void:
	## Опціональний ілюстрований фон-підкладка з samples/ (тонкий шар під градієнтом)
	_add_bg_sample_layer(theme, vp)
	match theme:
		"meadow", "default":
			_add_bg_sprite("rx_cloudLayer1", vp, Vector2(0, 0.0), Vector2(1.1, 0.12),
				Color("d0e0c8", 0.70), "drift", true)
			_add_bg_sprite("rx_cloud2", vp, Vector2(0.6, 0.03), Vector2(0.12, 0.06),
				Color("c0d8b8", 0.60), "drift", true)
			_add_bg_sprite("rx_cloud5", vp, Vector2(0.25, 0.04), Vector2(0.10, 0.05),
				Color("c8dac0", 0.55), "drift", true)
			_add_bg_sprite("rx_sun", vp, Vector2(0.82, 0.02), Vector2(0.08, 0.08),
				Color("ffe888", 0.60), "", true)
			_add_bg_sprite("rx_tree", vp, Vector2(0.02, 0.48), Vector2(0.09, 0.28),
				Color("ffffff", 0.90), "sway", true)
			_add_bg_sprite("rx_treePine", vp, Vector2(0.12, 0.52), Vector2(0.05, 0.20),
				Color("ffffff", 0.85), "sway", true)
			_add_bg_sprite("rx_treeLong", vp, Vector2(0.84, 0.46), Vector2(0.05, 0.26),
				Color("ffffff", 0.90), "sway", true)
			_add_bg_sprite("rx_treeSmall_green1", vp, Vector2(0.92, 0.56), Vector2(0.03, 0.12),
				Color("ffffff", 0.80), "sway", true)
			_add_bg_sprite("rx_bush1", vp, Vector2(0.20, 0.70), Vector2(0.05, 0.04),
				Color("ffffff", 0.75), "", true)
			_add_bg_sprite("rx_hillsLarge", vp, Vector2(0, 0.64), Vector2(1.2, 0.32),
				Color("1a5a10", 0.85))
			_add_bg_sprite("rx_fence", vp, Vector2(0.0, 0.82), Vector2(1.1, 0.05),
				Color("3a2810", 0.80))
			_add_bg_sprite("rx_groundLayer1", vp, Vector2(0, 0.84), Vector2(1.3, 0.16),
				Color("1a5808", 0.85))
			_add_bg_sprite("rx_groundLayer2", vp, Vector2(-0.05, 0.92), Vector2(1.3, 0.10),
				Color("125008", 0.80))
		"forest":
			_add_bg_sprite("rx_cloudLayerB1", vp, Vector2(0, 0.0), Vector2(1.1, 0.10),
				Color("b0c8b0", 0.65), "drift", true)
			_add_bg_sprite("rx_mountainA", vp, Vector2(0.1, 0.42), Vector2(0.45, 0.48),
				Color("051a0e", 0.85))
			_add_bg_sprite("rx_treePine", vp, Vector2(0.0, 0.44), Vector2(0.06, 0.30),
				Color("ffffff", 0.90), "sway", true)
			_add_bg_sprite("rx_treeLong", vp, Vector2(0.08, 0.46), Vector2(0.04, 0.26),
				Color("ffffff", 0.85), "sway", true)
			_add_bg_sprite("rx_tree", vp, Vector2(0.22, 0.48), Vector2(0.07, 0.24),
				Color("ffffff", 0.85), "sway", true)
			_add_bg_sprite("rx_treePine", vp, Vector2(0.78, 0.44), Vector2(0.06, 0.30),
				Color("ffffff", 0.85), "sway", true)
			_add_bg_sprite("rx_treeLong", vp, Vector2(0.55, 0.48), Vector2(0.04, 0.24),
				Color("ffffff", 0.80), "sway", true)
			_add_bg_sprite("rx_treeSmall_green3", vp, Vector2(0.40, 0.56), Vector2(0.03, 0.12),
				Color("ffffff", 0.80), "sway", true)
			_add_bg_sprite("rx_treeSmall_green1", vp, Vector2(0.92, 0.54), Vector2(0.03, 0.12),
				Color("ffffff", 0.75), "sway", true)
			_add_bg_sprite("rx_bush2", vp, Vector2(0.30, 0.68), Vector2(0.05, 0.04),
				Color("ffffff", 0.70), "", true)
			_add_bg_sprite("rx_hillsLarge", vp, Vector2(0, 0.62), Vector2(1.2, 0.34),
				Color("0e3820", 0.85))
			_add_bg_sprite("rx_groundLayer2", vp, Vector2(-0.1, 0.74), Vector2(1.3, 0.28),
				Color("082818", 0.80))
		"ocean":
			_add_bg_sprite("rx_cloudLayer2", vp, Vector2(0, 0.0), Vector2(1.1, 0.12),
				Color("a8c0e0", 0.70), "drift", true)
			_add_bg_sprite("rx_cloud1", vp, Vector2(0.15, 0.04), Vector2(0.12, 0.06),
				Color("98b0d0", 0.65), "drift", true)
			_add_bg_sprite("rx_cloud5", vp, Vector2(0.65, 0.05), Vector2(0.10, 0.05),
				Color("90a8c8", 0.60), "drift", true)
			_add_bg_sprite("rx_sun", vp, Vector2(0.85, 0.02), Vector2(0.08, 0.08),
				Color("ffe888", 0.55), "", true)
			_add_bg_sprite("rx_treePalm", vp, Vector2(0.02, 0.54), Vector2(0.06, 0.22),
				Color("ffffff", 0.80), "sway", true)
			_add_bg_sprite("rx_treePalm", vp, Vector2(0.90, 0.56), Vector2(0.05, 0.18),
				Color("ffffff", 0.75), "sway", true)
			_add_bg_sprite("rx_hillsLarge", vp, Vector2(0, 0.66), Vector2(1.2, 0.32),
				Color("083868", 0.85))
			_add_bg_sprite("rx_hills", vp, Vector2(-0.05, 0.76), Vector2(1.3, 0.26),
				Color("062850", 0.80))
			_add_bg_sprite("rx_groundLayer1", vp, Vector2(0, 0.90), Vector2(1.3, 0.12),
				Color("062850", 0.75))
		"science":
			_add_bg_sprite("rx_cloud4", vp, Vector2(0.2, 0.03), Vector2(0.12, 0.06),
				Color("b0a8c8", 0.65), "", true)
			_add_bg_sprite("rx_cloud2", vp, Vector2(0.7, 0.04), Vector2(0.10, 0.05),
				Color("a8a0c0", 0.60), "drift", true)
			_add_bg_sprite("rx_tower", vp, Vector2(0.02, 0.44), Vector2(0.05, 0.30),
				Color("201840", 0.85))
			_add_bg_sprite("rx_mountainB", vp, Vector2(0.6, 0.46), Vector2(0.35, 0.44),
				Color("1a1235", 0.85))
			_add_bg_sprite("rx_treePine", vp, Vector2(0.88, 0.52), Vector2(0.05, 0.22),
				Color("1a1235", 0.80), "sway")
			_add_bg_sprite("rx_towerSmall", vp, Vector2(0.40, 0.54), Vector2(0.04, 0.18),
				Color("201840", 0.75))
			_add_bg_sprite("rx_hillsLarge", vp, Vector2(0, 0.74), Vector2(1.2, 0.28),
				Color("150e30", 0.85))
		"space":
			## Зірки — маленькі білі точки з різною прозорістю
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = 42
			for idx: int in 30:
				var sx: float = rng.randf_range(0.05, 0.95)
				var sy: float = rng.randf_range(0.05, 0.75)
				var star_size: float = rng.randf_range(2.0, 7.0)
				var star_alpha: float = rng.randf_range(0.35, 0.80)
				_add_star_dot(vp, sx, sy, star_size, star_alpha)
			_add_bg_sprite("rx_moonFull", vp, Vector2(0.80, 0.06), Vector2(0.06, 0.06),
				Color("e8e0f0", 0.50), "", true)
			_add_bg_sprite("rx_mountainB", vp, Vector2(0.65, 0.62), Vector2(0.30, 0.32),
				Color("080e20", 0.85))
			_add_bg_sprite("rx_mountainA", vp, Vector2(0.05, 0.65), Vector2(0.38, 0.30),
				Color("060c18", 0.80))
			_add_bg_sprite("rx_mountainC", vp, Vector2(0.3, 0.70), Vector2(0.40, 0.26),
				Color("050a15", 0.75))
		"city":
			_add_bg_sprite("rx_cloudLayer1", vp, Vector2(0, 0.0), Vector2(1.1, 0.10),
				Color("d0c0a8", 0.65), "drift", true)
			_add_bg_sprite("rx_cloud6", vp, Vector2(0.5, 0.03), Vector2(0.12, 0.06),
				Color("c8b8a0", 0.55), "drift", true)
			_add_bg_sprite("rx_tower", vp, Vector2(0.05, 0.42), Vector2(0.05, 0.30),
				Color("3a2810", 0.85))
			_add_bg_sprite("rx_house1", vp, Vector2(0.48, 0.50), Vector2(0.10, 0.22),
				Color("4a3818", 0.85))
			_add_bg_sprite("rx_house2", vp, Vector2(0.72, 0.52), Vector2(0.12, 0.20),
				Color("4a3818", 0.80))
			_add_bg_sprite("rx_houseSmall1", vp, Vector2(0.30, 0.56), Vector2(0.08, 0.16),
				Color("3a2810", 0.80))
			_add_bg_sprite("rx_castleSmall", vp, Vector2(0.88, 0.48), Vector2(0.08, 0.22),
				Color("3a2810", 0.80))
			_add_bg_sprite("rx_fence", vp, Vector2(0.0, 0.78), Vector2(1.1, 0.05),
				Color("3a2810", 0.75))
			_add_bg_sprite("rx_hillsLarge", vp, Vector2(0, 0.68), Vector2(1.2, 0.30),
				Color("3a2810", 0.85))
			_add_bg_sprite("rx_groundLayer2", vp, Vector2(0, 0.88), Vector2(1.3, 0.12),
				Color("4a3010", 0.80))
		"puzzle":
			_add_bg_sprite("rx_cloud3", vp, Vector2(0.15, 0.03), Vector2(0.12, 0.07),
				Color("b0a0c8", 0.65), "", true)
			_add_bg_sprite("rx_cloud6", vp, Vector2(0.7, 0.05), Vector2(0.10, 0.06),
				Color("a898c0", 0.60), "", true)
			_add_bg_sprite("rx_cloud4", vp, Vector2(0.4, 0.02), Vector2(0.10, 0.05),
				Color("b0a8c8", 0.55), "drift", true)
			_add_bg_sprite("rx_tree", vp, Vector2(0.02, 0.50), Vector2(0.07, 0.24),
				Color("201040", 0.90), "sway")
			_add_bg_sprite("rx_treePine", vp, Vector2(0.87, 0.52), Vector2(0.05, 0.22),
				Color("180838", 0.85), "sway")
			_add_bg_sprite("rx_bush2", vp, Vector2(0.12, 0.70), Vector2(0.05, 0.04),
				Color("201040", 0.70))
			_add_bg_sprite("rx_hillsLarge", vp, Vector2(0, 0.70), Vector2(1.2, 0.30),
				Color("201040", 0.85))
			_add_bg_sprite("rx_groundLayer1", vp, Vector2(0, 0.88), Vector2(1.3, 0.12),
				Color("180838", 0.80))
		"music":
			_add_bg_sprite("rx_cloud7", vp, Vector2(0.55, 0.03), Vector2(0.10, 0.06),
				Color("d0c0a0", 0.65), "", true)
			_add_bg_sprite("rx_cloud2", vp, Vector2(0.15, 0.02), Vector2(0.10, 0.05),
				Color("c8b898", 0.60), "drift", true)
			_add_bg_sprite("rx_sun", vp, Vector2(0.85, 0.02), Vector2(0.08, 0.08),
				Color("f0c870", 0.55), "", true)
			_add_bg_sprite("rx_treeOrange", vp, Vector2(0.03, 0.50), Vector2(0.07, 0.24),
				Color("ffffff", 0.85), "sway", true)
			_add_bg_sprite("rx_tree", vp, Vector2(0.87, 0.52), Vector2(0.06, 0.22),
				Color("ffffff", 0.80), "sway", true)
			_add_bg_sprite("rx_bush1", vp, Vector2(0.14, 0.70), Vector2(0.05, 0.04),
				Color("ffffff", 0.70), "", true)
			_add_bg_sprite("rx_hillsLarge", vp, Vector2(0, 0.70), Vector2(1.2, 0.28),
				Color("381808", 0.85))
			_add_bg_sprite("rx_groundLayer2", vp, Vector2(0, 0.88), Vector2(1.3, 0.12),
				Color("301408", 0.80))
		"garden":
			_add_bg_sprite("rx_cloud4", vp, Vector2(0.3, 0.03), Vector2(0.12, 0.06),
				Color("d0b0b8", 0.60), "drift", true)
			_add_bg_sprite("rx_treeOrange", vp, Vector2(0.03, 0.46), Vector2(0.07, 0.26),
				Color("ffffff", 0.90), "sway", true)
			_add_bg_sprite("rx_tree", vp, Vector2(0.80, 0.48), Vector2(0.07, 0.24),
				Color("ffffff", 0.85), "sway", true)
			_add_bg_sprite("rx_treeSmall_orange1", vp, Vector2(0.35, 0.56), Vector2(0.03, 0.12),
				Color("ffffff", 0.80), "sway", true)
			_add_bg_sprite("rx_bush3", vp, Vector2(0.62, 0.70), Vector2(0.05, 0.04),
				Color("ffffff", 0.75), "", true)
			_add_bg_sprite("rx_bushOrange1", vp, Vector2(0.15, 0.72), Vector2(0.06, 0.04),
				Color("ffffff", 0.70), "", true)
			_add_bg_sprite("rx_fence", vp, Vector2(0.0, 0.78), Vector2(1.1, 0.06),
				Color("4a2028", 0.80))
			_add_bg_sprite("rx_hillsLarge", vp, Vector2(0, 0.66), Vector2(1.2, 0.32),
				Color("3a1020", 0.85))
			_add_bg_sprite("rx_groundLayer1", vp, Vector2(0, 0.86), Vector2(1.3, 0.14),
				Color("4a1828", 0.80))
		"candy":
			_add_bg_sprite("rx_cloud3", vp, Vector2(0.1, 0.04), Vector2(0.12, 0.07),
				Color("d89098", 0.65), "", true)
			_add_bg_sprite("rx_cloud7", vp, Vector2(0.65, 0.03), Vector2(0.10, 0.06),
				Color("d8a890", 0.60), "", true)
			_add_bg_sprite("rx_cloud1", vp, Vector2(0.35, 0.01), Vector2(0.10, 0.05),
				Color("d89aa8", 0.55), "drift", true)
			_add_bg_sprite("rx_treeOrange", vp, Vector2(0.02, 0.50), Vector2(0.07, 0.24),
				Color("ffffff", 0.85), "sway", true)
			_add_bg_sprite("rx_tree", vp, Vector2(0.89, 0.52), Vector2(0.06, 0.22),
				Color("ffffff", 0.80), "sway", true)
			_add_bg_sprite("rx_cactus1", vp, Vector2(0.40, 0.60), Vector2(0.04, 0.12),
				Color("ffffff", 0.75), "", true)
			_add_bg_sprite("rx_hillsLarge", vp, Vector2(0, 0.68), Vector2(1.2, 0.30),
				Color("482010", 0.85))
			_add_bg_sprite("rx_groundLayer1", vp, Vector2(0, 0.88), Vector2(1.3, 0.12),
				Color("401810", 0.80))
		"arctic":
			_add_bg_sprite("rx_cloudLayer2", vp, Vector2(0, 0.0), Vector2(1.1, 0.10),
				Color("b8d0e0", 0.70), "drift", true)
			_add_bg_sprite("rx_cloud8", vp, Vector2(0.45, 0.03), Vector2(0.10, 0.06),
				Color("a8c8d8", 0.60), "drift", true)
			_add_bg_sprite("rx_mountainC", vp, Vector2(0.3, 0.40), Vector2(0.40, 0.42),
				Color("284858", 0.85))
			_add_bg_sprite("rx_mountainA", vp, Vector2(0.05, 0.44), Vector2(0.45, 0.46),
				Color("203848", 0.85))
			_add_bg_sprite("rx_mountainB", vp, Vector2(0.5, 0.46), Vector2(0.38, 0.42),
				Color("183040", 0.80))
			_add_bg_sprite("rx_treeFrozen", vp, Vector2(0.02, 0.54), Vector2(0.06, 0.22),
				Color("ffffff", 0.85), "sway", true)
			_add_bg_sprite("rx_treeSnow", vp, Vector2(0.88, 0.56), Vector2(0.05, 0.18),
				Color("ffffff", 0.80), "sway", true)
			_add_bg_sprite("rx_hillsLarge", vp, Vector2(0, 0.68), Vector2(1.2, 0.30),
				Color("284858", 0.85))
		"sunset":
			_add_bg_sprite("rx_cloudLayer1", vp, Vector2(0, 0.0), Vector2(1.1, 0.12),
				Color("e8a888", 0.75), "drift", true)
			_add_bg_sprite("rx_cloud1", vp, Vector2(0.50, 0.02), Vector2(0.12, 0.07),
				Color("e0a080", 0.65), "drift", true)
			_add_bg_sprite("rx_sun", vp, Vector2(0.40, 0.02), Vector2(0.08, 0.08),
				Color("ffd888", 0.70), "", true)
			_add_bg_sprite("rx_tree", vp, Vector2(0.01, 0.48), Vector2(0.07, 0.26),
				Color("3a1028", 0.90), "sway")
			_add_bg_sprite("rx_treePine", vp, Vector2(0.10, 0.54), Vector2(0.04, 0.18),
				Color("2d0a20", 0.85), "sway")
			_add_bg_sprite("rx_treeLong", vp, Vector2(0.86, 0.46), Vector2(0.05, 0.28),
				Color("3a1028", 0.90), "sway")
			_add_bg_sprite("rx_treeSmall_green1", vp, Vector2(0.92, 0.56), Vector2(0.03, 0.12),
				Color("2d0a20", 0.80), "sway")
			_add_bg_sprite("rx_hillsLarge", vp, Vector2(0, 0.64), Vector2(1.2, 0.30),
				Color("4a1838", 0.85))
			_add_bg_sprite("rx_hills", vp, Vector2(-0.05, 0.74), Vector2(1.3, 0.25),
				Color("350e28", 0.80))
			_add_bg_sprite("rx_groundLayer1", vp, Vector2(0, 0.88), Vector2(1.1, 0.14),
				Color("2a0818", 0.85))


## Ілюстрований фон-підкладка з backgrounds/samples/ (colored_forest тощо).
## Тонкий шар (alpha 0.30-0.35) під PNG-елементами для глибини сцени.
## Маппінг по game_id — кожна гра має УНІКАЛЬНИЙ sample у рамках своєї теми.
const _BG_GAME_SAMPLE_MAP: Dictionary = {
	## meadow theme
	"hungry_pets": "colored_grass",
	"compare": "uncolored_hills",
	"counting": "uncolored_plain",
	## forest theme
	"knight_path": "colored_forest",
	"odd_one_out": "colored_talltrees",
	"shadow_match": "uncolored_talltrees",
	"sorting": "uncolored_forest",
	## ocean theme
	"color_pop": "uncolored_desert",
	"hygiene": "kenney_desert",
	## science theme
	"algo_robot": "uncolored_piramids",
	"color_lab": "uncolored_castle",
	## space theme
	"gravity_orbits": "uncolored_peaks",
	"safe_maze": "uncolored_hills",
	"sensory_sandbox": "kenney_forest",
	## city theme
	"analog_clock": "colored_castle",
	"cash_register": "kenney_castles",
	"math_scales": "uncolored_castle",
	## puzzle theme
	"magnetic_halves": "uncolored_plain",
	"math_bingo": "uncolored_piramids",
	"pattern": "uncolored_desert",
	"spelling_blocks": "uncolored_talltrees",
	## music theme
	"music": "colored_fall",
	"smart_coloring": "colored_grass",
	## garden theme
	"eco_conveyor": "colored_talltrees",
	"shape_sorter": "kenney_forest",
	## candy theme
	"color_conveyor": "colored_desert",
	"size_sort": "uncolored_piramids",
	## arctic theme
	"weather_dress": "uncolored_forest",
	## sunset theme
	"memory": "colored_fall",
}


func _add_bg_sample_layer(theme_key: String, vp: Vector2) -> void:
	if not _BG_GAME_SAMPLE_MAP.has(game_id):
		return
	var sample_name: String = _BG_GAME_SAMPLE_MAP[game_id]
	var path: String = "res://assets/backgrounds/samples/%s.png" % sample_name
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var layer: TextureRect = TextureRect.new()
	layer.texture = tex
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.size = vp
	layer.position = Vector2.ZERO
	## Тонкий alpha — підкладка, не перебиває градієнт
	## Для uncolored зображень — тінт кольором теми
	if sample_name.begins_with("uncolored") and BG_THEME_GRADIENTS.has(theme_key):
		var theme_color: Color = BG_THEME_GRADIENTS[theme_key][2]  ## Середній колір градієнту
		layer.modulate = Color(theme_color.r, theme_color.g, theme_color.b, 0.30)
	else:
		layer.modulate = Color(1, 1, 1, 0.35)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = -2
	add_child(layer)


## Додати фоновий PNG-елемент як TextureRect.
## pos_frac — позиція (0-1 від viewport), scale_frac — розмір (частка viewport).
## shader_type: "" = без шейдера, "drift" = паралакс, "sway" = хитання.
## V164: Два режими — silhouette (заміна кольору) та natural (оригінальні кольори).
func _add_bg_sprite(element_name: String, vp: Vector2, pos_frac: Vector2,
		scale_frac: Vector2, tint_color: Color, shader_type: String = "",
		natural: bool = false) -> void:
	var path: String = "res://assets/backgrounds/elements/%s.png" % element_name
	if not ResourceLoader.exists(path):
		push_warning("Background element missing: " + path)
		return
	var tex: Texture2D = load(path)
	var bg_layer: TextureRect = TextureRect.new()
	bg_layer.texture = tex
	bg_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_layer.position = Vector2(vp.x * pos_frac.x, vp.y * pos_frac.y)
	bg_layer.size = Vector2(vp.x * scale_frac.x, vp.y * scale_frac.y)
	if natural:
		bg_layer.modulate = Color(1, 1, 1, tint_color.a)
	else:
		bg_layer.modulate = Color.WHITE
	bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.z_index = -1
	## Шейдер з tinting + анімація + grain (LAW 28)
	var layer_mat: ShaderMaterial = null
	if shader_type != "" and not SettingsManager.reduced_motion:
		var shader_path: String = ""
		if shader_type == "drift":
			shader_path = "res://assets/shaders/bg_parallax_layer.gdshader"
		elif shader_type == "sway":
			shader_path = "res://assets/shaders/sway.gdshader"
		if shader_path != "" and ResourceLoader.exists(shader_path):
			var shader: Shader = load(shader_path)
			layer_mat = ShaderMaterial.new()
			layer_mat.shader = shader
			layer_mat.set_shader_parameter("grain_tex", GameData._get_grain_texture())
			layer_mat.set_shader_parameter("grain_intensity", 0.0)  ## Grain вимкнений глобально
			if not natural:
				layer_mat.set_shader_parameter("use_tint", true)
				layer_mat.set_shader_parameter("tint_color", tint_color)
	if not layer_mat:
		if natural:
			layer_mat = GameData.create_premium_material(
				0.02, 3.0, 0.0, 0.0, 0.03, 0.04, 0.10, "", 0.0, 0.06, 0.15, 0.12)
		else:
			var sil_path: String = "res://assets/shaders/silhouette.gdshader"
			if ResourceLoader.exists(sil_path):
				var sil_shader: Shader = load(sil_path)
				layer_mat = ShaderMaterial.new()
				layer_mat.shader = sil_shader
				layer_mat.set_shader_parameter("tint_color", tint_color)
			else:
				bg_layer.modulate = tint_color
	if layer_mat:
		bg_layer.material = layer_mat
	add_child(bg_layer)


## Додати зірку-точку — маленький Panel для space теми (геометрична форма OK).
func _add_star_dot(vp: Vector2, x_frac: float, y_frac: float,
		sz: float, alpha: float) -> void:
	var p: Panel = Panel.new()
	p.position = Vector2(vp.x * x_frac - sz * 0.5, vp.y * y_frac - sz * 0.5)
	p.size = Vector2(sz, sz)
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, alpha)
	s.set_corner_radius_all(int(sz * 0.5))
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = -1
	add_child(p)


## Застосувати анімований шейдер до фонового TextureRect.
## V167: illustrated_bg = true → gradient_shift = 0 (зсув UV руйнує PNG-зображення)
func _apply_bg_shader(bg: TextureRect, theme_key: String, illustrated_bg: bool = false) -> void:
	if not BG_SHADER_PARAMS.has(theme_key):
		return
	var shader_res: Shader = load("res://assets/shaders/bg_animated.gdshader")
	if not shader_res:
		push_warning("bg_animated.gdshader not found")
		return
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader_res
	var params: Dictionary = BG_SHADER_PARAMS[theme_key]
	mat.set_shader_parameter("bokeh_count", params.get("bokeh_count", 5.0))
	mat.set_shader_parameter("bokeh_size", params.get("bokeh_size", 0.06))
	mat.set_shader_parameter("bokeh_intensity", params.get("bokeh_intensity", 0.12))
	mat.set_shader_parameter("bokeh_color", params.get("bokeh_color", Color(1, 1, 1, 0.08)))
	mat.set_shader_parameter("bokeh_speed", params.get("bokeh_speed", 0.15))
	## V167: для ілюстрованих фонів gradient_shift = 0 (зсув UV руйнує PNG)
	mat.set_shader_parameter("gradient_shift", 0.0 if illustrated_bg else params.get("gradient_shift", 0.015))
	mat.set_shader_parameter("gradient_speed", params.get("gradient_speed", 0.4))
	mat.set_shader_parameter("pattern_type", params.get("pattern_type", 0))
	mat.set_shader_parameter("pattern_intensity", params.get("pattern_intensity", 0.0))
	mat.set_shader_parameter("pattern_scale", params.get("pattern_scale", 20.0))
	mat.set_shader_parameter("vignette_strength", params.get("vignette_strength", 0.0))
	## Depth-layered bokeh — secondary color
	mat.set_shader_parameter("bokeh_color_2", params.get("bokeh_color_2",
		params.get("bokeh_color", Color(1, 1, 1, 0.08))))
	## Theme-specific procedural detail layer
	mat.set_shader_parameter("theme_id", params.get("theme_id", 0))
	mat.set_shader_parameter("detail_intensity", params.get("detail_intensity", 0.0))
	mat.set_shader_parameter("detail_scale", params.get("detail_scale", 10.0))
	mat.set_shader_parameter("detail_speed", params.get("detail_speed", 0.2))
	mat.set_shader_parameter("detail_color", params.get("detail_color", Color(1, 1, 1, 0.1)))
	## Radial highlight + horizon glow
	mat.set_shader_parameter("highlight_pos", params.get("highlight_pos", Vector2(0.8, 0.15)))
	mat.set_shader_parameter("highlight_radius", params.get("highlight_radius", 0.0))
	mat.set_shader_parameter("highlight_intensity", params.get("highlight_intensity", 0.0))
	mat.set_shader_parameter("highlight_color", params.get("highlight_color", Color(1, 1, 0.8, 0.15)))
	mat.set_shader_parameter("horizon_glow", params.get("horizon_glow", 0.0))
	mat.set_shader_parameter("horizon_y", params.get("horizon_y", 0.75))
	mat.set_shader_parameter("horizon_color", params.get("horizon_color", Color(1, 0.9, 0.7, 0.1)))
	## Chromatic aberration — subtle RGB split at vignette edges
	mat.set_shader_parameter("chromatic_aberration", params.get("chromatic_aberration", 0.0))
	## reduced_motion: вимкнути анімацію шейдера
	mat.set_shader_parameter("time_scale", 0.0 if SettingsManager.reduced_motion else 1.0)
	## Grain texture overlay (LAW 28)
	mat.set_shader_parameter("grain_tex", GameData._get_grain_texture())
	mat.set_shader_parameter("grain_intensity", 0.0)  ## Grain вимкнений глобально
	mat.set_shader_parameter("detail_intensity", 0.0)  ## Процедурний шум вимкнений
	bg.material = mat


## Анімувати фонові елементи — sun pulse, star twinkle.
func _animate_bg_tweens(theme_key: String) -> void:
	if SettingsManager.reduced_motion:
		return
	## Sun pulse — для тем з сонцем
	if theme_key in ["meadow", "music", "sunset"]:
		for child: Node in get_children():
			if child is TextureRect and child.z_index == -1:
				## Знайти sun-елемент за розміром (малий квадрат)
				if child.size.x > 0 and child.size.x < 300 and child.size.y > 0 \
						and child.size.x == child.size.y:
					continue  ## Пропускаємо — pulse через modulate нижче
		## Sun pulse через modulate.a
		for child: Node in get_children():
			if child is TextureRect and child.z_index == -1 \
					and child.size.x > 0 and absf(child.size.x - child.size.y) < 5.0 \
					and child.size.x < 300:
				child.pivot_offset = child.size / 2.0
				var tw: Tween = _create_game_tween().set_loops()
				tw.tween_property(child, "scale", Vector2(1.06, 1.06), 2.0)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				tw.tween_property(child, "scale", Vector2.ONE, 2.0)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				break


## Легкі плаваючі акценти на фоні — тематичні частки для глибини.
func _spawn_ambient_particles() -> void:
	if SettingsManager.reduced_motion:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var cfg: Dictionary = BG_PARTICLE_CONFIGS.get(bg_theme,
		BG_PARTICLE_CONFIGS.get("meadow", {}))
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.emitting = true
	emitter.amount = cfg.get("amount", 6)
	emitter.lifetime = 5.0
	emitter.explosiveness = 0.0
	emitter.randomness = 0.5
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.emission_rect_extents = Vector2(vp.x * 0.5, 10.0)
	emitter.direction = cfg.get("direction", Vector2(0, -1))
	emitter.spread = cfg.get("spread", 40.0)
	emitter.gravity = cfg.get("gravity", Vector2(0, -15))
	emitter.initial_velocity_min = 10.0
	emitter.initial_velocity_max = 25.0
	emitter.scale_amount_min = 0.3
	emitter.scale_amount_max = 0.6
	emitter.color = cfg.get("color", Color(1, 1, 1, 0.12))
	emitter.position = Vector2(vp.x * 0.5, vp.y * 0.9)
	emitter.z_index = -1
	add_child(emitter)


var _floating_decos: Array[SplashDeco] = []
var _floating_deco_base_y: Array[float] = []
const _DECO_FLOAT_AMP: float = 12.0
const _DECO_ROT_AMP: float = 8.0
const _DECO_SPEEDS: Array[float] = [6.5, 8.0, 5.5]


## Процедурні декоративні фігури SplashDeco по кутах ігрового екрану.
## Ті самі 4-шарові фігури з grain-текстурою що на splash screen і main menu.
## z_index = -1, mouse_filter = IGNORE — не заважають ігровим елементам.
func _spawn_floating_decos(vp: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	var shapes: Array = [SplashDeco.Shape.LOLLIPOP_A, SplashDeco.Shape.PLANET,
		SplashDeco.Shape.LOLLIPOP_B]
	var positions: Array[Vector2] = [
		Vector2(vp.x * 0.04, vp.y * 0.75),   ## нижній лівий
		Vector2(vp.x * 0.88, vp.y * 0.12),   ## верхній правий
		Vector2(vp.x * 0.90, vp.y * 0.78),   ## нижній правий
	]
	var sizes: Array[Vector2] = [
		Vector2(45, 60), Vector2(50, 50), Vector2(40, 55),
	]
	for i: int in shapes.size():
		var d: SplashDeco = SplashDeco.new()
		d.shape_type = shapes[i]
		d.size = sizes[i]
		d.position = positions[i]
		d.modulate.a = 0.0
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.z_index = -1
		add_child(d)
		## Fade-in з затримкою
		create_tween().tween_property(d, "modulate:a", 0.35, 0.6)\
			.set_delay(0.4 + float(i) * 0.2)
		_floating_decos.append(d)
		_floating_deco_base_y.append(d.position.y)


## Анімація плавання декоративних фігур — sine wave + rotation wobble.
## Копія паттерну зі splash_screen.gd (DECO_FLOAT_AMP, DECO_ROT_AMP, per-deco speed).
func _process_floating_decos() -> void:
	if SettingsManager.reduced_motion or _floating_decos.is_empty():
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	for i: int in _floating_decos.size():
		if is_instance_valid(_floating_decos[i]):
			var spd: float = TAU / _DECO_SPEEDS[i]
			var dir: float = -1.0 if i % 2 == 1 else 1.0
			_floating_decos[i].position.y = _floating_deco_base_y[i] \
				+ sin(t * spd) * _DECO_FLOAT_AMP
			_floating_decos[i].rotation_degrees = sin(t * spd * 0.8) \
				* _DECO_ROT_AMP * dir


## Масштаб UI відносно референсної висоти (800px).
## Дочірні класи використовують для font_size, margins тощо.
func _ui_scale() -> float:
	return get_viewport().get_visible_rect().size.y / REFERENCE_HEIGHT


## Масштаб розміру для тоддлерів — збільшує items для кращої моторики.
func _toddler_scale(base_size: float) -> float:
	return base_size * TODDLER_SCALE if SettingsManager.age_group == 1 else base_size


## Плавна зміна тексту інструкції — fade out → set text → fade in.
## Дочірні класи викликають замість прямого label.text = "...".
func _fade_instruction(label: Label, new_text: String, duration: float = 0.3) -> void:
	if not is_instance_valid(label):
		push_warning("BaseMiniGame: _fade_instruction — label freed")
		return
	if label.text == new_text:
		return
	if SettingsManager.reduced_motion:
		label.text = new_text
		return
	var tw: Tween = create_tween()
	tw.tween_property(label, "modulate:a", 0.0, duration * 0.5)
	tw.tween_callback(func() -> void: label.text = new_text)
	tw.tween_property(label, "modulate:a", 1.0, duration * 0.5)


## UX-03: Тост-повідомлення про досягнення — slide-in зверху, автозникнення 2с.
## Glass pill background з candy depth (LAW 28).
func _show_achievement_toast(text: String) -> void:
	if not _ui_layer:
		return
	var s: float = _ui_scale()
	## Glass pill container
	var pill: PanelContainer = PanelContainer.new()
	var pill_style: StyleBoxFlat = StyleBoxFlat.new()
	pill_style.bg_color = Color(0, 0, 0, 0.45)
	pill_style.set_corner_radius_all(999)
	pill_style.anti_aliasing_size = 1.0
	pill_style.border_width_bottom = 2
	pill_style.border_width_left = 1
	pill_style.border_width_right = 1
	pill_style.border_width_top = 0
	pill_style.border_color = Color(ThemeManager.COLOR_GOLD, 0.3)
	pill_style.shadow_color = Color(0, 0, 0, 0.2)
	pill_style.shadow_size = 4
	pill_style.shadow_offset = Vector2(0, 2)
	pill_style.content_margin_left = 24.0
	pill_style.content_margin_right = 24.0
	pill_style.content_margin_top = 8.0
	pill_style.content_margin_bottom = 10.0
	pill.add_theme_stylebox_override("panel", pill_style)
	pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	pill.offset_top = -60.0
	pill.offset_bottom = -20.0
	pill.offset_left = -200.0
	pill.offset_right = 200.0
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Label всередині pill
	var toast: Label = Label.new()
	toast.text = text
	toast.add_theme_font_size_override("font_size", int(24.0 * s))
	toast.add_theme_color_override("font_color", ThemeManager.COLOR_GOLD)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(toast)
	_ui_layer.add_child(pill)
	AudioManager.play_sfx("success")
	if SettingsManager.reduced_motion:
		pill.offset_top = 80.0 * s
		pill.offset_bottom = 120.0 * s
		get_tree().create_timer(2.5).timeout.connect(pill.queue_free)
		return
	## Slide in
	var tw: Tween = create_tween()
	tw.tween_property(pill, "offset_top", 80.0 * s, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pill, "offset_bottom", 120.0 * s, 0.4)
	## Затримка + fade out
	tw.tween_interval(2.0)
	tw.tween_property(pill, "modulate:a", 0.0, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.finished.connect(pill.queue_free)


## Анімація входу в міні-гру — легкий масштаб + fade для плавного старту.
func _play_entrance_animation() -> void:
	if SettingsManager.reduced_motion:
		push_warning("BaseMiniGame: entrance animation skipped — reduced_motion enabled")
		return
	modulate.a = 0.0
	## Node2D не має pivot_offset — масштабуємо через зміщення position
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = vp / 2.0
	var offset: Vector2 = center * (1.0 - 0.95)
	scale = Vector2(0.95, 0.95)
	position = offset
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", Vector2.ZERO, 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Віртуальний метод — дочірній клас перевизначає для тексту підказки.
func get_tutorial_instruction() -> String:
	return ""


## Віртуальний метод — дочірній клас повертає дані для анімованої руки-підказки.
## {"type": "drag", "from": Vector2, "to": Vector2} або {"type": "tap", "target": Vector2}
func get_tutorial_demo() -> Dictionary:
	return {}


## Реєстрація правильної відповіді — скидає hint level, streak бонус.
## Якщо передано node — автоматично відтворює feedback (audio + haptics + VFX).
func _register_correct(node: Node2D = null) -> void:
	if _game_finished:
		return
	_consecutive_errors = 0
	_idle_hint_level = 0
	_remove_glow_hint()
	_streak_count += 1
	## MasteryManager: трекінг правильної відповіді
	if not _skill_id.is_empty():
		MasteryManager.record_attempt(game_id, _skill_id, true)
	## Hit-stop: 30ms мікро-пауза для "ваги" моменту (ігровий juice)
	if not SettingsManager.reduced_motion:
		Engine.time_scale = 0.05
		get_tree().create_timer(0.03, true, false, true).timeout.connect(
			func() -> void: Engine.time_scale = 1.0)
	## Auto-feedback: audio + haptics + VFX коли node передано
	if node and is_instance_valid(node):
		var pitch: float = PITCH_SCALE[mini(_streak_count, PITCH_SCALE.size() - 1)]
		AudioManager.play_sfx("success", pitch)
		HapticsManager.vibrate_success()
		_animate_correct_item(node)


## Реєстрація помилки — після N поспіль помилок показує scaffold підказку.
## Якщо передано node — автоматично відтворює error feedback (T: click+wobble, P: error+smoke+wobble).
func _register_error(node: Node2D = null) -> void:
	_consecutive_errors += 1
	_streak_count = 0
	## MasteryManager: трекінг помилки
	if not _skill_id.is_empty():
		MasteryManager.record_attempt(game_id, _skill_id, false)
	var threshold: int = 2 if SettingsManager.age_group == 1 else 3
	if _consecutive_errors >= threshold:
		_consecutive_errors = 0
		_show_scaffold_hint()
	## Auto-feedback: вікова error response коли node передано
	if node and is_instance_valid(node):
		_play_error_sequence(node)


## Scaffold підказка — показує tutorial hand з правильною відповіддю.
func _show_scaffold_hint() -> void:
	if _tutorial_sys:
		_tutorial_sys.show_scaffold_hint()


## Створити tween з автореєстрацією — очищується в finish_game() та _kill_all_tweens().
## Дочірні класи використовують замість create_tween() для гарантованого cleanup.
func _create_game_tween() -> Tween:
	var tw: Tween = create_tween()
	_active_tweens.append(tw)
	return tw


## Знищити всі зареєстровані tweens — викликається при завершенні гри/раунду.
func _kill_all_tweens() -> void:
	for tw: Tween in _active_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_active_tweens.clear()
	if _round_label_tween and _round_label_tween.is_valid():
		_round_label_tween.kill()
	_round_label_tween = null


## Оновити round label з elastic bounce анімацією (spam-safe).
## Dedicated _round_label_tween — kills previous before new (no overlap).
func _update_round_label(new_text: String) -> void:
	if not is_instance_valid(_round_label):
		return
	_round_label.text = new_text
	if SettingsManager.reduced_motion:
		return
	## Kill previous bounce if still running (tween overlap protection)
	if _round_label_tween and _round_label_tween.is_valid():
		_round_label_tween.kill()
		_round_label.scale = Vector2.ONE
	_round_label.pivot_offset = _round_label.size / 2.0
	_round_label_tween = _create_game_tween()
	_round_label_tween.tween_property(_round_label, "scale",
		Vector2(1.25, 1.25), 0.08)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_round_label_tween.tween_property(_round_label, "scale",
		Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Уніфікована послідовність успіху — SFX + вібрація + конфеті.
## Дочірні класи викликають замість дублювання 3-4 рядків у кожній грі.
func _play_success_sequence(pos: Vector2 = Vector2.ZERO) -> void:
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	if pos == Vector2.ZERO:
		pos = get_viewport().get_visible_rect().size * 0.5
	VFXManager.spawn_premium_celebration(pos)


## Легке святкування між раундами — sparkle + audio + haptics.
## НЕ включає screen_shake (motion sickness при повторенні кожен раунд).
## Легше за _play_success_sequence() (без confetti).
func _play_round_celebration(pos: Vector2 = Vector2.ZERO) -> void:
	if _game_finished:
		return
	if pos == Vector2.ZERO:
		pos = get_viewport().get_visible_rect().size * 0.5
	AudioManager.play_sfx("success")
	HapticsManager.vibrate_success()
	VFXManager.spawn_sparkle_pop(pos)


## Уніфікована послідовність помилки — SFX + вібрація + wobble.
## Toddler: comic bounce + wobble. Preschool: error SFX + smoke + wobble.
func _play_error_sequence(node: Node2D) -> void:
	if SettingsManager.age_group == 1:
		AudioManager.play_sfx("bounce")  ## Comic звук для Toddler — м'якіший та веселіший
	else:
		AudioManager.play_sfx("error")
		HapticsManager.vibrate_light()
		if is_instance_valid(node):
			VFXManager.spawn_error_smoke(node.global_position)
	_animate_error_item(node)


## Ескалація idle hint — повертає рівень (0 = м'який, 1 = сильніший, 2+ = tutorial hand).
func _advance_idle_hint() -> int:
	_idle_hint_level = mini(_idle_hint_level + 1, 2)
	if _idle_hint_level >= 2 and _tutorial_sys:
		_tutorial_sys.show_scaffold_hint()
	return _idle_hint_level


## Каскадна поява елементів — premium staggered deal animation.
## Дочірні класи викликають після створення масиву нодів.
func _staggered_spawn(nodes: Array, delay_per_item: float = 0.08) -> void:
	if SettingsManager.reduced_motion:
		return
	## Toddler: повільніші анімації для кращого відстеження (research: young children track slower)
	var speed_mult: float = 1.4 if SettingsManager.age_group == 1 else 1.0
	for i: int in nodes.size():
		var node: CanvasItem = nodes[i] as CanvasItem
		if not is_instance_valid(node):
			continue
		var original_scale: Vector2 = node.scale  ## Зберігаємо оригінальний scale
		node.scale = Vector2.ZERO
		node.modulate.a = 0.0
		var tw: Tween = create_tween().set_parallel(true)
		var d: float = float(i) * delay_per_item * speed_mult
		tw.tween_property(node, "scale", original_scale * 1.1, 0.2 * speed_mult)\
			.set_delay(d).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "modulate:a", 1.0, 0.15 * speed_mult).set_delay(d)
		tw.chain().tween_property(node, "scale", original_scale, 0.08 * speed_mult)


## Оркестрована поява елементів — stagger + audio + input lock + pivot.
## Покращена версія _staggered_spawn з повним lifecycle management.
func _orchestrated_entrance(nodes: Array, delay_per_item: float = 0.08,
		unlock_input: bool = true, sfx_name: String = "pop") -> void:
	if nodes.is_empty():
		push_warning("BaseMiniGame: _orchestrated_entrance() — порожній масив")
		if unlock_input:
			_input_locked = false
		return
	_input_locked = true
	if SettingsManager.reduced_motion:
		for node: Variant in nodes:
			var ci: CanvasItem = node as CanvasItem
			if ci and is_instance_valid(ci):
				ci.scale = Vector2.ONE
				ci.modulate.a = 1.0
		if unlock_input:
			_input_locked = false
		return
	## Frame 0 flash prevention — приховати ДО створення tweens
	## Зберігаємо оригінальні scale ПЕРЕД обнуленням
	var _orig_scales: Array[Vector2] = []
	for node: Variant in nodes:
		var ci: CanvasItem = node as CanvasItem
		if not is_instance_valid(ci):
			_orig_scales.append(Vector2.ONE)
			continue
		_orig_scales.append(ci.scale)
		if ci is Control:
			(ci as Control).pivot_offset = (ci as Control).size / 2.0
		ci.scale = Vector2.ZERO
		ci.modulate.a = 0.0
	## Staggered entrance з audio (Toddler: повільніше для кращого відстеження)
	var speed_mult: float = 1.4 if SettingsManager.age_group == 1 else 1.0
	var last_tw: Tween = null
	for i: int in nodes.size():
		var ci: CanvasItem = nodes[i] as CanvasItem
		if not is_instance_valid(ci):
			continue
		var target_s: Vector2 = _orig_scales[i] if i < _orig_scales.size() else Vector2.ONE
		var tw: Tween = _create_game_tween().set_parallel(true)
		var d: float = float(i) * delay_per_item * speed_mult
		tw.tween_property(ci, "scale", target_s * 1.1, 0.2 * speed_mult)\
			.set_delay(d).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ci, "modulate:a", 1.0, 0.15 * speed_mult).set_delay(d)
		tw.chain().tween_property(ci, "scale", target_s, 0.08 * speed_mult)
		## Audio: ascending pitch "pop" (кожен 2-й елемент якщо >8)
		if nodes.size() <= 8 or i % 2 == 0:
			var pitch: float = 0.85 + 0.4 * (float(i) / maxf(float(nodes.size() - 1), 1.0))
			tw.tween_callback(AudioManager.play_sfx.bind(sfx_name, pitch)).set_delay(d)
		last_tw = tw
	if unlock_input and last_tw:
		last_tw.finished.connect(func() -> void: _input_locked = false, CONNECT_ONE_SHOT)


## Idle breathing — subtle scale pulse для інтерактивних елементів.
## Per-node bound tweens: auto-destroyed when node is freed (memory safe).
## Call _stop_idle_breathing() before modifying item scales.
func _start_idle_breathing(nodes: Array) -> void:
	if SettingsManager.reduced_motion:
		return
	for node: CanvasItem in nodes:
		if not is_instance_valid(node):
			continue
		if node.has_meta("_breathing"):
			continue
		var base_scale: Vector2 = node.scale
		## Bind tween to node — auto-killed when node freed (no C++ crash)
		var tw: Tween = node.create_tween().bind_node(node).set_loops()
		tw.tween_property(node, "scale", base_scale * 1.03,
			randf_range(0.8, 1.2))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)\
			.set_delay(randf_range(0.0, 0.5))
		tw.tween_property(node, "scale", base_scale,
			randf_range(0.8, 1.2))\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		node.set_meta("_breathing", true)
		node.set_meta("_breathing_tween", tw)
		node.set_meta("_breathing_base_scale", base_scale)


## Stop breathing — kill per-node tweens, restore scales.
## Call before any item scale manipulation or round cleanup.
func _stop_idle_breathing(nodes: Array) -> void:
	for node: CanvasItem in nodes:
		if not is_instance_valid(node):
			continue
		if not node.has_meta("_breathing"):
			continue
		var tw: Tween = node.get_meta("_breathing_tween") as Tween
		if tw and tw.is_valid():
			tw.kill()
		## Restore base scale (CXO fix: prevent stuck mid-breath scale)
		var base_scale: Variant = node.get_meta("_breathing_base_scale")
		if base_scale is Vector2:
			node.scale = base_scale
		else:
			node.scale = Vector2.ONE
		node.remove_meta("_breathing")
		node.remove_meta("_breathing_tween")
		node.remove_meta("_breathing_base_scale")


## Анімація правильної відповіді — bounce + ripple VFX + streak combo.
## Дочірні класи можуть викликати.
func _animate_correct_item(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	_remove_glow_hint()  ## Зняти glow hint при правильній відповіді
	VFXManager.spawn_success_ripple(node.global_position, ThemeManager.COLOR_PRIMARY)
	## Streak combo VFX — прогресивне святкування серії правильних
	JuicyEffects.combo_vfx(node.global_position, _streak_count)
	if _streak_count >= STREAK_THRESHOLD:
		JuicyEffects.screen_shake(self, 3.0)
		JuicyEffects.combo_flash(node, self)
	## Variable celebration — 15% шанс premium VFX на звичайний correct (surprise & delight)
	if randf() < 0.15 and _streak_count >= 2:
		VFXManager.spawn_premium_celebration(node.global_position)
		AudioManager.play_sfx("reward")
	## Snap pulse VFX (без scale tween — bounce нижче вже є)
	VFXManager.spawn_snap_pulse(node.global_position)
	## Textured sparkle для streak ≥ 2 (LAW 28 premium feedback)
	if _streak_count >= 2:
		VFXManager.spawn_correct_sparkle(node.global_position)
	## Ripple feedback shader на background при правильній відповіді
	_apply_ripple_feedback(node.global_position)
	if SettingsManager.reduced_motion:
		return
	var original_scale: Vector2 = node.scale
	var tw: Tween = create_tween()
	tw.tween_property(node, "scale", original_scale * 1.2, 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", original_scale, 0.15)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Анімація помилки — м'яке хитання (Law 16: позитивна помилка, без harsh red).
func _animate_error_item(node: Node2D) -> void:
	if not is_instance_valid(node):
		return
	if SettingsManager.reduced_motion:
		return
	var original_pos: Vector2 = node.position
	var tw: Tween = create_tween()
	tw.tween_property(node, "position:x", original_pos.x - 8.0, 0.04)
	tw.tween_property(node, "position:x", original_pos.x + 8.0, 0.04)
	tw.tween_property(node, "position:x", original_pos.x - 4.0, 0.03)
	tw.tween_property(node, "position:x", original_pos.x + 4.0, 0.03)
	tw.tween_property(node, "position:x", original_pos.x, 0.03)


## Ripple feedback shader на background при correct answer.
## Створює 0.5с хвилю від позиції дотику (ripple_feedback.gdshader).
var _ripple_material: ShaderMaterial = null

func _apply_ripple_feedback(global_pos: Vector2) -> void:
	if SettingsManager.reduced_motion:
		return
	if not is_instance_valid(_bg_node):
		return
	## Lazy init ripple shader
	if not _ripple_material:
		var shader: Shader = load("res://assets/shaders/ripple_feedback.gdshader")
		if not shader:
			return
		_ripple_material = ShaderMaterial.new()
		_ripple_material.shader = shader
	## Конвертуємо global position → UV координати background
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var uv_center: Vector2 = global_pos / vp_size
	_ripple_material.set_shader_parameter("ripple_center", uv_center)
	_ripple_material.set_shader_parameter("ripple_time", 0.0)
	_ripple_material.set_shader_parameter("ripple_strength", 0.012)
	## next_pass — додатковий shader pass поверх існуючого bg_animated
	var existing_mat: Material = _bg_node.material
	if existing_mat:
		existing_mat.next_pass = _ripple_material
	else:
		_bg_node.material = _ripple_material
	## Анімуємо ripple_time 0→1.2 за 0.5с, потім знімаємо ripple pass
	var tw: Tween = create_tween()
	tw.tween_method(func(t: float) -> void:
		if _ripple_material:
			_ripple_material.set_shader_parameter("ripple_time", t),
		0.0, 1.2, 0.5)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_bg_node) and _bg_node.material:
			if _bg_node.material == _ripple_material:
				_bg_node.material = null
			elif _bg_node.material.next_pass == _ripple_material:
				_bg_node.material.next_pass = null)


## Glow pulse shader на hint target — пульсуюче підсвічення для idle hint level ≥ 1.
var _glow_hint_material: ShaderMaterial = null
var _glow_hint_node: CanvasItem = null

func _apply_glow_hint(node: CanvasItem) -> void:
	if SettingsManager.reduced_motion:
		return
	if not is_instance_valid(node):
		return
	_remove_glow_hint()
	## Lazy init glow shader
	if not _glow_hint_material:
		var shader: Shader = load("res://assets/shaders/glow_pulse.gdshader")
		if not shader:
			return
		_glow_hint_material = ShaderMaterial.new()
		_glow_hint_material.shader = shader
		_glow_hint_material.set_shader_parameter("glow_color", Color(1.0, 0.95, 0.4, 1.0))
		_glow_hint_material.set_shader_parameter("glow_intensity", 0.5)
		_glow_hint_material.set_shader_parameter("pulse_speed", 2.5)
	node.material = _glow_hint_material
	_glow_hint_node = node


func _remove_glow_hint() -> void:
	if is_instance_valid(_glow_hint_node) and _glow_hint_node.material == _glow_hint_material:
		_glow_hint_node.material = null
	_glow_hint_node = null


## LAW 26: Канонічна формула зірок — єдине джерело правди.
## Toddler → завжди 5. Preschool → clampi(5 - penalty / 2, 1, 5).
func _calculate_stars(penalty: int) -> int:
	if SettingsManager.age_group == 1:
		return 5
	@warning_ignore("integer_division")
	return clampi(5 - penalty / 2, 1, 5)


## LAW 24: Safety timeout — гра не може тривати вічно (A2).
## Кожна мінігра викликає це в _ready() зі своїм SAFETY_TIMEOUT_SEC.
func _start_safety_timeout(timeout_sec: float = 120.0) -> void:
	get_tree().create_timer(timeout_sec).timeout.connect(func() -> void:
		if not _game_finished:
			push_warning(game_id + ": SAFETY_TIMEOUT triggered after %.0fs" % timeout_sec)
			finish_game(_calculate_stars(0))
	)


## Прогрес раунду 0.0 -> 1.0 для масштабування складності.
## round 0 = 0.0, останній раунд = 1.0.
func _round_progress(current: int, total: int) -> float:
	if total <= 1:
		return 0.0
	return clampf(float(current) / float(total - 1), 0.0, 1.0)


## Лінійна інтерполяція float параметра за прогресом раунду.
## easy_val для раунду 0, hard_val для останнього раунду.
func _scale_by_round(easy_val: float, hard_val: float, current: int, total: int) -> float:
	return lerpf(easy_val, hard_val, _round_progress(current, total))


## Ступінчаста інтерполяція — повільний старт (comfort zone R1-2),
## крутий фініш (challenge R3-5). Research: діти потребують 80-90% success rate
## на початку для побудови впевненості, потім поступове ускладнення (Springer 2022).
## Використовувати замість _scale_by_round() для покращеної difficulty curve.
func _scale_stepped(easy_val: float, hard_val: float, current: int, total: int) -> float:
	var t: float = _round_progress(current, total)
	var curved_t: float = t * t  ## Quadratic ease-in: R1=0%, R2=6%, R3=25%, R4=56%, R5=100%
	return lerpf(easy_val, hard_val, curved_t)


## Ступінчаста інтерполяція int — аналог _scale_by_round_i з ease-in.
func _scale_stepped_i(easy_val: int, hard_val: int, current: int, total: int) -> int:
	return int(roundf(_scale_stepped(float(easy_val), float(hard_val), current, total)))


## Лінійна інтерполяція int параметра за прогресом раунду.
func _scale_by_round_i(easy_val: int, hard_val: int, current: int, total: int) -> int:
	return int(roundf(_scale_by_round(float(easy_val), float(hard_val), current, total)))


## Адаптивний фактор на основі ZPD (Zone of Proximal Development, Виготський).
## Повертає 0.0 (дитина бореться) .. 1.0 (дитина освоїла) за останні 2 раунди.
## Використовується в _scale_adaptive() для динамічного підлаштування складності.
func _get_adaptive_factor() -> float:
	if _round_errors.size() < 2:
		return 0.5  ## Недостатньо даних — дефолтна прогресія
	var recent: int = _round_errors[-1] + _round_errors[-2]
	if recent == 0:
		return 1.0  ## Бездоганні 2 раунди — прискорити
	elif recent >= 4:
		return 0.0  ## Багато помилок — сповільнити
	return clampf(1.0 - float(recent) / 4.0, 0.0, 1.0)


## Адаптивна інтерполяція — 70% лінійна + 30% за продуктивністю (ZPD blend).
## Opt-in: дочірній клас викликає замість _scale_by_round() для адаптивних ігор.
func _scale_adaptive(easy_val: float, hard_val: float, current: int, total: int) -> float:
	var linear: float = _scale_by_round(easy_val, hard_val, current, total)
	var factor: float = _get_adaptive_factor()
	var target: float = lerpf(easy_val, hard_val, factor)
	return lerpf(linear, target, 0.3)  ## 30% адаптивний вплив


## Адаптивна інтерполяція int — аналог _scale_by_round_i з ZPD.
func _scale_adaptive_i(easy_val: int, hard_val: int, current: int, total: int) -> int:
	return int(roundf(_scale_adaptive(float(easy_val), float(hard_val), current, total)))


## Записати помилки раунду для адаптивної складності.
## Дочірній клас викликає на початку нового раунду з помилками попереднього.
func _record_round_errors(errors_in_round: int) -> void:
	_round_errors.append(errors_in_round)


## Анімований перехід між раундами — "Round N / Total" card.
## on_done викликається після завершення анімації.
func _animate_round_transition(round_num: int, total: int, on_done: Callable) -> void:
	if SettingsManager and SettingsManager.reduced_motion:
		on_done.call()
		return
	if not _ui_layer:
		on_done.call()
		return
	var s: float = _ui_scale()
	var label: Label = Label.new()
	label.text = "%d / %d" % [round_num, total]
	label.add_theme_font_size_override("font_size", int(48.0 * s))
	label.add_theme_color_override("font_color", ThemeManager.COLOR_GOLD)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.scale = Vector2(0.3, 0.3)
	label.modulate.a = 0.0
	label.pivot_offset = get_viewport().get_visible_rect().size / 2.0
	## Dissolve shader для premium round transition
	var dissolve_shader: Shader = load("res://assets/shaders/dissolve.gdshader")
	if dissolve_shader:
		var dissolve_mat: ShaderMaterial = ShaderMaterial.new()
		dissolve_mat.shader = dissolve_shader
		dissolve_mat.set_shader_parameter("progress", 1.0)
		dissolve_mat.set_shader_parameter("edge_color", Vector4(ThemeManager.COLOR_GOLD.r,
			ThemeManager.COLOR_GOLD.g, ThemeManager.COLOR_GOLD.b, 1.0))
		dissolve_mat.set_shader_parameter("edge_width", 0.08)
		label.material = dissolve_mat
	_ui_layer.add_child(label)
	var tw: Tween = create_tween()
	## Appear: dissolve in (progress 1→0) + scale pop
	if label.material is ShaderMaterial:
		tw.tween_method(func(p: float) -> void:
			if is_instance_valid(label) and label.material:
				(label.material as ShaderMaterial).set_shader_parameter("progress", p),
			1.0, 0.0, 0.25)
	tw.parallel().tween_property(label, "scale", Vector2(1.1, 1.1), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 1.0, 0.15)
	tw.tween_property(label, "scale", Vector2.ONE, 0.08)
	tw.tween_interval(0.35)
	## Disappear: dissolve out (progress 0→1)
	if label.material is ShaderMaterial:
		tw.tween_method(func(p: float) -> void:
			if is_instance_valid(label) and label.material:
				(label.material as ShaderMaterial).set_shader_parameter("progress", p),
			0.0, 1.0, 0.25)
	else:
		tw.tween_property(label, "modulate:a", 0.0, 0.2)
	tw.tween_callback(label.queue_free)
	tw.tween_callback(on_done)


## Physics-based pulse анімація для idle hints — BACK→ELASTIC замість LINEAR.
## Дочірні класи викликають замість ручного tween_property scale.
var _pulse_tween: Tween = null

func _pulse_node(node: CanvasItem, intensity: float = 1.2) -> void:
	if not is_instance_valid(node):
		return
	if SettingsManager.reduced_motion:
		return
	## A10 level 1: glow shader на правильний елемент (диференціація від level 0)
	if _idle_hint_level >= 1:
		_apply_glow_hint(node)
	## Перервати попередній pulse щоб уникнути stacking
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	var orig: Vector2 = node.scale
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(node, "scale", orig * intensity, 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(node, "scale", orig, 0.25)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Safe area margins — Rect2i(left, top, right, bottom).
## На пристроях без нотча повертає нулі.
static func _get_safe_margins() -> Rect2i:
	var screen: Rect2i = DisplayServer.get_display_safe_area()
	var full: Vector2i = DisplayServer.screen_get_size()
	if screen.size.x == 0 or full.x == 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(
		screen.position.x,       ## left
		screen.position.y,       ## top
		full.x - screen.end.x,   ## right
		full.y - screen.end.y,   ## bottom
	)


## Deferred premium UI pass — викликається через process_frame після всіх _ready().
func _deferred_premium_ui_pass() -> void:
	_apply_premium_ui_pass(self)


## Автоматичний premium UI pass — глянець на великих панелях, spacing для контейнерів,
## примусове застосування глобальної теми на Control без теми.
func _apply_premium_ui_pass(node: Node) -> void:
	## Force theme on root-level Controls (parent is NOT Control — e.g., child of Node2D/CanvasLayer)
	## Не чіпаємо вкладені Controls — вони наслідують тему від батька через Godot inheritance chain
	if node is Control:
		var ctrl: Control = node as Control
		if ctrl.theme == null and not (ctrl.get_parent() is Control):
			if get_tree().root.theme != null:
				ctrl.theme = get_tree().root.theme
	## Container spacing enforcement — shadows need breathing room
	if node is GridContainer:
		var gc: GridContainer = node as GridContainer
		if gc.get_theme_constant("h_separation") < 12:
			gc.add_theme_constant_override("h_separation", 12)
		if gc.get_theme_constant("v_separation") < 12:
			gc.add_theme_constant_override("v_separation", 12)
	elif node is HBoxContainer and not node is MenuBar:
		var hb: HBoxContainer = node as HBoxContainer
		if hb.get_theme_constant("separation") < 10:
			hb.add_theme_constant_override("separation", 10)
	elif node is VBoxContainer:
		var vb: VBoxContainer = node as VBoxContainer
		if vb.get_theme_constant("separation") < 10:
			vb.add_theme_constant_override("separation", 10)
	## Auto-gloss on large panels (skip dark/transparent — white highlight looks wrong)
	if node is Panel and not node.has_meta("_has_gloss"):
		var panel: Panel = node as Panel
		if panel.size.x >= 60.0 and panel.size.y >= 60.0:
			var sb: StyleBox = panel.get_theme_stylebox("panel")
			var skip_gloss: bool = false
			if sb is StyleBoxFlat:
				var bg: Color = (sb as StyleBoxFlat).bg_color
				var lum: float = bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114
				if lum < 0.3 or bg.a < 0.5:
					skip_gloss = true
			if not skip_gloss:
				panel.set_meta("_has_gloss", true)
				GameData.add_gloss(panel)
	## Auto gloss on smaller candy panels (≥40px) for uniform depth (LAW 28 V162)
	## Основний gloss (line 1376) покриває ≥60px — тут ловимо менші елементи (40-59px)
	if node is Panel and not node.has_meta("_has_gloss"):
		var p_sm: Panel = node as Panel
		if p_sm.size.x >= 40.0 and p_sm.size.y >= 40.0 and p_sm.size.x < 60.0:
			var sb_sm: StyleBox = p_sm.get_theme_stylebox("panel")
			var skip_sm: bool = false
			if sb_sm is StyleBoxFlat:
				var bg_sm: Color = (sb_sm as StyleBoxFlat).bg_color
				var lum_sm: float = bg_sm.r * 0.299 + bg_sm.g * 0.587 + bg_sm.b * 0.114
				if lum_sm < 0.3 or bg_sm.a < 0.5:
					skip_sm = true
			if not skip_sm:
				p_sm.set_meta("_has_gloss", true)
				GameData.add_gloss(p_sm, 12)
	## Auto grain material on candy-styled panels without material (LAW 28 V162)
	## Додає тактильну текстуру зернистості як на splash/main menu елементах
	if node is Panel and not node.has_meta("_has_grain"):
		var p_gr: Panel = node as Panel
		if p_gr.size.x >= 40.0 and p_gr.size.y >= 40.0 and p_gr.material == null:
			var sb_gr: StyleBox = p_gr.get_theme_stylebox("panel")
			if sb_gr is StyleBoxFlat:
				var flat_gr: StyleBoxFlat = sb_gr as StyleBoxFlat
				if flat_gr.bg_color.a > 0.4 and (flat_gr.shadow_size > 0 or flat_gr.border_width_bottom > 0):
					p_gr.set_meta("_has_grain", true)
					p_gr.material = GameData.create_premium_material(
						0.03, 2.0, 0.04, 0.06, 0.0, 0.04, 0.10, "", 0.0, 0.08, 0.18, 0.15)
	## Recurse children
	for child: Node in node.get_children():
		_apply_premium_ui_pass(child)
