#!/usr/bin/env bash
# common.sh : fonctions communes aux verifications whoami sur OKE. Ne pas executer seul : source depuis
# verify-http.sh, verify-change.sh, verify-rollback.sh, selftest.sh.
#
# GARANTIES (lecture seule) :
#   - kubeconfig UNIQUEMENT depuis $KUBECONFIG (jamais ~/.kube/config par defaut) ;
#   - contexte refuse s'il ne matche pas CONTEXT_RE (defaut « oracle-a1 ») ou s'il vaut admin@homeops ;
#   - verbes kubectl limites a get, version, api-resources, auth can-i ; aucun apply/patch/delete/exec/create ;
#   - aucun Secret lu (la fonction k refuse tout argument contenant « secret ») ;
#   - HTTP uniquement par tunnel `kubectl port-forward` vers le Service ClusterIP, sur 127.0.0.1 : aucune
#     exposition, aucun pod cree, aucun LoadBalancer ;
#   - le corps HTTP n'est jamais imprime, seuls des codes et des comparaisons sont journalises.
#
# Sortie : lignes horodatees « <UTC> <STATUT> <ID> <message> » ; STATUT = PASS | FAIL | NOT_TESTED | BLOCKED | INFO.

# Variables globales lues par les scripts appelants (LIVE_RELEASE, LAST_OUT, LAST_RC) : non utilisees ici.
# shellcheck disable=SC2034
set -uo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$COMMON_DIR/../.." && pwd)"

WHOAMI_APP="${WHOAMI_APP:-whoami}"
WHOAMI_ENV="${WHOAMI_ENV:-production}"
OC_NS="${OC_NS:-default}"                 # namespace des Project/Component/ReleaseBinding OpenChoreo
ARGOCD_NS="${ARGOCD_NS:-lab-argocd}"   # namespace des Applications Argo CD du labo (platform/install/argocd)
ARGO_APP="${ARGO_APP:-lab-apps}"         # Application Argo CD qui synchronise generated/
CONTEXT_RE="${CONTEXT_RE:-oracle-a1}"    # le contexte OKE doit matcher ; jamais admin@homeops
WHOAMI_STATE_DIR="${WHOAMI_STATE_DIR:-$HOME/.local/state/golden-path-whoami}"   # hors depot (pas de trace Git)
WHOAMI_IMAGE_PORT="${WHOAMI_IMAGE_PORT:-8080}"

N_PASS=0; N_FAIL=0; N_NT=0; N_BLOCKED=0
LIVE_RELEASE=""

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

rec() { # rec STATUT ID message...
  local st="$1" id="$2"; shift 2
  case "$st" in
    PASS) N_PASS=$((N_PASS+1)) ;;
    FAIL) N_FAIL=$((N_FAIL+1)) ;;
    NOT_TESTED) N_NT=$((N_NT+1)) ;;
    BLOCKED) N_BLOCKED=$((N_BLOCKED+1)) ;;
    INFO) ;;
  esac
  printf '%s %-11s %-6s %s\n' "$(ts)" "$st" "$id" "$*"
}

expect() { # expect ID "libelle" obtenu attendu
  if [ "$3" = "$4" ]; then rec PASS "$1" "$2 (=$3)"; else rec FAIL "$1" "$2 (obtenu '$3', attendu '$4')"; fi
}

print_header() { # entete d'evidence
  echo "# evidence golden-path-whoami v1 (OKE, lecture seule)"
  echo "date_utc: $(ts)"
  echo "cluster: oke"
  echo "app: $WHOAMI_APP"
  echo "environment: $WHOAMI_ENV"
  echo "git_head: $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo inconnu)"
  echo "script: ${0##*/}"
  echo "---"
}

