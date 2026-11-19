"""Tests hors réseau de tools/status/app_status.py (T-497) : fixtures JSON de l'API Checks, fetch factice.

Aucune requête réelle : chaque test injecte un `fetch` qui journalise les requêtes et rend une fixture. Couvre les
quatre conclusions, la sélection du check run le plus récent de l'App openchoreo-status, l'app inconnue ou exclue,
le check absent, la limite locale (1 requête/min), le 403/429 de GitHub, l'ETag (304), l'absence d'en-tête
Authorization, et la cohérence du nom de check avec platform/install/argocd/notifications/.
Usage : python3 -I -m unittest discover -s tests/status -p 'test_*.py'
"""

import importlib.util
import io
import json
import os
import re
import tempfile
import unittest
import urllib.error
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
FIX = Path(__file__).resolve().parent / "fixtures"
SPEC = importlib.util.spec_from_file_location("app_status", ROOT / "tools" / "status" / "app_status.py")
assert SPEC and SPEC.loader
ast = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ast)

SHA = "0123456789abcdef0123456789abcdef01234567"
T0 = 1_800_000_000.0
KEYS = {
    "schema",
    "app",
    "argo_app",
    "check_name",
    "repo",
    "ref",
    "revision",
    "conclusion",
    "details_url",
    "completed_at",
    "source",
    "fetched_at",
    "stale",
    "github",
    "error",
}


class FakeFetch:
    """Rend des réponses préparées et journalise les requêtes (aucun réseau)."""

    def __init__(self, *responses):
        self.responses = list(responses)
        self.requests = []

    def __call__(self, req):
        self.requests.append(req)
        resp = self.responses.pop(0)
        if isinstance(resp, Exception):
            raise resp
        return resp


def ok(fixture, etag='"e1"'):
    return 200, {"etag": etag}, (FIX / fixture).read_bytes()


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.cache = ast.Cache(Path(self.tmp.name))

    def tearDown(self):
        self.tmp.cleanup()

    def read(self, fetch, app="whoami", ref=SHA, now=T0, **kw):
        out, rc = ast.read_status(app, ref, cache=self.cache, fetch=fetch, now=now, **kw)
        self.assertEqual(set(out), KEYS)
        self.assertEqual(out["schema"], "app-checkrun.v1")
        return out, rc


class Conclusions(Base):
    def test_success(self):
        out, rc = self.read(FakeFetch(ok("check-runs-success.json")))
        self.assertEqual(rc, 0)
        self.assertEqual(out["conclusion"], "success")
        self.assertEqual((out["argo_app"], out["check_name"]), ("lab-o-whoami", "argocd/lab-o-whoami"))
        self.assertEqual(out["repo"], "platform-zephyr/openchoreo-lab")
        self.assertEqual(out["revision"], SHA)
        self.assertEqual(out["completed_at"], "2026-11-19T10:00:00Z")
        self.assertTrue(out["details_url"].startswith("https://github.com/platform-zephyr/openchoreo-lab/tree/"))
        self.assertEqual((out["source"], out["stale"], out["error"]), ("api", False, None))
        self.assertEqual(out["github"], {"status": "completed", "conclusion": "success"})

    def test_failure(self):
        self.assertEqual(self.read(FakeFetch(ok("check-runs-failure.json")))[0]["conclusion"], "failure")

    def test_neutral_and_in_progress_are_pending(self):
        for fx in ("check-runs-neutral.json", "check-runs-in-progress.json"):
            with self.subTest(fx), tempfile.TemporaryDirectory() as d:
                self.cache = ast.Cache(Path(d))
                self.assertEqual(self.read(FakeFetch(ok(fx)))[0]["conclusion"], "pending")

    def test_latest_run_wins(self):
        out, _ = self.read(FakeFetch(ok("check-runs-neutral-then-success.json")))
        self.assertEqual(out["conclusion"], "success")
        self.assertEqual(out["completed_at"], "2026-11-19T10:05:00Z")

    def test_absent_check(self):
        out, rc = self.read(FakeFetch(ok("check-runs-empty.json")))
        self.assertEqual((rc, out["conclusion"], out["details_url"], out["github"]), (0, "absent", None, None))
        self.assertEqual(out["revision"], SHA)

    def test_absent_on_branch_has_null_revision(self):
        out, _ = self.read(FakeFetch(ok("check-runs-empty.json")), ref="main")
        self.assertEqual((out["conclusion"], out["revision"], out["ref"]), ("absent", None, "main"))

    def test_foreign_app_run_is_ignored(self):
        self.assertEqual(self.read(FakeFetch(ok("check-runs-foreign-app.json")))[0]["conclusion"], "absent")

    def test_lab_k_app_reads_sandbox_repo(self):
        out, rc = self.read(FakeFetch(ok("check-runs-empty.json")), app="lab-k-demo")
        self.assertEqual(
            (rc, out["repo"], out["check_name"]), (0, "platform-zephyr/bench-ab-arm-k", "argocd/lab-k-demo")
        )


