"""Tests de caracterisation d'appgen (T-214) : messages et ordre exacts des fonctions gelees que l'oracle generated/
ne couvre pas (semantic_check, _native_errors, egress_errors, gateway_errors, validate_all_full, rendu helm, CLI).

Ecrits AVANT le decoupage en paquet, contre appgen.py monolithique : ils figent le comportement observable
(liste d'erreurs complete, dans l'ordre). Un ecart = changement de comportement, jamais une mise a jour silencieuse.
Lancer : python3 -m unittest discover -s tests/appgen
"""
from __future__ import annotations

import contextlib
import copy
import io
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "appgen"))
sys.path.insert(0, str(ROOT / "tests" / "appgen"))

import appgen  # noqa: E402
from test_extensions import RICH_CAPS, TODAY, Sandbox, podinfo, whoami  # noqa: E402

CLUSTERS = ROOT / "clusters"


def check(doc: dict, dirname: str | None = None, index: dict | None = None, gate: bool = True,
          clusters: Path = CLUSTERS, fqdn: bool = False) -> tuple[list[str], list[str]]:
    name = doc["metadata"]["name"]
    ctx = appgen.Context(clusters_dir=clusters, index=index if index is not None else {name: doc}, today=TODAY,
                         allow_unenforced_fqdn=fqdn)
    return appgen.semantic_check(doc, dirname or name, gate, ctx)


def k3d(doc: dict) -> dict:
    doc["spec"]["cluster"] = "k3d"
    return doc


class SemanticCheck(unittest.TestCase):
    """semantic_check : nom, environnements, secrets, helm public, gate OKE, politique absente."""

    def test_name_env_secrets(self):
        doc = k3d(whoami())
        doc["metadata"]["name"] = "Bad_Name"
        doc["spec"]["environments"] = ["production", "staging"]
        doc["spec"]["secrets"] = [{"key": "X_A", "env": "A"}, {"key": "X_A", "env": "A"}]
        doc["spec"]["runtime"]["env"] = {"A": "1", "MY_TOKEN": "x", "URL": "https://u:p@h/x"}
        self.assertEqual(check(doc, dirname="whoami"), ([
            "metadata.name 'Bad_Name' differe du repertoire 'whoami'",
            "nom 'Bad_Name' invalide",
            "environnement 'staging' inconnu",
            "secrets : cle en double",
            "secrets : variable d'environnement en double",
            "secret 'X_A' : prefixe 'BAD_NAME_' obligatoire",
            "secret 'X_A' : prefixe 'BAD_NAME_' obligatoire",
            "variable 'A' a la fois en env et en secret",
            "runtime.env 'MY_TOKEN' ressemble a un secret : utiliser secrets[] (ESO)",
            "runtime.env 'URL' : valeur de type secret detectee (interdit dans Git)",
        ], []))

    def test_delivery_gate_and_missing_cluster(self):
        doc = whoami()
        doc["spec"]["cluster"] = "oke"
        doc["spec"]["delivery"] = "helm"
        with tempfile.TemporaryDirectory() as tmp:
            errs, warns = check(doc, gate=False, clusters=Path(tmp))
        self.assertEqual(warns, [])
        self.assertEqual(errs[:2], [
            "spec.delivery 'helm' differe du calcul 'native' (APP-CONTRACT section 3)",
            "cluster oke refuse : gate OKE non franchi (Cilium, baseline #1620, refus IMDS, acces operateur)",
        ])
        self.assertTrue(errs[2].startswith("politique de cluster absente : "), errs)
        self.assertEqual(len(errs), 3)

    def test_oidc_backup_exposure_tokens(self):
        doc = k3d(whoami())
        doc["spec"]["secrets"] = [{"key": "WHOAMI_OIDC", "env": "OIDC_SECRET"}]
        doc["spec"]["identity"] = {"oidc": {"provider": "authentik", "issuer": "https://auth.example.org:8443/app",
                                            "clientId": "c", "clientSecretKey": "WHOAMI_OTHER",
                                            "allowedGroups": ["a"], "adminGroup": "b"}}
        doc["spec"]["runtime"]["env"] = {"OAUTH2_CLIENT_ID": "c", "OAUTH2_ADMIN_GROUP": "z", "MODE": "NodePort"}
        doc["spec"]["backup"] = {"class": "irreplaceable", "mechanism": "cnpg"}
        doc["spec"]["exposure"] = {"mode": "public", "auth": "none"}
        self.assertEqual(check(doc), ([
            "identity.oidc.provider 'authentik' non admis sur le cluster 'k3d' (admis : thunderid)",
            "identity.oidc.clientSecretKey 'WHOAMI_OTHER' absent de secrets[].key",
            "runtime.env OAUTH2_CLIENT_ID interdit : injecte depuis identity.oidc.clientId",
            "identity.oidc.adminGroup 'b' absent de allowedGroups",
            "runtime.env OAUTH2_ADMIN_GROUP differe de identity.oidc.adminGroup",
            "identity.oidc authentik : egress {fqdn: auth.example.org, ports: [443]} (ou public-internet) requis",
            "backup.class irreplaceable refuse : aucune restauration hors Oracle prouvee",
            "backup.mechanism 'cnpg' non admis sur le cluster 'k3d' (admis : none)",
            "backup.mechanism cnpg : database requise sur une instance sauvegardee (capabilities)",
            "exposition publique sans authentification interdite",
            "/spec/runtime/env/MODE : valeur interdite 'NodePort'",
        ], []))

    def test_helm_public_and_storage(self):
        doc = k3d(podinfo())
        doc["spec"]["exposure"] = {"mode": "public", "auth": "oidc", "host": "x.example.org"}
        doc["spec"]["storage"] = {"profile": "block-rwo", "mountPath": "/data", "size": "1Gi"}
        doc["spec"]["data"] = {"class": "rebuildable"}
        doc["spec"]["backup"] = {"class": "none", "mechanism": "velero"}
        self.assertEqual(check(doc)[0], [
            "backup.mechanism 'velero' non admis sur le cluster 'k3d' (admis : none)",
            "parcours helm : exposition publique non livree (HTTPRoute a rendre) : refus",
            "parcours helm : storage se declare dans values.yaml, pas dans app.yaml",
        ])

    def test_velero_without_storage(self):
        doc = k3d(whoami())
        doc["spec"]["backup"] = {"class": "none", "mechanism": "velero"}
        self.assertIn("backup.mechanism velero : storage requis", check(doc)[0])