verdict() { # calcule le verdict final ; code 0 PASS, 1 FAIL, 3 PARTIAL
  echo "---"
  echo "summary: PASS=$N_PASS FAIL=$N_FAIL NOT_TESTED=$N_NT BLOCKED=$N_BLOCKED"
  if [ "$N_FAIL" -gt 0 ]; then echo "verdict: FAIL"; return 1; fi
  if [ $((N_NT + N_BLOCKED)) -gt 0 ]; then echo "verdict: PARTIAL"; return 3; fi
  echo "verdict: PASS"; return 0
}

# k : kubectl en lecture seule, toujours via $KUBECONFIG.
k() {
  local verb="${1:-}" a
  case "$verb" in
    get|version|api-resources) ;;
    auth) [ "${2:-}" = "can-i" ] || { echo "refus : 'auth' autre que can-i" >&2; return 2; } ;;
    *) echo "refus : verbe kubectl '$verb' interdit (lecture seule)" >&2; return 2 ;;
  esac
  for a in "$@"; do
    case "$a" in
      *ecret*) if [ "$verb" != auth ]; then echo "refus : lecture de Secret interdite" >&2; return 2; fi ;;
    esac
  done
  kubectl "$@"
}

preflight() { # preflight : KUBECONFIG explicite, contexte autorise. Retour 0 ou 2 (BLOCKED).
  if [ -z "${KUBECONFIG:-}" ]; then
    rec BLOCKED P0 "KUBECONFIG non defini : aucun repli sur ~/.kube/config"; return 2
  fi
  if [ ! -r "$KUBECONFIG" ]; then
    rec BLOCKED P0 "KUBECONFIG illisible"; return 2
  fi
  local ctx
  ctx="$(kubectl config current-context 2>/dev/null || true)"   # lecture locale du kubeconfig, aucun appel reseau
  if [ -z "$ctx" ] || [ "$ctx" = "admin@homeops" ]; then
    rec BLOCKED P0 "contexte vide ou non autorise (admin@homeops interdit)"; return 2
  fi
  if ! printf '%s' "$ctx" | grep -Eq -- "$CONTEXT_RE"; then
    rec BLOCKED P0 "contexte ne matche pas CONTEXT_RE='$CONTEXT_RE' (nom non journalise)"; return 2
  fi
  rec INFO P0 "contexte autorise (matche CONTEXT_RE), kubeconfig depuis KUBECONFIG"
  if ! k version --request-timeout=10s >/dev/null 2>&1; then
    rec BLOCKED P0 "API server injoignable (session bastion fermee ? voir docs/GOLDEN-PATH-WHOAMI.md)"; return 2
  fi
  rec PASS P0 "API server joignable (kubectl version)"
  return 0
}

cell_ns() { # namespace de cellule dp-* de whoami (label OpenChoreo, sinon nommage dp-<ns>-<app>-<env>-)
  local ns
  ns="$(k get ns -l "openchoreo.dev/project=$WHOAMI_APP,openchoreo.dev/environment=$WHOAMI_ENV" \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [ -z "$ns" ]; then
    ns="$(k get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null \
          | grep -E "^dp-${OC_NS}-${WHOAMI_APP}-${WHOAMI_ENV}-" | head -n1 || true)"
  fi
  printf '%s' "$ns"
}

git_blob() { # git_blob REV CHEMIN : blob SHA (vide si absent)
  git -C "$REPO_ROOT" rev-parse -q --verify "$1:$2" 2>/dev/null || true
}

git_show() { # git_show REV CHEMIN : contenu (vide si absent)
  git -C "$REPO_ROOT" show "$1:$2" 2>/dev/null || true
}

release_of_rev() { # release_of_rev REV : releaseName de la ReleaseBinding whoami-production a ce commit
  git_show "$1" "generated/namespaces/default/projects/$WHOAMI_APP/components/$WHOAMI_APP/release-bindings/$WHOAMI_APP-$WHOAMI_ENV.yaml" \
    | sed -n 's/^  releaseName: //p' | tr -d '\r'
}

