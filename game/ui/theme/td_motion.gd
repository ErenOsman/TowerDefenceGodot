class_name TdMotion
extends RefCounted
## Channels that add up instead of stopping each other (port of the Unity UITweener): scale, lift and alpha each ease
## to their own target over their own time, plus a sideways shake and a breathing pulse, so hover, press, a denied
## shake and an attention pulse can all run at once. The owner calls step(unscaled dt) every frame and reads
## scale_value() / offset() / alpha. Lift is upward (Godot y-down: offset().y = -lift).

enum { SCALE, LIFT, ALPHA }

var _from := [1.0, 0.0, 1.0]
var _to := [1.0, 0.0, 1.0]
var _value := [1.0, 0.0, 1.0]
var _time := [0.0, 0.0, 0.0]
var _dur := [0.0, 0.0, 0.0]
var _curve := ["", "", ""]
var _shake_amp := 0.0
var _shake_time := 0.0
var _shake_dur := 0.0
var _shake_swings := 3
var _pulse_amount := 0.0
var _pulse_period := 1.6
var _pulse_clock := 0.0

## The channel's value now.
func value(ch: int) -> float:
	return _value[ch]

## Eases a channel to a value over seconds (0 = at once) along a TdTheme easing ("" = smoothstep).
func to(ch: int, v: float, seconds: float, curve := "") -> void:
	if is_equal_approx(_to[ch], v) and _time[ch] >= _dur[ch]: return
	_from[ch] = _value[ch]
	_to[ch] = v
	_time[ch] = 0.0
	_dur[ch] = maxf(0.0, seconds)
	_curve[ch] = curve
	if _dur[ch] <= 0.0:
		_value[ch] = v

## Shakes sideways: amplitude px over seconds, swinging back and forth.
func shake(amplitude: float, seconds: float, swings := 3) -> void:
	if amplitude <= 0.0 or seconds <= 0.0: return
	_shake_amp = amplitude
	_shake_dur = seconds
	_shake_time = 0.0
	_shake_swings = maxi(1, swings)

## A slow breathing scale (0.03 = up to 3 % bigger) with a ping-pong period; 0 stops it.
func pulse(amount: float, period: float) -> void:
	_pulse_amount = amount
	_pulse_period = maxf(0.05, period)
	if amount <= 0.0: _pulse_clock = 0.0

## The pulse's phase now (0..1..0), for glows that breathe along.
func pulse_phase() -> float:
	if _pulse_amount <= 0.0: return 0.0
	return pingpong(_pulse_clock * 2.0 / _pulse_period, 1.0)

func is_pulsing() -> bool:
	return _pulse_amount > 0.0

## Ends every motion at its target (e.g. when the element is hidden).
func snap() -> void:
	for i in 3:
		_value[i] = _to[i]
		_time[i] = _dur[i]
	_shake_time = _shake_dur

## Advances by dt seconds (unscaled); returns whether anything moved.
func step(dt: float) -> bool:
	var moving := false
	for i in 3:
		if _time[i] >= _dur[i]: continue
		_time[i] = minf(_dur[i], _time[i] + dt)
		var t: float = _time[i] / _dur[i]
		var k := TdTheme.eased(_curve[i], t)
		_value[i] = lerpf(_from[i], _to[i], k)
		moving = true
	if _shake_time < _shake_dur:
		_shake_time += dt
		moving = true
	if _pulse_amount > 0.0:
		_pulse_clock += dt
		moving = true
	return moving

## Total scale multiplier: scale channel x pulse.
func scale_value() -> float:
	return _value[SCALE] * (1.0 + _pulse_amount * pulse_phase())

## Position offset: (shake, -lift).
func offset() -> Vector2:
	var sx := 0.0
	if _shake_time < _shake_dur and _shake_dur > 0.0:
		var t := _shake_time / _shake_dur
		sx = sin(t * _shake_swings * PI * 2.0) * _shake_amp * (1.0 - t)
	return Vector2(sx, -_value[LIFT])

var alpha: float:
	get: return _value[ALPHA]

func is_shaking() -> bool:
	return _shake_time < _shake_dur
