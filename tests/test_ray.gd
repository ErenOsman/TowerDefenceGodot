extends TestCase
## Port of RayTests.cs. Straight shots at any angle (Ray): the first blocker takes the hit, walls stop the
## shot, allies pass or block by option. The ray from (0,0) to (6,3) crosses (1,1) (2,1) (3,2) (4,2) (5,3) (6,3).

const TARGET := Vector2i(6, 3)
const ON_THE_WAY := Vector2i(3, 2)

static func _shot(passes_allies := true) -> AbilityDef:
	var a := AbilityDef.new()
	a.name = "Shot"
	a.tags = [Tags.Attack, Tags.Projectile]
	a.targeting = PatternDef.diamond("10")
	a.target_filter = Condition.new("Target.IsEnemy")
	var atk := AttackStep.new()
	atk.area = PatternDef.ray(passes_allies)
	atk.can_miss = false
	atk.can_crit = false
	atk.power = Formula.new("10")
	var dmg := DamageStep.new()
	dmg.amount = Formula.new("ActionPower")
	atk.on_hit = [dmg]
	a.steps = [atk]
	return a

## [fixture, archer, target]
static func _setup_fight() -> Array:
	var f := Fixture.new()
	return [f, f.unit("Archer", 0, 0, 0, 100), f.unit("Target", 1, TARGET.x, TARGET.y, 100)]

static func _hit_by(f: Fixture) -> String:
	var names := []
	for e in f.events(GameEventType.DamageDealt): names.append(f.state.get_entity(e.target).name)
	return ",".join(names)

func test_a_clear_ray_hits_the_target_at_any_angle() -> void:
	var r := _setup_fight()
	var f: Fixture = r[0]
	var archer: Entity = r[1]
	f.resolver.cast(archer, _shot(), Aim.at(archer.pos, TARGET))
	assert_eq(_hit_by(f), "Target", f.dump())

func test_the_first_enemy_on_the_way_takes_the_hit() -> void:
	var r := _setup_fight()
	var f: Fixture = r[0]
	var archer: Entity = r[1]
	f.unit("Shield", 1, ON_THE_WAY.x, ON_THE_WAY.y, 100)
	f.resolver.cast(archer, _shot(), Aim.at(archer.pos, TARGET))
	assert_eq(_hit_by(f), "Shield", f.dump())

func test_allies_pass_or_block_by_option() -> void:
	var r := _setup_fight()
	var f: Fixture = r[0]
	var archer: Entity = r[1]
	f.unit("Friend", 0, ON_THE_WAY.x, ON_THE_WAY.y, 100)

	f.resolver.cast(archer, _shot(true), Aim.at(archer.pos, TARGET))
	assert_eq(_hit_by(f), "Target")

	var ray := Targeting.ray(f.state, archer, PatternDef.ray(false), TARGET)
	assert_eq(ray[1], ON_THE_WAY, "an ally stops the shot")
	assert_seq(ray[0], [Vector2i(1, 1), Vector2i(2, 1), ON_THE_WAY])

func test_walls_stop_the_shot_and_stealthed_enemies_are_passed() -> void:
	var r := _setup_fight()
	var f: Fixture = r[0]
	var archer: Entity = r[1]
	var sneak: Entity = f.unit("Sneak", 1, 2, 1, 100)
	var stealth := StatusDef.new()
	stealth.name = "Stealth"
	stealth.tags = [Tags.Stealthed]
	var st := StatusInstance.new()
	st.def = stealth
	st.stacks = 1
	st.turns_left = -1
	sneak.statuses.append(st)
	f.resolver.cast(archer, _shot(), Aim.at(archer.pos, TARGET))
	assert_eq(_hit_by(f), "Target", "the archer cannot see it, so it is not in the way")

	f.state.grid.set_terrain(Vector2i(4, 2), TerrainDef.Wall)
	assert_null(Targeting.ray(f.state, archer, PatternDef.ray(), TARGET)[1])

func test_preview_shows_the_line_the_hit_and_areas() -> void:
	var r := _setup_fight()
	var f: Fixture = r[0]
	var archer: Entity = r[1]
	var target: Entity = r[2]
	var shield: Entity = f.unit("Shield", 1, ON_THE_WAY.x, ON_THE_WAY.y, 100)

	var shot := AimPreview.for_aim(f.state, archer.id, _shot(), Aim.at(archer.pos, TARGET))
	assert_seq(shot.line, [Vector2i(1, 1), Vector2i(2, 1), ON_THE_WAY])
	assert_seq(shot.area, [ON_THE_WAY])
	assert_seq(shot.targets, [shield.id])

	var blast := AbilityDef.new()
	blast.name = "Blast"
	blast.targeting = PatternDef.diamond("8")
	var atk := AttackStep.new()
	atk.area = PatternDef.diamond("1")
	atk.power = Formula.new("5")
	blast.steps = [atk]
	var area := AimPreview.for_aim(f.state, archer.id, blast, Aim.at(archer.pos, Vector2i(6, 2)))
	assert_eq(area.area.size(), 5)
	assert_seq(area.targets, [target.id])

	assert_eq(AimPreview.range(f.state, archer.id, _shot()).size(), 64, "Diamond 10 from a corner of a 10×10 grid: 10+10+9+…+2 tiles")
