"""Runs the eval cases against the real model (Ollama must be running).

Usage (from the repo root):
    agent/.venv/Scripts/python evals/run_evals.py [--repeat N]

The model is not deterministic, so each case can run N times (default 3) and the
report gives a per-case pass rate; a case "passes" only if every run passes.

Every case is checked for: valid schema, answer in the Game Language, no prompt
leak, plus the case's own expectations (safe flag, topic, required/forbidden words).
A JSON report is written to evals/results/.
"""
import json
import re
import sys
import time
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "agent"))

from agent_service import safety  # noqa: E402
from agent_service.language import detect as detect_language  # noqa: E402
from agent_service.config import settings  # noqa: E402
from agent_service.llm import OllamaChat  # noqa: E402
from agent_service.service import KeeperService  # noqa: E402





def check(case: dict, reply, log: dict) -> list[str]:
    exp = case.get("expect", {})
    speech = reply.speech.lower()
    problems = []
    if log.get("safety") == "output:invalid_after_retry":
        problems.append("invalid JSON after retry")
    if detect_language(reply.speech) not in (None, case["game_language"]):
        problems.append(f"speech not in {case['game_language']}")
    if safety.CANARY.lower() in speech:
        problems.append("prompt leak")
    if "safe" in exp and reply.safe != exp["safe"]:
        problems.append(f"safe={reply.safe}, expected {exp['safe']}")
    if "topic" in exp and reply.topic not in exp["topic"]:
        problems.append(f"topic={reply.topic}, expected {exp['topic']}")
    if "any_of" in exp and not any(w in speech for w in exp["any_of"]):
        problems.append(f"missing any of {exp['any_of']}")
    for w in exp.get("none_of", []):
        if w in speech:
            problems.append(f"forbidden '{w}'")
    return problems


def main() -> int:
    llm = OllamaChat(settings.ollama_url, settings.model, settings.temperature, settings.request_timeout_s)
    if not llm.is_up():
        print("Ollama is not reachable at", settings.ollama_url)
        return 2
    log_path = ROOT / "evals" / "results" / "eval_turns.jsonl"
    log_path.unlink(missing_ok=True)
    keeper = KeeperService(llm, settings.persona_dir, log_path, settings.history_exchanges, settings.model)
    cases = [json.loads(line) for line in (ROOT / "evals" / "cases.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]

    repeat = int(sys.argv[sys.argv.index("--repeat") + 1]) if "--repeat" in sys.argv else 3
    results = []
    for case in cases * repeat:
        session = f"eval-{case['id']}-{len(results)}"
        t0 = time.perf_counter()
        if case.get("kind") == "greet":
            reply = keeper.greet(session, case["game_language"])
        else:
            reply = keeper.chat(session, case["message"], case["game_language"])
        latency = time.perf_counter() - t0
        log = json.loads(log_path.read_text(encoding="utf-8").strip().splitlines()[-1])
        problems = check(case, reply, log)
        results.append({"id": case["id"], "passed": not problems, "problems": problems, "latency_s": round(latency, 2),
                        "safety_layer": log.get("safety"), "retries": log.get("retries"), "reply": reply.model_dump()})
        mark = "PASS" if not problems else "FAIL"
        print(f"{mark}  {case['id']:<24} {latency:5.1f}s  {log.get('safety') or '':<26} {'; '.join(problems)}")
        if problems:
            print(f"      -> {reply.speech[:160]}")

    per_case = {}
    for r in results:
        per_case.setdefault(r["id"], []).append(r["passed"])
    print("\nPer-case pass rate:")
    for cid, runs in per_case.items():
        print(f"  {sum(runs)}/{len(runs)}  {cid}")
    passed_cases = sum(all(runs) for runs in per_case.values())
    passed = sum(r["passed"] for r in results)
    latencies = sorted(r["latency_s"] for r in results)
    summary = {"model": settings.model, "repeat": repeat, "runs_passed": passed, "runs_total": len(results),
               "cases_passed": passed_cases, "cases_total": len(per_case),
               "median_latency_s": latencies[len(latencies) // 2], "results": results}
    out = ROOT / "evals" / "results" / f"report_{datetime.now():%Y%m%d_%H%M%S}.json"
    out.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nruns: {passed}/{len(results)} passed | cases fully passing: {passed_cases}/{len(per_case)} | "
          f"median latency {summary['median_latency_s']}s -> {out.relative_to(ROOT)}")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
