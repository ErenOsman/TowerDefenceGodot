class_name AbilityText
extends RefCounted
## Plain numbers for UIs, evaluated for one caster: an ability's range (or how far it moves), attack
## area, power and cooldown, and an entity's power (its strongest attack) and speed. Formulas are
## evaluated with a private RNG, so asking never changes a battle; one that needs more than the caster
## (a target, a chain variable) is shown as its text.
## The nested C# class AbilityText.DefStats is the global class DefStats. C# Tags(...) → `tags` returning an
## Array of [value, name] pairs. Num? results → float or null. Evaluation errors: ctx.error instead of exceptions.

## "Range 2", "Moves up to 2 tiles", "Self"…: where the ability can aim.
static func range(a: AbilityDef, self_entity: IEntity, vocab: Vocabulary) -> String:
	return _range(a, self_entity, vocab)

static func _range(a: AbilityDef, self_entity: IEntity, vocab: Vocabulary) -> String:
	var p: PatternDef = a.targeting if a.targeting != null else PatternDef.self_()
	var mx := _eval(p.max_radius, self_entity, vocab)
	var mn := _eval(p.min_radius, self_entity, vocab)
	match p.shape:
		Shape.Single: return "Self"
		Shape.Steps: return "Moves up to %s" % _tiles(mx)
		Shape.PathAhead: return "Moves up to %s along its path" % _tiles(mx)
		Shape.Ray: return "Straight line"
		Shape.Custom: return "Custom range"
		Shape.Line: return "Line %s" % mx
		_: return ("Range %s–%s" % [mn, mx]) if mn != "0" else ("Range %s" % mx)

## The first attack's area ("Area: Circle 1", "First in line"), or null for a single target.
static func area(a: AbilityDef, self_entity: IEntity, vocab: Vocabulary) -> Variant:
	var attack := _first_attack(a)
	if attack == null or attack.area == null: return null
	match attack.area.shape:
		Shape.Single: return null
		Shape.Ray: return "Hits the first in line"
		_: return "Area: %s %s" % [Shape.name_of(attack.area.shape), _eval(attack.area.max_radius, self_entity, vocab)]

## The first attack's power, with its hits and bounces ("10", "60 +2 bounces"), or null when the ability does not attack.
static func power(a: AbilityDef, self_entity: IEntity, vocab: Vocabulary) -> Variant:
	var attack := _first_attack(a)
	if attack == null: return null
	var result := _eval(attack.power, self_entity, vocab)
	var hits := _eval(attack.hits, self_entity, vocab)
	var bounces := _eval(attack.bounces, self_entity, vocab)
	if hits != "1": result += " ×%s" % hits
	if bounces != "0": result += " +%s bounces" % bounces
	return result

## The results of an ability's formulas for this caster, named by what they are (UI Design Rules, Ability text and
## tags): Damage (or Heal when its hits only heal), Range (Move for a walk), Area, Hits, Jumps, Duration (only when
## a status's length scales, i.e. its formula reads something), Pushback / Pull. Value first (["10", "Damage"]).
## A formula that needs a target shows as its text. Returns an Array of [value, name] pairs.
static func tags(a: AbilityDef, self_entity: IEntity, vocab: Vocabulary) -> Array:
	var result := []
	var all := all_steps(a.steps)
	var attack: AttackStep = null
	for st in all:
		if st is AttackStep:
			attack = st
			break
	if attack != null:
		var on_hit := all_steps(attack.on_hit)
		var has_heal := false
		var has_damage := false
		for st in on_hit:
			if st is HealStep: has_heal = true
			if st is DamageStep: has_damage = true
		result.append([_eval(attack.power, self_entity, vocab), "Heal" if has_heal and not has_damage else "Damage"])
	else:
		var heal: HealStep = null
		for st in all:
			if st is HealStep:
				heal = st
				break
		if heal != null and not heal.amount.is_empty and heal.amount.expression != "ActionPower":
			result.append([_eval(heal.amount, self_entity, vocab), "Heal"])

	var p: PatternDef = a.targeting if a.targeting != null else PatternDef.self_()
	if p.shape != Shape.Single and p.shape != Shape.Custom and p.shape != Shape.Ray and not p.max_radius.is_empty:
		result.append([_eval(p.max_radius, self_entity, vocab), "Move" if p.shape == Shape.Steps or p.shape == Shape.PathAhead else "Range"])

	if attack != null:
		if attack.area != null and attack.area.shape != Shape.Single and attack.area.shape != Shape.Ray and not attack.area.max_radius.is_empty:
			result.append([_eval(attack.area.max_radius, self_entity, vocab), "Area"])
		var hits := _eval(attack.hits, self_entity, vocab)
		var bounces := _eval(attack.bounces, self_entity, vocab)
		if hits != "1" and hits != "0": result.append([hits, "Hits"])
		if bounces != "0": result.append([bounces, "Jumps"])
	for st in all:
		if st is ApplyStatusStep and not st.duration.is_empty and not _is_number(st.duration):
			result.append([_eval(st.duration, self_entity, vocab), "Duration"])
			break
	for st in all:
		if st is PushStep:
			result.append([_eval(st.distance, self_entity, vocab), "Pull" if st.pull else "Pushback"])
			break
	return result

