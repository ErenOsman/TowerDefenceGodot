class_name SubjectNeeds
extends RefCounted
## [Flags] Which subjects a formula reads / an evaluation point provides. Combine with |, test with &.

const None := 0
const Source := 1
const Target := 2
const Self := 4

const NAMES := ["None", "Source", "Target", "Self"]
const VALUES := [0, 1, 2, 4]

## Parses "Source" or a C#-style flags list "Source, Self"; -1 when a part is unknown.
static func parse(s: String) -> int:
	var v := 0
	for part in s.split(","):
		var i := NAMES.find(part.strip_edges())
		if i < 0: return -1
		v |= VALUES[i]
	return v

static func name_of(v: int) -> String:
	if v == 0: return "None"
	var parts: Array[String] = []
	for i in range(1, NAMES.size()):
		if v & VALUES[i]: parts.append(NAMES[i])
	return ", ".join(parts)
