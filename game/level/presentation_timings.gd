class_name PresentationTimings
extends RefCounted
## How long the level's presentation shows things, in seconds (PresentationTimings.cs): banners, floating text and
## health bars, plus the generic effects. Read from the content's PresentationTimings.json (ContentLibrary keeps
## unknown-type files in skipped_json); the defaults below when absent.

var round_banner := 0.8
var enemy_phase_banner := 0.8
var wave_banner := 1.2
var message_banner := 1.6
var floating_text := 0.9
var ability_name := 0.8
var health_bar_after_death := 1.0
var health_bar_after_hit := 1.5
## VFX kit effect names (the Unity prefab's file name): played where a unit appears, dies, bumps.
var spawn_vfx := "Spawn Pop"
var death_vfx := "Death Poof"
var collision_vfx := "Collision Thud"

static var _defaults: PresentationTimings = null

## The timings in use by the level (set by LevelController); null = defaults().
static var current: PresentationTimings = null

static func defaults() -> PresentationTimings:
	if _defaults == null: _defaults = PresentationTimings.new()
	return _defaults

## current, or the defaults.
static func get_timings() -> PresentationTimings:
	return current if current != null else defaults()

## The timings from a content library's PresentationTimings file (the defaults for what it lacks).
static func from_library(lib) -> PresentationTimings:
	var t := PresentationTimings.new()
	if lib == null or not ("skipped_json" in lib): return t
	for file in lib.skipped_json:
		var j = lib.skipped_json[file]
		if not (j is Dictionary) or str(j.get("type", "")) != "PresentationTimings": continue
		var assets = j.get("assets", {})
		if not (assets is Dictionary) or assets.is_empty(): continue
		var a: Dictionary = assets.values()[0]
		t.round_banner = float(a.get("roundBanner", t.round_banner))
		t.enemy_phase_banner = float(a.get("enemyPhaseBanner", t.enemy_phase_banner))
		t.wave_banner = float(a.get("waveBanner", t.wave_banner))
		t.message_banner = float(a.get("messageBanner", t.message_banner))
		t.floating_text = maxf(0.1, float(a.get("floatingText", t.floating_text)))
		t.ability_name = maxf(0.1, float(a.get("abilityName", t.ability_name)))
		t.health_bar_after_death = float(a.get("healthBarAfterDeath", t.health_bar_after_death))
		t.health_bar_after_hit = float(a.get("healthBarAfterHit", t.health_bar_after_hit))
		t.spawn_vfx = VfxKit.effect_name(a.get("spawnVfx", t.spawn_vfx))
		t.death_vfx = VfxKit.effect_name(a.get("deathVfx", t.death_vfx))
		t.collision_vfx = VfxKit.effect_name(a.get("collisionVfx", t.collision_vfx))
		break
	return t
