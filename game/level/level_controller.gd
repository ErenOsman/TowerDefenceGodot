class_name LevelController
extends Node3D
## Plays a level in the scene (LevelController.cs, its spec): builds the session, the board, the views and the
## camera, ticks the Director with scaled time (game speed = Engine.time_scale), and takes board input only while
## the Director is idle (selecting and cancelling always work). The HUD (game/ui/hud) reads it and calls its
## commands; `version` changes (and `changed` fires) whenever what the HUD shows may have changed. The HUD reads
## the shown frame (`shown`), never GameState.
##
## The level comes from GameApp.level_launch (LevelLaunch); run directly (F6 / a tool), it plays `test_level_id`
## with `test_hand` when the save has no hand. Pointer input over the HUD is not the board's: a Control under the
## pointer (Viewport.gui_get_hovered_control) blocks board hover, clicks, wheel zoom and drags, so HUD roots that
## cover the screen must use MOUSE_FILTER_IGNORE. Overlay layers are all MOUSE_FILTER_IGNORE.

## Fired whenever version changes (a command, a mode or selection change, playback).
signal changed(version: int)
## Esc with nothing to cancel, or the Pause key: the HUD opens the pause menu.
signal pause_requested
## The level is over and its last action (and the end banner) has played: the HUD opens the end screen.
signal level_ended(outcome: int)
## The level could not start (setup_error says why).
signal setup_failed(error: String)
## An EnergyChanged event played (the energy counter ticks).
signal energy_ticked(amount: int, energy: int)
## The speech-bubble sequence changed line (or ended).
signal sequence_changed
## A refusal or hint message was set ("" when it faded).
signal message_changed(text: String)

## Run directly: the level played (LevelAsset id) and the towers (TowerAsset ids) when the save has none.
@export var test_level_id: String = "chapter1-1"
@export var test_hand: PackedStringArray = PackedStringArray(["archer", "archer", "cannon", "mage"])
@export var level_seed: int = 1
## Dead units leave a visible corpse (off: the body disappears once it has died).
@export var show_corpses: bool = false
## The HUD scene added over the level when it exists (the hud agent's); it gets this controller through
## `controller = …` (when it has that property) before it enters the tree, and bind(self) after.
@export var hud_scene_path: String = "res://game/ui/hud/hud.tscn"
## Setting overrides for tools (null = the save's settings).
var instant_override = null
var always_show_health_override = null
var follow_override = null

const MESSAGE_SECONDS := 3.0

# ------------------------------------------------------------------ runtime state

var level: LevelAsset = null
var session: LevelSession = null
var converter: AssetConverter = null
var recorder: FrameRecorder = null
var director: Director = null
var board: BoardView = null
var views: EntityViews = null
var overlay: BattleOverlay = null
var camera: BoardCamera = null
var presenters: DefaultPresenters = null
var setup_error = null            # String or null
var version: int = 0:
	set(v):
		version = v
		changed.emit(version)

var _rules_asset: GameRulesAsset = null
var _preview_caster: Entity = null
var _preview_ability: AbilityDef = null
var _aura_owner: Entity = null
var _aura_preview = null          # Condition or null
var _aura_tiles = null            # Array or null
var _aura_at := Vector2i.ZERO
var _key_preview := false
var _quick_key := -1
var _placing = null               # tower ID (String) or null
var _selected: int = -1
var _aiming: AbilityDef = null
var _aims: Array = []
var _route: RouteBuilder = null
var _hover = null                 # Vector2i or null
var _message = null               # String or null
var _message_until := 0.0
var _was_busy := false
var _end_shown := false
var _launched := false
var _sequence: SequenceRun = null
var _waves_cleared := 0
var _waves_arrived := 0
var _met := {}
var _catalogued := {}
var _sequence_subject: int = -1
var _recorded := false
var _last_followed_action := -1
var _forecast = null
var _forecast_for := -1
var _forecast_version := -1
var _turn_forecast: PhaseForecast = null
var _tray_hover: int = -1
var _board_press := false
var _was_left := false
var _was_right := false
var _ready_version := -1
var _ready_units: Array = []
var _enemy_forecast: PhaseForecast = null
var _enemy_forecast_version := -1
var _markers_key: Array = []
var _last_shown_phase: int = Phase.NotStarted
var _last_ticks := 0
var _loading_held := false
var _frames_drawn := 0

## Tools and tests: forces the tile under the pointer (Vector2i; out of bounds = none), null = the real pointer.
var hover_override = null
## A panel (pause, settings, end screen) is open over the level: its keys are its own (the HUD sets it).
var ui_panel_open: bool = false
## End turn is hovered (the HUD sets it): the hint line may show threat_summary. Nothing changes on the board.
var preview_enemy_phase: bool = false
## The tower type this level's first clear just gave (shown on the end screen), or null.
var reward: TowerAsset = null
## The previewed tiles' screen rects this frame (tooltips keep clear of them).
var preview_rects: Array = []

# ------------------------------------------------------------------ properties (the HUD reads these)

## The Director playing the level's log; busy while anything plays (see `director`).
## An entity's view on the board (its model, where its plate sits), or null.
func view_of(id: int) -> EntityView:
	return views.get_view(id) if views != null else null

## What the view shows now (the Director's frame), never the live state.
var shown: ViewFrame:
	get: return director.shown if director != null else null

## Player commands are accepted: nothing is playing, it is the player phase and the level runs.
var can_act: bool:
	get: return session != null and not director.busy and session.phase == Phase.Player and not session.is_over \
		and not (_sequence != null and _sequence.blocking)

## The speech-bubble sequence playing (the level's intro, the tutorial's steps, an entrance), or null.
var sequence: SequenceRun:
	get: return _sequence if _sequence != null and not _sequence.finished else null

## The unit the playing sequence is about (an enemy's entrance lines), or -1.
var sequence_subject: int:
	get: return _sequence_subject

var placing:
	get: return _placing
var selected: int:
	get: return _selected
var aiming: AbilityDef:
	get: return _aiming
## The tile under the pointer (Vector2i), or null.
var hover:
	get: return _hover

## Quick cast's combination is held: clicking an ability casts it at once where its instinct says.
var quick_cast_held: bool:
	get: return _modifier_held("QuickCast")

## The Instant Play setting.
var instant: bool:
	get:
		if instant_override != null: return instant_override
		var sd = _auto("SaveData")
		return sd != null and sd.settings.instant_playback
## The Always Show Health setting.
var always_show_health: bool:
	get:
		if always_show_health_override != null: return always_show_health_override
		var sd = _auto("SaveData")
		return sd == null or sd.settings.always_show_health
## The Follow Action setting.
var follow: bool:
	get:
		if follow_override != null: return follow_override
		var sd = _auto("SaveData")
		return sd != null and sd.settings.follow_action
## The Camera Follows Selection setting.
var follow_selection: bool:
	get:
		var sd = _auto("SaveData")
		return sd == null or sd.settings.follow_selection

## One line for the HUD: what to do now, or why the last command failed.
var hint: String:
	get:
		if setup_error != null: return setup_error
		if director != null and director.busy: return "Playing…  (%s skips one action)" % _key_first("Skip")
		if _placing != null:
			var p: TowerDef = session.tower(_placing)
			if p != null and session.energy < p.cost:
				return "Not enough energy to place %s (%d needed). Right-click cancels." % [p.name, p.cost]
			return "Click a free tile off the path. Right-click cancels."
		if _quick_key >= 0 or (quick_cast_held and _preview_ability != null): return _quick_cast_hint()
		if _aiming != null:
			if _route != null: return "Move the pointer along the way, click the destination."
			return _aim_instinct_hint() if quick_cast_held else "Click a green tile. Right-click cancels."
		if _message != null: return _message
		if preview_enemy_phase: return threat_summary
		return ""

## The hint line shows a refusal now (why the last command failed): the HUD draws it in red.
var hint_is_refusal: bool:
	get: return _message != null and setup_error == null and not (director != null and director.busy)

## The playing level is the tutorial.
var is_tutorial: bool:
	get:
		var app = _auto("GameApp")
		return app != null and level != null and app.is_tutorial(level)

## The end screen offers Retry: always, except after winning the tutorial.
var can_retry: bool:
	get: return not is_tutorial or session == null or session.outcome != Outcome.Won

## What the end screen's leave button says: "Camp" / "Level select"; the tutorial leads to the main menu.
var leave_label: String:
	get:
		if is_tutorial: return "Main menu"
		var app = _auto("GameApp")
		return app.home_label() if app != null else "Level select"

