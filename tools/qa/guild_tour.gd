extends SceneTree
## UI QA tour of the Workshop, the Guild, the Mission board / detail, the hand editor for a mission and the co-op
## screens (FakeRelay bots). Opens every screen through the real flow (Camp → stations) with real mouse / key events,
## hovers and clicks every visible clickable control, takes screenshots and runs the layout checks of guild_qa.gd.
##   /home/ubuntu/godot/jobs.sh --render shot [--resolution 1280x720] tools/qa/guild_tour.gd -- <out dir> [sections] [tag]
##   sections: comma list of camp,guild,board,detail,hand,workshop,coop,play (default: all); tag: file prefix (1080/720)
## Its own save (user://guild_tour.json, deleted first): the guild_shot collection (5-tower hand), tokens, Chapters 1–2
## won (Workshop + Guild open), Night Watch won and played today.

const QA := preload("res://tools/qa/guild_qa.gd")

var qa
var out_dir := "user://qa_guild"
var sections: PackedStringArray = []
var save
var app
var flow
var by_type := {}
var net: RelayClient
var relay: FakeRelay
## Screens the crawler's lambdas reopen (lambdas capture locals by value: members are shared).
var cur := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	if args.size() > 1 and args[1] != "all": sections = args[1].split(",")
	var t := "1080"
	if args.size() > 2: t = args[2]
	elif DisplayServer.window_get_size().x < 1500: t = "720"
	qa = QA.new(self, out_dir, t)
	if args.has("quick"): qa.quick_max = 22
	_run.call_deferred()
	_watchdog.call_deferred()

## A script error stops only its coroutine (the tour would hang until the timeout): no shot / finding for 6 min → done.
func _watchdog() -> void:
	while true:
		await create_timer(20.0, true, false, true).timeout
		if Time.get_ticks_msec() / 1000.0 - qa.last_progress > 360.0:
			qa.progress("WATCHDOG: no progress for 6 min, finishing")
			qa.finish()
			quit()
			return

func want(s: String) -> bool:
	return sections.is_empty() or sections.has(s)

func _run() -> void:
	save = root.get_node("SaveData")
	app = root.get_node("GameApp")
	flow = root.get_node("SceneFlow")
	await qa.until(func(): return flow.current != flow.Boot and not flow.is_loading and current_scene != null, 60.0)
	await qa.wait(10, 0.5)
	_setup_save()
	note("window ", DisplayServer.window_get_size(), " visible ", root.get_visible_rect(), " final ", root.get_final_transform())
	if want("camp"): await tour_camp()
	if want("guild"): await tour_guild()
	if want("board"): await tour_board()
	if want("detail"): await tour_detail()
	if want("hand"): await tour_hand()
	if want("workshop"): await tour_workshop()
	if want("coop"): await tour_coop()
	if want("play"): await tour_play()
	if sections.has("verify"): await tour_verify()
	if sections.has("abuse"): await tour_abuse()
	qa.finish()
	quit()

# ------------------------------------------------------------------ save

func _setup_save() -> void:
	save.path = "user://guild_tour.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	save.begin("Eren", false)
	app.ensure_loaded()
	var counts := {"archer": 6, "guardian": 5, "mage": 4, "priest": 5, "wisp": 4, "ballista": 3, "alchemist": 3}
	save.towers.hand.clear()
	for t in app.catalog.tower_types:
		by_type[t.get_id()] = []
		for i in counts.get(t.get_id(), 2):
			by_type[t.get_id()].append(save.towers.add(t.get_id()))
	for pick in [["archer", 0], ["archer", 1], ["guardian", 0], ["priest", 0], ["mage", 0]]:
		save.towers.add_to_hand(by_type[pick[0]][pick[1]].id)
	for pair in [["fire-arrow", 2], ["yew-bow", 1], ["steel-plate", 1], ["arcane-shard", 3]]:
		SaveTools.run("add_tokens", save.data, app.catalog, pair)
	_win_main(1, 99)
	_win_main(2, 99)
	save.profile.camp_seen = true
	var nw: MissionDef = app.mission("night-watch")
	var r := LevelResult.new()
	r.level_id = nw.level_id
	r.won = true
	r.rounds = 9
	r.base_hp_pct = 80
	save.missions.record(r, nw.id)
	MissionBoard.record_play(nw, save.missions, [])
	save.save()

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

# ------------------------------------------------------------------ navigation

func go_scene(id: int) -> Node:
	for attempt in 4:
		await qa.until(func(): return not flow.is_loading, 60.0)
		await qa.frames(2)
		flow.go(id)
		if await qa.until(func(): return flow.current == id and not flow.is_loading and current_scene != null and current_scene.scene_file_path.get_file().get_basename() == flow.FILES[id], 60.0): break
	await qa.wait(30, 1.0)
	return current_scene

func goto_camp() -> Node:
	return await go_scene(flow.Camp)

func goto_guild(welcome := false) -> Node:
	save.profile.guild_seen = not welcome
	save.save()
	var g = await go_scene(flow.Guild)
	return g

# ------------------------------------------------------------------ Camp: the Signpost

func tour_camp() -> void:
	qa.screen = "Camp signpost"
	# locked: Chapter 2 not cleared (results kept aside, put back after)
	var camp = await goto_camp()
	qa.step = "unlocked"
	await qa.shot("camp")
	qa.audit(camp, "camp", "")
	var sp: Control = camp.signpost
	if sp == null:
		qa.find("bug", "Camp.signpost", "no signpost hotspot")
		return
	qa.move(qa.centre(sp))
	await qa.wait(6, 0.7)
	qa.check_tooltip("Signpost")
	await qa.shot("camp_signpost_hover")
	qa.park_mouse()
	await qa.wait(4, 0.4)
	qa.check_unhovered(sp, "Signpost")
	# the gold New tag while the guild was never seen
	if camp.signpost_tag == null: qa.find("data", "Signpost New tag", "missing before the first Guild visit")
	# click: the Guild (welcome card)
	save.profile.guild_seen = false
	await qa.click_at(qa.centre(sp))
	await qa.until(func(): return flow.current == flow.Guild and not flow.is_loading, 60.0)
	await qa.wait(30, 1.0)
	qa.step = "after click"
	if flow.current != flow.Guild: qa.find("bug", "Signpost click", "did not open the Guild")
	await qa.shot("guild_from_signpost")

# ------------------------------------------------------------------ the Guild

func tour_guild() -> void:
	qa.screen = "Guild"
	var g = await goto_guild(true)
	qa.step = "welcome"
	await qa.wait(10, 0.8)
	var s: String = await qa.shot("guild_welcome")
	qa.audit(g.welcome_card, "welcome", s)
	if not g.welcome_card.visible: qa.find("data", "welcome card", "not shown on the first visit")
	# hover the OK button, then Space closes it
	await qa.crawl(func(): return g.welcome_card if g.welcome_card.visible else null, "guild_welcome", {"hover_only": func(_c): return true})
	await qa.key(KEY_SPACE)
	await qa.wait(6, 0.4)
	qa.step = "welcome closed by Space"
	if g.welcome_card.visible: qa.find("esc", "welcome card", "Space does not close it")
	if not save.profile.guild_seen: qa.find("data", "welcome card", "guild_seen not saved after closing")
	s = await qa.shot("guild")
	qa.audit(g, "guild", s)
	# every station / hotspot: hover, click (each opens a popup: Esc back); the door and ← Camp leave the scene
	var leaves := func(c): return c == g.camp_button or c == g.door
	await qa.crawl(func(): return g if is_instance_valid(g) else null, "guild", {"hover_only": leaves})
	# the door: hover highlight + tooltip, click → Camp
	qa.step = "door"
	qa.move(qa.centre(g.door))
	await qa.wait(6, 0.7)
	qa.check_tooltip("Guild Door")
	await qa.shot("guild_door_hover")
	await qa.click_at(qa.centre(g.door))
	await qa.until(func(): return flow.current == flow.Camp and not flow.is_loading, 60.0)
	await qa.wait(20, 0.6)
	if flow.current != flow.Camp: qa.find("bug", "Guild Door", "click did not go back to the Camp")
	await qa.shot("door_to_camp")
	# ← Camp
	g = await goto_guild()
	qa.step = "← Camp"
	await qa.click_at(qa.centre(g.camp_button))
	await qa.until(func(): return flow.current == flow.Camp and not flow.is_loading, 60.0)
	await qa.wait(20, 0.6)
	if flow.current != flow.Camp: qa.find("bug", "← Camp", "click did not go back to the Camp")
	# Esc in the Guild with nothing open: should not trap; (the Guild has no Esc action: note it)
	g = await goto_guild()
	qa.step = "Esc on the bare Guild"
	await qa.key(KEY_ESCAPE)
	await qa.wait(10, 0.6)
	await qa.shot("guild_esc")

