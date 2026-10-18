extends SceneTree
## Dev script (Eren's hand editor corrections, 2026-10-17): renders and checks
##  - the mission detail → hand editor opened for a mission with 0 and with 1 tower in the hand (the window must keep
##    its size: prints "SIZE 0 …" / "SIZE 1 …" and CHECK lines), with a tired tower (not in the mission strip),
##  - the Filters popup, the mission detail, the mission board,
##  - the Upgrade view with 0 gold (the × and the Backpack button's fixed width), the Workshop Modify view (×, no
##    legend / caption / Leads to / cost rows),
##  - mouse drag-to-scroll on every visible ScrollContainer of those screens (the DragScroll autoload) and a real
##    drag on the scrollable ones.
##   cd ~/godot && GODOT_TIMEOUT=600 ./jobs.sh --render shot --resolution 1280x720 tools/hand2_shot.gd -- <out dir>
## Own save (user://hand2_shot.json, deleted first). PNGs <out dir>/hand2_<n>_<step>.png. Ends with "HAND2 n fails".

var out_dir := "user://hand2"
var _n := 0
var fails := 0
var save
var app

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir) if out_dir.begins_with("user://") else out_dir)
	_run.call_deferred()

func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1
	print("CHECK %s %s" % ["OK" if ok else "FAIL", what])

func _run() -> void:
	save = root.get_node("SaveData")
	app = root.get_node("GameApp")
	save.path = "user://hand2_shot.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	app.ensure_loaded()
	_win_main(1, 99)
	_win_main(2, 99)
	save.profile.camp_seen = true
	var by_type := {}
	for pair in [["archer", 4], ["guardian", 3], ["mage", 2], ["priest", 3], ["drummer", 3], ["wisp", 2], ["cannon", 2]]:
		by_type[pair[0]] = []
		for i in pair[1]: by_type[pair[0]].append(save.towers.add(pair[0]))
	for t in app.catalog.tower_types:
		if not by_type.has(t.get_id()):
			by_type[t.get_id()] = [save.towers.add(t.get_id())]
	save.towers.hand.clear()
	save.data.ensure_layouts()
	save.data.gold = 0
	save.save()
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	TdMenu.menu_background(host)
	# the mission board, then Patrol's detail with an empty hand
	var board: TdPopup = load("res://game/ui/screens/mission_board.gd").new()
	board.free_on_close = true
	host.add_child(board)
	board.open()
	await _boards()
	await _shot("mission_board")
	_scroll_checks("mission_board", board)
	var d = board.open_detail("patrol")
	await _boards()
	await _shot("detail_empty_hand")
	# the hand editor for the mission: 0 towers, then 1
	var he = d.open_hand_editor()
	await _frames(40)
	var s0: Vector2 = he.window.size
	var tray0: Vector2 = he._tray_panel.size
	var head0: float = he._cap_label.get_parent().size.y
	print("SIZE 0 window ", s0, " strip ", tray0)
	await _shot("editor_0_towers")
	he.add(by_type["drummer"][1].id)
	await _frames(20)
	var s1: Vector2 = he.window.size
	print("SIZE 1 window ", s1, " strip ", he._tray_panel.size)
	await _shot("editor_1_tower")
	_check(s0 == s1, "adding a tower keeps the window size (%s → %s)" % [s0, s1])
	_check(tray0 == he._tray_panel.size, "and the strip's size (%s → %s)" % [tray0, he._tray_panel.size])
	_check(is_equal_approx(head0, he._cap_label.get_parent().size.y), "and the header's height")
	he.remove(by_type["drummer"][1].id)
	await _frames(20)
	_check(he.window.size == s0, "removing it again: the same size")
	# a fuller hand with a tired tower: not in the mission strip, still in the collection with its moon badge
	for o in [by_type["archer"][0], by_type["guardian"][1], by_type["priest"][0], by_type["drummer"][1], by_type["mage"][0]]:
		he.add(o.id)
	save.missions.tire(by_type["guardian"][1].id, MissionBoard.day_of())
	he.refresh()
	he._select(by_type["drummer"][1].id)
	await _frames(20)
	_check(he.window.size == s0, "5 towers, one tired: the same size (%s)" % [he.window.size])
	var shown: Array = he._slots.filter(func(sl): return sl.tower_id != "").map(func(sl): return sl.tower_id)
	_check(not shown.has(by_type["guardian"][1].id) and shown.size() == 4, "the mission strip shows only rested towers (%d)" % shown.size())
	await _shot("editor_mission_tired")
	_scroll_checks("hand_editor", he)
	await _drag_check("hand_editor detail", he._detail.get_child(0))
	# the Filters popup
	he.collection.filter.roles = ["Support"]
	he.collection.filter.heal = true
	he.collection.refresh()
	var fp = he.collection.open_filters()
	await _frames(30)
	await _shot("filters_popup")
	_scroll_checks("filters_popup", fp)
	var fsc := _scrolls(fp)
	if not fsc.is_empty(): await _drag_check("filters popup", fsc[0])
	fp.close()
	await _frames(20)
	he.close()
	await _frames(20)
	d.refresh()
	await _frames(10)
	await _shot("detail_rested_only")
	d.close()
	await _frames(10)
	board.close()
	await _frames(10)
	# the Upgrade view with 0 gold
	var up: TdPopup = load("res://game/ui/screens/upgrade.tscn").instantiate()
	host.add_child(up)
	up.open()
	await _frames(30)
	_scroll_checks("upgrade picker", up)
	var bw0: float = up.pick_backpack.size.x
	up.open_view(by_type["archer"][1].id)
	await _frames(30)
	await _shot("upgrade_view_0_gold")
	_scroll_checks("upgrade view", up)
	save.data.gold = 240
	TdBackpackButton.refresh_all(self)
	await _frames(5)
	_check(is_equal_approx(up.backpack_button.size.x, bw0) or up.backpack_button.size.x == up.pick_backpack.size.x, "the Backpack button keeps its width from 0 to 240 gold (%.0f / %.0f)" % [bw0, up.backpack_button.size.x])
	print("BACKPACK width 0 gold ", bw0, " / 240 gold ", up.backpack_button.size.x)
	up.close()
	await _frames(20)
	# the Workshop picker and Modify view
	var ws: TdPopup = load("res://game/ui/screens/workshop.tscn").instantiate()
	host.add_child(ws)
	ws.open()
	await _frames(30)
	_scroll_checks("workshop picker", ws)
	ws.open_modify(by_type["guardian"][0].id)
	await _frames(30)
	await _shot("workshop_modify")
	_scroll_checks("workshop modify", ws)
	for sc in _scrolls(ws): await _drag_check("workshop modify " + str(sc.get_path()).get_file(), sc)
	ws.close()
	await _frames(20)
	# the Backpack and the Codex
	var bp = load("res://game/ui/screens/backpack.gd").show_over(host)
	await _frames(30)
	_scroll_checks("backpack", bp)
	bp.close()
	await _frames(20)
	var cx: TdPopup = load("res://game/ui/screens/codex.tscn").instantiate()
	host.add_child(cx)
	cx.open()
	await _frames(30)
	_scroll_checks("codex", cx)
	cx.close()
	await _frames(10)
	print("HAND2 %d fails" % fails)
	quit()

