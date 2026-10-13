extends TestCase
## The co-op lobby screens driven by a RelayClient on the FakeRelay (in the tree, no frames needed): rooms listed,
## empty/offline states, join refusals, the room's slots and host controls, the settings' removal warning, chat notes.

var relay: FakeRelay
var me: RelayClient
var bot: FakeRelay.Link
var holder: Control

func setup() -> void:
	relay = FakeRelay.new()
	me = RelayClient.new()
	me.auto_poll = false
	me.player_name_override = "Çağrı"
	me.version = "0123456789abcdef"
	holder = Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(holder)
	holder.add_child(me)
	me.connect_fake(relay)
	me.poll()
	bot = relay.connect_client()
	bot.send_text(NetProtocol.encode(NetProtocol.hello("0123456789abcdef", "Şule")))

func teardown() -> void:
	holder.free()

func _lobby() -> CoopLobby:
	var l := CoopLobby.new()
	l.net = me
	holder.add_child(l)
	CoopUi.show_popup(l)
	return l

func test_lobby_lists_rooms_and_empty_state() -> void:
	var l := _lobby()
	assert_true(l._empty_box.visible, "no rooms: the empty state")
	assert_eq(l._empty_title.text, "No rooms yet.")
	bot.send_text(NetProtocol.encode(NetProtocol.create("Akşam", CoopLevels.list().level_ids()[0], 2, "pw", ["archer"])))
	me.poll()
	assert_eq(l._list.get_child_count(), 1)
	assert_false(l._empty_box.visible)
	assert_eq(l.selected_room, bot.room_id, "the first room is selected")
	l._search.text = "zzz"
	l._draw_list()
	assert_eq(l._list.get_child_count(), 0, "search filters")

func test_lobby_offline_state() -> void:
	me.disconnect_relay()
	me.auto_reconnect = false
	var l := _lobby()
	me.disconnect_relay()
	l.refresh()
	assert_eq(l._empty_title.text, "Can't reach the server.")
	assert_eq(l._empty_actions.get_child_count(), 2, "Retry and Offline practice")
	assert_false(l._create.interactable)

func test_join_popup_shows_wrong_password() -> void:
	bot.send_text(NetProtocol.encode(NetProtocol.create("Akşam", CoopLevels.list().level_ids()[0], 2, "pw", ["archer"])))
	me.poll()
	var l := _lobby()
	l.join_selected()
	me.poll()
	var j: CoopJoinPopup = null
	for c in l._popups.get_children(): if c is CoopJoinPopup: j = c
	assert_not_null(j, "a password room asks for it")
	j._password.text = "nope"
	j.join()
	me.poll()
	assert_true(j._warn.visible)
	assert_true((j._warn.get_node("Text") as Label).text.contains("Wrong password"))
	j._password.text = "pw"
	j.join()
	me.poll()
	assert_true(me.in_room)
	assert_not_null(l.room_popup, "the room opens once you are in")

func test_room_slots_host_controls_and_settings() -> void:
	var l := _lobby()
	var level: String = CoopLevels.list().level_ids()[0]
	me.create_room("Akşam", level, 4, "", ["archer"])
	me.poll()
	var room: CoopRoom = l.room_popup
	assert_not_null(room)
	assert_eq(room._slots.get_child_count(), 4, "one row per slot")
	bot.send_text(NetProtocol.encode(NetProtocol.join(me.room.id, "", ["mage"])))
	me.poll()
	var lines := []
	for c in room.chat_log: lines.append(c.text)
	assert_contains(lines, "Şule joined the room.")
	assert_true(room._start.visible, "the host sees Start")
	assert_false(room._start.interactable, "not everyone is ready")
	room.toggle_ready()
	bot.send_text(NetProtocol.encode(NetProtocol.ready(true)))
	me.poll()
	assert_true(room._start.interactable)
	var s := room.open_settings()
	s.count = 1
	assert_seq(s.removed_names(), ["Şule"])
	s._refresh()
	assert_eq(s._apply.text, "Apply and remove 1")
	s.level_id = CoopLevels.list().level_ids()[1]
	s.count = 4
	s.apply()
	me.poll()
	assert_true(room._banner.visible, "level changed banner")
	assert_false(room._start.interactable, "Ready reset")

func test_match_start_hands_off() -> void:
	var got := []
	me.match_ready.connect(func(info): got.append(info))
	me.create_room("Solo", CoopLevels.list().level_ids()[0], 1, "", ["archer"])
	me.poll()
	me.set_ready(true)
	me.poll()
	me.start_match()
	me.poll()
	assert_eq(got.size(), 1)
	assert_eq(got[0].local_player, me.player_id)
	assert_eq(got[0].players[0].hand, ["archer"])
