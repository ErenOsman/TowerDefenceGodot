# Sim Port — porting the simulation to Godot 4.7: conventions (READ FIRST)

The Unity game at `~/game` (read-only!) is being rebuilt in this Godot project. Its rules live in an
engine-free C# simulation (`~/game/Assets/Scripts/Game/`), which we port **1:1 to GDScript**: same
classes, same methods, same behaviour, same event log. The C# code *is* the spec; the design docs in
`~/game/Docs/Design/` explain intent when the code is unclear. The game's content (towers, abilities,
levels…) is data: `res://data/content/*.json` (copied from `~/game/Content/`), loaded by the data layer.
The C# tests (`~/game/Assets/Tests/EditMode/*.cs`, 183 of them) are ported too; they pass on the C#
(see "The oracle"), so they define "done".

## Layout
| C# | Godot |
|---|---|
| `Scripts/Game/Formulas/*.cs` | `res://sim/formulas/` |
| `Scripts/Game/Combat/*.cs` (+ `Entity/`) | `res://sim/combat/` |
| `Scripts/Game/Level/*.cs` | `res://sim/level/` |
| `Scripts/Game/Meta/*.cs` | `res://sim/meta/` |
| `Scripts/Game/Presentation/*.cs` | `res://sim/presentation/` |
| `Scripts/Game/Data/*.cs` (assets, converter, validator, content JSON) | `res://sim/data/` |
| `Tests/EditMode/XTests.cs` | `res://tests/test_x.gd` (one file per C# test file, `Fixture.cs` → `tests/fixture.gd`) |
| presentation / UI (`Scripts/Gameplay`, `Scripts/UI`) | `res://game/` (later phase; not a 1:1 port) |

**One global class per file.** Every C# class/struct/enum/interface becomes its own `.gd` file with
`class_name <SameNameAsCSharp>` (file name = snake_case of the class: `AbilityInstance` → `ability_instance.gd`).
C# files holding many classes (Effects.cs, Steps.cs, State.cs…) become many files. Other agents port other
files *at the same time* and refer to your classes by their C# names, so never rename a class. Exceptions
(Godot already owns the name): `Orientation` → `PatternOrientation`; `Pos` → use `Vector2i` directly (no class);
`Dir` → `Vector2i` too (helpers in `Dirs`, see below); `EntityId` → plain `int` (0 = Environment, -1 = None);
`Num` → plain `float` + the `Num` static helpers (already written: `sim/formulas/num.gd`). If a name you
need clashes with a Godot global (the check fails with "Class ... hides a global"), prefix it with `Td` and
write the choice at the end of this file under "Renames".

## Naming
- Classes: C# name. Methods: `snake_case` of the C# name (`ValidAims` → `valid_aims`, `CanCast` → `can_cast`).
- Fields: C# lowercase definition fields keep their names (`cooldown`, `maxRadius` → `max_radius`: snake_case
  every multi-word identifier). Runtime PascalCase properties → snake_case (`Entity.PathId` → `path_id`).
- Computed C# properties (`Alive`, `IsNone`, `Pos`) → GDScript properties with a getter, so callers write
  `e.alive` like the C#: `var alive: bool: get: return life == LifeState.Alive`. Methods with parameters stay methods.
- Static classes (`Targeting`, `Instinct`, `Tags`, `AbilityText`, `Directions`) → `class_name X` with `static func`s and `const`s.
- Interfaces (`IEntity`, `IRng`, `IRuleSource`, `IFormulaNode`, `IPresenter`) → base classes with the same name
  whose methods `push_error("abstract")`; implementers `extends` them (or just duck-type when extending is impossible).
- Enums: own file, `class_name <EnumName>`, members as `const` ints in C# order, plus `const NAMES := [...]`
  and `static func parse(s: String) -> int` (JSON stores enum *names*) and `static func name_of(v: int) -> String`.
  Usage reads like C#: `Stacking.Refresh`, `Trigger.OnHitTaken`.
- Constants: `Tags.Attack` etc. stay `const`.
- Default values: match the C# field initialisers exactly (they are what the JSON omits).

## Types
- `Num` → `float`. ALWAYS route arithmetic on formula values through `Num.add/sub/mul/div/mod` (or `Num.fix`
  the result) so decimal exactness holds; compare with `==` after fixing. Stats, facts, variables: floats.
- `Pos` → `Vector2i` (`.x`, `.y`; `+` works; Manhattan = `absi(a.x-b.x)+absi(a.y-b.y)`). `Dir` → `Vector2i`
  with `Dirs.between(a,b)`, `Dirs.cardinal_between(a,b)`, `Dirs.reverse(d)` (= `-d`), `Dirs.NONE`,
  `Dirs.is_none(d)`; `CardinalDirection` enum + `Directions.to_dir(c)` as in C#. (`Dirs` is written by the Combat A agent.)