class NativeErrors(unittest.TestCase):
    """_native_errors : workloads, volumes, base, exceptions, quota."""

    def test_workloads_volumes_db(self):
        doc = k3d(whoami())
        doc["spec"]["secrets"] = [{"key": "WHOAMI_A", "env": "A"}]
        doc["spec"]["workloads"] = [
            {"name": "main", "kind": "Deployment", "runtime": {"size": "small"}},
            {"name": "tcp", "kind": "Deployment", "secrets": ["B"], "database": True,
             "runtime": {"size": "small", "port": 5000, "protocol": "TCP", "healthPath": "/h", "env": {"PASSWORD": "x"}}},
        ]
        doc["spec"]["jobs"] = [{"name": "cron", "schedule": "* * * * *", "runtime": {"size": "small"}}]
        doc["spec"]["storage"] = [
            {"name": "d", "profile": "rwx-shared", "mountPath": "/d", "size": "1Gi"},
            {"name": "d", "profile": "block-rwo", "mountPath": "/e", "size": "1Gi", "workload": "cron"},
            {"name": "f", "profile": "block-rwo", "mountPath": "/f", "size": "1Gi", "workload": "tcp"},
        ]
        doc["spec"]["database"] = {"instance": "nope"}
        doc["spec"]["data"] = {"class": "rebuildable"}
        doc["spec"]["runtime"]["replicas"] = 2
        doc["spec"]["workloads"][1]["runtime"]["replicas"] = 3
        self.assertEqual(check(doc)[0], [
            "workloads/jobs : nom en double ou 'main' reserve",
            "workloads[tcp].env 'PASSWORD' ressemble a un secret : utiliser secrets[] (ESO)",
            "workloads[tcp].secrets 'B' absent de spec.secrets[].env",
            "workloads[tcp] : healthPath sans objet pour un endpoint TCP",
            "storage : nom de volume en double",
            "storage[d] profil 'rwx-shared' non disponible sur le cluster 'k3d'",
            "storage[d].workload 'cron' inconnu (les jobs ne montent pas de volume)",
            "PVC RWO : replicas <= 1 (storage present sur 'tcp')",
            "database.instance 'nope' non admis sur le cluster 'k3d' (admis : lab-pg)",
            "profil stateless avec database ou storage",
        ])

    def test_workload_database_without_spec(self):
        doc = k3d(whoami())
        doc["spec"]["jobs"] = [{"name": "cron", "schedule": "* * * * *", "database": True, "runtime": {"size": "small"}}]
        self.assertEqual(check(doc)[0], ["jobs[cron].database sans spec.database"])

    def test_security_exceptions(self):
        doc = k3d(whoami())
        doc["spec"]["jobs"] = [{"name": "cron", "schedule": "* * * * *", "runtime": {"size": "small"}}]
        doc["spec"]["runtime"]["runAsUser"] = 1000
        doc["spec"]["securityExceptions"] = [
            {"rule": "run-as-root", "expires": "2026-12-01", "reason": "r"},
            {"rule": "run-as-root", "expires": "2026-12-01", "reason": "r"},
            {"rule": "run-as-root", "workload": "cron", "expires": "pas-une-date", "reason": "r"},
            {"rule": "writable-rootfs", "workload": "ghost", "expires": "2026-01-01", "reason": "r"},
            {"rule": "writable-rootfs", "expires": "2027-12-01", "reason": "r"},
        ]
        self.assertEqual(check(doc)[0], [
            "securityExceptions[0] (run-as-root@main) : runAsUser incompatible avec run-as-root",
            "securityExceptions[1] (run-as-root@main) : en double",
            "securityExceptions[1] (run-as-root@main) : runAsUser incompatible avec run-as-root",
            "securityExceptions[2] (run-as-root@cron) : run-as-root seulement pour un Deployment avec endpoint",
            "securityExceptions[2] (run-as-root@cron) : date expires invalide",
            "securityExceptions[3] (writable-rootfs@ghost) : workload inconnu",
            "securityExceptions[3] (writable-rootfs@ghost) : exception expiree le 2026-01-01 (refus)",
            "securityExceptions[4] (writable-rootfs@main) : expires au-dela de 90 jours",
        ])

    def test_quota(self):
        doc = k3d(whoami())
        doc["spec"]["runtime"]["size"] = "medium"
        doc["spec"]["runtime"]["replicas"] = 5
        self.assertEqual(check(doc)[0], [
            "quota de cellule depasse ((1400, 1792)) : maximum (1000, 2048) (m CPU, Mi)"])


