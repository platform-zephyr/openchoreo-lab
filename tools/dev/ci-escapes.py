#!/usr/bin/env python3
"""Indicateur d'évasions de la CI (SL-7, T-461, ADR-0022) : LECTURE SEULE, stdlib seule.

Une évasion est un job rouge de `ci` dont le contrôle a un niveau <= L2 dans `tools/dev/ci-map.tsv` : un contrôle local
(`tools/dev/check`) l'aurait trouvé. Le script lit les runs `ci` des PR de la période par `gh api -X GET` (jamais une
autre méthode HTTP, jamais un autre sous-commande `gh`), compte par PR et publie un rapport daté.

Par PR : `first_push_green` (le premier run terminé est vert), `ci_runs_per_pr`, `minutes_to_green` (création du premier
run -> fin du premier run vert, None sinon), `escapes` (liste `{pr, job, niveau, run}`). Global : `escape_rate` =
jobs rouges de niveau <= L2 / jobs rouges (None sans job rouge). Le job agrégateur `ci-ok` n'est pas compté (il
reflète les autres). Un job rouge absent de la table est listé dans `unmapped_jobs` : il n'est PAS compté comme
évasion (niveau inconnu) ; c'est un défaut de `ci-map.tsv`, que `tests/dev-factory/ci-parity.sh` rend visible.
Règle de promotion (SHIFT-LEFT-DEV-ENV §4.2) : un contrôle de niveau >= L3 qui fait échouer >= 2 PR distinctes sur la
période est un candidat « décaler à gauche » (la durée par rapport au budget de L2 n'est pas mesurée ici : à vérifier
à la main).

Usage :
  tools/dev/ci-escapes.py [--repo OWNER/REPO] [--days 7] [--now AAAA-MM-JJTHH:MM:SSZ] [--out DIR] [--json]
  tools/dev/ci-escapes.py --fixture FICHIER.json [...]   # hors ligne : {"prs": [...], "runs": [...], "jobs": {"<run>": [...]}}
Sorties : Markdown sur stdout (ou JSON avec --json) ; `--out DIR` écrit `ci-escapes-AAAA-Www.{json,md}` (semaine ISO
de `--now`). Code 0 = rapport produit (des évasions n'échouent pas le script : un indicateur informe, il ne bloque pas),
2 = erreur d'usage ou de lecture. Aucun secret : numéros de PR, noms de jobs et durées seulement.
"""
import argparse
import json
import subprocess
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

SCHEMA = "ci-escapes.v1"
WORKFLOW = "ci.yaml"
AGGREGATE = "ci-ok"
MAX_LEVEL_ESCAPE = 2
PAGE = 100
MAX_PAGES = 10
ROOT = Path(__file__).resolve().parents[2]
CI_MAP = ROOT / "tools" / "dev" / "ci-map.tsv"
TS = "%Y-%m-%dT%H:%M:%SZ"


class ReadError(Exception):
    """Lecture GitHub impossible (gh absent, droit insuffisant, réponse invalide)."""


def parse_ts(value):
    return datetime.strptime(value, TS).replace(tzinfo=UTC)


def load_levels(path=CI_MAP):
    """job -> niveau entier (L2 -> 2) d'après ci-map.tsv ; les lignes LOCAL-ONLY et les commentaires sont ignorés."""
    levels = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        cols = line.split("\t")
        if not line.strip() or line.startswith("#") or len(cols) < 3 or cols[0] == "LOCAL-ONLY":
            continue
        niveau = cols[2].strip()
        if niveau[:1] == "L" and niveau[1:].isdigit():
            levels[cols[0]] = int(niveau[1:])
    return levels


