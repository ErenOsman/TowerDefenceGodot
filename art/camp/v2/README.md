# Camp v2 kit (Blender, 2026-10-17)

The Camp redesigned as a small outdoor **settlement** (Camp & Chapters — Design, section "Camp v2 — a settlement with
the Guild and the Smithy"). The Smithy and the Guild hall stand at the back as buildings with doors; the smaller
stations stay props. Check renders from the camp.gd camera with the game light: `Camp v2 Layout.png` (both buildings
open) and `Camp v2 Layout Closed.png` (both closed), in ~/blender/out/camp_v2/.
Source: `~/blender/scripts/camp_v2.py` (`run.sh scripts/camp_v2.py` rebuilds everything).

## Props (FBX, 1 unit = 1 tile at scale 1, origin at the feet, centred, facing the camera at yaw 0)

| Prop | Use | What it is | Idle | Tris |
|---|---|---|---|---|
| Smithy Facade Open | station Blacksmith (after Chapter 2) | stone ground storey, sooty timber + plaster upper storey, slate roof, a tall forge chimney at the left end with a glowing vent at its foot, an iron-strapped door swung open onto the forge's warm glow (light spilling over the step), lit windows, lit lantern, quench barrel, anvil on a stump, a hanging anvil-and-hammer sign | smoke puffs rise from the chimney, swell and thin away (7-puff loop, 72 f); lantern and sign sway | 4496 |
| Smithy Facade Closed | the same slot before Chapter 2 | the same building: door shut and barred, dark windows, unlit lantern, no smoke, no glow | the sign sways a little (72 f) | 3994 |
| Guild Hall Facade Open | station Guild (after Chapter 2) | stone footing, timber frame and cream plaster, wine roof, a gable with the guild crest (gold-rimmed wine shield, crossed swords, gold tower), two wine banners, the plaque with the tower over the door, a big arched door with both leaves open onto the hall's warm light and wine rug, lit windows with flower boxes, a hearth chimney, a bench, a barrel, a lantern, the flag on a pole at the gable's tip | the flag sways and its swallow tail folds (48 f); lantern sways | 3216 |
| Guild Hall Facade Closed | the same slot before Chapter 2 | the same building: doors shut and barred, dark windows, unlit lantern | the flag sways (48 f) | 3172 |
| Hills Backdrop | decor, back edge | low faceted hills (14 tiles wide) with a small wood of map-kit trees (Tree Pine / Tree Round / Bush style) between the buildings, trees in the back corners, bushes behind the buildings, a few stones | static | 8416 |
| Camp Trees | decor, side edges | a narrow clump of map-kit trees (pine, round tree, two bushes, a stone), about 1.3 x 2.5 tiles, 2.3 high | static | 1896 |
| Camp Paths | decor, ground | beaten-earth stepping patches (top 0.012) joining both doors, the campfire and the front stations, crossing the camp from edge to edge | static | 2252 |

Facade rest bounds (unscaled; x 2.8 in the camp): Smithy x -0.77..0.78, depth (Blender y) -0.53..0.51, height
1.55 (about 4.3 x 2.9 tiles, 4.35 high; the chimney is the top; the smoke rises about 1.6 tiles above it while the
Idle plays). Guild hall x -0.75..0.75, y -0.52..0.44, height 1.85 with the flag (4.2 x 2.7 tiles, 5.2 high, the
ridge at 3.9). **Open and Closed of a building share pivot, footprint, rest bounds and scale**: the smoke puffs are
built at 1% size inside the chimney mouth and only grow during the Idle (the hidden-part scale trick, so bone scale
keys must import), and the glow spill stays inside the closed state's box.

No Impact events: these are hub props, with an Idle only.

## Where things go (layout.json, the Guild / Blacksmith schema)

Board 14 x 10 tiles; tile x 0..13 left to right, depth 0..9 front to back; Godot `position = Vector3(x, 0, -depth)`.
Ground: the map kit (BoardView ground pieces + frame), as the v1 Camp. `kits`: a prop name is looked up in
`res://art/camp/v2/`, then `res://art/camp/`, then the map-kit tiles (Signpost).

| slot | tile (x, depth) | row | station | prop (open / closed) | scale |
|---|---|---|---|---|---|
| 0 | 2.6, 7.65 | front | Blacksmith | Smithy Facade Open / Smithy Facade Closed | 2.8 |
| 1 | 10.6, 7.65 | front | Guild | Guild Hall Facade Open / Guild Hall Facade Closed | 2.8 |
| 2 | 2.1, 1.9 | front | Chapters (primary) | War Table | 3.2 |
| 3 | 6.9, 1.5 | front | Codex | Codex Lectern | 3.2 |
| 4 | 11.5, 1.9 | front | Towers | Miniature Shelf | 3.0 |
| centre | 6.3, 4.85 | - | none | Campfire | 3.0 |

Decor: Camp Paths (6.5, 4.5) scale 1; Hills Backdrop (6.5, 8.9) scale 1 (covers x -0.5..13.5, depth 7.4..9.5, up to
4.3 high with the trees); Camp Trees (0.15, 7.75) yaw 0 beside the Smithy and (12.85, 7.75) yaw 180 beside the Guild
hall; Tent (6.6, 6.5) scale 2.4 in the middle, between the buildings, the campfire before its door; Signpost
(art/tiles/Signpost.fbx) (8.35, 6.35) scale 2.4 by the Guild hall's door. Everything stands on the board.

- **Station ids:** Chapters, Towers, Codex as before; `Workshop` becomes **Blacksmith** (the Smithy); Guild moves
  from the Signpost to the Guild hall. The sides match the slides: the Blacksmith comes in from the left, the Guild
  from the right.
- **Spacing:** every pair of stations is at least **4.62** tiles apart (Codex-Towers; `min_distance` in the file).
- **Buttons:** every station is `row: "front"`: its button goes on the floor in front of the prop / door, no
  sub-lines. Checked with an emulation of `TdStationWorld.place_buttons` (1920 x 1080 canvas, 236 x 60 buttons):
  all five buttons get their front spot, open and closed (`_check/Camp v2 Layout Buttons.png`). Camp Paths spans
  more than half the screen, so the rule treats it as ground (like a floor) and it never blocks a button. Keep the
  Tent off the strip below the Guild hall's door: it took the Guild button's spot when it stood there.
- **Camera / light:** camp.gd's camera (c = ring centre (6.5, 5.0) at `(x, 0, -(depth + 0.6))`, position
  `c + Vector3(0, 14.5, 17.0)`, `look_at(c)`, fov 34) and `TdDiorama._add_light`. The ring centre moved from
  (6.5, 4.6) to (6.5, 5.0), so the chimney smoke stays in the frame; the ring is only the camera target now.

