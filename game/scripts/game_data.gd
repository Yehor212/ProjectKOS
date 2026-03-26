class_name GameData
extends RefCounted

# --- Game constants ---
const ANIMAL_Y_FACTOR: float = 0.3
const FOOD_Y_FACTOR: float = 0.8
const MAX_ROUNDS: int = 10

# --- UI text keys (pass through tr() at call site) ---
const TEXT_CORRECT: String = "MSG_CORRECT"
const TEXT_WRONG: String = "MSG_WRONG"
const TEXT_WIN: String = "MSG_WIN"

## --- LAW 25: Color-blind secondary encoding — canonical color→pattern mapping ---
const COLOR_BLIND_PATTERNS: Dictionary = {
	"red": "stripes", "blue": "dots", "green": "waves",
	"yellow": "star", "purple": "diamond", "orange": "cross",
	"pink": "heart", "white": "ring", "cream": "triangle",
	"light_blue": "chevron",
}
## Color value → pattern (for games that use Color objects instead of string IDs)
const _CB_COLOR_MAP: Dictionary = {
	## color_pop
	Color("ef4444"): "stripes", Color("3b82f6"): "dots", Color("22c55e"): "waves",
	Color("eab308"): "star", Color("a855f7"): "diamond",
	## smart_coloring
	Color("ef476f"): "stripes", Color("06d6a0"): "waves", Color("118ab2"): "dots",
	Color("ffd166"): "star", Color("a78bfa"): "diamond", Color("fb923c"): "cross",
}

static func get_cb_pattern(color_id: String) -> String:
	return COLOR_BLIND_PATTERNS.get(color_id, "")

static func get_cb_pattern_for_color(color: Color) -> String:
	return _CB_COLOR_MAP.get(color, "")

# --- Animal-food pairs ---
# 19 unique 1:1 pairings. Each animal maps to exactly one food.
# Adding a pair: create matching .tscn scenes, then append a Dictionary here.
const ANIMALS_AND_FOOD: Array[Dictionary] = [
	{"name": "Bunny", "animal_scene": preload("res://scenes/animals/Bunny.tscn"), "food_scene": preload("res://scenes/food/Carrot.tscn")},
	{"name": "Dog", "animal_scene": preload("res://scenes/animals/Dog.tscn"), "food_scene": preload("res://scenes/food/Bone.tscn")},
	{"name": "Bear", "animal_scene": preload("res://scenes/animals/Bear.tscn"), "food_scene": preload("res://scenes/food/Honey.tscn")},
	{"name": "Monkey", "animal_scene": preload("res://scenes/animals/Monkey.tscn"), "food_scene": preload("res://scenes/food/Banana.tscn")},
	{"name": "Cat", "animal_scene": preload("res://scenes/animals/Cat.tscn"), "food_scene": preload("res://scenes/food/Fish.tscn")},
	{"name": "Chicken", "animal_scene": preload("res://scenes/animals/Chicken.tscn"), "food_scene": preload("res://scenes/food/Wheat.tscn")},
	{"name": "Cow", "animal_scene": preload("res://scenes/animals/Cow.tscn"), "food_scene": preload("res://scenes/food/Grass.tscn")},
	{"name": "Crocodile", "animal_scene": preload("res://scenes/animals/Crocodile.tscn"), "food_scene": preload("res://scenes/food/Drumstick.tscn")},
	{"name": "Frog", "animal_scene": preload("res://scenes/animals/Frog.tscn"), "food_scene": preload("res://scenes/food/Mosquito.tscn")},
	{"name": "Deer", "animal_scene": preload("res://scenes/animals/Deer.tscn"), "food_scene": preload("res://scenes/food/Leaf.tscn")},
	{"name": "Elephant", "animal_scene": preload("res://scenes/animals/Elephant.tscn"), "food_scene": preload("res://scenes/food/Watermelon.tscn")},
	{"name": "Horse", "animal_scene": preload("res://scenes/animals/Horse.tscn"), "food_scene": preload("res://scenes/food/Hay.tscn")},
	{"name": "Lion", "animal_scene": preload("res://scenes/animals/Lion.tscn"), "food_scene": preload("res://scenes/food/Meat.tscn")},
	{"name": "Penguin", "animal_scene": preload("res://scenes/animals/Penguin.tscn"), "food_scene": preload("res://scenes/food/Shrimp.tscn")},
	{"name": "Panda", "animal_scene": preload("res://scenes/animals/Panda.tscn"), "food_scene": preload("res://scenes/food/Bamboo.tscn")},
	{"name": "Goat", "animal_scene": preload("res://scenes/animals/Goat.tscn"), "food_scene": preload("res://scenes/food/Cabbage.tscn")},
	{"name": "Mouse", "animal_scene": preload("res://scenes/animals/Mouse.tscn"), "food_scene": preload("res://scenes/food/Cheese.tscn")},
	{"name": "Squirrel", "animal_scene": preload("res://scenes/animals/Squirrel.tscn"), "food_scene": preload("res://scenes/food/Walnut.tscn")},
	{"name": "Hedgehog", "animal_scene": preload("res://scenes/animals/Hedgehog.tscn"), "food_scene": preload("res://scenes/food/Apple.tscn")},
]


static func find_correct_food_name(animal_name: String) -> String:
	for pair: Dictionary in ANIMALS_AND_FOOD:
		if pair.name == animal_name:
			var parts: PackedStringArray = pair.food_scene.resource_path.get_file().split(".")
			if parts.size() > 0:
				return parts[0]
			return pair.name
	push_warning("GameData: no food found for animal '%s'" % animal_name)
	return ""


