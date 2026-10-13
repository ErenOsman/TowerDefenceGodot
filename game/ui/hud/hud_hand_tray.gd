class_name HudHandTray
extends PanelContainer
## The hand tray (hud-menu-spec §6.4; UI Design Rules, bottom row): flat wood at the bottom-left, one HudHandPiece per
## tower of the hand in a straight row. A piece's click places (toggle_placing), selects its placed tower
## (select_and_show) or, without the energy, shakes and says what is missing; hovering a placed piece lights its tower's
## ring on the board (preview_tower). Ctrl+N (the Hand modifier) is the controller's.

var controller: LevelController
var _row: HBoxContainer
var _pieces: Array = []

func _init() -> void:
	name = "HandTray"
	mouse_filter = MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", TdTheme.stylebox("hand_tray", Color.WHITE, [22, 6, 22, 2]))
	_row = HudArt.hbox(int(HudLayout.PIECE_GAP))
	_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_row)

func piece_count() -> int:
	return _pieces.size()

func refresh() -> void:
	var c := controller
	if c == null or c.session == null: return
	var s := c.session
	var f: ViewFrame = c.shown
	var hand: Array = c.hand_towers # co-op: only yours
	while _pieces.size() < hand.size():
		var p := HudHandPiece.new()
		_row.add_child(p)
		p.pressed.connect(_on_pressed)
		p.hover_changed.connect(_on_hover)
		_pieces.append(p)
	while _pieces.size() > hand.size():
		_pieces.pop_back().queue_free()
	var keys = get_tree().root.get_node_or_null("KeyBinds")
	var energy: int = c.shown_energy
	for i in hand.size():
		var t: TowerDef = hand[i]
		var frame := _placed_frame(f, t.id)
		var cds := []
		if frame != null:
			var e: Entity = s.state.get_entity(frame.id)
			if e != null:
				for a in e.abilities:
					var left: int = frame.cooldowns.get(a, 0)
					cds.append([0 if left == Entity.HeldCooldown else left, left == Entity.HeldCooldown])
		var key := ""
		if keys != null and i < 9: key = keys.first(HudText.ability_key(i))
		var affordable := energy >= t.cost
		var piece: HudHandPiece = _pieces[i]
		piece.show_state(t.id, i, t.name, t.cost, key, HudArt.miniature(c.converter, t.entity), HudArt.portrait(c.converter, t.entity),
			frame, cds, c.placing == t.id, affordable, frame != null and c.selected == frame.id)
		piece.set_tooltip(_tooltip(t, i, frame, affordable, keys))
	custom_minimum_size = Vector2(HudLayout.tray_width(hand.size()), HudLayout.TRAY_H)

## The tower's frame on the board as shown now (alive and on a tile), or null while it is in the hand.
func _placed_frame(f: ViewFrame, tower_id: String) -> EntityFrame:
	if f == null or controller == null or controller.session == null: return null
	var e: Entity = controller.session.placed_tower(tower_id)
	var fr: EntityFrame = f.get_frame(e.id) if e != null else null
	if fr == null:
		for x in f.entities.values():
			if x.tower_id == tower_id: fr = x
	return fr if fr != null and fr.life == LifeState.Alive and fr.position != null else null

## The piece's tooltip (ability-rows style): "Tower · key Ctrl+1" (the same key text as the tray badge), the
## description, one tag line of stats (icon + bold number + name), footer = cost (red when short) or the refund.
func _tooltip(t: TowerDef, i: int, frame: EntityFrame, affordable: bool, keys) -> Dictionary:
	var c := controller
	var vocab = c.session.state.vocab
	# one tag line: HP, then the main attack's result tags (Damage, Range…), as many as fit one line
	var tags := []
	if t.entity != null:
		var stats := DefStats.new(t.entity)
		tags.append(["MaxHp", "%d/%d" % [frame.hp, frame.max_hp] if frame != null else HudText.num(stats.stat("MaxHp")), "HP"])
		var main: AbilityDef = null
		for a in t.entity.abilities:
			if main == null and not a.targeting.is_movement: main = a
		if main != null:
			for r in AbilityText.tags(main, stats, vocab):
				if tags.size() < 3: tags.append([str(r[1]), str(r[0]), str(r[1])])
	var key: String = HudText.piece_key(keys.first(HudText.ability_key(i)), keys.modifier_name(keys.get_modifier("Hand"))) if keys != null and i < 9 else ""
	var desc: String = t.type.description if t.type != null else ""
	var sub := "Tower · key " + key if key != "" else "Tower"
	if frame != null: sub = "Tower · on the board"
	var body := TooltipText.describe(TooltipText.from_rich(desc))
	var line := "[font_size=20]%s[/font_size]" % HudArt.tag_line(tags, 18) if not tags.is_empty() else ""
	if line != "": body += ("\n" if body != "" else "") + line
	var header := TooltipText.title(t.name, TooltipText.tower_color(), sub)
	if frame != null:
		return TooltipText.content(header, body, "Click to select it", "Sell +%d" % c.session.sell_value(t.id))
	var cost := "%d energy" % t.cost
	var energy: int = c.shown_energy
	if not affordable:
		return TooltipText.content(header, body, cost, TooltipText.colored(TooltipText.harmful_color(), HudText.shortfall(t.cost, energy)))
	return TooltipText.content(header, body, "Click, then a lit tile", TooltipText.colored(TooltipText.value_color(), cost))

func _on_pressed(p: HudHandPiece) -> void:
	var c := controller
	if c == null or c.session == null: return
	var t: TowerDef = c.session.tower(p.tower_id)
	if t == null: return
	var frame := _placed_frame(c.shown, t.id)
	if frame != null:
		c.select_and_show(frame.id)
		return
	if c.is_coop and not c.is_my_turn and c.placing != t.id:
		p.deny("")
		c.refuse(c.wait_reason if c.wait_reason != "" else "Not your turn")
		return
	var energy: int = c.shown_energy
	if energy < t.cost and c.placing != t.id:
		p.deny("")
		c.refuse(HudText.cost_missing_hint(t.name, t.cost, energy))
		return
	c.toggle_placing(t.id)

func _on_hover(p: HudHandPiece, on: bool) -> void:
	var c := controller
	if c == null or c.shown == null: return
	var frame := _placed_frame(c.shown, p.tower_id)
	if on and frame != null: c.preview_tower(frame.id)
	elif not on: c.preview_tower(-1)

## The first piece whose tower is still in the hand (not on the board), or null.
func first_in_hand() -> HudHandPiece:
	if controller == null or controller.session == null: return null
	for p in _pieces:
		if _placed_frame(controller.shown, p.tower_id) == null: return p
	return null
