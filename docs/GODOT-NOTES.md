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
