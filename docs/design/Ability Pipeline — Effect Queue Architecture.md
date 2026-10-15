# Ability Pipeline — Effect Queue Architecture

Oct 1, 2026 · @Eren · Godot pass 2026-10-15

## Summary

Every change to combat state is an effect taken from a single queue. Reactions wait until the current batch ends, and deaths are decided at a checkpoint after each queue item. The logic communicates only through events, which the presentation plays back.

This design builds on Formula System — Design and Condition System — Design, referred to below as the Formula System and the Condition System.

- **Single queue.** Abilities, movement, status ticks and reaction responses all run as effects. An ability's structure is defined by the effects it expands into.
- **Batches.** Effects that happen at the same moment form a batch. No reaction runs and no unit dies until the batch ends.
- **Three kinds of rules.** Formula System modifiers change numbers, replacements change effects, and reactions respond to events by queuing new effects.
- **Events as the only output.** The Director turns events into animation; the combat log, replays and tests read the same list.
- **One code path.** Play, tooltips, outcome previews and AI use the same resolver; previews and AI run it on a copy of the state.

### Goals and non-goals

**Goals**

- The same state, commands and seed produce the same event log on every machine.
- Nothing reacts and nobody dies in the middle of a batch.
- A tooltip, an outcome preview and the AI see exactly what play will do.
- A new ability, status or passive is an asset built from existing steps, not code.
- The combat core runs without the engine (`sim/`, plain GDScript), so tests, AI and a possible server share it.

**Non-goals**

- Full order independence. HP limits and movement make it unattainable; the resolution rules define every remaining order instead.
- Simultaneous or real-time turns.
- Performance optimization. Effects are small and turns are short, so the cost is negligible at tactics scale.

### The loop at a glance

&#91;embedded content: resolution loop · one queue, one checkpoint per item\]

Child effects created by Apply also go to the front, behind the reactions of the same item. A batch counts as one item, so an entire area attack has a single checkpoint.

## Core concepts

The following terms are used throughout this document. The code blocks marked *design sketch* are the Oct 1 design, written in C# before anything was built; the built classes are their GDScript ports under `sim/combat/` (`effect.gd`, `ability_instance.gd`, `resolver.gd`, `targeting.gd`…; names per docs/Sim Port.md: `Effect.IsValid` → `is_valid`, `UnitId` → `int`). The definitions shown in GDScript are the built classes.

| Term | Meaning |
| --- | --- |
| GameState | All combat data: units, stats, statuses, grid, turn order and RNG state. Plain GDScript (`sim/combat/game_state.gd`), cloneable, no engine calls. |
| Effect | The unit the resolver runs: `DamageEffect`, `HealEffect`, `ApplyStatusEffect`, `StepEffect`, `PushEffect`… Composite effects such as `CastAbility` and `Attack` only expand into other effects. |
| Queue | A deque of pending work. Child effects and reaction responses go to the front, so a cause finishes before unrelated work continues. |
| Queue item | What the resolver takes in one go: a single effect, or a batch. |
| Batch | Effects that happen at the same moment, such as one attack's hits on every target in its area. |
| Chain | The ordered effects for one target inside a batch: hit roll → damage → lifesteal → push. Later effects read earlier results. |
| Checkpoint | Runs after every queue item: deaths, passive re-checks, then reactions. |
| Event | An immutable fact the logic writes, such as `HitResolved` or `UnitDied`, with the event that caused it. |
| Event log | The ordered list of events, and the only output of the logic. |
| AbilityInstance | One use of an ability: caster, aim, frozen variables, per-target results, scoped modifiers and deferred reactions. |
| Reaction | A rule that responds to an event by queuing new effects (Rules). |

### Effect

An effect is checked, possibly replaced, then applied. Applying it changes state, writes events and may push child effects.

Design sketch (built: `sim/combat/effect.gd`):

```csharp
public abstract class Effect
{
    public UnitId Source;                // the Environment unit for traps and tiles (Formula System)
    public AbilityInstance Ability;      // null for status ticks and terrain
    public EventId Cause;                // the event that produced it; none for commands
    public TagSet Tags;                  // Attack, Spell, Fire, Reaction, Reflected…
    public int Depth;                    // the cause's depth + 1
    public bool Cancelled;

    public virtual bool IsValid(GameState s) => true;    // false = the effect fizzles
    public abstract void Apply(ResolveContext ctx);      // state, events, child effects
}
```

### Batch and chain

- A batch holds one chain per target, run in canonical target order (Targeting and patterns).
- Effects in a chain run in authored order and read earlier results through chain variables such as `HpLost`.
- During a batch, reactions are only collected and deaths are not decided. A unit at 0 HP stays on the grid until the checkpoint.
- A missed hit roll stops its own chain; the other chains run as normal.
- Forced moves run after all chains, in push order (Effect catalog).

### Checkpoint

1. **Deaths.** Every unit at 0 HP dies, by unit id, and each writes `UnitDied`.
2. **Passives.** Passive conditions are re-checked: the Condition System's Passive evaluation point.
3. **Reactions.** Reactions collected from this item's events are checked and rolled, and their effects are pushed to the front of the queue.

