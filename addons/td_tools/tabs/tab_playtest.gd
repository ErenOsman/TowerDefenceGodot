@tool
extends "res://addons/td_tools/tabs/tab_base.gd"
## Level Playtester (LevelPlaytester.cs): pick a level, a hand (tower types, multi-select; none = the save's hand),
## a seed and instant playback, then Play runs res://game/level/level.tscn with them: the request goes to
## user://dev_launch.json (DevLaunch), which the LevelController takes once at setup. The result is only written
## to the save when "Save the result" is ticked.

var level_pick: OptionButton
var level_info: Label
var hand_list: ItemList
var seed_spin: SpinBox
var instant: CheckBox
var record: CheckBox
var levels: Array = [] # {id, label, info}
var towers: Array = [] # {id, label}

func build() -> void:
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	left.add_child(D.label("Level"))
	level_pick = OptionButton.new()
	level_pick.item_selected.connect(func(_i): _show_level())
	left.add_child(level_pick)
	level_info = D.note("")
	left.add_child(level_info)
	var opts := HBoxContainer.new()
	left.add_child(opts)
	opts.add_child(D.label("Seed"))
	seed_spin = SpinBox.new()
	seed_spin.min_value = 1
	seed_spin.max_value = 999999
	seed_spin.value = 1
	opts.add_child(seed_spin)
	opts.add_child(D.button("Random", func(): seed_spin.value = randi_range(1, 999999)))
	instant = CheckBox.new()
	instant.text = "Instant playback"
	opts.add_child(instant)
	record = CheckBox.new()
	record.text = "Save the result"
	record.tooltip_text = "Off: playing writes nothing to user://gamedata.json (no progress, no rewards)."
	opts.add_child(record)
	var play := D.button("▶ Play", play_level, "Runs the Level scene with this level, hand and seed.")
	play.custom_minimum_size = Vector2(160, 0)
	left.add_child(play)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(D.label("Hand (Ctrl/Shift-click several; none = the save's hand)"))
	hand_list = ItemList.new()
	hand_list.select_mode = ItemList.SELECT_MULTI
	hand_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_list.custom_minimum_size = Vector2(0, 140)
	right.add_child(hand_list)

## Fetches the level and tower lists (a tools job).
func fill() -> void:
	dock.job("levels", {}, func(r: Dictionary):
		dock.show_content(r)
		levels = r.get("levels", [])
		towers = r.get("towers", [])
		var keep := level_pick.selected
		level_pick.clear()
		for l in levels: level_pick.add_item(l.label)
		if keep >= 0 and keep < levels.size(): level_pick.select(keep)
		hand_list.clear()
		for t in towers: hand_list.add_item(t.label)
		_show_level()
		say("%d levels, %d tower types." % [levels.size(), towers.size()]))

## The picked level's id ("" for none).
func selected_level() -> String:
	var i := level_pick.selected
	return levels[i].id if i >= 0 and i < levels.size() else ""

func selected_hand() -> Array:
	var out := []
	for i in hand_list.get_selected_items(): out.append(towers[i].id)
	return out

func _show_level() -> void:
	var i := level_pick.selected
	level_info.text = levels[i].info if i >= 0 and i < levels.size() else ""

## The launch request for the current choices.
func request() -> Dictionary:
	return DevLaunch.make(selected_level(), selected_hand(), int(seed_spin.value),
		true if instant.button_pressed else null, record.button_pressed)

func play_level() -> void:
	if selected_level() == "":
		say("Pick a level.")
		return
	var req := request()
	var problem := DevLaunch.write_file(req)
	if problem != "":
		say(problem)
		return
	if dock.call_host("play_scene", [DevLaunch.LEVEL_SCENE]):
		say("Playing %s · hand %s · seed %d" % [req.level_id, ", ".join(PackedStringArray(req.hand)) if not req.hand.is_empty() else "(saved)", req.seed])
	else:
		say("Wrote %s (no editor host to play it)." % DevLaunch.FILE)
