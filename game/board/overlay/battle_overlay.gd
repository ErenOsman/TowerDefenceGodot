class_name BattleOverlay
extends CanvasLayer
## The screen-space layer over the board (BattleOverlay.cs) and its parts: plates (HP and statuses following each
## entity), markers (forecast numbers, Kills tags), floaters (damage numbers and words), banners (round, phase,
## waves, messages) and the sequence marks (ring, dim, arrow). Values come from the Director's shown frame, never
## from GameState. Layer −1: under the HUD (layer 0 and up) and menus. Nothing here takes the pointer.

var cam: Camera3D = null
var plates: PlateLayer
var markers: MarkerLayer
var floaters: FloaterLayer
var banners: BannerLayer
var sequence: SequenceMarks

func _init() -> void:
	name = "Battle Overlay"
	layer = -1

## cam: the board camera; icon_of: StatusDef → Texture2D (or null).
func setup(p_cam: Camera3D, icon_of: Callable = Callable()) -> void:
	cam = p_cam
	plates = PlateLayer.new()
	plates.cam = cam
	plates.icon_of = icon_of
	add_child(plates)
	markers = MarkerLayer.new()
	markers.cam = cam
	add_child(markers)
	floaters = FloaterLayer.new()
	floaters.cam = cam
	add_child(floaters)
	sequence = SequenceMarks.new()
	add_child(sequence)
	banners = BannerLayer.new()
	add_child(banners)

## HP bars show on undamaged entities too (the Always Show Health setting).
var always_show_health: bool:
	get: return plates != null and plates.always_show_health
	set(v):
		if plates != null: plates.always_show_health = v

## Entities whose plate is full and bar shows: id → true.
var focused: Dictionary:
	get: return plates.focused if plates != null else {}
	set(v):
		if plates != null: plates.focused = v

## A hit landed on the entity (damage above 0, also when a shield took it all): its HP bar shows for a moment.
func hurt(id: int) -> void:
	if plates != null: plates.hurt(id)

## Moves plates to their entities, ticks floaters and banners (dt unscaled seconds).
func refresh(shown: ViewFrame, views: Dictionary, dt: float) -> void:
	if plates == null: return
	plates.timings = PresentationTimings.get_timings()
	plates.refresh(shown, views, dt)
	markers.tick(views, plates.has_statuses)
	floaters.tick(dt)
	if cam is BoardCamera: banners.centre_x = (cam as BoardCamera).free_centre().x
	banners.tick(dt)
	sequence.tick(dt)

## Words that rise from a point in the world and fade (damage numbers, Miss, +Poison). life ≤ 0: the timing.
func float_text(world: Vector3, text: String, color: Color, life: float = -1.0, font_size: int = 40) -> void:
	if life <= 0.0: life = PresentationTimings.get_timings().floating_text
	if floaters != null: floaters.float_text(world, text, color, life, font_size)

## A banner over the board (see BannerLayer); kind: banners of one kind replace each other.
func banner(text: String, seconds: float, sticky: bool = false, kind = null) -> void:
	if banners != null: banners.show_banner(text, seconds, sticky, kind)

## Replaces the markers over entities (Array of OverlayMarker; null clears them).
func set_markers(list) -> void:
	if markers != null: markers.set_markers(list)

## The HP a previewed hit or heal would leave each entity (id → int), striped on its bar; {} clears it.
func set_health_preview(hp: Dictionary) -> void:
	if plates != null: plates.health_preview = hp

## Hides the banner and the waiting ones (not a sticky one).
func hide_banner() -> void:
	if banners != null: banners.hide_banner()
