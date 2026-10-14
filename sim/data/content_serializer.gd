class_name ContentSerializer
extends RefCounted
## The content JSON format (Content/<Type>.json, AGENTS Rule 15), shared by ContentLibrary (JSON → plain asset
## objects) and the round-trip check (asset → JSON). Follows Unity's serialization: the fields each class
## serializes, in declaration order (SCHEMA below, since GDScript has no reflection over C# attributes).
## References are keys; [SerializeReference] objects (ability steps) carry "$type"; formulas and conditions are
## plain strings; enums are names; vectors are arrays. Art references ("Assets/Art/…png#name") stay strings.
##
## Field descriptors (JSON name → kind):
##   int, float, bool, string, art (a Unity asset path kept as a string; "" for none),
##   formula / formula:Slot / formula:Slot? (optional), condition:Slot, enum:EnumClass, ref:AssetClass,
##   obj:Class, poly (a [SerializeReference] object with "$type"), vec2i ([x, y]), pos ({"x", "y"} → Vector2i),
##   list:<descriptor>.
## The GDScript property is the snake_case of the JSON name (minRadius → min_radius).

const SCHEMA := {
	# ------------------------------------------------------------------ assets
	"AbilityAsset": {
		"number": "int", "id": "string", "displayName": "string", "description": "string", "icon": "art",
		"tags": "list:string", "costs": "list:obj:Cost", "castGate": "condition:CastGate", "targeting": "obj:PatternDef",
		"targetFilter": "condition:TargetFilter", "targetsDead": "bool", "needsFreeTile": "bool", "cooldown": "int",
		"cooldownUntilReset": "bool", "startCooldown": "int", "instinct": "obj:InstinctDef", "steps": "obj:StepList",
		"presentation": "ref:AbilityPresentationAsset", "faceTargetOnCast": "bool",
	},
	"StatusAsset": {
		"number": "int", "id": "string", "displayName": "string", "description": "string", "icon": "art", "loopVfx": "art",
		"tags": "list:string", "stacking": "enum:Stacking", "maxStacks": "int", "duration": "int",
		"durationUnit": "enum:DurationUnit", "modifiers": "list:obj:Modifier", "replacements": "list:obj:ReplacementData",
		"reactions": "list:ref:ReactionAsset", "passiveCondition": "condition:Passive", "aura": "condition:TargetFilter",
		"shieldPool": "formula:OnHit?", "teamOverride": "enum:TeamOverride", "fixedTeam": "int", "persistsThroughDeath": "bool",
	},
	"ReactionAsset": {
		"number": "int", "trigger": "enum:Trigger", "condition": "condition:ReactionTrigger", "chance": "formula:OnHit",
		"rollPer": "enum:RollPer", "timing": "enum:Timing", "limit": "enum:Limit", "ignoreTags": "list:string",
		"worksWhenDead": "bool", "response": "obj:StepList",
	},
	"PassiveAsset": {
		"number": "int", "displayName": "string", "description": "string", "icon": "art", "hidden": "bool",
		"condition": "condition:Passive", "offCondition": "condition:Passive", "modifiers": "list:obj:Modifier",
		"replacements": "list:obj:ReplacementData", "reactions": "list:ref:ReactionAsset", "aura": "condition:TargetFilter",
	},
	"EntityAsset": {
		"number": "int", "id": "string", "displayName": "string", "description": "string", "icon": "art", "miniature": "art",
		"view": "art", "plateOffset": "float", "kind": "enum:EntityKind", "tags": "list:string", "stats": "list:obj:StatValue",
		"footing": "enum:Footing", "blocksProjectiles": "bool", "abilities": "list:ref:AbilityAsset",
		"passives": "list:ref:PassiveAsset", "dieWithSummoner": "bool", "entrance": "ref:SequenceAsset",
	},
	"ItemAsset": {
		"number": "int", "modifiers": "list:obj:Modifier", "replacements": "list:obj:ReplacementData", "reactions": "list:ref:ReactionAsset",
	},
	"TowerAsset": {
		"number": "int", "id": "string", "displayName": "string", "description": "string", "icon": "art",
		"entity": "ref:EntityAsset", "cost": "int",
	},
	"LevelAsset": {
		"number": "int", "id": "string", "displayName": "string", "description": "string", "icon": "art", "music": "art",
		"terrain": "list:string", "terrainKeys": "list:obj:TerrainKey", "build": "list:string", "road": "list:string",
		"visual": "list:string", "props": "list:string", "paths": "list:obj:PathData", "bases": "list:obj:BaseData",
		"startingUnits": "list:obj:StartingUnitData", "handCap": "int", "fixedHand": "list:ref:TowerAsset",
		"intro": "ref:SequenceAsset", "startEnergy": "int", "energyPerRound": "int", "waves": "list:obj:WaveData",
	},
	"TerrainAsset": {
		"number": "int", "id": "string", "displayName": "string", "description": "string", "stand": "enum:Standing",
		"blocksProjectiles": "bool", "blocksSight": "bool", "tags": "list:string", "whenUnstandable": "enum:WhenUnstandable",
		"tiles": "list:ref:TileAsset", "buildTiles": "list:ref:TileAsset", "edgeTiles": "list:ref:TileAsset",
	},
	"TileAsset": {
		"number": "int", "id": "string", "view": "art", "kind": "enum:TileKind", "sides": "string",
	},
	"GameRulesAsset": {
		"stats": "list:string", "library": "list:obj:LibraryEntry", "hitChance": "formula:OnHit", "critChance": "formula:OnHit",
		"critMultiplier": "formula:OnHit", "mitigation": "formula:Mitigation", "manaRegen": "formula:Modifier",
		"facingEnabled": "bool", "relations": "list:obj:TeamRelation", "tiles": "list:ref:TileAsset",
		"reactions": "list:ref:ReactionAsset", "replacements": "list:obj:ReplacementData", "modifiers": "list:obj:Modifier",
		"maxDepth": "int",
		# Missions & Guild (Godot-first: set by the overlay's Extras.json until Rules.json has it)
		"towerEnergyPerDay": "int",
	},
	"GameCatalogAsset": {
		"chapters": "list:obj:ChapterData", "towerTypes": "list:ref:TowerAsset", "startingTowers": "list:ref:TowerAsset",
		"tutorial": "ref:LevelAsset", "tutorialReward": "ref:TowerAsset", "campUnlock": "ref:LevelAsset", "codex": "ref:CodexAsset",
		# Missions & Guild (Godot-first: set by the overlay's Extras.json until Catalog.json has them)
		"guildUnlock": "ref:LevelAsset", "missions": "list:ref:MissionAsset",
	},
	"CodexAsset": {
		"towers": "list:ref:TowerAsset", "enemies": "list:ref:EntityAsset", "statuses": "list:ref:StatusAsset", "tips": "list:obj:CodexTip",
	},
	"SequenceAsset": {"number": "int", "lines": "list:obj:SequenceLine"},
	# Workshop (Workshop — Design): Godot-first, from res://data/content-godot until the Unity repo has them
	"FormAsset": {
		"id": "string", "displayName": "string", "description": "string", "icon": "art", "badge": "art",
		"tower": "ref:TowerAsset", "parent": "ref:FormAsset", "entity": "ref:EntityAsset", "cost": "int",
		"unlock": "list:obj:TokenAmount", "order": "int",
	},
	"TokenAsset": {"id": "string", "displayName": "string", "description": "string", "icon": "art", "rarity": "enum:TokenRarity"},
	# Missions & Guild — Design: Godot-first, from res://data/content-godot until the Unity repo has Missions.json
	"MissionAsset": {
		"id": "string", "displayName": "string", "description": "string", "icon": "art", "level": "ref:LevelAsset",
		"mode": "enum:MissionMode", "players": "obj:PlayerRange", "playsPerDay": "int", "requires": "list:ref:ContentAsset",
		"requireAll": "bool", "sharedPool": "bool", "coopHandCap": "int", "firstWinTokens": "list:obj:TokenAmount",
		"winTokens": "list:obj:TokenAmount",
	},
	"AbilityPresentationAsset": {
		"number": "int", "casterAnimation": "enum:CasterAnimation", "customTrigger": "string", "projectile": "art",
		"projectileSpeed": "float", "castVfx": "art", "impactVfx": "art", "hitVfx": "art", "vfxLifetime": "float",
		"castSound": "art", "impactSound": "art", "hitSound": "art", "cameraShake": "float",
	},
	# ------------------------------------------------------------------ serializable data (DataTypes.cs and the asset files)
	"StepList": {"items": "list:poly"},
	"LibraryEntry": {"name": "string", "expression": "string"},
	"ReplacementData": {
		"name": "string", "matches": "enum:EffectKind", "withTags": "list:string", "condition": "condition:Replacement",
		"action": "enum:ReplaceAction", "instead": "obj:StepList",
	},
	"StatValue": {"stat": "string", "value": "string"},
	"TeamRelation": {"teamA": "int", "teamB": "int", "relation": "enum:Relation"},
	"TerrainKey": {"symbol": "string", "terrain": "ref:TerrainAsset"},
	"PathData": {"tiles": "list:vec2i"},
	"BaseData": {"tile": "vec2i", "entity": "ref:EntityAsset"},
	"StartingUnitData": {"entity": "ref:EntityAsset", "tile": "vec2i", "side": "enum:StartingSide", "path": "int", "facing": "enum:SpawnFacing"},
	"WaveData": {
		"name": "string", "start": "enum:WaveStart", "startRound": "int", "afterWave": "int", "spawns": "list:obj:SpawnData",
		"events": "list:obj:LevelEventData",
	},
	"SpawnData": {"round": "int", "enemy": "ref:EntityAsset", "path": "int", "facing": "enum:SpawnFacing"},
	"LevelEventData": {
		"round": "int", "kind": "enum:LevelEventKind", "enemy": "ref:EntityAsset", "count": "int", "path": "int",
		"randomTiles": "bool", "facing": "enum:SpawnFacing", "energy": "int", "message": "string",
		"terrain": "ref:TerrainAsset", "tiles": "list:vec2i", "build": "enum:BuildChange",
	},
	"ChapterData": {
		"id": "string", "displayName": "string", "kind": "enum:ChapterKind", "requires": "list:ref:LevelAsset",
		"requireAll": "bool", "levels": "list:obj:CatalogLevelData",
	},
	"CatalogLevelData": {
		"level": "ref:LevelAsset", "requirement": "enum:RequirementKind", "requires": "list:ref:LevelAsset",
		"requireAll": "bool", "firstClearReward": "ref:TowerAsset", "firstWinTokens": "list:obj:TokenAmount",
		"winTokens": "list:obj:TokenAmount",
	},
	"TokenAmount": {"token": "ref:TokenAsset", "amount": "int"},
	"PlayerRange": {"min": "int", "max": "int"},
	"CodexTip": {"id": "string", "title": "string", "text": "string", "image": "art"},
	# ------------------------------------------------------------------ core classes the assets embed (other slices own them)
	"PatternDef": {
		"shape": "enum:Shape", "minRadius": "formula:Targeting", "maxRadius": "formula:Targeting",
		"orientation": "enum:PatternOrientation", "includeCenter": "bool", "requiresLineOfSight": "bool",
		"stopAtFirstBlocker": "bool", "passesAllies": "bool", "jumpsOverUnits": "bool", "custom": "list:pos",
	},
	"InstinctDef": {"preset": "enum:InstinctPreset", "must": "condition:TargetFilter", "prefer": "list:obj:Preference"},
	"Preference": {"value": "formula:Instinct", "highest": "bool", "over": "enum:PreferOver", "filter": "condition:TargetFilter"},
	"Modifier": {
		"target": "string", "kind": "enum:ModKind", "amount": "formula:Modifier", "direction": "enum:ModDirection",
		"requiredTags": "list:string",
	},
	"Cost": {"resource": "string", "amount": "int"},
	"SequenceLine": {
		"speaker": "enum:SequenceSpeaker", "text": "string", "pointAt": "enum:SequencePointAt", "tileX": "int", "tileY": "int",
		"uiElement": "string", "continueOn": "enum:SequenceContinue", "seconds": "float", "waitFor": "enum:SequenceEvent",
		"pausesPlay": "bool",
	},
	# ------------------------------------------------------------------ ability steps ([SerializeReference] StepData)
	"AttackStepData": {
		"area": "obj:PatternDef", "areaFilter": "condition:TargetFilter", "power": "formula:Attack", "canMiss": "bool",
		"canCrit": "bool", "onHit": "obj:StepList", "hits": "formula:Attack", "bounces": "formula:Attack",
		"bounceArea": "obj:PatternDef", "bounceFilter": "condition:TargetFilter", "bounceInstinct": "obj:InstinctDef",
	},
	"DamageStepData": {"amount": "formula:OnHit", "tags": "list:string", "on": "enum:StepTarget"},
	"HealStepData": {"amount": "formula:OnHit", "tags": "list:string", "on": "enum:StepTarget"},
	"ApplyStatusStepData": {
		"status": "ref:StatusAsset", "stacks": "formula:OnHit", "duration": "formula:OnHit?", "on": "enum:StepTarget",
		"addTags": "list:string",
	},
	"RemoveStatusStepData": {
		"by": "enum:RemoveBy", "status": "ref:StatusAsset", "stacks": "formula:OnHit?", "tag": "string", "limit": "int",
		"on": "enum:StepTarget",
	},
	"PushStepData": {"distance": "formula:OnHit", "pull": "bool", "on": "enum:StepTarget"},
	"WalkStepData": {},
	"TeleportStepData": {"on": "enum:StepTarget"},
	"IfStepData": {"condition": "condition:Step", "then": "obj:StepList", "otherwise": "obj:StepList"},
	"CastAbilityStepData": {"ability": "ref:AbilityAsset", "aimAt": "enum:StepTarget", "aimByInstinct": "bool"},
	"ResetCooldownStepData": {"ability": "ref:AbilityAsset", "on": "enum:StepTarget", "turns": "formula:OnHit?"},
	"AddCooldownStepData": {"ability": "ref:AbilityAsset", "on": "enum:StepTarget", "turns": "formula:OnHit"},
	"PickStepData": {
		"area": "obj:PatternDef", "center": "enum:PickCenter", "filter": "condition:TargetFilter", "count": "formula:Attack",
		"instinct": "obj:InstinctDef", "steps": "obj:StepList",
	},
	"AddScopedModifierStepData": {"modifier": "obj:Modifier", "on": "enum:StepTarget"},
	"ChangeTerrainStepData": {
		"terrain": "ref:TerrainAsset", "area": "obj:PatternDef", "onlyOn": "list:string", "build": "enum:BuildChange",
	},
	"SpawnStepData": {"entity": "ref:EntityAsset", "at": "enum:SpawnAt", "summon": "bool", "team": "int"},
	"ResurrectStepData": {"hp": "formula:OnHit", "on": "enum:StepTarget"},
	"RemoveStepData": {"reason": "string", "on": "enum:StepTarget"},
	"JumpStepData": {},
	"FaceStepData": {"on": "enum:StepTarget", "mode": "enum:FaceMode", "direction": "enum:CardinalDirection"},
}

