# Implementation Notes — how the Godot build does things

The Godot build is the game (since 2026-10-15; docs/Decisions.md "Project and tools"). This file says how it does
things: engine notes, tools, data that lives outside the content files, and the places where it deliberately differs
from the frozen Unity build (kept as the archive and the C# oracle). The design docs (`docs/design/`), the decision log
and the glossary are the live copies (docs/README.md); content is `data/content/*.json` (docs/Content.md). After a
content change: `./test.sh`, `tools/soak.gd`, regenerate the reference (`tools/game_reference.gd`); golden
(`tools/golden.gd`) plays a frozen snapshot and checks the simulation only (see "Golden").

## Deliberate differences
- Camera picking corrects Godot's `project_ray_*`, which ignores a frustum camera's offset (GridSpace.ground_under).
- VFX are CPUParticles3D approximations of the Shuriken kit (`game/level/vfx/`); no sound effect files exist yet (hooks only).
- The Princess is never drawn on the board (Eren 2026-10-15): she speaks as a visual-novel bust on the dialogue box's edge, her model rendered once per session into a transparent texture (`TdBust`, a SubViewport); the old on-board speaker prop is removed.
- The selection ring (selected unit, and the tower lit from its tray piece at half strength) is a true circle on screen drawn by `SelectRingLayer` in the battle overlay, centred on the unit's projected feet, radius from the tile's size on screen (Eren 2026-10-15); aim / range / hover tile markers stay ground decals.
- TdButton reserves "bleed" room for rims/rings so clipping containers never cut hovered/selected buttons (ability buttons: 143 px + 4 px gap on the action bar).
- Camp: stations on a ring from `art/camp/layout.json` (Blender kit, free slots for later stations).
- Descriptions and level intros come from the content JSON unchanged; wording fixes belong in `data/content`. The tutorial level is the exception: its guided lines live in `data/tutorial.json` (see "Tutorial lines" below).

## Decisions taken while testing the Godot build
See `docs/Decisions.md` (2026-10-13 rows onwards; the log lives in this repo since 2026-10-15).
- HP bars (2026-10-14, now matching Unity's PlateLayer / EntityStatusBinder / UI_HealthBar / EntityStatus.prefab;
  checked by `tests/test_plate.gd` and the live `tools/plate_check.gd`): (1) the bar was told the HP every frame, which
  restarted its ease each frame — a hit crawled down, the ghost never trailed, a heal never filled; now only changes
  reach it, as Unity's binder does. Unity's numbers (TdHealthBar has the same): fill 0.3 s smoothstep at once; ghost
  waits 0.3 s, drains in 0.6 s; heal: ghost jumps ahead, fill follows after 0.3 s in 0.3 s; unscaled time.
  (2) plate colours from the prefab: smooth gradient full (0.2, 0.85, 0.3) / half (0.95, 0.85, 0.15) / empty
  (0.9, 0.15, 0.15) instead of the kit's 60/30 % steps; ghost white 35 % on a hit (was hp.ghost red 55 %), (0.3, 1,
  0.5) 35 % on a heal (opt-in fields on TdHealthBar; the hand pieces and inspector keep the kit look). (3) the bar's
  CENTRE sits on the anchor (Unity's centre pivot; it was the bottom edge, 5 px high); 10 thick in both forms (full
  was 8). (4) layout owned by KitPlate (`plate_rects`): chip row 11 over the bar (compact 5), centred over the bar even
  when wider (was pushed right), backing 8 / 6 round bar + chips + pills — no stale kit size can shift a plate after a
  hover. (5) the reference tile (plate size at zoom 1) is the default framing's, as Unity measures it once at Init:
  it was re-measured at the current zoom on a turn or a HUD change, so zoomed-in plates shrank back to designed size.
  Unchanged and already equal: the show rule (Always Show Health / hovered or selected / previewed / 1.5 s
  healthBarAfterHit / dying 1 s healthBarAfterDeath), anchor maths (12 px × readable(zoom) over the outline's top),
  compact fit / full readable scale, 50 % dimming, full plate on top, preview stripes blinking.
  Still different: Unity shows iconless statuses as words in a line over the plate (Godot: an empty chip; every status
  has an icon today); the full plate's backing stays the darker 85 % panel (a neighbour's bar showed through Unity's 55 %).
- Camera turn (2026-10-14): Q / E keep the zoom distance and the pan; only the limits follow the new angle (zoom-out
  limit = the fit for it, a zoom beyond it is pulled in; the focus clamped to the pan limits). The fit is measured
  with the board centred, whatever the pan (it was measured from the focus).
- Camera zoom-out (QA 2026-10-14): zooming out with the wheel recentres the board, so a view dragged to the board's
  edge cannot end half off screen at the zoom-out limit (Unity only clamped the focus; the pan
  rule of 2026-10-13 is unchanged).
- Level select hides the enemy chips until the level has one attempt recorded; the heading stays over one muted line "You'll see them when you play it." (UI Design Rules "Level select", 2026-10-14). The enemies fact tile always shows the kit's `icon_enemy` (never the first enemy's portrait; UI review 2026-10-14). No extra save field: `MenuLogic.has_played` reads the LevelRecord's `attempts`, which every result (win, loss, quit through Pause) increments.

