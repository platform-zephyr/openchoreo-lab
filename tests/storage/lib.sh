#!/usr/bin/env bash
# =============================================================================================
# DANGER — N'EXÉCUTER QUE SUR UN CLUSTER JETABLE (VM de test isolée créée par 00-setup-vm.sh).
# JAMAIS sur OKE (oracle-a1), jamais sur le Talos homeops, jamais sur un cluster qui porte des
# données. Ces scripts créent, remplissent et SUPPRIMENT des PVC, PV, volumes LVM et namespaces.
# =============================================================================================
# Bibliothèque commune de tests/storage. Préparée le 2026-11-17, JAMAIS exécutée (voir
# docs/storage/TEST-PLAN.md). Sourcée par chaque t*.sh ; ne s'exécute pas seule.
#
# Garde-fous (tous obligatoires, sinon sortie 2 avant toute commande kubectl d'écriture) :
#   1. STORAGE_TEST_ALLOWED_CONTEXTS : liste explicite (espaces) des contextes kubectl admis.
#   2. KUBECONFIG explicite, fichier hors ~/.kube et hors ~/.cache/oke-access.
#   3. Contexte, cluster et URL du serveur ne contiennent aucun motif de production.
#   4. ConfigMap marqueur default/storage-test-disposable (posé par 00-setup-vm.sh) avec
#      data.disposable=true et data.context=<contexte courant>.
set -euo pipefail

STORAGE_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVIDENCE_DIR="${EVIDENCE_DIR:-$STORAGE_TEST_DIR/evidence}"
ENGINE="${ENGINE:-}"                       # local-path | openebs-hostpath | openebs-lvm | longhorn
TEST_NS_PREFIX="st-"                        # tous les namespaces de test commencent par st-
TEST_IMAGE="${TEST_IMAGE:-busybox:1.36.1}"
DENY_RE='oke|oracle|oci|a1|homeops|tatouine|talos|prod|prd|admin@|10\.0\.20\.|10\.0\.2\.'

die() { echo "ABANDON : $*" >&2; exit 2; }

