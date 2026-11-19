#!/usr/bin/env python3
"""Contrôle STATIQUE des règles Argo du labo (revues B2 et PR #8 P1), là où l'AppProject ne peut pas agir.

Usage : python3 -I tools/oke/argo_guard.py [racine du dépôt]
Arbre contrôlé : platform/, generated/, apps/ (tout chemin qu'une Application du dépôt peut synchroniser ;
les fichiers de tests/ ne sont jamais une source Argo, ce que la règle A3 impose). Sans cluster.
Séparation PAR SOURCE (flux A2, docs/ARGO-ESCALATION.md) : lab-root (Application), lab-platform
(platform/**), lab-o (generated/namespaces/default), lab-authz (platform/authz), default verrouillé.
Refuse :
  A1. une Application hors platform/install/argocd/apps/ (sauf la racine root-application.yaml : lab-root, chemin apps/) ;
  A2. une Application dont spec.project ∉ {lab-platform, lab-o, lab-authz, lab-root, lab-k-root} (donc jamais
      `default` ni `lab-k`) ; dans apps/, jamais lab-root ; lab-authz réservé à l'Application lab-authz (chemin
      platform/authz), lab-o à l'ApplicationSet lab-o (aucune Application écrite à la main) ;
  A3. une Application `lab-platform` hors platform/, ou visant platform/install/argocd/ ou platform/authz/ ; toute
      source multiple, Helm, plugin ou kustomize ;
  O1-O5 (ApplicationSet lab-o, T-491, T-502) : un seul, sous apps/ ; missingkey=error, preserveResourcesOnDeletion ;
      UN générateur git `files` sur la SEULE liste clusters/oke/lab-o-apps.yaml (dépôt du labo, main) ; modèle :
      projet et destination LITTÉRAUX, chemin projects/{{.app}}, ni templatePatch ; O5 : chaque entrée de la liste
      est `{app: <nom DNS>}`, unique, générée sous projects/<nom> et OKE stateless ; A3 : `sources[]` refusé ;
      A2 : aucune Application écrite à la main dans le projet lab-o ;
  A4. une synchro `automated` sur un projet lab-authz ou lab-platform (synchro MANUELLE, flux A2) ;
  P1. un AppProject hors des fichiers de bootstrap (project-lab.yaml : lab-platform, lab-o, lab-authz, lab-root,
      lab-k, lab-k-root ; project-default-locked.yaml : default) ; `default` non verrouillé (listes vides, */*) ;
  P2. une whitelist `*` (group, kind ou name), un dépôt source ou une destination `*`, une entrée
      cluster-scoped sans `name` ; lab-root autre que « Application et ApplicationSet dans lab-argocd » ; Application ou
      AppProject dans les whitelists hors lab-root ; lab-o avec un kind cluster-scoped, une destination
      autre que `default` ou un kind namespacé hors des kinds OpenChoreo applicatifs ;
  P3. lab-authz ou lab-platform sans fenêtre `deny` permanente (`* * * * *`, 24h, `*`, manualSync), ou avec `allow` ;
  G1. sous generated/namespaces/ un kind hors des kinds applicatifs de lab-o ; sous generated/catalog/ un kind
      hors backstage.io ; ailleurs sous generated/, tout fichier YAML ;
  Z1. un kind authz OpenChoreo (AuthzRole, AuthzRoleBinding, ClusterAuthzRole*) hors platform/authz/, et dans
      platform/authz/ tout autre kind ou un nom hors `lab-*` ;
  S1. dans les fichiers qu'une Application lab-platform ou lab-o synchronise : un objet cluster-scoped absent
      (kind ET nom) de clusterResourceWhitelist de SON projet, ou un kind namespacé hors whitelist / en blacklist ;
  S2. une NetworkPolicy synchronisée hors des listes nommées (lab-pg, TUNNEL), ou avec une règle « tout ouvrir »
      (règle sans from/to, namespaceSelector vide, 0.0.0.0/0) (revue A1) ; S4. Deployment ou CNP hors TUNNEL ;
  S3. le Namespace lab-pg ou lab-tunnel sans ses labels PSA restricted / part-of / egress-isolated (revue A2) ;
  K1. un kustomization.yaml (rendu kustomize : bases distantes, ../) ; L1-L4 (bras K, T-495) : argo_guard_k.py.
Sortie : une ligne par écart ; code 1 si au moins un écart, 2 si un YAML est illisible (échec fermé).
Ne remplace pas la revue (CODEOWNERS, docs/CI-PLATFORM-CHECKS.md).
"""
import fnmatch
import pathlib
import re
import sys

