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
STACK_NS_RE='^(openchoreo-control-plane|openchoreo-data-plane|openchoreo-cert-manager|openchoreo-external-secrets|lab-argocd|lab-secrets|lab-cnpg|lab-pg|dp-.+)$'
# Namespaces d'essai : seuls lieux d'écriture. Exceptions IMPOSÉES par OpenChoreo, à acquitter par Paul
# (missions/MISSION.md) : label + objets OpenChoreo dans `default` ; dp-* créés par le contrôleur
# (jamais écrits par ces scripts, supprimés au nettoyage seulement s'ils portent platform.smadja.dev/cell).
# shellcheck disable=SC2034  # utilisé par les scripts qui sourcent lib.sh
TRIAL_NS=(openchoreo-control-plane openchoreo-data-plane openchoreo-cert-manager
          openchoreo-external-secrets lab-secrets lab-argocd lab-cnpg lab-pg)
# Ancien nom de lab-cnpg, créé VIDE par l'étape 1 du 2026-11-17 (revue B3). Supprimé uniquement par
# `uninstall.sh --migrate-cnpg-system`, s'il est vide et porte nos labels (docs/PHASE-B.md §2, migration).
# shellcheck disable=SC2034
LEGACY_CNPG_NS=cnpg-system

STATE_DIR="${OKE_PHASEB_STATE:-$HOME/.cache/openchoreo-lab-phaseb}"
APPLY="${APPLY:-0}"

# Helm isolé du poste (revue m8) : un index de dépôt cassé dans ~/.cache/helm (`no cached repo found`)
# fait échouer `helm pull --repo`. Cache, config, données, dépôts et registres sous STATE_DIR/helm.
# Sans effet sur les releases (stockées dans le cluster) ni sur le kubeconfig.
export HELM_CACHE_HOME="$STATE_DIR/helm/cache" HELM_CONFIG_HOME="$STATE_DIR/helm/config" \
       HELM_DATA_HOME="$STATE_DIR/helm/data"
export HELM_REPOSITORY_CONFIG="$HELM_CONFIG_HOME/repositories.yaml" \
       HELM_REPOSITORY_CACHE="$HELM_CACHE_HOME/repository" HELM_REGISTRY_CONFIG="$HELM_CONFIG_HOME/registry/config.json"

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

