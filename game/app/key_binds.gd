extends Node
## Autoload `KeyBinds` (InputBindings.cs + GameKeys.cs): rebindable keys. Actions are registered by id
## (label, group, two default KeyCombos) and read by id — never hard-code keys:
##   KeyBinds.pressed("EndRound"), held("CameraUp"), released(...), modifier_held("QuickCast").
## Each action has two slots; each slot is a key with a Modifiers combination, matched exactly (End round =
## Enter or Shift+Space). "Bare" actions (camera, ability keys) match whatever is held. Modifier actions
## (Aim, QuickCast, Hand) pick only a combination, all different (choosing a taken one swaps them).
## A key may be bound twice (both fire; conflicts() tells the Controls page). Choices are saved in
## SaveData.settings.key_binds / modifier_binds; actions not saved use their defaults. Mouse buttons and
## Esc (back_pressed(): close/cancel/pause) stay fixed.
##
## Reads: _input records keys going down/up; at the start of each frame (process_priority -1000) they become
## this frame's pressed/released sets, so any _process this frame sees them once.

signal changed

# GameKeys.cs ids
const EndRound := "EndRound"
const Skip := "Skip"
const Pause := "Pause"
## Co-op only: Pass (give your turn away) and opening the match chat.
const Pass := "Pass"
const Chat := "Chat"
const CameraUp := "CameraUp"
const CameraDown := "CameraDown"
const CameraLeft := "CameraLeft"
const CameraRight := "CameraRight"
const RotateLeft := "RotateLeft"
const RotateRight := "RotateRight"
const Aim := "Aim"
const QuickCast := "QuickCast"
const Hand := "Hand"
## How many ability keys there are (Ability1–Ability9).
const AbilityKeys := 9

## The id of the i-th ability key (0-based): "Ability1"…
static func ability(index: int) -> String:
	return "Ability%d" % (index + 1)

## Registered key actions in registration order: {id, label, group, primary: KeyCombo, secondary: KeyCombo, any_modifiers}.
var actions: Array = []
## Registered modifier actions: {id, label, group, modifiers}.
var modifier_actions: Array = []

## While true (the Controls page is capturing a key), pressed/held/released report nothing.
var block_keys: bool = false

## Settings to store into instead of SaveData.settings (tests; nothing is saved then).
var settings_override: SettingsData = null

var _down := {}             # keycode → true, keys held now
var _pressed := {}          # this frame
var _released := {}
var _pressed_next := {}     # recorded by _input, become this frame's at the next _process
var _released_next := {}
var _fallback := SettingsData.new()

func _init() -> void:
	register_game_keys()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000

## GameKeys.Register: the game's actions with their defaults.
func register_game_keys() -> void:
	var g_round := "Round"; var g_towers := "Towers"; var g_camera := "Camera"
	register(EndRound, "End round", g_round, KeyCombo.new(KEY_ENTER), KeyCombo.new(KEY_SPACE, Modifiers.Shift))
	register(Skip, "Skip / continue", g_round, KeyCombo.new(KEY_SPACE))
	register(Pause, "Pause (also Esc)", g_round, KeyCombo.new(KEY_P))
	register_modifier(Aim, "Aim modifier", g_towers, Modifiers.None)
	register_modifier(QuickCast, "Quick cast modifier", g_towers, Modifiers.Shift)
	register_modifier(Hand, "Hand card modifier", g_towers, Modifiers.Ctrl)
	for i in AbilityKeys:
		register(ability(i), "Ability %d" % (i + 1), g_towers, KeyCombo.new(KEY_1 + i), null, true)
	register(CameraUp, "Move camera up", g_camera, KeyCombo.new(KEY_W), KeyCombo.new(KEY_UP), true)
	register(CameraDown, "Move camera down", g_camera, KeyCombo.new(KEY_S), KeyCombo.new(KEY_DOWN), true)
	register(CameraLeft, "Move camera left", g_camera, KeyCombo.new(KEY_A), KeyCombo.new(KEY_LEFT), true)
	register(CameraRight, "Move camera right", g_camera, KeyCombo.new(KEY_D), KeyCombo.new(KEY_RIGHT), true)
	register(RotateLeft, "Rotate camera left", g_camera, KeyCombo.new(KEY_Q))
	register(RotateRight, "Rotate camera right", g_camera, KeyCombo.new(KEY_E))
	register(Pass, "Pass (give your turn away)", "Co-op", KeyCombo.new(KEY_TAB))
	register(Chat, "Open the chat", "Co-op", KeyCombo.new(KEY_T))

