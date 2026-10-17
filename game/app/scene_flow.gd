extends Node
## Autoload `SceneFlow` (SceneController.cs): scene changes by id, never by path.
##   SceneFlow.go(SceneFlow.MainMenu)
## The level (Game) goes through the Loading scene: go(Game) sets pending_target and opens Loading; the loading
## screen calls load_pending(self), which loads the level and opens it UNDER the loading screen (which stays on
## top); the level calls hold_loading_screen() in _ready and release_loading_screen() once its board, models and
## HUD are built; the loading screen waits for target_ready and not loading_screen_held, fades out and calls
## close_loading_screen(self). Every load restores the game speed (a pause menu left time at 0) and starts the
## scene's music (AudioMgr.play_scene_music).
## Scenes: res://game/boot.tscn, res://game/screens/<name>.tscn (also accepted under res://game/ui/screens/),
## res://game/level/level.tscn; a missing one falls back to res://game/app/placeholders/<name>.tscn.
## slide(id, dir) is the other transition (Camp ⇄ Guild, Camp ⇄ Blacksmith; Eren 2026-10-15): both screens visible, the old one moving
## out to the left while the new one comes in from the right (dir -1: the other way), SLIDE_TIME, ease out, input
## blocked; the new scene can wait for slide_finished (is_sliding) before showing its own cards. go() stays a cut.

signal loading_started
## 0..1 while a scene loads.
signal loading_progress(progress: float)
## The new scene is the current scene.
signal loading_completed
## The loading screen was closed over the opened level.
signal loading_screen_closed
## A slide() ended (the new scene sits in place, the old one is freed).
signal slide_finished

## The slide's length (seconds, unscaled time).
const SLIDE_TIME := 0.45
## True while a slide() runs (input is blocked; set together with is_loading).
var is_sliding: bool = false
## Renders: >= 0 holds a running slide at that progress (0..1, before the ease) until set back to -1.
var slide_hold: float = -1.0

enum { Boot, MainMenu, Game, LevelSelect, Welcome, Camp, Loading, Guild, Blacksmith }
const NAMES := ["Boot", "MainMenu", "Game", "LevelSelect", "Welcome", "Camp", "Loading", "Guild", "Blacksmith"]
const FILES := ["boot", "main_menu", "level", "level_select", "welcome", "camp", "loading", "guild", "blacksmith"]

## True while a scene change runs.
var is_loading: bool = false
## Where the Loading scene goes next (-1: nothing pending). Set by go(Game); read by the loading screen.
var pending_target: int = -1
## The scene showing now (one of the ids).
var current: int = Boot
## The pending target has been opened under the loading screen.
var target_ready: bool = false

## Timings of the last scene change (diagnostics): loading the PackedScene, and instantiate + add (its _ready).
var last_load_ms: float = 0.0
var last_build_ms: float = 0.0

var _holds := 0
var _loading_screen: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

static func name_of(id: int) -> String:
	return NAMES[id] if id >= 0 and id < NAMES.size() else str(id)

## The scene file for an id: the real one when it exists, else its placeholder ("" when neither).
func path_of(id: int) -> String:
	for p in candidates(id):
		if ResourceLoader.exists(p): return p
	return ""

## Where a scene id is looked for, in order.
static func candidates(id: int) -> Array:
	if id < 0 or id >= FILES.size(): return []
	var f: String = FILES[id]
	match id:
		Boot: return ["res://game/boot.tscn"]
		Game: return ["res://game/level/level.tscn", "res://game/app/placeholders/level.tscn"]
	return ["res://game/screens/%s.tscn" % f, "res://game/ui/screens/%s.tscn" % f, "res://game/app/placeholders/%s.tscn" % f]

## Whether the real scene (not a placeholder) exists.
func has_real_scene(id: int) -> bool:
	var p := path_of(id)
	return p != "" and not p.begins_with("res://game/app/placeholders/")

