#!/usr/bin/env bash
# Telecharge les schemas JSON externes (CiliumNetworkPolicy, CiliumClusterwideNetworkPolicy, Application Argo CD, ExternalSecret) depuis
# datreeio/CRDs-catalog a un commit epingle, et verifie leur sha256. Donnees seulement (aucun code execute).
# Usage : tools/appgen/fetch-ext-schemas.sh <dossier de sortie (vide)>
set -euo pipefail
OUT="${1:?dossier de sortie requis}"
COMMIT="784ec895547a36e548e6810b41f27baade3a0890"   # datreeio/CRDs-catalog main au 2026-11-17
BASE="https://raw.githubusercontent.com/datreeio/CRDs-catalog/$COMMIT"
FILES=(
  "cilium.io/ciliumnetworkpolicy_v2.json 585b8964e637dad0213ad2feb581d6333207c155cdbe394c68b2d1d5defb7833"
  "cilium.io/ciliumclusterwidenetworkpolicy_v2.json aaed71d34d6a0b77a0bd48ba54704b2c85455ceea3f01cd5850c7469729d9d2c"
  "argoproj.io/application_v1alpha1.json 99c37877b0626eaf21f42f70f4fc432a4b820de548d88ed90cc75381adf5192c"
  "external-secrets.io/externalsecret_v1.json 7634aa711997c50e952970bc149fad4b2ac9e1fbc90047bc43e28e8c2682d570"
)
for entry in "${FILES[@]}"; do
  path="${entry%% *}"
  sum="${entry##* }"
  mkdir -p "$OUT/$(dirname "$path")"
  curl -sfL --retry 3 -o "$OUT/$path" "$BASE/$path"
  echo "$sum  $OUT/$path" | shasum -a 256 -c - >/dev/null || { echo "fetch-ext-schemas : sha256 invalide pour $path" >&2; exit 1; }
done
echo "fetch-ext-schemas : ${#FILES[@]} schemas verifies sous $OUT (CRDs-catalog@$COMMIT)"
