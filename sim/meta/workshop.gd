class_name Workshop
extends RefCounted
## The Workshop's rules (Workshop — Design § Rules), engine-free and static: unlocking a tower's forms with tokens,
## picking its current form, what a level builds from a tower, and what a level's result drops. Unlocks belong to the
## individual tower (OwnedTower.forms); tokens live in the TokenWallet. Godot-first (Unity: Game.Meta.Workshop).

## Why the last can_unlock / unlock / set_form said no ("" when it said yes) — the C# `out string reason`.
static var last_reason: String = ""

## Whether a form can be unlocked on this tower now: the form belongs to the tower's type, it is not unlocked yet,
## its parent is unlocked on this tower (none for root children), and every token of its cost is owned.
## Reasons: "Already unlocked", "Needs Fire Archer first", "Needs 1 more Ember Core" (several: "… and 2 more Yew Bow"),
## "Not a form of this tower", "No tower" / "No form".
static func can_unlock(tower: OwnedTower, form: FormDef, wallet: TokenWallet, reason_out = null) -> bool:
	last_reason = _unlock_reason(tower, form, wallet)
	if reason_out is Array:
		reason_out.resize(1)
		reason_out[0] = null if last_reason == "" else last_reason
	return last_reason == ""

static func _unlock_reason(tower: OwnedTower, form: FormDef, wallet: TokenWallet) -> String:
	if tower == null: return "No tower"
	if form == null: return "No form"
	if form.tower != tower.type: return "Not a form of this tower"
	if is_unlocked(tower, form.id): return "Already unlocked"
	if form.parent != null and not is_unlocked(tower, form.parent.id): return "Needs %s first" % form.parent.name
	var short: Dictionary = wallet.missing(form.unlock) if wallet != null else form.unlock.duplicate()
	if not short.is_empty():
		var parts := []
		for id in short: parts.append("%d more %s" % [short[id], form.token_name(id)])
		return "Needs " + " and ".join(parts)
	return ""

## Unlocks a form on the tower: spends its tokens and adds it to the tower's unlocked forms (it does not switch the
## form). False (and last_reason) when can_unlock says no; nothing is spent then.
static func unlock(tower: OwnedTower, form: FormDef, wallet: TokenWallet) -> bool:
	if not can_unlock(tower, form, wallet): return false
	if not wallet.spend(form.unlock):
		last_reason = "Needs more tokens"
		return false
	tower.forms.append(form.id)
	return true

## Whether a form is unlocked on the tower ("" = the default form: always).
static func is_unlocked(tower: OwnedTower, form_id: String) -> bool:
	return tower != null and (form_id == "" or tower.forms.has(form_id))

## Picks the tower's current form: "" (the default) or one of its unlocked forms. Free; false (and last_reason
## "Not unlocked on this tower") otherwise.
static func set_form(tower: OwnedTower, form_id: String) -> bool:
	if tower == null:
		last_reason = "No tower"
		return false
	if not is_unlocked(tower, form_id):
		last_reason = "Not unlocked on this tower"
		return false
	last_reason = ""
	tower.form = form_id
	return true

## The tower's current form in its type, or null for the default (or a form the content no longer has).
static func current_form(tower: OwnedTower, type: TowerType) -> FormDef:
	if tower == null or type == null or tower.form == "": return null
	return type.find_form(tower.form)

## What a level builds for this tower (Workshop — Design § Rules "In a level"): the base type for the default form,
## else a TowerType with the base's id (saves, Codex and co-op key on it) and forms, the form's display name,
## description, entity and energy cost (its own, else the base's), with `form` and `base` set.
## A form id the content no longer has falls back to the base type.
static func resolve(tower: OwnedTower, type: TowerType) -> TowerType:
	return resolve_form(type, current_form(tower, type))

## The type a level builds for a form of a type (null form = the type itself).
static func resolve_form(type: TowerType, form: FormDef) -> TowerType:
	if type == null or form == null: return type
	var base: TowerType = type.base if type.base != null else type
	var t := TowerType.new()
	t.id = base.id
	t.name = form.name if form.name != "" else base.name
	t.description = form.description if form.description != "" else base.description
	t.entity = form.entity if form.entity != null else base.entity
	t.cost = form.cost_or(base.cost)
	t.forms = base.forms
	t.form = form
	t.base = base
	return t

## The tokens a result gives (Workshop — Design § Rules "Tokens", Missions & Guild — Design § Rewards): the source's
## first-win drops once (with the first win: record.wins == 1, record = what LevelProgress.record /
## MissionProgress.record returned), its win drops on every win; nothing on a loss or a quit. source: a MissionDef
## (missions are the token source) or a CatalogEntry (chapter levels carry no drops now). {token id: amount},
## first-win drops first (amounts of the same kind add up).
static func drops(result: LevelResult, record: LevelRecord, source) -> Dictionary:
	var out := {}
	if result == null or not result.won or result.quit or source == null: return out
	if record != null and record.wins == 1:
		for id in source.first_win_tokens: out[id] = int(out.get(id, 0)) + int(source.first_win_tokens[id])
	for id in source.win_tokens: out[id] = int(out.get(id, 0)) + int(source.win_tokens[id])
	return out

## Where a token drops — the Workshop's "Found in: …" (Missions & Guild — Design: missions are the only source).
## source = an Array of MissionDef → the ids of the missions that drop it (first-win or win drop), in board order.
## source = a LevelCatalog (the older screen code) → the LEVEL ids those missions play (catalog.missions, filled
## by GameCatalogAsset.to_catalog) plus any level entry that still lists the token, de-duplicated, in catalog level
## order. New code: MissionBoard.found_in / found_in_text.
static func found_in(token_id: String, source) -> Array:
	var out := []
	if source is Array:
		for m in source:
			if m != null and m.drops_token(token_id): out.append(m.id)
		return out
	if source == null or not (source is LevelCatalog): return out
	var levels := {}
	for m in source.missions:
		if m != null and m.drops_token(token_id): levels[m.level_id] = true
	for e in source.entries:
		if levels.has(e.level_id) or e.first_win_tokens.has(token_id) or e.win_tokens.has(token_id): out.append(e.level_id)
	return out

## The forms of a type the tower can unlock right now (parent unlocked and tokens owned), in content order.
static func unlockable(tower: OwnedTower, type: TowerType, wallet: TokenWallet) -> Array:
	var out := []
	if type == null: return out
	for f in type.forms:
		if can_unlock(tower, f, wallet): out.append(f)
	last_reason = ""
	return out

## Every token a form path costs from the root to this form, for a form not yet reachable: {token id: amount}
## of the forms on the way that this tower has not unlocked (itself included).
static func path_cost(tower: OwnedTower, form: FormDef) -> Dictionary:
	var out := {}
	var f := form
	while f != null:
		if not is_unlocked(tower, f.id):
			for id in f.unlock: out[id] = int(out.get(id, 0)) + int(f.unlock[id])
		f = f.parent
	return out
