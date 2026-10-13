class_name GameRules
extends IRuleSource
## Game-wide formulas, teams and rules. Shared, never cloned.

var vocabulary: Vocabulary

## OnHit: chance that an attack chain hits (only rolled when the step can miss).
var hit_chance: Formula = Formula.new("1")

## OnHit: chance of a crit (only rolled when the step can crit and the hit landed).
var crit_chance: Formula = Formula.new("0")

## OnHit: multiplier applied to Damage on a crit.
var crit_multiplier: Formula = Formula.new("1.5")

## Mitigation: FinalDamage from Damage, e.g. Damage * 100 / (100 + Target.Armor).
var mitigation: Formula = Formula.new("Damage")

## Mana restored at the owner's TurnStarted (Self = the entity). Capped at MaxMana.
var mana_regen: Formula = Formula.new("0")

## When off, facing is never read and never changes.
var facing_enabled: bool = false

## Rules owned by the Environment entity, e.g. collision damage. Arrays of ReactionDef / ReplacementRule / Modifier.
var reactions: Array = []
var replacements: Array = []
var modifiers: Array = []

## Effects deeper than this are dropped with a warning.
var max_depth: int = 16

## Vector2i(teamA, teamB) → Relation.
var _relations: Dictionary = {}

func _init(p_vocabulary: Vocabulary = null) -> void:
	vocabulary = p_vocabulary

## Sets the relation between two teams (both directions). Default: same team Ally, otherwise Enemy.
func set_relation(team_a: int, team_b: int, p_relation: int) -> GameRules:
	_relations[Vector2i(team_a, team_b)] = p_relation
	_relations[Vector2i(team_b, team_a)] = p_relation
	return self

func relation_of(team_a: int, team_b: int) -> int:
	var key := Vector2i(team_a, team_b)
	if _relations.has(key): return _relations[key]
	return Relation.Ally if team_a == team_b else Relation.Enemy

## IRuleSource.Name.
var name: String:
	get: return "GameRules"

## IRuleSource.Aura: never an aura.
var aura: Condition:
	get: return Condition.new()
