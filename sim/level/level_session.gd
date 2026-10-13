class_name LevelSession
extends RefCounted
## One play of a level (Game Overview — Design). Each round is a player phase (every tower's shared
## turn: place, sell and cast freely, then End round), an enemy phase (each enemy's own turn, in
## Initiative order) and a level phase (wave starts, spawns, LevelEvents, energy income, wave
## finishes). Won when every wave is finished; lost when any base reaches 0 HP.
## Engine-free: the presentation reads State and the event log, and calls the commands below.
##
## Port notes: C# `out string reason` → the method returns the bool and leaves the reason in
## `last_reason` ("" when allowed). A C# InvalidOperationException on an invalid command → push_error
## and return null/false. The constructor's ArgumentException (a tower ID twice in the hand) → `last_error`
## is set (check it after new()).

var level: LevelDef
var state: GameState
var resolver: Resolver

## The towers of the hand that came into this level (the first ones, up to its hand cap). Array of TowerDef.
var hand: Array = []

## Placed towers by tower ID (String → EntityId int). A sold or dead tower leaves this map and is back in the hand.
var placed: Dictionary = {}

var bases: Array[int] = []

## The level's starting allies (StartingSide.Ally): commanded like bases, taking their turn with the towers.
var allies: Array[int] = []

var waves: Array = []  # of WaveState
var messages: Array[String] = []

var energy: int = 0
var phase: int = Phase.NotStarted
var outcome: int = Outcome.Running

## Why the last can_place / can_sell / can_cast said no ("" when it said yes). The C# `out string reason`
## is also available as the optional trailing reason_out Array (reason_out[0] = String or null), like Targeting.
var last_reason: String = ""
## Set by the constructor when the C# would throw (a tower ID twice in the hand); "" otherwise.
var last_error: String = ""

var round: int:
	get: return state.round
var log: EventLog:
	get: return resolver.log
var is_over: bool:
	get: return outcome != Outcome.Running

func _init(p_level: LevelDef, rules: GameRules, p_hand: Array, p_seed: int) -> void:
	level = p_level
	state = GameState.new(rules, level.build_grid(), p_seed)
	resolver = Resolver.new(state)
	hand = p_hand.slice(0, maxi(0, level.hand_cap))
	var counts := {}
	for t in hand: counts[t.id] = counts.get(t.id, 0) + 1
	for t in hand:
		if counts[t.id] > 1:
			last_error = "Tower ID '%s' is in the hand %d times; every tower needs its own ID." % [t.id, counts[t.id]]
			break
	energy = level.start_energy
	for b in level.bases:
		var made: Entity = state.create(b.entity, Teams.Player, b.tile)
		made.facing = Directions.to_dir(CardinalDirection.Down) # bases face down the board, toward the camera, like placed towers
		bases.append(made.id)
	for u in level.starting_units: _place_starting_unit(u)
	for i in level.waves.size():
		var w := WaveState.new()
		w.def = level.waves[i]
		w.index = i
		waves.append(w)

# ------------------------------------------------------------------ queries

func tower(tower_id: String) -> TowerDef:
	for t in hand:
		if t.id == tower_id: return t
	return null

func placed_tower(tower_id: String) -> Entity:
	return state.get_entity(placed[tower_id]) if placed.has(tower_id) else null

## The tower ID of a placed tower entity, or null.
func tower_id_of(e: Entity) -> Variant:
	for k in placed:
		if placed[k] == e.id: return k
	return null

var enemies: Array:
	get:
		var out := []
		for e in state.entities:
			if e.alive and e.kind == EntityKind.Unit and e.base_team == Teams.Enemy: out.append(e)
		return out

## Placed towers in EntityId order.
var towers: Array:
	get:
		var ids: Array = placed.values()
		ids.sort()
		var out := []
		for id in ids:
			var e: Entity = state.get_entity(id)
			if e != null and e.alive: out.append(e)
		return out

## The units the player commands: the placed towers, then the living bases (bases take their turn with the towers and cast like them).
var player_units: Array:
	get:
		var out := towers
		for id in bases + allies:
			var e: Entity = state.get_entity(id)
			if e != null and e.alive and not _is_tower(e): out.append(e)
		return out

## The order the enemies take their turns in: highest Initiative first, then EntityId (fixed when the enemy phase starts).
func enemy_order() -> Array:
	var list := enemies
	var init := {}
	for e in list: init[e.id] = state.final_stat(e, "Initiative")
	list.sort_custom(func(a, b):
		if init[a.id] != init[b.id]: return init[a.id] > init[b.id]
		return a.id < b.id)
	return list

