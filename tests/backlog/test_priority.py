"""Tests de tools/backlog/priority.py (T-476) : score = descendants non terminés ; aucun accès réseau."""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "backlog"))
import priority  # noqa: E402
import status  # noqa: E402
from priority import Node  # noqa: E402


def n(tid, deps=(), st="todo", stage="S1", ex=True, size=1):
    return Node(tid, st, tuple(deps), stage, ex, size)


def write(d: Path, tid, deps="[]", st="todo", stage="S1", model="claude-sonnet-5-5", klass="AUTONOME",
          scope="tools/x.py"):
    (d / f"{tid}-x.md").write_text(
        f"---\nid: {tid}\ntitle: \"t\"\nstatus: {st}\nphase: P0\nadr: []\ndepends_on: {deps}\nclass: {klass}\n"
        f"velocity: false\nlane: l\nstage: {stage}\nmodel: {model}\neffort: high\n---\n# {tid}\n\n"
        f"## Périmètre de fichiers\n{scope}\n\n## Critères de fin\n- [ ] a\n", encoding="utf-8")


class Score(unittest.TestCase):
    def test_isolated_ticket_scores_zero(self):
        self.assertEqual(priority.scores([n("T-1")]), {"T-1": 0})

    def test_chain_counts_transitive_descendants(self):
        sc = priority.scores([n("T-1"), n("T-2", ["T-1"]), n("T-3", ["T-2"])])
        self.assertEqual(sc, {"T-1": 2, "T-2": 1, "T-3": 0})

    def test_diamond_counts_each_descendant_once(self):
        sc = priority.scores([n("A"), n("B", ["A"]), n("C", ["A"]), n("D", ["B", "C"])])
        self.assertEqual(sc["A"], 3)
        self.assertEqual(sc["B"], 1)

    def test_done_and_dropped_descendants_are_ignored(self):
        sc = priority.scores([n("T-1"), n("T-2", ["T-1"], "done"), n("T-3", ["T-1"], "dropped"),
                              n("T-4", ["T-1"], "deferred")])
        self.assertEqual(sc["T-1"], 1)  # `deferred` reste du travail en attente

    def test_unknown_dependency_is_an_error(self):
        with self.assertRaisesRegex(priority.PriorityError, "T-2 : dépendance inconnue T-9"):
            priority.scores([n("T-2", ["T-9"])])

    def test_cycle_is_an_error(self):
        with self.assertRaisesRegex(priority.PriorityError, "cycle"):
            priority.scores([n("A", ["B"]), n("B", ["A"])])


class Order(unittest.TestCase):
    def ids(self, nodes, only=None):
        return [x.id for x, _ in priority.rank(nodes, only)]

    def test_higher_score_first(self):
        nodes = [n("T-1"), n("T-2"), n("T-3", ["T-2"])]
        self.assertEqual(self.ids(nodes, {"T-1", "T-2"}), ["T-2", "T-1"])

    def test_ties_break_on_stage_then_scope_then_id(self):
        nodes = [n("T-10", stage="S2"), n("T-9", stage="S1", size=3), n("T-8", stage="S1", size=1),
                 n("T-7", stage="S1", size=1)]
        self.assertEqual(self.ids(nodes), ["T-7", "T-8", "T-9", "T-10"])

    def test_human_or_mandat_is_demoted_whatever_the_score(self):
        nodes = [n("T-1", ex=False), n("T-2", ["T-1"]), n("T-3", ["T-1"]), n("T-4")]
        self.assertEqual(self.ids(nodes, {"T-1", "T-4"}), ["T-4", "T-1"])

    def test_ready_ids_needs_all_dependencies_done(self):
        nodes = [n("A", st="done"), n("B", ["A"]), n("C", ["B"]), n("D", st="in-progress")]
        self.assertEqual(priority.ready_ids(nodes), {"B"})


class Cli(unittest.TestCase):
    def tmpdir(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        return Path(tmp.name)

    def backlog(self):
        d = self.tmpdir()
        write(d, "T-001", st="done")
        write(d, "T-002", deps="[T-001]")
        write(d, "T-003", deps="[T-002]")
        write(d, "T-004", deps="[T-001]", model="human", klass="AUTONOME + MANDAT")
        return d

    def run_main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = priority.main(list(args))
        return rc, out.getvalue(), err.getvalue()

    def test_json_ranking_of_ready_tickets(self):
        rc, out, _ = self.run_main("--backlog", str(self.backlog()), "--json")
        self.assertEqual(rc, 0)
        data = json.loads(out)
        self.assertEqual(data["schema"], "priority.v1")
        self.assertEqual([(r["id"], r["score"], r["executable"]) for r in data["ranking"]],
                         [("T-002", 1, True), ("T-004", 0, False)])

    def test_top_limits_rows(self):
        rc, out, _ = self.run_main("--backlog", str(self.backlog()), "--top", "1")
        self.assertEqual((rc, out.count("T-0")), (0, 1))

    def test_cycle_exits_2_with_clear_message(self):
        d = self.tmpdir()
        write(d, "T-001", deps="[T-002]")
        write(d, "T-002", deps="[T-001]")
        rc, _, err = self.run_main("--backlog", str(d))
        self.assertEqual(rc, 2)
        self.assertIn("cycle de dépendances", err)

    def test_status_shows_score_and_sorts_ready(self):
        text = status.render(self.backlog())
        self.assertIn("| Ticket | Score | Titre |", text)
        self.assertLess(text.index("[T-002]"), text.index("[T-004]"))

    def test_status_survives_unknown_dependency(self):
        d = self.tmpdir()
        write(d, "T-001", deps="[T-099]")
        self.assertIn("score de priorité indisponible", status.render(d))


if __name__ == "__main__":
    unittest.main()