### AbilityInstance

Design sketch (built: `sim/combat/ability_instance.gd`):

```csharp
public sealed class AbilityInstance
{
    public AbilityInstanceId Id;
    public IAbilityDef Def;
    public UnitId Caster;
    public Aim Aim;                                         // tile + direction
    public Dictionary<VarId, Num> Frozen = new();           // Attack-phase results such as Power
    public Dictionary<UnitId, HitResult> Results = new();   // Hit, IsCrit, FinalDamage, HpLost per target
    public List<ScopedModifier> Scoped = new();             // for this ability only; removed by EndAbility
    public List<PendingReaction> Deferred = new();          // AfterAbility reactions
    public HashSet<RuleKey> Fired = new();                  // OncePerAbility limits, rollPer: Attack results
}
```

`CastAbility` pushes the ability's steps followed by an `EndAbility` effect. Every effect the ability causes is queued in front of `EndAbility`, so `EndAbility` runs only after the ability has fully resolved. It then removes scoped modifiers, writes `AbilityEnded` and starts deferred reactions.

### Events

| Event | Facts for formulas and conditions | Triggers (side) |
| --- | --- | --- |
| `AbilityDeclared` | ability tags | `OnCast` (caster), `OnAllyCast` |
| `AttackStarted` | `Power` | `OnAttackStarted`, `OnTargeted` |
| `HitResolved` | `Hit`, `IsCrit`, `Damage`, `FinalDamage` | `OnHitDealt`, `OnHitTaken`, `OnAllyHitTaken`; `OnDodge` when `Hit` is false |
| `DamageDealt` | `Damage`, `FinalDamage`, `Absorbed`, `HpLost`, `Overkill`, tags | `OnDamageDealt`, `OnDamageTaken` |
| `Healed` | `Amount`, `Overheal` | `OnHealed` |
| `StatusApplied`, `StatusRemoved` | status, stacks | `OnStatusApplied`, `OnStatusRemoved` |
| `UnitMoved`, `UnitEnteredTile` | from, to, move kind | `OnMove`, `OnEnterTile` |
| `Collision` | the unit or wall hit | `OnCollision` |
| `UnitDied` | killer | `OnDeath` (dying unit), `OnKill` (killer) |
| `TurnStarted`, `TurnEnded` | unit | `OnTurnStart`, `OnTurnEnd` |
| `AttackEnded`, `AbilityEnded` | ability tags | `OnAttackEnded`, `OnAbilityEnded` |
| `Fizzled`, `Prevented` | effect kind | none; debugging and presentation only |

`HitResolved` is written once per attack chain, after its effects. `DamageDealt` is written by every `DamageEffect`, including poison ticks and reflected damage. Taking damage and being hit by an attack are therefore different triggers.

## Resolution rules

The resolver applies the following rules. No other component determines resolution order.

1. **One item at a time.** The resolver takes the front item of the queue, one effect or one batch, and resolves it completely.
2. **Validity first.** `IsValid` runs against current state before an effect applies. A dead or missing target, or a mover that can no longer move, fizzles the effect and writes `Fizzled`.
3. **Replacements next.** Replacement rules may cancel, redirect or replace the effect (Rules). Each effect is redirected at most once.
4. **Numbers at apply time.** Formula slots resolve when their effect applies, against live state. Attack-phase slots are the exception: they freeze when the `Attack` effect starts, per the Formula System's snapshot rule.
5. **Batches are simultaneous.** Inside a batch, no reaction runs and no unit dies. Chains run in canonical target order, and effects in a chain run in authored order.
6. **Forced moves last.** A batch's pushes and pulls run after all its chains, in push order (Effect catalog).
7. **Children to the front.** Effects created while applying go to the front of the queue, in authored order.
8. **Checkpoint after every item.** Deaths by unit id, then passive re-checks, then reactions.
9. **Reactions in a fixed order.** For each event in log order: the event's source side, then its target side, then every other unit by unit id; each owner's rules in definition order. This extends the Condition System's attacker-then-defender order to third parties.
10. **Reactions before children.** Reaction responses reach the front after the item's child effects, so they run first. A reaction to `AbilityDeclared` therefore runs before the ability's first step.
11. **AfterAbility waits.** A reaction with `AfterAbility` timing is stored on the `AbilityInstance`. It starts as a new root ability when `EndAbility` runs.
12. **Depth limit.** An effect's depth is its cause's depth + 1. An effect deeper than 16 is dropped and logged as a warning.

- **Dead units.** A unit that dies leaves the grid at the checkpoint and cannot be targeted. Its rules stop, except `OnDeath` reactions and rules marked `worksWhenDead`; reactions it collected in the same item are dropped unless marked so.
- **Randomness.** RNG draws happen only in `Apply` and in reaction checks, in queue order, from the battle's seeded RNG (Simulation).
- **Between commands.** A command runs until the queue is empty, and only then is the next command accepted. A save between commands therefore needs only `GameState`.

