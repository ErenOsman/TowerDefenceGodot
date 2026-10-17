extends TestCase
## UI kit: TdTheme token lookup, type scale, motion curves, feedback profiles, control styles, kit sprites.

func test_color_tokens_by_any_spelling() -> void:
	assert_eq(TdTheme.color("accent").to_html(false), "4d8fe6")
	assert_eq(TdTheme.color("wood.900"), TdTheme.color("wood_900"))
	assert_eq(TdTheme.color("wood900"), TdTokens.WOOD_900)
	assert_eq(TdTheme.color("accent.fill").to_html(false), "3a6bb0")
	assert_eq(TdTheme.color("gold.ink").to_html(false), "7a4e00")
	assert_eq(TdTheme.color("chip.status.bg").to_html(false), "2a1f3a")
	assert_true(TdTheme.has_color("hp.high"))
	assert_false(TdTheme.has_color("not.a.token"))

func test_scrim_and_ghost_keep_their_alpha() -> void:
	assert_num(snappedf(TdTheme.color("scrim").a, 0.01), 0.88)
	assert_num(snappedf(TdTheme.color("hp.ghost").a, 0.01), 0.55)
	assert_eq(TdTheme.rich("ink"), "#2e2117")

func test_tokens_from_the_unity_theme_and_the_kit() -> void:
	# UITheme.json colours plus the kit's extra stops (cream.disabled, primary.*) are all there
	assert_true(TdTheme.has_color("cream.disabled"))
	assert_true(TdTheme.has_color("primary.top"))
	assert_eq(TdTheme.normalize_token("Wood.900"), "wood900")

func test_type_scale() -> void:
	assert_eq(TdTheme.font_size("display"), 64)
	assert_eq(TdTheme.font_size("h1"), 44)
	assert_eq(TdTheme.font_size("h2"), 32)
	assert_eq(TdTheme.font_size("body"), 22)
	assert_eq(TdTheme.font_size("small"), 20)
	assert_eq(TdTheme.font_size("micro"), 18)
	assert_eq(TdTheme.type_color("h2").to_html(false), "8dbbff")
	for role in TdTokens.TYPE:
		assert_true(TdTheme.font_size(role) >= TdTokens.MIN_FONT_SIZE, "%s is under the minimum" % role)
	assert_eq(TdTheme.font("display").resource_path, "res://art/fonts/Plinth-Bold.ttf")
	assert_eq(TdTheme.font("body").resource_path, "res://art/fonts/Nunito-Medium.ttf")
	assert_eq(TdTheme.font("small").resource_path, "res://art/fonts/Nunito-Bold.ttf")
	assert_eq(TdTheme.font("plate").resource_path, "res://art/fonts/Nunito-ExtraBold.ttf")

func test_motion_tokens() -> void:
	assert_num(TdTheme.motion("instant"), 0.1)
	assert_num(TdTheme.motion("quick"), 0.18)
	assert_num(TdTheme.motion("normal"), 0.25)
	assert_num(TdTheme.motion("slow"), 0.5)
	assert_num(TdTheme.motion("tooltip_delay"), 0.4)
	assert_num(TdTheme.motion("pulse_attention"), 1.6)

func test_easing_curves() -> void:
	for n in ["out", "lift", "in_out", "in", "linear", "smooth"]:
		assert_num(TdTheme.eased(n, 0.0), 0.0, n)
		assert_num(TdTheme.eased(n, 1.0), 1.0, n)
	# ease.out is fast at the start, ease.lift overshoots (~1.06) before settling
	assert_true(TdTheme.eased("out", 0.25) > 0.6)
	var peak := 0.0
	for i in 101: peak = maxf(peak, TdTheme.eased("lift", i / 100.0))
	assert_true(peak > 1.03 and peak < 1.1, "lift peak %f" % peak)
	assert_num(snappedf(TdTheme.eased("in_out", 0.5), 0.01), snappedf(TdTheme.bezier(0.4, 0.0, 0.2, 1.0, 0.5), 0.01))
	assert_num(snappedf(TdTheme.eased("linear", 0.3), 0.0001), 0.3)

