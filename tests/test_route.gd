extends TestCase
## Port of RouteTests.cs: choosing a movement route with the pointer (RouteBuilder) and validating routes (Targeting.is_valid_aim).

const A := Vector2i(0, 1)
const B := Vector2i(1, 1)
const C := Vector2i(1, 0)

var walk: AbilityDef

func setup() -> void:
	walk = AbilityDef.new()
	walk.name = "Walk"
	walk.tags = [Tags.Movement]
	walk.targeting = PatternDef.steps("Self.Speed")
	walk.steps = [WalkStep.new()]

## [fixture, mover]
func _setup_mover() -> Array:
	var f := Fixture.new(5, 5)
	var mover: Entity = f.unit("Mover", 0, 0, 0, 100, [["Speed", 3]])
	mover.abilities.append(walk)
	return [f, mover]

func test_the_route_follows_the_pointer_and_shortens_when_it_comes_back() -> void:
	var r := _setup_mover()
	var f: Fixture = r[0]
	var route := RouteBuilder.new(f.state, r[1], walk)

	route.hover(A)
	route.hover(B)
	route.hover(C) # a detour: (1,0) is one step away, but the pointer went round
	assert_seq(route.path, [A, B, C])

	route.hover(A) # back over the route
	assert_seq(route.path, [A])

	route.hover(Vector2i(3, 0)) # not next to the end: the shortest route
	assert_eq(route.path.size(), 3)
	assert_eq(route.destination, Vector2i(3, 0))

	route.hover(Vector2i(4, 4)) # out of reach: the route stays
	assert_eq(route.destination, Vector2i(3, 0))

func test_the_route_never_exceeds_the_budget() -> void:
	var r := _setup_mover()
	var f: Fixture = r[0]
	var route := RouteBuilder.new(f.state, r[1], walk)
	for p in [A, B, C, Vector2i(2, 0)]: route.hover(p)
	assert_eq(route.destination, Vector2i(2, 0))
	assert_eq(route.path.size(), 2, "a 4th step is over budget, so the shortest route is used")

func test_the_chosen_route_is_walked_tile_by_tile() -> void:
	var r := _setup_mover()
	var f: Fixture = r[0]
	var mover: Entity = r[1]
	var route := RouteBuilder.new(f.state, mover, walk)
	for p in [A, B, C]: route.hover(p)
	var aim := route.to_aim()

	var reason := []
	assert_true(Targeting.is_valid_aim(f.state, mover.id, walk, aim, reason), str(reason))
	f.resolver.cast(mover, walk, aim)

	var entered := []
	for e in f.events(GameEventType.EntityEnteredTile): entered.append(e.to)
	assert_seq(entered, [A, B, C])
	assert_eq(mover.position, C)

func test_invalid_routes_are_rejected() -> void:
	var r := _setup_mover()
	var f: Fixture = r[0]
	var mover: Entity = r[1]
	f.state.grid.set_terrain(Vector2i(2, 1), TerrainDef.Wall)
	var valid := func(path: Array) -> bool:
		var aim := Aim.new(path[path.size() - 1], Dirs.NONE)
		aim.path = path.duplicate()
		return Targeting.is_valid_aim(f.state, mover.id, walk, aim)

	assert_true(valid.call([A, B, C]))
	assert_false(valid.call([B]), "not next to the start")
	assert_false(valid.call([A, B, Vector2i(2, 1)]), "through a wall")
	assert_false(valid.call([A, B, A]), "crosses a tile twice")
	assert_false(valid.call([A, Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)]), "over budget")

	var shortest := Aim.new(Vector2i(2, 0), Dirs.NONE)
	assert_true(Targeting.is_valid_aim(f.state, mover.id, walk, shortest))
	assert_eq(shortest.path.size(), 2, "no route given: the shortest is filled in")
