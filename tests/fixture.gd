class_name Fixture
extends RefCounted
## Builds small fights for tests: a vocabulary, game rules, a grid and a resolver (port of Fixture.cs).

var vocab: Vocabulary
var rules: GameRules
var state: GameState
var resolver: Resolver

func _init(width: int = 10, height: int = 10, seed: int = 12345) -> void:
	vocab = CombatVocabulary.create("Str", "Per", "Armor", "Evasion", "Exposed")
	rules = GameRules.new(vocab)
	# deterministic in tests: Evasion 1 always dodges, Exposed 1 is always crit
	rules.hit_chance = Formula.new("1 - Target.Evasion")
	rules.crit_chance = Formula.new("Target.Exposed")
	rules.crit_multiplier = Formula.new("1.5")
	rules.mitigation = Formula.new("Damage")
	state = GameState.new(rules, BattleGrid.new(width, height), seed)
	resolver = Resolver.new(state)

var log: EventLog:
	get: return resolver.log

## stats: Array of [stat_name, value] pairs, e.g. [["Initiative", 5]].
func unit(p_name: String, team: int, x: int, y: int, hp: int, stats: Array = []) -> Entity:
	return state.add_unit(p_name, team, Vector2i(x, y), hp, stats)

## Array of GameEvent.
func events(type: int) -> Array:
	return log.of_type(type)

func dump() -> String:
	return log.dump(state)

## Event types in order, skipping the given types (to keep assertions focused).
func types(skip: Array = []) -> Array:
	var out := []
	for e in log.events:
		if not skip.has(e.type): out.append(e.type)
	return out

static func N(d) -> float:
	return Num.fix(float(d))
