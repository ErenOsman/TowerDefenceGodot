extends "res://tools/qa/level_tour.gd"
## Probe (Eren 2026-10-17): with a placed, selected tower, a real click on its TRAY piece moved the camera to the
## board's top-left and cleared the selection. Prints the camera focus and the selection around that click.
func _run() -> void:
	_save()
	if not await _start_level("chapter1-1"): return
	await wait(1.0)
	if level.sequence != null: level.skip_sequence()
	await settle(); park(); await wait(0.3)
	var arch := piece_for("archer")
	await click_control(arch); await wait(0.3)
	var tiles := build_tiles(1, arch.tower_id)
	print("placing=", level.placing, " tiles=", tiles)
	await click(tile_screen(tiles[0])); await wait(0.6)
	var archer: Entity = level.session.placed_tower(arch.tower_id)
	print("placed id=", archer.id if archer else -1, " selected=", level.selected, " focus=", level.camera.focus_target)
	# select it by a real click on the board
	await click(tile_screen(archer.pos)); await wait(0.5)
	print("after board click: selected=", level.selected, " focus=", level.camera.focus_target)
	park(); await wait(0.3)
	var f0 = level.camera.focus_target
	await click_control(arch); await wait(0.8)
	print("after TRAY click: selected=", level.selected, " focus=", level.camera.focus_target, " moved=", (level.camera.focus_target - f0).length(), " placing=", level.placing)
	_flush_log(); quit(0)
