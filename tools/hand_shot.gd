extends SceneTree
## Dev script: screenshots the hand editor (Hand select) under Xvfb.
##   ~/godot/run.sh projects/td -s tools/hand_shot.gd [-- <out dir>]
##   ~/godot/run.sh projects/td --resolution 1280x720 -s tools/hand_shot.gd -- user://hand720
## Uses its own save (user://hand_shot.json, deleted first): 3–5 towers of every type, a hand of 4.
## PNGs: <out dir>/hand_<n>_<step>.png — level (cap 4, "Two Roads"), plain (Camp), filtered, full, layout 3 renaming.

var out_dir := "user://hand"
var _n := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run.call_deferred()

func _run() -> void:
	var save = root.get_node("SaveData")
	var app = root.get_node("GameApp")
	save.path = "user://hand_shot.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	app.ensure_loaded()
	var counts := {"archer": 6, "guardian": 5, "mage": 4, "priest": 5, "wisp": 4, "ballista": 3, "alchemist": 4, "drummer": 3, "cannon": 3}
	for t in app.catalog.tower_types:
		var first := ""
		for i in counts.get(t.get_id(), 2):
			var o: OwnedTower = save.towers.add(t.get_id())
			if first == "": first = o.id
		if save.towers.hand.size() < 4 and t.get_id() in ["archer", "guardian", "priest", "wisp"]: save.towers.add_to_hand(first)
	save.save()
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	TdMenu.menu_background(host)
	var he: TdPopup = load("res://game/ui/screens/hand_editor.tscn").instantiate()
	host.add_child(he)
	he.set_level_context(4, "Two Roads")
	he.open()
	await _frames(40)
	he._select(save.towers.towers[2].id)
	await _frames(5)
	await _shot("level")
	he.close()
	await _frames(20)
	he.set_level_context(-1, "")
	he.open()
	await _frames(40)
	await _shot("plain")
	he._filter.roles = ["Support"]
	he._filter.cost_max = 200
	he._refresh_filters()
	he._refresh_grid()
	await _frames(5)
	await _shot("filtered")
	he.clear_filters()
	for o in save.towers.towers:
		if save.towers.hand.size() >= 8: break
		if not save.towers.hand.has(o.id) and o.type in ["alchemist", "ballista", "drummer", "mage", "cannon"] and not _has_type(save.towers, o.type):
			he.add(o.id)
	he._select(save.towers.towers[save.towers.towers.size() - 1].id)
	he.add(save.towers.towers[save.towers.towers.size() - 1].id)
	await _frames(5)
	he._say(HandLogic.FULL_REASON)
	await _frames(2)
	await _shot("full")
	he.switch_layout(2)
	he._renaming = 2
	he._refresh_layouts()
	await _frames(5)
	await _shot("layout3_renaming")
	print("hand: ", save.towers.hand.size(), " layouts: ", save.data.hand_layouts.map(func(l): return "%s %d" % [l.name, l.hand.size()]))
	quit()

func _has_type(towers: TowerCollection, type: String) -> bool:
	for id in towers.hand:
		if towers.find(id).type == type: return true
	return false

func _frames(n: int) -> void:
	for i in n: await process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	var p := "%s/hand_%02d_%s.png" % [out_dir, _n, label]
	root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p))
