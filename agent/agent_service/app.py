"""HTTP API used by the Godot game.

Run:  .venv/Scripts/python -m uvicorn agent_service.app:app --port 8000   (from agent/)
"""
from fastapi import FastAPI, HTTPException

from .config import settings
from .llm import OllamaChat
from .schema import ChatRequest, GreetRequest, NpcReply
from .service import KeeperService

llm = OllamaChat(settings.ollama_url, settings.model, settings.temperature, settings.request_timeout_s)
keeper = KeeperService(llm, settings.persona_dir, settings.log_path, settings.history_exchanges, settings.model)

app = FastAPI(title="Keeper Agent Service", version="0.2.0")


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "model": settings.model, "ollama": llm.is_up()}


@app.post("/greet", response_model=NpcReply)
def greet(req: GreetRequest) -> NpcReply:
    try:
        return keeper.greet(req.session_id, req.language)
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"model unavailable: {type(exc).__name__}") from exc


@app.post("/chat", response_model=NpcReply)
def chat(req: ChatRequest) -> NpcReply:
    try:
        return keeper.chat(req.session_id, req.message, req.language)
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"model unavailable: {type(exc).__name__}") from exc
