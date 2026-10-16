class_name WorkshopLogic
extends RefCounted
## The Workshop screen's pure helpers (Workshop — Design; mockup ~/uiux/mockups/screens-b/js/workshop.js), no nodes
## and no autoloads, so they can be tested: the tree's node ids, states and layout, what the right card compares
## (stat tiles, "+ Burn on hit" tag lines, abilities Changed / Same / New / Gone), the one action and its texts, the
## confirm popup's texts. The rules themselves are Workshop's (sim/meta/workshop.gd).
## A node id is a form id; ROOT ("") is the type's default form.

const ROOT := ""
## The tree's frame (the mockup's 640 × 680 SVG box); positions() are in it.
const TREE_SIZE := Vector2(640, 680)
const ROOT_AT := Vector2(320, 330)
## Root children by how many there are, in FormDef.order: clockwise from 9 o'clock, the top kept for grandchildren
## (mockup: Fire Archer left, Poison Archer right, Longbow below).
const SLOTS := {1: [Vector2(120, 280)], 2: [Vector2(120, 280), Vector2(520, 280)],
	3: [Vector2(120, 280), Vector2(520, 280), Vector2(320, 570)]}
## How far a grandchild sits beyond its parent.
const STEP := 200.0

# ------------------------------------------------------------------ the tree

## Every node id of a type's tree: ROOT, then its forms in content order.
static func node_ids(type: TowerType) -> Array:
	var out := [ROOT]
	if type != null:
		for f in type.forms: out.append(f.id)
	return out

## A node's form (null for ROOT or an unknown id).
static func form_of(type: TowerType, id: String) -> FormDef:
	return type.find_form(id) if type != null and id != ROOT else null

## A node's parent id (ROOT for a root child), null for ROOT itself.
static func parent_id(type: TowerType, id: String) -> Variant:
	if id == ROOT: return null
	var f := form_of(type, id)
	return f.parent.id if f != null and f.parent != null else ROOT

## The ids from the root to a node (ROOT first).
static func path_to(type: TowerType, id: String) -> Array:
	var out := []
	var k = id
	var guard := 0
	while k != null and guard < 16:
		out.push_front(k)
		k = parent_id(type, k)
		guard += 1
	return out

## A node's state for this tower: "current" (its form now), "unlocked", "locked" (the parent is not unlocked),
## "need" (tokens missing) or "can" (Unlock is possible now).
static func node_state(owned: OwnedTower, type: TowerType, id: String, wallet: TokenWallet) -> String:
	if owned == null: return "locked"
	var cur := owned.form if form_of(type, owned.form) != null else ROOT
	if id == cur: return "current"
	if Workshop.is_unlocked(owned, id): return "unlocked"
	var p = parent_id(type, id)
	if p != null and not Workshop.is_unlocked(owned, p): return "locked"
	var f := form_of(type, id)
	if f == null: return "locked"
	return "need" if wallet == null or not wallet.can_afford(f.unlock) else "can"

## The tower's current node id (ROOT when its form is the default or unknown).
static func current_id(owned: OwnedTower, type: TowerType) -> String:
	return owned.form if owned != null and form_of(type, owned.form) != null else ROOT

## Where each node sits in TREE_SIZE: {id: Vector2}. The root in the middle; root children by FormDef.order on
## SLOTS (more than 3: evenly round the root clockwise from 9 o'clock); grandchildren STEP beyond their parent: up
## from a side node (then down), sideways from the bottom one.
static func positions(type: TowerType) -> Dictionary:
	var out := {ROOT: ROOT_AT}
	if type == null: return out
	var kids := _ordered(type.children_of(null))
	for i in kids.size():
		var at: Vector2
		if SLOTS.has(kids.size()): at = SLOTS[kids.size()][i]
		else:
			var a := TAU * i / kids.size()
			at = ROOT_AT + Vector2(-cos(a) * 220.0, -sin(a) * 240.0)
		out[kids[i].id] = at
	# deeper levels, parents first (content order keeps parents before children only by chance: loop by depth)
	for depth in range(2, 4):
		for p in type.forms:
			if p.depth != depth - 1 or not out.has(p.id): continue
			var gk := _ordered(type.children_of(p))
			var pa: Vector2 = out[p.id]
			for j in gk.size():
				var at: Vector2
				if absf(pa.x - ROOT_AT.x) > 40.0: # a side node: up, then down, then further up
					at = pa + Vector2(0, -STEP if j % 2 == 0 else STEP) * (1 + j / 2)
				elif pa.y > ROOT_AT.y: # the bottom node: left, then right
					at = pa + Vector2(-STEP if j % 2 == 0 else STEP, 0) * (1 + j / 2)
				else:
					var d := (pa - ROOT_AT).normalized()
					at = pa + d.rotated(0.5 * (j - (gk.size() - 1) / 2.0)) * STEP
				out[gk[j].id] = at
	return out

