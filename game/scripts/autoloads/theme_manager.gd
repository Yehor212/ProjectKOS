extends Node

## Глобальний менеджер теми — «Juicy 3D» палітра для дитячого UI.
## Завантажує Nunito Bold та налаштовує стилі Button/SecondaryButton/Label/Panel.
## Зареєстрований як autoload ДО SceneManager, щоб тема була готова з першого кадру.

## --- Кольорова палітра «Juicy 3D Kids» ---
const COLOR_SKY_BLUE: Color = Color("37B6F6")       ## Фон / Spring Sky
const COLOR_SOFT_NEUTRAL: Color = Color("FDFBF7")   ## Панелі контенту
const COLOR_PRIMARY: Color = Color("06d6a0")         ## Play/Go — м'ятний
const COLOR_PRIMARY_DEPTH: Color = Color("04a077")   ## 3D-тінь основних кнопок
const COLOR_SECONDARY: Color = Color("ffb5a7")       ## Back/Close — ніжно-рожевий
const COLOR_SECONDARY_DEPTH: Color = Color("e5989b") ## 3D-тінь вторинних кнопок
const COLOR_CHARCOAL: Color = Color("2C3539")        ## Дорослий / батьківський текст
const COLOR_GOLD: Color = Color("FFD166")            ## Зірки, нагороди, акцент
const COLOR_GOLD_DEPTH: Color = Color("e6a817")      ## 3D-тінь золотих кнопок
const COLOR_SURFACE_GLASS: Color = Color(1, 1, 1, 0.30)  ## Скляні панелі (V164: 0.12→0.30)

## --- Розширена палітра (UI consistency) ---
const COLOR_SUCCESS: Color = Color("22c55e")             ## Resume / confirm — зелений
const COLOR_ERROR: Color = Color("ef4444")               ## Exit / cancel — червоний
const COLOR_PRESCHOOL: Color = Color("7b68ee")           ## Preschool age badge — фіолетовий
const COLOR_BADGE_LOCKED: Color = Color("b8c0cc")        ## Locked / unavailable — сірий

## --- Spacing (8pt grid) ---
const SPACE_XS: int = 4
const SPACE_SM: int = 8
const SPACE_MD: int = 16
const SPACE_LG: int = 24
const SPACE_XL: int = 32

## --- Juicy 3D параметри ---
const CANDY_RADIUS: int = 32
const CANDY_BORDER: int = 6
const CANDY_SHADOW_SIZE: int = 6


var _global_theme: Theme = null
var _btn_textures: Dictionary = {}  ## {"green_normal": Texture2D, ...}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_global_theme = _build_theme()
	get_tree().root.theme = _global_theme
	## Автоматичний click SFX на всі кнопки через SceneTree
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		if not node.pressed.is_connected(_play_button_sfx):
			node.pressed.connect(_play_button_sfx)


static func _play_button_sfx() -> void:
	AudioManager.play_sfx("click")


func get_global_theme() -> Theme:
	return _global_theme


func _load_btn_textures() -> void:
	var base: String = "res://assets/textures/ui/buttons/"
	var colors: Array[String] = ["green", "yellow", "red", "grey"]
	for c in colors:
		var n_path: String = base + "btn_rect_%s_normal.png" % c
		var p_path: String = base + "btn_rect_%s_pressed.png" % c
		if ResourceLoader.exists(n_path) and ResourceLoader.exists(p_path):
			_btn_textures[c + "_normal"] = load(n_path)
			_btn_textures[c + "_pressed"] = load(p_path)
	## Круглі кнопки — всі кольори (Kenney UI Pack, CC0)
	var round_colors: Array[String] = ["blue", "green", "red", "yellow"]
	for rc in round_colors:
		var rn: String = base + "btn_round_%s_normal.png" % rc
		var rp: String = base + "btn_round_%s_pressed.png" % rc
		if ResourceLoader.exists(rn) and ResourceLoader.exists(rp):
			_btn_textures["round_%s_normal" % rc] = load(rn)
			_btn_textures["round_%s_pressed" % rc] = load(rp)
	## Backward compat: "round_normal" -> blue
	if _btn_textures.has("round_blue_normal"):
		_btn_textures["round_normal"] = _btn_textures["round_blue_normal"]
		_btn_textures["round_pressed"] = _btn_textures["round_blue_pressed"]
	## Gloss текстури — м'які кнопки з бликом (Kenney UI Pack, CC0)
	var gloss_shapes: Dictionary = {
		"rect": "btn_rectangle_%s_gloss.png",
		"square": "btn_square_%s_gloss.png",
		"round": "btn_round_%s_gloss.png",
	}
	var gloss_colors: Array[String] = ["blue", "green", "red", "yellow"]
	for shape_key: String in gloss_shapes:
		for gc: String in gloss_colors:
			var g_path: String = base + gloss_shapes[shape_key] % gc
			if ResourceLoader.exists(g_path):
				_btn_textures["gloss_%s_%s" % [shape_key, gc]] = load(g_path)
	if _btn_textures.is_empty():
		push_warning("ThemeManager: текстури кнопок не знайдено, fallback на StyleBoxFlat")


