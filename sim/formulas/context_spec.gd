class_name ContextSpec
extends RefCounted
## What an evaluation point (formula phase or condition point) provides, and what it expects back.

var name: String
var subjects: int
## Set of variable names ({name: true}).
var vars: Dictionary = {}
var expects: int
var allow_random: bool

## vars: variadic names (or one Array), like the C# params string[].
func _init(p_name: String = "", p_subjects: int = SubjectNeeds.None, p_expects: int = ValueKind.Number, p_allow_random: bool = false, ...p_vars: Array) -> void:
	name = p_name
	subjects = p_subjects
	expects = p_expects
	allow_random = p_allow_random
	for v in Vocabulary._flatten(p_vars): vars[v] = true

## A copy that also provides the given variables (e.g. chain variables produced earlier).
func with(...extra_vars: Array) -> ContextSpec:
	var all: Array = vars.keys()
	all.append_array(Vocabulary._flatten(extra_vars))
	return ContextSpec.new(name, subjects, expects, allow_random, all)

const _SOURCE_SELF := SubjectNeeds.Source | SubjectNeeds.Self
const _ALL := SubjectNeeds.Source | SubjectNeeds.Target | SubjectNeeds.Self

# Formula phases
static var Targeting := ContextSpec.new("Targeting", _SOURCE_SELF, ValueKind.Number, true)
static var Attack := ContextSpec.new("Attack", _SOURCE_SELF, ValueKind.Number, true)
static var OnHit := ContextSpec.new("OnHit", _ALL, ValueKind.Number, true, "ActionPower")
static var Mitigation := ContextSpec.new("Mitigation", _ALL, ValueKind.Number, true, "ActionPower", "Damage")

## Modifier amounts resolve in the phase of the value they modify, so any subject may be read.
static var Modifier := ContextSpec.new("Modifier", _ALL, ValueKind.Number, true, "ActionPower", "Damage")

# Condition evaluation points
static var CastGate := ContextSpec.new("Cast gate", _SOURCE_SELF, ValueKind.Bool, false)
static var TargetFilter := ContextSpec.new("Target filter", _ALL, ValueKind.Bool, false)
static var ReactionTrigger := ContextSpec.new("Reaction trigger", _ALL, ValueKind.Bool, false)
static var Passive := ContextSpec.new("Passive", SubjectNeeds.Self, ValueKind.Bool, false)
static var Replacement := ContextSpec.new("Replacement", _ALL, ValueKind.Bool, false)
static var Step := ContextSpec.new("Step", _ALL, ValueKind.Bool, false, "ActionPower")

## An instinct's preference: a number scored for each candidate (Self = the chooser, Target = the candidate).
static var Instinct := ContextSpec.new("Instinct", _ALL, ValueKind.Number, false)

## Looks up a spec by the name used in [Slot("...")]; null if unknown.
static func by_name(p_name: String) -> ContextSpec:
	match p_name:
		"Targeting": return Targeting
		"Attack": return Attack
		"OnHit": return OnHit
		"Mitigation": return Mitigation
		"Modifier": return Modifier
		"CastGate": return CastGate
		"TargetFilter": return TargetFilter
		"ReactionTrigger": return ReactionTrigger
		"Passive": return Passive
		"Replacement": return Replacement
		"Step": return Step
		"Instinct": return Instinct
		_: return null
