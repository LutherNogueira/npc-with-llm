# NPC with LLM

A LucasArts-style point-and-click game in Godot whose NPC, a mysterious hooded Keeper, is powered by a local LLM. The Keeper talks about the author's portfolio, AI and the agent market in a fantasy tone.

The project is built in stages, from a plain structured-JSON chatbot up to a tool-using agent with memory and RAG over the game's lore. It doubles as a hands-on path into AI agent engineering.

## Roadmap

| Stage | What it adds | Status |
|---|---|---|
| 1. Interface | Godot room, dialogue box, verbs, audio, settings menu, talking to a **Mock** NPC that returns the final JSON contract | ✅ Done |
| 2. Chatbot | Python Agent Service with a local LLM (Ollama) returning structured JSON, layered safety and evals | ⏳ Next |
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

Requirements: [Godot 4.7](https://godotengine.org/download) (standard build, GDScript).

1. Open Godot and import `game/project.godot`, or run it from the command line:

   ```bash
   godot --path game
   ```

2. Pick a language, click the Keeper with **Talk to**, and type freely. **Examine** works on the door, book and mirror. Press **Esc** for the settings menu (language and audio).

## Tests

```bash
# Mock and schema unit tests (headless)
godot --headless --path game --script res://tests/test_mock.gd

# Smoke test of the full flow (run without --headless to also save screenshots)
godot --headless --path game res://tests/smoke.tscn
```

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
tools/           audio generator
docs/adr/        architecture decision records
GLOSSARY.md      domain vocabulary
```

Art is placeholder (a code-drawn cut-out puppet and room) until final assets are chosen.
