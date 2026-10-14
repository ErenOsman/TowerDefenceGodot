extends RefCounted
## QA helpers for tools/qa/guild_tour.gd (UI QA pass on the Workshop, Guild, Missions and Co-op screens).
## Real input (InputEventMouseMotion / InputEventMouseButton / InputEventKey through Input.parse_input_event),
## screenshots (full frames and hover crops), and automated layout checks after each step:
##  clip   — a Control poking partly outside its clipping ancestor (clip_contents / ScrollContainer content) or the viewport
##  text   — a Label / RichTextLabel cut (ellipsis, hidden lines, content taller / wider than the box), text under 18 px
##  overlap— two texts (or a text and a button face) drawn over each other
##  tip    — a tooltip outside the viewport
##  stuck  — hover state / tooltip still on after the pointer left
##  esc    — a state Back/Esc does not leave
##  error  — an engine error or warning printed during the step (a Logger)
## Findings go to <out>/findings.txt (one line each, deduplicated) and are printed as "QA <kind> …".

var tree: SceneTree
var out_dir := ""
var tag := ""           # resolution tag for file names ("1080" / "720")
var step := "start"
var shots := 0
var findings: Array = []      # [{kind, screen, element, what, shot}]
var _seen := {}
var errors: Array = []        # [{step, text}]
var _logger: QaLogger
var _mutex := Mutex.new()
## Hover crops to look at later (one contact sheet per screen).
var sheet_items: Array = []   # [Image]
var sheet_names: Array = []
var screen := ""
## Text sizes under this are reported (UI rule: nothing under 18 px).
const MIN_TEXT := 18
## Pointer parking spot (canvas coordinates), checked to be over nothing clickable.
var park := Vector2(1910, 6)

class QaLogger extends Logger:
	var qa
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array) -> void:
		var kind := "WARNING" if error_type == 1 else ("SCRIPT ERROR" if error_type == 2 else ("SHADER ERROR" if error_type == 3 else "ERROR"))
		qa._error("%s: %s %s (%s:%d %s)" % [kind, code, rationale, file, line, function])
	func _log_message(message: String, error: bool) -> void:
		if error and not message.contains("ALSA") and not message.contains("PCM"): qa._error("stderr: " + message.strip_edges())

func _init(t: SceneTree, dir: String, res_tag: String) -> void:
	tree = t
	out_dir = dir
	tag = res_tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_logger = QaLogger.new()
	_logger.qa = self
	OS.add_logger(_logger)
	Input.use_accumulated_input = false

func _error(text: String) -> void:
	# known noise: leaked RIDs at exit, the dummy audio driver
	if text.contains("RID allocations") or text.contains("ObjectDB instances leaked"): return
	_mutex.lock()
	errors.append({"step": step, "text": text})
	_mutex.unlock()
	print("QA-ERR [", step, "] ", text)
	progress("QA-ERR [%s] %s" % [step, text])

func finish() -> void:
	OS.remove_logger(_logger)
	var f := FileAccess.open(out_dir.path_join("findings_%s.txt" % tag), FileAccess.WRITE)
	for x in findings:
		f.store_line("%s\t%s\t%s\t%s\t%s" % [x.kind, x.screen, x.element, x.what, x.shot])
	for e in errors:
		f.store_line("error\t%s\t-\t%s\t-" % [e.step, e.text])
	f.close()
	print("QA DONE: %d findings, %d errors" % [findings.size(), errors.size()])
	progress("QA DONE")

## Appends a line to <out>/progress_<tag>.log (the daemon prints the job's output only at the end).
var last_progress := 0.0
## > 0: every crawl stops after this many controls (the 720 pass).
var quick_max := 0

func progress(line: String) -> void:
	last_progress = Time.get_ticks_msec() / 1000.0
	var path := out_dir.path_join("progress_%s.log" % tag)
	var f := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null: return
	f.seek_end()
	f.store_line("%.1f %s" % [Time.get_ticks_msec() / 1000.0, line])
	f.close()

