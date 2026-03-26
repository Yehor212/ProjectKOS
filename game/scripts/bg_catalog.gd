class_name BgCatalog
extends RefCounted

## Каталог фонів для магазину — ціни, теми, порядок відображення.
## Використовує SettingsManager.buy_background() / equip_background() для покупки.

const BACKGROUNDS: Array[Dictionary] = [
	{"id": "default", "theme": "sky", "name_key": "BG_SKY", "cost": 0, "order": 0},
	{"id": "meadow", "theme": "meadow", "name_key": "BG_MEADOW", "cost": 100, "order": 1},
	{"id": "forest", "theme": "forest", "name_key": "BG_FOREST", "cost": 100, "order": 2},
	{"id": "ocean", "theme": "ocean", "name_key": "BG_OCEAN", "cost": 100, "order": 3},
	{"id": "beach", "theme": "beach", "name_key": "BG_BEACH", "cost": 100, "order": 4},
	{"id": "city", "theme": "city", "name_key": "BG_CITY", "cost": 100, "order": 5},
	{"id": "puzzle", "theme": "puzzle", "name_key": "BG_PUZZLE", "cost": 100, "order": 6},
	{"id": "garden", "theme": "garden", "name_key": "BG_GARDEN", "cost": 100, "order": 7},
	{"id": "forest_night", "theme": "forest_night", "name_key": "BG_FOREST_NIGHT", "cost": 150, "order": 8},
	{"id": "science", "theme": "science", "name_key": "BG_SCIENCE", "cost": 150, "order": 9},
	{"id": "candy", "theme": "candy", "name_key": "BG_CANDY", "cost": 150, "order": 10},
	{"id": "arctic", "theme": "arctic", "name_key": "BG_ARCTIC", "cost": 150, "order": 11},
	{"id": "sunset", "theme": "sunset", "name_key": "BG_SUNSET", "cost": 200, "order": 12},
	{"id": "space", "theme": "space", "name_key": "BG_SPACE", "cost": 200, "order": 13},
	{"id": "arctic_night", "theme": "arctic_night", "name_key": "BG_ARCTIC_NIGHT", "cost": 200, "order": 14},
	{"id": "arctic_village", "theme": "arctic_village", "name_key": "BG_ARCTIC_VILLAGE", "cost": 200, "order": 15},
	{"id": "underwater", "theme": "underwater", "name_key": "BG_UNDERWATER", "cost": 150, "order": 16},
	{"id": "castle", "theme": "castle", "name_key": "BG_CASTLE", "cost": 250, "order": 17},
]


## Знайти фон за id. Fallback на default якщо не знайдено.
static func get_bg(id: String) -> Dictionary:
	for bg: Dictionary in BACKGROUNDS:
		if bg.id == id:
			return bg
	push_warning("BgCatalog: невідомий id '%s', fallback на default" % id)
	return BACKGROUNDS[0]


## Тема шейдера для заданого id (для GameData.apply_premium_background).
static func get_theme_for_id(id: String) -> String:
	return get_bg(id).get("theme", "sky") as String


## Шлях до зображення-прев'ю для TextureRect (PNG або JPG fallback).
static func get_preview_path(id: String) -> String:
	var theme: String = get_theme_for_id(id)
	var png_path: String = "res://assets/backgrounds/themes/bg_%s.png" % theme
	if ResourceLoader.exists(png_path):
		return png_path
	var jpg_path: String = "res://assets/backgrounds/themes/bg_%s.jpg" % theme
	if ResourceLoader.exists(jpg_path):
		return jpg_path
	push_warning("BgCatalog: прев'ю не знайдено для '%s'" % id)
	return png_path
