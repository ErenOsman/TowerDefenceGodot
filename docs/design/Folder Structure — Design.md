# Folder Structure — Design

Started 2026-10-05; the [Decisions](#decisions) table records how each part was settled.

Where everything in the project lives, and the rules that keep it there. The goal is that someone new — a person or an agent — can guess where a thing is before searching, and knows where a new thing goes without asking.

## Principles

1. **One home per thing.** Every file has exactly one right folder, decided by *what it is*, not by who made it or when.
2. **Content by type, art by unit.** Game data is sorted by asset type (all abilities together); art is sorted by the unit it belongs to (everything the Slime needs in one folder).
3. **Docs outside Assets.** Documentation is read on GitHub and in editors, never imported by Unity.
4. **Generated files say so, and are never edited by hand.** The game reference, placeholder models and Chapter 1 content come from tools; change the tool or the source, then regenerate.
5. **Demo content is kept apart.** Examples the game does not use live in `Examples/` subfolders, so the real content reads clean.
6. **Resources only for what is loaded by name.** Everything in Resources ships with the game whether used or not.
7. **Moves keep GUIDs.** Assets move inside Unity (drag in the Project window, `Tools > Project > Sort Data and Art`, or the move queue), never by file moves that leave the `.meta` behind.

## The tree

```text
TowerDefenceProject/
├── README.md                 what the project is, how to open it, where to start
├── CLAUDE.md                 entry point for Claude Code (points to Assets/.agents)
├── Docs/                     all documentation (see Docs/README.md)
│   ├── Design/               design docs, one per system
│   ├── Reference/            GENERATED: towers, enemies, statuses, levels with their numbers
│   ├── Notes/                older snapshots
│   └── Changelog.md, Decisions.md, Glossary.md, README.md, Combat — Implementation Notes.md
├── Assets/
│   ├── .agents/              guides for agents and people: AGENTS (rules), CONTEXT (architecture), MAPPING (file map)
│   ├── Scripts/              code, see below
│   ├── Editor/               editor-only code, see below
│   ├── Tests/EditMode/       Edit Mode tests (Game.Tests)
│   ├── Data/                 game content (ScriptableObjects), by type
│   ├── Art/                  models, materials, textures, icons, UI sprites, fonts, VFX
│   ├── Audio/                music, sound effects, the mixer
│   ├── Prefabs/UI/           UI prefabs by screen (model and effect prefabs live in Art)
│   ├── Scenes/               Boot, MainMenu, LevelSelect, Game; Test/ for scratch scenes
│   ├── Resources/            only GameCatalog
│   └── TextMesh Pro/         package content (not ours; leave as is)
├── Packages/, ProjectSettings/   Unity project files (tracked)
├── Builds/                   game builds by platform and version (git-ignored), see Builds below
└── Library/, Temp/, Logs/, UserSettings/, *.csproj, *.sln   generated (git-ignored)
```

## Code: `Assets/Scripts` and `Assets/Editor`

The folder decides the assembly and the namespace.

| Folder | Assembly | Namespace | What goes here |
| --- | --- | --- | --- |
| `Scripts/Game/Formulas`, `Combat`, `Level`, `Meta`, `Presentation` | one asmdef each, no engine references | `Game.<Folder>` | The game rules: the engine-free simulation |
| `Scripts/Game/Data` | `Game.Data` | `Game.Data` | ScriptableObject asset types and the converter to the simulation's defs |
| `Scripts/Gameplay` | Assembly-CSharp | `Game.Gameplay` | Presentation in the scene: level controller, board, views, presenters, camera |
| `Scripts/UI/<Scene>` | Assembly-CSharp | `Core.UI` | One subfolder per scene for its panels (`GameScene`, `LevelSelectScene`…); shared UI in `CoreUI`, `Elements` |
| `Scripts/Core` | Assembly-CSharp | `Core` | Template singletons and data (managers, save data) |
| `Scripts/Utils` | Assembly-CSharp | `Core.Utils` | Standalone helpers (`Timer`, `InputHelper`) |
| `Editor/Game` | `Game.Editor` | `Game.EditorTools` | Game tools: builders, editors, validators, exporters, the folder tools |
| `Editor/Gameplay`, `Editor/UI`, `Editor/Setup`, `Editor/Debug`, `Editor/Inspectors` | Assembly-CSharp-Editor | `Core.EditorTools` / `Game.EditorTools` | Scene and UI builders, project setup tools, debug windows, custom inspectors |
| `Tests/EditMode` | `Game.Tests` | `Game.Tests` | Edit Mode tests |

Rules: editor code never lives under `Scripts/` (AGENTS Rule 9); UI scripts never live outside `Scripts/UI/` (Rule 5).

## Content: `Assets/Data`

One folder per asset type; `DataFolders` in `Editor/Game` is the single source of these paths.

| Folder | Holds |
| --- | --- |
| `Towers/` | Tower types (`TowerAsset`): cost, entity, type ID |
| `Units/Towers/`, `Units/Enemies/`, `Units/Bases/`, `Units/Other/` | Entities (`EntityAsset`) by role: towers (off the road), enemies (on the road), bases (tagged Base), the rest (hazards, objects) |
| `Abilities/`, `Passives/`, `Reactions/`, `Statuses/`, `Items/` | One folder per rule type |
| `Levels/<Chapter>/` | Catalog levels by chapter (`Levels/Chapter 1/`); `Levels/Other/` for levels outside the catalog (Example Level, test levels) |
| `Presentation/` | Ability presentations (projectile, VFX, sounds, shake) |
| `Settings/` | Game Rules, Presentation Timings |
| `<Type>/Examples/` | Demo content the game catalog does not use |

- **Inside a type folder, organise freely**: `Abilities/Archer/Shoot.asset` is fine; the sorter leaves subfolders alone.
- **Content is found by type and name**, never by path (`DataFolders.Find`), so tools survive moves.
- **The game catalog** (`Resources/GameCatalog.asset`) is the root of what the game uses: anything it reaches (directly or through other assets) is game content; anything else is an example.

## Art: `Assets/Art`

| Folder | Holds |
| --- | --- |
| `Models/<Unit>/` | Everything one unit's look needs: model prefab, Animator controller, clips, its own materials. Units that reuse another's rig use that unit's controller and clips (the Runner uses `Models/Slime/`) |
| `Materials/` | Materials several models share |
| `Textures/` | Textures not owned by one model |
| `Icons/` | Every content icon — abilities, statuses, units, towers — also when the interface uses it too |
| `UI/` | Interface-only sprites: bars, frames, the energy and HP icons |
| `VFX/` | Effects and projectiles |
| `Fonts/` | Fonts |
| `…/Placeholder/` | Generated placeholder art (`Create Example Model`) that several units share |

**When real art arrives for a unit:** put it in `Models/<Unit>/` beside the placeholder, switch the unit's `view` to it, test, then delete the placeholder files. `Create Example Model` never replaces a view or presentation that is not one of its own placeholders, and keeps existing placeholder files as they are (hand tweaks survive); `Rebuild Example Models (overwrite)` redoes the placeholders only.

## Everything else

| Folder | Holds |
| --- | --- |
| `Audio/Music/`, `Audio/SFX/` | Music tracks and sound effects; the mixer at `Audio/` |
| `Prefabs/UI/<Screen>/` | UI prefabs by screen (`Level`, `LevelSelect`, `MainMenu`, `Pause`, `Settings`) plus shared `Elements` — restyle the game by editing these. Model and effect prefabs are art and live in `Art/` |
| `Scenes/` | One scene per `SceneID` (Boot 0, MainMenu 1, Game 2, LevelSelect 3); scratch and test scenes in `Scenes/Test/`, never in the build list |
| `Resources/` | Only assets the code loads by name |

No empty "just in case" folders in `Scripts/` or `Prefabs/`: a folder is made when its first file arrives (the folders in `Data/` and `Art/` are the exception — they show people where things go, and keep a `.gitkeep`).

## Builds: `Builds/` (repo root, git-ignored)

```text
Builds/
├── Windows/
│   ├── 0.1/            TowerDefenceProject.exe and its data
│   ├── 0.1.zip         the same, zipped to share
│   ├── 0.2/
│   └── 0.2.zip
└── Web/
    └── Test/           the latest web test build (Tools > Build > Web (test build)), replaced each time
```

- **`Builds/<Platform>/<version>/`** for every build kept: `Windows`, `Web`, later `Mac`, `Android`… The version is just the folder's name (`0.1`, `0.2`…); it does not have to match the Player Settings version.
- **A zip beside the folder** (`0.2.zip`) is what gets shared.
- **Test builds** go to `Builds/<Platform>/Test/` and are overwritten every time; they are never kept as versions.
- **Tools > Build** makes them: `Web (test build)`, `Windows (dev build)` (a development build into `Builds/Windows/Test/`) and `Windows (release)` (the next version, one above the highest `Builds/Windows/<version>` folder, with its zip; Player Settings' version is set to it so the game's version label matches).
- **Builds never go into git.** Share them through itch.io or GitHub Releases. Old versions can be deleted when the disk is tight; any version can be rebuilt from its commit.

## Naming

- **Content assets** are named as players see them (`Slime King`, `Firebolt`); their stable `id` field is what saves and rules use, so renaming a file is safe.
- **Levels** start with their number in the chapter (`1 First Steps`) so folders list them in play order.
- **Art** starts with its unit (`Slime Walk`, `Brute Skin`); model prefabs end in `Model` (`Slime King Model`).
- **Folders** are plural for collections (`Abilities`, `Models`) and Title Case with spaces like asset names.

## The tools that keep it this way

| Tool | Use |
| --- | --- |
| `Tools > Project > Sort Data and Art` | Moves misplaced content into its type folder (examples into `Examples/`); safe to rerun |
| `AssetMoves.txt` / `Tools > Project > Apply Asset Moves` | Moves on request from outside the editor (agents, scripts), GUIDs kept |
| `Tools > Docs > Export Game Reference` (or `bash Tools/Offline/offline.sh docs`) | Regenerates `Docs/Reference` after content changes |
| `Tools > Combat > Validate All` | Catches broken references and bad content after moves |

## Decisions

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
