class_name EnemyAbilityPreview
extends RefCounted
## One enemy ability of its coming turn, alone (the HUD's enemy card: an ability row hovered; user, 2026-10-14).
## The turn is played on a copy of the state the way TurnForecast.turn plays it (the units ahead first, then this
## unit's abilities in order, each aimed by its instinct), so the hovered ability is seen where it would really be
## cast (after the walk before it); but the result keeps ONLY that ability: its step, and what that cast alone does
## (losses, HP left, kills). A movement ability never shows numbers: hovering "Path Walk" previews the route and the
## stop tile only, never the Spit / Ram that follows it. The real state and its RNG are untouched.
##
## Game-layer helper (no Unity counterpart in the sim port): built on TurnForecast's preview resolver.

## The hovered ability's part of the unit's coming turn: steps[unit_id] = [that step] (empty when the ability would
## not be cast this turn), loss / hp / killed from that cast alone (empty for a movement ability).
static func only(state: GameState, unit_id: int, ability: AbilityDef, before = null) -> PhaseForecast:
	var result := PhaseForecast.new()
	if state == null or ability == null: return result
	var copy: GameState = state.clone()
	var resolver := TurnForecast._preview(copy)
	if before != null:
		for id in before:
			var earlier: Entity = copy.get_entity(id)
			if earlier == null or not earlier.alive or id == unit_id: continue
			_play(copy, resolver, earlier, null)
			if earlier.alive and earlier.life != LifeState.Removed: resolver.end_turn(earlier)
	var unit: Entity = copy.get_entity(unit_id)
	if unit == null or not unit.alive: return result
	_play(copy, resolver, unit, ability, result)
	return result

## The unit's turn on the copy (as TurnForecast._play_turn); when `stop_at` comes up, that cast alone is recorded
## into `result` and the turn ends there.
static func _play(copy: GameState, resolver: Resolver, unit: Entity, stop_at: AbilityDef, result: PhaseForecast = null) -> void:
	resolver.start_turn(unit, false)
	if not unit.alive or not unit.can_act: return
	for a in unit.abilities.duplicate():
		if not unit.alive: return
		if not Targeting.can_cast(copy, unit.id, a): continue
		var aim := Instinct.choose(copy, unit, a)
		if aim == null: continue
		if a == stop_at and result != null:
			result.steps[unit.id] = [ForecastStep.make(a, aim, AimPreview.for_aim(copy, unit.id, a, aim))]
			if a.targeting.is_movement: return # the walk: route and stop tile, no numbers
			var start: GameState = copy.clone()
			resolver.cast(unit, a, aim)
			TurnForecast._compare(start, copy, result)
			return
		resolver.cast(unit, a, aim)

## Where the unit stands when it casts the hovered ability: after the walks before it in its turn (the attack line
## starts there). `steps` is the full turn (TurnForecast.of).
static func cast_from(start: Vector2i, steps: Array, ability: AbilityDef) -> Vector2i:
	var at := start
	for st in steps:
		if st.ability == ability: return at
		if st.is_movement: at = st.aim.tile
	return at
