class_name HudHandPiece
extends Control
## One tower of the hand in the tray (hud-menu-spec §6.4, UI Design Rules "The hand is a tray of miniatures"): a slot
## 124 × 160 whose parts move, never the slot. States (priority Placed > Picked > CantAfford > InHand):
## - in hand: the miniature on its plinth (112 tall), name plate, gold cost coin top-left, key top-right; hover lifts it
##   16 px and scales 1.06; Picked (placing) lifts 30 px, scale 1.1 with the gold glow;
## - can't afford: the miniature at 40 % and grey, the coin red, the plate poor; a click shakes it and says what is missing;
## - placed: the empty plinth with the tower's colour portrait medallion, the "placed" plate, an HP bar (numbers on
##   hover) and, when show_pips, one mini pip per ability; hover lights its ring on the board;
## - selected (its tower is selected): the cobalt plate, the bright medallion ring lifted 8 px (and the arrow when
##   show_arrow).
## The HUD fills it with show(...) and listens to `pressed`.

signal pressed(piece: HudHandPiece)
signal hover_changed(piece: HudHandPiece, hovered: bool)

const SLOT := Vector2(124, 160)
## Mini cooldown pips on placed pieces. Off: the 2026-10-09 build review removed them (the Unity build shows none).
static var show_pips := false
## The arrow over the selected piece. Off: selection is colour only (2026-10-09 review, Unity build).
static var show_arrow := false

var tower_id := ""
var index := 0
var hovered := false

var _shadow: TextureRect
var _glow: TextureRect
var _render: TextureRect
var _plinth: TextureRect
var _medal: Control
var _plate: TdButton
var _onboard: TextureRect
var _cost: Panel
var _cost_label: Label
var _key: Label
var _hp: TdHealthBar
var _pips: HBoxContainer
var _arrow: TextureRect
var _trigger: TdTooltipTrigger

var _placed := false
var _picked := false
var _poor := false
var _selected := false
var _lift := 0.0
var _scale := 1.0
var _shake_t := 1.0
var _clock := 0.0
var _deny_left := 0.0

func _init() -> void:
	custom_minimum_size = SLOT
	size = SLOT
	mouse_filter = MOUSE_FILTER_STOP

func _ready() -> void:
	_shadow = HudArt.sprite("piece_shadow", Vector2(104, 30))
	_shadow.position = Vector2((SLOT.x - 104) / 2.0, SLOT.y - 30 - 30)
	_shadow.pivot_offset = Vector2(52, 15)
	add_child(_shadow)
	_glow = HudArt.sprite("piece_glow", Vector2(150, 150), Color(TdTheme.color("gold"), 0.7))
	_glow.position = Vector2((SLOT.x - 150) / 2.0, -4)
	_glow.visible = false
	add_child(_glow)
	_plinth = HudArt.sprite("piece_plinth_empty", Vector2(108, 52))
	_plinth.position = Vector2((SLOT.x - 108) / 2.0, SLOT.y - 52 - 44)
	add_child(_plinth)
	_render = TextureRect.new()
	_render.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_render.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_render.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_render.mouse_filter = MOUSE_FILTER_IGNORE
	_render.size = Vector2(112, 112)
	_render.pivot_offset = Vector2(56, 112)
	add_child(_render)
	_medal = HudArt.medallion(64, "medallion_ring", 8)
	_medal.pivot_offset = Vector2(32, 32)
	add_child(_medal)
	_plate = TdButton.new()
	_plate.style = TdButton.Style.NAME_PLATE
	_plate.custom_minimum_size = Vector2(108, 28)
	_plate.size = Vector2(108, 28)
	add_child(_plate)
	_plate.mouse_filter = MOUSE_FILTER_IGNORE
	_onboard = HudArt.sprite("icon_onboard", Vector2(16, 16))
	_onboard.visible = false
	_cost = Panel.new()
	_cost.mouse_filter = MOUSE_FILTER_IGNORE
	_cost.position = Vector2(4, 6)
	_cost.size = Vector2(52, 30)
	add_child(_cost)
	_cost_label = HudArt.label("", "micro", TdTheme.color("gold.light"), 20)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.size = Vector2(52, 30)
	_cost_label.position = Vector2(0, -1)
	_cost.add_child(_cost_label)
	_key = HudArt.label("", "micro", TdTheme.color("cream.200"))
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_key.position = Vector2(SLOT.x - 44, 6)
	_key.size = Vector2(36, 24)
	TdTheme.outline(_key, 4)
	add_child(_key)
	_hp = TdHealthBar.new()
	_hp.variant = TdHealthBar.Variant.PLATE
	_hp.size = Vector2(100, 8)
	_hp.position = Vector2((SLOT.x - 100) / 2.0, SLOT.y - 12)
	_hp.outlined_label = true
	add_child(_hp)
	_pips = HudArt.hbox(4)
	_pips.position = Vector2(4, 4)
	add_child(_pips)
	_arrow = HudArt.sprite("piece_selected_arrow", Vector2(28, 20))
	_arrow.position = Vector2((SLOT.x - 28) / 2.0, -22)
	_arrow.visible = false
	add_child(_arrow)
	_trigger = TdTooltipTrigger.new()
	add_child(_trigger)
	mouse_entered.connect(func():
		hovered = true
		hover_changed.emit(self, true)
		_restyle())
	mouse_exited.connect(func():
		hovered = false
		if _deny_left > 0.0:
			_deny_left = 0.0
			TdTooltip.hide(self)
		hover_changed.emit(self, false)
		_restyle())

