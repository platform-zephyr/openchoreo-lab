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
FAILS=0 BLOCKS=0
res() { # STATUT ID MESSAGE   (PASS | FAIL | BLOCKED)
  local line; line="$(date -u +%FT%TZ) $1 $2 $3"
  printf '%s\n' "$line" | tee -a "$STATE_DIR/verify.log"
  [[ "$1" != FAIL ]] || FAILS=$((FAILS + 1))
  [[ "$1" != BLOCKED ]] || BLOCKS=$((BLOCKS + 1))
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

# --- Tests réseau (security) ---------------------------------------------------------------------------
# Un refus d'egress ne se prouve PAS par « curl https://1.1.1.1 échoue » : une erreur TLS, un DNS en panne ou un
# timeout ordinaire donneraient le même échec. On classe donc chaque sonde (code de sortie de curl) :
#   0 / http_code != 000 : egress OUVERT (réponse HTTP)           7 : TCP refusé (RST)
#   35,51,58,59,60,77,83 : erreur TLS = la connexion TCP A ÉTÉ ÉTABLIE (egress OUVERT, pas un refus)
#   6 : erreur DNS (ne dit rien de l'egress ; on sonde une IP)    28 : timeout TCP (compatible drop Cilium)
# « Refus Cilium » n'est déclaré que si : sonde en namespace ISOLÉ = timeout TCP, ET témoin positif dans un
# namespace NON isolé (lab-netcontrol) = connexion établie, DNS OK dans les deux. Sans témoin : BLOCKED.
classify() { # RC -> libellé
  case "$1" in
    0) echo "OPEN-HTTP";; 7) echo "TCP-REFUSED";; 28) echo "TCP-TIMEOUT";; 6) echo "DNS-ERROR";;
    35|51|58|59|60|77|83) echo "TLS-ERROR(TCP établi)";; *) echo "OTHER(rc=$1)";;
  esac
}
probe_pod() { # NS NOM LABELS_EXTRA
  local ns="$1" p="$2"
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
  kubectl -n "$ns" wait --for=condition=Ready --timeout=180s "pod/$p" >/dev/null
}
probe_rc() { # NS POD URL [curl args] -> echo "RC"
  local ns="$1" p="$2"; shift 2
  local rc=0
  kubectl -n "$ns" exec "$p" -- curl -sS -o /dev/null --connect-timeout 5 -m 8 "$@" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}
