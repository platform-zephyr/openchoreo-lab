#!/usr/bin/env python3
"""Contrôle CI des tickets `backlog/T-*.md` (ADR-0012, ADR-0023).

Erreurs (code de sortie 1) : en-tête incomplet ou invalide, id dupliqué, statut/classe/phase/étape inconnus, ADR
inexistant, dépendance absente ou gelée, cycle, `model`/`effort` inconnus, ticket actif sans périmètre de fichiers
exploitable, ticket `done` avec une case de critère non cochée.
Avertissements (code 0) : `effort: max` sur Sonnet (plafond xhigh), ticket REVUE sur le noyau sans modèle Opus,
éléments de périmètre non exploitables dans un ticket qui en contient aussi d'exploitables.

Sans dépendance : l'en-tête est un sous-ensemble plat de YAML (`clé: valeur`), le graphe utilise `graphlib`.
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from graphlib import CycleError, TopologicalSorter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

STATUSES = {"todo", "in-progress", "blocked", "deferred", "done", "dropped"}
ACTIVE = {"todo", "in-progress"}
CLASSES = {"AUTONOME", "REVUE", "MANDAT"}
STAGES = ["S0", "S1", "S2", "S3", "PORTE", "FINAL0", "I1", "I1bis", "I2", "I3", "I4", "I5", "I6", "I7", "I8",
          "FINAL", "I9", "après-porte"]
STAGE_ORDER = {s: n for n, s in enumerate(STAGES)}
PHASE_RE = re.compile(r"^P[0-5]$")
# ADR-0023 : ID complet épinglé ou `human` (geste de Paul seul).
MODELS = {"claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5", "human"}
EFFORTS = {"low", "medium", "high", "xhigh", "max"}
REQUIRED = ["id", "title", "status", "phase", "adr", "depends_on", "class", "velocity", "lane", "stage"]
# Chemins du noyau hors CODEOWNERS (ADR-0023 règle R1).
EXTRA_CORE = ["docs/adr", "docs/review"]
PATH_RE = re.compile(r"^[\w.*?{}\[\]<>/-]+$")  # `<app>` : paramètre de chemin
# Périmètre hors de ce dépôt : accepté tel quel (aucun glob à contrôler).
OFF_REPO_MARKERS = ("hors de ce dépôt", "historique git")


@dataclass
class Ticket:
    path: Path
    head: dict[str, str]
    body: str
    errors: list[str] = field(default_factory=list)

    def get(self, key: str) -> str:
        return self.head.get(key, "")

    @property
    def id(self) -> str:
        return self.get("id") or self.path.stem

    @property
    def status(self) -> str:
        return self.get("status")

    @property
    def deps(self) -> list[str]:
        return parse_list(self.get("depends_on"))


def parse_list(value: str) -> list[str]:
    return [x.strip().strip("\"'") for x in value.strip().strip("[]").split(",") if x.strip()]


def parse_ticket(path: Path) -> Ticket:
    """Sépare l'en-tête (entre les deux `---`) du corps ; l'en-tête est lu ligne à ligne (`clé: valeur # commentaire`)."""
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not m:
        t = Ticket(path, {}, text)
        t.errors.append("en-tête `---` absent ou non fermé")
        return t
    head: dict[str, str] = {}
    for line in m.group(1).splitlines():
        km = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if km:
            value = re.sub(r"\s+#.*$", "", km.group(2)).strip()  # commentaire de fin de ligne
            head[km.group(1)] = value.strip("\"") if value.startswith('"') else value
    return Ticket(path, head, m.group(2))


def section(body: str, title: str) -> str:
    m = re.search(rf"^## {re.escape(title)}\s*\n(.*?)(?=^## |\Z)", body, re.S | re.M)
    return m.group(1) if m else ""


def split_scope(text: str) -> list[str]:
    """Éléments du périmètre séparés par des virgules hors parenthèses."""
    items, depth, cur = [], 0, ""
    for ch in text.replace("\n", " "):
        depth += (ch == "(") - (ch == ")")
        if ch == "," and depth == 0:
            items.append(cur)
            cur = ""
        else:
            cur += ch
    items.append(cur)
    return [i.strip() for i in items if i.strip()]


def scope_paths(body: str) -> tuple[list[str], list[str]]:
    """(chemins ou globs exploitables, éléments inexploitables) du périmètre de fichiers."""
    good, bad = [], []
    text = section(body, "Périmètre de fichiers")
    if any(m in text.lower() for m in OFF_REPO_MARKERS):
        return ["(hors dépôt)"], []
    for item in split_scope(text):
        token = re.sub(r"\s*\(.*?\)", "", item).strip().strip("`")
        (good if PATH_RE.match(token) and ("/" in token or "." in token) else bad).append(token or item)
    return [g.strip("/") for g in good], bad


def core_paths(root: Path) -> list[str]:
    """Noyau de confiance : lignes `/chemin @owner` de CODEOWNERS + docs/adr, docs/review."""
    paths = list(EXTRA_CORE)
    co = root / ".github" / "CODEOWNERS"
    if co.exists():
        for line in co.read_text(encoding="utf-8").splitlines():
            parts = line.split()
            if len(parts) >= 2 and parts[0].startswith("/") and parts[1].startswith("@"):
                paths.append(parts[0].strip("/"))
    return paths


def touches_core(paths: list[str], core: list[str]) -> bool:
    for p in paths:
        p = re.split(r"[*?{\[]", p)[0].strip("/")  # préfixe avant le premier joker
        for c in core:
            if p == c or p.startswith(c + "/") or c.startswith(p + "/") or (p == "" and c):
                return True
    return False


def adr_exists(root: Path, adr: str) -> bool:
    return any((root / "docs" / "adr").glob(f"{adr}-*.md")) or any((root / "docs" / "adr").glob(f"{adr}.md"))


@dataclass
class Result:
    errors: list[str]
    warnings: list[str]
    todo: int = 0
    depth: int = 0


def check(root: Path = ROOT) -> Result:
    """Contrôle tous les tickets de `root/backlog`."""
    errors: list[str] = []
    warns: list[str] = []
    tickets: dict[str, Ticket] = {}
    files = sorted((root / "backlog").glob("T-*.md"))
    if not files:
        return Result([f"ERREUR : aucun ticket trouvé sous {root / 'backlog'}"], [])
    core = core_paths(root)
    for f in files:
        t = parse_ticket(f)
        errors += [f"{f.name}: {e}" for e in t.errors]
        if t.errors:
            continue
        i = t.id
        if i in tickets:
            errors.append(f"ID-DUPLIQUÉ {i} ({f.name} et {tickets[i].path.name})")
            continue
        tickets[i] = t
        for k in REQUIRED:
            if k not in t.head:
                errors.append(f"CHAMP-ABSENT {i} {k}")
        if not f.name.startswith(i + "-") and f.stem != i:
            errors.append(f"NOM-FICHIER {i} ne correspond pas à {f.name}")
        errors += _check_values(root, t)
        errors += _check_model(t, warns, core)
        errors += _check_body(t, warns)
    errors += _check_graph(tickets)
    todo = [t for t in tickets.values() if t.status == "todo"]
    depth = _depth(tickets, todo)
    return Result(errors, warns, len(todo), depth)


def _check_values(root: Path, t: Ticket) -> list[str]:
    i, out = t.id, []
    if t.get("status") and t.status not in STATUSES:
        out.append(f"STATUT-INCONNU {i} {t.status}")
    if t.get("class"):
        for c in re.split(r"\s*\+\s*", t.get("class")):
            if c not in CLASSES:
                out.append(f"CLASSE-INCONNUE {i} {c}")
    if t.get("phase") and not PHASE_RE.match(t.get("phase")):
        out.append(f"PHASE-INCONNUE {i} {t.get('phase')}")
    if t.get("stage") and t.get("stage") not in STAGE_ORDER and not (t.status == "dropped" and t.get("stage") == "—"):
        out.append(f"ÉTAPE-INCONNUE {i} {t.get('stage')}")
    for a in parse_list(t.get("adr")):
        if not adr_exists(root, a):
            out.append(f"ADR-ABSENT {i} {a}")
    return out


def _check_model(t: Ticket, warns: list[str], core: list[str]) -> list[str]:
    """Routage ADR-0023 : model/effort obligatoires sur un ticket actif, valeurs connues, plafond Sonnet."""
    i, model, effort, out = t.id, t.get("model"), t.get("effort"), []
    if t.status in ACTIVE and (not model or not effort):
        return [f"MODEL-ABSENT {i}"]
    if not model:
        return out
    if model not in MODELS:
        return [f"MODEL-INCONNU {i} {model}"]
    if model == "human":
        if effort != "none":
            out.append(f"EFFORT {i} human => none")
    elif effort not in EFFORTS:
        out.append(f"EFFORT-INCONNU {i} {effort}")
    elif model == "claude-sonnet-5-5" and effort == "max":
        warns.append(f"EFFORT {i} sonnet plafonné à xhigh (max demandé)")
    if t.status in ACTIVE and "REVUE" in t.get("class") and model != "claude-opus-5-5":
        paths, _ = scope_paths(t.body)
        if touches_core(paths, core):
            warns.append(f"ROUTAGE {i} REVUE sur le noyau sans modèle opus ({model})")
    return out


def _check_body(t: Ticket, warns: list[str]) -> list[str]:
    i, out = t.id, []
    if t.status in ACTIVE:
        good, bad = scope_paths(t.body)
        if not good:
            out.append(f"PÉRIMÈTRE-INEXPLOITABLE {i} aucun chemin ou glob dans « Périmètre de fichiers »")
        elif bad:
            warns.append(f"PÉRIMÈTRE {i} éléments non exploitables : {'; '.join(bad)}")
    if t.status == "done":
        crit = section(t.body, "Critères de fin")
        if re.search(r"^\s*- \[ \]", crit, re.M):
            out.append(f"CRITÈRES {i} status done avec case non cochée")
    return out


def _check_graph(tickets: dict[str, Ticket]) -> list[str]:
    out = []
    live = {k: t for k, t in tickets.items() if t.status not in ("dropped", "deferred", "blocked")}
    for i, t in live.items():
        for d in t.deps:
            dep = tickets.get(d)
            if dep is None:
                out.append(f"MISSING {i} {d}")
            elif dep.status == "dropped":
                out.append(f"DEP-ON-DROPPED {i} {d}")
            elif dep.status in ("deferred", "blocked"):
                out.append(f"ACTIF->GELÉ {i} {d}")
            elif STAGE_ORDER.get(dep.get("stage"), 99) > STAGE_ORDER.get(t.get("stage"), 99):
                out.append(f"ÉTAPE {i} {t.get('stage')} -> {d} {dep.get('stage')}")
    try:
        TopologicalSorter({k: [d for d in t.deps if d in tickets] for k, t in tickets.items()}).prepare()
    except CycleError as e:
        out.append(f"CYCLE {e.args[1]}")
    return out


def _depth(tickets: dict[str, Ticket], todo: list[Ticket]) -> int:
    memo: dict[str, int] = {}
    act = {t.id for t in todo}

    def depth(n: str, seen: tuple[str, ...] = ()) -> int:
        if n in memo:
            return memo[n]
        if n in seen:  # cycle déjà signalé
            return 0
        memo[n] = 1 + max([depth(d, seen + (n,)) for d in tickets[n].deps if d in act] + [0])
        return memo[n]

    return max([depth(n) for n in act] + [0])


def main() -> int:
    r = check()
    for w in r.warnings:
        print("AVERTISSEMENT", w)
    for e in r.errors:
        print(e)
    print("actifs", r.todo, "erreurs", len(r.errors), "avertissements", len(r.warnings), "profondeur", r.depth)
    return 1 if r.errors else 0


if __name__ == "__main__":
    sys.exit(main())