## Co-op rules (sim)
- `CoopSession` (`sim/level/coop_session.gd`) wraps a `CoopLevelSession` (a LevelSession subclass that only changes the
  hand cap and, with separate pools, where energy changes are booked). Single player is untouched.
- The co-op level list (`CoopList`: per level `sharedPool` and `coopHandCap`, default 3) is built from the Coop/Any
  missions (`data/content/Missions.json`); `data/coop.json` is generated from them for the relay (see "Workshop &
  Missions content").
- Separate pools write one EnergyChanged per pool with the extra fact `Pool` = the player's slot (the HUD should show
  only the local player's pool). GiveEnergy level events are split 1/N like income; a closed (leaver's) share is lost.
- A leaver's towers can be cast with by anyone but not sold (a sold tower would go back to a hand nobody plays).
- `pass` is a GDScript keyword: the method is `pass_turn(player)`; the protocol command stays `{"k": "pass"}`.

## Hand layouts (save)
- `GameData.hand_layouts` / `active_layout` (saved as `"handLayouts": {"active": n, "layouts": [{"name", "hand": [tower ids]}]}`):
  the hand editor's 4 fixed, renamable layouts (UI Design Rules § Hand select; the Unity GameData never had it). The active layout always
  mirrors `towers.hand` (the hand levels use); a save without the key gets Layout 1 = the hand, 2–4 empty.
- Tower roles / delivery in the hand editor's filters are derived from the abilities (`HandLogic.traits`), not authored:
  every tower has Tower Walk, so there is no "Movement" role chip and no "Can move" toggle (UI Design Rules, cd1b6a5).

## Tutorial lines (guided tutorial)
**Source of truth: `docs/design/Guided Tutorial — Design.md`** (decisions, the step table, the refusals, the data
grammar of `data/tutorial.json`). This section only says how the Godot build does it.

- The tutorial level plays the guided tutorial instead of `Sequence/Tutorial Steps` when `data/tutorial.json` exists
  (`game/level/guided_tutorial.gd`, owned by the LevelController; other levels' intros and entrances still use
  SequenceRun). The lines stay in `data/tutorial.json` (they carry the `allow` / `advance` gating fields the content's
  sequence lines do not have).
- Presentation (2026-10-14, rebuilt from the bubble version): every step speaks through the **dialogue box**
  (`TdDialogueBox` in `HudSequence`, 1100×220, centred, bottom edge 212 px over the screen's, like the Unity build's
  `UI_DialogueBox`): name plate, letter-by-letter text, Skip (skip glyph, click only — Esc keeps pause) top-right.
  Notes: bottom-left "Click or press Space" on talk steps, the allowed action on action steps
  (`GuidedTutorial.action_note()`: "Click the Archer piece", "Place the Archer on a lit tile", "Click Tower Walk",
  "Shift-click Shoot"…), "Click to hide" on the free-play line; bottom-right "Tutorial · n/N" (+ the bobbing next
  mark when it waits for a click). The Princess is a **bust on the box** (Eren 2026-10-15), not a board prop: her
  model (`res://art/models/Princess.fbx`) in its Idle, head and shoulders to the waist, turned 25° toward the text,
  rendered once per session in a transparent SubViewport (`TdBust.bust()`: the whole figure at 1024×1280, the bust cut from its drawn pixels, ≤ 720 px tall) with a soft blurred drop shadow
  (`TdBust.shadow_of`); without a renderer (headless) or the model, `art/portraits/Princess.png` stands in. It stands
  on the box's bottom edge behind the box, 62 % past its left edge, 560 px tall, rising over the top edge, sliding in
  when it first shows; docked at the top it stays upright and shortens so the head stays under the top bar
  (`HudSequence._place_bust`); when the left edge would cover the ringed target it moves to the right edge, mirrored
  (`HudSequence.bust_on_left`). No medallion on the name plate. Level intros use the same bust.
- A refusal (`GuidedTutorial.refusal_text()`: "Not now: click the slime first.", "Finish this step first." on talk
  lines) replaces the bottom-left note for 2 s in the warning colour (`warn`); the box and the ringed target shake.
  The hint line under the bar stays hidden while the tutorial speaks.
