#!/usr/bin/env python3
"""Contrôle STATIQUE du RBAC versionné de kgateway (T-060), sans cluster.

Usage : python3 -I tools/oke/kgateway_rbac_check.py MANIFESTE VALUES [RENDU_SANS_RBAC RENDU_AVEC_RBAC]
  MANIFESTE        platform/install/manifests/05-kgateway-rbac.yaml
  VALUES           platform/install/values/kgateway.yaml
  RENDU_SANS_RBAC  `helm template` du chart avec VALUES (rbac.create=false) : aucun objet RBAC attendu
  RENDU_AVEC_RBAC  même rendu avec --set rbac.create=true : le ClusterRole du chart, référence amont
Refuse :
  R1. VALUES sans `rbac.create: false` ;
  R2. dans le ClusterRole versionné, un verbe sur `secrets` hors get/list/watch, ou un joker (`*`) ;
  R3. un Role autre que `create` sur `secrets` dans openchoreo-control-plane ; une liaison vers un autre sujet
      que le SA kgateway d'openchoreo-control-plane ;
  R4. (avec les rendus) un objet RBAC rendu par le chart en rbac.create=false ;
  R5. (avec les rendus) un écart entre le ClusterRole versionné et celui du chart, hors `secrets` réduit à la lecture.
Sortie : une ligne par écart ; code 1 si au moins un écart.
"""
import sys

import yaml

NS, SA = "openchoreo-control-plane", "kgateway"
RBAC_KINDS = {"ClusterRole", "ClusterRoleBinding", "Role", "RoleBinding"}
READ = {"get", "list", "watch"}


def docs(path):
    with open(path, encoding="utf-8") as f:
        return [d for d in yaml.safe_load_all(f) if isinstance(d, dict)]


def perms(rules):
    """(groupe, ressource) -> ensemble de verbes, indépendant du découpage des règles."""
    out = {}
    for r in rules or []:
        for g in r.get("apiGroups") or [""]:
            for res in r.get("resources") or []:
                out.setdefault((g, res), set()).update(r.get("verbs") or [])
    return out


def check(manifest, values, render_off=None, render_on=None):
    errs = []
    v = docs(values)[0]
    if (v.get("rbac") or {}).get("create") is not False:
        errs.append("R1 values : rbac.create doit valoir false")
    objs = docs(manifest)
    crs = [o for o in objs if o.get("kind") == "ClusterRole"]
    if len(crs) != 1:
        errs.append(f"R2 manifeste : 1 ClusterRole attendu, {len(crs)} trouvé(s)")
    cr = perms(crs[0].get("rules")) if crs else {}
    for (g, res), verbs in cr.items():
        if "*" in verbs or res == "*" or g == "*":
            errs.append(f"R2 ClusterRole : joker sur {g}/{res}")
        if g == "" and res == "secrets" and not verbs <= READ:
            errs.append(f"R2 ClusterRole : secrets {sorted(verbs - READ)} (lecture seule attendue)")
    for o in objs:
        k, md = o.get("kind"), o.get("metadata") or {}
        if k == "Role":
            p = perms(o.get("rules"))
            if md.get("namespace") != NS or p != {("", "secrets"): {"create"}}:
                errs.append(f"R3 Role {md.get('name')} : seul `create secrets` dans {NS} est admis")
        if k in ("ClusterRoleBinding", "RoleBinding"):
            subj = o.get("subjects") or []
            if subj != [{"kind": "ServiceAccount", "name": SA, "namespace": NS}]:
                errs.append(f"R3 {k} {md.get('name')} : sujet attendu ServiceAccount {NS}/{SA}")
        if k not in RBAC_KINDS:
            errs.append(f"R3 manifeste : kind inattendu {k}")
    if render_off:
        for o in docs(render_off):
            if o.get("kind") in RBAC_KINDS:
                errs.append(f"R4 rendu rbac.create=false : {o['kind']} {o['metadata']['name']} rendu")
    if render_on:
        up = [o for o in docs(render_on) if o.get("kind") == "ClusterRole"]
        if len(up) != 1:
            errs.append(f"R5 rendu rbac.create=true : 1 ClusterRole attendu, {len(up)}")
        else:
            want = perms(up[0].get("rules"))
            want[("", "secrets")] = want.get(("", "secrets"), set()) & READ
            for key in sorted(set(want) | set(cr)):
                if want.get(key, set()) != cr.get(key, set()):
                    errs.append(f"R5 écart avec le chart sur {key[0] or 'core'}/{key[1]} : "
                                f"chart {sorted(want.get(key, set()))}, Git {sorted(cr.get(key, set()))}")
    return errs


def main(argv):
    if len(argv) not in (3, 5):
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    errs = check(*argv[1:])
    for e in errs:
        print(e)
    if not errs:
        print("kgateway-rbac : OK")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
