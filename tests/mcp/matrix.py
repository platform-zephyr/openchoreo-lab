"""Matrice allow/deny MCP pour les identités agents (k3d seulement).

Prérequis : platform/authz/ et tests/mcp/fixtures/ appliqués, clients créés par thunder.py.
Sortie : une ligne `ID|RÉSULTAT|description|preuve` par test (PASS / FAIL / NOT_TESTED).
Aucun jeton ni secret n'est imprimé.
"""
import json
import subprocess
import sys
import time

from mcp import MCP, claims, outcome, token_for

NS, PRJ, COMP = "lab-mcp", "lab-mcp", "lab-target"
RB_DEV, RB_PROD = "lab-target-development", "lab-target-production"
WRITE_PREFIXES = ("create_", "update_", "delete_", "patch_", "trigger_")
OPERATOR_WRITES = {"create_component_release", "create_release_binding", "update_release_binding"}
results = []


def rec(tid, ok, desc, proof, status=None):
    st = status or ("PASS" if ok else "FAIL")
    results.append((tid, st, desc, proof))
    print("%s|%s|%s|%s" % (tid, st, desc, str(proof).replace("|", "/").replace("\n", " ")[:220]), flush=True)


def expect(tid, desc, sess, tool, args, want):
    st, msg = outcome(sess.call(tool, args))
    ok = (st == "denied") if want == "denied" else (st != "denied" if want == "authorized" else st == want)
    rec(tid, ok, desc, "%s -> %s: %s" % (tool, st, msg))
    return st


def kubectl(*a, stdin=None):
    return subprocess.run(["kubectl", *a], input=stdin, capture_output=True, text=True)


def rb_spec(name):
    out = kubectl("-n", NS, "get", "releasebinding", name, "-o", "json").stdout
    return json.loads(out)["spec"] if out else {}


def no_secret(tid, who, sess):
    """Aucune exposition de SecretReference : liste refusée ou vide, lecture unitaire refusée."""
    st, msg = outcome(sess.call("list_secret_references", {"namespace_name": NS}))
    rec(tid, st == "denied" or (st == "ok" and "lab-dummy-ref" not in msg),
        "%s (non filtré) : list_secret_references n'expose rien (référence factice présente)" % who,
        "list_secret_references -> %s: %s" % (st, msg[:100]))
    expect(tid + "b", "%s (non filtré) : get_secret_reference refusé" % who, sess, "get_secret_reference",
           {"namespace_name": NS, "secret_reference_name": "lab-dummy-ref"}, "denied")