# ------------------------------------------------------------------ drag scroll

func _scrolls(root_node: Node) -> Array:
	var out := []
	var stack := [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is ScrollContainer and n.is_visible_in_tree() and n.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			out.append(n)
		for c in n.get_children(): stack.append(c)
	return out

## Every visible vertical scroll has the drag-to-scroll (TdDragScroll, given by the DragScroll autoload).
func _scroll_checks(screen: String, root_node: Node) -> void:
	var all := _scrolls(root_node)
	var missing := all.filter(func(s): return not s.has_meta(TdDragScroll.META))
	_check(missing.is_empty(), "%s: %d scroll areas, all drag-scroll %s" % [screen, all.size(), "" if missing.is_empty() else str(missing.map(func(s): return str(s.get_path())))])

var _last := Vector2.ZERO

func _motion(p: Vector2, held: bool) -> void:
	var m := InputEventMouseMotion.new()
	m.relative = p - _last
	_last = p
	m.position = p
	m.global_position = p
	m.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.warp_mouse(p)
	Input.parse_input_event(m)
	await _frames(2)

func _button(p: Vector2, pressed: bool) -> void:
	var b := InputEventMouseButton.new()
	b.position = p
	b.global_position = p
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = pressed
	b.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(b)
	await _frames(2)

## A real mouse drag (press, move 120 px up, release) in a scroll that has something to scroll: it scrolls.
func _drag_check(what: String, sc: ScrollContainer) -> void:
	if sc == null or not sc.is_visible_in_tree(): return
	await _frames(2)
	if sc.get_v_scroll_bar().max_value <= sc.size.y + 1:
		print("SKIP %s: nothing to scroll" % what)
		return
	sc.scroll_vertical = 0
	await _frames(2)
	var r := sc.get_global_rect()
	# canvas → viewport (the content scale)
	var xf := sc.get_viewport().get_final_transform()
	var a: Vector2 = xf * Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.7)
	var b := a - Vector2(0, 120)
	await _motion(a, false)
	await _button(a, true)
	for i in range(1, 11): await _motion(a.lerp(b, i / 10.0), true)
	await _button(b, false)
	await _frames(4)
	_check(sc.scroll_vertical > 0, "%s: a mouse drag scrolls it (scroll %d)" % [what, sc.scroll_vertical])

# ------------------------------------------------------------------ helpers

func _win_main(n: int, count: int) -> void:
	var k := 0
	for ch in app.catalog.chapters:
		if ch == null or ch.kind != ChapterKind.Main: continue
		k += 1
		if k != n: continue
		var i := 0
		for e in ch.levels:
			if i >= count: break
			var r := LevelResult.new()
			r.level_id = e.level.get_id()
			r.won = true
			save.progress.record(r)
			i += 1

func _until(cond: Callable, seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await process_frame

func _frames(n: int) -> void:
	for i in n: await process_frame

func _boards() -> void:
	await _frames(3)
	await _until(func(): return CoopBoardPic._queue.is_empty() and not CoopBoardPic._busy, 120.0)
	await _frames(4)

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var p := "%s/hand2_%02d_%s.png" % [out_dir, _n, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p))
