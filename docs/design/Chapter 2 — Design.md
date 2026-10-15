# Chapter 2 — Design

Started 2026-10-05. Godot pass 2026-10-15. The levels are content entries `Level/Chapter 2/…` in `data/content/Levels.json` (first generated in the Unity project by its Create Chapter 2 tool; now edited as content). Numbers are first guesses, to be tuned in play.

The second main chapter, played from the Camp after Chapter 1. Each level is built around one main gimmick (the user's), filled out with stronger enemies, fuller waves and a new, pricier tower as its first-clear reward.

## New units

| Unit | Side | What it does | Numbers |
| --- | --- | --- | --- |
| **Wisp** (tower) | yours | Spark: hits an enemy (Range 3). Blink: teleports to a free tile up to Range + 2 away, over anything, every third turn. Chapter 1 level 4's reward (was a second Archer) | HP 15, Power 10, Range 3, cost 200 |
| **Rock** | neutral | Blocks its tile, roads included; anyone can break it. Tag `Rock` | HP 20 |
| **Rabbit** | enemy | Hop: moves up to Speed along its road, jumping over anything in the way. Nibble: hits what is next to it. Quicken: an ability it casts on itself every other turn (cooldown 2): +1 Speed (Haste, stacking, at most +2) | HP 30, Speed 1 (Quicken: up to 3), Power 5 |
| **Rockjaw** | enemy | A Brute that eats a rock next to it (the one in front of it on its road first) at the end of each of its turns and gains 100 Shield per rock | HP 70, Power 18 |
| **Drummer** (was the War Drum) | yours (2-3's starting ally, then 2-3's reward tower) | War Beat: towers within 2 tiles get +3 Power. Rally: allies within 2 get +2 Power and +1 Speed for its Duration (2 turns), every third turn | HP 30, Duration 2, cost 200 |
| **Bat** | enemy | Flying: walks a road drawn across a chasm. Bite | HP 30, Speed 2, Power 8 |
| **Ironhide** | enemy | A big brute with a shield that refills every turn (Shielded) | HP 130, Power 22 |
| **Slime Shaman** | enemy | Slime Mend: heals the most hurt enemy within 3 for its Potency, every other turn | HP 40, Potency 15 |
| **Jackalope** | enemy | A big rabbit: Quicken, Hop, Nibble | HP 55, Speed 3, Power 9 |
| **Ballista** (tower) | yours, 2-1's reward | Bolt: an enemy 2 to 4 tiles away, every other turn | HP 20, Power 25, Range 4, cost 240 |
| **Alchemist** (tower) | yours, 2-2's reward | Acid Flask: area (Radius 1) for its Power and Acid stacks equal to its Potency (Acid: that much damage each turn for 3 turns, stacking) | HP 15, Power 4, Potency 3, Range 3, cost 220 |
| **Cannon** (tower) | yours, 2-4's reward | Bombard: 2 to 3 tiles away, area (Radius 1) for 30, every third turn | HP 30, Power 30, cost 280 |
| **Slime Glutton** (boss) | enemy | When it arrives it kills every other enemy on the field; each kill gives it +20 max HP (Gorged) and heals 20. Then Slam (area) and Crush like the Slime King | HP 200, Power 10 |

## Levels

Chapter 2 uses its own base, the **Fortress** (40 HP; Chapter 1's Base has 10): its enemies hit for up to 22, and their hits stay one-shots for towers on purpose. Rockjaws' Shield adds up, but only the 6 rocks on or beside Rock Garden's road are within their reach.

| Level | Map | The idea | Waves |
| --- | --- | --- | --- |
| 1 Rock Garden (reward: Ballista) | 14×7, one road; energy 400 +40 | Two columns of rocks across the middle, on the road too. Rabbits hop them; Rockjaws stop at them and eat through | Hoppers (4 rabbits); Rockjaw + rabbits + a slime; two Rockjaws, two Jackalopes, a rabbit |
| 2 Three at the Gate (reward: Alchemist) | 14×7, one road; 450 +40 | Starts with three Brutes already in the middle of the road | Stragglers; Healers (two Shamans, a Brute, a rabbit); Ironhide + hoppers |
| 3 The Drummer (reward: Drummer) | 14×8; 450 +40 | Starts with a Drummer on your side. The base sits just above the chasm on the right; the ground road climbs to the top and comes round to it; a wall block in the middle. The bottom two rows are chasm with a road along the bottom; the last wave's Bats fly along it | Spitters + a Shaman; Brutes + an Ironhide; From the Chasm (4 bats, a slime, a Jackalope) |
| 4 The Glutton (reward: Cannon) | 15×9, three roads into one base (the outer two along the top and bottom edges, round the right side); 550 +45 | Strong enemies on all roads first; the Glutton then eats them all on arrival and comes on bigger (about +160 max HP) | Vanguard (Ironhides, Brutes, Big Slime, Shield Slime, a Shaman, a Jackalope); The Glutton |

Every Chapter 2 level lets in 5 towers of the hand.

## Rules this chapter added

- Starting units (allies, neutral obstacles, enemies on a road): a level entry's `startingUnits`.
- Hopping over units on a road (`PatternDef.jumpsOverUnits` + Jump step).
- Flying over chasms; a road across a chasm is for flyers only (Validate All checks it).
- Abilities that need a free tile (`needsFreeTile`: Blink).
- Winning at once when the last enemy falls.

## Open questions

- Real models: the new units use the slime / brute placeholders or a plain shape. (The Godot build has Blender models for all of them in `art/models/`: Rockjaw, Jackalope, Ironhide, Drummer, Bat, Slime Glutton…)
- Towers' quick cast may pick a rock (rocks are a valid target for attacks): keep, or have the instinct skip rocks?
