"""Corpus de caractérisation de tools/oke/argo_guard.py et psa_check.py (T-423).

Chaque cas est un identifiant stable + une entrée ; `run_*` rend la sortie observable (liste de messages). Le gel
`golden.json` a été produit AVANT le découpage, contre l'ancien code : le refactor doit le reproduire à l'identique.
Régénérer (jamais après un refactor, seulement pour une règle changée volontairement) :
    python3 -I tests/argo-guard/corpus.py | gzip -9n > tests/argo-guard/golden.json.gz
"""
import copy
import importlib.util
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]


def load_module(name, rel):
    spec = importlib.util.spec_from_file_location(name, ROOT / rel)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


GUARD = load_module("argo_guard_under_test", "tools/oke/argo_guard.py")
PSA = load_module("psa_check_under_test", "tools/oke/psa_check.py")


def real_guard():
    g = GUARD.Guard(ROOT)
    assert g.load() == 0
    return g


# --- check_projects -------------------------------------------------------------------------------------
KEYS = ("sourceRepos", "destinations", "sourceNamespaces", "clusterResourceWhitelist", "namespaceResourceWhitelist",
        "namespaceResourceBlacklist", "clusterResourceBlacklist", "syncWindows")
VARIANTS = {
    "absent": None,
    "vide": [],
    "repo-joker": ["https://github.com/*"],
    "repo-ok": ["https://github.com/platform-zephyr/openchoreo-lab"],
    "dest-server-joker": [{"server": "*", "namespace": "default"}],
    "dest-ns-joker": [{"server": "https://kubernetes.default.svc", "namespace": "*"}],
    "dest-name-joker": [{"name": "*", "namespace": "default"}],
    "dest-lab-argocd": [{"server": "https://kubernetes.default.svc", "namespace": "lab-argocd"}],
    "dest-default": [{"server": "https://kubernetes.default.svc", "namespace": "default"}],
    "wl-group-joker": [{"group": "*", "kind": "Foo", "name": "x"}],
    "wl-kind-joker": [{"group": "g", "kind": "*", "name": "x"}],
    "wl-name-joker": [{"group": "g", "kind": "Foo", "name": "*"}],
    "wl-sans-nom": [{"group": "g", "kind": "Foo"}],
    "wl-application": [{"group": "argoproj.io", "kind": "Application"}],
    "wl-appproject": [{"group": "argoproj.io", "kind": "AppProject", "name": "x"}],
    "wl-appset": [{"group": "argoproj.io", "kind": "ApplicationSet", "name": "x"}],
    "wl-authz-ok": [{"group": "openchoreo.dev", "kind": "AuthzRole", "name": "lab-x"}],
    "wl-authz-nom-hors-lab": [{"group": "openchoreo.dev", "kind": "AuthzRole", "name": "x"}],
    "wl-autre-kind": [{"group": "openchoreo.dev", "kind": "Component"}],
    "wl-appkind-nomme": [{"group": "openchoreo.dev", "kind": "Component", "name": "n"}],
    "wl-mauvais-groupe": [{"group": "apps", "kind": "Component"}],
    "wl-kind-inconnu": [{"group": "openchoreo.dev", "kind": "Secret"}],
    "bl-tout": [{"group": "*", "kind": "*"}],
    "bl-partiel": [{"group": "*", "kind": "Secret"}],
    "win-deny": [dict(GUARD.DENY_WINDOW)],
    "win-allow": [dict(GUARD.DENY_WINDOW), {"kind": "allow", "schedule": "* * * * *", "duration": "1h",
                                            "applications": ["*"]}],
    "win-deny-court": [dict(GUARD.DENY_WINDOW, duration="1h")],
    "win-deny-sans-manual": [{k: v for k, v in GUARD.DENY_WINDOW.items() if k != "manualSync"}],
}
DEFAULT_KEYS = ("sourceRepos", "destinations", "sourceNamespaces", "clusterResourceWhitelist",
                "namespaceResourceWhitelist", "clusterResourceBlacklist", "namespaceResourceBlacklist")


