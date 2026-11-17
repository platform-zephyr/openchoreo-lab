#!/usr/bin/env bash
# Valide le rendu contre les CRD OpenChoreo (kubeconform -strict, aucun schema manquant tolere).
# Usage : tools/appgen/validate-crd.sh <dossier config/crd/bases> [dossier generated] [dossier schemas externes]
#   - generated/namespaces : CRD OpenChoreo v1.3.3 seulement ;
#   - generated/previews et generated/helm (si presents) : schemas Kubernetes par defaut + schemas externes
#     (cilium.io, argoproj.io, external-secrets.io) obtenus par tools/appgen/fetch-ext-schemas.sh.
# Prerequis : kubeconform et python3. Les regles CEL ne sont pas evaluees ici (API server seul).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CRDS="${1:?dossier config/crd/bases requis}"
GEN="${2:-$ROOT/generated}"
EXT="${3:-}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
python3 "$ROOT/tools/appgen/crd2schema.py" "$CRDS" "$WORK/schemas"
kubeconform -strict -summary \
  -schema-location "$WORK/schemas/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
  "$GEN/namespaces"
OTHERS=()
for d in previews helm; do
  [ -d "$GEN/$d" ] && OTHERS+=("$GEN/$d")
done
if [ "${#OTHERS[@]}" -gt 0 ]; then
  if [ -z "$EXT" ]; then
    echo "validate-crd : ${OTHERS[*]} presents mais aucun dossier de schemas externes fourni : ECHEC" >&2
    exit 1
  fi
  kubeconform -strict -summary \
    -schema-location default \
    -schema-location "$EXT/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
    "${OTHERS[@]}"
fi