## The open / closed swap (before / after Chapter 2)

Slots 0 and 1 carry `"prop"` (open), `"prop_closed"` (closed) and `"unlock": "guildUnlock"`.

- **Before Chapter 2's last level is won:** load `prop_closed`: no button, no hotspot, nothing in the tour.
- **After it:** load `prop` at the same tile, scale and yaw (same pivot and bounds: swap the node in place, e.g.
  replace the child when the unlock happens while the Camp is open, or just pick the variant on build). Show the
  station button and make the door a hotspot; the mini tour points at the Guild, then the Blacksmith, once.
- **Door hotspot:** `"hotspot": "door"`, and `door.centre_local` / `door.size_local` give the doorway in Godot
  prop-local units (x right, y up, z toward the camera; multiply by `scale`): Smithy centre (0, 0.235, 0.33), size
  0.34 x 0.47; Guild hall centre (0, 0.245, 0.38), size 0.32 x 0.49. Projecting that rect gives a tight hotspot; the
  whole prop rect works too.
- Optional warmth for the open state: an `OmniLight3D` (warm, `FFB24A`, range ~2.5) just inside each doorway.

## Adding a station

1. Build its prop in the same pipeline (a new function in `~/blender/scripts/camp_v2.py`, export to
   `out/camp_v2/<Name>`), or reuse a prop from `art/camp/`.
2. Add a slot to layout.json: `tile`, `station`, `prop`, `scale` (2.4 to 3.4, like the Camp), `face_yaw` 0,
   `row` "front". Free ground: the left and right middle (around (1.0, 4.5) and (12.3, 4.4)); keep it 4.6+ tiles
   from every other station and off the strips just below the two doors (their buttons go there).
3. Add the station to camp.gd's `STATIONS` (id = the slot's `station`) and re-check the buttons in the running game.
A building station follows the facades: two FBX states with the same bounds, `prop` + `prop_closed`.

## Colours added to the palette (td.PALETTE)

Slate 5B5F68, SlateDark 484B53 (smithy roof), Smoke BDB6AC, SmokeDark 9A948C (chimney smoke), WindowLit F5C46A
(emission 1.6: lit windows, the Guild hall's interior glow), WindowDark 2C303A (dark windows, unlit lantern glass),
GlowSpill E8A65A (emission 0.35: warm light on the floor inside and in front of an open door).
