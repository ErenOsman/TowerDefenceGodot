# Guided Tutorial — Design

Written 2026-10-14 by the Godot agent from Eren's decisions (2026-10-13/14). This file is the source of truth for
the tutorial level's guidance; "Tutorial, First Run & Sequences — Design" keeps the first-run flow and the sequence
system (level intros, entrance lines), but its tutorial part is replaced by this doc. The current step list and the
data grammar are mirrored in the Godot repo's `docs/GODOT-NOTES.md` ("Tutorial lines") until the content moves into
the Unity repo.

## Why a new tutorial

- A friend of Eren's played the old tutorial and **never learned that towers can move**. The old one (Unity, a plain
  sequence of speech bubbles) explained but did not make the player do things, and the tower panel opened over the
  bubble.
- The first Godot version made the player act but spoke through **tooltip-like bubbles on the board**: cramped,
  pointing at tiles, text overlapping ("Finish this step first" over "Click or Space"). Eren: "there should be a
  visual-novel style conversation here, not a tooltip style" and "Unity's was bad too".

## Decisions

| Topic | Decision | Source |
| --- | --- | --- |
| Shape | **Short** and **hand-holding ("babysit")**: one small step per line, the player does each thing once, nothing is only told | Eren 2026-10-14 |
| What it teaches | Place a tower, **towers move** (Tower Walk), shoot, cooldowns (End turn to recover), quick cast, End turn; then "finish the wave" freely | Eren 2026-10-14 |
| Gating | At every step **only the allowed action is possible**: its target is ringed (tile, button, tray piece, unit); anything else is refused with a shake and a specific refusal line | Eren 2026-10-14 |
| Presentation | The Princess speaks through the **visual-novel dialogue box** at the bottom of the screen: name plate, letter-by-letter text, "Click or press Space", "Tutorial · n/N" with the bobbing next mark, **Skip** top-right. Not bubbles on the board. The Princess stands on the board as a 3D prop while she speaks | Eren 2026-10-14 (box) · 2026-10-08 (dialogue style, the Princess speaks, the Base does not) |
| Box placement | Bottom by default; when the ringed target would be under the box, the box **docks at the top** for that step. The box never covers the target | agents |
| Skip | **Click only** (the Skip button); Esc keeps its normal meaning (cancel / pause). Skip ends the guidance: free play with the normal HUD | Eren 2026-10-14 |
| Pause in the tutorial | Continue, Settings, Skip tutorial (and Quit, which counts as skipping); no Main menu, no Codex | Eren 2026-10-08 (Camp doc) |
| Text | The lines are **placeholders**: Eren rewrites them. The agents do not polish wording | Eren 2026-10-13 |
| Where lines live | For now `data/tutorial.json` in the Godot repo (the Sequences.json line format plus `allow` / `advance`). Once Unity has the same gating, the lines move to `Data/Sequences/Tutorial Steps` and the JSON keeps only the gating | agents |

## The level

(Godot overlay until the Unity Levels.json changes; the Unity agent must make the same change.) The catalog's
tutorial level `Levels/Tutorial/Tutorial` ("First Defence") is shortened (Eren 2026-10-14: the slime took too long):

- **Map** 7 × 5 (was 12 × 5), all Ground. **Road** row 2, 6 tiles from the spawn at (0,2) to (5,2) (was 11);
  the **castle** (`Units/Bases/Base`) at (6,2).
- **Build tiles** beside the road at the castle end: columns 4–6 of rows 0, 1, 3, 4 (12 tiles). The tutorial lights
  (5,1) and (5,3); the road line points at (2,2); the walk goes 2 tiles toward the slime ((5,1) → (3,1)).
- **Waves** unchanged: "One Slime" (a Slime at round 1), then "A Slime and a Runner" after it. **Energy** unchanged:
  100 to start, 0 per round, the fixed hand is the Archer (cost 100), hand cap 1.
- Played as the steps ask, **the slime is in Shoot range after ≤ 2 End turns** at step 9, and the level is won in
  about 8 rounds (8 End turns in `tests/test_tutorial.gd`).
- Camera (Godot, `hud.gd`): while the guidance runs, the board is framed above the bottom dialogue box (bottom inset
  = the box + its name plate), so the small board never sits under the box; free play / Skip returns to the normal
  framing.

## The steps (placeholder wording)

