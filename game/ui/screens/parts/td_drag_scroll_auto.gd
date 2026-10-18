extends Node
## Autoload "DragScroll" (Eren 2026-10-17: "mouse drag must scroll every menu scroll area"): gives every vertical
## ScrollContainer that enters the main window TdDragScroll's drag-to-scroll (6 px dead zone, so clicks still work; a
## press on a drag source such as a hand-editor tile keeps its own drag). One shared mechanism: screens no longer need
## to call TdDragScroll.attach themselves (the explicit calls still style the bar; a scroll is never attached twice).
## Left alone: horizontal-only scrolls (vertical scroll disabled) and scrolls inside another Window (a dropdown's
## PopupMenu list).

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	if n is ScrollContainer: _attach_later.call_deferred(n)

func _attach_later(s: ScrollContainer) -> void:
	if not is_instance_valid(s) or not s.is_inside_tree(): return
	if s.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED: return
	if s.get_window() != get_tree().root: return
	TdDragScroll.attach_drag(s)