# ---------------------------------------------------------------- key actions

## Adds a key action (or updates it when the id is already registered).
func register(id: String, label: String, group: String, primary: KeyCombo, secondary: KeyCombo = null, any_modifiers := false) -> void:
	if secondary == null: secondary = KeyCombo.none()
	var a = find(id)
	if a == null:
		a = {"id": id}
		actions.append(a)
	a.label = label
	a.group = group
	a.any_modifiers = any_modifiers
	a.primary = KeyCombo.new(primary.key) if any_modifiers else primary.copy()
	a.secondary = KeyCombo.new(secondary.key) if any_modifiers else secondary.copy()

## The registered key action (Dictionary), or null.
func find(id: String):
	for a in actions:
		if a.id == id: return a
	return null

## An action's key in a slot (0 primary, 1 secondary); KeyCombo.none() when unbound or unknown.
func get_bind(id: String, slot: int) -> KeyCombo:
	var saved = _saved(id)
	if saved != null: return saved.primary if slot == 0 else saved.secondary
	var a = find(id)
	if a == null: return KeyCombo.none()
	return a.primary if slot == 0 else a.secondary

## One of the action's keys went down this frame with its combination held.
func pressed(id: String) -> bool:
	return not _blocked() and (_matches(id, 0, _pressed) or _matches(id, 1, _pressed))

## One of the action's keys is held with its combination.
func held(id: String) -> bool:
	return not _blocked() and (_matches(id, 0, _down) or _matches(id, 1, _down))

## One of the action's keys went up this frame (whatever is held).
func released(id: String) -> bool:
	if _blocked(): return false
	var a := get_bind(id, 0)
	var b := get_bind(id, 1)
	return (not a.is_none and _released.has(a.key)) or (not b.is_none and _released.has(b.key))

## Keys are not for the game now: block_keys is on, or a text field has the focus (typing a name).
func _blocked() -> bool:
	if block_keys: return true
	if not is_inside_tree(): return false
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

## Esc went down this frame (fixed: cancel aiming/placing first, else pause / close the panel).
func back_pressed() -> bool:
	return not block_keys and _pressed.has(KEY_ESCAPE)

## A raw key went down this frame (for fixed keys; prefer actions).
func key_pressed(keycode: int) -> bool:
	return not block_keys and _pressed.has(keycode)

## Binds a key to an action's slot (KeyCombo.none() clears it); bare actions drop the combination.
## Other actions keep the key if they have it (see conflicts). Saved at once.
func set_bind(id: String, slot: int, combo: KeyCombo) -> void:
	var a = find(id)
	if a == null: return
	if combo == null: combo = KeyCombo.none()
	combo = KeyCombo.new(combo.key) if a.any_modifiers else combo.copy()
	_write(id, slot, combo)
	_save()
	changed.emit()

## Whether an action's slot shares its key with another slot (another action's, or its own other slot): both
## would fire. A bare key clashes with that key under any combination.
func conflicts(id: String, slot: int) -> bool:
	var a = find(id)
	var combo := get_bind(id, slot)
	if a == null or combo.is_none: return false
	for other in actions:
		for s in 2:
			if (other.id != id or s != slot) and _clashes(get_bind(other.id, s), other.any_modifiers, combo, a.any_modifiers):
				return true
	return false

## Every [id, slot] that conflicts (empty when none).
func all_conflicts() -> Array:
	var out := []
	for a in actions:
		for s in 2:
			if conflicts(a.id, s): out.append([a.id, s])
	return out

# ---------------------------------------------------------------- modifier actions

## Adds a modifier action (or updates it).
func register_modifier(id: String, label: String, group: String, default_modifiers: int) -> void:
	var a = _find_modifier(id)
	if a == null:
		a = {"id": id}
		modifier_actions.append(a)
	a.label = label
	a.group = group
	a.modifiers = default_modifiers

## The combination a modifier action uses now.
func get_modifier(id: String) -> int:
	for b in _settings().modifier_binds:
		if b.action == id: return b.modifiers
	var a = _find_modifier(id)
	return a.modifiers if a != null else Modifiers.None

