#!/usr/bin/env python3
"""Cliquet de maintenabilité (ADR-0024, T-414).

Rôle : mesurer le code Python de `tools/` et `tests/` (complexité et longueur par fonction avec radon, longueur par
fichier, erreurs ruff et mypy par fichier, couverture) et refuser toute dégradation par rapport à
`tools/quality/baseline.json`.

Entrées : l'arbre du dépôt (cwd), `baseline.json`, facultativement un `coverage json` (`--coverage-json`) et une
référence git (`--base`) pour la couverture du diff.
Sortie : code 0 (PASS) ou 1 (FAIL) ; `--output` écrit `quality.v1.json` (mesure datée).

Règles :
- code neuf (absent de la ligne de base) : complexité > 15, fonction > 80 lignes, fichier > 600 lignes : échec ;
- code gelé (présent dans la ligne de base, car il dépassait déjà un seuil) : aucune valeur ne peut monter ;
- erreurs ruff et mypy : par fichier, aucune hausse (fichier absent de la ligne de base = 0) ;
- couverture (avec `--coverage-json`) : plancher de 85 % sur le paquet `tools/appgen/appgenlib/` (agrégat des instructions), 80 % des lignes exécutables
  modifiées (`--base`).
Une valeur qui baisse passe sans toucher la ligne de base ; `--write-baseline` la régénère (PR dédiée, noyau).
Python standard seulement ; ruff, radon et mypy sont lancés en sous-processus (versions épinglées dans la CI).
"""

from __future__ import annotations

import argparse
import datetime
import json
import math
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

MAX_CC = 15
MAX_FUNC_LINES = 80
MAX_FILE_LINES = 600
REPORT_FILE_LINES = 400
APPGEN = "tools/appgen/appgenlib/"
APPGEN_FLOOR = 85.0
DIFF_FLOOR = 80.0
SCAN_DIRS = ("tools", "tests")
DEFAULT_MYPY_PATHS = ("tools/appgen",)
BASELINE_PATH = Path(__file__).with_name("baseline.json")
SCHEMA_BASELINE = "quality-baseline.v1"
SCHEMA_REPORT = "quality.v1"


def _run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=False)


def _tool(name: str) -> list[str]:
    found = shutil.which(name)
    return [found] if found else [sys.executable, "-m", name]


def list_python_files(root: Path) -> list[str]:
    """Fichiers `*.py` sous tools/ et tests/, chemins relatifs POSIX triés."""
    out: list[str] = []
    for top in SCAN_DIRS:
        for dirpath, dirnames, filenames in os.walk(root / top):
            dirnames[:] = [d for d in dirnames if not d.startswith(".") and d != "__pycache__"]
            out.extend(Path(dirpath, f).relative_to(root).as_posix() for f in filenames if f.endswith(".py"))
    return sorted(out)


def count_lines(root: Path, rel: str) -> int:
    with open(root / rel, encoding="utf-8") as handle:
        return sum(1 for _ in handle)


def _flatten(blocks: list[dict[str, Any]], prefix: str = "") -> list[dict[str, Any]]:
    """Aplatit la sortie radon (classes, méthodes, fonctions imbriquées) en une liste de fonctions."""
    flat: list[dict[str, Any]] = []
    for block in blocks:
        name = prefix + block["name"]
        if block["type"] == "class":
            flat.extend(_flatten(block.get("methods", []), name + "."))
            continue
        flat.append({"name": name, "cc": block["complexity"], "len": block["endline"] - block["lineno"] + 1})
        flat.extend(_flatten(block.get("closures", []), name + "."))
    return flat


def measure_functions(root: Path, files: list[str]) -> dict[str, dict[str, int]]:
    """Complexité et longueur par fonction, clé `chemin::nom` (suffixe `#n` si le nom se répète)."""
    if not files:
        return {}
    res = _run([*_tool("radon"), "cc", "-j", *files], root)
    if res.returncode != 0:
        raise RuntimeError(f"radon a échoué : {res.stderr.strip()}")
    funcs: dict[str, dict[str, int]] = {}
    for rel, blocks in json.loads(res.stdout).items():
        if not isinstance(blocks, list):  # erreur de syntaxe : radon renvoie {"error": ...}
            raise RuntimeError(f"radon n'a pas pu lire {rel}")
        for item in _flatten(blocks):
            key = f"{rel}::{item['name']}"
            n = 2
            while key in funcs:
                key = f"{rel}::{item['name']}#{n}"
                n += 1
            funcs[key] = {"cc": item["cc"], "len": item["len"]}
    return funcs


def measure_ruff(root: Path, files: list[str]) -> dict[str, int]:
    """Nombre d'erreurs ruff par fichier (jeu complet de pyproject.toml)."""
    if not files:
        return {}
    res = _run([*_tool("ruff"), "check", "--output-format", "json", "--no-cache", "--no-fix", *files], root)
    if res.returncode not in (0, 1):
        raise RuntimeError(f"ruff a échoué : {res.stderr.strip()}")
    counts: dict[str, int] = {}
    for diag in json.loads(res.stdout or "[]"):
        rel = Path(diag["filename"]).resolve().relative_to(root.resolve()).as_posix()
        counts[rel] = counts.get(rel, 0) + 1
    return counts


