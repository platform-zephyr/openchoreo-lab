"""Tests du lint du registre des identités (T-306). Tous les jetons ci-dessous sont factices et assemblés à l'exécution."""
import copy
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "backlog"))
import identities_lint as L  # noqa: E402

REGISTRY = ROOT / "docs" / "state" / "identities.yaml"
BASE = yaml.safe_load(REGISTRY.read_text(encoding="utf-8"))


def lint_data(data, extra_text=""):
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "identities.yaml"
        p.write_text(yaml.safe_dump(data, allow_unicode=True) + extra_text, encoding="utf-8")
        return L.lint(p)


def mutated(fn):
    d = copy.deepcopy(BASE)
    # safe_load a produit des dates : les remettre en chaînes pour le dump
    for i in d["identities"]:
        for k in ("created", "rotate_by", "last_rotated"):
            if k in i:
                i[k] = str(i[k])
    fn(d["identities"][0])
    return d


class RegistreReel(unittest.TestCase):
    def test_registre_valide(self):
        self.assertEqual(L.lint(REGISTRY), [])

    def test_entrees_attendues(self):
        names = {i["name"] for i in BASE["identities"]}
        for n in ("abonnement-claude-jeton", "executant-identite-github", "doppler-acces-elargi",
                  "eso-lab-jeton", "lab-kubeconfig", "talos-secrets-machine-lab"):
            self.assertIn(n, names)


class Refus(unittest.TestCase):
    def assertRefused(self, errs, needle=None):
        self.assertTrue(errs, "le lint devait refuser")
        if needle:
            self.assertTrue(any(needle in e for e in errs), errs)

    def test_champ_de_valeur_refuse(self):
        for champ in ("value", "secret", "token", "password", "valeur"):
            errs = lint_data(mutated(lambda i, c=champ: i.__setitem__(c, "x")))
            self.assertRefused(errs, "additionalProperties")

    def test_date_creation_absente(self):
        self.assertRefused(lint_data(mutated(lambda i: i.pop("created"))), "required")

    def test_date_rotation_absente(self):
        self.assertRefused(lint_data(mutated(lambda i: i.pop("rotate_by"))), "required")

    def test_date_invalide(self):
        self.assertRefused(lint_data(mutated(lambda i: i.__setitem__("created", "18/11/2026"))), "pattern")
        self.assertRefused(lint_data(mutated(lambda i: i.__setitem__("created", "2026-13-40"))), "pattern")

    def test_rotation_avant_creation(self):
        self.assertRefused(lint_data(mutated(lambda i: i.__setitem__("rotate_by", "2020-01-01"))), "antérieure")

    def test_dev_obligatoire_et_booleen(self):
        self.assertRefused(lint_data(mutated(lambda i: i.pop("dev"))), "required")
        self.assertRefused(lint_data(mutated(lambda i: i.__setitem__("dev", "oui"))), "type")

    def test_coffre_inconnu(self):
        self.assertRefused(lint_data(mutated(lambda i: i.__setitem__("vault", "fichier-local"))), "enum")

    def test_nom_en_double(self):
        d = mutated(lambda i: None)
        d["identities"].append(copy.deepcopy(d["identities"][0]))
        self.assertRefused(lint_data(d), "double")

    def test_jetons_connus(self):
        fakes = {
            "GitHub": "ghp_" + "A1b2C3d4" * 5,
            "GitHub fine-grained": "github_pat_" + "A1b2C3d4_" * 4,
            "Doppler": "dp.st." + "abcdEFGH1234",
            "OpenBao": "hvs." + "AbCdEf123456" * 2,
            "Slack": "xoxb-" + "1234567890-abcdef",
            "AWS": "AKIA" + "ABCDEFGHIJKLMNOP",
            "sk-": "sk-" + "ant-api03-abcdefghijklmnop",
            "JWT": "eyJhbGciOiJI" + "." + "eyJzdWIiOiIx" + ".sig",
            "PEM": "-----BEGIN " + "PRIVATE KEY-----",
            "autorisation": "Bearer " + "abcdefghijklmnop1234",
        }
        for label, v in fakes.items():
            errs = lint_data(mutated(lambda i, v=v: i.__setitem__("note", v)))
            self.assertRefused(errs)
            self.assertFalse(any(v in e for e in errs), "la valeur ne doit jamais être affichée")

    def test_entropie_et_hex(self):
        self.assertRefused(lint_data(mutated(lambda i: i.__setitem__("note", "Zx9Qw3Rt7Yu1Io5Pa8Sd2Fg6Hj4Kl0Mn"))), "entropie")
        self.assertRefused(lint_data(mutated(lambda i: i.__setitem__("note", "0123456789abcdef" * 2))), "hexad")

    def test_donnees_internes(self):
        cas = {"IPv4": "10.0." + "20.60", "e-mail": "paul@" + "example.org", "URL": "https:" + "//exemple.test",
               "hôte": "nas." + "home.lan", "chemin": "/home/" + "paul/x", "OCID": "ocid1." + "tenancy.oc1..aaaa"}
        for label, v in cas.items():
            self.assertRefused(lint_data(mutated(lambda i, v=v: i.__setitem__("note", v))), label)

    def test_commentaire_scanne(self):
        self.assertRefused(lint_data(mutated(lambda i: None), "# jeton ghp_" + "A1b2C3d4" * 5 + "\n"), "texte interdit")

    def test_pas_de_faux_positif_sur_noms(self):
        d = mutated(lambda i: i.__setitem__("note", "talos-secrets-machine-lab et doppler-acces-elargi-jeton-expirant"))
        self.assertEqual(lint_data(d), [])


if __name__ == "__main__":
    unittest.main()
