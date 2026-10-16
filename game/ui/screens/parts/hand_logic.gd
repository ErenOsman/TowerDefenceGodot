class_name HandLogic
extends RefCounted
## The hand editor's pure rules (no nodes, no autoloads), so they can be tested: what a tower is (roles, delivery and
## the toggle flags, derived from its abilities' tags and steps), the collection's entries, filtering and sorting,
## the hand edits (add, remove, drop on a slot, double-click toggle; never more than TowerCollection.MaxHand) and
## the saved layouts on GameData (switch, rename, keep the active one in step with the hand).
## Every tower is an individual (its own tower ID): two Archers are two entries, never "×2".

## No "Movement" role: every tower walks (Tower Walk), so it would match them all (UI/UX, doc cd1b6a5).
const ROLES := ["Attack", "Spell", "Support", "Control"]
const DELIVERIES := ["Melee", "Projectile", "Lobbed", "Spell"]
## The role chips' dots (the mockup's role colours).
const ROLE_COLORS := {"Attack": Color("#FF7A6B"), "Spell": Color("#C59BFF"), "Support": Color("#7EE08A"),
	"Control": Color("#FFD46B")}
## The cost slider's top: at it the slider means "any".
const COST_ANY := 300
## The cost quick chips: [label, min, max].
const COST_CHIPS := [["≤100", 0, 100], ["≤200", 0, 200], ["200+", 200, COST_ANY]]
const SORTS := ["number", "name", "cost"]
## The Sort dropdown's labels: "Default" sorts by the hidden type number (user, 2026-10-13: never "Number").
const SORT_NAMES := ["Default", "Name", "Cost"]
## Status tags that take control of a unit (Control role).
const CONTROL_TAGS := ["Taunted", "Redirected", "Stunned", "Frozen", "Asleep", "Rooted", "Silenced", "Disarmed"]
## A layout name's longest length.
const NAME_MAX := 24
const FULL_REASON := "Hand full: remove one to add another."

# ------------------------------------------------------------------ what a tower is

## A tower definition's traits from its abilities: {"roles": [...] in ROLES order, "delivery": [...] in DELIVERIES
## order, "move": bool, "heal": bool, "status": bool}.
##  Attack / Spell: an ability carries that tag. Support: it heals or applies a Buff status.
##  Control: it applies a status that takes control (Taunted, Stunned…) or pushes / pulls.
##  Delivery: an ability's Melee / Projectile / Lobbed tag; Spell when a Spell ability has none of those.
##  move: a Movement ability. heal: a heal step. status: it applies a status.
static func traits(def: EntityDef) -> Dictionary:
	var roles := {}
	var deliv := {}
	var move := false
	var heal := false
	var status := false
	if def != null:
		for ab in def.abilities:
			if ab == null: continue
			var tags: Array = ab.tags
			if tags.has(Tags.Attack): roles["Attack"] = true
			if tags.has(Tags.Spell): roles["Spell"] = true
			if tags.has(Tags.Movement):
				move = true
			var own := false
			for d in [Tags.Melee, Tags.Projectile, Tags.Lobbed]:
				if tags.has(d):
					deliv[d] = true
					own = true
			if not own and tags.has(Tags.Spell): deliv["Spell"] = true
			for st in AbilityText.all_steps(ab.steps):
				if st is HealStep:
					heal = true
					roles["Support"] = true
				elif st is ApplyStatusStep:
					status = true
					var stags: Array = (st.status.tags if st.status != null else []) + st.add_tags
					if stags.has(Tags.Buff): roles["Support"] = true
					for t in CONTROL_TAGS:
						if stags.has(t): roles["Control"] = true
				elif st is PushStep:
					roles["Control"] = true
	var r := []
	for x in ROLES:
		if roles.has(x): r.append(x)
	var dl := []
	for x in DELIVERIES:
		if deliv.has(x): dl.append(x)
	return {"roles": r, "delivery": dl, "move": move, "heal": heal, "status": status}