### The resolver

Design sketch (built: `Resolver.run` in `sim/combat/resolver.gd`):

```csharp
public void Run(Effect command)
{
    queue.AddFirst(QueueItem.Single(command));
    while (queue.Count > 0)
    {
        var item = PopFront();                          // one effect, or a batch
        var ctx = new ResolveContext(state, log, item);

        foreach (var effect in item.InOrder(ctx))      // batch: chains in canonical order, HitResolved
        {                                               // at each chain's end; a miss ends its chain
            if (!effect.IsValid(state)) { log.Write(new Fizzled(effect)); continue; }
            rules.Replace(effect, state);               // cancel, redirect, replace
            if (effect.Cancelled) continue;
            effect.Apply(ctx);                          // formulas + modifiers, state, events, children
        }
        item.Finish(ctx);                               // a batch's forced moves, in push order (rule 6)
        PushFront(ctx.Children);                        // rule 7

        ResolveDeaths(ctx);                             // rule 8: HP <= 0 → UnitDied, by unit id
        rules.RecheckPassives(state, ctx);
        PushFront(rules.React(ctx.NewEvents, state));   // rules 9–10: condition, chance, response effects
    }
}
```

## Rules: modifiers, replacements, reactions

Statuses, passives, items, tiles and GameRules affect combat through three kinds of rules.

| Kind | Changes | Runs | Defined in |
| --- | --- | --- | --- |
| Modifier | A number: Flat, PctAdd, PctMult or Override on a stat or variable | When a formula slot resolves | Formula System |
| Replacement | An effect: cancel, redirect or replace it | Before the effect applies | This document |
| Reaction | Nothing directly; it queues new effects | At the checkpoint after its event | Condition System, extended here |

The resolver finds all three by walking `GameState`: units, then their statuses, passives and items, then tiles and GameRules. No rule is an event subscription (a signal), which is what lets previews clone the state (Simulation).

### Modifiers

- The Formula System pipeline applies unchanged: Flat, then PctAdd, then PctMult, then clamp, filtered by tags such as Attack, Spell or Fire.
- Outgoing modifiers come from the effect's source and incoming ones from its target.
- **Scoped modifiers** last for one ability. They live on the `AbilityInstance`, and `EndAbility` removes them; +10 Str for this attack is a reaction to `AbilityDeclared` that adds one.
- Expanding an area by 1 tile is a Flat +1 modifier on the area's `maxRadius` slot, filtered by tag.

### Replacements

A replacement intercepts an effect before it applies. It reads state but never changes it; anything it causes happens as effects.

```gdscript
class_name ReplacementRule                        # sim/combat/replacement_rule.gd
var matches: int = EffectKind.Damage
var with_tags: Array = []                         # e.g. Fire
var condition: Condition = Condition.new()        # Replacement point: Self, Source, Target, effect kind and tags
var action: int = ReplaceAction.Cancel            # Cancel | Redirect | Replace
var instead: Array = []                           # Steps, used by Replace
```

In content, replacements are entries of a passive's, a status's or the rules' `replacements` list.

| Example | Rule |
| --- | --- |
| Fire Immunity | Cancel a `DamageEffect` tagged Fire whose target is Self; writes `Prevented` |
| Bodyguard | Redirect a `DamageEffect` aimed at an adjacent ally to Self, while `Self.CanAct` |
| Unstoppable | Cancel a `PushEffect` whose target is Self |
| Stone Form | Replace a `PushEffect` on Self with `ApplyStatus(Rooted, 1 turn)` |

Cancels run before redirects, and redirects before replaces. An effect is redirected at most once, so two bodyguards cannot pass damage back and forth.

### Reactions

A reaction listens to an event, checks a condition, rolls a chance and queues its response effects. It follows the Condition System's trigger, condition and chance model, extended with a response list, timing, limits and tag filters.

```gdscript
class_name ReactionDef                            # sim/combat/reaction_def.gd
var trigger: int = Trigger.OnHitTaken             # event + side
var condition: Condition = Condition.new()        # Reaction-trigger point; empty = always true
var chance: Formula = Formula.new("1")            # OnHit phase
var roll_per: int = RollPer.Hit                   # or Attack
var timing: int = Timing.AfterItem                # or AfterAbility
var limit: int = Limit.None                       # OncePerAbility | OncePerTurn
var ignore_tags: Array = [Tags.Reflected]
var works_when_dead: bool = false
var response: Array = []                          # Steps: effects to queue
```

Reactions are content entries in `data/content/Reactions.json` (`Reaction/<Name>`) with the same fields (`trigger`, `condition`, `chance`, `rollPer`, `timing`, `limit`, `ignoreTags`, `worksWhenDead`, `response`); `AssetConverter` turns an entry into a `ReactionDef`.

