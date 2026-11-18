#!/usr/bin/env python3
"""Lint du registre des identités (T-306) : schéma identities.v1 + refus de toute valeur ressemblant à un secret.

Usage : python3 -I tools/backlog/identities_lint.py [fichier.yaml]   (défaut : docs/state/identities.yaml)
Le message d'erreur donne le chemin du champ et la règle, jamais la valeur.
"""
import json
import math
import re
import sys
from pathlib import Path

import jsonschema
import yaml

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "docs" / "schema" / "identities.v1.json"
DEFAULT = ROOT / "docs" / "state" / "identities.yaml"

# Préfixes de jetons connus (GitHub, Doppler, OpenBao/Vault, Slack, AWS, API sk-, GitLab, age, JWT, PEM, en-têtes).
TOKEN_RES = [
    (r"gh[pousr]_[A-Za-z0-9]{16,}", "jeton GitHub"),
    (r"github_pat_[A-Za-z0-9_]{16,}", "jeton GitHub fine-grained"),
    (r"dp\.(?:st|pt|ct|sa|scim|audit)\.[A-Za-z0-9._-]{8,}", "jeton Doppler"),
    (r"hv[sbr]\.[A-Za-z0-9_-]{16,}", "jeton OpenBao/Vault"),
    (r"xox[abprs]-[A-Za-z0-9-]{10,}", "jeton Slack"),
    (r"(?:AKIA|ASIA)[A-Z0-9]{16}", "clé AWS"),
    (r"sk-[A-Za-z0-9_-]{16,}", "clé API sk-"),
    (r"glpat-[A-Za-z0-9_-]{16,}", "jeton GitLab"),
    (r"AGE-SECRET-KEY-1[A-Z0-9]{20,}", "clé age"),
    (r"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}", "JWT"),
    (r"-----BEGIN [A-Z ]*(?:PRIVATE KEY|CERTIFICATE)-----", "bloc PEM"),
    (r"(?i)\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]{16,}", "en-tête d'autorisation"),
]
# Formes interdites dans ce fichier public : IPv4, e-mail, URL, hôte interne, chemin local, OCID.
FORBIDDEN_RES = [
    (r"\b\d{1,3}(?:\.\d{1,3}){3}\b", "adresse IPv4"),
    (r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", "adresse e-mail"),
    (r"https?://", "URL"),
    (r"\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:local|lan|internal|home|svc|cluster\.local)\b", "hôte interne"),
    (r"(?:/home/|/Users/|[A-Za-z]:\\)", "chemin local"),
    (r"ocid1\.[a-z0-9_.-]+", "OCID"),
]
HEX_RE = re.compile(r"\b[0-9a-fA-F]{32,}\b")
B64_RE = re.compile(r"[A-Za-z0-9+/_=-]{24,}")
ENTROPY_MIN = 4.0  # bits par caractère ; un slug en minuscules avec tirets reste sous 4


def entropy(s: str) -> float:
    return -sum((s.count(c) / len(s)) * math.log2(s.count(c) / len(s)) for c in set(s)) if s else 0.0


def scan_text(text: str) -> list[str]:
    """Retourne les règles violées (jamais la valeur)."""
    found = [label for rx, label in TOKEN_RES + FORBIDDEN_RES if re.search(rx, text)]
    if HEX_RE.search(text):
        found.append("chaîne hexadécimale longue")
    for m in B64_RE.finditer(text):
        tok = m.group(0)
        if entropy(tok) >= ENTROPY_MIN and re.search(r"\d", tok) and re.search(r"[A-Za-z]", tok):
            found.append("chaîne à forte entropie")
            break
    return found


class _StrLoader(yaml.SafeLoader):
    """Garde les dates en chaînes : le schéma les valide par motif."""


_StrLoader.yaml_implicit_resolvers = {
    k: [(tag, rx) for tag, rx in v if tag != "tag:yaml.org,2002:timestamp"]
    for k, v in yaml.SafeLoader.yaml_implicit_resolvers.items()
}


def walk(node, path=""):
    if isinstance(node, dict):
        for k, v in node.items():
            yield f"{path}/<clé>", str(k)
            yield from walk(v, f"{path}/{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk(v, f"{path}[{i}]")
    elif isinstance(node, str):
        yield path, node


def lint(file: Path) -> list[str]:
    raw = file.read_text(encoding="utf-8")
    try:
        data = yaml.load(raw, Loader=_StrLoader)  # noqa: S506 (SafeLoader dérivé)
    except yaml.YAMLError as e:
        return [f"{file.name}: YAML invalide ({type(e).__name__})"]
    errors = []
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    for e in sorted(jsonschema.Draft202012Validator(schema).iter_errors(data), key=lambda e: list(map(str, e.absolute_path))):
        loc = "/".join(str(p) for p in e.absolute_path) or "(racine)"
        errors.append(f"{file.name}: schéma {loc}: {e.validator}")
    names = set()
    for i, ident in enumerate(data.get("identities", []) if isinstance(data, dict) else []):
        if not isinstance(ident, dict):
            continue
        if ident.get("name") in names:
            errors.append(f"{file.name}: identities[{i}]: nom en double")
        names.add(ident.get("name"))
        c, r = ident.get("created"), ident.get("rotate_by")
        if isinstance(c, str) and isinstance(r, str) and r < c:
            errors.append(f"{file.name}: identities[{i}]: rotate_by antérieure à created")
    for path, s in walk(data):
        for rule in scan_text(s):
            errors.append(f"{file.name}: {path}: valeur interdite ({rule})")
    for ln, line in enumerate(raw.splitlines(), 1):
        for rule in scan_text(line):
            errors.append(f"{file.name}:{ln}: texte interdit ({rule})")
    return sorted(set(errors))


def main(argv: list[str]) -> int:
    file = Path(argv[1]) if len(argv) > 1 else DEFAULT
    errs = lint(file)
    for e in errs:
        print("ERREUR", e)
    if errs:
        return 1
    print(f"OK {file.name}: schéma identities.v1 valide, aucune valeur suspecte")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
