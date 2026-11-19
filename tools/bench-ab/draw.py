#!/usr/bin/env python3
"""Tirage préenregistré de la panne de M4 (T-485, docs/research/POC-OPENCHOREO-STRATEGY.md §2.3).

La panne dépend seulement de la graine et du rang : le bras n'entre pas dans le calcul, donc le tirage est identique
pour les deux bras au même rang. `tests/bench-ab/draw.yaml` enregistre la graine et les tirages ; `verify` refuse tout
écart entre le fichier et le recalcul. Usage : python3 tools/bench-ab/draw.py [--file tests/bench-ab/draw.yaml]
Code 0 si le fichier est conforme, 1 sinon. Stdlib + PyYAML, hors ligne.
"""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

import yaml

FAULTS = ("digest_faux", "port_faux", "probe_fausse")
RANKS = (0, 1, 2)  # 0 = passe 0 (non comptée), 1 et 2 = runs comptés
DEFAULT = Path(__file__).resolve().parents[2] / "tests" / "bench-ab" / "draw.yaml"


def draw(seed: str, rank: int) -> str:
    """Panne du rang `rank` : SHA-256 de `graine:M4:rang`, premiers 32 bits modulo le nombre de pannes."""
    digest = hashlib.sha256(f"{seed}:M4:{rank}".encode()).hexdigest()
    return FAULTS[int(digest[:8], 16) % len(FAULTS)]


def verify(doc: dict) -> list[str]:
    """Liste des écarts (vide = conforme)."""
    errors: list[str] = []
    if doc.get("schema") != "bench-ab-draw.v1":
        errors.append("schema inattendu")
    seed = doc.get("seed")
    if not isinstance(seed, str) or not seed:
        return [*errors, "graine absente"]
    if tuple(doc.get("faults", ())) != FAULTS:
        errors.append("liste des pannes différente du code")
    recorded = doc.get("draws")
    if not isinstance(recorded, dict) or sorted(recorded) != list(RANKS):
        return [*errors, "tirages attendus pour les rangs 0, 1 et 2"]
    for rank, fault in recorded.items():
        if fault != draw(seed, rank):
            errors.append(f"rang {rank} : enregistré {fault!r}, recalculé {draw(seed, rank)!r}")
    return errors


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--file", type=Path, default=DEFAULT)
    args = ap.parse_args(argv)
    try:
        doc = yaml.safe_load(args.file.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        print(f"FAIL : {args.file} illisible ({type(exc).__name__})", file=sys.stderr)
        return 1
    errors = verify(doc if isinstance(doc, dict) else {})
    for e in errors:
        print(f"FAIL : {e}", file=sys.stderr)
    print("PASS : tirage conforme" if not errors else "FAIL : tirage non conforme")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
