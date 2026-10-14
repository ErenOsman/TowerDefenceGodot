extends SceneTree
## Proof that the hand editor's drag and drop works end to end with real mouse events (InputEventMouseButton /
## InputEventMouseMotion through Input.parse_input_event), after the TdCollection refactor:
##  1. reorder: drag hand slot 1 onto slot 3 → the tower moves to slot 3;
##  2. remove: drag a hand slot out of the strip (onto the filter column) → it leaves the hand;
##  3. add: drag a collection tile onto an empty slot → it joins the hand; the grid did not scroll;
##  4. drag-scroll: press on the gap between two tiles and drag up → the grid scrolls (TdDragScroll).
## Prints CHECK OK/FAIL lines and "DRAG CHECK n fails".
##   flock /home/ubuntu/godot/.td.lock ~/godot/run.sh /home/ubuntu/godot/projects/td -s tools/hand_drag_check.gd

var fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1
	print("CHECK %s %s" % ["OK" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n: await process_frame

var _last := Vector2.ZERO

func _motion(p: Vector2, held: bool) -> void:
	var m := InputEventMouseMotion.new()
	m.relative = p - _last # Godot counts the drag threshold from the relative motion
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

## A left-button drag from a to b in steps (Godot starts a drag-and-drop after a few px).
func _drag(a: Vector2, b: Vector2, steps := 12) -> void:
	await _motion(a, false)
	await _button(a, true)
	for i in range(1, steps + 1): await _motion(a.lerp(b, float(i) / steps), true)
	await _button(b, false)
	await _frames(6)

func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func _run() -> void:
	var save = root.get_node("SaveData")
	var app = root.get_node("GameApp")
	save.path = "user://hand_drag_check.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	save.load_data()
	app.ensure_loaded()
	for t in app.catalog.tower_types:
		for i in 4: save.towers.add(t.get_id())
	for i in 4: save.towers.add_to_hand(save.towers.towers[i * 4].id)
	save.save()
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var he: TdPopup = load("res://game/ui/screens/hand_editor.tscn").instantiate()
	host.add_child(he)
	he.open()
	await _frames(40)
	var hand: Array = save.towers.hand.duplicate()
	var p0 := _center(he._slots[0])
	await _motion(p0, false)
	print("hovered at slot 1: ", root.gui_get_hovered_control(), " slot: ", he._slots[0], " rect ", he._slots[0].get_global_rect())
	await _button(p0, true)
	for i in 6: await _motion(p0 + Vector2(0, 4 * (i + 1)), true)
	print("dragging: ", root.gui_is_dragging(), " focus ", root.gui_get_focus_owner())
	await _button(p0 + Vector2(0, 24), false)
	await _frames(4)
	# 1. reorder
	await _drag(_center(he._slots[0]), _center(he._slots[2]))
	_check(save.towers.hand.size() == 4 and save.towers.hand[2] == hand[0], "reorder: slot 1 dragged onto slot 3 → %s" % [save.towers.hand])
	# 2. remove: out of the strip, onto the filter column
	var leaving: String = save.towers.hand[0]
	var filters: Control = he.collection.get_child(0)
	await _drag(_center(he._slots[0]), _center(filters))
	_check(save.towers.hand.size() == 3 and not save.towers.hand.has(leaving), "remove: a slot dragged out of the strip → %s" % [save.towers.hand])
	# 3. add: a tile onto an empty slot
	var tile: TdTowerTile = null
	for id in he.collection.tiles:
		if not save.towers.hand.has(id):
			tile = he.collection.tiles[id]
			break
	var before_scroll: int = he.collection.grid_scroll.scroll_vertical
	var tid := tile.tower_id # the grid is rebuilt after the add: the tile is freed
	await _drag(_center(tile), _center(he._slots[5]))
	_check(save.towers.hand.has(tid), "add: tile %s dragged onto an empty slot → %s" % [tid, save.towers.hand])
	_check(he.collection.grid_scroll.scroll_vertical == before_scroll, "a tile drag does not scroll the grid")
	# 4. drag-scroll from the gap between the first two tiles of a lower row
	var g: GridContainer = he.collection.grid
	var a: TdTowerTile = g.get_child(g.columns * 2)
	var gap := Vector2(a.get_global_rect().end.x + 5.0, a.get_global_rect().get_center().y)
	await _drag(gap, gap + Vector2(0, -200), 16)
	_check(he.collection.grid_scroll.scroll_vertical > before_scroll, "drag on empty grid space scrolls (scroll %d → %d)" % [before_scroll, he.collection.grid_scroll.scroll_vertical])
	print("scrollbar width: ", he.collection.grid_scroll.get_v_scroll_bar().get_combined_minimum_size().x)
	print("DRAG CHECK %d fails" % fails)
	quit()
