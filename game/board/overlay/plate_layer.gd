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
var _full_id := -1      # the unit whose full plate shows (its status chips have tooltips)
var _hold_id := -1      # the pointer is on that full plate: it stays full (the tile behind it is not "hovered")
var _tip_key := ""      # the status chip under the pointer, and how long it has been there (unscaled)
var _tip_time := 0.0
var _tip_open := false
const TOOLTIP_DELAY := 0.4

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
	# the pointer resting on a full plate keeps it full, so its status chips can be read
	var mouse := get_viewport().get_mouse_position() if get_viewport() != null else Vector2(-1e6, -1e6)
	if _hold_id >= 0 and _plates.has(_hold_id) and _plates[_hold_id].has_method("plate_rect") and _plates[_hold_id].plate_rect().grow(6).has_point(mouse):
		focused[_hold_id] = true
	else: _hold_id = -1
	_any_full = false
	_full_id = -1
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
	_status_tooltip(mouse, dt)
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
	if is_focused: _full_id = id
	_form(plate, view, is_focused)
	plate.show_frame(f)
	var previewed := f.life == LifeState.Alive and health_preview.has(id)
	plate.set_health_preview(health_preview[id] if previewed else null)
	var bar := _bar_visible(id, f, t)
	_bars[id] = bar
	plate.set_health_visible(bar)
	if plate.has_method("tick"): plate.tick(dt)

## Status tooltips on the board, on the full plate only: the chip under the pointer (found by position: the plate
## never takes the pointer) opens its status's tooltip right of the plate after TOOLTIP_DELAY.
func _status_tooltip(mouse: Vector2, dt: float) -> void:
	var plate = _plates.get(_full_id) if _full_id >= 0 else null
	var hit: Array = plate.chip_at(mouse) if plate != null and plate.visible and plate.has_method("chip_at") else []
	if hit.is_empty():
		_tip_key = ""
		_tip_time = 0.0
		if _tip_open:
			TdTooltip.hide(self)
			_tip_open = false
		return
	_hold_id = _full_id
	if hit[0] != _tip_key:
		_tip_key = hit[0]
		_tip_time = 0.0
		if _tip_open:
			TdTooltip.hide(self)
			_tip_open = false
	_tip_time += dt
	if _tip_open or _tip_time < TOOLTIP_DELAY: return
	var sv: StatusView = plate.views_by_key.get(_tip_key)
	if sv == null: return
	var d: StatusDef = sv.def
	var harmful := d != null and d.has_tag(Tags.Debuff)
	var helpful := d != null and d.has_tag(Tags.Buff)
	var rounds := d != null and d.duration_unit == DurationUnit.Rounds
	var shield := sv.shield > 0
	# the description filled in the same way as the HUD inspector's status tooltips ({stacks}, {turns})
	var desc := HudText.status_description(d.description, sv.stacks, sv.turns_left) if d != null else ""
	var c := TooltipText.status(sv.name, desc, harmful, helpful, sv.shield if shield else sv.stacks,
		sv.turns_left, rounds, true, ", ".join(sv.applied_by), "left" if shield else "stacks")
	TdTooltip.show_content_beside(c, hit[1], TdTooltipPlacement.Side.RIGHT, plate.plate_rect())
	TdTooltip.own(self)
	_tip_open = true

## Whether the entity's HP bar shows now (Unity's rule, see the class summary).
func _bar_visible(id: int, f: EntityFrame, t: PresentationTimings) -> bool:
	var since: float = _since_hit[id] if _since_hit.has(id) else -1.0
	return bar_rule(f.life == LifeState.Alive, always_show_health, focused.has(id), health_preview.has(id), since, t.health_bar_after_hit)

## Unity's HP bar rule (PlateLayer.Show): the bar shows with Always Show Health, while hovered or selected (focused),
## while a hit or heal is previewed on it (alive only), for after_hit seconds after its HP + shield last went down
## (since_hit < 0: never hit), and while it dies (the dying window itself is PlateLayer.refresh's).
static func bar_rule(alive: bool, always: bool, is_focused: bool, previewed: bool, since_hit: float, after_hit: float) -> bool:
	if not alive: return true
	if always or is_focused or previewed: return true
	return since_hit >= 0.0 and since_hit <= after_hit

## A plate's form at a tile's on-screen width (canvas px) against the reference tile (WorldUi, PlateLayer.Form):
## [scale, bar width before the scale]. Full: readable (never below 1), 164 wide; compact: fit (shrinks zoomed
## out), the tile − 8 on screen at any zoom (at least 24).
static func form_metrics(tile: float, reference: float, full: bool) -> Array:
	var zoom := tile / maxf(1.0, reference)
	var s := WorldUi.readable(zoom) if full else WorldUi.fit(zoom)
	var width := KitPlate.FULL_WIDTH if full else maxf(24.0, (tile - 8.0) / maxf(0.01, s))
	return [s, width]

## Whether an entity's HP bar showed at the last refresh (tests and tools).
func bar_shown(id: int) -> bool:
	return _plates.has(id) and _bars.get(id, false)

## Compact or full: the bar's width, the scale with the zoom, the draw order and the dimming of the others.
func _form(plate, view: EntityView, full: bool) -> void:
	var m := form_metrics(WorldUi.tile_width(cam, view.global_position), WorldUi.reference_tile, full)
	plate.set_form(full, m[1], m[0], _any_full and not full)
	if full: move_child(plate, get_child_count() - 1)