## The asset types (ScriptableObjects) a content file may hold.
const ASSET_TYPES := [
	"AbilityAsset", "StatusAsset", "ReactionAsset", "PassiveAsset", "EntityAsset", "ItemAsset", "TowerAsset", "LevelAsset",
	"TerrainAsset", "TileAsset", "GameRulesAsset", "GameCatalogAsset", "CodexAsset", "SequenceAsset", "AbilityPresentationAsset",
	"FormAsset", "TokenAsset", "MissionAsset",
]

## A new object of a content class by name (C# Activator.CreateInstance), or null for an unknown name.
static func create(type_name: String) -> Object:
	match type_name:
		"AbilityAsset": return AbilityAsset.new()
		"StatusAsset": return StatusAsset.new()
		"ReactionAsset": return ReactionAsset.new()
		"PassiveAsset": return PassiveAsset.new()
		"EntityAsset": return EntityAsset.new()
		"ItemAsset": return ItemAsset.new()
		"TowerAsset": return TowerAsset.new()
		"LevelAsset": return LevelAsset.new()
		"TerrainAsset": return TerrainAsset.new()
		"TileAsset": return TileAsset.new()
		"GameRulesAsset": return GameRulesAsset.new()
		"GameCatalogAsset": return GameCatalogAsset.new()
		"CodexAsset": return CodexAsset.new()
		"SequenceAsset": return SequenceAsset.new()
		"AbilityPresentationAsset": return AbilityPresentationAsset.new()
		"FormAsset": return FormAsset.new()
		"TokenAsset": return TokenAsset.new()
		"TokenAmount": return TokenAmount.new()
		"MissionAsset": return MissionAsset.new()
		"PlayerRange": return PlayerRange.new()
		"StepList": return StepList.new()
		"LibraryEntry": return LibraryEntry.new()
		"ReplacementData": return ReplacementData.new()
		"StatValue": return StatValue.new()
		"TeamRelation": return TeamRelation.new()
		"TerrainKey": return TerrainKey.new()
		"PathData": return PathData.new()
		"BaseData": return BaseData.new()
		"StartingUnitData": return StartingUnitData.new()
		"WaveData": return WaveData.new()
		"SpawnData": return SpawnData.new()
		"LevelEventData": return LevelEventData.new()
		"ChapterData": return ChapterData.new()
		"CatalogLevelData": return CatalogLevelData.new()
		"CodexTip": return CodexTip.new()
		"PatternDef": return PatternDef.new()
		"InstinctDef": return InstinctDef.new()
		"Preference": return Preference.new()
		"Modifier": return Modifier.new()
		"Cost": return Cost.new()
		"SequenceLine": return SequenceLine.new()
		"AttackStepData": return AttackStepData.new()
		"DamageStepData": return DamageStepData.new()
		"HealStepData": return HealStepData.new()
		"ApplyStatusStepData": return ApplyStatusStepData.new()
		"RemoveStatusStepData": return RemoveStatusStepData.new()
		"PushStepData": return PushStepData.new()
		"WalkStepData": return WalkStepData.new()
		"TeleportStepData": return TeleportStepData.new()
		"IfStepData": return IfStepData.new()
		"CastAbilityStepData": return CastAbilityStepData.new()
		"ResetCooldownStepData": return ResetCooldownStepData.new()
		"AddCooldownStepData": return AddCooldownStepData.new()
		"PickStepData": return PickStepData.new()
		"AddScopedModifierStepData": return AddScopedModifierStepData.new()
		"ChangeTerrainStepData": return ChangeTerrainStepData.new()
		"SpawnStepData": return SpawnStepData.new()
		"ResurrectStepData": return ResurrectStepData.new()
		"RemoveStepData": return RemoveStepData.new()
		"JumpStepData": return JumpStepData.new()
		"FaceStepData": return FaceStepData.new()
	return null

