#!/usr/bin/env python3
"""Historique `quality.v1` (T-421) : une ligne JSON par merge sur `main`.

Rôle : compléter la mesure de `check.py` (shellcheck, % docstrings, fichiers touchés), valider une ligne contre
`docs/schema/quality.v1.json` et l'ajouter à `docs/state/quality-history.jsonl`. Un indicateur informe, il ne bloque pas :
seule une ligne invalide ou en double est refusée. Aucune valeur secrète : des compteurs, un SHA et des chemins.
Python standard seulement ; shellcheck est facultatif (absent : `shellcheck_issues` vaut null).
"""

from __future__ import annotations

import argparse
import ast
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

SCHEMA_PATH = Path(__file__).resolve().parents[2] / "docs" / "schema" / "quality.v1.json"
HISTORY = Path("docs/state/quality-history.jsonl")
MAX_TOUCHED = 200
_TYPES: dict[str, Any] = {"integer": int, "number": (int, float), "string": str, "array": list, "object": dict, "null": type(None)}
_DEFS = (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)


def docstring_percent(root: Path, files: list[str]) -> float:
    """Part (%) des modules, classes et fonctions publiques (nom sans `_`) qui portent une docstring."""
    total = documented = 0
    for rel in files:
        tree = ast.parse((root / rel).read_text(encoding="utf-8"))
        nodes: list[Any] = [tree]
        nodes += [n for n in ast.walk(tree) if isinstance(n, _DEFS) and not n.name.startswith("_")]
        total += len(nodes)
        documented += sum(1 for n in nodes if ast.get_docstring(n) is not None)
    return round(documented * 100 / total, 1) if total else 100.0


def shellcheck_issues(root: Path) -> int | None:
    """Nombre de diagnostics shellcheck sur les `*.sh` suivis par git ; None si shellcheck ou git manque."""
    exe = shutil.which("shellcheck")
    ls = subprocess.run(["git", "ls-files", "*.sh"], cwd=root, capture_output=True, text=True, check=False)
    if exe is None or ls.returncode != 0:
        return None
    files = [f for f in ls.stdout.splitlines() if f]
    if not files:
        return 0
    res = subprocess.run([exe, "-f", "json", *files], cwd=root, capture_output=True, text=True, check=False)
    if res.returncode not in (0, 1):
        return None
    return len(json.loads(res.stdout or "[]"))


def touched_files(root: Path, commit: str) -> list[str]:
    """Fichiers `.py` touchés par le commit (premier parent), pour relier la qualité aux indicateurs de livraison."""
    cmd = ["git", "diff", "--name-only", f"{commit}^1", commit, "--", "*.py"]
    res = subprocess.run(cmd, cwd=root, capture_output=True, text=True, check=False)
    return sorted(res.stdout.split())[:MAX_TOUCHED] if res.returncode == 0 else []


def _check_value(key: str, value: Any, spec: dict[str, Any]) -> list[str]:
    """Validation minimale d'une valeur (const, type, minimum, maximum, motif, objet imbriqué)."""
    if "const" in spec:
        return [] if value == spec["const"] else [f"{key} : {spec['const']!r} attendu"]
    types = spec["type"] if isinstance(spec.get("type"), list) else [spec.get("type")]
    if not any(t in _TYPES and isinstance(value, _TYPES[t]) and not isinstance(value, bool) for t in types):
        return [f"{key} : type {'|'.join(map(str, types))} attendu"]
    errors = _check_bounds(key, value, spec) if isinstance(value, int | float) else []
    if isinstance(value, str) and "pattern" in spec and not re.fullmatch(spec["pattern"], value):
        errors.append(f"{key} : motif {spec['pattern']} non respecté")
    if isinstance(value, dict) and "properties" in spec:
        errors += validate(value, spec, key + ".")
    return errors


def _check_bounds(key: str, value: float, spec: dict[str, Any]) -> list[str]:
    errors = []
    if "minimum" in spec and value < spec["minimum"]:
        errors.append(f"{key} : {value} < {spec['minimum']}")
    if "maximum" in spec and value > spec["maximum"]:
        errors.append(f"{key} : {value} > {spec['maximum']}")
    return errors


def validate(line: dict[str, Any], schema: dict[str, Any], prefix: str = "") -> list[str]:
    """Erreurs de `line` contre le schéma : champs requis, champs inconnus, valeurs."""
    props = schema["properties"]
    errors = [f"{prefix}{k} requis" for k in schema.get("required", []) if k not in line]
    errors += [f"{prefix}{k} inconnu" for k in line if k not in props]
    for key, value in line.items():
        if key in props:
            errors += _check_value(prefix + key, value, props[key])
    return errors


def append_line(path: Path, line: dict[str, Any], schema: dict[str, Any]) -> str:
    """Ajoute une ligne validée ; refuse une ligne invalide ; ignore un commit déjà présent (une ligne par merge)."""
    errors = validate(line, schema)
    if errors:
        raise ValueError("ligne quality.v1 invalide : " + " ; ".join(errors))
    existing = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    if any(json.loads(x).get("commit") == line["commit"] for x in existing if x.strip()):
        return "deja-presente"
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(line, sort_keys=True, ensure_ascii=False) + "\n")
    return "ajoutee"


def enrich(report: dict[str, Any], root: Path, py_files: list[str]) -> dict[str, Any]:
    """Ajoute à la mesure de `check.py` les indicateurs propres à l'historique."""
    return {
        **report,
        "shellcheck_issues": shellcheck_issues(root),
        "docstring_percent": docstring_percent(root, py_files),
        "touched_files": touched_files(root, report["commit"]),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Ajoute la ligne quality.v1 d'un merge à l'historique.")
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--report", type=Path, required=True, help="sortie de `check.py --output`")
    parser.add_argument("--history", type=Path, default=None)
    args = parser.parse_args(argv)
    root = args.root.resolve()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import check

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    line = enrich(json.loads(args.report.read_text(encoding="utf-8")), root, check.list_python_files(root))
    try:
        status = append_line(args.history or root / HISTORY, line, schema)
    except ValueError as err:
        print(f"FAIL {err}", file=sys.stderr)
        return 1
    print(f"PASS quality.v1 {status} : {line['commit'][:12]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