# Nettoyage garanti (trap EXIT/INT/TERM) : supprime les sondes, supprime le namespace témoin en ATTENDANT sa
# disparition et vérifie qu'il n'existe plus ; sinon FAIL « nettoyage » (ressource de test résiduelle).
SEC_NS=openchoreo-control-plane SEC_POD=lab-netprobe SEC_CNS=lab-netcontrol
security_cleanup() {
  trap - EXIT INT TERM
  kubectl -n "$SEC_NS" delete pod "$SEC_POD" --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 || true
  kubectl delete namespace "$SEC_CNS" --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1 || true
  if kubectl get namespace "$SEC_CNS" >/dev/null 2>&1; then
    res FAIL S-cleanup "namespace témoin $SEC_CNS encore présent après suppression"
  elif kubectl -n "$SEC_NS" get pod "$SEC_POD" >/dev/null 2>&1; then
    res FAIL S-cleanup "pod de sonde $SEC_POD encore présent"
  else
    res PASS S-cleanup "sondes et namespace témoin $SEC_CNS supprimés et absents (vérifié)"
  fi
}
security() {
  local ns=$SEC_NS p=$SEC_POD cns=$SEC_CNS
  trap security_cleanup EXIT INT TERM
  probe_pod "$ns" "$p"
  # Namespace témoin NON isolé (sans platform.smadja.dev/egress-isolated) : supprimé à la fin.
  kubectl create namespace "$cns" --dry-run=client -o yaml | kubectl label --local -f - -o yaml \
    pod-security.kubernetes.io/enforce=restricted app.kubernetes.io/part-of=openchoreo-lab | kubectl apply -f - >/dev/null
  probe_pod "$cns" "$p"
  expect_ok S-dns "DNS résolu depuis le namespace d'essai isolé" kubectl -n "$ns" exec "$p" -- nslookup kubernetes.default.svc.cluster.local
  expect_ok S-dns-control "DNS résolu depuis le namespace témoin" kubectl -n "$cns" exec "$p" -- nslookup kubernetes.default.svc.cluster.local
  # IMDS : TCP 80 doit être en timeout alors que le DNS (53) du même hôte répond (refus par port, pas panne d'hôte).
  local imds dns53
  imds="$(classify "$(probe_rc "$ns" "$p" http://169.254.169.254/opc/v2/instance/)")"
  if kubectl -n "$ns" exec "$p" -- nslookup example.com 169.254.169.254 >/dev/null 2>&1; then dns53=ok; else dns53=ko; fi
  if [[ "$imds" == TCP-TIMEOUT && "$dns53" == ok ]]; then res PASS S-imds "IMDS :80 TCP-TIMEOUT alors que 169.254.169.254:53 répond (CCNP deny-imds)"
  elif [[ "$imds" == TCP-TIMEOUT ]]; then res BLOCKED S-imds "IMDS :80 TCP-TIMEOUT mais pas de témoin sur :53 : refus non distinguable d'une panne"
  else res FAIL S-imds "IMDS :80 classé $imds (attendu TCP-TIMEOUT)"; fi
  # Egress Internet : sonde sur une IP, TLS ignoré (-k) pour ne classer que le TCP.
  local test_c ctrl_c
  test_c="$(classify "$(probe_rc "$ns" "$p" -k https://1.1.1.1/)")"
  ctrl_c="$(classify "$(probe_rc "$cns" "$p" -k https://1.1.1.1/)")"
  if [[ "$test_c" == TCP-TIMEOUT && ( "$ctrl_c" == OPEN-HTTP || "$ctrl_c" == TLS-ERROR* ) ]]; then
    res PASS S-egress "namespace isolé : $test_c ; témoin non isolé : $ctrl_c => refus par la politique réseau (default-deny effectif)"
  elif [[ "$test_c" == OPEN-HTTP || "$test_c" == TLS-ERROR* ]]; then
    res BLOCKED S-egress "egress OUVERT depuis le namespace isolé ($test_c) : C1, CCNP allow-egress-unisolated de kube-ops (docs/PHASE-B.md §6). Default-deny NON fonctionnel."
  else
    res BLOCKED S-egress "sonde isolée $test_c, témoin $ctrl_c : refus Cilium non prouvé (pas de témoin positif)"
  fi
  # Intra-namespace : un service ClusterIP existant du namespace (kgateway avant l'étape 6, cluster-gateway après).
  local svc svcport cross_rc
  read -r svc svcport < <(kubectl -n "$ns" get svc -o jsonpath='{range .items[?(@.spec.clusterIP!="None")]}{.metadata.name}{" "}{.spec.ports[0].port}{"\n"}{end}' | head -1)
  if [[ -z "${svc:-}" ]]; then
    res BLOCKED S-intra "aucun Service dans $ns : trafic intra-namespace non testable à ce stade"
  else
    cross_rc="$(probe_rc "$ns" "$p" -k "https://$svc.$ns.svc:$svcport/")"
    case "$cross_rc" in
      0|35|51|52|56|58|59|60|77|83) res PASS S-intra "trafic intra-namespace : connexion TCP établie vers $svc:$svcport (curl rc=$cross_rc)";;
      *) res FAIL S-intra "intra-namespace vers $svc:$svcport : $(classify "$cross_rc")";;
    esac
  fi
  security_cleanup
}

case "$MODE" in
  --step) declare -F "v$N" >/dev/null || die "étape inconnue : $N"; "v$N";;
  --security) security;;
  --all) for n in 1 2 3 4 5 6 7 8 9 10 11; do "v$n"; done; security;;
  *) die "usage : $0 --step N | --security | --all";;
esac
log "FAIL=$FAILS BLOCKED=$BLOCKS (journal : $STATE_DIR/verify.log)"
(( BLOCKS == 0 )) || log "JALON NON VALIDABLE : au moins un contrôle de sécurité est BLOCKED (voir le journal)."
(( FAILS == 0 )) || exit 1
(( BLOCKS == 0 )) || exit 2
