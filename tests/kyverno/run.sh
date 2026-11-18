#!/usr/bin/env bash
# Tests hors cluster des politiques Kyverno (platform/kyverno/policies) avec `kyverno test`.
# Usage : tests/kyverno/run.sh [chemin/vers/kyverno]   (défaut : $KYVERNO_BIN, puis `kyverno` du PATH)
# Les fixtures datées (exceptions, approbations de suppression) portent des jetons @@T<±N><h|d>@@ :
# ils sont rendus RELATIFS à l'heure courante dans une copie temporaire (le dépôt n'est jamais modifié),
# sinon les cas « valide » pourriraient à la date d'expiration.
# Vérifie aussi que chaque politique référence un dossier de tests existant (annotation
# platform.smadja.dev/tests) et que chaque dossier de tests vise au moins une politique.
# Codes : 0 PASS, 1 FAIL (test ou cohérence), 2 usage/outillage.
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
kyv="${1:-${KYVERNO_BIN:-kyverno}}"
command -v "$kyv" >/dev/null 2>&1 || { echo "kyverno introuvable : $kyv" >&2; exit 2; }
"$kyv" version >/dev/null

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/platform/kyverno" "$work/tests"
cp -R "$repo/platform/kyverno/policies" "$work/platform/kyverno/"
cp -R "$repo/tests/kyverno" "$work/tests/"

# Rendu des dates relatives (python3 : même comportement sous macOS et Linux).
python3 -I - "$work/tests/kyverno" <<'PY'
import datetime, pathlib, re, sys
now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
pat = re.compile(r"@@T([+-])(\d+)([hd])@@")
def sub(m):
    n = int(m.group(2)) * (24 if m.group(3) == "d" else 1)
    d = now + datetime.timedelta(hours=n if m.group(1) == "+" else -n)
    return d.strftime("%Y-%m-%dT%H:%M:%SZ")
for p in pathlib.Path(sys.argv[1]).rglob("*.yaml"):
    t = p.read_text()
    if "@@T" in t:
        p.write_text(pat.sub(sub, t))
PY

rc=0
# Cohérence politique <-> tests.
for pol in "$repo"/platform/kyverno/policies/*.yaml; do
  name="$(basename "$pol" .yaml)"
  ref="$(sed -n 's/^ *platform.smadja.dev\/tests: *//p' "$pol")"
  if [[ "$ref" != "tests/kyverno/$name" || -z "$(find "$repo/$ref" -name kyverno-test.yaml 2>/dev/null)" ]]; then
    echo "FAIL coherence: $name référence '$ref' (attendu tests/kyverno/$name contenant un kyverno-test.yaml)"; rc=1
  elif ! grep -rqs "policy: $name," "$repo/$ref" && ! grep -rqs "policy: $name\$" "$repo/$ref"; then
    echo "FAIL coherence: aucun résultat attendu pour $name dans $ref"; rc=1
  fi
  for want in pass fail; do
    grep -rqs "result: $want" "$repo/$ref" || { echo "FAIL coherence: $name sans cas « $want »"; rc=1; }
  done
done

# `kyverno test` découvre récursivement tous les kyverno-test.yaml.
if ! "$kyv" test "$work/tests/kyverno" --detailed-results --remove-color; then
  rc=1
fi
[[ $rc -eq 0 ]] && echo "KYVERNO TESTS: PASS" || echo "KYVERNO TESTS: FAIL"
exit $rc
