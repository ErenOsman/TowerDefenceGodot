class_name ChapterKind
extends RefCounted
## Main chapters are the story, in order; side chapters are extra, each opened by its own rule.

const Main := 0
const Side := 1

const NAMES := ["Main", "Side"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
