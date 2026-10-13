class_name ApplyStatusEffect
extends Effect

var status: StatusDef
var stacks: Formula = Formula.new("1")
## How long it lasts (a formula); empty uses the status's own duration. -1 is permanent.
var duration: Formula = Formula.new()

## Tags for this application only (Hidden, Permanent…).
var add_tags: Array = []

func _kind() -> int: return EffectKind.ApplyStatus
func _name() -> String: return "ApplyStatus " + (status.name if status != null else "")

func apply(ctx: ResolveContext) -> void:
	var s: GameState = ctx.state
	var src: Entity = s.get_entity(source)
	var target: Entity = s.get_entity(target_id)
	var ectx: EvalContext = ctx.eval(self, self_of(s), src, target, ctx.vars(self))
	var n: int = maxi(0, Effect.floor_int(stacks.evaluate(s.vocab, ectx)))
	if n == 0: return
	var turns: int = maxi(-1, Effect.floor_int(duration.evaluate(s.vocab, ectx))) if not duration.is_empty else status.duration
	# the pool formula may read Stacks: the stacks this application gives (Shield: shieldPool "Stacks", one point per stack)
	var pool_vars: Dictionary = ctx.vars(self).duplicate()
	pool_vars["Stacks"] = float(n)
	var pool: int = 0 if status.shield_pool.is_empty else Effect.floor_int(status.shield_pool.evaluate(s.vocab, ctx.eval(self, self_of(s), src, target, pool_vars)), Round.FloorMin0)
	var team_before: int = s.effective_team(target)
	var add: Array = add_tags if add_tags != null else []

	var existing: StatusInstance = null
	for x in target.statuses:
		if x.def == status and (status.stacking != Stacking.PerSource or x.applied_by == source):
			existing = x
			break
	if existing != null and status.stacking != Stacking.Replace and status.stacking != Stacking.Independent:
		existing.extra_tags = ApplyStatusEffect._merge_tags(existing.extra_tags, add)

	var make_new := false
	match status.stacking:
		Stacking.Stack, Stacking.PerSource:
			if existing != null:
				existing.stacks = mini(status.max_stacks, existing.stacks + n)
				existing.turns_left = turns
				existing.applied_by = source
				existing.pool += pool
			else: make_new = true
		Stacking.Refresh:
			if existing != null:
				existing.turns_left = turns
				existing.applied_by = source
				existing.pool = maxi(existing.pool, pool)
			else: make_new = true
		Stacking.Replace:
			if existing != null:
				target.statuses.erase(existing)
				existing = null
			make_new = true
		_:
			make_new = true
	if make_new:
		existing = StatusInstance.new()
		existing.def = status
		existing.stacks = mini(status.max_stacks, n)
		existing.turns_left = turns
		existing.applied_by = source
		existing.pool = pool
		existing.override_team = s.effective_team(src) if status.team_override == TeamOverride.Applier and src != null else status.fixed_team
		var distinct: Array = []
		for t in add:
			if not distinct.has(t): distinct.append(t)
		existing.extra_tags = distinct
		var pctx := EvalContext.new()
		pctx.self_ = target
		pctx.rng = s.rng
		existing.active = status.passive_condition.evaluate(s.vocab, pctx)
		target.statuses.append(existing)

	if status.stacks_are_shield: existing.stacks = existing.pool # a Shield's stacks are its points (not capped by maxStacks)

	var e := GameEvent.new()
	e.type = GameEventType.StatusApplied
	e.source = source
	e.target = target_id
	e.detail = status.name
	e.tags = tags.duplicate()
	for t in existing.all_tags: e.tags[t] = true
	e.facts["Stacks"] = float(target.stacks(status.name))
	ctx.write(self, e)
	ctx.check_team(self, target, team_before)

## Tags of a merged application: the union, except Hidden, which stays only if both were hidden —
## once a status has been shown, a hidden application does not make it disappear.
static func _merge_tags(had: Array, added: Array) -> Array:
	var hidden: bool = had.has(Tags.Hidden) and added.has(Tags.Hidden)
	var out: Array = []
	for t in had + added:
		if t != Tags.Hidden and not out.has(t): out.append(t)
	if hidden: out.append(Tags.Hidden)
	return out
