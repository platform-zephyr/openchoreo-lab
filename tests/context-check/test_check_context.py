import datetime as dt
import sys
import tempfile
import unittest
from pathlib import Path
from typing import ClassVar

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "context-check"))
import check_context as cc  # noqa: E402

TODAY = dt.date(2026, 11, 18)
HDR = "---\nowner: paul\nupdated: {d}\nreview_days: 7\n---\n"


def cfg(**over):
    c = cc.load_config(None)
    c["freshness_required"] = {}
    c["deny"] = []
    c.update(over)
    return c


class Base(unittest.TestCase):
    def setUp(self):
        self._t = tempfile.TemporaryDirectory()
        self.root = Path(self._t.name)

    def tearDown(self):
        self._t.cleanup()

    def w(self, rel, text):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")

    def codes(self, c=None):
        return [(i[0], i[1]) for i in cc.run(self.root, c or cfg(), TODAY)]


class TestSizes(Base):
    def test_ok(self):
        self.w("AGENTS.md", "# a\n" * 10)
        self.assertEqual(self.codes(), [])

    def test_too_many_lines(self):
        self.w("AGENTS.md", "x\n" * 61)
        self.assertIn(("ERREUR", "taille-lignes"), self.codes())

    def test_too_many_bytes(self):
        self.w("STATE.md", ("y" * 200 + "\n") * 40)
        self.assertIn(("ERREUR", "taille-octets"), self.codes())

    def test_total(self):
        self.w("AGENTS.md", "x\n" * 50)
        self.w("STATE.md", "x\n" * 50)
        c = cfg(always_loaded_total={"max_lines": 90, "max_bytes": 11000})
        self.assertIn(("ERREUR", "total-lignes"), self.codes(c))
        self.assertNotIn(("ERREUR", "total-lignes"), self.codes())


class TestLinks(Base):
    def test_valid_and_dead(self):
        self.w("AGENTS.md", "[ok](docs/a.md) [ko](docs/absent.md#x)\n")
        self.w("docs/a.md", "# a\n")
        found = cc.run(self.root, cfg(), TODAY)
        dead = [i for i in found if i[1] == "lien-mort"]
        self.assertEqual(len(dead), 1)
        self.assertIn("absent.md", dead[0][4])

    def test_ignores_urls_anchors_fences_templates(self):
        self.w("AGENTS.md", "[w](https://x.y/z) [a](#ancre) [t](apps/<nom>/app.yaml)\n```\n[c](nope.md)\n```\n")
        self.assertEqual([c for c in self.codes() if c[1] == "lien-mort"], [])

    def test_import_checked(self):
        self.w("CLAUDE.md", "@AGENTS.md\n")
        self.assertIn(("ERREUR", "lien-mort"), self.codes())
        self.w("AGENTS.md", "ok\n")
        self.assertNotIn(("ERREUR", "lien-mort"), self.codes())

    def test_relative_to_file(self):
        self.w("docs/a.md", "[b](b.md)\n")
        self.w("docs/b.md", "x\n")
        self.assertEqual(self.codes(), [])

    def test_research_skipped(self):
        self.w("docs/research/x.md", "[ko](absent.md)\n")
        self.assertEqual(self.codes(), [])