## The coming enemy phase played ahead as things stand (enemy turns only, in their order): casts, losses, kills.
func forecast_enemy_phase() -> PhaseForecast:
	var ids: Array[int] = []
	for e in enemy_order(): ids.append(e.id)
	return TurnForecast.phase(state, ids)

## A unit the player commands: a placed tower, a base or a starting ally.
func is_commanded(e: Entity) -> bool:
	return e != null and (_is_tower(e) or bases.has(e.id) or allies.has(e.id))

func _is_tower(e: Entity) -> bool:
	return placed.values().has(e.id)

# ------------------------------------------------------------------ flow

## Starts round 1 with the player phase.
func start() -> void:
	if phase != Phase.NotStarted:
		push_error("The level has already started.")
		return
	_begin_round()

## Ends the player phase, runs the enemy phase and the level phase, then starts the next round.
func end_round() -> void:
	if not _require_player_phase(): return

	var scope = log.begin_action(ActionKind.TowersTurnEnd, -1)
	for t in player_units:
		resolver.end_turn(t)   # tower status durations drop at End round
		if after_command(): _close(scope); return
	_close(scope)

	# ---- enemy phase: order fixed at its start, so enemies spawned now act next round
	scope = log.begin_action(ActionKind.Phase, -1, Phase.name_of(Phase.Enemy))
	_set_phase(Phase.Enemy)
	_close(scope)
	var order := enemy_order()
	for enemy in order:
		if not enemy.alive: continue
		scope = log.begin_action(ActionKind.EnemyTurn, enemy.id, enemy.name)
		resolver.start_turn(enemy, false) # their cooldowns dropped with the towers'
		if after_command(): _close(scope); return
		if enemy.alive and enemy.can_act: EnemyBrain.take_turn(self, enemy)
		if is_over: _close(scope); return
		if enemy.life == LifeState.Removed: _close(scope); continue
		resolver.end_turn(enemy)
		if after_command(): _close(scope); return
		_close(scope)

	# ---- level phase
	scope = log.begin_action(ActionKind.Phase, -1, Phase.name_of(Phase.Level))
	_set_phase(Phase.Level)
	_close(scope)
	_run_level_phase()
	if is_over: return
	scope = log.begin_action(ActionKind.RoundEnd, -1)
	resolver.end_round()           # round-based status durations
	if after_command(): _close(scope); return
	_close(scope)
	_begin_round()

func _begin_round() -> void:
	var scope = log.begin_action(ActionKind.Phase, -1, Phase.name_of(Phase.Player))
	resolver.start_round()
	_set_phase(Phase.Player)
	_close(scope)
	scope = log.begin_action(ActionKind.TowersTurnStart, -1) # one action: Skip finishes every tower's turn start
	for t in player_units:
		resolver.start_turn(t) # ticks, cooldowns drop by one
		if after_command(): _close(scope); return
	# enemies' cooldowns drop now too, so the player sees what they can do in their coming turn
	for enemy in enemies:
		resolver.tick_cooldowns(enemy)
		if after_command(): _close(scope); return
	_close(scope)

# ------------------------------------------------------------------ player commands

## Whether the tower can be placed there; the reason is left in last_reason.
func can_place(tower_id: String, tile: Vector2i, reason_out = null) -> bool:
	var ok := _can_place(tower_id, tile)
	if reason_out is Array:
		reason_out.resize(1)
		reason_out[0] = null if ok else last_reason
	return ok

func _can_place(tower_id: String, tile: Vector2i) -> bool:
	last_reason = _player_phase_error()
	if last_reason != "": return false
	var t := tower(tower_id)
	if t == null: return _no("Not in the hand")
	if t.entity == null: return _no("Its type has no entity")
	if placed.has(tower_id): return _no("Already placed")
	if energy < t.cost: return _no("Not enough energy")
	if state.grid.blocks_movement(tile): return _no("Not walkable")
	if not state.grid.can_build(tile): return _no("Not a buildable tile")
	if t.entity.footing == Footing.OffPath and state.grid.is_path(tile): return _no("On a path")
	if not state.is_free(tile): return _no("Occupied")
	return true

