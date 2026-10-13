# Game Overview — Design

Oct 2, 2026 · @Eren

## Summary

A turn-based tower defense on a grid: the player picks a hand of up to 8 towers, enters a level, places towers by spending energy and clears every wave of enemies while defending the base. One rule holds it together: every action is an **ability**.

Waves follow their own schedules and can overlap, and the level is won only when every one is finished. Every round has three phases: the player acts freely with any tower, the enemies take their turns one at a time, then the level spawns enemies, runs its LevelEvents and pays out energy.

**Design pillars**

- **Every move is an ability.** Walking, attacking and repositioning are abilities; passives and statuses work as the Ability Pipeline specifies.
- **Every tower is an individual.** Each tower has its own tower ID, so two archer towers are different towers with different abilities and stats.
- **Position matters.** Enemies keep to their own path, and a walking enemy cannot pass the unit ahead; towers move like units in a grid tactics game, around unwalkable tiles or over them.
- **Each level stands alone.** A level takes the first towers of the hand, up to its cap, and nothing but meta progress carries over.

## Terms

Every section uses these words.

| Term | Meaning |
| --- | --- |
| Level | A map and its data, from paths to waves and energy income (Level data); won when every wave is finished |
| Hand | Up to 8 towers in order, kept until the player changes it; a level takes the first ones up to its hand cap (4–5) |
| Wave | A group of enemies spawned on a schedule of rounds counted from the wave's start; finished once all its spawns and LevelEvents have happened and all its enemies are dead |
| Round | A player phase, an enemy phase, then a level phase |
| Player phase | Every tower's shared turn: the player places or sells towers and casts any tower's abilities, then presses End round |
| Enemy phase | Enemies take their turns one at a time, each trying its abilities in its own order |
| Level phase | Spawns, LevelEvents, energy income, and wave starts and finishes happen; the name is open |
| LevelEvent | A scripted action at a set round of a wave, such as spawning enemies, giving energy or showing a message; not a pipeline event such as `HitResolved` |
| Energy | The in-level currency spent to place towers; each level sets how much comes in every round |
| Base | An entity some enemies attack; each level places its own, possibly several, and the level is lost when any base reaches 0 HP |
| Wall, chasm | Unwalkable tiles: no one stands on them, walking units go around them and some movement jumps over them; a wall also blocks straight projectiles and some line of sight |
| Speed | A stat every unit has; movement formulas usually read it |
| Tower | A player unit placed from the hand; heroes are towers too |
| Tower ID | What makes two archers different towers; lasting, unlike the battle-only `EntityId` |

## Related design docs

This overview says what the game is; the system designs below say how it runs. Each later section links the part of the game it describes to the doc that specifies it.

| Doc | What it specifies | Where the game uses it |
| --- | --- | --- |
| Entity System — Design | Entities: units, objects, hazards and the Environment; stats, teams, lifecycle and turns | Towers and enemies on the grid; turn order |
| Ability Pipeline — Effect Queue Architecture | Every change as an effect in one queue; modifiers, replacements and reactions | Walk, Attack and every other move |
| Formula System — Design | Numbers: damage and stat formulas, the buff pipeline, grid targeting patterns | Tower and enemy stats; attack ranges and areas |
| Condition System — Design | Yes/no rules: cast gates, target filters, triggers and passives | Which enemy a tower targets; when a passive fires |

## Game flow

The player picks a hand of up to 8 towers, then enters any unlocked level, which brings in the first ones up to its hand cap of 4–5; the level is won when every wave is finished and lost when any base reaches 0 HP.

&#91;embedded content: game flow · hand, level, waves, two-phase rounds\]

Enemies take their own turns, and the player phase counts as one shared turn for all towers; the Entity System still gives every unit a turn of its own (Changes the system docs need). A multiplayer mode could give each player a turn.

## Level data

A level is data: the map and everything scheduled on it.

