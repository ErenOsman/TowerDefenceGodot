class_name MissionDetail
extends "res://game/ui/screens/level_select.gd"
## A mission's detail (Missions & Guild — Design § The Guild; mockups screens-b/mission-detail.html, -done, -coop,
## -tired, -all-tired): the level select's screen reused for a mission, full screen over the Guild's backdrop.
## - Top: "← Missions [Esc]" and the mission's name.
## - Left: the missions (board order) with their thumbnail and a line ("1 left today", "Done today", "Co-op · find a
##   room", "2 left today", the lock reason); the selected row is cobalt.
## - Centre: the mode chip and "plays Two Roads", the title, the description, the level's four fact tiles (co-op
##   only: "3 towers each"), the enemies (the level select's rule: chips once the level or the mission was played).
## - Right: the board picture, "Drops" (Each win / First win, first-win coins gold-rimmed, "✓ claimed"), the pips
##   "● 1 of 1 play left today", the note over the button ("ⓘ Starting uses a play, win or lose.", "Co-op only (2–6
##   players). Starting the match uses your play.", "✓ Done today: …", "⚠ All your towers are tired: …") and the
##   primary Play (GameApp.play_mission) or Find a room (find_room: the lobby with the mission picked).
## - Bottom: "Your hand" with the mission's note, the 8 slots with tired towers at 50 % (moon badge, "Tired · rests
##   in 5 h") and "▲ goes" under the towers it takes, the divider after the last of them; Change hand opens the hand
##   editor for the mission. Texts and states: MissionUiLogic.

signal find_room(mission_id: String)

## The board picture's height (the level select's is 300).
const MAP_H := 160.0

var mission_id := ""
var missions: Array = []
var _back_title: Label
var _drops_box: VBoxContainer
var _pips: HBoxContainer
var _note_row: HBoxContainer
var _change_wood: Control
var _change_primary: TdButton
var _state := ""
var _lock_reason := ""

func _init() -> void:
	super._init()
	in_camp = true

func _build() -> void:
	var bd := TdGuildBackdrop.new()
	add_child(bd)
	_frame = Control.new()
	_frame.mouse_filter = MOUSE_FILTER_IGNORE
	_frame.size = FRAME
	_frame.set_anchors_preset(PRESET_CENTER)
	_frame.offset_left = -FRAME.x / 2.0; _frame.offset_right = FRAME.x / 2.0
	_frame.offset_top = -FRAME.y / 2.0; _frame.offset_bottom = FRAME.y / 2.0
	add_child(_frame)
	var back_b := _key_button("Missions", "icon_back", "", Vector2(232, 52))
	back_b.position = Vector2(64, 34)
	back_b.pressed.connect(back)
	_frame.add_child(back_b)
	_back_title = TdMenu.label("", "h1", TdTheme.color("cream.100"), 52)
	_back_title.add_theme_color_override("font_shadow_color", TdTheme.color("rim"))
	_back_title.add_theme_constant_override("shadow_offset_y", 3)
	_back_title.position = Vector2(322, 24)
	_frame.add_child(_back_title)
	_build_list()
	_build_detail()
	_build_hand()
	_reshape_right_column()
	# Change hand as the cobalt primary while Play is off for the hand's sake (one primary per screen)
	var side := _slots_used.get_parent()
	_change_wood = side.get_child(0)
	_change_primary = TdMenu.button(TdButton.Style.PRIMARY, "Change hand", Vector2(300, 60), TdTheme.texture("icon_cards"))
	_change_primary.font_size = 26
	# no bleed room: it would widen the column by ~28 px and the button and "N of 8 slots used" jumped left when it
	# replaced the wood one (QA 2026-10-15; nothing clips there, the hover growth still shows)
	_change_primary.bleed_mode = TdButton.Bleed.OFF
	_change_primary.clicked.connect(open_hand_editor)
	_change_primary.visible = false
	side.add_child(_change_primary)
	side.move_child(_change_primary, 0)
	_popups = Control.new()
	_popups.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_popups.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_popups)

