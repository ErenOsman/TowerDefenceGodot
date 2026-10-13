class_name BeamPresenter
extends TimedPresenter
## Columns of light dropping on the targets (Beam, spells, and attacks without a kind tag): 0.3 s, ready at 0.15.

var at: Array
var parent: Node
var _columns: Array = []

func _init(p_parent: Node = null, p_at: Array = []) -> void:
	super(0.3, 0.15)
	parent = p_parent
	at = p_at

func _on_begin() -> void:
	if parent == null or not is_instance_valid(parent): return
	var mat := BoardMaterials.overlay(Color(1.0, 1.0, 0.7, 0.6))
	for p in at:
		var c := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 1.0
		c.mesh = cyl
		c.material_override = mat
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(c)
		c.position = p + Vector3.UP * 3.0 # the board sits at the world origin
		c.scale = Vector3(0.3, 6.0, 0.3)
		_columns.append(c)

func _on_update(t: float) -> void:
	for c in _columns:
		if is_instance_valid(c): c.scale = Vector3(0.3 * (1.0 - t * 0.7), 6.0, 0.3 * (1.0 - t * 0.7))

func _on_finish() -> void:
	for c in _columns:
		if is_instance_valid(c): c.queue_free()
	_columns.clear()
