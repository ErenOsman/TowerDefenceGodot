class_name CombatVocabulary
extends RefCounted
## The stats, variables and queries combat registers into the formula core (Entity System —
## Design, Query vocabulary). A game adds its own stats on top (e.g. CombatVocabulary.create("Armor")).
## Every query works on Dead subjects; relative queries compare the subject with Self.

## create("Str", "Per") or create(["Str", "Per"]).
static func create(...extra_stats: Array) -> Vocabulary:
	var v := Vocabulary.new()
	v.add_stats("MaxHp", "Hp", "HpPct", "Shield", "Initiative", "Speed")
	# Range: how far a unit's abilities reach (their targeting reads Self.Range); Radius: how wide its
	# area attacks hit (Self.Radius). Stats, so statuses and passives can boost them and the UI shows them.
	v.add_stats("Range", "Radius")
	# Power: what every hit adds (an attack's ActionPower reads Self.Power); Potency: what heals, statuses,
	# shields and buffs add (Mend: 10 + Self.Potency)
	v.add_stats("Power", "Potency")
	# Duration: how long the statuses a unit applies last, when its ability reads it (Apply Status duration = Self.Duration)
	v.add_stats("Duration")
	v.add_stats("Mana", "MaxMana", "Ap", "ActionPoints", "Mp", "MovePoints")
	v.add_stats(Vocabulary._flatten(extra_stats))

	# variables produced by combat (Variables combat adds)
	v.add_vars("ActionPower", "Damage", "FinalDamage", "Absorbed", "HpLost", "Overkill", "Amount", "Overheal", "Stacks", "TilesLeft", "Round")
	# in a reaction that comes from a status: that instance's own stacks (0 elsewhere). With PerSource,
	# Self.Stacks(X) is the total of every instance, so ticks should read StatusStacks.
	v.add_vars("StatusStacks")
	v.add_vars("X", "Y") # TileChanged: the tile
	v.add_bool_vars("Hit", "IsCrit")

	_add_name(v, "HasStatus", ValueKind.Bool, func(e: Entity, n: String) -> float: return Num.bool_num(e.has_status(n)))
	_add_name(v, "Stacks", ValueKind.Number, func(e: Entity, n: String) -> float: return float(e.stacks(n)))
	_add_name(v, "HasBuff", ValueKind.Bool, func(e: Entity, n: String) -> float:
		for s in e.statuses:
			if s.active and s.def.name == n and s.def.has_tag(Tags.Buff): return 1.0
		return 0.0)
	_add_name(v, "HasTag", ValueKind.Bool, func(e: Entity, n: String) -> float: return Num.bool_num(e.has_tag(n)))
	# the terrain under a unit (Tiles — Design): Self.OnTerrain(chasm), Target.OnTerrainTag(Solid)
	_add_name(v, "OnTerrain", ValueKind.Bool, func(e: Entity, n: String) -> float:
		return Num.bool_num(e.on_board and e.state.grid.terrain_at(e.pos).name == n))
	_add_name(v, "OnTerrainTag", ValueKind.Bool, func(e: Entity, n: String) -> float:
		return Num.bool_num(e.on_board and e.state.grid.terrain_at(e.pos).has_tag(n)))

	_add_flag(v, "IsAlive", func(e: Entity) -> bool: return e.alive)
	_add_flag(v, "CanAct", func(e: Entity) -> bool: return e.can_act)
	_add_flag(v, "CanMove", func(e: Entity) -> bool: return e.can_move)
	_add_flag(v, "IsUnit", func(e: Entity) -> bool: return e.kind == EntityKind.Unit)
	_add_flag(v, "IsObject", func(e: Entity) -> bool: return e.kind == EntityKind.Object_)
	_add_flag(v, "IsHazard", func(e: Entity) -> bool: return e.kind == EntityKind.Hazard)
	_add_flag(v, "DamagedThisRound", func(e: Entity) -> bool: return e.last_damaged_round == e.state.round and e.last_damaged_round >= 0)
	# the tile's index on its own path (higher = closer to the base), -1 off a path
	v.add_query(QueryDef.new("PathProgress", QueryArg.None, ValueKind.Number,
		func(u, _a, _o, _c) -> float: return float(u.path_progress)))
	# how many turns the unit has started (1 in its first): "every second turn" is TurnsTaken % 2 == 0
	v.add_query(QueryDef.new("TurnsTaken", QueryArg.None, ValueKind.Number,
		func(u, _a, _o, _c) -> float: return float(u.turns_taken)))

	# relative to Self
	_add_relative(v, "IsAlly", ValueKind.Bool, func(e: Entity, self_e: Entity) -> float:
		return Num.bool_num(not self_e.is_environment and e.state.relation(self_e, e) == Relation.Ally))
	_add_relative(v, "IsEnemy", ValueKind.Bool, func(e: Entity, self_e: Entity) -> float:
		return Num.bool_num(not self_e.is_environment and e.state.relation(self_e, e) == Relation.Enemy))
	_add_relative(v, "Distance", ValueKind.Number, func(e: Entity, self_e: Entity) -> float:
		return float(Dirs.manhattan(e.pos, self_e.pos)))
	# how far ahead along Self's own path the subject stands (the nearest path tile's index; -1 when Self follows no path)
	_add_relative(v, "AheadOnPath", ValueKind.Number, func(e: Entity, self_e: Entity) -> float:
		return float(self_e.ahead_on_path(e)))

	# Self stands behind the subject: on the side opposite the subject's facing
	_add_relative(v, "IsBehind", ValueKind.Bool, func(e: Entity, self_e: Entity) -> float:
		return Num.bool_num(e.state.rules.facing_enabled and self_e != e and _dot(e.facing, e.pos, self_e.pos) < 0))
	# the subject faces Self
	_add_relative(v, "IsFacing", ValueKind.Bool, func(e: Entity, self_e: Entity) -> float:
		return Num.bool_num(e.state.rules.facing_enabled and self_e != e and _dot(e.facing, e.pos, self_e.pos) > 0))

	v.add_query(QueryDef.new("DistanceTo", QueryArg.Subject, ValueKind.Number,
		func(u, _a, other, _c) -> float: return 0.0 if other == null else float(Dirs.manhattan(u.pos, other.pos))))
	return v

static func _dot(facing: Vector2i, from: Vector2i, to: Vector2i) -> int:
	return facing.x * (to.x - from.x) + facing.y * (to.y - from.y)

## f: (Entity, String) -> float.
static func _add_name(v: Vocabulary, p_name: String, result: int, f: Callable) -> void:
	v.add_query(QueryDef.new(p_name, QueryArg.Name, result, func(u, arg, _o, _c) -> float: return f.call(u, arg)))

## f: (Entity) -> bool.
static func _add_flag(v: Vocabulary, p_name: String, f: Callable) -> void:
	v.add_query(QueryDef.new(p_name, QueryArg.None, ValueKind.Bool, func(u, _a, _o, _c) -> float: return Num.bool_num(f.call(u))))

## f: (Entity subject, Entity self) -> float; without an Entity Self: false / 0.
static func _add_relative(v: Vocabulary, p_name: String, result: int, f: Callable) -> void:
	v.add_query(QueryDef.new(p_name, QueryArg.None, result, func(u, _a, _o, ctx) -> float:
		return f.call(u, ctx.self_) if ctx.self_ is Entity else 0.0))
