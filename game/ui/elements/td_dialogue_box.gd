class_name TdDialogueBox
extends Control
## The visual-novel dialogue box (port of UI_DialogueBox; UI Design Rules, Dialogue): dialogue_box wood panel about
## 1100 x 220 (the caller places / anchors this control), the speaker on a cobalt name plate over the top edge
## (Plinth 26 white), the line revealed letter by letter (`letters_per_second`, Nunito 22 cream; BBCode allowed), a
## bobbing Next mark once the whole line shows and it waits for a click, Skip (with its key) in the top-right corner,
## optional notes (step counter bottom-left, hint bottom-right) and a bust portrait standing on the box's left edge
## that slides in (60 px, motion.normal, ease out) when a new speaker first talks. A click on the box shows the whole
## line, a second one continues (clicked); Skip raises skip_clicked. Unscaled time. No game references.
##   show_line(speaker, text, wait_for_click, portrait := null), reveal_all(), hide_line(), set_notes(step, hint),
##   set_skip_key(text), is_shown(), is_fully_shown(); signals clicked, skip_clicked
## (hide_line, not hide: Control.hide() cannot be overridden.)

signal clicked
signal skip_clicked

@export var letters_per_second := 40.0
@export var next_bob := 4.0
@export var portrait_slide := 60.0
@export var portrait_height := 560.0
@export var text_size := 22
## The portrait stands on the box's left edge (false: right edge).
@export var portrait_left := true

var _content: Control
var _portrait: TextureRect
var _box: Panel
var _plate: Panel
var _name: Label
var _text: RichTextLabel
var _next: TextureRect
var _skip: TdButton
var _step: Label
var _hint: RichTextLabel
var _letters := 0
var _revealed := 0.0
var _waits := false
var _speaker := ""
var _portrait_t := 1.0
var _clock := 0.0
var _built := false

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _ready() -> void:
	_build()

func _build() -> void:
	if _built: return
	_built = true
	if size == Vector2.ZERO: size = Vector2(1100, 220)
	_content = Control.new()
	_content.mouse_filter = MOUSE_FILTER_IGNORE
	_content.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_content)
	_portrait = TextureRect.new()
	_portrait.mouse_filter = MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_portrait.visible = false
	_content.add_child(_portrait)
	_box = Panel.new()
	_box.mouse_filter = MOUSE_FILTER_STOP
	_box.add_theme_stylebox_override("panel", TdTheme.stylebox("dialogue_box"))
	_box.gui_input.connect(_on_box_input)
	_content.add_child(_box)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.mouse_filter = MOUSE_FILTER_IGNORE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	TdTheme.apply_type(_text, "body", TdTheme.color("cream.100"), text_size)
	_text.add_theme_font_override("bold_font", TdTheme.font("nunito_extrabold"))
	_text.add_theme_constant_override("line_separation", 6)
	_box.add_child(_text)
	_plate = Panel.new()
	_plate.mouse_filter = MOUSE_FILTER_IGNORE
	_plate.add_theme_stylebox_override("panel", TdTheme.stylebox("tag_phase_player"))
	_content.add_child(_plate)
	_name = Label.new()
	_name.mouse_filter = MOUSE_FILTER_IGNORE
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TdTheme.apply_type(_name, "header", Color.WHITE)
	_plate.add_child(_name)
	_skip = TdButton.new()
	_skip.style = TdButton.Style.SECONDARY
	_skip.custom_minimum_size = Vector2(150, 44)
	_skip.size = Vector2(150, 44)
	_skip.font_size = 22
	_skip.text = "Skip"
	_content.add_child(_skip)
	_skip.set_key_hint("Esc")
	_skip.fit_to_content(120)
	_skip.clicked.connect(func() -> void: skip_clicked.emit())
	_step = Label.new()
	_step.mouse_filter = MOUSE_FILTER_IGNORE
	TdTheme.apply_type(_step, "small", TdTheme.color("cream.300"))
	_step.visible = false
	_box.add_child(_step)
	_hint = RichTextLabel.new()
	_hint.bbcode_enabled = true
	_hint.scroll_active = false
	_hint.fit_content = true
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.mouse_filter = MOUSE_FILTER_IGNORE
	TdTheme.apply_type(_hint, "small", TdTheme.color("cream.300"))
	_hint.visible = false
	_box.add_child(_hint)
	_next = TextureRect.new()
	_next.mouse_filter = MOUSE_FILTER_IGNORE
	_next.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_next.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_next.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_next.texture = TdTheme.texture("icon_next")
	_next.modulate = TdTheme.color("gold")
	_next.visible = false
	_box.add_child(_next)
	resized.connect(_layout)
	_content.visible = false
	_layout()

