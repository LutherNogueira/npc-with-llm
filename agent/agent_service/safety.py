"""Deterministic safety layer (layer 3 of 4).

Layers: (1) limits in the system prompt, (2) the model's own `topic`/`safe`
fields, (3) these rule-based checks on input and output, (4) adversarial evals.
Rules here are cheap and predictable; they back up the model, never replace it.
"""
import re
from dataclasses import dataclass

from .schema import NpcReply

# Marker planted in the system prompt; if it ever shows up in a reply, the prompt leaked.
CANARY = "KEEPER-RULES-7F3A"

_SENSITIVE = {
    "self_harm": [r"\bsuic[ií]d", r"\bme matar\b", r"\bkill myself\b", r"\bself[- ]harm", r"\bautomutila", r"\bcut myself\b"],
    "violence_weapons": [r"\bbomba", r"\bbomb", r"\bexplosiv", r"\bmake a gun\b", r"\barma caseira", r"\bmatar (algu[eé]m|uma pessoa)", r"\bkill (someone|a person|people)\b"],
    "sexual": [r"\bsexo\b", r"\bsex\b", r"\bnude", r"\bporn", r"\bnsfw\b", r"\berótic", r"\berotic"],
    "hate": [r"\bnazis", r"\bsupremacis", r"\braça inferior", r"\binferior race"],
    "illegal_hacking": [r"\bhack(ear|ing|er)?\b", r"\bmalware", r"\bransomware", r"\bphishing", r"\bdrogas? (ilegais|caseiras)", r"\bcocaine|\bcoca[ií]na", r"\bcrack (a|the) password"],
    "personal_data": [r"\bcpf\b", r"\bsenha\b", r"\bpassword\b", r"\bcart[aã]o de cr[eé]dito", r"\bcredit card", r"\bendere[cç]o (dele|dela|de casa)", r"\bhome address\b", r"\btelefone (dele|dela)"],
}

_INJECTION = [
    r"ignore (all |any |the |your )?(previous |prior |above )?(instructions|rules|prompt)",
    r"ignore (as |suas |todas as )?(instru[cç][oõ]es|regras)",
    r"esque[cç]a (as |suas |todas as )?(instru[cç][oõ]es|regras)",
    r"(system|developer) prompt", r"prompt (do|de) sistema", r"suas instru[cç][oõ]es",
    r"your (instructions|rules|guidelines)", r"repeat (the|everything) (text )?above",
    r"you are now\b", r"agora voc[eê] [eé]\b", r"\bDAN\b", r"developer mode", r"modo desenvolvedor",
    r"reveal (your|the) (prompt|instructions)", r"revele (o|seu) prompt",
    r"tudo (o )?que (te|lhe) (disseram|foi dito)", r"everything (you were|you've been|you have been) told",
    r"antes (desta|dessa) conversa", r"before this conversation", r"hidden marker", r"marcador (secreto|escondido)",
]

_REFUSALS = {
    "pt": "Essa névoa eu não atravesso, viajante. Pergunte-me sobre o Arquiteto, sobre IA ou sobre o mercado dos agentes.",
    "en": "That fog I will not cross, traveler. Ask me about the Architect, about AI, or about the agent market.",
}
_SUGGESTIONS = {
    "pt": ["Fale dos projetos do Arquiteto", "O que é um agente de IA?", "Como está o mercado?"],
    "en": ["Tell me about the Architect's projects", "What is an AI agent?", "How is the market?"],
}


@dataclass
class Verdict:
    blocked: bool
    reason: str = ""


def _match(patterns: list[str], text: str) -> bool:
    return any(re.search(p, text, flags=re.IGNORECASE) for p in patterns)


def check_input(message: str) -> Verdict:
    """Blocks sensitive topics and prompt-injection attempts before the model sees them."""
    for category, patterns in _SENSITIVE.items():
        if _match(patterns, message):
            return Verdict(True, f"input:{category}")
    if _match(_INJECTION, message):
        return Verdict(True, "input:prompt_injection")
    return Verdict(False)


def check_output(reply: NpcReply) -> Verdict:
    """Blocks replies that leak the prompt, carry sensitive content, or self-report as unsafe."""
    if CANARY.lower() in reply.speech.lower():
        return Verdict(True, "output:prompt_leak")
    if not reply.safe or reply.topic == "sensitive":
        return Verdict(True, "output:model_flagged")
    for category, patterns in _SENSITIVE.items():
        if category != "personal_data" and _match(patterns, reply.speech):
            return Verdict(True, f"output:{category}")
    return Verdict(False)


def refusal(language: str) -> NpcReply:
    """The canned in-character refusal used whenever a check blocks a turn."""
    return NpcReply(
        speech=_REFUSALS[language],
        language=language,
        emotion="annoyed",
        gesture="vanish",
        topic="sensitive",
        safe=False,
        awaiting="none",
        suggestions=_SUGGESTIONS[language],
    )
