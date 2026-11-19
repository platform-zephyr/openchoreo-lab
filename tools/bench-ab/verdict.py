#!/usr/bin/env python3
"""Agrégateur et verdict du banc A/B (T-485, ADR-0025, docs/research/POC-OPENCHOREO-STRATEGY.md §2.4-2.5).

Entrées :
- des seuils (`tests/bench-ab/thresholds.yaml`, ou le gabarit `thresholds.template.yaml` avant le gel de T-486) ;
- un répertoire de campagne : un fichier `bench-run.v1` par run compté (arm K|O, task M1..M4 ou P1..P3, rank 1..N ;
  le rang 0 est la passe 0, jamais comptée), qui porte le check run, les observations, les compteurs d'effort et le
  chemin d'un `mission-result.v1` relatif au répertoire (lu par `tools/factory/stats.py`).
Le statut d'une tâche vient des graders (`graders.py`), jamais du statut déclaré par l'agent.
Sortie : un rapport JSON `bench-ab-report.v1` : S1, S2, S3, S5, S6, S7 par bras, statut par seuil, verdict
(`valeur_prouvee`, `arret`, `en_cours`) et arrêt anticipé. S4 est retiré (couvert par S3).
Règle de verdict : S1, S6 et S7 passent et au moins 2 de S2, S3, S5 ; sinon arrêt. Arrêt anticipé : on complète les
runs manquants au meilleur cas pour O (réussite, effort nul) et au pire cas pour K ; un seuil qui ne passe pas alors est
inatteignable. Une mesure absente rend NOT_TESTED, qui ne passe jamais.
Usage : verdict.py validate --thresholds F | verdict.py report --thresholds F --dir D
Codes : 0 valeur prouvée ou en cours ; 1 arrêt ; 2 entrée invalide. Hors ligne, aucun secret.
"""
from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
from pathlib import Path
from typing import Any

import yaml

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "factory"))
import graders  # noqa: E402
import stats  # noqa: E402

SCHEMA_REPORT = "bench-ab-report.v1"
SCHEMA_RUN = "bench-run.v1"
SCHEMA_FILE = HERE.parents[1] / "tests" / "bench-ab" / "thresholds.schema.json"
CRITERIA = ("S1", "S2", "S3", "S5", "S6", "S7")
ARMS = ("K", "O")
INF = math.inf
PASS, FAIL, NOT_TESTED = graders.PASS, graders.FAIL, graders.NOT_TESTED


# ---------------------------------------------------------------- seuils

def load_thresholds(path: Path) -> dict:
    """Lit et valide les seuils (schéma JSON + cohérence) ; lève ValueError avec la liste des écarts."""
    try:
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        schema = json.loads(SCHEMA_FILE.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError, json.JSONDecodeError) as exc:
        raise ValueError(f"lecture impossible ({type(exc).__name__})") from exc
    try:
        import jsonschema
    except ImportError as exc:
        raise ValueError("NOT_TESTED : module jsonschema absent") from exc
    errors = [f"{'/'.join(map(str, e.absolute_path)) or '.'} : {e.message}"
              for e in jsonschema.Draft202012Validator(schema).iter_errors(doc)]
    if not errors:
        errors = coherence_errors(doc)
    if errors:
        raise ValueError("; ".join(errors))
    return doc


def coherence_errors(doc: dict) -> list[str]:
    errors = []
    verdict = doc["verdict"]
    cited = {*verdict["must_pass"], *verdict["at_least"]["among"]}
    if cited != set(CRITERIA) or set(verdict["must_pass"]) & set(verdict["at_least"]["among"]):
        errors.append("verdict : chaque seuil S1, S2, S3, S5, S6, S7 doit figurer une seule fois")
    if verdict["at_least"]["count"] > len(verdict["at_least"]["among"]):
        errors.append("verdict.at_least.count dépasse la liste")
    return errors


# ---------------------------------------------------------------- runs

