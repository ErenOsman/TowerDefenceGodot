class_name TdPanelTransition
extends RefCounted
## Open and close motion for a panel (port of PanelTransition; UI rules: windows open in 0.25 s with fade + scale from
## 0.96, close faster): open() fades the content in and scales it up from 0.96 over motion.normal (ease out); close()
## animates out over motion.quick (ease in-out) then hides it (or calls on_done). Unscaled time, so it plays while
## the game is paused or sped up. Scales around the control's centre.
##   TdPanelTransition.open(control), TdPanelTransition.close(control, on_done := Callable()),
##   TdPanelTransition.is_closing(control)

const START_SCALE := 0.96
const META := "_td_panel_tween"

static func open(c: Control, start_scale := START_SCALE) -> Tween:
	_kill(c)
	c.visible = true
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ONE * start_scale
	c.modulate.a = 0.0
	var tw := TdTheme.tween(c)
	tw.set_parallel(true)
	TdTheme.ease_tweener(tw.tween_property(c, "scale", Vector2.ONE, TdTheme.motion("normal")), "out")
	TdTheme.ease_tweener(tw.tween_property(c, "modulate:a", 1.0, TdTheme.motion("normal")), "out")
	c.set_meta(META, tw)
	return tw

static func close(c: Control, on_done := Callable(), end_scale := START_SCALE) -> Tween:
	_kill(c)
	c.pivot_offset = c.size / 2.0
	var tw := TdTheme.tween(c)
	tw.set_parallel(true)
	TdTheme.ease_tweener(tw.tween_property(c, "scale", Vector2.ONE * end_scale, TdTheme.motion("quick")), "in_out")
	TdTheme.ease_tweener(tw.tween_property(c, "modulate:a", 0.0, TdTheme.motion("quick")), "in_out")
	tw.chain().tween_callback(func() -> void:
		c.visible = false
		c.scale = Vector2.ONE
		c.modulate.a = 1.0
		c.remove_meta(META)
		if on_done.is_valid(): on_done.call())
	c.set_meta(META, tw)
	return tw

static func is_closing(c: Control) -> bool:
	if not c.has_meta(META): return false
	var tw: Tween = c.get_meta(META)
	return tw != null and tw.is_valid() and tw.is_running() and c.modulate.a < 1.0 and c.visible

static func _kill(c: Control) -> void:
	if c.has_meta(META):
		var tw: Tween = c.get_meta(META)
		if tw != null and tw.is_valid(): tw.kill()
		c.remove_meta(META)
	c.scale = Vector2.ONE
	c.modulate.a = 1.0
