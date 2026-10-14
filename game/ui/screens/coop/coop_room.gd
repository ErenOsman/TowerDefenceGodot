class_name CoopRoom
extends TdPopup
## The room (mockups lobby-room-2/4/6, -room-4-guest, -room-changed): the header (lock, room name, "level · co-op ·
## n of count players", room code + Copy), a banner when the level or the player count changed, one slot per player
## count (number, medallion, name in the player's colour, Host crown, You; their hand; Ready / Not ready; yours has
## Change hand; the host has × to remove others), the level card (+ Change level for the host → room settings), the
## chat, and the bottom row: Leave room, what we wait for, Ready, Start (host; all present players Ready).
## When the relay starts the match, Net emits match_ready; the in-match code opens the level.
## Missions & Guild (mockup lobby-room-tired): your row's strip shows your saved hand's first towers up to the cap
## with tired ones dimmed (moon badge) and "1 tired: the next rested tower goes" (CoopLevels.tired_note); Ready is
## refused while no rested tower would come (CoopLevels.can_ready: "All your towers are tired: …"). A switch to a
## mission you used up today is the lobby's business (it leaves the room and says why).

const HAND_EDITOR := "res://game/ui/screens/hand_editor.tscn"
const BANNER_SECONDS := 8.0
## The chat panel's height (about nine lines plus the field).
const CHAT_H := 350.0
## The level picture's height: a mission room's is shorter (its drop row sits under it; the chat keeps its size).
const MAP_H := 116.0
const MISSION_MAP_H := 72.0

var net: Node = null
## Lines of the chat: [{name, text, color, system}].
var chat_log: Array = []

var _title: Label
var _lock: TextureRect
var _sub: Label
var _code: RichTextLabel
var _banner: PanelContainer
var _banner_text: Label
var _banner_left := 0.0
var _slots: VBoxContainer
var _card: Dictionary
var _change_level: Control
var _mission_box: VBoxContainer
var _chat_box: VBoxContainer
var _chat_scroll: ScrollContainer
var _chat_in: LineEdit
var _wait: Label
var _ready_btn: TdButton
var _start: TdButton
var _ready_ring: PanelContainer
var _start_reason := ""
var _popups: Control

func _init() -> void:
	super._init()
	use_scrim = false
	close_on_scrim = false
	right_click_closes = false