# ------------------------------------------------------------------ helpers

## Freezes the 3D views (station world SubViewports) under a node: popups over the Guild render much faster.
## The last frame stays on screen (UPDATE_DISABLED keeps the texture).
func freeze_world(n: Node, on: bool) -> void:
	if n == null or not is_instance_valid(n): return
	for v in n.find_children("*", "SubViewport", true, false):
		if v.get_parent() is SubViewportContainer and v.get_parent().get_parent() is TdStationWorld or _under_world(v):
			v.render_target_update_mode = SubViewport.UPDATE_DISABLED if on else SubViewport.UPDATE_ALWAYS

func _under_world(v: Node) -> bool:
	var p := v.get_parent()
	while p != null:
		if p is TdStationWorld: return true
		p = p.get_parent()
	return false

## Waits for the queued board pictures (CoopBoardPic) to render.
func boards() -> void:
	await qa.frames(3)
	await qa.until(func(): return CoopBoardPic._queue.is_empty() and not CoopBoardPic._busy, 120.0)
	await qa.wait(4, 0.3)

## A visible control under `root` whose shown text is `text` (TdButton text, Label, Button), or null.
func find_text(root: Node, text: String, type := "") -> Control:
	for c in QA.visible_controls(root):
		if type != "" and not c.is_class(type) and not (c.get_script() != null and c.get_script().get_global_name() == type): continue
		if c is TdButton and str(c.text) == text: return c
		if c is Button and c.text == text: return c
		if c is Label and c.text == text: return c
	return null

func texts_under(root: Node) -> String:
	var s := []
	for c in QA.visible_controls(root):
		if c is Label and c.text != "": s.append(c.text)
		elif c is RichTextLabel and c.get_parsed_text() != "": s.append(c.get_parsed_text())
		elif c is TdButton and str(c.text) != "": s.append(str(c.text))
	return " | ".join(s)

func top_popup() -> TdPopup:
	return TdPopup.open_popups.back() if not TdPopup.open_popups.is_empty() else null

## Opens the mission board from the Guild with a real click on the Missions station.
func open_board(g) -> TdPopup:
	await qa.click_at(qa.centre(g.stations["Missions"]))
	await qa.wait(10, 0.6)
	await boards()
	if g.board == null or not g.board.is_open: qa.find("bug", "Missions station", "click did not open the board")
	return g.board

func shot_audit(label: String, root: Node) -> String:
	var s: String = await qa.shot(label)
	qa.audit(root, label, s)
	return s

# ------------------------------------------------------------------ the mission board

func tour_board() -> void:
	qa.screen = "Mission board"
	var g = await goto_guild()
	var b = await open_board(g)
	if b == null: return
	freeze_world(g, true)
	qa.step = "open"
	await shot_audit("board", b)
	# Play on a card launches a level (tested in the play section); × closes the board (reopened)
	var is_play := func(c): return c is TdButton and str(c.text) == "Play"
	await qa.crawl(func(): return g.board if g.board != null and g.board.is_open else null, "board",
		{"hover_only": is_play, "max": 60, "reopen": func():
			await open_board(g)
			freeze_world(g, true)})
	# Esc closes the board
	qa.step = "Esc"
	if g.board == null or not g.board.is_open: await open_board(g)
	await qa.key(KEY_ESCAPE)
	await qa.wait(8, 0.5)
	if g.board != null and g.board.is_open: qa.find("esc", "board", "Esc does not close the board")
	# right click closes too
	await open_board(g)
	await qa.click_at(Vector2(960, 540), MOUSE_BUTTON_RIGHT)
	await qa.wait(8, 0.5)
	if g.board != null and g.board.is_open: qa.find("esc", "board", "right click does not close the board")

# ------------------------------------------------------------------ the mission detail (every state)

func open_detail_by_click(g, mission_id: String) -> TdPopup:
	var b = g.board if g.board != null and g.board.is_open else await open_board(g)
	var card: Control = b.cards.get(mission_id)
	if card == null:
		qa.find("bug", "board card " + mission_id, "no card")
		return null
	var sc := QA.scroll_parent(card)
	if sc != null:
		sc.ensure_control_visible(card)
		await qa.frames(3)
	# click the card's picture corner (not its buttons)
	var r := QA.grect(card)
	await qa.click_at(r.position + Vector2(40, 40))
	await qa.wait(10, 0.7)
	await boards()
	if b.detail == null: qa.find("bug", "board card " + mission_id, "click did not open the detail")
	return b.detail

func tour_detail() -> void:
	qa.screen = "Mission detail"
	var g = await goto_guild()
	freeze_world(g, true)
	var d = await open_detail_by_click(g, "patrol")
	if d == null: return
	var hand: Array = save.towers.hand
	qa.step = "normal"
	await shot_audit("detail_normal", d)
	# every control of the normal detail: rows select missions, Change hand / slots open the hand editor (Esc back),
	# Play launches the level (hover only: the play section), ← Missions closes it (reopened)
	var is_play := func(c): return c == d._play
	cur.d = d
	await qa.crawl(func(): return cur.d if is_instance_valid(cur.d) and cur.d.is_open else null, "detail",
		{"hover_only": func(c): return is_instance_valid(cur.d) and c == cur.d._play, "max": 50, "reopen": func():
			cur.d = await open_detail_by_click(g, "patrol")},
		)
	d = cur.d
	if not is_instance_valid(d) or not d.is_open: d = await open_detail_by_click(g, "patrol")
	# states
	var states := [
		["tired", func(): save.missions.tire(hand[1], MissionBoard.day_of()), "patrol"],
		["all_tired", func():
			for id in hand: save.missions.tire(id, MissionBoard.day_of()), "patrol"],
		["done", func(): save.missions.tired.clear(), "night-watch"],
		["coop", func(): pass, "hold-the-gate"],
		["locked", func(): app.mission("glutton-returns").requires = ["hold-the-gate"], "glutton-returns"],
		["empty_hand", func():
			save.towers.hand.clear(), "patrol"],
	]
	var hand_copy := hand.duplicate()
	for st in states:
		qa.step = st[0]
		st[1].call()
		# pick the mission with a real click on its row in the left list
		var row = null
		for r in d._rows:
			if r.get_index() >= 0 and d.missions[d._rows.find(r)].id == st[2]: row = r
		if row != null:
			var sc := QA.scroll_parent(row)
			if sc != null:
				sc.ensure_control_visible(row)
				await qa.frames(3)
			await qa.click_at(qa.centre(row))
		else:
			d.select_mission(st[2])
		d.refresh()
		await qa.wait(8, 0.5)
		await boards()
		if d.mission_id != st[2]: qa.find("bug", "mission row " + st[2], "click did not select it (got %s)" % d.mission_id)
		var s := await shot_audit("detail_" + st[0], d)
		# the primary button: hover (reason when off), click (refused: nothing is spent)
		var plays_before: int = MissionBoard.plays_left(app.mission(st[2]), save.missions) if app.mission(st[2]) != null else -1
		qa.move(qa.centre(d._play))
		await qa.wait(6, 0.6)
		qa.check_tooltip("Play (" + st[0] + ")", s)
		if not d._play.interactable:
			if not TdTooltip.is_visible(): qa.find("data", "Play (" + st[0] + ")", "disabled without a hover reason")
			await qa.shot("detail_%s_play_hover" % st[0])
			await qa.click_at(qa.centre(d._play))
			await qa.wait(6, 0.4)
			if flow.is_loading or flow.current != flow.Guild: qa.find("bug", "Play (" + st[0] + ")", "a disabled Play started something")
			var after: int = MissionBoard.plays_left(app.mission(st[2]), save.missions) if app.mission(st[2]) != null else -1
			if after != plays_before: qa.find("data", "Play (" + st[0] + ")", "plays changed %d → %d on a refused click" % [plays_before, after])
		qa.park_mouse()
		await qa.wait(4, 0.3)
		qa.check_unhovered(d._play, "Play")
		# the board under the detail agrees (state line of the card)
		var card_text := texts_under(g.board.cards.get(st[2])) if g.board != null and g.board.cards.has(st[2]) else ""
		note("STATE ", st[0], " detail: ", texts_under(d._note_row), " || card: ", card_text)
		if st[0] == "coop":
			# Find a room → the lobby with Create room and the mission picked; Esc ×2 back
			var depth := TdPopup.open_popups.size()
			await qa.click_at(qa.centre(d._play))
			await qa.wait(12, 1.0)
			await boards()
			await shot_audit("detail_coop_find_room", qa.top(d))
			var t = top_popup()
			if not (t is CoopCreatePopup): qa.find("data", "Find a room", "the top popup is %s, not Create room" % [QA.describe(t) if t != null else "none"])
			elif t.level_id != app.mission("hold-the-gate").level_id: qa.find("data", "Find a room", "Create room picked %s, not Hold the Gate's level" % t.level_id)
			await qa.esc_back(depth, "Find a room")
	save.towers.hand.assign(hand_copy)
	app.mission("glutton-returns").requires = []
	save.missions.tired.clear()
	save.save()
	# Esc closes the detail back to the board
	qa.step = "Esc"
	d.select_mission("patrol")
	await qa.wait(4, 0.2)
	var depth := TdPopup.open_popups.size()
	await qa.key(KEY_ESCAPE)
	await qa.wait(8, 0.5)
	if TdPopup.open_popups.size() >= depth: qa.find("esc", "detail", "Esc does not close the detail")
	elif top_popup() != g.board: qa.find("esc", "detail", "Esc did not land on the board")