func find(kind: String, element: String, what: String, shot := "") -> void:
	var key := "%s|%s|%s|%s" % [kind, screen, element, what]
	if _seen.has(key): return
	_seen[key] = true
	findings.append({"kind": kind, "screen": screen + " / " + step, "element": element, "what": what, "shot": shot})
	print("QA ", kind, " [", screen, " / ", step, "] ", element, ": ", what, (" → " + shot if shot != "" else ""))
	progress("QA %s [%s / %s] %s: %s%s" % [kind, screen, step, element, what, (" → " + shot if shot != "" else "")])

# ------------------------------------------------------------------ frames, input

func frames(n: int) -> void:
	for i in n: await tree.process_frame

## n frames and at least `secs` seconds (tooltips wait 0.4 s unscaled).
func wait(n: int, secs := 0.0) -> void:
	var t0 := Time.get_ticks_msec()
	for i in n: await tree.process_frame
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await tree.process_frame

func until(cond: Callable, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000.0: return false
		await tree.process_frame
	return true

func to_window(p: Vector2) -> Vector2:
	return tree.root.get_final_transform() * p

var mouse := Vector2.ZERO
var _mask := 0

func move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = to_window(p)
	ev.global_position = ev.position
	ev.relative = ev.position - to_window(mouse)
	ev.button_mask = _mask
	mouse = p
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func button(p: Vector2, pressed: bool, which := MOUSE_BUTTON_LEFT, dbl := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = to_window(p)
	ev.global_position = ev.position
	ev.button_index = which
	ev.pressed = pressed
	ev.double_click = dbl
	var bit := 1 << (which - 1)
	_mask = (_mask | bit) if pressed else (_mask & ~bit)
	ev.button_mask = _mask
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

## A real click: move there, press, a frame, release.
func click_at(p: Vector2, which := MOUSE_BUTTON_LEFT) -> void:
	move(p)
	await frames(2)
	button(p, true, which)
	await frames(1)
	button(p, false, which)
	await frames(2)

func dbl_click_at(p: Vector2) -> void:
	await click_at(p)
	button(p, true, MOUSE_BUTTON_LEFT, true)
	await frames(1)
	button(p, false)
	await frames(2)

func key(code: int, shift := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.shift_pressed = shift
	ev.pressed = true
	if code == KEY_SPACE: ev.unicode = 32
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await frames(1)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await frames(2)

func type_text(s: String) -> void:
	for ch in s:
		var ev := InputEventKey.new()
		ev.unicode = ch.unicode_at(0)
		ev.pressed = true
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await frames(1)

func park_mouse() -> void:
	move(park)

## The centre of a control's clickable face (TdButton: its face rect), canvas coordinates.
func centre(c: Control) -> Vector2:
	if c is TdButton: return (c as TdButton).face_global_rect().get_center()
	return grect(c).get_center()

# ------------------------------------------------------------------ shots

func shot(label: String) -> String:
	await RenderingServer.frame_post_draw
	shots += 1
	var name := "%s_%03d_%s.png" % [tag, shots, label.validate_filename().replace(" ", "_")]
	var p := out_dir.path_join(name)
	tree.root.get_viewport().get_texture().get_image().save_png(p)
	print("saved ", ProjectSettings.globalize_path(p))
	progress("shot " + name)
	return name

func frame_image() -> Image:
	await RenderingServer.frame_post_draw
	return tree.root.get_viewport().get_texture().get_image()

## A crop of the frame in canvas coordinates (scaled into the image's pixels).
func crop(img: Image, r: Rect2) -> Image:
	var k := Vector2(img.get_width(), img.get_height()) / tree.root.get_visible_rect().size
	var px := Rect2i(Vector2i(r.position * k), Vector2i(r.size * k)).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if px.size.x <= 0 or px.size.y <= 0: return null
	return img.get_region(px)

func add_to_sheet(img: Image, name: String) -> void:
	if img == null: return
	sheet_items.append(img)
	sheet_names.append(name)

## Packs the hover crops into contact sheets (rows of crops, at most 1920 wide) and a names file.
func flush_sheet(label: String) -> void:
	if sheet_items.is_empty(): return
	var W := 1920
	var x := 0; var y := 0; var row_h := 0
	var places := []
	var pages := []
	var page_items := []
	for i in sheet_items.size():
		var im: Image = sheet_items[i]
		if im.get_width() > W: im.resize(W, int(im.get_height() * float(W) / im.get_width()))
		if x + im.get_width() > W:
			x = 0; y += row_h + 6; row_h = 0
		if y + im.get_height() > 2400 and not page_items.is_empty():
			pages.append([places, y + row_h]); places = []; x = 0; y = 0; row_h = 0
		places.append([im, Vector2i(x, y), sheet_names[i]])
		page_items.append(i)
		x += im.get_width() + 6
		row_h = maxi(row_h, im.get_height())
	pages.append([places, y + row_h])
	var names := FileAccess.open(out_dir.path_join("%s_sheet_%s.txt" % [tag, label]), FileAccess.WRITE)
	for pi in pages.size():
		var pl: Array = pages[pi][0]
		var sheet := Image.create(W, maxi(8, int(pages[pi][1])), false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.1, 0.1, 0.1))
		for it in pl:
			var im: Image = it[0]
			im.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), it[1])
			names.store_line("page %d at %s: %s" % [pi, it[1], it[2]])
		sheet.save_png(out_dir.path_join("%s_sheet_%s_%d.png" % [tag, label, pi]))
	names.close()
	sheet_items.clear()
	sheet_names.clear()

