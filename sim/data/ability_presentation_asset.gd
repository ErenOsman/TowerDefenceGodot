class_name AbilityPresentationAsset
extends ContentAsset
## How one ability looks and sounds, overriding the defaults its attack-kind tag picks: the caster's
## animation, a projectile prefab, cast / impact / hit VFX, sounds and camera shake. Optional on an
## Ability asset; several abilities can share one (every arrow shot). Art fields are Unity asset paths
## ("" for none); the presentation layer maps them.

## Hidden content number (1, 2, 3… per asset type); players never see it.
var number: int = 0

# Caster
var caster_animation: int = CasterAnimation.Default
## Animator trigger when Caster Animation is Custom.
var custom_trigger: String = ""

# Projectile (Projectile and Lobbed attacks)
## Flies from the caster to the target, launched at the caster's Impact. "": the placeholder sphere.
var projectile: String = ""
## Tiles per second; 0 = the default pace.
var projectile_speed: float = 0.0

# Effects
## At the caster when its animation starts.
var cast_vfx: String = ""
## At the aimed target at the impact.
var impact_vfx: String = ""
## On every entity the ability damages.
var hit_vfx: String = ""
## Seconds before a spawned effect is destroyed.
var vfx_lifetime: float = 2.0

# Sounds (replace the default event sounds)
var cast_sound: String = ""
var impact_sound: String = ""
var hit_sound: String = ""

# Camera
## Camera shake at the impact (0 = none, 1 = strong).
var camera_shake: float = 0.0
