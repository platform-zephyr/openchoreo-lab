"""T-010 : probes derivees de runtime.healthPath (G2) et quota de cellule derive de size x replicas + stockage (G4).

Statique : rendu contre platform/ reel (le CCT service-restricted autorise le trait health-probes) ; la CEL du trait
n'est pas evaluee ici (NOT_TESTED hors cluster).
Lancer : python3 -m unittest discover -s tests/appgen
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "appgen"))
sys.path.insert(0, str(ROOT / "tests" / "appgen"))

import appgen  # noqa: E402
from appgenlib.render_native import project_params  # noqa: E402
from test_extensions import TODAY, Sandbox, stateful, whoami  # noqa: E402

REAL_PLATFORM = ROOT / "platform"
VOLUME = {"profile": "block-rwo", "mountPath": "/data", "size": "1Gi"}


def render(doc: dict) -> dict:
    sb = Sandbox()
    sb.add(doc)
    return appgen.render_all(sb.root, REAL_PLATFORM, today=TODAY)


def comp_dir(name: str) -> str:
    return f"namespaces/default/projects/{name}/components/{name}"


def quota(doc: dict) -> dict:
    name = doc["metadata"]["name"]
    ctx = appgen.Context(clusters_dir=ROOT / "clusters", index={name: doc}, today=TODAY)
    return project_params(doc, ctx.caps(doc["spec"]["cluster"]), {name: doc}).get("quota", {})


class Probes(unittest.TestCase):
    def test_readiness_and_liveness_from_health_path(self):
        doc = whoami()
        port, path = doc["spec"]["runtime"]["port"], doc["spec"]["runtime"]["healthPath"]
        files = render(doc)
        comp = files[f"{comp_dir('whoami')}/component.yaml"]
        trait = next(t for t in comp["spec"]["traits"] if t["name"] == "health-probes")
        handler = {"httpGet": {"port": port, "path": path}}
        self.assertEqual(trait["parameters"]["readiness"], {"enabled": True, "handler": handler, "periodSeconds": 5})
        self.assertEqual(trait["parameters"]["liveness"]["handler"], handler)
        self.assertTrue(trait["parameters"]["liveness"]["enabled"])
        rb = files[f"{comp_dir('whoami')}/release-bindings/whoami-production.yaml"]
        self.assertEqual(rb["spec"]["traitEnvironmentConfigs"][trait["instanceName"]], {"enabled": True})

    def test_trait_frozen_in_release(self):
        files = render(whoami())
        rel = next(v for k, v in files.items() if "/whoami/releases/" in k and k.endswith(".yaml"))
        self.assertIn("health-probes", [t["name"] for t in rel["spec"]["traits"]])
        self.assertIn("health-probes", [t["name"] for t in rel["spec"]["componentProfile"]["traits"]])

    def test_probes_coexist_with_pvc_trait(self):
        comp = render(stateful(whoami(), dict(VOLUME)))[f"{comp_dir('whoami')}/component.yaml"]
        self.assertEqual(sorted(t["name"] for t in comp["spec"]["traits"]),
                         ["health-probes", "persistent-volume-claim"])


class CellQuota(unittest.TestCase):
    def test_small_keeps_cpt_default(self):
        self.assertEqual(quota(whoami()), {})

    def test_medium_times_three(self):
        doc = whoami()
        doc["spec"]["runtime"].update(size="medium", replicas=3)
        # RollingUpdate : 3 pods + 1 de surplus (25 % arrondi au superieur) = 4 x (200m, 256Mi)
        self.assertEqual(quota(doc), {"cpu": "800m", "memory": "1024Mi", "pvcs": "0"})

    def test_archetype_c_pvc_recreate(self):
        # Recreate : aucun surplus ; 1 x small sous le defaut ; 1 PVC
        self.assertEqual(quota(stateful(whoami(), dict(VOLUME))), {"cpu": "300m", "memory": "512Mi", "pvcs": "1"})

    def test_rendered_project_carries_quota(self):
        doc = whoami()
        doc["spec"]["runtime"].update(size="medium", replicas=3)
        proj = render(doc)["namespaces/default/projects/whoami/project.yaml"]
        self.assertEqual(proj["spec"]["parameters"]["quota"]["cpu"], "800m")


if __name__ == "__main__":
    unittest.main()
