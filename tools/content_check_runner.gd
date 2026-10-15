extends RefCounted
## The content check job (tools/content_check.gd, daemon job `content_check`; used by the wiki's Content Editor):
## loads the game content (data/content) with candidate entries merged on top
## (ContentLibrary.load_game(candidate dir): same key → the candidate wins), validates everything (library problems,
## ContentCheck = Validate All, conversion of every candidate), reports only what the candidates add (findings that
## the content without them already has are counted in "baseline"), and probes each candidate by its type in small
## headless fights (statuses on dummies, abilities cast at dummies, units on a small road, levels played with the
## golden policy…).
##   run(["<candidate dir>", "[level id]"]) → {"json": Dictionary, "code": 0 ok / 1 errors / 2 usage}
##   run(["--schema"]) → the content format (ContentSerializer.SCHEMA, enum names, stats, file of each type)
## Engine-free apart from the logger (script errors met while probing are reported). No class_name on purpose:
## the resident daemon cannot learn new global classes without a restart.

const MAX_TURNS := 12
const LEVEL_ROUNDS := 40
const UNIT_ROUNDS := 3
const SEED := 12345
const MAX_EVENT_LINES := 60

## Engine errors (push_error, script errors) while the check runs.
class ErrLog extends Logger:
	var lines := PackedStringArray()
	var _m := Mutex.new()
	const KINDS := ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"]

	func take() -> PackedStringArray:
		_m.lock(); var l := lines; lines = PackedStringArray(); _m.unlock()
		return l

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var k := clampi(error_type, 0, 3)
		_m.lock()
		if lines.size() < 200:
			lines.append("%s: %s (%s:%d %s)" % [KINDS[k], rationale if rationale != "" else code, file, line, function])
		_m.unlock()

var lib: ContentLibrary
var conv: AssetConverter
var rules: GameRules
var errlog := ErrLog.new()
var errors: Array = []
var warnings: Array = []
var probes: Array = []
var candidates: Array = []   # [{file, type, key}]
var cand_keys := {}          # key → true
var _refs_index := {}        # candidate key → ["<owner key> (<field>)"]

# ------------------------------------------------------------------ entry

static func run(args: Array) -> Dictionary:
	var r = load("res://tools/content_check_runner.gd").new()
	return r._run(args)

func _run(args: Array) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	if args.size() > 0 and str(args[0]) == "--schema":
		return {"json": _schema(), "code": 0, "marker": "CONTENT_SCHEMA"}
	if args.is_empty():
		return {"json": {"ok": false, "errors": ["usage: content_check <candidate dir> [level id] | --schema"], "warnings": [], "probes": [], "elapsed_ms": 0}, "code": 2}
	var dir := str(args[0])
	var level_id := str(args[1]) if args.size() > 1 else ""
	OS.add_logger(errlog)
	var out := {}
	if not DirAccess.dir_exists_absolute(dir):
		errors.append("candidate dir %s does not exist" % dir)
	else:
		_check(dir, level_id)
	OS.remove_logger(errlog)
	out["ok"] = errors.is_empty()
	out["errors"] = errors
	out["warnings"] = warnings
	out["probes"] = probes
	out["candidates"] = candidates
	out["elapsed_ms"] = Time.get_ticks_msec() - t0
	if _baseline.size() > 0: out["baseline"] = _baseline
	return {"json": out, "code": 0 if errors.is_empty() else 1}

var _baseline := {}

func _check(dir: String, level_id: String) -> void:
	# the candidate files
	var by_file := {}
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"): continue
		var text := FileAccess.get_file_as_string(dir.path_join(f))
		var json := JSON.new()
		if json.parse(text) != OK:
			errors.append("%s: line %d: %s" % [f, json.get_error_line(), json.get_error_message()])
			continue
		var root = json.data
		if not (root is Dictionary) or not (root.get("assets") is Dictionary):
			errors.append("%s: not a content file ({\"type\", \"assets\": {key: entry}})" % f)
			continue
		var type_name := str(root.get("type", ""))
		if not ContentSerializer.ASSET_TYPES.has(type_name):
			errors.append("%s: type '%s' is not a content asset type (%s)" % [f, type_name, ", ".join(ContentSerializer.ASSET_TYPES)])
			continue
		if ContentFiles.file_of(type_name) != f:
			errors.append("%s: a %s file must be called %s" % [f, type_name, ContentFiles.file_of(type_name)])
			continue
		by_file[f] = root
		for key in root["assets"]:
			candidates.append({"file": f, "type": type_name, "key": key})
			cand_keys[key] = true
			if not (root["assets"][key] is Dictionary): continue
			# fields the format does not have are dropped by the loader with a problem; list them up front
			var fields := ContentSerializer.fields_of(type_name)
			for field in root["assets"][key]:
				if field != "$type" and not fields.has(field):
					errors.append("%s: unknown field '%s' (a %s has: %s)" % [key, field, type_name, ", ".join(fields.keys())])
			for field in fields:
				if not root["assets"][key].has(field):
					warnings.append("%s: field '%s' is missing (it gets the default)" % [key, field])
	if candidates.is_empty() and errors.is_empty():
		warnings.append("no candidate entries in %s: the content alone was loaded and validated" % dir)
	if not errors.is_empty() and by_file.is_empty(): return

	# the content without and with the candidates
	var base := ContentLibrary.load_game()
	lib = ContentLibrary.load_game(dir)
	var base_problems := {}
	for p in base.problems: base_problems[p] = true
	var known := 0
	for p in lib.problems:
		if base_problems.has(p): known += 1
		else: errors.append("load: " + p)
	for e in errlog.take(): errors.append("load: " + e)
	if lib.rules == null:
		errors.append("no game rules (Rules.json) in the content")
		return
	var vocab := ContentCheck.vocabulary_of(lib.rules)
	var base_find := {}
	for f in ContentCheck.run(base.all, ContentCheck.vocabulary_of(base.rules)): base_find[str(f)] = true
	errlog.take()
	var base_e := 0
	var base_w := 0
	for f in ContentCheck.run(lib.all, vocab):
		var key = lib.key_of(f.asset)
		var msg: String = ("%s: %s" % [key, f.message]) if key != null else f.message
		if base_find.has(str(f)):
			if f.error: base_e += 1
			else: base_w += 1
			continue
		if f.error: errors.append("validate: " + msg)
		else: warnings.append("validate: " + msg)
	for e in errlog.take(): errors.append("validate: " + e)
	_baseline = {"load_problems": known, "errors": base_e, "warnings": base_w,
		"note": "findings the content already has without the candidates (not listed)"}

	conv = AssetConverter.new()
	rules = conv.rules(lib.rules)
	_index_refs()

	# convert and probe each candidate
	for c in candidates:
		var asset = lib.get_asset(c.key)
		if asset == null:
			errors.append("%s: not loaded (see the load errors)" % c.key)
			continue
		if not ContentSerializer.is_type(asset, c.type):
			errors.append("%s: the key already names a %s in %s" % [c.key, ContentSerializer.type_of(asset), lib.file_of(asset)])
			continue
		var made = _convert(asset)
		var conv_errs := errlog.take()
		for e in conv_errs: errors.append("convert %s: %s" % [c.key, e])
		if made == null:
			errors.append("convert %s: converting it failed" % c.key)
			continue
		var probe := {"entry": c.key, "kind": c.type.trim_suffix("Asset").to_lower(), "lines": [], "tables": [], "warnings": []}
		var used: Array = _refs_index.get(c.key, [])
		probe.lines.append("found in: " + (", ".join(used) if not used.is_empty() else "nothing (no other entry refers to it)"))
		_probe(asset, made, probe)
		for e in errlog.take():
			probe.warnings.append("engine: " + e)
		for w in probe.warnings: warnings.append("probe %s: %s" % [c.key, w])
		probes.append(probe)

	if level_id != "":
		var la = null
		for l in lib.all_of("LevelAsset"):
			if l.id == level_id or lib.key_of(l) == level_id: la = l
		if la == null: errors.append("level '%s' not found (give its id or key)" % level_id)
		elif not cand_keys.has(lib.key_of(la)):
			var probe := {"entry": lib.key_of(la), "kind": "level", "lines": ["played with the candidates in the content"], "tables": [], "warnings": []}
			_probe_level(la, probe)
			for e in errlog.take(): probe.warnings.append("engine: " + e)
			for w in probe.warnings: warnings.append("probe %s: %s" % [probe.entry, w])
			probes.append(probe)

