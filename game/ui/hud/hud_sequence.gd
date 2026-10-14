class_name HudSequence
extends Control
## The level's speech (UI_SequenceBubble; UI Design Rules, Dialogue): story lines (no target, or Center) in the
## dialogue box at the bottom with the Princess's bust portrait; lines that point at something (a unit, a tile, a HUD
## element) in a speech bubble with a tail beside the target, following it (sequence_target_screen; a HUD target is
## found by node name, e.g. "EndTurnButton", and gets a soft pulsing ring; the board draws its own ring for world
## targets). Click → continue_sequence (a box line that waits for the game hides until the next line), Skip →
## skip_sequence. Full-rect and pointer-transparent; only the box / bubble take clicks.
## The guided tutorial (controller.guided) speaks ONLY through the dialogue box, every step (Guided Tutorial — Design):
## talk steps wait for a click / Space ("Click or press Space" bottom-left), action steps keep the instruction up while
## the ring marks the target and the bottom-left note names the allowed action; a refusal replaces that note for 2 s in
## the warning colour; "Tutorial · n/N" bottom-right. The box docks at the top for a step whose ringed target would lie
## under it (dialogue_rect). One owner: controller.sequence is either the guided run or the level's own sequence, never
## both, and both go through this one box.

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
## The guided tutorial: the piece's own ring (under its badges), the shake and the "Not now" note on a refused action,
## the text kept when only the target changes, the box docked at the top.
var _piece_ring: Control
var _refusals := 0
var _shake_t := 1.0
var _shown_text := ""
var _note := ""
var _note_right := ""
var _refusal_until := -1.0
var _dock_top := false
var _guided_index := -1
## The guided step whose box the player clicked away (the free-play line), -1 = none.
var _hidden_step := -1
## The board ring's size (canvas px at zoom 1); the bubble's tail ends on its edge.
const BOARD_RING := Vector2(120, 64)
## The piece ring stands this far outside the hand piece.
const PIECE_RING_OUT := 8.0
## The dialogue box's bottom edge stands this far above the screen's (the hand tray and the bar stay clear under it).
const BOX_BOTTOM := 212.0
## Docked at the top: the box's top edge (its name plate and Skip reach 30 px higher, still under the top bar).
const BOX_TOP := HudLayout.TOP_BAR + 40.0
## The air kept between the box (with its plate and Skip) and a ringed target.
const DOCK_MARGIN := 8.0
## Once docked at the top, the target must clear the bottom area by this much more before the box goes back down.
const DOCK_HYSTERESIS := 24.0
## How long a refusal stays in the note's place (seconds, unscaled).
const REFUSAL_SECONDS := 2.0

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
	_piece_ring = Control.new()
	_piece_ring.name = "TutorialRing"
	_piece_ring.mouse_filter = MOUSE_FILTER_IGNORE
	_piece_ring.draw.connect(_draw_piece_ring)
	dialogue = TdDialogueBox.new()
	dialogue.size = Vector2(1100, 160) # shorter than the kit's 220 (Eren 2026-10-14: "tutorial paneli daha kısa olsun")
	# no bust beside the box: the Princess stands on the board (the board's speaker prop); only a small medallion
	# on the name plate, as in the Unity build
	_medal = HudArt.medallion(52, "medallion_ring", 5)
	(_medal.get_node("Ring") as TextureRect).texture = HudSequence.teal_ring("medallion_ring")
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
	var medal_ring = bubble.get("_medal_ring")
	if medal_ring is TextureRect: medal_ring.texture = HudSequence.teal_ring("medal_ring") # the Princess: teal, not cobalt
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
	if dialogue == null or _guided() != null: return # the guided tutorial places the box itself (dialogue_rect)
	dialogue.position = HudSequence.dialogue_rect(size, dialogue.size, null).position