# ------------------------------------------------------------------ the hand editor for a mission

func tour_hand() -> void:
	qa.screen = "Hand editor (mission)"
	var g = await goto_guild()
	freeze_world(g, true)
	var hand: Array = save.towers.hand
	save.towers.add_to_hand(by_type["wisp"][0].id)
	save.missions.tire(hand[1], MissionBoard.day_of())
	save.missions.tire(hand[2], MissionBoard.day_of())
	var d = await open_detail_by_click(g, "patrol")
	if d == null: return
	qa.step = "open by Change hand"
	var ch: Control = d._change_primary if d._change_primary.visible else d._change_wood
	await qa.click_at(qa.centre(ch))
	await qa.wait(12, 0.8)
	var he = top_popup()
	if he == null or he == d:
		qa.find("bug", "Change hand", "no hand editor opened")
		return
	await shot_audit("hand_mission", he)
	note("HAND TEXT: ", texts_under(he._tray_panel if "_tray_panel" in he else he).left(600))
	# tiles beyond the first 12 are the same control 24 more times: hover / click only the first 12
	var tiles_seen := [0]
	var skip := func(c):
		if c is TdTowerTile:
			return c.get_index() >= 6
		return false
	# the sort OptionButton opens a PopupMenu window (Esc closes it): handled by the after hook
	var after := func(c, who, info):
		for w in root.get_embedded_subwindows():
			if w.visible and w is PopupMenu:
				await qa.shot("hand_sort_menu")
				await qa.key(KEY_ESCAPE)
				await qa.wait(4, 0.3)
				if w.visible: qa.find("esc", who, "Esc does not close the sort menu"); w.hide()
		if not is_instance_valid(cur.he): return
		if cur.he._rename_edit != null and is_instance_valid(cur.he._rename_edit) and cur.he._renaming >= 0:
			await qa.shot("hand_rename")
			await qa.key(KEY_ESCAPE)
			await qa.wait(4, 0.3)
			if cur.he._renaming >= 0: qa.find("esc", who, "Esc does not cancel the layout rename")
		if not is_instance_valid(cur.he) or not cur.he.is_open: return
	cur.he = he
	await qa.crawl(func(): return cur.he if is_instance_valid(cur.he) and cur.he.is_open else null, "hand",
		{"skip": skip, "after": after, "max": 45, "esc": true, "hover_only": func(c): return QA.label_of(c).begins_with("tip:Close")})
	# Esc closes the editor back to the detail; the detail redraws
	if is_instance_valid(he) and he.is_open:
		qa.step = "Esc"
		await qa.key(KEY_ESCAPE)
		await qa.wait(8, 0.5)
		if is_instance_valid(he) and he.is_open: qa.find("esc", "hand editor", "Esc does not close it")
	save.missions.tired.clear()
	save.towers.hand.erase(by_type["wisp"][0].id)
	save.save()

# ------------------------------------------------------------------ the Workshop

func ws_open(camp) -> TdPopup:
	var b: TdButton = camp.buttons.get("Workshop")
	await qa.click_at(qa.centre(b))
	await qa.wait(14, 0.9)
	var ws = top_popup()
	if ws == null or not ws.has_method("open_modify"):
		qa.find("bug", "Workshop station", "click did not open the Workshop")
		return null
	return ws

