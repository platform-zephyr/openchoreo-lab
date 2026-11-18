#!/usr/bin/env bash
# T-060 : retire le droit Secrets cluster-wide du SA kgateway, après `helm upgrade --install kgateway`.
# Lit le manifeste de la release, le filtre (tools/oke/kgateway-rbac.py), l'applique en server-side apply
# (propriétaire distinct de Helm, conflits forcés : la liste `rules` est atomique), puis redémarre le contrôleur
# pour qu'il n'ait plus que les droits bornés. À rejouer après chaque `helm upgrade` de kgateway (Helm remet le
# ClusterRole d'origine). Le contexte kubectl est celui de l'appelant (install.sh, ci-bootstrap.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NS="${KGATEWAY_NAMESPACE:-openchoreo-control-plane}"
helm -n "$NS" get manifest kgateway \
  | PYTHONDONTWRITEBYTECODE=1 python3 -I "$ROOT/tools/oke/kgateway-rbac.py" --rbac-only \
  | kubectl apply --server-side --force-conflicts --field-manager=lab-kgateway-rbac -f -
kubectl -n "$NS" rollout restart deploy/kgateway
kubectl -n "$NS" rollout status deploy/kgateway --timeout=180s