func _convert(asset):
	if asset is StatusAsset: return conv.status(asset)
	if asset is ReactionAsset: return conv.reaction(asset)
	if asset is AbilityAsset: return conv.ability(asset)
	if asset is PassiveAsset: return conv.passive(asset)
	if asset is EntityAsset: return conv.entity(asset)
	if asset is TowerAsset: return conv.tower_type(asset)
	if asset is LevelAsset: return conv.level(asset)
	if asset is FormAsset: return conv.form(asset)
	if asset is TokenAsset: return conv.token(asset)
	if asset is MissionAsset: return conv.mission(asset)
	if asset is TerrainAsset: return conv.terrain(asset)
	if asset is GameRulesAsset: return conv.rules(asset)
	return true

func _probe(asset, made, probe: Dictionary) -> void:
	if asset is StatusAsset: _probe_status(asset, made, probe)
	elif asset is AbilityAsset: _probe_ability(asset, made, probe)
	elif asset is EntityAsset: _probe_unit(asset, made, probe)
	elif asset is TowerAsset: _probe_tower(asset, made, probe)
	elif asset is LevelAsset: _probe_level(asset, probe)
	elif asset is ReactionAsset: _probe_reaction(asset, made, probe)
	elif asset is PassiveAsset: _probe_passive(asset, made, probe)
	elif asset is FormAsset: _probe_form(asset, probe)
	elif asset is TokenAsset: _probe_token(asset, probe)
	elif asset is MissionAsset: _probe_mission(asset, probe)
	else: probe.lines.append("no probe for this type (validator only)")

# ------------------------------------------------------------------ helpers

## Every reference to a candidate key from another entry ("Unit/Tower/Mage (abilities)").
func _index_refs() -> void:
	for a in lib.all:
		var owner = lib.key_of(a)
		var json := ContentSerializer.to_json(a, lib)
		_walk_refs(json, "", owner)

func _walk_refs(v, path: String, owner) -> void:
	if v is String:
		if cand_keys.has(v) and v != owner:
			if not _refs_index.has(v): _refs_index[v] = []
			var s := "%s (%s)" % [owner, path.trim_prefix(".")]
			if not _refs_index[v].has(s): _refs_index[v].append(s)
	elif v is Dictionary:
		for k in v: _walk_refs(v[k], path + "." + str(k), owner)
	elif v is Array:
		for x in v: _walk_refs(x, path, owner)

func _state(w: int = 13, h: int = 9) -> GameState:
	return GameState.new(rules, BattleGrid.new(w, h), SEED)

func _mk(obj, props: Dictionary):
	for k in props:
		var v = props[k]
		var cur = obj.get(k)
		if v is String and cur is Formula: v = Formula.new(v)
		elif v is String and cur is Condition: v = Condition.new(v)
		obj.set(k, v)
	return obj

func _apply_ability(status: StatusDef, stacks: String, duration: String = "") -> AbilityDef:
	return _mk(AbilityDef.new(), {name = "probe-apply", targeting = PatternDef.diamond("20"),
		steps = [_mk(ApplyStatusStep.new(), {status = status, stacks = stacks, duration = duration})]})

func _hit_ability(amount: String, tags: Array = []) -> AbilityDef:
	return _mk(AbilityDef.new(), {name = "probe-hit", tags = [Tags.Attack], targeting = PatternDef.diamond("20"),
		steps = [_mk(AttackStep.new(), {power = amount, can_miss = false, can_crit = false,
			on_hit = [_mk(DamageStep.new(), {amount = "ActionPower", tags = tags})]})]})

func _heal_ability(amount: String) -> AbilityDef:
	return _mk(AbilityDef.new(), {name = "probe-heal", targeting = PatternDef.diamond("20"),
		steps = [_mk(HealStep.new(), {amount = amount})]})

func _status_text(e: Entity) -> String:
	var parts := PackedStringArray()
	for s in e.statuses:
		if not s.active: continue
		parts.append("%s×%d%s" % [s.def.name, s.stacks, "" if s.turns_left < 0 else " (%dt)" % s.turns_left])
	return ", ".join(parts) if not parts.is_empty() else "-"

func _stats_text(stats: Dictionary) -> String:
	var parts := PackedStringArray()
	var keys := stats.keys()
	keys.sort()
	for k in keys: parts.append("%s %s" % [k, Num.to_str(stats[k])])
	return ", ".join(parts)

func _event_lines(s: GameState, log: EventLog, from: int, skip: Array = []) -> Array:
	var out := []
	for i in range(from, log.events.size()):
		var e: GameEvent = log.events[i]
		if skip.has(e.type): continue
		if out.size() >= MAX_EVENT_LINES:
			out.append("… %d more events" % (log.events.size() - i))
			break
		out.append(log.format(e, s))
	return out

const NOISE := [GameEventType.TurnStarted, GameEventType.TurnEnded, GameEventType.RoundStarted, GameEventType.RoundEnded,
	GameEventType.CooldownChanged, GameEventType.PhaseStarted]

## The step types somewhere in an asset's JSON ("DamageStepData"…).
func _step_types(asset) -> Dictionary:
	var found := {}
	_walk_types(ContentSerializer.to_json(asset, lib), found)
	return found

func _walk_types(v, found: Dictionary) -> void:
	if v is Dictionary:
		if v.has("$type"): found[str(v["$type"])] = true
		for k in v: _walk_types(v[k], found)
	elif v is Array:
		for x in v: _walk_types(x, found)

## Units (EntityAssets) whose abilities include this ability asset.
func _units_with_ability(a) -> Array:
	var out := []
	for u in lib.all_of("EntityAsset"):
		if u.abilities.has(a): out.append(u)
	return out

