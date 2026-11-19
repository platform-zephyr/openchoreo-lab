"""Rendu d'un composant natif : Component, Workload, ComponentRelease (immuables) et ReleaseBinding.

Role : traduire un composant normalise (model.components) en objets OpenChoreo. Le nom d'une ComponentRelease
est le hash de sa spec (deterministe) ; les releases deja presentes dans generated/ sont conservees (A2, ajout
seul) et une release modifiee a la main est refusee. Chaque ReleaseBinding pointe la release de son environnement
(T-003, G3) : development suit la release courante, un environnement epingle suit son pin.
Entrees : document app.yaml, composant, index de platform/, politique du cluster, cibles egress, et le
dictionnaire `rendered` qui porte aussi `__index__` (apps du depot), `__history__` (releases conservees) et
`__release_pins__` (pins ComponentRelease `<composant>/<env>`).
Sorties : fichiers ajoutes a `rendered` ({chemin relatif sous generated/: objet}) ; AppError en cas de refus.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from appgenlib.config import (
    ACCESS_MODE,
    CCT_BY_KIND,
    NS,
    PROBES_TRAIT,
    PVC_TRAIT_BY_KIND,
    ROOT_EXCEPTION_CCT,
    SYNC_OPTIONS,
    SYNC_OPTIONS_KEY,
)
from appgenlib.model import AppError, component_strategy, components, egress_spec, exceptions_for, load_yaml, volumes
from appgenlib.platform_index import _cct, _require_params


def _env_list(spec: dict, comp: dict) -> list[dict]:
    rt = comp["rt"]
    items: list[dict] = [{"key": k, "value": str(v)} for k, v in rt.get("env", {}).items()]
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


def _component_release(name: str, spec: dict) -> dict:
    return {
        "apiVersion": "openchoreo.dev/v1alpha1", "kind": "ComponentRelease",
        "metadata": {"name": name, "namespace": NS, "annotations": {SYNC_OPTIONS_KEY: SYNC_OPTIONS["ComponentRelease"]}},
        "spec": spec,
    }


def load_release_history(generated: Path | None) -> dict[str, dict[str, dict]]:
    """ComponentRelease deja presentes dans generated/ : {dossier releases relatif: {nom: spec}} (A2).

    Le nom d'une release est le hash de sa spec : une release modifiee a la main est refusee (immuable).
    Les metadonnees ne sont pas reprises (reecrites au rendu, annotations comprises)."""
    out: dict[str, dict[str, dict]] = {}
    if generated is None or not generated.is_dir():
        return out
    for path in sorted(generated.glob(f"namespaces/{NS}/projects/*/components/*/releases/*.yaml")):
        obj = load_yaml(path)
        rel = str(path.relative_to(generated))
        if not isinstance(obj, dict) or obj.get("kind") != "ComponentRelease":
            raise AppError(f"{rel} : ComponentRelease attendue")
        name, spec = obj["metadata"]["name"], obj["spec"]
        cname = path.parent.parent.name
        if name != path.stem or _release_name(spec, cname) != name:
            raise AppError(f"{rel} : release modifiee a la main (nom != hash de la spec) : restaurer depuis Git")
        out.setdefault(str(path.parent.relative_to(generated)), {})[name] = spec
    return out


def _component_params(spec: dict, comp: dict, exc: set[str]) -> dict:
    """Parametres du ClusterComponentType (ordre des cles fige : il apparait dans les manifests)."""
    params: dict[str, Any] = {}
    if "run-as-root" not in exc:
        params["runAsUser"] = comp["rt"].get("runAsUser", 65532)
    if comp["kind"] == "Deployment":
        params["strategy"] = component_strategy(spec, comp)
    if comp["port"] and comp["kind"] == "Deployment":
        exp = spec["exposure"]
        params["publicAuth"] = exp["auth"] if comp["main"] and exp["mode"] == "public" else "none"
    if comp["kind"] == "CronJob":
        params["concurrencyPolicy"] = "Forbid"
        if comp.get("timeZone"):
            params["timeZone"] = comp["timeZone"]
    if "writable-rootfs" in exc:
        params["readOnlyRootFilesystem"] = False
    return params


def _pvc_traits(comp: dict, vols: list[dict], platform: dict, caps: dict, data_class: str | None = None) -> tuple[list, list, dict, dict]:
    """Volumes -> (traits du Component, traits du profil de release, specs des traits figees, config par env)."""
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
        if data_class:
            tparams["dataClass"] = data_class   # T-025 : label data-class du PVC
        _require_params(trait, f"ClusterTrait '{tname}'", tparams)
        traits_ref.append({"kind": "ClusterTrait", "name": tname, "instanceName": v["name"], "parameters": tparams})
        traits_profile.append({"instanceName": v["name"], "kind": "ClusterTrait", "name": tname, "parameters": tparams})
        traits_release[tname] = {"kind": "ClusterTrait", "name": tname, "spec": trait["spec"]}
        trait_env[v["name"]] = {"size": v["size"], "storageClass": caps["storageClasses"][v["profile"]]}
    return traits_ref, traits_profile, traits_release, trait_env


def _probes_trait(comp: dict, cct: dict, platform: dict) -> tuple[list, list, dict, dict]:
    """T-010 (G2) : healthPath d'un endpoint HTTP -> trait health-probes (readiness + liveness httpGet).

    Meme forme de retour que _pvc_traits. Rien si pas de healthPath, si `healthProbe: false`, pas de port HTTP ou CCT qui n'autorise pas le trait."""
    path = comp["rt"].get("healthPath") if comp["rt"].get("healthProbe", True) else None
    allowed = {t["name"] for t in cct["spec"].get("allowedTraits", [])}
    if not path or not comp["port"] or comp["protocol"] != "HTTP" or PROBES_TRAIT not in allowed:
        return [], [], {}, {}
    trait = platform.get(("ClusterTrait", PROBES_TRAIT))
    if trait is None:
        raise AppError(f"ClusterTrait '{PROBES_TRAIT}' introuvable dans platform/")
    handler = {"httpGet": {"port": comp["port"], "path": path}}
    tparams = {"containerName": "main",
               "liveness": {"enabled": True, "handler": handler, "initialDelaySeconds": 10, "periodSeconds": 10},
               "readiness": {"enabled": True, "handler": handler, "periodSeconds": 5}}
    _require_params(trait, f"ClusterTrait '{PROBES_TRAIT}'", tparams)
    ref = {"kind": "ClusterTrait", "name": PROBES_TRAIT, "instanceName": "probes", "parameters": tparams}
    return [ref], [ref], {PROBES_TRAIT: {"kind": "ClusterTrait", "name": PROBES_TRAIT, "spec": trait["spec"]}}, \
        {"probes": {"enabled": True}}