class Refusals(Base):
    def test_unknown_app_no_request(self):
        fetch = FakeFetch()
        out, rc = self.read(fetch, app="does-not-exist")
        self.assertEqual((rc, out["error"]["code"], out["conclusion"], out["source"]), (2, "unknown_app", None, "none"))
        self.assertEqual(fetch.requests, [])

    def test_app_excluded_from_oke(self):
        out, rc = self.read(FakeFetch(), app="mealie")
        self.assertEqual((rc, out["error"]["code"]), (2, "unknown_app"))

    def test_invalid_inputs(self):
        for app, ref, kw in (
            ("Who/ami", SHA, {}),
            ("whoami", "../etc", {}),
            ("whoami", "main", {"require_sha": True}),
            ("whoami", SHA, {"repo": "pas un dépôt"}),
        ):
            with self.subTest(app=app, ref=ref):
                fetch = FakeFetch()
                out, rc = self.read(fetch, app=app, ref=ref, **kw)
                self.assertEqual((rc, out["error"]["code"]), (2, "usage"))
                self.assertEqual(fetch.requests, [])

    def test_not_found(self):
        out, rc = self.read(FakeFetch((404, {}, b'{"message":"Not Found"}')))
        self.assertEqual((rc, out["error"]["code"]), (4, "not_found"))

    def test_network_error(self):
        out, rc = self.read(FakeFetch(urllib.error.URLError("hors ligne")))
        self.assertEqual((rc, out["error"]["code"]), (4, "network"))

    def test_unreadable_body(self):
        out, rc = self.read(FakeFetch((200, {}, b"<html>")))
        self.assertEqual((rc, out["error"]["code"]), (4, "api_error"))


class RateLimit(Base):
    def test_github_403_rate_limit_then_no_request(self):
        headers = {"x-ratelimit-remaining": "0", "x-ratelimit-reset": str(int(T0) + 1800)}
        fetch = FakeFetch((403, headers, b'{"message":"API rate limit exceeded"}'))
        out, rc = self.read(fetch)
        self.assertEqual((rc, out["error"]["code"], out["error"]["retry_after_s"]), (3, "rate_limited", 1800))
        # 10 minutes plus tard : toujours bloqué, AUCUNE nouvelle requête (pas de boucle).
        out, rc = self.read(fetch, now=T0 + 600)
        self.assertEqual((rc, out["error"]["code"], out["error"]["retry_after_s"]), (3, "rate_limited", 1200))
        self.assertEqual(len(fetch.requests), 1)

    def test_429_retry_after(self):
        out, rc = self.read(FakeFetch((429, {"retry-after": "120"}, b"")))
        self.assertEqual((rc, out["error"]["retry_after_s"]), (3, 120))

    def test_403_without_rate_limit_is_api_error(self):
        out, rc = self.read(FakeFetch((403, {"x-ratelimit-remaining": "42"}, b"{}")))
        self.assertEqual((rc, out["error"]["code"]), (4, "api_error"))

    def test_local_throttle_one_request_per_minute(self):
        fetch = FakeFetch(ok("check-runs-success.json"), ok("check-runs-empty.json"))
        self.read(fetch)
        out, rc = self.read(fetch, app="ntfy", now=T0 + 30)
        self.assertEqual((rc, out["error"]["code"], out["error"]["retry_after_s"]), (3, "throttled", 30))
        self.assertEqual(len(fetch.requests), 1)
        out, rc = self.read(fetch, app="ntfy", now=T0 + 61)
        self.assertEqual((rc, out["conclusion"], out["check_name"]), (0, "absent", "argocd/lab-o-ntfy"))
        self.assertEqual(len(fetch.requests), 2)

    def test_fresh_cache_served_without_request(self):
        fetch = FakeFetch(ok("check-runs-success.json"))
        self.read(fetch)
        out, rc = self.read(fetch, now=T0 + 10)
        self.assertEqual((rc, out["source"], out["stale"], out["conclusion"]), (0, "cache", False, "success"))
        self.assertEqual(len(fetch.requests), 1)

    def test_stale_cache_served_when_rate_limited(self):
        fetch = FakeFetch(ok("check-runs-success.json"), (429, {"retry-after": "600"}, b""))
        self.read(fetch)
        out, rc = self.read(fetch, now=T0 + 120)
        self.assertEqual((rc, out["source"], out["stale"], out["conclusion"]), (0, "cache", True, "success"))
        self.assertEqual(out["fetched_at"], ast.iso(T0))

    def test_etag_304_reuses_cache(self):
        fetch = FakeFetch(ok("check-runs-success.json", etag='"abc"'), (304, {}, b""))
        self.read(fetch)
        out, rc = self.read(fetch, now=T0 + 90)
        self.assertEqual(fetch.requests[1].get_header("If-none-match"), '"abc"')
        self.assertEqual((rc, out["source"], out["stale"], out["conclusion"]), (0, "api", False, "success"))


