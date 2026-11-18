"""Un test unitaire par règle nommée d'argo_guard.py et psa_check.py (T-423) : un cas conforme, un cas refusé.

Complète test_characterization.py (comportement global gelé) et run.sh (cas négatifs sur l'arbre réel).
Lancer : python3 -m unittest discover -s tests/argo-guard
"""
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import corpus

G, PSA = corpus.GUARD, corpus.PSA
REL = "f.yaml"


def guard():
    g = G.Guard(corpus.ROOT)
    return g


def errs_of(fn, *args):
    g = guard()
    getattr(g, fn)(REL, *args)
    return g.errs


class ProjectRules(unittest.TestCase):
    def test_p1_default_locked(self):
        g = guard()
        g.rule_p1_default_locked({"clusterResourceBlacklist": [{"group": "*", "kind": "*"}],
                                  "namespaceResourceBlacklist": [{"group": "*", "kind": "*"}]})
        g.rule_p1_default_locked(None)
        self.assertEqual(g.errs, [])
        g.rule_p1_default_locked({"sourceRepos": ["x"]})
        self.assertEqual(len(g.errs), 1)
        self.assertIn("P1 projet default non verrouillé", g.errs[0])

    def test_p2_source_repos(self):
        self.assertEqual(errs_of("rule_p2_source_repos", "lab-x", {"sourceRepos": ["https://a/b"]}), [])
        self.assertIn("sourceRepos 'https://a/*' joker",
                      errs_of("rule_p2_source_repos", "lab-x", {"sourceRepos": ["https://a/*"]})[0])

    def test_p2_destinations(self):
        self.assertEqual(errs_of("rule_p2_destinations", "lab-x", {"destinations": [{"namespace": "default"}]}), [])
        for key in ("server", "namespace", "name"):
            self.assertIn("destination joker", errs_of("rule_p2_destinations", "lab-x",
                                                       {"destinations": [{key: "*"}]})[0])

    def test_p2_whitelist_entry(self):
        ok = {"group": "g", "kind": "K", "name": "n"}
        self.assertEqual(errs_of("rule_p2_whitelist_entry", "lab-x", "clusterResourceWhitelist", ok), [])
        for bad in ({**ok, "group": "*"}, {**ok, "kind": "*"}, {**ok, "name": "*"}):
            self.assertIn("joker", errs_of("rule_p2_whitelist_entry", "lab-x", "clusterResourceWhitelist", bad)[0])
        self.assertIn("sans nom", errs_of("rule_p2_whitelist_entry", "lab-x", "clusterResourceWhitelist",
                                          {"group": "g", "kind": "K"})[0])
        self.assertEqual(errs_of("rule_p2_whitelist_entry", "lab-x", "namespaceResourceWhitelist",
                                 {"group": "g", "kind": "K"}), [])
        app = {"group": "argoproj.io", "kind": "Application", "name": "n"}
        self.assertIn("réservé à lab-root", errs_of("rule_p2_whitelist_entry", "lab-x",
                                                    "namespaceResourceWhitelist", app)[0])
        self.assertEqual(errs_of("rule_p2_whitelist_entry", "lab-root", "namespaceResourceWhitelist", app), [])

    def test_p2_no_wildcards(self):
        g = guard()
        g.rule_p2_no_wildcards(REL, "lab-x", {"sourceNamespaces": ["a"], "sourceRepos": ["*"],
                                              "destinations": [{"server": "*"}],
                                              "namespaceResourceWhitelist": [{"group": "*", "kind": "K"}]})
        self.assertEqual(len(g.errs), 4)
        g = guard()
        g.rule_p2_no_wildcards(REL, "lab-x", {})
        self.assertEqual(g.errs, [])

    def test_p2_lab_root(self):
        ok = {"namespaceResourceWhitelist": [{"group": "argoproj.io", "kind": "Application"}],
              "destinations": [{"namespace": "lab-argocd"}]}
        self.assertEqual(errs_of("rule_p2_lab_root", ok), [])
        self.assertEqual(errs_of("rule_p2_lab_root", None), [])
        self.assertIn("seul kind Application", errs_of("rule_p2_lab_root", {**ok, "destinations": []})[0])
        self.assertEqual(len(errs_of("rule_p2_lab_root", {**ok, "clusterResourceWhitelist": [{}]})), 1)

    def test_p2_lab_authz(self):
        ok = {"clusterResourceWhitelist": [{"kind": "AuthzRole", "name": "lab-r"}],
              "namespaceResourceBlacklist": [{"group": "*", "kind": "*"}]}
        self.assertEqual(errs_of("rule_p2_lab_authz", ok), [])
        self.assertEqual(errs_of("rule_p2_lab_authz", None), [])
        bad = {**ok, "clusterResourceWhitelist": [{"kind": "AuthzRole", "name": "r"}, {"kind": "Secret", "name": "lab-r"}]}
        self.assertEqual(len(errs_of("rule_p2_lab_authz", bad)), 2)
        self.assertIn("aucun kind namespacé", errs_of("rule_p2_lab_authz", {**ok, "namespaceResourceBlacklist": []})[0])
        self.assertIn("aucun kind namespacé", errs_of("rule_p2_lab_authz", {
            **ok, "namespaceResourceWhitelist": [{"group": "g", "kind": "K"}]})[0])

    def test_p3_deny_window(self):
        deny = dict(G.DENY_WINDOW)
        self.assertEqual(errs_of("rule_p3_deny_window", "lab-x", {"syncWindows": [deny]}), [])
        self.assertIn("P3 lab-x", errs_of("rule_p3_deny_window", "lab-x", {})[0])
        self.assertEqual(len(errs_of("rule_p3_deny_window", "lab-x", {"syncWindows": [deny, {"kind": "allow"}]})), 1)
        self.assertEqual(len(errs_of("rule_p3_deny_window", "lab-x", {"syncWindows": [dict(deny, duration="1h")]})), 1)

    def test_p2_lab_apps(self):
        ok = {"clusterResourceWhitelist": [],
              "namespaceResourceWhitelist": [{"group": "openchoreo.dev", "kind": "Component"}],
              "destinations": [{"server": "https://kubernetes.default.svc", "namespace": "default"}]}
        self.assertEqual(errs_of("rule_p2_lab_apps", ok), [])
        self.assertEqual(errs_of("rule_p2_lab_apps", None), [])
        bad = {"clusterResourceWhitelist": [{"kind": "Namespace"}],
               "namespaceResourceWhitelist": [{"group": "g", "kind": "Secret"}],
               "destinations": [{"server": "x", "namespace": "y"}]}
        self.assertEqual(len(errs_of("rule_p2_lab_apps", bad)), 3)
        self.assertIn("POSÉE vide", errs_of("rule_p2_lab_apps", {k: v for k, v in ok.items()
                                                                if k != "clusterResourceWhitelist"})[0])


