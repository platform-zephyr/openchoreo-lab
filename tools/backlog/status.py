#!/usr/bin/env python3
"""Vue d'état du backlog (T-473) : ce qui est fait, en cours, bloqué, prêt. Génère `backlog/STATUS.md`.

Lecture seule des tickets `backlog/T-*.md` (analyse d'en-tête partagée avec check.py). Sortie déterministe : tri
naturel par identifiant, aucun horodatage de génération ; une date n'apparaît que si elle est écrite dans les notes
du ticket.

Usage :
  python3 tools/backlog/status.py            # imprime la vue sur stdout
  python3 tools/backlog/status.py --write    # écrit backlog/STATUS.md
  python3 tools/backlog/status.py --check    # code 1 si backlog/STATUS.md est périmé (branchable en CI plus tard)
"""
from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check

ROOT = Path(__file__).resolve().parents[2]
REPO = "platform-zephyr/openchoreo-lab"  # base des liens d'issues (surchargeable : --repo)
ORDER = ["in-progress", "todo", "blocked", "deferred", "done", "dropped"]
DATE_RE = re.compile(r"\b(20\d\d-\d\d-\d\d)\b")
PR_RE = re.compile(r"\bPR #(\d+)")
EVIDENCE_RE = re.compile(r"[\w./-]*evidence/[\w./-]*\w")
BOX_RE = re.compile(r"^\s*- \[([ xX])\]", re.M)
OPEN_RE = re.compile(r"^\s*- \[ \]\s*(.*)$", re.M)
TITLE_RE = re.compile(r'^title:\s*"(.*)"\s*$', re.M)  # check.py coupe un titre au premier « #»
RESTE_RE = re.compile(r"^\W*(Reste\b.*)$", re.M)
BLOCK_RE = re.compile(r"^\W*(Bloqué par\s*:.*)$", re.M)
MAX_CELL = 260
MAX_PROOFS = 4

Row = dict[str, object]


def natural_key(tid: str) -> tuple[str, int, str]:
    m = re.match(r"^(\D*)(\d+)(.*)$", tid)
    return (m.group(1), int(m.group(2)), m.group(3)) if m else (tid, 0, "")


def cell(text: str, limit: int = MAX_CELL) -> str:
    """Texte sûr pour une cellule de tableau : une ligne, `|` échappé, tronqué."""
    one = re.sub(r"\s+", " ", text).strip().replace("|", "\\|")
    return one if len(one) <= limit else one[: limit - 1].rstrip() + "…"


def load(backlog: Path) -> tuple[dict[str, Row], list[str]]:
    """Lit les tickets ; renvoie (lignes par id, anomalies de lecture)."""
    rows: dict[str, Row] = {}
    problems: list[str] = []
    for f in sorted(backlog.glob("T-*.md")):
        t = check.parse_ticket(f)
        if t.errors or not t.get("id"):
            problems.append(f"{f.name} : en-tête illisible")
            continue
        crit = check.section(t.body, "Critères de fin")
        boxes = BOX_RE.findall(crit)
        notes = check.section(t.body, "Notes")
        dates = DATE_RE.findall(notes)
        proofs = sorted({f"PR #{n}" for n in PR_RE.findall(notes)}
                        | {p.strip(".,;:") for p in EVIDENCE_RE.findall(t.body)})
        reste = RESTE_RE.search(notes)
        first_open = OPEN_RE.search(crit)
        title = TITLE_RE.search(f.read_text(encoding="utf-8"))
        blocked = BLOCK_RE.search(notes)
        rows[t.id] = {
            "id": t.id, "file": f.name, "title": title.group(1) if title else t.get("title"), "status": t.status, "deps": t.deps,
            "issue": t.get("github_issue"), "checked": sum(b != " " for b in boxes), "total": len(boxes),
            "date": max(dates) if dates else "", "proofs": proofs,
            "reste": reste.group(1) if reste else "",
            "first_open": first_open.group(1) if first_open else "", "blocked": blocked.group(1) if blocked else "",
        }
    return rows, problems


def link(r: Row) -> str:
    return f"[{r['id']}]({r['file']})"


def issue(r: Row, repo: str) -> str:
    n = str(r["issue"])
    return f"[#{n}](https://github.com/{repo}/issues/{n})" if n.isdigit() else "—"


def boxes(r: Row) -> str:
    return f"{r['checked']}/{r['total']}" if r["total"] else "aucun critère"


def table(head: list[str], lines: list[list[str]]) -> list[str]:
    if not lines:
        return ["_Aucun._", ""]
    out = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    out += ["| " + " | ".join(x) + " |" for x in lines]
    return [*out, ""]


def by_status(rows: dict[str, Row], status: str) -> list[Row]:
    return [rows[k] for k in sorted(rows, key=natural_key) if rows[k]["status"] == status]


def dep_state(rows: dict[str, Row], r: Row) -> tuple[list[str], list[str]]:
    """(dépendances non `done`, dépendances inconnues) d'un ticket."""
    deps: list[str] = r["deps"]  # type: ignore[assignment]
    unknown = [d for d in deps if d not in rows]
    waiting = [d for d in deps if d in rows and rows[d]["status"] != "done"]
    return waiting, unknown


def section_done(rows: dict[str, Row], repo: str) -> list[str]:
    lines = []
    for r in by_status(rows, "done"):
        proofs: list[str] = r["proofs"]  # type: ignore[assignment]
        shown = ", ".join(f"`{p}`" for p in proofs[:MAX_PROOFS]) + (" …" if len(proofs) > MAX_PROOFS else "")
        lines.append([link(r), cell(str(r["title"]), 120), str(r["date"]) or "—", cell(shown, 200) if proofs else "—",
                      issue(r, repo)])
    return ["## Fait (`done`)", "", *table(["Ticket", "Titre", "Date", "Preuve citée", "Issue"], lines)]


