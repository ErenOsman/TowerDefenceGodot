# Tower Defence — Godot

Godot 4.7 rebuild of the Unity game [TowerDefenceProject](https://github.com/ErenOsman/TowerDefenceProject).
Open `project.godot` with Godot 4.7 (Standard, no .NET). The simulation (`sim/`) is a 1:1 GDScript port of the
Unity game's engine-free C# rules; content comes from `data/content/*.json` (a copy of the Unity repo's `Content/`).

- `PORT.md` — how the simulation was ported and verified (C# oracle, golden logs).
- `game/ARCH.md` — the game layer (app shell, UI kit, board, level, HUD, screens).
- `./check.sh` parse-checks every script, `./test.sh` runs the tests (headless).
- Web build: `~/godot/export.sh projects/td --publish` on the wiki server.
