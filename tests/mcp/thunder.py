"""Crée / supprime les clients OAuth2 de test sur le ThunderID du k3d (jamais ailleurs).

Usage : thunder.py create | delete
- Jeton d'administration : application système du k3d (openchoreo-system-app, scope `system`).
  Son secret est lu au moment de l'exécution dans la ConfigMap thunder/thunder-bootstrap
  (valeur de développement du chart k3d) ou dans THUNDER_SYSTEM_CLIENT_SECRET. Rien en dur.
- Secrets des clients de test : aléatoires, écrits dans MCP_TEST_STATE (0600, hors dépôt).
"""
import json
import os
import re
import secrets
import subprocess
import sys
import urllib.error
import urllib.request

from mcp import STATE, THUNDER, token

CLIENTS = {
    "openchoreo-agent-reader": "Agent IA lecture (test k3d)",
    "openchoreo-agent-operator": "Agent IA opérateur runtime (test k3d)",
    "lab-platform-admin-test": "Admin plateforme (test k3d, sert à evaluate_authz)",
}
OU = "01900000-0000-7000-8000-000000000001"  # OU `default` du bootstrap k3d


def system_token():
    sec = os.environ.get("THUNDER_SYSTEM_CLIENT_SECRET")
    if not sec:
        cm = subprocess.check_output(["kubectl", "-n", "thunder", "get", "cm", "thunder-bootstrap", "-o", "json"])
        sec = re.search(r"clientSecret: (\S+)", json.loads(cm)["data"]["55-system-app.yaml"]).group(1)
    return token("openchoreo-system-app", sec, scope="system", resource=THUNDER + "/mcp")


def api(method, path, tok, body=None):
    req = urllib.request.Request(THUNDER + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
    try:
        r = urllib.request.urlopen(req, timeout=15)
        t = r.read().decode()
        return r.status, (json.loads(t) if t.strip() else None)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]


def existing(tok):
    _, d = api("GET", "/applications?limit=200", tok)
    return {a.get("clientId"): a["id"] for a in (d or {}).get("applications", [])}


def create():
    tok = system_token()
    have = existing(tok)
    state = {}
    for cid, desc in CLIENTS.items():
        sec = secrets.token_urlsafe(32)
        body = {"name": cid, "description": desc, "type": "m2m", "ouId": OU,
                "inboundAuthConfig": [{"type": "oauth2", "config": {
                    "clientId": cid, "clientSecret": sec, "grantTypes": ["client_credentials"],
                    "tokenEndpointAuthMethod": "client_secret_post", "pkceRequired": False,
                    "publicClient": False,
                    "token": {"accessToken": {"clientConfig": {"validityPeriod": 900}}}}}]}
        if cid in have:
            code, out = api("PUT", "/applications/" + have[cid], tok, body)
        else:
            code, out = api("POST", "/applications", tok, body)
        if code >= 300:
            sys.exit("création %s : HTTP %s %s" % (cid, code, out))
        state[cid] = sec
        print("client %s : %s" % (cid, "mis à jour" if cid in have else "créé"))
    fd = os.open(STATE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(state, f)


def delete():
    tok = system_token()
    have = existing(tok)
    for cid in CLIENTS:
        if cid in have:
            code, _ = api("DELETE", "/applications/" + have[cid], tok)
            print("client %s : supprimé (HTTP %s)" % (cid, code))
    if os.path.exists(STATE):
        os.remove(STATE)


if __name__ == "__main__":
    {"create": create, "delete": delete}[sys.argv[1]]()
