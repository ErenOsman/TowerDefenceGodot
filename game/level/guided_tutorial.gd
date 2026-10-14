class_name GuidedTutorial
extends RefCounted
## The guided ("babysitting") tutorial of the catalog's tutorial level (Godot-only; the Unity build plays the
## tutorial as a plain SequenceRun). Owned by the LevelController while the tutorial level plays; reads
## res://data/tutorial.json: lines in the Sequences.json line format plus
##   allow   — the only actions the player may take while the line shows (tokens below; [] = talk only)
##   advance — "click" | "seconds:<s>" | "event:<placing|placed|selected|aiming|cast|round_ended|in_range|won>"
## Allow tokens: "piece:<tower type id>", "tile:x,y" (a placement tile), "select:archer" (the player's first tower),
## "ability:<ability id>", "aim_tile:x,y", "aim_tile:toward_enemy:<n>" (n tiles from the archer along its row toward
## the first enemy, the nearest valid aim when that one is not), "aim_unit:first_enemy", "aim_unit:enemy",
## "end_turn", "end_turn:until_castable" (End turn only while the line's ability has no enemy to hit), "quick_cast",
## "all". What a step needs first is allowed too: the piece while a placement line's tile waits and the tower is not
## being placed; the archer while an ability line's tower is not selected.
##
## The HUD shows `run` (a SequenceRun whose index this class sets; it never ticks it) through controller.sequence in
## the dialogue box (HudSequence) and asks display_line() where to ring (one ring per line) and action_note() for the
## box's note ("Click the Archer piece"); a refused action calls host.refuse(text) with what was wrong ("Not now: click
## the slime first.") and bumps `refusals` (the HUD shakes the ringed target and shows the text in the note's place).
## An optional per-line "hint" replaces that text.
## Never changes the game itself except clearing the selection when a line asks the player to select.

const PATH := "res://data/tutorial.json"

## A refused action (the HUD shakes what is ringed): the hint shown.
signal refused(hint: String)

## The LevelController (duck-typed: session, selected, placing, aiming, director, select(), refuse()).
var host
## Per line: {line: SequenceLine, allow: Array, advance: String, seconds: float, hint: String}.
var steps: Array = []
## What the HUD reads (controller.sequence while the tutorial runs).
var run: SequenceRun
var finished := false
## Counts refused actions (the HUD shakes on a change).
var refusals := 0
var last_hint := ""

var _seen := {}
var _shown_for := 0.0
var _display_key := ""
var _quick_click := "Shift-click"

## Loads the lines (null when the file is missing or empty). `fill` turns a line's text into what is shown
## ({player}, {key:Id}, {click:Id}); null = a plain fallback.
static func load_file(p_host, path: String = PATH, fill = null) -> GuidedTutorial:
	if not FileAccess.file_exists(path): return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or not (data.get("lines") is Array) or data.lines.is_empty(): return null
	return GuidedTutorial.new(p_host, data.lines, fill)

func _init(p_host, lines: Array, fill = null) -> void:
	host = p_host
	var shown := []
	_quick_click = fill.call("{click:QuickCast}") if fill is Callable and fill.is_valid() else "Shift-click"
	for d in lines:
		if not (d is Dictionary): continue
		var text: String = str(d.get("text", ""))
		text = fill.call(text) if fill is Callable and fill.is_valid() else GuidedTutorial.plain_fill(text)
		var advance: String = str(d.get("advance", "click"))
		var l := SequenceLine.new()
		l.speaker = maxi(0, SequenceSpeaker.parse(str(d.get("speaker", "Princess"))))
		l.text = text
		l.point_at = maxi(0, SequencePointAt.parse(str(d.get("pointAt", "Nothing"))))
		l.tile_x = int(d.get("tileX", 0))
		l.tile_y = int(d.get("tileY", 0))
		l.ui_element = str(d.get("uiElement", ""))
		var seconds := 3.0
		if advance == "click": l.continue_on = SequenceContinue.Click
		elif advance.begins_with("seconds:"):
			l.continue_on = SequenceContinue.Seconds
			seconds = float(advance.trim_prefix("seconds:"))
		else: l.continue_on = SequenceContinue.Event
		l.seconds = seconds
		var wait := SequenceEvent.parse(str(d.get("waitFor", "")))
		l.wait_for = wait if wait >= 0 else SequenceEvent.TowerPlaced
		l.pauses_play = l.continue_on != SequenceContinue.Event
		var allow: Array = []
		for t in d.get("allow", []): allow.append(str(t))
		var hint: String = str(d.get("hint", ""))
		steps.append({"line": l, "allow": allow, "advance": advance, "seconds": seconds, "hint": hint})
		shown.append(l)
	run = SequenceRun.new(shown)
	if steps.is_empty(): finished = true
	else: _enter()

