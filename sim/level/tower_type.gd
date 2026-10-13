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