guard() {
  [[ -n "${STORAGE_TEST_ALLOWED_CONTEXTS:-}" ]] || die "STORAGE_TEST_ALLOWED_CONTEXTS vide : aucun contexte admis."
  [[ -n "${KUBECONFIG:-}" ]] || die "KUBECONFIG doit être explicite (fichier du cluster jetable)."
  case "$KUBECONFIG" in
    *:*) die "KUBECONFIG multiple refusé." ;;
    "$HOME"/.kube/*|*/.cache/oke-access/*|*oke*|*oracle*|*talos*|*homeops*) die "KUBECONFIG interdit : $KUBECONFIG" ;;
  esac
  [[ -f "$KUBECONFIG" ]] || die "KUBECONFIG introuvable."
  local ctx cluster server
  ctx="$(kubectl config current-context)"
  cluster="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.cluster}')"
  server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
  local ok=no c
  for c in $STORAGE_TEST_ALLOWED_CONTEXTS; do [[ "$c" == "$ctx" ]] && ok=yes; done
  [[ $ok == yes ]] || die "contexte '$ctx' absent de STORAGE_TEST_ALLOWED_CONTEXTS."
  if grep -qiE "$DENY_RE" <<<"$ctx $cluster $server"; then
    die "motif de production détecté dans contexte/cluster/serveur ($ctx / $cluster / $server)."
  fi
  local marker mctx
  marker="$(kubectl -n default get configmap storage-test-disposable -o jsonpath='{.data.disposable}' 2>/dev/null || true)"
  mctx="$(kubectl -n default get configmap storage-test-disposable -o jsonpath='{.data.context}' 2>/dev/null || true)"
  [[ "$marker" == "true" && "$mctx" == "$ctx" ]] || die "marqueur storage-test-disposable absent ou d'un autre contexte."
  local n; n="$(kubectl get nodes --no-headers | wc -l | tr -d ' ')"
  [[ "$n" == 1 ]] || die "le banc attend un cluster jetable mono-nœud ($n nœuds)."
  case "$ENGINE" in local-path|openebs-hostpath|openebs-lvm|longhorn) ;; *) die "ENGINE invalide : '$ENGINE'." ;; esac
  mkdir -p "$EVIDENCE_DIR"
}

# Commande exécutée SUR le nœud jetable (lvs, df, redémarrage k3s). Par défaut : sudo local,
# car 00-setup-vm.sh et les tests tournent dans la VM. Vide = étapes nœud NOT_TESTED.
NODE_EXEC="${NODE_EXEC-sudo}"
node_exec() { [[ -n "$NODE_EXEC" ]] || return 99; $NODE_EXEC "$@"; }

storage_class() {
  case "$ENGINE" in
    local-path) echo "${SC_OVERRIDE:-local-path}" ;;
    openebs-hostpath) echo "${SC_OVERRIDE:-st-openebs-hostpath-xfs}" ;;
    openebs-lvm) echo "${SC_OVERRIDE:-st-lvm-thick}" ;;
    longhorn) echo "${SC_OVERRIDE:-st-longhorn-1r}" ;;
  esac
}
engine_namespace() {
  case "$ENGINE" in
    local-path) echo kube-system ;; openebs-*) echo storage-system ;; longhorn) echo longhorn-system ;;
  esac
}
size_enforcement_claimed() { [[ "$ENGINE" != local-path ]]; }

RESULTS=()
FAILS=0
record() { # id status message
  RESULTS+=("$1|$2|$3")
  [[ "$2" == FAIL ]] && FAILS=$((FAILS + 1))
  printf '%-11s %-6s [%s] %s\n' "$2" "$1" "$ENGINE" "$3"
  printf '%s|%s|%s|%s|%s\n' "$(date -u +%FT%TZ)" "$ENGINE" "$1" "$2" "$3" >> "$EVIDENCE_DIR/results.log"
}
evidence() { # id -- texte sur stdin
  { echo "# $(date -u +%FT%TZ) engine=$ENGINE ctx=$(kubectl config current-context)"; cat; } >> "$EVIDENCE_DIR/$1.txt"
}
finish() {
  echo "--- résumé $(basename "$0") [$ENGINE] : ${#RESULTS[@]} résultats, $FAILS FAIL"
  [[ $FAILS -eq 0 ]]
}

new_ns() { # suffixe -> nom
  local ns; ns="${TEST_NS_PREFIX}$1-$(date +%s)"
  kubectl create namespace "$ns" >/dev/null
  kubectl label namespace "$ns" storage-test.smadja.dev/owned=true pod-security.kubernetes.io/enforce=restricted >/dev/null
  echo "$ns"
}
drop_ns() { [[ "$1" == ${TEST_NS_PREFIX}* ]] || die "refus de supprimer $1"; kubectl delete namespace "$1" --wait=true --timeout=180s >/dev/null || true; }

make_pvc() { # ns name size [storageClass]
  kubectl -n "$1" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: $2}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ${4:-$(storage_class)}
  resources: {requests: {storage: $3}}
EOF
}

# Pod "restricted" (PSA) qui monte un ou plusieurs PVC sous /data/<pvc>.
make_pod() { # ns name pvc1 [pvc2...]
  local ns=$1 name=$2; shift 2
  local mounts="" vols="" p
  for p in "$@"; do
    mounts+="        - {name: $p, mountPath: /data/$p}"$'\n'
    vols+="    - {name: $p, persistentVolumeClaim: {claimName: $p}}"$'\n'
  done
  kubectl -n "$ns" apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata: {name: $name}
spec:
  automountServiceAccountToken: false
  securityContext: {runAsNonRoot: true, runAsUser: 65532, runAsGroup: 65532, fsGroup: 65532, seccompProfile: {type: RuntimeDefault}}
  containers:
    - name: c
      image: $TEST_IMAGE
      command: ["sh", "-c", "sleep 86400"]
      securityContext: {allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: {drop: [ALL]}}
      resources: {requests: {cpu: 10m, memory: 16Mi}, limits: {memory: 64Mi}}
      volumeMounts:
$mounts
  volumes:
$vols
EOF
  kubectl -n "$ns" wait --for=condition=Ready "pod/$name" --timeout=180s >/dev/null
}
pexec() { local ns=$1 pod=$2; shift 2; kubectl -n "$ns" exec "$pod" -- sh -c "$*"; }

# Écrit N Mio dans un fichier ; renvoie le code de dd (ENOSPC attendu au-delà de la taille).
write_mib() { # ns pod path mib
  set +e; pexec "$1" "$2" "dd if=/dev/urandom of=$3 bs=1M count=$4 conv=fsync 2>&1"; local rc=$?; set -e; return $rc
}
sha_of() { pexec "$1" "$2" "sha256sum $3 | cut -d' ' -f1"; }
