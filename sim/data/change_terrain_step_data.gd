class_name ChangeTerrainStepData
extends StepData

## The terrain the tiles become (e.g. Ground to fill a chasm, Chasm to drop a bridge).
var terrain: TerrainAsset = null
## The tiles changed: the aimed tile (Single) or an area around it.
var area: PatternDef = PatternDef.single()
## Only tiles of these terrains change (their ids, e.g. chasm); empty = every tile of the area.
var only_on: Array[String] = []
## Building on the changed tiles: kept, switched on, or switched off.
var build: int = BuildChange.Keep

func to_core(c: AssetConverter) -> Step:
	var s := ChangeTerrainStep.new()
	s.terrain = c.terrain(terrain)
	s.area = area if area != null else PatternDef.single()
	s.only_on = only_on.duplicate() if only_on != null else []
	s.build = build
	return s
