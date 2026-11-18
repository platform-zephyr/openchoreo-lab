#!/usr/bin/env bash
# Hook PostToolUse (Edit|Write|MultiEdit) : lint du fichier touché (T-331, SL-5).
# Entrée : JSON sur stdin (tool_input.file_path). Appelle `tools/dev/check --file` (L0, < 2 s).
# rc 0 : PASS ou NOT_TESTED ; rc 2 + stderr : FAIL (PostToolUse ne bloque pas, il renvoie le message à l'agent).
# Aucun réseau, aucun cluster ; sortie sans valeur sensible.
set -u
command -v jq >/dev/null 2>&1 || exit 0
input="$(cat)"
f="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[[ -n "$f" ]] || exit 0
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
[[ -f "$f" ]] || exit 0
rel="$(realpath -m --relative-to="$root" "$f" 2>/dev/null)" || exit 0
case "$rel" in ../*) exit 0 ;; esac
out="$(cd "$root" && timeout 20 tools/dev/check --file "$rel" 2>&1)"
rc=$?
if [[ "$rc" -eq 2 ]]; then
  {
    echo "T-331 post-edit : le contrôle L0 de $rel est FAIL. Corriger avant de poursuivre."
    printf '%s\n' "$out" | grep -vE '^(PASS|NOT_TESTED|SKIP|--|==|RESULT)' | head -30
  } >&2
  exit 2
fi
exit 0
