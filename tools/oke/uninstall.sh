#!/usr/bin/env bash
# uninstall.sh : rollback par étape et nettoyage de l'essai (aligné sur CLEANUP.md). NON EXÉCUTÉ.
# Usage : tools/oke/uninstall.sh [--step N | --all] [--apply] [--delete-crds]
#   - DRY-RUN PAR DÉFAUT ; --apply pour exécuter.
#   - --step N : annule la seule étape N de install.sh (rollback d'étape, docs/PHASE-B.md §2).
#   - --all : étapes 12 -> 1, puis vérification CLEANUP.md (étape 6).
#   - --delete-crds : supprime aussi les CRD de l'essai (openchoreo.dev, kgateway, cert-manager, ESO,
#     Gateway API, argoproj.io) SEULEMENT si aucun namespace hors essai ne les utilise (vérifié).
# Périmètre : namespaces de TRIAL_NS (lib.sh), dp-* portant le label du CPT cell-restricted, et le label
# openchoreo.dev/control-plane de `default`. Jamais d'autre namespace, jamais de volume OCI hors lab-pg.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MODE="" N="" DELETE_CRDS=0
while (($#)); do
  case "$1" in
    --step) MODE=step; N="$2"; shift 2;;
    --all) MODE=all; shift;;
    --apply) APPLY=1; shift;;
    --delete-crds) DELETE_CRDS=1; shift;;
    -h|--help) sed -n '2,11p' "$0"; exit 0;;
    *) die "argument inconnu : $1";;
  esac
done
[[ -n "$MODE" ]] || die "usage : $0 --step N | --all [--apply] [--delete-crds]"
export APPLY
need kubectl helm jq
guard_context
M="$INSTALL_DIR/manifests"
KD=(kubectl delete --ignore-not-found)

helm_rm() { # NS RELEASE
  if helm -n "$1" status "$2" >/dev/null 2>&1; then run helm -n "$1" uninstall "$2" --wait; else log "release $1/$2 absente"; fi
}

# CRD d'un groupe encore utilisées hors des namespaces d'essai ? (refus de suppression si oui)
crd_in_use_outside() { # GROUPE
  local crd kind
  for crd in $(kubectl get crd -o name | grep -E "\\.$1\$" | sed 's#.*/##'); do
    kind="$(kubectl get crd "$crd" -o jsonpath='{.spec.names.plural}.{.spec.group}')"
    if kubectl get "$kind" -A -o json 2>/dev/null \
      | jq -e --arg re "^(openchoreo-|lab-|dp-|cnpg-system$|default$)" '[.items[] | select((.metadata.namespace // "") != "" and ((.metadata.namespace) | test($re) | not))] | length > 0' >/dev/null; then
      log "CRD $crd utilisée hors essai : conservée"; return 0
    fi
  done
  return 1
}
rm_crds() { # GROUPE
  [[ "$DELETE_CRDS" == 1 ]] || { log "CRD *.$1 conservées (--delete-crds absent)"; return; }
  if crd_in_use_outside "$1"; then return; fi
  local crds; crds="$(kubectl get crd -o name | grep -E "\\.$1\$" || true)"
  # shellcheck disable=SC2086  # découpage voulu : liste de crd/<nom>
  [[ -z "$crds" ]] || run kubectl delete $crds
}

