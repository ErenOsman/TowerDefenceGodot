# Documentation

Start here. Everything about the game lives in this folder, plus the agent guides in `Assets/.agents/`.

## What to read

| You want to know… | Read |
| --- | --- |
| What the game is and how a level plays | [Game Overview](Design/Game%20Overview%20—%20Design.md) |
| What a word means | [Glossary](Glossary.md) |
| What towers, enemies, statuses and levels exist, with their numbers | [Game reference](Reference/README.md) (generated) |
| What changed lately | [Changelog](Changelog.md) |
| What was made by AI, and what to replace first | [AI usage](AI%20Usage.md) |
| Why something is the way it is | [Decision log](Decisions.md) |
| How a system works | The design docs below |
| Where the code differs from the design docs | [Combat — Implementation Notes](Combat%20—%20Implementation%20Notes.md) |
| How the code is organised, its conventions, how to extend it | `Assets/.agents/CONTEXT.md` |
| Where each file is | `Assets/.agents/MAPPING.md` |
| The rules for working on the code (people and agents) | `Assets/.agents/AGENTS.md` |

## Design docs

| Doc | Covers |
| --- | --- |
| [Game Overview](Design/Game%20Overview%20—%20Design.md) | The game, the loop, rounds and phases, open questions |
| [Entity System](Design/Entity%20System%20—%20Design.md) | Entities, stats, statuses, passives, items |
| [Ability Pipeline](Design/Ability%20Pipeline%20—%20Effect%20Queue%20Architecture.md) | Abilities as steps, the effect queue, checkpoints, reactions, replacements |
| [Formula System](Design/Formula%20System%20—%20Design.md) | Formulas: numbers written as text |
| [Condition System](Design/Condition%20System%20—%20Design.md) | Conditions: yes/no written as text |
| [Instinct](Design/Instinct%20—%20Design.md) | Automatic aiming: enemy turns, quick cast, Pick, Taunted and Redirected |
| [Animation & Presentation](Design/Animation%20&%20Presentation%20—%20Design.md) | The event log, the Director, presenters, view frames, camera |
| [Level Select](Design/Level%20Select%20—%20Design.md) | Catalog, unlocks, progress records, the level select screen, the hand |
| [UI Design Rules](Design/UI%20Design%20Rules%20—%20Design.md) | Style B "Painted Diorama" UI: rules, tokens, components and decisions (from the server's UI/UX agent). Kit notes in `Notes/UI/` |
| [Style & Art Direction](Design/Style%20%26%20Art%20Direction%20—%20Design.html) | "Painted Miniatures": the art style of the models, boards and props (HTML, open in a browser) |
| [Multiplayer](Design/Multiplayer%20—%20Design.md) | Draft: what the deterministic rules give multiplayer (lockstep), possible modes (co-op, versus, async), open questions |
| [Tiles](Design/Tiles%20—%20Design.md) | Draft: terrain as content, build tiles, roads as start + moves (corners, edges, loops), the map in the battle state, changing tiles at runtime |
| [Folder Structure](Design/Folder%20Structure%20—%20Design.md) | Where everything lives and why, naming, the tools that keep it tidy |
| [Tutorial, First Run & Sequences](Design/Tutorial,%20First%20Run%20&%20Sequences%20—%20Design.md) | Welcome screen, player name, the tutorial level, speech bubbles and sequences (planned) |
| [Codex](Design/Codex%20—%20Design.md) | The in-game reference: towers, enemies, statuses and tips, discovered as the player plays, with a turning model preview |
| [Camp & Chapters](Design/Camp%20%26%20Chapters%20—%20Design.md) | The Camp (home between levels after Chapter 1: chapters, towers, Codex; later workshop and multiplayer), main and side chapters, Continue (planned) |
| [Chapter 2](Design/Chapter%202%20—%20Design.md) | The second main chapter: rocks, rabbits, Rockjaws, a War Drum ally, bats over a chasm, the Slime Glutton; the Wisp tower |

## Keeping the docs true

- **Content changed** (stats, abilities, levels): run `bash Tools/Offline/offline.sh docs` (from the content JSON, no Unity needed) or `Tools > Docs > Export Game Reference` in Unity, and commit `Reference/`. Never edit those pages by hand.
- **A change worth noticing is done**: add a line to the [changelog](Changelog.md) under today's date.
- **Something was added or replaced** (art, sound, text, content, code): update its row in [AI usage](AI%20Usage.md).
- **A decision was made or reversed**: add a line to the [decision log](Decisions.md).
- **A new term appeared**: add it to the [glossary](Glossary.md).
- **A system changed shape**: update its design doc (or the implementation notes, when the code knowingly differs from the design).
- **Files added, moved or removed**: update `Assets/.agents/MAPPING.md`; a new pattern or system also goes into `CONTEXT.md`.