static func get_food_name_from_scene(food_scene: PackedScene) -> String:
	var parts: PackedStringArray = food_scene.resource_path.get_file().split(".")
	if parts.size() > 0:
		return parts[0]
	push_warning("GameData: empty food scene path")
	return ""


## ---- Candy UI Helpers — єдиний стиль для всіх міні-ігор ----

## Створює candy StyleBoxFlat для панелей (зони, картки, контейнери).
## Volumetric gummy: lightened surface, asymmetric depth border, tinted shadow.
static func candy_panel(bg_color: Color, corner: int = 24,
		with_shadow: bool = true) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color.lightened(0.06) if bg_color.get_luminance() > 0.1 else bg_color
	style.set_corner_radius_all(corner)
	style.anti_aliasing_size = 1.2
	## Volumetric candy depth — thick bottom lip, thin top frame (LAW 28 enhanced)
	style.border_width_bottom = 5
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_color = bg_color.darkened(0.22)
	if with_shadow:
		style.shadow_color = Color(bg_color.darkened(0.5), 0.35)
		style.shadow_size = 10
		style.shadow_offset = Vector2(0, 5)
	style.set_content_margin_all(12)
	return style


## Premium candy panel — глибша тінь, товщий бордер, подвійний shadow (LAW 28).
## Для ігор які хочуть рівень вище базового candy_panel.
static func candy_panel_premium(bg_color: Color, corner: int = 24) -> StyleBoxFlat:
	var style: StyleBoxFlat = candy_panel(bg_color, corner, true)
	## Посилена глибина — товщий bottom lip, ширша тінь
	style.border_width_bottom = 6
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 1
	style.anti_aliasing_size = 1.5
	## Подвійна тінь — зовнішня (розмита) + внутрішня (чітка)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	style.shadow_color = Color(bg_color.darkened(0.5), 0.40)
	## Збільшені внутрішні відступи для дихання контенту
	style.set_content_margin_all(16)
	return style


## Створює candy StyleBoxFlat для круглих елементів (монети, фішки, кнопки).
## Volumetric gummy: lightened surface, asymmetric depth border, tinted shadow.
static func candy_circle(bg_color: Color, radius: float,
		with_shadow: bool = true) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color.lightened(0.06) if bg_color.get_luminance() > 0.1 else bg_color
	style.set_corner_radius_all(int(radius))
	style.anti_aliasing_size = 1.2
	## Volumetric candy depth — gummy button feel (LAW 28 enhanced)
	style.border_width_bottom = 4
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_color = bg_color.darkened(0.25)
	if with_shadow:
		style.shadow_color = Color(bg_color.darkened(0.5), 0.35)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 4)
	return style


## Створює candy StyleBoxFlat для клітинок ігрової дошки (сітка, board cells).
## Volumetric gummy: lightened surface, asymmetric depth border, tinted shadow.
static func candy_cell(bg_color: Color, corner: int = 14,
		is_interactive: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color.lightened(0.06) if bg_color.get_luminance() > 0.1 else bg_color
	style.set_corner_radius_all(corner)
	style.anti_aliasing_size = 1.2
	## Volumetric candy depth (LAW 28 enhanced)
	style.border_width_bottom = 3
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_color = bg_color.darkened(0.22)
	style.shadow_color = Color(bg_color.darkened(0.5), 0.32)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 4)
	if is_interactive:
		## Stronger depth + glow для інтерактивних клітинок
		style.border_width_bottom = 5
		style.shadow_size = 9
		style.shadow_color = Color(bg_color.darkened(0.3), 0.4)
	return style


## Створює глянцевий верхній блік для Control (додає як child).
## Anchor-based — працює до layout pass (safe для automated injection).
static func add_gloss(parent: Control, corner: int = 20) -> Panel:
	var gloss: Panel = Panel.new()
	gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gloss.anchor_bottom = 0.35
	gloss.offset_left = 4.0
	gloss.offset_right = -4.0
	gloss.offset_top = 3.0
	gloss.offset_bottom = 0.0
	var g_style: StyleBoxFlat = StyleBoxFlat.new()
	g_style.bg_color = Color(1, 1, 1, 0.12)
	g_style.corner_radius_top_left = corner
	g_style.corner_radius_top_right = corner
	@warning_ignore("integer_division")
	g_style.corner_radius_bottom_left = maxi(corner / 2, 6)
	@warning_ignore("integer_division")
	g_style.corner_radius_bottom_right = maxi(corner / 2, 6)
	g_style.anti_aliasing_size = 1.0
	gloss.add_theme_stylebox_override("panel", g_style)
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gloss)
	return gloss


## Напівпрозора pill для тексту інструкції — glass-like.
static func instruction_pill(bg_color: Color = Color(0, 0, 0, 0.25)) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(20)
	style.anti_aliasing_size = 1.2
	## Glass-like pill з глибшою тінню (LAW 28 enhanced)
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.15)
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


## Золотиста pill для лічильника зірок.
static func star_pill() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(Color("FFD166"), 0.35)
	style.set_corner_radius_all(16)
	style.anti_aliasing_size = 1.5
	## Volumetric depth — subtle bottom lip (V164: increased visibility)
	style.border_width_bottom = 2
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 0
	style.border_color = Color(Color("FFD166"), 0.65)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


