#!/usr/bin/env python3
"""Check anti-dérive du contexte des agents (stdlib seule, Python >= 3.9).

Trois contrôles, configurés par context-check.json (voisin du script) :
  1. taille : lignes/octets max par fichier « toujours chargé » et pour leur somme ;
  2. liens : tout lien Markdown relatif et tout `@import` doit pointer un fichier existant ;
  3. fraîcheur : en-tête `---` avec owner / updated / review_days ; obligatoire pour les
     fichiers listés dans `freshness_required`, validé s'il est présent ailleurs.
Option : `deny` (motifs interdits dans des fichiers donnés) pour attraper une contradiction connue.

Sortie : une ligne `ERREUR|AVERTISSEMENT <code> <fichier>:<ligne> message` par problème.
Code retour : 1 s'il y a au moins une erreur, sinon 0.
Usage : python3 check_context.py [--root .] [--config chemin.json] [--today AAAA-MM-JJ]
"""
from __future__ import annotations

import argparse
import datetime as dt
import glob
import json
import re
import sys
from pathlib import Path

DEFAULTS = {
    "always_loaded": {"AGENTS.md": {"max_lines": 60, "max_bytes": 5000},
                      "CLAUDE.md": {"max_lines": 10, "max_bytes": 600},
                      "STATE.md": {"max_lines": 60, "max_bytes": 6000}},
    "always_loaded_total": {"max_lines": 130, "max_bytes": 11000},
    "scan_globs": ["*.md", "docs/**/*.md", ".agents/**/*.md", "golden-paths/**/*.md", "missions/**/*.md"],
    "skip_globs": ["docs/research/**", "generated/**", "node_modules/**"],
    "freshness_required": {"STATE.md": 7, "missions/MISSION.md": 30},
    "skill_description_max_chars": 450,
    "deny": [],
}

LINK_RE = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
IMPORT_RE = re.compile(r"^@(\S+\.md)\s*$")
FENCE_RE = re.compile(r"^\s*(```|~~~)")


def load_config(path: Path | None) -> dict:
    cfg = json.loads(json.dumps(DEFAULTS))
    if path and path.is_file():
        cfg.update(json.loads(path.read_text(encoding="utf-8")))
    return cfg


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8", errors="replace")


