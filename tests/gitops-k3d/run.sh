#!/usr/bin/env bash
# Preuve GitOps de bout en bout sur k3d : Git -> Argo CD -> OpenChoreo, avec les objets RÉELS de generated/.
# Étiquette des résultats : k3d (jamais OKE). Voir docs/GITOPS-PROOF.md.
#
# Usage : tests/gitops-k3d/run.sh [all|cleanup]
#   all     : bootstrap (Argo, serveur Git de test) puis cycle complet whoami ; laisse les objets en place.
#   cleanup : supprime Applications, objets gl-oc, dp-gl-oc-*, gl-git, gl-oc, Argo CD (namespace argocd, CRD).
# Prérequis : KUBECONFIG d'un cluster k3d jetable (contexte k3d-*), OpenChoreo 1.3.3 + DataPlane `default`,
# helm, git, python3 (PyYAML, jsonschema), accès Internet (GitHub, quay.io, docker.io).
# Limite connue (run 4) : T-RETRAIT-1 échoue tant que whoami est la seule app de gl-apps (garde Argo
# allowEmpty=false) ; T-READD/T-RETRAIT-PVC n'ont donc pas été exécutés jusqu'au bout. Voir RESULTS.md.
# Seuls écrits par kubectl hors Git : bootstrap (namespaces, Argo, serveur Git, AppProject, Applications),
# perturbations VOLONTAIRES de dérive (T-DRIFT-*), redémarrage du contrôleur, nettoyage.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
EVID="$HERE/evidence"
WORK="${GL_WORK:-$(mktemp -d)}"
W="$WORK/gl-repo"
GH_REPO="https://github.com/platform-zephyr/openchoreo-lab"
IN_REPO="git://gl-git.gl-git.svc.cluster.local:9418/gl-repo.git"
GIT_PF=19418
GW_PF=29080
HOST_HDR="production-gl-oc.internal.localhost"
IMG_NEW="traefik/whoami:v1.11.0@sha256:200689790a0a0ea48ca45992e0450bc26ccab5307375b41c84dfc4f2475937ab"
ARGO_IMG="quay.io/argoproj/argocd:v3.5.1@sha256:0deb1a1c917629b960ead995ae3b6069450a866992676599658687ef9a641ee8"
# shellcheck source=../../platform/install/versions.env
source "$ROOT/platform/install/versions.env"

k() { kubectl "$@"; }
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "[$(date -u +%T)] $*"; }

# --- garde-fous -------------------------------------------------------------------------------------
preflight() {
  [[ "${KUBECONFIG:-}" != *oke-access* ]] || { echo "REFUS : kubeconfig OKE" >&2; exit 2; }
  local ctx; ctx="$(k config current-context)"
  [[ "$ctx" == k3d-* ]] || { echo "REFUS : contexte $ctx (k3d-* attendu)" >&2; exit 2; }
  mkdir -p "$EVID"
}

# --- résultats et preuves ---------------------------------------------------------------------------
rec() { # rec ID RESULTAT "détail"
  printf '%s\t%s\t%s\t%s\n' "$(ts)" "$1" "$2" "$3" >>"$EVID/results.tsv"
  log "RESULT $1 $2 : $3"
}
ev() { # ev ID commande... (sortie ajoutée à evidence/ID.txt, datée)
  local id="$1"; shift
  { echo "### $(ts) \$ $*"; "$@" 2>&1 || true; echo; } >>"$EVID/$id.txt"
}
evs() { # evs ID "texte"
  { echo "### $(ts)"; echo "$2"; echo; } >>"$EVID/$1.txt"
}
wait_until() { # wait_until TIMEOUT cmd... ; imprime la durée (s), code 1 si délai dépassé
  local t="$1"; shift; local s; s=$(date +%s)
  while ! "$@" >/dev/null 2>&1; do
    (( $(date +%s) - s >= t )) && { echo "timeout"; return 1; }
    sleep 2
  done
  echo $(( $(date +%s) - s ))
}

app_rev() { k -n argocd get app "$1" -o jsonpath='{.status.sync.revision}'; }
app_synced_at() { # app sha : dernière opération Succeeded sur ce sha, et aucune ressource OutOfSync hors
  # celles qui attendent un prune refusé (Prune=false) : leur OutOfSync est permanent, attendu et documenté.
  k -n argocd get app "$1" -o json | python3 -c '
import json, sys
a = json.load(sys.stdin)["status"]; sha = sys.argv[1]
op = a.get("operationState", {})
ok = op.get("phase") == "Succeeded" and op.get("syncResult", {}).get("revision") == sha and a.get("sync", {}).get("revision") == sha
bad = [r for r in a.get("resources", []) if r.get("status") != "Synced" and not r.get("requiresPruning")]
sys.exit(0 if ok and not bad else 1)' "$2"
}
dpns() { k get ns -o name | sed -n 's#^namespace/\(dp-gl-oc-whoami-production-.*\)#\1#p' | head -1; }
rb_ready() { [[ "$(k -n gl-oc get releasebinding whoami-production -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" == True ]]; }
rb_reason() { k -n gl-oc get releasebinding whoami-production -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null; }
orphans() { k -n argocd get app gl-apps -o jsonpath='{.status.conditions[?(@.type=="OrphanedResourceWarning")].message}' | grep -o '[0-9]*' | head -1; }
rb_release() { k -n gl-oc get releasebinding whoami-production -o jsonpath='{.spec.releaseName}'; }
dep() { k -n "$(dpns)" get deploy -l openchoreo.dev/component=whoami -o name | head -1; }
dep_ok() { # replicas image
  local d; d="$(dep)"; [[ -n "$d" ]] || return 1
  [[ "$(k -n "$(dpns)" get "$d" -o jsonpath='{.status.readyReplicas}/{.status.updatedReplicas}/{.spec.replicas}')" == "$1/$1/$1" ]] \
    && [[ "$(k -n "$(dpns)" get "$d" -o jsonpath='{.spec.template.spec.containers[0].image}')" == "$2" ]] \
    && [[ "$(k -n "$(dpns)" get pods -l openchoreo.dev/component=whoami --no-headers 2>/dev/null | wc -l | tr -d ' ')" == "$1" ]]
}
http_code() { curl -s -m 5 -o /dev/null -w '%{http_code}' -H "Host: $HOST_HDR" "http://127.0.0.1:$GW_PF/whoami-http/" || true; }
pvc_bound() { [[ "$(k -n "$(dpns)" get pvc -o jsonpath='{.items[0].status.phase}' 2>/dev/null)" == Bound ]]; }
http_ok() { [[ "$(http_code)" == 200 ]]; }