## Кругла кнопка з candy 3D depth для direction arrows та ін.
static func make_circle_btn_style(color: Color,
		pressed: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(999)
	style.anti_aliasing_size = 1.0
	style.set_content_margin_all(12)
	if pressed:
		style.border_width_bottom = 0
		style.shadow_size = 0
	else:
		style.border_width_bottom = 4
		style.border_color = color.darkened(0.2)
		style.shadow_color = Color(color.darkened(0.5), 0.25)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 2)
	return style


## Створює ShaderMaterial "alive" — дихання, моргання, реакції тварин.
static func create_alive_material() -> ShaderMaterial:
	var shader: Shader = load("res://assets/shaders/animal_alive.gdshader")
	if not shader:
		push_warning("GameData: animal_alive.gdshader не знайдено")
		return create_sway_material()
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("grain_tex", _get_grain_texture())
	mat.set_shader_parameter("grain_intensity", 0.0)  ## Grain вимкнений глобально
	## Premium 2.5D candy depth (LAW 28)
	mat.set_shader_parameter("depth_amount", 0.04)
	mat.set_shader_parameter("gloss_amount", 0.06)
	mat.set_shader_parameter("inner_shadow", 0.05)
	mat.set_shader_parameter("rim_light", 0.05)
	mat.set_shader_parameter("vibrance", 0.08)
	return mat


## Створює ShaderMaterial для хитання (sway) їжі.
static func create_sway_material() -> ShaderMaterial:
	var shader: Shader = load("res://assets/shaders/sway.gdshader")
	if not shader:
		push_warning("GameData: sway.gdshader не знайдено")
		return null
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("grain_tex", _get_grain_texture())
	mat.set_shader_parameter("grain_intensity", 0.0)  ## Grain вимкнений глобально
	## Premium 2.5D candy depth (LAW 28)
	mat.set_shader_parameter("depth_amount", 0.04)
	mat.set_shader_parameter("gloss_amount", 0.06)
	mat.set_shader_parameter("inner_shadow", 0.05)
	mat.set_shader_parameter("rim_light", 0.05)
	mat.set_shader_parameter("vibrance", 0.08)
	return mat


## Shared NoiseTexture2D — generated once, cached as static var (LAW 28).
static var _grain_texture: NoiseTexture2D = null


static func _get_grain_texture() -> NoiseTexture2D:
	if _grain_texture:
		return _grain_texture
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	noise.seed = 42
	## FBM фрактали — мультимасштабна текстура (крупне зерно + дрібна деталізація)
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	noise.fractal_gain = 0.4
	_grain_texture = NoiseTexture2D.new()
	_grain_texture.noise = noise
	_grain_texture.width = 256
	_grain_texture.height = 256
	_grain_texture.seamless = true
	return _grain_texture


## Candy grain material — subtle noise overlay для тактильної якості поверхні (LAW 28).
## Активовано: candy_grain.gdshader з 12 uniforms (grain, depth, gloss, specular, vibrance).
static func create_grain_material(intensity: float = 0.07,
		grain_scale: float = 2.0, depth: float = 0.0,
		gloss: float = 0.0, inner_shadow_amount: float = 0.0,
		rim_light_amount: float = 0.0, vibrance_amount: float = 0.0) -> ShaderMaterial:
	var shader: Shader = load("res://assets/shaders/candy_grain.gdshader")
	if not shader:
		push_warning("GameData: candy_grain.gdshader не знайдено")
		return null
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("grain_tex", _get_grain_texture())
	mat.set_shader_parameter("grain_intensity", intensity)
	mat.set_shader_parameter("grain_scale", grain_scale)
	mat.set_shader_parameter("depth_amount", depth)
	mat.set_shader_parameter("gloss_amount", gloss)
	mat.set_shader_parameter("inner_shadow", inner_shadow_amount)
	mat.set_shader_parameter("rim_light", rim_light_amount)
	mat.set_shader_parameter("vibrance", vibrance_amount)
	return mat


## Premium grain material — з текстурою поверхні та specular (LAW 28).
## Розширення create_grain_material для HQ-візуалів: specular spot, surface texture, shadow softness.
static func create_premium_material(intensity: float = 0.05,
		grain_scale: float = 1.5, depth: float = 0.06,
		gloss: float = 0.10, inner_shadow_amount: float = 0.08,
		rim_light_amount: float = 0.06, vibrance_amount: float = 0.1,
		texture_path: String = "", texture_blend: float = 0.0,
		specular_size: float = 0.0, specular_intensity: float = 0.0,
		shadow_softness: float = 0.0) -> ShaderMaterial:
	var shader: Shader = load("res://assets/shaders/candy_grain.gdshader")
	if not shader:
		push_warning("GameData: candy_grain.gdshader не знайдено")
		return null
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("grain_tex", _get_grain_texture())
	mat.set_shader_parameter("grain_intensity", intensity)
	mat.set_shader_parameter("grain_scale", grain_scale)
	mat.set_shader_parameter("depth_amount", depth)
	mat.set_shader_parameter("gloss_amount", gloss)
	mat.set_shader_parameter("inner_shadow", inner_shadow_amount)
	mat.set_shader_parameter("rim_light", rim_light_amount)
	mat.set_shader_parameter("vibrance", vibrance_amount)
	mat.set_shader_parameter("shadow_softness", shadow_softness)
	mat.set_shader_parameter("specular_size", specular_size)
	mat.set_shader_parameter("specular_intensity", specular_intensity)
	if texture_path != "" and ResourceLoader.exists(texture_path):
		mat.set_shader_parameter("surface_texture", load(texture_path))
		mat.set_shader_parameter("texture_blend", texture_blend)
	return mat


