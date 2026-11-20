extends Node
## NPC client (autoload "NpcClient").
## Talks to the Agent Service over HTTP (Stage 2). If the service cannot be
## reached, it falls back to the local MockNpc so the game stays playable.
## `language` is the Game Language: changed only through the menu.

signal thinking_started
signal response_received(data: Dictionary)
signal language_changed(lang: String)
signal backend_changed(online: bool)

## Empty string = always use the mock.
var backend_url := "http://127.0.0.1:8000"
var language := "pt"
var session_id := ""
## True once a connection attempt failed; the rest of the session uses the mock.
var using_mock := false

var _mock := MockNpc.new()


func _ready() -> void:
	randomize()
	session_id = "godot-%d-%d" % [Time.get_unix_time_from_system(), randi() % 100000]


func set_language(lang: String) -> void:
	if lang == language:
		return
	language = lang
	language_changed.emit(lang)


func greet() -> void:
	_request("/greet", {"session_id": session_id, "language": language},
		func() -> Dictionary: return _mock.greeting(language))


func send_message(text: String) -> void:
	thinking_started.emit()
	_request("/chat", {"session_id": session_id, "message": text, "language": language},
		func() -> Dictionary: return _mock.reply(text, language))


func _request(path: String, body: Dictionary, fallback: Callable) -> void:
	if backend_url == "" or using_mock:
		_deliver(fallback.call(), true)
		return
	var http := HTTPRequest.new()
	http.timeout = 150.0  # a cold local model can take a while to load
	add_child(http)
	var err := http.request(backend_url + path, ["Content-Type: application/json"],
		HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		_fall_back("request error %d" % err, true)
		_deliver(fallback.call(), true)
		return
	var res: Array = await http.request_completed  # [result, code, headers, body]
	http.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		# Connection failures switch to the mock for good; a 503 only for this turn.
		_fall_back("result %d, HTTP %d" % [result, code], result == HTTPRequest.RESULT_CANT_CONNECT)
		_deliver(fallback.call(), true)
		return
	var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_fall_back("reply is not a JSON object", false)
		_deliver(fallback.call(), true)
		return
	_deliver(data, false)


func _fall_back(reason: String, sticky: bool) -> void:
	push_warning("Agent Service unavailable (%s); using the mock." % reason)
	if sticky and not using_mock:
		using_mock = true
		backend_changed.emit(false)


func _deliver(data: Dictionary, simulate_delay: bool) -> void:
	var err := NpcSchema.validate(data)
	if err != "":
		push_error("Reply outside the schema: %s" % err)
		return
	if simulate_delay:
		await get_tree().create_timer(randf_range(0.7, 1.4)).timeout
	response_received.emit(data)
