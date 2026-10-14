class_name TowerType
extends RefCounted
## A kind of tower (Archer): the entity it fights as and its energy cost. Designer data.

## Stable type ID, stored in saves (never the asset name).
var id: String = ""
## The name players see.
var name: String = ""
## Player-facing text for tooltips.
var description: String = ""
var entity: EntityDef = null
## Energy to place it. Selling refunds cost × 0.5 × Hp / MaxHp.
var cost: int = 0

## The type's forms (Workshop), its tree in content order: Array of FormDef. Empty for a type without forms.
var forms: Array = []
## Set on the type a level builds for a formed tower (Workshop.resolve): the form it fights as; null = default.
var form: FormDef = null
## Set with form: the base type (whose id, forms and default entity this one shares). Null on a base type.
var base: TowerType = null

## One of the type's forms by ID, or null.
func find_form(form_id: String) -> FormDef:
	for f in forms:
		if f.id == form_id: return f
	return null

## The forms whose parent is p (null = the root children), in content order.
func children_of(p: FormDef) -> Array:
	var out := []
	for f in forms:
		if f.parent == p: out.append(f)
	return out