## Where the dialogue box goes (canvas px): centred, its bottom edge BOX_BOTTOM above the screen's; docked at the top
## (top edge BOX_TOP) when `target` (the ringed target's screen rect, or null) would lie under the bottom box, its
## name plate / Skip or DOCK_MARGIN round them. `was_top`: it is docked at the top now — it stays there until the
## target clears the bottom area by DOCK_HYSTERESIS more (no flicker while the camera glides). When both places
## would cover the target, the one covering less of it.
static func dialogue_rect(screen: Vector2, box: Vector2, target, was_top := false) -> Rect2:
	var x := (screen.x - box.x) / 2.0
	var bottom := Rect2(x, screen.y - BOX_BOTTOM - box.y, box.x, box.y)
	var top := Rect2(x, BOX_TOP, box.x, box.y)
	if not (target is Rect2): return bottom
	var t: Rect2 = target
	var keep := DOCK_MARGIN + (DOCK_HYSTERESIS if was_top else 0.0)
	var bottom_hit := HudSequence.box_area(bottom, keep).intersection(t).get_area() if HudSequence.box_area(bottom, keep).intersects(t) else 0.0
	if bottom_hit <= 0.0: return bottom
	var top_hit := HudSequence.box_area(top, DOCK_MARGIN).intersection(t).get_area() if HudSequence.box_area(top, DOCK_MARGIN).intersects(t) else 0.0
	if top_hit <= 0.0: return top
	var bottom_plain := HudSequence.box_area(bottom, DOCK_MARGIN)
	var bottom_cover := bottom_plain.intersection(t).get_area() if bottom_plain.intersects(t) else 0.0
	return top if top_hit < bottom_cover else bottom

## What a box at `r` covers: the box, its name plate and Skip over the top edge, and `margin` all round.
static func box_area(r: Rect2, margin: float) -> Rect2:
	return Rect2(r.position - Vector2(margin, TdDialogueBox.OVERHANG + margin), r.size + Vector2(margin * 2.0, TdDialogueBox.OVERHANG + margin * 2.0))

## The story box is up (the hand and bar step back; not on a guided action step: the target may be in the tray).
func box_shown() -> bool:
	if dialogue == null or not dialogue.is_shown(): return false
	var guided := _guided()
	if guided != null: return guided.talking
	return not _pointing

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
		_place_piece_ring(null)
		return
	line = effective_line(line)
	var guided := _guided()
	if guided != null:
		_process_guided(guided, run, line, dt)
		return
	if run == _run and run.version == _hidden_version: return
	if run != _run or run.version != _version:
		_run = run
		_version = run.version
		_hidden_version = -1
		_hidden_step = -1
		var point := line.point_at != SequencePointAt.Center and line.point_at != SequencePointAt.Nothing
		if point != _pointing: _mode_t = 0.0
		_pointing = point
		var portrait: Texture2D = HudArt.portrait_named("Princess") if line.speaker == SequenceSpeaker.Princess else null
		var waits := line.continue_on == SequenceContinue.Click
		var skip_key := _skip_key()
		var how := HudText.how_it_goes_on(line.continue_on, line.wait_for, skip_key)
		var text := TooltipText.from_rich(line.text)
		bubble.box_width = 540.0
		if _pointing:
			dialogue.hide_line()
			bubble.show_line(_speaker(line), text, waits, portrait)
			bubble.set_hint("" if waits else how.trim_prefix("Click to hide. "), "Click or " + HudSequence.key_chip(skip_key) if waits else "")
			_shown_text = text
			var world = controller.sequence_target_world(line)
			if world != null and controller.camera != null and not controller.camera.in_view(world, 0.02): controller.camera.glide(world)
		else:
			bubble.hide_bubble()
			_shown_text = ""
			_layout()
			dialogue.set_step_warning(false)
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
		bubble.tail_to_target = false
		bubble.target_below = null
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
		bubble.position.x = 0.0
		bubble.modulate.a = fade
		var ui_rect = _ui_rect(line)
		var hole = ui_rect.get_center() if ui_rect != null else _target(line, true)
		var hole_r: float = (maxf(ui_rect.size.x, ui_rect.size.y) / 2.0 + 24.0) if ui_rect != null else 70.0
		# a line that waits for the player to act leaves the board lit (user, 2026-10-10): only the ring marks the target
		_set_dim(hole, hole_r, 0.0 if line.continue_on == SequenceContinue.Event else 0.3 * fade)
		_board_ring(line, ui_rect == null)
		_place_piece_ring(null)
		_place_hud_ring(ui_rect)
	else:
		_ring.visible = false
		_dim.visible = false
		_board_ring(null, false)
		_place_piece_ring(null)
		dialogue.modulate.a = fade