## Drop shadow для Control — напівпрозорий розмитий дублікат (LAW 28 depth).
static func add_drop_shadow(parent: Control, offset: Vector2 = Vector2(4, 6),
		blur_scale: float = 1.05, alpha: float = 0.25) -> Panel:
	var shadow: Panel = Panel.new()
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = offset.x
	shadow.offset_top = offset.y
	shadow.offset_right = offset.x
	shadow.offset_bottom = offset.y
	shadow.scale = Vector2(blur_scale, blur_scale)
	shadow.pivot_offset = parent.size * 0.5 if parent.size.length() > 0 else Vector2(50, 50)
	var s_style: StyleBoxFlat = StyleBoxFlat.new()
	s_style.bg_color = Color(0.0, 0.0, 0.0, alpha)
	s_style.set_corner_radius_all(20)
	s_style.anti_aliasing_size = 2.0
	shadow.add_theme_stylebox_override("panel", s_style)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shadow)
	parent.move_child(shadow, 0)
	return shadow


## Застосувати фон до TextureRect — для non-minigame сцен.
## V167: спочатку спробувати ілюстровану PNG-картинку, fallback на градієнт.
static func apply_gradient_background(bg: TextureRect, theme: String = "meadow") -> void:
	if not bg:
		push_warning("GameData: apply_gradient_background — bg is null")
		return
	## V167: спробувати завантажити ілюстрований фон (PNG або JPG)
	var theme_png_path: String = "res://assets/backgrounds/themes/bg_%s.png" % theme
	var theme_jpg_path: String = "res://assets/backgrounds/themes/bg_%s.jpg" % theme
	var illustrated_path: String = ""
	if ResourceLoader.exists(theme_png_path):
		illustrated_path = theme_png_path
	elif ResourceLoader.exists(theme_jpg_path):
		illustrated_path = theme_jpg_path
	if not illustrated_path.is_empty():
		bg.texture = load(illustrated_path)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.position = Vector2.ZERO
		if bg.get_viewport():
			bg.call_deferred("set_size", bg.get_viewport().get_visible_rect().size)
		return
	## Fallback: програмний градієнт (якщо PNG відсутній)
	var gradients: Dictionary = {
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
		"sky": [Color("D4E8F7"), Color("B0D4F1"), Color("87CEEB"), Color("A8D8F0"), Color("C0E4F8")],
		"forest_night": [Color("4a6858"), Color("2d4838"), Color("1a3028"), Color("0f1e18"), Color("080e0c")],
		"beach": [Color("ffe8c8"), Color("ffd4a0"), Color("f0c880"), Color("e0b868"), Color("d0a850")],
		"arctic_night": [Color("c0d8f0"), Color("7898c0"), Color("4060a0"), Color("283878"), Color("182050")],
		"arctic_village": [Color("e0f0ff"), Color("b8d8f0"), Color("90c0e0"), Color("68a8d0"), Color("4890c0")],
		"underwater": [Color("c8f0ff"), Color("80d0f0"), Color("48b0e0"), Color("2088c0"), Color("1060a0")],
		"castle": [Color("e8d8c8"), Color("c8b8a0"), Color("a89878"), Color("887860"), Color("685848")],
	}
	var key: String = theme if gradients.has(theme) else "meadow"
	var colors: Array = gradients[key]
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
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.position = Vector2.ZERO
	## bg може мати FULL_RECT anchors від .tscn — set_deferred уникає _set_size warning
	if bg.get_viewport():
		bg.call_deferred("set_size", bg.get_viewport().get_visible_rect().size)


