"""Tests des extensions du contrat (E1, E2, E3, E6-E9, E12, parcours Helm) : cas positifs et negatifs.

Lancer : python3 -m unittest discover -s tests/appgen -v   (depuis la racine du depot)
Les politiques de cluster de test sont ecrites dans une racine temporaire (clusters/<c>/capabilities.yaml).
"""
from __future__ import annotations

import copy
import datetime
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

import appgen  # noqa: E402

FIX = ROOT / "tests" / "appgen" / "fixtures"
TODAY = datetime.date(2026, 11, 17)

K3D_CAPS = appgen.load_yaml(ROOT / "clusters" / "k3d" / "capabilities.yaml")


def caps_doc(**spec_overrides) -> dict:
    doc = copy.deepcopy(K3D_CAPS)
    doc["spec"].update(spec_overrides)
    return doc


RICH_CAPS = caps_doc(
    cilium=True,
    privateEgressCIDRs=["10.0.20.192/32"],
    databaseInstances={
        "lab-pg": {"resourceType": "cnpg-lab-db", "namespace": "lab-pg", "cluster": "lab-pg", "backup": "none"},
        "pg-shared": {"resourceType": "cnpg-shared-db", "namespace": "data", "cluster": "pg-shared", "backup": "cnpg"},
    },
    identityProviders=["thunderid", "authentik"],
    storageClasses={"block-rwo": "local-path", "rwx-shared": "nfs-rwx"},
    backupMechanisms=["none", "cnpg", "velero"],
)


def whoami() -> dict:
    # Racine de test : clusters/k3d uniquement ; le gate OKE est teste dans test_appgen (NegativeCases).
    doc = appgen.load_yaml(ROOT / "apps" / "whoami" / "app.yaml")
    doc["spec"]["cluster"] = "k3d"
    return doc


def miniflux() -> dict:
    return appgen.load_yaml(ROOT / "apps" / "miniflux" / "app.yaml")


def podinfo() -> dict:
    return appgen.load_yaml(ROOT / "apps" / "_examples" / "podinfo-helm" / "app.yaml")


def stateful(doc: dict, storage) -> dict:
    doc["spec"]["profile"] = "stateful"
    doc["spec"]["storage"] = storage
    doc["spec"]["update"] = {"strategy": "Recreate"}
    return doc


class Sandbox:
    """Racine temporaire : apps/, clusters/k3d, platform (fixtures + propositions)."""

    def __init__(self, caps: dict | None = None, ext_platform: bool = True):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "clusters" / "k3d").mkdir(parents=True)
        (self.root / "clusters" / "k3d" / "capabilities.yaml").write_text(
            yaml.safe_dump(caps or K3D_CAPS, sort_keys=False), encoding="utf-8")
        self.platform = self.root / "platform"
        shutil.copytree(FIX / "platform", self.platform)
        if ext_platform:
            shutil.copytree(FIX / "platform-ext", self.platform / "ext")

    def add(self, doc: dict, values: dict | None = None) -> None:
        d = self.root / "apps" / doc["metadata"]["name"]
        d.mkdir(parents=True, exist_ok=True)
        (d / "app.yaml").write_text(yaml.safe_dump(doc, sort_keys=False), encoding="utf-8")
        if values is not None:
            (d / "values.yaml").write_text(yaml.safe_dump(values, sort_keys=False), encoding="utf-8")

    def errors(self, **kw) -> list[str]:
        return appgen.validate_all_full(self.root, examples=False, today=TODAY, **kw)[1]

    def warnings(self, **kw) -> list[str]:
        return appgen.validate_all_full(self.root, examples=False, today=TODAY, **kw)[2]

    def render(self, **kw) -> dict:
        return appgen.render_all(self.root, self.platform, today=TODAY, **kw)

    def close(self):
        self.tmp.cleanup()


