extends TestCase
## Port of FormulaTests.cs: Formula System — Design and Condition System — Design, without combat.

class FakeUnit extends IEntity:
	var stats: Dictionary = {}
	var statuses: Dictionary = {}
	func _init(p_name: String) -> void: name = p_name
	func stat(s: String) -> float: return stats.get(s, 0.0)

## Counts draws so tests can prove when the RNG is (not) touched.
class CountingRng extends IRng:
	var draws := 0
	func next_uint() -> int:
		draws += 1
		return 0x80000000
	func next_unit() -> float:
		draws += 1
		return 0.5
	func chance(p: float) -> bool: return next_unit() < p
	func clone() -> IRng: return CountingRng.new()

var vocab: Vocabulary
var source: FakeUnit
var target: FakeUnit

func setup() -> void:
	vocab = Vocabulary.new() \
		.add_stats("Str", "Per", "MaxHP", "HpPct", "Armor") \
		.add_vars("Power", "Damage", "HpLost") \
		.add_bool_vars("IsCrit") \
		.add_query(QueryDef.new("HasStatus", QueryArg.Name, ValueKind.Bool,
			func(u, n, _o, _c): return Num.bool_num(u.statuses.has(n)))) \
		.add_library("BaseMelee", "Source.Str * 2")

	source = FakeUnit.new("Source")
	source.stats["Str"] = 20.0
	source.stats["Per"] = 12.0
	target = FakeUnit.new("Target")
	target.stats["MaxHP"] = 400.0
	target.stats["HpPct"] = 0.25
	target.stats["Armor"] = 25.0

func ctx(rng: IRng = null) -> EvalContext:
	var c := EvalContext.new()
	c.source = source
	c.self_ = source
	c.target = target
	c.rng = rng if rng != null else XorShiftRng.new(1)
	return c

func eval(f: String, c: EvalContext = null) -> float:
	var node := vocab.compile(f)
	if node == null:
		fail("compile '%s' failed: %s" % [f, vocab.last_error])
		return NAN
	return node.evaluate(c if c != null else ctx())

func test_precedence_and_arithmetic() -> void:
	assert_num(eval("2 + 3 * 4"), 14)
	assert_num(eval("(2 + 3) * 4"), 20)
	assert_num(eval("-3 + 2"), -1)
	assert_num(eval("@BaseMelee"), 40)

func test_modulo_is_floored() -> void:
	assert_num(eval("7 % 3"), 1)
	assert_num(eval("-1 % 3"), 2, "sign of the divisor, unlike C#")
	assert_num(eval("2.5 % 1"), 0.5)
	assert_num(eval("1 + 2 * 3 % 4"), 3, "same precedence as * and /, left to right: 1 + ((2 * 3) % 4)")
	assert_true(Num.is_true(eval("Source.Str % 2 == 0")))

	var c := ctx()
	assert_num(eval("5 % 0", c), 0)
	assert_eq(c.warnings.size(), 1)

func test_decimals_are_exact() -> void:
	# in double, 1.15 * 100 = 114.99999999999999, which floors to 114
	assert_num(eval("floor(1.15 * 100)"), 115)

func test_if_evaluates_only_the_chosen_branch() -> void:
	var rng := CountingRng.new()
	eval("if(1 < 2, 5, rand(0, 10))", ctx(rng))
	assert_eq(rng.draws, 0)
	eval("if(1 > 2, 5, rand(0, 10))", ctx(rng))
	assert_eq(rng.draws, 1)

func test_rand_uses_bounds_in_previews() -> void:
	var c := ctx(CountingRng.new())
	c.mode = EvalMode.PreviewMin
	assert_num(eval("rand(36, 44)", c), 36)
	c.mode = EvalMode.PreviewMax
	assert_num(eval("rand(36, 44)", c), 44)
	assert_eq((c.rng as CountingRng).draws, 0)

func test_division_by_zero_is_zero_with_warning() -> void:
	var c := ctx()
	assert_num(eval("10 / (Source.Str - 20)", c), 0)
	assert_not_null(c.warnings)
	assert_eq(c.warnings.size(), 1)

func test_parsing_is_culture_invariant() -> void:
	# no culture in GDScript; keep the checks
	assert_num(eval("0.05"), 0.05)
	assert_eq(Num.to_str(0.05), "0.05")

func test_parse_errors_report_a_column() -> void:
	assert_null(vocab.compile("Source.Strr * 2"))
	assert_true(vocab.last_error.contains("col 8: unknown stat 'Strr'"), vocab.last_error)
	assert_not_null(vocab.last_exception)
	assert_null(vocab.compile("Power +"))
	assert_ne(vocab.last_error, "")
	assert_null(vocab.compile("Foo"))
	assert_ne(vocab.last_error, "")