func _build() -> void:
	# plain wood planks while waiting in the room: the blurred level picture confused players (Eren 2026-10-14)
	TdMenu.wood_background(self)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: root.add_theme_constant_override("margin_" + side, 32)
	root.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(root)
	window = root
	var col := TdMenu.vbox(18)
	root.add_child(col)
	# header
	var head := TdMenu.panel(TdPanel.Kind.WOOD, 20)
	col.add_child(head)
	var hh := TdMenu.hbox(16)
	head.add_child(hh)
	_lock = TdMenu.picture(TdTheme.texture("icon_lock"), Vector2(34, 34))
	_lock.modulate = TdTheme.color("cream.100")
	_lock.size_flags_vertical = SIZE_SHRINK_CENTER
	hh.add_child(_lock)
	var tv := TdMenu.vbox(0)
	tv.size_flags_horizontal = SIZE_EXPAND_FILL
	hh.add_child(tv)
	_title = TdMenu.label("", "display", TdTheme.color("cream.100"), 46)
	tv.add_child(_title)
	_sub = TdMenu.label("", "body", TdTheme.color("cream.200"), 22)
	tv.add_child(_sub)
	_code = TdMenu.rich("", "body", TdTheme.color("cream.200"), 22)
	_code.autowrap_mode = TextServer.AUTOWRAP_OFF
	_code.size_flags_horizontal = SIZE_SHRINK_END
	_code.size_flags_vertical = SIZE_SHRINK_CENTER
	hh.add_child(_code)
	var copy := TdMenu.wood_button("Copy", Vector2(150, 56))
	copy.icon = TdTheme.texture("icon_cards")
	copy.add_theme_constant_override("icon_max_width", 26)
	copy.size_flags_vertical = SIZE_SHRINK_CENTER
	copy.tooltip_text = "Copy the room name and password to send to a friend."
	copy.pressed.connect(func(): DisplayServer.clipboard_set(invite_text()))
	hh.add_child(copy)
	# body
	var body := TdMenu.hbox(24)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(body)
	var left := TdMenu.vbox(12)
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(left)
	_banner = CoopUi.flat_panel(Color(0.16, 0.12, 0.08, 0.95), 10, CoopUi.GOLD, Vector4(18, 8, 18, 8))
	_banner.visible = false
	left.add_child(_banner)
	var bh := TdMenu.hbox(10)
	_banner.add_child(bh)
	var info_icon := TdMenu.picture(TdTheme.texture("icon_info"), Vector2(24, 24))
	info_icon.modulate = CoopUi.GOLD
	bh.add_child(info_icon)
	_banner_text = TdMenu.label("", "body", TdTheme.color("cream.100"), 22)
	bh.add_child(_banner_text)
	_slots = TdMenu.vbox(10)
	left.add_child(_slots)
	var right := TdMenu.vbox(16)
	right.custom_minimum_size = Vector2(560, 0)
	body.add_child(right)
	_card = CoopUi.level_card(560, 116)
	right.add_child(_card.panel)
	# a mission room: one compact row of drop coins right under the level picture
	_mission_box = TdMenu.vbox(0)
	var card_v: Control = (_card.map as Control).get_parent().get_parent()
	card_v.add_child(_mission_box)
	card_v.move_child(_mission_box, 1)
	_change_level = CoopUi.paper_action("icon_edit", "Change level", func(): open_settings())
	_card.extra.add_child(_change_level)
	var chat := TdMenu.panel(TdPanel.Kind.WOOD, 16)
	chat.custom_minimum_size = Vector2(0, CHAT_H) # fixed: the same for host and guest, every room (user rule)
	chat.size_flags_vertical = SIZE_SHRINK_BEGIN
	right.add_child(chat)
	var cv := TdMenu.vbox(8)
	chat.add_child(cv)
	cv.add_child(TdMenu.label("Chat", "h3", TdTheme.color("cream.100"), 26))
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_chat_scroll.custom_minimum_size = Vector2(0, CHAT_H - 120.0)
	cv.add_child(_chat_scroll)
	_chat_box = TdMenu.vbox(2)
	_chat_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_chat_box.alignment = BoxContainer.ALIGNMENT_END
	_chat_box.size_flags_vertical = SIZE_EXPAND_FILL
	_chat_scroll.add_child(_chat_box)
	_chat_scroll.get_v_scroll_bar().changed.connect(_scroll_chat) # keep the newest line in view
	_chat_in = CoopUi.field("Say something…", 0, false, NetProtocol.MAX_CHAT)
	_chat_in.text_submitted.connect(func(t):
		if net != null: net.chat(t)
		_chat_in.text = "")
	cv.add_child(_chat_in)
	# bottom row
	var bottom := TdMenu.hbox(18)
	col.add_child(bottom)
	var leave := TdMenu.wood_button("Leave room", Vector2(260, 66))
	leave.icon = TdTheme.texture("icon_back")
	leave.add_theme_constant_override("icon_max_width", 28)
	leave.pressed.connect(leave_room)
	bottom.add_child(leave)
	_wait = TdMenu.label("", "body", TdTheme.color("cream.100"), 23)
	_wait.size_flags_horizontal = SIZE_EXPAND_FILL
	_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wait.size_flags_vertical = SIZE_SHRINK_CENTER
	bottom.add_child(_wait)
	_ready_btn = TdMenu.button(TdButton.Style.SECONDARY, "Ready up", Vector2(220, 66), TdTheme.texture("icon_check"))
	_ready_btn.font_size = 30
	_ready_btn.clicked.connect(toggle_ready)
	_ready_ring = PanelContainer.new() # the green outline while you are Ready
	_ready_ring.mouse_filter = MOUSE_FILTER_IGNORE
	_ready_ring.size_flags_vertical = SIZE_SHRINK_CENTER
	_ready_ring.add_child(_ready_btn)
	bottom.add_child(_ready_ring)
	_start = TdMenu.button(TdButton.Style.PRIMARY, "Start", Vector2(200, 66), TdTheme.texture("icon_play"))
	_start.font_size = 30
	_start.clicked.connect(start)
	_start.bleed_mode = TdButton.Bleed.OFF
	bottom.add_child(_start)
	_popups = Control.new()
	_popups.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_popups.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_popups)

func _on_open() -> void:
	if net == null: net = get_node_or_null("/root/Net")
	if net == null: return
	for pair in [["room_changed", _on_room], ["room_notes", _on_notes], ["chat_received", _on_chat], ["match_started", _on_match],
			["kicked", _on_kicked], ["error_received", _on_error], ["rtt_changed", _on_rtt]]:
		if not net.is_connected(pair[0], pair[1]): net.connect(pair[0], pair[1])
	if chat_log.is_empty() and net.in_room:
		var host := NetProtocol.player_name(net.room, str(net.room.get("host", "")))
		add_system_line("%s created the room." % host if net.is_host else "You joined %s's room." % host)
	refresh()

