#!/usr/bin/env python3
"""Taille d'un ticket du backlog (T-480) : de quoi décider qu'il est trop gros pour un run d'agent.

Rôle : calculer, par ticket actif, le nombre d'éléments du périmètre de fichiers, le nombre de critères de fin et les
globs `**` portant sur un répertoire de code. `check.py` en tire un AVERTISSEMENT (jamais une erreur) ; les seuils sont
des constantes initiales, à recalibrer avec les tours par ticket (T-479).

Usage :
  python3 tools/backlog/sizing.py --json        # taille et motifs de chaque ticket actif (todo, in-progress)

Sans dépendance (bibliothèque standard). `check.py` importe ce module ; l'inverse n'a lieu que dans la CLI (import
tardif), pour éviter un cycle.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

MAX_SCOPE_ITEMS = 8  # plus de 8 éléments de périmètre : trop gros
MAX_CRITERIA = 6  # plus de 6 critères de fin : trop gros
CODE_DIRS = ("tools/", "platform/", ".github/")  # un glob `**` ici est trop large pour un run
CRITERIA_RE = re.compile(r"^\s*- \[[ xX]\]", re.M)


def _token(item: str) -> str:
    """Chemin d'un élément de périmètre : sans commentaire entre parenthèses ni apostrophes inverses."""
    return re.sub(r"\s*\(.*?\)", "", item).strip().strip("`").strip("/")


def code_globs(items: list[str]) -> list[str]:
    """Éléments `**` dont le chemin commence par un répertoire de code (CODE_DIRS)."""
    tokens = (_token(i) for i in items)
    return [t for t in tokens if "**" in t and t.startswith(tuple(d.rstrip("/") + "/" for d in CODE_DIRS))]


def size_of(scope_items: list[str], criteria_text: str, off_repo: bool = False) -> dict[str, Any]:
    """Taille d'un ticket : `scope`, `criteria`, `code_globs` et `reasons` (vide si dans les seuils).

    `scope_items` : éléments du périmètre déjà séparés (voir `check.split_scope`) ; `off_repo` : périmètre
    « hors de ce dépôt », sans fichier à compter.
    """
    criteria = len(CRITERIA_RE.findall(criteria_text))
    if off_repo:
        return {"scope": 0, "criteria": criteria, "code_globs": [], "reasons": []}
    globs = code_globs(scope_items)
    reasons = []
    if len(scope_items) > MAX_SCOPE_ITEMS:
        reasons.append(f"{len(scope_items)} éléments de périmètre (seuil {MAX_SCOPE_ITEMS})")
    if criteria > MAX_CRITERIA:
        reasons.append(f"{criteria} critères de fin (seuil {MAX_CRITERIA})")
    if globs:
        reasons.append(f"glob ** sur du code : {', '.join(globs)}")
    return {"scope": len(scope_items), "criteria": criteria, "code_globs": globs, "reasons": reasons}


def ticket_size(ticket: Any, check: Any) -> dict[str, Any]:
    """Taille d'un `check.Ticket` (le module `check` est passé en paramètre : pas d'import circulaire)."""
    text = check.section(ticket.body, "Périmètre de fichiers")
    off_repo = any(m in text.lower() for m in check.OFF_REPO_MARKERS)
    return size_of(check.split_scope(text), check.section(ticket.body, "Critères de fin"), off_repo)


def message(ticket_id: str, size: dict[str, Any]) -> str:
    """Texte de l'avertissement ; chaîne vide si le ticket est dans les seuils."""
    if not size["reasons"]:
        return ""
    return f"TAILLE {ticket_id} {' ; '.join(size['reasons'])} : envisager de scinder le ticket"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="sortie JSON (taille et motifs par ticket actif)")
    parser.parse_args(argv)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import check  # import tardif : check.py importe ce module

    out: dict[str, Any] = {}
    for path in sorted((check.ROOT / "backlog").glob("T-*.md")):
        t = check.parse_ticket(path)
        if not t.errors and t.status in check.ACTIVE:
            out[t.id] = ticket_size(t, check)
    print(json.dumps(out, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