def expected_slots(th: dict) -> list[tuple[str, str, int]]:
    """(bras, tâche ou piège, rang) de la campagne comptée : N runs par tâche et par bras, un run par piège et par bras."""
    slots = [(a, t, r) for a in ARMS for t in th["tasks"] for r in range(1, th["runs_per_task_per_arm"] + 1)]
    return slots + [(a, p, 1) for a in ARMS for p in th["traps"]]


def num(value: Any) -> float | None:
    return float(value) if isinstance(value, (int, float)) and not isinstance(value, bool) and value >= 0 else None


def build_run(rec: dict, directory: Path) -> dict:
    """Run enrichi : verdict du grader, cause (M4), effort, tours et coût (via stats.read_one)."""
    mission = {}
    ref = rec.get("mission_result")
    if isinstance(ref, str):
        target = (directory / ref).resolve()
        if directory.resolve() in target.parents:
            mission = stats.read_one(target)[0] or {}
    obs = rec.get("observations") if isinstance(rec.get("observations"), dict) else {}
    grade = graders.grade("trap" if rec["task"].startswith("P") else rec["task"].lower(),
                          rec.get("check_run"), obs, rec.get("expected_sha"))
    return {
        "arm": rec["arm"], "task": rec["task"], "rank": rec["rank"], "status": grade["status"], "reason": grade["reason"],
        "cause_correct": graders.cause_verdict(obs)["status"] == PASS if rec["task"] == "M4" else None,
        "num_turns": num(mission.get("num_turns")), "total_cost_usd": num(mission.get("total_cost_usd")),
        "files_written": num(rec.get("files_written")), "lines_written": num(rec.get("lines_written")),
        "human_interventions": num(rec.get("human_interventions")),
        "duration_s": num(rec.get("duration_to_fix_pr_s")) if rec["task"] == "M4" else None,
    }


def check_record(rec: Any, th: dict) -> str:
    """Motif de rejet d'un fichier de campagne, ou chaîne vide."""
    if not isinstance(rec, dict) or rec.get("schema") != SCHEMA_RUN:
        return "schema_inconnu"
    if rec.get("arm") not in ARMS or rec.get("task") not in (*th["tasks"], *th["traps"]):
        return "bras_ou_tache_inconnu"
    if not isinstance(rec.get("rank"), int) or isinstance(rec.get("rank"), bool):
        return "rang_invalide"
    if rec["rank"] == 0:
        return "passe_0_non_comptee"
    if (rec["arm"], rec["task"], rec["rank"]) not in set(expected_slots(th)):
        return "hors_campagne"
    return ""


def load_campaign(directory: Path, th: dict) -> tuple[list[dict], list[dict]]:
    """(runs valides, fichiers ignorés avec motif). Un doublon (bras, tâche, rang) est ignoré."""
    runs: dict[tuple, dict] = {}
    ignored: list[dict] = []
    for path in sorted(directory.glob("*.json")):
        try:
            rec = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            ignored.append({"file": path.name, "why": "illisible"})
            continue
        if isinstance(rec, dict) and rec.get("schema") == stats.SCHEMA_IN:
            continue  # un mission-result.v1 voisin : lu via le bench-run qui le référence
        why = check_record(rec, th)
        key = (rec.get("arm"), rec.get("task"), rec.get("rank")) if not why else None
        if not why and key in runs:
            why = "doublon"
        if why:
            ignored.append({"file": path.name, "why": why})
        else:
            runs[key] = build_run(rec, directory)
    return list(runs.values()), ignored


def placeholder(arm: str, task: str, rank: int) -> dict:
    """Run non encore réalisé, au meilleur cas pour O et au pire cas pour K (pour l'arrêt anticipé)."""
    best = arm == "O"
    effort = 0.0 if best else INF
    return {"arm": arm, "task": task, "rank": rank, "status": PASS if best else FAIL, "reason": "hypothétique",
            "cause_correct": best if task == "M4" else None, "num_turns": effort, "total_cost_usd": effort,
            "files_written": effort, "lines_written": effort, "human_interventions": 0.0 if best else INF,
            "duration_s": effort if task == "M4" else None}


