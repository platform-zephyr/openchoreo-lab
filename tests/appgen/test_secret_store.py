"""T-499 : forme de remoteRef selon le fournisseur ESO du store (capacite secretStoreProvider).

doppler (defaut, k3d) : key = cle du contrat, inchange. kubernetes (lab-store sur OKE) : key = Secret minuscule RFC 1123
du coffre lab-secrets, property = cle du contrat. Une cle dont le nom de Secret derive n'est pas RFC 1123 est refusee a
la generation, comme une property explicite sur un store kubernetes.
Lancer : python3 -m unittest discover -s tests/appgen
"""
from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "appgen"))
sys.path.insert(0, str(ROOT / "tests" / "appgen"))

import appgen  # noqa: E402
from appgenlib.model import remote_ref  # noqa: E402
from test_extensions import RICH_CAPS, TODAY, podinfo  # noqa: E402

CLUSTERS = ROOT / "clusters"
KUBE = {**copy.deepcopy(RICH_CAPS["spec"]), "secretStore": "lab-store", "secretStoreProvider": "kubernetes"}


def searxng() -> dict:
    return appgen.load_yaml(ROOT / "apps" / "searxng" / "app.yaml")


def errors(doc: dict) -> list[str]:
    name = doc["metadata"]["name"]
    ctx = appgen.Context(clusters_dir=CLUSTERS, index={name: doc}, today=TODAY)
    return appgen.semantic_check(doc, name, True, ctx)[0]


class RemoteRef(unittest.TestCase):
    def test_doppler_default_unchanged(self):
        self.assertEqual(remote_ref({"key": "APP_A", "env": "A"}, {}), {"key": "APP_A"})
        self.assertEqual(remote_ref({"key": "APP_A", "env": "A", "property": "p"}, {"secretStoreProvider": "doppler"}),
                         {"key": "APP_A", "property": "p"})

    def test_kubernetes_lowercase_secret_and_property(self):
        self.assertEqual(remote_ref({"key": "SEARXNG_SECRET", "env": "S"}, KUBE),
                         {"key": "searxng-secret", "property": "SEARXNG_SECRET"})

    def test_capabilities_per_cluster(self):
        self.assertEqual(appgen.load_capabilities(CLUSTERS, "oke").get("secretStoreProvider"), "kubernetes")
        self.assertNotIn("secretStoreProvider", appgen.load_capabilities(CLUSTERS, "k3d"))


class Generated(unittest.TestCase):
    def test_searxng_secret_reference_targets_lab_store_layout(self):
        sr = appgen.load_yaml(ROOT / "generated" / "namespaces" / "default" / "projects" / "searxng" /
                              "secret-references" / "searxng-secrets.yaml")
        self.assertEqual(sr["spec"]["data"],
                         [{"secretKey": "SEARXNG_SECRET",
                           "remoteRef": {"key": "searxng-secret", "property": "SEARXNG_SECRET"}}])

    def test_k3d_secret_reference_keeps_doppler_key(self):
        sr = appgen.load_yaml(ROOT / "generated" / "namespaces" / "default" / "projects" / "miniflux" /
                              "secret-references" / "miniflux-secrets.yaml")
        self.assertEqual(sr["spec"]["data"][0]["remoteRef"], {"key": "MINIFLUX_OAUTH2_CLIENT_SECRET"})

    def test_helm_external_secret_kubernetes(self):
        doc = podinfo()
        doc["spec"]["cluster"] = "k3d"
        doc["spec"]["secrets"] = [{"key": "PODINFO_A", "env": "A"}]
        files = appgen.render_helm(doc, copy.deepcopy(KUBE))
        es = next(v for k, v in files.items() if k.endswith("/externalsecret-podinfo-secrets.yaml"))
        self.assertEqual(es["spec"]["secretStoreRef"], {"kind": "ClusterSecretStore", "name": "lab-store"})
        self.assertEqual(es["spec"]["data"], [{"secretKey": "A", "remoteRef": {"key": "podinfo-a",
                                                                               "property": "PODINFO_A"}}])


class Negative(unittest.TestCase):
    def test_real_searxng_valid(self):
        self.assertEqual(errors(searxng()), [])

    def test_key_not_rfc1123_refused(self):
        doc = searxng()
        doc["spec"]["secrets"] = [{"env": "SEARXNG_SECRET", "key": "SEARXNG_SECRET_"}]
        self.assertEqual(appgen.schema_errors(doc), [], "le schema admet la cle : le refus doit venir d'appgen")
        self.assertIn("secret 'SEARXNG_SECRET_' : nom de Secret 'searxng-secret-' non conforme RFC 1123 (store ESO "
                      "kubernetes : minuscules, chiffres, '-', debut et fin alphanumeriques)", errors(doc))

    def test_property_refused_on_kubernetes_store(self):
        doc = searxng()
        doc["spec"]["secrets"][0]["property"] = "value"
        self.assertIn("secret 'SEARXNG_SECRET' : property interdite avec un store ESO kubernetes (la property est la "
                      "cle)", errors(doc))

    def test_same_key_accepted_on_doppler_store(self):
        doc = searxng()
        doc["spec"]["cluster"] = "k3d"
        doc["spec"]["secrets"] = [{"env": "SEARXNG_SECRET", "key": "SEARXNG_SECRET_", "property": "value"}]
        self.assertFalse([e for e in errors(doc) if "SEARXNG_SECRET_" in e])


if __name__ == "__main__":
    unittest.main()
