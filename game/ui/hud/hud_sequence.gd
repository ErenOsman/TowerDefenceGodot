class_name HudSequence
extends Control
## The level's speech (UI_SequenceBubble; UI Design Rules, Dialogue): story lines (no target, or Center) in the
## dialogue box at the bottom with the Princess's bust portrait; lines that point at something (a unit, a tile, a HUD
## element) in a speech bubble with a tail beside the target, following it (sequence_target_screen; a HUD target is
## found by node name, e.g. "EndTurnButton", and gets a soft pulsing ring; the board draws its own ring for world
## targets). Click → continue_sequence (a box line that waits for the game hides until the next line), Skip →
## skip_sequence. Full-rect and pointer-transparent; only the box / bubble take clicks.

## Finds a HUD element by name (set by the HUD): name -> Control or null.
var find_ui: Callable
## The first hand piece still in the hand (Control) or null; the action bar's button for "move" / "attack" or null.
var find_piece: Callable
var find_ability: Callable
var controller: LevelController

var dialogue: TdDialogueBox
var bubble: TdTextBubble
var _ring: Control
var _run: SequenceRun = null
var _version := -1
var _hidden_version := -1
var _pointing := false
var _mode_t := 1.0
var _clock := 0.0

func _init() -> void:
	name = "Sequence"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

const DIM_SHADER := """
shader_type canvas_item;
uniform vec2 area = vec2(1920.0, 1080.0);
uniform vec2 centre = vec2(-1000.0);
uniform float radius = 0.0;
uniform float alpha = 0.3;
void fragment() {
	float d = distance(UV * area, centre);
	COLOR = vec4(0.06, 0.04, 0.03, alpha * smoothstep(radius, radius + 48.0, d));
}
"""

## The dim behind a pointing bubble (~30 %), with a soft lit hole round the target.
var _dim: ColorRect

func _ready() -> void:
	_dim = ColorRect.new()
	_dim.mouse_filter = MOUSE_FILTER_IGNORE
	_dim.set_anchors_preset(PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = DIM_SHADER
	mat.shader = sh
	_dim.material = mat
	_dim.visible = false
	add_child(_dim)
	_ring = Control.new()
	_ring.mouse_filter = MOUSE_FILTER_IGNORE
	_ring.visible = false
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	dialogue = TdDialogueBox.new()
	dialogue.size = Vector2(1100, 220)
	dialogue.portrait_height = 520
	add_child(dialogue)
	dialogue.hide_line()
	dialogue.set_skip_key("")
	dialogue.clicked.connect(_on_dialogue_clicked)
	_wood_plate(dialogue)
	dialogue.skip_clicked.connect(func(): if controller != null: controller.skip_sequence())
	bubble = TdTextBubble.new()
	bubble.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bubble)
	bubble.hide_bubble()
	bubble.set_skip_key("")
	bubble.clicked.connect(func(): if controller != null: controller.continue_sequence())
	_wood_plate(bubble)
	bubble.skip_clicked.connect(func(): if controller != null: controller.skip_sequence())
	resized.connect(_layout)
	_layout()

## The speaker's plate in wood with the name in teal (cobalt is kept for what is active / selected).
static func _wood_plate(box: Control) -> void:
	var plate: Panel = box.get("_plate")
	var n: Label = box.get("_name")
	if plate != null: plate.add_theme_stylebox_override("panel", TdTheme.stylebox("dialogue_nameplate"))
	if n != null: n.add_theme_color_override("font_color", TdTheme.color("teal"))

func _layout() -> void:
	if dialogue == null: return
	dialogue.position = Vector2((size.x - dialogue.size.x) / 2.0, size.y - 212.0 - dialogue.size.y)

## The story box is up (the hand and bar step back).
func box_shown() -> bool:
	return dialogue != null and dialogue.is_shown() and not _pointing

func _process(delta: float) -> void:
	if controller == null: return
	var dt := TdTheme.unscaled(delta)
	_clock += dt
	var run: SequenceRun = controller.sequence
	var line: SequenceLine = run.current if run != null else null
	if line == null:
		if _run != null:
			dialogue.hide_line()
			bubble.hide_bubble()
		_ring.visible = false
		_dim.visible = false
		_run = null
		return
	line = effective_line(line)
	if run == _run and run.version == _hidden_version: return
	if run != _run or run.version != _version:
		_run = run
		_version = run.version
		_hidden_version = -1
		var point := line.point_at != SequencePointAt.Center and line.point_at != SequencePointAt.Nothing
		if point != _pointing: _mode_t = 0.0
		_pointing = point
		var portrait: Texture2D = HudArt.portrait_named("Princess") if line.speaker == SequenceSpeaker.Princess else null
		var waits := line.continue_on == SequenceContinue.Click
		var keys = get_tree().root.get_node_or_null("KeyBinds")
		var skip_key: String = keys.first("Skip") if keys != null else "Space"
		var how := HudText.how_it_goes_on(line.continue_on, line.wait_for, skip_key)
		var text := TooltipText.from_rich(line.text)
		if _pointing:
			dialogue.hide_line()
			bubble.show_line(_speaker(line), text, waits, portrait)
			bubble.set_hint("" if waits else how.trim_prefix("Click to hide. "), "Click or [b]%s[/b]" % skip_key if waits else "")
			var world = controller.sequence_target_world(line)
			if world != null and controller.camera != null and not controller.camera.in_view(world, 0.02): controller.camera.glide(world)
		else:
			bubble.hide_bubble()
			dialogue.show_line(_speaker(line), text, waits, portrait)
			var step := ""
			if run.count > 1: step = ("Tutorial · " if controller.is_tutorial else "") + "%d/%d" % [run.index + 1, run.count]
			dialogue.set_notes(step, how)
	_mode_t += dt
	var fade := clampf(_mode_t / 0.25, 0.0, 1.0)
	if _pointing:
		var spot = _target(line, false)
		# a HUD target always keeps it inside; a board target only while it is on screen (off screen it follows)
		var on_screen: bool = spot != null and Rect2(Vector2.ZERO, size).has_point(spot)
		bubble.keep_inside = line.point_at == SequencePointAt.UI or on_screen
		bubble.point_at(spot)
		bubble.modulate.a = fade
		var ui_rect = _ui_rect(line)
		var hole = ui_rect.get_center() if ui_rect != null else _target(line, true)
		var hole_r: float = (maxf(ui_rect.size.x, ui_rect.size.y) / 2.0 + 24.0) if ui_rect != null else 70.0
		# a line that waits for the player to act leaves the board lit (user, 2026-10-10): only the ring marks the target
		_set_dim(hole, hole_r, 0.0 if line.continue_on == SequenceContinue.Event else 0.3 * fade)
		_ring.visible = ui_rect != null
		if ui_rect != null:
			var side: float = maxf(ui_rect.size.x, ui_rect.size.y) + 40.0
			_ring.size = Vector2(side, side)
			_ring.position = ui_rect.get_center() - _ring.size / 2.0
			_ring.queue_redraw()
	else:
		_ring.visible = false
		_dim.visible = false
		dialogue.modulate.a = fade

