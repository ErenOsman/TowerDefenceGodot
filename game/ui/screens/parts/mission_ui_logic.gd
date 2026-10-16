class_name MissionUiLogic
extends RefCounted
## The Missions & Guild screens' pure rules and texts (Missions & Guild — Design § The Guild; the UI/UX mockups
## screens-b/guild*.html, mission-board.html, mission-detail*.html, lobby-*-mission / -auto-left / -room-tired,
## hand-select-mission.html, end-screen-mission*.html, camp-signpost*.html). The rules themselves are MissionBoard's
## (sim/meta/mission_board.gd); this class turns them into what a card, a row or a button says. Static, no Nodes;
## `now` is injectable as in MissionBoard (null = the system clock). Tested in tests/test_mission_ui.gd.

## Card / row states.
const Play := "play"     # a play left, solo-playable (Solo / Any): Play
const Room := "room"     # a play left, co-op only: Find a room
const Done := "done"     # no play left today
const Locked := "locked" # its requirement is not met

const StartNote := "Starting uses a play, win or lose."
const BoardTitle := "Missions"
const GuildTitle := "Guild"
const GuildSub := "Missions and co-op"
const WelcomeTitle := "The Guild"
## The first visit's card (guild-welcome.html): the lead line and four rows [icon, bbcode].
const WelcomeLead := "You cleared Chapter 2. The Guild hands out [b]missions[/b]: levels you can play a few times a day."
const WelcomeRows := [
	["flag", "[b]Missions[/b] are the only place to earn [b]tokens[/b]."],
	["token", "[b]Tokens[/b] unlock tower forms in the Camp's [b]Workshop[/b]."],
	["hourglass", "Each mission has [b]plays a day[/b] (usually 1). Starting one uses a play, win or lose. Plays reset at midnight."],
	["users", "Co-op lives here too: every multiplayer level is a mission."],
]
const WelcomeButton := "Got it"
## The Guild's stations (guild.html): {id, label, sub, icon}; Missions is primary, its sub is counted (station_sub).
const Stations := [
	{"id": "Missions", "label": "Missions", "sub": "", "icon": "flag", "primary": true},
	{"id": "Multiplayer", "label": "Multiplayer", "sub": "Co-op rooms (missions only)", "icon": "users"},
	{"id": "Towers", "label": "Towers", "sub": "Your hand and layouts", "icon": "cards"},
	{"id": "Camp", "label": "Camp", "sub": "Back to the Camp", "icon": "back"},
]
const SpendInWorkshop := "Spend them in the Workshop."
const TiredDetail := "Tired: went on a mission today. Rests in %s."

# ------------------------------------------------------------------ chips and lines

## The board / detail mode chip: "Solo", "Co-op 2–6", "Any · solo or 1–4".
static func mode_chip(m: MissionDef) -> String:
	if m == null: return ""
	match m.mode:
		MissionMode.Coop: return "Co-op %d–%d" % [m.min_players, m.max_players]
		MissionMode.Any: return "Any · solo or %d–%d" % [m.min_players, m.max_players]
	return "Solo"

## The short form for rows: "Solo", "Co-op 2–6", "Any 1–4".
static func mode_short(m: MissionDef) -> String:
	if m == null: return ""
	if m.mode == MissionMode.Any: return "Any %d–%d" % [m.min_players, m.max_players]
	return mode_chip(m)

## The board header's line: "Earn tokens for the Workshop · plays reset at midnight (in 5 h)".
static func board_subtitle(now = null) -> String:
	return "Earn tokens for the Workshop · plays reset at midnight (in %s)" % MissionBoard.duration_text(MissionBoard.resets_in(now))

## Under a card's name: the level ("Two Roads"), with the plays a day when more than one ("The Drummer · 2 plays a day").
static func level_line(m: MissionDef, level_name: String) -> String:
	if m != null and m.plays_per_day > 1: return "%s · %d plays a day" % [level_name, m.plays_per_day]
	return level_name

## The detail's kicker after the chip: "plays Two Roads".
static func plays_level(level_name: String) -> String:
	return "plays " + level_name

# ------------------------------------------------------------------ states

## A mission's state for the board: Locked (requirement), Done (no play left), Room (co-op only) or Play.
static func state_of(m: MissionDef, unlocked: bool, mp: MissionProgress, now = null) -> String:
	if m == null or not unlocked: return Locked
	if MissionBoard.plays_left(m, mp, now) <= 0: return Done
	return Play if m.is_solo else Room