- **Order of checks.** Reactions are gathered by trigger as events are written. At the checkpoint, in rule 9 order, each reaction's condition is evaluated, then its chance is rolled, then its response is queued. Only reactions that pass their condition roll, as the Condition System requires.
- **Roll frequency.** `rollPer: Attack` rolls once per `Attack` effect and stores the result on the `AbilityInstance` for its other hits.
- **Self and Source.** `Self` is the rule's owner. Effects in the response use the owner as Source, or the Environment unit for tiles and GameRules.
- **Event facts.** Response formulas read the triggering event's facts; Thorns, for example, deals `FinalDamage * 0.2`.
- **Reactions that are abilities.** A response can be `CastAbility`. The new ability receives its own `AbilityInstance` and the `Reaction` tag.

### Loop protection

- **Depth.** Rule 12 stops any chain of causes deeper than 16 effects.
- **Limits.** `OncePerAbility` and `OncePerTurn` prevent a rule from firing again in the same window; `OncePerTurn` resets at every `TurnStarted`.
- **Tags.** Reflected damage carries the `Reflected` tag, which damage reactions ignore by default, so two units with Thorns cannot reflect damage back and forth. Counters ignore abilities tagged `Reaction`.

## Formulas and conditions

The Formula System and the Condition System are used without modification. This section specifies where each formula phase and condition evaluation point runs in the queue, and defines the variables that combat adds.

### Formula phases in the queue

| Phase | Resolves in | How often | Reads |
| --- | --- | --- | --- |
| Targeting | Targeting queries (UI, AI) and the `Attack` effect's area | Once per aim | Source, Self |
| Attack | The `Attack` effect; results frozen in `AbilityInstance.Frozen` | Once per `Attack` effect | Source, Self |
| OnHit | `DamageEffect`, `HealEffect`, other chain effects and reaction chances | Per target and hit | Source, Target, Self, frozen and chain variables |
| Mitigation | Inside `DamageEffect`, after OnHit | Per target and hit | Source, Target, Self, `Damage` |

- A multi-hit attack is a `Repeat` of batches under one `Attack` effect, so every hit reads the same frozen `Power`, as the Formula System's snapshot rule requires.
- An ability with two `Attack` steps freezes `Power` twice; each step is a separate attack.
- The Formula System's Shield Breaker example runs unchanged: `Power` 156 freezes in the `Attack` effect, and each target's chain resolves `Damage` and `FinalDamage`, 211 for the target with 25 armor.

### Variables combat adds

| Variable | Produced by | Readable in |
| --- | --- | --- |
| `Power` | `Attack` effect | Later effects of the same attack |
| `Hit`, `IsCrit` | `RollHit` | Later effects in the same chain; `HitResolved` triggers |
| `Damage`, `FinalDamage` | `DamageEffect` | Later effects in the same chain; `DamageDealt` and `HitResolved` triggers |
| `Absorbed`, `HpLost`, `Overkill` | `DamageEffect` | Later effects in the same chain; `DamageDealt` triggers |
| `Amount`, `Overheal` | `HealEffect` | Later effects in the same chain; `Healed` triggers |

The validator extends the Formula System's phase check: a chain step may read only variables that an earlier step of the same chain produces. A Lifesteal step placed before its Damage step fails validation (Validate All, `AssetValidator`) with `HpLost is not produced yet`.

### Condition evaluation points in the queue

| Evaluation point | Runs in | Reads |
| --- | --- | --- |
| Cast gate | Targeting queries and `CastAbility.IsValid` | Self |
| Target filter | Targeting queries and the `Attack` effect's area, per candidate | Self, Target |
| Reaction trigger | The checkpoint, per collected reaction | Self, Source, Target, event facts |
| Passive | Every checkpoint, after deaths | Self |
| Replacement (new) | Before an effect applies | Self, Source, Target, effect kind and tags |
| Step (new) | `If` steps in an ability or a response | Self, Source, Target, frozen and chain variables |

- Reaction-trigger conditions see the state after the whole batch, plus the event's own facts. A check such as `Self.HpPct < 0.3` therefore accounts for every hit in that batch.
- **Checkpoint granularity**, left open in the Condition System, is fixed here: passives re-check after every queue item. An entire area attack is one checkpoint, and each hit of a multi-hit attack is its own.
- Conditions remain free of `rand()`; a chance is always a separate field, rolled once.

### Damage in formula terms

1. `Damage` is the damage step's OnHit slot, for example `Power`, with outgoing Damage modifiers.
2. On a crit, `Damage` is multiplied by the crit formula in GameRules.
3. `FinalDamage` is the Mitigation formula in GameRules, for example `Damage * 100 / (100 + Target.Armor)`, with incoming FinalDamage modifiers, floored at the slot output.
4. Shields absorb first (`Absorbed`), then HP takes the rest up to the HP left (`HpLost`); anything beyond is `Overkill`.

## Targeting and patterns

Targeting is a pure query shared by the UI, the AI and the resolver, so a tile the UI highlights is always a tile the ability can hit.

Design sketch (built: `sim/combat/targeting.gd`, `Targeting.can_cast`, `valid_aims`, `area_targets`):

