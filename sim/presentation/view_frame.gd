class_name ViewFrame
extends RefCounted
## What the view shows after one beat: every entity and the level's counters. Captured by the
## simulation when the beat completes, so presenters never re-apply rules (Animation &
## Presentation design, View model).

var beat: int = 0
var round: int = 0
var phase: int = Phase.NotStarted
var outcome: int = Outcome.Running
var energy: int = 0
var waves: Array = []  # of WaveView
## EntityId (int) → EntityFrame, in entity order.
var entities: Dictionary = {}

func get_frame(id: int) -> EntityFrame:
	return entities.get(id, null)

## Reads the current state of a level (or of a bare battle when session is null).
static func capture(state: GameState, session: LevelSession, p_beat: int) -> ViewFrame:
	var frame := ViewFrame.new()
	frame.beat = p_beat
	frame.round = state.round
	if session != null:
		frame.phase = session.phase
		frame.outcome = session.outcome
		frame.energy = session.energy
		for w in session.waves:
			var wv := WaveView.new()
			wv.name = w.def.name if w.def.name != "" else "Wave " + str(w.index + 1)
			wv.started = w.started
			wv.finished = w.finished
			wv.wave_round = w.wave_round(state.round) if w.started else 0
			frame.waves.append(wv)

	for e in state.entities:
		if e.is_environment or e.life == LifeState.Removed: continue
		var f := EntityFrame.new()
		f.id = e.id
		f.name = _display_name(e, session)
		f.kind = e.kind
		f.life = e.life
		f.position = e.position
		f.pos = e.pos
		f.facing = e.facing
		f.team = state.effective_team(e)
		f.has_hp = e.has_hp
		f.hp = e.hp if e.has_hp else 0
		f.max_hp = e.max_hp if e.has_hp else 0
		f.shield = e.shield
		f.tower_id = session.tower_id_of(e) if session != null else null
		for sum in e.status_summaries():
			var sv := StatusView.new()
			sv.def = sum.def
			sv.name = sum.def.display_name
			sv.stacks = sum.stacks
			sv.turns_left = sum.turns_left
			var pool := 0
			for s in e.statuses:
				if s.active and s.def == sum.def: pool += s.pool
			sv.shield = pool
			for s in e.statuses:
				if s.def != sum.def: continue
				var a: Entity = state.get_entity(s.applied_by)
				if a == null or a.def == null or a.id == 0: continue
				if not sv.applied_by.has(a.def.display_name): sv.applied_by.append(a.def.display_name)
			f.statuses.append(sv)
		for p in e.passives:
			if p.def != null and not p.def.hidden:
				var pv := PassiveView.new()
				pv.def = p.def
				pv.name = p.def.display_name
				pv.active = p.active
				f.passives.append(pv)
		for k in e.cooldowns:
			if e.cooldowns[k] > 0: f.cooldowns[k] = e.cooldowns[k]
		frame.entities[e.id] = f
	return frame

## A placed tower's name from the hand (custom or type name), else the entity's display name.
static func _display_name(e: Entity, session: LevelSession) -> String:
	var tower_id = session.tower_id_of(e) if session != null else null
	if tower_id != null:
		var t: TowerDef = session.tower(tower_id)
		if t != null: return t.name
	return e.def._display_name if e.def != null and e.def._display_name != "" else e.name  # C# reads the raw displayName field
