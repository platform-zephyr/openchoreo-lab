"""Tests de tools/backlog/status.py (T-473) : un backlog factice par cas, aucun accès réseau ni cluster."""
import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "backlog"))
import status  # noqa: E402


def ticket(tid, st="todo", deps="[]", criteria="- [ ] a", notes="", issue="null", title=None):
    notes_block = f"\n## Notes\n{notes}\n" if notes else ""
    return (f"---\nid: {tid}\ntitle: \"{title or 'Titre ' + tid}\"\nstatus: {st}\nphase: P0\nadr: []\n"
            f"depends_on: {deps}\nclass: AUTONOME\nvelocity: false\nlane: l\nstage: S0\ngithub_issue: {issue}\n---\n"
            f"# {tid}\n\n## Périmètre de fichiers\ntools/x.py\n\n## Critères de fin\n{criteria}\n{notes_block}")


class StatusTest(unittest.TestCase):
    def make(self, **tickets):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        b = Path(tmp.name)
        for tid, text in tickets.items():
            (b / f"{tid.replace('_', '-')}-x.md").write_text(text, encoding="utf-8")
        return b

    def run_main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = status.main(list(args))
        return rc, out.getvalue(), err.getvalue()

    def test_counters_and_done_proof(self):
        b = self.make(
            T_001=ticket("T-001", "done", criteria="- [x] a\n- [x] b",
                         notes="Preuve 2026-11-17 puis 2026-11-18 : PR #8, `backlog/evidence/T-001.md`."),
            T_002=ticket("T-002", "todo", deps="[T-001]"))
        text = status.render(b)
        self.assertIn("| `done` | 1 |", text)
        self.assertIn("| `todo` | 1 |", text)
        self.assertIn("| **Total** | **2** |", text)
        done = text.split("## Fait")[1].split("## Gelés")[0]
        self.assertIn("2026-11-18", done)
        self.assertIn("`PR #8`", done)
        self.assertIn("backlog/evidence/T-001.md", done)
        self.assertIn("## À faire, prêts", text)
        self.assertIn("[T-002]", text.split("prêts")[1].split("bloqués par dépendance")[0])

    def test_done_without_proof_or_date(self):
        text = status.render(self.make(T_001=ticket("T-001", "done", criteria="- [x] a")))
        self.assertIn("| — | — | — |", text)

    def test_in_progress_reste_and_boxes(self):
        b = self.make(T_001=ticket("T-001", "in-progress", criteria="- [x] a\n- [ ] b\n- [ ] c",
                                   notes="Reste (2026-11-18) : le hook | Stop.", issue="49"))
        text = status.render(b)
        row = next(x for x in text.splitlines() if x.startswith("| [T-001]"))
        self.assertIn("1/3", row)
        self.assertIn("Reste (2026-11-18) : le hook \\| Stop.", row)
        self.assertIn("[#49](https://github.com/platform-zephyr/openchoreo-lab/issues/49)", row)

    def test_blocked_reason(self):
        text = status.render(self.make(T_001=ticket("T-001", "blocked", notes="Bloqué par : ADR non atteint.")))
        self.assertIn("Bloqué par : ADR non atteint.", text)

    def test_todo_waiting_on_dependency(self):
        b = self.make(T_001=ticket("T-001", "in-progress", notes="Reste : x"),
                      T_002=ticket("T-002", "todo", deps="[T-001]"))
        text = status.render(b)
        waiting = text.split("bloqués par dépendance")[1].split("## Fait")[0]
        self.assertIn("T-001 (in-progress)", waiting)

    def test_negative_ticket_without_criteria(self):
        text = status.render(self.make(T_001=ticket("T-001", "todo", criteria="Rien à cocher.")))
        self.assertIn("aucun critère", text)
        self.assertIn("T-001 : aucun critère de fin", text)

    def test_negative_unknown_dependency(self):
        text = status.render(self.make(T_001=ticket("T-001", "todo", deps="[T-999]")))
        self.assertIn("T-999 (inconnue)", text)
        self.assertIn("T-001 : dépendance inconnue T-999", text)
        self.assertNotIn("[T-001]", text.split("prêts")[1].split("bloqués par dépendance")[0])

    def test_negative_unreadable_header(self):
        b = self.make(T_001=ticket("T-001"))
        (b / "T-002-x.md").write_text("pas d'en-tête\n", encoding="utf-8")
        self.assertIn("T-002-x.md : en-tête illisible", status.render(b))

    def test_deterministic_and_natural_order(self):
        b = self.make(T_010=ticket("T-010"), T_002=ticket("T-002"), T_061b=ticket("T-061b"))
        first = status.render(b)
        self.assertEqual(first, status.render(b))
        self.assertLess(first.index("[T-002]"), first.index("[T-010]"))
        self.assertLess(first.index("[T-010]"), first.index("[T-061b]"))
        self.assertNotRegex(first, r"[Gg]énéré le|\d\d:\d\d:\d\d")

    def test_write_then_check_then_stale(self):
        b = self.make(T_001=ticket("T-001"))
        self.assertEqual(self.run_main("--backlog", str(b), "--check")[0], 1)  # absent = périmé
        self.assertEqual(self.run_main("--backlog", str(b), "--write")[0], 0)
        self.assertEqual(self.run_main("--backlog", str(b), "--check")[0], 0)
        (b / "T-001-x.md").write_text(ticket("T-001", "done", criteria="- [x] a"), encoding="utf-8")
        rc, _, err = self.run_main("--backlog", str(b), "--check")
        self.assertEqual(rc, 1)
        self.assertIn("PÉRIMÉ", err)

    def test_check_does_not_modify(self):
        b = self.make(T_001=ticket("T-001"))
        (b / "STATUS.md").write_text("vieux\n", encoding="utf-8")
        self.run_main("--backlog", str(b), "--check")
        self.assertEqual((b / "STATUS.md").read_text(encoding="utf-8"), "vieux\n")

    def test_real_backlog_in_sync_shape(self):
        text = status.render(ROOT / "backlog")
        self.assertIn("## Compteurs", text)


if __name__ == "__main__":
    unittest.main()
