#!/usr/bin/env python3
"""Statistiques de l'usine par run (T-479, ADR-0021 ; recommandation R2 de docs/research/FACTORY-PRIOR-ART.md).

Idée reprise (idée seulement) de `metrics.jsonl` + `factory-stats` du dépôt AlexPEClub/software-factory (MIT).
Entrée : un répertoire de fichiers `mission-result.v1` (docs/schema/mission-result.v1.json ; artefacts
`mission-result-<n>`, éventuellement dans des sous-dossiers). Sortie : par modèle demandé et par ticket, le nombre de
runs, les tours (médiane, p90), le coût estimé, la durée, les refus de permission par nom d'outil, les statuts et les
causes d'échec.
Usage : python3 tools/factory/stats.py --dir DIR [--json] [--since AAAA-MM-JJ]
Code 0 si le répertoire se lit (même sans run : « aucun run ») ; code 2 si le répertoire est introuvable.
Les montants sont des estimations côté client, pas la facture (NOT_PROVEN). Ne remplace pas ledger.py (fenêtres de quota).
Confidentialité : seuls des agrégats sortent. Les chaînes lues dans les fichiers (modèle, cause, outil) ne sont reprises
que si elles appartiennent à une liste fermée ou à un motif strict de nom d'outil ; le reste devient « autre » ou « ? ».
Hors ligne : stdlib seulement, aucun réseau, aucune lecture de l'environnement.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import statistics
import sys
from datetime import UTC, datetime
from pathlib import Path

SCHEMA_IN = "mission-result.v1"
SCHEMA_OUT = "factory-stats.v1"
STATUSES = ("PASS", "FAIL", "NOT_TESTED", "BLOCKED")
FAILURES = ("model_mismatch", "no_branch", "agent_error", "action_error", "trailers_refused", "turn_cap_exceeded")
MODELS = ("claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5")
OTHER = "autre"
# Nom d'outil d'un refus : `Bash:git push` ou `Edit` ; tout le reste (contenu éventuel) est ramené à « ? ».
# La partie après « : » (début de commande) peut porter un argument collé par erreur (jeton) : seuls des mots
# en minuscules et tirets (deux au plus) sont repris ; sinon elle devient « ? » (`Bash:?`).
TOOL_RE = re.compile(r"([A-Za-z0-9_.-]{1,40})(?::(.*))?", re.S)
CMD_RE = re.compile(r"[a-z][a-z-]{0,19}(?: [a-z][a-z-]{0,19})?")
# champ -> (types acceptés) ; bool est exclu car int en Python.
REQUIRED = {"ticket_issue": (int,), "model_requested": (str,), "status": (str,), "num_turns": (int,),
            "duration_ms": (int,), "total_cost_usd": (int, float)}
SKIP_REASONS = ("illisible", "schema_inconnu", "champ_manquant", "avant_since")


def ts_of(data: dict, path: Path) -> datetime:
    """Horodatage du run : `finished_at` s'il est valide, sinon la date de modification du fichier."""
    value = data.get("finished_at")
    if isinstance(value, str):
        try:
            dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
            return dt if dt.tzinfo else dt.replace(tzinfo=UTC)
        except ValueError:
            pass
    return datetime.fromtimestamp(path.stat().st_mtime, UTC)


def valid_fields(data: dict) -> bool:
    for key, types in REQUIRED.items():
        v = data.get(key)
        if isinstance(v, bool) or not isinstance(v, types):
            return False
    return data["status"] in STATUSES and min(data["num_turns"], data["duration_ms"], data["total_cost_usd"]) >= 0


def read_one(path: Path) -> tuple[dict | None, str]:
    """Rend (run, "") ou (None, motif d'écart)."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return None, "illisible"
    if not isinstance(data, dict) or data.get("schema") != SCHEMA_IN:
        return None, "schema_inconnu"
    if not valid_fields(data):
        return None, "champ_manquant"
    return {**data, "_ts": ts_of(data, path)}, ""


def load_runs(directory: Path, since: datetime | None) -> tuple[list[dict], dict]:
    runs: list[dict] = []
    skipped = {k: 0 for k in SKIP_REASONS}
    for path in sorted(directory.rglob("*.json")):
        run, why = read_one(path)
        if run is not None and since is not None and run["_ts"] < since:
            run, why = None, "avant_since"
        if run is None:
            skipped[why] += 1
        else:
            runs.append(run)
    return runs, skipped


def percentile(values: list[float], pct: int) -> float:
    """Rang le plus proche ; 0 pour une liste vide."""
    if not values:
        return 0
    ordered = sorted(values)
    return ordered[max(0, math.ceil(pct / 100 * len(ordered)) - 1)]


def summary(values: list[float]) -> dict:
    return {"median": statistics.median(values) if values else 0, "p90": percentile(values, 90)}


def clean_tool(raw: object) -> str:
    m = TOOL_RE.fullmatch(raw) if isinstance(raw, str) else None
    if m is None:
        return "?"
    name, cmd = m.groups()
    if cmd is None:
        return name
    return f"{name}:{cmd}" if CMD_RE.fullmatch(cmd) else f"{name}:?"


def count_denials(runs: list[dict]) -> dict:
    """Refus par nom d'outil, tous runs confondus ; un même outil refusé plusieurs fois est additionné."""
    counts: dict[str, int] = {}
    for r in runs:
        denials = r.get("permission_denials")
        for raw in denials if isinstance(denials, list) else []:
            name = clean_tool(raw)
            counts[name] = counts.get(name, 0) + 1
    return dict(sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])))


