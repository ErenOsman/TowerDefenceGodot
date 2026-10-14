extends TestCase
## Animated 3D backdrops (Camp/Guild TdStationWorld, the menus' miniatures) stop drawing while a full-screen window
## covers them (TdDiorama.screen_covered / animate_unless_covered), and draw again when it closes.

var holder: Control
var popup: TdPopup
var vp: SubViewport

func setup() -> void:
	holder = Control.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(holder)
	vp = SubViewport.new()
	holder.add_child(vp)
	popup = TdPopup.new()
	holder.add_child(popup)
	popup.window = Control.new()
	popup.window.size = Vector2(400, 300)
	popup.add_child(popup.window)

func teardown() -> void:
	TdPopup.open_popups.erase(popup)
	holder.free()

func _show(scrim_alpha: float) -> void:
	popup.is_open = true
	popup.visible = true
	popup.scrim.visible = true
	popup.scrim.color.a = scrim_alpha
	popup.scrim.modulate.a = 1.0
	TdPopup.open_popups.append(popup)

func _tree() -> SceneTree:
	return holder.get_tree()

func test_scrim_window_covers() -> void:
	assert_false(TdDiorama.screen_covered(_tree()))
	_show(0.88)
	assert_true(TdDiorama.screen_covered(_tree()), "the 88 % scrim is up")
	popup.scrim.modulate.a = 0.5
	assert_false(TdDiorama.screen_covered(_tree()), "still fading in: keep drawing")

func test_light_scrim_does_not_cover() -> void:
	_show(0.6) # the Camp/Guild tour bubble's scrim
	assert_false(TdDiorama.screen_covered(_tree()))

func test_full_size_window_covers_without_scrim() -> void:
	_show(0.0)
	popup.scrim.visible = false
	assert_false(TdDiorama.screen_covered(_tree()))
	popup.window.size = _tree().root.get_visible_rect().size
	assert_true(TdDiorama.screen_covered(_tree()))

func test_backdrop_inside_the_window_keeps_drawing() -> void:
	_show(0.88)
	var inner := SubViewport.new()
	popup.window.add_child(inner)
	assert_false(TdDiorama.screen_covered(_tree(), inner))

func test_update_mode_follows_the_cover() -> void:
	_show(0.88)
	for i in 5: TdDiorama.animate_unless_covered(vp, holder)
	assert_eq(vp.render_target_update_mode, SubViewport.UPDATE_WHEN_VISIBLE, "the first frames always draw")
	TdDiorama.animate_unless_covered(vp, holder)
	assert_eq(vp.render_target_update_mode, SubViewport.UPDATE_DISABLED, "covered: not drawn")
	popup.is_open = false
	TdDiorama.animate_unless_covered(vp, holder)
	assert_eq(vp.render_target_update_mode, SubViewport.UPDATE_WHEN_VISIBLE, "uncovered: drawn again")
