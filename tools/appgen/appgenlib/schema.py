"""Controles de forme : schema JSON de app.yaml, variables d'environnement et values.yaml.

Role : refuser ce qui est mal forme ou ressemble a un secret avant toute regle semantique.
Entrees : document app.yaml charge, dictionnaire env, values.yaml charge (parcours helm).
Sorties : listes de messages d'erreur (vides si conforme) ; aucune E/S hors lecture du schema.
"""
from __future__ import annotations

from typing import Any

from jsonschema import Draft7Validator

from appgenlib.config import SCHEMA_PATH, SECRET_LIKE_ENV, SECRET_LIKE_VALUE
from appgenlib.model import load_yaml


def schema_errors(doc: Any) -> list[str]:
    validator = Draft7Validator(load_yaml(SCHEMA_PATH))
    out = []
    for err in sorted(validator.iter_errors(doc), key=lambda e: list(e.path)):
        where = "/".join(str(p) for p in err.path) or "<racine>"
        out.append(f"schema {where}: {err.message}")
    return out


def _env_errors(label: str, env: dict[str, Any], envs_secret: list[str]) -> list[str]:
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


def _values_key_errors(k: Any, v: Any, p: str) -> list[str]:
    """Garde-fous sur une cle de values.yaml (chemin p)."""
    errs = []
    if k in ("hostNetwork", "hostPID", "hostIPC", "privileged", "allowPrivilegeEscalation") and v is True:
        errs.append(f"values.yaml {p}: true interdit")
    if k == "hostPath":
        errs.append(f"values.yaml {p}: hostPath interdit")
    if k == "type" and v in ("LoadBalancer", "NodePort"):
        errs.append(f"values.yaml {p}: Service {v} interdit (ClusterIP seulement)")
    if k == "runAsUser" and v == 0:
        errs.append(f"values.yaml {p}: runAsUser 0 interdit (securityExceptions non applicable en helm)")
    return errs


def values_errors(values: Any) -> list[str]:
    """Garde-fous sur values.yaml (parcours helm) : privileges, hote, Service expose, secrets."""
    errs: list[str] = []

    def walk(node: Any, path: str) -> None:
        if isinstance(node, dict):
            for k, v in node.items():
                p = f"{path}.{k}"
                errs.extend(_values_key_errors(k, v, p))
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
