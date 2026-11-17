#!/usr/bin/env bash
# Flux A2 : preuve NÉGATIVE sur un VRAI Argo CD (chart argo-cd 10.3.3 / v3.5.1 épinglés, values du dépôt) que
# les AppProject de platform/install/argocd/ bornent ce qu'un commit peut faire synchroniser. Chaque test :
# un commit « malveillant » dans un dépôt Git de TEST servi dans le cluster (git daemon), une synchro réelle,
# puis l'observation de l'état Argo (Application, operationState, conditions) ET de l'API server.
# Étiquette des résultats : k3d (jamais OKE). Docs : docs/ARGO-ESCALATION.md ; résultats : RESULTS.md.
#
# Usage : KUBECONFIG=<kubeconfig d'un k3d JETABLE> tests/argo-escalation/run.sh [all|setup|tests|cleanup]
# Prérequis : helm, kubectl, git, jq, yq, curl, shasum ; Internet (GitHub, quay.io) pour le chart Argo, les CRD
# OpenChoreo (commit épinglé) et le chart CNPG (CRD seulement), tous vérifiés par sha256/commit.
# Seule écart au dépôt réel : l'URL GitHub est remplacée par l'URL du dépôt de test, PARTOUT (sourceRepos
# des projets, repoURL des Application). Aucune garde n'est désactivée ; aucun push vers GitHub.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
A="$ROOT/platform/install/argocd"
EVID="$HERE/evidence"
WORK="${ARGO_ESC_WORK:-$(mktemp -d "${TMPDIR:-/tmp}/argo-esc.XXXXXX")}"
W="$WORK/repo"
GH="https://github.com/platform-zephyr/openchoreo-lab"
IN_REPO="git://lab-gitsrv.lab-gitsrv.svc.cluster.local:9418/repo.git"
PF_PORT="${ARGO_ESC_PF_PORT:-19419}"
NS=lab-argocd
# CRD OpenChoreo v1.3.3 : même commit que la CI (OPENCHOREO_COMMIT de .github/workflows/ci.yaml).
OC_COMMIT=5336791f421b3efb79603b09b8ce0c98e8ef077d
# shellcheck source=../../platform/install/versions.env
source "$ROOT/platform/install/versions.env"
CNPG_URL="https://github.com/cloudnative-pg/charts/releases/download/cloudnative-pg-v${CNPG_VERSION}/cloudnative-pg-${CNPG_VERSION}.tgz"
ARGO_URL="https://github.com/argoproj/argo-helm/releases/download/argo-cd-${ARGOCD_VERSION}/argo-cd-${ARGOCD_VERSION}.tgz"

k() { kubectl "$@"; }
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "[$(date -u +%T)] $*" >&2; }

preflight() {
  [[ "${KUBECONFIG:-}" == *oke-access* ]] && { echo "REFUS : kubeconfig OKE" >&2; exit 2; }
  local ctx; ctx="$(k config current-context)"
  [[ "$ctx" == k3d-* ]] || { echo "REFUS : contexte $ctx (k3d-* jetable attendu)" >&2; exit 2; }
  [[ "$ctx" != k3d-openchoreo ]] || { echo "REFUS : k3d partagé openchoreo" >&2; exit 2; }
  mkdir -p "$EVID" "$WORK"
  LABEL="k3d $ctx, $(k version -o json | jq -r .serverVersion.gitVersion)"
}

rec() { # rec ID PASS|FAIL|NOT_TESTED "détail"
  printf '%s\t%s\t%s\t%s\n' "$(ts)" "$1" "$2" "$3" >>"$EVID/results.tsv"
  log "RESULT $1 $2 : $3"
}

fetch() { # fetch URL SHA256 DEST : téléchargement vérifié
  [[ -f "$3" ]] || curl -fsSL -o "$3" "$1"
  echo "$2  $3" | shasum -a 256 -c - >/dev/null || { echo "sha256 invalide : $3" >&2; exit 3; }
}

