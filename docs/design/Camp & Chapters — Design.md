# Camp & Chapters — Design

Started 2026-10-05. Phase 1 (rules and flow) is built; the [build plan](#build-plan) lists the rest.

After Chapter 1 the player gets a home between levels: the **Camp**. From there they pick a chapter, manage their towers and hand, read the Codex, and later modify towers and play multiplayer. Until then the game stays the short, linear first hour it is now: tutorial → Chapter 1's four levels.

## Decisions

| Topic | Decision |
| --- | --- |
| Name | **Camp** (scene `CampScene`, `SceneID.Camp`) |
| Unlocks | When Chapter 1's last level is won (the catalog's `campUnlock` level). Until then: main menu → level select → level, as now |
| First visit | Winning that level offers **To the Camp** on the end screen; the first visit greets the player and points at each station once. Seeing the Camp appear is the reward for finishing Chapter 1 |
| Level select | After the unlock it is a panel inside the Camp (chapters, then a chapter's levels), not its own scene; LevelSelectScene stays for the time before |
| Chapters | **Main** chapters in order (Chapter 2 opens when Chapter 1 is cleared) and **side** chapters, each with its own unlock rule (e.g. "win Chapter 1 level 3"), listed in their own row |
| Hand | Change hand stays on every level's detail (towers keep arriving); the Camp also has the full collection screen |
| Codex | In the main menu, the Camp and a level's pause menu (not during the tutorial) |
| Main menu | Play goes to the Camp once it is unlocked (level select before). New **Continue** button: plays the next main-chapter level not won yet; hidden when there is none, and while the next one is still the first level (Play starts that) |
| After a level | Once the Camp is unlocked, the end screen's leave button and the pause menu's say **Camp**; Next level stays |
| Tutorial pause | Continue, Settings, Skip tutorial (and Quit, which counts as skipping); no Main menu, no Codex |
| Later | Tower workshop (modify towers) and multiplayer: shown in the Camp as locked stations ("coming later") |

## The Camp

A screen of stations (panels for now; built so they can become places in a visual camp once there is art):

| Station | What it does |
| --- | --- |
| **Chapters** | Main chapters in a row, side chapters below; locked ones show what opens them. Picking one opens its levels (the level select panel: list, detail, hand, Play) |
| **Towers** | Every owned tower and the hand: the hand editor, full size |
| **Workshop** | Locked: tower modification comes later |
| **Codex** | Opens the Codex |
| **Multiplayer** | Locked: comes later |
| **Main menu** | Back to the main menu |

First visit (`profile.campSeen`): a short welcome card, then each station's button highlighted in turn with one line about it; Skip ends it. Never again after that.

## Data

- `GameCatalogAsset.campUnlock`: the level whose win opens the Camp (Chapter 1 level 4).
- `ChapterData.kind` (Main / Side) and `ChapterData.unlock`: for a main chapter the previous main chapter cleared (default); for a side chapter the listed levels won (all / any). A chapter's first level opens when the chapter does.
- `PlayerProfile.campSeen`: the first visit happened.
- Engine-free rules in `Game.Meta` (`LevelCatalog`): `CampUnlocked(progress)`, chapter unlocks, `NextMainLevel(progress)` for Continue.

## Build plan

1. **Rules and flow (code):** built. catalog and chapter data, the unlock rules with tests, main menu Continue and Play, end screen and pause labels, the tutorial's pause menu.
2. **Camp scene:** scripts written (`UI_Camp`, `UI_ChapterSelect`, `UI_LevelSelect.ShowChapter`); scene and prefabs pending. `SceneID.Camp`, `UI_Camp` and its stations, the level select panel inside it (with chapter picking), `Tools > Deprecated > Set Up Camp Scene`.
3. **First visit:** the welcome card (built), then the tour: a speech bubble at each station in turn, the station highlighted, spoken by the Princess with her name and portrait like the tutorial (`UI_Camp.tourSpeaker`, `tourPortrait`) (`UI_Camp.tour`, its lines editable in the Inspector; the TourBubble prefab pending).
4. **Side chapters:** chapter kinds in the chapter row; a sample side chapter when there is content for one.

## Open questions

- What the Workshop modifies (stats, abilities, looks) and what it costs.
- Whether multiplayer is co-op or versus.
- Whether the Camp gets a visual scene (a place with stations) once there is art.
