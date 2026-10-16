# Blacksmith — Design

Written 2026-10-16 by the Godot agent from Eren's decisions of the same day; the points he left open are decided
here and marked **(agents)**. This doc is the source of truth for the Blacksmith place, tower **levels** (the
Upgrade mechanic) and **gold**. Workshop — Design (forms and tokens) keeps the Modify station's rules; Missions &
Guild — Design keeps the missions, which now also drop gold.

The **Blacksmith** is a place like the Guild, reached from the Camp (its button slides the screen, like the Guild's)
once Chapter 2 is cleared. It holds **Modify** (the Workshop: a tower turns into one of its forms, paid with tokens)
and **Upgrade** (new: a tower rises in **level** by completing that tower's **tasks** and paying **gold**). Every
tower starts at level 1 when the Blacksmith opens. A form never passes its base tower's level.

## Decisions

| Topic | Decision | Source |
| --- | --- | --- |
| Where | A **Blacksmith** place, like the Guild: a station button in the Camp (the Workshop's spot and prop, the anvil table), hidden until Chapter 2 is cleared, sliding to its own screen; back slides to the Camp. Stations: **Modify** (the Workshop tree, unchanged), **Upgrade**, **Towers** (hand editor), **Camp** | Eren 2026-10-16 (Blacksmith with modify and upgrade) · agents (stations, slide like the Guild) |
| Levels | Every tower (each individual, by its id) has a **level**, 1 when the Blacksmith opens, up to the type's **max level** (5 for now, data). A level is gained by pressing **Upgrade** once that level's **tasks** are complete and its **gold** is paid | Eren (all towers level 1 after Chapter 2; tasks; press Upgrade) · agents (per individual tower, max 5) |
| Tasks | Each level step of a tower type lists its tasks, e.g. Archer 1 → 2: "Win a mission with this tower" and "100 gold". Tasks are counted **per tower** (this Archer, not any Archer). Kinds (data): win a mission with the tower in the hand; win N levels with it; N kills by it; N damage dealt; N hits taken without dying; place it N times; a specific mission; a win without losing a tower | Eren (example) · agents (the kinds) |
| Gold | **Gold** is a new currency: missions drop it (`winGold` every win, `firstWinGold` once), like tokens. Spent only on upgrades for now. Tokens stay the Workshop's currency | Eren (gold = missions' reward) · agents (only upgrades spend it, for now) |
| What a level gives | Stat bonuses set per tower type and level in the content: e.g. Archer level 2 +2 Power, level 3 +5 Max HP, …; a level may also add or change an ability at a set step (data allows it; the starter content uses stats only). Bonuses are modifiers on the tower's entity, so previews and the Codex show them | agents |
| Forms and levels | Each **unlocked form** of a tower has its **own level and tasks** (in Forms.json), but a form's level can **never exceed the base tower's level**: the Upgrade button for a form is disabled with "Raise Archer to level 3 first". The tower fights with the level bonuses of its **current** form (base or form) | Eren (forms ≤ base) · agents (own levels per form; current form's bonuses) |
| Before Chapter 2 | No levels exist: nothing shows "Lv", no tasks count, no gold drops. On the first Blacksmith visit every tower is level 1 and its level-1 → 2 tasks start counting from then (earlier wins do not count) | Eren (level 1 after Chapter 2) · agents (counting starts at the unlock) |
| Shown where | A small **Lv n** chip on the tower's card (hand select, Workshop picker, tray piece, board medallion, Codex "In your collection" rows); the Upgrade station shows the tasks with progress; the end screen lists task progress gained in that level/mission ("Archer: Win a mission ✓") | agents |
| Codex | Read-only: the tower page's Overview gets a "Levels" line listing what each level gives (from the content); no tasks there | agents |
| Content | `Content/Towers.json` gains `levels`; `Forms.json` the same; `Missions.json` gains gold drops; `Tokens.json` untouched; a `Gold` currency entry is not an asset (one number in the wallet) | agents |

## Player flow

```text
Camp ──Blacksmith──▶ Blacksmith ──Upgrade──▶ Tower picker ──▶ Upgrade view (level, tasks, gold, Upgrade) ──Back──▶ picker
                          ├──Modify──▶ Workshop picker → Modify view (as today)
                          ├──Towers──▶ Hand editor
                          └──Camp──▶ Camp (slide back)
```

A mission win: the end screen shows the gold earned and the tasks that advanced; the Blacksmith's Upgrade station
button shows "N ready" when some tower can be upgraded now.

## The Upgrade view

```text
┌ ← Back   Archer  #1 · tower 3   Lv 2                              gold 🪙 240 ┐
│ This tower now          │ Level 3                           │ What it gives     │
│ portrait, Lv 2          │ Tasks                             │ +5 Max HP         │
│ Max HP 20 · Power 12    │ ✓ Win a mission with this tower   │ +1 Range          │
│ Range 2 · Speed 2       │ ○ Deal 60 damage with it   42/60  │                   │
│ abilities               │ ○ 150 gold          you have 240  │ Then: Level 4     │
│                         │ [      Upgrade to level 3      ]  │ Win 2 missions …  │
│ Forms: Fire Archer Lv 1 │ (disabled: "Deal 18 more damage") │                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

- **Picker**: the collection as in the Workshop, each tile with its Lv chip and a small "ready" mark when the
  tower can be upgraded; a filter "Ready to upgrade".
- **Upgrade view**: left the tower as it is now (its current form's stats); centre the next level's tasks with
  progress and the gold line; the single action **Upgrade to level n**, enabled only when every task is done and
  the gold is there, otherwise disabled with the first missing thing as its reason. Right: what the level gives
  and a preview of the level after. At max level: "Max level" and the list of what the levels gave.
- **Forms**: a row under the tower lists its unlocked forms with their levels; picking one shows that form's tasks;
  its Upgrade is disabled with "Raise <base> to level n first" while the base is behind.
- **Confirm**: Upgrade asks once through the confirm popup ("Upgrade Archer to level 3? Spends 150 gold.").

## Rules

- **Level** is saved per owned tower (`OwnedTower.level`, default 1) and per unlocked form (`OwnedTower.form_levels`,
  form id → level, default 1). `max level` comes from the type's `levels` list length + 1.
- **Tasks** are defined per level step (the step to level n lists what level n needs). Progress is saved per tower and
  per form (`OwnedTower.task_progress`: step → task index → count). Counting starts at the Blacksmith unlock; only
  towers present in a won level/mission count "win" tasks, and only the acting tower counts kills/damage/hits.
  The sim already logs every event with the acting entity and the owned tower id, so the level's end records the
  counts without new sim rules (`TowerTasks.apply(result, log, towers)`, engine-free, in `sim/meta`).
- **Upgrade** needs: every task of the step complete, the gold, and for a form: base level > form level. It spends
  the gold, raises the level, resets that step's progress and starts the next step's counting.
- **Bonuses** are modifiers listed per level (`{stat, kind: Flat|PctAdd, amount}`) applied to the tower's entity
  when a level is built from the owned tower (`Workshop.resolve` → `TowerLevels.apply`); cumulative over levels.
  A form's bonuses are its own list; the base's bonuses do not carry into a form (each form has its own ladder).
- **Gold** lives in the wallet next to tokens (`TokenWallet.gold`, with earned total); missions grant it with their
  token drops; chapter levels drop none; dev shortcuts can grant it.
- **Co-op**: a tower's level travels with its hand entry (`"<type>@<form>:L<n>"`), so both clients build the same
  entity; tasks count for each player's own towers.
- **Validation**: every task kind is known; counts > 0; gold ≥ 0; a level's modifiers name real stats; a form's
  ladder is not longer than its base's; every mission gold drop ≥ 0; at least one mission drops gold.

## Data

### Towers.json / Forms.json — `levels`

```json
"levels": [
  { "to": 2, "gold": 100, "tasks": [ { "kind": "WinMission", "count": 1 } ],
    "bonuses": [ { "stat": "Power", "kind": "Flat", "amount": "2" } ] },
  { "to": 3, "gold": 150, "tasks": [ { "kind": "WinMission", "count": 1 }, { "kind": "Damage", "count": 60 } ],
    "bonuses": [ { "stat": "MaxHp", "kind": "Flat", "amount": "5" } ] }
]
```

Task kinds: `WinMission` (count missions won with the tower in the hand), `WinLevel`, `WinMissionId` (`mission`),
`Kills`, `Damage`, `HitsTaken` (survived), `Placed`, `WinNoLoss` (a win without losing a tower). Task texts come
from the kind and count ("Win a mission with this tower", "Deal 60 damage with it"); a task may give its own `text`.

### Missions.json — gold

`winGold` (every win) and `firstWinGold` (once), integers, next to the token drops.

### Catalog.json

`blacksmithUnlock` = the same level as `guildUnlock` (Chapter 2's last) unless changed.

### Saves

`OwnedTower.level`, `form_levels`, `task_progress`; `TokenWallet.gold` / `gold_earned`; `PlayerProfile.blacksmith_seen`.
Engine-free rules in `sim/meta/tower_levels.gd` (`max_level`, `step_for`, `can_upgrade(tower, form, wallet) → reason`,
`upgrade`, `bonuses_at`, `apply`) and `sim/meta/tower_tasks.gd` (`describe`, `apply(result, log, towers)`).

## Starter content (placeholders; Eren rewrites)

| Tower | To level | Gold | Tasks | Gives |
| --- | --- | --- | --- | --- |
| Archer | 2 | 100 | Win a mission with it | +2 Power |
| Archer | 3 | 150 | Win a mission; deal 60 damage | +5 Max HP |
| Archer | 4 | 250 | Win 2 missions; 10 kills | +1 Range |
| Archer | 5 | 400 | Win 3 missions; a win without losing a tower | +3 Power, +5 Max HP |
| Guardian | 2 | 100 | Win a mission with it | +10 Max HP |
| Guardian | 3 | 150 | Win a mission; take 40 hits and survive | +2 Power |
| … | | | the same shape for every tower; forms get a shorter 3-step ladder | |

Gold drops (placeholder): Patrol 40 / first 60, Night Watch 60 / 80, Hold the Gate 80 / 100, Drum Line 50 / 80,
The Glutton Returns 120 / 150. At one play a day, a tower reaches level 2 after its first mission win and level 5
in about a week of play, if it goes on missions every day.

## Build plan

1. **Data and rules** (Godot): the content fields, `TowerLevels`, `TowerTasks`, the wallet's gold, mission gold
   drops, the level built into the entity, co-op hand entries, tests, the content check's probes for levels.
2. **Screens**: the Camp's Blacksmith button (replacing the Workshop station, same prop; hidden before Chapter 2,
   slide), the Blacksmith place (a kit from the Blender agent: anvil, forge, racks; mockups from the UI/UX agent),
   the Upgrade picker and view, Lv chips everywhere, end-screen task lines, Codex "Levels" line.
3. **Art**: the Blacksmith diorama (Blender agent), gold coin icon and Lv chip (UI/UX kit).

## Open questions

- Whether levels should also raise a tower's energy cost (no, for now).
- Whether gold should be spendable elsewhere later (forms costing gold + tokens, a shop).
- A "respec" or form-level transfer when a tower switches form: no; each form keeps its own ladder.