class EgressErrors(unittest.TestCase):
    """egress_errors : doublon, CIDR, FQDN sans Cilium, regles app."""

    def test_rules(self):
        other = k3d(whoami())
        other["metadata"]["name"] = "other"
        other["spec"]["environments"] = ["development"]
        remote = copy.deepcopy(other)
        remote["metadata"]["name"] = "remote"
        remote["spec"]["cluster"] = "oke"
        doc = k3d(whoami())
        doc["spec"]["environments"] = ["production"]
        doc["spec"]["network"]["egress"] = [
            {"cidr": "127.0.0.0/8", "ports": [80]},
            {"cidr": "127.0.0.0/8", "ports": [80]},
            {"fqdn": "198.51.100.7", "ports": [443]},
            {"fqdnPattern": "*.com", "ports": [443]},
            {"app": "whoami"},
            {"app": "ghost"},
            {"app": "remote"},
            {"app": "other", "workload": "w"},
        ]
        index = {"whoami": doc, "other": other, "remote": remote}
        self.assertEqual(check(doc, index=index), ([
            "egress cidr '127.0.0.0/8' interdit : plage non routable",
            "egress : regle en double {\"cidr\": \"127.0.0.0/8\", \"ports\": [80]}",
            "egress cidr '127.0.0.0/8' interdit : plage non routable",
            "egress fqdn '198.51.100.7' : adresse IP interdite (utiliser cidr)",
            "egress FQDN '198.51.100.7' sur le cluster 'k3d' sans Cilium : aucune CiliumNetworkPolicy n'y serait "
            "appliquee : refus",
            "egress fqdnPattern '*.com' trop large (au moins *.domaine.tld)",
            "egress FQDN '*.com' sur le cluster 'k3d' sans Cilium : aucune CiliumNetworkPolicy n'y serait "
            "appliquee : refus",
            "egress app : cible = l'app elle-meme (deja autorise dans la cellule)",
            "egress app 'ghost' : app inconnue dans le depot",
            "egress app 'remote' : cible non native ou sur un autre cluster",
            "egress app 'other/w' : workload inconnu ou sans port",
            "egress app 'other' : absente des environnements ['production']",
        ], []))

    def test_unenforced_fqdn_warns(self):
        doc = k3d(whoami())
        doc["spec"]["network"]["egress"] = [{"fqdn": "api.example.org", "ports": [443]}]
        self.assertEqual(check(doc, fqdn=True), ([], [
            "egress FQDN 'api.example.org' sur le cluster 'k3d' sans Cilium : aucune CiliumNetworkPolicy n'y serait "
            "appliquee (--allow-unenforced-fqdn : apercu marque enforced=false, flux refuses)"]))

    def test_helm_app_rule(self):
        doc = k3d(podinfo())
        doc["spec"]["network"]["egress"] = [{"app": "whoami"}]
        self.assertEqual(check(doc)[0], ["egress app : non supporte en parcours helm"])