class TestFreshness(Base):
    req: ClassVar[dict[str, int]] = {"STATE.md": 7}

    def test_fresh(self):
        self.w("STATE.md", HDR.format(d="2026-11-15") + "ok\n")
        self.assertEqual(self.codes(cfg(freshness_required=self.req)), [])

    def test_stale(self):
        self.w("STATE.md", HDR.format(d="2026-11-01") + "ok\n")
        self.assertEqual(self.codes(cfg(freshness_required=self.req)), [("AVERTISSEMENT", "fraicheur-perime")])

    def test_stale_400_days_warns_and_exits_0(self):
        self.w("STATE.md", HDR.format(d="2025-10-14") + "ok\n")  # 400 jours avant TODAY
        self.w("missions/MISSION.md", HDR.format(d="2025-10-14") + "ok\n")
        found = cc.run(self.root, cfg(freshness_required=self.req), TODAY)
        self.assertEqual([(i[0], i[1]) for i in found], [("AVERTISSEMENT", "fraicheur-perime")] * 2)
        self.assertTrue(all("updated 2025-10-14" in i[4] and "âge 400 j" in i[4] for i in found))
        argv = ["--root", str(self.root), "--config", "/nonexistent", "--today", TODAY.isoformat()]
        self.assertEqual(cc.main(argv), 0)

    def test_missing_header_and_file(self):
        self.assertIn(("ERREUR", "fraicheur-absent"), self.codes(cfg(freshness_required=self.req)))
        self.w("STATE.md", "# sans en-tête\n")
        self.assertIn(("ERREUR", "fraicheur-entete"), self.codes(cfg(freshness_required=self.req)))

    def test_invalid_date_future_and_owner(self):
        self.w("docs/a.md", "---\nowner: paul\nupdated: hier\nreview_days: 5\n---\n")
        self.assertIn(("ERREUR", "fraicheur-date"), self.codes())
        self.w("docs/a.md", HDR.format(d="2027-01-01"))
        self.assertIn(("ERREUR", "fraicheur-futur"), self.codes())
        self.w("docs/a.md", "---\nupdated: 2026-11-17\nreview_days: 5\n---\n")
        self.assertIn(("ERREUR", "fraicheur-champ"), self.codes())

    def test_optional_header_not_required_elsewhere(self):
        self.w("docs/a.md", "# pas d'en-tête\n")
        self.assertEqual(self.codes(), [])


class TestSkillsAndDeny(Base):
    def test_skill_description(self):
        self.w(".agents/skills/x/SKILL.md", "---\nname: x\ndescription: " + "d" * 500 + "\n---\n")
        self.assertIn(("AVERTISSEMENT", "skill-description"), self.codes())
        self.w(".agents/skills/y/SKILL.md", "# sans en-tête\n")
        self.assertIn(("ERREUR", "skill-entete"), self.codes())

    def test_deny(self):
        self.w("STATE.md", "OIDC via ThunderID\n")
        rule = [{"pattern": "(?i)thunderid", "paths": ["STATE.md"], "reason": "ADR-0007"}]
        self.assertIn(("ERREUR", "interdit"), self.codes(cfg(deny=rule)))

    def test_main_exit_codes(self):
        self.w("AGENTS.md", "ok\n")
        self.assertEqual(cc.main(["--root", str(self.root), "--config", "/nonexistent", "--today", "2026-11-18"]), 1)
        self.w("STATE.md", HDR.format(d="2026-11-17") + "ok\n")
        self.w("missions/MISSION.md", HDR.format(d="2026-11-10").replace("7", "30") + "ok\n")
        self.assertEqual(cc.main(["--root", str(self.root), "--config", "/nonexistent", "--today", "2026-11-18"]), 0)


class TestPending(Base):
    def test_pending_downgrades_file_and_total(self):
        self.w("STATE.md", "x\n" * 140)
        c = cfg(freshness_required={"STATE.md": 7}, pending={"STATE.md": "coordinateur"})
        found = cc.run(self.root, c, TODAY)
        self.assertTrue(found)
        self.assertEqual({i[0] for i in found}, {"AVERTISSEMENT"})
        self.assertIn(("AVERTISSEMENT", "total-lignes"), [(i[0], i[1]) for i in found])
        self.assertTrue(all("en attente : coordinateur" in i[4] for i in found))

    def test_pending_does_not_hide_other_files(self):
        self.w("AGENTS.md", "x\n" * 61)
        c = cfg(pending={"STATE.md": "coordinateur"})
        self.assertIn(("ERREUR", "taille-lignes"), self.codes(c))


class TestRepository(unittest.TestCase):
    def test_repo_passes_with_its_config(self):
        cfg_path = REPO / "tools" / "context-check" / "context-check.json"
        issues = cc.run(REPO, cc.load_config(cfg_path), TODAY)
        self.assertEqual([i for i in issues if i[0] == "ERREUR"], [])


if __name__ == "__main__":
    unittest.main()