# ------------------------------------------------------------------ geometry

## A control's drawn rect in canvas coordinates (its global transform: scale and rotation included).
static func grect(c: Control) -> Rect2:
	var xf := c.get_global_transform()
	var r := Rect2(xf * Vector2.ZERO, Vector2.ZERO)
	for p in [Vector2(c.size.x, 0), c.size, Vector2(0, c.size.y)]:
		r = r.expand(xf * p)
	return r

## What a panel draws beyond its rect (StyleBox expand margins, shadows).
static func outset_rect(c: Control) -> Rect2:
	var r := grect(c)
	var sb: StyleBox = null
	if c is PanelContainer or c is Panel: sb = c.get_theme_stylebox("panel")
	if sb is StyleBoxTexture:
		var t := sb as StyleBoxTexture
		r = r.grow_individual(t.expand_margin_left, t.expand_margin_top, t.expand_margin_right, t.expand_margin_bottom)
	elif sb is StyleBoxFlat:
		var f := sb as StyleBoxFlat
		r = r.grow_individual(f.expand_margin_left, f.expand_margin_top, f.expand_margin_right, f.expand_margin_bottom)
		if f.shadow_size > 0 and f.shadow_color.a > 0.05:
			r = r.merge(r.grow(f.shadow_size).grow_individual(0, 0, 0, 0).abs())
	return r

static func path_of(c: Node, base: Node) -> String:
	var s := ""
	var n := c
	var k := 0
	while n != null and n != base and k < 5:
		var nm := str(n.name)
		if nm.begins_with("@"): nm = n.get_class() if n.get_script() == null else (n.get_script().get_global_name() if n.get_script().get_global_name() != "" else n.get_class())
		s = nm + ("/" + s if s != "" else "")
		n = n.get_parent()
		k += 1
	return s

## A readable name: the text it shows (TdButton text / Label / tooltip) and its class.
static func describe(c: Control) -> String:
	var t := label_of(c)
	var cls := c.get_class()
	if c.get_script() != null:
		var g: String = c.get_script().get_global_name()
		if g != "": cls = g
		elif c.get_script().resource_path != "": cls = c.get_script().resource_path.get_file().get_basename()
		else: cls = "inner:" + c.get_class()
	return "%s \"%s\"" % [cls, t.left(48)] if t != "" else cls

