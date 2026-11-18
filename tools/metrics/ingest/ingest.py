#!/usr/bin/env python3
"""Ingestion GitHub -> bronze Parquet, puis gold DORA (T-201, ADR-0019). Jeton lecture seule (GITHUB_TOKEN).

Usage :
  ingest.py ingest --repo OWNER/NOM --out DIR [--days 14] [--budget 900]
  ingest.py gold   --out DIR [--now AAAA-MM-JJTHH:MM:SSZ]      -> gold.json sur stdout (metrics-gold.v1)
Fenetre glissante de 14 jours, upsert par cle naturelle : un rejeu ne cree aucun doublon. Budget de requetes
compte ; budget epuise = lignes non enrichies (enriched=false) reprises au passage suivant, code de sortie 0 et
`truncated` dans le resume.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dora
import github_api
import model
import store


def ingest(client, st, now: datetime, days: int = 14) -> dict:
    since = now - timedelta(days=days)
    pr_rows, truncated = [], False
    pulls = []
    for p in client.pages("pulls", {"state": "all", "sort": "updated", "direction": "desc"}):
        if (model.parse_ts(p.get("updated_at")) or now) < since:
            break  # tri decroissant : le reste est hors fenetre
        pulls.append(p)
    for pr in pulls:
        files = reviews = None
        if pr.get("merged_at"):
            try:
                files = [f["filename"] for f in client.pages(f"pulls/{pr['number']}/files", {})]
                reviews = sum(1 for r in client.pages(f"pulls/{pr['number']}/reviews", {})
                              if (r.get("user") or {}).get("type") != "Bot")
            except github_api.BudgetExhausted:
                files = reviews = None
                truncated = True
        else:
            files, reviews = [], 0  # PR non fusionnee : rien a enrichir
        pr_rows.append(model.pr_row(pr, files, reviews))
    run_rows = []
    try:
        for run in client.pages("actions/runs", {"created": f">={since.date().isoformat()}"}, key="workflow_runs"):
            run_rows.append(model.run_row(run))
    except github_api.BudgetExhausted:
        truncated = True
    return {
        "pr": store.upsert(st, "pr", pr_rows), "run": store.upsert(st, "run", run_rows),
        "requests": client.used, "budget": client.budget, "truncated": truncated,
    }


def load(st, source: str) -> list[dict]:
    return [r for day in st.days(source) for r in st.read(source, day)]


def gold(st, now: datetime) -> dict:
    cells = dora.compute(load(st, "pr"), load(st, "run"), now)
    return {"schema": "metrics-gold.v1", "generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "min_n": dora.MIN_N, "cells": cells}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    i = sub.add_parser("ingest")
    i.add_argument("--repo", required=True)
    i.add_argument("--out", required=True, type=Path)
    i.add_argument("--days", type=int, default=14)
    i.add_argument("--budget", type=int, default=github_api.DEFAULT_BUDGET)
    g = sub.add_parser("gold")
    g.add_argument("--out", required=True, type=Path)
    g.add_argument("--now")
    args = ap.parse_args(argv)
    now = model.parse_ts(args.now) if getattr(args, "now", None) else datetime.now(UTC)
    st = store.ParquetStore(args.out)
    if args.cmd == "ingest":
        summary = ingest(github_api.Client(args.repo, args.budget), st, now, args.days)
    else:
        summary = gold(st, now)
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
