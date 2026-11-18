"""Client GitHub en lecture seule avec budget de requetes (T-201 : < 1 000 req/h pour GITHUB_TOKEN).

Jeton lu dans l'environnement (GITHUB_TOKEN), jamais journalise. Chaque requete decremente le budget ; budget
epuise = `BudgetExhausted` (l'appelant degrade en ligne non enrichie). Methode GET uniquement. stdlib.
"""
from __future__ import annotations

import json
import os
import urllib.request

API = "https://api.github.com"
DEFAULT_BUDGET = 900  # marge sous 1 000 req/h


class BudgetExhausted(Exception):
    pass


class Client:
    def __init__(self, repo: str, budget: int = DEFAULT_BUDGET, token: str | None = None, opener=None) -> None:
        self.repo = repo
        self.budget = budget
        self.used = 0
        self._token = token if token is not None else os.environ.get("GITHUB_TOKEN", "")
        self._open = opener or urllib.request.urlopen

    def get(self, path: str, params: dict | None = None):
        if self.used >= self.budget:
            raise BudgetExhausted(f"{self.used}/{self.budget} requetes")
        self.used += 1
        query = "&".join(f"{k}={v}" for k, v in (params or {}).items())
        url = f"{API}/repos/{self.repo}/{path}" + (f"?{query}" if query else "")
        headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
        if self._token:
            headers["Authorization"] = f"Bearer {self._token}"
        req = urllib.request.Request(url, headers=headers, method="GET")
        with self._open(req, timeout=30) as resp:
            return json.load(resp)

    def pages(self, path: str, params: dict, key: str | None = None, max_pages: int = 10):
        for page in range(1, max_pages + 1):
            data = self.get(path, {**params, "per_page": 100, "page": page})
            items = data.get(key, []) if key else data
            yield from items
            if len(items) < 100:
                return
