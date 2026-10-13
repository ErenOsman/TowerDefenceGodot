# Decision log

Why the game is the way it is: one line per decision, newest first within each area. Add a line whenever a decision changes the game, its rules, its content or how the project is run. Design docs hold the big designs and their own decision tables; this log holds everything else, including balance changes and reversals.

Format: date · decision · reason. The commit that made the change is in brackets where there is one.

## Rules

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-10-10 | Planned, not built: Shield stops being a status. Shield (and a later super shield) become pools on the unit next to HP, like health layers, instead of a status with a damage pool (`StatusDef.shieldPool`) | Eren (first said 2026-10-03, repeated now). Until then Shield stays a status |
| 2026-10-09 | Abilities set the durations of the statuses they apply: every Apply Status step has its own `duration` (a number or formula such as `Self.Duration`); the status's own duration is only the fallback for a step left empty. Settled: don't ask again | Eren (asked twice; "yes of course"). The 12 empty steps got their status's current duration, so nothing plays differently |
| 2026-10-05 | The level is won the moment the last enemy falls (when every wave's schedule is done), not at the next End round; a wave is cleared the same way | Waiting for End round after the last kill felt like a bug |
| 2026-10-05 | Levels can start with units on the map: allies the player commands like a base, neutral obstacles (a third team both sides may attack), enemies already on a road (counted in the first wave) | Helping towers, rocks to break and enemies already advancing make levels differ without new code; the map tiles stay what rules read, the art model only shows them |
| 2026-10-05 | Units carry Power (hits) and Potency (heals, later statuses and shields); abilities read them (Shoot = `Self.Power`, Mend = `Self.Potency`); the attack's value is ActionPower in formulas and Damage to players; Str removed | A stronger unit hits harder with the same ability; magic and physical towers share Power, so a mage never scales with strength; one name per idea |
| 2026-10-05 | Range and Radius are unit stats; abilities read `Self.Range` / `Self.Radius` (a second ability may use `Self.Range + 1`: Taunt, Mend); numbers unchanged | Statuses, passives and upgrades can boost reach and area like any stat, and the UI shows them |
| 2026-10-04 | Enemy cooldowns count down at the start of the player's turn, with the towers', not at the enemy's own turn start (057c1c1) | During the player phase you can see what each enemy will be able to do in its coming turn. Cast timing is unchanged |
| 2026-10-04 | Cooldown 1 = usable every turn; cooldowns are at least 1 (9e22a90) | Cooldown 0 allowed several casts a turn, which nothing in the design wants |
| 2026-10-04 | When a level has build tiles, towers can be placed only there (5aeb271) | Placement becomes a decision about defending the base, not "next to the road anywhere" |
| 2026-10-03 | Bases are player units: selected and cast like towers, take their turn with them (d248ca8) | Bases can carry abilities and passives |
| 2026-10-03 | Cooldowns can start running (`startCooldown`, -1 locked) or be held until a Reset Cooldown step (`cooldownUntilReset`) (d248ca8) | "Ready again on a kill" and "not usable on turn 1" abilities, as data |
| 2026-10-03 | `Taunted` is soft and per ability: the aims hitting any taunter form the pool the ability's instinct picks from; the old hard taunt is `Redirected` (03ae835, 61a245a) | A taunted unit still plays like itself and can't be stuck doing nothing; hard redirection stays available |
| 2026-10-03 | Most hit counts only enemies (or units passing the filter) and gives no aim when nothing worth hitting is in reach (a10be49) | An area ability fired at its own allies, or at nothing, reads as a bug |
| 2026-10-03 | Instinct is set per ability, never per entity; tower single-target default is Nearest, like enemies | One unit can carry abilities with different instincts. See the Instinct design doc |
| 2026-10-03 | No preview of what enemies will hit (no Into the Breach intents) | Abilities can get too complex to preview honestly |

## Chapter 1 content and balance

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-10-05 | Chapter 1 level 4 rewards the Wisp (a tower that teleports) instead of a second Archer; Chapter 2 follows with one new idea per level (rocks and hoppers, enemies already on the road, an ally drum and flyers over a chasm, a boss that eats its own side) | Each level teaches one thing; the Wisp gives the player a new way to move before Chapter 2's crowded maps |
| 2026-10-04 | Build area: the 5×5 square around the base, off the roads (f32c2b7, 8f94266) | Base neighbours only (3–4 tiles) lost every level and left Two Roads with fewer tiles than a hand. Writing it as a fixed square instead of a radius setting was the user's call |
| 2026-10-04 | Shield Slime HP 10 → 20 (c9af744) | It died to the first shots; the user wants it to soak more. Bots then lost Two Roads and The Slime King, but the user tests the levels and decides |
| 2026-10-04 | Spitters: Big Slimes replace plain slimes; Runner and Slime Archer HP → 15 (8a54a65) | Archers one-shot everything, which is not fun |
| 2026-10-04 | Bash cooldown 1; Two Roads' last wave has a Shield Slime instead of a plain slime (c5e15cc) | Balance |
| 2026-10-04 | Archer Shoot hits the chosen enemy (single target) instead of the first unit along a line (5766902) | The straight shot often hit the wrong enemy |
| 2026-10-03 | Counter-attack belongs to the Guardian, not the Archer; First Steps uses Big Slimes instead of Runners, 7 enemies instead of 14 (23b5aa7) | Fits the Guardian's role; level 1 was too long |
| 2026-10-03 | Energy: every level starts at 200; +20 a round on levels 1–2, +25 on levels 3–4 (b4c16a5) | The user's numbers |
| 2026-10-03 | Slam hits towers only; Crush decides the base and goes for it unless taunted; Two Roads has 3 Shield Slimes, not 5 (5cf2469) | The boss shouldn't erase the base in one turn; taunting the boss has to matter |
| 2026-10-03 | Priest Smite: 5, or 15 against a `Boss`; using it delays the Priest's other abilities by a turn (61a245a) | A boss answer with a cost |
| 2026-10-03 | Each Chapter 1 level has 3 waves with at most one enemy per wave round; each first clear gives a tower: Guardian, Mage, Priest, Archer (d1ba65b) | Readable waves; the hand grows as the chapter goes on |
| 2026-10-03 | Archer costs 100 (2ed9210) | Round numbers for energy |

## Presentation and UI

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-10-13 | Hand select has FOUR fixed layout tabs (Layout 1 holds the hand, 2–4 start empty, rename only; the active layout is the one levels use); saved as `handLayouts` {active, layouts[{name, hand}]} next to the hand (Godot build first; the Unity GameData lacks the field) | Eren ("4 layout olsun"); UI doc 30e8a78 (Hand select section) |
| 2026-10-13 | Level select, hand select and chapter select follow the UI/UX agent's screens-b mockups (level-select.html, hand-select.html) in the Godot build: numbered rows with Won/New/lock states, fact tiles, enemy chips, rendered board preview, first-win reward line, 8-slot hand strip with the cap divider; chapter cards with thumbnail, level dots, reward and green-when-complete progress | Eren asked for "the new level select"; built 961bf86 |
| 2026-10-13 | The action bar is centred on the screen (~62 px above the bottom), never left-aligned next to the hand tray; a wide tray pushes it right by just enough (24 px clearance), else it rises a row, still centred | Eren, testing the Godot build. In the UI Design Rules doc (4dca561) |
| 2026-10-13 | The aiming ability button: gold rim, lifted 5 px, slow gold glow pulse, gold key badge; the unit's other abilities dim to 60 %; the bar label reads "Shoot: pick a target"; right click, Esc or the same key cancels | Eren: it was not clear which ability was selected. In the doc (8685694) |
| 2026-10-13 | No "Next: …" forecast line on the enemy's inspector card nor in its Info window; the enemy's coming turn is previewed on the board when hovered | Eren ("yazmasın"). UI doc 334ad65, NEWS 32 |
| 2026-10-13 | Hand tray: the key badge shows just the number ("1"), never "Ctrl+1"; no "on board" tag on placed pieces (the medallion portrait already shows it); a picked piece lifts no higher than a hovered one | Eren, Godot testing |
| 2026-10-13 | The title keeps the text "Tower Defence" until the name is decided (no logo placeholder); Boot keeps the plain dark wood backdrop; Welcome, Main menu and Loading share the blurred diorama image, centred; main-menu miniatures face bottom-left | Eren |
| 2026-10-13 | Level camera pitch stays 50° (the Unity gameplay angle); level lighting matched to Unity's muted look (a 35° trial was rejected as too flat) | Eren |
| 2026-10-13 | HP bars follow Unity's rule everywhere: status chips always visible, the bar only with Always Show Health, hover/selection, 1.5 s after a hit, a preview, or while dying | Eren: the Godot bars showed always |
| 2026-10-13 | Camp stations stand in a ring round the campfire, props facing the camera, front stations' buttons below their prop, back ones above; the camp board stays expandable (free slots in `layout.json`, Blender kit) | Eren: the 18×9 arc layout read too big with bad angles |
| 2026-10-11 | A separate Loading scene shows before every level (the game's name, a Codex tip, a live bar); the Boot scene's loading stays plain | Eren: boot stays simple; loading a level deserves a screen |
| 2026-10-11 | The Loading scene is a real loading screen with its own script (`UI_Loading`): it waits for the level to build its board, models and HUD under the opaque screen before 100% and the fade; minimum 0.3 s | Eren: the level was being set up after the bar was full; and Boot and Loading should not share one script |
| 2026-10-11 | Left-drag on the board pans the map (Drag with Mouse, on by default); board clicks act on release unless the press dragged | Eren: dragging the map with the mouse is expected |
| 2026-10-11 | The Priest's Mend heals towers only, never the base | Eren |
| 2026-10-11 | The camera frames the board centred on the whole screen width; the right bar is no longer kept clear (it may cover the board's edge while open). Mid-screen banners centre on the screen | Eren: the level should start centred, and middle-of-screen text sat to the left |
| 2026-10-10 | Descriptions say only what a thing does: no cooldowns in ability descriptions (the cooldown shows on its own), no durations in status descriptions (the time pill shows them) | Eren: the descriptions read badly |
| 2026-10-10 | Damage and heal previews are calculated, not rolled: uncertain hits land, anything else left to chance (crits, chance reactions) is left out, `rand()` gives its lowest; stats, statuses, shields and certain reactions apply. The hovered enemy's numbers use the same dry run | Eren: a rolled preview would leak the RNG; a calculated one still counts armour and statuses. Chance effects are left out so the preview stays readable as abilities grow |
| 2026-10-10 | Your ability's preview shows only what the cast does to its targets: no reaction fires in it, even a guaranteed one (counters, on-death bursts). Kept open: `TurnForecast.Cast(..., reactions: true)`, or a warning in the tooltip | Eren: the player should think about those; showing them would clutter the board |
| 2026-10-10 | Every board gets an automatic frame: the kit's Border pieces (board edge side and corner) on the map's outer tiles, facing out. Replaces the same day's "no frame" note, a misunderstanding | Eren |
| 2026-10-05 | After Chapter 1 the player gets a Camp between the main menu and the levels (chapters, towers, Codex; later workshop and multiplayer); level select becomes a panel in it; main and side chapters; a Continue button in the main menu; no world map | A home for meta-progression, revealed as the reward for finishing Chapter 1, while the first hour stays linear |
| 2026-10-05 | The Codex shows only what the player has discovered (the rest as ???), with a turning 3D model for towers and enemies; opened from the main menu and the pause menu | A collection feel without spoilers (the Slime King); the model preview is where future art shows best |
| 2026-10-05 | Keys are rebindable (Settings > Controls): two per action, each a key with none, Shift, Ctrl, Alt or Ctrl+Shift; the ability keys' three uses (aim, quick cast, hand card) are each a modifier choice; mouse buttons and Esc stay fixed; a key may go to two actions, shown in red rather than taken away | The game is mouse-first; keys are shortcuts the player may move, and the modifier list stays short so combinations never clash |
| 2026-10-05 | Level lighting: a light from straight above (white, intensity 0.45, no shadows) plus soft grey flat ambient (0.65), no reflections; replaces fully flat lighting, tried the same day (76f76ab) | The angled light looked bad; after trying fully flat, the user chose to try a mix. Starting values the user may tune: the light's intensity for depth, the ambient colour for the shadow side |
| 2026-10-04 | Build tiles look like ground; only placing highlights them (66b7db2) | The user wants a clean board |
| 2026-10-04 | Clicks select and right-click cancels while an action plays; commands still wait for playback (6de2c81) | Waiting to inspect a unit felt sluggish; commands mid-animation would desync what is drawn |
| 2026-10-04 | Shift + 1–9: hold to preview, release to quick cast, right-click cancels; Shift while aiming shows the instinct's pick (6de2c81, 0673f35) | Lets the player see the automatic choice before committing |
| 2026-10-04 | Right-click never presses a button (UI_Button reacts to the left button only) (6de2c81) | Right-click means cancel everywhere |
| 2026-10-04 | Ability and passive tooltips open left of the right bar; hand card tooltips above the bottom bar (6de2c81) | Tooltips never cover the bar they describe |
| 2026-10-04 | Hand towers are picked with Ctrl+1–9 only; plain 1–9 aims abilities (83bba90) | Number keys did two things |
| 2026-10-04 | Health bars show on hover, selection, after a hit and while dying, not always; Always Show Health is a setting (7c621b8, bb44e47) | A cleaner board; the setting covers players who want them all |
| 2026-10-04 | Banners don't block play; a newer round or phase banner replaces a stale one (7c621b8, 7ec99b8) | Fast players were waiting on text |
| 2026-10-04 | Presentation durations live in a Presentation Timings asset (7c621b8) | Tunable without code |
| 2026-10-04 | Corpses hidden by default (5766902) | Visual noise; abilities that target corpses can turn them back on |
| 2026-10-04 | Follow the action centres every action (aceca91) | It moved only for off-screen actions, which felt random |
| 2026-10-03 | Shift + Space ends the round, like Enter (d063317) | Space alone skips playback |
| 2026-10-02 | The simulation resolves instantly; a Director plays the log back as animation | Logic never waits for art. See the Animation & Presentation design doc |

## Project and tools

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-10-13 | The game is being rebuilt in Godot 4.7 in a separate repo (ErenOsman/TowerDefenceGodot): the engine-free simulation ported 1:1 to GDScript and verified against the C# (183 tests, 11 golden level logs identical), the UI rebuilt natively from the kit and the UI rules | Eren asked for a full Godot rebuild; a separate repo keeps the Unity tooling and the Godot project apart |
| 2026-10-13 | The Unity repo stays the single source of truth for content (`Content/*.json`) and design docs; the Godot repo carries copies pulled by `tools/sync_from_unity.sh`, plus Godot-only notes in its `docs/GODOT-NOTES.md`; decisions taken while testing the Godot build go into this log and the UI doc | One place to edit, no drift between the two builds |
| 2026-10-08 | UI and dialogue answers for the style B redesign. Status durations: the status's own duration stays the fallback, and Apply Status may override it. Enemy intent on the board: yes, even more detailed. Dialogue speaker: the Princess, for now. Ability keys stay 1–9. No speed button in the HUD (Settings only). Pause has separate "Quit to level select" and "Quit game", and the tutorial's Pause also has "Exit tutorial". Victory shows base HP left and towers lost. No mid-level save: the main menu's Continue shows the next level | Eren's answers to the UI/UX agent's open questions (wiki to-do 2) |
| 2026-10-05 | One Shield status whose stacks are its points replaces Slime Shield and Stone Skin; the amount is the stacks applied | One shield mechanic, reusing stacks instead of a new field (AGENTS Rule 17) |
| 2026-10-05 | Logic work runs without Unity: Game.Data builds offline against a small UnityEngine stand-in, so tests, Validate All and the reference docs run on the content JSON (`Tools/Offline/offline.sh`) | The editor is a bottleneck for rules and content work; the same code runs in both places, so nothing is duplicated |
| 2026-10-05 | Content lives as JSON in `Content/` (one file per asset type) and is the source of truth; edits there are intended whoever made them; imports into Unity are chosen entry by entry; the content builders are deprecated | Content was hard-coded in builder scripts; JSON can be read, diffed and edited by people and any tool, and a partial import never overwrites what was not asked for |
| 2026-10-05 | Content numbers are owned by the assets, edited in the Balance Sheet (or Balance.txt for agents); the chapter builders create what is missing and fix structure, but never overwrite numbers | Balancing happens while playing; a builder rerun must not undo hand-tuned numbers |
| 2026-10-05 | Until 1.0, changes may break saves, restructure the game and alter older levels and content; no compatibility shims are kept | The game is in deep beta: a clean design matters more than old saves (Delete Save starts over) |
| 2026-10-05 | Every content asset has a hidden number, 1, 2, 3… per asset type, given by the editor and never reused (kept in `Editor/Game/ContentNumbers.txt`) | A short stable handle for tools, sorting, logs and later saves; the string ids stay what rules and saves use today |
| 2026-10-05 | Art by unit: `Art/Models/<Unit>/` holds the model, its animations and its own materials; no separate Animations folder | A model and its animations belong together; one folder per unit is what an artist opens |
| 2026-10-05 | Project layout: Docs at the repo root (outside Assets), content in one folder per type under `Assets/Data` (demo content in `Examples/`), art by kind under `Assets/Art`, Resources only for name-loaded assets (a680455) | Other people must find things without asking. Docs inside Assets were imported as assets for nothing; Resources ships everything in it with the game, so content stays out of it |
| 2026-10-05 | Game content is documented by a generated reference (`Tools > Docs > Export Game Reference`), not by hand (9a48d34) | Hand-written numbers go stale after every balance change |
| 2026-10-05 | Design docs live in the repo (`Docs/Design/`), not as claude.ai docs (a38b757) | Every person and agent working on the repo can read them |
| 2026-10-04 | Input goes through the Input System package only (`InputHelper`); the old Input Manager is off (2d2b0c7, cdaa6ec) | Unity is deprecating the Input Manager |
| 2026-10-04 | The repo is on GitHub as a private repo; nobody pushes unless the user asks | Backups and access for cloud sessions or a server, under the user's control |
| 2026-10-03 | Chapter 1 is built by `Tools > Combat > Create Chapter 1`; a rebuild leaves unchanged abilities untouched (81381ae) | Content can be regenerated after a balance change without file churn |
