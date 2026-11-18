extends PanelContainer
## Reusable dialogue box: typewriter text, clickable suggestions and a free-text
## input. It knows nothing about the NPC; it only emits signals and shows replies.

signal submitted(text: String)
signal closed
signal typing_changed(active: bool)
signal blip

var _last_typed := 0

var _speech: RichTextLabel
var _thinking: Label
var _suggestions: HBoxContainer
var _input: LineEdit
var _send: Button
var _close: Button
var _tween: Tween
var _pulse: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -250
	offset_left = 20
	offset_right = -20
	offset_bottom = -20
	# Opaque background and its own border, so the box does not blend into the floor.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("14101f")
	sb.border_color = Color("a9c8e8")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	_speech = RichTextLabel.new()
	_speech.custom_minimum_size = Vector2(0, 100)
	_speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_speech.add_theme_font_size_override("normal_font_size", 22)
	box.add_child(_speech)

	_thinking = Label.new()
	_thinking.visible = false
	box.add_child(_thinking)

	_suggestions = HBoxContainer.new()
	_suggestions.add_theme_constant_override("separation", 8)
	box.add_child(_suggestions)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_input = LineEdit.new()
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_t: String) -> void: _on_send())
	row.add_child(_input)
	_send = Button.new()
	_style_button(_send)
	_send.pressed.connect(_on_send)
	row.add_child(_send)
	_close = Button.new()
	_style_button(_close)
	_close.pressed.connect(func() -> void: closed.emit())
	row.add_child(_close)
	set_labels("pt")


func set_labels(lang: String) -> void:
	_input.placeholder_text = "Escreva livremente..." if lang == "pt" else "Write freely..."
	_send.text = "Enviar" if lang == "pt" else "Send"
	_close.text = "Sair" if lang == "pt" else "Leave"
	_thinking.text = "…a névoa se agita…" if lang == "pt" else "…the fog stirs…"


func show_thinking() -> void:
	_set_input_enabled(false)
	_clear_suggestions()
	_thinking.visible = true
	if _pulse:
		_pulse.kill()
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_thinking, "modulate:a", 0.25, 0.6)
	_pulse.tween_property(_thinking, "modulate:a", 1.0, 0.6)


func show_response(data: Dictionary) -> void:
	if _pulse:
		_pulse.kill()
	_thinking.visible = false
	set_labels(data["language"])
	_speech.text = data["speech"]
	_speech.visible_characters = 0
	_last_typed = 0
	if _tween:
		_tween.kill()
	typing_changed.emit(true)
	_tween = create_tween()
	var total := _speech.get_total_character_count()
	_tween.tween_method(_on_typed, 0, total, maxf(0.4, total * 0.03))
	_tween.finished.connect(func() -> void: typing_changed.emit(false))
	_clear_suggestions()
	for s in data["suggestions"]:
		var b := Button.new()
		_style_button(b)
		b.text = s
		b.pressed.connect(func() -> void: _submit(s))
		_suggestions.add_child(b)
	_set_input_enabled(true)
	_input.grab_focus()


func _on_typed(count: int) -> void:
	_speech.visible_characters = count
	if count != _last_typed and count % 2 == 0:
		var ch := _speech.get_parsed_text().substr(count - 1, 1)
		if ch.strip_edges() != "":
			blip.emit()
	_last_typed = count


## Buttons with their own background and border, readable on the dark panel.
func _style_button(b: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color("2a2440"), "hover": Color("3d3560"), "pressed": Color("504680"), "disabled": Color("1c1828")}[state]
		sb.border_color = Color("ffe08a") if state == "hover" else Color("6a7fa0")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override(state, sb)


func _on_send() -> void:
	var t := _input.text.strip_edges()
	if t != "":
		_submit(t)


func _submit(text: String) -> void:
	_input.clear()
	submitted.emit(text)


func _set_input_enabled(on: bool) -> void:
	_input.editable = on
	_send.disabled = not on


func _clear_suggestions() -> void:
	for c in _suggestions.get_children():
		c.queue_free()