class Base(unittest.TestCase):
    caps = K3D_CAPS

    def setUp(self):
        self.sb = Sandbox(self.caps)
        self.addCleanup(self.sb.close)

    def assertRefused(self, docs, expected: str, values=None, **kw):
        for d in docs if isinstance(docs, list) else [docs]:
            self.sb.add(d, values)
        found = self.sb.errors(**kw)
        self.assertTrue(any(expected in e for e in found), f"attendu '{expected}', obtenu : {found}")

    def assertValid(self, docs, values=None, **kw):
        for d in docs if isinstance(docs, list) else [docs]:
            self.sb.add(d, values)
        self.assertEqual(self.sb.errors(**kw), [])


# ----------------------------------------------------------------------------- E3 egress


class EgressK3d(Base):
    """Cluster sans Cilium (k3d) : FQDN refuse ; CIDR et app autorises."""

    def test_aliases_still_valid(self):
        self.assertValid([whoami(), miniflux()])

    def test_public_cidr_with_auto_except(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"cidr": "100.0.0.0/8", "ports": [443]}]
        self.sb.add(doc)
        self.assertEqual(self.sb.errors(), [])
        proj = self.sb.render()["namespaces/default/projects/whoami/project.yaml"]
        self.assertEqual(proj["spec"]["parameters"]["egress"], "none")
        self.assertEqual(proj["spec"]["parameters"]["egressCIDRs"],
                         [{"cidr": "100.0.0.0/8", "except": ["100.64.0.0/10"], "ports": [443]}])

    def test_fqdn_refused_without_cilium(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"fqdn": "api.minimax.io", "ports": [443]}]
        self.assertRefused(doc, "sans Cilium")

    def test_fqdn_unenforced_flag_warns_and_marks(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"fqdn": "api.minimax.io", "ports": [443]}]
        self.sb.add(doc)
        self.assertEqual(self.sb.errors(allow_unenforced_fqdn=True), [])
        self.assertTrue(self.sb.warnings(allow_unenforced_fqdn=True))
        files = self.sb.render(allow_unenforced_fqdn=True)
        proj = files["namespaces/default/projects/whoami/project.yaml"]
        self.assertNotIn("egressFQDNs", proj["spec"]["parameters"], "fail-closed : regles FQDN non transmises")
        cnp = files["previews/whoami/production/ciliumnetworkpolicy-egress-fqdn.yaml"]
        self.assertEqual(cnp["metadata"]["annotations"]["platform.smadja.dev/enforced"], "false")

    def test_world_cidr_refused(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"cidr": "0.0.0.0/0", "ports": [443]}]
        self.assertRefused(doc, "public-internet")

    def test_too_wide_cidr_refused(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"cidr": "64.0.0.0/2", "ports": [443]}]
        self.assertRefused(doc, "trop large")

    def test_imds_refused(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"cidr": "169.254.169.254/32", "ports": [80]}]
        self.assertRefused(doc, "IMDS")

    def test_private_cidr_refused_by_default(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"cidr": "10.0.20.192/32", "ports": [443]}]
        self.assertRefused(doc, "privateEgressCIDRs")

    def test_cidr_not_network_address_refused(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"cidr": "8.8.8.8/8", "ports": [53]}]
        self.assertRefused(doc, "adresse de reseau exacte")

    def test_rule_without_ports_refused(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"cidr": "1.1.1.0/24"}]
        self.assertRefused(doc, "schema")

    def test_unknown_app_refused(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"app": "nope"}]
        self.assertRefused(doc, "app inconnue")

    def test_self_app_refused(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"app": "whoami"}]
        self.assertRefused(doc, "l'app elle-meme")

    def test_app_rule_renders_connection_and_target_visibility(self):
        consumer = whoami()
        consumer["metadata"]["name"] = "caller"
        consumer["spec"]["network"]["egress"] = [{"app": "whoami"}]
        self.sb.add(consumer)
        self.sb.add(whoami())
        self.assertEqual(self.sb.errors(), [])
        files = self.sb.render()
        wl = files["namespaces/default/projects/caller/components/caller/workload.yaml"]
        self.assertEqual(wl["spec"]["dependencies"]["endpoints"][0],
                         {"project": "whoami", "component": "whoami", "name": "http", "visibility": "namespace",
                          "envBindings": {"address": "WHOAMI_URL"}})
        target = files["namespaces/default/projects/whoami/components/whoami/workload.yaml"]
        self.assertIn("namespace", target["spec"]["endpoints"]["http"]["visibility"])
        np = files["previews/caller/production/networkpolicy-egress-allowlist.yaml"]
        sel = np["spec"]["egress"][0]["to"][0]
        self.assertEqual(sel["namespaceSelector"]["matchLabels"]["openchoreo.dev/project"], "whoami")

    def test_extension_requires_cpt_support(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"cidr": "1.1.1.0/24", "ports": [443]}]
        self.sb.add(doc)
        shutil.rmtree(self.sb.platform / "ext")
        with self.assertRaises(appgen.AppError) as cm:
            self.sb.render()
        self.assertIn("ClusterProjectType", str(cm.exception))


