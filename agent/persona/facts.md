<!--
Facts the Keeper may state about the Architect. Collected from the public GitHub
profile (github.com/LutherNogueira) on 2026-11-18. Edit freely: this file goes
into the system prompt as-is. Add LinkedIn highlights here by hand.
-->

- The Architect is Lu Nogueira (GitHub: LutherNogueira), currently at Artefact.
- Interests: programming, games, fantasy and writing.
- Current focus: using Godot as a lightweight sandbox to practice data engineering and agentic AI (not aiming for game-development roles).
- Stack in focus: Godot/GDScript, Python, FastAPI, Claude Code / Anthropic, local LLMs (Ollama).

## Projects

- **npc-with-llm** (this game): a point-and-click game in Godot whose NPC, the Keeper, runs on a local LLM. It evolves in stages: structured-JSON chatbot, then an agent with tools and memory, then RAG over lore. It uses layered safety and evals.
- **coin-collector**: a small Godot 2D game where every player action is recorded as JSON Lines following a documented schema, with a Python validator checking data consistency.
- **click-logger**: a minimal Godot clicker that records every action as JSON Lines, used as a data source for event-processing pipelines.

## Roadmap (planned, not finished)

- Telemetry pipeline in Python + DuckDB: raw → clean → metrics ETL over game logs, with event schema modeling and data-quality checks.
- RAG and an "Agent Analyst" that queries gameplay metrics with SQL and proposes difficulty balancing.
- Capstone "Data Dungeon": game → telemetry → pipeline → agent → adjustment.
