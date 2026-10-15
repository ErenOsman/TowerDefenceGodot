# Glossary

The game's terms, one or two lines each. Code names are in `code`; the design doc that covers a term in depth is linked. Design docs are in [`design/`](design/). Godot pass 2026-10-15: code names are the Godot build's (GDScript, per docs/Sim Port.md).

## Playing a level

| Term | Meaning |
| --- | --- |
| **Level** | One battle on a grid map: roads, bases, waves. A `LevelAsset`; listed in the game catalog |
| **Round** | One cycle of the three phases: player, enemy, level. Round-based durations tick at its end |
| **Player phase** | All your towers and bases act freely, in any order, until you End round. Counts as every tower's turn |
| **Enemy phase** | Enemies act one at a time, in Initiative order fixed when the phase starts |
| **Level phase** | Spawns, LevelEvents, energy income, wave changes |
| **Turn** | A unit's own turn: TurnStarted, its actions, TurnEnded. Turn-based durations and cooldowns count these |
| **Energy** | What placing a tower costs. A level starts with some and gains more each round |
| **Hand** | The towers you bring, up to 8, in order. A level lets in the first *hand cap* of them (Chapter 1: 4); the rest stay on the bench |
| **Base** | What you defend (an entity tagged `Base`). The level is lost when any base reaches 0 HP. Bases act like towers |
| **Road / path** | A **path** is the tiles an enemy walks, in order (`PathDef`; an enemy follows `Entity.path_id` and keeps its place as `path_step`). It may cross itself and have gaps, and need not end at a base: an enemy at its end stays and keeps acting. The **road** is what is drawn on the map (the level's road layer); every path step runs along it |
| **Terrain** | What a tile's ground is (Tiles — Design): Ground, Wall, Chasm or another Terrain entry. It says who may stand there (everyone, flyers, nobody) and whether it stops shots and sight. It can change during a battle (Change Terrain); a unit that can no longer stand there falls, or is pushed out of a new wall |
| **Build tile** | A tile where towers may be placed (`+` in the build layer). When a level has any, towers can be placed only there. Looks like ground; placing highlights them |
| **Wave** | A named group of spawns and LevelEvents, starting at a round or after another wave is cleared. The level is won when every wave is cleared, at once when the last enemy falls |
| **LevelEvent** | A scripted wave action: spawn enemies, give energy, show a message, change terrain |
| **Starting unit** | A unit on the map when a level starts: an **ally** you command (a helping tower), a **neutral** obstacle both sides can break (a rock), or an **enemy** already on a road (part of the first wave) |
| **First-clear reward** | A tower type a catalog level gives once, on its first win |
| **Catalog** | `GameCatalogAsset` (`data/content/Catalog.json`): chapters, their levels in order, unlock requirements, rewards, tower types, starting towers |

## Units

| Term | Meaning |
| --- | --- |
| **Entity** | Anything on the board: a unit, an object (a base, a wall-like thing) or a hazard. Defined by an `EntityAsset` → `EntityDef`; alive as an `Entity` |
| **Tower** | A player unit you place. A **tower type** (`TowerAsset`: entity, cost, type ID) vs an **owned tower** (`OwnedTower`, its own GUID in the save); the hand lists owned towers |
| **Enemy** | A unit that spawns on a road and walks it toward a base |
| **Footing** | Where an entity may stand: `OnPath` (enemies, roads only), `OffPath` (towers, never on roads), `Any` |
| **Stats** | Numbers on an entity: `MaxHp`, `Speed` (tiles per move), `Power` (what its hits deal), `Potency` (what its heals give; later statuses, shields, buffs), `Duration` (how long the statuses it applies last, when its ability reads it), `Range` (how far its abilities reach), `Radius` (how wide its area attacks are), `Initiative` (enemy turn order), and any others content uses; these show only on units that use them. Formulas read them; modifiers change them |
| **Tag** | A label rules can test: `Base`, `Boss`, `Movement`, `Attack`, `Melee`, `Projectile`, `Lobbed`, `Beam`, `Spell`, `Buff`, `Debuff`, `Taunted`, `Redirected`, `Stealthed`… |

## Abilities and rules

| Term | Meaning |
| --- | --- |
| **Ability** | Everything a unit does, walking included. Targeting + filter + a list of steps + cooldown + instinct. `AbilityAsset` → `AbilityDef` ([Ability Pipeline](design/Ability%20Pipeline%20—%20Effect%20Queue%20Architecture.md)) |
| **Aim** | Where an ability is cast: a tile (with a direction, and a route for movement). Valid aims come from `Targeting.valid_aims` |
| **Targeting pattern** | The shape of what an ability can reach (Diamond, Square, Line, Cone, Ray, Steps, PathAhead…) with min and max radius formulas |
| **Area** | The tiles an attack hits around its aim; may differ from the targeting pattern |
| **Step** | One instruction in an ability (Attack, Damage, Heal, Apply Status, Walk, Pick, Reset Cooldown…). Steps queue effects |
| **Effect** | One change to the game state (damage, move, apply status). Every change is an effect in the Resolver's queue |
| **Resolver** | Runs the effect queue: effects in batches, then a **checkpoint** where reactions fire |
| **Reaction** | A rule that runs when an event happens (on hit, on turn start…), e.g. Counter-attack, shield refill |
| **Replacement** | A rule that changes an effect before it applies (e.g. a shield absorbing damage) |
| **Passive** | An always-on bundle of modifiers, reactions and replacements on a unit, optionally conditional. `hidden` ones are mechanics players never see |
| **Status** | A temporary bundle on a unit (Poison, Taunted, Shield): stacks, a duration in turns or rounds, optional shield pool and icon ([Entity System](design/Entity%20System%20—%20Design.md)) |
| **Shield** | Damage absorbed before HP. The Shield status is the shield: one point per stack, and absorbed damage removes stacks (a status whose shield pool is `Stacks`). `Self.Shield` is a unit's total |
| **Modifier** | A change to a stat or a number in the pipeline (add, multiply, override) |
| **ActionPower / Damage** | The value an attack produces (`ActionPower` in formulas; **Damage** to players), usually the unit's Power: Shoot hits for `Self.Power` |
| **Formula** | A number written as text: `Self.Power * 2`, `if(Target.HasTag(Boss), 15, 5)` ([Formula System](design/Formula%20System%20—%20Design.md)) |
| **Condition** | A yes/no written as text: `Target.IsEnemy and Target.Hp < Target.MaxHp` ([Condition System](design/Condition%20System%20—%20Design.md)) |
| **Vocabulary** | The names formulas can use (`Self`, `Target`, stats, queries). `CombatVocabulary` |
| **Cooldown** | Turns before an ability can be used again; 1 = every turn. Can start running, or wait for a Reset Cooldown step |

## Instinct (automatic aiming)

| Term | Meaning |
| --- | --- |
| **Instinct** | How an ability picks its aim when nobody clicks: enemy turns, quick cast, Pick steps, bounces ([Instinct](design/Instinct%20—%20Design.md)) |
| **Must** | An instinct's filter: aims that fail it are dropped |
| **Prefer** | An instinct's ordered preferences (highest / lowest of a formula, area count, area sum) |
| **Preset** | A named instinct: Nearest, Farthest, First, Last, Weakest, Strongest, Most hurt, Most hit, Random, Farthest step, Ahead, Engage |
| **Quick cast** | Shift-click an ability (or hold Shift + its number and let go): cast at once where its instinct says |
| **Taunted / Redirected** | Soft / hard pull toward the status's applier. See the Instinct doc |

## Presentation

| Term | Meaning |
| --- | --- |
| **Event log** | Everything that happened, as events, in order. Commands resolve instantly and only write the log ([Animation & Presentation](design/Animation%20&%20Presentation%20—%20Design.md)) |
| **Action / beat / event** | The log's grouping: an action is what Skip finishes (one cast, one enemy's turn); a beat is one queue item, played in order; events in a beat play together |
| **Director** | Plays the log back through presenters; busy while playing |
| **Presenter** | Draws one event (a lunge, a projectile, a flash, a banner) and says when the next beat may start |
| **View frame** | A snapshot of what the player should see after a beat; the UI reads `Director.shown`, never the live state |
| **Impact** | The moment a hit lands (an Animation Event on real models); the next beat may start there |

