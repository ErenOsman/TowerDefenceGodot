# Folder Structure — Design

Started 2026-10-05; the [Decisions](#decisions) table records how each part was settled. Godot pass 2026-10-15: rewritten for the Godot project (`~/godot/projects/td`), the game since 2026-10-15; the Unity tree is in [History](#history).

Where everything in the project lives, and the rules that keep it there. The goal is that someone new — a person or an agent — can guess where a thing is before searching, and knows where a new thing goes without asking.

## Principles

1. **One home per thing.** Every file has exactly one right folder, decided by *what it is*, not by who made it or when.
2. **Content by type, art by kind and unit.** Game data is sorted by asset type (all abilities in `data/content/Abilities.json`); art is sorted by kind (models, icons, portraits) and named after the unit it belongs to (`art/models/Slime.fbx`, `art/icons/Units/Slime.png`, `art/portraits/Slime.png`). A unit's model, rig and clips are one FBX from the Blender pipeline, so its look is one file.
3. **Docs apart from the game.** Documentation is Markdown in `docs/`, read on GitHub and in editors; the game never loads it.
4. **Generated files say so, and are never edited by hand.** The game reference (`docs/reference/`), `data/coop.json` and the UI theme come from tools; change the tool or the source, then regenerate.
5. **Demo content is kept apart.** Examples the game does not use live under `Example/` key folders (`Ability/Example/…`, `Unit/Other/Example/…`, `Presentation/Example/…`) and levels outside the catalog under `Level/Other/`, so the real content reads clean.
6. **The simulation is engine-free.** Everything under `sim/` is plain GDScript (`RefCounted`, no Node, no Resource, no `load`; only `sim/data/` uses `JSON` and `FileAccess`), so the rules run headless, in tests and in tools.
7. **One global class per file.** Every `class_name X` lives in its own `.gd` whose name is the snake_case of `X` (`LevelSession` → `sim/level/level_session.gd`, `TdHealthBar` → `game/ui/elements/td_health_bar.gd`). A name Godot already owns gets a `Td` prefix (docs/Sim Port.md "Renames").
8. **Moves keep uids.** Scripts and scenes are referenced by `uid://` as well as by path: move a file in the editor's FileSystem dock, or together with its `.uid` / `.import` file, never alone. Content is found by key and type, never by file position.

## The tree

```text
td/                           ~/godot/projects/td; open project.godot with Godot 4.7 (Standard, no .NET)
├── README.md                 what the project is, how to open it, where to start
├── project.godot             project settings, autoloads, the TD Tools plugin
├── export_presets.cfg        export presets (Web)
├── web_shell.html            the web export's HTML shell
├── default_bus_layout.tres   audio buses
├── check.sh, test.sh         parse-check every script; run the tests
├── art/                      imported art: models, map kit, hub kits, icons, portraits, UI sprites, fonts, music
├── data/                     game data: content/*.json (the source of truth), tutorial.json, coop.json
├── sim/                      the simulation: the game rules, engine-free
├── game/                     the game layer: app shell, board, level, UI, net, dev tools (+ boot.tscn)
├── addons/td_tools/          the TD Tools editor dock
├── tests/                    the test suite (test_*.gd)
├── tools/                    command-line tool scripts: check, golden, soak, content check, generators, renders
├── docs/                     all documentation
└── .godot/                   import cache (generated, git-ignored)
```

```text
docs/
├── design/                   design docs, one per system (this file)
├── reference/                GENERATED: towers, enemies, statuses, levels, Codex with their numbers
├── notes/                    handoff notes, kit READMEs, UI notes (notes/ui: Unity-era notes kept for the kit)
├── archive/                  Unity-era docs kept as history (changelog, C# combat notes, the old index)
└── Decisions.md, Glossary.md, AI Usage.md, Content.md, Implementation Notes.md, Co-op Protocol.md,
                              Sim Port.md (the simulation port's conventions), Architecture.md (the game layer)
```

## Code: `sim/`, `game/`, `addons/`

The folder decides what a script may touch.

| Folder | What goes here | May use |
| --- | --- | --- |
| `sim/formulas/` | The formula language: `Parser`, `Vocabulary`, the nodes, `Num` | plain GDScript only |
| `sim/combat/` | The rules core: `GameState`, entities, abilities, steps and effects (`Resolver`), statuses, reactions, passives, `Targeting`, `Instinct`, `EventLog` | plain GDScript only |
| `sim/level/` | A level being played: `LevelSession`, `LevelDef`, waves, towers and forms, `EnemyBrain`, the co-op `CoopSession` | plain GDScript only |
| `sim/meta/` | Between levels: `LevelCatalog`, `LevelProgress`, `TowerCollection`, `CodexProgress`, `Workshop`, `TokenWallet`, `MissionBoard`, `MissionProgress` | plain GDScript only |
| `sim/presentation/` | What the screen shows, engine-free: `Director`, `ViewFrame`, `FrameRecorder`, `SequenceRun` | plain GDScript only |
| `sim/data/` | The content layer: asset types (`ContentAsset` subclasses), `ContentLibrary` (loads `data/content`), `AssetConverter` (assets → the sim's defs), `AssetValidator` and `ContentCheck` (Validate All), `ContentSerializer` (the field schema), `ContentFiles` (type → file and key folder), `ContentHash` | plain GDScript + `JSON`, `FileAccess` |
| `game/app/` | The app shell: the autoloads `GameApp`, `SaveData`, `SettingsMgr`, `AudioMgr`, `KeyBinds`, `SceneFlow`; save and settings data, `ArtPaths` (content art paths → `res://art/…`) | Godot |
| `game/board/` | The 3D board: `BoardView`, `EntityView` / `EntityRig` (model, clips), `BoardCamera`, `GridSpace`; `overlay/` for plates, markers, floaters, banners | Godot |
| `game/level/` | The level scene: `LevelController`, `GuidedTutorial`, `presenters/` (one per event kind), `vfx/` (the CPUParticles3D kit `VfxKit` + `effects.json` + sprites), sounds, co-op launch | Godot |
| `game/ui/theme/` | `TdTheme` (built from the sprite kit), tokens, motion, 9-slice boxes | Godot |
| `game/ui/elements/` | Reusable controls: `TdButton`, tooltips, `TdHealthBar`, `TdIconChip`, `TdDialogueBox`, `TdTextBubble`, panels | Godot |
| `game/ui/hud/` | The level HUD: `Hud`, top bar, hand tray, inspector, action bar, `HudSequence`, pause, end screen | Godot |
| `game/ui/screens/` | One script (+ `.tscn`) per screen: main menu, level select, Camp, Guild, Codex, Workshop, hand editor, settings…; `parts/` for pieces several screens share and their pure logic (`MenuLogic`, `HandLogic`, `WorkshopLogic`, `TdStationWorld`); `coop/` for the lobby and room | Godot |
| `game/net/` | Co-op networking: `RelayClient` (autoload `Net`), `NetProtocol`, `CoopLevels` | Godot |
| `game/dev/` | Developer tools shared by the game and the editor dock: the F1 dev panel (`TdDevPanel`), `SaveTools`, `BalanceSheet`, `GameReference`, `DevLog` | Godot |
| `addons/td_tools/` | The TD Tools editor dock (`tabs/`: Save, Validate, Balance, Playtest, Reference); editor-only | Godot editor |

Rules: nothing under `sim/` touches the engine (docs/Sim Port.md "Style"); `game/` reads the `ViewFrame` (`Director.shown`) for what is drawn, never `GameState`, and changes the game only through `LevelController` commands (docs/Architecture.md); editor-only code lives only in `addons/`, and logic the dock and the running game share goes in `game/dev/`; one global class per file (Principle 7). The game layer's architecture is in `docs/Architecture.md`, the simulation's conventions in `docs/Sim Port.md`.

## Content: `data/`

| Path | Holds |
| --- | --- |
| `data/content/<Type>.json` | All game content, one file per asset type (`Abilities.json`, `Units.json`, `Levels.json`, `Catalog.json`…): `{"type": "<AssetType>", "assets": {"<key>": {entry}, …}}`. The source of truth (docs/Content.md) |
| `data/content/PresentationTimings.json`, `UITheme.json` | Presentation settings read by the game layer (not content assets) |
| `data/tutorial.json` | The guided tutorial's lines and steps (Guided Tutorial — Design) |
| `data/coop.json` | GENERATED from the co-op missions by `tools/coop_json.gd`; the relay reads it |

- **Keys mirror a folder layout, one key folder per type, singular** (`Status/Burn`, `Ability/Shoot`, `Unit/Tower/Archer`, `Unit/Enemy/Rabbit`, `Level/Chapter 1/1 First Steps`); the file names stay plural. Units by role: `Unit/Tower/`, `Unit/Tower/Form/`, `Unit/Enemy/`, `Unit/Base/`, `Unit/Other/` (hazards, objects); levels by chapter (`Level/Chapter 1/`), `Level/Other/` for levels outside the catalog. The table is `ContentFiles.KEY_FOLDERS`; `tests/test_content_keys.gd` enforces it (docs/Content.md "Keys").
- **Below the type folder, organise freely**: a free-form sub-folder (`Level/Chapter 1/`, `Unit/Other/`) is fine; grouping sub-folders are singular (`Example/`, not `Examples/`).
- **Content is found by type and key**, never by file position (`ContentLibrary.get_asset(key)`, `find("TypeName", name)`, `all_of("TypeName")`); references between entries are keys; saves, rules and co-op use the entries' `id` fields, never keys.
- **The game catalog** (`Catalog.json`, the one `GameCatalogAsset`) is the root of what the game uses: anything it reaches (directly or through other entries) is game content; anything else is an example.
- **Art references inside content** stay Unity-style path strings (`Assets/Art/Icons/Units/Archer.png#Archer`); `ArtPaths` maps them to `res://art/…`.

## Art: `art/`

Godot imports every file here on the next run (the `.import` files beside them are tracked); there are no import steps, prefabs or material setup (Style & Art Direction — Design § 5).

| Folder | Holds |
| --- | --- |
| `art/models/<Unit>.fbx` | One FBX per unit, tower, enemy, object and projectile from the Blender pipeline: mesh, palette materials, rig and its AnimationPlayer clips (`Idle`, `Walk`, `Attack`, `Cast`, `Hit`, `Die`, `Spawn`), the `Muzzle` node; `impacts.json` holds the clips' impact times |
| `art/tiles/<Piece>.fbx` | The map kit: ground, build ground, roads, chasms, walls, board edges, bridge, props (`BoardView`) |
| `art/camp/`, `art/guild/` | The hub kits: props + `layout.json` (+ README) for the Camp and the Guild screens |
| `art/icons/` | Every content icon: `Abilities/`, `Passives/`, `Statuses/`, `Units/` (+ `Units/Miniatures/`), also when the interface uses it too |
| `art/portraits/<Unit>.png` | Bust renders for dialogue and cards |
| `art/ui/KitB/<group>/` | The style B sprite kit (interface-only sprites: panels, buttons, bars, chips, badges, forms, tokens…); `art/ui/Backgrounds/`, `art/ui/icons-extra/` for the rest |
| `art/fonts/` | Fonts (Plinth display, Nunito body, symbol subsets) with their licences |
| `art/music/` | Music tracks (menu, maps, battle); there are no sound-effect files yet (`AudioMgr` has the SFX pool and hooks) |
| `game/level/vfx/sprites/` | The VFX kit's particle sprites (code-side art: the effects are defined in `game/level/vfx/effects.json`) |

**When real art arrives for a unit:** export `art/models/<Unit>.fbx` (a new file or over the old one). The unit's `view` in `Units.json` keeps its path string (`Assets/Art/Models/<Unit>/<Unit> Blender.prefab`), which `ArtPaths.model` maps to `res://art/models/<Unit>.fbx`. Check it with `./check.sh` and a render (`tools/fbxcheck.gd`, the level shots).

## Everything else

| Folder | Holds |
| --- | --- |
| `game/boot.tscn`, `game/level/level.tscn`, `game/ui/screens/<name>.tscn` | The scenes `SceneFlow` opens: Boot (the main scene), the level, one per screen; a missing screen falls back to `game/app/placeholders/<name>.tscn`. Many screens build their tree in code (`_ready()`); `.tscn` is kept for layout-heavy ones |
| `game/ui/theme/` | `td_theme.tres` and the theme code: restyle the game here (generated parts come from `tools/build_theme.gd`, which reads `data/content/UITheme.json` and `kit_slices.json`) |
| `tests/` | `test_<name>.gd` per area (`TestCase` subclasses, methods `test_*`), `fixture.gd` (shared test content), `test_case.gd` (asserts), `run.gd` / `suite_runner.gd` (the runner `./test.sh` and the daemon use) |
| `tools/` | Command-line scripts (`godot --headless --path . -s tools/<x>.gd`): `check.gd`, `golden.gd`, `soak.gd`, `content_check.gd`, the generators (`game_reference.gd`, `coop_json.gd`, `build_theme.gd`), `content_format.py`, the render scripts (`*_shot.gd`, `level_scenes.gd`), `daemon.gd`; `tools/qa/` for QA tours and probes |
| `addons/td_tools/` | The editor plugin (the only editor-only code) |

Scratch scripts and renders never go into the tree: renders go to `out/` (git-ignored) or `~/godot/shots`, throwaway probes to a scratch folder. No empty "just in case" folders: a folder is made when its first file arrives.

## Builds

Builds live outside the repo and never go into git:

- **Web:** `~/godot/export.sh projects/td [--publish]` exports the `Web` preset (single-threaded, GL Compatibility, `web_shell.html`) to `~/godot/out/td/`; `--publish` copies it to the wiki server, `http://92.5.94.11/art/godot/td/`. `~/godot/publish_head.sh` exports and publishes from git HEAD (the last commit), not the working tree, so half-done edits never leak into the build. Each publish replaces the last.
- **Windows:** the Windows x86_64 export templates are installed (`~/godot/README.md`); `export_presets.cfg` has no Windows preset yet.
- Any build can be rebuilt from its commit.

## Server tooling (the daemons)

Two resident Godot processes keep the project loaded on the server, so `./check.sh`, `./test.sh` and the render scripts skip the start-up, the import and the lock: `td-godot-headless` (check and test in-process: `tools/daemon.gd` + `tests/suite_runner.gd`) and `td-godot-render` (tool-script renders in a child Godot on an Xvfb display). Client `~/godot/jobs.sh`, full doc `~/godot/README-daemon.md`, notes in docs/Implementation Notes.md "Godot daemons". `TD_NO_DAEMON=1 ./test.sh` forces a direct run. They live outside the repo (`~/godot/daemon/`, systemd user units); only `tools/daemon.gd` is in the tree.

## Naming

- **Content entries** are named as players see them (`Slime King`, `Firebolt`): the last part of the key; their stable `id` field is what saves and rules use, so renaming a key is safe (references between entries must follow it).
- **Levels** start with their number in the chapter (`1 First Steps`) so they list in play order.
- **Art** is named after its unit (`art/models/Slime King.fbx`, `art/icons/Units/Slime King.png`); clips inside an FBX are `<Unit>|<Clip>` (`Slime|Walk`).
- **Content key folders** are singular, Title Case with spaces like entry names (`Status/`, `Unit/Enemy/`); the content files are plural (`Statuses.json`). Code folders and script files are lowercase snake_case (`game/ui/elements/td_health_bar.gd`); art folders keep the names in the table above.

## The tools that keep it this way

| Tool | Use |
| --- | --- |
| `./check.sh` | Parse-checks every script under `sim/`, `game/`, `tests/`, `tools/` (`tools/check.gd`) |
| `./test.sh [--filter name]` | The test suite; `tests/test_content_keys.gd` refuses a key outside its type folder, a plural sub-folder or a reference that does not resolve; `tests/test_content_all.gd` loads, validates and round-trips every entry |
| Validate All (TD Tools dock, Validate tab) | `ContentCheck` + `AssetValidator`: broken references and bad content |
| `tools/content_check.gd` (the wiki Content Editor at `/admin/content` runs it) | Checks candidate entries before they are merged into `data/content` |
| `python3 tools/content_format.py [--check]` | Keeps the content files in their layout |
| `tools/game_reference.gd` (or the dock's Reference tab) | Regenerates `docs/reference/` after content changes |

## Decisions

The 2026-10-05 rows settled the Unity project's tree (see History); they are kept as written. The content key rules (singular key folders, plural files) are in docs/Decisions.md (2026-10-15) and docs/Content.md.

| Date | Question | Decision |
| --- | --- | --- |
| 2026-10-05 | Docs inside or outside Assets? | Outside, at the repo root |
| 2026-10-05 | Content in Resources/Data? | No: Resources only for assets loaded by name; content in `Assets/Data` |
| 2026-10-05 | How to sort content? | One folder per asset type, units by role, levels by chapter |
| 2026-10-05 | Models and animations apart? | No: one folder per unit under `Art/Models` with its model, animations and own materials |
| 2026-10-05 | Empty template folders (`Prefabs/Core`, `Models`, `Test`, `VFX`; `Scripts/Managers`, `ScriptableObjects`, `Test`) | Removed; model and effect prefabs live in `Art/` |
| 2026-10-05 | Icons the interface also uses | All content icons in `Art/Icons`; `Art/UI` holds interface-only sprites (attack and move icons moved there) |
| 2026-10-05 | Scratch scenes | `SampleScene` and `TestScene` moved to `Scenes/Test/` (still in the build list as 4 and 5) |
| 2026-10-05 | Where examples live | Inside each type folder (`Abilities/Examples/`…), next to their kind |
| 2026-10-05 | `Audio/Musics` | Renamed `Audio/Music` |
| 2026-10-05 | `Editor/ScriptView` | Renamed `Editor/Inspectors` (custom inspectors) |
| 2026-10-05 | Real art replacing a placeholder | Added beside it, the view switched, the placeholder deleted; Create Example Model never touches real art or existing placeholder files |
| 2026-10-05 | Scratch scenes in the build list | Removed from the build list |
| 2026-10-05 | Builds | `Builds/<Platform>/<version>/` plus a zip beside it; test builds in `Builds/<Platform>/Test/`; never in git. The two existing Windows builds were renamed to `Builds/Windows/0.1` and `0.2` |

## Open questions

None right now. New questions go here until decided, then into the sections above and the Decisions table.

## History

This doc was written for the Unity project (`TowerDefenceProject`, frozen and read-only since 2026-10-15): docs at the repo root outside `Assets/`; code in `Assets/Scripts` with one assembly per simulation folder (`Game.Formulas`, `Game.Combat`… with no engine references, `Game.Data` for the ScriptableObject types) and the scene code in Assembly-CSharp, editor tools in `Assets/Editor`; content as ScriptableObject `.asset` files in `Assets/Data/<Type>/` (plural folders, `Examples/` sub-folders, the catalog in `Resources/`); art in one folder per unit under `Assets/Art/Models/<Unit>/` with its prefab, Animator controller and clips; UI prefabs in `Assets/Prefabs/UI/<Screen>/`; moves kept GUIDs through the `.meta` files (`Tools > Project > Sort Data and Art`, `AssetMoves.txt`); builds in `Builds/<Platform>/<version>/` with a zip beside each, made by `Tools > Build`. The Godot project kept the ideas (one home per thing, content by type, generated files marked, examples apart, the catalog as the root): the simulation folders became `sim/`, the scene and UI code `game/`, the editor tools the TD Tools dock, the `.asset` folders the key folders of `data/content/*.json`, and each unit's art folder one FBX.