## {click:Id} → "Shift-click" ("click" mid-sentence would read oddly too), {key:Id} → Id, {player} → the default name.
static func plain_fill(text: String) -> String:
	var re := RegEx.new()
	re.compile("\\{click:(\\w+)\\}")
	text = re.sub(text, "Shift-click", true)
	re.compile("\\{key:(\\w+)\\}")
	text = re.sub(text, "$1", true)
	return text.replace("{player}", PlayerProfile.DefaultName)

# ------------------------------------------------------------------ state

var index: int:
	get: return run.index if not finished else -1

var step: Dictionary:
	get: return steps[run.index] if not finished and run.index >= 0 and run.index < steps.size() else {}

## The line shows text only (Space / a click goes on): every action waits.
var talking: bool:
	get: return not finished and str(step.get("advance", "")) != "" and not str(step.advance).begins_with("event:")

## The HUD keeps the selection card closed (every line before the free-play one).
var hides_card: bool:
	get: return not finished and not _has("all")

func _has(token: String) -> bool:
	return step.get("allow", []).has(token)

func _tokens(prefix: String) -> Array:
	var out := []
	for t in step.get("allow", []):
		if t.begins_with(prefix): out.append(t.trim_prefix(prefix))
	return out

static func _tile(s: String):
	var parts := s.split(",")
	if parts.size() != 2 or not parts[0].strip_edges().is_valid_int() or not parts[1].strip_edges().is_valid_int(): return null
	return Vector2i(int(parts[0]), int(parts[1]))

## The player's first tower on the board (the archer the lines talk about), or null.
func archer() -> Entity:
	var s: LevelSession = host.session
	if s == null: return null
	for t in s.hand:
		var e := s.placed_tower(t.id)
		if e != null and e.alive: return e
	return null

## The first living enemy on the board, or null.
func first_enemy() -> Entity:
	var s: LevelSession = host.session
	if s == null: return null
	for e in s.enemies:
		if e.alive and e.position != null: return e
	return null

## An ability of the archer by id, or null.
func ability(id: String) -> AbilityDef:
	var a := archer()
	if a == null: return null
	for ab in a.abilities:
		if ab.name == id: return ab
	return null

## The ability the line is about (its first ability: token), or null.
func line_ability() -> AbilityDef:
	var ids := _tokens("ability:")
	return ability(ids[0]) if ids.size() > 0 else null

## The archer's ability `a` could hit an enemy now (the first enemy when only_first).
func can_hit(a: AbilityDef, only_first: bool) -> bool:
	var me := archer()
	if me == null or a == null: return false
	var s: LevelSession = host.session
	var want := first_enemy()
	for aim in Targeting.valid_aims(s.state, me.id, a):
		var t: Entity = Instinct.target_of(s.state, a, aim)
		if t == null or not t.alive or not s.enemies.has(t): continue
		if not only_first or t == want: return true
	return false

## The first enemy is within the archer's Shoot range (its first attack).
func enemy_in_range() -> bool:
	var me := archer()
	if me == null: return false
	for a in me.abilities:
		if a.tags.has(Tags.Attack): return can_hit(a, true)
	return false

## The tile "aim_tile:toward_enemy:<n>" names: n tiles from the archer along its row toward the first enemy (left when
## there is none); when that is not a valid aim of the walk, the valid aim nearest to it (same row first). Null
## when the archer is not on the board.
func walk_tile(n: int = 2):
	var me := archer()
	if me == null or me.position == null: return null
	var foe := first_enemy()
	var dir := -1
	if foe != null and foe.position != null and foe.pos.x != me.pos.x: dir = signi(foe.pos.x - me.pos.x)
	var want := me.pos + Vector2i(dir * n, 0)
	var walk: AbilityDef = null
	for a in me.abilities:
		if a.targeting.is_movement: walk = a
	if walk == null: return want
	var aims: Array = Targeting.valid_aims(host.session.state, me.id, walk)
	var best = null
	var best_score := 1 << 30
	for aim in aims:
		var t: Vector2i = aim.tile
		if t == want: return want
		var score := (absi(t.x - want.x) + absi(t.y - want.y)) * 10 + (0 if t.y == want.y else 5)
		if score < best_score:
			best_score = score
			best = t
	return best if best != null else want

## The aim tiles the line allows (aim_tile tokens resolved), [] when it names none.
func aim_tiles() -> Array:
	var out := []
	for t in _tokens("aim_tile:"):
		if t.begins_with("toward_enemy:"):
			var w = walk_tile(int(t.trim_prefix("toward_enemy:")))
			if w != null: out.append(w)
		else:
			var p = _tile(t)
			if p != null: out.append(p)
	return out