## Changes scene. Game goes through Loading unless direct (the loading screen's own load uses load_pending).
func go(id: int, direct := false) -> void:
	if is_loading:
		push_warning("[SceneFlow] already loading a scene; ignoring go(%s)" % name_of(id))
		return
	if not direct and id == Game:
		pending_target = id
		id = Loading
	_change(id)

## Changes scene with a horizontal slide: the current scene moves out to the left while the new one comes in from
## the right (dir 1), or the other way (dir -1). Both are full-rect Controls; no black frame (the new scene is built
## off-screen first); every input event is swallowed until the slide ends. Not for Game (that goes through Loading).
func slide(id: int, dir := 1) -> void:
	if is_loading:
		push_warning("[SceneFlow] already loading a scene; ignoring slide(%s)" % name_of(id))
		return
	var path := path_of(id)
	if path == "" or id == Game:
		go(id)
		return
	is_loading = true
	is_sliding = true
	loading_started.emit()
	await get_tree().process_frame # let the caller finish (a button's signal)
	var packed := await _load(path)
	var tree := get_tree()
	var old := tree.current_scene
	if packed == null:
		push_error("[SceneFlow] could not load %s" % path)
		is_loading = false
		is_sliding = false
		return
	var w: float = tree.root.get_visible_rect().size.x
	var inst := packed.instantiate()
	current = id
	if inst is Control: (inst as Control).position.x = w * dir # built off-screen
	tree.root.add_child(inst)
	tree.current_scene = inst
	restore_game_speed()
	_after_open(id)
	loading_completed.emit()
	if inst is Control: (inst as Control).position.x = w * dir # its _ready may have reset its offsets
	await tree.process_frame # its first frame drawn off-screen (the 3D view sizes itself)
	var t := 0.0
	var last := Time.get_ticks_usec()
	while t < 1.0:
		var now := Time.get_ticks_usec()
		if slide_hold >= 0.0: t = clampf(slide_hold, 0.0, 0.999)
		else: t = minf(1.0, t + (now - last) / 1e6 / SLIDE_TIME)
		last = now
		_slide_pose(old, inst, w, dir, t)
		if t >= 1.0: break
		await tree.process_frame
	if old != null and is_instance_valid(old):
		old.get_parent().remove_child(old)
		old.queue_free()
	if is_instance_valid(inst) and inst is Control: (inst as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	is_loading = false
	is_sliding = false
	slide_finished.emit()

## Places both scenes at slide progress t (0..1; ease out cubic).
static func _slide_pose(old: Node, new: Node, w: float, dir: int, t: float) -> void:
	var e := 1.0 - pow(1.0 - t, 3.0)
	if old is Control and is_instance_valid(old): (old as Control).position.x = -w * dir * e
	if new is Control and is_instance_valid(new): (new as Control).position.x = w * dir * (1.0 - e)

## Every input event is swallowed while a slide runs (autoloads' _input comes before the GUI and _unhandled_input).
func _input(event: InputEvent) -> void:
	if is_sliding: get_viewport().set_input_as_handled()

## Reloads the current scene (a level restarts directly, like Unity).
func restart_current() -> void:
	if is_loading:
		push_warning("[SceneFlow] already loading a scene; ignoring restart")
		return
	_change(current)

## Quits (on the web there is nothing to quit to: goes to the main menu instead).
func quit_game() -> void:
	print("[SceneFlow] quit requested")
	if OS.has_feature("web"):
		go(MainMenu)
	else:
		get_tree().quit()

## Guard: outside a level the engine always runs at 1 (menus, Camp, Guild, Blacksmith, Loading, Welcome), whatever
## path led there (Eren 2026-10-17: "ana menü gibi yerler game speed'den etkilenmemeli"). The pause menu's 0 only
## exists inside a level, so it is never overridden here.
func _process(_delta: float) -> void:
	if current != Game and Engine.time_scale != 1.0: Engine.time_scale = 1.0

## A new scene never starts paused: the game speed setting again (or 1).
func restore_game_speed() -> void:
	get_tree().paused = false
	var sd := get_node_or_null("/root/SaveData")
	var speed: float = sd.settings.game_speed if sd != null else 1.0
	# the game speed only runs levels; menus, the Camp and the Guild always run at 1 (Eren 2026-10-15)
	Engine.time_scale = speed if speed > 0.0 and current == Game else 1.0

# ---------------------------------------------------------------- loading screen holds

## A scene that needs time after it opens (the level) holds the loading screen; it stays up, opaque, until released.
func hold_loading_screen() -> void:
	_holds += 1

func release_loading_screen() -> void:
	_holds = maxi(0, _holds - 1)

var loading_screen_held: bool:
	get: return _holds > 0

## Called by the loading screen: loads pending_target and opens it under the screen (which stays on top until
## close_loading_screen). Emits loading_progress along the way; target_ready turns true when it is open.
func load_pending(loading_screen: Node) -> void:
	var target := pending_target if pending_target >= 0 else MainMenu
	pending_target = -1
	target_ready = false
	_loading_screen = loading_screen
	await _change(target, loading_screen)
	target_ready = true

## A loading screen is over the scene (from load_pending until close_loading_screen: opaque, then fading out).
## The opened scene's first sequence line and first input wait for it (LevelController.behind_loading_screen).
func is_loading_screen_up() -> bool:
	return _loading_screen != null and is_instance_valid(_loading_screen) and not _loading_screen.is_queued_for_deletion()

## Frees the loading screen over the opened scene (hidden at once: not drawn again, even for the frame it is freed in).
func close_loading_screen(loading_screen: Node = null) -> void:
	var n := loading_screen if loading_screen != null else _loading_screen
	_loading_screen = null
	target_ready = false
	if n != null and is_instance_valid(n):
		if n is CanvasItem or n is CanvasLayer: n.visible = false
		n.queue_free()
	loading_screen_closed.emit()

# ---------------------------------------------------------------- internals

func _change(id: int, keep: Node = null) -> void:
	var path := path_of(id)
	if path == "":
		push_error("[SceneFlow] no scene for %s" % name_of(id))
		return
	is_loading = true
	loading_started.emit()
	loading_progress.emit(0.0)
	await get_tree().process_frame # let the caller finish (a button's signal) and the screen draw
	var t_load := Time.get_ticks_usec()
	var packed := await _load(path)
	last_load_ms = (Time.get_ticks_usec() - t_load) / 1000.0
	if packed == null:
		push_error("[SceneFlow] could not load %s" % path)
		is_loading = false
		return
	var tree := get_tree()
	var old := tree.current_scene
	if old != null and old != keep:
		old.get_parent().remove_child(old)
		old.queue_free()
	var t_build := Time.get_ticks_usec()
	var inst := packed.instantiate()
	current = id
	tree.root.add_child(inst)
	last_build_ms = (Time.get_ticks_usec() - t_build) / 1000.0
	tree.current_scene = inst
	if keep != null and is_instance_valid(keep) and keep.get_parent() == tree.root:
		tree.root.move_child(keep, -1)
	is_loading = false
	restore_game_speed()
	loading_progress.emit(1.0)
	_after_open(id)
	loading_completed.emit()

func _after_open(id: int) -> void:
	# NewGame.cs: a tutorial cut short (closed game, crash) counts as skipped once a menu opens
	if (id == MainMenu or id == LevelSelect) and SaveData.profile.tutorial_pending:
		SaveData.skip_tutorial()
	AudioMgr.play_scene_music(id, LevelLaunch.level)

## Loads a PackedScene, in the background where threads exist (progress signals), else at once (web).
func _load(path: String) -> PackedScene:
	if OS.has_feature("web") or ResourceLoader.has_cached(path):
		return load(path) as PackedScene
	if ResourceLoader.load_threaded_request(path, "PackedScene", true) != OK:
		return load(path) as PackedScene
	var progress := []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED: break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return null
		if not progress.is_empty(): loading_progress.emit(clampf(float(progress[0]), 0.0, 1.0))
		await get_tree().process_frame
	return ResourceLoader.load_threaded_get(path) as PackedScene
