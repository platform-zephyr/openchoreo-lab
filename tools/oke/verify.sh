#!/usr/bin/env bash
# verify.sh : critères de sortie de la Phase B, étape par étape (docs/PHASE-B.md §2). NON EXÉCUTÉ.
# Usage : tools/oke/verify.sh --step N   |   tools/oke/verify.sh --security   |   --all
# Lecture seule, sauf : `kubectl apply --dry-run=server` (rien n'est persisté) et, pour --security,
# un pod de sonde éphémère `lab-netprobe` dans openchoreo-control-plane (supprimé à la fin).
# Sortie : une ligne PASS / FAIL / BLOCKED par test, horodatée ; journal dans $STATE_DIR/verify.log.
# Code : 0 si aucun FAIL, 1 sinon. Un PASS ici est une preuve OKE datée (AGENTS.md) ; garder le journal.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MODE="${1:-}" ; N="${2:-}"
guard_context
mkdir -p "$STATE_DIR"
FAILS=0
res() { # STATUT ID MESSAGE
  local line; line="$(date -u +%FT%TZ) $1 $2 $3"
  printf '%s\n' "$line" | tee -a "$STATE_DIR/verify.log"
  [[ "$1" != FAIL ]] || FAILS=$((FAILS + 1))
}
expect_ok()   { local id="$1" msg="$2"; shift 2; if "$@" >/dev/null 2>&1; then res PASS "$id" "$msg"; else res FAIL "$id" "$msg"; fi; }
expect_deny() { # ID MSG MOTIF CMD... : la commande doit échouer avec le motif attendu
  local id="$1" msg="$2" pat="$3" out; shift 3
  if out="$("$@" 2>&1)"; then res FAIL "$id" "$msg (admis)"; elif grep -qiE "$pat" <<<"$out"; then res PASS "$id" "$msg"; else res FAIL "$id" "$msg (refus inattendu : ${out:0:160})"; fi
}
deploys_ok() { kubectl -n "$1" wait --for=condition=Available deployment --all --timeout=30s; }
psa_is() { [[ "$(kubectl get ns "$1" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" == "$2" ]]; }
no_lb() { [[ -z "$(kubectl get svc -A -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer" or .spec.type=="NodePort") | .metadata.namespace' | grep -E '^(openchoreo-|lab-|dp-|cnpg-system$)' || true)" ]]; }

bad_pod() { # NS : pod privilégié + hostNetwork (doit être refusé par PSA et la VAP kube-ops)
  kubectl -n "$1" apply --dry-run=server -f - <<EOF
apiVersion: v1
kind: Pod
metadata: {name: lab-bad-probe}
spec:
  hostNetwork: true
  containers:
    - name: c
      image: docker.io/curlimages/curl:8.17.0@sha256:935d9100e9ba842cdb060de42472c7ca90cfe9a7c96e4dacb55e79e560b3ff40
      securityContext: {privileged: true}
EOF
}

v1() {
  local ns
  for ns in openchoreo-control-plane openchoreo-cert-manager openchoreo-external-secrets lab-secrets lab-argocd cnpg-system; do
    expect_ok "B1-psa-$ns" "PSA enforce=restricted sur $ns" psa_is "$ns" restricted
  done
  expect_ok B1-psa-dp "PSA enforce=baseline sur openchoreo-data-plane (exception documentée)" psa_is openchoreo-data-plane baseline
  for ns in "${TRIAL_NS[@]}"; do
    [[ "$ns" == lab-pg ]] && continue
    expect_ok "B1-quota-$ns" "ResourceQuota lab-quota dans $ns" kubectl -n "$ns" get resourcequota lab-quota
    expect_ok "B1-deny-$ns" "NetworkPolicy lab-default-deny dans $ns" kubectl -n "$ns" get networkpolicy lab-default-deny
  done
  expect_deny B1-admission "pod privileged+hostNetwork refusé dans openchoreo-control-plane" \
    'forbidden|denied|violates PodSecurity' bad_pod openchoreo-control-plane
}

v2() {
  local c
  for c in gatewayclasses gateways httproutes referencegrants grpcroutes; do
    expect_ok "B2-$c" "CRD $c.gateway.networking.k8s.io Established" \
      kubectl wait --for=condition=Established --timeout=10s "crd/$c.gateway.networking.k8s.io"
  done
}

v3() {
  expect_ok B3-deploy "cert-manager : 3 Deployments Available" deploys_ok openchoreo-cert-manager
  expect_ok B3-noks "aucun objet cert-manager dans kube-system (leader election dans son namespace)" \
    bash -c "! kubectl -n kube-system get role,rolebinding,lease -o name | grep -q cert-manager"
  # Prouve le chemin réseau API server -> webhook :10250 (CNP lab-allow-webhook-from-apiserver) [S].
  expect_ok B3-webhook "webhook cert-manager joignable (dry-run serveur d'un Issuer)" bash -c \
    "printf 'apiVersion: cert-manager.io/v1\nkind: Issuer\nmetadata: {name: lab-probe, namespace: openchoreo-cert-manager}\nspec: {selfSigned: {}}\n' | kubectl apply --dry-run=server -f -"
}

v4() {
  expect_ok B4-deploy "ESO Available" deploys_ok openchoreo-external-secrets
  expect_ok B4-store "ClusterSecretStore lab-store Ready" kubectl wait --for=condition=Ready --timeout=30s clustersecretstore/lab-store
}

v5() {
  expect_ok B5-deploy "kgateway Available" kubectl -n openchoreo-control-plane wait --for=condition=Available --timeout=30s deployment/kgateway
  expect_ok B5-class "GatewayClass kgateway Accepted" kubectl wait --for=condition=Accepted --timeout=30s gatewayclass/kgateway
}

v6() {
  expect_ok B6-deploy "CP : controller-manager, openchoreo-api, cluster-gateway, kgateway Available" deploys_ok openchoreo-control-plane
  expect_ok B6-ca "ConfigMap cluster-gateway-ca peuplé (CA publique)" bash -c \
    "kubectl -n openchoreo-control-plane get cm cluster-gateway-ca -o jsonpath='{.data.ca\.crt}' | grep -q 'BEGIN CERTIFICATE'"
  expect_ok B6-webhook "webhook OpenChoreo joignable (dry-run serveur du CCT service-restricted)" \
    kubectl apply --dry-run=server -f "$ROOT/platform/component-types/service-restricted.yaml"
  expect_ok B6-nobackstage "Backstage et event-forwarder absents (profil minimal)" bash -c \
    "! kubectl -n openchoreo-control-plane get deploy -o name | grep -qE 'backstage|event-forwarder'"
  # API et MCP : santé 200, MCP sans jeton 401 (pas d'IdP en Phase B : échec fermé attendu).
  local pf; kubectl -n openchoreo-control-plane port-forward svc/openchoreo-api 18080:8080 >/dev/null 2>&1 & pf=$!
  sleep 3
  expect_ok B6-health "openchoreo-api /health = 200" bash -c "[[ \$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18080/health) == 200 ]]"
  expect_ok B6-mcp "MCP sans jeton refusé (401)" bash -c "[[ \$(curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:18080/mcp) == 401 ]]"
  kill "$pf" 2>/dev/null || true
}

v7() {
  expect_ok B7-deploy "DP : cluster-agent et Envoy gateway-default Available" deploys_ok openchoreo-data-plane
  expect_ok B7-gw "Gateway gateway-default Programmed" kubectl -n openchoreo-data-plane wait --for=condition=Programmed --timeout=30s gateway/gateway-default
  expect_ok B7-nolb "aucun Service LoadBalancer/NodePort dans les namespaces d'essai" no_lb
  expect_ok B7-vap "VAP lab-cluster-agent-scope et lab-cell-pod-hardening présentes" \
    kubectl get validatingadmissionpolicy lab-cluster-agent-scope lab-cell-pod-hardening
  local sa=system:serviceaccount:openchoreo-data-plane:cluster-agent-dataplane
  expect_ok B7-quota-rbac "cluster-agent peut patcher resourcequotas (ClusterRole additionnel)" \
    bash -c "[[ \$(kubectl auth can-i patch resourcequotas -n dp-probe --as=$sa) == yes ]]"
  expect_deny B7-vap1 "cluster-agent : ClusterRoleBinding refusée par VAP-1 (dry-run, impersonation)" 'lab-cluster-agent-scope' \
    bash -c "printf 'apiVersion: rbac.authorization.k8s.io/v1\nkind: ClusterRoleBinding\nmetadata: {name: lab-vap1-probe}\nroleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: view}\nsubjects: [{kind: User, name: nobody}]\n' | kubectl apply --dry-run=server --as=$sa -f -"
}

v8() {
  expect_ok B8-cdp "ClusterDataPlane default présent" kubectl get clusterdataplane default
  expect_ok B8-agent "agent connecté au cluster-gateway (condition Ready/Connected)" bash -c \
    "kubectl get clusterdataplane default -o json | jq -e '[.status.conditions[]? | select(.status==\"True\")] | length > 0'"
  kubectl -n openchoreo-data-plane logs deploy/cluster-agent-dataplane --tail=20 2>/dev/null | grep -iE 'connect|error' | tail -5 || true
}

v9() {
  expect_ok B9-types "CCT, CPT, CRT, ClusterTrait du labo présents" \
    kubectl get clustercomponenttype service-restricted clusterprojecttype cell-restricted \
      clusterresourcetype cnpg-lab-db clustertrait persistent-volume-claim clustertrait health-probes
  expect_ok B9-env "Environment production et DeploymentPipeline standard" \
    kubectl -n default get environment production deploymentpipeline standard
  expect_ok B9-default "namespace default : label openchoreo.dev/control-plane=true" bash -c \
    "[[ \$(kubectl get ns default -o jsonpath='{.metadata.labels.openchoreo\.dev/control-plane}') == true ]]"
}

v10() {
  expect_ok B10-pg "Cluster CNPG lab-pg Ready" kubectl -n lab-pg wait --for=condition=Ready --timeout=30s cluster.postgresql.cnpg.io/lab-pg
  expect_ok B10-pvc "PVC lab-pg Bound (block volume OCI)" bash -c \
    "kubectl -n lab-pg get pvc -o json | jq -e '[.items[] | select(.status.phase==\"Bound\")] | length == 1'"
  expect_ok B10-psa "lab-pg en PSA restricted" psa_is lab-pg restricted
}

v11() {
  expect_ok B11-argo "Argo CD Available" deploys_ok lab-argocd
  local a
  for a in lab-root lab-platform; do
    expect_ok "B11-$a" "Application $a Synced et Healthy" bash -c \
      "kubectl -n lab-argocd get application $a -o json | jq -e '.status.sync.status==\"Synced\" and .status.health.status==\"Healthy\"'"
  done
}

v12() {
  local sa=system:serviceaccount:openchoreo-data-plane:cluster-agent-dataplane
  expect_ok B12-norbac "RBAC réduit : l'agent ne peut plus créer de ClusterRoleBinding (RBAC, avant VAP)" \
    bash -c "[[ \$(kubectl auth can-i create clusterrolebindings --as=$sa) == no ]]"
  expect_ok B12-noexec "RBAC réduit : plus de pods/exec" bash -c "[[ \$(kubectl auth can-i create pods/exec -n dp-probe --as=$sa) == no ]]"
  expect_ok B12-quota "RBAC réduit : resourcequotas toujours permis" bash -c "[[ \$(kubectl auth can-i patch resourcequotas -n dp-probe --as=$sa) == yes ]]"
  res BLOCKED B12-render "rendu complet d'une app avec le RBAC réduit : à prouver avec whoami en Phase C"
}

# Sonde réseau : pod éphémère conforme (restricted, digest) dans openchoreo-control-plane.
security() {
  local ns=openchoreo-control-plane p=lab-netprobe
  kubectl -n "$ns" delete pod "$p" --ignore-not-found --wait=true >/dev/null
  kubectl -n "$ns" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata: {name: $p, labels: {app.kubernetes.io/part-of: openchoreo-lab}}
spec:
  automountServiceAccountToken: false
  restartPolicy: Never
  securityContext: {runAsNonRoot: true, runAsUser: 100, seccompProfile: {type: RuntimeDefault}}
  containers:
    - name: probe
      image: docker.io/curlimages/curl:8.17.0@sha256:935d9100e9ba842cdb060de42472c7ca90cfe9a7c96e4dacb55e79e560b3ff40
      command: ["sleep", "300"]
      resources: {requests: {cpu: 5m, memory: 16Mi}, limits: {cpu: 100m, memory: 32Mi}}
      securityContext: {allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: {drop: [ALL]}}
EOF
  kubectl -n "$ns" wait --for=condition=Ready --timeout=120s "pod/$p" >/dev/null
  pc() { kubectl -n "$ns" exec "$p" -- curl -s -o /dev/null -m 5 -w '%{http_code}' "$@" 2>/dev/null || true; }
  expect_ok S-dns "DNS résolu depuis un namespace d'essai" kubectl -n "$ns" exec "$p" -- nslookup kubernetes.default.svc.cluster.local
  local imds; imds="$(pc http://169.254.169.254/opc/v2/instance/)"
  if [[ "$imds" == 000 ]]; then res PASS S-imds "IMDS 169.254.169.254:80 injoignable (CCNP deny-imds)"; else res FAIL S-imds "IMDS joignable (HTTP $imds)"; fi
  local out; out="$(pc https://1.1.1.1/)"
  if [[ "$out" == 000 ]]; then
    res PASS S-egress "egress Internet refusé (default-deny egress effectif : C1 résolu)"
  else
    res BLOCKED S-egress "egress Internet OUVERT (HTTP $out) : C1, CCNP allow-egress-unisolated de kube-ops (docs/PHASE-B.md §6)"
  fi
  local cross; cross="$(pc -k https://cluster-gateway.openchoreo-control-plane.svc:8443/)"
  if [[ "$cross" != 000 ]]; then res PASS S-intra "trafic intra-namespace ouvert (cluster-gateway :8443)"; else res FAIL S-intra "intra-namespace bloqué"; fi
  kubectl -n "$ns" delete pod "$p" --wait=false >/dev/null
}

case "$MODE" in
  --step) declare -F "v$N" >/dev/null || die "étape inconnue : $N"; "v$N";;
  --security) security;;
  --all) for n in 1 2 3 4 5 6 7 8 9 10 11; do "v$n"; done; security;;
  *) die "usage : $0 --step N | --security | --all";;
esac
log "FAIL=$FAILS (journal : $STATE_DIR/verify.log)"
(( FAILS == 0 ))
