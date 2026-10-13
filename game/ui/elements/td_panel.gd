class_name TdPanel
extends PanelContainer
## A kit panel (PanelContainer) with the right 9-slice and padding for its kind, plus static StyleBox helpers for code
## that draws its own panels. Kinds: WINDOW (window_frame, wood plaque r22: Settings / Codex / Pause, padding 32),
## WOOD (panel_wood r14 with the cobalt band: inspector, bars), ENEMY (panel_wood_enemy), PAPER (paper_card r12:
## readable cards), TOOLTIP (tooltip_paper), DIALOGUE (dialogue_box), PILL (pill_wood), MENU (menu_panel: Welcome
## plaque), WELL (well: inset area), STAT (paper_stat tile).
## Open / close motion: TdPanelTransition; full-screen dim behind windows: TdScrim.

enum Kind { WINDOW, WOOD, ENEMY, PAPER, TOOLTIP, DIALOGUE, PILL, MENU, WELL, STAT }

const SPRITES := ["window_frame", "panel_wood", "panel_wood_enemy", "paper_card", "tooltip_paper", "dialogue_box", "pill_wood", "menu_panel", "well", "paper_stat"]
const PADDING := [32.0, 20.0, 20.0, 20.0, 16.0, 40.0, 12.0, 32.0, 16.0, 8.0]

@export var kind: Kind = Kind.WOOD:
	set(v):
		kind = v
		_apply()
## -1: the kind's padding.
@export var padding := -1.0:
	set(v):
		padding = v
		_apply()

func _init() -> void:
	_apply()

func _apply() -> void:
	var p: float = padding if padding >= 0.0 else PADDING[kind]
	add_theme_stylebox_override("panel", box(kind, p))

## The StyleBox of a kind with padding p (reference px).
static func box(k: Kind, p := -1.0) -> StyleBox:
	var pad: float = p if p >= 0.0 else PADDING[k]
	return TdTheme.stylebox(SPRITES[k], Color.WHITE, [pad, pad, pad, pad])

static func window_box(p := 32.0) -> StyleBox: return box(Kind.WINDOW, p)
static func wood_box(p := 20.0, enemy := false) -> StyleBox: return box(Kind.ENEMY if enemy else Kind.WOOD, p)
static func paper_card_box(p := 20.0) -> StyleBox: return box(Kind.PAPER, p)
static func tooltip_box(p := 16.0) -> StyleBox: return box(Kind.TOOLTIP, p)

## A window: TdPanel (WINDOW) holding a VBox with a title row (h2 title at the top-left, optional × close button at
## the top-right) and returns {"panel", "body" (VBoxContainer for the content), "title" (Label), "close" (TdButton or null)}.
static func make_window(title: String, closable := true) -> Dictionary:
	var panel := TdPanel.new()
	panel.kind = Kind.WINDOW
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := TdTheme.label(title, "h1", TdTheme.color("cream.100"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close: TdButton = null
	if closable:
		close = TdButton.new()
		close.style = TdButton.Style.ICON
		close.custom_minimum_size = Vector2(52, 52)
		close.size = Vector2(52, 52)
		close.icon = TdTheme.texture("icon_close")
		head.add_child(close)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	return {"panel": panel, "body": body, "title": t, "close": close}
