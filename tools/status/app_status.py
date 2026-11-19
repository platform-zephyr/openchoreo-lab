#!/usr/bin/env python3
"""Lecture anonyme du statut de déploiement d'une app par les check runs GitHub (T-497, première moitié de T-006).

Rôle : un agent sans accès cluster et sans identifiant lit le check run `argocd/<application Argo>` que le contrôleur
Argo CD Notifications publie sur OKE sous l'App `openchoreo-status` (T-489, gabarits de
`platform/install/argocd/notifications/argocd-notifications-cm.yaml`), pour une révision Git.

Usage : python3 tools/status/app_status.py <app> [--sha SHA | --ref REF] [--repo OWNER/NOM] [--cache-dir DOSSIER]
  <app>   nom de l'app (`whoami` -> Application `lab-o-whoami`) ou nom complet d'Application `lab-o-*` / `lab-k-*`.
  --ref   branche, tag ou SHA (défaut : main) ; --sha impose un SHA hexadécimal (7 à 40 caractères).

Sortie (stdout) : UN objet JSON, schéma `app-checkrun.v1`, clés triées, toujours toutes présentes :
  schema        "app-checkrun.v1"
  app           nom donné en argument
  argo_app      Application Argo CD (`lab-o-<app>` ou `lab-k-<app>`)
  check_name    nom du check run lu (`argocd/<argo_app>`)
  repo          dépôt GitHub lu (OWNER/NOM ; dépôt source de l'Application)
  ref           révision demandée (SHA, branche ou tag)
  revision      SHA du check run retenu ; à défaut le SHA demandé ; sinon null
  conclusion    success | failure | pending | absent ; null si `error` est renseigné
  details_url   lien du check run (arbre Git de l'app à la révision) ou null
  completed_at  horodatage ISO 8601 du check run ou null
  source        api (réponse GitHub, y compris 304) | cache (aucune requête faite) | none (rien lu)
  fetched_at    horodatage ISO 8601 UTC de la lecture GitHub servie, ou null
  stale         true si le cache servi a plus de 60 s (requête refusée par la limite locale ou par GitHub)
  github        {"status": ..., "conclusion": ...} bruts du check run retenu (null si absent)
  error         null, ou {"code": ..., "message": ..., "retry_after_s": entier ou null}
Interprétation : success = Synced + Healthy ; failure = Degraded ou synchro en échec (diagnose-app, côté coordinateur) ;
pending = Progressing (check run `neutral`) ou check run non terminé ; absent = aucun check run de `openchoreo-status`
sous ce nom pour cette révision (pas encore synchronisée, app hors OKE, ou Notifications non posé sur le cluster).
Un check run d'une autre App GitHub (Actions, etc.) portant le même nom est ignoré.

Codes de sortie : 0 lecture faite (quelle que soit la conclusion) ; 2 usage ou app inconnue (aucune requête) ;
3 limite de débit (locale : 1 requête par minute ; ou GitHub 403/429) sans cache utilisable ; 4 erreur de l'API ou
du réseau (dépôt ou révision introuvable compris).

Garanties : API publique, requêtes ANONYMES (aucun jeton lu dans l'environnement, aucun en-tête Authorization),
au plus une requête par minute (horloge locale dans le cache), requête conditionnelle (ETag), jamais de boucle ni
d'attente. Cache : `$APP_STATUS_CACHE_DIR`, sinon `$XDG_CACHE_HOME/openchoreo-lab/app-status`, sinon
`~/.cache/openchoreo-lab/app-status` ; il ne contient que des statuts publics et des ETag. Python standard seulement.
"""

from __future__ import annotations

import argparse
import contextlib
import datetime
import hashlib
import json
import math
import os
import re
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable
from pathlib import Path
from typing import Any

SCHEMA = "app-checkrun.v1"
API = "https://api.github.com"
USER_AGENT = "openchoreo-lab-app-status"
MIN_INTERVAL_S = 60
CHECK_PREFIX = "argocd/"
STATUS_APP_SLUG = "openchoreo-status"
ROOT = Path(__file__).resolve().parents[2]
LAB_APPS = Path("platform/install/argocd/apps/lab-apps.yaml")
LAB_K_ROOT = Path("platform/install/argocd/apps/lab-k-root.yaml")
PROJECTS = Path("generated/namespaces/default/projects")