# --- installation ------------------------------------------------------------------------------------
setup() {
  local dl="$WORK/dl"; mkdir -p "$dl"
  fetch "$ARGO_URL" "$ARGOCD_TGZ_SHA256" "$dl/argo-cd.tgz"
  fetch "$CNPG_URL" "$CNPG_TGZ_SHA256" "$dl/cnpg.tgz"
  if [[ ! -d "$dl/oc/config/crd/bases" ]]; then
    git init -q "$dl/oc" && git -C "$dl/oc" remote add origin https://github.com/openchoreo/openchoreo
    git -C "$dl/oc" sparse-checkout set config/crd/bases
    git -C "$dl/oc" fetch -q --depth 1 origin "$OC_COMMIT" && git -C "$dl/oc" checkout -q FETCH_HEAD
  fi
  [[ "$(git -C "$dl/oc" rev-parse HEAD)" == "$OC_COMMIT" ]] || { echo "commit OpenChoreo inattendu" >&2; exit 3; }
  log "CRD OpenChoreo ($OC_COMMIT) et CNPG ($CNPG_VERSION, CRD seulement ; aucun opérateur)"
  k apply --server-side -f "$dl/oc/config/crd/bases" >/dev/null
  helm template cnpg "$dl/cnpg.tgz" -n lab-cnpg |
    yq 'select(.kind == "CustomResourceDefinition" and .spec.group == "postgresql.cnpg.io")' |
    k apply --server-side -f - >/dev/null

  log "Argo CD $ARGOCD_VERSION (values du dépôt)"
  k create namespace "$NS" --dry-run=client -o yaml | k apply -f - >/dev/null
  helm upgrade --install argocd "$dl/argo-cd.tgz" -n "$NS" -f "$ROOT/platform/install/values/argocd.yaml" \
    --wait --timeout 10m >/dev/null

  log "serveur Git de test"
  k apply -f "$HERE/git-server.yaml" >/dev/null
  k -n lab-gitsrv rollout status deploy/lab-gitsrv --timeout=180s >/dev/null
  pf_start

  log "dépôt de test : copie de platform/, generated/, apps/ (URL GitHub -> $IN_REPO)"
  rm -rf "$W"; mkdir -p "$W"
  cp -R "$ROOT/platform" "$ROOT/generated" "$ROOT/apps" "$W/"
  subst_urls "$W"
  git -C "$W" init -q -b main
  git -C "$W" -c user.name=lab -c user.email=lab@example.invalid add -A
  git -C "$W" -c user.name=lab -c user.email=lab@example.invalid commit -qm "base : copie du dépôt"
  git -C "$W" remote add origin "git://127.0.0.1:$PF_PORT/repo.git"
  git -C "$W" push -qf origin main

  log "bootstrap : projet default verrouillé, projets lab-*, Application racine (comme install.sh --step 11)"
  k -n "$NS" wait --for=create appprojects.argoproj.io/default --timeout=120s >/dev/null
  local bs="$WORK/bootstrap"; rm -rf "$bs"; mkdir -p "$bs"
  cp "$A"/project-default-locked.yaml "$A"/project-lab.yaml "$A"/root-application.yaml "$bs/"
  subst_urls "$bs"
  k apply --server-side --force-conflicts -f "$bs/project-default-locked.yaml" >/dev/null
  k apply --server-side -f "$bs/project-lab.yaml" >/dev/null
  k apply --server-side -f "$bs/root-application.yaml" >/dev/null
  wait_rev lab-root "$(head_sha)" 180 || true
  # lab-platform : synchro MANUELLE forcée (fenêtre deny) ; première synchro = geste opérateur, comme sur OKE.
  sync_manual lab-platform "$(head_sha)"
  k -n lab-pg wait --for=create clusters.postgresql.cnpg.io/lab-pg --timeout=180s >/dev/null
  # Aucun opérateur CNPG sur ce cluster : le contrôle de santé Lua d'Argo échoue sur un Cluster sans
  # status (ComparisonError, synchro « Running » sans fin). Status SIMULÉ (sous-ressource status), ce qui
  # ne touche à aucun AppProject ni aucune garde ; consigné dans RESULTS.md.
  k -n lab-pg patch clusters.postgresql.cnpg.io lab-pg --subresource=status --type merge -p \
    '{"status":{"phase":"Cluster in healthy state","phaseReason":"simulé (test A2, aucun opérateur CNPG)","instances":1,"readyInstances":1}}' >/dev/null
  refresh_all
  wait_rev lab-platform "$(head_sha)" 180 || true
  snap BASE lab-root lab-platform lab-apps lab-authz
  k -n "$NS" get appprojects -o json >"$EVID/BASE-appprojects.json"
}

