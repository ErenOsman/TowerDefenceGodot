class_name TdTowerTile
extends Control
## One owned tower in the hand editor's collection grid (mockup hand-select ".hc"): the portrait medallion, the name,
## the gold cost coin (top-left) and, when the tower is in the hand, a green badge with its slot number = key
## (top-right). Selected: cobalt. Click selects, double-click toggles it in / out of the hand, drag it onto a hand slot.
## No stats on the cards.

signal pressed(tower_id: String)
signal double_pressed(tower_id: String)

const SIZE := Vector2(108, 116)
const MEDAL := 60.0

var tower_id := ""
var selected := false
var _hovered := false
var _medal: Control
var _name: Label
var _pic: Texture2D

static func make(e: Dictionary, picture: Texture2D, key: int) -> TdTowerTile:
	var t := TdTowerTile.new()
	t.tower_id = e.id
	t._pic = picture
	t._build(e, key)
	return t

func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _hovered = true; _restyle())
	mouse_exited.connect(func(): _hovered = false; _restyle())

func _build(e: Dictionary, key: int) -> void:
	_medal = TdMenu.medallion(_pic, MEDAL)
	_medal.position = Vector2((SIZE.x - MEDAL) / 2.0, 12)
	add_child(_medal)
	_name = TdMenu.label(e.name, "micro", TdTheme.color("cream.100"), 18)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.position = Vector2(4, 80)
	_name.size = Vector2(SIZE.x - 8, 26)
	_name.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_name)
	var coin := TdHandSlot.coin(e.cost, 32.0)
	coin.position = Vector2(4, 4)
	add_child(coin)
	tooltip_text = e.name
	if key >= 0:
		var b := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = TdTheme.color("good.ink")
		sb.border_color = TdTheme.color("rim")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(7)
		b.add_theme_stylebox_override("panel", sb)
		b.size = Vector2(28, 28)
		b.position = Vector2(SIZE.x - 32, 4)
		b.mouse_filter = MOUSE_FILTER_IGNORE
		var l := TdMenu.label(str(key + 1), "micro", Color.WHITE, 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size = b.size
		l.position = Vector2(0, -1)
		b.add_child(l)
		add_child(b)
		tooltip_text = "%s · in hand, key %d" % [e.name, key + 1]

func set_selected(v: bool) -> void:
	selected = v
	_restyle()

func _restyle() -> void:
	if _medal != null: _medal.position.y = 12 - (3.0 if _hovered else 0.0)
	queue_redraw()

func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	if selected:
		sb.bg_color = Color("#4378C2")
		sb.border_color = TdTheme.color("accent.light")
		sb.set_border_width_all(3)
	else:
		sb.bg_color = Color("#605040") if _hovered else Color("#4E3D30")
		sb.border_color = TdTheme.color("rim")
		sb.set_border_width_all(2)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click: double_pressed.emit(tower_id)
		else: pressed.emit(tower_id)

func _get_drag_data(_at: Vector2) -> Variant:
	var holder := Control.new()
	var m := TdMenu.medallion(_pic, MEDAL)
	m.position = -Vector2(MEDAL, MEDAL) / 2.0
	m.modulate.a = 0.9
	holder.add_child(m)
	set_drag_preview(holder)
	return {"kind": "grid", "id": tower_id}
