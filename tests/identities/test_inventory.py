"""Tests de l'inventaire des identités et de la matrice identité x secrets (T-183).

Chaque refus est prouvé sur une copie mutée de l'inventaire ou du registre réels. Aucun secret réel : le jeton du test
de valeur est factice et assemblé à l'exécution.
"""

import copy
import datetime
import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "identity-inventory"))
import inventory as INV  # noqa: E402


def _strings(node):
    """Dates YAML en chaînes, pour réécrire les fichiers tels quels."""
    if isinstance(node, dict):
        return {k: _strings(v) for k, v in node.items()}
    if isinstance(node, list):
        return [_strings(v) for v in node]
    if isinstance(node, datetime.date):
        return node.isoformat()
    return node


BASE_INV = _strings(yaml.safe_load(INV.INVENTORY.read_text(encoding="utf-8")))
BASE_REG = _strings(yaml.safe_load(INV.REGISTRY.read_text(encoding="utf-8")))


def ident(data, iid):
    return next(i for i in data["identities"] if i["id"] == iid)


def run_lint(inv_fn=None, reg_fn=None):
    inv, reg = copy.deepcopy(BASE_INV), copy.deepcopy(BASE_REG)
    if inv_fn:
        inv_fn(inv)
    if reg_fn:
        reg_fn(reg)
    with tempfile.TemporaryDirectory() as d:
        pi, pr = Path(d) / "inventory.yaml", Path(d) / "identities.yaml"
        pi.write_text(yaml.safe_dump(inv, allow_unicode=True), encoding="utf-8")
        pr.write_text(yaml.safe_dump(reg, allow_unicode=True), encoding="utf-8")
        return INV.lint(pi, pr)


class InventaireReel(unittest.TestCase):
    def test_inventaire_valide(self):
        self.assertEqual(INV.lint(), [])

    def test_types_attendus(self):
        types = {i["type"] for i in BASE_INV["identities"]}
        for t in ("humain", "agent", "ci", "eso", "crossplane"):
            self.assertIn(t, types)

    def test_matrice_du_document_derivee(self):
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(INV.main([]), 0, out.getvalue())

    def test_aucun_agent_ne_lit_une_valeur(self):
        agents = [i for i in BASE_INV["identities"] if i["type"] == "agent"]
        self.assertGreaterEqual(len(agents), 3)
        for a in agents:
            self.assertFalse(set(a["secrets"].values()) & INV.VALUE_READ, a["id"])
            self.assertNotIn("V", INV.render(BASE_INV).split(f"| `{a['id']}` |")[-1].split("\n")[0])

    def test_ecarts_dev_tous_dev_true(self):
        reg = {e["name"]: e for e in BASE_REG["identities"]}
        for i in BASE_INV["identities"]:
            for name in i.get("dev_deviations", []):
                self.assertIs(reg[name]["dev"], True, name)

    def test_un_seul_chemin_d_elevation(self):
        for i in BASE_INV["identities"]:
            self.assertLessEqual(len(i["elevation"]), 1, i["id"])