## The level the end screen's Next level opens: the first unlocked level after this one not won yet, or null.
var next_level_asset: LevelAsset:
	get:
		var app = _auto("GameApp")
		var sd = _auto("SaveData")
		if app == null or sd == null or level == null or app.catalog == null: return null
		var next: CatalogEntry = app.catalog.to_catalog().next_after(level.get_id(), sd.progress)
		return app.catalog.find_level(next.level_id) if next != null else null

## The coming enemy phase played ahead as things stand; null unless the player phase is on and nothing plays.
var enemy_forecast: PhaseForecast:
	get:
		if session == null or director.busy or session.phase != Phase.Player or session.is_over: return null
		if _enemy_forecast_version != version:
			_enemy_forecast = session.forecast_enemy_phase()
			_enemy_forecast_version = version
		return _enemy_forecast

# ------------------------------------------------------------------ lifecycle

func _ready() -> void:
	var flow = _auto("SceneFlow")
	if flow != null:
		flow.hold_loading_screen()
		_loading_held = true
	EntityView.show_corpses = show_corpses
	_last_ticks = Time.get_ticks_msec()
	_setup()
	if setup_error != null:
		push_warning("[Level] " + str(setup_error))
		setup_failed.emit(setup_error)

## Builds everything; on failure setup_error says why (and the scene stays empty but alive).
func _setup() -> void:
	var app = _auto("GameApp")
	var lib: ContentLibrary = app.lib if app != null else ContentLibrary.load("res://data/content")
	if LevelLaunch.has_request():
		level = LevelLaunch.level
		LevelLaunch.clear()
		_launched = true
	if level == null:
		for l in lib.all_of("LevelAsset"):
			if l.get_id() == test_level_id: level = l
	_rules_asset = lib.rules
	if _rules_asset == null or level == null:
		setup_error = "No level to play (GameApp.level_launch is empty and test level '%s' was not found)." % test_level_id
		return
	var problems := AssetValidator.validate_level(level)
	if problems.size() > 0:
		setup_error = "\n".join(problems)
		return
	PresentationTimings.current = PresentationTimings.from_library(lib)
	converter = AssetConverter.new()
	var hand: Array = []
	if level.fixed_hand != null:
		for t in level.fixed_hand:
			if t != null: hand.append(converter.tower(t, TowerIds.new_id()))
	if hand.is_empty(): hand = _saved_hand(app)
	if hand.is_empty(): hand = _test_hand(lib)
	var rules := converter.rules(_rules_asset)
	session = LevelSession.new(converter.level(level), rules, hand, maxi(1, level_seed))
	if session.last_error != "":
		setup_error = session.last_error
		session = null
		return
	recorder = FrameRecorder.of_session(session)
	_build_world()

	board = BoardView.new()
	add_child(board)
	board.build(session.state.grid, level, _rules_asset.tiles, _model_scene)
	var entities := Node3D.new()
	entities.name = "Entities"
	add_child(entities)
	views = EntityViews.new(entities,
		func(id): return _entity_scene(id),
		func(st): return _status_loop(st),
		func(id): return _plate_offset(id),
		func(n): return VfxKit.loop(n))
	camera = BoardCamera.new()
	camera.name = "Board Camera"
	camera.process_priority = -10 # moves before the overlay follows it
	add_child(camera)
	camera.current = true
	camera.keys = _auto("KeyBinds")
	var sd = _auto("SaveData")
	camera.drag_to_pan = sd == null or sd.settings.drag_to_pan
	var insets := default_hud_insets()
	camera.hud_insets = Vector4(0.0, insets.z, insets.x, insets.y)
	camera.init(session.state.grid.width, session.state.grid.height)
	board.set_camera(camera)
	overlay = BattleOverlay.new()
	add_child(overlay)
	overlay.setup(camera, func(st): return _status_icon(st))

	presenters = DefaultPresenters.new(views, overlay, session.state, board)
	presenters.sounds = GameSounds.new()
	presenters.status_name = status_name
	presenters.presentation_of = func(ability): return _presentation(ability)
	presenters.shake = func(amount): camera.shake(amount)
	presenters.faces_aim = func(ability):
		var a = converter.asset_of(ability, "AbilityAsset")
		return a != null and a.face_target_on_cast
	presenters.scene_of = _model_scene
	presenters.energy_ticked.connect(func(amount, energy): energy_ticked.emit(amount, energy))
	director = Director.new(session.log, presenters, recorder)
	director.beat_started.connect(_follow_action)
	director.beat_ended.connect(func(beat):
		views.sync(beat.frame)
		version += 1)
	views.sync(director.shown) # bases and anything present before the first event

	_add_hud()
	session.start()
	_start_intro()
	if not _launched:
		var audio = _auto("AudioMgr")
		if audio != null and flow_game_id() >= 0: audio.play_scene_music(flow_game_id(), level)
	version += 1

## The HUD over the level (game/ui/hud), when its scene exists.
var hud: Node = null

func _add_hud() -> void:
	if hud_scene_path == "" or not ResourceLoader.exists(hud_scene_path): return
	var scene: PackedScene = load(hud_scene_path)
	if scene == null: return
	hud = scene.instantiate()
	if "controller" in hud: hud.controller = self
	add_child(hud)
	if hud.has_method("bind"): hud.bind(self)

## The lights and sky of the diorama.
func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.11, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.82, 0.78)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 0.8
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var unscaled := clampf((now - _last_ticks) / 1000.0, 0.0, 0.1)
	_last_ticks = now
	_release_loading_screen_when_drawn()
	if session == null: return
	if _message != null and now / 1000.0 >= _message_until:
		_message = null
		message_changed.emit("")
		version += 1
	director.instant = instant
	director.tick(delta)
	overlay.always_show_health = always_show_health
	var focused := {}
	if _selected >= 0: focused[_selected] = true
	if _hover != null:
		var under: Entity = session.state.entity_at(_hover)
		if under != null: focused[under.id] = true
	overlay.focused = focused

	if _was_busy != director.busy:
		_was_busy = director.busy
		version += 1
	_check_entrances()
	_discover_for_codex()
	_tick_sequence(unscaled)
	if director.busy and _pressed("Skip"): skip()
	_handle_pause_keys()
	_handle_input()
	_draw_highlights()
	_update_board_feedback()

	if session.is_over: _record(false)
	var reading: bool = sequence != null and sequence.current != null and sequence.current.continue_on != SequenceContinue.Event
	if session.is_over and not director.busy and not _end_shown and not reading:
		_end_shown = true
		_cancel_modes()
		version += 1
		level_ended.emit(session.outcome)
	# after the camera moved this frame (it processes first): plates, markers and floaters follow it
	overlay.refresh(director.shown, views.all, unscaled)
	preview_rects.clear()
	board.highlight_screen_rects(camera, preview_rects)
	_update_sequence_marks()

## Lets the loading screen go once the level has drawn a few frames (models, HUD and their shaders ready).
func _release_loading_screen_when_drawn() -> void:
	if not _loading_held: return
	_frames_drawn += 1
	if _frames_drawn < 3 and setup_error == null: return
	_loading_held = false
	var flow = _auto("SceneFlow")
	if flow != null: flow.release_loading_screen()

func _exit_tree() -> void:
	if _loading_held:
		_loading_held = false
		var flow = _auto("SceneFlow")
		if flow != null: flow.release_loading_screen()
	if recorder != null: recorder.detach()
	if PresentationTimings.current != null: PresentationTimings.current = null

func _notification(what: int) -> void:
	# closing the game during the tutorial counts as skipping it (its reward given)
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_tutorial and session != null and not session.is_over:
		var sd = _auto("SaveData")
		if sd != null: sd.skip_tutorial()

# ------------------------------------------------------------------ public API (HUD commands)

## What the HUD covers, in canvas pixels (the camera fits the board in the rest): the top bar, the bottom row
## (hand tray + action bar) and the right bar (always counted). The HUD calls this when its layout changes.
func set_hud_insets(top: float, bottom: float, right: float) -> void:
	if camera != null: camera.set_hud_insets(top, bottom, right)

## The insets used until the HUD sets them (Vector3 top, bottom, right): top bar 96; bottom row 168, +140 when the
## tray and the action bar do not fit side by side at 1920 (130 per hand piece + 110 per ability > 1372); right
## bar 300.
func default_hud_insets() -> Vector3:
	var abilities := 0
	if session != null:
		for t in session.hand:
			if t.entity != null: abilities = maxi(abilities, t.entity.abilities.size())
		for id in session.bases:
			var b: Entity = session.state.get_entity(id)
			if b != null: abilities = maxi(abilities, b.abilities.size())
	var pieces := session.hand.size() if session != null else 0
	var bottom := 168.0 + (140.0 if 130 * pieces + 110 * abilities > 1372 else 0.0)
	return Vector3(96.0, bottom, 300.0)

