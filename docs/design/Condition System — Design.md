# Condition System — Design

Oct 1, 2026 · @Eren

## Summary

A condition is a boolean expression in the formula language: evaluated by the formula core at a declared point, it reads game state and never changes it.

- **Boolean formulas.** Conditions share the formula language, context, validation and tooling. Beyond stats, what they read comes from queries that game systems register, such as `Target.HasStatus(Poison)`.
- **Explicit subjects.** Every read names whose state it reads: `Self`, `Source` or `Target`.
- **Declared evaluation points.** Cast gates, target filters, effect triggers and passives each fix what a condition can read; a read the point cannot provide is rejected in the editor.
- **No randomness in conditions.** An effect's proc chance is a separate field, so gates can be evaluated for UI and AI as often as needed.
- **Triggers decide the side.** Whether an effect listens as attacker or defender is part of its trigger (`OnHitDealt`, `OnHitTaken`), applied when effects are gathered.
- **Explainable.** A failed gate reports which part failed, in English, for tooltips and debugging.

## Goals and non-goals

Conditions succeed when designers can express any gate or filter by combining existing queries, and players can always see why something is unavailable.

**Goals**

- Any gate, filter or trigger check is written from existing queries, without code changes.
- A condition that cannot work where it is attached fails in the editor, not in play.
- UI and AI can evaluate any gate any number of times, with no side effects and no RNG draws.
- Players see why an action is unavailable.

**Non-goals**

- Behavior. Conditions answer yes or no; what happens next belongs to abilities and effects.
- Performance. Evaluation cost is negligible at this scale.
- Localization. Failure texts are always in English.

## Conditions are boolean formulas

A condition has no evaluator of its own: it is a formula whose result is a boolean, parsed, validated and evaluated by the formula core.

- **Shared with formulas:** the expression language, including `and`, `or`, `not` and game-registered queries, plus the context (Source, Target, Self, variables), validation, the trace, storage as text in assets and the editor tooling.
- **Added here:** evaluation points in place of damage phases, and two rules: a condition slot must produce a boolean, and a condition may not use `rand()`.
- **Why expressions:** a separate condition type per check (health below, stat above, has status…) multiplies with every stat, subject and comparison, and cannot express "or" or "not". One expression covers them all: `Self.HpPct < 0.3 and not Self.HasStatus(Silence)`.

The grammar lives in the formula design doc, and conditions use it unchanged; a bare `Self.HpPct` in a condition slot is a type error.

## What a condition can read

Beyond stats, everything a condition reads is a query that a game system registers; the table shows what a typical tactics game might register.

| Read | Example | Registered by | Returns |
| --- | --- | --- | --- |
| Stat | `Self.Str`, `Target.HpPct` | Stat catalog | Number |
| Status | `Target.HasStatus(Poison)` | Status system | Boolean |
| Status stacks | `Target.Stacks(Burn)` | Status system | Number |
| Buff | `Self.HasBuff(Rage)` | Buff system | Boolean |
| Life and control | `Target.IsAlive`, `Self.CanAct` | Combat system | Boolean |
| Relation | `Target.IsAlly`, `Target.IsEnemy` | Team system | Boolean, relative to `Self` |
| Event facts | `IsCrit`, `Damage` | Combat flow | Boolean or number, only where the event provides them |

- A game without statuses, buffs or teams registers no such queries; a condition that uses one fails validation.
- Each query is registered with its argument kind (e.g. a status name), result type and the evaluation points where it is valid, so the validator checks it like a stat.
- `CanAct` shows a good query shape: it is false under any status that prevents acting (stun, freeze, sleep), so conditions never list control statuses one by one.
- Numeric queries work in formulas too: `Damage * (1 + 0.1 * Target.Stacks(Burn))`.

## Where conditions are evaluated

Each condition slot declares its evaluation point, which fixes the context it can read; the validator rejects any read that point cannot provide.

| Evaluation point | When | Can read |
| --- | --- | --- |
| Cast gate | Before targeting, and whenever UI or AI asks | `Self` |
| Target filter | Once per candidate, while targeting and highlighting tiles | `Self`, `Target` (the candidate) |
| Effect trigger | When the effect's event fires, per target and hit | `Self`, `Source`, `Target` and the event's facts |
| Passive | At checkpoints (see Passives and re-evaluation) | `Self` |

- A read the point cannot provide is an editor error, e.g. `Cast gate reads IsCrit, but no attack has been rolled.`
- `Self` is the condition's owner. In cast gates and target filters it is the caster, so it equals `Source`.
- Event facts are variables produced by the combat flow: a hit provides `IsCrit` and `Damage`; other events provide their own.

## Triggers and chance

An effect is gathered by its trigger, gated by its condition and only then rolled against its chance; conditions themselves never draw random numbers.

&#91;embedded content: effect resolution · gather, check, roll, apply\]

Attacker and defender effects are gathered by side, then each passes the same deterministic check before its chance is rolled.

