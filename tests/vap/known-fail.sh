# shellcheck shell=bash
# Classement KNOWN_FAIL au niveau du cas (T-457). Source par tests/vap/run.sh et tests/vap/known-fail.test.sh.
# Un cas listé reste EXÉCUTÉ et son verdict reste visible ; seule sa contribution au code de sortie change.
# Aucune politique n'est désactivée. Retirer l'entrée quand l'écart est corrigé à la source.
#   B-09 : conteneur éphémère privileged hors dp-* admis (pods/ephemeralcontainers). Écart de la baseline
#          kube-ops, hors de ce dépôt ; correction réelle : baseline de la VM lab (T-363).
KNOWN_FAIL_IDS=(B-09)

# classify ID VERDICT -> écrit le verdict final : PASS | FAIL | KNOWN_FAIL | UNEXPECTED_PASS
#   FAIL        d'un cas listé -> KNOWN_FAIL (non bloquant)
#   PASS        d'un cas listé -> UNEXPECTED_PASS (annoncé ; non bloquant ; retirer l'entrée de KNOWN_FAIL_IDS)
#   cas absent de la liste -> verdict inchangé (un FAIL reste bloquant)
classify() {
  local id="$1" verdict="$2" k
  for k in "${KNOWN_FAIL_IDS[@]}"; do
    if [[ "$k" == "$id" ]]; then
      case "$verdict" in
        FAIL) echo KNOWN_FAIL; return;;
        PASS) echo UNEXPECTED_PASS; return;;
      esac
    fi
  done
  echo "$verdict"
}
