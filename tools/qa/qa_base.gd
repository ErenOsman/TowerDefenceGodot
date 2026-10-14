extends SceneTree
## Shared machinery of the in-level UI QA tour (tools/qa/level_tour.gd): real input (pointer motion, clicks, keys,
## wheel, drags through Input.parse_input_event), screenshots, and the automated checks run after every step:
##   (a) errors / warnings logged while the step ran (an engine Logger), (b) Controls poking out of a clipping
##   ancestor (9-slice expand margins counted), (c) Label / RichTextLabel truncation or overflow, (d) overlaps of
##   HUD parts that must stay apart, the tooltip over the thing it describes, the dialogue box over its ring,
##   (e) tooltips / HUD parts partly outside the screen, (f) hover state left behind after the pointer goes,
##   (g) states that cannot be left (Esc / right click must get back to idle).
## Findings are printed as `QA FIND|…` lines, appended to <out>/findings.tsv, and the first step that shows a new
## finding saves a `…_find.png`. A watchdog quits when nothing progressed for 150 s (a script error mid-await).

var out_dir := "user://qa"
var prefix := "qa"
var level: LevelController
var hud: Hud

var _step := "start"
var _shot_n := 0
var _found := {}          # key → count
var _new_this_step := false
var _last_progress := 0
var _log: QaLog
var _tsv: FileAccess
var shots_on_change := true
var max_shots := 140

const NOISE := ["ALSA", "RID allocations leaked", "Unknown PCM", "snd_", "audio", "AudioDriver", "ObjectDB instances leaked", "resources still in use at exit", "Pulse"]

class QaLog extends Logger:
	var lines: Array = []
	var m := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		var kind: String = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)]
		var where := ""
		for bt in _bt:
			if bt != null and bt.get_frame_count() > 0:
				for i in mini(4, bt.get_frame_count()): where += " < %s:%d %s" % [bt.get_frame_file(i).get_file(), bt.get_frame_line(i), bt.get_frame_function(i)]
		m.lock()
		lines.append("%s %s (%s:%d) %s%s" % [kind, rationale if rationale != "" else code, file.get_file(), line, function, where])
		m.unlock()
	func _log_message(message: String, error: bool) -> void:
		if not error: return
		m.lock()
		lines.append("STDERR " + message.strip_edges())
		m.unlock()
	func take() -> Array:
		m.lock()
		var out := lines
		lines = []
		m.unlock()
		return out

func qa_setup(dir: String, p: String) -> void:
	out_dir = dir
	prefix = p
	DirAccess.make_dir_recursive_absolute(out_dir)
	_tsv = FileAccess.open(out_dir.path_join("%s_findings.tsv" % prefix), FileAccess.WRITE)
	_log = QaLog.new()
	OS.add_logger(_log)
	_last_progress = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if _last_progress > 0 and Time.get_ticks_msec() - _last_progress > 150000:
		print("QA STALL after step '%s' (a script error mid-await?)" % _step)
		_flush_log()
		quit(2)
		_last_progress = 0
	return false

func progress() -> void:
	_last_progress = Time.get_ticks_msec()

# ------------------------------------------------------------------ findings

func find(check: String, element: String, what: String) -> void:
	var key := check + "|" + element + "|" + what.left(60)
	if _found.has(key):
		_found[key] += 1
		return
	_found[key] = 1
	_new_this_step = true
	var line := "%s\t%s\t%s\t%s\t%s\t%s" % [prefix, _step, check, element, what, "%s_%02d_%s_find.png" % [prefix, _shot_n, _step]]
	print("QA FIND|" + line.replace("\t", "|"))
	if _tsv != null:
		_tsv.store_line(line)
		_tsv.flush()

func note(text: String) -> void:
	print("QA NOTE|%s|%s|%s" % [prefix, _step, text])

func expect(cond: bool, check: String, element: String, what: String) -> bool:
	if not cond: find(check, element, what)
	return cond

func _flush_log() -> void:
	if _log == null: return
	for l in _log.take():
		var noisy := false
		for n in NOISE: if l.contains(n): noisy = true
		if noisy: continue
		find("a-log", "stderr", l.left(400))

