# Formula System — Design

Oct 1, 2026 · @Eren

## Summary

Formulas are small, side-effect-free expressions that compile into trees and resolve at explicit phases against a typed context.

- **Composable.** Formulas are built from `Const`, `Stat`, `Var`, arithmetic, `min/max/clamp` and `if` nodes; a new formula is a new combination, not new code.
- **Phase-safe.** Every slot declares when it resolves (Targeting, Attack, OnHit, Mitigation). A formula that reads something its phase does not provide is rejected before the game runs.
- **Buffs in a separate pipeline.** Flat, then additive %, then multiplicative %, then clamp: the same order for every value.
- **Parameterized patterns.** Shape, distance metric, radius range, orientation and line of sight are separate fields.
- **One resolver, three uses.** The same code produces the result, the tooltip preview and the breakdown.
- **Deterministic.** Exact `decimal` arithmetic, rounding only at slot outputs and a seeded project RNG give the same result on every machine.
- **Data, not code.** Formulas are text fields in ScriptableObject assets, validated in the editor and at build time.

## Goals and non-goals

The system succeeds when a designer can write a new formula safely without going through a programmer.

**Goals**

- Writing a new formula from existing building blocks needs no code change.
- An invalid formula fails in the editor and at build time, never at runtime.
- Tooltip previews and actual results come from the same code.
- Every number is explainable: players and developers can see a breakdown.
- The same inputs and seed produce the same result on every machine.

**Non-goals**

- A general-purpose scripting language. Formulas produce numbers; targeting and effect chains belong to another layer.
- Performance. Evaluating a few nodes per hit is negligible at this scale.
- Localization. Tooltips and breakdowns are always in English.

## Core concepts

A formula is a recipe with no value until it is resolved; these terms name where, when and against what that happens.

| Term | Meaning |
| --- | --- |
| Formula | An expression that produces a number: text in an asset, a node tree at runtime. |
| Resolution | Evaluating a formula against a context to get a number. |
| Slot | A field that expects a formula (Range, Power, Damage…). Declares its phase, output type and rounding. |
| Phase | When resolution happens: Targeting, Attack, OnHit, Mitigation. |
| Context | Everything readable during resolution: Source, Target, variables, RNG, mode. |
| Variable | A named result of a phase (Power, Damage); later phases read it. |
| Stat | A unit attribute (Str, MaxHP…): base value plus stat modifiers. |
| Modifier | A flat or percentage change applied to a stat or a variable. |
| Snapshot | A value frozen at one moment and reused unchanged by later phases. |
| Trace | A step-by-step breakdown of a resolution, shown in tooltips and debugging. |
| Self | The owner of a formula: the unit carrying a modifier or trait, or the user of an ability. |

## Formulas as expression trees

At runtime a formula is a tree of small, immutable nodes, each able to evaluate itself; there is no central switch.

&#91;embedded content: damage formula tree · 12 nodes\]

Leaves read data (Stat, Var, Const) and inner nodes compute, so a new formula is a new combination of existing nodes rather than new code.

| Node | In text | What it does |
| --- | --- | --- |
| `Const` | `100`, `0.05` | A literal number, held exactly |
| `Stat` | `Source.Str`, `Target.MaxHP`, `Self.Str` | The subject's final stat value, stat modifiers included |
| `Query` | `Target.HasStatus(Weakened)`, `Target.Stacks(Burn)` | A query registered by a game system; returns a number or a boolean |
| `Var` | `Power`, `Damage` | The result of an earlier phase |
| `Op` | `a + b`, `a * b`, `a / b`, `-a` | Arithmetic; division by zero returns 0 and logs a warning |
| `Logic` | `a and b`, `a or b`, `not a` | Boolean logic |
| `Func` | `min`, `max`, `clamp`, `floor`, `round` | Helper functions |
| `Compare`, `If` | `if(Target.HpPct < 0.3, 1.5, 1)` | A conditional value; only the chosen branch is evaluated |
| `Random` | `rand(0.9, 1.1)` | Draws only from the seeded RNG in the context |
| `Ref` | `@BaseMelee` | A reference to a named formula in the FormulaLibrary |

The core is plain C# with no `UnityEngine` reference. `Num` is a thin wrapper around `decimal`; see Numbers, rounding and randomness.

