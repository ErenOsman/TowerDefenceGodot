class_name KeyCombo
extends RefCounted
## One key of an action (InputBindings.cs `KeyCombo`): a Godot key (`Key`, KEY_NONE = unbound) with the
## Modifiers combination held with it. Treat as a value: never mutate one that is stored, make a new one.

var key: int = KEY_NONE
var modifiers: int = Modifiers.None

func _init(p_key: int = KEY_NONE, p_modifiers: int = Modifiers.None) -> void:
	key = p_key
	modifiers = p_modifiers

var is_none: bool:
	get: return key == KEY_NONE

static func none() -> KeyCombo:
	return KeyCombo.new()

func equals(other: KeyCombo) -> bool:
	return other != null and key == other.key and (key == KEY_NONE or modifiers == other.modifiers)

func copy() -> KeyCombo:
	return KeyCombo.new(key, modifiers)

## Saved form: {"key": "Enter", "modifiers": 0} — the key by its Godot name (OS.get_keycode_string), the
## combination as the Unity save stored it (the enum's number).
func to_dict() -> Dictionary:
	return {"key": "" if key == KEY_NONE else OS.get_keycode_string(key), "modifiers": modifiers}

static func from_dict(d) -> KeyCombo:
	if not (d is Dictionary): return KeyCombo.none()
	var k = d.get("key", "")
	var code := KEY_NONE
	if k is String:
		code = OS.find_keycode_from_string(k) if k != "" else KEY_NONE
	elif k is float or k is int:
		code = int(k)
	var m = d.get("modifiers", 0)
	var mods := int(m) if (m is float or m is int) else maxi(0, Modifiers.parse(str(m)))
	return KeyCombo.new(code, clampi(mods, 0, Modifiers.CtrlShift))

func _to_string() -> String:
	return "KeyCombo(%s, %s)" % [OS.get_keycode_string(key), Modifiers.name_of(modifiers)]