func tour_workshop() -> void:
	qa.screen = "Workshop"
	var camp = await goto_camp()
	freeze_world(camp, true)
	var ws = await ws_open(camp)
	if ws == null: return
	qa.step = "picker"
	await shot_audit("ws_picker", ws)
	var archer: OwnedTower = by_type["archer"][2]
	var skip := func(c):
		return c is TdTowerTile and c.get_index() >= 6
	# picker: Modify slides to the Modify view → Esc back (checked); × closes (reopened)
	var after := func(c, who, info):
		if not is_instance_valid(cur.ws): return
		if cur.ws.view == "modify":
			await qa.key(KEY_ESCAPE)
			await qa.wait(10, 0.6)
			if cur.ws.view != "pick": qa.find("esc", who, "Esc does not leave the Modify view")
		for w in root.get_embedded_subwindows():
			if w.visible and w is PopupMenu:
				await qa.shot("ws_sort_menu")
				await qa.key(KEY_ESCAPE)
				await qa.wait(4, 0.3)
				if w.visible: qa.find("esc", who, "Esc does not close the sort menu"); w.hide()
	cur.ws = ws
	await qa.crawl(func(): return cur.ws if is_instance_valid(cur.ws) and cur.ws.is_open and cur.ws.view == "pick" else null, "ws_pick",
		{"skip": skip, "after": after, "max": 70, "reopen": func():
			cur.ws = await ws_open(camp)})
	ws = cur.ws
	if not is_instance_valid(ws) or not ws.is_open: ws = await ws_open(camp)
	cur.ws = ws
	# double click Archer #? (tower 3) → Modify
	qa.step = "double click a tile"
	ws.collection.clear_filters()
	await qa.wait(4, 0.3)
	var tile: Control = ws.collection.tiles.get(archer.id)
	if tile != null:
		var sc := QA.scroll_parent(tile)
		if sc != null: sc.ensure_control_visible(tile); await qa.frames(3)
		await qa.dbl_click_at(qa.centre(tile))
		await qa.wait(14, 0.9)
	if ws.view != "modify" or ws.tower_id != archer.id:
		qa.find("bug", "picker tile double click", "did not open Modify for it (view %s, tower %s)" % [ws.view, ws.tower_id])
		ws.open_modify(archer.id)
		await qa.wait(14, 0.9)
	await shot_audit("ws_modify", ws)
	# every node state is on screen: Archer (current), Fire (can), Poison (need), Inferno (locked) …
	var states := {}
	for id in ws._tree.nodes: states[id] = ws._tree.nodes[id].state
	note("NODE STATES ", states)
	# the Modify view: nodes select, token chips hover, the card's action: Unlock → confirm (Esc cancels)
	var mod_after := func(c, who, info):
		if not is_instance_valid(cur.ws): return
		if cur.ws.confirm_open:
			await shot_audit("ws_confirm_from_" + who.left(20), cur.ws._confirm)
			await qa.key(KEY_ESCAPE)
			await qa.wait(6, 0.4)
			if cur.ws.confirm_open: qa.find("esc", who, "Esc does not cancel the confirm")
		if cur.ws.view != "modify":
			cur.ws.open_modify(archer.id)
			await qa.wait(14, 0.9)
	var is_back := func(c): return c is TdButton and str(c.text) == "Back"
	await qa.crawl(func(): return ws if is_instance_valid(ws) and ws.is_open and ws.view == "modify" else null, "ws_mod",
		{"after": mod_after, "hover_only": is_back, "max": 40})
	# each node selected: the card for every state (screens)
	for id in ws._tree.nodes:
		var n: Control = ws._tree.nodes[id]
		qa.step = "node " + (id if id != "" else "base")
		await qa.click_at(qa.centre(n))
		await qa.wait(6, 0.4)
		if ws.node_id != id: qa.find("bug", "tree node " + id, "click did not select it")
		await shot_audit("ws_node_%s_%s" % [id if id != "" else "base", n.state], ws)
	# keyboard: arrows move between nodes
	qa.step = "arrows"
	ws.select_node("archer-poison")
	await qa.wait(3, 0.2)
	var seq := []
	for k in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_RIGHT, KEY_DOWN]:
		await qa.key(k)
		await qa.wait(3, 0.2)
		seq.append(ws.node_id)
	note("ARROWS from poison: ", seq)
	if seq.all(func(x): return x == "archer-poison"): qa.find("bug", "tree arrows", "arrow keys do not move the selection")
	# unlock with tokens through the real flow: select Fire Archer, click Unlock, then the confirm's Unlock
	qa.step = "unlock"
	var have0: int = save.tokens.count("fire-arrow")
	ws.select_node("archer-fire")
	await qa.wait(6, 0.4)
	var unlock_btn: Control = null
	for c in QA.visible_controls(ws._card):
		if c is TdButton and c.interactable and c.style == TdButton.Style.PRIMARY: unlock_btn = c
	if unlock_btn == null:
		qa.find("bug", "Fire Archer card", "no enabled Unlock button")
	else:
		await qa.click_at(qa.centre(unlock_btn))
		await qa.wait(8, 0.5)
		await shot_audit("ws_confirm", ws._confirm)
		var yes := find_text(ws._confirm, "Unlock")
		if yes == null: qa.find("bug", "confirm", "no Unlock button")
		else:
			await qa.click_at(qa.centre(yes))
			await qa.wait(8, 0.5)
		await shot_audit("ws_unlocked", ws)
		var have1: int = save.tokens.count("fire-arrow")
		note("UNLOCK fire-arrow ", have0, " → ", have1, " forms ", archer.forms)
		if not archer.forms.has("archer-fire"): qa.find("data", "unlock", "the form is not on the tower after Unlock")
		# the header token chip shows the new count
		var hdr := texts_under(ws._tokens)
		if not hdr.contains(str(have1)): qa.find("data", "Modify header tokens", "header '%s' does not show %d" % [hdr, have1])
		# Use this form (Enter = the card's action)
		qa.step = "use (Enter)"
		await qa.key(KEY_ENTER)
		await qa.wait(8, 0.5)
		if archer.form != "archer-fire": qa.find("bug", "Enter on an unlocked form", "did not switch the form (form '%s')" % archer.form)
		await shot_audit("ws_used", ws)
	# Esc chain: Modify → picker → closed; the picker shows the form name / badge
	qa.step = "Esc chain"
	await qa.key(KEY_ESCAPE)
	await qa.wait(12, 0.8)
	if ws.view != "pick": qa.find("esc", "Modify", "Esc does not go back to the picker")
	var s := await shot_audit("ws_picker_after", ws)
	var tile2: Control = ws.collection.tiles.get(archer.id)
	var tile_text := texts_under(tile2) if tile2 != null else ""
	note("PICKER tile: ", tile_text, " | detail: ", texts_under(ws._pdetail).left(300))
	if not tile_text.contains("Fire"): qa.find("data", "picker tile", "formed tower tile says '%s' (no form name)" % tile_text, s)
	if tile2 != null and tile2.find_children("*", "", true, false).filter(func(x): return x.get_script() != null and str(x.get_script().resource_path).contains("form_badge")).is_empty():
		note("NOTE picker tile: no TdFormBadge node found (check the shot)")
	await qa.key(KEY_ESCAPE)
	await qa.wait(10, 0.6)
	if is_instance_valid(ws) and ws.is_open: qa.find("esc", "Workshop picker", "Esc does not close the Workshop")
	# the formed tower elsewhere: the hand editor (Towers station) and the mission detail's hand
	save.towers.hand[0] = archer.id
	save.save()
	qa.step = "form elsewhere: hand editor"
	await qa.click_at(qa.centre(camp.buttons["Towers"]))
	await qa.wait(14, 0.9)
	var he = top_popup()
	if he != null:
		s = await shot_audit("ws_form_in_hand_editor", he)
		var ht := texts_under(he)
		if not ht.contains("Fire Archer"): qa.find("data", "hand editor", "the formed tower's name 'Fire Archer' is nowhere", s)
		await qa.key(KEY_ESCAPE)
		await qa.wait(8, 0.5)
	var g = await goto_guild()
	freeze_world(g, true)
	qa.step = "form elsewhere: mission detail"
	var d = await open_detail_by_click(g, "patrol")
	if d != null:
		s = await shot_audit("ws_form_in_detail", d)
		if not texts_under(d._tray).contains("Fire Archer"): qa.find("data", "mission detail hand", "the formed tower shows as '%s'" % texts_under(d._tray).left(80), s)
	# the Codex knows the unlocked form (its Forms page lists forms some tower has unlocked)
	note("CODEX forms check: archer forms ", archer.forms)

# ------------------------------------------------------------------ co-op (FakeRelay bots)

func _bot(n: String) -> FakeRelay.Link:
	var l := relay.connect_client()
	l.send_text(NetProtocol.encode(NetProtocol.hello(CoopLevels.content_version(), n)))
	return l

func _say(l: FakeRelay.Link, msg: Dictionary) -> void:
	l.send_text(NetProtocol.encode(msg))

func _connect_fake() -> void:
	relay = FakeRelay.new()
	relay.shared_pool_of = func(l): return CoopLevels.shared_pool(l)
	net = root.get_node("Net")
	net.player_name_override = "Eren"
	net.connect_fake(relay)
	net.practice = false
	net.auto_poll = true
	relay.player_pings = {}
	net._rtt_in = 1e9

func open_lobby(g) -> CoopLobby:
	await qa.click_at(qa.centre(g.stations["Multiplayer"]))
	await qa.wait(12, 0.8)
	await boards()
	var t = top_popup()
	if not (t is CoopLobby):
		qa.find("bug", "Multiplayer station", "did not open the lobby")
		return null
	return t

