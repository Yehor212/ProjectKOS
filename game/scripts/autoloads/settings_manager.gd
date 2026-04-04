extends Node

## Налаштування та збереження — гучність, мова, фони, координація збережень.

const SAVE_PATH: String = "user://save.save"
var SAVE_KEY: String = ""
const TRANSLATIONS_PATH: String = "res://assets/translations/translations.csv"
const LOCALES: Array[String] = ["en", "uk", "fr", "es"]

var sfx_volume: float = 1.0
var bgm_volume: float = 0.7
var current_language: String = "en"
var unlocked_backgrounds: Array = ["default"]
var current_bg: String = "default"
var haptics_enabled: bool = true
var reduced_motion: bool = false
var has_rated_app: bool = false
var age_group: int = 0  ## 0=Unset, 1=Toddler, 2=Preschool
var color_blind_mode: bool = false  ## LAW 25: secondary encoding via patterns in color-dependent games
var slow_mode: bool = false  ## Accessibility: reduces moving target speeds by 50% for motor-impaired children
var session_limit_minutes: int = 20  ## LAW 26: таймер здоров'я сесії (0=вимкнено)
var _save_dirty: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SAVE_KEY = _derive_key()
	_load_translations()
	load_settings()


func _process(_delta: float) -> void:
	if _save_dirty:
		_do_save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		RewardManager.last_logout_unix = Time.get_unix_time_from_system()
		_do_save()  ## Примусовий запис при згортанні — не чекаємо наступний кадр
		RewardManager.schedule_retention_notification()

func save_settings() -> void:
	_save_dirty = true


func _do_save() -> void:
	_save_dirty = false
	var data: Dictionary = {
		"sfx_volume": sfx_volume, "bgm_volume": bgm_volume, "language": current_language,
		"unlocked_backgrounds": unlocked_backgrounds, "current_bg": current_bg,
		"haptics_enabled": haptics_enabled, "reduced_motion": reduced_motion,
		"has_rated_app": has_rated_app,
		"age_group": age_group,
		"color_blind_mode": color_blind_mode, "slow_mode": slow_mode,
		"session_limit_minutes": session_limit_minutes,
	}
	data.merge(ProgressManager.get_save_data(), false)  ## false = не перезаписувати settings ключі
	data.merge(RewardManager.get_save_data(), false)
	data.merge(MasteryManager.get_save_data(), false)
	var tmp_path: String = SAVE_PATH + ".tmp"
	var file: FileAccess = FileAccess.open_encrypted_with_pass(
		tmp_path, FileAccess.WRITE, SAVE_KEY)
	if not file:
		push_warning("SettingsManager: не вдалося відкрити файл збереження (error %d)"
			% FileAccess.get_open_error())
		return
	file.store_var(data)
	file = null
	var err: Error = DirAccess.rename_absolute(tmp_path, SAVE_PATH)
	if err != OK:
		push_error("SettingsManager: rename_absolute() failed (error %d), спроба прямого запису" % err)
		## Fallback — прямий запис без atomic rename
		var fallback: FileAccess = FileAccess.open_encrypted_with_pass(
			SAVE_PATH, FileAccess.WRITE, SAVE_KEY)
		if fallback:
			fallback.store_var(data)
		else:
			push_error("SettingsManager: fallback запис також невдалий")

