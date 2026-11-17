#!/usr/bin/env bash
# verify.sh : critères de sortie de la Phase B, étape par étape (docs/PHASE-B.md §2). Étapes 1-5 et
# --security exécutées sur OKE le 2026-11-17 (journal $STATE_DIR/verify.log) ; 6 et suivantes NON exécutées.
# Usage : tools/oke/verify.sh --step N (N = 1..12 ou 6b)   |   tools/oke/verify.sh --security   |   --all
# Lecture seule, sauf : `kubectl apply --dry-run=server` (rien n'est persisté) et, pour --security,
# un pod de sonde éphémère `lab-netprobe` dans openchoreo-control-plane (supprimé à la fin).
# Sortie : une ligne PASS / FAIL / BLOCKED par test, horodatée ; journal dans $STATE_DIR/verify.log.
# Code : 0 si tout PASS ; 1 si au moins un FAIL ; 3 si BLOCKED sans FAIL (jalon non validable) ; 2 = garde
# de contexte ou abandon (die). Un PASS ici est une preuve OKE datée (AGENTS.md) ; garder le journal.
# Aucune panne kubectl n'est masquée : une lecture en erreur donne FAIL, jamais PASS (revue I11, m1).
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
no_lb() { # échoue si kubectl échoue (pas de liste vide silencieuse)
  local svc; svc="$(kubectl get svc -A -o json)" || return 1
  [[ "$(jq '[.items[] | select(.spec.type=="LoadBalancer" or .spec.type=="NodePort")
            | select(.metadata.namespace | test("^(openchoreo-|lab-|dp-)"))] | length' <<<"$svc")" == 0 ]]
}
# none_match NS MOTIF TYPE : aucun objet TYPE de NS ne correspond au motif ; kubectl en erreur => échec.
none_match() {
  local out; out="$(kubectl -n "$1" get "$3" -o name)" || return 1
  ! grep -qE "$2" <<<"$out"
}
# ns_absent NS : vrai seulement si l'API répond et que le namespace n'existe pas.
ns_absent() { local out; out="$(kubectl get namespace "$1" --ignore-not-found -o name)" || return 1; [[ -z "$out" ]]; }
ns_partof() { kubectl get namespace "$1" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}'; }

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

restricted_pod_nodigest() { # NS : pod conforme PSA restricted mais image SANS digest (VAP baseline-image-digest)
  kubectl -n "$1" apply --dry-run=server -f - <<EOF
apiVersion: v1
kind: Pod
metadata: {name: lab-nodigest-probe}
spec:
  automountServiceAccountToken: false
  securityContext: {runAsNonRoot: true, runAsUser: 100, seccompProfile: {type: RuntimeDefault}}
  containers:
    - name: c
      image: docker.io/curlimages/curl:8.17.0
      resources: {requests: {cpu: 5m, memory: 16Mi}, limits: {cpu: 50m, memory: 32Mi}}
      securityContext: {allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: {drop: [ALL]}}
EOF
}

v1() {
  local ns
  for ns in openchoreo-control-plane openchoreo-cert-manager openchoreo-external-secrets lab-secrets lab-argocd lab-cnpg; do
    expect_ok "B1-psa-$ns" "PSA enforce=restricted sur $ns" psa_is "$ns" restricted
  done
  expect_ok B1-psa-dp "PSA enforce=baseline sur openchoreo-data-plane (exception documentée)" psa_is openchoreo-data-plane baseline
  for ns in "${TRIAL_NS[@]}"; do
    [[ "$ns" == lab-pg ]] && continue
    expect_ok "B1-quota-$ns" "ResourceQuota lab-quota dans $ns" kubectl -n "$ns" get resourcequota lab-quota
    expect_ok "B1-deny-$ns" "NetworkPolicy lab-default-deny dans $ns" kubectl -n "$ns" get networkpolicy lab-default-deny
  done
  # Motif PSA exact : un refus de quota (« exceeded quota … forbidden ») ne passe plus pour un refus PSA.
  expect_deny B1-admission "pod privileged+hostNetwork refusé par PSA restricted dans openchoreo-control-plane" \
    'violates PodSecurity "restricted' bad_pod openchoreo-control-plane
  expect_deny B1-vap-digest "image sans digest refusée par la VAP kube-ops baseline-image-digest (pod PSA-conforme)" \
    'baseline-image-digest' restricted_pod_nodigest openchoreo-control-plane
  # Migration B3 : l'ancien namespace vide cnpg-system (étape 1 du 2026-11-17) doit avoir disparu.
  local part
  if ns_absent "$LEGACY_CNPG_NS"; then
    res PASS B1-legacy-cnpg "namespace $LEGACY_CNPG_NS absent (migration lab-cnpg faite)"
  elif ! part="$(ns_partof "$LEGACY_CNPG_NS")"; then
    res FAIL B1-legacy-cnpg "namespace $LEGACY_CNPG_NS illisible"
  elif [[ "$part" == openchoreo-lab ]]; then
    res FAIL B1-legacy-cnpg "namespace $LEGACY_CNPG_NS de l'essai encore présent : tools/oke/uninstall.sh --migrate-cnpg-system --apply"
  else
    res PASS B1-legacy-cnpg "namespace $LEGACY_CNPG_NS présent SANS label de l'essai : hors périmètre, non touché"
  fi
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
    none_match kube-system cert-manager role,rolebinding,lease
  # Prouve le chemin réseau API server -> webhook :10250 (CNP lab-allow-webhook-from-apiserver) [S].
  expect_ok B3-webhook "webhook cert-manager joignable (dry-run serveur d'un Issuer)" bash -c \
    "printf 'apiVersion: cert-manager.io/v1\nkind: Issuer\nmetadata: {name: lab-probe, namespace: openchoreo-cert-manager}\nspec: {selfSigned: {}}\n' | kubectl apply --dry-run=server -f -"
}

crds_keep() { # GROUPE : toutes les CRD du groupe portent helm.sh/resource-policy=keep (revue I1)
  local j; j="$(kubectl get crd -o json)" || return 1
  jq -e --arg g "$1" '[.items[] | select(.spec.group == $g)] as $c | ($c | length) > 0
    and ([$c[] | select(.metadata.annotations["helm.sh/resource-policy"] != "keep")] | length) == 0' <<<"$j" >/dev/null
}
v4() {
  expect_ok B4-deploy "ESO Available" deploys_ok openchoreo-external-secrets
  expect_ok B4-store "ClusterSecretStore lab-store Ready" kubectl wait --for=condition=Ready --timeout=30s clustersecretstore/lab-store
  expect_ok B4-crd-keep "CRD external-secrets.io annotées helm.sh/resource-policy=keep (install.sh --step 4 rejoué)" \
    crds_keep external-secrets.io
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
  expect_ok B6-noevents "event-forwarder absent (profil minimal ; Backstage : étape 6b)" \
    none_match openchoreo-control-plane event-forwarder deploy
  expect_ok B6-netpol "CNP d'egress vers Authentik présentes (03-idp-egress.yaml)" \
    kubectl -n openchoreo-control-plane get ciliumnetworkpolicy lab-allow-openchoreo-api-authentik lab-allow-backstage-authentik
  expect_ok B6-no-tryout "ni mcp-tryout-client-binding ni liaisons ThunderID (bootstrap.mappings remplacé)" bash -c \
    "out=\$(kubectl get clusterauthzrolebindings.openchoreo.dev -o name) && ! grep -qE 'mcp-tryout|platform-engineer-binding|sre-binding' <<<\"\$out\""
  # API et MCP : santé 200, MCP sans jeton 401 (pas d'IdP en Phase B : échec fermé attendu).
  local pf; kubectl -n openchoreo-control-plane port-forward svc/openchoreo-api 18080:8080 >/dev/null 2>&1 & pf=$!
  sleep 3
  expect_ok B6-health "openchoreo-api /health = 200" bash -c "[[ \$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:18080/health) == 200 ]]"
  expect_ok B6-mcp "MCP sans jeton refusé (401)" bash -c "[[ \$(curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:18080/mcp) == 401 ]]"
  kill "$pf" 2>/dev/null || true
}

# 6b : portail Backstage (docs/PORTAL.md §4 et §6). Critère d'arrêt : un FAIL ici => uninstall.sh --step 6b.
backstage_pods_ok() {
  local j; j="$(kubectl -n openchoreo-control-plane get pods -l app.kubernetes.io/component=backstage -o json)" || return 1
  jq -e '(.items | length) == 1 and ([.items[].status.containerStatuses[]?
    | select(.restartCount > 0 or .lastState.terminated.reason == "OOMKilled")] | length) == 0' <<<"$j" >/dev/null
}
backstage_psa_ok() {
  local j; j="$(kubectl -n openchoreo-control-plane get deploy backstage -o json)" || return 1
  jq -e '.spec.template.spec as $s | $s.securityContext.runAsNonRoot == true
    and $s.securityContext.seccompProfile.type == "RuntimeDefault"
    and ([$s.containers[] | select((.securityContext.appArmorProfile.type // "") == "Unconfined")] | length) == 0
    and ([$s.volumes[]? | select(.persistentVolumeClaim)] | length) == 0' <<<"$j" >/dev/null
}
no_exposure() { # P6 : aucun HTTPRoute ni Ingress backstage, Service ClusterIP, aucun PVC dans le namespace
  local r i t p
  r="$(kubectl -n openchoreo-control-plane get httproutes.gateway.networking.k8s.io -o name)" || return 1
  i="$(kubectl -n openchoreo-control-plane get ingress -o name)" || return 1
  t="$(kubectl -n openchoreo-control-plane get svc backstage -o jsonpath='{.spec.type}')" || return 1
  p="$(kubectl -n openchoreo-control-plane get pvc -o name)" || return 1
  ! grep -q backstage <<<"$r$i" && [[ "$t" == ClusterIP && -z "$p" ]]
}
v6b() {
  local ns=openchoreo-control-plane loc
  expect_ok B6b-deploy "Deployment backstage Available" kubectl -n "$ns" wait --for=condition=Available --timeout=60s deployment/backstage
  expect_ok B6b-restarts "backstage : 1 pod, 0 redémarrage, aucun OOMKilled" backstage_pods_ok
  expect_ok B6b-psa "backstage : runAsNonRoot, seccomp RuntimeDefault, sans AppArmor Unconfined, sans PVC" backstage_psa_ok
  expect_ok B6b-noexpose "P6 : ni HTTPRoute ni Ingress backstage, Service ClusterIP, aucun PVC" no_exposure
  # P2 : redirection vers Authentik. Seul l'en-tête Location est lu (aucun secret dans la sortie).
  local pf; kubectl -n "$ns" port-forward svc/backstage 17007:7007 >/dev/null 2>&1 & pf=$!
  sleep 3
  loc="$(curl -s -o /dev/null -D - 'http://127.0.0.1:17007/api/auth/openchoreo-auth/start?env=development' | grep -i '^location:' || true)"
  kill "$pf" 2>/dev/null || true
  if [[ "$loc" =~ https://auth\.smadja\.dev/application/o/authorize/.*client_id=openchoreo-backstage-client ]]; then
    res PASS B6b-login "P2 : /api/auth/openchoreo-auth/start redirige vers Authentik (client openchoreo-backstage-client)"
  else
    res FAIL B6b-login "P2 : pas de redirection Authentik attendue (Location='${loc:0:120}')"
  fi
  res BLOCKED B6b-p3p5 "P3 (session), P4 (catalogue), P5 (refus sans groupe) : navigateur et clients Authentik requis (docs/PORTAL.md §6)"
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
  # Revue B1 : CONNECT pods/exec hors dp-* refusé par VAP-1 (le RBAC du chart l'autorise). La VAP refuse
  # AVANT toute exécution ; si elle laissait passer, `true` n'existe pas dans l'image distroless (refus
  # inattendu => FAIL, jamais PASS).
  local pods
  if pods="$(kubectl -n openchoreo-control-plane get pod -l app.kubernetes.io/component=controller-manager -o name)" && [[ -n "$pods" ]]; then
    expect_deny B7-exec "cluster-agent : kubectl exec dans openchoreo-control-plane refusé par VAP-1 (CONNECT pods/exec)" \
      'lab-cluster-agent-scope' kubectl -n openchoreo-control-plane exec "${pods%%$'\n'*}" --as="$sa" -- true
  else
    res FAIL B7-exec "aucun pod controller-manager lisible pour la sonde d'exec"
  fi
  # Revue I6 : verrou PSA des cellules. Témoin positif (dp-* conforme admis) puis refus (privileged).
  expect_ok B7-psa-ok "cluster-agent : Namespace dp-* restricted admis (témoin, dry-run)" cell_ns_as_agent restricted
  expect_deny B7-psa-lock "cluster-agent : Namespace dp-* en PSA privileged refusé par VAP-1 (dry-run)" \
    'lab-cluster-agent-scope' cell_ns_as_agent privileged
}
cell_ns_as_agent() { # NIVEAU_PSA : dry-run serveur d'un Namespace dp-vap1-probe créé en tant que cluster-agent
  kubectl apply --dry-run=server --as=system:serviceaccount:openchoreo-data-plane:cluster-agent-dataplane -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: dp-vap1-probe
  labels:
    pod-security.kubernetes.io/enforce: $1
    pod-security.kubernetes.io/enforce-version: latest
    platform.smadja.dev/cell: restricted
EOF
}

# Connexion RÉELLE (revue I8) : champ status.agentConnection du CRD ClusterDataPlane 1.3.3
# (connected, connectedAgents, lastHeartbeatTime), pas « n'importe quelle condition True ».
agent_connected() {
  local j; j="$(kubectl get clusterdataplane default -o json)" || return 1
  jq -e '.status.agentConnection as $a | $a.connected == true and ($a.connectedAgents // 0) >= 1
    and (($a.lastHeartbeatTime // "") | length) > 0
    and (now - ($a.lastHeartbeatTime | sub("\\.[0-9]+"; "") | fromdateiso8601)) < 300' <<<"$j" >/dev/null
}
v8() {
  expect_ok B8-cdp "ClusterDataPlane default présent" kubectl get clusterdataplane default
  expect_ok B8-agent "agent connecté : agentConnection.connected=true, connectedAgents>=1, heartbeat < 5 min" agent_connected
  local logs
  if logs="$(kubectl -n openchoreo-data-plane logs deploy/cluster-agent-dataplane --tail=200)"; then
    if grep -qiE 'lab-cluster-agent-scope|x509|tls: ' <<<"$logs"; then
      res FAIL B8-logs "journal de l'agent : refus VAP-1 ou erreur TLS (kubectl logs deploy/cluster-agent-dataplane)"
    else
      res PASS B8-logs "journal de l'agent (200 lignes) sans refus VAP-1 ni erreur TLS"
    fi
  else
    res FAIL B8-logs "journal de l'agent illisible"
  fi
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
  expect_ok B10-cnpg "opérateur CNPG Available dans lab-cnpg" deploys_ok lab-cnpg
}

v11() {
  expect_ok B11-argo "Argo CD Available" deploys_ok lab-argocd
  expect_ok B11-projects "AppProject lab, lab-authz et lab-root présents" \
    kubectl -n lab-argocd get appprojects.argoproj.io lab lab-authz lab-root
  # Revue PR #8, P1 : `default` verrouillé (aucun dépôt, aucune destination, aucune whitelist, blacklist totale).
  expect_ok B11-default-locked "AppProject default verrouillé (0 dépôt, 0 destination, 0 whitelist)" bash -c \
    "kubectl -n lab-argocd get appproject default -o json | jq -e '.spec as \$s
      | ((\$s.sourceRepos // []) | length == 0) and ((\$s.destinations // []) | length == 0)
      and ((\$s.sourceNamespaces // []) | length == 0)
      and ((\$s.clusterResourceWhitelist // []) | length == 0) and ((\$s.namespaceResourceWhitelist // []) | length == 0)
      and ((\$s.namespaceResourceBlacklist // []) | any(.group == \"*\" and .kind == \"*\"))'"
  expect_ok B11-root-project "Application lab-root dans le projet lab-root" bash -c \
    "[[ \$(kubectl -n lab-argocd get application lab-root -o jsonpath='{.spec.project}') == lab-root ]]"
  expect_ok B11-no-default-app "aucune Application du projet default" bash -c \
    "kubectl -n lab-argocd get applications.argoproj.io -o json | jq -e '[.items[] | select(.spec.project == \"default\")] | length == 0'"
  expect_ok B11-authz-manual "Application lab-authz sans synchro automatique" bash -c \
    "kubectl -n lab-argocd get application lab-authz -o json | jq -e '.spec.syncPolicy.automated == null'"
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
SEC_CREATED_CNS=0
security_cleanup() {
  trap - EXIT INT TERM
  local pod_left ns_left
  # Les suppressions peuvent échouer (déjà absent) ; l'absence est ENSUITE vérifiée, et une lecture en
  # erreur donne FAIL (jamais « absent » par défaut). Le namespace témoin n'est supprimé que s'il a été créé ici.
  kubectl -n "$SEC_NS" delete pod "$SEC_POD" --ignore-not-found --wait=true --timeout=60s >/dev/null 2>&1 \
    || log "suppression de $SEC_POD en erreur (vérifiée ci-dessous)"
  if [[ "$SEC_CREATED_CNS" == 1 ]]; then
    kubectl delete namespace "$SEC_CNS" --ignore-not-found --wait=true --timeout=120s >/dev/null 2>&1 \
      || log "suppression de $SEC_CNS en erreur (vérifiée ci-dessous)"
  fi
  if ! ns_left="$(kubectl get namespace "$SEC_CNS" --ignore-not-found -o name)" \
     || ! pod_left="$(kubectl -n "$SEC_NS" get pod "$SEC_POD" --ignore-not-found -o name)"; then
    res FAIL S-cleanup "état des sondes illisible (API en erreur) : vérifier à la main $SEC_NS/$SEC_POD et $SEC_CNS"
  elif [[ -n "$ns_left" && "$SEC_CREATED_CNS" == 1 ]]; then
    res FAIL S-cleanup "namespace témoin $SEC_CNS encore présent après suppression"
  elif [[ -n "$pod_left" ]]; then
    res FAIL S-cleanup "pod de sonde $SEC_POD encore présent"
  else
    res PASS S-cleanup "sondes et namespace témoin $SEC_CNS supprimés et absents (vérifié)"
  fi
}
security() {
  local ns=$SEC_NS p=$SEC_POD cns=$SEC_CNS
  # Garde I3/m3 : jamais de réutilisation d'un namespace témoin préexistant (il ne serait pas à nous).
  ns_absent "$cns" || die "namespace $cns déjà présent ou API en erreur : témoin non créé, rien supprimé"
  trap security_cleanup EXIT INT TERM
  probe_pod "$ns" "$p"
  # Namespace témoin NON isolé (sans platform.smadja.dev/egress-isolated) : supprimé à la fin.
  kubectl create namespace "$cns" --dry-run=client -o yaml | kubectl label --local -f - -o yaml \
    pod-security.kubernetes.io/enforce=restricted app.kubernetes.io/part-of=openchoreo-lab | kubectl create -f - >/dev/null
  SEC_CREATED_CNS=1
  probe_pod "$cns" "$p"
  expect_ok S-dns "DNS résolu depuis le namespace d'essai isolé" kubectl -n "$ns" exec "$p" -- nslookup kubernetes.default.svc.cluster.local
  expect_ok S-dns-control "DNS résolu depuis le namespace témoin" kubectl -n "$cns" exec "$p" -- nslookup kubernetes.default.svc.cluster.local
  # IMDS (revue m2) : sondé depuis le namespace témoin NON isolé, où seule la CCNP deny-imds agit, avec le
  # témoin :53 du même hôte depuis le même pod (refus par port, pas panne d'hôte) : reste valable après C1.
  # Depuis le namespace isolé, :80 ne doit en aucun cas répondre (FAIL si ouvert).
  local imds imds_iso dns53
  imds="$(classify "$(probe_rc "$cns" "$p" http://169.254.169.254/opc/v2/instance/)")"
  imds_iso="$(classify "$(probe_rc "$ns" "$p" http://169.254.169.254/opc/v2/instance/)")"
  if kubectl -n "$cns" exec "$p" -- nslookup example.com 169.254.169.254 >/dev/null 2>&1; then dns53=ok; else dns53=ko; fi
  if [[ "$imds_iso" == OPEN-HTTP || "$imds_iso" == TLS-ERROR* ]]; then res FAIL S-imds "IMDS :80 JOIGNABLE depuis le namespace isolé ($imds_iso)"
  elif [[ "$imds" == TCP-TIMEOUT && "$dns53" == ok ]]; then res PASS S-imds "IMDS :80 TCP-TIMEOUT (témoin non isolé ; isolé : $imds_iso) alors que 169.254.169.254:53 répond (CCNP deny-imds)"
  elif [[ "$imds" == TCP-TIMEOUT ]]; then res BLOCKED S-imds "IMDS :80 TCP-TIMEOUT mais pas de témoin sur :53 : refus non distinguable d'une panne"
  else res FAIL S-imds "IMDS :80 classé $imds depuis le témoin (attendu TCP-TIMEOUT)"; fi
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
  local svc svcport cross_rc svcs
  svcs="$(kubectl -n "$ns" get svc -o jsonpath='{range .items[?(@.spec.clusterIP!="None")]}{.metadata.name}{" "}{.spec.ports[0].port}{"\n"}{end}')" \
    || { res FAIL S-intra "liste des Services de $ns illisible"; security_cleanup; return; }
  read -r svc svcport <<<"${svcs%%$'\n'*}"
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
  --all) for n in 1 2 3 4 5 6 6b 7 8 9 10 11; do "v$n"; done; security;;
  *) die "usage : $0 --step N | --security | --all";;
esac
log "FAIL=$FAILS BLOCKED=$BLOCKS (journal : $STATE_DIR/verify.log)"
(( BLOCKS == 0 )) || log "JALON NON VALIDABLE : au moins un contrôle est BLOCKED (voir le journal)."
(( FAILS == 0 )) || exit 1
(( BLOCKS == 0 )) || exit 3