## Places a hand tower (C# throws when it cannot: push_error and null here).
func place(tower_id: String, tile: Vector2i) -> Entity:
	if not can_place(tower_id, tile):
		push_error("Cannot place %s: %s" % [tower_id, last_reason])
		return null
	var t := tower(tower_id)
	var scope = log.begin_action(ActionKind.Place, -1, tower_id)
	_add_energy(-t.cost, "place " + t.name)

	var before: int = state.entities.size()
	# a placed tower faces down the board, toward the camera (it faced up, its back to the player)
	var fx := SpawnEffect.new()
	fx.def = t.entity
	fx.tile = tile
	fx.team = Teams.Player
	fx.summon = false
	fx.exact_tile = true
	fx.owner = 0
	fx.source = 0
	fx.facing = Directions.to_dir(CardinalDirection.Down)
	resolver.run(fx)
	var made: Entity = state.entities[before] if state.entities.size() > before else null
	if made != null: placed[tower_id] = made.id
	after_command()
	_close(scope)
	return made

## Energy refunded for selling: cost × 0.5 × Hp / MaxHp, rounded down.
func sell_value(tower_id: String) -> int:
	var e := placed_tower(tower_id)
	var t := tower(tower_id)
	if e == null or t == null or e.max_hp <= 0: return 0
	return (t.cost * e.hp) / (2 * e.max_hp)

func can_sell(tower_id: String, reason_out = null) -> bool:
	var ok := _can_sell(tower_id)
	if reason_out is Array:
		reason_out.resize(1)
		reason_out[0] = null if ok else last_reason
	return ok

func _can_sell(tower_id: String) -> bool:
	last_reason = _player_phase_error()
	if last_reason == "" and placed_tower(tower_id) == null: last_reason = "Not placed"
	return last_reason == ""

## Sells a placed tower (C# throws when it cannot: push_error and false here).
func sell(tower_id: String) -> bool:
	if not can_sell(tower_id):
		push_error("Cannot sell %s: %s" % [tower_id, last_reason])
		return false
	var refund := sell_value(tower_id)
	var e := placed_tower(tower_id)
	var scope = log.begin_action(ActionKind.Sell, e.id, tower_id)
	placed.erase(tower_id)
	var fx := RemoveEffect.new()
	fx.target_id = e.id
	fx.source = 0
	fx.reason = "sold"
	resolver.run(fx)
	_add_energy(refund, "sell " + tower(tower_id).name)
	after_command()
	_close(scope)
	return true

## Whether the player can still do something this player phase besides walking: cast a non-movement ability
## with a unit they command, or place a hand tower they can afford. False outside the player phase. The HUD
## uses it to make End turn ask for attention.
func anything_to_do() -> bool:
	if phase != Phase.Player or is_over: return false
	var reason := last_reason
	for unit in player_units:
		for ability in unit.abilities:
			if not ability.targeting.is_movement and can_cast(unit, ability):
				last_reason = reason
				return true
	last_reason = reason
	for t in hand:
		if not placed.has(t.id) and energy >= t.cost: return true
	return false

## Whether a commanded unit can cast the ability now; the reason is left in last_reason.
func can_cast(unit: Entity, ability: AbilityDef, reason_out = null) -> bool:
	var ok := _can_cast(unit, ability)
	if reason_out is Array:
		reason_out.resize(1)
		reason_out[0] = null if ok else last_reason
	return ok

func _can_cast(unit: Entity, ability: AbilityDef) -> bool:
	last_reason = _player_phase_error()
	if last_reason != "": return false
	if unit == null or not is_commanded(unit): return _no("Not a placed tower or a base")
	if not unit.abilities.has(ability): return _no("Not its ability")
	if Targeting.can_cast(state, unit.id, ability): return true
	return _no(Targeting.last_reason)

## Casts a tower's ability. The aim is validated; a movement aim may carry a chosen route (RouteBuilder).
## (C# throws when it cannot: push_error and false here.)
func cast(unit: Entity, ability: AbilityDef, aim: Aim) -> bool:
	if not can_cast(unit, ability):
		push_error("Cannot cast %s: %s" % [ability.name, last_reason])
		return false
	if not Targeting.is_valid_aim(state, unit.id, ability, aim):
		last_reason = Targeting.last_reason
		push_error("Cannot cast %s there: %s" % [ability.name, last_reason])
		return false
	var scope = log.begin_action(ActionKind.Cast, unit.id, ability.name)
	resolver.cast(unit, ability, aim)
	after_command()
	_close(scope)
	return true

# ------------------------------------------------------------------ level phase