## The guided tutorial's step in the dialogue box (never the bubble): the line (retyped only when its words change),
## the notes ("Click or press Space" / the allowed action left, "Tutorial · n/N" right), the one ring on what the step
## needs next, the dim on a talk step that points at something, and the box docked away from the ringed target.
func _process_guided(guided: GuidedTutorial, run: SequenceRun, line: SequenceLine, dt: float) -> void:
	if run != _run or run.version != _version:
		var new_step := run != _run or run.index != _guided_index
		_run = run
		_version = run.version
		_hidden_version = -1
		_guided_index = run.index
		if new_step:
			_hidden_step = -1
			_dock_top = false
		bubble.hide_bubble()
		_pointing = line.point_at != SequencePointAt.Center and line.point_at != SequencePointAt.Nothing
		var waits := line.continue_on == SequenceContinue.Click
		var text := _color_tower_names(TooltipText.from_rich(line.text))
		if text != _shown_text or not dialogue.is_shown():
			if not dialogue.is_shown(): _mode_t = 0.0
			dialogue.show_line(_speaker(line), text, waits, null)
			var portrait: Texture2D = HudArt.portrait_named("Princess") if line.speaker == SequenceSpeaker.Princess else null
			_medal.visible = portrait != null
			HudArt.set_medallion(_medal, portrait)
		_shown_text = text
		if waits: _note = HudText.how_it_goes_on(SequenceContinue.Click, line.wait_for, _skip_key())
		elif not guided.hides_card: _note = "Click to hide" # the free-play line: the player may put it away
		else: _note = guided.action_note()
		_note_right = "Tutorial · %d/%d" % [run.index + 1, run.count]
		_refusal_until = -1.0
		_set_note(_note, false)
		var world = controller.sequence_target_world(line)
		if world != null and controller.camera != null and not controller.camera.in_view(world, 0.02): controller.camera.glide(world)
	_guided_marks(guided, line, dt)
	if _hidden_step == run.index:
		if dialogue.is_shown(): dialogue.hide_line()
		_shown_text = ""
	_mode_t += dt
	var fade := clampf(_mode_t / 0.25, 0.0, 1.0)
	var ui_rect = _ui_rect(line)
	var piece := _ui_control(line) as HudHandPiece
	_place_piece_ring(piece)
	_place_hud_ring(ui_rect if piece == null else null)
	_board_ring(line, ui_rect == null and line.point_at != SequencePointAt.UI)
	# a talk step that shows something dims the rest a little (a soft lit hole round it); an action step leaves the
	# board lit (user, 2026-10-10): only the ring marks the target
	var hole = ui_rect.get_center() if ui_rect != null else (_target(line, true) if _pointing else null)
	var hole_r: float = (maxf(ui_rect.size.x, ui_rect.size.y) / 2.0 + 24.0) if ui_rect != null else 70.0
	_set_dim(hole, hole_r, 0.3 * fade if guided.talking and hole != null and dialogue.is_shown() else 0.0)
	var r := HudSequence.dialogue_rect(size, dialogue.size, _guided_target_rect(line), _dock_top)
	_dock_top = r.position.y < size.y * 0.5
	dialogue.position = r.position + Vector2(_shake_offset(), 0)
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
	controller.overlay.sequence.set_target(at, false, null, BOARD_RING * _ring_zoom())

func _ring_zoom() -> float:
	return WorldUi.readable(controller.camera.zoom_factor()) if controller != null and controller.camera != null else 1.0

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