static func label_of(c: Control) -> String:
	if c is TdButton and str(c.text) != "": return str(c.text)
	if c is Button and c.text != "": return c.text
	if c is Label: return c.text
	if c is RichTextLabel: return c.get_parsed_text().strip_edges()
	if c is LineEdit: return "field:" + (c.placeholder_text if c.text == "" else c.text)
	# the first text inside
	for l in c.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and l.text.strip_edges() != "": return l.text.strip_edges()
	for l in c.find_children("*", "RichTextLabel", true, false):
		if l.is_visible_in_tree() and l.get_parsed_text().strip_edges() != "": return l.get_parsed_text().strip_edges()
	var tt := TdTooltipTrigger.find_on(c)
	if tt != null: return "tip:" + (tt.header if tt.header != "" else tt.body).left(40)
	if c.tooltip_text != "": return "tip:" + c.tooltip_text
	return ""

static func visible_controls(root: Node) -> Array:
	var out := []
	_collect(root, out)
	return out

static func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is CanvasItem and not c.visible: continue
		if c is Window or c is SubViewport: continue
		if c is CanvasLayer and not c.visible: continue
		if c is Control: out.append(c)
		_collect(c, out)

# ------------------------------------------------------------------ candidates

## Clickable / hoverable controls under `root`, in tree order: [{c, kind:"click"|"hover"|"field"}].
static func candidates(root: Node, vp_rect: Rect2) -> Array:
	var out := []
	for c in visible_controls(root):
		if c.mouse_filter == Control.MOUSE_FILTER_IGNORE: continue
		if c is ScrollBar or c is ScrollContainer or c is TdScrim: continue
		if _inside_button(c): continue
		var kind := ""
		if c is TdButton or c is BaseButton: kind = "click"
		elif c is LineEdit: kind = "field"
		elif c.mouse_filter == Control.MOUSE_FILTER_STOP and (c.has_signal("clicked") or c.has_signal("pressed") or c.has_signal("activated") \
				or _has_gui_handler(c) or c.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND):
			kind = "click"
		elif TdTooltipTrigger.find_on(c) != null or c.tooltip_text != "":
			kind = "hover"
		if kind == "": continue
		var r := grect(c)
		if r.size.x < 4 or r.size.y < 4: continue
		if not vp_rect.has_point(r.get_center()): continue
		out.append({"c": c, "kind": kind})
	return out

static func _inside_button(c: Node) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is TdButton or p is BaseButton: return true
		p = p.get_parent()
	return false

static func _has_gui_handler(c: Control) -> bool:
	if c.gui_input.get_connections().size() > 0: return true
	var s: Script = c.get_script()
	while s != null:
		if s.has_source_code() and s.source_code.contains("func _gui_input"): return true
		s = s.get_base_script()
	return false

## A stable key for a candidate (class + label + position on a 6 px grid).
static func key_of(c: Control) -> String:
	var r := grect(c)
	return "%s|%d,%d" % [describe(c), int(r.position.x / 6), int(r.position.y / 6)]

## Whether the point really reaches the control (not covered by something else).
func reaches(c: Control) -> bool:
	var h := tree.root.gui_get_hovered_control()
	if h == null: return false
	return h == c or c.is_ancestor_of(h) or (h.is_ancestor_of(c) and h.mouse_filter == Control.MOUSE_FILTER_STOP and false)

# ------------------------------------------------------------------ checks