# --- port-forwards ----------------------------------------------------------------------------------
PF_PIDS=()
pf() { k -n "$1" port-forward "svc/$2" "$3:$4" >/dev/null 2>&1 & PF_PIDS+=($!); sleep 3; }
cleanup_pf() { for p in "${PF_PIDS[@]:-}"; do [[ -n "$p" ]] && kill "$p" 2>/dev/null || true; done; }
trap cleanup_pf EXIT

# --- dépôt de test ----------------------------------------------------------------------------------
gcommit() { # gcommit "message" ; commit + push, imprime le sha
  git -C "$W" add -A
  git -C "$W" -c user.name=gl-test -c user.email=gl-test@invalid commit -q -m "$1"
  git -C "$W" push -q "git://127.0.0.1:$GIT_PF/gl-repo.git" main
  git -C "$W" rev-parse HEAD
}
render() { # parcours évalué : app.yaml -> appgen validate/render (CI) -> annotations (correction proposée)
  (cd "$W" && python3 tools/appgen/appgen.py validate >/dev/null && python3 tools/appgen/appgen.py render >/dev/null)
  python3 "$HERE/annotate_syncopts.py" "$W/generated" >/dev/null
}
edit_app() { # edit_app 'code python sur la variable s (texte de apps/whoami/app.yaml)'
  python3 - "$W/apps/whoami/app.yaml" "$1" <<'EOF'
import sys
p, code = sys.argv[1], sys.argv[2]
s = open(p).read(); before = s
exec(code)
assert s != before, "edit_app : aucun changement"
open(p, "w").write(s)
EOF
}
apply_app() { # apply_app fichier repo prune
  sed -e "s#__REPO__#$2#" -e 's#__REV__#main#' -e "s#__PRUNE__#${3:-false}#" "$HERE/apps/$1.yaml" | k apply -f - >/dev/null
}
# RECON_MODE : `polling` (aucun déclencheur : délai Argo par défaut 120 s + gigue) pour les 2 premiers commits,
# puis `webhook` : annotation argocd.argoproj.io/refresh=normal après le push (équivalent d'un webhook Git).
RECON_MODE=polling
kick() { [[ "$RECON_MODE" == webhook ]] && k -n argocd annotate app "$1" argocd.argoproj.io/refresh=normal --overwrite >/dev/null || true; }
step() { # step ID "message" ; commit, puis mesure Git->Argo
  local id="$1" sha t; sha="$(gcommit "$2")"; kick gl-apps
  t=$(wait_until 420 app_synced_at gl-apps "$sha") || true
  evs "$id" "commit $sha « $2 » ; Git -> Argo gl-apps Synced : ${t}s ($RECON_MODE)"
  echo "$t"
}
app_source_is() { [[ "$(k -n argocd get app "$1" -o jsonpath='{.status.sync.comparedTo.source.repoURL}')" == "$2" ]] && app_synced_at "$1" "$3"; }

# ====================================================================================================
bootstrap() {
  local t0; t0=$(date +%s)
  log "bootstrap : namespaces, Argo CD $ARGOCD_VERSION, serveur Git, AppProject"
  k apply -f "$HERE/bootstrap/00-namespaces.yaml" >/dev/null
  local chart="$WORK/argo-cd-$ARGOCD_VERSION.tgz"
  HELM_CACHE_HOME="$WORK/.h" HELM_CONFIG_HOME="$WORK/.h" HELM_DATA_HOME="$WORK/.h" \
    helm pull "$ARGOCD_CHART" --repo "$ARGOCD_REPO" --version "$ARGOCD_VERSION" -d "$WORK" >/dev/null
  echo "$ARGOCD_TGZ_SHA256  $chart" | shasum -a 256 -c - >/dev/null || { rec T-BOOT FAIL "sha256 du chart Argo"; exit 1; }
  helm upgrade --install argocd "$chart" -n argocd \
    -f "$ROOT/platform/install/values/argocd.yaml" -f "$HERE/argocd-values-k3d.yaml" --wait --timeout 8m >/dev/null
  k apply -f "$HERE/bootstrap/01-git-server.yaml" -f "$HERE/bootstrap/02-appproject.yaml" >/dev/null
  k -n gl-git rollout status deploy/gl-git --timeout=180s >/dev/null
  ev T-BOOT k -n argocd get pods -o wide
  ev T-BOOT k get ns argocd gl-oc gl-git --show-labels
  local gh; gh=$(k -n argocd exec deploy/argocd-repo-server -c repo-server -- git ls-remote "$GH_REPO" refs/heads/main | cut -f1)
  [[ -n "$gh" ]] && rec T-BOOT PASS "Argo CD v3.5.1 (chart $ARGOCD_VERSION, sha256 vérifié) Running sous PSA restricted en $(( $(date +%s)-t0 ))s ; GitHub joignable depuis le repo-server (main=$gh)" \
                 || rec T-BOOT FAIL "GitHub injoignable depuis le cluster"
  GH_SHA="$gh"
}

