#!/usr/bin/env python3
"""appgen : apps/<nom>/app.yaml -> manifests OpenChoreo v1.3.3 (ou Application Argo CD) sous generated/.

Commandes :
  validate                 schema + regles semantiques (apps/*/app.yaml et apps/_examples/*/app.yaml)
  render [--out DIR]       ecrit les manifests (suppression prealable de DIR, sortie deterministe)
  check                    rend dans un dossier temporaire et compare a generated/ (derive = echec)
  pin-resource APP RELEASE ecrit la pin ResourceRelease d'une base dans pins/resource-releases.yaml

Politique par cluster : clusters/<cluster>/capabilities.yaml (docs/schema/capabilities.schema.json).
Aucun secret n'est lu ni ecrit : seules des references (SecretReference, ExternalSecret) sont generees.
Dependances : PyYAML, jsonschema (figes dans tools/appgen/requirements.txt).
"""
from __future__ import annotations

import argparse
import copy
import datetime
import filecmp
import hashlib
import ipaddress
import json
import re
import shutil
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

import yaml
from jsonschema import Draft7Validator

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "docs" / "schema" / "app.schema.json"
CAPS_SCHEMA_PATH = ROOT / "docs" / "schema" / "capabilities.schema.json"
PINS_PATH = ROOT / "pins" / "resource-releases.yaml"

NS = "default"
PIPELINE = "standard"
PROJECT_TYPE = "cell-restricted"
COMPONENT_TYPE = "deployment/service-restricted"
CCT_NAME = "service-restricted"
PVC_TRAIT = "persistent-volume-claim"
CRT_NAME = "cnpg-lab-db"
DB_INSTANCE = "lab-pg"
ALLOWED_ENVIRONMENTS = {"development", "production"}

# Type de composant par (kind, endpoint ?). Seul deployment/service-restricted existe dans platform/ aujourd'hui ;
# les autres sont a livrer par platform/ (APP-CONTRACT section 7.4). Absent => render echoue (jamais de repli).
CCT_BY_KIND = {
    ("Deployment", True): "deployment/service-restricted",
    ("Deployment", False): "deployment/worker-restricted",
    ("StatefulSet", True): "statefulset/statefulset-restricted",
    ("StatefulSet", False): "statefulset/statefulset-restricted",
    ("CronJob", False): "cronjob/cronjob-restricted",
}
ROOT_EXCEPTION_CCT = "deployment/service-root-exception"
PVC_TRAIT_BY_KIND = {"Deployment": PVC_TRAIT, "StatefulSet": "persistent-volume-claim-sts"}
ACCESS_MODE = {"block-rwo": "ReadWriteOnce", "rwx-shared": "ReadWriteMany"}
# Parametres du ClusterProjectType ajoutes par les extensions (a declarer par platform/ avant usage).
CPT_EXT_PARAMS = ("egressCIDRs", "egressFQDNs", "egressApps", "databaseNamespace", "databaseCluster", "podSecurity")

# Requests par taille (table kube-ops, identique a la CCT) et quota de cellule par defaut (CPT).
SIZE_REQUESTS = {"small": (50, 128), "medium": (200, 256)}
QUOTA_DEFAULT = (300, 512)
QUOTA_MAX = (1000, 2048)   # au-dela : refus (E11 non livre)

