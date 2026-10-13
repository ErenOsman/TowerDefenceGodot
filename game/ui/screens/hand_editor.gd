extends TdPopup
## The hand editor popup (UI_HandEditor.cs; mockup hand-editor.html): the hand in order (click a tower to take it
## out) and the other owned towers (click one to add it at the end). Order matters: a level takes the first towers
## up to its hand cap (shown when opened from a level). Every edit saves and emits `changed`; cards pop in.
## From level select (with its level) and the Camp's Towers station (no level).

signal changed

## The level the hand is for (null: none, e.g. the Camp).
var level: LevelAsset = null

var _hand_row: HFlowContainer
var _owned_row: HFlowContainer
var _count: Label
var _info: Label
var _owned_title: Label
var _empty: Label
var _cap_note: Label

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var p := TdMenu.panel(TdPanel.Kind.WINDOW, 28)
	p.custom_minimum_size = Vector2(1460, 0)
	center.add_child(p)
	window = p
	var col := TdMenu.vbox(18)
	p.add_child(col)
	var head := TdMenu.hbox(16)
	col.add_child(head)
	head.add_child(TdMenu.label("Change hand", "h1", TdTheme.color("cream.100")))
	_count = TdMenu.label("", "body", TdTheme.color("cream.300"), 24)
	_count.size_flags_vertical = SIZE_SHRINK_CENTER
	_count.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(_count)
	var x := TdMenu.close_button()
	x.clicked.connect(close)
	head.add_child(x)
	_info = TdMenu.wrap_label("Click a tower in your hand to take it out, a tower below to add it to the end. A level takes towers from the left.", "body", TdTheme.color("cream.200"), 22)
	col.add_child(_info)
	var hand_well := TdMenu.panel(TdPanel.Kind.WELL, 20)
	col.add_child(hand_well)
	var hv := TdMenu.vbox(10)
	hand_well.add_child(hv)
	hv.add_child(TdMenu.label("Your hand", "h2", TdTheme.color("gold"), 30))
	_hand_row = HFlowContainer.new()
	_hand_row.add_theme_constant_override("h_separation", 12)
	_hand_row.add_theme_constant_override("v_separation", 12)
	_hand_row.custom_minimum_size = Vector2(0, 140)
	hv.add_child(_hand_row)
	_cap_note = TdMenu.label("", "small", TdTheme.color("gold"), 20)
	hv.add_child(_cap_note)
	var owned_well := TdMenu.panel(TdPanel.Kind.WELL, 20)
	col.add_child(owned_well)
	var ov := TdMenu.vbox(10)
	owned_well.add_child(ov)
	var oh := TdMenu.hbox(16)
	ov.add_child(oh)
	oh.add_child(TdMenu.label("Your other towers", "h2", TdTheme.color("cream.100"), 30))
	_owned_title = TdMenu.label("", "body", TdTheme.color("cream.300"), 22)
	_owned_title.size_flags_vertical = SIZE_SHRINK_CENTER
	oh.add_child(_owned_title)
	_owned_row = HFlowContainer.new()
	_owned_row.add_theme_constant_override("h_separation", 12)
	_owned_row.add_theme_constant_override("v_separation", 12)
	_owned_row.custom_minimum_size = Vector2(0, 140)
	ov.add_child(_owned_row)
	_empty = TdMenu.label("Every tower you own is in your hand.", "body", TdTheme.color("cream.300"), 22)
	ov.add_child(_empty)
	col.add_child(TdMenu.label("Saved as you change it.", "small", TdTheme.color("cream.300"), 20))

func _on_open() -> void:
	refresh(true)

func refresh(pop := false) -> void:
	var towers := SaveData.towers
	var catalog: GameCatalogAsset = GameApp.catalog
	for c in _hand_row.get_children(): c.queue_free()
	for c in _owned_row.get_children(): c.queue_free()
	var made := []
	var cap := level.hand_cap if level != null else TowerCollection.MaxHand
	for i in towers.hand.size():
		var owned := towers.find(towers.hand[i])
		var card := TdHandCard.make(owned, catalog.find_tower(owned.type) if owned != null else null, i)
		card.set_dimmed(i >= cap)
		var id: String = towers.hand[i]
		card.pressed.connect(func(): remove(id))
		TdTooltipTrigger.attach(card, "", "Click: take out")
		_hand_row.add_child(card)
		made.append(card)
	var others := 0
	for owned in towers.towers:
		if towers.hand.has(owned.id): continue
		var card := TdHandCard.make(owned, catalog.find_tower(owned.type))
		var id: String = owned.id
		card.pressed.connect(func(): add(id))
		_owned_row.add_child(card)
		made.append(card)
		others += 1
	_count.text = "%d / %d towers" % [towers.hand.size(), TowerCollection.MaxHand]
	_cap_note.text = "In %s: the first %d" % [level.get_display_name(), cap] if level != null else ""
	_cap_note.visible = level != null
	_owned_title.text = "Click one to add it at the end (slot %d)" % (towers.hand.size() + 1) if towers.hand.size() < TowerCollection.MaxHand else "The hand is full (%d)" % TowerCollection.MaxHand
	_empty.visible = others == 0
	_owned_row.visible = others > 0
	if pop: TdMenu.pop_in(made, 0.03)

## Takes a tower out of the hand.
func remove(id: String) -> void:
	SaveData.towers.remove_from_hand(id)
	_changed()

## Adds an owned tower at the end of the hand (when there is room).
func add(id: String) -> void:
	if not SaveData.towers.can_add_to_hand(id): return
	SaveData.towers.add_to_hand(id)
	_changed()

func _changed() -> void:
	SaveData.save()
	refresh(false)
	changed.emit()
