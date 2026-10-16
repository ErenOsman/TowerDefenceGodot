class_name TdBackpackButton
extends TdButton
## The Backpack button (Backpack — Design § Where; UI/UX mockup screens-b/backpack-button.html): a plain wood
## secondary button with the bag glyph, the gold coin and the gold count in gold text ("[bag] [coin] 240"). At the
## top-right of the Camp, the Guild and the Blacksmith (place_top_right), and left of × in the Workshop picker's,
## the Upgrade picker's and the Upgrade view's headers (make). Hidden before the Camp unlocks (nothing to carry).
## A click opens the Backpack popup (BackpackScreen) over `host`; the count refreshes when that popup closes, and
## everywhere at once with TdBackpackButton.refresh_all(tree) (the Upgrade view's Pay calls it).
## Icons: TdDrops.bag_icon() / gold_coin_texture() (the kit's icon_backpack and tokens/gold.png; a kit drop-in under
## the same names replaces them).

const GROUP := "backpack_button"
## Where the places put it (1920×1080 reference; the mockup's right 32 / top 28 at 1280, scaled).
const MARGIN := Vector2(48, 40)

## Where the Backpack popup is added (a place's popup layer, or the picker popup it sits in); null = the current scene.
var host: Node = null
## The count shown (tests and tools).
var count := 0
## The Backpack popup it opened (while open), or null.
var popup: BackpackScreen = null

var _bag: TextureRect
var _coin: TextureRect
var _count: Label
var _row: HBoxContainer
var _h := 56.0

## A button for a header (52 px high, as the × beside it) or a place (56 px).
static func make(popup_host: Node = null, height := 52.0) -> TdBackpackButton:
	var b := TdBackpackButton.new()
	b.host = popup_host
	b._h = height
	b.style = TdButton.Style.SECONDARY
	b.custom_minimum_size = Vector2(150, height)
	b.size = b.custom_minimum_size
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

## Adds one at the top-right of a place (Camp, Guild, Blacksmith); the popup goes into popup_host. Returns it.
static func place_top_right(parent: Control, popup_host: Node) -> TdBackpackButton:
	var b := make(popup_host, 56.0)
	parent.add_child(b)
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b._fit()
	return b

## Refreshes the count of every Backpack button in the tree (after a Pay).
static func refresh_all(tree: SceneTree) -> void:
	if tree == null: return
	for b in tree.get_nodes_in_group(GROUP):
		if b is TdBackpackButton: b.refresh()

func _ready() -> void:
	super()
	add_to_group(GROUP)
	tooltip_text = ""
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_row.mouse_filter = MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(_row)
	var d := 34.0 if _h >= 56.0 else 30.0
	_bag = TdMenu.picture(TdDrops.bag_icon(), Vector2(d, d))
	_bag.modulate = TdTheme.color("cream.100")
	_bag.size_flags_vertical = SIZE_SHRINK_CENTER
	_row.add_child(_bag)
	_coin = TdMenu.picture(TdDrops.gold_coin_texture(), Vector2(d, d))
	_coin.size_flags_vertical = SIZE_SHRINK_CENTER
	_row.add_child(_coin)
	_count = TdMenu.label("0", "header", TdTheme.color("gold"), 30 if _h >= 56.0 else 28)
	_count.add_theme_font_override("font", TdTheme.font("plinth"))
	_count.size_flags_vertical = SIZE_SHRINK_CENTER
	_row.add_child(_count)
	_content.resized.connect(_fit_row)
	clicked.connect(open_backpack)
	refresh()

## Reads the gold again (and whether it shows: the Camp is open).
func refresh() -> void:
	count = GameApp.gold()
	visible = BackpackLogic.button_shown(GameApp.camp_unlocked())
	if _count == null: return
	_count.text = BackpackLogic.button_text(count)
	TdTooltipTrigger.attach(self, TooltipText.title(BackpackLogic.Title, TooltipText.value_color(), ""),
		BackpackLogic.button_tip(count, SaveData.tokens))
	_fit()

## Opens the Backpack popup over host; refreshes when it closes.
func open_backpack() -> BackpackScreen:
	if is_instance_valid(popup) and popup.is_open: return popup
	var where: Node = host if is_instance_valid(host) else get_tree().current_scene
	popup = BackpackScreen.show_over(where)
	popup.closed.connect(func(): if is_instance_valid(self): refresh())
	return popup

## Width from the content (left 12, right 16, as the mockup's padding); anchored ones keep their top-right corner.
func _fit() -> void:
	if _row == null: return
	var w := ceilf(_row.get_combined_minimum_size().x) + 30.0
	custom_minimum_size = Vector2(w, _h)
	size = custom_minimum_size
	if anchor_left == 1.0 and anchor_right == 1.0:
		offset_right = -MARGIN.x
		offset_left = -MARGIN.x - w
		offset_top = MARGIN.y
		offset_bottom = MARGIN.y + _h
	_fit_row()

func _fit_row() -> void:
	if _row == null: return
	var ms := _row.get_combined_minimum_size()
	_row.size = Vector2(ms.x, _content.size.y)
	_row.position = Vector2(floorf((_content.size.x - ms.x) / 2.0) - 2.0, 0)
