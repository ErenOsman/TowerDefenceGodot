class_name TooltipText
extends RefCounted
## The game's tooltips in one style (port of the Unity TooltipText / EntityText helpers), as BBCode for RichTextLabel
## (TdTooltip / TdTooltipStack show them): a title coloured by kind (gold abilities, purple passives, red harmful and
## green helpful statuses, blue towers) with a small grey subtitle line, the description (changing numbers bold,
## keywords coloured), stat rows ("Power: 10", a value changed from its base "10 » 12"), and a footer band (cooldown,
## cost, state). Tooltips are paper, so every role colour is its ink version (all >= 4.5:1 on paper).
## Content builders return {"header", "body", "footer_label", "footer_value"} for TdTooltip.show_content().

const SUBTITLE_SIZE := 20 # type.small (Nunito Bold 20)
const NOTE_SIZE := 20
const SUBTITLE_FONT := "res://art/fonts/Nunito-Bold.ttf"

static var _keywords: Array = []

# ------------------------------------------------------------------ colours (paper)

static func ability_color() -> String: return TdTheme.rich("gold.ink")
static func passive_color() -> String: return TdTheme.rich("status.ink")
static func harmful_color() -> String: return TdTheme.rich("bad.ink")
static func helpful_color() -> String: return TdTheme.rich("good.ink")
static func neutral_color() -> String: return TdTheme.rich("accent.ink")
static func tower_color() -> String: return TdTheme.rich("accent.ink")
static func enemy_color() -> String: return TdTheme.rich("bad.ink")
static func label_color() -> String: return TdTheme.rich("ink.2")
static func subtitle_color() -> String: return TdTheme.rich("ink.2")
static func note_color() -> String: return TdTheme.rich("ink.2")
static func value_color() -> String: return TdTheme.rich("gold.ink")

## The title colour for a kind: "ability", "passive", "harmful"/"debuff", "helpful"/"buff", "status", "tower", "enemy".
static func kind_color(kind: String) -> String:
	match kind:
		"ability": return ability_color()
		"passive": return passive_color()
		"harmful", "debuff", "bad": return harmful_color()
		"helpful", "buff", "good": return helpful_color()
		"tower": return tower_color()
		"enemy": return enemy_color()
		_: return neutral_color()

# ------------------------------------------------------------------ pieces

## Escapes text so "[" shows literally.
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")

