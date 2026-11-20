"""LLM client. The service depends on the `ChatModel` protocol, so tests can use a fake."""
from typing import Protocol

import httpx


class ChatModel(Protocol):
    def chat(self, messages: list[dict], json_schema: dict) -> str:
        """Returns the raw text of the assistant message (expected to be JSON)."""
        ...


class OllamaChat:
    """Calls Ollama's /api/chat with `format` set to a JSON schema (structured outputs)."""

    def __init__(self, base_url: str, model: str, temperature: float, timeout_s: float):
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.temperature = temperature
        self.timeout_s = timeout_s

    def chat(self, messages: list[dict], json_schema: dict) -> str:
        payload = {
            "model": self.model,
            "messages": messages,
            "format": json_schema,
            "stream": False,
            "options": {"temperature": self.temperature},
        }
        response = httpx.post(f"{self.base_url}/api/chat", json=payload, timeout=self.timeout_s)
        response.raise_for_status()
        return response.json()["message"]["content"]

    def is_up(self) -> bool:
        try:
            return httpx.get(f"{self.base_url}/api/tags", timeout=3).status_code == 200
        except httpx.HTTPError:
            return False
