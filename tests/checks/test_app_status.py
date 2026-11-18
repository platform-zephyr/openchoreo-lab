"""Tests du schéma app-status.v1 et de la sortie JSON de golden-paths/_checks (T-072, ADR-0011).

Lancer : python3 -m unittest discover -s tests/checks -v   (depuis la racine du dépôt)
Aucun cluster : le mode sans cluster doit sortir NOT_TESTED, jamais PASS ; un faux `kubectl` (stub) sert aux cas RUNTIME.
"""
from __future__ import annotations

import copy
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import jsonschema

ROOT = Path(__file__).resolve().parents[2]
CHECKS = ROOT / "golden-paths" / "_checks"
SCHEMA = json.loads((ROOT / "docs/schema/app-status-v1.schema.json").read_text(encoding="utf-8"))
sys.path.insert(0, str(CHECKS))
import status_json  # noqa: E402

VALIDATOR = jsonschema.Draft202012Validator(SCHEMA, format_checker=jsonschema.FormatChecker())


def errors(doc):
    return [e.message for e in VALIDATOR.iter_errors(doc)]


def load(name):
    return json.loads((ROOT / "docs/schema" / name).read_text(encoding="utf-8"))


def build(text, no_cluster=False):
    return status_json.build("whoami", "production", "A-stateless-http", "k3d", text, no_cluster, now="2026-11-18T12:00:00Z")


class SchemaTests(unittest.TestCase):
    def test_schema_is_valid(self):
        jsonschema.Draft202012Validator.check_schema(SCHEMA)

    def test_examples_validate(self):
        for n in ("app-status-v1.example.json", "app-status-v1.example-not-tested.json"):
            self.assertEqual(errors(load(n)), [], n)

    def test_pass_requires_runtime_and_no_cause(self):
        ok = {
            "schemaVersion": "app-status.v1", "app": "whoami", "environment": "production", "cluster": "k3d",
            "archetype": "A-stateless-http", "source": {"revision": None, "release": None}, "level": "RUNTIME",
            "verdict": "PASS", "timestamp": "2026-11-18T12:00:00Z",
            "summary": {"PASS": 1, "FAIL": 0, "NOT_TESTED": 0, "BLOCKED": 0},
            "checks": [{"id": "W1", "script": "check-workload.sh", "status": "PASS", "message": "ok"}],
        }
        self.assertEqual(errors(ok), [])
        static = copy.deepcopy(ok); static["level"] = "STATIC"
        self.assertTrue(errors(static))
        with_fail = copy.deepcopy(ok); with_fail["summary"]["FAIL"] = 1
        self.assertTrue(errors(with_fail))
        with_cause = copy.deepcopy(ok); with_cause["cause"] = {"type": "check_failed", "retryable": False, "rule": "W1"}
        self.assertTrue(errors(with_cause))

    def test_non_pass_requires_cause(self):
        d = load("app-status-v1.example.json"); del d["cause"]
        self.assertTrue(errors(d))

    def test_failed_check_requires_typed_cause(self):
        d = load("app-status-v1.example.json"); del d["checks"][2]["cause"]
        self.assertTrue(errors(d))

    def test_unknown_field_and_version_rejected(self):
        d = load("app-status-v1.example.json"); d["extra"] = 1
        self.assertTrue(errors(d))
        d = load("app-status-v1.example.json"); d["schemaVersion"] = "app-status.v2"
        self.assertTrue(errors(d))

    def test_static_level_never_pass(self):
        d = load("app-status-v1.example-not-tested.json"); d["verdict"] = "PASS"
        self.assertTrue(errors(d))