## Every step of a list, nested ones included (an attack's hits, an If's branches, a Pick's steps…), in order.
## (The C# reflects over List<Step> fields; here every script variable holding an Array is searched for Steps.)
static func all_steps(steps) -> Array:
	var result := []
	if steps == null: return result
	for s in steps:
		if s == null: continue
		result.append(s)
		for prop in s.get_property_list():
			if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
			var v = s.get(prop.name)
			if v is Array and not v.is_empty() and v[0] is Step:
				result.append_array(all_steps(v))
	return result

static var _number_regex: RegEx = null

## decimal.TryParse with NumberStyles.Number: optional sign (leading or trailing), digits with group commas, a point.
static func _is_number(f: Formula) -> bool:
	if _number_regex == null:
		_number_regex = RegEx.create_from_string("^\\s*([+-]?)\\s*(\\d[\\d,]*\\.?\\d*|\\.\\d+)\\s*([+-]?)\\s*$")
	var m := _number_regex.search(f.expression.strip_edges())
	return m != null and not (m.get_string(1) != "" and m.get_string(3) != "")

## One line: range, area, damage (the attack's ActionPower) and cooldown.
static func summary(a: AbilityDef, self_entity: IEntity, vocab: Vocabulary) -> String:
	var parts := [_range(a, self_entity, vocab)]
	var ar = area(a, self_entity, vocab)
	if ar is String: parts.append(ar)
	var pw = power(a, self_entity, vocab)
	if pw is String: parts.append("Damage " + pw)
	if a.cooldown_until_reset: parts.append("Cooldown until reset")
	elif a.cooldown > 0: parts.append("Cooldown %d" % a.cooldown) # 1 = once a turn, every turn
	if a.start_cooldown != 0: parts.append("starts locked" if a.start_cooldown < 0 else "starts on cooldown %d" % a.start_cooldown)
	return " · ".join(parts)

## The highest power among an entity's attacks (numbers only), or null when it has none.
static func best_power(abilities: Array, self_entity: IEntity, vocab: Vocabulary) -> Variant:
	var best = null
	for a in abilities:
		var attack := _first_attack(a)
		if attack == null: continue
		var v = _try_eval(attack.power, self_entity, vocab)
		if v != null and (best == null or v > best): best = v
	return best

## A stat the unit has as one of its own (a base stat of its definition), as it is now (boosts
## included); null when the unit does not use it, so Range and Radius show only on units whose
## abilities read them.
static func own_stat(self_entity: IEntity, p_stat: String, vocab: Vocabulary) -> Variant:
	if self_entity == null or not vocab.is_stat(p_stat): return null
	var def: EntityDef = null
	if self_entity is Entity: def = self_entity.def
	elif self_entity is DefStats: def = self_entity.def
	if def == null or not def.base_stats.has(p_stat): return null
	return self_entity.stat(p_stat)

## The entity's Speed stat, or null when it has none (bases, hazards).
static func speed(self_entity: IEntity, vocab: Vocabulary) -> Variant:
	if not vocab.is_stat("Speed"): return null
	var v := self_entity.stat("Speed")
	return v if v > 0.0 else null

# ------------------------------------------------------------------ helpers

static func _tiles(n: String) -> String:
	return "1 tile" if n == "1" else n + " tiles"

static func _first_attack(a: AbilityDef) -> AttackStep:
	for st in a.steps:
		if st is AttackStep: return st
	return null

static func _eval(f, self_entity: IEntity, vocab: Vocabulary) -> String:
	var formula := Formula.of(f)
	if formula.is_empty: return "0"
	var v = _try_eval(formula, self_entity, vocab)
	return Num.to_str(v) if v != null else formula.expression

## The value, or null when the formula reads a target or a chain variable (C#: caught exception) or fails to parse.
static func _try_eval(f, self_entity: IEntity, vocab: Vocabulary) -> Variant:
	var formula := Formula.of(f)
	if formula.is_empty or self_entity == null: return null
	if formula.compile(vocab) == null: return null # C#: FormulaException, caught
	var ctx := EvalContext.new()
	ctx.self_ = self_entity; ctx.source = self_entity; ctx.rng = XorShiftRng.new(1)
	var v := formula.evaluate(vocab, ctx)
	if ctx.error != "": return null
	return v