func _tower_entities() -> Dictionary:
	var out := {}
	for t in lib.all_of("TowerAsset"):
		if t.entity != null: out[t.entity] = t
	for f in lib.all_of("FormAsset"):
		if f.entity != null: out[f.entity] = f
	return out

# ------------------------------------------------------------------ Status

func _probe_status(asset: StatusAsset, def: StatusDef, probe: Dictionary) -> void:
	probe.lines.append("%s: stacking %s, max %d stacks, duration %s %s, tags [%s]%s%s" % [def.name, Stacking.name_of(def.stacking),
		def.max_stacks, "∞ (-1)" if def.duration < 0 else str(def.duration), DurationUnit.name_of(def.duration_unit), ", ".join(def.tags),
		", shield pool " + def.shield_pool.expression if not def.shield_pool.is_empty else "",
		", %d reaction(s)" % def.reactions.size() if def.reactions.size() > 0 else ""])
	# typical stacks: what the content's abilities apply
	var typical := mini(3, maxi(1, def.max_stacks))
	var typical_note := "no ability applies it yet: probe uses %d" % typical
	var appliers := []
	for a in lib.all_of("AbilityAsset") + lib.all_of("ReactionAsset"):
		var found := []
		_find_apply(ContentSerializer.to_json(a, lib), lib.key_of(asset), found)
		for f in found: appliers.append([a, f])
	if not appliers.is_empty():
		var a = appliers[0][0]
		var step: Dictionary = appliers[0][1]
		var stacks := str(step.get("stacks", "1"))
		var value = AssetConverter.try_parse(stacks)
		var who := ""
		if value == null and stacks.begins_with("Self.") and a is AbilityAsset:
			for u in _units_with_ability(a):
				for sv in u.stats:
					if sv != null and "Self." + sv.stat == stacks:
						value = AssetConverter.try_parse(sv.value)
						who = " of " + str(lib.key_of(u))
				if value != null: break
		if value != null: typical = clampi(int(value), 1, maxi(1, def.max_stacks))
		typical_note = "typical %d = %s '%s'%s (%s%s)" % [typical, "stacks", stacks, who, lib.key_of(a),
			", duration '%s'" % step.get("duration") if str(step.get("duration", "")) != "" else ""]
		if appliers.size() > 1:
			var others := PackedStringArray()
			for i in range(1, mini(appliers.size(), 6)): others.append("%s (stacks '%s')" % [lib.key_of(appliers[i][0]), appliers[i][1].get("stacks", "1")])
			typical_note += "; also applied by " + ", ".join(others)
	probe.lines.append(typical_note)
	var counts := []
	for n in [1, typical, maxi(1, def.max_stacks)]:
		if not counts.has(n): counts.append(n)
	# a shield for the shielded dummy: the content's (a status with a shield pool) or a plain one
	var shield_def: StatusDef = null
	for s in lib.all_of("StatusAsset"):
		if s != asset and not s.shield_pool.is_empty and s.duration < 0:
			shield_def = conv.status(s)
			break
	if shield_def == null:
		shield_def = _mk(StatusDef.new(), {name = "probe-shield", stacking = Stacking.Stack, max_stacks = 9999, duration = -1, shield_pool = "Stacks"})
	var ticks := _step_types(asset)
	var tick_reactions := false
	for r in def.reactions:
		if r != null and r.trigger in [Trigger.OnTurnStart, Trigger.OnTurnEnd, Trigger.OnRoundStart, Trigger.OnRoundEnd, Trigger.OnAnyTurnStart, Trigger.OnAnyTurnEnd]:
			tick_reactions = true
	var does_hp := false
	for r in asset.reactions:
		if r == null: continue
		var t := _step_types(r)
		if t.has("DamageStepData") or t.has("HealStepData") or t.has("AttackStepData"): does_hp = true
	var never_expires := false
	var decays := false
	for target_kind in ["100-HP dummy", "shielded dummy (100 HP + 20 shield)"]:
		for n in counts:
			var s := _state()
			var r := Resolver.new(s)
			var applier: Entity = s.add_unit("Applier", Teams.Player, Vector2i(0, 0), 100, [["Power", 10], ["Potency", 2]])
			var dummy: Entity = s.add_unit("Dummy", Teams.Enemy, Vector2i(2, 0), 100, [["Speed", 1]])
			if target_kind.begins_with("shielded"):
				r.cast(applier, _apply_ability(shield_def, "20"), Aim.at(applier.pos, dummy.pos))
			var mods_before := {}
			for m in def.modifiers:
				if m != null and m.target != "": mods_before[m.target] = s.final_stat(dummy, m.target)
			r.cast(applier, _apply_ability(def, str(n)), Aim.at(applier.pos, dummy.pos))
			var rows := []
			rows.append(["applied", dummy.hp, dummy.shield, dummy.stacks(def.name), _turns_left(dummy, def), _status_text(dummy)])
			if dummy.stacks(def.name) == 0 and not dummy.has_status(def.name):
				probe.warnings.append("%d stack(s) on the %s: not applied (or removed at once)" % [n, target_kind])
			if not mods_before.is_empty():
				var parts := PackedStringArray()
				for k in mods_before: parts.append("%s %s → %s" % [k, Num.to_str(mods_before[k]), Num.to_str(s.final_stat(dummy, k))])
				probe.lines.append("%d stack(s) on the %s: %s" % [n, target_kind, ", ".join(parts)])
			var prev_stacks := dummy.stacks(def.name)
			var hp_seen := dummy.hp + dummy.shield
			var changed := false
			var death_turn := -1
			var gone_turn := -1
			var log_from := r.log.events.size()
			for t in range(1, MAX_TURNS + 1):
				r.start_round()
				r.start_turn(dummy)
				var hp_a := dummy.hp
				var sh_a := dummy.shield
				var st_a := dummy.stacks(def.name)
				r.end_turn(dummy)
				r.end_round()
				if dummy.hp + dummy.shield != hp_seen: changed = true
				hp_seen = dummy.hp + dummy.shield
				var st_b := dummy.stacks(def.name)
				if st_b < prev_stacks and st_b > 0: decays = true
				prev_stacks = st_b
				rows.append([str(t), "%d → %d" % [hp_a, dummy.hp], "%d → %d" % [sh_a, dummy.shield], "%d → %d" % [st_a, st_b], _turns_left(dummy, def), _status_text(dummy)])
				if not dummy.alive:
					death_turn = t
					break
				if not dummy.has_status(def.name):
					gone_turn = t
					break
			var dmg := 100 + (20 if target_kind.begins_with("shielded") else 0) - dummy.hp - dummy.shield
			var summary := "%d stack(s) on the %s: " % [n, target_kind]
			if death_turn > 0:
				summary += "kills a 100-HP unit in %d turn(s)" % death_turn
				if target_kind == "100-HP dummy": probe.warnings.append("%d stack(s) kill a 100-HP unit in %d turn(s)" % [n, death_turn])
			elif gone_turn > 0: summary += "gone after %d turn(s), %d HP+shield lost in all" % [gone_turn, dmg]
			else:
				summary += "still on after %d turns (%d stacks), %d HP+shield lost" % [MAX_TURNS, dummy.stacks(def.name), dmg]
				never_expires = true
			probe.lines.append(summary)
			probe.tables.append({"title": "%d stack(s) on the %s" % [n, target_kind],
				"columns": ["turn", "HP after turn start → end", "shield (start → end)", "stacks (start → end)", "turns left", "statuses"], "rows": rows})
			if does_hp and tick_reactions and not changed and death_turn < 0 and n == counts[0] and target_kind == "100-HP dummy":
				probe.warnings.append("ticks for 0: its reactions deal damage/heal but HP never changed over %d turns" % MAX_TURNS)
			if not r.log.warnings.is_empty(): probe.warnings.append("resolver: " + str(r.log.warnings[0]))
			if n == counts[0] and target_kind == "100-HP dummy":
				var ev := _event_lines(s, r.log, log_from, NOISE)
				if not ev.is_empty():
					probe.lines.append("events (%d stack(s), plain dummy):" % n)
					for l in ev: probe.lines.append("  " + l)
	if never_expires:
		if decays: probe.warnings.append("stacks never reach 0 with the remove rule: still on after %d turns" % MAX_TURNS)
		elif def.duration < 0 and not def.tags.has(Tags.Permanent) and def.shield_pool.is_empty:
			probe.warnings.append("never expires (duration -1 and nothing removes it)")
		elif def.duration >= MAX_TURNS: probe.warnings.append("lasts longer than %d turns" % MAX_TURNS)
	if def.reactions.is_empty() and def.modifiers.is_empty() and def.replacements.is_empty() and def.shield_pool.is_empty \
			and def.aura.is_empty and def.team_override == TeamOverride.None and _tag_effects(def).is_empty():
		probe.warnings.append("does nothing by itself: no reactions, modifiers, replacements, shield, aura, team override or rule tag")

