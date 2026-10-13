class_name TdHandSlot
extends Control
## One of the hand editor's 8 hand slots (the tray piece of the mockup hand-select): filled, the tower's miniature
## standing on its shadow, a name plate, the gold cost coin (top-left) and the slot number = the in-level key
## (top-right; a red × replaces it on hover: take it out); empty, a dashed socket with a ghost plinth and its number.
## Late (after the level's cap): dimmed. Drag a filled slot to reorder (drop on another slot) or out of the strip to
## take it out; drop a collection card on a slot to put it there. Clicking a filled slot selects its tower.

signal pressed(tower_id: String)
signal removed(tower_id: String)
## A drag (hand piece or collection card) dropped here: data {"kind": "hand"|"grid", "id"}.
signal dropped(data: Dictionary, slot: int)
## This piece started being dragged.
signal drag_began(tower_id: String)

const SIZE := Vector2(104, 126)
const PLATE_Y := 96.0
const FIG := 88.0

var slot := 0
var tower_id := ""
var late := false
var selected := false
var _hovered := false
var _over := false
var _fig: TextureRect
var _plate: TdButton
var _x: Control
var _key: Label

## A filled slot (type may be null).
static func filled(index: int, owned: OwnedTower, type: TowerAsset, mini: Texture2D) -> TdHandSlot:
	var s := TdHandSlot.new()
	s.slot = index
	s.tower_id = owned.id if owned != null else ""
	s._build(owned, type, mini)
	return s

static func empty(index: int) -> TdHandSlot:
	var s := TdHandSlot.new()
	s.slot = index
	s._build(null, null, null)
	return s

func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _hovered = true; _restyle())
	mouse_exited.connect(func(): _hovered = false; _over = false; _restyle())

func _build(owned: OwnedTower, type: TowerAsset, mini: Texture2D) -> void:
	if tower_id == "":
		var n := TdMenu.label(str(slot + 1), "micro", TdTheme.color("cream.300"), 18)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.position = Vector2(0, PLATE_Y + 2)
		n.size = Vector2(SIZE.x, 24)
		add_child(n)
		tooltip_text = "Slot %d (key %d): drop a tower here" % [slot + 1, slot + 1]
		return
	var shadow := TdMenu.picture(TdTheme.texture("piece_shadow"), Vector2(90, 26))
	shadow.position = Vector2((SIZE.x - 90) / 2.0, PLATE_Y - 22)
	add_child(shadow)
	_fig = TdMenu.picture(mini, Vector2(FIG, FIG))
	_fig.position = Vector2((SIZE.x - FIG) / 2.0, PLATE_Y - FIG + 4)
	add_child(_fig)
	_plate = TdButton.new()
	_plate.style = TdButton.Style.NAME_PLATE
	_plate.custom_minimum_size = Vector2(100, 28)
	_plate.size = Vector2(100, 28)
	_plate.text = MenuLogic.tower_name(owned, type)
	_plate.mouse_filter = MOUSE_FILTER_IGNORE
	_plate.position = Vector2((SIZE.x - 100) / 2.0, PLATE_Y)
	add_child(_plate)
	if type != null:
		var coin := TdHandSlot.coin(type.cost, 30.0)
		coin.position = Vector2(0, 2)
		add_child(coin)
	_key = TdMenu.label(str(slot + 1), "micro", TdTheme.color("cream.100"), 20)
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_key.position = Vector2(SIZE.x - 40, 2)
	_key.size = Vector2(36, 26)
	TdTheme.outline(_key, 4)
	add_child(_key)
	_x = _remove_button()
	_x.position = Vector2(SIZE.x - 30, 0)
	_x.visible = false
	add_child(_x)

