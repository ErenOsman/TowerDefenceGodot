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
| Later | The tower Workshop is designed: Workshop — Design (2026-10-14). Multiplayer moves to the **Guild**: after Chapter 2 is cleared the Camp's **Signpost** gains **Missions**, which opens the Guild (missions, multiplayer, hand editing): Missions & Guild — Design (2026-10-14) |

## The Camp

A screen of stations (panels for now; built so they can become places in a visual camp once there is art):

| Station | What it does |
| --- | --- |
| **Chapters** | Main chapters in a row, side chapters below; locked ones show what opens them. Picking one opens its levels (the level select panel: list, detail, hand, Play) |
| **Towers** | Every owned tower and the hand: the hand editor, full size |
| **Workshop** | Modify towers: a tower turns into one of its forms, unlocked with tokens from missions (Workshop — Design). Locked with "Opens after Chapter 2" until Chapter 2's last level is won (`guildUnlock`, the same level that opens the Guild) |
| **Codex** | Opens the Codex |
| **Signpost → Missions** | Appears once Chapter 2's last level is won (`guildUnlock`): opens the Guild, where missions (the source of tokens) and multiplayer live (Missions & Guild — Design). Until then the Signpost is a plain prop |
| **Multiplayer** | Moved to the Guild (2026-10-14). In the Godot build the Camp's Multiplayer station opens the co-op lobby until the Guild opens, then is a shortcut to the Guild until the first Guild visit (`profile.guildSeen`), then disappears |
| **Main menu** | Back to the main menu |

First visit (`profile.campSeen`, `PlayerProfile.camp_seen`): a short welcome card, then each station's button highlighted in turn with one line about it; Skip ends it. Never again after that.

## Data

- `campUnlock` in `data/content/Catalog.json` (`GameCatalogAsset.camp_unlock`): the level whose win opens the Camp (Chapter 1 level 4, `Level/Chapter 1/4 The Slime King`).
- A catalog chapter's `kind` (Main / Side) and its unlock (`requires`, `requireAll`; `ChapterData`): for a main chapter the previous main chapter cleared (default); for a side chapter the listed levels won (all / any). A chapter's first level opens when the chapter does.
- `PlayerProfile.camp_seen` (saved as `campSeen`): the first visit happened.
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
