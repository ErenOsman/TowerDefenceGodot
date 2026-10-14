# Godot notes — where the Godot build differs from Unity

Godot-only notes. The design docs in `docs/design/` and `docs/Decisions.md` are read-only copies pulled from the
Unity repo by `tools/sync_from_unity.sh` (the Unity repo is the single source of truth; edit there). Content
(`data/content/*.json`) is pulled the same way; after a content change the script re-runs the golden comparison
(`tools/golden.gd`) against the C# oracle logs when they are present.

## Deliberate differences
- Camera picking corrects Godot's `project_ray_*`, which ignores a frustum camera's offset (GridSpace.ground_under).
- VFX are CPUParticles3D approximations of the Shuriken kit (`game/level/vfx/`); no sound effect files exist yet (hooks only).
- The Princess is a 3D prop placed on the board while her line shows (not a portrait beside the box).
- TdButton reserves "bleed" room for rims/rings so clipping containers never cut hovered/selected buttons (ability buttons: 143 px + 4 px gap on the action bar).
- Camp: stations on a ring from `art/camp/layout.json` (Blender kit, free slots for later stations).
- Descriptions and level intros come from the content JSON unchanged; wording fixes belong in the Unity content. The tutorial level is the exception: its guided lines live in `data/tutorial.json` (see "Tutorial lines" below).

## Decisions taken while testing the Godot build
See `docs/Decisions.md` (2026-10-13 rows) — they are logged in the Unity repo and synced here.
- Level select hides the enemy chips until the level has one attempt recorded; the heading stays over one muted line "You'll see them when you play it." (UI Design Rules "Level select", 2026-10-14). The enemies fact tile waits for a generic enemy glyph from the kit (asked the UI/UX agent). No extra save field: `MenuLogic.has_played` reads the LevelRecord's `attempts`, which every result (win, loss, quit through Pause) increments.

## Co-op rules (sim) — Godot-only for now
- `CoopSession` (`sim/level/coop_session.gd`) wraps a `CoopLevelSession` (a LevelSession subclass that only changes the
  hand cap and, with separate pools, where energy changes are booked). Single player is untouched.
- The Multiplayer station's level list lives in `data/coop.json` (`CoopList`): per level `sharedPool` and `coopHandCap`
  (default 3). **These fields should move into the Unity content later** (the catalog's chapter-like Multiplayer list
  and the level's `isSharedPool`), then `data/coop.json` goes away and `CoopList` reads the catalog.
- Separate pools write one EnergyChanged per pool with the extra fact `Pool` = the player's slot (the HUD should show
  only the local player's pool). GiveEnergy level events are split 1/N like income; a closed (leaver's) share is lost.
- A leaver's towers can be cast with by anyone but not sold (a sold tower would go back to a hand nobody plays).
- `pass` is a GDScript keyword: the method is `pass_turn(player)`; the protocol command stays `{"k": "pass"}`.

## Hand layouts (save) — Godot-only for now
- `GameData.hand_layouts` / `active_layout` (saved as `"handLayouts": {"active": n, "layouts": [{"name", "hand": [tower ids]}]}`):
  the hand editor's 4 fixed, renamable layouts (UI Design Rules § Hand select). **The Unity GameData lacks this field**;
  it should be added there (and to the save docs) when Unity gets the Hand select screen. The active layout always
  mirrors `towers.hand` (the hand levels use); a save without the key gets Layout 1 = the hand, 2–4 empty.
- Tower roles / delivery in the hand editor's filters are derived from the abilities (`HandLogic.traits`), not authored:
  every tower has Tower Walk, so there is no "Movement" role chip and no "Can move" toggle (UI Design Rules, cd1b6a5).

## Tutorial lines — Godot-only for now (guided tutorial)
The tutorial level plays a guided ("babysitting") tutorial instead of `Sequences/Tutorial Steps` when
`data/tutorial.json` exists (`game/level/guided_tutorial.gd`, owned by the LevelController; other levels' intros and
entrances still use SequenceRun). At every step only one action is possible: it is ringed and the Princess's bubble
points at it (one ring per line, the tail ends on its edge); anything else is refused (the bubble says what was wrong; the ringed target and the bubble shake).
Space / a click goes on on talk lines; Skip ends the guidance (free play). **Move these texts into the Unity content**
(`Data/Sequences/Tutorial Steps`) once Unity gets the same gating; then `data/tutorial.json` keeps only `allow`/`advance`.