cycle() {
  pf gl-git gl-git $GIT_PF 9418
  pf openchoreo-data-plane gateway-default $GW_PF 19080

  # --- T-PLAT : gl-platform depuis GitHub -----------------------------------------------------------
  apply_app gl-platform "$GH_REPO"
  local t; t=$(wait_until 300 app_synced_at gl-platform "$GH_SHA") || true
  ev T-PLAT k -n argocd get app gl-platform -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision}{"\n"}{range .status.resources[*]}{.kind}/{.namespace}/{.name} {.status}{"\n"}{end}'
  [[ "$t" != timeout ]] && rec T-PLAT PASS "gl-platform (GitHub main $GH_SHA) Synced en ${t}s : CCT service-restricted, CPT cell-restricted, CRT, ClusterTrait PVC/health-probes, 2 VAP+bindings, Environment/DeploymentPipeline (gl-oc)" \
                        || rec T-PLAT FAIL "gl-platform non Synced"

  # --- T-GH : gl-apps depuis GitHub, objets réels inchangés ------------------------------------------
  apply_app gl-apps "$GH_REPO" false
  t=$(wait_until 300 app_synced_at gl-apps "$GH_SHA") || true
  wait_until 120 bash -c "$(declare -f k rb_reason); [[ -n \$(rb_reason) ]]" >/dev/null || true
  ev T-GH k -n argocd get app gl-apps -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}{range .status.resources[*]}{.kind}/{.name} {.status} health={.health.status}{"\n"}{end}'
  ev T-GH k -n gl-oc get releasebinding whoami-production -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
  local reason health
  reason=$(rb_reason)
  health=$(k -n argocd get app gl-apps -o jsonpath='{.status.health.status}')
  [[ "$t" != timeout ]] && rec T-GH-SYNC PASS "gl-apps (GitHub main, generated/ whoami, prune=false) Synced en ${t}s" || rec T-GH-SYNC FAIL "gl-apps non Synced"
  if [[ "$reason" == RenderingFailed ]]; then
    rec T-GH-RENDER FAIL "whoami de generated/ NON rendu tel quel : endpoint internal exige gateway.ingress.internal, absent de 40-openchoreo-env.yaml ET du ClusterDataPlane (k3d et gabarit OKE)"
  else rec T-GH-RENDER PASS "ReleaseBinding Ready=$reason"; fi
  if [[ "$health" == Healthy && "$reason" != Ready ]]; then
    rec T-ARGO-HEALTH FAIL "Argo affiche Healthy alors que le ReleaseBinding est Ready=False ($reason) : aucun health check Lua pour les CR OpenChoreo"
  else rec T-ARGO-HEALTH PASS "health=$health reason=$reason"; fi

  # --- T-SWITCH : bascule GitHub -> gl-repo (même commit), aucun changement attendu ----------------
  rm -rf "$W"; git clone -q --branch main "$GH_REPO" "$W"
  git -C "$W" push -q "git://127.0.0.1:$GIT_PF/gl-repo.git" main
  local before after
  before=$(k -n gl-oc get component,workload,releasebinding,componentrelease,project -o jsonpath='{range .items[*]}{.kind}/{.metadata.name}={.metadata.generation} {end}')
  apply_app gl-platform "$IN_REPO"; apply_app gl-apps "$IN_REPO" false
  wait_until 300 app_source_is gl-apps "$IN_REPO" "$GH_SHA" >/dev/null || true
  wait_until 300 app_source_is gl-platform "$IN_REPO" "$GH_SHA" >/dev/null || true
  sleep 20
  after=$(k -n gl-oc get component,workload,releasebinding,componentrelease,project -o jsonpath='{range .items[*]}{.kind}/{.metadata.name}={.metadata.generation} {end}')
  evs T-SWITCH "avant : $before"$'\n'"après : $after"
  [[ "$before" == "$after" ]] && rec T-SWITCH PASS "source GitHub -> gl-repo (git:// dans le cluster, même sha) : aucune génération modifiée" \
                              || rec T-SWITCH FAIL "générations modifiées par la bascule"

  # --- T-DEPLOY : correction par Git de l'Environment, puis déploiement complet ---------------------
  # T-458 : patch idempotent (plus d'ancre de texte) ; verdict added|updated|noop dans les preuves.
  local envpatch sha t0 ta td
  envpatch=$(python3 "$HERE/patch_env.py" "$W/platform/install/manifests/40-openchoreo-env.yaml") || envpatch=ECHEC
  evs T-DEPLOY "patch_env.py : $envpatch (gateway.ingress.internal.http.host = internal.localhost)"
  if [[ "$envpatch" == noop ]]; then sha=$(git -C "$W" rev-parse HEAD)   # déjà conforme : rien à committer
  else sha=$(gcommit "k3d: gateway.ingress.internal sur Environment production") || sha=$(git -C "$W" rev-parse HEAD); fi
  t0=$(date +%s)
  ta=$(wait_until 420 app_synced_at gl-platform "$sha") || true
  td=$(wait_until 600 bash -c "$(declare -f k dpns rb_ready dep dep_ok); rb_ready && dep_ok 1 '$(k -n gl-oc get workload whoami-workload -o jsonpath='{.spec.container.image}')'") || true
  [[ "$td" != timeout ]] && { wait_until 180 http_ok >/dev/null || true; }  # la route suit l'hôte interne patché
  local tot=$(( $(date +%s)-t0 ))
  local ns; ns=$(dpns)
  ev T-DEPLOY k get ns "$ns" --show-labels
  ev T-DEPLOY k -n "$ns" get deploy,pod,svc,netpol,httproute,resourcequota -o wide
  ev T-DEPLOY k -n "$ns" get pod -l openchoreo.dev/component=whoami -o jsonpath='{.items[0].spec.securityContext}{"\n"}{.items[0].spec.containers[0].securityContext}{"\n"}'
  ev T-DEPLOY k -n argocd get app gl-apps gl-platform
  local code; code=$(http_code)
  evs T-DEPLOY "commit $sha ; Git->Argo gl-platform ${ta}s ; Argo->pod prêt ${td}s ; total commit->pod ${tot}s ; HTTP via gateway (Host $HOST_HDR) = $code"
  local psa; psa=$(k get ns "$ns" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')
  local np; np=$(k -n "$ns" get netpol default-deny -o name 2>/dev/null || true)
  # NetworkPolicy : un pod hors cellule (gl-git) ne joint pas le Service (default-deny).
  local deny
  deny=$(k -n gl-git run gl-np-probe --rm -i --restart=Never --image="$ARGO_IMG" --quiet \
    --overrides='{"spec":{"automountServiceAccountToken":false,"securityContext":{"runAsNonRoot":true,"runAsUser":999,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"p","image":"'"$ARGO_IMG"'","command":["bash","-c","timeout 5 bash -c \"echo > /dev/tcp/whoami.'"$ns"'.svc.cluster.local/8080\" && echo OPEN || echo BLOCKED"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}' 2>/dev/null | tail -1) || true
  evs T-DEPLOY "sonde gl-git -> whoami.$ns:8080 : $deny"
  if [[ "$td" != timeout && "$code" == 200 && "$psa" == restricted && -n "$np" && "$deny" == BLOCKED ]]; then
    rec T-DEPLOY PASS "commit->pod Running ${tot}s (Git->Argo ${ta}s) ; PSA restricted ; default-deny (sonde externe BLOCKED) ; HTTP 200 via gateway-default"
  else rec T-DEPLOY FAIL "patch_env=$envpatch td=$td http=$code psa=$psa np=$np sonde=$deny"; fi
  RECON+=("env-fix:git->argo=${ta}s,commit->pod=${tot}s")

  # --- T-ANNOT : annotations Prune=false (correction appgen proposée) + prune=true -----------------
  python3 "$HERE/annotate_syncopts.py" "$W/generated" >/dev/null
  sha=$(gcommit "gl: annotations sync-options APP-CONTRACT §5 (correction appgen proposée)")
  apply_app gl-apps "$IN_REPO" true
  t=$(wait_until 420 app_synced_at gl-apps "$sha") || true
  ev T-ANNOT k -n gl-oc get component,componentrelease -o jsonpath='{range .items[*]}{.kind}/{.metadata.name} {.metadata.annotations.argocd\.argoproj\.io/sync-options}{"\n"}{end}'
  [[ "$t" != timeout ]] && rec T-ANNOT PASS "annotations Prune=false posées par Git, gl-apps prune=true Synced en ${t}s" || rec T-ANNOT FAIL "non Synced"

  RECON_MODE=webhook
  # --- T-MOD-REPLICAS : replicas 2 par app.yaml (configs d'environnement du binding) -------------
  local cr_before rel0; cr_before=$(k -n gl-oc get componentrelease -o name | wc -l | tr -d ' '); rel0=$(rb_release)
  local img0; img0=$(k -n gl-oc get workload whoami-workload -o jsonpath='{.spec.container.image}')
  edit_app 's = s.replace("    size: small\n", "    size: small\n    replicas: 2\n")'
  render; t0=$(date +%s)
  ta=$(step T-MOD-REPLICAS "whoami: replicas 2")
  td=$(wait_until 600 bash -c "$(declare -f k dpns dep dep_ok); dep_ok 2 '$img0'") || true
  ev T-MOD-REPLICAS k -n "$(dpns)" get "$(dep)" -o jsonpath='{.spec.replicas} {.spec.template.spec.containers[0].resources}{"\n"}'
  local req; req=$(k -n "$(dpns)" get "$(dep)" -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')
  local cr_after; cr_after=$(k -n gl-oc get componentrelease -o name | wc -l | tr -d ' ')
  if [[ "$td" != timeout && "$req" == 50m && "$(rb_release)" == "$rel0" && "$cr_after" == "$cr_before" ]]; then
    rec T-MOD-REPLICAS PASS "replicas 1->2 par commit ; même ComponentRelease ($rel0 : replicas/size vivent dans le binding) ; commit->pods $(( $(date +%s)-t0 ))s (Git->Argo ${ta}s)"
  else rec T-MOD-REPLICAS FAIL "td=$td req=$req release=$(rb_release) CR $cr_before->$cr_after"; fi
  RECON+=("replicas:git->argo=${ta}s,commit->pods=$(( $(date +%s)-t0 ))s")

  # --- T-MOD-VERSION : nouvelle image (digest) => nouvelle ComponentRelease ------------------------
  edit_app "s = s.replace('$img0', '$IMG_NEW')"
  render; t0=$(date +%s)
  ta=$(step T-MOD-VERSION "whoami: v1.11.0 (digest)")
  VERSION_SHA=$(git -C "$W" rev-parse HEAD)
  td=$(wait_until 600 bash -c "$(declare -f k dpns dep dep_ok); dep_ok 2 '$IMG_NEW'") || true
  local rel1; rel1=$(rb_release)
  ev T-MOD-VERSION k -n gl-oc get componentrelease,releasebinding
  code=$(http_code)
  if [[ "$td" != timeout && "$rel1" != "$rel0" && "$code" == 200 ]] && k -n gl-oc get componentrelease "$rel0" >/dev/null 2>&1; then
    rec T-MOD-VERSION PASS "image v1.10.3 -> v1.11.0 : release $rel0 -> $rel1, ancienne release conservée (Prune=false), HTTP 200 ; commit->pods $(( $(date +%s)-t0 ))s (Git->Argo ${ta}s)"
  else rec T-MOD-VERSION FAIL "td=$td rel=$rel1 http=$code"; fi
  RECON+=("version:git->argo=${ta}s,commit->pods=$(( $(date +%s)-t0 ))s")
  # Conséquence de Prune=false + appgen qui retire l'ancien fichier de release : OutOfSync permanent ?
  local st; st=$(k -n argocd get app gl-apps -o jsonpath='{.status.sync.status}')
  ev T-PRUNE-STATUS k -n argocd get app gl-apps -o jsonpath='{.status.sync.status}{"\n"}{range .status.resources[*]}{.kind}/{.name} {.status} requiresPruning={.requiresPruning}{"\n"}{end}'
  if [[ "$st" == OutOfSync ]]; then
    rec T-PRUNE-STATUS FAIL "après une nouvelle release, gl-apps reste OutOfSync en permanence : $rel0 absente de Git (appgen render la supprime) mais Prune=false (requiresPruning=true)"
  else rec T-PRUNE-STATUS PASS "gl-apps $st après nouvelle release"; fi

  # --- T-IMMUT : une ComponentRelease ne se modifie pas ------------------------------------------
  local out
  out=$(k -n gl-oc patch componentrelease "$rel0" --type=merge -p "{\"spec\":{\"workload\":{\"container\":{\"image\":\"$IMG_NEW\"}}}}" 2>&1) && rc=0 || rc=$?
  evs T-IMMUT "kubectl patch componentrelease $rel0 (image) -> rc=$rc : $out"
  [[ $rc -ne 0 ]] && rec T-IMMUT PASS "patch de $rel0 refusé par l'API : ${out:0:160}" || rec T-IMMUT FAIL "patch accepté : ComponentRelease mutable"

  # --- T-DRIFT : dérives manuelles ----------------------------------------------------------------
  # D1 : champ possédé par Argo (ReleaseBinding replicas) -> selfHeal.
  k -n gl-oc patch releasebinding whoami-production --type=merge -p '{"spec":{"componentTypeEnvironmentConfigs":{"replicas":3}}}' >/dev/null
  t=$(wait_until 300 bash -c "[[ \$(kubectl -n gl-oc get releasebinding whoami-production -o jsonpath='{.spec.componentTypeEnvironmentConfigs.replicas}') == 2 ]]") || true
  local t2; t2=$(wait_until 300 bash -c "$(declare -f k dpns dep dep_ok); dep_ok 2 '$IMG_NEW'") || true
  ev T-DRIFT-ARGO k -n argocd get app gl-apps -o jsonpath='{.status.sync.status} {.status.operationState.syncResult.revision} {.status.operationState.finishedAt}{"\n"}'
  [[ "$t" != timeout ]] && rec T-DRIFT-ARGO PASS "kubectl patch ReleaseBinding replicas=3 annulé par selfHeal Argo en ${t}s ; Deployment revenu à 2 (+${t2}s)" \
                        || rec T-DRIFT-ARGO FAIL "dérive du ReleaseBinding non corrigée"
  # D2 : objet rendu dans dp-* (propriété OpenChoreo) : kubectl scale.
  k -n "$(dpns)" scale "$(dep)" --replicas=3 >/dev/null
  t=$(wait_until 420 bash -c "[[ \$(kubectl -n $(dpns) get $(dep) -o jsonpath='{.spec.replicas}') == 2 ]]") || true
  evs T-DRIFT-OC "kubectl scale --replicas=3 sur $(dep) ; retour à 2 : ${t}s"
  [[ "$t" != timeout ]] && rec T-DRIFT-OC PASS "kubectl scale du Deployment rendu (dp-*) corrigé par OpenChoreo en ${t}s" \
                        || rec T-DRIFT-OC FAIL "Deployment rendu resté à 3 replicas après 420s : dérive dans dp-* non corrigée"
  # remise en état éventuelle sans kubectl apply : on attend la correction ; sinon on le note seulement.
  # D3 : suppression du Service rendu.
  k -n "$(dpns)" delete svc whoami --wait=true >/dev/null
  t=$(wait_until 420 bash -c "kubectl -n $(dpns) get svc whoami") || true
  [[ "$t" != timeout ]] && rec T-DRIFT-OC-DEL PASS "Service rendu supprimé à la main, recréé par OpenChoreo en ${t}s" \
                        || rec T-DRIFT-OC-DEL FAIL "Service rendu non recréé après 420s"
  # D4 : Environment (gl-platform) modifié à la main -> selfHeal.
  k -n gl-oc patch environment production --type=merge -p '{"spec":{"isProduction":false}}' >/dev/null
  t=$(wait_until 300 bash -c "[[ \$(kubectl -n gl-oc get environment production -o jsonpath='{.spec.isProduction}') == true ]]") || true
  [[ "$t" != timeout ]] && rec T-DRIFT-PLAT PASS "kubectl patch Environment annulé par selfHeal gl-platform en ${t}s" || rec T-DRIFT-PLAT FAIL "non corrigé"
  # D5 : objet créé hors Git dans gl-oc -> orphelin signalé (pas supprimé).
  local n_orph; n_orph=$(orphans); n_orph=${n_orph:-0}
  k -n gl-oc create -f - >/dev/null <<'EOF'
apiVersion: openchoreo.dev/v1alpha1
kind: DeploymentPipeline
metadata: {name: gl-orphan-probe}
spec: {promotionPaths: []}
EOF
  t=$(wait_until 240 bash -c "$(declare -f k orphans); [[ \$(orphans) -gt ${n_orph:-0} ]]") || true
  ev T-DRIFT-ORPHAN k -n argocd get app gl-apps -o jsonpath='{.status.conditions}{"\n"}'
  [[ "$t" != timeout ]] && rec T-DRIFT-ORPHAN PASS "objet créé hors Git (gl-oc) signalé OrphanedResourceWarning ($n_orph -> $(orphans)) en ${t}s, non supprimé" || rec T-DRIFT-ORPHAN FAIL "aucun signalement"
  k -n gl-oc delete deploymentpipeline gl-orphan-probe >/dev/null

  # --- T-ROLLBACK : git revert du commit de version ----------------------------------------------
  git -C "$W" -c user.name=gl-test -c user.email=gl-test@invalid revert --no-edit "$VERSION_SHA" >/dev/null
  git -C "$W" push -q "git://127.0.0.1:$GIT_PF/gl-repo.git" main; kick gl-apps; sha=$(git -C "$W" rev-parse HEAD); t0=$(date +%s)
  ta=$(wait_until 420 app_synced_at gl-apps "$sha") || true
  td=$(wait_until 600 bash -c "$(declare -f k dpns dep dep_ok); dep_ok 2 '$img0'") || true
  ev T-ROLLBACK k -n gl-oc get componentrelease,releasebinding -o wide
  ev T-ROLLBACK k -n argocd get app gl-apps -o jsonpath='{.status.sync.status} {.status.conditions}{"\n"}'
  code=$(http_code)
  if [[ "$td" != timeout && "$(rb_release)" == "$rel0" && "$code" == 200 ]] && k -n gl-oc get componentrelease "$rel1" >/dev/null 2>&1; then
    rec T-ROLLBACK PASS "git revert : binding $rel1 -> $rel0 (release d'origine intacte, réutilisée), image v1.10.3, HTTP 200 ; revert->pods $(( $(date +%s)-t0 ))s (Git->Argo ${ta}s) ; $rel1 conservée (orpheline)"
  else rec T-ROLLBACK FAIL "td=$td release=$(rb_release) http=$code"; fi
  RECON+=("revert:git->argo=${ta}s,commit->pods=$(( $(date +%s)-t0 ))s")

  # --- T-RESTART : redémarrage du contrôleur OpenChoreo -------------------------------------------
  local ns2; ns2=$(dpns)
  before=$(k -n "$ns2" get pods -l openchoreo.dev/component=whoami -o jsonpath='{range .items[*]}{.metadata.uid}:{.status.containerStatuses[0].restartCount} {end}')
  local dgen0; dgen0=$(k -n "$ns2" get "$(dep)" -o jsonpath='{.metadata.generation}')
  k -n openchoreo-control-plane rollout restart deploy/controller-manager >/dev/null
  k -n openchoreo-control-plane rollout status deploy/controller-manager --timeout=300s >/dev/null
  sleep 60
  after=$(k -n "$ns2" get pods -l openchoreo.dev/component=whoami -o jsonpath='{range .items[*]}{.metadata.uid}:{.status.containerStatuses[0].restartCount} {end}')
  local dgen1; dgen1=$(k -n "$ns2" get "$(dep)" -o jsonpath='{.metadata.generation}')
  evs T-RESTART "pods avant : $before"$'\n'"pods après : $after"$'\n'"generation Deployment : $dgen0 -> $dgen1 ; HTTP $(http_code) ; RB Ready=$(rb_ready && echo True || echo False) ; Argo $(k -n argocd get app gl-apps -o jsonpath='{.status.sync.status}')"
  if [[ "$before" == "$after" && "$dgen0" == "$dgen1" ]] && http_ok && rb_ready; then
    rec T-RESTART PASS "rollout restart controller-manager : pods identiques (UID, 0 redémarrage), Deployment non modifié, HTTP 200, binding Ready"
  else rec T-RESTART FAIL "pods $before -> $after ; gen $dgen0 -> $dgen1"; fi

  # --- T-PIN-STALE : passage stateless -> stateful (PVC) + medium sur l'app EN PLACE -------------------
  local prb_pin0 sf_yaml; prb_pin0=$(k -n gl-oc get projectreleasebinding whoami-production -o jsonpath='{.spec.projectRelease}')
  edit_app 's = s.replace("  profile: stateless\n", "  profile: stateful\n").replace("    size: small\n    replicas: 2\n", "    size: medium\n").replace("  backup: {class: none}\n", "  storage: {profile: block-rwo, mountPath: /data, size: 1Gi}\n  update: {strategy: Recreate}\n  backup: {class: regenerable}\n")'
  sf_yaml="$WORK/whoami-stateful.yaml"; cp "$W/apps/whoami/app.yaml" "$sf_yaml"
  render; t0=$(date +%s)
  ta=$(step T-PIN-STALE "whoami: stateful (PVC 1Gi /data), size medium")
  sleep 60
  local latest pin1 hard
  latest=$(k -n gl-oc get project whoami -o jsonpath='{.status.latestRelease.name}')
  pin1=$(k -n gl-oc get projectreleasebinding whoami-production -o jsonpath='{.spec.projectRelease}')
  hard=$(k -n "$(dpns)" get resourcequota cell-quota -o jsonpath='{.spec.hard.persistentvolumeclaims}')
  ev T-PIN-STALE k -n gl-oc get project whoami -o jsonpath='Project.spec.parameters={.spec.parameters}{"\n"}latestRelease={.status.latestRelease.name}{"\n"}'
  ev T-PIN-STALE k -n gl-oc get projectreleasebinding whoami-production -o jsonpath='PRB.spec.projectRelease={.spec.projectRelease}{"\n"}'
  ev T-PIN-STALE k -n "$(dpns)" get resourcequota
  if [[ "$pin1" == "$latest" ]]; then
    rec T-PIN-STALE PASS "PRB suit la nouvelle ProjectRelease $latest sans geste"
  else
    rec T-PIN-STALE FAIL "changement de paramètres du Project par app.yaml : latestRelease=$latest mais PRB reste épinglé sur $pin1 (avant le commit : $prb_pin0) ; quota pvcs=$hard (le nouveau quota n'est PAS appliqué)"
  fi

  # --- T-PIN-PRB : 2e commit qui avance la pin (lecture du cluster, comme pin-resource) ------------
  local prbf="$W/generated/namespaces/default/projects/whoami/project-bindings/whoami-production.yaml"
  python3 - "$prbf" "$latest" <<'PY'
import sys
p, rel = sys.argv[1], sys.argv[2]; s = open(p).read()
assert "projectRelease" not in s
s = s.replace("  environment: production\n", f"  environment: production\n  projectRelease: {rel}\n", 1)
open(p, "w").write(s)
PY
  ta=$(step T-PIN-PRB "whoami: pin ProjectReleaseBinding -> $latest (2e commit)")
  t=$(wait_until 120 bash -c "[[ \$(kubectl -n $(dpns) get resourcequota cell-quota -o jsonpath='{.spec.hard.persistentvolumeclaims}') == 1 ]]") || true
  ev T-PIN-PRB k -n gl-oc get projectreleasebinding whoami-production --show-managed-fields -o jsonpath='{.spec.projectRelease}{"\n"}{range .metadata.managedFields[*]}{.manager} {.operation} {.fieldsV1.f:spec}{"\n"}{end}'
  ev T-PIN-PRB k -n "$(dpns)" get resourcequota
  [[ "$t" != timeout ]] && rec T-PIN-PRB PASS "2e commit (pin $pin1 -> $latest, champ repris par Argo en SSA) : quota pvcs=1 appliqué en ${t}s" \
                        || rec T-PIN-PRB FAIL "quota non mis à jour après la pin"

  # --- T-STRATEGY : RollingUpdate -> Recreate sur le Deployment existant ---------------------------
  t=$(wait_until 180 pvc_bound) || true
  ev T-STRATEGY k -n gl-oc get releasebinding whoami-production -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
  ev T-STRATEGY k -n "$(dpns)" get deploy,pvc,pod -o wide
  ev T-STRATEGY k -n argocd get app gl-apps -o jsonpath='Argo: {.status.sync.status} {.status.health.status}{"\n"}'
  if [[ "$t" != timeout ]]; then rec T-STRATEGY PASS "passage stateful en place : PVC Bound"
  else
    rec T-STRATEGY FAIL "passage stateless -> stateful en place refusé par l'API : « $(k -n gl-oc get releasebinding whoami-production -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' | grep -o 'spec.strategy.rollingUpdate: Forbidden[^;]*' | head -1 | cut -c1-110) » ; ancienne version servie (HTTP $(http_code)), Argo $(k -n argocd get app gl-apps -o jsonpath='{.status.health.status}')"
  fi

  # --- T-RETRAIT-1 : retrait de l'app (stateless de fait) ------------------------------------------
  local ns3; ns3=$(dpns)
  git -C "$W" rm -q -r apps/whoami; render
  sha=$(gcommit "whoami: retrait"); kick gl-apps; t0=$(date +%s)
  ta=$(wait_until 300 app_synced_at gl-apps "$sha") || true
  local tg; tg=$(wait_until 240 bash -c "! kubectl get ns $ns3") || true
  ev T-RETRAIT-1 k -n gl-oc get project,component,componentrelease,workload,releasebinding,projectreleasebinding
  ev T-RETRAIT-1 k get ns "$ns3"
  ev T-RETRAIT-1 k -n argocd get app gl-apps -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}{range .status.resources[*]}{.kind}/{.name} {.status} requiresPruning={.requiresPruning}{"\n"}{end}'
  local comp1; comp1=$(k -n gl-oc get component whoami -o name 2>/dev/null || true)
  local proj1; proj1=$(k -n gl-oc get project whoami -o name 2>/dev/null || true)
  if [[ -z "$proj1" && -n "$comp1" && "$tg" != timeout ]]; then
    rec T-RETRAIT-1 PASS "retrait Git (Git->Argo ${ta}s) : Project/PRB/Workload/RB supprimés par Argo, namespace $ns3 supprimé par OpenChoreo en ${tg}s ; Component et ComponentRelease conservés (Prune=false)"
  else rec T-RETRAIT-1 FAIL "project='${proj1}' component='${comp1}' ns=${tg}"; fi

  # --- T-READD : ré-ajout de l'app, stateful dès sa création ---------------------------------------
  mkdir -p "$W/apps/whoami"; cp "$sf_yaml" "$W/apps/whoami/app.yaml"; render
  t0=$(date +%s)
  ta=$(step T-READD "whoami: ré-ajout stateful (PVC 1Gi /data)")
  t=$(wait_until 420 pvc_bound) || true
  td=$(wait_until 420 bash -c "$(declare -f k dpns dep dep_ok); dep_ok 1 '$img0'") || true
  ev T-READD k -n "$(dpns)" get resourcequota,pvc,deploy,pod -o wide
  ev T-READD k -n "$(dpns)" get "$(dep)" -o jsonpath='{.spec.strategy} {.spec.template.spec.containers[0].resources.requests}{"\n"}'
  PVC_UID=$(k -n "$(dpns)" get pvc -o jsonpath='{.items[0].metadata.uid}' 2>/dev/null || true)
  PVC_PV=$(k -n "$(dpns)" get pvc -o jsonpath='{.items[0].spec.volumeName}' 2>/dev/null || true)
  if [[ "$t" != timeout && "$td" != timeout ]] && http_ok; then
    rec T-READD PASS "app stateful créée par Git : PVC Bound ($PVC_UID), Recreate, 1 pod medium Running, HTTP 200 ; commit->pod $(( $(date +%s)-t0 ))s"
  else rec T-READD FAIL "pvc=$t dep=$td http=$(http_code) ; $(k -n gl-oc get releasebinding whoami-production -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null | cut -c1-200)"; fi

  # --- T-RETRAIT-PVC : retrait d'une app avec PVC --------------------------------------------------
  ns3=$(dpns)
  git -C "$W" rm -q -r apps/whoami; render
  sha=$(gcommit "whoami: retrait (stateful)"); kick gl-apps; t0=$(date +%s)
  ta=$(wait_until 300 app_synced_at gl-apps "$sha") || true
  tg=$(wait_until 240 bash -c "! kubectl get ns $ns3") || true
  ev T-RETRAIT-PVC k get ns "$ns3"
  ev T-RETRAIT-PVC k -n "$ns3" get pvc
  ev T-RETRAIT-PVC k get pv "$PVC_PV"
  local pvc_now pv_now
  pvc_now=$(k -n "$ns3" get pvc -o jsonpath='{.items[0].metadata.uid}' 2>/dev/null || true)
  pv_now=$(k get pv "$PVC_PV" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  evs T-RETRAIT-PVC "Git->Argo ${ta}s ; namespace supprimé : ${tg}s ; PVC avant $PVC_UID, après '${pvc_now}' ; PV $PVC_PV : '${pv_now:-absent}'"
  if [[ -n "$PVC_UID" && "$pvc_now" == "$PVC_UID" ]]; then
    rec T-RETRAIT-PVC PASS "retrait par Git : PVC $PVC_UID conservé"
  elif [[ -z "$PVC_UID" ]]; then
    rec T-RETRAIT-PVC NOT_TESTED "aucun PVC créé (voir T-READD)"
  else
    rec T-RETRAIT-PVC FAIL "retrait par Git (contrat : prune sur Project/PRB/RB, Prune=false sur Component/CR) : namespace cellule supprimé en ${tg}s, PVC $PVC_UID SUPPRIMÉ, PV '${pv_now:-supprimé}' (local-path reclaimPolicy Delete) : données perdues"
  fi
  evs RECON "${RECON[*]}"
}

cleanup() {
  log "nettoyage"
  local t0; t0=$(date +%s)
  k -n argocd delete app gl-apps gl-platform --ignore-not-found --wait=true >/dev/null 2>&1 || true
  # Objets OpenChoreo de gl-oc : finalizers du contrôleur (Component, bindings) ; mesure du temps.
  k -n gl-oc delete releasebinding,projectreleasebinding,component,workload,project --all --wait=false >/dev/null 2>&1 || true
  local t; t=$(wait_until 300 bash -c "[[ -z \$(kubectl -n gl-oc get releasebinding,projectreleasebinding,component,workload,project -o name 2>/dev/null) ]]") || true
  k -n gl-oc delete componentrelease,environment,deploymentpipeline --all --wait=true >/dev/null 2>&1 || true
  if [[ "$t" == timeout ]]; then
    ev T-FINALIZERS k -n gl-oc get releasebinding,projectreleasebinding,component,workload,project -o jsonpath='{range .items[*]}{.kind}/{.metadata.name} {.metadata.finalizers}{"\n"}{end}'
    rec T-FINALIZERS FAIL "objets gl-oc bloqués par finalizers après 300s (voir evidence)"
  else rec T-FINALIZERS PASS "suppression des objets OpenChoreo gl-oc (finalizers) en ${t}s"; fi
  for ns in $(k get ns -o name | sed -n 's#^namespace/\(dp-gl-oc-.*\)#\1#p'); do k delete ns "$ns" --wait=true >/dev/null 2>&1 || true; done
  # Retrait de l'annotation de suivi Argo sur les objets plateforme partagés (non supprimés).
  for o in $(k get clustercomponenttype,clusterprojecttype,clusterresourcetype,clustertrait,validatingadmissionpolicy,validatingadmissionpolicybinding -o name); do
    k annotate "$o" argocd.argoproj.io/tracking-id- >/dev/null 2>&1 || true
  done
  helm uninstall argocd -n argocd >/dev/null 2>&1 || true
  k delete -f "$HERE/bootstrap/01-git-server.yaml" --ignore-not-found >/dev/null 2>&1 || true
  k delete appproject gl -n argocd --ignore-not-found >/dev/null 2>&1 || true
  k delete ns argocd gl-git gl-oc --ignore-not-found --wait=true >/dev/null 2>&1 || true
  k get crd -o name | grep argoproj.io | xargs -r kubectl delete >/dev/null 2>&1 || true
  log "nettoyage terminé en $(( $(date +%s)-t0 ))s"
}

main() {
  preflight
  case "${1:-all}" in
    all)
      : >"$EVID/results.tsv"; rm -f "$EVID"/T-*.txt "$EVID"/RECON.txt
      RECON=(); local s; s=$(date +%s)
      { echo "# k3d — $(ts)"; k version -o json | python3 -c 'import json,sys;print("kubernetes",json.load(sys.stdin)["serverVersion"]["gitVersion"])';
        k -n openchoreo-control-plane get deploy controller-manager -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'; echo "argo-cd chart $ARGOCD_VERSION"; } >"$EVID/VERSIONS.txt"
      bootstrap
      cycle
      evs RECON "durée totale run.sh : $(( $(date +%s)-s ))s"
      ;;
    cleanup) cleanup ;;
    *) echo "usage: $0 [all|cleanup]" >&2; exit 2 ;;
  esac
}
main "$@"
