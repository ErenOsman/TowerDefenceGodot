# Missions & Guild — Design

Written 2026-10-14 by the Godot agent from Eren's decisions of the same day; Godot pass 2026-10-15. The points he left
open are decided here and marked **(agents)**. This file is the source of truth for missions, the Guild and where tokens come from;
Workshop — Design (tokens), Camp & Chapters — Design (the Camp's Signpost) and Multiplayer — Design (co-op rooms)
point at it.

After **Chapter 2** is cleared, the Camp's **Signpost** opens **Missions**: it leads to the **Guild**, a second place
like the Camp. The Guild holds the **missions** and **multiplayer**. Missions are the **source of tokens** (the
Workshop's currency). Unlike chapter levels, a mission can be played a limited number of times a day (one, unless the
mission says otherwise). Every multiplayer level is a mission, with the same daily limit: a mission you have used up
today cannot be joined, and a room that switches to it drops you.

## Decisions

| Topic | Decision | Source |
| --- | --- | --- |
| Where | The Camp's **Signpost** gains **Missions** once Chapter 2's last level is won (the catalog's `guildUnlock`); it opens the **Guild**, a place like the Camp, with Back to the Camp | Eren 2026-10-14 |
| Name | **Guild** (scene `game/ui/screens/guild.tscn`, `SceneFlow.Guild`) | Eren ("kamp yerine guild olabilir") |
| What is there | **Missions** (the mission board), **Multiplayer** (the co-op lobby, moved here from the Camp), **Towers** (the hand editor, the same hands and 4 layouts as the Camp's), **Camp** (back). The Workshop stays in the Camp: tokens are earned in the Guild and spent in the Camp | Eren (missions, multiplayer, hand editing) · agents (Towers = the same hand editor; Workshop stays) |
| Tokens | **Missions are the only source of tokens.** Chapter levels drop none (their prize is the first-clear tower). A mission lists what it drops: `winTokens` on every win and `firstWinTokens` once | Eren (missions = token source) · agents (chapters drop nothing) |
| Daily limit | A mission can be **played `playsPerDay` times a day** (default 1; content may say 2, 3…). A play is **consumed when the mission starts** (the level starts; in co-op, when the match starts), so a loss or a quit counts too. The count resets at **local midnight** | Eren (once a day or a set number) · agents (consumed at start, local midnight) |
| Multiplayer | **Every multiplayer level is a mission**; the lobby lists only missions. A player whose plays of a mission are used up **cannot create or join** a room set to it ("Done today · resets in 5 h"); if the host **switches the room to** such a mission, that player **leaves the room automatically** with the same message. The match start consumes one play for everyone in the room | Eren |
| Tower energy | **Every tower has 1 energy a day for missions**: a tower that went on a mission today is **tired** and cannot go on another until the reset. Energy is spent when the mission starts, by the towers the mission takes from the hand (the first ones up to its cap; the bench keeps its energy). Chapter levels never tire towers. The hand editor and the mission detail show tired towers (dimmed, "Tired · rests in 5 h"); a mission cannot start when every tower it would take is tired, and offers Change hand | Eren 2026-10-14 (1 energy per tower per day) · agents (spent at start by the towers taken; shown in the hand) |
| Solo and co-op | A mission's `mode` is **Solo**, **Co-op** (with a player range, 1–6) or **Any** (playable alone from the board or in a room). Co-op missions carry the co-op rules the Multiplayer doc gives the level (`sharedPool`, `coopHandCap`): `data/content/Missions.json` replaces the co-op list | agents |
| Unlock | A mission has a requirement like a level: open when the Guild opens (default), or a list of levels / missions that must be won first (all / any). No daily rotation for now: the board shows every unlocked mission every day | agents |
| Records | Missions keep their own records (attempts, wins, best) under the **mission id**, separate from the chapter level they reuse; co-op wins count as wins for every player in the match. Missions never change chapter progress | agents |
| After a mission | The end screen shows the token drops ("Rewards: Fire Arrow ×1"); Retry is hidden when the plays are used up ("Done today"); the leave button says **Guild** | agents |
| Content | `data/content/Missions.json` (`MissionAsset`), the catalog's `guildUnlock` and ordered `missions` list; no numbers in code | agents |

## Player flow

```text
Camp ──Signpost: Missions──▶ Guild ──Missions──▶ Mission board ──Play──▶ Level ──ends──▶ End screen ──Guild──▶ Guild
                               │                      │  (solo / any)                            (Retry while plays remain)
                               ├──Multiplayer──▶ Lobby ──room (a mission)──▶ co-op match ──▶ End screen ──Guild
                               ├──Towers──▶ Hand editor
                               └──Camp──▶ Camp
```

Before Chapter 2 is cleared the Signpost stays a plain prop; the first time Missions opens, the Guild greets the
player once (a short card, like the Camp's first visit: `profile.guildSeen`) and says what missions and tokens are.

## The Guild

Reference mockups (UI/UX agent, 2026-10-14, approved as the UI direction): http://92.5.94.11/art/ui/screens-b/
(camp-signpost, guild, guild-welcome, mission-board, mission-detail / -done / -coop / -tired / -all-tired,
lobby-mission-picker, lobby-list-mission, lobby-auto-left, lobby-room-tired, hand-select-mission,
end-screen-mission; sheet `shots/missions-sheet.png`). Their choices: drops in two rows, "Each win" and "First win"
(first-win coins with a gold rim, dimmed "claimed" once taken); plays left as pips ("1 of 1 play left today"); board
cards carry small secondary Play / Find a room buttons, the primary button lives in the detail; tired towers at 50 %
with a moon "z" badge and "Tired · rests in 5 h"; the cap divider counts rested towers, "▲ goes" under the towers
that will come; the co-op room row says "1 tired: the next rested tower goes"; the Guild backdrop is a warm-tinted
blurred diorama with a ring of 4 stations.

A place like the Camp (stations on a ring; panels until there is art):

| Station | What it does |
| --- | --- |
| **Missions** | The mission board: every unlocked mission as a card: name, mode chip (Solo / Co-op 2–4 / Any), the tokens it drops, and its state: **Play** (plays left: "1 play left today"), **Done today · resets in 5 h** (greyed), **Find a room** for co-op missions, or the lock reason. Picking a card opens the mission detail: the level's preview, facts and enemies as in level select, the drops, the plays left, the hand strip with Change hand, and Play / Find a room |
| **Multiplayer** | The co-op lobby as the Multiplayer doc describes it; the room's level picker lists missions only, each with the player's plays left; missions used up today are listed greyed with "Done today" and cannot be picked |
| **Towers** | The hand editor, full size (the same collection, hands and layouts as the Camp's Towers); tired towers are dimmed with "Tired · rests in 5 h" so a rested hand can be built for the next mission |
| **Camp** | Back to the Camp |

## Rules

- **Plays.** `MissionProgress.plays_left(mission, now)` = `playsPerDay − plays used today`; "today" is the local
  calendar date of `now`. Starting a mission records one play (`day`, `count`); a new date resets the count. A play
  is spent at start, never refunded. The time until the reset is shown as hours ("resets in 5 h", "resets in 20 min"
  under an hour).
- **Tower energy.** `MissionProgress.is_tired(tower id, now)`: the tower's last mission day equals today's date.
  Starting a mission marks every tower it takes (the hand's first ones up to the cap, tired ones skipped: the level
  takes the first **rested** towers) with today's date. The reset is the daily one. Selling or losing a tower in a
  level changes nothing. In co-op each player's own towers tire the same way. A mission's detail and the room's
  hand strip show "Tired" towers; Play / Ready is refused when no rested tower would come in ("All your towers are
  tired: change your hand or come back tomorrow").
- **Co-op.** Creating or joining a room needs a play left for its mission; the client checks before sending `create`
  / `join` (the relay stays dumb and does not know saves). On `room` with a level the player has used up (the host
  changed it), the client sends `leave` and shows "Done today: the room switched to <mission>". `match_start`
  records the play for every player in the room. The relay's `rooms` list still carries the level id; the lobby
  shows "Done today" on those rooms and disables Join.
- **Rewards.** On a win: `winTokens` to everyone in the match; `firstWinTokens` once per mission per player; the
  end screen shows them. A loss or a quit gives nothing (but the play is spent).
- **Unlock.** The catalog's `guildUnlock` (Chapter 2's last level) opens the Signpost entry and the Guild;
  a mission's own `requires` works like a level's.
- **Validation (Validate All):** every mission's level exists; a co-op mission's player range is within 1–6 and
  its level's `coopHandCap` ≥ 1; `playsPerDay` ≥ 1; every token kind drops from at least one mission (else warn);
  the Workshop's "Found in" reads mission drops now.

## Data

### data/content/Missions.json — `MissionAsset` (keys `Mission/<Name>`)

| Field | Meaning |
| --- | --- |
| `id`, `displayName`, `description`, `icon` | the mission ("Night Watch"); saved under the id |
| `level` | the level it plays (a `Level/…` key) (a chapter level reused, or a level made for the mission) |
| `mode` | `Solo` / `Coop` / `Any` |
| `players` | `{ "min": 2, "max": 4 }` for Coop / Any (the room's count is clamped to it) |
| `playsPerDay` | 1 by default |
| `requires`, `requireAll` | level / mission ids that must be won first; empty = open with the Guild |
| `sharedPool`, `coopHandCap` | the co-op rules (Multiplayer — Design); replaces `coop.json` as the co-op list (the relay still reads `data/coop.json`, generated from the missions by `tools/coop_json.gd`) |
| `firstWinTokens`, `winTokens` | `[{ "token": "Token/Fire Arrow", "amount": 1 }]` |

Catalog: `guildUnlock` (a level) and `missions` (ordered mission list, the board's order). The Workshop's catalog
drop fields `firstWinTokens` / `winTokens` on chapter levels are dropped: tokens come from missions only.

### Saves

- `MissionProgress`: records per mission id (attempts, wins, won, best base HP, fewest rounds, last played),
  `plays`: `[{ "id", "day": "2026-10-14", "count": 1 }]` and `tired`: `[{ "tower": "<tower id>", "day": "2026-10-14" }]`.
  `PlayerProfile.guildSeen`.
- Engine-free rules in `sim/meta/mission_board.gd` (`MissionBoard`, static): `is_guild_unlocked(progress, catalog)`,
  `is_unlocked(mission, progress, mission_progress)`, `plays_left(mission, mission_progress, now)`,
  `start_play(mission, mission_progress, hand, cap, now)` (spends the play and tires the towers taken; returns them),
  `is_tired(tower, mission_progress, now)`, `rested_hand(hand, mission_progress, now)`, `resets_in(now)`,
  `drops(result, record, mission)`; `MissionDef` and `MissionProgress` beside it. Tests: `tests/test_missions.gd`.
- Rule data: `towerEnergyPerDay` = 1 in the game rules (one field, so it can change without code).

## Starter content (placeholders, Eren rewrites)

| Mission | Level | Mode | Plays/day | Drops (win · first win) |
| --- | --- | --- | --- | --- |
| Patrol | Chapter 1 · 3 Two Roads | Any 1–4 | 1 | Yew Bow ×1 · Fire Arrow ×1 |
| Night Watch | Chapter 2 · 1 Rock Garden | Any 1–4 | 1 | Fire Arrow ×1, Poison Gland ×1 · Arcane Shard ×1 |
| Hold the Gate | Chapter 2 · 2 Three at the Gate | Co-op 2–6 | 1 | Steel Plate ×1 · Steel Plate ×1 |
| Drum Line | Chapter 2 · 3 The Drummer | Any 1–4 | 2 | Arcane Shard ×1, Poison Gland ×1 · Fire Arrow ×1 |
| The Glutton Returns | Chapter 2 · 4 The Glutton | Co-op 2–6 | 1 | Ember Core ×1 · Ember Core ×1 |

## In the Godot build

Built (2026-10-14/15): the content and rules (`MissionAsset`, the catalog's `guildUnlock` / `missions`,
`MissionProgress`, `MissionBoard` with tests, Validate All; the co-op list reads missions; the end screen grants
mission drops) and the screens: the Signpost to the Guild, the Guild (`game/ui/screens/guild.gd`, a 3D hall from the
Blender kit's `art/guild/`, built like the Camp by `TdStationWorld`), the mission board and detail
(`mission_board.gd`, `mission_detail.gd`), the lobby's mission picker with "Done today", the auto-leave message. How
it is wired: docs/Implementation Notes.md ("Missions & Guild rules", "Missions & Guild screens"). Still open: a mission card
look (missions have no icon art yet; their `icon` is empty).

History: the plan first had the content, rules and screens built in the Unity repo (`UI_Guild` and its stations)
and then mirrored in the Godot build; only the Godot build was done before the Unity build stopped on 2026-10-15.

## Open questions

- Reset time: local midnight (chosen) or a fixed server hour for everyone.
- Daily rotation (a few missions a day instead of the whole board) and weekly missions.
- Whether missions get their own levels (made for them) or keep reusing chapter levels.
- **Gold.** If a gold currency is ever added, it belongs here: missions would be its source (like tokens), and a
  Blacksmith shop could spend it. It is not part of tower upgrades (Eren 2026-10-16: "gold, mission documentinde
  olabilir"). Not planned yet.
