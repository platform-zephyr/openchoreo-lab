#!/usr/bin/env bash
# Tests hors ligne de l'assistant des gestes humains (T-325). Aucun reseau, aucun cluster, aucun secret reel :
# sondes lues dans des fixtures (GESTES_FIXTURES), backlog fictif dans un dossier temporaire.
# Usage : tests/factory/gestes-test.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
G="$ROOT/tools/factory/gestes.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/gestes-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
export GESTES_NOW=2026-11-18T10:00:00Z
export GESTES_REPO=acme/lab
PASS=0 FAIL=0

ok() { PASS=$((PASS + 1)); echo "ok   $1"; }
ko() { FAIL=$((FAIL + 1)); echo "FAIL $1"; }
expect_rc() { # nom rc_attendu commande...
  local name="$1" want="$2" rc
  shift 2
  "$@" >"$TMP/out" 2>"$TMP/err" </dev/null && rc=0 || rc=$?
  if [ "$rc" = "$want" ]; then ok "$name"; else ko "$name (rc=$rc, attendu $want)"; fi
}
has() { # nom motif [fichier]
  if grep -qE -- "$2" "${3:-$TMP/out}"; then ok "$1"; else ko "$1 (motif absent : $2)"; fi
}
hasnt() {
  if grep -qE -- "$2" "${3:-$TMP/out}"; then ko "$1 (motif present : $2)"; else ok "$1"; fi
}

ticket() { # dossier id stage status class model deps corps
  cat >"$1/$2-x.md" <<EOF
---
id: $2
title: "Titre $2"
status: $4
phase: P0
adr: [0002]
depends_on: [$7]
class: $5
lane: gouvernance
stage: $3
model: $6
effort: high
---
# $2 x

## Intention
$8

## Périmètre de fichiers
docs/x.md

## Critères de fin
- [ ] critère ouvert de $2
- [x] critère clos de $2

## Notes
Reste : une action de $2.
EOF
}

B="$TMP/backlog"
mkdir -p "$B"
ticket "$B" T-900 S0 todo MANDAT claude-sonnet-5-5 "T-901" "Poser le réglage A. Voir https://example.org/aide."
ticket "$B" T-901 S0 in-progress "REVUE + MANDAT" claude-sonnet-5-5 "" "Geste B, environ 12 minutes."
ticket "$B" T-902 S0 todo AUTONOME human "" "Geste C par model human. Durée : 7 min"
ticket "$B" T-903 S0 todo AUTONOME claude-sonnet-5-5 "" "Pas un geste : AUTONOME."
ticket "$B" T-904 S0 "done" MANDAT claude-sonnet-5-5 "" "Déjà fait : exclu."
ticket "$B" T-905 S1 todo MANDAT claude-sonnet-5-5 "" "Autre étape : exclu de S0."
ticket "$B" T-906 S0 todo MANDAT human "" "Geste libre, hors chemin critique."
ticket "$B" T-907 S0 dropped MANDAT human "" "Abandonné : exclu."

# --- sélection, ordre, durées
expect_rc "list S0 rc 0" 0 "$G" list --backlog "$B"
has "dépendance avant dépendant (T-901 puis T-900)" "^1	T-901	12$"
has "durée par défaut 3 min pour T-900" "^2	T-900	3$"
has "durée « Durée : N min » pour T-902" "^3	T-902	7$"
hasnt "AUTONOME non human exclu" "T-903"
hasnt "done exclu" "T-904"
hasnt "autre étape exclue" "T-905"
hasnt "dropped exclu" "T-907"
hasnt "hors chemin critique absent de la liste ordonnée" "T-906"
expect_rc "list S1 ne voit que T-905" 0 "$G" list --stage S1 --backlog "$B"
has "S1 : T-905" "T-905"

# --- génération
expect_rc "generate rc 0" 0 "$G" generate --backlog "$B"
has "total 22 min dans le budget 30" "3 gestes, 22 min estimées pour un budget de 30 min \(dans le budget\)"
has "critère ouvert repris" "critère ouvert de T-900"
hasnt "critère clos non repris" "critère clos"
has "Reste repris" "Reste : une action de T-901"
has "lien repris" "https://example.org/aide"
has "hors séance : T-906" "T-906 : Titre T-906"
expect_rc "generate --strict budget 20 -> 1" 1 "$G" generate --strict --budget 20 --backlog "$B"
has "dépassement signalé" "DÉPASSE le budget"
expect_rc "generate --strict budget 30 -> 0" 0 "$G" generate --strict --budget 30 --backlog "$B"
expect_rc "budget non numérique -> 2" 2 "$G" generate --budget abc --backlog "$B"
expect_rc "generate --out écrit un fichier" 0 "$G" generate --backlog "$B" --out "$TMP/doc.md"
if [ -s "$TMP/doc.md" ]; then ok "fichier de sortie non vide"; else ko "fichier de sortie vide"; fi
expect_rc "verify-doc à jour -> 0" 0 "$G" verify-doc --backlog "$B" --doc "$TMP/doc.md"
echo "ligne ajoutée à la main" >>"$TMP/doc.md"
expect_rc "verify-doc périmé -> 1" 1 "$G" verify-doc --backlog "$B" --doc "$TMP/doc.md"
expect_rc "verify-doc absent -> 1" 1 "$G" verify-doc --backlog "$B" --doc "$TMP/absent.md"