def count_failures(runs: list[dict]) -> dict:
    counts: dict[str, int] = {}
    for r in runs:
        cause = r.get("failure")
        if cause is None:
            continue
        key = cause if cause in FAILURES else OTHER
        counts[key] = counts.get(key, 0) + 1
    return dict(sorted(counts.items()))


def aggregate(runs: list[dict]) -> dict:
    statuses = {s: sum(1 for r in runs if r["status"] == s) for s in STATUSES}
    return {
        "runs": len(runs),
        "turns": summary([r["num_turns"] for r in runs]),
        "duration_s": summary([r["duration_ms"] / 1000 for r in runs]),
        "cost_usd_estimated": {"total": round(sum(r["total_cost_usd"] for r in runs), 4),
                               **{k: round(v, 4) for k, v in summary([r["total_cost_usd"] for r in runs]).items()}},
        "statuses": {s: n for s, n in statuses.items() if n},
        "failures": count_failures(runs),
        "permission_denials": count_denials(runs),
    }


def group(runs: list[dict], key) -> dict:
    groups: dict = {}
    for r in runs:
        groups.setdefault(key(r), []).append(r)
    return {k: aggregate(v) for k, v in sorted(groups.items(), key=lambda kv: str(kv[0]))}


def build(runs: list[dict], skipped: dict, since: datetime | None) -> dict:
    return {
        "schema": SCHEMA_OUT,
        "since": since.date().isoformat() if since else None,
        "note": "Montants estimés côté client, pas la facture (NOT_PROVEN).",
        "total": aggregate(runs),
        "by_model": group(runs, lambda r: r["model_requested"] if r["model_requested"] in MODELS else OTHER),
        "by_ticket": group(runs, lambda r: r["ticket_issue"]),
        "ignored": skipped,
    }


def fmt_pair(d: dict, nd: int = 0) -> str:
    return f"{d['median']:.{nd}f} / {d['p90']:.{nd}f}"


def table(title: str, label: str, groups: dict) -> list[str]:
    lines = [f"### {title}", "", f"| {label} | Runs | Tours (méd. / p90) | Durée s (méd. / p90) | Coût estimé USD (total) | Statuts | Échecs | Refus |",
             "|---|---|---|---|---|---|---|---|"]
    for name, a in groups.items():
        lines.append("| {} | {} | {} | {} | {:.3f} | {} | {} | {} |".format(
            name, a["runs"], fmt_pair(a["turns"]), fmt_pair(a["duration_s"]), a["cost_usd_estimated"]["total"],
            fmt_counts(a["statuses"]), fmt_counts(a["failures"]), fmt_counts(a["permission_denials"])))
    return [*lines, ""]


def fmt_counts(counts: dict) -> str:
    return ", ".join(f"{k} x{v}" for k, v in counts.items()) or "aucun"


def render_markdown(report: dict) -> str:
    since = f" depuis le {report['since']}" if report["since"] else ""
    head = [f"## Statistiques de l'usine{since}", "", f"Schéma : `{report['schema']}`. {report['note']}", ""]
    ign = ", ".join(f"{k} {v}" for k, v in report["ignored"].items() if v) or "aucun"
    tail = [f"Fichiers ignorés : {ign}."]
    if report["total"]["runs"] == 0:
        return "\n".join([*head, "aucun run", "", *tail]) + "\n"
    body = table("Par modèle demandé", "Modèle", report["by_model"]) + table("Par ticket (issue)", "Issue", report["by_ticket"])
    return "\n".join(head + body + tail) + "\n"


def parse_since(value: str | None) -> datetime | None:
    return datetime.strptime(value, "%Y-%m-%d").replace(tzinfo=UTC) if value else None


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Statistiques de l'usine par run (mission-result.v1).")
    ap.add_argument("--dir", required=True, help="répertoire de fichiers mission-result.v1 (récursif)")
    ap.add_argument("--json", action="store_true", help=f"sortie JSON (champ schema: {SCHEMA_OUT})")
    ap.add_argument("--since", metavar="AAAA-MM-JJ", help="ignore les runs terminés avant cette date (UTC)")
    args = ap.parse_args(argv)
    try:
        since = parse_since(args.since)
    except ValueError:
        print("--since : format AAAA-MM-JJ attendu", file=sys.stderr)
        return 2
    directory = Path(args.dir)
    if not directory.is_dir():
        print(f"répertoire introuvable : {directory}", file=sys.stderr)
        return 2
    runs, skipped = load_runs(directory, since)
    report = build(runs, skipped, since)
    print(json.dumps(report, indent=2, ensure_ascii=False) if args.json else render_markdown(report), end="\n" if args.json else "")
    return 0


if __name__ == "__main__":
    sys.exit(main())
