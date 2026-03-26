extends Node

## Тактильний зворотний зв'язок — обгортка над Input.vibrate_handheld().
## Research (Journal of Consumer Research 2025): 400мс = оптимум для позитивного відгуку.
## Патерн: success=400мс, error=200мс pulse, light=100мс, star=300+100мс (подвійний тап).


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func vibrate_success() -> void:
	if SettingsManager.haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(400)


func vibrate_error() -> void:
	if SettingsManager.haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(200)


func vibrate_light() -> void:
	if SettingsManager.haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(100)


## Патерн "подвійний тап" для зірок та досягнень
func vibrate_star() -> void:
	if SettingsManager.haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(300)
		await get_tree().create_timer(0.15).timeout
		if not is_instance_valid(self):
			return
		Input.vibrate_handheld(100)


## Святковий патерн для завершення гри (400+200+400)
func vibrate_celebration() -> void:
	if SettingsManager.haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(400)
		await get_tree().create_timer(0.2).timeout
		if not is_instance_valid(self):
			return
		Input.vibrate_handheld(200)
		await get_tree().create_timer(0.15).timeout
		if not is_instance_valid(self):
			return
		Input.vibrate_handheld(400)