class EgressCilium(Base):
    caps = RICH_CAPS

    def test_fqdn_cidr_rendered_as_cnp_and_np(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [
            {"fqdn": "api.minimax.io", "ports": [443]},
            {"fqdnPattern": "*.eu.r2.cloudflarestorage.com", "ports": [443]},
            {"cidr": "10.0.20.192/32", "ports": [443]},
        ]
        self.sb.add(doc)
        self.assertEqual(self.sb.errors(), [])
        files = self.sb.render()
        params = files["namespaces/default/projects/whoami/project.yaml"]["spec"]["parameters"]
        self.assertEqual(params["egressFQDNs"][1], {"matchPattern": "*.eu.r2.cloudflarestorage.com", "ports": [443]})
        cnp = files["previews/whoami/production/ciliumnetworkpolicy-egress-fqdn.yaml"]
        self.assertEqual(cnp["metadata"]["annotations"]["platform.smadja.dev/enforced"], "true")
        self.assertEqual(len(cnp["spec"]["egress"]), 3)   # DNS + 2 FQDN
        np = files["previews/whoami/production/networkpolicy-egress-allowlist.yaml"]
        self.assertEqual(np["spec"]["egress"][0]["to"][0]["ipBlock"], {"cidr": "10.0.20.192/32"})

    def test_metadata_fqdn_refused(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"fqdn": "metadata.google.internal", "ports": [80]}]
        self.assertRefused(doc, "metadonnees")

    def test_wildcard_tld_refused(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"fqdnPattern": "*.com", "ports": [443]}]
        self.assertRefused(doc, "schema")

    def test_ip_as_fqdn_refused(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"fqdn": "169.254.169.254", "ports": [80]}]
        self.assertRefused(doc, "schema")

    def test_cluster_local_fqdn_refused(self):
        doc = whoami()
        doc["spec"]["network"]["egress"] = [{"fqdn": "kubernetes.default.svc.cluster.local", "ports": [443]}]
        self.assertRefused(doc, "nom interne")


# ----------------------------------------------------------------------------- E1 / E2