## The guided tutorial's refusal: the ringed target and the box shake, and the refusal takes the bottom-left note's
## place (warning colour, REFUSAL_SECONDS) — the hint line under the bar is hidden while the tutorial speaks (one voice).
func _guided_marks(guided: GuidedTutorial, line: SequenceLine, dt: float) -> void:
	if guided.refusals != _refusals:
		_refusals = guided.refusals
		_shake_t = 0.0
		var target := _ui_control(line)
		if target is HudHandPiece: (target as HudHandPiece).deny("")
		elif target is TdButton: (target as TdButton).shake()
		_refusal_until = _clock + REFUSAL_SECONDS
		_set_note(guided.last_hint, true)
	elif _refusal_until >= 0.0 and _clock >= _refusal_until:
		_refusal_until = -1.0
		_set_note(_note, false)
	_shake_t = minf(1.0, _shake_t + dt / 0.32)

## The box's notes: `text` bottom-left (a refusal in the warning colour), the step counter bottom-right.
func _set_note(text: String, refusal: bool) -> void:
	dialogue.set_step_warning(refusal)
	dialogue.set_notes(text, _note_right)

## The Skip action's key (the continue key: Space by default).
func _skip_key() -> String:
	var keys = get_tree().root.get_node_or_null("KeyBinds") if is_inside_tree() else null
	return keys.first("Skip") if keys != null else "Space"

## The pulsing ring round a HUD element (null hides it), kept on screen, shaking with a refusal.
func _place_hud_ring(ui_rect) -> void:
	_ring.visible = ui_rect != null
	if ui_rect == null: return
	var r := HudSequence.ring_rect(ui_rect, size)
	_ring.position = r.position + Vector2(_shake_offset(), 0)
	_ring.size = r.size
	_ring.queue_redraw()

## What the guided box must keep clear of (canvas px), or null: the ring round the step's target, and for a unit the
## unit itself up to its plate over the head.
func _guided_target_rect(line: SequenceLine):
	var r = _guided_ring_rect(line)
	if r == null: return null
	var guided := _guided()
	if guided != null and line.point_at == SequencePointAt.Tile and controller.placing != null:
		# a placement step lights more than the ringed tile: the box keeps clear of every lit one
		for t in guided.place_tiles():
			var other := line.with_text(line.text)
			other.point_at = SequencePointAt.Tile
			other.tile_x = t.x
			other.tile_y = t.y
			var o = _guided_ring_rect(other)
			if o != null: r = (r as Rect2).merge(o)
	if line.point_at in [SequencePointAt.FirstTower, SequencePointAt.FirstEnemy, SequencePointAt.Speaker, SequencePointAt.Subject]:
		var head = controller.sequence_target_screen(line, false)
		if head != null: r = (r as Rect2).expand(head - Vector2(0, 48.0 * _ring_zoom()))
	return r

## The refusal shake (±7 px, like a denied hand piece), 0 when still.
func _shake_offset() -> float:
	return sin(_shake_t * TAU * 4.0) * 7.0 * (1.0 - _shake_t) if _shake_t < 1.0 else 0.0

## A key as a chip in BBCode (dark wood, cream bold): "Click or [Space]".
static func key_chip(key: String) -> String:
	return "[bgcolor=#%s][color=#%s][b] %s [/b][/color][/bgcolor]" % [TdTheme.color("wood.800").to_html(false), TdTheme.color("cream.100").to_html(false), key]

static var _teal_rings := {}

## A kit medallion ring with its cobalt band repainted teal (the Princess's medallion: cobalt is kept for what is
## active / selected).
static func teal_ring(sprite: String) -> Texture2D:
	if _teal_rings.has(sprite): return _teal_rings[sprite]
	var tex: Texture2D = TdTheme.texture(sprite)
	if tex == null: return null
	var img := tex.get_image()
	if img == null: return tex
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var teal: Color = TdTheme.color("teal")
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and c.b > c.r + 0.15 and c.b > c.g + 0.05: # the cobalt band (and its anti-aliased edge)
				var k := c.get_luminance() / 0.45
				img.set_pixel(x, y, Color(teal.r * k, teal.g * k, teal.b * k, c.a))
	var out := ImageTexture.create_from_image(img)
	_teal_rings[sprite] = out
	return out