```csharp
public static class Targeting
{
    // cast gate (Condition System) and costs; reason is the gate's failure text
    public static bool CanCast(GameState s, UnitId caster, IAbilityDef a, out string reason);

    // targeting pattern around the caster, then the target filter
    public static IEnumerable<Aim> ValidAims(GameState s, UnitId caster, IAbilityDef a);

    // area pattern around the aim, then the area filter, in canonical order
    public static IReadOnlyList<UnitId> AreaTargets(GameState s, UnitId caster, IAttackStep atk, Aim aim);
}
```

- **Two patterns, as in the Formula System.** The ability's `targeting` pattern defines where it can aim, centred on the caster. Each `Attack` step's `area` pattern defines what is hit around the aim.
- **Gathered once.** `AreaTargets` runs when the `Attack` effect starts. Units that enter or leave the area during the batch do not change it.
- **Canonical order.** Distance from the aim in the pattern's metric, then unit id; Line and Cone use distance along their direction. Batches, reactions and previews all use this order.
- **Projectiles.** A projectile that can be blocked is a Line pattern with `stopAtFirstBlocker`. A projectile that cannot be blocked is only a presentation hint.
- **Direction.** `TowardTarget` orientation uses the caster-to-aim direction stored in `Aim`, so a Cone keeps its direction even if the caster is moved during the ability.

## Effect catalog

Each effect has a single responsibility and writes the events listed below.

| Effect | Does | Writes |
| --- | --- | --- |
| `CastAbility` | Checks the cast gate, pays costs, pushes the steps and `EndAbility` | `AbilityDeclared` |
| `Attack` | Freezes Attack-phase slots, gathers area targets, pushes a batch and `AttackEnd` | `AttackStarted` |
| `RollHit` | Rolls hit and crit for one chain; a miss ends the chain | chain variables only |
| `DamageEffect` | OnHit, crit, Mitigation, shields, HP (Formulas and conditions) | `DamageDealt` |
| `HealEffect` | OnHit amount, capped at MaxHP | `Healed` |
| `ApplyStatusEffect`, `RemoveStatusEffect` | Adds or removes stacks per the status's stacking rule | `StatusApplied`, `StatusRemoved` |
| `StepEffect` | Moves a unit one tile | `UnitMoved`, `UnitEnteredTile` |
| `PushEffect` | Forced move, one tile at a time | `UnitMoved`, `UnitEnteredTile`, `Collision` |
| `TeleportEffect` | Moves a unit without crossing tiles | `UnitMoved`, `UnitEnteredTile` |
| `SpawnEffect` | Places a unit or a hazard | `UnitSpawned` |
| `ResourceEffect` | Changes mana, action points or cooldowns | `ResourceChanged` |
| `AttackEnd`, `EndAbility` | Close an attack or an ability; `EndAbility` clears scoped modifiers and starts deferred reactions | `AttackEnded`, `AbilityEnded` |

At the end of each attack chain, the batch writes `HitResolved` with the chain's `Hit`, `IsCrit`, `Damage` and `FinalDamage`.

### Movement

- **Walking.** A Walk ability expands into one `StepEffect` per tile, each its own queue item. Traps, zones and overwatch react after every step.
- **Interrupted walks.** A `StepEffect` fizzles if the mover is dead, rooted or no longer on the tile it should leave. The rest of the path then fizzles too.
- **Pushes.** A `PushEffect` moves its unit one tile at a time. A wall or a unit stops it and writes `Collision`; collision damage, if the game wants it, is a GameRules reaction to `Collision`.
- **Push order.** A batch's forced moves run after its chains. Pushes away from the aim go farthest unit first and pulls nearest first, ties by unit id, so the outer unit moves before it can block the one behind it.
- **Hazards.** Lava and traps are reactions to `UnitEnteredTile` with the Environment unit as Source. A pushed unit meets them at the checkpoint after the batch.

## Statuses and turns

A status is a set of rules with a lifetime, and a turn is delimited by two events. Neither requires an ability or a hit roll.

| Field | Meaning |
| --- | --- |
| `tags` | Debuff, Poison, Control… for filters, cleanses and immunities |
| `stacking` | Stack up to a cap, Refresh, Replace or Independent |
| `duration` | Turns, or permanent |
| `modifiers` | Formula System modifiers active while the status is active |
| `replacements`, `reactions` | Replacement rules and reactions active while the status is active |
| `passiveCondition` | Optional gate on the whole set of rules, re-checked at checkpoints (Condition System) |

- **State.** A `StatusInstance` in `GameState` holds the definition, stacks, turns left and the unit that applied it.
- **Turn flow.** The turn system queues `TurnStarted(unit)`, then the unit's commands, then `TurnEnded(unit)`. These are ordinary queue items with checkpoints.
- **Ticks.** Poison is a reaction to its owner's `OnTurnStart` that queues a `DamageEffect` tagged Poison for `Self.Stacks(Poison) * 5`. It involves no hit roll and no Attack phase.
- **Source of a tick.** The unit that applied the status, or the Environment unit if that unit is gone, since the Formula System requires Source never to be null.
- **Expiry.** Durations count down at the owner's `TurnEnded`. A status at 0 is removed with `StatusRemoved`, to which its own reactions can respond.
- **Queries.** `HasStatus` and `Stacks` come from the status system, as in the Condition System. Buffs take the same form whether or not they remain a separate system.

