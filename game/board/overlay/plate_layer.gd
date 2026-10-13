class_name PlateLayer
extends Control
## The plates over the board (PlateLayer.cs): one plate per entity with HP, following it on screen and scaled with
## the zoom. Compact by default (as wide as its tile on screen minus 8, 3 chip slots); the hovered or selected
## unit's plate is full (164 px bar, 4 slots with pills) on a dark backing and on top, the others dimmed to half.
## Statuses always show; the HP bar (Unity's rule, PlateLayer.cs) shows only with always_show_health, while the
## entity is hovered or selected, for health_bar_after_hit seconds after a hit (its HP + shield went down, also when
## the shield took it all, or hurt() from the damage presenter), while a health preview is on it, and while it dies
## (draining to zero for health_bar_after_death seconds, also for a unit killed from full HP). A plate with neither
## statuses nor a bar is empty. Status slots: defensive buffs → control → damage over time → the rest, newest first.

var cam: Camera3D = null
## StatusDef → Texture2D.
var icon_of: Callable = Callable()
## HP bars show on undamaged entities too (the Always Show Health setting).
var always_show_health: bool = false
## Entities whose plate is full and bar shows (the hovered and the selected one): id → true.
var focused: Dictionary = {}
## The HP a previewed hit or heal would leave each entity: id → int.
var health_preview: Dictionary = {}
var timings: PresentationTimings = null
## Makes a plate Control: the ui-kit's TdEntityStatus (KitPlate) by default; BoardPlate is the overlay's own
## drawn fallback with the same calls.
var make_plate: Callable = func(): return KitPlate.new()

var _plates := {}       # id → BoardPlate
var _dying := {}        # id → seconds since death
var _last_alive := {}   # id → [hp, max_hp]
var _last_toughness := {}
var _since_hit := {}
var _any_full := false
var _bars := {}         # id → whether its bar showed at the last refresh

## A frame's statuses in plate slot order — defensive buffs → control → damage over time → the rest, newest first
## within each group. The one rule for every status row (board plates and the HUD's inspector).
static func status_order(statuses: Array) -> Array:
	return OverlayStyle.ordered_statuses(statuses)

func _init() -> void:
	name = "Plates"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

## A hit landed on the entity: its HP bar shows for a moment.
func hurt(id: int) -> void:
	_since_hit[id] = 0.0

func has_statuses(id: int) -> bool:
	return _plates.has(id) and _plates[id].has_statuses

## The plate drawn for an entity (tests and tools), or null.
func plate_of(id: int):
	return _plates.get(id)

## Moves plates to their entities and shows the frame on them (dt: unscaled seconds).
func refresh(shown: ViewFrame, views: Dictionary, dt: float) -> void:
	if shown == null: return
	var t := timings if timings != null else PresentationTimings.defaults()
	_any_full = false
	for fid in focused:
		var ff: EntityFrame = shown.get_frame(fid)
		if views.has(fid) and ff != null and ff.has_hp and ff.life == LifeState.Alive: _any_full = true
	var seen := {}
	for id in views:
		var view = views[id]
		if view == null or not is_instance_valid(view): continue
		var f: EntityFrame = shown.get_frame(id)
		if f == null or not f.has_hp: continue
		if f.life != LifeState.Alive:
			var known := _dying.has(id)
			var age: float = _dying[id] + dt if known else 0.0
			if age > t.health_bar_after_death: continue
			if not known and not _plates.has(id):
				if not _last_alive.has(id): continue
				var ghost := EntityFrame.new()
				ghost.id = f.id
				ghost.life = LifeState.Alive
				ghost.has_hp = true
				ghost.hp = _last_alive[id][0]
				ghost.max_hp = _last_alive[id][1]
				_show(id, view, ghost, dt, t)
			_dying[id] = age
			seen[id] = true
			_show(id, view, f, dt, t)
			continue
		_dying.erase(id)
		_last_alive[id] = [f.hp, f.max_hp]
		var toughness := f.hp + f.shield
		if _last_toughness.has(id) and toughness < _last_toughness[id]: _since_hit[id] = 0.0
		elif _since_hit.has(id): _since_hit[id] += dt
		_last_toughness[id] = toughness
		seen[id] = true
		_show(id, view, f, dt, t)
	for id in _plates.keys():
		if not seen.has(id):
			_plates[id].queue_free()
			_plates.erase(id)
	for id in _last_alive.keys():
		if not views.has(id):
			_last_alive.erase(id)
			_dying.erase(id)
			_last_toughness.erase(id)
			_since_hit.erase(id)

func _show(id: int, view: EntityView, f: EntityFrame, dt: float, t: PresentationTimings) -> void:
	var plate = _plates.get(id)
	if plate == null:
		plate = make_plate.call() if make_plate.is_valid() else BoardPlate.new()
		if "icon_of" in plate: plate.icon_of = icon_of
		add_child(plate)
		_plates[id] = plate
	var screen := view.plate_screen_position(cam)
	plate.visible = screen.z > 0.0 and view.visible
	plate.place_at(Vector2(screen.x, screen.y))
	var is_focused := f.life == LifeState.Alive and focused.has(id)
	_form(plate, view, is_focused)
	plate.show_frame(f)
	var previewed := f.life == LifeState.Alive and health_preview.has(id)
	plate.set_health_preview(health_preview[id] if previewed else null)
	var bar := _bar_visible(id, f, t)
	_bars[id] = bar
	plate.set_health_visible(bar)
	if plate.has_method("tick"): plate.tick(dt)

## Whether the entity's HP bar shows now (Unity's rule, see the class summary).
func _bar_visible(id: int, f: EntityFrame, t: PresentationTimings) -> bool:
	if f.life != LifeState.Alive: return true
	if always_show_health or focused.has(id) or health_preview.has(id): return true
	return _since_hit.has(id) and _since_hit[id] <= t.health_bar_after_hit

## Whether an entity's HP bar showed at the last refresh (tests and tools).
func bar_shown(id: int) -> bool:
	return _plates.has(id) and _bars.get(id, false)

## Compact or full: the bar's width, the scale with the zoom, the draw order and the dimming of the others.
func _form(plate, view: EntityView, full: bool) -> void:
	var tile := WorldUi.tile_width(cam, view.global_position)
	var zoom := tile / maxf(1.0, WorldUi.reference_tile)
	var s := WorldUi.readable(zoom) if full else WorldUi.fit(zoom)
	var width := BoardPlate.FULL_WIDTH if full else maxf(24.0, (tile - 8.0) / maxf(0.01, s))
	plate.set_form(full, width, s, _any_full and not full)
	if full: move_child(plate, get_child_count() - 1)