def gh_get(path):
    """GET en lecture seule via gh ; le chemin est relatif à l'API (aucune écriture possible : -X GET fixe)."""
    try:
        proc = subprocess.run(["gh", "api", "-X", "GET", path], capture_output=True, text=True, timeout=120, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ReadError(f"gh api {path} : {exc}") from exc
    if proc.returncode != 0:
        raise ReadError(f"gh api {path} : rc={proc.returncode} {proc.stderr.strip()[:200]}")
    try:
        return json.loads(proc.stdout)
    except ValueError as exc:
        raise ReadError(f"gh api {path} : réponse non JSON") from exc


def paged(get, path, key):
    """Parcourt les pages d'une liste (`key` = clé de l'objet englobant, ou None si la réponse est la liste)."""
    out = []
    sep = "&" if "?" in path else "?"
    for page in range(1, MAX_PAGES + 1):
        data = get(f"{path}{sep}per_page={PAGE}&page={page}")
        items = data[key] if key else data
        out.extend(items)
        if len(items) < PAGE:
            break
    return out


def fetch_live(repo, since, get=gh_get):
    """Runs `ci` de PR créés depuis `since` et leurs jobs : {"runs": [...], "jobs": {run_id: [...]}}."""
    day = since.strftime("%Y-%m-%d")
    runs = paged(get, f"repos/{repo}/actions/workflows/{WORKFLOW}/runs?event=pull_request&created=%3E%3D{day}", "workflow_runs")
    jobs = {}
    for run in runs:
        if run.get("conclusion") == "failure":
            jobs[str(run["id"])] = paged(get, f"repos/{repo}/actions/runs/{run['id']}/jobs", "jobs")
    return {"runs": runs, "jobs": jobs}


def pr_of(run):
    """Numéro de PR d'un run (liste `pull_requests`) ; les PR de fork n'en ont pas : repli sur la branche."""
    prs = run.get("pull_requests") or []
    if prs:
        return f"#{prs[0]['number']}"
    return f"branche:{run.get('head_branch', '?')}"


def group_by_pr(runs, since, now):
    """Runs terminés (success/failure) de la période, regroupés par PR ; annulés, ignorés et en cours : pas un verdict."""
    by_pr = {}
    for run in runs:
        if run.get("conclusion") not in ("success", "failure"):
            continue
        if not since <= parse_ts(run["created_at"]) <= now:
            continue
        by_pr.setdefault(pr_of(run), []).append(run)
    return by_pr


def pr_sort_key(pr):
    """PR numérotées d'abord (ordre numérique), puis les branches (ordre alphabétique)."""
    return (pr[0] != "#", int(pr[1:]) if pr[0] == "#" else 0, pr)


def minutes_to_green(runs):
    """Minutes entre la création du premier run et la fin du premier run vert ; None sans run vert."""
    green = next((r for r in runs if r["conclusion"] == "success"), None)
    if green is None:
        return None
    return round((parse_ts(green["updated_at"]) - parse_ts(runs[0]["created_at"])).total_seconds() / 60, 1)


def red_job_names(run, jobs):
    """Noms des jobs rouges d'un run rouge, sans `ci-ok` ; la matrice « dev (x) » devient « dev »."""
    if run["conclusion"] != "failure":
        return []
    return [job["name"].split(" (")[0] for job in jobs.get(str(run["id"]), [])
            if job.get("conclusion") == "failure" and job["name"] != AGGREGATE]


def summarise_pr(pr, runs, jobs, levels, acc):
    """Indicateurs d'une PR ; `acc` (red, unmapped, failing) cumule les compteurs globaux."""
    pr_escapes = []
    for run in runs:
        for name in red_job_names(run, jobs):
            acc["red"] += 1
            acc["failing"].setdefault(name, set()).add(pr)
            level = levels.get(name)
            if level is None:
                acc["unmapped"].add(name)
            elif level <= MAX_LEVEL_ESCAPE:
                pr_escapes.append({"pr": pr, "job": name, "niveau": f"L{level}", "run": run["id"]})
    return {
        "pr": pr,
        "ci_runs_per_pr": len(runs),
        "first_push_green": runs[0]["conclusion"] == "success",
        "minutes_to_green": minutes_to_green(runs),
        "escapes": pr_escapes,
    }


def shift_left_candidates(failing, levels):
    """Contrôles de niveau >= L3 en échec sur >= 2 PR distinctes (règle de promotion, SHIFT-LEFT-DEV-ENV §4.2)."""
    return sorted(
        ({"job": j, "niveau": f"L{levels[j]}", "prs": sorted(p)}
         for j, p in failing.items() if j in levels and levels[j] > MAX_LEVEL_ESCAPE and len(p) >= 2),
        key=lambda c: c["job"],
    )


def analyse(data, levels, since, now):
    """Calcule l'indicateur à partir de runs et de jobs déjà lus (pure : testable sans réseau)."""
    by_pr = group_by_pr(data["runs"], since, now)
    acc = {"red": 0, "unmapped": set(), "failing": {}}
    prs = []
    for pr in sorted(by_pr, key=pr_sort_key):
        runs = sorted(by_pr[pr], key=lambda r: (r["created_at"], r["id"]))
        prs.append(summarise_pr(pr, runs, data["jobs"], levels, acc))
    escapes = [e for p in prs for e in p["escapes"]]
    n = len(prs)
    return {
        "schema": SCHEMA,
        "date": now.strftime(TS),
        "since": since.strftime(TS),
        "prs_count": n,
        "first_push_green_rate": round(sum(p["first_push_green"] for p in prs) / n, 3) if n else None,
        "red_jobs": acc["red"],
        "escapes_count": len(escapes),
        "escape_rate": round(len(escapes) / acc["red"], 3) if acc["red"] else None,
        "unmapped_jobs": sorted(acc["unmapped"]),
        "shift_left_candidates": shift_left_candidates(acc["failing"], levels),
        "prs": prs,
    }


def pct(value):
    return "n/a" if value is None else f"{value * 100:.0f} %"


def render_markdown(rep):
    iso = parse_ts(rep["date"]).isocalendar()
    out = [
        f"# Évasions de la CI : semaine {iso[0]}-W{iso[1]:02d} (rapport du {rep['date']})",
        "",
        f"Période : {rep['since']} -> {rep['date']}. Évasion = job rouge dont le contrôle local est de niveau <= L2 "
        "(`tools/dev/ci-map.tsv`). Cible : 0 par semaine, PR vertes au premier push >= 80 % (objectif, pas une mesure).",
        "",
        f"- PR avec au moins un run `ci` terminé : {rep['prs_count']}",
        f"- Vertes au premier push : {pct(rep['first_push_green_rate'])}",
        f"- Jobs rouges (hors `ci-ok`) : {rep['red_jobs']} ; évasions : {rep['escapes_count']} ; taux d'évasion : {pct(rep['escape_rate'])}",
    ]
    if rep["unmapped_jobs"]:
        out.append(f"- Jobs rouges absents de ci-map.tsv (niveau inconnu, non comptés) : {', '.join(rep['unmapped_jobs'])}")
    out += ["", "| PR | runs ci | vert au 1er push | minutes jusqu'au vert | évasions |", "|---|---|---|---|---|"]
    for p in rep["prs"]:
        esc = ", ".join(f"{e['job']} ({e['niveau']})" for e in p["escapes"]) or "-"
        mtg = "-" if p["minutes_to_green"] is None else p["minutes_to_green"]
        out.append(f"| {p['pr']} | {p['ci_runs_per_pr']} | {'oui' if p['first_push_green'] else 'non'} | {mtg} | {esc} |")
    if rep["shift_left_candidates"]:
        out += ["", "Candidats « décaler à gauche » (>= 2 PR distinctes en échec, niveau >= L3) :"]
        out += [f"- {c['job']} ({c['niveau']}) : {', '.join(c['prs'])}" for c in rep["shift_left_candidates"]]
    return "\n".join(out) + "\n"


def write_report(rep, out_dir):
    iso = parse_ts(rep["date"]).isocalendar()
    base = Path(out_dir) / f"ci-escapes-{iso[0]}-W{iso[1]:02d}"
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    base.with_suffix(".json").write_text(json.dumps(rep, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    base.with_suffix(".md").write_text(render_markdown(rep), encoding="utf-8")
    return base


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--repo", help="OWNER/REPO (défaut : le dépôt courant, lu par `gh repo view`)")
    ap.add_argument("--days", type=int, default=7, help="longueur de la période en jours (défaut 7)")
    ap.add_argument("--now", help="date de référence UTC (AAAA-MM-JJTHH:MM:SSZ) ; défaut : maintenant")
    ap.add_argument("--out", help="dossier où écrire ci-escapes-AAAA-Www.json et .md")
    ap.add_argument("--json", action="store_true", help="JSON sur stdout au lieu du Markdown")
    ap.add_argument("--fixture", help="lire les runs et jobs dans ce JSON (aucun appel réseau)")
    ap.add_argument("--map", default=str(CI_MAP), help="table des niveaux (défaut : tools/dev/ci-map.tsv)")
    args = ap.parse_args(argv)
    if args.days < 1:
        print("ci-escapes : --days doit être >= 1", file=sys.stderr)
        return 2
    try:
        now = parse_ts(args.now) if args.now else datetime.now(UTC).replace(microsecond=0)
        since = now - timedelta(days=args.days)
        levels = load_levels(args.map)
        if args.fixture:
            data = json.loads(Path(args.fixture).read_text(encoding="utf-8"))
        else:
            repo = args.repo
            if not repo:
                repo = gh_get_repo()
            data = fetch_live(repo, since)
    except (ReadError, OSError, ValueError, KeyError) as exc:
        print(f"ci-escapes : {exc}", file=sys.stderr)
        return 2
    rep = analyse(data, levels, since, now)
    if args.out:
        base = write_report(rep, args.out)
        print(f"-- rapport écrit : {base}.json et {base}.md", file=sys.stderr)
    sys.stdout.write(json.dumps(rep, indent=2, sort_keys=True) + "\n" if args.json else render_markdown(rep))
    return 0


def gh_get_repo():
    """Dépôt courant par `gh repo view` (lecture seule)."""
    try:
        proc = subprocess.run(["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"],
                              capture_output=True, text=True, timeout=60, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ReadError(f"gh repo view : {exc}") from exc
    if proc.returncode != 0 or "/" not in proc.stdout:
        raise ReadError("dépôt non déterminé : passer --repo OWNER/REPO")
    return proc.stdout.strip()


if __name__ == "__main__":
    sys.exit(main())