func _run_level_phase() -> void:
	# wave starts (a wave that finished in an earlier level phase can start the next one)
	for w in waves:
		if w.started: continue
		var start_now: bool
		if w.def.start == WaveStart.AtRound:
			start_now = round >= w.def.start_round
		else:
			start_now = w.def.after_wave >= 0 and w.def.after_wave < waves.size() and waves[w.def.after_wave].finished
		if not start_now: continue
		w.start_round = round
		var scope = log.begin_action(ActionKind.Wave, -1, _wave_name(w))
		_write_event(GameEventType.WaveStarted, _wave_name(w))
		_close(scope)

	# spawns and LevelEvents of this round of every running wave
	var running := []
	for w in waves:
		if w.started and not w.finished: running.append(w)
	for w in running:
		var wr: int = w.wave_round(round)
		for sp in w.def.spawns:
			if sp.round != wr: continue
			spawn_enemy(sp.enemy, sp.path, null, w.index, sp.facing)
			if is_over: return
		for ev in w.def.events:
			if ev.round != wr: continue
			var scope = log.begin_action(ActionKind.LevelEvent, -1, LevelEventKind.name_of(ev.kind))
			_run_level_event(ev, w)
			_close(scope)
			if is_over: return

	if level.energy_per_round != 0:
		var scope = log.begin_action(ActionKind.Income, -1)
		_add_energy(level.energy_per_round, "income")
		_close(scope)

	_finish_cleared_waves()

func _run_level_event(ev: LevelEventDef, wave: WaveState) -> void:
	match ev.kind:
		LevelEventKind.SpawnEnemies:
			for i in ev.count:
				var path_id: int = ev.path if ev.path >= 0 else _random_int(state.grid.paths.size())
				var p: PathDef = state.grid.path(path_id)
				if p == null or p.tiles.size() == 0: continue
				var tile: Vector2i = p.tiles[_random_int(p.tiles.size())] if ev.random_tiles else p.tiles[0]
				spawn_enemy(ev.enemy, path_id, tile, wave.index, ev.facing)
				if is_over: return
		LevelEventKind.GiveEnergy:
			_add_energy(ev.energy, "event")
		LevelEventKind.ShowMessage:
			messages.append(ev.message)
			_write_event(GameEventType.LevelMessage, ev.message)
		LevelEventKind.ChangeTerrain:
			if ev.terrain == null: return
			var fx := ChangeTerrainEffect.new()
			fx.tiles.assign(ev.tiles)
			fx.terrain = ev.terrain
			fx.build = ev.build
			fx.source = 0
			resolver.run(fx)
			after_command() # a fall may finish a wave or the level

## Spawns an enemy on its path (its first tile by default, tile = null); a taken tile uses the nearest free
## tile of that path. It starts facing along its path, or in the given direction.
func spawn_enemy(enemy: EntityDef, path_id: int, tile: Variant, wave: int, facing: int = SpawnFacing.AlongPath) -> void:
	var p: PathDef = state.grid.path(path_id)
	if enemy == null or p == null or p.tiles.size() == 0: return
	var scope = log.begin_action(ActionKind.Spawn, -1, enemy.name)
	var fx := SpawnEffect.new()
	fx.def = enemy
	fx.tile = tile if tile != null else p.tiles[0]
	fx.team = Teams.Enemy
	fx.summon = false
	fx.path_id = path_id
	fx.wave = wave
	fx.owner = 0
	fx.source = 0
	fx.facing = _to_dir(facing)
	resolver.run(fx)
	after_command()
	_close(scope)

# ------------------------------------------------------------------ helpers

## After every command: dead towers go back to the hand (their corpse is removed), and any base
## at 0 HP loses the level. Returns true when the level is over. (C# internal.)
func after_command() -> bool:
	for k in placed.keys():
		var e: Entity = state.get_entity(placed[k])
		if e != null and e.alive: continue
		placed.erase(k)
		if e != null and e.life == LifeState.Dead:
			var fx := RemoveEffect.new()
			fx.target_id = e.id
			fx.source = 0
			fx.reason = "back to the hand"
			resolver.run(fx)
	if not is_over:
		for id in bases:
			if not state.get_entity(id).alive:
				_end(Outcome.Lost)
				break
	# the last enemy falling wins at once (outside the level phase, which checks at its end)
	if not is_over and phase != Phase.Level and phase != Phase.NotStarted: _finish_cleared_waves()
	return is_over

