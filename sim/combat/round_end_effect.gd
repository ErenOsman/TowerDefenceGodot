class_name RoundEndEffect
extends Effect
## Writes RoundEnded, then counts down every round-based status; a status at 0 is removed.

func _kind() -> int: return EffectKind.Other

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var ended := GameEvent.new()
	ended.type = GameEventType.RoundEnded
	ended.facts["Round"] = float(s.round)
	ctx.write(self, ended)
	s.current_turn = -1

	for e in s.entities.duplicate():
		if e.alive: ctx.count_down(self, e, DurationUnit.Rounds)
