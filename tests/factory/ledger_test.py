"""Tests hors ligne de tools/factory/ledger.py et tools/cost/agent_usage.py (T-326)."""
import json
import sys
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "factory"))
sys.path.insert(0, str(ROOT / "tools" / "cost"))
import agent_usage  # noqa: E402
import ledger  # noqa: E402


def result(issue, ts, agent="agent-a", cost=1.0, turns=10, dur=1000, tok=100, **extra):
    r = {"schema": "mission-result.v1", "ticket_issue": issue, "finished_at": ts, "agent": agent,
         "status": "PASS", "num_turns": turns, "duration_ms": dur, "total_cost_usd": cost,
         "tokens": {"input_tokens": tok, "output_tokens": tok, "cache_read_input_tokens": 0,
                    "cache_creation_input_tokens": 0}}
    r.update(extra)
    return r


def write(d, *rs):
    for r in rs:
        (Path(d) / f"r{r['ticket_issue']}.json").write_text(json.dumps(r), encoding="utf-8")


class LedgerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = Path(self.tmp.name) / "results"
        self.d.mkdir()
        self.state = Path(self.tmp.name) / "state" / "LIMIT.json"

    def tearDown(self):
        self.tmp.cleanup()

    def test_blocs_5h_et_semaines(self):
        write(self.d,
              result(1, "2026-11-16T09:10:00Z", cost=1.5, turns=10, dur=1000, tok=100),
              result(2, "2026-11-16T13:59:00Z", cost=0.5, turns=5, dur=500, tok=50),   # meme bloc (09h-14h)
              result(3, "2026-11-16T14:00:00Z", cost=2.0, turns=7, dur=700, tok=10),   # nouveau bloc
              result(4, "2026-11-23T00:30:00Z", cost=1.0))                               # semaine suivante
        (self.d / "autre.json").write_text('{"schema": "x"}')
        rep = ledger.report(ledger.load_results(self.d))
        b = rep["blocks_5h"]
        self.assertEqual([x["missions"] for x in b], [2, 1, 1])
        self.assertEqual(b[0]["turns"], 15)
        self.assertEqual(b[0]["duration_ms"], 1500)
        self.assertEqual(b[0]["input_tokens"], 150)
        self.assertEqual(b[0]["output_tokens"], 150)
        self.assertAlmostEqual(b[0]["cost_usd_estimated"], 2.0)
        w = rep["weeks"]
        self.assertEqual([x["week_start"] for x in w], ["2026-11-16", "2026-11-23"])
        self.assertEqual(w[0]["missions"], 3)
        self.assertAlmostEqual(w[0]["cost_usd_estimated"], 4.0)

    def test_agregat_hebdo_par_agent(self):
        write(self.d,
              result(1, "2026-11-16T09:00:00Z", agent="a", cost=1.0),
              result(2, "2026-11-17T09:00:00Z", agent="b", cost=2.0),
              result(3, "2026-11-18T09:00:00Z", agent="a", cost=3.0))
        got = {r["agent"]: (r["missions"], r["cost_usd_estimated"]) for r in agent_usage.weekly_by_agent(self.d)}
        self.assertEqual(got, {"a": (2, 4.0), "b": (1, 2.0)})

    def test_disjoncteur_limit_arrete_sans_relance(self):
        now = datetime(2026, 11, 18, 10, 0, tzinfo=UTC)
        write(self.d, result(1, "2026-11-18T09:00:00Z"),
              result(2, "2026-11-18T09:30:00Z", status="FAIL",
                     limit={"message": "5-hour session limit reached - resets 3pm (UTC)"}))
        self.assertEqual(ledger.check(self.state), 0)
        self.assertEqual(ledger.trip(ledger.load_results(self.d), self.state, now), ledger.EXIT_OPEN)
        info = json.loads(self.state.read_text())
        self.assertEqual(info["resume_at"], "2026-11-18T15:00:00+00:00")
        self.assertEqual(info["resume"], "manual")
        # Disjoncteur ouvert : aucun lancement, meme apres le reset annonce (pas de relance automatique).
        self.assertEqual(ledger.check(self.state), ledger.EXIT_OPEN)
        # Reprise manuelle par Paul.
        self.assertEqual(ledger.main(["reset", "--state", str(self.state)]), 0)
        self.assertEqual(ledger.check(self.state), 0)

    def test_reset_iso_et_sans_limit(self):
        now = datetime(2026, 11, 18, 10, 0, tzinfo=UTC)
        write(self.d, result(1, "2026-11-18T09:00:00Z"))
        self.assertEqual(ledger.trip(ledger.load_results(self.d), self.state, now), 0)
        self.assertFalse(self.state.exists())
        write(self.d, result(2, "2026-11-18T09:05:00Z", status="LIMIT", limit={"reset_at": "2026-11-18T14:00:00Z"}))
        rc = ledger.main(["trip", "--results", str(self.d), "--state", str(self.state),
                          "--now", "2026-11-18T10:00:00Z"])
        self.assertEqual(rc, ledger.EXIT_OPEN)
        self.assertEqual(json.loads(self.state.read_text())["resume_at"], "2026-11-18T14:00:00+00:00")

    def test_message_et_reset_du_lendemain(self):
        now = datetime(2026, 11, 18, 16, 0, tzinfo=UTC)
        self.assertTrue(ledger.classify_message("Claude usage limit reached"))
        self.assertFalse(ledger.classify_message("tests passed"))
        r = {"limit": {"message": "weekly limit reached, resets 9am"}}
        self.assertEqual(ledger.reset_time(r, now).isoformat(), "2026-11-19T09:00:00+00:00")


if __name__ == "__main__":
    unittest.main(verbosity=2)