class DatabaseAndIdentity(Base):
    caps = RICH_CAPS

    def test_pg_shared_admitted_by_cluster_policy(self):
        doc = miniflux()
        doc["spec"]["database"]["instance"] = "pg-shared"
        self.sb.add(doc)
        self.assertEqual(self.sb.errors(), [])
        files = self.sb.render()
        res = files["namespaces/default/projects/miniflux/resources/miniflux-db.yaml"]
        self.assertEqual(res["spec"]["type"]["name"], "cnpg-shared-db")
        params = files["namespaces/default/projects/miniflux/project.yaml"]["spec"]["parameters"]
        self.assertEqual((params["databaseNamespace"], params["databaseCluster"]), ("data", "pg-shared"))

    def test_unknown_instance_refused(self):
        doc = miniflux()
        doc["spec"]["database"]["instance"] = "pg-prod"
        self.assertRefused(doc, "schema")

    def authentik(self) -> dict:
        doc = miniflux()
        doc["spec"]["identity"]["oidc"].update(
            provider="authentik", issuer="https://auth.smadja.dev/application/o/miniflux/",
            allowedGroups=["admin", "friends"], adminGroup="admin")
        doc["spec"]["network"] = {"egress": [{"fqdn": "auth.smadja.dev", "ports": [443]}]}
        doc["spec"]["runtime"]["env"]["OAUTH2_ADMIN_GROUP"] = "admin"
        doc["spec"]["runtime"]["env"]["OAUTH2_GROUP_CLAIM"] = "groups"
        return doc

    def test_authentik_with_groups_valid(self):
        self.sb.add(self.authentik())
        self.assertEqual(self.sb.errors(), [])
        cat = self.sb.render()["catalog/miniflux/catalog-info.yaml"]
        self.assertEqual(cat["metadata"]["annotations"]["platform.smadja.dev/oidc-allowed-groups"], "admin,friends")

    def test_authentik_without_groups_refused(self):
        doc = self.authentik()
        del doc["spec"]["identity"]["oidc"]["allowedGroups"]
        self.assertRefused(doc, "allowedGroups")

    def test_admin_group_outside_allowed_refused(self):
        doc = self.authentik()
        doc["spec"]["identity"]["oidc"]["allowedGroups"] = ["friends"]
        self.assertRefused(doc, "absent de allowedGroups")

    def test_authentik_without_issuer_egress_refused(self):
        doc = self.authentik()
        doc["spec"]["network"] = {"egress": "none", "allowIdp": True}
        self.assertRefused(doc, "requis")

    def test_admin_group_env_mismatch_refused(self):
        doc = self.authentik()
        doc["spec"]["runtime"]["env"]["OAUTH2_ADMIN_GROUP"] = "friends"
        self.assertRefused(doc, "OAUTH2_ADMIN_GROUP")

    def test_http_issuer_refused(self):
        doc = self.authentik()
        doc["spec"]["identity"]["oidc"]["issuer"] = "http://auth.smadja.dev/"
        self.assertRefused(doc, "schema")


class PolicyOnK3d(Base):
    def test_authentik_not_admitted_on_k3d(self):
        doc = DatabaseAndIdentity.authentik(self)
        self.assertRefused(doc, "non admis sur le cluster 'k3d'")

    def test_pg_shared_not_admitted_on_k3d(self):
        doc = miniflux()
        doc["spec"]["database"]["instance"] = "pg-shared"
        self.assertRefused(doc, "admis : lab-pg")

    def test_missing_cluster_policy_refused(self):
        (self.sb.root / "clusters" / "k3d" / "capabilities.yaml").unlink()
        shutil.rmtree(self.sb.root / "clusters")
        (self.sb.root / "clusters").mkdir()
        self.assertRefused(whoami(), "politique de cluster absente")


# ----------------------------------------------------------------------------- E6 / E7 / E8 / E9


def with_extras(doc: dict) -> dict:
    doc["spec"]["workloads"] = [
        {"name": "worker", "kind": "Deployment", "runtime": {"size": "small", "command": ["/worker"]},
         "database": True, "secrets": ["OAUTH2_CLIENT_SECRET"]},
        {"name": "cache", "kind": "StatefulSet", "runtime": {"size": "small", "port": 6379, "protocol": "TCP"}},
    ]
    doc["spec"]["jobs"] = [{"name": "cleanup", "schedule": "30 21 * * *", "timeZone": "Europe/Paris",
                            "runtime": {"size": "small", "command": ["/cleanup"]}, "database": True}]
    return doc


