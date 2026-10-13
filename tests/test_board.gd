extends TestCase
## The board layer's pure logic (game/board, game/level): tile ↔ world, the map-kit yaw table, facing, presenter
## timing on a fake clock, banners, the VFX kit's data, and a level played through the Director with the default
## presenters (no SCRIPT ERROR, views in line with the frame).

const N := Vector2i(0, 1)
const E := Vector2i(1, 0)
const S := Vector2i(0, -1)
const W := Vector2i(-1, 0)

func _near(a: Vector3, b: Vector3, msg := "") -> void:
	assert_true(a.distance_to(b) < 0.0001, "%s: %s ≠ %s" % [msg, a, b])

# ------------------------------------------------------------------ grid space

func test_tile_to_world_puts_north_at_minus_z() -> void:
	assert_eq(GridSpace.to_world(Vector2i(3, 2)), Vector3(3, 0, -2))
	assert_eq(GridSpace.to_world(Vector2i(0, 0), 0.5), Vector3(0, 0.5, 0))
	assert_eq(GridSpace.to_tile(Vector3(3.4, 1.0, -1.6)), Vector2i(3, 2))
	for p in [Vector2i(0, 0), Vector2i(7, 4), Vector2i(13, 8)]:
		assert_eq(GridSpace.to_tile(GridSpace.to_world(p)), p)
	assert_eq(GridSpace.to_world_dir(N), Vector3(0, 0, -1))
	assert_eq(GridSpace.to_world_dir(E), Vector3(1, 0, 0))

## A kit piece imports with its rest north side along +Z and its west side along +X (Blender (x, y, z) → Godot
## (x, z, −y), the map's north = Blender −Y, west = Blender +X). piece_yaw(turns) must put those sides where the
## clockwise-turned sides belong on the board (the README's yaw table: rotating +90 turns arms N→E→S→W).
func test_piece_yaw_turns_sides_clockwise() -> void:
	var order := [N, E, S, W]
	for t in 4:
		var b := Basis(Vector3.UP, GridSpace.piece_yaw(t))
		_near(b * Vector3(0, 0, 1), GridSpace.to_world_dir(order[t]), "north side after %d turns" % t)
		_near(b * Vector3(1, 0, 0), GridSpace.to_world_dir(order[(t + 3) % 4]), "west side after %d turns" % t)

func test_road_corner_table() -> void:
	# README: ┘ (N+W) yaw 0, └ (N+E) 90, ┌ (E+S) 180, ┐ (S+W) 270 — TileLook.fit gives the turns
	assert_eq(TileLook.fit("NW", "NW"), 0)
	assert_eq(TileLook.fit("NW", "NE"), 1)
	assert_eq(TileLook.fit("NW", "ES"), 2)
	assert_eq(TileLook.fit("NW", "SW"), 3)
	# and the corner's arms land on those board sides
	var wanted := [[N, W], [N, E], [E, S], [S, W]]
	for t in 4:
		var b := Basis(Vector3.UP, GridSpace.piece_yaw(t))
		var arms := [b * Vector3(0, 0, 1), b * Vector3(1, 0, 0)]
		for d in wanted[t]:
			var hit := false
			for a in arms: hit = hit or a.distance_to(GridSpace.to_world_dir(d)) < 0.001
			assert_true(hit, "corner turn %d reaches %s" % [t, d])

func test_facing_yaw_turns_the_model_front() -> void:
	for d in [N, E, S, W, Vector2i(1, 1)]:
		var front: Vector3 = Basis(Vector3.UP, GridSpace.facing_yaw(d)) * Vector3(0, 0, 1)
		_near(front, GridSpace.to_world_dir(d).normalized(), "facing %s" % d)
	assert_null(GridSpace.look_yaw(Vector3.ONE, Vector3(1, 5, 1)))
	var yaw = GridSpace.look_yaw(Vector3.ZERO, Vector3(0, 0, -3))
	_near(Basis(Vector3.UP, yaw) * Vector3(0, 0, 1), Vector3(0, 0, -1), "look north")

