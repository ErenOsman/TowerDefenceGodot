extends TestCase
## The co-op relay protocol (docs/COOP-PROTOCOL.md): frames, builders, limits, room helpers, error text, checksum.

func test_encode_decode_round_trip() -> void:
	var m := NetProtocol.create("Akşam savunması", "chapter1-1", 4, "gizli", ["archer", "mage"])
	var back = NetProtocol.decode(NetProtocol.encode(m))
	assert_eq(back.t, "create")
	assert_eq(back.name, "Akşam savunması", "Turkish characters survive")
	assert_eq(back.level, "chapter1-1")
	assert_eq(NetProtocol.int_of(back, "count"), 4)
	assert_eq(back.password, "gizli")
	assert_seq(back.hand, ["archer", "mage"])

func test_decode_rejects_non_messages() -> void:
	assert_null(NetProtocol.decode("not json"))
	assert_null(NetProtocol.decode("[1,2]"))
	assert_null(NetProtocol.decode("{\"x\": 1}"))
	assert_null(NetProtocol.decode("{\"t\": 5}"))
	assert_not_null(NetProtocol.decode("{\"t\": \"ping\"}"))

func test_builders_clamp_and_omit() -> void:
	assert_eq(NetProtocol.hello("abc", "  A very long player name here ").name.length(), NetProtocol.MAX_PLAYER_NAME)
	assert_eq(NetProtocol.hello("abc", "Eren").client, NetProtocol.CLIENT)
	assert_false(NetProtocol.create("Room", "l", 2, "", []).has("password"), "no password = open room")
	assert_eq(NetProtocol.create("x".repeat(40), "l", 9, "", []).name.length(), 24)
	assert_eq(NetProtocol.create("Room", "l", 9, "", []).count, 6)
	assert_eq(NetProtocol.set_count(0).count, 1)
	assert_eq(NetProtocol.chat("y".repeat(300)).text.length(), 200)
	assert_false(NetProtocol.join("ABC234", "", []).has("password"))
	var c := NetProtocol.cmd(3, 7, {"k": "pass"})
	assert_eq([c.t, c.round, c.seq, c.cmd.k], ["cmd", 3, 7, "pass"])
	assert_eq(NetProtocol.checksum(2, "00ff").hash, "00ff")

func test_int_of_reads_json_floats() -> void:
	var m = NetProtocol.decode("{\"t\":\"cmd\",\"round\":3,\"seq\":2.0}")
	assert_eq(NetProtocol.int_of(m, "round"), 3)
	assert_eq(NetProtocol.int_of(m, "seq"), 2)
	assert_eq(NetProtocol.int_of(m, "missing", 9), 9)

func test_error_text_for_every_code() -> void:
	for code in NetProtocol.ERROR_CODES:
		assert_true(NetProtocol.error_text(code) != "", code)
	assert_true(NetProtocol.error_text("wrong_password").contains("Wrong password"))
	assert_true(NetProtocol.error_text("full").contains("full"))

func test_room_helpers() -> void:
	var room := {"id": "R", "host": "a", "count": 4, "level": "l1", "players": [
		{"id": "b", "name": "Şule", "ready": true, "slot": 1},
		{"id": "a", "name": "Çağrı", "ready": true, "slot": 0},
		{"id": "c", "name": "Mert", "ready": false, "slot": 2}]}
	var order := []
	for p in NetProtocol.players_by_slot(room): order.append(p.id)
	assert_seq(order, ["a", "b", "c"])
	assert_false(NetProtocol.all_ready(room))
	assert_seq(NetProtocol.not_ready_names(room), ["Mert"])
	assert_eq(NetProtocol.join_names(["A", "B", "C"]), "A, B and C")
	assert_eq(NetProtocol.join_names(["A"]), "A")
	assert_false(NetProtocol.all_ready({"players": []}), "an empty room never starts")

func test_room_diff_notes() -> void:
	var old := {"id": "R", "host": "a", "count": 4, "level": "l1", "players": [
		{"id": "a", "name": "Çağrı", "slot": 0}, {"id": "c", "name": "Mert", "slot": 1}]}
	var new := {"id": "R", "host": "a", "count": 3, "level": "l2", "players": [
		{"id": "a", "name": "Çağrı", "slot": 0}, {"id": "b", "name": "Şule", "slot": 1}]}
	var kinds := []
	for n in NetProtocol.room_diff(old, new): kinds.append("%s:%s" % [n.kind, n.name])
	assert_set(kinds, ["left:Mert", "joined:Şule", "level:Çağrı", "count:Çağrı"])
	assert_eq(NetProtocol.room_diff({}, new).size(), 0, "entering a room says nothing")

func test_name_filter() -> void:
	assert_true(NetProtocol.name_allowed("Akşam savunması"))
	assert_true(NetProtocol.name_allowed("Klasik oda"), "short words only match whole words")
	assert_false(NetProtocol.name_allowed("   "))
	assert_false(NetProtocol.name_allowed("Kötü İsim"))

func test_fnv_matches_coop_session() -> void:
	for s in ["", "a", "round=1|Ç", "x".repeat(100)]:
		assert_eq(NetProtocol.fnv1a64(s), CoopSession.fnv1a64(s.to_utf8_buffer()), s)
	assert_eq(NetProtocol.fnv1a64(""), "cbf29ce484222325")

func test_content_version_is_16_hex() -> void:
	var v := CoopLevels.content_version()
	assert_eq(v.length(), 16)
	assert_true(FakeRelay._hex16(v), v)
