#!/usr/bin/env python3
"""status_json.py : convertit la sortie texte de run-all.sh en statut `app-status.v1` (docs/schema/app-status-v1.schema.json).

Entrée standard : lignes `STATUS ID message` et marqueurs `## check-xxx.sh` produits par _lib.sh/run-all.sh.
Sortie standard : un seul objet JSON, clés triées, stable. Lecture seule, aucun appel cluster.

  status_json.py APP ENV ARCHETYPE CLUSTER_LABEL [--no-cluster] < evidence.txt

Règles (ADR-0011) : PASS exige le niveau RUNTIME et zéro FAIL/BLOCKED/NOT_TESTED. Sans cluster, verdict NOT_TESTED.
"""
from __future__ import annotations

import datetime
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LINE = re.compile(r"^(PASS|FAIL|NOT_TESTED|BLOCKED)\s+(\S+)\s+(.*)$")
STATUSES = ("PASS", "FAIL", "NOT_TESTED", "BLOCKED")
MAX_MSG = 300


def cause_for(status: str, rule: str, no_cluster: bool) -> dict:
    if status == "FAIL":
        return {"type": "check_failed", "retryable": False, "rule": rule}
    if no_cluster:
        return {"type": "cluster_unreachable", "retryable": True, "rule": rule}
    return {"type": "prerequisite_missing", "retryable": True, "rule": rule}


def parse(text: str, no_cluster: bool) -> list[dict]:
    checks, script = [], "run-all.sh"
    for raw in text.splitlines():
        if raw.startswith("## "):
            script = raw[3:].strip()
            continue
        m = LINE.match(raw)
        if not m:
            continue
        status, cid, msg = m.groups()
        c = {"id": cid, "script": script, "status": status, "message": msg.strip()[:MAX_MSG]}
        if status != "PASS":
            c["cause"] = cause_for(status, cid, no_cluster)
        checks.append(c)
    return checks


def git_revision() -> str | None:
    try:
        out = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"], capture_output=True, text=True, timeout=10)
        rev = out.stdout.strip()
        return rev if re.fullmatch(r"[0-9a-f]{40}", rev) else None
    except (OSError, subprocess.SubprocessError):
        return None


def release_name(app: str, env: str) -> str | None:
    f = ROOT / "generated/namespaces/default/projects" / app / "components" / app / "release-bindings" / f"{app}-{env}.yaml"
    try:
        import yaml

        return yaml.safe_load(f.read_text(encoding="utf-8"))["spec"]["releaseName"]
    except Exception:  # fichier absent, YAML absent ou clé manquante : pas de release connue
        return None


def build(app: str, env: str, archetype: str, cluster: str, text: str, no_cluster: bool, now: str | None = None) -> dict:
    checks = parse(text, no_cluster)
    if no_cluster and not checks:
        msg = "aucun cluster joignable ou GP_NO_CLUSTER=1 : aucune observation runtime"
        checks = [{"id": "CLUSTER", "script": "run-all.sh", "status": "NOT_TESTED", "message": msg,
                   "cause": cause_for("NOT_TESTED", "CLUSTER", True)}]
    summary = {s: sum(1 for c in checks if c["status"] == s) for s in STATUSES}
    # Observation runtime = un check autre que G1 (local, sans cluster) a rendu PASS ou FAIL.
    observed = (not no_cluster) and any(c["status"] in ("PASS", "FAIL") and c["id"] != "G1" for c in checks)
    level = "RUNTIME" if observed else "STATIC"
    if summary["FAIL"]:
        verdict = "FAIL"
    elif summary["BLOCKED"]:
        verdict = "BLOCKED"
    elif summary["NOT_TESTED"] or not observed:
        verdict = "NOT_TESTED"
    else:
        verdict = "PASS"
    doc = {
        "schemaVersion": "app-status.v1",
        "app": app,
        "environment": env,
        "cluster": cluster,
        "archetype": archetype,
        "source": {"revision": git_revision(), "release": release_name(app, env)},
        "level": level,
        "verdict": verdict,
        "timestamp": now or datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "summary": summary,
        "checks": checks,
    }
    if verdict != "PASS":
        first = next((c for s in ("FAIL", "BLOCKED", "NOT_TESTED") for c in checks if c["status"] == s), None)
        doc["cause"] = first["cause"] if first else cause_for("NOT_TESTED", "CLUSTER", no_cluster)
    return doc


def main(argv: list[str]) -> int:
    args = [a for a in argv if a != "--no-cluster"]
    no_cluster = "--no-cluster" in argv
    if len(args) != 4:
        print("usage: status_json.py APP ENV ARCHETYPE CLUSTER_LABEL [--no-cluster] < evidence.txt", file=sys.stderr)
        return 2
    app, env, arch, cluster = args
    doc = build(app, env, arch, cluster, sys.stdin.read(), no_cluster)
    json.dump(doc, sys.stdout, ensure_ascii=False, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