## Continues the sequence's line when it waits for a click (the bubble's click).
func continue_sequence() -> void:
	if _sequence != null: _sequence.click()
	version += 1

## Ends the sequence at once (the bubble's Skip).
func skip_sequence() -> void:
	if _sequence != null: _sequence.skip()
	version += 1

## Starts placing a tower from the hand, or stops when it is already being placed.
func toggle_placing(tower_id: String) -> void:
	var was: bool = _placing == tower_id
	_cancel_modes()
	if not was and can_act:
		_placing = tower_id
		_selected = -1
	version += 1

## The tower whose tray piece is under the pointer (its ring lights on the board); -1 when none.
func preview_tower(id: int) -> void:
	_tray_hover = id

## Selects a placed tower from its tray piece; the camera glides to it when Camera Follows Selection is on.
func select_and_show(id: int) -> void:
	select(id)

## Selects an entity (its abilities and stats show in the HUD); -1 clears it.
func select(id: int) -> void:
	_cancel_modes()
	preview_ability(null, null)
	preview_aura(null, null)
	var cleared := id < 0 and _selected >= 0
	var changed_now := id != _selected
	_selected = id
	if changed_now and id >= 0 and follow_selection:
		var v := view_of(id)
		if v != null: camera.glide(v.global_position)
	_message = null
	if id >= 0 and _sequence != null: _sequence.notify(SequenceEvent.UnitSelected)
	if cleared and _sequence != null: _sequence.notify(SequenceEvent.SelectionCleared)
	version += 1

## Starts aiming one of the selected unit's abilities, or stops when it is already aimed.
func toggle_aim(ability: AbilityDef) -> void:
	var caster: Entity = session.state.get_entity(_selected) if session != null else null
	if _aiming == ability or caster == null:
		_cancel_modes()
		version += 1
		return
	if not can_act: return
	_cancel_modes()
	if not session.can_cast(caster, ability):
		_say(session.last_reason)
		version += 1
		return
	_aiming = ability
	_aims = Targeting.valid_aims(session.state, caster.id, ability)
	_route = RouteBuilder.new(session.state, caster, ability) if ability.targeting.shape == Shape.Steps else null
	if _aims.is_empty():
		_say("No valid target")
		_aiming = null
		_route = null
	version += 1

## Quick cast: casts the selected unit's ability at once, at its only valid aim or where its instinct says;
## otherwise the hint says why.
func quick_cast(ability: AbilityDef) -> void:
	var caster: Entity = session.state.get_entity(_selected) if session != null else null
	if caster == null or not can_act: return
	_cancel_modes()
	if not session.can_cast(caster, ability):
		_say(session.last_reason)
		version += 1
		return
	var aim: Aim = Instinct.quick_cast(session.state, caster, ability)
	if aim == null:
		_say(Instinct.last_reason)
		version += 1
		return
	_do(func(): return session.cast(caster, ability, aim))
	if _message == null: _notify_cast(ability, true)

## Shows an ability's range on the board while the HUD hovers it (null clears it).
func preview_ability(caster: Entity, ability: AbilityDef) -> void:
	_preview_caster = caster
	_preview_ability = ability

## Shows the tiles an aura covers around its owner while the HUD hovers its passive (null owner or an empty
## Condition clears it).
func preview_aura(owner: Entity, aura) -> void:
	_aura_owner = null if aura == null or aura.is_empty else owner
	_aura_preview = aura
	_aura_tiles = null

## Sells the selected placed tower.
func sell_selected() -> void:
	var e: Entity = session.state.get_entity(_selected) if session != null else null
	var tower_id = session.tower_id_of(e) if e != null else null
	if tower_id == null: return
	_do(func(): return session.sell(tower_id))
	_selected = -1

func end_round() -> void:
	if not can_act: return
	_do(func(): session.end_round(); return true)
	if _sequence != null: _sequence.notify(SequenceEvent.RoundEnded)

## Finishes the action that is playing.
func skip() -> void:
	if director == null or not director.busy: return
	director.skip()
	version += 1

## Plays the level again from the start (asking for the same level).
func retry() -> void:
	if level != null: LevelLaunch.request(level)
	var flow = _auto("SceneFlow")
	if flow != null and flow.current == flow_game_id(): flow.restart_current()
	else: get_tree().reload_current_scene()

## Goes home: the Camp once Chapter 1 is won, level select before (from the tutorial: the main menu); leaving a
## level that is still running saves it as quit.
func level_select() -> void:
	_record(true)
	var flow = _auto("SceneFlow")
	var app = _auto("GameApp")
	if flow == null: return
	_restore_speed()
	if is_tutorial: flow.go(flow.MainMenu)
	elif app != null: flow.go(app.home())
	else: flow.go(flow.LevelSelect)

## Leaves the tutorial for the main menu, counting it as skipped (its reward still given).
func skip_tutorial() -> void:
	_record(true)
	var sd = _auto("SaveData")
	if sd != null: sd.skip_tutorial()
	var flow = _auto("SceneFlow")
	if flow != null:
		_restore_speed()
		flow.go(flow.MainMenu)

## Plays the next level (see next_level_asset); does nothing when there is none.
func next_level() -> void:
	var next := next_level_asset
	if next == null: return
	LevelLaunch.request(next)
	var flow = _auto("SceneFlow")
	if flow != null:
		_restore_speed()
		flow.go(flow.Game)

## Saves the level as quit if it is still running (leaving the game from the pause menu).
func record_quit() -> void:
	_record(true)

## The name players see for a status ID.
func status_name(id: String) -> String:
	if converter != null:
		for d in converter.built("StatusDef"):
			if d.name == id: return d.display_name
	return id

## Shows a refusal on the hint line for a few seconds, e.g. a key pressed on an ability that isn't ready.
func refuse(text: String) -> void:
	_say(text)
	version += 1

## An enemy's coming turn from the enemy phase forecast: "Next: Smash on Archer", "Next: moves 2",
## "Next: waits", or "" outside your idle turn.
func next_turn_line(enemy: Entity) -> String:
	var forecast := enemy_forecast
	if enemy == null or forecast == null or not forecast.steps.has(enemy.id): return ""
	var parts: Array[String] = []
	for step in forecast.steps[enemy.id]:
		if step.is_movement:
			parts.append("moves %d" % (step.aim.path.size() if step.aim.path != null else 1))
			continue
		var names: Array[String] = []
		for id in step.preview.targets:
			var t: Entity = session.state.get_entity(id)
			if t != null and t != enemy and not names.has(t.def.display_name): names.append(t.def.display_name)
		parts.append("%s on %s" % [step.ability.display_name, ", ".join(names)] if names.size() > 0 else step.ability.display_name)
	return "Next: " + ", then ".join(parts) if parts.size() > 0 else "Next: waits"

## Where a sequence line points in the world (its target's ground), or null (a HUD element, nothing, gone).
func sequence_target_world(line: SequenceLine):
	if line == null or shown == null: return null
	var f: EntityFrame = null
	match line.point_at:
		SequencePointAt.Speaker: f = _base_frame()
		SequencePointAt.FirstEnemy: f = _first_frame(func(e): return e.kind == EntityKind.Unit and e.team == Teams.Enemy and e.tower_id == null)
		SequencePointAt.FirstTower: f = _first_frame(func(e): return e.tower_id != null)
		SequencePointAt.Subject: f = shown.get_frame(_sequence_subject)
		SequencePointAt.Tile: return GridSpace.to_world(Vector2i(line.tile_x, line.tile_y))
		_: return null
	return GridSpace.to_world(f.pos) if f != null else null

## Where a sequence line points on screen (canvas pixels): its target's head (ground = false) or feet, or null.
func sequence_target_screen(line: SequenceLine, ground: bool = false):
	var w = sequence_target_world(line)
	if w == null or camera == null: return null
	var p: Vector3 = w + Vector3.UP * (0.05 if ground else 1.1)
	if camera.is_position_behind(p): return null
	return camera.unproject_position(p)

func _base_frame() -> EntityFrame:
	if session == null or session.bases.is_empty() or shown == null: return null
	return shown.get_frame(session.bases[0])

