class_name FormDef
extends RefCounted
## One form of a tower type (Workshop — Design): a different tower the type turns into (Archer → Fire Archer),
## with its own entity, name and optionally energy cost, unlocked per individual tower with tokens. Designer data.
## Holds its type by ID (not a TowerType reference) so TowerType.forms ↔ FormDef makes no reference cycle.

## Stable form ID, saved on towers (OwnedTower.form / forms).
var id: String = ""
## The name players see ("Fire Archer").
var name: String = ""
var description: String = ""
## Portrait sprite (Unity path) and the small form badge sprite ("" = none).
var icon: String = ""
var badge: String = ""
## The base tower type's ID (TowerType.id).
var tower: String = ""
## The parent form, or null for a form hanging off the root (the type's default form).
var parent: FormDef = null
## The entity the tower fights as in this form.
var entity: EntityDef = null
## Energy cost in this form; -1 = the base tower's.
var cost: int = -1
## The tokens to spend: {token id: amount}, in content order.
var unlock: Dictionary = {}
## The token kinds the cost names: {token id: TokenDef} (for their names).
var tokens: Dictionary = {}
## Where the node sits around the root (0, 1, 2… clockwise from the top).
var order: int = 0
## Upgrades — Design: the form's own level ladder (Array of TowerLevelDef); the base's bonuses do not carry into it.
var levels: Array = []

## How deep the node sits: 1 for a root child, 2 for its child…
var depth: int:
	get:
		var d := 1
		var p := parent
		while p != null and d < 64:
			d += 1
			p = p.parent
		return d

## The energy cost a level uses: the form's own, else the base's.
func cost_or(base_cost: int) -> int:
	return cost if cost >= 0 else base_cost

## A token's display name (its id when unknown).
func token_name(token_id: String) -> String:
	var t = tokens.get(token_id)
	return t.name if t != null and t.name != "" else token_id

func _to_string() -> String:
	return "%s (form of %s)" % [id, tower]
