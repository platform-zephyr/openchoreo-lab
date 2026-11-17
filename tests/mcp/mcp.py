"""Client MCP minimal (JSON-RPC sur HTTP streamable) et jetons OAuth2 client_credentials.

Aucun secret en dur : les identifiants des clients de test sont lus dans un fichier d'état
hors dépôt (MCP_TEST_STATE, mode 0600), écrit par thunder.py. k3d seulement.
"""
import base64
import json
import os
import urllib.error
import urllib.parse
import urllib.request

THUNDER = os.environ.get("THUNDER_URL", "http://thunder.openchoreo.localhost:8080")
MCP_URL = os.environ.get("MCP_URL", "http://api.openchoreo.localhost:8080/mcp")
STATE = os.environ.get("MCP_TEST_STATE", os.path.join(os.environ.get("TMPDIR", "/tmp"), "lab-mcp-clients.json"))


def token(client_id, client_secret, scope=None, resource=None):
    data = {"grant_type": "client_credentials", "client_id": client_id, "client_secret": client_secret}
    if scope:
        data["scope"] = scope
    if resource:
        data["resource"] = resource
    req = urllib.request.Request(THUNDER + "/oauth2/token", data=urllib.parse.urlencode(data).encode(),
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    return json.load(urllib.request.urlopen(req, timeout=15))["access_token"]


def claims(tok):
    p = tok.split(".")[1]
    return json.loads(base64.urlsafe_b64decode(p + "=" * (-len(p) % 4)))


def load_state():
    with open(STATE) as f:
        return json.load(f)


def token_for(client_id):
    return token(client_id, load_state()[client_id])


class MCP:
    """Session MCP : initialize, puis tools/list et tools/call."""

    def __init__(self, tok, query=""):
        self.url = MCP_URL + query
        self.h = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
        if tok:
            self.h["Authorization"] = "Bearer " + tok
        self.id = 0
        self.sid = None
        self.init = self.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                            "clientInfo": {"name": "lab-mcp-tests", "version": "1"}})
        if "http" not in (self.init or {}):
            self.rpc("notifications/initialized", None, notif=True)

    def rpc(self, method, params, notif=False):
        self.id += 1
        body = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            body["params"] = params
        if not notif:
            body["id"] = self.id
        h = dict(self.h)
        if self.sid:
            h["Mcp-Session-Id"] = self.sid
        req = urllib.request.Request(self.url, data=json.dumps(body).encode(), headers=h)
        try:
            r = urllib.request.urlopen(req, timeout=30)
        except urllib.error.HTTPError as e:
            return {"http": e.code, "body": e.read().decode()[:300]}
        self.sid = r.headers.get("Mcp-Session-Id", self.sid)
        t = r.read().decode()
        if notif or not t.strip():
            return None
        for line in t.splitlines():
            if line.startswith("data:"):
                t = line[5:].strip()
                break
        return json.loads(t)

    def tools(self):
        r = self.rpc("tools/list", {})
        return sorted(t["name"] for t in r["result"]["tools"])

    def call(self, name, args):
        return self.rpc("tools/call", {"name": name, "arguments": args})


def outcome(resp):
    """Normalise une réponse tools/call en ('ok'|'denied'|'error', message court)."""
    if resp is None:
        return "error", "réponse vide"
    if "http" in resp:
        return "denied" if resp["http"] in (401, 403) else "error", "HTTP %s" % resp["http"]
    if "error" in resp:
        msg = resp["error"].get("message", "")
        return ("denied" if _is_denied(msg) else "error"), msg[:160]
    res = resp.get("result", {})
    text = " ".join(c.get("text", "") for c in res.get("content", []) if isinstance(c, dict))
    if res.get("isError"):
        return ("denied" if _is_denied(text) else "error"), text[:160]
    return "ok", text[:120]


def _is_denied(msg):
    m = msg.lower()
    return any(k in m for k in ("insufficient permission", "missing required permission", "forbidden",
                                "not authorized", "unauthorized", "permission denied"))