- The ring stays on what the step needs next (board ring round a tile / unit, gold ring round a HUD button, the
  piece's own ring in the tray); talk steps that show something dim the rest 30 % with a lit hole, action steps don't.
- Docking: `HudSequence.dialogue_rect(screen, box, target, was_top)` (pure, `tests/test_dialogue_dock.gd`): bottom by
  default; when the target's screen rect (ring; a unit up to its plate; on a placement step every lit tile) meets the
  bottom box + its plate/Skip overhang + 8 px, the box docks at the top (top edge 136) for that step; back down only
  once the target clears by 24 px more; if both cover it, the lesser cover. Today steps 4, 6 and 8 dock at the top.
- One owner: `controller.sequence` is the guided run while it runs, else the level's own SequenceRun; both go through
  the same box (the guided branch places it, the other path re-centres it). The bubble (`TdTextBubble`) is only used
  by non-guided sequence lines that point at something.
- Render proof: `tools/tutorial_shot.gd` (steps 1–11 with refusals; prints where the box is docked).

## Workshop & Missions content
The Workshop's starter content (Workshop — Design § Starter content) and the missions (Missions & Guild — Design §
Starter content; placeholder names and numbers) are ordinary content in `data/content/` (they lived in an overlay,
`data/content-godot/`, until 2026-10-15; merged when the Godot build became the game — see docs/Content.md):