## Menus and progress

| Term | Meaning |
| --- | --- |
| **Codex** | The in-game reference book: towers, enemies, statuses and tips, opened from the main menu and the pause menu ([Codex — Design](design/Codex%20—%20Design.md)) |
| **Discovered** | A Codex entry the player has met: a tower owned, an enemy or status seen in a level. Others show as **???**; a newly discovered one has a dot until opened |
| **Tip** | A short how-to page in the Codex; its text names keys as the player bound them |
| **Key binding** | A key (with none, Shift, Ctrl, Alt or Ctrl+Shift) given to an action in Settings > Controls; two per action |
| **Profile** | The player's name, the tutorial's state and the intros seen, in the save |

## Code and data

| Term | Meaning |
| --- | --- |
| **Asset vs Def** | Assets are the content entries designers edit (`data/content/*.json`, loaded as `ContentAsset` subclasses in `sim/data/`); the `AssetConverter` turns them into plain defs the engine-free simulation runs |
| **Simulation** | `sim/formulas`, `sim/combat`, `sim/level`, `sim/meta` (and `sim/presentation`, `sim/data`): no engine calls, deterministic (seeded `GameState.rng`) |
| **LevelSession** | One running level: commands (Place, Sell, Cast, End round), phases, waves, win and loss |
| **LevelController** | The scene object that owns the session, the Director, the board and the camera, and handles input |
| **Game reference** | The generated content pages in [`reference/`](reference/) (`tools/game_reference.gd`) |
| **Content number** | A hidden number every content asset has (1, 2, 3… per asset type), given when the entry is made and never reused; players never see it. Rules and saves use the string **id** |