## A board card's state line and small button: {state, text, button ("" = none)}.
##   play: "1 play left today" + Play; room: "1 play left today" + Find a room; done: "Done today · resets in 5 h";
##   locked: the lock reason ("Win Hold the Gate first").
static func card_state(m: MissionDef, unlocked: bool, lock_reason: String, mp: MissionProgress, now = null) -> Dictionary:
	var st := state_of(m, unlocked, mp, now)
	match st:
		Locked: return {"state": st, "text": lock_reason, "button": ""}
		Done: return {"state": st, "text": MissionBoard.done_text(now), "button": ""}
		Room: return {"state": st, "text": MissionBoard.plays_text(m, mp, now), "button": "Find a room"}
	return {"state": st, "text": MissionBoard.plays_text(m, mp, now), "button": "Play"}

## The detail's left list line: "1 left today", "2 left today", "Done today", "Co-op · find a room", the lock reason.
static func list_line(m: MissionDef, state: String, lock_reason: String, mp: MissionProgress, now = null) -> String:
	match state:
		Locked: return lock_reason
		Done: return "Done today"
		Room: return "Co-op · find a room"
	return "%d left today" % MissionBoard.plays_left(m, mp, now)

## The detail's primary button: "Play" (Solo / Any) or "Find a room" (co-op only).
static func primary_label(m: MissionDef) -> String:
	return "Play" if m == null or m.is_solo else "Find a room"

## The drop rows: [["Each win", {token: n}], ["First win", {token: n}]], empty lists left out.
static func drop_rows(m: MissionDef) -> Array:
	var out := []
	if m == null: return out
	if not m.win_tokens.is_empty(): out.append(["Each win", m.win_tokens])
	if not m.first_win_tokens.is_empty(): out.append(["First win", m.first_win_tokens])
	return out

## The "Each win / First win" rows with their gold (Backpack — Design; missions are the only gold source):
## [[label, {token id: amount}, gold], …]; a row shows when it drops tokens or gold.
static func reward_rows(m: MissionDef) -> Array:
	var out := []
	if m == null: return out
	if not m.win_tokens.is_empty() or m.win_gold > 0: out.append(["Each win", m.win_tokens, maxi(0, m.win_gold)])
	if not m.first_win_tokens.is_empty() or m.first_win_gold > 0: out.append(["First win", m.first_win_tokens, maxi(0, m.first_win_gold)])
	return out

## The first-win drop was taken already (the mission was won once): shown dimmed with "claimed".
static func first_win_claimed(m: MissionDef, mp: MissionProgress) -> bool:
	return m != null and mp != null and mp.is_won(m.id)

## The pips: [plays left, plays a day].
static func pips(m: MissionDef, mp: MissionProgress, now = null) -> Array:
	return [MissionBoard.plays_left(m, mp, now), maxi(1, m.plays_per_day) if m != null else 1]

## The detail's pips line: "1 of 1 play left today", used up: "0 of 1 play left today · resets in 5 h".
static func pips_text(m: MissionDef, mp: MissionProgress, now = null) -> String:
	var t := MissionBoard.plays_of_text(m, mp, now)
	if MissionBoard.plays_left(m, mp, now) <= 0: t += " · " + MissionBoard.resets_in_text(now)
	return t

## The line over the detail's primary button: {kind, text}; kind "info" (Play can start), "coop" (co-op only),
## "done" (no play left), "warn" (no rested tower / empty hand: Play refused), "lock" (requirement).
## bring_reason: MissionBoard.can_bring's reason for the current hand ("" when it brings a rested tower).
static func detail_note(m: MissionDef, state: String, lock_reason: String, bring_reason: String, now = null) -> Dictionary:
	match state:
		Locked: return {"kind": "lock", "text": lock_reason}
		Done:
			var plays := "today's plays" if m != null and m.plays_per_day > 1 else "today's play"
			return {"kind": "done", "text": "Done today: you used %s. Resets in %s." % [plays, MissionBoard.duration_text(MissionBoard.resets_in(now))]}
		Room:
			return {"kind": "coop", "text": "Co-op only (%d–%d players). Starting the match uses your play." % [m.min_players, m.max_players]}
	if bring_reason != "": return {"kind": "warn", "text": bring_reason + ("" if bring_reason.ends_with(".") else ".")}
	return {"kind": "info", "text": StartNote}

