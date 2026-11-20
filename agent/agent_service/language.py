"""Cheap pt/en detector used to catch replies written in the wrong language.

The model sometimes writes English while still setting `language: "pt"`, so the
field alone cannot be trusted. Counting common function words is enough here.
"""
import re

_PT = {"o", "os", "as", "de", "do", "da", "dos", "das", "que", "não", "é", "um", "uma", "você", "seu", "sua",
       "para", "com", "em", "no", "na", "mas", "isso", "aqui", "ele", "ela", "são", "está", "como", "mais"}
_EN = {"the", "of", "is", "you", "your", "and", "to", "in", "it", "that", "not", "but", "this", "here",
       "with", "are", "he", "she", "has", "have", "was", "for", "what", "which", "as", "more"}


def detect(text: str) -> str | None:
    """Returns "pt", "en", or None when the text is too short or ambiguous to tell."""
    words = re.findall(r"[a-zà-ú]+", text.lower())
    pt = sum(w in _PT for w in words)
    en = sum(w in _EN for w in words)
    if pt + en < 3 or pt == en:
        return None
    return "pt" if pt > en else "en"
