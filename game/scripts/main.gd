extends Node2D
## Single point-and-click room: clickable NPC, hotspots, Examine/Talk verbs.
## The hovered object's name and Examine lines appear ABOVE the object, so the
## dialogue box never hides them.

const ChatBoxScene := preload("res://scenes/chat_box.tscn")
const PuppetScript := preload("res://scripts/npc_puppet.gd")

const HIGHLIGHT := Color("ffe08a")
var verb := "talk"
var _puppet: Node2D
var _chat: PanelContainer
var _ui: CanvasLayer
var _verb_bar: HBoxContainer
var _lang_panel: Control
var _greeted := false
var _emotion := "mysterious"
var _settings: Control

var _spots := {}  # id -> {rect, node, outline, pt, en}
var _hover_tag: PanelContainer
var _say_tag: PanelContainer
var _say_serial := 0


func _ready() -> void:
	_build_room()
	_build_ui()
	NpcClient.thinking_started.connect(func() -> void:
		_chat.show_thinking()
		Audio.play_sfx("fog"))
	NpcClient.response_received.connect(_on_response)
	NpcClient.language_changed.connect(_relabel)
	_show_language_select()


func _tr2(pt: String, en: String) -> String:
	return pt if NpcClient.language == "pt" else en


# ------------------------------------------------------------------ room
func _build_room() -> void:
	# Backdrop: slate-blue wall, dark baseboard, warm brown floor.
	_rect(self, Rect2(0, 0, 1280, 400), Color("3e4c66"))
	_rect(self, Rect2(0, 400, 1280, 70), Color("2f3a4f"))
	_rect(self, Rect2(0, 470, 1280, 250), Color("5a4030"))
	_rect(self, Rect2(0, 470, 1280, 6), Color("3a281c"))

	var door := _object("door", Rect2(60, 90, 200, 380), "Porta", "Door")
	_rect(door, Rect2(60, 90, 200, 380), Color("2a1a10"))
	_rect(door, Rect2(75, 105, 170, 365), Color("8a5a32"))
	_rect(door, Rect2(95, 130, 130, 140), Color("7a4e2a"))
	_rect(door, Rect2(95, 300, 130, 140), Color("7a4e2a"))
	_rect(door, Rect2(212, 285, 16, 16), Color("e0b040"))

	var book := _object("book", Rect2(870, 215, 110, 255), "Livro", "Book")
	_rect(book, Rect2(895, 262, 60, 208), Color("8c8c96"))
	_rect(book, Rect2(885, 255, 80, 12), Color("a8a8b2"))
	_rect(book, Rect2(882, 228, 86, 28), Color("b0283a"))
	_rect(book, Rect2(886, 232, 78, 8), Color("f0e6c8"))

	var mirror := _object("mirror", Rect2(1010, 110, 140, 230), "Espelho", "Mirror")
	_rect(mirror, Rect2(1010, 110, 140, 230), Color("c9a227"))
	_rect(mirror, Rect2(1024, 124, 112, 202), Color("a9c8e8"))
	var shine := Polygon2D.new()
	shine.polygon = PackedVector2Array([Vector2(1040, 300), Vector2(1060, 300), Vector2(1110, 140), Vector2(1090, 140)])
	shine.color = Color(1, 1, 1, 0.35)
	mirror.add_child(shine)

	_puppet = Node2D.new()
	_puppet.set_script(PuppetScript)
	_puppet.position = Vector2(560, 250)
	add_child(_puppet)
	_register("npc", Rect2(500, 150, 130, 320), _puppet, "Guardião", "Keeper")


func _rect(parent: Node, r: Rect2, c: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.position = r.position
	cr.size = r.size
	cr.color = c
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)
	return cr


## Creates an object's visual node and registers its hotspot.
func _object(id: String, r: Rect2, name_pt: String, name_en: String) -> Node2D:
	var node := Node2D.new()
	node.name = id
	add_child(node)
	_register(id, r, node, name_pt, name_en)
	return node


func _register(id: String, r: Rect2, node: Node2D, name_pt: String, name_en: String) -> void:
	var outline := Line2D.new()
	outline.points = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	outline.width = 3.0
	outline.default_color = HIGHLIGHT
	outline.visible = false
	outline.z_index = 10
	add_child(outline)

	var b := Button.new()
	b.flat = true
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func() -> void: _on_hotspot(id))
	b.mouse_entered.connect(func() -> void: _hover(id, true))
	b.mouse_exited.connect(func() -> void: _hover(id, false))
	b.z_index = 11
	add_child(b)
	_spots[id] = {"rect": r, "node": node, "outline": outline, "pt": name_pt, "en": name_en}


func _hover(id: String, on: bool) -> void:
	if _lang_active():
		return
	var s: Dictionary = _spots[id]
	s["outline"].visible = on
	create_tween().tween_property(s["node"], "modulate", Color(1.35, 1.35, 1.35) if on else Color.WHITE, 0.12)
	if on:
		_say_tag.visible = false
		_show_tag(_hover_tag, _tr2(s["pt"], s["en"]), s["rect"])
	else:
		_hover_tag.visible = false


# ------------------------------------------------------- floating tags
func _make_tag(text_color: Color, border: Color) -> PanelContainer:
	var tag := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.09, 0.85)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	tag.add_theme_stylebox_override("panel", sb)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", text_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_child(label)
	tag.visible = false
	return tag


## Places the tag centered above the object, kept inside the screen.
func _show_tag(tag: PanelContainer, text: String, r: Rect2) -> void:
	var label: Label = tag.get_child(0)
	label.text = text
	var long := text.length() > 48
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long else TextServer.AUTOWRAP_OFF
	label.custom_minimum_size = Vector2(460 if long else 0, 0)
	tag.size = Vector2.ZERO
	tag.reset_size()
	var sz := tag.get_combined_minimum_size()
	var x := clampf(r.get_center().x - sz.x / 2.0, 8.0, 1280.0 - sz.x - 8.0)
	var y := maxf(r.position.y - sz.y - 10.0, 60.0)
	tag.position = Vector2(x, y)
	tag.visible = true


