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
