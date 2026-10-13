class_name GameRulesAsset
extends ContentAsset
## Game-wide formulas, the stat vocabulary, team relations and Environment-owned rules.

## Stats formulas may read, in addition to MaxHp, Hp, HpPct, Shield, Initiative and the resource stats.
var stats: Array[String] = ["Armor"]

## Named formulas usable as @Name: Array of LibraryEntry.
var library: Array = []

## [Slot("OnHit")]
var hit_chance: Formula = Formula.new("1")
## [Slot("OnHit")]
var crit_chance: Formula = Formula.new("0")
## [Slot("OnHit")]
var crit_multiplier: Formula = Formula.new("1.5")
## [Slot("Mitigation")]
var mitigation: Formula = Formula.new("Damage")

## Mana restored at each TurnStarted (Self = the unit), capped at MaxMana. [Slot("Modifier")]
var mana_regen: Formula = Formula.new("0")

## Entities turn toward where they move and cast; enables IsBehind/IsFacing and Facing patterns.
var facing_enabled: bool = false

## Pairs not listed: same team Ally, otherwise Enemy. Array of TeamRelation.
var relations: Array = []

## The map kit: every Tile a level's visual and props layers may name (Array of TileAsset).
var tiles: Array = []

## Rules owned by the Environment entity: Array of ReactionAsset.
var reactions: Array = []
## Array of ReplacementData.
var replacements: Array = []
## Array of Modifier.
var modifiers: Array = []

var max_depth: int = 16

func create_vocabulary() -> Vocabulary:
	var v: Vocabulary = CombatVocabulary.create(stats if stats != null else [])
	for entry in library:
		if entry != null and not entry.name.is_empty(): v.add_library(entry.name, entry.expression if entry.expression != null else "")
	return v
