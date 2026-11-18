"""Tests hors ligne de tools/factory/stats.py (T-479). Aucun réseau, aucun cluster, aucun secret."""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "factory"))
import stats  # noqa: E402


def run(issue, model="claude-sonnet-5-5", status="PASS", turns=10, cost=1.0, dur=2000, **extra):
    r = {"schema": "mission-result.v1", "ticket_issue": issue, "model_requested": model, "model_observed": model,
         "effort": "high", "escalated_from": None, "status": status, "num_turns": turns, "duration_ms": dur,
         "total_cost_usd": cost, "tokens": {}, "ci_failures": 0, "checks": {}}
    r.update(extra)
    return r


def write(d, name, obj):
    p = Path(d) / name
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(obj if isinstance(obj, str) else json.dumps(obj), encoding="utf-8")


def cli(*args):
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        rc = stats.main(list(args))
    return rc, out.getvalue(), err.getvalue()


class StatsTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.d = self._tmp.name
        self.addCleanup(self._tmp.cleanup)

    def report(self, *extra):
        rc, out, _ = cli("--dir", self.d, "--json", *extra)
        self.assertEqual(rc, 0)
        return json.loads(out)

    def test_empty_directory(self):
        rc, out, _ = cli("--dir", self.d)
        self.assertEqual(rc, 0)
        self.assertIn("aucun run", out)
        self.assertEqual(self.report()["total"]["runs"], 0)

    def test_missing_directory(self):
        rc, _, err = cli("--dir", str(Path(self.d) / "absent"))
        self.assertEqual(rc, 2)
        self.assertIn("introuvable", err)

    def test_bad_since(self):
        self.assertEqual(cli("--dir", self.d, "--since", "hier")[0], 2)

    def test_negative_cases_ignored_and_counted(self):
        write(self.d, "ok.json", run(1))
        write(self.d, "pasjson.json", "{ceci n'est pas du json")
        write(self.d, "autre.json", {"schema": "mission-result.v2", "ticket_issue": 2})
        write(self.d, "liste.json", [1, 2])
        manquant = run(3)
        del manquant["num_turns"]
        write(self.d, "manquant.json", manquant)
        write(self.d, "booleen.json", run(4, turns=True))
        write(self.d, "statut.json", run(5, status="LIMIT"))
        rep = self.report()
        self.assertEqual(rep["total"]["runs"], 1)
        self.assertEqual(rep["ignored"], {"illisible": 1, "schema_inconnu": 2, "champ_manquant": 3, "avant_since": 0})

    def test_aggregation_by_model_and_ticket(self):
        for i, t in enumerate([2, 4, 6, 8, 10, 12, 14, 16, 18, 20]):
            write(self.d, f"a{i}.json", run(7, turns=t, cost=0.5))
        write(self.d, "b.json", run(8, model="claude-opus-5-5", status="FAIL", failure="no_branch", cost=2.0))
        rep = self.report()
        sonnet = rep["by_model"]["claude-sonnet-5-5"]
        self.assertEqual((sonnet["runs"], sonnet["turns"]["median"], sonnet["turns"]["p90"]), (10, 11, 18))
        self.assertEqual(sonnet["cost_usd_estimated"]["total"], 5.0)
        self.assertEqual(rep["by_ticket"]["8"]["failures"], {"no_branch": 1})
        self.assertEqual(rep["by_ticket"]["8"]["statuses"], {"FAIL": 1})
        self.assertEqual(rep["schema"], "factory-stats.v1")

    def test_repeated_denials_aggregated(self):
        write(self.d, "a.json", run(1, permission_denials=["Bash:git push", "Edit", "Bash:git push"]))
        write(self.d, "b.json", run(2, permission_denials=["Bash:git push", "WebFetch"]))
        den = self.report()["total"]["permission_denials"]
        self.assertEqual(den, {"Bash:git push": 3, "Edit": 1, "WebFetch": 1})

    def test_since_filters_on_finished_at(self):
        write(self.d, "old.json", run(1, finished_at="2026-11-01T10:00:00Z"))
        write(self.d, "new.json", run(2, finished_at="2026-11-18T10:00:00Z"))
        rep = self.report("--since", "2026-11-10")
        self.assertEqual(rep["total"]["runs"], 1)
        self.assertEqual(rep["ignored"]["avant_since"], 1)
        self.assertEqual(rep["since"], "2026-11-10")

    def test_recursive_artifact_layout(self):
        write(self.d, "mission-result-5/mission-result-5.json", run(5))
        self.assertEqual(self.report()["total"]["runs"], 1)

    def test_markdown_default(self):
        write(self.d, "a.json", run(9))
        rc, out, _ = cli("--dir", self.d)
        self.assertEqual(rc, 0)
        self.assertIn("### Par modèle demandé", out)
        self.assertIn("| 9 | 1 |", out)

    def test_no_sensitive_content_in_output(self):
        secret = "ghp_SECRETVALUE123"
        os.environ["STATS_TEST_ENV_SECRET"] = "valeur-env-secrete"
        self.addCleanup(os.environ.pop, "STATS_TEST_ENV_SECRET", None)
        write(self.d, "a.json", run(
            1, model_observed=secret, failure=secret, prompt="PROMPT-CORPS", tool_output="SORTIE-OUTIL",
            permission_denials=["Bash:git push", f"Bash {secret} --token=abc", {"tool_input": secret}, "x" * 500]))
        for args in ((), ("--json",)):
            _, out, _ = cli("--dir", self.d, *args)
            for forbidden in (secret, "PROMPT-CORPS", "SORTIE-OUTIL", "valeur-env-secrete", "--token"):
                self.assertNotIn(forbidden, out)
        den = self.report()["total"]["permission_denials"]
        self.assertEqual(den, {"?": 3, "Bash:git push": 1})
        self.assertEqual(self.report()["total"]["failures"], {"autre": 1})


if __name__ == "__main__":
    unittest.main()