func tour_coop() -> void:
	qa.screen = "Co-op"
	_connect_fake()
	var g = await goto_guild()
	freeze_world(g, true)
	var lobby: CoopLobby = await open_lobby(g)
	if lobby == null: return
	qa.step = "empty list"
	await shot_audit("lobby_empty", lobby)
	# rooms from bots
	var mert := _bot("Mert")
	_say(mert, NetProtocol.create("Quick slimes", "chapter2-2", 2, "", ["cannon"]))
	var ayla := _bot("Ayla")
	_say(ayla, NetProtocol.create("Herkes gelsin! Uzun bir oda adı burada", "chapter2-1", 6, "", ["wisp", "archer"]))
	var cagri := _bot("Çağrı")
	_say(cagri, NetProtocol.create("Akşam savunması", "chapter1-3", 4, "gizli", ["archer", "cannon", "mage"]))
	var full := _bot("Şule")
	_say(full, NetProtocol.create("Dolu oda", "chapter2-2", 2, "", ["priest"]))
	_say(_bot("Cem"), NetProtocol.join(full.room_id, "", ["archer"]))
	await qa.frames(4)
	# Refresh with a real click
	qa.step = "refresh"
	var refresh_btn := find_text(lobby, "Refresh")
	if refresh_btn != null: await qa.click_at(qa.centre(refresh_btn))
	else: qa.find("bug", "lobby", "no Refresh button")
	await qa.wait(10, 0.6)
	await boards()
	if lobby._list.get_child_count() < 4: qa.find("data", "Refresh", "list has %d rows after Refresh (4 rooms)" % lobby._list.get_child_count())
	await shot_audit("lobby_list", lobby)
	# filters: type in the search, Show full rooms off (switch and its label)
	qa.step = "search"
	await qa.click_at(qa.centre(lobby._search))
	await qa.type_text("akşam")
	await qa.wait(6, 0.4)
	await shot_audit("lobby_search", lobby)
	if lobby._list.get_child_count() != 1: qa.find("data", "search 'akşam'", "%d rows (1 expected)" % lobby._list.get_child_count())
	lobby._search.text = ""
	lobby._search.text_changed.emit("")
	await qa.click_at(qa.centre(lobby._show_full))
	await qa.wait(6, 0.4)
	await shot_audit("lobby_hide_full", lobby)
	var n_hidden: int = lobby._list.get_child_count()
	var lbl := find_text(lobby, "Show full rooms")
	if lbl != null: await qa.click_at(qa.centre(lbl))
	await qa.wait(6, 0.4)
	note("rows with full hidden: ", n_hidden, " after label click: ", lobby._list.get_child_count())
	if n_hidden >= lobby._list.get_child_count(): qa.find("data", "Show full rooms", "toggling does not change the rows (%d / %d)" % [n_hidden, lobby._list.get_child_count()])
	# crawl the lobby (rows select, Join / Create open popups: Esc back; × closes: reopened)
	var join_skip := func(c): return is_instance_valid(cur.lobby) and c == cur.lobby._join # explicit below
	cur.lobby = lobby
	await qa.crawl(func(): return cur.lobby if is_instance_valid(cur.lobby) and cur.lobby.is_open and not net.in_room else null, "lobby",
		{"hover_only": join_skip, "max": 40, "after": func(c, who, info):
			if net.in_room:
				net.leave_room()
				await qa.wait(8, 0.5),
		"reopen": func():
			cur.lobby = await open_lobby(g)})
	lobby = cur.lobby
	if not is_instance_valid(lobby) or not lobby.is_open: lobby = await open_lobby(g)
	# join a password room with a wrong password, then the right one
	qa.step = "join wrong password"
	lobby.select_room(cagri.room_id)
	await qa.wait(4, 0.3)
	await qa.click_at(qa.centre(lobby._join))
	await qa.wait(8, 0.6)
	var jp = top_popup()
	if not (jp is CoopJoinPopup): qa.find("bug", "Join (password room)", "no password popup")
	else:
		await shot_audit("join_popup", jp)
		await qa.click_at(qa.centre(jp._password))
		await qa.type_text("yanlis")
		await qa.key(KEY_ENTER)
		await qa.wait(8, 0.5)
		await shot_audit("join_wrong", jp)
		if net.in_room: qa.find("data", "wrong password", "joined anyway")
		await qa.crawl(func(): return jp if is_instance_valid(jp) and jp.is_open else null, "join", {"max": 10, "esc": true,
			"hover_only": func(c): return c == jp._join})
		if is_instance_valid(jp) and jp.is_open:
			jp._password.text = ""
			await qa.click_at(qa.centre(jp._password))
			await qa.type_text("gizli")
			await qa.click_at(qa.centre(jp._join))
			await qa.wait(10, 0.7)
		if not net.in_room: qa.find("data", "right password", "not in the room")
		else:
			await boards()
			await shot_audit("room_guest", qa.top(lobby))
			await qa.key(KEY_ESCAPE)
			await qa.wait(6, 0.4)
			if not net.in_room: qa.find("esc", "room", "Esc left the room (Leave room should)")
			var leave := find_text(lobby.room_popup, "Leave room") if lobby.room_popup != null else null
			if leave != null: await qa.click_at(qa.centre(leave))
			await qa.wait(8, 0.5)
			if net.in_room: qa.find("bug", "Leave room", "still in the room")
	# full room: Join refused
	qa.step = "full room"
	lobby.select_room(full.room_id)
	await qa.wait(4, 0.3)
	qa.move(qa.centre(lobby._join))
	await qa.wait(6, 0.6)
	await shot_audit("lobby_full_selected", lobby)
	qa.park_mouse()
	# Create room: name, password, counts (mission range), mission picker, Create
	qa.step = "create"
	await qa.click_at(qa.centre(lobby._create))
	await qa.wait(10, 0.7)
	await boards()
	var cp = top_popup()
	if not (cp is CoopCreatePopup):
		qa.find("bug", "Create room", "no create popup")
		return
	await shot_audit("create", cp)
	await qa.crawl(func(): return cp if is_instance_valid(cp) and cp.is_open else null, "create",
		{"max": 40, "hover_only": func(c): return c == cp._create, "esc": true})
	if not is_instance_valid(cp) or not cp.is_open:
		await qa.click_at(qa.centre(lobby._create))
		await qa.wait(10, 0.7)
		cp = top_popup()
	# pick Hold the Gate (2–6) and try 1 player (disabled); the done mission row cannot be picked
	var hg: MissionDef = app.mission("hold-the-gate")
	qa.step = "create: Hold the Gate range"
	for r in cp._levels.get_children():
		if is_instance_valid(r) and QA.label_of(r).contains(hg.name):
			await qa.click_at(qa.centre(r))
			await qa.wait(6, 0.4)
			break
	note("create level ", cp.level_id, " count ", cp.count)
	for b in cp._picker_buttons():
		if b.text == "1":
			qa.move(qa.centre(b))
			await qa.wait(6, 0.6)
			await shot_audit("create_count1_hover", cp)
			await qa.click_at(qa.centre(b))
			await qa.wait(4, 0.3)
			if cp.count == 1: qa.find("data", "players 1 for Hold the Gate", "accepted a count outside the mission's range")
	qa.park_mouse()
	# the name: clear and type
	cp._name.text = ""
	await qa.click_at(qa.centre(cp._name))
	await qa.type_text("Akşam savunması uzun isim test")
	await qa.wait(4, 0.3)
	await shot_audit("create_typed", cp)
	await qa.click_at(qa.centre(cp._create))
	await qa.wait(12, 0.8)
	if not net.in_room:
		qa.find("bug", "Create", "not in a room after Create")
		return
	await boards()
	var room: CoopRoom = lobby.room_popup
	var b1 := _bot("Şule")
	_say(b1, NetProtocol.join(net.room.id, "", ["mage", "archer", "wisp"]))
	var b2 := _bot("Mert")
	_say(b2, NetProtocol.join(net.room.id, "", ["guardian", "ballista"]))
	_say(b1, NetProtocol.ready(true))
	await qa.wait(10, 0.6)
	await boards()
	qa.step = "room host"
	await shot_audit("room_host", room)
	# ready / unready with real clicks
	await qa.click_at(qa.centre(room._ready_btn))
	await qa.wait(6, 0.4)
	var me = NetProtocol.find_player(net.room, net.player_id)
	var r1 := bool(me.get("ready", false)) if me != null else false
	await shot_audit("room_ready", room)
	await qa.click_at(qa.centre(room._ready_btn))
	await qa.wait(6, 0.4)
	me = NetProtocol.find_player(net.room, net.player_id)
	var r2 := bool(me.get("ready", false)) if me != null else false
	note("READY toggles: ", r1, " → ", r2)
	if not r1 or r2: qa.find("data", "Ready", "ready toggling went %s → %s" % [r1, r2])
	# chat: type and Enter
	qa.step = "chat"
	await qa.click_at(qa.centre(room._chat_in))
	await qa.type_text("Merhaba! Sol yolu alıyorum.")
	await qa.key(KEY_ENTER)
	_say(b1, NetProtocol.chat("ok, I take the right road with a very long line that should wrap nicely in the chat panel"))
	await qa.wait(10, 0.6)
	await shot_audit("room_chat", room)
	# Space while typing must not do anything else; Esc in the room: stays (Leave room leaves)
	qa.step = "room crawl"
	await qa.crawl(func(): return room if is_instance_valid(room) and room.is_open else null, "room",
		{"max": 40, "hover_only": func(c): return QA.label_of(c) in ["Leave room", "Start"] or str(c.name) == "Kick",
		"after": func(c, who, info):
			for w in root.get_embedded_subwindows():
				if w.visible and w is PopupMenu: w.hide()})
	# settings (host): Change level → pick Night Watch (done today) → Apply would auto-leave… pick count instead
	qa.step = "settings"
	var cl: Control = room._change_level
	await qa.click_at(qa.centre(cl))
	await qa.wait(10, 0.7)
	await boards()
	var st = top_popup()
	if st is CoopRoomSettings:
		await shot_audit("settings", st)
		await qa.crawl(func(): return st if is_instance_valid(st) and st.is_open else null, "settings",
			{"max": 30, "hover_only": func(c): return c == st._apply})
		if is_instance_valid(st) and st.is_open:
			for bb in st._picker:
				if bb.text == "2": await qa.click_at(qa.centre(bb))
			await qa.wait(6, 0.4)
			await shot_audit("settings_lower", st)
			await qa.click_at(qa.centre(st._apply))
			await qa.wait(10, 0.6)
		note("after settings: count ", net.room.get("count"), " players ", NetProtocol.players_by_slot(net.room).size())
		await shot_audit("room_after_settings", room)
	else:
		qa.find("bug", "Change level", "no settings popup")
	# kick: the host's × on a bot
	qa.step = "kick"
	_say(b2, NetProtocol.join(net.room.id, "", ["guardian"]))
	await qa.wait(6, 0.4)
	var kick: Control = null
	for c in QA.visible_controls(room):
		if str(c.name) == "Kick": kick = c
	if kick == null: qa.find("bug", "room", "no kick × for the host")
	else:
		var n0 := NetProtocol.players_by_slot(net.room).size()
		await qa.click_at(qa.centre(kick))
		await qa.wait(10, 0.6)
		var n1 := NetProtocol.players_by_slot(net.room).size()
		note("KICK players ", n0, " → ", n1)
		if n1 >= n0: qa.find("data", "kick", "players %d → %d" % [n0, n1])
		await shot_audit("room_kicked", room)
	# Change hand in the room → hand editor → Esc (back to the room, still in it)
	qa.step = "room change hand"
	var chb := find_text(room, "Change hand")
	if chb != null:
		await qa.click_at(qa.centre(chb))
		await qa.wait(12, 0.8)
		await shot_audit("room_hand_editor", qa.top(room))
		await qa.key(KEY_ESCAPE)
		await qa.wait(8, 0.5)
		if not room.is_open or not net.in_room: qa.find("esc", "room hand editor", "Esc left the room")
	# leave
	qa.step = "leave"
	await qa.click_at(qa.centre(find_text(room, "Leave room")))
	await qa.wait(8, 0.5)
	if net.in_room: qa.find("bug", "Leave room", "still in the room")
	# auto-leave: join Mert's room, he switches to Night Watch (done today)
	qa.step = "auto-leave"
	var host := _bot("Deniz")
	_say(host, NetProtocol.create("Gate keepers", "chapter2-3", 4, "", ["archer"]))
	await qa.wait(4, 0.3)
	net.list_rooms()
	await qa.wait(6, 0.4)
	lobby.select_room(host.room_id)
	await qa.wait(4, 0.3)
	await qa.click_at(qa.centre(lobby._join))
	await qa.wait(10, 0.6)
	note("in room before switch: ", net.in_room, " level ", net.room.get("level", ""))
	_say(host, NetProtocol.set_level(app.mission("night-watch").level_id))
	await qa.wait(16, 1.0)
	var dp = top_popup()
	await shot_audit("auto_left", qa.top(lobby))
	if net.in_room: qa.find("data", "auto-leave", "still in the room after the host switched to a used-up mission")
	if dp == null or not str(dp.get_script().resource_path).contains("coop_lobby") and not ("texts" in dp):
		qa.find("data", "auto-leave", "no Done today popup (top: %s)" % [QA.describe(dp) if dp != null else "none"])
	else:
		cur.dp = dp # a lambda capturing a freed popup raises an engine error when called: read it from the dict
		await qa.crawl(func(): return cur.dp if is_instance_valid(cur.dp) and cur.dp.is_open else null, "done_popup", {"max": 4})
	# Esc closes the lobby
	qa.step = "lobby Esc"
	if is_instance_valid(lobby) and top_popup() == lobby:
		await qa.key(KEY_ESCAPE)
		await qa.wait(8, 0.5)
		if is_instance_valid(lobby) and lobby.is_open: qa.find("esc", "lobby", "Esc does not close the lobby")

