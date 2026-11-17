#!/usr/bin/env bash
# uninstall.sh : rollback par étape et nettoyage de l'essai (aligné sur CLEANUP.md). NON EXÉCUTÉ.
# Usage : tools/oke/uninstall.sh [--step N | --all | --migrate-cnpg-system] [--apply] [--delete-crds]
#   - DRY-RUN PAR DÉFAUT ; --apply pour exécuter. Les gardes (lectures) tournent aussi en dry-run.
#   - --step N : annule la seule étape N de install.sh (N = 1..12 ou 6b ; rollback d'étape, PHASE-B §2).
#   - --all : étapes 12 -> 1 (6b avant 6), puis vérification CLEANUP.md (étape 6).
#   - --migrate-cnpg-system : supprime l'ancien namespace `cnpg-system` créé VIDE par l'étape 1 du
#     2026-11-17 (revue B3), SEULEMENT s'il porte part-of=openchoreo-lab et ne contient que nos objets.
#   - --delete-crds : supprime aussi les CRD de l'essai, SEULEMENT si (a) elles n'existaient pas avant
#     l'essai ($STATE_DIR/crds-before.txt, écrit par preflight.sh ; fichier absent => refus) et (b) aucun
#     objet hors essai ne les utilise (namespacé hors périmètre, ou cluster-scoped sans marque de l'essai).
#     Toute lecture en erreur => CRD CONSERVÉES (échec fermé, revue I2).
# Périmètre : namespaces de TRIAL_NS (lib.sh) portant part-of=openchoreo-lab, dp-* portant le label du CPT
# cell-restricted, label openchoreo.dev/control-plane de `default` (exceptions OpenChoreo acquittées,
# missions/MISSION.md). Jamais d'autre namespace, jamais de volume OCI hors lab-pg.
# Argo (revue I4) : tant que l'Application lab-platform (ou lab-root) existe, les rollbacks des étapes
# qu'Argo adopte (7, 9, 10) sont REFUSÉS : selfHeal recréerait l'objet (ex. un nouveau volume de 50 Go).
# Annuler d'abord l'étape 11 (uninstall.sh --step 11).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MODE="" N="" DELETE_CRDS=0
while (($#)); do
  case "$1" in
    --step) MODE=step; N="$2"; shift 2;;
    --all) MODE=all; shift;;
    --migrate-cnpg-system) MODE=migrate; shift;;
    --apply) APPLY=1; shift;;
    --delete-crds) DELETE_CRDS=1; shift;;
    -h|--help) sed -n '2,20p' "$0"; exit 0;;
    *) die "argument inconnu : $1";;
  esac
done
[[ -n "$MODE" ]] || die "usage : $0 --step N | --all | --migrate-cnpg-system [--apply] [--delete-crds]"
export APPLY
need kubectl helm jq yq
guard_context
M="$INSTALL_DIR/manifests"
KD=(kubectl delete --ignore-not-found)
TRIAL_NS_RE="^($(IFS='|'; echo "${TRIAL_NS[*]}"))$"

in_trial_ns() { [[ "$1" =~ $TRIAL_NS_RE ]]; }

helm_rm() { # NS RELEASE : seulement dans un namespace d'essai ; lecture en erreur => abandon
  in_trial_ns "$1" || die "helm_rm : namespace $1 hors essai"
  local rels
  rels="$(helm -n "$1" list -a -q)" || die "helm list -n $1 en erreur"
  if grep -qx "$2" <<<"$rels"; then run helm -n "$1" uninstall "$2" --wait; else log "release $1/$2 absente"; fi
}