## An enum class by its C# name (JSON stores enum names), or null.
static func enum_class(enum_name: String):
	match enum_name:
		"Stacking": return Stacking
		"DurationUnit": return DurationUnit
		"TeamOverride": return TeamOverride
		"Relation": return Relation
		"Trigger": return Trigger
		"RollPer": return RollPer
		"Timing": return Timing
		"Limit": return Limit
		"StepTarget": return StepTarget
		"EffectKind": return EffectKind
		"ReplaceAction": return ReplaceAction
		"RemoveBy": return RemoveBy
		"PickCenter": return PickCenter
		"SpawnAt": return SpawnAt
		"FaceMode": return FaceMode
		"CardinalDirection": return CardinalDirection
		"BuildChange": return BuildChange
		"Standing": return Standing
		"WhenUnstandable": return WhenUnstandable
		"EntityKind": return EntityKind
		"Footing": return Footing
		"Shape": return Shape
		"PatternOrientation": return PatternOrientation
		"InstinctPreset": return InstinctPreset
		"PreferOver": return PreferOver
		"ModKind": return ModKind
		"ModDirection": return ModDirection
		"StartingSide": return StartingSide
		"SpawnFacing": return SpawnFacing
		"WaveStart": return WaveStart
		"LevelEventKind": return LevelEventKind
		"ChapterKind": return ChapterKind
		"RequirementKind": return RequirementKind
		"SequenceSpeaker": return SequenceSpeaker
		"SequencePointAt": return SequencePointAt
		"SequenceContinue": return SequenceContinue
		"SequenceEvent": return SequenceEvent
		"TileKind": return TileKind
		"CasterAnimation": return CasterAnimation
		"TokenRarity": return TokenRarity
		"MissionMode": return MissionMode
	return null