func _tag_effects(def: StatusDef) -> Array:
	var out := []
	for t in def.tags:
		if t in [Tags.Stunned, Tags.Frozen, Tags.Asleep, Tags.Rooted, Tags.Silenced, Tags.Disarmed, Tags.Untargetable,
				Tags.Stealthed, Tags.Taunted, Tags.Redirected]:
			out.append(t)
	return out

func _turns_left(e: Entity, def: StatusDef) -> String:
	for s in e.statuses:
		if s.active and s.def == def: return "∞" if s.turns_left < 0 else str(s.turns_left)
	return "-"

func _find_apply(v, status_key, found: Array) -> void:
	if v is Dictionary:
		if str(v.get("$type", "")) == "ApplyStatusStepData" and v.get("status") == status_key: found.append(v)
		for k in v: _find_apply(v[k], status_key, found)
	elif v is Array:
		for x in v: _find_apply(x, status_key, found)

# ------------------------------------------------------------------ Ability

const DEFAULT_STATS := {"MaxHp": 100.0, "Initiative": 0.0, "Power": 10.0, "Potency": 2.0, "Range": 3.0, "Radius": 1.0, "Speed": 2.0, "Duration": 2.0}

func _probe_ability(asset: AbilityAsset, def: AbilityDef, probe: Dictionary) -> void:
	var users := _units_with_ability(asset)
	var towers := _tower_entities()
	var caster_def: EntityDef
	var team := Teams.Player
	if not users.is_empty():
		var u = users[0]
		caster_def = conv.entity(u)
		if not towers.has(u) and u.footing != Footing.OffPath: team = Teams.Enemy
		var names := PackedStringArray()
		for x in users: names.append(str(lib.key_of(x)))
		probe.lines.append("cast by a dummy with the stats of %s (%s side): %s; units with it: %s" % [lib.key_of(u),
			"tower" if team == Teams.Player else "enemy", _stats_text(caster_def.base_stats), ", ".join(names)])
	else:
		caster_def = EntityDef.new()
		caster_def.name = "probe-caster"
		caster_def.base_stats = DEFAULT_STATS.duplicate()
		caster_def.abilities = [def]
		caster_def.footing = Footing.OffPath
		probe.lines.append("no unit has it: cast by a dummy with %s (tower side)" % _stats_text(caster_def.base_stats))
	var foe := Teams.Enemy if team == Teams.Player else Teams.Player
	probe.lines.append("cooldown %d%s%s, targeting %s r %s–%s, filter '%s', tags [%s]%s" % [def.cooldown,
		" (until reset)" if def.cooldown_until_reset else "", ", starts on cooldown %d" % def.start_cooldown if def.start_cooldown != 0 else "",
		Shape.name_of(def.targeting.shape), def.targeting.min_radius.expression, def.targeting.max_radius.expression,
		def.target_filter.expression if def.target_filter.expression != null else "", ", ".join(def.tags),
		", costs " + ", ".join(def.costs.map(func(c): return "%d %s" % [c.amount, c.resource])) if not def.costs.is_empty() else ""])
	if def.targeting.shape == Shape.PathAhead:
		probe.lines.append("moves along an enemy road: see a Unit probe of a unit that has it (no road here)")
		return
	var s := _state(13, 9)
	var r := Resolver.new(s)
	var caster: Entity = s.create(caster_def, team, Vector2i(2, 4))
	if not caster.abilities.has(def): caster.abilities.append(def)
	caster.cooldowns.erase(def)
	# dummies: foes at 1, 2 and 5 tiles, a group of three around 3 tiles (areas), a hurt ally and a full one
	var layout := [["Foe d1", foe, Vector2i(3, 4), 100], ["Foe d2", foe, Vector2i(4, 4), 100], ["Foe group", foe, Vector2i(5, 4), 100],
		["Foe group N", foe, Vector2i(5, 5), 100], ["Foe group S", foe, Vector2i(5, 3), 100], ["Foe d5", foe, Vector2i(7, 4), 100],
		["Hurt ally", team, Vector2i(2, 5), 100], ["Ally", team, Vector2i(1, 4), 100]]
	for d in layout:
		var e: Entity = s.add_unit(d[0], d[1], d[2], d[3], [["Speed", 1]])
		if d[0] == "Hurt ally": e.hp = 50
	var reason := []
	if not Targeting.can_cast(s, caster.id, def, reason):
		var why := str(reason[0])
		probe.warnings.append(("cost unaffordable: " if why.begins_with("Not enough") else "cannot cast: ") + why)
		return
	var aims := Targeting.valid_aims(s, caster.id, def)
	var tiles := PackedStringArray()
	for a in aims.slice(0, 12): tiles.append(Dirs.pos_str(a.tile))
	probe.lines.append("%d valid aim(s) from (2, 4)%s" % [aims.size(), ": " + ", ".join(tiles) + (" …" if aims.size() > 12 else "") if not aims.is_empty() else ""])
	var qr := []
	var aim: Aim = Instinct.quick_cast(s, caster, def, qr)
	if aim == null:
		probe.warnings.append("no valid aim: %s" % str(qr[0] if not qr.is_empty() else "?"))
		return
	var before := {}
	for e in s.entities:
		if e.is_environment: continue
		before[e.id] = [e.hp, e.shield, _status_text(e), e.pos]
	var from := r.log.events.size()
	r.cast(caster, def, aim)
	probe.lines.append("the instinct (%s) aims at %s" % [InstinctPreset.name_of(def.instinct.preset), Dirs.pos_str(aim.tile)])
	var rows := []
	var hit := 0
	for e in s.entities:
		if e.is_environment or not before.has(e.id): continue
		var b: Array = before[e.id]
		var st := _status_text(e)
		if b[0] == e.hp and b[1] == e.shield and b[2] == st and b[3] == e.pos: continue
		if e != caster: hit += 1
		rows.append([e.name, "foe" if e.base_team == foe else ("caster" if e == caster else "ally"), str(e.hp - b[0]),
			"%d → %d" % [b[0], e.hp], "%d → %d" % [b[1], e.shield], "%s → %s" % [b[2], st],
			"" if b[3] == e.pos else "%s → %s" % [Dirs.pos_str(b[3]), Dirs.pos_str(e.pos)]])
	probe.tables.append({"title": "one cast at %s" % Dirs.pos_str(aim.tile), "columns": ["unit", "side", "HP change", "HP", "shield", "statuses", "moved"], "rows": rows})
	probe.lines.append("%d unit(s) affected" % hit)
	if hit == 0: probe.warnings.append("the cast changed nothing on any dummy")
	var cd := caster.cooldown(def)
	if cd == Entity.HeldCooldown: probe.lines.append("after the cast: on cooldown until reset")
	else:
		var turns := 0
		while not Targeting.can_cast(s, caster.id, def) and turns < 10 and caster.alive:
			r.start_turn(caster)
			r.end_turn(caster)
			turns += 1
		probe.lines.append("after the cast: cooldown %d; castable again after %d turn start(s)%s" % [cd, turns,
			"" if Targeting.can_cast(s, caster.id, def) else " (still not after 10: %s)" % Targeting.last_reason])
	for l in _event_lines(s, r.log, from, NOISE): probe.lines.append("  " + l)
	if not r.log.warnings.is_empty(): probe.warnings.append("resolver: " + str(r.log.warnings[0]))

