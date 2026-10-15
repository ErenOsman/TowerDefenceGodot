<!-- Generated from data/content by tools/game_reference.gd (or the TD Tools dock's Reference tab). Do not edit by hand: change the content and generate again. -->

# Enemies

Enemies walk their road toward the base and act one at a time in the enemy phase, trying their abilities in order and using each one they can. Where an ability can aim at several targets, its instinct picks (see the Instinct design doc).

| Enemy | HP | Speed | Potency | Power | Radius | Range | Tags | First appears in |
|---|---|---|---|---|---|---|---|---|
| [Slime](#slime) | 10 | 1 | — | 5 | — | 1 | — | First Steps |
| [Big Slime](#big-slime) | 30 | 1 | — | 5 | — | 1 | — | First Steps |
| [Slime Archer](#slime-archer) | 15 | 1 | — | 5 | — | 2 | — | Spitters |
| [Runner](#runner) | 15 | 2 | — | 5 | — | 1 | — | Spitters |
| [Shield Slime](#shield-slime) | 20 | 1 | — | 5 | — | 1 | — | Two Roads |
| [Brute](#brute) | 30 | 2 | — | 15 | — | 1 | — | The Slime King |
| [Slime King](#slime-king) | 80 | 1 | — | 5 | 1 | 1 | Boss | The Slime King |
| [Rabbit](#rabbit) | 30 | 1 | — | 5 | — | 1 | — | Rock Garden |
| [Rockjaw](#rockjaw) | 70 | 1 | — | 18 | — | 1 | — | Rock Garden |
| [Jackalope](#jackalope) | 55 | 3 | — | 9 | — | 1 | — | Rock Garden |
| [Slime Shaman](#slime-shaman) | 40 | 1 | 15 | — | — | 3 | — | Three at the Gate |
| [Ironhide](#ironhide) | 130 | 1 | — | 22 | — | 1 | — | Three at the Gate |
| [Bat](#bat) | 30 | 2 | — | 8 | — | 1 | Flying | The Drummer |
| [Slime Glutton](#slime-glutton) | 200 | 1 | — | 10 | 1 | 1 | Boss | The Glutton |

## Slime

Slow and weak, but it rams the base.

Appears in: First Steps, Two Roads, The Slime King, Rock Garden, Three at the Gate, The Drummer

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Slime`</sub>

Stats: HP 10 · Speed 1 · Range 1 · Power 5

Abilities, in the order it tries them:

1. **Path Walk** _(Movement)_: Walks along its path, up to Speed tiles.
   Moves up to 1 tile along its path · Cooldown 1
2. **Ram** _(Attack, Melee)_: Rams the base for 5 and dies doing so.
   Range 1 · Damage 5 · Cooldown 1

## Big Slime

A big, slow slime with 30 HP that rams the base.

Appears in: First Steps, Spitters, The Glutton

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Big Slime`</sub>

Stats: HP 30 · Speed 1 · Range 1 · Power 5

Abilities, in the order it tries them:

1. **Path Walk** _(Movement)_: Walks along its path, up to Speed tiles.
   Moves up to 1 tile along its path · Cooldown 1
2. **Ram** _(Attack, Melee)_: Rams the base for 5 and dies doing so.
   Range 1 · Damage 5 · Cooldown 1

## Slime Archer

Walks along its path like the other slimes, then spits at a tower or the base up to 2 tiles away for 5.

Appears in: Spitters, Two Roads, The Slime King, Three at the Gate, The Drummer

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Slime Archer`</sub>

Stats: HP 15 · Speed 1 · Range 2 · Power 5

Abilities, in the order it tries them:

1. **Path Walk** _(Movement)_: Walks along its path, up to Speed tiles.
   Moves up to 1 tile along its path · Cooldown 1
2. **Spit** _(Attack, Projectile)_: Spits at a tower or the base up to 2 tiles away for 5.
   Range 2 · Damage 5 · Cooldown 1

## Runner

A small, fast slime: 2 tiles a turn, and it rams the base.

Appears in: Spitters, Two Roads, The Slime King, Three at the Gate

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Runner`</sub>

Stats: HP 15 · Speed 2 · Range 1 · Power 5

Abilities, in the order it tries them:

1. **Path Walk** _(Movement)_: Walks along its path, up to Speed tiles.
   Moves up to 2 tiles along its path · Cooldown 1
2. **Ram** _(Attack, Melee)_: Rams the base for 5 and dies doing so.
   Range 1 · Damage 5 · Cooldown 1

## Shield Slime

A slime whose shield absorbs 10 damage and refills to 10 at the start of each of its turns.

Appears in: Two Roads, The Slime King, The Drummer, The Glutton

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Shield Slime`</sub>

Stats: HP 20 · Speed 1 · Range 1 · Power 5

Abilities, in the order it tries them:

1. **Path Walk** _(Movement)_: Walks along its path, up to Speed tiles.
   Moves up to 1 tile along its path · Cooldown 1
2. **Ram** _(Attack, Melee)_: Rams the base for 5 and dies doing so.
   Range 1 · Damage 5 · Cooldown 1

Passives:

- **Shielded**: Arrives with a Shield that absorbs 10 damage, and refills it to 10 at the start of each of its turns.

## Brute

A melee enemy. It walks to the tower furthest ahead that it can reach this turn and smashes it.

Appears in: The Slime King, Three at the Gate, The Drummer, The Glutton

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Brute`</sub>

Stats: HP 30 · Speed 2 · Range 1 · Power 15

Abilities, in the order it tries them:

1. **Brute Walk** _(Movement)_: Walks up to Speed tiles along its path, stopping where its attack can reach the target it wants.
   Moves up to 2 tiles along its path · Cooldown 1 · instinct: engage (walks to where its attack can reach its target)
2. **Smash** _(Attack, Melee)_: Smashes an adjacent tower or the base for its Power: the one furthest ahead on its path, the nearer on a tie.
   Range 1 · Damage 15 · Cooldown 1 · instinct: ahead (the unit furthest along its path)

## Slime King

The boss: it walks to the towers ahead, slams everything next to it and crushes the base.

Appears in: The Slime King

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Slime King`</sub>

Stats: HP 80 · Speed 1 · Range 1 · Radius 1 · Power 5 · tags: Boss

Abilities, in the order it tries them:

1. **Path Walk** _(Movement)_: Walks along its path, up to Speed tiles.
   Moves up to 1 tile along its path · Cooldown 1
2. **Slam** _(Attack, Melee)_: Slams the ground: twice its Power to every tower next to it.
   Self · Area: Diamond 1 · Damage 10 · Cooldown 1
3. **Crush** _(Attack, Melee)_: Crushes the base, or a tower, next to it for its Power. It goes for the base unless taunted.
   Range 1 · Damage 5 · Cooldown 1 · instinct: prefers highest `if(Target.HasTag(Base), 1, 0)`, then lowest `Self.DistanceTo(Target)`

## Rabbit

A quick hopper: it jumps over anything on its road and speeds up every second turn.

Appears in: Rock Garden, Three at the Gate

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Rabbit`</sub>

Stats: HP 30 · Speed 1 · Range 1 · Power 5

Abilities, in the order it tries them:

1. **Quicken** _(Buff)_: Speeds itself up: 1 more Speed, twice at most.
   Self · Cooldown 2
2. **Hop** _(Movement)_: Hops up to Speed tiles along its road, over anything in its way.
   Moves up to 1 tile along its path · Cooldown 1
3. **Nibble** _(Attack, Melee)_: Nibbles a tower or the base next to it.
   Range 1 · Damage 5 · Cooldown 1

## Rockjaw

A brute that eats a rock next to it at the end of each turn and gains 100 Shield.

Appears in: Rock Garden

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Rockjaw`</sub>

Stats: HP 70 · Speed 1 · Range 1 · Power 18

Abilities, in the order it tries them:

1. **Brute Walk** _(Movement)_: Walks up to Speed tiles along its path, stopping where its attack can reach the target it wants.
   Moves up to 1 tile along its path · Cooldown 1 · instinct: engage (walks to where its attack can reach its target)
2. **Smash** _(Attack, Melee)_: Smashes an adjacent tower or the base for its Power: the one furthest ahead on its path, the nearer on a tie.
   Range 1 · Damage 18 · Cooldown 1 · instinct: ahead (the unit furthest along its path)

Passives:

- **Rock Eater**: At the end of each of its turns it eats a rock next to it and gains 100 Shield.

## Jackalope

A big horned rabbit: it hops three tiles at a time and speeds up every second turn.

Appears in: Rock Garden, Three at the Gate, The Drummer, The Glutton

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Jackalope`</sub>

Stats: HP 55 · Speed 3 · Range 1 · Power 9

Abilities, in the order it tries them:

1. **Quicken** _(Buff)_: Speeds itself up: 1 more Speed, twice at most.
   Self · Cooldown 2
2. **Hop** _(Movement)_: Hops up to Speed tiles along its road, over anything in its way.
   Moves up to 3 tiles along its path · Cooldown 1
3. **Nibble** _(Attack, Melee)_: Nibbles a tower or the base next to it.
   Range 1 · Damage 9 · Cooldown 1

## Slime Shaman

Keeps the others going: it heals the most hurt enemy within 3 tiles, every other turn.

Appears in: Three at the Gate, The Drummer, The Glutton

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Slime Shaman`</sub>

Stats: HP 40 · Speed 1 · Range 3 · Potency 15

Abilities, in the order it tries them:

1. **Slime Mend** _(Spell)_: Heals a hurt enemy up to 3 tiles away for its Potency.
   Range 3 · Cooldown 2
2. **Path Walk** _(Movement)_: Walks along its path, up to Speed tiles.
   Moves up to 1 tile along its path · Cooldown 1

## Ironhide

A huge brute under a shield that refills every turn. It smashes the tower furthest ahead.

Appears in: Three at the Gate, The Drummer, The Glutton

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Ironhide`</sub>

Stats: HP 130 · Speed 1 · Range 1 · Power 22

Abilities, in the order it tries them:

1. **Brute Walk** _(Movement)_: Walks up to Speed tiles along its path, stopping where its attack can reach the target it wants.
   Moves up to 1 tile along its path · Cooldown 1 · instinct: engage (walks to where its attack can reach its target)
2. **Smash** _(Attack, Melee)_: Smashes an adjacent tower or the base for its Power: the one furthest ahead on its path, the nearer on a tie.
   Range 1 · Damage 22 · Cooldown 1 · instinct: ahead (the unit furthest along its path)

Passives:

- **Shielded**: Arrives with a Shield that absorbs 10 damage, and refills it to 10 at the start of each of its turns.

## Bat

A flying pest: it crosses chasms on its road and bites what it reaches.

Appears in: The Drummer

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Bat`</sub>

Stats: HP 30 · Speed 2 · Range 1 · Power 8 · tags: Flying

Abilities, in the order it tries them:

1. **Path Walk** _(Movement)_: Walks along its path, up to Speed tiles.
   Moves up to 2 tiles along its path · Cooldown 1
2. **Bite** _(Attack, Melee)_: Bites a tower or the base next to it.
   Range 1 · Damage 8 · Cooldown 1

## Slime Glutton

The boss: when it arrives it eats every other enemy on the field, growing 20 max HP for each, then slams and crushes its way to the base.

Appears in: The Glutton

<sub>Source: `data/content/Units.json` → `Unit/Enemy/Slime Glutton`</sub>

Stats: HP 200 · Speed 1 · Range 1 · Radius 1 · Power 10 · tags: Boss

Abilities, in the order it tries them:

1. **Path Walk** _(Movement)_: Walks along its path, up to Speed tiles.
   Moves up to 1 tile along its path · Cooldown 1
2. **Slam** _(Attack, Melee)_: Slams the ground: twice its Power to every tower next to it.
   Self · Area: Diamond 1 · Damage 20 · Cooldown 1
3. **Crush** _(Attack, Melee)_: Crushes the base, or a tower, next to it for its Power. It goes for the base unless taunted.
   Range 1 · Damage 10 · Cooldown 1 · instinct: prefers highest `if(Target.HasTag(Base), 1, 0)`, then lowest `Self.DistanceTo(Target)`

Passives:

- **Glutton**: When it arrives it eats every other enemy on the field; each kill gives it 20 more max HP.
