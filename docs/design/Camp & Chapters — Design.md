# Camp & Chapters — Design

Started 2026-10-05. Godot pass 2026-10-15. Built in the Godot build: rules and flow, the Camp scene, the first visit; [In the Godot build](#in-the-godot-build) says what is there.

After Chapter 1 the player gets a home between levels: the **Camp**. From there they pick a chapter, manage their towers and hand, read the Codex, and later modify towers and play multiplayer. Until then the game stays the short, linear first hour it is now: tutorial → Chapter 1's four levels.

## Decisions

| Topic | Decision |
| --- | --- |
| Name | **Camp** (scene `game/ui/screens/camp.tscn`, `SceneFlow.Camp`) |
| Unlocks | When Chapter 1's last level is won (the catalog's `campUnlock` level). Until then: main menu → level select → level, as now |
| First visit | Winning that level offers **To the Camp** on the end screen; the first visit greets the player and points at each station once. Seeing the Camp appear is the reward for finishing Chapter 1 |
| Level select | After the unlock it is a panel inside the Camp (chapters, then a chapter's levels), not its own scene; the Level Select scene (`SceneFlow.LevelSelect`) stays for the time before |
| Chapters | **Main** chapters in order (Chapter 2 opens when Chapter 1 is cleared) and **side** chapters, each with its own unlock rule (e.g. "win Chapter 1 level 3"), listed in their own row |
| Hand | Change hand stays on every level's detail (towers keep arriving); the Camp also has the full collection screen |
| Codex | In the main menu, the Camp and a level's pause menu (not during the tutorial) |
| Main menu | Play goes to the Camp once it is unlocked (level select before). New **Continue** button: plays the next main-chapter level not won yet; hidden when there is none, and while the next one is still the first level (Play starts that) |
| After a level | Once the Camp is unlocked, the end screen's leave button and the pause menu's say **Camp**; Next level stays |
| Tutorial pause | Continue, Settings, Skip tutorial (and Quit, which counts as skipping); no Main menu, no Codex |
| Later | The tower Workshop is designed: Workshop — Design (2026-10-14). Multiplayer lives in the **Guild** only (never in the Camp): after Chapter 2 is cleared the Camp's **Signpost** gains **Missions**, which opens the Guild (missions, multiplayer, hand editing): Missions & Guild — Design (2026-10-14) |

## The Camp

A screen of stations (panels for now; built so they can become places in a visual camp once there is art):

| Station | What it does |
| --- | --- |
| **Chapters** | Main chapters in a row, side chapters below; locked ones show what opens them. Picking one opens its levels (the level select panel: list, detail, hand, Play) |
| **Towers** | Every owned tower and the hand: the hand editor, full size |
| **Workshop** | Modify towers: a tower turns into one of its forms, unlocked with tokens from missions (Workshop — Design). Not shown at all until Chapter 2's last level is won (`guildUnlock`, the same level that opens the Guild; Eren 2026-10-15: no greyed state) |
| **Codex** | Opens the Codex |
| **Guild** (by the Signpost) | "Guild · Missions and co-op", where Multiplayer stood; not shown until Chapter 2's last level is won (`guildUnlock`). Opens the Guild, where missions (the source of tokens) and multiplayer live (Missions & Guild — Design): the Camp slides out to the left while the Guild comes in from the right. A gold "New" on the button until the first Guild visit. Until then the Signpost is a plain prop |
| **Main menu** | Back to the main menu |

First visit (`profile.campSeen`, `PlayerProfile.camp_seen`): a short welcome card, then each shown station's button highlighted in turn with one line about it; Skip ends it. Never again after that. After Chapter 2 is cleared, the next visit points once at the two buttons that appeared (Guild, then Workshop).

## Camp v2 — a settlement with the Guild and the Smithy (2026-10-17)

Eren (2026-10-17): "buranın baştan tasarlanması lazım, yeni guild ve blacksmith'i akılda bulundurarak". The Camp is
redesigned around the two places that now have interiors. What follows is the agents' proposal, to be built from the
UI/UX mockup and the Blender kit; Eren decides on the frames.

| Topic | Decision | Source |
| --- | --- | --- |
| What the Camp is | A small outdoor **settlement** on a 14×10 board (the interiors' size), not a ring of props round a fire. The **Guild hall** and the **Smithy** stand as **buildings** with doors; the smaller stations stay props | agents |
| Where things stand | Back row, left: the **Smithy** facade (forge chimney, anvil sign). Back row, right: the **Guild hall** facade (flag, signpost by its door). Between them, further back: hills/trees (decor). Middle: the campfire and the player's tent. Front sides: the map table (**Chapters**, left-front), the tower rack (**Towers**, right-front), the lectern (**Codex**, front, by the tent). The sides match the slides: the Blacksmith slides in from the left, the Guild from the right | agents (slide directions, Eren 2026-10-16) |
| Buttons | One station button per station, on the floor in front of the prop/door (the shared placement rule), **no sub-lines**; Chapters stays the primary. The building doors are also hotspots | Eren 2026-10-17 (no lines under buttons) |
| Before Chapter 2 | The two buildings stand there **closed** (door shut, dark windows, no button, no hotspot); after Chapter 2 the doors open, lanterns light, the buttons appear, and the mini tour points at them once | Eren (hidden before Chapter 2, 2026-10-15) · agents (closed buildings instead of empty slots) |
| Art | Blender kit `art/camp/v2/`: Smithy Facade, Guild Hall Facade (each with Idle: smoke, flag), Hills backdrop, Trees; the existing props (fire, tent, map table, rack, lectern, signpost) are reused; `layout.json` in the interiors' schema (slots, centre, decor) | agents |
| Transition | Unchanged: Guild slides in from the right, Blacksmith from the left; Main menu ⇄ Camp fades | Eren |

Build plan: 1) UI/UX mockup of the settlement (camp-v2.html) and its closed/open states; 2) Blender kit (facades, backdrop) with layout.json; 3) Godot: camp.gd reads the v2 layout (station ids unchanged: Chapters, Towers, Workshop → Blacksmith, Codex, Guild), closed/open building states, the tour lines.

