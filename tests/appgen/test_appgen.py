"""Tests de tools/appgen : validation, cas negatifs, rendu deterministe, absence de derive.

Lancer : python3 -m unittest discover -s tests/appgen -v   (depuis la racine du depot)
Aucune dependance hors PyYAML et jsonschema.
"""
from __future__ import annotations

import copy
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "appgen"))

import appgen  # noqa: E402  (import apres ajustement de sys.path)

FIXTURE_PLATFORM = ROOT / "tests" / "appgen" / "fixtures" / "platform"
REAL_PLATFORM = ROOT / "platform"


def base_whoami() -> dict:
    # Racine de test : seul clusters/k3d est fourni, donc whoami (cible oke dans le depot) est ramene a k3d.
    doc = appgen.load_yaml(ROOT / "apps" / "whoami" / "app.yaml")
    doc["spec"]["cluster"] = "k3d"
    return doc


def copy_apps_k3d(dst: Path) -> None:
    """Copie apps/ (sans _examples) pour une racine temporaire ; whoami y est force sur k3d."""
    shutil.copytree(ROOT / "apps", dst / "apps", ignore=shutil.ignore_patterns("_examples"))
    p = dst / "apps" / "whoami" / "app.yaml"
    doc = appgen.load_yaml(p)
    doc["spec"]["cluster"] = "k3d"
    p.write_text(_dump(doc), encoding="utf-8")


def base_miniflux() -> dict:
    return appgen.load_yaml(ROOT / "apps" / "miniflux" / "app.yaml")


def errors_for(doc: dict, dirname: str = "whoami") -> list[str]:
    """Erreurs schema + semantiques pour un document modifie."""
    return appgen.schema_errors(doc) + appgen.semantic_errors(doc, dirname, cluster_gate_open=False)


class PilotValidation(unittest.TestCase):
    def test_pilot_apps_and_example_are_valid(self):
        count, errors = appgen.validate_all(ROOT, examples=True)
        self.assertEqual(errors, [], "erreurs de validation des apps du depot")
        self.assertGreaterEqual(count, 4, "au moins 3 apps pilote + 1 exemple attendus")

    def test_render_refuses_without_platform(self):
        with self.assertRaises(appgen.AppError):
            appgen.load_platform(ROOT / "tests" / "appgen" / "does-not-exist")