## Premium фон з анімованим шейдером — для main_menu та інших UI-екранів.
static func apply_premium_background(bg: TextureRect, theme: String = "sunset",
		reduced_motion: bool = false) -> void:
	apply_gradient_background(bg, theme)
	## Застосувати анімований шейдер
	var shader_res: Shader = load("res://assets/shaders/bg_animated.gdshader")
	if not shader_res:
		push_warning("GameData: bg_animated.gdshader not found")
		return
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader_res
	## Параметри для sunset теми (дефолт для main menu)
	var presets: Dictionary = {
		"sunset": {"bokeh_count": 6.0, "bokeh_size": 0.08, "bokeh_intensity": 0.25,
			"bokeh_color": Color(1.0, 0.85, 0.5, 0.25), "bokeh_speed": 0.12,
			"gradient_shift": 0.02, "gradient_speed": 0.3, "vignette_strength": 0.15},
		"meadow": {"bokeh_count": 4.0, "bokeh_size": 0.08, "bokeh_intensity": 0.18,
			"bokeh_color": Color(1, 1, 0.9, 0.18), "bokeh_speed": 0.15,
			"gradient_shift": 0.015, "gradient_speed": 0.4, "vignette_strength": 0.12},
		"forest": {"bokeh_count": 5.0, "bokeh_size": 0.06, "bokeh_intensity": 0.15,
			"bokeh_color": Color(0.7, 1.0, 0.8, 0.2), "bokeh_speed": 0.08,
			"gradient_shift": 0.01, "gradient_speed": 0.25, "vignette_strength": 0.2},
		"ocean": {"bokeh_count": 7.0, "bokeh_size": 0.1, "bokeh_intensity": 0.2,
			"bokeh_color": Color(0.8, 0.95, 1.0, 0.22), "bokeh_speed": 0.1,
			"gradient_shift": 0.02, "gradient_speed": 0.35, "vignette_strength": 0.12},
		"science": {"bokeh_count": 5.0, "bokeh_size": 0.07, "bokeh_intensity": 0.2,
			"bokeh_color": Color(0.85, 0.7, 1.0, 0.2), "bokeh_speed": 0.12,
			"gradient_shift": 0.015, "gradient_speed": 0.3, "vignette_strength": 0.15},
		"space": {"bokeh_count": 8.0, "bokeh_size": 0.05, "bokeh_intensity": 0.3,
			"bokeh_color": Color(0.9, 0.9, 1.0, 0.15), "bokeh_speed": 0.05,
			"gradient_shift": 0.008, "gradient_speed": 0.15, "vignette_strength": 0.25},
		"city": {"bokeh_count": 5.0, "bokeh_size": 0.07, "bokeh_intensity": 0.18,
			"bokeh_color": Color(1.0, 0.9, 0.7, 0.2), "bokeh_speed": 0.1,
			"gradient_shift": 0.015, "gradient_speed": 0.3, "vignette_strength": 0.15},
		"puzzle": {"bokeh_count": 4.0, "bokeh_size": 0.09, "bokeh_intensity": 0.2,
			"bokeh_color": Color(0.8, 0.7, 1.0, 0.2), "bokeh_speed": 0.12,
			"gradient_shift": 0.018, "gradient_speed": 0.35, "vignette_strength": 0.12},
		"music": {"bokeh_count": 6.0, "bokeh_size": 0.08, "bokeh_intensity": 0.22,
			"bokeh_color": Color(1.0, 0.85, 0.6, 0.22), "bokeh_speed": 0.15,
			"gradient_shift": 0.02, "gradient_speed": 0.4, "vignette_strength": 0.1},
		"garden": {"bokeh_count": 5.0, "bokeh_size": 0.08, "bokeh_intensity": 0.18,
			"bokeh_color": Color(1.0, 0.85, 0.9, 0.2), "bokeh_speed": 0.1,
			"gradient_shift": 0.015, "gradient_speed": 0.3, "vignette_strength": 0.12},
		"candy": {"bokeh_count": 6.0, "bokeh_size": 0.09, "bokeh_intensity": 0.22,
			"bokeh_color": Color(1.0, 0.8, 0.85, 0.22), "bokeh_speed": 0.12,
			"gradient_shift": 0.02, "gradient_speed": 0.35, "vignette_strength": 0.1},
		"arctic": {"bokeh_count": 4.0, "bokeh_size": 0.1, "bokeh_intensity": 0.15,
			"bokeh_color": Color(0.85, 0.95, 1.0, 0.18), "bokeh_speed": 0.06,
			"gradient_shift": 0.01, "gradient_speed": 0.2, "vignette_strength": 0.15},
		"sky": {"bokeh_count": 3.0, "bokeh_size": 0.1, "bokeh_intensity": 0.12,
			"bokeh_color": Color(1.0, 1.0, 1.0, 0.15), "bokeh_speed": 0.08,
			"gradient_shift": 0.0, "gradient_speed": 0.2, "vignette_strength": 0.08},
		"forest_night": {"bokeh_count": 6.0, "bokeh_size": 0.05, "bokeh_intensity": 0.2,
			"bokeh_color": Color(0.6, 0.9, 0.7, 0.18), "bokeh_speed": 0.06,
			"gradient_shift": 0.008, "gradient_speed": 0.2, "vignette_strength": 0.25},
		"beach": {"bokeh_count": 5.0, "bokeh_size": 0.09, "bokeh_intensity": 0.18,
			"bokeh_color": Color(1.0, 0.95, 0.8, 0.2), "bokeh_speed": 0.1,
			"gradient_shift": 0.015, "gradient_speed": 0.3, "vignette_strength": 0.1},
		"arctic_night": {"bokeh_count": 5.0, "bokeh_size": 0.06, "bokeh_intensity": 0.2,
			"bokeh_color": Color(0.7, 0.85, 1.0, 0.2), "bokeh_speed": 0.05,
			"gradient_shift": 0.008, "gradient_speed": 0.15, "vignette_strength": 0.22},
		"arctic_village": {"bokeh_count": 4.0, "bokeh_size": 0.08, "bokeh_intensity": 0.15,
			"bokeh_color": Color(0.9, 0.95, 1.0, 0.18), "bokeh_speed": 0.07,
			"gradient_shift": 0.01, "gradient_speed": 0.2, "vignette_strength": 0.12},
		"underwater": {"bokeh_count": 7.0, "bokeh_size": 0.08, "bokeh_intensity": 0.2,
			"bokeh_color": Color(0.7, 0.95, 1.0, 0.2), "bokeh_speed": 0.08,
			"gradient_shift": 0.015, "gradient_speed": 0.3, "vignette_strength": 0.15},
		"castle": {"bokeh_count": 5.0, "bokeh_size": 0.07, "bokeh_intensity": 0.18,
			"bokeh_color": Color(1.0, 0.9, 0.7, 0.2), "bokeh_speed": 0.08,
			"gradient_shift": 0.012, "gradient_speed": 0.25, "vignette_strength": 0.18},
	}
	var params: Dictionary = presets.get(theme, presets.get("sunset", {}))
	## V167: визначити чи фон ілюстрований (PNG/JPG) — gradient_shift зсуває зображення
	var has_illustrated: bool = (
		ResourceLoader.exists("res://assets/backgrounds/themes/bg_%s.png" % theme)
		or ResourceLoader.exists("res://assets/backgrounds/themes/bg_%s.jpg" % theme)
	)
	for key_name: String in params:
		## Для ілюстрованих фонів — gradient_shift = 0 (зсув UV руйнує PNG)
		if has_illustrated and key_name == "gradient_shift":
			mat.set_shader_parameter("gradient_shift", 0.0)
		else:
			mat.set_shader_parameter(key_name, params[key_name])
	mat.set_shader_parameter("time_scale", 0.0 if reduced_motion else 1.0)
	mat.set_shader_parameter("grain_tex", _get_grain_texture())
	mat.set_shader_parameter("grain_intensity", 0.0)  ## Grain вимкнений глобально
	mat.set_shader_parameter("detail_intensity", 0.0)  ## Процедурний шум вимкнений
	bg.material = mat


