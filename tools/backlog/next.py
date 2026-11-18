#!/usr/bin/env python3
"""Dispatcher minimal (T-210) : liste les tickets prêts, sortie JSON stable `ready.v1`.

Lecture seule : ne lance aucun agent, n'écrit aucun fichier. Paul (workflow_dispatch) lance la liste.
La classe, le modèle et l'effort sont recalculés depuis les chemins du périmètre (admission.py).

Usage :
  python3 tools/backlog/next.py [--limit N] [--open-stage S1]
  python3 tools/backlog/next.py --overlap-report T-002,T-214,...
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from graphlib import CycleError, TopologicalSorter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import admission  # noqa: E402
import priority

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "ready.v1"
STAGES = ["S0", "S1", "S2", "S3", "PORTE", "FINAL0", "I1", "I1bis", "I2", "I3", "I4", "I5", "I6", "I7", "I8",
          "FINAL", "I9", "après-porte"]  # même ordre que check.py
STAGE_ORD = {s: n for n, s in enumerate(STAGES)}
ACTIVE = ("todo", "in-progress")

Ticket = dict[str, object]


# --------------------------------------------------------------------------- lecture


def _header(text: str) -> dict[str, str]:
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    out: dict[str, str] = {}
    if not m:
        return out
    for line in m.group(1).splitlines():
        k, sep, v = line.partition(":")
        if sep:
            out[k.strip()] = re.sub(r"\s+#.*$", "", v).strip().strip('"')
    return out


def _perimeter(text: str) -> list[str]:
    m = re.search(r"^## Périmètre de fichiers\s*\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    if not m:
        return []
    body = " ".join(line.strip() for line in m.group(1).splitlines() if line.strip())
    return admission.parse_perimeter(body)


def load_tickets(backlog: Path) -> dict[str, Ticket]:
    tickets: dict[str, Ticket] = {}
    for f in sorted(backlog.glob("T-*.md")):
        text = f.read_text(encoding="utf-8")
        h = _header(text)
        if "id" not in h:
            continue
        deps = [d.strip() for d in h.get("depends_on", "[]").strip("[]").split(",") if d.strip()]
        tickets[h["id"]] = {
            "id": h["id"], "title": h.get("title", ""), "status": h.get("status", ""),
            "stage": h.get("stage", ""), "lane": h.get("lane", ""), "deps": deps,
            "velocity": h.get("velocity") == "true", "header_class": h.get("class", ""),
            "header_model": h.get("model", ""), "header_effort": h.get("effort", ""),
            "perimeter": _perimeter(text),
        }
    return tickets


# --------------------------------------------------------------------------- calcul


def ready_ids(tickets: dict[str, Ticket]) -> set[str]:
    """Tickets `todo` dont toutes les dépendances sont `done` (graphlib, lève CycleError sur un cycle)."""
    graph = {i: [d for d in t["deps"] if d in tickets] for i, t in tickets.items() if t["status"] != "dropped"}  # type: ignore[union-attr]
    for i, t in tickets.items():
        if any(d not in tickets for d in t["deps"]):  # type: ignore[union-attr]
            graph.setdefault(i, []).append(f"?absent:{i}")  # dépendance inconnue : jamais prêt
    ts: TopologicalSorter[str] = TopologicalSorter(graph)
    ts.prepare()
    ready: set[str] = set()
    while ts.is_active():
        batch = ts.get_ready()
        if not batch:
            break
        progressed = False
        for n in batch:
            t = tickets.get(n)
            if t is not None and t["status"] == "done":
                ts.done(n)
                progressed = True
            elif t is not None and t["status"] == "todo":
                ready.add(n)
        if not progressed:
            break
    return ready


def open_stage(tickets: dict[str, Ticket]) -> str:
    """Étape la plus basse qui a encore du travail non bloqué par un geste humain."""
    stages = [t["stage"] for t in tickets.values()
              if t["status"] in ACTIVE and t["header_model"] != "human" and "MANDAT" not in t["header_class"]]  # type: ignore[operator]
    return min(stages, key=lambda s: STAGE_ORD.get(s, 99)) if stages else ""  # type: ignore[arg-type]


def _sort_key(t: Ticket) -> tuple[int, int, str]:
    return (STAGE_ORD.get(t["stage"], 99), 0 if t["velocity"] else 1, t["id"])  # type: ignore[arg-type]


def _priority_keys(tickets: dict[str, Ticket]) -> dict[str, tuple]:
    """Clé de tri (priority.py) et score de chaque ticket ; graphe invalide : repli sur `_sort_key`, score nul."""
    nodes = [priority.Node(i, str(t["status"]), tuple(t["deps"]), str(t["stage"]),  # type: ignore[arg-type]
                           t["header_model"] != "human" and "MANDAT" not in t["header_class"],  # type: ignore[operator]
                           len(t["perimeter"]))  # type: ignore[arg-type]
             for i, t in tickets.items()]
    try:
        sc = priority.scores(nodes)
    except priority.PriorityError:
        return {i: (*_sort_key(t), None) for i, t in tickets.items()}  # type: ignore[arg-type]
    return {n.id: (*priority.sort_key(n, sc[n.id]), sc[n.id]) for n in nodes}


def compute(tickets: dict[str, Ticket], core: admission.Core, limit: int | None = None,
            stage_open: str | None = None) -> dict[str, object]:
    ready = ready_ids(tickets)
    stage_open = stage_open if stage_open is not None else open_stage(tickets)
    limit_ord = STAGE_ORD.get(stage_open, 99)
    taken: list[tuple[str, list[str]]] = [(i, t["perimeter"]) for i, t in tickets.items()  # type: ignore[misc]
                                         if t["status"] == "in-progress"]
    proposed: list[Ticket] = []
    held: list[dict[str, object]] = []
    excluded: list[dict[str, object]] = []
    keys = _priority_keys(tickets)
    for tid in sorted(ready, key=keys.__getitem__):
        t = tickets[tid]
        paths: list[str] = t["perimeter"]  # type: ignore[assignment]
        reason = None
        if t["header_model"] == "human" or "MANDAT" in t["header_class"]:  # type: ignore[operator]
            reason = "geste-humain-en-attente"
        elif STAGE_ORD.get(t["stage"], 99) > limit_ord:  # type: ignore[arg-type]
            reason = f"etape-fermee:{t['stage']}"
        elif not paths:
            reason = "perimetre-vide"
        elif admission.refused_paths(paths):
            reason = "chemin-refuse:" + ",".join(admission.refused_paths(paths))
        if reason:
            excluded.append({"id": tid, "reason": reason})
            continue
        clash = next(((o, hit) for o, ps in taken if (hit := admission.any_overlap(paths, ps))), None)
        if clash:
            held.append({"id": tid, "conflicts_with": clash[0], "globs": list(clash[1])})
            continue
        routing, model, effort = admission.resolve_model(
            paths, t["stage"], t["header_model"], t["header_effort"], core)  # type: ignore[arg-type]
        taken.append((tid, paths))
        proposed.append({
            "id": tid, "title": t["title"], "stage": t["stage"], "lane": t["lane"],
            "class": admission.compute_class(paths, core), "model": model, "effort": effort,
            "routing": routing, "perimeter": paths, "score": keys[tid][-1],
        })
        if limit is not None and len(proposed) >= limit:
            break
    ready_set = {p["id"] for p in proposed}
    for p in proposed:
        p["unblocks"] = sorted(
            i for i, t in tickets.items()
            if t["status"] == "todo" and p["id"] in t["deps"]  # type: ignore[operator]
            and all(d == p["id"] or tickets.get(d, {}).get("status") == "done" for d in t["deps"])  # type: ignore[union-attr]
        )
    return {"schema": SCHEMA, "open_stage": stage_open, "ready": proposed,
            "held_overlap": held, "excluded": excluded,
            "in_progress": sorted(i for i, _ in taken if i not in ready_set and tickets[i]["status"] == "in-progress")}


def _reaches(tickets: dict[str, Ticket], src: str, dst: str) -> bool:
    seen, stack = set(), [src]
    while stack:
        n = stack.pop()
        if n == dst:
            return True
        if n in seen or n not in tickets:
            continue
        seen.add(n)
        stack.extend(tickets[n]["deps"])  # type: ignore[arg-type]
    return False


def overlap_report(tickets: dict[str, Ticket], ids: list[str]) -> dict[str, object]:
    """Recoupements de globs entre tickets ; `serialized` = ordonnés par une dépendance (transitive)."""
    pairs = []
    for n, a in enumerate(ids):
        for b in ids[n + 1:]:
            hit = admission.any_overlap(tickets[a]["perimeter"], tickets[b]["perimeter"])  # type: ignore[arg-type]
            if hit:
                ser = _reaches(tickets, a, b) or _reaches(tickets, b, a)
                pairs.append({"a": a, "b": b, "globs": list(hit), "serialized": ser})
    return {"schema": "overlap.v1", "tickets": ids, "pairs": pairs,
            "unserialized": [p for p in pairs if not p["serialized"]]}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--backlog", type=Path, default=ROOT / "backlog")
    ap.add_argument("--codeowners", type=Path, default=ROOT / ".github" / "CODEOWNERS")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--open-stage")
    ap.add_argument("--overlap-report", help="liste d'identifiants séparés par des virgules")
    args = ap.parse_args(argv)
    tickets = load_tickets(args.backlog)
    core = admission.load_core(args.codeowners)
    try:
        if args.overlap_report:
            ids = [i.strip() for i in args.overlap_report.split(",") if i.strip()]
            missing = [i for i in ids if i not in tickets]
            if missing:
                print("ticket inconnu : " + ",".join(missing), file=sys.stderr)
                return 2
            out = overlap_report(tickets, ids)
        else:
            out = compute(tickets, core, args.limit, args.open_stage)
    except CycleError as e:
        print(f"cycle de dépendances : {e.args[1]}", file=sys.stderr)
        return 2
    print(json.dumps(out, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
