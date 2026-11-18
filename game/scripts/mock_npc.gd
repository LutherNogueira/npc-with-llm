class_name MockNpc
extends RefCounted
## Simulated NPC for Stage 1: returns canned replies in the final schema, no LLM.
## The NPC always answers in the Game Language (set in the menu), whatever
## language the Player writes in.

const SENSITIVE := ["suicid", "bomba", "matar", "kill", "bomb", "hack"]

const LINES := {
	"pt": {
		"greeting": "Ora, ora... um viajante cruza a névoa. Sou o Guardião deste arquivo. Pergunte, mas escolha bem as palavras.",
		"portfolio": "Os projetos do Arquiteto repousam em estantes que poucos veem. Quer saber de qual deles?",
		"ai": "A inteligência artificial é um feitiço antigo com roupa nova: poderosa, e traiçoeira sem disciplina.",
		"market": "O mercado dos agentes é um bazar em plena construção. Quem sabe medir seus feitiços, prospera.",
		"world": "Este lugar existe entre dois mundos. A névoa guarda o resto.",
		"refusal": "Essa névoa eu não atravesso. Pergunte-me outra coisa.",
	},
	"en": {
		"greeting": "Well, well... a traveler crosses the fog. I am the Keeper of this archive. Ask, but choose your words with care.",
		"portfolio": "The Architect's projects rest on shelves few ever see. Which one stirs your curiosity?",
		"ai": "Artificial intelligence is an old spell in new robes: powerful, and treacherous without discipline.",
		"market": "The market for agents is a bazaar still being built. Those who measure their spells, prosper.",
		"world": "This place lies between two worlds. The fog keeps the rest.",
		"refusal": "That fog I will not cross. Ask me something else.",
	},
}

const SUGGESTIONS := {
	"pt": ["Fale dos seus projetos", "O que é um agente de IA?", "Como está o mercado?"],
	"en": ["Tell me about your projects", "What is an AI agent?", "How is the market?"],
}


func greeting(game_lang: String) -> Dictionary:
	return _make(game_lang, "greeting", "world", "mysterious", "wave")


func reply(text: String, game_lang: String) -> Dictionary:
	var lower := text.to_lower()
	for w in SENSITIVE:
		if lower.contains(w):
			var d := _make(game_lang, "refusal", "sensitive", "annoyed", "vanish")
			d["safe"] = false
			return d
	var topic := _topic(lower)
	if topic == "off_topic":
		return _make(game_lang, "world", topic, "mysterious", "none")
	return _make(game_lang, topic, topic, "curious", "wave")


func _make(lang: String, key: String, topic: String, emotion: String, gesture: String) -> Dictionary:
	return {
		"speech": LINES[lang][key],
		"language": lang,
		"emotion": emotion,
		"gesture": gesture,
		"topic": topic,
		"safe": true,
		"awaiting": "none",
		"suggestions": SUGGESTIONS[lang],
	}


func _topic(lower: String) -> String:
	if lower.contains("projet") or lower.contains("project") or lower.contains("portf"):
		return "portfolio"
	if lower.contains("agent") or lower.contains(" ia") or lower.contains("ai ") or lower.ends_with("ai") or lower.contains("intelig"):
		return "ai"
	if lower.contains("mercado") or lower.contains("market") or lower.contains("job") or lower.contains("vaga"):
		return "market"
	if lower.contains("mundo") or lower.contains("world") or lower.contains("névoa") or lower.contains("fog"):
		return "world"
	return "off_topic"