## The level select's reward card becomes the "Drops" box; the pips and the note line go between it and Play.
func _reshape_right_column() -> void:
	# a lower board picture: the drops, the pips and the note fit above Play
	_map_col.add_theme_constant_override("separation", 10)
	var map_frame: Control = _map_col.get_child(0)
	map_frame.custom_minimum_size = Vector2(MAP_SIZE.x, MAP_H)
	_preview.custom_minimum_size = Vector2(MAP_SIZE.x, MAP_H)
	# its board picture took the level select's 300 px height in _ready: rendered 300 high and cut to 160 (QA 2026-10-14)
	if _preview._pic != null: _preview._pic.custom_minimum_size = Vector2(MAP_SIZE.x, MAP_H)
	for c in _reward.get_children():
		_reward.remove_child(c)
		c.queue_free()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.09, 0.067, 0.051, 0.55)
	rsb.set_corner_radius_all(14)
	rsb.content_margin_left = 16; rsb.content_margin_right = 16
	rsb.content_margin_top = 10; rsb.content_margin_bottom = 12
	_reward.add_theme_stylebox_override("panel", rsb)
	var v := TdMenu.vbox(8)
	v.mouse_filter = MOUSE_FILTER_IGNORE
	_reward.add_child(v)
	v.add_child(TdMenu.label("Drops", "h3", TdTheme.color("cream.100"), 22))
	_drops_box = TdMenu.vbox(0)
	_drops_box.mouse_filter = MOUSE_FILTER_PASS
	v.add_child(_drops_box)
	_pips = TdMenu.hbox(8)
	_pips.mouse_filter = MOUSE_FILTER_IGNORE
	_map_col.add_child(_pips)
	_map_col.move_child(_pips, _reward.get_index() + 1)
	_note_row = TdMenu.hbox(8)
	_note_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_note_row.mouse_filter = MOUSE_FILTER_IGNORE
	_map_col.add_child(_note_row)
	_map_col.move_child(_note_row, _play.get_parent().get_index())

# ------------------------------------------------------------------ open / select

func _on_open() -> void:
	_asset = GameApp.catalog
	if _asset == null:
		_title.text = "No game catalog"
		return
	_catalog = _asset.to_catalog()
	if _asset.grant_starting_towers(SaveData.towers): SaveData.save()
	missions = GameApp.missions()
	if mission_id == "" and not missions.is_empty(): mission_id = missions[0].id
	refresh(true)

## Shows another mission.
func select_mission(id: String) -> void:
	mission_id = id
	refresh(false)

func mission() -> MissionDef:
	return MissionBoard.find(missions, mission_id)

func _cap(m: MissionDef, level: LevelAsset) -> int:
	if m == null: return 0
	if not m.is_solo: return m.coop_hand_cap
	return clampi(level.hand_cap if level != null else 0, 0, TowerCollection.MaxHand)

func _state_of(m: MissionDef) -> String:
	var unlocked := MissionBoard.is_unlocked(m, SaveData.progress, SaveData.missions, _asset)
	_lock_reason = MissionBoard.last_reason if not unlocked else ""
	return MissionUiLogic.state_of(m, unlocked, SaveData.missions)

func refresh(pop := false) -> void:
	if _asset == null: return
	var m := mission()
	var level := GameApp.mission_level(m)
	selected = level.get_id() if level != null else ""
	_state = _state_of(m)
	_back_title.text = m.name if m != null else ""
	_draw_list(pop)
	_draw_mission(m, level)
	_draw_hand(level, pop)
	_draw_action(m, level)

# ------------------------------------------------------------------ list

func _draw_list(pop: bool) -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	var head := TdMenu.hbox(8)
	head.mouse_filter = MOUSE_FILTER_IGNORE
	var hl := TdMenu.label("Missions", "h3", TdTheme.color("cream.200"), 26)
	hl.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(TdMenu.spacer(0, 4))
	head.add_child(hl)
	var n := TdMenu.label(str(missions.size()), "plate", TdTheme.color("cream.300"), 18)
	n.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(n)
	head.add_child(TdMenu.spacer(0, 4))
	_list.add_child(head)
	for m in missions:
		var b := _mission_row(m)
		_list.add_child(b)
		_rows.append(b)
	if pop: TdMenu.pop_in(_rows)

func _mission_row(m: MissionDef) -> TdButton:
	var st := _state_of(m)
	var line := MissionUiLogic.list_line(m, st, _lock_reason, SaveData.missions)
	var b := TdButton.new()
	b.style = TdButton.Style.ROW
	b.custom_minimum_size = Vector2(ROW_SIZE.x, 66)
	b.size = b.custom_minimum_size
	b.text = ""
	b.selectable = true
	b.selected = m.id == mission_id
	var sel := b.selected
	var face := b.face_node()
	var thumb := CoopUi.thumb_rect(m.level_id, Vector2(78, 52))
	thumb.position = Vector2(8, 7)
	if st == MissionUiLogic.Locked: (thumb.get_child(0) as CoopBoardPic).grey = true
	thumb.mouse_filter = MOUSE_FILTER_IGNORE
	face.add_child(thumb)
	var col := TdMenu.vbox(-4)
	col.position = Vector2(98, 0)
	col.size = Vector2(ROW_SIZE.x - 110, 66)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = MOUSE_FILTER_IGNORE
	face.add_child(col)
	var nm := TdMenu.label(m.name, "plate", Color.WHITE if sel else TdTheme.color("cream.100"), 24)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	var ll := TdMenu.label(line, "small", Color(1, 1, 1, 0.85) if sel else TdTheme.color("cream.300"), 18)
	ll.clip_text = true
	ll.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(ll)
	if st == MissionUiLogic.Locked and not sel: b.modulate.a = 0.7
	var id := m.id
	b.clicked.connect(func(): select_mission(id))
	return b

