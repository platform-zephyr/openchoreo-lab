#!/usr/bin/env python3
"""Extrait le schema openAPIV3Schema de chaque CRD (dossier config/crd/bases) en JSON Schema autonome.

Sortie : <out>/<group>/<kind en minuscules>_<version>.json (kubeconform met ResourceKind en minuscules ; sensible a la casse sous Linux), nommage attendu par kubeconform
(-schema-location '<out>/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json').
Les regles CEL (x-kubernetes-validations) ne sont pas evaluees ici : seul l'API server les applique.
"""
import argparse
import json
import sys
from pathlib import Path

import yaml


def convert(crd_dir: Path, out: Path) -> int:
    written = 0
    for path in sorted(crd_dir.glob("*.yaml")):
        crd = yaml.safe_load(path.read_text(encoding="utf-8"))
        if not isinstance(crd, dict) or crd.get("kind") != "CustomResourceDefinition":
            continue
        group = crd["spec"]["group"]
        kind = crd["spec"]["names"]["kind"]
        for version in crd["spec"]["versions"]:
            schema = dict(version["schema"]["openAPIV3Schema"])
            schema["$schema"] = "http://json-schema.org/draft-07/schema#"
            target = out / group / f"{kind.lower()}_{version['name']}.json"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps(schema, indent=1, sort_keys=True), encoding="utf-8")
            written += 1
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("crd_dir", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    n = convert(args.crd_dir, args.out)
    print(f"crd2schema : {n} schema(s) ecrits sous {args.out}")
    return 0 if n else 1


if __name__ == "__main__":
    sys.exit(main())
