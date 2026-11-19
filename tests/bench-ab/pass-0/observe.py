#!/usr/bin/env python3
"""Collecteur des observations `http_status` (M1, M4) et `api_row_found` (M2) du banc A/B (T-501, ADR-0025).

Les graders (`tools/bench-ab/graders.py`) lisent ces deux clés ; rien ne les produisait. Ce script fait la mesure et
écrit UNE ligne JSON à clés triées, stable d'un appel à l'autre :
    {"http_status": 200}            {"api_row_found": true}
Une mesure impossible (hôte injoignable, réponse inexploitable) rend la valeur `null` : le grader répond NOT_TESTED,
jamais PASS. Le script ne contient aucun hôte, jeton ni mot de passe : l'adresse vient de `--base-url`, le mot de
passe de la variable d'environnement nommée par `--password-env` (défaut `MINIFLUX_ADMIN_PASSWORD`), lue en mémoire
seulement, jamais affichée ni écrite.

Usage :
  observe.py http-status --base-url URL [--path /health] [--run-file F]
  observe.py api-row     --base-url URL --title T [--user admin] [--password-env VAR] [--run-file F]
  observe.py parse-http-status F | parse-api-row F --title T      (fixtures hors ligne : lit un fichier)
--run-file : fusionne l'observation dans `observations` d'un fichier `bench-run.v1` (écriture atomique).
Codes : 0 observation écrite (même `null`) ; 2 usage.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

TIMEOUT_S = 10
CATEGORIES = "/v1/categories"


def emit(obs: dict) -> str:
    return json.dumps(obs, sort_keys=True, separators=(", ", ": "), ensure_ascii=False)


def parse_http_status(text: str) -> int | None:
    """Premier entier de 3 chiffres (100-599) d'une ligne d'état `HTTP/1.1 200 OK` ou d'un `curl -w %{http_code}`."""
    for token in text.split():
        if token.isdigit() and len(token) == 3 and 100 <= int(token) <= 599:
            return int(token)
    return None


def parse_api_row(body: str, title: str) -> bool | None:
    """Réponse de `GET /v1/categories` : tableau d'objets avec `title`. True si `title` y figure, False sinon,
    None si la réponse n'est pas un tableau d'objets (erreur d'authentification, page HTML : rien n'est prouvé)."""
    try:
        doc = json.loads(body)
    except ValueError:
        return None
    if not isinstance(doc, list) or not all(isinstance(item, dict) for item in doc):
        return None
    return any(item.get("title") == title for item in doc)


def request(url: str, method: str = "GET", headers: dict | None = None, body: bytes | None = None):
    """(code, texte) ; (None, '') si la connexion échoue. Les erreurs HTTP 4xx/5xx rendent leur code."""
    req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as resp:
            return resp.status, resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as err:
        return err.code, err.read().decode("utf-8", "replace")
    except (urllib.error.URLError, OSError, ValueError):
        return None, ""


def check_url(url: str) -> str:
    if not url.startswith(("http://", "https://")):
        raise SystemExit("observe.py : --base-url doit commencer par http:// ou https://")
    return url.rstrip("/")


def observe_http_status(base_url: str, path: str) -> dict:
    code, _ = request(check_url(base_url) + path)
    return {"http_status": code}


def observe_api_row(base_url: str, title: str, user: str, password: str | None) -> dict:
    """Crée la catégorie synthétique (201 ou 409 « existe déjà » admis) puis la relit. Sans mot de passe : null."""
    if not password:
        return {"api_row_found": None}
    base = check_url(base_url)
    token = base64.b64encode(f"{user}:{password}".encode()).decode()
    headers = {"Authorization": f"Basic {token}", "Content-Type": "application/json"}
    code, _ = request(base + CATEGORIES, "POST", headers, json.dumps({"title": title}).encode())
    if code not in (201, 409):
        return {"api_row_found": None}
    code, body = request(base + CATEGORIES, "GET", headers)
    return {"api_row_found": parse_api_row(body, title) if code == 200 else None}


def merge_into_run(path: Path, obs: dict) -> None:
    run = json.loads(path.read_text(encoding="utf-8"))
    current = run.get("observations") if isinstance(run.get("observations"), dict) else {}
    run["observations"] = {**current, **obs}
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=path.name + ".")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(run, indent=2, ensure_ascii=False) + "\n")
    os.replace(tmp, path)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("http-status", "api-row"):
        p = sub.add_parser(name)
        p.add_argument("--base-url", required=True)
        p.add_argument("--run-file")
        if name == "http-status":
            p.add_argument("--path", default="/health")
        else:
            p.add_argument("--title", required=True)
            p.add_argument("--user", default="admin")
            p.add_argument("--password-env", default="MINIFLUX_ADMIN_PASSWORD")
    for name in ("parse-http-status", "parse-api-row"):
        p = sub.add_parser(name)
        p.add_argument("file")
        if name == "parse-api-row":
            p.add_argument("--title", required=True)
    args = ap.parse_args(argv)

    if args.cmd == "http-status":
        obs = observe_http_status(args.base_url, args.path)
    elif args.cmd == "api-row":
        obs = observe_api_row(args.base_url, args.title, args.user, os.environ.get(args.password_env))
    elif args.cmd == "parse-http-status":
        obs = {"http_status": parse_http_status(Path(args.file).read_text(encoding="utf-8"))}
    else:
        obs = {"api_row_found": parse_api_row(Path(args.file).read_text(encoding="utf-8"), args.title)}

    if getattr(args, "run_file", None):
        merge_into_run(Path(args.run_file), obs)
    print(emit(obs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