## One entry per owned tower, in collection order: {id, type_id, type (TowerAsset or null), def (EntityDef or null),
## number (the type's number), name, cost, index (1-based place in the collection: "tower 3"), roles, delivery, move,
## heal, status}, plus the Workshop form: form (FormAsset or null), base_name (the type's name), badge (the form's
## badge sprite path or ""), description (the form's, else the type's). A formed tower is its form: its entity,
## cost, traits and name ("Fire Archer"). convert may be null (no traits then).
static func entries(towers: TowerCollection, catalog: GameCatalogAsset, convert: AssetConverter) -> Array:
	var out := []
	var cache := {}
	for i in towers.towers.size():
		var o: OwnedTower = towers.towers[i]
		var type: TowerAsset = catalog.find_tower(o.type) if catalog != null else null
		var form := MenuLogic.form_in(o, type)
		var key := o.type + "@" + (form.get_id() if form != null else "")
		if not cache.has(key):
			var ea: EntityAsset = form.entity if form != null and form.entity != null else (type.entity if type != null else null)
			var def: EntityDef = convert.entity(ea) if convert != null and ea != null else null
			cache[key] = [def, traits(def)]
		var desc := ""
		if form != null: desc = form.description
		if desc == "" and type != null: desc = type.description
		if desc == "" and type != null and type.entity != null: desc = type.entity.description
		var cost: int = type.cost if type != null else 0
		if form != null and form.cost >= 0: cost = form.cost
		var e := {"id": o.id, "type_id": o.type, "type": type, "def": cache[key][0],
			"number": type.number if type != null else 9999, "name": MenuLogic.tower_name(o, type),
			"cost": cost, "index": i + 1, "form": form,
			"base_name": type.get_display_name() if type != null else "", "badge": MenuLogic.form_badge(form),
			"description": desc,
			# Upgrades — Design: the level its current form fights at (the Lv chip; shown only once the Blacksmith is open)
			"level": TowerLevels.level_of(o, form.get_id() if form != null else "")}
		e.merge(cache[key][1])
		out.append(e)
	return out

# ------------------------------------------------------------------ filter and sort

static func default_filter() -> Dictionary:
	return {"q": "", "roles": [], "delivery": [], "cost_min": 0, "cost_max": COST_ANY,
		"move": false, "heal": false, "status": false, "hide": false}

## Whether any filter is set (Clear filters shows).
static func filter_active(f: Dictionary) -> bool:
	return str(f.q).strip_edges() != "" or not f.roles.is_empty() or not f.delivery.is_empty() or f.cost_min > 0 \
		or f.cost_max < COST_ANY or f.move or f.heal or f.status or f.hide

## Whether an entry passes the filter: the name (or a formed tower's base type name) contains the search (any case); any picked role; any picked
## delivery; the cost in [cost_min, cost_max] (cost_max at COST_ANY = no top); each toggle on requires its flag;
## Hide my hand leaves out the hand's towers.
static func matches(e: Dictionary, f: Dictionary, hand: Array) -> bool:
	var q := str(f.q).strip_edges().to_lower()
	if q != "" and not str(e.name).to_lower().contains(q) and not str(e.get("base_name", "")).to_lower().contains(q): return false
	if not f.roles.is_empty() and not _any(e.roles, f.roles): return false
	if not f.delivery.is_empty() and not _any(e.delivery, f.delivery): return false
	if e.cost < f.cost_min: return false
	if f.cost_max < COST_ANY and e.cost > f.cost_max: return false
	if f.move and not e.move: return false
	if f.heal and not e.heal: return false
	if f.status and not e.status: return false
	if f.hide and hand.has(e.id): return false
	return true

static func _any(have: Array, want: Array) -> bool:
	for w in want:
		if have.has(w): return true
	return false

## Sorts in place: "number" (the release order, default; ties in collection order), "name", "cost" (ties by number,
## then name, then the collection index) (a total order: sort_custom is not stable).
static func sort_entries(list: Array, by: String) -> Array:
	list.sort_custom(func(a, b):
		var ka := _key(a, by)
		var kb := _key(b, by)
		for i in ka.size():
			if ka[i] != kb[i]: return ka[i] < kb[i]
		return false)
	return list