func test_library_cycles_are_rejected() -> void:
	vocab.add_library("A", "@B + 1").add_library("B", "@A")
	assert_null(vocab.compile("@A"))
	assert_true(vocab.last_error.contains("references itself"), vocab.last_error)

func _some_contains(errors: Array, s: String) -> void:
	for e in errors:
		if e.contains(s): return
	fail("no error contains \"%s\" in %s" % [s, str(errors)])

func test_validator_checks_phases_types_and_randomness() -> void:
	var errors := Validator.validate("Target.MaxHP", ContextSpec.Targeting, vocab, "Range")
	_some_contains(errors, "Range reads Target.MaxHP, but Targeting has no target.")

	errors = Validator.validate("HpLost * 0.5", ContextSpec.OnHit, vocab, "Lifesteal")
	_some_contains(errors, "HpLost is not produced yet")
	assert_seq(Validator.validate("HpLost * 0.5", ContextSpec.OnHit.with("HpLost"), vocab), [])

	errors = Validator.validate("Self.HpPct", ContextSpec.CastGate, vocab)
	_some_contains(errors, "must produce a boolean")

	errors = Validator.validate("rand(0, 1) < 0.5", ContextSpec.ReactionTrigger, vocab)
	_some_contains(errors, "rand()")

	errors = Validator.validate("IsCrit", ContextSpec.CastGate, vocab)
	_some_contains(errors, "IsCrit")

	assert_seq(Validator.validate("Self.HpPct < 0.3 and not Self.HasStatus(Silence)", ContextSpec.CastGate, vocab), [])

func test_condition_reports_the_first_failing_part() -> void:
	source.stats["HpPct"] = 0.5
	var rage := Condition.new("Self.HpPct < 0.3 and not Self.HasStatus(Silence)")
	assert_eq(rage.failure_reason(vocab, ctx()), "Requires Self.HpPct < 0.3")

	source.stats["HpPct"] = 0.2
	source.statuses["Silence"] = true
	assert_eq(rage.failure_reason(vocab, ctx()), "Requires not Self.HasStatus(Silence)")

	source.statuses.clear()
	assert_null(rage.failure_reason(vocab, ctx()))
	assert_true(Condition.new("").evaluate(vocab, ctx())) # empty = always true

func test_modifier_pipeline_order() -> void:
	var mods := [
		[ModKind.Flat, 10.0],
		[ModKind.PctAdd, 0.2],
		[ModKind.PctAdd, 0.3],
		[ModKind.PctMult, 0.2],
		[ModKind.PctMult, 0.3],
	]
	# (100 + 10) × 1.5 × 1.2 × 1.3
	assert_num(ModifierPipeline.apply(100.0, mods), 257.4)
	assert_num(ModifierPipeline.apply(100.0, [[ModKind.Override, 1.0]]), 1)


# ---------------------------------------------------------------- parity with the C# oracle
# Expected lines produced by the C# (~/godot/oracle, a throwaway probe): parse errors with columns, node text,
# values, traces, warnings, validator messages. Values the decimal type prints with more than 9 decimals
# (rand, 10 / 3) are compared numerically.

class OracleUnit extends IEntity:
	func stat(s: String) -> float: return 20.0 if s == "Str" else 0.25

const ORACLE_CASES := [
	"2 + 3 * 4 - 1",
	"Source.Strr * 2",
	"Power +",
	"Foo",
	"@A",
	"@Bad",
	"@Nope",
	"@",
	"Source.Str >= 10 and Self.HpPct < 0.5",
	"Source.Str + IsCrit",
	"IsCrit and Power",
	"not Power",
	"-IsCrit",
	"1 = 2",
	"1 ! 2",
	"1 # 2",
	"min(1)",
	"min(1, 2, 3)",
	"max(Source.Str, Power, 2)",
	"clamp(5, 1)",
	"clamp(15, 1, 10)",
	"floor(2.7) + round(2.5) + round(-2.5)",
	"if(Power, 1, 2)",
	"if(IsCrit, 1, IsCrit)",
	"if(IsCrit, Power * 2, 0)",
	"rand(1)",
	"rand(1, 10)",
	"rand(IsCrit, 2)",
	"Source.HasStatus(Poison)",
	"Source.HasStatus",
	"Source.HasStatus()",
	"Self.DistanceTo(Target) + 1",
	"Self.DistanceTo(Foo)",
	"Target.IsAlive",
	"Target.IsAlive == true",
	"true == 1",
	"Source",
	"Source.",
	"1.2.3",
	".5 + 5.",
	"(1 + 2",
	"1 + 2)",
	"1 2",
	"Power % 0 + Damage / 0",
	"1 < 2 < 3",
	"true or false and false",
	"  Source.Str   *  ( 2 + 1 )  ",
	"@Base + @Base",
	"10 / 3",
	"Source.Str != Power",
	"Damage == IsCrit",
	"1 <= 2 == true",
	"1 > ",
]

