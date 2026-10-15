<!-- Generated from data/content by tools/game_reference.gd (or the TD Tools dock's Reference tab). Do not edit by hand: change the content and generate again. -->

# Towers

Towers are placed from the hand for energy, only on build tiles when a level has any. Each acts freely in the player phase.

| Tower | Cost | HP | Speed | Duration | Potency | Power | Radius | Range | First clear of |
|---|---|---|---|---|---|---|---|---|---|
| [Archer](#archer) | 100 | 20 | 2 | — | — | 10 | — | 2 | starting tower |
| [Guardian](#guardian) | 100 | 40 | 2 | — | — | 5 | — | 2 | First Steps |
| [Mage](#mage) | 120 | 15 | 2 | — | 2 | 8 | 1 | 3 | Spitters |
| [Priest](#priest) | 100 | 15 | 2 | — | 10 | 5 | — | 3 | Two Roads |
| [Wisp](#wisp) | 200 | 15 | 2 | — | — | 10 | — | 3 | The Slime King |
| [Ballista](#ballista) | 240 | 20 | 1 | — | — | 25 | — | 4 | Rock Garden |
| [Alchemist](#alchemist) | 220 | 15 | 2 | — | 3 | 4 | 1 | 3 | Three at the Gate |
| [Drummer](#drummer) | 200 | 25 | 2 | 2 | — | — | — | — | The Drummer |
| [Cannon](#cannon) | 280 | 30 | 1 | — | — | 30 | 1 | 3 | The Glutton |

## Archer

Shoots enemies up to 2 tiles away and can move between shots.

Cost **100** energy · type ID `archer`

<sub>Source: `data/content/Towers.json` → `Tower/Archer Tower` · `data/content/Units.json` → `Unit/Tower/Archer`</sub>

Stats: HP 20 · Speed 2 · Range 2 · Power 10

Abilities, in the order they show:

1. **Shoot** _(Attack, Projectile)_: Shoots an arrow for 10 at an enemy up to 2 tiles away.
   Range 2 · Damage 10 · Cooldown 1
2. **Tower Walk** _(Movement)_: Moves the tower up to Speed tiles.
   Moves up to 2 tiles · Cooldown 2

## Guardian

A sturdy tower that taunts enemies into hitting it instead of the others.

Cost **100** energy · type ID `guardian`

<sub>Source: `data/content/Towers.json` → `Tower/Guardian Tower` · `data/content/Units.json` → `Unit/Tower/Guardian`</sub>

Stats: HP 40 · Speed 2 · Range 2 · Power 5

Abilities, in the order they show:

1. **Taunt**: Taunts an enemy up to 2 tiles away for 2 turns: when it can reach the Guardian, it attacks the Guardian.
   Range 2 · Cooldown 2
2. **Bash** _(Attack, Melee)_: Bashes an adjacent enemy for 5.
   Range 1 · Damage 5 · Cooldown 1
3. **Tower Walk** _(Movement)_: Moves the tower up to Speed tiles.
   Moves up to 2 tiles · Cooldown 2

Passives:

- **Counter-attack**: When an adjacent enemy hits it, it hits back for 5 (once per turn). Only while at half HP or more.

## Mage

Slow but hits groups: Firebolt burns everything around the tile it hits.

Cost **120** energy · type ID `mage`

<sub>Source: `data/content/Towers.json` → `Tower/Mage Tower` · `data/content/Units.json` → `Unit/Tower/Mage`</sub>

Stats: HP 15 · Speed 2 · Range 3 · Radius 1 · Power 8 · Potency 2

Abilities, in the order they show:

1. **Firebolt** _(Attack, Spell, Fire)_: Hurls fire up to 3 tiles away: 8 to everyone on and around the tile it hits, your own towers and base too, and sets them burning (2 a turn for 2 turns).
   Range 3 · Area: Circle 1 · Damage 8 · Cooldown 2
2. **Tower Walk** _(Movement)_: Moves the tower up to Speed tiles.
   Moves up to 2 tiles · Cooldown 2

## Priest

Keeps the others standing: Mend heals the most hurt tower.

Cost **100** energy · type ID `priest`

<sub>Source: `data/content/Towers.json` → `Tower/Priest Tower` · `data/content/Units.json` → `Unit/Tower/Priest`</sub>

Stats: HP 15 · Speed 2 · Range 3 · Power 5 · Potency 10

Abilities, in the order they show:

1. **Mend** _(Spell)_: Heals a hurt tower up to 4 tiles away for 10.
   Range 4 · Cooldown 1
2. **Smite** _(Attack, Spell)_: Smites an enemy up to 3 tiles away for 5, or 15 against a boss. The Priest's other abilities wait one more turn.
   Range 3 · Damage 5 · Cooldown 1
3. **Tower Walk** _(Movement)_: Moves the tower up to Speed tiles.
   Moves up to 2 tiles · Cooldown 2

## Wisp

A spirit tower: it zaps from afar and blinks across the field, over walls and roads.

Cost **200** energy · type ID `wisp`

<sub>Source: `data/content/Towers.json` → `Tower/Wisp Tower` · `data/content/Units.json` → `Unit/Tower/Wisp`</sub>

Stats: HP 15 · Speed 2 · Range 3 · Power 10

Abilities, in the order they show:

1. **Spark** _(Attack, Spell)_: Zaps an enemy up to 3 tiles away for 10.
   Range 3 · Damage 10 · Cooldown 1
2. **Blink** _(Movement)_: Teleports to a free tile up to 5 tiles away, over anything in between.
   Range 5 · Cooldown 3

## Ballista

A siege bow: it hits hard from far away, but cannot shoot what stands next to it.

Cost **240** energy · type ID `ballista`

<sub>Source: `data/content/Towers.json` → `Tower/Ballista Tower` · `data/content/Units.json` → `Unit/Tower/Ballista`</sub>

Stats: HP 20 · Speed 1 · Range 4 · Power 25

Abilities, in the order they show:

1. **Bolt** _(Attack, Projectile)_: Fires a heavy bolt for 25 at an enemy 2 to 4 tiles away.
   Range 2–4 · Damage 25 · Cooldown 2
2. **Tower Walk** _(Movement)_: Moves the tower up to Speed tiles.
   Moves up to 1 tile · Cooldown 2

## Alchemist

Throws flasks of acid onto groups: the acid keeps eating them for a few turns, stacking.

Cost **220** energy · type ID `alchemist`

<sub>Source: `data/content/Towers.json` → `Tower/Alchemist Tower` · `data/content/Units.json` → `Unit/Tower/Alchemist`</sub>

Stats: HP 15 · Speed 2 · Range 3 · Radius 1 · Power 4 · Potency 3

Abilities, in the order they show:

1. **Acid Flask** _(Attack, Spell)_: Throws acid up to 3 tiles away: 4 to every enemy on and around the tile, and 3 Acid that eats them for 3 turns.
   Range 3 · Area: Circle 1 · Damage 4 · Cooldown 2
2. **Tower Walk** _(Movement)_: Moves the tower up to Speed tiles.
   Moves up to 2 tiles · Cooldown 2

## Drummer

A drummer beating a war drum: towers within 2 tiles of it hit 3 harder, and Rally speeds them up for a while.

Cost **200** energy · type ID `drummer`

<sub>Source: `data/content/Towers.json` → `Tower/Drummer Tower` · `data/content/Units.json` → `Unit/Tower/Drummer`</sub>

Stats: HP 25 · Duration 2 · Speed 2

Abilities, in the order they show:

1. **Rally** _(Spell)_: Every ally within 2 tiles gets 2 more Power and 1 more Speed for 2 turns.
   Self · Cooldown 3
2. **Tower Walk** _(Movement)_: Moves the tower up to Speed tiles.
   Moves up to 2 tiles · Cooldown 2

Passives:

- **War Beat**: Towers within 2 tiles get 3 more Power.

## Cannon

Slow and heavy: a shell every third turn that wrecks a whole group. It cannot fire at what is next to it.

Cost **280** energy · type ID `cannon`

<sub>Source: `data/content/Towers.json` → `Tower/Cannon Tower` · `data/content/Units.json` → `Unit/Tower/Cannon`</sub>

Stats: HP 30 · Speed 1 · Range 3 · Radius 1 · Power 30

Abilities, in the order they show:

1. **Bombard** _(Attack, Lobbed)_: Lobs a shell 2 to 3 tiles away: 30 to every enemy on and around the tile.
   Range 2–3 · Area: Circle 1 · Damage 30 · Cooldown 3
2. **Tower Walk** _(Movement)_: Moves the tower up to Speed tiles.
   Moves up to 1 tile · Cooldown 2
