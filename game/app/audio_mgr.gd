extends Node
## Autoload `AudioMgr` (AudioManager.cs + SceneMusic.cs): looping music with a crossfade between two players
## (bus Music), a round-robin pool of SFX players (bus SFX) and positional one-shots. Volumes per bus are
## SettingsMgr's job. Fades run on unscaled time, so they work while the game is paused or sped up.

## Default crossfade seconds when switching music.
const DEFAULT_FADE := 1.0
const SFX_POOL := 8
## The tracks in res://art/music/.
const TRACKS := ["menu", "map1", "map2", "map3", "battle"]
const MAP_TRACKS := ["map1", "map2", "map3"]

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _vol := {}          # player → linear volume 0..1
var _names := {}        # player → track name ("" none)
var _fade := {}         # {incoming, outgoing, in_from, out_from, t, duration, stop_all}
var _sfx: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _last_usec := 0
var _streams := {}      # path → AudioStream

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _make_player("Music_A", "Music")
	_b = _make_player("Music_B", "Music")
	_active = _a
	for i in SFX_POOL: _sfx.append(_make_player("SFX_%d" % i, "SFX"))
	_last_usec = Time.get_ticks_usec()

func _make_player(n: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	p.bus = bus
	add_child(p)
	_vol[p] = 1.0
	_names[p] = ""
	return p

# ---------------------------------------------------------------- music

## Plays a track by name ("menu", "map1"…"map3", "battle"), res path or Unity clip path, or an AudioStream.
## Crossfades from what plays (fade < 0: DEFAULT_FADE; 0: instant). The same track already playing keeps playing.
func play_music(track, fade: float = -1.0) -> void:
	var stream: AudioStream = null
	var track_name := ""
	if track is AudioStream:
		stream = track
		track_name = track.resource_path.get_file().get_basename()
	elif track is String or track is StringName:
		var path := ArtPaths.music(String(track))
		stream = _stream(path)
		track_name = path.get_file().get_basename()
	if stream == null:
		push_warning("[AudioMgr] no music '%s'" % str(track))
		return
	if fade < 0.0: fade = DEFAULT_FADE
	if _active.stream == stream and _active.playing: return
	_fade = {}
	if not _a.playing and not _b.playing: fade = 0.0
	var incoming := _other(_active) if _active.playing else _active
	if incoming.stream != stream or not incoming.playing:
		incoming.stream = stream
		_names[incoming] = track_name
		_set_vol(incoming, 0.0)
		incoming.play()
	_active = incoming
	if fade > 0.0:
		_fade = {"incoming": incoming, "outgoing": _other(incoming), "in_from": _vol[incoming],
			"out_from": _vol[_other(incoming)], "t": 0.0, "duration": fade, "stop_all": false}
	else:
		_other(incoming).stop()
		_set_vol(_other(incoming), 1.0)
		_set_vol(incoming, 1.0)

## Stops the music with a fade-out (fade < 0: DEFAULT_FADE).
func stop_music(fade: float = -1.0) -> void:
	if fade < 0.0: fade = DEFAULT_FADE
	_fade = {}
	if fade > 0.0 and (_a.playing or _b.playing):
		_fade = {"stop_all": true, "a_from": _vol[_a], "b_from": _vol[_b], "t": 0.0, "duration": fade}
	else:
		for p in [_a, _b]:
			p.stop()
			_set_vol(p, 1.0)

func pause_music() -> void:
	_active.stream_paused = true

func resume_music() -> void:
	_active.stream_paused = false

## Music is playing (not paused).
func is_music_playing() -> bool:
	return _active.playing and not _active.stream_paused

## The track playing (or fading in) now: its name ("battle"), or "" for none.
func current_music() -> String:
	return _names[_active] if _active.playing else ""

## SceneMusic.cs per scene: MainMenu/Welcome → menu; LevelSelect/Camp/Guild → one of map1–3 (kept when one already
## plays); the level → its LevelAsset.music when set, else battle. Boot/Loading keep what plays.
func play_scene_music(scene_id: int, level: LevelAsset = null) -> void:
	match scene_id:
		SceneFlow.MainMenu, SceneFlow.Welcome:
			play_music("menu")
		SceneFlow.LevelSelect, SceneFlow.Camp, SceneFlow.Guild:
			if MAP_TRACKS.has(current_music()): return
			play_music(MAP_TRACKS[randi() % MAP_TRACKS.size()])
		SceneFlow.Game:
			var track := "battle"
			if level != null and level.music != "" and _stream(ArtPaths.music(level.music)) != null:
				track = level.music
			play_music(track)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_usec) / 1000000.0, 0.25)
	_last_usec = now
	if _fade.is_empty(): return
	_fade.t += dt
	var t := clampf(_fade.t / _fade.duration, 0.0, 1.0)
	if _fade.stop_all:
		_set_vol(_a, lerpf(_fade.a_from, 0.0, t))
		_set_vol(_b, lerpf(_fade.b_from, 0.0, t))
		if t >= 1.0:
			for p in [_a, _b]:
				p.stop()
				_set_vol(p, 1.0)
			_fade = {}
		return
	var incoming: AudioStreamPlayer = _fade.incoming
	var outgoing: AudioStreamPlayer = _fade.outgoing
	_set_vol(incoming, lerpf(_fade.in_from, 1.0, t))
	if outgoing.playing: _set_vol(outgoing, lerpf(_fade.out_from, 0.0, t))
	if t >= 1.0:
		outgoing.stop()
		_set_vol(outgoing, 1.0)
		_set_vol(incoming, 1.0)
		_fade = {}

func _other(p: AudioStreamPlayer) -> AudioStreamPlayer:
	return _b if p == _a else _a

func _set_vol(p: AudioStreamPlayer, linear: float) -> void:
	_vol[p] = linear
	p.volume_db = linear_to_db(maxf(linear, 0.0001))

# ---------------------------------------------------------------- SFX

## Plays a one-shot (AudioStream or res path) on the SFX pool; overlapping sounds do not cut each other off.
func play_sfx(stream, volume: float = 1.0) -> void:
	var s := _as_stream(stream)
	if s == null: return
	var p := _sfx[_next_sfx]
	p.stream = s
	p.volume_db = linear_to_db(maxf(volume, 0.0001))
	p.play()
	_next_sfx = (_next_sfx + 1) % _sfx.size()

## Plays a positional one-shot at a world position (a temporary AudioStreamPlayer3D, freed when done).
func play_sfx_at(stream, position: Vector3, volume: float = 1.0) -> void:
	var s := _as_stream(stream)
	if s == null: return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.volume_db = linear_to_db(maxf(volume, 0.0001))
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else self
	parent.add_child(p)
	p.global_position = position
	p.finished.connect(p.queue_free)
	p.play()

func _as_stream(stream) -> AudioStream:
	if stream is AudioStream: return stream
	if stream is String and stream != "": return _stream(stream)
	return null

func _stream(path: String) -> AudioStream:
	if path == "": return null
	if _streams.has(path): return _streams[path]
	var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	if s != null and path.begins_with("res://art/music/") and "loop" in s: s.loop = true
	_streams[path] = s
	return s
