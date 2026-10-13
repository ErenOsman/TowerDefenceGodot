class_name CoopSession
extends RefCounted
## One co-op match of a level for 1 to 6 players (Multiplayer — Design, co-op; decisions of 2026-10-13).
## Godot-only (no C# counterpart). It wraps a CoopLevelSession — a LevelSession whose rules are unchanged —
## and adds who may act: the player phase is split into one turn per player in slot (join) order; Pass
## moves the player to the end of this round's order (it never ends the turn); End turn is final for the
## round; when every player has ended, the wrapped session's end_round runs the enemy and level phases and
## the next round starts with the slot order again. Each player brings their own hand (tower IDs
## "<player id>:<type id>#<n>", at most the co-op hand cap) and commands only their own towers; bases and
## starting allies are anyone's. Energy is one shared pool, or one pool + income per player with the
## level's start energy and income split 1/N (integer division, the remainder to slot 0).
## A player who leaves mid-match: their turn is skipped from then on, their towers become neutral (any
## remaining player may cast with them), their pool is closed.
##
## The presentation reads `session` (a LevelSession) exactly as in single player: same state, log,
## Director and ViewFrames. Clients stay in step by applying the relay's commands in relay order
## (apply_command) and comparing checksum() after each round (docs/COOP-PROTOCOL.md).

const MaxPlayers := 6
const DefaultHandCap := 3

## The wrapped level session (hand them this for the presentation).
var session: CoopLevelSession
## Every player ID in slot order (turn order at the start of each round), leavers included.
var slots: Array[String] = []
## Player ID → their hand (Array of TowerDef, cut to hand_cap).
var hands: Dictionary = {}
## Player IDs who left the match (a set: id → true).
var left: Dictionary = {}
var shared_pool: bool = true
var hand_cap: int = DefaultHandCap
## Separate pools only: player ID → energy (closed pools are erased). Empty with a shared pool.
var pools: Dictionary = {}
## Separate pools only: player ID → their share of the level's income per round.
var income_share: Dictionary = {}
## This round's players who have not ended their turn yet; the first one is acting.
var turn_order: Array[String] = []
## Why the last refused call said no ("" when it was allowed).
var last_reason: String = ""
## Set by the constructor when the setup is invalid (player count, duplicate IDs); "" otherwise.
var last_error: String = ""

## Tower ID → the player ID whose hand it came from.
var _owner: Dictionary = {}
## The player whose command is running ("" outside commands: level phase income goes to every pool).
var _actor: String = ""

## CoopSession.new(level, rules, players, seed, shared_pool, hand_cap)
## players: Array of {"id": String, "hand": Array of TowerDef} in slot order (1 to 6).
## Build hands from tower type IDs with CoopSession.build_hand.
func _init(level: LevelDef, rules: GameRules, players: Array, p_seed: int, p_shared_pool: bool = true, p_hand_cap: int = DefaultHandCap) -> void:
	shared_pool = p_shared_pool
	hand_cap = maxi(0, p_hand_cap)
	var all_towers: Array = []
	for p in players:
		var pid: String = str(p.get("id", ""))
		if pid == "" or hands.has(pid):
			last_error = "Player ID '%s' is empty or used twice." % pid
			continue
		slots.append(pid)
		var h: Array = Array(p.get("hand", [])).slice(0, hand_cap)
		hands[pid] = h
		for t in h:
			_owner[t.id] = pid
			all_towers.append(t)
	if slots.is_empty() or slots.size() > MaxPlayers:
		last_error = "A co-op match needs 1 to %d players (got %d)." % [MaxPlayers, slots.size()]
	session = CoopLevelSession.new(level, rules, all_towers, p_seed)
	if session.last_error != "" and last_error == "": last_error = session.last_error
	session.attach(self)
	if not shared_pool:
		var n := slots.size()
		var start := split(level.start_energy, n)
		var income := split(level.energy_per_round, n)
		for i in n:
			pools[slots[i]] = start[i]
			income_share[slots[i]] = income[i]
	_mirror_energy()

