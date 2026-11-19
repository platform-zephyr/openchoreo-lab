"""Tests hors ligne du collecteur pass-0/observe.py (T-501) : fixtures + serveur HTTP loopback. Aucun réseau externe."""
import io
import json
import os
import secrets
import subprocess
import sys
import tempfile
import threading
import unittest
from contextlib import redirect_stdout
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIX = HERE.parent / "fixtures" / "observe"
sys.path.insert(0, str(HERE))
import observe  # noqa: E402

PASSWORD = "pw-" + secrets.token_urlsafe(24)  # généré à chaque exécution : aucune valeur dans le dépôt
TITLE = "bench-pass0-m2"


def fixture(name):
    return (FIX / name).read_text(encoding="utf-8")


class Handler(BaseHTTPRequestHandler):
    categories = []
    expected_auth = None

    def log_message(self, *a):
        pass

    def reply(self, code, body=b""):
        self.send_response(code)
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            return self.reply(200, b"ok")
        if self.path == "/down":
            return self.reply(503)
        if self.path == "/v1/categories":
            if self.headers.get("Authorization") != Handler.expected_auth:
                return self.reply(401, b'{"error_message": "Access Unauthorized"}')
            return self.reply(200, json.dumps(Handler.categories).encode())
        self.reply(404)

    def do_POST(self):
        if self.headers.get("Authorization") != Handler.expected_auth:
            return self.reply(401)
        title = json.loads(self.rfile.read(int(self.headers["Content-Length"])))["title"]
        if any(c["title"] == title for c in Handler.categories):
            return self.reply(409)
        Handler.categories.append({"id": len(Handler.categories) + 1, "title": title})
        self.reply(201)


class Server:
    def __enter__(self):
        import base64
        Handler.categories = [{"id": 1, "title": "All"}]
        Handler.expected_auth = "Basic " + base64.b64encode(f"admin:{PASSWORD}".encode()).decode()
        self.srv = HTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.srv.serve_forever, daemon=True).start()
        return f"http://127.0.0.1:{self.srv.server_port}"

    def __exit__(self, *exc):
        self.srv.shutdown()
        self.srv.server_close()


def run_main(argv, env=None):
    out = io.StringIO()
    old = dict(os.environ)
    os.environ.update(env or {})
    try:
        with redirect_stdout(out):
            rc = observe.main(argv)
    finally:
        os.environ.clear()
        os.environ.update(old)
    return rc, out.getvalue()


class ParseTest(unittest.TestCase):
    def test_http_status(self):
        self.assertEqual(observe.parse_http_status(fixture("http-200.txt")), 200)
        self.assertEqual(observe.parse_http_status(fixture("http-503.txt")), 503)
        self.assertIsNone(observe.parse_http_status(fixture("http-garbage.txt")))

    def test_api_row(self):
        self.assertIs(observe.parse_api_row(fixture("categories-found.json"), TITLE), True)
        self.assertIs(observe.parse_api_row(fixture("categories-missing.json"), TITLE), False)
        self.assertIsNone(observe.parse_api_row(fixture("categories-auth-error.json"), TITLE))
        self.assertIsNone(observe.parse_api_row("<html>", TITLE))

    def test_stable_output(self):
        self.assertEqual(observe.emit({"http_status": 200}), '{"http_status": 200}')
        self.assertEqual(observe.emit({"api_row_found": None}), '{"api_row_found": null}')
        rc, out = run_main(["parse-api-row", str(FIX / "categories-found.json"), "--title", TITLE])
        self.assertEqual((rc, out), (0, '{"api_row_found": true}\n'))


class LiveLoopbackTest(unittest.TestCase):
    def test_http_status(self):
        with Server() as url:
            self.assertEqual(run_main(["http-status", "--base-url", url]), (0, '{"http_status": 200}\n'))
            self.assertEqual(run_main(["http-status", "--base-url", url, "--path", "/down"])[1], '{"http_status": 503}\n')

    def test_unreachable_is_null(self):
        with Server() as url:
            pass  # serveur arrêté : port fermé
        self.assertEqual(run_main(["http-status", "--base-url", url])[1], '{"http_status": null}\n')

    def test_api_row_found_and_idempotent(self):
        env = {"MINIFLUX_ADMIN_PASSWORD": PASSWORD}
        with Server() as url:
            for _ in range(2):  # 2e appel : POST 409, la ligne est relue quand même
                rc, out = run_main(["api-row", "--base-url", url, "--title", TITLE], env)
                self.assertEqual((rc, out), (0, '{"api_row_found": true}\n'))
            self.assertEqual(sum(c["title"] == TITLE for c in Handler.categories), 1)

    def test_wrong_or_missing_password_is_null_never_false(self):
        with Server() as url:
            self.assertEqual(run_main(["api-row", "--base-url", url, "--title", TITLE], {"MINIFLUX_ADMIN_PASSWORD": "autre"})[1], '{"api_row_found": null}\n')
            self.assertEqual(observe.observe_api_row(url, TITLE, "admin", None), {"api_row_found": None})

    def test_password_never_printed_or_written(self):
        with Server() as url, tempfile.TemporaryDirectory() as d:
            run = Path(d) / "M2.O.r0.json"
            run.write_text(json.dumps({"task": "M2", "observations": None}), encoding="utf-8")
            proc = subprocess.run(
                [sys.executable, "-I", str(HERE / "observe.py"), "api-row", "--base-url", url, "--title", TITLE, "--run-file", str(run)],
                env={"MINIFLUX_ADMIN_PASSWORD": PASSWORD, "PATH": os.environ["PATH"]}, capture_output=True, text=True, check=True)
            self.assertNotIn(PASSWORD, proc.stdout + proc.stderr)
            self.assertNotIn(PASSWORD, run.read_text(encoding="utf-8"))
            self.assertEqual(json.loads(run.read_text(encoding="utf-8"))["observations"], {"api_row_found": True})

    def test_bad_url_scheme_refused(self):
        with self.assertRaises(SystemExit):
            observe.check_url("file:///etc/passwd")


class MergeTest(unittest.TestCase):
    def test_merge_keeps_existing_observations(self):
        with tempfile.TemporaryDirectory() as d:
            run = Path(d) / "r.json"
            run.write_text(json.dumps({"observations": {"injected_fault": "port_faux"}}), encoding="utf-8")
            observe.merge_into_run(run, {"http_status": 200})
            self.assertEqual(json.loads(run.read_text(encoding="utf-8"))["observations"], {"http_status": 200, "injected_fault": "port_faux"})


class GraderCompatTest(unittest.TestCase):
    def test_output_feeds_graders(self):
        sys.path.insert(0, str(HERE.parents[2] / "tools" / "bench-ab"))
        import graders
        ok = json.loads((HERE.parent / "fixtures" / "checkruns" / "success.json").read_text(encoding="utf-8"))
        self.assertEqual(graders.grade("m1", ok, {"http_status": 200})["status"], "PASS")
        self.assertEqual(graders.grade("m1", ok, {"http_status": None})["status"], "NOT_TESTED")
        self.assertEqual(graders.grade("m2", ok, {"api_row_found": None})["status"], "NOT_TESTED")


if __name__ == "__main__":
    unittest.main()