- **Map.** The grid, with its paths, walls and chasms.
- **Bases.** Where each base stands; there can be several.
- **Hand cap.** How many towers of the hand come into the level (4–5).
- **Waves.** Each wave's start condition and its spawn schedule, in rounds counted from the wave's start.
- **LevelEvents.** Each one's wave, round and action.
- **Energy income.** How much energy comes in every round.

## Waves and LevelEvents

Each wave spawns its enemies on a schedule of rounds counted from the wave's own start: a slime in its first round and another in its third, for example. Spawns and LevelEvents happen in the level phase, after the enemies' turns. A wave starts on a condition such as a set round or the previous wave finishing, so waves can overlap, and the level is won when every wave is finished.

A wave is finished once all its spawns and LevelEvents have happened and all its enemies are dead, including those its LevelEvents spawned. Until then, killing every enemy on the grid does not end it.

A LevelEvent pairs a round of a wave with an action: in wave 5, round 3, for example, it could spawn 5 slimes at random places, give the player energy, or show a message on screen.

## Map: grid and paths

A level is a grid of tiles crossed by one or more paths, with walls and chasms no one can walk on; every entity takes exactly one tile for now.

&#91;embedded content: example map · path, wall and chasm, a tower walk and a jump\]

- **Directions.** Units move in 4 directions, never diagonally.
- **Paths.** Each enemy knows its path from the moment it spawns and always follows it, unless a specific rule changes it. Paths can branch.
- **Crossings.** Where two paths cross, a unit on the crossing tile blocks both.
- **Gaps.** A path whose consecutive tiles do not share an edge cannot be walked, so walking enemies will probably not spawn on it; enemies that move by distance can cross it.
- **Walls and chasms.** No one stands on them; walking units go around them, and some movement abilities jump over them. A wall also blocks straight projectiles and, for patterns that require it, line of sight.
- **Who stands where.** Enemies stay on their path; towers move across the walkable tiles off it. A level may mark **build tiles**; towers are then placed only on those (Chapter 1: the 5×5 square around the base), though they may walk off them.
- **Blocking.** A walking enemy cannot pass the unit ahead; jumping, flying, trampling and walk-over enemies can, and two entities can sometimes share a tile.
- **Spawning.** An enemy whose spawn tile is taken appears on the nearest free path tile.

Each level places its own base, possibly several, so the example leaves it out.

## Every move is an ability

Every action a unit takes is an ability: an enemy advances with **Walk**, a tower hits with **Attack**. Passives, statuses and reactions work as the Ability Pipeline — Effect Queue Architecture specifies.

| Who | Wants to | Uses | Notes |
| --- | --- | --- | --- |
| Enemy | Advance along its path | A movement ability: Walk, Jump, Teleport, Flying and more | Kinds differ in how they move and get past units (Movement kinds, below) |
| Enemy | Attack | Its attack abilities | Some attack only the base, others attack towers |
| Tower | Hit an enemy | An ability the player casts, or a passive | Passives fire on their trigger, in any phase |
| Tower | Reposition | A movement ability, such as Walk or Jump | Walkable tiles off the path; some can jump over a path |

In the player phase the player casts any ability of any placed tower, in any order. No unit has action or movement points; tower abilities have cooldowns instead, and an ability that also triggers like a passive goes on cooldown either way. In the enemy phase each enemy tries its abilities in its own order, some moving before they attack and others after.

The player phase counts as every tower's turn. When it starts, statuses on towers deal their ticks and cooldowns drop by one — enemies' cooldowns drop then too, so the player sees what each enemy can do next; when the player presses End round, status durations drop by one. Rules in the system docs that read a turn, from passive checks to `OncePerTurn`, read the player phase that way for towers.

**Movement kinds**

| Kind | Moves | Gets past the unit ahead |
| --- | --- | --- |
| Walk | Tile by tile along the path | No |
| Flying | Like Walk | Yes, through other enemies (tentative) |
| Walk over | Like Walk, for non-flying enemies that step over others | Yes |
| Trample | Like Walk, without stopping for units ahead (bosses, for example) | Yes, by trampling them |
| Jump | Straight to the target tile | Yes |
| Teleport | Same as Jump | Yes |
| By distance | Covers a distance instead of following path tiles, so it can cross gaps | Open |

