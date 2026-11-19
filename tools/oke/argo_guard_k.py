"""Règles L1-L4 de tools/oke/argo_guard.py : bras K du banc A/B (T-495, ADR-0025). Module importé, pas un script.

Les fichiers du bac à sable bench-ab-arm-k ne sont pas dans ce dépôt : seules NOTRE frontière (AppProjects lab-k,
lab-k-root de platform/install/argocd/project-lab.yaml) et l'Application lab-k-root sont contrôlées. Refuse :
  L1. lab-k autre que : dépôt bench-ab-arm-k SEUL, destinations EXACTES `lab-k-*`, svc-echo-bench, svc-miniflux,
      svc-ntfy (noms explicites, jamais `svc-*`) et lab-pg du cluster local, Namespace `lab-k-*` et ces trois noms
      seulement, kinds namespacés `*/*` comme le projet `applications` de kube-ops (T-506, E5), blacklist conservée,
      aucune autre clé (roles, destinationServiceAccounts...) ; le dépôt du bac à sable dans un autre projet que
      lab-k / lab-k-root ; `lab-k-*` ailleurs, ou un joker de kinds hors lab-k (P2 joker) ;
  L2. une destination de lab-k qui couvrirait openchoreo-*, argocd, kube-system, lab-argocd ou lab-secrets ;
  L3. lab-k-root autre que « ApplicationSet dans lab-argocd, dépôt bench-ab-arm-k seul » (+ fenêtre deny, P3) ;
      l'Application lab-k-root autre que : apps/, nom lab-k-root, dépôt HTTPS du bac à sable, main, chemin
      k8s/bootstrap/argocd-root, include des DEUX ApplicationSets seulement (jamais l'AppProject copié),
      destination lab-argocd ; le projet lab-k-root employé par une autre Application ;
  L4. une Application de CE dépôt dans le projet lab-k (réservé aux Applications des ApplicationSets du bac à
      sable : A2 d'argo_guard.py, projet absent de la liste admise).
"""
import fnmatch

# Bac à sable bench-ab-arm-k lu en HTTPS (sans identifiant par défaut ; dépôt privé : Secret de dépôt Argo de type
# GitHub App, même URL, backlog/T-495-appproject-lab-k.md) ; les deux formes d'URL désignent un seul dépôt.
IN_CLUSTER = "https://kubernetes.default.svc"
K_REPOS = ["https://github.com/platform-zephyr/bench-ab-arm-k.git", "https://github.com/platform-zephyr/bench-ab-arm-k"]
K_PROJECTS = ("lab-k", "lab-k-root")
# Décisions de Paul (« oui » du 2026-11-19, T-506) : E1, namespaces `svc-<app>` du chart platform-app de kube-ops
# inchangé, par NOMS EXPLICITES (jamais `svc-*`) ; E5, kinds du projet `applications` de kube-ops (`*/*`) et lab-pg.
K_SVC_NS = ("svc-echo-bench", "svc-miniflux", "svc-ntfy")
K_DEST_NS = ("lab-k-*", *K_SVC_NS, "lab-pg")
K_CLUSTER_WL = [{"group": "", "kind": "Namespace", "name": n} for n in ("lab-k-*", *K_SVC_NS)]  # lab-pg : plateforme
K_NAMESPACED_WL = [{"group": "*", "kind": "*"}]
K_BLACKLIST = [{"group": "rbac.authorization.k8s.io", "kind": "Role"},
               {"group": "rbac.authorization.k8s.io", "kind": "RoleBinding"}, {"group": "", "kind": "Secret"},
               {"group": "", "kind": "ResourceQuota"}, {"group": "", "kind": "LimitRange"}]
K_KEYS = {"description", "sourceRepos", "destinations", "clusterResourceWhitelist", "namespaceResourceWhitelist",
          "namespaceResourceBlacklist", "orphanedResources"}
# Namespaces que lab-k ne doit jamais atteindre (L2) : un exemple de nom par motif interdit.
K_FORBIDDEN_NS = ("openchoreo-control-plane", "openchoreo-data-plane", "openchoreo-x", "argocd", "kube-system",
                  "lab-argocd", "lab-secrets", "default", "lab-cnpg", "dp-x", "svc-other")
K_ROOT_SOURCE = {"repoURL": K_REPOS[0], "targetRevision": "main", "path": "k8s/bootstrap/argocd-root",
                 "directory": {"recurse": False,
                               "include": "{apps-generated-applicationset.yaml,applications-applicationset.yaml}"}}
K_ROOT_DEST = {"server": IN_CLUSTER, "namespace": "lab-argocd"}


def same(got, want):
    """Même liste d'entrées (dictionnaires), à l'ordre près, sans doublon ni entrée en plus."""
    got = got if isinstance(got, list) else []
    return len(got) == len(want) and all(r in got for r in want) and all(r in want for r in got)


def k_destination_allowed(project, dst):
    """Seules destinations de lab-k admises par P2 (L1) : celles de K_DEST_NS, cluster local."""
    return project == "lab-k" and dst in [{"server": IN_CLUSTER, "namespace": ns} for ns in K_DEST_NS]


def k_wildcard_kinds_allowed(project, key, r):
    """P2 : le seul joker de kinds admis est `*/*` en namespaceResourceWhitelist de lab-k (L1, E5)."""
    return project == "lab-k" and key == "namespaceResourceWhitelist" and r in K_NAMESPACED_WL


