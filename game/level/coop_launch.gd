class_name CoopLaunch
extends RefCounted
## The co-op match the Game scene should play (like LevelLaunch for single player): set when the relay hands the
## match over (Net.match_ready), taken once by LevelController._setup, which then builds a CoopMode instead of a
## plain LevelSession. Static, no Node. GameApp hooks Net.match_ready to start_match once at boot.
##   info = {seed, level, shared_pool, players: [{id, name, hand (type ids), slot}] (slot order), local_player}

static var info: Dictionary = {}
## The relay client the match runs on (null = the `Net` autoload). Tools and tests set a stub.
static var net = null
static var _hooked: Object = null

static func has_request() -> bool:
	return not info.is_empty()

static func request(p_info: Dictionary, p_net = null) -> void:
	info = p_info.duplicate(true)
	net = p_net

## The pending match (consumed: a second call returns {}).
static func take() -> Dictionary:
	var out := info
	info = {}
	return out

static func clear() -> void:
	info = {}
	net = null

## Listens to a relay client's match_ready (once per client).
static func hook(relay) -> void:
	if relay == null or _hooked == relay or not relay.has_signal("match_ready"): return
	_hooked = relay
	relay.match_ready.connect(start_match)

## The relay started a match: the level is requested and the Game scene opens (through the loading screen).
## false when the level is not in this game (nothing changes then).
static func start_match(p_info: Dictionary) -> bool:
	var level := CoopLevels.level_asset(str(p_info.get("level", "")))
	if level == null:
		push_warning("[Coop] match_start for an unknown level: %s" % p_info.get("level", ""))
		return false
	LevelLaunch.request(level)
	request(p_info)
	var tree := Engine.get_main_loop() as SceneTree
	var flow = tree.root.get_node_or_null("SceneFlow") if tree != null else null
	if flow != null: flow.go(flow.Game)
	return true