## The C# class name of a content object (its GDScript class_name), or "" for none.
static func type_of(o) -> String:
	if o == null or not (o is Object): return ""
	var s = o.get_script()
	return s.get_global_name() if s != null else ""

## Whether o is of the named class or derives from it.
static func is_type(o, type_name: String) -> bool:
	if o == null or not (o is Object): return false
	var s = o.get_script()
	while s != null:
		if s.get_global_name() == type_name: return true
		s = s.get_base_script()
	return false

static var _props := {}

## The GDScript property for a JSON field name: minRadius → min_radius.
static func prop_of(json_name: String) -> String:
	if not _props.has(json_name): _props[json_name] = json_name.to_snake_case()
	return _props[json_name]

## The serialized fields of a content class (JSON name → descriptor), or {} for an unknown class.
static func fields_of(type_name: String) -> Dictionary:
	return SCHEMA.get(type_name, {})

## The [Slot] of a formula or condition field (C# SlotAttribute), or null when the field is not a formula slot.
static func slot_of(type_name: String, json_name: String) -> SlotAttribute:
	var d: String = fields_of(type_name).get(json_name, "")
	for prefix in ["formula:", "condition:"]:
		if d.begins_with(prefix):
			var spec := d.substr(prefix.length())
			var optional := spec.ends_with("?")
			return SlotAttribute.new(spec.trim_suffix("?"), optional)
	return null

