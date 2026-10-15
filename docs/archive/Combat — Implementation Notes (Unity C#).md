# Combat — Implementation Notes

How the game simulation (`Assets/Scripts/Game/`) implements the design docs in `Docs/Design/`:
**Game Overview**, **Entity System**, **Ability Pipeline — Effect Queue Architecture**, **Formula System**
and **Condition System**. The design docs stay as written; this file lists what the code adds, where it
differs, and which open decisions it took. File map: `.agents/MAPPING.md`; architecture: `.agents/CONTEXT.md`.

**Run the tests:** Window → General → Test Runner → EditMode → Run All.

## Authoring

- **Create assets:** Assets → Create → Game → Ability / Status / Reaction / Passive / Entity / Item / Tower / Level / Game Rules.
  Keep one **Game Rules** asset in the project: its `stats` list is the vocabulary the drawers validate against
  (`MaxHp`, `Hp`, `HpPct`, `Shield`, `Initiative`, `Speed` and the resource stats are always there).
- **Entities:** kind (Unit, Object, Hazard), footing (enemies `OnPath`, towers `OffPath`), tags, base stats
  (text, so `0.05` stays exact), abilities and passives. Units need `MaxHp`; objects have HP only when `MaxHp` > 0.
- **Towers:** a Tower asset is a tower **type** (stable type ID such as `archer`, entity, energy cost). The player owns
  individual towers of a type, each with its own tower ID (a GUID), saved in `gamedata.json`
  (`GameData.towers`); edit them and the hand in Tools → Runtime → Persistent Data Viewer.
- **Levels:** the map as three text layers, rows top to bottom with y = 0 the **last** row (Tiles — Design): `terrain` (a
  character per terrain, named in `terrainKeys`), `build` (`+`) and `road` (box characters for the sides joined); paths as tiles in
  walking order (loops and gaps allowed), bases (an entity tagged `Base`),
  hand cap, start energy, energy per round, waves (start at a round or after another wave; spawns and
  LevelEvents in wave-relative rounds; one spawn entry per enemy).
- **Ids and what players see:** Ability, Status and Entity assets have an `id` (what rules and saves refer to:
  `HasStatus(Poison)`, Remove Status by name; empty falls back to the asset name), a `displayName`, a
  `description` and an `icon`; Tower assets have a `displayName` (empty = the entity's), `description` and `icon`.
  The HUD and tooltips show only these, never asset names. Validate All **warns** (never blocks play) when one is
  missing; abilities and towers need an icon, statuses get theirs with the art hooks (presentation phase 5).
- **Steps:** "+ Add step" picks a type; ⇄ changes it, ▲ ▼ reorder, ✕ removes.
- **Formulas and conditions** are text with live validation; chain order is checked by Validate All.
- **Tools → Combat → Validate All** checks every asset; **Create Example Assets** saves the examples
  (including Slime, Archer Tower, Base and Example Level) into the type folders under `Assets/Data`.

## Usage

```csharp
var convert = new AssetConverter();                                   // one per battle
List<TowerDef> hand = gameData.towers.BuildHand(typeId => convert.TowerType(towerAssetsById[typeId]));
var session = new LevelSession(convert.Level(levelAsset), convert.Rules(gameRulesAsset), hand, seed: 42);
session.Start();                                                      // round 1, player phase
Entity archer = session.Place(hand[0].id, new Pos(3, 3));             // by owned tower ID; costs energy
AbilityDef shoot = archer.Abilities[0];
Aim aim = Targeting.ValidAims(session.State, archer.Id, shoot).First();
if (session.CanCast(archer, shoot, out string why)) session.Cast(archer, shoot, aim);
session.EndRound();      // towers' TurnEnded → enemy phase → level phase → next round's player phase
// session.Outcome: Running / Won / Lost; session.Log: every event, for the presentation
```

## Game Overview: what is implemented

- **Rounds:** `LevelSession.EndRound()` ends the player phase (TurnEnded for every tower), runs the enemy phase
  (each enemy: TurnStarted, `EnemyBrain`, TurnEnded; order by Initiative then EntityId, fixed at the phase start),
  then the level phase, then `RoundEnded` and the next round's player phase (RoundStarted, TurnStarted for every tower).
- **Level phase order:** wave starts → this round's spawns and LevelEvents of every running wave → energy income →
  wave finishes → win check. A wave started by `AfterWave` starts in the level phase after the other wave finished.
- **Wave finished:** all its scheduled rounds have happened and no living entity has its `Wave`
  (spawns, LevelEvent spawns and their summons, which inherit the wave; starting enemies are in the first wave).
  Checked at the end of the level phase and after every command, so the kill that removes the last enemy
  finishes the wave at once (a wave started by `AfterWave` then starts in the coming level phase).
- **Lose:** any base not alive after any command. **Win:** every wave finished — at once, by the last kill, not at the next End round.
- **Towers:** placed on free, walkable tiles off every path for energy — only on build tiles when the level has
  any (`BattleGrid.CanBuild`, "Not a buildable tile"); walking is not limited to them; selling refunds
  `cost × Hp / (2 × MaxHp)` rounded down; a sold or dead tower returns to the hand (its corpse is removed) and
  costs full price again. A tower placed mid-phase gets its first TurnStarted next round.
- **No action or movement points.** Cooldowns (`AbilityDef.cooldown`) instead: casting sets it (player cast or
  reaction cast alike), it drops by one at the owner's TurnStarted, so cooldown 1 = once per round. Enemies'
  cooldowns drop at the start of the player phase, with the towers' (their own TurnStarted skips it), so the HUD
  shows during the player phase what each enemy can do in its coming turn; the timing of their casts is the same.
- **Movement:** `Speed` stat; patterns `Steps` (4-direction walk over tiles the mover may enter: around walls,
  chasms, paths and units; for towers) and `PathAhead` (forward along the mover's own path, stopping at a gap or
  at the unit ahead; for enemies). `ValidAims` gives movement aims a route (`Aim.Path`) for `WalkStep`.
  `JumpStep` resolves like Teleport (tagged `Jump`): skipped tiles see nothing.
- **Chosen routes:** a movement aim may carry any route the player picked (`RouteBuilder`, Fire Emblem style).
  `LevelSession.Cast` validates every aim with `Targeting.IsValidAim`: a Steps route must move one tile at a time
  through enterable tiles, never revisit one and fit the reach; PathAhead routes are fixed. No route = the shortest.
- **Tiles:** `BattleGrid` has walls (block movement, straight projectiles and line of sight), chasms (block
  movement) and paths. `GameState.CanStand/CanEnter` apply footing; spawning an OnPath entity on a taken tile
  uses the nearest free tile of its path (by index, the tile behind first on a tie).
- **Enemy AI (`EnemyBrain`):** tries abilities in their order; each takes the aim its instinct chooses.
- **Bases act like towers** (user decision): `Entity.CanAct` allows objects tagged Base; `LevelSession.PlayerUnits` (towers, then bases) take the towers' turn start / end; `CanCast` / `Cast` accept a base. The Entity System doc's "objects take no turns" has this exception.
- **Cooldowns:** `cooldownUntilReset` stores `Entity.HeldCooldown` (int.MaxValue; never ticks; CanCast says "On cooldown until reset"); `startCooldown` is applied in `GameState.Create` (-1 = held); `ResetCooldownStep` / `ResetCooldownEffect` and `AddCooldownStep` / `AddCooldownEffect` (all but the casting ability when none is named; held cooldowns stay held) write `CooldownChanged` (Detail = the ability, empty = all). A reset with a number shortens turn cooldowns only.
- **Instinct** (`Docs/Design/Instinct — Design.md`): `Instinct.Choose` / `Rank` over the
  valid aims: Must (a condition on the candidate's target), then the preset or the custom Prefer list, then the
  target's EntityId, then the candidates' own order. `AbilityDef.instinct` / `AbilityAsset.instinct` (drawer, converter,
  validator) and `AttackStep.bounceInstinct` / `AttackStepData.bounceInstinct`;
  Default = movement FarthestStep, an attack area larger than one tile MostHit, a target filter whose candidates
  are all allies MostHurt, any other filter Nearest, no filter FirstValid (the first aim as given). Differences
  from the doc: two status tags, `Redirected` (hard, in `ValidAims`, hand aiming too; the old Taunt) and `Taunted` (soft: after Must,
  the instinct keeps the aims hitting the applier when any do, else falls back; hand aiming is free); stealth
  (`IsTargetableBy`) plays the doc's Unseen; a Must on an aim without a target fails; MostHit and area
  preferences use the first area Attack step's targets (MostHit without an area filter counts the caster's enemies, then
  fewer allies hit, then the nearer tile; an aim worth nothing is no aim); Nearest on a bounce measures from the last target; the
  doc's `Hits(condition)` / `Sum(formula)` are a preference's `over` (AreaCount / AreaSum) + `filter`, not formula
  functions. Queries `PathProgress`, `DamagedThisRound` (`Entity.LastDamagedRound`). Example abilities keep
  Default. Quick cast: `Instinct.QuickCast` + `LevelController.QuickCast` (shift-click on a tower bar ability row; Shift over a row highlights the target and the hint names it). Pick step (`PickStep` / `PickEffect`: units in an area around the caster or the aim, chosen when it runs, its steps on each as Target; Default instinct Nearest to the centre) and `CastAbilityStep.aimByInstinct` (a reaction's cast aimed by the cast ability's instinct). Examples: Taunted, Provoke, Volley, Brute (created by Create Example Assets, which only adds missing files). Presets Ahead (`Entity.AheadOnPath`: the index of the chooser's path tile nearest the unit; ties the nearer) and Engage (movement only, validated: stands the mover on each reachable tile, collects what the follow-up attack — the next non-movement ability — could hit, ranks those units by the attack's instinct with distances from where it stands now, then takes the reachable tile furthest along that hits the best one; else the longest route). Engage is a positional check only: no damage is simulated, so it keeps the no-look-ahead decision.
- **Actions and beats** (for presentation, see the Animation & Presentation design): every event carries `Action`
  and `Beat`. `LevelSession` opens one action per cast, placement, sale, enemy turn, wave start/finish, spawn,
  LevelEvent, income, round end and phase change; the towers' turn starts and ends are one action each. A
  `Resolver.Run` outside any action is its own `Command` action. Each queue item is a beat, and each checkpoint
  (deaths, passive switches) is the next beat, so deaths play after the hits.
- **Level events** written to the same log: `PhaseStarted`, `WaveStarted`, `WaveFinished`, `EnergyChanged`,
  `LevelMessage`, `LevelWon`, `LevelLost` (no reactions respond to them).

- **Tower identity:** owned tower IDs are GUIDs (`TowerIds.New()`), created outside battles (never from the battle's
  seeded RNG); `TowerIds.Short()` gives the first 8 characters for display. A hand may not hold the same ID twice.

**Not built yet (Game Overview):** Flying / Walk over / Trample / distance-based movement and tile sharing
(open question), knockback rules per side, per-ability landing logic beyond what If steps can express,
bases sharing one health pool, hand and meta progress persistence, kills or waves paying energy, presentation.

## Differences from the system docs

- **Formula language:** `%` (floored modulo), `true` / `false`, typed variables (`Hit`, `IsCrit` are booleans).
- **Queries:** `DistanceTo(Subject)` (Manhattan) in addition to the doc's vocabulary; `TurnsTaken` (how many turns the unit has started, 1 in its first: "every second turn" is `Self.TurnsTaken % 2 == 0`).
- **ActionPower** is what the design docs call `Power`: the value an Attack step produces (its `power` formula after modifiers), read by Damage / Heal amounts (default `ActionPower`), mitigation and modifiers targeting it. Renamed because **Power** is now a unit stat.
- **Power and Potency stats:** core stats. A unit's numbers live on it and its abilities read them: hits `Self.Power` (Slam `Self.Power * 2`), heals `Self.Potency` (Mend). Statuses, passives and upgrades boost them like any stat. Players see an attack's ActionPower as **Damage**. `Str` is gone.
- **Starting units** (`LevelDef.startingUnits`, `LevelAsset.startingUnits`): units on the map when the level starts. **Ally**: the player's team, commanded like a base (`LevelSession.Allies`, `IsCommanded`), takes its turn with the towers, never in the hand or sold. **Neutral**: a third team (`Teams.Neutral`) that both sides count as an enemy, for obstacles such as rocks; it blocks its tile and never acts. **Enemy**: on a road (its own or the one through its tile), walking it; it belongs to the first wave, so the level is not won while it lives. Validate All checks the tile (inside, not a wall or chasm, not taken; enemies on their road); an ally or obstacle on a road is allowed (rocks on the road are a design tool: enemies stop there until it is gone).
- **Apply Status `duration`:** one optional formula for how long this application lasts (e.g. `2`, or `Self.Duration`, the caster's Duration stat). Empty uses the status's own duration; `-1` is permanent. (The old fixed `duration` number and the `turns` formula were merged into it.) The Drummer's Rally uses `Self.Duration`; Burn keeps its own 2 turns.
- **Range and Radius stats:** core stats besides `MaxHp`, `Speed`, `Initiative`. Abilities read them in their patterns (`Diamond(Self.Range)`, an area of `Self.Radius`; `Self.Range + 1` for a second, longer ability), so boosting the stat changes every ability that reads it. A unit has them only when its abilities use them, and the UI shows them only then (`AbilityText.OwnStat`).
- **Multi-hit and bounce** are `hits` / `bounces` fields on the Attack step.
- **Step targets:** each step has `on`: `Target`, `Self`, `EventSource`, `EventTarget`.
- **Environment rules** (Game Rules reactions) match their trigger for any entity, ignoring the side.
- **Names:** assemblies `Game.Formulas`, `Game.Combat`, `Game.Level`, `Game.Data`, `Game.Editor`, `Game.Tests`;
  `GameEventType` and `BattleGrid` avoid clashes with `UnityEngine.EventType` / `UnityEngine.Grid`. Stats are `MaxHp` / `Hp`.
- **Extra triggers:** `OnAnyTurnStart` / `OnAnyTurnEnd`, `OnRoundStart` / `OnRoundEnd`, `OnSpawned`, `OnResurrected`.
- **Extra steps:** Spawn, Resurrect, Remove, Face, Jump.
- **Shields** are statuses with a `shieldPool` formula, drained newest first.
- **Status tags:** `Debuff` / `Buff` (what cleanses and dispels target), `Hidden` (the UI skips it; rules don't),
  `Permanent` (removal by tag skips it; removal by name still works). An Apply Status step can add tags to one
  application (`addTags`), so the same Fire can be hidden or shown. When applications merge, tags are united,
  except Hidden, which stays only if both were hidden (a shown status never disappears).
- **Cleanse:** Remove Status `by Tag` removes matching statuses newest first, skipping Permanent; `limit` 0 = all.
- **Shield is one status, its stacks are its points:** a status whose `shieldPool` is `Stacks` gets one shield point per stack. Absorbed damage removes stacks, and `maxStacks` does not cap it. The amount comes from Apply Status's own `stacks` formula: Eat Rock gives 100, Shield Up 10, and the refill `10 - Self.Stacks(shield)` while `Self.Stacks(shield) < 10`. A shield pool formula may read `Stacks` (the stacks the application gives). Slime Shield and Stone Skin are gone.
- **Changing tiles (Tiles — Design, step 3):** formulas have no tile subject, so the design's `Tile.HasTag(X)` is not built. The Change Terrain step takes `onlyOn`, a list of terrain names, instead of a condition. Units read their own tile with `OnTerrain(name)` and `OnTerrainTag(tag)`. TileChanged carries the facts `X` and `Y`, and its `Detail` is `old>new` (terrain names). Falling sets the unit's HP to 0, so it dies at the next checkpoint like any other death: OnDeath and OnKill fire, and the source of the change is the killer. Objects without HP are removed instead. A push goes to the nearest tile the unit may enter (by steps, then a fixed order) and writes EntityMoved with the detail `Pushed`.
- **Removing some stacks:** Remove Status `by Name` has a `stacks` formula (OnHit; e.g. `1`, `Target.Stacks(Marked) - 1`); empty removes the whole status. Stacks come off the newest instance first; an instance left with none is removed. Every StatusRemoved event, partial or full, has the fact `Stacks` (what is left after it), so an OnStatusRemoved reaction can tell a partial loss from the end (`Stacks == 0`).
- **Stacking `PerSource`:** one instance per applier, stacking into its own; each ticks for its applier and expires
  on its own. `Entity.StatusSummaries()` groups instances for the UI: total stacks, longest duration, the instances.
  In a status's reactions, `StatusStacks` is that instance's stacks; use it for ticks (`Self.Stacks(X)` is the total).
- **Durations** are in turns (owner's TurnEnded) or rounds (RoundEnded), per status.
- **Control:** `Silenced` blocks Spell abilities, `Disarmed` blocks Attack abilities, `Rooted` blocks movement abilities.
  An ability with a target filter is single-target (stealth and taunt apply); larger areas hit stealthed entities.
- **Kill credit** is the Source of the effect that brought HP to 0 (`HpZeroBy`); hazards and the Environment never count.
- **Facing:** spawned entities start facing along their path where they appear (or the spawn entry's set direction:
  `SpawnFacing` on wave spawns and Spawn Enemies events); the starting direction applies even while `facingEnabled` is
  off. The Face step turns towards the aim, in a set direction (`Up` = +y = towards the first row of the map layers) or
  along the entity's own path; like every turn it needs `facingEnabled` in Game Rules. A "jump, then look down" ability
  is Jump + Face (Direction: Down).
- **Patterns:** shape `Single` is the centre tile only (single-target attacks; the caster's own tile as targeting).
  It has no radius, so MaxRadius modifiers never turn it into an area, unlike a radius-0 Diamond.
  Orientation `Facing` uses the caster's facing (when `facingEnabled`).
  Shape `Ray` is a straight shot at any angle from the caster to the aimed tile (Bresenham, like line of sight):
  a wall stops it (no hit); the first entity that blocks projectiles and that the caster can target takes the hit.
  `passesAllies` (default on) lets allies through; it also applies to Lines with `stopAtFirstBlocker`.
- **Attack kinds** are tags: `Melee`, `Projectile` (usually a Ray area), `Lobbed` (no line of sight, often a
  minimum range), `Beam` (straight to the target). Presentation picks animations by them; reactions and
  replacements can match them (`withTags`), e.g. reflect projectiles.
- **`OncePerTurn`** resets at the owner's own TurnStarted (the design's intent; an earlier version reset it on anyone's).
- **Presentation** (Animation & Presentation design, phases 1–5) is in `Scripts/Game/Presentation`, `Scripts/Gameplay`
  and `Scripts/UI/GameScene`. The art contract adds to the design: a state named `Die` (Skip and corpses jump to its
  last frame); clips are found by name (the clip whose name contains the trigger, for its length and Impact event);
  without an Impact event the impact comes at `fallbackImpact` (half the clip). A ranged attack's projectile leaves
  at the caster's Impact and the beat goes on when it arrives. Abilities without an Attack step (summons, buffs)
  play their caster animation at AbilityDeclared; movement abilities play none. An ability presentation's sounds
  replace the event defaults (cast for AbilityDeclared/AttackStarted, hit for its DamageDealt).
- **Pattern radii** are whole numbers (rounded down), except **Circle**, which keeps decimals: a tile is inside when its distance from the centre is at most radius + ½, so 1 is the 3×3 block, 2 is 5×5 without corners, and 1.5 lies between (the 3×3 block and the four tiles two steps away).
- **First-clear rewards:** a catalog level's `firstClearReward` gives one tower of that type on its first win
  (`GameCatalogAsset.GrantFirstClearReward`); the only way to gain towers besides the starting ones so far.
- **Not implemented:** previews and AI scoring, `failText`, passive self-feedback check, pattern preview grid.

## Open decisions (doc defaults used)

- Reactions an entity collected in the batch that killed it are dropped (`worksWhenDead` overrides);
  `OnDeath` reactions still run, and a dead owner may still attack (an exploding barrel).
- A status's own reactions see its `StatusRemoved` (the event is written before it is removed).
- Spawning on a taken tile: OnPath entities use the nearest free tile of their path; others the nearest free
  tile within 1 (orthogonal first), or the spawn fizzles. Spawning writes no `EntityEnteredTile`.
  Units spawned mid-round act from the next round.
- Ticks deal damage at the owner's turn start; durations count down at its turn end (or the round's end).
- Third-party reaction order is by EntityId. Enemy turn order: Initiative, then EntityId (spawn order).
- Previews treat uncertain rolls as passing.