## Fills the piece. placed_frame: the tower's frame on the board (null in hand). cooldowns: [[left, held], …] per ability.
func show_state(p_tower_id: String, p_index: int, tower_name: String, cost: int, key: String, mini: Texture2D, portrait: Texture2D,
		placed_frame: EntityFrame, cooldowns: Array, picked: bool, affordable: bool, selected: bool) -> void:
	tower_id = p_tower_id
	index = p_index
	_placed = placed_frame != null
	_picked = picked and not _placed
	_poor = not affordable and not _placed
	_selected = selected and _placed
	_plate.text = tower_name
	_render.texture = mini
	HudArt.set_medallion(_medal, portrait, "medallion_ring_selected" if _selected else "medallion_ring")
	_cost_label.text = str(cost)
	_cost.add_theme_stylebox_override("panel", TdTheme.stylebox("badge_cost_poor" if _poor else "badge_cost"))
	_cost_label.add_theme_color_override("font_color", TdTheme.color("bad") if _poor else TdTheme.color("gold.light"))
	_key.text = key
	if _placed:
		_hp.set_health(placed_frame.hp, placed_frame.max_hp)
	for c in _pips.get_children():
		_pips.remove_child(c)
		c.queue_free()
	if _placed and show_pips:
		for cd in cooldowns:
			var name := "pip_mini_held" if cd[1] else ("pip_mini_wait" if cd[0] > 0 else "pip_mini_ready")
			_pips.add_child(HudArt.sprite(name, Vector2(18, 18)))
	_restyle()

func set_tooltip(content: Dictionary) -> void:
	_trigger.set_tooltip(content)
	_trigger.set_placement(TdTooltipPlacement.Side.ABOVE_CENTRED, get_parent() as Control)

## The refused click: a shake (±7 px) and the reason above the piece.
func deny(reason: String) -> void:
	_shake_t = 0.0
	if reason != "":
		TdTooltip.show_beside(self, TdTooltipPlacement.Side.ABOVE_CENTRED, get_parent() as Control,
			TooltipText.colored(TooltipText.harmful_color(), reason))
		TdTooltip.own(self)
		_deny_left = 1.6

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Rect2(Vector2.ZERO, size).has_point(event.position): pressed.emit(self)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()

func _restyle() -> void:
	if _plate == null: return
	_render.visible = not _placed
	_shadow.visible = not _placed
	_plinth.visible = _placed
	_medal.visible = _placed
	_cost.visible = not _placed
	_hp.visible = _placed
	_hp.set_label_visible(_placed and hovered)
	_glow.visible = _picked
	_arrow.visible = _selected and show_arrow
	_render.modulate = Color(0.6, 0.6, 0.6, 0.4) if _poor else Color.WHITE
	# the plate: Selected (cobalt) > Picked > Placed > poor > hover/normal
	var extra := ""
	if _selected: extra = "Selected"
	elif _placed: extra = "PlacedHover" if hovered else "Placed"
	elif _picked: extra = "Picked"
	_plate.set_extra_state(extra)
	_plate.set_interactable(not _poor)
	_plate.force_state(hovered and not _poor, false)
	var plate_y := SLOT.y - 28 - (26.0 if _placed else 10.0)
	_plate.position = Vector2((SLOT.x - 108) / 2.0, plate_y)
	_hp.position.y = SLOT.y - 14

func _process(delta: float) -> void:
	if _plate == null: return
	var dt := TdTheme.unscaled(delta)
	_clock += dt
	if _deny_left > 0.0:
		_deny_left -= dt
		if _deny_left <= 0.0: TdTooltip.hide(self)
	var lift := 0.0
	var sc := 1.0
	if _placed:
		lift = 8.0 if _selected else 0.0
		sc = 1.06 if hovered else 1.0
	elif _picked:
		lift = 30.0; sc = 1.1
	elif hovered and not _poor:
		lift = 16.0; sc = 1.06
	var k := clampf(dt / TdTheme.motion("quick") * 2.5, 0.0, 1.0)
	_lift = lerpf(_lift, lift, k)
	_scale = lerpf(_scale, sc, k)
	var shake := 0.0
	if _shake_t < 1.0:
		_shake_t = minf(1.0, _shake_t + dt / 0.32)
		shake = sin(_shake_t * TAU * 4.0) * 7.0 * (1.0 - _shake_t)
	_render.position = Vector2((SLOT.x - 112) / 2.0 + shake, SLOT.y - 112 - 34 - _lift)
	_render.scale = Vector2.ONE * _scale
	var lifted := clampf(_lift / 30.0, 0.0, 1.0)
	_shadow.scale = Vector2.ONE * lerpf(1.0, 0.6, lifted)
	_shadow.modulate.a = lerpf(1.0, 0.4, lifted)
	_medal.position = Vector2((SLOT.x - 64) / 2.0 + shake, 26 - _lift)
	_medal.scale = Vector2.ONE * _scale
	_glow.position.y = -4 - _lift
	if _poor: _plate.position.x = (SLOT.x - 108) / 2.0 + shake
