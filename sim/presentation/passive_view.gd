class_name PassiveView
extends RefCounted
## One passive as the UI shows it (hidden passives are left out).

var def: PassiveDef = null
var name: String = ""
## Its condition holds now (always true for a passive without one).
var active: bool = false

## The visible passives of a definition (an entity not on the board yet, e.g. a tower in the hand), all active.
static func of(d: EntityDef) -> Array:
	var list := []
	if d != null:
		for p in d.passives:
			if p != null and not p.hidden:
				var v := PassiveView.new()
				v.def = p
				v.name = p.display_name
				v.active = true
				list.append(v)
	return list