## Presentation

The Director turns the event log into a timeline. Logic never waits for animation, and presentation never changes logic.

- **Beats.** The events of one queue item form a beat. Beats play in order; events inside a beat play in parallel across units.
- **Presenters.** Each event type has a default presenter: `DamageDealt` → flinch and number, `UnitMoved` → walk or slide, `StatusApplied` → icon and VFX, `UnitDied` → death. An ability's presentation entry (`Presentations.json`) can override its own beats, for example cast → projectile → explosion.
- **Sync points.** A beat can wait for a signal from the beat before it, such as the impact frame of a swing (the clip's impact key, else `art/models/impacts.json`; `EntityRig`) or a projectile's arrival, before showing numbers.
- **View model.** HP bars, status icons and on-screen positions come from a view model that presenters update as they play. The UI never reads `GameState`, so HP drops when the fireball lands, not when the logic ran.
- **Skip.** Fast-forward applies the remaining view updates at once; the logic has already finished, so nothing is lost.
- **Other readers.** The combat log, replays and golden tests read the same event log.

## Simulation, preview and determinism

Previews and AI run the same resolver on a copy of the state, so their predictions match execution.

- **Clone.** `GameState.Clone()` deep-copies units, statuses, grid, turn order and RNG state; definitions are shared read-only assets. Rules come from state (Rules), so the copy carries its rules with it.
- **Modes.** The Formula System's `EvalMode` drives the resolver. `Execute` uses the battle RNG; `PreviewMin` and `PreviewMax` set `rand()` to its bounds and never touch the battle RNG.
- **Damage preview.** Both preview passes assume the hit lands without a crit, and hit and crit chances come from their own formulas. The tooltip then reads 36–44 damage, 75% to hit.
- **Outcome preview.** The same passes show pushes, collisions and deaths: *kills* when `PreviewMin` kills, *may kill* when only `PreviewMax` does.
- **Chance reactions.** Previews skip reactions that require a roll and mark them *may trigger*; reactions without a roll, such as Thorns, are shown.
- **AI.** Cast gates and target filters prune candidates first (Condition System). Each remaining ability and aim runs on a clone in a preview mode, and the AI scores the resulting state and events.
- **Determinism.** One project-owned, integer-based RNG per battle (Formula System). Draws happen only in `Apply` and reaction checks, in queue order, so the same state, commands and seed write the same event log; golden tests compare those logs.
- **Saves and replays.** Between commands the queue is empty, so a save consists of `GameState` alone. A replay consists of the starting state, the seed and the command list.

## Authoring

Abilities, statuses and reactions are content entries in `data/content/Abilities.json`, `Statuses.json` and `Reactions.json` (keys `Ability/<Name>`, `Status/<Name>`, `Reaction/<Name>`; docs/Content.md). Their structure is a list of steps, while numbers and conditions remain text, as the Formula System specifies. `AssetConverter` turns each entry into the simulation's def (`AbilityDef`, `StatusDef`, `ReactionDef`) and each step item into its `Step` class.

An ability entry (abridged from `Ability/Example/Fireball`):

```json
"Ability/Example/Fireball": {
  "id": "Fireball",
  "tags": ["Attack", "Spell", "Fire"],
  "costs": [{ "resource": "Mana", "amount": 5 }],
  "castGate": "",
  "targeting": { "shape": "Diamond", "minRadius": "0", "maxRadius": "6", … },
  "targetFilter": "",
  "steps": { "items": [
    { "$type": "AttackStepData",
      "area": { "shape": "Circle", "minRadius": "0", "maxRadius": "1", … },
      "areaFilter": "",
      "power": "100",
      "canMiss": true, "canCrit": true,
      "onHit": { "items": [ { "$type": "DamageStepData", "amount": "ActionPower", "tags": [], "on": "Target" } ] } }
  ] },
  "presentation": "Presentation/Example/Fireball Presentation"
}
```

The step it becomes (`sim/combat/attack_step.gd`, abridged):

```gdscript
class_name AttackStep extends Step
var area: PatternDef = PatternDef.single()
var area_filter: Condition = Condition.new()      # Target-filter point for area candidates
var power: Formula = Formula.new("100")           # Attack phase; frozen for every hit of this attack
var can_miss: bool = true                         # chances come from GameRules
var can_crit: bool = true
var on_hit: Array = []                            # Steps: one chain per target
```

`area` and `power` are fields of `AttackStep`, so one ability can contain several attacks.

| Step | Expands into | Notes |
| --- | --- | --- |
| `Attack` | `Attack` effect, then a batch of chains and `AttackEnd` | Freezes Attack-phase slots |
| `RollHit` | `RollHit` | Added automatically when `canMiss` or `canCrit` is set |
| `Damage`, `Heal` | `DamageEffect`, `HealEffect` | OnHit slot with its rounding |
| `ApplyStatus`, `RemoveStatus` | `ApplyStatusEffect`, `RemoveStatusEffect` | Stacks as a formula |
| `Push`, `Pull`, `MoveSelf`, `Teleport` | Movement effects | Distance as a formula |
| `Spawn` | `SpawnEffect` | Units or hazards |
| `If` | Its `then` or `else` steps | Step evaluation point |
| `Repeat` | One batch per repeat under the same attack | Multi-hit; count as a formula |
| `Bounce` | The next batch, after the previous checkpoint | Chain lightning; skips units already hit |
| `CastAbility` | A new ability with its own instance | For reactions such as counters |

- **Step types.** Each step item names its type in `$type` (`AttackStepData`, `DamageStepData`…; one `sim/data/<name>_step_data.gd` per type). `ContentSerializer.SCHEMA` lists every type's fields; the wiki Content Editor and `tools/content_check.gd -- --schema` read it.
- **Renames.** Saved data records each step's type name. Renaming a step class means renaming its `$type` in every content file; an unknown `$type` is a load problem (`tests/test_content_all.gd` fails), so saved steps are never lost silently.
- **Steps and text.** Nesting and lists are what the editors (the wiki Content Editor, the JSON itself) handle well. Formulas and conditions inside steps remain text, with the formula tooling's diffs and validation.
- **Validation.** The Formula System's validator also checks step order for chain variables, event facts in responses, and that `Repeat` and `Bounce` counts resolve to at least 1.

| Folder | Holds |
| --- | --- |
| `sim/formulas/` | Formula and condition core (engine-free) |
| `sim/combat/` | `GameState`, effects, resolver, rules, events, targeting, steps (engine-free) |
| `sim/data/` | Ability, status and reaction assets (content entries), the converter to the defs, the validator |
| `sim/presentation/` | Director, view model (`ViewFrame`, `FrameRecorder`) |
| `game/level/presenters/` | Presenters, one per event kind |
| `addons/td_tools/`, `game/dev/` | Validate All, Balance Sheet, Level Playtester |
| `tests/`, `tools/golden.gd` | Unit tests (`test_combat.gd`, `test_asset.gd`…) and the golden logs |

Only `sim/` is the core; nothing in it touches the engine, and `game/` reads the event log and the view model, never the reverse. The core works on its own defs (`AbilityDef`, `StatusDef`, `ReactionDef`), so core tests build defs directly in code (`tests/test_combat.gd`) without any content file.

## Example flows

The following flows illustrate the resolution rules. Steps are listed in resolution order, and each queue item ends with a checkpoint.

### Fireball: area attack with reactions

A Mage casts Fireball, `power` `100`, on a Circle containing A, B and C; none of the units has armor. A has Thorns (20% of `FinalDamage`, tagged Reflected) and Fire Vulnerability (+20% incoming), and A's ally has Enrage (`OnAllyHitTaken`: +10 Str).

1. `CastAbility`: mana paid, `AbilityDeclared`; pushes `Attack` and `EndAbility`. No reactions.
2. `Attack`: `Power` 100 frozen; targets A, B, C in canonical order; pushes the batch and `AttackEnd`.
3. Batch:
   - A: hit, `DamageEffect` 100 × 1.2 = 120, `HitResolved`.
   - B: dodge, so the chain ends; `HitResolved` with `Hit` false.
   - C: crit, `DamageEffect` 100 × 1.5 = 150, `HitResolved`.
   - Checkpoint: no deaths. For A's hit, Thorns (target side) and then Enrage (A's ally) go to the front.
