"""Tests de tools/appgen/crd2schema.py : cas positifs et négatifs sur des CRD factices (tmp)."""
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "appgen"))

import crd2schema  # noqa: E402


def crd(kind: str = "Widget", group: str = "ex.io", versions: tuple[str, ...] = ("v1",)) -> str:
    return yaml.safe_dump({
        "kind": "CustomResourceDefinition",
        "spec": {"group": group, "names": {"kind": kind},
                 "versions": [{"name": v, "schema": {"openAPIV3Schema": {"type": "object"}}} for v in versions]},
    })


class Crd2SchemaTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.src = Path(self._tmp.name) / "crd"
        self.out = Path(self._tmp.name) / "out"
        self.src.mkdir()

    def test_nommage_en_minuscules_et_une_sortie_par_version(self):
        (self.src / "a.yaml").write_text(crd(versions=("v1", "v2beta1")))
        self.assertEqual(crd2schema.convert(self.src, self.out), 2)
        for name in ("widget_v1.json", "widget_v2beta1.json"):
            schema = json.loads((self.out / "ex.io" / name).read_text())
            self.assertEqual(schema["$schema"], "http://json-schema.org/draft-07/schema#")
            self.assertEqual(schema["type"], "object")

    def test_ignore_ce_qui_nest_pas_une_crd(self):
        (self.src / "cm.yaml").write_text("kind: ConfigMap\n")
        (self.src / "liste.yaml").write_text("- a\n- b\n")
        (self.src / "vide.yaml").write_text("")
        (self.src / "note.txt").write_text(crd())  # extension non .yaml
        self.assertEqual(crd2schema.convert(self.src, self.out), 0)
        self.assertFalse(self.out.exists())

    def test_crd_sans_schema_leve_une_erreur(self):
        doc = yaml.safe_load(crd())
        del doc["spec"]["versions"][0]["schema"]
        (self.src / "a.yaml").write_text(yaml.safe_dump(doc))
        with self.assertRaises(KeyError):
            crd2schema.convert(self.src, self.out)

    def test_main_code_de_sortie(self):
        (self.src / "a.yaml").write_text(crd())
        for argv, code in [([str(self.src), str(self.out)], 0), ([str(self.src / "x"), str(self.out / "y")], 1)]:
            with self.subTest(code=code), mock.patch.object(sys, "argv", ["crd2schema", *argv]), \
                    contextlib.redirect_stdout(io.StringIO()) as buf:
                self.assertEqual(crd2schema.main(), code)
                self.assertIn("crd2schema", buf.getvalue())


if __name__ == "__main__":
    unittest.main()
