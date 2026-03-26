extends PanelContainer

## Dev-консоль — дебаг-інструменти, доступні лише в debug-білді.

var _dev_taps: int = 0
var _dev_timer: Timer = null


func _on_version_pressed() -> void:
	if not OS.is_debug_build():
		return
	_dev_taps += 1
	if _dev_taps >= 5:
		_dev_taps = 0
		if _dev_timer:
			_dev_timer.stop()
		visible = true
		return
	if _dev_timer == null:
		_dev_timer = Timer.new()
		_dev_timer.wait_time = 1.5
		_dev_timer.one_shot = true
		_dev_timer.timeout.connect(func() -> void: _dev_taps = 0)
		add_child(_dev_timer)
	_dev_timer.start()


func _on_dev_add_stars() -> void:
	ProgressManager.add_stars(1000)
	var star_label: Label = get_parent().get_node_or_null("StarLabel")
	if star_label:
		star_label.text = " %d" % ProgressManager.stars


func _on_dev_unlock_all() -> void:
	for pair: Dictionary in GameData.ANIMALS_AND_FOOD:
		ProgressManager.unlock_animal(pair.name)


func _on_dev_reset_save() -> void:
	DirAccess.remove_absolute(SettingsManager.SAVE_PATH)
	ProgressManager.stars = 0
	ProgressManager.best_time_sec = 9999
	ProgressManager.best_errors = 9999
	ProgressManager.unlocked_animals = []
	SettingsManager.unlocked_backgrounds = ["default"]
	SettingsManager.current_bg = "default"
	ProgressManager.has_seen_tutorial = false
	ProgressManager.total_animals_fed = 0
	ProgressManager.achievement_100_fed = false
	ProgressManager.games_played = 0
	SettingsManager.has_rated_app = false
	ProgressManager.games_played_today = 0
	ProgressManager.daily_quest_completed = false
	ProgressManager.highest_level_unlocked = 1
	ProgressManager.inventory_hints = 3
	RewardManager.last_logout_unix = 0.0
	RewardManager.login_streak = 0
	SettingsManager.haptics_enabled = true
	RewardManager.quest_date = ""
	RewardManager.quest_data = []
	SettingsManager.save_settings()
	get_tree().reload_current_scene()


func _on_dev_close() -> void:
	visible = false
