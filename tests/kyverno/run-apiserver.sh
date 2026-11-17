#!/usr/bin/env bash
# Preuves Kyverno sur un VRAI API server (k3d `lab-sec-kyv`) : refus et témoins par requêtes réelles
# (--as), PolicyReport exploitables, test « Kyverno indisponible », empreinte mesurée.
# STATUT : PRÊT, NON EXÉCUTÉ (2026-11-17 : VM colima saturée, aucun cluster libre ; décision de Paul).
#
# Usage :
#   KUBECONFIG=<scratchpad>/lab-sec-kyv.kubeconfig tests/kyverno/run-apiserver.sh [--create] [--keep]
#     --create : crée le cluster k3d lab-sec-kyv (DOCKER_CONTEXT=colima-openchoreo) si la VM a >= 2560 MiB libres
#     --keep   : ne supprime pas le cluster à la fin
# Garde-fous de contexte (échec franc, code 2) :
#   - KUBECONFIG explicite, fichier dédié ; jamais ~/.kube/config ni ~/.cache/oke-access ;
#   - contexte courant EXACTEMENT k3d-lab-sec-kyv ; serveur https://0.0.0.0|127.0.0.1 (k3d local) ;
#   - refus de tout contexte nommé oke, openchoreo, lab-sec-a1, lab-sec-argo, lab-sec-vap.
# Sorties : tests/kyverno/evidence/<horodatage>/ (journal, rapports JSON, empreinte). Codes : 0 PASS, 1 FAIL, 2 garde.
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../../platform/kyverno/install/versions.env
. "$repo/platform/kyverno/install/versions.env"
CLUSTER=lab-sec-kyv CTX=k3d-lab-sec-kyv KNS=lab-kyverno
create=0 keep=0
for a in "$@"; do case "$a" in --create) create=1 ;; --keep) keep=1 ;; *) echo "argument inconnu : $a" >&2; exit 2 ;; esac; done

die() { echo "GARDE: $*" >&2; exit 2; }
[[ -n "${KUBECONFIG:-}" ]] || die "KUBECONFIG doit être explicite (fichier dédié au cluster $CLUSTER)"
[[ "$KUBECONFIG" != *":"* ]] || die "un seul fichier KUBECONFIG"
case "$KUBECONFIG" in "$HOME/.kube/config"|*oke-access*) die "KUBECONFIG interdit : $KUBECONFIG" ;; esac

if [[ $create -eq 1 ]]; then
  export DOCKER_CONTEXT=colima-openchoreo
  avail="$(colima ssh -p openchoreo -- free -m | awk '/^Mem:/{print $7}')"
  [[ "$avail" -ge 2560 ]] || die "mémoire VM insuffisante : ${avail} MiB disponibles (< 2560)"
  k3d cluster list -o json | jq -e --arg c "$CLUSTER" 'any(.[]; .name == $c)' >/dev/null && die "$CLUSTER existe déjà"
  k3d cluster create "$CLUSTER" --agents 0 --kubeconfig-update-default=false --kubeconfig-switch-context=false \
    --k3s-arg '--disable=traefik@server:0' --wait
  k3d kubeconfig get "$CLUSTER" > "$KUBECONFIG"
fi
cur="$(kubectl config current-context)"
[[ "$cur" == "$CTX" ]] || die "contexte courant '$cur' ≠ $CTX"
case "$cur" in *oke*|*openchoreo*|*lab-sec-a1*|*lab-sec-argo*|*lab-sec-vap*) die "contexte interdit : $cur" ;; esac
srv="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
[[ "$srv" =~ ^https://(0\.0\.0\.0|127\.0\.0\.1|localhost): ]] || die "serveur non local : $srv"

ev="$repo/tests/kyverno/evidence/$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p "$ev"
exec > >(tee "$ev/run.log") 2>&1
pass=0 fail=0
ok()  { echo "PASS $1 — $2"; pass=$((pass+1)); }
ko()  { echo "FAIL $1 — $2"; fail=$((fail+1)); }
# expect_deny ID MOTIF commande... : la commande DOIT échouer avec MOTIF dans stderr.
expect_deny() { local id=$1 pat=$2; shift 2; local out
  if out="$("$@" 2>&1)"; then ko "$id" "admis (attendu : refus « $pat »)"
  elif grep -qE "$pat" <<<"$out"; then ok "$id" "refusé : $(grep -oE "${pat}[^\"]{0,80}" <<<"$out" | head -1)"
  else ko "$id" "refusé pour une autre raison : ${out:0:200}"; fi; }
expect_ok() { local id=$1; shift; local out
  if out="$("$@" 2>&1)"; then ok "$id" "admis"; else ko "$id" "refusé : ${out:0:200}"; fi; }
K() { kubectl "$@"; }
APP_SA=system:serviceaccount:dp-kyv:app
D1=ghcr.io/example/app@sha256:0000000000000000000000000000000000000000000000000000000000000001

echo "== 0. Protections indépendantes de Kyverno (installées AVANT lui) : PSA + VAP natives"
K apply -f "$repo/platform/kyverno/install/namespaces.yaml"
for ns in dp-kyv lab-kyvtest; do
  K create namespace "$ns" --dry-run=client -o yaml | K label --local -f - -o yaml \
    pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=latest \
    platform.smadja.dev/egress-isolated=true app.kubernetes.io/part-of=openchoreo-lab | K apply -f -
  K -n "$ns" create quota lab-quota --hard=requests.cpu=500m,requests.memory=512Mi,services.loadbalancers=0,services.nodeports=0 \
    --dry-run=client -o yaml | K apply -f -
  K -n "$ns" apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: lab-default-deny}
spec: {podSelector: {}, policyTypes: [Ingress, Egress]}
EOF
done
K -n dp-kyv create serviceaccount app --dry-run=client -o yaml | K apply -f -
K create clusterrolebinding kyv-app-edit --clusterrole=edit --serviceaccount=dp-kyv:app --dry-run=client -o yaml | K apply -f -
K apply -f "$repo/platform/policies/vap-cell-pod-hardening.yaml"
# VAP kube-ops baseline (export OKE) : simulée telle quelle pour reproduire la cible.
jq '.items |= map(del(.metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp,
      .metadata.generation, .metadata.managedFields, .status))' \
  "$repo/tests/vap/fixtures/baseline-oke-export.json" | K apply -f -

