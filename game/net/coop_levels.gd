class_name CoopLevels
extends RefCounted
## The game side of the co-op data: the content version sent in hello (ContentHash), the Multiplayer list
## (CoopList, res://data/coop.json) cached once, its level assets from the catalog, and the player's co-op hand
## (the saved hand's first coop_hand_cap tower types). Static, no Node.

static var _list: CoopList = null
static var _version := ""

static func list() -> CoopList:
	if _list == null: _list = CoopList.load()
	return _list

## The content hash (16 hex) both clients must share; cached.
static func content_version() -> String:
	if _version == "": _version = ContentHash.compute()
	return _version

static func shared_pool(level_id: String) -> bool:
	return list().shared_pool(level_id)

static func hand_cap(level_id: String) -> int:
	return list().hand_cap(level_id)

## The co-op levels' assets (unknown ids skipped), in list order.
static func level_assets() -> Array:
	var app = _app()
	return list().level_assets(app.catalog) if app != null else []

static func level_asset(level_id: String) -> LevelAsset:
	var app = _app()
	if app == null or app.catalog == null: return null
	return app.catalog.find_level(level_id)

## The level's name for players (the id when it is unknown).
static func level_name(level_id: String) -> String:
	var a := level_asset(level_id)
	return a.get_display_name() if a != null else level_id

## "Shared pool · 100, +12 a round" / "Separate energy · 1/4 each · 25 each, +3 a round".
static func energy_text(level_id: String, players: int) -> String:
	var a := level_asset(level_id)
	if a == null: return ""
	if shared_pool(level_id): return "Shared pool · %d, +%d a round" % [a.start_energy, a.energy_per_round]
	var n := maxi(1, players)
	return "Separate energy · 1/%d each · %d each, +%d a round" % [n, a.start_energy / n, a.energy_per_round / n]

## The tower TYPE ids the player brings (the protocol's `hand`): the saved hand's owned towers, in order, cut to cap.
## A formed tower is sent as "<type id>@<form id>" (CoopSession.hand_entry; the relay never reads it).
static func my_hand_types(cap: int) -> Array:
	var sd = _node("SaveData")
	var out := []
	if sd == null: return out
	for id in sd.towers.hand:
		var owned = sd.towers.find(id)
		if owned != null: out.append(CoopSession.hand_entry(owned.type, owned.form))
		if out.size() >= cap: break
	return out

## A TowerAsset by type id or hand entry ("archer@archer-fire" → the Archer; for pictures), or null.
static func tower_asset(type_id: String) -> TowerAsset:
	var app = _app()
	return app.catalog.find_tower(CoopSession.parse_hand_entry(type_id)[0]) if app != null and app.catalog != null else null

## The FormAsset of a hand entry ("archer@archer-fire"), or null for the default form.
static func form_asset(entry: String) -> FormAsset:
	var app = _app()
	var form_id: String = CoopSession.parse_hand_entry(entry)[1]
	return app.catalog.find_form(form_id) if form_id != "" and app != null and app.catalog != null else null

static func _app():
	return _node("GameApp")

static func _node(n: String):
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(n) if tree != null else null