func _say(id: String, text: String, seconds := 3.5) -> void:
	_hover_tag.visible = false
	_show_tag(_say_tag, text, _spots[id]["rect"])
	_say_serial += 1
	var serial := _say_serial
	await get_tree().create_timer(seconds).timeout
	if serial == _say_serial:
		_say_tag.visible = false


# -------------------------------------------------------------------- UI
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_verb_bar = HBoxContainer.new()
	_verb_bar.position = Vector2(20, 16)
	_ui.add_child(_verb_bar)
	_hover_tag = _make_tag(HIGHLIGHT, HIGHLIGHT)
	_ui.add_child(_hover_tag)
	_say_tag = _make_tag(Color.WHITE, Color("a9c8e8"))
	_ui.add_child(_say_tag)

	_chat = ChatBoxScene.instantiate()
	_chat.visible = false
	_chat.submitted.connect(func(t: String) -> void: NpcClient.send_message(t))
	_chat.closed.connect(func() -> void:
		_chat.visible = false
		Audio.play_sfx("close"))
	_chat.typing_changed.connect(func(a: bool) -> void: _puppet.set_talking(a))
	_chat.blip.connect(func() -> void: Audio.play_blip(_emotion))
	_ui.add_child(_chat)

	var gear := Button.new()
	gear.text = "♪"
	gear.position = Vector2(1210, 16)
	gear.pressed.connect(func() -> void: _settings.toggle())
	_ui.add_child(gear)
	# Added last so it sits above everything; ESC toggles it (see settings_menu.gd).
	_settings = preload("res://scripts/settings_menu.gd").new()
	_ui.add_child(_settings)


func _show_language_select() -> void:
	_lang_panel = PanelContainer.new()
	_lang_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Idioma / Language"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for pair in [["pt", "Português"], ["en", "English"]]:
		var b := Button.new()
		b.text = pair[1]
		b.custom_minimum_size = Vector2(240, 48)
		b.pressed.connect(func() -> void: _choose_language(pair[0]))
		box.add_child(b)
	_lang_panel.add_child(box)
	_ui.add_child(_lang_panel)


func _lang_active() -> bool:
	return _lang_panel != null and is_instance_valid(_lang_panel) and not _lang_panel.is_queued_for_deletion()


func _choose_language(lang: String) -> void:
	NpcClient.set_language(lang)
	_lang_panel.queue_free()
	_chat.set_labels(lang)
	_settings.set_labels(lang)
	Audio.play_sfx("click")
	Audio.play_ambient("ambient_drone")
	Audio.play_music("theme")
	for c in _verb_bar.get_children():
		c.queue_free()
	for v in [["examine", "Examinar", "Examine"], ["talk", "Falar", "Talk to"]]:
		var b := Button.new()
		b.text = _tr2(v[1], v[2])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		_style_verb(b)
		b.button_pressed = v[0] == verb
		b.pressed.connect(func() -> void: _set_verb(v[0]))
		b.add_to_group("verb_buttons")
		b.set_meta("verb", v[0])
		b.set_meta("pt", v[1])
		b.set_meta("en", v[2])
		_verb_bar.add_child(b)
	_say("npc", _tr2("Clique no Guardião para falar.", "Click the Keeper to talk."), 5.0)


## Game Language changed in the menu: relabel the whole UI.
func _relabel(lang: String) -> void:
	_chat.set_labels(lang)
	for b in get_tree().get_nodes_in_group("verb_buttons"):
		b.text = b.get_meta(lang)


## Active verb in gold, inactive one muted, so it is clear which one applies.
func _style_verb(b: Button) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var active: bool = state.contains("pressed")
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("6b5216") if active else Color("1c1828")
		sb.border_color = HIGHLIGHT if active or state == "hover" else Color("6a7fa0")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_pressed_color", HIGHLIGHT)
	b.add_theme_color_override("font_hover_pressed_color", HIGHLIGHT)


func _set_verb(v: String) -> void:
	Audio.play_sfx("verb")
	verb = v
	for b in get_tree().get_nodes_in_group("verb_buttons"):
		b.button_pressed = b.get_meta("verb") == v


func _on_hotspot(id: String) -> void:
	if _lang_active():
		return
	Audio.play_sfx("click")
	if id == "npc" and verb == "talk":
		_say_tag.visible = false
		if not _chat.visible:
			Audio.play_sfx("open")
		_chat.visible = true
		if not _greeted:
			_greeted = true
			_chat.show_thinking()
			NpcClient.greet()
		return
	if verb == "talk":
		_say(id, _tr2("Não adianta falar com isso.", "No use talking to that."))
		return
	var texts := {
		"npc": ["Um vulto encapuzado. Observa de volta.", "A hooded figure. It watches back."],
		"door": ["Trancada. Algo me diz que o Guardião tem a chave.", "Locked. The Keeper surely has the key."],
		"book": ["Páginas em branco... por enquanto.", "Blank pages... for now."],
		"mirror": ["Meu reflexo parece sussurrar algo.", "My reflection seems to whisper something."],
	}
	_say(id, _tr2(texts[id][0], texts[id][1]))


func _on_response(data: Dictionary) -> void:
	_emotion = data["emotion"]
	if not data["safe"]:
		Audio.play_sfx("refuse")
	elif data["gesture"] != "none":
		Audio.play_sfx(data["gesture"])  # sfx files share the gesture names
	_puppet.apply_response(data)
	_chat.show_response(data)