## Splits an amount evenly into n shares, the remainder to share 0 (integer division).
static func split(amount: int, n: int) -> Array:
	var out := []
	if n <= 0: return out
	var each := amount / n
	for i in n: out.append(each)
	out[0] += amount - each * n
	return out

## A player's hand from tower type IDs (the protocol's `hand`): tower IDs "<player id>:<type id>#<n>", n counting
## each type from 1. type_by_id: Callable(String) -> TowerType; unknown types are skipped.
static func build_hand(player_id: String, type_ids: Array, type_by_id: Callable) -> Array:
	var out := []
	var counts := {}
	for type_id in type_ids:
		var type: TowerType = type_by_id.call(str(type_id))
		if type == null: continue
		counts[type_id] = counts.get(type_id, 0) + 1
		var d := TowerDef.new()
		d.id = "%s:%s#%d" % [player_id, type_id, counts[type_id]]
		d.type = type
		out.append(d)
	return out

# ------------------------------------------------------------------ queries

var state: GameState:
	get: return session.state
var log: EventLog:
	get: return session.log
var round: int:
	get: return session.round
var is_over: bool:
	get: return session.is_over

## The players still in the match, in slot order.
var players: Array[String]:
	get:
		var out: Array[String] = []
		for p in slots:
			if not left.has(p): out.append(p)
		return out

## Whose turn it is ("" when nobody can act: not started, outside the player phase, over, everyone left).
var current_player: String:
	get:
		if session.phase != Phase.Player or session.is_over or turn_order.is_empty(): return ""
		return turn_order[0]

## The slot (join order index) of a player, or -1.
func slot_of(player: String) -> int:
	return slots.find(player)

## A player's energy: the shared pool, their own pool, or 0 when it is closed (or unknown player).
func energy_of(player: String) -> int:
	if shared_pool: return session.energy if slots.has(player) and not left.has(player) else 0
	return pools.get(player, 0)

## The player whose hand a tower ID came from, or "".
func owner_of(tower_id: String) -> String:
	return _owner.get(tower_id, "")

## A player's hand towers (TowerDefs).
func hand_of(player: String) -> Array:
	return hands.get(player, [])

## Whether it is that player's turn and they may act.
func can_act(player: String) -> bool:
	last_reason = _turn_error(player)
	return last_reason == ""

## Whether the player may command that unit: their own placed tower, a leaver's tower (neutral now), a base or a
## starting ally. Other units are left to the session's own rule ("Not a placed tower or a base").
func controls(player: String, unit: Entity) -> bool:
	if unit == null: return false
	var tid = session.tower_id_of(unit)
	if tid != null:
		var owner := owner_of(tid)
		return owner == player or left.has(owner)
	return true

## The units a player may command now (session order: towers, then bases and allies).
func units_of(player: String) -> Array:
	var out := []
	for u in session.player_units:
		if controls(player, u): out.append(u)
	return out

## Whether the player could still do something besides walking in their turn (the HUD's End turn hint).
func anything_to_do(player: String) -> bool:
	if not can_act(player): return false
	for unit in units_of(player):
		for ability in unit.abilities:
			if not ability.targeting.is_movement and session.can_cast(unit, ability): return true
	for t in hand_of(player):
		if not session.placed.has(t.id) and energy_of(player) >= t.cost: return true
	return false

# ------------------------------------------------------------------ flow

## Starts round 1: the player phase, slot 0 acting.
func start() -> void:
	if session.phase != Phase.NotStarted:
		push_error("The match has already started.")
		return
	session.start()
	_reset_order()

## Gives the turn away: the player moves to the end of this round's order. Never ends their turn.
func pass_turn(player: String) -> bool:
	if not can_act(player): return false
	turn_order.remove_at(0)
	turn_order.append(player)
	_mirror_energy()
	return true