## Finishes every wave whose schedule has all happened and whose enemies are all gone, and wins the
## level when every wave is finished. Runs at the end of the level phase and after every command,
## so killing the last enemy wins at once instead of at the next End round.
func _finish_cleared_waves() -> void:
	for w in waves:
		if not w.started or w.finished or _spawned_rounds(w) < w.def.last_scheduled_round: continue
		var alive := false
		for e in state.entities:
			if e.wave == w.index and e.alive:
				alive = true
				break
		if alive: continue
		w.finished = true
		var scope = log.begin_action(ActionKind.Wave, -1, _wave_name(w))
		_write_event(GameEventType.WaveFinished, _wave_name(w))
		_close(scope)
	if waves.size() > 0 and waves.all(func(w): return w.finished): _end(Outcome.Won)

## How many of a started wave's rounds have had their spawns and events: in the level phase this round's too.
func _spawned_rounds(w: WaveState) -> int:
	return w.wave_round(round) if phase == Phase.Level else round - w.start_round

func _end(o: int) -> void:
	outcome = o
	phase = Phase.Over
	var scope = log.begin_action(ActionKind.LevelEnd, -1, Outcome.name_of(o)) # joins the action that ended it, if any
	_write_event(GameEventType.LevelWon if o == Outcome.Won else GameEventType.LevelLost)
	_close(scope)

func _set_phase(p: int) -> void:
	phase = p
	var e := GameEvent.new()
	e.type = GameEventType.PhaseStarted
	e.detail = Phase.name_of(p)
	e.facts["Round"] = float(round)
	log.write(e)

func _add_energy(amount: int, why: String) -> void:
	energy += amount
	var e := GameEvent.new()
	e.type = GameEventType.EnergyChanged
	e.detail = why
	e.facts["Amount"] = float(amount)
	e.facts["Energy"] = float(energy)
	log.write(e)

func _player_phase_error() -> String:
	if is_over: return "The level is over"
	if phase != Phase.Player: return "Not the player phase"
	return ""

func _require_player_phase() -> bool:
	var error := _player_phase_error()
	if error != "":
		push_error(error)
		return false
	return true

func _no(reason: String) -> bool:
	last_reason = reason
	return false

func _wave_name(w: WaveState) -> String:
	return w.def.name if w.def.name != "" else "Wave " + str(w.index + 1)

static func _to_dir(f: int) -> Vector2i:
	match f:
		SpawnFacing.Up: return Directions.to_dir(CardinalDirection.Up)
		SpawnFacing.Down: return Directions.to_dir(CardinalDirection.Down)
		SpawnFacing.Left: return Directions.to_dir(CardinalDirection.Left)
		SpawnFacing.Right: return Directions.to_dir(CardinalDirection.Right)
	return Dirs.NONE # AlongPath: SpawnEffect reads the path

## Puts a starting unit on its tile: an ally on the player's team (commanded like a base), a neutral
## obstacle, or an enemy on its road (walking it, part of the first wave so the level is not won while it lives).
func _place_starting_unit(u: StartingUnitDef) -> void:
	if u == null or u.entity == null or not state.grid.in_bounds(u.tile) or state.grid.blocks_movement(u.tile) \
			or (u.entity.is_blocking and not state.is_free(u.tile)):
		return
	var team: int = Teams.Player if u.side == StartingSide.Ally else (Teams.Enemy if u.side == StartingSide.Enemy else Teams.Neutral)
	var e: Entity = state.create(u.entity, team, u.tile)
	var facing := _to_dir(u.facing)
	if u.side == StartingSide.Enemy:
		if u.path >= 0:
			e.path_id = u.path
		else:
			e.path_id = -1
			for i in state.grid.paths.size():
				if state.grid.paths[i].contains(u.tile):
					e.path_id = i
					break
		var p: PathDef = state.grid.path(e.path_id)
		e.path_step = p.index_of(u.tile) if p != null else -1
		e.wave = 0 if level.waves.size() > 0 else -1
		if Dirs.is_none(facing):
			facing = p.direction_at_step(e.path_step) if p != null else Dirs.NONE
	if not Dirs.is_none(facing): e.facing = facing
	if u.side == StartingSide.Ally: allies.append(e.id)

func _random_int(n: int) -> int:
	return 0 if n <= 0 else state.rng.next_uint() % n

func _write_event(type: int, detail = null) -> void:
	var e := GameEvent.new()
	e.type = type
	e.detail = detail
	log.write(e)

## Closes an action opened with log.begin_action (the C# `using` scope): the port's scope object is
## disposed when it has dispose(), else the log's end_action() is called.
func _close(scope) -> void:
	if scope is Object and scope != null and scope.has_method("dispose"):
		scope.dispose()
	elif log.has_method("end_action"):
		log.end_action()