Jump and Teleport skip the tiles in between, so passives that react to an enemy entering range there do not fire. Each movement ability also carries its own logic: one Jump lands one tile short when its target is taken, another lands one tile further. Towers use the same kinds (Tower movement and knockback, below).

## Tower movement and knockback

Towers move in 4 directions, much like units in a grid tactics game, and use the same movement kinds as enemies, such as Walk and Jump. A tower never stands on a path, a wall or a chasm: Walk goes around walls and chasms, and some movement abilities jump over them or over a path they reach.

Because towers cannot step onto path tiles, a path that runs from edge to edge splits the map into areas a walking tower cannot leave; only movement that jumps a path crosses between them.

Every unit, tower or enemy, has a Speed stat. Where a movement ability can take a unit is set the way the Formula System — Design sets an attack's reach: a pattern gives the shape, and a formula, usually reading Speed, gives the size.

Knockback works differently for enemies and towers; its details are out of scope here.

## Towers, enemies and the base

Towers and enemies are both units in the Entity System — Design's sense: they have HP and stats and usually block their tile. Enemies take turns of their own, while the player phase counts as one shared turn for all towers, which the Entity System's Unit kind does not allow for yet.

The base is an entity too: some enemies attack it and die doing so, others stay next to it and attack until they are killed. Each level places its own bases, possibly several; the level is lost when any of them reaches 0 HP, and bases that share one health pool may come later.

| Aspect | Towers | Enemies |
| --- | --- | --- |
| Team | Player | Enemy |
| Controlled by | The player | The game |
| Acts | Any time in the player phase, no turn order | One turn each in the enemy phase, trying its abilities in its own order |
| Limited by | Ability cooldowns; no action or movement points | No action or movement points; movement reach comes from Speed |
| Stands on | Walkable tiles off the path | Its own path |
| Moves with | Movement kinds such as Walk and Jump, like a grid tactics unit | A movement kind (Movement kinds, above) |
| Attacks | Abilities the player casts, and passives | The base only, or towers, by enemy |
| Arrives | Placed from the hand for energy | Spawned by waves and LevelEvents |
| Leaves | Sold or killed: back to the hand, placeable again | Killed, or dies attacking the base |
| Identity | Own tower ID | Per type, such as Slime |

Every entity is 1×1 for now, which matches the Entity System's one-tile footprint.

## Hand and placement

The player picks a hand of up to 8 towers in order, which stays until the player changes it, then enters any unlocked level. Each level has a hand cap, and only the first towers up to it, 4–5, come into the level.

During the level, towers are placed on tiles off the path — on build tiles only, when the level has them — by spending energy. Energy comes in every round and from LevelEvents; finishing a wave gives nothing for now, though kills and finished waves may pay energy or gold later.

Selling or retreating a tower refunds its placement cost × 0.5 × current HP / max HP in energy, and a tower that dies also returns to the hand. A returned tower costs its full price to place again.

Each tower has its own tower ID, so two archer towers are different towers with different abilities and stats. IDs would also allow trading later; trading is not in the game for now. A tower ID is not the Entity System's `EntityId`, which lives for one battle only.

## Between levels

Nothing from a level carries over to the next. Progress is meta: completing levels unlocks further levels, and a level's first clear can give a new tower (Chapter 1 gives Guardian, Mage, Priest, then Archer). A meta-currency or a similar reward is planned; what it buys is open.

## Changes the system docs need

The answers above changed thirteen things in the system docs. The system docs themselves were not rewritten: the code implements the changes, and `Docs/Combat — Implementation Notes.md` records how.

