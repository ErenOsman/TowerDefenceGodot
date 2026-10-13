class_name TurnForecast
extends RefCounted
## Casts played ahead on a copy of the state (for UIs: previews); the real state and its RNG are untouched. The
## numbers are calculated, not rolled (the resolver's preview mode): uncertain hits land, anything else left to
## chance (a crit, a chance reaction) does not happen, rand() gives its lowest value; stats, statuses, shields and
## certain reactions all apply.
## C# Of/Turn/Phase/Cast → of/turn/phase/cast.

## What a unit would do if its turn came now (the enemy turn preview): the turn played the way EnemyBrain does
## (TurnStarted, then each ability in order, aimed by its instinct). The units that act before it (before, in
## their order) take their turns on the copy first, so a unit ahead that walks on frees the road.
static func of(state: GameState, unit_id: int, before = null) -> Array:
	return turn(state, unit_id, before).steps.get(unit_id, [])

## The unit's coming turn as `of` plays it, with what that turn alone would do: the losses, the HP
## left and the kills compare the board just before its turn with the board after it.
static func turn(state: GameState, unit_id: int, before = null) -> PhaseForecast:
	var result := PhaseForecast.new()
	var copy: GameState = state.clone()
	var resolver := _preview(copy)

	if before != null:
		for id in before:
			var earlier: Entity = copy.get_entity(id)
			if earlier == null or not earlier.alive or id == unit_id: continue
			_play_turn(copy, resolver, earlier, null)
			if earlier.alive and earlier.life != LifeState.Removed: resolver.end_turn(earlier)

	var unit: Entity = copy.get_entity(unit_id)
	if unit == null or not unit.alive: return result
	var start: GameState = copy.clone()
	var steps := []
	_play_turn(copy, resolver, unit, steps)
	result.steps[unit_id] = steps
	_compare(start, copy, result)
	return result

## The whole enemy phase as things stand: every unit in the order given takes its turn on one copy of the state
## (each after the ones before it), recording what each casts; then what everyone would lose (HP and shield)
## and who would die. The real state and its RNG are untouched.
static func phase(state: GameState, order: Array) -> PhaseForecast:
	var result := PhaseForecast.new()
	var copy: GameState = state.clone()
	var resolver := _preview(copy)
	for id in order:
		var unit: Entity = copy.get_entity(id)
		if unit == null or not unit.alive: continue
		var steps := []
		_play_turn(copy, resolver, unit, steps)
		result.steps[id] = steps
		if unit.alive and unit.life != LifeState.Removed: resolver.end_turn(unit)
	_compare(state, copy, result)
	return result

## One cast played ahead on a copy of the state (for UIs: what the hovered or aimed ability would do): what its
## targets would lose or gain and who would die. Only the cast itself: everything that changes its numbers applies
## (stats, statuses, shields, replacements), but no reaction fires (a counter, an on-death burst), so previews stay
## readable as abilities grow (UI Design Rules, Board previews). reactions: true plays them too.
static func cast(state: GameState, caster_id: int, ability: AbilityDef, aim: Aim, reactions := false) -> PhaseForecast:
	var result := PhaseForecast.new()
	var copy: GameState = state.clone()
	var caster: Entity = copy.get_entity(caster_id)
	if caster == null or not caster.alive or ability == null or aim == null: return result
	result.steps[caster_id] = [ForecastStep.make(ability, aim, AimPreview.for_aim(copy, caster_id, ability, aim))]
	var resolver := _preview(copy)
	resolver.reactions = reactions
	resolver.cast(caster, ability, aim)
	_compare(state, copy, result)
	return result

## A resolver on the copy that calculates instead of rolling (EvalMode.PreviewMin).
static func _preview(copy: GameState) -> Resolver:
	var r := Resolver.new(copy)
	r.mode = EvalMode.PreviewMin
	return r

static func _compare(state: GameState, copy: GameState, result: PhaseForecast) -> void:
	for before in state.entities:
		if not before.alive: continue
		var after: Entity = copy.get_entity(before.id)
		var alive: bool = after != null and after.alive
		var lost: int = before.hp + before.shield - (after.hp + after.shield if alive else 0)
		if lost > 0: result.loss[before.id] = lost
		if not alive: result.killed[before.id] = true
		var hp: int = after.hp if alive else 0
		if hp != before.hp: result.hp[before.id] = hp

## A unit's turn on the copy, like EnemyBrain.TakeTurn; record (optional Array) gets every cast.
static func _play_turn(copy: GameState, resolver: Resolver, unit: Entity, record) -> void:
	resolver.start_turn(unit, false) # its cooldowns dropped at the player phase (LevelSession)
	if not unit.alive or not unit.can_act: return
	for ability in unit.abilities.duplicate():
		if not unit.alive: break
		if not Targeting.can_cast(copy, unit.id, ability): continue
		var aim := Instinct.choose(copy, unit, ability)
		if aim == null: continue
		if record != null: record.append(ForecastStep.make(ability, aim, AimPreview.for_aim(copy, unit.id, ability, aim)))
		resolver.cast(unit, ability, aim)
