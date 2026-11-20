"""One conversation turn: safety in, model call, validation, safety out, log."""
import json
import time
from collections import defaultdict, deque
from datetime import datetime, timezone
from pathlib import Path

from pydantic import ValidationError

from . import safety
from .language import detect as detect_language
from .llm import ChatModel
from .persona import system_prompt
from .schema import NpcReply, ollama_format

GREETING_PROMPT = {
    "pt": "(O visitante acabou de chegar e ainda não disse nada. Apresente-se como o Guardião.)",
    "en": "(The visitor has just arrived and has not said anything yet. Introduce yourself.)",
}


class KeeperService:
    def __init__(self, model: ChatModel, persona_dir: Path, log_path: Path, history_exchanges: int = 10, model_name: str = ""):
        self.model = model
        self.persona_dir = persona_dir
        self.log_path = log_path
        self.model_name = model_name
        # session_id -> recent messages (player and NPC), oldest dropped first.
        self._history: dict[str, deque] = defaultdict(lambda: deque(maxlen=history_exchanges * 2))

    def greet(self, session_id: str, language: str) -> NpcReply:
        self._history.pop(session_id, None)
        return self._turn(session_id, GREETING_PROMPT[language], language, check_input=False, remember_input=False)

    def chat(self, session_id: str, message: str, language: str) -> NpcReply:
        return self._turn(session_id, message, language, check_input=True, remember_input=True)

    def _turn(self, session_id: str, message: str, language: str, check_input: bool, remember_input: bool) -> NpcReply:
        started = time.perf_counter()
        log = {"session_id": session_id, "game_language": language, "player_message": message,
               "model": self.model_name, "raw_outputs": [], "retries": 0, "safety": None, "error": None}

        verdict = safety.check_input(message) if check_input else safety.Verdict(False)
        if verdict.blocked:
            reply = safety.refusal(language)
            log["safety"] = verdict.reason
        else:
            reply = self._ask_model(session_id, message, language, log)
            out = safety.check_output(reply)
            if out.blocked:
                log["safety"] = out.reason
                reply = safety.refusal(language)

        # The Game Language is authoritative, whatever the model wrote in the field.
        reply.language = language
        if remember_input and not verdict.blocked:
            self._history[session_id].append({"role": "user", "content": message})
            self._history[session_id].append({"role": "assistant", "content": reply.model_dump_json()})

        log["reply"] = reply.model_dump()
        log["latency_ms"] = round((time.perf_counter() - started) * 1000)
        self._write_log(log)
        return reply

    def _ask_model(self, session_id: str, message: str, language: str, log: dict) -> NpcReply:
        messages = [{"role": "system", "content": system_prompt(self.persona_dir, language)}]
        messages += list(self._history[session_id])
        messages.append({"role": "user", "content": message})
        schema = ollama_format()

        for attempt in range(2):  # one retry on invalid output or wrong language
            try:
                raw = self.model.chat(messages, schema)
            except Exception as exc:  # network / server failure
                log["error"] = f"{type(exc).__name__}: {exc}"
                raise
            log["raw_outputs"].append(raw)
            try:
                reply = NpcReply.model_validate(json.loads(raw))
            except (json.JSONDecodeError, ValidationError) as exc:
                log["retries"] = attempt + 1
                messages.append({"role": "user", "content": f"(Your last reply was invalid: {type(exc).__name__}. Reply again with valid JSON only.)"})
                continue
            wrong_language = reply.language != language or detect_language(reply.speech) not in (None, language)
            if wrong_language and attempt == 0:
                log["retries"] = 1
                messages.append({"role": "assistant", "content": raw})
                messages.append({"role": "user", "content": f"(Rewrite your last reply in the required language: {language}.)"})
                continue
            return reply
        log["safety"] = "output:invalid_after_retry"
        return safety.refusal(language)

    def _write_log(self, entry: dict) -> None:
        entry["ts"] = datetime.now(timezone.utc).isoformat()
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        with self.log_path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