4. Thorns: `DamageEffect` 24 to the Mage, tagged Reflected, so the Mage's own damage reactions ignore it.
5. Enrage: `ApplyStatusEffect` +10 Str on A's ally.
6. `AttackEnd` writes `AttackEnded`.
7. `EndAbility` writes `AbilityEnded`; there are no deferred reactions.

The Director plays the cast (1), the projectile and explosion (2), A, B and C reacting together (3), then Thorns on the Mage and Enrage on the ally (4–5).

### Shield Bash: hit, push, collision

A Knight hits B for 80 and pushes it 2 tiles. B has 100 HP, no armor and a wall two tiles behind it; GameRules deals 10 damage on `Collision`.

1. `CastAbility`: stamina paid; pushes `Attack` and `EndAbility`.
2. `Attack`: single target B; pushes the batch and `AttackEnd`.
3. Batch:
   - B: hit, `DamageEffect` 80 (B at 20), `HitResolved`.
   - Forced moves: B slides one tile, meets the wall and writes `Collision`.
   - Checkpoint: no deaths; the collision reaction goes to the front.
4. `DamageEffect` 10 from the Environment unit (B at 10).
5. `AttackEnd`.
6. `EndAbility`.

If the 80 damage had reduced B to 0 HP, B would still be pushed, because deaths are decided at the checkpoint. B would then die at the wall, and the collision damage would fizzle on a dead target.

### Walk: interrupted by overwatch

