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
- Tutorial lines and descriptions come from the content JSON unchanged; wording fixes belong in the Unity content.

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
