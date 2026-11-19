"""Contrôle statique d'Argo CD Notifications (T-489) : sans cluster, sans réseau, sans secret.

Vérifie platform/install/argocd/notifications/, la clé `notifications` de platform/install/values/argocd.yaml et la
condition du ClusterSecretStore lab-store. Chaque refus est prouvé sur une copie mutée (cas négatifs). Les valeurs
« secrètes » des cas négatifs sont factices et assemblées à l'exécution.
Usage : python3 -I -m unittest discover -s tests/argo-notifications -p 'test_*.py'
"""

import copy
import re
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
NOTIF = ROOT / "platform" / "install" / "argocd" / "notifications"
VALUES = ROOT / "platform" / "install" / "values" / "argocd.yaml"
STORE = ROOT / "platform" / "install" / "manifests" / "20-eso-lab-store.yaml"

KEYS = ("OPENCHOREO_STATUS_APP_ID", "OPENCHOREO_STATUS_INSTALLATION_ID", "OPENCHOREO_STATUS_PRIVATE_KEY")
CONCLUSIONS = {"lab-check-success": "success", "lab-check-failure": "failure", "lab-check-neutral": "neutral"}
TRIGGERS = {"on-lab-success": "lab-check-success", "on-lab-failure": "lab-check-failure",
            "on-lab-neutral": "lab-check-neutral"}
# Champs à texte libre ou à adresse : interdits dans un gabarit publié sur GitHub.
FORBIDDEN_TEMPLATE = ("health.message", "operationState.message", "argocdUrl", ".status.resources",
                      "conditions", "destination.server", "summary.externalURLs", "summary.images")
SECRET_PATTERNS = (
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}"),
    re.compile(r"\bdp\.(st|sa|ct|pt)\.[A-Za-z0-9]{20,}"),
    re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"),
)


def load_all(path):
    return [d for d in yaml.safe_load_all(path.read_text(encoding="utf-8")) if isinstance(d, dict)]


def notif_objects():
    out = {}
    for f in sorted(NOTIF.glob("*.yaml")):
        for d in load_all(f):
            out[(d["kind"], d["metadata"]["name"])] = d
    return out


def check_template(tname, concl, raw):
    """Écarts d'un gabarit de check run."""
    if raw is None:
        return [f"gabarit {tname} absent"]
    errs = [f"gabarit {tname} : champ interdit {bad}" for bad in FORBIDDEN_TEMPLATE if bad in raw]
    gh = (yaml.safe_load(raw) or {}).get("github") or {}
    cr = gh.get("checkRun") or {}
    out = cr.get("output") or {}
    rules = (
        (cr.get("status") == "completed" and cr.get("conclusion") == concl,
         f"status completed et conclusion {concl} attendus"),
        (".app.metadata.name" in str(cr.get("name", "")), "nom de check run sans le nom de l'app"),
        (gh.get("revisionPath") == "{{.app.status.sync.revision}}", "revisionPath doit être la révision de synchro"),
        (gh.get("repoURLPath") == "{{.app.spec.source.repoURL}}", "repoURLPath doit être le dépôt source"),
        (bool(out.get("title")) and bool(out.get("summary")), "titre et résumé requis"),
    )
    errs += [f"gabarit {tname} : {msg}" for ok, msg in rules if not ok]
    errs += [f"gabarit {tname} : seul checkRun est admis (trouvé {k})"
             for k in ("status", "deployment", "pullRequestComment", "repositoryDispatch") if k in gh]
    return errs


def check_trigger(trig, tpl, raw):
    """Écarts d'un trigger : garde de nom, oncePer par révision, un seul gabarit."""
    conds = yaml.safe_load(raw or "") or []
    if not conds:
        return [f"trigger {trig} absent"]
    errs = []
    for c in conds:
        when = c.get("when", "")
        if "startsWith 'lab-o-'" not in when or "startsWith 'lab-k-'" not in when:
            errs.append(f"trigger {trig} : garde de nom lab-o-/lab-k- absente")
        if c.get("oncePer") != "app.status.sync.revision":
            errs.append(f"trigger {trig} : oncePer doit être app.status.sync.revision")
        if c.get("send") != [tpl]:
            errs.append(f"trigger {trig} : doit envoyer {tpl} seulement")
    return errs


