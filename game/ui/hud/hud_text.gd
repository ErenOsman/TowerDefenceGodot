class_name HudText
extends RefCounted
## The battle HUD's words and small rules, pure (no nodes): phase names, wave text, base HP warning, the hand
## piece's "not enough energy" lines, the action bar's ready count and refusals, ability row states, stat tiles
## (EntityText.StatTiles), status descriptions with their placeholders filled, the end screen's summary, and the
## sequence hint ("Click to hide. Goes on when …"). Ports of the Unity EntityText / UI_LevelTopBar / UI_EndScreen /
## UI_SequenceBubble text.

## The stats a unit shows after Max HP, in this order (Speed only when the unit has it).
const SHOWN_STATS := ["Power", "Potency", "Duration", "Speed", "Range", "Radius"]

## A number as players read it: whole values without decimals ("10", "2.5").
static func num(v) -> String:
	if v == null: return ""
	var f := float(v)
	if is_equal_approx(f, roundf(f)): return str(int(roundf(f)))
	return str(snappedf(f, 0.01))

# ------------------------------------------------------------------ top bar

static func phase_name(phase: int, outcome: int) -> String:
	if outcome == Outcome.Won: return "Victory"
	if outcome == Outcome.Lost: return "Defeat"
	match phase:
		Phase.Player: return "Your turn"
		Phase.Enemy: return "Enemy turn"
		Phase.Level: return "Level phase"
	return ""

## "1/3": the waves started so far (at least 1) of all; "-" without waves. waves = Array of WaveView.
static func wave_text(waves: Array) -> String:
	if waves.is_empty(): return "-"
	var started := 0
	for w in waves:
		if w.started: started += 1
	return "%d/%d" % [maxi(1, started), waves.size()]

## A wave pip's look: "done" (cleared: on, tinted good), "on" (running, or the first from the start), "off".
static func wave_pip(waves: Array, i: int) -> String:
	var w = waves[i]
	if w.finished: return "done"
	if w.started or i == 0: return "on"
	return "off"

## The base's HP shows red at 30 % of its max or less.
static func base_low(hp: int, max_hp: int) -> bool:
	return max_hp > 0 and hp * 10 <= max_hp * 3

## End turn's label (two lines): "End turn" in your turn (and once the level is over), else "Enemy turn".
static func end_turn_label(phase: int, outcome: int) -> String:
	return "End\nturn" if phase == Phase.Player or outcome != Outcome.Running else "Enemy\nturn"

# ------------------------------------------------------------------ hand

## How much energy a tower still needs (0 when affordable).
static func energy_missing(cost: int, energy: int) -> int:
	return maxi(0, cost - energy)

## The piece's refusal tooltip (hud-menu-spec §6.4): "Needs 180 energy (you have 150)".
static func cost_missing(cost: int, energy: int) -> String:
	return "Needs %d energy (you have %d)" % [cost, energy]

## The hint line's refusal for a piece clicked without the energy: "Cannon needs 280 energy (you have 0)."
static func cost_missing_hint(tower_name: String, cost: int, energy: int) -> String:
	return "%s needs %d energy (you have %d)." % [tower_name, cost, energy]

## The hand tooltip's footer for a piece you cannot afford (beside "280 energy"): "Needs 180 more".
static func shortfall(cost: int, energy: int) -> String:
	return "Needs %d more" % energy_missing(cost, energy)

# ------------------------------------------------------------------ action bar

## The action bar's label while an ability is aimed: "Shoot: pick a target".
static func aiming_label(ability_name: String) -> String:
	return "%s: pick a target" % ability_name

## How many of the flags are true (abilities castable now).
static func ready_count(castable: Array) -> int:
	var n := 0
	for c in castable:
		if c: n += 1
	return n

## The action bar's second line: "2 ready" for a unit you command, "100 energy" for a hand tower being placed.
static func ready_line(ready: int, placing_cost := -1) -> String:
	return "%d energy" % placing_cost if placing_cost >= 0 else "%d ready" % ready

## Why an ability can't be cast now, for the hint line (UI_ActionBar): "" when it can.
static func ability_refusal(ability_name: String, castable: bool, left: int, held: bool, reason: String) -> String:
	if castable: return ""
	if held: return "%s waits for a reset." % ability_name
	if left > 0: return "%s is ready in %s." % [ability_name, "1 turn" if left == 1 else "%d turns" % left]
	if reason != "": return "%s: %s" % [ability_name, reason]
	return ""

## An ability row's state in the inspector: "Ready", "1 turn", "2 turns", "After a reset".
static func row_state(left: int, held: bool) -> String:
	if held: return "After a reset"
	if left <= 0: return "Ready"
	return "1 turn" if left == 1 else "%d turns" % left