# --- cas négatifs d'usage
expect_rc "sous-commande inconnue -> 2" 2 "$G" bogus
expect_rc "sans argument -> 2" 2 "$G"
expect_rc "option inconnue -> 2" 2 "$G" generate --zzz --backlog "$B"
expect_rc "backlog absent -> 2" 2 "$G" list --backlog "$TMP/nope"
C="$TMP/cycle"
mkdir -p "$C"
ticket "$C" T-910 S0 todo MANDAT claude-sonnet-5-5 "T-911" "A"
ticket "$C" T-911 S0 todo MANDAT claude-sonnet-5-5 "T-910" "B"
expect_rc "cycle de dépendances -> 2" 2 "$G" generate --backlog "$C"
has "cycle nommé" "cycle de dépendances" "$TMP/err"

# --- garde de secrets : aucune valeur affichée ni écrite
FAKE="ghp_$(printf 'a%.0s' {1..30})"
S="$TMP/secret"
mkdir -p "$S"
ticket "$S" T-920 S0 todo MANDAT claude-sonnet-5-5 "" "Coller $FAKE dans le réglage."
expect_rc "motif de secret -> 3" 3 "$G" generate --backlog "$S" --out "$TMP/leak.md"
hasnt "valeur absente de stdout" "ghp_" "$TMP/out"
hasnt "valeur absente de stderr" "ghp_" "$TMP/err"
if [ ! -e "$TMP/leak.md" ]; then ok "aucun fichier écrit sur refus"; else ko "fichier écrit malgré le secret"; fi
expect_rc "verify-doc refuse aussi -> 3" 3 "$G" verify-doc --backlog "$S" --doc "$TMP/doc.md"
KEY="-----BEGIN RSA PRIVATE KEY-----"
ticket "$S" T-921 S0 todo MANDAT claude-sonnet-5-5 "" "$KEY"
rm -f "$S/T-920-x.md"
expect_rc "clé privée -> 3" 3 "$G" generate --backlog "$S"

# --- sondes (fixtures) : PASS / FAIL / NOT_TESTED avec horodatage
P="$TMP/probe"
mkdir -p "$P/backlog" "$P/fx"
for t in T-305 T-431 T-433 T-434 T-999; do ticket "$P/backlog" "$t" S0 todo MANDAT claude-sonnet-5-5 "" "Geste $t."; done
printf 'aaa\trefs/tags/core-baseline\nbbb\trefs/tags/core-baseline^{}\n' >"$P/fx/tag-core-baseline"
printf '0' >"$P/fx/apply-check.rc"
printf '[{"id":1,"name":"main","target":"branch"},{"id":2,"name":"tags","target":"tag"}]' >"$P/fx/rulesets.json"
printf '{"two_factor_requirement_enabled":true,"default_repository_permission":"none","members_can_create_repositories":false}' >"$P/fx/org.json"
export GESTES_FIXTURES="$P/fx"
expect_rc "check tout PASS sauf sans sonde -> 0" 0 "$G" check --backlog "$P/backlog"
has "T-305 PASS horodaté" "^2026-11-18T10:00:00Z \| T-305 \| PASS \|"
has "T-431 PASS" "\| T-431 \| PASS \|"
has "T-433 PASS" "\| T-433 \| PASS \|"
has "T-434 PASS" "\| T-434 \| PASS \|"
has "T-999 NOT_TESTED (aucune sonde)" "\| T-999 \| NOT_TESTED \|"

