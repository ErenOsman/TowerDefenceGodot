# Workshop — Design

Written 2026-10-14 by the Godot agent from Eren's decisions of 2026-10-13 (given to the UI/UX agent) and the approved
mockups; Eren asked for the doc first and left the open points to the agents ("I trust you"), so the rest is decided
here and marked **(agents)**. Godot pass 2026-10-15. This file is the source of truth for the Workshop; the Camp doc's open question
"what the Workshop modifies and what it costs" is answered by it.

The **Workshop** is the Camp station where the player **modifies towers**: a tower turns into one of its **forms**
(Archer → Fire Archer), unlocked with **tokens** found in levels. A form is a different tower: other stats, abilities,
passives, look and name. The tower keeps its ID, its name tag and its place in the hand; it fights as its current form.

## Decisions

| Topic | Decision | Source |
| --- | --- | --- |
| Where | Camp station **Workshop**, **opened when Chapter 2 is cleared** (the same level as the Guild: `guildUnlock`); until then the station is locked with "Opens after Chapter 2". Picker first, then the Modify view slides in from the right; the Modify view may be its own scene | Eren 2026-10-13 · Eren 2026-10-14 (after Chapter 2) |
| Picker | The collection like Hand select (search, Role / Delivery / Cost filters, Sort), no hand row; a detail card with **Modify** (or double-click) | Eren 2026-10-13 |
| Modify view | **Left** the tower as it is now, **centre** the forms tree, **right** the selected node: what changes, what it costs, one action | Eren 2026-10-13 |
| The tree | The tower's default form is the root in the middle; 2–3 nodes branch off it, each a different form of that tower. Forms may have children (Fire Archer → Inferno Archer): depth is allowed | Eren 2026-10-13 |
| Unlock | A node is unlocked by spending **tokens** (Fire Archer: 1 Fire Arrow). A child needs its parent unlocked | Eren 2026-10-13 |
| Switching | The tower stays in the form picked until changed; any unlocked form can be picked again. Switching is **free** and only in the Workshop (not during a level) | Eren (stays / switch back) · agents (free, Camp only) |
| Per tower | Unlocks belong to the **individual tower** ("Unlocks for this Archer"): two Archers are two towers, each with its own forms. Tokens spent on one tower do nothing for another | agents (fits "every tower is an individual") |
| Tokens | The game's **meta currency**: kinds such as Fire Arrow, Poison Gland, Yew Bow, Ember Core, Steel Plate, Arcane Shard, each with an icon and a line saying where it drops. No coins, no second currency | agents |
| Where tokens come from | **Missions** (Missions & Guild — Design, 2026-10-14): a mission drops `winTokens` on every win and `firstWinTokens` once; missions are played a limited number of times a day. Chapter levels drop no tokens (their prize is the first-clear tower). Replaces the earlier per-level drops | Eren 2026-10-14 |
| What a form changes | Anything the tower's entity has: stats, abilities (added, changed, removed), passives, model and portrait, name, and optionally the **energy cost** (default: the base tower's) | Eren (stats/abilities/looks) · agents (cost field, default unchanged) |
| Elsewhere | A formed tower shows its form name and a small **form badge** on its hand card, tray piece, board medallion and Codex entry | UI/UX agent, mockup workshop-badge |
| Codex | A tower's Codex page has page tabs **Overview · Abilities** (passives included) **· Forms** (more pages may come). Forms is a **list** of rows, not a tree, showing **only forms the player has unlocked** on any of their towers (locked forms do not appear in the Codex at all); the base form is a row like the others ("Archer · Base form", first, no special styling). Selecting a row switches the whole page (header with the badge, Overview, Abilities) to that form; going back is selecting the base row (no Back button). The tab label is just "Forms", no count. No "Open in Workshop" link: the Codex is read-only reference. Empty state: the default row plus "Unlock more forms in the Workshop." A 4th tab **Immunities** sits after Forms, disabled for now: label dimmed to ~45 %, not clickable, hover tooltip "Coming later"; it becomes a real page once immunities exist in the data. Enemy pages have the same four tabs, Overview · Abilities · Forms · Immunities, with Forms disabled the same way (enemies may get forms later) and Immunities disabled as on towers. The Workshop tree still shows every form's real portrait. Mockup: screens-b/codex2.html | Eren 2026-10-14 |
| Locked nodes | A form not yet unlocked shows its token coin in the tree node instead of a grey portrait; the portrait appears once unlocked | Eren 2026-10-14 |
| No comparison | The form card shows the form's own stats and abilities; nothing is compared against the current form (no arrows, no Changed/Same tags) | Eren 2026-10-14 |
| Confirm | Unlocking asks once ("Unlock Fire Archer for this Archer? Spends 1 Fire Arrow (you have 2 → 1)"); switching does not | mockup workshop-confirm |
| Content | Forms and tokens are content JSON like everything else (`data/content/Forms.json`, `data/content/Tokens.json`); drops live in `Catalog.json`; no numbers in code | agents |

