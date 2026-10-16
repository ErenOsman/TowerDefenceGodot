# Documentation

**These are the live docs.** Since 2026-10-15 the Godot build is the game (docs/Decisions.md, "Project and tools"):
the design docs in `docs/design/`, the decision log `docs/Decisions.md` and the glossary `docs/Glossary.md` are edited
**here**. The Unity repo's `Docs/` (ErenOsman/TowerDefenceProject) is frozen as of 2026-10-15 and is no longer
updated or synced; `~/uiux/push-doc.sh` (which pushed docs into the Unity repo) is retired — commit doc changes to
this repo instead.

## Live

| You want to know… | Read |
| --- | --- |
| What the game is and how a level plays | [Game Overview](design/Game%20Overview%20—%20Design.md) |
| What a word means | [Glossary](Glossary.md) |
| Why something is the way it is | [Decision log](Decisions.md) (newest first, by area) |
| How a system works, what is decided | the design docs below |
| How the Godot build does things (engine notes, tools, golden, daemons, content check) | [Implementation Notes](Implementation%20Notes.md) |
| The content files, the key convention and who writes them | [Content](Content.md) |
| The co-op relay protocol | [Co-op Protocol](Co-op%20Protocol.md) |
| What was made by AI, and what to replace first | [AI Usage](AI%20Usage.md) |
| What towers, enemies, statuses and levels exist, with their numbers | [Game reference](reference/README.md) (generated, see below) |
| The simulation port and its verification | [Sim Port](Sim%20Port.md), the game layer [Architecture](Architecture.md) |

### Design docs (`design/`)

| Doc | About |
| --- | --- |
| [Game Overview](design/Game%20Overview%20—%20Design.md) | the game in one page: board, turns, towers, enemies, energy |
| [Entity System](design/Entity%20System%20—%20Design.md) | units, stats, tags, footing, kinds |
| [Ability Pipeline — Effect Queue Architecture](design/Ability%20Pipeline%20—%20Effect%20Queue%20Architecture.md) | abilities, steps, the effect queue, reactions, replacements |
| [Formula System](design/Formula%20System%20—%20Design.md) | the formula language for numbers |
| [Condition System](design/Condition%20System%20—%20Design.md) | conditions and filters |
| [Instinct](design/Instinct%20—%20Design.md) | how abilities aim by themselves (enemies, quick cast) |
| [Tiles](design/Tiles%20—%20Design.md) | maps as layers: terrain, build, road, visual, props |
| [Animation & Presentation](design/Animation%20&%20Presentation%20—%20Design.md) | the event log played back by the Director |
| [Level Select](design/Level%20Select%20—%20Design.md) | the level select screen |
| [Camp & Chapters](design/Camp%20&%20Chapters%20—%20Design.md) | the Camp hub, chapters, unlocks |
| [Chapter 2](design/Chapter%202%20—%20Design.md) | Chapter 2's levels and gimmicks |
| [Codex](design/Codex%20—%20Design.md) | the in-game reference book |
| [Tutorial, First Run & Sequences](design/Tutorial,%20First%20Run%20&%20Sequences%20—%20Design.md) | first run, sequences, dialogue |
| [Guided Tutorial](design/Guided%20Tutorial%20—%20Design.md) | the step-by-step tutorial level |
| [Workshop](design/Workshop%20—%20Design.md) | tower forms and tokens |
| [Missions & Guild](design/Missions%20&%20Guild%20—%20Design.md) | missions, the Guild, tower energy, token drops |
| [Blacksmith](design/Blacksmith%20—%20Design.md) | the Blacksmith place: Modify and Upgrade |
| [Upgrades](design/Upgrades%20—%20Design.md) | tower levels, tasks, gold Pay tasks, bonuses |
| [Backpack](design/Backpack%20—%20Design.md) | what the player carries: gold, tokens |
| [Multiplayer](design/Multiplayer%20—%20Design.md) | co-op: lobby, rooms, pools, relay |
| [UI Design Rules](design/UI%20Design%20Rules%20—%20Design.md) | the UI rules (kit, layout, screens) |
| [Style & Art Direction](design/Style%20&%20Art%20Direction%20—%20Design.md) | "Painted Miniatures on a Diorama Board", the Blender pipeline |
| [Folder Structure](design/Folder%20Structure%20—%20Design.md) | where everything in the project lives |

### Generated

- `reference/` — the game reference (Towers, Enemies, Statuses, Levels, Codex), generated from `data/content` by
  `tools/game_reference.gd` (`godot --headless --path . -s tools/game_reference.gd`). **Regenerate it after content
  changes** and commit it with them; never edit it by hand ([README-snapshot](reference/README-snapshot.md)).

### Working notes (`notes/`)

Kept for context; useful but not maintained as rules (the design docs win where they differ):
[For Eren](notes/For%20Eren.md), [Handoff](notes/Handoff.md), [VFX kit README](notes/VFX-KIT-README.md), and the UI
kit notes in `notes/ui/` ([HUD & menu spec](notes/ui/hud-menu-spec.md), [Kit B README](notes/ui/kit-b-README.md),
[screen-size fixes](notes/ui/screen-size-fixes.md), [UI components plan](notes/ui/ui-components-plan.md),
`manifest_ui.json`, `font-characters.txt`).

## Archive (`archive/`, frozen, not updated)

From the Unity repo, as of 2026-10-15: the [Unity changelog](archive/Changelog%20(Unity,%20to%202026-10-15).md), the
[C# combat implementation notes](archive/Combat%20—%20Implementation%20Notes%20(Unity%20C%23).md) and the
[old Unity Docs index](archive/README%20(Unity%20Docs%20index).md). Read them for history; they describe the Unity
code, not this build.