_MYPY_LINE = re.compile(r"^(?P<file>[^:\n]+\.py):\d+(?::\d+)?: error:", re.MULTILINE)


def measure_mypy(root: Path, paths: tuple[str, ...]) -> dict[str, int]:
    """Nombre d'erreurs mypy par fichier (configuration de pyproject.toml)."""
    paths = tuple(p for p in paths if (root / p).exists())
    if not paths:
        return {}
    res = _run([*_tool("mypy"), "--no-color-output", "--no-error-summary", "--show-column-numbers", *paths], root)
    if res.returncode not in (0, 1):
        raise RuntimeError(f"mypy a échoué : {res.stderr.strip() or res.stdout.strip()}")
    counts: dict[str, int] = {}
    for match in _MYPY_LINE.finditer(res.stdout):
        rel = Path(match["file"]).as_posix()
        counts[rel] = counts.get(rel, 0) + 1
    return counts


def measure(root: Path, mypy_paths: tuple[str, ...] = DEFAULT_MYPY_PATHS) -> dict[str, Any]:
    """Mesure complète : `files` (lignes, ruff, mypy par fichier) et `functions` (cc, len)."""
    files = list_python_files(root)
    ruff = measure_ruff(root, files)
    mypy = measure_mypy(root, mypy_paths)
    return {
        "files": {f: {"lines": count_lines(root, f), "ruff": ruff.get(f, 0), "mypy": mypy.get(f, 0)} for f in files},
        "functions": measure_functions(root, files),
    }


def baseline_from(current: dict[str, Any]) -> dict[str, Any]:
    """Ligne de base : seulement ce qui dépasse déjà un seuil dur ou une erreur d'outil (le reste est borné par les seuils)."""
    files = {
        f: {k: v for k, v in m.items() if k != "lines" or v > MAX_FILE_LINES}
        for f, m in current["files"].items()
        if m["lines"] > MAX_FILE_LINES or m["ruff"] or m["mypy"]
    }
    for entry in files.values():
        for tool in ("ruff", "mypy"):
            if entry.get(tool) == 0:
                del entry[tool]
    functions: dict[str, dict[str, int]] = {}
    for key, m in current["functions"].items():
        over = {n: m[n] for n, limit in (("cc", MAX_CC), ("len", MAX_FUNC_LINES)) if m[n] > limit}
        if over:
            functions[key] = over
    return {"schema": SCHEMA_BASELINE, "files": dict(sorted(files.items())), "functions": dict(sorted(functions.items()))}