func _exit_tree() -> void:
	super._exit_tree()
	if net == null: return
	for pair in [["room_changed", _on_room], ["room_notes", _on_notes], ["chat_received", _on_chat], ["match_started", _on_match],
			["kicked", _on_kicked], ["error_received", _on_error], ["rtt_changed", _on_rtt]]:
		if net.is_connected(pair[0], pair[1]): net.disconnect(pair[0], pair[1])

func _process(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= TdTheme.unscaled(delta)
		if _banner_left <= 0.0: _banner.visible = false

# ------------------------------------------------------------------ relay events

func _on_room(room: Dictionary) -> void:
	if room.is_empty():
		close()
		return
	if CoopLevels.auto_leave_reason(room) != "": return # the lobby leaves the room (and closes this)
	refresh()

func _on_notes(notes: Array) -> void:
	for n in notes:
		match n.kind:
			"joined": add_system_line("%s joined the room." % n.name)
			"left": add_system_line("%s left the room." % n.name)
			"host": add_system_line("%s is the host now." % n.name)
			"level":
				var ln := CoopLevels.level_name(str(n.value))
				add_system_line("%s changed the level to %s." % [n.name, ln])
				show_banner("Level changed to %s — Everyone's Ready was reset." % ln)
			"count":
				add_system_line("%s set the room to %d players." % [n.name, int(n.value)])
				show_banner("The room is for %d players now — Everyone's Ready was reset." % int(n.value))

func _on_chat(from: String, n: String, text: String) -> void:
	add_line(n, text, _color_of(from))

func _on_rtt(_ms: int) -> void:
	refresh()

func _on_kicked() -> void:
	close()

func _on_error(code: String, text: String) -> void:
	add_system_line(NetProtocol.error_text(code) if code != "bad_request" else text)

## The match started: Net emits match_ready (the in-match code changes scene); the room only says so.
func _on_match(_info: Dictionary) -> void:
	add_system_line("The match is starting…")

# ------------------------------------------------------------------ chat

func add_line(n: String, text: String, color: Color) -> void:
	chat_log.append({"name": n, "text": text, "color": color, "system": false})
	_draw_chat_line(chat_log.back())

func add_system_line(text: String) -> void:
	chat_log.append({"name": "", "text": text, "color": Color.WHITE, "system": true})
	_draw_chat_line(chat_log.back())

func _draw_chat_line(line: Dictionary) -> void:
	if _chat_box == null: return
	var t: String
	if line.system: t = "[i][color=#%s]%s[/color][/i]" % [TdTheme.color("cream.300").to_html(false), _esc(line.text)]
	else: t = "[b][color=#%s]%s[/color][/b] %s" % [TdTheme.color("accent.light").to_html(false), _esc(line.name), _esc(line.text)]
	var r := TdMenu.rich(t, "body", TdTheme.color("cream.100"), 21)
	r.add_theme_font_override("italics_font", CoopUi.italic_font())
	_chat_box.add_child(r)
	while _chat_box.get_child_count() > 60: _chat_box.get_child(0).free()
	_scroll_chat.call_deferred()

func _scroll_chat() -> void:
	if is_instance_valid(_chat_scroll): _chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)

static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")

func show_banner(text: String) -> void:
	_banner_text.text = text
	_banner.visible = true
	_banner_left = BANNER_SECONDS

# ------------------------------------------------------------------ drawing

func _color_of(player_id: String) -> Color:
	if net == null or not net.in_room: return CoopMode.COLORS[0]
	var p = NetProtocol.find_player(net.room, player_id)
	return CoopMode.COLORS[NetProtocol.int_of(p, "slot") % CoopMode.COLORS.size()] if p != null else CoopMode.COLORS[0]

## "Room: <name> · Password: <password>" for Copy (the room id never shows).
func invite_text() -> String:
	if net == null or not net.in_room: return ""
	var t := "Room: %s" % net.room.get("name", "")
	if bool(net.room.get("locked", false)) and net.room_password != "": t += " · Password: %s" % net.room_password
	return t