| File | What |
| --- | --- |
| `Forms.json` (`FormAsset`) | the 9 starter forms: `archer-fire`, `archer-inferno` (child of Fire Archer), `archer-poison`, `archer-longbow`, `guardian-bastion`, `guardian-spiked`, `mage-pyro`, `mage-frost`, `mage-storm`. Fields: `id, displayName, description, icon, badge, tower, parent, entity, cost (-1 = base), unlock [{token, amount}], order`. Icons = the base tower's portrait; badges `art/ui/KitB/forms/<form id>.png` |
| `Tokens.json` (`TokenAsset`) | `fire-arrow, poison-gland, yew-bow, steel-plate, arcane-shard, ember-core` (`id, displayName, description, icon, rarity`); icons `art/ui/KitB/tokens/<token id>.png` |
| `Missions.json` (`MissionAsset`) | the 5 starter missions: `patrol` (Two Roads, Any 1–4), `night-watch` (Rock Garden, Any 1–4), `hold-the-gate` (Three at the Gate, Coop 2–6), `drum-line` (The Drummer, Any 1–4, 2 plays a day), `glutton-returns` (The Glutton, Coop 2–6); all separate energy pools (sharedPool false), coopHandCap 3. Fields: `id, displayName, description, icon ("" until the kit has mission art), level, mode (Solo/Coop/Any), players {min, max}, playsPerDay, requires [level or mission keys], requireAll, sharedPool, coopHandCap, firstWinTokens, winTokens` |
| `Catalog.json`, `Rules.json` | the catalog's `guildUnlock` (= Chapter 2's last level) and `missions` (the board order); the rules' `towerEnergyPerDay` = 1. **Chapter levels drop no tokens**, missions are the only token source |
| `Levels.json` | the **short tutorial level** `Level/Tutorial/Tutorial`: 7 × 5, road (0,2)–(5,2), castle (6,2), build tiles columns 4–6 of rows 0/1/3/4, same waves/energy/hand (Guided Tutorial — Design § The level; Eren 2026-10-14). `data/tutorial.json`'s tiles match it. Golden plays the frozen Unity snapshot's 12 × 5 entry (see "Golden" below) |
| `Units.json`, `Abilities.json`, `Passives.json`, `Reactions.json` | the form entities (`Unit/Tower/Form/*`: copies of the base tower with the doc's stat changes, base model/icon/miniature) and their abilities (Fire Shot, Fire Volley, Venom Shot, Long Shot, Shield Bash, Fireball, Frost Bolt, Chain Spark), the Spiked Counter-attack passive and its 8-damage reaction |

How it is read:
- `ContentLibrary.load_game()` (GameApp, the level's fallback) = `load(data/content)`; `load_game(extra)` merges a
  candidate folder over it (the content check). The fields are in `ContentSerializer.SCHEMA`
  (`GameCatalogAsset.guildUnlock/missions`, `GameRulesAsset.towerEnergyPerDay`, `MissionAsset`, `PlayerRange`).
  `CatalogLevelData.firstWinTokens / winTokens` stay in the schema (empty everywhere).
- `ContentHash.compute()` hashes every `data/content/*.json`, so co-op clients must have the same forms and missions.
- Validate All (`ContentCheck` + `AssetValidator.validate_mission`): a mission's level exists, playsPerDay ≥ 1, a Coop/Any
  mission's players within 1–6 (min ≤ max; Coop max ≥ 2) and coopHandCap ≥ 1, requires are levels/missions without empty
  entries, self-reference or cycles, drop entries have a token and a positive amount; mission ids unique; the catalog's
  `guildUnlock` is a chapter level and its `missions` list has no empty/duplicate entry. Warnings: a token kind no mission
  drops, a mission not on the board.
- Not serialized, linked by the library: `TowerAsset.forms` (its FormAssets in content order), `GameCatalogAsset.forms /
  tokens`.
- Saves: `towers.towers[i].form` / `.forms`; `tokens: {"tokens": [{id,
  count}], "earned": [...]}`; `missions: {"records": [{missionId, attempts, wins, won, bestBaseHpPct, fewestRounds,
  fewestTowersLost, lastPlayed}], "plays": [{id, day, count}], "tired": [{tower, day, count}]}` (`count` is the doc's
  shape plus a count so `towerEnergyPerDay` > 1 works; a missing count reads 1); `profile.guildSeen`. Old saves load
  with no forms, no tokens, no mission history.
- Co-op hand entries are `"<type id>@<form id>"` for formed towers (docs/Co-op Protocol.md).
- **Duplication:** `data/coop.json` is no longer the co-op list (`CoopLevels.list()` = `CoopList.from_missions`, the
  Coop/Any missions) but stays for the relay, which reads `sharedPool` from it by level id. It is generated from the
  missions (`godot --headless --path . -s tools/coop_json.gd`); `test_missions` fails while they disagree.

## Missions & Guild rules
- Engine-free in `sim/meta`: `MissionDef` (converter: `AssetConverter.mission`), `MissionProgress` (saved), `MissionBoard`
  (static rules, `last_reason`; `now` injectable: null = local system time, a datetime Dictionary or "YYYY-MM-DD[THH:MM:SS]").
  Days are local calendar dates; the reset is local midnight (daylight-saving shifts ignored in `resets_in`).
- A solo mission starts through `GameApp.play_mission(id)` → `LevelLaunch.request(level, mission_id)`; the level
  (`LevelController._setup`) calls `MissionBoard.start_play` (spends the play, tires the towers taken = the hand's first
  rested ones up to the level's hand cap) and builds only those towers. Retry re-requests the mission (another play).
  The result goes to `MissionProgress` under the mission id with the mission's drops (`MissionBoard.finish`), never to
  the chapter progress (no first-clear tower). Chapter levels never tire towers or drop tokens.
- Co-op: rooms still carry level ids; `CoopLevels.mission_for_level` maps them to the Coop/Any mission. `create` adds
  the extra field `mission` (the relay ignores unknown fields; it does not store or echo it). `CoopLaunch.start_match`
  → `CoopLevels.on_match_start` spends the local player's play and tires the towers sent (`my_hand_types` skips tired
  ones). A mission match records the mission result and drops for every player (each client for itself); leaving it
  while running counts as a quit attempt. Rooms whose level is no mission give nothing (as before).
- Dev: SaveTools actions `chapter2` (Clear Chapter 2: opens the Guild) and `rest_missions` (Reset today's plays / rest
  all towers), shown in the F1 panel and the TD Tools Save tab.

## Upgrades & Blacksmith data (2026-10-16)
**Source of truth: `docs/design/Upgrades — Design.md`** (and `Blacksmith — Design.md` § Data). How the Godot build does it:
- Content: `levels` on every `TowerAsset` (4 steps to level 5) and `FormAsset` (3 steps) — `TowerLevelData {to, tasks:
  [TowerTaskData {kind (TowerTaskKind), count, mission?, text?}], bonuses: [LevelBonusData {stat, kind Flat|PctAdd,
  amount}]}`; `GameCatalogAsset.blacksmithUnlock` (= guildUnlock; null falls back to guildUnlock). Converted to
  `TowerType.levels` / `FormDef.levels` (`TowerLevelDef`, `TaskDef`, bonuses as `Modifier`). Validation:
  `AssetValidator.validate_ladder` (steps 2, 3, 4 … in order, known kinds, counts > 0, WinMissionId names a mission,
  real stats, Flat/PctAdd, numeric amounts) + a form's ladder not longer than its tower's. The content check's tower
  and form probes print a "levels" table (tasks, gives, stats at each level).
- Rules: `TowerLevels` (sim/meta, static, `last_reason`) and `TowerTasks` (texts, counting). Bonuses are **baked into a
  copy of the entity's base stats** (Flat sum, then × (1 + PctAdd sum)), not added as runtime modifiers, so every stat
  reader (inspector, previews, Codex, placement HP) sees them; the copy's `EntityDef.levelled_from` keeps
  `AssetConverter.asset_of` (models, icons) working. Level 1 builds the content type itself (golden unchanged).
- `Workshop.resolve` levels the type at the current form's level; `TowerType.level` says the level it was built at.
- Counting: `LevelController._record` → `_count_tasks` (only when `GameApp.blacksmith_unlocked()` was true before this
  result was recorded; nothing on a quit), for the hand's owned towers: the base ladder's current step, and also the
  form's step when the tower fought in a form. `upgrade_ready_count()` counts ready towers and ready forms.
  Kills / damage / hits / placed come from the log (Place action detail = hand tower id → its first EntitySpawned);
  combat tasks count on a loss too, win tasks only on a win. Results: `controller.task_advances` (data) /
  `task_lines` (`TowerTasks.progress_line`: "Archer (tower 3): 8 / 10 kills +3", `ready_lines`: "Guardian is ready
  to upgrade! Go to the Blacksmith.").
- Saves: `towers[i].level` / `formLevels` / `taskProgress` (written only when not default), `profile.blacksmithSeen`.
- Dev: SaveTools `level_up_towers` ("Level up all towers": +1 level each, forms up to their tower) and
  `complete_tasks` ("Complete current tasks"), in the F1 panel and the TD Tools Save tab.

## Missions & Guild screens
- `SceneFlow.Guild` → `game/ui/screens/guild.tscn`: the Blender agent's 3D guild hall (`art/guild/`, layout.json in
  the Camp's schema) built like the Camp by the shared `TdStationWorld` (camp.gd uses it too: ground, props, Idle
  loops, camera, light, button placement); the Guild has no map-kit ground (Guild Floor + Guild Hall are decor), its
  `centre` (Mission Board) is the Missions station (button below), plus the README's warm hearth light. Props load
  through `GameApp.prop_scene(folder, name)` (`camp_scene` = folder "camp"; both fall back to `art/tiles/`). The
  blurred `TdGuildBackdrop` remains only behind the full-screen mission detail.
- Station buttons (Camp and Guild, UI/UX ruling 2026-10-14: props never move for buttons) take the first free spot
  of: in front of the prop, beside it (the freer side first), above it — free = no prop's projected bounds (floors /
  halls excluded) and no other button (`TdStationWorld.place_buttons`). The Guild's Camp station is the bottom-left
  "← Camp" button plus the Guild Door as a hotspot (`TdStationWorld.hotspot`).
- Camp (Eren 2026-10-15, replaces the Signpost hotspot of 2026-10-14): a **Guild** station button ("Guild" /
  "Missions and co-op", `camp.gd` STATIONS) at layout slot 5 (where Multiplayer stood; prop `Signpost`, the map-kit
  piece: `GameApp.camp_scene` falls back to `res://art/tiles/<name>.fbx`); slot 4 is free. A small gold "New" sits on
  the button's corner until the first Guild visit (`MissionUiLogic.signpost_tag(profile.guild_seen)`). No Multiplayer
  in the Camp at all: it lives in the Guild. The Guild and Workshop buttons (gate `chapter2`) are **not shown** until
  Chapter 2's last level is won (no locked look; the props stay); the first tour skips them, and after Chapter 2 the
  next Camp visit runs a two-line mini tour (Guild, Workshop: `TOUR_OPEN`) once — `PlayerProfile.guild_tour_seen`
  (saved `guildTourSeen`; set too when the first visit itself is after Chapter 2, skipped once the Guild was visited).
- Camp ⇄ Guild is a slide (`SceneFlow.slide(id, dir)`): the new scene is built off-screen (one frame), then both move
  together for `SLIDE_TIME` 0.45 s, ease-out cubic on unscaled time (the Camp out to the left, the Guild in from the
  right; "← Camp" and the Guild Door slide back with dir -1); `SceneFlow._input` swallows every event while
  `is_sliding`; the Guild's welcome card (and the Camp's tours) wait for `slide_finished`. Every other change stays
  `go()` (a cut; the level through Loading). `slide_hold` poses a slide for renders (`tools/guild_shot.gd` slide_mid).