def main():
    tr, to, ta = (token_for(c) for c in ("openchoreo-agent-reader", "openchoreo-agent-operator", "lab-platform-admin-test"))

    # --- Identités -------------------------------------------------------------------------
    for tid, t, cid in (("I1", tr, "openchoreo-agent-reader"), ("I2", to, "openchoreo-agent-operator")):
        c = claims(t)
        rec(tid, c.get("client_id") == cid and "groups" not in c,
            "jeton client_credentials %s : claim client_id, pas de groups (=> sujet service_account)" % cid,
            "claims=%s" % sorted(c))
    anon = MCP(None)
    rec("I3", (anon.init or {}).get("http") == 401, "MCP sans jeton refusé", anon.init)
    bad = MCP(tr[:-6] + "AAAAAA")
    rec("I4", (bad.init or {}).get("http") == 401, "MCP avec jeton à signature altérée refusé", bad.init)

    R, Ru = MCP(tr), MCP(tr, "?filterByAuthz=false")
    O, Ou = MCP(to), MCP(to, "?filterByAuthz=false")
    A = MCP(ta)

    # --- Filtrage de tools/list -----------------------------------------------------------------
    rt, ot, at, rut = R.tools(), O.tools(), A.tools(), Ru.tools()
    rw = [n for n in rt if n.startswith(WRITE_PREFIXES)]
    sens = [n for n in rt + ot if "authz" in n or "secret" in n]
    rec("L1", not rw and len(rt) > 20, "reader : liste filtrée sans aucun outil d'écriture",
        "%d outils, écriture=%s" % (len(rt), rw))
    ow = {n for n in ot if n.startswith(WRITE_PREFIXES)}
    rec("L2", ow == OPERATOR_WRITES, "operator : seuls outils d'écriture = runtime borné",
        "%d outils, écriture=%s" % (len(ot), sorted(ow)))
    rec("L3", not sens, "reader/operator : aucun outil authz ni secret_reference listé", "trouvés=%s" % sens)
    rec("L4", len(rut) == len(at) > len(rt),
        "filterByAuthz=false ne fait qu'afficher tous les outils (visibilité, pas permission)",
        "reader filtré=%d, non filtré=%d, admin=%d" % (len(rt), len(rut), len(at)))

    # --- Reader : lectures autorisées ---------------------------------------------------------
    expect("R1", "reader : list_namespaces", R, "list_namespaces", {}, "ok")
    expect("R2", "reader : list_components (lab-mcp)", R, "list_components",
           {"namespace_name": NS, "project_name": PRJ}, "ok")
    expect("R3", "reader : get_release_binding", R, "get_release_binding",
           {"namespace_name": NS, "binding_name": RB_DEV}, "ok")
    expect("R4", "reader : list_release_bindings", R, "list_release_bindings",
           {"namespace_name": NS, "component_name": COMP}, "ok")
    # --- Reader : écritures refusées, même en session non filtrée -----------------------------
    before = rb_spec(RB_DEV)
    expect("R5", "reader (non filtré) : update_release_binding refusé", Ru, "update_release_binding",
           {"namespace_name": NS, "binding_name": RB_DEV,
            "component_type_environment_configs": {"replicas": 3}}, "denied")
    rec("R5b", rb_spec(RB_DEV) == before, "reader : ReleaseBinding inchangé après le refus", "spec identique")
    expect("R6", "reader (non filtré) : create_component refusé", Ru, "create_component",
           {"namespace_name": NS, "project_name": PRJ, "name": "lab-evil",
            "component_type": "deployment/web-application"}, "denied")
    expect("R7", "reader (non filtré) : delete_component refusé", Ru, "delete_component",
           {"namespace_name": NS, "component_name": COMP}, "denied")
    no_secret("R8", "reader", Ru)
    expect("R9", "reader (non filtré) : list_authz_role_bindings (cluster) refusé", Ru,
           "list_authz_role_bindings", {"scope": "cluster"}, "denied")
    expect("R10", "reader (non filtré) : create_release_binding refusé", Ru, "create_release_binding",
           {"namespace_name": NS, "project_name": PRJ, "component_name": COMP,
            "environment": "development", "release_name": "x"}, "denied")

    # --- Operator : runtime borné ---------------------------------------------------------------
    expect("O1", "operator : update_release_binding replicas/ressources en development autorisé", O,
           "update_release_binding",
           {"namespace_name": NS, "binding_name": RB_DEV, "component_type_environment_configs": {
               "replicas": 2, "resources": {"requests": {"cpu": "50m", "memory": "32Mi"},
                                            "limits": {"cpu": "200m", "memory": "64Mi"}}}}, "ok")
    time.sleep(1)
    spec = rb_spec(RB_DEV)
    got = (spec.get("componentTypeEnvironmentConfigs") or {}).get("replicas")
    rec("O1b", got == 2, "operator : écriture effective dans le cluster (hors Git)", "spec.replicas=%s" % got)
    before = rb_spec(RB_PROD)
    expect("O2", "operator : update_release_binding en production refusé (condition CEL)", O,
           "update_release_binding",
           {"namespace_name": NS, "binding_name": RB_PROD,
            "component_type_environment_configs": {"replicas": 2}}, "denied")
    rec("G1", False, "dérive GitOps : Argo CD écrase-t-il l'écriture MCP sur un binding géré par Git ?",
        "A3 (Argo sur k3d) non terminé ; lab-mcp n'est pas géré par Git", status="NOT_TESTED")
    rec("O2b", rb_spec(RB_PROD) == before, "operator : binding production inchangé", "spec identique")
    expect("O3", "operator : create_component_release autorisé par l'authz (échec métier attendu : pas de workload)",
           O, "create_component_release", {"namespace_name": NS, "component_name": COMP}, "authorized")
    expect("O4", "operator (non filtré) : create_component refusé", Ou, "create_component",
           {"namespace_name": NS, "project_name": PRJ, "name": "lab-evil",
            "component_type": "deployment/web-application"}, "denied")
    expect("O5", "operator (non filtré) : delete_component refusé", Ou, "delete_component",
           {"namespace_name": NS, "component_name": COMP}, "denied")
    expect("O6", "operator (non filtré) : update_workload/create_workload refusé (image = Git)", Ou,
           "create_workload", {"namespace_name": NS, "component_name": COMP,
                               "workload_spec": {"container": {"image": "traefik/whoami:v1.10.3"}}}, "denied")
    no_secret("O7", "operator", Ou)
    expect("O8", "operator (non filtré) : create_secret_reference refusé", Ou, "create_secret_reference",
           {"namespace_name": NS, "name": "lab-evil", "spec": {}}, "denied")
    expect("O9", "operator (non filtré) : create_authz_role_binding (cluster) refusé", Ou,
           "create_authz_role_binding",
           {"scope": "cluster", "name": "lab-evil", "spec": {
               "entitlement": {"claim": "client_id", "value": "openchoreo-agent-operator"},
               "roleMappings": [{"roleRef": {"kind": "ClusterAuthzRole", "name": "admin"}}]}}, "denied")
    expect("O10", "operator (non filtré) : list_authz_role_bindings (cluster) refusé", Ou,
           "list_authz_role_bindings", {"scope": "cluster"}, "denied")
    st, msg = outcome(Ou.call("list_authz_actions", {}))
    rec("O11", st == "ok" and "entitlement" not in msg,
        "constat : list_authz_actions reste appelable (outil non scopé, catalogue statique d'actions, sans binding)",
        "list_authz_actions -> %s: %s" % (st, msg[:80]))

    # --- ClusterRoleBinding via Trait : deny explicite -------------------------------------------
    crb_trait = {"creates": [{"targetPlane": "dataplane", "template": {
        "apiVersion": "rbac.authorization.k8s.io/v1", "kind": "ClusterRoleBinding",
        "metadata": {"name": "lab-evil-${metadata.name}"},
        "roleRef": {"apiGroup": "rbac.authorization.k8s.io", "kind": "ClusterRole", "name": "cluster-admin"},
        "subjects": [{"kind": "ServiceAccount", "name": "default", "namespace": "${metadata.namespace}"}]}}]}
    trait_args = {"scope": "cluster", "name": "lab-evil-crb", "spec": crb_trait}
    patch_args = {"namespace_name": NS, "component_name": COMP,
                  "traits": [{"kind": "ClusterTrait", "name": "t-add-crb", "instanceName": "evil"}]}
    expect("T1", "operator : create_trait (ClusterTrait rendant une ClusterRoleBinding) refusé", Ou,
           "create_trait", trait_args, "denied")
    expect("T2", "operator : patch_component (attacher le trait CRB t-add-crb) refusé", Ou,
           "patch_component", patch_args, "denied")
    # Escalade simulée : un allow ajouté par erreur (clustertrait:create, component:update) ne doit
    # pas l'emporter sur le binding deny lab-agent-operator-deny.
    esc = """
apiVersion: openchoreo.dev/v1alpha1
kind: ClusterAuthzRole
metadata: {name: lab-escalation-test, labels: {platform.smadja.dev/owner: lab-authz}}
spec: {actions: ["clustertrait:create", "trait:create", "component:update"]}
---
apiVersion: openchoreo.dev/v1alpha1
kind: ClusterAuthzRoleBinding
metadata: {name: lab-escalation-test, labels: {platform.smadja.dev/owner: lab-authz}}
spec:
  entitlement: {claim: client_id, value: openchoreo-agent-operator}
  effect: allow
  roleMappings: [{roleRef: {kind: ClusterAuthzRole, name: lab-escalation-test}}]
"""
    kubectl("apply", "-f", "-", stdin=esc)
    time.sleep(6)
    ev = A.call("evaluate_authz", {"requests": [{
        "action": "clustertrait:create", "resource": {"type": "clustertrait"},
        "subject_context": {"type": "service_account", "entitlement_claim": "client_id",
                            "entitlement_values": ["openchoreo-agent-operator"]}}]})
    expect("T3", "operator + allow d'escalade : create_trait CRB toujours refusé (deny gagne)", Ou,
           "create_trait", trait_args, "denied")
    expect("T4", "operator + allow d'escalade : patch_component trait CRB toujours refusé (deny gagne)", Ou,
           "patch_component", patch_args, "denied")
    rec("T5", '"decision":false' in json.dumps(ev, separators=(",", ":")),
        "evaluate_authz confirme : clustertrait:create refusé malgré l'allow d'escalade",
        outcome(ev)[1])
    kubectl("delete", "-f", "-", "--ignore-not-found", stdin=esc)
    leaked = kubectl("get", "clustertrait", "lab-evil-crb", "--ignore-not-found", "-o", "name").stdout.strip()
    traits = (json.loads(kubectl("-n", NS, "get", "component", COMP, "-o", "json").stdout)["spec"].get("traits"))
    rec("T6", not leaked and not traits, "aucun ClusterTrait créé, aucun trait attaché",
        "clustertrait=%r traits=%r" % (leaked, traits))

    # --- Humains (groupes) : décision du PDP via evaluate_authz ------------------------------------
    def decide(group, action, rtype, hierarchy=None):
        req = {"action": action, "resource": {"type": rtype},
               "subject_context": {"type": "user", "entitlement_claim": "groups", "entitlement_values": [group]}}
        if hierarchy:
            req["resource"]["hierarchy"] = hierarchy
        r = A.call("evaluate_authz", {"requests": [req]})
        s = json.dumps(r.get("result", {}).get("structuredContent", r), separators=(",", ":"))
        return '"decision":true' in s, s[:160]

    h = {"namespace": NS, "project": PRJ}
    cases = [("H1", "openchoreo-viewers", "component:view", "component", True),
             ("H2", "openchoreo-viewers", "component:create", "component", False),
             ("H3", "openchoreo-viewers", "secretreference:view", "secretreference", False),
             ("H4", "openchoreo-developers", "component:create", "component", False),
             ("H4b", "openchoreo-developers", "releasebinding:update", "releasebinding", True),
             ("H4c", "openchoreo-developers", "resource:read-secrets", "resource", False),
             ("H4d", "openchoreo-developers", "component:exec", "component", False),
             ("H5", "openchoreo-developers", "clusterauthzrolebinding:create", "clusterauthzrolebinding", False),
             ("H6", "authentik-admins", "clusterauthzrolebinding:create", "clusterauthzrolebinding", True),
             ("H7", "groupe-inconnu", "component:view", "component", False)]
    for tid, g, act, rt_, want in cases:
        hier = h if not rt_.startswith("cluster") else None
        got, s = decide(g, act, rt_, hier)
        rec(tid, got == want, "PDP groupe %s : %s => %s" % (g, act, "allow" if want else "deny"), s)
    rec("H8", False, "connexion navigateur réelle (console/Backstage) par groupe", "login interactif non joué",
        status="NOT_TESTED")

    # --- Audit (sans observability plane) --------------------------------------------------------
    logs = kubectl("-n", "openchoreo-control-plane", "logs", "deploy/openchoreo-api", "--since=10m").stdout
    acc = [l for l in logs.splitlines() if "ACCESS-LOG" in l and '"path":"/mcp"' in l]
    rec("AU1", bool(acc), "journal openchoreo-api : ACCESS-LOG par requête MCP (méthode, chemin, IP, UA, statut)",
        "%d lignes /mcp ; ex. %s" % (len(acc), acc[-1][:160] if acc else ""))
    who = [l for l in logs.splitlines() if "openchoreo-agent-" in l]
    rec("AU2", not who, "constat : au niveau INFO, ni sujet (client_id) ni décision authz dans le journal "
        "(refus MCP = HTTP 200 JSON-RPC)", "%d lignes mentionnant un client agent" % len(who))
    mf = json.loads(kubectl("-n", NS, "get", "releasebinding", RB_DEV, "--show-managed-fields", "-o", "json").stdout)
    mgrs = sorted({m.get("manager") for m in mf["metadata"].get("managedFields", [])})
    rec("AU3", bool(mgrs), "trace minimale dans l'objet : managedFields (gestionnaire, horodatage) sans identité agent",
        "managers=%s" % mgrs)

    fails = [r for r in results if r[1] == "FAIL"]
    print("BILAN|PASS=%d FAIL=%d NOT_TESTED=%d" % (
        sum(r[1] == "PASS" for r in results), len(fails), sum(r[1] == "NOT_TESTED" for r in results)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
