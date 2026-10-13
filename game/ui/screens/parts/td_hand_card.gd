class_name TdHandCard
extends Control
## One tower of the hand in the menus (level select's hand strip, the hand editor): a round portrait medallion with
## a name plate under it (the Unity build's look), optional cost badge and slot number. Dimmed when benched (beyond
## the level's hand cap). Click: `pressed`. Hover lifts it and lights the plate.

signal pressed

const SIZE := Vector2(130, 150)
const MEDAL := 80.0
const MEDAL_AT := Vector2(25, 22)

var tower_id := ""
var _plate: TdButton
var _medal: Control
var _dimmed := false
var _hovered := false

## Builds the card for an owned tower (type may be null for an unknown one).
static func make(owned: OwnedTower, type: TowerAsset, index := -1) -> TdHandCard:
	var c := TdHandCard.new()
	c.tower_id = owned.id if owned != null else ""
	c._build(owned, type, index)
	return c

func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _hovered = true; _refresh())
	mouse_exited.connect(func(): _hovered = false; _refresh())

func _build(owned: OwnedTower, type: TowerAsset, index: int) -> void:
	var view := type.entity.view if type != null and type.entity != null else ""
	var icon := type.icon if type != null else ""
	_medal = TdMenu.medallion(TdMenu.unit_picture(view, icon), MEDAL)
	_medal.position = MEDAL_AT
	add_child(_medal)
	_plate = TdButton.new()
	_plate.style = TdButton.Style.NAME_PLATE
	_plate.custom_minimum_size = Vector2(120, 30)
	_plate.size = Vector2(120, 30)
	_plate.text = MenuLogic.tower_name(owned, type)
	_plate.mouse_filter = MOUSE_FILTER_IGNORE
	_plate.position = Vector2((SIZE.x - 120) / 2.0, 114)
	add_child(_plate)
	if type != null:
		# the cost: a 36 px gold coin with a dark number, clear of the medallion's ring (top-left corner)
		var coin := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = TdTheme.color("gold")
		sb.border_color = TdTheme.color("gold.dark")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(18)
		coin.add_theme_stylebox_override("panel", sb)
		coin.size = Vector2(36, 36)
		coin.position = Vector2(0, 0)
		coin.mouse_filter = MOUSE_FILTER_IGNORE
		var cost := Label.new()
		cost.text = str(type.cost)
		TdTheme.apply_type(cost, "micro", Color("#2E2117"), 18 if type.cost < 1000 else 14)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost.size = coin.size
		cost.mouse_filter = MOUSE_FILTER_IGNORE
		coin.add_child(cost)
		add_child(coin)
	if index >= 0:
		var n := Label.new()
		n.text = str(index + 1)
		TdTheme.apply_type(n, "micro", TdTheme.color("cream.200"), 20)
		n.position = Vector2(SIZE.x - 18, 0)
		n.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(n)

## Benched: dimmed (the level leaves it home).
func set_dimmed(v: bool) -> void:
	_dimmed = v
	_refresh()

func _refresh() -> void:
	modulate = Color(1, 1, 1, 0.45 if _dimmed and not _hovered else (0.8 if _dimmed else 1.0))
	if _plate: _plate.force_state(_hovered, false)
	if _medal: _medal.position.y = MEDAL_AT.y - (4.0 if _hovered else 0.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Rect2(Vector2.ZERO, size).has_point(event.position): pressed.emit()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
