class_name SettingsData
extends RefCounted
## All player-configurable settings (GameData.cs `SettingsData`). Saved under "settings" in user://gamedata.json
## with the Unity field names (masterVolume, isFullscreen…); fields missing from a save keep these defaults.

# --- Audio ---
var master_volume: float = 0.3
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var other_volume: float = 1.0

# --- Display ---
var resolution_width: int = 1920
var resolution_height: int = 1080
var is_fullscreen: bool = true

# --- Gameplay ---
var game_speed: float = 1.0
## The camera glides to centre each action as it starts.
var follow_action: bool = false
## The camera glides to the unit you select (board click, tray piece or key). On by default.
var follow_selection: bool = true
## Holding the left mouse button and moving drags the map (a press that moves is a drag, not a click).
var drag_to_pan: bool = true
## Animations finish as soon as they start (a command's result shows in one frame).
var instant_playback: bool = false
## HP bars over entities always show; off, they show only once an entity is damaged.
var always_show_health: bool = false

# --- Controls ---
## Rebound keys (KeyBinds): one {action: String, primary: KeyCombo, secondary: KeyCombo} per changed action.
var key_binds: Array = []
## Changed modifier choices: one {action: String, modifiers: int} per changed modifier action.
var modifier_binds: Array = []

## [JSON name, property] of every plain field, in the Unity order.
const FIELDS := [
	["masterVolume", "master_volume"], ["musicVolume", "music_volume"], ["sfxVolume", "sfx_volume"],
	["otherVolume", "other_volume"], ["resolutionWidth", "resolution_width"], ["resolutionHeight", "resolution_height"],
	["isFullscreen", "is_fullscreen"], ["gameSpeed", "game_speed"], ["followAction", "follow_action"],
	["followSelection", "follow_selection"], ["dragToPan", "drag_to_pan"], ["instantPlayback", "instant_playback"],
	["alwaysShowHealth", "always_show_health"],
]

func to_dict() -> Dictionary:
	var d := {}
	for f in FIELDS: d[f[0]] = get(f[1])
	var kb := []
	for b in key_binds:
		kb.append({"action": b.action, "primary": b.primary.to_dict(), "secondary": b.secondary.to_dict()})
	d["keyBinds"] = kb
	var mb := []
	for b in modifier_binds:
		mb.append({"action": b.action, "modifiers": b.modifiers})
	d["modifierBinds"] = mb
	return d

static func from_dict(d) -> SettingsData:
	var s := SettingsData.new()
	if not (d is Dictionary): return s
	for f in FIELDS:
		if not d.has(f[0]): continue
		var cur = s.get(f[1])
		var v = d[f[0]]
		if cur is bool: s.set(f[1], bool(v))
		elif cur is int: s.set(f[1], int(v))
		else: s.set(f[1], float(v))
	for b in d.get("keyBinds", []):
		if b is Dictionary and str(b.get("action", "")) != "":
			s.key_binds.append({"action": str(b.action), "primary": KeyCombo.from_dict(b.get("primary")),
				"secondary": KeyCombo.from_dict(b.get("secondary"))})
	for b in d.get("modifierBinds", []):
		if b is Dictionary and str(b.get("action", "")) != "":
			s.modifier_binds.append({"action": str(b.action), "modifiers": clampi(int(b.get("modifiers", 0)), 0, Modifiers.CtrlShift)})
	return s