class ApplicationRules(unittest.TestCase):
    def test_a1_location(self):
        g = guard()
        g.rule_a1_location(f"{G.ARGO}/apps/x.yaml", "x", "lab-platform", {})
        self.assertEqual(g.errs, [])
        g.rule_a1_location("platform/x.yaml", "x", "lab-platform", {})
        self.assertIn("A1 Application 'x' hors", g.errs[0])
        g = guard()
        g.rule_a1_location(G.ROOT_APP, "lab-root", "lab-root", {"source": {"path": f"{G.ARGO}/apps"}})
        self.assertEqual(g.errs, [])
        g.rule_a1_location(G.ROOT_APP, "lab-root", "lab-root",
                           {"source": {"path": f"{G.ARGO}/apps", "directory": {"recurse": True}}})
        self.assertIn("A1 l'Application racine", g.errs[0])

    def test_a2_project(self):
        g = guard()
        g.rule_a2_project(f"{G.ARGO}/apps/x.yaml", "x", "lab-apps")
        self.assertEqual(g.errs, [])
        g.rule_a2_project(f"{G.ARGO}/apps/x.yaml", "x", "default")
        self.assertEqual(len(g.errs), 2)
        g = guard()
        g.rule_a2_project("platform/x.yaml", "x", "lab-root")
        self.assertIn("réservé à", g.errs[0])
        g = guard()
        g.rule_a2_project(G.ROOT_APP, "lab-root", "lab-root")
        self.assertEqual(g.errs, [])

    def test_a3_sources(self):
        g = guard()
        g.rule_a3_sources(REL, "x", "lab-platform", {"sources": []})
        self.assertIn("sources multiples interdites", g.errs[0])
        g = guard()
        g.rule_a3_sources(REL, "lab-platform", "lab-platform", {})
        self.assertEqual(g.errs, [])
        g.rule_a3_sources(REL, "lab-apps", "lab-apps", {})  # délègue à check_lab_apps_sources
        self.assertIn("sources[] absent ou vide", g.errs[0])

    def test_a3_source_kinds(self):
        for k in ("chart", "helm", "kustomize", "plugin"):
            self.assertIn(f"source.{k} interdit", errs_of("rule_a3_source_kinds", "x", {k: {}})[0])
        self.assertEqual(errs_of("rule_a3_source_kinds", "x", {"path": "platform"}), [])

    def test_a2_authz_reserved(self):
        ok = {"path": "platform/authz"}
        self.assertEqual(errs_of("rule_a2_authz_reserved", "lab-authz", "lab-authz", ok), [])
        self.assertEqual(errs_of("rule_a2_authz_reserved", "x", "lab-platform", {}), [])
        self.assertEqual(len(errs_of("rule_a2_authz_reserved", "x", "lab-authz", ok)), 1)
        self.assertEqual(len(errs_of("rule_a2_authz_reserved", "lab-authz", "lab-authz", {"path": "platform"})), 1)
        self.assertEqual(len(errs_of("rule_a2_authz_reserved", "lab-authz", "lab-authz",
                                     {**ok, "directory": {"recurse": True}})), 1)

    def test_a4_manual_sync(self):
        auto = {"syncPolicy": {"automated": {}}}
        self.assertEqual(errs_of("rule_a4_manual_sync", "x", "lab-apps", auto), [])
        self.assertEqual(errs_of("rule_a4_manual_sync", "x", "lab-platform", {"syncPolicy": {}}), [])
        for proj in ("lab-platform", "lab-authz"):
            self.assertIn("A4", errs_of("rule_a4_manual_sync", "x", proj, auto)[0])

    def test_a3_platform_path(self):
        for path in ("platform", "platform/policies", "platform/data"):
            self.assertEqual(errs_of("rule_a3_platform_path", "x", "lab-platform", {"path": path}), [], path)
        for path in ("generated/x", "platformx", "platform/../x", G.ARGO, "platform/authz", ""):
            self.assertEqual(len(errs_of("rule_a3_platform_path", "x", "lab-platform", {"path": path})), 1, path)
        self.assertEqual(errs_of("rule_a3_platform_path", "x", "lab-apps", {"path": "generated"}), [])

    def test_lab_apps_source_origin(self):
        ok = corpus.lab_src("w")
        self.assertEqual(errs_of("rule_lab_apps_source_origin", 0, ok), [])
        self.assertIn("sources[0].helm interdit", errs_of("rule_lab_apps_source_origin", 0, dict(ok, helm={}))[0])
        self.assertIn("hors dépôt", errs_of("rule_lab_apps_source_origin", 0, dict(ok, repoURL="x"))[0])
        self.assertIn("doit être main", errs_of("rule_lab_apps_source_origin", 0, dict(ok, targetRevision="dev"))[0])

    def test_lab_apps_source_path(self):
        pre = G.APPS_PATH + "/projects/"
        g, seen = guard(), set()
        g.rule_lab_apps_source_path(REL, 0, pre + "w", {"w"}, seen)
        self.assertEqual(g.errs, [])
        g.rule_lab_apps_source_path(REL, 1, pre + "w", {"w"}, seen)
        self.assertIn("en double", g.errs[0])
        for bad in ("", pre, pre + "w/x", pre + "..", "platform"):
            g = guard()
            g.rule_lab_apps_source_path(REL, 0, bad, {"w"}, set())
            self.assertIn("seul", g.errs[0], bad)
        g = guard()
        g.rule_lab_apps_source_path(REL, 0, pre + "z", {"w"}, set())
        self.assertIn("non OKE stateless", g.errs[0])

    def test_lab_apps_source_directory(self):
        self.assertEqual(errs_of("rule_lab_apps_source_directory", 0, {"recurse": True, "include": "*.yaml"}), [])
        self.assertEqual(len(errs_of("rule_lab_apps_source_directory", 0, {})), 2)
        self.assertIn("recurse", errs_of("rule_lab_apps_source_directory", 0, {"recurse": "true", "include": "*.yaml"})[0])
        self.assertIn("include", errs_of("rule_lab_apps_source_directory", 0, {"recurse": True, "include": "*"})[0])