def projects_cases():
    base = {k: copy.deepcopy(v) for k, v in real_guard().projects().items()}
    yield "base", base
    for name in base:
        p = copy.deepcopy(base)
        del p[name]
        yield f"{name}/projet-absent", p
        p = copy.deepcopy(base)
        p[name] = {}
        yield f"{name}/spec-vide", p
    for name in base:
        keys = DEFAULT_KEYS if name == "default" else KEYS
        for key in keys:
            for vname, val in VARIANTS.items():
                if (key == "sourceRepos") != vname.startswith("repo-") and vname not in ("absent", "vide"):
                    continue  # types réalistes : chaînes pour sourceRepos, mappings pour les autres clés
                p = copy.deepcopy(base)
                if val is None:
                    p[name].pop(key, None)
                else:
                    p[name][key] = copy.deepcopy(val)
                yield f"{name}/{key}/{vname}", p
    # combinaisons : plusieurs écarts simultanés
    p = copy.deepcopy(base)
    p["lab-root"].update(clusterResourceWhitelist=[{"group": "", "kind": "Namespace", "name": "x"}],
                         namespaceResourceWhitelist=[{"group": "*", "kind": "*"}], destinations=[])
    yield "combo/lab-root", p
    p = copy.deepcopy(base)
    p["lab-o"] = {"sourceRepos": ["*"], "destinations": [{"namespace": "x*"}],
                     "namespaceResourceWhitelist": [{"group": "g", "kind": "Application"}],
                     "sourceNamespaces": ["x"]}
    yield "combo/lab-o", p
    p = copy.deepcopy(base)
    p["lab-authz"]["namespaceResourceBlacklist"] = []
    p["lab-authz"]["namespaceResourceWhitelist"] = [{"group": "g", "kind": "Foo"}]
    yield "combo/lab-authz", p
    p = copy.deepcopy(base)
    p["default"]["clusterResourceBlacklist"] = [{"group": "*", "kind": "Secret"}]
    yield "combo/default-bl-cluster", p
    p = copy.deepcopy(base)
    p["default"]["namespaceResourceBlacklist"] = []
    yield "combo/default-bl-ns-vide", p
    p = copy.deepcopy(base)
    p["default"]["namespaceResourceBlacklist"] = None
    yield "combo/default-bl-ns-none", p


def run_projects(mod, projs):
    g = mod.Guard(ROOT)
    g.check_projects(projs)
    return g.errs


# --- check_apps / check_lab_apps_sources ---------------------------------------------------------------
A = GUARD.ARGO
REPO = "https://github.com/platform-zephyr/openchoreo-lab"


def src(path, **extra):
    return {"repoURL": REPO, "targetRevision": "main", "path": path, **extra}


def lab_src(app):
    return src(f"{GUARD.APPS_PATH}/projects/{app}", directory={"recurse": True, "include": "*.yaml"})


def app_obj(name, project, source=None, kind="Application", sources=None, sync=None, extra_spec=None):
    spec = {"project": project}
    if source is not None:
        spec["source"] = source
    if sources is not None:
        spec["sources"] = sources
    if sync is not None:
        spec["syncPolicy"] = sync
    spec.update(extra_spec or {})
    return {"apiVersion": "argoproj.io/v1alpha1", "kind": kind, "metadata": {"name": name}, "spec": spec}


AUTO = {"automated": {"prune": True}}


