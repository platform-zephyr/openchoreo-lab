#!/usr/bin/env python3
"""Adapte l'Environment `production` au banc k3d (étape T-DEPLOY de run.sh), de façon idempotente.

Usage : patch_env.py <40-openchoreo-env.yaml>   (le fichier est modifié en place ; verdict sur stdout)

Contexte (T-458) : la correction G1 (`gateway.ingress.internal`, hôte `lab.internal`) est dans `main`. L'ancienne
version cherchait la chaîne `  isProduction: true\n---` et échouait (assert) dès que G1 était présente. Règle actuelle,
sans ancre de texte à deviner :
  - `internal` absent  -> ajouté avec l'hôte k3d (verdict `added`) ;
  - `internal` présent -> inchangé (verdict `noop`). Le run 44313410652 (2026-11-18) a prouvé qu'un changement
    d'hôte sur un Environment déjà rendu n'est pas re-rendu (route restée sur `lab.internal` 5 min) : run.sh lit
    donc l'hôte réel de la HTTPRoute au lieu de forcer un hôte.
Sortie : `added` ou `noop`. Code 1 si le document Environment est introuvable ou si le résultat ne contient pas
de `gateway.ingress.internal.http.host` (jamais de succès silencieux).
"""
from __future__ import annotations

import re
import sys

import yaml

K3D_HOST = "internal.localhost"
K3D_PORT = 19080
INTERNAL_BLOCK = f"""      internal:
        name: gateway-default
        namespace: openchoreo-data-plane
        http:
          host: {K3D_HOST}
          listenerName: http
          port: {K3D_PORT}
"""


def _env_doc(docs: list[str]) -> int:
    for i, d in enumerate(docs):
        if re.search(r"^kind: Environment$", d, re.M) and re.search(r"^  name: production$", d, re.M):
            return i
    raise ValueError("document Environment `production` introuvable")


def _internal_host(doc: str):
    spec = yaml.safe_load(doc).get("spec", {})
    return (((spec.get("gateway") or {}).get("ingress") or {}).get("internal") or {}).get("http", {}).get("host")


def patch(text: str) -> tuple[str, str]:
    """Retourne (texte, verdict). Lève ValueError si l'Environment est introuvable ou le résultat invalide."""
    docs = re.split(r"(?m)^---\n", text)
    i = _env_doc(docs)
    d = docs[i]
    host = _internal_host(d)
    if host is not None:
        return text, "noop"
    if re.search(r"^    ingress:\n", d, re.M):
        new = re.sub(r"(?m)^(    ingress:\n)", lambda m: m.group(1) + INTERNAL_BLOCK, d, count=1)
        verdict = "added"
    elif re.search(r"^  gateway:\n", d, re.M):
        new = re.sub(r"(?m)^(  gateway:\n)", lambda m: m.group(1) + "    ingress:\n" + INTERNAL_BLOCK, d, count=1)
        verdict = "added"
    else:
        new = d.rstrip("\n") + "\n  gateway:\n    ingress:\n" + INTERNAL_BLOCK
        verdict = "added"
    if _internal_host(new) is None:
        raise ValueError("résultat sans gateway.ingress.internal.http.host")
    docs[i] = new if new.endswith("\n") else new + "\n"
    return "---\n".join(docs), verdict


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage : patch_env.py <fichier>", file=sys.stderr)
        return 2
    try:
        with open(argv[1], encoding="utf-8") as f:
            text = f.read()
        out, verdict = patch(text)
    except (OSError, ValueError, yaml.YAMLError) as e:
        print(f"ECHEC : {e}", file=sys.stderr)
        return 1
    if out != text:
        with open(argv[1], "w", encoding="utf-8") as f:
            f.write(out)
    print(verdict)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
