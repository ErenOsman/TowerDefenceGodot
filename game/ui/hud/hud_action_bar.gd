class_name HudActionBar
extends PanelContainer
## The action bar (hud-menu-spec §6.3; UI_ActionBar): for the selected unit you command, or the hand tower being placed:
## who (name + "N ready" / its cost), a divider, one ability button per ability (TdButton ABILITY: clock ring, turns-left
## badge or lock, key, Aiming / Cooldown / Held looks) and the passives as passive chips (dimmed while off). Hover
## previews the range on the board and opens the ability tooltip above the bar; click or the key aims (the
## controller's toggle_aim), Shift-click (the QuickCast modifier) quick casts; a button that can't be cast shakes and
## the hint line says why. A held ability key shows its button pressed. A hand tower's buttons show, never cast.

var controller: LevelController

var _who: Label
var _ready: Label
var _divider: ColorRect
var _row: HBoxContainer
var _buttons: Array = []     # TdButton per ability
var _abilities: Array = []   # AbilityDef per button
var _reasons: Array = []     # String per button ("" castable)
var _passives: Array = []    # TdIconChip per passive
var _owner_key := ""
var _caster: Entity = null
var casting := false
var buttons_shown := 0

func _init() -> void:
	name = "ActionBar"
	mouse_filter = MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", TdTheme.stylebox("panel_wood", Color.WHITE, [16, 14, 16, 14]))
	var h := HudArt.hbox(26)
	add_child(h)
	var who := HudArt.vbox(0)
	who.custom_minimum_size = Vector2(110, 0)
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(who)
	_who = HudArt.label("", "micro", TdTheme.color("accent.light"), 26)
	who.add_child(_who)
	_ready = HudArt.label("", "small", TdTheme.color("cream.300"))
	who.add_child(_ready)
	_divider = ColorRect.new()
	_divider.color = TdTheme.color("wood.500")
	_divider.custom_minimum_size = Vector2(2, 56)
	_divider.size_flags_vertical = SIZE_SHRINK_CENTER
	_divider.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_child(_divider)
	_row = HudArt.hbox(26)
	h.add_child(_row)

## The unit whose abilities show (a commanded selection), or null.
func caster_of(c: LevelController) -> Entity:
	if c == null or c.session == null: return null
	var e: Entity = c.session.state.get_entity(c.selected)
	return e if e != null and c.session.is_commanded(e) and e.alive else null

## Whether the bar has something to show now.
func wanted(c: LevelController) -> bool:
	return caster_of(c) != null or (c != null and c.placing != null)

func refresh() -> void:
	var c := controller
	_caster = caster_of(c)
	var hand: TowerDef = c.session.tower(c.placing) if _caster == null and c.placing != null else null
	if _caster == null and hand == null: return
	casting = _caster != null
	var f: EntityFrame = c.shown.get_frame(_caster.id) if _caster != null and c.shown != null else null
	var list: Array = _caster.abilities if _caster != null else (hand.entity.abilities if hand.entity != null else [])
	var passives: Array = f.passives if f != null else PassiveView.of(hand.entity if hand != null else null)
	_who.text = _caster.def.display_name if _caster != null else hand.name
	var key := ("e%d" % _caster.id) if _caster != null else ("t" + hand.id)
	if key != _owner_key or list.size() != _buttons.size() or passives.size() != _passives.size():
		_owner_key = key
		_rebuild(list, passives)
	var self_entity = _caster if _caster != null else (DefStats.new(hand.entity) if hand.entity != null else null)
	var busy: bool = c.director != null and c.director.busy
	var keys = get_tree().root.get_node_or_null("KeyBinds")
	var castable_flags := []
	_reasons.clear()
	var keep_reason := c.session.last_reason
	for i in list.size():
		var a: AbilityDef = list[i]
		var b: TdButton = _buttons[i]
		var left: int = f.cooldowns.get(a, 0) if f != null else 0
		var held := left == Entity.HeldCooldown
		if held: left = 0
		var castable: bool = _caster != null and not busy and c.session.can_cast(_caster, a)
		var reason: String = c.session.last_reason if _caster != null and not castable else ""
		castable_flags.append(castable)
		_reasons.append(HudText.ability_refusal(a.display_name, castable or _caster == null, left, held, reason))
		var key_text := ""
		if _caster != null and i < 9 and keys != null: key_text = keys.first(HudText.ability_key(i))
		b.set_ability_state(left, maxi(1, a.cooldown), held, c.aiming == a, key_text)
		b.set_interactable(castable or _caster == null)
		b.denied_reason = ""
		var note := ""
		if _caster != null:
			var combo: String = keys.combo("Aim", HudText.ability_key(i)) if keys != null and i < 9 else ""
			note = TooltipText.note(HudText.key_note(combo, keys.click_text("QuickCast") if keys != null else "Shift-click"))
		var content := TooltipText.ability(a.display_name, a.description, " · ".join(a.tags),
			AbilityText.tags(a, self_entity, c.session.state.vocab) if self_entity != null else [],
			a.cooldown, a.cooldown_until_reset, Entity.HeldCooldown if held else left, [note], a.start_cooldown)
		var trig := TdTooltipTrigger.find_on(b)
		trig.set_tooltip(content)
		trig.set_placement(TdTooltipPlacement.Side.ABOVE_CENTRED, self)
	c.session.last_reason = keep_reason
	for i in passives.size():
		var pv: PassiveView = passives[i]
		var chip: TdIconChip = _passives[i]
		chip.modulate.a = 1.0 if pv.active else 0.45
		var desc: String = pv.def.description if pv.def != null else ""
		var trig := TdTooltipTrigger.find_on(chip)
		trig.set_tooltip(TooltipText.passive(pv.name, desc, pv.active))
		trig.set_placement(TdTooltipPlacement.Side.ABOVE_CENTRED, self)
	_ready.text = HudText.ready_line(HudText.ready_count(castable_flags), -1 if _caster != null else hand.cost)
	buttons_shown = list.size() + passives.size()
	_divider.visible = buttons_shown > 0

