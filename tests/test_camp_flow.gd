extends TestCase
## The Camp v2 layout (art/camp/v2/layout.json: the Smithy and the Guild hall as buildings, closed before Chapter 2,
## open after it with a button and a door hotspot), the Chapter 2 gate (Eren 2026-10-15), the post-Chapter-2 mini tour flag, the
## SceneFlow slide's pose, and the layout editor (TdLayoutEditor) on a live Camp: select, move with snapping,
## turn, scale, delete decor, and the saved layout keeping the schema. Uses its own save path (restored after).

var _sd
var _old_data
var _old_path := ""
var holder: Node

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func setup() -> void:
	_sd = _tree().root.get_node("SaveData")
	_old_data = _sd.data
	_old_path = _sd.path
	_sd.path = "user://test_camp_flow.json"
	_sd.data = GameData.new()
	_sd.profile.create("Tester")
	_sd.profile.camp_seen = true
	holder = Node.new()
	_tree().root.add_child(holder)

func teardown() -> void:
	holder.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_sd.path))
	_sd.data = _old_data
	_sd.path = _old_path

func _chapters(n: int) -> void:
	DevShortcuts.complete_main_chapters(_sd.data, _tree().root.get_node("GameApp").catalog, n)

func _camp() -> Control:
	var c: Control = load("res://game/ui/screens/camp.tscn").instantiate()
	holder.add_child(c)
	return c

func test_camp_v2_layout() -> void:
	var layout: Dictionary = load("res://game/ui/screens/camp.gd").load_layout()
	assert_eq(layout.kits, ["camp/v2", "camp", "tiles"])
	assert_eq(layout.ring.centre, [6.5, 5.0], "the camera target (the chimney smoke in frame)")
	var by_station := {}
	for s in layout.slots: by_station[str(s.station)] = s
	assert_eq(by_station.keys().size(), 5)
	for id in ["Chapters", "Towers", "Codex", "Blacksmith", "Guild"]: assert_true(by_station.has(id), id)
	for id in ["Blacksmith", "Guild"]:
		var s: Dictionary = by_station[id]
		assert_true(s.has("prop_closed") and s.has("unlock"), "%s is a building with a closed facade" % id)
		assert_eq(s.hotspot, "door")
		assert_eq(s.door.size_local.size(), 2)
	assert_eq(by_station["Guild"].prop, "Guild Hall Facade Open")
	assert_eq(by_station["Blacksmith"].prop_closed, "Smithy Facade Closed")
	for s in layout.slots:
		assert_eq(s.row, "front", "every button on the floor in front of its prop / door")
		assert_ne(s.station, "Multiplayer", "no Multiplayer in the Camp")
	assert_eq(load("res://game/ui/screens/camp.gd").STATION_ALIASES["Blacksmith"], "Workshop", "the Smithy keeps the Workshop id")

func _shown_prop(c: Control, id: String) -> String:
	for e in c.world.entries:
		if e.kind == "slot" and e.node == c.props.get(id): return e.prop
	return ""

func test_camp_closed_buildings_before_chapter2() -> void:
	_chapters(1)
	var c := _camp()
	assert_true(c.buttons["Chapters"].visible)
	assert_false(c.buttons["Guild"].visible, "no Guild button before Chapter 2 (not greyed: hidden)")
	assert_false(c.buttons["Workshop"].visible, "no Workshop button before Chapter 2")
	assert_not_null(c.props.get("Guild"), "the Guild hall stands there, closed")
	assert_not_null(c.props.get("Workshop"), "the Smithy stands there, closed")
	assert_true(c.is_closed("Guild") and c.is_closed("Workshop"))
	assert_eq(_shown_prop(c, "Guild"), "Guild Hall Facade Closed")
	assert_eq(_shown_prop(c, "Workshop"), "Smithy Facade Closed")
	assert_true(c.hotspots.is_empty(), "no door hotspot while closed")
	assert_null(c.guild_tag)
	assert_false(c.open_tour_due())
	c.show_tour_step(0)
	var ids := []
	while c.tour_step >= 0:
		ids.append(c.tour[c.tour_step][0])
		c.show_tour_step(c.tour_step + 1)
	assert_eq(ids, ["Chapters", "Towers", "Codex"], "the first tour skips the closed buildings")

func test_camp_shows_guild_after_chapter2_with_new_tag_and_mini_tour() -> void:
	_chapters(2)
	_sd.profile.guild_tour_seen = true # not started by _ready (it waits two frames; the test runs synchronously)
	var c := _camp()
	_sd.profile.guild_tour_seen = false
	var g: TdMenuButton = c.buttons["Guild"]
	assert_true(g.visible)
	assert_true(c.buttons["Workshop"].visible)
	assert_false(c.is_closed("Guild") or c.is_closed("Workshop"), "the doors open after Chapter 2")
	assert_eq(_shown_prop(c, "Guild"), "Guild Hall Facade Open")
	assert_eq(_shown_prop(c, "Workshop"), "Smithy Facade Open")
	assert_true(c.hotspots.has("Guild") and c.hotspots.has("Workshop"), "each open door is a hotspot")
	assert_null(TdTooltipTrigger.find_on(c.hotspots["Guild"]), "a door hotspot has no tooltip")
	for id in ["Chapters", "Towers", "Codex", "Workshop", "Guild"]:
		assert_eq(c.buttons[id].sub, "", "no line under %s" % id)
	assert_eq(g.text, "Guild")
	assert_not_null(c.guild_tag, "a New tag on the button until the first Guild visit")
	assert_eq(c.guild_tag.get_parent(), g)
	assert_true(c.open_tour_due())
	c.start_open_tour()
	assert_true(_sd.profile.guild_tour_seen)
	assert_eq(c.tour, c.TOUR_OPEN)
	assert_eq(c.tour[c.tour_step][0], "Guild")
	assert_true(g.selected)
	c.show_tour_step(c.tour_step + 1)
	assert_eq(c.tour[c.tour_step][0], "Workshop")
	c.show_tour_step(c.tour_step + 1)
	assert_eq(c.tour_step, -1)
	assert_false(c.open_tour_due(), "only once")

