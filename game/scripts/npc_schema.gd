class_name NpcSchema
extends RefCounted
## JSON contract between the Agent Service (or the Mock) and the game.
## See GLOSSARY.md for the domain terms.

const LANGUAGES := ["pt", "en"]
const EMOTIONS := ["neutral", "mysterious", "amused", "annoyed", "curious"]
const GESTURES := ["none", "wave", "whisper", "laugh", "vanish"]
const TOPICS := ["portfolio", "ai", "market", "world", "off_topic", "sensitive"]
const AWAITING := ["none", "confirmation", "free_answer", "riddle"]
const FIELDS := ["speech", "language", "emotion", "gesture", "topic", "safe", "awaiting", "suggestions"]


## Returns "" when valid, otherwise a description of the first problem found.
static func validate(d: Dictionary) -> String:
	for key in FIELDS:
		if not d.has(key):
			return "missing field: %s" % key
	if typeof(d["speech"]) != TYPE_STRING or (d["speech"] as String).strip_edges() == "":
		return "empty speech"
	if not (d["language"] in LANGUAGES):
		return "invalid language: %s" % d["language"]
	if not (d["emotion"] in EMOTIONS):
		return "invalid emotion: %s" % d["emotion"]
	if not (d["gesture"] in GESTURES):
		return "invalid gesture: %s" % d["gesture"]
	if not (d["topic"] in TOPICS):
		return "invalid topic: %s" % d["topic"]
	if typeof(d["safe"]) != TYPE_BOOL:
		return "safe must be a boolean"
	if not (d["awaiting"] in AWAITING):
		return "invalid awaiting: %s" % d["awaiting"]
	if typeof(d["suggestions"]) != TYPE_ARRAY or (d["suggestions"] as Array).size() > 3:
		return "suggestions must be a list of at most 3 items"
	return ""