static func _ordered(forms: Array) -> Array:
	var list := forms.duplicate()
	var index := {}
	for i in list.size(): index[list[i]] = i
	list.sort_custom(func(a, b): return a.order < b.order or (a.order == b.order and index[a] < index[b]))
	return list

## The node next to `from` in a direction (arrow keys): the nearest one roughly that way; `from` itself when none.
static func neighbour(pos: Dictionary, from: String, dir: Vector2) -> String:
	if not pos.has(from): return from
	var best := from
	var best_score := INF
	var p: Vector2 = pos[from]
	for id in pos:
		if id == from: continue
		var d: Vector2 = pos[id] - p
		var dot := d.normalized().dot(dir.normalized())
		if dot < 0.35: continue
		var score := d.length() * (2.0 - dot)
		if score < best_score:
			best_score = score
			best = id
	return best

# ------------------------------------------------------------------ names and lines

## A node's name: the form's, else the type's ("Archer").
static func name_of(type: TowerType, id: String) -> String:
	var f := form_of(type, id)
	if f != null: return f.name
	return type.name if type != null else ""

## A node's entity (the form's, else the type's).
static func def_of(type: TowerType, id: String) -> EntityDef:
	var f := form_of(type, id)
	if f != null and f.entity != null: return f.entity
	return type.entity if type != null else null

## A node's description (the form's, else the type's, else its entity's).
static func description_of(type: TowerType, id: String) -> String:
	var f := form_of(type, id)
	if f != null and f.description != "": return f.description
	if type != null and type.description != "": return type.description
	var d := def_of(type, id)
	return d.description if d != null else ""

## The card's line under the name: "Base form", "Form of Archer", "Form of Fire Archer" (a child: its parent).
static func subtitle(type: TowerType, id: String) -> String:
	var f := form_of(type, id)
	if f == null: return "Base form"
	return "Form of " + (f.parent.name if f.parent != null else name_of(type, ROOT))

## The picker card's form line: "Default form · 1 of 4 forms unlocked", "Form of Archer · …", "Default form · no
## forms yet" (a type without forms).
static func form_line(owned: OwnedTower, type: TowerType) -> String:
	var cur := current_id(owned, type)
	var head := "Default form" if cur == ROOT else "Form of " + name_of(type, ROOT)
	var n := type.forms.size() if type != null else 0
	if n == 0: return head + " · no forms yet"
	var u := 0
	for f in type.forms:
		if Workshop.is_unlocked(owned, f.id): u += 1
	return "%s · %d of %d forms unlocked" % [head, u, n]

## The card's ⓘ trait lines: what the form does on its own terms (no comparison): every status its abilities
## apply to their target, "Burn on hit", or "Burn around the target" when the ability hits an area; a status from
## a non-attack ability: "Applies Taunted" (content order, each once).
static func trait_lines(def: EntityDef, vocab: Vocabulary) -> Array:
	var out := []
	if def == null: return out
	var me := DefStats.new(def)
	for ab in def.abilities:
		if ab == null: continue
		var area := vocab != null and AbilityText.area(ab, me, vocab) != null
		for st in AbilityText.all_steps(ab.steps):
			if st is ApplyStatusStep and st.status != null and st.on != StepTarget.Self:
				var line := "%s %s" % [st.status.display_name, "around the target" if area else "on hit"]
				if not ab.tags.has(Tags.Attack): line = "Applies " + st.status.display_name # Taunt: "Applies Taunted"
				if not out.has(line): out.append(line)
	return out

## "This tower now" panel's line: "Form: Default" / "Form: Fire Archer".
static func now_line(owned: OwnedTower, type: TowerType) -> String:
	var cur := current_id(owned, type)
	return "Form: " + ("Default" if cur == ROOT else name_of(type, cur))

## "#1 · tower 3".
static func number_text(number: int, index: int) -> String:
	return "#%d · tower %d" % [number, index]

## "Leads to: Inferno Archer" ("" for a leaf).
static func leads_to(type: TowerType, id: String) -> String:
	if type == null: return ""
	var names := []
	for f in _ordered(type.children_of(form_of(type, id))): names.append(f.name)
	return "" if names.is_empty() else "Leads to: " + ", ".join(names)

## A node's hover text (the mockup's title): "Inferno Archer: Unlock Fire Archer first".
static func node_hint(type: TowerType, id: String, state: String) -> String:
	var hint := ""
	match state:
		"locked": hint = "Unlock %s first" % name_of(type, parent_id(type, id))
		"need": hint = "Needs tokens"
		"can": hint = "Can unlock now"
		"current": hint = "Current form"
		_: hint = "Unlocked: free to switch"
	return "%s: %s" % [name_of(type, id), hint]

