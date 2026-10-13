extends TestCase
## UI kit: TooltipText BBCode (titles, stat rows "base » now", tags, cooldown words), chip badge text, bar layout helpers.

func _has(text: String, part: String) -> void:
	assert_true(text.contains(part), "expected %s in %s" % [part, text])

func teardown() -> void:
	TooltipText.set_keywords([])

func test_stat_row_shows_base_and_now() -> void:
	var good := TdTheme.rich("good.ink")
	var bad := TdTheme.rich("bad.ink")
	var sub := TdTheme.rich("ink.2")
	assert_eq(TooltipText.changed("10", "10"), "10")
	assert_eq(TooltipText.changed("", "7"), "7")
	assert_eq(TooltipText.changed("10", "12"), "[color=%s]10[/color] » [color=%s]12[/color]" % [sub, good])
	assert_eq(TooltipText.changed("10", "8"), "[color=%s]10[/color] » [color=%s]8[/color]" % [sub, bad])
	assert_eq(TooltipText.row("Power", "10"), "[color=%s]Power:[/color] 10" % sub)
	assert_eq(TooltipText.stat_row("Range", "2", "3"), "[color=%s]Range:[/color] " % sub + TooltipText.changed("2", "3"))

func test_lead_number() -> void:
	assert_num(TooltipText.lead("60 ×2"), 60.0)
	assert_num(TooltipText.lead("-1"), -1.0)
	assert_num(TooltipText.lead("2.5 tiles"), 2.5)
	assert_null(TooltipText.lead("none"))

func test_title_tags_and_words() -> void:
	var t := TooltipText.title("Shoot", TooltipText.ability_color(), "Attack · ranged")
	assert_true(t.begins_with("[color=%s]Shoot[/color]\n" % TdTheme.rich("gold.ink")))
	_has(t, "Attack · ranged")
	assert_eq(TooltipText.tag_line([["10", "Damage"], ["2", "Range"]]), "[b]10[/b]\u00a0Damage  ·  [b]2[/b]\u00a0Range")
	assert_eq(TooltipText.tag_line([]), "")
	assert_eq(TooltipText.cooldown_words(1), "1 turn CD")
	assert_eq(TooltipText.cooldown_words(0), "1 turn CD")
	assert_eq(TooltipText.cooldown_words(3), "3 turn CD")
	assert_eq(TooltipText.cooldown_words(2, true), "CD until reset")
	assert_eq(TooltipText.ready_in(0), "Ready")
	assert_eq(TooltipText.ready_in(1), "In 1 turn")
	assert_eq(TooltipText.ready_in(3), "In 3 turns")
	assert_eq(TooltipText.ready_in(Entity.HeldCooldown), "After a reset")
	assert_eq(TooltipText.turns(1, "round"), "1 round")

func test_kind_colours_on_paper() -> void:
	assert_eq(TooltipText.kind_color("ability"), TdTheme.rich("gold.ink"))
	assert_eq(TooltipText.kind_color("passive"), TdTheme.rich("status.ink"))
	assert_eq(TooltipText.kind_color("debuff"), TdTheme.rich("bad.ink"))
	assert_eq(TooltipText.kind_color("buff"), TdTheme.rich("good.ink"))
	assert_eq(TooltipText.kind_color("tower"), TdTheme.rich("accent.ink"))

func test_describe_bolds_numbers_and_colours_keywords() -> void:
	TooltipText.set_keywords(["Burn", "Slime Shield", "Shield"])
	var d := TooltipText.describe("Deals 10 damage and applies Burn for 2 turns.")
	assert_eq(d, "Deals [b]10[/b] damage and applies [color=%s]Burn[/color] for [b]2[/b] turns." % TdTheme.rich("status.ink"))
	# longest keyword first, numbers inside existing markup untouched
	var d2 := TooltipText.describe("Gains Slime Shield. <color=#ff0000>3</color>")
	_has(d2, "[color=%s]Slime Shield[/color]" % TdTheme.rich("status.ink"))
	_has(d2, "[color=#ff0000][b]3[/b][/color]")
	assert_eq(TooltipText.from_rich("<b>x</b> <size=70%>y</size>"), "[b]x[/b] y")

func test_body_joins_parts() -> void:
	assert_eq(TooltipText.body("Desc", ["a", "b"], ["c"]), "Desc\n\na\nb\n\nc")
	assert_eq(TooltipText.body("", [], []), "")

