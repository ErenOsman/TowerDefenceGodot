class_name PatternDef
extends RefCounted
## A pattern: shape, distance metric, radius range, orientation and blocking rules.
## The pattern gives the shape; formulas (Targeting phase) give the size.
## C# PatternDef.Self() is `self_()` here (`self` is a keyword).

var shape: int = Shape.Diamond
## [Slot("Targeting")]
var min_radius: Formula = Formula.new("0")
## [Slot("Targeting")]
var max_radius: Formula = Formula.new("0")
var orientation: int = PatternOrientation.TowardTarget
var include_center: bool = true
var requires_line_of_sight: bool = false

## For Line: stop at the first wall (excluded) or projectile-blocking entity (included).
var stop_at_first_blocker: bool = false

## For Ray and blocking Lines: the caster's allies do not stop the shot.
var passes_allies: bool = true

## For PathAhead: units in the way are hopped over (it lands only on free tiles; gaps still stop it). Use with a Jump step.
var jumps_over_units: bool = false

## For Custom: offsets from the centre (rotation not applied). Array of Vector2i.
var custom: Array = []

static func _make(p_shape: int, p_max = null, p_min = null, p_include_center := true) -> PatternDef:
	var p := PatternDef.new()
	p.shape = p_shape
	if p_max != null: p.max_radius = Formula.of(p_max)
	if p_min != null: p.min_radius = Formula.of(p_min)
	p.include_center = p_include_center
	return p

## The caster's own tile (as targeting). C# Self().
static func self_() -> PatternDef: return _make(Shape.Single)

## The aimed tile only (as an attack area): single-target.
static func single() -> PatternDef: return _make(Shape.Single)
static func diamond(p_max, p_min = "0") -> PatternDef: return _make(Shape.Diamond, p_max, p_min)
static func circle(p_max) -> PatternDef: return _make(Shape.Circle, p_max)
static func square(p_max) -> PatternDef: return _make(Shape.Square, p_max)
static func plus(p_max) -> PatternDef: return _make(Shape.Plus, p_max)
static func line(p_max, p_stop_at_first_blocker := false) -> PatternDef:
	var p := _make(Shape.Line, p_max, "1", false)
	p.stop_at_first_blocker = p_stop_at_first_blocker
	return p
## A straight shot at any angle to the aimed tile, stopped by the first wall or blocker.
static func ray(p_passes_allies := true) -> PatternDef:
	var p := _make(Shape.Ray)
	p.passes_allies = p_passes_allies
	return p

static func cone(p_max) -> PatternDef: return _make(Shape.Cone, p_max, "1", false)
static func steps(p_max) -> PatternDef: return _make(Shape.Steps, p_max, "1", false)
static func path_ahead(p_max) -> PatternDef: return _make(Shape.PathAhead, p_max, "1", false)

## Distance of an offset in this pattern's metric (Line/Cone: along the direction).
func distance(dx: int, dy: int, dir: Vector2i) -> int:
	match shape:
		Shape.Square, Shape.Diagonal:
			return maxi(absi(dx), absi(dy))
		Shape.Circle:
			# smallest r with 4(dx² + dy²) ≤ (2r + 1)²
			var r := 0
			while true:
				if 4 * (dx * dx + dy * dy) <= (2 * r + 1) * (2 * r + 1): return r
				r += 1
			return r
		Shape.Line, Shape.Cone:
			return absi(dx) + absi(dy) if dir == Vector2i.ZERO else maxi(absi(dx), absi(dy))
		_:
			return absi(dx) + absi(dy)

var is_directional: bool:
	get: return shape == Shape.Line or shape == Shape.Cone

## Movement shapes give each tile a route (Aim.Path) as well as a distance.
var is_movement: bool:
	get: return shape == Shape.Steps or shape == Shape.PathAhead