func _first_frame(pred: Callable) -> EntityFrame:
	if shown == null: return null
	for f in shown.entities.values():
		if f.life == LifeState.Alive and f.position != null and pred.call(f): return f
	return null

# ------------------------------------------------------------------ input

## The pause menu's keys, also while an action plays: P asks for it; Esc asks when nothing is placed or aimed.
## Neither works while a panel is open (ui_panel_open) or the end screen shows.
func _handle_pause_keys() -> void:
	if ui_panel_open or _end_shown: return
	if _pressed("Pause"):
		_cancel_modes()
		version += 1
		pause_requested.emit()
		return
	if _back_pressed() and _placing == null and _aiming == null and _quick_key < 0: pause_requested.emit()

func _handle_input() -> void:
	var vp := get_viewport()
	var over_ui := vp != null and vp.gui_get_hovered_control() != null
	var mouse := vp.get_mouse_position() if vp != null else Vector2.ZERO
	var was = _hover
	_hover = null if over_ui else GridSpace.tile_under(camera, mouse, session.state.grid)
	if hover_override != null: _hover = hover_override if session.state.grid.in_bounds(hover_override) else null
	if _route != null and _hover != null: _route.hover(_hover)
	if was != _hover and _aiming != null: version += 1

	var left := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var right := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var left_pressed := left and not _was_left
	var left_released := not left and _was_left
	var right_pressed := right and not _was_right
	_was_left = left
	_was_right = right
	if ui_panel_open: return

	# Esc cancels a mode first; right-click over the HUD only cancels (it never deselects there)
	if right_pressed or _back_pressed():
		if _quick_key >= 0:
			_quick_key = -1
			version += 1
		elif _placing != null or _aiming != null:
			_cancel_modes()
			version += 1
		elif right_pressed and not over_ui and _selected >= 0:
			select(-1)
		return
	# End round: its keys (Enter, Shift+Space; Space alone skips while an action plays)
	if _pressed("EndRound"):
		end_round()
		return
	var hand := _modifier_held("Hand")
	var ability_keys := _modifier_held("Aim") or quick_cast_held
	_hold_preview(ability_keys)
	# Quick cast + 1–9 held: its range and quick-cast target show; letting the number go casts it
	if _quick_key >= 0 and not _held("Ability%d" % (_quick_key + 1)):
		var key := _quick_key
		_quick_key = -1
		var holder := _selected_tower()
		if holder != null and key < holder.abilities.size(): quick_cast(holder.abilities[key])
		version += 1
	for i in 9:
		if not _pressed("Ability%d" % (i + 1)): continue
		if hand:
			if i < session.hand.size(): _select_hand(i)
		elif ability_keys and _selected_tower() != null: _select_ability(i)
		return
	# a board click acts when the button comes up, only when the press started on the board and did not drag the map
	if left_pressed: _board_press = not over_ui
	if not left_released: return
	var click := _board_press and not camera.left_dragged
	_board_press = false
	if not click or over_ui or _hover == null: return
	_click_tile(_hover)

## A click on a board tile (also used by tools): select, place or cast as the mode says.
func click_tile(p: Vector2i) -> void:
	_click_tile(p)

func _click_tile(p: Vector2i) -> void:
	if not can_act: # while an action plays: clicks only select, from what is shown
		select(_shown_entity_at(p))
		return
	if _placing != null:
		if session.can_place(_placing, p):
			var tower_id: String = _placing
			_do(func(): return session.place(tower_id, p))
			var placed := session.placed_tower(tower_id)
			if placed != null:
				_selected = placed.id
				if _sequence != null: _sequence.notify(SequenceEvent.TowerPlaced)
		else:
			_say(session.last_reason)
			version += 1
		return
	if _aiming != null:
		var caster: Entity = session.state.get_entity(_selected)
		var aim: Aim = null
		if _route != null:
			_route.hover(p)
			aim = _route.to_aim()
		else:
			for a in _aims:
				if a.tile == p:
					aim = a
					break
		if caster != null and aim != null and aim.tile == p:
			var ability := _aiming
			_do(func(): return session.cast(caster, ability, aim))
			if _message == null: _notify_cast(ability, false)
			return
		_cancel_modes()
	var at: Entity = session.state.entity_at(p)
	if at == null:
		var hz: Array = session.state.hazards_at(p)
		if hz.size() > 0: at = hz[0]
	select(at.id if at != null else -1)

## The Hand modifier + 1–9: a placed tower is selected, a tower in the hand starts (or stops) placing.
func _select_hand(index: int) -> void:
	var tower_id: String = session.hand[index].id
	var placed := session.placed_tower(tower_id)
	if placed != null: select(placed.id)
	elif can_act: toggle_placing(tower_id)

## The selected entity when the player commands it (a placed tower, a base or an ally), else null.
func _selected_tower() -> Entity:
	var e: Entity = session.state.get_entity(_selected)
	return e if session.is_commanded(e) else null

## While an ability key is held with a commanded unit selected, its ability's range shows as if its row were
## hovered (also when it cannot be cast now); letting go clears it.
func _hold_preview(ability_keys: bool) -> void:
	var caster := _selected_tower() if ability_keys else null
	var held_ability: AbilityDef = null
	if caster != null:
		for i in mini(9, caster.abilities.size()):
			if _held("Ability%d" % (i + 1)):
				held_ability = caster.abilities[i]
				break
	if held_ability != null:
		if _preview_ability != held_ability or _preview_caster != caster:
			preview_ability(caster, held_ability)
			version += 1
		_key_preview = true
	elif _key_preview:
		_key_preview = false
		preview_ability(null, null)
		version += 1

## An ability key with a commanded unit selected: aims its ability (toggles off when already aimed); with Quick
## cast, it waits for the key to be let go and then quick casts (right-click before that cancels).
func _select_ability(index: int) -> void:
	var caster := _selected_tower()
	if caster == null or index >= caster.abilities.size(): return
	if quick_cast_held:
		_quick_key = index
		version += 1
	else: toggle_aim(caster.abilities[index])

## The entity standing on a tile in the shown frame (what the player sees while an action plays), else -1.
func _shown_entity_at(p: Vector2i) -> int:
	for f in director.shown.entities.values():
		if f.position != null and f.pos == p and f.life == LifeState.Alive: return f.id
	return -1

func _say(text: String) -> void:
	if text == "": text = "That cannot be done now" # a refusal always says something
	_message = text
	_message_until = Time.get_ticks_msec() / 1000.0 + MESSAGE_SECONDS
	message_changed.emit(text)

## Runs a command; a refused one (the sim's push_error path returns null/false) shows its reason.
func _do(command: Callable) -> void:
	var ok = command.call()
	if ok == null or (ok is bool and not ok): _say(session.last_reason if session.last_reason != "" else "That cannot be done now")
	else: _message = null
	_cancel_modes()
	version += 1

func _cancel_modes() -> void:
	_quick_key = -1
	_placing = null
	_aiming = null
	_aims = []
	_route = null

# ------------------------------------------------------------------ highlights

enum Preview { RANGE, TARGET, AREA, LINE, ROUTE, BLOCKED, PLACE, HOVER, ENEMY_PATH, ENEMY_STOP, ENEMY_AREA, ENEMY_LINE, ENEMY_TARGET, MOVE, DEST, PLACE_BLOCKED, HEAL }

const RANGE_COLOR := Color(0.35, 0.65, 1.0, 0.25)
const AIM_COLOR := Color(0.3, 0.9, 0.4, 0.45)
const AREA_COLOR := Color(1.0, 0.45, 0.15, 0.55)
const BLOCKED_COLOR := Color(0.9, 0.25, 0.25, 0.3)
const STOP_COLOR := Color(1.0, 0.6, 0.1, 0.7)
const HOVER_COLOR := Color(1.0, 1.0, 1.0, 0.2)
const SELECT_COLOR := Color(0.3, 0.56, 0.9, 0.6)
const PLACE_COLOR := Color(0.3, 0.9, 0.4, 0.3)

static func _decal(n: String) -> Texture2D:
	return OverlayStyle.kit(n)

