<!-- Generated from the game content (Tools > Docs > Export Game Reference, or Tools/Offline/offline.sh docs). Do not edit by hand: change the content and export again. -->

# Statuses

Statuses sit on a unit for a while: buffs, debuffs, shields and marks. Turns count the carrier's own turns; rounds count whole rounds.

## Acid

Takes *stacks* damage at the start of each of its turns.

lasts 3 turns · stacking: Stack (up to 99) · tags: Debuff, Poison

ID `acid`

<sub>Source: `Assets/Data/Statuses/Acid.asset` (`Content/Statuses.json` → `Statuses/Acid`)</sub>

## Burn

Takes *stacks* fire damage at the start of each of its turns.

lasts 2 turns · stacking: Replace · tags: Debuff, Fire

ID `burn`

<sub>Source: `Assets/Data/Statuses/Burn.asset` (`Content/Statuses.json` → `Statuses/Burn`)</sub>

## Gorged

Has *20 × stacks* more max HP.

lasts until removed · stacking: Stack (up to 99) · tags: Buff, Permanent

ID `gorged`

<sub>Source: `Assets/Data/Statuses/Gorged.asset` (`Content/Statuses.json` → `Statuses/Gorged`)</sub>

## Haste

Moves farther: *stacks* more Speed.

lasts until removed · stacking: Stack (up to 99) · tags: Buff

ID `haste`

<sub>Source: `Assets/Data/Statuses/Haste.asset` (`Content/Statuses.json` → `Statuses/Haste`)</sub>

## Rallied

Hits for 2 more and moves 1 more tile.

lasts 2 turns · stacking: Refresh · tags: Buff

ID `rallied`

<sub>Source: `Assets/Data/Statuses/Rallied.asset` (`Content/Statuses.json` → `Statuses/Rallied`)</sub>

## Shield

Blocks the next *stacks* damage before HP.

lasts until removed · stacking: Stack (up to 9999) · shield: Stacks · tags: Buff

ID `shield`

<sub>Source: `Assets/Data/Statuses/Shield.asset` (`Content/Statuses.json` → `Statuses/Shield`)</sub>

## Taunted

Must attack whoever taunted it, when it can reach them.

lasts 2 turns · stacking: Refresh · tags: Taunted, Debuff

ID `Taunted`

<sub>Source: `Assets/Data/Statuses/Taunted.asset` (`Content/Statuses.json` → `Statuses/Taunted`)</sub>