EXIT_OK, EXIT_USAGE, EXIT_RATE, EXIT_API = 0, 2, 3, 4
APP_RE = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")
SHA_RE = re.compile(r"^[0-9a-f]{7,40}$")
REF_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]*(?:/[A-Za-z0-9_][A-Za-z0-9._-]*)*$")
REPO_RE = re.compile(r"^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$")
REPO_URL_RE = re.compile(r"^\s*repoURL:\s*https://github\.com/([A-Za-z0-9-]+/[A-Za-z0-9._-]+?)(?:\.git)?\s*$", re.M)
EXCLUDE_RE = re.compile(r"path:\s*generated/namespaces/default/projects/([a-z0-9-]+)\s*,\s*exclude:\s*true")
FAILURES = {"failure", "timed_out", "cancelled", "action_required", "startup_failure"}

Response = tuple[int, dict[str, str], bytes]
Fetcher = Callable[[urllib.request.Request], Response]


class StatusError(Exception):
    """Erreur rendue dans le champ `error` de la sortie, avec son code de sortie."""

    def __init__(self, code: str, message: str, exit_code: int, retry_after_s: int | None = None) -> None:
        super().__init__(message)
        self.code, self.message, self.exit_code, self.retry_after_s = code, message, exit_code, retry_after_s

    def as_dict(self) -> dict[str, Any]:
        return {"code": self.code, "message": self.message, "retry_after_s": self.retry_after_s}


