#!/usr/bin/env python3
"""Score de priorité du backlog (T-476) : combien de tickets ce ticket débloque-t-il ?

Formule (déterministe, stdlib seule) :
  score = nombre de tickets NON `done` et NON `dropped` qui dépendent de lui, directement ou transitivement
          (descendants dans `depends_on`).
  Ordre de la file des agents : (1) exécutable par un agent d'abord (`model: human` ou classe MANDAT = rétrogradé),
  (2) score décroissant, (3) étape (S0 < S1 …), (4) périmètre le plus petit, (5) identifiant naturel.
Pourquoi : sur un graphe de dépendances, le chemin critique borne la durée totale (CPM, Kelley et Walker, 1959) ;
compter les descendants en est la mesure la plus simple, sans estimation de valeur ni de taille que ce backlog n'a
pas (WSJF et RICE exigent des notes subjectives : scaledagileframework.com/wsjf ;
intercom.com/blog/rice-simple-prioritization-for-product-managers). Même idée que le coefficient `blocking` de
l'urgence de Taskwarrior. Dépendance inconnue ou cycle : `PriorityError`.

Statut : statut DÉRIVÉ (`derive.py` : cases cochées + PR fusionnée dans main lue dans l'historique git local), pas le
champ `status:` saisi à la main, sauf pour `blocked`, `deferred`, `dropped` (décisions manuelles) ou sans historique git.

Usage : python3 tools/backlog/priority.py [--top N] [--json] [--all] [--diff]
  par défaut : tickets `todo` prêts (dépendances toutes `done`) ; --all : tous les tickets non terminés ;
  --diff : tickets dont le statut dérivé diffère de l'en-tête.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections.abc import Iterable
from dataclasses import dataclass
from graphlib import CycleError, TopologicalSorter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check
import derive

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "priority.v1"
CLOSED = frozenset({"done", "dropped"})


class PriorityError(ValueError):
    """Graphe invalide : dépendance inconnue ou cycle."""


@dataclass(frozen=True)
class Node:
    id: str
    status: str
    deps: tuple[str, ...] = ()
    stage: str = ""
    executable: bool = True  # False : geste humain (`model: human`) ou classe MANDAT
    scope_size: int = 0
    declared: str = ""  # champ `status:` de l'en-tête (le statut utilisé est `status`, dérivé)


def natural_key(tid: str) -> tuple[str, int, str]:
    m = re.match(r"^(\D*)(\d+)(.*)$", tid)
    return (m.group(1), int(m.group(2)), m.group(3)) if m else (tid, 0, "")


def descendants(nodes: Iterable[Node]) -> dict[str, set[str]]:
    """Descendants (dépendants transitifs) de chaque ticket ; lève PriorityError sur inconnue ou cycle."""
    by_id = {n.id: n for n in nodes}
    for n in by_id.values():
        unknown = [d for d in n.deps if d not in by_id]
        if unknown:
            raise PriorityError(f"{n.id} : dépendance inconnue {', '.join(unknown)}")
    try:
        order = list(TopologicalSorter({i: n.deps for i, n in by_id.items()}).static_order())
    except CycleError as e:
        raise PriorityError("cycle de dépendances : " + " -> ".join(e.args[1])) from e
    desc: dict[str, set[str]] = {i: set() for i in by_id}
    for i in reversed(order):  # dépendants avant leurs dépendances
        for d in by_id[i].deps:
            desc[d] |= desc[i] | {i}
    return desc


def scores(nodes: Iterable[Node]) -> dict[str, int]:
    """Score de chaque ticket : descendants ni `done` ni `dropped`."""
    nodes = list(nodes)
    status = {n.id: n.status for n in nodes}
    return {i: sum(status[d] not in CLOSED for d in ds) for i, ds in descendants(nodes).items()}


def stage_order(stage: str) -> int:
    return check.STAGE_ORDER.get(stage, len(check.STAGES))


def sort_key(n: Node, score: int) -> tuple[int, int, int, int, tuple[str, int, str]]:
    return (0 if n.executable else 1, -score, stage_order(n.stage), n.scope_size, natural_key(n.id))


def rank(nodes: Iterable[Node], only: set[str] | None = None) -> list[tuple[Node, int]]:
    """Tickets classés (meilleur d'abord) ; `only` restreint aux identifiants donnés."""
    nodes = list(nodes)
    sc = scores(nodes)
    picked = [n for n in nodes if only is None or n.id in only]
    return sorted(((n, sc[n.id]) for n in picked), key=lambda p: sort_key(*p))


def ready_ids(nodes: Iterable[Node]) -> set[str]:
    nodes = list(nodes)
    status = {n.id: n.status for n in nodes}
    return {n.id for n in nodes if n.status == "todo" and all(status.get(d) == "done" for d in n.deps)}


def load_nodes(backlog: Path, evidence: derive.Evidence | None = None) -> list[Node]:
    """Tickets du backlog avec leur statut dérivé ; `evidence` : historique git (défaut : dépôt parent du backlog)."""
    ev = evidence if evidence is not None else derive.collect(backlog.resolve().parent)
    nodes = []
    for f in sorted(backlog.glob("T-*.md")):
        t = check.parse_ticket(f)
        if t.errors or not t.get("id"):
            continue
        good, _ = check.scope_paths(t.body)
        st = derive.derive(t.id, t.status, check.section(t.body, "Critères de fin"), ev, t.get("github_issue"))
        nodes.append(Node(t.id, st, tuple(t.deps), t.get("stage"),
                          t.get("model") != "human" and "MANDAT" not in t.get("class"), len(good), t.status))
    return nodes


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--backlog", type=Path, default=ROOT / "backlog")
    ap.add_argument("--top", type=int, help="limite le nombre de lignes")
    ap.add_argument("--json", action="store_true", help="sortie JSON `priority.v1`")
    ap.add_argument("--all", action="store_true", help="tous les tickets non terminés, pas seulement les prêts")
    ap.add_argument("--diff", action="store_true", help="tickets dont le statut dérivé diffère de l'en-tête")
    args = ap.parse_args(argv)
    nodes = load_nodes(args.backlog)
    if args.diff:
        for n in sorted((n for n in nodes if n.status != n.declared), key=lambda n: natural_key(n.id)):
            print(f"{n.id}  en-tête {n.declared:<11}  dérivé {n.status}")
        return 0
    try:
        only = {n.id for n in nodes if n.status not in CLOSED | {"deferred"}} if args.all else ready_ids(nodes)
        ranked = rank(nodes, only)
    except PriorityError as e:
        print(f"erreur : {e}", file=sys.stderr)
        return 2
    ranked = ranked[: args.top] if args.top else ranked
    if args.json:
        rows = [{"id": n.id, "score": s, "stage": n.stage, "executable": n.executable, "scope_size": n.scope_size,
                 "status": n.status, "declared": n.declared} for n, s in ranked]
        print(json.dumps({"schema": SCHEMA, "ranking": rows}, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print("rang  score  étape   agent  périmètre  ticket")
        for k, (n, s) in enumerate(ranked, 1):
            print(f"{k:>4}  {s:>5}  {n.stage:<6}  {'oui' if n.executable else 'non':<5}  {n.scope_size:>9}  {n.id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