## Ends the player's turn for this round; when every player has ended, the enemy and level phases run and the
## next round starts.
func end_turn(player: String) -> bool:
	if not can_act(player): return false
	turn_order.remove_at(0)
	if turn_order.is_empty(): _finish_round()
	_mirror_energy()
	return true

## A player leaves mid-match: their turn is skipped from then on, their towers become neutral, their pool closes.
## Returns false for an unknown player or one who already left.
func remove_player(player: String) -> bool:
	if not slots.has(player) or left.has(player):
		last_reason = "Not in the match"
		return false
	left[player] = true
	pools.erase(player)
	income_share.erase(player)
	var was_waiting := not turn_order.is_empty()
	turn_order.erase(player)
	if was_waiting and turn_order.is_empty() and not players.is_empty() \
			and session.phase == Phase.Player and not session.is_over:
		_finish_round()
	_mirror_energy()
	last_reason = ""
	return true

func _finish_round() -> void:
	session.end_round()
	_reset_order()

func _reset_order() -> void:
	turn_order.clear()
	if session.phase == Phase.Player and not session.is_over: turn_order.assign(players)

# ------------------------------------------------------------------ player commands

func can_place(player: String, tower_id: String, tile: Vector2i) -> bool:
	if not can_act(player): return false
	if owner_of(tower_id) != player: return _no("Not in your hand" if session.tower(tower_id) != null else "Not in the hand")
	_mirror_energy()
	var ok := session.can_place(tower_id, tile)
	last_reason = session.last_reason
	return ok

## Places one of the player's hand towers; null (and last_reason) when refused.
func place(player: String, tower_id: String, tile: Vector2i) -> Entity:
	if not can_place(player, tower_id, tile): return null
	_actor = player
	var made := session.place(tower_id, tile)
	_actor = ""
	_mirror_energy()
	return made

func can_sell(player: String, tower_id: String) -> bool:
	if not can_act(player): return false
	if session.placed_tower(tower_id) != null and owner_of(tower_id) != player: return _no("Not your tower")
	var ok := session.can_sell(tower_id)
	last_reason = session.last_reason
	return ok

## Sells one of the player's placed towers; the refund goes to their pool.
func sell(player: String, tower_id: String) -> bool:
	if not can_sell(player, tower_id): return false
	_actor = player
	var ok := session.sell(tower_id)
	_actor = ""
	_mirror_energy()
	return ok

func can_cast(player: String, unit: Entity, ability: AbilityDef) -> bool:
	if not can_act(player): return false
	if unit != null and not controls(player, unit): return _no("Not your tower")
	var ok := session.can_cast(unit, ability)
	last_reason = session.last_reason
	return ok

## Casts with a unit the player commands; the aim is validated first (false + last_reason when refused).
func cast(player: String, unit: Entity, ability: AbilityDef, aim: Aim) -> bool:
	if not can_cast(player, unit, ability): return false
	if not Targeting.is_valid_aim(session.state, unit.id, ability, aim): return _no(Targeting.last_reason)
	_actor = player
	var ok := session.cast(unit, ability, aim)
	_actor = ""
	_mirror_energy()
	return ok

# ------------------------------------------------------------------ protocol commands