func _build_theme() -> Theme:
	_load_btn_textures()
	var font_bold: Font = _load_font("res://assets/fonts/Nunito-Bold.ttf")
	if font_bold == null:
		font_bold = _get_fallback_font()
	var font_btn: FontVariation = FontVariation.new()
	font_btn.base_font = font_bold
	font_btn.spacing_glyph = 2

	var theme: Theme = Theme.new()
	theme.default_font = font_bold
	theme.default_font_size = 24

	# --- Primary Button ---
	theme.set_font("font", "Button", font_btn)
	theme.set_font_size("font_size", "Button", 28)
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.6, 0.6, 0.6, 0.5))
	theme.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.15))
	theme.set_constant("outline_size", "Button", 4)

	var dis_color: Color = Color(0.4, 0.4, 0.4, 0.5)
	var dis_depth: Color = Color(0.25, 0.25, 0.25, 0.5)
	theme.set_stylebox("normal", "Button",
		make_soft_style(COLOR_PRIMARY, COLOR_PRIMARY_DEPTH))
	theme.set_stylebox("hover", "Button",
		make_soft_style(COLOR_PRIMARY.lightened(0.05), COLOR_PRIMARY_DEPTH))
	theme.set_stylebox("pressed", "Button",
		make_soft_style(COLOR_PRIMARY, COLOR_PRIMARY_DEPTH, CANDY_RADIUS, true))
	theme.set_stylebox("disabled", "Button",
		make_soft_style(dis_color, dis_depth))

	# --- SecondaryButton (варіація для назад / скасувати / вийти) ---
	theme.set_type_variation("SecondaryButton", "Button")
	theme.set_stylebox("normal", "SecondaryButton",
		make_soft_style(COLOR_SECONDARY, COLOR_SECONDARY_DEPTH))
	theme.set_stylebox("hover", "SecondaryButton",
		make_soft_style(COLOR_SECONDARY.lightened(0.05), COLOR_SECONDARY_DEPTH))
	theme.set_stylebox("pressed", "SecondaryButton",
		make_soft_style(COLOR_SECONDARY, COLOR_SECONDARY_DEPTH, CANDY_RADIUS, true))
	theme.set_stylebox("disabled", "SecondaryButton",
		make_soft_style(dis_color, dis_depth))
	theme.set_color("font_outline_color", "SecondaryButton", Color(0, 0, 0, 0.15))
	theme.set_constant("outline_size", "SecondaryButton", 4)

	# --- CircleButton (back, pause, direction arrows — soft circle) ---
	theme.set_type_variation("CircleButton", "Button")
	theme.set_font_size("font_size", "CircleButton", 26)
	theme.set_stylebox("normal", "CircleButton",
		make_soft_style(COLOR_PRIMARY, COLOR_PRIMARY_DEPTH, 999))
	theme.set_stylebox("hover", "CircleButton",
		make_soft_style(COLOR_PRIMARY.lightened(0.05), COLOR_PRIMARY_DEPTH, 999))
	theme.set_stylebox("pressed", "CircleButton",
		make_soft_style(COLOR_PRIMARY, COLOR_PRIMARY_DEPTH, 999, true))
	theme.set_stylebox("disabled", "CircleButton",
		make_soft_style(dis_color, dis_depth, 999))
	theme.set_color("font_outline_color", "CircleButton", Color(0, 0, 0, 0.2))
	theme.set_constant("outline_size", "CircleButton", 3)

	# --- PillButton (action buttons — soft pill) ---
	theme.set_type_variation("PillButton", "Button")
	theme.set_font_size("font_size", "PillButton", 24)
	theme.set_stylebox("normal", "PillButton",
		make_soft_style(COLOR_PRIMARY, COLOR_PRIMARY_DEPTH, 999))
	theme.set_stylebox("hover", "PillButton",
		make_soft_style(COLOR_PRIMARY.lightened(0.05), COLOR_PRIMARY_DEPTH, 999))
	theme.set_stylebox("pressed", "PillButton",
		make_soft_style(COLOR_PRIMARY, COLOR_PRIMARY_DEPTH, 999, true))
	theme.set_stylebox("disabled", "PillButton",
		make_soft_style(dis_color, dis_depth, 999))
	theme.set_color("font_outline_color", "PillButton", Color(0, 0, 0, 0.15))
	theme.set_constant("outline_size", "PillButton", 4)

	# --- AccentButton (primary CTA — gold soft) ---
	theme.set_type_variation("AccentButton", "Button")
	theme.set_font_size("font_size", "AccentButton", 28)
	theme.set_stylebox("normal", "AccentButton",
		make_soft_style(COLOR_GOLD, COLOR_GOLD_DEPTH))
	theme.set_stylebox("hover", "AccentButton",
		make_soft_style(COLOR_GOLD.lightened(0.05), COLOR_GOLD_DEPTH))
	theme.set_stylebox("pressed", "AccentButton",
		make_soft_style(COLOR_GOLD, COLOR_GOLD_DEPTH, CANDY_RADIUS, true))
	theme.set_stylebox("disabled", "AccentButton",
		make_soft_style(dis_color, dis_depth))
	theme.set_color("font_color", "AccentButton", Color.WHITE)
	theme.set_color("font_outline_color", "AccentButton", Color(0, 0, 0, 0.2))
	theme.set_constant("outline_size", "AccentButton", 5)

	# --- CheckButton (toggle — flat glass, не candy nine-patch) ---
	var cb_normal: StyleBoxFlat = StyleBoxFlat.new()
	cb_normal.bg_color = Color(1, 1, 1, 0.08)
	cb_normal.set_corner_radius_all(16)
	cb_normal.content_margin_left = 16
	cb_normal.content_margin_right = 16
	cb_normal.content_margin_top = 12
	cb_normal.content_margin_bottom = 12
	var cb_hover: StyleBoxFlat = StyleBoxFlat.new()
	cb_hover.bg_color = Color(1, 1, 1, 0.14)
	cb_hover.set_corner_radius_all(16)
	cb_hover.content_margin_left = 16
	cb_hover.content_margin_right = 16
	cb_hover.content_margin_top = 12
	cb_hover.content_margin_bottom = 12
	var cb_pressed: StyleBoxFlat = StyleBoxFlat.new()
	cb_pressed.bg_color = Color(1, 1, 1, 0.05)
	cb_pressed.set_corner_radius_all(16)
	cb_pressed.content_margin_left = 16
	cb_pressed.content_margin_right = 16
	cb_pressed.content_margin_top = 12
	cb_pressed.content_margin_bottom = 12
	theme.set_stylebox("normal", "CheckButton", cb_normal)
	theme.set_stylebox("hover", "CheckButton", cb_hover)
	theme.set_stylebox("pressed", "CheckButton", cb_pressed)
	theme.set_stylebox("disabled", "CheckButton", cb_pressed)
	theme.set_color("font_color", "CheckButton", Color.WHITE)
	theme.set_color("font_hover_color", "CheckButton", Color.WHITE)
	theme.set_font_size("font_size", "CheckButton", 20)

	# --- OptionButton (dropdown — flat glass, не candy nine-patch) ---
	var ob_normal: StyleBoxFlat = StyleBoxFlat.new()
	ob_normal.bg_color = Color(1, 1, 1, 0.10)
	ob_normal.set_corner_radius_all(16)
	ob_normal.content_margin_left = 16
	ob_normal.content_margin_right = 40
	ob_normal.content_margin_top = 12
	ob_normal.content_margin_bottom = 12
	var ob_hover: StyleBoxFlat = StyleBoxFlat.new()
	ob_hover.bg_color = Color(1, 1, 1, 0.16)
	ob_hover.set_corner_radius_all(16)
	ob_hover.content_margin_left = 16
	ob_hover.content_margin_right = 40
	ob_hover.content_margin_top = 12
	ob_hover.content_margin_bottom = 12
	var ob_pressed: StyleBoxFlat = StyleBoxFlat.new()
	ob_pressed.bg_color = Color(1, 1, 1, 0.06)
	ob_pressed.set_corner_radius_all(16)
	ob_pressed.content_margin_left = 16
	ob_pressed.content_margin_right = 40
	ob_pressed.content_margin_top = 12
	ob_pressed.content_margin_bottom = 12
	theme.set_stylebox("normal", "OptionButton", ob_normal)
	theme.set_stylebox("hover", "OptionButton", ob_hover)
	theme.set_stylebox("pressed", "OptionButton", ob_pressed)
	theme.set_stylebox("disabled", "OptionButton", ob_pressed)
	theme.set_color("font_color", "OptionButton", Color.WHITE)
	theme.set_color("font_hover_color", "OptionButton", Color.WHITE)
	theme.set_font_size("font_size", "OptionButton", 20)

	# --- Label ---
	theme.set_font("font", "Label", font_bold)
	theme.set_font_size("font_size", "Label", 24)
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 2)

	# --- Font hierarchy: Fredoka для заголовків → fallback Nunito ExtraBold → Bold ---
	var heading_font: Font = _load_font("res://assets/fonts/FredokaOne-Regular.ttf")
	if heading_font == null:
		heading_font = _load_font("res://assets/fonts/Nunito-ExtraBold.ttf")
	if heading_font == null:
		heading_font = font_bold
	var heading_variation: FontVariation = FontVariation.new()
	heading_variation.base_font = heading_font
	heading_variation.spacing_glyph = 3

	# --- HeadingLabel — секційні заголовки (42px) ---
	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_font("font", "HeadingLabel", heading_variation)
	theme.set_font_size("font_size", "HeadingLabel", 42)
	theme.set_color("font_color", "HeadingLabel", COLOR_CHARCOAL)
	theme.set_color("font_outline_color", "HeadingLabel", Color(0, 0, 0, 0.18))
	theme.set_constant("outline_size", "HeadingLabel", 6)
	theme.set_color("font_shadow_color", "HeadingLabel", Color(0, 0, 0, 0.12))
	theme.set_constant("shadow_offset_x", "HeadingLabel", 2)
	theme.set_constant("shadow_offset_y", "HeadingLabel", 3)

	# --- TitleLabel — великі екранні заголовки (56px, золотий) ---
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", heading_variation)
	theme.set_font_size("font_size", "TitleLabel", 56)
	theme.set_color("font_color", "TitleLabel", COLOR_GOLD)
	theme.set_color("font_outline_color", "TitleLabel", Color(0, 0, 0, 0.22))
	theme.set_constant("outline_size", "TitleLabel", 8)
	theme.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.15))
	theme.set_constant("shadow_offset_x", "TitleLabel", 2)
	theme.set_constant("shadow_offset_y", "TitleLabel", 4)

	# --- PanelContainer (Soft Neutral — напівпрозорий крем) ---
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(COLOR_SOFT_NEUTRAL, 0.9)
	panel_style.set_corner_radius_all(16)
	panel_style.anti_aliasing_size = 1.0
	panel_style.set_content_margin_all(20)
	panel_style.shadow_color = Color(0, 0, 0, 0.12)
	panel_style.shadow_size = 6
	panel_style.shadow_offset = Vector2(0, 3)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(1, 1, 1, 0.15)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# --- HSlider (повзунок гучності) ---
	var slider_bg: StyleBoxFlat = StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.3, 0.3, 0.3, 0.6)
	slider_bg.set_corner_radius_all(4)
	slider_bg.anti_aliasing_size = 1.0
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", slider_bg)

	var slider_fill: StyleBoxFlat = StyleBoxFlat.new()
	slider_fill.bg_color = COLOR_PRIMARY
	slider_fill.set_corner_radius_all(4)
	slider_fill.anti_aliasing_size = 1.0
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	# --- ProgressBar (candy pill bar with depth — LAW 28) ---
	var progress_bg: StyleBoxFlat = StyleBoxFlat.new()
	progress_bg.bg_color = Color(0.12, 0.12, 0.15, 0.55)
	progress_bg.set_corner_radius_all(8)
	progress_bg.anti_aliasing_size = 1.0
	progress_bg.set_border_width_all(1)
	progress_bg.border_color = Color(0, 0, 0, 0.2)
	progress_bg.set_content_margin_all(0)
	theme.set_stylebox("background", "ProgressBar", progress_bg)

	var progress_fill: StyleBoxFlat = StyleBoxFlat.new()
	progress_fill.bg_color = COLOR_PRIMARY
	progress_fill.set_corner_radius_all(8)
	progress_fill.anti_aliasing_size = 1.0
	progress_fill.set_border_width_all(1)
	progress_fill.border_color = COLOR_PRIMARY_DEPTH
	progress_fill.shadow_color = Color(0, 0, 0, 0.15)
	progress_fill.shadow_size = 2
	progress_fill.shadow_offset = Vector2(0, 1)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)

	return theme


