# Guild kit (Blender, 2026-10-14)

The Guild (Missions & Guild — Design, section "The Guild") as a small 3D diorama, shown like the Camp
(`game/ui/screens/camp.gd`): a warm, timber-framed guild hall interior with the stations on a ring round the
Mission Board. Check render from the camp.gd camera: `Guild Layout.png` (in ~/blender/out/guild/).
Source: `~/blender/scripts/guild.py` (`run.sh scripts/guild.py` rebuilds everything).

## Props (FBX, 1 unit = 1 tile, origin at the feet, facing the camera at yaw 0, each with a looping `Idle`)

| Prop | Station | What it is | Idle | Tris |
|---|---|---|---|---|
| Mission Board | Missions (centre) | big notice board on two posts under a little wine-red roof, a guild crest on the ridge, pinned mission cards with ink lines and red wax seals, a quest map, a hanging lantern, a bucket of scrolls | lantern sways | 1602 |
| Coop Table | Multiplayer | round tavern table, 2 chairs + 2 stools, mugs, dice cup and dice, two crossed pennants in Cobalt and Amber (co-op) | pennants flutter | 1600 |
| Tower Rack | Towers | tall weapon rack (bow, sword, mage staff with a spirit orb) over three display tiers of tower miniatures on cobalt-banded plinths, a gold cup | orb pulses | 2090 |
| Guild Door | Camp | arched stone doorway with a double door, the right leaf ajar onto daylight (the way out to the camp), a lantern, an arrow sign with a tent painted on it | lantern sways | 1600 |
| Guild Floor | decor | 14 x 10 tiles of warm flagstones over a stone footing, a wine rug with an ochre border under the Mission Board | none (static) | 9776 |
| Guild Hall | decor | backdrop: back wall + two side walls (stone footing, timber frame, plaster), sloping down toward the open front, a hearth with fire (back left), 3 wine banners, a crest with crossed swords, wall lanterns, a window, barrels and crates | fire flickers, banners sway | 5526 |

## Where things go (layout.json, the Camp's schema)

Board 14 x 10 tiles; tile x 0..13 left to right, depth 0..9 front to back; Godot `position = Vector3(x, 0, -depth)`.

- **Floor and Hall:** both have their origin at the floor's centre: place them at tile (6.5, 4.5), i.e.
  `Vector3(6.5, 0, -4.5)`, scale 1, yaw 0 (the two `decor` entries). The floor replaces the Camp's BoardView
  map-kit ground: do not build a BoardView board for the Guild. The floor's top is y = 0 (rug +0.03); its
  footing goes down to -0.33. The hall's walls stand just outside the 14 x 10 floor (x -0.9..13.9, depth up to 9.9,
  4.55 high); the front is open toward the camera.
- **Centre:** Mission Board at (6.5, 4.5), scale 2.6. Unlike the Camp's campfire, the centre IS a station:
  `centre.station = "Missions"` with `row: "front"` (its button goes below it, because the Guild Door stands right
  behind it on screen). A screen copied from camp.gd needs one extra line: treat `centre` like a slot when it has
  a `station`.
- **Ring:** ellipse centre (6.5, 4.5), radii 5.4 x 4.65, 5 slots at 90 + k*72 degrees:

| slot | tile (x, depth) | row | station | prop | scale |
|---|---|---|---|---|---|
| centre | 6.5, 4.5 | front | Missions | Mission Board | 2.6 |
| 0 | 6.5, 9.15 | back | Camp | Guild Door | 2.8 |
| 1 | 1.36, 5.94 | back | Multiplayer | Coop Table | 3.0 |
| 2 | 3.33, 0.74 | front | (free) | - | - |
| 3 | 9.67, 0.74 | front | (free) | - | - |
| 4 | 11.64, 5.94 | back | Towers | Tower Rack | 2.6 |

  Slot 0 lies in the back wall line: the door's back face (0.36 behind its origin at scale 2.8) touches the wall.
  Every prop has face_yaw 0. Stations are at least 4.6 tiles apart, so their buttons do not overlap.
- **Camera / light:** the previews use camp.gd's camera (c = ring centre at `(x, 0, -(depth + 0.6))`, position
  `c + Vector3(0, 14.5, 17.0)`, `look_at(c)`, fov 34) and `TdDiorama._add_light(root, wood.900)`. The warmth
  comes from the materials (flagstone, plaster, wine, the emissive Hearth/Fire/Holy glows), so no extra lights are
  needed. Optional: an `OmniLight3D` (warm, `FFB24A`) in the hearth at tile (3.1, 8.75), height 0.5, range ~4.

## Loading

The props are loaded like the Camp's (`GameApp.camp_scene` reads `res://art/camp/`); the Guild needs the same
lookup on `res://art/guild/<prop>.fbx`. Play each model's `Idle` in a loop (`TdDiorama._idle`).

## Adding a station

1. Put its prop FBX here (same pipeline: `~/blender/scripts/guild.py`, export to `out/guild/<Name>`).
2. Fill a free slot (2 or 3, the front corners of the ring) in layout.json: set `station`, `prop`, `scale`
   (2.4–3.4, like the Camp) and drop the "free slot" note; keep `face_yaw` 0. Slots never move.
3. Add the station to the screen's station list (id = the slot's `station`).
After both free slots: add slots on the ring at the half angles (e.g. 126 and 54 degrees, back left/right of the
centre) and check they stay 2+ tiles from their neighbours; the back wall art keeps its centre free for the door.

## Colours added to the palette (td.PALETTE)

Flagstone A8937A, FlagstoneDark 937F67, FlagstoneLight B9A68A, Plaster D8C4A2, Wine 8C3833, WineDark 652A2B,
Daylight D2E3EE (emission 0.8: the doorway and the window).