def apps_cases():
    cases = []
    locations = {"apps": f"{A}/apps/x.yaml", "racine": GUARD.ROOT_APP, "ailleurs": "platform/data/x.yaml",
                 "apps-sous": f"{A}/apps/sub/x.yaml"}
    projects = ("lab-platform", "lab-o", "lab-authz", "lab-root", "default", "autre", None)
    names = ("lab-root", "lab-platform", "lab-o", "lab-authz", "evil")
    sources = {
        "platform": src("platform/policies"),
        "platform-racine": src("platform"),
        "platform-slash": src("platform/"),
        "authz": src("platform/authz"),
        "authz-rec": src("platform/authz", directory={"recurse": True}),
        "argocd": src(A),
        "argo-apps": src(f"{A}/apps"),
        "argo-apps-rec": src(f"{A}/apps", directory={"recurse": True}),
        "traversee": src("platform/../x"),
        "hors-platform": src("generated/x"),
        "platformx": src("platformx"),
        "helm": src("platform", helm={"x": 1}),
        "chart": {"repoURL": REPO, "chart": "c"},
        "kustomize": src("platform", kustomize={}),
        "plugin": src("platform", plugin={}),
        "vide": {},
    }
    for lname, rel in locations.items():
        for proj in projects:
            for name in names:
                for sname, s in sources.items():
                    if proj == "lab-o":
                        continue
                    cases.append((f"{lname}/{proj}/{name}/{sname}", rel, app_obj(name, proj, s)))
    for lname, rel in locations.items():
        for proj in ("lab-platform", "lab-authz", "lab-root", "lab-o", "default"):
            for sync_name, sync in (("auto", AUTO), ("auto-vide", {"automated": None}), ("manuel", {})):
                cases.append((f"sync/{lname}/{proj}/{sync_name}", rel,
                              app_obj("lab-" + proj[4:], proj, src("platform/x"), sync=sync)))
    cases.append(("appset", f"{A}/apps/x.yaml", app_obj("x", "lab-platform", kind="ApplicationSet")))
    cases.append(("appset-ailleurs", "platform/x.yaml", app_obj("x", "default", kind="ApplicationSet")))
    cases.append(("sans-spec", f"{A}/apps/x.yaml", {"kind": "Application", "metadata": {"name": "x"}}))
    cases.append(("sans-nom", f"{A}/apps/x.yaml", {"kind": "Application", "spec": {"project": "lab-platform"}}))
    cases.append(("sources-multiples", f"{A}/apps/x.yaml", app_obj("x", "lab-platform", sources=[src("platform")])))
    cases.append(("sources-et-source", f"{A}/apps/lab-o.yaml",
                  app_obj("lab-o", "lab-o", src("x"), sources=[lab_src("whoami")])))
    return cases


def appset_obj(**over):
    """ApplicationSet lab-o conforme (T-491, T-502) ; `over` remplace des clés de spec."""
    spec = {
        "goTemplate": True, "goTemplateOptions": ["missingkey=error"],
        "syncPolicy": {"preserveResourcesOnDeletion": True},
        "generators": [{"git": {"repoURL": REPO, "revision": "main",
                                "files": [{"path": GUARD.LAB_O_LIST}]}}],
        "template": {
            "metadata": {"name": "lab-o-{{.app}}"},
            "spec": {"project": "lab-o",
                     "source": {"repoURL": REPO, "targetRevision": "main", "path": GUARD.APP_PATH_TPL,
                                "directory": {"recurse": True, "include": "*.yaml"}},
                     "destination": {"server": "https://kubernetes.default.svc", "namespace": "default"},
                     "syncPolicy": {"automated": {"prune": False, "selfHeal": True}}}},
    }
    spec.update(over)
    return {"apiVersion": "argoproj.io/v1alpha1", "kind": "ApplicationSet", "metadata": {"name": "lab-o"},
            "spec": spec}