# ---------------------------------------------------------------- valeurs par bras (S1-S7)

def med(values: list[float | None]) -> float | None:
    """Médiane ; None si la liste est vide ou si une valeur manque (mesure impossible : NOT_TESTED)."""
    if not values or any(v is None for v in values):
        return None
    return statistics.median(values)  # type: ignore[type-var]


def metric_medians(tasks: list[dict], metrics: tuple[str, ...]) -> dict:
    return {m: med([r[m] for r in tasks]) for m in metrics}


def s5_values(tasks: list[dict]) -> dict:
    m4 = [r for r in tasks if r["task"] == "M4"]
    durations = [INF if r["duration_s"] is None else r["duration_s"] for r in m4]  # null = aucune PR de correctif
    return {"correct_causes": sum(1 for r in m4 if r["cause_correct"]), "median_duration_s": med(durations)}


def s7_value(mine: list[dict]) -> dict:
    counts = [r["human_interventions"] for r in mine]
    return {"interventions": None if not mine or None in counts else sum(counts)}


def arm_values(runs: list[dict], arm: str, th: dict) -> dict:
    mine = [r for r in runs if r["arm"] == arm]
    tasks = [r for r in mine if r["task"] in th["tasks"]]
    traps = [r for r in mine if r["task"] in th["traps"]]
    return {
        "S1": {t: sum(1 for r in tasks if r["task"] == t and r["status"] == PASS) for t in th["tasks"]},
        "S2": metric_medians(tasks, ("files_written", "lines_written")),
        "S3": metric_medians(tasks, ("num_turns", "total_cost_usd")),
        "S5": s5_values(tasks),
        "S6": {"contained": sum(1 for r in traps if r["status"] == PASS)},
        "S7": s7_value(mine),
    }


# ---------------------------------------------------------------- statut par seuil

def ratio_status(o: dict, k: dict, metrics: list[str], limit: float) -> str:
    for m in metrics:
        if o[m] is None or k[m] is None:
            return NOT_TESTED
    return PASS if all(o[m] <= limit * k[m] for m in metrics) else FAIL


def s1_status(o: dict, k: dict, rule: dict, runs_per: int) -> str:
    each = all(o[t] >= k[t] for t in o) if rule["o_at_least_k_on_each_task"] else True
    full = sum(1 for t in o if o[t] >= runs_per)
    return PASS if each and full >= rule["o_full_pass_min_tasks"] else FAIL


def s5_status(o: dict, k: dict, rule: dict) -> str:
    if o["correct_causes"] < rule["o_correct_causes_required"]:
        return FAIL
    if not rule["o_median_duration_at_most_k"]:
        return PASS
    od, kd = o["median_duration_s"], k["median_duration_s"]
    return PASS if od is not None and kd is not None and od != INF and od <= kd else FAIL


def s6_status(o: dict, k: dict, rule: dict) -> str:
    if o["contained"] < rule["o_contained_required"]:
        return FAIL
    return PASS if not rule["o_at_least_k"] or o["contained"] >= k["contained"] else FAIL


def s7_status(o: dict, rule: dict) -> str:
    if o["interventions"] is None:
        return NOT_TESTED
    return PASS if o["interventions"] <= rule["max_o_interventions"] else FAIL


