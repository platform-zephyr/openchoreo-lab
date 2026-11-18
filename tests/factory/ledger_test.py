"""Tests hors ligne de tools/factory/ledger.py et tools/cost/agent_usage.py (T-326)."""
import json
import sys
import tempfile
import unittest
import unittest.mock
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


def execution(path, result_text, is_error=True, subtype="success", jsonl=False):
    """Sortie de claude-code-action : init, un tour d'agent, puis le message final `result`."""
    msgs = [{"type": "system", "subtype": "init", "model": "claude-sonnet-5-5"},
            {"type": "assistant", "message": {"content": [{"type": "text", "text": "travail"}]}},
            {"type": "result", "subtype": subtype, "is_error": is_error, "num_turns": 3, "result": result_text}]
    text = "\n".join(json.dumps(m) for m in msgs) if jsonl else json.dumps(msgs)
    Path(path).write_text(text, encoding="utf-8")
    return Path(path)


class DisjoncteurDeQuotaTest(unittest.TestCase):
    """T-467 : detection de la limite d'usage Max dans la sortie d'un run, et blocage du planificateur."""

    NOW = "2026-11-18T10:00:00Z"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.state = self.dir / "factory" / "LIMIT.json"

    def tearDown(self):
        self.tmp.cleanup()

    def run_detect(self, exe, *extra):
        return ledger.main(["detect", "--execution-file", str(exe), "--state", str(self.state),
                            "--now", self.NOW, *extra])

    def test_formes_officielles(self):
        # https://code.claude.com/docs/en/errors, section « Usage limits ».
        cases = {"You've hit your session limit · resets 3:45pm": "session",
                 "You've hit your weekly limit · resets Mon 12:00am": "weekly",
                 "You\u2019ve hit your Opus limit · resets 3:45pm": "opus",
                 "You've hit your Sonnet limit · resets 3:45pm": "sonnet",
                 "Claude AI usage limit reached|1795010400": "usage"}
        for text, kind in cases.items():
            with self.subTest(text=text):
                self.assertEqual(ledger.limit_kind(text), kind)

    def test_throttles_et_quota_ne_sont_pas_confondus(self):
        for text in ("API Error: Rate limit reached", "Server is temporarily limiting requests",
                     "Request rejected (429)", "API Error: Repeated 529 Overloaded errors",
                     "You've hit your monthly spend limit", "tests passed"):
            with self.subTest(text=text):
                self.assertIsNone(ledger.limit_kind(text))

    def test_detect_ouvre_le_disjoncteur_session(self):
        exe = execution(self.dir / "exec.json", "You've hit your session limit · resets 3:45pm")
        self.assertEqual(self.run_detect(exe, "--issue", "66", "--model", "claude-sonnet-5-5"), ledger.EXIT_OPEN)
        info = json.loads(self.state.read_text())
        self.assertEqual((info["state"], info["kind"], info["resume"]), ("open", "session", "manual"))
        self.assertEqual(info["resume_at"], "2026-11-18T15:45:00+00:00")
        self.assertEqual(info["ticket_issue"], 66)
        self.assertEqual(ledger.check(self.state), ledger.EXIT_OPEN)

    def test_detect_jsonl_et_reset_hebdomadaire(self):
        # 2026-11-18 est un mercredi : « Mon 12:00am » = lundi 23 novembre 00:00 UTC.
        exe = execution(self.dir / "exec.jsonl", "You've hit your weekly limit · resets Mon 12:00am", jsonl=True)
        self.assertEqual(self.run_detect(exe), ledger.EXIT_OPEN)
        self.assertEqual(json.loads(self.state.read_text())["resume_at"], "2026-11-23T00:00:00+00:00")

    def test_reset_dans_le_fuseau_du_message_et_epoch(self):
        now = datetime(2026, 11, 18, 10, 0, tzinfo=UTC)
        r = {"limit": {"message": "You've hit your session limit · resets 3pm (Europe/Paris)"}}
        self.assertEqual(ledger.reset_time(r, now).isoformat(), "2026-11-18T14:00:00+00:00")
        r = {"limit": {"message": "Claude AI usage limit reached|1795010400"}}
        self.assertEqual(ledger.reset_time(r, now), datetime.fromtimestamp(1795010400, UTC))
        r = {"limit": {"message": "weekly limit · resets Wed 9am"}}  # deja passe aujourd'hui : semaine suivante
        self.assertEqual(ledger.reset_time(r, now).isoformat(), "2026-11-25T09:00:00+00:00")

    def test_detect_negatifs_aucune_ecriture(self):
        cases = {
            "succes": ("Livre : PR #70", False),
            "succes qui cite le message": ("Ticket T-467 : detecter « You've hit your session limit »", False),
            "throttle serveur": ("API Error: Rate limit reached", True),
            "surcharge": ("API Error: Repeated 529 Overloaded errors", True),
            "compte rendu long en erreur": ("You've hit your session limit " + "x" * 700, True),
        }
        for name, (text, is_error) in cases.items():
            with self.subTest(name=name):
                exe = execution(self.dir / "exec.json", text, is_error=is_error)
                self.assertEqual(self.run_detect(exe), 0)
                self.assertFalse(self.state.exists())
        (self.dir / "vide.json").write_text("", encoding="utf-8")
        self.assertEqual(self.run_detect(self.dir / "vide.json"), 0)
        self.assertFalse(self.state.exists())

    def test_gate_planificateur(self):
        out = self.dir / "github_output"
        env = {"GITHUB_OUTPUT": str(out)}
        with unittest.mock.patch.dict("os.environ", env):
            self.assertEqual(ledger.main(["gate", "--state", str(self.state)]), 0)
            exe = execution(self.dir / "exec.json", "You've hit your session limit · resets 3:45pm")
            self.run_detect(exe)
            self.assertEqual(ledger.main(["gate", "--state", str(self.state)]), ledger.EXIT_OPEN)
        self.assertEqual(out.read_text().splitlines(), ["limited=false", "limited=true"])

    def test_limite_de_famille_ne_bloque_que_sa_famille(self):
        exe = execution(self.dir / "exec.json", "You've hit your Opus limit · resets 3:45pm")
        self.assertEqual(self.run_detect(exe, "--model", "claude-opus-5-5"), ledger.EXIT_OPEN)
        self.assertEqual(ledger.check(self.state, "claude-opus-5-5"), ledger.EXIT_OPEN)
        self.assertEqual(ledger.check(self.state, "claude-sonnet-5-5"), 0)
        self.assertEqual(ledger.check(self.state), ledger.EXIT_OPEN)  # modele inconnu : sens sur

    def test_etat_illisible_reste_ouvert(self):
        self.state.parent.mkdir(parents=True)
        self.state.write_text("{pas du json", encoding="utf-8")
        self.assertEqual(ledger.check(self.state, "claude-sonnet-5-5"), ledger.EXIT_OPEN)


if __name__ == "__main__":
    unittest.main(verbosity=2)
