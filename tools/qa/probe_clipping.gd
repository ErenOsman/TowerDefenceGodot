extends SceneTree
## Edge-clip probe (UI Design Rules — Design § Edge clip; docs/Implementation Notes.md § Edge clip (2026-10-17)):
## opens menu screens through SceneFlow and the screens' own openers (the same calls the QA tours and shot tools
## make), walks every visible Control of the top layer and reports
##   a  a Control whose rect (plus what it draws past it) leaves the rect of a clip_contents ancestor,
##   b  a Control that leaves its nearest card (PanelContainer / Panel with a drawn StyleBox),
##   c  the same caused by an overhang drawer: a portrait ring, ring line, Lv chip, form badge, a StyleBox's
##      outset / expand margins / shadow, a TdButton's bleed when it keeps none inside its rect.
## The rect math is tools/qa/clip_math.gd (tested by tests/test_clip_probe.gd).
##   cd ~/godot && ./jobs.sh --render shot tools/qa/probe_clipping.gd -- [screen …|all] [shots=<dir>]
## Screens (comma or space list; default all): main_menu, settings, codex, level_select, hand_editor, camp, guild,
##   mission_board, mission_detail, rewards, blacksmith, workshop, workshop_modify, upgrade, upgrade_view,
##   upgrade_view_form, backpack. settings probes its four tabs, codex its four sections (the towers page shows the
##   shared tower card).
## Output: one line per finding "<screen> <node path> <edge(s)> <px>  [check: what, ancestor]", then
## "PROBE CLIP SUMMARY …"; exit code 1 when anything is found. shots=<dir> saves a PNG of each screen probed.
## Own save (user://probe_clipping.json, deleted first): Chapters 1–2 won, a 5-tower hand, tokens, 240 gold, an
## Archer at level 2 with its step to 3 half done, an Archer wearing Fire Archer, Night Watch won once.
## The screens are untyped here: their classes name the GameApp autoload, which a SceneTree script cannot compile.

const ClipMath := preload("res://tools/qa/clip_math.gd")
const ALL := ["main_menu", "settings", "codex", "level_select", "hand_editor", "camp", "guild", "mission_board",
	"mission_detail", "rewards", "blacksmith", "workshop", "workshop_modify", "upgrade", "upgrade_view",
	"upgrade_view_form", "backpack"]

## True false positives: [screen ("*" any), node path substring, check ("*" any), why]. Keep each with its reason.
const WHITELIST := [
]

var save
var app
var flow
var screens: Array = []
var shots_dir := ""
var archers: Array = []
var total := 0
var per_screen := {}
var listed := 0
var _progress := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		for s in a.split(",", false):
			s = s.strip_edges()
			if s.begins_with("shots="): shots_dir = s.substr(6)
			elif s == "all": screens.append_array(ALL)
			elif s != "": screens.append(s)
	if screens.is_empty(): screens = ALL.duplicate()
	for s in screens:
		if not ALL.has(s):
			print("probe_clipping: unknown screen '%s' (known: %s)" % [s, ", ".join(ALL)])
			quit(2)
			return
	if shots_dir != "": DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots_dir))
	_run.call_deferred()
	_watchdog.call_deferred()

## A script error stops only the coroutine: no screen finished for 120 s → quit(2).
func _watchdog() -> void:
	while true:
		await create_timer(10.0, true, false, true).timeout
		if Time.get_ticks_msec() - _progress > 120000:
			print("probe_clipping: WATCHDOG, stuck after %s (a script error mid-await?)" % str(per_screen.keys()))
			quit(2)
			return

func _run() -> void:
	save = root.get_node("SaveData")
	app = root.get_node("GameApp")
	flow = root.get_node("SceneFlow")
	await _until(func(): return flow.current != flow.Boot and not flow.is_loading and current_scene != null, 60.0)
	_setup_save()
	_progress = Time.get_ticks_msec()
	Engine.max_fps = 60
	if shots_dir == "": RenderingServer.render_loop_enabled = false
	for s in screens: await _probe_screen(s)
	var parts := []
	for s in per_screen: parts.append("%s %d" % [s, per_screen[s]])
	print("PROBE CLIP SUMMARY: %d finding(s), %d whitelisted, %d screen(s) probed  (%s)" % [total, listed, per_screen.size(), ", ".join(parts)])
	RenderingServer.render_loop_enabled = true # quitting with the render loop off aborts the engine (core dump)
	await process_frame
	quit(1 if total > 0 else 0)