## Marks a tile for a preview with the kit's decal (a missing decal falls back to the target decal tinted, then to
## the flat colour); valid targets pulse. yaw in Unity degrees (0: the decal's top points north, clockwise).
func _mark(p: Vector2i, kind: int, yaw: float = 0.0) -> void:
	var fallback := _decal("board/decal_target_valid")
	var decal: Texture2D = null
	var tint := Color.WHITE
	var flat := Color.TRANSPARENT
	var size := 0.96
	var lift := 0.02
	match kind:
		Preview.RANGE: decal = _decal("board/decal_range"); tint = Color(1, 1, 1, 0.9); flat = RANGE_COLOR
		Preview.TARGET: decal = fallback; tint = Color(1, 1, 1, _pulse_alpha()); flat = AIM_COLOR; lift = 0.025
		Preview.AREA:
			decal = _decal("board/decal_area"); tint = Color(1, 1, 1, 0.9); flat = AREA_COLOR; lift = 0.03
			if decal == null: decal = fallback; tint = Color(1, 0.82, 0.4, 0.8)
		Preview.LINE: flat = Color(1, 0.25, 0.2, 0.8); size = 0.25; lift = 0.05
		Preview.ROUTE:
			decal = _decal("board/decal_move_step"); lift = 0.04
			if decal == null: flat = Color(1, 1, 1, 0.7); size = 0.3
		Preview.MOVE: decal = _decal("board/decal_move"); tint = Color(1, 1, 1, 0.9); flat = RANGE_COLOR
		Preview.DEST: decal = _decal("board/decal_move_dest"); flat = AIM_COLOR; lift = 0.045
		Preview.PLACE_BLOCKED: decal = _decal("board/decal_place_blocked"); tint = Color(1, 1, 1, 0.9)
		Preview.HEAL:
			decal = _decal("board/decal_heal_valid"); tint = Color(1, 1, 1, _pulse_alpha()); flat = AIM_COLOR; lift = 0.025
			if decal == null: decal = fallback
		Preview.BLOCKED: flat = BLOCKED_COLOR
		Preview.PLACE: decal = _decal("board/decal_place"); tint = Color(1, 1, 1, 0.9); flat = PLACE_COLOR
		Preview.HOVER: flat = HOVER_COLOR; lift = 0.035
		Preview.ENEMY_PATH: decal = _decal("board/decal_enemy_path"); tint = Color(1, 1, 1, 0.9); flat = Color(1, 1, 1, 0.7); lift = 0.04
		Preview.ENEMY_STOP: decal = _decal("board/decal_enemy_stop"); flat = STOP_COLOR; lift = 0.045
		Preview.ENEMY_AREA:
			decal = _decal("board/decal_enemy_stop"); tint = Color(1, 0.45, 0.4, 0.75); flat = AREA_COLOR; lift = 0.03
			if decal == null: decal = fallback
		Preview.ENEMY_LINE: flat = Color(1, 0.25, 0.2, 0.8); size = 0.25; lift = 0.05
		_: decal = fallback; tint = Color(1, 0.5, 0.45, _pulse_alpha()); flat = BLOCKED_COLOR; lift = 0.025
	if decal != null: board.highlight(p, tint, size, lift, decal, GridSpace.decal_yaw(yaw))
	elif flat.a > 0.0: board.highlight(p, flat, size, lift)

## A valid target's mark: green (heals, buffs) on someone on the caster's side, else the target decal.
func _target_kind(caster: Entity, tile: Vector2i) -> int:
	var on: Entity = session.state.entity_at(tile)
	if on != null and on != caster and session.state.effective_team(on) == session.state.effective_team(caster): return Preview.HEAL
	return Preview.TARGET

## A walk's route: a dot on each step, and the destination ring with its chevron turned along the last step.
func _mark_route(from: Vector2i, path) -> void:
	if path == null or path.is_empty(): return
	for i in path.size() - 1: _mark(path[i], Preview.ROUTE)
	var end: Vector2i = path[path.size() - 1]
	var before: Vector2i = path[path.size() - 2] if path.size() > 1 else from
	var dx := end.x - before.x
	var dy := end.y - before.y
	var yaw := 90.0 if dx > 0 else (270.0 if dx < 0 else (180.0 if dy < 0 else 0.0))
	_mark(end, Preview.DEST, yaw)

## The valid targets' pulse (pulse.target 0.9 s), in six steps so only a few materials exist.
static func _pulse_alpha() -> float:
	var period := 0.9
	var k := pingpong(Time.get_ticks_msec() / 1000.0 * 2.0 / period, 1.0)
	return roundf(lerpf(0.55, 1.0, k) * 6.0) / 6.0

## The soft glow under a unit that can still act.
func _ready_glow(p: Vector2i) -> void:
	var glow := _decal("cooldown/ready_glow")
	if glow != null: board.highlight(p, Color(1, 1, 1, 0.8), 1.3, 0.015, glow)
	else: board.highlight(p, Color(0.45, 0.7, 1.0, 0.22), 0.96, 0.015)

## The cobalt selection ring on a tile.
func _selection_ring(p: Vector2i, strength: float) -> void:
	var ring := _decal("board/decal_select_ring")
	if ring != null: board.highlight(p, Color(1, 1, 1, strength), 1.15, 0.03, ring)
	else: board.highlight(p, Color(SELECT_COLOR, SELECT_COLOR.a * strength))

## The units you command that can still cast something besides walking (cached per version).
func _ready_units_now() -> Array:
	if _ready_version == version: return _ready_units
	_ready_version = version
	_ready_units = []
	var reason := session.last_reason
	for unit in session.player_units:
		if not unit.on_board: continue
		for a in unit.abilities:
			if not a.targeting.is_movement and session.can_cast(unit, a):
				_ready_units.append(unit)
				break
	session.last_reason = reason
	return _ready_units

func _draw_highlights() -> void:
	board.clear_highlights()
	if director.busy: return
	var caster: Entity = session.state.get_entity(_selected)
	if caster != null and caster.on_board: _selection_ring(caster.pos, 1.0)
	if _tray_hover >= 0 and _tray_hover != _selected:
		var lit: Entity = session.state.get_entity(_tray_hover)
		if lit != null and lit.on_board: _selection_ring(lit.pos, 0.5)

	if _placing != null:
		var grid := session.state.grid
		var reason := session.last_reason
		for x in grid.width:
			for y in grid.height:
				var p := Vector2i(x, y)
				if session.can_place(_placing, p): _mark(p, Preview.PLACE)
				elif grid.buildable.has(p): _mark(p, Preview.PLACE_BLOCKED)
		session.last_reason = reason

	# an enemy's ability row hovered (the HUD's enemy card): only that ability in its coming turn, played on a copy
	# of the state — its walk, stop tile, attack line; nothing of its range
	if _aiming == null and _preview_ability != null and _preview_caster != null and _preview_caster.on_board and not session.is_commanded(_preview_caster):
		var only := []
		for st in _forecast_of(_preview_caster):
			if st.ability == _preview_ability: only.append(st)
		_draw_forecast(_preview_caster, only)
	elif _aiming == null and _preview_ability != null and _preview_caster != null and _preview_caster.on_board and _preview_caster.id == _selected:
		var walk := _preview_ability.targeting.is_movement
		for t in AimPreview.range(session.state, _preview_caster.id, _preview_ability): _mark(t, Preview.MOVE if walk else Preview.RANGE)
		for t in AimPreview.blocked(session.state, _preview_caster.id, _preview_ability): _mark(t, Preview.BLOCKED)
		if not walk:
			for a in Targeting.valid_aims(session.state, _preview_caster.id, _preview_ability): _mark(a.tile, _target_kind(_preview_caster, a.tile))
		if (quick_cast_held or _quick_key >= 0) and _selected_tower() == _preview_caster:
			var quick: Aim = Instinct.quick_cast(session.state, _preview_caster, _preview_ability)
			if quick != null:
				var preview := AimPreview.for_aim(session.state, _preview_caster.id, _preview_ability, quick)
				for t in preview.area: _mark(t, Preview.AREA)
				for t in preview.line: _mark(t, Preview.LINE)
				_attack_lines(_preview_caster.pos, _preview_ability, quick, preview, false)
				if quick.path != null: _mark_route(_preview_caster.pos, quick.path)

	# hovering an enemy on the board: its whole coming turn (intent shows on hover only)
	var hovered := _hovered_enemy()
	if hovered != null: _draw_forecast(hovered, _forecast_of(hovered))

	# a soft glow under each unit you command that can still act this turn
	if session.phase == Phase.Player and not session.is_over:
		for unit in _ready_units_now(): _ready_glow(unit.pos)

	if _aiming == null and _aura_owner != null and _aura_owner.on_board:
		if _aura_tiles == null or _aura_at != _aura_owner.pos:
			_aura_tiles = AimPreview.aura_range(session.state, _aura_owner.id, _aura_preview)
			_aura_at = _aura_owner.pos
		for t in _aura_tiles: _mark(t, Preview.RANGE)

	if _aiming != null and caster != null:
		var walk := _aiming.targeting.is_movement
		for t in AimPreview.range(session.state, caster.id, _aiming): _mark(t, Preview.MOVE if walk else Preview.RANGE)
		if not walk:
			for a in _aims: _mark(a.tile, _target_kind(caster, a.tile))
		if _route != null: _mark_route(caster.pos, _route.path)
		var shown_aim: Aim = null
		if quick_cast_held: shown_aim = Instinct.quick_cast(session.state, caster, _aiming)
		elif _hover != null:
			for a in _aims:
				if a.tile == _hover:
					shown_aim = a
					break
		if _route == null and shown_aim != null:
			var preview := AimPreview.for_aim(session.state, caster.id, _aiming, shown_aim)
			for t in preview.area: _mark(t, Preview.AREA)
			for t in preview.line: _mark(t, Preview.LINE)
			_attack_lines(caster.pos, _aiming, shown_aim, preview, false)
	if _hover != null: _mark(_hover, Preview.HOVER)