subst_urls() { # remplace l'URL GitHub par celle du dépôt de test dans tous les YAML d'un arbre
  find "$1" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 |
    xargs -0 perl -pi -e "s#\Q$GH\E(\.git)?#$IN_REPO#g"
}

pf_start() {
  pkill -f "port-forward svc/lab-gitsrv $PF_PORT:9418" 2>/dev/null || true
  k -n lab-gitsrv port-forward svc/lab-gitsrv "$PF_PORT:9418" >/dev/null 2>&1 &
  PF_PID=$!
  trap 'kill "$PF_PID" 2>/dev/null || true' EXIT
  sleep 3
}

# --- primitives de test ------------------------------------------------------------------------------
head_sha() { git -C "$W" rev-parse HEAD; }
commit() { # commit "message" : commit + push de l'arbre de test, puis refresh des Application
  git -C "$W" -c user.name=attacker -c user.email=attacker@example.invalid add -A
  git -C "$W" -c user.name=attacker -c user.email=attacker@example.invalid commit -qm "$1"
  git -C "$W" push -q origin main
  refresh_all
}
revert() { # annule le dernier commit (état propre pour le test suivant)
  git -C "$W" -c user.name=lab -c user.email=lab@example.invalid revert --no-edit HEAD >/dev/null
  git -C "$W" push -q origin main
  refresh_all
}
refresh_all() {
  local a
  for a in $(k -n "$NS" get applications.argoproj.io -o name); do
    k -n "$NS" annotate "$a" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
  done
}
no_auto() { # no_auto APP SHA SECONDES : vrai si AUCUNE opération sur SHA pendant la durée (refresh forcés)
  local s; s=$(date +%s)
  while (( $(date +%s) - s < $3 )); do
    k -n "$NS" annotate application "$1" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
    sleep 15
    [[ "$(op_rev "$1")" == "$2" ]] && return 1
  done
  return 0
}
plat_revert() { revert; sync_manual lab-platform "$(head_sha)"; wait_rev lab-platform "$(head_sha)" 240 || true; }
app_json() { k -n "$NS" get application "$1" -o json 2>/dev/null; }
op_rev() { app_json "$1" | jq -r '.status.operationState.operation.sync.revision // ""'; }
op_phase() { app_json "$1" | jq -r '.status.operationState.phase // ""'; }
wait_rev() { # wait_rev APP SHA TIMEOUT : attend une opération TERMINÉE sur SHA (auto ou manuelle)
  local s; s=$(date +%s)
  while :; do
    if [[ "$(op_rev "$1")" == "$2" ]] && [[ "$(op_phase "$1")" =~ ^(Succeeded|Failed|Error)$ ]]; then return 0; fi
    (( $(date +%s) - s >= $3 )) && { log "délai dépassé : $1 @ ${2:0:7} (op $(op_rev "$1" | cut -c1-7) $(op_phase "$1"))"; return 1; }
    sleep 3
  done
}
sync_manual() { # sync_manual APP SHA : synchro MANUELLE (geste opérateur) sur une révision donnée
  k -n "$NS" patch application "$1" --type merge -p \
    "{\"operation\":{\"initiatedBy\":{\"username\":\"argo-escalation-test\"},\"sync\":{\"revision\":\"$2\"}}}" >/dev/null
}
snap() { # snap ID APP... : preuve (Application complète + résumé)
  local id="$1"; shift; local a
  for a in "$@"; do
    app_json "$a" >"$EVID/$id-$a.json" || echo '{}' >"$EVID/$id-$a.json"
    jq '{name: .metadata.name, project: .spec.project, sync: .status.sync.status, health: .status.health.status,
         conditions: [.status.conditions[]? | {type, message}],
         operation: {phase: .status.operationState.phase, revision: .status.operationState.operation.sync.revision,
                     initiatedBy: .status.operationState.operation.initiatedBy, message: .status.operationState.message},
         refused: [.status.operationState.syncResult.resources[]? | select(.status != "Synced")
                   | {kind, namespace, name, status, message}]}' "$EVID/$id-$a.json" >"$EVID/$id-$a.summary.json"
  done
}
op_msg() { app_json "$1" | jq -r '[.status.operationState.message // "", (.status.operationState.syncResult.resources[]? | .message // "")] | join(" | ")'; }
absent() { ! k get "$@" >/dev/null 2>&1; }

