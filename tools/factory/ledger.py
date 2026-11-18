#!/usr/bin/env python3
"""Ledger minimal de quota et disjoncteur « limit » (T-326, ADR-0021 / ADR-0017).

Entrees : fichiers JSON `mission-result.v1` (un par mission) dans un dossier. Champs lus : tokens, num_turns,
duration_ms, total_cost_usd, status, plus, quand l'executant les fournit :
  finished_at  horodatage ISO 8601 (sinon la date de modification du fichier)
  agent        identite d'agent (sinon "inconnu")
  limit        {"reset_at": "<ISO 8601>"} ou {"message": "<texte du CLI>"}, ou status "LIMIT"
Les montants sont des estimations cote client, pas la facture ; aucun solde d'abonnement n'est lu (NOT_PROVEN).
Hors ligne : stdlib uniquement, aucun reseau, aucun secret.

Sous-commandes :
  report  --results DIR               sommes par fenetre de 5 h et par semaine (JSON)
  check   --state FILE [--model M]    code 0 si l'usine peut lancer ; code 11 si le disjoncteur est ouvert
  gate    --state FILE [--model M]    comme check, et ecrit `limited=true|false` dans $GITHUB_OUTPUT (planificateur) ;
                                      une limite propre a une famille (Opus, Sonnet) ne bloque pas les autres modeles
  detect  --execution-file F --state FILE [--issue N] [--model M] [--now ISO]
                                      lit la sortie de claude-code-action (JSON ou JSONL) ; si le message final est une
                                      erreur de limite d'usage, ouvre le disjoncteur (code 11), sinon 0 (T-467)
  trip    --results DIR --state FILE  ouvre le disjoncteur s'il existe un resultat « limit » (code 11), sinon 0
  reset   --state FILE                referme le disjoncteur (geste manuel de Paul, au reset annonce)
Le disjoncteur ne relance jamais : il consigne `resume_at` ; la reprise reste manuelle.

Formes du message (doc officielle https://code.claude.com/docs/en/errors, section « Usage limits », lue le
2026-11-18) : « You've hit your session limit · resets 3:45pm », « You've hit your weekly limit · resets Mon 12:00am »,
« You've hit your Opus limit · resets 3:45pm », « You've hit your Sonnet limit · resets 3:45pm ». Un throttle serveur
(« Server is temporarily limiting requests », « Request rejected (429) », 529 « Overloaded ») n'est PAS une limite
d'abonnement : le disjoncteur l'ignore. En mode `-p`, l'erreur arrive dans le champ `result` du message final ; le
sous-type peut rester `success` avec `is_error: true` (anthropics/claude-code#79500) : seul `is_error` compte.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import UTC, datetime, timedelta, tzinfo
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

WINDOW = timedelta(hours=5)
EXIT_OPEN = 11
FIELDS = ("input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")
# Forme officielle (doc « Usage limits ») ; apostrophe droite ou typographique.
OFFICIAL_RE = re.compile(r"you(?:'|\u2019| ha)ve hit your (session|weekly|opus|sonnet) limit", re.I)
# Formes generiques (« 5-hour session limit reached » ; « Claude AI usage limit reached|<epoch> » des anciens CLI, vue
# dans des issues amont, absente de la doc : NOT_PROVEN). « rate limit » est exclu : throttle, pas quota.
LIMIT_RE = re.compile(r"\b(session|usage|weekly|5-hour)\s+limit\b", re.I)
EPOCH_RE = re.compile(r"usage limit reached\|(\d{10})", re.I)
RESET_RE = re.compile(
    r"resets?\s+(?:at\s+)?(?:(mon|tue|wed|thu|fri|sat|sun)[a-z]*\.?\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?"
    r"(?:\s*\(([^)]+)\))?", re.I)
WEEKDAYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
FAMILY = {"opus": "claude-opus-", "sonnet": "claude-sonnet-"}
# Un texte final plus long n'est pas un message d'erreur du CLI, mais un compte rendu d'agent qui peut le citer.
MAX_ERROR_LEN = 600


def parse_ts(value: str) -> datetime:
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return dt if dt.tzinfo else dt.replace(tzinfo=UTC)


def now_utc(arg: str | None) -> datetime:
    return parse_ts(arg) if arg else datetime.now(UTC)


def load_results(directory: Path) -> list[dict]:
    """Charge les mission-result.v1 ; ignore tout autre JSON. Ajoute `_ts` (datetime UTC) et `_agent`."""
    out = []
    for path in sorted(directory.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(data, dict) or data.get("schema") != "mission-result.v1":
            continue
        ts = data.get("finished_at")
        data["_ts"] = parse_ts(ts) if ts else datetime.fromtimestamp(path.stat().st_mtime, UTC)
        data["_agent"] = data.get("agent") or "inconnu"
        out.append(data)
    return sorted(out, key=lambda r: r["_ts"])


def _zero() -> dict:
    return {"missions": 0, "turns": 0, "duration_ms": 0, "cost_usd_estimated": 0.0, **{k: 0 for k in FIELDS}}


def _add(acc: dict, r: dict) -> None:
    acc["missions"] += 1
    acc["turns"] += int(r.get("num_turns") or 0)
    acc["duration_ms"] += int(r.get("duration_ms") or 0)
    acc["cost_usd_estimated"] = round(acc["cost_usd_estimated"] + float(r.get("total_cost_usd") or 0.0), 6)
    tokens = r.get("tokens") or {}
    for k in FIELDS:
        acc[k] += int(tokens.get(k) or 0)


def window_blocks(results: list[dict]) -> list[dict]:
    """Blocs de 5 h : un bloc s'ouvre a la premiere mission (arrondie a l'heure UTC) et dure 5 h."""
    blocks: list[dict] = []
    ends: list[datetime] = []
    for r in results:
        ts = r["_ts"]
        if not ends or ts >= ends[-1]:
            start = ts.replace(minute=0, second=0, microsecond=0)
            ends.append(start + WINDOW)
            blocks.append({"start": start.isoformat(), "end": (start + WINDOW).isoformat(), **_zero()})
        _add(blocks[-1], r)
    return blocks


def week_start(ts: datetime) -> datetime:
    day = ts.replace(hour=0, minute=0, second=0, microsecond=0)
    return day - timedelta(days=day.weekday())  # lundi UTC


def weekly(results: list[dict], by_agent: bool = False) -> list[dict]:
    """Semaines calendaires UTC (lundi). `by_agent` : un agregat par identite d'agent (repris de T-145)."""
    acc: dict[tuple, dict] = {}
    for r in results:
        ws = week_start(r["_ts"]).date().isoformat()
        key = (ws, r["_agent"]) if by_agent else (ws,)
        row = acc.setdefault(key, {"week_start": ws, **({"agent": r["_agent"]} if by_agent else {}), **_zero()})
        _add(row, r)
    return [acc[k] for k in sorted(acc)]


