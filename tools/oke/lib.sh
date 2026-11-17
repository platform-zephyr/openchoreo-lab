#!/usr/bin/env bash
# Bibliothèque commune des scripts tools/oke/*.sh (Phase B, docs/PHASE-B.md). Sourcée, jamais exécutée.
# Garde-fous : contexte OKE oracle-a1 seulement, kubeconfig temporaire d'open-oke-access.sh seulement,
# écriture limitée aux namespaces d'essai, mesures sans metrics-server (API summary du kubelet).
# shellcheck shell=bash

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL_DIR="$ROOT/platform/install"
# shellcheck source=../../platform/install/versions.env
. "$INSTALL_DIR/versions.env"

# Accès : produit par open-oke-access.sh (geste de Paul). Jamais créé par un agent.
OKE_ACCESS_DIR="${OKE_ACCESS_DIR:-$HOME/.cache/oke-access}"
OKE_LOCAL_PORT="${OKE_LOCAL_PORT:-16443}"
EXPECTED_KUBECONFIG="$OKE_ACCESS_DIR/kubeconfig"
OKE_CONTEXT_RE="${OKE_CONTEXT_RE:-^context-oracle-a1-}"
# Plage de l'endpoint API privé (homelab-private-subnet 10.0.2.0/24, OKE-ACCESS.md).
OKE_TLS_SERVER_RE='^10\.0\.2\.[0-9]+$'

# Budget au repos (missions/MISSION.md) appliqué à la pile de l'essai (STACK_NS).
BUDGET_MEM_MI="${BUDGET_MEM_MI:-1536}"
BUDGET_CPU_M="${BUDGET_CPU_M:-300}"
STACK_NS_RE='^(openchoreo-control-plane|openchoreo-data-plane|openchoreo-cert-manager|openchoreo-external-secrets|lab-argocd|lab-secrets)$'
# Namespaces d'essai : seuls lieux d'écriture (plus `default` : label et objets OpenChoreo uniquement,
# dp-* : créés par OpenChoreo, jamais écrits par ces scripts).
# shellcheck disable=SC2034  # utilisé par les scripts qui sourcent lib.sh
TRIAL_NS=(openchoreo-control-plane openchoreo-data-plane openchoreo-cert-manager
          openchoreo-external-secrets lab-secrets lab-argocd cnpg-system lab-pg)

STATE_DIR="${OKE_PHASEB_STATE:-$HOME/.cache/openchoreo-lab-phaseb}"
APPLY="${APPLY:-0}"

log()  { printf '%s %s\n' "$(date -u +%H:%M:%SZ)" "$*" >&2; }
die()  { log "ABANDON : $*"; exit "${2:-2}"; }

need() {
  local t
  for t in "$@"; do command -v "$t" >/dev/null 2>&1 || die "outil manquant : $t"; done
}

# run CMD... : exécute en mode --apply, affiche seulement en dry-run (défaut).
run() {
  if [[ "$APPLY" == 1 ]]; then
    log "+ $*"
    "$@"
  else
    printf '[dry-run] %s\n' "$*"
  fi
}

# Garde de contexte : refuse tout ce qui n'est pas le kubeconfig temporaire OKE oracle-a1.
guard_context() {
  need kubectl jq
  [[ -n "${KUBECONFIG:-}" ]] || die "KUBECONFIG non défini (attendu : $EXPECTED_KUBECONFIG)"
  [[ "$KUBECONFIG" == "$EXPECTED_KUBECONFIG" ]] \
    || die "KUBECONFIG=$KUBECONFIG ne pointe pas sur le kubeconfig temporaire $EXPECTED_KUBECONFIG"
  [[ -f "$KUBECONFIG" ]] || die "kubeconfig absent : l'accès n'est pas ouvert (open-oke-access.sh, geste de Paul)"
  local perm ctx server tlsname
  perm="$(stat -f '%Lp' "$KUBECONFIG" 2>/dev/null || stat -c '%a' "$KUBECONFIG")"
  [[ "$perm" == 600 ]] || die "kubeconfig en mode $perm (attendu 600)"
  ctx="$(kubectl config current-context)"
  case "$ctx" in *homeops*|*homelab*|admin@*) die "contexte interdit : $ctx";; esac
  [[ "$ctx" =~ $OKE_CONTEXT_RE ]] || die "contexte '$ctx' ne correspond pas à $OKE_CONTEXT_RE"
  server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
  [[ "$server" == "https://127.0.0.1:$OKE_LOCAL_PORT" ]] || die "serveur API inattendu : $server"
  tlsname="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.tls-server-name}')"
  [[ "$tlsname" =~ $OKE_TLS_SERVER_RE ]] || die "tls-server-name inattendu : '$tlsname' (TLS doit rester vérifié)"
  # Identité du cluster : un seul nœud, arm64, instance OCI.
  local nodes
  nodes="$(kubectl get nodes -o json)"
  [[ "$(jq '.items | length' <<<"$nodes")" == 1 ]] || die "nombre de nœuds != 1"
  [[ "$(jq -r '.items[0].status.nodeInfo.architecture' <<<"$nodes")" == arm64 ]] || die "nœud non arm64"
  [[ "$(jq -r '.items[0].spec.providerID // ""' <<<"$nodes")" == *ocid1.instance.* ]] || die "nœud non OCI"
  log "contexte OK : $ctx ($server, tls-server-name $tlsname)"
}