## The placement tiles the line allows.
func place_tiles() -> Array:
	var out := []
	for t in _tokens("tile:"):
		var p = _tile(t)
		if p != null: out.append(p)
	return out

func _needs_archer() -> bool:
	return not _tokens("ability:").is_empty() or _has("quick_cast") or not _tokens("aim_").is_empty()

func _archer_selected() -> bool:
	var a := archer()
	return a != null and host.selected == a.id

## End turn is allowed now: "end_turn", or "end_turn:until_castable" while the line's ability can hit no enemy (or
## is not ready).
func _end_turn_ok() -> bool:
	if _has("end_turn"): return true
	if _has("end_turn:until_castable"):
		var a := line_ability()
		var me := archer()
		if a == null or me == null: return true
		return not host.session.can_cast(me, a) or not can_hit(a, false)
	return false

# ------------------------------------------------------------------ the gate

## Whether the player may do this now. kind: "piece" (tower id), "tile" (placement tile), "select" (entity id, -1 =
## clear), "ability" (AbilityDef to aim), "aim" (tile clicked while aiming), "quick_cast" (AbilityDef), "end_turn".
func allows(kind: String, payload = null) -> bool:
	if finished: return true
	if talking: return false
	if _has("all"): return true
	var s: LevelSession = host.session
	match kind:
		"piece":
			var t: TowerDef = s.tower(str(payload)) if s != null else null
			if t == null or t.type == null: return false
			if _tokens("piece:").has(t.type.id): return true
			# a placement line whose placing was cancelled: the piece again
			return not place_tiles().is_empty() and host.placing == null and s.placed_tower(t.id) == null
		"tile":
			return place_tiles().has(payload)
		"select":
			var id := int(payload) if payload != null else -1
			var a := archer()
			if a != null and id == a.id and (_has("select:archer") or _needs_archer()): return true
			return id >= 0 and id == host.selected # selecting what is selected changes nothing
		"ability":
			var ab: AbilityDef = payload
			return ab != null and _tokens("ability:").has(ab.name)
		"aim":
			var aiming: AbilityDef = host.aiming
			if aiming == null or not _tokens("ability:").has(aiming.name): return false
			var tiles := aim_tiles()
			var units := _tokens("aim_unit:")
			if tiles.is_empty() and units.is_empty(): return str(step.get("advance", "")) != "event:aiming" # "click X" lines stop at aiming
			if tiles.has(payload): return true
			var at: Entity = s.state.entity_at(payload) if payload is Vector2i else null
			if at == null or not at.alive: return false
			if units.has("first_enemy") and at == first_enemy(): return true
			if units.has("enemy") and s.enemies.has(at): return true
			return false
		"quick_cast":
			if not _has("quick_cast"): return false
			var ids := _tokens("ability:")
			var qa: AbilityDef = payload
			return ids.is_empty() or (qa != null and ids.has(qa.name))
		"end_turn":
			return _end_turn_ok()
	return false

## What the step needs next, lower case ("click the Archer piece", "place the Archer on a lit tile", "click End
## turn", "Shift-click Shoot", "click your Archer", "click the slime"); "" on a talk line or in free play.
func need_text() -> String:
	if finished or talking or _has("all"): return ""
	var l := display_line()
	match l.point_at:
		SequencePointAt.UI:
			if l.ui_element == "@piece": return "click the %s piece" % _tower_name()
			if l.ui_element == "EndTurnButton": return "click End turn"
			if l.ui_element.begins_with("@ability:"):
				var a := line_ability()
				var verb := _quick_click if _has("quick_cast") else "click"
				return "%s %s" % [verb, a.display_name if a != null else "the ability"]
		SequencePointAt.Tile:
			if not place_tiles().is_empty(): return "place the %s on a lit tile" % _tower_name()
			return "click the lit tile"
		SequencePointAt.FirstTower: return "click your %s" % _tower_name()
		SequencePointAt.FirstEnemy:
			var e := first_enemy()
			return "click the %s" % (e.def.display_name.to_lower() if e != null else "enemy")
	return ""

## The dialogue box's note on an action step: what the player may do now ("Place the Archer on a lit tile"),
## "" on a talk line or in free play.
func action_note() -> String:
	var need := need_text()
	return need.left(1).to_upper() + need.substr(1) if need != "" else ""

## What was wrong, in the Princess's words: "Not now: click the slime first." (what the line needs next); on a talk
## line "Finish this step first." (Guided Tutorial — Design; the HUD shows it in the box's note slot, in place of
## "Click or press Space", never beside it).
func refusal_text() -> String:
	var need := need_text()
	return "Finish this step first." if need == "" else "Not now: %s first." % need

