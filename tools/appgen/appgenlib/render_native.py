"""Rendu d'une app native : cellule OpenChoreo (Project), composants, secrets, base, apercus egress, catalogue.

Role : assembler tous les objets OpenChoreo d'une app native a partir de app.yaml et de la plateforme.
Entrees : document app.yaml, index de platform/, cluster, pins ResourceRelease, ProjectRelease et
ComponentRelease par environnement, politique du cluster, index des apps du depot, releases deja presentes (history).
Sorties : {chemin relatif sous generated/: objet} ; AppError si un objet ou un parametre de plateforme manque.
"""
from __future__ import annotations

import copy
from typing import Any

from appgenlib.catalog import catalog_entity
from appgenlib.config import (
    CPT_EXT_PARAMS,
    DB_INSTANCE,
    NS,
    PIPELINE,
    PROJECT_TYPE,
    QUOTA_DEFAULT,
    ROOT,
    SYNC_OPTIONS,
    SYNC_OPTIONS_KEY,
)
from appgenlib.egress import egress_objects, egress_project_params, egress_targets
from appgenlib.model import AppError, _requests, components, egress_spec, load_capabilities, volumes
from appgenlib.platform_index import _require_params
from appgenlib.render_component import render_component


def project_params(doc: dict, caps: dict, index: dict) -> dict:
    spec = doc["spec"]
    net = spec["network"]
    profile, _ = egress_spec(spec)
    params: dict[str, Any] = {"egress": profile, "database": "database" in spec,
                              "allowIdp": bool(net.get("allowIdp", False))}
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


def _project_files(doc: dict, platform: dict, pparams: dict, project_pins: dict | None, files: dict) -> None:
    """Project (parametres verifies contre le CPT si une extension est utilisee) et un ProjectReleaseBinding par env."""
    meta, spec = doc["metadata"], doc["spec"]
    name = meta["name"]
    base = f"namespaces/{NS}/projects/{name}"
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
    for env in spec["environments"]:
        prb_spec = {"owner": {"projectName": name}, "environment": env}
        ppin = (project_pins or {}).get(f"{name}/{env}")
        if ppin:
            prb_spec["projectRelease"] = ppin   # A3 : pin explicite (2e PR) ; absent = initialise par le controleur
        files[f"{base}/project-bindings/{name}-{env}.yaml"] = {
            "apiVersion": "openchoreo.dev/v1alpha1", "kind": "ProjectReleaseBinding",
            "metadata": {"name": f"{name}-{env}", "namespace": NS,
                         "labels": {"openchoreo.dev/project": name, "openchoreo.dev/environment": env}},
            "spec": prb_spec,
        }


def _secret_reference(name: str, secrets: list[dict]) -> dict:
    return {
        "apiVersion": "openchoreo.dev/v1alpha1", "kind": "SecretReference",
        "metadata": {"name": f"{name}-secrets", "namespace": NS},
        "spec": {
            "template": {"type": "Opaque"},
            "data": [
                {"secretKey": s["env"],
                 "remoteRef": {"key": s["key"], **({"property": s["property"]} if "property" in s else {})}}
                for s in secrets
            ],
        },
    }


def _database_files(name: str, spec: dict, caps: dict, pins: dict, files: dict) -> None:
    """Resource de base (ClusterResourceType de l'instance) et un ResourceReleaseBinding par env (pin explicite)."""
    base = f"namespaces/{NS}/projects/{name}"
    db = spec["database"]
    dbname = name.replace("-", "_")
    passkey = name.upper().replace("-", "_") + "_PG_PASSWORD"
    crt = caps["databaseInstances"][db.get("instance", DB_INSTANCE)]["resourceType"]
    files[f"{base}/resources/{name}-db.yaml"] = {
        "apiVersion": "openchoreo.dev/v1alpha1", "kind": "Resource",
        "metadata": {"name": f"{name}-db", "namespace": NS,
                     "annotations": {SYNC_OPTIONS_KEY: SYNC_OPTIONS["Resource"]}},
        "spec": {
            "owner": {"projectName": name},
            "type": {"kind": "ClusterResourceType", "name": crt},
            "parameters": {"database": dbname, "passwordKey": passkey},
        },
    }
    for env in spec["environments"]:
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


def _egress_previews(doc: dict, caps: dict, index: dict, files: dict) -> None:
    """Apercu (non synchronise) des politiques egress que le CPT rendra : relu en PR, valide par kubeconform."""
    name, spec = doc["metadata"]["name"], doc["spec"]
    _, rules = egress_spec(spec)
    if not rules:
        return
    note = {"platform.smadja.dev/preview": "rendu par le ClusterProjectType cell-restricted ; non applique tel quel"}
    for env in spec["environments"]:
        ns = f"dp-{NS}-{name}-{env}"
        for obj in egress_objects(name, env, ns, egress_project_params(doc, caps, index), rules, caps["cilium"], note):
            files[f"previews/{name}/{env}/{obj['kind'].lower()}-{obj['metadata']['name']}.yaml"] = obj


def render_native(doc: dict, platform: dict[tuple[str, str], dict], cluster: str, pins: dict,
                  caps: dict | None = None, index: dict | None = None, history: dict | None = None,
                  project_pins: dict | None = None, release_pins: dict | None = None) -> dict[str, object]:
    spec = copy.deepcopy(doc["spec"])
    name = doc["metadata"]["name"]
    spec["_name"] = name
    doc = {**doc, "spec": spec}
    caps = caps if caps is not None else load_capabilities(ROOT / "clusters", cluster)
    index = index if index is not None else {name: doc}
    files: dict[str, object] = {}

    _project_files(doc, platform, project_params(doc, caps, index), project_pins, files)
    targeted = egress_targets(index)
    scratch: dict = {"__index__": index, "__history__": history or {}, "__release_pins__": release_pins or {}}
    for comp in components(doc):
        render_component(doc, comp, platform, caps, targeted, scratch)
    scratch.pop("__index__")
    scratch.pop("__history__")
    scratch.pop("__release_pins__")
    files.update(scratch)

    if spec.get("secrets"):
        files[f"namespaces/{NS}/projects/{name}/secret-references/{name}-secrets.yaml"] = \
            _secret_reference(name, spec["secrets"])
    if "database" in spec:
        _database_files(name, spec, caps, pins, files)
    _egress_previews(doc, caps, index, files)
    files[f"catalog/{name}/catalog-info.yaml"] = catalog_entity(doc)
    return files
