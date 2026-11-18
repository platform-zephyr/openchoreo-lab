"""Tests de patch_env.py (T-458). Lancer : python3 -m unittest discover -s tests/gitops-k3d -v  (racine du dépôt).
Aucun cluster. Cas positifs sur le vrai manifeste de `main` + cas négatifs (ancre absente, YAML invalide)."""
from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

import patch_env  # noqa: E402

MANIFEST = ROOT / "platform" / "install" / "manifests" / "40-openchoreo-env.yaml"

# Environment tel qu'avant G1 : l'ancienne ancre `  isProduction: true\n---` existe.
PRE_G1 = """apiVersion: openchoreo.dev/v1alpha1
kind: Environment
metadata:
  name: production
  namespace: default
spec:
  dataPlaneRef:
    kind: ClusterDataPlane
    name: default
  isProduction: true
---
apiVersion: openchoreo.dev/v1alpha1
kind: DeploymentPipeline
metadata:
  name: standard
spec:
  promotionPaths: []
"""


def env_spec(text: str) -> dict:
    return next(d for d in yaml.safe_load_all(text) if d and d["kind"] == "Environment")["spec"]


def internal(text: str) -> dict:
    return env_spec(text)["gateway"]["ingress"]["internal"]


class PatchEnv(unittest.TestCase):
    def test_main_manifest_is_patched_without_anchor(self):
        # Régression T-458 : G1 présent dans main, l'ancienne ancre n'existe plus.
        text = MANIFEST.read_text(encoding="utf-8")
        self.assertNotIn("  isProduction: true\n---", text)
        out, verdict = patch_env.patch(text)
        self.assertEqual(verdict, "updated")
        self.assertEqual(internal(out)["http"]["host"], patch_env.K3D_HOST)
        self.assertEqual(internal(out)["http"]["port"], patch_env.K3D_PORT)

    def test_external_and_other_documents_untouched(self):
        text = MANIFEST.read_text(encoding="utf-8")
        out, _ = patch_env.patch(text)
        self.assertEqual(env_spec(out)["gateway"]["ingress"]["external"], env_spec(text)["gateway"]["ingress"]["external"])
        a = [d for d in yaml.safe_load_all(text) if d and d["kind"] != "Environment"]
        b = [d for d in yaml.safe_load_all(out) if d and d["kind"] != "Environment"]
        self.assertEqual(a, b)
        self.assertEqual(len(a), len(b))

    def test_comments_preserved(self):
        text = MANIFEST.read_text(encoding="utf-8")
        out, _ = patch_env.patch(text)
        self.assertIn("Correction G1", out)

    def test_idempotent(self):
        once, v1 = patch_env.patch(MANIFEST.read_text(encoding="utf-8"))
        twice, v2 = patch_env.patch(once)
        self.assertEqual((v1, v2), ("updated", "noop"))
        self.assertEqual(once, twice)

    def test_pre_g1_manifest_gets_internal_block(self):
        out, verdict = patch_env.patch(PRE_G1)
        self.assertEqual(verdict, "added")
        self.assertEqual(internal(out)["name"], "gateway-default")
        self.assertEqual(internal(out)["http"]["listenerName"], "http")
        self.assertEqual(patch_env.patch(out)[1], "noop")
        kinds = [d["kind"] for d in yaml.safe_load_all(out) if d]
        self.assertEqual(kinds, ["Environment", "DeploymentPipeline"])

    def test_ingress_with_external_only_keeps_external(self):
        text = PRE_G1.replace(
            "  isProduction: true\n",
            "  isProduction: true\n  gateway:\n    ingress:\n      external:\n        name: gateway-default\n"
            "        namespace: openchoreo-data-plane\n        http: {host: ext.example, listenerName: http, port: 19080}\n",
        )
        out, verdict = patch_env.patch(text)
        self.assertEqual(verdict, "added")
        ing = env_spec(out)["gateway"]["ingress"]
        self.assertEqual(ing["external"]["http"]["host"], "ext.example")
        self.assertEqual(ing["internal"]["http"]["host"], patch_env.K3D_HOST)

    # --- cas négatifs ---
    def test_negative_no_environment_document(self):
        with self.assertRaises(ValueError):
            patch_env.patch("apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: x\n")

    def test_negative_environment_not_production(self):
        with self.assertRaises(ValueError):
            patch_env.patch(PRE_G1.replace("name: production", "name: development"))

    def test_negative_invalid_yaml(self):
        with self.assertRaises(yaml.YAMLError):
            patch_env.patch("kind: Environment\nmetadata:\n  name: production\nspec: [unclosed\n")


class RunShWiring(unittest.TestCase):
    def test_run_sh_uses_patch_env_not_text_anchor(self):
        run = (HERE / "run.sh").read_text(encoding="utf-8")
        self.assertIn("patch_env.py", run)
        self.assertNotIn('old = "  isProduction: true', run)
        self.assertNotIn("assert old in s", run)


class Cli(unittest.TestCase):
    def run_cli(self, text: str):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "env.yaml"
            p.write_text(text, encoding="utf-8")
            r = subprocess.run([sys.executable, "-I", str(HERE / "patch_env.py"), str(p)], capture_output=True, text=True)
            return r, p.read_text(encoding="utf-8")

    def test_cli_updates_then_noop(self):
        r, out = self.run_cli(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual((r.returncode, r.stdout.strip()), (0, "updated"))
        r2, _ = self.run_cli(out)
        self.assertEqual((r2.returncode, r2.stdout.strip()), (0, "noop"))

    def test_cli_fails_loudly_without_environment(self):
        r, out = self.run_cli("kind: ConfigMap\nmetadata:\n  name: x\n")
        self.assertEqual(r.returncode, 1)
        self.assertIn("ECHEC", r.stderr)
        self.assertEqual(out, "kind: ConfigMap\nmetadata:\n  name: x\n")

    def test_cli_usage(self):
        r = subprocess.run([sys.executable, "-I", str(HERE / "patch_env.py")], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
