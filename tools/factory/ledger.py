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
  check   --state FILE                code 0 si l'usine peut lancer ; code 11 si le disjoncteur est ouvert
  trip    --results DIR --state FILE  ouvre le disjoncteur s'il existe un resultat « limit » (code 11), sinon 0
  reset   --state FILE                referme le disjoncteur (geste manuel de Paul, au reset annonce)
Le disjoncteur ne relance jamais : il consigne `resume_at` ; la reprise reste manuelle.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

WINDOW = timedelta(hours=5)
EXIT_OPEN = 11
FIELDS = ("input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens")
LIMIT_RE = re.compile(r"(session|usage|weekly|5-hour|rate)\s+limit", re.I)
RESET_RE = re.compile(r"resets?\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?", re.I)


def parse_ts(value: str) -> datetime:
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def now_utc(arg: str | None) -> datetime:
    return parse_ts(arg) if arg else datetime.now(timezone.utc)


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
        data["_ts"] = parse_ts(ts) if ts else datetime.fromtimestamp(path.stat().st_mtime, timezone.utc)
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


def reset_time(r: dict, now: datetime) -> datetime | None:
    """Reset annonce : `limit.reset_at` (ISO) ou « resets 3pm » dans `limit.message` (prochaine occurrence, UTC)."""
    lim = r.get("limit") or {}
    if isinstance(lim, dict) and lim.get("reset_at"):
        return parse_ts(lim["reset_at"])
    msg = lim.get("message", "") if isinstance(lim, dict) else str(lim)
    m = RESET_RE.search(msg)
    if not m:
        return None
    hour, minute, ap = int(m.group(1)), int(m.group(2) or 0), (m.group(3) or "").lower()
    if ap == "pm" and hour < 12:
        hour += 12
    if ap == "am" and hour == 12:
        hour = 0
    if hour > 23 or minute > 59:
        return None
    cand = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    return cand if cand > now else cand + timedelta(days=1)


def classify_message(text: str) -> bool:
    """Vrai si un texte du CLI annonce une limite de session, d'usage ou hebdomadaire."""
    return bool(LIMIT_RE.search(text))


def trip(results: list[dict], state: Path, now: datetime) -> int:
    hits = [r for r in results if is_limit(r)]
    if not hits:
        return 0
    last = hits[-1]
    resume = reset_time(last, now)
    state.parent.mkdir(parents=True, exist_ok=True)
    state.write_text(json.dumps({
        "schema": "quota-breaker.v1", "state": "open", "tripped_at": now.isoformat(),
        "resume_at": resume.isoformat() if resume else None, "resume": "manual",
        "ticket_issue": last.get("ticket_issue"), "agent": last["_agent"],
    }, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return EXIT_OPEN


def check(state: Path) -> int:
    if state.exists():
        info = json.loads(state.read_text(encoding="utf-8") or "{}")
        print(f"disjoncteur ouvert : aucun lancement ; reprise manuelle de Paul a partir de {info.get('resume_at')}")
        return EXIT_OPEN
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_report = sub.add_parser("report")
    p_report.add_argument("--results", required=True, type=Path)
    p_check = sub.add_parser("check")
    p_check.add_argument("--state", required=True, type=Path)
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
    if args.cmd == "check":
        return check(args.state)
    if args.cmd == "trip":
        rc = trip(load_results(args.results), args.state, now_utc(args.now))
        if rc:
            print("resultat « limit » : lot arrete, aucune relance ; reprise manuelle au reset", file=sys.stderr)
        return rc
    args.state.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