class SyncedRules(unittest.TestCase):
    def test_s1_whitelist(self):
        lab = {"clusterResourceWhitelist": [{"group": "", "kind": "Namespace", "name": "lab-*"}],
               "namespaceResourceWhitelist": [{"group": "", "kind": "ConfigMap"}],
               "namespaceResourceBlacklist": [{"group": "", "kind": "Secret"}]}
        g = guard()
        g.rule_s1_whitelist(REL, "lab-x", lab, "", "Namespace", "lab-a")
        g.rule_s1_whitelist(REL, "lab-x", lab, "", "ConfigMap", "c")
        self.assertEqual(g.errs, [])
        g.rule_s1_whitelist(REL, "lab-x", lab, "", "Namespace", "autre")
        self.assertIn("cluster-scoped absent", g.errs[-1])
        g.rule_s1_whitelist(REL, "lab-x", lab, "", "Secret", "s")
        self.assertIn("namespacé non autorisé", g.errs[-1])
        g.rule_s1_whitelist(REL, "lab-x", {}, "", "ConfigMap", "c")
        self.assertEqual(len(g.errs), 3)
        g = guard()
        g.rule_s1_whitelist(REL, "lab-x", dict(lab, clusterResourceBlacklist=[{"group": "", "kind": "Namespace"}]),
                            "", "Namespace", "lab-a")
        self.assertEqual(len(g.errs), 1)

    def test_s2_network_policy(self):
        g = guard()
        g.check_np(REL, "lab-pg", "default-deny", {"ingress": [{"from": [{"podSelector": {}}]}]})
        self.assertEqual(g.errs, [])
        g.check_np(REL, "x", "y", {"ingress": [{}], "egress": [{"to": [{"ipBlock": {"cidr": "0.0.0.0/0"}},
                                                                     {"namespaceSelector": {}}]}]})
        self.assertEqual(len(g.errs), 4)

    def test_s3_lab_pg_labels(self):
        g = guard()
        g.rule_s3_lab_pg_labels(REL, dict(G.LAB_PG_LABELS))
        self.assertEqual(g.errs, [])
        g.rule_s3_lab_pg_labels(REL, {})
        self.assertEqual(len(g.errs), 3)
        g = guard()
        g.rule_s3_lab_pg_labels(REL, {**G.LAB_PG_LABELS, "pod-security.kubernetes.io/warn": "baseline"})
        self.assertIn("doit rester restricted", g.errs[0])

    def test_files_of_source(self):
        g = guard()
        g.files = {"platform/a.yaml": [], "platform/b.json": [], "platform/s/c.yaml": [], "platformx/d.yaml": []}
        self.assertEqual(g.files_of_source({"path": "platform/"}), {"platform/a.yaml", "platform/b.json"})
        self.assertEqual(g.files_of_source({"path": "platform", "directory": {"recurse": True, "include": "*.yaml"}}),
                         {"platform/a.yaml", "platform/s/c.yaml"})

    def test_expand_include(self):
        self.assertEqual(G.expand_include("{*.yaml, *.json}"), ["*.yaml", "*.json"])
        self.assertEqual(G.expand_include("*.yml"), ["*.yml"])


