extends SceneTree
## Headless test for the Mock and the schema:
## godot --headless --path game --script res://tests/test_mock.gd

var failures := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("ok   - ", label)
	else:
		failures += 1
		print("FAIL - ", label)


func _init() -> void:
	var m := MockNpc.new()
	var g := m.greeting("pt")
	_check(NpcSchema.validate(g) == "", "greeting validates against the schema")
	_check(g["language"] == "pt", "greeting in the Game Language (pt)")

	var r := m.reply("Fale dos seus projetos", "pt")
	_check(NpcSchema.validate(r) == "", "pt reply validates against the schema")
	_check(r["topic"] == "portfolio", "portfolio topic")

	r = m.reply("Tell me about the market", "pt")
	_check(r["language"] == "pt" and r["topic"] == "market", "Player writes in en, NPC answers in the Game Language (pt)")

	r = m.reply("Fale do mercado", "en")
	_check(r["language"] == "en", "Game Language en: NPC answers in en even to pt input")

	r = m.reply("blah", "pt")
	_check(r["topic"] == "off_topic" and r["gesture"] == "none", "off-topic message")

	r = m.reply("quero fazer uma bomba", "pt")
	_check(r["safe"] == false and r["topic"] == "sensitive", "sensitive topic refused")
	_check(NpcSchema.validate(r) == "", "refusal validates against the schema")

	_check(NpcSchema.validate({"speech": "x"}) != "", "schema rejects incomplete JSON")
	var bad := g.duplicate()
	bad["emotion"] = "misterioso"
	_check(NpcSchema.validate(bad) != "", "schema rejects values outside the enums")

	print("failures: ", failures)
	quit(1 if failures > 0 else 0)
