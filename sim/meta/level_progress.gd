class_name LevelProgress
extends RefCounted
## Meta progress across levels, saved in GameData. Unlocks are never stored: they are computed
## from these records and the catalog (LevelCatalog).

var levels: Array = []  # of LevelRecord
## The level last selected in level select, so the cursor returns to it.
var last_selected: String = ""
## The C# ArgumentException message of the last record() that failed; "" otherwise.
var last_error: String = ""

func find(level_id: String) -> LevelRecord:
	for r in levels:
		if r.level_id == level_id: return r
	return null

func is_won(level_id: String) -> bool:
	var r := find(level_id)
	return r != null and r.won

## Adds one play: every result is an attempt; a win also updates the best values.
## (C# throws ArgumentException without a level id: push_error, last_error and null here.)
func record(result: LevelResult) -> LevelRecord:
	if result == null or result.level_id == "":
		last_error = "A result needs its level id."
		push_error(last_error)
		return null
	last_error = ""
	var r := find(result.level_id)
	if r == null:
		r = LevelRecord.new()
		r.level_id = result.level_id
		levels.append(r)

	r.attempts += 1
	if result.when != "": r.last_played = result.when
	if result.quit or not result.won: return r

	r.wins += 1
	r.won = true
	r.best_base_hp_pct = maxi(r.best_base_hp_pct, clampi(result.base_hp_pct, 0, 100))
	r.fewest_rounds = result.rounds if r.fewest_rounds < 0 else mini(r.fewest_rounds, result.rounds)
	r.fewest_towers_lost = result.towers_lost if r.fewest_towers_lost < 0 else mini(r.fewest_towers_lost, result.towers_lost)
	return r