## Every layout check over the controls under `root` (the top screen).
func audit(root: Node, where: String, shot_name := "") -> void:
	var vp := tree.root.get_visible_rect()
	var ctrls := visible_controls(root)
	var texts := []
	var faces := []
	for c in ctrls:
		if c.modulate.a <= 0.01 or c.self_modulate.a <= 0.01: continue
		if _alpha_hidden(c): continue
		var r := outset_rect(c)
		if r.size.x <= 0.5 or r.size.y <= 0.5: continue
		# viewport (what its clipping ancestors let through)
		var vis := _visible_part(c, r)
		if vis.size.x > 0.5 and vis.intersects(vp) and not vp.grow(1.0).encloses(vis):
			var what := "pokes outside the viewport (%s vs %s)" % [_rs(r), _rs(vp)]
			find("clip", describe(c) + " @" + path_of(c, root), what, shot_name)
		# clipping ancestor
		var a := _clipper(c)
		if a != null:
			var ar := grect(a)
			if a is ScrollContainer:
				var content: Control = null
				for ch in a.get_children():
					if ch is Control and not (ch is ScrollBar): content = ch; break
				if content != null and content != c:
					var cr := grect(content)
					var view := ar
					var full_out := not r.intersects(view)
					if not full_out:
						# horizontally always; vertically only beyond the scrollable content (a rim nobody can scroll to)
						if r.position.x < view.position.x - 1.0 or r.end.x > view.end.x + 1.0:
							find("clip", describe(c) + " @" + path_of(c, root), "cut at the side of its ScrollContainer (%s vs %s)" % [_rs(r), _rs(view)], shot_name)
						elif r.position.y < cr.position.y - 1.0 or r.end.y > cr.end.y + 1.0:
							if (r.position.y < view.position.y - 1.0) or (r.end.y > view.end.y + 1.0):
								find("clip", describe(c) + " @" + path_of(c, root), "rim beyond the scroll content: cut (%s vs content %s)" % [_rs(r), _rs(cr)], shot_name)
			elif r.intersects(ar) and not ar.grow(1.0).encloses(r) and not _ok_overhang(c, a):
				find("clip", describe(c) + " @" + path_of(c, root), "cut by clipping ancestor %s (%s vs %s)" % [describe(a), _rs(r), _rs(ar)], shot_name)
		# text
		if c is Label or c is RichTextLabel:
			_check_text(c, root, shot_name)
			if _has_text(c) and _shown_in_clip(c): texts.append(c)
		elif c is TdButton and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and _shown_in_clip(c):
			faces.append(c)
	# overlaps: text vs text, text vs a button face it is not part of
	var boxes := []
	for t in texts: boxes.append([t, _visible_part(t, text_rect(t))])
	for i in boxes.size():
		var ri: Rect2 = boxes[i][1]
		if ri.size.x < 2: continue
		for j in range(i + 1, boxes.size()):
			var rj: Rect2 = boxes[j][1]
			var a: Control = boxes[i][0]; var b: Control = boxes[j][0]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			var inter := ri.intersection(rj)
			if inter.size.x > 3 and inter.size.y > 3:
				find("overlap", describe(a) + " × " + describe(b), "texts overlap by %dx%d px at %s" % [inter.size.x, inter.size.y, _v(inter.position)], shot_name)
		for f in faces:
			var a: Control = boxes[i][0]
			if f.is_ancestor_of(a) or a.is_ancestor_of(f): continue
			if _same_button(a, f): continue
			var fr: Rect2 = (f as TdButton).face_global_rect()
			var inter := ri.intersection(fr)
			if inter.size.x > 3 and inter.size.y > 3:
				find("overlap", describe(a) + " × " + describe(f), "text runs under/over a button by %dx%d px" % [inter.size.x, inter.size.y], shot_name)

func _same_button(a: Control, f: Control) -> bool:
	return f.is_ancestor_of(a)

## r cut by every clipping ancestor of c (empty when fully clipped).
func _visible_part(c: Control, r: Rect2) -> Rect2:
	var a := _clipper(c)
	while a != null:
		r = r.intersection(grect(a))
		if r.size.x <= 0 or r.size.y <= 0: return Rect2()
		a = _clipper(a)
	return r

## Some ancestors fade it out (modulate alpha 0) or keep it out of view.
static func _alpha_hidden(c: Control) -> bool:
	var n: Node = c
	while n != null and n is CanvasItem:
		if (n as CanvasItem).modulate.a <= 0.02: return true
		n = n.get_parent()
	return false

## A popup's window during its open transition is scaled; only a settled frame is audited (callers wait).
static func _clipper(c: Control) -> Control:
	var p := c.get_parent()
	while p != null and p is Control:
		if p is ScrollContainer or (p as Control).clip_contents: return p
		p = p.get_parent()
	return null

## Overhangs that are fine: a slider pane fully outside (the Workshop's other view).
func _ok_overhang(_c: Control, _a: Control) -> bool:
	return false

