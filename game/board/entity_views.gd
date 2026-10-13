class_name EntityViews
extends RefCounted
## The views of the board's entities by EntityId (EntityViews.cs). Presenters create, move and remove them; after
## each beat sync() brings every view no presenter is moving in line with the frame, so a view can never stay out
## of date (a skipped move, an entity no presenter showed). Status loop VFX follow the frame the same way.

var parent: Node3D
## id → PackedScene or null (a placeholder).
var scene_for: Callable
## StatusDef → effect name ("" for none).
var status_vfx_for: Callable
## effect name → Node3D loop.
var make_loop: Callable
## id → plate offset (EntityAsset.plate_offset; 0 = automatic).
var plate_offset_for: Callable

var _views := {}  # id → EntityView

func _init(p_parent: Node3D, p_scene_for: Callable = Callable(), p_status_vfx_for: Callable = Callable(),
		p_plate_offset_for: Callable = Callable(), p_make_loop: Callable = Callable()) -> void:
	parent = p_parent
	scene_for = p_scene_for
	status_vfx_for = p_status_vfx_for
	plate_offset_for = p_plate_offset_for
	make_loop = p_make_loop

## id → EntityView (do not change it).
var all: Dictionary:
	get: return _views

func get_view(id: int) -> EntityView:
	var v = _views.get(id)
	return v if v != null and is_instance_valid(v) else null

func ensure(f: EntityFrame) -> EntityView:
	var v := get_view(f.id)
	if v != null: return v
	var scene: PackedScene = scene_for.call(f.id) if scene_for.is_valid() else null
	v = EntityView.create(parent, f, scene)
	v.plate_offset = plate_offset_for.call(f.id) if plate_offset_for.is_valid() else 0.0
	_views[f.id] = v
	return v

func remove(id: int) -> void:
	if not _views.has(id): return
	var v = _views[id]
	_views.erase(id)
	if v != null and is_instance_valid(v): v.queue_free()

## Matches every idle view to the frame: creates missing ones, places, shows corpses, removes the gone.
func sync(frame: ViewFrame) -> void:
	if frame == null: return
	for f in frame.entities.values():
		var is_new := not _views.has(f.id)
		var v := ensure(f)
		if v.animating > 0 and not is_new: continue
		v.place(f.pos)
		if f.life == LifeState.Dead: v.show_corpse()
		else:
			v.show_alive()
			v.set_team(f)
			v.set_status_vfx(_status_vfx(f), make_loop)
	for id in _views.keys():
		var v := get_view(id)
		if v == null:
			_views.erase(id)
			continue
		if frame.get_frame(id) == null and v.animating == 0: remove(id)

func _status_vfx(f: EntityFrame) -> Dictionary:
	var wanted := {}
	if not status_vfx_for.is_valid(): return wanted
	for s in f.statuses:
		if s.def == null: continue
		var fx: String = status_vfx_for.call(s.def)
		if fx != "": wanted[s.def] = fx
	return wanted

## Frees every view (leaving the level).
func clear() -> void:
	for id in _views.keys(): remove(id)
