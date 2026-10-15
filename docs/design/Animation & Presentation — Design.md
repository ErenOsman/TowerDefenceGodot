# Animation & Presentation — Design

Written 2026-10-02 as a claude.ai doc; moved into the repo on 2026-10-05. This file is now the source of truth. Godot pass 2026-10-15: code names are the Godot build's. All five build phases are built (in the Godot build too); [Since the doc was written](#since-the-doc-was-written) lists what changed afterwards.

The simulation resolves every command instantly and writes an event log; a Director plays that log back as animation afterwards. Logic never waits for animation, and animation never changes logic.

## Decisions

Five choices, made on 2026-10-02, shape everything below.

| Topic | Decision | Consequence |
| --- | --- | --- |
| Input during playback | Commands wait until the Director is idle | No command can arrive mid-animation, so the view never shows a state the player can act on before it is drawn (selecting and cancelling still work, see below) |
| Speed | Game speed (a multiplier), Instant, and a Skip button that finishes the current action | Every presenter's duration scales by one number; Instant and Skip reuse the same "finish now" path |
| Enemy phase | Sequential: one enemy's turn plays fully before the next | Always matches the log's order; safe overlap can be added later without other changes |
| Camera | Player-controlled; a "follow the action" setting | The Director never moves the camera unless that setting is on |
| Visuals | Placeholders first (shapes, tweens, flashes, numbers) | The whole pipeline works before any model or animation exists; real art plugs into the same presenters |

## Architecture

```text
Command ──▶ LevelSession / Resolver ──▶ event log (+ view frames)        ← runs the game
                                              │
                                              ▼
                                         Director  ── groups events into actions and beats
                                              │
                          ┌───────────────────┼───────────────────┐
                          ▼                   ▼                   ▼
                     presenters          view model           camera / sounds   ← drawing only
                (tweens, models, VFX)   (Director.shown)
                          │                   │
                          ▼                   ▼
                     entity views          HUD / UI
```

Only the top row runs the game; everything below the Director is drawing, and none of it can change a rule.

## Actions, beats and events

The log is grouped in three levels, and every event records the action and the beat it belongs to. The simulation stamps them; the Director only reads them.

| Level | What it is | Examples | Marked by |
| --- | --- | --- | --- |
| Action | One thing a player sees as a unit; Skip finishes one action | a tower cast, placing or selling a tower, one enemy's whole turn, a phase change, a wave spawn | `LevelSession`, which opens an action around each of these |
| Beat | The events of one queue item; beats of an action play in order | the projectile and explosion, then the three hits together, then Thorns | `Resolver`, one beat per queue item (`run` + item index) |
| Event | One fact; events of a beat play in parallel | `DamageDealt`, `EntityMoved`, `StatusApplied` | the effect that writes it |