# Garde I1 : la release doit déclarer helm.sh/resource-policy=keep sur TOUTES ses CRD (sinon `helm uninstall`
# les supprimerait, avec tous les objets du cluster). Lecture du manifeste stocké de la release.
release_keeps_crds() { # NS RELEASE
  local man
  if ! helm -n "$1" status "$2" >/dev/null 2>&1; then return 0; fi
  man="$(helm -n "$1" get manifest "$2")" || die "helm get manifest $1/$2 en erreur"
  [[ "$(yq -N 'select(.kind == "CustomResourceDefinition" and .metadata.annotations["helm.sh/resource-policy"] != "keep") | .metadata.name' <<<"$man")" == "" ]] \
    || die "release $1/$2 : CRD sans helm.sh/resource-policy=keep ; relancer install.sh --step correspondante --apply avant tout uninstall"
}

# argo_adopts : vrai si une Application lab-root/lab-platform existe. CRD absente => faux. Erreur => abandon.
argo_adopts() {
  local crd apps
  crd="$(kubectl get crd applications.argoproj.io --ignore-not-found -o name)" || die "lecture des CRD argoproj en erreur"
  [[ -n "$crd" ]] || return 1
  apps="$(kubectl -n lab-argocd get applications.argoproj.io lab-root lab-platform --ignore-not-found -o name)" \
    || die "lecture des Application Argo en erreur"
  [[ -n "$apps" ]]
}
refuse_if_argo() { # ÉTAPE
  # Dry-run de --all : l'étape 11 (suppression des Application) n'a pas été jouée ; en --apply elle l'a été,
  # et la garde relit l'état réel.
  if [[ "$APPLY" != 1 && "$MODE" == all ]]; then log "[dry-run] étape $1 : garde Argo évaluée après l'annulation réelle de l'étape 11"; return; fi
  if argo_adopts; then die "étape $1 : Application lab-root/lab-platform présente (selfHeal recréerait les objets) : uninstall.sh --step 11 d'abord"; fi
}

