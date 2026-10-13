class_name CastAbilityEffect
extends Effect

var def: AbilityDef
## EntityId (int).
var caster: int = -1
var aim: Aim

func _kind() -> int: return EffectKind.CastAbility
func _name() -> String: return "CastAbility " + (def.name if def != null else "")

func is_valid(s: GameState) -> bool:
	return Targeting.can_cast(s, caster, def)

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var c: Entity = s.get_entity(caster)
	var instance := AbilityInstance.new()
	instance.id = s.next_ability_instance_id()
	instance.def = def
	instance.caster = caster
	instance.aim = aim
	instance.tags = Tags.union(tags, def.tags)
	ability = instance
	s.open_abilities.append(instance)
	if def.cooldown_until_reset: c.cooldowns[def] = Entity.HeldCooldown # waits for a Reset Cooldown step
	elif def.cooldown > 0: c.cooldowns[def] = def.cooldown # player cast or reaction cast alike

	for cost in def.costs:
		var have: int = c.resource(cost.resource)
		c.resources[cost.resource] = have - cost.amount
		var paid := GameEvent.new()
		paid.type = GameEventType.ResourceChanged
		paid.source = caster
		paid.target = caster
		paid.detail = cost.resource
		paid.facts["Amount"] = float(-cost.amount)
		ctx.write(self, paid)

	if aim.tile != c.pos: ctx.face(self, c, Dirs.cardinal_between(c.pos, aim.tile))

	var declared_e := GameEvent.new()
	declared_e.type = GameEventType.AbilityDeclared
	declared_e.source = caster
	declared_e.detail = def.name
	declared_e.tags = instance.tags.duplicate()
	var declared: GameEvent = ctx.write(self, declared_e)

	var sc := StepContext.new()
	sc.state = s
	sc.ability = instance
	sc.self_ = c
	sc.effect_source = caster
	if def.targets_dead:
		var corpses: Array = s.corpses_at(aim.tile)
		sc.target = corpses[0] if not corpses.is_empty() else null
	else:
		sc.target = s.entity_at(aim.tile)
	sc.aim = aim
	sc.tags = instance.tags.duplicate()
	sc.cause = declared.id
	sc.depth = depth + 1
	ctx.push_all(Step.expand_list(def.steps, sc))
	var end := EndAbilityEffect.new()
	end.instance = instance
	end.caster = caster
	ctx.push(sc.init(end))
