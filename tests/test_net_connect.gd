extends TestCase
## RelayClient's connect timeout: wall clock + a minimum number of polls, so one long frame (a slow device, a
## backgrounded browser tab) does not time out a socket the browser has not opened yet. Uses a stub peer that stays
## in STATE_CONNECTING (no network).

class StubPeer extends RefCounted:
	var ready_state := WebSocketPeer.STATE_CONNECTING
	var closed := false
	func poll() -> void: pass
	func get_ready_state() -> int: return ready_state
	func close(_code := 1000, _reason := "") -> void:
		closed = true
		ready_state = WebSocketPeer.STATE_CLOSED
	func send_text(_t: String) -> int: return OK
	func take() -> Array: return []

var c: RelayClient
var peer: StubPeer

func setup() -> void:
	c = RelayClient.new()
	c.auto_poll = false
	c.auto_reconnect = false
	c.player_name_override = "Test"
	c.version = "0123456789abcdef"
	peer = StubPeer.new()
	c._want = true
	c._peer = peer
	c._start_connect_clock()
	c._set_state(RelayClient.State.CONNECTING)

func teardown() -> void:
	c.free()

func test_one_long_frame_does_not_time_out() -> void:
	c.poll(10.0)
	assert_eq(c.state, RelayClient.State.CONNECTING, "a single 10 s delta keeps the attempt alive")
	assert_false(peer.closed)
	assert_eq(c.connect_failure, "")
	# the browser delivers the open event on the next frame: hello goes out
	peer.ready_state = WebSocketPeer.STATE_OPEN
	c.poll(0.016)
	assert_eq(c.state, RelayClient.State.HELLO)
	assert_eq(c.sent_log.back().t, "hello")

func test_many_long_frames_need_wall_clock_too() -> void:
	for i in 40: c.poll(10.0) # many polls, but almost no wall-clock time has passed
	assert_eq(c.state, RelayClient.State.CONNECTING, "summed deltas alone never time out")

func test_times_out_after_wall_clock_and_polls() -> void:
	c._connect_started_ms = Time.get_ticks_msec() - int(RelayClient.CONNECT_TIMEOUT * 1000.0) - 500
	for i in RelayClient.CONNECT_MIN_POLLS - 1: c.poll(0.016)
	assert_eq(c.state, RelayClient.State.CONNECTING, "too few polls: not yet")
	c.poll(0.016)
	assert_true(peer.closed, "8 s of wall clock and enough polls: the attempt fails")
	assert_eq(c.state, RelayClient.State.OFFLINE)
	assert_eq(c.connect_failure, "Can't reach the server.")

func test_retry_timer_clamps_a_long_frame() -> void:
	c.disconnect_relay()
	c._want = true
	c.auto_reconnect = true
	c._retry_in = 1.0
	c._set_state(RelayClient.State.RECONNECTING)
	c.poll(10.0) # clamped to MAX_DELTA: the retry is not fired by one long frame
	assert_num(c._retry_in, 1.0 - RelayClient.MAX_DELTA)
	c.disconnect_relay()