def _endpoints(spec: dict, name: str, comp: dict, targeted: set) -> dict:
    """Endpoint unique du composant ; visibilite 'namespace' en plus s'il est la cible d'une regle egress app."""
    vis = ["project"]
    if comp["main"]:
        vis = ["external"] if spec["exposure"]["mode"] == "public" else ["internal"]
    if (name, comp["key"]) in targeted:
        vis = [*vis, "namespace"]
    return {"http" if comp["protocol"] == "HTTP" else "tcp": {"type": comp["protocol"], "port": comp["port"],
                                                              "visibility": vis}}


def _dependencies(spec: dict, name: str, comp: dict, index: dict) -> dict:
    """Dependances du Workload : base (Resource) et endpoints des apps visees par l'egress (composant main)."""
    deps: dict[str, Any] = {}
    if comp["database"]:
        deps["resources"] = [{"ref": f"{name}-db", "envBindings": {"url": spec["database"].get("envVar", "DATABASE_URL")}}]
    if comp["main"]:
        conns = []
        for r in egress_spec(spec)[1]:
            if "app" in r:
                tcomp = next(c for c in components(index[r["app"]]) if c["key"] == r.get("workload", "main"))
                conns.append({"project": r["app"], "component": tcomp["cname"],
                              "name": "http" if tcomp["protocol"] == "HTTP" else "tcp", "visibility": "namespace",
                              "envBindings": {"address": r.get("envVar", r["app"].upper().replace("-", "_") + "_URL")}})
        if conns:
            deps["endpoints"] = conns
    return deps


def _workload_spec(spec: dict, name: str, comp: dict, targeted: set, index: dict) -> dict:
    rt = comp["rt"]
    container: dict[str, Any] = {"image": comp["image"], "env": _env_list(spec, comp)}
    if rt.get("command"):
        container["command"] = rt["command"]
    if rt.get("args"):
        container["args"] = rt["args"]
    workload_spec: dict[str, Any] = {"owner": {"projectName": name, "componentName": comp["cname"]},
                                     "container": container}
    if comp["port"]:
        workload_spec["endpoints"] = _endpoints(spec, name, comp, targeted)
    deps = _dependencies(spec, name, comp, index)
    if deps:
        workload_spec["dependencies"] = deps
    return workload_spec


def _check_strategy_change(cname: str, params: dict, past: dict) -> None:
    """Refuse RollingUpdate -> Recreate sur un composant deja deploye (422 de l'API, T-STRATEGY)."""
    if params.get("strategy") == "Recreate" and any(
            (r["componentProfile"].get("parameters") or {}).get("strategy") == "RollingUpdate" for r in past.values()):
        raise AppError(
            f"{cname} : passage RollingUpdate -> Recreate refuse sur un composant deja deploye (l'API refuse la "
            "mise a jour en place : 422 spec.strategy.rollingUpdate, T-STRATEGY). Chemin : PR 1 retrait de l'app "
            "(+ suppression operateur du Component), PR 2 re-ajout stateful ; ou garder RollingUpdate sans PVC RWO.")


