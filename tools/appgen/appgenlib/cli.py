"""Interface en ligne de commande d'appgen : validate, render, check, pin-resource, pin-project, promote, rollback.

Role : analyser les arguments, appeler validation, rendu et controles GitOps sur le depot (config.ROOT), afficher
le verdict et rendre un code de sortie (0 = OK, 1 = echec ou derive).
Entrees : argv ; arbre du depot ; revision git de base pour `check --base`.
Sorties : code de sortie, messages sur stdout/stderr ; `render` reecrit le dossier cible ; `pin-*` reecrit
config.PINS_PATH ou config.PROJECT_PINS_PATH ; `promote` et `rollback` reecrivent config.RELEASE_PINS_PATH (chemins
et config.ROOT lus via le module config a chaque appel).
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

from appgenlib import config
from appgenlib.config import ALLOWED_ENVIRONMENTS
from appgenlib.gitops import base_state, binding_errors, diff_trees, project_pin_warnings, release_deletions
from appgenlib.model import AppError, app_dirs, load_yaml
from appgenlib.promotion import promotion_pins, rollback_pins
from appgenlib.render import load_pins, render_all, write_tree
from appgenlib.validate import validate_all_full

DESCRIPTION = "appgen : apps/<nom>/app.yaml -> manifests OpenChoreo v1.3.3 (ou Application Argo CD) sous generated/."


def cmd_validate(args: argparse.Namespace) -> int:
    count = len(app_dirs(config.ROOT, examples=True))
    _, errors, warnings = validate_all_full(config.ROOT, args.allow_oke,
                                            allow_unenforced_fqdn=args.allow_unenforced_fqdn)
    for w in warnings:
        print(f"AVERTISSEMENT {w}", file=sys.stderr)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        print(f"appgen validate : ECHEC ({len(errors)} erreur(s) sur {count} app(s))", file=sys.stderr)
        return 1
    print(f"appgen validate : OK ({count} app(s))")
    return 0


def cmd_render(args: argparse.Namespace) -> int:
    out = Path(args.out) if args.out else config.ROOT / "generated"
    try:
        # Releases conservees : lues dans le dossier cible avant son effacement (A2, ajout seul).
        files = render_all(config.ROOT, Path(args.platform_dir), args.allow_oke, args.allow_unenforced_fqdn,
                           history_dir=out if out.exists() else config.ROOT / "generated")
    except AppError as exc:
        print(f"appgen render : ECHEC\n{exc}", file=sys.stderr)
        return 1
    if out.exists():
        shutil.rmtree(out)
    write_tree(files, out)
    print(f"appgen render : {len(files)} fichier(s) ecrits sous {out}")
    return 0


def _base_diffs(base: str, files: dict[str, object]) -> list[str]:
    """check --base : releases supprimees (erreurs) ; 2e PR pin-project (avertissements, sur stderr)."""
    root = config.ROOT
    base_paths, base_params, base_pins = base_state(base)
    cur_paths = {f"generated/{p.relative_to(root / 'generated')}" for p in (root / "generated").rglob("*.yaml")}
    cur_params = {obj["metadata"]["name"]: obj["spec"].get("parameters", {})
                  for obj in files.values() if isinstance(obj, dict) and obj.get("kind") == "Project"}
    for w in project_pin_warnings(base_params, cur_params, base_pins, load_pins(root, "project-releases.yaml")):
        print(f"AVERTISSEMENT {w}", file=sys.stderr)
    return release_deletions(base_paths, cur_paths)


def cmd_check(args: argparse.Namespace) -> int:
    root = config.ROOT
    try:
        files = render_all(root, Path(args.platform_dir), args.allow_oke, args.allow_unenforced_fqdn)
    except AppError as exc:
        print(f"appgen check : ECHEC\n{exc}", file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory() as tmp:
        tmp_out = Path(tmp) / "generated"
        write_tree(files, tmp_out)
        diffs = diff_trees(tmp_out, root / "generated")
    diffs += binding_errors(root / "generated")
    if args.base:
        try:
            diffs += _base_diffs(args.base, files)
        except subprocess.CalledProcessError as exc:
            print(f"appgen check : base '{args.base}' illisible ({exc.stderr.strip()})", file=sys.stderr)
            return 1
    if diffs:
        print("appgen check : DERIVE (lancer tools/appgen render et committer)", file=sys.stderr)
        print("\n".join(diffs), file=sys.stderr)
        return 1
    print(f"appgen check : OK, aucune derive ({len(files)} fichier(s))")
    return 0


def _write_pin(path: Path, header: str, key: str, release: str) -> None:
    """Ajoute ou remplace un pin, cles triees, avec un commentaire d'en-tete fixe."""
    _write_pins(path, header, {key: release})


def _write_pins(path: Path, header: str, new: dict[str, str]) -> None:
    """Ajoute ou remplace des pins, cles triees, avec un commentaire d'en-tete fixe."""
    path.parent.mkdir(parents=True, exist_ok=True)
    data = load_yaml(path) if path.exists() else None
    pins = dict((data or {}).get("pins") or {})
    pins.update(new)
    path.write_text(header + yaml.safe_dump({"pins": dict(sorted(pins.items()))}, sort_keys=False), encoding="utf-8")


