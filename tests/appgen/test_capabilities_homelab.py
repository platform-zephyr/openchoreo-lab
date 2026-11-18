"""Tests T-365 : capacites du cluster homelab (clusters/homelab/capabilities.yaml), refus par defaut, placement.

Lancer : python3 -m unittest discover -s tests/appgen -v   (depuis la racine du depot)
Un test par refus : arch absente, stockage absent, availability scheduled ; puis placement par defaut (ADR-0003 §4).
"""
from __future__ import annotations

import copy
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "appgen"))
sys.path.insert(0, str(ROOT / "tests" / "appgen"))

import appgen  # noqa: E402
from test_extensions import TODAY, stateful, whoami  # noqa: E402

CLUSTERS = ROOT / "clusters"


def write_caps(tmp: str, cluster: str, doc: dict) -> Path:
    d = Path(tmp) / cluster
    d.mkdir(parents=True, exist_ok=True)
    (d / "capabilities.yaml").write_text(yaml.safe_dump(doc, sort_keys=False), encoding="utf-8")
    return Path(tmp)


def homelab_doc() -> dict:
    return copy.deepcopy(yaml.safe_load((CLUSTERS / "homelab" / "capabilities.yaml").read_text(encoding="utf-8")))


def on_homelab(doc: dict) -> dict:
    doc["spec"]["cluster"] = "homelab"
    return doc


def semantic(doc: dict, clusters: Path = CLUSTERS) -> list[str]:
    ctx = appgen.Context(clusters_dir=clusters, index={doc["metadata"]["name"]: doc}, today=TODAY)
    return appgen.semantic_check(doc, doc["metadata"]["name"], True, ctx)[0]


class HomelabCapabilities(unittest.TestCase):
    def test_homelab_policy_loads_and_declares_the_new_fields(self):
        spec = appgen.load_capabilities(CLUSTERS, "homelab")
        self.assertEqual(spec["arch"], ["amd64"])
        self.assertEqual(spec["availability"], "always")
        self.assertEqual(spec["gvisor"], "absent")
        self.assertIn("kyverno", spec["admission"])
        self.assertIn("block-rwo", spec["storageClasses"])
        self.assertNotIn("rwx-shared", spec["storageClasses"])

    def test_every_cluster_declares_arch_availability_gvisor_admission(self):
        for name in ("k3d", "oke", "homelab"):
            spec = appgen.load_capabilities(CLUSTERS, name)
            self.assertEqual(spec["availability"], "always", name)
            self.assertTrue(spec["arch"], name)
            self.assertIn(spec["gvisor"], ("proven", "absent"), name)
            self.assertTrue(spec["admission"], name)

    def test_oke_and_k3d_stay_arm64_without_kyverno(self):
        for name in ("k3d", "oke"):
            spec = appgen.load_capabilities(CLUSTERS, name)
            self.assertEqual(spec["arch"], ["arm64"], name)
            self.assertNotIn("kyverno", spec["admission"], name)


class RefusalArchAbsent(unittest.TestCase):
    def test_policy_without_arch_is_refused(self):
        doc = homelab_doc()
        del doc["spec"]["arch"]
        with tempfile.TemporaryDirectory() as tmp:
            root = write_caps(tmp, "homelab", doc)
            with self.assertRaisesRegex(appgen.AppError, "'arch' is a required property"):
                appgen.load_capabilities(root, "homelab")

    def test_unknown_arch_is_refused(self):
        doc = homelab_doc()
        doc["spec"]["arch"] = ["riscv64"]
        with tempfile.TemporaryDirectory() as tmp:
            root = write_caps(tmp, "homelab", doc)
            with self.assertRaisesRegex(appgen.AppError, "arch"):
                appgen.load_capabilities(root, "homelab")

    def test_empty_arch_is_refused(self):
        doc = homelab_doc()
        doc["spec"]["arch"] = []
        with tempfile.TemporaryDirectory() as tmp:
            root = write_caps(tmp, "homelab", doc)
            with self.assertRaisesRegex(appgen.AppError, "arch"):
                appgen.load_capabilities(root, "homelab")

    def test_app_on_cluster_without_policy_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            errs = semantic(on_homelab(whoami()), clusters=Path(tmp))
        self.assertTrue(any("politique de cluster absente" in e for e in errs), errs)


class RefusalStorageAbsent(unittest.TestCase):
    def test_profile_not_declared_by_homelab_is_refused(self):
        doc = on_homelab(stateful(whoami(), [
            {"name": "media", "profile": "rwx-shared", "mountPath": "/media", "size": "1Gi"}]))
        errs = semantic(doc)
        self.assertIn("storage[media] profil 'rwx-shared' non disponible sur le cluster 'homelab'", errs)

    def test_profile_declared_by_homelab_is_admitted(self):
        doc = on_homelab(stateful(whoami(), {"profile": "block-rwo", "mountPath": "/data", "size": "1Gi"}))
        errs = semantic(doc)
        self.assertFalse([e for e in errs if "profil" in e], errs)

    def test_policy_without_any_storage_class_refuses_block_rwo(self):
        caps = homelab_doc()
        caps["spec"]["storageClasses"] = {}
        doc = on_homelab(stateful(whoami(), {"profile": "block-rwo", "mountPath": "/data", "size": "1Gi"}))
        with tempfile.TemporaryDirectory() as tmp:
            errs = semantic(doc, clusters=write_caps(tmp, "homelab", caps))
        self.assertIn("storage[data] profil 'block-rwo' non disponible sur le cluster 'homelab'", errs)


class RefusalAvailabilityScheduled(unittest.TestCase):
    def test_scheduled_is_not_in_the_contract(self):
        doc = homelab_doc()
        doc["spec"]["availability"] = "scheduled"
        with tempfile.TemporaryDirectory() as tmp:
            root = write_caps(tmp, "homelab", doc)
            with self.assertRaisesRegex(appgen.AppError, "availability"):
                appgen.load_capabilities(root, "homelab")

    def test_schema_admits_only_always(self):
        schema = appgen.load_yaml(ROOT / "docs" / "schema" / "capabilities.schema.json")
        self.assertEqual(schema["properties"]["spec"]["properties"]["availability"]["enum"], ["always"])

    def test_gvisor_value_is_controlled(self):
        doc = homelab_doc()
        doc["spec"]["gvisor"] = "maybe"
        with tempfile.TemporaryDirectory() as tmp:
            root = write_caps(tmp, "homelab", doc)
            with self.assertRaisesRegex(appgen.AppError, "gvisor"):
                appgen.load_capabilities(root, "homelab")


class DefaultPlacement(unittest.TestCase):
    """ADR-0003 §4 : par defaut, une app va sur le homelab ; oke seulement sur demande explicite de Paul."""

    def test_default_cluster_is_homelab(self):
        self.assertEqual(appgen.default_cluster(CLUSTERS), "homelab")

    def test_default_cluster_is_never_oke(self):
        self.assertNotEqual(appgen.default_cluster(CLUSTERS), "oke")

    def test_default_cluster_needs_its_policy(self):
        with tempfile.TemporaryDirectory() as tmp, self.assertRaisesRegex(appgen.AppError, "politique de cluster absente"):
            appgen.default_cluster(Path(tmp))

    def test_default_cluster_policy_is_valid_and_homelab_named(self):
        path = CLUSTERS / appgen.default_cluster(CLUSTERS) / "capabilities.yaml"
        self.assertEqual(yaml.safe_load(path.read_text(encoding="utf-8"))["metadata"]["name"], "homelab")


if __name__ == "__main__":
    unittest.main()