def parse_front_matter(text: str) -> dict | None:
    """Retourne les paires clé: valeur de l'en-tête `---`, ou None s'il n'y en a pas."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    out: dict = {}
    for ln in lines[1:]:
        if ln.strip() == "---":
            return out
        m = re.match(r"^([A-Za-z_][\w-]*)\s*:\s*(.*?)\s*$", ln)
        if m:
            out[m.group(1)] = m.group(2).strip("\"'")
    return None  # en-tête jamais refermé


def check_sizes(root: Path, cfg: dict, issues: list) -> None:
    tot_l = tot_b = 0
    for name, lim in cfg["always_loaded"].items():
        p = root / name
        if not p.is_file():
            continue
        text = read(p)
        # CLAUDE.md qui ne fait qu'importer AGENTS.md : on ne compte pas deux fois le contenu importé
        n_lines = len(text.splitlines())
        n_bytes = len(text.encode("utf-8"))
        tot_l += n_lines
        tot_b += n_bytes
        if n_lines > lim["max_lines"]:
            issues.append(("ERREUR", "taille-lignes", name, 0, f"{n_lines} lignes > {lim['max_lines']}"))
        if n_bytes > lim["max_bytes"]:
            issues.append(("ERREUR", "taille-octets", name, 0, f"{n_bytes} octets > {lim['max_bytes']}"))
    tl = cfg["always_loaded_total"]
    if tot_l > tl["max_lines"]:
        issues.append(("ERREUR", "total-lignes", "(toujours chargé)", 0, f"{tot_l} lignes > {tl['max_lines']}"))
    if tot_b > tl["max_bytes"]:
        issues.append(("ERREUR", "total-octets", "(toujours chargé)", 0, f"{tot_b} octets > {tl['max_bytes']}"))


def md_files(root: Path, cfg: dict) -> list[Path]:
    seen: set[Path] = set()
    for g in cfg["scan_globs"]:
        for f in glob.glob(str(root / g), recursive=True):
            seen.add(Path(f))
    skipped: set[Path] = set()
    for g in cfg["skip_globs"]:
        for f in glob.glob(str(root / g), recursive=True):
            skipped.add(Path(f))
    skip_dirs = [s for s in skipped if s.is_dir()]
    out = []
    for f in sorted(seen):
        if not f.is_file() or f in skipped:
            continue
        if any(d in f.parents for d in skip_dirs):
            continue
        out.append(f)
    return out


def check_links(root: Path, files: list[Path], issues: list) -> None:
    for f in files:
        in_fence = False
        rel = f.relative_to(root).as_posix()
        for i, ln in enumerate(read(f).splitlines(), 1):
            if FENCE_RE.match(ln):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            targets = [m.group(1) for m in LINK_RE.finditer(ln)]
            mi = IMPORT_RE.match(ln)
            if mi:
                targets.append(mi.group(1))
            for t in targets:
                if re.match(r"^[a-z][a-z0-9+.-]*:", t, re.I) or t.startswith("#"):
                    continue  # http:, mailto:, ancre locale
                path = t.split("#", 1)[0].split("?", 1)[0]
                if not path or "<" in path or "{" in path:
                    continue  # gabarit (<nom>, {{x}})
                base = root if path.startswith("/") else f.parent
                dest = (base / path.lstrip("/")).resolve()
                if not dest.exists():
                    issues.append(("ERREUR", "lien-mort", rel, i, f"cible absente : {t}"))


def check_freshness(root: Path, files: list[Path], cfg: dict, today: dt.date, issues: list) -> None:
    required = cfg["freshness_required"]
    candidates = {f.relative_to(root).as_posix(): f for f in files}
    for name in required:
        candidates.setdefault(name, root / name)
    for rel, f in sorted(candidates.items()):
        if not f.is_file():
            if rel in required:
                issues.append(("ERREUR", "fraicheur-absent", rel, 0, "fichier obligatoire absent"))
            continue
        fm = parse_front_matter(read(f))
        if fm is None:
            if rel in required:
                issues.append(("ERREUR", "fraicheur-entete", rel, 1, "en-tête `---` (owner, updated, review_days) manquant"))
            continue
        if rel not in required and not ({"owner", "updated", "review_days"} & set(fm)):
            continue  # en-tête sans champs de fraîcheur (ex. SKILL.md) : non concerné
        for key in ("owner", "updated"):
            if not fm.get(key):
                issues.append(("ERREUR", "fraicheur-champ", rel, 1, f"champ `{key}` manquant"))
        try:
            updated = dt.date.fromisoformat(fm.get("updated", ""))
        except ValueError:
            if fm.get("updated"):
                issues.append(("ERREUR", "fraicheur-date", rel, 1, f"date invalide : {fm['updated']}"))
            continue
        days = fm.get("review_days") or required.get(rel)
        try:
            days = int(days)
        except (TypeError, ValueError):
            issues.append(("ERREUR", "fraicheur-champ", rel, 1, "`review_days` entier manquant ou invalide"))
            continue
        if updated > today:
            issues.append(("ERREUR", "fraicheur-futur", rel, 1, f"updated {updated} est dans le futur"))
        elif (today - updated).days > days:
            issues.append(("ERREUR", "fraicheur-perime", rel, 1,
                           f"périmé : updated {updated}, review_days {days}, âge {(today - updated).days} j"))


def check_skills(root: Path, cfg: dict, issues: list) -> None:
    mx = cfg["skill_description_max_chars"]
    for f in sorted(glob.glob(str(root / ".agents/skills/*/SKILL.md"))):
        p = Path(f)
        rel = p.relative_to(root).as_posix()
        fm = parse_front_matter(read(p))
        if fm is None or not fm.get("name") or not fm.get("description"):
            issues.append(("ERREUR", "skill-entete", rel, 1, "name et description requis"))
        elif len(fm["description"]) > mx:
            issues.append(("AVERTISSEMENT", "skill-description", rel, 1,
                           f"description de {len(fm['description'])} caractères > {mx} (toujours chargée)"))


def check_deny(root: Path, cfg: dict, issues: list) -> None:
    for rule in cfg["deny"]:
        rx = re.compile(rule["pattern"])
        for g in rule["paths"]:
            for f in sorted(glob.glob(str(root / g), recursive=True)):
                p = Path(f)
                if not p.is_file():
                    continue
                for i, ln in enumerate(read(p).splitlines(), 1):
                    if rx.search(ln):
                        issues.append((rule.get("level", "ERREUR"), "interdit", p.relative_to(root).as_posix(), i,
                                       rule["reason"]))


def run(root: Path, cfg: dict, today: dt.date) -> list:
    issues: list = []
    files = md_files(root, cfg)
    check_sizes(root, cfg, issues)
    check_links(root, files, issues)
    check_freshness(root, files, cfg, today, issues)
    check_skills(root, cfg, issues)
    check_deny(root, cfg, issues)
    return issues


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--config", default=str(Path(__file__).with_name("context-check.json")))
    ap.add_argument("--today", default=None, help="AAAA-MM-JJ (tests)")
    a = ap.parse_args(argv)
    root = Path(a.root).resolve()
    today = dt.date.fromisoformat(a.today) if a.today else dt.date.today()
    issues = run(root, load_config(Path(a.config)), today)
    for lvl, code, f, line, msg in issues:
        print(f"{lvl} {code} {f}:{line} {msg}")
    errs = sum(1 for i in issues if i[0] == "ERREUR")
    print(f"context-check : {errs} erreur(s), {len(issues) - errs} avertissement(s)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
