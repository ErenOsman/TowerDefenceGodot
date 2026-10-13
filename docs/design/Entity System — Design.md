# Entity System — Design

Oct 2, 2026 · @Eren

## Summary

An entity is anything that has an identity in a battle: a unit, an object, a hazard or the Environment entity. Entities are plain data in `GameState`, every change to them is an effect, and every rule they carry is found by walking them.

This design builds on Ability Pipeline — Effect Queue Architecture, Formula System — Design and Condition System — Design, referred to below as the Ability Pipeline, the Formula System and the Condition System.

- **Plain data.** An entity's runtime state is a plain C# object; definitions are read-only assets.
- **Changed only by effects.** HP, position, statuses and team change only when an effect applies, so every change writes an event.
- **Computed on read.** Final stats, tags, team and capabilities are derived from base values and active rules whenever they are read.
- **One model for everything on the board.** Units, objects and hazards share one data shape and differ by kind and flags.
- **Stable identity.** An `EntityId` is never reused in a battle, and it is the final tie-break in every ordering rule.

### Goals and non-goals

**Goals**

- A new unit, object or hazard is an asset, not code.
- Play, previews, AI and tests share one entity model, because cloning `GameState` clones every entity.
- Every value a formula or condition reads about an entity comes from one documented query vocabulary.
- Dead entities keep their data, so kill credit, resurrection and the combat log can read it.

**Non-goals**

- Multi-tile entities. Every entity occupies at most one tile.
- Real-time movement or physics.
- Inventory and equipment management outside combat; items appear here only as rule sources.

## Core concepts

The following terms are used throughout this document.

| Term | Meaning |
| --- | --- |
| Entity | Anything with an `EntityId` in a battle: a unit, an object, a hazard or the Environment entity. |
| EntityId | A battle-unique integer that is never reused; the final tie-break in every ordering rule. |
| EntityDefinition | The read-only asset an entity is created from: kind, base stats, tags, flags, abilities and passives. |
| Kind | Unit, Object or Hazard. It decides occupancy, turns and default targeting. |
| Stat | A number named in the Formula System's stat catalog, such as `Str` or `MaxHp`: a base value plus modifiers. |
| Resource | A current amount that effects spend or restore, such as HP, mana or action points. |
| Capability | Whether an entity can act, move, cast or be targeted, computed from its life state, kind and tags. |
| Team | The side an entity fights for. Relations between teams decide who is an ally or an enemy. |
| Rule source | Anything that contributes modifiers, replacements or reactions: passives, statuses, items and auras. |
| Life state | Alive, Dead or Removed. |
| Environment entity | The one entity with fixed stats, no tile and no turns, used as Source for effects that no entity owns. |

The Formula System reads an entity through its `IEntity` interface.

## Entity state

An entity's runtime state is a plain C# object owned by `GameState`. It holds identity, placement, base values, resources and the instances that change during a battle.

```csharp
public sealed class Entity : IEntity
{
    public EntityId Id;                                  // battle-unique, never reused
    public IEntityDef Def;                               // read-only asset
    public EntityKind Kind;                              // Unit | Object | Hazard
    public LifeState Life;                               // Alive | Dead | Removed

    public TeamId BaseTeam;                              // effective team may differ (Teams and relations)
    public Cell? Position;                               // null when not on the board
    public Direction Facing;                             // read only when facing is enabled

    public StatBlock BaseStats;                          // from the definition, plus spawn adjustments
    public ResourceSet Resources;                        // HP, mana, action points, movement points
    public List<StatusInstance> Statuses = new();        // stacks, turns left, applier, shield pool
    public List<PassiveState> Passives = new();          // one per definition passive: active flag
    public List<ItemRef> Items = new();                  // equipped items, as rule sources
    public Dictionary<AbilityId, AbilityState> Abilities = new();  // cooldowns, charges

    public EntityId? Summoner;                           // set for summons
    public EntityId? CreatedBy;                          // set for objects and hazards made by an ability
    public TurnState Turn;                               // points refreshed, has acted this round
    public DeathRecord? Death;                           // killer, tile and item; set on death
}
```

- **Nothing derived is stored.** Final stats, tags, effective team and capabilities are computed on read from base values and active rules. A per-entity cache keyed by `GameState`'s version is allowed as an optimization, never as the source of truth.
- **No engine references.** No Unity objects, delegates or event subscriptions. `GameState.Clone()` deep-copies every entity and shares definitions.
- **Only effects write.** Every field changes inside an effect's `Apply`, which writes the matching event, so presentation and logs never miss a change.

## Kinds and occupancy

