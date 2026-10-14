extends TestCase
## The web build has no system fallback font: every symbol the UI writes must come from a bundled font. Nunito and
## Plinth lack arrows, check marks, shapes…; their import settings (art/fonts/*.ttf.import `fallbacks`) chain
## DejaVuSans-Bold-TdSubset + NotoSansSymbols-TdSubset. Checks Font.has_char and a TextServer shape (no glyph
## drawn as the missing-glyph box) for every font the theme and the board overlays use.

const GLYPHS := "✓→●▲▼▶←↻ⓘ⧗✕⚠♛—›‹•°≤≥±»"
const FALLBACKS := ["res://art/fonts/DejaVuSans-Bold-TdSubset.ttf", "res://art/fonts/NotoSansSymbols-TdSubset.ttf"]

func _theme_fonts() -> Array:
	var out := []
	for key in TdTokens.FONT_FILES:
		out.append(load(TdTokens.FONT_FILES[key]))
	var th: Theme = load("res://game/ui/theme/td_theme.tres")
	if th.default_font != null: out.append(th.default_font)
	for t in th.get_type_list():
		for n in th.get_font_list(t): out.append(th.get_font(n, t))
	out.append(OverlayStyle.font(OverlayStyle.DISPLAY_FONT))
	out.append(OverlayStyle.font(OverlayStyle.BODY_FONT))
	return out

func test_every_theme_font_has_the_fallbacks() -> void:
	for f in _theme_fonts():
		var base: Font = f
		while base is FontVariation and (base as FontVariation).base_font != null: base = (base as FontVariation).base_font
		var paths := []
		for fb in base.fallbacks: paths.append(fb.resource_path)
		assert_seq(paths, FALLBACKS, "%s fallbacks" % base.resource_path)

func test_every_glyph_is_covered() -> void:
	for f in _theme_fonts():
		var font: Font = f
		var missing := ""
		for ch in GLYPHS:
			if not font.has_char(ch.unicode_at(0)): missing += ch
		assert_eq(missing, "", "%s lacks glyphs" % font.resource_path)

func test_shaped_text_has_no_missing_glyph_boxes() -> void:
	var ts := TextServerManager.get_primary_interface()
	for f in _theme_fonts():
		var font: Font = f
		var line := TextLine.new()
		line.add_string("you have 2 → 1 " + GLYPHS, font, 22)
		var rid := line.get_rid()
		var bad := []
		var chain := font.get_rids() # the font + its bundled fallbacks (not the desktop's system fonts)
		for g in ts.shaped_text_get_glyphs(rid):
			# a glyph no bundled font has: index 0, the hex box flag, or drawn from a system font (absent on the web)
			if int(g.index) == 0 or (int(g.flags) & TextServer.GRAPHEME_IS_VALID) == 0 or not chain.has(g.font_rid):
				bad.append(int(g.start))
		assert_eq(bad, [], "%s draws boxes at %s" % [font.resource_path, str(bad)])