## Data

- `campUnlock` in `data/content/Catalog.json` (`GameCatalogAsset.camp_unlock`): the level whose win opens the Camp (Chapter 1 level 4, `Level/Chapter 1/4 The Slime King`).
- A catalog chapter's `kind` (Main / Side) and its unlock (`requires`, `requireAll`; `ChapterData`): for a main chapter the previous main chapter cleared (default); for a side chapter the listed levels won (all / any). A chapter's first level opens when the chapter does.
- `PlayerProfile.camp_seen` (saved as `campSeen`): the first visit happened. `PlayerProfile.guild_tour_seen` (`guildTourSeen`): the mini tour pointing at the Guild and Workshop buttons after Chapter 2 happened.
- `art/camp/layout.json` (and `art/guild/layout.json`): where the props stand (slots with their station, centre, decor). Eren can move props in the running game with the dev panel's layout editor (F1 → Edit layout; drag, Q/E, +/-, Ctrl+S saves the same file): `docs/Implementation Notes.md` § Layout editor.
- Engine-free rules: `GameCatalogAsset.camp_unlocked(progress)` (`sim/data`), and in `sim/meta/level_catalog.gd` (`LevelCatalog`) the chapter unlocks (`is_chapter_unlocked`) and `next_main_level(progress)` for Continue.

## In the Godot build

- **Rules and flow:** built: catalog and chapter data, the unlock rules with tests, main menu Continue and Play, end screen and pause labels, the tutorial's pause menu.
- **Camp scene:** built as a 3D camp (`game/ui/screens/camp.gd`): station props laid out from the Blender kit's `art/camp/layout.json` on map-kit ground (the shared `TdStationWorld`), a station button by each prop (`camp.gd` `STATIONS`). Chapters opens the chapter picker (`chapter_select.gd`), then a chapter's levels in the level select panel (`level_select.gd` inside the Camp).
- **First visit:** built: the welcome card, then the tour: the Princess's speech bubble (`TdTextBubble`, her name and portrait) points at each station in turn, the station highlighted; a click goes on, Skip ends it. The lines are in `camp.gd` (`TOUR`).
- **Side chapters:** the chapter picker has the side-chapter row (hidden while there are none); there is no side chapter in the content yet.

History: in the Unity project only the rules and flow were finished; the Camp scene's scripts (`UI_Camp`, `UI_ChapterSelect`, `UI_LevelSelect.ShowChapter`) were written, with the scene, prefabs and the tour bubble still pending and the tour lines edited in the Inspector.

## Open questions

- ~~What the Workshop modifies (stats, abilities, looks) and what it costs.~~ Answered in Workshop — Design (2026-10-14): forms unlocked with tokens.
- Whether multiplayer is co-op or versus.
- Whether the Camp gets a visual scene (a place with stations) once there is art.
