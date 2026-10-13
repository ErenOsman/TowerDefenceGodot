class_name ContentCheck
extends RefCounted
## Validate All: every content asset checked with AssetValidator (formulas, references, maps, waves…), tower type
## IDs unique, the levels' look (TileLook), and every level, tower, entity and the rules converted once to catch
## what only shows when the game builds them. Shared by the editor (Tools > Combat > Validate All) and the
## offline check, which runs it on the content JSON.

## One finding: the asset it is about, the message, and whether it is an error (else a warning).
class Finding:
	var asset
	var message: String
	var error: bool

	func _init(p_asset, p_message: String, p_error: bool) -> void:
		asset = p_asset
		message = p_message
		error = p_error

	func _to_string() -> String:
		return ("ERROR " if error else "WARN ") + message

## The asset types Validate All looks at.
const Types := [
	"AbilityAsset", "StatusAsset", "ReactionAsset", "PassiveAsset", "GameRulesAsset", "EntityAsset", "ItemAsset",
	"TowerAsset", "LevelAsset", "GameCatalogAsset", "TerrainAsset", "TileAsset",
]

## Checks the assets (any others are skipped). The vocabulary comes from the rules asset (or the default).
## Returns an Array of Finding.
static func run(assets: Array, vocab: Vocabulary) -> Array:
	var list := []
	for a in assets:
		if a != null and Types.has(ContentSerializer.type_of(a)): list.append(a)
	var findings := []
	for asset in list:
		for w in AssetValidator.warnings(asset): findings.append(Finding.new(asset, w, false))
		for e in AssetValidator.validate([asset], vocab): findings.append(Finding.new(asset, e, true))

	var ids := {}
	for tower in list:
		if not (tower is TowerAsset): continue
		if ids.has(tower.get_id()): findings.append(Finding.new(tower, "%s: tower type ID '%s' is also used by %s" % [tower.name, tower.get_id(), ids[tower.get_id()].name], true))
		else: ids[tower.get_id()] = tower

	# the levels' look (Tiles — Design): layer cells name Tiles of the right kind, and the automatic look finds a piece
	var kit = null
	for a in list:
		if a is GameRulesAsset:
			kit = a.tiles
			break
	if kit != null and not kit.is_empty():
		for level in list:
			if not (level is LevelAsset): continue
			var problems := []
			TileLook.ground(level, kit, problems)
			TileLook.props(level, kit, problems)
			var size: Vector2i = level.size
			if not level.visual.is_empty() and level.visual.size() != size.y: problems.append("the visual layer has %d rows, the map %d" % [level.visual.size(), size.y])
			if not level.props.is_empty() and level.props.size() != size.y: problems.append("the props layer has %d rows, the map %d" % [level.props.size(), size.y])
			var props := TileLook.props(level, kit)
			for x in size.x:
				for y in size.y:
					var piece: TilePiece = props[x][y]
					if piece.tile != null and piece.tile.kind != TileKind.Prop: problems.append("props (%d, %d): %s is not a Prop" % [x, y, piece.tile.get_id()])
			# unknown or malformed cells are errors; a tile no automatic piece fits is a warning
			var seen := {}
			for p in problems:
				if seen.has(p): continue
				seen[p] = true
				findings.append(Finding.new(level, "%s: look: %s" % [level.name, p], not p.contains("no piece fits")))

	# what the game does with them: convert (a broken reference chain shows here, not in the validator).
	# GDScript has no exceptions: a conversion that returns null is reported instead.
	for asset in list:
		var converter := AssetConverter.new()
		var made = true
		if asset is LevelAsset: made = converter.level(asset)
		elif asset is TowerAsset: made = converter.tower_type(asset)
		elif asset is EntityAsset: made = converter.entity(asset)
		elif asset is GameRulesAsset: made = converter.rules(asset)
		if made == null: findings.append(Finding.new(asset, "%s: converting it failed" % asset.name, true))
	return findings

## The vocabulary formulas are checked against: the rules asset's, or the default combat vocabulary.
static func vocabulary_of(rules: GameRulesAsset) -> Vocabulary:
	return rules.create_vocabulary() if rules != null else CombatVocabulary.create()
