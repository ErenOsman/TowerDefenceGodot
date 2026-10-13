extends CanvasLayer
## The loading screen before a level (UI_Loading.cs; the Unity build's look): the last menu diorama blurred behind
## (TdDiorama.snapshot; dark wood with a vignette when there is none), a wood plaque holding the logo slot
## (the placeholder name), a status line with the percentage, a cobalt bar and one random Codex tip with the player's
## keys. The contract with SceneFlow: layer 100, SceneFlow.load_pending(self) loads the pending level and opens it
## under this screen; the first 80 % of the bar follows the read, then it eases on while the level holds the screen
## (SceneFlow.loading_screen_held), shows "Complete!", fades out on unscaled time and calls
## SceneFlow.close_loading_screen(self).

const MIN_TIME := 0.3
const READ_SHARE := 0.8
const POST_DELAY := 0.1
const FADE_TIME := 0.5
const SETUP_TIMEOUT := 15.0
const STATUS := "Setting up the board..."

var root: Control
var title: Label
var status: Label
var percent: Label
var tip: RichTextLabel
var bar_fill: Control
var _bar_w := 716.0
var _t := 0.0
var _read := 0.0
var _shown := 0.0
var _waited := 0.0
var _phase := 0  # 0 reading, 1 setting up, 2 complete, 3 fading
var _phase_t := 0.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	SceneFlow.loading_progress.connect(func(p: float): _read = maxf(_read, p))
	SceneFlow.load_pending(self)

func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = TdTheme.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var has_dio := TdDiorama.has_snapshot()
	TdMenu.wood_background(root, true)
	if has_dio:
		var dio := TdDiorama.new()
		dio.build_board = false
		dio.dim = 0.6
		dio.blur = 2.2
		root.add_child(dio)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	# a wood plaque (92 %) behind the title, the bar and the tip, so they read over the board
	var plaque := TdMenu.panel(TdPanel.Kind.MENU, 44)
	plaque.self_modulate.a = 0.92
	center.add_child(plaque)
	var col := TdMenu.vbox(18)
	col.custom_minimum_size = Vector2(_bar_w, 0)
	plaque.add_child(col)
	var logo := TdMenu.logo_slot(72, Vector2(_bar_w, 130))
	title = logo.get_child(0)
	col.add_child(logo)
	col.add_child(TdMenu.spacer(16))
	var row := TdMenu.hbox(12)
	col.add_child(row)
	status = TdMenu.label(STATUS, "header", TdTheme.color("cream.200"), 28)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status)
	percent = TdMenu.label("0%", "header", Color.WHITE, 24)
	percent.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(percent)
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(_bar_w, 40)
	bar.add_theme_stylebox_override("panel", TdTheme.stylebox("loadbar_track"))
	col.add_child(bar)
	bar_fill = Panel.new()
	bar_fill.add_theme_stylebox_override("panel", TdTheme.stylebox("loadbar_fill"))
	bar_fill.size = Vector2(0, 40)
	bar_fill.clip_contents = true
	bar.add_child(bar_fill)
	tip = TdMenu.rich("", "body", TdTheme.color("cream.300"), 24)
	tip.custom_minimum_size = Vector2(_bar_w, 0)
	col.add_child(tip)
	tip.text = tip_text()

## One Codex tip at random, keys filled in ("" when there are none).
static func tip_text() -> String:
	var codex: CodexAsset = GameApp.catalog.codex if GameApp.catalog != null else null
	if codex == null or codex.tips.is_empty(): return ""
	var t: CodexTip = codex.tips[randi() % codex.tips.size()]
	return "[b][color=%s]Tip:[/color][/b] %s" % [TdTheme.rich("cream.200"), TooltipText.from_rich(KeyBinds.fill_keys(t.text))]

func _process(delta: float) -> void:
	var dt := minf(TdTheme.unscaled(delta), 0.1) # capped: a frame stalled by the read would fill the bar at once
	_t += dt
	match _phase:
		0:
			_shown = minf(clampf(_t / MIN_TIME, 0.0, 1.0), _read) * READ_SHARE
			if SceneFlow.target_ready and _t >= MIN_TIME:
				_phase = 1
				_shown = READ_SHARE
		1:
			_waited += dt
			_shown = move_toward(_shown, 0.97, dt * 0.6)
			if not SceneFlow.loading_screen_held or _waited >= SETUP_TIMEOUT:
				if SceneFlow.loading_screen_held: push_warning("[Loading] the scene was still setting up after %d s; showing it anyway" % int(SETUP_TIMEOUT))
				_phase = 2
				_phase_t = 0.0
				_shown = 1.0
				status.text = "Complete!"
		2:
			_phase_t += dt
			if _phase_t >= POST_DELAY:
				_phase = 3
				_phase_t = 0.0
		3:
			_phase_t += dt
			var k := clampf(_phase_t / FADE_TIME, 0.0, 1.0)
			root.modulate.a = 1.0 - k * k * (3.0 - 2.0 * k)
			if k >= 1.0:
				set_process(false)
				SceneFlow.close_loading_screen(self)
	_show(_shown)

func _show(p: float) -> void:
	bar_fill.size = Vector2(maxf(0.0, _bar_w * p), 40)
	bar_fill.visible = p > 0.005
	percent.text = "%d%%" % roundi(p * 100.0)