func refresh() -> void:
	if net == null or not net.in_room: return
	var room: Dictionary = net.room
	var level := str(room.get("level", ""))
	var count := NetProtocol.int_of(room, "count")
	var players := NetProtocol.players_by_slot(room)
	_title.text = str(room.get("name", ""))
	var locked := bool(room.get("locked", false))
	_lock.modulate = TdTheme.color("cream.100") if locked else Color(TdTheme.color("cream.300"), 0.35)
	_lock.tooltip_text = "Password room" if locked else "Open room: no password"
	_lock.mouse_filter = MOUSE_FILTER_PASS
	var mission := CoopLevels.mission_for_level(level)
	var what := CoopLevels.level_name(level) if mission == null else "%s · plays %s" % [mission.name, CoopLevels.level_name(level)]
	_sub.text = "%s · co-op · %d of %d player%s" % [what, players.size(), count, "" if count == 1 else "s"]
	if mission != null: # the plays line in the header too (the side card stays short)
		var sd = get_node_or_null("/root/SaveData")
		_sub.text += " · " + MissionBoard.plays_text(mission, sd.missions if sd != null else null)
	_code.text = "Room: [b][color=#%s]%s[/color][/b]  ·  Password: [b]%s[/b]" % [TdTheme.color("cream.100").to_html(false),
		_esc(str(room.get("name", ""))), "•".repeat(6) if locked else "none"]
	CoopUi.fill_level_card(_card, level, count, true)
	_fill_mission(mission)
	_change_level.visible = net.is_host
	_draw_slots(room, players, count, level)
	var me = NetProtocol.find_player(room, net.player_id)
	var am_ready: bool = me != null and bool(me.get("ready", false))
	# the guest's main button is Ready (cobalt); the host's main button is Start, so its Ready is the wood one
	_ready_btn.style = TdButton.Style.SECONDARY if net.is_host else TdButton.Style.PRIMARY
	_ready_btn.text = "Ready" if am_ready or not net.is_host else "Ready up"
	_ready_btn.set_selected(am_ready)
	_ready_ring.add_theme_stylebox_override("panel", CoopUi.box(Color(0, 0, 0, 0), 14, CoopUi.GOOD if am_ready else Color(0, 0, 0, 0), 3, Vector4(3, 3, 3, 3)))
	_ready_btn.tooltip_text = "Click again to stop being ready." if am_ready else "Tell the others you are ready."
	var waiting := NetProtocol.not_ready_names(room)
	var host_name := NetProtocol.player_name(room, str(room.get("host", "")))
	if net.is_host:
		_start.visible = true
		# not ready yet: the one Disabled look (UI review 2026-10-14), its click and hover say why; _wait says it too
		_start_reason = "" if waiting.is_empty() else "Waiting for %s to be ready." % NetProtocol.join_names(waiting)
		_start.set_interactable(_start_reason == "", _start_reason)
		_start.tooltip_text = _start_reason
		_wait.text = "Everyone is ready. Start when you like." if waiting.is_empty() else "Waiting for %s to be ready." % NetProtocol.join_names(waiting)
	else:
		_start.visible = false
		_wait.text = "%s starts the match when everyone is ready." % host_name
	# Ready needs a rested tower for a mission (Disabled look + the reason on the wait line)
	var level_id := str(room.get("level", ""))
	if not am_ready and not CoopLevels.can_ready(level_id):
		_ready_btn.set_interactable(false, CoopLevels.last_reason + ".")
		_wait.text = CoopLevels.last_reason + "."
	else:
		_ready_btn.set_interactable(true)
	my_hand_cut()

func _draw_slots(room: Dictionary, players: Array, count: int, level: String) -> void:
	CoopUi.clear(_slots)
	var cap := CoopLevels.hand_cap(level)
	var row_h := 76.0 if count <= 4 else 70.0
	for i in count:
		var p = players[i] if i < players.size() else null
		_slots.add_child(_slot_row(i, p, room, cap, row_h))

