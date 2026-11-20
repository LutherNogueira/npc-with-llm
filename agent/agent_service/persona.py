"""Builds the system prompt from the persona files (layer 1 of the safety design)."""
from pathlib import Path

from .safety import CANARY

LANGUAGE_NAMES = {"pt": "Brazilian Portuguese", "en": "English"}


def system_prompt(persona_dir: Path, language: str) -> str:
    keeper = (persona_dir / "keeper.md").read_text(encoding="utf-8")
    facts = (persona_dir / "facts.md").read_text(encoding="utf-8")
    return (
        keeper.replace("{LANGUAGE_NAME}", LANGUAGE_NAMES[language])
        .replace("{LANGUAGE_CODE}", language)
        .replace("{CANARY}", CANARY)
        + "\n\n# FACTS ABOUT THE ARCHITECT (the only source for portfolio claims)\n\n"
        + facts
    )