## Applies one protocol command (docs/COOP-PROTOCOL.md, CoopSession.Command) for a player:
##   {"k": "place", "tower": String, "x": int, "y": int}   {"k": "sell", "tower": String}
##   {"k": "cast", "unit": int, "ability": String (AbilityDef.name), "x": int, "y": int, "path": [[x, y], …] (walks; optional)}
##   {"k": "pass"}   {"k": "end_turn"}
## Numbers may arrive as floats (JSON). Returns false with last_reason when refused (nothing changes then).
func apply_command(player: String, cmd: Dictionary) -> bool:
	var k = cmd.get("k")
	match k:
		"pass": return pass_turn(player)
		"end_turn": return end_turn(player)
		"place":
			if not (cmd.get("tower") is String) or not _is_num(cmd.get("x")) or not _is_num(cmd.get("y")): return _no("Bad command")
			return place(player, cmd.tower, Vector2i(int(cmd.x), int(cmd.y))) != null
		"sell":
			if not (cmd.get("tower") is String): return _no("Bad command")
			return sell(player, cmd.tower)
		"cast":
			if not _is_num(cmd.get("unit")) or not (cmd.get("ability") is String) or not _is_num(cmd.get("x")) or not _is_num(cmd.get("y")):
				return _no("Bad command")
			var unit: Entity = session.state.get_entity(int(cmd.unit))
			if unit == null or int(cmd.unit) == 0: return _no("No such unit")
			var ability: AbilityDef = null
			for a in unit.abilities:
				if a != null and a.name == cmd.ability:
					ability = a
					break
			if ability == null: return _no("Not its ability")
			if not can_cast(player, unit, ability): return false
			var tile := Vector2i(int(cmd.x), int(cmd.y))
			var aim: Aim = null
			for a in Targeting.valid_aims(session.state, unit.id, ability):
				if a.tile == tile:
					aim = a
					break
			if aim == null: return _no("Not a valid target")
			var path = cmd.get("path")
			if path is Array and not path.is_empty():
				var tiles := []
				for p in path:
					if not (p is Array) or p.size() != 2 or not _is_num(p[0]) or not _is_num(p[1]): return _no("Bad command")
					tiles.append(Vector2i(int(p[0]), int(p[1])))
				var walk := Aim.new(aim.tile, aim.dir)
				walk.path = tiles
				aim = walk
			return cast(player, unit, ability, aim)
	return _no("Unknown command")

## The protocol command for a placement.
static func place_command(tower_id: String, tile: Vector2i) -> Dictionary:
	return {"k": "place", "tower": tower_id, "x": tile.x, "y": tile.y}

static func sell_command(tower_id: String) -> Dictionary:
	return {"k": "sell", "tower": tower_id}

## The protocol command for a cast (the path only for walks that carry one).
static func cast_command(unit: Entity, ability: AbilityDef, aim: Aim) -> Dictionary:
	var c := {"k": "cast", "unit": unit.id, "ability": ability.name, "x": aim.tile.x, "y": aim.tile.y}
	if ability.targeting.is_movement and aim.path is Array and not aim.path.is_empty():
		var path := []
		for p in aim.path: path.append([p.x, p.y])
		c["path"] = path
	return c

# ------------------------------------------------------------------ checksum

## The canonical state string both clients hash: round, phase, outcome, turn order, pools, leavers, placed
## towers, waves, RNG state, and every entity (by id) with position, life, team, facing, hp, shield, resources,
## statuses (def name, stacks, turns, shield pool), cooldowns. Sorted keys, ints as ints, floats via Num.to_str.
func state_digest() -> String:
	var s := session.state
	var lines := PackedStringArray()
	lines.append("round=%d phase=%s outcome=%s" % [s.round, Phase.name_of(session.phase), Outcome.name_of(session.outcome)])
	lines.append("turn=" + ",".join(PackedStringArray(turn_order)))
	lines.append("left=" + ",".join(PackedStringArray(_sorted(left.keys()))))
	if shared_pool:
		lines.append("energy=%d" % session.energy)
	else:
		var parts := PackedStringArray()
		for p in _sorted(pools.keys()): parts.append("%s:%d" % [p, pools[p]])
		lines.append("pools=" + ",".join(parts))
	var placed := PackedStringArray()
	for t in _sorted(session.placed.keys()): placed.append("%s:%d" % [t, session.placed[t]])
	lines.append("placed=" + ",".join(placed))
	var waves := PackedStringArray()
	for w in session.waves: waves.append("%d:%d:%s" % [w.index, w.start_round, "1" if w.finished else "0"])
	lines.append("waves=" + ",".join(waves))
	lines.append("rng=%d" % (s.rng.state if "state" in s.rng else 0))
	for e in s.entities:
		if e.is_environment: continue
		var pos: String = "-" if e.position == null else "%d,%d" % [e.position.x, e.position.y]
		var shield := 0
		var sts := PackedStringArray()
		for st in e.statuses:
			shield += st.pool
			sts.append("%s:%d:%d:%d:%s" % [st.def.name if st.def != null else "?", st.stacks, st.turns_left, st.pool, "1" if st.active else "0"])
		var cds := []
		for a in e.cooldowns: cds.append("%s:%d" % [a.name if a != null else "?", e.cooldowns[a]])
		cds.sort()
		var res := PackedStringArray()
		for r in _sorted(e.resources.keys()): res.append("%s:%s" % [r, _num(e.resources[r])])
		lines.append("e%d %s life=%d team=%d pos=%s face=%d,%d hp=%s shield=%d step=%d res=%s st=%s cd=%s" % [
			e.id, e.def.name if e.def != null else e.name, e.life, e.base_team, pos, e.facing.x, e.facing.y,
			_num(e.hp) if e.has_hp else "-", shield, e.path_step, ",".join(res), ",".join(sts), ",".join(PackedStringArray(cds))])
	return "\n".join(lines)