echo "== 1. Installation Kyverno $KYVERNO_VERSION (chart $KYVERNO_CHART_VERSION, profil minimal)"
tgz="$ev/kyverno-$KYVERNO_CHART_VERSION.tgz"
curl -fsSL "$KYVERNO_CHART_REPO/kyverno-$KYVERNO_CHART_VERSION.tgz" -o "$tgz"
echo "$KYVERNO_CHART_TGZ_SHA256  $tgz" | shasum -a 256 -c -
helm upgrade --install kyverno "$tgz" -n "$KNS" -f "$repo/platform/kyverno/install/values.yaml" --wait --timeout 5m
# CRD minimale CNPG (K-10) si l'opérateur n'est pas présent.
K get crd clusters.postgresql.cnpg.io >/dev/null 2>&1 || \
  K apply -f "$repo/tests/kyverno/lab-protect-persistent-data/cnpg-cluster-crd.yaml"
K apply -f "$repo/platform/kyverno/policies/"
K wait --for=condition=Ready validatingpolicies.policies.kyverno.io --all --timeout=120s
K get validatingwebhookconfigurations -o json > "$ev/webhooks.json"
sleep 5

echo "== 2. Refus et témoins par requêtes réelles"
mkdeploy() { # nom ns image [extra securityContext json]
  cat <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: $1, namespace: $2}
spec:
  selector: {matchLabels: {app: $1}}
  template:
    metadata: {labels: {app: $1}}
    spec:
      securityContext: {runAsNonRoot: true, seccompProfile: {type: RuntimeDefault}}
      automountServiceAccountToken: false
      containers:
        - name: app
          image: $3
          securityContext: ${4:-{allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}}
          resources: {requests: {cpu: 10m, memory: 16Mi}, limits: {memory: 32Mi}}
EOF
}
expect_ok   K01-ok  sh -c "$(declare -f mkdeploy); mkdeploy ok-app dp-kyv $D1 | kubectl apply --as=$APP_SA -f -"
expect_deny K01-esc 'lab-workload-restricted' sh -c "$(declare -f mkdeploy); mkdeploy esc dp-kyv $D1 '{capabilities: {drop: [ALL]}}' | kubectl apply --as=$APP_SA -f -"
expect_deny K03-tag 'lab-image-digest' sh -c "$(declare -f mkdeploy); mkdeploy tag dp-kyv nginx:1.27 | kubectl apply --as=$APP_SA -f -"
expect_deny K04-lb  'lab-service-exposure' kubectl -n dp-kyv create service loadbalancer lb --tcp=443 --as=$APP_SA
expect_deny K04-np  'lab-service-exposure' kubectl -n dp-kyv create service nodeport np --tcp=80 --as=$APP_SA
expect_ok   K04-cip kubectl -n dp-kyv create service clusterip cip --tcp=80 --as=$APP_SA
expect_deny K06-crb 'lab-cluster-scoped-provenance' sh -c "kubectl create clusterrole kyv-app --verb=get --resource=pods --dry-run=client -o yaml | kubectl annotate --local -f - -o yaml argocd.argoproj.io/tracking-id=lab-apps:rbac.authorization.k8s.io/ClusterRole:/kyv-app | kubectl apply -f -"
expect_deny K07-np  'lab-security-objects-guard' kubectl -n dp-kyv delete networkpolicy lab-default-deny --as=$APP_SA
expect_deny K07-psa 'lab-security-objects-guard' kubectl label ns lab-kyvtest pod-security.kubernetes.io/enforce=privileged --overwrite
expect_deny K08-lbl 'lab-egress-declared' kubectl label ns lab-kyvtest platform.smadja.dev/egress-isolated-
K -n dp-kyv apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: data}
spec: {accessModes: [ReadWriteOnce], resources: {requests: {storage: 1Gi}}}
EOF
expect_deny K10-del 'lab-protect-persistent-data' kubectl -n dp-kyv delete pvc data --wait=false
expect_deny K12-win 'lab-delete-approval-window' kubectl -n dp-kyv annotate pvc data platform.smadja.dev/delete-approved-until="$(date -u -v+3d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+3 days' +%Y-%m-%dT%H:%M:%SZ)"
expect_deny K11-exp 'lab-policy-exception-governance' sh -c "kubectl apply -f - <<'EOF'
apiVersion: policies.kyverno.io/v1
kind: PolicyException
metadata: {name: no-expiry, namespace: lab-policy-exceptions}
spec:
  policyRefs: [{name: lab-image-digest, kind: ValidatingPolicy}]
  matchConditions: [{name: x, expression: 'true'}]