def appset_specs():
    """Variantes de l'ApplicationSet : `ok` conforme, les autres ont UN écart chacune."""
    prefix = GUARD.APPS_PATH + "/projects/"
    ok = appset_obj()

    def tpl(**spec_over):
        t = copy.deepcopy(ok["spec"]["template"])
        t["spec"].update(spec_over)
        return {"template": t}

    def gen(**git_over):
        g = copy.deepcopy(ok["spec"]["generators"])
        g[0]["git"].update(git_over)
        return {"generators": g}

    return {
        "ok": ok,
        "sans-gotemplate": appset_obj(goTemplate=False),
        "sans-missingkey": appset_obj(goTemplateOptions=[]),
        "sans-preserve": appset_obj(syncPolicy={}),
        "template-patch": appset_obj(templatePatch="spec:\n  project: x"),
        "strategie": appset_obj(strategy={"type": "RollingSync"}),
        "deux-generateurs": appset_obj(generators=ok["spec"]["generators"] * 2),
        "generateur-directories": appset_obj(generators=[{"git": {"repoURL": REPO, "revision": "main",
                                                                  "directories": [{"path": prefix + "*"}]}}]),
        "generateur-list": appset_obj(generators=[{"list": {"elements": []}}]),
        "generateur-absent": appset_obj(generators=[]),
        "depot-autre": appset_obj(**gen(repoURL="https://example.org/evil")),
        "revision-dev": appset_obj(**gen(revision="dev")),
        "files-autre-liste": appset_obj(**gen(files=[{"path": "clusters/k3d/lab-o-apps.yaml"}])),
        "files-glob": appset_obj(**gen(files=[{"path": "apps/*/app.yaml"}])),
        "files-deux": appset_obj(**gen(files=[{"path": GUARD.LAB_O_LIST}, {"path": "clusters/k3d/x.yaml"}])),
        "files-exclusion": appset_obj(**gen(files=[{"path": GUARD.LAB_O_LIST, "exclude": True}])),
        "files-et-directories": appset_obj(**gen(directories=[{"path": prefix + "*"}])),
        "files-absent": appset_obj(**gen(files=[])),
        "nom-autre": appset_obj(**{"template": dict(ok["spec"]["template"], metadata={"name": "{{.path.basename}}"})}),
        "projet-parametre": appset_obj(**tpl(project="{{.app}}")),
        "projet-autre": appset_obj(**tpl(project="lab-platform")),
        "projet-default": appset_obj(**tpl(project="default")),
        "destination-parametree": appset_obj(**tpl(destination={"server": "https://kubernetes.default.svc",
                                                                "namespace": "{{.app}}"})),
        "destination-kube-system": appset_obj(**tpl(destination={"server": "https://kubernetes.default.svc",
                                                                 "namespace": "kube-system"})),
        "destination-serveur": appset_obj(**tpl(destination={"server": "https://evil.example.org",
                                                             "namespace": "default"})),
        "source-chemin-path": appset_obj(**tpl(source=dict(ok["spec"]["template"]["spec"]["source"],
                                                           path="{{.path.path}}"))),
        "nom-path": appset_obj(**{"template": dict(ok["spec"]["template"],
                                                    metadata={"name": "lab-o-{{.path.basename}}"})}),
        "source-chemin-fixe": appset_obj(**tpl(source=dict(ok["spec"]["template"]["spec"]["source"], path="platform"))),
        "source-helm": appset_obj(**tpl(source=dict(ok["spec"]["template"]["spec"]["source"], helm={}))),
        "source-depot": appset_obj(**tpl(source=dict(ok["spec"]["template"]["spec"]["source"],
                                                     repoURL="https://example.org/evil"))),
        "source-revision": appset_obj(**tpl(source=dict(ok["spec"]["template"]["spec"]["source"],
                                                        targetRevision="dev"))),
        "source-sans-recurse": appset_obj(**tpl(source=dict(ok["spec"]["template"]["spec"]["source"],
                                                            directory={"include": "*.yaml"}))),
        "source-include-large": appset_obj(**tpl(source=dict(ok["spec"]["template"]["spec"]["source"],
                                                             directory={"recurse": True, "include": "*"}))),
        "spec-cle-interdite": appset_obj(**tpl(ignoreDifferences=[{"kind": "Secret"}])),
        "prune": appset_obj(**tpl(syncPolicy={"automated": {"prune": True}})),
        "vide": {"kind": "ApplicationSet", "metadata": {"name": "lab-o"}},
    }


DEFAULT_LIST = [{"app": "w"}]


def run_appset(mod, rel, obj, files=None, lab_o_list=DEFAULT_LIST):
    g = mod.Guard(ROOT)
    g.files = files if files is not None else {}
    g.lab_o_list = lab_o_list
    g.oke_apps = lambda: {"w"}
    g.check_appset(rel, obj)
    return g.errs


def run_apps(mod, rel, obj):
    g = mod.Guard(ROOT)
    g.files = {rel: [obj]}
    apps = g.check_apps()
    return {"errs": g.errs, "apps": [r for r, _ in apps]}


# --- synced / check_synced / check_np / oke_apps ----------------------------------------------------------
def synced_cases():
    files = {
        "platform/a.yaml": [], "platform/b.yml": [], "platform/c.json": [], "platform/sub/d.yaml": [],
        "platform/sub/deep/e.yaml": [], "platformx/f.yaml": [], "generated/namespaces/default/projects/w/g.yaml": [],
        "generated/namespaces/default/projects/w/sub/h.yaml": [], "generated/namespaces/default/projects/w/i.yml": [],
        "other/j.yaml": [],
    }
    inc = {"aucun": None, "yaml": "*.yaml", "accolades": "{*.yaml, *.json}", "yml": "*.yml", "vide": ""}
    for pname in ("lab-platform", "lab-o", "lab-authz", "default"):
        for path in ("platform", "platform/", "platform/sub", "generated/namespaces/default/projects/w", "nope"):
            for rec in (None, True, False):
                for iname, i in inc.items():
                    d = {}
                    if rec is not None:
                        d["recurse"] = rec
                    if i is not None:
                        d["include"] = i
                    s = {"path": path}
                    if d:
                        s["directory"] = d
                    yield f"{pname}/{path}/{rec}/{iname}", files, app_obj("a", pname, s)
    for pname in ("lab-platform", "lab-o"):
        yield f"{pname}/multi", files, app_obj("a", pname, sources=[lab_src("w"), "x", {"foo": 1}, src("platform")])
        yield f"{pname}/sans-path", files, app_obj("a", pname, {"repoURL": REPO})
        yield f"{pname}/sans-source", files, app_obj("a", pname)
        yield f"{pname}/sources-vide", files, app_obj("a", pname, sources=[])