1. **Trigger.** Each effect declares the event it listens to, including its side: `OnHitDealt` when its owner attacks, `OnHitTaken` when its owner is hit, and events such as `OnDodge`, `OnKill` or `OnTurnStart`. Only matching effects are gathered.
2. **Condition.** The effect's condition is evaluated; `false` stops the effect.
3. **Chance.** The `chance` field, a formula such as `0.2 + Self.Per * 0.01`, is rolled once with the seeded RNG. Only effects that passed their condition roll, so RNG use stays deterministic.
4. **Apply.** The effect runs with `Self` bound to its owner.

- **Why chance is separate:** gates are evaluated again and again for UI, AI and previews. A random condition would flicker or consume RNG on every look; a separate chance field is rolled exactly once and reads plainly in tooltips ("On crit: 50% chance to apply Bleed").
- **Fixed order:** effects run in a fixed order (attacker's first, then defender's, each in gathering order), so every machine consumes RNG identically.
- **Roll frequency per effect:** each effect declares whether its chance rolls once per hit or once per attack (`rollPer: Hit | Attack`), so one game can use both. Which one fits is a design choice for each effect, not a rule of the condition system.

## Passives and re-evaluation

A passive's condition is re-checked at fixed checkpoints, and a passive may not modify what its own condition reads.

- **Checkpoints.** After every resolved hit, heal or status change, and at turn start and turn end. Between checkpoints a passive's state does not change.
- **No self-feedback.** The validator compares what the condition reads with what the passive modifies. A passive gated on `Self.HpPct` may not modify MaxHP; otherwise it could switch itself on and off at every checkpoint.
- **Optional hysteresis.** A threshold passive can take a separate `offCondition` (e.g. on at `Self.HpPct < 0.5`, off at `Self.HpPct >= 0.55`) when healing near the threshold would make it flicker.
- **Visible state.** Whether a passive is active is shown on the unit, so players can read it without opening a tooltip.

## Explaining failures, previews and AI

Because a condition is a tree and never changes state, the system can say which part failed, preview any gate and let AI query gates freely.

- **Failure reasons.** The trace marks the first failing leaf, and the UI turns it into English text such as "Requires HP below 30%". A slot can override the text with a `failText` when the generated one reads poorly.
- **Previews.** Gates are pure, so the UI evaluates them on every hover and redraw: greyed-out abilities, valid tiles, "Bleed on crit" hints.
- **AI.** AI evaluates gates and filters on hypothetical states ("if I move here, can I cast Purify?") with the same evaluator, drawing no random numbers.
- **Short-circuit.** `and` and `or` stop at the first deciding operand, left to right. Since conditions are pure, this affects only speed and the reported reason, never the result.

## Authoring and validation in Unity

Condition slots reuse the formula tooling unchanged: text fields in ScriptableObject assets, with the same drawer, validator, build gate and tests.

```csharp
[CreateAssetMenu(menuName = "Game/Effect")]
public sealed class EffectDefinition : ScriptableObject {
    public Trigger trigger = Trigger.OnHitDealt;

    [ConditionSlot(EvalPoint.EffectTrigger)]
    public Condition condition = new Condition("IsCrit");

    [FormulaSlot(Phase.OnHit)]
    public Formula chance = new Formula("0.5");

    public StatusId applies = StatusId.Bleed;
}

[Serializable]
public struct Condition {
    [SerializeField] string expression;        // empty means always true
    public Condition(string expression) => this.expression = expression;
    public IFormulaNode Compiled => FormulaCache.Get(expression);
}
```

- **Drawer.** Shows true or false against the FormulaTestBench units and highlights the part that failed.
- **Extra checks.** Beyond the formula checks: a non-boolean result in a condition slot, `rand()` inside a condition, and a passive that modifies what it reads.
- **Tests.** Unit tests per query, and golden tests per gate (state → expected result and failure text), run in CI with the formula tests.

## Examples

Six assets cover the typical uses; the last one combines a threshold with a negated status in a single expression.

| Asset | Evaluation point | Condition |
| --- | --- | --- |
| Rage (ability) | Cast gate | `Self.HpPct < 0.3` |
| Purify (ability) | Target filter | `Target.IsAlly and Target.HasStatus(Poison)` |
| Bleed (effect, chance `0.5`) | Effect trigger, `OnHitDealt` | `IsCrit` |
| Counter (effect) | Effect trigger, `OnDodge` | `Self.CanAct` |
| Berserker (passive) | Passive | `Self.HpPct < 0.5` |
| Executioner (effect) | Effect trigger, `OnHitDealt` | `Target.HpPct < 0.25 and not Target.HasStatus(Shielded)` |

## Open decisions

Two decisions that shape how conditions feel in play are still open.

- **Checkpoint granularity.** Re-check passives after every hit, or only after each full action? Per hit is more responsive; per action is easier to follow in multi-hit combos.
- **Failure texts.** Generate every reason from the tree, or require authored text for player-facing gates?
