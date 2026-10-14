class_name NetProtocol
extends RefCounted
## The co-op relay protocol v1 (docs/COOP-PROTOCOL.md): JSON text frames, one object per frame, field `t` = type.
## Encoding/decoding, the client → relay message builders, limits, the player-facing text for relay errors, and
## pure helpers the screens share (room diff → chat notes, swear filter used by the fake relay). No Node, no I/O.

const PROTOCOL := "coop-1"
const CLIENT := "godot-td/0.7"
const DEFAULT_URL := "ws://92.5.94.11/ws/relay"

const MAX_PLAYER_NAME := 16
const MAX_ROOM_NAME := 24
const MAX_CHAT := 200
const MIN_COUNT := 1
const MAX_COUNT := 6
const DEFAULT_COUNT := 2

## Client → relay types.
const CLIENT_TYPES := ["hello", "list", "create", "join", "leave", "ready", "set_level", "set_count", "kick", "chat",
	"set_hand", "start", "cmd", "checksum", "pong"]
## Relay → client types.
const RELAY_TYPES := ["welcome", "rooms", "room", "error", "chat", "kicked", "match_start", "cmd", "desync",
	"player_left", "ping"]

const ERROR_CODES := ["not_found", "full", "wrong_password", "version", "started", "not_host", "bad_name", "bad_request"]

# ------------------------------------------------------------------ frames

## One message as a text frame.
static func encode(msg: Dictionary) -> String:
	return JSON.stringify(msg)

## A text frame as a message, or null when it is not a JSON object with a string `t`.
static func decode(text: String):
	var j := JSON.new()
	if j.parse(text) != OK: return null
	var d = j.data
	if not (d is Dictionary) or not (d.get("t") is String): return null
	return d

## JSON numbers come back as floats: an int field read safely.
static func int_of(msg: Dictionary, key: String, fallback := 0) -> int:
	var v = msg.get(key)
	if v is float or v is int: return int(v)
	if v is String and v.is_valid_int(): return v.to_int()
	return fallback

# ------------------------------------------------------------------ client → relay

static func hello(version: String, player_name: String) -> Dictionary:
	return {"t": "hello", "version": version, "name": clamp_text(player_name, MAX_PLAYER_NAME), "client": CLIENT}

static func list() -> Dictionary:
	return {"t": "list"}

## mission (optional): the mission id the room is for, sent as an extra field the relay ignores (it keeps and
## broadcasts only `level`; clients map the level back with CoopLevels.mission_for_level).
static func create(room_name: String, level: String, count: int, password: String, hand: Array, mission: String = "") -> Dictionary:
	var m := {"t": "create", "name": clamp_text(room_name, MAX_ROOM_NAME), "level": level,
		"count": clampi(count, MIN_COUNT, MAX_COUNT), "hand": hand.duplicate()}
	if password != "": m["password"] = password
	if mission != "": m["mission"] = mission
	return m

static func join(room_id: String, password: String, hand: Array) -> Dictionary:
	var m := {"t": "join", "room": room_id, "hand": hand.duplicate()}
	if password != "": m["password"] = password
	return m

static func leave() -> Dictionary: return {"t": "leave"}
static func ready(value: bool) -> Dictionary: return {"t": "ready", "value": value}
static func set_level(level: String) -> Dictionary: return {"t": "set_level", "level": level}
static func set_count(count: int) -> Dictionary: return {"t": "set_count", "count": clampi(count, MIN_COUNT, MAX_COUNT)}
static func kick(player: String) -> Dictionary: return {"t": "kick", "player": player}
static func chat(text: String) -> Dictionary: return {"t": "chat", "text": clamp_text(text, MAX_CHAT)}
static func set_hand(hand: Array) -> Dictionary: return {"t": "set_hand", "hand": hand.duplicate()}
static func start() -> Dictionary: return {"t": "start"}
static func cmd(round: int, seq: int, command: Dictionary) -> Dictionary:
	return {"t": "cmd", "round": round, "seq": seq, "cmd": command}
static func checksum(round: int, hash: String) -> Dictionary: return {"t": "checksum", "round": round, "hash": hash}
static func pong() -> Dictionary: return {"t": "pong"}

## Text cut to n characters (strip_edges first).
static func clamp_text(s: String, n: int) -> String:
	s = s.strip_edges()
	return s.substr(0, n) if s.length() > n else s

# ------------------------------------------------------------------ text for players

## The sentence a relay error shows (mockups: join-full, join-wrong, create-refused).
static func error_text(code: String) -> String:
	match code:
		"not_found": return "That room is gone."
		"full": return "This room is full. Pick another room, or make your own."
		"wrong_password": return "Wrong password. Ask the host for it again."
		"version": return "That room plays another game version."
		"started": return "That match has already started."
		"not_host": return "Only the host can do that."
		"bad_name": return "That name isn't allowed. Pick another name."
		"bad_request": return "The server did not understand that."
	return "Something went wrong (%s)." % code