# MODE TEST k3d (tests/uninstall-k3d, flux sécurité A3) : actif SEULEMENT si LAB_TEST_CLUSTER est exporté et
# vaut exactement k3d-lab-sec-vap (nom en constante, jamais un motif). Toute autre valeur non vide : refus.
# Ne remplace pas la garde OKE : il exige en plus un kubeconfig hors OKE_ACCESS_DIR, le contexte
# k3d-lab-sec-vap, un serveur local, un nœud unique k3d-lab-sec-vap-server-0 au providerID k3s:// et un
# STATE_DIR dédié (OKE_PHASEB_STATE ≠ défaut), pour ne jamais lire ni écrire l'état réel de l'essai OKE.
LAB_TEST_CONTEXT=k3d-lab-sec-vap
guard_test_context() {
  [[ "$LAB_TEST_CLUSTER" == "$LAB_TEST_CONTEXT" ]] \
    || die "LAB_TEST_CLUSTER='$LAB_TEST_CLUSTER' refusé : seul '$LAB_TEST_CONTEXT' est un cluster de test accepté"
  [[ -n "${KUBECONFIG:-}" && "$KUBECONFIG" != *:* ]] || die "mode test : KUBECONFIG doit désigner un seul fichier"
  [[ "$KUBECONFIG" != "$EXPECTED_KUBECONFIG" && "$KUBECONFIG" != "$OKE_ACCESS_DIR"/* && "$KUBECONFIG" != *oke-access* ]] \
    || die "mode test : KUBECONFIG=$KUBECONFIG est le kubeconfig OKE"
  [[ -f "$KUBECONFIG" ]] || die "mode test : kubeconfig absent : $KUBECONFIG"
  [[ -n "${OKE_PHASEB_STATE:-}" && "$STATE_DIR" != "$HOME/.cache/openchoreo-lab-phaseb" ]] \
    || die "mode test : OKE_PHASEB_STATE dédié requis (jamais l'état réel $HOME/.cache/openchoreo-lab-phaseb)"
  local ctx server nodes
  ctx="$(kubectl config current-context)"
  [[ "$ctx" == "$LAB_TEST_CONTEXT" ]] || die "mode test : contexte '$ctx' != $LAB_TEST_CONTEXT"
  [[ ! "$ctx" =~ $OKE_CONTEXT_RE ]] || die "mode test : contexte OKE refusé"
  server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
  [[ "$server" =~ ^https://(0\.0\.0\.0|127\.0\.0\.1|localhost):[0-9]+$ && "$server" != "https://127.0.0.1:$OKE_LOCAL_PORT" ]] \
    || die "mode test : serveur API inattendu : $server"
  nodes="$(kubectl get nodes -o json)" || die "mode test : nœuds illisibles"
  [[ "$(jq '.items | length' <<<"$nodes")" == 1 ]] || die "mode test : nombre de nœuds != 1"
  [[ "$(jq -r '.items[0].metadata.name' <<<"$nodes")" == "$LAB_TEST_CONTEXT-server-0" ]] || die "mode test : nœud inattendu"
  [[ "$(jq -r '.items[0].spec.providerID // ""' <<<"$nodes")" == k3s://* ]] || die "mode test : nœud non k3s"
  log "MODE TEST k3d : contexte $ctx ($server), état $STATE_DIR"
}

# Garde de contexte : refuse tout ce qui n'est pas le kubeconfig temporaire OKE oracle-a1 (ou, en mode
# test explicite, le seul k3d jetable k3d-lab-sec-vap : guard_test_context ci-dessus).
guard_context() {
  need kubectl jq
  if [[ -n "${LAB_TEST_CLUSTER:-}" ]]; then guard_test_context; return; fi
  [[ -n "${KUBECONFIG:-}" ]] || die "KUBECONFIG non défini (attendu : $EXPECTED_KUBECONFIG)"
  [[ "$KUBECONFIG" == "$EXPECTED_KUBECONFIG" ]] \
    || die "KUBECONFIG=$KUBECONFIG ne pointe pas sur le kubeconfig temporaire $EXPECTED_KUBECONFIG"
  [[ -f "$KUBECONFIG" ]] || die "kubeconfig absent : l'accès n'est pas ouvert (open-oke-access.sh, geste de Paul)"
  local perm ctx server tlsname
  # GNU d'abord : sous Linux, `stat -f` (système de fichiers) réussit partiellement et polluerait la valeur.
  perm="$(stat -c '%a' "$KUBECONFIG" 2>/dev/null || stat -f '%Lp' "$KUBECONFIG")"
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

# --- Mesures ---------------------------------------------------------------------------------------
# Règle : une mesure absente, vide ou illisible n'est JAMAIS un zéro. Elle sort `MEASUREMENT_UNAVAILABLE`
# (code 4) et interdit toute conclusion PASS.
unavailable() { printf 'MEASUREMENT_UNAVAILABLE: %s\n' "$1" >&2; }

# usage_by_ns : "namespace cpu_m mem_Mi" par namespace (API summary du kubelet, sans metrics-server ;
# nécessite nodes/proxy). Valeurs instantanées. Un pod sans valeur CPU/mémoire rend "NA NA" pour son
# namespace (jamais 0). Code 4 si l'API échoue, répond vide ou n'a aucun pod.
usage_by_ns() {
  local node raw
  node="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)" || node=""
  [[ -n "$node" ]] || { unavailable "nom du nœud illisible"; return 4; }
  raw="$(kubectl get --raw "/api/v1/nodes/$node/proxy/stats/summary" 2>/dev/null)" \
    || { unavailable "API kubelet /stats/summary en erreur"; return 4; }
  [[ -n "$raw" ]] || { unavailable "API kubelet /stats/summary : réponse vide"; return 4; }
  jq -e '(.pods | type == "array") and (.pods | length > 0)' <<<"$raw" >/dev/null 2>&1 \
    || { unavailable "API kubelet /stats/summary : aucun pod dans la réponse"; return 4; }
  jq -r '.pods[] | [.podRef.namespace, (.cpu.usageNanoCores // "NA"), (.memory.workingSetBytes // "NA")] | @tsv' <<<"$raw" \
    | awk -F'\t' '{ns=$1; seen[ns]=1; if ($2=="NA"||$3=="NA") {na[ns]=1; next} c[ns]+=$2/1e6; m[ns]+=$3/1048576}
        END {for (n in seen) { if (n in na) printf "%s NA NA\n", n; else printf "%s %d %d\n", n, int(c[n]+0.999), int(m[n]+0.999) }}' | sort
}

# requests_by_ns : "namespace cpu_m mem_Mi" des requests effectives (max(somme des conteneurs, plus
# grand initContainer)) des pods non terminés. Code non nul si kubectl échoue (jamais de liste vide silencieuse).
requests_by_ns() {
  local pods
  pods="$(kubectl get pods -A -o json)" || { unavailable "kubectl get pods -A en erreur"; return 4; }
  jq -r '
    def cpu: if . == null then 0 elif endswith("m") then (.[:-1]|tonumber) else (tonumber*1000) end;
    def mem: if . == null then 0 elif endswith("Mi") then (.[:-2]|tonumber) elif endswith("Gi") then (.[:-2]|tonumber*1024)
             elif endswith("Ki") then (.[:-2]|tonumber/1024) elif endswith("G") then (.[:-1]|tonumber*1e9/1048576)
             elif endswith("M") then (.[:-1]|tonumber*1e6/1048576) elif endswith("k") then (.[:-1]|tonumber*1000/1048576)
             else (tonumber/1048576) end;
    def eff(p; f): ([.spec.containers[] | (.resources.requests // {}) | p | f] | add // 0) as $s
                | ([(.spec.initContainers // [])[] | (.resources.requests // {}) | p | f] | max // 0) as $i
                | if $i > $s then $i else $s end;
    .items[] | select(.status.phase != "Succeeded" and .status.phase != "Failed")
    | [.metadata.namespace, eff(.cpu; cpu), eff(.memory; mem)] | @tsv' <<<"$pods" \
  | awk -F'\t' '{c[$1]+=$2; m[$1]+=$3} END {for (n in c) printf "%s %d %d\n", n, c[n], m[n]}' | sort
}

# stack_usage : "cpu_m mem_Mi" sommés sur STACK_NS_RE (pile de l'essai, y compris lab-cnpg, lab-pg, dp-*).
# Code 4 (MEASUREMENT_UNAVAILABLE) si une mesure manque : kubectl en erreur, namespace de la pile avec des
# pods mais absent de la réponse, ou valeur NA. Seul le filtrage grep tolère « aucune ligne » (revue I11).
stack_usage() {
  local u wanted ns pods all
  u="$(usage_by_ns)" || return 4
  pods="$(kubectl get pods -A --field-selector=status.phase=Running -o json)" \
    || { unavailable "kubectl get pods (Running) en erreur"; return 4; }
  all="$(jq -r '.items[].metadata.namespace' <<<"$pods")" || { unavailable "liste des pods illisible"; return 4; }
  wanted="$(sort -u <<<"$all" | { grep -E "$STACK_NS_RE" || true; })"
  for ns in $wanted; do
    awk -v n="$ns" '$1==n {f=1} END {exit !f}' <<<"$u" || { unavailable "namespace $ns : pods Running mais absent de /stats/summary"; return 4; }
  done
  if awk -v re="$STACK_NS_RE" '$1 ~ re && $2=="NA" {f=1} END {exit !f}' <<<"$u"; then
    unavailable "valeur CPU/mémoire absente pour au moins un pod de la pile"; return 4
  fi
  awk -v re="$STACK_NS_RE" '$1 ~ re {c+=$2; m+=$3} END {printf "%d %d\n", c, m}' <<<"$u"
}

# capacity_gate : requests effectives de TOUS les pods face à l'allocatable du nœud et au seuil de 70 %
# (D-2026-11-15-05), CPU et mémoire. Ne conclut jamais sur une valeur vide. Code 5 si dépassement,
# 4 si indisponible. Les requests ne sont JAMAIS réduites pour passer ce test (voir docs/PHASE-B.md §4).
CAP_THRESHOLD_PCT="${CAP_THRESHOLD_PCT:-70}"
capacity_gate() {
  local alloc acpu amem rq rcpu rmem pcpu pmem
  alloc="$(kubectl get nodes -o json 2>/dev/null | jq -r '.items[0].status.allocatable | [.cpu, .memory] | @tsv')" || alloc=""
  [[ -n "$alloc" ]] || { unavailable "allocatable du nœud illisible"; return 4; }
  acpu="$(awk '{v=$1; if (v ~ /m$/) {sub(/m$/,"",v); print v} else print v*1000}' <<<"$alloc")"
  amem="$(awk '{v=$2; if (v ~ /Ki$/) {sub(/Ki$/,"",v); print v/1024} else if (v ~ /Mi$/) {sub(/Mi$/,"",v); print v} else if (v ~ /Gi$/) {sub(/Gi$/,"",v); print v*1024} else print v/1048576}' <<<"$alloc")"
  rq="$(requests_by_ns)" || rq=""
  [[ -n "$rq" ]] || { unavailable "requests des pods illisibles"; return 4; }
  read -r rcpu rmem < <(awk '{c+=$2; m+=$3} END {printf "%d %d\n", c, m}' <<<"$rq")
  acpu="${acpu%.*}"; amem="${amem%.*}"
  [[ "$acpu" =~ ^[0-9]+$ && "$amem" =~ ^[0-9]+$ && "$acpu" -gt 0 && "$amem" -gt 0 ]] \
    || { unavailable "allocatable non numérique ($acpu m, $amem Mi)"; return 4; }
  # Pourcentage affiché arrondi au supérieur ; comparaison exacte en entiers (70,9 % ne passe plus, revue m6).
  pcpu=$(( (rcpu * 100 + acpu - 1) / acpu )); pmem=$(( (rmem * 100 + amem - 1) / amem ))
  printf '%s capacité (tous pods) requests cpu=%sm/%sm (%s%%) mem=%sMi/%sMi (%s%%) seuil=%s%%\n' "$(date -u +%FT%TZ)" \
    "$rcpu" "$acpu" "$pcpu" "$rmem" "$amem" "$pmem" "$CAP_THRESHOLD_PCT" | tee -a "$STATE_DIR/budget.log" >&2
  if (( rcpu * 100 > acpu * CAP_THRESHOLD_PCT || rmem * 100 > amem * CAP_THRESHOLD_PCT )); then
    log "SEUIL DE CAPACITÉ DÉPASSÉ (${CAP_THRESHOLD_PCT} %) : arrêt, ne pas réduire les requests pour passer (risque d'éviction)."
    return 5
  fi
}

# budget_gate LABEL : 3 mesures à 20 s d'intervalle (chacune réessayée 3 fois si indisponible). Journalise les
# valeurs individuelles, la moyenne et le MAXIMUM ; le budget est comparé au MAXIMUM (jamais au minimum).
# Code 3 : budget dépassé ; 4 : MEASUREMENT_UNAVAILABLE (aucun PASS possible) ; 5 : seuil de capacité dépassé.
budget_gate() {
  local label="$1" i t out cpus=() mems=() cpu mem sc=0 sm=0 maxc=0 maxm=0 n=3
  [[ "$APPLY" == 1 ]] || { printf '[dry-run] mesure budget après %s\n' "$label"; return 0; }
  mkdir -p "$STATE_DIR"
  for i in 1 2 3; do
    out=""
    for t in 1 2 3; do
      if out="$(stack_usage 2>/dev/null)" && [[ -n "$out" ]]; then break; fi
      out=""; sleep 10
    done
    if [[ -z "$out" ]]; then
      stack_usage >/dev/null || true
      printf '%s %s MEASUREMENT_UNAVAILABLE (échantillon %s) : aucune conclusion PASS\n' "$(date -u +%FT%TZ)" "$label" "$i" | tee -a "$STATE_DIR/budget.log" >&2
      exit 4
    fi
    read -r cpu mem <<<"$out"; cpus+=("$cpu"); mems+=("$mem")
    sc=$((sc + cpu)); sm=$((sm + mem)); (( cpu > maxc )) && maxc=$cpu; (( mem > maxm )) && maxm=$mem
    [[ $i == 3 ]] || sleep 20
  done
  printf '%s %s usage pile (essais+lab-cnpg+lab-pg+dp-*) cpu=[%s]m moy=%sm max=%sm ; mem=[%s]Mi moy=%sMi max=%sMi ; budget=%sm/%sMi (comparé au MAX)\n' \
    "$(date -u +%FT%TZ)" "$label" "$(IFS=,; echo "${cpus[*]}")" $((sc / n)) "$maxc" "$(IFS=,; echo "${mems[*]}")" $((sm / n)) "$maxm" \
    "$BUDGET_CPU_M" "$BUDGET_MEM_MI" | tee -a "$STATE_DIR/budget.log" >&2
  if (( maxm > BUDGET_MEM_MI || maxc > BUDGET_CPU_M )); then
    log "BUDGET DÉPASSÉ après $label : arrêt (docs/PHASE-B.md §4, rollback de l'étape)."
    exit 3
  fi
  capacity_gate || exit $?
}

# fetch_chart NOM SOURCE VERSION SHA256 [REPO] : télécharge le .tgz dans STATE_DIR/charts, vérifie le
# sha256 épinglé, affiche le chemin. SOURCE = oci://... ou nom de chart (avec REPO).
fetch_chart() {
  local name="$1" src="$2" ver="$3" sha="$4" repo="${5:-}" dir="$STATE_DIR/charts" tgz got
  need helm shasum
  mkdir -p "$dir" "$HELM_CACHE_HOME" "$HELM_CONFIG_HOME" "$HELM_DATA_HOME"
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

# fetch_gw_crds : télécharge le manifest des CRD Gateway API (versions.env) dans STATE_DIR, vérifie son
# sha256 épinglé, affiche son chemin. Utilisé par install.sh (étape 2) et uninstall.sh (rendu des CRD).
fetch_gw_crds() {
  local f="$STATE_DIR/gateway-api-$GW_CRDS_VERSION.yaml" got
  need curl shasum
  mkdir -p "$STATE_DIR"
  [[ -f "$f" ]] || curl -fsSL -o "$f" "$GW_CRDS_URL" >&2
  got="$(shasum -a 256 "$f" | awk '{print $1}')"
  [[ "$got" == "$GW_CRDS_SHA256" ]] || die "sha256 Gateway API : $got != $GW_CRDS_SHA256"
  printf '%s\n' "$f"
}

# wait_deploys NS : attend que tous les Deployments du namespace soient Available.
wait_deploys() {
  run kubectl -n "$1" wait --for=condition=Available deployment --all --timeout="${2:-300s}"
}
