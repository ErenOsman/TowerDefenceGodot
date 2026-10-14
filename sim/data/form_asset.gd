class_name FormAsset
extends ContentAsset
## A form of a tower type (Workshop — Design, Content/Forms.json): a different tower the type can turn into
## (Archer → Fire Archer), unlocked per individual tower with tokens. It fights as its own entity.

## Stable form ID, saved on towers (OwnedTower.form / forms), e.g. "archer-fire". Empty falls back to the asset name.
var id: String = ""
## The form's own name ("Fire Archer"); empty = the entity's display name.
var display_name: String = ""
var description: String = ""
## The form's portrait (a Unity sprite path; may be the base tower's until a render exists).
var icon: String = ""
## The small badge sprite on hand cards, tray pieces, the board medallion and the Codex ("" = none).
var badge: String = ""
## The base tower type.
var tower: TowerAsset = null
## The parent form, or null for a form hanging off the root (the type's default form).
var parent: FormAsset = null
## The entity the tower fights as in this form.
var entity: EntityAsset = null
## Energy cost in this form; -1 = the base tower's.
var cost: int = -1
## The tokens to spend: Array of TokenAmount.
var unlock: Array = []
## Where the node sits around the root (0, 1, 2… clockwise from the top); children sit beyond their parent.
var order: int = 0

## The id, else the asset name.
func get_id() -> String:
	return name if id.is_empty() else id

## The display name, else the entity's, else the asset name.
func get_display_name() -> String:
	if not display_name.is_empty(): return display_name
	if entity != null and not entity.display_name.is_empty(): return entity.display_name
	return name
