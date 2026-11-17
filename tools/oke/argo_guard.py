#!/usr/bin/env python3
"""Contrôle STATIQUE des règles Argo du labo (revues B2 et PR #8 P1), là où l'AppProject ne peut pas agir.

Usage : python3 -I tools/oke/argo_guard.py [racine du dépôt]
Arbre contrôlé : platform/, generated/, apps/ (tout chemin qu'une Application du dépôt peut synchroniser ;
les fichiers de tests/ ne sont jamais une source Argo, ce que la règle A3 impose). Sans cluster.
Séparation PAR SOURCE (flux A2, docs/ARGO-ESCALATION.md) : lab-root (Application), lab-platform
(platform/**), lab-apps (generated/namespaces/default), lab-authz (platform/authz), default verrouillé.
Refuse :
  A1. une Application hors platform/install/argocd/apps/ (seule exception : l'Application racine
      platform/install/argocd/root-application.yaml, nom lab-root, projet lab-root, chemin apps/) ;
  A2. une Application dont spec.project ∉ {lab-platform, lab-apps, lab-authz, lab-root} (donc jamais
      `default`) ; dans apps/, jamais lab-root ; lab-authz réservé à l'Application lab-authz (chemin
      platform/authz), lab-apps à l'Application lab-apps (chemin generated/namespaces/default) ;
  A3. une Application `lab-platform` dont le chemin n'est pas sous platform/, ou vise
      platform/install/argocd/ ou platform/authz/ ; toute source multiple, Helm, plugin ou kustomize ;
  A4. une synchro `automated` sur un projet lab-authz ou lab-platform (synchro MANUELLE, flux A2) ;
  P1. un AppProject hors des fichiers de bootstrap (project-lab.yaml : lab-platform, lab-apps, lab-authz,
      lab-root ; project-default-locked.yaml : default) ; le projet `default` non verrouillé (listes
      vides, blacklist */*) ;
  P2. une whitelist `*` (group, kind ou name), un dépôt source ou une destination `*`, une entrée
      cluster-scoped sans `name` ; lab-root autre que « Application dans lab-argocd » ; Application ou
      AppProject dans les whitelists hors lab-root ; lab-apps avec un kind cluster-scoped, une destination
      autre que `default` ou un kind namespacé hors des kinds OpenChoreo applicatifs ;
  P3. lab-authz ou lab-platform sans sa fenêtre `deny` permanente (schedule `* * * * *`, 24h,
      applications `*`, manualSync: true), ou avec une fenêtre `allow` ;
  G1. sous generated/namespaces/ un kind hors des kinds applicatifs de lab-apps ; sous generated/catalog/
      un kind hors backstage.io ; ailleurs sous generated/, tout fichier YAML ;
  Z1. un kind authz OpenChoreo (AuthzRole, AuthzRoleBinding, ClusterAuthzRole*) hors platform/authz/, et
      dans platform/authz/ tout autre kind ou un nom hors `lab-*` ;
  S1. dans les fichiers qu'une Application lab-platform ou lab-apps synchronise : un objet cluster-scoped
      absent (kind ET nom) de clusterResourceWhitelist de SON projet, ou un kind namespacé hors whitelist /
      en blacklist ;
  S2. une NetworkPolicy synchronisée hors de la liste nommée de lab-pg, ou avec une règle « tout ouvrir »
      (règle sans from/to, namespaceSelector vide, 0.0.0.0/0) (revue A1) ;
  S3. le Namespace lab-pg sans ses labels PSA restricted / part-of / egress-isolated (revue A2) ;
  K1. un kustomization.yaml (Argo le rendrait avec kustomize : bases distantes, chemins ../).
Sortie : une ligne par écart ; code 1 si au moins un écart, 2 si un YAML est illisible (échec fermé).
Ne remplace pas la revue (CODEOWNERS, docs/CI-PLATFORM-CHECKS.md).
"""
import fnmatch
import pathlib
import sys

import yaml

