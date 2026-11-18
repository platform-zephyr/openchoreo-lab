"""Tests du contrat d'alerte (T-100, ADR-0015) : schéma alert-payload.v1, lint OBS-0, cause.nature de app-status.v1.

Lancer : python3 -m unittest discover -s tests/observe -v   (depuis la racine du dépôt). Aucun cluster.
"""
from __future__ import annotations

import copy
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

import jsonschema
import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "observe"))
import lint_runbooks  # noqa: E402

SCHEMA_DIR = ROOT / "docs" / "schema"
PAYLOAD_SCHEMA = json.loads((SCHEMA_DIR / "alert-payload.v1.json").read_text(encoding="utf-8"))
STATUS_SCHEMA = json.loads((SCHEMA_DIR / "app-status-v1.schema.json").read_text(encoding="utf-8"))
RULES = ROOT / "observability" / "alert-rules" / "lab-generic.yaml"
RUNBOOKS = ROOT / "docs" / "runbooks"


def validator(schema):
    return jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker())


def load(name):
    return json.loads((SCHEMA_DIR / name).read_text(encoding="utf-8"))


def in_dir(cwd, rule_files):
    old = os.getcwd()
    os.chdir(cwd)
    try:
        return lint_runbooks.lint(rule_files, Path("docs/runbooks"))
    finally:
        os.chdir(old)


class PayloadSchemaTests(unittest.TestCase):
    def setUp(self):
        self.v = validator(PAYLOAD_SCHEMA)

    def errs(self, doc):
        return [e.message for e in self.v.iter_errors(doc)]

    def test_schema_is_valid(self):
        jsonschema.Draft202012Validator.check_schema(PAYLOAD_SCHEMA)

    def test_two_valid_examples(self):
        for name in ("alert-payload.v1.example-app.json", "alert-payload.v1.example-platform.json"):
            self.assertEqual(self.errs(load(name)), [], name)

    def test_invalid_app_alert_without_app_and_env(self):
        doc = load("alert-payload.v1.example-app.json")
        del doc["app"], doc["env"]
        self.assertTrue(self.errs(doc))

    def test_invalid_extra_field_and_runbook_url(self):
        doc = load("alert-payload.v1.example-app.json")
        doc["logs"] = "sortie brute"
        self.assertTrue(self.errs(doc))
        doc = load("alert-payload.v1.example-app.json")
        doc["runbook"] = "https://example.invalid/runbook"
        self.assertTrue(self.errs(doc))

    def test_invalid_enums_and_version(self):
        for key, value in (("severity", "page"), ("class", "other"), ("status", "pending"),
                           ("schemaVersion", "alert-payload.v2"), ("fingerprint", "ZZ")):
            doc = load("alert-payload.v1.example-app.json")
            doc[key] = value
            self.assertTrue(self.errs(doc), key)

    def test_examples_match_a_real_rule_and_runbook(self):
        rules, _ = lint_runbooks.load_rules([RULES])
        for name in ("alert-payload.v1.example-app.json", "alert-payload.v1.example-platform.json"):
            doc = load(name)
            self.assertIn(doc["alert"], rules)
            self.assertEqual(doc["runbook"], f"docs/runbooks/{doc['alert']}.md")
            self.assertTrue((ROOT / doc["runbook"]).is_file())
            self.assertEqual(doc["class"], rules[doc["alert"]]["labels"]["class"])
            self.assertEqual(doc["severity"], rules[doc["alert"]]["labels"]["severity"])


class CauseNatureTests(unittest.TestCase):
    def setUp(self):
        self.v = validator(STATUS_SCHEMA)

    def test_existing_examples_still_valid_without_nature(self):
        for n in ("app-status-v1.example.json", "app-status-v1.example-not-tested.json"):
            self.assertEqual([e.message for e in self.v.iter_errors(load(n))], [], n)

    def test_nature_accepted_and_closed(self):
        doc = load("app-status-v1.example.json")
        for nature in ("retryable", "a_corriger", "plateforme"):
            d = copy.deepcopy(doc)
            d["cause"]["nature"] = nature
            d["checks"][2]["cause"]["nature"] = nature
            self.assertEqual([e.message for e in self.v.iter_errors(d)], [], nature)
        d = copy.deepcopy(doc)
        d["cause"]["nature"] = "inconnue"
        self.assertTrue(list(self.v.iter_errors(d)))


class LintTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.runbooks = self.tmp / "docs" / "runbooks"
        shutil.copytree(RUNBOOKS, self.runbooks)
        self.rules = self.tmp / "rules.yaml"
        shutil.copy(RULES, self.rules)

    def lint(self):
        # Les chemins d'annotation sont relatifs au dépôt : on lint depuis la copie de travail.
        return in_dir(self.tmp, [self.rules])

    def test_repository_is_green(self):
        self.assertEqual(in_dir(ROOT, [RULES]), [])

    def test_rule_without_runbook_fails(self):
        (self.runbooks / "LabAppDown.md").unlink()
        self.assertTrue(any("LabAppDown" in e and "manquant" in e for e in self.lint()))

    def test_orphan_runbook_fails(self):
        (self.runbooks / "LabInconnue.md").write_text((self.runbooks / "LabAppDown.md").read_text(encoding="utf-8"),
                                                      encoding="utf-8")
        self.assertTrue(any("orphelin" in e for e in self.lint()))

    def test_missing_front_matter_key_fails(self):
        path = self.runbooks / "LabPodPending.md"
        path.write_text(path.read_text(encoding="utf-8").replace("escalate_when:", "escalade:", 1), encoding="utf-8")
        self.assertTrue(any("escalate_when" in e for e in self.lint()))

    def test_write_command_in_checks_fails(self):
        path = self.runbooks / "LabAppDown.md"
        path.write_text(path.read_text(encoding="utf-8").replace(
            'argocd app get lab-apps', 'kubectl delete pod -n dp-x', 1), encoding="utf-8")
        self.assertTrue(any("lecture seule" in e or "écriture" in e for e in self.lint()))

    def test_rule_missing_runbook_annotation_fails(self):
        doc = yaml.safe_load(self.rules.read_text(encoding="utf-8"))
        del doc["groups"][0]["rules"][0]["annotations"]["runbook"]
        self.rules.write_text(yaml.safe_dump(doc), encoding="utf-8")
        self.assertTrue(any("annotation runbook" in e for e in self.lint()))

    def test_severity_mismatch_fails(self):
        doc = yaml.safe_load(self.rules.read_text(encoding="utf-8"))
        doc["groups"][0]["rules"][0]["labels"]["severity"] = "info"
        self.rules.write_text(yaml.safe_dump(doc), encoding="utf-8")
        self.assertTrue(any("severity différente" in e for e in self.lint()))

    def test_unknown_action_fails(self):
        path = self.runbooks / "LabClusterUnreachable.md"
        path.write_text(path.read_text(encoding="utf-8").replace("  - notify", "  - restart", 1), encoding="utf-8")
        self.assertTrue(any("allowed_actions inconnues" in e for e in self.lint()))


if __name__ == "__main__":
    unittest.main()
