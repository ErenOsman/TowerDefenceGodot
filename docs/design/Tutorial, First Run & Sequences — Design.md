# Tutorial, First Run & Sequences — Design

Started 2026-10-05. Not built yet; the [build plan](#build-plan) lists the phases.

The first time the game starts, the player names themselves and plays a short tutorial level that teaches placing, selecting, shooting and ending a round. It can be skipped, and it appears only once.

**2026-10-14:** the tutorial itself is redesigned as a guided, hand-holding tutorial spoken through the visual-novel
dialogue box: see **Guided Tutorial — Design**. This doc keeps the first-run flow and the sequence system.

The tutorial's guidance and the conversations at the start of levels use one system: **sequences** of lines shown in **speech bubbles** (`UI_TextBubble`).

## Decisions

| Topic | Decision |
| --- | --- |
| When it shows | Only on the first launch: the save has no profile yet |
| Name screen | Its own scene, **WelcomeScene** (build index 4, `SceneID.Welcome`) |
| Guidance | Step by step: each step waits for the player to do it; the tutorial is a sequence (see below) |
| Text on screen | Speech bubbles (`UI_TextBubble`) driven by sequences — the same system for the tutorial and for level intros |
| Who speaks | The base: its bubble points at the base on the board, with the base's name. Other speakers can be added later |
| Level intros | Play the first time a level starts; Retry and replays skip them |
| Portraits | Name only for now; the bubble keeps a portrait slot for later |
| Tutorial level | 1 Archer (a fixed hand, not the player's), a 12-tile road, 2 waves: 1 Slime, then a Slime and a Runner; first clear gives 1 Archer |
| Replay | Not replayable once won: not in level select, and no Retry after a win. Losing offers Retry |
| Skipping | From the Welcome screen, or from the pause menu during the tutorial; skipping still gives the 2nd Archer |
| After winning | Main menu |
| Starting towers | A new save starts with 1 Archer (was 2); the tutorial or skipping it gives the 2nd, so everyone has 2 |

## Flow

```text
Boot (loading) ─┬─ save has a profile ─────────────────────────────────────▶ Main menu
                └─ first launch ─▶ Welcome (name) ─┬─ Start ──▶ Tutorial ─ win ─▶ Main menu
                                                   │               │ lose ─▶ Retry
                                                   │               └ pause ▶ Skip tutorial ─▶ Main menu
                                                   └─ Skip tutorial ───────────────────────▶ Main menu
```

Skipping (either way) marks the tutorial skipped and gives the 2nd Archer. Closing the game during the tutorial counts as skipping too (and after a crash, the next visit to the main menu or level select catches it), so the tutorial is never left pending; the Welcome screen does not come back, since the profile exists.

## Save: the profile

A new `profile` section in `GameData`:

| Field | Meaning |
| --- | --- |
| `playerName` | The name from the Welcome screen |
| `tutorial` | `NotStarted`, `Done` or `Skipped` |

- **First launch** = no profile in the save. The Welcome screen creates it.
- **Saves from before this feature** get a profile on load, marked `Skipped`, so existing players never see the Welcome screen.
- **Testing:** reset the save in `Tools > Runtime > Persistent Data Viewer` to see the first run again.

## Welcome screen

- A name field: not empty, at most 16 characters, prefilled with a default name.
- **Start** (main button) and **Skip tutorial** (smaller).
- Shows the name in the main menu afterwards ("Welcome back, Eren").
- Built like the other screens: a scene builder in the Tools menu, prefab-based UI, the boot loading screen routes here on first launch.

## The tutorial level

- A `LevelAsset` with id `tutorial`, outside the catalog's chapters, so level select never lists it.
- A 12×5 map, one road, the base at its end, build tiles around it; the Archer walks out to meet the enemies.
- **Fixed hand:** 1 Archer of its own. A new `LevelAsset` field (the level's own hand) overrides the player's hand; the player's collection is not touched.
- Energy: enough for exactly 1 Archer, no income needed.
- Waves: wave 1 — 1 Slime; wave 2 — a Slime and a Runner, starting after wave 1 is cleared.
- First clear: +1 Archer to the player's collection, `tutorial = Done`, then the main menu.

## Sequences and speech bubbles

### The speech bubble — `UI_TextBubble`

A reusable UI element (`Scripts/UI/Elements/TextBubble/`, prefab-based so it can be restyled):

- **Speaker:** a name line and an optional portrait.
- **Text:** rich text, revealed letter by letter (a click or Space shows it all at once, a second click goes on). `{player}` is replaced by the player's name.
- **Where it points:** at a unit or tile on the board (a tail toward it, following the camera), at a UI element (the End Turn button, an ability row), or nowhere (centred near the bottom).
- **Never blocks the board** unless the line says so; a small "Skip" in its corner skips the whole sequence.

### Sequences

A `SequenceAsset` (`Create > Game > Sequence`) is a list of lines, played in order. Each line has:

| Field | Meaning |
| --- | --- |
| Speaker | Who talks. For now always the base (the line's bubble points at it and shows its name); later other units or a speaker asset with a portrait |
| Text | What they say (`{player}` = the player's name, `{key:EndRound}` = that action's key as bound, `{click:QuickCast}` = "Shift-click" or whatever the quick-cast modifier is) |
| Points at | The speaker, nothing (bottom or middle of the screen), the first enemy or tower, the sequence's subject (an entrance: that enemy), a tile, or a UI element (by its name in the HUD) |
| Continues when | A click (default), after N seconds, or a game event: a tower placed, a unit selected, an ability cast, a quick cast, the round ended, a wave cleared, the level won |
| Pauses play | Whether commands wait while the line shows (intros: yes; tutorial steps: no, the player has to act) |

- A **level intro** is a sequence on the level (`LevelAsset.intro`) that plays before round 1, the first time the level is played (the save remembers which intros were seen). Every level may have one.
- **The tutorial** is the tutorial level's intro plus its steps: lines that continue on game events.
- **Entrance lines** are a sequence on an enemy (`EntityAsset.entrance`): the base speaks them the first time the player meets that enemy on the board (the save remembers it, like intros), once its arrival has played and no other sequence is showing. Lines pointing at *Subject* point at that enemy. The Slime King has two (`Data/Sequences/Slime King Entrance`, made by `Create Chapter 1`).
- Sequences only show text and read events; they never change the game (like the presenters).
- The Director's playback and a sequence don't fight: a line waiting for a game event waits until the action that caused it has finished playing.

### Tutorial lines

Built by `Tools > Deprecated > Create Tutorial` (`Data/Sequences/Tutorial Steps`). Placing a tower selects it, so there is no separate "select it" step; its panel then opens over the bubble, so two centred lines explain the panel and ask for a right-click to close it. The first Slime appears at the end of round 1 at the far end of a 12-tile road, and the Archer shoots 2 tiles, so the tutorial teaches walking toward it and shooting once it is in range.

| # | Text | Continues when | Points at |
| --- | --- | --- | --- |
| 1 | Welcome, {player}. Slimes are coming down that road, and I am what they want. | click | the base |
| 2 | Place your Archer near me. Click its card at the bottom, and the tiles you can build on light up; pick one. | a tower placed | the base |
| 3 | This panel shows the selected tower: its name and health at the top, then its abilities. Click an ability to use it; a number after its name is how many turns it must wait. | click | the middle of the screen |
| 4 | Right-click once to close it. | the selection closed | the middle of the screen |
| 5 | Good. Click End Turn to end the round (or press {key:EndRound}). Then the enemies move. | the round ended | End Turn button |
| 6 | A Slime! It is too far to shoot. Click your Archer, click Tower Walk on its panel, then a tile on the way to the Slime. | a tower moved | the first enemy |
| 7 | Your Archer shoots 2 tiles. Click End Turn until the Slime comes that close. | an enemy in range | the first enemy |
| 8 | It is in range! Click your Archer, click Shoot, then click the Slime. | an ability cast (not a walk) | the first enemy |
| 9 | Each round: shoot, then click End Turn. Keep it up until the Slime is gone. | wave cleared | the base |
| 10 | Well done! More are coming: keep clicking End Turn until they are here. | the next wave fully spawned (the Runner comes a round after the Slime) | End Turn button |
| 11 | A Slime and a fast Runner now. When one is in range, {click:QuickCast} Shoot: your Archer picks a target by itself. | a quick cast | the first enemy |
| 12 | Hold them off until the wave is over. | the level won | the base |

## Build plan

1. **Save profile and first-run routing** — `profile` in `GameData` (old saves marked Skipped), `SceneID.Welcome`, the boot loading screen picks Welcome or the main menu.
2. **Welcome scene** — name field, Start, Skip tutorial; scene builder; the main menu greets by name.
3. **Tutorial level** — fixed-hand field on levels, the tutorial level asset (built by a menu like Create Chapter 1), starting towers 2 → 1 and the reward/skip giving the 2nd, win → main menu, not in level select.
4. **Sequences** — `SequenceAsset` and speakers, the sequence player (lines, waits, game events, skip), `LevelAsset.intro`; testable without a scene.
5. **Speech bubble** — `UI_TextBubble` element and prefab, pointing at units, tiles and UI, letter-by-letter text, Skip; the level plays its intro.
6. **The tutorial sequence** — its lines, Skip tutorial in the pause menu.

Phases 1, 3 and 4 are code and data; 2, 5 and 6 need scene and prefab work in Unity.

## Open questions

- Sequences at other moments (a boss arriving, a wave starting, after a win) — later, through LevelEvents?
