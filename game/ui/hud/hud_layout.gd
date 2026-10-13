class_name HudLayout
extends RefCounted
## The battle HUD's bottom row and screen zones as pure math (UI Design Rules, Bottom row layout; hud-menu-spec §6),
## in canvas pixels at the 1920×1080 reference (the canvas grows with the window's aspect, so `screen` may be wider
## or taller). Left to right: the hand tray (bottom-left, from the 32 px margin), the action bar (centred on the
## SCREEN, ~62 px above the bottom; a wide hand pushes it right until it clears the tray by 24 px, never left: user
## decision 2026-10-13), End turn (bottom-right, never moved). When the pushed bar would reach End turn, the bar and
## its hint move up to a row above the tray, centred on the screen. bar_raised() is the doc's count rule
## (130 × pieces + 147 × abilities > 1372; 147 = one ability button with its bleed room and gap), kept as a quick
## estimate; bottom_row() decides from the real widths. The hint sits under the bar (centred on it, left-aligned once
## the bar has been pushed right).

const MARGIN := 32.0
const TOP_BAR := 96.0
## The free board area the bottom row centres on: the screen minus the right bar's 300 px (UI Design Rules). The
## camera does not keep it clear (insets right = 0): the open card may cover the board's edge.
const RIGHT_BAR := 300.0
const INSPECTOR_W := 360.0
const INSPECTOR_TOP := 96.0
const TRAY_H := 168.0
const PIECE_W := 124.0
const PIECE_GAP := 6.0
const TRAY_PAD := 22.0
const END_TURN := 168.0
const END_TURN_BOTTOM := 20.0
const BAR_BOTTOM := 62.0
const BAR_H := 112.0
const BAR_GAP := 24.0
## How far a slid action bar stays right of the tray.
const TRAY_CLEAR := 24.0
const RAISED_GAP := 12.0
const HINT_H := 44.0
## The fit rule's budget at 1920 wide: 130 px per piece + 110 px per ability must stay within this.
const ROW_BUDGET := 1372.0
const PIECE_COST := 130.0
## One ability button in the bar: the 84 face plus the kit's bleed room (ring, key badge, cooldown badge: 29 + 30),
## and the gap between buttons; the fit rule counts this per ability.
const ABILITY_W := 143.0
const ABILITY_GAP := 4.0
const ABILITY_COST := ABILITY_W + ABILITY_GAP

## The tray's width for n pieces (pieces × 124 + gaps + 44 padding); an empty hand keeps one slot's width.
static func tray_width(pieces: int) -> float:
	var n := maxi(1, pieces)
	return n * PIECE_W + (n - 1) * PIECE_GAP + TRAY_PAD * 2.0

static func tray_rect(screen: Vector2, pieces: int) -> Rect2:
	return Rect2(MARGIN, screen.y - TRAY_H, tray_width(pieces), TRAY_H)

## The tray and the bar don't fit side by side: the bar goes up a row. The budget grows with a wider canvas.
static func bar_raised(pieces: int, abilities: int, screen_w := 1920.0) -> bool:
	return PIECE_COST * pieces + ABILITY_COST * abilities > ROW_BUDGET + (screen_w - 1920.0)

## The action bar's width: padding 16 + who column + divider + buttons 84 with 26 between (passives count as buttons).
static func bar_width(buttons: int, who_w := 110.0) -> float:
	var n := maxi(0, buttons)
	var w := 16.0 * 2.0 + maxf(110.0, who_w)
	if n > 0: w += 26.0 + 2.0 + 26.0 + n * ABILITY_W + (n - 1) * ABILITY_GAP
	return w

## The free board area's horizontal centre (the screen minus the right bar).
static func free_centre_x(screen: Vector2) -> float:
	return (screen.x - RIGHT_BAR) / 2.0

## Where the bar, the hint and the camera inset go: {"bar": Rect2, "raised": bool, "slid": bool,
## "hint_x": float (left edge when slid, else the centre), "hint_y": float (top), "hint_centred": bool,
## "bottom_inset": float (what the HUD covers at the bottom)}.
static func bottom_row(screen: Vector2, pieces: int, abilities: int, bar_w: float) -> Dictionary:
	# user decision 2026-10-13: centred on the SCREEN; a wide hand pushes it right until it clears the tray by 24 px
	# (never left); if it would then reach End turn, it goes up a row above the tray, centred again
	var tray := tray_rect(screen, pieces)
	var cx := screen.x / 2.0
	var x := cx - bar_w / 2.0
	var slid := false
	var raised := false
	var end_left := screen.x - MARGIN - END_TURN - BAR_GAP
	if x < tray.end.x + TRAY_CLEAR:
		x = tray.end.x + TRAY_CLEAR
		slid = true
	if x + bar_w > end_left: raised = true
	var y := screen.y - BAR_BOTTOM - BAR_H
	if raised:
		slid = false
		x = clampf(cx - bar_w / 2.0, MARGIN, maxf(MARGIN, end_left - bar_w))
		y = tray.position.y - RAISED_GAP - HINT_H - BAR_H
	var bar := Rect2(x, y, bar_w, BAR_H)
	var hint_y := bar.end.y + 4.0
	return {
		"bar": bar, "raised": raised, "slid": slid,
		"hint_x": bar.position.x if slid else bar.get_center().x, "hint_y": hint_y, "hint_centred": not slid,
		"bottom_inset": (screen.y - bar.position.y) if raised else TRAY_H,
	}

## Where the hint line goes with no bar shown: the bottom strip between the tray and End turn, centred on the free
## area unless the tray reaches it ({"x", "y", "centred"}).
static func hint_without_bar(screen: Vector2, pieces: int, hint_w: float) -> Dictionary:
	var tray := tray_rect(screen, pieces)
	var cx := free_centre_x(screen)
	var y := screen.y - BAR_BOTTOM + 4.0
	if cx - hint_w / 2.0 < tray.end.x + BAR_GAP:
		return {"x": tray.end.x + BAR_GAP, "y": y, "centred": false}
	return {"x": cx, "y": y, "centred": true}

static func inspector_rect(screen: Vector2, height: float) -> Rect2:
	return Rect2(screen.x - MARGIN - INSPECTOR_W, INSPECTOR_TOP, INSPECTOR_W, height)

static func end_turn_rect(screen: Vector2) -> Rect2:
	return Rect2(screen.x - MARGIN - END_TURN, screen.y - END_TURN_BOTTOM - END_TURN, END_TURN, END_TURN)

## The hint pill's left edge: never over the tray (from its end + 24); next to a bar in the bottom row, never left
## of the bar either (left-aligned with it once it would cross the tray); always inside the screen.
static func hint_left(left: float, width: float, screen: Vector2, pieces: int, bar_in_row: bool, bar_x: float) -> float:
	var tray := tray_rect(screen, pieces)
	var x := left
	if x < tray.end.x + BAR_GAP:
		x = bar_x if bar_in_row else tray.end.x + BAR_GAP
		x = maxf(x, tray.end.x + BAR_GAP)
	return clampf(x, MARGIN, maxf(MARGIN, screen.x - MARGIN - END_TURN - BAR_GAP - width))