## The enemy under the pointer (not one you command), while nothing is placed, aimed or previewed.
func _hovered_enemy() -> Entity:
	if _hover == null or _placing != null or _aiming != null or _preview_ability != null or director.busy: return null
	var e: Entity = session.state.entity_at(_hover)
	return e if e != null and e.alive and e.kind == EntityKind.Unit and not session.is_commanded(e) else null

## Casts played ahead on the board: a walk's route and stop tile, an attack's area and line.
func _draw_forecast(caster: Entity, steps: Array) -> void:
	var at: Vector2i = caster.pos if caster != null else Vector2i.ZERO
	for step in steps:
		if step.is_movement:
			if step.aim.path != null:
				for p in step.aim.path: _mark(p, Preview.ENEMY_PATH)
			_mark(step.aim.tile, Preview.ENEMY_STOP)
			at = step.aim.tile
			continue
		for t in step.preview.area: _mark(t, Preview.ENEMY_AREA)
		for t in step.preview.line: _mark(t, Preview.ENEMY_LINE)
		if caster != null: _attack_lines(at, step.ability, step.aim, step.preview, true)

## The line an attack takes to where it really lands (hud-menu-spec §6.8, attack preview by delivery; all from the
## game's own dry run — preview.targets are the units really hit). Enemy red or player cobalt (the kit's two sprite
## sets), never mixed. Melee: a short chevron on the attacker → target edge. Projectile: a straight dashed line low
## over the board, scrolling, stopping at the first blocker (✕ there) with an end dot. Lobbed: a dotted high arc
## (apex 0.35 × distance), an impact ring on the landing tile and a splash decal on each area tile. Spell: a rune
## under the target and a faint link. Beam: a solid low line to every unit hit.
func _attack_lines(from: Vector2i, ability: AbilityDef, aim: Aim, preview: AimPreview, enemy: bool) -> void:
	if ability == null or (ability.targeting != null and ability.targeting.is_movement): return
	var side := "enemy" if enemy else "player"
	var hits: Array = []
	for id in preview.targets:
		var t: Entity = session.state.get_entity(id)
		if t != null and t.on_board and t.pos != from and not hits.has(t.pos): hits.append(t.pos)
	var aimed_tile: Vector2i = aim.tile if aim != null else from
	if ability.tags.has(Tags.Melee):
		var ends := hits if hits.size() > 0 else ([aimed_tile] if aimed_tile != from else [])
		for end in ends:
			var d: Vector2i = end - from
			var at := GridSpace.to_world(from).lerp(GridSpace.to_world(end), 0.55) + Vector3.UP * 0.06
			board.decal_at(at, _decal("attack/atk_melee_chevron_" + side), Color.WHITE, 0.42,
				GridSpace.decal_yaw(rad_to_deg(atan2(float(d.x), float(d.y)))), true)
		return
	if ability.tags.has(Tags.Lobbed):
		var land := aimed_tile
		var a := GridSpace.to_world(from, 0.5)
		var b := GridSpace.to_world(land, 0.1)
		board.line(a, b, _decal("attack/atk_lob_dots_" + side), Color.WHITE, 0.12, 0.35 * a.distance_to(b))
		var ring := _decal("attack/atk_impact_ring_" + side)
		if ring != null: board.highlight(land, Color.WHITE, 1.05, 0.05, ring)
		var splash := _decal("attack/atk_splash_" + side)
		if splash != null:
			for t in preview.area:
				if t != land: board.highlight(t, Color(1, 1, 1, 0.85), 0.9, 0.048, splash)
		return
	if ability.tags.has(Tags.Spell):
		var ends2 := hits if hits.size() > 0 else ([aimed_tile] if aimed_tile != from else [])
		for end in ends2:
			var s0 := GridSpace.to_world(from, 0.3)
			var e0 := GridSpace.to_world(end, 0.3)
			board.line(s0.move_toward(e0, 0.35), e0.move_toward(s0, 0.35), _decal("attack/atk_spell_link_" + side), Color(1, 1, 1, 0.45), 0.08, 0.0, true, true)
			var rune := _decal("attack/atk_rune_" + side)
			if rune != null: board.highlight(end, Color.WHITE, 0.95, 0.05, rune)
		return
	if ability.tags.has(Tags.Beam):
		for end in (hits if hits.size() > 0 else [aimed_tile]):
			var s1 := GridSpace.to_world(from, 0.3)
			var e1 := GridSpace.to_world(end, 0.3)
			board.line(s1.move_toward(e1, 0.35), e1, _decal("attack/atk_beam_" + side), Color.WHITE, 0.1, 0.0, false, true)
		return
	# Projectile (and any attack without a delivery): straight, low, to the first unit or wall it really hits
	var land2 := aimed_tile
	var blocked := false
	var aimed: Entity = Instinct.target_of(session.state, ability, aim) if aim != null else null
	if hits.size() > 0:
		land2 = hits[0]
		if aimed != null and aimed.on_board and not hits.has(aimed.pos): blocked = true
	elif preview.line.size() > 0 and preview.line[preview.line.size() - 1] != aimed_tile:
		land2 = preview.line[preview.line.size() - 1]
		blocked = true
	if land2 == from: return
	var s2 := GridSpace.to_world(from, 0.3)
	var e2 := GridSpace.to_world(land2, 0.3)
	var tip := e2.move_toward(s2, 0.15)
	board.line(s2.move_toward(e2, 0.2), tip, _decal("attack/atk_line_dash_" + side), Color.WHITE, 0.09, 0.0, true, true, 0.6)
	# the end point: the kit's red dot for the enemy, a gold one for the player (colours never mixed)
	var dot := _decal("board/line_attack_end" if enemy else "badges/badge_circle_gold")
	if dot != null: board.decal_at(tip, dot, Color.WHITE, 0.16, 0.0, true)
	if blocked: board.decal_at(GridSpace.to_world(land2, 0.35), _decal("attack/atk_blocked_x"), Color.WHITE, 0.45, 0.0, true)

## While End turn is hovered: the whole enemy phase as one line of text for the HUD's hint line (no board marks:
## the board shows only the hovered enemy's intent). "Base −4 · Archer −6"; a unit it would kill reads "Archer −6
## (falls)"; "" outside your idle turn; "No damage this turn" when nothing of yours is hit.
var threat_summary: String:
	get:
		var forecast := enemy_forecast
		if forecast == null: return ""
		var parts: Array[String] = []
		for unit in session.player_units:
			if not unit.on_board: continue
			var lost := int(forecast.loss.get(unit.id, 0))
			if lost <= 0 and not forecast.killed.has(unit.id): continue
			parts.append("%s −%d%s" % [unit.def.display_name if unit.def != null else unit.name, lost, " (falls)" if forecast.killed.has(unit.id) else ""])
		return " · ".join(parts) if parts.size() > 0 else "No damage this turn"

## The hovered enemy's coming turn (after the enemies before it), played on a copy of the state; cached per version.
func _forecast_of(enemy: Entity) -> Array:
	if _forecast == null or _forecast_for != enemy.id or _forecast_version != version:
		var before: Array[int] = []
		for e in session.enemy_order():
			if e.id == enemy.id: break
			before.append(e.id)
		_turn_forecast = TurnForecast.turn(session.state, enemy.id, before)
		_forecast = _turn_forecast.steps.get(enemy.id, [])
		_forecast_for = enemy.id
		_forecast_version = version
	return _forecast

# ------------------------------------------------------------------ board feedback (forecast markers, pops)