## The piece's ring: a child of the piece under its key badge and cost coin, a rounded rect 6 px outside it, kept
## on screen (its glow too) at the bottom edge. null removes it.
func _place_piece_ring(piece: HudHandPiece) -> void:
	if not is_instance_valid(_piece_ring): # freed with a piece that left the tray
		_piece_ring = Control.new()
		_piece_ring.name = "TutorialRing"
		_piece_ring.mouse_filter = MOUSE_FILTER_IGNORE
		_piece_ring.draw.connect(_draw_piece_ring)
	if piece == null:
		if _piece_ring.get_parent() != null: _piece_ring.get_parent().remove_child(_piece_ring)
		return
	if _piece_ring.get_parent() != piece:
		if _piece_ring.get_parent() != null: _piece_ring.get_parent().remove_child(_piece_ring)
		piece.add_child(_piece_ring)
		piece.move_child(_piece_ring, 0)
	var r := Rect2(-Vector2(PIECE_RING_OUT, PIECE_RING_OUT), piece.size + Vector2(PIECE_RING_OUT, PIECE_RING_OUT) * 2.0)
	var screen_bottom := get_viewport_rect().size.y
	var bottom_global := piece.global_position.y + r.end.y * piece.get_global_transform().get_scale().y
	var over := bottom_global - (screen_bottom - 12.0) # the glow (8 px) and a little air stay on screen
	if over > 0.0: r.size.y -= over / maxf(0.01, piece.get_global_transform().get_scale().y)
	_piece_ring.position = r.position + Vector2(_shake_offset(), 0)
	_piece_ring.size = r.size
	_piece_ring.queue_redraw()

## The ring of the guided line's target in canvas pixels: the HUD ring round a button / the piece ring, or the board
## ring round a tile or unit's feet; null when it is not on screen.
func _guided_ring_rect(line: SequenceLine):
	var ui = _ui_control(line)
	if ui != null:
		if ui is HudHandPiece: return ui.get_global_rect().grow(PIECE_RING_OUT)
		return HudSequence.ring_rect(ui.get_global_rect(), size)
	if line.point_at == SequencePointAt.UI: return null
	var ground = _target(line, true)
	if ground == null: return null
	var rs := BOARD_RING * _ring_zoom()
	return Rect2(ground - rs * 0.5, rs)

## Tower names in a line in accent.light ("Click your [Archer] to place it.").
func _color_tower_names(text: String) -> String:
	if controller == null or controller.session == null: return text
	var names := {}
	for t in controller.session.hand: names[t.name] = true
	var col := TdTheme.color("accent.light").to_html(false)
	for n in names:
		var re := RegEx.create_from_string("\\b%s\\b" % n)
		text = re.sub(text, "[color=#%s]%s[/color]" % [col, n], true)
	return text

func _draw_piece_ring() -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * 4.0)
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.set_corner_radius_all(24)
	box.set_border_width_all(4)
	box.border_color = Color(TdTheme.color("gold.light"), 0.75 + 0.25 * pulse)
	box.shadow_color = Color(TdTheme.color("gold"), 0.35 * pulse)
	box.shadow_size = 8
	box.anti_aliasing = true
	_piece_ring.draw_style_box(box, Rect2(Vector2.ZERO, _piece_ring.size))

func _on_dialogue_clicked() -> void:
	if controller == null: return
	var run: SequenceRun = controller.sequence
	var line: SequenceLine = run.current if run != null else null
	var guided := _guided()
	if guided != null:
		# a talk step goes on; the free-play line's box can be put away; an action step's box ignores the click
		if guided.talking: controller.continue_sequence()
		elif not guided.hides_card: _hidden_step = run.index
		return
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
