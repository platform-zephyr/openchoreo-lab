#!/usr/bin/env python3
"""Contrôle STATIQUE des règles Argo du labo (revue B2), là où l'AppProject ne peut pas agir (chemins).

Usage : python3 -I tools/oke/argo_guard.py [racine du dépôt]
Vérifie, sans cluster :
  1. kinds Authz OpenChoreo (AuthzRole, AuthzRoleBinding, ClusterAuthzRole, ClusterAuthzRoleBinding) :
     seulement sous platform/authz/ (chemin dédié, projet lab-authz) parmi les fichiers synchronisés par Argo ;
  2. platform/install/argocd/apps/ : uniquement des Application ; projet `lab-authz` réservé à l'Application
     lab-authz de chemin platform/authz ; projet `lab` pour les autres ; jamais d'AppProject ;
  3. chaque objet cluster-scoped des fichiers que lab-platform synchronise figure, par kind ET nom, dans
     clusterResourceWhitelist de l'AppProject lab (aucun Namespace/VAP/CRD/ClusterRole non listé) ;
  4. chaque objet namespacé de ces fichiers a un kind de namespaceResourceWhitelist et n'est pas en blacklist.
Sortie : une ligne par écart ; code 1 si au moins un écart. Ne remplace pas la revue (CODEOWNERS).
"""
import fnmatch
import pathlib
import sys

import yaml

AUTHZ_KINDS = {"AuthzRole", "AuthzRoleBinding", "ClusterAuthzRole", "ClusterAuthzRoleBinding"}
# Kinds cluster-scoped connus des fichiers plateforme (le reste est namespacé).
CLUSTER_KINDS = {"Namespace", "ValidatingAdmissionPolicy", "ValidatingAdmissionPolicyBinding",
                 "CustomResourceDefinition", "ClusterRole", "ClusterRoleBinding",
                 "MutatingWebhookConfiguration", "ValidatingWebhookConfiguration", "PersistentVolume",
                 "StorageClass", "PriorityClass", "ClusterComponentType", "ClusterProjectType",
                 "ClusterResourceType", "ClusterTrait", "ClusterDataPlane", "ClusterAuthzRole",
                 "ClusterAuthzRoleBinding", "ClusterSecretStore", "ClusterIssuer", "GatewayClass",
                 "CiliumClusterwideNetworkPolicy", "ClusterExternalSecret", "ClusterGenerator"}


def docs(path):
    with open(path, encoding="utf-8") as f:
        return [d for d in yaml.safe_load_all(f) if isinstance(d, dict) and d.get("kind")]


def group_of(api_version):
    return api_version.split("/")[0] if "/" in api_version else ""


def expand_include(pattern):
    """Développe un include Argo `{a,b,c}` en liste de motifs glob."""
    p = pattern.strip()
    if p.startswith("{") and p.endswith("}"):
        return [x.strip() for x in p[1:-1].split(",")]
    return [p]


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    errs = []
    argo = root / "platform/install/argocd"
    projects = {d["metadata"]["name"]: d["spec"] for d in docs(argo / "project-lab.yaml") if d["kind"] == "AppProject"}
    if "lab" not in projects:
        print("ERREUR AppProject lab absent de project-lab.yaml")
        return 1
    lab = projects["lab"]

    # 2. Applications
    apps = []
    for f in sorted((argo / "apps").glob("*.yaml")):
        for d in docs(f):
            rel = f.relative_to(root)
            if d["kind"] != "Application":
                errs.append(f"{rel}: kind {d['kind']} interdit dans apps/ (Application seulement)")
                continue
            proj = d["spec"].get("project")
            path = d["spec"].get("source", {}).get("path", "")
            name = d["metadata"]["name"]
            if proj == "lab-authz" and not (name == "lab-authz" and path == "platform/authz"):
                errs.append(f"{rel}: projet lab-authz réservé à l'Application lab-authz (chemin platform/authz)")
            if proj not in ("lab", "lab-authz"):
                errs.append(f"{rel}: projet '{proj}' inconnu")
            apps.append(d)

    # Fichiers synchronisés par Argo (Applications de projet lab, chemin platform).
    synced = set()
    for a in apps:
        src = a["spec"].get("source", {})
        if a["spec"].get("project") != "lab" or not src.get("path", "").startswith("platform"):
            continue
        base = root / src["path"]
        pats = expand_include(src.get("directory", {}).get("include", "*.yaml"))
        for f in base.rglob("*.yaml"):
            rel = str(f.relative_to(base))
            if any(fnmatch.fnmatch(rel, p) for p in pats):
                synced.add(f)

    # 1. Authz hors chemin dédié (tout platform/ et generated/, synchronisés ou non : une PR pourrait les inclure)
    for top in ("platform", "generated"):
        for f in sorted((root / top).rglob("*.yaml")):
            rel = f.relative_to(root)
            if str(rel).startswith("platform/authz/"):
                continue
            try:
                for d in docs(f):
                    if d["kind"] in AUTHZ_KINDS and f in synced:
                        errs.append(f"{rel}: {d['kind']}/{d['metadata'].get('name')} synchronisé hors platform/authz/")
            except yaml.YAMLError:
                continue  # gabarits Helm (values) : hors sujet ici

    # 3 et 4. Whitelists de l'AppProject lab
    cw = lab.get("clusterResourceWhitelist", [])
    nw = lab.get("namespaceResourceWhitelist", [])
    nb = lab.get("namespaceResourceBlacklist", [])

    def match(rules, group, kind, name=None):
        for r in rules:
            if r.get("group") not in (group, "*") or r.get("kind") not in (kind, "*"):
                continue
            if name is None or "name" not in r or fnmatch.fnmatch(name, r["name"]):
                return True
        return False

    for f in sorted(synced):
        rel = f.relative_to(root)
        for d in docs(f):
            g, k, n = group_of(d.get("apiVersion", "")), d["kind"], d["metadata"].get("name", "")
            if k in CLUSTER_KINDS:
                if not match(cw, g, k, n):
                    errs.append(f"{rel}: {k}/{n} cluster-scoped absent de clusterResourceWhitelist (lab)")
            else:
                if not match(nw, g, k) or match(nb, g, k):
                    errs.append(f"{rel}: {k}/{n} namespacé non autorisé par l'AppProject lab")

    for e in errs:
        print("ÉCART", e)
    print(f"argo_guard : {len(synced)} fichier(s) synchronisé(s) par lab-platform contrôlé(s), {len(errs)} écart(s)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