## "Ready!" pops when the player's turn starts on screen; the markers when something changed.
func _update_board_feedback() -> void:
	var f := director.shown
	if f == null: return
	if f.phase != _last_shown_phase:
		if f.phase == Phase.Player and _last_shown_phase != Phase.NotStarted: _pop_ready(f)
		_last_shown_phase = f.phase
	var key := [version, _preview_ability, _aiming, _hover, preview_enemy_phase]
	if _markers_key == key: return
	_markers_key = key
	var health_preview := {}
	overlay.set_markers(_build_markers(health_preview))
	overlay.set_health_preview(health_preview)

## "Ready!" over each unit you command that has a ready ability besides walking.
func _pop_ready(f: ViewFrame) -> void:
	for unit in session.player_units:
		var frame: EntityFrame = f.get_frame(unit.id)
		var view := view_of(unit.id)
		if frame == null or frame.life != LifeState.Alive or view == null: continue
		for a in unit.abilities:
			if not a.targeting.is_movement and not frame.cooldowns.has(a):
				overlay.float_text(view.head_position, "Ready!", OverlayStyle.GOOD, -1.0, 34)
				break

## What shows over entities: the hovered enemy's coming turn; while End turn is hovered, the whole enemy phase;
## and the ability hovered or aimed now. "-N" / "+N", the HP it would leave striped on the bar, "Kills".
func _build_markers(health_preview: Dictionary) -> Array:
	var markers := {}
	var for_id := func(id: int) -> OverlayMarker:
		if not markers.has(id): markers[id] = OverlayMarker.new(id)
		return markers[id]
	var show := func(forecast: PhaseForecast, skip_id: int) -> void:
		var ids := {}
		for id in forecast.loss: ids[id] = true
		for id in forecast.hp: ids[id] = true
		for id in forecast.killed: ids[id] = true
		for id in ids:
			var target: Entity = session.state.get_entity(id)
			if id == skip_id or target == null or not target.on_board: continue
			var m: OverlayMarker = for_id.call(id)
			if forecast.killed.has(id):
				m.chip = _decal("board/tag_kills")
				m.text = "Kills"
				m.text_color = Color.WHITE
			elif forecast.loss.has(id):
				# a base reads "Base −4" (its HP is the level's), anyone else a bare "−6" over the plate
				m.text = ("%s −%d" % [target.def.display_name, int(forecast.loss[id])]) if session.bases.has(id) else "−%d" % int(forecast.loss[id])
				m.text_color = OverlayStyle.FX_DAMAGE
			elif forecast.hp.has(id) and int(forecast.hp[id]) > target.hp:
				m.text = "+%d" % (int(forecast.hp[id]) - target.hp)
				m.text_color = OverlayStyle.FX_HEAL
			if forecast.hp.has(id): health_preview[id] = int(forecast.hp[id])
		# everyone the casts hit shows their HP bar, even when their HP stays
		for steps in forecast.steps.values():
			for step in steps:
				if step.is_movement: continue
				for tid in step.preview.targets:
					var hit: Entity = session.state.get_entity(tid)
					if tid != skip_id and not health_preview.has(tid) and hit != null and hit.on_board and hit.alive: health_preview[tid] = hit.hp
	var enemy := _hovered_enemy()
	if enemy != null:
		_forecast_of(enemy)
		if _turn_forecast != null: show.call(_turn_forecast, enemy.id)
	elif _preview_ability != null and _preview_caster != null and not session.is_commanded(_preview_caster) and not director.busy:
		# an enemy's ability row: what its turn would do, when that ability is part of it
		var uses := false
		for st in _forecast_of(_preview_caster): uses = uses or st.ability == _preview_ability
		if uses and _turn_forecast != null: show.call(_turn_forecast, _preview_caster.id)
	var caster: Entity = _preview_caster if _preview_ability != null else (session.state.get_entity(_selected) if _aiming != null else null)
	var shown_ability: AbilityDef = _preview_ability if _preview_ability != null else _aiming
	if caster != null and shown_ability != null and not shown_ability.targeting.is_movement and session.is_commanded(caster) and not director.busy:
		var aim: Aim = null
		if _aiming != null and _hover != null:
			for a in _aims:
				if a.tile == _hover:
					aim = a
					break
		if aim == null: aim = Instinct.quick_cast(session.state, caster, shown_ability)
		if aim != null: show.call(TurnForecast.cast(session.state, caster.id, shown_ability, aim), -1)
	return markers.values()

# ------------------------------------------------------------------ helpers

## Follow the action: at an action's first beat the camera glides to centre the entities it involves (only actions
## that happen somewhere: a cast, an enemy's turn, a spawn, a level event, placing or selling).
func _follow_action(beat: BeatPlayback) -> void:
	if not follow or director.instant or beat.action == null or beat.action.id == _last_followed_action: return
	_last_followed_action = beat.action.id
	var k: int = beat.action.kind
	if not (k == ActionKind.Cast or k == ActionKind.EnemyTurn or k == ActionKind.Spawn or k == ActionKind.LevelEvent or k == ActionKind.Place or k == ActionKind.Sell): return
	var points := []
	var add := func(id: int) -> void:
		if id <= 0: return
		var f: EntityFrame = beat.frame.get_frame(id) if beat.frame != null else null
		if f != null: points.append(GridSpace.to_world(f.pos))
		else:
			var v := view_of(id)
			if v != null: points.append(v.global_position)
	add.call(beat.action.actor)
	for e in beat.events:
		add.call(e.source)
		add.call(e.target)
		if e.targets != null:
			for t in e.targets: add.call(t)
	camera.glide_to(points)

## The hand from the save (owned towers in the hand), or [] without a save or a catalog.
func _saved_hand(app) -> Array:
	var sd = _auto("SaveData")
	if app == null or sd == null or app.catalog == null: return []
	var problems: Array = []
	var hand: Array = app.catalog.build_hand(sd.towers, converter, problems)
	for p in problems: push_warning("[Level] hand: " + str(p))
	return hand if hand != null else []

## The test hand (TowerAsset ids) when nothing else gives one.
func _test_hand(lib: ContentLibrary) -> Array:
	var hand: Array = []
	var i := 0
	for id in test_hand:
		for t in lib.all_of("TowerAsset"):
			if t.get_id() == id:
				hand.append(converter.tower(t, "test-%d-%s" % [i, id]))
				i += 1
				break
	return hand

## Saves the level's result once: won or lost when it ends, quit when it is left while running.
func _record(quit: bool) -> void:
	var sd = _auto("SaveData")
	var app = _auto("GameApp")
	if _recorded or session == null or level == null or sd == null: return
	_recorded = true
	var result := LevelResults.from(session, level.get_id(), Time.get_datetime_string_from_system(true) + "Z", quit)
	var rec: LevelRecord = sd.progress.record(result)
	if is_tutorial:
		reward = sd.complete_tutorial() if result.won and not result.quit else null
	elif app != null and app.catalog != null:
		reward = app.catalog.grant_first_clear_reward(result, rec, sd.towers)
	sd.save()

## The level's intro plays the first time the level is played (the tutorial's: until it is finished).
func _start_intro() -> void:
	if level.intro == null or level.intro.lines.is_empty(): return
	var sd = _auto("SaveData")
	var profile: PlayerProfile = sd.profile if sd != null else null
	var play: bool
	if is_tutorial: play = profile == null or not profile.created or profile.tutorial_pending
	else: play = profile == null or not profile.has_seen_intro(level.get_id())
	if not play: return
	_play(level.intro, profile, "" if is_tutorial else level.get_id())

## The first time the player meets an enemy whose asset has entrance lines (a boss), the base speaks them,
## pointing at it, once its arrival has played. One at a time: they wait for any other sequence.
func _check_entrances() -> void:
	if director.busy or session.is_over or (_sequence != null and not _sequence.finished): return
	var sd = _auto("SaveData")
	var profile: PlayerProfile = sd.profile if sd != null else null
	for enemy in session.enemies:
		if _met.has(enemy.id): continue
		_met[enemy.id] = true
		var asset = converter.asset_of(enemy.def, "EntityAsset")
		if asset == null or asset.entrance == null or asset.entrance.lines.is_empty(): continue
		var key := PlayerProfile.meet_key(asset.get_id())
		if profile != null and profile.has_seen_intro(key): continue
		_sequence_subject = enemy.id
		_play(asset.entrance, profile, key)
		return