class Workloads(Base):
    caps = RICH_CAPS

    def test_multi_workloads_and_job_render(self):
        self.sb.add(with_extras(miniflux()))
        self.assertEqual(self.sb.errors(), [])
        files = self.sb.render()
        base = "namespaces/default/projects/miniflux/components"
        self.assertEqual(files[f"{base}/miniflux-worker/component.yaml"]["spec"]["componentType"]["name"],
                         "deployment/worker-restricted")
        self.assertEqual(files[f"{base}/miniflux-cache/component.yaml"]["spec"]["componentType"]["name"],
                         "statefulset/statefulset-restricted")
        cache = files[f"{base}/miniflux-cache/workload.yaml"]["spec"]["endpoints"]["tcp"]
        self.assertEqual(cache["visibility"], ["project"], "workload annexe jamais expose")
        job = files[f"{base}/miniflux-cleanup/component.yaml"]["spec"]
        self.assertEqual(job["parameters"]["concurrencyPolicy"], "Forbid")
        rb = files[f"{base}/miniflux-cleanup/release-bindings/miniflux-cleanup-production.yaml"]["spec"]
        self.assertEqual(rb["componentTypeEnvironmentConfigs"]["schedule"], "30 21 * * *")
        wk = files[f"{base}/miniflux-worker/workload.yaml"]["spec"]
        self.assertEqual(wk["dependencies"]["resources"][0]["ref"], "miniflux-db")
        self.assertNotIn("OAUTH2_CLIENT_ID", [e["key"] for e in wk["container"]["env"]])

    def test_reserved_main_name_refused(self):
        doc = with_extras(miniflux())
        doc["spec"]["workloads"][0]["name"] = "main"
        self.assertRefused(doc, "'main' reserve")

    def test_duplicate_names_refused(self):
        doc = with_extras(miniflux())
        doc["spec"]["jobs"][0]["name"] = "worker"
        self.assertRefused(doc, "nom en double")

    def test_undeclared_secret_refused(self):
        doc = with_extras(miniflux())
        doc["spec"]["workloads"][0]["secrets"] = ["NOPE"]
        self.assertRefused(doc, "absent de spec.secrets")

    def test_sidecar_refused(self):
        doc = with_extras(miniflux())
        doc["spec"]["workloads"][0]["sidecars"] = [{"image": "x"}]
        self.assertRefused(doc, "Additional properties")

    def test_secret_in_worker_env_refused(self):
        doc = with_extras(miniflux())
        doc["spec"]["workloads"][0]["runtime"]["env"] = {"API_TOKEN": "x"}
        self.assertRefused(doc, "ressemble a un secret")

    def test_bad_schedule_refused(self):
        doc = with_extras(miniflux())
        doc["spec"]["jobs"][0]["schedule"] = "every day"
        self.assertRefused(doc, "schema")

    def test_job_with_port_refused(self):
        doc = with_extras(miniflux())
        doc["spec"]["jobs"][0]["runtime"]["port"] = 8080
        self.assertRefused(doc, "Additional properties")

    def test_job_without_database_refused(self):
        doc = with_extras(whoami())
        doc["spec"]["workloads"][0]["secrets"] = []
        self.assertRefused(doc, "sans spec.database")

    def test_missing_worker_cct_fails_render(self):
        self.sb.add(with_extras(miniflux()))
        shutil.rmtree(self.sb.platform / "ext")
        with self.assertRaises(appgen.AppError):
            self.sb.render()

    def test_quota_cap_refused(self):
        doc = with_extras(miniflux())
        for w in doc["spec"]["workloads"]:
            w["runtime"].update(size="medium", replicas=3)
        doc["spec"]["workloads"][1]["runtime"]["replicas"] = 3
        self.assertRefused(doc, "quota de cellule depasse")