func _slot_row(i: int, p, room: Dictionary, cap: int, h: float) -> Control:
	var ready: bool = p != null and bool(p.get("ready", false))
	var panel: Container
	if p == null:
		panel = CoopUi.DashedBox.new()
	else:
		panel = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", CoopUi.box(Color(0.18, 0.13, 0.1, 0.9), 12, CoopUi.GOOD if ready else Color(0.3, 0.23, 0.17), 3 if ready else 2, Vector4(14, 6, 14, 6)))
	panel.custom_minimum_size = Vector2(0, h)
	var row := TdMenu.hbox(14)
	panel.add_child(row)
	row.add_child(CoopUi.number_badge(i + 1, p == null))
	if p == null:
		var circle := CoopUi.empty_circle(54)
		circle.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(circle)
		var gap := TdMenu.spacer()
		gap.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(gap)
		var strip := CoopUi.hand_strip([], cap, 44)
		strip.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(strip)
		row.add_child(TdMenu.spacer(0, 330))
		return panel
	var pid := str(p.id)
	var mine: bool = pid == net.player_id
	var hand: Array = p.get("hand", [])
	var medal := CoopUi.player_medal(hand, 54)
	medal.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(medal)
	var nm := TdMenu.label(str(p.get("name", "?")), "h2", TdTheme.color("accent.light"), 32) # one colour for every name
	nm.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(nm)
	row.add_child(CoopUi.ping_label(net.ping_of(pid) if net.has_method("ping_of") else -1))
	if pid == str(room.get("host", "")):
		var crown := TdMenu.label("♛ Host", "body", CoopUi.GOLD, 22)
		crown.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(crown)
	if mine:
		var you := TdMenu.pill("[b]You[/b]", Color(0.1, 0.08, 0.06), Color.WHITE, 20, Color("9cc2ff"))
		you.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(you)
	var sp := TdMenu.spacer()
	sp.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(sp)
	var strip2: Control = my_strip(cap) if mine else CoopUi.hand_strip(hand, cap, 44)
	strip2.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(strip2)
	var tired := CoopLevels.tired_note(cap) if mine and CoopLevels.mission_for_level(str(room.get("level", ""))) != null else ""
	if tired != "":
		var tl := TdMenu.label(tired.replace(": ", ":\n"), "small", TdTheme.color("cream.100"), 18)
		tl.size_flags_vertical = SIZE_SHRINK_CENTER
		tl.add_theme_constant_override("line_spacing", -4)
		row.add_child(tl)
	var state := CoopUi.state_pill("✓ Ready" if ready else "Not ready", Color("2f7d3a") if ready else Color(0.13, 0.1, 0.08), Color.WHITE if ready else TdTheme.color("cream.200"))
	state.custom_minimum_size = Vector2(150, 0)
	state.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(state)
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(190, 0)
	row.add_child(tail)
	if mine:
		var ch := TdMenu.button(TdButton.Style.SECONDARY, "Change hand", Vector2(186, 48), TdTheme.texture("icon_cards"))
		ch.font_size = 21
		ch.position = Vector2(0, (h - 12 - 48) / 2.0)
		ch.clicked.connect(open_hand_editor)
		tail.add_child(ch)
	elif net.is_host:
		# a 36 px ×, centred in the row's height, right-aligned inside the rim (no bleed room)
		var holder := HBoxContainer.new()
		holder.alignment = BoxContainer.ALIGNMENT_END
		holder.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		holder.offset_right = -4
		holder.mouse_filter = MOUSE_FILTER_IGNORE
		tail.add_child(holder)
		var x := TdButton.new()
		x.style = TdButton.Style.ICON
		x.bleed_mode = TdButton.Bleed.OFF
		x.custom_minimum_size = Vector2(36, 36)
		x.size = Vector2(36, 36)
		x.icon = TdTheme.texture("icon_close")
		x.size_flags_vertical = SIZE_SHRINK_CENTER
		x.name = "Kick"
		TdTooltipTrigger.attach(x, "", "Remove %s from the room" % p.get("name", ""))
		x.clicked.connect(func(): net.kick(pid))
		holder.add_child(x)
	return panel

## The side card for a mission room: the mission's name and ONE compact row of drops under a shorter picture
## ("Each win [coin]  First win [coin]"); the mission line and plays left are in the header.
func _fill_mission(mission: MissionDef) -> void:
	for c in _mission_box.get_children(): c.queue_free()
	_mission_box.visible = mission != null
	var map_frame: Control = (_card.map as Control).get_parent()
	map_frame.custom_minimum_size.y = MISSION_MAP_H if mission != null else MAP_H
	if mission == null: return
	_card.title.text = mission.name
	var sd = get_node_or_null("/root/SaveData")
	var mp: MissionProgress = sd.missions if sd != null else null
	var box := CoopUi.flat_panel(Color("2b201a"), 10, Color(0, 0, 0, 0), Vector4(12, 4, 12, 4))
	var row := TdMenu.hbox(8)
	box.add_child(row)
	var claimed := MissionUiLogic.first_win_claimed(mission, mp)
	for r in MissionUiLogic.drop_rows(mission):
		var first: bool = r[0] == "First win"
		if row.get_child_count() > 0: row.add_child(TdMenu.spacer(0, 6))
		var l := TdMenu.label(r[0], "plate", TdTheme.color("cream.200"), 18)
		l.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(l)
		for c in TdDrops.coins(r[1], first, first and claimed, 34.0): row.add_child(c)
		if first and claimed: row.add_child(TdDrops.claimed_tag(18))
	_mission_box.add_child(box)