# ------------------------------------------------------------------ a mission play spent: board / detail / end screen

func tour_play() -> void:
	qa.screen = "Mission play"
	var g = await goto_guild()
	freeze_world(g, true)
	var b = await open_board(g)
	var m: MissionDef = app.mission("drum-line")
	var left0 := MissionBoard.plays_left(m, save.missions)
	var card: Control = b.cards.get(m.id)
	var play := find_text(card, "Play")
	qa.step = "card Play"
	if play == null:
		qa.find("bug", "Drum Line card", "no Play button")
		return
	var sc := QA.scroll_parent(card)
	if sc != null: sc.ensure_control_visible(card); await qa.frames(3)
	await qa.click_at(qa.centre(play))
	await qa.until(func(): return flow.current == flow.Game and not flow.is_loading and current_scene != null, 90.0)
	await qa.wait(20, 1.0)
	var level = current_scene
	if flow.current != flow.Game:
		qa.find("bug", "card Play", "the level did not open")
		return
	var left1 := MissionBoard.plays_left(m, save.missions)
	note("PLAYS drum-line ", left0, " → ", left1)
	if left1 != left0 - 1: qa.find("data", "play spent", "plays left %d → %d" % [left0, left1])
	# win fast
	level.skip_sequence()
	for i in 300:
		await process_frame
		if not level.director.busy: break
	level.instant_override = true
	for rr in 80:
		if level.session.is_over: break
		for en in level.session.enemies:
			if not en.alive: continue
			var fx := DamageEffect.new()
			fx.amount = Formula.new("999")
			fx.target_id = en.id
			fx.source = 0
			level.session.resolver.run(fx)
		level.session.after_command()
		level.version += 1
		for i in 300:
			await process_frame
			if not level.director.busy: break
		if level.session.is_over: break
		level.end_round()
		for i in 300:
			await process_frame
			if not level.director.busy: break
	for i in 600:
		if level.hud.end_screen.visible: break
		await process_frame
	await qa.wait(10, 1.0)
	qa.step = "end screen"
	var es: Control = level.hud.end_screen
	var s := await shot_audit("end_screen", es)
	var et := texts_under(es)
	note("END: ", et)
	# leave to the Guild with the end screen's button
	var lb := find_text(es, level.leave_label)
	if lb == null:
		for c in QA.visible_controls(es):
			if c is TdButton and str(c.text).contains("Guild"): lb = c
	if lb == null:
		qa.find("bug", "end screen", "no '%s' button" % level.leave_label, s)
		return
	await qa.click_at(qa.centre(lb))
	await qa.until(func(): return flow.current == flow.Guild and not flow.is_loading and current_scene != null, 90.0)
	await qa.wait(30, 1.0)
	if flow.current != flow.Guild: qa.find("bug", "end screen leave", "did not go to the Guild")
	g = current_scene
	freeze_world(g, true)
	qa.step = "board after"
	b = await open_board(g)
	var ct := texts_under(b.cards.get(m.id))
	s = await shot_audit("board_after_play", b)
	note("CARD after: ", ct)
	var left2 := MissionBoard.plays_left(m, save.missions)
	var d = await open_detail_by_click(g, m.id)
	if d != null:
		s = await shot_audit("detail_after_play", d)
		var dt := texts_under(d._pips)
		note("DETAIL pips after: ", dt)
		if not dt.contains(str(left2)): qa.find("data", "detail pips", "'%s' does not say %d left" % [dt, left2], s)
	if not ct.contains(str(left2)) and left2 > 0: qa.find("data", "board card", "'%s' does not say %d left" % [ct, left2], s)
	# the Guild's Missions station count agrees
	var sub := str(g.stations["Missions"].sub)
	note("STATION sub: ", sub)

