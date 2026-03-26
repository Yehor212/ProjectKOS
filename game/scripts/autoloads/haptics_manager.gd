extends Node

## Тактильний зворотний зв'язок — обгортка над Input.vibrate_handheld().


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func vibrate_success() -> void:
	if SettingsManager.haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(50)


func vibrate_error() -> void:
	if SettingsManager.haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(80)


func vibrate_light() -> void:
	if SettingsManager.haptics_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(30)
