#!/usr/bin/env python3
"""Inventaire des identités et matrice identité x catégories de secrets (T-183).

Usage :
  python3 -I tools/identity-inventory/inventory.py            valide l'inventaire et vérifie la matrice de docs/IDENTITY.md
  python3 -I tools/identity-inventory/inventory.py --write    régénère la matrice de docs/IDENTITY.md
  python3 -I tools/identity-inventory/inventory.py --print    affiche la matrice

Refus (code 1) : schéma identity-inventory.v1, valeur ressemblant à un secret, identité d'agent avec lecture de valeur,
plus d'un chemin d'élévation, élévation vers une identité inconnue ou en cycle, credential absent du registre ou sans
propriétaire ni échéance, écart dev sur un credential non `dev: true`, credential du registre non couvert par l'inventaire,
matrice du document différente de celle dérivée de l'inventaire. Les messages citent un chemin et une règle, jamais une valeur.
Avertissement (code 0) : échéance dépassée.
"""

from __future__ import annotations

import argparse
import datetime
import json
import sys
from pathlib import Path
from typing import Any

import jsonschema
import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "backlog"))
import identities_lint as registry_lint  # noqa: E402

INVENTORY = ROOT / "identities" / "inventory.yaml"
SCHEMA = ROOT / "identities" / "schema" / "inventory.v1.json"
REGISTRY = ROOT / "docs" / "state" / "identities.yaml"
DOC = ROOT / "docs" / "IDENTITY.md"
BEGIN = "<!-- BEGIN identity-inventory : généré par tools/identity-inventory/inventory.py --write, ne pas éditer -->"
END = "<!-- END identity-inventory -->"
VALUE_READ = {"valeur", "valeur-break-glass"}
AGENT_TYPES = {"agent"}
CELL = {"presence": "P", "creation": "C", "ecriture": "E", "valeur": "V", "valeur-break-glass": "V!"}


def load_yaml(path: Path) -> Any:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=registry_lint._StrLoader)


def schema_errors(data: Any) -> list[str]:
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    errs = sorted(jsonschema.Draft202012Validator(schema).iter_errors(data), key=lambda e: list(map(str, e.absolute_path)))
    return [f"schéma {'/'.join(map(str, e.absolute_path)) or '(racine)'}: {e.validator}" for e in errs]


def value_errors(data: Any, raw: str) -> list[str]:
    errs = [f"{path}: valeur interdite ({rule})" for path, s in registry_lint.walk(data) for rule in registry_lint.scan_text(s)]
    for ln, line in enumerate(raw.splitlines(), 1):
        errs += [f"ligne {ln}: texte interdit ({rule})" for rule in registry_lint.scan_text(line)]
    return errs


def identity_errors(ident: dict, ids: set[str], categories: set[str]) -> list[str]:
    """Règles par identité : catégories connues, aucun agent lecteur de valeur, un seul chemin d'élévation."""
    iid = ident["id"]
    errs = [f"{iid}: catégorie inconnue {c}" for c in ident["secrets"] if c not in categories]
    if ident["type"] in AGENT_TYPES:
        errs += [f"{iid}: identité d'agent avec lecture de valeur sur {c}" for c, a in ident["secrets"].items() if a in VALUE_READ]
    paths = ident["elevation"]
    if len(paths) > 1:
        errs.append(f"{iid}: {len(paths)} chemins d'élévation (au plus 1)")
    for p in paths:
        if p["to"] == iid or p["to"] not in ids:
            errs.append(f"{iid}: élévation vers une identité inconnue ou vers elle-même ({p['to']})")
    return errs


def cycle_errors(identities: list[dict]) -> list[str]:
    nxt = {i["id"]: [p["to"] for p in i["elevation"]] for i in identities}
    errs = []
    for start in nxt:
        seen, cur = {start}, nxt[start]
        while cur:
            node = cur[0]
            if node == start:
                errs.append(f"{start}: cycle d'élévation")
                break
            if node in seen or node not in nxt:
                break
            seen.add(node)
            cur = nxt[node]
    return errs


def credential_errors(ident: dict, registry: dict[str, dict]) -> list[str]:
    """Chaque credential référencé existe, a un propriétaire, une échéance, et ce consommateur ; un écart dev est `dev: true`."""
    iid, errs = ident["id"], []
    mine = set(ident.get("registry_consumers", []))
    for field in ("credentials", "dev_deviations"):
        for name in ident.get(field, []):
            entry = registry.get(name)
            if entry is None:
                errs.append(f"{iid}: {field} {name} absent du registre")
                continue
            if not entry.get("owner") or not entry.get("rotate_by"):
                errs.append(f"{iid}: credential {name} sans propriétaire ou sans échéance")
            if not mine & set(entry.get("consumers", [])):
                errs.append(f"{iid}: credential {name} sans consommateur commun avec registry_consumers")
            if field == "dev_deviations" and entry.get("dev") is not True:
                errs.append(f"{iid}: écart dev {name} non marqué dev: true dans le registre")
    return errs