## FNV-1a 64 of state_digest()'s UTF-8 bytes, as 16 lowercase hex digits.
func checksum() -> String:
	return fnv1a64(state_digest().to_utf8_buffer())

## FNV-1a 64 over bytes, as 16 hex digits. Computed on two 32-bit halves so no step overflows a signed int.
static func fnv1a64(bytes: PackedByteArray) -> String:
	var hi := 0xcbf29ce4
	var lo := 0x84222325
	for b in bytes:
		lo = lo ^ b
		# × 0x100000001b3 = × (0x100 << 32) + × 0x1b3
		var lo_full := lo * 0x1b3
		var new_hi := (hi * 0x1b3 + lo * 0x100 + (lo_full >> 32)) & 0xFFFFFFFF
		lo = lo_full & 0xFFFFFFFF
		hi = new_hi
	return "%08x%08x" % [hi, lo]

# ------------------------------------------------------------------ energy (CoopLevelSession calls these)

## Separate pools: books one energy change of the wrapped session. A player's command changes their own pool;
## outside commands (level phase) income gives each open pool its share and other gains (GiveEnergy) are split
## 1/N over the starting players (remainder to slot 0), a closed pool's share being lost.
func _book_energy(amount: int, why: String) -> void:
	if _actor != "":
		if pools.has(_actor):
			pools[_actor] += amount
			session._write_pool_energy(amount, pools[_actor], slot_of(_actor), why)
		_mirror_energy()
		return
	var shares := {}
	if why == "income":
		shares = income_share
	else:
		var parts := split(amount, slots.size())
		for i in slots.size(): shares[slots[i]] = parts[i]
	for p in slots:
		if not pools.has(p) or int(shares.get(p, 0)) == 0: continue
		pools[p] += shares[p]
		session._write_pool_energy(shares[p], pools[p], slot_of(p), why)
	_mirror_energy()

## Separate pools: the session's single `energy` mirrors the acting (or current) player's pool, so its own
## checks (can_place's cost, anything_to_do) read the right pool.
func _mirror_energy() -> void:
	if shared_pool: return
	var p := _actor if _actor != "" else current_player
	session.energy = pools.get(p, 0)

# ------------------------------------------------------------------ helpers

func _turn_error(player: String) -> String:
	if not slots.has(player): return "Not in the match"
	if left.has(player): return "Left the match"
	if session.is_over: return "The level is over"
	if session.phase == Phase.NotStarted: return "Not started"
	if session.phase != Phase.Player: return "Not the player phase"
	if current_player != player: return "Not your turn"
	return ""

func _no(reason: String) -> bool:
	last_reason = reason
	return false

static func _is_num(v) -> bool:
	return v is int or v is float

static func _num(v) -> String:
	return Num.to_str(float(v)) if v is float else str(v)

static func _sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort()
	return out
