"""Tests du statut dérivé (tools/backlog/derive.py) et de son branchement dans check.py, priority.py, next.py, status.py.

Chaque cas construit un petit dépôt git local dans un dossier temporaire : aucun accès réseau, aucune API GitHub.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "backlog"))
import check  # noqa: E402
import derive  # noqa: E402
import next as nxt  # noqa: E402
import priority  # noqa: E402
import status  # noqa: E402

GIT = shutil.which("git")
ENV = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.invalid", "GIT_COMMITTER_NAME": "t",
       "GIT_COMMITTER_EMAIL": "t@example.invalid", "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1"}


def ticket(tid, st="todo", criteria="- [ ] a", deps="[]", notes="", issue="null"):
    notes_block = f"\n## Notes\n{notes}\n" if notes else ""
    return (f"---\nid: {tid}\ntitle: \"t {tid}\"\nstatus: {st}\nphase: P0\nadr: [0001]\ndepends_on: {deps}\n"
            f"class: AUTONOME\nvelocity: false\nlane: l\nstage: S0\nmodel: claude-sonnet-5-5\neffort: high\n"
            f"github_issue: {issue}\n---\n# {tid}\n\n## Périmètre de fichiers\ntools/x.py\n\n"
            f"## Critères de fin\n{criteria}\n{notes_block}")


def ev(**kw):
    return derive.Evidence(available=True, ref="origin/main", **kw)


class DeriveRule(unittest.TestCase):
    """La règle seule, sur des preuves construites à la main."""

    def test_done_needs_all_boxes_and_a_merged_pr(self):
        self.assertEqual(derive.derive("T-1", "in-progress", "- [x] a\n- [x] b", ev(trailers={"T-1"})), "done")
        self.assertEqual(derive.derive("T-1", "todo", "- [x] a", ev(subjects={"T-1"})), "done")

    def test_open_box_with_merged_pr_is_in_progress(self):
        self.assertEqual(derive.derive("T-1", "done", "- [x] a\n- [ ] b", ev(trailers={"T-1"})), "in-progress")

    def test_branch_or_checked_box_is_in_progress(self):
        self.assertEqual(derive.derive("T-1", "todo", "- [ ] a", ev(branch_tickets={"T-1"})), "in-progress")
        self.assertEqual(derive.derive("T-1", "todo", "- [ ] a", ev(branch_issues={"42"}), "42"), "in-progress")
        self.assertEqual(derive.derive("T-1", "todo", "- [x] a\n- [ ] b", ev()), "in-progress")

    def test_nothing_is_todo(self):
        self.assertEqual(derive.derive("T-1", "in-progress", "- [ ] a", ev()), "todo")

    def test_no_box_is_never_done(self):
        self.assertEqual(derive.derive("T-1", "todo", "Rien à cocher.", ev(trailers={"T-1"})), "in-progress")

    def test_manual_statuses_are_kept(self):
        for st in ("blocked", "deferred", "dropped"):
            self.assertEqual(derive.derive("T-1", st, "- [x] a", ev(trailers={"T-1"})), st)

    def test_declared_done_with_all_boxes_is_kept_without_pr(self):
        """Rétro-compatibilité : clôtures antérieures aux trailers et gestes humains sans PR."""
        self.assertEqual(derive.derive("T-1", "done", "- [x] a", ev()), "done")

    def test_without_git_history_the_header_wins(self):
        self.assertEqual(derive.derive("T-1", "in-progress", "- [x] a", derive.Evidence()), "in-progress")

    def test_squash_subject_tickets(self):
        self.assertEqual(derive.subject_tickets("feat(x): y (T-12, en partie) (#9)"), {"T-12"})
        self.assertEqual(derive.subject_tickets("docs: preuves (T-1, T-2b) (#3)"), {"T-1", "T-2b"})
        self.assertEqual(derive.subject_tickets("docs(backlog): T-1 et T-2 (#4)"), set())  # hors parenthèses
        self.assertEqual(derive.subject_tickets("feat(x): y (T-12)"), set())  # pas une fusion squash


@unittest.skipUnless(GIT, "git absent")
class GitRepo(unittest.TestCase):
    """Preuves lues dans un vrai dépôt git local (sans remote, sans réseau)."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        (self.root / "backlog").mkdir()
        (self.root / "docs" / "adr").mkdir(parents=True)
        (self.root / "docs" / "adr" / "0001-x.md").write_text("# ADR\n")
        self.git("init", "-q", "-b", "main")
        self.commit("init")

    def git(self, *args):
        return subprocess.run([GIT, "-C", str(self.root), *args], env=ENV, check=True, capture_output=True,
                              text=True).stdout

    def commit(self, msg):
        self.git("add", "-A")
        self.git("commit", "-q", "--allow-empty", "-m", msg)

    def add(self, tid, **kw):
        (self.root / "backlog" / f"{tid}-x.md").write_text(ticket(tid, **kw), encoding="utf-8")

    def test_trailer_on_main_closes_a_checked_ticket(self):
        self.add("T-214", st="in-progress", criteria="- [x] a\n- [x] b")
        self.commit("refactor(appgen): paquet (#100)\n\n* detail\n\nTicket: T-214\nModel: claude-opus-5-5")
        e = derive.collect(self.root)
        self.assertTrue(e.available)
        self.assertEqual(e.ref, "main")  # pas d'origin/main : retombée sur main local
        self.assertIn("T-214", e.trailers)
        self.assertEqual([n.status for n in priority.load_nodes(self.root / "backlog")], ["done"])

    def test_claude_branch_marks_in_progress(self):
        self.add("T-050")
        self.add("T-051", issue="66")
        self.add("T-052")
        self.commit("docs: tickets")
        self.git("branch", "claude/t-050-verdicts")
        self.git("branch", "claude/issue-66-ci")
        self.git("checkout", "-q", "-b", "claude/sans-nom")
        self.commit("feat: travail\n\nTicket: T-052")
        self.git("checkout", "-q", "main")
        got = {i: t["status"] for i, t in nxt.load_tickets(self.root / "backlog").items()}
        self.assertEqual(got, {"T-050": "in-progress", "T-051": "in-progress", "T-052": "in-progress"})

    def test_disagreement_is_a_warning_never_an_error(self):
        self.add("T-214", st="in-progress", criteria="- [x] a")
        self.add("T-300", st="in-progress", criteria="- [ ] a")
        self.commit("feat: x (T-214) (#100)")
        r = check.check(self.root)
        self.assertEqual(r.errors, [])
        self.assertTrue(any(w.startswith("STATUT-DÉRIVÉ T-214 en-tête in-progress, calcul done") for w in r.warnings),
                        r.warnings)
        self.assertTrue(any(w.startswith("STATUT-DÉRIVÉ T-300 en-tête in-progress, calcul todo") for w in r.warnings),
                        r.warnings)

    def test_dependents_become_ready_when_derived_done(self):
        self.add("T-214", st="in-progress", criteria="- [x] a")
        self.add("T-215", deps="[T-214]")
        self.commit("feat: x\n\nTicket: T-214")
        self.assertEqual(priority.ready_ids(priority.load_nodes(self.root / "backlog")), {"T-215"})
        self.assertIn("T-214 : en-tête `in-progress`, statut dérivé `done`", status.render(self.root / "backlog"))

    def test_shallow_clone_falls_back_to_header(self):
        self.add("T-214", st="in-progress", criteria="- [x] a")
        self.commit("feat: x\n\nTicket: T-214")
        self.commit("chore: y")
        clone = self.root / "clone"
        subprocess.run([GIT, "clone", "-q", "--depth", "1", f"file://{self.root}", str(clone)], env=ENV, check=True)
        self.assertFalse(derive.collect(clone).available)
        self.assertEqual([n.status for n in priority.load_nodes(clone / "backlog")], ["in-progress"])

    def test_offline_uses_local_origin_main_without_fetch(self):
        """Mode local sans réseau : seule la référence déjà présente est lue (ici une origin/main posée à la main)."""
        self.add("T-214", st="in-progress", criteria="- [x] a")
        self.commit("feat: x\n\nTicket: T-214")
        self.git("update-ref", "refs/remotes/origin/main", "HEAD~1")  # origin/main en retard : trailer pas encore vu
        e = derive.collect(self.root)
        self.assertEqual(e.ref, "origin/main")
        self.assertNotIn("T-214", e.trailers)