def run_synced(mod, files, obj):
    g = mod.Guard(ROOT)
    g.files = files
    out = g.synced([("x.yaml", obj)])
    return {k: sorted(v) for k, v in out.items()}


def obj(kind, name, ns=None, api="v1", spec=None, labels=None):
    md = {"name": name}
    if ns:
        md["namespace"] = ns
    if labels is not None:
        md["labels"] = labels
    d = {"apiVersion": api, "kind": kind, "metadata": md}
    if spec is not None:
        d["spec"] = spec
    return d


PG = {"app.kubernetes.io/part-of": "openchoreo-lab", "platform.smadja.dev/egress-isolated": "true",
      "pod-security.kubernetes.io/enforce": "restricted"}
NP_SPECS = {
    "vide": {},
    "ingress-sans-from": {"ingress": [{}]},
    "ingress-none": {"ingress": [None]},
    "ingress-from-vide": {"ingress": [{"from": []}]},
    "egress-sans-to": {"egress": [{"ports": []}]},
    "ns-selector-vide": {"ingress": [{"from": [{"namespaceSelector": {}}]}]},
    "ns-selector-ok": {"ingress": [{"from": [{"namespaceSelector": {"matchLabels": {"a": "b"}}}]}]},
    "cidr-0": {"egress": [{"to": [{"ipBlock": {"cidr": "0.0.0.0/0"}}]}]},
    "cidr-v6": {"egress": [{"to": [{"ipBlock": {"cidr": "::/0"}}]}]},
    "cidr-ok": {"egress": [{"to": [{"ipBlock": {"cidr": "10.0.0.0/8"}}]}]},
    "cidr-sans": {"egress": [{"to": [{"podSelector": {}}]}]},
    "combo": {"ingress": [{"from": [{"namespaceSelector": {}}, {"ipBlock": {"cidr": "1.0.0.0/0"}}]}, {}],
              "egress": [{"to": [{"ipBlock": {"cidr": "0.0.0.0/0"}}]}]},
}


def synced_objects():
    objs = {
        "cm": obj("ConfigMap", "c", "x"),
        "ns-lab-pg": obj("Namespace", "lab-pg", labels=PG),
        "ns-lab-pg-sans-labels": obj("Namespace", "lab-pg"),
        "ns-lab-pg-labels-faux": obj("Namespace", "lab-pg",
                                     labels={**PG, "pod-security.kubernetes.io/enforce": "baseline"}),
        "ns-lab-pg-warn-ok": obj("Namespace", "lab-pg", labels={**PG, "pod-security.kubernetes.io/warn": "restricted",
                                                               "pod-security.kubernetes.io/audit": "restricted"}),
        "ns-lab-pg-warn-ko": obj("Namespace", "lab-pg", labels={**PG, "pod-security.kubernetes.io/warn": "baseline"}),
        "ns-lab-pg-audit-ko": obj("Namespace", "lab-pg",
                                  labels={**PG, "pod-security.kubernetes.io/audit": "privileged"}),
        "ns-autre": obj("Namespace", "autre"),
        "crd": obj("CustomResourceDefinition", "x.y", api="apiextensions.k8s.io/v1"),
        "clusterrole": obj("ClusterRole", "r", api="rbac.authorization.k8s.io/v1"),
        "vap": obj("ValidatingAdmissionPolicy", "lab-x", api="admissionregistration.k8s.io/v1"),
        "authzrole": obj("ClusterAuthzRole", "lab-x", api="openchoreo.dev/v1alpha1"),
        "component": obj("Component", "c", "default", api="openchoreo.dev/v1alpha1"),
        "secret": obj("Secret", "s", "x"),
        "sans-api": {"kind": "Thing", "metadata": {"name": "t"}},
        "sans-metadata": {"apiVersion": "v1", "kind": "ConfigMap"},
    }
    for ns, n in (("lab-pg", "default-deny"), ("lab-pg", "allow-pg-clients"), ("lab-pg", "autre"), ("x", "default-deny")):
        for sname, spec in NP_SPECS.items():
            objs[f"np/{ns}/{n}/{sname}"] = obj("NetworkPolicy", n, ns, api="networking.k8s.io/v1", spec=spec)
    return objs