def report(results: list[dict]) -> dict:
    return {"schema": "quota-ledger.v1", "estimate": True, "blocks_5h": window_blocks(results),
            "weeks": weekly(results), "weeks_by_agent": weekly(results, by_agent=True)}


# --- Disjoncteur ---------------------------------------------------------------------------------------------

def is_limit(r: dict) -> bool:
    return bool(r.get("limit")) or str(r.get("status", "")).upper() == "LIMIT" or r.get("failure") == "session_limit"


def _zone(name: str | None) -> tzinfo:
    """Fuseau entre parentheses dans le message ; UTC sinon (fuseau des runners GitHub)."""
    if name:
        try:
            return ZoneInfo(name.strip())
        except (ZoneInfoNotFoundError, ValueError):
            pass
    return UTC


def _to_24h(hour: int, ap: str) -> int:
    if ap == "pm" and hour < 12:
        return hour + 12
    if ap == "am" and hour == 12:
        return 0
    return hour


def reset_time(r: dict, now: datetime) -> datetime | None:
    """Reset annonce : `limit.reset_at` (ISO) ; sinon « resets 3pm » ou « resets Mon 12:00am » dans `limit.message`
    (prochaine occurrence apres `now`, dans le fuseau du message ou en UTC) ; sinon « |<epoch> » des anciens CLI."""
    lim = r.get("limit") or {}
    if isinstance(lim, dict) and lim.get("reset_at"):
        return parse_ts(lim["reset_at"])
    msg = lim.get("message", "") if isinstance(lim, dict) else str(lim)
    m = RESET_RE.search(msg)
    if not m:
        e = EPOCH_RE.search(msg)
        return datetime.fromtimestamp(int(e.group(1)), UTC) if e else None
    day, minute = m.group(1), int(m.group(3) or 0)
    hour = _to_24h(int(m.group(2)), (m.group(4) or "").lower())
    if hour > 23 or minute > 59:
        return None
    local = now.astimezone(_zone(m.group(5)))
    cand = local.replace(hour=hour, minute=minute, second=0, microsecond=0)
    step = timedelta(days=7 if day else 1)
    if day:
        cand += timedelta(days=(WEEKDAYS.index(day.lower()[:3]) - cand.weekday()) % 7)
    if cand <= local:
        cand += step
    return cand.astimezone(UTC)


def limit_kind(text: str) -> str | None:
    """`session`, `weekly`, `opus`, `sonnet` (forme officielle) ; `usage`, `5-hour` (forme generique) ; sinon None."""
    m = OFFICIAL_RE.search(text) or LIMIT_RE.search(text)
    return m.group(1).lower() if m else None


def classify_message(text: str) -> bool:
    """Vrai si un texte du CLI annonce une limite de session, d'usage, hebdomadaire ou de famille de modele."""
    return limit_kind(text) is not None


def load_messages(path: Path) -> list[dict]:
    """Sortie de claude-code-action (`execution_file`) : tableau JSON ou JSONL ; lignes illisibles ignorees."""
    raw = path.read_text(encoding="utf-8").strip()
    if not raw:
        return []
    try:
        data = json.loads(raw)
        msgs = data if isinstance(data, list) else [data]
    except json.JSONDecodeError:
        msgs = []
        for line in raw.splitlines():
            try:
                msgs.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return [m for m in msgs if isinstance(m, dict)]


