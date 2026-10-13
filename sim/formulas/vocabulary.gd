class_name Vocabulary
extends RefCounted
## The names formulas may use: stats, queries, variables and named library formulas.
## The formula core has no built-in game concepts; everything comes from here.
##
## REGISTRATION API (every add_* returns the Vocabulary, so calls chain like the C#; the variadic ones also
## accept a single Array of names):
##   var vocab := Vocabulary.new() \
##       .add_stats("Str", "MaxHp") \             # Source.Str / Target.MaxHp → IEntity.stat("Str")
##       .add_vars("ActionPower", "Damage") \     # number variables → ctx.vars["Damage"]
##       .add_bool_vars("IsCrit") \               # boolean variables (store 1.0 / 0.0 in ctx.vars)
##       .add_query(QueryDef.new("HasStatus", QueryArg.Name, ValueKind.Bool,
##           func(unit: IEntity, name_arg, other: IEntity, ctx: EvalContext) -> float:
##               return Num.bool_num(unit.has_status(name_arg)))) \
##       .add_library("BaseMelee", "Source.Str * 2")   # usable as @BaseMelee
##   QueryDef.evaluate is a Callable(unit, name_arg: String or null, other: IEntity or null, ctx) -> float:
##   QueryArg.None → Target.IsAlive (name_arg/other null); QueryArg.Name → Target.HasStatus(Poison)
##   (name_arg = "Poison"); QueryArg.Subject → Self.DistanceTo(Target) (other = ctx.entity(Subject.Target)).
## Lookups without out-params: try_get_var(n) → ValueKind or null; try_get_query(n) → QueryDef or null;
## try_get_library(n) → String or null.
## compile(expression) → IFormulaNode, or null on a parse error: then last_error holds the C# exception
## message ("col 8: unknown stat 'Strr'") and last_exception the FormulaException.

var _stats: Dictionary = {}
var _vars: Dictionary = {}
var _queries: Dictionary = {}
var _library: Dictionary = {}
var _cache: Dictionary = {}

## Message of the last failed compile() ("" after a successful one).
var last_error: String = ""
var last_exception: FormulaException = null

static func _flatten(names: Array) -> Array:
	if names.size() == 1 and (names[0] is Array or names[0] is PackedStringArray): return Array(names[0])
	return names

func add_stats(...names: Array) -> Vocabulary:
	for n in _flatten(names): _stats[n] = true
	_cache.clear()
	return self

func add_vars(...names: Array) -> Vocabulary:
	for n in _flatten(names): _vars[n] = ValueKind.Number
	_cache.clear()
	return self

func add_bool_vars(...names: Array) -> Vocabulary:
	for n in _flatten(names): _vars[n] = ValueKind.Bool
	_cache.clear()
	return self

func add_query(q: QueryDef) -> Vocabulary:
	_queries[q.name] = q
	_cache.clear()
	return self

func add_library(p_name: String, expression: String) -> Vocabulary:
	_library[p_name] = expression
	_cache.clear()
	return self

func is_stat(p_name: String) -> bool: return _stats.has(p_name)

## C# TryGetVar: the ValueKind, or null when unknown.
func try_get_var(p_name: String) -> Variant: return _vars.get(p_name)

var var_names: Array:
	get: return _vars.keys()

## C# TryGetQuery: the QueryDef, or null when unknown.
func try_get_query(p_name: String) -> QueryDef: return _queries.get(p_name)

## C# TryGetLibrary: the expression, or null when unknown.
func try_get_library(p_name: String) -> Variant: return _library.get(p_name)

## Parses once and caches by text. Returns null on errors (C# throws FormulaException): see last_error.
func compile(expression) -> IFormulaNode:
	if expression == null: expression = ""
	if _cache.has(expression):
		last_error = ""
		last_exception = null
		return _cache[expression]
	var node := Parser.parse(expression, self)
	if node == null:
		last_exception = Parser.last_error
		last_error = last_exception.message
		return null
	last_error = ""
	last_exception = null
	_cache[expression] = node
	return node
