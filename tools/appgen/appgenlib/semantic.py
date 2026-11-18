"""Regles semantiques d'une app (au-dela du schema JSON).

Role : appliquer APP-CONTRACT a un app.yaml deja conforme au schema : nom, parcours, gate OKE, environnements,
secrets, identite OIDC, sauvegarde, exposition, egress, composants natifs (workloads, volumes, base, exceptions,
quota), valeurs interdites. L'ordre des messages est fige (tests de caracterisation).
Entrees : document app.yaml, nom du repertoire, etat du gate OKE, Context (politiques, index, date du jour).
Sorties : (erreurs, avertissements) ; aucune E/S hors lecture des politiques de cluster via Context.
"""
from __future__ import annotations

import datetime

from appgenlib.config import (
    ALLOWED_ENVIRONMENTS,
    DB_INSTANCE,
    FORBIDDEN_TOKENS,
    MAX_EXCEPTION_DAYS,
    QUOTA_MAX,
    REF_OK,
)
from appgenlib.egress import egress_errors
from appgenlib.model import (
    AppError,
    Context,
    _requests,
    _walk_strings,
    components,
    compute_delivery,
    egress_spec,
    volumes,
)
from appgenlib.schema import _env_errors


def _identity_errors(name: str, dirname: str, spec: dict, cluster_gate_open: bool) -> list[str]:
    """Nom, parcours declare contre parcours calcule (APP-CONTRACT section 3), gate OKE."""
    errs = []
    if name != dirname:
        errs.append(f"metadata.name '{name}' differe du repertoire '{dirname}'")
    if not REF_OK.match(name):
        errs.append(f"nom '{name}' invalide")
    delivery = compute_delivery(spec)
    if "delivery" in spec and spec["delivery"] != delivery:
        errs.append(f"spec.delivery '{spec['delivery']}' differe du calcul '{delivery}' (APP-CONTRACT section 3)")
    if spec["cluster"] == "oke" and not cluster_gate_open:
        errs.append("cluster oke refuse : gate OKE non franchi (Cilium, baseline #1620, refus IMDS, acces operateur)")
    return errs


def _secret_errors(name: str, spec: dict) -> list[str]:
    """Secrets : references seulement, prefixe <NAME>_ impose, sans doublon ; env runtime sans secret."""
    errs = []
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
    errs += _env_errors("runtime", spec.get("runtime", {}).get("env", {}), envs_secret)
    return errs


def _authentik_errors(spec: dict, oidc: dict) -> list[str]:
    """Fournisseur authentik : l'egress doit joindre l'emetteur en 443 (ou public-internet)."""
    host = oidc["issuer"].split("://", 1)[1].split("/", 1)[0].split(":", 1)[0]
    profile, rules = egress_spec(spec)
    if profile != "public-internet" and not any(r.get("fqdn") == host and 443 in r["ports"] for r in rules):
        return [f"identity.oidc authentik : egress {{fqdn: {host}, ports: [443]}} (ou public-internet) requis"]
    return []


def _oidc_errors(spec: dict, caps: dict) -> list[str]:
    """Identite OIDC (E2)."""
    oidc = spec.get("identity", {}).get("oidc")
    if not oidc:
        return []
    errs = []
    keys = [s["key"] for s in spec.get("secrets", [])]
    runtime_env = spec.get("runtime", {}).get("env", {})
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
        errs += _authentik_errors(spec, oidc)
    return errs


def _backup_errors(spec: dict, caps: dict) -> list[str]:
    """Sauvegarde (D-2026-11-14-03) et mecanisme (E9)."""
    errs = []
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
    return errs


def _delivery_errors(doc: dict, caps: dict, ctx: Context) -> list[str]:
    """Regles propres au parcours : composants natifs, ou limites du parcours helm."""
    spec = doc["spec"]
    if compute_delivery(spec) == "native":
        return _native_errors(doc, caps, [s["env"] for s in spec.get("secrets", [])], ctx)
    errs = []
    if spec["exposure"]["mode"] == "public":
        errs.append("parcours helm : exposition publique non livree (HTTPRoute a rendre) : refus")
    if volumes(spec):
        errs.append("parcours helm : storage se declare dans values.yaml, pas dans app.yaml")
    return errs


def _forbidden_token_errors(doc: dict) -> list[str]:
    return [f"{path} : valeur interdite '{tok}'" for path, text in _walk_strings(doc) for tok in FORBIDDEN_TOKENS
            if tok in text]


def semantic_check(doc: dict, dirname: str, cluster_gate_open: bool, ctx: Context) -> tuple[list[str], list[str]]:
    spec = doc["spec"]
    errs = _identity_errors(doc["metadata"]["name"], dirname, spec, cluster_gate_open)
    try:
        caps = ctx.caps(spec["cluster"])
    except AppError as exc:
        return [*errs, str(exc)], []
    errs += [f"environnement '{env}' inconnu" for env in spec["environments"] if env not in ALLOWED_ENVIRONMENTS]
    errs += _secret_errors(doc["metadata"]["name"], spec)
    errs += _oidc_errors(spec, caps)
    errs += _backup_errors(spec, caps)
    if spec["exposure"]["mode"] == "public" and spec["exposure"]["auth"] == "none":
        errs.append("exposition publique sans authentification interdite")
    e_errs, warns = egress_errors(doc, ctx, caps)
    errs += e_errs
    errs += _delivery_errors(doc, caps, ctx)
    errs += _forbidden_token_errors(doc)
    return errs, warns