- Mission board = `MissionBoardScreen` (`mission_board.gd`, a TdPopup over the Guild; `MissionBoard` is the rules
  class). Detail = `MissionDetail` (`mission_detail.gd`) **extends level_select.gd** (facts, enemies rule, preview,
  hand strip reused; the reward card becomes "Drops"; HandSlot gained `mark(tired_text, goes)`). Find a room → the
  Guild opens `CoopLobby` with `preselect_mission` → Create room with that mission picked.
- Texts and states: `MissionUiLogic` (tested in `tests/test_mission_ui.gd`); coins / drop rows / mode chip / extra
  icons: `TdDrops` (icons flag, hourglass, users rasterised from the UI/UX mockup SVGs into `art/ui/icons-extra/`).
  The tired badge is the kit's `badges/badge_tired.png` (`TdTiredBadge`, ≥ 20 px, top-left of the tower picture
  under the cost coin, opposite the form badge); a tired slot is at 50 % as a whole, its caption muted.
- UI review 2026-10-14: one Disabled look for kit buttons (Primary / Secondary / Danger / Menu / Tab:
  `TdButton.disabled_box()`, ink at 60 %, label `#7A8296`, reason on hover and on a line nearby; also
  `TdTowerCard.disabled_button` and the room's Start, which was a dimmed cobalt). The detail's note is one left-aligned
  line (a type step smaller when needed); Change hand turns cobalt primary while Play is off for the hand's sake (all
  tired / empty hand). Create room disables player counts outside the mission's range ("Hold the Gate needs 2–6
  players"). The room's header says "Patrol · plays Two Roads" and its card has the plays note and the drops. Locked
  missions' pictures are desaturated (`CoopBoardPic.grey`). The end screen says "Retry takes 1 rested tower (Mage)"
  under Retry when the cap is not filled, and "All your towers are tired: change your hand in the Guild or come back
  tomorrow." when Retry is hidden for that reason.
