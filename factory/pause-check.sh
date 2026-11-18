#!/usr/bin/env bash
# Kill-switch de l'usine (ADR-0021, T-311) : la presence de factory/PAUSE arrete tout lancement et tout merge automatique.
# Sortie : 0 = usine active ; 10 = en pause. Ecrit `paused=true|false` dans $GITHUB_OUTPUT si defini.
# PAUSE_REF=<ref git> : lit le fichier dans cette ref (ex. origin/main) au lieu de l'arbre de travail.
# Aucune lecture de secret. Usage : factory/pause-check.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
PAUSE_FILE="factory/PAUSE"
paused=false
if [[ -n "${PAUSE_REF:-}" ]]; then
  if git cat-file -e "${PAUSE_REF}:${PAUSE_FILE}" 2>/dev/null; then paused=true; fi
elif [[ -e "$PAUSE_FILE" ]]; then
  paused=true
fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "paused=${paused}" >>"$GITHUB_OUTPUT"; fi
if [[ "$paused" == true ]]; then
  echo "PAUSE: ${PAUSE_FILE} present, aucun lancement ni merge automatique"
  exit 10
fi
echo "ACTIF: ${PAUSE_FILE} absent"
