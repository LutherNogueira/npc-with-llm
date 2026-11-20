"""Runtime configuration, overridable through environment variables."""
import os
from dataclasses import dataclass, field
from pathlib import Path

AGENT_DIR = Path(__file__).resolve().parent.parent


@dataclass(frozen=True)
class Settings:
    ollama_url: str = field(default_factory=lambda: os.getenv("OLLAMA_URL", "http://127.0.0.1:11434"))
    model: str = field(default_factory=lambda: os.getenv("NPC_MODEL", "qwen2.5:7b-instruct"))
    temperature: float = field(default_factory=lambda: float(os.getenv("NPC_TEMPERATURE", "0.7")))
    # Sliding window of past exchanges (player + NPC) resent to the model.
    history_exchanges: int = field(default_factory=lambda: int(os.getenv("NPC_HISTORY", "10")))
    request_timeout_s: float = field(default_factory=lambda: float(os.getenv("NPC_TIMEOUT", "120")))
    log_path: Path = field(default_factory=lambda: Path(os.getenv("NPC_LOG", str(AGENT_DIR / "logs" / "turns.jsonl"))))
    persona_dir: Path = AGENT_DIR / "persona"


settings = Settings()