| Change | State |
| --- | --- |
| Entity System: no action or movement points; Speed; player, enemy and level phases | Built |
| Entity System: tile types (path, walkable, wall, chasm), paths with branches and gaps, spawning on the nearest free path tile | Built (build tiles added since) |
| Entity System: walls and chasms as tiles that block movement (walls also projectiles) | Built |
| Entity System: a Speed stat | Built |
| Entity System: tile sharing (flying, walk-over) | Not built |
| Entity System: the base (an entity with HP; any base at 0 HP loses; several per level) | Built; bases also cast abilities like towers |
| Entity System: wave membership | Built |
| Ability Pipeline: clocks (a tower's turn is the player phase) | Built; enemies' cooldowns drop at the player phase too |
| Ability Pipeline: dual-use abilities share one cooldown | Built |
| Ability Pipeline: movement kinds (Walk, Teleport, Jump; Flying, Walk over, Trample) | Walk, Teleport and Jump built; the rest not |
| Ability Pipeline: knockback differing for towers and enemies | Not built |
| Formula System: movement patterns (`Steps`, `PathAhead`) | Built |
| Condition System: passive checkpoints at the player phase's start and end | Built (passives re-check at every checkpoint) |

## Open questions

Four decisions are open; LevelEvents as abilities is deliberately left for later.

**Levels and waves**

- [ ] **LevelEvents as abilities.** To be decided later.
- [x] **Enemy turn order.** Highest Initiative first, then spawn order; the order is fixed when the enemy phase starts.

**Movement and paths**

- [ ] **Tile sharing.** Hazards already share tiles through the Entity System's overlay layer and will be the most common case; when may two units share one, as flying and walk-over enemies do?
- [ ] **Trample at a crossing.** Does a trampled unit move along its own path or the trampler's, perhaps decided by tags?

**Towers and energy**

- [ ] **New towers.** Partly answered: a new save starts with the catalog's starting towers, and a level's first clear can give one. Other ways (a shop, a meta-currency) are open.

## Changelog

| Date | Change |
| --- | --- |
| 2026-10-05 | Brought up to date with the game: build tiles, enemy cooldowns at the player phase, bases that act, first-clear rewards; the system-doc changes marked built or not; enemy turn order decided (Initiative); new towers partly answered |
| 2026-10-02 | No unit has action or movement points; enemies have Speed too, and movement reach comes from it. 5 questions open |
| 2026-10-02 | Tower clocks decided: the player phase is every tower's turn; tower statuses tick and cooldowns drop at its start, durations drop at End round. 6 questions open |
| 2026-10-02 | New Level data section (map, bases, hand cap, waves, LevelEvents, energy income); the level phase also pays energy and starts and finishes waves; Level phase question narrowed to Tower clocks. 7 questions open |
| 2026-10-02 | Units move in 4 directions; every unit has Speed, and movement destinations come from a pattern and a formula; walls and chasms, with walls blocking straight shots and some line of sight; knockback details out of scope; map example redrawn. 7 questions open |
| 2026-10-02 | Any base at 0 HP loses the level; new Tower movement and knockback section (grid-tactics movement, Walk and Jump, jumping paths); unwalkable tiles; map example redrawn. 9 questions open |
| 2026-10-02 | Every wave must be finished to win; new level phase after the enemies' turns for spawns and LevelEvents; bases placed per level, possibly several; enemies try abilities in their own order and always follow their path; hand kept until changed; energy every round; sell refund and full-cost re-placement. 7 questions open |
| 2026-10-02 | Wave schedules in wave-relative rounds, wave start conditions and overlap, wave finish rule; base behaviors; movement kinds table; path branches, crossings and gaps; tile sharing; tower cooldowns instead of points; selling and death return towers to the hand; hand of up to 8 with a level cap; currency is energy. 12 questions open |
| 2026-10-02 | Hand is picked before entering a level; waves defined (finished when all their enemies are dead) and the level is won after the last one; LevelEvents tied to a wave and round, with examples. 13 questions open |
| 2026-10-02 | Folded in the first answers: two-phase rounds, waves vs rounds, LevelEvent, the base, movement kinds, spawning, enemy and tower attacks, cooldowns, level select, hand and placement, tower IDs, meta progress. Added Terms and Changes the system docs need; 12 questions open |
| 2026-10-02 | First draft from the game description: levels and rounds, grid and paths, abilities, towers and enemies, tower picks, 16 open questions |