class GatewayErrors(unittest.TestCase):
    def test_environment_absent_and_no_ingress(self):
        files = {
            "a/workload.yaml": {"kind": "Workload", "spec": {"owner": {"componentName": "c"},
                                                            "endpoints": {"http": {"visibility": ["external"]}}}},
            "a/rb-dev.yaml": {"kind": "ReleaseBinding", "spec": {"owner": {"componentName": "c"},
                                                                 "environment": "development"}},
            "a/rb-prod.yaml": {"kind": "ReleaseBinding", "spec": {"owner": {"componentName": "c"},
                                                                  "environment": "production"}},
            "b/other.yaml": "texte",
        }
        platform = {("Environment", "production"): {"spec": {"gateway": {"ingress": {"internal": {}}}}}}
        self.assertEqual(appgen.gateway_errors(files, platform), [
            "a/workload.yaml : Environment 'development' absent de platform/",
            "a/workload.yaml : endpoint external mais Environment 'production' sans gateway.ingress.external "
            "(RenderingFailed garanti, G1)",
        ])
        self.assertEqual(appgen.gateway_errors(files, {}), [])


class ValidateAllFull(unittest.TestCase):
    def test_yaml_invalid_and_duplicate_host_and_helm_values(self):
        sb = Sandbox(RICH_CAPS)
        self.addCleanup(sb.close)
        a = whoami()
        a["spec"]["exposure"] = {"mode": "public", "auth": "cloudflare-access", "host": "x.example.org"}
        sb.add(a)
        b = copy.deepcopy(a)
        b["metadata"]["name"] = "whoami2"
        sb.add(b)
        sb.add(k3d(podinfo()), {"hostNetwork": True, "x": {"hostPath": "/"}, "svc": {"type": "NodePort"},
                                "sc": {"runAsUser": 0}, "l": ["-----BEGIN KEY"]})
        nov = k3d(podinfo())
        nov["metadata"]["name"] = "novalues"
        sb.add(nov)
        (sb.root / "apps" / "broken").mkdir()
        (sb.root / "apps" / "broken" / "app.yaml").write_text("a: [\n", encoding="utf-8")
        count, errors, warnings = appgen.validate_all_full(sb.root, examples=False, today=TODAY)
        self.assertEqual((count, warnings), (4, []))
        self.assertEqual(errors, [
            "apps/broken/app.yaml: YAML invalide (ParserError)",
            "apps/novalues/app.yaml: parcours helm sans values.yaml",
            "apps/podinfo/app.yaml: values.yaml .hostNetwork: true interdit",
            "apps/podinfo/app.yaml: values.yaml .x.hostPath: hostPath interdit",
            "apps/podinfo/app.yaml: values.yaml .svc.type: Service NodePort interdit (ClusterIP seulement)",
            "apps/podinfo/app.yaml: values.yaml .sc.runAsUser: runAsUser 0 interdit (securityExceptions non "
            "applicable en helm)",
            "apps/podinfo/app.yaml: values.yaml .l[0]: valeur de type secret detectee (interdit dans Git)",
            "apps/whoami2/app.yaml: hote 'x.example.org' deja utilise par whoami",
        ])
        with self.assertRaises(appgen.AppError):
            sb.render()


