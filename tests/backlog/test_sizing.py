"""Tests de tools/backlog/sizing.py et de l'avertissement TAILLE de check.py (T-480) : dépôt factice, aucun réseau."""
import contextlib
import importlib.util
import io
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_check

TOOLS = Path(__file__).resolve().parents[2] / "tools" / "backlog"
SPEC = importlib.util.spec_from_file_location("backlog_sizing", TOOLS / "sizing.py")
sizing = importlib.util.module_from_spec(SPEC)
sys.modules["backlog_sizing"] = sizing
SPEC.loader.exec_module(sizing)

CRIT = "\n".join(f"- [ ] critère {n}" for n in range(1, 8))


class SizeOfTest(unittest.TestCase):
    def test_dans_les_seuils(self):
        s = sizing.size_of(["a/b.py", "c/d.py"], "- [ ] un\n- [x] deux")
        self.assertEqual((s["scope"], s["criteria"], s["reasons"]), (2, 2, []))

    def test_trop_d_elements(self):
        items = [f"docs/f{n}.md" for n in range(sizing.MAX_SCOPE_ITEMS + 1)]
        self.assertEqual(len(sizing.size_of(items, "")["reasons"]), 1)
        self.assertEqual(sizing.size_of(items[:-1], "")["reasons"], [])

    def test_trop_de_criteres(self):
        self.assertEqual(sizing.size_of(["a/b.py"], CRIT)["criteria"], 7)
        self.assertEqual(len(sizing.size_of(["a/b.py"], CRIT)["reasons"]), 1)

    def test_glob_code(self):
        s = sizing.size_of(["tools/**", "`platform/x/**/*.yaml` (commentaire)", ".github/**"], "")
        self.assertEqual(len(s["code_globs"]), 3)
        self.assertEqual(len(s["reasons"]), 1)

    def test_negatifs(self):
        self.assertEqual(sizing.size_of(["docs/**", "backlog/T-*.md"], "")["reasons"], [])  # ** hors code
        self.assertEqual(sizing.size_of(["tools/appgen/*.py"], "")["reasons"], [])  # pas de **
        self.assertEqual(sizing.size_of(["tools/x.py (voir tools/** ailleurs)"], "")["reasons"], [])  # commentaire
        self.assertEqual(sizing.size_of([], "")["reasons"], [])  # aucun critère ni périmètre
        off = sizing.size_of(["tools/**"] * 12, CRIT, off_repo=True)
        self.assertEqual((off["scope"], off["reasons"]), (0, []))  # hors de ce dépôt : rien à compter


class CheckWarningTest(unittest.TestCase):
    """Dépôt factice de test_check (gabarits repris, sans rejouer ses cas)."""

    setUp = test_check.CheckTest.setUp
    add = test_check.CheckTest.add
    run_check = test_check.CheckTest.run_check

    def taille(self, r):
        return [w for w in r.warnings if w.startswith("TAILLE")]

    def test_avertissement_sans_erreur(self):
        self.add(test_check.ticket(criteria=CRIT))
        r = self.run_check()
        self.assertEqual(r.errors, [])
        self.assertEqual(len(self.taille(r)), 1)
        self.assertIn("scinder", self.taille(r)[0])

    def test_hors_depot_commentaire_et_docs(self):
        self.add(test_check.ticket(scope="hors de ce dépôt (réglages GitHub)"))
        self.assertEqual(self.taille(self.run_check()), [])
        self.add(test_check.ticket(scope="docs/**, tools/backlog/check.py (voir tools/** ailleurs)"))
        self.assertEqual(self.taille(self.run_check()), [])

    def test_sans_critere(self):
        self.add(test_check.ticket(criteria=""))
        self.assertEqual(self.taille(self.run_check()), [])

    def test_glob_code_et_statuts_ignores(self):
        self.add(test_check.ticket(scope="tools/**"))
        self.assertEqual(len(self.taille(self.run_check())), 1)
        for status in ("done", "dropped", "deferred"):
            crit = CRIT.replace("[ ]", "[x]") if status == "done" else CRIT
            self.add(test_check.ticket(scope="tools/**", criteria=crit, status=status, stage="S0"))
            self.assertEqual(self.taille(self.run_check()), [], status)
        self.add(test_check.ticket(scope="tools/**", status="in-progress"))
        self.assertEqual(len(self.taille(self.run_check())), 1)


class CliTest(unittest.TestCase):
    def test_json_backlog_reel(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.assertEqual(sizing.main(["--json"]), 0)
        data = json.loads(buf.getvalue())
        self.assertTrue(data)
        self.assertEqual(set(next(iter(data.values()))), {"scope", "criteria", "code_globs", "reasons"})


if __name__ == "__main__":
    unittest.main()
