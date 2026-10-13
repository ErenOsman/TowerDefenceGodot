class_name Trigger
extends RefCounted
## An event plus the side the owner must be on. OnAnyTurnStart/OnAnyTurnEnd: any entity's turn (the condition
## decides whose). OnSpawned/OnResurrected: the owner was spawned/resurrected. OnTileChanged: any tile's terrain
## changed (facts X, Y: the tile).

const OnCast := 0
const OnAllyCast := 1
const OnAttackStarted := 2
const OnTargeted := 3
const OnHitDealt := 4
const OnHitTaken := 5
const OnAllyHitTaken := 6
const OnDodge := 7
const OnDamageDealt := 8
const OnDamageTaken := 9
const OnHealed := 10
const OnStatusApplied := 11
const OnStatusRemoved := 12
const OnMove := 13
const OnEnterTile := 14
const OnCollision := 15
const OnDeath := 16
const OnKill := 17
const OnTurnStart := 18
const OnTurnEnd := 19
const OnAttackEnded := 20
const OnAbilityEnded := 21
const OnAnyTurnStart := 22
const OnAnyTurnEnd := 23
const OnRoundStart := 24
const OnRoundEnd := 25
const OnSpawned := 26
const OnResurrected := 27
const OnTileChanged := 28

const NAMES := ["OnCast", "OnAllyCast", "OnAttackStarted", "OnTargeted", "OnHitDealt", "OnHitTaken", "OnAllyHitTaken", "OnDodge", "OnDamageDealt", "OnDamageTaken", "OnHealed", "OnStatusApplied", "OnStatusRemoved", "OnMove", "OnEnterTile", "OnCollision", "OnDeath", "OnKill", "OnTurnStart", "OnTurnEnd", "OnAttackEnded", "OnAbilityEnded", "OnAnyTurnStart", "OnAnyTurnEnd", "OnRoundStart", "OnRoundEnd", "OnSpawned", "OnResurrected", "OnTileChanged"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
