class_name ActionInfo
extends RefCounted
## One action: a kind, who acts (-1 = None for the level itself), and a detail (ability, tower ID, wave…).

var id: int = 0
var kind: int = ActionKind.Command
var actor: int = -1
## String or null.
var detail = null
