#!/usr/bin/env bash
# tests/idp-demo/run.sh : démonstration « déploiement initié via la plateforme » (docs/IDP-USABLE.md §3).
#
# Chaîne : intention -> apps/<nom>/app.yaml -> appgen -> PR -> CI -> merge -> Argo CD -> preuve runtime
#         -> modification (size) -> preuve -> rollback par git revert (PR) -> preuve.
#
# GARDE-FOUS
#   - DRY_RUN=1 par défaut : aucune écriture distante (pas de push, pas de PR, pas de merge). Les commandes
#     qui écriraient sont affichées, pas exécutées. Les écritures LOCALES (branche, apps/<nom>/, generated/)
#     restent limitées au périmètre autorisé par AGENTS.md.
#   - Cluster : LECTURE SEULE. Seul `kubectl get` (via le wrapper k() de golden-paths/_checks/_lib.sh) et les
#     checks golden-path (lecture seule) sont utilisés. Aucun apply, patch, exec, port-forward ni secret lu.
#   - Contexte explicite obligatoire : KUBE_CONTEXT=context-oracle-a1-* avec CLUSTER_LABEL=oke, ou
#     KUBE_CONTEXT=k3d-openchoreo avec CLUSTER_LABEL=k3d. Jamais le kubeconfig personnel.
#   - Le merge exige CONFIRM_MERGE_PR=<numéro de la PR>, saisi par le coordinateur après l'accord de Paul
#     (platform-guardrails §1 : cluster oke = REVUE). La PR de rollback suit le même régime.
#   - Aucun secret, jeton ou valeur de Secret dans les sorties ; les preuves vont dans EVID (hors Git par défaut).
#
# USAGE (le coordinateur exécute ; voir docs/IDP-USABLE.md §3 pour l'ordre et les preuves attendues)
#   tests/idp-demo/run.sh plan   NOM IMAGE@sha256:…     # branche idp-demo/NOM-<ts>, apps/NOM/app.yaml, appgen
#   tests/idp-demo/run.sh resize NOM small|medium        # modification : size (AUTONOME, platform-guardrails §1) ;
#                                                        # hors branche idp-demo/NOM-*, part d'origin/main
#   DRY_RUN=0 tests/idp-demo/run.sh pr NOM "MESSAGE"     # commit, push, PR non brouillon, attente des checks CI
#   DRY_RUN=0 CONFIRM_MERGE_PR=N tests/idp-demo/run.sh merge N
#   KUBE_CONTEXT=… CLUSTER_LABEL=oke tests/idp-demo/run.sh observe NOM SHA_DU_MERGE   # lecture seule
#   DRY_RUN=0 tests/idp-demo/run.sh revert NOM SHA_DU_MERGE   # PR de rollback (git revert) ; puis merge + observe
#
# SORTIE : EVID (défaut evidence/idp-demo/<CLUSTER_LABEL>/<NOM>/<UTC>/) avec summary.txt (une ligne par étape :
# ID|PASS|FAIL|BLOCKED|NOT_TESTED|DRY_RUN|détail) et les sorties brutes de chaque étape.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
DRY_RUN="${DRY_RUN:-1}"
CLUSTER_LABEL="${CLUSTER_LABEL:-oke}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
CMD="${1:-}"
NAME="${2:-}"
EVID="${EVID_DIR:-}"
TEMPLATE="apps/whoami/app.yaml"   # gabarit d'archétype A (stateless, digest épinglé, exposition private)
NAME_RE='^[a-z][a-z0-9-]{1,30}[a-z0-9]$'
DIGEST_RE='^[a-z0-9][a-z0-9./_-]*(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$'

die() { printf 'ABANDON : %s\n' "$*" >&2; exit 2; }
log() { printf '%s %s\n' "$(date -u +%H:%M:%SZ)" "$*" >&2; }

# Journal de preuve : une ligne par étape, lisible par le coordinateur, sans secret.
rec() {
  local line="$1|$2|$3"
  printf '%s\n' "$line"
  if [ -n "$EVID" ]; then mkdir -p "$EVID"; printf '%s\n' "$line" >>"$EVID/summary.txt"; fi
}

# Écriture distante : affichée seulement si DRY_RUN=1.
wet() {
  if [ "$DRY_RUN" = 1 ]; then printf '[DRY_RUN] %s\n' "$*" >&2; return 0; fi
  "$@"
}

# Lecture cluster : garde de contexte puis wrapper read-only de golden-paths/_checks/_lib.sh.
cluster_guard() {
  case "$CLUSTER_LABEL" in
    oke)  case "${KUBE_CONTEXT:-}" in context-oracle-a1-*) ;; *) die "oke : KUBE_CONTEXT doit être context-oracle-a1-* (reçu '${KUBE_CONTEXT:-}')" ;; esac ;;
    k3d)  [ "${KUBE_CONTEXT:-}" = k3d-openchoreo ] || die "k3d : KUBE_CONTEXT doit être k3d-openchoreo" ;;
    *)    die "CLUSTER_LABEL invalide : $CLUSTER_LABEL" ;;
  esac
  case "$KUBE_CONTEXT" in *homeops*) die "contexte personnel refusé" ;; esac
  export CLUSTER_LABEL KUBE_CONTEXT
  # shellcheck source=../../golden-paths/_checks/_lib.sh
  . "$ROOT/golden-paths/_checks/_lib.sh"
}