SCAN = ("platform", "generated", "apps")
ARGO = "platform/install/argocd"
ROOT_APP = f"{ARGO}/root-application.yaml"
LAB_PROJECTS = ("lab-platform", "lab-apps", "lab-authz", "lab-root")
PROJECT_FILES = {f"{ARGO}/project-lab.yaml": set(LAB_PROJECTS),
                 f"{ARGO}/project-default-locked.yaml": {"default"}}
ALLOWED_PROJECTS = set(LAB_PROJECTS)
CHILD_PROJECTS = {"lab-platform", "lab-apps", "lab-authz"}
SYNC_PROJECTS = ("lab-platform", "lab-apps")  # projets dont les objets synchronisés sont contrôlés (S1)
APPS_PATH = "generated/namespaces/default"
# Kinds OpenChoreo applicatifs (sortie de tools/appgen) : seuls admis par lab-apps et sous generated/namespaces.
APP_KINDS = {"Project", "Component", "ComponentRelease", "Workload", "ReleaseBinding", "ProjectReleaseBinding",
             "Resource", "ResourceReleaseBinding", "SecretReference"}
MANUAL_PROJECTS = ("lab-platform", "lab-authz")  # projets PRIVILÉGIÉS : synchro manuelle forcée (P3, A4)
DENY_WINDOW = {"kind": "deny", "schedule": "* * * * *", "duration": "24h", "applications": ["*"],
                "manualSync": True}
AUTHZ_KINDS = {"AuthzRole", "AuthzRoleBinding", "ClusterAuthzRole", "ClusterAuthzRoleBinding"}
# Kinds cluster-scoped connus. Un kind inconnu est traité comme namespacé : il doit alors figurer
# explicitement dans namespaceResourceWhitelist (aucun `*`), donc il est refusé par défaut.
CLUSTER_KINDS = {"Namespace", "ValidatingAdmissionPolicy", "ValidatingAdmissionPolicyBinding",
                 "CustomResourceDefinition", "ClusterRole", "ClusterRoleBinding", "APIService",
                 "MutatingWebhookConfiguration", "ValidatingWebhookConfiguration", "PersistentVolume",
                 "StorageClass", "PriorityClass", "RuntimeClass", "IngressClass", "CSIDriver",
                 "MutatingAdmissionPolicy", "MutatingAdmissionPolicyBinding", "ClusterComponentType",
                 "ClusterProjectType", "ClusterResourceType", "ClusterTrait", "ClusterDataPlane",
                 "ClusterWorkflow", "ClusterAuthzRole", "ClusterAuthzRoleBinding", "ClusterSecretStore",
                 "ClusterIssuer", "GatewayClass", "CiliumClusterwideNetworkPolicy", "ClusterExternalSecret",
                 "ClusterGenerator", "ClusterPushSecret"}
# NetworkPolicy admises (revue A1) : celles de platform/data/lab-pg-namespace.yaml, par nom.
ALLOWED_NP = {("lab-pg", n) for n in ("default-deny", "allow-intra-dns-operator", "allow-pg-clients",
                                      "allow-apiserver")}
LAB_PG_LABELS = {"app.kubernetes.io/part-of": "openchoreo-lab",
                 "platform.smadja.dev/egress-isolated": "true",
                 "pod-security.kubernetes.io/enforce": "restricted"}


class Loader(yaml.SafeLoader):
    """SafeLoader qui accepte les tags inconnus (blueprints Authentik `!Find`...) sans les exécuter."""


def _any_tag(loader, _suffix, node):
    if isinstance(node, yaml.MappingNode):
        return loader.construct_mapping(node)
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    return loader.construct_scalar(node)


Loader.add_multi_constructor("!", _any_tag)


