"""Rendu de tout le depot et ecriture deterministe de l'arbre genere.

Role : valider (refus si une erreur), charger plateforme, pins et releases conservees, rendre chaque app par son
parcours (natif ou helm ; pins de release par environnement, T-003), appliquer le controle G1, puis ecrire l'arbre trie avec un en-tete fixe.
Entrees : racine du depot, dossier platform/, gate OKE, tolerance FQDN, date du jour, dossier d'historique.
Sorties : {chemin relatif: objet} (render_all) ; fichiers YAML sous le dossier cible (write_tree) ; pins lus.
"""
from __future__ import annotations

import datetime
from pathlib import Path

import yaml

from appgenlib.config import RELEASE_PINS_FILE
from appgenlib.gateway import gateway_errors
from appgenlib.model import AppError, app_dirs, clusters_dir_for, compute_delivery, load_capabilities, load_yaml
from appgenlib.platform_index import load_platform
from appgenlib.render_component import load_release_history
from appgenlib.render_helm import render_helm
from appgenlib.render_native import render_native
from appgenlib.validate import validate_all_full


def load_pins(root: Path, filename: str = "resource-releases.yaml") -> dict[str, str]:
    path = root / "pins" / filename
    if not path.exists():
        return {}
    data = load_yaml(path) or {}
    return {str(k): str(v) for k, v in (data.get("pins") or {}).items()}


def render_all(root: Path, platform_dir: Path, cluster_gate_open: bool = True,
               allow_unenforced_fqdn: bool = False, today: datetime.date | None = None,
               history_dir: Path | None = None) -> dict[str, object]:
    """history_dir : arbre genere existant dont les ComponentRelease sont conservees (defaut root/generated)."""
    _, errors, _ = validate_all_full(root, cluster_gate_open, examples=False,
                                     allow_unenforced_fqdn=allow_unenforced_fqdn, today=today)
    if errors:
        raise AppError("\n".join(errors))
    platform = load_platform(platform_dir)
    pins = load_pins(root)
    project_pins = load_pins(root, "project-releases.yaml")
    release_pins = load_pins(root, RELEASE_PINS_FILE)
    history = load_release_history(history_dir if history_dir is not None else root / "generated")
    cdir = clusters_dir_for(root)
    docs = [load_yaml(d / "app.yaml") for d in app_dirs(root)]
    index = {doc["metadata"]["name"]: doc for doc in docs}
    files: dict[str, object] = {}
    for doc in docs:
        caps = load_capabilities(cdir, doc["spec"]["cluster"])
        if compute_delivery(doc["spec"]) == "helm":
            files.update(render_helm(doc, caps))
        else:
            files.update(render_native(doc, platform, doc["spec"]["cluster"], pins, caps, index, history, project_pins,
                                       release_pins))
    errs = gateway_errors(files, platform)
    if errs:
        raise AppError("\n".join(errs))
    return files


def write_tree(files: dict[str, object], out: Path) -> None:
    for rel in sorted(files):
        target = out / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        body = yaml.safe_dump(files[rel], sort_keys=False, allow_unicode=True, width=4096)
        header = "# Genere par tools/appgen (ne pas editer a la main). Source : apps/*/app.yaml.\n"
        target.write_text(header + body, encoding="utf-8")