func _rebuild(list: Array, passives: Array) -> void:
	for b in _buttons: b.queue_free()
	for p in _passives: p.queue_free()
	_buttons.clear()
	_passives.clear()
	_abilities = list.duplicate()
	for i in list.size():
		var a: AbilityDef = list[i]
		var b := TdButton.new()
		b.style = TdButton.Style.ABILITY
		b.custom_minimum_size = Vector2(84, 84)
		b.size = Vector2(84, 84)
		b.size_flags_vertical = SIZE_SHRINK_CENTER
		b.icon = HudArt.ability_face(controller.converter, a)
		_row.add_child(b)
		TdTooltipTrigger.attach(b)
		b.clicked.connect(_on_click.bind(i))
		b.denied.connect(_on_denied.bind(i))
		b.hover_changed.connect(_on_hover.bind(i))
		_buttons.append(b)
	for pv in passives:
		var chip := TdIconChip.new()
		chip.shape = TdIconChip.ChipShape.PASSIVE
		chip.chip_size = 64
		chip.size_flags_vertical = SIZE_SHRINK_CENTER
		chip.custom_minimum_size = Vector2(64, 64)
		_row.add_child(chip)
		chip.set_icon(HudArt.passive_icon(controller.converter, pv.def))
		TdTooltipTrigger.attach(chip)
		var aura = pv.def.aura if pv.def != null else null
		chip.mouse_entered.connect(func():
			if _caster != null and aura != null and not aura.is_empty: controller.preview_aura(_caster, aura))
		chip.mouse_exited.connect(func(): controller.preview_aura(null, null))
		_passives.append(chip)

func _on_click(i: int) -> void:
	if _caster == null or i >= _abilities.size(): return
	if controller.quick_cast_held: controller.quick_cast(_abilities[i])
	else: controller.toggle_aim(_abilities[i])

func _on_denied(i: int) -> void:
	if i < _reasons.size() and _reasons[i] != "": controller.refuse(_reasons[i])

func _on_hover(on: bool, i: int) -> void:
	if on and i < _abilities.size(): controller.preview_ability(_caster, _abilities[i])
	else: controller.preview_ability(null, null)

## Keys answer like the mouse: a held ability key shows its button pressed; a key on one that can't be cast shakes it.
func _process(_delta: float) -> void:
	if not visible or not casting or controller == null: return
	var keys = get_tree().root.get_node_or_null("KeyBinds")
	if keys == null: return
	var hand_keys: bool = keys.modifier_held("Hand")
	for i in mini(_buttons.size(), 9):
		var b: TdButton = _buttons[i]
		var id := HudText.ability_key(i)
		b.set_key_held(not hand_keys and keys.held(id) and b.interactable)
		if not hand_keys and keys.pressed(id) and not b.interactable: b.simulate_click()

## The button for ability i (tools and tests), or null.
func button(i: int) -> TdButton:
	return _buttons[i] if i < _buttons.size() else null
