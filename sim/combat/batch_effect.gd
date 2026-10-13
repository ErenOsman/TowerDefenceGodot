class_name BatchEffect
extends Effect
## Effects that happen at the same moment: one chain per target in canonical order. The resolver
## runs it as a single queue item, so it has one checkpoint and no reaction or death mid-batch.

## Array of EntityId (int).
var targets: Array = []
## Array of Chain.
var chains: Array = []
## Array of PushEffect.
var forced_moves: Array = []

func _kind() -> int: return EffectKind.Other
func is_valid(_s: GameState) -> bool: return true

func apply(_ctx: ResolveContext) -> void:
	push_error("Batches are run by the resolver.")

## Builds the chains against current state, when the batch reaches the front of the queue.
func build_chains(s: GameState) -> void:
	chains.clear()
	var step: AttackStep = attack.step
	for id in targets:
		var target: Entity = s.get_entity(id)
		var c := Chain.new()
		c.target = id
		var sc: StepContext = attack.step_context.with_target(target)
		if step.can_miss or step.can_crit:
			var roll := RollHitEffect.new()
			roll.target_id = id
			c.effects.append(sc.init(roll))
		c.effects.append_array(Step.expand_list(step.on_hit, sc))
		for e in c.effects: e.chain = c
		chains.append(c)
		attack.hit_units[id] = true