need_name() { [[ "$NAME" =~ $NAME_RE ]] || die "nom d'application invalide : '$NAME'"; }

set_evid() {
  # Hors du dépôt par défaut : une preuve ne doit pas être commitée par accident (scope_guard).
  EVID="${EVID_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/openchoreo-lab/idp-demo/$CLUSTER_LABEL/$NAME/$TS}"
  mkdir -p "$EVID"
  log "preuves : ${EVID#"$ROOT"/}"
}

appgen_gate() { # validate + render + check (dérive = échec) ; sorties dans EVID
  local out="$EVID/appgen-$1.txt"
  if python3 tools/appgen/appgen.py validate >"$out" 2>&1 \
     && python3 tools/appgen/appgen.py render >>"$out" 2>&1 \
     && python3 tools/appgen/appgen.py check >>"$out" 2>&1; then
    rec "APPGEN-$1" PASS "validate, render, check sans dérive"
  else
    rec "APPGEN-$1" FAIL "voir ${out#"$ROOT"/}"; return 1
  fi
}

# Périmètre Git attendu : apps/<nom>/, generated/ et l'entrée sources[] de lab-apps.yaml (gardée par argo_guard).
scope_guard() {
  local bad
  bad="$(git status --porcelain | awk '{print $2}' | grep -Ev "^(apps/$NAME/|generated/|platform/install/argocd/apps/lab-apps.yaml$)" || true)"
  [ -z "$bad" ] || die "modifications hors périmètre : $bad"
}

cmd_plan() {
  need_name
  [[ "${3:-}" =~ $DIGEST_RE ]] || die "image sans digest : '${3:-}' (format nom:tag@sha256:…)"
  local image="$3" br="idp-demo/$NAME-$TS"
  [ -f "$TEMPLATE" ] || die "gabarit absent : $TEMPLATE"
  [ ! -e "apps/$NAME" ] || die "apps/$NAME existe déjà"
  set_evid
  git fetch --quiet origin main 2>/dev/null || log "fetch origin impossible : base locale"
  git switch -q -c "$br" origin/main 2>/dev/null || git switch -q -c "$br" HEAD
  mkdir -p "apps/$NAME"
  # Intention -> contrat : seuls le nom, la description et l'image changent ; le reste du gabarit est conservé.
  sed -e "s/^  name: whoami$/  name: $NAME/" \
      -e "s/^  description: .*/  description: Démo IDP $NAME (tests\/idp-demo, $TS)/" \
      -e "s|^    image: .*|    image: $image|" "$TEMPLATE" >"apps/$NAME/app.yaml"
  if ! grep -q "^  name: $NAME$" "apps/$NAME/app.yaml" || ! grep -q "image: $image" "apps/$NAME/app.yaml"; then
    rm -rf "apps/$NAME"; die "gabarit non rempli (format de $TEMPLATE changé ?)"
  fi
  rec PLAN-INTENT PASS "archétype A (gabarit whoami), image digest-épinglée, branche $br"
  appgen_gate plan
  rec PLAN-CLASS PASS "AUTONOME sur k3d ; sur oke : REVUE (cluster oke) => merge soumis à CONFIRM_MERGE_PR"
  log "étape plan terminée ; prochaine étape : DRY_RUN=0 tests/idp-demo/run.sh pr $NAME \"...\""
}

cmd_resize() {
  need_name
  local size="${3:-}"
  [[ "$size" == small || "$size" == medium ]] || die "taille invalide : '$size'"
  set_evid
  if [[ "$(git branch --show-current)" != idp-demo/$NAME-* ]]; then
    # Modification après merge : nouvelle branche depuis origin/main (jamais sur main).
    git fetch --quiet origin main
    git switch -q -c "idp-demo/$NAME-$TS" origin/main
  fi
  [ -f "apps/$NAME/app.yaml" ] || die "apps/$NAME/app.yaml absent (lancer plan d'abord)"
  sed -i.bak -e "s/^    size: .*/    size: $size/" "apps/$NAME/app.yaml" && rm -f "apps/$NAME/app.yaml.bak"
  grep -q "^    size: $size$" "apps/$NAME/app.yaml" || die "taille non appliquée"
  rec RESIZE PASS "runtime.size = $size (modification de test, AUTONOME)"
  appgen_gate resize
}