class Refus(unittest.TestCase):
    def assertRefused(self, errs, needle):
        self.assertTrue(errs, "l'inventaire devait être refusé")
        self.assertTrue(any(needle in e for e in errs), errs)

    def test_credential_sans_proprietaire(self):
        errs = run_lint(reg_fn=lambda r: next(e for e in r["identities"] if e["name"] == "eso-lab-jeton").pop("owner"))
        self.assertRefused(errs, "sans propriétaire ou sans échéance")

    def test_credential_sans_echeance(self):
        errs = run_lint(reg_fn=lambda r: next(e for e in r["identities"] if e["name"] == "eso-lab-jeton").pop("rotate_by"))
        self.assertRefused(errs, "sans propriétaire ou sans échéance")

    def test_credential_absent_du_registre(self):
        errs = run_lint(lambda d: ident(d, "eso-plateforme")["credentials"].append("jeton-fantome"))
        self.assertRefused(errs, "absent du registre")

    def test_identite_sans_proprietaire_ni_echeance(self):
        for champ in ("owner", "expires"):
            errs = run_lint(lambda d, c=champ: ident(d, "agent-dev").pop(c))
            self.assertRefused(errs, "required")

    def test_deux_chemins_d_elevation(self):
        def two(d):
            ident(d, "agent-dev")["elevation"] = [
                {"to": "agent-ops-lecteur", "via": "mandat de Paul", "class": "MANDAT"},
                {"to": "agent-remediation", "via": "revue de PR", "class": "REVUE"},
            ]
        self.assertRefused(run_lint(two), "2 chemins d'élévation")

    def test_elevation_en_cycle(self):
        back = {"to": "agent-ops-lecteur", "via": "retour", "class": "MANDAT"}
        self.assertRefused(run_lint(lambda d: ident(d, "agent-remediation")["elevation"].append(back)), "cycle d'élévation")

    def test_elevation_vers_inconnue(self):
        bad = {"to": "inconnue", "via": "x y", "class": "MANDAT"}
        self.assertRefused(run_lint(lambda d: ident(d, "ci-github")["elevation"].append(bad)), "identité inconnue")

    def test_agent_lecteur_de_valeur(self):
        for acces in ("valeur", "valeur-break-glass"):
            errs = run_lint(lambda d, a=acces: ident(d, "agent-dev")["secrets"].__setitem__("apps", a))
            self.assertRefused(errs, "identité d'agent avec lecture de valeur")

    def test_ecart_dev_non_dev(self):
        errs = run_lint(reg_fn=lambda r: next(e for e in r["identities"] if e["name"] == "lab-kubeconfig").__setitem__("dev", False))
        self.assertRefused(errs, "non marqué dev: true")

    def test_credential_du_registre_non_couvert(self):
        self.assertRefused(run_lint(lambda d: ident(d, "portail-backstage").__setitem__("credentials", [])), "non couvert")

    def test_consommateur_incoherent(self):
        self.assertRefused(run_lint(lambda d: ident(d, "ci-github")["credentials"].append("eso-lab-jeton")),
                           "sans consommateur commun")

    def test_categorie_inconnue(self):
        self.assertRefused(run_lint(lambda d: ident(d, "ci-github")["secrets"].__setitem__("inconnue", "presence")),
                           "catégorie inconnue")

    def test_champ_de_valeur(self):
        for champ in ("value", "token", "secret"):
            errs = run_lint(lambda d, c=champ: ident(d, "ci-github").__setitem__(c, "x"))
            self.assertRefused(errs, "additionalProperties")

    def test_jeton_dans_une_note(self):
        fake = "gh" + "p_" + "A1b2C3d4E5f6G7h8I9j0K1l2"
        self.assertRefused(run_lint(lambda d: ident(d, "ci-github").__setitem__("note", fake)), "jeton GitHub")

    def test_doublon(self):
        self.assertRefused(run_lint(lambda d: d["identities"].append(copy.deepcopy(ident(d, "ci-github")))), "en double")


class Document(unittest.TestCase):
    def _main(self, doc_text, *extra):
        with tempfile.TemporaryDirectory() as d:
            doc = Path(d) / "IDENTITY.md"
            doc.write_text(doc_text, encoding="utf-8")
            out = io.StringIO()
            with redirect_stdout(out):
                rc = INV.main(["--doc", str(doc), *extra])
            return rc, out.getvalue(), doc.read_text(encoding="utf-8")

    def test_matrice_divergente_refusee_puis_regeneree(self):
        stale = f"# x\n\n{INV.BEGIN}\n| ancienne |\n{INV.END}\n"
        rc, out, _ = self._main(stale)
        self.assertEqual(rc, 1)
        self.assertIn("matrice différente", out)
        rc, _, text = self._main(stale, "--write")
        self.assertEqual(rc, 0)
        self.assertIn(INV.render(BASE_INV), text)

    def test_marqueurs_absents(self):
        rc, out, _ = self._main("# rien\n")
        self.assertEqual(rc, 1)
        self.assertIn("marqueurs", out)

    def test_avertissement_echeance(self):
        self.assertTrue(INV.warnings(BASE_INV, datetime.date(2030, 1, 1)))
        self.assertEqual(INV.warnings(BASE_INV, datetime.date(2026, 11, 18)), [])


if __name__ == "__main__":
    unittest.main()