func test_content_builders() -> void:
	var a := TooltipText.ability("Shoot", "Shoots for 10.", "Attack", [["10", "Damage"]], 2, false, 1)
	assert_eq(a["footer_label"], "2 turn CD")
	_has(a["footer_value"], "In 1 turn")
	_has(a["footer_value"], TdTheme.rich("bad.ink"))
	var s := TooltipText.status("Poison", "Takes 3.", true, false, 4, 2)
	_has(s["header"], "Harmful · 4 stacks")
	assert_false(s["header"].contains("×"), "never × for stacks")
	_has(s["body"], "[b]2[/b] turns left")
	assert_false(s["body"].contains("Duration"))
	_has(s["body"], "[img=")
	var sh := TooltipText.status("Shield", "Absorbs damage.", false, true, 1250, -1, false, true, "Rockjaw", "left")
	_has(sh["header"], "Helpful · 1250 left")
	_has(TooltipText.time_left(1, true, "Mage"), "[b]1[/b] round left · applied by Mage")
	TooltipText.set_keywords(["Burn"])
	_has(TooltipText.describe("Applies Burn.", true), "[url=kw:Burn]")
	var p := TooltipText.status("Haste", "", false, true, 1, -1, false)
	_has(p["header"], TdTheme.rich("good.ink"))
	assert_false(p["body"].contains("left"))
	var t := TooltipText.tower("Archer", "Shoots.", "Ctrl+1", [["HP", "20"], ["Power", "10", "12"]], false, false, 100)
	_has(t["header"], "Tower · Ctrl+1")
	assert_eq(t["footer_label"], "Cost")
	_has(t["footer_value"], TdTheme.rich("bad.ink"))
	_has(t["body"], "»")

func test_badge_text_shortens_four_digits() -> void:
	assert_eq(TdIconChip.short_number(7), "7")
	assert_eq(TdIconChip.short_number(999), "999")
	assert_eq(TdIconChip.short_number(1000), "1.0k")
	assert_eq(TdIconChip.short_number(1250), "1.2k")
	assert_eq(TdIconChip.short_number(1299), "1.2k")
	assert_eq(TdIconChip.short_number(9999), "9.9k")
	assert_eq(TdIconChip.short_number(12345), "12k")
	assert_eq(TdIconChip.badge_text("1250"), "1.2k")
	assert_eq(TdIconChip.badge_text("x"), "x")

func test_badge_sizes_follow_the_chip() -> void:
	assert_seq(TdIconChip.badge_metrics(32), [18.0, 14])
	assert_seq(TdIconChip.badge_metrics(40), [22.0, 16])
	assert_seq(TdIconChip.badge_metrics(48), [24.0, 18])
	assert_num(TdIconChip.pill_width(8, 18), 18.0) # one digit: round
	assert_num(TdIconChip.pill_width(30, 18), 30 + 18 * 0.55)

func test_icon_bar_slots() -> void:
	var s := TdIconBar.slots(4, 32, 12, 12, 0, TdIconBar.Align.LEFT, false)
	assert_seq(s, [Vector2(0, 0), Vector2(44, 0), Vector2(88, 0), Vector2(132, 0)]) # a row of 4 = 164 px
	var w := TdIconBar.slots(5, 40, 12, 8, 3, TdIconBar.Align.CENTER, false)
	assert_eq(w[3], Vector2((3 * 40 + 2 * 12 - (2 * 40 + 12)) / 2.0, 48))
	var up := TdIconBar.slots(4, 32, 12, 12, 2, TdIconBar.Align.LEFT, true)
	assert_eq(up[0], Vector2(0, 44)) # rows grow up: the first row is the bottom one

func test_health_colour_and_label() -> void:
	assert_eq(TdHealthBar.color_for(1.0), TdTheme.color("hp.high"))
	assert_eq(TdHealthBar.color_for(0.61), TdTheme.color("hp.high"))
	assert_eq(TdHealthBar.color_for(0.6), TdTheme.color("hp.mid"))
	assert_eq(TdHealthBar.color_for(0.31), TdTheme.color("hp.mid"))
	assert_eq(TdHealthBar.color_for(0.3), TdTheme.color("hp.low"))
	assert_eq(TdHealthBar.format_label("{0} / {1}", 20, 20), "20 / 20")
	assert_eq(TdHealthBar.format_label("{0}/{1}", 7.5, 20), "7.5/20")

func test_motion_channels_add_up() -> void:
	var m := TdMotion.new()
	m.to(TdMotion.SCALE, 1.1, 0.2, "linear")
	m.shake(6, 0.32)
	m.step(0.1)
	assert_num(snappedf(m.value(TdMotion.SCALE), 0.001), 1.05)
	assert_true(m.is_shaking())
	m.step(0.5)
	assert_num(m.value(TdMotion.SCALE), 1.1)
	assert_false(m.is_shaking())
	assert_num(m.offset().x, 0.0)
	m.to(TdMotion.LIFT, 5, 0)
	assert_eq(m.offset(), Vector2(0, -5))
	m.pulse(0.03, 1.6)
	m.step(0.4) # a quarter period: phase 0.5
	assert_num(snappedf(m.scale_value(), 0.0001), snappedf(1.1 * 1.015, 0.0001))
