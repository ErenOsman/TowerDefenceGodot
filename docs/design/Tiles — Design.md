# Tiles — Design

Status: **steps 1–3 and 5 of the build plan are built** (terrain and the live map; the map as layers; changing tiles, 2026-10-05; the visual and props layers, 2026-10-09), in the Godot build too (Godot pass 2026-10-15). The presentation of a changing tile (step 4) is not. How a level's map is described, stored and changed. The map is three text layers (terrain, build, road) instead of one mixed map text, and it is part of the battle state instead of a fixed backdrop. Units, waves and everything else in a level stay as they are.

## Why change it

Today a level has two separate descriptions of its ground:

- **Map text:** rows of characters (`.` ground, `+` buildable, `#` wall, `~` chasm). The five kinds are hard-coded (`TileType`).
- **Paths:** each road is a list of tiles in walking order, written separately. In the JSON that is one line per tile (the Drummer's two roads take 34 lines), and which way a road turns at a tile is never written down, only implied by its neighbours.

The map is also **fixed during a battle** (`BattleGrid` is shared by every state copy), so nothing can change the ground: a chasm cannot be filled, a bridge cannot collapse, a wall cannot be broken.

Chapter 2 already pushed against this: "a road across a chasm" is a special case (flyers only, checked by Validate All), and rocks on a road had to be units.

## Goals

1. **Every tile has its terrain, whether towers may be built on it, and the road drawn on it** (the sides it joins), each kept in its own layer. The enemy routes (paths) are kept separately, as tiles in walking order.
2. **Terrain is data**, like every other kind of content: ground, wall, chasm, and new ones (bridge, water, rubble…) without code.
3. **The map can change at runtime.** Abilities and level events change a tile's terrain: a chasm becomes solid ground, a bridge falls into a chasm, a wall crumbles.
4. **Readable, short JSON.** A person or an AI can read a level and edit it by hand (AGENTS Rule 15).
5. **Rules and looks stay apart.** Terrain says what the rules need; the tile's art is a view that follows it.

## The model

### Terrain (a content type)

A **Terrain** entry (`data/content/Terrains.json`, keys `Terrain/<Name>`) says what a tile does for the rules.

| Field | Meaning | Ground | Wall | Chasm |
| --- | --- | --- | --- | --- |
| `id`, `displayName`, `description` | As every content asset | ground | wall | chasm |
| `stand` | Who may stand and walk here: Everyone, Flyers, Nobody | Everyone | Nobody | Flyers |
| `blocksProjectiles` | Straight shots stop here | no | yes | no |
| `blocksSight` | Line of sight stops here (patterns that need it) | no | yes | no |
| `tags` | For conditions and abilities (`Solid`, `Liquid`…) | Solid | Solid | — |
| `whenUnstandable` | What happens to a unit standing here when the tile becomes this terrain and the unit cannot stand on it: **Die** (default) or **Push** (to the nearest tile it can stand on) | Die | Push | Die |
| `view` | The tile's look (a model or material path); art only | | | |

The three above ship as the built-in terrains, so existing rules keep their meaning. New terrains are new entries; for example, a **Bridge** is Everyone + no projectile block, looking like planks over a chasm.

### Tile

Every tile of the map has three things, each stored in its own text layer (see Storage):

- **Terrain:** a Terrain asset (Ground, Wall, Chasm, or another), written as a character named in the level's terrain keys.
- **Build:** whether towers may be placed here. This is a flag, not a terrain, so filling a chasm does not decide building. The rule stays the same: when a level marks any build tiles, towers are placed only on them.
- **Road:** the sides the road joins on this tile, drawn as a box character: `─` left–right, `┘` left–up, `┬` three ways, `┼` four ways or a crossing, `╴ ╶ ╵ ╷` a road ending in the middle, `•` a road of one tile. A road can start on any tile, the middle of the map included.

The road layer is the picture of the road: the presentation draws it, and the Level Editor shows it. It does not order anything; who walks where is the paths' job.

### Paths

The enemy routes are separate from the tiles: each path is its tiles in walking order, `Path 1: [0, 2], [1, 2], [2, 2]…`.

- **A path runs along the road.** Each step between neighbouring tiles must be joined by the road layer on both tiles (Validate All checks it). The Level Editor redraws the road layer from the paths as you draw them.
- **Gaps:** two tiles in a row that do not touch are a gap, which walking cannot cross (only jumps and flyers).
- **Branches** are separate paths that share their first tiles. **Crossings** are paths through the same tile. Waves name paths by number.
- **Loops:** a path may pass through a tile it already went through (it circles and crosses itself); that tile's road joins all the sides used (`┼` where it crosses straight). See Loops below.
- **A path need not end at a base.** An enemy at the end of its path stays there, and keeps using its other abilities.

### Loops

Today the engine works out how far an enemy has got from the tile it stands on (`PathDef.IndexOf(Pos)`: `PathProgress`, `PathAhead`, the aim preview, route building and spawning all do this). On a looping road that tile appears twice, so the answer would be wrong.

- **Each unit on a road remembers its step:** `Entity.PathStep`, the index of its tile in the road's tile list. It is set when the unit spawns or is placed on the road, and moves with every road walk, jump or push along the road.
- **Everything that asked "where am I on the road" reads the step instead:** `PathProgress` is `PathStep`, and `PathAhead` counts from it. The tile alone only answers "which roads pass here".
- **Every move:** after any move (a walk step, a jump, a teleport, a push), the unit's step becomes the visit of its new tile nearest its old step. On a tie, the later visit wins. Walking forward from step 5 onto a tile visited at steps 2 and 6 gives 6.
- **Blocking on the shared tile:** a unit on a crossing blocks every road passing through it, as now, including the same road's other visit. An enemy that reaches the crossing on its second pass waits like at any crossing.
- **Spawning:** a spawn on a looping road starts at step 0. "Nearest free road tile" counts in steps, not in tiles.

A path does not decide who may walk it; the terrain under each tile does. A path across a chasm is walkable by flyers only, because chasm is Flyers. Once the chasm is filled, walkers can walk it too, so the Chapter 2 special case goes away.

### The map in the battle state

The map moves into `GameState`. A copy of the state copies the terrain changes, so the level playtester's undo and the Director's frames see them. Every rule that reads the ground reads the live map: movement, standing, projectiles, sight, aim previews, Instinct and Validate All's road checks.

## Changing tiles at runtime

### Change Terrain step

A **Change Terrain** step (an ability step) sets the terrain of tiles:

- **`terrain`:** the Terrain asset to set (e.g. Ground).
- **`on`:** the tiles. Either the aimed tile, or the step's area (a pattern around the aim, like Attack's area).
- **`only`:** an optional condition on the old terrain, so only matching tiles change. For example, `Tile.HasTag(Liquid)`, or the old terrain is Chasm. This makes "fill every chasm tile in a 3×3" one step.
- **`build`:** optionally switches build on or off for those tiles.