# Egress (E3).
PRIVATE_NETS = [ipaddress.ip_network(c) for c in
                ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10", "169.254.0.0/16")]
LINK_LOCAL = ipaddress.ip_network("169.254.0.0/16")
NON_ROUTABLE = [ipaddress.ip_network(c) for c in ("0.0.0.0/8", "127.0.0.0/8", "224.0.0.0/4", "240.0.0.0/4")]
MIN_PUBLIC_PREFIX = 8
FORBIDDEN_FQDN_SUFFIXES = (".local", ".localhost", ".internal", ".svc", ".cluster.local", ".arpa", ".lan", ".home")
FORBIDDEN_FQDN_PREFIXES = ("metadata.", "instance-data.")

# Exceptions (E12).
MAX_EXCEPTION_DAYS = 90

# Parcours Helm (Argo CD). URL du depot GitOps = $id du schema [S : a confirmer au premier push].
GITOPS_REPO = "https://github.com/platform-zephyr/openchoreo-lab.git"
GITOPS_REVISION = "main"
ARGO_NAMESPACE = "argocd"
ARGO_PROJECT_HELM = "lab-helm"

# Valeurs interdites ou dangereuses, cherchees dans toutes les cles et valeurs de app.yaml.
FORBIDDEN_TOKENS = ("LoadBalancer", "NodePort", "hostPath", "hostNetwork", "privileged", "ClusterRoleBinding")
SECRET_LIKE_ENV = re.compile(r"(PASSWORD|PASSWD|SECRET|TOKEN|PRIVATE_KEY|API_KEY|CREDENTIAL|ACCESS_KEY)")
SECRET_LIKE_VALUE = [
    re.compile(r"-----BEGIN "),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{30,}"),
    re.compile(r"sk-[A-Za-z0-9]{20,}"),
    re.compile(r"[a-z][a-z0-9+.-]*://[^/\s:@]+:[^/\s@]+@"),  # URL avec identifiants
]
REF_OK = re.compile(r"^[a-z][a-z0-9-]{1,18}[a-z0-9]$")


class AppError(Exception):
    """Erreur de validation ou de rendu (message lisible, sans valeur secrete)."""


# --------------------------------------------------------------------------- chargement


def load_yaml(path: Path):
    with path.open("r", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def _walk_strings(node, path=""):
    """Yield (chemin, chaine) pour chaque cle et valeur chaine de l'arbre."""
    if isinstance(node, dict):
        for k, v in node.items():
            yield f"{path}/{k}(cle)", str(k)
            yield from _walk_strings(v, f"{path}/{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from _walk_strings(v, f"{path}[{i}]")
    elif isinstance(node, str):
        yield path, node


def app_dirs(root: Path, examples: bool = False) -> list[Path]:
    """Repertoires d'apps a rendre (apps/<nom>/) ; examples=True ajoute apps/_examples/<nom>/."""
    dirs = sorted(p.parent for p in (root / "apps").glob("*/app.yaml"))
    if examples:
        dirs += sorted(p.parent for p in (root / "apps" / "_examples").glob("*/app.yaml"))
    return dirs


def clusters_dir_for(root: Path) -> Path:
    """clusters/ du depot evalue ; repli sur celui du depot de l'outil (tests sur racine temporaire)."""
    return root / "clusters" if (root / "clusters").is_dir() else ROOT / "clusters"


def load_capabilities(clusters_dir: Path, cluster: str) -> dict:
    path = clusters_dir / cluster / "capabilities.yaml"
    if not path.exists():
        raise AppError(f"politique de cluster absente : {path} (refus par defaut)")
    doc = load_yaml(path)
    errs = [f"{'/'.join(map(str, e.path)) or '<racine>'}: {e.message}"
            for e in Draft7Validator(load_yaml(CAPS_SCHEMA_PATH)).iter_errors(doc)]
    if errs:
        raise AppError(f"{path} invalide : " + " ; ".join(errs))
    if doc["metadata"]["name"] != cluster:
        raise AppError(f"{path} : metadata.name '{doc['metadata']['name']}' differe de '{cluster}'")
    return doc["spec"]


@dataclass
class Context:
    """Contexte de validation : politiques de cluster, index des apps (egress inter-apps), date du jour."""
    clusters_dir: Path = ROOT / "clusters"
    index: dict = field(default_factory=dict)
    today: datetime.date = field(default_factory=datetime.date.today)
    allow_unenforced_fqdn: bool = False
    _caps: dict = field(default_factory=dict)

    def caps(self, cluster: str) -> dict:
        if cluster not in self._caps:
            self._caps[cluster] = load_capabilities(self.clusters_dir, cluster)
        return self._caps[cluster]


# --------------------------------------------------------------------------- normalisation


def compute_delivery(spec: dict) -> str:
    return "helm" if "chart" in spec["source"] else "native"


def volumes(spec: dict) -> list[dict]:
    """storage (objet historique ou liste E8) -> liste normalisee de volumes."""
    st = spec.get("storage")
    if st is None:
        return []
    if isinstance(st, dict):
        return [{"name": "data", "profile": st["profile"], "mountPath": st["mountPath"], "size": st["size"],
                 "workload": "main", "readOnly": False}]
    return [{"workload": "main", "readOnly": False, **v} for v in st]


def egress_spec(spec: dict) -> tuple[str, list[dict]]:
    """network.egress -> (profil alias, regles). Une liste de regles implique le profil 'none' (default-deny)."""
    eg = spec["network"]["egress"]
    if isinstance(eg, str):
        return eg, []
    return "none", list(eg)


def components(doc: dict) -> list[dict]:
    """Composants OpenChoreo d'une app native : main, puis workloads[] (E6), puis jobs[] (E7)."""
    meta, spec = doc["metadata"], doc["spec"]
    name = meta["name"]
    rt = spec["runtime"]
    out = [{
        "key": "main", "cname": name, "kind": "Deployment", "image": spec["source"]["image"],
        "port": rt["port"], "protocol": "HTTP", "rt": rt, "main": True,
        "database": "database" in spec, "secrets": [s["env"] for s in spec.get("secrets", [])],
    }]
    for w in spec.get("workloads", []):
        out.append({
            "key": w["name"], "cname": f"{name}-{w['name']}", "kind": w["kind"],
            "image": w.get("image", spec["source"]["image"]), "port": w["runtime"].get("port"),
            "protocol": w["runtime"].get("protocol", "HTTP"), "rt": w["runtime"], "main": False,
            "database": w.get("database", False), "secrets": w.get("secrets", []),
        })
    for j in spec.get("jobs", []):
        out.append({
            "key": j["name"], "cname": f"{name}-{j['name']}", "kind": "CronJob",
            "image": j.get("image", spec["source"]["image"]), "port": None, "protocol": None,
            "rt": j["runtime"], "main": False, "schedule": j["schedule"], "timeZone": j.get("timeZone"),
            "database": j.get("database", False), "secrets": j.get("secrets", []),
        })
    return out


def exceptions_for(spec: dict, key: str) -> set[str]:
    return {e["rule"] for e in spec.get("securityExceptions", []) if e.get("workload", "main") == key}


# --------------------------------------------------------------------------- validation


def schema_errors(doc) -> list[str]:
    validator = Draft7Validator(load_yaml(SCHEMA_PATH))
    out = []
    for err in sorted(validator.iter_errors(doc), key=lambda e: list(e.path)):
        where = "/".join(str(p) for p in err.path) or "<racine>"
        out.append(f"schema {where}: {err.message}")
    return out


def _env_errors(label: str, env: dict, envs_secret: list[str]) -> list[str]:
    errs = []
    for var, value in env.items():
        if var in envs_secret:
            errs.append(f"variable '{var}' a la fois en env et en secret")
        if SECRET_LIKE_ENV.search(var):
            errs.append(f"{label}.env '{var}' ressemble a un secret : utiliser secrets[] (ESO)")
        for pat in SECRET_LIKE_VALUE:
            if pat.search(str(value)):
                errs.append(f"{label}.env '{var}' : valeur de type secret detectee (interdit dans Git)")
                break
    return errs


def cidr_policy(cidr: str, caps: dict) -> tuple[list[str], list[str]]:
    """Regle CIDR -> (erreurs, except[]). IMDS jamais ; prive seulement si liste dans capabilities ; /0 jamais."""
    try:
        net = ipaddress.ip_network(cidr, strict=True)
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
            errs += fqdn_errors(r.get("fqdn") or r["fqdnPattern"], "fqdnPattern" in r)
            if not caps["cilium"]:
                msg = (f"egress FQDN '{r.get('fqdn') or r['fqdnPattern']}' sur le cluster '{spec['cluster']}' sans Cilium : "
                       "aucune CiliumNetworkPolicy n'y serait appliquee")
                if ctx.allow_unenforced_fqdn:
                    warns.append(msg + " (--allow-unenforced-fqdn : apercu marque enforced=false, flux refuses)")
                else:
                    errs.append(msg + " : refus")
        else:
            if helm:
                errs.append("egress app : non supporte en parcours helm")
                continue
            target = ctx.index.get(r["app"])
            wl = r.get("workload", "main")
            if r["app"] == name:
                errs.append("egress app : cible = l'app elle-meme (deja autorise dans la cellule)")
            elif target is None:
                errs.append(f"egress app '{r['app']}' : app inconnue dans le depot")
            elif compute_delivery(target["spec"]) != "native" or target["spec"]["cluster"] != spec["cluster"]:
                errs.append(f"egress app '{r['app']}' : cible non native ou sur un autre cluster")
            else:
                comp = next((c for c in components(target) if c["key"] == wl and c["kind"] != "CronJob"), None)
                if comp is None or not comp["port"]:
                    errs.append(f"egress app '{r['app']}/{wl}' : workload inconnu ou sans port")
                missing = set(spec["environments"]) - set(target["spec"]["environments"])
                if missing:
                    errs.append(f"egress app '{r['app']}' : absente des environnements {sorted(missing)}")
    return errs, warns


def values_errors(values) -> list[str]:
    """Garde-fous sur values.yaml (parcours helm) : privileges, hote, Service expose, secrets."""
    errs = []

    def walk(node, path):
        if isinstance(node, dict):
            for k, v in node.items():
                p = f"{path}.{k}"
                if k in ("hostNetwork", "hostPID", "hostIPC", "privileged", "allowPrivilegeEscalation") and v is True:
                    errs.append(f"values.yaml {p}: true interdit")
                if k == "hostPath":
                    errs.append(f"values.yaml {p}: hostPath interdit")
                if k == "type" and v in ("LoadBalancer", "NodePort"):
                    errs.append(f"values.yaml {p}: Service {v} interdit (ClusterIP seulement)")
                if k == "runAsUser" and v == 0:
                    errs.append(f"values.yaml {p}: runAsUser 0 interdit (securityExceptions non applicable en helm)")
                walk(v, p)
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, f"{path}[{i}]")
        elif isinstance(node, str):
            for pat in SECRET_LIKE_VALUE:
                if pat.search(node):
                    errs.append(f"values.yaml {path}: valeur de type secret detectee (interdit dans Git)")
                    break

    walk(values or {}, "")
    return errs


def semantic_check(doc: dict, dirname: str, cluster_gate_open: bool, ctx: Context) -> tuple[list[str], list[str]]:
    errs: list[str] = []
    warns: list[str] = []
    meta, spec = doc["metadata"], doc["spec"]
    name = meta["name"]

    if name != dirname:
        errs.append(f"metadata.name '{name}' differe du repertoire '{dirname}'")
    if not REF_OK.match(name):
        errs.append(f"nom '{name}' invalide")

    # Choix du parcours (APP-CONTRACT section 3) : calcule, jamais silencieux.
    delivery = compute_delivery(spec)
    if "delivery" in spec and spec["delivery"] != delivery:
        errs.append(f"spec.delivery '{spec['delivery']}' differe du calcul '{delivery}' (APP-CONTRACT section 3)")

    if spec["cluster"] == "oke" and not cluster_gate_open:
        errs.append("cluster oke refuse : gate OKE non franchi (Cilium, baseline #1620, refus IMDS, acces operateur)")
    try:
        caps = ctx.caps(spec["cluster"])
    except AppError as exc:
        return errs + [str(exc)], warns

    for env in spec["environments"]:
        if env not in ALLOWED_ENVIRONMENTS:
            errs.append(f"environnement '{env}' inconnu")

    # Secrets : references seulement, prefixe <NAME>_ impose.
    prefix = name.upper().replace("-", "_") + "_"
    secrets = spec.get("secrets", [])
    keys = [s["key"] for s in secrets]
    envs_secret = [s["env"] for s in secrets]
    if len(set(keys)) != len(keys):
        errs.append("secrets : cle en double")
    if len(set(envs_secret)) != len(envs_secret):
        errs.append("secrets : variable d'environnement en double")
    for s in secrets:
        if not s["key"].startswith(prefix):
            errs.append(f"secret '{s['key']}' : prefixe '{prefix}' obligatoire")
    runtime_env = spec.get("runtime", {}).get("env", {})
    errs += _env_errors("runtime", runtime_env, envs_secret)

    # Identite OIDC (E2).
    oidc = spec.get("identity", {}).get("oidc")
    if oidc:
        provider = oidc.get("provider", "thunderid")
        if provider not in caps["identityProviders"]:
            errs.append(f"identity.oidc.provider '{provider}' non admis sur le cluster '{spec['cluster']}' "
                        f"(admis : {', '.join(caps['identityProviders'])})")
        if oidc["clientSecretKey"] not in keys:
            errs.append(f"identity.oidc.clientSecretKey '{oidc['clientSecretKey']}' absent de secrets[].key")
        if "OAUTH2_CLIENT_ID" in runtime_env:
            errs.append("runtime.env OAUTH2_CLIENT_ID interdit : injecte depuis identity.oidc.clientId")
        groups = oidc.get("allowedGroups")
        if groups and oidc.get("adminGroup") and oidc["adminGroup"] not in groups:
            errs.append(f"identity.oidc.adminGroup '{oidc['adminGroup']}' absent de allowedGroups")
        if "OAUTH2_ADMIN_GROUP" in runtime_env and runtime_env["OAUTH2_ADMIN_GROUP"] != oidc.get("adminGroup"):
            errs.append("runtime.env OAUTH2_ADMIN_GROUP differe de identity.oidc.adminGroup")
        if provider == "authentik":
            host = oidc["issuer"].split("://", 1)[1].split("/", 1)[0].split(":", 1)[0]
            profile, rules = egress_spec(spec)
            if profile != "public-internet" and not any(r.get("fqdn") == host and 443 in r["ports"] for r in rules):
                errs.append(f"identity.oidc authentik : egress {{fqdn: {host}, ports: [443]}} (ou public-internet) requis")

    # Sauvegarde (D-2026-11-14-03) et mecanisme (E9).
    backup = spec["backup"]
    if backup["class"] == "irreplaceable":
        errs.append("backup.class irreplaceable refuse : aucune restauration hors Oracle prouvee")
    mech = backup.get("mechanism", "none")
    if mech not in caps["backupMechanisms"]:
        errs.append(f"backup.mechanism '{mech}' non admis sur le cluster '{spec['cluster']}' "
                    f"(admis : {', '.join(caps['backupMechanisms'])})")
    if mech == "cnpg":
        inst = spec.get("database", {}).get("instance", DB_INSTANCE)
        if "database" not in spec or caps["databaseInstances"].get(inst, {}).get("backup", "none") != "cnpg":
            errs.append("backup.mechanism cnpg : database requise sur une instance sauvegardee (capabilities)")
    if mech == "velero" and not volumes(spec):
        errs.append("backup.mechanism velero : storage requis")

    # Exposition publique.
    exp = spec["exposure"]
    if exp["mode"] == "public" and exp["auth"] == "none":
        errs.append("exposition publique sans authentification interdite")

    # Egress declaratif (E3).
    e_errs, e_warns = egress_errors(doc, ctx, caps)
    errs += e_errs
    warns += e_warns

    if delivery == "native":
        errs += _native_errors(doc, caps, envs_secret, ctx)
    else:
        if exp["mode"] == "public":
            errs.append("parcours helm : exposition publique non livree (HTTPRoute a rendre) : refus")
        if volumes(spec):
            errs.append("parcours helm : storage se declare dans values.yaml, pas dans app.yaml")

    for path, text in _walk_strings(doc):
        for tok in FORBIDDEN_TOKENS:
            if tok in text:
                errs.append(f"{path} : valeur interdite '{tok}'")
    return errs, warns


def _native_errors(doc: dict, caps: dict, envs_secret: list[str], ctx: Context) -> list[str]:
    errs: list[str] = []
    spec = doc["spec"]
    comps = components(doc)
    by_key = {c["key"]: c for c in comps}
    keys = [c["key"] for c in comps]
    if len(set(keys)) != len(keys) or keys.count("main") != 1:
        errs.append("workloads/jobs : nom en double ou 'main' reserve")

    for c in comps[1:]:
        label = f"{'jobs' if c['kind'] == 'CronJob' else 'workloads'}[{c['key']}]"
        errs += _env_errors(label, c["rt"].get("env", {}), [])
        for env in c["secrets"]:
            if env not in envs_secret:
                errs.append(f"{label}.secrets '{env}' absent de spec.secrets[].env")
        if c["database"] and "database" not in spec:
            errs.append(f"{label}.database sans spec.database")
        if c["port"] and c["protocol"] == "TCP" and c["rt"].get("healthPath"):
            errs.append(f"{label} : healthPath sans objet pour un endpoint TCP")

    # Volumes (E8).
    vols = volumes(spec)
    vnames = [v["name"] for v in vols]
    if len(set(vnames)) != len(vnames):
        errs.append("storage : nom de volume en double")
    for v in vols:
        comp = by_key.get(v["workload"])
        if comp is None or comp["kind"] == "CronJob":
            errs.append(f"storage[{v['name']}].workload '{v['workload']}' inconnu (les jobs ne montent pas de volume)")
            continue
        if v["profile"] not in caps["storageClasses"]:
            errs.append(f"storage[{v['name']}] profil '{v['profile']}' non disponible sur le cluster '{spec['cluster']}'")
        if v["profile"] == "block-rwo" and comp["rt"].get("replicas", 1) > 1:
            errs.append(f"PVC RWO : replicas <= 1 (storage present sur '{v['workload']}')")

    # Base (E1).
    if "database" in spec:
        inst = spec["database"].get("instance", DB_INSTANCE)
        if inst not in caps["databaseInstances"]:
            errs.append(f"database.instance '{inst}' non admis sur le cluster '{spec['cluster']}' "
                        f"(admis : {', '.join(sorted(caps['databaseInstances']))})")
    if spec["profile"] == "stateless" and ("database" in spec or vols):
        errs.append("profil stateless avec database ou storage")

    # Exceptions de securite (E12).
    seen = set()
    for i, e in enumerate(spec.get("securityExceptions", [])):
        wl = e.get("workload", "main")
        label = f"securityExceptions[{i}] ({e['rule']}@{wl})"
        if (e["rule"], wl) in seen:
            errs.append(f"{label} : en double")
        seen.add((e["rule"], wl))
        comp = by_key.get(wl)
        if comp is None:
            errs.append(f"{label} : workload inconnu")
        elif e["rule"] == "run-as-root" and not (comp["kind"] == "Deployment" and comp["port"]):
            errs.append(f"{label} : run-as-root seulement pour un Deployment avec endpoint")
        try:
            expires = datetime.date.fromisoformat(e["expires"])
        except ValueError:
            errs.append(f"{label} : date expires invalide")
            continue
        if expires < ctx.today:
            errs.append(f"{label} : exception expiree le {e['expires']} (refus)")
        elif (expires - ctx.today).days > MAX_EXCEPTION_DAYS:
            errs.append(f"{label} : expires au-dela de {MAX_EXCEPTION_DAYS} jours")
        if comp is not None and e["rule"] == "run-as-root" and "runAsUser" in comp["rt"]:
            errs.append(f"{label} : runAsUser incompatible avec run-as-root")

    # Quota de cellule (somme des requests declarees).
    if _requests(doc)[0] > QUOTA_MAX[0] or _requests(doc)[1] > QUOTA_MAX[1]:
        errs.append(f"quota de cellule depasse ({_requests(doc)}) : maximum {QUOTA_MAX} (m CPU, Mi)")
    return errs


def _requests(doc: dict) -> tuple[int, int]:
    cpu = mem = 0
    for c in components(doc):
        n = 1 if c["kind"] == "CronJob" else c["rt"].get("replicas", 1)
        rc, rm = SIZE_REQUESTS[c["rt"]["size"]]
        cpu, mem = cpu + n * rc, mem + n * rm
    return cpu, mem


def semantic_errors(doc: dict, dirname: str, cluster_gate_open: bool, ctx: Context | None = None) -> list[str]:
    ctx = ctx or Context(index={doc["metadata"]["name"]: doc})
    return semantic_check(doc, dirname, cluster_gate_open, ctx)[0]


def validate_all_full(root: Path, cluster_gate_open: bool = False, examples: bool = True,
                      allow_unenforced_fqdn: bool = False, today: datetime.date | None = None):
    """Retourne (nb_apps, erreurs, avertissements). Verifie aussi l'unicite des hotes publics."""
    errors: list[str] = []
    warnings: list[str] = []
    hosts: dict[str, str] = {}
    ctx = Context(clusters_dir=clusters_dir_for(root), allow_unenforced_fqdn=allow_unenforced_fqdn,
                  today=today or datetime.date.today())
    loaded = []
    for d in app_dirs(root, examples=examples):
        label = str(d.relative_to(root) / "app.yaml")
        try:
            doc = load_yaml(d / "app.yaml")
        except yaml.YAMLError as exc:
            errors.append(f"{label}: YAML invalide ({exc.__class__.__name__})")
            continue
        sch = schema_errors(doc)
        errors += [f"{label}: {e}" for e in sch]
        if not sch:
            loaded.append((d, label, doc))
            ctx.index.setdefault(doc["metadata"]["name"], doc)
    for d, label, doc in loaded:
        dirname = doc["metadata"]["name"] if d.parent.name == "_examples" else d.name
        errs, warns = semantic_check(doc, dirname, cluster_gate_open, ctx)
        errors += [f"{label}: {e}" for e in errs]
        warnings += [f"{label}: {w}" for w in warns]
        if compute_delivery(doc["spec"]) == "helm":
            vpath = d / "values.yaml"
            if not vpath.exists():
                errors.append(f"{label}: parcours helm sans values.yaml")
            else:
                errors += [f"{label}: {e}" for e in values_errors(load_yaml(vpath))]
        host = doc["spec"]["exposure"].get("host")
        if host and not str(d).startswith(str(root / "apps" / "_examples")):
            if host in hosts:
                errors.append(f"{label}: hote '{host}' deja utilise par {hosts[host]}")
            hosts[host] = d.name
    return len(loaded), errors, warnings


def validate_all(root: Path, cluster_gate_open: bool = False, examples: bool = True, **kw):
    """Retourne (nb_apps, liste_erreurs)."""
    count = len(app_dirs(root, examples=examples))
    _, errors, _ = validate_all_full(root, cluster_gate_open, examples, **kw)
    return count, errors


# --------------------------------------------------------------------------- platform


class _PlatformLoader(yaml.SafeLoader):
    """Lecture tolerante des fichiers de platform/ qui ne sont pas des objets OpenChoreo (ex. blueprints
    Authentik : tags !Find, !KeyOf). Les tags inconnus donnent None ; seuls CCT/ClusterTrait/CPT sont retenus.
    Les descripteurs d'applications restent lus par yaml.safe_load (tag inconnu = erreur)."""


_PlatformLoader.add_multi_constructor("!", lambda loader, suffix, node: None)


def load_platform(platform_dir: Path) -> dict[tuple[str, str], dict]:
    """Indexe les objets de plateforme (CCT, ClusterTrait, ClusterProjectType) par (kind, name)."""
    index: dict[tuple[str, str], dict] = {}
    if not platform_dir.is_dir():
        raise AppError(f"dossier plateforme absent : {platform_dir} (CCT et ClusterTrait requis)")
    for path in sorted(platform_dir.rglob("*.yaml")):
        for doc in yaml.load_all(path.read_text(encoding="utf-8"), Loader=_PlatformLoader):  # noqa: S506 (SafeLoader)
            if not isinstance(doc, dict):
                continue
            kind = doc.get("kind")
            if kind in ("ClusterComponentType", "ClusterTrait", "ClusterProjectType"):
                index[(kind, doc["metadata"]["name"])] = doc
    return index


def _declared_params(obj: dict, section: str = "parameters") -> set[str] | None:
    schema = ((obj.get("spec") or {}).get(section) or {}).get("openAPIV3Schema") or {}
    props = schema.get("properties")
    return set(props) if isinstance(props, dict) else None


def _require_params(obj: dict, label: str, params: dict, section: str = "parameters") -> None:
    """Refuse un parametre non declare par l'objet de plateforme (evite un rejet ou un elagage silencieux)."""
    declared = _declared_params(obj, section)
    unknown = sorted(set(params) - (declared or set()))
    if unknown:
        raise AppError(f"{label} : parametre(s) {unknown} non declare(s) dans {section} (a livrer par platform/)")


# --------------------------------------------------------------------------- rendu natif


def _env_list(spec: dict, comp: dict) -> list[dict]:
    rt = comp["rt"]
    items = [{"key": k, "value": str(v)} for k, v in rt.get("env", {}).items()]
    oidc = spec.get("identity", {}).get("oidc")
    if oidc and comp["main"]:
        items.append({"key": "OAUTH2_CLIENT_ID", "value": oidc["clientId"]})
    for s in spec.get("secrets", []):
        if s["env"] in comp["secrets"]:
            items.append({
                "key": s["env"],
                "valueFrom": {"secretKeyRef": {"name": f"{spec['_name']}-secrets", "key": s["env"]}},
            })
    return items


def _release_name(component_spec: dict, cname: str) -> str:
    digest = hashlib.sha256(json.dumps(component_spec, sort_keys=True).encode()).hexdigest()
    return f"{cname}-{digest[:10]}"


def _cct(platform: dict, ref: str) -> dict:
    wtype, short = ref.split("/", 1)
    cct = platform.get(("ClusterComponentType", short))
    if cct is None:
        raise AppError(f"ClusterComponentType '{short}' introuvable dans platform/")
    if cct["spec"].get("workloadType") != wtype:
        raise AppError(f"ClusterComponentType '{short}' : workloadType '{cct['spec'].get('workloadType')}' != '{wtype}'")
    return cct


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
    out = {}
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


def egress_objects(name: str, env: str, namespace: str, params: dict, rules: list[dict], cilium: bool,
                   annotations: dict) -> list[dict]:
    """NetworkPolicy (CIDR, apps) et CiliumNetworkPolicy (FQDN) equivalentes aux parametres egress."""
    objs = []
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


def project_params(doc: dict, caps: dict, index: dict) -> dict:
    spec = doc["spec"]
    net = spec["network"]
    profile, _ = egress_spec(spec)
    params = {"egress": profile, "database": "database" in spec, "allowIdp": bool(net.get("allowIdp", False))}
    params.update(egress_project_params(doc, caps, index))
    inst = spec.get("database", {}).get("instance", DB_INSTANCE)
    if "database" in spec and inst != DB_INSTANCE:
        params["databaseNamespace"] = caps["databaseInstances"][inst]["namespace"]
        params["databaseCluster"] = caps["databaseInstances"][inst]["cluster"]
    npvc = len(volumes(spec))
    cpu, mem = _requests(doc)
    if npvc or cpu > QUOTA_DEFAULT[0] or mem > QUOTA_DEFAULT[1]:
        params["quota"] = {"cpu": f"{max(cpu, QUOTA_DEFAULT[0])}m", "memory": f"{max(mem, QUOTA_DEFAULT[1])}Mi",
                           "pvcs": str(npvc)}
    if any(e["rule"] == "run-as-root" for e in spec.get("securityExceptions", [])):
        params["podSecurity"] = "baseline"   # namespace de CETTE cellule seulement ; jamais global
    return params


def render_component(doc: dict, comp: dict, platform: dict, caps: dict, targeted: set, rendered: dict) -> None:
    spec = doc["spec"]
    name = doc["metadata"]["name"]
    cname = comp["cname"]
    rt = comp["rt"]
    base = f"namespaces/{NS}/projects/{name}"
    exc = exceptions_for(spec, comp["key"])
    vols = [v for v in volumes(spec) if v["workload"] == comp["key"]]

    if "run-as-root" in exc:
        cct_ref = ROOT_EXCEPTION_CCT
    else:
        cct_ref = CCT_BY_KIND[(comp["kind"], bool(comp["port"]))]
    cct = _cct(platform, cct_ref)

    params: dict = {}
    if "run-as-root" not in exc:
        params["runAsUser"] = rt.get("runAsUser", 65532)
    if comp["kind"] == "Deployment":
        has_rwo = any(v["profile"] == "block-rwo" for v in vols)
        default = "Recreate" if vols else "RollingUpdate"
        strategy = spec.get("update", {}).get("strategy", default) if comp["main"] else ("Recreate" if has_rwo else "RollingUpdate")
        params["strategy"] = strategy
    if comp["port"] and comp["kind"] == "Deployment":
        exp = spec["exposure"]
        params["publicAuth"] = exp["auth"] if comp["main"] and exp["mode"] == "public" else "none"
    if comp["kind"] == "CronJob":
        params["concurrencyPolicy"] = "Forbid"
        if comp.get("timeZone"):
            params["timeZone"] = comp["timeZone"]
    if "writable-rootfs" in exc:
        params["readOnlyRootFilesystem"] = False
    _require_params(cct, f"ClusterComponentType '{cct_ref}'", params)

    traits_ref: list[dict] = []
    traits_profile: list[dict] = []
    traits_release: dict[str, dict] = {}
    trait_env: dict = {}
    for v in vols:
        tname = PVC_TRAIT_BY_KIND[comp["kind"]]
        trait = platform.get(("ClusterTrait", tname))
        if trait is None:
            raise AppError(f"ClusterTrait '{tname}' introuvable dans platform/")
        tparams = {"mountPath": v["mountPath"]}
        if v["profile"] != "block-rwo":
            tparams["accessMode"] = ACCESS_MODE[v["profile"]]
        if v["readOnly"]:
            tparams["readOnly"] = True
        _require_params(trait, f"ClusterTrait '{tname}'", tparams)
        traits_ref.append({"kind": "ClusterTrait", "name": tname, "instanceName": v["name"], "parameters": tparams})
        traits_profile.append({"instanceName": v["name"], "kind": "ClusterTrait", "name": tname, "parameters": tparams})
        traits_release[tname] = {"kind": "ClusterTrait", "name": tname, "spec": trait["spec"]}
        trait_env[v["name"]] = {"size": v["size"], "storageClass": caps["storageClasses"][v["profile"]]}

    rendered[f"{base}/components/{cname}/component.yaml"] = {
        "apiVersion": "openchoreo.dev/v1alpha1", "kind": "Component",
        "metadata": {"name": cname, "namespace": NS},
        "spec": {
            "owner": {"projectName": name},
            "componentType": {"kind": "ClusterComponentType", "name": cct_ref},
            "autoDeploy": False,
            "parameters": params,
            **({"traits": traits_ref} if traits_ref else {}),
        },
    }

    container = {"image": comp["image"], "env": _env_list(spec, comp)}
    if rt.get("command"):
        container["command"] = rt["command"]
    if rt.get("args"):
        container["args"] = rt["args"]
    workload_spec: dict = {"owner": {"projectName": name, "componentName": cname}, "container": container}
    if comp["port"]:
        if comp["main"]:
            vis = ["external"] if spec["exposure"]["mode"] == "public" else ["internal"]
        else:
            vis = ["project"]
        if (name, comp["key"]) in targeted:
            vis = vis + ["namespace"]
        workload_spec["endpoints"] = {"http" if comp["protocol"] == "HTTP" else "tcp":
                                      {"type": comp["protocol"], "port": comp["port"], "visibility": vis}}
    deps: dict = {}
    if comp["database"]:
        deps["resources"] = [{"ref": f"{name}-db", "envBindings": {"url": spec["database"].get("envVar", "DATABASE_URL")}}]
    if comp["main"]:
        conns = []
        for r in egress_spec(spec)[1]:
            if "app" in r:
                target = rendered["__index__"][r["app"]]
                tcomp = next(c for c in components(target) if c["key"] == r.get("workload", "main"))
                conns.append({"project": r["app"], "component": tcomp["cname"],
                              "name": "http" if tcomp["protocol"] == "HTTP" else "tcp", "visibility": "namespace",
                              "envBindings": {"address": r.get("envVar", r["app"].upper().replace("-", "_") + "_URL")}})
        if conns:
            deps["endpoints"] = conns
    if deps:
        workload_spec["dependencies"] = deps
    rendered[f"{base}/components/{cname}/workload.yaml"] = {
        "apiVersion": "openchoreo.dev/v1alpha1", "kind": "Workload",
        "metadata": {"name": f"{cname}-workload", "namespace": NS}, "spec": workload_spec,
    }

    # ComponentRelease : contenu fige (CCT, traits, workload, profil). Nom = hash du contenu (deterministe).
    release_spec = {
        "owner": {"componentName": cname, "projectName": name},
        "componentType": {"kind": "ClusterComponentType", "name": cct_ref, "spec": cct["spec"]},
        "workload": {k: v for k, v in workload_spec.items() if k != "owner"},
        "componentProfile": {"parameters": params, "traits": traits_profile},
    }
    if traits_release:
        release_spec["traits"] = [traits_release[k] for k in sorted(traits_release)]
    rel = _release_name(release_spec, cname)
    rendered[f"{base}/components/{cname}/releases/{rel}.yaml"] = {
        "apiVersion": "openchoreo.dev/v1alpha1", "kind": "ComponentRelease",
        "metadata": {"name": rel, "namespace": NS}, "spec": release_spec,
    }
    if comp["kind"] == "CronJob":
        env_cfg = {"size": rt["size"], "schedule": comp["schedule"]}
    else:
        env_cfg = {"size": rt["size"], "replicas": rt.get("replicas", 1)}
    for env in spec["environments"]:
        rb_spec = {
            "owner": {"projectName": name, "componentName": cname},
            "environment": env,
            "releaseName": rel,
            "componentTypeEnvironmentConfigs": env_cfg,
        }
        if trait_env:
            rb_spec["traitEnvironmentConfigs"] = trait_env
        rendered[f"{base}/components/{cname}/release-bindings/{cname}-{env}.yaml"] = {
            "apiVersion": "openchoreo.dev/v1alpha1", "kind": "ReleaseBinding",
            "metadata": {"name": f"{cname}-{env}", "namespace": NS}, "spec": rb_spec,
        }


def render_native(doc: dict, platform: dict[tuple[str, str], dict], cluster: str, pins: dict,
                  caps: dict | None = None, index: dict | None = None) -> dict[str, object]:
    spec = copy.deepcopy(doc["spec"])
    meta = doc["metadata"]
    name = meta["name"]
    spec["_name"] = name
    doc = {**doc, "spec": spec}
    caps = caps if caps is not None else load_capabilities(ROOT / "clusters", cluster)
    index = index if index is not None else {name: doc}
    has_db = "database" in spec
    envs = spec["environments"]
    files: dict[str, object] = {}
    base = f"namespaces/{NS}/projects/{name}"

    pparams = project_params(doc, caps, index)
    ext = sorted(set(pparams) & set(CPT_EXT_PARAMS))
    if ext:
        cpt = platform.get(("ClusterProjectType", PROJECT_TYPE))
        if cpt is None:
            raise AppError(f"ClusterProjectType '{PROJECT_TYPE}' introuvable dans platform/ (requis pour {ext})")
        _require_params(cpt, f"ClusterProjectType '{PROJECT_TYPE}'", pparams)
    annotations = {"openchoreo.dev/description": meta["description"]}
    files[f"{base}/project.yaml"] = {
        "apiVersion": "openchoreo.dev/v1alpha1", "kind": "Project",
        "metadata": {"name": name, "namespace": NS, "annotations": annotations, "labels": {"openchoreo.dev/name": name}},
        "spec": {
            "deploymentPipelineRef": {"name": PIPELINE},
            "type": {"kind": "ClusterProjectType", "name": PROJECT_TYPE},
            "parameters": pparams,
        },
    }
    for env in envs:
        files[f"{base}/project-bindings/{name}-{env}.yaml"] = {
            "apiVersion": "openchoreo.dev/v1alpha1", "kind": "ProjectReleaseBinding",
            "metadata": {"name": f"{name}-{env}", "namespace": NS,
                         "labels": {"openchoreo.dev/project": name, "openchoreo.dev/environment": env}},
            "spec": {"owner": {"projectName": name}, "environment": env},
        }

    targeted = egress_targets(index)
    scratch: dict = {"__index__": index}
    for comp in components(doc):
        render_component(doc, comp, platform, caps, targeted, scratch)
    scratch.pop("__index__")
    files.update(scratch)

    if spec.get("secrets"):
        files[f"{base}/secret-references/{name}-secrets.yaml"] = {
            "apiVersion": "openchoreo.dev/v1alpha1", "kind": "SecretReference",
            "metadata": {"name": f"{name}-secrets", "namespace": NS},
            "spec": {
                "template": {"type": "Opaque"},
                "data": [
                    {"secretKey": s["env"],
                     "remoteRef": {"key": s["key"], **({"property": s["property"]} if "property" in s else {})}}
                    for s in spec["secrets"]
                ],
            },
        }

    if has_db:
        db = spec["database"]
        dbname = name.replace("-", "_")
        passkey = name.upper().replace("-", "_") + "_PG_PASSWORD"
        crt = caps["databaseInstances"][db.get("instance", DB_INSTANCE)]["resourceType"]
        files[f"{base}/resources/{name}-db.yaml"] = {
            "apiVersion": "openchoreo.dev/v1alpha1", "kind": "Resource",
            "metadata": {"name": f"{name}-db", "namespace": NS},
            "spec": {
                "owner": {"projectName": name},
                "type": {"kind": "ClusterResourceType", "name": crt},
                "parameters": {"database": dbname, "passwordKey": passkey},
            },
        }
        for env in envs:
            rrb_spec = {
                "owner": {"projectName": name, "resourceName": f"{name}-db"},
                "environment": env,
                "retainPolicy": "Retain",
            }
            pin = pins.get(f"{name}/{env}")
            if pin:
                rrb_spec["resourceRelease"] = pin  # absent tant que non epingle : le binding reste en attente
            files[f"{base}/resource-bindings/{name}-db-{env}.yaml"] = {
                "apiVersion": "openchoreo.dev/v1alpha1", "kind": "ResourceReleaseBinding",
                "metadata": {"name": f"{name}-db-{env}", "namespace": NS}, "spec": rrb_spec,
            }

    # Apercu (non synchronise) des politiques egress que le CPT rendra : relu en PR, valide par kubeconform.
    _, rules = egress_spec(spec)
    if rules:
        note = {"platform.smadja.dev/preview": "rendu par le ClusterProjectType cell-restricted ; non applique tel quel"}
        for env in envs:
            ns = f"dp-{NS}-{name}-{env}"
            for obj in egress_objects(name, env, ns, egress_project_params(doc, caps, index), rules, caps["cilium"], note):
                files[f"previews/{name}/{env}/{obj['kind'].lower()}-{obj['metadata']['name']}.yaml"] = obj

    files[f"catalog/{name}/catalog-info.yaml"] = catalog_entity(doc)
    return files


def catalog_entity(doc: dict, extra: dict | None = None) -> dict:
    meta, spec = doc["metadata"], doc["spec"]
    native = compute_delivery(spec) == "native"
    annotations = {"openchoreo.dev/managed": "true" if native else "false"}
    oidc = spec.get("identity", {}).get("oidc", {})
    if oidc.get("allowedGroups"):
        annotations["platform.smadja.dev/oidc-provider"] = oidc.get("provider", "thunderid")
        annotations["platform.smadja.dev/oidc-allowed-groups"] = ",".join(oidc["allowedGroups"])
    if spec["backup"].get("mechanism", "none") != "none":
        annotations["platform.smadja.dev/backup"] = f"{spec['backup']['mechanism']}/{spec['backup']['retention']}"
    if spec.get("securityExceptions"):
        annotations["platform.smadja.dev/security-exceptions"] = ",".join(
            f"{e['rule']}@{e.get('workload', 'main')}:{e['expires']}" for e in spec["securityExceptions"])
    annotations.update(extra or {})
    return {
        "apiVersion": "backstage.io/v1alpha1", "kind": "Component",
        "metadata": {
            "name": meta["name"], "description": meta["description"],
            "annotations": annotations,
            **({"links": [{"url": meta["docs"]}]} if "docs" in meta else {}),
        },
        "spec": {"type": "service", "lifecycle": meta.get("lifecycle", "experimental"), "owner": meta["owner"]},
    }


# --------------------------------------------------------------------------- rendu helm (Argo CD)


PSA_LABELS = {
    "pod-security.kubernetes.io/enforce": "restricted",
    "pod-security.kubernetes.io/enforce-version": "latest",
    "pod-security.kubernetes.io/warn": "restricted",
    "pod-security.kubernetes.io/audit": "restricted",
}


def helm_namespace(name: str, env: str) -> str:
    return f"lab-{name}-{env}"


def render_helm(doc: dict, caps: dict | None = None) -> dict[str, object]:
    """Application Argo CD multi-source (chart epingle + values.yaml + garde-fous), sans OpenChoreo."""
    meta, spec = doc["metadata"], doc["spec"]
    name = meta["name"]
    caps = caps if caps is not None else load_capabilities(ROOT / "clusters", spec["cluster"])
    chart = spec["source"]["chart"]
    oci = chart["repo"].startswith("oci://")
    files: dict[str, object] = {}
    profile, rules = egress_spec(spec)
    for env in spec["environments"]:
        ns = helm_namespace(name, env)
        rdir = f"helm/{name}/{env}/resources"
        res: list[dict] = [
            {"apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
             "metadata": {"name": "default-deny", "namespace": ns},
             "spec": {"podSelector": {}, "policyTypes": ["Ingress", "Egress"]}},
            {"apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
             "metadata": {"name": "allow-dns-and-namespace", "namespace": ns},
             "spec": {"podSelector": {}, "policyTypes": ["Ingress", "Egress"],
                      "ingress": [{"from": [{"podSelector": {}}]}],
                      "egress": [{"to": [{"podSelector": {}}]},
                                 {"to": [{"namespaceSelector": {"matchLabels": {"kubernetes.io/metadata.name": "kube-system"}},
                                          "podSelector": {"matchLabels": {"k8s-app": "kube-dns"}}}],
                                  "ports": [{"protocol": "UDP", "port": 53}, {"protocol": "TCP", "port": 53}]}]}},
            {"apiVersion": "v1", "kind": "ResourceQuota", "metadata": {"name": "no-exposed-services", "namespace": ns},
             "spec": {"hard": {"services.loadbalancers": "0", "services.nodeports": "0"}}},
        ]
        if profile == "public-internet":
            res.append({"apiVersion": "networking.k8s.io/v1", "kind": "NetworkPolicy",
                        "metadata": {"name": "egress-public-internet", "namespace": ns},
                        "spec": {"podSelector": {}, "policyTypes": ["Egress"],
                                 "egress": [{"to": [{"ipBlock": {"cidr": "0.0.0.0/0", "except": [str(p) for p in PRIVATE_NETS]}}],
                                             "ports": [{"protocol": "TCP", "port": 80}, {"protocol": "TCP", "port": 443}]}]}})
        if rules:
            res += egress_objects(name, env, ns, egress_project_params(doc, caps, {}), rules, caps["cilium"], {})
        if spec.get("secrets"):
            res.append({"apiVersion": "external-secrets.io/v1", "kind": "ExternalSecret",
                        "metadata": {"name": f"{name}-secrets", "namespace": ns},
                        "spec": {"refreshInterval": "1h",
                                 "secretStoreRef": {"kind": "ClusterSecretStore", "name": caps["secretStore"]},
                                 "target": {"name": f"{name}-secrets", "creationPolicy": "Owner"},
                                 "data": [{"secretKey": s["env"], "remoteRef": {"key": s["key"],
                                           **({"property": s["property"]} if "property" in s else {})}}
                                          for s in spec["secrets"]]}})
        for obj in res:
            files[f"{rdir}/{obj['kind'].lower()}-{obj['metadata']['name']}.yaml"] = obj
        files[f"helm/{name}/{env}/application.yaml"] = {
            "apiVersion": "argoproj.io/v1alpha1", "kind": "Application",
            # Pas de finalizer resources-finalizer : supprimer l'Application CONSERVE les ressources
            # (equivalent de preserveResourcesOnDeletion, qui n'existe que sur ApplicationSet).
            "metadata": {"name": f"{name}-{env}", "namespace": ARGO_NAMESPACE,
                         "labels": {"platform.smadja.dev/app": name, "platform.smadja.dev/delivery": "helm"},
                         "annotations": {"platform.smadja.dev/chart-digest": chart["digest"],
                                         "platform.smadja.dev/managed-by": "argocd (hors OpenChoreo)"}},
            "spec": {
                "project": ARGO_PROJECT_HELM,
                "sources": [
                    {"repoURL": chart["repo"][len("oci://"):] if oci else chart["repo"], "chart": chart["name"],
                     "targetRevision": chart["version"],
                     "helm": {"releaseName": name, "valueFiles": [f"$values/apps/{name}/values.yaml"]}},
                    {"repoURL": GITOPS_REPO, "targetRevision": GITOPS_REVISION, "ref": "values"},
                    {"repoURL": GITOPS_REPO, "targetRevision": GITOPS_REVISION, "path": f"generated/{rdir}"},
                ],
                "destination": {"server": "https://kubernetes.default.svc", "namespace": ns},
                "syncPolicy": {
                    "automated": {"prune": False, "selfHeal": True},
                    "managedNamespaceMetadata": {"labels": dict(PSA_LABELS)},
                    "syncOptions": ["CreateNamespace=true", "FailOnSharedResource=true", "PruneLast=true",
                                    "ServerSideApply=true"],
                },
            },
        }
    files[f"catalog/{name}/catalog-info.yaml"] = catalog_entity(doc, {
        "argocd/app-name": ",".join(f"{name}-{e}" for e in spec["environments"]),
        "platform.smadja.dev/chart": f"{chart['repo']}/{chart['name']}:{chart['version']}",
    })
    return files


def render_all(root: Path, platform_dir: Path, cluster_gate_open: bool = False,
               allow_unenforced_fqdn: bool = False, today: datetime.date | None = None) -> dict[str, object]:
    _, errors, _ = validate_all_full(root, cluster_gate_open, examples=False,
                                     allow_unenforced_fqdn=allow_unenforced_fqdn, today=today)
    if errors:
        raise AppError("\n".join(errors))
    platform = load_platform(platform_dir)
    pins = load_pins(root)
    cdir = clusters_dir_for(root)
    docs = [load_yaml(d / "app.yaml") for d in app_dirs(root)]
    index = {doc["metadata"]["name"]: doc for doc in docs}
    files: dict[str, object] = {}
    for doc in docs:
        caps = load_capabilities(cdir, doc["spec"]["cluster"])
        if compute_delivery(doc["spec"]) == "helm":
            files.update(render_helm(doc, caps))
        else:
            files.update(render_native(doc, platform, doc["spec"]["cluster"], pins, caps, index))
    return files


def write_tree(files: dict[str, object], out: Path) -> None:
    for rel in sorted(files):
        target = out / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        body = yaml.safe_dump(files[rel], sort_keys=False, allow_unicode=True, width=4096)
        header = "# Genere par tools/appgen (ne pas editer a la main). Source : apps/*/app.yaml.\n"
        target.write_text(header + body, encoding="utf-8")


def load_pins(root: Path) -> dict[str, str]:
    path = root / "pins" / "resource-releases.yaml"
    if not path.exists():
        return {}
    data = load_yaml(path) or {}
    return {str(k): str(v) for k, v in (data.get("pins") or {}).items()}


def diff_trees(expected: Path, actual: Path) -> list[str]:
    """Liste les differences entre deux arborescences generees (fichiers ajoutes, retires, modifies)."""
    def listing(base: Path) -> set[str]:
        return {str(p.relative_to(base)) for p in base.rglob("*") if p.is_file()} if base.exists() else set()

    a, b = listing(expected), listing(actual)
    diffs = [f"absent de generated/ : {x}" for x in sorted(a - b)]
    diffs += [f"fichier en trop dans generated/ : {x}" for x in sorted(b - a)]
    for common in sorted(a & b):
        if not filecmp.cmp(expected / common, actual / common, shallow=False):
            diffs.append(f"modifie : {common}")
    return diffs


# --------------------------------------------------------------------------- CLI


def cmd_validate(args) -> int:
    count = len(app_dirs(ROOT, examples=True))
    _, errors, warnings = validate_all_full(ROOT, args.allow_oke, allow_unenforced_fqdn=args.allow_unenforced_fqdn)
    for w in warnings:
        print(f"AVERTISSEMENT {w}", file=sys.stderr)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        print(f"appgen validate : ECHEC ({len(errors)} erreur(s) sur {count} app(s))", file=sys.stderr)
        return 1
    print(f"appgen validate : OK ({count} app(s))")
    return 0


def cmd_render(args) -> int:
    out = Path(args.out) if args.out else ROOT / "generated"
    try:
        files = render_all(ROOT, Path(args.platform_dir), args.allow_oke, args.allow_unenforced_fqdn)
    except AppError as exc:
        print(f"appgen render : ECHEC\n{exc}", file=sys.stderr)
        return 1
    if out.exists():
        shutil.rmtree(out)
    write_tree(files, out)
    print(f"appgen render : {len(files)} fichier(s) ecrits sous {out}")
    return 0


def cmd_check(args) -> int:
    try:
        files = render_all(ROOT, Path(args.platform_dir), args.allow_oke, args.allow_unenforced_fqdn)
    except AppError as exc:
        print(f"appgen check : ECHEC\n{exc}", file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory() as tmp:
        tmp_out = Path(tmp) / "generated"
        write_tree(files, tmp_out)
        diffs = diff_trees(tmp_out, ROOT / "generated")
    if diffs:
        print("appgen check : DERIVE (lancer tools/appgen render et committer)", file=sys.stderr)
        print("\n".join(diffs), file=sys.stderr)
        return 1
    print(f"appgen check : OK, aucune derive ({len(files)} fichier(s))")
    return 0


def cmd_pin_resource(args) -> int:
    """Pin de ResourceReleaseBinding : valeur lue par l'operateur (kubectl get resource ... status.latestRelease.name)."""
    if not re.fullmatch(rf"{re.escape(args.app)}-db-[a-z0-9]+", args.release):
        print(f"pin-resource : '{args.release}' ne ressemble pas a une ResourceRelease de {args.app}-db", file=sys.stderr)
        return 1
    PINS_PATH.parent.mkdir(parents=True, exist_ok=True)
    data = load_yaml(PINS_PATH) if PINS_PATH.exists() else None
    pins = dict((data or {}).get("pins") or {})
    pins[f"{args.app}/{args.env}"] = args.release
    PINS_PATH.write_text(
        "# Pins ResourceRelease (2e PR d'une base). Ecrit par tools/appgen pin-resource.\n"
        + yaml.safe_dump({"pins": dict(sorted(pins.items()))}, sort_keys=False),
        encoding="utf-8",
    )
    print(f"pin-resource : {args.app}/{args.env} -> {args.release} (relancer render puis committer)")
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="appgen", description=__doc__.split("\n")[0])
    parser.add_argument("--platform-dir", default=str(ROOT / "platform"),
                        help="dossier contenant ClusterComponentType, ClusterTrait, ClusterProjectType (defaut : platform/)")
    parser.add_argument("--allow-oke", action="store_true", help="ouvrir le gate OKE (ne pas utiliser avant gate)")
    parser.add_argument("--allow-unenforced-fqdn", action="store_true",
                        help="labo seulement : egress FQDN sur cluster sans Cilium -> avertissement, apercu marque "
                             "enforced=false, regles NON transmises (flux refuses)")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("validate").set_defaults(func=cmd_validate)
    p_render = sub.add_parser("render")
    p_render.add_argument("--out", default=None)
    p_render.set_defaults(func=cmd_render)
    sub.add_parser("check").set_defaults(func=cmd_check)
    p_pin = sub.add_parser("pin-resource")
    p_pin.add_argument("app")
    p_pin.add_argument("env", choices=sorted(ALLOWED_ENVIRONMENTS))
    p_pin.add_argument("release")
    p_pin.set_defaults(func=cmd_pin_resource)
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