## The ability tooltip's note: "Key 1 · Shift-click for quick cast".
static func key_note(key: String, quick_click: String) -> String:
	var quick := "%s for quick cast" % quick_click
	return "Key %s · %s" % [key, quick] if key != "" else quick

## The icon name in a content icon reference ("Assets/Art/Icons/Abilities/Shoot.png#Shoot" → "Shoot").
static func icon_name(ref: String) -> String:
	if ref == "": return ""
	var i := ref.find("#")
	if i >= 0: return ref.substr(i + 1)
	return ref.get_file().get_basename()

## The unit's model folder in a view path ("Assets/Art/Models/Archer/Archer Blender.prefab" → "Archer"), else "".
static func model_name(view: String) -> String:
	var parts := view.split("/")
	var i := parts.find("Models")
	return parts[i + 1] if i >= 0 and i + 1 < parts.size() else ""

# ------------------------------------------------------------------ inspector

## One stat tile per stat (EntityText.StatTiles): [{stat, label, value, bonus}], Max HP first, then the stats the unit
## has; bonus = "+2" / "-1" against the definition's base, "" when none. self_entity: an Entity or DefStats.
static func stat_tiles(self_entity, def: EntityDef, vocab) -> Array:
	var tiles := []
	if self_entity == null: return tiles
	var bonus := func(stat: String, now: float) -> String:
		if def == null or not def.base_stats.has(stat): return ""
		var b := float(def.base_stats[stat])
		if is_equal_approx(b, now): return ""
		return ("+" if now > b else "") + num(now - b)
	var max_hp := float(self_entity.stat("MaxHp"))
	if max_hp > 0.0: tiles.append({"stat": "MaxHp", "label": "Max HP", "value": num(max_hp), "bonus": bonus.call("MaxHp", max_hp)})
	for stat in SHOWN_STATS:
		var v = AbilityText.speed(self_entity, vocab) if stat == "Speed" else AbilityText.own_stat(self_entity, stat, vocab)
		if v == null: continue
		tiles.append({"stat": stat, "label": stat, "value": num(v), "bonus": bonus.call(stat, float(v))})
	return tiles

## A status description with {stacks}, {stacks*N} and {turns} filled in (bold values; "–" for a permanent {turns}).
static func status_description(description: String, stacks: int, turns_left: int) -> String:
	if description == "": return description
	var re := RegEx.create_from_string("\\{\\s*(stacks|turns)\\s*(?:\\*\\s*(\\d+)\\s*)?\\}")
	var out := ""
	var at := 0
	for m in re.search_all(description.to_lower()):
		out += description.substr(at, m.get_start() - at)
		var is_stacks := m.get_string(1) == "stacks"
		var v := stacks if is_stacks else turns_left
		var shown := "–"
		if is_stacks or v >= 0:
			if m.get_string(2) != "": v *= int(m.get_string(2))
			shown = str(v)
		out += "[b]%s[/b]" % shown
		at = m.get_end()
	return out + description.substr(at)

# ------------------------------------------------------------------ end screen

## "An Archer joined you!" / "A Mage joined you!".
static func joined(tower_name: String) -> String:
	var first := tower_name.substr(0, 1).to_upper()
	return "%s %s joined you!" % ["An" if "AEIOU".contains(first) and first != "" else "A", tower_name]

## A level tower's form name (Workshop): its form's name ("Fire Archer"), else its type's ("Archer"). The custom
## name is TowerDef.name; this is the line under or beside it.
static func form_name(def: TowerDef) -> String:
	if def == null or def.type == null: return ""
	if def.form != null and def.form.name != "": return def.form.name
	return def.type.base.name if def.type.base != null else def.type.name

## A level tower's form badge sprite (res://art/ui/KitB/forms/<form id>.png), "" for the default form or no sprite.
static func badge_path(def: TowerDef) -> String:
	if def == null or def.form == null or def.form.badge == "": return ""
	var p := ArtPaths.kit(def.form.badge)
	return p if p != "" and ResourceLoader.exists(p) else ""

## Workshop drops as one end-screen line: "Rewards: Fire Arrow ×2, Ember Core ×1" ("" for none). drops: {token id:
## amount}; catalog (may be null) gives the names (the id otherwise).
static func rewards_text(drops: Dictionary, catalog: GameCatalogAsset = null) -> String:
	var parts := token_parts(drops, catalog)
	return "" if parts.is_empty() else "Rewards: " + ", ".join(parts)

## {token id: amount} → [[TokenAsset or null, token id, amount], …] in order, amounts > 0 (the end screen's chips).
static func token_rows(amounts: Dictionary, catalog: GameCatalogAsset = null) -> Array:
	var out := []
	for id in amounts:
		if int(amounts[id]) <= 0: continue
		out.append([catalog.find_token(id) if catalog != null else null, str(id), int(amounts[id])])
	return out