- "▲ goes" shows in the mission detail only while a tower of the hand is tired (as the mockups: the normal detail has
  no marks); the hand editor opened for a mission (`mission` set) always marks the towers that go. Tired towers are
  dimmed in the hand editor wherever it opens (strip and collection).
- Lobby: room rows say the mission's name ("Night Watch · done today"), state "Done today", Join refused with "Done
  today: you played … Resets in 5 h."; the auto-leave runs in the lobby (deferred `leave_room` + "Done today" popup);
  the room shows your saved hand's first cap towers with the tired ones badged and `CoopLevels.tired_note`; Ready is
  refused by `CoopLevels.can_ready` (also with an empty saved hand).
- Workshop "Found in" names missions (`WorkshopLogic.found_in_text(token, GameApp.missions())` →
  `MissionBoard.found_in_text`); the old "Chapter 2 levels" / "(boss)" grouping is gone.
- Renders: `tools/guild_shot.gd` (gives The Glutton Returns a "Win Hold the Gate first" requirement in memory only,
  to show a locked card).

## Blacksmith place (game/ui/screens/blacksmith.gd, 2026-10-16)
**Source of truth: `docs/design/Blacksmith — Design.md`.** The place only; the Upgrade screens are separate work.
- `SceneFlow.Blacksmith` → `game/ui/screens/blacksmith.tscn`, built like the Guild on `TdStationWorld` from
  `art/blacksmith/layout.json` (the Guild schema + `"kits"`: the folders a prop name is looked up in, in order,
  `art/<kit>/<prop>.fbx`, then the map-kit tiles; a smithy kit = its FBX in `art/blacksmith/` + new prop names, a JSON
  change). **Placeholder art**: Modify = the Camp's Tower Workshop (anvil table), Upgrade = the Camp's Supplies, Towers
  = the Guild's Tower Rack, Camp = the Guild's Guild Door, on the Guild Floor, plus a warm OmniLight by the anvil.
- Camp: the Workshop station keeps its id `"Workshop"` and slot (tests, layout.json, tools) but reads **Blacksmith ·
  Modify and upgrade towers**, gate `"blacksmith"` (`GameApp.blacksmith_unlocked()` when it exists, else Chapter 2
  won), and slides to the Blacksmith (`camp.open_blacksmith()`, dir 1). `camp.open_workshop()` still opens the
  Workshop popup directly (dev tools, `tools/workshop_shot.gd`). The post-Chapter-2 mini tour: Guild, then Blacksmith.
- Stations: Modify (primary, `open_modify()` = the Workshop popup, as the Camp opened it), Upgrade (`open_upgrade()`,
  a stub returning null; while `UPGRADE_READY` is false the button is disabled with "Coming soon"), Towers (the hand
  editor), Camp (as the Guild: no station button, "← Camp" bottom-left + the door hotspot; `back_to_camp()` slides
  with dir -1).