def check_cm(cm):
    """Écarts du ConfigMap argocd-notifications-cm (liste vide = conforme)."""
    errs = []
    data = cm.get("data") or {}
    if cm["metadata"].get("namespace") != "lab-argocd":
        errs.append("namespace du ConfigMap différent de lab-argocd")
    svc = yaml.safe_load(data.get("service.github", "")) or {}
    want = {"appID": "$" + KEYS[0], "installationID": "$" + KEYS[1], "privateKey": "$" + KEYS[2]}
    if svc != want:
        errs.append(f"service.github doit référencer exactement les trois clés du Secret : {svc!r}")
    for tname, concl in CONCLUSIONS.items():
        errs += check_template(tname, concl, data.get(f"template.{tname}"))
    for trig, tpl in TRIGGERS.items():
        errs += check_trigger(trig, tpl, data.get(f"trigger.{trig}"))
    subs = yaml.safe_load(data.get("subscriptions", "")) or []
    if subs != [{"recipients": ["github"], "triggers": list(TRIGGERS)}]:
        errs.append(f"subscriptions : un abonnement par défaut github sur les trois triggers attendu : {subs!r}")
    return errs


def check_es(es):
    errs = []
    spec = es.get("spec") or {}
    if es["metadata"].get("namespace") != "lab-argocd":
        errs.append("ExternalSecret hors de lab-argocd")
    if spec.get("secretStoreRef") != {"kind": "ClusterSecretStore", "name": "lab-store"}:
        errs.append("ExternalSecret : seul le ClusterSecretStore lab-store est admis")
    if (spec.get("target") or {}).get("name") != "argocd-notifications-secret":
        errs.append("ExternalSecret : cible argocd-notifications-secret attendue")
    got = [(d.get("secretKey"), (d.get("remoteRef") or {}).get("property")) for d in spec.get("data") or []]
    if got != [(k, k) for k in KEYS] or spec.get("dataFrom"):
        errs.append(f"ExternalSecret : exactement les trois clés {KEYS} attendues : {got!r}")
    return errs


def check_values(values):
    n = values.get("notifications") or {}
    errs = []
    if n.get("enabled") is not True:
        errs.append("notifications.enabled doit valoir true")
    if (n.get("cm") or {}).get("create") is not False or (n.get("secret") or {}).get("create") is not False:
        errs.append("notifications.cm.create et notifications.secret.create doivent valoir false")
    for k in ("notifiers", "templates", "triggers", "subscriptions", "secret.items", "context"):
        if k in n:
            errs.append(f"notifications.{k} : la configuration vit sous platform/install/argocd/notifications/")
    if not ((n.get("resources") or {}).get("requests")):
        errs.append("notifications.resources.requests requis (quota lab-argocd)")
    return errs


def scan_secrets(text):
    return [p.pattern for p in SECRET_PATTERNS if p.search(text)]


class Positive(unittest.TestCase):
    def setUp(self):
        self.objs = notif_objects()

    def test_inventory(self):
        self.assertEqual(sorted(self.objs), [("CiliumNetworkPolicy", "lab-allow-github-api-notifications"),
                                             ("ConfigMap", "argocd-notifications-cm"),
                                             ("ExternalSecret", "argocd-notifications-secret")])
        for (kind, name), d in self.objs.items():
            self.assertEqual(d["metadata"].get("namespace"), "lab-argocd", f"{kind}/{name}")

    def test_cm(self):
        self.assertEqual(check_cm(self.objs[("ConfigMap", "argocd-notifications-cm")]), [])

    def test_external_secret(self):
        self.assertEqual(check_es(self.objs[("ExternalSecret", "argocd-notifications-secret")]), [])

    def test_values(self):
        self.assertEqual(check_values(yaml.safe_load(VALUES.read_text(encoding="utf-8"))), [])

    def test_no_secret_in_clear(self):
        for f in [*sorted(NOTIF.glob("*.yaml")), VALUES]:
            self.assertEqual(scan_secrets(f.read_text(encoding="utf-8")), [], str(f))
        kinds = {k for k, _ in self.objs}
        self.assertNotIn("Secret", kinds)

    def test_egress_only_api_github(self):
        cnp = self.objs[("CiliumNetworkPolicy", "lab-allow-github-api-notifications")]["spec"]
        self.assertEqual(cnp["endpointSelector"], {"matchLabels": {"app.kubernetes.io/name":
                                                                   "argocd-notifications-controller"}})
        fqdns = [f for r in cnp["egress"] for f in r.get("toFQDNs", [])]
        self.assertEqual(fqdns, [{"matchName": "api.github.com"}])
        self.assertNotIn("toCIDR", str(cnp))
        self.assertNotIn("toEntities", str(cnp))

    def test_store_admits_lab_argocd_only_by_exact_name(self):
        store = next(d for d in load_all(STORE) if d["kind"] == "ClusterSecretStore")
        regexes = [r for c in store["spec"]["conditions"] for r in c.get("namespaceRegexes", [])]
        self.assertIn("^lab-argocd$", regexes)
        self.assertFalse([r for r in regexes if r in ("^lab-", ".*", "^lab-.*")], regexes)


