class_name StatusInstance
extends RefCounted
## One application of a status on an entity.

var def: StatusDef = null
var stacks: int = 0
var turns_left: int = 0
## C# default(EntityId) = 0 (the Environment).
var applied_by: int = 0
var active: bool = true

## Remaining shield; 0 for statuses that are not shields.
var pool: int = 0

## The team this status forces while active (Applier: the applier's team when applied).
var override_team: int = 0

## Tags added by the application (e.g. Hidden, Permanent), on top of the definition's.
var extra_tags: Array = []

func has_tag(tag: String) -> bool:
	return def.has_tag(tag) or extra_tags.has(tag)

var is_hidden: bool:
	get: return has_tag(Tags.Hidden)

## The definition's tags plus the application's.
var all_tags: Array:
	get:
		var out: Array = def.tags.duplicate()
		for t in extra_tags:
			if not def.has_tag(t): out.append(t)
		return out

## ExtraTags is replaced, never mutated, so the copy shares it (C# MemberwiseClone).
func clone() -> StatusInstance:
	var s := StatusInstance.new()
	s.def = def
	s.stacks = stacks
	s.turns_left = turns_left
	s.applied_by = applied_by
	s.active = active
	s.pool = pool
	s.override_team = override_team
	s.extra_tags = extra_tags
	return s
