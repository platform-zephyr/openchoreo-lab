#!/usr/bin/env bash
# Hook SessionStart (startup, resume) : une ligne `tools/dev/doctor` ajoutée au contexte (T-331, SL-5). Ne bloque jamais.
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$root" 2>/dev/null || exit 0
[[ -x tools/dev/doctor ]] || { echo "doctor : NOT_TESTED (tools/dev/doctor absent)"; exit 0; }
out="$(timeout 4 tools/dev/doctor 2>&1)"
rc=$?
if [[ "$rc" -eq 124 ]]; then echo "doctor : NOT_TESTED (délai de 4 s dépassé)"; exit 0; fi
sum="$(printf '%s\n' "$out" | grep -E '^-- ' | tail -n1)"
res="$(printf '%s\n' "$out" | grep -E '^RESULT' | tail -n1)"
echo "doctor : ${sum#-- } | ${res:-RESULT ?} (détail : tools/dev/doctor)"
exit 0