A Rogue walks 3 tiles past an Archer with Overwatch: `OnEnterTile` inside its zone, condition `Self.CanAct`, `OncePerTurn`, response `CastAbility(Pinning Shot)`.

1. `CastAbility(Walk)`: movement points paid; pushes three `StepEffect`s and `EndAbility`.
2. `StepEffect` 1: the Rogue enters tile 1, inside the zone, and `UnitEnteredTile` is written. Checkpoint: Overwatch goes to the front.
3. Pinning Shot, tagged Reaction, resolves as an ability of its own: the Rogue takes damage and is Rooted.
4. `StepEffect` 2 fizzles because the Rogue is Rooted, and so does `StepEffect` 3.
5. `EndAbility`.

### Chain Lightning: bounces

Chain Lightning hits one enemy, then bounces twice to the nearest enemy within 2 tiles that it has not hit yet.

1. `CastAbility`; pushes `Attack` and `EndAbility`.
2. `Attack`: `Power` 60 frozen; target T1; pushes the batch, `Bounce` with 2 left, and `AttackEnd`.
3. Batch on T1, then its checkpoint; T1's reactions resolve.
4. `Bounce` picks T2 from the units alive now, in canonical order around T1, and pushes a batch and `Bounce` with 1 left.
5. Batch on T2, `Bounce` picks T3, batch on T3.
6. `AttackEnd`, then `EndAbility`.

Every bounce reads the same frozen `Power` 60, and a unit killed by a reaction between bounces is never picked.

### Poison: a tick without an ability

U carries 3 stacks of Poison applied by an enemy Shaman, and U has no armor.

1. `TurnStarted(U)`. Checkpoint: Poison's `OnTurnStart` reaction queues a `DamageEffect` tagged Poison for `Self.Stacks(Poison) * 5` = 15, with the Shaman as Source.
2. `DamageEffect` 15. If U dies, `UnitDied` is written and the Shaman's `OnKill` reactions follow.
3. U's commands, then `TurnEnded(U)`: Poison's duration counts down, and at 0 it is removed with `StatusRemoved`.

## In the Godot build

All of it is built, in `sim/` (a 1:1 port of the C# core, checked against it by `tools/golden.gd`). The core loop (`GameState`, `Effect`, `Resolver` with batches and checkpoints, `EventLog`) writes the same log for the same seed (`test_same_seed_writes_the_same_log`); the Formula System's Shield Breaker deals 211 (`test_shield_breaker_deals_211`); `Targeting.can_cast`, `valid_aims` and `area_targets` serve the UI, the AI and the resolver; scoped modifiers, replacements, reactions with limits and tags, statuses and turns run, and the depth limit stops a two-unit heal loop (`test_depth_limit_stops_a_heal_loop`); Fireball, Shield Bash, Walk and Chain Lightning exist as content entries (`tests/test_asset.gd` plays them from the assets); the Director, presenters and view model let HP drop on the impact frame and skip (`tests/test_director.gd`); cloning and the preview passes drive the previews (`AimPreview`, `PhaseForecast`); units pick their aims with `Instinct` (Instinct — Design).

History: the doc's roadmap built the headless core first (core loop, formulas, targeting, rules, assets, presentation, preview and AI, each with a test as its done-criterion) in the Unity project's C#, with abilities as ScriptableObjects holding `[SerializeReference]` step lists edited in the Inspector, and one assembly per layer (`Game.Formulas`, `Game.Combat` with no engine references, `Game.Combat.Unity` for the assets, `Game.Combat.Presentation`, `Game.Combat.Editor`, `Game.Combat.Tests`). The Godot build ported that core to GDScript and moved the assets into `data/content/*.json`.

## Open decisions

The following decisions remain open. Until each is made, the implementation uses the stated default.

- **Reactions of units that die.** Drop what a unit collected in the batch that killed it (default), or let it fire, such as Thorns on a killing blow? `worksWhenDead` covers exceptions either way.
- **Tick timing.** Damage at the owner's turn start and countdown at its turn end (default), or both at turn end?
- **Ticks that scale with the applier.** Resolve the amount at application and store it (default), or read the applier live at every tick?
- **Lifesteal base.** `HpLost` (default, which ignores overkill and shields) or `FinalDamage`?
- **Third-party order.** Unit id (default) or initiative for reactions from units that are neither source nor target?
- **Chance reactions in previews.** Mark them *may trigger* (default), or hide them?

## References

- Formula System — Design: formulas, phases, modifiers, patterns, numbers and RNG, used here without modification.
- Condition System — Design: conditions, evaluation points, triggers and chance, on which reactions are built.
- Magic: The Gathering Comprehensive Rules: the stack, triggered abilities and state-based actions, the model for batches and checkpoints.
- Slay the Spire's action queue (`addToTop`, `addToBottom`): the model for child effects and reactions going to the front.
- XCOM 2's game state history and visualization: the model for the event log and the Director.
- Unreal Engine's Gameplay Ability System: gameplay tags, and gameplay cues kept separate from logic.
