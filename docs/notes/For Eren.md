# For Eren

> **Unity-era note (2026-10-05), Godot pass 2026-10-15.** The questions and proposals are still open and apply to the
> Godot build's content (`data/content`) as well; the "Done" list describes checks made in the Unity project.

Questions and proposals collected while you were away (from 2026-10-05). I only build the parts that don't need your decision: bug fixes, tests, docs and checks. Everything that changes the game waits here for your answer. Newest first within each section.

## Questions (your decision)

1. **Level rules the wiki agent says you want.** Today's Validate All reports these as errors, so they aren't built yet. Are they right?
   - Build tiles allowed on any terrain (usable once someone can stand there) and on roads.
   - A path allowed to turn straight back.
   - A non-flyer sent over a chasm simply falls and dies (now: Validate All refuses to send it).
   - A base and a starting unit allowed to share a tile (the wiki agent itself advises against it).

## Proposals

1. **Numbers in descriptions go stale.** 38 descriptions contain hard-coded numbers ("Zaps an enemy up to 2 tiles away for 6"). Every balance change makes some of them wrong: Spark says 2 tiles / 6, but the Wisp has Range 3 / Power 10; Blink says 4 tiles, but its range is Range + 2 = 5. Two ways to fix it:
   - **a) Placeholders, reusing what exists:** status descriptions already fill in `{stacks}` and `{turns}`. The same could work in ability, passive and unit texts with the caster's numbers, e.g. "Zaps an enemy up to {Self.Range} tiles away for {Self.Power}". The text then always matches the data.
   - **b) No numbers in texts:** the tooltips already show range and damage separately, so the text could only say what the ability does.

   I'd do (a). Shared abilities make it necessary: Smash belongs to the Brute (15), the Ironhide (22) and the Rockjaw (18), so no single number in its text can be right. Until you decide, I only correct texts that are wrong (see Done).

## Done while you were away

- 2026-10-05: Unity check: all 130 Content JSON entries match their assets, and Validate All has no errors (20 missing icons). The Level Editor works with the new map layers, including painting, a self-crossing path drawn as ┼, and resizing; no console errors.
- 2026-10-05: tests for the content JSON format (layout, round trips, error reporting). They found that a never-set text was written as `null` but loaded as `""`; it's now written as `""`, as Unity stores it. The Unity session's health scan found no missing scripts and no broken references in 82 prefabs, 6 scenes and 130 content assets.
- 2026-10-05: corrected stale texts; no numbers changed:
  - Spark now reads 3 tiles / 10 and Blink 5 tiles, matching the Wisp's data.
  - Crush, Slam and Smash say "its Power" instead of one number. Several enemies with different Power share them; Smash, for example: Brute 15, Ironhide 22, Rockjaw 18.
  - Rock Eater and Rockjaw now say "100 Shield" instead of "stone shield".
- 2026-10-05: started this file.
