#!/usr/bin/env bash
# Test hors ligne (T-430) : JSON valide, --check conforme/dérive sur fixtures, require_code_owner_review=false en dev.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
APPLY=tools/github/apply.sh
FX=tests/github-config/fixtures
fail=0
ok() { echo "PASS $1"; }
ko() { echo "FAIL $1"; fail=1; }
expect_rc() { # attendu, description, commande...
  local want="$1" desc="$2" rc=0
  shift 2
  "$@" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq "$want" ]; then ok "$desc"; else ko "$desc (rc=$rc, attendu $want)"; fi
}

for f in .github/rulesets/*.json "$FX"/*.json; do
  if python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' "$f"; then ok "JSON valide $f"; else ko "JSON invalide $f"; fi
done

# Contenu de main-dev.json
if python3 -I - <<'P'
import json
d = json.load(open(".github/rulesets/main-dev.json"))
t = {r["type"]: r.get("parameters", {}) for r in d["rules"]}
assert set(t) == {"non_fast_forward", "deletion", "pull_request", "merge_queue", "required_status_checks"}, t.keys()
pr = t["pull_request"]
assert pr["required_approving_review_count"] == 0 and pr["require_code_owner_review"] is False
assert t["merge_queue"]["merge_method"] == "SQUASH"
assert t["required_status_checks"]["required_status_checks"] == [{"context": "ci-ok"}]
assert d["bypass_actors"] == [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "pull_request"}]
P
then ok "main-dev.json : règles attendues"; else ko "main-dev.json : règles"; fi

# --check hors ligne
expect_rc 0 "--check conforme (champs API en plus ignorés)" "$APPLY" --check --state "$FX/conforme.json"
expect_rc 1 "--check détecte code owners true" "$APPLY" --check --state "$FX/derive-code-owners.json"
expect_rc 1 "--check détecte bypass retiré" "$APPLY" --check --state "$FX/derive-bypass.json"
expect_rc 1 "--check détecte ci-ok absent" "$APPLY" --check --state "$FX/derive-ci-ok.json"
expect_rc 3 "--check lecture sans droit admin = NOT_TESTED" "$APPLY" --check --state "$FX/sans-droit-admin.json"
expect_rc 2 "profil final absent en dev" "$APPLY" final x/y

# Mode par défaut : aucune écriture, code owners à false, y compris via l'enveloppe
out="$("$APPLY" dev x/y 2>/dev/null)"
if grep -q '"require_code_owner_review": false' <<<"$out"; then ok "apply.sh affiche code owners false"; else ko "apply.sh code owners"; fi
out="$(tools/apply-branch-protection.sh x/y 2>/dev/null)"
if grep -q '"require_code_owner_review": false' <<<"$out"; then ok "enveloppe : code owners false"; else ko "enveloppe code owners"; fi
if grep -q '"require_code_owner_review": true' <<<"$out"; then ko "enveloppe : true interdit avant FINAL0"; else ok "enveloppe : aucun true"; fi

# La valeur true n'existe que dans main-final.json (T-400)
hits="$(grep -rl --include='*.json' --include='*.sh' '"require_code_owner_review": *true' .github/rulesets tools || true)"
if [ -z "$hits" ] || [ "$hits" = ".github/rulesets/main-final.json" ]; then ok "true seulement dans main-final.json"; else ko "true trouvé dans : $hits"; fi

# Aucun secret manipulé
if grep -nEi 'gh secret|token|password|BEGIN .*PRIVATE' tools/github/apply.sh tools/github/ruleset_diff.py .github/rulesets/*.json; then ko "motif secret"; else ok "aucun motif secret"; fi

# Écriture : exactement deux appels (PUT, POST), dans la branche --apply
if [ "$(grep -c -- '--method' tools/github/apply.sh)" -eq 2 ]; then ok "deux appels d'écriture (PUT, POST)"; else ko "appels d'écriture inattendus"; fi

exit "$fail"