class Guard:
    def __init__(self, root):
        self.root = root
        self.errs = []
        self.files = {}  # chemin relatif -> liste d'objets

    def err(self, rel, msg):
        self.errs.append(f"{rel}: {msg}")

    def load(self):
        bad = 0
        for top in SCAN:
            base = self.root / top
            if not base.is_dir():
                continue
            for f in sorted(base.rglob("*")):
                if not f.is_file() or f.suffix not in (".yaml", ".yml"):
                    continue
                rel = str(f.relative_to(self.root))
                if f.name in ("kustomization.yaml", "kustomization.yml"):
                    self.err(rel, "K1 kustomization interdit (rendu kustomize par Argo)")
                try:
                    with open(f, encoding="utf-8") as fh:
                        objs = [d for d in yaml.load_all(fh, Loader=Loader) if isinstance(d, dict)]
                except yaml.YAMLError as e:
                    print(f"ILLISIBLE {rel}: {e}".splitlines()[0])
                    bad += 1
                    continue
                self.files[rel] = [d for d in objs if d.get("kind")]
        return bad

    def objects(self, kind=None):
        for rel, objs in self.files.items():
            for d in objs:
                if kind is None or d.get("kind") in kind:
                    yield rel, d

    # --- AppProject -----------------------------------------------------------------------------------
    def projects(self):
        projs = {}
        for rel, d in self.objects({"AppProject"}):
            name = (d.get("metadata") or {}).get("name")
            if name not in PROJECT_FILES.get(rel, set()):
                self.err(rel, f"P1 AppProject '{name}' hors des fichiers de bootstrap ({', '.join(PROJECT_FILES)})")
                continue
            if name in projs:
                self.err(rel, f"P1 AppProject '{name}' déclaré deux fois")
            projs[name] = d.get("spec") or {}
        for name in (*LAB_PROJECTS, "default"):
            if name not in projs:
                self.err(ARGO, f"P1 AppProject '{name}' absent")
        return projs

    def check_projects(self, projs):
        rel = f"{ARGO}/project-lab.yaml"
        d = projs.get("default")
        if d is not None:
            locked = all(not d.get(k) for k in ("sourceRepos", "destinations", "sourceNamespaces",
                                                 "clusterResourceWhitelist", "namespaceResourceWhitelist"))
            for k in ("clusterResourceBlacklist", "namespaceResourceBlacklist"):
                locked = locked and any(r.get("group") == "*" and r.get("kind") == "*" for r in d.get(k) or [])
            if not locked:
                self.err(f"{ARGO}/project-default-locked.yaml", "P1 projet default non verrouillé "
                         "(sourceRepos/destinations/whitelists vides et blacklists */* exigés)")
        for name in LAB_PROJECTS:
            s = projs.get(name)
            if s is None:
                continue
            for repo in s.get("sourceRepos") or []:
                if "*" in repo:
                    self.err(rel, f"P2 {name} : sourceRepos '{repo}' joker")
            for dst in s.get("destinations") or []:
                if "*" in str(dst.get("server", "")) or "*" in str(dst.get("namespace", "")) or "*" in str(dst.get("name", "")):
                    self.err(rel, f"P2 {name} : destination joker {dst}")
            if s.get("sourceNamespaces"):
                self.err(rel, f"P2 {name} : sourceNamespaces interdit")
            for key in ("clusterResourceWhitelist", "namespaceResourceWhitelist"):
                for r in s.get(key) or []:
                    if r.get("group") == "*" or r.get("kind") == "*" or r.get("name") == "*":
                        self.err(rel, f"P2 {name} : {key} joker {r}")
                    if key == "clusterResourceWhitelist" and not r.get("name"):
                        self.err(rel, f"P2 {name} : {key} sans nom {r}")
                    if r.get("kind") in ("Application", "AppProject", "ApplicationSet") and name != "lab-root":
                        self.err(rel, f"P2 {name} : {r.get('kind')} en whitelist (réservé à lab-root)")
        root = projs.get("lab-root")
        if root is not None:
            nw = root.get("namespaceResourceWhitelist") or []
            dst = root.get("destinations") or []
            if root.get("clusterResourceWhitelist") or nw != [{"group": "argoproj.io", "kind": "Application"}] \
                    or [x.get("namespace") for x in dst] != ["lab-argocd"]:
                self.err(rel, "P2 lab-root : seul kind Application dans lab-argocd admis")
        authz = projs.get("lab-authz")
        if authz is not None:
            for r in authz.get("clusterResourceWhitelist") or []:
                if r.get("kind") not in AUTHZ_KINDS or not str(r.get("name", "")).startswith("lab-"):
                    self.err(rel, f"P2 lab-authz : whitelist hors authz lab-* {r}")
            if authz.get("namespaceResourceWhitelist") or not match(authz.get("namespaceResourceBlacklist") or [],
                                                                    "x", "y"):
                self.err(rel, "P2 lab-authz : aucun kind namespacé admis (blacklist */* exigée)")
        for name in MANUAL_PROJECTS:
            wins = (projs.get(name) or {}).get("syncWindows") or []
            if any(w.get("kind") == "allow" for w in wins) or not any(
                    all(w.get(k) == v for k, v in DENY_WINDOW.items()) for w in wins):
                self.err(rel, f"P3 {name} : fenêtre deny permanente exigée {DENY_WINDOW} (aucune allow)")
        apps_p = projs.get("lab-apps")
        if apps_p is not None:
            if apps_p.get("clusterResourceWhitelist") or apps_p.get("clusterResourceWhitelist") is None:
                self.err(rel, "P2 lab-apps : clusterResourceWhitelist doit être POSÉE vide (aucun kind cluster-scoped)")
            nw = apps_p.get("namespaceResourceWhitelist") or []
            if not nw or any(r.get("group") != "openchoreo.dev" or r.get("kind") not in APP_KINDS or "name" in r
                             for r in nw):
                self.err(rel, f"P2 lab-apps : namespaceResourceWhitelist limitée aux kinds {sorted(APP_KINDS)}")
            if [(x.get("server"), x.get("namespace")) for x in apps_p.get("destinations") or []] != \
                    [("https://kubernetes.default.svc", "default")]:
                self.err(rel, "P2 lab-apps : seule destination admise : namespace default du cluster local")

    # --- Application ----------------------------------------------------------------------------------
    def check_apps(self):
        apps = []
        for rel, d in self.objects({"Application", "ApplicationSet"}):
            spec = d.get("spec") or {}
            name = (d.get("metadata") or {}).get("name")
            proj = spec.get("project")
            if d["kind"] == "ApplicationSet":
                self.err(rel, "A1 ApplicationSet interdit")
                continue
            in_apps = str(pathlib.PurePosixPath(rel).parent) == f"{ARGO}/apps"
            if rel == ROOT_APP:
                src = spec.get("source") or {}
                if name != "lab-root" or proj != "lab-root" or src.get("path") != f"{ARGO}/apps" \
                        or (src.get("directory") or {}).get("recurse"):
                    self.err(rel, "A1 l'Application racine doit être lab-root, projet lab-root, chemin "
                                  f"{ARGO}/apps sans récursion")
            elif not in_apps:
                self.err(rel, f"A1 Application '{name}' hors {ARGO}/apps/")
            if proj not in ALLOWED_PROJECTS:
                self.err(rel, f"A2 Application '{name}' : projet '{proj}' interdit (admis : {sorted(ALLOWED_PROJECTS)})")
            if in_apps and proj not in CHILD_PROJECTS:
                self.err(rel, f"A2 Application '{name}' : projet '{proj}' interdit dans apps/ "
                              f"({', '.join(sorted(CHILD_PROJECTS))})")
            if rel != ROOT_APP and proj == "lab-root":
                self.err(rel, f"A2 Application '{name}' : projet lab-root réservé à {ROOT_APP}")
            if "sources" in spec:
                self.err(rel, f"A3 Application '{name}' : sources multiples interdites")
            src = spec.get("source") or {}
            for k in ("chart", "helm", "kustomize", "plugin"):
                if k in src:
                    self.err(rel, f"A3 Application '{name}' : source.{k} interdit (répertoire YAML seulement)")
            path = str(src.get("path", ""))
            if proj == "lab-authz":
                if name != "lab-authz" or path != "platform/authz" or (src.get("directory") or {}).get("recurse"):
                    self.err(rel, "A2 projet lab-authz réservé à l'Application lab-authz (chemin platform/authz)")
            if proj in MANUAL_PROJECTS and (spec.get("syncPolicy") or {}).get("automated") is not None:
                self.err(rel, f"A4 Application '{name}' ({proj}) : synchro automated interdite (sync MANUELLE)")
            if proj == "lab-apps" and (name != "lab-apps" or not (path == APPS_PATH or path.startswith(APPS_PATH + "/projects/"))):
                self.err(rel, f"A2 projet lab-apps réservé à l'Application lab-apps (chemin {APPS_PATH})")
            if proj == "lab-platform":
                norm = pathlib.PurePosixPath(path)
                if ".." in norm.parts or not (path == "platform" or path.startswith("platform/")) \
                        or path.startswith((ARGO, "platform/authz")):
                    self.err(rel, f"A3 Application '{name}' : chemin '{path}' interdit au projet lab-platform")
            apps.append((rel, d))
        return apps

    def synced(self, apps):
        out = {p: set() for p in SYNC_PROJECTS}
        for _rel, a in apps:
            spec = a.get("spec") or {}
            src = spec.get("source") or {}
            if spec.get("project") not in SYNC_PROJECTS or "path" not in src:
                continue
            base = str(src["path"]).rstrip("/")
            dr = src.get("directory") or {}
            pats = expand_include(dr.get("include") or "*.yaml") if dr.get("include") else ["*.yaml", "*.yml", "*.json"]
            for rel in self.files:
                if not rel.startswith(base + "/"):
                    continue
                sub = rel[len(base) + 1:]
                if not dr.get("recurse") and "/" in sub:
                    continue
                if any(fnmatch.fnmatch(sub, p) for p in pats):
                    out[spec["project"]].add(rel)
        return out

    # --- Authz ----------------------------------------------------------------------------------------
    def check_authz(self):
        for rel, d in self.objects():
            name = str((d.get("metadata") or {}).get("name", ""))
            if rel.startswith("platform/authz/"):
                if d["kind"] not in AUTHZ_KINDS or not name.startswith("lab-"):
                    self.err(rel, f"Z1 {d['kind']}/{name} : platform/authz/ n'admet que des kinds authz nommés lab-*")
            elif d["kind"] in AUTHZ_KINDS:
                self.err(rel, f"Z1 {d['kind']}/{name} hors platform/authz/")

    # --- generated/ : sortie de tools/appgen seulement --------------------------------------------------
    def check_generated(self):
        for rel, d in self.objects():
            if not rel.startswith("generated/"):
                continue
            g, k = group_of(d.get("apiVersion", "")), d["kind"]
            n = (d.get("metadata") or {}).get("name")
            if rel.startswith("generated/namespaces/"):
                if g != "openchoreo.dev" or k not in APP_KINDS:
                    self.err(rel, f"G1 {k}/{n} : generated/namespaces/ n'admet que les kinds {sorted(APP_KINDS)}")
            elif rel.startswith("generated/catalog/"):
                if g != "backstage.io":
                    self.err(rel, f"G1 {k}/{n} : generated/catalog/ n'admet que backstage.io")
            else:
                self.err(rel, f"G1 {k}/{n} : chemin generated/ inconnu (namespaces/ ou catalog/)")

    # --- Objets synchronisés par lab-platform / lab-apps ----------------------------------------------
    def check_synced(self, synced, proj_name, lab):
        cw = lab.get("clusterResourceWhitelist") or []
        nw = lab.get("namespaceResourceWhitelist") or []
        nb = lab.get("namespaceResourceBlacklist") or []
        cb = lab.get("clusterResourceBlacklist") or []
        for rel in sorted(synced):
            for d in self.files[rel]:
                g, k = group_of(d.get("apiVersion", "")), d["kind"]
                md = d.get("metadata") or {}
                n, ns = str(md.get("name", "")), md.get("namespace")
                if k in CLUSTER_KINDS:
                    if not match(cw, g, k, n) or match(cb, g, k, n):
                        self.err(rel, f"S1 {k}/{n} cluster-scoped absent de clusterResourceWhitelist ({proj_name})")
                elif not nw or not match(nw, g, k) or match(nb, g, k):
                    self.err(rel, f"S1 {k}/{n} namespacé non autorisé par l'AppProject {proj_name}")
                if k == "NetworkPolicy":
                    self.check_np(rel, ns, n, d.get("spec") or {})
                if k == "Namespace" and n == "lab-pg":
                    labels = md.get("labels") or {}
                    for lk, lv in LAB_PG_LABELS.items():
                        if labels.get(lk) != lv:
                            self.err(rel, f"S3 Namespace lab-pg : label {lk}={lv} exigé (trouvé {labels.get(lk)!r})")
                    for lk in ("pod-security.kubernetes.io/warn", "pod-security.kubernetes.io/audit"):
                        if labels.get(lk) not in (None, "restricted"):
                            self.err(rel, f"S3 Namespace lab-pg : {lk} doit rester restricted")

    def check_np(self, rel, ns, name, spec):
        if (ns, name) not in ALLOWED_NP:
            self.err(rel, f"S2 NetworkPolicy {ns}/{name} hors liste nommée {sorted(ALLOWED_NP)}")
        for direction, peer_key in (("ingress", "from"), ("egress", "to")):
            for rule in spec.get(direction) or []:
                peers = (rule or {}).get(peer_key)
                if not peers:
                    self.err(rel, f"S2 NetworkPolicy {ns}/{name} : règle {direction} sans {peer_key} (tout ouvert)")
                    continue
                for p in peers:
                    if "namespaceSelector" in p and not p["namespaceSelector"]:
                        self.err(rel, f"S2 NetworkPolicy {ns}/{name} : namespaceSelector vide (tous namespaces)")
                    cidr = (p.get("ipBlock") or {}).get("cidr", "")
                    if cidr.endswith("/0"):
                        self.err(rel, f"S2 NetworkPolicy {ns}/{name} : ipBlock {cidr} (tout Internet)")


