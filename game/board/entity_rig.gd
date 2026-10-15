class_name EntityRig
extends RefCounted
## Maps the presenters' calls onto a model's AnimationPlayer (EntityAnimatorBridge.cs). The FBX contract:
## clips `<Name>|Idle`, `|Walk`, `|Attack`, `|Cast`, `|Hit`, `|Die` (last frame = the corpse), `|Spawn`.
## A trigger plays the first clip whose name ends with "|<Trigger>" (else contains it). The impact: a method
## track key calling "Impact"/"impact" on the clip when there is one, else the Blender kit's
## res://art/models/impacts.json ({"<Model>": {"<Clip>": seconds}}, the model = the part of the clip name before
## "|"; Blender's FBX export cannot write method tracks), else fallback_impact of the clip.
## One-shot clips return to Idle (or Walk while moving) when they end. Missing clips are skipped, so a model
## may have only some.

const MOVING := "Moving"
const ATTACK := "Attack"
const CAST := "Cast"
const HIT := "Hit"
const DIE := "Die"
const SPAWN := "Spawn"
const IDLE := "Idle"
const WALK := "Walk"

## Impact time when a clip has no impact key, as a fraction of the clip.
var fallback_impact: float = 0.5

var player: AnimationPlayer = null
var _clips := {}            # trigger (lower case) → animation name
var _pending_impact: Callable = Callable()
var _moving := false
var _dead := false

func _init(p_player: AnimationPlayer) -> void:
	player = p_player
	for a in player.get_animation_list():
		var short: String = a.get_slice("|", a.get_slice_count("|") - 1).to_lower()
		if not _clips.has(short): _clips[short] = a
	for loop_name in [IDLE, WALK]:
		var anim := _anim(loop_name)
		if anim != null: anim.loop_mode = Animation.LOOP_LINEAR
	player.animation_finished.connect(_on_finished)
	_play_rest()

func _clip(trigger: String) -> String:
	var t := trigger.to_lower()
	if _clips.has(t): return _clips[t]
	for k in _clips:
		if k.contains(t): return _clips[k]
	return ""

func _anim(trigger: String) -> Animation:
	var n := _clip(trigger)
	return player.get_animation(n) if n != "" else null

## Whether the model has a clip for this trigger (Moving: a Walk clip), so the presenter can fall back to a tween.
func has(trigger: String) -> bool:
	if trigger == MOVING: return _clip(WALK) != ""
	return _clip(trigger) != ""

## The clip's length (seconds at 1×), or fallback.
func clip_length(trigger: String, fallback: float) -> float:
	var a := _anim(trigger)
	return a.length if a != null else fallback

## Whether the clip has an impact key (otherwise fallback_impact is used).
func has_impact_event(trigger: String) -> bool:
	return impact_key_time(trigger) >= 0.0

## The time of the clip's impact key, or -1.
func impact_key_time(trigger: String) -> float:
	var a := _anim(trigger)
	if a == null: return -1.0
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_METHOD: continue
		for k in a.track_get_key_count(t):
			if str(a.method_track_get_name(t, k)).to_lower() == "impact": return a.track_get_key_time(t, k)
	return -1.0

## When the impact lands, in seconds into the clip: the clip's impact key, else the kit's impacts.json, else
## fallback_impact of the clip.
func impact_time(trigger: String) -> float:
	var key := impact_key_time(trigger)
	if key >= 0.0: return key
	var table := impact_table_time(trigger)
	if table >= 0.0: return minf(table, clip_length(trigger, 0.5))
	return clip_length(trigger, 0.5) * fallback_impact

const IMPACTS_PATH := "res://art/models/impacts.json"
static var _impacts = null  # {"<Model>": {"<Clip>": seconds}} once loaded; {} when the file is missing

## The impact time from art/models/impacts.json for this clip (model = the clip name's part before "|"), or -1.
func impact_table_time(trigger: String) -> float:
	var name: String = _clips.get(trigger.to_lower(), "")
	if name == "" or not name.contains("|"): return -1.0
	var model := name.get_slice("|", 0)
	var clip := name.get_slice("|", name.get_slice_count("|") - 1)
	var table: Dictionary = impacts_table()
	if not table.has(model): return -1.0
	var clips: Dictionary = table[model]
	if not clips.has(clip): return -1.0
	return float(clips[clip])

static func impacts_table() -> Dictionary:
	if _impacts == null:
		_impacts = {}
		if FileAccess.file_exists(IMPACTS_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(IMPACTS_PATH))
			if parsed is Dictionary: _impacts = parsed
			else: push_warning("EntityRig: %s is not a JSON object" % IMPACTS_PATH)
	return _impacts

func set_moving(moving: bool) -> void:
	if _moving == moving: return
	_moving = moving
	if _dead: return
	var current := player.current_animation
	if current == "" or current == _clip(IDLE) or current == _clip(WALK): _play_rest()

## Plays a trigger's clip; on_impact runs when release_impact() is called (the presenter's impact moment) or when
## another clip starts first. False when there is no such clip.
func play(trigger: String, on_impact: Callable = Callable()) -> bool:
	var n := _clip(trigger)
	if n == "": return false
	release_impact()
	_pending_impact = on_impact
	if trigger != DIE: _dead = false
	else: _dead = true
	player.play(n, 0.08)
	player.seek(0.0, true)
	return true

## The impact moment (the presenter calls it at impact_time).
func release_impact() -> void:
	var a := _pending_impact
	_pending_impact = Callable()
	if a.is_valid(): a.call()

## Skip / Instant: drops whatever is playing and returns to the rest pose (the impact still fires).
func to_rest() -> void:
	release_impact()
	_dead = false
	_play_rest(true)

## The corpse: the Die clip's last frame. False when the model has no Die clip.
func show_dead() -> bool:
	release_impact()
	var n := _clip(DIE)
	if n == "": return false
	_dead = true
	player.play(n, 0.0)
	player.seek(player.get_animation(n).length, true)
	return true

func _play_rest(snap: bool = false) -> void:
	var n := _clip(WALK) if _moving and _clip(WALK) != "" else _clip(IDLE)
	if n == "":
		player.stop()
		return
	player.play(n, 0.0 if snap else 0.12)
	if snap: player.seek(0.0, true)

func _on_finished(anim_name: StringName) -> void:
	if _dead or anim_name == _clip(DIE): return
	_play_rest()