def project_specs():
    base = real_guard().projects()
    out = {"vide": {}, "reelle/lab-platform": base["lab-platform"], "reelle/lab-o": base["lab-o"],
           "reelle/lab-authz": base["lab-authz"]}
    out["tout"] = {"clusterResourceWhitelist": [{"group": "*", "kind": "*"}],
                   "namespaceResourceWhitelist": [{"group": "*", "kind": "*"}]}
    out["tout-bl"] = {**out["tout"], "namespaceResourceBlacklist": [{"group": "", "kind": "Secret"}],
                      "clusterResourceBlacklist": [{"group": "", "kind": "Namespace"}]}
    out["nom-glob"] = {"clusterResourceWhitelist": [{"group": "", "kind": "Namespace", "name": "lab-*"}],
                       "namespaceResourceWhitelist": [{"group": "", "kind": "ConfigMap"}]}
    out["wl-ns-seule"] = {"namespaceResourceWhitelist": [{"group": "", "kind": "ConfigMap"},
                                                         {"group": "networking.k8s.io", "kind": "NetworkPolicy"}]}
    return out


def run_check_synced(mod, files, project, spec):
    g = mod.Guard(ROOT)
    g.files = files
    g.check_synced(set(files), project, spec)
    return g.errs


def oke_files_cases():
    def app_yaml(**spec):
        return [{"kind": "App", "spec": spec}]
    return {
        "oke-stateless": {"apps/a/app.yaml": app_yaml(cluster="oke", profile="stateless")},
        "k3d": {"apps/a/app.yaml": app_yaml(cluster="k3d", profile="stateless")},
        "stateful": {"apps/a/app.yaml": app_yaml(cluster="oke", profile="stateless", storage={})},
        "database": {"apps/a/app.yaml": app_yaml(cluster="oke", profile="stateless", database={})},
        "profil-autre": {"apps/a/app.yaml": app_yaml(cluster="oke", profile="postgres")},
        "pas-app": {"apps/a/app.yaml": [{"kind": "Other", "spec": {"cluster": "oke", "profile": "stateless"}}]},
        "mauvais-chemin": {"apps/a/b/app.yaml": app_yaml(cluster="oke", profile="stateless"),
                           "apps/app.yaml": app_yaml(cluster="oke", profile="stateless"),
                           "platform/a/app.yaml": app_yaml(cluster="oke", profile="stateless"),
                           "apps/a/values.yaml": app_yaml(cluster="oke", profile="stateless")},
        "mixte": {"apps/a/app.yaml": app_yaml(cluster="oke", profile="stateless"),
                  "apps/b/app.yaml": app_yaml(cluster="k3d", profile="stateless")},
        "sans-spec": {"apps/a/app.yaml": [{"kind": "App"}]},
    }


def run_oke(mod, files):
    g = mod.Guard(ROOT)
    g.files = files
    return sorted(g.oke_apps())


# --- psa_check.check ------------------------------------------------------------------------------------
def container(**kw):
    c = {"name": "c", "image": "x@sha256:" + "0" * 64, "resources": {"requests": {"cpu": "1m", "memory": "1Mi"}},
         "securityContext": {"allowPrivilegeEscalation": False, "runAsNonRoot": True,
                             "capabilities": {"drop": ["ALL"]}, "seccompProfile": {"type": "RuntimeDefault"}}}
    for k, v in kw.items():
        if v is None:
            c.pop(k, None)
        else:
            c[k] = v
    return c


def sc(**kw):
    base = copy.deepcopy(container()["securityContext"])
    for k, v in kw.items():
        if v is None:
            base.pop(k, None)
        else:
            base[k] = v
    return base


