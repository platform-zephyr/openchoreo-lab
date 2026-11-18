"""Tests de tools/metrics/ingest/ sur jeu synthetique (T-201). Stdlib ; les tests Parquet sont SKIP sans pyarrow."""
import json
import sys
import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools" / "metrics" / "ingest"))
import dora
import github_api
import ingest
import model
import store

try:
    import pyarrow  # noqa: F401
    HAVE_ARROW = True
except ImportError:
    HAVE_ARROW = False

NOW = datetime(2026, 11, 18, 12, 0, tzinfo=UTC)
SECRET_BODY = "Reverts #3\n\ntoken ghp_" + "A" * 36  # fabrique a l'execution : aucun secret reel


def iso(days_ago: float, hours: float = 0) -> str:
    return (NOW - timedelta(days=days_ago, hours=hours)).strftime("%Y-%m-%dT%H:%M:%SZ")


def make_pr(n, days_ago, lead_h=2.0, ref="claude/t-1-x", labels=("class:AUTONOME",), title="feat: x", body="corps prive",
            merged=True, user_type="User"):
    created = NOW - timedelta(days=days_ago, hours=lead_h)
    return {
        "number": n, "title": title, "body": body, "created_at": created.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "updated_at": iso(days_ago), "merged_at": iso(days_ago) if merged else None, "closed_at": iso(days_ago),
        "labels": [{"name": x} for x in labels], "head": {"ref": ref}, "user": {"login": "someone", "type": user_type},
    }


class FakeClient:
    """Imite Client : sert les pages depuis un dict, compte les requetes et applique le budget."""

    def __init__(self, pulls, files, reviews, runs, budget=900):
        self.pulls, self.files, self.reviews, self.runs = pulls, files, reviews, runs
        self.used, self.budget = 0, budget

    def pages(self, path, params, key=None, max_pages=10):
        if self.used >= self.budget:
            raise github_api.BudgetExhausted("budget")
        self.used += 1
        if path == "pulls":
            return iter(self.pulls)
        if path == "actions/runs":
            return iter(self.runs)
        num = int(path.split("/")[1])
        if path.endswith("/files"):
            return iter([{"filename": f} for f in self.files.get(num, [])])
        return iter(self.reviews.get(num, []))


def synthetic_client(budget=900):
    pulls = [make_pr(1, 1, ref="claude/t-1-x"), make_pr(2, 2, ref="codex/t-2-y", labels=("class:REVUE",)),
             make_pr(3, 3, title="feat: z"), make_pr(4, 5, title="fix: z"),
             make_pr(5, 6), make_pr(6, 7, ref="feat/humain", user_type="User"),
             make_pr(7, 0.5, title="Revert \"feat: z\"", ref="revert-3", body=SECRET_BODY, labels=()),
             make_pr(8, 4, merged=False)]
    files = {n: ["apps/whoami/app.yaml"] for n in range(1, 8)}
    files[5] = ["docs/x.md"]
    reviews = {2: [{"user": {"type": "User"}}], 3: [{"user": {"type": "Bot"}}]}
    runs = [{"id": i, "name": "ci", "event": "pull_request", "conclusion": "success", "head_branch": "claude/t-1-x",
             "created_at": iso(i % 5, 0.2), "updated_at": iso(i % 5)} for i in range(1, 7)]
    return FakeClient(pulls, files, reviews, runs, budget)


class ModelTests(unittest.TestCase):
    def test_projection_is_whitelist_without_body_title_login(self):
        row = model.pr_row(make_pr(7, 1, body=SECRET_BODY, title="Revert x"), ["apps/a/app.yaml"], 0)
        self.assertEqual(set(row), set(model.PR_FIELDS))
        blob = json.dumps(row)
        self.assertNotIn("ghp_", blob)
        self.assertNotIn("someone", blob)
        self.assertNotIn("corps", blob)
        self.assertEqual(row["reverts_pr"], 3)
        self.assertTrue(row["is_revert"])

    def test_derived_fields(self):
        self.assertEqual(model.classify_agent("claude/t-1", "User"), "claude")
        self.assertEqual(model.classify_agent("codex/x", "User"), "codex")
        self.assertEqual(model.classify_agent("x", "Bot"), "bot")
        self.assertEqual(model.classify_agent("x", "User"), "human")
        self.assertEqual(model.pr_class([{"name": "class:revue"}]), "REVUE")
        self.assertEqual(model.pr_class([{"name": "bug"}]), "unknown")
        self.assertEqual(model.pr_row(make_pr(1, 1), ["apps/a/x", "apps/b/y"], 0)["app"], "multi")
        self.assertEqual(model.pr_row(make_pr(1, 1), ["docs/x"], 0)["deploy_scope"], False)
        self.assertFalse(model.pr_row(make_pr(1, 1), None, None)["enriched"])

    def test_secret_value_refused_by_store(self):
        row = {"pr_number": 1, "created_at": iso(1), "agent": "ghp_" + "B" * 36}
        with self.assertRaises(ValueError):
            store.upsert(store.MemoryStore(), "pr", [row])


