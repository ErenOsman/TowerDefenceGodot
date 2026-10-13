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
## The guided tutorial: extra board rings (every lit tile), the shake on a refused action, the text kept when only
## the target changes.
var _tile_rings: Control
var _tile_ring_points: Array = []
var _refusals := 0
var _shake_t := 1.0
var _shown_text := ""

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
var _medal: Control
## How far the bubble's speaker plate and medallion reach above its box.
const BUBBLE_HEAD := 34.0

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
	_tile_rings = Control.new()
	_tile_rings.mouse_filter = MOUSE_FILTER_IGNORE
	_tile_rings.set_anchors_preset(PRESET_FULL_RECT)
	_tile_rings.draw.connect(_draw_tile_rings)
	add_child(_tile_rings)
	dialogue = TdDialogueBox.new()
	dialogue.size = Vector2(1100, 220)
	# no bust beside the box: the Princess stands on the board (the board's speaker prop); only a small medallion
	# on the name plate, as in the Unity build
	_medal = HudArt.medallion(52, "medallion_ring", 5)
	_medal.position = Vector2(-4, -36)
	_medal.visible = false
	add_child(dialogue)
	dialogue.hide_line()
	(dialogue.get("_content") as Control).add_child(_medal) # hides with the box
	dialogue.set_skip_key("")
	dialogue.clicked.connect(_on_dialogue_clicked)
	_wood_plate(dialogue)
	dialogue.skip_clicked.connect(func(): if controller != null: controller.skip_sequence())
	bubble = TdTextBubble.new()
	bubble.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bubble)
	bubble.offset_top = HudLayout.TOP_BAR + 16.0 + BUBBLE_HEAD - bubble.margin
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
		_shown_text = ""
		_tile_ring_points.clear()
		_tile_rings.queue_redraw()
		return
	line = effective_line(line)
	_guided_marks(line, dt)
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
		var guided := _guided()
		if _pointing:
			dialogue.hide_line()
			var same := guided != null and text == _shown_text and bubble.is_shown()
			bubble.show_line(_speaker(line), text, waits, portrait)
			if same: bubble.reveal_all() # only the target moved (the guided tutorial's next click): no retyping
			if guided != null:
				var note := "Tutorial · %d/%d" % [run.index + 1, run.count] if line.continue_on != SequenceContinue.Seconds else ""
				bubble.set_hint(note, "Click or [b]%s[/b]" % skip_key if waits else "")
			else:
				bubble.set_hint("" if waits else how.trim_prefix("Click to hide. "), "Click or [b]%s[/b]" % skip_key if waits else "")
			_shown_text = text
			var world = controller.sequence_target_world(line)
			if world != null and controller.camera != null and not controller.camera.in_view(world, 0.02): controller.camera.glide(world)
		else:
			bubble.hide_bubble()
			_shown_text = ""
			dialogue.show_line(_speaker(line), text, waits, null)
			_medal.visible = portrait != null
			HudArt.set_medallion(_medal, portrait)
			var step := ""
			if run.count > 1: step = ("Tutorial · " if controller.is_tutorial else "") + "%d/%d" % [run.index + 1, run.count]
			dialogue.set_notes(step, how)
	_mode_t += dt
	var fade := clampf(_mode_t / 0.25, 0.0, 1.0)
	if _pointing:
		var spot = _target(line, false)
		if spot != null and line.point_at != SequencePointAt.UI:
			var box_h: float = bubble.box_rect().size.y
			var top: float = bubble.global_position.y + bubble.margin
			if spot.y - bubble.gap - box_h < top:
				var feet = _target(line, true)
				if feet != null: spot = feet + Vector2(0, 12)
		# a HUD target always keeps it inside; a board target only while it is on screen (off screen it follows)
		var on_screen: bool = spot != null and Rect2(Vector2.ZERO, size).has_point(spot)
		bubble.keep_inside = line.point_at == SequencePointAt.UI or on_screen
		bubble.point_at(spot)
		bubble.position.x = _shake_offset()
		bubble.modulate.a = fade
		var ui_rect = _ui_rect(line)
		var hole = ui_rect.get_center() if ui_rect != null else _target(line, true)
		var hole_r: float = (maxf(ui_rect.size.x, ui_rect.size.y) / 2.0 + 24.0) if ui_rect != null else 70.0
		# a line that waits for the player to act leaves the board lit (user, 2026-10-10): only the ring marks the target
		_set_dim(hole, hole_r, 0.0 if line.continue_on == SequenceContinue.Event else 0.3 * fade)
		_board_ring(line, ui_rect == null)
		_ring.visible = ui_rect != null
		if ui_rect != null:
			var r := HudSequence.ring_rect(ui_rect, size)
			_ring.position = r.position + Vector2(_shake_offset(), 0)
			_ring.size = r.size
			_ring.queue_redraw()
	else:
		_ring.visible = false
		_dim.visible = false
		_board_ring(null, false)
		dialogue.modulate.a = fade

