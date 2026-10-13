class_name MarkerLayer
extends Control
## Markers over the board (MarkerLayer.cs): above each entity's plate, a chip or a bare word / number (the "-6"
## a forecast would take, "+4", a "Kills" tag) and an optional row of pips, following the entity on screen.
## Never takes the pointer. Markers are OverlayMarker values (set() replaces them all).

const ABOVE := 54.0          # reference pixels over the plate point, clear of its status chips
const ABOVE_NO_STATUS := 14.0

var cam: Camera3D = null
var _markers := {}           # id → OverlayMarker
var _views := {}             # id → Control (a VBox: chip label, pips)

func _init() -> void:
	name = "Markers"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

## Replaces every marker (null or empty clears them).
func set_markers(list) -> void:
	_markers.clear()
	if list != null:
		for m in list: _markers[m.id] = m
	for id in _views.keys():
		if not _markers.has(id):
			_views[id].queue_free()
			_views.erase(id)
	for m in _markers.values(): _fill(_view_of(m.id), m)

## The markers set now (tests).
var markers: Dictionary:
	get: return _markers

## Moves the markers over their entities' heads, scaled with the zoom there.
func tick(entities: Dictionary, has_statuses: Callable = Callable()) -> void:
	for id in _views:
		var v: Control = _views[id]
		var entity = entities.get(id)
		var on: bool = entity != null and is_instance_valid(entity) and entity.visible
		var screen := Vector3.ZERO
		if on:
			screen = entity.plate_screen_position(cam)
			on = screen.z > 0.0
		v.visible = on
		if not on: continue
		var zoom := WorldUi.zoom(cam, entity.global_position)
		var lift := ABOVE if (not has_statuses.is_valid() or has_statuses.call(id)) else ABOVE_NO_STATUS
		var s := WorldUi.readable(zoom)
		v.scale = Vector2.ONE * s
		v.position = Vector2(screen.x, screen.y - lift * WorldUi.fit(zoom)) - Vector2(v.size.x * 0.5, v.size.y) * s

func _view_of(id: int) -> Control:
	if _views.has(id): return _views[id]
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 4)
	var chip := PanelContainer.new()
	chip.name = "Chip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(chip)
	var label := Label.new()
	label.name = "Text"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	var pips := HBoxContainer.new()
	pips.name = "Pips"
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.add_theme_constant_override("separation", 4)
	box.add_child(pips)
	add_child(box)
	_views[id] = box
	return box

func _fill(v: Control, m: OverlayMarker) -> void:
	var chip: PanelContainer = v.get_node("Chip")
	var label: Label = chip.get_node("Text")
	var has_chip := m.chip != null
	chip.visible = has_chip or m.text != ""
	if has_chip:
		var sb := StyleBoxTexture.new()
		sb.texture = m.chip
		sb.texture_margin_left = 14
		sb.texture_margin_right = 14
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 8
		chip.add_theme_stylebox_override("panel", sb)
	else:
		chip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	label.text = m.text
	label.label_settings = OverlayStyle.world_label(20 if has_chip else 30, m.text_color)
	var pips: HBoxContainer = v.get_node("Pips")
	for c in pips.get_children(): c.queue_free()
	pips.visible = m.pips.size() > 0
	for tex in m.pips:
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = Vector2(18, 18)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(r)
	v.reset_size()