def group_of(api_version):
    return api_version.split("/")[0] if "/" in api_version else ""


def expand_include(pattern):
    """Développe un include Argo `{a,b,c}` en liste de motifs glob."""
    p = str(pattern).strip()
    if p.startswith("{") and p.endswith("}"):
        return [x.strip() for x in p[1:-1].split(",")]
    return [p]


def match(rules, group, kind, name=None):
    for r in rules:
        if r.get("group") not in (group, "*") or r.get("kind") not in (kind, "*"):
            continue
        if name is None or "name" not in r or fnmatch.fnmatch(name, r["name"]):
            return True
    return False


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    g = Guard(root)
    if g.load():
        print("argo_guard : YAML illisible : échec fermé")
        return 2
    projs = g.projects()
    g.check_projects(projs)
    apps = g.check_apps()
    g.check_authz()
    g.check_generated()
    synced = g.synced(apps)
    for p in SYNC_PROJECTS:
        g.check_synced(synced[p], p, projs.get(p) or {})
    for e in g.errs:
        print("ÉCART", e)
    counts = ", ".join(f"{len(synced[p])} par {p}" for p in SYNC_PROJECTS)
    print(f"argo_guard : {len(g.files)} fichier(s) lus, {len(apps)} Application(s), fichier(s) synchronisé(s) : "
          f"{counts}, {len(g.errs)} écart(s)")
    return 1 if g.errs else 0


if __name__ == "__main__":
    sys.exit(main())
