class_name CoopLevelSession
extends LevelSession
## The LevelSession a CoopSession drives (Multiplayer — Design, co-op). Godot-only (no C# counterpart).
## It differs from a plain LevelSession in two things only:
##  - the hand is every player's hand together (each already cut to the co-op per-player cap), not cut
##    to the level's single-player hand cap;
##  - with separate energy pools, every energy change goes to one player's pool (the acting player's, or
##    each open pool's share of income and GiveEnergy) instead of the single `energy`. With a shared pool it
##    behaves exactly like LevelSession, so a one-player shared-pool match writes the same event log.
## The presentation keeps reading this object like any LevelSession (state, log, placed, towers…).

## The CoopSession that owns this one (held weakly: the CoopSession owns us). Null = plain behaviour.
var _coop_ref: WeakRef = null

func _init(p_level: LevelDef, rules: GameRules, p_hand: Array, p_seed: int) -> void:
	super(p_level, rules, p_hand, p_seed)
	hand = p_hand.duplicate()
	last_error = ""
	var counts := {}
	for t in hand: counts[t.id] = counts.get(t.id, 0) + 1
	for t in hand:
		if counts[t.id] > 1:
			last_error = "Tower ID '%s' is in the hand %d times; every tower needs its own ID." % [t.id, counts[t.id]]
			break

func attach(coop) -> void:
	_coop_ref = weakref(coop) if coop != null else null

## Separate pools: the CoopSession books the change (writing the EnergyChanged events); a shared pool (or
## no CoopSession) is LevelSession's own single pool.
func _add_energy(amount: int, why: String) -> void:
	var coop = _coop_ref.get_ref() if _coop_ref != null else null
	if coop == null or coop.shared_pool:
		super._add_energy(amount, why)
		return
	coop._book_energy(amount, why)

## Writes one pool's EnergyChanged event: like LevelSession's, plus the fact Pool = the player's slot.
func _write_pool_energy(amount: int, total: int, slot: int, why: String) -> void:
	var e := GameEvent.new()
	e.type = GameEventType.EnergyChanged
	e.detail = why
	e.facts["Amount"] = float(amount)
	e.facts["Energy"] = float(total)
	e.facts["Pool"] = float(slot)
	log.write(e)
