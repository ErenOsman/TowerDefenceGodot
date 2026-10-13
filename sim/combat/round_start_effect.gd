class_name RoundStartEffect
extends Effect
## Sorts living units by Initiative (highest first, ties by EntityId) and writes RoundStarted.

func _kind() -> int: return EffectKind.Other

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	s.round += 1
	var units: Array = []
	for e in s.entities:
		if e.alive and e.kind == EntityKind.Unit and e.on_board:
			units.append([s.final_stat(e, "Initiative"), e.id])
	units.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var order: Array = []
	for u in units: order.append(u[1])
	s.turn_order = order
	s.turn_index = -1
	s.current_turn = -1

	var started := GameEvent.new()
	started.type = GameEventType.RoundStarted
	started.targets = s.turn_order.duplicate()
	started.facts["Round"] = float(s.round)
	ctx.write(self, started)