# ------------------------------------------------------------------ save

func _setup_save() -> void:
	save.path = "user://probe_clipping.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	save.begin("Eren", false)
	app.ensure_loaded()
	save.towers.hand.clear()
	archers = []
	for i in 3: archers.append(save.towers.add("archer"))
	for id in ["guardian", "mage", "priest"]: save.towers.add_to_hand(save.towers.add(id).id)
	for i in 2: save.towers.add_to_hand(archers[i].id)
	for pair in [["fire-arrow", 2], ["arcane-shard", 3], ["ember-core", 1]]:
		SaveTools.run("add_tokens", save.data, app.catalog, pair)
	app.complete_chapter1()
	app.complete_chapter2()
	var p = save.profile
	p.camp_seen = true
	p.guild_seen = true
	for f in ["guild_tour_seen", "blacksmith_seen"]:
		if f in p: p.set(f, true)
	save.data.gold = 240
	var nw = app.mission("night-watch")
	if nw != null:
		var r := LevelResult.new()
		r.level_id = nw.level_id
		r.won = true
		r.rounds = 9
		r.base_hp_pct = 80
		save.missions.record(r, nw.id)
	# Archer 1: level 2, its step to 3 half done (the Upgrade view with bars and Pay)
	var a1 = archers[0]
	a1.level = 2
	var t = app.tower_type("archer")
	var step = TowerLevels.step_for(a1, t, "")
	if step != null:
		var counts := []
		for i in step.tasks.size(): counts.append(0)
		if counts.size() > 0: counts[0] = 1
		if counts.size() > 2: counts[1] = 42
		var gi := TowerTasks.gold_task_index(step)
		if gi >= 0: counts[gi] = 25
		a1.task_progress[TowerLevels.step_key("", step.to)] = counts
	# Archer 2: level 3, wearing Fire Archer (badge, tint ring)
	var a2 = archers[1]
	a2.level = 3
	a2.forms = ["archer-fire"]
	a2.form = "archer-fire"
	for id in ["slime", "runner", "big-slime"]: save.codex.discover(CodexSection.Enemies, id)
	for id in ["burn", "shield", "taunted"]: save.codex.discover(CodexSection.Statuses, id)
	save.save()

# ------------------------------------------------------------------ openers

func _probe_screen(s: String) -> void:
	match s:
		"main_menu":
			var mm = await _go(flow.MainMenu)
			await _check(s, mm)
		"settings":
			var mm = await _go(flow.MainMenu)
			var st = mm.open_popup("settings")
			await _settle()
			for i in st.pages.size():
				if OS.has_feature("web") and i == 1: continue
				st.show_tab(i)
				await _settle(0.4)
				await _check("settings:%d" % i, st)
			st.close()
		"codex":
			var mm = await _go(flow.MainMenu)
			var cx = mm.open_popup("codex")
			await _settle()
			var names := ["towers", "enemies", "statuses", "tips"]
			for i in cx.SECTIONS.size():
				cx.show_section(cx.SECTIONS[i])
				await _settle(0.5)
				await _check("codex:" + names[i], cx)
			cx.close()
		"level_select":
			var ls = await _go(flow.LevelSelect)
			await _check(s, ls)
		"hand_editor":
			var ls = await _go(flow.LevelSelect)
			var he = ls.open_hand_editor()
			await _settle()
			await _check(s, he)
			he.close()
		"camp":
			var c = await _camp()
			await _check(s, c)
		"backpack":
			var c = await _camp()
			var bp = c.backpack_button.open_backpack()
			await _settle()
			await _check(s, bp)
			bp.close()
		"guild":
			var g = await _guild()
			await _check(s, g)
		"mission_board", "mission_detail", "rewards":
			var g = await _guild()
			var b = g.open_missions()
			await _settle(1.2)
			if s == "mission_board": await _check(s, b)
			elif s == "rewards":
				var rw = b.open_rewards("night-watch")
				await _settle()
				await _check(s, rw)
				rw.close()
			else:
				var d = b.open_detail("night-watch")
				await _settle(1.2)
				await _check(s, d)
				d.close()
			await _settle(0.3)
			b.close()
		"blacksmith":
			var sm = await _smithy()
			await _check(s, sm)
		"workshop", "workshop_modify":
			var sm = await _smithy()
			var ws = sm.open_modify()
			await _settle()
			if s == "workshop_modify":
				ws.open_modify(archers[0].id)
				await _settle(1.0)
			await _check(s, ws)
			ws.close()
		"upgrade", "upgrade_view", "upgrade_view_form":
			var sm = await _smithy()
			var up = sm.open_upgrade()
			await _settle()
			if s != "upgrade":
				up.open_view(archers[0 if s == "upgrade_view" else 1].id)
				await _settle(1.0)
			await _check(s, up)
			up.close()
	await _settle(0.4)

