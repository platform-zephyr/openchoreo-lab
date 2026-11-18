"""Egress declaratif (E3) : validation des regles, parametres du ClusterProjectType et apercus de politiques.

Role : une seule lecture de network.egress pour la validation (CIDR, FQDN, app) et pour le rendu (parametres CPT,
NetworkPolicy et CiliumNetworkPolicy equivalentes).
Entrees : document app.yaml, politique du cluster (capabilities), index des apps du depot, Context.
Sorties : (erreurs, avertissements) pour la validation ; dictionnaires de parametres et objets Kubernetes pour
le rendu.
"""
from __future__ import annotations

import ipaddress
import json
import re
from typing import Any

from appgenlib.config import (
    FORBIDDEN_FQDN_PREFIXES,
    FORBIDDEN_FQDN_SUFFIXES,
    LINK_LOCAL,
    MIN_PUBLIC_PREFIX,
    NON_ROUTABLE,
    PRIVATE_NETS,
)
from appgenlib.model import Context, components, compute_delivery, egress_spec


def cidr_policy(cidr: str, caps: dict) -> tuple[list[str], list[str]]:
    """Regle CIDR -> (erreurs, except[]). IMDS jamais ; prive seulement si liste dans capabilities ; /0 jamais."""
    try:
        net: Any = ipaddress.ip_network(cidr, strict=True)
    except ValueError:
        return [f"egress cidr '{cidr}' invalide (adresse de reseau exacte attendue)"], []
    if net.prefixlen == 0:
        return [f"egress cidr '{cidr}' interdit : utiliser le profil explicite egress: public-internet"], []
    if net.subnet_of(LINK_LOCAL):
        return [f"egress cidr '{cidr}' interdit : link-local / IMDS 169.254.169.254 jamais autorise"], []
    for nr in NON_ROUTABLE:
        if net.subnet_of(nr):
            return [f"egress cidr '{cidr}' interdit : plage non routable"], []
    private = next((p for p in PRIVATE_NETS if net.subnet_of(p)), None)
    if private is not None:
        allowed = [ipaddress.ip_network(c) for c in caps.get("privateEgressCIDRs", [])]
        if not any(net.subnet_of(a) for a in allowed):
            return [f"egress cidr '{cidr}' prive ({private}) refuse : absent de capabilities.privateEgressCIDRs"], []
        return [], []
    if net.prefixlen < MIN_PUBLIC_PREFIX:
        return [f"egress cidr '{cidr}' trop large (< /{MIN_PUBLIC_PREFIX}) : utiliser egress: public-internet"], []
    # Plage publique englobant des reseaux prives (ex. 8.0.0.0/7 ne contient rien ; 0.0.0.0/1 contient 10/8) :
    # except automatique, IMDS compris.
    excepts = [str(p) for p in PRIVATE_NETS if p.subnet_of(net)]
    return [], excepts


def fqdn_errors(value: str, pattern: bool) -> list[str]:
    host = value[2:] if pattern else value
    errs = []
    if re.fullmatch(r"[0-9.]+", host):
        errs.append(f"egress fqdn '{value}' : adresse IP interdite (utiliser cidr)")
    if host.endswith(FORBIDDEN_FQDN_SUFFIXES) or host in ("localhost",) or host.startswith(FORBIDDEN_FQDN_PREFIXES):
        errs.append(f"egress fqdn '{value}' interdit : nom interne, cluster ou metadonnees")
    if pattern and host.count(".") < 1:
        errs.append(f"egress fqdnPattern '{value}' trop large (au moins *.domaine.tld)")
    return errs


def _fqdn_rule_errors(r: dict, spec: dict, caps: dict, ctx: Context) -> tuple[list[str], list[str]]:
    """Regle fqdn/fqdnPattern : forme du nom, puis refus (ou avertissement) sans Cilium."""
    errs = fqdn_errors(r.get("fqdn") or r["fqdnPattern"], "fqdnPattern" in r)
    warns: list[str] = []
    if not caps["cilium"]:
        msg = (f"egress FQDN '{r.get('fqdn') or r['fqdnPattern']}' sur le cluster '{spec['cluster']}' sans Cilium : "
               "aucune CiliumNetworkPolicy n'y serait appliquee")
        if ctx.allow_unenforced_fqdn:
            warns.append(msg + " (--allow-unenforced-fqdn : apercu marque enforced=false, flux refuses)")
        else:
            errs.append(msg + " : refus")
    return errs, warns


def _app_rule_errors(r: dict, name: str, spec: dict, ctx: Context) -> list[str]:
    """Regle app (parcours natif) : cible connue, native, meme cluster, workload avec port, memes environnements."""
    target = ctx.index.get(r["app"])
    wl = r.get("workload", "main")
    if r["app"] == name:
        return ["egress app : cible = l'app elle-meme (deja autorise dans la cellule)"]
    if target is None:
        return [f"egress app '{r['app']}' : app inconnue dans le depot"]
    if compute_delivery(target["spec"]) != "native" or target["spec"]["cluster"] != spec["cluster"]:
        return [f"egress app '{r['app']}' : cible non native ou sur un autre cluster"]
    errs = []
    comp = next((c for c in components(target) if c["key"] == wl and c["kind"] != "CronJob"), None)
    if comp is None or not comp["port"]:
        errs.append(f"egress app '{r['app']}/{wl}' : workload inconnu ou sans port")
    missing = set(spec["environments"]) - set(target["spec"]["environments"])
    if missing:
        errs.append(f"egress app '{r['app']}' : absente des environnements {sorted(missing)}")
    return errs