EOF"

echo "== 3. Rapports (PolicyReport) et requête jq de conformité"
sleep 60   # agrégation admission -> PolicyReport
K get policyreports.wgpolicyk8s.io -A -o json > "$ev/policyreports.json" || true
K get clusterpolicyreports.wgpolicyk8s.io -o json > "$ev/clusterpolicyreports.json" || true
jq -r '[.items[] | {ns: .metadata.namespace, pass: (.summary.pass // 0), fail: (.summary.fail // 0)}]
  | group_by(.ns) | map({ns: .[0].ns, pass: (map(.pass)|add), fail: (map(.fail)|add)}) | .[]
  | "\(.ns)\tpass=\(.pass)\tfail=\(.fail)"' "$ev/policyreports.json" | tee "$ev/compliance-by-namespace.tsv"
if [[ -s "$ev/compliance-by-namespace.tsv" ]]; then ok RPT "PolicyReport agrégés"; else ko RPT "aucun PolicyReport"; fi

echo "== 4. Empreinte au repos (metrics-server k3s)"
sleep 30
K -n "$KNS" get pods -o wide | tee "$ev/pods.txt"
K top pods -n "$KNS" --containers | tee "$ev/top.txt" || echo "metrics-server indisponible"
K -n "$KNS" get pods -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u | tee "$ev/images.txt"

echo "== 5. Kyverno INDISPONIBLE (admission controller à 0)"
K -n "$KNS" scale deploy kyverno-admission-controller --replicas=0
K -n "$KNS" wait --for=delete pod -l app.kubernetes.io/component=admission-controller --timeout=120s || true
# Critiques : toujours refusés SANS Kyverno.
expect_deny DOWN-priv  'lab-cell-pod-hardening|baseline-pod-hardening|PodSecurity' kubectl -n dp-kyv run priv --image=$D1 --as=$APP_SA \
  --overrides='{"spec":{"containers":[{"name":"priv","image":"'$D1'","securityContext":{"privileged":true}}]}}'
expect_deny DOWN-root  'PodSecurity' kubectl -n dp-kyv run root --image=$D1 --as=$APP_SA \
  --overrides='{"spec":{"securityContext":{"runAsUser":0},"containers":[{"name":"root","image":"'$D1'"}]}}'
expect_deny DOWN-tag   'lab-cell-pod-hardening' kubectl -n dp-kyv run tag --image=nginx:1.27 --as=$APP_SA
expect_deny DOWN-lb    'exceeded quota' kubectl -n dp-kyv create service loadbalancer lb2 --tcp=443 --as=$APP_SA
# Fail : destructif et exceptions refusés (webhook injoignable).
expect_deny DOWN-pvc   'failed calling webhook|no endpoints|connection refused' kubectl -n dp-kyv delete pvc data --wait=false
expect_deny DOWN-pex   'failed calling webhook|no endpoints|connection refused' sh -c "kubectl apply -f - <<'EOF'
apiVersion: policies.kyverno.io/v1
kind: PolicyException
metadata: {name: during-outage, namespace: lab-policy-exceptions}
spec:
  policyRefs: [{name: lab-image-digest, kind: ValidatingPolicy}]
  matchConditions: [{name: x, expression: 'true'}]
EOF"
# Ignore : non critiques admis (le Pod reste soumis à PSA) ; le cluster n'est PAS bloqué.
expect_ok   DOWN-esc   sh -c "$(declare -f mkdeploy); mkdeploy esc-down dp-kyv $D1 '{capabilities: {drop: [ALL]}}' | kubectl apply --as=$APP_SA -f -"
expect_ok   DOWN-ns    kubectl create namespace lab-kyv-outage
K delete namespace lab-kyv-outage --wait=false
expect_ok   DOWN-sys   kubectl -n kube-system create configmap kyv-outage-probe --from-literal=a=b
K -n kube-system delete configmap kyv-outage-probe --ignore-not-found
K -n "$KNS" scale deploy kyverno-admission-controller --replicas=1
K -n "$KNS" rollout status deploy kyverno-admission-controller --timeout=180s

echo "== Bilan : $pass PASS, $fail FAIL (preuves : $ev)"
if [[ $keep -eq 0 && $create -eq 1 ]]; then DOCKER_CONTEXT=colima-openchoreo k3d cluster delete "$CLUSTER"; fi
[[ $fail -eq 0 ]]