## Ілюстровані фонові PNG-елементи поверх градієнта — дерева, хмари, пагорби.
## Для UI-екранів (main_menu, game_hub, nursery тощо) що не мають BaseMiniGame.
## V167: ПРОПУСКАЄ елементи коли ілюстрований фон вже присутній (уникає подвійного накладання).
static func add_bg_elements(parent: Node, theme: String,
		reduced_motion: bool = false, opacity_mul: float = 1.0) -> void:
	## V167: перевірити чи фон ілюстрований — якщо так, елементи зайві
	var theme_png_path: String = "res://assets/backgrounds/themes/bg_%s.png" % theme
	if ResourceLoader.exists(theme_png_path):
		## Ілюстрований фон вже має дерева/хмари/пагорби — пропускаємо все
		return
	var vp: Vector2 = Vector2(1280, 720)
	if parent is Control:
		var ctrl: Control = parent as Control
		if ctrl.get_viewport():
			vp = ctrl.get_viewport().get_visible_rect().size
	## Знизити z_index фонового TextureRect щоб PNG-елементи були видимі поверх нього
	var bg_node: Node = parent.get_node_or_null("Background")
	if bg_node and bg_node is CanvasItem:
		(bg_node as CanvasItem).z_index = -3
	## Опціональна ілюстрована підкладка
	var sample_map: Dictionary = {
		"meadow": "colored_grass", "forest": "colored_forest",
		"ocean": "uncolored_hills", "science": "uncolored_piramids",
		"space": "uncolored_peaks", "city": "colored_castle",
		"puzzle": "uncolored_plain", "music": "colored_fall",
		"garden": "colored_talltrees", "candy": "colored_desert",
		"arctic": "uncolored_forest", "sunset": "colored_desert",
	}
	if sample_map.has(theme):
		var sample_path: String = "res://assets/backgrounds/samples/%s.png" % sample_map[theme]
		if ResourceLoader.exists(sample_path):
			var sample_layer: TextureRect = TextureRect.new()
			sample_layer.texture = load(sample_path)
			sample_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sample_layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			sample_layer.size = vp
			sample_layer.modulate = Color(1, 1, 1, 0.35 * opacity_mul)
			sample_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sample_layer.z_index = -2
			parent.add_child(sample_layer)
	## Тематичні PNG-елементи (opacity_mul зменшує прозорість для UI-екранів)
	var elements: Array[Dictionary] = _get_theme_elements(theme)
	for elem: Dictionary in elements:
		if opacity_mul < 1.0:
			var c: Color = elem.get("color", Color.WHITE)
			elem["color"] = Color(c.r, c.g, c.b, c.a * opacity_mul)
		_add_ui_bg_sprite(parent, elem, vp, reduced_motion)


