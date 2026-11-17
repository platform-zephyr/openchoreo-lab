#!/usr/bin/env bash
# _lib.sh : socle commun des vérifications runtime des golden paths.
#
# LECTURE SEULE. Le wrapper k() n'accepte que get/describe/auth can-i/api-resources/version.
# Aucun contenu de Secret n'est lu : `get secret` n'est permis qu'avec `-o name`.
# Compatible bash 3.2 (macOS) : pas de tableaux associatifs, pas de mapfile.
#
# Variables d'entrée :
#   CLUSTER_LABEL  (obligatoire) k3d | oke. Étiquette de preuve : un résultat k3d n'est jamais une preuve OKE.
#   KUBE_CONTEXT   (recommandé)  contexte kubectl explicite. Jamais le kubeconfig personnel de Paul.
#   ARGOCD_NS      (défaut argocd)
#   OC_NS          (défaut default) namespace OpenChoreo des Project/Component/ReleaseBinding.
set -uo pipefail

: "${CLUSTER_LABEL:?CLUSTER_LABEL=k3d|oke obligatoire (étiquette de preuve)}"
case "$CLUSTER_LABEL" in k3d|oke) ;; *) echo "CLUSTER_LABEL invalide : $CLUSTER_LABEL" >&2; exit 2 ;; esac
ARGOCD_NS="${ARGOCD_NS:-argocd}"
OC_NS="${OC_NS:-default}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

N_PASS=0; N_FAIL=0; N_NT=0; N_BLOCKED=0

# k : kubectl en lecture seule, contexte explicite.
k() {
  case "${1:-}" in
    get|describe|api-resources|version) ;;
    auth) [ "${2:-}" = "can-i" ] || { echo "refus : seul 'auth can-i' est permis" >&2; return 2; } ;;
    *) echo "refus : verbe kubectl '${1:-}' interdit (vérifications en lecture seule)" >&2; return 2 ;;
  esac
  local a is_secret=0 has_name=0
  for a in "$@"; do
    case "$a" in secret|secrets|secret/*|secrets/*) is_secret=1 ;; esac
    case "$a" in name|-oname|--output=name) has_name=1 ;; esac
  done
  if [ "$is_secret" = 1 ] && [ "$1" != "auth" ] && [ "$has_name" = 0 ]; then
    echo "refus : lecture d'un Secret autrement que par '-o name' interdite" >&2; return 2
  fi
  if [ -n "${KUBE_CONTEXT:-}" ]; then kubectl --context "$KUBE_CONTEXT" "$@"; else kubectl "$@"; fi
}

record() { # record STATUS ID MESSAGE
  local st="$1" id="$2"; shift 2
  case "$st" in
    PASS) N_PASS=$((N_PASS+1)) ;; FAIL) N_FAIL=$((N_FAIL+1)) ;;
    NOT_TESTED) N_NT=$((N_NT+1)) ;; BLOCKED) N_BLOCKED=$((N_BLOCKED+1)) ;; INFO) ;;
  esac
  printf '%-10s %-6s %s\n' "$st" "$id" "$*"
}

# expect ID "message" valeur_obtenue valeur_attendue
expect() {
  if [ "$3" = "$4" ]; then record PASS "$1" "$2 (=$3)"; else record FAIL "$1" "$2 (obtenu '$3', attendu '$4')"; fi
}

header() { # header APP ENV ARCHETYPE (omis si GP_NESTED=1)
  [ "${GP_NESTED:-0}" = 1 ] && return 0
  local ctx sha
  ctx="${KUBE_CONTEXT:-$(kubectl config current-context 2>/dev/null || echo inconnu)}"
  sha="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo inconnu)"
  echo "# evidence golden-path v1"
  echo "date_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "cluster: $CLUSTER_LABEL"
  echo "kube_context: $ctx"
  echo "git_head: $sha"
  echo "app: $1"
  echo "environment: $2"
  echo "archetype: $3"
  echo "---"
}

finish() { # code : 0 tout PASS ; 1 au moins un FAIL ; 3 aucun FAIL mais BLOCKED/NOT_TESTED
  if [ "${GP_NESTED:-0}" = 1 ]; then  # appelé par run-all.sh : il agrège lui-même
    [ "$N_FAIL" -gt 0 ] && return 1; [ $((N_NT + N_BLOCKED)) -gt 0 ] && return 3; return 0
  fi
  echo "---"
  echo "summary: PASS=$N_PASS FAIL=$N_FAIL NOT_TESTED=$N_NT BLOCKED=$N_BLOCKED"
  if [ "$N_FAIL" -gt 0 ]; then echo "verdict: FAIL"; return 1; fi
  if [ $((N_NT + N_BLOCKED)) -gt 0 ]; then echo "verdict: PARTIAL"; return 3; fi
  echo "verdict: PASS"; return 0
}

cond() { # cond KIND NAME NAMESPACE TYPE -> status de la condition
  k get "$1" "$2" -n "$3" -o jsonpath="{.status.conditions[?(@.type==\"$4\")].status}" 2>/dev/null
}

has_crd() { k get crd "$1" -o name >/dev/null 2>&1; }

# Namespace de cellule data plane d'une app (dp-<ns>-<projet>-<env>-<hash>) [S : nommage à confirmer sur k3d].
cell_ns() { # cell_ns APP ENV
  local ns
  ns="$(k get ns -l "openchoreo.dev/project=$1,openchoreo.dev/environment=$2" \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [ -z "$ns" ]; then
    ns="$(k get ns -o name 2>/dev/null | sed 's#^namespace/##' | grep -E "^dp-${OC_NS}-$1-$2-" | head -n1 || true)"
  fi
  printf '%s' "$ns"
}

# Champ de apps/<app>/app.yaml (chemin pointé, ex. spec.runtime.port). Vide si absent.
app_field() { # app_field APP CHEMIN
  python3 - "$REPO_ROOT/apps/$1/app.yaml" "$2" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
for part in sys.argv[2].split("."):
    if isinstance(d, dict) and part in d:
        d = d[part]
    else:
        d = None
        break
if d is None:
    print("")
elif isinstance(d, bool):
    print("true" if d else "false")
elif isinstance(d, list):
    print(" ".join(str(x) for x in d))
elif isinstance(d, dict):
    print("present")
else:
    print(d)
PY
}
