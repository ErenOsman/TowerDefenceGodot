# Style & Art Direction — Design

Oct 15, 2026 · Blender agent (the wiki server) for @Eren · editable master: [Claude doc](https://claude.ai/code/artifact/58fedad4-41a9-42d4-b9f1-187255b1bf85) (older, Unity-era); **this file is what the project reads.**

The game's art is **"Painted Miniatures on a Diorama Board"**: towers are chunky painted tabletop miniatures on plinths with a thin cobalt band, enemies are faceted creatures in muted colours, and every level is a diorama slab of earth cut to the grid. Everything is made by Python scripts in headless Blender (`~/blender` on the server), built from primitives, bevels and solid colours, so any model can be rebuilt or changed by editing its script.

## 1. Pillars

Every model is checked against these.

1. **One silhouette per tile.** A unit is recognisable from its top half alone, at the game camera's ~50° pitch, from all four 90° turns. Each unit has ONE signature shape that reads from above (hood + bow, wide hat brim, halo, crown, wings, antlers, hood flare…).
2. **Faceted everywhere.** Flat-shaded low-poly with small bevels (0.006–0.02) on hard edges, so shapes catch a highlight line at 60 px. Since 2026-10-09 the slimes are faceted too (the old smooth glossy jelly is gone).
3. **Calm board, readable pieces.** Ground and walls are low saturation and mid value; units carry the colour, so tile highlights (blue range, green aim, orange area, red blocked, yellow select) and HP bars always read. Colours are **muted** (user, 2026-10-09): no saturated plastic.
4. **Shared palette, no textures.** Every model uses names from one palette (section 3). New models reuse it, so the whole game stays one family.
5. **Clear beats.** Every action clip has a wind-up, one impact frame and a recovery.

User rules that override older notes:

- **No red glowing eyes on new models** (2026-10-09). Defaults: dark `Ink` eyes with a small `Ivory` glint; undead get a cold `SoulFire` light in dark sockets; snakes amber slit pupils; Basilisk and Medusa the pale `StoneGaze`; the Phoenix gold. (Older beasts and brutes still have `EnemyEye`; changing them is parked.)
- **Slimes have no mouth** (2026-10-09), except the Slime Glutton (a boss grin). Red Slime has a fuse and ember cracks.
- **No base or building has a face** (2026-10-08): the Base does not talk; dialogue uses portraits.
- **Parked idea:** the beasts' and brutes' red eyes, and any further faceting pass, wait for a decision.

## 2. Shape language

| Family | Shape rule | Team mark |
| --- | --- | --- |
| Towers: people | Chibi miniature, head ~40% of the figure, one oversized prop or hat | Round dark-wood plinth with a thin Cobalt band, plus one Cobalt cloth piece |
| Towers: engines | Squat machine on a square timber platform, one long readable axis (bow arms, barrel) | Platform with a Cobalt trim and pennant |
| Towers: spirit (Wisp) | Floating cyan flame over a small stone lantern | Plinth |
| Slimes | Faceted domes and drops, no limbs, props stuck in the body, dark eyes | — |
| Beasts, spiders | Low and long, ears / antlers / legs as the signature | — |
| Brutes | Hunched triangle: huge shoulders and arms, small head low between them | — |
| Undead | Chibi skeleton, big skull, readable ribcage, SoulFire eye lights | — |
| Serpents | S-curve or coiled body on the tile, head raised | — |
| Birds | Hover above the tile (pivot on the ground), spread wings are the signature | — |
| Bosses | Their family's shape at 1.3–1.6×, filling the tile, plus one crown-like top feature | — |
| Buildings, objects | Stone, timber, moss; neutral objects break apart when destroyed | Cobalt roofs on the player's buildings |

Cobalt is reserved for the player's side (tower bands, the Base's and Fortress's roofs). Co-op's second player colour is `Amber` (an idea, not decided).

## 3. Colour

- **Palette:** 122 named colours (sRGB hex, roughness, metallic, emission) in `~/blender/lib/td.py` (`PALETTE`), swatch sheet `~/blender/docs/palette.png`. Each FBX material is named after its palette entry, so Godot shows the same colour on every model.
- **Ground and roads:** Grass `#7D8B5C` (checker ±4% value), road Dirt `#C4A577`, walls Stone `#8E9097`, chasm Void `#17162A` with a VoidGlow rim, diorama sides Soil `#6E5038`.
- **Contrast rule:** a unit's main mass differs from the ground it stands on (towers vs Grass, enemies vs Dirt) by a luminance contrast of at least 1.5:1 (1.3 where hue already separates them).
- **Glows mean magic or life:** Fire, Ember, Hearth, Holy, Spirit, Acid, SoulFire, StoneGaze. They are emissive materials, kept small (tips, eyes, cracks), so a model never turns into a glowing blob.

## 4. Scale, pivots and budgets

One tile is 1×1 unit. A normal unit stays inside a 0.8×0.8 footprint so neighbours never touch; only bosses and buildings fill the tile.

| Class | Footprint | Height | Triangles |
| --- | --- | --- | --- |
| Small enemy | ≤0.6 | 0.25–0.45 | ≤2,500 |
| Tower (person) | plinth Ø0.72 | 0.8–0.95 | ≤3,000 (Archer 3,804) |
| Tower (engine) | 0.82 square | 0.5–0.65 | ≤3,000 |
| Big enemy | ≤0.8 | 0.5–1.05 | ≤3,500 |
| Boss / mini-boss | ≤1.0 | 0.85–1.2 | ≤5,000 |
| Building | ≤0.96 | 0.9–1.1 | ≤4,000 |
| Tile piece | exactly 1.0 | — | ≤400 |
| Hub backdrop (Guild Hall, Guild Floor) | the scene | — | one-off, up to ~10k |

- **Pivot** at the feet, centred on the tile. Models face Blender −Y, which is **Godot +Z**. Flyers keep the pivot on the ground and the body in the air.
- **Head-room** for the HP bar: nothing but a boss crown or a banner sticks up more than 0.3 above the body.
- **Corpse** (last frame of Die) stays inside the tile and ≤0.35 high, so a corpse never hides a living neighbour.
- **Attacks may reach into the next tile** at the impact frame (bites, pikes, staffs), because the target stands there.

## 5. Godot contract (what the game actually reads)

**Import.** Drop the FBX into the project; Godot imports it on the next run. No import steps, no prefabs, no material setup.

| Kind | Folder | Loaded by |
| --- | --- | --- |
| Units, towers, enemies, objects, projectiles | `art/models/<Name>.fbx` | `GameApp.model_scene` (`ArtPaths` maps the content's old view paths to it) |
| Map kit (ground, roads, walls, chasms, edges, props) | `art/tiles/<Piece>.fbx` | `BoardView` |
| Hub kits | `art/camp/`, `art/guild/` (FBX + `layout.json` + README) | `GameApp.camp_scene` and the Camp / Guild screens |

**Rig and clips** (`game/board/entity_rig.gd`, `entity_view.gd`, `td_diorama.gd`):

- One skinned mesh on one armature; Godot creates an `AnimationPlayer`. Each Blender action becomes a clip; the loader matches the last `|`-separated part of the name, so `Idle` and `<Name>|Idle` both work.
- **Clips:** `Idle` and `Walk` (looped by the loader; Walk plays while the unit moves), `Attack`, `Cast`, `Hit`, `Die` (its **last frame is the corpse**, held by `show_dead`), `Spawn`. Missing clips are skipped and the presenter falls back to a tween. Hub props only need `Idle`.
- **Impact:** the loader looks for a method-track key named `Impact` on the clip; without one it lands the impact at **50% of the clip**. Blender's FBX export cannot write method tracks, so today every clip uses the 50% fallback. The exact impact frame of every Attack and Cast (and the Red Slime's Die burst) is listed per model in `~/blender/out/manifest.json` (`clips.<Clip>.impact`, 30 fps); an import step that adds the `Impact` key from that file would make the hits land on the right frame.
- **Muzzle:** an empty named `Muzzle`, parented to the bone that carries the bow, barrel, staff head, beak or mouth, so it follows the animation. `EntityView` picks the deepest `Muzzle` node; projectiles start there (else two thirds of the way up).
- **Hitbox (optional):** a mesh named `Hitbox` is hidden and used for the HP bar's outline.
- **Hidden effect parts** (muzzle flashes, chips, web nets, fire rings, ash piles) are built at 1% size at rest and scaled up by their bone inside a clip, so bone **scale** keys must import (they do).
- **Materials:** one material per palette name, metallic/roughness/emission as in the palette; the game's hit flash uses `material_overlay`, so it keeps every material's own colour.

**Hub layout schema** (`art/camp/layout.json`, `art/guild/layout.json`): `board.tiles` [w, d] (tile x left→right, depth front→back; Godot `position = Vector3(x, 0, -depth)`), `centre`, `slots` (tile, `face_yaw`, `row` back = button above / front = button below, `station`, `prop`, `scale`), `decor`, `ring` (reference). Props face the camera (`face_yaw` 0) and keep ≥2 tiles of clear ground between stations so buttons don't overlap. The Godot side owns the Camp layout since 2026-10-13.

## 6. Animation language

All clips at 30 fps, timed to the presenters: one tile of movement takes 0.18 s (walk) or 0.35 s (jump arc).

| Clip | Length | Shape |
| --- | --- | --- |
| Idle | 48–72 f, loop | Breathing bob 2–4% + one secondary motion (cape, ears, flame, banner) |
| Walk | 12 f, loop | Two steps or hops in place; the game moves the root |
| Attack | 15–28 f | Wind-up 40–60%, a 2–3 frame strike, recovery; impact = the strike frame |
| Cast | 18–36 f | Gather (raise, glow), release, settle; impact = the release frame |
| Hit | 8–13 f | Recoil away from the front, squash, back |
| Die | 20–39 f | Topple, melt, collapse or burst, ending in the corpse pose |
| Spawn | 12–24 f | Pop, drop, rise or hatch in, with an overshoot |

Personality: towers hop like moved game pieces and attack crisply; slimes squash and stretch; beasts, spiders and birds are twitchy and quick; brutes are heavy (long wind-up, fall on their back); undead rattle and collapse into bone piles; serpents slither with a travelling wave; engines recoil; bosses run 1.3–1.5× slower and get a bigger entrance.

## 7. Environment

- **Map kit** (30 pieces, `art/tiles/`): Ground A–D, Build Ground A–B, Road End / Straight / Corner / T / Cross / Single, Wall A–B, Chasm 0–4 (incl. 2 Corner / 2 Opposite), Bridge, Board Edge Side / Corner, trees, bush, fence, signpost, Spawn Burrow, Fire Tile. Every piece is exactly 1×1, ground top at height 0, slab bottom at −0.35.
- **Sides at yaw 0** (N = Godot +Z = the board's top row, E = +X): Road End N · Straight NS · Corner NW · T NWS · Cross NESW · Single none; Chasm (sides bordering ground) 0 none · 1 N · 2 Corner NW · 2 Opposite NS · 3 NWS · 4 NESW; Bridge NS. Positive yaw turns clockwise seen from above. Each road/chasm piece also has a `sides` string in `~/blender/out/tiles/manifest.json`.
- **Hubs:** the Camp (outdoors: tent, campfire, war table, miniature shelf, codex lectern, workshop, signal post, supplies) and the Guild (indoors, warm: timber hall, hearth, banners, mission board on the back wall, co-op table, tower rack, door at the front edge, flagstone floor with a rug).
- **Menu boards:** level dioramas with a transparent background and blurred variants for loading / menu screens (`~/blender/scripts/level_render.py`, `blur_board.py`).

## 8. Roster (2026-10-15)

| Family | Models |
| --- | --- |
| Towers | Archer (remade 2026-10-08), Guardian, Mage, Priest, Wisp, Alchemist, Drummer, Ballista, Cannon; ideas: Pikeman, Princess |
| Slimes | Slime, Runner, Big Slime, Shield Slime, Slime Archer, Slime Shaman, Red Slime (explodes on death), Slime King, Slime Glutton (boss) |
| Beasts, spiders, birds | Rabbit, Jackalope, Bat, Tusker; Giant Spider, Green Giant Spider, Yellow Spider; Crow, Eagle, Phoenix (mini-boss) |
| Brutes | Brute, Ironhide, Rockjaw; idea: Strider |
| Undead | Skeleton, Skeleton Spearman, Skeleton Archer, Skeleton Mage, Skeleton Fire Mage, Lich (mini-boss), Skeleton King (boss) |
| Serpents | Snake, Cobra, Basilisk (boss), Medusa (mini-boss) |
| Buildings, objects | Base, Fortress, Rock, Rock B, Rock C, Statue (petrified knight), Statue B (praying angel) |
| Projectiles | Arrow, Ballista Bolt, Cannon Shell, Fire Orb, Acid Flask, Spit Glob, Wisp Spark |

Per-model triangles, bounds, clip lengths and impact frames: `~/blender/out/manifest.json`. Pictures (hero, game camera, animation sheets, portraits): the gallery at http://92.5.94.11/art/. Not built: the Stone Golem boss idea.

**Other renders:** UI portraits (512 px, transparent, one camera and light for all: `out/portraits/`), hand-tray miniatures (towers on their plinths, 256 / 512 px, one shared scale: `out/miniatures_*`).

## 9. Making and checking a model

- One script per model, `~/blender/scripts/<name>.py`, run with `~/blender/run.sh scripts/<name>.py`. Family kits in `~/blender/lib/` (towers, slimes, beasts, brutes, skeletons, serpents, spiders, birds, objects, map kit, camp, guild). Builder brief: `~/blender/docs/BRIEF.md`.
- Every export fixes normals (closed parts outward, thin parts two-sided, because Godot culls back faces), keeps living units above the board, and writes the manifest entry.
- Checks before a delivery: `scripts/lint.py` (normals, open parts, weights, palette, loops, pops, ground, corpse, impact), `scripts/audit.py` (how deep parts sink into each other per frame), and close-ups (`scripts/closeups.py "Name@Clip@frame"`) looked at from several angles, because the audit skips overlaps between parts on the same bone.

## Changelog

| Date | Change |
| --- | --- |
| 2026-10-15 | Moved to the Godot repo as Markdown and rewritten for Godot: import, clip/Impact/Muzzle contract as the loader reads it, folders, hub layouts. Brought up to date: faceted slimes, no red eyes, no faces on buildings, the roster since 2026-10-07 (undead, serpents, spiders, birds, statues, Red Slime, Princess, Guild) |
| 2026-10-07 | First version (Unity era): style chosen, palette, shape language, animation contract, map kit, 26 models |
