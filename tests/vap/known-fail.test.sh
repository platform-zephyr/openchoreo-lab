#!/usr/bin/env bash
# Test hors cluster de tests/vap/known-fail.sh (cas positifs et négatifs). Aucun réseau, aucun kubectl.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 2
# shellcheck source=known-fail.sh
source ./known-fail.sh
bad=0
eq() { # DESC ATTENDU OBTENU
  if [[ "$2" == "$3" ]]; then printf 'PASS %s\n' "$1"; else printf 'FAIL %s : attendu %s, obtenu %s\n' "$1" "$2" "$3"; bad=$((bad + 1)); fi
}
eq "B-09 en échec -> KNOWN_FAIL"          KNOWN_FAIL      "$(classify B-09 FAIL)"
eq "B-09 qui passe -> UNEXPECTED_PASS"    UNEXPECTED_PASS "$(classify B-09 PASS)"
eq "autre cas en échec reste FAIL"        FAIL            "$(classify B-10 FAIL)"
eq "autre cas qui passe reste PASS"       PASS            "$(classify B-10 PASS)"
eq "id voisin B-090 non classé"           FAIL            "$(classify B-090 FAIL)"
eq "id voisin B-9 non classé"             FAIL            "$(classify B-9 FAIL)"
eq "id vide non classé"                   FAIL            "$(classify '' FAIL)"
eq "verdict inconnu inchangé pour B-09"   NOT_TESTED      "$(classify B-09 NOT_TESTED)"
# Garde : seul B-09 est listé (toute extension de la liste doit être délibérée).
eq "liste = B-09 seul" "B-09" "${KNOWN_FAIL_IDS[*]}"
# Intégration : run.sh utilise classify, ne compte que FAIL dans FAILS et annonce le passage inattendu.
grep -q 'source "\$ROOT/tests/vap/known-fail.sh"' run.sh; eq "run.sh source known-fail.sh" 0 $?
grep -q 'classify "\$id" "\$verdict"' run.sh; eq "run.sh appelle classify" 0 $?
grep -q 'ANNONCE' run.sh; eq "run.sh annonce UNEXPECTED_PASS" 0 $?
exit $(( bad > 0 ))
