#!/usr/bin/env bash
# verify-rollback.sh : prouve le retour a l'etat initial apres `git revert` du changement.
#
# Pre-requis : PR de revert MERGEE (REVERT_SHA = commit de merge du revert sur main). CHANGE_SHA = commit du changement,
# BASE_SHA = commit avant le changement (etat d'origine). verify-change.sh doit avoir ete execute (UID baseline).
#
# Preuves :
#   Git  : app.yaml et generated/ de REVERT_SHA identiques a BASE_SHA (blobs), release d'origine presente.
#   Live : ReleaseBinding = release d'origine ; meme UID de ComponentRelease qu'avant le changement (objet non
#          recree, donc hash et contenu inchanges) ; pod sans WHOAMI_NAME ; HTTP 200 sans « Name: <CHANGE_NAME> ».
#
# Usage :
#   KUBECONFIG=<kubeconfig OKE> REVERT_SHA=<sha> CHANGE_SHA=<sha> BASE_SHA=<sha> \
#     [CHANGE_NAME=whoami-gitops-oke-v2] [TIMEOUT=900] [INTERVAL=20] tests/golden-path-whoami/verify-rollback.sh
# Code retour : 0 PASS ; 1 FAIL ; 2 BLOCKED ; 3 PARTIAL.
#
# shellcheck source=common.sh source-path=SCRIPTDIR
. "$(dirname "$0")/common.sh"

HERE="$(cd "$(dirname "$0")" && pwd)"
REVERT_SHA="${REVERT_SHA:-}"; CHANGE_SHA="${CHANGE_SHA:-}"; BASE_SHA="${BASE_SHA:-}"
CHANGE_NAME="${CHANGE_NAME:-whoami-gitops-oke-v2}"
TIMEOUT="${TIMEOUT:-900}"; INTERVAL="${INTERVAL:-20}"

print_header
if [ -z "$REVERT_SHA" ] || [ -z "$CHANGE_SHA" ] || [ -z "$BASE_SHA" ]; then
  rec BLOCKED R0 "REVERT_SHA, CHANGE_SHA et BASE_SHA sont requis"; verdict; exit 2
fi
for c in "$REVERT_SHA" "$CHANGE_SHA" "$BASE_SHA"; do
  if ! git -C "$REPO_ROOT" cat-file -e "$c^{commit}" 2>/dev/null; then
    rec BLOCKED R0 "commit $c inconnu du clone local (git fetch origin main)"; verdict; exit 2
  fi
done

# R1 : Git. Le revert ne laisse aucune trace du changement et rend exactement la base.
if git_show "$REVERT_SHA" "apps/$WHOAMI_APP/app.yaml" | grep -qF "WHOAMI_NAME"; then
  rec FAIL R1 "WHOAMI_NAME encore present dans app.yaml au commit de revert"
else
  rec PASS R1 "WHOAMI_NAME absent de app.yaml au commit de revert"
fi
APP_PATH="apps/$WHOAMI_APP/app.yaml"
if [ -n "$(git_blob "$BASE_SHA" "$APP_PATH")" ] && [ "$(git_blob "$BASE_SHA" "$APP_PATH")" = "$(git_blob "$REVERT_SHA" "$APP_PATH")" ]; then
  rec PASS R1 "app.yaml du revert identique (blob) a la base"
else
  rec FAIL R1 "app.yaml du revert different de la base"
fi
if git -C "$REPO_ROOT" diff --quiet "$BASE_SHA" "$REVERT_SHA" -- "generated/namespaces/default/projects/$WHOAMI_APP" "$APP_PATH"; then
  rec PASS R2 "arbre whoami (generated/ + app.yaml) identique entre la base et le revert"
else
  rec FAIL R2 "arbre whoami different entre la base et le revert"
fi

base_rel="$(release_of_rev "$BASE_SHA")"
rev_rel="$(release_of_rev "$REVERT_SHA")"
if [ -n "$base_rel" ] && [ "$base_rel" = "$rev_rel" ]; then
  rec PASS R3 "release d'origine $base_rel reapparait au commit de revert"
else
  rec FAIL R3 "release du revert ('$rev_rel') != release d'origine ('$base_rel')"
fi
rel_path="generated/namespaces/default/projects/$WHOAMI_APP/components/$WHOAMI_APP/releases/$base_rel.yaml"
if [ -n "$(git_blob "$BASE_SHA" "$rel_path")" ] && [ "$(git_blob "$BASE_SHA" "$rel_path")" = "$(git_blob "$REVERT_SHA" "$rel_path")" ]; then
  rec PASS R3 "fichier de release d'origine identique (blob) a la base : hash de contenu inchange"
else
  rec FAIL R3 "fichier de release d'origine absent ou different"
fi

# Live : preuves runtime (necessitent verify-change.sh pour l'UID de reference).
UID_FILE="$WHOAMI_STATE_DIR/$WHOAMI_APP-$WHOAMI_ENV-baseline-release.txt"
if [ ! -f "$UID_FILE" ] || [ "$(cut -d' ' -f1 "$UID_FILE")" != "$base_rel" ]; then
  rec NOT_TESTED R4 "UID de reference de la release d'origine absent ($UID_FILE) : objet non recree non prouve"
  ref_uid=""
else
  ref_uid="$(cut -d' ' -f2 "$UID_FILE")"
fi

preflight || { verdict; exit 2; }

export EXPECT_REVISION="$REVERT_SHA" EXPECT_RELEASE="$base_rel" NAME_ABSENT="$CHANGE_NAME"
rec INFO R5 "attente de convergence (TIMEOUT=${TIMEOUT}s, pas ${INTERVAL}s)"
if wait_converge "$TIMEOUT" "$INTERVAL" "$HERE/verify-http.sh"; then
  rec PASS R5 "convergence vers la base atteinte (rc=$LAST_RC)"
else
  if [ "$LAST_RC" = 2 ]; then rec BLOCKED R5 "verify-http.sh bloque (rc=2)"; else rec FAIL R5 "pas de retour a la base dans ${TIMEOUT}s"; fi
fi

if [ -n "$ref_uid" ]; then
  live_uid="$(k get componentreleases.openchoreo.dev "$base_rel" -n "$OC_NS" -o jsonpath='{.metadata.uid}' 2>/dev/null || true)"
  if [ -n "$live_uid" ] && [ "$live_uid" = "$ref_uid" ]; then
    rec PASS R4 "ComponentRelease $base_rel : meme UID qu'avant le changement (objet d'origine, non recree)"
  else
    rec FAIL R4 "ComponentRelease $base_rel : UID different ou absent (live='${live_uid:-absent}')"
  fi
fi
echo "--- dernier etat (verify-http.sh) ---"
printf '%s\n' "$LAST_OUT"
echo "--- fin dernier etat ---"
verdict