```csharp
[Flags] public enum Needs { None = 0, Target = 1, Power = 2, Damage = 4, Self = 8 }
public enum Subject { Source, Target, Self }

public interface IFormulaNode {
    Num Evaluate(EvalContext ctx);
    Needs Requires { get; }            // for phase validation
}

public sealed class Const : IFormulaNode {
    public readonly Num Value;
    public Const(Num value) => Value = value;
    public Needs Requires => Needs.None;
    public Num Evaluate(EvalContext ctx) => Value;
}

public sealed class StatRef : IFormulaNode {
    public readonly Subject Who;       // Source | Target | Self
    public readonly StatId Stat;
    public StatRef(Subject who, StatId stat) { Who = who; Stat = stat; }
    public Needs Requires => Who switch {
        Subject.Target => Needs.Target,
        Subject.Self   => Needs.Self,  // the validator maps it to Source or Target
        _              => Needs.None
    };
    public Num Evaluate(EvalContext ctx) {
        Num v = ctx.Unit(Who).Stats.Final(Stat);     // stat modifiers included
        ctx.Trace?.Add($"{Who}.{Stat}", v);
        return v;
    }
}

public sealed class Mul : IFormulaNode {
    public readonly IFormulaNode A, B;
    public Mul(IFormulaNode a, IFormulaNode b) { A = a; B = b; }
    public Needs Requires => A.Requires | B.Requires;
    public Num Evaluate(EvalContext ctx) => A.Evaluate(ctx) * B.Evaluate(ctx);
}

public sealed class EvalContext {
    public Phase Phase;
    public EvalMode Mode;              // Execute | PreviewMin | PreviewMax
    public IUnit Source;               // an "Environment" unit for environmental effects
    public IUnit Target;               // null during Targeting and Attack
    public IUnit Self;                 // the formula's owner; equals Source in ability slots
    public IReadOnlyDictionary<VarId, Num> Vars;
    public IRng Rng;                   // seeded, integer-based; unused in previews
    public Trace Trace;                // collects a breakdown when not null
    public IUnit Unit(Subject s) => s switch {
        Subject.Source => Source,
        Subject.Target => Target,
        _              => Self
    };
}
```

## Expression language

Formulas are written in a small, side-effect-free expression language: it produces numbers and cannot change game state.

```
expr    := or
or      := and ('or' and)*
and     := not ('and' not)*
not     := 'not' not | cmp
cmp     := sum (('<' | '<=' | '>' | '>=' | '==' | '!=') sum)?
sum     := prod (('+' | '-') prod)*
prod    := unary (('*' | '/') unary)*
unary   := '-' unary | atom
atom    := NUMBER | ref | call | '(' expr ')'
ref     := SUBJECT '.' NAME ('(' NAME ')')? | VAR | '@' NAME
SUBJECT := 'Source' | 'Target' | 'Self'
call    := FUNC '(' expr (',' expr)* ')'    // min, max, clamp, floor, round, if, rand
```

- Lower rules bind tighter: `a + b * c` parses as `a + (b * c)`.
- Comparisons, `and`, `or`, `not` and boolean queries produce booleans; arithmetic produces numbers. `if(c, a, b)` takes a boolean and evaluates only the chosen branch. Nodes are typed, and the parser checks that every slot gets the type it expects, a number for formula slots.
- **Stats and queries come from game systems.** After a subject, a `NAME` is a stat from the stat catalog or a query from the query registry, such as `Target.HasStatus(Weakened)` or `Target.Stacks(Burn)`. The core has no built-in game concepts: a game without statuses registers no status queries, and a formula that uses one fails validation.
- `Self` is the formula's owner: the unit carrying a modifier or trait, or the user of an ability, where it equals `Source`. The validator checks it as `Source` for ability slots and outgoing modifiers, and as `Target` for incoming ones.
- `VAR` names come from phase outputs and `@NAME` from the FormulaLibrary; an unknown name fails at parse time.
- A hand-written recursive-descent parser reports errors with a column, e.g. `col 14: unknown stat 'Strr'`.
- Parsing is culture-invariant: numbers use `CultureInfo.InvariantCulture` and names compare with `StringComparison.Ordinal`. On a Turkish-locale machine, `"0.05"` can otherwise parse as 5, and `ToLower()` turns `I` into `ı`.

## Phases, context and validation

Every slot resolves in exactly one phase and may read only what that phase provides; this is checked in the editor and at build time, never at runtime.

&#91;embedded content: resolution phases · 4 phases, per-target loop\]

Targeting and Attack run once per action; OnHit and Mitigation repeat for every target in the area and read the Power frozen at Attack.