static func colored(color_hex: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [color_hex, text]

static func bold(text: String) -> String:
	return "[b]%s[/b]" % text

## The coloured title with an optional small grey subtitle line (Nunito Bold 20).
static func title(text: String, color_hex: String, subtitle := "") -> String:
	var s := colored(color_hex, text)
	if subtitle != "":
		s += "\n[font=%s][font_size=%d]%s[/font_size][/font]" % [SUBTITLE_FONT, SUBTITLE_SIZE, colored(subtitle_color(), subtitle)]
	return s

## "Label: value" with a grey label.
static func row(label: String, value: String) -> String:
	return "%s %s" % [colored(label_color(), label + ":"), value]

## A small grey line.
static func note(text: String) -> String:
	return "[font_size=%d]%s[/font_size]" % [NOTE_SIZE, colored(note_color(), text)]

## The value now; when it differs from the base, "base » now" with now green (higher) or red (lower).
static func changed(base_value: String, now: String) -> String:
	if base_value == "" or base_value == now: return now
	var n = lead(now)
	var b = lead(base_value)
	var c := harmful_color() if (n != null and b != null and n < b) else helpful_color()
	return "%s %s %s" % [colored(subtitle_color(), base_value), TdTheme.ARROW, colored(c, now)]

## A stat row with its base: row(label, changed(base, now)).
static func stat_row(label: String, base_value: String, now: String) -> String:
	return row(label, changed(base_value, now))

## The number a value starts with ("60 x2" -> 60.0), or null.
static func lead(value: String) -> Variant:
	var head := ""
	for ch in value:
		if ch.is_valid_int() or ch == "." or (ch == "-" and head == ""): head += ch
		else: break
	if head == "" or head == "-" or head == ".": return null
	return float(head)

## Result tags as one line: "[b]10[/b] Damage  ·  [b]2[/b] Range" (value and name joined by a no-break space, so a
## long line wraps between tags, never inside one; the names are the sim's AbilityText.tags: Damage, Heal, Range, Area,
## Hits, Jumps, Duration; final values only, no bonus); "" when none. tags = [[value, name], …].
static func tag_line(tags: Array) -> String:
	var parts: PackedStringArray = []
	for t in tags:
		parts.append("[b]%s[/b]\u00a0%s" % [str(t[0]), str(t[1]).replace(" ", "\u00a0")])
	return "  ·  ".join(parts)

## The words descriptions colour as keywords (status names), longest first.
static func set_keywords(names: Array) -> void:
	_keywords.clear()
	for n in names:
		if str(n) != "" and not _keywords.has(str(n)): _keywords.append(str(n))
	_keywords.sort_custom(func(a, b): return a.length() > b.length() or (a.length() == b.length() and a < b))

## A description as shown: every number bold (changeable values), every keyword (a status name) in the status colour,
## never underlined; Unity rich text (<b>, <color=…>) converted to BBCode. links = true also wraps each keyword in
## [url=kw:<Name>] so an interactive RichTextLabel can open its nested tooltip (enable_keyword_tooltips).
static func describe(description: String, links := false) -> String:
	if description == "": return description
	var text := from_rich(description)
	var num := RegEx.create_from_string("(?<![\\w#=.\\[])(\\d+(?:\\.\\d+)?)(?![\\w\\]])")
	text = num.sub(text, "[b]$1[/b]", true)
	for word in _keywords:
		var re := RegEx.create_from_string("(?i)(?<![\\w\\]])(" + _regex_escape(word) + ")(?![\\w\\[])")
		var rep := "[color=%s]$1[/color]" % passive_color()
		if links: rep = "[url=kw:%s]%s[/url]" % [word, rep]
		text = re.sub(text, rep, true)
	return text

## Keywords in an interactive RichTextLabel (Codex / Info rows; tooltips themselves never take the mouse) open their
## own tooltip on hover (a TdTooltipStack box beside the label), not underlined. content_of(keyword) -> a TooltipText
## content Dictionary ({header, body}) or {} for none. Use describe(text, true) for the label's text.
static func enable_keyword_tooltips(label: RichTextLabel, content_of: Callable) -> void:
	label.meta_underlined = false
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.meta_hover_started.connect(func(meta) -> void:
		var m := str(meta)
		if not m.begins_with("kw:"): return
		var c: Dictionary = content_of.call(m.trim_prefix("kw:"))
		if c.is_empty(): return
		TdTooltipStack.show(label, label.get_global_rect(), [c], TdTooltipPlacement.Side.AUTO))
	label.meta_hover_ended.connect(func(_meta) -> void: TdTooltipStack.hide(label))

## The clock icon for time lines (kit statuses/parts/icon_clock, two-tone) as a BBCode image at size px.
static func clock_icon(size := 20) -> String:
	var path: String = TdTokens.SPRITES["icon_clock_status"][0] if TdTokens.SPRITES.has("icon_clock_status") else ""
	if path == "": return ""
	return "[img=%dx%d]%s[/img]" % [size, size, path]

## "[clock] [b]12[/b] turns left · applied by Alchemist (Acid Flask)" (the number bold: it changes).
static func time_left(turns_left: int, rounds := false, applied_by := "") -> String:
	var unit := "round" if rounds else "turn"
	var t := "%s [b]%d[/b] %s left" % [clock_icon(), turns_left, unit if turns_left == 1 else unit + "s"]
	if applied_by != "": t += " · applied by " + applied_by
	return t

static func _regex_escape(s: String) -> String:
	var out := ""
	for ch in s:
		if ch in "\\^$.|?*+()[]{}": out += "\\"
		out += ch
	return out

## Unity TMP rich text -> BBCode: <b>, <i>, <u>, <color=#hex>/<color=name>, <size=NN%>/<size=NN> (sizes dropped).
static func from_rich(text: String) -> String:
	var t := text
	t = t.replace("<b>", "[b]").replace("</b>", "[/b]").replace("<i>", "[i]").replace("</i>", "[/i]")
	t = t.replace("<u>", "").replace("</u>", "")
	var col := RegEx.create_from_string("<color=\"?([#\\w]+)\"?>")
	t = col.sub(t, "[color=$1]", true)
	t = t.replace("</color>", "[/color]")
	var size := RegEx.create_from_string("</?size[^>]*>")
	t = size.sub(t, "", true)
	return t

## Description, then the rows, then extra lines, separated by blank lines.
static func body(description: String, rows: Array = [], extra: Array = []) -> String:
	var parts: PackedStringArray = []
	if description != "": parts.append(description)
	var r: PackedStringArray = []
	for x in rows:
		if str(x) != "": r.append(str(x))
	if not r.is_empty(): parts.append("\n".join(r))
	var e: PackedStringArray = []
	for x in extra:
		if str(x) != "": e.append(str(x))
	if not e.is_empty(): parts.append("\n".join(e))
	return "\n\n".join(parts)

static func turns(n: int, unit := "turn") -> String:
	return "1 %s" % unit if n == 1 else "%d %ss" % [n, unit]

## The cooldown in words (UI Design Rules): "1 turn CD", "2 turn CD", "CD until reset".
static func cooldown_words(cooldown: int, until_reset := false) -> String:
	return "CD until reset" if until_reset else "%d turn CD" % maxi(1, cooldown)

## How soon it is ready: "Ready", "In 1 turn", "In 3 turns", "After a reset" (held, or left == Entity.HeldCooldown).
static func ready_in(left: int, held := false) -> String:
	if held or left == Entity.HeldCooldown: return "After a reset"
	if left <= 0: return "Ready"
	return "In 1 turn" if left == 1 else "In %d turns" % left

static func content(header: String, body_text: String, footer_label := "", footer_value := "") -> Dictionary:
	return {"header": header, "body": body_text, "footer_label": footer_label, "footer_value": footer_value}

# ------------------------------------------------------------------ kinds

## An ability: tags as the subtitle ("Attack · ranged"), the full description, the result tags line, extra lines (e.g.
## why it cannot be cast), the cooldown in the footer with its state ("Ready" green / "In 1 turn" red).
static func ability(name: String, description: String, subtitle := "", result_tags: Array = [], cooldown := 1,
		until_reset := false, cooldown_left := 0, extra_lines: Array = [], start_cooldown := 0) -> Dictionary:
	var rows := []
	var tl := tag_line(result_tags)
	if tl != "": rows.append(tl)
	if start_cooldown != 0:
		rows.append(note("Starts locked." if start_cooldown < 0 else "Starts on cooldown (%s)." % turns(start_cooldown)))
	var state := ready_in(cooldown_left, until_reset and cooldown_left != 0)
	return content(title(name, ability_color(), subtitle), body(describe(description), rows, extra_lines),
		cooldown_words(cooldown, until_reset), colored(helpful_color() if cooldown_left == 0 else harmful_color(), state))

## A passive: "Passive" subtitle, description, Active / Inactive in the footer.
static func passive(name: String, description: String, active := true) -> Dictionary:
	return content(title(name, passive_color(), "Passive"), describe(description) if description != "" else "No description.",
		"State", colored(helpful_color(), "Active") if active else colored(subtitle_color(), "Inactive"))

## A status (for the status tooltip stack, which has no footer): red when harmful (Debuff), green when helpful (Buff);
## the description, and a time line "[clock] [b]2[/b] turns left · applied by X" (turns_left < 0: permanent, no time;
## just "Applied by X" when known). The subtitle names the stacks: "Harmful · 15 stacks" (never "×"); stack_word
## replaces "stacks" ("left" for Shield: "Helpful · 1250 left"); with_stacks false leaves them out (the chip's pill or
## the body already says it).
static func status(name: String, description: String, harmful: bool, helpful: bool, stacks := 1, turns_left := -1,
		rounds := false, with_stacks := true, applied_by := "", stack_word := "stacks") -> Dictionary:
	var kind := "Harmful" if harmful else ("Helpful" if helpful else "Status")
	if with_stacks and stacks > 1: kind += " · %d %s" % [stacks, stack_word]
	var rows := []
	if turns_left >= 0:
		rows.append(time_left(turns_left, rounds, applied_by))
	elif applied_by != "":
		rows.append(note("Applied by " + applied_by))
	var col := harmful_color() if harmful else (helpful_color() if helpful else neutral_color())
	return content(title(name, col, kind), body(describe(description) if description != "" else "No description.", rows))

## A tower in the hand / on the board: "Tower · Ctrl+1" subtitle, description, stat rows ([label, value] or
## [label, base, now]); footer = cost (red when unaffordable) in the hand, the sell refund once placed.
static func tower(name: String, description: String, key_text := "", stat_rows: Array = [], on_board := false,
		affordable := true, cost := 0, sell_value := 0) -> Dictionary:
	var rows := []
	for r in stat_rows:
		rows.append(row(r[0], changed(str(r[1]), str(r[2]))) if r.size() >= 3 else row(r[0], str(r[1])))
	var fv := "+%d energy" % sell_value if on_board else ("%d energy" % cost if affordable else colored(harmful_color(), "%d energy" % cost))
	return content(title(name, tower_color(), "Tower · " + key_text if key_text != "" else "Tower"), body(describe(description), rows),
		"On the board · sell" if on_board else "Cost", fv)

## An enemy: red title, "Enemy" subtitle (+ where), description, stat rows, optional next-turn line.
static func enemy(name: String, description: String, where := "", stat_rows: Array = [], next_turn := "") -> Dictionary:
	var rows := []
	for r in stat_rows:
		rows.append(row(r[0], changed(str(r[1]), str(r[2]))) if r.size() >= 3 else row(r[0], str(r[1])))
	var extra := [row("Next turn", next_turn)] if next_turn != "" else []
	return content(title(name, enemy_color(), "Enemy · " + where if where != "" else "Enemy"), body(describe(description), rows, extra))