func test_feedback_profiles() -> void:
	assert_num(TdTheme.feedback("MenuButton")["hover_scale"], 1.03)
	assert_num(TdTheme.feedback("MenuButton")["press_sink"], 9.0) # the menu sprites' band: the pressed face covers it
	assert_num(TdTheme.feedback("MenuButton")["press_scale"], 1.0) # a press never changes the size (Eren 2026-10-17)
	assert_num(TdTheme.feedback("Button")["press_sink"], 0.0) # flat buttons have no band: nothing moves
	assert_num(TdTheme.feedback("IconButton")["denied_shake"], 4.0)
	assert_num(TdTheme.feedback("Button")["denied_time"], 0.32)
	assert_num(TdTheme.feedback("nope")["denied_shake"], 6.0) # unknown -> Button

func test_control_styles_and_state_priority() -> void:
	var p := TdTheme.control_style("Primary")
	assert_eq(p["normal"], "btn_primary_normal")
	assert_eq(TdTheme.pick_sprite(p, true, false, false, false), "btn_primary_hover")
	assert_eq(TdTheme.pick_sprite(p, true, true, false, false), "btn_primary_pressed")
	assert_eq(TdTheme.pick_sprite(p, true, true, false, true), "btn_primary_disabled") # disabled beats pressed
	var s := TdTheme.control_style("Secondary")
	assert_eq(TdTheme.pick_sprite(s, false, false, true, false), "btn_primary_normal") # selected = primary look
	var a := TdTheme.control_style("Ability")
	assert_eq(TdTheme.pick_sprite(a, false, false, false, true, "Cooldown"), "ability_overlay_cooldown") # extra beats disabled
	var n := TdTheme.control_style("NamePlate")
	assert_eq(TdTheme.pick_sprite(n, true, false, false, false, "Placed"), "nameplate_placed_hover")
	assert_eq(TdTheme.pick_sprite(n, false, true, false, false), "nameplate_normal") # no pressed sprite -> normal
	assert_eq(TdTheme.pick_sprite(TdTheme.control_style("EndTurn"), false, false, false, false, "Attention"), "endturn_attention")

func test_kit_sprites_slice_at_reference_size() -> void:
	assert_eq(TdTheme.sprite_size("panel_wood"), Vector2(134, 102))
	assert_eq(TdTheme.sprite_border("panel_wood"), [38, 38, 38, 38])
	assert_eq(TdTheme.sprite_outset("menu_btn_primary_normal"), [3.0, 3.0, 3.0, 12.0])
	assert_eq(TdTheme.logical_size("btn_primary_normal"), Vector2(160, 60))
	var box := TdTheme.stylebox("btn_primary_normal")
	assert_true(box is TdSliceBox)
	assert_eq((box as TdSliceBox).border_left, 38)
	assert_num((box as TdSliceBox).texture_scale, 0.5)
	assert_eq((box as TdSliceBox)._get_draw_rect(Rect2(0, 0, 220, 60)), Rect2(-3, -3, 226, 66))
	assert_true(TdTheme.stylebox("btn_primary_normal") == box, "cached")
	assert_eq(TdTheme.role_sprite("cd_badge"), "cd_badge")
	assert_eq(TdTheme.role_sprite("clock_ring.3_1"), "clock_ring_3_1")
	assert_not_null(TdTheme.kit("abilities/Shoot"))
	assert_not_null(TdTheme.ability_face("Shoot"))

func test_clock_ring_names() -> void:
	assert_eq(TdTheme.clock_ring_name(1, 0, false), "clock_ring_1_ready")
	assert_eq(TdTheme.clock_ring_name(2, 1, false), "clock_ring_2_1")
	assert_eq(TdTheme.clock_ring_name(3, 3, false), "clock_ring_3_0")
	assert_eq(TdTheme.clock_ring_name(3, 1, true), "clock_ring_3_0")
	assert_eq(TdTheme.clock_ring_name(6, 3, false), "clock_ring_3_1") # long cooldowns fill 3 segments proportionally

func test_theme_resource_loads() -> void:
	var th := TdTheme.theme()
	assert_not_null(th)
	assert_true(th.has_stylebox("normal", "PrimaryButton"))
	assert_true(th.get_stylebox("panel", "WindowPanel") is TdSliceBox)
	assert_eq(th.get_font_size("font_size", "H1Label"), 44)