class PsaRules(unittest.TestCase):
    def test_vap_pod(self):
        errs = []
        PSA.rule_vap_pod({"hostNetwork": True, "hostPID": True, "hostIPC": True,
                          "volumes": [{"name": "h", "hostPath": {}}, {"name": "e", "emptyDir": {}}]}, errs)
        self.assertEqual(errs, ["VAP: hostNetwork", "VAP: hostPID", "VAP: hostIPC", "VAP: hostPath (h)"])
        errs = []
        PSA.rule_vap_pod({}, errs)
        self.assertEqual(errs, [])

    def test_pod_unconfined(self):
        errs = []
        PSA.rule_pod_unconfined({"appArmorProfile": {"type": "Unconfined"}, "seccompProfile": {"type": "Unconfined"}}, errs)
        self.assertEqual(len(errs), 2)
        errs = []
        PSA.rule_pod_unconfined({"seccompProfile": {"type": "RuntimeDefault"}}, errs)
        self.assertEqual(errs, [])

    def test_image_digest(self):
        w = []
        PSA.rule_image_digest({"image": "x@sha256:abc"}, "c", w)
        self.assertEqual(w, [])
        PSA.rule_image_digest({"image": "x:1"}, "c", w)
        self.assertEqual(w, ["image sans digest: c x:1"])

    def test_vap_privileged(self):
        e = []
        PSA.rule_vap_privileged({}, "c", e)
        self.assertEqual(e, [])
        PSA.rule_vap_privileged({"privileged": True}, "c", e)
        self.assertEqual(e, ["VAP: privileged (c)"])

    def test_baseline_hostport(self):
        e = []
        PSA.rule_baseline_hostport({"ports": [{"containerPort": 1}]}, "c", e)
        self.assertEqual(e, [])
        PSA.rule_baseline_hostport({"ports": [{"hostPort": 80}]}, "c", e)
        self.assertEqual(e, ["PSA baseline: hostPort (c)"])

    def test_baseline_unconfined(self):
        e = []
        PSA.rule_baseline_unconfined({"seccompProfile": {"type": "RuntimeDefault"}}, "c", e)
        self.assertEqual(e, [])
        PSA.rule_baseline_unconfined({"appArmorProfile": {"type": "Unconfined"},
                                      "seccompProfile": {"type": "Unconfined"}}, "c", e)
        self.assertEqual(len(e), 2)

    def test_baseline_caps(self):
        e = []
        PSA.rule_baseline_caps({"CHOWN"}, "c", e)
        self.assertEqual(e, [])
        PSA.rule_baseline_caps({"CHOWN", "SYS_ADMIN"}, "c", e)
        self.assertEqual(e, ["PSA baseline: capabilities ajoutées ['SYS_ADMIN'] (c)"])

    def test_requests(self):
        w = []
        PSA.rule_requests({"resources": {"requests": {"cpu": "1m", "memory": "1Mi"}}}, "c", w)
        self.assertEqual(w, [])
        PSA.rule_requests({"resources": {"requests": {"cpu": "1m"}}}, "c", w)
        PSA.rule_requests({}, "c", w)
        self.assertEqual(len(w), 2)

    def test_restricted_container(self):
        good = corpus.container()["securityContext"]
        e = []
        PSA.rule_restricted_container(good, {}, set(), "c", e)
        self.assertEqual(e, [])
        PSA.rule_restricted_container({}, {}, {"SYS_ADMIN"}, "c", e)
        self.assertEqual(len(e), 1)
        for frag in ("allowPrivilegeEscalation!=false", "drop ALL absent", "add ['SYS_ADMIN']", "runAsNonRoot absent",
                     "seccompProfile absent"):
            self.assertIn(frag, e[0])
        e = []
        PSA.rule_restricted_container(dict(good, runAsUser=0), {}, set(), "c", e)
        self.assertIn("runAsUser=0", e[0])
        e = []  # héritage du niveau pod
        PSA.rule_restricted_container({k: v for k, v in good.items() if k not in ("runAsNonRoot", "seccompProfile")},
                                      {"runAsNonRoot": True, "seccompProfile": {"type": "Localhost"}}, set(), "c", e)
        self.assertEqual(e, [])

    def test_restricted_volumes(self):
        e = []
        PSA.rule_restricted_volumes({"volumes": [{"name": "v", "emptyDir": {}}]}, e)
        self.assertEqual(e, [])
        PSA.rule_restricted_volumes({"volumes": [{"name": "v", "nfs": {}}]}, e)
        self.assertEqual(e, ["PSA restricted: volume v de type ['nfs']"])

    def test_check_levels(self):
        pod = {"kind": "Pod", "spec": {"containers": [{"name": "c", "image": "x"}]}}
        errs, warns = PSA.check(pod, "baseline")
        self.assertEqual(errs, [])
        self.assertEqual(len(warns), 2)
        errs, _ = PSA.check(pod, "restricted")
        self.assertEqual(len(errs), 1)
        self.assertEqual(PSA.check({"kind": "ConfigMap"}, "restricted"), ([], []))


if __name__ == "__main__":
    unittest.main()