- **Slot → phase.** Range and area radii → Targeting; Power → Attack; Damage and Heal → OnHit; armor and resistances → Mitigation. The phase is declared in the slot's `[FormulaSlot]` attribute.
- **Phase check.** A formula's `Requires` set must be a subset of what its phase provides. Otherwise the error is explicit: `Range reads Target.MaxHP, but Targeting has no target.`
- **No cycles.** Variables are read only from earlier phases, so Power and Damage cannot depend on each other; `@Ref` chains get their own cycle check.
- **Source is never null.** Environmental effects such as traps and poison tiles use a fixed-stat "Environment" unit as Source.

**Snapshot rules**

- Power resolves once at Attack and is frozen. In a multi-hit attack, a buff triggered by the first hit does not change the Power of later hits.
- OnHit and Mitigation read live values for every target and every hit.
- A slot can opt out with `[FormulaSlot(Phase.Attack, Snapshot = false)]`, for example when every hit should recompute Power; the default does not change.

## Modifier pipeline

Formulas produce base values only; buffs and debuffs apply in a separate pipeline, in the same fixed order for every value.

```latex
\text{Final} = \operatorname{clamp}\Big( (\text{Base} + \textstyle\sum \text{Flat}) \times (1 + \textstyle\sum \text{PctAdd}) \times \textstyle\prod (1 + \text{PctMult}),\ \text{min},\ \text{max} \Big)
```

| Kind | Example | Stacking |
| --- | --- | --- |
| Flat | +10 Str, +20 Power | Summed |
| PctAdd | +20% and +30% Power | Summed first: ×1.5 |
| PctMult | ×1.2 and ×1.3 | Multiplied separately: ×1.56 |
| Override | "Damage is exactly 1" | Replaces everything; rarely used |

- **Stat modifiers** (Str, MaxHP) are already included in the final value a `Stat` node reads.
- **Variable modifiers** (Power, Damage) apply at the slot output. "+20% attack power" is a Power modifier applied once at Attack, so it affects every hit of that attack equally.
- **Statuses usually act through modifiers.** A status that halves its owner's damage adds a PctMult of −50% (×0.5) to that owner's outgoing Damage; one that halves damage taken adds it to incoming FinalDamage. The status system supplies these while the status is active, so adding a status never means editing formulas. A formula reads a status only for an ability-specific interaction, e.g. `Damage * if(Target.HasStatus(Burning), 2, 1)`.
- **Amounts can be formulas.** A modifier's amount may be a formula, resolved in the phase of the value it modifies and validated like a slot. For example, an enemy trait that adds a Flat `-Self.Str` to the FinalDamage it takes reduces every hit by its own Str.
- **Why two percentage kinds:** additive percentages keep stacking linear and easy to balance; multiplicative ones are for rare, strong effects. Path of Exile's "increased" (additive) versus "more" (multiplicative) is a well-known example.

## Interface with game systems

The formula system answers one question: given this context and these modifiers, what is the number? Game systems decide which context, which modifiers, when and how many times.

**Game systems provide, per resolution**