import yaml

sys.path.append(str(pathlib.Path(__file__).resolve().parent))  # python3 -I : dossier du script absent de sys.path
from argo_guard_k import LabKRules, argo_kind_allowed, k_destination_allowed

SCAN = ("platform", "generated", "apps")
ARGO = "platform/install/argocd"
ROOT_APP = f"{ARGO}/root-application.yaml"
LAB_PROJECTS = ("lab-platform", "lab-o", "lab-authz", "lab-root", "lab-k", "lab-k-root")
PROJECT_FILES = {f"{ARGO}/project-lab.yaml": set(LAB_PROJECTS), f"{ARGO}/project-default-locked.yaml": {"default"}}
ALLOWED_PROJECTS, CHILD_PROJECTS = set(LAB_PROJECTS) - {"lab-k"}, set(LAB_PROJECTS) - {"lab-k", "lab-root"}  # L4
SYNC_PROJECTS = ("lab-platform", "lab-o")  # projets dont les objets synchronisés sont contrôlés (S1)
APPS_PATH = "generated/namespaces/default"
APP_PATH_TPL = APPS_PATH + "/projects/{{.app}}"  # chemin source du modèle lab-o (O4)
LAB_O_LIST = "clusters/oke/lab-o-apps.yaml"  # apps OKE de lab-o (T-502) : liste `- app: <nom>`, générateur git files
APP_NAME = re.compile(r"[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?")  # nom d'app : label DNS (ni `/`, ni `.`, ni gabarit)
REPO_URLS = {"https://github.com/platform-zephyr/openchoreo-lab", "https://github.com/platform-zephyr/openchoreo-lab.git"}
# Kinds OpenChoreo applicatifs (sortie de tools/appgen) : seuls admis par lab-o et sous generated/namespaces.
APP_KINDS = {"Project", "Component", "ComponentRelease", "Workload", "ReleaseBinding", "ProjectReleaseBinding",
             "Resource", "ResourceReleaseBinding", "SecretReference"}
MANUAL_PROJECTS = ("lab-platform", "lab-authz", "lab-k-root")  # synchro manuelle forcée (P3, A4)
DENY_WINDOW = {"kind": "deny", "schedule": "* * * * *", "duration": "24h", "applications": ["*"], "manualSync": True}
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
TUNNEL = {("NetworkPolicy", "lab-tunnel", n) for n in ("lab-default-deny", "lab-tunnel-egress-dns-api")} | {("Deployment", "lab-tunnel",
          "cloudflared"), ("CiliumNetworkPolicy", "lab-tunnel", "lab-tunnel-egress-edge"), ("NetworkPolicy", "openchoreo-control-plane", "lab-allow-tunnel-to-api")}  # T-006
LAB_PG_LABELS = {"app.kubernetes.io/part-of": "openchoreo-lab",
                 "platform.smadja.dev/egress-isolated": "true",
                 "pod-security.kubernetes.io/enforce": "restricted"}


class Loader(getattr(yaml, "CSafeLoader", yaml.SafeLoader)):
    """SafeLoader (CSafeLoader si libyaml est disponible) qui accepte les tags inconnus (blueprints Authentik `!Find`...) sans les exécuter."""


def _any_tag(loader, _suffix, node):
    if isinstance(node, yaml.MappingNode):
        return loader.construct_mapping(node)
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    return loader.construct_scalar(node)


Loader.add_multi_constructor("!", _any_tag)