def psa_pods():
    pods = {}
    pods["ok"] = {"containers": [container()]}
    pods["vide"] = {}
    for f in ("hostNetwork", "hostPID", "hostIPC"):
        pods[f"vap-{f}"] = {"containers": [container()], f: True}
    pods["vap-hostpath"] = {"containers": [container()], "volumes": [{"name": "h", "hostPath": {"path": "/"}}]}
    pods["vol-ok"] = {"containers": [container()],
                      "volumes": [{"name": "v", "emptyDir": {}}, {"name": "s", "secret": {}}]}
    pods["vol-nfs"] = {"containers": [container()], "volumes": [{"name": "v", "nfs": {}}]}
    pods["vol-multi"] = {"containers": [container()], "volumes": [{"name": "v", "emptyDir": {}, "nfs": {}}]}
    pods["pod-apparmor"] = {"containers": [container()],
                            "securityContext": {"appArmorProfile": {"type": "Unconfined"}}}
    pods["pod-seccomp-unconf"] = {"containers": [container()],
                                  "securityContext": {"seccompProfile": {"type": "Unconfined"}}}
    pods["pod-seccomp-ok"] = {"containers": [container(securityContext=sc(seccompProfile=None))],
                              "securityContext": {"seccompProfile": {"type": "RuntimeDefault"}}}
    pods["pod-nonroot"] = {"containers": [container(securityContext=sc(runAsNonRoot=None))],
                           "securityContext": {"runAsNonRoot": True}}
    pods["pod-user0"] = {"containers": [container()], "securityContext": {"runAsUser": 0}}
    pods["ctr-user0"] = {"containers": [container(securityContext=sc(runAsUser=0))]}
    pods["ctr-user0-pod-ok"] = {"containers": [container(securityContext=sc(runAsUser=1000))],
                                "securityContext": {"runAsUser": 0}}
    pods["init"] = {"containers": [container()],
                    "initContainers": [container(name="i", securityContext=sc(privileged=True))]}
    pods["sans-digest"] = {"containers": [container(image="x:1")]}
    pods["sans-image"] = {"containers": [container(image=None)]}
    pods["sans-requests"] = {"containers": [container(resources={})]}
    pods["requests-cpu-seul"] = {"containers": [container(resources={"requests": {"cpu": "1m"}})]}
    pods["sans-nom"] = {"containers": [container(name=None, securityContext=sc(privileged=True))]}
    pods["sans-sc"] = {"containers": [container(securityContext=None)]}
    pods["hostport"] = {"containers": [container(ports=[{"containerPort": 1, "hostPort": 80}, {"containerPort": 2}])]}
    pods["ctr-apparmor"] = {"containers": [container(securityContext=sc(appArmorProfile={"type": "Unconfined"}))]}
    pods["ctr-seccomp-unconf"] = {"containers": [container(securityContext=sc(seccompProfile={"type": "Unconfined"}))]}
    pods["ctr-seccomp-localhost"] = {"containers": [container(securityContext=sc(seccompProfile={"type": "Localhost"}))]}
    pods["ctr-seccomp-absent"] = {"containers": [container(securityContext=sc(seccompProfile=None))]}
    pods["ctr-seccomp-type-autre"] = {"containers": [container(securityContext=sc(seccompProfile={"type": "Foo"}))]}
    adds = {"net-bind": ["NET_BIND_SERVICE"], "sys-admin": ["SYS_ADMIN"], "mixte": ["CHOWN", "NET_ADMIN", "SYS_ADMIN"],
            "baseline-seul": ["CHOWN"], "vide": []}
    for cname, add in adds.items():
        caps = {"drop": ["ALL"], "add": add}
        pods[f"caps-add-{cname}"] = {"containers": [container(securityContext=sc(capabilities=caps))]}
    pods["caps-drop-minuscule"] = {"containers": [container(securityContext=sc(capabilities={"drop": ["all"]}))]}
    pods["caps-sans-drop"] = {"containers": [container(securityContext=sc(capabilities={}))]}
    pods["ape-true"] = {"containers": [container(securityContext=sc(allowPrivilegeEscalation=True))]}
    pods["ape-absent"] = {"containers": [container(securityContext=sc(allowPrivilegeEscalation=None))]}
    pods["nonroot-false"] = {"containers": [container(securityContext=sc(runAsNonRoot=False))]}
    pods["nonroot-absent"] = {"containers": [container(securityContext=sc(runAsNonRoot=None))]}
    pods["nombreux-ecarts"] = {
        "hostNetwork": True,
        "containers": [container(securityContext={"privileged": True}),
                       container(name="d", image="y", securityContext={"capabilities": {"add": ["SYS_ADMIN"]}})],
        "volumes": [{"name": "h", "hostPath": {}}, {"name": "n", "nfs": {}}]}
    return pods