## Records for the Codex the enemies on the board and the statuses on anyone, once their arrival has played.
func _discover_for_codex() -> void:
	var sd = _auto("SaveData")
	if director.busy or sd == null: return
	var codex: CodexProgress = sd.codex
	var found := false
	var enemies := session.enemies
	for e in session.state.entities:
		if not e.alive: continue
		if enemies.has(e) and not _catalogued.has(e.def):
			_catalogued[e.def] = true
			var enemy = converter.asset_of(e.def, "EntityAsset")
			if enemy != null: found = codex.discover(CodexSection.Enemies, enemy.get_id()) or found
		for st in e.statuses:
			if not st.active or _catalogued.has(st.def): continue
			_catalogued[st.def] = true
			var status = converter.asset_of(st.def, "StatusAsset")
			if status != null and not st.def.has_tag(Tags.Hidden): found = codex.discover(CodexSection.Statuses, status.get_id()) or found
	if found: sd.save()

## Starts a sequence ({player} → the player's name, {key:Id} → that action's key); when it ends or is skipped,
## seen_key (when given) is recorded in the profile so it does not play again.
func _play(asset: SequenceAsset, profile: PlayerProfile, seen_key: String) -> void:
	var player_name := profile.player_name if profile != null and profile.created else PlayerProfile.DefaultName
	var keys = _auto("KeyBinds")
	var lines := []
	for l in asset.lines:
		if l == null: continue
		var text: String = (l.text if l.text != null else "").replace("{player}", player_name)
		if keys != null: text = keys.fill_keys(text)
		lines.append(l.with_text(text))
	var run := SequenceRun.new(lines)
	run.line_changed.connect(func():
		version += 1
		sequence_changed.emit()
		if run.finished and seen_key != "" and profile != null and profile.mark_intro_seen(seen_key):
			var sd = _auto("SaveData")
			if sd != null: sd.save())
	_sequence = run
	version += 1
	sequence_changed.emit()

## Tells the sequence about a cast: a movement ability is TowerMoved, anything else AbilityCast (and QuickCast).
func _notify_cast(ability: AbilityDef, quick: bool) -> void:
	if _sequence == null: return
	if ability.tags.has(Tags.Movement):
		_sequence.notify(SequenceEvent.TowerMoved)
		return
	_sequence.notify(SequenceEvent.AbilityCast)
	if quick: _sequence.notify(SequenceEvent.QuickCast)

## Some tower (or base) could hit an enemy now with one of its attacks.
func _enemy_in_range() -> bool:
	var enemies := session.enemies
	for u in session.player_units:
		for a in u.abilities:
			if not a.tags.has(Tags.Attack): continue
			for aim in Targeting.valid_aims(session.state, u.id, a):
				var t: Entity = Instinct.target_of(session.state, a, aim)
				if t != null and t.alive and enemies.has(t): return true
	return false

## Advances the sequence; tells it when a wave was cleared or the level won; Space continues a click line.
func _tick_sequence(unscaled: float) -> void:
	if _sequence == null or _sequence.finished: return
	var cleared := 0
	var arrived := 0
	for w in session.waves:
		if w.finished: cleared += 1
		if w.started and session.round - w.start_round >= w.def.last_scheduled_round: arrived += 1
	if cleared > _waves_cleared:
		_waves_cleared = cleared
		_sequence.notify(SequenceEvent.WaveCleared)
	if arrived > _waves_arrived:
		_waves_arrived = arrived
		_sequence.notify(SequenceEvent.WaveArrived)
	if session.outcome != Outcome.Running:
		if session.outcome == Outcome.Won: _sequence.notify(SequenceEvent.LevelWon)
		if not director.busy: _sequence.skip()
		return
	var line := _sequence.current
	if not director.busy and line != null and line.continue_on == SequenceContinue.Event and line.wait_for == SequenceEvent.EnemyInRange and _enemy_in_range():
		_sequence.notify(SequenceEvent.EnemyInRange)
	if not director.busy and line != null and line.continue_on == SequenceContinue.Click and _pressed("Skip"): _sequence.click()
	_sequence.tick(unscaled, not director.busy)

## The ring and dim round what the sequence line points at on the board.
func _update_sequence_marks() -> void:
	var line: SequenceLine = sequence.current if sequence != null else null
	if line == null or line.point_at == SequencePointAt.UI or line.point_at == SequencePointAt.Nothing or line.point_at == SequencePointAt.Center:
		overlay.sequence.set_target(null, false)
		return
	overlay.sequence.set_target(sequence_target_screen(line, true), line.continue_on == SequenceContinue.Click,
		null, Vector2(120, 64) * WorldUi.readable(camera.zoom_factor()))

func _aim_instinct_hint() -> String:
	var caster: Entity = session.state.get_entity(_selected)
	var aim: Aim = Instinct.quick_cast(session.state, caster, _aiming) if caster != null else null
	if aim == null: return "%s: %s" % [_aiming.display_name, Instinct.last_reason if Instinct.last_reason != "" else "no target"]
	var target: Entity = Instinct.target_of(session.state, _aiming, aim)
	return "Its instinct would cast %s" % _aiming.display_name + (" on %s." % target.def.display_name if target != null and target != caster else " there.")

func _quick_cast_hint() -> String:
	if _preview_caster == null or _preview_caster.id != _selected or _selected_tower() != _preview_caster: return _message if _message != null else ""
	if not session.can_cast(_preview_caster, _preview_ability): return "%s: %s" % [_preview_ability.display_name, session.last_reason]
	var aim: Aim = Instinct.quick_cast(session.state, _preview_caster, _preview_ability)
	if aim == null: return "%s: %s" % [_preview_ability.display_name, Instinct.last_reason]
	var target: Entity = Instinct.target_of(session.state, _preview_ability, aim)
	var on := " on %s" % target.def.display_name if target != null and target != _preview_caster else ""
	if _quick_key >= 0: return "Let go to cast %s%s. Right-click cancels." % [_preview_ability.display_name, on]
	var keys = _auto("KeyBinds")
	var click: String = keys.click_text("QuickCast") if keys != null else "Shift-click"
	return "%s casts %s at once%s." % [click, _preview_ability.display_name, on]

# ------------------------------------------------------------------ content lookups

func _model_scene(view_path: String) -> PackedScene:
	var app = _auto("GameApp")
	if app != null: return app.model_scene(view_path)
	var p := ArtPaths.model(view_path)
	return load(p) if p != "" and ResourceLoader.exists(p) else null

func _entity_scene(id: int) -> PackedScene:
	var e: Entity = session.state.get_entity(id)
	var asset = converter.asset_of(e.def, "EntityAsset") if e != null and e.def != null else null
	return _model_scene(asset.view) if asset != null and asset.view != "" else null

func _plate_offset(id: int) -> float:
	var e: Entity = session.state.get_entity(id)
	var asset = converter.asset_of(e.def, "EntityAsset") if e != null and e.def != null else null
	return asset.plate_offset if asset != null else 0.0

func _status_loop(def) -> String:
	var asset = converter.asset_of(def, "StatusAsset")
	return VfxKit.effect_name(asset.loop_vfx) if asset != null else ""

func _status_icon(def) -> Texture2D:
	var asset = converter.asset_of(def, "StatusAsset") if def != null else null
	if asset == null or asset.icon == "": return null
	var app = _auto("GameApp")
	if app != null: return app.icon_texture(asset.icon)
	var p := ArtPaths.icon(asset.icon)
	return load(p) if p != "" and ResourceLoader.exists(p) else null

func _presentation(ability) -> AbilityPresentationAsset:
	var a = converter.asset_of(ability, "AbilityAsset")
	return a.presentation if a != null else null

# ------------------------------------------------------------------ autoloads and keys

func _auto(n: String):
	var tree := get_tree()
	return tree.root.get_node_or_null(n) if tree != null else null

func flow_game_id() -> int:
	var flow = _auto("SceneFlow")
	return flow.Game if flow != null else -1

func _restore_speed() -> void:
	var flow = _auto("SceneFlow")
	if flow != null: flow.restore_game_speed()

func _pressed(id: String) -> bool:
	var k = _auto("KeyBinds")
	return k != null and k.pressed(id)

func _held(id: String) -> bool:
	var k = _auto("KeyBinds")
	return k != null and k.held(id)

func _modifier_held(id: String) -> bool:
	var k = _auto("KeyBinds")
	return k != null and k.modifier_held(id)

func _back_pressed() -> bool:
	var k = _auto("KeyBinds")
	return k != null and k.back_pressed()

func _key_first(id: String) -> String:
	var k = _auto("KeyBinds")
	return k.first(id) if k != null else id