class IdempotenceTests(unittest.TestCase):
    def test_replay_over_14_days_has_no_duplicates(self):
        st = store.MemoryStore()
        first = ingest.ingest(synthetic_client(), st, NOW)
        snapshot = {k: list(v) for k, v in st.parts.items()}
        for _ in range(3):
            ingest.ingest(synthetic_client(), st, NOW)
        self.assertEqual(st.parts, snapshot)
        keys = [r["pr_number"] for r in ingest.load(st, "pr")]
        self.assertEqual(len(keys), len(set(keys)), "doublon de PR")
        self.assertEqual(len(keys), 8)
        run_keys = [r["run_id"] for r in ingest.load(st, "run")]
        self.assertEqual(len(run_keys), len(set(run_keys)))
        self.assertFalse(first["truncated"])

    def test_partial_replays_keep_other_rows_of_the_partition(self):
        st = store.MemoryStore()
        store.upsert(st, "pr", [model.pr_row(make_pr(1, 1)), model.pr_row(make_pr(2, 1))])
        store.upsert(st, "pr", [model.pr_row(make_pr(2, 1, title="fix: y"))])
        rows = ingest.load(st, "pr")
        self.assertEqual([r["pr_number"] for r in rows], [1, 2])
        self.assertTrue(rows[1]["is_fix"])

    def test_window_excludes_old_pull_requests(self):
        client = synthetic_client()
        client.pulls.append(make_pr(99, 30))  # trie par update desc : doit rester en queue
        st = store.MemoryStore()
        ingest.ingest(client, st, NOW, days=14)
        self.assertNotIn(99, [r["pr_number"] for r in ingest.load(st, "pr")])

    def test_budget_is_counted_and_truncation_degrades(self):
        client = synthetic_client(budget=4)
        st = store.MemoryStore()
        summary = ingest.ingest(client, st, NOW)
        self.assertLessEqual(client.used, 4)
        self.assertTrue(summary["truncated"])
        self.assertTrue(any(not r["enriched"] for r in ingest.load(st, "pr")))

    def test_real_client_budget_and_read_only(self):
        calls = []

        class Resp:
            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

            def read(self, *a):
                return b"[]"

        def opener(req, timeout):
            calls.append(req)
            return Resp()

        c = github_api.Client("o/r", budget=2, token="x", opener=opener)
        c.get("pulls")
        c.get("pulls")
        with self.assertRaises(github_api.BudgetExhausted):
            c.get("pulls")
        self.assertTrue(all(r.get_method() == "GET" for r in calls))
        self.assertEqual(len(calls), 2)


def row(n, merged_days_ago, **kw):
    base = {"pr_number": n, "created_at": iso(merged_days_ago, 2), "merged_at": iso(merged_days_ago), "agent": "claude",
            "class": "AUTONOME", "app": "whoami", "deploy_scope": True, "is_revert": False, "is_fix": False,
            "reverts_pr": None, "human_reviews": 0, "enriched": True}
    base.update(kw)
    return base


def cell(cells, metric, window=30, dim="all", key="all"):
    return next(c for c in cells if (c["metric"], c["window_days"], c["dimension"], c["key"]) == (metric, window, dim, key))


