"""Projection des reponses GitHub vers des lignes bronze (T-201, ADR-0019).

Liste blanche de champs : aucun corps de PR, aucun titre, aucun login, aucune URL ne sort d'ici. Les valeurs
derivees (agent, classe, app, revert) sont calculees avant que le texte source soit jete. Stdlib seule.
"""
from __future__ import annotations

import re
from datetime import UTC, datetime

PR_FIELDS = (
    "pr_number", "created_at", "merged_at", "closed_at", "merged", "agent", "class", "app", "deploy_scope",
    "is_revert", "is_fix", "reverts_pr", "human_reviews", "enriched",
)
RUN_FIELDS = ("run_id", "workflow", "event", "conclusion", "created_at", "updated_at", "agent")
SOURCES = {"pr": ("pr_number", PR_FIELDS), "run": ("run_id", RUN_FIELDS)}

_AGENT_PREFIXES = ("claude", "codex")
_CLASS_RE = re.compile(r"^class:\s*(AUTONOME|REVUE|MANDAT)$", re.IGNORECASE)
_REVERTS_RE = re.compile(r"\bReverts?\s+(?:[\w.-]+/[\w.-]+)?#(\d+)", re.IGNORECASE)
_FIX_RE = re.compile(r"^(fix|revert)(\([^)]*\))?!?:", re.IGNORECASE)
_APP_RE = re.compile(r"^apps/([a-z0-9][a-z0-9-]*)/")
_SECRETISH = re.compile(r"(ghp_|gho_|ghs_|github_pat_|AKIA[0-9A-Z]{8}|-----BEGIN |xox[bp]-)")
_DEPLOY_PREFIXES = ("apps/", "platform/")


def classify_agent(head_ref: str | None, user_type: str | None) -> str:
    """Categorie pseudonyme stable : claude, codex, bot ou human. Jamais un login."""
    ref = (head_ref or "").lower()
    for prefix in _AGENT_PREFIXES:
        if ref.startswith(prefix + "/"):
            return prefix
    return "bot" if (user_type or "").lower() == "bot" else "human"


def pr_class(labels: list[dict]) -> str:
    for label in labels or []:
        m = _CLASS_RE.match(str(label.get("name", "")).strip())
        if m:
            return m.group(1).upper()
    return "unknown"


def reverted_pr(body: str | None) -> int | None:
    m = _REVERTS_RE.search(body or "")
    return int(m.group(1)) if m else None


def apps_from_paths(paths: list[str]) -> list[str]:
    return sorted({m.group(1) for p in paths if (m := _APP_RE.match(p))})


def pr_row(pr: dict, files: list[str] | None = None, human_reviews: int | None = None) -> dict:
    """Une ligne bronze. `files` / `human_reviews` None = non enrichi (budget de requetes epuise)."""
    title = pr.get("title") or ""
    head_ref = (pr.get("head") or {}).get("ref")
    apps = apps_from_paths(files) if files is not None else []
    return {
        "pr_number": int(pr["number"]),
        "created_at": pr.get("created_at"),
        "merged_at": pr.get("merged_at"),
        "closed_at": pr.get("closed_at"),
        "merged": bool(pr.get("merged_at")),
        "agent": classify_agent(head_ref, (pr.get("user") or {}).get("type")),
        "class": pr_class(pr.get("labels") or []),
        "app": apps[0] if len(apps) == 1 else ("multi" if apps else "none"),
        "deploy_scope": any(p.startswith(_DEPLOY_PREFIXES) for p in files or []),
        "is_revert": title.lower().startswith("revert") or (head_ref or "").lower().startswith("revert"),
        "is_fix": bool(_FIX_RE.match(title)),
        "reverts_pr": reverted_pr(pr.get("body")),
        "human_reviews": human_reviews,
        "enriched": files is not None and human_reviews is not None,
    }


def run_row(run: dict) -> dict:
    return {
        "run_id": int(run["id"]),
        "workflow": str(run.get("name") or ""),
        "event": run.get("event"),
        "conclusion": run.get("conclusion"),
        "created_at": run.get("created_at"),
        "updated_at": run.get("updated_at"),
        "agent": classify_agent(run.get("head_branch"), None),
    }


def partition_day(row: dict) -> str:
    return str(row.get("created_at"))[:10]


def contains_secret(row: dict) -> bool:
    return any(isinstance(v, str) and _SECRETISH.search(v) for v in row.values())


def parse_ts(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(UTC)
