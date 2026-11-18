#!/usr/bin/env python3
"""Lint OBS-0 : une règle d'alerte, un runbook lisible par agent (T-100, ADR-0015).

Entrées : fichiers de règles Prometheus (`observability/alert-rules/*.yaml`) et runbooks (`docs/runbooks/*.md`,
hors `_TEMPLATE.md`). Sortie : code 0 (aucune erreur) ou 1 ; une erreur par ligne sur stderr.
Contrôles : chaque règle a severity, class et une annotation runbook égale à `docs/runbooks/<alert>.md` ; ce fichier
existe ; son front matter est complet et cohérent avec la règle ; ses `checks` sont en lecture seule ; aucun runbook
n'est orphelin. Python standard + PyYAML.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

SEVERITIES = {"critical", "warning", "info"}
RULE_CLASSES = {"app", "platform"}
GUARD_CLASSES = {"AUTONOME", "REVUE", "MANDAT"}
ACTIONS = {"diagnose", "open-pr", "revert", "notify"}
LIST_KEYS = ("signals", "checks", "allowed_actions", "escalate_when")
REQUIRED = ("alert", "severity", "class", *LIST_KEYS)
NAME_RE = re.compile(r"^[A-Z][A-Za-z0-9]{2,63}$")
WRITE_VERBS = re.compile(
    r"\b(apply|create|delete|patch|edit|replace|scale|exec|cp|drain|cordon|taint|annotate|label|rollout|"
    r"set|sync|rollback|push|merge)\b"
)
READ_PREFIXES = ("kubectl get", "kubectl describe", "kubectl logs", "kubectl top", "kubectl events",
                 "golden-paths/_checks/", "argocd app get", "argocd app history", "git log", "git diff", "git show")
FRONT_RE = re.compile(r"\A---\n(.*?)\n---\n", re.S)


def load_rules(paths: list[Path]) -> tuple[dict[str, dict], list[str]]:
    rules: dict[str, dict] = {}
    errors: list[str] = []
    for path in paths:
        try:
            doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        except (OSError, yaml.YAMLError) as exc:
            errors.append(f"{path}: illisible ({exc.__class__.__name__})")
            continue
        for group in doc.get("groups") or []:
            for rule in group.get("rules") or []:
                name = rule.get("alert")
                if not name:
                    continue
                if name in rules:
                    errors.append(f"{path}: règle {name} dupliquée")
                rules[name] = rule
    return rules, errors


def parse_front_matter(path: Path) -> tuple[dict | None, str]:
    match = FRONT_RE.match(path.read_text(encoding="utf-8"))
    if not match:
        return None, f"{path}: front matter absent"
    try:
        data = yaml.safe_load(match.group(1))
    except yaml.YAMLError:
        return None, f"{path}: front matter YAML invalide"
    if not isinstance(data, dict):
        return None, f"{path}: front matter n'est pas un objet"
    return data, ""


def check_rule(name: str, rule: dict, runbook_dir: Path) -> list[str]:
    errs = []
    labels = rule.get("labels") or {}
    if not NAME_RE.match(name):
        errs.append(f"règle {name}: nom hors du motif {NAME_RE.pattern}")
    if labels.get("severity") not in SEVERITIES:
        errs.append(f"règle {name}: label severity absent ou hors {sorted(SEVERITIES)}")
    if labels.get("class") not in RULE_CLASSES:
        errs.append(f"règle {name}: label class absent ou hors {sorted(RULE_CLASSES)}")
    expected = f"{runbook_dir.as_posix()}/{name}.md"
    got = (rule.get("annotations") or {}).get("runbook")
    if got != expected:
        errs.append(f"règle {name}: annotation runbook {got!r}, attendu {expected!r}")
    return errs


def check_commands(name: str, checks: list) -> list[str]:
    errs = []
    for cmd in checks:
        if not isinstance(cmd, str) or not cmd.strip():
            errs.append(f"runbook {name}: check vide ou non textuel")
            continue
        if not cmd.startswith(READ_PREFIXES):
            errs.append(f"runbook {name}: check hors des préfixes en lecture seule : {cmd!r}")
        elif WRITE_VERBS.search(cmd):
            errs.append(f"runbook {name}: check avec un verbe d'écriture : {cmd!r}")
    return errs


def check_lists(name: str, front: dict) -> list[str]:
    errs = []
    for key in LIST_KEYS:
        value = front.get(key)
        if key in front and (not isinstance(value, list) or not value):
            errs.append(f"runbook {name}: {key} doit être une liste non vide")
    bad = [a for a in front.get("allowed_actions") or [] if a not in ACTIONS]
    if bad:
        errs.append(f"runbook {name}: allowed_actions inconnues {bad} (permises : {sorted(ACTIONS)})")
    if isinstance(front.get("checks"), list):
        errs += check_commands(name, front["checks"])
    return errs


def check_runbook(name: str, rule: dict, front: dict) -> list[str]:
    errs = [f"runbook {name}: clé {k} absente" for k in REQUIRED if k not in front]
    if front.get("alert") != name:
        errs.append(f"runbook {name}: alert={front.get('alert')!r}, attendu {name!r}")
    if front.get("severity") != (rule.get("labels") or {}).get("severity"):
        errs.append(f"runbook {name}: severity différente de la règle")
    if front.get("class") not in GUARD_CLASSES:
        errs.append(f"runbook {name}: class hors {sorted(GUARD_CLASSES)}")
    return errs + check_lists(name, front)


def lint(rule_files: list[Path], runbook_dir: Path) -> list[str]:
    rules, errors = load_rules(rule_files)
    if not rules:
        errors.append("aucune règle d'alerte trouvée")
    for name, rule in sorted(rules.items()):
        errors += check_rule(name, rule, runbook_dir)
        path = runbook_dir / f"{name}.md"
        if not path.is_file():
            errors.append(f"règle {name}: runbook manquant ({path.as_posix()})")
            continue
        front, problem = parse_front_matter(path)
        if front is None:
            errors.append(problem)
        else:
            errors += check_runbook(name, rule, front)
    for path in sorted(runbook_dir.glob("*.md")):
        if path.name != "_TEMPLATE.md" and path.stem not in rules:
            errors.append(f"{path.as_posix()}: runbook orphelin, aucune règle {path.stem}")
    return errors


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--rules", nargs="+", type=Path, help="fichiers de règles (défaut : observability/alert-rules/*.yaml)")
    ap.add_argument("--runbooks", type=Path, default=Path("docs/runbooks"))
    args = ap.parse_args(argv)
    files = args.rules or sorted(Path("observability/alert-rules").glob("*.yaml"))
    errors = lint(files, args.runbooks)
    for err in errors:
        print(f"OBS-0 FAIL {err}", file=sys.stderr)
    if not errors:
        print(f"OBS-0 PASS {len(files)} fichier(s) de règles, runbooks dans {args.runbooks.as_posix()}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