class FormulaTests(unittest.TestCase):
    def setUp(self):
        # 10 deploys sur 30 j : lead 2 h ; PR 3 annulee par la PR 11 apres 6 h ; PR 4 est un fix ; 5 avec revue humaine.
        self.prs = [row(n, n) for n in range(1, 11)]
        self.prs[2]["merged_at"] = iso(3)
        self.prs[3]["is_fix"] = True
        for r in self.prs[:5]:
            r["human_reviews"] = 1
        self.prs.append(row(11, 3 - 0.25, is_revert=True, reverts_pr=3, created_at=iso(3, 1)))
        self.runs = [{"run_id": i, "conclusion": "success", "created_at": iso(1, 0.5), "updated_at": iso(1),
                      "agent": "claude"} for i in range(5)]
        self.cells = dora.compute(self.prs, self.runs, NOW)

    def test_deploy_frequency(self):
        c = cell(self.cells, "deploy_frequency")
        self.assertEqual(c["n"], 11)
        self.assertAlmostEqual(c["value"], 11 / 30, places=4)

    def test_lead_time_median(self):
        self.assertAlmostEqual(cell(self.cells, "lead_time_hours")["value"], 2.0, places=3)

    def test_change_fail_rate_and_recovery(self):
        self.assertAlmostEqual(cell(self.cells, "change_fail_rate")["value"], 1 / 11, places=4)
        # recovery : n=1 < 5 -> non publie
        rec = cell(self.cells, "recovery_time_hours")
        self.assertEqual((rec["n"], rec["status"], rec["value"]), (1, "insuffisant", None))

    def test_recovery_time_median_when_n_reaches_5(self):
        prs = [row(n, 10 + n) for n in range(1, 6)]
        for n in range(1, 6):  # chaque PR est annulee 6 h apres sa fusion
            prs.append(row(20 + n, 10 + n - 0.25, is_revert=True, reverts_pr=n))
        c = cell(dora.compute(prs, [], NOW), "recovery_time_hours")
        self.assertEqual((c["n"], c["status"]), (5, "ok"))
        self.assertAlmostEqual(c["value"], 6.0, places=3)
        self.assertAlmostEqual(cell(dora.compute(prs, [], NOW), "change_fail_rate")["value"], 5 / 10, places=4)

    def test_rework_and_autonomy(self):
        self.assertAlmostEqual(cell(self.cells, "rework_rate")["value"], 2 / 11, places=4)  # fix + revert
        self.assertAlmostEqual(cell(self.cells, "autonomy_rate")["value"], 6 / 11, places=4)

    def test_ci_loop(self):
        c = cell(self.cells, "ci_loop_minutes")
        self.assertEqual(c["n"], 5)
        self.assertAlmostEqual(c["value"], 30.0, places=3)

    def test_small_n_is_insufficient_and_not_published(self):
        c = cell(self.cells, "deploy_frequency", dim="app", key="whoami")
        self.assertEqual(c["n"], 11)
        few = dora.compute(self.prs[:4], [], NOW)
        c = cell(few, "lead_time_hours")
        self.assertEqual((c["n"], c["status"], c["value"]), (4, "insuffisant", None))
        c5 = cell(dora.compute(self.prs[:5], [], NOW), "lead_time_hours")
        self.assertEqual(c5["status"], "ok")

    def test_dimensions_agent_class_app_cluster(self):
        prs = [row(n, n, agent="codex" if n % 2 else "claude", **{"class": "REVUE" if n > 6 else "AUTONOME"})
               for n in range(1, 13)]
        cells = dora.compute(prs, [], NOW)
        self.assertEqual(cell(cells, "deploy_frequency", dim="agent", key="codex")["n"], 6)
        self.assertEqual(cell(cells, "deploy_frequency", dim="class", key="REVUE")["n"], 6)
        self.assertEqual(cell(cells, "deploy_frequency", dim="app", key="whoami")["n"], 12)
        self.assertEqual(cell(cells, "deploy_frequency", dim="cluster", key="unknown")["n"], 12)

    def test_window_7_vs_30(self):
        prs = [row(n, n) for n in range(1, 11)]
        self.assertEqual(cell(dora.compute(prs, [], NOW), "deploy_frequency", window=7)["n"], 7)  # 1..7 j (borne de 7 j incluse)

    def test_non_deploy_scope_excluded(self):
        prs = [row(n, n, deploy_scope=False) for n in range(1, 8)]
        self.assertEqual(cell(dora.compute(prs, [], NOW), "deploy_frequency")["n"], 0)

    def test_gold_is_deterministic_from_bronze(self):
        st = store.MemoryStore()
        ingest.ingest(synthetic_client(), st, NOW)
        a = json.dumps(ingest.gold(st, NOW), sort_keys=True)
        st2 = store.MemoryStore()
        ingest.ingest(synthetic_client(), st2, NOW)
        ingest.ingest(synthetic_client(), st2, NOW)
        self.assertEqual(a, json.dumps(ingest.gold(st2, NOW), sort_keys=True))
        self.assertNotIn("ghp_", a)


@unittest.skipUnless(HAVE_ARROW, "pyarrow absent : NOT_TESTED (test Parquet)")
class ParquetTests(unittest.TestCase):
    def test_replay_parquet_no_duplicates_no_body(self):
        import pyarrow.parquet as pq
        with tempfile.TemporaryDirectory() as d:
            st = store.ParquetStore(Path(d))
            ingest.ingest(synthetic_client(), st, NOW)
            files1 = {p: p.read_bytes() for p in Path(d).rglob("*.parquet")}
            ingest.ingest(synthetic_client(), st, NOW)
            ingest.ingest(synthetic_client(), st, NOW)
            files2 = {p: p.read_bytes() for p in Path(d).rglob("*.parquet")}
            self.assertEqual(files1, files2, "rejeu non idempotent")
            self.assertTrue(any("source=pr/dt=" in str(p) for p in files1))
            rows = ingest.load(st, "pr")
            self.assertEqual(len(rows), len({r["pr_number"] for r in rows}))
            for p in files1:
                cols = set(pq.read_table(p).column_names)
                self.assertFalse(cols & {"body", "title", "login", "user"})
                self.assertNotIn(b"ghp_", p.read_bytes())
                self.assertNotIn(b"corps prive", p.read_bytes())
            self.assertFalse(list(Path(d).rglob("*.tmp")))


if __name__ == "__main__":
    unittest.main()
