class_name Modifiers
extends RefCounted
## A modifier combination held with a key (InputBindings.cs `Modifiers`): none (the key alone), Shift, Ctrl,
## Alt or Ctrl+Shift. Matched exactly: Space is not Shift+Space, Ctrl is not Ctrl+Shift.

const None := 0
const Shift := 1
const Ctrl := 2
const Alt := 3
const CtrlShift := 4

const NAMES := ["None", "Shift", "Ctrl", "Alt", "CtrlShift"]

## Every combination, in the order a dropdown lists them.
const ALL := [None, Shift, Ctrl, Alt, CtrlShift]

## Index of the member called s, or -1 when unknown.
static func parse(s: String) -> int: return NAMES.find(s)

static func name_of(v: int) -> String: return NAMES[v] if v >= 0 and v < NAMES.size() else str(v)
