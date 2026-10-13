class_name EnemyBrain
extends RefCounted
## An enemy's turn: it tries its abilities in their own order, casting each one it can, where
## each ability's instinct says (Instinct — Design). By default movement goes farthest, an area
## attack aims for the most hits, a target filter takes the nearest valid target (ties by
## EntityId), and anything else its first aim.

static func take_turn(session: LevelSession, enemy: Entity) -> void:
	var s: GameState = session.state
	for ability in enemy.abilities.duplicate():
		if not enemy.alive or session.is_over: return
		if not Targeting.can_cast(s, enemy.id, ability): continue
		var aim = choose_aim(s, enemy, ability)
		if aim == null: continue
		session.resolver.cast(enemy, ability, aim)
		if session.after_command(): return

## The aim the enemy takes with this ability (its instinct), or null when it has none.
static func choose_aim(s: GameState, enemy: Entity, ability: AbilityDef) -> Aim:
	return Instinct.choose(s, enemy, ability)