| # | Princess says | Allowed (ringed) | Goes on when |
| --- | --- | --- | --- |
| 1 | Slimes come down this road… | nothing (points at road tile (4,2)) | click / Space |
| 2 | …to your castle. Keep it safe. | nothing (points at the castle) | click / Space |
| 3 | Click your Archer to place it. | the Archer's tray piece | placing starts |
| 4 | Now click a lit tile. | build tiles (10,3) and (10,1) only (only they light; the ring is on (10,3)) | the tower is placed |
| 5 | End the turn to let the slime come. | End turn | the round ended |
| 6 | Towers can move. Click your Archer. | selecting the Archer | it is selected |
| 7 | Click Tower Walk. | the Tower Walk button | aiming starts |
| 8 | Now click the lit tile. | the tile 2 steps toward the slime on the archer's row | the walk is cast |
| 9 | Click End turn until the slime is in range. | End turn | by itself: the first enemy is in Shoot range at a turn start |
| 10 | Click Shoot. | the Shoot button | aiming starts |
| 11 | Now click the slime. | the slime | the shot is cast |
| 12 | Nice shot. | nothing | 1.5 s |
| 13 | Shoot needs a turn to recover. Click End turn. | End turn | the round ended |
| 14 | A Runner is fast. {click:QuickCast} Shoot to fire at the nearest target. | quick cast Shoot (or a normal Shoot at an enemy); End turn while nothing is in range | a cast |
| 15 | That's it: place, move, shoot, end turn. Finish the wave. | everything | the level is won (end screen) |