func test_camera_bounds_and_free_area() -> void:
	var cam := BoardCamera.new()
	cam.bounds = Rect2(-0.5, -0.5, 10, 5)
	cam.max_distance = 16.0  # fit 10
	cam.min_distance = 3.0
	cam.distance_target = 10.0
	assert_eq(cam.clamp_focus(Vector3(20, 3, 4)), Vector3(4.5, 0, -2), "at the default framing the board stays whole: no pan")
	cam.distance_target = 14.0
	assert_eq(cam.clamp_focus(Vector3(0, 0, 0)), Vector3(4.5, 0, -2), "zoomed out: still centred")
	cam.distance_target = 3.0
	assert_eq(cam.clamp_focus(Vector3(20, 3, 4)), Vector3(9.5, 0, 0.5), "zoomed all the way in: up to the board's edges")
	assert_eq(cam.clamp_focus(Vector3(-3, 0, -9)), Vector3(-0.5, 0, -4.5))
	var free := cam.free_area()
	assert_num(snappedf(free.position.y, 0.0001), snappedf((96.0 + BoardCamera.GUTTER) / 1080.0, 0.0001), "under the top bar, with a gutter")
	assert_num(snappedf(free.end.y, 0.0001), snappedf(1.0 - (168.0 + BoardCamera.GUTTER) / 1080.0, 0.0001), "above the hand tray, with a gutter")
	assert_num(snappedf(free.end.x, 0.0001), snappedf(1.0 - BoardCamera.GUTTER / 1920.0, 0.0001), "the whole width (the right bar may cover the edge)")
	cam.free()

# ------------------------------------------------------------------ presenters on a fake clock

func test_timed_presenter_ready_at_impact_then_done() -> void:
	var p := TimedPresenter.new(0.3, 0.15)
	p.begin()
	assert_false(p.ready)
	p.tick(0.1)
	assert_false(p.ready)
	p.tick(0.06)
	assert_true(p.ready)
	assert_false(p.done)
	p.tick(0.2)
	assert_true(p.done)
	var zero := SimplePresenter.new(0.0)
	zero.begin()
	assert_true(zero.done, "a zero-length presenter finishes at begin")

func test_when_ready_fires_once() -> void:
	var count := [0]
	var p := WhenReady.new(TimedPresenter.new(0.2, 0.1), func(): count[0] += 1)
	p.begin()
	assert_eq(count[0], 0)
	p.tick(0.12)
	assert_eq(count[0], 1)
	p.tick(0.2)
	p.finish()
	assert_eq(count[0], 1)

func test_projectile_pace() -> void:
	var straight := ProjectilePresenter.new(null, Vector3.ZERO, Vector3(5, 0, 0))
	assert_num(straight.duration, 0.6, "0.12 s per tile")
	assert_num(ProjectilePresenter.new(null, Vector3.ZERO, Vector3(0.5, 0, 0)).duration, 0.12, "never under 0.12")
	assert_num(ProjectilePresenter.new(null, Vector3.ZERO, Vector3(5, 0, 0), 1.5).duration, 0.5, "lobbed")
	assert_num(ProjectilePresenter.new(null, Vector3.ZERO, Vector3(5, 0, 0), 0.0, null, 10.0).duration, 0.5, "speed 10")

func test_move_presenter_slides_and_holds_the_view() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var v := EntityView.new()
	root.add_child(v)
	var p := MovePresenter.new(v, Vector2i(1, 1), Vector2i(2, 1))
	assert_eq(v.animating, 1, "held while it moves")
	_near(Basis(Vector3.UP, v.rotation.y) * Vector3(0, 0, 1), Vector3(1, 0, 0), "faces east")
	p.begin()
	p.tick(0.09)
	_near(v.position, Vector3(1.5, 0, -1), "half way at half time")
	p.tick(0.1)
	assert_true(p.done)
	_near(v.position, Vector3(2, 0, -1), "on the tile")
	assert_eq(v.animating, 0)
	v.free()

# ------------------------------------------------------------------ overlay pieces

func test_banners_of_a_kind_replace_and_the_queue_stays_short() -> void:
	var b := BannerLayer.new()
	b.show_banner("Round 1", 0.8, false, "round")
	b.show_banner("Wave 1 begins", 1.2)
	b.show_banner("Round 2", 0.8, false, "round")
	assert_eq(b.text, "Round 2", "a newer round cuts the showing one short")
	assert_eq(b.waiting, 1)
	for i in 5: b.show_banner("message %d" % i, 1.0)
	assert_eq(b.waiting, BannerLayer.MAX_WAITING)
	b.show_banner("Victory", 1.0, true)
	assert_eq(b.text, "Victory")
	assert_eq(b.waiting, 0)
	b.show_banner("Round 3", 0.8, false, "round")
	assert_eq(b.text, "Victory", "nothing replaces a sticky banner")
	b.free()