func test_button_bleed_room() -> void:
	# a row in a list keeps room for its 5 px outset + 6 px denied shake inside its own rect
	assert_eq(TdButton.bleed_for(TdButton.Style.ROW, Vector2(400, 60)), Vector4(11, 5, 11, 5))
	# menu buttons grow from their left edge: more room on the right
	var m := TdButton.bleed_for(TdButton.Style.MENU_WOOD, Vector2(440, 64))
	assert_true(m.z > m.x and m.w >= 12.0, str(m))
	# abilities: clock ring left/bottom, cooldown badge top/right
	var a := TdButton.bleed_for(TdButton.Style.ABILITY, Vector2(84, 84))
	assert_true(a.y >= 24.0 and a.z >= 24.0 and a.w >= 17.0, str(a))
	var b := TdButton.new()
	b.style = TdButton.Style.ROW
	b.custom_minimum_size = Vector2(400, 60)
	b.bleed_mode = TdButton.Bleed.ON
	assert_eq(b.get_combined_minimum_size(), Vector2(422, 70))
	b.size = Vector2(422, 70)
	assert_eq(b.face_rect(), Rect2(11, 5, 400, 60))
	b.bleed_mode = TdButton.Bleed.OFF
	assert_eq(b.face_rect(), Rect2(0, 0, 422, 70))
	b.free()

## Pressed reads as a sink, never a different shape (Eren 2026-10-17: "pressed buttons look buggy").
func test_pressed_is_a_clean_sink() -> void:
	var m := TdButton.new()
	m.style = TdButton.Style.MENU_WOOD
	m.custom_minimum_size = Vector2(440, 64)
	m.size = Vector2(440, 64)
	m.force_state(false, false)
	var rest: Vector2 = m.face_node().position
	m.force_state(false, true)
	assert_eq(m.face_node().position, rest + Vector2(0, 9), "the face moves down by its band, label and icon with it")
	assert_eq(m.face_node().scale, Vector2.ONE, "no press scale")
	var face: TdSliceBox = m._bg.get_theme_stylebox("panel")
	assert_eq(face.texture, TdTheme.stylebox("menu_btn_wood_normal").texture, "the normal face, no pressed sprite swap")
	assert_num(face.outset_bottom, 3.0, "the face block alone: the band is its own layer")
	assert_true(m._band.visible)
	assert_num(m._band.position.y + m.face_node().position.y, rest.y + 64.0, "the band stays where it was")
	assert_num(m._bg.self_modulate.r, 0.92)
	m.force_state(true, true)
	assert_num(m.face_node().scale.x, 1.03, "hovered and pressed keeps the hover scale")
	m.free()
	var t := TdButton.new()
	t.style = TdButton.Style.TAB
	t.force_state(false, true)
	assert_eq(t._sprite_now(), "tab_normal", "a pressed tab never looks selected")
	assert_num(t._bg.self_modulate.r, 0.92)
	assert_eq(t.face_node().position, Vector2.ZERO, "flat: nothing moves")
	t.free()
	var p := TdButton.new()
	p.style = TdButton.Style.PRIMARY
	p.force_state(false, true)
	assert_eq(p._sprite_now(), "btn_primary_pressed", "the kit's pressed face: same outline, darker")
	assert_num(p._bg.self_modulate.r, 1.0)
	p.free()

## The generated theme files are what the generator makes from its inputs (UITheme.json, kit_slices.json,
## kit_tokens.json, EXTRA_SPRITES): a hand edit of td_tokens.gd / td_theme.tres / half/ fails here. Fix: move the
## change into an input and re-run `godot --headless --path . -s tools/build_theme.gd` (same check: `-- --check`).
func test_theme_generator_has_no_drift() -> void:
	var b = load("res://tools/theme_builder.gd").new()
	var bad: PackedStringArray = b.drift()
	assert_eq(bad.size(), 0, "\n  ".join(bad))

## The roles and the kit drop-ins come from the generator (they were once only in a hand-edited td_tokens.gd).
func test_generated_roles_and_kit_drop_ins() -> void:
	assert_eq(TdTheme.role_sprite("panel"), "panel_wood")
	assert_eq(TdTheme.role_sprite("decal_target"), "decal_target_valid")
	assert_eq(TdTheme.role_sprite("stat_icon.Power"), "icon_power")
	for s in ["icon_gold", "icon_backpack", "token_gold", "badge_tired"]:
		assert_true(TdTheme.has_sprite(s), s)
	assert_eq(TdTheme.texture("icon_gold"), TdTheme.kit("icons/icon_gold"), "same texture as the by-path lookup")
	assert_eq(TdTheme.texture("token_gold"), TdTheme.kit("tokens/gold"))
