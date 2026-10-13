class_name RemoveStatusEffect
extends Effect
## By name: every instance of that status (Permanent included), or with `stacks` that many
## stacks, newest instance first (an instance left with none is removed). Taking off only some stacks
## writes StatusRemoved too, with Facts Stacks (what is left) and StacksRemoved. By tag (a cleanse):
## instances with the tag, newest first, skipping Permanent ones; limit > 0 removes at most that many.

var status_name: String = ""
var tag: String = ""
var limit: int = 0

## By name: how many stacks to remove (floored); empty removes every stack.
var stacks: Formula = Formula.new()

func _kind() -> int: return EffectKind.RemoveStatus
func _name() -> String: return "RemoveStatus " + (status_name if tag == null or tag == "" else "#" + tag)

func apply(ctx: ResolveContext) -> void:
	var target: Entity = ctx.state.get_entity(target_id)
	var no_tag: bool = tag == null or tag == ""
	if no_tag and not stacks.is_empty:
		_remove_stacks(ctx, target)
		return
	var chosen: Array = []
	if no_tag:
		for x in target.statuses:
			if x.def.name == status_name: chosen.append(x)
	else:
		for i in range(target.statuses.size() - 1, -1, -1):
			var x: StatusInstance = target.statuses[i]
			if x.has_tag(tag) and not x.has_tag(Tags.Permanent): chosen.append(x)
		if limit > 0 and chosen.size() > limit: chosen.resize(limit)
	for st in chosen: ctx.remove_status(self, target, st)

func _remove_stacks(ctx: ResolveContext, target: Entity) -> void:
	var s: GameState = ctx.state
	var ectx: EvalContext = ctx.eval(self, self_of(s), s.get_entity(source), target, ctx.vars(self))
	var left: int = maxi(0, Effect.floor_int(stacks.evaluate(s.vocab, ectx)))
	var newest_first: Array = []
	for i in range(target.statuses.size() - 1, -1, -1):
		if target.statuses[i].def.name == status_name: newest_first.append(target.statuses[i])
	for st in newest_first:
		if left <= 0: break
		if st.stacks <= left:
			left -= st.stacks
			ctx.remove_status(self, target, st)
			continue
		st.stacks -= left
		var e := GameEvent.new()
		e.type = GameEventType.StatusRemoved
		e.source = source
		e.target = target_id
		e.detail = st.def.name
		e.tags = tags.duplicate()
		for t in st.all_tags: e.tags[t] = true
		e.facts["Stacks"] = float(target.stacks(status_name))
		e.facts["StacksRemoved"] = float(left)
		ctx.write(self, e)
		left = 0
