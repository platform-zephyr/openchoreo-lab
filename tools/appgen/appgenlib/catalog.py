"""Entite de catalogue Backstage d'une app (parcours natif ou helm).

Role : decrire l'app pour le portail (proprietaire, cycle de vie, OIDC, sauvegarde, exceptions de securite).
Entrees : document app.yaml ; annotations supplementaires (parcours helm : Application Argo CD, chart).
Sorties : objet `backstage.io/v1alpha1 Component` (dictionnaire) ecrit sous generated/catalog/<nom>/.
"""
from __future__ import annotations

from typing import Any

from appgenlib.model import compute_delivery


def catalog_entity(doc: dict[str, Any], extra: dict[str, Any] | None = None) -> dict[str, Any]:
    meta, spec = doc["metadata"], doc["spec"]
    native = compute_delivery(spec) == "native"
    annotations = {"openchoreo.dev/managed": "true" if native else "false"}
    oidc = spec.get("identity", {}).get("oidc", {})
    if oidc.get("allowedGroups"):
        annotations["platform.smadja.dev/oidc-provider"] = oidc.get("provider", "thunderid")
        annotations["platform.smadja.dev/oidc-allowed-groups"] = ",".join(oidc["allowedGroups"])
    if spec["backup"].get("mechanism", "none") != "none":
        annotations["platform.smadja.dev/backup"] = f"{spec['backup']['mechanism']}/{spec['backup']['retention']}"
    if spec.get("securityExceptions"):
        annotations["platform.smadja.dev/security-exceptions"] = ",".join(
            f"{e['rule']}@{e.get('workload', 'main')}:{e['expires']}" for e in spec["securityExceptions"])
    annotations.update(extra or {})
    return {
        "apiVersion": "backstage.io/v1alpha1", "kind": "Component",
        "metadata": {
            "name": meta["name"], "description": meta["description"],
            "annotations": annotations,
            **({"links": [{"url": meta["docs"]}]} if "docs" in meta else {}),
        },
        "spec": {"type": "service", "lifecycle": meta.get("lifecycle", "experimental"), "owner": meta["owner"]},
    }
