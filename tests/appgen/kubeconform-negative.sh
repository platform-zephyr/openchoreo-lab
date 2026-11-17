#!/usr/bin/env bash
# Cas negatif kubeconform : une valeur de type faux dans un objet genere DOIT etre refusee.
# Usage : tests/appgen/kubeconform-negative.sh <dossier config/crd/bases>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CRDS="${1:?dossier config/crd/bases requis}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
python3 "$ROOT/tools/appgen/crd2schema.py" "$CRDS" "$WORK/schemas" >/dev/null
# Rendu de reference dans WORK (platform de test), puis injection d'une erreur de type.
python3 "$ROOT/tools/appgen/appgen.py" --platform-dir "$ROOT/tests/appgen/fixtures/platform" render --out "$WORK/gen" >/dev/null
TARGET="$(find "$WORK/gen/namespaces" -name component.yaml | head -n 1)"
sed -i.bak 's/autoDeploy: false/autoDeploy: "oui"/' "$TARGET"
if kubeconform -strict -summary \
  -schema-location "$WORK/schemas/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
  "$WORK/gen/namespaces" >"$WORK/out.txt" 2>&1; then
  echo "kubeconform-negative : FAIL (la valeur invalide a ete acceptee)"
  exit 1
fi
echo "kubeconform-negative : PASS (valeur invalide refusee : $(grep -c 'is invalid' "$WORK/out.txt") objet(s) rejete(s))"