## The gold cost coin (a round gold badge with the number in dark ink), `d` px across.
static func coin(cost: int, d: float) -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = TdTheme.color("gold")
	sb.border_color = TdTheme.color("rim")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(d / 2.0))
	p.add_theme_stylebox_override("panel", sb)
	var w := maxf(d, 14.0 + 10.0 * str(cost).length())
	p.size = Vector2(w, d)
	p.custom_minimum_size = p.size
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = str(cost)
	TdTheme.apply_type(l, "micro", Color("#2A1D00"), 18 if d >= 30.0 else 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = p.size
	l.position = Vector2(0, -1)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

func _remove_button() -> Control:
	var b := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = TdTheme.color("danger.mid")
	sb.border_color = TdTheme.color("rim")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(15)
	b.add_theme_stylebox_override("panel", sb)
	b.size = Vector2(30, 30)
	b.mouse_filter = MOUSE_FILTER_STOP
	b.tooltip_text = "Take out of the hand"
	var ic := TdMenu.picture(TdTheme.texture("icon_close"), Vector2(16, 16))
	ic.position = Vector2(7, 7)
	b.add_child(ic)
	b.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			b.accept_event()
			removed.emit(tower_id)
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			b.accept_event())
	return b

func set_late(v: bool) -> void:
	late = v
	_restyle()

func set_selected(v: bool) -> void:
	selected = v
	_restyle()

func _restyle() -> void:
	modulate.a = 0.6 if late and not _hovered else 1.0
	if _plate != null:
		_plate.set_extra_state("Selected" if selected else "")
		_plate.force_state(_hovered, false)
	if _fig != null: _fig.position.y = PLATE_Y - FIG + 4 - (10.0 if _hovered else 0.0)
	if _x != null:
		_x.visible = _hovered
		_key.visible = not _hovered
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2(3, 4), SIZE - Vector2(6, 6))
	if tower_id == "":
		var col := Color(TdTheme.color("cream.100"), 0.25)
		_dashed_round_rect(r, 12.0, col)
		# the ghost plinth: a flat dashed ellipse
		var c := Vector2(SIZE.x / 2.0, PLATE_Y - 26)
		var pts := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			pts.append(c + Vector2(cos(a) * 34.0, sin(a) * 11.0))
		for i in range(0, 32, 2): draw_line(pts[i], pts[i + 1], col, 2.0, true)
	if _over:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.3, 0.56, 0.9, 0.15)
		sb.border_color = TdTheme.color("accent.light")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(14)
		draw_style_box(sb, r)

func _dashed_round_rect(r: Rect2, rad: float, col: Color) -> void:
	var a := r.position
	var b := r.end
	draw_dashed_line(Vector2(a.x + rad, a.y), Vector2(b.x - rad, a.y), col, 2.0, 7.0)
	draw_dashed_line(Vector2(a.x + rad, b.y), Vector2(b.x - rad, b.y), col, 2.0, 7.0)
	draw_dashed_line(Vector2(a.x, a.y + rad), Vector2(a.x, b.y - rad), col, 2.0, 7.0)
	draw_dashed_line(Vector2(b.x, a.y + rad), Vector2(b.x, b.y - rad), col, 2.0, 7.0)
	draw_arc(Vector2(a.x + rad, a.y + rad), rad, PI, PI * 1.5, 6, col, 2.0, true)
	draw_arc(Vector2(b.x - rad, a.y + rad), rad, PI * 1.5, TAU, 6, col, 2.0, true)
	draw_arc(Vector2(b.x - rad, b.y - rad), rad, 0, PI * 0.5, 6, col, 2.0, true)
	draw_arc(Vector2(a.x + rad, b.y - rad), rad, PI * 0.5, PI, 6, col, 2.0, true)

# ------------------------------------------------------------------ input, drag and drop

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if tower_id != "" and Rect2(Vector2.ZERO, size).has_point(event.position): pressed.emit(tower_id)

func _get_drag_data(_at: Vector2) -> Variant:
	if tower_id == "": return null
	var ghost := TdMenu.picture(_fig.texture if _fig != null else null, Vector2(FIG, FIG))
	ghost.modulate.a = 0.9
	ghost.rotation = -0.08
	var holder := Control.new()
	holder.add_child(ghost)
	ghost.position = -Vector2(FIG, FIG) / 2.0
	set_drag_preview(holder)
	drag_began.emit(tower_id)
	return {"kind": "hand", "id": tower_id, "from": slot}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.get("kind", "") in ["hand", "grid"]
	if ok != _over:
		_over = ok
		queue_redraw()
	return ok

func _drop_data(_at: Vector2, data: Variant) -> void:
	_over = false
	queue_redraw()
	dropped.emit(data, slot)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _over:
		_over = false
		queue_redraw()
