class_name ModifierPipeline
extends RefCounted
## Final = clamp((Base + ΣFlat) × (1 + ΣPctAdd) × Π(1 + PctMult), min, max); an Override replaces it.
## The same order for every value.

## mods: Array of [kind: ModKind, amount: float] pairs (the C# (ModKind, Num) tuples).
## min_value/max_value: float or null (C# Num?); name: String or null.
static func apply(base_value: float, mods: Array, min_value = null, max_value = null, trace: Trace = null, name = null) -> float:
	var flat := 0.0
	var pct_add := 0.0
	var pct_mult := 1.0
	var override_value = null
	var any := false

	for m in mods:
		any = true
		var kind: int = m[0]
		var amount: float = m[1]
		match kind:
			ModKind.Flat: flat = Num.add(flat, amount)
			ModKind.PctAdd: pct_add = Num.add(pct_add, amount)
			ModKind.PctMult: pct_mult = Num.mul(pct_mult, Num.add(1.0, amount))
			ModKind.Override: override_value = amount

	var result: float = override_value if override_value != null else Num.mul(Num.mul(Num.add(base_value, flat), Num.add(1.0, pct_add)), pct_mult)
	if min_value != null: result = Num.max_of(min_value, result)
	if max_value != null: result = Num.min_of(max_value, result)

	if any and trace != null:
		trace.add("%s after modifiers (flat %s, +%s, ×%s)" % ["value" if name == null else name, Num.to_str(flat), Num.to_str(pct_add), Num.to_str(pct_mult)], result)
	return result
