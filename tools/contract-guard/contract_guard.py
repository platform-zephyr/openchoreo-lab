#!/usr/bin/env python3
"""Garde du contrat (T-070, ADR-0001 Vérification, ADR-0005 §3) : stdlib seule, lecture seule, sans réseau ni cluster.

Trois contrôles :
  1. Compatibilité du schéma : `docs/schema/app.schema.json` comparé à la version de la base (défaut `origin/main`).
     Une rupture (propriété retirée, `required` ajouté, valeur d'`enum` retirée, type, borne ou motif resserré,
     `additionalProperties` passé à false) sans changement de `properties.apiVersion.const` = FAIL.
  2. Aucun objet Kubernetes (`apiVersion:` et `kind:` en colonne 0) hors des dossiers autorisés ci-dessous.
  3. Indicateur (informatif, jamais bloquant) : part des apps déclarées par `app.yaml` seul (cible 90 %, ADR-0001).

Dossiers autorisés : apps/ et generated/ (contrat et sortie d'appgen), platform/ (objets plateforme sous Argo CD),
docs/, tests/ et golden-paths/ (exemples, fixtures et gabarits que rien ne synchronise), clusters/ (amorçage des
clusters : plateforme, pas applicatif). Tout autre dossier (tools/, .github/, factory/...) est refusé.

Usage : contract_guard.py [--root DIR] [--base REF] [--base-schema FICHIER] [--only schema|manifests]
Codes : 0 PASS, 1 FAIL, 2 usage, 125 NOT_TESTED (base introuvable : le contrôle de schéma n'a pas tourné).
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

SCHEMA_REL = "docs/schema/app.schema.json"
ALLOWED_DIRS = ("apps/", "generated/", "platform/", "docs/", "tests/", "golden-paths/", "clusters/")
MANIFEST_EXT = (".yaml", ".yml")
API_RE = re.compile(r"^apiVersion:\s*\S", re.M)
KIND_RE = re.compile(r"^kind:\s*\S", re.M)
LOWER_BOUNDS = ("minimum", "minItems", "minLength", "minProperties")
UPPER_BOUNDS = ("maximum", "maxItems", "maxLength", "maxProperties")


def _types(node):
    t = node.get("type")
    return set(t) if isinstance(t, list) else ({t} if t else None)


def _bound_breaks(path, old, new):
    """Bornes resserrées : un maximum plus bas, un minimum plus haut, ou une borne nouvelle."""
    out = []
    for keys, tighter in ((UPPER_BOUNDS, lambda n, o: n < o), (LOWER_BOUNDS, lambda n, o: n > o)):
        out += [f"{path}: {k} resserré" for k in keys if k in new and (k not in old or tighter(new[k], old[k]))]
    return out


def _scalar_breaks(path, old, new):
    out = []
    old_t, new_t = _types(old), _types(new)
    if old_t and new_t and not old_t <= new_t:
        out.append(f"{path}: type {sorted(old_t)} -> {sorted(new_t)}")
    if "pattern" in new and old.get("pattern") != new["pattern"]:
        out.append(f"{path}: motif modifié")
    out += _bound_breaks(path, old, new)
    if new.get("additionalProperties") is False and old.get("additionalProperties") is not False:
        out.append(f"{path}: additionalProperties passé à false")
    return out


def _set_breaks(path, old, new):
    out = []
    if "enum" in new:
        if "enum" not in old:
            out.append(f"{path}: enum ajouté")
        else:
            gone = {json.dumps(v) for v in old["enum"]} - {json.dumps(v) for v in new["enum"]}
            out += [f"{path}: valeur d'enum retirée {v}" for v in sorted(gone)]
    for name in sorted(set(new.get("required", [])) - set(old.get("required", []))):
        out.append(f"{path}: champ requis ajouté « {name} »")
    for name in sorted(set(old.get("properties", {})) - set(new.get("properties", {}))):
        out.append(f"{path}: propriété retirée « {name} »")
    for name in sorted(set(old.get("definitions", {})) - set(new.get("definitions", {}))):
        out.append(f"{path}: définition retirée « {name} »")
    return out


def schema_breaks(old, new, path="#"):
    """Liste des ruptures de compatibilité de `new` par rapport à `old` (JSON Schema déjà chargé)."""
    if not isinstance(old, dict) or not isinstance(new, dict):
        return []
    out = _scalar_breaks(path, old, new) + _set_breaks(path, old, new)
    for key, old_v in old.items():
        new_v = new.get(key)
        if isinstance(old_v, dict) and isinstance(new_v, dict):
            out += schema_breaks(old_v, new_v, f"{path}/{key}")
        elif isinstance(old_v, list) and isinstance(new_v, list) and key not in ("enum", "required"):
            for i, (o, n) in enumerate(zip(old_v, new_v, strict=False)):
                out += schema_breaks(o, n, f"{path}/{key}[{i}]")
    return out


def api_version(schema):
    return schema.get("properties", {}).get("apiVersion", {}).get("const")


def check_schema(old, new):
    """(statut, détails) : FAIL si rupture sans nouvelle version du contrat (apiVersion.const)."""
    breaks = [b for b in schema_breaks(old, new) if "/apiVersion" not in b]
    if not breaks:
        return "PASS", ["schéma compatible avec la base"]
    if api_version(old) != api_version(new):
        return "PASS", [f"rupture déclarée par une nouvelle version ({api_version(old)} -> {api_version(new)})", *breaks]
    return "FAIL", [f"rupture de schéma sans changement de apiVersion ({api_version(new)}) :", *breaks]


def _git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, check=False)


def tracked_files(root):
    res = _git(root, "ls-files", "-co", "--exclude-standard")
    if res.returncode == 0:
        return [f for f in res.stdout.splitlines() if (root / f).is_file()]
    return sorted(str(p.relative_to(root)) for p in root.rglob("*") if p.is_file() and ".git" not in p.parts)


def is_manifest(path):
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False
    return bool(API_RE.search(text) and KIND_RE.search(text))


def stray_manifests(root, files):
    """Fichiers YAML portant un objet Kubernetes hors des dossiers autorisés."""
    return [f for f in files if f.endswith(MANIFEST_EXT) and not f.startswith(ALLOWED_DIRS) and is_manifest(root / f)]


def declared_alone(root, files):
    """(apps déclarées par app.yaml seul, apps au total) ; les dossiers `_*` ne sont pas des apps."""
    apps = {}
    for f in files:
        parts = f.split("/")
        if len(parts) >= 3 and parts[0] == "apps" and not parts[1].startswith("_"):
            apps.setdefault(parts[1], []).append(f)
    total = {a: fs for a, fs in apps.items() if f"apps/{a}/app.yaml" in fs}

    def extra(a, fs):
        return [f for f in fs if f.endswith(MANIFEST_EXT) and f != f"apps/{a}/app.yaml"
                and f.rsplit("/", 1)[1] != "values.yaml" and is_manifest(root / f)]

    return sum(1 for a, fs in total.items() if not extra(a, fs)), len(total)


def base_schema(root, ref, base_file):
    """(schéma de la base, None) ; ({}, None) si absent de la base ; (None, raison) si la base est introuvable."""
    if base_file:
        return json.loads(Path(base_file).read_text(encoding="utf-8")), None
    if _git(root, "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}").returncode != 0:
        return None, f"base {ref} introuvable"
    base = _git(root, "merge-base", ref, "HEAD").stdout.strip() or ref
    res = _git(root, "show", f"{base}:{SCHEMA_REL}")
    return (json.loads(res.stdout) if res.returncode == 0 else {}), None


def run_schema(root, args):
    old, why = base_schema(root, args.base, args.base_schema)
    if old is None:
        print(f"NOT_TESTED schéma : {why}")
        return 125
    if not old:
        print("PASS schéma : absent de la base, rien à comparer")
        return 0
    status, details = check_schema(old, json.loads((root / SCHEMA_REL).read_text(encoding="utf-8")))
    print(f"{status} schéma : {details[0]}")
    for d in details[1:]:
        print(f"  - {d}")
    return 1 if status == "FAIL" else 0


def run_manifests(root):
    files = tracked_files(root)
    stray = stray_manifests(root, files)
    print(f"{'FAIL' if stray else 'PASS'} manifestes : {len(stray)} objet(s) Kubernetes hors {', '.join(ALLOWED_DIRS)}")
    for f in stray:
        print(f"  - {f}")
    alone, total = declared_alone(root, files)
    pct = 100 * alone / total if total else 0
    print(f"INDICATEUR apps-app-yaml-seul : {alone}/{total} ({pct:.0f} %, cible 90 %)")
    return 1 if stray else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=".")
    ap.add_argument("--base", default="origin/main")
    ap.add_argument("--base-schema")
    ap.add_argument("--only", choices=("schema", "manifests"))
    args = ap.parse_args(argv)
    root = Path(args.root).resolve()
    rcs = []
    if args.only != "manifests":
        rcs.append(run_schema(root, args))
    if args.only != "schema":
        rcs.append(run_manifests(root))
    return 1 if 1 in rcs else (125 if 125 in rcs else 0)


if __name__ == "__main__":
    sys.exit(main())
