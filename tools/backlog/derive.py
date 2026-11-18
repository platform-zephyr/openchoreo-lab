#!/usr/bin/env python3
"""Statut dérivé d'un ticket : cases de « Critères de fin » + historique git local (décision de Paul, 2026-11-18).

Règle :
  - `blocked`, `deferred`, `dropped` : décisions manuelles, lues dans l'en-tête (`status:`), jamais recalculées ;
  - `done` : au moins une case, toutes cochées, ET une PR fusionnée dans main pour ce ticket ;
  - `in-progress` : une PR fusionnée ou une branche `claude/*` porte le ticket, ou une case est déjà cochée (critère
    prouvé, travail antérieur aux trailers), sans être `done` ;
  - `todo` sinon.
Une PR est fusionnée pour le ticket si un commit de main porte la ligne `Ticket: T-NNN` (trailer, conservé dans le
corps d'un squash) ou, pour l'historique antérieur aux trailers, si le sujet d'une fusion squash de GitHub (`… (#N)`)
cite le ticket entre parenthèses : `feat(x): … (T-NNN)`, `(T-NNN, en partie)`, `(T-a, T-b)`.
Rétro-compatibilité : un ticket déclaré `done` dont toutes les cases sont cochées reste `done` même sans PR trouvée
(clôtures antérieures aux trailers, gestes humains sans PR) ; `check.py` le signale.
Une branche `claude/*` (locale ou distante) porte le ticket si son nom contient `t-NNN` (ou `issue-<github_issue>`) ou si
un de ses commits absents de main porte `Ticket: T-NNN`.

Lecture seule et SANS RÉSEAU : seul l'historique git déjà présent est lu (aucun fetch, aucune API GitHub). Référence de
main : `origin/main`, sinon `main`, sinon `HEAD`. Sans dépôt git, ou dans un clone superficiel (historique tronqué),
aucune preuve n'est disponible : le statut de l'en-tête est repris tel quel (`Evidence` vide, `available=False`).
"""
from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

MANUAL = frozenset({"blocked", "deferred", "dropped"})
DERIVED = frozenset({"todo", "in-progress", "done"})
MAIN_REFS = ("origin/main", "main", "HEAD")
TICKET_LINE_RE = re.compile(r"^Ticket:\s*(T-\d+[a-z]?)\b", re.M)
SQUASH_SUBJECT_RE = re.compile(r"\(#(\d+)\)\s*$")
PAREN_RE = re.compile(r"\(([^()]*)\)")
TICKET_ID_RE = re.compile(r"\bT-\d+[a-z]?\b")
BOX_RE = re.compile(r"^\s*- \[([ xX])\]", re.M)
BRANCH_TICKET_RE = re.compile(r"(?<![0-9a-z])t-(\d+[a-z]?)(?![0-9a-z])", re.I)
BRANCH_ISSUE_RE = re.compile(r"(?<![0-9a-z])issue-(\d+)(?![0-9])", re.I)
SEP = "\x1e"


@dataclass
class Evidence:
    """Preuves git lues une fois pour tout le backlog."""
    available: bool = False
    ref: str = ""
    trailers: set[str] = field(default_factory=set)      # tickets cités par `Ticket:` dans main
    subjects: set[str] = field(default_factory=set)      # tickets cités entre parenthèses d'un sujet de squash
    branch_tickets: set[str] = field(default_factory=set)  # tickets portés par une branche claude/*
    branch_issues: set[str] = field(default_factory=set)   # issues portées par une branche claude/issue-<n>-*


def _git(repo: Path, *args: str) -> str | None:
    try:
        p = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, timeout=30, check=False)
    except (OSError, subprocess.SubprocessError):
        return None
    return p.stdout if p.returncode == 0 else None


def _main_ref(repo: Path) -> str:
    for ref in MAIN_REFS:
        if _git(repo, "rev-parse", "--verify", "--quiet", ref + "^{commit}") is not None:
            return ref
    return ""


