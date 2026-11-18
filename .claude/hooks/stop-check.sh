#!/usr/bin/env bash
# Hook Stop : definition of done rapide (T-331, SL-5). `tools/dev/check --fast` puis `tools/dev/leak-guard.sh`
# (le même script que la CI). Bloque (rc 2, message sur stderr) seulement sur FAIL ; NOT_TESTED, erreur d'outil
# (rc 2 de leak-guard : gitleaks absent) et usage incorrect ne bloquent jamais.
# Boucle infinie : si stop_hook_active vaut true (le Stop précédent a déjà relancé l'agent), le hook laisse finir.
# Le plafond de l'amont (CLAUDE_CODE_STOP_HOOK_BLOCK_CAP, 8 blocs consécutifs) reste le second filet.
set -u
command -v jq >/dev/null 2>&1 || exit 0
input="$(cat)"
[[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" == "true" ]] && exit 0
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$root" || exit 0
msg=""
out="$(timeout 60 tools/dev/check --fast 2>&1)"
rc=$?
if [[ "$rc" -eq 1 ]]; then
  msg+="check --fast : FAIL"$'\n'"$(printf '%s\n' "$out" | grep -vE '^(PASS|NOT_TESTED|SKIP)' | head -30)"$'\n'
fi
if [[ -x tools/dev/leak-guard.sh ]]; then
  lg="$(timeout 60 tools/dev/leak-guard.sh 2>&1)"
  lrc=$?
  # 0 = rien, 1 = fuite(s) (FAIL), autre = erreur d'outil (NOT_TESTED : ne bloque pas).
  if [[ "$lrc" -eq 1 ]]; then
    msg+="leak-guard : FAIL (valeurs masquées)"$'\n'"$(printf '%s\n' "$lg" | head -20)"$'\n'
  fi
fi
if [[ -n "$msg" ]]; then
  { echo "T-331 Stop : corriger avant de terminer (NOT_TESTED ne bloque pas)."; printf '%s' "$msg"; } >&2
  exit 2
fi
exit 0
