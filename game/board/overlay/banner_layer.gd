class_name BannerLayer
extends Control
## Banners over the board (BannerLayer.cs): round, phase, waves, messages, in the display type, centred over the
## board's free area at 18 % from the top. Each sweeps in from the left (fading in), holds and sweeps out. One
## arriving while another shows waits its turn; one of the same kind replaces a stale one (a newer drops an older
## one waiting, or cuts the one showing short); sticky ones (won, lost) show at once and stay. Never blocks the
## pointer. Unscaled time.

const SWEEP := 60.0
const QUICK := 0.18   # UITheme motion.quick
const MAX_WAITING := 2

## The x of the free area's centre in canvas pixels (BoardCamera.free_centre); NAN = the middle.
var centre_x: float = NAN

var _label: Label
var _queue: Array = []     # [text, seconds, kind]
var _age := 0.0
var _hold := 0.0
var _sticky := false
var _showing := false
var _kind = null

func _init() -> void:
	name = "Banners"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.name = "Banner"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.label_settings = OverlayStyle.world_label(64, OverlayStyle.CREAM, OverlayStyle.DISPLAY_FONT, 12)
	_label.visible = false
	add_child(_label)

## The banner showing now ("" when none).
var text: String:
	get: return _label.text if _showing else ""

## How many banners wait (tests).
var waiting: int:
	get: return _queue.size()

## Shows a banner for some seconds (see the class summary for waiting, kinds and sticky ones).
func show_banner(message: String, seconds: float, stick: bool = false, kind = null) -> void:
	if stick:
		_queue.clear()
		_start(message, seconds, true, null)
		return
	if _showing and _sticky: return # the level is over
	if kind != null:
		_queue = _queue.filter(func(b): return b[2] != kind)
		if _showing and _kind == kind:
			_start(message, seconds, false, kind)
			return
	if _showing:
		_queue.append([message, seconds, kind])
		while _queue.size() > MAX_WAITING: _queue.pop_front() # a fast player (or Instant) never sees stale banners
		return
	_start(message, seconds, false, kind)

## Hides the banner and drops the waiting ones (not a sticky one).
func hide_banner() -> void:
	if _sticky: return
	_queue.clear()
	_showing = false
	_label.visible = false

func tick(dt: float) -> void:
	if not _showing: return
	_age += dt
	var into := clampf(_age / QUICK, 0.0, 1.0)
	var out_of := 0.0 if _sticky else clampf((_age - _hold) / QUICK, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - into, 3.0)
	var view := get_viewport_rect().size
	var cx := view.x * 0.5 if is_nan(centre_x) else centre_x
	_label.reset_size()
	_label.position = Vector2(cx - _label.size.x * 0.5 - SWEEP * (1.0 - ease) + SWEEP * out_of, view.y * 0.18 - _label.size.y * 0.5)
	_label.modulate.a = ease * (1.0 - out_of)
	if not _sticky and _age >= _hold + QUICK:
		if _queue.size() > 0:
			var next: Array = _queue.pop_front()
			_start(next[0], next[1], false, next[2])
		else:
			_showing = false
			_label.visible = false

func _start(message: String, seconds: float, stick: bool, kind) -> void:
	_label.text = message
	_label.visible = true
	_age = 0.0
	_hold = maxf(seconds, QUICK)
	_sticky = stick
	_kind = kind
	_showing = true

## Hides everything, sticky banners too (the end window is opening).
func clear_all() -> void:
	_queue.clear()
	_sticky = false
	_showing = false
	_label.visible = false