# ------------------------------------------------------------------ room helpers

## The players of a room state ordered by slot (join order = turn order).
static func players_by_slot(room: Dictionary) -> Array:
	var out: Array = (room.get("players", []) as Array).duplicate()
	out.sort_custom(func(a, b): return int_of(a, "slot") < int_of(b, "slot"))
	return out

static func find_player(room: Dictionary, player_id: String):
	for p in room.get("players", []):
		if str(p.get("id", "")) == player_id: return p
	return null

static func player_name(room: Dictionary, player_id: String) -> String:
	var p = find_player(room, player_id)
	return str(p.get("name", "?")) if p != null else "?"

## Everyone present is Ready (empty slots don't block); false for an empty room.
static func all_ready(room: Dictionary) -> bool:
	var ps: Array = room.get("players", [])
	if ps.is_empty(): return false
	for p in ps:
		if not bool(p.get("ready", false)): return false
	return true

## The names of the players not Ready yet, in slot order.
static func not_ready_names(room: Dictionary) -> Array:
	var out := []
	for p in players_by_slot(room):
		if not bool(p.get("ready", false)): out.append(str(p.get("name", "?")))
	return out

## "A", "A and B", "A, B and C".
static func join_names(names: Array) -> String:
	if names.is_empty(): return ""
	if names.size() == 1: return str(names[0])
	var head := []
	for i in names.size() - 1: head.append(str(names[i]))
	return ", ".join(head) + " and " + str(names[names.size() - 1])

## What changed between two room states, as notes for the chat and banners:
## [{kind: "joined"|"left"|"host"|"level"|"count", name, value}]. old = {} → the room was just entered (nothing).
static func room_diff(old: Dictionary, new: Dictionary) -> Array:
	var out := []
	if old.is_empty() or new.is_empty() or str(old.get("id", "")) != str(new.get("id", "")): return out
	var before := {}
	for p in old.get("players", []): before[str(p.id)] = p
	var after := {}
	for p in new.get("players", []): after[str(p.id)] = p
	for id in before:
		if not after.has(id): out.append({"kind": "left", "name": str(before[id].get("name", "?"))})
	for p in players_by_slot(new):
		if not before.has(str(p.id)): out.append({"kind": "joined", "name": str(p.get("name", "?"))})
	if str(old.get("level", "")) != str(new.get("level", "")):
		out.append({"kind": "level", "name": player_name(new, str(new.get("host", ""))), "value": str(new.get("level", ""))})
	if int_of(old, "count") != int_of(new, "count"):
		out.append({"kind": "count", "name": player_name(new, str(new.get("host", ""))), "value": int_of(new, "count")})
	if str(old.get("host", "")) != str(new.get("host", "")) and after.has(str(new.get("host", ""))):
		out.append({"kind": "host", "name": player_name(new, str(new.get("host", "")))})
	return out

# ------------------------------------------------------------------ names

## Words a room name may not contain (the fake relay's filter; the real relay has its own list).
const BLOCKED_WORDS := ["fuck", "shit", "bitch", "cunt", "nigg", "orospu", "sik", "amk", "piç", "göt", "kötü isim"]

## The room name passes the swear filter and is not empty.
static func name_allowed(room_name: String) -> bool:
	var s := room_name.strip_edges().to_lower()
	if s == "": return false
	var turkish := s.replace("İ".to_lower(), "i").replace("ı", "i")
	for w in BLOCKED_WORDS:
		var wl: String = w.to_lower()
		if s.contains(wl) or turkish.contains(wl.replace("ı", "i")):
			# whole words only for the short ones ("sik" in "klasik" is fine)
			if wl.length() <= 3 and not _whole_word(turkish, wl): continue
			return false
	return true

static func _whole_word(s: String, w: String) -> bool:
	for part in s.split(" ", false):
		if part == w: return true
	return false

# ------------------------------------------------------------------ checksum

## FNV-1a 64 of a string (UTF-8 bytes) as 16 hex chars — the checksum over CoopSession.state_digest() when the
## session has no checksum of its own.
static func fnv1a64(s: String) -> String:
	var h := -3750763034362895579 # 0xcbf29ce484222325 as signed 64
	var prime := 1099511628211
	for b in s.to_utf8_buffer():
		h = h ^ b
		h = h * prime # wraps (64-bit signed arithmetic)
	return "%08x%08x" % [(h >> 32) & 0xFFFFFFFF, h & 0xFFFFFFFF]