All kinds share one data shape; they differ in how they occupy tiles, whether they take turns and how they can be targeted.

| Kind | Tile layer | Takes turns | Has HP | Targetable by default | Examples |
| --- | --- | --- | --- | --- | --- |
| Unit | Blocking | Yes | Yes | Yes | Knight, Slime, summoned wolf |
| Object | Blocking | No | Optional | Only with HP | Barrel, totem, wall segment |
| Hazard | Overlay | No | No | No | Fire tile, poison pool, trap |
| Environment | None | No | No | Never | Source of GameRules reactions |

### Tile layers

- **Blocking layer.** At most one unit or object per tile. Movement cannot enter an occupied tile, and spawning into one follows the spawn rule (Lifecycle).
- **Overlay layer.** Any number of hazards per tile. Hazards never block movement or projectiles; they act through reactions to events such as `EntityEnteredTile` and `TurnStarted`.
- **Blocking flags.** `blocksMovement` and `blocksProjectiles` come from the definition. A Line pattern with `stopAtFirstBlocker` stops at the first entity whose `blocksProjectiles` is set and whose relation to the shooter passes the pattern's blocker filter.
- **Footprint.** Every entity occupies at most one tile.

### Facing

- Facing is a GameRules switch. When it is off, queries and patterns ignore it.
- When it is on, a `StepEffect` turns the mover toward its step, casting turns the caster toward the aim, and a `FaceEffect` covers explicit turns. Each change writes `FacingChanged`.
- `IsBehind` and `IsFacing` read it, and the Formula System's Facing orientation for patterns uses it.

### The Environment entity

- One Environment entity exists in every battle. It has fixed stats from GameRules, no tile, no turns and no HP; it can never be targeted and never dies.
- It is the Source of effects that no entity owns, since the Formula System requires Source never to be null: GameRules reactions such as collision damage, and the responses of hazards (Open decisions).

## Stats and resources

Stats are Formula System values computed on read; resources are current amounts that only effects change.

### Stats

- **Catalog.** Stat names come from the Formula System's catalog (`StatId`). An entity stores one base value per stat in its `StatBlock`.
- **Final value.** `Stats.Final(stat)`, which the Formula System calls through `IEntity`, runs the modifier pipeline over the base value and the modifiers gathered from the entity's rule sources (Rule sources).
- **Stats the entity system reads.** `MaxHp`, `MaxMana`, `Initiative`, `ActionPoints` and `MovePoints`. All other stats belong to abilities and rules.

### Resources

| Resource | Maximum | Refills | Changed by |
| --- | --- | --- | --- |
| HP | `MaxHp` | Never on its own | `DamageEffect`, `HealEffect` |
| Shield | Its status's pool | Never | `DamageEffect` (absorbs), shield statuses |
| Mana | `MaxMana` | Per GameRules, e.g. at `TurnStarted` | Costs, `ResourceEffect` |
| Action points | `ActionPoints` | At the owner's `TurnStarted` | Costs, `ResourceEffect` |
| Movement points | `MovePoints` | At the owner's `TurnStarted` | Walk costs, `ResourceEffect` |

- **Integers.** Resources are integers, matching the Formula System's rounding at slot output.
- **HP at zero.** HP never goes below 0. An entity at 0 HP stays Alive until the next checkpoint (Ability Pipeline).
- **Shields are statuses.** A shield is a status instance with a pool. `DamageEffect` drains pools newest first, and a pool that reaches 0 removes its status, so shield stacking and duration follow the status's own fields.
- **Max HP changes.** HP keeps its absolute value when `MaxHp` rises and is capped when `MaxHp` falls (default; Open decisions). Because `MaxHp` is computed on read, the cap applies on read: an entity reports `min(HP, MaxHp)`, and every effect that changes HP starts from that capped value.

## Capabilities

Capabilities say whether an entity can act, move, cast or be targeted. They are computed from life state, kind and tags, never stored, and the UI, the AI and the resolver call the same functions.

| Capability | True when | Blocked by tags |
| --- | --- | --- |
| `CanAct` | Alive, kind Unit, and no tag that prevents acting | `Stunned`, `Frozen`, `Asleep` |
| `CanMove` | `CanAct` and not rooted | `Rooted` |
| `CanCast(ability)` | `CanAct`, costs payable and the cast gate passes | `Silenced` for Spell abilities, `Disarmed` for Attack abilities |
| `IsTargetable(by)` | Alive, a targetable kind, and not hidden from `by` | `Untargetable`; `Stealthed` against enemies |