func _go(id: int) -> Node:
	_close_popups()
	if flow.current != id or current_scene == null:
		for attempt in 3:
			await _until(func(): return not flow.is_loading, 60.0)
			flow.go(id)
			if await _until(func(): return flow.current == id and not flow.is_loading and current_scene != null, 60.0): break
		await _settle(1.2)
	return current_scene

func _camp() -> Node:
	var c = await _go(flow.Camp)
	if c.welcome_card.visible: c.close_welcome()
	if c.tour_step >= 0: c.end_tour()
	await _settle(0.3)
	return c

func _guild() -> Node:
	var g = await _go(flow.Guild)
	if g.welcome_card.visible: g.close_welcome()
	await _settle(0.3)
	return g

func _smithy() -> Node:
	var b = await _go(flow.Blacksmith)
	if b.get("welcome_card") != null and b.welcome_card.visible: b.close_welcome()
	if b.has_method("end_tour"): b.end_tour()
	await _settle(0.3)
	return b

func _close_popups() -> void:
	for i in range(TdPopup.open_popups.size() - 1, -1, -1):
		var p = TdPopup.open_popups[i]
		if is_instance_valid(p) and p.is_inside_tree() and p != current_scene and p.has_method("close"): p.close()

# ------------------------------------------------------------------ the check

## Walks the screen's top layer (the top open popup above `fallback`, else `fallback`) and prints its findings.
func _check(screen: String, fallback: Node) -> void:
	var top: Node = fallback
	for i in range(TdPopup.open_popups.size() - 1, -1, -1):
		var p = TdPopup.open_popups[i]
		if is_instance_valid(p) and p.is_inside_tree() and p.visible:
			top = p
			break
	if top == null:
		print("%s (not opened)" % screen)
		per_screen[screen] = -1
		return
	var recs := ClipMath.collect(top)
	var finds := ClipMath.findings(recs)
	var n := 0
	for f in finds:
		var why := _whitelisted(screen, f)
		if why != "":
			listed += 1
			continue
		print(ClipMath.line(screen, f))
		n += 1
	per_screen[screen] = n
	total += n
	_progress = Time.get_ticks_msec()
	print("PROBE %s: %d control(s), %d finding(s)" % [screen, recs.size(), n])
	if shots_dir != "":
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/probe_%s.png" % [shots_dir, screen.replace(":", "_")])

func _whitelisted(screen: String, f: Dictionary) -> String:
	for w in WHITELIST:
		if (w[0] == "*" or w[0] == screen or screen.begins_with(w[0] + ":")) and String(f.path).contains(w[1]) and (w[2] == "*" or w[2] == f.check):
			return w[3]
	return ""

# ------------------------------------------------------------------ time

func _settle(seconds := 0.9) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until: await process_frame
	await process_frame
	await process_frame

func _until(cond: Callable, seconds: float) -> bool:
	var t := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t > seconds * 1000.0: return false
		await process_frame
	return true
