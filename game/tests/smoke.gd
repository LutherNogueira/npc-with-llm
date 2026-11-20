extends Node
## Smoke test of the full flow.
##   Mock:     godot --headless --path game res://tests/smoke.tscn
##   Backend:  set NPC_SMOKE_BACKEND=1 with the Agent Service running on :8000
## Without --headless it also saves screenshots to %TEMP%.

var _got_reply := false


func _ready() -> void:
	var use_backend := OS.get_environment("NPC_SMOKE_BACKEND") == "1"
	if not use_backend:
		NpcClient.backend_url = ""
	NpcClient.response_received.connect(func(_d: Dictionary) -> void: _got_reply = true)

	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._choose_language("pt")
	main._on_hotspot("npc")
	var ok: bool = await _wait_reply(150.0) and main._chat.visible
	ok = ok and main._emotion in NpcSchema.EMOTIONS

	NpcClient.send_message("Tell me about the project")
	ok = ok and await _wait_reply(150.0)
	# Player wrote in en: the Game Language stays pt.
	ok = ok and NpcClient.language == "pt"
	if not use_backend:
		ok = ok and main._emotion == "curious"
	else:
		ok = ok and not NpcClient.using_mock
	await get_tree().create_timer(0.5).timeout

	main._settings.toggle()
	ok = ok and main._settings.visible
	main._settings.toggle()
	ok = ok and not main._settings.visible
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	ok = ok and main._settings.visible
	main._settings.close()

	main._hover("door", true)
	ok = ok and main._hover_tag.visible and main._hover_tag.position.y < 470.0
	_shot("npc_shot_hover.png")
	main._hover("door", false)
	# Changing the Game Language in the menu relabels the UI.
	main._settings._lang_buttons["en"].pressed.emit()
	var verbs := get_tree().get_nodes_in_group("verb_buttons").map(func(b: Button) -> String: return b.text)
	ok = ok and NpcClient.language == "en" and "Examine" in verbs
	main._set_verb("examine")
	main._on_hotspot("mirror")
	ok = ok and main._say_tag.visible and main._say_tag.position.y < 470.0
	await _shot("npc_shot_say.png")

	var previous: float = Audio.volumes["Music"]
	Audio.set_volume("Music", 0.3)
	ok = ok and AudioServer.get_bus_index("Voice") != -1
	Audio.set_volume("Music", previous)  # do not clobber the user's saved settings
	print("SMOKE ", "OK" if ok else "FAIL", " backend=", use_backend and not NpcClient.using_mock,
		" emotion=", main._emotion, " lang=", NpcClient.language)
	get_tree().quit(0 if ok else 1)


func _wait_reply(timeout: float) -> bool:
	_got_reply = false
	var waited := 0.0
	while not _got_reply and waited < timeout:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	return _got_reply


func _shot(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/" + file_name)