func _shown_in_clip(c: Control) -> bool:
	var a := _clipper(c)
	var r := grect(c)
	while a != null:
		if not r.intersects(grect(a)): return false
		a = _clipper(a)
	return true

static func _has_text(c: Control) -> bool:
	if c is Label: return c.text.strip_edges() != ""
	if c is RichTextLabel: return c.get_parsed_text().strip_edges() != ""
	return false

static func _font_size(c: Control) -> int:
	if c is Label:
		if c.label_settings != null: return c.label_settings.font_size
		return c.get_theme_font_size("font_size")
	return c.get_theme_font_size("normal_font_size")

## The rect the text really covers (alignment, wrap and line count taken into account).
static func text_rect(c: Control) -> Rect2:
	var xf := c.get_global_transform()
	var sc := xf.get_scale()
	if c is Label:
		var l := c as Label
		var font: Font = l.label_settings.font if l.label_settings != null and l.label_settings.font != null else l.get_theme_font("font")
		var fs := _font_size(l)
		var lines := maxi(1, l.get_visible_line_count())
		var lh := font.get_height(fs) + l.get_theme_constant("line_spacing")
		var w := 0.0
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			for line in l.text.split("\n"): w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
			if l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING: w = minf(w, l.size.x)
		else:
			w = minf(l.size.x, font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, l.size.x, fs).x)
		var h := lh * lines
		var x := 0.0
		match l.horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER: x = (l.size.x - w) / 2.0
			HORIZONTAL_ALIGNMENT_RIGHT: x = l.size.x - w
		var y := 0.0
		match l.vertical_alignment:
			VERTICAL_ALIGNMENT_CENTER: y = (l.size.y - h) / 2.0
			VERTICAL_ALIGNMENT_BOTTOM: y = l.size.y - h
		# glyph box without the font's line padding (ascent band only, a little inset)
		return Rect2(xf * Vector2(x, y + 2), Vector2(w, h - 4) * sc)
	var r := c as RichTextLabel
	var cw := minf(float(r.get_content_width()), r.size.x)
	var ch := minf(float(r.get_content_height()), r.size.y) if r.clip_contents else float(r.get_content_height())
	var x0 := 0.0
	if r.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER: x0 = (r.size.x - cw) / 2.0
	elif r.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT: x0 = r.size.x - cw
	return Rect2(xf * Vector2(x0, 2), Vector2(cw, maxf(0.0, ch - 4)) * sc)