func note(...args: Array) -> void:
	var s := "".join(args.map(func(a): return str(a)))
	print(s)
	if qa != null: qa.progress(s)

# ------------------------------------------------------------------ verify: the fixed screens, shots + audits only

func tour_verify() -> void:
	qa.screen = "Verify"
	var g = await goto_guild()
	freeze_world(g, true)
	var d = await open_detail_by_click(g, "patrol")
	if d != null:
		await shot_audit("v_detail_picture", d)
		# right click on a card area closes (fix #3)
		var depth := TdPopup.open_popups.size()
		await qa.click_at(Vector2(900, 300), MOUSE_BUTTON_RIGHT)
		await qa.wait(8, 0.5)
		note("right click on the detail: popups ", depth, " → ", TdPopup.open_popups.size())
		if TdPopup.open_popups.size() >= depth: qa.find("esc", "detail", "right click does not close it")
	# co-op
	_connect_fake()
	if g.board != null and g.board.is_open: g.board.close()
	await qa.wait(6, 0.4)
	var lobby: CoopLobby = await open_lobby(g)
	if lobby == null: return
	var full := _bot("Şule")
	_say(full, NetProtocol.create("Dolu oda", "chapter2-2", 2, "", ["priest"]))
	_say(_bot("Cem"), NetProtocol.join(full.room_id, "", ["archer"]))
	var ayla := _bot("Ayla")
	_say(ayla, NetProtocol.create("Herkes gelsin! Uzun bir oda adı", "chapter2-1", 6, "", ["wisp"]))
	net.list_rooms()
	await qa.wait(6, 0.4)
	lobby.select_room(full.room_id)
	await boards()
	await shot_audit("v_lobby_full", lobby)
	var cp := lobby.open_create(app.mission("hold-the-gate").level_id)
	await qa.wait(10, 0.6)
	await boards()
	await shot_audit("v_create", cp)
	cp.create()
	await qa.wait(10, 0.6)
	var room: CoopRoom = lobby.room_popup
	if room == null: return
	var b1 := _bot("Mert")
	_say(b1, NetProtocol.join(net.room.id, "", ["mage", "archer", "wisp"]))
	save.missions.tire(save.towers.hand[1], MissionBoard.day_of())
	save.missions.tire(save.towers.hand[2], MissionBoard.day_of())
	room.refresh()
	await qa.wait(8, 0.5)
	await boards()
	await shot_audit("v_room_host", room)
	var st := room.open_settings()
	await qa.wait(10, 0.6)
	await boards()
	await shot_audit("v_settings", st)
	st.close()
	await qa.wait(6, 0.4)
	var he := room.open_hand_editor()
	await qa.wait(12, 0.8)
	await shot_audit("v_room_hand_editor", he)
	he.close()
	await qa.wait(6, 0.4)
	room.leave_room()
	save.missions.tired.clear()
	# workshop medallions
	var camp = await goto_camp()
	freeze_world(camp, true)
	var ws = await ws_open(camp)
	if ws != null:
		ws.open_modify(by_type["archer"][2].id)
		await qa.wait(14, 0.9)
		await shot_audit("v_ws_modify", ws)

# ------------------------------------------------------------------ abuse: wrong inputs (QA round 2)

func depth() -> int:
	return TdPopup.open_popups.size()

## Open popups whose script is (or extends) the named class (by name: a class reference here would compile the
## screen scripts before the autoloads exist).
func count_popups(cls_name: String) -> int:
	var n := 0
	for p in TdPopup.open_popups:
		var s: Script = p.get_script()
		while s != null:
			if s.get_global_name() == cls_name: n += 1; break
			s = s.get_base_script()
	return n

func keys(list: Array) -> void:
	for k in list:
		await qa.key(k)
		await qa.wait(3, 0.2)

