@tool
extends VBoxContainer
## The "TD Tools" bottom panel: ports of the Unity editor tools, without the game's autoloads (the editor does not
## run them): Persistent data (user://gamedata.json), Validate All, Balance Sheet, Level Playtester, Export Game
## Reference. Jobs that run the simulation code go through job() (a headless Godot in the editor). `host` gives the editor-only calls
## (play_scene, select_file, open_external, rescan): the plugin in the editor, a stub in tests.

const TabSave := preload("res://addons/td_tools/tabs/tab_save.gd")
const TabValidate := preload("res://addons/td_tools/tabs/tab_validate.gd")
const TabBalance := preload("res://addons/td_tools/tabs/tab_balance.gd")
const TabPlaytest := preload("res://addons/td_tools/tabs/tab_playtest.gd")
const TabReference := preload("res://addons/td_tools/tabs/tab_reference.gd")
const Jobs := preload("res://addons/td_tools/jobs.gd")

## Whatever provides the editor calls (duck-typed); null = none (buttons that need it say so).
var host: Object = null
var content_folder := ContentFiles.Folder
var tabs: TabContainer
var content_label: Label
var pages: Array = []
## Jobs run in a separate headless Godot (true in the editor; tests run them in-process).
var external: bool = Engine.is_editor_hint()
var busy_label: Label
var _running: Array = [] # [job, done, cmd]

func _init() -> void:
	custom_minimum_size = Vector2(0, 320)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	add_child(head)
	content_label = Label.new()
	content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_label.text = "Content not loaded yet."
	head.add_child(content_label)
	busy_label = Label.new()
	head.add_child(busy_label)
	var reload := Button.new()
	reload.text = "Reload content"
	reload.tooltip_text = "Read data/content/*.json again in every tab (after a sync or an edit)."
	reload.pressed.connect(reload_content)
	head.add_child(reload)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	for t in [[TabSave, "Persistent data"], [TabValidate, "Validate all"], [TabBalance, "Balance sheet"],
			[TabPlaytest, "Level playtester"], [TabReference, "Export game reference"]]:
		var page: Control = t[0].new()
		page.name = t[1]
		page.dock = self
		tabs.add_child(page)
		pages.append(page)
	tabs.tab_changed.connect(func(i): pages[i].on_shown())

func _ready() -> void:
	pages[tabs.current_tab].on_shown()

## Shows a tab (and fills it the first time).
func show_tab(i: int) -> void:
	tabs.current_tab = i
	pages[i].on_shown()

## Runs a tools job (jobs.gd) and calls done(result) with its Dictionary: in a headless Godot process when in the
## editor (polled in _process, so the editor stays responsive), else at once.
func job(cmd: String, args: Dictionary, done: Callable) -> void:
	if not args.has("folder"): args["folder"] = content_folder
	if not external:
		done.call(Jobs.run(cmd, args))
		return
	var j := Jobs.start_external(cmd, args)
	if j.pid < 0:
		done.call({"problem": "could not start " + OS.get_executable_path()})
		return
	_running.append([j, done, cmd])
	_show_busy()

func _process(_dt: float) -> void:
	if _running.is_empty(): return
	for r in _running.duplicate():
		var j: Dictionary = r[0]
		var result = null
		if not OS.is_process_running(j.pid): result = Jobs.finish_external(j)
		elif Time.get_ticks_msec() - j.started > Jobs.TIMEOUT_MS:
			OS.kill(j.pid)
			result = {"problem": "the tools process timed out"}
		if result != null:
			_running.erase(r)
			r[1].call(result)
	_show_busy()

func _show_busy() -> void:
	busy_label.text = ("Working: " + ", ".join(PackedStringArray(_running.map(func(r): return r[2]))) + "…") if not _running.is_empty() else ""

## Reloads the content (the jobs read data/content each time) and refreshes the tabs that show it.
func reload_content() -> void:
	job("levels", {}, show_content)
	for p in pages: p.on_content_reloaded()

## The header line from a "levels" job result.
func show_content(r: Dictionary) -> void:
	content_label.text = "Content: %d assets in %s%s" % [int(r.get("assets", 0)), content_folder,
		"" if int(r.get("problems", 0)) == 0 else " · %d loading problem(s)" % int(r.get("problems", 0))]

## Calls host.method(args) when the host has it; false otherwise.
func call_host(method: String, args: Array = []) -> bool:
	if host == null or not host.has_method(method): return false
	host.callv(method, args)
	return true

# ---------------------------------------------------------------- small builders shared by the tabs

static func button(text: String, on_press: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(on_press)
	return b

static func label(text: String, expand := false) -> Label:
	var l := Label.new()
	l.text = text
	if expand: l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func note(text: String) -> Label:
	var l := label(text, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(1, 1, 1, 0.7)
	return l
