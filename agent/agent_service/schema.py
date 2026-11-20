"""The JSON contract shared with the game (mirrors game/scripts/npc_schema.gd)."""
from typing import Literal

from pydantic import BaseModel, Field

Language = Literal["pt", "en"]
Emotion = Literal["neutral", "mysterious", "amused", "annoyed", "curious"]
Gesture = Literal["none", "wave", "whisper", "laugh", "vanish"]
Topic = Literal["portfolio", "ai", "market", "world", "off_topic", "sensitive"]
Awaiting = Literal["none", "confirmation", "free_answer", "riddle"]


class NpcReply(BaseModel):
    """One reply from the Keeper."""

    speech: str = Field(min_length=1, max_length=700, description="What the Keeper says, 1-3 short sentences.")
    language: Language
    emotion: Emotion
    gesture: Gesture
    topic: Topic
    safe: bool
    awaiting: Awaiting
    suggestions: list[str] = Field(max_length=3, description="Up to 3 short follow-ups the Player might ask.")


def ollama_format() -> dict:
    """JSON schema handed to Ollama's `format` field to force structured output."""
    return NpcReply.model_json_schema()


class ChatRequest(BaseModel):
    session_id: str = Field(min_length=1, max_length=64)
    message: str = Field(min_length=1, max_length=1000)
    language: Language


class GreetRequest(BaseModel):
    session_id: str = Field(min_length=1, max_length=64)
    language: Language
