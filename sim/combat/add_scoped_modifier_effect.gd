class_name AddScopedModifierEffect
extends Effect

var modifier: Modifier
var scope: AbilityInstance

func _kind() -> int: return EffectKind.Other

func apply(_ctx: ResolveContext) -> void:
	var sm := ScopedModifier.new()
	sm.owner = target_id
	sm.modifier = modifier
	scope.scoped.append(sm)