- **Control comes from tags.** Stun, freeze, sleep, root, silence, disarm and stealth are statuses whose main job is to grant a tag. Capabilities read tags, never status names, so a new control status needs no code; this is the shape the Condition System recommends for `CanAct`.
- **Forced movement.** Pushes and pulls ignore `CanMove`; only voluntary movement requires it.
- **Redirect.** A status tagged `Redirected` records its applier. While it is active, the entity's single-target abilities may target only that applier (hand aiming too). The softer `Taunted` only steers automatic choices (Instinct — Design).
- **Stealth and areas.** Stealth hides an entity from enemies' single-target selection. Area attacks still hit it unless their area filter excludes stealthed entities.
- **One check everywhere.** Targeting queries, `CastAbility.IsValid` and `StepEffect.IsValid` call these functions, so the UI never offers an action the resolver would reject.

## Teams and relations

Each entity has a base team, a status can override it, and a relation table decides who is an ally or an enemy.

- **Teams.** GameRules lists the teams of a battle, such as Player, Enemy and Neutral. An entity's base team is set when it spawns.
- **Relations.** A table maps every pair of teams to Ally, Enemy or Neutral. `IsAlly`, `IsEnemy` and target filters read it, and an entity is always its own ally.
- **Overrides.** A status with an `overrideTeam` field changes the effective team while it is active: the applier's team for charm, a fixed team for other effects. The newest override wins, and applying or ending one writes `TeamChanged`.
- **Summons.** A summon takes its summoner's effective team when it spawns. Later team changes of the summoner do not carry over.
- **Where it matters.** Target filters, aura filters, blocker filters and ally-based triggers such as `OnAllyHitTaken` read the effective team at the moment they are evaluated.

## Rule sources

An entity's modifiers, replacements and reactions come from four sources. The resolver gathers them by walking `GameState` every time it needs them, so rules are never registered or unregistered.

| Source | Lives on | Active while |
| --- | --- | --- |
| Passive | The entity's definition | Always, or while its passive condition holds |
| Status | A `StatusInstance` on the entity | The status exists |
| Item | The entity's `Items` | Equipped |
| Aura | Another entity's passive or status | The receiver matches the aura's filter when the rule is read |

```csharp
IEnumerable<IRule> RulesOf(Entity e, GameState s)
{
    foreach (var p in e.Passives.Where(p => p.Active)) foreach (var r in p.Def.Rules) yield return r;
    foreach (var st in e.Statuses)                     foreach (var r in st.Def.Rules) yield return r;  // oldest first
    foreach (var item in e.Items)                      foreach (var r in item.Def.Rules) yield return r;
    foreach (var other in s.EntitiesById())            // auras, by EntityId
        foreach (var aura in other.Auras())
            if (aura.Covers(e, other, s)) yield return aura.Rule;
}
```

- **Passives.** A passive holds modifiers, replacements and reactions, plus an optional passive condition. The Ability Pipeline re-checks the condition at every checkpoint, with the Condition System's hysteresis (`offCondition`) and its rule against self-feedback. The active flag lives in `PassiveState`, and every switch writes `PassiveActivated` or `PassiveDeactivated`, so the UI can show it.
- **Auras.** An aura is a rule whose filter names receivers instead of its owner, for example allies within 2 tiles gaining +10% Damage. Because rules are gathered on read, an aura follows its owner and its receivers with no tracking.
- **Order.** Passives, then statuses oldest first, then items, then auras by owner `EntityId`. This is the definition order that the Ability Pipeline's reaction ordering uses.
- **Dead and removed entities.** A Dead entity contributes only its `OnDeath` reactions and rules marked `worksWhenDead`, and its auras end with it. A Removed entity contributes nothing.
- **Buffs.** A buff is a status tagged Buff, so `HasBuff(X)` is `HasStatus(X)` limited to that tag.

## Lifecycle

An entity is Alive from its spawn until a checkpoint finds it at 0 HP. It then stays in `GameState` as Dead, and only a `RemoveEffect` takes it out of the battle.

&#91;embedded content: entity lifecycle · Alive, Dead, Removed\]

Kill credit, resurrection and the combat log read Dead entities; queries and rule gathering ignore Removed ones.

