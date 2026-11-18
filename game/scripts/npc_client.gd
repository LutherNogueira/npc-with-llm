extends Node
## NPC client (autoload "NpcClient").
## Stage 1 uses MockNpc. In Stage 2 the mock is replaced by HTTP requests to the
## Agent Service (backend_url), keeping the same JSON contract.
## `language` is the Game Language: changed only through the menu, never by what
## the Player types.

signal thinking_started
signal response_received(data: Dictionary)
signal language_changed(lang: String)

var backend_url := ""  # empty = use the local mock
var language := "pt"

var _mock := MockNpc.new()


func set_language(lang: String) -> void:
	if lang == language:
		return
	language = lang
	language_changed.emit(lang)


func greet() -> void:
	_deliver(_mock.greeting(language))


func send_message(text: String) -> void:
	thinking_started.emit()
	_deliver(_mock.reply(text, language))


func _deliver(data: Dictionary) -> void:
	var err := NpcSchema.validate(data)
	if err != "":
		push_error("Reply outside the schema: %s" % err)
		return
	await get_tree().create_timer(randf_range(0.7, 1.4)).timeout
	response_received.emit(data)