printf 'aaa\trefs/tags/core-baseline\n' >"$P/fx/tag-core-baseline"
expect_rc "tag léger -> FAIL, rc 1" 1 "$G" check --backlog "$P/backlog"
has "T-305 FAIL tag léger" "\| T-305 \| FAIL \| tag léger"
: >"$P/fx/tag-core-baseline"
expect_rc "tag absent -> FAIL" 1 "$G" check --backlog "$P/backlog"
has "T-305 FAIL absent" "\| T-305 \| FAIL \| tag core-baseline absent"
printf '[{"id":1,"target":"branch"}]' >"$P/fx/rulesets.json"
printf '1' >"$P/fx/apply-check.rc"
printf '3' >"$P/fx/apply-check.rc"
expect_rc "ruleset tag absent -> FAIL" 1 "$G" check --backlog "$P/backlog"
has "T-433 FAIL" "\| T-433 \| FAIL \|"
has "T-431 NOT_TESTED si non comparable" "\| T-431 \| NOT_TESTED \|"
printf '{"two_factor_requirement_enabled":false,"default_repository_permission":"read","members_can_create_repositories":true}' >"$P/fx/org.json"
"$G" check --backlog "$P/backlog" >"$TMP/out" 2>&1 </dev/null
has "T-434 FAIL si réglage faux" "\| T-434 \| FAIL \|"
printf '{"login":"acme"}' >"$P/fx/org.json"
"$G" check --backlog "$P/backlog" >"$TMP/out" 2>&1 </dev/null
has "T-434 NOT_TESTED si droit insuffisant" "\| T-434 \| NOT_TESTED \| champs réservés"
rm -f "$P/fx/org.json" "$P/fx/rulesets.json"
"$G" check --backlog "$P/backlog" >"$TMP/out" 2>&1 </dev/null
has "T-434 NOT_TESTED si lecture impossible" "\| T-434 \| NOT_TESTED \| lecture de l'organisation impossible"
has "T-433 NOT_TESTED si lecture impossible" "\| T-433 \| NOT_TESTED \| lecture des rulesets impossible"
"$G" check --backlog "$P/backlog" --log "$TMP/log.txt" >/dev/null 2>&1 </dev/null
if [ "$(wc -l <"$TMP/log.txt")" = 5 ]; then ok "journal : une ligne par geste"; else ko "journal : nombre de lignes"; fi
if grep -q "2026-11-18T10:00:00Z" "$TMP/log.txt"; then ok "journal horodaté"; else ko "journal sans horodatage"; fi

# --- séance interactive : une déclaration seule n'est jamais PASS
Q="$TMP/seance"
mkdir -p "$Q/backlog"
ticket "$Q/backlog" T-930 S0 todo MANDAT claude-sonnet-5-5 "" "Premier."
ticket "$Q/backlog" T-931 S0 todo MANDAT claude-sonnet-5-5 "T-930" "Deuxieme."
ticket "$Q/backlog" T-932 S0 todo MANDAT claude-sonnet-5-5 "T-931" "Troisieme."
"$G" seance --backlog "$Q/backlog" >"$TMP/out" 2>&1 <<<$'o\nn\ns'
has "déclaré fait sans sonde -> NOT_TESTED" "\| T-930 \| NOT_TESTED \| déclaré fait par Paul, non vérifié"
has "non fait -> FAIL" "\| T-931 \| FAIL \| geste déclaré non fait"
has "sauté -> NOT_TESTED" "\| T-932 \| NOT_TESTED \| geste sauté"
"$G" seance --backlog "$Q/backlog" >"$TMP/out" 2>&1 </dev/null
has "fin d'entrée -> NOT_TESTED" "\| T-930 \| NOT_TESTED \| aucune réponse"
hasnt "séance sans PASS inventé" "\| PASS \|"
printf 'aaa\trefs/tags/core-baseline\nbbb\trefs/tags/core-baseline^{}\n' >"$P/fx/tag-core-baseline"
"$G" seance --backlog "$P/backlog" >"$TMP/out" 2>&1 <<<$'o\no\no\no\no'
has "effet déjà présent -> PASS sans question" "\| T-305 \| PASS \| .*\(déjà fait\)"

# --- le script ne contient aucune commande d'écriture distante
unset GESTES_FIXTURES
if grep -nE 'gh api (-X|--method) *(POST|PUT|PATCH|DELETE)|kubectl (apply|create|delete)|git push|apply\.sh --apply|--input|-f [a-z_]+=' "$G" >/dev/null; then
  ko "écriture distante présente dans gestes.sh"
else ok "aucune commande d'écriture dans gestes.sh"; fi

# --- document réel du dépôt : à jour et propre pour gitleaks
if [ -f "$ROOT/docs/GESTES-PAUL.md" ]; then
  expect_rc "docs/GESTES-PAUL.md à jour" 0 "$G" verify-doc
  mkdir -p "$TMP/scan"
  cp "$ROOT/docs/GESTES-PAUL.md" "$TMP/scan/"
  "$G" generate --backlog "$B" --out "$TMP/scan/fixture.md" >/dev/null 2>&1
  if command -v gitleaks >/dev/null 2>&1; then
    expect_rc "gitleaks propre sur le document généré" 0 "$ROOT/tools/dev/leak-guard.sh" "$TMP/scan"
  else
    echo "NOT_TESTED gitleaks absent"
  fi
else
  echo "NOT_TESTED docs/GESTES-PAUL.md absent"
fi

echo
echo "gestes-test : $PASS ok, $FAIL echec(s)"
[ "$FAIL" -eq 0 ]