# ------------------------------------------------------------------ step: run every check, shoot on news

## Runs all automated checks on the current screen; saves a screenshot when a new finding appeared (or `force`).
func step(name: String, force := false) -> void:
	progress()
	_step = name
	_new_this_step = false
	await process_frame
	_flush_log()
	if hud != null and is_instance_valid(hud):
		_check_controls(hud.root)
		_check_overlaps()
	_check_tooltip_screen()
	if _new_this_step or force: await shot(name + ("_find" if _new_this_step else ""))

func shot(name: String) -> void:
	if _shot_n >= max_shots or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := out_dir.path_join("%s_%02d_%s.png" % [prefix, _shot_n, name])
	_shot_n += 1
	img.save_png(path)
	print("saved ", path)

# ------------------------------------------------------------------ (b) clip, (c) text, (e) screen

func _alpha(c: CanvasItem) -> float:
	var a := 1.0
	var n: Node = c
	while n != null:
		if n is CanvasItem:
			a *= (n as CanvasItem).modulate.a
			if n == c: a *= (n as CanvasItem).self_modulate.a
		if n is CanvasLayer: break
		n = n.get_parent()
	return a

func drawn_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var sb: StyleBox = null
	if c is PanelContainer or c is Panel: sb = c.get_theme_stylebox("panel")
	if sb != null and (sb is StyleBoxTexture or sb is StyleBoxFlat):
		var s := c.get_global_transform().get_scale()
		r = r.grow_individual(float(sb.get("expand_margin_left")) * s.x, float(sb.get("expand_margin_top")) * s.y,
			float(sb.get("expand_margin_right")) * s.x, float(sb.get("expand_margin_bottom")) * s.y)
	return r

func label_of(c: Node) -> String:
	var parts: Array[String] = []
	var n: Node = c
	var depth := 0
	while n != null and depth < 5:
		var nm := String(n.name)
		var sc = n.get_script()
		var cls: String = sc.get_global_name() if sc != null and sc.get_global_name() != "" else n.get_class()
		parts.push_front(nm if not nm.begins_with("@") else cls)
		if hud != null and n == hud.root: break
		n = n.get_parent()
		depth += 1
	var t := ""
	if c is Label: t = (c as Label).text
	elif c is RichTextLabel: t = (c as RichTextLabel).get_parsed_text()
	elif c is TdButton: t = (c as TdButton).text
	if t != "": return "/".join(parts) + " '" + t.replace("\n", " ").left(40) + "'"
	return "/".join(parts)

func _check_controls(top: Node) -> void:
	var screen := root.get_visible_rect()
	var stack: Array = [top]
	if is_instance_valid(TdTooltip._layer): stack.append(TdTooltip._layer)
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).visible: continue
		for ch in n.get_children(): stack.append(ch)
		if not (n is Control): continue
		var c := n as Control
		if c.size.x < 1.0 or c.size.y < 1.0: continue
		if _alpha(c) < 0.05: continue
		var r := drawn_rect(c)
		_check_clip(c, r)
		_check_text(c)
		# what can be seen of it: cut by its clipping ancestors; a rich label only as tall as its text
		if c is RichTextLabel: r.size.y = minf(r.size.y, (c as RichTextLabel).get_content_height())
		r = _visible_part(c, r)
		if r.size.x <= 0.0 or r.size.y <= 0.0: continue
		# (e) partly off the screen (full-screen layers and things slid fully away are fine)
		if r.size.x < screen.size.x * 0.95 and r.intersects(screen) and not screen.grow(1.5).encloses(r) and not c.has_method("coin"):
			if not _plate_or_board(c): find("e-offscreen", label_of(c), "partly outside the screen: %s" % _rs(r))

func _visible_part(c: Control, r: Rect2) -> Rect2:
	var p: Node = c.get_parent()
	while p != null and p is Control:
		if (p as Control).clip_contents:
			var cr := (p as Control).get_global_rect()
			if not r.intersects(cr): return Rect2()
			r = r.intersection(cr)
		p = p.get_parent()
	return r

