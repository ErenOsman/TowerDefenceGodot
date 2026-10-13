extends TestCase
## Port of DirectorTests.cs: the Director with fake presenters: beat order, parallel events, impact tails,
## frames, Skip, Instant.

class Clock extends RefCounted:
	var now: float = 0.0

## Plays for `duration` seconds and is ready at `ready_at` (its impact).
class FakePresenter extends IPresenter:
	var event: GameEvent
	var duration: float
	var ready_at: float
	var elapsed: float = 0.0
	var begun := false
	var finished := false
	var begun_at: float = 0.0
	var _clock: Clock

	func _init(e: GameEvent, p_duration: float, p_ready_at: float, clock: Clock) -> void:
		event = e; duration = p_duration; ready_at = p_ready_at; _clock = clock

	func begin() -> void:
		begun = true
		begun_at = _clock.now
	func tick(dt: float) -> void: elapsed += dt
	func is_ready() -> bool: return elapsed >= ready_at - 1e-4
	func is_done() -> bool: return elapsed >= duration - 1e-4
	func finish() -> void:
		elapsed = duration
		finished = true

class FakeFactory extends IPresenterFactory:
	var made: Array = []
	var timing: Dictionary = {}  # GameEventType → [duration, ready]
	var clock := Clock.new()

	func create(e: GameEvent, _beat: BeatPlayback) -> IPresenter:
		var t: Array = timing.get(e.type, [0.1, 0.1])
		var p := FakePresenter.new(e, t[0], t[1], clock)
		made.append(p)
		return p

	func of(type: int) -> Array:
		return made.filter(func(p): return p.event.type == type)

static func _blast(power: int) -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Blast"
	a.targeting = PatternDef.diamond("9")
	var atk := AttackStep.new()
	atk.area = PatternDef.diamond("1"); atk.power = Formula.new(str(power)); atk.can_miss = false; atk.can_crit = false
	var dmg := DamageStep.new(); dmg.amount = Formula.new("ActionPower")
	atk.on_hit = [dmg]
	a.steps = [atk]
	return a

## {f, caster, a, b, factory, director}
func _setup(hp := 30) -> Dictionary:
	var f := Fixture.new()
	var caster := f.unit("Caster", 0, 0, 0, 100)
	var a := f.unit("A", 1, 4, 4, hp)
	var b := f.unit("B", 1, 5, 4, hp)
	var factory := FakeFactory.new()
	var director := Director.new(f.log, factory, FrameRecorder.new(f.state, f.log))
	return {"f": f, "caster": caster, "a": a, "b": b, "factory": factory, "director": director}

func _play_all(d: Director, clock: Clock, dt := 0.05) -> void:
	for i in 1000:
		if not d.busy: break
		clock.now += dt
		d.tick(dt)
	assert_false(d.busy, "playback ends")

func test_beats_play_in_order_and_a_beats_events_together() -> void:
	var t := _setup(10)
	var director: Director = t.director
	var factory: FakeFactory = t.factory
	assert_false(director.busy)
	t.f.resolver.cast(t.caster, _blast(10), Aim.at(t.caster.pos, t.a.pos))
	assert_true(director.busy, "new events: input must wait")

	_play_all(director, factory.clock)

	var hits := factory.of(GameEventType.DamageDealt)
	var deaths := factory.of(GameEventType.EntityDied)
	var attacks := factory.of(GameEventType.AttackStarted)
	assert_eq(hits.size(), 2)
	assert_eq(attacks.size(), 1)
	if hits.size() != 2 or attacks.size() != 1: return
	assert_true(absf(hits[0].begun_at - hits[1].begun_at) <= 1e-4, "hits of one beat start together")
	assert_true(hits[0].begun_at > attacks[0].begun_at, "the hits wait for the attack")
	assert_true(deaths.all(func(d): return d.begun_at > hits[0].begun_at), "deaths wait for the hits")
	assert_true(factory.made.all(func(p): return p.begun))

func test_a_presenter_ready_at_impact_lets_the_next_beat_start_while_its_tail_plays() -> void:
	var t := _setup()
	var director: Director = t.director
	var factory: FakeFactory = t.factory
	factory.timing[GameEventType.AttackStarted] = [0.6, 0.2]
	t.f.resolver.cast(t.caster, _blast(10), Aim.at(t.caster.pos, t.a.pos))

	_play_all(director, factory.clock)

	var attacks := factory.of(GameEventType.AttackStarted)
	var hits := factory.of(GameEventType.DamageDealt)
	if attacks.size() != 1 or hits.is_empty():
		fail("expected an attack and hits")
		return
	assert_true(hits[0].begun_at - attacks[0].begun_at < 0.3, "the hit starts at the impact, not after the follow-through")
	assert_true(attacks[0].done, "the tail still played to its end")

