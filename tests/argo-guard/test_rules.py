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
K = sys.modules["argo_guard_k"]  # règles L1-L4, chargées par argo_guard.py (T-495)
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
        ok = {"namespaceResourceWhitelist": [{"group": "argoproj.io", "kind": "Application"},
                                             {"group": "argoproj.io", "kind": "ApplicationSet"}],
              "destinations": [{"namespace": "lab-argocd"}]}
        self.assertEqual(errs_of("rule_p2_lab_root", ok), [])
        self.assertEqual(errs_of("rule_p2_lab_root", None), [])
        self.assertIn("kinds Application et ApplicationSet", errs_of("rule_p2_lab_root", {**ok, "destinations": []})[0])
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


class LabKRules(unittest.TestCase):
    """L1-L4 (T-495) : AppProject lab-k et lab-k-root, Application lab-k-root."""
    IN = "https://kubernetes.default.svc"

    def real(self):
        return corpus.real_guard().projects()

    def test_real_projects_pass(self):
        p = self.real()
        g = guard()
        g.check_projects(p)
        self.assertEqual(g.errs, [])

    def test_l1_destinations_refused(self):
        for ns in ("argocd", "kube-system", "lab-argocd", "lab-secrets", "openchoreo-*", "lab-*", "*", "svc-*"):
            k = self.real()["lab-k"]
            k["destinations"] = k["destinations"] + [{"server": self.IN, "namespace": ns}]
            errs = errs_of("rule_l1_lab_k", k)
            with self.subTest(ns=ns):
                self.assertTrue(any(e.startswith(f"{REL}: L1 lab-k : destinations exactes") for e in errs), errs)
                self.assertTrue(any("L2 lab-k : destination" in e for e in errs), errs)

    def test_t506_explicit_svc_and_kinds(self):
        """T-506 (E1, E5) : svc-<app> nommés seulement, lab-pg admis, `*/*` en kinds namespacés de lab-k seulement."""
        k = self.real()["lab-k"]
        self.assertEqual(errs_of("rule_l1_lab_k", k), [])
        for ns in ("svc-*", "svc-other", "svc-echo-*"):
            k2 = dict(k, destinations=k["destinations"] + [{"server": self.IN, "namespace": ns}])
            with self.subTest(ns=ns):
                self.assertTrue(errs_of("rule_l1_lab_k", k2), ns)
        k3 = dict(k, clusterResourceWhitelist=k["clusterResourceWhitelist"] + [{"group": "", "kind": "Namespace",
                                                                                "name": "svc-*"}])
        self.assertIn("L1 lab-k : clusterResourceWhitelist", errs_of("rule_l1_lab_k", k3)[0])
        k4 = dict(k, namespaceResourceBlacklist=[])
        self.assertIn("L1 lab-k : namespaceResourceBlacklist", errs_of("rule_l1_lab_k", k4)[0])
        self.assertTrue(K.k_wildcard_kinds_allowed("lab-k", "namespaceResourceWhitelist", {"group": "*", "kind": "*"}))
        for proj, key in (("lab-o", "namespaceResourceWhitelist"), ("lab-k", "clusterResourceWhitelist"),
                          ("lab-k-root", "namespaceResourceWhitelist")):
            with self.subTest(proj=proj, key=key):
                self.assertFalse(K.k_wildcard_kinds_allowed(proj, key, {"group": "*", "kind": "*"}))
        p = self.real()
        p["lab-o"]["namespaceResourceWhitelist"] = p["lab-o"]["namespaceResourceWhitelist"] + [{"group": "*", "kind": "*"}]
        g = guard()
        g.check_projects(p)
        self.assertTrue(any("P2 lab-o : namespaceResourceWhitelist joker" in e for e in g.errs), g.errs)

    def test_l1_other_cluster_refused(self):
        k = self.real()["lab-k"]
        k["destinations"] = [{"server": "https://evil.example.org", "namespace": "lab-k-*"},
                             {"server": self.IN, "namespace": "svc-*"}]
        self.assertTrue(any("L2" in e for e in errs_of("rule_l1_lab_k", k)))

    def test_l1_source_other_repo_refused(self):
        k = self.real()["lab-k"]
        for repos in (["https://github.com/platform-zephyr/openchoreo-lab"], k["sourceRepos"] + ["https://example.org/x"],
                      []):
            k2 = dict(k, sourceRepos=repos)
            with self.subTest(repos=repos):
                self.assertIn("L1 lab-k : sourceRepos limité", errs_of("rule_l1_lab_k", k2)[0])

    def test_l1_unlisted_kind_refused(self):
        for extra in ({"group": "external-secrets.io", "kind": "ExternalSecret"},
                      {"group": "external-secrets.io", "kind": "SecretStore"},
                      {"group": "generators.external-secrets.io", "kind": "Password"},
                      {"group": "", "kind": "ConfigMap"}):
            k = self.real()["lab-k"]
            k["namespaceResourceWhitelist"] = k["namespaceResourceWhitelist"] + [extra]
            with self.subTest(kind=extra["kind"]):
                self.assertTrue(any("namespaceResourceWhitelist = EXACTEMENT" in e
                                    for e in errs_of("rule_l1_lab_k", k)))
        k = self.real()["lab-k"]
        k["clusterResourceWhitelist"] = k["clusterResourceWhitelist"] + [
            {"group": "rbac.authorization.k8s.io", "kind": "ClusterRole", "name": "lab-k-x"}]
        self.assertTrue(any("clusterResourceWhitelist limitée" in e for e in errs_of("rule_l1_lab_k", k)))
        k = self.real()["lab-k"]
        k["namespaceResourceBlacklist"] = k["namespaceResourceBlacklist"][1:]
        self.assertTrue(any("namespaceResourceBlacklist de kube-ops" in e for e in errs_of("rule_l1_lab_k", k)))
        k = self.real()["lab-k"]
        k["namespaceResourceBlacklist"] = [r for r in k["namespaceResourceBlacklist"] if r["kind"] != "Cluster"]
        self.assertTrue(any("Cluster" in e for e in errs_of("rule_l1_lab_k", k)))
        k = self.real()["lab-k"]
        k["roles"] = [{"name": "x", "policies": ["p, proj:lab-k:x, applications, *, lab-k/*, allow"]}]
        self.assertIn("L1 lab-k : clé spec.roles interdite", errs_of("rule_l1_lab_k", k)[0])

    def test_svc_glob_only_for_lab_k(self):
        p = self.real()
        p["lab-o"]["destinations"] = p["lab-o"]["destinations"] + [{"server": self.IN, "namespace": "svc-*"}]
        g = guard()
        g.check_projects(p)
        self.assertTrue(any("P2 lab-o : destination joker" in e for e in g.errs), g.errs)
        p = self.real()
        p["lab-k-root"]["destinations"] = [{"server": self.IN, "namespace": "svc-*"}]
        g = guard()
        g.check_projects(p)
        self.assertTrue(any("P2 lab-k-root : destination joker" in e for e in g.errs), g.errs)

    def test_l1_k_repo_reserved(self):
        p = self.real()
        p["lab-platform"]["sourceRepos"] = p["lab-platform"]["sourceRepos"] + [K.K_REPOS[0]]
        self.assertIn("L1 lab-platform : dépôt du bac à sable", errs_of("rule_l1_k_repos", p)[0])

    def test_l3_lab_k_root_project(self):
        kr = self.real()["lab-k-root"]
        self.assertEqual(errs_of("rule_l3_lab_k_root", kr), [])
        for key, val in (("namespaceResourceWhitelist", [{"group": "argoproj.io", "kind": "ApplicationSet"},
                                                         {"group": "argoproj.io", "kind": "Application"}]),
                         ("destinations", [{"server": self.IN, "namespace": "argocd"}]),
                         ("clusterResourceWhitelist", [{"group": "", "kind": "Namespace", "name": "lab-k-x"}])):
            with self.subTest(key=key):
                self.assertIn("L3 lab-k-root", errs_of("rule_l3_lab_k_root", dict(kr, **{key: val}))[0])

    def test_l3_k_root_app(self):
        dst = {"server": self.IN, "namespace": "lab-argocd"}
        ok = {"project": "lab-k-root", "source": dict(K.K_ROOT_SOURCE), "destination": dst}
        self.assertEqual(errs_of("rule_l3_k_root_app", "lab-k-root", "lab-k-root", ok), [])
        self.assertEqual(errs_of("rule_l3_k_root_app", "x", "lab-platform", {}), [])
        bad_sources = {
            "projet-copie": dict(K.K_ROOT_SOURCE, directory={"recurse": False, "include": "*.yaml"}),
            "autre-depot": dict(K.K_ROOT_SOURCE, repoURL="https://github.com/platform-zephyr/openchoreo-lab"),
            "recurse": dict(K.K_ROOT_SOURCE, directory=dict(K.K_ROOT_SOURCE["directory"], recurse=True)),
            "chemin": dict(K.K_ROOT_SOURCE, path="k8s"),
        }
        for sid, s in bad_sources.items():
            with self.subTest(source=sid):
                self.assertIn("L3", errs_of("rule_l3_k_root_app", "lab-k-root", "lab-k-root",
                                            dict(ok, source=s))[0])
        self.assertIn("L3", errs_of("rule_l3_k_root_app", "lab-k-root", "lab-k-root",
                                    dict(ok, destination={"server": self.IN, "namespace": "kube-system"}))[0])
        self.assertIn("L3", errs_of("rule_l3_k_root_app", "other", "lab-k-root", ok)[0])
        self.assertIn("L3", errs_of("rule_l3_k_root_app", "lab-k-root", "lab-platform", ok)[0])

    def test_l4_lab_k_not_for_repo_apps(self):
        self.assertIn("projet 'lab-k' interdit", errs_of("rule_a2_project", "x", "lab-k")[0])


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
        g.rule_a2_project(f"{G.ARGO}/apps/x.yaml", "x", "lab-o")
        self.assertIn("réservé à l'ApplicationSet lab-o", g.errs[0])  # aucune Application écrite à la main
        g = guard()
        g.rule_a2_project(f"{G.ARGO}/apps/x.yaml", "x", "lab-platform")
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
        res = corpus.run_apps(G, f"{G.ARGO}/apps/x.yaml", corpus.app_obj("x", "lab-platform", sources=[]))
        self.assertIn("sources multiples interdites", res["errs"][0])
        res = corpus.run_apps(G, f"{G.ARGO}/apps/x.yaml", corpus.app_obj("x", "lab-platform", corpus.src("platform")))
        self.assertEqual(res["errs"], [])

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
        self.assertEqual(errs_of("rule_a4_manual_sync", "x", "lab-o", auto), [])
        self.assertEqual(errs_of("rule_a4_manual_sync", "x", "lab-platform", {"syncPolicy": {}}), [])
        for proj in ("lab-platform", "lab-authz"):
            self.assertIn("A4", errs_of("rule_a4_manual_sync", "x", proj, auto)[0])

    def test_a3_platform_path(self):
        for path in ("platform", "platform/policies", "platform/data"):
            self.assertEqual(errs_of("rule_a3_platform_path", "x", "lab-platform", {"path": path}), [], path)
        for path in ("generated/x", "platformx", "platform/../x", G.ARGO, "platform/authz", ""):
            self.assertEqual(len(errs_of("rule_a3_platform_path", "x", "lab-platform", {"path": path})), 1, path)
        self.assertEqual(errs_of("rule_a3_platform_path", "x", "lab-o", {"path": "generated"}), [])

    def test_appset_ok_and_refusals(self):
        specs = corpus.appset_specs()
        rel = f"{G.ARGO}/apps/lab-apps.yaml"
        tree = {f"{G.APPS_PATH}/projects/{a}/x.yaml": [] for a in ("w", "k3dapp")}
        self.assertEqual(corpus.run_appset(G, rel, specs["ok"], tree), [])
        for sid, o in specs.items():
            if sid != "ok":
                with self.subTest(sid):
                    self.assertTrue(corpus.run_appset(G, rel, o, tree), sid)

    def test_appset_location_and_name(self):
        ok = corpus.appset_obj()
        self.assertIn("O1", corpus.run_appset(G, "platform/x.yaml", ok)[0])
        bad = dict(ok, metadata={"name": "evil"})
        self.assertIn("O1", corpus.run_appset(G, f"{G.ARGO}/apps/x.yaml", bad)[0])
        g = guard()
        g.files = {}
        g.check_appset(f"{G.ARGO}/apps/a.yaml", ok)
        g.check_appset(f"{G.ARGO}/apps/b.yaml", ok)  # un second ApplicationSet
        self.assertTrue(any("O1" in e for e in g.errs))

    def test_o5_unlisted_k3d_app_is_ignored(self):
        """T-502 : une app k3d générée mais absente de la liste n'est ni refusée ni synchronisée."""
        rel = f"{G.ARGO}/apps/lab-apps.yaml"
        tree = {f"{G.APPS_PATH}/projects/{a}/x.yaml": [] for a in ("w", "autre")}
        self.assertEqual(corpus.run_appset(G, rel, corpus.appset_obj(), tree), [])

    def test_o5_list_refusals(self):
        """T-502 : chaque variante non conforme de la liste OKE est refusée par O5 (cas négatifs)."""
        tree = {f"{G.APPS_PATH}/projects/{a}/x.yaml": [] for a in ("w", "k3dapp")}
        for lid, lst in corpus.lab_o_list_cases().items():
            with self.subTest(lid):
                errs = corpus.run_appset(G, f"{G.ARGO}/apps/lab-apps.yaml", corpus.appset_obj(), tree, lst)
                if lid in ("ok", "vide"):
                    self.assertEqual(errs, [])
                else:
                    self.assertTrue(errs and all(f"{G.LAB_O_LIST}: O5 lab-o : " in e for e in errs), errs)

    def test_o5_real_list_matches_oke_apps(self):
        """La liste versionnée est exactement l'ensemble des apps déployées sur OKE (whoami, ntfy, echo-demo, searxng)."""
        g = guard()
        self.assertEqual(g.load(), 0)
        self.assertEqual(sorted(g.lab_o_apps()), ["echo-demo", "ntfy", "searxng", "whoami"])
        self.assertNotIn("miniflux", g.lab_o_apps())
        self.assertNotIn("echo-bench", g.lab_o_apps())

    def test_o5_missing_list_fails_closed(self):
        g = guard()
        g.files, g.lab_o_list = {}, None
        g.check_appset(f"{G.ARGO}/apps/lab-apps.yaml", corpus.appset_obj())
        self.assertEqual(g.errs, [f"{G.LAB_O_LIST}: O5 lab-o : liste absente ou invalide (attendu : une liste `- app: <nom>`)"])

    def test_appset_files_only_listed(self):
        g = guard()
        pre = G.APPS_PATH + "/projects/"
        g.files = {f"{pre}w/a.yaml": [], f"{pre}w/sub/b.yaml": [], f"{pre}k3dapp/c.yaml": [], f"{pre}w/d.json": [],
                   f"{pre}wx/e.yaml": []}
        g.lab_o_list = [{"app": "w"}, {"app": "../k3dapp"}]
        self.assertEqual(g.appset_files(corpus.appset_obj()), {f"{pre}w/a.yaml", f"{pre}w/sub/b.yaml"})


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

    def test_s4_tunnel_named_objects(self):
        lab = {"namespaceResourceWhitelist": [{"group": "apps", "kind": "Deployment"},
                                              {"group": "cilium.io", "kind": "CiliumNetworkPolicy"}]}
        ok = {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": "cloudflared", "namespace": "lab-tunnel"}}
        g = guard()
        g.check_synced_object(REL, ok, "lab-platform", lab)
        self.assertEqual(g.errs, [])
        bad = {"apiVersion": "cilium.io/v2", "kind": "CiliumNetworkPolicy",
               "metadata": {"name": "open-all", "namespace": "openchoreo-control-plane"}}
        g.check_synced_object(REL, bad, "lab-platform", lab)
        self.assertEqual(len(g.errs), 1)
        self.assertIn("S4 CiliumNetworkPolicy openchoreo-control-plane/open-all", g.errs[0])

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