# usage_by_ns : "namespace cpu_m mem_Mi" par namespace, depuis l'API summary du kubelet (sans
# metrics-server). Nécessite nodes/proxy (accès opérateur). Valeurs instantanées.
usage_by_ns() {
  local node
  node="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"
  kubectl get --raw "/api/v1/nodes/$node/proxy/stats/summary" \
    | jq -r '.pods[] | [.podRef.namespace, ((.cpu.usageNanoCores // 0) / 1e6), ((.memory.workingSetBytes // 0) / 1048576)] | @tsv' \
    | awk -F'\t' '{c[$1]+=$2; m[$1]+=$3} END {for (n in c) printf "%s %d %d\n", n, c[n], m[n]}' | sort
}

# requests_by_ns : "namespace cpu_m mem_Mi" des requests des pods non terminés.
requests_by_ns() {
  kubectl get pods -A -o json | jq -r '
    def cpu: if . == null then 0 elif endswith("m") then (.[:-1]|tonumber) else (tonumber*1000) end;
    def mem: if . == null then 0 elif endswith("Mi") then (.[:-2]|tonumber) elif endswith("Gi") then (.[:-2]|tonumber*1024)
             elif endswith("Ki") then (.[:-2]|tonumber/1024) elif endswith("M") then (.[:-1]|tonumber) else (tonumber/1048576) end;
    .items[] | select(.status.phase != "Succeeded" and .status.phase != "Failed")
    | .metadata.namespace as $n | .spec.containers[]
    | [$n, (.resources.requests.cpu | cpu), (.resources.requests.memory | mem)] | @tsv' \
  | awk -F'\t' '{c[$1]+=$2; m[$1]+=$3} END {for (n in c) printf "%s %d %d\n", n, c[n], m[n]}' | sort
}

# stack_usage : "cpu_m mem_Mi" sommés sur STACK_NS_RE.
stack_usage() {
  usage_by_ns | awk -v re="$STACK_NS_RE" '$1 ~ re {c+=$2; m+=$3} END {printf "%d %d\n", c, m}'
}

# budget_gate LABEL : mesure 3 fois à 20 s d'intervalle (pic de démarrage écarté : on garde le
# minimum), compare au budget, écrit la mesure dans STATE_DIR, sort en 3 si dépassement.
budget_gate() {
  local label="$1" i cpu mem best_cpu=999999 best_mem=999999
  [[ "$APPLY" == 1 ]] || { printf '[dry-run] mesure budget après %s\n' "$label"; return 0; }
  mkdir -p "$STATE_DIR"
  for i in 1 2 3; do
    read -r cpu mem < <(stack_usage)
    (( cpu < best_cpu )) && best_cpu=$cpu
    (( mem < best_mem )) && best_mem=$mem
    [[ $i == 3 ]] || sleep 20
  done
  printf '%s %s cpu=%sm mem=%sMi budget=%sm/%sMi\n' "$(date -u +%FT%TZ)" "$label" "$best_cpu" "$best_mem" \
    "$BUDGET_CPU_M" "$BUDGET_MEM_MI" | tee -a "$STATE_DIR/budget.log" >&2
  if (( best_mem > BUDGET_MEM_MI || best_cpu > BUDGET_CPU_M )); then
    log "BUDGET DÉPASSÉ après $label : arrêt (docs/PHASE-B.md §4, rollback de l'étape)."
    exit 3
  fi
}

# fetch_chart NOM SOURCE VERSION SHA256 [REPO] : télécharge le .tgz dans STATE_DIR/charts, vérifie le
# sha256 épinglé, affiche le chemin. SOURCE = oci://... ou nom de chart (avec REPO).
fetch_chart() {
  local name="$1" src="$2" ver="$3" sha="$4" repo="${5:-}" dir="$STATE_DIR/charts" tgz got
  need helm shasum
  mkdir -p "$dir"
  tgz="$dir/$name-$ver.tgz"
  if [[ ! -f "$tgz" ]]; then
    if [[ -n "$repo" ]]; then
      helm pull "$src" --repo "$repo" --version "$ver" --destination "$dir" >&2
    else
      helm pull "$src" --version "$ver" --destination "$dir" >&2
    fi
  fi
  got="$(shasum -a 256 "$tgz" | awk '{print $1}')"
  [[ "$got" == "$sha" ]] || die "sha256 du chart $name $ver : $got != $sha (épinglé)"
  printf '%s\n' "$tgz"
}

# wait_deploys NS : attend que tous les Deployments du namespace soient Available.
wait_deploys() {
  run kubectl -n "$1" wait --for=condition=Available deployment --all --timeout="${2:-300s}"
}