## Конфігурація елементів для кожної теми (для UI-екранів).
static func _get_theme_elements(theme: String) -> Array[Dictionary]:
	match theme:
		"meadow":
			return [
				## V164: Redux colored assets — natural mode for trees
				{"name": "rx_cloudLayer1", "pos": Vector2(0, 0.0), "scale": Vector2(1.1, 0.12), "color": Color("d0e8d0", 0.70), "anim": "drift", "natural": true},
				{"name": "rx_cloud2", "pos": Vector2(0.55, 0.03), "scale": Vector2(0.12, 0.07), "color": Color("c0d8c0", 0.60), "natural": true},
				{"name": "rx_sun", "pos": Vector2(0.84, 0.02), "scale": Vector2(0.08, 0.08), "color": Color("ffe888", 0.65), "natural": true},
				{"name": "rx_tree", "pos": Vector2(0.02, 0.48), "scale": Vector2(0.09, 0.28), "color": Color("ffffff", 0.90), "anim": "sway", "natural": true},
				{"name": "rx_treePine", "pos": Vector2(0.12, 0.54), "scale": Vector2(0.05, 0.18), "color": Color("ffffff", 0.80), "anim": "sway", "natural": true},
				{"name": "rx_treeLong", "pos": Vector2(0.86, 0.46), "scale": Vector2(0.05, 0.28), "color": Color("ffffff", 0.90), "anim": "sway", "natural": true},
				{"name": "rx_treeSmall_green2", "pos": Vector2(0.92, 0.58), "scale": Vector2(0.04, 0.12), "color": Color("ffffff", 0.80), "anim": "sway", "natural": true},
				{"name": "rx_bush1", "pos": Vector2(0.18, 0.72), "scale": Vector2(0.06, 0.04), "color": Color("ffffff", 0.75), "natural": true},
				{"name": "rx_bush3", "pos": Vector2(0.78, 0.74), "scale": Vector2(0.07, 0.04), "color": Color("ffffff", 0.70), "natural": true},
				{"name": "rx_hillsLarge", "pos": Vector2(0, 0.65), "scale": Vector2(1.2, 0.30), "color": Color("1a5a10", 0.85)},
				{"name": "rx_fence", "pos": Vector2(0.0, 0.84), "scale": Vector2(1.1, 0.05), "color": Color("3a2810", 0.80)},
				{"name": "rx_groundLayer1", "pos": Vector2(0, 0.86), "scale": Vector2(1.3, 0.16), "color": Color("1a5808", 0.85)},
			]
		"sunset":
			return [
				## V164: Redux colored assets + silhouette shader
				{"name": "rx_cloudLayer1", "pos": Vector2(0, 0.0), "scale": Vector2(1.1, 0.12), "color": Color("e8a888", 0.75), "anim": "drift", "natural": true},
				{"name": "rx_cloud1", "pos": Vector2(0.50, 0.02), "scale": Vector2(0.14, 0.08), "color": Color("e0a080", 0.65), "anim": "drift", "natural": true},
				{"name": "rx_cloud3", "pos": Vector2(0.18, 0.04), "scale": Vector2(0.10, 0.06), "color": Color("d89070", 0.55), "natural": true},
				{"name": "rx_sun", "pos": Vector2(0.42, 0.02), "scale": Vector2(0.09, 0.09), "color": Color("ffd888", 0.70), "natural": true},
				{"name": "rx_tree", "pos": Vector2(0.01, 0.48), "scale": Vector2(0.08, 0.28), "color": Color("3a1028", 0.90), "anim": "sway"},
				{"name": "rx_treePine", "pos": Vector2(0.10, 0.52), "scale": Vector2(0.05, 0.22), "color": Color("2d0a20", 0.85), "anim": "sway"},
				{"name": "rx_treeLong", "pos": Vector2(0.87, 0.46), "scale": Vector2(0.06, 0.30), "color": Color("3a1028", 0.90), "anim": "sway"},
				{"name": "rx_treeSmall_green1", "pos": Vector2(0.92, 0.56), "scale": Vector2(0.04, 0.14), "color": Color("2d0a20", 0.80), "anim": "sway"},
				{"name": "rx_bush1", "pos": Vector2(0.14, 0.72), "scale": Vector2(0.06, 0.05), "color": Color("3a1028", 0.75)},
				{"name": "rx_bush2", "pos": Vector2(0.82, 0.74), "scale": Vector2(0.07, 0.05), "color": Color("2d0a20", 0.70)},
				{"name": "rx_hillsLarge", "pos": Vector2(0, 0.65), "scale": Vector2(1.2, 0.30), "color": Color("4a1838", 0.85)},
				{"name": "rx_hills", "pos": Vector2(-0.05, 0.75), "scale": Vector2(1.3, 0.25), "color": Color("350e28", 0.80)},
				{"name": "rx_groundLayer1", "pos": Vector2(0, 0.88), "scale": Vector2(1.1, 0.14), "color": Color("2a0818", 0.85)},
			]
		"forest":
			return [
				{"name": "rx_cloudLayerB1", "pos": Vector2(0, 0.0), "scale": Vector2(1.1, 0.10), "color": Color("b8d0b8", 0.60), "anim": "drift", "natural": true},
				{"name": "rx_treePine", "pos": Vector2(0.0, 0.42), "scale": Vector2(0.07, 0.32), "color": Color("ffffff", 0.90), "anim": "sway", "natural": true},
				{"name": "rx_treeLong", "pos": Vector2(0.10, 0.44), "scale": Vector2(0.05, 0.28), "color": Color("ffffff", 0.85), "anim": "sway", "natural": true},
				{"name": "rx_tree", "pos": Vector2(0.84, 0.46), "scale": Vector2(0.08, 0.26), "color": Color("ffffff", 0.90), "anim": "sway", "natural": true},
				{"name": "rx_treeSmall_green1", "pos": Vector2(0.92, 0.56), "scale": Vector2(0.04, 0.12), "color": Color("ffffff", 0.80), "anim": "sway", "natural": true},
				{"name": "rx_bush2", "pos": Vector2(0.20, 0.70), "scale": Vector2(0.06, 0.04), "color": Color("ffffff", 0.75), "natural": true},
				{"name": "rx_hillsLarge", "pos": Vector2(0, 0.62), "scale": Vector2(1.2, 0.35), "color": Color("0e3820", 0.85)},
				{"name": "rx_groundLayer2", "pos": Vector2(-0.1, 0.75), "scale": Vector2(1.3, 0.28), "color": Color("082818", 0.80)},
			]
		"garden":
			return [
				{"name": "rx_cloud5", "pos": Vector2(0.3, 0.03), "scale": Vector2(0.12, 0.06), "color": Color("d8b0c0", 0.60), "natural": true},
				{"name": "rx_treeOrange", "pos": Vector2(0.03, 0.46), "scale": Vector2(0.08, 0.28), "color": Color("ffffff", 0.90), "anim": "sway", "natural": true},
				{"name": "rx_tree", "pos": Vector2(0.84, 0.48), "scale": Vector2(0.07, 0.26), "color": Color("ffffff", 0.85), "anim": "sway", "natural": true},
				{"name": "rx_bushOrange1", "pos": Vector2(0.15, 0.72), "scale": Vector2(0.06, 0.04), "color": Color("ffffff", 0.75), "natural": true},
				{"name": "rx_bush4", "pos": Vector2(0.80, 0.73), "scale": Vector2(0.07, 0.04), "color": Color("ffffff", 0.70), "natural": true},
				{"name": "rx_fence", "pos": Vector2(0.0, 0.82), "scale": Vector2(1.1, 0.06), "color": Color("5a2830", 0.80)},
				{"name": "rx_hillsLarge", "pos": Vector2(0, 0.68), "scale": Vector2(1.2, 0.30), "color": Color("3a1020", 0.85)},
				{"name": "rx_groundLayer1", "pos": Vector2(0, 0.86), "scale": Vector2(1.3, 0.16), "color": Color("4a1828", 0.80)},
			]
		_:
			return [
				{"name": "rx_cloudLayer1", "pos": Vector2(0, 0.0), "scale": Vector2(1.1, 0.12), "color": Color("c0d0e0", 0.65), "anim": "drift", "natural": true},
				{"name": "rx_tree", "pos": Vector2(0.03, 0.50), "scale": Vector2(0.07, 0.24), "color": Color("ffffff", 0.85), "anim": "sway", "natural": true},
				{"name": "rx_treePine", "pos": Vector2(0.88, 0.52), "scale": Vector2(0.05, 0.20), "color": Color("ffffff", 0.80), "anim": "sway", "natural": true},
				{"name": "rx_hillsLarge", "pos": Vector2(0, 0.68), "scale": Vector2(1.2, 0.30), "color": Color("1a5a10", 0.85)},
				{"name": "rx_groundLayer1", "pos": Vector2(0, 0.86), "scale": Vector2(1.3, 0.16), "color": Color("1a5808", 0.80)},
			]