## Gives a modifier action a combination; another action that had it takes this one's old one. Saved at once.
func set_modifier(id: String, modifiers: int) -> void:
	if _find_modifier(id) == null: return
	var old := get_modifier(id)
	if old == modifiers: return
	for other in modifier_actions:
		if other.id != id and get_modifier(other.id) == modifiers: _write_modifier(other.id, old)
	_write_modifier(id, modifiers)
	_save()
	changed.emit()

## The combination held now (exactly), or -1 for one not offered (e.g. Alt+Shift).
func held_modifiers() -> int:
	var shift := _down.has(KEY_SHIFT)
	var ctrl := _down.has(KEY_CTRL) or _down.has(KEY_META)
	var alt := _down.has(KEY_ALT)
	if alt: return -1 if (shift or ctrl) else Modifiers.Alt
	if ctrl: return Modifiers.CtrlShift if shift else Modifiers.Ctrl
	return Modifiers.Shift if shift else Modifiers.None

## The modifier action's combination is held now (exactly; None: no modifier held).
func modifier_held(id: String) -> bool:
	return held_modifiers() == get_modifier(id)

# ---------------------------------------------------------------- reset

## Every action back to its default keys and combinations. Saved at once.
func reset_all() -> void:
	_settings().key_binds.clear()
	_settings().modifier_binds.clear()
	_save()
	changed.emit()

# ---------------------------------------------------------------- names for players

## The action's keys, e.g. "Enter · Shift+Space"; "" when it has none (the C# returned null).
func describe(id: String) -> String:
	var a := get_bind(id, 0)
	var b := get_bind(id, 1)
	if a.is_none and b.is_none: return ""
	if a.is_none: return combo_text(b)
	if b.is_none: return combo_text(a)
	return combo_text(a) + " · " + combo_text(b)

## The first key of an action (e.g. "Enter"); "unbound" when it has none.
func first(id: String) -> String:
	var k := get_bind(id, 0)
	if k.is_none: k = get_bind(id, 1)
	return "unbound" if k.is_none else combo_text(k)

## A modifier action's combination with a key action's first key, e.g. "Shift+1" or "1"; "" when unbound.
func combo(modifier_id: String, key_id: String) -> String:
	var k := get_bind(key_id, 0)
	if k.is_none: k = get_bind(key_id, 1)
	return "" if k.is_none else combo_text(KeyCombo.new(k.key, get_modifier(modifier_id)))

## A click with a modifier action's combination: "Shift-click", or "Click" for none.
func click_text(modifier_id: String) -> String:
	var m := get_modifier(modifier_id)
	return "Click" if m == Modifiers.None else modifier_name(m) + "-click"

## Replaces {key:Id} with that action's first key and {click:Id} with a modifier action's click
## ("Shift-click", "click" for none), so hints and speech follow the player's bindings.
func fill_keys(text: String) -> String:
	if text == "": return text
	text = _replace(text, "\\{key:(\\w+)\\}", func(id): return first(id))
	return _replace(text, "\\{click:(\\w+)\\}", func(id): return "click" if get_modifier(id) == Modifiers.None else click_text(id))

## A key with its combination: "Shift+Space", "Enter"; "-" for none.
static func combo_text(c: KeyCombo) -> String:
	if c == null or c.is_none: return "-"
	return key_name(c.key) if c.modifiers == Modifiers.None else modifier_name(c.modifiers) + "+" + key_name(c.key)

## A combination: "Shift", "Ctrl+Shift"…; "None" for the key alone.
static func modifier_name(m: int) -> String:
	return "Ctrl+Shift" if m == Modifiers.CtrlShift else Modifiers.name_of(m)

## A key's name: "1", "Num 1", "Enter", "Up", "Esc"…; "-" for none.
static func key_name(key: int) -> String:
	if key == KEY_NONE: return "-"
	if key >= KEY_0 and key <= KEY_9: return str(key - KEY_0)
	if key >= KEY_KP_0 and key <= KEY_KP_9: return "Num %d" % (key - KEY_KP_0)
	match key:
		KEY_ENTER: return "Enter"
		KEY_KP_ENTER: return "Num Enter"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_UP: return "Up"
		KEY_DOWN: return "Down"
		KEY_LEFT: return "Left"
		KEY_RIGHT: return "Right"
		KEY_ESCAPE: return "Esc"
		KEY_QUOTELEFT: return "`"
		KEY_MINUS: return "-"
		KEY_EQUAL: return "="
		KEY_COMMA: return ","
		KEY_PERIOD: return "."
		KEY_SLASH: return "/"
		KEY_BACKSLASH: return "\\"
		KEY_SEMICOLON: return ";"
		KEY_APOSTROPHE: return "'"
		KEY_BRACKETLEFT: return "["
		KEY_BRACKETRIGHT: return "]"
		KEY_PAGEUP: return "Page Up"
		KEY_PAGEDOWN: return "Page Down"
		KEY_CAPSLOCK: return "Caps Lock"
	return OS.get_keycode_string(key)