## Wrong inputs on every screen: right clicks, Space / Enter / Tab / arrows where they mean nothing, double clicks on
## cards, Play, Modify, Unlock and Create. Each step notes what happened; anything that opened twice, played or spent
## is a finding (engine warnings are caught by the logger).
func tour_abuse() -> void:
	qa.screen = "Wrong inputs"
	var g = await goto_guild()
	freeze_world(g, true)
	qa.step = "bare guild keys"
	await qa.click_at(Vector2(960, 760), MOUSE_BUTTON_RIGHT)
	await keys([KEY_SPACE, KEY_ENTER, KEY_TAB, KEY_1, KEY_ESCAPE])
	if depth() != 0 or flow.current != flow.Guild: qa.find("bug", "bare Guild", "keys / right click: %d popups, scene %s" % [depth(), flow.current])
	await qa.shot("ab_guild_keys")
	# the board: a double click on a card opens one detail
	qa.step = "board card double click"
	var b = await open_board(g)
	freeze_world(g, true)
	var card: Control = b.cards.get("patrol")
	await qa.dbl_click_at(QA.grect(card).position + Vector2(40, 40))
	await qa.wait(10, 0.6)
	await boards()
	note("double click card: details ", count_popups("MissionDetail"), " depth ", depth())
	if count_popups("MissionDetail") != 1: qa.find("bug", "board card double click", "%d details opened" % count_popups("MissionDetail"))
	var d = b.detail
	qa.step = "detail keys"
	if d != null:
		await qa.click_at(qa.centre(d._rows[3]))
		await qa.wait(4, 0.3)
		var dd := depth()
		await keys([KEY_SPACE, KEY_ENTER, KEY_TAB, KEY_UP, KEY_DOWN])
		note("detail keys: depth ", dd, " → ", depth(), " loading ", flow.is_loading, " mission ", d.mission_id)
		if flow.is_loading: qa.find("bug", "detail keys", "a key started the level")
		await qa.shot("ab_detail_keys")
		# a double click on a hand slot: one hand editor
		await qa.dbl_click_at(qa.centre(d._pieces[0]))
		await qa.wait(12, 0.8)
		var n_he := 0
		for p in TdPopup.open_popups:
			if str(p.get_script().resource_path).contains("hand_editor"): n_he += 1
		note("double click hand slot: hand editors ", n_he)
		if n_he > 1: qa.find("bug", "detail hand slot double click", "%d hand editors opened" % n_he)
		await qa.shot("ab_detail_slot_dbl")
		while depth() > dd:
			await qa.key(KEY_ESCAPE)
			await qa.wait(6, 0.4)
		# right click on Play: Back, never plays
		await qa.click_at(qa.centre(d._play), MOUSE_BUTTON_RIGHT)
		await qa.wait(8, 0.5)
		if flow.is_loading: qa.find("bug", "right click on Play", "started the level")
		if is_instance_valid(d) and d.is_open: qa.find("esc", "detail", "right click on Play did not go back")
	qa.step = "board keys"
	if g.board != null and g.board.is_open:
		await keys([KEY_SPACE, KEY_ENTER, KEY_TAB])
		if flow.is_loading: qa.find("bug", "board keys", "a key started a level")
		await qa.shot("ab_board_keys")
	# co-op: lobby keys, double click Create, Enter in the room name, Esc chain
	qa.step = "lobby keys"
	if g.board != null and g.board.is_open:
		await qa.key(KEY_ESCAPE)
		await qa.wait(8, 0.5)
	_connect_fake()
	var lobby: CoopLobby = await open_lobby(g)
	if lobby != null:
		var mert := _bot("Mert")
		_say(mert, NetProtocol.create("Quick slimes", "chapter2-2", 4, "", ["cannon"]))
		net.list_rooms()
		await qa.wait(6, 0.4)
		lobby.select_room(mert.room_id)
		await qa.wait(4, 0.3)
		await keys([KEY_SPACE, KEY_ENTER, KEY_TAB])
		note("lobby keys: in room ", net.in_room, " depth ", depth())
		await qa.shot("ab_lobby_keys")
		if net.in_room:
			net.leave_room()
			await qa.wait(8, 0.5)
		# double click on a room row: joins? (one room popup at most)
		var row: Control = null
		for r in lobby._list.get_children():
			if r is Control and r.visible: row = r; break
		if row != null:
			await qa.dbl_click_at(qa.centre(row))
			await qa.wait(10, 0.6)
			await boards()
			note("double click room row: in room ", net.in_room, " rooms popups ", count_popups("CoopRoom"), " depth ", depth())
			if count_popups("CoopRoom") > 1: qa.find("bug", "lobby row double click", "%d room popups" % count_popups("CoopRoom"))
			await qa.shot("ab_lobby_row_dbl")
			if net.in_room:
				net.leave_room()
				await qa.wait(10, 0.6)
		qa.step = "create double click"
		var d0 := depth()
		await qa.dbl_click_at(qa.centre(lobby._create))
		await qa.wait(10, 0.7)
		await boards()
		note("double click Create room: create popups ", count_popups("CoopCreatePopup"), " depth ", d0, " → ", depth())
		if count_popups("CoopCreatePopup") > 1: qa.find("bug", "Create room double click", "%d create popups" % count_popups("CoopCreatePopup"))
		var cp = top_popup()
		if cp is CoopCreatePopup:
			await qa.click_at(qa.centre(cp._name))
			await qa.key(KEY_END)
			await qa.type_text(" 2")
			await qa.key(KEY_ENTER)
			await qa.wait(10, 0.6)
			note("Enter in the room name: in room ", net.in_room, " top ", QA.describe(top_popup()) if top_popup() != null else "none")
			await qa.shot("ab_create_enter")
			if not net.in_room:
				# the Create button double clicked: one room
				await qa.dbl_click_at(qa.centre(cp._create))
				await qa.wait(12, 0.8)
				note("double click Create: in room ", net.in_room, " room popups ", count_popups("CoopRoom"), " rooms on relay ", relay.rooms.size() if "rooms" in relay else -1)
			if count_popups("CoopRoom") > 1: qa.find("bug", "Create double click", "%d room popups" % count_popups("CoopRoom"))
			await boards()
			await qa.shot("ab_room")
			if net.in_room:
				var room: CoopRoom = lobby.room_popup
				# Ready double click: back to not ready (two toggles), no error
				await qa.dbl_click_at(qa.centre(room._ready_btn))
				await qa.wait(6, 0.4)
				var me = NetProtocol.find_player(net.room, net.player_id)
				note("Ready double click: ready ", me.get("ready", false) if me != null else "?")
				# Esc, right click in the room: stays
				await qa.key(KEY_ESCAPE)
				await qa.wait(4, 0.3)
				await qa.click_at(Vector2(960, 540), MOUSE_BUTTON_RIGHT)
				await qa.wait(6, 0.4)
				note("room after Esc + right click: in room ", net.in_room, " depth ", depth())
				await qa.shot("ab_room_esc")
				net.leave_room()
				await qa.wait(8, 0.5)
		while depth() > 0:
			await qa.key(KEY_ESCAPE)
			await qa.wait(6, 0.4)
	# Workshop
	qa.step = "workshop keys"
	var camp = await goto_camp()
	freeze_world(camp, true)
	var ws = await ws_open(camp)
	if ws != null:
		var t0: Control = ws.collection.tiles.get(by_type["archer"][1].id)
		await qa.click_at(qa.centre(t0))
		await qa.wait(4, 0.3)
		await keys([KEY_SPACE, KEY_TAB, KEY_RIGHT, KEY_DOWN])
		note("picker after Space/Tab/arrows: view ", ws.view, " tower ", ws.tower_id, " (clicked ", by_type["archer"][1].id, ")")
		await qa.shot("ab_ws_pick_keys")
		await qa.key(KEY_ENTER)
		await qa.wait(14, 0.9)
		if ws.view != "modify": qa.find("bug", "picker Enter", "did not open Modify")
		await keys([KEY_ENTER, KEY_ENTER, KEY_SPACE, KEY_TAB])
		note("modify after Enter×2 on the current form: view ", ws.view, " confirm ", ws.confirm_open)
		if ws.view == "modify": # a right click in the picker closes the Workshop
			await qa.click_at(qa.centre(ws._tree) + Vector2(0, -60), MOUSE_BUTTON_RIGHT)
			await qa.wait(12, 0.8)
			if ws.view != "pick": qa.find("esc", "Modify right click", "did not go back to the picker")
		if not is_instance_valid(ws) or not ws.is_open: ws = await ws_open(camp)
		var mb := find_text(ws._pdetail, "Modify")
		if mb != null:
			await qa.dbl_click_at(qa.centre(mb))
			await qa.wait(14, 0.9)
		note("double click Modify: view ", ws.view)
		await qa.shot("ab_ws_modify_dbl")
		if ws.view == "modify":
			ws.select_node("archer-fire")
			await qa.wait(6, 0.4)
			var have0: int = save.tokens.count("fire-arrow")
			var ub: Control = null
			for c in QA.visible_controls(ws._card):
				if c is TdButton and c.interactable and c.style == TdButton.Style.PRIMARY: ub = c
			if ub != null:
				await qa.dbl_click_at(qa.centre(ub))
				await qa.wait(8, 0.5)
				note("double click Unlock: confirm ", ws.confirm_open, " tokens ", have0, " → ", save.tokens.count("fire-arrow"))
				await qa.shot("ab_ws_unlock_dbl")
				if ws.confirm_open:
					var yes := find_text(ws._confirm, "Unlock")
					if yes != null:
						await qa.dbl_click_at(qa.centre(yes))
						await qa.wait(8, 0.5)
				var have1: int = save.tokens.count("fire-arrow")
				note("double click confirm Unlock: tokens ", have0, " → ", have1, " confirm ", ws.confirm_open)
				if have1 < have0 - 1: qa.find("data", "Unlock double click", "spent %d tokens" % (have0 - have1))
				await qa.shot("ab_ws_unlocked_dbl")
		await keys([KEY_ESCAPE, KEY_ESCAPE, KEY_ESCAPE])
		await qa.wait(8, 0.5)
		note("Esc ×3: workshop open ", is_instance_valid(ws) and ws.is_open, " scene ", flow.current)
	# the last: a double click on a card's Play (Drum Line: 2 plays) → one launch, one play spent
	qa.step = "card Play double click"
	g = await goto_guild()
	freeze_world(g, true)
	b = await open_board(g)
	var dl: Control = b.cards.get("drum-line")
	var play := find_text(dl, "Play")
	var left0 := MissionBoard.plays_left(app.mission("drum-line"), save.missions)
	var sc := QA.scroll_parent(dl)
	if sc != null:
		sc.ensure_control_visible(dl)
		await qa.frames(3)
	if play != null:
		await qa.dbl_click_at(qa.centre(play))
		await qa.until(func(): return flow.current == flow.Game and not flow.is_loading and current_scene != null, 90.0)
		await qa.wait(20, 1.0)
		var left1 := MissionBoard.plays_left(app.mission("drum-line"), save.missions)
		note("double click Play: plays ", left0, " → ", left1, " scene ", flow.current)
		if left1 != left0 - 1: qa.find("data", "card Play double click", "plays %d → %d" % [left0, left1])
		await qa.shot("ab_play_dbl")