- `EntityId` → `int`; `EntityId.Environment` → `0`, `EntityId.None` → `-1`, `IsNone` → `id < 0`.
- `List<T>` → `Array` (typed where cheap: `Array[int]`), `Dictionary<K,V>` → `Dictionary`, `HashSet<string>` →
  `Dictionary` used as a set (`{tag: true}`) **or** an `Array` of strings — pick per class and keep it consistent;
  `Tags.set_of(tags)` / `Tags.union(a, b)` return Dictionaries used as sets.
- `decimal`/`int` facts in `GameEvent.Facts` → floats. Strings compare ordinal (default).
- Nullable references → `null`. Structs (value copies!) → where the C# copies a struct by value, copy explicitly.
- `IEnumerable` returning methods → return `Array`. LINQ → loops. `OrderBy` is stable; `Array.sort_custom` is
  NOT — every ordering must be total (the C# tie-breaks by EntityId; keep them).
- Exceptions: GDScript has none. A C# method that throws (parser/validator errors, `FormulaException`) returns
  `null`/`false` and records the message in a `last_error: String` field or returns an error list; tests that
  `Assert.Throws` check that instead. Never `assert()` for user-data errors; `push_error` only for programmer errors.
- Deep copies (`GameState.Clone`, `Entity.Clone`, `IRng.Clone`) → explicit `clone()` methods copying every field the C# copies.
- `ulong` RNG: GDScript `int` is a wrapping signed 64-bit; implement xorshift64* with masks:
  `s ^= (s >> 12) & 0xFFFFFFFFFFFFF` (logical shift = arithmetic shift masked to 52 bits), `s ^= s << 25`,
  `s ^= (s >> 27) & 0x1FFFFFFFFF`, result `((s * 0x2545F4914F6CDD1D) >> 32) & 0xFFFFFFFF`.
  Test vectors: seed 12345 → 2555902770, 3234773579, 328846939; seed 0 → 226735074; seed 7 `next_unit()` → 0.82024666643701494 (≈, 9 decimals after `Num.fix`).
- Godot `Dictionary` keeps insertion order (C# Dictionary effectively did too); keep insertion orders the same as the C#.

## Files you must not touch
`~/game` is read-only. Never edit files another agent owns (see the task brief); if you need an API from a
class someone else is porting, read its C# and call the snake_case name you expect — the integration pass
fixes mismatches. Put small shared helpers you need in your own files.

## Checking your work
- `./check.sh` — parse-checks every script (prints `CHECK OK n scripts` or the failing files + SCRIPT ERRORs).
  Classes other agents have not written yet show as "Identifier not found": ignore those, fix your own.
- `./test.sh [--filter name]` — runs `tests/test_*.gd` (TestCase subclasses, methods `test_*`, asserts from
  `tests/test_case.gd`: `assert_eq`, `assert_num`, `assert_seq`, `assert_set`, `assert_true`, `assert_contains`…).
  Both scripts take a lock, so parallel agents queue; each run takes ~5–20 s.
- A GDScript runtime error inside a test (null call, missing method) prints `SCRIPT ERROR` and the test goes
  on returning null: treat every SCRIPT ERROR as a failure.

## The oracle
The C# simulation compiles and its 183 tests pass on this server with .NET 8:
`cd ~/godot/oracle && PATH=$HOME/dotnet:$PATH dotnet test -nologo -v q [--filter Name]`.
To see what the C# really does for a case, add a throwaway `[Test]` to `~/godot/oracle/Probe.cs`, write the
result to a file (`System.IO.File.WriteAllText("/home/ubuntu/godot/oracle/probe.txt", …)`) and run it with
`--filter Probe`. Golden (`Golden.cs` / `tools/golden.gd`) plays the frozen content snapshot `~/godot/oracle/content/`
(Unity's content on 2026-10-15), not `data/content`; see `~/godot/oracle/README.md`. `EventLog.Dump(state)` gives the full event log as text: the GDScript port's `dump()` must
produce the same lines, so the two can be diffed.

## Style
`extends RefCounted` by default (omit for plain classes; nothing in sim/ touches Nodes). Tabs. Type hints where
easy. Keep the C# comments' meaning as `##` doc comments on classes and non-obvious methods. Keep methods in the
C# order so reviewers can diff side by side. No Godot engine calls in sim/ (no Node, no Resource, no `load`),
except `JSON` and `FileAccess` in `sim/data/`.

## Renames (append here when a C# name could not be kept)
- `Orientation` → `PatternOrientation` (Godot global enum `Orientation`).
- `Pos`, `Dir`, `EntityId`, `Num` → `Vector2i`, `Vector2i`, `int`, `float` (see Types).
- `EvalContext.Self` → `self_` (`self` is a GDScript keyword). `IfNode.Then/Else` → `then_node`/`else_node`, `FuncNode.Func` → `fn` (keywords).
- Formula errors without exceptions: `Vocabulary.compile()` returns null and sets `vocab.last_error` (the C# message,
  e.g. "col 8: unknown stat 'Strr'") / `vocab.last_exception` (FormulaException); `Parser.parse()` → null + `Parser.last_error`.
  Evaluation-time InvalidOperationException (missing subject/variable/RNG) → `ctx.error` (first message), value 0.
  `Vocabulary.TryGetX(name, out v)` → `try_get_var/try_get_query/try_get_library(name)` returning the value or null.
- `ModifierPipeline.apply(base, mods, min, max, trace, name)`: `mods` is an Array of `[ModKind, amount]` pairs.
- Combat core: `GameState.Get(id)` → `get_entity(id)` (Object.get() cannot be overridden). `EntityKind.Object`/`Environment`
  → `EntityKind.Object_`/`Environment_` (Godot native class names; `NAMES`/`parse` keep "Object"/"Environment").
- `displayName` field + `DisplayName` property (EntityDef, StatusDef, PassiveDef, TerrainDef) → one property `display_name`:
  assigning sets the raw field `_display_name`, reading gives DisplayName (name when empty); `get_display_name()` alias too.
- `Entity.Grant(...)` overloads → one `grant(rule)` dispatching on ReactionDef / Modifier / ReplacementRule / PassiveDef.
  `GameState.IsFree(p)` / `IsFree(p, flying)` → `is_free(p, flying = null)` (null = the one-argument overload).
  `Pos?` → Vector2i or null (`Entity.position`, `free_tile_near`, `free_path_tile_near`). `Entity.state` is held through a WeakRef.
- `RuleSources.Reactions` tuples → Dictionaries `{def, effect_source, key, status}`; `GameState.ValueModifiers` → `[ModKind, amount]` pairs.
- `EventLog.BeginAction` (IDisposable) → `begin_action(kind, actor, detail)` returning a scope with `dispose()` (or `end_action()`),
  or `in_action(kind, actor, detail, callable)`; `BeatCompleted` event → `signal beat_completed(beat)`; `OfType` → `of_type`.
  Pos/Dir ToString → `Dirs.pos_str` "(x,y)" / `Dirs.dir_str` "<dx,dy>"; Manhattan/Chebyshev → `Dirs.manhattan/chebyshev`.
- Targeting slice: `PatternDef.Self()` → `PatternDef.self_()`; `Preference.Highest/Lowest` → `highest_of/lowest_of` (the field
  `highest` owns the name); `AimPreview.For` → `AimPreview.for_aim`; nested `AbilityText.DefStats` → global `DefStats`;
  `AbilityText.Tags` → `AbilityText.tags` (Array of `[value, name]`). Tuples → Arrays: `Targeting.radii` → `[min, max]`,
  `tiles` → `[[Vector2i, distance], …]`, `routes` → `[[Vector2i, route Array], …]`, `ray` → `[route, hit or null]`.
  `out string reason` (`Targeting.can_cast/is_valid_aim`, `Instinct.quick_cast`) → optional trailing `reason_out: Array`
  (`reason_out[0]` = String or null) and the static `Targeting.last_reason` / `Instinct.last_reason` ("" when it passed).
  `PhaseForecast.killed` is a Dictionary set; `RouteBuilder.path` returns a copy, `destination` is Vector2i or null.
  Inside a class, a global function wins over a same-named method (`range`): `AimPreview.range`/`AbilityText.range` delegate to `_range`.
- Level/Meta/Presentation slice: `out string reason` (`LevelSession.can_place/can_sell/can_cast`, `TowerCollection.can_add_to_hand`)
  → bool + `last_reason` field ("" when allowed) + optional trailing `reason_out: Array` like Targeting. Invalid commands
  (`place/sell/cast/end_round/start`, `TowerCollection.add_to_hand`, `LevelProgress.record`) → `push_error` and return null/false
  (`record` also sets `last_error`); the `LevelSession` constructor's ArgumentException (a tower ID twice) → `session.last_error`.
  `TowerIds.New()` → `TowerIds.new_id()` (`new` is the constructor). `ViewFrame.Get(id)` → `get_frame(id)` (Object.get).
  `FrameRecorder(LevelSession)` overload → `FrameRecorder.of_session(session)`; `FrameRecorder.new(state, log, session = null)`.
  C# events → signals: `Director.action_started/action_ended(info)`, `beat_started/beat_ended(beat)`, `SequenceRun.line_changed`.
  `IPresenter.Ready/Done` → properties `ready`/`done` whose getters call the overridable `is_ready()`/`is_done()`.
  `LevelCatalog` tuples → Dictionaries: `requirement()`/`chapter_requirement()` → `{levels, all}`, `visible()` → `[{entry, unlocked}]`.
  `LevelSession.SpawnEnemy(…, Pos? tile, …)` → `spawn_enemy(enemy, path_id, tile_or_null, wave, facing)`; `TowerIdOf` → String or null.
  `LevelDef.buildable` (HashSet) → Dictionary set; `LevelDef.terrain` → Dictionary Vector2i → TerrainDef; `paths` → Array of Arrays.
- Ability pipeline (Steps/Effects/Resolver): `Effect.Kind`/`Effect.Name` (C# virtual properties) → properties `kind`/`name`
  whose getters call the overridable `_kind()`/`_name()` (GDScript cannot override a property; the default `_name()` is the
  class name minus "Effect", like the C#). `StepContext.Self` → `self_`. `IfStep.else` → `else_` (`then` kept).
  `Chain.Var(name)` → `var_(name)`. `Resolver.EndTurn()` / `EndTurn(unit)` → `end_turn(unit = null)`. `Resolver.Run` while a
  command resolves and `BatchEffect.Apply` (C# throw InvalidOperationException) → `push_error` and return.
  `AbilityDef.displayName`/`DisplayName` → `display_name` (raw `_display_name`, reads name when empty) like StatusDef, plus
  `get_display_name()`. Effect/StepContext/AttackContext tag sets and `AttackContext.hit_units` are Dictionaries `{k: true}`.
  `Effect.set_add(set, k)` and `Effect.floor_int(v, round = Round.Floor)` are port helpers (HashSet.Add on a Dictionary-or-Array
  set; `Rounding.Apply(v, r).FloorToInt()`).
- Data layer (sim/data): assets are `ContentAsset` subclasses (port base standing in for ScriptableObject: `name`,
  `type_name()`). An asset's raw `id`/`displayName` fields keep the snake_case names; the C# computed `Id` / `DisplayName`
  properties → `get_id()` / `get_display_name()` (same snake_case name). Art references (sprites, prefabs, audio, fbx) are
  Unity path Strings ("" for none) instead of objects. `ContentLibrary.Get(key)` → `get_asset(key)` (Object.get);
  `Find<T>(name)` → `find("TypeName", name)`; `AllOf<T>()` → `all_of("TypeName")`; `Add(texts)` takes `[[file, text], …]`;
  unknown-type files also keep their parsed JSON in `skipped_json[file]` (PresentationTimings, UITheme).
  `AssetConverter.AssetOf<T>(def)` → `asset_of(def, "TypeName" = "")`; `Built<T>()` → `built("TypeName")`;
  `TryParse(text, out Num)` → `try_parse(text)` → float or null; `Tower(type, id, customName = null)` → `tower(type, id, custom_name = "")`.
  `AssetValidator.Validate(XAsset…)` overloads → `validate_asset(asset, vocab)` plus typed `validate_ability/_status/_reaction/
  _passive/_entity/_item/_rules/_tower/_level/_catalog`; `validate(assets, vocab)` keeps the list form; `Warnings` → `warnings`.
  `StepData.DisplayName` → property `display_name` (override `_display_name()`). `LevelAsset.Size` tuple → `size: Vector2i`;
  layer chars are 1-char Strings; `RoadAt` → `road_at` (String, or null for a bad char). `TileLook.TryParse(cell, out id, out turns)`
  → `try_parse(cell)` → `{ok, id, turns}`; `string[,]`/`TilePiece[,]` → `grid[x][y]`; `Frame` tuples → `[x, y, TilePiece]`;
  `TilePiece` struct equality → `equals()`. `GameCatalogAsset.Entries()` → `entries()` → `[[CatalogLevelData, chapter], …]`.
  `ContentCheck.Finding` → inner class `ContentCheck.Finding`; conversion exceptions → "converting it failed" when null.
  `LevelLaunch.HasRequest` → `has_request()`. `ContentFiles.Folder` → "res://data/content". The [Slot] table of every
  formula/condition field is `ContentSerializer.SCHEMA` (descriptor "formula:OnHit?") → `ContentSerializer.slot_of(type, field)`.