cmd_pr() {
  need_name
  local msg="${3:-modification $NAME}" br; br="$(git branch --show-current)"
  [[ "$br" == idp-demo/$NAME-* ]] || die "branche courante '$br' : attendu idp-demo/$NAME-*"
  set_evid
  scope_guard
  git add "apps/$NAME" generated
  git commit -q -m "$NAME: $msg" -m "Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>"
  wet git push -q -u origin HEAD
  printf '%s\n' "Démonstration tests/idp-demo (intention $NAME, preuves dans $EVID)." \
    "Périmètre : apps/$NAME/ et generated/ uniquement. Aucune écriture cluster." \
    "" "🤖 Generated with [Claude Code](https://claude.com/claude-code)" >"$EVID/pr-body.md"
  if [ "$DRY_RUN" = 1 ]; then
    rec PR DRY_RUN "gh pr create --title '$NAME: $msg' (non brouillon)"; return 0
  fi
  local url; url="$(gh pr create --base main --title "$NAME: $msg" --body-file "$EVID/pr-body.md")"
  printf '%s\n' "$url" >"$EVID/pr-url.txt"
  rec PR PASS "$url"
  if gh pr checks "$url" --watch --fail-fast >"$EVID/ci.txt" 2>&1; then
    rec CI PASS "checks requis verts (gh pr checks)"
  else
    rec CI FAIL "voir ${EVID#"$ROOT"/}/ci.txt ; corriger dans la même branche"; return 1
  fi
}

cmd_merge() {
  local pr="${2:-}"
  [[ "$pr" =~ ^[0-9]+$ ]] || die "numéro de PR attendu"
  NAME="pr-$pr"
  [ "${CONFIRM_MERGE_PR:-}" = "$pr" ] || die "merge refusé : CONFIRM_MERGE_PR=$pr requis (accord de Paul, REVUE oke)"
  set_evid
  if [ "$DRY_RUN" = 1 ]; then rec MERGE DRY_RUN "gh pr merge $pr --squash --delete-branch"; return 0; fi
  gh pr merge "$pr" --squash --delete-branch >/dev/null
  local sha; sha="$(gh pr view "$pr" --json mergeCommit --jq .mergeCommit.oid)"
  rec MERGE PASS "PR #$pr squash, SHA $sha"
  printf '%s\n' "$sha" >"$EVID/merge-sha.txt"
}

cmd_observe() {
  need_name
  local sha="${3:-}" argo_rev="" i
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "SHA de merge complet attendu"
  set_evid
  cluster_guard
  # 1. Argo CD : l'Application lab-apps a synchronisé le SHA du merge (lecture).
  for ((i = 0; i < 40; i++)); do
    argo_rev="$(k get applications.argoproj.io -n "$ARGOCD_NS" lab-apps -o jsonpath='{.status.sync.revision}{.status.sync.revisions[0]}' 2>/dev/null || true)"
    [ "$argo_rev" = "$sha" ] && break
    sleep 15
  done
  local st; st="$(k get applications.argoproj.io -n "$ARGOCD_NS" lab-apps -o jsonpath='{.status.sync.status} {.status.health.status}' 2>/dev/null || true)"
  if [ "$argo_rev" = "$sha" ]; then
    rec ARGO-SYNC PASS "lab-apps révision = $sha ($st)"
  else
    rec ARGO-SYNC FAIL "révision '$argo_rev' != $sha après 10 min ($st)"; return 1
  fi
  # 2. Preuve runtime golden-path (lecture seule) : Argo, ReleaseBinding, Ready, digest, HTTP.
  set +e
  "$ROOT/golden-paths/_checks/run-all.sh" "$NAME" production --evidence "$EVID/runtime" >"$EVID/run-all.txt" 2>&1
  local rc=$?
  set -e
  local verdict; verdict="$(grep -m1 -o 'verdict: *[A-Z]*' "$EVID/run-all.txt" || echo 'verdict: inconnu')"
  case "$rc" in
    0) rec RUNTIME PASS "$verdict (run-all, $CLUSTER_LABEL, $KUBE_CONTEXT)" ;;
    3) rec RUNTIME PARTIAL "$verdict : BLOCKED/NOT_TESTED à expliquer" ;;
    *) rec RUNTIME FAIL "$verdict (code $rc) : voir ${EVID#"$ROOT"/}/run-all.txt"; return 1 ;;
  esac
}

cmd_revert() {
  need_name
  local sha="${3:-}" br
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "SHA de merge complet attendu"
  br="revert/$NAME-${sha:0:7}-$TS"
  set_evid
  wet git fetch --quiet origin main
  if [ "$DRY_RUN" = 1 ]; then
    rec REVERT DRY_RUN "git switch -c $br origin/main ; git revert --no-edit $sha ; gh pr create"; return 0
  fi
  git switch -q -c "$br" origin/main
  git revert --no-edit "$sha" >/dev/null
  appgen_gate revert
  git push -q -u origin HEAD
  local url; url="$(gh pr create --base main --title "revert: $NAME ${sha:0:7}" \
    --body "Rollback de ${sha:0:7} (git revert). Preuve de la régression et du retour : tests/idp-demo, $EVID.")"
  printf '%s\n' "$url" >"$EVID/revert-pr-url.txt"
  rec REVERT PASS "$url"
}

case "$CMD" in
  plan)    cmd_plan "$@" ;;
  resize)  cmd_resize "$@" ;;
  pr)      cmd_pr "$@" ;;
  merge)   cmd_merge "$@" ;;
  observe) cmd_observe "$@" ;;
  revert)  cmd_revert "$@" ;;
  *) die "usage : plan|resize|pr|merge|observe|revert (voir l'en-tête du script)" ;;
esac