## Exactly one light ring per line: the board's ring (sequence marks) goes round the world target the bubble
## points at, and is off while the bubble points at a HUD element (that ring is the HUD's). The HUD processes after
## the controller, so this replaces the ring it set for the line's original point-at.
func _board_ring(line, world: bool) -> void:
	if controller == null or controller.overlay == null or controller.overlay.sequence == null: return
	if line == null or not world:
		controller.overlay.sequence.set_target(null, false)
		return
	var at = controller.sequence_target_screen(line, true)
	var zoom: float = WorldUi.readable(controller.camera.zoom_factor()) if controller.camera != null else 1.0
	controller.overlay.sequence.set_target(at, false, null, Vector2(120, 64) * zoom)

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
	var guided := _guided()
	if guided != null: # the guided tutorial points where its step needs the player next
		var shown := guided.display_line()
		return shown if shown != null else line
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

## The HUD ring's rect: the element grown 10 px, kept 4 px inside the screen (never cut by its edge).
static func ring_rect(target: Rect2, screen: Vector2) -> Rect2:
	var r := target.grow(10.0)
	var inside := Rect2(Vector2(4, 4), screen - Vector2(8, 8))
	return r.intersection(inside) if inside.intersects(r) else r

func _draw_ring() -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * 4.0)
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.set_corner_radius_all(int(minf(_ring.size.x, _ring.size.y) / 2.0))
	box.set_border_width_all(5)
	box.border_color = Color(TdTheme.color("gold.light"), 0.75 + 0.25 * pulse)
	box.shadow_color = Color(TdTheme.color("gold"), 0.35 * pulse)
	box.shadow_size = 8
	box.anti_aliasing = true
	_ring.draw_style_box(box, Rect2(Vector2.ZERO, _ring.size))

## The guided tutorial while it runs, else null.
func _guided() -> GuidedTutorial:
	if controller == null or controller.guided == null or controller.guided.finished: return null
	return controller.guided

## The guided tutorial's extra marks: a ring on every lit tile besides the one the bubble points at, and a shake of
## the ringed target and the bubble when an action was refused.
func _guided_marks(line: SequenceLine, dt: float) -> void:
	var guided := _guided()
	_tile_ring_points.clear()
	if guided != null:
		if guided.refusals != _refusals:
			_refusals = guided.refusals
			_shake_t = 0.0
			var target := _ui_control(line)
			if target is HudHandPiece: (target as HudHandPiece).deny("")
			elif target is TdButton: (target as TdButton).shake()
		var pointed := Vector2i(line.tile_x, line.tile_y) if line.point_at == SequencePointAt.Tile else Vector2i(-99, -99)
		for t in guided.ring_tiles():
			if t == pointed or controller.camera == null: continue
			var w := GridSpace.to_world(t) + Vector3.UP * 0.05
			if controller.camera.is_position_behind(w): continue
			_tile_ring_points.append(controller.camera.unproject_position(w))
	_shake_t = minf(1.0, _shake_t + dt / 0.32)
	_tile_rings.queue_redraw()

## The refusal shake (±7 px, like a denied hand piece), 0 when still.
func _shake_offset() -> float:
	return sin(_shake_t * TAU * 4.0) * 7.0 * (1.0 - _shake_t) if _shake_t < 1.0 else 0.0

## The soft light rings of the board marks (SequenceMarks' look) round each extra lit tile.
func _draw_tile_rings() -> void:
	if _tile_ring_points.is_empty(): return
	var zoom: float = WorldUi.readable(controller.camera.zoom_factor()) if controller != null and controller.camera != null else 1.0
	var half := Vector2(120, 64) * zoom * (1.0 + 0.08 * sin(_clock * 4.0)) * 0.5
	for c in _tile_ring_points:
		var pts := PackedVector2Array()
		for i in 49:
			var a := i * TAU / 48.0
			pts.append(c + Vector2(_shake_offset() + cos(a) * half.x, sin(a) * half.y))
		for k in [[22.0, 0.07], [15.0, 0.12], [9.0, 0.2], [4.0, 0.35], [2.0, 0.55]]:
			_tile_rings.draw_polyline(pts, Color(1.0, 0.94, 0.72, k[1]), k[0], true)

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
	var c := _ui_control(line)
	return c.get_global_rect() if c != null else null

## The HUD element a line points at (shown), or null.
func _ui_control(line: SequenceLine) -> Control:
	if line.point_at != SequencePointAt.UI or line.ui_element == "" or not find_ui.is_valid(): return null
	var c: Control = null
	if line.ui_element == "@piece": c = find_piece.call() if find_piece.is_valid() else null
	elif line.ui_element.begins_with("@ability:"): c = find_ability.call(line.ui_element.trim_prefix("@ability:")) if find_ability.is_valid() else null
	else: c = find_ui.call(line.ui_element)
	if c == null or not c.is_visible_in_tree(): return null
	return c