def _bound_release(spec: dict, cname: str, env: str, rel: str, known: set[str], pins: dict) -> str:
    """Release d'un environnement (T-003, ecart G3).

    Un pin `<composant>/<env>` l'emporte et doit viser une release conservee ; sans pin, la release courante.
    Production sans pin alors que development est declare : refus (la meme release partirait partout)."""
    pin = pins.get(f"{cname}/{env}")
    if pin is not None:
        if pin not in known:
            raise AppError(f"{cname}/{env} : pin '{pin}' sans ComponentRelease conservee dans generated/ "
                           f"(releases connues : {', '.join(sorted(known))})")
        return pin
    if env == "production" and "development" in spec["environments"]:
        raise AppError(f"{cname} : production sans pin alors que development est declare ; valider en development "
                       f"puis `tools/appgen/appgen.py promote {spec['_name']}` (pins/component-releases.yaml)")
    return rel


def _release_bindings(spec: dict, name: str, comp: dict, rel: str, trait_env: dict, cdir: str,
                      rendered: dict, known: set[str]) -> None:
    """Un ReleaseBinding par environnement, pointant la release de cet environnement (_bound_release)."""
    cname, rt = comp["cname"], comp["rt"]
    pins = rendered.get("__release_pins__", {})
    if comp["kind"] == "CronJob":
        env_cfg = {"size": rt["size"], "schedule": comp["schedule"]}
    else:
        env_cfg = {"size": rt["size"], "replicas": rt.get("replicas", 1)}
    for env in spec["environments"]:
        rb_spec = {
            "owner": {"projectName": name, "componentName": cname},
            "environment": env,
            "releaseName": _bound_release(spec, cname, env, rel, known, pins),
            "componentTypeEnvironmentConfigs": env_cfg,
        }
        if trait_env:
            rb_spec["traitEnvironmentConfigs"] = trait_env
        rendered[f"{cdir}/release-bindings/{cname}-{env}.yaml"] = {
            "apiVersion": "openchoreo.dev/v1alpha1", "kind": "ReleaseBinding",
            "metadata": {"name": f"{cname}-{env}", "namespace": NS}, "spec": rb_spec,
        }


def render_component(doc: dict, comp: dict, platform: dict, caps: dict, targeted: set, rendered: dict) -> None:
    spec = doc["spec"]
    name = doc["metadata"]["name"]
    cname = comp["cname"]
    cdir = f"namespaces/{NS}/projects/{name}/components/{cname}"
    exc = exceptions_for(spec, comp["key"])
    vols = [v for v in volumes(spec) if v["workload"] == comp["key"]]

    cct_ref = ROOT_EXCEPTION_CCT if "run-as-root" in exc else CCT_BY_KIND[(comp["kind"], bool(comp["port"]))]
    cct = _cct(platform, cct_ref)
    params = _component_params(spec, comp, exc)
    _require_params(cct, f"ClusterComponentType '{cct_ref}'", params)
    traits_ref, traits_profile, traits_release, trait_env = _pvc_traits(comp, vols, platform, caps, spec.get("data", {}).get("class"))
    p_ref, p_profile, p_release, p_env = _probes_trait(comp, cct, platform)
    traits_ref, traits_profile = [*traits_ref, *p_ref], [*traits_profile, *p_profile]
    traits_release, trait_env = {**traits_release, **p_release}, {**trait_env, **p_env}

    rendered[f"{cdir}/component.yaml"] = {
        "apiVersion": "openchoreo.dev/v1alpha1", "kind": "Component",
        "metadata": {"name": cname, "namespace": NS, "annotations": {SYNC_OPTIONS_KEY: SYNC_OPTIONS["Component"]}},
        "spec": {
            "owner": {"projectName": name},
            "componentType": {"kind": "ClusterComponentType", "name": cct_ref},
            "autoDeploy": False,
            "parameters": params,
            **({"traits": traits_ref} if traits_ref else {}),
        },
    }
    workload_spec = _workload_spec(spec, name, comp, targeted, rendered["__index__"])
    rendered[f"{cdir}/workload.yaml"] = {
        "apiVersion": "openchoreo.dev/v1alpha1", "kind": "Workload",
        "metadata": {"name": f"{cname}-workload", "namespace": NS}, "spec": workload_spec,
    }

    # ComponentRelease : contenu fige (CCT, traits, workload, profil). Nom = hash du contenu (deterministe).
    release_spec: dict[str, Any] = {
        "owner": {"componentName": cname, "projectName": name},
        "componentType": {"kind": "ClusterComponentType", "name": cct_ref, "spec": cct["spec"]},
        "workload": {k: v for k, v in workload_spec.items() if k != "owner"},
        "componentProfile": {"parameters": params, "traits": traits_profile},
    }
    if traits_release:
        release_spec["traits"] = [traits_release[k] for k in sorted(traits_release)]
    rel = _release_name(release_spec, cname)
    rdir = f"{cdir}/releases"
    past = rendered["__history__"].get(rdir, {})
    _check_strategy_change(cname, params, past)
    for name_, past_spec in past.items():   # A2 : releases deja dans Git conservees (ajout seul)
        rendered[f"{rdir}/{name_}.yaml"] = _component_release(name_, past_spec)
    rendered[f"{rdir}/{rel}.yaml"] = _component_release(rel, release_spec)
    _release_bindings(spec, name, comp, rel, trait_env, cdir, rendered, {*past, rel})
