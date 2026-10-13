class_name Stacking
extends RefCounted
## What a new application does when the target already has the status. Stack: add stacks, refresh
## duration. Refresh: duration only. Replace: start over. Independent: always a new instance.
## PerSource: one instance per applier, stacking into its own (two poisoners = two poisons, each
## ticking for its applier and expiring on its own). New modes go at the end (assets store numbers).

const Stack := 0
const Refresh := 1
const Replace := 2
const Independent := 3
const PerSource := 4

const NAMES := ["Stack", "Refresh", "Replace", "Independent", "PerSource"]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
