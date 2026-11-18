#!/usr/bin/env python3
"""Compare un ruleset voulu (JSON versionné) à l'état lu sur GitHub.

Usage : ruleset_diff.py VOULU.json LU.json
Sortie : une ligne par écart ; code 0 = conforme, 1 = dérive, 3 = état non comparable (lecture sans droit admin).

Sémantique : les clés ajoutées par l'API (id, dates, _links, paramètres par défaut) sont ignorées ; toute clé du JSON
voulu doit exister et valoir pareil. Les listes ont la même longueur (un bypass ou une règle en trop est une dérive).
Aucune valeur secrète n'est lue ni écrite : un ruleset n'en contient pas.
"""
import json
import sys


def match(want, got, path, out):
    if isinstance(want, dict):
        if not isinstance(got, dict):
            out.append(f"{path}: attendu objet, lu {got!r}")
            return
        for k, v in want.items():
            if k not in got:
                out.append(f"{path}.{k}: absent (attendu {v!r})")
            else:
                match(v, got[k], f"{path}.{k}", out)
    elif isinstance(want, list):
        if not isinstance(got, list):
            out.append(f"{path}: attendu liste, lu {got!r}")
            return
        if len(want) != len(got):
            out.append(f"{path}: {len(got)} élément(s) lu(s), {len(want)} attendu(s)")
        # Chaque élément voulu doit correspondre à un élément lu distinct (ordre libre).
        pool = list(got)
        for i, w in enumerate(want):
            for j, g in enumerate(pool):
                sub = []
                match(w, g, f"{path}[{i}]", sub)
                if not sub:
                    del pool[j]
                    break
            else:
                out.append(f"{path}[{i}]: aucun élément lu ne correspond à {w!r}")
    elif want != got:
        out.append(f"{path}: lu {got!r}, attendu {want!r}")


def main(argv):
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as f:
        want = json.load(f)
    with open(argv[2], encoding="utf-8") as f:
        got = json.load(f)
    if "bypass_actors" in want and "bypass_actors" not in got:
        print("NOT_TESTED: bypass_actors absent de l'état lu (jeton sans droit admin)")
        return 3
    out = []
    match(want, got, "$", out)
    for line in out:
        print("DERIVE", line)
    return 1 if out else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