class Volumes(Base):
    caps = RICH_CAPS

    def vols(self) -> dict:
        doc = with_extras(miniflux())
        return stateful(doc, [
            {"name": "data", "profile": "block-rwo", "mountPath": "/data", "size": "5Gi"},
            {"name": "media", "profile": "rwx-shared", "mountPath": "/media", "size": "100Gi", "readOnly": True},
            {"name": "cache", "profile": "block-rwo", "mountPath": "/cache", "size": "1Gi", "workload": "cache"},
        ])

    def test_multi_volumes_render(self):
        self.sb.add(self.vols())
        self.assertEqual(self.sb.errors(), [])
        files = self.sb.render()
        base = "namespaces/default/projects/miniflux"
        comp = files[f"{base}/components/miniflux/component.yaml"]["spec"]
        media = next(t for t in comp["traits"] if t["instanceName"] == "media")
        self.assertEqual(media["parameters"], {"mountPath": "/media", "accessMode": "ReadWriteMany", "readOnly": True})
        rb = files[f"{base}/components/miniflux/release-bindings/miniflux-production.yaml"]["spec"]
        self.assertEqual(rb["traitEnvironmentConfigs"]["media"]["storageClass"], "nfs-rwx")
        sts = files[f"{base}/components/miniflux-cache/component.yaml"]["spec"]
        self.assertEqual(sts["traits"][0]["name"], "persistent-volume-claim-sts")
        self.assertEqual(files[f"{base}/project.yaml"]["spec"]["parameters"]["quota"]["pvcs"], "3")

    def test_rwx_refused_on_k3d(self):
        self.sb = Sandbox(K3D_CAPS)
        self.addCleanup(self.sb.close)
        self.assertRefused(self.vols(), "non disponible sur le cluster 'k3d'")

    def test_rwo_with_replicas_refused(self):
        doc = self.vols()
        doc["spec"]["workloads"][1]["runtime"]["replicas"] = 2
        self.assertRefused(doc, "PVC RWO")

    def test_duplicate_volume_refused(self):
        doc = self.vols()
        doc["spec"]["storage"][1]["name"] = "data"
        self.assertRefused(doc, "nom de volume en double")

    def test_volume_on_job_refused(self):
        doc = self.vols()
        doc["spec"]["storage"][2]["workload"] = "cleanup"
        self.assertRefused(doc, "les jobs ne montent pas")


class Backup(Base):
    caps = RICH_CAPS

    def test_velero_valid(self):
        doc = stateful(whoami(), {"profile": "block-rwo", "mountPath": "/data", "size": "1Gi"})
        doc["spec"]["backup"] = {"class": "regenerable", "mechanism": "velero", "retention": "14d"}
        self.sb.add(doc)
        self.assertEqual(self.sb.errors(), [])
        cat = self.sb.render()["catalog/whoami/catalog-info.yaml"]
        self.assertEqual(cat["metadata"]["annotations"]["platform.smadja.dev/backup"], "velero/14d")

    def test_velero_without_storage_refused(self):
        doc = whoami()
        doc["spec"]["backup"] = {"class": "regenerable", "mechanism": "velero", "retention": "14d"}
        self.assertRefused(doc, "storage requis")

    def test_mechanism_without_retention_refused(self):
        doc = stateful(whoami(), {"profile": "block-rwo", "mountPath": "/data", "size": "1Gi"})
        doc["spec"]["backup"] = {"class": "regenerable", "mechanism": "velero"}
        self.assertRefused(doc, "retention")

    def test_cnpg_on_unbacked_instance_refused(self):
        doc = miniflux()
        doc["spec"]["backup"] = {"class": "regenerable", "mechanism": "cnpg", "retention": "30d"}
        self.assertRefused(doc, "instance sauvegardee")


class BackupK3d(Base):
    def test_velero_not_admitted_on_k3d(self):
        doc = stateful(whoami(), {"profile": "block-rwo", "mountPath": "/data", "size": "1Gi"})
        doc["spec"]["backup"] = {"class": "regenerable", "mechanism": "velero", "retention": "14d"}
        self.assertRefused(doc, "non admis sur le cluster 'k3d'")


# ----------------------------------------------------------------------------- E12


