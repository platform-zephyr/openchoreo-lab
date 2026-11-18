"""Controle G1 : visibilite des endpoints contre la gateway des Environments.

Role : refuser au rendu un endpoint `internal`/`external` deploye dans un Environment sans gateway.ingress
correspondante (RenderingFailed garanti cote OpenChoreo, T-GH-RENDER).
Entrees : fichiers rendus {chemin: objet} et index de platform/ (platform_index.load_platform).
Sorties : liste d'erreurs (vide si conforme ou si platform/ ne declare aucun Environment).
"""
from __future__ import annotations


def _binding_envs(files: dict[str, object]) -> dict[str, set[str]]:
    """{componentName: environnements} d'apres les ReleaseBinding rendus."""
    owners: dict[str, set[str]] = {}
    for obj in files.values():
        if isinstance(obj, dict) and obj.get("kind") == "ReleaseBinding":
            owners.setdefault(obj["spec"]["owner"]["componentName"], set()).add(obj["spec"]["environment"])
    return owners


def _workload_errors(rel: str, obj: dict, envs: dict, bound: set[str]) -> list[str]:
    """Erreurs G1 d'un Workload pour chacun des environnements ou il est deploye."""
    errs = []
    vis = {v for ep in (obj["spec"].get("endpoints") or {}).values() for v in ep.get("visibility", [])}
    for env in sorted(bound):
        if env not in envs:
            errs.append(f"{rel} : Environment '{env}' absent de platform/")
            continue
        ingress = ((envs[env].get("spec") or {}).get("gateway") or {}).get("ingress") or {}
        errs += [f"{rel} : endpoint {v} mais Environment '{env}' sans gateway.ingress.{v} (RenderingFailed garanti, G1)"
                 for v in sorted(vis & {"internal", "external"}) if v not in ingress]
    return errs


def gateway_errors(files: dict[str, object], platform: dict) -> list[str]:
    """G1 : un endpoint `internal`/`external` exige gateway.ingress.<v> sur l'Environment (sinon RenderingFailed,
    T-GH-RENDER). Controle actif des que platform/ declare au moins un Environment (fixtures sans Environment :
    controle non applicable, le gateway peut venir du ClusterDataPlane, non lu ici)."""
    envs = {name: obj for (kind, name), obj in platform.items() if kind == "Environment"}
    if not envs:
        return []
    errs = []
    owners = _binding_envs(files)
    for rel, obj in sorted(files.items()):
        if isinstance(obj, dict) and obj.get("kind") == "Workload":
            errs += _workload_errors(rel, obj, envs, owners.get(obj["spec"]["owner"]["componentName"], set()))
    return errs
