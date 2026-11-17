#!/usr/bin/env bash
# Banc authz + MCP — k3d UNIQUEMENT (jamais OKE).
# Applique platform/authz/ et la cible jetable tests/mcp/fixtures/, crée des clients OAuth2 de test
# sur le ThunderID du k3d (secrets aléatoires, hors dépôt), exécute la matrice allow/deny
# (tests/mcp/matrix.py) et écrit la preuve dans tests/mcp/evidence/k3d-<horodatage>.txt.
#
# Usage : tests/mcp/run.sh             # installe, teste, puis nettoie (défaut)
#         tests/mcp/run.sh --keep      # installe et teste, sans nettoyer
#         tests/mcp/run.sh --cleanup   # nettoie seulement
# Variables : KUBECONFIG (défaut : kubeconfig du k3d du labo), EXPECTED_CONTEXT (k3d-openchoreo),
#             MCP_TEST_STATE (fichier 0600 des secrets de test, défaut $TMPDIR/lab-mcp-clients.json).
# Outils : kubectl, python3 (bibliothèque standard seulement).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$ROOT/tests/mcp"
export KUBECONFIG="${KUBECONFIG:-/private/tmp/claude-501/-Users-paul-Desktop-perso/775067df-86e8-413f-97d7-8573a60947a2/scratchpad/openchoreo/kubeconfig}"
EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-k3d-openchoreo}"
export MCP_TEST_STATE="${MCP_TEST_STATE:-${TMPDIR:-/tmp}/lab-mcp-clients.json}"
MODE="${1:-run}"

ctx="$(kubectl config current-context)"
if [ "$ctx" != "$EXPECTED_CONTEXT" ]; then
  echo "BLOCKED : contexte '$ctx' au lieu de '$EXPECTED_CONTEXT' (ce banc ne tourne que sur k3d)" >&2
  exit 2
fi

cleanup() {
  echo "== nettoyage"
  kubectl delete clusterauthzrolebinding,clusterauthzrole lab-escalation-test --ignore-not-found >/dev/null
  kubectl delete clustertrait lab-evil-crb --ignore-not-found >/dev/null
  kubectl delete -f "$HERE/fixtures/" --ignore-not-found --wait=true >/dev/null || true
  kubectl delete -f "$ROOT/platform/authz/" --ignore-not-found >/dev/null
  (cd "$HERE" && python3 thunder.py delete) || true
  echo "objets lab-* restants :"
  kubectl get clusterauthzroles,clusterauthzrolebindings -o name | grep '/lab-' || echo "  aucun"
  kubectl get ns lab-mcp -o name 2>/dev/null || echo "  namespace lab-mcp supprimé"
}

if [ "$MODE" = "--cleanup" ]; then cleanup; exit 0; fi

echo "== préflight : l'API valide-t-elle les jetons ThunderID ? (JWKS joignable depuis openchoreo-api)"
if kubectl -n openchoreo-control-plane logs deploy/openchoreo-api --since=2m 2>/dev/null \
    | grep -q 'Failed to refresh JWKS cache'; then
  echo "BLOCKED : openchoreo-api ne résout pas thunder.openchoreo.localhost (JWKS)." >&2
  echo "  Cause connue k3d : après redémarrage, k3s réécrit la ConfigMap coredns et perd" >&2
  echo "  'host.k3d.internal' dans NodeHosts (cible du rewrite coredns-custom). Voir RESULTS.md." >&2
  exit 3
fi

echo "== application de platform/authz/ et de la cible lab-mcp"
kubectl apply --dry-run=server -f "$ROOT/platform/authz/" >/dev/null
kubectl apply -f "$ROOT/platform/authz/" -f "$HERE/fixtures/"
echo "== clients de test ThunderID (k3d)"
(cd "$HERE" && python3 thunder.py create)
sleep 5  # propagation des CRD authz vers l'enforcer (watcher)

mkdir -p "$HERE/evidence"
EVF="$HERE/evidence/k3d-$(date -u +%Y%m%dT%H%M%SZ).txt"
{
  echo "# Matrice authz/MCP — k3d ($EXPECTED_CONTEXT), $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# OpenChoreo $(kubectl -n openchoreo-control-plane get deploy openchoreo-api -o jsonpath='{.spec.template.spec.containers[0].image}' | sed 's/.*://')"
} >"$EVF"
rc=0
(cd "$HERE" && python3 matrix.py) | tee -a "$EVF" || rc=$?
echo "preuve : ${EVF#"$ROOT"/}"

if [ "$MODE" != "--keep" ]; then cleanup; fi
exit "$rc"