def psa_objects():
    objs = {}
    for pname, ps in psa_pods().items():
        objs[f"Pod/{pname}"] = {"kind": "Pod", "spec": ps}
        objs[f"Deployment/{pname}"] = {"kind": "Deployment", "spec": {"template": {"spec": ps}}}
        objs[f"CronJob/{pname}"] = {"kind": "CronJob", "spec": {"jobTemplate": {"spec": {"template": {"spec": ps}}}}}
    for kind in ("StatefulSet", "DaemonSet", "ReplicaSet", "Job"):
        objs[f"{kind}/ok"] = {"kind": kind, "spec": {"template": {"spec": psa_pods()["nombreux-ecarts"]}}}
    objs["ConfigMap"] = {"kind": "ConfigMap"}
    objs["Deployment/sans-spec"] = {"kind": "Deployment"}
    objs["CronJob/sans-spec"] = {"kind": "CronJob", "spec": {}}
    objs["Service"] = {"kind": "Service", "spec": {"template": {"spec": psa_pods()["nombreux-ecarts"]}}}
    return objs


def run_psa(mod, o, level):
    errs, warns = mod.check(copy.deepcopy(o), level)
    return {"errs": errs, "warns": warns}


def lab_o_list_cases():
    """Variantes de clusters/oke/lab-o-apps.yaml (O5, T-502) : `ok` conforme, les autres ont un écart."""
    return {
        "ok": [{"app": "w"}],
        "vide": [],
        "absente": None,
        "objet": {"app": "w"},
        "texte": "w",
        "app-k3d": [{"app": "w"}, {"app": "k3dapp"}],
        "app-sans-generated": [{"app": "w"}, {"app": "fantome"}],
        "doublon": [{"app": "w"}, {"app": "w"}],
        "remontee": [{"app": "../../../../platform"}],
        "chemin": [{"app": "w/sub"}],
        "gabarit": [{"app": "{{.path.path}}"}],
        "majuscules": [{"app": "W"}], "nombre": [{"app": 7}],
        "cle-en-plus": [{"app": "w", "path": "platform"}],
        "cle-autre": [{"name": "w"}],
        "entree-texte": ["w"],
    }


# --- production du gel -------------------------------------------------------------------------------------
def build(mod_guard=GUARD, mod_psa=PSA):
    out = {"check_projects": {}, "check_apps": {}, "check_appset": {}, "lab_o_list": {}, "synced": {},
           "check_synced": {}, "oke_apps": {}, "psa_check": {}}
    for cid, p in projects_cases():
        out["check_projects"][cid] = run_projects(mod_guard, p)
    for cid, rel, o in apps_cases():
        out["check_apps"][cid] = run_apps(mod_guard, rel, o)
    pre = GUARD.APPS_PATH + "/projects/"
    tree = {f"{pre}{a}/x.yaml": [] for a in ("w", "k3dapp", "autre")}
    for sid, o in appset_specs().items():
        for rel in (f"{A}/apps/lab-apps.yaml", "platform/x.yaml"):
            out["check_appset"][f"{sid}/{rel}"] = run_appset(mod_guard, rel, o, tree)
    for lid, lst in lab_o_list_cases().items():
        g = mod_guard.Guard(ROOT)
        g.files, g.lab_o_list, g.oke_apps = tree, lst, (lambda: {"w"})
        g.rule_o5_list()
        out["lab_o_list"][lid] = {"errs": g.errs, "files": sorted(g.appset_files(None))}
    for cid, files, o in synced_cases():
        out["synced"][cid] = run_synced(mod_guard, files, o)
    for pid, spec in project_specs().items():
        for oid, o in synced_objects().items():
            out["check_synced"][f"{pid}/{oid}"] = run_check_synced(mod_guard, {"f.yaml": [o]}, "lab-x", spec)
    for cid, files in oke_files_cases().items():
        out["oke_apps"][cid] = run_oke(mod_guard, files)
    for oid, o in psa_objects().items():
        for level in ("restricted", "baseline"):
            out["psa_check"][f"{level}/{oid}"] = run_psa(mod_psa, o, level)
    return out


if __name__ == "__main__":
    json.dump(build(), sys.stdout, ensure_ascii=False, indent=0, sort_keys=True)
    sys.stdout.write("\n")