## Додати один PNG-елемент фону на UI-екран.
## V164: Два режими:
##   "natural": true  — показуємо ОРИГІНАЛЬНІ кольори PNG (Redux colored assets)
##   "natural": false — silhouette shader: бере ТІЛЬКИ альфу, колір з "color"
static func _add_ui_bg_sprite(parent: Node, elem: Dictionary, vp: Vector2,
		reduced_motion: bool) -> void:
	var name_str: String = elem.get("name", "")
	var path: String = "res://assets/backgrounds/elements/%s.png" % name_str
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var layer: TextureRect = TextureRect.new()
	layer.texture = tex
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var pos_frac: Vector2 = elem.get("pos", Vector2.ZERO)
	var scale_frac: Vector2 = elem.get("scale", Vector2(0.1, 0.1))
	layer.position = Vector2(vp.x * pos_frac.x, vp.y * pos_frac.y)
	layer.size = Vector2(vp.x * scale_frac.x, vp.y * scale_frac.y)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = -1
	var is_natural: bool = elem.get("natural", false)
	var tint: Color = elem.get("color", Color(0.2, 0.2, 0.2, 0.8))
	if is_natural:
		## Natural mode: показуємо оригінальні кольори PNG, alpha з color.a
		layer.modulate = Color(1, 1, 1, tint.a)
	else:
		layer.modulate = Color.WHITE
	## Шейдер для анімації + tint + grain (LAW 28)
	var anim_type: String = elem.get("anim", "")
	if anim_type != "" and not reduced_motion:
		var shader_path: String = ""
		if anim_type == "drift":
			shader_path = "res://assets/shaders/bg_parallax_layer.gdshader"
		elif anim_type == "sway":
			shader_path = "res://assets/shaders/sway.gdshader"
		if shader_path != "" and ResourceLoader.exists(shader_path):
			var shader: Shader = load(shader_path)
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("grain_tex", _get_grain_texture())
			mat.set_shader_parameter("grain_intensity", 0.0)  ## Grain вимкнений глобально
			if not is_natural:
				mat.set_shader_parameter("use_tint", true)
				mat.set_shader_parameter("tint_color", tint)
			layer.material = mat
	if not layer.material:
		if is_natural:
			## Natural — grain only
			layer.material = create_grain_material(0.02, 3.0, 0.0, 0.0, 0.03, 0.04, 0.10)
		else:
			## Silhouette shader
			var sil_shader_path: String = "res://assets/shaders/silhouette.gdshader"
			if ResourceLoader.exists(sil_shader_path):
				var sil_shader: Shader = load(sil_shader_path)
				var sil_mat: ShaderMaterial = ShaderMaterial.new()
				sil_mat.shader = sil_shader
				sil_mat.set_shader_parameter("tint_color", tint)
				layer.material = sil_mat
			else:
				layer.modulate = tint
	parent.add_child(layer)


## Створює SpriteFrames зі спрайт-шиту (стрип або сітка cols x rows)
static func create_sprite_frames_from_strip(
	sheet_path: String, columns: int = 4, rows: int = 2, fps: float = 6.0
) -> SpriteFrames:
	if not ResourceLoader.exists(sheet_path):
		push_warning("GameData: спрайт-шит '%s' не знайдено" % sheet_path)
		return null
	var sheet_tex: Texture2D = load(sheet_path)
	@warning_ignore("integer_division")
	var frame_w: int = sheet_tex.get_width() / columns
	@warning_ignore("integer_division")
	var frame_h: int = sheet_tex.get_height() / rows
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_speed("idle", fps)
	frames.set_animation_loop("idle", true)
	for row: int in range(rows):
		for col: int in range(columns):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = sheet_tex
			atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
			frames.add_frame("idle", atlas)
	return frames