def reste_cell(r: Row) -> str:
    """Ligne « Reste » du ticket ; à défaut, premier critère non coché (signalé comme tel)."""
    if r["reste"]:
        return cell(str(r["reste"]))
    if r["first_open"]:
        return "Premier critère ouvert : " + cell(str(r["first_open"]), 200)
    return "(ligne « Reste » absente)"


def section_progress(rows: dict[str, Row], repo: str) -> list[str]:
    lines = [[link(r), cell(str(r["title"]), 100), boxes(r), reste_cell(r),
              issue(r, repo)] for r in by_status(rows, "in-progress")]
    return ["## En cours (`in-progress`)", "", *table(["Ticket", "Titre", "Critères", "Reste", "Issue"], lines)]


def section_blocked(rows: dict[str, Row], repo: str) -> list[str]:
    lines = [[link(r), cell(str(r["title"]), 100), cell(str(r["blocked"])) or "(ligne « Bloqué par » absente)",
              issue(r, repo)] for r in by_status(rows, "blocked")]
    return ["## Bloqué (`blocked`)", "", *table(["Ticket", "Titre", "Blocage", "Issue"], lines)]


def section_todo(rows: dict[str, Row], repo: str) -> list[str]:
    ready: list[list[str]] = []
    waiting: list[list[str]] = []
    for r in by_status(rows, "todo"):
        wait, unknown = dep_state(rows, r)
        if wait or unknown:
            what = [f"{d} ({rows[d]['status']})" for d in wait] + [f"{d} (inconnue)" for d in unknown]
            waiting.append([link(r), cell(str(r["title"]), 100), ", ".join(what), issue(r, repo)])
        else:
            ready.append([link(r), cell(str(r["title"]), 120), boxes(r), issue(r, repo)])
    return (["## À faire, prêts (`todo`, dépendances toutes `done`)", "", *table(["Ticket", "Titre", "Critères", "Issue"], ready), "## À faire, bloqués par dépendance", "", *table(["Ticket", "Titre", "Attend", "Issue"], waiting)])


def section_other(rows: dict[str, Row]) -> list[str]:
    out = ["## Gelés et abandonnés", ""]
    for st in ("deferred", "dropped"):
        ids = ", ".join(link(r) for r in by_status(rows, st))
        out.append(f"- `{st}` : {ids or 'aucun'}")
    return [*out, ""]


def anomalies(rows: dict[str, Row], problems: list[str]) -> list[str]:
    out = list(problems)
    for k in sorted(rows, key=natural_key):
        r = rows[k]
        _, unknown = dep_state(rows, r)
        if unknown:
            out.append(f"{r['id']} : dépendance inconnue {', '.join(unknown)}")
        if r["status"] in check.ACTIVE and not r["total"]:
            out.append(f"{r['id']} : aucun critère de fin (cases à cocher)")
        if r["status"] == "in-progress" and not r["reste"] and not r["first_open"]:
            out.append(f"{r['id']} : `in-progress` sans ligne « Reste » dans les notes")
        if r["status"] == "blocked" and not r["blocked"]:
            out.append(f"{r['id']} : `blocked` sans ligne « Bloqué par : »")
    return ["## Anomalies de lecture", ""] + ([f"- {a}" for a in out] if out else ["_Aucune._"]) + [""]


def render(backlog: Path, repo: str = REPO) -> str:
    rows, problems = load(backlog)
    count = Counter(str(r["status"]) for r in rows.values())
    head = [
        "# État du backlog (généré)", "",
        "Généré par `python3 tools/backlog/status.py --write` depuis `backlog/T-*.md` ; ne pas éditer à la main. "
        "Aucune date de génération : une date n'est affichée que si le ticket l'écrit dans ses notes. "
        "La preuve est la référence citée dans le ticket (fichier `evidence/` ou `PR #n`), pas une vérification runtime. "
        "Ordre de travail : [ROADMAP.md](ROADMAP.md) ; prochaines étapes : [NEXT.md](NEXT.md).", "",
        "## Compteurs", "",
    ]
    head += table(["Statut", "Tickets"], [[f"`{s}`", str(count.get(s, 0))] for s in ORDER]
                  + [["**Total**", f"**{len(rows)}**"]])
    parts = [head, section_progress(rows, repo), section_blocked(rows, repo), section_todo(rows, repo),
             section_done(rows, repo), section_other(rows), anomalies(rows, problems)]
    return "\n".join(line for p in parts for line in p).rstrip("\n") + "\n"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--backlog", type=Path, default=ROOT / "backlog")
    ap.add_argument("--output", type=Path, help="fichier de sortie (défaut : <backlog>/STATUS.md)")
    ap.add_argument("--repo", default=REPO, help="owner/nom pour les liens d'issues")
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true", help="écrit STATUS.md")
    mode.add_argument("--check", action="store_true", help="code 1 si STATUS.md est périmé ou absent")
    args = ap.parse_args(argv)
    out = args.output or args.backlog / "STATUS.md"
    text = render(args.backlog, args.repo)
    if args.write:
        out.write_text(text, encoding="utf-8")
        print(f"écrit {out}")
    elif args.check:
        current = out.read_text(encoding="utf-8") if out.exists() else None
        if current != text:
            print(f"PÉRIMÉ : {out} diffère de la vue calculée ; lancer `python3 tools/backlog/status.py --write`",
                  file=sys.stderr)
            return 1
        print("STATUS.md à jour")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