- **The slot and its phase.** The combat flow runs Targeting and Attack once per action, then OnHit and Mitigation for every target and every hit.
- **The context.** Source, Target, Self (the formula's owner) and a seeded RNG.
- **The vocabulary.** Stat names and queries, such as statuses, buffs or teams, registered with their argument and result types. The formula core has no built-in game concepts.
- **The modifiers for that value, already filtered.** Outgoing ones come from the attacker and incoming ones from the target, narrowed by tags such as Attack or Spell.

**The formula system**

- Evaluates the formula, applies the modifiers in the fixed order, then clamps and rounds per the slot's rule.
- Returns the number and, when asked, the breakdown.
- Reads nothing beyond the context and changes no game state.

Which modifiers exist, who owns them, damage types and hit structure belong to the combat and buff systems and are specified in their own documents.

## Patterns

A pattern is a small definition rather than an enum value: shape, distance metric, radius range, orientation and blocking rules. The pattern gives the shape; formulas give the size.

&#91;embedded content: grid pattern shapes · 8 shapes, radius 3\]

At the same radius, Diamond selects 25 tiles, Circle 37 and Square 49; Line and Cone are undefined without a direction.

| Field | Values | Notes |
| --- | --- | --- |
| `shape` | Diamond, Square, Circle, Plus, Diagonal, Line, Cone, Custom | Diamond = Manhattan, Square = Chebyshev, Circle = Euclidean |
| `minRadius`, `maxRadius` | Formula | Resolved at Targeting, floored to int, at least 0; `minRadius > 0` makes a ring |
| `orientation` | Fixed, Facing, TowardTarget | Required for Line and Cone |
| `includeCenter` | true / false | Usually true for area effects |
| `requiresLineOfSight` | true / false | Tiles behind obstacles are excluded |
| `stopAtFirstBlocker` | true / false | For Line: stops at the first obstacle |

- **Two patterns per action:** a `targeting` pattern (where you can aim, centred on Source) and an `area` pattern (what is hit around the aimed tile).
- **Circle rule:** `dx² + dy² ≤ (r + 0.5)²`, computed in integers as `4(dx² + dy²) ≤ (2r + 1)²`. Without the +0.5, small circles cannot be told apart from Diamond; at r = 2 both select the same 13 tiles.
- **Custom shapes:** `Union` and `Difference` cover most needs, e.g. ring = Diamond(max) − Diamond(min − 1). Irregular shapes such as a knight's move use a `Custom` mask.
- **In Unity:** `PatternDef` is a serializable class whose radii are `Formula` fields; its drawer shows a small grid preview.

## Numbers, rounding and randomness

All formula math uses one numeric type: C#'s `decimal`, wrapped in a thin `Num` struct. The numbers designers type are held exactly, and results match on every platform.

Binary floating point cannot hold values such as 0.05 or 1.15 exactly, and rounding boundaries expose it: in double, 1.15 × 100 = 114.99999999999999, which floors to 114. Float results can also differ in the last digit across compilers and platforms (Mono/IL2CPP, x64/ARM), and a floor turns that into a 1 HP difference.

`decimal` avoids both, and its speed does not matter at this scale. If it ever does, a 64-bit fixed-point type is the fallback, and `Num` keeps that swap to one file.

```csharp
public readonly struct Num {
    readonly decimal v;
    Num(decimal v) => this.v = v;

    public static implicit operator Num(int i) => new Num(i);
    public static Num Parse(string s) => new Num(decimal.Parse(s, CultureInfo.InvariantCulture));

    public static Num operator +(Num a, Num b) => new Num(a.v + b.v);
    public static Num operator *(Num a, Num b) => new Num(a.v * b.v);
    public static Num operator /(Num a, Num b) => b.v == 0 ? new Num(0) : new Num(a.v / b.v);
    public int FloorToInt() => (int)decimal.Floor(v);
    // −, comparisons and min/max follow the same pattern
    // no conversion from float on purpose: floats cannot leak into the simulation
}
```

- **Fractional data:** Unity does not serialize `decimal`, so fractional values come from formula text or from integer fields (e.g. 2000 basis points = 20% for a modifier amount). No simulation data lives in `float` fields.
- **Rounding:** never inside a formula; once, at the slot output, per the slot's rule. Damage → int, `floor`; Range and radii → int, `floor`, at least 0; Power → not rounded.
- **Randomness:** only through `rand()` and the seeded RNG in the context, a project-owned, integer-based generator (e.g. xorshift or PCG). `UnityEngine.Random` shares global state and is unavailable in the engine-free core; `System.Random` is not guaranteed to produce the same sequence across .NET versions. Crits draw from the same RNG in a fixed order.
- **Previews:** tooltips run two passes, with `rand()` returning its lower and then its upper bound, so the tooltip reads "36–44 damage". This holds while the formula is monotonic in the random term, which damage variance almost always is.
- **Breakdowns:** with `Trace` enabled, each node records its contribution; the same English text feeds tooltips and debugging and costs nothing when disabled.

## Storage and tooling in Unity

Formulas are data: they live as text fields in ScriptableObject assets. Code holds only the building blocks, and the editor holds the tools that make writing formulas safe.

&#91;embedded content: formula system layers · editor, data, core\]

Assets live in git as text; editor tools edit and validate them, and the game compiles each text into a tree once, on load.

- **Data, not code.** ScriptableObjects are Unity's established home for designer-authored data. Formulas in code would cost a recompile and domain reload per balance tweak and tie designers to programmers; generating C# from the text would pay the same cost to gain only performance, a non-goal.
- **Text, not a `[SerializeReference]` graph.** Text gives one-line diffs, pastes into spreadsheets and can be read by a non-Unity server. The drawer still shows the parsed tree as a read-only preview.

```csharp
[CreateAssetMenu(menuName = "Game/Ability")]
public sealed class AbilityDefinition : ScriptableObject {
    public PatternDef targeting;
    public PatternDef area;

    [FormulaSlot(Phase.Attack)]
    public Formula power = new Formula("100");

    [FormulaSlot(Phase.OnHit, Round.Floor)]
    public Formula damage = new Formula("Power");
}

[Serializable]
public struct Formula {
    [SerializeField] string expression;             // the single source of truth
    public Formula(string expression) => this.expression = expression;
    public IFormulaNode Compiled => FormulaCache.Get(expression);   // parsed once, cached by text
}
```

- **Shared formulas and names.** A FormulaLibrary asset holds named formulas (`@BaseMelee`); a GameRules asset holds game-wide ones such as mitigation and crit chance. Stat names come from one catalog, a `StatId` enum or a StatCatalog asset.
- **Editor tools.** A `FormulaSlot` drawer parses as you type, checks the phase and previews the result and breakdown on `FormulaTestBench` units. A Playground window, a Validate All command and an `IPreprocessBuildWithReport` build gate complete the set.
- **Runtime.** Each text compiles once, on first use or at startup, into an immutable tree cached by its text, so editing a formula in Play Mode takes effect on the next resolution.
- **Assemblies.** The core (`Game.Formulas`) is an asmdef with No Engine References, shared by the Unity client, a server and tests. Asset types live in `Game.Formulas.Unity`, tools in `Game.Formulas.Editor`.
- **Spreadsheets (optional).** If balancing moves to sheets, an importer writes rows into the assets, and each field keeps a single source of truth.

## Worked example

In this example, Shield Breaker deals **211 damage**. Source: 20 Str, 12 Per, a +20% Power buff. Target: 400 max HP, 100 current HP, 25 armor.

`ShieldBreaker.asset` fields, as the Inspector shows them:

| Field | Value |
| --- | --- |
| targeting | Diamond · min `1` · max `1 + floor(Source.Per / 5)` |
| area | Plus · max `1` · includes center |
| power | `100 + Source.Str * 1.5` |
| damage | `(Power + Target.MaxHP * 0.05) * if(Target.HpPct < 0.3, 1.5, 1)` |
| mitigation (GameRules) | `Damage * 100 / (100 + Target.Armor)` |

The breakdown, shared by the tooltip and debugging:

```
Range       = 1 + floor(Source.Per(12) / 5)                 = 3      → tiles at distance 1–3
Power       = 100 + Source.Str(20) × 1.5                    = 130
            + Power modifiers (+20%)                         = 156    → snapshot
Damage      = Power(156) + Target.MaxHP(400) × 0.05         = 176
            × if(Target.HpPct(0.25) < 0.3 → 1.5)             = 264
FinalDamage = Damage(264) × 100 / (100 + Target.Armor(25))   = 211.2  → floor → 211
```

OnHit and Mitigation run separately for each target in the Plus area; Power is 156 for all of them.

## Validation and testing

Formula errors are caught before the game runs: as you type in the drawer, in bulk with Validate All, and finally at the build gate and in CI.

- **One validator.** The drawer, Validate All, the build gate and CI all call the same `Validator`, so they always agree.
- **Checks.** Parse errors (with column), unknown stats, queries, variables or `@Ref`s, phase violations, type mismatches, `@Ref` cycles and constant division by zero.
- **Unit tests.** The core is engine-free, so its tests run in Unity Test Framework's Edit Mode or, if preferred, in a separate .NET test project. Every node type is covered, especially that `if` evaluates only the chosen branch and `rand` draws only from the context RNG.
- **Golden tests.** A few fixed scenarios per ability (stats + seed → expected result and breakdown). A deliberate balance change updates the table; an accidental one breaks a test. Running them on every target platform confirms the results match exactly.
- **CI.** Validate All and the tests run on every commit and block the merge on failure.

## Open decisions

Three decisions that shape the design are still open.

- **Network model.** Server-authoritative or lockstep? `decimal` works for both. Under a server-authoritative model it mainly keeps client previews exact; lockstep also needs a deterministic RNG consumption order and input timing.
- **Where balancing happens.** Only in the Inspector, or in spreadsheets? Spreadsheets need an importer and a single source of truth per field.
- **Rounding per slot.** `floor` or `round` for Damage? It changes how the game feels and is set in one place, the slot's `[FormulaSlot]` attribute.