## Player flow

```text
Camp ──Workshop──▶ Picker (collection) ──Modify / double-click──▶ Modify view (tree) ──Back / Esc──▶ Picker ──Close──▶ Camp
                                                                       │ Unlock (confirm) · Use this form
                                                                       ▼
                                                        the tower's form changes; hand, tray and board follow
```

A level never changes a form: the hand brings each tower in as the form it has when the level starts. Selling and
dying in a level change nothing in the Workshop (towers come back after every level, as now).

## Screen layout

Reference mockup (approved as the UI direction): http://92.5.94.11/art/ui/screens-b/workshop.html, frames
`workshop-picker` … `workshop-badge`, sheet `shots/workshop-sheet.png`.

```text
┌ Workshop · Pick a tower to modify ─────────────────────────────────────────── × ┐
│ Search / Role / Delivery / Cost │ 37 towers            Sort ▾ │ Fire Archer      │
│                                 │ [Archer][Archer][Fire Archer*]… │ #1 · tower 3  │
│                                 │ (collection grid, badges)   │ 100 energy        │
│                                 │                             │ Form of Archer ·  │
│                                 │                             │ 1 of 4 unlocked   │
│                                 │                             │ stats · abilities │
│                                 │                             │ [    Modify    ]  │
└──────────────────────────────────────────────────────────────────────────────────┘
          ▼ slides right (~350 ms)
┌ ← Back Esc   Archer  #1 · tower 3                  tokens: 🔥2 🧪0 🏹1 🔥0 🛡1 💎3 ┐
│ This tower now      │ Forms · click one to see it          │ Fire Archer          │
│ portrait, name,     │        (Inferno Archer)              │ Form of Archer       │
│ "Form: Default"     │            │                         │ description          │
│ Max HP · Power ·    │ (Fire Archer)─(Archer)─(Poison Arch.)│ 19 Max HP · 11 Power │
│ Range · Speed       │            │                         │ 2 Range · 2 Speed    │
│ abilities as now    │        (Longbow)                     │ Fire Shot …          │
│                     │ ● Current ● Unlocked ● Can unlock    │ Tower Walk …         │
│                     │ ● Needs tokens                       │ (no comparison)      │
│                     │                                      │ › Leads to: Inferno  │
│                     │                                      │ Unlock cost 🔥1 (2)  │
│                     │                                      │ [Unlock · 1 Fire Arrow] │
└──────────────────────────────────────────────────────────────────────────────────┘
```

- **Node states:** Current (cobalt ring, the path from the root to it is cobalt), Unlocked (green ✓ check on the
  node, no ring), Can unlock (gold ring + glow: the parent is unlocked and the tokens are there), Needs tokens (red
  "0/1" chip), Locked behind a parent ("needs Fire Archer"). Rings are only for Current and Can unlock.
  **A form that is not unlocked yet shows its token in the node** (the coin of the first token of its cost, large,
  in place of the portrait; a two-token cost keeps both count chips below), not a grey portrait; the portrait appears
  once the form is unlocked (Eren, 2026-10-14). The right card still shows the form's real portrait when a locked
  node is selected.
