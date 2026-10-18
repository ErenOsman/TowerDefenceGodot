class_name TowerCollection
extends RefCounted
## The player's towers and hand, saved in GameData. The hand is an ordered list of owned tower IDs
## (up to 8); a level takes the first ones up to its hand cap.

const MaxHand := 8

var towers: Array = []  # of OwnedTower
var hand: Array = []
## Why the last can_add_to_hand said no ("" when it said yes) — the C# `out string reason`.
var last_reason: String = ""

func find(id: String) -> OwnedTower:
	for t in towers:
		if t.id == id: return t
	return null

## A tower's place among the player's towers of the SAME type, 1-based, in the order they were got ("Drummer #2" =
## the second Drummer); 0 when the id is not owned. The id itself is untouched. Godot-first (Eren 2026-10-17).
func ordinal_of(id: String) -> int:
	return TowerCollection.ordinal_in(towers, id)

static func ordinal_in(list: Array, id: String) -> int:
	var type := ""
	for t in list:
		if t.id == id:
			type = t.type
			break
	if type == "": return 0
	var n := 0
	for t in list:
		if t.type == type: n += 1
		if t.id == id: return n
	return 0

## Gives the player a new tower of a type, with a fresh ID.
func add(type_id: String, custom_name: String = "") -> OwnedTower:
	var t := OwnedTower.new()
	t.id = TowerIds.new_id()
	t.type = type_id
	t.custom_name = custom_name
	towers.append(t)
	return t

## Removes a tower (and takes it out of the hand).
func remove(id: String) -> bool:
	hand.erase(id)
	var removed := false
	for i in range(towers.size() - 1, -1, -1):
		if towers[i].id == id:
			towers.remove_at(i)
			removed = true
	return removed

func can_add_to_hand(id: String, reason_out = null) -> bool:
	if find(id) == null: last_reason = "Not owned"
	elif hand.has(id): last_reason = "Already in the hand"
	elif hand.size() >= MaxHand: last_reason = "The hand is full (%d)" % MaxHand
	else: last_reason = ""
	if reason_out is Array:
		reason_out.resize(1)
		reason_out[0] = null if last_reason == "" else last_reason
	return last_reason == ""

## C# throws InvalidOperationException when it cannot: push_error and false here.
func add_to_hand(id: String) -> bool:
	if not can_add_to_hand(id):
		push_error(last_reason)
		return false
	hand.append(id)
	return true

func remove_from_hand(id: String) -> void:
	hand.erase(id)

## Moves a hand entry to a new index (order matters: a level takes the first ones).
func move_in_hand(id: String, index: int) -> void:
	if not hand.has(id): return
	hand.erase(id)
	hand.insert(maxi(0, mini(index, hand.size())), id)

## The hand as level towers, in order. Hand entries that are not owned, or whose type is unknown
## (removed from the game), are skipped and reported in problems. type_by_id: Callable(String) -> TowerType.
## Each tower is built as its current Workshop form (Workshop.resolve): the form's entity, name and cost, keeping
## the tower's own ID; a form the content no longer has is reported and the default form is used.
func build_hand(type_by_id: Callable, problems = null) -> Array:
	return build_towers(hand, type_by_id, problems)

## Like build_hand for any list of owned tower ids (a mission takes only the hand's first rested towers:
## MissionBoard.start_play), in the given order. Godot-first.
func build_towers(ids: Array, type_by_id: Callable, problems = null) -> Array:
	var result := []
	var seen := {}
	for id in ids:
		if seen.has(id): continue
		seen[id] = true
		var owned := find(id)
		if owned == null:
			if problems != null: problems.append("Hand entry %s is not an owned tower" % id)
			continue
		var type: TowerType = type_by_id.call(owned.type)
		if type == null:
			if problems != null: problems.append("Tower %s has an unknown type '%s'" % [id, owned.type])
			continue
		if owned.form != "" and type.find_form(owned.form) == null and problems != null:
			problems.append("Tower %s has an unknown form '%s' (default form used)" % [id, owned.form])
		var d := TowerDef.new()
		d.id = owned.id
		d.custom_name = owned.custom_name
		d.type = Workshop.resolve(owned, type)
		result.append(d)
	return result

## What a level builds for one owned tower (Workshop): its type as its current form, or null when the type is unknown.
func resolve(id: String, type_by_id: Callable) -> TowerType:
	var owned := find(id)
	if owned == null: return null
	return Workshop.resolve(owned, type_by_id.call(owned.type))