def detect_limit(messages: list[dict]) -> dict | None:
    """Limite d'usage annoncee par le message final `result` en erreur (`is_error` vrai), sinon None.

    Seul le message final compte : un tour d'agent qui cite le message (un ticket sur ce sujet) ne declenche rien. Un
    texte final plus long que MAX_ERROR_LEN est un compte rendu, pas une erreur du CLI.
    """
    res = next((m for m in reversed(messages) if m.get("type") == "result"), None)
    if not res or not res.get("is_error"):
        return None
    text = str(res.get("result") or "")
    kind = limit_kind(text) if len(text) <= MAX_ERROR_LEN else None
    if kind is None:
        return None
    return {"kind": kind, "message": text.strip()}


def _write_state(state: Path, now: datetime, resume: datetime | None, **extra) -> None:
    state.parent.mkdir(parents=True, exist_ok=True)
    state.write_text(json.dumps({
        "schema": "quota-breaker.v1", "state": "open", "tripped_at": now.isoformat(),
        "resume_at": resume.isoformat() if resume else None, "resume": "manual", **extra,
    }, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def detect(execution_file: Path, state: Path, now: datetime, issue: int | None = None,
           model: str | None = None) -> int:
    """Ouvre le disjoncteur (code 11) si la session s'est terminee sur une limite d'usage ; sinon 0, sans ecrire."""
    lim = detect_limit(load_messages(execution_file))
    if lim is None:
        return 0
    _write_state(state, now, reset_time({"limit": lim}, now), kind=lim["kind"], message=lim["message"],
                 ticket_issue=issue, model=model, agent="claude-agent")
    return EXIT_OPEN


def trip(results: list[dict], state: Path, now: datetime) -> int:
    hits = [r for r in results if is_limit(r)]
    if not hits:
        return 0
    last = hits[-1]
    _write_state(state, now, reset_time(last, now), ticket_issue=last.get("ticket_issue"), agent=last["_agent"])
    return EXIT_OPEN


def blocks(info: dict, model: str | None) -> bool:
    """Une limite de famille (Opus, Sonnet) ne bloque que cette famille ; toute autre limite bloque tout."""
    prefix = FAMILY.get(str(info.get("kind", "")).lower())
    return not (prefix and model and not model.startswith(prefix))


def check(state: Path, model: str | None = None) -> int:
    if not state.exists():
        return 0
    try:
        info = json.loads(state.read_text(encoding="utf-8") or "{}")
    except json.JSONDecodeError:
        info = {}  # etat illisible : le disjoncteur reste ouvert (sens sur)
    if not isinstance(info, dict):
        info = {}
    if not blocks(info, model):
        print(f"limite {info.get('kind')} : {model} reste autorise (autre famille de modele)")
        return 0
    print(f"disjoncteur ouvert : aucun lancement ; reprise manuelle de Paul a partir de {info.get('resume_at')}")
    return EXIT_OPEN


def gate(state: Path, model: str | None = None) -> int:
    """Pour le planificateur : `limited=true|false` dans $GITHUB_OUTPUT, code 11 si le lot ne doit pas partir."""
    rc = check(state, model)
    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as f:
            f.write(f"limited={'true' if rc else 'false'}\n")
    return rc


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_report = sub.add_parser("report")
    p_report.add_argument("--results", required=True, type=Path)
    for name in ("check", "gate"):
        p_gate = sub.add_parser(name)
        p_gate.add_argument("--state", required=True, type=Path)
        p_gate.add_argument("--model")
    p_detect = sub.add_parser("detect")
    p_detect.add_argument("--execution-file", required=True, type=Path)
    p_detect.add_argument("--state", required=True, type=Path)
    p_detect.add_argument("--issue", type=int)
    p_detect.add_argument("--model")
    p_detect.add_argument("--now")
    p_trip = sub.add_parser("trip")
    p_trip.add_argument("--results", required=True, type=Path)
    p_trip.add_argument("--state", required=True, type=Path)
    p_trip.add_argument("--now")
    p_reset = sub.add_parser("reset")
    p_reset.add_argument("--state", required=True, type=Path)
    args = ap.parse_args(argv)
    if args.cmd == "report":
        print(json.dumps(report(load_results(args.results)), indent=2, sort_keys=True))
        return 0
    if args.cmd in ("check", "gate"):
        return (check if args.cmd == "check" else gate)(args.state, args.model)
    if args.cmd == "detect":
        rc = detect(args.execution_file, args.state, now_utc(args.now), args.issue, args.model)
        if rc:
            print("limite d'usage detectee : disjoncteur ouvert, aucun lancement jusqu'a la reprise manuelle",
                  file=sys.stderr)
        return rc
    if args.cmd == "trip":
        rc = trip(load_results(args.results), args.state, now_utc(args.now))
        if rc:
            print("resultat « limit » : lot arrete, aucune relance ; reprise manuelle au reset", file=sys.stderr)
        return rc
    args.state.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
