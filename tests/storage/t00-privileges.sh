#!/usr/bin/env bash
# =============================================================================================
# DANGER — N'EXÉCUTER QUE SUR UN CLUSTER JETABLE. Applique TEMPORAIREMENT la VAP
# baseline-pod-hardening (copie de tests/vap/fixtures/baseline-oke-export.json) sur le banc.
# =============================================================================================
# T-00 : privilèges réels du moteur ENGINE et effet de la VAP (Deny hostPath/privileged hors
# kube-system/cloudflared). Résultats :
#   T-00a inventaire des pods du moteur (privileged / hostPath / hostNetwork)  -> preuve
#   T-00b provisionnement sous la VAP telle qu'exportée d'OKE                   -> PASS si le
#         comportement observé correspond à la prédiction (refus si le moteur est hors exemption)
#   T-00c provisionnement avec l'exception nommée storage-system                -> PASS si Bound
source "$(dirname "$0")/lib.sh"
guard
ROOT="$(cd "$STORAGE_TEST_DIR/../.." && pwd)"
FIX="$ROOT/tests/vap/fixtures/baseline-oke-export.json"
ENS="$(engine_namespace)"

kubectl -n "$ENS" get pods -o json | jq -r '.items[] | .metadata.name as $n |
  [ $n,
    ((.spec.hostNetwork // false)|tostring),
    ([.spec.containers[]?, .spec.initContainers[]? | .securityContext.privileged // false] | any | tostring),
    ([.spec.volumes[]? | select(.hostPath) | .hostPath.path] | join(",")) ] | @tsv' \
  | tee >(evidence T-00a) | sed 's/^/  /'
record T-00a PASS "inventaire écrit dans evidence/T-00a.txt (nom, hostNetwork, privileged, hostPath)"

apply_vap() { # liste NotIn
  jq --argjson notin "$1" '.items |= map(select(.metadata.name=="baseline-pod-hardening")
     | if .kind=="ValidatingAdmissionPolicyBinding"
       then .spec.matchResources.namespaceSelector.matchExpressions[0].values = $notin else . end
     | del(.metadata.resourceVersion,.metadata.uid,.metadata.creationTimestamp,.metadata.generation,.metadata.managedFields,.status))' \
     "$FIX" | kubectl apply -f - >/dev/null
}
remove_vap() {
  kubectl delete validatingadmissionpolicybinding baseline-pod-hardening --ignore-not-found >/dev/null
  kubectl delete validatingadmissionpolicy baseline-pod-hardening --ignore-not-found >/dev/null
}
trap remove_vap EXIT

try_bind() { # id
  local ns; ns="$(new_ns t00)"
  make_pvc "$ns" p 1Gi
  set +e; make_pod "$ns" w p; local rc=$?; set -e
  local phase; phase="$(kubectl -n "$ns" get pvc p -o jsonpath='{.status.phase}')"
  { kubectl -n "$ns" describe pvc p; kubectl get events -A --field-selector reason=FailedCreate 2>/dev/null | tail -20; } | evidence "$1"
  drop_ns "$ns"
  [[ $rc -eq 0 && "$phase" == Bound ]]
}

# Le DaemonSet/Deployment déjà en place n'est pas réadmis : on force un redémarrage des pods
# du moteur pour qu'ils repassent par l'admission.
restart_engine() {
  if [[ "$ENS" == kube-system ]]; then kubectl -n kube-system delete pods -l app=local-path-provisioner --wait=true >/dev/null
  else kubectl -n "$ENS" delete pods --all --wait=true >/dev/null; fi
  sleep 20
}

apply_vap '["kube-system","cloudflared"]'; restart_engine
if try_bind T-00b; then
  if [[ "$ENS" == kube-system ]]; then record T-00b PASS "moteur en kube-system : exempté, provisionnement OK (prédit)"
  else record T-00b FAIL "provisionnement OK alors que la VAP devait refuser hostPath/privileged dans $ENS"; fi
else
  if [[ "$ENS" == kube-system ]]; then record T-00b FAIL "refus inattendu en kube-system"
  else record T-00b PASS "refus sous la VAP OKE hors exemption (prédit) : exception nommée nécessaire"; fi
fi

apply_vap "[\"kube-system\",\"cloudflared\",\"$ENS\"]"; restart_engine
if try_bind T-00c; then record T-00c PASS "provisionnement OK avec l'exception nommée $ENS"
else record T-00c FAIL "échec même avec l'exception $ENS (voir evidence/T-00c.txt)"; fi
finish
