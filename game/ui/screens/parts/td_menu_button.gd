class_name TdMenuButton
extends TdButton
## A main-menu list button (hud-menu-spec §5 MenuButton): the kit's deep menu sprites (MenuPrimary / MenuWood)
## with the icon and label left-aligned (icon at 28 px, label 16 px after it) instead of centred, an optional
## sub line under the title (Continue: "Two Roads") and an optional hint on the right shown on hover.

## A second line under the label (Nunito Bold 20); "" for none.
var sub := "":
	set(v):
		sub = v
		if _sub_label: _sub_label.text = v; _sub_label.visible = v != ""; _layout()
## Shown at the right while hovered (Nunito Bold 18); "" for none.
var hint := "":
	set(v):
		hint = v
		if _hint_label: _hint_label.text = v
var left_pad := 28.0

var _sub_label: Label
var _hint_label: Label

func _ready() -> void:
	super._ready()
	_sub_label = Label.new()
	_sub_label.mouse_filter = MOUSE_FILTER_IGNORE
	TdTheme.apply_type(_sub_label, "small", Color("#E6EFFF") if style == Style.MENU_PRIMARY else TdTheme.color("cream.200"), 20)
	_sub_label.text = sub
	_sub_label.visible = sub != ""
	_content.add_child(_sub_label)
	_hint_label = Label.new()
	_hint_label.mouse_filter = MOUSE_FILTER_IGNORE
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TdTheme.apply_type(_hint_label, "small", TdTheme.color("cream.200"), 18)
	_hint_label.text = hint
	_hint_label.visible = false
	_content.add_child(_hint_label)
	hover_changed.connect(func(h): if _hint_label: _hint_label.visible = h and hint != "" and interactable)
	_layout()

func _layout() -> void:
	super._layout()
	if not _built or _label == null: return
	if style != Style.MENU_PRIMARY and style != Style.MENU_WOOD and style != Style.PRIMARY and style != Style.SECONDARY and style != Style.DANGER: return
	var s := face_rect().size # the face (TdButton may reserve bleed room round it)
	var sink := 0.0 # pressed: the whole face node sinks (TdButton._pose), the label with it
	var has_icon := icon != null and _icon.visible
	var iw := 30.0 if s.y >= 80.0 else 26.0
	if has_icon:
		_icon.size = Vector2(iw, iw)
		_icon.position = Vector2(left_pad, (s.y - iw) / 2.0 + sink)
	var lx := left_pad + (iw + 18.0 if has_icon else 0.0)
	var two := _sub_label != null and _sub_label.visible
	var lh := _label.get_minimum_size().y
	if two:
		var shh := _sub_label.get_minimum_size().y
		var y0 := (s.y - lh - shh + 4.0) / 2.0
		_label.position = Vector2(lx, y0 + sink)
		_label.size = Vector2(s.x - lx - 16.0, lh)
		_sub_label.position = Vector2(lx, y0 + lh - 4.0 + sink)
		_sub_label.size = Vector2(s.x - lx - 16.0, shh)
	else:
		_label.position = Vector2(lx, sink)
		_label.size = Vector2(s.x - lx - 16.0, s.y)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _hint_label:
		_hint_label.position = Vector2(lx, sink)
		_hint_label.size = Vector2(s.x - lx - 24.0, s.y)
