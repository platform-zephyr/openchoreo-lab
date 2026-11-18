"""Metriques DORA par agent, classe, app et cluster, calculees depuis les lignes bronze (T-201, ex T-202, ADR-0019).

Formules (D1 a D5, D7, D8 du catalogue) sur les PR fusionnees dans la fenetre :
- deploy_frequency   : PR fusionnees portant sur apps/ ou platform/, par jour.
- lead_time_hours    : mediane (merged_at - created_at) de ces PR. Proxy : le 1er commit n'est pas ingere.
- change_fail_rate   : part de ces PR annulees par une PR de revert fusionnee (champ reverts_pr).
- recovery_time_hours: mediane (fusion du revert - fusion de la PR annulee).
- rework_rate        : part de ces PR qui sont un fix ou un revert (convention de commit).
- autonomy_rate      : part des PR fusionnees (enrichies) sans aucune revue humaine.
- ci_loop_minutes    : mediane (updated_at - created_at) des runs termines en success ou failure.
Honnetete : aucune source runtime (Argo) ici ; D1 ne prouve donc pas un deploiement synchronise (`proof` = github-only).
Un chiffre sous n < MIN_N n'est pas publie : valeur None, statut `insuffisant`. Le cluster n'existe pas dans GitHub :
dimension `cluster` = `unknown` tant qu'aucune source ne le porte. Stdlib seule.
"""
from __future__ import annotations

import statistics
from datetime import datetime, timedelta

from model import parse_ts

MIN_N = 5
DIMENSIONS = ("agent", "class", "app", "cluster")
WINDOWS = (7, 30)
PROOF = "github-only"


def _hours(a: datetime, b: datetime) -> float:
    return (b - a).total_seconds() / 3600


def _cell(metric: str, window: int, dim: str, key: str, value: float | None, n: int) -> dict:
    ok = n >= MIN_N and value is not None
    return {
        "metric": metric, "window_days": window, "dimension": dim, "key": key,
        "value": round(value, 4) if ok else None, "n": n,
        "status": "ok" if ok else "insuffisant", "proof": PROOF,
    }


def _median(values: list[float]) -> float | None:
    return statistics.median(values) if values else None


def _merged_in_window(prs: list[dict], now: datetime, window: int) -> list[dict]:
    start = now - timedelta(days=window)
    out = []
    for r in prs:
        m = parse_ts(r.get("merged_at"))
        if m and start <= m <= now:
            out.append(r)
    return out


def _ratio(count: int, total: int) -> float | None:
    return count / total if total else None


def _ci_loops(runs: list[dict], now: datetime, window: int) -> list[float]:
    start = now - timedelta(days=window)
    out = []
    for x in runs:
        if x.get("conclusion") not in ("success", "failure") or not x.get("created_at") or not x.get("updated_at"):
            continue
        created = parse_ts(x["created_at"])
        if start <= created <= now:
            out.append((parse_ts(x["updated_at"]) - created).total_seconds() / 60)
    return out


def compute_group(prs: list[dict], runs: list[dict], reverts: dict[int, datetime], now: datetime,
                  window: int) -> list[tuple[str, float | None, int]]:
    """(metrique, valeur, n) pour un groupe de lignes. `reverts` : numero de PR annulee -> date de fusion du revert."""
    merged = _merged_in_window(prs, now, window)
    deploys = [r for r in merged if r.get("deploy_scope")]
    lead = [_hours(parse_ts(r["created_at"]), parse_ts(r["merged_at"])) for r in deploys if r.get("created_at")]
    failed = [r for r in deploys if r["pr_number"] in reverts]
    recovery = [_hours(parse_ts(r["merged_at"]), reverts[r["pr_number"]]) for r in failed]
    enriched = [r for r in merged if r.get("enriched")]
    loops = _ci_loops(runs, now, window)
    nd = len(deploys)
    return [
        ("deploy_frequency", nd / window, nd),
        ("lead_time_hours", _median(lead), len(lead)),
        ("change_fail_rate", _ratio(len(failed), nd), nd),
        ("recovery_time_hours", _median(recovery), len(recovery)),
        ("rework_rate", _ratio(sum(1 for r in deploys if r.get("is_fix") or r.get("is_revert")), nd), nd),
        ("autonomy_rate", _ratio(sum(1 for r in enriched if r.get("human_reviews") == 0), len(enriched)),
         len(enriched)),
        ("ci_loop_minutes", _median(loops), len(loops)),
    ]


def revert_index(prs: list[dict]) -> dict[int, datetime]:
    """Numero de PR annulee -> date de fusion du revert (le plus ancien si plusieurs)."""
    out: dict[int, datetime] = {}
    for r in prs:
        target, ts = r.get("reverts_pr"), parse_ts(r.get("merged_at"))
        if target and ts and (target not in out or ts < out[target]):
            out[target] = ts
    return out


def compute(prs: list[dict], runs: list[dict], now: datetime, windows=WINDOWS) -> list[dict]:
    """Cellules de gold : une ligne par (metrique, fenetre, dimension, cle). La dimension `all` est le total."""
    reverts = revert_index(prs)
    cells: list[dict] = []
    for window in windows:
        groups: list[tuple[str, str, list[dict], list[dict]]] = [("all", "all", prs, runs)]
        for dim in DIMENSIONS:
            keys = sorted({_of(r, dim) for r in prs} | ({_of(x, dim) for x in runs} if dim == "agent" else set()))
            for key in keys:
                gruns = runs if dim == "cluster" else [x for x in runs if dim == "agent" and _of(x, dim) == key]
                groups.append((dim, key, [r for r in prs if _of(r, dim) == key], gruns))
        for dim, key, gp, gr in groups:
            for metric, value, n in compute_group(gp, gr, reverts, now, window):
                cells.append(_cell(metric, window, dim, key, value, n))
    return cells


def _of(row: dict, dim: str) -> str:
    return "unknown" if dim == "cluster" else str(row.get(dim, "unknown"))
