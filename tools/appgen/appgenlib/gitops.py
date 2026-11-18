"""Controles GitOps de la commande `check` : derive, releases supprimees, references de release, 2e PR de pin.

Role : comparer le rendu a generated/, refuser la suppression d'une ComponentRelease d'un composant conserve (A2),
verifier que chaque ReleaseBinding pointe un fichier, et signaler un Project modifie sans nouveau pin (A3).
Entrees : arborescences generees, chemins et parametres a une revision git de base (lecture seule `git ls-tree`,
`git show`), pins.
Sorties : listes de messages (erreurs ou avertissements) ; CalledProcessError si la revision git est illisible.
"""
from __future__ import annotations

import filecmp
import re
import subprocess
from pathlib import Path

import yaml

from appgenlib.config import ROOT
from appgenlib.model import load_yaml

_RELEASE_PATH = re.compile(r"^(?P<comp>generated/namespaces/[^/]+/projects/[^/]+/components/[^/]+)/releases/(?P<rel>[^/]+)\.yaml$")


def release_deletions(base_paths: set[str], current_paths: set[str]) -> list[str]:
    """A2 : une ComponentRelease presente sur la base et absente maintenant, alors que son composant existe
    toujours, est une suppression interdite (binding de rollback casse, Application OutOfSync). La purge
    accompagne le retrait du composant entier (component.yaml absent)."""
    errs = []
    for p in sorted(base_paths - current_paths):
        m = _RELEASE_PATH.match(p)
        if m and f"{m['comp']}/component.yaml" in current_paths:
            errs.append(f"release supprimee : {p} (releases/ en ajout seul ; rollback = revert de app.yaml puis render)")
    return errs


def project_pin_warnings(base_params: dict, cur_params: dict, base_pins: dict, cur_pins: dict) -> list[str]:
    """A3 : parametres d'un Project existant modifies sans changement de pin -> le PRB reste sur l'ancienne
    ProjectRelease (quota, NetworkPolicy, PVC non appliques, T-PIN-STALE). Signale la 2e PR."""
    out = []
    for app in sorted(set(base_params) & set(cur_params)):
        if base_params[app] == cur_params[app]:
            continue
        keys = {k for k in set(base_pins) | set(cur_pins) if k.startswith(f"{app}/")}
        if any(base_pins.get(k) != cur_pins.get(k) for k in keys):
            continue
        out.append(f"{app} : parametres du Project modifies ; 2e PR requise apres merge : "
                   f"tools/appgen/appgen.py pin-project {app} <env> <status.latestRelease.name du Project>")
    return out


def binding_errors(generated: Path) -> list[str]:
    """Chaque ReleaseBinding doit pointer une ComponentRelease presente dans generated/ (A2)."""
    errs = []
    for path in sorted(generated.glob("namespaces/*/projects/*/components/*/release-bindings/*.yaml")):
        obj = load_yaml(path)
        rel = obj["spec"].get("releaseName")
        if not (path.parent.parent / "releases" / f"{rel}.yaml").exists():
            errs.append(f"{path.relative_to(generated)} : releaseName '{rel}' sans fichier releases/{rel}.yaml")
    return errs


def _git(args: list[str]) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args], check=True, capture_output=True, text=True).stdout


def base_state(ref: str) -> tuple[set[str], dict, dict]:
    """(chemins generated/, parametres Project, pins Project) a la revision ref (lecture git seule)."""
    paths = set(_git(["ls-tree", "-r", "--name-only", ref, "--", "generated/"]).split())
    params = {}
    for p in paths:
        if re.fullmatch(r"generated/namespaces/[^/]+/projects/[^/]+/project\.yaml", p):
            obj = yaml.safe_load(_git(["show", f"{ref}:{p}"]))
            params[obj["metadata"]["name"]] = obj["spec"].get("parameters", {})
    try:
        pins = (yaml.safe_load(_git(["show", f"{ref}:pins/project-releases.yaml"])) or {}).get("pins") or {}
    except subprocess.CalledProcessError:
        pins = {}
    return paths, params, {str(k): str(v) for k, v in pins.items()}


def diff_trees(expected: Path, actual: Path) -> list[str]:
    """Liste les differences entre deux arborescences generees (fichiers ajoutes, retires, modifies)."""
    def listing(base: Path) -> set[str]:
        return {str(p.relative_to(base)) for p in base.rglob("*") if p.is_file()} if base.exists() else set()

    a, b = listing(expected), listing(actual)
    diffs = [f"absent de generated/ : {x}" for x in sorted(a - b)]
    diffs += [f"fichier en trop dans generated/ : {x}" for x in sorted(b - a)]
    for common in sorted(a & b):
        if not filecmp.cmp(expected / common, actual / common, shallow=False):
            diffs.append(f"modifie : {common}")
    return diffs
