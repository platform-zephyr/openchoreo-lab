#!/usr/bin/env bash
# Étape 11 de tools/oke/install.sh, partie Notifications (T-497), SANS cluster : kubectl FACTICE (PATH) qui journalise
# chaque appel ; une écriture = ligne WRITE. Vérifie : Secret lab-secrets/openchoreo-status absent => message
# « notifications non appliquées : Secret absent », code 0, aucune écriture ; présent => server-side apply
# (field-manager openchoreo-lab) de platform/install/argocd/notifications/ en --apply, affiché seulement en dry-run ;
# lecture en erreur => message, code 0 ; le Secret n'est lu que par `-o name` ; step_11 appelle la fonction après
# root-application. Modèle : tests/security-bundle/run.sh. Usage : tests/status/install-notifications.sh
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/status-notif.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin" LOGF="$WORK/calls.log"
mkdir -p "$BIN"
cat > "$BIN/kubectl" <<'EOK'
#!/usr/bin/env bash
printf 'kubectl %s\n' "$*" >> "$LOGF"
v="$1"; [[ "$1" == -n ]] && v="$3"
case "$v" in delete|apply|label|annotate|patch|create|replace|scale|rollout) printf 'WRITE kubectl %s\n' "$*" >> "$LOGF"; exit 0;; esac
case "$*" in
  "-n lab-secrets get secret openchoreo-status --ignore-not-found -o name")
    case "$FAKE_SECRET" in present) echo secret/openchoreo-status;; absent) ;; error) echo "forbidden" >&2; exit 1;; esac;;
  *) printf 'UNEXPECTED kubectl %s\n' "$*" >> "$LOGF"; exit 1;;
esac
EOK
chmod +x "$BIN/kubectl"
pass=0 fail=0
ok() { pass=$((pass + 1)); printf 'PASS %s\n' "$1"; }
ko() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; sed 's/^/    /' "$WORK/out" "$LOGF" | tail -n 8; }
# envrun SECRET APPLY : appelle apply_status_notifications avec lib.sh et le kubectl factice.
envrun() {
  : > "$LOGF"
  env PATH="$BIN:$PATH" LOGF="$LOGF" FAKE_SECRET="$1" APPLY="$2" OKE_PHASEB_STATE="$WORK/state" \
    bash -c ". '$REPO/tools/oke/lib.sh'; apply_status_notifications" > "$WORK/out" 2>&1
}
writes() { grep -c '^WRITE' "$LOGF" || true; }
secret_reads_ok() { ! grep -E 'secret' "$LOGF" | grep -v '^kubectl -n lab-secrets get secret openchoreo-status --ignore-not-found -o name$' | grep -q .; }
NOTIF_APPLY="WRITE kubectl apply --server-side --field-manager=openchoreo-lab -f $REPO/platform/install/argocd/notifications/"

for mode in 1 0; do
  if envrun absent "$mode" && grep -q 'notifications non appliquées : Secret absent' "$WORK/out" && [[ "$(writes)" == 0 ]] \
     && ! grep -q '\[dry-run\]' "$WORK/out" && secret_reads_ok; then ok "secret-absent[APPLY=$mode] : message, rc 0, aucune écriture"
  else ko "secret-absent[APPLY=$mode]"; fi
done
if envrun error 1 && grep -q 'notifications non appliquées : présence du Secret' "$WORK/out" && [[ "$(writes)" == 0 ]]; then
  ok "lecture-en-erreur : message, rc 0, aucune écriture"; else ko "lecture-en-erreur"; fi
if envrun present 1 && [[ "$(grep '^WRITE' "$LOGF")" == "$NOTIF_APPLY" ]] && secret_reads_ok && ! grep -q UNEXPECTED "$LOGF"; then
  ok "secret-present[--apply] : un seul server-side apply du dossier notifications/"; else ko "secret-present[--apply]"; fi
if envrun present 0 && [[ "$(writes)" == 0 ]] \
   && grep -qx "\[dry-run\] kubectl apply --server-side --field-manager=openchoreo-lab -f $REPO/platform/install/argocd/notifications/" "$WORK/out"; then
  ok "secret-present[dry-run] : apply affiché, aucune écriture"; else ko "secret-present[dry-run]"; fi
# Ordre dans step_11 : après le helm upgrade d'Argo CD et après root-application.
body="$(awk '/^step_11\(\)/,/^}/' "$REPO/tools/oke/install.sh")"
h="$(grep -n 'helm upgrade --install argocd' <<<"$body" | cut -d: -f1)"; r="$(grep -n 'root-application.yaml' <<<"$body" | cut -d: -f1)"
n="$(grep -n '^  apply_status_notifications$' <<<"$body" | cut -d: -f1)"
: > "$WORK/out"; : > "$LOGF"
if [[ -n "$h" && -n "$r" && -n "$n" ]] && (( h < r && r < n )); then ok "step_11 : notifications après Argo CD et la racine"; else ko "step_11 : ordre"; fi
# Aucune lecture de valeur de Secret dans la fonction (ni -o json/yaml/jsonpath, ni describe).
fn="$(awk '/^apply_status_notifications\(\)/,/^}/' "$REPO/tools/oke/lib.sh")"
if grep -q -- '-o name' <<<"$fn" && ! grep -qE -- '-o (json|yaml|jsonpath)|describe|get secrets? [^ ]* -o (json|yaml)' <<<"$fn"; then
  ok "fonction : présence par -o name seulement"; else ko "fonction : lecture du Secret"; fi

printf '%s PASS=%d FAIL=%d\n' "$(date -u +%FT%TZ)" "$pass" "$fail"
(( fail == 0 ))
