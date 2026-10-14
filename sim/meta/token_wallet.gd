class_name TokenWallet
extends RefCounted
## The player's Workshop tokens, saved in GameData (Workshop — Design): a count per token kind and the total ever
## earned per kind (for stats; nothing reads it yet). Keys are token IDs (TokenAsset.id), in first-seen order.

## {token id: count owned}
var counts: Dictionary = {}
## {token id: total earned}
var earned: Dictionary = {}

## How many of a token the player has.
func count(token_id: String) -> int:
	return int(counts.get(token_id, 0))

## Whether the player has at least amount of a token.
func has(token_id: String, amount: int = 1) -> bool:
	return count(token_id) >= amount

## Gives tokens (counts as earned). Non-positive amounts do nothing.
func add(token_id: String, amount: int = 1) -> void:
	if token_id == "" or amount <= 0: return
	counts[token_id] = count(token_id) + amount
	earned[token_id] = int(earned.get(token_id, 0)) + amount

## Gives every {token id: amount}.
func add_all(amounts: Dictionary) -> void:
	for id in amounts: add(id, int(amounts[id]))

## Whether every {token id: amount} is owned.
func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if count(id) < int(cost[id]): return false
	return true

## What is missing of a cost: {token id: how many more}, empty when it is affordable.
func missing(cost: Dictionary) -> Dictionary:
	var out := {}
	for id in cost:
		var short := int(cost[id]) - count(id)
		if short > 0: out[id] = short
	return out

## Spends a cost when every part is owned (all or nothing); returns whether it did.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost): return false
	for id in cost:
		if int(cost[id]) > 0: counts[id] = count(id) - int(cost[id])
	return true

## Total tokens owned (every kind).
func total() -> int:
	var n := 0
	for id in counts: n += int(counts[id])
	return n

## Save form: {"tokens": [{"id", "count"}], "earned": [{"id", "count"}]} (Workshop — Design, GameData.tokens).
func to_dict() -> Dictionary:
	return {"tokens": _list(counts), "earned": _list(earned)}

static func from_dict(d) -> TokenWallet:
	var w := TokenWallet.new()
	if not (d is Dictionary): return w
	w.counts = _dict(d.get("tokens"))
	w.earned = _dict(d.get("earned"))
	return w

static func _list(m: Dictionary) -> Array:
	var out := []
	for id in m: out.append({"id": id, "count": int(m[id])})
	return out

static func _dict(v) -> Dictionary:
	var out := {}
	if not (v is Array): return out
	for o in v:
		if not (o is Dictionary) or o.get("id") == null: continue
		var id := str(o.get("id"))
		if id == "": continue
		out[id] = int(out.get(id, 0)) + maxi(0, int(o.get("count", 0)))
	return out
