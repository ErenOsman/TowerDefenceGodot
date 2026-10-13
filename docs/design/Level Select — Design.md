# Level Select — Design

Written 2026-10-03 as a claude.ai doc; moved into the repo on 2026-10-05. This file is now the source of truth. All four build phases are built; [Since the doc was written](#since-the-doc-was-written) lists what changed afterwards.

Level select is the screen between the main menu and a level: the player picks an unlocked level, sees what it holds, checks the hand that comes in, and plays. Winning a level unlocks the next ones and is saved as meta progress.

## Decisions

Eight choices, settled on 2026-10-03, shape the screen.

| Topic | Decision |
| --- | --- |
| Layout | **List grouped by chapter + detail panel.** A world map can come later as another skin over the same data |
| Unlock rule | **Graph**: each level lists the levels that must be won first (all or any). Linear is its simplest case |
| Which levels show | **Every unlocked level, plus one locked level** (the first locked one in catalog order) with its requirement; all other locked levels stay hidden |
| Result rating | **No stars for now.** Results are saved silently (see Progress) so stars can come later without replays |
| Progress on screen | **Not shown yet**: no best base HP, rounds or attempts in the UI |
| Hand | **Shown in level select, with "Change hand"** opening a hand popup |
| Rewards | None in the first phase (since added: first-clear rewards, see below) |
| After a win | Back to level select, and **"Next level"** on the end screen when the win opened one |

## Player flow

```text
Main menu ──Play──▶ Level select ──Play──▶ Level ──ends──▶ End screen
                        ▲                                   │
                        ├────────────── Level select ───────┤
                        │            Retry ─▶ Level (same)  │
                        │       Next level ─▶ Level (next)  │
```

The end screen always leads back into the loop: Retry or Next level start a level again, Level select returns to the list with the cursor on the level just played.

## Screen layout

```text
┌──────────────────────┬──────────────────────────────────────────────┐
│ Chapter 1            │  First Steps                    [icon]       │
│   1 First Steps  ✓   │  Slimes walk one road to your base…          │
│ ▶ 2 Spitters         │  ┌──────────┐  Waves 3 · Enemies 7           │
│   3 Two Roads (lock) │  │ minimap  │  Hand 4 · Energy 200 (+20)     │
│                      │  └──────────┘  Enemies: [Slime ×3] [Big ×2]  │
│                      │                                  [  Play  ]  │
├──────────────────────┴──────────────────────────────────────────────┤
│ Hand: [Archer][Archer][Guardian][Mage] │ [Priest] ··· (bench)       │
│                        In this level   │  Bench        [Change hand]│
└─────────────────────────────────────────────────────────────────────┘
```

The hand cap of the selected level decides where "In this level" ends: here the first 4 towers come in and the rest wait on the bench.

## Levels, chapters and unlocks

One catalog asset lists every level in play order, grouped into chapters, and says what opens each one.

- **Level identity:** `LevelAsset` has the fields the other assets have — a stable `id` (saved in progress, never the asset name), `displayName`, `description` and `icon`. Validate All flags a missing or duplicate id.
- **The catalog (`GameCatalogAsset`, one per project, loaded from Resources):** chapters in order, each with a name and its levels in order. Each entry has its level and its **requirement**: Previous (the default), Open, or a list of levels of which all or any must be won.
- **Unlocked** = its requirement is met by the saved progress. **Won** = a win was ever recorded. A won level stays playable. Shown: every unlocked level, plus the first locked level in catalog order with its requirement; every other locked level is hidden until it is the next one. Chapters with nothing to show are hidden too.
- **Default requirement:** a new entry needs the entry before it in the same chapter (the first entry of a chapter needs the last of the previous chapter), so a plain list behaves as a line without any setup. Branches are made by editing the requirement.
- **Validation:** unknown ids, requirements that point at the level itself or form a cycle, and levels nobody can ever reach are errors in Validate All.
- **Not in scope yet:** chapter art, difficulty modes, daily or challenge levels.

## Progress and results

The save keeps one record per level played, written when a level ends; unlocks are never stored, only computed from these records.

| Field | Meaning | Used for |
| --- | --- | --- |
| `levelId` | The level's stable id | Matching the catalog |
| `attempts`, `wins` | How often it was played and won | The detail panel; stats later |
| `won` | At least one win | Unlocks, the "won" mark |
| `bestBaseHpPct` | Highest share of base HP left in a win (all bases together) | Stars later, "best" line |
| `fewestRounds` | Fewest rounds in a win | Stars later, "best" line |
| `fewestTowersLost` | Fewest towers that died in a win | Stars later |
| `lastPlayed` | Date of the last attempt | Sorting, the cursor |

- **Where:** `GameData.progress` (`LevelProgress` in `Game.Meta`, engine-free and tested like `TowerCollection`), next to `GameData.towers`. The save also keeps the last selected level, so the cursor returns to it.
- **When:** the level reports its result when the session ends (won or lost; quitting from the pause menu counts as an attempt only, never a loss record).
- **Saved, not shown:** nothing in these records is shown to the player yet (no stars, no best values, no attempts on screen). They are saved from the first build, so a later stars or stats feature starts with real data.

## Level preview

Everything in the detail panel is read from the Level asset and the save, so a new level needs no extra authoring to look complete.

- **Header:** display name, chapter, icon, description.
- **Minimap:** a small picture of the map built at runtime from the Level asset (`LevelMinimap`): ground, wall and chasm tiles, the roads with each road's start marked, bases marked. Build tiles look like ground. One texture per level, no scene loaded.
- **Facts:** waves, total enemies, hand cap, start energy, energy per round.
- **Enemies:** each enemy type the waves and LevelEvents can spawn, with its icon, display name and count; hovering one shows its tooltip (HP, speed, abilities) the way the level UI does.
- **Locked level** (only the one locked level that is shown): the same panel, greyed, with the requirement ("Win Two Roads first") and Play disabled; the player can still read what is coming.

## Hand before a level

The hand strip at the bottom shows all 8 slots, and the selected level's hand cap splits them into towers that come in and towers that stay on the bench.

- **The strip:** the saved hand (`GameData.towers.hand`) as cards in order; the first `handCap` cards are lit with "In this level", the rest dimmed as "Bench". Changing the selected level moves the split at once.
- **Change hand:** a popup with the owned towers and the 8 slots: add, remove, reorder. It edits the same `TowerCollection` the Persistent Data Viewer edits and saves on close.
- **Empty or short hand:** Play still works with fewer towers; with no tower at all, Play warns ("No towers in your hand") instead of starting.
- **Starting towers:** a new save starts with the catalog's starting towers, so the screen is never empty.
- **Out of scope:** tower details beyond the card (upgrades, stats screens) belong to a later collection screen.

## Launching a level and coming back

Level select hands the GameScene one request, and the GameScene hands back one result; neither scene knows the other's internals.

- **The request (`LevelLaunch`):** a small static holder set by level select before loading `SceneID.Game`: the chosen Level asset. Retry reuses it.
- **The GameScene reads it:** `LevelController` takes the requested level and builds the hand from the saved collection (`GameCatalogAsset.BuildHand`, tower types looked up in the catalog). With no request — the GameScene played straight from the editor — it keeps the Inspector level and test hand, so development flow is unchanged.
- **The result:** when the session ends, the level writes a record into `GameData.progress` and saves. Quitting through the pause menu writes only the attempt.
- **The end screen:** Retry (same request), Level select (`SceneID.LevelSelect`), and **Next level** when the win opened a level that follows in the catalog.
- **Main menu:** Play opens level select.

## Data and code

The rules (unlocks, records) are engine-free and tested; the screen is a template-style panel in its own scene.

| Piece | Where |
| --- | --- |
| `LevelProgress`, `LevelRecord`, `LevelResult`, `LevelCatalog` (unlock check) | `Scripts/Game/Meta/` (`Game.Meta`), Edit Mode tests |
| `GameData.progress`, last selected level | `Scripts/Core/GameData.cs` |
| `id`, `displayName`, `description`, `icon`, `music` on `LevelAsset` | `Scripts/Game/Data/LevelAsset.cs` |
| `GameCatalogAsset` (chapters, levels, requirements, first-clear rewards, tower types, starting towers) | `Scripts/Game/Data/`, the asset in `Resources/` |
| Catalog checks (ids, cycles, unreachable levels) | `AssetValidator` + Validate All |
| `LevelLaunch` request | `Scripts/Gameplay/` |
| `LevelMinimap` | `Scripts/UI/LevelSelectScene/` |
| `UI_LevelSelect` (chapter list, detail panel, hand strip), hand popup | `Scripts/UI/LevelSelectScene/`, prefabs in `Prefabs/UI/LevelSelect/` |
| `LevelSelectScene` | `Scenes/`, build index 3; `SceneID.LevelSelect = 3`; `Tools > Deprecated > Set Up Level Select Scene` builds it |
| Read the request, write the result, Next level | `LevelController`, `UI_EndScreen` |

## Since the doc was written

- **First-clear rewards:** a catalog level's `firstClearReward` gives one new tower of that type on its first win (`GameCatalogAsset.GrantFirstClearReward`); the end screen says which tower joined ("A Guardian joined you!"). Chapter 1 rewards Guardian, Mage, Priest, then Archer.
- **Livelier UI:** level rows, hand cards and buttons are `UI_Button`s, all prefab-based like the level HUD.
- **Build tiles** show as plain ground on the minimap.
