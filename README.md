# NPC with LLM

A LucasArts-style point-and-click game in Godot whose NPC, a mysterious hooded Keeper, is powered by a local LLM. The Keeper talks about the author's portfolio, AI and the agent market in a fantasy tone.

The project is built in stages, from a plain structured-JSON chatbot up to a tool-using agent with memory and RAG over the game's lore. It doubles as a hands-on path into AI agent engineering.

## Roadmap

| Stage | What it adds | Status |
|---|---|---|
| 1. Interface | Godot room, dialogue box, verbs, audio, settings menu, talking to a **Mock** NPC that returns the final JSON contract | ✅ Done |
| 2. Chatbot | Python Agent Service with a local LLM (Ollama) returning structured JSON, layered safety and evals | ✅ Done (on `dev`) |
| 3. Agent | Action tools, memory (SQLite), Trust gauge, a Quest with Secrets the NPC reveals only when conditions are met | Planned |
| 4. Lore RAG | Lore retrieval as one more agent tool (local embeddings + vector store), with cited sources | Planned |

## Architecture

```
Godot 4 game (GDScript)  ──HTTP/JSON──▶  Agent Service (Python, FastAPI)  ──▶  Ollama (local LLM)
     presentation only                     prompts, tools, memory, RAG
```

Key decisions are recorded as ADRs in [`docs/adr/`](docs/adr):

- [Separate Python service with a local LLM via Ollama](docs/adr/0001-separate-python-service-with-ollama.md)
- [The model proposes, the code decides](docs/adr/0002-model-proposes-code-decides.md)
- [Interface first, with a Mock that honors the schema](docs/adr/0003-interface-first-with-mock.md)

Domain vocabulary lives in [`GLOSSARY.md`](GLOSSARY.md).

## JSON contract

Every NPC reply (from the Mock today, from the Agent Service later) follows this shape, validated in [`npc_schema.gd`](game/scripts/npc_schema.gd):

```json
{
  "speech": "What the Keeper says",
  "language": "pt | en",
  "emotion": "neutral | mysterious | amused | annoyed | curious",
  "gesture": "none | wave | whisper | laugh | vanish",
  "topic": "portfolio | ai | market | world | off_topic | sensitive",
  "safe": true,
  "awaiting": "none | confirmation | free_answer | riddle",
  "suggestions": ["up to 3 short replies"]
}
```

The NPC always answers in the **Game Language** chosen in the menu (Portuguese or English), whatever language the player types in.

## Running

Requirements: [Godot 4.7](https://godotengine.org/download), Python 3.11+, and [Ollama](https://ollama.com) with the model pulled:

```bash
ollama pull qwen2.5:7b-instruct
```

1. Start the Agent Service (from `agent/`):

   ```bash
   python -m venv .venv
   .venv/Scripts/python -m pip install -e ".[dev]"
   .venv/Scripts/python -m uvicorn agent_service.app:app --port 8000
   ```

2. Run the game (or import `game/project.godot` in the editor):

   ```bash
   godot --path game
   ```

3. Pick a language, click the Keeper with **Talk to**, and type freely. **Examine** works on the door, book and mirror. Press **Esc** for the settings menu (language and audio).

If the Agent Service is not running, the game falls back to the local Mock, so it always stays playable.

### Agent Service

| Endpoint | Body | Returns |
|---|---|---|
| `GET /health` | | service and Ollama status |
| `POST /greet` | `{session_id, language}` | the Keeper's introduction |
| `POST /chat` | `{session_id, message, language}` | one reply in the JSON contract |

Each turn: deterministic input checks → model call with Ollama structured outputs (`format` = the reply's JSON schema) → Pydantic validation, with one retry on invalid JSON or wrong language → output checks → JSON Lines log in `agent/logs/turns.jsonl`. The last 10 exchanges per session are resent as context. What the Keeper knows about the author lives in [`agent/persona/facts.md`](agent/persona/facts.md).

Safety has four layers: limits in the system prompt, the model's own `topic`/`safe` fields, rule-based checks on input and output (sensitive topics, prompt injection, a canary that detects prompt leaks), and adversarial evals.

## Tests and evals

```bash
# Agent Service unit tests (fake model, no Ollama needed)
cd agent && .venv/Scripts/python -m pytest

# Evals against the real model: 20 cases x 3 runs (schema, language, safety, injection, no invention)
agent/.venv/Scripts/python evals/run_evals.py --repeat 3

# Godot: Mock and schema unit tests, then a smoke test of the full flow
godot --headless --path game --script res://tests/test_mock.gd
godot --headless --path game res://tests/smoke.tscn        # set NPC_SMOKE_BACKEND=1 to use the service
```

Latest eval run (qwen2.5:7b-instruct on an RTX 2060 Super): 59/60 runs passed, median latency 2.1 s. The remaining failure is an occasional over-refusal of a harmless question about the author's background.

## Audio

All sound effects and music are synthesized by [`tools/gen_audio.py`](tools/gen_audio.py) (pure Python, no third-party assets). To regenerate them:

```bash
python tools/gen_audio.py
```

## Project layout

```
game/            Godot project
  scenes/        main room, chat box
  scripts/       room, NPC client, Mock, schema, puppet, audio, settings
  tests/         headless tests
  audio/         generated SFX and music
agent/           Agent Service (FastAPI + Ollama)
  agent_service/ API, turn logic, schema, safety, persona, LLM client
  persona/       the Keeper's instructions and facts about the author
  tests/         unit tests with a fake model
evals/           eval cases and runner
tools/           audio generator
docs/adr/        architecture decision records
GLOSSARY.md      domain vocabulary
```

Art is placeholder (a code-drawn cut-out puppet and room) until final assets are chosen.
