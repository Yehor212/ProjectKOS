extends Node

## Polyphonic audio pool — prevents SFX clipping when multiple sounds overlap.
## String-keyed SFX dictionary for clean call sites: AudioManager.play_sfx("click")

const SFX_DIR: String = "res://assets/audio/sfx/"
const BGM_DIR: String = "res://assets/audio/bgm/"
const BGM_NORMAL_DB: float = -6.0
const BGM_LOWERED_DB: float = -18.0

var _pool: Array[AudioStreamPlayer] = []
var _sfx: Dictionary = {}
var _bgm: Dictionary = {}
var _bgm_player: AudioStreamPlayer = null
var _last_sfx_frame: Dictionary = {}  ## sfx_name → frame (дебаунс дублів)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	## BGM player — окремий на BGM bus
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = &"BGM"
	add_child(_bgm_player)
	_bgm = {
		"bgm_loop": _try_load(BGM_DIR + "bgm_loop.wav"),
		"bgm_animals": _try_load(BGM_DIR + "bgm_animals.wav"),
		"bgm_numbers": _try_load(BGM_DIR + "bgm_numbers.wav"),
		"bgm_colors": _try_load(BGM_DIR + "bgm_colors.wav"),
	}
	for i: int in range(16):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_pool.append(player)
	_sfx = {
		"click": _try_load(SFX_DIR + "click.wav"),
		"success": _try_load(SFX_DIR + "success.wav"),
		"error": _try_load(SFX_DIR + "error.wav"),
		"coin": _try_load(SFX_DIR + "coin.wav"),
		"pop": _try_load(SFX_DIR + "pop.wav"),
		"whoosh": _try_load(SFX_DIR + "whoosh.wav"),
		"toggle": _try_load(SFX_DIR + "toggle.wav"),
		"tap": _try_load(SFX_DIR + "tap.wav"),
		"slide": _try_load(SFX_DIR + "slide.wav"),
		"star": _try_load(SFX_DIR + "star.wav"),
		"bounce": _try_load(SFX_DIR + "bounce.wav"),
		"swipe": _try_load(SFX_DIR + "swipe.wav"),
		"reward": _try_load(SFX_DIR + "reward.wav"),
		## Тематичні SFX (раніше не зареєстровані — 28 файлів на диску)
		"combo": _try_load(SFX_DIR + "combo.wav"),
		"golden": _try_load(SFX_DIR + "golden.wav"),
		"rainbow": _try_load(SFX_DIR + "rainbow.wav"),
		"sticker": _try_load(SFX_DIR + "sticker.wav"),
		"unlock": _try_load(SFX_DIR + "unlock.wav"),
		"feed": _try_load(SFX_DIR + "feed.wav"),
		"pet": _try_load(SFX_DIR + "pet.wav"),
		"ambient_nature": _try_load(SFX_DIR + "ambient_nature.wav"),
		"page_turn": _try_load(SFX_DIR + "page_turn.wav"),
		"sparkle": _try_load(SFX_DIR + "sparkle.wav"),
		"yawn": _try_load(SFX_DIR + "yawn.wav"),
		"chomp": _try_load(SFX_DIR + "chomp.wav"),
		"giggle": _try_load(SFX_DIR + "giggle.wav"),
		"applause": _try_load(SFX_DIR + "applause.wav"),
		"woosh_magic": _try_load(SFX_DIR + "woosh_magic.wav"),
		"snap": _try_load(SFX_DIR + "snap.wav"),
		"flip": _try_load(SFX_DIR + "flip.wav"),
		"crunch": _try_load(SFX_DIR + "crunch.wav"),
		"splash": _try_load(SFX_DIR + "splash.wav"),
		"ka_ching": _try_load(SFX_DIR + "ka_ching.wav"),
		"bubble_pop": _try_load(SFX_DIR + "bubble_pop.wav"),
		"camera": _try_load(SFX_DIR + "camera.wav"),
		"note_c": _try_load(SFX_DIR + "note_c.wav"),
		"note_e": _try_load(SFX_DIR + "note_e.wav"),
		"note_g": _try_load(SFX_DIR + "note_g.wav"),
		"note_a": _try_load(SFX_DIR + "note_a.wav"),
	}


func _try_load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("AudioManager: missing audio at '%s'" % path)
	return null


## SFX з авто-варіацією тону — органічне звучання при повторенні.
## click/error залишаються фіксованими (UI consistency).
const _AUTO_VARY_SFX: PackedStringArray = ["success", "coin", "bounce", "pop", "star", "reward"]
const _AUTO_VARY_RANGE: float = 0.1  ## ±10% pitch

func play_sfx(sound_name: String, pitch: float = 1.0) -> void:
	## Дебаунс: один SFX за кадр (авто + ручний виклик не дублюються)
	var frame: int = Engine.get_process_frames()
	if _last_sfx_frame.get(sound_name, -1) == frame:
		return
	_last_sfx_frame[sound_name] = frame
	## Авто-варіація тону для gameplay SFX (тільки коли pitch = default)
	if pitch == 1.0 and sound_name in _AUTO_VARY_SFX:
		pitch = randf_range(1.0 - _AUTO_VARY_RANGE, 1.0 + _AUTO_VARY_RANGE)
	var stream: AudioStream = _sfx.get(sound_name)
	if not stream:
		push_warning("AudioManager: SFX '%s' не знайдено" % sound_name)
		return
	for player: AudioStreamPlayer in _pool:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = pitch
			player.play()
			return
	## Пул вичерпано — перевикористовуємо найстаріший плеєр
	_pool[0].stream = stream
	_pool[0].pitch_scale = pitch
	_pool[0].play()
	## Ротація: переміщуємо використаний в кінець
	var oldest: AudioStreamPlayer = _pool[0]
	_pool.remove_at(0)
	_pool.append(oldest)


## Pitch-varied SFX — рандомізований тон для органічного звучання.
func play_sfx_varied(sound_name: String, range_pct: float = 0.15) -> void:
	var pitch: float = randf_range(1.0 - range_pct, 1.0 + range_pct)
	play_sfx(sound_name, pitch)


## BGM — фонова музика на окремому bus з crossfade
func play_bgm(track_name: String = "bgm_loop") -> void:
	var stream: AudioStream = _bgm.get(track_name)
	if not stream:
		push_warning("AudioManager: BGM '%s' не знайдено" % track_name)
		return
	if _bgm_player.stream == stream and _bgm_player.playing:
		return
	_bgm_player.stream = stream
	_bgm_player.volume_db = BGM_NORMAL_DB
	_bgm_player.play()


func stop_bgm() -> void:
	if _bgm_player.playing:
		var tw: Tween = create_tween()
		tw.tween_property(_bgm_player, "volume_db", -40.0, 0.5)
		tw.tween_callback(_bgm_player.stop)


func lower_bgm() -> void:
	if _bgm_player.playing:
		var tw: Tween = create_tween()
		tw.tween_property(_bgm_player, "volume_db", BGM_LOWERED_DB, 0.3)


func restore_bgm() -> void:
	if _bgm_player.playing:
		var tw: Tween = create_tween()
		tw.tween_property(_bgm_player, "volume_db", BGM_NORMAL_DB, 0.3)