def check_functions(baseline: dict[str, Any], current: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    frozen = baseline.get("functions", {})
    for key, now in current["functions"].items():
        limits = frozen.get(key, {})
        kind = "gelée" if key in frozen else "neuve"
        cc_max = limits.get("cc", MAX_CC)
        len_max = limits.get("len", MAX_FUNC_LINES)
        if now["cc"] > cc_max:
            errors.append(f"{key} : complexité {now['cc']} > {cc_max} (fonction {kind})")
        if now["len"] > len_max:
            errors.append(f"{key} : {now['len']} lignes > {len_max} (fonction {kind})")
    return errors


def check_files(baseline: dict[str, Any], current: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    frozen = baseline.get("files", {})
    for rel, now in current["files"].items():
        limits = frozen.get(rel, {})
        lines_max = max(limits.get("lines", MAX_FILE_LINES), MAX_FILE_LINES)
        if now["lines"] > lines_max:
            errors.append(f"{rel} : {now['lines']} lignes > {lines_max}")
        for tool in ("ruff", "mypy"):
            if now[tool] > limits.get(tool, 0):
                errors.append(f"{rel} : {now[tool]} erreurs {tool} > {limits.get(tool, 0)}")
    return errors


def package_percent(cov: dict[str, Any], prefix: str = APPGEN) -> float | None:
    """Couverture agrégée (instructions) des fichiers sous `prefix` ; None si aucun fichier n'est mesuré."""
    covered = total = 0
    for rel, entry in cov.get("files", {}).items():
        if rel.startswith(prefix):
            summary = entry["summary"]
            covered += int(summary["covered_lines"])
            total += int(summary["num_statements"])
    return covered * 100 / total if total else None


def check_coverage(cov: dict[str, Any]) -> list[str]:
    pct = package_percent(cov)
    if pct is None:
        return [f"couverture : {APPGEN} absent de coverage.json"]
    if pct < APPGEN_FLOOR:
        return [f"couverture {APPGEN} : {pct:.1f} % < {APPGEN_FLOOR:.0f} %"]
    return []


_HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")


def parse_added_lines(diff: str) -> dict[str, set[int]]:
    """Lignes ajoutées par fichier, depuis un `git diff -U0`."""
    added: dict[str, set[int]] = {}
    current: str | None = None
    for line in diff.splitlines():
        if line.startswith("+++ "):
            current = line[6:] if line.startswith("+++ b/") else None
        elif current is not None and (m := _HUNK.match(line)):
            start, count = int(m[1]), int(m[2]) if m[2] is not None else 1
            added.setdefault(current, set()).update(range(start, start + count))
    return added


def diff_coverage(added: dict[str, set[int]], cov: dict[str, Any]) -> tuple[int, int]:
    """(lignes exécutables modifiées couvertes, lignes exécutables modifiées) sur les fichiers mesurés."""
    covered = total = 0
    for rel, lines in added.items():
        entry = cov.get("files", {}).get(rel)
        if entry is None:
            continue
        executed = set(entry["executed_lines"]) & lines
        missing = set(entry["missing_lines"]) & lines
        covered += len(executed)
        total += len(executed) + len(missing)
    return covered, total


def check_diff_coverage(root: Path, base: str, cov: dict[str, Any]) -> list[str]:
    res = _run(["git", "diff", "-U0", "--no-color", f"{base}...HEAD", "--", "*.py"], root)
    if res.returncode != 0:
        return [f"couverture du diff : git diff {base}...HEAD a échoué : {res.stderr.strip()}"]
    covered, total = diff_coverage(parse_added_lines(res.stdout), cov)
    if total and covered * 100 < DIFF_FLOOR * total:
        return [f"couverture du diff : {covered}/{total} lignes ({covered * 100 / total:.1f} %) < {DIFF_FLOOR:.0f} %"]
    return []


def percentile(values: list[int], pct: int) -> int:
    """Rang le plus proche (nearest-rank)."""
    if not values:
        return 0
    ordered = sorted(values)
    return ordered[max(math.ceil(pct * len(ordered) / 100) - 1, 0)]


def build_report(current: dict[str, Any], cov: dict[str, Any] | None, commit: str, now: datetime.datetime) -> dict[str, Any]:
    ccs = [m["cc"] for m in current["functions"].values()]
    coverage = None
    if cov is not None:
        appgen = package_percent(cov)
        coverage = {
            "appgen_percent": round(appgen, 1) if appgen is not None else None,
            "total_percent": round(float(cov.get("totals", {}).get("percent_covered", 0.0)), 1),
        }
    return {
        "schema": SCHEMA_REPORT,
        "date": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "commit": commit,
        "cc_max": max(ccs, default=0),
        "cc_p95": percentile(ccs, 95),
        "functions_gt_15": sum(1 for c in ccs if c > MAX_CC),
        "files_gt_400_lines": sum(1 for m in current["files"].values() if m["lines"] > REPORT_FILE_LINES),
        "ruff_errors": sum(m["ruff"] for m in current["files"].values()),
        "mypy_errors": sum(m["mypy"] for m in current["files"].values()),
        "coverage": coverage,
    }


def _git_head(root: Path) -> str:
    res = _run(["git", "rev-parse", "HEAD"], root)
    return res.stdout.strip() if res.returncode == 0 else "unknown"


def _load_json(path: Path) -> dict[str, Any]:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path} : objet JSON attendu")
    return data


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0] if __doc__ else "")
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--baseline", type=Path, default=BASELINE_PATH)
    parser.add_argument("--coverage-json", type=Path, help="sortie de `coverage json` (plancher appgen, diff)")
    parser.add_argument("--base", help="référence git pour la couverture du diff (avec --coverage-json)")
    parser.add_argument("--output", type=Path, help="écrit quality.v1.json")
    parser.add_argument("--write-baseline", action="store_true", help="régénère la ligne de base (PR dédiée)")
    return parser.parse_args(argv)


def run(args: argparse.Namespace) -> int:
    root = args.root.resolve()
    current = measure(root)
    if args.write_baseline:
        args.baseline.write_text(json.dumps(baseline_from(current), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"PASS ligne de base écrite : {args.baseline}")
        return 0
    baseline = _load_json(args.baseline)
    errors = check_functions(baseline, current) + check_files(baseline, current)
    cov = _load_json(args.coverage_json) if args.coverage_json else None
    if cov is not None:
        errors += check_coverage(cov)
        if args.base:
            errors += check_diff_coverage(root, args.base, cov)
    report = build_report(current, cov, _git_head(root), datetime.datetime.now(datetime.UTC))
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))
    for err in errors:
        print(f"FAIL {err}", file=sys.stderr)
    if errors:
        print(f"FAIL cliquet de maintenabilité : {len(errors)} dégradation(s)", file=sys.stderr)
        return 1
    print("PASS cliquet de maintenabilité")
    return 0


def main(argv: list[str] | None = None) -> int:
    return run(parse_args(sys.argv[1:] if argv is None else argv))


if __name__ == "__main__":
    sys.exit(main())