# ------------------------------------------------------------------ detail

func _draw_mission(m: MissionDef, level: LevelAsset) -> void:
	for c in _kicker.get_children(): c.queue_free()
	for c in _facts.get_children(): c.queue_free()
	for c in _enemies.get_children(): c.queue_free()
	for c in _drops_box.get_children(): c.queue_free()
	_chips.clear()
	if m == null or level == null:
		_title.text = "No mission"
		_desc.text = "This mission's level is missing from the catalog." if m != null else "No missions yet."
		_enemies_head.visible = false
		_enemies_note.visible = false
		_reward.visible = false
		_preview.show_level(null)
		return
	var dim := 0.6 if _state == MissionUiLogic.Locked else 1.0
	_kicker.add_child(TdDrops.mode_chip(m, 20))
	var pl := TdMenu.label(MissionUiLogic.plays_level(level.get_display_name()), "plate", TdTheme.color("cream.300"), 20)
	pl.size_flags_vertical = SIZE_SHRINK_CENTER
	_kicker.add_child(pl)
	_title.text = m.name
	_title.modulate.a = dim
	_desc.text = TooltipText.from_rich(m.description if m.description != "" else level.description)
	_desc.modulate.a = dim
	var f := MenuLogic.level_facts(level)
	var played := MenuLogic.has_played(SaveData.progress, level.get_id()) or _mission_played(m)
	var coop := not m.is_solo
	var hand_n: int = m.coop_hand_cap if coop else int(f.hand)
	var tiles := [
		_fact("icon_wave", str(f.waves), MenuLogic.plural(f.waves, "wave")),
		_fact("icon_enemy", str(f.enemies), MenuLogic.plural(f.enemies, "enemy", "enemies")), # always the kit's enemy glyph (UI review 2026-10-14)
		_fact("icon_cards", str(hand_n), MenuLogic.plural(hand_n, "tower") + (" each" if coop else " in hand")),
		_fact("icon_energy", str(f.energy), "energy", null, "+%d a round" % f.per_round),
	]
	for t in tiles:
		t.modulate.a = dim
		_facts.add_child(t)
	var counts := MenuLogic.enemy_counts(level) if played else []
	_enemies_head.visible = not played or not counts.is_empty()
	_enemies_note.visible = not played
	var compact := counts.size() > 4
	for pair in counts:
		var chip := _enemy_chip(pair[0], pair[1], compact)
		chip.modulate.a = dim
		_enemies.add_child(chip)
		_chips.append(chip)
	_reward.visible = not MissionUiLogic.drop_rows(m).is_empty()
	_drops_box.add_child(TdDrops.rows(m, MissionUiLogic.first_win_claimed(m, SaveData.missions), 38.0, 96.0, 20))
	_preview.show_level(level)
	_preview.modulate = Color(1, 1, 1, 1) if dim >= 1.0 else Color(0.75, 0.75, 0.75, 0.6)
	_preview.set_grey(_state == MissionUiLogic.Locked)

func _mission_played(m: MissionDef) -> bool:
	var r := SaveData.missions.find(m.id)
	return r != null and r.attempts > 0