func _tower_name() -> String:
	var a := archer()
	if a != null: return a.def.display_name
	var s: LevelSession = host.session
	return s.hand[0].name if s != null and s.hand.size() > 0 else "tower"

## A refused action: the hint on the hint line (the line's own words, or how a talk line goes on) and a shake.
func refuse() -> void:
	var hint := str(step.get("hint", ""))
	if hint == "": hint = refusal_text()
	last_hint = hint
	refusals += 1
	host.refuse(hint)
	refused.emit(hint)

# ------------------------------------------------------------------ progress

## A game event happened (placing, placed, selected, aiming, cast, round_ended, won).
func notify(event: String) -> void:
	if not finished: _seen[event] = true

## The bubble was clicked or Space pressed: a click line goes on.
func click() -> void:
	if not finished and str(step.get("advance", "")) == "click": _next()

## Ends the guidance (free play from here).
func skip() -> void:
	if finished: return
	finished = true
	run.skip()

## Advances: a timed line after its seconds; an event line once its event came and nothing plays; in_range is
## checked at the player's turn while nothing plays. Ends with the level, or when the archer a line needs is gone.
func tick(dt: float, playback_idle: bool) -> void:
	if finished: return
	var s: LevelSession = host.session
	if s != null and s.is_over:
		if not playback_idle: return
		skip()
		return
	_shown_for += dt
	var adv := str(step.get("advance", ""))
	if adv.begins_with("seconds:"):
		if _shown_for >= float(step.get("seconds", 0.0)): _next()
	elif adv.begins_with("event:") and playback_idle:
		var e := adv.trim_prefix("event:")
		if e == "in_range":
			if s != null and s.phase == Phase.Player and enemy_in_range(): _next()
		elif _seen.has(e): _next()
	if finished: return
	if playback_idle and _needs_archer() and archer() == null and s != null and s.phase == Phase.Player:
		skip() # the archer fell: the steps cannot go on, free play
		return
	_refresh_display()

func _next() -> void:
	_seen = {}
	_shown_for = 0.0
	if run.index + 1 >= steps.size():
		skip()
		return
	run.index += 1
	_enter()
	_bump()

## A line that asks to select the archer starts with nothing selected (placing selects the tower at once).
func _enter() -> void:
	_display_key = ""
	if str(step.get("advance", "")) == "event:selected" and _has("select:archer") and _archer_selected():
		host.select(-1)

func _bump() -> void:
	run.version += 1
	run.line_changed.emit()

# ------------------------------------------------------------------ what the HUD shows

## The line as the HUD shows it now: where it points follows what the step needs next — the piece until placing
## starts, then the first lit tile; the archer until it is selected, then the ability's button until it is aimed,
## then its target; End turn while "end_turn:until_castable" is the way on.
func display_line() -> SequenceLine:
	if finished: return null
	var base: SequenceLine = step.line
	var out := base.with_text(base.text)
	for k in ["speaker", "continue_on", "wait_for", "pauses_play", "seconds"]: out.set(k, base.get(k))
	if talking: return out
	var tiles := place_tiles()
	if not tiles.is_empty():
		if host.placing == null:
			out.point_at = SequencePointAt.UI
			out.ui_element = "@piece"
		else:
			out.point_at = SequencePointAt.Tile
			out.tile_x = tiles[0].x
			out.tile_y = tiles[0].y
		return out
	if _needs_archer():
		var a := line_ability()
		if _has("end_turn:until_castable") and _end_turn_ok():
			out.point_at = SequencePointAt.UI
			out.ui_element = "EndTurnButton"
		elif not _archer_selected():
			out.point_at = SequencePointAt.FirstTower
		elif a != null and host.aiming != a:
			out.point_at = SequencePointAt.UI
			out.ui_element = "@ability:" + ("move" if a.targeting.is_movement else "attack")
		elif a != null:
			var aims := aim_tiles()
			if not aims.is_empty():
				out.point_at = SequencePointAt.Tile
				out.tile_x = aims[0].x
				out.tile_y = aims[0].y
			else:
				out.point_at = SequencePointAt.FirstEnemy
	return out

## Changes whenever display_line() would point somewhere else (the HUD redraws on run.version).
func _refresh_display() -> void:
	var l := display_line()
	if l == null: return
	var key := "%d|%s|%d,%d" % [l.point_at, l.ui_element, l.tile_x, l.tile_y]
	if key != _display_key:
		var first := _display_key == ""
		_display_key = key
		if not first: _bump()