def egress_errors(doc: dict, ctx: Context, caps: dict) -> tuple[list[str], list[str]]:
    spec, name = doc["spec"], doc["metadata"]["name"]
    errs: list[str] = []
    warns: list[str] = []
    _, rules = egress_spec(spec)
    helm = compute_delivery(spec) == "helm"
    seen = set()
    for r in rules:
        ident = json.dumps(r, sort_keys=True)
        if ident in seen:
            errs.append(f"egress : regle en double {ident}")
        seen.add(ident)
        if "cidr" in r:
            errs += cidr_policy(r["cidr"], caps)[0]
        elif "fqdn" in r or "fqdnPattern" in r:
            f_errs, f_warns = _fqdn_rule_errors(r, spec, caps, ctx)
            errs += f_errs
            warns += f_warns
        elif helm:
            errs.append("egress app : non supporte en parcours helm")
        else:
            errs += _app_rule_errors(r, name, spec, ctx)
    return errs, warns


def egress_targets(index: dict) -> set[tuple[str, str]]:
    """(app, workload) vises par une regle egress app : leur endpoint recoit la visibilite 'namespace'."""
    out = set()
    for doc in index.values():
        for r in egress_spec(doc["spec"])[1]:
            if "app" in r:
                out.add((r["app"], r.get("workload", "main")))
    return out


def egress_project_params(doc: dict, caps: dict, index: dict) -> dict:
    """Regles E3 -> parametres du ClusterProjectType (structures simples ; except calcules ici)."""
    _, rules = egress_spec(doc["spec"])
    cidrs, fqdns, apps = [], [], []
    for r in rules:
        if "cidr" in r:
            cidrs.append({"cidr": r["cidr"], "except": cidr_policy(r["cidr"], caps)[1], "ports": list(r["ports"])})
        elif "fqdn" in r:
            fqdns.append({"matchName": r["fqdn"], "ports": list(r["ports"])})
        elif "fqdnPattern" in r:
            fqdns.append({"matchPattern": r["fqdnPattern"], "ports": list(r["ports"])})
        else:
            target = index[r["app"]]
            comp = next(c for c in components(target) if c["key"] == r.get("workload", "main"))
            apps.append({"project": r["app"], "component": comp["cname"], "port": comp["port"]})
    out: dict[str, Any] = {}
    if cidrs:
        out["egressCIDRs"] = cidrs
    if fqdns and caps["cilium"]:
        out["egressFQDNs"] = fqdns   # sans Cilium : jamais transmis (fail-closed), apercu marque
    if apps:
        out["egressApps"] = apps
    return out


def _dns_cnp_rule() -> dict:
    return {"toEndpoints": [{"matchLabels": {"k8s:io.kubernetes.pod.namespace": "kube-system", "k8s:k8s-app": "kube-dns"}}],
            "toPorts": [{"ports": [{"port": "53", "protocol": "ANY"}], "rules": {"dns": [{"matchPattern": "*"}]}}]}


def _np_rules(env: str, params: dict) -> list[dict]:
    """Regles de NetworkPolicy (ipBlock pour les CIDR, selecteurs pour les apps) des parametres egress."""
    np_rules = []
    for r in params.get("egressCIDRs", []):
        block = {"cidr": r["cidr"], **({"except": r["except"]} if r["except"] else {})}
        np_rules.append({"to": [{"ipBlock": block}], "ports": [{"protocol": "TCP", "port": p} for p in r["ports"]]})
    for r in params.get("egressApps", []):
        np_rules.append({
            "to": [{"namespaceSelector": {"matchLabels": {"openchoreo.dev/project": r["project"],
                                                          "openchoreo.dev/environment": env}},
                    "podSelector": {"matchLabels": {"openchoreo.dev/component": r["component"]}}}],
            "ports": [{"protocol": "TCP", "port": r["port"]}],
        })
    return np_rules


def egress_objects(name: str, env: str, namespace: str, params: dict, rules: list[dict], cilium: bool,
                   annotations: dict) -> list[dict]:
    """NetworkPolicy (CIDR, apps) et CiliumNetworkPolicy (FQDN) equivalentes aux parametres egress."""
    objs = []
    np_rules = _np_rules(env, params)
    if np_rules:
        objs.append({
            "apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
            "metadata": {"name": "egress-allowlist", "namespace": namespace, "annotations": dict(annotations)},
            "spec": {"podSelector": {}, "policyTypes": ["Egress"], "egress": np_rules},
        })
    fq = [r for r in rules if "fqdn" in r or "fqdnPattern" in r]
    if fq:
        # Meme forme que le CPT propose : une regle par entree (pas de regroupement, pour coller au rendu CEL).
        cnp_rules = [_dns_cnp_rule()] + [
            {"toFQDNs": [{"matchName": r["fqdn"]} if "fqdn" in r else {"matchPattern": r["fqdnPattern"]}],
             "toPorts": [{"ports": [{"port": str(p), "protocol": "TCP"} for p in r["ports"]]}]}
            for r in fq
        ]
        objs.append({
            "apiVersion": "cilium.io/v2", "kind": "CiliumNetworkPolicy",
            "metadata": {"name": "egress-fqdn", "namespace": namespace,
                         "annotations": {**annotations, "platform.smadja.dev/enforced": "true" if cilium else "false"}},
            "spec": {"endpointSelector": {}, "egress": cnp_rules},
        })
    return objs