## The pips, the note and the primary button.
func _draw_action(m: MissionDef, level: LevelAsset) -> void:
	for c in _pips.get_children(): c.queue_free()
	for c in _note_row.get_children(): c.queue_free()
	if m == null:
		_play.set_interactable(false, "No mission")
		return
	var pp := MissionUiLogic.pips(m, SaveData.missions)
	for i in pp[1]:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = SIZE_SHRINK_CENTER
		dot.mouse_filter = MOUSE_FILTER_IGNORE
		dot.add_theme_stylebox_override("panel", _flat(TdTheme.color("gold") if i < pp[0] else Color("#1A130F"), 8, TdTheme.color("rim"), 2))
		_pips.add_child(dot)
	var t := MissionUiLogic.pips_text(m, SaveData.missions)
	var pr := TdMenu.rich("[b]%d[/b] %s" % [pp[0], t.substr(str(pp[0]).length() + 1)], "plate", TdTheme.color("cream.100"), 21)
	pr.autowrap_mode = TextServer.AUTOWRAP_OFF
	pr.size_flags_vertical = SIZE_SHRINK_CENTER
	_pips.add_child(pr)
	var hand: Array = SaveData.towers.hand
	var bring := ""
	if _state == MissionUiLogic.Play and not MissionBoard.can_bring(hand, SaveData.missions, _cap(m, level)): bring = MissionBoard.last_reason
	var note := MissionUiLogic.detail_note(m, _state, _lock_reason, bring)
	var icon_name: String = {"info": "info", "coop": "users", "done": "check", "warn": "", "lock": "lock"}[note.kind]
	var col := TdTheme.color("bad") if note.kind == "warn" else TdTheme.color("cream.200")
	if note.kind == "warn":
		var w := TdMenu.picture(TdMenu.warn_icon(), Vector2(22, 22))
		w.size_flags_vertical = SIZE_SHRINK_CENTER
		_note_row.add_child(w)
	elif icon_name != "":
		_note_row.add_child(TdDrops.icon(icon_name, 20, col))
	# left-aligned at 18 px (never smaller), up to two lines: the icon sits on the first line and the second line
	# wraps under the text, not under the icon (the label is its own column beside the icon)
	for ic in _note_row.get_children(): ic.size_flags_vertical = SIZE_SHRINK_BEGIN
	var nl := TdMenu.wrap_label(note.text, "plate", col, 18)
	nl.custom_minimum_size = Vector2(MAP_SIZE.x - 34.0, 0)
	nl.size_flags_horizontal = SIZE_EXPAND_FILL
	nl.max_lines_visible = 2
	_note_row.add_child(nl)
	_play.text = MissionUiLogic.primary_label(m)
	_play.icon = TdTheme.texture("icon_play") if m.is_solo else TdDrops.icon_texture("users")
	_play.custom_minimum_size = Vector2(300 if m.is_solo else 330, 76)
	_play.left_pad = 86 if m.is_solo else 40
	var ok := MissionUiLogic.primary_enabled(_state, bring)
	_play.set_interactable(ok, note.text)
	var hand_fix: bool = not ok and note.kind == "warn" # all tired / empty hand: Change hand is the way on
	_change_primary.visible = hand_fix
	_change_wood.visible = not hand_fix

# ------------------------------------------------------------------ hand

func _draw_hand(level: LevelAsset, pop: bool) -> void:
	for c in _tray.get_children():
		_tray.remove_child(c)
		c.queue_free()
	_pieces.clear()
	var m := mission()
	var towers := SaveData.towers
	var hand: Array = towers.hand
	var cap := _cap(m, level)
	var marks := MissionUiLogic.hand_marks(hand, SaveData.missions, cap)
	var cut := MissionUiLogic.divider_at(hand, SaveData.missions, cap)
	var any_mark := false
	for i in TowerCollection.MaxHand:
		if i == cut: _tray.add_child(_cut())
		var piece := HandSlot.new()
		var benched := cut >= 0 and i >= cut
		if i < hand.size():
			var owned := towers.find(hand[i])
			var type := _asset.find_tower(owned.type) if owned != null else null
			piece.setup(owned, type, i, benched and not marks[i].tired)
			var tired_text := MissionUiLogic.tired_line() if marks[i].tired else ""
			piece.mark(tired_text, marks[i].goes and MissionUiLogic.any_tired(hand, SaveData.missions))
			any_mark = any_mark or marks[i].tired
		else:
			piece.setup(null, null, i, benched)
		piece.pressed.connect(open_hand_editor)
		_tray.add_child(piece)
		_pieces.append(piece)
	# room for the lines under the slots
	var box := _tray.get_parent() as PanelContainer
	if box != null:
		var sb: StyleBoxFlat = box.get_theme_stylebox("panel").duplicate()
		sb.content_margin_bottom = 58 if any_mark else 8 # two caption lines + ~8 px above the edge
		box.add_theme_stylebox_override("panel", sb)
	var lvname := level.get_display_name() if level != null else ""
	_note.text = MissionUiLogic.hand_note(m, lvname, hand.size(), cap, MissionUiLogic.any_tired(hand.slice(0, maxi(cut, cap)), SaveData.missions))
	_slots_used.text = MenuLogic.slots_used_text(hand.size())
	if pop: TdMenu.pop_in(_pieces, 0.03)

## Change hand: the hand editor for this mission (its cap, the "▲ goes" marks).
func open_hand_editor() -> TdPopup:
	var he: TdPopup = load(HAND_EDITOR).instantiate()
	he.free_on_close = true
	var m := mission()
	var lv := GameApp.mission_level(m)
	he.set("level", lv)
	he.set("mission", m)
	if m != null and not m.is_solo: he.set("hand_cap", m.coop_hand_cap)
	_popups.add_child(he)
	if he.has_signal("changed"): he.connect("changed", func(): refresh(false))
	he.closed.connect(func(): if is_instance_valid(self): refresh(false))
	he.open()
	return he

## Play (Solo / Any) or Find a room (co-op).
func play() -> void:
	var m := mission()
	if m == null: return
	if _state == MissionUiLogic.Room:
		find_room.emit(m.id)
		return
	SaveData.save()
	GameApp.play_mission(m.id)

func back() -> void:
	SaveData.save()
	close()