func test_camp_no_new_tag_once_the_guild_was_seen() -> void:
	_chapters(2)
	_sd.profile.guild_seen = true
	var c := _camp()
	assert_null(c.guild_tag)
	assert_false(c.open_tour_due(), "the Guild already visited: no mini tour")

func test_profile_guild_tour_seen_round_trip() -> void:
	var p := PlayerProfile.new()
	p.guild_tour_seen = true
	assert_true(GameData.profile_from_dict(GameData.profile_to_dict(p)).guild_tour_seen)
	assert_false(GameData.profile_from_dict({}).guild_tour_seen, "old saves: not seen")

func test_flow_slide_pose() -> void:
	var a := Control.new()
	var b := Control.new()
	holder.add_child(a)
	holder.add_child(b)
	var flow = _tree().root.get_node("SceneFlow")
	flow._slide_pose(a, b, 1000.0, 1, 0.0)
	assert_num(a.position.x, 0.0)
	assert_num(b.position.x, 1000.0, "the new scene starts off-screen right")
	flow._slide_pose(a, b, 1000.0, 1, 0.5)
	assert_true(a.position.x < -500.0 and a.position.x > -1000.0, "ease out: past halfway at half time")
	assert_num(b.position.x - a.position.x, 1000.0, "both move together (no gap, no overlap)")
	flow._slide_pose(a, b, 1000.0, 1, 1.0)
	assert_num(a.position.x, -1000.0)
	assert_num(b.position.x, 0.0)
	flow._slide_pose(a, b, 1000.0, -1, 0.25)
	assert_true(a.position.x > 0.0 and b.position.x < 0.0, "dir -1: the old scene leaves to the right")
	assert_false(flow.is_sliding)

func test_layout_editor_moves_turns_scales_and_saves_the_schema() -> void:
	_chapters(2)
	_sd.profile.guild_tour_seen = true
	var c := _camp()
	assert_true(TdLayoutEditor.can_edit(c))
	assert_false(TdLayoutEditor.can_edit(Control.new()))
	var ed := TdLayoutEditor.new()
	holder.add_child(ed)
	assert_true(ed.start(c))
	assert_eq(ed.place_name(), "Camp")
	var guild_e := {}
	var tent_e := {}
	for e in c.world.entries:
		if e.kind == "slot" and e.node == c.props["Guild"]: guild_e = e
		if e.kind == "decor" and e.prop == "Tent": tent_e = e
	assert_false(guild_e.is_empty(), "the Guild hall is a slot entry")
	assert_false(tent_e.is_empty())
	ed.select(guild_e)
	ed.move_selected(Vector2(10.13, 3.4))
	assert_eq(TdLayoutEditor.prop_tile(c.props["Guild"]), Vector2(10.25, 3.5), "snapped to 0.25")
	ed.move_selected(Vector2(10.13, 3.4), true)
	assert_true(TdLayoutEditor.prop_tile(c.props["Guild"]).distance_to(Vector2(10.13, 3.4)) < 0.001, "free with Shift")
	ed.rotate_selected(15.0)
	ed.scale_selected(0.1)
	assert_num(snappedf(c.props["Guild"].scale.x, 0.01), 2.9)
	assert_true(ed.dirty)
	ed.select(guild_e)
	assert_false(ed.delete_selected(), "stations cannot be removed")
	ed.select(tent_e)
	assert_true(ed.delete_selected())
	var out: Dictionary = ed.current_layout()
	var s1: Dictionary = {}
	for s in out.slots:
		if int(s.slot) == 1: s1 = s
	assert_eq(s1.station, "Guild", "stations keep their slot ids")
	assert_eq(s1.tile, [10.13, 3.4])
	assert_num(s1.face_yaw, 15.0)
	assert_num(s1.scale, 2.9)
	assert_eq(s1.row, "front")
	assert_eq(s1.prop, "Guild Hall Facade Open", "the open / closed props kept")
	assert_eq(s1.prop_closed, "Guild Hall Facade Closed")
	assert_true(s1.has("door") and s1.has("unlock"), "door and unlock kept")
	assert_true(s1.has("note"), "notes kept")
	assert_eq(out.slots.size(), 5)
	assert_eq(out.decor.map(func(d): return d.prop), ["Camp Paths", "Hills Backdrop", "Camp Trees", "Camp Trees", "Signpost"], "the deleted decor is gone")
	assert_eq(out.kits, ["camp/v2", "camp", "tiles"], "kits kept")
	assert_eq(out.board.tiles, [14, 10], "whole numbers stay ints")
	assert_true(out.has("ring") and out.has("centre"))
	assert_eq(out.centre.prop, "Campfire")
	# saved somewhere harmless: the real layout.json is never written by the test
	ed.layout_path = "user://test_layout_camp.json"
	var p := ed.save()
	assert_eq(p, "user://test_layout_camp.json")
	var back = JSON.parse_string(FileAccess.get_file_as_string(p))
	assert_true(back is Dictionary and back.has("slots") and back.decor.size() == 5)
	assert_false(ed.dirty)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	ed.free()
