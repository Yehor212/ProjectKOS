extends Node

## Analytics stub — prints structured event data to console in debug builds.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func log_level_start(round_num: int) -> void:
	if OS.is_debug_build():
		print('[ANALYTICS] Event: level_start | Data: {"round": %d}' % round_num)


func log_level_complete(round_num: int, time_taken: float, errors: int) -> void:
	if OS.is_debug_build():
		print('[ANALYTICS] Event: level_complete | Data: {"round": %d, "time": %.1f, "errors": %d}' % [round_num, time_taken, errors])


func log_item_match(animal_name: String, is_correct: bool) -> void:
	if OS.is_debug_build():
		print('[ANALYTICS] Event: item_match | Data: {"animal": "%s", "correct": %s}' % [animal_name, str(is_correct).to_lower()])