func _set_dim(centre, radius: float, alpha: float) -> void:
	_dim.visible = alpha > 0.0
	var mat := _dim.material as ShaderMaterial
	mat.set_shader_parameter("area", size)
	mat.set_shader_parameter("centre", centre if centre != null else Vector2(-1000, -1000))
	mat.set_shader_parameter("radius", radius if centre != null else 0.0)
	mat.set_shader_parameter("alpha", alpha)

## The line as the HUD points it (the tutorial may be re-read freely; the words stay the content's):
## - a story line that waits for a tower to be placed points at the first piece still in the hand ("click its piece
##   in the tray");
## - a line that waits for a cast or a move points at what to click next: your tower while none is selected, then
##   the ability button it names (Tower Walk for a move, the first attack for a cast), then its own target.
func effective_line(line: SequenceLine) -> SequenceLine:
	if controller == null or controller.session == null or line.continue_on != SequenceContinue.Event: return line
	var w := line.wait_for
	var out: SequenceLine = null
	if w == SequenceEvent.TowerPlaced and line.point_at == SequencePointAt.Nothing and find_piece.is_valid() and find_piece.call() != null:
		out = line.with_text(line.text)
		out.point_at = SequencePointAt.UI
		out.ui_element = "@piece"
	elif w == SequenceEvent.TowerMoved or w == SequenceEvent.AbilityCast or w == SequenceEvent.QuickCast:
		var sel: Entity = controller.session.state.get_entity(controller.selected)
		var commanded := sel != null and controller.session.is_commanded(sel) and controller.session.tower_id_of(sel) != null
		if not commanded:
			out = line.with_text(line.text)
			out.point_at = SequencePointAt.FirstTower
		elif controller.aiming == null:
			out = line.with_text(line.text)
			out.point_at = SequencePointAt.UI
			out.ui_element = "@ability:" + ("move" if w == SequenceEvent.TowerMoved else "attack")
	if out == null: return line
	for k in ["speaker", "continue_on", "wait_for", "pauses_play", "seconds", "tile_x", "tile_y"]: out.set(k, line.get(k))
	return out

func _draw_ring() -> void:
	var r := _ring.size.x / 2.0 * (1.0 + 0.06 * sin(_clock * 4.0))
	var c := _ring.size / 2.0
	_ring.draw_arc(c, r, 0.0, TAU, 64, Color(TdTheme.color("gold.light"), 0.9), 5.0, true)
	_ring.draw_arc(c, r + 6.0, 0.0, TAU, 64, Color(TdTheme.color("gold"), 0.35), 6.0, true)

func _on_dialogue_clicked() -> void:
	if controller == null: return
	var run: SequenceRun = controller.sequence
	var line: SequenceLine = run.current if run != null else null
	if line != null and not _pointing and line.continue_on == SequenceContinue.Event:
		_hidden_version = run.version
		dialogue.hide_line()
		return
	controller.continue_sequence()

func _speaker(line: SequenceLine) -> String:
	if line.speaker == SequenceSpeaker.Princess: return "Princess"
	if controller.shown != null:
		for id in controller.session.bases:
			var f: EntityFrame = controller.shown.get_frame(id)
			if f != null and f.life == LifeState.Alive: return f.name
	return "Base"

## The point a bubble points at: a HUD element's top centre, else the controller's screen point for the line.
func _target(line: SequenceLine, ground: bool):
	if line.point_at == SequencePointAt.UI:
		var r = _ui_rect(line)
		if r == null: return null
		return Vector2(r.get_center().x, r.position.y if not ground else r.get_center().y)
	return controller.sequence_target_screen(line, ground)

func _ui_rect(line: SequenceLine):
	if line.point_at != SequencePointAt.UI or line.ui_element == "" or not find_ui.is_valid(): return null
	var c: Control = null
	if line.ui_element == "@piece": c = find_piece.call() if find_piece.is_valid() else null
	elif line.ui_element.begins_with("@ability:"): c = find_ability.call(line.ui_element.trim_prefix("@ability:")) if find_ability.is_valid() else null
	else: c = find_ui.call(line.ui_element)
	if c == null or not c.is_visible_in_tree(): return null
	return c.get_global_rect()