Each changed tile writes a **TileChanged** event: tile, old terrain, new terrain, and the source as usual.

### Change Terrain level event

A **Change Terrain** LevelEvent kind does the same on a schedule: the listed tiles, in a round of a wave. For example, "round 3: the bridge falls", or "wave 2 start: the chasm crust hardens".

### Units on a tile that changes

| The tile becomes… | A unit standing on it… |
| --- | --- |
| Still standable for it (e.g. chasm → ground, ground → bridge) | Stays; nothing happens |
| Not standable for it (ground → chasm for a walker, anything → wall) | The new terrain's `whenUnstandable` decides. **Die** (the default): the unit dies with the tag `Fell`; there is no corpse over a chasm. **Push**: the unit moves to the nearest tile it can stand on (a road unit to the nearest free tile of its road, ahead first); if there is none, it dies. Flyers over a new chasm stay |

### Reading tiles in formulas and conditions

These are new vocabulary entries in `CombatVocabulary`:

- `Tile.Terrain` and `Tile.HasTag(X)`: the tile a step or pattern is looking at (the aimed tile, or an area tile).
- `Self.OnTerrain(Chasm)` and `Target.OnTerrain(Chasm)`: the terrain under a unit.

A reaction trigger **OnTileChanged** (facts: the tile, the old and new terrain id) lets passives respond, e.g. a tower that gains Power when a chasm is filled next to it.

