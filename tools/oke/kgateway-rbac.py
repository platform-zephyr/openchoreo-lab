#!/usr/bin/env python3
"""Filtre RBAC du chart kgateway (T-060, ADR-0006) : retire le droit `secrets` cluster-wide.

Le chart kgateway v2.3.11 donne à son ServiceAccount, par un ClusterRole, create/delete/get/list/patch/watch sur
les Secrets de tout le cluster, sans option de values pour le retirer. Ce filtre lit le rendu sur l'entrée standard,
retire `secrets` du ClusterRole `kgateway-<ns>` et ajoute à la place un Role + RoleBinding par namespace listé dans
KGATEWAY_SECRETS_NAMESPACES (défaut : openchoreo-control-plane,openchoreo-data-plane ; le premier porte les
certificats xDS, le second le certificat TLS du Gateway). Les verbes d'origine sont conservés, mais bornés à ces
namespaces. Usage : helm -n NS get manifest kgateway | tools/oke/kgateway-rbac.py --rbac-only | kubectl apply --server-side --force-conflicts -f -
(--rbac-only : ne rend que le ClusterRole modifié, les Role et les RoleBinding ; sans l option, tout le rendu).
Helm 4 n'accepte plus un exécutable en --post-renderer (plugin requis) : d'où cette application après `helm upgrade`
Dépendance : PyYAML (déjà requis par tools/oke/render-check.sh). Aucune écriture hors stdout.
"""
import os
import sys

import yaml

DEFAULT_NAMESPACES = "openchoreo-control-plane,openchoreo-data-plane"


def strip_secrets(role):
    """ClusterRole sans `secrets` ; renvoie (rôle, verbes d'origine ou None)."""
    rules, verbs = [], None
    for r in role.get("rules", []):
        res = list(r.get("resources", []))
        if "secrets" in res and r.get("apiGroups") == [""]:
            verbs = list(r["verbs"])
            res = [x for x in res if x != "secrets"]
            if not res:
                continue
            r = {**r, "resources": res}
        rules.append(r)
    return {**role, "rules": rules}, verbs


def namespaced(ns, verbs, subjects):
    meta = {"name": "kgateway-secrets", "namespace": ns,
            "labels": {"app.kubernetes.io/name": "kgateway", "app.kubernetes.io/part-of": "openchoreo-lab"}}
    api = "rbac.authorization.k8s.io/v1"
    return [{"apiVersion": api, "kind": "Role", "metadata": meta,
             "rules": [{"apiGroups": [""], "resources": ["secrets"], "verbs": verbs}]},
            {"apiVersion": api, "kind": "RoleBinding", "metadata": dict(meta), "subjects": subjects,
             "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "Role", "name": "kgateway-secrets"}}]


def transform(docs, namespaces):
    out, verbs, subjects = [], None, None
    for d in (x for x in docs if isinstance(x, dict)):
        name = str(d.get("metadata", {}).get("name", ""))
        if d.get("kind") == "ClusterRole" and name.startswith("kgateway-"):
            d, verbs = strip_secrets(d)
        elif d.get("kind") == "ClusterRoleBinding" and name.startswith("kgateway-role-"):
            subjects = d.get("subjects")
        out.append(d)
    if verbs is None or not subjects:
        sys.exit("kgateway-rbac : règle secrets ou ClusterRoleBinding introuvable (chart changé ? revoir ce filtre)")
    for ns in namespaces:
        out += namespaced(ns, verbs, subjects)
    return out




def main():
    nss = [n for n in os.environ.get("KGATEWAY_SECRETS_NAMESPACES", DEFAULT_NAMESPACES).split(",") if n]
    docs = list(yaml.safe_load_all(sys.stdin.read()))
    out = transform(docs, nss)
    if "--rbac-only" in sys.argv[1:]:
        out = [d for d in out if d.get("kind") in ("Role", "RoleBinding")
               or (d.get("kind") == "ClusterRole" and str(d["metadata"]["name"]).startswith("kgateway-"))]
    yaml.safe_dump_all(out, sys.stdout, sort_keys=False)


if __name__ == "__main__":
    main()