def _component_errors(spec: dict, comps: list[dict], envs_secret: list[str]) -> list[str]:
    """Workloads (E6) et jobs (E7) : noms, env, secrets references, base, healthPath TCP."""
    errs = []
    keys = [c["key"] for c in comps]
    if len(set(keys)) != len(keys) or keys.count("main") != 1:
        errs.append("workloads/jobs : nom en double ou 'main' reserve")
    for c in comps[1:]:
        label = f"{'jobs' if c['kind'] == 'CronJob' else 'workloads'}[{c['key']}]"
        errs += _env_errors(label, c["rt"].get("env", {}), [])
        errs += [f"{label}.secrets '{env}' absent de spec.secrets[].env" for env in c["secrets"]
                 if env not in envs_secret]
        if c["database"] and "database" not in spec:
            errs.append(f"{label}.database sans spec.database")
        if c["port"] and c["protocol"] == "TCP" and c["rt"].get("healthPath"):
            errs.append(f"{label} : healthPath sans objet pour un endpoint TCP")
    return errs


def _volume_errors(spec: dict, vols: list[dict], by_key: dict, caps: dict) -> list[str]:
    """Volumes (E8) : nom unique, workload qui monte, profil disponible, RWO mono-replica."""
    errs = []
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
    return errs


def _database_errors(spec: dict, vols: list[dict], caps: dict) -> list[str]:
    """Base (E1) : instance admise ; profil stateless sans base ni volume."""
    errs = []
    if "database" in spec:
        inst = spec["database"].get("instance", DB_INSTANCE)
        if inst not in caps["databaseInstances"]:
            errs.append(f"database.instance '{inst}' non admis sur le cluster '{spec['cluster']}' "
                        f"(admis : {', '.join(sorted(caps['databaseInstances']))})")
    if spec["profile"] == "stateless" and ("database" in spec or vols):
        errs.append("profil stateless avec database ou storage")
    return errs


def _exception_errors(label: str, e: dict, comp: dict | None, today: datetime.date) -> list[str]:
    """Une exception de securite (E12) : workload, portee de run-as-root, date d'expiration, runAsUser."""
    errs = []
    if comp is None:
        errs.append(f"{label} : workload inconnu")
    elif e["rule"] == "run-as-root" and not (comp["kind"] == "Deployment" and comp["port"]):
        errs.append(f"{label} : run-as-root seulement pour un Deployment avec endpoint")
    try:
        expires = datetime.date.fromisoformat(e["expires"])
    except ValueError:
        return [*errs, f"{label} : date expires invalide"]
    if expires < today:
        errs.append(f"{label} : exception expiree le {e['expires']} (refus)")
    elif (expires - today).days > MAX_EXCEPTION_DAYS:
        errs.append(f"{label} : expires au-dela de {MAX_EXCEPTION_DAYS} jours")
    if comp is not None and e["rule"] == "run-as-root" and "runAsUser" in comp["rt"]:
        errs.append(f"{label} : runAsUser incompatible avec run-as-root")
    return errs


def _exceptions_errors(spec: dict, by_key: dict, today: datetime.date) -> list[str]:
    """Exceptions de securite (E12) : doublons puis controle de chaque entree."""
    errs = []
    seen = set()
    for i, e in enumerate(spec.get("securityExceptions", [])):
        wl = e.get("workload", "main")
        label = f"securityExceptions[{i}] ({e['rule']}@{wl})"
        if (e["rule"], wl) in seen:
            errs.append(f"{label} : en double")
        seen.add((e["rule"], wl))
        errs += _exception_errors(label, e, by_key.get(wl), today)
    return errs


def _native_errors(doc: dict, caps: dict, envs_secret: list[str], ctx: Context) -> list[str]:
    spec = doc["spec"]
    comps = components(doc)
    by_key = {c["key"]: c for c in comps}
    vols = volumes(spec)
    errs = _component_errors(spec, comps, envs_secret)
    errs += _volume_errors(spec, vols, by_key, caps)
    errs += _database_errors(spec, vols, caps)
    errs += _exceptions_errors(spec, by_key, ctx.today)
    # Quota de cellule (somme des requests declarees).
    if _requests(doc)[0] > QUOTA_MAX[0] or _requests(doc)[1] > QUOTA_MAX[1]:
        errs.append(f"quota de cellule depasse ({_requests(doc)}) : maximum {QUOTA_MAX} (m CPU, Mi)")
    return errs


def semantic_errors(doc: dict, dirname: str, cluster_gate_open: bool, ctx: Context | None = None) -> list[str]:
    ctx = ctx or Context(index={doc["metadata"]["name"]: doc})
    return semantic_check(doc, dirname, cluster_gate_open, ctx)[0]
