class_name LevelResults
extends RefCounted
## Builds a LevelResult from a level session (engine-free; the GameScene calls it when the level ends).

## Won if the session's outcome is Won; base HP left over all bases together; rounds played;
## towers that died (player units — bases are objects). quit = left through the pause menu.
static func from(session: LevelSession, level_id: String, when: String, quit: bool = false) -> LevelResult:
	var hp := 0
	var max_hp := 0
	for id in session.bases:
		var b: Entity = session.state.get_entity(id)
		if b == null: continue
		max_hp += b.max_hp
		if b.alive: hp += b.hp
	var towers_lost := 0
	for e in session.log.events:
		if e.type != GameEventType.EntityDied: continue
		var t: Entity = session.state.get_entity(e.target)
		if t != null and t.kind == EntityKind.Unit and t.base_team == Teams.Player: towers_lost += 1
	var r := LevelResult.new()
	r.level_id = level_id
	r.won = not quit and session.outcome == Outcome.Won
	r.quit = quit
	r.base_hp_pct = (hp * 100) / max_hp if max_hp > 0 else 0
	r.rounds = session.round
	r.towers_lost = towers_lost
	r.when = when
	return r