def exception(rule="run-as-root", expires="2026-12-31", **kw) -> dict:
    return {"rule": rule, "reason": "image upstream en uid 0, correctif demande en amont (issue #123)",
            "expires": expires, "approver": "user:default/paul", **kw}


class SecurityExceptions(Base):
    def test_writable_rootfs_renders_param(self):
        doc = whoami()
        doc["spec"]["securityExceptions"] = [exception("writable-rootfs")]
        self.sb.add(doc)
        self.assertEqual(self.sb.errors(), [])
        comp = self.sb.render()["namespaces/default/projects/whoami/components/whoami/component.yaml"]
        self.assertIs(comp["spec"]["parameters"]["readOnlyRootFilesystem"], False)

    def test_run_as_root_renders_exception_type_and_cell_psa(self):
        doc = whoami()
        doc["spec"]["securityExceptions"] = [exception()]
        self.sb.add(doc)
        self.assertEqual(self.sb.errors(), [])
        files = self.sb.render()
        comp = files["namespaces/default/projects/whoami/components/whoami/component.yaml"]["spec"]
        self.assertEqual(comp["componentType"]["name"], appgen.ROOT_EXCEPTION_CCT)
        self.assertNotIn("runAsUser", comp["parameters"])
        proj = files["namespaces/default/projects/whoami/project.yaml"]["spec"]["parameters"]
        self.assertEqual(proj["podSecurity"], "baseline")
        cat = files["catalog/whoami/catalog-info.yaml"]["metadata"]["annotations"]
        self.assertEqual(cat["platform.smadja.dev/security-exceptions"], "run-as-root@main:2026-12-31")

    def test_expired_refused(self):
        doc = whoami()
        doc["spec"]["securityExceptions"] = [exception(expires="2026-11-16")]
        self.assertRefused(doc, "expiree")

    def test_too_long_refused(self):
        doc = whoami()
        doc["spec"]["securityExceptions"] = [exception(expires="2027-06-01")]
        self.assertRefused(doc, "au-dela de 90 jours")

    def test_short_reason_refused(self):
        doc = whoami()
        doc["spec"]["securityExceptions"] = [exception(reason="parce que")]
        self.assertRefused(doc, "schema")

    def test_missing_expires_refused(self):
        doc = whoami()
        exc = exception()
        del exc["expires"]
        doc["spec"]["securityExceptions"] = [exc]
        self.assertRefused(doc, "expires")

    def test_unknown_workload_refused(self):
        doc = whoami()
        doc["spec"]["securityExceptions"] = [exception(workload="ghost")]
        self.assertRefused(doc, "workload inconnu")

    def test_run_as_root_with_run_as_user_refused(self):
        doc = whoami()
        doc["spec"]["runtime"]["runAsUser"] = 1000
        doc["spec"]["securityExceptions"] = [exception()]
        self.assertRefused(doc, "runAsUser incompatible")

    def test_run_as_root_without_platform_type_fails_render(self):
        doc = whoami()
        doc["spec"]["securityExceptions"] = [exception()]
        self.sb.add(doc)
        shutil.rmtree(self.sb.platform / "ext")
        with self.assertRaises(appgen.AppError):
            self.sb.render()


# ----------------------------------------------------------------------------- Helm


PODINFO_VALUES = appgen.load_yaml(ROOT / "apps" / "_examples" / "podinfo-helm" / "values.yaml")