def _usable_repo(repo: Path) -> bool:
    top = _git(repo, "rev-parse", "--show-toplevel")
    if top is None or Path(top.strip()).resolve() != repo.resolve():
        return False
    return (_git(repo, "rev-parse", "--is-shallow-repository") or "").strip() == "false"


def _messages(repo: Path, *args: str) -> list[str]:
    out = _git(repo, "log", f"--format={SEP}%B", *args) or ""
    return [m for m in out.split(SEP) if m.strip()]


def _branch_names(repo: Path) -> list[str]:
    out = _git(repo, "for-each-ref", "--format=%(refname)", "refs/heads/claude", "refs/remotes") or ""
    return [r for r in out.splitlines() if "/claude/" in r]


def collect(repo: Path) -> Evidence:
    """Lit l'historique git local de `repo` ; `Evidence(available=False)` si inutilisable."""
    if not _usable_repo(repo):
        return Evidence()
    ref = _main_ref(repo)
    if not ref:
        return Evidence()
    ev = Evidence(available=True, ref=ref)
    for msg in _messages(repo, ref):
        ev.trailers.update(TICKET_LINE_RE.findall(msg))
        ev.subjects.update(subject_tickets(msg.strip().splitlines()[0]))
    branches = _branch_names(repo)
    for name in branches:
        ev.branch_tickets.update("T-" + t.lower() for t in BRANCH_TICKET_RE.findall(name.rsplit("/claude/", 1)[1]))
        ev.branch_issues.update(BRANCH_ISSUE_RE.findall(name.rsplit("/claude/", 1)[1]))
    if branches:
        for msg in _messages(repo, *branches, "--not", ref):
            ev.branch_tickets.update(TICKET_LINE_RE.findall(msg))
    return ev


def subject_tickets(subject: str) -> set[str]:
    """Tickets cités entre parenthèses dans le sujet d'une fusion squash (`… (T-NNN) (#N)`) ; vide sinon."""
    m = SQUASH_SUBJECT_RE.search(subject)
    if not m:
        return set()
    head = subject[: m.start()]
    return {t for group in PAREN_RE.findall(head) for t in TICKET_ID_RE.findall(group)}


def boxes(criteria: str) -> tuple[int, int]:
    """(cases cochées, cases au total) d'une section « Critères de fin »."""
    found = BOX_RE.findall(criteria)
    return sum(b != " " for b in found), len(found)


def merged(tid: str, ev: Evidence) -> bool:
    """Une PR fusionnée dans main porte-t-elle ce ticket ?"""
    return tid in ev.trailers or tid in ev.subjects


def has_branch(tid: str, issue: str, ev: Evidence) -> bool:
    return tid in ev.branch_tickets or (issue.isdigit() and issue in ev.branch_issues)


def derive(tid: str, declared: str, criteria: str, ev: Evidence, issue: str = "") -> str:
    """Statut calculé ; l'en-tête fait foi pour les statuts manuels ou sans preuve git disponible."""
    if declared in MANUAL or not ev.available:
        return declared
    checked, total = boxes(criteria)
    complete = bool(total) and checked == total
    is_merged = merged(tid, ev)
    if complete and (is_merged or declared == "done"):  # done déclaré sans PR trouvée : rétro-compatibilité
        return "done"
    if is_merged or checked or has_branch(tid, issue, ev):
        return "in-progress"
    return "todo"


def reason(tid: str, criteria: str, ev: Evidence, issue: str = "") -> str:
    """Explication courte du calcul (messages d'avertissement)."""
    checked, total = boxes(criteria)
    pr = "PR fusionnée" if merged(tid, ev) else "aucune PR fusionnée"
    br = ", branche claude/*" if has_branch(tid, issue, ev) else ""
    return f"cases {checked}/{total}, {pr}{br} (réf. {ev.ref})"
