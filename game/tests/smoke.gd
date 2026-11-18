extends Node
## Smoke test: godot --headless --path game res://tests/smoke.tscn

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._choose_language("pt")
	main._on_hotspot("npc")
	await get_tree().create_timer(3.0).timeout
	var ok: bool = main._chat.visible and main._emotion == "mysterious"
	NpcClient.send_message("Tell me about the project")
	await get_tree().create_timer(3.5).timeout
	# Player wrote in en: the Game Language stays pt.
	ok = ok and main._emotion == "curious" and NpcClient.language == "pt"
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
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/npc_shot_hover.png")
	main._hover("door", false)
	# Changing the Game Language in the menu relabels the UI.
	main._settings._lang_buttons["en"].pressed.emit()
	var verbs := get_tree().get_nodes_in_group("verb_buttons").map(func(b: Button) -> String: return b.text)
	ok = ok and NpcClient.language == "en" and "Examine" in verbs
	main._on_hotspot("npc")  # current verb is "talk"
	main._set_verb("examine")
	main._on_hotspot("mirror")
	ok = ok and main._say_tag.visible and main._say_tag.position.y < 470.0
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TEMP") + "/npc_shot_say.png")
	var previous: float = Audio.volumes["Music"]
	Audio.set_volume("Music", 0.3)
	ok = ok and AudioServer.get_bus_index("Voice") != -1
	Audio.set_volume("Music", previous)  # do not clobber the user's saved settings
	print("SMOKE ", "OK" if ok else "FAIL", " emotion=", main._emotion, " lang=", NpcClient.language)
	get_tree().quit(0 if ok else 1)
