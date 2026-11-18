#!/usr/bin/env python3
"""appgen : apps/<nom>/app.yaml -> manifests OpenChoreo v1.3.3 (ou Application Argo CD) sous generated/.

Commandes :
  validate                 schema + regles semantiques (apps/*/app.yaml et apps/_examples/*/app.yaml)
  render [--out DIR]       ecrit les manifests (sortie deterministe). Les ComponentRelease deja presentes dans
                           DIR (defaut generated/) sont CONSERVEES (ajout seul, A2) ; integrite verifiee par hash.
  check [--base REF]       rend dans un dossier temporaire et compare a generated/ (derive = echec) ; verifie que
                           chaque releaseName pointe un fichier ; avec --base (ex. origin/main) : refuse la
                           suppression d'une release d'un composant conserve, signale la 2e PR pin-project (A3)
  pin-resource APP ENV RELEASE  pin ResourceRelease d'une base -> pins/resource-releases.yaml
  pin-project APP ENV RELEASE   pin ProjectRelease d'une cellule -> pins/project-releases.yaml (2e PR, A3)
  promote APP              pin production <- release du ReleaseBinding development de chaque composant
                           (generated/) -> pins/component-releases.yaml (T-003, G3) ; development suit la
                           release courante, production son pin
  rollback APP RELEASE...  pin production <- release conservee (generated/) d'un composant de l'app

Politique par cluster : clusters/<cluster>/capabilities.yaml (docs/schema/capabilities.schema.json).
Aucun secret n'est lu ni ecrit : seules des references (SecretReference, ExternalSecret) sont generees.
Dependances : PyYAML, jsonschema (figes dans tools/appgen/requirements.txt).

Role de ce fichier (T-214) : point d'entree inchange et facade d'import. Le code vit dans le paquet appgenlib/
(un module par responsabilite, voir appgenlib/__init__.py) ; ce module en reexporte l'API publique pour les tests
et les appelants existants (`import appgen`).
Entrees : argv (ligne de commande). Sorties : code de sortie de appgenlib.cli.main.
"""
from __future__ import annotations

import sys

from appgenlib.catalog import catalog_entity
from appgenlib.cli import main
from appgenlib.config import (
    CCT_NAME,
    PINS_PATH,
    PROJECT_PINS_PATH,
    PVC_TRAIT,
    ROOT,
    ROOT_EXCEPTION_CCT,
    SECRET_LIKE_VALUE,
)
from appgenlib.egress import cidr_policy, egress_errors, egress_objects, egress_project_params, fqdn_errors
from appgenlib.gateway import gateway_errors
from appgenlib.gitops import base_state, binding_errors, diff_trees, project_pin_warnings, release_deletions
from appgenlib.model import (
    AppError,
    Context,
    app_dirs,
    component_strategy,
    components,
    compute_delivery,
    default_cluster,
    load_capabilities,
    load_yaml,
    surge_pods,
    volumes,
)
from appgenlib.platform_index import load_platform
from appgenlib.render import load_pins, render_all, write_tree
from appgenlib.render_component import load_release_history, render_component
from appgenlib.render_helm import render_helm
from appgenlib.render_native import project_params, render_native
from appgenlib.schema import schema_errors, values_errors
from appgenlib.semantic import semantic_check, semantic_errors
from appgenlib.validate import validate_all, validate_all_full

__all__ = [
    "CCT_NAME", "PINS_PATH", "PROJECT_PINS_PATH", "PVC_TRAIT", "ROOT", "ROOT_EXCEPTION_CCT", "SECRET_LIKE_VALUE",
    "AppError", "Context", "app_dirs", "base_state", "binding_errors", "catalog_entity", "cidr_policy",
    "component_strategy", "components", "compute_delivery", "default_cluster", "diff_trees", "egress_errors",
    "egress_objects", "egress_project_params", "fqdn_errors", "gateway_errors", "load_capabilities", "load_pins", "load_platform",
    "load_release_history", "load_yaml", "main", "project_params", "project_pin_warnings", "release_deletions",
    "render_all", "render_component", "render_helm", "render_native", "schema_errors", "semantic_check",
    "semantic_errors", "surge_pods", "validate_all", "validate_all_full", "values_errors", "volumes", "write_tree",
]

if __name__ == "__main__":  # pragma: no cover  (execute en sous-processus, hors mesure de couverture)
    sys.exit(main())