## Публічний метод — candy кнопка з Kenney текстурою (прямокутна/овальна).
## Доступні кольори: "green", "red", "yellow", "grey".
## Fallback на flat candy якщо текстура не знайдена.
func make_candy_style(color_key: String, fallback_color: Color,
		fallback_depth: Color, pressed: bool = false) -> StyleBox:
	var tex_key: String = color_key + ("_pressed" if pressed else "_normal")
	if not _btn_textures.has(tex_key):
		return _make_candy_style_flat(fallback_color, fallback_depth, pressed)

	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = _btn_textures[tex_key]

	## Nine-patch margins — кути текстури (306×148).
	## Сума top+bottom (45) < мінімальної кнопки (60px parental_gate).
	style.texture_margin_left = 30
	style.texture_margin_right = 30
	style.texture_margin_top = 20
	style.texture_margin_bottom = 25 if not pressed else 20

	## Горизонтально — TILE_FIT: candy-смуги повторюються рівномірно.
	## Вертикально — STRETCH: стискає центр без тайлінгу.
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH

	## Content margins — мінімальний відступ тексту від країв
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_bottom = 6
	style.content_margin_top = 6 + CANDY_BORDER if pressed else 6

	return style


func _make_candy_style_flat(color: Color, depth_color: Color,
		pressed: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	## Brighten top slightly for "lit from above" candy effect (V164)
	style.bg_color = color.lightened(0.08) if not pressed else color.darkened(0.05)
	style.set_corner_radius_all(CANDY_RADIUS)
	style.anti_aliasing_size = 1.5
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_bottom = 18
	if pressed:
		style.border_width_bottom = 0
		style.content_margin_top = 18 + CANDY_BORDER
		style.shadow_size = 0
	else:
		## Bottom depth border (layer 2)
		style.border_width_bottom = CANDY_BORDER
		style.border_color = depth_color
		## Blend border with bg for softer candy depth
		style.border_blend = true
		style.content_margin_top = 18
		## Stronger shadow for more depth (V164)
		style.shadow_color = Color(0, 0, 0, 0.22)
		style.shadow_size = CANDY_SHADOW_SIZE + 2
		style.shadow_offset = Vector2(0, 5)
	return style


func _make_glass_circle(bg: Color, pressed: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	## Ensure solid visibility — at least 30% alpha (V164)
	style.bg_color = Color(bg.r, bg.g, bg.b, maxf(bg.a, 0.30))
	style.set_corner_radius_all(999)
	style.anti_aliasing_size = 1.5
	style.set_content_margin_all(14)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.55)
	if pressed:
		style.shadow_size = 0
		style.border_color = Color(1, 1, 1, 0.20)
	else:
		style.shadow_color = Color(0, 0, 0, 0.25)
		style.shadow_size = 10
		style.shadow_offset = Vector2(0, 5)
	return style


func _make_circle_style(pressed: bool = false) -> StyleBox:
	return make_circle_texture_style("blue", pressed)


## Публічний метод — candy кругла кнопка з текстурою для будь-якого кольору.
## Доступні кольори: "blue", "green", "red", "yellow".
## Fallback на glass circle якщо текстура не знайдена.
func make_circle_texture_style(color_key: String, pressed: bool = false) -> StyleBox:
	var tex_key: String = "round_%s_%s" % [color_key, "pressed" if pressed else "normal"]
	if not _btn_textures.has(tex_key):
		## Fallback: спробувати generic round
		var gen_key: String = "round_%s" % ("pressed" if pressed else "normal")
		if _btn_textures.has(gen_key):
			tex_key = gen_key
		else:
			return _make_glass_circle(COLOR_SURFACE_GLASS, pressed)

	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = _btn_textures[tex_key]
	## 128×128 Kenney candy кругла текстура
	## Сума top+bottom < найменшої кнопки (64px back buttons)
	var margin: int = 20
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = 26 if not pressed else margin
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.set_content_margin_all(8)
	return style


## Публічний метод — м'яка gloss кнопка (прямокутник, квадрат або коло).
## shape: "rect", "square", "round". color: "green", "red", "blue", "yellow".
## Fallback на candy_style_flat якщо текстура не знайдена.
func make_gloss_style(shape: String, color: String, pressed: bool = false) -> StyleBox:
	var tex_key: String = "gloss_%s_%s" % [shape, color]
	if not _btn_textures.has(tex_key):
		push_warning("ThemeManager: gloss texture not found: %s, fallback" % tex_key)
		return _make_candy_style_flat(COLOR_PRIMARY, COLOR_PRIMARY_DEPTH, pressed)
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = _btn_textures[tex_key]
	if pressed:
		style.modulate_color = Color(0.85, 0.85, 0.85, 1.0)
	## Nine-patch margins — кути gloss текстури
	var margin: int = 24 if shape == "round" else 20
	var bottom: int = 30 if not pressed else margin
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = bottom
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.set_content_margin_all(10)
	return style


## Публічний метод — м'яка плоска кнопка без текстури (modern flat).
## Для головного меню: чистий колір, скруглені кути, ніжна тінь.
func make_soft_style(color: Color, _depth_color: Color,
		corner: int = CANDY_RADIUS, pressed: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color if not pressed else color.darkened(0.08)
	style.set_corner_radius_all(corner)
	style.anti_aliasing_size = 1.5
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	if not pressed:
		style.shadow_color = Color(0, 0, 0, 0.18)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 4)
	else:
		style.shadow_color = Color(0, 0, 0, 0.08)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0, 1)
	return style


func _make_pill_style(color: Color, depth_color: Color,
		pressed: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(999)
	style.anti_aliasing_size = 1.0
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_bottom = 14
	if pressed:
		style.border_width_bottom = 0
		style.content_margin_top = 14 + 4
		style.shadow_size = 0
	else:
		style.border_width_bottom = 4
		style.border_color = depth_color
		style.content_margin_top = 14
		style.shadow_color = Color(0, 0, 0, 0.18)
		style.shadow_size = CANDY_SHADOW_SIZE
		style.shadow_offset = Vector2(0, 3)
	return style


func _load_font(path: String) -> Font:
	var ff := FontFile.new()
	if ff.load_dynamic_font(path) == OK:
		return ff
	if ResourceLoader.exists(path):
		var font: Font = load(path) as Font
		if font != null:
			return font
	push_warning("ThemeManager: шрифт '%s' не знайдено, fallback" % path)
	return null


func _get_fallback_font() -> Font:
	var fallback: Font = ThemeDB.fallback_font
	if fallback != null:
		return fallback
	push_error("ThemeManager: ThemeDB.fallback_font == null, SystemFont")
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([])
	return sf