Refusals (with the shake, in the bubble's note; the hint line under the bar is hidden while the tutorial speaks):
"Not now: click the slime first." (what the line needs next: the Archer piece / the lit tile / your Archer / Tower Walk /
Shoot / End turn / the slime, "Shift-click Shoot" on line 14) and "Finish this step first." on talk lines.
End turn shows at 60 % on lines that do not allow it.

`data/tutorial.json` = the Sequences.json line fields (`speaker`, `text`, `pointAt`, `tileX/Y`, `uiElement`,
`continueOn`, `seconds`, `waitFor`, `pausesPlay`) plus:
- `advance`: `click` | `seconds:<s>` | `event:<placing|placed|selected|aiming|cast|round_ended|in_range|won>` (it decides
  `continueOn`; talk lines pause play).
- `allow` tokens: `piece:<tower type id>`, `tile:x,y`, `select:archer` (the player's first tower), `ability:<ability id>`,
  `aim_tile:x,y`, `aim_tile:toward_enemy:<n>` (n tiles along the archer's row toward the first enemy; the nearest valid
  walk aim if that one is not), `aim_unit:first_enemy`, `aim_unit:enemy`, `end_turn`, `end_turn:until_castable` (End
  turn only while the line's ability can hit no enemy or is not ready), `quick_cast`, `all`. `[]` = talk only.
  What a step needs first is implied: the piece again while a tile line is not placing; the archer while an ability
  line's tower is not selected. Right-click / Esc cancelling always works. Selling is refused until `all`.
- `hint` (optional): replaces the generated refusal text.
- A line that goes on at `event:aiming` refuses aim clicks (one step = one action: the button, then the target).

## Workshop content — Godot-only until the Unity repo has Forms.json/Tokens.json
`data/content/*.json` is synced from the Unity repo and never edited here, so the Workshop's starter content
(Workshop — Design § Starter content: placeholder names and numbers) lives in an **overlay**, `data/content-godot/`:

| File | What |
| --- | --- |
| `Forms.json` (`FormAsset`) | the 9 starter forms: `archer-fire`, `archer-inferno` (child of Fire Archer), `archer-poison`, `archer-longbow`, `guardian-bastion`, `guardian-spiked`, `mage-pyro`, `mage-frost`, `mage-storm`. Fields: `id, displayName, description, icon, badge, tower, parent, entity, cost (-1 = base), unlock [{token, amount}], order`. Icons = the base tower's portrait; badges `Assets/Art/UI/KitB/forms/<form id>.png` (→ `res://art/ui/KitB/forms/`) |
| `Tokens.json` (`TokenAsset`) | `fire-arrow, poison-gland, yew-bow, steel-plate, arcane-shard, ember-core` (`id, displayName, description, icon, rarity`); icons `Assets/Art/UI/KitB/tokens/<token id>.png` |
| `Units.json`, `Abilities.json`, `Passives.json`, `Reactions.json` | the form entities (`Units/Towers/Forms/*`: copies of the base tower with the doc's stat changes, base model/icon/miniature) and their abilities (Fire Shot, Fire Volley, Venom Shot, Long Shot, Shield Bash, Fireball, Frost Bolt, Chain Spark), the Spiked Counter-attack passive and its 8-damage reaction. Same shape as the Unity files |
| `CatalogDrops.json` | `{ "<level id>": { "firstWinTokens": [...], "winTokens": [...] } }`: Chapter 1 levels win drop 1 Yew Bow; every Chapter 2 level first win 1 Fire Arrow + 1 Arcane Shard; Rock Garden win Fire Arrow + Poison Gland; Three at the Gate first win +2 Steel Plate, win 1 Steel Plate; The Drummer win Poison Gland + Arcane Shard; The Glutton first win +1 Ember Core, win 1 Ember Core |

How it is read:
- `ContentLibrary.load_game()` (GameApp, the level's fallback, the save-action tool job) = `load(data/content, data/content-godot)`:
  an overlay file with the name of a content file adds its entries to that file (same key → the overlay's wins), other
  files are added, and `CatalogDrops.json` fills `CatalogLevelData.firstWinTokens / winTokens` (the fields Unity's
  `Catalog.json` will carry; they are in `ContentSerializer.SCHEMA` already). `ContentLibrary.load(folder)` alone (tests of
  the synced content, golden, Validate All in the TD Tools dock) does not read the overlay.
- `ContentHash.compute()` hashes the overlay files too (as `content-godot/<name>`, after the content's), so co-op clients
  must have the same forms.
- Not serialized, linked by the library: `TowerAsset.forms` (its FormAssets in content order), `GameCatalogAsset.forms /
  tokens`. The Unity build should derive them the same way (or add `forms` lists to the catalog).
- Saves (Godot-first, also missing in Unity's GameData): `towers.towers[i].form` (current form id, "" = default) and
  `.forms` (unlocked ids); `tokens: {"tokens": [{id, count}], "earned": [{id, count}]}`. Old saves load with no forms and no tokens.
- Co-op hand entries are `"<type id>@<form id>"` for formed towers (docs/COOP-PROTOCOL.md).

**When Unity adopts the Workshop:** move `Forms.json`, `Tokens.json` and the form units/abilities into `Content/`, put the
drop lists on the catalog's level entries, sync, then delete `data/content-godot/` (and `CatalogDrops.json` handling can
stay harmlessly or go). Check that the Unity ids match the ones above or old Godot saves lose their forms/tokens.

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
- "Found in" groups a whole chapter as "Chapter 2 levels" and marks boss levels "(boss)".
- Elsewhere: `MenuLogic.tower_name` returns the form's name for a formed tower without a custom name (hand cards,
  slots, level-select strip, the picker); `HandLogic.entries` builds a formed tower from its form (entity, cost,
  traits, description, badge); Default sort keeps the collection order within a type. HUD tray pieces, the placed
  medallion and the inspector portrait carry the badge; the end screen shows the token row (`HudText.token_rows`).
- Codex (user decisions 2026-10-14, mockup codex2): tower and enemy pages have page tabs built from a list
  (`TOWER_PAGES` / `ENEMY_PAGES`): Overview · Abilities (passives included) · Forms · Immunities (Immunities disabled,
  Forms disabled on enemies: dimmed, "Coming later"). The Forms page lists "Archer · Base form" and only the forms some tower of yours has unlocked;
  picking a row shows that form on every page (the base row goes back). Read-only: no Workshop link.