class HelmPath(Base):
    def test_application_rendered(self):
        self.sb.add(podinfo(), PODINFO_VALUES)
        self.assertEqual(self.sb.errors(), [])
        files = self.sb.render()
        app = files["helm/podinfo/production/application.yaml"]
        self.assertNotIn("finalizers", app["metadata"], "suppression de l'Application = ressources conservees")
        spec = app["spec"]
        self.assertEqual(spec["sources"][0]["targetRevision"], "6.9.2")
        self.assertEqual(spec["sources"][0]["helm"]["valueFiles"], ["$values/apps/podinfo/values.yaml"])
        self.assertEqual(spec["sources"][1]["ref"], "values")
        self.assertIs(spec["syncPolicy"]["automated"]["prune"], False)
        self.assertEqual(spec["syncPolicy"]["managedNamespaceMetadata"]["labels"]["pod-security.kubernetes.io/enforce"],
                         "restricted")
        self.assertTrue(spec["destination"]["namespace"].startswith("lab-"))
        self.assertIn("helm/podinfo/production/resources/networkpolicy-default-deny.yaml", files)
        cat = files["catalog/podinfo/catalog-info.yaml"]["metadata"]["annotations"]
        self.assertEqual(cat["openchoreo.dev/managed"], "false")

    def test_chart_without_digest_refused(self):
        doc = podinfo()
        doc["spec"]["source"]["chart"] = {"repo": "https://stefanprodan.github.io/podinfo", "name": "podinfo",
                                          "version": "6.9.2"}
        self.assertRefused(doc, "digest", PODINFO_VALUES)

    def test_chart_version_range_refused(self):
        doc = podinfo()
        doc["spec"]["source"]["chart"]["version"] = "^6.9"
        self.assertRefused(doc, "schema", PODINFO_VALUES)

    def test_missing_values_refused(self):
        self.assertRefused(podinfo(), "sans values.yaml")

    def test_host_network_values_refused(self):
        self.assertRefused(podinfo(), "hostNetwork", {**PODINFO_VALUES, "hostNetwork": True})

    def test_load_balancer_values_refused(self):
        self.assertRefused(podinfo(), "Service LoadBalancer", {**PODINFO_VALUES, "service": {"type": "LoadBalancer"}})

    def test_public_helm_refused(self):
        doc = podinfo()
        doc["spec"]["exposure"] = {"mode": "public", "host": "podinfo.lab.smadja.dev", "auth": "cloudflare-access"}
        self.assertRefused(doc, "exposition publique non livree", PODINFO_VALUES)

    def test_runtime_in_helm_refused(self):
        doc = podinfo()
        doc["spec"]["jobs"] = [{"name": "x", "schedule": "* * * * *", "runtime": {"size": "small"}}]
        self.assertRefused(doc, "schema", PODINFO_VALUES)


# ----------------------------------------------------------------------------- kubeconform (optionnel)


@unittest.skipUnless(shutil.which("kubeconform") and os.environ.get("APPGEN_CRDS") and os.environ.get("APPGEN_EXT_SCHEMAS"),
                     "kubeconform, APPGEN_CRDS (config/crd/bases v1.3.3) et APPGEN_EXT_SCHEMAS requis")
class Kubeconform(unittest.TestCase):
    """Rendu complet des extensions (natif + aperçus + helm) valide par kubeconform -strict."""

    def test_extensions_render_is_schema_valid(self):
        sb = Sandbox(RICH_CAPS)
        self.addCleanup(sb.close)
        doc = Volumes.vols(self)
        doc["spec"]["network"] = {"egress": [{"fqdn": "api.minimax.io", "ports": [443]},
                                              {"cidr": "100.0.0.0/8", "ports": [443]}, {"app": "whoami"}],
                               "allowIdp": True}
        doc["spec"]["securityExceptions"] = [exception("writable-rootfs")]
        sb.add(doc)
        sb.add(whoami())
        pod = podinfo()
        pod["spec"]["network"] = {"egress": [{"fqdn": "api.github.com", "ports": [443]}]}
        pod["spec"]["secrets"] = [{"env": "TOKEN_X", "key": "PODINFO_TOKEN_X"}]
        sb.add(pod, PODINFO_VALUES)
        out = sb.root / "generated"
        appgen.write_tree(sb.render(), out)
        res = subprocess.run([str(ROOT / "tools" / "appgen" / "validate-crd.sh"), os.environ["APPGEN_CRDS"], str(out),
                              os.environ["APPGEN_EXT_SCHEMAS"]], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)


if __name__ == "__main__":
    unittest.main()
