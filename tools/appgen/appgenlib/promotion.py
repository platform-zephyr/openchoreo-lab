"""Promotion development -> production et retour arriere par pin de ComponentRelease (T-003, ADR-0004, ecart G3).

Role : calculer les pins de production d'une app a partir de generated/ (etat commite, donc valide et merge) :
  - promote : chaque composant de l'app recoit en production la release de son ReleaseBinding development ;
  - rollback : production repointe une release conservee (A2) d'un composant de l'app.
Semantique reprise de l'amont (idee, aucune ligne copiee) : `occ releasebinding generate --target-env
--use-pipeline` d'openchoreo/openchoreo v1.3.3 ; promouvoir = binding de l'env cible avec la release de l'env
source ; revenir = repointer une release anterieure.
Entrees : racine generated/, nom d'app, releases demandees. Aucune ecriture ici.
Sorties : {"<composant>/production": release} ; AppError si rien a promouvoir ou release inconnue.
"""
from __future__ import annotations

from pathlib import Path

from appgenlib.config import NS
from appgenlib.model import AppError, load_yaml

SOURCE_ENV = "development"
TARGET_ENV = "production"


def _components_dir(generated: Path, app: str) -> Path:
    cdir = generated / "namespaces" / NS / "projects" / app / "components"
    if not cdir.is_dir():
        raise AppError(f"{app} : aucune app native rendue dans generated/ (lancer render, merger, puis promouvoir)")
    return cdir


def promotion_pins(generated: Path, app: str) -> dict[str, str]:
    """Release development de chaque composant de l'app -> pin production."""
    pins = {}
    for path in sorted(_components_dir(generated, app).glob(f"*/release-bindings/*-{SOURCE_ENV}.yaml")):
        spec = load_yaml(path)["spec"]
        cname = path.parent.parent.name
        if spec.get("environment") != SOURCE_ENV or spec["owner"]["componentName"] != cname:
            continue
        rel = spec["releaseName"]
        if not (path.parent.parent / "releases" / f"{rel}.yaml").exists():
            raise AppError(f"{cname} : release development '{rel}' absente de generated/ (relancer render)")
        pins[f"{cname}/{TARGET_ENV}"] = rel
    if not pins:
        raise AppError(f"{app} : aucun ReleaseBinding {SOURCE_ENV} dans generated/ ; deployer d'abord en "
                       f"{SOURCE_ENV} (environments: [{SOURCE_ENV}]) et merger")
    return pins


def rollback_pins(generated: Path, app: str, releases: list[str]) -> dict[str, str]:
    """Chaque release demandee doit etre conservee sous generated/ pour un composant de l'app."""
    cdir = _components_dir(generated, app)
    owners = {p.stem: p.parent.parent.name for p in cdir.glob("*/releases/*.yaml")}
    pins = {}
    for rel in releases:
        if rel not in owners:
            raise AppError(f"{app} : release '{rel}' inconnue (releases conservees : {', '.join(sorted(owners))})")
        pins[f"{owners[rel]}/{TARGET_ENV}"] = rel
    return pins