def statuses(values: dict, th: dict) -> dict[str, str]:
    o, k, rules = values["O"], values["K"], th["thresholds"]
    return {
        "S1": s1_status(o["S1"], k["S1"], rules["S1"], th["runs_per_task_per_arm"]),
        "S2": ratio_status(o["S2"], k["S2"], rules["S2"]["metrics"], rules["S2"]["max_ratio_o_over_k"]),
        "S3": ratio_status(o["S3"], k["S3"], rules["S3"]["metrics"], rules["S3"]["max_ratio_o_over_k"]),
        "S5": s5_status(o["S5"], k["S5"], rules["S5"]),
        "S6": s6_status(o["S6"], k["S6"], rules["S6"]),
        "S7": s7_status(o["S7"], rules["S7"]),
    }


def verdict_of(status: dict[str, str], th: dict) -> str:
    """`valeur_prouvee` si les seuils obligatoires passent et au moins `count` des autres ; sinon `arret`."""
    rule = th["verdict"]
    musts = all(status[s] == PASS for s in rule["must_pass"])
    enough = sum(1 for s in rule["at_least"]["among"] if status[s] == PASS) >= rule["at_least"]["count"]
    return "valeur_prouvee" if musts and enough else "arret"


# ---------------------------------------------------------------- rapport

def jsonable(value: Any) -> Any:
    """Les infinis (mesure sans borne) deviennent null dans le JSON."""
    if isinstance(value, dict):
        return {k: jsonable(v) for k, v in value.items()}
    return None if isinstance(value, float) and not math.isfinite(value) else value


def early_stop(best: dict[str, str], th: dict, complete: bool) -> dict:
    """Arrêt anticipé : le meilleur cas pour O (K au pire) ne donne pas « valeur prouvée »."""
    stopped = bool(th["early_stop"] and not complete and verdict_of(best, th) == "arret")
    unreachable = [s for s in CRITERIA if best[s] != PASS]
    reasons = [f"{s} inatteignable" for s in unreachable]
    if stopped and not reasons:
        reasons = ["moins de 2 seuils parmi S2, S3, S5 atteignables"]
    return {"triggered": stopped, "reasons": reasons if stopped else []}


def build_report(runs: list[dict], ignored: list[dict], th: dict) -> dict:
    slots = expected_slots(th)
    have = {(r["arm"], r["task"], r["rank"]) for r in runs}
    missing = [s for s in slots if s not in have]
    complete = not missing
    final = statuses({a: arm_values(runs, a, th) for a in ARMS}, th)
    best = statuses({a: arm_values([*runs, *(placeholder(*s) for s in missing)], a, th) for a in ARMS}, th)
    stop = early_stop(best, th, complete)
    verdict = verdict_of(final, th) if complete else ("arret" if stop["triggered"] else "en_cours")
    return jsonable({
        "schema": SCHEMA_REPORT, "complete": complete, "expected_runs": len(slots), "recorded_runs": len(runs),
        "per_arm": {a: arm_values(runs, a, th) for a in ARMS},
        "criteria": {s: {"status": final[s] if complete else "EN_COURS", "reachable": best[s] == PASS} for s in CRITERIA},
        "verdict": verdict, "early_stop": stop, "ignored": ignored,
        "note": "NOT_TESTED ne passe jamais ; seul un grader par code décide du statut d'une tâche.",
    })


# ---------------------------------------------------------------- CLI

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("validate", "report"):
        p = sub.add_parser(name)
        p.add_argument("--thresholds", type=Path, required=True)
        if name == "report":
            p.add_argument("--dir", type=Path, required=True)
    args = ap.parse_args(argv)
    try:
        th = load_thresholds(args.thresholds)
    except ValueError as exc:
        print(f"FAIL : seuils invalides : {exc}", file=sys.stderr)
        return 2
    if args.cmd == "validate":
        print("PASS : seuils valides")
        return 0
    if not args.dir.is_dir():
        print("FAIL : répertoire de campagne introuvable", file=sys.stderr)
        return 2
    report = build_report(*load_campaign(args.dir, th), th)
    print(json.dumps(report, indent=2, ensure_ascii=False, sort_keys=True))
    return 1 if report["verdict"] == "arret" else 0


if __name__ == "__main__":
    sys.exit(main())