const ORACLE_EXPECTED := [
	"OK|Number|2 + 3 * 4 - 1|13||",
	"ERR|col 8: unknown stat 'Strr'",
	"ERR|col 8: unexpected 'end of formula'",
	"ERR|col 1: unknown name 'Foo'",
	"ERR|col 2: in '@A': col 2: in '@B': col 2: library formula '@A' references itself",
	"ERR|col 2: in '@Bad': col 8: unknown stat 'Foo'",
	"ERR|col 2: unknown library formula '@Nope'",
	"ERR|col 2: expected a library formula name after '@', found 'end of formula'",
	"OK|Bool|Source.Str >= 10 and Self.HpPct < 0.5|1|Source.Str = 20;Self.HpPct = 0.25|",
	"ERR|col 14: arithmetic expects a number, but 'IsCrit' is a boolean",
	"ERR|col 12: 'and' expects a boolean, but 'Power' is a number",
	"ERR|col 5: 'not' expects a boolean, but 'Power' is a number",
	"ERR|col 2: '-' expects a number, but 'IsCrit' is a boolean",
	"ERR|col 3: unexpected '=' (use == or !=)",
	"ERR|col 3: unexpected '!' (use == or !=)",
	"ERR|col 3: unexpected character '#'",
	"ERR|col 1: 'min' takes 2 or more arguments, got 1",
	"OK|Number|min(1, 2, 3)|1||",
	"OK|Number|max(Source.Str, Power, 2)|20|Source.Str = 20;Power = 7.5|",
	"ERR|col 1: 'clamp' takes 3 arguments, got 2",
	"OK|Number|clamp(15, 1, 10)|10||",
	"OK|Number|floor(2.7) + round(2.5) + round(-2.5)|2||",
	"ERR|col 4: the condition of 'if' expects a boolean, but 'Power' is a number",
	"ERR|col 15: both branches of 'if' must have the same type",
	"OK|Number|if(IsCrit, Power * 2, 0)|15|IsCrit = 1;Power = 7.5|",
	"ERR|col 1: 'rand' takes 2 arguments, got 1",
	"OK|Number|rand(1, 10)|3.3271890971809625625610351558|rand(1, 10) = 3.3271890971809625625610351558|",
	"ERR|col 6: 'rand' expects a number, but 'IsCrit' is a boolean",
	"OK|Bool|Source.HasStatus(Poison)|1|Source.HasStatus(Poison) = 1|",
	"ERR|col 17: expected '(' after 'HasStatus', found 'end of formula'",
	"ERR|col 18: expected an argument for 'HasStatus', found ')'",
	"OK|Number|Self.DistanceTo(Target) + 1|4|Self.DistanceTo(Target) = 3|",
	"ERR|col 17: 'DistanceTo' expects Source, Target or Self, found 'Foo'",
	"OK|Bool|Target.IsAlive|1|Target.IsAlive = 1|",
	"OK|Bool|Target.IsAlive == true|1|Target.IsAlive = 1|",
	"ERR|col 9: cannot compare 'true' with '1'",
	"ERR|col 7: expected '.' after 'Source', found 'end of formula'",
	"ERR|col 8: expected a stat or query after 'Source.', found 'end of formula'",
	"ERR|col 1: invalid number '1.2.3'",
	"OK|Number|.5 + 5.|5.5||",
	"ERR|col 7: expected ')', found 'end of formula'",
	"ERR|col 6: unexpected ')'",
	"ERR|col 3: unexpected '2'",
	"OK|Number|Power % 0 + Damage / 0|0|Power = 7.5;Damage = 3|Modulo by zero in 'Power % 0'; result is 0.;Division by zero in 'Damage / 0'; result is 0.",
	"ERR|col 7: unexpected '<'",
	"OK|Bool|true or false and false|1||",
	"OK|Number|Source.Str   *  ( 2 + 1 )|60|Source.Str = 20|",
	"OK|Number|@Base + @Base|80|Source.Str = 20;Source.Str = 20|",
	"OK|Number|10 / 3|3.3333333333333333333333333333||",
	"OK|Bool|Source.Str != Power|1|Source.Str = 20;Power = 7.5|",
	"ERR|col 11: cannot compare 'Damage' with 'IsCrit'",
	"ERR|col 8: unexpected '=='",
	"ERR|col 5: unexpected 'end of formula'",
	"V|Targeting||Targeting is empty.",
	"V|Targeting|Target.Str|Targeting reads Target.Str, but Targeting has no target.",
	"V|Targeting|Damage|Targeting reads Damage, but Damage is not produced yet in Targeting.",
	"V|Targeting|rand(1,2)|",
	"V|Targeting|Source.Str > 1|Targeting must produce a number, but 'Source.Str > 1' is a boolean.",
	"V|Targeting|Self.DistanceTo(Target)|",
	"V|Targeting|Source.Foo|Targeting: col 8: unknown stat 'Foo'",
	"V|CastGate||",
	"V|CastGate|Target.Str|Cast gate must produce a boolean, but 'Target.Str' is a number.;Cast gate reads Target.Str, but Cast gate has no target.",
	"V|CastGate|Damage|Cast gate must produce a boolean, but 'Damage' is a number.;Cast gate reads Damage, but Damage is not produced yet in Cast gate.",
	"V|CastGate|rand(1,2)|Cast gate must produce a boolean, but 'rand(1,2)' is a number.;Cast gate uses rand(), which conditions may not use; put the chance in a separate field.",
	"V|CastGate|Source.Str > 1|",
	"V|CastGate|Self.DistanceTo(Target)|Cast gate must produce a boolean, but 'Self.DistanceTo(Target)' is a number.",
	"V|CastGate|Source.Foo|Cast gate: col 8: unknown stat 'Foo'",
	"V|Passive||",
	"V|Passive|Target.Str|Passive must produce a boolean, but 'Target.Str' is a number.;Passive reads Target.Str, but Passive has no target.",
	"V|Passive|Damage|Passive must produce a boolean, but 'Damage' is a number.;Passive reads Damage, but Damage is not produced yet in Passive.",
	"V|Passive|rand(1,2)|Passive must produce a boolean, but 'rand(1,2)' is a number.;Passive uses rand(), which conditions may not use; put the chance in a separate field.",
	"V|Passive|Source.Str > 1|Passive reads Source.Str, but Passive has no source.",
	"V|Passive|Self.DistanceTo(Target)|Passive must produce a boolean, but 'Self.DistanceTo(Target)' is a number.",
	"V|Passive|Source.Foo|Passive: col 8: unknown stat 'Foo'",
	"V|OnHit||OnHit is empty.",
	"V|OnHit|Target.Str|",
	"V|OnHit|Damage|OnHit reads Damage, but Damage is not produced yet in OnHit.",
	"V|OnHit|rand(1,2)|",
	"V|OnHit|Source.Str > 1|OnHit must produce a number, but 'Source.Str > 1' is a boolean.",
	"V|OnHit|Self.DistanceTo(Target)|",
	"V|OnHit|Source.Foo|OnHit: col 8: unknown stat 'Foo'",
	"M|20|value after modifiers (flat 5, +0, ×1.5) = 20",
	"C|Requires not Self.Str > 5",
	"R|0.3390852638985961675643920898",
	"R|0.7822558477055281400680541992",
	"R|0.790137045085430145263671875",
	"R|0.9440426349174231290817260742",
	"R|0.7643936777021735906600952148",
]