# ------------------------------------------------------------------ reading

## Sets the fields named in json on target (fields not in json keep their value); problems are reported, not thrown.
static func load_into(target: Object, json: Dictionary, refs, problems: Array, where: String) -> void:
	var type_name := type_of(target)
	var fields := fields_of(type_name)
	for key in json:
		if key == "$type": continue
		if not fields.has(key):
			problems.append("%s.%s: no such field" % [where, key])
			continue
		var prop := prop_of(key)
		if not (prop in target):
			problems.append("%s.%s: no such field (%s has no property '%s')" % [where, key, type_name, prop])
			continue
		var value = _load(json[key], fields[key], target.get(prop), refs, problems, "%s.%s" % [where, key])
		_assign_prop(target, prop, value)

## Sets a property; arrays go through assign() so typed array properties keep their type.
static func _assign_prop(target: Object, prop: String, value) -> void:
	var current = target.get(prop)
	if current is Array and value is Array:
		var fresh: Array = current.duplicate()
		fresh.assign(value)
		target.set(prop, fresh)
	elif current is String and value == null:
		target.set(prop, "")
	else:
		target.set(prop, value)

static func _load(json, desc: String, current, refs, problems: Array, where: String):
	if desc.begins_with("list:"):
		var element := desc.substr(5)
		var items: Array = json if json is Array else []
		var old: Array = current if current is Array else []
		var result := []
		for i in items.size():
			result.append(_load(items[i], element, old[i] if i < old.size() else null, refs, problems, "%s[%d]" % [where, i]))
		return result
	if desc == "poly":
		if not (json is Dictionary): return null
		var t = json.get("$type")
		var obj = current if current != null and type_of(current) == str(t) else create(str(t) if t != null else "")
		if obj == null or not SCHEMA.has(str(t)):
			problems.append("%s: unknown $type '%s'" % [where, "" if t == null else str(t)])
			return current
		load_into(obj, json, refs, problems, where)
		return obj
	if desc.begins_with("ref:"):
		if json == null: return null
		var key: String = json if json is String else str(json)
		var found = refs.resolve(key, desc.substr(4))
		if found == null and not refs.may_be_missing(key):
			problems.append("%s: '%s' not found" % [where, key])
			return current
		return found
	if desc == "art":
		return json if json is String else ""
	if desc == "string":
		if json == null: return ""
		return json if json is String else str(json)
	if desc == "bool":
		return json if json is bool else current
	if desc.begins_with("enum:"):
		var cls = enum_class(desc.substr(5))
		if json is String and cls.NAMES.has(json): return cls.parse(json)
		if json is float or json is int: return int(json)
		problems.append("%s: '%s' is not one of %s" % [where, str(json), ", ".join(cls.NAMES)])
		return current
	if desc == "int":
		if json is float or json is int: return int(json)
		if json is bool: return 1 if json else 0
		if json is String and json.is_valid_int(): return json.to_int()
		problems.append("%s: '%s' is not a number" % [where, str(json)])
		return current
	if desc == "float":
		if json is float or json is int: return float(json)
		if json is String and json.is_valid_float(): return json.to_float()
		problems.append("%s: '%s' is not a number" % [where, str(json)])
		return current
	if desc == "vec2i":
		var a := _floats(json, 2)
		return Vector2i(roundi(a[0]), roundi(a[1]))
	if desc == "pos":
		if json is Dictionary: return Vector2i(int(json.get("x", 0)), int(json.get("y", 0)))
		var a := _floats(json, 2)
		return Vector2i(roundi(a[0]), roundi(a[1]))
	if desc == "formula" or desc.begins_with("formula:"):
		return Formula.new(json if json is String else "")
	if desc.begins_with("condition:"):
		return Condition.new(json if json is String else "")
	if desc.begins_with("obj:"):
		var type_name := desc.substr(4)
		if json is Dictionary:
			var target = current if current != null and type_of(current) == type_name else create(type_name)
			load_into(target, json, refs, problems, where)
			return target
		return null if json == null and type_name != "Cost" else current
	push_error("ContentSerializer: unknown descriptor '%s'" % desc)
	return current

