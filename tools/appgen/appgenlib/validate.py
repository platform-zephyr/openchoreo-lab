"""Validation de toutes les apps d'un depot (commande `validate`, prealable de `render`).

Role : charger chaque apps/<nom>/app.yaml (et apps/_examples/ sur demande), appliquer schema puis regles
semantiques avec un index commun (egress inter-apps), controler values.yaml (helm) et l'unicite des hotes publics.
Entrees : racine du depot, gate OKE, inclusion des exemples, tolerance FQDN, date du jour.
Sorties : (nombre d'apps chargees, erreurs, avertissements), messages prefixes par le chemin du fichier.
"""
from __future__ import annotations

import datetime
from pathlib import Path
from typing import Any

import yaml

from appgenlib.model import Context, app_dirs, clusters_dir_for, compute_delivery, load_yaml
from appgenlib.schema import schema_errors, values_errors
from appgenlib.semantic import semantic_check


def _load_apps(root: Path, examples: bool, ctx: Context, errors: list[str]) -> list[tuple[Path, str, dict[str, Any]]]:
    """Charge les apps conformes au schema et les indexe dans ctx ; ajoute les erreurs de lecture et de schema."""
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
    return loaded


def _helm_values_errors(d: Path, label: str) -> list[str]:
    vpath = d / "values.yaml"
    if not vpath.exists():
        return [f"{label}: parcours helm sans values.yaml"]
    return [f"{label}: {e}" for e in values_errors(load_yaml(vpath))]


def validate_all_full(root: Path, cluster_gate_open: bool = True, examples: bool = True,
                      allow_unenforced_fqdn: bool = False,
                      today: datetime.date | None = None) -> tuple[int, list[str], list[str]]:
    """Retourne (nb_apps, erreurs, avertissements). Verifie aussi l'unicite des hotes publics."""
    errors: list[str] = []
    warnings: list[str] = []
    hosts: dict[str, str] = {}
    ctx = Context(clusters_dir=clusters_dir_for(root), allow_unenforced_fqdn=allow_unenforced_fqdn,
                  today=today or datetime.date.today())
    loaded = _load_apps(root, examples, ctx, errors)
    for d, label, doc in loaded:
        dirname = doc["metadata"]["name"] if d.parent.name == "_examples" else d.name
        errs, warns = semantic_check(doc, dirname, cluster_gate_open, ctx)
        errors += [f"{label}: {e}" for e in errs]
        warnings += [f"{label}: {w}" for w in warns]
        if compute_delivery(doc["spec"]) == "helm":
            errors += _helm_values_errors(d, label)
        host = doc["spec"]["exposure"].get("host")
        if host and not str(d).startswith(str(root / "apps" / "_examples")):
            if host in hosts:
                errors.append(f"{label}: hote '{host}' deja utilise par {hosts[host]}")
            hosts[host] = d.name
    return len(loaded), errors, warnings


def validate_all(root: Path, cluster_gate_open: bool = True, examples: bool = True,
                 **kw: Any) -> tuple[int, list[str]]:
    """Retourne (nb_apps, liste_erreurs)."""
    count = len(app_dirs(root, examples=examples))
    _, errors, _ = validate_all_full(root, cluster_gate_open, examples, **kw)
    return count, errors