class ConverterTests(unittest.TestCase):
    TEXT_PASS = "## check-gitops.sh\nPASS       G1     ok\nPASS       G3     ok\n## check-workload.sh\nPASS       W1     ok\n"

    def test_all_pass_is_runtime_pass(self):
        d = build(self.TEXT_PASS)
        self.assertEqual((d["level"], d["verdict"]), ("RUNTIME", "PASS"))
        self.assertNotIn("cause", d)
        self.assertEqual(errors(d), [])

    def test_fail_has_non_retryable_cause(self):
        d = build(self.TEXT_PASS + "FAIL       W2     NetworkPolicy absente\n")
        self.assertEqual(d["verdict"], "FAIL")
        self.assertEqual(d["cause"], {"type": "check_failed", "retryable": False, "rule": "W2"})
        self.assertEqual(errors(d), [])

    def test_blocked_is_retryable_prerequisite(self):
        d = build("## check-gitops.sh\nPASS       G1     ok\nBLOCKED    G2     Argo CD non installé\n")
        self.assertEqual(d["verdict"], "BLOCKED")
        self.assertEqual(d["level"], "STATIC")  # seul G1 (local) a répondu : pas d'observation runtime
        self.assertEqual(d["cause"]["type"], "prerequisite_missing")
        self.assertTrue(d["cause"]["retryable"])
        self.assertEqual(errors(d), [])

    def test_only_local_g1_pass_is_not_pass(self):
        d = build("## check-gitops.sh\nPASS       G1     ok\n")
        self.assertEqual(d["verdict"], "NOT_TESTED")
        self.assertEqual(errors(d), [])

    def test_empty_input_never_pass(self):
        self.assertEqual(build("")["verdict"], "NOT_TESTED")
        self.assertEqual(errors(build("")), [])

    def test_no_cluster_forces_not_tested_even_with_pass_lines(self):
        d = build(self.TEXT_PASS, no_cluster=True)
        self.assertEqual((d["level"], d["verdict"]), ("STATIC", "NOT_TESTED"))
        self.assertEqual(errors(d), [])

    def test_message_truncated_and_output_stable(self):
        d = build("FAIL       W1     " + "x" * 900 + "\n")
        self.assertEqual(len(d["checks"][0]["message"]), 300)
        self.assertEqual(json.dumps(build(self.TEXT_PASS), sort_keys=True), json.dumps(build(self.TEXT_PASS), sort_keys=True))


def run_all(extra_env, *args, path=None):
    env = {**os.environ, "CLUSTER_LABEL": "k3d", **extra_env}
    if path:
        env["PATH"] = path + os.pathsep + env["PATH"]
    return subprocess.run(["bash", str(CHECKS / "run-all.sh"), "whoami", "production", *args],
                          capture_output=True, text=True, env=env, cwd=ROOT, timeout=120)


class RunAllTests(unittest.TestCase):
    def test_no_cluster_json_is_not_tested(self):
        r = run_all({"GP_NO_CLUSTER": "1"}, "--format", "json")
        self.assertEqual(r.returncode, 3, r.stderr)
        d = json.loads(r.stdout)
        self.assertEqual((d["verdict"], d["level"], d["cluster"]), ("NOT_TESTED", "STATIC", "k3d"))
        self.assertEqual(errors(d), [])

    def test_no_cluster_text_never_pass(self):
        r = run_all({"GP_NO_CLUSTER": "1"})
        self.assertEqual(r.returncode, 3)
        self.assertIn("verdict: NOT_TESTED", r.stdout)
        self.assertNotIn("verdict: PASS", r.stdout)

    def test_unreachable_cluster_is_not_tested(self):
        # kubectl présent mais serveur injoignable : stub dont `version` échoue.
        with tempfile.TemporaryDirectory() as d:
            stub = Path(d) / "kubectl"
            stub.write_text("#!/bin/sh\nexit 1\n")
            stub.chmod(stub.stat().st_mode | stat.S_IEXEC)
            r = run_all({}, "--format", "json", path=d)
        self.assertEqual(r.returncode, 3, r.stderr)
        doc = json.loads(r.stdout)
        self.assertEqual(doc["verdict"], "NOT_TESTED")
        self.assertEqual(doc["cause"]["type"], "cluster_unreachable")

    def test_stub_cluster_json_is_valid_and_not_pass(self):
        # Faux cluster : `version` réussit, tout le reste est vide -> les checks échouent ou sont bloqués, jamais PASS.
        with tempfile.TemporaryDirectory() as d:
            stub = Path(d) / "kubectl"
            stub.write_text("#!/bin/sh\n[ \"$1\" = version ] && exit 0\nexit 1\n")
            stub.chmod(stub.stat().st_mode | stat.S_IEXEC)
            r = run_all({}, "--format", "json", path=d)
        doc = json.loads(r.stdout)
        self.assertEqual(errors(doc), [])
        self.assertNotEqual(doc["verdict"], "PASS")
        self.assertIn(r.returncode, (1, 3))

    def test_evidence_json_file_written(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as d:
            rel = os.path.relpath(d, ROOT)
            r = run_all({"GP_NO_CLUSTER": "1"}, "--format", "json", "--evidence", rel)
            files = list(Path(d).glob("k3d/whoami/*-production.json"))
            self.assertEqual(len(files), 1, r.stderr)
            self.assertEqual(errors(json.loads(files[0].read_text(encoding="utf-8"))), [])

    def test_bad_format_rejected(self):
        self.assertEqual(run_all({"GP_NO_CLUSTER": "1"}, "--format", "xml").returncode, 2)


if __name__ == "__main__":
    unittest.main()
