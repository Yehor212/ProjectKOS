class_name SaveTransfer

## Утиліта для експорту/імпорту збережень через буфер обміну (Base64 + JSON).


static func do_export() -> String:
	var data: Dictionary = {
		"stars": ProgressManager.stars,
		"inventory_hints": ProgressManager.inventory_hints,
		"unlocked_animals": ProgressManager.unlocked_animals,
		"unlocked_backgrounds": SettingsManager.unlocked_backgrounds,
		"best_time_sec": ProgressManager.best_time_sec,
		"best_errors": ProgressManager.best_errors,
		"total_animals_fed": ProgressManager.total_animals_fed,
		"games_played": ProgressManager.games_played,
	}
	var json_str: String = JSON.stringify(data)
	var encoded: String = Marshalls.utf8_to_base64(json_str)
	DisplayServer.clipboard_set(encoded)
	return "MSG_COPIED"


static func do_import() -> String:
	var encoded: String = DisplayServer.clipboard_get()
	if encoded.is_empty():
		return "MSG_CLIPBOARD_EMPTY"
	var json_str: String = Marshalls.base64_to_utf8(encoded)
	if json_str.is_empty():
		return "MSG_INVALID_DATA"
	var parsed: Variant = JSON.parse_string(json_str)
	if not parsed is Dictionary or (not parsed.has("stars") and not parsed.has("coins")):
		return "MSG_INVALID_SAVE"
	var data: Dictionary = parsed
	ProgressManager.stars = maxi(0, int(data.get("stars", data.get("coins", 0))))
	ProgressManager.inventory_hints = maxi(0, int(data.get("inventory_hints", 3)))
	var animals: Variant = data.get("unlocked_animals", [])
	if animals is Array:
		ProgressManager.unlocked_animals = animals
	SettingsManager.unlocked_backgrounds = data.get("unlocked_backgrounds", ["default"])
	ProgressManager.best_time_sec = maxi(0, int(data.get("best_time_sec", 9999)))
	ProgressManager.best_errors = maxi(0, int(data.get("best_errors", 9999)))
	ProgressManager.total_animals_fed = maxi(0, int(data.get("total_animals_fed", 0)))
	ProgressManager.games_played = maxi(0, int(data.get("games_played", 0)))
	SettingsManager.save_settings()
	return ""