# ------------------------------------------------------------------ Unit / Entity

func _probe_unit(asset: EntityAsset, def: EntityDef, probe: Dictionary) -> void:
	_describe_entity(def, probe)
	var towers := _tower_entities()
	var player_side: bool = towers.has(asset) or def.footing == Footing.OffPath
	_run_road(def, player_side, probe)

func _describe_entity(def: EntityDef, probe: Dictionary) -> void:
	probe.lines.append("%s: %s, footing %s, tags [%s]" % [def.name, EntityKind.name_of(def.kind), Footing.name_of(def.footing), ", ".join(def.tags)])
	probe.lines.append("stats: " + _stats_text(def.base_stats))
	var rows := []
	for a in def.abilities:
		if a == null: continue
		rows.append([a.name, a.get_display_name(), str(a.cooldown), "%s %s–%s" % [Shape.name_of(a.targeting.shape), a.targeting.min_radius.expression, a.targeting.max_radius.expression],
			"movement" if a.targeting.is_movement else ", ".join(a.tags)])
	probe.tables.append({"title": "abilities", "columns": ["id", "name", "cooldown", "targeting", "tags"], "rows": rows})
	var pn := PackedStringArray()
	for p in def.passives:
		if p != null: pn.append(p.get_display_name() if p.has_method("get_display_name") else p.name)
	probe.lines.append("passives: " + (", ".join(pn) if not pn.is_empty() else "none"))
	if def.abilities.is_empty() and def.kind == EntityKind.Unit: probe.warnings.append("a unit with no abilities: it never acts")

