class_name GameSounds
extends RefCounted
## The default sound per event type, plus one per attack kind (Melee, Projectile, Lobbed, Beam), played by the
## presenters through AudioMgr when their event starts (GameSounds.cs). The game has no SFX files yet, so the
## tables are empty and every call is a no-op hook: fill `events` / `attacks` with res:// audio paths (or
## streams) to hear them. An ability's own sounds come with its presentation asset (Unity clip paths, mapped to
## res:// when such files exist).

## GameEventType → Array of stream paths (one is picked at random).
var events: Dictionary = {}
## attack-kind tag → Array of stream paths, played on AttackStarted instead of the event's sound.
var attacks: Dictionary = {}
var volume: float = 1.0

static var _played_frame := {}

## Plays the sound for an event, if there is one.
func play(e: GameEvent) -> void:
	if e.type == GameEventType.AttackStarted:
		for tag in attacks:
			if e.tags.has(tag):
				_play_one(attacks[tag])
				return
	if events.has(e.type): _play_one(events[e.type])

## Plays a clip through AudioMgr (an ability presentation's own sounds use this too); a Unity path or "" with no
## res:// counterpart is silent. The same clip plays at most once per frame, so Instant and Skip do not stack it.
static func play_clip(clip, vol: float = 1.0) -> void:
	if clip == null or (clip is String and clip == ""): return
	var path := str(clip)
	if path.begins_with("Assets/"): path = "res://art/sfx/" + path.get_file().get_basename() + ".ogg"
	elif path.begins_with("art/"): path = "res://" + path # canonical content form ("art/sfx/<clip>.ogg")
	if clip is String and not ResourceLoader.exists(path): return
	var frame := Engine.get_process_frames()
	if _played_frame.get(path, -1) == frame: return
	_played_frame[path] = frame
	var tree := Engine.get_main_loop() as SceneTree
	var audio = tree.root.get_node_or_null("AudioMgr") if tree != null else null
	if audio != null and audio.has_method("play_sfx"): audio.play_sfx(path if clip is String else clip, vol)

func _play_one(list) -> void:
	if list == null or list.is_empty(): return
	play_clip(list[randi() % list.size()], volume)
