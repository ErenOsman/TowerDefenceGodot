class_name Modifier
extends RefCounted
## A change to a stat or a variable. Amounts are fractions for percentages (0.2 = +20%).
## The amount is a formula resolved in the phase of the value it modifies, with Self = the owner.

## The stat (Power, MaxHp…) or variable (ActionPower, Damage, FinalDamage, MaxRadius…) it changes.
var target: String = ""
var kind: int = ModKind.Flat
## [Slot("Modifier")]
var amount: Formula = Formula.new()
var direction: int = ModDirection.Outgoing
## The value's tags must contain all of these (e.g. Fire); empty applies to everything.
var required_tags: Array = []

## Modifier.new() or Modifier.new(target, kind, amount, direction, "Fire", ...) (tags variadic or one Array).
func _init(p_target: String = "", p_kind: int = ModKind.Flat, p_amount = null, p_direction: int = ModDirection.Outgoing, ...p_required_tags: Array) -> void:
	target = p_target
	kind = p_kind
	amount = Formula.of(p_amount)
	direction = p_direction
	required_tags = Vocabulary._flatten(p_required_tags).duplicate()

## tags: an Array or a Dictionary used as a set (anything with has()), or null.
func applies_to(value_name: String, tags) -> bool:
	if target != value_name: return false
	if required_tags == null: return true
	for t in required_tags:
		if tags == null or not tags.has(t): return false
	return true
