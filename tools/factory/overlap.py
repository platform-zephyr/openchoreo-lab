#!/usr/bin/env python3
"""Garde de recouvrement d'un lot d'agents (T-467, constat Q5 n° 4 de l'audit du premier run multi-issues).

Rôle : avant que le planificateur de `claude-agent.yml` émette sa matrice, refuser un lot dont deux tickets ont des
périmètres de fichiers qui se recoupent. La file de fusion refuse une PR en conflit et l'agent, déjà terminé, ne
rebase pas : deux agents ne doivent jamais écrire au même endroit en même temps.

Entrées : une liste de références (numéros d'issues GitHub ou identifiants `T-NNN`), par `--tickets` ou la variable
`TICKETS` (même format que `factory/plan-matrix.sh` : virgules ou espaces). Une issue est rattachée à son ticket par le
champ `github_issue:` de l'en-tête. Le périmètre est lu dans `## Périmètre de fichiers` avec le même analyseur et le
même test de recoupement de globs que le dispatcher (`tools/backlog/admission.py`, T-210).

Règle de finesse (dossiers racines) : un élément qui désigne un dossier de premier niveau (`tools/`, `docs/`,
`tests/`, `.github/`, ou `tools/**`) est une **ombrelle** quand le même ticket déclare aussi au moins un chemin plus
précis dessous (`tools/observe/lint.py`, `tests/observe/`). L'ombrelle est alors ignorée : seuls ses chemins précis
comptent. Deux tickets n'entrent donc en conflit sous un dossier racine que si tous deux déclarent un même sous-chemin
(ou deux sous-chemins qui se recoupent). Sûreté : un dossier racine déclaré **sans** chemin précis dessous reste une
revendication de tout le sous-arbre (il recoupe tout ce que l'autre ticket y déclare) ; un dossier de profondeur 2 ou
plus (`tools/appgen/`) n'est jamais une ombrelle ; les fichiers chauds sont cherchés dans le périmètre raffiné, donc un
fichier chaud n'est revendiqué que s'il est déclaré ou couvert par un dossier non raffiné.

Fichiers chauds : `.github/workflows/ci.yaml`, `.github/CODEOWNERS`, `tools/dev/check`, `tools/dev/ci-map.tsv`,
`AGENTS.md`. Les trois premiers fichiers CI sont couplés par le test de parité (T-460) : un ticket qui touche l'un
d'eux est compté comme touchant les trois.

Sortie : JSON `overlap-guard.v1` sur stdout (champ additif `umbrellas` par ticket : ombrelles ignorées) ; un message par refus sur stderr.
Codes : 0 = lot admis ; 4 = recouvrement (lot refusé) ; 3 = référence sans ticket ou sans périmètre exploitable dans
un lot de plus d'un ticket (lot refusé : rien ne prouve l'absence de recouvrement) ; 2 = usage.
Hors ligne, stdlib seulement, lecture seule : aucun réseau, aucun secret, aucune écriture.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

# `python3 -I` ignore PYTHONDONTWRITEBYTECODE : sans ceci, l'import laisse tools/backlog/__pycache__ (T-475).
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backlog"))
import admission  # noqa: E402  (après sys.dont_write_bytecode)

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "overlap-guard.v1"
EXIT_OK, EXIT_USAGE, EXIT_UNRESOLVED, EXIT_OVERLAP = 0, 2, 3, 4

HOT_FILES: tuple[str, ...] = (
    ".github/workflows/ci.yaml",
    ".github/CODEOWNERS",
    "tools/dev/check",
    "tools/dev/ci-map.tsv",
    "AGENTS.md",
)
# Couplage par le test de parité ci.yaml <-> check (T-460, tests/dev-factory/ci-parity.sh).
COUPLED: tuple[str, ...] = (".github/workflows/ci.yaml", "tools/dev/ci-map.tsv", "tools/dev/check")

_HEADER_RE = re.compile(r"---\n(.*?)\n---\n", re.S)
_PERIMETER_RE = re.compile(r"^## Périmètre de fichiers\s*\n(.*?)(?=^## |\Z)", re.S | re.M)


def _header(text: str) -> dict[str, str]:
    m = _HEADER_RE.match(text)
    out: dict[str, str] = {}
    for line in (m.group(1).splitlines() if m else []):
        k, sep, v = line.partition(":")
        if sep:
            out[k.strip()] = re.sub(r"\s+#.*$", "", v).strip().strip('"')
    return out


def load_backlog(backlog: Path) -> dict[str, dict[str, object]]:
    """{T-NNN: {"issue": str|None, "perimeter": [globs]}} pour chaque ticket du backlog."""
    out: dict[str, dict[str, object]] = {}
    for f in sorted(backlog.glob("T-*.md")):
        text = f.read_text(encoding="utf-8")
        h = _header(text)
        if "id" not in h:
            continue
        m = _PERIMETER_RE.search(text)
        body = " ".join(line.strip() for line in m.group(1).splitlines() if line.strip()) if m else ""
        issue = h.get("github_issue", "")
        out[h["id"]] = {"issue": issue if issue.isdigit() else None, "perimeter": admission.parse_perimeter(body)}
    return out


def parse_refs(raw: str) -> list[str]:
    """Références uniques dans l'ordre ; ValueError sur un jeton qui n'est ni un entier ni un T-NNN."""
    refs: list[str] = []
    for tok in raw.replace(",", " ").split():
        if re.fullmatch(r"\d+", tok):
            tok = str(int(tok))
        elif not re.fullmatch(r"T-\d+", tok):
            raise ValueError(f"référence invalide : '{tok}' (numéro d'issue ou T-NNN)")
        if tok not in refs:
            refs.append(tok)
    return refs


def resolve(ref: str, backlog: dict[str, dict[str, object]]) -> str | None:
    if ref.startswith("T-"):
        return ref if ref in backlog else None
    return next((tid for tid, t in backlog.items() if t["issue"] == ref), None)


def _root_dir(glob: str) -> str | None:
    """Nom du dossier de premier niveau si `glob` vaut `X/` ou `X/**`, sinon None."""
    segs = [s for s in glob.strip("/").split("/") if s]
    if len(segs) == 2 and segs[1] == "**":
        return segs[0]
    if len(segs) == 1 and glob.endswith("/") and not any(c in segs[0] for c in "*?["):
        return segs[0]
    return None


def refine(globs: list[str]) -> tuple[list[str], list[str]]:
    """(périmètre raffiné, ombrelles retirées) : voir « Règle de finesse » en tête de module."""
    umbrellas = []
    for g in globs:
        root = _root_dir(g)
        if root and any(h != g and _root_dir(h) is None and h.startswith(root + "/") for h in globs):
            umbrellas.append(g)
    return [g for g in globs if g not in umbrellas], umbrellas


def expand_hot(globs: list[str]) -> tuple[list[str], list[str]]:
    """(périmètre étendu au groupe couplé, fichiers chauds couverts)."""
    hot = [f for f in HOT_FILES if any(admission.overlaps(g, f) for g in globs)]
    extended = list(globs)
    if any(f in COUPLED for f in hot):
        extended += [f for f in COUPLED if f not in extended]
        hot = [f for f in HOT_FILES if f in hot or f in COUPLED]
    return extended, hot


def _pair_conflict(a: dict[str, object], b: dict[str, object]) -> dict[str, object] | None:
    hit = admission.any_overlap(a["scope"], b["scope"])  # type: ignore[arg-type]
    if not hit:
        return None
    hot = sorted(set(a["hot"]) & set(b["hot"]))  # type: ignore[arg-type]
    return {"a": a["ref"], "b": b["ref"], "a_ticket": a["ticket"], "b_ticket": b["ticket"],
            "globs": list(hit), "hot_files": hot}


def evaluate(refs: list[str], backlog: dict[str, dict[str, object]]) -> tuple[int, dict[str, object]]:
    entries: list[dict[str, object]] = []
    unresolved: list[dict[str, str]] = []
    for ref in refs:
        tid = resolve(ref, backlog)
        if tid is None:
            unresolved.append({"ref": ref, "reason": "aucun ticket (ni T-NNN, ni github_issue)"})
            continue
        globs: list[str] = backlog[tid]["perimeter"]  # type: ignore[assignment]
        if not globs:
            unresolved.append({"ref": ref, "reason": f"{tid} : périmètre de fichiers vide ou non exploitable"})
            continue
        precise, umbrellas = refine(globs)
        scope, hot = expand_hot(precise)
        entries.append({"ref": ref, "ticket": tid, "perimeter": globs, "umbrellas": umbrellas,
                        "scope": scope, "hot": hot})
    conflicts = [c for i, a in enumerate(entries) for b in entries[i + 1:] if (c := _pair_conflict(a, b))]
    if conflicts:
        rc = EXIT_OVERLAP
    elif unresolved and len(refs) > 1:
        rc = EXIT_UNRESOLVED
    else:
        rc = EXIT_OK
    out = {"schema": SCHEMA, "admitted": rc == EXIT_OK, "refs": refs,
           "tickets": [{k: e[k] for k in ("ref", "ticket", "perimeter", "umbrellas", "hot")} for e in entries],
           "conflicts": conflicts, "unresolved": unresolved}
    return rc, out


def _label(ref: str, tid: str | None = None) -> str:
    if ref.startswith("T-"):
        return ref
    return f"#{ref} ({tid})" if tid else f"#{ref}"


def messages(out: dict[str, object]) -> list[str]:
    lines = []
    for c in out["conflicts"]:  # type: ignore[union-attr]
        hot = f" ; fichier chaud : {', '.join(c['hot_files'])}" if c["hot_files"] else ""
        lines.append(f"REFUS recouvrement : {_label(c['a'], c['a_ticket'])} et {_label(c['b'], c['b_ticket'])} "
                     f"partagent {c['globs'][0]} ~ {c['globs'][1]}{hot}. Lancer l'un après la fusion de l'autre.")
    for u in out["unresolved"]:  # type: ignore[union-attr]
        lines.append(f"REFUS périmètre inconnu : {_label(u['ref'])} : {u['reason']}. Recouvrement impossible à exclure.")
    return lines


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tickets", default=os.environ.get("TICKETS", ""),
                    help="issues ou T-NNN, virgules ou espaces (défaut : $TICKETS)")
    ap.add_argument("--backlog", type=Path, default=ROOT / "backlog")
    args = ap.parse_args(argv)
    try:
        refs = parse_refs(args.tickets)
    except ValueError as e:
        print(f"overlap: {e}", file=sys.stderr)
        return EXIT_USAGE
    if not refs:
        print("overlap: aucune référence à contrôler", file=sys.stderr)
        return EXIT_USAGE
    rc, out = evaluate(refs, load_backlog(args.backlog))
    print(json.dumps(out, ensure_ascii=False, indent=2, sort_keys=True))
    for line in messages(out):
        print(line, file=sys.stderr)
    if rc == EXIT_OK and out["unresolved"]:
        print("overlap: ticket seul sans périmètre exploitable : admis (aucun autre agent dans le lot)", file=sys.stderr)
    return rc


if __name__ == "__main__":
    sys.exit(main())
