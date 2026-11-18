#!/usr/bin/env bash
# Construit la matrice des issues a traiter pour claude-agent.yml (T-311).
# Entrees (variables d'environnement, jamais interpolees dans le YAML) :
#   TICKETS      numeros d'issues separes par virgules ou espaces (workflow_dispatch) ;
#   EVENT_ISSUE  numero de l'issue etiquetee (evenement `issues`), utilise si TICKETS est vide ;
#   MAX_TICKETS  plafond de la liste (defaut 20).
# Sortie : JSON {"issue":[...]} sur stdout et `matrix=...` dans $GITHUB_OUTPUT si defini. Echec si un jeton n'est pas un entier.
set -euo pipefail
raw="${TICKETS:-}"
[[ -n "${raw//[[:space:],]/}" ]] || raw="${EVENT_ISSUE:-}"
max="${MAX_TICKETS:-20}"
list=()
for tok in $(printf '%s' "$raw" | tr ',' ' '); do
  [[ "$tok" =~ ^[0-9]+$ ]] || { echo "numero d'issue invalide : '${tok}'" >&2; exit 2; }
  list+=("$((10#$tok))")
done
((${#list[@]} > 0)) || { echo "aucune issue a traiter" >&2; exit 2; }
mapfile -t uniq < <(printf '%s\n' "${list[@]}" | awk '!seen[$0]++')
((${#uniq[@]} <= max)) || { echo "plus de ${max} issues dans un dispatch" >&2; exit 2; }
json="{\"issue\":[$(IFS=,; echo "${uniq[*]}")]}"
echo "$json"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "matrix=${json}" >>"$GITHUB_OUTPUT"; fi
