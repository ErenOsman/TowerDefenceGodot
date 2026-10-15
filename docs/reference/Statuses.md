<!-- Generated from data/content by tools/game_reference.gd (or the TD Tools dock's Reference tab). Do not edit by hand: change the content and generate again. -->

# Statuses

Statuses sit on a unit for a while: buffs, debuffs, shields and marks. Turns count the carrier's own turns; rounds count whole rounds.

## Acid

Takes *stacks* damage at the start of each of its turns.

lasts 3 turns · stacking: Stack (up to 99) · tags: Debuff, Poison

ID `acid`

<sub>Source: `data/content/Statuses.json` → `Status/Acid`</sub>

## Burn

Takes *stacks* fire damage at the start of each of its turns.

lasts 2 turns · stacking: Replace · tags: Debuff, Fire

ID `burn`

<sub>Source: `data/content/Statuses.json` → `Status/Burn`</sub>

## Gorged

Has *20 × stacks* more max HP.

lasts until removed · stacking: Stack (up to 99) · tags: Buff, Permanent

ID `gorged`

<sub>Source: `data/content/Statuses.json` → `Status/Gorged`</sub>

## Haste

Moves farther: *stacks* more Speed.

lasts until removed · stacking: Stack (up to 99) · tags: Buff

ID `haste`

<sub>Source: `data/content/Statuses.json` → `Status/Haste`</sub>

## Rallied

Hits for 2 more and moves 1 more tile.

lasts 2 turns · stacking: Refresh · tags: Buff

ID `rallied`

<sub>Source: `data/content/Statuses.json` → `Status/Rallied`</sub>

## Shield

Blocks the next *stacks* damage before HP.

lasts until removed · stacking: Stack (up to 9999) · shield: Stacks · tags: Buff

ID `shield`

<sub>Source: `data/content/Statuses.json` → `Status/Shield`</sub>

## Taunted

Must attack whoever taunted it, when it can reach them.

lasts 2 turns · stacking: Refresh · tags: Taunted, Debuff

ID `Taunted`

<sub>Source: `data/content/Statuses.json` → `Status/Taunted`</sub>