func _layout() -> void:
	if not _built: return
	var s := size
	_box.position = Vector2.ZERO
	_box.size = s
	# padding (kit tokens dialogueBox): 40 top, 40 right, 24 bottom, 56 left
	_text.position = Vector2(56, 40)
	_text.size = Vector2(s.x - 56 - 40, s.y - 40 - 24 - 34)
	_name.size = Vector2.ZERO
	var nf: Font = TdTheme.font("plinth")
	var nw := maxf(160.0, nf.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TdTheme.font_size("header")).x + 48.0)
	_plate.size = Vector2(nw, 52)
	_plate.position = Vector2(40, -30)
	_name.position = Vector2.ZERO
	_name.size = _plate.size - Vector2(0, 2)
	_skip.position = Vector2(s.x - _skip.size.x - 28, -24)
	_step.position = Vector2(56, s.y - 24 - 28)
	_step.size = Vector2(400, 28)
	_hint.size = Vector2(0, 0)
	var hw := _hint.get_content_width()
	_hint.position = Vector2(s.x - 40 - hw - (40.0 if _next.visible else 0.0), s.y - 24 - 28)
	_hint.size = Vector2(hw + 4, 28)
	_next.size = Vector2(28, 28)
	_next.position = Vector2(s.x - 40 - 28, s.y - 24 - 30)
	var ph := portrait_height
	var tex := _portrait.texture
	var pw := ph * 0.8 if tex == null else ph * tex.get_size().x / maxf(1.0, tex.get_size().y)
	_portrait.size = Vector2(pw, ph)
	var px := -pw * 0.62 if portrait_left else s.x - pw * 0.38
	_portrait.position = Vector2(px, s.y - ph)

# ------------------------------------------------------------------ API

func is_shown() -> bool:
	return _built and _content.visible

func is_fully_shown() -> bool:
	return _revealed >= _letters

## Shows a line: the speaker ("" hides the plate), the text (BBCode) appearing from the start, the Next mark once it
## waits for a click and is fully shown, the portrait (null: none; a new speaker slides in).
func show_line(speaker: String, line: String, wait_for_click := true, portrait: Texture2D = null) -> void:
	_build()
	_content.visible = true
	_name.text = speaker
	_plate.visible = speaker != ""
	_portrait.texture = portrait
	_portrait.visible = portrait != null
	if portrait != null and speaker != _speaker:
		_portrait_t = 0.0
		_portrait.modulate.a = 0.0
	_speaker = speaker
	_text.text = line
	_text.visible_characters = 0
	_letters = _text.get_total_character_count()
	_revealed = 0.0
	_waits = wait_for_click
	if letters_per_second <= 0.0: reveal_all()
	_update_next()
	_layout()

## The small notes: a step counter ("Tutorial · 2/12") and a hint ("Click or Space to show all"; BBCode); "" hides each.
func set_notes(step: String, hint: String) -> void:
	_build()
	_step.text = step
	_step.visible = step != ""
	_hint.text = hint
	_hint.visible = hint != ""
	_layout()

## The key shown on Skip ("Esc"; "" hides the badge). Read it from KeyBinds.
func set_skip_key(t: String) -> void:
	_build()
	_skip.set_key_hint(t)
	_skip.fit_to_content(120)
	_layout()

func set_skip_visible(v: bool) -> void:
	_build()
	_skip.visible = v

func reveal_all() -> void:
	_revealed = _letters
	if _text: _text.visible_characters = -1
	_update_next()

## Hides the box; the next speaker slides in again.
func hide_line() -> void:
	_build()
	_content.visible = false
	_speaker = ""

func _update_next() -> void:
	if _next:
		_next.visible = _waits and is_fully_shown()
		_layout()

func _on_box_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if not is_shown(): return
		if not is_fully_shown():
			reveal_all()
		else:
			clicked.emit()
		_box.accept_event()

func _process(delta: float) -> void:
	if not is_shown(): return
	var dt := TdTheme.unscaled(delta)
	_clock += dt
	if not is_fully_shown() and letters_per_second > 0.0:
		_revealed = minf(_letters, _revealed + letters_per_second * dt)
		_text.visible_characters = int(floor(_revealed))
		if is_fully_shown(): _update_next()
	if _next.visible:
		_next.position.y = size.y - 24 - 30 - sin(_clock * 4.0) * next_bob
	if _portrait_t < 1.0:
		_portrait_t = minf(1.0, _portrait_t + dt / maxf(0.01, TdTheme.motion("normal")))
		var k := TdTheme.eased("out", _portrait_t)
		var pw := _portrait.size.x
		var px := -pw * 0.62 if portrait_left else size.x - pw * 0.38
		_portrait.position.x = px + (-portrait_slide if portrait_left else portrait_slide) * (1.0 - k)
		_portrait.modulate.a = k