## Shift, Ctrl, Alt (and Meta) are combinations, never keys of their own.
static func is_modifier_key(key: int) -> bool:
	return key == KEY_SHIFT or key == KEY_CTRL or key == KEY_ALT or key == KEY_META

## The KeyCombo a key event means (for the Controls page's capture), or null for a release, an echo or a
## modifier key alone. The combination is read from the event's modifier flags.
static func combo_from_event(event: InputEvent) -> KeyCombo:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo: return null
	var code := _code_of(k)
	if code == KEY_NONE or is_modifier_key(code): return null
	var ctrl := k.ctrl_pressed or k.meta_pressed
	var m := Modifiers.None
	if k.alt_pressed:
		if ctrl or k.shift_pressed: return null # not a combination the game offers
		m = Modifiers.Alt
	elif ctrl: m = Modifiers.CtrlShift if k.shift_pressed else Modifiers.Ctrl
	elif k.shift_pressed: m = Modifiers.Shift
	return KeyCombo.new(code, m)

# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	feed(event)

## Records a key event (called by _input; tests and tools may feed events directly).
func feed(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or k.echo: return
	var code := _code_of(k)
	if code == KEY_NONE: return
	if k.pressed:
		if not _down.has(code): _pressed_next[code] = true
		_down[code] = true
	else:
		_down.erase(code)
		_released_next[code] = true

## Starts a new input frame: the keys recorded since the last one become pressed/released now.
func next_frame() -> void:
	_pressed = _pressed_next
	_released = _released_next
	_pressed_next = {}
	_released_next = {}

func _process(_delta: float) -> void:
	next_frame()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		for code in _down: _released_next[code] = true
		_down.clear()

static func _code_of(k: InputEventKey) -> int:
	var code: int = k.keycode if k.keycode != KEY_NONE else k.physical_keycode
	return code

# ---------------------------------------------------------------- matching / storage

func _matches(id: String, slot: int, keys: Dictionary) -> bool:
	var c := get_bind(id, slot)
	if c.is_none or not keys.has(c.key): return false
	var a = find(id)
	return a != null and (a.any_modifiers or held_modifiers() == c.modifiers)

static func _clashes(a: KeyCombo, a_bare: bool, b: KeyCombo, b_bare: bool) -> bool:
	return not a.is_none and not b.is_none and a.key == b.key and (a_bare or b_bare or a.modifiers == b.modifiers)

func _settings() -> SettingsData:
	if settings_override != null: return settings_override
	var sd := get_node_or_null("/root/SaveData") if is_inside_tree() else null
	return sd.settings if sd != null else _fallback

func _saved(id: String):
	for b in _settings().key_binds:
		if b.action == id: return b
	return null

func _find_modifier(id: String):
	for a in modifier_actions:
		if a.id == id: return a
	return null

## Writes one slot, saving the action's other slot as it is now (its default the first time).
func _write(id: String, slot: int, c: KeyCombo) -> void:
	var b = _saved(id)
	if b == null:
		b = {"action": id, "primary": get_bind(id, 0), "secondary": get_bind(id, 1)}
		_settings().key_binds.append(b)
	if slot == 0: b.primary = c
	else: b.secondary = c

func _write_modifier(id: String, m: int) -> void:
	for b in _settings().modifier_binds:
		if b.action == id:
			b.modifiers = m
			return
	_settings().modifier_binds.append({"action": id, "modifiers": m})

func _save() -> void:
	if settings_override != null: return
	var sd := get_node_or_null("/root/SaveData") if is_inside_tree() else null
	if sd != null: sd.save()

static func _replace(text: String, pattern: String, fn: Callable) -> String:
	var re := RegEx.create_from_string(pattern)
	var out := ""
	var at := 0
	for m in re.search_all(text):
		out += text.substr(at, m.get_start() - at) + str(fn.call(m.get_string(1)))
		at = m.get_end()
	return out + text.substr(at)
