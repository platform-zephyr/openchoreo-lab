"""Index des objets de plateforme (platform/) et controle des parametres declares.

Role : lire platform/ avec tolerance (tags YAML inconnus), indexer ClusterComponentType, ClusterTrait,
ClusterProjectType et Environment par (kind, nom), et refuser tout parametre non declare par l'objet cible.
Entrees : dossier platform/ ; objet de plateforme et parametres rendus.
Sorties : index {(kind, nom): objet} ; AppError si un dossier, un objet ou un parametre manque.
"""
from __future__ import annotations

from pathlib import Path

import yaml

from appgenlib.model import AppError


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
        for doc in yaml.load_all(path.read_text(encoding="utf-8"), Loader=_PlatformLoader):  # SafeLoader
            if not isinstance(doc, dict):
                continue
            kind = doc.get("kind")
            if kind in ("ClusterComponentType", "ClusterTrait", "ClusterProjectType", "Environment"):
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


def _cct(platform: dict, ref: str) -> dict:
    wtype, short = ref.split("/", 1)
    cct = platform.get(("ClusterComponentType", short))
    if cct is None:
        raise AppError(f"ClusterComponentType '{short}' introuvable dans platform/")
    if cct["spec"].get("workloadType") != wtype:
        raise AppError(f"ClusterComponentType '{short}' : workloadType '{cct['spec'].get('workloadType')}' != '{wtype}'")
    return cct