func _plate_or_board(c: Control) -> bool:
	# board plates follow units off the edge of the screen, that is normal
	var n: Node = c
	while n != null:
		if n is PlateLayer or n is CanvasLayer and n != hud: return n is PlateLayer
		n = n.get_parent()
	return false

func _check_clip(c: Control, r: Rect2) -> void:
	var p: Node = c.get_parent()
	while p != null and p is Control:
		var pc := p as Control
		if pc.clip_contents:
			var cr := pc.get_global_rect()
			if not r.intersects(cr): return # scrolled / slid out entirely
			var cut_x := r.position.x < cr.position.x - 1.5 or r.end.x > cr.end.x + 1.5
			var cut_y := r.position.y < cr.position.y - 1.5 or r.end.y > cr.end.y + 1.5
			if pc is ScrollContainer:
				var sc := pc as ScrollContainer
				if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: cut_x = false
				if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: cut_y = false
				# rows of a vertical list are cut at the top/bottom by scrolling: fine
			if cut_x or cut_y:
				find("b-clip", label_of(c), "cut by %s: %s outside %s" % [label_of(pc).get_slice(" '", 0).get_file(), _rs(r), _rs(cr)])
			return
		p = p.get_parent()

func _rs(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [r.position.x, r.position.y, r.size.x, r.size.y]

func _check_text(c: Control) -> void:
	if c is Label:
		var l := c as Label
		if l.text == "": return
		var font := l.get_theme_font("font")
		var fs := l.get_theme_font_size("font_size")
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var t := l.text.to_upper() if l.uppercase else l.text
			var w := font.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if w > l.size.x + 2.0:
				var how := "truncated" if (l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING) else "overflows its box"
				find("c-text", label_of(l), "%s: text %.0f px in %.0f" % [how, w, l.size.x])
		else:
			if l.get_line_count() > l.get_visible_line_count() and l.get_visible_line_count() >= 0:
				find("c-text", label_of(l), "wrapped text cut: %d of %d lines" % [l.get_visible_line_count(), l.get_line_count()])
			var lh := font.get_height(fs) + l.get_theme_constant("line_spacing")
			var need := lh * l.get_visible_line_count()
			if need > l.size.y + 4.0 and l.get_visible_line_count() > 1:
				find("c-text", label_of(l), "lines need %.0f px, box %.0f" % [need, l.size.y])
	elif c is RichTextLabel:
		var rt := c as RichTextLabel
		if rt.get_parsed_text().strip_edges() == "" or rt.scroll_active: return
		if not rt.is_finished(): return
		var h := rt.get_content_height()
		if h > rt.size.y + 3.0:
			find("c-text", label_of(rt), "rich text needs %d px, box %d" % [h, rt.size.y])
		if rt.autowrap_mode == TextServer.AUTOWRAP_OFF and rt.get_content_width() > rt.size.x + 3.0:
			find("c-text", label_of(rt), "rich text %d px wide, box %d" % [rt.get_content_width(), rt.size.x])

func _check_tooltip_screen() -> void:
	if not tip_visible(): return
	var r := tip_rect()
	if not root.get_visible_rect().grow(1).encloses(r):
		find("e-offscreen", "tooltip", "tooltip outside the screen %s" % _rs(r))


# ------------------------------------------------------------------ tooltip or stack

## A tooltip or a tooltip stack (status chips) is up.
func tip_visible() -> bool:
	if TdTooltip.is_visible(): return true
	var l = TdTooltip._layer
	return is_instance_valid(l) and l.stack_root != null and l.stack_root.visible and l.stack_root.modulate.a > 0.05

## Its rect (the stack's boxes merged).
func tip_rect() -> Rect2:
	if TdTooltip.is_visible(): return TdTooltip.box().get_global_rect()
	var l = TdTooltip._layer
	var r := Rect2()
	var first := true
	if is_instance_valid(l):
		for b in l.stack_boxes:
			if b is Control and (b as Control).is_visible_in_tree():
				r = (b as Control).get_global_rect() if first else r.merge((b as Control).get_global_rect())
				first = false
	return r

# ------------------------------------------------------------------ (d) overlaps

## Named HUD part rects that are visible now (face rects for buttons).
func parts() -> Dictionary:
	var out := {}
	if hud == null: return out
	var tb := hud.top_bar
	_part(out, "hp pill", tb.get("_hp_pill"))
	_part(out, "energy pill", tb.get("_energy_pill"))
	_part(out, "tracker", tb.get("_tracker"))
	_part(out, "skip", tb.get("_skip"))
	_part(out, "pause", tb.get("_pause"))
	_part(out, "end turn", tb.end_turn)
	_part(out, "tray", hud.tray, true)
	_part(out, "action bar", hud.action_bar)
	_part(out, "inspector", hud.inspector)
	_part(out, "hint", hud.hint_pill)
	if hud.coop_hud != null:
		_part(out, "pass", hud.coop_hud.dial)
		_part(out, "coop toast", hud.coop_hud.toast)
		_part(out, "chat", hud.coop_hud.chat_strip)
	return out

func _part(out: Dictionary, n: String, c, content := false) -> void:
	if c == null or not is_instance_valid(c) or not (c as Control).is_visible_in_tree() or _alpha(c) < 0.05: return
	var r: Rect2
	if c is TdButton: r = (c as TdButton).face_global_rect()
	elif c.has_method("coin"): # the co-op Pass dial: a wide pointer-transparent control, only its coin is drawn / takes the pointer
		var R: float = c.get("R")
		r = Rect2(c.get_global_transform() * (c.coin() - Vector2(R, R)), Vector2(R, R) * 2.0)
	elif content: r = _content_rect(c)
	else: r = (c as Control).get_global_rect()
	if r.size.x > 0.0 and r.size.y > 0.0: out[n] = r

## The union of the visible children's rects (the tray's area is wider than its pieces).
func _content_rect(c: Control) -> Rect2:
	var r := Rect2()
	var first := true
	for ch in c.find_children("*", "Control", true, false):
		var cc := ch as Control
		if not cc.is_visible_in_tree() or cc.size.x < 2 or _alpha(cc) < 0.05: continue
		var g := cc.get_global_rect()
		r = g if first else r.merge(g)
		first = false
	return r

const APART := [
	["hp pill", "energy pill"], ["energy pill", "tracker"], ["tracker", "skip"], ["skip", "pause"],
	["tray", "action bar"], ["tray", "end turn"], ["tray", "hint"], ["action bar", "end turn"], ["action bar", "hint"],
	["hint", "end turn"], ["inspector", "action bar"], ["inspector", "end turn"], ["inspector", "skip"],
	["inspector", "pause"], ["inspector", "tracker"], ["inspector", "tray"], ["inspector", "hint"],
	["pass", "action bar"], ["pass", "inspector"], ["pass", "tray"],
	["coop toast", "inspector"], ["chat", "tray"], ["chat", "action bar"],
]

func _check_overlaps() -> void:
	var p := parts()
	for pair in APART:
		if p.has(pair[0]) and p.has(pair[1]):
			var a: Rect2 = p[pair[0]]
			var b: Rect2 = p[pair[1]]
			var i := a.intersection(b)
			if i.size.x > 2.0 and i.size.y > 2.0:
				find("d-overlap", "%s × %s" % pair, "%s overlaps %s by %dx%d" % [pair[0], pair[1], i.size.x, i.size.y])
	# the dialogue box over its ringed target
	var seq := hud.sequence
	if seq != null and seq.dialogue != null and seq.dialogue.is_shown() and _alpha(seq.dialogue) > 0.5:
		var box := seq.dialogue.get_global_rect()
		for ring_name in ["_ring", "_piece_ring"]:
			var ring = seq.get(ring_name)
			if ring is Control and (ring as Control).is_visible_in_tree() and _alpha(ring) > 0.1:
				var rr := (ring as Control).get_global_rect()
				var i := box.intersection(rr)
				if i.size.x > 4.0 and i.size.y > 4.0:
					find("d-overlap", "dialogue × " + ring_name, "dialogue box %s covers the ring %s" % [_rs(box), _rs(rr)])
		if p.has("action bar") and box.intersects(p["action bar"]):
			find("d-overlap", "dialogue × action bar", "dialogue box over the action bar")
		if p.has("inspector") and box.intersects(p["inspector"]):
			find("d-overlap", "dialogue × inspector", "dialogue box over the inspector")
		if p.has("hint") and box.intersects(p["hint"]):
			find("d-overlap", "dialogue × hint", "dialogue box over the hint line")
		if tip_visible():
			var tr := tip_rect()
			var ti := HudSequence.box_area(box, 0.0).intersection(tr)
			if ti.size.x > 3.0 and ti.size.y > 3.0:
				find("d-overlap", "tooltip × dialogue", "a tooltip %s covers the dialogue box %s" % [_rs(tr), _rs(box)])

## The tooltip must not sit on the control that opened it.
func check_tooltip_clear_of(anchor: Control, what: String) -> void:
	if not tip_visible() or anchor == null: return
	var a: Rect2 = anchor.face_global_rect() if anchor is TdButton else anchor.get_global_rect()
	if anchor.has_method("coin"):
		var R: float = anchor.get("R")
		a = Rect2(anchor.get_global_transform() * (anchor.coin() - Vector2(R, R)), Vector2(R, R) * 2.0)
	var t := tip_rect()
	var i: Rect2 = a.intersection(t)
	if i.size.x > 3.0 and i.size.y > 3.0:
		find("d-overlap", "tooltip × " + what, "tooltip %s covers %s %s" % [_rs(t), what, _rs(a)])

# ------------------------------------------------------------------ (f) stuck hover, (g) leave

## After the pointer left the HUD: no button still hovered, no tooltip, no preview left on the board.
func check_unhovered(where: String) -> void:
	if hud == null: return
	for b in hud.root.find_children("*", "TdButton", true, false):
		if (b as TdButton).hovered and (b as TdButton).is_visible_in_tree():
			find("f-stuck-hover", label_of(b), "still hovered after the pointer left (%s)" % where)
	for p in hud.tray._pieces:
		if p.hovered: find("f-stuck-hover", "hand piece " + p.tower_id, "piece still hovered (%s)" % where)
	if tip_visible() and not tip_rect().has_point(root.get_mouse_position()):
		find("f-stuck-hover", "tooltip", "tooltip still open after the pointer left (%s)" % where)
	if level != null and level.preview_enemy_phase:
		find("f-stuck-hover", "end turn", "enemy-turn preview left on (%s)" % where)
	if level != null and level.get("_preview_ability") != null:
		find("f-stuck-hover", "ability preview", "ability range preview left on the board (%s)" % where)

## Esc / right clicks until idle; reports when it takes more than the expected presses or never gets there.
func back_to_idle(where: String, max_presses := 4) -> void:
	for i in max_presses:
		var busy := level.placing != null or level.aiming != null or hud.pause.is_open() or hud.info.is_open()
		if not busy: return
		await key(KEY_ESCAPE)
		await wait(0.5)
	if level.placing != null or level.aiming != null or hud.pause.is_open() or hud.info.is_open():
		find("g-stuck", where, "Esc ×%d did not get back to idle (placing %s aiming %s pause %s info %s)" % [max_presses, level.placing, level.aiming, hud.pause.is_open(), hud.info.is_open()])

# ------------------------------------------------------------------ input

func to_window(p: Vector2) -> Vector2:
	return p * Vector2(root.size) / root.get_visible_rect().size

func move(p: Vector2) -> void:
	root.warp_mouse(p)
	var ev := InputEventMouseMotion.new()
	ev.position = to_window(p)
	ev.global_position = ev.position
	ev.button_mask = _mask
	Input.parse_input_event(ev)

var _mask := 0

func button(p: Vector2, idx: int, down: bool, dbl := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = idx
	ev.pressed = down
	ev.double_click = dbl
	ev.position = to_window(p)
	ev.global_position = ev.position
	var bit := 1 << (idx - 1)
	_mask = (_mask | bit) if down else (_mask & ~bit)
	ev.button_mask = _mask
	Input.parse_input_event(ev)

## A real click: move there, press, two frames, release, two frames.
func click(p: Vector2, idx := MOUSE_BUTTON_LEFT) -> void:
	move(p)
	await frames(2)
	button(p, idx, true)
	await frames(2)
	button(p, idx, false)
	await frames(3)

func click_control(c: Control, idx := MOUSE_BUTTON_LEFT) -> void:
	await click(centre_of(c), idx)

func centre_of(c: Control) -> Vector2:
	return (c.face_global_rect() if c is TdButton else c.get_global_rect()).get_center()

func wheel(p: Vector2, up: bool, n := 1) -> void:
	for i in n:
		move(p)
		button(p, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, true)
		await frames(1)
		button(p, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, false)
		await frames(1)

func drag(from: Vector2, to: Vector2, idx := MOUSE_BUTTON_LEFT, steps := 8) -> void:
	move(from)
	await frames(2)
	button(from, idx, true)
	await frames(2)
	for i in steps:
		move(from.lerp(to, float(i + 1) / steps))
		await frames(1)
	button(to, idx, false)
	await frames(3)

func key(code: int, shift := false, hold_frames := 2) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	ev.shift_pressed = shift
	if shift: await _key_raw(KEY_SHIFT, true)
	Input.parse_input_event(ev)
	await frames(hold_frames)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	if shift: await _key_raw(KEY_SHIFT, false)
	await frames(2)

func _key_raw(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)
	await frames(1)

func park() -> void:
	move(Vector2(980, 120))

# ------------------------------------------------------------------ time

func frames(n: int) -> void:
	for i in n: await process_frame

func wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until: await process_frame

func settle() -> void:
	for i in 900:
		await process_frame
		if level == null or level.director == null or not level.director.busy: break
	await frames(2)
	progress()

func until_tooltip(max_s := 3.0) -> bool:
	var until := Time.get_ticks_msec() + int(max_s * 1000.0)
	while not tip_visible() and Time.get_ticks_msec() < until: await process_frame
	await wait(0.2)
	return tip_visible()

# ------------------------------------------------------------------ hover with change detection

## What hovering changes: tooltip text, hovered flags, board previews.
func hover_signature() -> String:
	var s := []
	s.append(tip_visible())
	s.append(str(tip_rect()))
	if TdTooltip.is_visible():
		var b := TdTooltip.box()
		var lbls := b.find_children("*", "RichTextLabel", true, false)
		for l in lbls: s.append((l as RichTextLabel).get_parsed_text().left(30))
	if hud != null:
		for b in hud.root.find_children("*", "TdButton", true, false):
			if (b as TdButton).hovered: s.append(String(b.name) + (b as TdButton).text)
		for p in hud.tray._pieces:
			if p.hovered: s.append("piece" + p.tower_id)
	if level != null:
		s.append(level.preview_enemy_phase)
		s.append(str(level.get("_preview_ability")))
		s.append(str(level.hover))
	return str(s)

## Hovers a control with real motion (6 frames + the tooltip delay), runs the checks, shoots when hovering changed
## something; then leaves and checks nothing stayed hovered.
func hover(c: Control, what: String, expect_tip := true) -> void:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		note("hover %s: not visible" % what)
		return
	var before := hover_signature()
	move(centre_of(c) + Vector2(1, 0))
	await frames(6)
	var tip := await until_tooltip(1.6) if expect_tip else false
	var after := hover_signature()
	if expect_tip and not tip: note("hover %s: no tooltip" % what)
	check_tooltip_clear_of(c, what)
	var changed := after != before
	_step = "hover_" + what.replace(" ", "_")
	await step(_step, changed and shots_on_change)
	park()
	await frames(6)
	await wait(0.3)
	check_unhovered("after " + what)
