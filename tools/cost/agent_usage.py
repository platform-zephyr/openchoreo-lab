#!/usr/bin/env python3
"""Agregat hebdomadaire par identite d'agent (repris de T-145, T-326). Estimation cote client, pas la facture.

Usage : tools/cost/agent_usage.py --results DIR   -> JSON sur stdout (semaine UTC commencant le lundi, par agent)
Lit les mission-result.v1 via tools/factory/ledger.py ; hors ligne, stdlib uniquement.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "factory"))
import ledger  # noqa: E402


def weekly_by_agent(directory: Path) -> list[dict]:
    return ledger.weekly(ledger.load_results(directory), by_agent=True)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--results", required=True, type=Path)
    args = ap.parse_args(argv)
    print(json.dumps({"schema": "agent-usage.v1", "estimate": True, "weeks": weekly_by_agent(args.results)},
                     indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