func test_plate_slot_order() -> void:
	var make := func(n: String, tags: Array, shield := 0) -> StatusView:
		var d := StatusDef.new()
		d.name = n
		for t in tags: d.tags.append(t)
		var v := StatusView.new()
		v.def = d
		v.name = n
		v.shield = shield
		return v
	var list := [make.call("Haste", ["Buff"]), make.call("Burn", ["Debuff", "Fire"]), make.call("Rooted", ["Rooted"]),
		make.call("Shield", ["Buff"], 5), make.call("Acid", ["Poison"]), make.call("Rallied", ["Buff"])]
	var names := []
	for s in OverlayStyle.ordered_statuses(list): names.append(s.name)
	assert_seq(names, ["Shield", "Rooted", "Acid", "Burn", "Rallied", "Haste"], "defensive, control, DoT (newest first), rest")

func test_vfx_kit_reads_the_43_effects() -> void:
	assert_eq(VfxKit.names().size(), 43)
	assert_eq(VfxKit.effect_name("Assets/Art/VFX/Kit/Hit Spark.prefab"), "Hit Spark")
	assert_eq(VfxKit.effect_name(""), "")
	var fx := VfxKit.build("Cannon Blast")
	assert_not_null(fx)
	assert_eq(fx.get_child_count(), 7, "one emitter per layer")
	assert_true(fx.get_child(0) is CPUParticles3D)
	assert_false(fx.get_meta("loop"))
	fx.free()
	var loop := VfxKit.loop("Burn Loop")
	assert_true(loop.get_meta("loop"))
	assert_false((loop.get_child(0) as CPUParticles3D).one_shot)
	loop.free()
	assert_null(VfxKit.build("No Such Effect"))

func test_presentation_timings_from_content() -> void:
	var lib := ContentLibrary.load("res://data/content")
	var t := PresentationTimings.from_library(lib)
	assert_num(t.wave_banner, 1.2)
	assert_num(t.health_bar_after_hit, 1.5)
	assert_eq(t.spawn_vfx, "Spawn Pop")
	assert_eq(t.collision_vfx, "Collision Thud")

# ------------------------------------------------------------------ a level through the Director

func test_level_plays_through_default_presenters() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var lib := ContentLibrary.load("res://data/content")
	var convert := AssetConverter.new()
	var level_asset: LevelAsset = null
	for l in lib.all_of("LevelAsset"):
		if l.get_id() == "chapter1-1": level_asset = l
	var archer: TowerAsset = null
	for t in lib.all_of("TowerAsset"):
		if t.get_id() == "archer": archer = t
	var hand := [convert.tower(archer, "a1"), convert.tower(archer, "a2")]
	var session := LevelSession.new(convert.level(level_asset), convert.rules(lib.rules), hand, 7)
	var recorder := FrameRecorder.of_session(session)
	var world := Node3D.new()
	root.add_child(world)
	var views := EntityViews.new(world, func(id):
		var e: Entity = session.state.get_entity(id)
		var a = convert.asset_of(e.def, "EntityAsset") if e != null else null
		var p := ArtPaths.model(a.view) if a != null else ""
		return load(p) if p != "" and ResourceLoader.exists(p) else null)
	var overlay := BattleOverlay.new()
	root.add_child(overlay)
	var cam := BoardCamera.new()
	world.add_child(cam)
	cam.init(session.state.grid.width, session.state.grid.height)
	overlay.setup(cam)
	var factory := DefaultPresenters.new(views, overlay, session.state, world)
	factory.presentation_of = func(ability):
		var a = convert.asset_of(ability, "AbilityAsset")
		return a.presentation if a != null else null
	var director := Director.new(session.log, factory, recorder)
	director.beat_ended.connect(func(beat): views.sync(beat.frame))
	director.instant = true
	session.start()
	var placed := 0
	for y in session.state.grid.height:
		for x in session.state.grid.width:
			if placed < 2 and session.can_place(hand[placed].id, Vector2i(x, y)):
				session.place(hand[placed].id, Vector2i(x, y))
				placed += 1
	for r in 6:
		if session.is_over: break
		for unit in session.player_units:
			for a in unit.abilities:
				if a.targeting.is_movement or not session.can_cast(unit, a): continue
				var aim = Instinct.quick_cast(session.state, unit, a)
				if aim != null: session.cast(unit, a, aim)
		session.end_round()
		director.tick(0.016)
	director.finish_all()
	views.sync(director.shown)
	assert_eq(placed, 2)
	assert_false(director.busy)
	for f in director.shown.entities.values():
		var v := views.get_view(f.id)
		assert_not_null(v, "a view for %s" % f.name)
		if v != null and f.position != null: assert_eq(GridSpace.to_tile(v.position), f.pos, "%s on its tile" % f.name)
	recorder.detach()
	overlay.free()
	world.free()