func _oracle_vocab() -> Vocabulary:
	return Vocabulary.new().add_stats("Str", "HpPct").add_vars("Power", "Damage").add_bool_vars("IsCrit") \
		.add_query(QueryDef.new("HasStatus", QueryArg.Name, ValueKind.Bool, func(_u, n, _o, _c): return Num.bool_num(n == "Poison"))) \
		.add_query(QueryDef.new("DistanceTo", QueryArg.Subject, ValueKind.Number, func(_u, _n, _o, _c): return 3.0)) \
		.add_query(QueryDef.new("IsAlive", QueryArg.None, ValueKind.Bool, func(_u, _n, _o, _c): return 1.0)) \
		.add_library("Base", "Source.Str * 2").add_library("Bad", "Source.Foo").add_library("A", "@B + 1").add_library("B", "@A")

func _oracle_lines() -> Array[String]:
	var v := _oracle_vocab()
	var lines: Array[String] = []
	for f in ORACLE_CASES:
		var n := v.compile(f)
		if n == null:
			lines.append("ERR|" + v.last_error)
			continue
		var t := Trace.new()
		var u := OracleUnit.new()
		var c := EvalContext.new()
		c.source = u; c.self_ = u; c.target = u; c.rng = XorShiftRng.new(5); c.trace = t
		c.vars = {"Power": 7.5, "Damage": 3.0, "IsCrit": 1.0}
		var val := n.evaluate(c)
		var shown := Num.to_str(val) if c.error == "" else "RUNTIME " + c.error
		lines.append("OK|%s|%s|%s|%s|%s" % [ValueKind.name_of(n.kind), n.text, shown, ";".join(t.lines), "" if c.warnings == null else ";".join(c.warnings)])
	for spec in ["Targeting", "CastGate", "Passive", "OnHit"]:
		for f in ["", "Target.Str", "Damage", "rand(1,2)", "Source.Str > 1", "Self.DistanceTo(Target)", "Source.Foo"]:
			lines.append("V|%s|%s|%s" % [spec, f, ";".join(Validator.validate(f, ContextSpec.by_name(spec), v))])
	var tr := Trace.new()
	var r := ModifierPipeline.apply(10.0, [[ModKind.Flat, 5.0], [ModKind.PctMult, 0.5]], 0.0, 20.0, tr, null)
	lines.append("M|%s|%s" % [Num.to_str(r), str(tr)])
	var cc := EvalContext.new()
	cc.self_ = OracleUnit.new()
	lines.append("C|" + str(Condition.new("not (Self.Str > 5 or Self.HpPct > 1)").failure_reason(v, cc)))
	var rng := XorShiftRng.new(42)
	for i in 5: lines.append("R|" + Num.to_str(rng.next_unit()))
	return lines