class NegativeCases(unittest.TestCase):
    """Chaque cas doit etre refuse avec un message contenant la cle attendue."""

    def assertRefused(self, doc, expected: str, dirname: str = "whoami"):
        found = errors_for(doc, dirname)
        self.assertTrue(found, f"aucune erreur, attendu : {expected}")
        self.assertTrue(any(expected in e for e in found), f"attendu '{expected}', obtenu : {found}")

    def test_plaintext_secret_in_env_name(self):
        doc = base_whoami()
        doc["spec"]["runtime"]["env"] = {"DB_PASSWORD": "hunter2"}
        self.assertRefused(doc, "ressemble a un secret")

    def test_secret_like_value_in_env(self):
        doc = base_whoami()
        doc["spec"]["runtime"]["env"] = {"FEATURE_FLAG": "ghp_" + "a" * 36}
        self.assertRefused(doc, "valeur de type secret")

    def test_url_with_credentials_in_env(self):
        doc = base_whoami()
        doc["spec"]["runtime"]["env"] = {"UPSTREAM": "https://user:pw@example.org/feed"}
        self.assertRefused(doc, "valeur de type secret")

    def test_image_without_digest(self):
        doc = base_whoami()
        doc["spec"]["source"]["image"] = "traefik/whoami:v1.10.3"
        self.assertRefused(doc, "does not match")

    def test_closed_gate_refuses_oke(self):
        doc = base_whoami()
        doc["spec"]["cluster"] = "oke"
        self.assertRefused(doc, "gate OKE non franchi")

    def test_public_without_auth(self):
        doc = base_miniflux()
        doc["spec"]["exposure"]["auth"] = "none"
        self.assertRefused(doc, "exposition publique sans authentification", "miniflux")

    def test_public_without_host(self):
        doc = base_miniflux()
        del doc["spec"]["exposure"]["host"]
        self.assertRefused(doc, "host", "miniflux")

    def test_load_balancer_value_refused(self):
        doc = base_whoami()
        doc["metadata"]["description"] = "LoadBalancer"
        self.assertRefused(doc, "valeur interdite 'LoadBalancer'")

    def test_unknown_service_field_refused(self):
        doc = base_whoami()
        doc["spec"]["service"] = {"type": "LoadBalancer"}
        self.assertRefused(doc, "Additional properties")

    def test_host_path_refused(self):
        doc = base_whoami()
        doc["spec"]["runtime"]["hostPath"] = "/var/lib"
        self.assertRefused(doc, "Additional properties")

    def test_unknown_top_level_field_refused(self):
        doc = base_whoami()
        doc["spec"]["autoDeploy"] = True
        self.assertRefused(doc, "Additional properties")

    def test_delivery_mismatch_refused(self):
        doc = base_whoami()
        doc["spec"]["delivery"] = "helm"
        self.assertRefused(doc, "differe du calcul")

    def test_irreplaceable_backup_refused(self):
        doc = base_whoami()
        doc["spec"]["backup"] = {"class": "irreplaceable", "rpo": "1h", "rto": "2h", "retention": "7d"}
        self.assertRefused(doc, "irreplaceable refuse")

    def test_oidc_secret_key_not_declared(self):
        doc = base_miniflux()
        doc["spec"]["identity"]["oidc"]["clientSecretKey"] = "MINIFLUX_UNDECLARED"
        self.assertRefused(doc, "absent de secrets", "miniflux")

    def test_secret_prefix_wrong(self):
        doc = base_miniflux()
        doc["spec"]["secrets"][0]["key"] = "OTHER_OAUTH2_CLIENT_SECRET"
        self.assertRefused(doc, "prefixe 'MINIFLUX_'", "miniflux")

    def test_oidc_client_id_override_refused(self):
        doc = base_miniflux()
        doc["spec"]["runtime"]["env"]["OAUTH2_CLIENT_ID"] = "other"
        self.assertRefused(doc, "OAUTH2_CLIENT_ID interdit", "miniflux")

    def test_oke_without_gate_refused(self):
        doc = base_whoami()
        doc["spec"]["cluster"] = "oke"
        self.assertRefused(doc, "gate OKE non franchi")

    def test_pvc_with_two_replicas_refused(self):
        doc = base_miniflux()
        doc["spec"]["profile"] = "stateful"
        doc["spec"]["database"] = None
        del doc["spec"]["database"]
        doc["spec"]["storage"] = {"profile": "block-rwo", "mountPath": "/data", "size": "1Gi"}
        doc["spec"]["update"] = {"strategy": "Recreate"}
        doc["spec"]["runtime"]["replicas"] = 2
        self.assertRefused(doc, "PVC RWO", "miniflux")

    def test_stateless_with_database_refused(self):
        doc = base_whoami()
        doc["spec"]["database"] = {"engine": "postgres"}
        self.assertRefused(doc, "database")

    def test_port_below_1024_refused(self):
        doc = base_whoami()
        doc["spec"]["runtime"]["port"] = 80
        self.assertRefused(doc, "less than the minimum")

    def test_database_other_instance_refused(self):
        doc = base_miniflux()
        doc["spec"]["database"]["instance"] = "pg-shared"
        self.assertRefused(doc, "lab-pg", "miniflux")

    def test_chart_oci_without_digest_refused(self):
        doc = {
            "apiVersion": "platform.smadja.dev/v2alpha1", "kind": "App",
            "metadata": {"name": "podinfo", "owner": "user:default/paul", "description": "x"},
            "spec": {
                "source": {"chart": {"repo": "oci://ghcr.io/stefanprodan/charts", "name": "podinfo", "version": "6.9.2"}},
                "cluster": "k3d", "environments": ["production"], "profile": "stateless",
                "exposure": {"mode": "private", "auth": "none"}, "network": {"egress": "none"},
                "backup": {"class": "none"}, "observability": {"metrics": {"enabled": False}},
            },
        }
        self.assertRefused(doc, "digest", "podinfo")

    def test_duplicate_public_host_across_apps(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            for name in ("alpha", "beta"):
                d = tmp_root / "apps" / name
                d.mkdir(parents=True)
                doc = base_miniflux()
                doc["metadata"]["name"] = name
                doc["spec"]["database"]["envVar"] = "DATABASE_URL"
                doc["spec"]["identity"]["oidc"]["clientSecretKey"] = "MINIFLUX_OAUTH2_CLIENT_SECRET"
                doc["spec"]["secrets"] = [{"env": "OAUTH2_CLIENT_SECRET", "key": "MINIFLUX_OAUTH2_CLIENT_SECRET"}]
                doc["spec"]["secrets"][0]["key"] = "ALPHA_OAUTH2_CLIENT_SECRET" if name == "alpha" else "BETA_OAUTH2_CLIENT_SECRET"
                doc["spec"]["identity"]["oidc"]["clientSecretKey"] = doc["spec"]["secrets"][0]["key"]
                doc["spec"]["exposure"]["host"] = "same.lab.smadja.dev"
                (d / "app.yaml").write_text(_dump(doc), encoding="utf-8")
            _, errors = appgen.validate_all(tmp_root, examples=False)
            self.assertTrue(any("deja utilise" in e for e in errors), errors)


def _dump(doc) -> str:
    import yaml
    return yaml.safe_dump(doc, sort_keys=False)


class RenderBehaviour(unittest.TestCase):
    def render(self, platform=FIXTURE_PLATFORM, root=ROOT):
        return appgen.render_all(root, platform, cluster_gate_open=True)

    def test_render_is_deterministic(self):
        first = self.render()
        second = self.render()
        self.assertEqual(first, second)

    def test_no_drift_between_two_renders(self):
        with tempfile.TemporaryDirectory() as tmp:
            out_a, out_b = Path(tmp) / "a", Path(tmp) / "b"
            appgen.write_tree(self.render(), out_a)
            appgen.write_tree(self.render(), out_b)
            self.assertEqual(appgen.diff_trees(out_a, out_b), [])

    def test_drift_is_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            out_a, out_b = Path(tmp) / "a", Path(tmp) / "b"
            appgen.write_tree(self.render(), out_a)
            shutil.copytree(out_a, out_b)
            target = next(out_b.rglob("releases/*.yaml"))
            target.write_text(target.read_text() + "# derive\n", encoding="utf-8")
            self.assertTrue(any("modifie" in d for d in appgen.diff_trees(out_a, out_b)))

    def test_components_never_autodeploy(self):
        for rel, obj in self.render().items():
            if isinstance(obj, dict) and obj.get("apiVersion") == "openchoreo.dev/v1alpha1" and obj.get("kind") == "Component":
                self.assertIs(obj["spec"]["autoDeploy"], False, rel)

    def test_release_binding_points_to_rendered_release(self):
        files = self.render()
        releases = {Path(k).stem for k in files if "/releases/" in k}
        for rel, obj in files.items():
            if isinstance(obj, dict) and obj.get("kind") == "ReleaseBinding":
                self.assertIn(obj["spec"]["releaseName"], releases, rel)

    def test_secrets_are_references_only(self):
        files = self.render()
        for rel, obj in files.items():
            text = _dump(obj)
            for pat in appgen.SECRET_LIKE_VALUE:
                self.assertIsNone(pat.search(text), f"valeur de type secret dans {rel}")
        miniflux_wl = files["namespaces/default/projects/miniflux/components/miniflux/workload.yaml"]
        secret_envs = [e for e in miniflux_wl["spec"]["container"]["env"] if "valueFrom" in e]
        self.assertTrue(secret_envs)
        for e in secret_envs:
            self.assertNotIn("value", e)

    def test_database_binding_and_unpinned_release(self):
        files = self.render()
        wl = files["namespaces/default/projects/miniflux/components/miniflux/workload.yaml"]
        self.assertEqual(wl["spec"]["dependencies"]["resources"][0]["envBindings"], {"url": "DATABASE_URL"})
        rrb = files["namespaces/default/projects/miniflux/resource-bindings/miniflux-db-production.yaml"]
        self.assertNotIn("resourceRelease", rrb["spec"], "pin absent : le binding doit rester sans release")

    def test_pin_is_rendered_when_present(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            copy_apps_k3d(tmp_root)
            (tmp_root / "pins").mkdir()
            (tmp_root / "pins" / "resource-releases.yaml").write_text(
                "pins:\n  miniflux/production: miniflux-db-abc123\n", encoding="utf-8")
            files = self.render(root=tmp_root)
            rrb = files["namespaces/default/projects/miniflux/resource-bindings/miniflux-db-production.yaml"]
            self.assertEqual(rrb["spec"]["resourceRelease"], "miniflux-db-abc123")

    def test_standalone_platform_missing_component_type(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(appgen.AppError):
                self.render(platform=Path(tmp))


class GeneratedTreeNoDrift(unittest.TestCase):
    def test_committed_generated_matches_render(self):
        if not REAL_PLATFORM.is_dir():
            self.skipTest("platform/ absent : rendu de reference impossible")
        index = appgen.load_platform(REAL_PLATFORM)
        if ("ClusterComponentType", appgen.CCT_NAME) not in index or ("ClusterTrait", appgen.PVC_TRAIT) not in index:
            self.skipTest("CCT service-restricted ou ClusterTrait persistent-volume-claim absente de platform/")
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "generated"
            appgen.write_tree(appgen.render_all(ROOT, REAL_PLATFORM, True), out)
            self.assertEqual(appgen.diff_trees(out, ROOT / "generated"), [])


if __name__ == "__main__":
    unittest.main()
