"""Règles d'admission d'un ticket (T-210) : périmètre, classe, modèle, chevauchement.

Tout est déterministe et sans effet de bord. Rien ici ne lit la classe d'en-tête pour l'abaisser :
classe, modèle et effort sont recalculés depuis les chemins du périmètre (ADR-0002, ADR-0023).
Python stdlib seulement.
"""
from __future__ import annotations

import fnmatch
import re
from dataclasses import dataclass
from pathlib import Path

# Chemins qu'un exécutant n'écrit jamais : le coordinateur seul (T-210, ADR-0021).
REFUSED_PATHS: tuple[str, ...] = ("STATE.md", "backlog/ROADMAP.md")

# R1-sensible (amendement ADR-0023) : Opus `high`.
SENSITIVE_PREFIXES: tuple[str, ...] = (
    "platform/authz/",
    "platform/policies/",
    "platform/cluster-agent/",
    "platform/install/argocd/",
    "platform/secrets/",
    "platform/identity/",
    "security/",
    "tools/oke/",
    "tests/vap/",
    "tests/argo-guard/",
    "tests/security-bundle/",
    "users/",
    "groups/",
    "identities/",
)
SENSITIVE_STAGES: frozenset[str] = frozenset({"FINAL", "PORTE"})

# Noyau supplémentaire d'ADR-0023 (en plus de CODEOWNERS).
EXTRA_CORE: tuple[str, ...] = ("docs/adr/", "docs/review/")
# R2-texte : documentation hors noyau.
TEXT_PREFIXES: tuple[str, ...] = ("docs/", "backlog/")
NOT_TEXT_PREFIXES: tuple[str, ...] = ("backlog/proposals/",)

MODEL_RANK = {"claude-haiku-5-5": 1, "claude-sonnet-5-5": 2, "claude-opus-5-5": 3}
EFFORT_RANK = {"none": 0, "low": 1, "medium": 2, "high": 3, "xhigh": 4, "max": 5}
SONNET_MAX_EFFORT = "xhigh"


# --------------------------------------------------------------------------- périmètre

_PATH_RE = re.compile(r"^[\w.*?\[\]{}@+\-/]+$")


def _split_top_level(text: str) -> list[str]:
    parts, depth, cur = [], 0, []
    for ch in text:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth = max(0, depth - 1)
        if ch == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    parts.append("".join(cur))
    return parts


def parse_perimeter(text: str) -> list[str]:
    """Extrait les globs de chemins d'une ligne `## Périmètre de fichiers`.

    Les notes entre parenthèses sont retirées ; les entrées qui ne sont pas des chemins du dépôt
    (« kube-ops », « dépôt Atlas ») sont ignorées.
    """
    out: list[str] = []
    for raw in _split_top_level(text):
        tok = re.sub(r"\([^)]*\)", "", raw).strip().strip("`")
        if not tok or not _PATH_RE.match(tok):
            continue
        if "/" not in tok and "." not in tok and "*" not in tok:
            continue  # nom nu sans chemin ni extension : dépôt ou outil externe
        out.append(tok[2:] if tok.startswith("./") else tok)
    return out


# --------------------------------------------------------------------------- chevauchement


def _segments(pat: str) -> tuple[list[str], bool]:
    """(segments, est_prefixe) : un motif terminé par `/` couvre tout son sous-arbre."""
    is_dir = pat.endswith("/")
    segs = [s for s in pat.strip("/").split("/") if s]
    return segs, is_dir


def _seg_match(a: str, b: str) -> bool:
    return a == b or fnmatch.fnmatchcase(a, b) or fnmatch.fnmatchcase(b, a)


def overlaps(a: str, b: str) -> bool:
    """Vrai si deux globs de périmètre peuvent désigner un même fichier (test conservateur)."""
    sa, da = _segments(a)
    sb, db = _segments(b)
    for i in range(min(len(sa), len(sb))):
        if sa[i] == "**" or sb[i] == "**":
            return True
        if not _seg_match(sa[i], sb[i]):
            return False
    if len(sa) == len(sb):
        return True
    short_is_dir, longer = (da, sb) if len(sa) < len(sb) else (db, sa)
    shorter = sa if len(sa) < len(sb) else sb
    # Un motif plus court recoupe le plus long s'il couvre un sous-arbre : terminé par `/`, ou
    # dernier segment sans point ni joker (répertoire écrit sans barre finale).
    last = shorter[-1]
    looks_dir = short_is_dir or ("." not in last and not any(c in last for c in "*?["))
    return looks_dir and bool(longer)


