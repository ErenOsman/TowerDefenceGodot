class_name GameEventType
extends RefCounted
## The kinds of GameEvent. CooldownChanged: a Reset Cooldown or Add Cooldown step changed Target's cooldowns
## (Detail: the ability, empty = all). TileChanged: a tile's terrain or build flag changed (To: the tile;
## Detail: "old>new" terrain names; Facts X, Y). PhaseStarted..LevelLost are written by the level layer
## (no reactions respond to them).

const AbilityDeclared := 0
const AttackStarted := 1
const HitResolved := 2
const DamageDealt := 3
const Healed := 4
const StatusApplied := 5
const StatusRemoved := 6
const EntityMoved := 7
const EntityEnteredTile := 8
const Collision := 9
const EntityDied := 10
const TurnStarted := 11
const TurnEnded := 12
const AttackEnded := 13
const AbilityEnded := 14
const CooldownChanged := 15
const ResourceChanged := 16
const Fizzled := 17
const Prevented := 18
const EntitySpawned := 19
const EntityResurrected := 20
const EntityRemoved := 21
const TeamChanged := 22
const FacingChanged := 23
const PassiveActivated := 24
const PassiveDeactivated := 25
const RoundStarted := 26
const RoundEnded := 27
const TileChanged := 28
const PhaseStarted := 29
const WaveStarted := 30
const WaveFinished := 31
const EnergyChanged := 32
const LevelMessage := 33
const LevelWon := 34
const LevelLost := 35

const NAMES := ["AbilityDeclared", "AttackStarted", "HitResolved", "DamageDealt", "Healed", "StatusApplied", "StatusRemoved", "EntityMoved", "EntityEnteredTile", "Collision", "EntityDied", "TurnStarted", "TurnEnded", "AttackEnded", "AbilityEnded", "CooldownChanged", "ResourceChanged", "Fizzled", "Prevented", "EntitySpawned", "EntityResurrected", "EntityRemoved", "TeamChanged", "FacingChanged", "PassiveActivated", "PassiveDeactivated", "RoundStarted", "RoundEnded", "TileChanged", "PhaseStarted", "WaveStarted", "WaveFinished", "EnergyChanged", "LevelMessage", "LevelWon", "LevelLost"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