class NoGit(unittest.TestCase):
    def test_not_a_repository_falls_back_to_header(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertFalse(derive.collect(Path(d)).available)

    def test_git_missing_falls_back_to_header(self):
        with tempfile.TemporaryDirectory() as d:
            old = os.environ["PATH"]
            os.environ["PATH"] = d
            try:
                self.assertFalse(derive.collect(ROOT).available)
            finally:
                os.environ["PATH"] = old


class Reste(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        (self.root / "backlog").mkdir()
        (self.root / "docs" / "adr").mkdir(parents=True)
        (self.root / "docs" / "adr" / "0001-x.md").write_text("# ADR\n")

    def warns(self, **kw):
        (self.root / "backlog" / "T-900-x.md").write_text(ticket("T-900", **kw), encoding="utf-8")
        return [w for w in check.check(self.root, derive.Evidence()).warnings if w.startswith("RESTE")]

    def test_all_checked_with_reste_warns(self):
        self.assertEqual(len(self.warns(st="done", criteria="- [x] a", notes="Reste : ouvrir la PR.")), 1)

    def test_reste_heading_section_warns(self):
        w = self.warns(st="in-progress", criteria="- [x] a", notes="x\n\n## Reste\n- relancer la CI")
        self.assertEqual(len(w), 1)

    def test_empty_reste_or_open_box_is_silent(self):
        self.assertEqual(self.warns(st="done", criteria="- [x] a", notes="Reste : rien."), [])
        self.assertEqual(self.warns(st="in-progress", criteria="- [x] a\n- [ ] b", notes="Reste : b."), [])
        self.assertEqual(self.warns(st="dropped", criteria="- [x] a", notes="Reste : x."), [])

    def test_reste_is_a_warning_not_an_error(self):
        (self.root / "backlog" / "T-900-x.md").write_text(
            ticket("T-900", st="done", criteria="- [x] a", notes="Reste : x."), encoding="utf-8")
        self.assertEqual(check.check(self.root, derive.Evidence()).errors, [])


if __name__ == "__main__":
    unittest.main()
