class_name RuleSources
extends RefCounted
## Finds rules by walking GameState.rules_of; no rule is an event subscription.

## The receiver's reactions in definition order. Response effects come from the receiver,
## except: a status's reactions come from whoever applied it (or the Environment if that
## entity is gone), and a hazard's from the Environment (no kill credit by default).
## Returns an Array of Dictionaries {def: ReactionDef, effect_source: int, key: String, status: StatusInstance or null}
## (the C# named tuple; read them as r.def, r.effect_source, r.key, r.status).
static func reactions(s: GameState, receiver: Entity) -> Array:
	var out := []
	for r in s.rules_of(receiver):
		var src: int
		if receiver.is_environment or r.holder.kind == EntityKind.Hazard: src = 0
		elif r.status != null and not r.is_aura:
			var applier := s.get_entity(r.status.applied_by)
			src = applier.id if applier != null and applier.alive else 0
		else: src = receiver.id

		var list: Array = r.source.reactions
		for i in list.size():
			out.append({"def": list[i], "effect_source": src, "key": "%s:%d" % [r.key, i], "status": r.status})
	return out

## Array of ReplacementRule.
static func replacements(s: GameState, receiver: Entity) -> Array:
	var out := []
	for r in s.rules_of(receiver):
		for rule in r.source.replacements: out.append(rule)
	return out

## Whether a trigger matches an event for this owner. Environment-owned rules (GameRules)
## ignore the side and match the event for any entity.
static func matches(t: int, e: GameEvent, owner: Entity, s: GameState) -> bool:
	var env := owner.is_environment
	var is_source := env or e.source == owner.id
	var is_target := env or e.target == owner.id

	match t:
		Trigger.OnCast: return e.type == GameEventType.AbilityDeclared and is_source
		Trigger.OnAllyCast:
			return e.type == GameEventType.AbilityDeclared and e.source != owner.id and _is_ally(s, e.source, owner)
		Trigger.OnAttackStarted: return e.type == GameEventType.AttackStarted and is_source
		Trigger.OnTargeted:
			return e.type == GameEventType.AttackStarted and (env or (e.targets != null and e.targets.has(owner.id)))
		Trigger.OnHitDealt: return e.type == GameEventType.HitResolved and is_source and e.fact("Hit")
		Trigger.OnHitTaken: return e.type == GameEventType.HitResolved and is_target and e.fact("Hit")
		Trigger.OnAllyHitTaken:
			return e.type == GameEventType.HitResolved and e.fact("Hit") and e.target != owner.id and _is_ally(s, e.target, owner)
		Trigger.OnDodge: return e.type == GameEventType.HitResolved and is_target and not e.fact("Hit")
		Trigger.OnDamageDealt: return e.type == GameEventType.DamageDealt and is_source
		Trigger.OnDamageTaken: return e.type == GameEventType.DamageDealt and is_target
		Trigger.OnHealed: return e.type == GameEventType.Healed and is_target
		Trigger.OnStatusApplied: return e.type == GameEventType.StatusApplied and is_target
		Trigger.OnStatusRemoved: return e.type == GameEventType.StatusRemoved and is_target
		Trigger.OnMove: return e.type == GameEventType.EntityMoved and is_target
		Trigger.OnEnterTile: return e.type == GameEventType.EntityEnteredTile # any entity; the condition filters
		Trigger.OnCollision: return e.type == GameEventType.Collision and is_target
		Trigger.OnDeath: return e.type == GameEventType.EntityDied and is_target
		Trigger.OnKill: return e.type == GameEventType.EntityDied and not env and e.source == owner.id
		Trigger.OnTurnStart: return e.type == GameEventType.TurnStarted and is_target
		Trigger.OnTurnEnd: return e.type == GameEventType.TurnEnded and is_target
		Trigger.OnAttackEnded: return e.type == GameEventType.AttackEnded and is_source
		Trigger.OnAbilityEnded: return e.type == GameEventType.AbilityEnded and is_source
		Trigger.OnTileChanged: return e.type == GameEventType.TileChanged # any tile; the condition filters
		Trigger.OnAnyTurnStart: return e.type == GameEventType.TurnStarted
		Trigger.OnAnyTurnEnd: return e.type == GameEventType.TurnEnded
		Trigger.OnRoundStart: return e.type == GameEventType.RoundStarted
		Trigger.OnRoundEnd: return e.type == GameEventType.RoundEnded
		Trigger.OnSpawned: return e.type == GameEventType.EntitySpawned and is_target
		Trigger.OnResurrected: return e.type == GameEventType.EntityResurrected and is_target
		_: return false

static func _is_ally(s: GameState, other: int, owner: Entity) -> bool:
	var o := s.get_entity(other)
	return o != null and s.relation(owner, o) == Relation.Ally
