extends Node

## Нагороди — щоденні бонуси, серії входів, дані винагород.

const REWARDS_PATH: String = "res://data/rewards.json"
const DEFAULT_DAILY_STREAK: Dictionary = {
	"1": 50, "2": 75, "3": 100, "4": 125, "5": 150, "6": 200, "7": 300,
}

var login_streak: int = 0
var last_login_date: String = ""
var last_logout_unix: float = 0.0
var daily_rewards_config: Dictionary = {}
var quest_date: String = ""
var quest_data: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_reward_data()


func get_save_data() -> Dictionary:
	return {
		"login_streak": login_streak,
		"last_login_date": last_login_date,
		"last_logout_unix": last_logout_unix,
		"quest_date": quest_date,
		"quest_data": quest_data,
	}


func apply_save_data(data: Dictionary) -> void:
	login_streak = clampi(int(data.get("login_streak", 0)), 0, 7)
	last_login_date = data.get("last_login_date", "")
	last_logout_unix = float(data.get("last_logout_unix", 0.0))
	quest_date = data.get("quest_date", "")
	quest_data = data.get("quest_data", [])


func check_daily_reward() -> int:
	var today: String = Time.get_date_string_from_system()
	if today == last_login_date:
		return 0
	var yesterday: String = _get_yesterday_date()
	if last_login_date == yesterday:
		login_streak = mini(login_streak + 1, 7)
	else:
		login_streak = 1
	last_login_date = today
	ProgressManager.games_played_today = 0
	ProgressManager.daily_quest_completed = false
	var reward: int = _get_streak_reward(login_streak)
	ProgressManager.add_stars(reward)
	return reward


func load_reward_data() -> void:
	var file: FileAccess = FileAccess.open(REWARDS_PATH, FileAccess.READ)
	if not file:
		push_warning("RewardManager: rewards.json не знайдено, використовуємо default")
		daily_rewards_config = {"daily_streak": DEFAULT_DAILY_STREAK}
		return
	var json_text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		daily_rewards_config = parsed
	else:
		push_warning("RewardManager: rewards.json parse error, використовуємо default")
		daily_rewards_config = {"daily_streak": DEFAULT_DAILY_STREAK}


func schedule_retention_notification() -> void:
	if OS.is_debug_build():
		print("[PUSH STUB] Scheduled local notification for 24h")


func _get_yesterday_date() -> String:
	var unix: float = Time.get_unix_time_from_system() - 86400.0
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(unix))
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]


func _get_streak_reward(streak: int) -> int:
	var streak_data: Dictionary = daily_rewards_config.get("daily_streak", {})
	return int(streak_data.get(str(streak), 100))