| # | The Princess says | Allowed (ringed) | Goes on when |
| --- | --- | --- | --- |
| 1 | Slimes come down this road… | nothing (the road is ringed) | click / Space |
| 2 | …to your castle. Keep it safe. | nothing (the castle) | click / Space |
| 3 | Click your Archer to place it. | the Archer's tray piece | placing starts |
| 4 | Now click a lit tile. | two build tiles (only they light) | the tower is placed |
| 5 | End the turn to let the slime come. | End turn | the round ended |
| 6 | Towers can move. Click your Archer. | selecting the Archer | it is selected |
| 7 | Click Tower Walk. | the Tower Walk button | aiming starts |
| 8 | Now click the lit tile. | the tile 2 steps toward the slime | the walk is cast |
| 9 | Click End turn until the slime is in range. | End turn | the first enemy is in Shoot range at a turn start |
| 10 | Click Shoot. | the Shoot button | aiming starts |
| 11 | Now click the slime. | the slime | the shot is cast |
| 12 | Nice shot. | nothing | 1.5 s |
| 13 | Shoot needs a turn to recover. Click End turn. | End turn | the round ended |
| 14 | A Runner is fast. {click:QuickCast} Shoot to fire at the nearest target. | quick cast Shoot (or a normal Shoot); End turn while nothing is in range | a cast |
| 15 | That's it: place, move, shoot, end turn. Finish the wave. | everything | the level is won |

Refusals (shake + the refusal replaces the box's note line for about 2 s, in the warning colour): "Not now: click the
slime first." style, naming what the step needs (the Archer piece, the lit tile, your Archer, Tower Walk, Shoot, End
turn, the slime, "Shift-click Shoot"); "Finish this step first." on talk lines. End turn shows dimmed on steps that do
not allow it. The hint line under the action bar is hidden while the tutorial speaks.

## The box during a step

```text
┌ Princess ──────────────────────────────────────────────── [▶ Skip] ┐
│ Click Tower Walk.                                                   │
│                                                                     │
│ Click the ringed button              Tutorial · 7/15            ▼   │
└─────────────────────────────────────────────────────────────────────┘
```

- Talk steps: the full line, then "Click or press Space" bottom-left; a click shows the whole line first, a second
  click goes on.
- Action steps: the line stays while the ring marks the target; the bottom-left note names the allowed action; the
  box does not wait for a click, the action itself advances the step.
- Timed steps ("Nice shot.") go on by themselves.

## Data

`data/tutorial.json` (Godot repo; later Unity content): `_about` + `lines`, each line in the Sequences.json line
format (`speaker`, `text`, `pointAt`, `tileX`/`tileY`, `uiElement`, `continueOn`, `seconds`, `waitFor`,
`pausesPlay`) plus:

- `advance`: `click` | `seconds:<s>` | `event:<placing|placed|selected|aiming|cast|round_ended|in_range|won>`.
- `allow`: the only actions possible while the line shows. Tokens: `piece:<tower type id>`, `tile:x,y`,
  `select:archer` (the player's first tower), `ability:<ability id>`, `aim_tile:x,y`, `aim_tile:toward_enemy:<n>`,
  `aim_unit:first_enemy`, `aim_unit:enemy`, `end_turn`, `end_turn:until_castable`, `quick_cast`, `all`; `[]` = talk
  only. What a step needs first is implied (the piece again while a tile line is not placing, the archer while an
  ability line has nothing selected).
- Text macros: `{player}`, `{key:EndRound}`, `{click:QuickCast}` as in Sequences.

## Build plan

1. **Godot (built 2026-10-14, rebuilt onto the dialogue box the same day):** `game/level/guided_tutorial.gd` owned by
   the LevelController, `TdDialogueBox` for the speech, rings/pointers on targets, refusals, Skip; `tools/tutorial_shot.gd`
   renders the steps.
2. **Unity:** the same gating in the tutorial level (a `GuidedTutorial` over `SequenceRun`), the lines moved into
   `Data/Sequences/Tutorial Steps` with the `allow` / `advance` fields on the line asset; the dialogue box already exists
   (`UI_DialogueBox`).

## Open questions

- Whether the tutorial should also teach selling a tower and the enemy card (hovering an enemy) — not in the 15 steps.
- A second, optional tutorial for co-op (turns, Pass) once missions exist.