def any_overlap(xs: list[str], ys: list[str]) -> tuple[str, str] | None:
    for x in xs:
        for y in ys:
            if overlaps(x, y):
                return x, y
    return None


# --------------------------------------------------------------------------- noyau (CODEOWNERS)


@dataclass(frozen=True)
class Core:
    owned: tuple[str, ...]
    exceptions: tuple[str, ...]


def load_core(codeowners: Path) -> Core:
    owned: list[str] = list(EXTRA_CORE)
    exc: list[str] = []
    try:
        lines = codeowners.read_text(encoding="utf-8").splitlines()
    except OSError:
        lines = []
    for line in lines:
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        fields = line.split()
        path = fields[0].lstrip("/")
        if len(fields) == 1:
            exc.append(path)  # ligne sans propriétaire = exception ciblée
        else:
            owned.append(path)
    return Core(tuple(owned), tuple(exc))


def _within(path: str, exc: str) -> bool:
    return path == exc or path.startswith(exc.rstrip("/") + "/")


def core_hits(paths: list[str], core: Core) -> list[str]:
    """Chemins du périmètre qui touchent le noyau."""
    hits = []
    for p in paths:
        if any(_within(p, e) for e in core.exceptions):
            continue
        if any(overlaps(p, c) for c in core.owned):
            hits.append(p)
    return hits


# --------------------------------------------------------------------------- classe, modèle


def refused_paths(paths: list[str]) -> list[str]:
    return [p for p in paths if any(overlaps(p, r) for r in REFUSED_PATHS)]


def compute_class(paths: list[str], core: Core) -> str:
    """REVUE si le périmètre touche le noyau, sinon AUTONOME. L'en-tête n'est jamais lu."""
    return "REVUE" if core_hits(paths, core) else "AUTONOME"


def _is_text_only(paths: list[str], core: Core) -> bool:
    if not paths or core_hits(paths, core):
        return False
    for p in paths:
        if any(overlaps(p, n) for n in NOT_TEXT_PREFIXES):
            return False
        if not any(p.startswith(t) for t in TEXT_PREFIXES):
            return False
    return True


def rule_for(paths: list[str], stage: str, header_model: str, core: Core) -> tuple[str, str, str]:
    """(routing, modèle, effort) calculés depuis les chemins : 3 règles d'ADR-0023 + R0 + amendement."""
    if header_model == "human":
        return "R0-geste-humain", "human", "none"
    if stage in SENSITIVE_STAGES or any(overlaps(p, s) for p in paths for s in SENSITIVE_PREFIXES):
        return "R1-sensible", "claude-opus-5-5", "high"
    if _is_text_only(paths, core):
        return "R2-texte", "claude-haiku-5-5", "medium"
    return "R3-defaut", "claude-sonnet-5-5", "high"


def resolve_model(
    paths: list[str], stage: str, header_model: str, header_effort: str, core: Core
) -> tuple[str, str, str]:
    """Modèle final : le calcul est un plancher ; un `model:` d'en-tête plus bas est ignoré."""
    routing, model, effort = rule_for(paths, stage, header_model, core)
    if model == "human":
        return routing, model, effort
    if MODEL_RANK.get(header_model, 0) > MODEL_RANK[model]:
        model = header_model
        effort = header_effort if header_effort in EFFORT_RANK else effort
    elif MODEL_RANK.get(header_model, 0) == MODEL_RANK[model]:
        if EFFORT_RANK.get(header_effort, 0) > EFFORT_RANK[effort]:
            effort = header_effort
    if model == "claude-sonnet-5-5" and EFFORT_RANK[effort] > EFFORT_RANK[SONNET_MAX_EFFORT]:
        effort = SONNET_MAX_EFFORT
    return routing, model, effort