static func _floats(json, n: int) -> Array:
	var list: Array = json if json is Array else []
	var result := []
	for i in n: result.append(float(list[i]) if i < list.size() and (list[i] is float or list[i] is int) else 0.0)
	return result

# ------------------------------------------------------------------ writing

## An object's fields as JSON (a Dictionary in field order); refs gives the keys of referenced assets (key_of).
static func to_json(asset: Object, refs) -> Dictionary:
	return _save_object(asset, false, refs)

static func _save_object(value: Object, by_reference: bool, refs) -> Dictionary:
	var type_name := type_of(value)
	var o := {}
	if by_reference: o["$type"] = type_name
	var fields := fields_of(type_name)
	for key in fields:
		o[key] = _save(value.get(prop_of(key)), fields[key], refs)
	return o

static func _save(value, desc: String, refs):
	if desc.begins_with("list:"):
		var element := desc.substr(5)
		var out := []
		if value is Array:
			for item in value: out.append(_save(item, element, refs))
		return out
	if desc == "poly":
		return null if value == null else _save_object(value, true, refs)
	if desc.begins_with("ref:"):
		return null if value == null else refs.key_of(value)
	if desc == "art":
		return null if value == null or value == "" else value
	if desc == "string": return "" if value == null else value
	if desc == "bool": return bool(value)
	if desc.begins_with("enum:"):
		return enum_class(desc.substr(5)).name_of(int(value))
	if desc == "int": return int(value)
	if desc == "float": return float(value)
	if desc == "vec2i": return [value.x, value.y]
	if desc == "pos": return {"x": value.x, "y": value.y}
	if desc == "formula" or desc.begins_with("formula:") or desc.begins_with("condition:"):
		return "" if value == null or value.expression == null else value.expression
	if desc.begins_with("obj:"):
		return null if value == null else _save_object(value, false, refs)
	push_error("ContentSerializer: unknown descriptor '%s'" % desc)
	return null
