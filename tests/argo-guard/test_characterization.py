"""Tests de caractérisation (T-423) : le comportement observable d'argo_guard.py et psa_check.py est gelé.

`golden.json.gz` a été produit contre l'ancien code (avant découpage). Toute différence de message ou d'ordre est un échec.
Lancer : python3 -m unittest discover -s tests/argo-guard
"""
import gzip
import json
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import corpus

GOLDEN = json.loads(gzip.decompress(pathlib.Path(__file__).with_name("golden.json.gz").read_bytes()))
CURRENT = corpus.build()


class Characterization(unittest.TestCase):
    def test_same_sections(self):
        self.assertEqual(sorted(GOLDEN), sorted(CURRENT))

    def test_cases_all_match(self):
        for section in GOLDEN:
            self.assertEqual(sorted(GOLDEN[section]), sorted(CURRENT[section]), section)
            for cid, want in GOLDEN[section].items():
                with self.subTest(section=section, case=cid):
                    self.assertEqual(CURRENT[section][cid], want)

    def test_corpus_exercises_negative_rules(self):
        """Le corpus reste discriminant : chaque code de règle apparaît au moins une fois dans le gel."""
        blob = json.dumps(GOLDEN, ensure_ascii=False)
        for code in ("P1", "P2", "P3", "A1", "A2", "A3", "A4", "S1", "S2", "S3", "VAP:", "PSA baseline",
                     "PSA restricted"):
            self.assertIn(code, blob)


if __name__ == "__main__":
    unittest.main()
