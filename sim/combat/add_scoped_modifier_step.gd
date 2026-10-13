class_name AddScopedModifierStep
extends Step
## Adds a modifier for the rest of the triggering ability (e.g. +10 Str for this attack).

var modifier: Modifier
var on: int = StepTarget.Self

func expand(c: StepContext) -> Array:
	var t: Entity = c.resolve(on)
	var scope: AbilityInstance = c.event.ability if c.event != null and c.event.ability != null else c.ability
	if t == null or scope == null: return []
	var e := AddScopedModifierEffect.new()
	e.target_id = t.id
	e.modifier = modifier
	e.scope = scope
	return [c.init(e)]