func load_settings() -> void:
	var file: FileAccess = FileAccess.open_encrypted_with_pass(
		SAVE_PATH, FileAccess.READ, SAVE_KEY)
	if not file:
		push_warning("SettingsManager: no save file found, using defaults")
		var os_locale: String = OS.get_locale().substr(0, 2).to_lower()
		if LOCALES.has(os_locale):
			current_language = os_locale
		_apply_volume()
		TranslationServer.set_locale(current_language)
		return
	var data: Variant = file.get_var()
	if data is Dictionary:
		## LAW 22: Валідація збережених значень — corrupted save не зламає гру
		sfx_volume = clampf(data.get("sfx_volume", 1.0), 0.0, 1.0)
		bgm_volume = clampf(data.get("bgm_volume", 0.7), 0.0, 1.0)
		var loaded_lang: String = str(data.get("language", "en"))
		current_language = loaded_lang if loaded_lang in LOCALES else "en"
		## LAW 22: валідація фонів — corrupted array не зламає гру
		var loaded_bgs: Variant = data.get("unlocked_backgrounds", ["default"])
		if loaded_bgs is Array:
			unlocked_backgrounds = loaded_bgs
			if not unlocked_backgrounds.has("default"):
				unlocked_backgrounds.insert(0, "default")
		else:
			push_warning("SettingsManager: unlocked_backgrounds corrupted, resetting")
			unlocked_backgrounds = ["default"]
		var loaded_bg: Variant = data.get("current_bg", "default")
		current_bg = str(loaded_bg) if loaded_bg is String else "default"
		if not unlocked_backgrounds.has(current_bg):
			current_bg = "default"
		haptics_enabled = data.get("haptics_enabled", true)
		reduced_motion = data.get("reduced_motion", false)
		has_rated_app = data.get("has_rated_app", false)
		age_group = clampi(data.get("age_group", 0), 0, 2)
		color_blind_mode = data.get("color_blind_mode", false)
		slow_mode = data.get("slow_mode", false)
		session_limit_minutes = clampi(data.get("session_limit_minutes", 20), 0, 60)
		ProgressManager.apply_save_data(data)
		RewardManager.apply_save_data(data)
		MasteryManager.apply_save_data(data)
	else:
		push_warning("SettingsManager: corrupt save file, overwriting with defaults")
		save_settings()
	_apply_volume()
	TranslationServer.set_locale(current_language)

func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	save_settings()

func set_language(locale: String) -> void:
	current_language = locale
	TranslationServer.set_locale(locale)
	save_settings()

func buy_background(id: String, cost: int) -> bool:
	if ProgressManager.stars < cost:
		return false
	if unlocked_backgrounds.has(id):
		return false
	ProgressManager.add_stars(-cost)
	unlocked_backgrounds.append(id)
	current_bg = id
	save_settings()
	return true

func equip_background(id: String) -> void:
	if unlocked_backgrounds.has(id):
		current_bg = id
		save_settings()

func set_app_rated() -> void:
	has_rated_app = true
	save_settings()


func set_age_group(group: int) -> void:
	age_group = clampi(group, 1, 2)
	save_settings()


func is_age_set() -> bool:
	return age_group > 0


func _derive_key() -> String:
	## COPPA: НЕ використовувати OS.get_unique_id() — це hardware identifier
	var key_path: String = "user://enc.key"
	if FileAccess.file_exists(key_path):
		var reader: FileAccess = FileAccess.open(key_path, FileAccess.READ)
		if reader:
			var stored: String = reader.get_as_text().strip_edges()
			if not stored.is_empty():
				return stored
	## Генерація нового випадкового ключа
	var key: String = ""
	for _i: int in 32:
		key += String.chr(randi_range(33, 126))
	var writer: FileAccess = FileAccess.open(key_path, FileAccess.WRITE)
	if writer:
		writer.store_string(key)
	else:
		push_warning("SettingsManager: не вдалося зберегти enc.key")
	return key



func _apply_volume() -> void:
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))
	else:
		push_warning("SettingsManager: 'SFX' audio bus not found")
	var bgm_idx: int = AudioServer.get_bus_index("BGM")
	if bgm_idx != -1:
		AudioServer.set_bus_volume_db(bgm_idx, linear_to_db(bgm_volume))

func _load_translations() -> void:
	var file: FileAccess = FileAccess.open(TRANSLATIONS_PATH, FileAccess.READ)
	if not file:
		push_warning("SettingsManager: translations.csv not found")
		return
	var headers: PackedStringArray = file.get_csv_line()
	if headers.size() < 2:
		push_warning("SettingsManager: translations.csv has no language columns")
		return
	var translations: Array[Translation] = []
	for i: int in range(1, headers.size()):
		var t: Translation = Translation.new()
		t.locale = headers[i]
		translations.append(t)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or row[0] == "":
			continue
		for i: int in range(1, mini(row.size(), headers.size())):
			translations[i - 1].add_message(row[0], row[i])
	for t: Translation in translations:
		TranslationServer.add_translation(t)