func _check_text(c: Control, root: Node, shot_name: String) -> void:
	if not _has_text(c) or not _shown_in_clip(c): return
	var who := describe(c) + " @" + path_of(c, root)
	var fs := _font_size(c)
	if fs < MIN_TEXT:
		find("text", who, "font size %d px (< %d)" % [fs, MIN_TEXT], shot_name)
	if c is Label:
		var l := c as Label
		var font: Font = l.label_settings.font if l.label_settings != null and l.label_settings.font != null else l.get_theme_font("font")
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and (l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
			var w := 0.0
			for line in l.text.split("\n"): w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
			if w > l.size.x + 1.0:
				find("text", who, "cut: needs %d px, has %d (%s)" % [w, l.size.x, "ellipsis" if l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING else "clipped"], shot_name)
		if l.get_line_count() > l.get_visible_line_count() and l.get_visible_line_count() >= 0:
			find("text", who, "shows %d of %d lines" % [l.get_visible_line_count(), l.get_line_count()], shot_name)
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.size.x < 40 and l.text.length() > 6:
			find("text", who, "wrapping label squeezed to %d px wide" % l.size.x, shot_name)
	else:
		var r := c as RichTextLabel
		if r.scroll_active and r.get_v_scroll_bar().visible: return
		if r.get_content_height() > r.size.y + 2.0 and r.clip_contents:
			find("text", who, "cut: content %d px tall in %d" % [r.get_content_height(), r.size.y], shot_name)
		if r.autowrap_mode == TextServer.AUTOWRAP_OFF and r.get_content_width() > r.size.x + 2.0:
			find("text", who, "cut: content %d px wide in %d" % [r.get_content_width(), r.size.x], shot_name)
		if r.get_visible_line_count() < r.get_line_count() and r.max_lines_visible > 0:
			find("text", who, "shows %d of %d lines" % [r.get_visible_line_count(), r.get_line_count()], shot_name)

static func _rs(r: Rect2) -> String:
	return "[%d,%d %dx%d]" % [r.position.x, r.position.y, r.size.x, r.size.y]

static func _v(v: Vector2) -> String:
	return "(%d,%d)" % [v.x, v.y]

# ------------------------------------------------------------------ tooltips and hover state

## The visible tooltip's rect (TdTooltip box, the stack, or Godot's own tooltip window), or an empty Rect2.
func tooltip_rect() -> Rect2:
	var r := Rect2()
	if TdTooltip.is_visible():
		var b := TdTooltip.box()
		if b != null and b.is_visible_in_tree(): r = grect(b)
	var lay := TdTooltip._layer
	if lay != null and is_instance_valid(lay) and lay.stack_root != null and lay.stack_root.is_visible_in_tree():
		for sb in lay.stack_boxes:
			if is_instance_valid(sb) and sb.is_visible_in_tree():
				r = grect(sb) if r.size == Vector2.ZERO else r.merge(grect(sb))
	for w in tree.root.get_embedded_subwindows():
		if w.visible and w is PopupPanel:
			var wr := Rect2(Vector2(w.position), Vector2(w.size))
			r = wr if r.size == Vector2.ZERO else r.merge(wr)
	return r

func check_tooltip(who: String, shot_name := "") -> Rect2:
	var r := tooltip_rect()
	if r.size == Vector2.ZERO: return r
	var vp := tree.root.get_visible_rect()
	if not vp.grow(1.0).encloses(r):
		find("tip", who, "tooltip outside the viewport %s" % _rs(r), shot_name)
	return r

## Anything still showing hover after the pointer left (TdButton.hovered, a script's _hover, a tooltip).
func check_unhovered(c: Control, who: String) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree(): return
	if c is TdButton and c.hovered: find("stuck", who, "TdButton.hovered still true after the pointer left")
	for v in ["_hover", "_hovered"]:
		if v in c and c.get(v) == true: find("stuck", who, v + " still true after the pointer left")
	var tt := TdTooltipTrigger.find_on(c)
	if tt != null and tt.is_showing(): find("stuck", who, "tooltip trigger still showing after the pointer left")

# ------------------------------------------------------------------ the crawler

## The top open TdPopup (or `fallback`): what the pointer talks to.
func top(fallback: Node) -> Node:
	for i in range(TdPopup.open_popups.size() - 1, -1, -1):
		var p = TdPopup.open_popups[i]
		if is_instance_valid(p) and p.is_inside_tree(): return p
	return fallback

static func scroll_parent(c: Control) -> ScrollContainer:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer: return p
		p = p.get_parent()
	return null

## Hovers (and clicks) every candidate under get_root.call(), re-collected after each click (screens rebuild).
## opts: max (int), hover_only (Callable(c) → true: no click), skip (Callable(c) → true: not even hovered),
##       after (Callable(c, who, info) awaited after a click: put things back), reopen (Callable: the root closed),
##       esc (bool, default true: Esc back to the popup depth before the click), shots ("all" | "changed").
## Returns the list of clicked descriptions.
func crawl(get_root: Callable, label: String, opts := {}) -> Array:
	var visited := {}
	var clicked := []
	var vp := tree.root.get_visible_rect()
	var n := 0
	var max_n: int = mini(opts.get("max", 160), quick_max) if quick_max > 0 else opts.get("max", 160)
	var hover_only: Callable = opts.get("hover_only", func(_c): return false)
	var skip: Callable = opts.get("skip", func(_c): return false)
	while n < max_n:
		var root = get_root.call()
		if root == null or not is_instance_valid(root):
			if opts.has("reopen"):
				await opts.reopen.call()
				root = get_root.call()
			if root == null or not is_instance_valid(root): break
		var next = null
		for x in candidates(root, vp):
			if skip.call(x.c): continue
			if scroll_parent(x.c) == null and _visible_part(x.c, grect(x.c)).size.x < 4: continue # clipped away (the Workshop's other pane)
			var k := key_of(x.c)
			if visited.has(k): continue
			next = x
			break
		if next == null: break
		var c: Control = next.c
		visited[key_of(c)] = true
		n += 1
		var who := describe(c)
		step = label + ": " + who
		var sc := scroll_parent(c)
		if sc != null:
			sc.ensure_control_visible(c)
			await frames(3)
			if not is_instance_valid(c): continue
			visited[key_of(c)] = true
		# --- hover
		var area := grect(c).grow(36).intersection(vp)
		var img0 := await frame_image()
		var before := crop(img0, area)
		move(centre(c))
		await wait(6, 0.6)
		if not is_instance_valid(c): continue
		var h := tree.root.gui_get_hovered_control()
		if not reaches(c):
			find("reach", who + " @" + path_of(c, root), "the pointer at its centre lands on %s" % (describe(h) if h != null else "nothing"))
		var tip := check_tooltip(who)
		var img1 := await frame_image()
		var after := crop(img1, area)
		var changed := tip.size != Vector2.ZERO or (before != null and after != null and before.get_data() != after.get_data())
		if changed:
			add_to_sheet(crop(img1, area.merge(tip) if tip.size != Vector2.ZERO else area), "%s: %s" % [label, who])
		elif next.kind == "click" and reaches(c):
			find("hover", who + " @" + path_of(c, root), "no visible hover change")
		# --- leave
		park_mouse()
		await wait(4, 0.35)
		check_unhovered(c, who)
		if tooltip_rect().size != Vector2.ZERO:
			await wait(6, 0.4)
			if tooltip_rect().size != Vector2.ZERO: find("stuck", who, "a tooltip is still up after the pointer left")
		var lbl := label_of(c)
		var is_close: bool = lbl.begins_with("tip:Close") or lbl.begins_with("tip:Back to the") \
			or (c is TdButton and c.icon != null and c.icon == TdTheme.texture("icon_close") and str(c.name) != "Kick")
		if is_close and not opts.get("click_close", false): continue # × / Back: tested by the callers (Esc, reopen)
		if next.kind != "click" or hover_only.call(c) or not is_instance_valid(c) or not c.is_visible_in_tree(): continue
		# --- click
		var depth := TdPopup.open_popups.size()
		var scene0 := tree.current_scene
		var p := centre(c)
		await click_at(p)
		park_mouse()
		await wait(8, 0.7)
		clicked.append(who)
		var opened := TdPopup.open_popups.size() > depth
		var closed := TdPopup.open_popups.size() < depth
		var name := await shot("%s_click_%s" % [label, who.left(40)])
		var info := {"opened": opened, "closed": closed, "scene_changed": tree.current_scene != scene0, "shot": name}
		var t = top(root if is_instance_valid(root) else tree.current_scene)
		if t != null and is_instance_valid(t): audit(t, step, name)
		if opened and opts.get("esc", true):
			await esc_back(depth, who)
		if opts.has("after"): await opts.after.call(c, who, info)
	flush_sheet(label)
	return clicked

## Esc until the popup stack is back to `depth` (at most 3 presses); a state Esc cannot leave is a finding.
func esc_back(depth: int, who: String) -> bool:
	for i in 3:
		if TdPopup.open_popups.size() <= depth: return true
		await key(KEY_ESCAPE)
		await wait(6, 0.45)
	if TdPopup.open_popups.size() > depth:
		var t = TdPopup.open_popups.back()
		find("esc", who, "Esc ×3 does not leave %s" % (describe(t) if is_instance_valid(t) else "?"))
		while TdPopup.open_popups.size() > depth:
			var p = TdPopup.open_popups.back()
			if is_instance_valid(p): p.close()
			else: TdPopup.open_popups.pop_back()
			await frames(2)
		return false
	return true
