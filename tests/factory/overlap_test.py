"""Tests hors ligne de tools/factory/overlap.py (T-467). Lancer : python3 -I tests/factory/overlap_test.py"""
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "factory"))
import overlap  # noqa: E402


def ticket(tid, perimeter, issue="null"):
    return f"""---
id: {tid}
title: "t {tid}"
status: todo
github_issue: {issue}
---
# {tid}

## Intention
x

## Périmètre de fichiers
{perimeter}

## Critères de fin
- [ ] x
"""


TICKETS = {
    # (périmètre, issue)
    "T-901": ("apps/echo-demo/", "101"),
    "T-902": ("apps/other-demo/app.yaml, docs/apps/other.md", "102"),
    "T-903": ("apps/echo-demo/values.yaml (valeurs Helm)", "103"),
    "T-904": ("tools/dev/ci-map.tsv, tests/dev-factory/ci-parity.sh", "104"),
    "T-905": (".github/workflows/ci.yaml (job lint)", "105"),
    "T-906": ("tools/dev/check", "106"),
    "T-907": ("AGENTS.md, docs/AGENT-RUNNERS.md", "107"),
    "T-908": ("docs/**/*.md", "108"),
    "T-909": ("paramètres du dépôt, kube-ops", "109"),
    "T-910": (".github/CODEOWNERS", "110"),
    "T-911": (".github/", "111"),
    "T-912": (".github/workflows/claude-agent.yml", "112"),
    "T-913": ("tools/factory/*.py, tests/factory/", "null"),
    # Règle de finesse : dossier racine + chemins précis dessous = ombrelle ignorée.
    "T-914": ("tools/, tools/observe/lint.py, tests/, tests/observe/, docs/runbooks/", "114"),
    "T-915": ("tools/, tools/metrics/ingest/, tests/metrics/, docs/METRICS.md", "115"),
    "T-916": ("tools/, docs/", "116"),  # dossiers racines sans chemin précis : tout le sous-arbre
    "T-917": ("tests/, tests/observe/test_lint.py", "117"),
    "T-918": ("tools/, tools/dev/check", "118"),
    "T-919": ("tools/**, tools/appgen/", "119"),
    "T-920": (".github/, .github/workflows/metrics.yml", "120"),
}


class OverlapTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.backlog = Path(self.tmp.name)
        for tid, (per, issue) in TICKETS.items():
            (self.backlog / f"{tid}-x.md").write_text(ticket(tid, per, issue), encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def run_guard(self, tickets):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            rc = overlap.main(["--backlog", str(self.backlog), "--tickets", tickets])
        return rc, (json.loads(out.getvalue()) if out.getvalue() else None), err.getvalue()

    # --- admis

    def test_lot_disjoint_admis(self):
        rc, out, err = self.run_guard("101, 102 T-913")
        self.assertEqual(rc, overlap.EXIT_OK, err)
        self.assertTrue(out["admitted"])
        self.assertEqual([t["ticket"] for t in out["tickets"]], ["T-901", "T-902", "T-913"])
        self.assertEqual(out["conflicts"], [])

    def test_fichiers_voisins_sans_recouvrement(self):
        # claude-agent.yml n'est pas ci.yaml ; CODEOWNERS n'est pas couplé aux fichiers CI.
        rc, _, err = self.run_guard("112,105")
        self.assertEqual(rc, overlap.EXIT_OK, err)
        rc, _, err = self.run_guard("110,104")
        self.assertEqual(rc, overlap.EXIT_OK, err)

    def test_ticket_seul_sans_perimetre_admis(self):
        rc, out, _ = self.run_guard("109")
        self.assertEqual(rc, overlap.EXIT_OK)
        self.assertEqual(len(out["unresolved"]), 1)

    # --- refusés (cas négatifs)

    def test_repertoire_et_fichier_du_meme_arbre(self):
        rc, out, err = self.run_guard("101,103")
        self.assertEqual(rc, overlap.EXIT_OVERLAP)
        self.assertFalse(out["admitted"])
        self.assertEqual(out["conflicts"][0]["globs"], ["apps/echo-demo/", "apps/echo-demo/values.yaml"])
        self.assertIn("REFUS recouvrement : #101 (T-901) et #103 (T-903)", err)

    def test_glob_double_etoile(self):
        rc, _, _ = self.run_guard("107,108")
        self.assertEqual(rc, overlap.EXIT_OVERLAP)

    def test_fichiers_chauds_couples_par_la_parite(self):
        # ci-map.tsv, ci.yaml et tools/dev/check sont couplés : deux tickets qui en touchent chacun un se recoupent.
        for pair in ("104,105", "105,106", "104,106"):
            with self.subTest(pair=pair):
                rc, out, err = self.run_guard(pair)
                self.assertEqual(rc, overlap.EXIT_OVERLAP)
                self.assertTrue(out["conflicts"][0]["hot_files"])
                self.assertIn("fichier chaud", err)

    def test_fichier_chaud_seul(self):
        rc, out, _ = self.run_guard("110,111")  # CODEOWNERS et tout .github/
        self.assertEqual(rc, overlap.EXIT_OVERLAP)
        self.assertIn(".github/CODEOWNERS", out["conflicts"][0]["hot_files"])
        rc, out, _ = self.run_guard("107,T-907")  # même ticket par deux références : dédoublonné
        self.assertEqual(rc, overlap.EXIT_OVERLAP)

    def test_repertoire_large_entraine_le_groupe_couple(self):
        rc, out, _ = self.run_guard("111,106")  # .github/ couvre ci.yaml, donc tools/dev/check
        self.assertEqual(rc, overlap.EXIT_OVERLAP)
        self.assertIn("tools/dev/check", out["conflicts"][0]["hot_files"])

    def test_tous_les_couples_sont_rapportes(self):
        rc, out, _ = self.run_guard("104,105,106,101")
        self.assertEqual(rc, overlap.EXIT_OVERLAP)
        self.assertEqual(len(out["conflicts"]), 3)

    def test_issue_sans_ticket_dans_un_lot(self):
        rc, out, err = self.run_guard("101,999")
        self.assertEqual(rc, overlap.EXIT_UNRESOLVED)
        self.assertEqual(out["unresolved"][0]["ref"], "999")
        self.assertIn("REFUS périmètre inconnu : #999", err)

    def test_perimetre_non_exploitable_dans_un_lot(self):
        rc, _, err = self.run_guard("101,109")
        self.assertEqual(rc, overlap.EXIT_UNRESOLVED)
        self.assertIn("T-909", err)

    def test_recouvrement_prime_sur_inconnu(self):
        rc, _, _ = self.run_guard("101,103,999")
        self.assertEqual(rc, overlap.EXIT_OVERLAP)

    def test_usage(self):
        for bad in ("", "abc", "101;102", "T-x"):
            with self.subTest(bad=bad):
                rc, out, _ = self.run_guard(bad)
                self.assertEqual(rc, overlap.EXIT_USAGE)
                self.assertIsNone(out)

    # --- règle de finesse (ombrelles)

    def test_refine_unitaire(self):
        self.assertEqual(overlap.refine(["tools/", "tools/x.py", "docs/"]), (["tools/x.py", "docs/"], ["tools/"]))
        self.assertEqual(overlap.refine(["tools/**", "tools/a/"]), (["tools/a/"], ["tools/**"]))
        # Profondeur 2 : jamais une ombrelle ; dossier racine seul : conservé.
        self.assertEqual(overlap.refine(["apps/echo/", "apps/echo/values.yaml"]),
                         (["apps/echo/", "apps/echo/values.yaml"], []))
        self.assertEqual(overlap.refine(["tools/", "toolsx/a.py"]), (["tools/", "toolsx/a.py"], []))

    def test_ombrelles_disjointes_admises(self):
        for pair in ("114,115", "114,119", "115,119", "119,106", "120,110", "120,112"):
            with self.subTest(pair=pair):
                rc, out, err = self.run_guard(pair)
                self.assertEqual(rc, overlap.EXIT_OK, err)
                self.assertEqual(out["conflicts"], [])
        _, out, _ = self.run_guard("114")
        self.assertEqual(out["tickets"][0]["umbrellas"], ["tools/", "tests/"])

    def test_meme_sous_chemin_refuse(self):
        rc, out, err = self.run_guard("114,117")  # tests/observe/ ~ tests/observe/test_lint.py
        self.assertEqual(rc, overlap.EXIT_OVERLAP)
        self.assertEqual(out["conflicts"][0]["globs"], ["tests/observe/", "tests/observe/test_lint.py"])
        self.assertIn("REFUS recouvrement : #114 (T-914) et #117 (T-917)", err)

    def test_dossier_racine_non_raffine_reste_large(self):
        for pair in ("116,114", "116,115", "116,106", "116,T-913"):
            with self.subTest(pair=pair):
                rc, _, _ = self.run_guard(pair)
                self.assertEqual(rc, overlap.EXIT_OVERLAP)

    def test_fichier_chaud_sous_ombrelle_refuse(self):
        rc, out, _ = self.run_guard("118,105")  # tools/dev/check déclaré : groupe couplé avec ci.yaml
        self.assertEqual(rc, overlap.EXIT_OVERLAP)
        self.assertIn(".github/workflows/ci.yaml", out["conflicts"][0]["hot_files"])
        rc, out, _ = self.run_guard("118,104")
        self.assertEqual(rc, overlap.EXIT_OVERLAP)
        self.assertTrue(out["conflicts"][0]["hot_files"])

    def test_normalisation_des_numeros(self):
        self.assertEqual(overlap.parse_refs("007, 7 T-5,T-5"), ["7", "T-5"])

    def test_backlog_reel_lisible(self):
        bl = overlap.load_backlog(ROOT / "backlog")
        self.assertIn("T-311", bl)
        self.assertIn("factory/config.yaml", bl["T-311"]["perimeter"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