## Whether the detail's primary button works: Play needs a play, a rested tower and a solo-playable mission;
## Find a room needs a play left (the towers are checked at Ready).
static func primary_enabled(state: String, bring_reason: String) -> bool:
	if state == Play: return bring_reason == ""
	return state == Room

# ------------------------------------------------------------------ the hand strip

## Per hand slot (in hand order): {tired, goes}: tired towers stay home; "goes" marks the first rested towers up to
## the cap (the ones the mission takes).
static func hand_marks(hand: Array, mp: MissionProgress, cap: int, now = null) -> Array:
	var taken := MissionBoard.taken(hand, mp, cap, now)
	var out := []
	for t in hand:
		out.append({"tired": MissionBoard.is_tired(MissionBoard._id_of(t), mp, now), "goes": taken.has(t)})
	return out

## Where the cap divider goes (before slot index; -1 = none): after the last tower that goes when the cap is
## filled; when fewer rested towers than the cap are in the hand, after the hand (they all go). Never at 0 or 8.
static func divider_at(hand: Array, mp: MissionProgress, cap: int, now = null, slots := TowerCollection.MaxHand) -> int:
	if cap <= 0: return -1
	var marks := hand_marks(hand, mp, cap, now)
	var goes := 0
	var last := -1
	for i in marks.size():
		if marks[i].goes:
			goes += 1
			last = i
	var at := (last + 1) if goes >= cap else hand.size()
	return at if at > 0 and at < slots else -1

## Whether any of the hand's towers is tired.
static func any_tired(hand: Array, mp: MissionProgress, now = null) -> bool:
	for t in hand:
		if MissionBoard.is_tired(MissionBoard._id_of(t), mp, now): return true
	return false

## The detail's "Your hand" note: with tired towers "Patrol takes the first 4 rested towers; tired ones stay home.";
## co-op only "Three at the Gate takes the first 3 towers (co-op: per player); the rest wait on the bench."; else the
## level select's note ("Two Roads takes the first 4 towers; the rest wait on the bench.").
static func hand_note(m: MissionDef, level_name: String, hand_count: int, cap: int, tired: bool) -> String:
	if hand_count == 0: return MenuLogic.hand_strip_note(level_name, 0, cap)
	if tired: return "%s takes the first %d rested %s; tired ones stay home." % [m.name if m != null else level_name, cap, MenuLogic.plural(cap, "tower")]
	if m != null and not m.is_solo:
		return "%s takes the first %d %s (co-op: per player); the rest wait on the bench." % [level_name, cap, MenuLogic.plural(cap, "tower")]
	return MenuLogic.hand_strip_note(level_name, hand_count, cap)

## The hand editor's divider note when opened for a mission: "Night Watch takes the first 4 rested".
static func editor_cap_note(mission_name: String, cap: int) -> String:
	if mission_name == "" or cap <= 0: return ""
	return "%s takes the first %d rested" % [mission_name, cap]

## The "Tired · rests in 5 h" line under a tired tower (two lines on the small slots).
static func tired_line(now = null, two_lines := true) -> String:
	var t := MissionBoard.tired_text(now)
	return t.replace(" · ", " ·\n") if two_lines else t

## The hand editor card's line for a tired tower: "Tired: went on a mission today. Rests in 5 h."
static func tired_detail(now = null) -> String:
	return TiredDetail % MissionBoard.duration_text(MissionBoard.resets_in(now))

# ------------------------------------------------------------------ the Guild and the Camp

## How many unlocked missions have a play left today (the Missions station's count).
static func to_play_count(missions: Array, progress: LevelProgress, mp: MissionProgress, catalog: GameCatalogAsset, now = null) -> int:
	var n := 0
	for m in missions:
		if m == null: continue
		if MissionBoard.is_unlocked(m, progress, mp, catalog) and MissionBoard.plays_left(m, mp, now) > 0: n += 1
	return n

## The Missions station's sub line: "Today's missions · 3 to play" / "Today's missions · all done".
static func missions_station_sub(to_play: int) -> String:
	return "Today’s missions · " + ("all done" if to_play <= 0 else "%d to play" % to_play)

