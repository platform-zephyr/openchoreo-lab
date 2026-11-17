#!/usr/bin/env bash
# verify-change.sh : prouve que la modification (WHOAMI_NAME) est livree par GitOps ET visible en HTTP.
#
# Pre-requis : la PR de changement (tests/golden-path-whoami/change.patch) est MERGEE. CHANGE_SHA = commit de
# merge sur main ; BASE_SHA = commit juste avant (baseline). verify-http.sh doit etre PASS avant le changement.
#
# Usage :
#   KUBECONFIG=<kubeconfig OKE> CHANGE_SHA=<sha> BASE_SHA=<sha> \
#     [CHANGE_NAME=whoami-gitops-oke-v2] [TIMEOUT=900] [INTERVAL=20] tests/golden-path-whoami/verify-change.sh
# Effets : ecrit uniquement l'UID de la release baseline dans $WHOAMI_STATE_DIR (hors depot), pour verify-rollback.sh.
# Code retour : 0 PASS ; 1 FAIL ; 2 BLOCKED ; 3 PARTIAL.
#
# shellcheck source=common.sh source-path=SCRIPTDIR
. "$(dirname "$0")/common.sh"

HERE="$(cd "$(dirname "$0")" && pwd)"
CHANGE_SHA="${CHANGE_SHA:-}"; BASE_SHA="${BASE_SHA:-}"
CHANGE_NAME="${CHANGE_NAME:-whoami-gitops-oke-v2}"
TIMEOUT="${TIMEOUT:-900}"; INTERVAL="${INTERVAL:-20}"

print_header
if [ -z "$CHANGE_SHA" ] || [ -z "$BASE_SHA" ]; then
  rec BLOCKED C0 "CHANGE_SHA et BASE_SHA sont requis"; verdict; exit 2
fi
for c in "$CHANGE_SHA" "$BASE_SHA"; do
  if ! git -C "$REPO_ROOT" cat-file -e "$c^{commit}" 2>/dev/null; then
    rec BLOCKED C0 "commit $c inconnu du clone local (git fetch origin main)"; verdict; exit 2
  fi
done

# C1 : coherence statique (Git) : le commit de changement porte la valeur, et une autre release que la base.
want_rel="$(release_of_rev "$CHANGE_SHA")"
base_rel="$(release_of_rev "$BASE_SHA")"
if git_show "$CHANGE_SHA" "apps/$WHOAMI_APP/app.yaml" | grep -qF "WHOAMI_NAME: \"$CHANGE_NAME\""; then
  rec PASS C1 "apps/$WHOAMI_APP/app.yaml au commit de changement porte WHOAMI_NAME=$CHANGE_NAME"
else
  rec FAIL C1 "WHOAMI_NAME=$CHANGE_NAME absent de app.yaml au commit $CHANGE_SHA"
fi
if [ -n "$want_rel" ] && [ "$want_rel" != "$base_rel" ]; then
  rec PASS C1 "release de changement ($want_rel) differe de la baseline ($base_rel)"
else
  rec FAIL C1 "release de changement ('$want_rel') non distincte de la baseline ('$base_rel')"
fi

preflight || { verdict; exit 2; }
NS="$(cell_ns)"
if [ -z "$NS" ]; then rec FAIL C2 "cellule introuvable"; verdict; exit 1; fi

# C2 : avant le changement, le cluster sert la baseline ; on enregistre l'UID de sa release (preuve de non-recreation).
live_before="$(k get releasebindings.openchoreo.dev "$WHOAMI_APP-$WHOAMI_ENV" -n "$OC_NS" -o jsonpath='{.spec.releaseName}' 2>/dev/null || true)"
if [ "$live_before" = "$base_rel" ]; then
  rec PASS C2 "etat avant changement = baseline ($base_rel)"
else
  rec FAIL C2 "etat avant changement != baseline (live='$live_before', attendu='$base_rel') : ne pas poursuivre"
  verdict; exit 1
fi
uid="$(k get componentreleases.openchoreo.dev "$base_rel" -n "$OC_NS" -o jsonpath='{.metadata.uid}' 2>/dev/null || true)"
mkdir -p "$WHOAMI_STATE_DIR"
UID_FILE="$WHOAMI_STATE_DIR/$WHOAMI_APP-$WHOAMI_ENV-baseline-release.txt"
if [ -z "$uid" ]; then
  rec FAIL C2 "ComponentRelease baseline $base_rel absente : rollback non prouvable"
elif [ -f "$UID_FILE" ] && [ "$(cut -d' ' -f2 "$UID_FILE")" != "$uid" ]; then
  rec FAIL C2 "UID baseline different de celui deja enregistre hors depot"
else
  printf '%s %s\n' "$base_rel" "$uid" > "$UID_FILE"
  rec PASS C2 "UID de la release baseline enregistre hors depot (preuve pour le rollback)"
fi

# C3 : attendre la convergence (Argo revision = CHANGE_SHA, RB = release de changement, pod et HTTP refletent la valeur).
export EXPECT_REVISION="$CHANGE_SHA" EXPECT_RELEASE="$want_rel" EXPECT_NAME="$CHANGE_NAME"
rec INFO C3 "attente de convergence (TIMEOUT=${TIMEOUT}s, pas ${INTERVAL}s)"
if wait_converge "$TIMEOUT" "$INTERVAL" "$HERE/verify-http.sh"; then
  rec PASS C3 "convergence atteinte (rc=$LAST_RC) : revision, release, pod et HTTP refletent $CHANGE_NAME"
else
  if [ "$LAST_RC" = 2 ]; then rec BLOCKED C3 "verify-http.sh bloque (rc=2)"; else rec FAIL C3 "pas de convergence dans ${TIMEOUT}s"; fi
fi
echo "--- dernier etat (verify-http.sh) ---"
printf '%s\n' "$LAST_OUT"
echo "--- fin dernier etat ---"
verdict