## A small road (9 × 3, road along the middle row to a base at the right end). An enemy-side unit starts on the
## road with a 100-HP dummy tower beside it; a tower-side unit stands beside the road with two 100-HP dummies
## on it. UNIT_ROUNDS rounds; its own casts follow the golden policy (quick-cast every ability it can).
func _run_road(def: EntityDef, player_side: bool, probe: Dictionary) -> void:
	var base_asset = null
	for e in lib.all_of("EntityAsset"):
		if e.tags.has(Tags.Base):
			base_asset = e
			break
	var level_json := {"id": "probe-road", "displayName": "Probe road",
		"terrain": [".........", ".........", "........."], "terrainKeys": [], "build": ["+++++++..", ".........", "+++++++.."],
		"road": [".........", "────────╴", "........."], "paths": [{"tiles": [[0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [6, 1], [7, 1]]}],
		"bases": [], "startingUnits": [], "handCap": 0, "startEnergy": 0, "energyPerRound": 0, "waves": []}
	var ground = null
	for t in lib.all_of("TerrainAsset"):
		if t.stand == Standing.Everyone and not t.blocks_projectiles:
			ground = t
			break
	if ground != null: level_json["terrainKeys"] = [{"symbol": ".", "terrain": lib.key_of(ground)}]
	var la := LevelAsset.new()
	la.name = "Probe road"
	var problems := []
	ContentSerializer.load_into(la, level_json, lib, problems, "probe road")
	var level: LevelDef = conv.level(la)
	if level == null:
		probe.warnings.append("probe road: the level did not build (%s)" % ", ".join(problems))
		return
	if base_asset != null:
		var b := BaseDef.new()
		b.tile = Vector2i(8, 1)
		b.entity = conv.entity(base_asset)
		level.bases.append(b)
	var dummy := EntityDef.new()
	dummy.name = "probe-dummy"
	dummy.display_name = "Dummy"
	dummy.base_stats = {"MaxHp": 100.0, "Initiative": 0.0}
	var su := []
	if player_side:
		su.append([def, Vector2i(3, 2), StartingSide.Ally, -1])
		su.append([dummy, Vector2i(2, 1), StartingSide.Enemy, 0])
		su.append([dummy, Vector2i(5, 1), StartingSide.Enemy, 0])
	else:
		su.append([def, Vector2i(0, 1), StartingSide.Enemy, 0])
		dummy.footing = Footing.OffPath
		su.append([dummy, Vector2i(3, 2), StartingSide.Ally, -1])
	for x in su:
		var u := StartingUnitDef.new()
		u.entity = x[0]; u.tile = x[1]; u.side = x[2]; u.path = x[3]
		level.starting_units.append(u)
	var sess := LevelSession.new(level, rules, [], SEED)
	sess.start()
	var me: Entity = null
	for e in sess.state.entities:
		if e.def == def: me = e
	if me == null:
		probe.warnings.append("probe road: the unit could not be placed (footing %s on %s)" % [Footing.name_of(def.footing), "a build tile" if player_side else "the road"])
		return
	probe.lines.append("probe road: 9 × 3, road along the middle to a base at (8, 1); the unit %s at %s" % ["beside the road" if player_side else "on the road", Dirs.pos_str(me.pos)])
	var rows := []
	var from := sess.log.events.size()
	for rnd in range(1, UNIT_ROUNDS + 1):
		if sess.is_over: break
		var casts := PackedStringArray()
		if player_side:
			for ab in me.abilities.duplicate():
				if not me.alive or sess.is_over: break
				if ab.targeting.is_movement or not sess.can_cast(me, ab): continue
				var aim = Instinct.quick_cast(sess.state, me, ab)
				if aim == null: continue
				sess.cast(me, ab, aim)
		var n0 := sess.log.events.size()
		if not sess.is_over: sess.end_round()
		for i in range(from, sess.log.events.size()):
			var e: GameEvent = sess.log.events[i]
			if e.type == GameEventType.AbilityDeclared and e.source == me.id: casts.append(str(e.detail))
		from = sess.log.events.size()
		var others := PackedStringArray()
		for e in sess.state.entities:
			if e == me or e.is_environment or not e.has_hp: continue
			others.append("%s %d" % [e.name, e.hp] if e.alive else "%s dead" % e.name)
		rows.append([str(rnd), Dirs.pos_str(me.pos) if me.on_board else "-", str(me.hp) if me.alive else "dead", _status_text(me),
			", ".join(casts) if not casts.is_empty() else "-", ", ".join(others)])
		if not me.alive: break
	probe.tables.append({"title": "%d round(s) on the probe road" % UNIT_ROUNDS, "columns": ["round", "position", "HP", "statuses", "cast", "others (HP)"], "rows": rows})
	if sess.is_over: probe.lines.append("the probe road ended: " + Outcome.name_of(sess.outcome))
	var cast_any := false
	for row in rows:
		if row[4] != "-": cast_any = true
	if not cast_any: probe.warnings.append("cast nothing in %d rounds on the probe road" % UNIT_ROUNDS)

# ------------------------------------------------------------------ Tower

func _probe_tower(asset: TowerAsset, tt, probe: Dictionary) -> void:
	probe.lines.append("%s: id '%s', cost %d, entity %s" % [asset.name, asset.id, asset.cost, lib.key_of(asset.entity) if asset.entity != null else "none"])
	var costs := []
	for t in lib.all_of("TowerAsset"):
		if t != asset: costs.append(t.cost)
	costs.sort()
	if not costs.is_empty():
		probe.lines.append("other towers cost %d–%d (median %d)" % [costs[0], costs[-1], costs[costs.size() / 2]])
		if asset.cost > costs[-1] * 2: probe.warnings.append("costs more than twice the dearest other tower (%d)" % costs[-1])
	if asset.cost <= 0: probe.warnings.append("costs %d energy" % asset.cost)
	var cat := lib.catalog
	var in_types: bool = cat != null and cat.tower_types.has(asset)
	if not in_types: probe.warnings.append("not in the catalog's tower types: players never get it")
	# where it can be used: the levels from where it unlocks (start, tutorial reward or a first-clear reward)
	var levels := []
	var from_here := cat != null and (cat.starting_towers.has(asset) or cat.tutorial_reward == asset)
	var where := "from the start" if from_here else ""
	if cat != null:
		for ch in cat.chapters:
			if ch == null: continue
			for cl in ch.levels:
				if cl == null or cl.level == null: continue
				if from_here: levels.append(cl.level)
				if cl.first_clear_reward == asset:
					from_here = true
					where = "after %s" % lib.key_of(cl.level)
	if where != "": probe.lines.append("unlocks " + where)
	var rows := []
	var never := 0
	for l in levels:
		var fixed: bool = not l.fixed_hand.is_empty()
		var at := -1
		if l.start_energy >= asset.cost: at = 1
		elif l.energy_per_round > 0: at = 1 + int(ceil(float(asset.cost - l.start_energy) / l.energy_per_round))
		if at < 0: never += 1
		rows.append([str(lib.key_of(l)), str(l.start_energy), "+%d" % l.energy_per_round,
			"fixed hand" if fixed and not l.fixed_hand.has(asset) else ("round 1" if at == 1 else ("round %d" % at if at > 0 else "never"))])
	if not rows.is_empty():
		probe.tables.append({"title": "cost %d vs the chapter levels' energy" % asset.cost, "columns": ["level", "start energy", "per round", "affordable from"], "rows": rows})
	if never > 0: probe.warnings.append("unaffordable in %d level(s) (start energy below the cost and no income)" % never)
	if asset.entity != null:
		var def = conv.entity(asset.entity)
		if def != null:
			_describe_entity(def, probe)
			_run_road(def, true, probe)

# ------------------------------------------------------------------ Level

func _probe_level(la: LevelAsset, probe: Dictionary) -> void:
	var level: LevelDef = conv.level(la)
	if level == null:
		probe.warnings.append("the level did not convert")
		return
	var tower_assets: Array = lib.all_of("TowerAsset")
	tower_assets.sort_custom(func(a, b): return a.id < b.id)
	var hand := []
	for t in tower_assets: hand.append(conv.tower(t, "t-" + t.id))
	if la.fixed_hand != null and la.fixed_hand.size() > 0:
		hand = []
		for i in la.fixed_hand.size(): hand.append(conv.tower(la.fixed_hand[i], "fixed-" + str(i)))
	var s := LevelSession.new(level, rules, hand, SEED)
	if s.last_error != "":
		probe.warnings.append(s.last_error)
		return
	var spawns := 0
	for w in level.waves: spawns += w.spawns.size()
	probe.lines.append("%d × %d, %d road(s), %d base(s), %d wave(s) (%d spawns), start energy %d, +%d a round, hand cap %d%s" % [level.width, level.height,
		level.paths.size(), level.bases.size(), level.waves.size(), spawns, level.start_energy, level.energy_per_round, level.hand_cap,
		", fixed hand" if la.fixed_hand.size() > 0 else ""])
	probe.lines.append("golden policy (tools/golden.gd): place every hand tower on the first free build tile it can afford, quick-cast every ability, End round; seed %d, at most %d rounds" % [SEED, LEVEL_ROUNDS])
	var errs_before := errlog.take()
	for e in errs_before: probe.warnings.append("engine: " + e)
	s.start()
	var rows := []
	var rounds := 0
	while not s.is_over and rounds < LEVEL_ROUNDS:
		rounds += 1
		for t in s.hand:
			if s.placed.has(t.id): continue
			var tile = null
			for y in s.state.grid.height:
				if tile != null: break
				for x in s.state.grid.width:
					if s.can_place(t.id, Vector2i(x, y)):
						tile = Vector2i(x, y); break
			if tile != null: s.place(t.id, tile)
			if s.is_over: break
		var casts := 0
		if not s.is_over:
			for unit in s.player_units:
				if not unit.alive: continue
				for ability in unit.abilities.duplicate():
					if ability.targeting.is_movement: continue
					if not s.can_cast(unit, ability): continue
					var aim = Instinct.quick_cast(s.state, unit, ability)
					if aim == null: continue
					s.cast(unit, ability, aim)
					casts += 1
					if s.is_over: break
				if s.is_over: break
		var placed := s.placed.size()
		if not s.is_over: s.end_round()
		var base_hp := PackedStringArray()
		for id in s.bases:
			var b: Entity = s.state.get_entity(id)
			base_hp.append(str(b.hp) if b.alive else "dead")
		var finished := 0
		for w in s.waves:
			if w.finished: finished += 1
		rows.append([str(rounds), str(s.energy), str(placed), str(casts), str(s.enemies.size()), "%d/%d" % [finished, s.waves.size()], ", ".join(base_hp)])
	var finished := 0
	for w in s.waves:
		if w.finished: finished += 1
	var left := s.enemies.size()
	probe.lines.append("result: %s at round %d; %d enemies left, waves finished %d/%d, energy %d, %d events" % [Outcome.name_of(s.outcome),
		s.round, left, finished, s.waves.size(), s.energy, s.log.events.size()])
	probe.tables.append({"title": "golden play, round by round", "columns": ["round", "energy (end)", "towers placed", "casts", "enemies alive", "waves done", "base HP"], "rows": rows})
	var errs := errlog.take()
	probe.lines.append("script errors while playing: %d" % errs.size())
	for e in errs.slice(0, 10): probe.warnings.append("engine: " + e)
	if s.outcome == Outcome.Running: probe.warnings.append("not over after %d rounds (%d enemies left)" % [LEVEL_ROUNDS, left])
	if s.outcome == Outcome.Lost: probe.lines.append("the golden policy loses it (a naive player: not an error)")
	if not s.log.warnings.is_empty(): probe.warnings.append("resolver: " + str(s.log.warnings[0]))

# ------------------------------------------------------------------ Reaction / Passive

## Fires a trigger once around a dummy that holds the rule: returns the formatted events.
func _fire(trigger: int, setup: Callable, probe: Dictionary) -> void:
	var s := _state(9, 9)
	var r := Resolver.new(s)
	var holder: Entity = s.add_unit("Holder", Teams.Player, Vector2i(4, 4), 100, [["Power", 10], ["Potency", 2], ["Range", 3], ["Speed", 2]])
	var foe: Entity = s.add_unit("Foe", Teams.Enemy, Vector2i(5, 4), 100, [["Power", 10], ["Speed", 2]])
	var ally: Entity = s.add_unit("Ally", Teams.Player, Vector2i(4, 5), 100, [["Power", 10]])
	setup.call(holder)
	var before := {}
	for e in s.entities:
		if not e.is_environment: before[e.id] = [e.hp, e.shield, _status_text(e)]
	var from := r.log.events.size()
	var how := ""
	var mark: StatusDef = _mk(StatusDef.new(), {name = "probe-mark", tags = [Tags.Debuff], duration = 2})
	match trigger:
		Trigger.OnTurnStart: r.start_turn(holder); how = "the holder's turn starts"
		Trigger.OnTurnEnd: r.start_turn(holder); r.end_turn(holder); how = "the holder's turn ends"
		Trigger.OnAnyTurnStart: r.start_turn(foe); how = "another unit's turn starts"
		Trigger.OnAnyTurnEnd: r.start_turn(foe); r.end_turn(foe); how = "another unit's turn ends"
		Trigger.OnRoundStart: r.start_round(); how = "a round starts"
		Trigger.OnRoundEnd: r.end_round(); how = "a round ends"
		Trigger.OnHitTaken, Trigger.OnDamageTaken, Trigger.OnTargeted:
			r.cast(foe, _hit_ability("10"), Aim.at(foe.pos, holder.pos)); how = "an adjacent foe hits the holder for 10"
		Trigger.OnAllyHitTaken:
			r.cast(foe, _hit_ability("10"), Aim.at(foe.pos, ally.pos)); how = "a foe hits the holder's ally for 10"
		Trigger.OnDodge:
			foe.base_stats["Exposed"] = 0.0
			holder.base_stats["Evasion"] = 1.0
			var miss: AbilityDef = _hit_ability("10"); miss.steps[0].can_miss = true
			r.cast(foe, miss, Aim.at(foe.pos, holder.pos)); how = "a foe attacks the holder (Evasion 1: it dodges)"
		Trigger.OnHitDealt, Trigger.OnDamageDealt, Trigger.OnCast, Trigger.OnAttackStarted, Trigger.OnAttackEnded, Trigger.OnAbilityEnded:
			r.cast(holder, _hit_ability("10"), Aim.at(holder.pos, foe.pos)); how = "the holder hits the adjacent foe for 10"
		Trigger.OnAllyCast:
			r.cast(ally, _hit_ability("10"), Aim.at(ally.pos, foe.pos)); how = "the holder's ally hits a foe for 10"
		Trigger.OnKill:
			foe.hp = 5
			r.cast(holder, _hit_ability("10"), Aim.at(holder.pos, foe.pos)); how = "the holder kills a 5-HP foe"
		Trigger.OnDeath:
			r.cast(foe, _hit_ability("200"), Aim.at(foe.pos, holder.pos)); how = "a foe kills the holder (200 damage)"
		Trigger.OnHealed:
			holder.hp = 50
			r.cast(ally, _heal_ability("10"), Aim.at(ally.pos, holder.pos)); how = "an ally heals the holder (50 HP) for 10"
		Trigger.OnStatusApplied:
			r.cast(foe, _apply_ability(mark, "1"), Aim.at(foe.pos, holder.pos)); how = "a foe puts a 1-stack debuff on the holder"
		Trigger.OnStatusRemoved:
			r.cast(foe, _apply_ability(mark, "1"), Aim.at(foe.pos, holder.pos))
			from = r.log.events.size()
			var cl: AbilityDef = _mk(AbilityDef.new(), {name = "probe-cleanse", targeting = PatternDef.diamond("20"),
				steps = [_mk(RemoveStatusStep.new(), {by = RemoveBy.Name, status_name = "probe-mark"})]})
			r.cast(ally, cl, Aim.at(ally.pos, holder.pos)); how = "a debuff is removed from the holder"
		Trigger.OnMove, Trigger.OnEnterTile, Trigger.OnCollision:
			var push: AbilityDef = _mk(AbilityDef.new(), {name = "probe-push", targeting = PatternDef.diamond("20"),
				steps = [_mk(PushStep.new(), {distance = "1"})]})
			r.cast(foe, push, Aim.at(foe.pos, holder.pos)); how = "a foe pushes the holder 1 tile"
		_:
			probe.lines.append("trigger %s: not fired by the probe (needs a level: spawns, terrain changes, resurrection)" % Trigger.name_of(trigger))
			return
	var rows := []
	for e in s.entities:
		if e.is_environment or not before.has(e.id): continue
		var b: Array = before[e.id]
		rows.append([e.name, "%d → %d" % [b[0], e.hp], "%d → %d" % [b[1], e.shield], "%s → %s" % [b[2], _status_text(e)]])
	probe.lines.append("%s: %s" % [Trigger.name_of(trigger), how])
	var zero := 0
	for i in range(from, r.log.events.size()):
		var e: GameEvent = r.log.events[i]
		if e.type == GameEventType.DamageDealt and float(e.facts.get("Damage", 0)) == 0.0: zero += 1
	if zero > 0:
		probe.lines.append("  note: %d damage event(s) for 0 here (an amount reading StatusStacks is 0 outside a status)" % zero)
	var lines := _event_lines(s, r.log, from, NOISE)
	for l in lines: probe.lines.append("  " + l)
	probe.tables.append({"title": "%s fired once" % Trigger.name_of(trigger), "columns": ["unit", "HP", "shield", "statuses"], "rows": rows})
	if not r.log.warnings.is_empty(): probe.warnings.append("resolver: " + str(r.log.warnings[0]))

func _probe_reaction(asset: ReactionAsset, def: ReactionDef, probe: Dictionary) -> void:
	probe.lines.append("trigger %s, condition '%s', chance '%s', limit %s, timing %s, %d response step(s)" % [Trigger.name_of(def.trigger),
		asset.condition.expression if asset.condition.expression != null else "", asset.chance.expression, Limit.name_of(def.limit),
		Timing.name_of(def.timing), def.response.size()])
	if def.response.is_empty(): probe.warnings.append("no response steps: it does nothing")
	var holders := PackedStringArray()
	for k in _refs_index.get(lib.key_of(asset), []): holders.append(k)
	_fire(def.trigger, func(h: Entity): h.grant(def), probe)

func _probe_passive(asset: PassiveAsset, def: PassiveDef, probe: Dictionary) -> void:
	probe.lines.append("%s: condition '%s', %d modifier(s), %d reaction(s), %d replacement(s), aura '%s'" % [def.get_display_name(),
		def.condition.expression if def.condition.expression != null else "", def.modifiers.size(), def.reactions.size(), def.replacements.size(),
		def.aura.expression if def.aura.expression != null else ""])
	# its modifiers on a dummy
	if not def.modifiers.is_empty():
		var s := _state()
		var plain: Entity = s.add_unit("Plain", Teams.Player, Vector2i(0, 0), 100, [["Power", 10], ["Range", 3], ["Speed", 2]])
		var holder: Entity = s.add_unit("Holder", Teams.Player, Vector2i(2, 0), 100, [["Power", 10], ["Range", 3], ["Speed", 2]])
		holder.grant(def)
		Resolver.new(s).start_turn(holder)
		var parts := PackedStringArray()
		for m in def.modifiers:
			if m != null and m.target != "":
				parts.append("%s %s → %s" % [m.target, Num.to_str(s.final_stat(plain, m.target)), Num.to_str(s.final_stat(holder, m.target))])
		probe.lines.append("modifiers on a 100-HP dummy (Power 10, Range 3, Speed 2): " + ", ".join(parts))
	var seen := {}
	for rd in def.reactions:
		if rd == null or seen.has(rd.trigger): continue
		seen[rd.trigger] = true
		_fire(rd.trigger, func(h: Entity): h.grant(def), probe)
	if def.modifiers.is_empty() and def.reactions.is_empty() and def.replacements.is_empty() and def.aura.is_empty:
		probe.warnings.append("does nothing: no modifiers, reactions, replacements or aura")

# ------------------------------------------------------------------ Form / Token / Mission

func _probe_form(f: FormAsset, probe: Dictionary) -> void:
	var unlock := PackedStringArray()
	for amt in f.unlock:
		if amt != null: unlock.append("%d × %s" % [amt.amount, lib.key_of(amt.token) if amt.token != null else "?"])
	probe.lines.append("form '%s' of %s%s, entity %s, cost %d, unlock %s" % [f.id, lib.key_of(f.tower) if f.tower != null else "no tower",
		", child of " + str(lib.key_of(f.parent)) if f.parent != null else "", lib.key_of(f.entity) if f.entity != null else "none", f.cost,
		", ".join(unlock) if not unlock.is_empty() else "nothing"])
	for amt in f.unlock:
		if amt == null or amt.token == null: continue
		var drops := false
		for m in lib.all_of("MissionAsset"):
			for d in m.first_win_tokens + m.win_tokens:
				if d != null and d.token == amt.token: drops = true
		if not drops: probe.warnings.append("its unlock token %s drops from no mission: it can never be unlocked" % lib.key_of(amt.token))
	if f.entity != null:
		var def = conv.entity(f.entity)
		if def != null: _describe_entity(def, probe)

func _probe_token(t: TokenAsset, probe: Dictionary) -> void:
	var rows := []
	for m in lib.all_of("MissionAsset"):
		for d in m.first_win_tokens:
			if d != null and d.token == t: rows.append([str(lib.key_of(m)), "first win", str(d.amount)])
		for d in m.win_tokens:
			if d != null and d.token == t: rows.append([str(lib.key_of(m)), "every win", str(d.amount)])
	var needed := []
	for f in lib.all_of("FormAsset"):
		for amt in f.unlock:
			if amt != null and amt.token == t: needed.append("%s (%d)" % [lib.key_of(f), amt.amount])
	probe.tables.append({"title": "dropped by", "columns": ["mission", "when", "amount"], "rows": rows})
	probe.lines.append("needed by: " + (", ".join(needed) if not needed.is_empty() else "no form"))
	if needed.is_empty(): probe.warnings.append("no form needs it")

func _probe_mission(m: MissionAsset, probe: Dictionary) -> void:
	var drops := PackedStringArray()
	for d in m.first_win_tokens:
		if d != null: drops.append("first win %d × %s" % [d.amount, lib.key_of(d.token) if d.token != null else "?"])
	for d in m.win_tokens:
		if d != null: drops.append("every win %d × %s" % [d.amount, lib.key_of(d.token) if d.token != null else "?"])
	probe.lines.append("level %s, mode %s, players %s, %d play(s) a day, drops: %s" % [lib.key_of(m.level) if m.level != null else "none",
		MissionMode.name_of(m.mode), "%d–%d" % [m.players.min, m.players.max] if m.players != null else "?", m.plays_per_day,
		", ".join(drops) if not drops.is_empty() else "nothing"])
	var cat := lib.catalog
	if cat != null and not cat.missions.has(m): probe.lines.append("not on the mission board (catalog missions)")
	if m.level != null:
		_probe_level(m.level, probe)

# ------------------------------------------------------------------ schema

func _schema() -> Dictionary:
	var enums := {}
	for type_name in ContentSerializer.SCHEMA:
		for field in ContentSerializer.SCHEMA[type_name]:
			var d: String = ContentSerializer.SCHEMA[type_name][field]
			d = d.trim_prefix("list:")
			if d.begins_with("enum:"):
				var n := d.substr(5)
				var cls = ContentSerializer.enum_class(n)
				if cls != null: enums[n] = Array(cls.NAMES)
	var stats := []
	var l := ContentLibrary.load_game()
	if l.rules != null:
		var v := ContentCheck.vocabulary_of(l.rules)
		stats = v._stats.keys()
		stats.sort()
	var tags := []
	var consts: Dictionary = load("res://sim/combat/tags.gd").get_script_constant_map()
	for c in consts:
		var val = consts[c]
		if val is String: tags.append(val)
	tags.sort()
	var files := {}
	for t in ContentFiles.FILES: files[t] = ContentFiles.file_of(t)
	return {"schema": ContentSerializer.SCHEMA, "enums": enums, "asset_types": ContentSerializer.ASSET_TYPES, "files": files,
		"stats": stats, "tags": tags}