undo_12() {
  kubectl get clusterrole lab-cluster-agent-reduced >/dev/null 2>&1 || { log "RBAC réduit absent : rien à annuler"; return; }
  local tgz; tgz="$(fetch_chart openchoreo-data-plane "$OPENCHOREO_DP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_DP_TGZ_SHA256")"
  run helm upgrade openchoreo-data-plane "$tgz" -n openchoreo-data-plane -f "$INSTALL_DIR/values/openchoreo-data-plane.yaml" \
    --set clusterAgent.rbac.create=true --wait --timeout 10m
  run "${KD[@]}" -f "$ROOT/platform/cluster-agent/reduced-clusterrole.yaml"
}
undo_11() {
  # Pas de finalizer resources-finalizer : supprimer les Application conserve les objets (CLEANUP.md 1).
  run "${KD[@]}" -n lab-argocd application lab-root lab-platform
  run "${KD[@]}" -f "$INSTALL_DIR/argocd/project-lab.yaml"
  helm_rm lab-argocd argocd
  if kubectl get ns argocd >/dev/null 2>&1; then log "namespace argocd présent (kube-ops) : CRD argoproj.io conservées"; else rm_crds argoproj.io; fi
}
undo_10() {
  # Le PVC lab-pg (block volume OCI de l'essai, reclaim Delete) disparaît avec le Cluster : seul volume
  # OCI que l'essai supprime. Les volumes d'origine d'OKE ne sont liés à aucun PVC d'essai.
  run "${KD[@]}" -f "$ROOT/platform/data/lab-pg-cluster.yaml" --wait=true
  run "${KD[@]}" -f "$M/51-lab-pg-oke-overlay.yaml"
  helm_rm cnpg-system cnpg
}
undo_9() {
  # Les Components (Phase C) doivent être supprimés AVANT (CLEANUP.md 2 : leurs finalizers nettoient dp-*).
  if kubectl get components.openchoreo.dev -A -o name 2>/dev/null | grep -q .; then
    die "des Components existent encore : CLEANUP.md étape 2 d'abord"
  fi
  run "${KD[@]}" -f "$ROOT/platform/resource-types/" -f "$ROOT/platform/project-types/" \
    -f "$ROOT/platform/traits/" -f "$ROOT/platform/component-types/"
  run "${KD[@]}" -f "$M/40-openchoreo-env.yaml"
  run kubectl label namespace default openchoreo.dev/control-plane-
}
undo_8() { run "${KD[@]}" clusterdataplane default; }
undo_7() {
  helm_rm openchoreo-data-plane openchoreo-data-plane
  run "${KD[@]}" -f "$M/12-gateway-parameters.yaml" -f "$M/11-gateway-tls.yaml"
  run "${KD[@]}" -f "$ROOT/platform/cluster-agent/extra-rbac-quota.yaml"
  run "${KD[@]}" -f "$ROOT/platform/policies/"
}
undo_6() { helm_rm openchoreo-control-plane openchoreo-control-plane; rm_crds openchoreo.dev; }
undo_5() { helm_rm openchoreo-control-plane kgateway; helm_rm openchoreo-control-plane kgateway-crds; rm_crds kgateway.dev; }
undo_4() { run "${KD[@]}" -f "$M/20-eso-lab-store.yaml"; helm_rm openchoreo-external-secrets external-secrets; rm_crds external-secrets.io; }
undo_3() { helm_rm openchoreo-cert-manager cert-manager; rm_crds cert-manager.io; }
undo_2() { rm_crds gateway.networking.k8s.io; }
undo_1() {
  local ns
  # dp-* : uniquement ceux créés par le CPT du labo (label en constante platform.smadja.dev/cell).
  for ns in $(kubectl get ns -l platform.smadja.dev/cell=restricted -o name | sed 's#.*/##' | grep -E '^dp-' || true); do
    run kubectl delete namespace "$ns" --wait=false
  done
  for ns in "${TRIAL_NS[@]}"; do
    if kubectl get ns "$ns" >/dev/null 2>&1; then
      [[ "$(kubectl get ns "$ns" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}')" == openchoreo-lab ]] \
        || { log "namespace $ns sans label part-of=openchoreo-lab : NON supprimé"; continue; }
      run kubectl delete namespace "$ns" --wait=false
    fi
  done
}
check_clean() { # CLEANUP.md étape 6
  [[ "$APPLY" == 1 ]] || { echo "[dry-run] vérification CLEANUP.md étape 6"; return; }
  if kubectl get ns -o name | grep -E '/(lab-|openchoreo|dp-)'; then log "namespaces restants (suppression en cours ?)"; else log "aucun namespace d'essai"; fi
  kubectl get crd -o name | grep openchoreo && log "CRD openchoreo restantes" || true
  kubectl get pv -o custom-columns=NAME:.metadata.name,CLAIM:.spec.claimRef.namespace,STATUS:.status.phase --no-headers || true
  kubectl get clusterrole,clusterrolebinding,validatingwebhookconfiguration,mutatingwebhookconfiguration -o name \
    | grep -E 'openchoreo|lab-|cert-manager|external-secrets|kgateway|argocd' || log "aucun objet cluster-scoped d'essai restant"
}

case "$MODE" in
  step) declare -F "undo_$N" >/dev/null || die "étape inconnue : $N"; "undo_$N";;
  all) for n in 12 11 10 9 8 7 6 5 4 3 2 1; do log "=== annulation étape $n"; "undo_$n"; done; check_clean;;
esac