## A node's cost chip number: "0/1" when short (red), else the amount ("1", with a ✓ beside it).
static func chip_text(have: int, need: int) -> String:
	return "%d/%d" % [have, need] if have < need else str(need)

## "Fire Archer unlocked" (the toast on the card).
static func toast(type: TowerType, id: String) -> String:
	return "%s unlocked" % name_of(type, id)

# ------------------------------------------------------------------ the action

## "1 Fire Arrow", "1 Ember Core + 1 Fire Arrow" (names from the form's tokens).
static func spend_text(form: FormDef) -> String:
	var parts := []
	if form != null:
		for id in form.unlock: parts.append("%d %s" % [int(form.unlock[id]), form.token_name(id)])
	return " + ".join(parts)

## The Unlock button's parts (UI/UX 2026-10-14; never wraps): one token → [[token id, "1 Fire Arrow"]] ("Unlock ·
## [coin] 1 Fire Arrow"); two or more → coins and counts only [[id, "1"], [id, "1"]] (names stay in the cost row).
static func unlock_parts(form: FormDef) -> Array:
	var out := []
	if form == null: return out
	for id in form.unlock:
		var n := int(form.unlock[id])
		out.append([id, "%d %s" % [n, form.token_name(id)] if form.unlock.size() == 1 else str(n)])
	return out

## The card's one action for a node: {kind, text, note, reason}.
##  kind "unlock": text "Unlock · 1 Fire Arrow", no note
##  kind "use": text "Use this form", no note (UI/UX sub-line sweep 2026-10-16: "Unlocks for this …" and "Free: switch
##  back any time" removed)
##  kind "current": a disabled "✓ Current form" button, no note
##  kind "blocked": a disabled "Unlock", reason = Workshop.last_reason + "." ("Needs 1 more Ember Core."; no "Found
##  in": Eren 2026-10-16, the mission's Rewards popup is the one place that lists drops).
static func action(owned: OwnedTower, type: TowerType, id: String, wallet: TokenWallet, _index := 0) -> Dictionary:
	var st := node_state(owned, type, id, wallet)
	match st:
		"current": return {"kind": "current", "text": "Current form", "note": "", "reason": ""}
		"unlocked": return {"kind": "use", "text": "Use this form", "note": "", "reason": ""}
		"can": return {"kind": "unlock", "text": "Unlock · " + spend_text(form_of(type, id)),
			"note": "", "reason": ""}
	var f := form_of(type, id)
	Workshop.can_unlock(owned, f, wallet)
	var reason := Workshop.last_reason + "."
	return {"kind": "blocked", "text": "Unlock", "note": "", "reason": reason}

## The confirm popup's title: "Unlock Fire Archer for this Archer?".
static func confirm_title(type: TowerType, form: FormDef) -> String:
	return "Unlock %s for this %s?" % [form.name if form != null else "", name_of(type, ROOT)]

## Its body: "Spends 1 Fire Arrow (you have 2 → 1). You can switch back to Archer any time." (several tokens:
## "… and 1 Fire Arrow (you have 2 → 1)").
static func confirm_body(type: TowerType, form: FormDef, wallet: TokenWallet) -> String:
	var parts := []
	if form != null:
		for id in form.unlock:
			var have := wallet.count(id) if wallet != null else 0
			var n := int(form.unlock[id])
			parts.append("%d %s (you have %d → %d)" % [n, form.token_name(id), have, have - n])
	return "Spends %s. You can switch back to %s any time." % [" and ".join(parts), name_of(type, ROOT)]

# ------------------------------------------------------------------ the Codex's Forms page (mockup codex2.html)

## The rows of a tower's Codex Forms page: ROOT first, then the forms some owned tower of the type has unlocked
## (content order). Locked forms are not listed (user decision 2026-10-14).
static func codex_form_ids(towers: TowerCollection, type: TowerType) -> Array:
	var out := [ROOT]
	if type == null: return out
	for f in type.forms:
		if anyone_unlocked(towers, type.id, f.id): out.append(f.id)
	return out

## A Forms row's name: the form's ("Fire Archer"), the base row the type's ("Archer").
static func codex_row_name(type: TowerType, id: String) -> String:
	return name_of(type, id)

## A Forms row's second line: "Base form" / "Form of Archer" / "Form of Fire Archer".
static func codex_row_sub(type: TowerType, id: String) -> String:
	return subtitle(type, id)

## Whether any owned tower of a type has a form unlocked (the Codex shows the forms nobody has desaturated).
static func anyone_unlocked(towers: TowerCollection, type_id: String, form_id: String) -> bool:
	if towers == null: return false
	for o in towers.towers:
		if o.type == type_id and o.forms.has(form_id): return true
	return false

## Whether a level sends a boss.
static func is_boss_level(level: LevelAsset) -> bool:
	for pair in MenuLogic.enemy_counts(level):
		if pair[0] != null and pair[0].tags.has(Tags.Boss): return true
	return false
