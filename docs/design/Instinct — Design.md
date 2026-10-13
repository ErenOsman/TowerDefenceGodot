# Instinct — Design

Written 2026-10-03 as a claude.ai doc; moved into the repo on 2026-10-05. This file is now the source of truth. Everything in the build plan is built; [Since the doc was written](#since-the-doc-was-written) lists what changed afterwards.

**Instinct** is how an ability chooses its own aim when no player clicks a tile. Enemy turns, abilities that pick their own targets and shift-click quick cast all use the same rule: take the ability's valid aims, keep the ones it must take, sort them by its preferences, and break ties the same way every time.

## Where Instinct is used

Every aim the player does not click comes from an instinct:

| Who aims | Example | Before Instinct |
| --- | --- | --- |
| An enemy on its turn | The slime attacks a tower next to it | `EnemyBrain`: movement went farthest, attacks took the nearest valid target (ties by entity id) |
| An ability that picks its own targets | Chain Lightning's bounce; "shoot 3 random enemies in range" | Bounce took the nearest unit not hit yet; no other picks existed |
| A reaction that casts an ability | Overwatch shoots the enemy that entered the tile | Aims at a fixed event role (`EventTarget`); stays as it is |
| The player's quick cast | Shift-click Shoot with one enemy in range | — |

Instinct replaced the hard-coded rules in the first two rows and powers the fourth. The third keeps its explicit aim: a reaction knows whom it answers.

Instinct never makes an invalid choice. It only chooses among the aims `Targeting.ValidAims` already allows, so range, filters, cooldowns and costs stay where they are.

## How an instinct picks

1. Start from the ability's valid aims (`Targeting.ValidAims`). None → no aim.
2. Drop the aims that fail **Must**. None left → no aim.
3. Status tags bend the list: `Redirected` already limited the valid aims to the applier; `Taunted` keeps only the aims that hit a taunter, when any do (see [Statuses that bend instinct](#statuses-that-bend-instinct)).
4. Sort by the **Prefer** list (or the preset): the first entry sorts, later entries only break its ties.
5. Fixed tie-break: the target's entity id, then the tile in canonical order. Exactly one aim is left.

Each step only removes or reorders aims, never adds one. An empty list after any step (usually the valid aims or *Must*) ends with no aim; otherwise the tie-break always leaves exactly one.

## Preferences

An instinct has two parts, both written with the Formula and Condition systems so designers never need code:

- **Must** (optional condition): candidates that fail it are dropped. Nothing left means no aim: the enemy skips the ability, and quick cast says "No target". Example: a heal's `Target.Hp < Target.MaxHp`.
- **Prefer** (ordered list): each entry is *Highest* or *Lowest* of a formula. The first entry sorts; later entries only break its ties. Example: Most hit, then Nearest.

An area aim is scored by what it would hit. A preference can be set to **Area count** (how many units the aim's area hits) or **Area sum** (its formula added up over them), each with an optional filter. Example: Area count with filter `Target.IsEnemy`; Area sum of `Target.Hp`. A single-target aim has exactly one unit, so `Target` simply means it.

The ready-made instincts are preference lists with a name:

| Instinct | Picks | Written as |
| --- | --- | --- |
| Nearest | The closest target | Lowest `Self.DistanceTo(Target)` |
| Farthest | The farthest target in range | Highest `Self.DistanceTo(Target)` |
| First | The enemy closest to the base along its path | Highest `Target.PathProgress` |
| Last | The enemy that just entered | Lowest `Target.PathProgress` |
| Weakest | The lowest HP | Lowest `Target.Hp` |
| Strongest | The highest max HP | Highest `Target.MaxHp` |
| Most hurt | The lowest HP percentage (heals) | Lowest `Target.Hp / Target.MaxHp` |
| Most hit | The area aim hitting the most enemies (or units passing the area filter); then fewer allies hit, then the nearer tile. Hitting nothing worth hitting: no aim | Highest area count (filter: the ability's target filter) |
| Random | Any valid aim | Random (seeded) |
| Farthest step | Movement: the longest route | Highest route length |
| Ahead | The unit furthest ahead along the chooser's own path; the nearer on a tie | Highest `Target.AheadOnPath`, then Nearest |
| Engage | Movement: walk to where the next attack can hit the unit its instinct likes best, as far along as possible; nothing in reach: the longest route | Built in (plans for the owner's next non-movement ability) |
| First valid | The first valid aim in canonical order | — |

Example: the Brute walks with *Engage* and smashes with *Ahead*, so it stops beside the tower furthest along its path that it can reach this turn and hits that one. Engage only checks positions; it simulates nothing.

Random draws from `GameState.Rng`, so a replay with the same seed makes the same choice.

## Defaults

Most abilities never need a hand-written instinct. When an ability sets none, it gets one from its targeting and its owner:

| Ability | Owner | Default instinct |
| --- | --- | --- |
| Targets only its caster (Self) | Anyone | Self |
| Movement (`Steps`, `PathAhead`) | Enemy | Farthest step |
| Movement | Tower | None: quick cast refuses, the player picks the tile |
| Single target, enemy filter | Enemy | Nearest |
| Single target, enemy filter | Tower | Nearest, as for enemies |
| Single target, ally filter | Anyone | Most hurt |
| Area | Anyone | Most hit, then Nearest |
| No target filter | Anyone | The first valid aim in canonical order |

## Enemy turns

An enemy's turn is a priority list: it goes through its abilities in the order the designer listed them and casts each one it can. Instinct only decides where each cast goes.

1. Skip the ability if it cannot be cast now (cooldown, control tags, costs, its cast gate).
2. Ask its instinct for an aim. No aim (nothing valid, or nothing passes *Must*) → skip it.
3. Cast it, let the effects resolve, then go on to the next ability with the board as it is now.

So the order carries the enemy's personality. Slime: *Path Walk*, then *Ram* — walk first, then ram the base if it is in reach. A healer: *Mend* (Must: an ally is hurt) before *Walk*, so it heals when it can and walks otherwise.

Because step 3 uses the board as it stands, a second attack never aims at a unit the first one killed.

Enemies stay simple: no looking ahead (simulating a cast to score its result) and no shared plan across enemies. An ability that should focus fire says so in its own instinct.

## Abilities that choose their own targets

Some steps inside an ability pick units while it resolves. They get an instinct of their own, set on the step:

- **Bounce** (on the Attack step): picks the next unit around the last one hit, among those not hit yet. Default Nearest. Chain Lightning could switch to Weakest to finish units off.
- **Pick** (step): chooses up to N units in an area around the caster or the aim and runs its sub-steps on each. Its instinct ranks the candidates and the first N win. Examples: *Volley* hits 3 random enemies in range; *Rally* buffs the 2 most hurt allies.
- **Cast Ability from a reaction**: keeps its explicit aim (`EventTarget`, `EventSource`, `Self`), or, with *aim by instinct*, leaves the aim to the cast ability's instinct, for passives such as "at the start of each turn, shoot the weakest enemy in range".

These picks happen mid-resolution, so they read the state at that moment, after earlier batches and checkpoints. A unit killed between two bounces is never picked.

## Quick cast

Shift-click an ability (its row in the tower bar) to cast it at once, without aiming. It is the fast way to cast self-targeted abilities, and to shoot when only one enemy is in range.

1. The ability cannot be cast now → nothing happens; the hint line says why (cooldown, energy, control).
2. It has no valid aim → "No target".
3. It has exactly one valid aim → that one, whatever the instinct says.
4. Otherwise → the ability's instinct picks. Nothing passes its *Must*, or it has none (tower movement) → "No target: aim it yourself".
5. The chosen aim is cast through the normal `Cast` command, so replays, the log and the Director treat it like a clicked cast.

Holding Shift while the pointer is over an ability previews the quick cast: the tile, unit or area it would hit lights up, using the same highlight as aiming. The player sees the choice before committing to it.

Quick cast never picks for the player when they are already aiming: shift-click on the board while aiming does nothing special.

## Statuses that bend instinct

Two status tags steer choices without touching any ability. Both name the status's applier as the unit to go for:

| Tag | Strength | Effect | Hand aiming |
| --- | --- | --- | --- |
| `Taunted` | Soft | Per ability: after *Must*, the aims that hit any taunter form the pool the instinct picks from, when any do; otherwise it makes its normal choice | Free |
| `Redirected` | Hard | Only aims at the applier are valid, for instincts and for the player. A redirected unit that cannot reach the applier cannot attack | Restricted the same way |

Stealth (`Stealthed`) already hides a unit from single-target abilities, so the Unseen idea needs no tag of its own for now. Unlike Unseen, stealth also hides the unit from the player's single-target aims.

## Data and code

Instinct lives in the engine-free simulation, next to targeting, because Bounce and Pick run inside the Resolver.

| Layer | What it holds |
| --- | --- |
| `Game.Combat` | `InstinctDef` (Must condition, Prefer list, or a preset); `Instinct.Choose(state, chooser, ability, aims)` returns one aim or none; `Instinct.Rank` orders candidates for Pick; `Instinct.QuickCast`; `AbilityDef.instinct` (empty = the default from the table above); `Tags.Taunted`, `Tags.Redirected` |
| Formulas | Queries `Target.PathProgress`, `Target.DamagedThisRound` (focus fire), `Target.AheadOnPath`; Area count and Area sum preferences with a filter; formulas sit in an `Instinct` slot, validated like every other formula |
| `Game.Level` | `EnemyBrain` asks `Instinct.Choose` |
| `Game.Data` | `AbilityAsset.instinct` (preset dropdown, or custom Must and Prefer); the converter and `AssetValidator` cover it; the Attack step's bounce and the Pick step have an instinct field |
| Editor | `InstinctDrawer`: preset in one line, expanding to Must and Prefer when custom |
| GameScene | `LevelController.QuickCast(ability)`, the Shift preview and hint texts |

The tie-break after the last preference is fixed: the target's entity id, then the tile in canonical order. The same state therefore always gives the same choice, which keeps replays exact and makes previews honest.

## Decisions

| Question | Decision |
| --- | --- |
| Show what enemies will hit (Into the Breach style)? | No. Abilities can get too complex to preview honestly. |
| Tower default for single-target attacks | Nearest, the same as enemies. |
| Instinct per enemy, or per ability? | Per ability, so one unit can carry two abilities with different instincts. No override on the Entity. |
| Random | A normal preset for everyone, enemies included. Seeded, so replays hold. |
| Look ahead (simulate a cast to score it) | No, for now. Enemies stay simple. |
| Focus fire | Not a general rule. An instinct may prefer hurt targets through a query such as `Target.DamagedThisRound`. |
| Taunt | Soft and per ability: the taunter pool goes through the ability's instinct. The old hard taunt became `Redirected`. |

## Since the doc was written

- **Holding Shift + 1–9** with a tower selected shows the ability's range and quick-cast target; letting the number go casts it, and right-click before that cancels.
- **Shift while aiming** an ability highlights where its instinct would cast it, and the hint names the target. Clicking still casts at the clicked tile.
- **Most hit** counts enemies only (or units passing the ability's filter) and returns no aim when nothing worth hitting is in reach.