def iso(ts: float | None) -> str | None:
    if ts is None:
        return None
    return datetime.datetime.fromtimestamp(ts, datetime.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def repo_from(path: Path) -> str:
    """Premier `repoURL: https://github.com/OWNER/NOM` du manifeste (source des Applications)."""
    m = REPO_URL_RE.search(path.read_text(encoding="utf-8"))
    if not m:
        raise StatusError("config", f"repoURL GitHub introuvable dans {path.name}", EXIT_USAGE)
    return m[1]


def resolve_target(app: str, repo: str | None, root: Path = ROOT) -> tuple[str, str]:
    """(Application Argo CD, dépôt OWNER/NOM) pour <app> ; refuse une app inconnue sans requête réseau."""
    if not APP_RE.match(app):
        raise StatusError("usage", "nom d'app invalide (minuscules, chiffres, tirets)", EXIT_USAGE)
    if repo is not None and not REPO_RE.match(repo):
        raise StatusError("usage", "--repo attend OWNER/NOM", EXIT_USAGE)
    if app.startswith("lab-k-"):
        return app, repo or repo_from(root / LAB_K_ROOT)
    name = app.removeprefix("lab-o-")
    lab_apps = root / LAB_APPS
    excluded = set(EXCLUDE_RE.findall(lab_apps.read_text(encoding="utf-8")))
    if not name or not (root / PROJECTS / name).is_dir():
        raise StatusError("unknown_app", f"app inconnue : aucun dossier {PROJECTS}/{name}", EXIT_USAGE)
    if name in excluded:
        raise StatusError(
            "unknown_app", f"app {name} exclue de l'ApplicationSet lab-o : non déployée sur OKE", EXIT_USAGE
        )
    return f"lab-o-{name}", repo or repo_from(lab_apps)


def classify(runs: list[dict[str, Any]], check_name: str) -> dict[str, Any]:
    """Check run le plus récent (id maximal) de l'App openchoreo-status, ramené à 4 conclusions."""
    own = [r for r in runs if r.get("name") == check_name and (r.get("app") or {}).get("slug") == STATUS_APP_SLUG]
    if not own:
        return {"conclusion": "absent", "revision": None, "details_url": None, "completed_at": None, "github": None}
    run = max(own, key=lambda r: int(r.get("id") or 0))
    status, concl = run.get("status"), run.get("conclusion")
    if status != "completed":
        verdict = "pending"
    elif concl == "success":
        verdict = "success"
    elif concl in FAILURES:
        verdict = "failure"
    else:  # neutral (Progressing), skipped, stale : pas de verdict final
        verdict = "pending"
    return {
        "conclusion": verdict,
        "revision": run.get("head_sha"),
        "details_url": run.get("details_url") or run.get("html_url"),
        "completed_at": run.get("completed_at"),
        "github": {"status": status, "conclusion": concl},
    }


def http_fetch(req: urllib.request.Request) -> Response:
    """Requête HTTPS réelle ; une réponse HTTP d'erreur est rendue, pas levée."""
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:  # URL construite sur API (https)
            return resp.status, {k.lower(): v for k, v in resp.headers.items()}, resp.read()
    except urllib.error.HTTPError as exc:
        headers = {k.lower(): v for k, v in (exc.headers or {}).items()}
        return exc.code, headers, exc.read() or b""


class Cache:
    """Statuts publics et ETag par (dépôt, révision, check), plus l'horloge de débit. Écritures atomiques."""

    def __init__(self, directory: Path) -> None:
        self.dir = directory

    def _read(self, name: str) -> dict[str, Any] | None:
        try:
            data = json.loads((self.dir / name).read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return None
        return data if isinstance(data, dict) else None

    def _write(self, name: str, data: dict[str, Any]) -> None:
        self.dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        fd, tmp = tempfile.mkstemp(dir=self.dir, prefix=".tmp-")
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, sort_keys=True)
        os.replace(tmp, self.dir / name)

    def state(self) -> dict[str, Any]:
        return self._read("state.json") or {}

    def save_state(self, state: dict[str, Any]) -> None:
        self._write("state.json", state)

    def get(self, key: str) -> dict[str, Any] | None:
        return self._read(f"entry-{key}.json")

    def put(self, key: str, entry: dict[str, Any]) -> None:
        self._write(f"entry-{key}.json", entry)


def default_cache_dir() -> Path:
    if os.environ.get("APP_STATUS_CACHE_DIR"):
        return Path(os.environ["APP_STATUS_CACHE_DIR"])
    base = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    return base / "openchoreo-lab" / "app-status"


def build_request(repo: str, ref: str, check_name: str, etag: str | None) -> urllib.request.Request:
    query = urllib.parse.urlencode({"check_name": check_name, "filter": "all", "per_page": 100})
    url = f"{API}/repos/{repo}/commits/{urllib.parse.quote(ref, safe='/')}/check-runs?{query}"
    headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28", "User-Agent": USER_AGENT}
    if etag:
        headers["If-None-Match"] = etag
    return urllib.request.Request(url, headers=headers, method="GET")


def rate_limit_until(status: int, headers: dict[str, str], now: float) -> float | None:
    """Fin de blocage annoncée par GitHub (403/429 de limite de débit), sinon None."""
    if status not in (403, 429):
        return None
    if headers.get("retry-after", "").isdigit():
        return now + int(headers["retry-after"])
    if headers.get("x-ratelimit-remaining") == "0" and headers.get("x-ratelimit-reset", "").isdigit():
        return max(float(headers["x-ratelimit-reset"]), now + MIN_INTERVAL_S)
    return now + MIN_INTERVAL_S if status == 429 else None


def served(entry: dict[str, Any], source: str, now: float) -> dict[str, Any]:
    out = dict(entry["result"])
    out.update(source=source, fetched_at=iso(entry["fetched_at"]), stale=now - entry["fetched_at"] >= MIN_INTERVAL_S)
    return out


def parse_runs(status: int, body: bytes) -> list[dict[str, Any]]:
    """Liste `check_runs` d'une réponse 200, sinon StatusError (404/422 : introuvable)."""
    if status in (404, 422):
        raise StatusError("not_found", f"dépôt ou révision introuvable (HTTP {status})", EXIT_API)
    if status != 200:
        raise StatusError("api_error", f"réponse inattendue de l'API GitHub (HTTP {status})", EXIT_API)
    try:
        runs = json.loads(body)["check_runs"]
    except (ValueError, KeyError, TypeError):
        raise StatusError("api_error", "réponse de l'API GitHub illisible", EXIT_API) from None
    if not isinstance(runs, list):
        raise StatusError("api_error", "réponse de l'API GitHub illisible", EXIT_API)
    return runs


def fetch_status(repo: str, ref: str, check_name: str, cache: Cache, fetch: Fetcher, now: float) -> dict[str, Any]:
    """Résultat partiel (conclusion, revision, …, source, fetched_at, stale) ; au plus UNE requête, jamais d'attente."""
    key = hashlib.sha256(f"{repo}|{ref}|{check_name}".encode()).hexdigest()[:32]
    entry, state = cache.get(key), cache.state()
    if entry and now - entry["fetched_at"] < MIN_INTERVAL_S:
        return served(entry, "cache", now)
    limited = float(state.get("rate_limited_until") or 0)
    blocked = max(float(state.get("last_request_at") or 0) + MIN_INTERVAL_S, limited)
    if now < blocked:
        if entry:
            return served(entry, "cache", now)
        code = "rate_limited" if now < limited else "throttled"
        raise StatusError(
            code,
            "limite de débit : aucune requête avant l'échéance (pas de nouvel essai automatique)",
            EXIT_RATE,
            math.ceil(blocked - now),
        )
    state["last_request_at"] = now
    cache.save_state(state)  # avant la requête : une requête interrompue compte quand même
    try:
        status, headers, body = fetch(build_request(repo, ref, check_name, (entry or {}).get("etag")))
    except (urllib.error.URLError, OSError) as exc:
        raise StatusError("network", f"API GitHub injoignable ({type(exc).__name__})", EXIT_API) from None
    if status == 304 and entry:
        entry["fetched_at"] = now
        cache.put(key, entry)
        return served(entry, "api", now)
    until = rate_limit_until(status, headers, now)
    if until is not None:
        state["rate_limited_until"] = until
        cache.save_state(state)
        if entry:
            return served(entry, "cache", now)
        raise StatusError(
            "rate_limited",
            f"GitHub a refusé la requête anonyme (HTTP {status}, limite de débit)",
            EXIT_RATE,
            math.ceil(until - now),
        )
    runs = parse_runs(status, body)
    entry = {"fetched_at": now, "etag": headers.get("etag"), "result": classify(runs, check_name)}
    cache.put(key, entry)
    return served(entry, "api", now)


def read_status(
    app: str,
    ref: str,
    repo: str | None = None,
    *,
    cache: Cache,
    fetch: Fetcher = http_fetch,
    now: float | None = None,
    root: Path = ROOT,
    require_sha: bool = False,
) -> tuple[dict[str, Any], int]:
    """(objet app-checkrun.v1, code de sortie). Toutes les clés sont toujours présentes."""
    out: dict[str, Any] = {
        "schema": SCHEMA,
        "app": app,
        "argo_app": None,
        "check_name": None,
        "repo": repo,
        "ref": ref,
        "revision": ref if SHA_RE.match(ref) else None,
        "conclusion": None,
        "details_url": None,
        "completed_at": None,
        "source": "none",
        "fetched_at": None,
        "stale": False,
        "github": None,
        "error": None,
    }
    try:
        if require_sha and not SHA_RE.match(ref):
            raise StatusError("usage", "--sha attend 7 à 40 caractères hexadécimaux minuscules", EXIT_USAGE)
        if not REF_RE.match(ref) or ".." in ref:
            raise StatusError("usage", "révision invalide", EXIT_USAGE)
        argo_app, out["repo"] = resolve_target(app, repo, root)
        out["argo_app"], out["check_name"] = argo_app, CHECK_PREFIX + argo_app
        result = fetch_status(out["repo"], ref, out["check_name"], cache, fetch, time.time() if now is None else now)
    except StatusError as exc:
        out["error"] = exc.as_dict()
        return out, exc.exit_code
    out.update(result, revision=result["revision"] or out["revision"])
    return out, EXIT_OK


def main(argv: list[str] | None = None, fetch: Fetcher = http_fetch) -> int:
    parser = argparse.ArgumentParser(description="Statut de déploiement d'une app par les check runs GitHub (anonyme).")
    parser.add_argument("app")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--sha", help="SHA hexadécimal (7 à 40 caractères)")
    group.add_argument("--ref", default="main", help="branche, tag ou SHA (défaut : main)")
    parser.add_argument("--repo", help="dépôt OWNER/NOM (défaut : dépôt source de l'Application)")
    parser.add_argument("--cache-dir", type=Path, default=None)
    args = parser.parse_args(argv)
    cache = Cache(args.cache_dir or default_cache_dir())
    out, rc = read_status(
        args.app, args.sha or args.ref, args.repo, cache=cache, fetch=fetch, require_sha=args.sha is not None
    )
    with contextlib.suppress(BrokenPipeError):
        json.dump(out, sys.stdout, indent=2, sort_keys=True, ensure_ascii=False)
        sys.stdout.write("\n")
    return rc


if __name__ == "__main__":
    sys.exit(main())
