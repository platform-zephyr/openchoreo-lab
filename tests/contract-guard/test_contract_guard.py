"""Tests de la garde du contrat (T-070) : cas positifs et négatifs, sans git ni réseau."""
import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("contract_guard", ROOT / "tools/contract-guard/contract_guard.py")
cg = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cg)

BASE = {
    "type": "object",
    "additionalProperties": False,
    "required": ["apiVersion", "spec"],
    "properties": {
        "apiVersion": {"const": "platform.example/v2alpha1"},
        "spec": {"type": "object", "properties": {"mode": {"enum": ["a", "b"]}, "size": {"type": "integer", "maximum": 10}}},
    },
}


def variant(edit):
    new = copy.deepcopy(BASE)
    edit(new)
    return new


class SchemaCompat(unittest.TestCase):
    def test_identical_passes(self):
        self.assertEqual(cg.check_schema(BASE, copy.deepcopy(BASE))[0], "PASS")

    def test_additive_change_passes(self):
        new = variant(lambda s: s["properties"]["spec"]["properties"].update(extra={"type": "string"}))
        self.assertEqual(cg.check_schema(BASE, new)[0], "PASS")

    def test_breaks_without_version_fail(self):
        edits = {
            "propriété retirée": lambda s: s["properties"]["spec"]["properties"].pop("size"),
            "required ajouté": lambda s: s["properties"]["spec"].update(required=["mode"]),
            "enum retiré": lambda s: s["properties"]["spec"]["properties"]["mode"].update(enum=["a"]),
            "type": lambda s: s["properties"]["spec"]["properties"]["size"].update(type="string"),
            "borne": lambda s: s["properties"]["spec"]["properties"]["size"].update(maximum=5),
            "additionalProperties": lambda s: s["properties"]["spec"].update(additionalProperties=False),
        }
        for name, edit in edits.items():
            with self.subTest(name):
                status, details = cg.check_schema(BASE, variant(edit))
                self.assertEqual(status, "FAIL")
                self.assertIn("sans changement de apiVersion", details[0])

    def test_break_with_new_version_passes(self):
        def edit(s):
            s["properties"]["spec"]["properties"].pop("size")
            s["properties"]["apiVersion"]["const"] = "platform.example/v2beta1"

        status, details = cg.check_schema(BASE, variant(edit))
        self.assertEqual(status, "PASS")
        self.assertIn("nouvelle version", details[0])

    def test_real_schema_is_compatible_with_itself(self):
        real = json.loads((ROOT / cg.SCHEMA_REL).read_text(encoding="utf-8"))
        self.assertEqual(cg.schema_breaks(real, real), [])


class Manifests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

    def put(self, rel, text):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
        return rel

    def test_stray_manifest_refused_and_allowed_dirs_accepted(self):
        obj = "apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: x\n"
        files = [self.put("tools/x/cm.yaml", obj), self.put("apps/a/app.yaml", obj), self.put("platform/p.yaml", obj),
                 self.put("generated/g.yaml", obj), self.put(".github/w.yaml", "name: ci\non: push\n"),
                 self.put("factory/z.yml", obj)]
        self.assertEqual(sorted(cg.stray_manifests(self.root, files)), ["factory/z.yml", "tools/x/cm.yaml"])

    def test_indicator_counts_apps_with_extra_manifest(self):
        obj = "apiVersion: v1\nkind: ConfigMap\n"
        files = [self.put("apps/a/app.yaml", "kind: App\n"), self.put("apps/a/values.yaml", "x: 1\n"),
                 self.put("apps/b/app.yaml", "kind: App\n"), self.put("apps/b/extra.yaml", obj),
                 self.put("apps/_examples/p/app.yaml", "kind: App\n")]
        self.assertEqual(cg.declared_alone(self.root, files), (1, 2))

    def test_main_fails_on_stray_manifest(self):
        self.put("tools/x/cm.yaml", "apiVersion: v1\nkind: ConfigMap\n")
        self.assertEqual(cg.main(["--root", str(self.root), "--only", "manifests"]), 1)

    def test_main_schema_break_fails_and_missing_base_is_not_tested(self):
        self.put(cg.SCHEMA_REL, json.dumps(variant(lambda s: s["properties"]["spec"]["properties"].pop("size"))))
        base = self.put("base.json", json.dumps(BASE))
        self.assertEqual(cg.main(["--root", str(self.root), "--only", "schema", "--base-schema", str(self.root / base)]), 1)
        self.assertEqual(cg.main(["--root", str(self.root), "--only", "schema", "--base", "refs/absent"]), 125)


if __name__ == "__main__":
    unittest.main()