## Your strip in your row: the saved hand's first `cap` towers (tired ones dimmed with the moon badge: the match
## skips them and takes the next rested tower), padded with empty circles.
func my_strip(cap: int) -> HBoxContainer:
	var sd = get_node_or_null("/root/SaveData")
	var h := TdMenu.hbox(4)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	if sd == null: return h
	var ids: Array = sd.towers.hand.slice(0, cap)
	for i in cap:
		if i >= ids.size():
			h.add_child(CoopUi.empty_circle(44))
			continue
		var owned = sd.towers.find(ids[i])
		var entry := CoopSession.hand_entry(owned.type, owned.form) if owned != null else ""
		var one := CoopUi.hand_strip([entry], 1, 44)
		var m: Control = one.get_child(0)
		one.remove_child(m)
		one.queue_free()
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(44, 44)
		holder.mouse_filter = MOUSE_FILTER_PASS
		holder.add_child(m)
		if MissionBoard.is_tired(str(ids[i]), sd.missions):
			m.modulate = Color(1, 1, 1, 0.5)
			TdTiredBadge.attach(holder, 44.0, 0.46, Vector2(0.18, 0.18))
			TdTooltipTrigger.attach(holder, "", MissionUiLogic.tired_line(null, false))
		h.add_child(holder)
	return h

## Your hand in the room is cut to the level's co-op cap (sent again when the saved hand or the cap changed).
func my_hand_cut() -> bool:
	if net == null or not net.in_room: return false
	var me = NetProtocol.find_player(net.room, net.player_id)
	if me == null: return false
	var want := CoopLevels.my_hand_types(CoopLevels.hand_cap(str(net.room.get("level", ""))))
	if want.is_empty() or want == Array(me.get("hand", [])): return false
	net.set_hand(want)
	return true

# ------------------------------------------------------------------ actions

func toggle_ready() -> void:
	if net == null or not net.in_room: return
	var me = NetProtocol.find_player(net.room, net.player_id)
	var ready := me != null and bool(me.get("ready", false))
	# a mission needs a rested tower to bring (Missions & Guild — Design § Tower energy)
	if not ready and not CoopLevels.can_ready(str(net.room.get("level", ""))):
		_ready_btn._deny()
		_wait.text = CoopLevels.last_reason + "."
		return
	net.set_ready(not ready)

## The host's Start: refused with its reason (shake + tooltip) while someone is not Ready.
func can_start() -> bool:
	return net != null and net.is_host and NetProtocol.all_ready(net.room)

func start() -> void:
	if not can_start():
		if _start_reason != "": _start._deny()
		return
	net.start_match()

func leave_room() -> void:
	if net == null: return
	net.leave_room()
	close()

## Change hand: the hand editor, limited to this level's co-op cap. Opening it makes you Not ready (Eren 2026-10-14);
## the new hand goes to the room once, when the editor closes (not on every edit; the relay resets Ready on it too).
func open_hand_editor() -> TdPopup:
	var he: TdPopup = load(HAND_EDITOR).instantiate()
	he.free_on_close = true
	var level := str(net.room.get("level", "")) if net != null else ""
	var cap_level := LevelAsset.new()  # stands in for the level: its name and the co-op cap
	cap_level.display_name = "co-op (%s)" % CoopLevels.level_name(level)
	cap_level.hand_cap = CoopLevels.hand_cap(level)
	he.level = cap_level
	_popups.add_child(he)
	if net != null and net.in_room:
		var me = NetProtocol.find_player(net.room, net.player_id)
		if me != null and bool(me.get("ready", false)): net.set_ready(false)
	he.closed.connect(func(): my_hand_cut())
	CoopUi.show_popup(he)
	return he

## Room settings (host): the level and the player count.
func open_settings() -> CoopRoomSettings:
	var s := CoopRoomSettings.new()
	s.free_on_close = true
	s.net = net
	_popups.add_child(s)
	CoopUi.show_popup(s)
	return s

func back() -> void:
	pass # Esc does not leave the room: Leave room does
