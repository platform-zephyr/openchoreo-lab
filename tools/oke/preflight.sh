#!/usr/bin/env bash
# preflight.sh : vérifications EN LECTURE SEULE avant la Phase B (docs/PHASE-B.md §1, étape 0).
# Aucune écriture : uniquement get/list, l'API summary du kubelet et `kubectl top` s'il existe.
# Pré-requis : accès ouvert par Paul (open-oke-access.sh open), export KUBECONFIG=~/.cache/oke-access/kubeconfig.
# Sortie : rapport sur stdout ; code 0 = GO, 1 = NO-GO (au moins un BLOQUANT), 2 = garde de contexte.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

guard_context
BLOCK=0
ok()    { printf 'OK        %s\n' "$*"; }
warn()  { printf 'ATTENTION %s\n' "$*"; }
block() { printf 'BLOQUANT  %s\n' "$*"; BLOCK=1; }

echo "== Cluster"
ver="$(kubectl version -o json | jq -r '.serverVersion.gitVersion')"
case "$ver" in v1.3[4-9]*|v1.[4-9][0-9]*) ok "Kubernetes $ver (>= 1.34 requis par OpenChoreo 1.3.3)";; *) block "Kubernetes $ver < 1.34";; esac
node="$(kubectl get nodes -o json)"
jq -r '.items[0] | "nœud \(.metadata.name) \(.status.nodeInfo.architecture) kubelet \(.status.nodeInfo.kubeletVersion) allocatable cpu=\(.status.allocatable.cpu) mem=\(.status.allocatable.memory) pods=\(.status.allocatable.pods)"' <<<"$node"
alloc_pods="$(jq -r '.items[0].status.allocatable.pods' <<<"$node")"
running_pods="$(kubectl get pods -A --field-selector=status.phase!=Succeeded,status.phase!=Failed -o json \
  | jq '[.items[] | select(.spec.hostNetwork != true)] | length')"
echo "pods avec IP VCN (hors hostNetwork) : $running_pods / $alloc_pods"
# La Phase B ajoute 16 pods permanents (docs/PHASE-B.md §4) + Jobs transitoires.
if (( running_pods + 20 > alloc_pods )); then block "IP de pods insuffisantes : $running_pods + 20 > $alloc_pods"; else ok "marge de pods suffisante"; fi

echo "== Requests déclarées par namespace (cpu m, mem Mi)"
requests_by_ns
echo "== Usage instantané par namespace (API summary du kubelet ; cpu m, mem Mi)"
usage_by_ns
if kubectl top nodes >/dev/null 2>&1; then
  echo "== kubectl top (metrics-server présent)"; kubectl top nodes; kubectl top pods -A --no-headers | sort
else
  warn "metrics-server absent : mesures par l'API summary du kubelet (tools/oke/measure.sh)"
fi

echo "== Baseline kube-ops #1620 attendue"
for v in baseline-pod-hardening baseline-automount-token baseline-image-digest; do
  if kubectl get validatingadmissionpolicy "$v" >/dev/null 2>&1; then ok "VAP $v"; else block "VAP $v absente"; fi
done
for p in allow-egress-unisolated deny-imds; do
  if kubectl get ciliumclusterwidenetworkpolicy "$p" >/dev/null 2>&1; then ok "CCNP $p"; else block "CCNP $p absente"; fi
done
if kubectl -n kube-system get ds cilium >/dev/null 2>&1; then ok "Cilium présent"; else block "Cilium absent"; fi
# Conflit C1 : la CCNP allow-all neutralise le default-deny egress des namespaces d'essai.
sel="$(kubectl get ciliumclusterwidenetworkpolicy allow-egress-unisolated -o json 2>/dev/null \
  | jq -c '.spec.endpointSelector.matchExpressions // []' || echo '[]')"
if grep -q 'platform.smadja.dev/egress-isolated' <<<"$sel"; then
  ok "C1 résolu : allow-egress-unisolated exclut platform.smadja.dev/egress-isolated"
else
  warn "C1 OUVERT : allow-egress-unisolated sélectionne aussi openchoreo-*/lab-*/dp-* ; default-deny egress non prouvable"
fi

echo "== CRD déjà présentes (une installation d'essai ne doit pas en écraser d'autres)"
kubectl get crd -o name | grep -E 'gateway\.networking\.k8s\.io|cert-manager\.io|external-secrets\.io|kgateway\.dev|openchoreo\.dev|argoproj\.io|cnpg\.io' || echo "(aucune)"

echo "== Namespaces"
for ns in "${TRIAL_NS[@]}" argocd external-secrets cert-manager thunder; do
  if kubectl get ns "$ns" >/dev/null 2>&1; then
    part="$(kubectl get ns "$ns" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}')"
    if [[ "$part" == openchoreo-lab ]]; then ok "$ns existe (essai, reprise)"; else warn "$ns existe HORS essai (part-of='$part')"; fi
  fi
done
kubectl get ns -o name | grep -E '/dp-' && warn "namespaces dp-* déjà présents" || true
[[ "$(kubectl get ns default -o jsonpath='{.metadata.labels.openchoreo\.dev/control-plane}')" == true ]] \
  && warn "default déjà labellisé openchoreo.dev/control-plane" || true

echo "== Stockage (block volume OCI : 50 Go minimum par PVC, quota Always Free 200 Go)"
kubectl get storageclass
kubectl get pv -o custom-columns=NAME:.metadata.name,SIZE:.spec.capacity.storage,CLAIM:.spec.claimRef.namespace,STATUS:.status.phase --no-headers || true
warn "volumes OCI hors cluster (boot 50 Go + 2 x 50 Go du drill, OKE-EXEC.md) invisibles ici : budget à confirmer par Paul avant l'étape 10 (lab-pg)"

echo "== Services LoadBalancer existants"
kubectl get svc -A -o json | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace)/\(.metadata.name)"' || true

echo "== Verdict"
if (( BLOCK )); then echo "NO-GO"; exit 1; fi
echo "GO (pré-requis lus ; rien n'a été modifié)"