- **Right card, one action:** `Unlock · 1 Fire Arrow` (enabled only in Can unlock; under it "Unlocks for this Archer
  (tower 3)"), or `Use this form` (unlocked, not current; under it "Free: switch back any time"), or nothing for the
  current form ("This is the tower's current form"). Missing tokens: the button is disabled and a red line says what
  is missing and where it drops ("Needs 1 more Ember Core. Found in: The Glutton (boss)").
- **No comparison between forms** (Eren, 2026-10-14): the card shows the selected form as it is — its stat tiles,
  its abilities and passives as their tooltips show them — with no arrows against the current form and no
  Changed / Same / New / Gone tags; the player compares by clicking nodes. Then "Leads to: …" for its children.
- **Token header:** every token kind with the count owned; hovering one shows its name, description and where it drops.
- **After Unlock:** the confirm popup, then the node fills, the ring flashes, a "Fire Archer unlocked" toast on the
  card and the action becomes `Use this form`. Unlocking does not switch the form by itself.
- **Keys:** Esc / Back returns to the picker (then closes it); Enter = the card's action; arrows move between nodes.

## Rules

- A **form** belongs to one tower type and has at most one **parent** form; a form without a parent hangs off the
  root (the type's default form). The default form is never unlocked or paid for: every tower has it.
- **Unlock** needs: the parent unlocked on this tower (none for root children), and every token of the cost owned.
  The tokens are spent at once; nothing refunds them. Unlocked forms are saved on the tower and never lost.
- **Current form** is one of the tower's unlocked forms or the default. Switching costs nothing and is immediate.
- A formed tower keeps its **ID** (saves, hand, progress, Codex "owned" all key on it), its **custom name** (the
  badge and the form name show next to it), its **hand slot** and its **tower number**.
- **In a level** the tower is built from its form: the form's entity (stats, abilities, passives, model) and the
  form's **energy cost** when it has one, else the base tower's. Selling refunds from that cost (the existing rule).
  Any tooltip, Codex or wiki text about the tower speaks of the form by its own name.
- **Tokens** are counted per kind in the save; a mission's drops are granted on the end screen ("Rewards: Fire
  Arrow ×2, Ember Core ×1"), first-win drops once per mission, win drops on every win (Missions & Guild — Design).
  Quitting or losing drops nothing. Dev shortcuts can grant tokens.
- **Co-op:** a player's hand entries carry the form, and the form's content comes with the content hash, so both
  clients build the same entity. The relay never reads forms.
- **Validation (Validate All):** a form's tower, entity, parent and tokens must exist; a form's parent must belong
  to the same tower type; no cycles; depth ≤ 3 (root + 2 levels) for now; every token kind must drop somewhere
  (a level lists it) or Validate All warns; a cost of 0 tokens is an error (the default form is the free one).

## Data

Content stays JSON under `data/content/` (the single source of truth, read by the game and the wiki). New
files and fields; everything keyed by stable ids like the rest.

### data/content/Forms.json — `FormAsset` (keys `Form/<Name>`)

| Field | Meaning |
| --- | --- |
| `id` | stable id, saved on towers (`archer-fire`) |
| `displayName`, `description`, `icon` | the form's own name and portrait ("Fire Archer"; the portrait may be the base portrait until the Blender agent renders one) |
| `badge` | the small badge sprite shown on cards, tray pieces and the board medallion (`Assets/Art/UI/KitB/forms/archer-fire.png`, i.e. `res://art/ui/KitB/forms/`) |
| `tower` | the base tower type (`Tower/Archer Tower`) |
| `parent` | the parent form, or empty for a root child |
| `entity` | the unit entry the tower fights as in this form (`Unit/Tower/Form/Fire Archer`): a full entity like any other tower's, so forms need no new mechanics |
| `cost` | energy cost in this form; `-1` = the base tower's |
| `unlock` | the tokens to spend: `[{ "token": "Token/Fire Arrow", "amount": 1 }]` |
| `order` | where the node sits around the root (0, 1, 2… clockwise from the top); children sit beyond their parent |

### data/content/Tokens.json — `TokenAsset` (keys `Token/<Name>`)

| Field | Meaning |
| --- | --- |
| `id`, `displayName`, `description`, `icon` | "Fire Arrow — An arrowhead that still smoulders." |
| `rarity` | `Common` / `Rare`: a hint for the header's order and the drop tables, no rule reads it |

Where a token drops is not stored on the token: the Workshop derives "Found in: Night Watch, Drum Line" from the
missions' drop lists (so it stays true when missions change).

### Missions.json — drops

`firstWinTokens` and `winTokens` live on missions (`data/content/Missions.json`, Missions & Guild — Design), each
`[{ "token": …, "amount": n }]`; chapter levels carry none. `GameReference` exports them with the mission and lists
every form under its tower with its cost and where its tokens come from (not built yet: `game/dev/game_reference.gd` has
no forms, tokens or missions).

### Saves (`GameData`)

- `OwnedTower.form` — the current form id, empty = default. `OwnedTower.forms` — unlocked form ids (never the default).
- `GameData.tokens` — `TokenWallet`: `[{ "id": "fire-arrow", "count": 2 }]` plus `earned` totals per kind (for
  stats; nothing reads it yet). Engine-free rules in `sim/meta/workshop.gd` (`Workshop`, static): `can_unlock(tower, form, wallet)` (+ the reason),
  `unlock`, `set_form`, `drops(result, record, source)`; tested in `tests/test_workshop.gd`.
- `CodexProgress`: forms are discovered through the existing "owned" rule (owned = some tower has it unlocked).

### Engine-free model

```text
FormDef  { id, name, description, towerType, parent, entity: EntityDef, cost (-1 = base), unlock: {tokenId: n}, badge, order }
TowerType gains  forms: FormDef[]   (its tree, in content order)
Workshop.resolve(ownedTower, towerType) → the TowerType the level builds (its form's entity and cost; AssetConverter)
Workshop.can_unlock(tower, form, wallet): "Needs Fire Archer first" | "Needs 1 more Ember Core" | ok
```

## Starter content (placeholders: names, numbers and art are the mockup's; Eren rewrites)

| Tower | Form | Parent | Unlock | What changes |
| --- | --- | --- | --- | --- |
| Archer | Fire Archer | – | 1 Fire Arrow | Shoot → Fire Shot: 11 damage (−1), applies Burn 2 turns |
| Archer | Inferno Archer | Fire Archer | 1 Ember Core + 1 Fire Arrow | Fire Shot → Fire Volley: Radius 1, Burn around the target, 2 turn CD |
| Archer | Poison Archer | – | 1 Poison Gland | Shoot → Venom Shot: 10 damage (−2), applies Acid 3 turns |
| Archer | Longbow | – | 2 Yew Bow | +2 Power, +1 Range, −1 Speed (Long Shot) |
| Guardian | Bastion | – | 1 Steel Plate | +15 Max HP, Taunt Range +1, −1 Speed (Shield Bash) |
| Guardian | Spiked Guardian | – | 1 Steel Plate + 1 Ember Core | +3 Power, Counter-attack hits for 8 |
| Mage | Pyromancer · Frost Mage · Storm Mage | – | Arcane Shard (+ Ember Core) | placeholders, see the mockup |

| Token | Rarity | Drops (placeholder; the mission table is in Missions & Guild — Design) |
| --- | --- | --- |
| Fire Arrow | Common | Night Watch (win), Patrol and Drum Line (first win) |
| Poison Gland | Common | Night Watch and Drum Line (win) |
| Yew Bow | Common | Patrol (win) |
| Steel Plate | Common | Hold the Gate (win and first win) |
| Arcane Shard | Common | Drum Line (win), Night Watch (first win) |
| Ember Core | Rare | The Glutton Returns (win and first win, co-op) |

Chapters drop nothing: the Workshop and the Guild's missions both open when Chapter 2 is cleared, so the first
form is a Chapter 2 reward in effect.

## In the Godot build

Built 2026-10-14: the content (`Forms.json`, `Tokens.json`: the starter forms and tokens above), the rules
(`FormDef` in `sim/level/`, `TokenDef`, `TokenWallet`, `Workshop` in `sim/meta/`, `OwnedTower.form` / `forms`, Validate
All rules; tests `tests/test_workshop.gd`); the level builds a tower from its form; the end screen grants drops; the
screens: the Camp's Workshop station opens the picker, the Modify view, the tree, the card, confirm
(`game/ui/screens/workshop.gd`, logic in `WorkshopLogic`, tests `tests/test_workshop_ui.gd`), badges on hand cards, tray
pieces and board medallions (`TdFormBadge`), the Codex's Forms page. How it differs in detail: docs/GODOT-NOTES.md
("Workshop screens").

**Art:** the 6 token icons and a badge per form are UI kit sprites in `art/ui/KitB/tokens/<token id>.png` and
`art/ui/KitB/forms/<form id>.png` (content paths `Assets/Art/UI/KitB/…`). The starter badge set, one per form: Fire
Archer (flame), Inferno Archer (big flame), Poison Archer (drop), Longbow (bow), Bastion (shield), Spiked Guardian
(spiked shield), Pyromancer (fireball), Frost Mage (snowflake), Storm Mage (spark). Form portraits and models from the
Blender agent when the forms are final; until then the base portrait with the form's tint and badge.

History: the plan first had the content, rules and screens built in the Unity repo (a Create Starter Forms tool,
`UI_Workshop`) and then mirrored in the Godot build from the synced content; only the Godot build was done before the
Unity build stopped on 2026-10-15.

## Open questions

- Whether the same token kinds last, or every chapter brings its own (the data allows both).
- Whether a form should ever be **removable** (refund) — no, for now.
- Form portraits: base portrait + tint and badge until real renders exist.