# --- tests -------------------------------------------------------------------------------------------
G=generated/namespaces/default/projects/whoami
AP=platform/install/argocd/apps

t_pos_apps() { # Témoin : un Component/Workload valide de generated/ est synchronisé par lab-apps.
  local sha; sha="$(head_sha)"; sync_manual lab-apps "$sha"
  wait_rev lab-apps "$sha" 240 || true; snap P-APPS lab-apps
  if [[ "$(op_phase lab-apps)" == Succeeded ]] && k -n default get components.openchoreo.dev whoami >/dev/null 2>&1 \
      && k -n default get workloads.openchoreo.dev -o name | grep -q .; then
    rec P-APPS PASS "lab-apps @${sha:0:7} Succeeded ; Component default/whoami et Workload présents (API)"
  else rec P-APPS FAIL "phase=$(op_phase lab-apps) $(op_msg lab-apps)"; fi
}

t_pos_platform() { # Témoin : changement légitime de platform/ synchronisé par lab-platform (auto).
  yq -i 'with(select(.kind == "ValidatingAdmissionPolicy"); .metadata.annotations."lab.smadja.dev/a2-witness" = "ok")' \
    "$W/platform/policies/vap-cell-pod-hardening.yaml"
  commit "P-PLATFORM : annotation légitime sur la VAP du labo"
  local sha v0 v auto=no; sha="$(head_sha)"
  vap_annot() { k get validatingadmissionpolicy lab-cell-pod-hardening -o jsonpath='{.metadata.annotations.lab\.smadja\.dev/a2-witness}' 2>/dev/null || true; }
  # 1) merge sur platform/** : AUCUNE synchro automatique (fenêtre deny du projet lab-platform).
  if no_auto lab-platform "$sha" 90; then v0="$(vap_annot)"; [[ -z "$v0" ]] && auto=bloquee; fi
  snap N9-auto lab-platform
  if [[ $auto == bloquee && "$(app_json lab-platform | jq -r .status.sync.status)" == OutOfSync ]]; then
    rec N9-platform-merge-sans-sync-auto PASS "commit @${sha:0:7} sur platform/policies : 90 s, refresh forcés, aucune opération ; lab-platform OutOfSync ; VAP inchangée (API)"
  else rec N9-platform-merge-sans-sync-auto FAIL "op=$(op_rev lab-platform | cut -c1-7) annot=$(vap_annot)"; fi
  # 2) témoin : la synchro MANUELLE (geste opérateur) applique le changement légitime.
  sync_manual lab-platform "$sha"; wait_rev lab-platform "$sha" 240 || true; snap P-PLATFORM lab-platform
  v="$(vap_annot)"
  if [[ "$(op_phase lab-platform)" == Succeeded && "$v" == ok ]]; then
    rec P-PLATFORM PASS "lab-platform @${sha:0:7} Succeeded (synchro manuelle) ; annotation présente sur VAP lab-cell-pod-hardening"
  else rec P-PLATFORM FAIL "phase=$(op_phase lab-platform) annot=$v $(op_msg lab-platform)"; fi
  plat_revert
}

