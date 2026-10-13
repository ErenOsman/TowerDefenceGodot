class_name Tags
extends RefCounted
## Well-known tag names. Tags are plain strings, so a game can add its own.
## Tag sets (C# HashSet<string>) are Dictionaries used as sets: {tag: true}; test with has().

const Attack := "Attack"
const Spell := "Spell"
const Fire := "Fire"
const Poison := "Poison"
const Reaction := "Reaction"
const Reflected := "Reflected"
const Debuff := "Debuff"
const Buff := "Buff"

# Entity tags
## Flies: may stand over chasms (and walk a road across one). Walls still stop it.
const Flying := "Flying"
## A rock: a neutral obstacle (Brutes that eat rocks look for it).
const Rock := "Rock"

## On EntityDied: the unit fell, its tile turned into terrain it cannot stand on (Tiles — Design).
const Fell := "Fell"

# Status tags (on the status, or added by one application)
## The UI does not show the status. Rules see it as usual.
const Hidden := "Hidden"
## Cleanses (Remove Status by tag) skip it; removal by name still works.
const Permanent := "Permanent"

# Capability tags (Entity System — Design, Capabilities). Statuses grant them; capabilities read them.
const Stunned := "Stunned"
const Frozen := "Frozen"
const Asleep := "Asleep"
const Rooted := "Rooted"
const Silenced := "Silenced"
const Disarmed := "Disarmed"
const Untargetable := "Untargetable"
const Stealthed := "Stealthed"
## Soft: automatic choices (instincts) prefer aims that hit the status's applier, when there are any; hand aiming is free.
const Taunted := "Taunted"
## Bosses (e.g. the Slime King): abilities can read it, as in Target.HasTag(Boss).
const Boss := "Boss"
## Hard: the unit may only target the status's applier (ValidAims), hand aiming included.
const Redirected := "Redirected"

# Attack kinds: for presentation (which animation) and rules (reflect projectiles, immune to melee…)
const Melee := "Melee"
## Straight shots (usually a Ray area): stopped by walls and blockers.
const Projectile := "Projectile"
## Arcs over units and walls (no line of sight).
const Lobbed := "Lobbed"
## Strikes the target directly (from the sky, homing): nothing in between matters.
const Beam := "Beam"

# Game Overview — Design
## Movement abilities (Walk, Jump…): enemies pick the aim that advances them farthest.
const Movement := "Movement"
## A base: the level is lost when any base reaches 0 HP.
const Base := "Base"

## Tags that make CanAct false.
const PreventActing := [Stunned, Frozen, Asleep]

## Tags.Set: Tags.set_of("A", "B") or Tags.set_of(array_or_null) → {"A": true, "B": true}.
static func set_of(...tags: Array) -> Dictionary:
	var s := {}
	var list = tags
	if tags.size() == 1 and (tags[0] == null or tags[0] is Array or tags[0] is PackedStringArray or tags[0] is Dictionary):
		list = [] if tags[0] == null else tags[0]
	for t in list: s[t] = true
	return s

## a and b: Arrays, Dictionary sets or null. Returns a new Dictionary set.
static func union(a, b) -> Dictionary:
	var s := {}
	if a != null:
		for t in a: s[t] = true
	if b != null:
		for t in b: s[t] = true
	return s
