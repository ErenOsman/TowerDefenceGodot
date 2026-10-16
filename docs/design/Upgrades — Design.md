# Upgrades — Design

Written 2026-10-16 by the Godot agent from Eren's decisions of the same day; the points he left open are decided
here and marked **(agents)**. This doc is the source of truth for tower **levels** (the Upgrade mechanic) and their
**tasks**. The place where upgrading happens is the Blacksmith (Blacksmith — Design); Workshop — Design
keeps forms and tokens; Missions & Guild — Design keeps the missions.

A tower rises in **level** by completing that tower's **tasks**, then pressing **Upgrade** in the Blacksmith. No
currency is spent (Eren 2026-10-16: gold is not part of upgrades). Every tower starts at level 1 when the Blacksmith opens (after Chapter 2). A form never passes its base
tower's level.

## Decisions

| Topic | Decision | Source |
| --- | --- | --- |
| Levels | Every tower (each individual, by its id) has a **level**, 1 when the Blacksmith opens, up to the type's **max level** (5 for now, data). A level is gained by pressing **Upgrade** once that level's **tasks** are complete; nothing is paid | Eren (all towers level 1 after Chapter 2; tasks; press Upgrade) · agents (per individual tower, max 5) |
| Tasks | Each level step of a tower type lists its tasks, e.g. Archer 1 → 2: "Win a mission with this tower". Tasks are counted **per tower** (this Archer, not any Archer). Kinds (data): win a mission with the tower in the hand; win N levels with it; N kills by it; N damage dealt; N hits taken without dying; place it N times; a specific mission; a win without losing a tower | Eren (example) · agents (the kinds) |
| Gold | **None.** Upgrades cost no currency; gold is not introduced (a later currency, if ever, gets its own doc) | Eren 2026-10-16 ("gold shouldn't be on upgrades") |
| What a level gives | Stat bonuses set per tower type and level in the content: e.g. Archer level 2 +2 Power, level 3 +5 Max HP, …; a level may also add or change an ability at a set step (data allows it; the starter content uses stats only). Bonuses are modifiers on the tower's entity, so previews and the Codex show them | agents |
| Forms and levels | Each **unlocked form** of a tower has its **own level and tasks** (in Forms.json), but a form's level can **never exceed the base tower's level**: the Upgrade button for a form is disabled with "Raise Archer to level 3 first". The tower fights with the level bonuses of its **current** form (base or form) | Eren (forms ≤ base) · agents (own levels per form; current form's bonuses) |
| Before Chapter 2 | No levels exist: nothing shows "Lv", no tasks count, nothing to collect for it. On the first Blacksmith visit every tower is level 1 and its level-1 → 2 tasks start counting from then (earlier wins do not count) | Eren (level 1 after Chapter 2) · agents (counting starts at the unlock) |
| Shown where | A small **Lv n** chip on the tower's card (hand select, Workshop picker, tray piece, board medallion, Codex "In your collection" rows); the Upgrade station shows the tasks with progress; the end screen lists task progress gained in that level/mission ("Archer: Win a mission ✓") | agents |
| Codex | Read-only: the tower page's Overview gets a "Levels" line listing what each level gives (from the content); no tasks there | agents |
| Content | `Content/Towers.json` gains `levels`; `Forms.json` the same; `Missions.json` and `Tokens.json` untouched | agents |

## Player flow

```text
Blacksmith ──Upgrade──▶ Tower picker ──▶ Upgrade view (level, tasks, Upgrade) ──Back──▶ picker ──▶ Blacksmith
```

A mission win: the end screen shows the tasks that advanced; the Blacksmith's Upgrade station
button shows "N ready" when some tower can be upgraded now.

## The Upgrade view

```text
┌ ← Back   Archer  tower 3   Lv 2                                                ┐
│ Now                     │ Level 3                           │ After upgrade     │
│ portrait, Lv 2          │ Tasks                             │ portrait, Lv 3    │
│ Max HP 20 · Power 12    │ ✓ Win a mission with this tower   │ Max HP 25 (+5)    │
│ Range 2 · Speed 2       │ ○ Deal 60 damage with it   42/60  │ Range 3 (+1)      │
│ abilities               │                                   │ abilities         │
│                         │ [      Upgrade to level 3      ]  │                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

- **Picker**: the collection as in the Workshop, each tile with its Lv chip and a small "ready" mark when the
  tower can be upgraded; a filter "Ready to upgrade".
- **Upgrade view** (Eren 2026-10-16): **left** the tower as it is now (its current form's card: Lv, stats,
  abilities); **centre** this level's tasks with progress and the single action **Upgrade to level n**, enabled only
  when every task is done, otherwise simply disabled (no reason line: the task bars already show what is
  missing; Eren 2026-10-16 "scalable değil"). The only text under the button is the form block, "Raise <base> to
  level n first"; **right** the same card as
  it will be **after the upgrade**, with the changed numbers marked. Nothing else: no "what the level gives" list,
  no preview of the level after, no "Level 2 of 5", no "Base form" line under a base-form tower. At max level the
  centre says the tower is at its highest level and the right card is empty.
- **Forms** (agents, 2026-10-16, from Eren's "no forms row"): the view works on the tower's **current form**: a
  tower wearing Fire Archer shows the Fire Archer ladder and level; in its base form, the base ladder. To upgrade
  another form, switch to it in Modify first. A form's Upgrade is disabled with "Raise <base> to level n first" while
  the base is behind.
- **Confirm**: Upgrade asks once through the confirm popup ("Upgrade Archer to level 3?").

## Rules

- **Level** is saved per owned tower (`OwnedTower.level`, default 1) and per unlocked form (`OwnedTower.form_levels`,
  form id → level, default 1). `max level` comes from the type's `levels` list length + 1.
- **Tasks** are defined per level step (the step to level n lists what level n needs). Progress is saved per tower and
  per form (`OwnedTower.task_progress`: step → task index → count). Counting starts at the Blacksmith unlock; only
  towers present in a won level/mission count "win" tasks, and only the acting tower counts kills/damage/hits.
  A tower fighting **in a form** counts toward **both** ladders: the base tower's (its career) and that form's;
  in the base form only the base ladder counts **(agents, 2026-10-16)**. The station's "N ready" counts ready
  forms too **(agents)**.
  The sim already logs every event with the acting entity and the owned tower id, so the level's end records the
  counts without new sim rules (`TowerTasks.apply(result, log, towers)`, engine-free, in `sim/meta`).
- **Upgrade** needs: every task of the step complete, and for a form: base level > form level. It raises the level, resets that step's progress and starts the next step's counting.
- **Bonuses** are modifiers listed per level (`{stat, kind: Flat|PctAdd, amount}`) applied to the tower's entity
  when a level is built from the owned tower (`Workshop.resolve` → `TowerLevels.apply`); cumulative over levels.
  A form's bonuses are its own list; the base's bonuses do not carry into a form (each form has its own ladder).
- **Co-op**: a tower's level travels with its hand entry (`"<type>@<form>:L<n>"`), so both clients build the same
  entity; tasks count for each player's own towers.
- **Validation**: every task kind is known; counts > 0; a level's modifiers name real stats; a form's ladder is
  not longer than its base's.

## Data

### Towers.json / Forms.json — `levels`

```json
"levels": [
  { "to": 2, "tasks": [ { "kind": "WinMission", "count": 1 } ],
    "bonuses": [ { "stat": "Power", "kind": "Flat", "amount": "2" } ] },
  { "to": 3, "tasks": [ { "kind": "WinMission", "count": 1 }, { "kind": "Damage", "count": 60 } ],
    "bonuses": [ { "stat": "MaxHp", "kind": "Flat", "amount": "5" } ] }
]
```

Task kinds: `WinMission` (count missions won with the tower in the hand), `WinLevel`, `WinMissionId` (`mission`),
`Kills`, `Damage`, `HitsTaken` (survived), `Placed`, `WinNoLoss` (a win without losing a tower). Task texts come
from the kind and count ("Win a mission with this tower", "Deal 60 damage with it"); a task may give its own `text`.

### Catalog.json

`blacksmithUnlock` = the same level as `guildUnlock` (Chapter 2's last) unless changed.

### Saves

`OwnedTower.level`, `form_levels`, `task_progress`; `PlayerProfile.blacksmith_seen`.
Engine-free rules in `sim/meta/tower_levels.gd` (`max_level`, `step_for`, `can_upgrade(tower, form) → reason`,
`upgrade`, `bonuses_at`, `apply`) and `sim/meta/tower_tasks.gd` (`describe`, `apply(result, log, towers)`).

## Starter content (placeholders; Eren rewrites)

| Tower | To level | Tasks | Gives |
| --- | --- | --- | --- |
| Archer | 2 | Win a mission with it | +2 Power |
| Archer | 3 | Win a mission; deal 60 damage | +5 Max HP |
| Archer | 4 | Win 2 missions; 10 kills | +1 Range |
| Archer | 5 | Win 3 missions; a win without losing a tower | +3 Power, +5 Max HP |
| Guardian | 2 | Win a mission with it | +10 Max HP |
| Guardian | 3 | Win a mission; take 40 hits and survive | +2 Power |
| … | | the same shape for every tower; forms get a shorter 3-step ladder | |

in about a week of play, if it goes on missions every day.

## Build plan

1. **Data and rules** (Godot): the content fields, `TowerLevels`, `TowerTasks`, the level built into the entity, co-op hand entries, tests, the content check's probes for levels.
2. **Screens**: the Upgrade picker and view in the Blacksmith (mockups from the UI/UX agent), Lv chips everywhere,
   end-screen task lines, the Codex "Levels" line.
3. **Art**: the Lv chip (UI/UX kit).

## Open questions

- Whether levels should also raise a tower's energy cost (no, for now).
- A currency for upgrades: no. Gold, if it ever exists, is a mission reward (Missions & Guild — Design, Open questions).
- A "respec" or form-level transfer when a tower switches form: no; each form keeps its own ladder.