t_n1_default() { # Application enfant (apps/) project: default, qui pointe sur un ClusterRoleBinding cluster-admin.
  mkdir -p "$W/platform/evil-n1"
  cat >"$W/platform/evil-n1/crb.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: lab-n1-evil}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: cluster-admin}
subjects: [{kind: ServiceAccount, name: default, namespace: default}]
EOF
  cat >"$W/$AP/n1-evil.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: n1-evil, namespace: lab-argocd}
spec:
  project: default
  source: {repoURL: $IN_REPO, targetRevision: main, path: platform/evil-n1}
  destination: {server: https://kubernetes.default.svc, namespace: default}
  syncPolicy: {automated: {prune: true, selfHeal: true}}
EOF
  commit "N1 : Application enfant project default -> ClusterRoleBinding cluster-admin"
  local sha; sha="$(head_sha)"; wait_rev lab-root "$sha" 180 || true
  sleep 45; refresh_all; sleep 20
  snap N1 lab-root n1-evil
  local cond; cond="$(app_json n1-evil | jq -r '[.status.conditions[]? | "\(.type): \(.message)"] | join(" | ")')"
  if absent clusterrolebinding lab-n1-evil && [[ "$cond" == *"not permitted"* || "$cond" == *"InvalidSpec"* ]]; then
    rec N1-project-default PASS "Application créée par lab-root (kind permis) mais REFUSÉE par Argo : $cond ; CRB lab-n1-evil absent (API)"
  else rec N1-project-default FAIL "cond=$cond ; CRB présent ? $(k get clusterrolebinding lab-n1-evil -o name 2>&1)"; fi
  revert; wait_rev lab-root "$(head_sha)" 180 || true
  k -n "$NS" delete application n1-evil --wait=false >/dev/null 2>&1 || true  # prune=false sur lab-root
}

t_n2a_app_in_platform() { # Application hors apps/ : dans platform/policies (synchronisé par lab-platform).
  cat >"$W/platform/policies/zz-n2.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: n2-sneaky, namespace: lab-argocd}
spec:
  project: lab-platform
  source: {repoURL: $IN_REPO, targetRevision: main, path: platform/policies}
  destination: {server: https://kubernetes.default.svc, namespace: default}
EOF
  commit "N2a : Application glissée dans platform/policies"
  local sha; sha="$(head_sha)"; sync_manual lab-platform "$sha"; wait_rev lab-platform "$sha" 240 || true; snap N2a lab-platform
  local m; m="$(op_msg lab-platform)"
  if absent -n "$NS" application n2-sneaky && [[ "$(op_phase lab-platform)" != Succeeded && "$m" == *"not permitted"* ]]; then
    rec N2a-app-hors-apps-platform PASS "lab-platform $(op_phase lab-platform) : ${m:0:220} ; Application n2-sneaky absente (API)"
  else rec N2a-app-hors-apps-platform FAIL "phase=$(op_phase lab-platform) $m"; fi
  plat_revert
}

gen_case() { # gen_case ID "description" FICHIER CHECK... : manifest malveillant dans generated/, synchro lab-apps
  local id="$1" desc="$2"; shift 2
  commit "$id : $desc"
  local sha; sha="$(head_sha)"; sync_manual lab-apps "$sha"; wait_rev lab-apps "$sha" 180 || true; snap "$id" lab-apps
  local m ph; m="$(op_msg lab-apps)"; ph="$(op_phase lab-apps)"
  if [[ "$ph" != Succeeded && "$m" == *"not permitted"* ]] && "$@"; then
    rec "$id" PASS "lab-apps $ph : ${m:0:240} ; API inchangée"
  else rec "$id" FAIL "phase=$ph $m"; fi
  revert
}

t_generated() {
  local f="$W/$G/zz-evil.yaml" rv_vap rv_ns
  # N2b : Application dans generated/.
  cat >"$f" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: n2b-gen, namespace: lab-argocd}
spec:
  project: lab-platform
  source: {repoURL: $IN_REPO, targetRevision: main, path: platform/policies}
  destination: {server: https://kubernetes.default.svc, namespace: default}
EOF
  gen_case N2b-application-generated "Application dans generated/" absent -n "$NS" application n2b-gen

  cat >"$f" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: {name: lab-n5-crb}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: cluster-admin}
subjects: [{kind: ServiceAccount, name: default, namespace: default}]
EOF
  gen_case N5a-clusterrolebinding "ClusterRoleBinding cluster-admin dans generated/" absent clusterrolebinding lab-n5-crb

  rv_ns="$(k get ns kube-system -o jsonpath='{.metadata.resourceVersion}')"
  cat >"$f" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: kube-system
  labels: {pod-security.kubernetes.io/enforce: privileged, lab.smadja.dev/pwned: "true"}
EOF
  gen_case N5b-namespace-kube-system "Namespace kube-system patché dans generated/" \
    bash -c "[[ \$(kubectl get ns kube-system -o jsonpath='{.metadata.resourceVersion}') == $rv_ns ]]"

  rv_vap="$(k get validatingadmissionpolicy lab-cell-pod-hardening -o jsonpath='{.metadata.resourceVersion}')"
  yq 'select(.kind == "ValidatingAdmissionPolicy") | .spec.failurePolicy = "Ignore" | .spec.validations = [{"expression": "true"}]' \
    "$W/platform/policies/vap-cell-pod-hardening.yaml" >"$f"
  gen_case N5c-vap-modifiee "VAP lab-cell-pod-hardening neutralisée dans generated/" \
    bash -c "[[ \$(kubectl get validatingadmissionpolicy lab-cell-pod-hardening -o jsonpath='{.metadata.resourceVersion}') == $rv_vap ]]"

  cat >"$f" <<'EOF'
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata: {name: lab-n5-vap}
spec:
  failurePolicy: Fail
  matchConstraints: {resourceRules: [{apiGroups: [""], apiVersions: [v1], operations: [CREATE], resources: [pods]}]}
  validations: [{expression: "false"}]
EOF
  gen_case N5d-vap-nouvelle "nouvelle VAP dans generated/" absent validatingadmissionpolicy lab-n5-vap

  cat >"$f" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: lab-n5-star}
rules: [{apiGroups: ["*"], resources: ["*"], verbs: ["*"]}]
EOF
  gen_case N5e-clusterrole-star "ClusterRole */*/* dans generated/" absent clusterrole lab-n5-star

  cat >"$f" <<'EOF'
apiVersion: v1
kind: Secret
metadata: {name: n5-secret, namespace: default}
stringData: {password: valeur-factice-de-test}
EOF
  gen_case N5f-secret-clair "Secret en clair dans generated/" absent -n default secret n5-secret

  local psa; psa="$(k get ns lab-pg -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || true)"
  cat >"$f" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: lab-pg
  labels: {pod-security.kubernetes.io/enforce: privileged}
EOF
  gen_case N5g-label-psa "label PSA de lab-pg abaissé à privileged depuis generated/" \
    bash -c "[[ \$(kubectl get ns lab-pg -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}') == '$psa' ]]"

  # Destination : objet applicatif (kind permis) mais dans kube-system.
  cat >"$f" <<'EOF'
apiVersion: openchoreo.dev/v1alpha1
kind: Project
metadata: {name: n5-ks, namespace: kube-system}
spec: {deploymentPipelineRef: {name: standard}, type: {kind: ClusterProjectType, name: cell-restricted}}
EOF
  gen_case N5h-destination-kube-system "Project (kind permis) dans kube-system depuis generated/" \
    absent -n kube-system projects.openchoreo.dev n5-ks
  rm -f "$f"
}