def argo_kind_allowed(project, kind):
    """P2 : Application, AppProject, ApplicationSet en whitelist : lab-root ; lab-k-root : ApplicationSet seul (L3)."""
    return project == "lab-root" or (project, kind) == ("lab-k-root", "ApplicationSet")


class LabKRules:
    """Mixin de Guard (argo_guard.py) : fournit les règles L1-L3 ; `self.err(rel, msg)` vient de Guard."""

    def check_lab_k_projects(self, rel, projs):
        """L1-L3 sur les AppProjects (appelé en fin de Guard.check_projects : ordre des écarts stable)."""
        self.rule_l1_k_repos(rel, projs)
        self.rule_l1_lab_k(rel, projs.get("lab-k"))
        self.rule_l3_lab_k_root(rel, projs.get("lab-k-root"))

    def rule_l1_k_repos(self, rel, projs):
        """L1 : le dépôt du bac à sable n'est source que de lab-k et lab-k-root."""
        for name, s in projs.items():
            if name not in K_PROJECTS and set(s.get("sourceRepos") or []) & set(K_REPOS):
                self.err(rel, f"L1 {name} : dépôt du bac à sable bench-ab-arm-k réservé à {', '.join(K_PROJECTS)}")

    def k_repos_only(self, rel, name, s):
        repos = s.get("sourceRepos") or []
        if not repos or len(repos) != len(set(repos)) or not set(repos) <= set(K_REPOS):
            self.err(rel, f"L1 {name} : sourceRepos limité au seul dépôt du bac à sable {K_REPOS}")

    def rule_l1_lab_k(self, rel, k):
        """L1 : lab-k = dépôt du bac à sable, aucune clé en plus, kinds exacts de kube-ops ; L2 : destinations."""
        if k is None:
            return
        self.k_repos_only(rel, "lab-k", k)
        for key in sorted(set(k) - K_KEYS):
            self.err(rel, f"L1 lab-k : clé spec.{key} interdite")
        self.rule_l2_k_destinations(rel, k.get("destinations") or [])
        self.rule_l1_k_kinds(rel, k)

    def rule_l2_k_destinations(self, rel, dests):
        """L1 : destinations exactes ; L2 : aucune ne couvre un namespace interdit ni un autre cluster."""
        if not same(dests, [{"server": IN_CLUSTER, "namespace": ns} for ns in K_DEST_NS]):
            self.err(rel, f"L1 lab-k : destinations exactes exigées : {list(K_DEST_NS)} du cluster local")
        for d in dests:
            hit = [n for n in K_FORBIDDEN_NS if fnmatch.fnmatch(n, str(d.get("namespace", "")))]
            if hit or d.get("server") not in (None, IN_CLUSTER) or "name" in d:
                self.err(rel, f"L2 lab-k : destination {d} hors périmètre (couvre {hit or 'un autre cluster'})")

    def rule_l1_k_kinds(self, rel, k):
        """L1 : Namespace lab-k-* et svc-<app> nommés, kinds `*/*` du projet applications de kube-ops, blacklist."""
        if not same(k.get("clusterResourceWhitelist"), K_CLUSTER_WL):
            self.err(rel, f"L1 lab-k : clusterResourceWhitelist limitée au Namespace {[r['name'] for r in K_CLUSTER_WL]}")
        if not same(k.get("namespaceResourceWhitelist"), K_NAMESPACED_WL):
            self.err(rel, "L1 lab-k : namespaceResourceWhitelist = EXACTEMENT */* (projet applications de kube-ops)")
        bl = k.get("namespaceResourceBlacklist") or []
        if any(r not in bl for r in K_BLACKLIST):
            self.err(rel, "L1 lab-k : namespaceResourceBlacklist de kube-ops exigée ("
                          + ", ".join(r["kind"] for r in K_BLACKLIST) + ")")

    def rule_l3_lab_k_root(self, rel, kr):
        """L3 : lab-k-root = ApplicationSet seul, dans lab-argocd, depuis le seul dépôt du bac à sable."""
        if kr is None:
            return
        self.k_repos_only(rel, "lab-k-root", kr)
        if kr.get("clusterResourceWhitelist") != [] \
                or kr.get("namespaceResourceWhitelist") != [{"group": "argoproj.io", "kind": "ApplicationSet"}] \
                or kr.get("destinations") != [K_ROOT_DEST] or set(kr) - K_KEYS - {"syncWindows"}:
            self.err(rel, "L3 lab-k-root : seul le kind ApplicationSet dans lab-argocd (cluster local) est admis")

    def rule_l3_k_root_app(self, rel, name, proj, spec):
        """L3 : le projet lab-k-root est réservé à l'Application lab-k-root, source et destination exactes."""
        if proj != "lab-k-root" and name != "lab-k-root":
            return
        if name != "lab-k-root" or proj != "lab-k-root" or "sources" in spec \
                or spec.get("source") != K_ROOT_SOURCE or spec.get("destination") != K_ROOT_DEST:
            self.err(rel, f"L3 Application '{name}' : projet lab-k-root réservé à l'Application lab-k-root "
                          f"(source exacte {K_ROOT_SOURCE}, destination lab-argocd)")
