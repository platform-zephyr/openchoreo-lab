#!/usr/bin/env bash
# Hook PreToolUse (Edit|Write|MultiEdit|NotebookEdit) : garde de périmètre (T-331, SL-5). Refus : rc 2 + stderr.
#  1. STATE.md et backlog/ROADMAP.md : écriture refusée hors session coordinatrice (LAB_COORDINATOR_SESSION=1).
#  2. generated/ : produit par tools/appgen, jamais édité à la main (comme permissions.deny).
#  3. Si AGENT_TICKET_SCOPE est posée (globs séparés par des virgules, `*` traverse les `/`, un élément finissant par
#     `/` couvre le dossier), tout fichier hors périmètre est refusé. Le fichier du ticket (AGENT_TICKET_ID=T-NNN :
#     backlog/T-NNN-*.md et backlog/evidence/T-NNN-*) reste modifiable. Variable absente : pas de limite de périmètre.
# Le périmètre vient de la section `Périmètre de fichiers` du ticket (l'exécutant la copie dans la variable).
set -u
deny() { echo "T-331 garde de périmètre : refusé : $1" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || deny "jq absent (le garde échoue fermé)"
input="$(cat)"
f="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)" || deny "entrée illisible"
[[ -n "$f" ]] || exit 0
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[[ "$f" == /* ]] || f="${cwd:-$root}/$f"
rel="$(realpath -m --relative-to="$root" "$f" 2>/dev/null)" || deny "chemin illisible"

case "$rel" in
  STATE.md | backlog/ROADMAP.md)
    [[ "${LAB_COORDINATOR_SESSION:-}" == "1" ]] || deny "$rel est réservé à la session coordinatrice" ;;
  generated | generated/*) deny "generated/ est produit par tools/appgen (ne pas éditer à la main)" ;;
esac

scope="${AGENT_TICKET_SCOPE:-}"
if [[ -n "$scope" ]]; then
  [[ "$rel" != ../* && "$rel" != .. ]] || deny "$f est hors du dépôt (périmètre du ticket posé)"
  id="${AGENT_TICKET_ID:-}"
  if [[ -n "$id" ]]; then
    # shellcheck disable=SC2053  # motifs voulus : globs du ticket
    [[ "$rel" == backlog/$id-*.md || "$rel" == backlog/evidence/$id-* ]] && exit 0
  fi
  IFS=',' read -r -a items <<<"$scope"
  for it in "${items[@]}"; do
    it="${it#"${it%%[![:space:]]*}"}"
    it="${it%"${it##*[![:space:]]}"}"
    [[ -n "$it" ]] || continue
    if [[ "$it" == */ ]]; then
      [[ "$rel" == "$it"* ]] && exit 0
    else
      # shellcheck disable=SC2053
      [[ "$rel" == $it || "$rel" == "$it"/* ]] && exit 0
    fi
  done
  deny "$rel est hors du périmètre du ticket (AGENT_TICKET_SCOPE)"
fi
exit 0