- **Spawn.** `SpawnEffect` creates an entity from a definition, assigns the next `EntityId` and writes `EntitySpawned`. If the target tile's blocking layer is taken, the entity goes to the nearest free tile within 1 tile in canonical order, or the effect fizzles (default; Open decisions). Spawning does not write `EntityEnteredTile`, so hazards on the tile wait for their next trigger.
- **Death.** At the checkpoint, an Alive entity at 0 HP becomes Dead. It leaves the blocking layer, loses its statuses except those marked `persistsThroughDeath`, and writes `EntityDied` with its killer and tile.
- **Kill credit.** The killer is the Source of the effect that brought HP to 0 within the item. The Environment entity is never credited.
- **Corpses.** A Dead entity keeps its data and its death tile in `DeathRecord`. It is invisible to targeting except for abilities whose filter asks for dead entities, such as resurrection or corpse explosion.
- **Resurrection.** `ResurrectEffect` returns a Dead entity to Alive on its death tile, or the nearest free tile, with HP from the effect's formula, and writes `EntityResurrected`. Cleared statuses do not return.
- **Removal.** `RemoveEffect` takes an entity out of the battle without a death: expired summons, spent hazards, cleaned-up corpses. It writes `EntityRemoved`, and no `OnDeath` or `OnKill` reaction fires. A Removed entity stays in `GameState` only so the event log can still name it.
- **Summons.** A summon outlives its summoner unless its definition sets `dieWithSummoner`, which removes it when the summoner dies.

Besides the Ability Pipeline's events, entities write the following:

| Event | Facts |
| --- | --- |
| `EntitySpawned` | entity, tile, creator |
| `EntityDied` | entity, killer, tile |
| `EntityResurrected` | entity, tile, HP |
| `EntityRemoved` | entity, reason |
| `TeamChanged` | entity, from, to |
| `FacingChanged` | entity, direction |
| `PassiveActivated`, `PassiveDeactivated` | entity, passive |

## Turns

Only units take turns. The turn order lives in `GameState` and is rebuilt at the start of every round.

- **Rounds.** `RoundStarted` and `RoundEnded` bracket each round. At `RoundStarted`, living units are sorted by `Initiative`, highest first, ties by `EntityId`, and the order is stored.
- **Changes mid-round.** Initiative changes take effect next round. Units spawned or resurrected during a round act from the next round (default; Open decisions), and units that die or are removed are skipped.
- **A unit's turn.** `TurnStarted(unit)` refreshes its action and movement points, then the unit issues commands, then `TurnEnded(unit)` counts its status durations down, as the Ability Pipeline specifies.
- **Units that cannot act.** A stunned unit still gets `TurnStarted` and `TurnEnded`, so its ticks and durations run; it simply issues no commands.
- **Objects and hazards** take no turns. Their rules react to other entities' turn events, such as a fire tile burning whoever starts a turn on it. Exception: bases (objects tagged `Base`) act and take their turn with the towers, so the player can cast their abilities.

## Query vocabulary

The entity system registers the following stats and queries with the Formula System and the Condition System. Every subject, `Self`, `Source` and `Target`, exposes the same set.

| Query | Type | Meaning |
| --- | --- | --- |
| `<Stat>`, e.g. `Str`, `MaxHp` | Number | Final value through the modifier pipeline |
| `Hp`, `Mana`, `Ap`, `Mp` | Number | Current resource, capped to its maximum |
| `HpPct` | Number | `Hp / MaxHp`, from 0 to 1 |
| `Shield` | Number | Sum of active shield pools |
| `IsAlive` | Bool | Life state is Alive |
| `CanAct`, `CanMove` | Bool | Capabilities |
| `HasStatus(X)`, `Stacks(X)` | Bool, Number | Status instances on the entity |
| `HasBuff(X)` | Bool | A status named X that is tagged Buff |
| `HasTag(X)` | Bool | Inherent or status-granted tag |
| `IsAlly`, `IsEnemy` | Bool | Relation to `Self` |
| `IsUnit`, `IsObject`, `IsHazard` | Bool | Kind |
| `Distance` | Number | Tiles from `Self`, in the grid metric |
| `IsBehind`, `IsFacing` | Bool | Facing relative to `Self`; only when facing is on |

- **Registration.** Each query is registered with its argument kind, result type and the evaluation points where it is valid, as the Condition System requires, so the validator checks it like a stat.
- **Relative queries.** `IsAlly`, `IsEnemy`, `Distance`, `IsBehind` and `IsFacing` compare the subject with `Self`. `Target.IsEnemy` in a target filter therefore means an enemy of the caster.
- **Dead subjects.** Every query works on a Dead entity, so `OnDeath` responses and corpse abilities can read the dead entity's stats and tags.

## Authoring in Unity

Entities are authored as `EntityDefinition` assets. Passives and items are separate assets, so many definitions can share them.

