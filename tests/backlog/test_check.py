"""Tests de tools/backlog/check.py : un dépôt factice par cas (tmp), aucun accès réseau ni cluster."""
import contextlib
import functools
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SPEC = importlib.util.spec_from_file_location(
    "backlog_check", Path(__file__).resolve().parents[2] / "tools" / "backlog" / "check.py")
check = importlib.util.module_from_spec(SPEC)
sys.modules["backlog_check"] = check
SPEC.loader.exec_module(check)

HEAD = {
    "id": "T-900", "title": '"Essai"', "status": "todo", "phase": "P0", "adr": "[0001]", "depends_on": "[]",
    "class": "AUTONOME", "velocity": "false", "lane": "ci", "stage": "S0",
    "model": "claude-sonnet-5-5", "effort": "high", "routing": "R3-defaut", "github_issue": "null",
}
SCOPE = "tools/backlog/check.py, tests/backlog/"


def ticket(scope: str = SCOPE, criteria: str = "- [ ] ok", **over: str) -> str:
    head = {**HEAD, **over}
    lines = [f"{k}: {v}" for k, v in head.items() if v is not None]
    return ("---\n" + "\n".join(lines) + "\n---\n# T\n\n## Intention\nx\n\n"
            f"## Périmètre de fichiers\n{scope}\n\n## Critères de fin\n{criteria}\n")


class CheckTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "backlog").mkdir()
        (self.root / "docs" / "adr").mkdir(parents=True)
        (self.root / "docs" / "adr" / "0001-x.md").write_text("# ADR\n")
        (self.root / ".github").mkdir()
        (self.root / ".github" / "CODEOWNERS").write_text("/platform/authz/ @owner\n/tools/backlog/ @owner\n")
        self.addCleanup(self._tmp.cleanup)

    def add(self, text: str, name: str = "T-900-essai.md") -> None:
        (self.root / "backlog" / name).write_text(text, encoding="utf-8")

    def run_check(self):
        return check.check(self.root)

    def assertError(self, prefix: str, r) -> None:
        self.assertTrue(any(e.startswith(prefix) for e in r.errors), (prefix, r.errors))

    def test_ticket_valide(self):
        self.add(ticket())
        r = self.run_check()
        self.assertEqual(r.errors, [])
        self.assertEqual(r.todo, 1)

    def test_aucun_ticket(self):
        self.assertTrue(self.run_check().errors[0].startswith("ERREUR"))

    def test_modele_inconnu_rouge(self):
        self.add(ticket(model="claude-unknown"))
        self.assertError("MODEL-INCONNU", self.run_check())

    def test_model_ou_effort_absent_sur_ticket_actif(self):
        self.add(ticket(model=None))
        self.assertError("MODEL-ABSENT", self.run_check())

    def test_effort_inconnu_et_human(self):
        self.add(ticket(effort="turbo"))
        self.assertError("EFFORT-INCONNU", self.run_check())
        self.add(ticket(model="human", effort="high"))
        self.assertError("EFFORT", self.run_check())
        self.add(ticket(model="human", effort="none"))
        self.assertEqual(self.run_check().errors, [])

    def test_effort_max_sonnet_avertit_sans_echouer(self):
        self.add(ticket(effort="max"))
        r = self.run_check()
        self.assertEqual(r.errors, [])
        self.assertTrue(any("xhigh" in w for w in r.warnings), r.warnings)

    def test_revue_sur_noyau_sans_opus_avertit(self):
        self.add(ticket(scope="platform/authz/, docs/", **{"class": "REVUE"}))
        r = self.run_check()
        self.assertEqual(r.errors, [])
        self.assertTrue(any(w.startswith("ROUTAGE") for w in r.warnings), r.warnings)

    def test_revue_sur_noyau_avec_opus_ou_hors_noyau_sans_avertissement(self):
        self.add(ticket(scope="platform/authz/", model="claude-opus-5-5", **{"class": "REVUE"}))
        self.assertEqual(self.run_check().warnings, [])
        self.add(ticket(scope="apps/demo/", **{"class": "REVUE"}))
        self.assertEqual(self.run_check().warnings, [])

    def test_adr_absent(self):
        self.add(ticket(adr="[0099]"))
        self.assertError("ADR-ABSENT", self.run_check())

    def test_statut_classe_phase_etape_inconnus(self):
        for key, val, code in [("status", "wip", "STATUT-INCONNU"), ("class", "LIBRE", "CLASSE-INCONNUE"),
                               ("phase", "P9", "PHASE-INCONNUE"), ("stage", "S9", "ÉTAPE-INCONNUE")]:
            with self.subTest(key=key):
                self.add(ticket(**{key: val}))
                self.assertError(code, self.run_check())

    def test_classe_combinee(self):
        self.add(ticket(**{"class": "AUTONOME + MANDAT"}))
        self.assertEqual(self.run_check().errors, [])

    def test_id_duplique(self):
        self.add(ticket())
        self.add(ticket(), "T-900-autre.md")
        self.assertError("ID-DUPLIQUÉ", self.run_check())

    def test_dependance_absente(self):
        self.add(ticket(depends_on="[T-777]"))
        self.assertError("MISSING", self.run_check())

    def test_dependance_gelee_ou_abandonnee(self):
        self.add(ticket(id="T-901", status="deferred"), "T-901-a.md")
        self.add(ticket(depends_on="[T-901]"))
        self.assertError("ACTIF->GELÉ", self.run_check())
        self.add(ticket(id="T-901", status="dropped"), "T-901-a.md")
        self.assertError("DEP-ON-DROPPED", self.run_check())

    def test_ordre_des_etapes(self):
        self.add(ticket(id="T-901", stage="S2"), "T-901-a.md")
        self.add(ticket(depends_on="[T-901]", stage="S1"))
        self.assertError("ÉTAPE", self.run_check())

    def test_cycle(self):
        self.add(ticket(id="T-901", depends_on="[T-900]"), "T-901-a.md")
        self.add(ticket(depends_on="[T-901]"))
        self.assertError("CYCLE", self.run_check())

    def test_profondeur(self):
        self.add(ticket(id="T-901"), "T-901-a.md")
        self.add(ticket(depends_on="[T-901]"))
        self.assertEqual(self.run_check().depth, 2)

    def test_perimetre_sans_glob_exploitable(self):
        for scope in ["", "voir plus tard", "à définir avec Paul"]:
            with self.subTest(scope=scope):
                self.add(ticket(scope=scope))
                self.assertError("PÉRIMÈTRE-INEXPLOITABLE", self.run_check())

    def test_perimetre_exploitable(self):
        self.add(ticket(scope="apps/<app>/, generated/**/*.yaml, tools/x.py (lecture), docs/"))
        r = self.run_check()
        self.assertEqual(r.errors, [])
        self.assertEqual(r.warnings, [])

    def test_perimetre_mixte_avertit(self):
        self.add(ticket(scope="tools/x.py, autre dépôt privé"))
        r = self.run_check()
        self.assertEqual(r.errors, [])
        self.assertTrue(any(w.startswith("PÉRIMÈTRE") for w in r.warnings))

    def test_perimetre_hors_depot_accepte(self):
        self.add(ticket(scope="dépôt homelab-infra terraform/unifi (hors de ce dépôt)"))
        self.assertEqual(self.run_check().errors, [])

    def test_done_avec_case_non_cochee(self):
        self.add(ticket(status="done", criteria="- [x] a\n- [ ] b"))
        self.assertError("CRITÈRES", self.run_check())
        self.add(ticket(status="done", criteria="- [x] a"))
        self.assertEqual(self.run_check().errors, [])

    def test_entete_absent(self):
        self.add("# pas d'en-tête\n")
        self.assertTrue(self.run_check().errors)

    def test_champ_de_base_absent(self):
        for key in ("title", "lane", "velocity", "depends_on"):
            with self.subTest(key=key):
                self.add(ticket(**{key: None}))
                self.assertError(f"CHAMP-ABSENT T-900 {key}", self.run_check())

    def test_nom_de_fichier_different_de_id(self):
        self.add(ticket(), "T-123-autre.md")
        self.assertError("NOM-FICHIER", self.run_check())
        (self.root / "backlog" / "T-123-autre.md").unlink()
        self.add(ticket(), "T-900.md")  # nom exact sans slug : accepté
        self.assertEqual(self.run_check().errors, [])

    def test_etape_tiret_acceptee_seulement_si_dropped(self):
        self.add(ticket(status="dropped", stage="—", model=None, effort=None))
        self.assertEqual(self.run_check().errors, [])
        self.add(ticket(status="todo", stage="—"))
        self.assertError("ÉTAPE-INCONNUE", self.run_check())

    def test_model_absent_tolere_hors_ticket_actif(self):
        self.add(ticket(status="done", criteria="- [x] a", model=None, effort=None))
        self.assertEqual(self.run_check().errors, [])

    def test_ticket_done_sans_perimetre_accepte(self):
        self.add(ticket(status="done", scope="", criteria="- [x] a"))
        self.assertEqual(self.run_check().errors, [])

    def test_adr_via_fichier_sans_slug(self):
        (self.root / "docs" / "adr" / "0002.md").write_text("# ADR\n")
        self.add(ticket(adr="[0002]"))
        self.assertEqual(self.run_check().errors, [])

    def test_noyau_et_sous_chemins(self):
        core = check.core_paths(self.root)
        self.assertIn("platform/authz", core)
        self.assertIn("docs/adr", core)
        self.assertTrue(check.touches_core(["docs/**/*.md"], core))  # préfixe `docs` contient docs/adr
        self.assertTrue(check.touches_core(["platform/authz/x.yaml"], core))
        self.assertTrue(check.touches_core(["**/*.md"], core))  # préfixe vide
        self.assertFalse(check.touches_core(["apps/demo"], core))

    def test_noyau_sans_codeowners(self):
        (self.root / ".github" / "CODEOWNERS").unlink()
        self.assertEqual(check.core_paths(self.root), check.EXTRA_CORE)

    def test_parse_list_et_split_scope(self):
        self.assertEqual(check.parse_list('["T-1", \'T-2\']'), ["T-1", "T-2"])
        self.assertEqual(check.parse_list("[]"), [])
        self.assertEqual(check.split_scope("a/b (x, y), c/d"), ["a/b (x, y)", "c/d"])

    def test_main_code_de_sortie(self):
        for text, code in [(ticket(), 0), (ticket(model="claude-unknown"), 1)]:
            with self.subTest(code=code):
                self.add(text)
                buf = io.StringIO()
                # `main()` appelle check() avec la racine du vrai dépôt : on la redirige vers la racine factice.
                fake = functools.partial(check.check, self.root)
                with mock.patch.object(check, "check", fake), contextlib.redirect_stdout(buf):
                    rc = check.main()
                self.assertEqual(rc, code)
                self.assertIn("erreurs", buf.getvalue())

    def test_depot_reel_sans_erreur(self):
        r = check.check(check.ROOT)
        self.assertEqual(r.errors, [])


if __name__ == "__main__":
    unittest.main()
