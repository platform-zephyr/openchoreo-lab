"""Chargement et normalisation d'un descripteur app.yaml.

Role : lire YAML et politiques de cluster, porter le contexte de validation, et ramener app.yaml a des structures
normalisees (parcours, volumes, egress, composants, strategie, requests) partagees par validation et rendu.
Entrees : chemins de fichiers YAML, dictionnaires app.yaml deja charges, clusters/<cluster>/capabilities.yaml.
Sorties : dictionnaires et listes Python ; AppError (message lisible, sans valeur secrete) en cas de refus.
"""
from __future__ import annotations

import datetime
from collections.abc import Iterator
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft7Validator

from appgenlib.config import CAPS_SCHEMA_PATH, MAX_SURGE_PERCENT, ROOT, SIZE_REQUESTS


class AppError(Exception):
    """Erreur de validation ou de rendu (message lisible, sans valeur secrete)."""


def load_yaml(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as fh:
        return yaml.load(fh, Loader=getattr(yaml, "CSafeLoader", yaml.SafeLoader))  # libyaml si dispo (= safe_load)


def _walk_strings(node: Any, path: str = "") -> Iterator[tuple[str, str]]:
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


def surge_pods(replicas: int) -> int:
    """Pods en surplus pendant un RollingUpdate : ceil(replicas * maxSurge%), maxSurge = defaut Kubernetes."""
    return -(-replicas * MAX_SURGE_PERCENT // 100)


def component_strategy(spec: dict, comp: dict) -> str | None:
    """Strategie du Deployment rendu (parametre `strategy` du CCT) ; None hors Deployment."""
    if comp["kind"] != "Deployment":
        return None
    vols = [v for v in volumes(spec) if v["workload"] == comp["key"]]
    if comp["main"]:
        return spec.get("update", {}).get("strategy", "Recreate" if vols else "RollingUpdate")
    return "Recreate" if any(v["profile"] == "block-rwo" for v in vols) else "RollingUpdate"


def _requests(doc: dict) -> tuple[int, int]:
    """Somme des requests + surplus d'un RollingUpdate (A7) : le quota doit admettre le pod en surplus."""
    cpu = mem = 0
    for c in components(doc):
        n = 1 if c["kind"] == "CronJob" else c["rt"].get("replicas", 1)
        if component_strategy(doc["spec"], c) == "RollingUpdate":
            n += surge_pods(n)
        rc, rm = SIZE_REQUESTS[c["rt"]["size"]]
        cpu, mem = cpu + n * rc, mem + n * rm
    return cpu, mem