check_gitops() { # check_gitops REVISION_ATTENDUE RELEASE_ATTENDUE  (arguments vides = pas de contrainte)
  local want_rev="${1:-}" want_rel="${2:-}" st rev rel ad c v
  if ! k get crd applications.argoproj.io -o name >/dev/null 2>&1; then
    rec BLOCKED G2 "CRD applications.argoproj.io absente : Argo CD non installe"; return 0
  fi
  st="$(k get applications.argoproj.io "$ARGO_APP" -n "$ARGOCD_NS" -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)"
  expect G2 "Argo $ARGO_APP Synced/Healthy" "$st" "Synced/Healthy"
  rev="$(k get applications.argoproj.io "$ARGO_APP" -n "$ARGOCD_NS" -o jsonpath='{.status.sync.revision}' 2>/dev/null || true)"
  if [ -n "$want_rev" ]; then expect G2 "Argo $ARGO_APP revision = commit attendu" "$rev" "$want_rev"
  else rec INFO G2 "Argo revision observee : ${rev:-inconnue}"; fi

  rel="$(k get releasebindings.openchoreo.dev "$WHOAMI_APP-$WHOAMI_ENV" -n "$OC_NS" -o jsonpath='{.spec.releaseName}' 2>/dev/null || true)"
  LIVE_RELEASE="$rel"
  if [ -n "$want_rel" ]; then expect G4 "ReleaseBinding releaseName = release attendue" "$rel" "$want_rel"
  else rec INFO G4 "ReleaseBinding releaseName observe : ${rel:-absent}"; fi
  for c in Ready ReleaseSynced ResourcesReady; do
    v="$(k get releasebindings.openchoreo.dev "$WHOAMI_APP-$WHOAMI_ENV" -n "$OC_NS" -o jsonpath="{.status.conditions[?(@.type==\"$c\")].status}" 2>/dev/null || true)"
    expect G5 "ReleaseBinding $c" "$v" "True"
  done
  if [ -n "$rel" ]; then
    if k get componentreleases.openchoreo.dev "$rel" -n "$OC_NS" -o name >/dev/null 2>&1; then
      rec PASS G4 "ComponentRelease $rel presente"
    else
      rec FAIL G4 "ComponentRelease $rel absente"
    fi
  fi
  ad="$(k get components.openchoreo.dev "$WHOAMI_APP" -n "$OC_NS" -o jsonpath='{.spec.autoDeploy}' 2>/dev/null || true)"
  expect G3 "Component autoDeploy" "${ad:-absent}" "false"
  v="$(k get projectreleasebindings.openchoreo.dev "$WHOAMI_APP-$WHOAMI_ENV" -n "$OC_NS" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
  expect G5 "ProjectReleaseBinding Ready" "$v" "True"
}

check_runtime() { # check_runtime NS EXPECT_NAME NAME_ABSENT : deployment, pods, securite, service
  local ns="$1" want_name="${2:-}" absent="${3:-}" dep ready desired pods_ready restarts v env_name
  dep="$(k get deploy -n "$ns" -l "openchoreo.dev/component=$WHOAMI_APP" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [ -z "$dep" ]; then rec FAIL W4 "aucun Deployment (label component=$WHOAMI_APP) dans $ns"; return 0; fi
  ready="$(k get deploy "$dep" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  desired="$(k get deploy "$dep" -n "$ns" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
  if [ -n "$ready" ] && [ "$ready" = "$desired" ] && [ "$desired" -ge 1 ] 2>/dev/null; then
    rec PASS W4 "Deployment $dep disponible ($ready/$desired)"
  else
    rec FAIL W4 "Deployment $dep non disponible (ready='${ready:-0}', desired='${desired:-?}')"
  fi
  pods_ready="$(k get pods -n "$ns" -l "openchoreo.dev/component=$WHOAMI_APP" \
    -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c '^True$' || true)"
  if [ "${pods_ready:-0}" -ge 1 ]; then rec PASS W4 "pods Ready : $pods_ready"; else rec FAIL W4 "aucun pod Ready"; fi
  restarts="$(k get pods -n "$ns" -l "openchoreo.dev/component=$WHOAMI_APP" \
    -o jsonpath='{range .items[*].status.containerStatuses[*]}{.restartCount}{"\n"}{end}' 2>/dev/null | awk '{s+=$1} END {print s+0}')"
  if [ "$restarts" -lt 3 ]; then rec PASS W4 "redemarrages cumules = $restarts (< 3)"; else rec FAIL W4 "redemarrages cumules = $restarts"; fi

  expect W5 "runAsNonRoot" "$(k get deploy "$dep" -n "$ns" -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}')" "true"
  expect W5 "automountServiceAccountToken" "$(k get deploy "$dep" -n "$ns" -o jsonpath='{.spec.template.spec.automountServiceAccountToken}')" "false"
  expect W5 "allowPrivilegeEscalation (conteneur)" "$(k get deploy "$dep" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}')" "false"
  expect W5 "readOnlyRootFilesystem (conteneur)" "$(k get deploy "$dep" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}')" "true"

  # Variable d'environnement : presente avec la valeur attendue, ou absente pour la base.
  env_name="$(k get deploy "$dep" -n "$ns" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="WHOAMI_NAME")].value}' 2>/dev/null || true)"
  if [ -n "$want_name" ]; then
    expect W6 "WHOAMI_NAME dans le pod" "$env_name" "$want_name"
  elif [ -n "$absent" ]; then
    if [ "$env_name" = "$absent" ]; then rec FAIL W6 "WHOAMI_NAME encore present dans le pod ($absent)"; else rec PASS W6 "WHOAMI_NAME absent du pod (retour a la base)"; fi
  fi

  expect W7 "Service $WHOAMI_APP type" "$(k get svc "$WHOAMI_APP" -n "$ns" -o jsonpath='{.spec.type}' 2>/dev/null || true)" "ClusterIP"
  v="$(k get svc "$WHOAMI_APP" -n "$ns" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)"
  expect W7 "Service $WHOAMI_APP port" "$v" "$WHOAMI_IMAGE_PORT"
}

check_scope() { # check_scope NS : rien d'autre que whoami n'a ete cree (PVC, LoadBalancer, NodePort, route publique, base)
  local ns="$1" n lines
  n="$(k get pvc -n "$ns" -o name 2>/dev/null | wc -l | tr -d ' ')"
  expect S1 "PVC dans la cellule" "$n" "0"
  n="$(k get svc -n "$ns" -o jsonpath='{range .items[*]}{.spec.type}{"\n"}{end}' 2>/dev/null | grep -cE '^(LoadBalancer|NodePort)$' || true)"
  expect S2 "Service LoadBalancer/NodePort dans la cellule" "$n" "0"
  n="$(k get httproutes.gateway.networking.k8s.io -n "$ns" -l openchoreo.dev/endpoint-visibility=external -o name 2>/dev/null | wc -l | tr -d ' ')"
  expect S3 "HTTPRoute d'endpoint external (exposition publique)" "$n" "0"
  n="$(k get ingress -n "$ns" -o name 2>/dev/null | wc -l | tr -d ' ')"
  expect S3 "Ingress dans la cellule" "$n" "0"
  # Tout le cluster, restreint aux objets lies a whoami (cellule dp-<ns>-whoami-*, ou nom whoami-*) : 0 LoadBalancer, 0 PVC.
  lines="$(k get svc -A -o jsonpath='{range .items[*]}{.metadata.namespace}|{.metadata.name}|{.spec.type}{"\n"}{end}' 2>/dev/null \
    | awk -F'|' -v ns="$ns" -v oc="$OC_NS" -v app="$WHOAMI_APP" \
        '$3=="LoadBalancer" && ($1==ns || index($1,"dp-" oc "-" app "-")==1 || index($2,app)==1) {n++} END {print n+0}')"
  expect S4 "Services LoadBalancer lies a whoami (tout namespace)" "$lines" "0"
  lines="$(k get pvc -A -o jsonpath='{range .items[*]}{.metadata.namespace}|{.metadata.name}{"\n"}{end}' 2>/dev/null \
    | awk -F'|' -v ns="$ns" -v oc="$OC_NS" -v app="$WHOAMI_APP" \
        '($1==ns || index($1,"dp-" oc "-" app "-")==1 || index($2,app)==1) {n++} END {print n+0}')"
  expect S4 "PVC lies a whoami (tout namespace)" "$lines" "0"
  # Pas de ressource de base (Resource OpenChoreo) pour whoami : l'app est stateless.
  if k get crd resources.openchoreo.dev -o name >/dev/null 2>&1; then
    n="$(k get resources.openchoreo.dev -n "$OC_NS" -o name 2>/dev/null | grep -c "$WHOAMI_APP" || true)"
    expect S5 "Resource OpenChoreo (base) pour whoami" "$n" "0"
  else
    rec NOT_TESTED S5 "CRD resources.openchoreo.dev absente : contrôle base non executable"
  fi
}

wait_converge() { # wait_converge TIMEOUT_S INTERVAL_S SCRIPT : relance SCRIPT jusqu'a rc 0 ou 3 (EXPECT_* herites de l'environnement)
  local deadline rc out
  deadline=$(( $(date +%s) + $1 ))
  while :; do
    out="$(bash "$3" 2>&1)"; rc=$?
    LAST_OUT="$out"; LAST_RC=$rc
    if [ "$rc" = 0 ] || [ "$rc" = 3 ]; then return 0; fi
    if [ "$rc" = 2 ]; then return 2; fi
    if [ "$(date +%s)" -ge "$deadline" ]; then return 1; fi
    sleep "$2"
  done
}

probe_http() { # probe_http NS EXPECT_NAME NAME_ABSENT : /health et / via tunnel port-forward local (aucune exposition)
  local ns="$1" want="${2:-}" absent="${3:-}" port pf_pid pf_log body code i ok
  port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
  pf_log="$(mktemp)"
  body="$(mktemp)"
  kubectl -n "$ns" port-forward "svc/$WHOAMI_APP" "$port:$WHOAMI_IMAGE_PORT" --address 127.0.0.1 >"$pf_log" 2>&1 &
  pf_pid=$!
  ok=0
  for _try in $(seq 1 20); do
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:$port/health" || true)"
    if [ "$code" = "200" ]; then ok=1; break; fi
    sleep 1
  done
  if [ "$ok" = 1 ]; then
    expect H1 "GET /health via tunnel local (tunnel, pas d'exposition)" "$code" "200"
    code="$(curl -s -o "$body" -w '%{http_code}' --max-time 5 "http://127.0.0.1:$port/" || true)"
    expect H2 "GET / via tunnel local" "$code" "200"
    if grep -qF 'Hostname:' "$body"; then rec PASS H2 "reponse whoami reconnue (ligne Hostname presente)"; else rec FAIL H2 "reponse non whoami"; fi
    if [ -n "$want" ]; then
      if grep -qF "Name: $want" "$body"; then
        rec PASS H3 "la reponse HTTP reflete la valeur attendue (Name: $want)"
      else
        rec FAIL H3 "la reponse HTTP ne contient pas 'Name: $want'"
      fi
    fi
    if [ -n "$absent" ]; then
      if grep -qF "Name: $absent" "$body"; then rec FAIL H4 "la reponse contient encore 'Name: $absent'"; else rec PASS H4 "la reponse ne contient plus 'Name: $absent'"; fi
    fi
  else
    rec FAIL H1 "pas de 200 sur /health via port-forward (dernier code '${code:-vide}')"
    sed 's/^/  pf: /' "$pf_log" | head -n 5
  fi
  kill "$pf_pid" 2>/dev/null || true
  wait "$pf_pid" 2>/dev/null || true
  rm -f "$pf_log" "$body"
}
