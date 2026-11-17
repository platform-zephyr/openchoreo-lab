#!/usr/bin/env python3
"""Ajoute aux manifests générés les annotations Argo exigées par APP-CONTRACT §5 (simule la correction appgen n°2).

Usage : annotate_syncopts.py <dossier generated/>. Idempotent. Ne touche qu'aux kinds :
  Component, Resource      -> argocd.argoproj.io/sync-options: Prune=false
  ComponentRelease         -> argocd.argoproj.io/sync-options: Prune=false,Delete=false
Texte modifié en place (commentaires conservés). Utilisé UNIQUEMENT dans le dépôt de test gl-repo.
"""
import pathlib
import re
import sys

OPTS = {"Component": "Prune=false", "Resource": "Prune=false", "ComponentRelease": "Prune=false,Delete=false"}
KEY = "argocd.argoproj.io/sync-options"


def main(root: str) -> int:
    n = 0
    for p in sorted(pathlib.Path(root).rglob("*.yaml")):
        s = p.read_text()
        m = re.search(r"^kind: (\S+)$", s, re.M)
        if not m or m.group(1) not in OPTS or KEY in s:
            continue
        line = f"    {KEY}: {OPTS[m.group(1)]}\n"
        if re.search(r"^metadata:\n(?:  .*\n)*?  annotations:\n", s, re.M):
            s = re.sub(r"(^metadata:\n(?:  .*\n)*?  annotations:\n)", r"\g<1>" + line, s, count=1, flags=re.M)
        else:
            s = re.sub(r"(^metadata:\n)", r"\g<1>  annotations:\n" + line, s, count=1, flags=re.M)
        p.write_text(s)
        n += 1
    print(f"annotate_syncopts: {n} fichier(s) annoté(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
