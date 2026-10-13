class_name CodexAsset
extends ContentAsset
## What the Codex lists, in order (Codex — Design): towers, enemies, statuses and tips. Referenced by the
## game catalog (GameCatalogAsset.codex).

## Array of TowerAsset.
var towers: Array = []
## Array of EntityAsset.
var enemies: Array = []
## Statuses players can meet; hidden ones (tag Hidden) never show. Array of StatusAsset.
var statuses: Array = []
## Short how-to pages: Array of CodexTip. Text may use {key:Id} and {click:Id}.
var tips: Array = []

## The enemies a level spawns (waves and spawn events), in order of appearance, without repeats.
static func enemies_of(level: LevelAsset) -> Array:
	var result := []
	if level == null: return result
	var seen := {}
	for wave in level.waves:
		if wave == null: continue
		var spawned := [] # [round, order, enemy]
		for s in wave.spawns:
			if s != null and s.enemy != null: spawned.append([s.round, spawned.size(), s.enemy])
		for e in wave.events:
			if e != null and e.kind == LevelEventKind.SpawnEnemies and e.enemy != null: spawned.append([e.round, spawned.size(), e.enemy])
		spawned.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])) # OrderBy is stable
		for x in spawned:
			if not seen.has(x[2]):
				seen[x[2]] = true
				result.append(x[2])
	return result