class Anonymity(Base):
    def test_no_authorization_header_even_with_token_in_env(self):
        fetch = FakeFetch(ok("check-runs-success.json"))
        with mock.patch.dict(os.environ, {"GITHUB_TOKEN": "factice", "GH_TOKEN": "factice"}):
            self.read(fetch)
        req = fetch.requests[0]
        self.assertIsNone(req.get_header("Authorization"))
        self.assertTrue(
            req.full_url.startswith(
                f"https://api.github.com/repos/platform-zephyr/openchoreo-lab/commits/{SHA}/check-runs?"
            )
        )
        self.assertIn("check_name=argocd%2Flab-o-whoami", req.full_url)
        self.assertEqual(req.get_method(), "GET")

    def test_cache_holds_no_token(self):
        with mock.patch.dict(os.environ, {"GITHUB_TOKEN": "valeur-factice-jeton"}):
            self.read(FakeFetch(ok("check-runs-success.json")))
        for f in Path(self.tmp.name).iterdir():
            self.assertNotIn("valeur-factice-jeton", f.read_text(encoding="utf-8"))


class Cli(Base):
    def test_main_prints_stable_json(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = ast.main(
                ["whoami", "--sha", SHA, "--cache-dir", self.tmp.name], fetch=FakeFetch(ok("check-runs-success.json"))
            )
        out = json.loads(buf.getvalue())
        self.assertEqual((rc, set(out), out["conclusion"]), (0, KEYS, "success"))
        self.assertEqual(list(out), sorted(out))

    def test_main_rejects_bad_sha(self):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = ast.main(["whoami", "--sha", "main", "--cache-dir", self.tmp.name], fetch=FakeFetch())
        self.assertEqual((rc, json.loads(buf.getvalue())["error"]["code"]), (2, "usage"))


class Consistency(unittest.TestCase):
    """Le nom lu par l'outil est celui que publient les gabarits de T-489."""

    def test_check_name_matches_notifications_templates(self):
        cm = (ROOT / "platform/install/argocd/notifications/argocd-notifications-cm.yaml").read_text(encoding="utf-8")
        names = re.findall(r'^\s+name:\s*"(.+)"\s*$', cm, re.M)
        self.assertEqual(names, [ast.CHECK_PREFIX + "{{.app.metadata.name}}"] * 3)
        self.assertIn("startsWith 'lab-o-'", cm)
        self.assertIn("startsWith 'lab-k-'", cm)

    def test_applicationset_name_prefix(self):
        lab_apps = (ROOT / ast.LAB_APPS).read_text(encoding="utf-8")
        self.assertIn('name: "lab-o-{{.app}}"', lab_apps)
        self.assertIn(f"path: {ast.LAB_O_LIST}", lab_apps)

    def test_listed_apps_resolve(self):
        """T-502 : chaque app de la liste OKE se résout en lab-o-<app> ; une app générée hors liste est refusée."""
        listed = ast.LISTED_RE.findall((ROOT / ast.LAB_O_LIST).read_text(encoding="utf-8"))
        self.assertEqual(sorted(listed), ["echo-demo", "ntfy", "searxng", "whoami"])
        for app in listed:
            self.assertEqual(ast.resolve_target(app, None)[0], f"lab-o-{app}")
        with self.assertRaises(ast.StatusError):
            ast.resolve_target("miniflux", None)


if __name__ == "__main__":
    unittest.main()