t_n3_kube_system() { # Application (apps/) dans le namespace kube-system.
  cat >"$W/$AP/n3-ks.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: n3-ks, namespace: kube-system}
spec:
  project: lab-platform
  source: {repoURL: $IN_REPO, targetRevision: main, path: platform/policies}
  destination: {server: https://kubernetes.default.svc, namespace: default}
EOF
  commit "N3 : Application dans kube-system"
  local sha; sha="$(head_sha)"; wait_rev lab-root "$sha" 180 || true; snap N3 lab-root
  local m; m="$(op_msg lab-root)"
  if absent -n kube-system applications.argoproj.io n3-ks && [[ "$(op_phase lab-root)" != Succeeded && "$m" == *"not permitted"* ]]; then
    rec N3-application-kube-system PASS "lab-root $(op_phase lab-root) : ${m:0:220} ; aucune Application dans kube-system (API)"
  else rec N3-application-kube-system FAIL "phase=$(op_phase lab-root) $m"; fi
  revert; wait_rev lab-root "$(head_sha)" 180 || true
}

t_n4_authz() { # lab-authz passé en automated + nouveau rôle : la fenêtre deny bloque l'auto ; le manuel passe.
  yq -i '.spec.syncPolicy.automated = {"prune": false, "selfHeal": true}' "$W/$AP/lab-authz.yaml"
  cat >>"$W/platform/authz/roles.yaml" <<'EOF'
---
apiVersion: openchoreo.dev/v1alpha1
kind: ClusterAuthzRole
metadata: {name: lab-n4-escalade}
spec:
  description: "test A2 : ne doit apparaître qu'après une synchro MANUELLE"
  actions: ["*"]
EOF
  commit "N4 : lab-authz automated + rôle lab-n4-escalade"
  local sha; sha="$(head_sha)"; wait_rev lab-root "$sha" 180 || true
  local auto; auto="$(app_json lab-authz | jq -c '.spec.syncPolicy.automated')"
  local _i; for _i in 1 2 3 4; do sleep 25; k -n "$NS" annotate application lab-authz argocd.argoproj.io/refresh=hard --overwrite >/dev/null; done
  snap N4-auto lab-root lab-authz
  k -n "$NS" logs statefulset/argocd-application-controller --since=5m 2>/dev/null | grep -i 'window' | tail -5 >"$EVID/N4-controller-window.log" || true
  local blocked=no
  if absent clusterauthzroles.openchoreo.dev lab-n4-escalade && [[ "$auto" != null ]] \
      && [[ "$(op_rev lab-authz)" != "$sha" ]]; then blocked=yes; fi
  sync_manual lab-authz "$sha"; wait_rev lab-authz "$sha" 180 || true; snap N4-manual lab-authz
  local manual=no
  if [[ "$(op_phase lab-authz)" == Succeeded ]] && ! absent clusterauthzroles.openchoreo.dev lab-n4-escalade; then manual=yes; fi
  if [[ $blocked == yes && $manual == yes ]]; then
    rec N4-authz-automated PASS "spec.automated=$auto appliqué par lab-root, ~100 s sans synchro auto (fenêtre deny ; rôle absent) ; synchro manuelle Succeeded (rôle créé)"
  else rec N4-authz-automated FAIL "bloqué=$blocked manuel=$manual auto=$auto op=$(op_rev lab-authz | cut -c1-7) $(op_phase lab-authz) $(op_msg lab-authz)"; fi
  revert; wait_rev lab-root "$(head_sha)" 180 || true
  k delete clusterauthzroles.openchoreo.dev lab-n4-escalade --ignore-not-found >/dev/null  # prune désactivé
}

t_n6_platform_star() { # même par le chemin privilégié platform/, un ClusterRole non nommé est refusé.
  cat >"$W/platform/policies/zz-n6.yaml" <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata: {name: lab-n6-star}
rules: [{apiGroups: ["*"], resources: ["*"], verbs: ["*"]}]
EOF
  commit "N6 : ClusterRole */*/* dans platform/policies"
  local sha; sha="$(head_sha)"; sync_manual lab-platform "$sha"; wait_rev lab-platform "$sha" 240 || true; snap N6 lab-platform
  local m; m="$(op_msg lab-platform)"
  if absent clusterrole lab-n6-star && [[ "$(op_phase lab-platform)" != Succeeded && "$m" == *"not permitted"* ]]; then
    rec N6-platform-clusterrole PASS "lab-platform $(op_phase lab-platform) : ${m:0:200} ; ClusterRole absent (API)"
  else rec N6-platform-clusterrole FAIL "phase=$(op_phase lab-platform) $m"; fi
  plat_revert
}

t_n7_platform_psa() { # chemin PRIVILÉGIÉ : abaisser la PSA de lab-pg dans platform/. Argo l'ACCEPTE (kind nommé).
  perl -pi -e 's#pod-security.kubernetes.io/enforce: restricted#pod-security.kubernetes.io/enforce: privileged#' \
    "$W/platform/data/lab-pg-namespace.yaml"
  commit "N7 : PSA lab-pg abaissée dans platform/data"
  local sha v0 v; sha="$(head_sha)"
  psa() { k get ns lab-pg -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'; }
  no_auto lab-platform "$sha" 60 || true; v0="$(psa)"; snap N7-auto lab-platform
  if [[ "$v0" == restricted ]]; then
    rec N7a-platform-psa-auto PASS "merge @${sha:0:7} (PSA lab-pg -> privileged) : 60 s sans synchro auto ; label enforce=$v0 (API)"
  else rec N7a-platform-psa-auto FAIL "label enforce=$v0 sans geste opérateur"; fi
  # Synchro MANUELLE de ce commit (opérateur qui ne relit pas) : Argo l'ACCEPTE, Namespace lab-pg nommé.
  sync_manual lab-platform "$sha"; wait_rev lab-platform "$sha" 240 || true; v="$(psa)"; snap N7-manual lab-platform
  rec N7b-platform-psa-manuel "$([[ $v == privileged ]] && echo ACCEPTE_PAR_ARGO || echo REFUSE_PAR_ARGO)" \
    "synchro manuelle $(op_phase lab-platform) ; label enforce=$v (attendu : Argo n'est PAS la barrière ; CI S3 + relecture opérateur)"
  plat_revert
  rec N7c-platform-psa-restaure "$([[ $(psa) == restricted ]] && echo PASS || echo FAIL)" "après revert + synchro manuelle : enforce=$(psa)"
}

t_n8_projects() { # Application enfant lab-apps qui synchronise platform/install/argocd (AppProject).
  cat >"$W/$AP/n8-projects.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: n8-projects, namespace: lab-argocd}
spec:
  project: lab-apps
  source: {repoURL: $IN_REPO, targetRevision: main, path: platform/install/argocd, directory: {include: "project-*.yaml"}}
  destination: {server: https://kubernetes.default.svc, namespace: default}
  syncPolicy: {automated: {prune: false, selfHeal: true}}
EOF
  local before; before="$(k -n "$NS" get appprojects -o json | jq -c '[.items[] | {n: .metadata.name, rv: .metadata.resourceVersion}]')"
  commit "N8 : Application enfant lab-apps -> AppProject"
  local sha; sha="$(head_sha)"; wait_rev lab-root "$sha" 180 || true; wait_rev n8-projects "$sha" 180 || true
  snap N8 lab-root n8-projects
  local after m; after="$(k -n "$NS" get appprojects -o json | jq -c '[.items[] | {n: .metadata.name, rv: .metadata.resourceVersion}]')"
  m="$(op_msg n8-projects)"
  if [[ "$before" == "$after" && "$m" == *"not permitted"* ]]; then
    rec N8-appproject-via-lab-apps PASS "n8-projects $(op_phase n8-projects) : ${m:0:220} ; AppProject inchangés (resourceVersion)"
  else rec N8-appproject-via-lab-apps FAIL "phase=$(op_phase n8-projects) $m ; avant=$before après=$after"; fi
  revert; wait_rev lab-root "$(head_sha)" 180 || true
  k -n "$NS" delete application n8-projects --wait=false >/dev/null 2>&1 || true
}

tests() {
  [[ -d "$W/.git" ]] || { echo "dépôt de test absent : lancer setup (même ARGO_ESC_WORK)" >&2; exit 2; }
  [[ -n "${PF_PID:-}" ]] || pf_start
  # Reprise possible après interruption : ARGO_ESC_FROM=<fonction> (ex. t_n3_kube_system) saute les tests
  # précédents et AJOUTE à results.tsv.
  local from="${ARGO_ESC_FROM:-}" t
  [[ -n "$from" ]] || : >"$EVID/results.tsv"
  {
    echo "date: $(ts)"; echo "cluster: $LABEL"
    echo "argocd: chart $ARGOCD_VERSION, $(k -n "$NS" get deploy argocd-server -o jsonpath='{.spec.template.spec.containers[0].image}')"
    echo "openchoreo-crd: $OC_COMMIT ; cnpg-crd: $CNPG_VERSION"
  } >>"$EVID/run-info.txt"
  for t in t_pos_apps t_pos_platform t_n1_default t_n2a_app_in_platform t_generated t_n3_kube_system t_n4_authz \
           t_n6_platform_star t_n7_platform_psa t_n8_projects; do
    [[ -n "$from" && "$t" != "$from" ]] && continue
    from=""; "$t"
  done
  k -n "$NS" get applications.argoproj.io -o json >"$EVID/FINAL-applications.json"
  column -t -s $'\t' "$EVID/results.tsv" >&2
}

cleanup() {
  k -n "$NS" delete applications.argoproj.io --all --wait=false >/dev/null 2>&1 || true
  k delete -f "$HERE/git-server.yaml" --ignore-not-found >/dev/null 2>&1 || true
  helm uninstall argocd -n "$NS" >/dev/null 2>&1 || true
  log "cluster k3d jetable : supprimer avec k3d cluster delete <nom>"
}

preflight
case "${1:-all}" in
  setup) setup ;;
  tests) tests ;;
  all) setup; tests ;;
  cleanup) cleanup ;;
  *) echo "usage : $0 [all|setup|tests|cleanup]" >&2; exit 2 ;;
esac