```csharp
[CreateAssetMenu(menuName = "Game/Entity")]
public sealed class EntityDefinition : ScriptableObject, IEntityDef
{
    public EntityKind kind = EntityKind.Unit;
    public Tag[] tags;                                       // Undead, Beast, Flying…
    public StatBlock baseStats;                              // values per StatId
    public bool blocksMovement = true, blocksProjectiles = true;

    public List<AbilityDefinition> abilities = new();        // Ability Pipeline
    public List<PassiveDefinition> passives = new();

    public bool dieWithSummoner;
    public EntityView view;                                  // prefab, bound by EntityId
}

[CreateAssetMenu(menuName = "Game/Passive")]
public sealed class PassiveDefinition : ScriptableObject
{
    [ConditionSlot(EvalPoint.Passive)] public Condition condition;     // empty = always active
    [ConditionSlot(EvalPoint.Passive)] public Condition offCondition;  // optional hysteresis
    public ModifierDef[] modifiers;                                    // Formula System
    public ReplacementRule[] replacements;                             // Ability Pipeline
    public ReactionDefinition[] reactions;                             // Ability Pipeline
    public AuraFilter aura;                                            // empty = owner only
}
```

- **StatBlock.** A serialized list of stat and value pairs. The validator flags a missing value for any stat the entity system reads.
- **Kind checks.** The entity validator rejects a Hazard with HP or abilities, and a Unit without `MaxHp` or `Initiative`. Abilities, passives and items go through the Formula System and Condition System validators.
- **Views.** `EntityView` is a MonoBehaviour that the Director creates on `EntitySpawned` and binds by `EntityId`. It reads only the view model, never `GameState`, as the Ability Pipeline specifies.
- **Assemblies.** `Entity`, `StatBlock` and the capability and relation functions live in `Game.Combat`. `EntityDefinition` and `PassiveDefinition` live in `Game.Combat.Unity`, and `EntityView` in `Game.Combat.Presentation`.

## Examples

Five entities and two flows show the model at work.

| Entity | Kind | Notable data |
| --- | --- | --- |
| Knight | Unit | Tag Human; passive Bodyguard, a replacement that redirects damage from adjacent allies |
| Slime | Unit | Spawned by an Orc's `OnDeath` reaction on the Orc's tile |
| Explosive Barrel | Object | 20 HP, `blocksProjectiles`; an `OnDeath` reaction deals 30 fire damage around it |
| Fire Tile | Hazard | Overlay; deals 10 fire damage to any entity that starts a turn on its tile or steps onto it; removed after 3 rounds |
| War Totem | Object | No HP; an aura gives allies within 2 tiles +10% Damage; `dieWithSummoner` |

### A death on a fire tile

The Knight kills an Orc standing on a Fire Tile. The Orc's `OnDeath` reaction spawns a Slime on its tile.

1. Batch: the Orc drops to 0 HP and stays Alive until the checkpoint.
2. Checkpoint: the Orc becomes Dead, leaves the blocking layer and writes `EntityDied` with the Knight as killer. Its `OnDeath` reaction queues a `SpawnEffect`.
3. `SpawnEffect`: the tile's blocking layer is free, so the Slime spawns there with the Orc's team and writes `EntitySpawned`. No `EntityEnteredTile` is written, so the Fire Tile does not react yet.
4. Next round, the Slime's `TurnStarted` triggers the Fire Tile: 10 fire damage with the Environment entity as Source.

### Charm

A Siren charms the Knight for 2 turns.

1. `ApplyStatusEffect(Charmed)` with `overrideTeam` set to the Siren's team writes `StatusApplied` and `TeamChanged` from Player to Enemy.
2. Every relation now reads the Knight as an enemy of the player's units: their area attacks with an enemy filter hit him, and his Bodyguard protects the Siren's allies instead.
3. At the Knight's second `TurnEnded`, Charmed expires and writes `StatusRemoved` and `TeamChanged` back to Player.

## Open decisions

The following decisions remain open. Until each is made, the implementation uses the stated default.

- **Spawning on an occupied tile.** Move to the nearest free tile within 1 tile, else fizzle (default), or always fizzle?
- **Max HP changes.** Keep absolute HP on a rise and cap it on a fall (default), or scale HP proportionally?
- **Statuses through death.** Clear all except those marked `persistsThroughDeath` (default), or keep every status for a later resurrection?
- **Hazard kill credit.** No credit, with the Environment entity as Source (default), or credit the hazard's creator?
- **Mid-round arrivals.** Spawned and resurrected units act from the next round (default), or join the current round by initiative?
- **Facing.** Off (default) until an ability or passive needs it, or on from the start?

## References

- Ability Pipeline — Effect Queue Architecture: effects, events, checkpoints, statuses, replacements and reactions that act on entities.
- Formula System — Design: the stat catalog, the modifier pipeline, rounding and the Environment Source rule.
- Condition System — Design: query registration, passive evaluation, hysteresis and the self-feedback rule.