func test_the_shown_frame_changes_when_the_beat_that_changed_it_starts() -> void:
	var t := _setup(30)
	var director: Director = t.director
	var factory: FakeFactory = t.factory
	var a: Entity = t.a
	var shown_at_beat := []  # [first event type, hp]
	director.beat_started.connect(func(beat): shown_at_beat.append([beat.events[0].type, director.shown.get_frame(a.id).hp]))

	t.f.resolver.cast(t.caster, _blast(10), Aim.at(t.caster.pos, a.pos))
	assert_eq(director.shown.get_frame(a.id).hp, 30, "nothing shown changes before playback")
	_play_all(director, factory.clock)

	var at_attack := shown_at_beat.filter(func(x): return x[0] == GameEventType.AttackStarted)
	var at_hit := shown_at_beat.filter(func(x): return x[0] == GameEventType.HitResolved or x[0] == GameEventType.DamageDealt)
	if at_attack.is_empty() or at_hit.is_empty():
		fail("expected attack and hit beats: %s" % str(shown_at_beat))
		return
	assert_eq(at_attack[0][1], 30, "still full while the attack plays")
	assert_eq(at_hit[0][1], 20, "drops with the hit")
	assert_eq(director.shown.get_frame(a.id).hp, 20)

func test_skip_finishes_one_action_and_the_next_plays_normally() -> void:
	var t := _setup()
	var director: Director = t.director
	var factory: FakeFactory = t.factory
	t.f.resolver.cast(t.caster, _blast(5), Aim.at(t.caster.pos, t.a.pos))   # action 0
	t.f.resolver.cast(t.caster, _blast(5), Aim.at(t.caster.pos, t.b.pos))   # action 1
	var ended := []
	director.action_ended.connect(func(info): ended.append(info.id))

	director.tick(0.01)
	director.skip()

	assert_seq(ended, [0])
	assert_true(factory.made.filter(func(p): return p.event.action == 0).all(func(p): return p.finished or p.done), "the first action is finished")
	assert_false(factory.made.any(func(p): return p.event.action == 1), "the second has not started")
	assert_true(director.busy)

	_play_all(director, factory.clock)
	assert_seq(ended, [0, 1])
	assert_false(factory.made.filter(func(p): return p.event.action == 1).any(func(p): return p.finished), "played, not skipped")

func test_instant_finishes_everything_in_one_tick() -> void:
	var t := _setup(10)
	var director: Director = t.director
	var factory: FakeFactory = t.factory
	director.instant = true
	t.f.resolver.cast(t.caster, _blast(10), Aim.at(t.caster.pos, t.a.pos))

	director.tick(0)

	assert_false(director.busy)
	assert_true(factory.made.all(func(p): return p.done))
	assert_eq(director.shown.get_frame(t.a.id).life, LifeState.Dead)

func test_frames_follow_the_level_and_are_released_after_playing() -> void:
	var base := EntityDef.new()
	base.name = "Base"; base.kind = EntityKind.Object_; base.tags = [Tags.Base]
	base.stat("MaxHp", 10)
	var level := LevelDef.new()
	level.width = 4; level.height = 3; level.start_energy = 5; level.energy_per_round = 2
	level.paths = [[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]]
	var b := BaseDef.new(); b.tile = Vector2i(3, 1); b.entity = base
	level.bases = [b]
	var w := WaveDef.new(); w.start_round = 5
	level.waves = [w]
	var session := LevelSession.new(level, GameRules.new(CombatVocabulary.create()), [], 1)
	var recorder := FrameRecorder.of_session(session)
	var factory := FakeFactory.new()
	var director := Director.new(session.log, factory, recorder)
	var energy_at_beat := []
	director.beat_started.connect(func(_beat): energy_at_beat.append(director.shown.energy))

	session.start()
	session.end_round()
	_play_all(director, factory.clock)

	assert_contains(energy_at_beat, 5)
	assert_contains(energy_at_beat, 7, "the income beat shows the new energy")
	assert_eq(director.shown.energy, 7)
	assert_eq(director.shown.phase, Phase.Player)
	assert_eq(recorder.count, 0, "played frames are released")