## Lines equal, or equal after reading every run of digits with a long fraction as a number (≈ 1e-8).
func _oracle_same(a: String, e: String) -> bool:
	if a == e: return true
	var re := RegEx.create_from_string("-?\\d+\\.\\d{9,}")
	var na := re.search_all(a)
	var ne := re.search_all(e)
	if ne.is_empty() or na.size() != ne.size(): return false
	if re.sub(a, "#", true) != re.sub(e, "#", true): return false
	for i in na.size():
		if absf(float(na[i].get_string()) - float(ne[i].get_string())) > 1e-8: return false
	return true

func test_oracle_parity() -> void:
	var got := _oracle_lines()
	assert_eq(got.size(), ORACLE_EXPECTED.size())
	for i in mini(got.size(), ORACLE_EXPECTED.size()):
		if not _oracle_same(got[i], ORACLE_EXPECTED[i]):
			fail("line %d:\n   expected %s\n   got      %s" % [i, ORACLE_EXPECTED[i], got[i]])

func test_rng_vectors() -> void:
	var r := XorShiftRng.new(12345)
	assert_eq(r.next_uint(), 2555902770)
	assert_eq(r.next_uint(), 3234773579)
	assert_eq(r.next_uint(), 328846939)
	assert_eq(XorShiftRng.new(0).next_uint(), 226735074)
	assert_num(XorShiftRng.new(7).next_unit(), 0.820246666)
	var a := XorShiftRng.new(99)
	a.next_uint()
	var b := a.clone()
	assert_eq(a.next_uint(), b.next_uint())

func test_runtime_errors_are_recorded() -> void:
	var c := EvalContext.new()
	c.self_ = source
	assert_num(eval("Target.MaxHP + 1", c), 1)
	assert_eq(c.error, "Target.MaxHP: Target is not available in this context.")
	var c2 := EvalContext.new()
	c2.self_ = source
	eval("Power * 2", c2)
	assert_eq(c2.error, "Variable 'Power' is not available in this context.")
	var c3 := ctx()
	c3.rng = null
	eval("rand(1, 2)", c3)
	assert_eq(c3.error, "rand(1, 2): no RNG in context.")
	assert_eq(ctx().error, "")

func test_modifier_applies_to() -> void:
	var m := Modifier.new("Damage", ModKind.PctAdd, "0.2", ModDirection.Incoming, "Fire")
	assert_eq(m.amount.expression, "0.2")
	assert_true(m.applies_to("Damage", ["Fire", "Attack"]))
	assert_true(m.applies_to("Damage", {"Fire": true}))
	assert_false(m.applies_to("Damage", ["Attack"]))
	assert_false(m.applies_to("Power", ["Fire"]))
	assert_true(Modifier.new("Power", ModKind.Flat, "1").applies_to("Power", null))
	assert_num(m.amount.evaluate(vocab, ctx()), 0.2)
	assert_eq(Rounding.apply(-0.5, Round.FloorMin0), 0.0)
	assert_eq(Rounding.apply(2.5, Round.Nearest), 3.0)