## {token id: amount} → ["Fire Arrow ×2", …] in order (names from the catalog's tokens, else the id).
static func token_parts(amounts: Dictionary, catalog: GameCatalogAsset = null) -> Array:
	var parts := []
	for id in amounts:
		if int(amounts[id]) <= 0: continue
		var t: TokenAsset = catalog.find_token(id) if catalog != null else null
		parts.append("%s ×%d" % [t.get_display_name() if t != null else str(id), int(amounts[id])])
	return parts

## The end screen's summary lines (UI_EndScreen).
static func end_summary(won: bool, rounds: int, waves_cleared: int, waves_total: int, base_hp: int, base_max: int,
		towers_lost: int) -> String:
	if won:
		return "Every wave cleared in %d rounds.\nBase: %d / %d HP left  ·  Towers lost: %d" % [rounds, base_hp, base_max, towers_lost]
	return "The base fell in round %d. Waves cleared: %d of %d.\nTowers lost: %d" % [rounds, waves_cleared, waves_total, towers_lost]

# ------------------------------------------------------------------ sequences

## The dialogue box's hint for how a line goes on (UI_SequenceBubble.HowItGoesOn); skip_key = the Skip action's keys.
static func how_it_goes_on(continue_on: int, wait_for: int, skip_key: String) -> String:
	match continue_on:
		SequenceContinue.Click: return "Click or press %s" % skip_key if skip_key != "" else "Click to go on"
		SequenceContinue.Seconds: return ""
	return "Click to hide. Goes on when " + waited(wait_for)

static func waited(e: int) -> String:
	match e:
		SequenceEvent.TowerPlaced: return "you place a tower"
		SequenceEvent.UnitSelected: return "you select a unit"
		SequenceEvent.AbilityCast: return "you use an ability"
		SequenceEvent.QuickCast: return "you quick cast an ability"
		SequenceEvent.RoundEnded: return "you end the round"
		SequenceEvent.WaveCleared: return "the wave is cleared"
		SequenceEvent.LevelWon: return "the level is won"
		SequenceEvent.TowerMoved: return "a tower moves"
		SequenceEvent.EnemyInRange: return "an enemy is in range"
		SequenceEvent.SelectionCleared: return "you close the selection"
		SequenceEvent.WaveArrived: return "the next wave arrives"
	return "you do it"

## The KeyBinds id of the i-th ability key (0-based): "Ability1"…
static func ability_key(index: int) -> String:
	return "Ability%d" % (index + 1)

## A description with stat names written where their value belongs filled in for the caster: "up to Speed tiles"
## → "up to [b]2[/b] tiles" (a stat name mid-sentence after a lowercase word; never at a sentence start).
## values: stat name -> number.
static func fill_stats(description: String, values: Dictionary) -> String:
	if description == "" or values.is_empty(): return description
	var names: PackedStringArray = []
	for k in values: names.append(str(k))
	var re := RegEx.create_from_string("(?<=[a-z,] )(" + "|".join(names) + ")\\b")
	var out := ""
	var at := 0
	for m in re.search_all(description):
		out += description.substr(at, m.get_start() - at) + "[b]%s[/b]" % num(values[m.get_string(1)])
		at = m.get_end()
	return singular_after_one(out + description.substr(at))

## "[b]1[/b] tiles" → "[b]1[/b] tile" (the counted words descriptions use after a filled-in number).
static func singular_after_one(text: String) -> String:
	var re := RegEx.create_from_string("(\\[b\\]1\\[/b\\]\\s+)(tile|turn|round|enemy|hit|target|time|stack)s\\b")
	return re.sub(text, "$1$2", true)

## The caster's stats for fill_stats (the stats it has: Power, Speed, Range…). self_entity: an Entity or DefStats.
static func stat_values(self_entity, vocab) -> Dictionary:
	var out := {}
	if self_entity == null: return out
	for stat in SHOWN_STATS:
		var v = AbilityText.speed(self_entity, vocab) if stat == "Speed" else AbilityText.own_stat(self_entity, stat, vocab)
		if v != null: out[stat] = v
	return out

## A hand piece's key as its tooltip names it: just the badge's number ("1"), never "Ctrl+1" or "(hold Ctrl)"
## (user decision 2026-10-13). The modifier parameter is kept for the call sites.
static func piece_key(key: String, _modifier: String) -> String:
	return key

## Result tags as the Info window names them (doc d013205): a walk's "Move" reads "Range". [[value, name], …].
static func shown_tags(tags: Array) -> Array:
	var out := []
	for t in tags: out.append([t[0], "Range" if str(t[1]) == "Move" else t[1]])
	return out