class Negative(unittest.TestCase):
    """Chaque mutation doit être refusée : prouve que les contrôles mordent."""

    def setUp(self):
        objs = notif_objects()
        self.cm = objs[("ConfigMap", "argocd-notifications-cm")]
        self.es = objs[("ExternalSecret", "argocd-notifications-secret")]

    def mut_cm(self, key, fn):
        cm = copy.deepcopy(self.cm)
        cm["data"][key] = fn(cm["data"][key])
        return check_cm(cm)

    def test_literal_private_key_refused(self):
        pem = "-----BEGIN " + "RSA PRIVATE KEY-----\\nZmFrZQ==\\n-----END " + "RSA PRIVATE KEY-----"
        self.assertTrue(self.mut_cm("service.github", lambda s: s.replace("$" + KEYS[2], f'"{pem}"')))
        self.assertTrue(scan_secrets(pem.replace("\\n", "\n")))

    def test_literal_app_id_refused(self):
        self.assertTrue(self.mut_cm("service.github", lambda s: s.replace("$" + KEYS[0], "1" + "23456")))

    def test_free_text_in_template_refused(self):
        self.assertTrue(self.mut_cm("template.lab-check-failure",
                                    lambda s: s.replace("Diagnostic : skill diagnose-app.", "{{.app.status.health.message}}")))

    def test_wrong_conclusion_refused(self):
        self.assertTrue(self.mut_cm("template.lab-check-neutral",
                                    lambda s: s.replace("conclusion: neutral", "conclusion: success", 1)))

    def test_commit_status_refused(self):
        self.assertTrue(self.mut_cm("template.lab-check-success",
                                    lambda s: s.replace("  checkRun:", "  status: {state: success}\n  checkRun:")))

    def test_trigger_without_name_guard_refused(self):
        self.assertTrue(self.mut_cm("trigger.on-lab-success", lambda s: s.replace("startsWith 'lab-k-'", "!= ''")))

    def test_trigger_without_once_per_refused(self):
        self.assertTrue(self.mut_cm("trigger.on-lab-neutral",
                                    lambda s: s.replace("oncePer: app.status.sync.revision\n", "")))

    def test_subscription_widened_refused(self):
        self.assertTrue(self.mut_cm("subscriptions", lambda s: s.replace("[github]", "[github, slack:x]")))

    def test_other_store_refused(self):
        es = copy.deepcopy(self.es)
        es["spec"]["secretStoreRef"]["name"] = "doppler-cluster"
        self.assertTrue(check_es(es))

    def test_extra_key_refused(self):
        es = copy.deepcopy(self.es)
        es["spec"]["dataFrom"] = [{"extract": {"key": "openchoreo-status"}}]
        self.assertTrue(check_es(es))

    def test_values_chart_cm_refused(self):
        v = yaml.safe_load(VALUES.read_text(encoding="utf-8"))
        v["notifications"]["cm"]["create"] = True
        self.assertTrue(check_values(v))
        v = yaml.safe_load(VALUES.read_text(encoding="utf-8"))
        v["notifications"]["enabled"] = False
        self.assertTrue(check_values(v))

    def test_ip_and_token_detected(self):
        self.assertTrue(scan_secrets("summary: " + "10.0." + "20.60"))
        self.assertTrue(scan_secrets("ghs" + "_" + "A" * 36))


if __name__ == "__main__":
    unittest.main()