## The Camp's locked Signpost line under "Missions": "Opens after Chapter 2" (the guildUnlock level's chapter; the
## same words as the locked Workshop).
static func signpost_locked_text(catalog: GameCatalogAsset) -> String:
	if catalog != null and catalog.guild_unlock != null:
		for e in catalog.entries():
			if e[0].level == catalog.guild_unlock: return "Opens after " + MenuLogic.chapter_name(catalog, e[1])
	return "Opens after Chapter 2"

## The Camp's Guild button tag: "New" until the Guild was visited once, else "".
static func signpost_tag(guild_seen: bool) -> String:
	return "" if guild_seen else "New"

# ------------------------------------------------------------------ end screen

## "Mission · Patrol".
static func end_subtitle(m: MissionDef) -> String:
	return "Mission · " + (m.name if m != null else "")

## Under the rewards: "1 play left today" / "Done today: no plays left · resets in 5 h".
static func end_plays_line(m: MissionDef, mp: MissionProgress, now = null) -> String:
	var n := MissionBoard.plays_left(m, mp, now)
	if n <= 0: return "Done today: no plays left · " + MissionBoard.resets_in_text(now)
	return "%d play%s left today" % [n, "" if n == 1 else "s"]

## The end screen's reward groups from what the win gave: [["Rewards", {each-win tokens}, false],
## ["First win", {first-win tokens}, true]] (first-win only when this win took it: first_win = the record's wins == 1).
static func end_reward_groups(m: MissionDef, won: bool, first_win: bool) -> Array:
	var out := []
	if m == null or not won: return out
	if not m.win_tokens.is_empty(): out.append(["Rewards", m.win_tokens, false])
	if first_win and not m.first_win_tokens.is_empty(): out.append(["First win" if not m.win_tokens.is_empty() else "Rewards", m.first_win_tokens, true])
	return out

# ------------------------------------------------------------------ co-op

## A create-room mission row: "1 play left today · Any 1–4" / "Done today · resets in 5 h".
static func picker_line(m: MissionDef, mp: MissionProgress, now = null) -> String:
	if MissionBoard.plays_left(m, mp, now) <= 0: return MissionBoard.done_text(now)
	return "%s · %s" % [MissionBoard.plays_text(m, mp, now), mode_short(m)]

## The create card's plays note: "1 play left today: the match start uses one for everyone."
static func create_plays_note(m: MissionDef, mp: MissionProgress, now = null) -> String:
	if MissionBoard.plays_left(m, mp, now) <= 0: return MissionBoard.done_text(now)
	return "[b]%s[/b]: the match start uses one for everyone." % MissionBoard.plays_text(m, mp, now)

## Why a player count is off in Create room: "Hold the Gate needs 2–6 players" ("" without a mission).
static func players_reason(m: MissionDef) -> String:
	if m == null: return ""
	return "%s needs %d–%d players" % [m.name, m.min_players, m.max_players]

## The end screen's line under Retry when only some of the towers it would take are rested:
## "Retry takes 1 rested tower (Mage)" ("" when it takes the full cap or none).
static func retry_takes_line(names: Array, cap: int) -> String:
	if names.is_empty() or names.size() >= cap: return ""
	return "Retry takes %d rested %s (%s)" % [names.size(), MenuLogic.plural(names.size(), "tower"), ", ".join(PackedStringArray(names))]

## Why Retry is hidden when no rested tower would go: the doc's line, pointing at the Guild.
const RetryAllTired := "All your towers are tired: change your hand in the Guild or come back tomorrow."

## A lobby room row's second line: the mission ("Night Watch"), "Night Watch · done today" when used up.
static func room_row_line(mission_name: String, done: bool) -> String:
	return mission_name + (" · done today" if done else "")

## Why Join is off on a room set to a mission used up today: "Done today: you played Night Watch today. Resets in 5 h."
static func join_done_text(mission_name: String, now = null) -> String:
	return "Done today: you played %s today. Resets in %s." % [mission_name, MissionBoard.duration_text(MissionBoard.resets_in(now))]

## The auto-leave popup (lobby-auto-left.html): {title, body, resets}.
static func auto_left(mission_name: String, now = null) -> Dictionary:
	return {"title": "Done today",
		"body": "The room switched to [b]%s[/b], which you already played today. You left the room." % mission_name,
		"resets": "Resets in [b]%s[/b]." % MissionBoard.duration_text(MissionBoard.resets_in(now))}