static func _key(e: Dictionary, by: String) -> Array:
	var n := str(e.name).to_lower()
	match by:
		"name": return [n, e.number, e.index]
		"cost": return [e.cost, e.number, n, e.index]
	return [e.number, e.index] # Default: the type's number, then the collection order (a formed or renamed tower stays put)

## The entries the grid shows: filtered, then sorted.
static func visible(all: Array, f: Dictionary, hand: Array, by := "number") -> Array:
	var out := []
	for e in all:
		if matches(e, f, hand): out.append(e)
	return sort_entries(out, by)

## "37 towers" or "12 of 37 towers".
static func count_text(shown: int, total: int) -> String:
	var unit := "tower" if total == 1 else "towers"
	return "%d %s" % [total, unit] if shown == total else "%d of %d %s" % [shown, total, unit]

## The cost heading's value: "any", "≤ 200", "200+".
static func cost_text(f: Dictionary) -> String:
	if f.cost_max >= COST_ANY: return "any" if f.cost_min <= 0 else "%d+" % f.cost_min
	return "≤ %d" % f.cost_max if f.cost_min <= 0 else "%d–%d" % [f.cost_min, f.cost_max]

## Picks a quick chip (or clears it when it was the one on).
static func toggle_cost_chip(f: Dictionary, chip: int) -> void:
	var c: Array = COST_CHIPS[chip]
	if f.cost_min == c[1] and f.cost_max == c[2]:
		f.cost_min = 0
		f.cost_max = COST_ANY
	else:
		f.cost_min = c[1]
		f.cost_max = c[2]

## Adds or removes a value of a list filter (roles, delivery).
static func toggle_in(list: Array, v: String) -> void:
	if list.has(v): list.erase(v)
	else: list.append(v)

# ------------------------------------------------------------------ the hand

## Why a tower cannot be added ("" when it can).
static func add_reason(towers: TowerCollection, id: String) -> String:
	if towers.hand.has(id): return ""
	if towers.find(id) == null: return "Not owned"
	if towers.hand.size() >= TowerCollection.MaxHand: return FULL_REASON
	return ""

## Adds a tower at the end of the hand (first empty slot). False when it cannot (full, not owned, already in).
static func add(towers: TowerCollection, id: String) -> bool:
	if not towers.can_add_to_hand(id): return false
	return towers.add_to_hand(id)

static func remove(towers: TowerCollection, id: String) -> bool:
	if not towers.hand.has(id): return false
	towers.remove_from_hand(id)
	return true

## Double-click: in the hand → out; else in (when there is room). True when the hand changed.
static func toggle(towers: TowerCollection, id: String) -> bool:
	if towers.hand.has(id): return remove(towers, id)
	return add(towers, id)

## A tower dropped on hand slot `slot` (0-based; the slots are 8, filled ones first): one already in the hand moves
## there (the others shift, the key follows); another onto a filled slot replaces that tower (it goes back to the
## collection); onto an empty slot it goes to the first empty one. True when the hand changed.
static func drop_on_slot(towers: TowerCollection, id: String, slot: int) -> bool:
	if towers.find(id) == null: return false
	var at := towers.hand.find(id)
	if at >= 0:
		var to := clampi(slot, 0, towers.hand.size() - 1)
		if to == at: return false
		towers.move_in_hand(id, to)
		return true
	if slot >= 0 and slot < towers.hand.size():
		towers.hand[slot] = id
		return true
	return add(towers, id)

# ------------------------------------------------------------------ layouts (GameData.hand_layouts)

## Keeps the active layout equal to the hand (call after every hand edit; GameData.to_dict does it too).
static func sync_layout(data: GameData) -> void:
	data.ensure_layouts()