class Guard(LabKRules):
    def __init__(self, root):
        self.root = root
        self.errs = []
        self.appsets = []  # ApplicationSet lab-o lus (fichiers synchronisés, S1)
        self.files = {}  # chemin relatif -> liste d'objets
        self.lab_o_list = None  # contenu YAML de LAB_O_LIST (None : fichier absent)

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
        return bad + self.load_lab_o_list()

    def load_lab_o_list(self):
        """Lit LAB_O_LIST (hors SCAN : une liste, pas des objets) ; 1 si illisible (échec fermé)."""
        f = self.root / LAB_O_LIST
        if not f.is_file():
            return 0
        try:
            with open(f, encoding="utf-8") as fh:
                self.lab_o_list = yaml.load(fh, Loader=Loader)
        except yaml.YAMLError as e:
            print(f"ILLISIBLE {LAB_O_LIST}: {e}".splitlines()[0])
            return 1
        return 0

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
        """Orchestre les règles P1/P2/P3 ; l'ordre des écarts est celui de l'ancienne fonction monolithique."""
        rel = f"{ARGO}/project-lab.yaml"
        self.rule_p1_default_locked(projs.get("default"))
        for name in LAB_PROJECTS:
            s = projs.get(name)
            if s is not None:
                self.rule_p2_no_wildcards(rel, name, s)
        self.rule_p2_lab_root(rel, projs.get("lab-root"))
        self.rule_p2_lab_authz(rel, projs.get("lab-authz"))
        for name in MANUAL_PROJECTS:
            self.rule_p3_deny_window(rel, name, projs.get(name))
        self.rule_p2_lab_apps(rel, projs.get("lab-o"))
        self.check_lab_k_projects(rel, projs)

    def rule_p1_default_locked(self, d):
        """P1 : le projet `default` est verrouillé (listes vides, blacklists */*)."""
        if d is None:
            return
        locked = all(not d.get(k) for k in ("sourceRepos", "destinations", "sourceNamespaces",
                                             "clusterResourceWhitelist", "namespaceResourceWhitelist"))
        for k in ("clusterResourceBlacklist", "namespaceResourceBlacklist"):
            locked = locked and any(r.get("group") == "*" and r.get("kind") == "*" for r in d.get(k) or [])
        if not locked:
            self.err(f"{ARGO}/project-default-locked.yaml", "P1 projet default non verrouillé "
                     "(sourceRepos/destinations/whitelists vides et blacklists */* exigés)")

    def rule_p2_no_wildcards(self, rel, name, s):
        """P2 : ni dépôt, ni destination, ni whitelist à joker ; pas de sourceNamespaces."""
        self.rule_p2_source_repos(rel, name, s)
        self.rule_p2_destinations(rel, name, s)
        if s.get("sourceNamespaces"):
            self.err(rel, f"P2 {name} : sourceNamespaces interdit")
        for key in ("clusterResourceWhitelist", "namespaceResourceWhitelist"):
            for r in s.get(key) or []:
                self.rule_p2_whitelist_entry(rel, name, key, r)

    def rule_p2_source_repos(self, rel, name, s):
        for repo in s.get("sourceRepos") or []:
            if "*" in repo:
                self.err(rel, f"P2 {name} : sourceRepos '{repo}' joker")

    def rule_p2_destinations(self, rel, name, s):
        for dst in [d for d in s.get("destinations") or [] if not k_destination_allowed(name, d)]:
            if any("*" in str(dst.get(k, "")) for k in ("server", "namespace", "name")):
                self.err(rel, f"P2 {name} : destination joker {dst}")

    def rule_p2_whitelist_entry(self, rel, name, key, r):
        if r.get("group") == "*" or r.get("kind") == "*" or r.get("name") == "*":
            self.err(rel, f"P2 {name} : {key} joker {r}")
        if key == "clusterResourceWhitelist" and not r.get("name"):
            self.err(rel, f"P2 {name} : {key} sans nom {r}")
        if r.get("kind") in ("Application", "AppProject", "ApplicationSet") and not argo_kind_allowed(name, r["kind"]):
            self.err(rel, f"P2 {name} : {r.get('kind')} en whitelist (réservé à lab-root)")

    def rule_p2_lab_root(self, rel, root):
        """P2 : lab-root n'admet que les kinds Application et ApplicationSet dans lab-argocd."""
        if root is None:
            return
        nw = root.get("namespaceResourceWhitelist") or []
        dst = root.get("destinations") or []
        want = [{"group": "argoproj.io", "kind": "Application"}, {"group": "argoproj.io", "kind": "ApplicationSet"}]
        if root.get("clusterResourceWhitelist") or nw != want \
                or [x.get("namespace") for x in dst] != ["lab-argocd"]:
            self.err(rel, "P2 lab-root : seuls les kinds Application et ApplicationSet dans lab-argocd admis")

    def rule_p2_lab_authz(self, rel, authz):
        """P2 : lab-authz n'admet que des kinds authz lab-* cluster-scoped, aucun kind namespacé."""
        if authz is None:
            return
        for r in authz.get("clusterResourceWhitelist") or []:
            if r.get("kind") not in AUTHZ_KINDS or not str(r.get("name", "")).startswith("lab-"):
                self.err(rel, f"P2 lab-authz : whitelist hors authz lab-* {r}")
        if authz.get("namespaceResourceWhitelist") or not match(authz.get("namespaceResourceBlacklist") or [],
                                                                "x", "y"):
            self.err(rel, "P2 lab-authz : aucun kind namespacé admis (blacklist */* exigée)")

    def rule_p3_deny_window(self, rel, name, proj):
        """P3 : fenêtre `deny` permanente exigée, aucune `allow` (projets privilégiés)."""
        wins = (proj or {}).get("syncWindows") or []
        if any(w.get("kind") == "allow" for w in wins) or not any(
                all(w.get(k) == v for k, v in DENY_WINDOW.items()) for w in wins):
            self.err(rel, f"P3 {name} : fenêtre deny permanente exigée {DENY_WINDOW} (aucune allow)")

    def rule_p2_lab_apps(self, rel, apps_p):
        """P2 : lab-o sans kind cluster-scoped, kinds OpenChoreo applicatifs seuls, destination `default`."""
        if apps_p is None:
            return
        if apps_p.get("clusterResourceWhitelist") or apps_p.get("clusterResourceWhitelist") is None:
            self.err(rel, "P2 lab-o : clusterResourceWhitelist doit être POSÉE vide (aucun kind cluster-scoped)")
        nw = apps_p.get("namespaceResourceWhitelist") or []
        if not nw or any(r.get("group") != "openchoreo.dev" or r.get("kind") not in APP_KINDS or "name" in r
                         for r in nw):
            self.err(rel, f"P2 lab-o : namespaceResourceWhitelist limitée aux kinds {sorted(APP_KINDS)}")
        if [(x.get("server"), x.get("namespace")) for x in apps_p.get("destinations") or []] != \
                [("https://kubernetes.default.svc", "default")]:
            self.err(rel, "P2 lab-o : seule destination admise : namespace default du cluster local")

    # --- Application ----------------------------------------------------------------------------------
    def check_apps(self):
        """Orchestre les règles A1-A4 par Application ; l'ordre des écarts est celui de l'ancienne fonction."""
        apps = []
        for rel, d in self.objects({"Application", "ApplicationSet"}):
            spec = d.get("spec") or {}
            name = (d.get("metadata") or {}).get("name")
            proj = spec.get("project")
            if d["kind"] == "ApplicationSet":
                self.check_appset(rel, d)
                continue
            self.rule_a1_location(rel, name, proj, spec)
            self.rule_a2_project(rel, name, proj)
            if "sources" in spec:  # A3 : un chemin par Application (lab-o passe par l'ApplicationSet)
                self.err(rel, f"A3 Application '{name}' : sources multiples interdites")
            src = spec.get("source") or {}
            self.rule_a3_source_kinds(rel, name, src)
            self.rule_a2_authz_reserved(rel, name, proj, src)
            self.rule_a4_manual_sync(rel, name, proj, spec)
            self.rule_l3_k_root_app(rel, name, proj, spec)
            self.rule_a3_platform_path(rel, name, proj, src)
            apps.append((rel, d))
        return apps

    def rule_a1_location(self, rel, name, proj, spec):
        """A1 : Application sous apps/ ; seule exception, l'Application racine lab-root."""
        if rel == ROOT_APP:
            src = spec.get("source") or {}
            if name != "lab-root" or proj != "lab-root" or src.get("path") != f"{ARGO}/apps" \
                    or (src.get("directory") or {}).get("recurse"):
                self.err(rel, "A1 l'Application racine doit être lab-root, projet lab-root, chemin "
                              f"{ARGO}/apps sans récursion")
        elif str(pathlib.PurePosixPath(rel).parent) != f"{ARGO}/apps":
            self.err(rel, f"A1 Application '{name}' hors {ARGO}/apps/")

    def rule_a2_project(self, rel, name, proj):
        """A2 : projet admis ; apps/ jamais lab-root ; lab-root réservé à l'Application racine."""
        in_apps = str(pathlib.PurePosixPath(rel).parent) == f"{ARGO}/apps"
        if proj not in ALLOWED_PROJECTS:
            self.err(rel, f"A2 Application '{name}' : projet '{proj}' interdit (admis : {sorted(ALLOWED_PROJECTS)})")
        if in_apps and proj not in CHILD_PROJECTS:
            self.err(rel, f"A2 Application '{name}' : projet '{proj}' interdit dans apps/ "
                          f"({', '.join(sorted(CHILD_PROJECTS))})")
        if proj == "lab-o":
            self.err(rel, f"A2 Application '{name}' : projet lab-o réservé à l'ApplicationSet lab-o (T-491)")
        if rel != ROOT_APP and proj == "lab-root":
            self.err(rel, f"A2 Application '{name}' : projet lab-root réservé à {ROOT_APP}")

    def rule_a3_source_kinds(self, rel, name, src):
        """A3 : répertoire YAML seulement (ni chart, ni helm, ni kustomize, ni plugin)."""
        for k in ("chart", "helm", "kustomize", "plugin"):
            if k in src:
                self.err(rel, f"A3 Application '{name}' : source.{k} interdit (répertoire YAML seulement)")

    def rule_a2_authz_reserved(self, rel, name, proj, src):
        """A2 : le projet lab-authz est réservé à l'Application lab-authz (platform/authz, sans récursion)."""
        if proj != "lab-authz":
            return
        if name != "lab-authz" or str(src.get("path", "")) != "platform/authz" \
                or (src.get("directory") or {}).get("recurse"):
            self.err(rel, "A2 projet lab-authz réservé à l'Application lab-authz (chemin platform/authz)")

    def rule_a4_manual_sync(self, rel, name, proj, spec):
        """A4 : pas de synchro `automated` sur un projet privilégié."""
        if proj in MANUAL_PROJECTS and (spec.get("syncPolicy") or {}).get("automated") is not None:
            self.err(rel, f"A4 Application '{name}' ({proj}) : synchro automated interdite (sync MANUELLE)")

    def rule_a3_platform_path(self, rel, name, proj, src):
        """A3 : lab-platform ne vise que platform/**, hors install/argocd et authz."""
        if proj != "lab-platform":
            return
        path = str(src.get("path", ""))
        norm = pathlib.PurePosixPath(path)
        if ".." in norm.parts or not (path == "platform" or path.startswith("platform/")) \
                or path.startswith((ARGO, "platform/authz")):
            self.err(rel, f"A3 Application '{name}' : chemin '{path}' interdit au projet lab-platform")

    def oke_apps(self):
        """Apps admises à lab-o : apps/<nom>/app.yaml, cluster oke, stateless (ni volume, ni base)."""
        out = set()
        for rel, objs in self.files.items():
            parts = pathlib.PurePosixPath(rel).parts
            if len(parts) != 3 or parts[0] != "apps" or parts[2] != "app.yaml":
                continue
            for d in objs:
                s = (d.get("spec") or {}) if d.get("kind") == "App" else {}
                if s.get("cluster") == "oke" and s.get("profile") == "stateless" \
                        and "storage" not in s and "database" not in s:
                    out.add(parts[1])
        return out

    def check_appset(self, rel, d):
        """O1-O5 : l'ApplicationSet `lab-o` est le seul admis ; une Application par app, projet et destination fixes."""
        name, spec = (d.get("metadata") or {}).get("name"), d.get("spec") or {}
        if name != "lab-o" or str(pathlib.PurePosixPath(rel).parent) != f"{ARGO}/apps" or self.appsets:
            self.err(rel, f"O1 ApplicationSet '{name}' : seul `lab-o`, un exemplaire, sous {ARGO}/apps/ est admis")
        self.appsets.append(d)
        self.rule_o2_options(rel, spec)
        self.rule_o3_generator(rel, spec)
        self.rule_o4_template(rel, spec)
        self.rule_o5_list()

    def lab_o_apps(self):
        """Noms valides de LAB_O_LIST (entrées `{app: <nom DNS>}`) ; les autres sont refusées par O5."""
        items = self.lab_o_list if isinstance(self.lab_o_list, list) else []
        return [e["app"] for e in items if isinstance(e, dict) and set(e) == {"app"}
                and isinstance(e["app"], str) and APP_NAME.fullmatch(e["app"])]

    def rule_o5_list(self):
        """O5 : la liste existe ; chaque entrée est `{app: <nom DNS>}`, unique, générée et OKE stateless."""
        if not isinstance(self.lab_o_list, list):
            self.err(LAB_O_LIST, "O5 lab-o : liste absente ou invalide (attendu : une liste `- app: <nom>`)")
            return
        valid = self.lab_o_apps()
        for e in self.lab_o_list:
            if not (isinstance(e, dict) and set(e) == {"app"} and e["app"] in valid):
                self.err(LAB_O_LIST, f"O5 lab-o : entrée invalide {e} (attendu : {{app: <nom DNS>}})")
        pre, oke, seen = APPS_PATH + "/projects/", self.oke_apps(), set()
        for a in valid:
            if a in seen:
                self.err(LAB_O_LIST, f"O5 lab-o : app '{a}' listée deux fois")
            seen.add(a)
            if a not in oke:
                self.err(LAB_O_LIST, f"O5 lab-o : app '{a}' listée mais non OKE stateless "
                                     "(apps/<app>/app.yaml : cluster oke, profile stateless, sans storage ni database)")
            if not any(r.startswith(f"{pre}{a}/") for r in self.files):
                self.err(LAB_O_LIST, f"O5 lab-o : app '{a}' listée sans dossier {pre}{a}/ (sortie de tools/appgen)")

    def want(self, rel, ok, code, msg):  # exigence littérale : écart `<code> lab-o : <msg>` si `ok` est faux
        if not ok:
            self.err(rel, f"{code} lab-o : {msg}")

    def only(self, rel, code, got, allowed, what):
        """O2-O4 : aucune clé hors `allowed` (un champ inconnu pourrait réécrire le projet ou la destination)."""
        for k in sorted(set(got) - set(allowed)):
            self.err(rel, f"{code} lab-o : {what}.{k} interdit")

    def rule_o2_options(self, rel, spec):
        """O2 : goTemplate + missingkey=error (un paramètre absent échoue, jamais une valeur vide) ; preserve."""
        self.want(rel, spec.get("goTemplate") is True and "missingkey=error" in (spec.get("goTemplateOptions") or []),
                  "O2", "goTemplate: true et goTemplateOptions [missingkey=error] exigés")
        self.want(rel, (spec.get("syncPolicy") or {}).get("preserveResourcesOnDeletion") is True,
                  "O2", "syncPolicy.preserveResourcesOnDeletion: true exigé")
        self.only(rel, "O2", spec, ("goTemplate", "goTemplateOptions", "syncPolicy", "generators", "template"), "spec")

    def rule_o3_generator(self, rel, spec):
        """O3 : UN générateur git `files` sur la seule liste LAB_O_LIST, dépôt du labo, main."""
        gens = spec.get("generators")
        if not isinstance(gens, list) or len(gens) != 1 or not isinstance(gens[0], dict) \
                or set(gens[0]) != {"git"} or not isinstance(gens[0]["git"], dict):
            self.err(rel, "O3 lab-o : un seul générateur, de type git, est admis")
            return
        g = gens[0]["git"]
        self.only(rel, "O3", g, ("repoURL", "revision", "files", "requeueAfterSeconds"), "generators[0].git")
        self.want(rel, g.get("repoURL") in REPO_URLS, "O3", f"git.repoURL '{g.get('repoURL')}' hors dépôt du labo")
        self.want(rel, g.get("revision") == "main", "O3", "git.revision doit être main")
        self.want(rel, g.get("files") == [{"path": LAB_O_LIST}], "O3",
                  f"git.files doit être exactement [{{path: {LAB_O_LIST}}}] (trouvé {g.get('files')})")

    def rule_o4_template(self, rel, spec):
        """O4 : modèle d'Application : nom préfixé, projet et destination LITTÉRAUX, source = dossier de l'app seulement."""
        tpl = spec.get("template") or {}
        ts = tpl.get("spec") or {}
        self.want(rel, (tpl.get("metadata") or {}).get("name") == "lab-o-{{.app}}",
                  "O4", "template.metadata.name doit être lab-o-{{.app}}")
        self.want(rel, ts.get("project") == "lab-o", "O4", "template.spec.project doit être le littéral lab-o (jamais un paramètre)")
        self.want(rel, ts.get("destination") == {"server": "https://kubernetes.default.svc", "namespace": "default"},
                  "O4", "template.spec.destination doit être le littéral {server: https://kubernetes.default.svc, namespace: default}")
        self.only(rel, "O4", ts, ("project", "source", "destination", "syncPolicy"), "template.spec")
        self.want(rel, ((ts.get("syncPolicy") or {}).get("automated") or {}).get("prune") is not True,
                  "O4", "syncPolicy.automated.prune: true interdit (finalizers Component/Resource)")
        self.rule_o4_source(rel, ts.get("source") or {})

    def rule_o4_source(self, rel, src):
        """O4 : source = dépôt du labo, main, chemin projects/{{.app}}, répertoire YAML récursif seulement."""
        self.only(rel, "O4", src, ("repoURL", "targetRevision", "path", "directory"), "template.spec.source")
        self.want(rel, src.get("repoURL") in REPO_URLS and src.get("targetRevision") == "main",
                  "O4", "template.spec.source : dépôt du labo et targetRevision main littéraux exigés")
        self.want(rel, src.get("path") == APP_PATH_TPL, "O4", f"template.spec.source.path doit être {APP_PATH_TPL}")
        self.want(rel, src.get("directory") == {"recurse": True, "include": "*.yaml"},
                  "O4", 'template.spec.source.directory doit être {recurse: true, include: "*.yaml"}')

    def appset_files(self, _appset):
        """Fichiers synchronisés par les Applications de l'ApplicationSet lab-o : projects/<app>/**/*.yaml des apps listées."""
        pre = APPS_PATH + "/projects/"
        apps = set(self.lab_o_apps())
        return {r for r in self.files if r.startswith(pre) and r.endswith(".yaml") and r[len(pre):].split("/")[0] in apps}

    def synced(self, apps):
        """Fichiers que chaque projet contrôlé (SYNC_PROJECTS) synchronise, par Application."""
        out = {p: set() for p in SYNC_PROJECTS}
        for _rel, a in apps:
            spec = a.get("spec") or {}
            if spec.get("project") not in SYNC_PROJECTS:
                continue
            for src in source_list(spec):
                if "path" in src:
                    out[spec["project"]].update(self.files_of_source(src))
        for appset in self.appsets:
            out["lab-o"].update(self.appset_files(appset))
        return out

    def files_of_source(self, src):
        """Fichiers (chemins relatifs) qu'Argo lit pour une source `directory` (include, recurse)."""
        base = str(src["path"]).rstrip("/")
        dr = src.get("directory") or {}
        pats = expand_include(dr.get("include") or "*.yaml") if dr.get("include") else ["*.yaml", "*.yml", "*.json"]
        found = set()
        for rel in self.files:
            if not rel.startswith(base + "/"):
                continue
            sub = rel[len(base) + 1:]
            if not dr.get("recurse") and "/" in sub:
                continue
            if any(fnmatch.fnmatch(sub, p) for p in pats):
                found.add(rel)
        return found

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

    # --- Objets synchronisés par lab-platform / lab-o ----------------------------------------------
    def check_synced(self, synced, proj_name, lab):
        """S1/S2/S3 sur chaque objet synchronisé par le projet `proj_name` (whitelists de son AppProject)."""
        for rel in sorted(synced):
            for d in self.files[rel]:
                self.check_synced_object(rel, d, proj_name, lab)

    def check_synced_object(self, rel, d, proj_name, lab):
        g, k = group_of(d.get("apiVersion", "")), d["kind"]
        md = d.get("metadata") or {}
        n, ns = str(md.get("name", "")), md.get("namespace")
        self.rule_s1_whitelist(rel, proj_name, lab, g, k, n)
        if k == "NetworkPolicy":
            self.check_np(rel, ns, n, d.get("spec") or {})
        if k == "Namespace" and n in ("lab-pg", "lab-tunnel"):
            self.rule_s3_lab_pg_labels(rel, md.get("labels") or {}, n)
        if k in ("Deployment", "CiliumNetworkPolicy") and (k, ns, n) not in TUNNEL:
            self.err(rel, f"S4 {k} {ns}/{n} hors liste nommée TUNNEL")

    def rule_s1_whitelist(self, rel, proj_name, lab, g, k, n):
        """S1 : objet cluster-scoped (kind ET nom) ou namespacé admis par les whitelists/blacklists du projet."""
        if k in CLUSTER_KINDS:
            cw, cb = lab.get("clusterResourceWhitelist") or [], lab.get("clusterResourceBlacklist") or []
            if not match(cw, g, k, n) or match(cb, g, k, n):
                self.err(rel, f"S1 {k}/{n} cluster-scoped absent de clusterResourceWhitelist ({proj_name})")
            return
        nw, nb = lab.get("namespaceResourceWhitelist") or [], lab.get("namespaceResourceBlacklist") or []
        if not nw or not match(nw, g, k) or match(nb, g, k):
            self.err(rel, f"S1 {k}/{n} namespacé non autorisé par l'AppProject {proj_name}")

    def rule_s3_lab_pg_labels(self, rel, labels, name="lab-pg"):
        """S3 : Namespace lab-pg / lab-tunnel avec ses labels PSA restricted / part-of / egress-isolated."""
        for lk, lv in LAB_PG_LABELS.items():
            if labels.get(lk) != lv:
                self.err(rel, f"S3 Namespace {name} : label {lk}={lv} exigé (trouvé {labels.get(lk)!r})")
        for lk in ("pod-security.kubernetes.io/warn", "pod-security.kubernetes.io/audit"):
            if labels.get(lk) not in (None, "restricted"):
                self.err(rel, f"S3 Namespace {name} : {lk} doit rester restricted")

    def check_np(self, rel, ns, name, spec):
        if (ns, name) not in ALLOWED_NP and ("NetworkPolicy", ns, name) not in TUNNEL:
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


def source_list(spec):
    """Sources d'une Application : `sources[]` (refusé par A3, lu par prudence) ou `source` (unique)."""
    if "sources" in spec:
        return [s for s in (spec.get("sources") or []) if isinstance(s, dict)]
    return [spec.get("source") or {}]


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