def cmd_pin_resource(args: argparse.Namespace) -> int:
    """Pin de ResourceReleaseBinding : valeur lue par l'operateur (kubectl get resource ... status.latestRelease.name)."""
    if not re.fullmatch(rf"{re.escape(args.app)}-db-[a-z0-9]+", args.release):
        print(f"pin-resource : '{args.release}' ne ressemble pas a une ResourceRelease de {args.app}-db", file=sys.stderr)
        return 1
    _write_pin(config.PINS_PATH, "# Pins ResourceRelease (2e PR d'une base). Ecrit par tools/appgen pin-resource.\n",
               f"{args.app}/{args.env}", args.release)
    print(f"pin-resource : {args.app}/{args.env} -> {args.release} (relancer render puis committer)")
    return 0


def cmd_pin_project(args: argparse.Namespace) -> int:
    """Pin de ProjectReleaseBinding (A3, 2e PR apres tout changement des parametres du Project) : valeur lue par
    l'operateur (kubectl get project <app> -n default -o jsonpath='{.status.latestRelease.name}')."""
    if not re.fullmatch(rf"{re.escape(args.app)}-[0-9a-f]{{10}}", args.release):
        print(f"pin-project : '{args.release}' ne ressemble pas a une ProjectRelease de {args.app} "
              f"({args.app}-<10 hex>)", file=sys.stderr)
        return 1
    _write_pin(config.PROJECT_PINS_PATH,
               "# Pins ProjectRelease (2e PR apres un changement des parametres du Project). "
               "Ecrit par tools/appgen pin-project.\n",
               f"{args.app}/{args.env}", args.release)
    print(f"pin-project : {args.app}/{args.env} -> {args.release} (relancer render puis committer)")
    return 0


RELEASE_PINS_HEADER = ("# Pins ComponentRelease par environnement (T-003). Ecrit par tools/appgen promote / rollback ;\n"
                       "# production suit ce pin, development la release courante.\n")


def _release_pin_command(label: str, compute) -> int:
    try:
        pins = compute(config.ROOT / "generated")
    except AppError as exc:
        print(f"{label} : ECHEC\n{exc}", file=sys.stderr)
        return 1
    _write_pins(config.RELEASE_PINS_PATH, RELEASE_PINS_HEADER, pins)
    for key, rel in sorted(pins.items()):
        print(f"{label} : {key} -> {rel}")
    print(f"{label} : relancer render puis committer (une PR ; retour arriere = git revert de cette PR)")
    return 0


def cmd_promote(args: argparse.Namespace) -> int:
    """Production epingle la release development de chaque composant (lue dans generated/, donc mergee)."""
    return _release_pin_command("promote", lambda gen: promotion_pins(gen, args.app))


def cmd_rollback(args: argparse.Namespace) -> int:
    """Production repointe une release conservee (generated/, ajout seul) ; development n'est pas touche."""
    return _release_pin_command("rollback", lambda gen: rollback_pins(gen, args.app, args.release))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="appgen", description=DESCRIPTION)
    parser.add_argument("--platform-dir", default=str(config.ROOT / "platform"),
                        help="dossier contenant ClusterComponentType, ClusterTrait, ClusterProjectType (defaut : platform/)")
    parser.add_argument("--allow-oke", action=argparse.BooleanOptionalAction, default=True,
                        help="gate OKE franchi le 2026-11-17 (defaut) ; --no-allow-oke pour le refermer")
    parser.add_argument("--allow-unenforced-fqdn", action="store_true",
                        help="labo seulement : egress FQDN sur cluster sans Cilium -> avertissement, apercu marque "
                             "enforced=false, regles NON transmises (flux refuses)")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("validate").set_defaults(func=cmd_validate)
    p_render = sub.add_parser("render")
    p_render.add_argument("--out", default=None)
    p_render.set_defaults(func=cmd_render)
    p_check = sub.add_parser("check")
    p_check.add_argument("--base", default=None,
                         help="revision git de reference (ex. origin/main) : suppression de release, 2e PR pin-project")
    p_check.set_defaults(func=cmd_check)
    for cmd, func in (("pin-resource", cmd_pin_resource), ("pin-project", cmd_pin_project)):
        p_pin = sub.add_parser(cmd)
        p_pin.add_argument("app")
        p_pin.add_argument("env", choices=sorted(ALLOWED_ENVIRONMENTS))
        p_pin.add_argument("release")
        p_pin.set_defaults(func=func)
    p_promote = sub.add_parser("promote", help="pin production <- release development de chaque composant (T-003)")
    p_promote.add_argument("app")
    p_promote.set_defaults(func=cmd_promote)
    p_rollback = sub.add_parser("rollback", help="pin production <- release conservee d'un composant (T-003)")
    p_rollback.add_argument("app")
    p_rollback.add_argument("release", nargs="+")
    p_rollback.set_defaults(func=cmd_rollback)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return int(args.func(args))