- **Events carry two fields:** `action` (an id, with the action's kind and actor) and `beat` (the queue item). Nothing else in the log changes, so tests and replays keep working.
- **One End round = many actions:** the towers' turn ends (one grouped action), each enemy's turn, then the level phase (spawns, events, income, wave changes), then the towers' turn starts (one grouped action). Skip during the enemy phase therefore finishes one enemy, not the whole phase.
- **Events the player never sees** (`Fizzled`, `Prevented`, `PassiveActivated`…) take no time unless a presenter is assigned to them.

## Director

The Director turns new log events into actions and plays them one at a time; commands are accepted only while it is idle.

1. A command runs to completion in `LevelSession` (instant).
2. The Director takes every event written since its cursor, grouped into actions and beats, and becomes busy; the UI disables commands.
3. For each action, each beat: start a presenter for every event in the beat, show that beat's view frame, and wait until all of them report ready.
4. When the last action ends, the Director is idle and commands return.

- **Presenters** implement three calls (`IPresenter`, `sim/presentation/i_presenter.gd`): `begin()`, `tick(dt)` after which they report whether they are done, and `finish()`, which snaps to the end state at once and may be called at any moment. Skip and Instant rely only on `finish()`, so no presenter needs special skip logic.
- **Game speed** uses `Engine.time_scale`, which `SettingsMgr` applies from `gameSpeed`. AnimationPlayers, particles and tweens on scaled time speed up for free; UI that must not speed up uses unscaled time. Pause sets the scale to 0, which freezes playback too.
- **Skip** calls `finish()` on everything in the current action and syncs its last view frame; the next action plays normally.
- **Instant** (a setting) finishes every action as soon as it starts, so a command's result appears in one frame.
- **The Director core is engine-free:** a state machine driven by `tick(dt)` (`Director`, `sim/presentation/director.gd`), with presenters behind an interface. Tests (`tests/test_director.gd`) drive it with fake presenters and a fake clock: beat order, parallel events, Skip, Instant, the busy flag.

## Enemy phase pacing

Enemy turns play strictly one after another, because few enemies are on screen and sequential playback can never show events out of order.

- **Why not overlap now:** the simulation is always right, but overlapping playback can be visibly wrong. If enemy A's walk triggers Overwatch and A dies, B's overlapping walk would pass an A that is about to die, or step into a tile A only frees later.
- **Pace comes from speed instead:** game speed, Instant and Skip (one enemy per press).
- **Safe overlap, if ever needed:** an action may start before the previous one ends only when (1) it involves no entity the running action involves, (2) it touches no tile the running action touches, and (3) none of its events was caused by an event of the running action. All three are read from the log, so the rule is exact, not a guess. It plugs into the Director's "start next action" check and changes nothing else.

## View model

The UI and entity views read a view model, never `GameState`, so an HP bar drops when the fireball lands, not when the player clicks.

- **View frames:** when a recorder is attached, the simulation captures a small frame after every queue item: per entity its life state, position, facing, HP, max HP, shield, visible status summaries (total stacks, longest duration, shield left), passives and cooldowns; for the level its round, phase, energy and wave states. Tests run without a recorder and pay nothing.
- **Frames, not deltas:** the view model switches to a beat's frame when the beat starts, and the UI animates from the previous frame's values to it, so the HP bar slides while the hit flashes. Presenters never re-apply rules, so an aura changing max HP or a shield absorbing damage cannot drift from the truth.
- **Size:** tens of entities and at most a few hundred queue items per round, so frames cost little; they are dropped once played.
- **The UI binds to the view model** (`TdHealthBar`, `TdEntityStatus`, energy and round counters) and updates when the Director syncs a frame or a presenter animates a value.

## Presenters

Every event type has a default presenter, so any ability plays without authoring. Durations are at 1× speed; banner and floating-text times come from Presentation Timings (`data/content/PresentationTimings.json`, read by `PresentationTimings`).

| Event | Default presentation (placeholder) | Duration |
| --- | --- | --- |
| `RoundStarted`, `PhaseStarted` | Banner "Round 3", "Enemy phase" | 0.8 s |
| `WaveStarted`, `WaveFinished`, `LevelMessage` | Banner with the text | 1.2 s |
| `AbilityDeclared` | Ability name floats above the caster | 0.25 s |
| `AttackStarted` + `Melee` | Caster lunges toward the target and back; impact at the lunge's peak | 0.3 s |
| `AttackStarted` + `Projectile` | Sphere flies to the target | 0.12 s per tile |
| `AttackStarted` + `Lobbed` | Sphere on an arc to the aimed tile | 0.5 s |
| `AttackStarted` + `Beam` or no kind tag | Column of light drops on the aimed tile | 0.3 s |
| `HitResolved` (miss) | "Miss" floats over the target | 0.4 s |
| `DamageDealt` | Target flashes red and shakes; damage number floats up; HP bar slides | 0.25 s |
| `Healed` | Green flash, green number | 0.25 s |
| `StatusApplied`, `StatusRemoved` | Icon pops in or out of the status bar (Hidden skipped) | 0.2 s |
| `EntityMoved` Walk / Push | Slide one tile | 0.18 s per tile |
| `EntityMoved` Jump / Teleport | Arc / fade out and in | 0.35 s |
| `Collision` | Thud: short shake on both | 0.15 s |
| `EntitySpawned`, `EntityResurrected` | Scale-in pop | 0.3 s |
| `EntityDied` | Shrink and fade (corpse hidden by default) | 0.4 s |
| `EntityRemoved` | Fade out | 0.2 s |
| `FacingChanged`, `TeamChanged` | Turn / colour swap | 0.1 s |
| `EnergyChanged` | Energy counter ticks | 0.2 s |
| `LevelWon`, `LevelLost` | End screen | until dismissed |

Events inside one beat run together, so an area attack's three `DamageDealt` flashes play at once, and its HP bars slide together.

## Ability presentation and sync points

Damage numbers appear on the impact, not before: a presenter can say "the beat may go on" before its own animation ends.

- **Beats already order cause and effect.** `AttackStarted` (the swing, the projectile) is one beat and the hits are the next, so hits never play before the attack. The only question is when the next beat may start.
- **Impact signal:** a presenter reports *ready* at its impact moment and keeps playing its tail (the sword's follow-through, the caster stepping back) while the next beat runs. Placeholders mark impact at a fixed fraction (a lunge's peak, a projectile's arrival); real models mark it with an impact key on the attack clip (a method track calling `Impact`, else the clip's time in `art/models/impacts.json`, which the Blender kit writes; `EntityRig`).
- **Ability presentation (optional):** an ability entry's `presentation` key (an entry of `Presentations.json`, `AbilityPresentationAsset`) overrides the defaults — caster animation (Attack, Cast or a custom trigger), projectile model and speed, cast, impact and hit VFX, sounds, camera shake. Without one, the attack-kind tag picks the default.
- **Finding it:** events carry their `AbilityInstance`, whose `AbilityDef` maps back to its asset through `AssetConverter.asset_of`.
- **Statuses:** a status entry's `icon` for the status bar and an optional `loopVfx` while applied (the VFX kit, `game/level/vfx/`).

## Entity views

Every entity on the board gets one view object, created when its spawn plays; presenters talk to it through one interface, so placeholders and real models are interchangeable.

- **What a view does:** move to a tile, play a clip (Attack, Cast, Hit, Die, Spawn) with an impact callback, flash a colour, show a floating text, show HP and statuses. A placeholder and a model both support it.
- **Which view:** the `view` on the unit's entry (`Units.json`; its path maps to `res://art/models/<Unit>.fbx` through `ArtPaths`). Empty or missing → a generated placeholder: capsule for units, cube for objects, flat disc for hazards; team colour; name label; HP bar above.
- **Clip contract for real models:** the FBX's AnimationPlayer has clips `<Name>|Idle`, `|Walk` (played while moving), `|Attack`, `|Cast`, `|Hit`, `|Die` (its last frame is the corpse), `|Spawn`, and an impact time on attack and cast clips (Style & Art Direction — Design § 5). `EntityRig` (`game/board/entity_rig.gd`) maps the view onto that AnimationPlayer, so artists only follow the clip names; missing clips fall back to tweens.
- **Grid to world:** tile (x, y) sits at world (x, 0, −y), one unit per tile (`GridSpace`; the board's north, the level text's top row, is −Z); the ground, road, wall and chasm tiles are map-kit meshes (`art/tiles/`) that `BoardView` builds from the level's map (Tiles — Design).
- **Dead entities** may keep a corpse on their tile (off by default, `LevelController.show_corpses`), since abilities can target it; `EntityRemoved` deletes the view.

## Camera

The player controls the camera; the Director moves it only when the "Follow the action" setting is on.

- **Controls:** pan (left-drag on the board — a press that moves past a few pixels drags instead of clicking, setting Drag with Mouse, on by default — middle-drag, WASD / arrows, edge scroll), zoom (wheel, clamped), rotate in 90° steps (Q/E), so the grid stays readable. Pan is clamped to the map's bounds.
- **Follow the action (setting, default off):** at the start of each action the camera glides to centre the entities it involves. Only actions that happen somewhere are followed (a cast, an enemy's turn, a spawn, a level event, placing or selling); board-wide ones (every tower's turn start or end, phase banners, income, round end) are not, since their middle is everyone's and pulled the camera back after the enemy phase (user, 2026-10-11).
- **Setting:** `SettingsData.follow_action` (saved as `followAction`), a toggle in the Gameplay page of the Settings screen (`game/ui/screens/settings.gd`).

## Where the code lives

The timing logic is engine-free and tested; only drawing and input live in Godot nodes.

| Folder | Contents |
| --- | --- |
| `sim/combat/`, `sim/level/` (engine-free) | Action and beat stamps on events; the view-frame recorder hook |
| `sim/presentation/` (engine-free) | `Director`, the presenter interface `IPresenter`, action/beat grouping, view frames (`ViewFrame`, `FrameRecorder`) |
| `sim/data/` | `view` on `EntityAsset`, the ability presentation asset, `AssetConverter.asset_of` |
| `game/level/` | `LevelController` (runs the session, ticks the Director, handles input), presenters (`presenters/`), the VFX kit (`vfx/`), `PresentationTimings`, `GameSounds` |
| `game/board/` | Board view, entity views (placeholder and model, `EntityRig`), overlay (plates, floating text, banners), camera |
| `game/ui/hud/` | HUD panels: top bar, hand, inspector and action bar with range previews, info popups, end screen |
| `tests/` | `test_director.gd` (grouping, beats, Skip, Instant with fake presenters) |

The game layer reads the `ViewFrame` and calls `LevelController` commands; `sim/` never references `game/` (game/ARCH.md).

## Settled after review

The five open questions were answered on 2026-10-02.

| Question | Decision |
| --- | --- |
| Names, descriptions and icons | Real fields, never the asset name: a stable `id`, `displayName`, `description` and `icon` on Ability, Status, Tower and Entity assets; the HUD and tooltips read them, and Validate All flags missing ones |
| Round start with many towers | One grouped action, "towers' turns start"; Skip finishes all of them at once |
| Floating numbers | Screen-space UI that follows its entity, so it reads the same from any camera angle |
| Sound | Presenters play sounds through `AudioMgr` (`GameSounds`): per-event defaults plus the ability presentation's own clips |
| After the end screen | Retry, Level select and Next level |

## Since the doc was written

- **Input during playback:** clicks still select units (from what is drawn) and right-click still cancels while an action plays; only commands wait for the Director.
- **Banners don't block:** play goes on under them; several queue, and a newer banner of the same kind (a round, a phase) replaces an older one.
- **Presentation Timings:** banner, floating-text, ability-name and health-bar durations are data (`data/content/PresentationTimings.json`).
- **Health bars:** a unit's plate shows its HP bar while it is hovered or selected, for a moment after it loses HP or shield, and while dying; the Always Show Health setting shows them all. Plates scale with the camera zoom.
- **Corpses** are hidden by default.
- **Follow the action** centres every action, also when it is already in view.
- **Face Target On Cast** (an ability entry's `faceTargetOnCast`) turns the caster toward the aimed tile as it casts.
