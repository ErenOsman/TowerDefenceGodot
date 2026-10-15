extends Node
## Autoload `SettingsMgr` (SettingsManager.cs): applies SaveData.settings to the engine — bus volumes
## (Master/Music/SFX/Other, Unity's log dB mapping), window size/fullscreen, Engine.time_scale = game speed.
## UI binds its sliders/toggles to the setters; each applies at once and saves unless save_to_disk is false.
## Gameplay toggles (follow_action, instant_playback…) are only stored: the level reads them from SaveData.settings.

signal changed

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_OTHER := "Other"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_all()

var _s: SettingsData:
	get: return SaveData.settings

## Applies every saved setting to the engine (on start, and after loading or resetting the save).
func apply_all() -> void:
	var s := _s
	set_master_volume(s.master_volume, false)
	set_music_volume(s.music_volume, false)
	set_sfx_volume(s.sfx_volume, false)
	set_other_volume(s.other_volume, false)
	set_resolution(s.resolution_width, s.resolution_height, s.is_fullscreen, false)
	set_game_speed(s.game_speed, false)

# ---------------------------------------------------------------- audio

## Unity's mapping: below 0.01 → -80 dB, else 20·log10(v) (v clamped to 0..1).
static func volume_to_db(linear: float) -> float:
	if linear < 0.01: return -80.0
	return log(clampf(linear, 0.0, 1.0)) / log(10.0) * 20.0

func set_master_volume(v: float, save_to_disk := true) -> void:
	_apply_volume(BUS_MASTER, v)
	_s.master_volume = clampf(v, 0.0, 1.0)
	_done(save_to_disk)

func set_music_volume(v: float, save_to_disk := true) -> void:
	_apply_volume(BUS_MUSIC, v)
	_s.music_volume = clampf(v, 0.0, 1.0)
	_done(save_to_disk)

func set_sfx_volume(v: float, save_to_disk := true) -> void:
	_apply_volume(BUS_SFX, v)
	_s.sfx_volume = clampf(v, 0.0, 1.0)
	_done(save_to_disk)

func set_other_volume(v: float, save_to_disk := true) -> void:
	_apply_volume(BUS_OTHER, v)
	_s.other_volume = clampf(v, 0.0, 1.0)
	_done(save_to_disk)

func _apply_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		push_warning("[SettingsMgr] no audio bus '%s' (default_bus_layout.tres)" % bus)
		return
	AudioServer.set_bus_volume_db(i, volume_to_db(linear))

# ---------------------------------------------------------------- display

## Window size and fullscreen. Ignored on the web (the canvas follows the page) and headless.
func set_resolution(width: int, height: int, fullscreen: bool, save_to_disk := true) -> void:
	_s.resolution_width = width
	_s.resolution_height = height
	_s.is_fullscreen = fullscreen
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size := Vector2i(maxi(width, 1280), maxi(height, 720))
			DisplayServer.window_set_size(size)
			var screen := DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
	_done(save_to_disk)

## The window sizes offered (common 16:9 sizes that fit the screen, plus the saved one).
func resolutions() -> Array:
	var screen := DisplayServer.screen_get_size() if DisplayServer.get_name() != "headless" else Vector2i(1920, 1080)
	var out := []
	for r in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]:
		if r.x <= screen.x and r.y <= screen.y: out.append(r)
	var cur := Vector2i(_s.resolution_width, _s.resolution_height)
	if not out.has(cur): out.append(cur)
	return out

# ---------------------------------------------------------------- gameplay

## Engine.time_scale (0.5 slow, 1 normal, 2 fast).
func set_game_speed(speed: float, save_to_disk := true) -> void:
	var flow = get_node_or_null("/root/SceneFlow")
	var in_level: bool = flow != null and flow.current == flow.Level
	Engine.time_scale = speed if speed > 0.0 and in_level else 1.0 # only levels run at the game speed
	_s.game_speed = speed
	_done(save_to_disk)

func set_follow_action(v: bool, save_to_disk := true) -> void:
	_s.follow_action = v
	_done(save_to_disk)

func set_follow_selection(v: bool, save_to_disk := true) -> void:
	_s.follow_selection = v
	_done(save_to_disk)

func set_drag_to_pan(v: bool, save_to_disk := true) -> void:
	_s.drag_to_pan = v
	_done(save_to_disk)

func set_instant_playback(v: bool, save_to_disk := true) -> void:
	_s.instant_playback = v
	_done(save_to_disk)

func set_always_show_health(v: bool, save_to_disk := true) -> void:
	_s.always_show_health = v
	_done(save_to_disk)

func _done(save_to_disk: bool) -> void:
	if save_to_disk: SaveData.save()
	changed.emit()