## Makes layout i the active one: the hand is saved into the current layout, then layout i's towers (the ones still
## owned, each once, at most MaxHand) become the hand. True when the active layout changed.
static func switch_layout(data: GameData, i: int) -> bool:
	data.ensure_layouts()
	if i < 0 or i >= data.hand_layouts.size() or i == data.active_layout: return false
	data.hand_layouts[data.active_layout].hand = data.towers.hand.duplicate()
	data.active_layout = i
	var hand := []
	for id in data.hand_layouts[i].hand:
		if hand.size() >= TowerCollection.MaxHand: break
		if data.towers.find(id) != null and not hand.has(id): hand.append(id)
	data.towers.hand = hand
	data.hand_layouts[i].hand = hand.duplicate()
	return true

## Renames layout i (trimmed, at most NAME_MAX characters; an empty name keeps the old one). True when it changed.
static func rename_layout(data: GameData, i: int, name: String) -> bool:
	data.ensure_layouts()
	if i < 0 or i >= data.hand_layouts.size(): return false
	var n := clean_name(name)
	if n == "" or n == data.hand_layouts[i].name: return false
	data.hand_layouts[i].name = n
	return true

static func clean_name(name: String) -> String:
	return name.strip_edges().substr(0, NAME_MAX).strip_edges()

## "4/8" for a layout.
static func layout_count(hand: Array) -> String:
	return "%d/%d" % [hand.size(), TowerCollection.MaxHand]

# ------------------------------------------------------------------ detail texts

## The detail card's stat tiles: up to `count` of Max HP, Power, Range, Speed, then Potency, Duration, Radius (the ones
## the tower has; no cap: extra stats add rows to the 2-column grid). Array of [stat, label, value text].
static func stat_tiles(me: IEntity, vocab: Vocabulary, count := 99) -> Array:
	var out := []
	if me == null or vocab == null: return out
	for s in ["MaxHp", "Power", "Range", "Speed", "Potency", "Duration", "Radius"]:
		if out.size() >= count: break
		var v = null
		if s == "MaxHp":
			var hp := me.stat("MaxHp")
			v = hp if hp > 0 else null
		elif s == "Speed": v = AbilityText.speed(me, vocab)
		else: v = AbilityText.own_stat(me, s, vocab)
		if v != null: out.append([s, "Max HP" if s == "MaxHp" else s, num_text(v)])
	return out

static func num_text(v) -> String:
	var f := float(v)
	return str(int(f)) if is_equal_approx(f, roundf(f)) else str(snappedf(f, 0.01))

## An ability row's subtitle: its tags, the delivery in lower case ("Attack · projectile · 1 turn CD").
static func ability_subtitle(tags: Array, cooldown: int, until_reset: bool) -> String:
	var parts := PackedStringArray()
	for t in tags:
		if t in [Tags.Fire, Tags.Poison]: continue
		parts.append(str(t).to_lower() if t in [Tags.Melee, Tags.Projectile, Tags.Lobbed, Tags.Beam] or (t == Tags.Spell and tags.has(Tags.Attack)) else str(t))
	parts.append("CD until reset" if until_reset else "%d turn CD" % maxi(1, cooldown))
	return " · ".join(parts)

## An ability's type words ("Attack · Projectile"); an ability without tags is named from what it does: a status
## that controls (taunt, stun, root…) → "Control", healing → "Support", a move → "Movement". (Shared with the Codex.)
static func ability_kind(ab: AbilityDef) -> String:
	if not ab.tags.is_empty(): return " · ".join(PackedStringArray(ab.tags))
	for st in AbilityText.all_steps(ab.steps):
		if st is ApplyStatusStep and st.status != null:
			for t in st.status.tags:
				if t in [Tags.Taunted, Tags.Stunned, Tags.Rooted] or Tags.PreventActing.has(t): return "Control"
		if st is HealStep: return "Support"
		if st is JumpStep or st is TeleportStep or st is WalkStep: return "Movement"
	return ""

## "#1 · tower 3".
static func number_text(e: Dictionary) -> String:
	return "#%d · tower %d" % [e.number, e.index]

## The note at the level's cap ("Two Roads takes the first 4"); "" without a level.
static func cap_note(level_name: String, cap: int) -> String:
	if level_name == "" or cap <= 0: return ""
	return "%s takes the first %d" % [level_name, cap]
