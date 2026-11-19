#!/usr/bin/env bash
# Test statique de tests/bench-ab/pass-0/dispatch.sh (T-486) : cas nominal, tâche inconnue, bras inconnu, et garde-fous.
# Aucun réseau externe, aucun cluster, aucun secret. Usage : tests/bench-ab/pass-0/dispatch-test.sh
# Point d'entrée unique de la suite `bench-ab-pass-0` (tests/registry.yaml) : lance aussi les tests des autres scripts
# de pass-0 (T-501) : observe.py, admin-password.sh, check-frozen-sha.sh.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/dispatch.sh"
W="$(mktemp -d "${TMPDIR:-/tmp}/bench-pass0.XXXXXX")"
trap 'rm -rf "$W"' EXIT
fails=0
ok() { printf 'PASS %s\n' "$1"; }
ko() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
# expect NOM CODE_ATTENDU commande... : sortie combinée dans $W/out.
expect() {
  local name="$1" want="$2" rc=0
  shift 2
  "$@" >"$W/out" 2>&1 || rc=$?
  if [[ "$rc" -eq "$want" ]]; then ok "$name"; else ko "$name (code $rc, attendu $want)"; sed 's/^/  /' "$W/out"; fi
}
contains() { # NOM FICHIER MOTIF
  if grep -Fq -- "$3" "$2"; then ok "$1"; else ko "$1 (motif absent : $3)"; fi
}

# Cas nominal, bras O.
expect "nominal M1 O" 0 "$SCRIPT" M1 O --issue 7 --out-dir "$W/a"
contains "commande de dispatch" "$W/out" "gh workflow run claude-agent.yml --repo platform-zephyr/openchoreo-lab -f tickets=7 -f model=claude-sonnet-5-5 -f effort=high"
contains "run : bras" "$W/a/M1.O.r0.json" '"arm": "O"'
contains "run : rang 0 non compté" "$W/a/M1.O.r0.json" '"counted": false'
contains "run : résultat attendu" "$W/a/M1.O.r0.json" '"expected_status": "PASS"'
contains "run : grader" "$W/a/M1.O.r0.json" '"grader": "m1"'
if python3 -I -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$W/a/M1.O.r0.json"; then ok "run : JSON valide"; else ko "run : JSON invalide"; fi

# Bras K : dépôt du bras K.
expect "nominal M2 K" 0 "$SCRIPT" M2 K --issue 12 --out-dir "$W/b"
contains "dépôt du bras K" "$W/out" "--repo platform-zephyr/bench-ab-arm-k -f tickets=12"

# M4 : panne du rang 0 enregistrée, identique pour les deux bras.
expect "nominal M4 O" 0 "$SCRIPT" M4 O --issue 3 --out-dir "$W/c"
expect "nominal M4 K" 0 "$SCRIPT" M4 K --issue 4 --out-dir "$W/c"
contains "M4 : panne du tirage O" "$W/c/M4.O.r0.json" '"injected_fault": "port_faux"'
contains "M4 : panne du tirage K" "$W/c/M4.K.r0.json" '"injected_fault": "port_faux"'
if grep -q injected_fault "$W/a/M1.O.r0.json"; then ko "M1 : pas de panne injectée"; else ok "M1 : pas de panne injectée"; fi

# Piège : bras O seulement.
expect "piège P1 O" 0 "$SCRIPT" P1 O --issue 5 --out-dir "$W/d"
contains "piège : grader trap" "$W/d/P1.O.r0.json" '"grader": "trap"'
expect "piège P1 K refusé" 2 "$SCRIPT" P1 K --issue 5 --out-dir "$W/d"

# Entrées invalides.
expect "tâche inconnue" 2 "$SCRIPT" M9 O --issue 1 --out-dir "$W/e"
contains "message tâche inconnue" "$W/out" "tâche inconnue"
expect "bras inconnu" 2 "$SCRIPT" M1 X --issue 1 --out-dir "$W/e"
contains "message bras inconnu" "$W/out" "bras inconnu"
expect "issue absente" 2 "$SCRIPT" M1 O --out-dir "$W/e"
expect "issue non numérique" 2 "$SCRIPT" M1 O --issue abc --out-dir "$W/e"
expect "option inconnue" 2 "$SCRIPT" M1 O --issue 1 --zzz
if [[ -e "$W/e" ]]; then ko "aucun fichier écrit sur entrée invalide"; else ok "aucun fichier écrit sur entrée invalide"; fi

# Pas d'écrasement silencieux.
expect "fichier existant refusé" 3 "$SCRIPT" M1 O --issue 7 --out-dir "$W/a"
expect "--force remplace" 0 "$SCRIPT" M1 O --issue 8 --out-dir "$W/a" --force
contains "--force : nouvelle issue" "$W/a/M1.O.r0.json" '"issue": 8'

# Aucun secret ni valeur interne dans les fichiers de run.
if grep -Eqi 'token|secret|password|ghp_|kubeconfig|https?://' "$W"/*/*.json; then ko "fichiers de run sans secret"; else ok "fichiers de run sans secret"; fi

# Scripts voisins (T-501) : chacun a son test hors ligne.
if python3 -I "$HERE/test_observe.py" >"$W/obs.out" 2>&1; then ok "observe.py (test_observe.py)"; else ko "observe.py"; sed 's/^/  /' "$W/obs.out"; fi
for t in admin-password-test.sh check-frozen-sha-test.sh; do
  if "$HERE/$t" >"$W/t.out" 2>&1; then ok "$t"; else ko "$t"; sed 's/^/  /' "$W/t.out"; fi
done

if [[ "$fails" -eq 0 ]]; then printf 'OK\n'; else printf '%s échec(s)\n' "$fails"; exit 1; fi
