"""Corrections statiques issues de la preuve GitOps k3d (docs/GITOPS-PROOF.md §4) : G1, A1-A7, O1.

Lancer : python3 -m unittest discover -s tests/appgen -v   (depuis la racine du depot)
Aucun cluster : A5 utilise `argocd admin settings resource-overrides health` en local (KUBECONFIG=/dev/null),
saute si le binaire argocd est absent.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "appgen"))
sys.path.insert(0, str(ROOT / "tests" / "appgen"))

import appgen  # noqa: E402
from appgenlib import config as appgen_config  # noqa: E402
from test_extensions import Base, Sandbox, whoami  # noqa: E402

MANIFESTS = ROOT / "platform" / "install" / "manifests"
HEALTH_VALUES = ROOT / "platform" / "install" / "argocd" / "health" / "values-openchoreo-health.yaml"
SYNC_KEY = "argocd.argoproj.io/sync-options"
BASE_WHOAMI = "namespaces/default/projects/whoami"


def releases_of(files: dict, cname: str = "whoami") -> dict:
    prefix = f"{BASE_WHOAMI}/components/{cname}/releases/"
    return {k: v for k, v in files.items() if k.startswith(prefix)}


def write_generated(sb: Sandbox, files: dict) -> None:
    out = sb.root / "generated"
    if out.exists():
        shutil.rmtree(out)
    appgen.write_tree(files, out)


def env_production() -> dict:
    docs = list(yaml.safe_load_all((MANIFESTS / "40-openchoreo-env.yaml").read_text(encoding="utf-8")))
    return next(d for d in docs if d and d["kind"] == "Environment" and d["metadata"]["name"] == "production")


def dataplane_template() -> dict:
    text = (MANIFESTS / "30-clusterdataplane.yaml.tmpl").read_text(encoding="utf-8")
    return yaml.safe_load(text.replace("__AGENT_CA__", "        DUMMY-CA"))


# ----------------------------------------------------------------------------- G1


class G1InternalGateway(Base):
    def test_environment_declares_internal_gateway(self):
        internal = env_production()["spec"]["gateway"]["ingress"]["internal"]
        self.assertEqual((internal["name"], internal["namespace"]), ("gateway-default", "openchoreo-data-plane"))
        self.assertEqual(internal["http"]["listenerName"], "http")
        self.assertEqual(internal["http"]["port"], 19080)
        self.assertTrue(internal["http"]["host"])

    def test_dataplane_template_declares_internal_gateway(self):
        ingress = dataplane_template()["spec"]["gateway"]["ingress"]
        self.assertIn("internal", ingress)
        self.assertEqual(ingress["internal"], env_production()["spec"]["gateway"]["ingress"]["internal"])

    def test_environment_keeps_dataplane_external_gateway(self):
        # Si spec.gateway de l'Environment remplace celui du DataPlane [S], les apps publiques gardent external.
        self.assertEqual(env_production()["spec"]["gateway"]["ingress"]["external"],
                         dataplane_template()["spec"]["gateway"]["ingress"]["external"])

    def _env(self, ingress: dict) -> None:
        (self.sb.platform / "env.yaml").write_text(yaml.safe_dump({
            "apiVersion": "openchoreo.dev/v1alpha1", "kind": "Environment",
            "metadata": {"name": "production", "namespace": "default"},
            "spec": {"dataPlaneRef": {"kind": "ClusterDataPlane", "name": "default"},
                     **({"gateway": {"ingress": ingress}} if ingress else {})}}), encoding="utf-8")

    def test_render_refuses_private_app_without_internal_gateway(self):
        self._env({"external": {"name": "g", "namespace": "n", "http": {"host": "h", "port": 1}}})
        self.sb.add(whoami())
        with self.assertRaisesRegex(appgen.AppError, "gateway.ingress.internal"):
            self.sb.render()

    def test_render_accepts_private_app_with_internal_gateway(self):
        self._env({"internal": {"name": "g", "namespace": "n", "http": {"host": "h", "port": 1}}})
        self.sb.add(whoami())
        self.assertTrue(self.sb.render())

    def test_real_platform_renders_whoami(self):
        files = appgen.render_all(ROOT, ROOT / "platform", True)
        self.assertIn(f"{BASE_WHOAMI}/components/whoami/component.yaml", files)


# ----------------------------------------------------------------------------- A1


class A1SyncOptions(Base):
    def test_annotations_on_component_release_resource_only(self):
        self.sb.add(whoami())
        expected = {"Component": "Prune=false", "ComponentRelease": "Prune=false,Delete=false",
                    "Resource": "Prune=false"}
        seen = set()
        for rel, obj in self.sb.render().items():
            if not isinstance(obj, dict) or obj.get("apiVersion") != "openchoreo.dev/v1alpha1":
                continue
            ann = (obj["metadata"].get("annotations") or {}).get(SYNC_KEY)
            self.assertEqual(ann, expected.get(obj["kind"]), rel)
            seen.add(obj["kind"])
        self.assertTrue({"Component", "ComponentRelease"} <= seen)

    def test_resource_annotation_on_real_tree(self):
        files = appgen.render_all(ROOT, ROOT / "platform", True)
        res = files["namespaces/default/projects/miniflux/resources/miniflux-db.yaml"]
        self.assertEqual(res["metadata"]["annotations"][SYNC_KEY], "Prune=false")

    def test_release_name_unchanged_by_annotations(self):
        # Le hash ne porte que sur spec : ajouter des annotations ne cree pas de nouvelle release.
        files = appgen.render_all(ROOT, ROOT / "platform", True)
        self.assertIn(f"{BASE_WHOAMI}/components/whoami/releases/whoami-31985273d8.yaml", files)


# ----------------------------------------------------------------------------- A2


class A2AppendOnlyReleases(Base):
    def _two_versions(self):
        doc = whoami()
        self.sb.add(doc)
        first = self.sb.render()
        write_generated(self.sb, first)
        doc["spec"]["runtime"]["env"] = {"WHOAMI_NAME": "v2"}
        self.sb.add(doc)
        return first, self.sb.render()

    def test_previous_release_kept(self):
        first, second = self._two_versions()
        old = set(releases_of(first))
        self.assertEqual(len(old), 1)
        self.assertTrue(old < set(releases_of(second)), "l'ancienne release doit rester dans generated/")
        self.assertEqual(len(releases_of(second)), 2)
        old_obj = second[next(iter(old))]
        self.assertEqual(old_obj["metadata"]["annotations"][SYNC_KEY], "Prune=false,Delete=false")
        rb = second[f"{BASE_WHOAMI}/components/whoami/release-bindings/whoami-production.yaml"]
        self.assertNotIn(rb["spec"]["releaseName"], {Path(k).stem for k in old})

    def test_render_twice_is_stable_with_history(self):
        _, second = self._two_versions()
        write_generated(self.sb, second)
        self.assertEqual(self.sb.render(), second)

    def test_tampered_history_release_refused(self):
        first, _ = self._two_versions()
        path = self.sb.root / "generated" / next(iter(releases_of(first)))
        obj = yaml.safe_load(path.read_text(encoding="utf-8"))
        obj["spec"]["workload"]["container"]["image"] = "evil@sha256:" + "0" * 64
        path.write_text(yaml.safe_dump(obj), encoding="utf-8")
        with self.assertRaisesRegex(appgen.AppError, "modifiee a la main"):
            self.sb.render()

    def test_removed_app_drops_history(self):
        _, second = self._two_versions()
        write_generated(self.sb, second)
        shutil.rmtree(self.sb.root / "apps" / "whoami")
        self.assertEqual(releases_of(self.sb.render()), {})

    def test_base_check_flags_deleted_release(self):
        base = {f"generated/{BASE_WHOAMI}/components/whoami/component.yaml",
                f"generated/{BASE_WHOAMI}/components/whoami/releases/whoami-aaaaaaaaaa.yaml"}
        current = {f"generated/{BASE_WHOAMI}/components/whoami/component.yaml",
                   f"generated/{BASE_WHOAMI}/components/whoami/releases/whoami-bbbbbbbbbb.yaml"}
        errs = appgen.release_deletions(base, current)
        self.assertEqual(len(errs), 1)
        self.assertIn("whoami-aaaaaaaaaa", errs[0])

    def test_base_check_allows_release_purge_with_component(self):
        base = {f"generated/{BASE_WHOAMI}/components/whoami/component.yaml",
                f"generated/{BASE_WHOAMI}/components/whoami/releases/whoami-aaaaaaaaaa.yaml"}
        self.assertEqual(appgen.release_deletions(base, set()), [])

    def test_binding_to_missing_release_detected(self):
        first, _ = self._two_versions()
        gen = self.sb.root / "generated"
        self.assertEqual(appgen.binding_errors(gen), [])
        for p in gen.rglob("releases/*.yaml"):
            p.unlink()
        self.assertTrue(any("releaseName" in e for e in appgen.binding_errors(gen)))


# ----------------------------------------------------------------------------- A3


class A3ProjectPin(Base):
    def test_project_pin_rendered(self):
        self.sb.add(whoami())
        (self.sb.root / "pins").mkdir()
        (self.sb.root / "pins" / "project-releases.yaml").write_text(
            "pins:\n  whoami/production: whoami-7c4886dc7d\n", encoding="utf-8")
        prb = self.sb.render()[f"{BASE_WHOAMI}/project-bindings/whoami-production.yaml"]
        self.assertEqual(prb["spec"]["projectRelease"], "whoami-7c4886dc7d")

    def test_no_pin_no_field(self):
        self.sb.add(whoami())
        prb = self.sb.render()[f"{BASE_WHOAMI}/project-bindings/whoami-production.yaml"]
        self.assertNotIn("projectRelease", prb["spec"])

    def test_pin_project_command(self):
        pins = self.sb.root / "pins" / "project-releases.yaml"
        # T-214 : la CLI lit le chemin dans appgenlib.config (le module appgen n'est plus qu'une facade).
        old = appgen_config.PROJECT_PINS_PATH
        appgen_config.PROJECT_PINS_PATH = pins
        self.addCleanup(setattr, appgen_config, "PROJECT_PINS_PATH", old)
        self.assertEqual(appgen.main(["pin-project", "whoami", "production", "whoami-7c4886dc7d"]), 0)
        self.assertEqual(appgen.load_yaml(pins)["pins"], {"whoami/production": "whoami-7c4886dc7d"})
        self.assertEqual(appgen.main(["pin-project", "whoami", "production", "other-7c4886dc7d"]), 1)

    def test_project_change_without_pin_warns(self):
        base = {"whoami": {"egress": "none", "quota": {"cpu": "300m", "memory": "512Mi", "pvcs": "0"}}}
        cur = {"whoami": {"egress": "none", "quota": {"cpu": "300m", "memory": "512Mi", "pvcs": "1"}}}
        warns = appgen.project_pin_warnings(base, cur, {}, {})
        self.assertTrue(any("pin-project" in w for w in warns), warns)
        self.assertEqual(appgen.project_pin_warnings(base, cur, {}, {"whoami/production": "whoami-x"}), [])
        self.assertEqual(appgen.project_pin_warnings(base, base, {}, {}), [])
        self.assertEqual(appgen.project_pin_warnings({}, cur, {}, {}), [], "app nouvelle : pas de 2e PR")


# ----------------------------------------------------------------------------- A4


class A4StrategySwitch(Base):
    def _deployed(self, doc):
        self.sb.add(doc)
        write_generated(self.sb, self.sb.render())

    def test_rolling_to_recreate_refused(self):
        self._deployed(whoami())
        doc = whoami()
        doc["spec"]["profile"] = "stateful"
        doc["spec"]["storage"] = {"profile": "block-rwo", "mountPath": "/data", "size": "1Gi"}
        doc["spec"]["data"] = {"class": "rebuildable"}
        doc["spec"]["update"] = {"strategy": "Recreate"}
        self.sb.add(doc)
        with self.assertRaisesRegex(appgen.AppError, "RollingUpdate -> Recreate"):
            self.sb.render()

    def test_recreate_to_rolling_allowed(self):
        doc = whoami()
        doc["spec"]["update"] = {"strategy": "Recreate"}
        self._deployed(doc)
        self.sb.add(whoami())
        self.assertTrue(self.sb.render())

    def test_new_app_stateful_allowed(self):
        doc = whoami()
        doc["spec"]["profile"] = "stateful"
        doc["spec"]["storage"] = {"profile": "block-rwo", "mountPath": "/data", "size": "1Gi"}
        doc["spec"]["data"] = {"class": "rebuildable"}
        doc["spec"]["update"] = {"strategy": "Recreate"}
        self.sb.add(doc)
        self.assertTrue(self.sb.render())


# ----------------------------------------------------------------------------- A7


class A7QuotaSurge(Base):
    def test_surge_pods_follow_default_max_surge(self):
        # maxSurge absent du CCT => defaut Kubernetes 25 %, arrondi au superieur.
        self.assertEqual([appgen.surge_pods(n) for n in (1, 2, 3, 4, 5)], [1, 1, 1, 1, 2])

    def test_rolling_medium_gets_surge_margin(self):
        doc = whoami()
        doc["spec"]["runtime"]["size"] = "medium"
        doc["spec"]["runtime"]["replicas"] = 2
        self.sb.add(doc)
        quota = self.sb.render()[f"{BASE_WHOAMI}/project.yaml"]["spec"]["parameters"]["quota"]
        self.assertEqual(quota["cpu"], "600m")      # 2 x 200m + 1 pod de surplus
        self.assertEqual(quota["memory"], "768Mi")  # 2 x 256Mi + 256Mi

    def test_recreate_has_no_surge(self):
        doc = whoami()
        doc["spec"]["profile"] = "stateful"
        doc["spec"]["storage"] = {"profile": "block-rwo", "mountPath": "/data", "size": "1Gi"}
        doc["spec"]["data"] = {"class": "rebuildable"}
        doc["spec"]["update"] = {"strategy": "Recreate"}
        doc["spec"]["runtime"]["size"] = "medium"
        self.sb.add(doc)
        quota = self.sb.render()[f"{BASE_WHOAMI}/project.yaml"]["spec"]["parameters"]["quota"]
        self.assertEqual(quota, {"cpu": "300m", "memory": "512Mi", "pvcs": "1"})


# ----------------------------------------------------------------------------- O1


class O1LabPlatformDestination(unittest.TestCase):
    def test_destination_namespace_allowed_by_project(self):
        app = appgen.load_yaml(ROOT / "platform" / "install" / "argocd" / "apps" / "lab-platform.yaml")
        ns = app["spec"]["destination"].get("namespace")
        self.assertTrue(ns, "destination.namespace absent : InvalidSpecError sur OKE")
        projects = []
        for p in (ROOT / "platform" / "install" / "argocd").glob("project-*.yaml"):
            projects += [d for d in yaml.safe_load_all(p.read_text(encoding="utf-8")) if d]
        proj = next(d for d in projects if d["kind"] == "AppProject" and d["metadata"]["name"] == app["spec"]["project"])
        self.assertIn(ns, {d.get("namespace") for d in proj["spec"]["destinations"]})


# ----------------------------------------------------------------------------- A5


@unittest.skipIf(shutil.which("argocd") is None, "binaire argocd absent")
class A5ArgoHealth(unittest.TestCase):
    KINDS = ("ReleaseBinding", "ProjectReleaseBinding", "ResourceReleaseBinding", "Component")

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.dir = Path(cls.tmp.name)
        cm = yaml.safe_load(HEALTH_VALUES.read_text(encoding="utf-8"))["configs"]["cm"]
        (cls.dir / "cm.yaml").write_text(yaml.safe_dump({
            "apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "argocd-cm", "namespace": "argocd"},
            "data": cm}), encoding="utf-8")
        cls.cm = cm

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def health(self, kind: str, status: dict | None, generation: int = 1) -> str:
        obj = {"apiVersion": "openchoreo.dev/v1alpha1", "kind": kind,
               "metadata": {"name": "x", "namespace": "default", "generation": generation}, "spec": {}}
        if status is not None:
            obj["status"] = status
        path = self.dir / f"{kind}.yaml"
        path.write_text(yaml.safe_dump(obj), encoding="utf-8")
        env = {**os.environ, "KUBECONFIG": os.devnull}
        out = subprocess.run(["argocd", "admin", "settings", "resource-overrides", "health", str(path),
                              "--argocd-cm-path", str(self.dir / "cm.yaml")],
                             capture_output=True, text=True, env=env, timeout=60)
        self.assertEqual(out.returncode, 0, out.stderr[-500:])
        for line in out.stdout.splitlines():
            if line.startswith("STATUS:"):
                return line.split(":", 1)[1].strip()
        self.fail(out.stdout)

    @staticmethod
    def ready(status: str, reason: str, gen: int = 1) -> dict:
        return {"conditions": [{"type": "ReleaseSynced", "status": "True", "reason": "ReleaseSynced"},
                               {"type": "Ready", "status": status, "reason": reason, "message": "m",
                                "observedGeneration": gen}]}

    def test_all_kinds_declared(self):
        for kind in self.KINDS:
            self.assertIn(f"resource.customizations.health.openchoreo.dev_{kind}", self.cm)

    def test_rendering_failed_is_degraded(self):          # T-ARGO-HEALTH
        self.assertEqual(self.health("ReleaseBinding", self.ready("False", "RenderingFailed")), "Degraded")

    def test_apply_failed_is_degraded(self):              # T-STRATEGY
        self.assertEqual(self.health("ReleaseBinding", self.ready("False", "ResourceApplyFailed")), "Degraded")

    def test_ready_is_healthy(self):
        for kind in self.KINDS:
            self.assertEqual(self.health(kind, self.ready("True", "Ready")), "Healthy", kind)

    def test_no_status_is_progressing(self):
        self.assertEqual(self.health("ProjectReleaseBinding", None), "Progressing")

    def test_stale_generation_is_progressing(self):
        self.assertEqual(self.health("ReleaseBinding", self.ready("True", "Ready", gen=1), generation=2), "Progressing")

    def test_component_without_ready_is_healthy(self):
        self.assertEqual(self.health("Component", {"conditions": []}), "Healthy")


if __name__ == "__main__":
    unittest.main()