def coverage_errors(identities: list[dict], registry: dict[str, dict]) -> list[str]:
    """Tout credential du registre est porté, pour chacun de ses consommateurs, par une identité de l'inventaire."""
    held: dict[str, set[str]] = {}
    for i in identities:
        names = set(i.get("credentials", [])) | set(i.get("dev_deviations", []))
        for consumer in i.get("registry_consumers", []):
            held.setdefault(consumer, set()).update(names)
    return [
        f"registre {name}: consommateur {c} non couvert par l'inventaire"
        for name, entry in sorted(registry.items())
        for c in entry.get("consumers", [])
        if name not in held.get(c, set())
    ]


def registry_index(registry: Any) -> dict[str, dict]:
    items = registry.get("identities", []) if isinstance(registry, dict) else []
    return {e["name"]: e for e in items if isinstance(e, dict) and "name" in e}


def lint(inventory: Path = INVENTORY, registry_path: Path = REGISTRY) -> list[str]:
    raw = inventory.read_text(encoding="utf-8")
    try:
        data = load_yaml(inventory)
    except yaml.YAMLError as e:
        return [f"YAML invalide ({type(e).__name__})"]
    errs = schema_errors(data) + value_errors(data, raw)
    if errs:
        return sorted(set(errs))
    identities = data["identities"]
    ids = [i["id"] for i in identities]
    errs += [f"{i}: identifiant en double" for i in sorted({i for i in ids if ids.count(i) > 1})]
    categories = {c["id"] for c in data["categories"]}
    registry = registry_index(load_yaml(registry_path))
    for ident in identities:
        errs += identity_errors(ident, set(ids), categories) + credential_errors(ident, registry)
    errs += cycle_errors(identities) + coverage_errors(identities, registry)
    return sorted(set(errs))


def warnings(data: dict, today: datetime.date) -> list[str]:
    return [f"{i['id']}: échéance {i['expires']} dépassée" for i in data["identities"] if i["expires"] < today.isoformat()]


def render(data: dict) -> str:
    """Matrice dérivée de l'inventaire : attributs, puis identité x catégories."""
    cats = data["categories"]
    out = [BEGIN, "", "| Identité | Type | Statut | Authentification | Durée | Propriétaire | Échéance | Élévation | Écarts dev |",
           "|---|---|---|---|---|---|---|---|---|"]
    for i in data["identities"]:
        elev = ", ".join(f"{p['to']} ({p['class']})" for p in i["elevation"]) or "—"
        dev = ", ".join(f"`{d}`" for d in i.get("dev_deviations", [])) or "—"
        out.append(f"| `{i['id']}` | {i['type']} | {i['status']} | {i['authentication']} | {i['token_ttl']} | {i['owner']} "
                   f"| {i['expires']} | {elev} | {dev} |")
    out += ["", "| Identité | " + " | ".join(c["short"] for c in cats) + " |", "|---|" + "---|" * len(cats)]
    for i in data["identities"]:
        out.append(f"| `{i['id']}` | " + " | ".join(CELL.get(i["secrets"].get(c["id"], ""), "—") for c in cats) + " |")
    out += ["", "Légende : P présence, C création sans lecture, E écriture ou synchronisation, V lecture de valeur, "
            "V! lecture d'urgence auditée (break-glass), — aucun accès.", "",
            "Catégories : " + " ; ".join(f"{c['short']} = {c['description']}" for c in cats) + ".", "", END]
    return "\n".join(out)


def doc_section(text: str) -> str | None:
    if BEGIN not in text or END not in text:
        return None
    return text[text.index(BEGIN): text.index(END) + len(END)]


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--inventory", type=Path, default=INVENTORY)
    ap.add_argument("--registry", type=Path, default=REGISTRY)
    ap.add_argument("--doc", type=Path, default=DOC)
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--print", action="store_true")
    args = ap.parse_args(argv)
    errs = lint(args.inventory, args.registry)
    for e in errs:
        print("ERREUR", e)
    if errs:
        return 1
    data = load_yaml(args.inventory)
    for w in warnings(data, datetime.date.today()):
        print("AVERTISSEMENT", w)
    table = render(data)
    if args.print:
        print(table)
        return 0
    text = args.doc.read_text(encoding="utf-8")
    current = doc_section(text)
    if current is None:
        print(f"ERREUR {args.doc.name}: marqueurs de la matrice absents")
        return 1
    if args.write:
        args.doc.write_text(text.replace(current, table), encoding="utf-8")
        print(f"OK {args.doc.name}: matrice régénérée ({len(data['identities'])} identités)")
        return 0
    if current != table:
        print(f"ERREUR {args.doc.name}: matrice différente de l'inventaire (relancer avec --write)")
        return 1
    print(f"OK inventaire : {len(data['identities'])} identités, matrice de {args.doc.name} à jour")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