class HelmRender(unittest.TestCase):
    def test_public_internet_rules_and_secrets(self):
        doc = k3d(podinfo())
        doc["spec"]["network"]["egress"] = [{"cidr": "100.0.0.0/8", "ports": [443]}]
        doc["spec"]["secrets"] = [{"key": "PODINFO_A", "env": "A", "property": "p"}]
        files = appgen.render_helm(doc, copy.deepcopy(RICH_CAPS["spec"]))
        kinds = sorted(k for k in files if "/development/" in k or "/production/" in k)
        self.assertTrue(any(k.endswith("/networkpolicy-egress-allowlist.yaml") for k in kinds), kinds)
        es = next(v for k, v in files.items() if k.endswith("/externalsecret-podinfo-secrets.yaml"))
        self.assertEqual(es["spec"]["data"], [{"secretKey": "A", "remoteRef": {"key": "PODINFO_A", "property": "p"}}])
        doc["spec"]["network"]["egress"] = "public-internet"
        files = appgen.render_helm(doc, copy.deepcopy(RICH_CAPS["spec"]))
        pub = next(v for k, v in files.items() if k.endswith("/networkpolicy-egress-public-internet.yaml"))
        self.assertEqual(pub["spec"]["egress"][0]["to"][0]["ipBlock"]["except"],
                         ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10", "169.254.0.0/16"])


class Capabilities(unittest.TestCase):
    def test_invalid_and_wrong_name(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp) / "x"
            d.mkdir()
            (d / "capabilities.yaml").write_text(yaml.safe_dump({"metadata": {"name": "x"}}), encoding="utf-8")
            with self.assertRaisesRegex(appgen.AppError, "invalide : "):
                appgen.load_capabilities(Path(tmp), "x")
            caps = yaml.safe_load((CLUSTERS / "k3d" / "capabilities.yaml").read_text(encoding="utf-8"))
            (d / "capabilities.yaml").write_text(yaml.safe_dump(caps), encoding="utf-8")
            with self.assertRaisesRegex(appgen.AppError, "metadata.name 'k3d' differe de 'x'"):
                appgen.load_capabilities(Path(tmp), "x")


def run_cli(*argv: str) -> tuple[int, str, str]:
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        rc = appgen.main(list(argv))
    return rc, out.getvalue(), err.getvalue()


class Cli(unittest.TestCase):
    """CLI en processus, sur le depot reel : validate, check, render (sortie identique a generated/)."""

    def test_validate(self):
        rc, out, _ = run_cli("validate")
        self.assertEqual(rc, 0)
        self.assertRegex(out, r"^appgen validate : OK \(\d+ app\(s\)\)\n$")

    def test_check_and_render_identical(self):
        rc, out, err = run_cli("check")
        self.assertEqual(rc, 0, err)
        self.assertRegex(out, r"^appgen check : OK, aucune derive \(\d+ fichier\(s\)\)\n$")
        with tempfile.TemporaryDirectory() as tmp:
            out_dir = Path(tmp) / "generated"
            rc, out, _ = run_cli("render", "--out", str(out_dir))
            self.assertEqual(rc, 0)
            self.assertEqual(appgen.diff_trees(out_dir, ROOT / "generated"), [])

    def test_render_refused_platform(self):
        with tempfile.TemporaryDirectory() as tmp:
            rc, _, err = run_cli("--platform-dir", str(Path(tmp) / "absent"), "render", "--out", str(Path(tmp) / "o"))
            self.assertEqual(rc, 1)
            self.assertIn("appgen render : ECHEC\ndossier plateforme absent", err)
            rc, _, err = run_cli("--platform-dir", str(Path(tmp) / "absent"), "check")
            self.assertEqual(rc, 1)
            self.assertIn("appgen check : ECHEC\ndossier plateforme absent", err)

    def test_pin_resource_rejects_bad_release(self):
        rc, _, err = run_cli("pin-resource", "miniflux", "production", "nope")
        self.assertEqual(rc, 1)
        self.assertIn("ne ressemble pas a une ResourceRelease de miniflux-db", err)

    def test_pin_project_rejects_bad_release(self):
        rc, _, err = run_cli("pin-project", "whoami", "production", "whoami-xyz")
        self.assertEqual(rc, 1)
        self.assertIn("(whoami-<10 hex>)", err)


if __name__ == "__main__":
    unittest.main()