- First visit: the welcome card (`profile.blacksmith_seen`, read with `"blacksmith_seen" in profile`; a session-only
  static flag when the profile has no such field), after the slide; closing it starts a 3-line tour (Modify, Upgrade,
  Towers; the Camp's Princess bubble).
- Esc: the top popup closes first (TdPopup); then the welcome card, then the tour; on the bare Blacksmith Esc slides
  back to the Camp (the Guild's bare Esc does nothing; the Blacksmith follows the "Esc = Camp" brief).
- Music: `AudioMgr.play_scene_music` has no Blacksmith case, so the Camp's map track keeps playing; Boot does not
  preload the scene (both in game/app files outside this change).
- Renders: `tools/menus_shot.gd` step `blacksmith` (blacksmith_welcome, blacksmith_tour, blacksmith, then Esc → Camp).
  QA: `tools/qa/guild_tour.gd` reaches the Workshop through the Blacksmith (`goto_smithy()`, `ws_open()`).

## Layout editor (dev, game/dev/layout_editor.gd, 2026-10-15)
Eren moves the Camp and Guild props himself. F1 dev panel → Shortcuts → "Edit layout" (enabled while the Camp or
the Guild is the current scene: any scene with `world: TdStationWorld` and a `LAYOUT` constant; same gate as the
panel: debug builds or `-- --dev`). The panel closes and `TdLayoutEditor` (a CanvasLayer at 100, under the panel)
takes every mouse event over the scene:
- Left drag a prop (stations, the centre piece, decor; ground-sized pieces such as the Guild Floor / Hall are not
  pickable): it moves on the board plane (camera ray → y = 0), snapped to 0.25 tiles, Shift = free. Q / E turn it
  by 15° (`face_yaw` for stations, `yaw` for centre / decor), + / - or the wheel over a prop scale it by 0.1,
  Delete removes a decor prop (stations and the centre cannot be removed), Esc stops. An overlay at the top shows the
  selected prop's name, station and slot, tile, yaw and scale (`*` = unsaved); the selected prop glows.
- The station buttons follow live (the scenes re-place them every frame from the props' projected boxes).
- Ctrl+S writes `res://art/camp/layout.json` / `res://art/guild/layout.json` in the same schema: the file is
  re-read at start and only `tile` / `face_yaw` / `yaw` / `scale` of the moved entries change; slot ids, stations,
  rows, notes, ring, centre and board are kept; deleted decor entries are dropped; whole numbers are written as ints
  (`JSON.stringify(…, " ")`, key order kept). Each prop knows its entry through `TdStationWorld.entries`
  ({node, kind slot/centre/decor, index, prop}). Where res:// is read-only (an exported or web build) it writes
  `user://layout_<place>.json` and copies the JSON to the clipboard: paste it into the repo's file.
- Test: `tests/test_camp_flow.gd` (move / snap / turn / scale / delete, the saved schema, to a user:// path).

## Workshop screens (game/ui/screens/workshop.gd)
- Opened from the Camp's Workshop station (`camp.gd` STATIONS: `open_workshop`, a TdPopup like Codex / Towers; the tour
  line is unchanged). Picker = `TdCollection` (the hand editor's filters + grid, shared; no hand row, no quick cost chips
  or toggles) + a detail card; Modify view slides in (0.35 s) in the same popup, not a separate scene.
- Texts, states, tree layout, compare tiles, tag lines, the action and "Found in" are `WorkshopLogic` (pure, tested in
  `tests/test_workshop_ui.gd`); the card parts are `TdTowerCard` (shared with the hand editor), the badge `TdFormBadge`
  (a colour dot under 20 px). Renders: `tools/workshop_shot.gd`.
- Tree: root children by `FormDef.order` on the mockup's slots (left, right, below; more than 3 evenly round the root),
  grandchildren 200 px beyond their parent (up from a side node). The right card shows the selected form as it is
  (stat tiles, abilities, passives): no comparison with the current form (user decision 2026-10-14).
- "Found in" names the missions that drop the token (see Missions & Guild screens).
- Elsewhere: `MenuLogic.tower_name` returns the form's name for a formed tower without a custom name (hand cards,
  slots, level-select strip, the picker); `HandLogic.entries` builds a formed tower from its form (entity, cost,
  traits, description, badge); Default sort keeps the collection order within a type. HUD tray pieces, the placed
  medallion and the inspector portrait carry the badge; the end screen shows the token row (`HudText.token_rows`).
- Codex (user decisions 2026-10-14, mockup codex2): tower and enemy pages have page tabs built from a list
  (`TOWER_PAGES` / `ENEMY_PAGES`): Overview · Abilities (passives included) · Forms · Immunities (Immunities disabled,
  Forms disabled on enemies: dimmed, "Coming later"). The Forms page lists "Archer · Base form" and only the forms some tower of yours has unlocked;
  picking a row shows that form on every page (the base row goes back). Read-only: no Workshop link.
- Review round 2026-10-14: the Camp station opens after Chapter 2 (`MenuLogic.workshop_unlocked`: the catalog's 2nd
  main chapter's last level won; `GameApp.complete_chapter2()` for dev); a form not unlocked shows its first token's
  coin in the tree (no grey shader); both Modify cards: stats, ⓘ trait lines (`WorkshopLogic.trait_lines`), "Abilities",
  passives last as square chips; pinned footer, hidden scrollbar with a bottom fade; Unlock button "Unlock · [coin] 1 Fire
  Arrow" (two tokens: coins and counts); disabled actions in a light paper fill; ability icons by id fall back to the
  asset icon. Form descriptions in the content are standalone (no comparisons). Every scroll bar is ≥ 12 px
  (`TdTheme._widen_scrollbars`); the collection grid drag-scrolls on empty space while tiles keep their own drag
  (`TdDragScroll` skips controls with meta `drag_source`); `tools/hand_drag_check.gd` proves reorder / remove / add / scroll.

## Golden (sim vs the C# oracle)
- `tools/golden.gd` plays every level with the golden policy (seed 12345) on the GDScript sim and diffs the logs with
  the C# oracle's (`~/godot/golden/*.log`, written by `~/godot/oracle/Golden.cs`). Expect "11/11 levels identical".
- Both sides load the **frozen Unity content snapshot** `~/godot/oracle/content/` (Unity `Content/*.json` at a00f795,
  2026-10-15), not `data/content`: the game's content has moved on (tutorial map, forms, tokens, missions, singular
  keys), but the C# cannot change any more, so golden is a regression check of the simulation on fixed content.
  The snapshot keeps Unity's plural keys; the loader assumes no key prefix. Never edit it; see `~/godot/oracle/README.md`.
- Content changes are checked by `tests/test_content_all.gd`, `tools/soak.gd` and the content check instead.

## Game reference (docs/reference)
- `tools/game_reference.gd` writes `docs/reference/{README,Towers,Enemies,Statuses,Levels,Codex}.md` from
  `data/content` (`GameReference`, game/dev/game_reference.gd: the Unity export's page layout; Source lines name
  `data/content/<File>.json → key`). **Regenerate the reference after content changes** and commit it with them.
  The TD Tools dock's Reference tab previews / exports the same pages.

## Godot daemons (server tooling, 2026-10-14)
Two resident Godot processes keep this project loaded, so `check.sh`, `test.sh` and `~/godot/run.sh --daemon … -s tools/<x>_shot.gd`
skip the start-up, the import and the lock. Full doc: `/home/ubuntu/godot/README-daemon.md`.
- Services (systemd user units): `td-godot-headless` (check and test, in-process: `tools/daemon.gd` + `tests/suite_runner.gd`,
  the same runner `tests/run.gd` uses) and `td-godot-render` (tool-script shots in a child Godot on its Xvfb display).
  Client: `/home/ubuntu/godot/jobs.sh [--render] ping|check|test|shot|reload|restart`.
- Restart: `systemctl --user restart td-godot-headless td-godot-render` (add `--no-block` to return at once).
- Logs: `/home/ubuntu/godot/daemon/q-{headless,render}/daemon.log`, plus `godot.log` and `import.log` next to it.
- Limits: a restart after 200 jobs or 1.5 GB RSS; `MemoryMax` 2.5 GB per service; a client waits at most 900 s (`JOBS_TIMEOUT`).
- Fall back to direct runs with `TD_NO_DAEMON=1 ./test.sh` / `./check.sh` (or plain `run.sh` without `--daemon`) when
  a result looks stale. A new `class_name` restarts the daemon by itself (that job runs in a child process); a dead
  daemon falls back on its own.
- Don't wrap daemon calls in `flock …/.td.lock` (the daemon serialises its own jobs). The lock stays for direct runs and exports.
- Job `content_check <candidate dir> [level id]` (and `content_check --schema`): see "Content check" below.

## Content check (tools/content_check.gd, 2026-10-15)
Offline check of candidate content entries, used by the wiki's Content Editor (/admin; `~/wiki/README.md`).
- Run: `/home/ubuntu/godot/jobs.sh content_check <dir> [level id]` (daemon job, in-process, ~1–3 s) or directly
  `godot --headless --path . -s tools/content_check.gd -- <dir> [level id]`. `<dir>` holds `<Type>.json` files in the
  content format (`{"type": "StatusAsset", "assets": {key: entry}}`, file names as in data/content). Output: ONE JSON
  object between `CONTENT_CHECK_BEGIN` / `CONTENT_CHECK_END`: `{ok, errors[], warnings[], probes[{entry, kind, lines[],
  tables[{title, columns, rows}], warnings[]}], candidates[], baseline{}, elapsed_ms}`; exit 0 ok / 1 errors / 2 usage.
  `--schema` prints `ContentSerializer.SCHEMA` + enum names + stats + tags between `CONTENT_SCHEMA_BEGIN/_END`
  (key order kept: `JSON.stringify(…, "", false)`).
- `--context <dir>` (more content-format files, not loaded): duplicate checks against them (the wiki's Content Editor passes its approved set and open entries; it then writes accepted entries into data/content itself and commits them as "Content Editor": `content: apply <key>` / `content: remove <key>`). Errors also: a key not starting with its type's folder (Status/…; read from the existing keys, the folder most of the type's keys use, ContentFiles.KEY_FOLDERS for a type with none), an id used by another entry of the type, keys differing only by case/spaces; warnings: duplicate display name or number.
- Loader: `ContentLibrary.load(folder, extra)` / `load_game(extra)` merge the candidate folder over data/content
  (same key → the candidate wins). Nothing is written. An empty candidate folder checks the content alone (ok + a warning). Test: `tests/test_content_candidate.gd`.
- Logic: `tools/content_check_runner.gd` (no class_name, so the daemon needs no restart). Errors = load problems,
  ContentCheck (Validate All) findings and conversion failures that the content without the candidates does not have
  (those are only counted in `baseline`), unknown fields; warnings = new warnings, missing fields, probe warnings.
  Probes (real game rules, seed 12345): Status → 1 / typical (what the content's abilities apply) / max stacks on a
  100-HP and a shielded dummy, 12 rounds of start_round/start_turn/end_turn/end_round, per-turn tables ("never expires",
  "ticks for 0", "kills a 100-HP unit in N turns", "stacks never reach 0 with the remove rule", "does nothing by
  itself"); Ability → cast by a dummy with the stats of a unit that has it at foes at 1/2/5 tiles, a group of three
  and allies, per-target HP/shield/status table, valid aims, "no valid aim", "cost unaffordable", cooldown recovery;
  Unit → stats, abilities, 3 rounds on a 9 × 3 probe road (enemy side walks the road, tower side casts at road
  dummies); Tower → cost vs other towers and vs the energy of the levels from where it unlocks, then its entity;
  Level (or the optional level id) → the golden policy of tools/golden.gd for 40 rounds (same result as golden: e.g.
  chapter1-2 Lost round 13, 579 events), round table, script errors; Reaction / Passive → granted to a dummy, its
  trigger fired once; Form / Token / Mission → "found in", unlock/drop sanity (a mission also plays its level).

