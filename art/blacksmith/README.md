# Blacksmith kit (Blender, 2026-10-16)

The Blacksmith (Blacksmith — Design) as a small 3D diorama, shown like the Guild (`game/ui/screens/blacksmith.gd`,
TdStationWorld): a warm, ember-lit smithy with a stone lower wall and a timber frame with smoke-stained plaster above.
It follows the Guild v2 pattern: the main station (the Forge) stands against the BACK wall, centred; the Smithy Door
stands at the FRONT edge facing the camera (no front wall). Check render from the camp.gd camera with the game's
light: `Blacksmith Layout.png` (in ~/blender/out/blacksmith/). Source: `~/blender/scripts/blacksmith.py`
(`run.sh scripts/blacksmith.py` rebuilds everything).

## Props (FBX, 1 unit = 1 tile, origin at the feet, facing the camera at yaw 0, each with a looping `Idle`)

| Prop | Station | What it is | Idle | Tris |
|---|---|---|---|---|
| Forge | Modify (back wall centre) | stone forge with a glowing coal bed and small flames, an ash pit glowing under a stone arch, a stone hood on iron posts with a timber mantel and a brass smithy mark (crossed hammers over an anvil), a flue up to the wall, leather bellows on a trestle (left), an anvil on a stump in front with a glowing bar and a hammer, tongs, a poker, a coal pail | 60 f: flames flicker, coals pulse, bellows pump twice, the hammer lifts its head and taps the hot bar (frame 31) with a burst of sparks | 3190 |
| Grindstone | Upgrade | sandstone wheel on a timber trestle over a water trough, crank and foot treadle with a connecting rod, a short sword on a tool rest against the rim, a water bucket, a guardian tower miniature (cobalt band, cobalt shield) on a pedestal with three gold chevrons (rank up) | 72 f: the wheel turns one full revolution at constant speed (seamless loop), the treadle rocks with the crank, sparks fly off the blade 6 times | 2422 |
| Smithy Rack | Towers | iron frame with brass finials and a horseshoe crest with scrolls, tongs / hammer / horseshoe hanging from hooks on the top bar, a plank tool board (rasp, chisel), three iron-edged tiers of eight tower miniatures on cobalt-banded plinths, a stack of iron and brass ingots | 48 f: the hanging tools sway | 2976 |
| Smithy Door | Camp | heavy plank door with three long iron strap hinges, studs, a ring pull and a horseshoe (open end up), ajar into the hall, in a quoined stone frame with a lintel and keystone, a threshold step, a lantern on a bracket (right), a hanging shop sign with a tent painted on it (left: the way to the camp) | 48 f: lantern and sign sway | 1792 |
| Smithy Floor | decor | 14 x 10 tiles of sooty flagstones (darker than the Guild's) over a stone footing, a scorched, charred patch with coal grit and a few embers in front of the forge, an iron drain grate by the quench trough | none (static) | 10340 |
| Smithy Hall | decor | backdrop: back wall + two side walls (stone lower wall, timber frame, smoke-stained plaster), sloping down toward the open front; a tall stone chimney in the back wall centre whose stack caps the Forge's flue (glowing mouth), tool rails with tongs, hammers, sledges and horseshoes on the back and side walls, a big horseshoe, a chain hook, a stone quench trough (back left), a coal heap with a shovel (back left corner), a small smelting furnace with a glowing mouth, a crucible and ingots (back right of the forge), anvil stumps, a water barrel, barrels, sacks and a crate, four wall lanterns | furnace flame flickers, chain sways | 12722 |

## Where things go (layout.json, the Guild's schema)

Board 14 x 10 tiles; tile x 0..13 left to right, depth 0..9 front to back; Godot `position = Vector3(x, 0, -depth)`.
`kits` is kept from the placeholder (`["blacksmith", "camp", "guild"]`); every prop named in the layout is in this
folder.

- **Floor and Hall:** both have their origin at the floor's centre: place them at tile (6.5, 4.5), i.e.
  `Vector3(6.5, 0, -4.5)`, scale 1, yaw 0 (the two `decor` entries). The floor replaces the placeholder's Guild
  Floor; do not build a BoardView board. The floor's top is y = 0; its footing goes down to -0.33. The hall's walls
  stand just outside the 14 x 10 floor (x -0.9..13.9, depth up to 9.9, back wall 4.0 high, chimney stack to 4.76);
  the front is open toward the camera.
- **Centre:** empty floor (`centre.prop` = null, no station); free for a decor piece later.
- **Slots:**

| slot | tile (x, depth) | row | station | prop | scale |
|---|---|---|---|---|---|
| 0 | 6.5, 8.69 | front | Modify | Forge | 2.7 |
| 1 | 1.36, 5.94 | back | Upgrade | Grindstone | 2.8 |
| 2 | 1.6, 1.1 | front | (free) | - | - |
| 3 | 11.4, 1.1 | front | (free) | - | - |
| 4 | 11.64, 5.94 | back | Towers | Smithy Rack | 2.6 |
| 5 | 6.5, 0.28 | front | Camp | Smithy Door | 2.8 |

  Slot 0 lies in the back wall line: the Forge's back face (0.31 behind its origin, x 2.7 = 0.81) touches the wall's
  inner face at depth 9.5, and its flue (top at 4.05) runs into the hall's chimney stack. Keep the Forge at scale 2.7
  or the flue and the stack no longer meet. Row front: the Modify button goes on the floor in front of the anvil
  (the anvil's front is at depth ~6.6). Slot 5's threshold step lip sits on the floor's front edge (depth -0.5);
  make the door clickable + the "<- Camp" button bottom-left, as in the Guild. Every prop has face_yaw 0. Every pair
  of slots is at least 4.85 tiles apart (the free front slots are pulled out to the sides so they keep 4.97 from
  the door).
- **Camera / light:** the previews use camp.gd's camera (c = ring centre at `(x, 0, -(depth + 0.6))`, position
  `c + Vector3(0, 14.5, 17.0)`, `look_at(c)`, fov 34) and `TdDiorama._add_light(root, wood.900)`. The warmth comes
  from the materials (sooty stone, timber, the emissive Ember / Fire / Hearth / Holy glows in the forge, furnace,
  chimney mouth and lanterns), so no extra lights are needed. Optional: move blacksmith.gd's `EMBERS` OmniLight3D
  (placeholder at the anvil table) to the Forge's coal bed, about `Vector3(6.5, 1.4, -8.2)`, range ~4.5.

## Loading

As the placeholder: `blacksmith.gd` looks each prop up in `res://art/<kit>/<prop>.fbx` for the layout's `kits`.
Play each model's `Idle` in a loop (`TdDiorama._idle`). The Forge's and the Grindstone's sparks are built at 1 % of
their size and scaled up by bone scale keys inside the Idle (as the game's hidden effect parts), so bone scale must
import (it does for the units). The Grindstone's wheel is keyed linearly 0 -> 360 degrees; keep the clip looping.

## Adding a station

1. Put its prop FBX here (same pipeline: `~/blender/scripts/blacksmith.py`, export to `out/blacksmith/<Name>`).
2. Fill a free slot (2 or 3, the front corners) in layout.json: set `station`, `prop`, `scale` (2.4-3.2, like the
   Guild) and drop the "free slot" note; keep `face_yaw` 0. Slots never move. A shop counter would suit slot 2.
3. Add the station to blacksmith.gd's station list (id = the slot's `station`).
After both free slots: add slots on the ring at the half angles (back left/right of the centre, e.g. (3.3, 7.2)
and (9.7, 7.2)) and check they stay 4.6 tiles from their neighbours and clear of the Forge's bellows (x ~4.0).

## Colours added to the palette (td.PALETTE)

SootStone 7A6E60, SootStoneDark 685D51, SootStoneLight 8A7D6C (the floor), PlasterSoot B3A083 (the hall's plaster),
QuenchWater 46626B (trough, bucket and barrel water). Everything else reuses existing names (Rock, RockDark, Stone,
StoneLight, StoneDark, Charred, Scorched, Singed, Wood, WoodDark, Bark, Leather, Iron, Steel, SteelDark, Brass,
Bronze, Gold, Cobalt, Ember, Fire, Hearth, Holy, Spirit and the miniatures' colours).