### Presentation

The Director plays TileChanged like any event. The tile's view swaps to the new terrain's view with a short beat (crumble, fill), and road pieces on it stay. Units that fall play their death with the `Fell` tag (a drop instead of the usual death).

## Look: the visual and props layers

The rules read only terrain, build and road. What a tile **looks like** is separate, so art can change without touching the rules. Decided 2026-10-09 (Eren): the look is **automatic** from terrain, build and road, and a level overrides it **by hand** where it wants something else. There are **two layers**: `visual` (the ground piece of each tile) and `props` (things standing on it: trees, bushes, fences, signposts).

### Tile (a content type)

A **Tile** entry (`data/content/Tiles.json`, keys `Tile/<Name>`) is one piece of the map kit.

| Field | Meaning |
| --- | --- |
| `id` | What the layers write: letters, digits and `_` only (`ground_a`, `road_corner`, `tree_pine`) |
| `view` | The map-kit model (`art/tiles/<Piece>.fbx`, through `ArtPaths`) |
| `layer` | Ground (a `visual` piece) or Prop (a `props` piece) |
| `sides` | At its default facing, the sides that matter for fitting, as letters of `NESW`: the sides a road piece joins (`NS` straight, `NE` corner, `NES` T, `NESW` cross, `N` end, empty single), or the sides an edge piece borders another terrain (a chasm's rim). Empty for plain pieces |

A piece's **default facing** is north (`N`, toward the top row). `<id>-<direction>` turns it: `road_corner-E` is the corner turned a quarter clockwise, `-S` half, `-W` three quarters. `<id>` alone is the default facing.

### Automatic look

Each tile gets, unless a layer overrides it:

1. **On a road over ground walkers stand on:** a road piece from Game Rules' tiles (kind Road), the one whose `sides` match the road layer's joined sides, turned to fit. A road over a chasm (a flyers' route) shows just the chasm, no bridge (Eren, 2026-10-09).
2. **Bordering other terrain** when its terrain has `edgeTiles` (a chasm's rim): the edge piece whose `sides` match the sides that border another terrain, turned to fit.
3. **A build tile:** one of its terrain's `buildTiles`.
4. **Otherwise:** one of its terrain's `tiles`.

Where a terrain has several variants (Ground A–D), the choice is a fixed hash of the tile's position, so a level always looks the same. Terrain's `view` is replaced by `tiles`, `buildTiles` and `edgeTiles`. Props are never automatic.

**The frame** is automatic: the map's outer tiles get the kit's Border pieces (`board_edge_side`, `board_edge_corner`: thin skins of the slab's cut side, grass lip and soil layers, on their tile's outer edge, drawn over the ground piece), each facing out; a corner tile gets only the corner piece. A Border piece's `sides` are the sides it faces out at its default facing (`N` for a side, `NW` for a corner), so `TileLook.Frame` turns it like a road piece. Levels never paint it.

### The layers

Both have the map's size, one row of cells per map row, top row first, **cells separated by spaces**:

```json
"visual": [
  ". . . . . . bridge-E . .",
  ". . . . . . . . ."
],
"props": [
  "tree_pine . . . bush . . . tree_round-W",
  ". . . . . . . . ."
]
```

- `visual`: `.` means automatic; an id (with an optional direction) overrides the tile's ground piece.
- `props`: `.` means nothing; an id puts that prop on the tile. Props are looks only: they never block or hide anything (a rule-relevant thing is a terrain or a unit).

## Storage (level JSON)

Three text layers of the same size, one character per tile, top row first, then the paths. The Drummer:

```json
"terrain": [
  "..............",
  "..............",
  "..............",
  "......##......",
  "......##......",
  "......##......",
  "~~~~~~~~~~~~~~",
  "~~~~~~~~~~~~~~"
],
"terrainKeys": [
  { "symbol": ".", "terrain": "Terrain/Ground" },
  { "symbol": "#", "terrain": "Terrain/Wall" },
  { "symbol": "~", "terrain": "Terrain/Chasm" }
],
"build": [
  "........+++++.",
  "........++.++.",
  "..............",
  "...+++..+++++.",
  "...+++..+++++.",
  "...+++..+++++.",
  "..............",
  ".............."
],
"road": [
  "..............",
  "..............",
  "..┌──────────┐",
  "..│..........│",
  "..│..........╵",
  "──┘...........",
  ".............╷",
  "─────────────┘"
],
"paths": [
  { "tiles": [
    [0, 2], [1, 2], [2, 2], [2, 3], [2, 4], [2, 5], [3, 5], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5],
    [9, 5], [10, 5], [11, 5], [12, 5], [13, 5], [13, 4], [13, 3]
  ] },
  …
]
```

- **Terrain:** any character, named in `terrainKeys` (`.` `#` `~` by convention for Ground, Wall and Chasm). A new terrain gets its own character, e.g. `{ "symbol": "=", "terrain": "Terrain/Bridge" }`. The terrain layer's rows set the map's size; the other layers match it.
- **Build:** `+` where towers may be placed, `.` elsewhere.
- **Road:** box characters as above, `.` for no road.
- **Paths:** tile lists, several positions to a line. The order cannot be drawn in a grid (loops, branches), so paths stay lists.
- `python3 tools/content_format.py` writes hand-edited files in the content layout (docs/CONTENT.md "Layout").

## Level Editor

The Level Editor was a Unity editor window; the Godot build has none yet, and levels are edited as JSON (by hand or in the wiki Content Editor, whose Check plays the level). The design stays for a future editor:

- **Terrain tool:** pick any Terrain asset and paint it; a terrain the level has not used yet gets a character in `terrainKeys` (its first letter, or a free one). **Build tool:** click or drag to switch building on or off.
- **Path tool:** click or drag tiles in walking order. A path may cross itself; dragging back or right-click removes the last tile; a click away from the end leaves a gap. The road layer follows the paths ("Road from paths" redraws it).
- **Tile info on hover:** terrain (and its character), build, the road's sides, the path steps on it, a base or starting units.
- **Change Terrain events** (step 3): shown on the map for the selected wave and round.
- **Visual and Props tools** (step 5): pick a Tile and paint it (right-click clears back to automatic / nothing); a key turns the piece a quarter. The map shows the automatic look under the overrides.

## Validate All

- The three layers have the same size; every terrain character is named in `terrainKeys` (one character each, a Terrain asset each); the build layer has only `+` and `.`; the road layer only road characters.
- A build tile must be terrain everyone stands on.
- Every step of a path between neighbours is joined by the road layer on both tiles. A path never turns straight back onto the tile it just left; loops must go round.
- A path over terrain walkers cannot stand on: only flying enemies may be sent along it.
- Change Terrain events and steps name a Terrain (step 3).
- `visual` and `props`, when present, have the map's size; every cell is `.` or a Tile id (with an optional `-N`, `-E`, `-S` or `-W`); a `visual` cell names a Ground tile and a `props` cell a Prop tile.
- The automatic look finds a piece for every tile: each road shape has a road tile, each terrain used has `tiles`. A missing piece is a warning (the board shows the terrain's colour there).

## Migration

Breaking changes are fine before 1.0. One-off converters rewrote the levels file (then Unity's `Content/Levels.json`). The first went from the old map text to a record per tile; the second went from that to the three layers. The road layer was drawn from the paths, and a path whose first tile is on the map's edge comes in from that edge. Validate All, the tests and the reference pages gave the same results as before.

## What stays the same

- The grid: 1×1 entities, x right, y up, (0, 0) bottom-left; four-direction movement.
- Enemies follow their path, cannot pass the unit ahead, and spawn on the nearest free tile of their path.
- Towers stand off roads; build tiles limit placement only.
- Rocks and other breakable obstacles stay units (they have HP). Terrain has no HP: a wall "breaks" because something changes its terrain.

## Open questions

1. **Switching roads (later).** Branches are separate roads chosen at spawn (decided). Some enemies may later change roads: a Switch Road step that moves the unit onto another road through its tile (at a shared tile, a fork or a crossing), its step set to that road's visit of the tile. Not designed yet.
2. **Changing roads at runtime (maybe).** Roads may change during a battle too: a road part opens when a gate breaks, or a road is replaced. This is not designed yet. The model keeps the roads in the battle state next to the terrain, so a Change Road step or level event can be added without changing the format.

## Build plan

1. **Terrain assets and the live map** (built 2026-10-05). The Terrain type, and the map in `GameState`, with every rule reading it.
2. **The map as layers** (built 2026-10-05). Levels keep terrain, build and road as text layers, and their paths as tile lists. Ground, Wall and Chasm became Terrain entries. Units keep their own path step (`Entity.path_step`), so paths can loop. A converter rewrote every level. Tested: a looping path (walking, blocking at its crossing), the layers and the road drawn from paths.
3. **Changing tiles** (built 2026-10-05). The Change Terrain step and level event, the TileChanged event and the OnTileChanged trigger (facts X, Y), falling (Fell) and pushing, `OnTerrain` / `OnTerrainTag`, and tests. Differences from this doc are in the Implementation Notes (docs/archive): `onlyOn` terrain names instead of a condition, and no `Tile.` subject in formulas.
4. **Presentation.** Terrain views, road pieces from the links, the change beat, and the fall death. Not built: the board (`BoardView`) is built once from the map and does not redraw a changed tile.
5. **Visual and props layers** (built 2026-10-09; the board's frame is automatic too, 2026-10-10: Border pieces on the map's outer tiles). The Tile type, the two layers, the automatic look (`roadTiles`, terrain `tiles` / `buildTiles` / `edgeTiles`, `TileLook`), validation, the kit's pieces as Tile entries, and the board built from map-kit pieces (`game/board/board_view.gd`; a tile without a piece gets a placeholder block).

The sim parts (steps 1–3, the data of step 5) are the C# port in `sim/`; the board is `BoardView`. History: in the Unity project the Level Editor window painted the layers, drew paths and had the Visual and Props tools (step 5); it did not show Change Terrain events on the map yet.

## Decisions

| Date | Decision |
| --- | --- |
| 2026-10-09 | A road over a chasm shows the chasm, not a road or a bridge: road pieces only on ground walkers stand on |
| 2026-10-09 | The map gets a look of its own: a `visual` layer (ground pieces) and a `props` layer (trees, bushes…), cells as Tile ids separated by spaces, `<id>-<N/E/S/W>` for a turned piece (the id alone is its default facing). The look is automatic from terrain, build and road; the layers override it by hand (`.` = automatic / nothing). Props are looks only |
| 2026-10-05 | Built step 3. The Change Terrain step limits itself with `onlyOn` (terrain names), since formulas have no tile subject. Falling is a death at HP 0 tagged Fell, credited to whoever changed the tile |
| 2026-10-05 | The per-tile records were too large (130 lines a level), so the map went back to text, as one layer per kind: terrain (with terrain keys), build, and road (box characters for the sides joined). Paths stay tile lists |
| 2026-10-05 | Step 2 redone as the user meant it: the map lists every tile (terrain, build, road pieces as joined sides), and paths stay tile lists in walking order. The first version (a start plus R/L/U/D moves, map text) is gone. Small JSON objects and tile positions are written compactly |
| 2026-10-05 | Units keep `PathStep`; after a move their step is the visit of the new tile nearest the old step |
| 2026-10-05 | A unit on a tile that becomes unstandable for it dies by default; the terrain can push it instead (`whenUnstandable`). Waves keep naming roads by number. Terrain has no rules of its own beyond standing, shots and sight (no slowing water, no burning lava for now). Terrains get no Codex entries. A road need not end at a base: an enemy at its end stays and keeps acting. Roads may later change at runtime (not designed yet). Branches stay separate roads chosen at spawn; some enemies may switch roads later |
| 2026-10-05 | Roads may loop through a tile they already passed; units remember their step on the road (`PathStep`) instead of looking it up from their tile |
| 2026-10-05 | First draft: terrain as content (stand / projectiles / sight / tags / view), build as a per-tile flag, roads as start + moves (entering from outside the map allowed), the map in the battle state, Change Terrain step and level event, falling by default. 7 questions open |