# crd_in_use_outside GROUPE : 0 (= « utilisée hors essai », donc CONSERVER) au moindre doute.
# Objets namespacés : hors openchoreo-*, lab-*, dp-* (et `default` pour openchoreo.dev seulement).
# Objets cluster-scoped : sans label part-of=openchoreo-lab ni annotation de release Helm d'un namespace d'essai.
crd_in_use_outside() {
  local g="$1" crds crd res scope objs nsre='^(openchoreo-|lab-|dp-)'
  [[ "$g" == openchoreo.dev ]] && nsre='^(openchoreo-|lab-|dp-|default$)'
  crds="$(kubectl get crd -o json)" || { log "liste des CRD illisible : CRD *.$g conservées"; return 0; }
  while IFS=$'\t' read -r crd res scope; do
    [[ -n "$crd" ]] || continue
    objs="$(kubectl get "$res" -A -o json)" || { log "objets $res illisibles : CRD *.$g conservées"; return 0; }
    if [[ "$scope" == Namespaced ]]; then
      if ! jq -e --arg re "$nsre" '[.items[] | select(.metadata.namespace | test($re) | not)] | length == 0' <<<"$objs" >/dev/null; then
        log "CRD $crd utilisée hors essai (objets namespacés) : conservée"; return 0
      fi
    else
      if ! jq -e --arg re "$TRIAL_NS_RE" '[.items[] | select((.metadata.labels["app.kubernetes.io/part-of"] // "") != "openchoreo-lab"
            and ((.metadata.annotations["meta.helm.sh/release-namespace"] // "") | test($re) | not))] | length == 0' <<<"$objs" >/dev/null; then
        log "CRD $crd : objet cluster-scoped sans marque de l'essai : conservée"; return 0
      fi
    fi
  done < <(jq -r --arg g "$g" '.items[] | select(.spec.group == $g) | [.metadata.name, "\(.spec.names.plural).\(.spec.group)", .spec.scope] | @tsv' <<<"$crds")
  return 1
}
rm_crds() { # GROUPE
  [[ "$DELETE_CRDS" == 1 ]] || { log "CRD *.$1 conservées (--delete-crds absent)"; return; }
  local before="$STATE_DIR/crds-before.txt" crds c keep=()
  [[ -f "$before" ]] || { log "CRD *.$1 conservées : $before absent (CRD d'avant l'essai inconnues)"; return; }
  if crd_in_use_outside "$1"; then return; fi
  crds="$(kubectl get crd -o name)" || { log "liste des CRD illisible : conservées"; return; }
  for c in $(grep -E "\\.$1\$" <<<"$crds" || true); do
    if grep -qx "$c" "$before"; then log "$c existait avant l'essai : conservée"; else keep+=("$c"); fi
  done
  (( ${#keep[@]} == 0 )) || run kubectl delete "${keep[@]}"
}

undo_12() {
  local cr
  cr="$(kubectl get clusterrole lab-cluster-agent-reduced --ignore-not-found -o name)" || die "lecture du ClusterRole réduit en erreur"
  [[ -n "$cr" ]] || { log "RBAC réduit absent : rien à annuler"; return; }
  local tgz; tgz="$(fetch_chart openchoreo-data-plane "$OPENCHOREO_DP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_DP_TGZ_SHA256")"
  run helm upgrade openchoreo-data-plane "$tgz" -n openchoreo-data-plane -f "$INSTALL_DIR/values/openchoreo-data-plane.yaml" \
    --set clusterAgent.rbac.create=true --wait --timeout 10m
  run "${KD[@]}" -f "$ROOT/platform/cluster-agent/reduced-clusterrole.yaml"
}
undo_11() {
  # Pas de finalizer resources-finalizer : supprimer les Application conserve les objets (CLEANUP.md 1).
  run "${KD[@]}" -n lab-argocd applications.argoproj.io lab-root lab-platform lab-authz
  run "${KD[@]}" -f "$INSTALL_DIR/argocd/project-lab.yaml"
  helm_rm lab-argocd argocd
  local ns
  ns="$(kubectl get ns argocd --ignore-not-found -o name)" || die "lecture du namespace argocd en erreur"
  if [[ -n "$ns" ]]; then log "namespace argocd présent (kube-ops) : CRD argoproj.io conservées"; else rm_crds argoproj.io; fi
}
undo_10() {
  refuse_if_argo 10
  # Le PVC lab-pg (block volume OCI de l'essai, reclaim Delete) disparaît avec le Cluster : seul volume
  # OCI que l'essai supprime. Les volumes d'origine d'OKE ne sont liés à aucun PVC d'essai.
  run "${KD[@]}" -f "$ROOT/platform/data/lab-pg-cluster.yaml" --wait=true
  run "${KD[@]}" -f "$M/51-lab-pg-oke-overlay.yaml"
  helm_rm lab-cnpg cnpg
}
undo_9() {
  refuse_if_argo 9
  # Les Components (Phase C) doivent être supprimés AVANT (CLEANUP.md 2 : leurs finalizers nettoient dp-*).
  local crd comps
  crd="$(kubectl get crd components.openchoreo.dev --ignore-not-found -o name)" || die "lecture des CRD openchoreo en erreur"
  if [[ -n "$crd" ]]; then
    comps="$(kubectl get components.openchoreo.dev -A -o name)" || die "lecture des Components en erreur"
    [[ -z "$comps" ]] || die "des Components existent encore : CLEANUP.md étape 2 d'abord"
  fi
  run "${KD[@]}" -f "$ROOT/platform/resource-types/" -f "$ROOT/platform/project-types/" \
    -f "$ROOT/platform/traits/" -f "$ROOT/platform/component-types/"
  run "${KD[@]}" -f "$M/40-openchoreo-env.yaml"
  run kubectl label namespace default openchoreo.dev/control-plane-
}
undo_8() { run "${KD[@]}" clusterdataplanes.openchoreo.dev default; }
undo_7() {
  refuse_if_argo 7
  helm_rm openchoreo-data-plane openchoreo-data-plane
  run "${KD[@]}" -f "$M/12-gateway-parameters.yaml" -f "$M/11-gateway-tls.yaml"
  run "${KD[@]}" -f "$ROOT/platform/cluster-agent/extra-rbac-quota.yaml"
  run "${KD[@]}" -f "$ROOT/platform/policies/"
}
undo_6b() { # Portail seul : CP réinstallé sans Backstage ; Secret et CNP du portail supprimés.
  local tgz; tgz="$(fetch_chart openchoreo-control-plane "$OPENCHOREO_CP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_CP_TGZ_SHA256")"
  local rel
  rel="$(helm -n openchoreo-control-plane list -a -q)" || die "helm list en erreur"
  if grep -qx openchoreo-control-plane <<<"$rel"; then
    run helm upgrade openchoreo-control-plane "$tgz" -n openchoreo-control-plane \
      -f "$INSTALL_DIR/values/openchoreo-control-plane.yaml" --set backstage.enabled=false --wait --timeout 10m
  fi
  run "${KD[@]}" -n openchoreo-control-plane secret backstage-secrets
  run "${KD[@]}" -n openchoreo-control-plane ciliumnetworkpolicies.cilium.io lab-allow-backstage-authentik
}
undo_6() {
  helm_rm openchoreo-control-plane openchoreo-control-plane
  run "${KD[@]}" -f "$M/03-idp-egress.yaml"
  run "${KD[@]}" -n openchoreo-control-plane secret backstage-secrets
  rm_crds openchoreo.dev
}
undo_5() {
  helm_rm openchoreo-control-plane kgateway
  # Le chart kgateway-crds met ses CRD dans templates/ sans option `keep` : `helm uninstall` les
  # supprimerait. Il n'est désinstallé qu'avec --delete-crds ET si les gardes de rm_crds passent.
  local before="$STATE_DIR/crds-before.txt"
  if [[ "$DELETE_CRDS" != 1 ]]; then log "release kgateway-crds (CRD kgateway.dev) conservée (--delete-crds absent)"; return; fi
  if [[ ! -f "$before" ]] || grep -q 'kgateway\.dev$' "$before"; then
    log "CRD kgateway.dev préexistantes ou état d'avant inconnu : release kgateway-crds conservée"; return
  fi
  if crd_in_use_outside kgateway.dev; then log "release kgateway-crds conservée"; return; fi
  helm_rm openchoreo-control-plane kgateway-crds
}
undo_4() {
  run "${KD[@]}" -f "$M/20-eso-lab-store.yaml"
  release_keeps_crds openchoreo-external-secrets external-secrets
  helm_rm openchoreo-external-secrets external-secrets
  rm_crds external-secrets.io
}
undo_3() {
  release_keeps_crds openchoreo-cert-manager cert-manager
  helm_rm openchoreo-cert-manager cert-manager
  rm_crds cert-manager.io
}
undo_2() { rm_crds gateway.networking.k8s.io; }

# migrate_cnpg_system : suppression de l'ancien namespace vide (revue B3). Conditions, toutes vérifiées
# en lecture, échec fermé : label part-of=openchoreo-lab ; aucune release Helm ; aucun objet namespacé
# hors ceux que l'étape 1 y a posés (quota, LimitRange, NP/CNP marqués part-of) et ceux que Kubernetes
# crée seul (ConfigMap kube-root-ca.crt, ServiceAccount default, Events).
migrate_cnpg_system() {
  local ns="$LEGACY_CNPG_NS" out part types objs foreign
  out="$(kubectl get namespace "$ns" --ignore-not-found -o name)" || die "lecture du namespace $ns en erreur"
  [[ -n "$out" ]] || { log "$ns absent : migration déjà faite"; return; }
  part="$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}')" || die "labels de $ns illisibles"
  [[ "$part" == openchoreo-lab ]] || die "$ns sans label part-of=openchoreo-lab : n'appartient pas à l'essai, NON supprimé"
  [[ -z "$(helm -n "$ns" list -a -q)" ]] || die "$ns contient une release Helm : NON supprimé"
  types="$(kubectl api-resources --namespaced=true --verbs=list -o name)" || die "api-resources en erreur"
  objs="$(kubectl -n "$ns" get "$(paste -sd, - <<<"$types")" -o json)" || die "inventaire de $ns en erreur : NON supprimé"
  foreign="$(jq -r '.items[]
    | select(.kind != "Event")
    | select(.kind != "ConfigMap" or .metadata.name != "kube-root-ca.crt")
    | select(.kind != "ServiceAccount" or .metadata.name != "default")
    | select((.metadata.labels["app.kubernetes.io/part-of"] // "") != "openchoreo-lab")
    | "\(.kind)/\(.metadata.name)"' <<<"$objs")"
  [[ -z "$foreign" ]] || die "$ns contient des objets hors essai : $(tr '\n' ' ' <<<"$foreign") ; NON supprimé"
  [[ "$(jq '[.items[] | select(.kind == "Pod" or .kind == "PersistentVolumeClaim")] | length' <<<"$objs")" == 0 ]] \
    || die "$ns contient des pods ou PVC : NON supprimé"
  log "$ns vide et marqué essai : suppression (remplacé par lab-cnpg)"
  run kubectl delete namespace "$ns" --wait=true --timeout=120s
}

undo_1() {
  local ns cells part out
  # dp-* : uniquement ceux créés par le CPT du labo (label en constante platform.smadja.dev/cell).
  cells="$(kubectl get ns -l platform.smadja.dev/cell=restricted -o name)" || die "liste des namespaces de cellule en erreur"
  for ns in ${cells//namespace\//}; do
    [[ "$ns" == dp-* ]] || continue
    run kubectl delete namespace "$ns" --wait=false
  done
  for ns in "${TRIAL_NS[@]}"; do
    out="$(kubectl get ns "$ns" --ignore-not-found -o name)" || die "lecture du namespace $ns en erreur"
    [[ -n "$out" ]] || continue
    part="$(kubectl get ns "$ns" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}')" || die "labels de $ns illisibles"
    [[ "$part" == openchoreo-lab ]] || { log "namespace $ns sans label part-of=openchoreo-lab : NON supprimé"; continue; }
    run kubectl delete namespace "$ns" --wait=false
  done
  migrate_cnpg_system
}
check_clean() { # CLEANUP.md étape 6 (lecture seule ; une lecture en erreur est signalée, jamais lue comme « propre »)
  [[ "$APPLY" == 1 ]] || { echo "[dry-run] vérification CLEANUP.md étape 6"; return; }
  local nss crds pv cs
  nss="$(kubectl get ns -o name)" || die "liste des namespaces en erreur"
  if grep -E '/(lab-|openchoreo|dp-)' <<<"$nss"; then log "namespaces restants (suppression en cours ?)"; else log "aucun namespace d'essai"; fi
  crds="$(kubectl get crd -o name)" || die "liste des CRD en erreur"
  if grep openchoreo <<<"$crds"; then log "CRD openchoreo restantes"; fi
  pv="$(kubectl get pv -o custom-columns=NAME:.metadata.name,CLAIM:.spec.claimRef.namespace,STATUS:.status.phase --no-headers)" \
    || die "liste des PV en erreur"
  printf '%s\n' "$pv"
  cs="$(kubectl get clusterrole,clusterrolebinding,validatingwebhookconfiguration,mutatingwebhookconfiguration -o name)" \
    || die "liste des objets cluster-scoped en erreur"
  grep -E 'openchoreo|lab-|cert-manager|external-secrets|kgateway|argocd' <<<"$cs" || log "aucun objet cluster-scoped d'essai restant"
}

case "$MODE" in
  step) declare -F "undo_$N" >/dev/null || die "étape inconnue : $N"; "undo_$N";;
  migrate) migrate_cnpg_system;;
  all) for n in 12 11 10 9 8 7 6b 6 5 4 3 2 1; do log "=== annulation étape $n"; "undo_$n"; done; check_clean;;
esac
