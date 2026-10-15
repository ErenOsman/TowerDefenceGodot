# VFX kit — particle effects for the tower defence (Painted Miniatures style)

Built-in render pipeline, Unity Particle System (Shuriken), unlit legacy particle shaders. 43 effects: 25 ability
effects (cast / impact / hit), 11 status loops, 3 generic (spawn, death, collision) and 7 projectile trails.
Preview (browser approximation): http://92.5.94.11/art/vfx/

## Install (Unity side)

1. Unzip `kit.zip` into the project root. It adds `Assets/Art/VFX/Kit/Sprites/*.png` (16 particle sprites) and
   `Assets/Editor/VfxKit/` (VfxKitBuilder.cs, VfxKitTypes.cs, VfxKitData.cs). Let Unity compile.
2. **Tools > VFX Kit > 1 Build Prefabs** — sets the sprite import settings, makes one material per sprite and blend
   mode in `Assets/Art/VFX/Kit/Materials/`, and builds `Assets/Art/VFX/Kit/<Effect>.prefab` (one child Particle
   System per layer). Rebuilding writes the same files, so GUIDs and references survive.
3. **2 Wire Abilities** — for every ability in the map (Shoot, Bolt, Bombard, Smash, Slam, Crush, Ram, Bash, Bite,
   Nibble, Firebolt, Spark, Smite, Acid Flask, Spit, Mend, Slime Mend, Rally, Quicken, Guardian Taunt, Blink, Hop and
   the Examples) sets castVfx / impactVfx / hitVfx and cameraShake on its AbilityPresentationAsset. An existing
   presentation (Ram, Shoot, Smash) is updated in place, its projectile fields untouched; others get a new
   `Assets/Data/Presentation/<Ability> Presentation.asset`. Skip this step if you prefer to wire by hand.
4. **3 Wire Statuses** — `StatusAsset.loopVfx` for Burn, Burning, Acid, Poison, Shield, Haste, Rallied, Taunted,
   Gorged, Rooted, Enraged.
5. **4 Wire Projectile Trails** — adds a "Trail" child (nested prefab) to the seven Blender projectile prefabs.

Steps 2–4 only touch data; nothing happens at runtime that the game does not already do (`Vfx.Spawn`,
`EntityView.SetStatusVfx`).

## Where the effects are spawned (and three small code notes)

- `impactVfx` and `hitVfx` spawn 0.4 above the tile (Presenters.cs). The ground rings in the kit sit at −0.38 on
  purpose, so they land on the tile.
- `castVfx` spawns at the caster's feet (`caster.transform.position`). Cast effects in the kit are built for that
  (their offsets are +0.3 … +0.35). Two of them want the Muzzle instead: **Cannon Muzzle** and **Bow Twang**.
  Suggestion: spawn castVfx at `caster.MuzzlePosition` when the ability is Projectile/Lobbed, else at the feet.
- **Spawn Pop**, **Death Poof** and **Collision Thud** have no hook yet. Suggested: `Vfx.Spawn` in SpawnPresenter
  (at the tile), DeathPresenter / the Die clip's end (at the view's position) and the Collision case (midpoint).
  Until then they are unused prefabs.
- `Vfx.Spawn` destroys an effect after `vfxLifetime` (2 s). Every burst in the kit is finished by 1.3 s. Loops
  (status, trail) are children of the view / projectile and die with it.
- Game speed: all effects run on scaled time, so they speed up with the game and freeze on pause (as the design says).

## Style rules the kit follows

- Flat, chunky "paper cut-out" particles: every sprite is a white shape with a darker rim baked in, tinted by the
  particle colour (same 2-tone idea as the icons). Alpha-blended by default; additive only for light (flashes,
  glints, embers, holy / spirit).
- Few particles, big shapes, short lives: 5–12 per burst, 0.3–0.6 s. Things shrink away rather than fade, except
  rings and light.
- Palette from the style doc: Cobalt = player / buffs, Fire / Holy / Spirit / Acid = the four glows, EnemyEye red =
  enemy intent and anger, Slime green = slimes, Dirt / Stone / Smoke = ground and smoke.
- Rings on the ground for anything that hits the tile; a star pop for anything that hits a body.

## Changing an effect

Everything is data in `spec/effects.py` (one line per layer). Edit, run `./build.sh publish`, unzip the new kit and
run step 1 again. The browser preview and the Unity prefabs come from the same file.
