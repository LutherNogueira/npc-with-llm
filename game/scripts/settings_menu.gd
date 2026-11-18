extends Control
## Settings menu (ESC or the ♪ button). Sections: Language and Audio.
## New sections are added with add_section(title_pt, title_en, control).

signal opened
signal closed

const AudioPanel := preload("res://scripts/audio_panel.gd")

var _title: Label
var _back: Button
var _sections: VBoxContainer
var _section_titles: Array = []  # [[Label, pt, en], ...]
var _audio: VBoxContainer
var _lang_buttons := {}  # lang -> Button


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_sections = VBoxContainer.new()
	_sections.add_theme_constant_override("separation", 14)
	box.add_child(_sections)

	add_section("Idioma", "Language", _build_language_row())
	_audio = AudioPanel.new()
	add_section("Áudio", "Audio", _audio)

	_back = Button.new()
	_back.pressed.connect(close)
	box.add_child(_back)
	NpcClient.language_changed.connect(set_labels)
	set_labels(NpcClient.language)


## The Game Language: the only thing that decides which language the NPC speaks.
func _build_language_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for pair in [["pt", "Português"], ["en", "English"]]:
		var b := Button.new()
		b.text = pair[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			Audio.play_sfx("click")
			NpcClient.set_language(pair[0])
			_sync_language_buttons())
		_lang_buttons[pair[0]] = b
		row.add_child(b)
	return row


func _sync_language_buttons() -> void:
	for lang in _lang_buttons:
		_lang_buttons[lang].button_pressed = lang == NpcClient.language


func add_section(title_pt: String, title_en: String, content: Control) -> void:
	var t := Label.new()
	t.add_theme_font_size_override("font_size", 20)
	_sections.add_child(t)
	_sections.add_child(content)
	_section_titles.append([t, title_pt, title_en])
	t.text = title_pt if NpcClient.language == "pt" else title_en


func set_labels(lang: String) -> void:
	_title.text = "Configurações" if lang == "pt" else "Settings"
	_back.text = "Voltar" if lang == "pt" else "Back"
	for s in _section_titles:
		s[0].text = s[1] if lang == "pt" else s[2]
	_audio.set_labels(lang)
	_sync_language_buttons()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_sync_language_buttons()
	visible = true
	Audio.play_sfx("open")
	opened.emit()


func close() -> void:
	visible = false
	Audio.play_sfx("close")
	closed.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()
