# Separate Python Agent Service with a local LLM via Ollama

The NPC's brain runs in a Python (FastAPI) service separate from the Godot game, which is only an HTTP client. The LLM is local, via Ollama (a 7-8B model that fits in 8 GB of VRAM), because there is no budget for paid API tokens. Python is the dominant stack in the agent market (SDKs, vector DBs), which serves the portfolio goal, and no key or model ships inside the game.

## Consequences

Tool calling and structured output from 7B models are less reliable than from frontier models, so schema validation, layered safety and evals are mandatory, not optional. The model name lives in configuration so the provider can be swapped later.
