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
#     Les CRD visées et leurs groupes sont lus dans le RENDU des sources épinglées (helm template
#     --include-crds avec les values du labo ; manifest Gateway API vérifié par sha256), jamais dans une
#     liste écrite à la main ni par suffixe (revue PR #8, P2). Groupe voisin inconnu du rendu (ex.
#     x.cert-manager.io) => CRD CONSERVÉES. Toute lecture ou rendu en erreur => CRD CONSERVÉES (échec fermé).
# Périmètre : namespaces de TRIAL_NS (lib.sh) portant part-of=openchoreo-lab, dp-* portant le label du CPT
# cell-restricted, label openchoreo.dev/control-plane de `default` (exceptions OpenChoreo acquittées,
# missions/MISSION.md). Jamais d'autre namespace, jamais de volume OCI hors lab-pg.
# Argo (revue I4) : tant que l'Application lab-platform (ou lab-root) existe, les rollbacks des étapes
# qu'Argo adopte (7, 9, 10) sont REFUSÉS : selfHeal recréerait l'objet (ex. un nouveau volume de 50 Go).
# Annuler d'abord l'étape 11 (uninstall.sh --step 11). L'étape 1 (namespaces, dont lab-pg et son volume) est
# aussi refusée tant qu'une Application existe, et tant qu'un Component OpenChoreo existe (revue PR #8, P3).
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
TRIAL_NS_RE="^($(IFS='|'; echo "${TRIAL_NS[*]}"))$"

in_trial_ns() { [[ "$1" =~ $TRIAL_NS_RE ]]; }

# helm_releases NS : toutes les releases, tous statuts. `helm list -a` n'existe plus en Helm 4 (l'erreur
# « unknown shorthand flag: 'a' » était lue comme « aucune release » dans migrate_cnpg_system : échec
# OUVERT, preuve k3d tests/uninstall-k3d, 2026-11-17). Ces filtres combinés valent -a en Helm 3 et 4.
helm_releases() {
  helm -n "$1" list -q --deployed --failed --pending --superseded --uninstalling --uninstalled
}

# kd ARGS… : kubectl delete --ignore-not-found, en tolérant SEULEMENT un kind non servi (CRD absente :
# étape jamais installée, ex. --all sur un OKE où seules les étapes 1-5 ont été jouées). Toute autre erreur
# => abandon. Sans cette tolérance, `--all` s'arrêtait à undo_10 (« no matches for kind Cluster »).
kd() {
  if [[ "$APPLY" != 1 ]]; then printf '[dry-run] kubectl delete --ignore-not-found %s\n' "$*"; return; fi
  local out rc=0
  log "+ kubectl delete --ignore-not-found $*"
  out="$(kubectl delete --ignore-not-found "$@" 2>&1)" || rc=$?
  [[ -z "$out" ]] || printf '%s\n' "$out" >&2
  (( rc == 0 )) && return 0
  if grep -v -e '^ensure CRDs are installed first$' -e 'resource mapping not found for name' \
       -e "the server doesn't have a resource type" -e ' deleted' <<<"$out" | grep -q .; then
    die "kubectl delete en erreur (autre qu'un kind non servi)"
  fi
  log "kind(s) non servi(s) (CRD absente) : rien à supprimer pour ces objets"
}

helm_rm() { # NS RELEASE : seulement dans un namespace d'essai ; lecture en erreur => abandon
  in_trial_ns "$1" || die "helm_rm : namespace $1 hors essai"
  local rels
  rels="$(helm_releases "$1")" || die "helm list -n $1 en erreur"
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

# argo_adopts : vrai si une Application existe dans lab-argocd (n'importe laquelle : toute Application
# peut gérer un objet de l'essai avec selfHeal). CRD absente => faux. Erreur => abandon.
argo_adopts() {
  local crd apps
  crd="$(kubectl get crd applications.argoproj.io --ignore-not-found -o name)" || die "lecture des CRD argoproj en erreur"
  [[ -n "$crd" ]] || return 1
  apps="$(kubectl -n lab-argocd get applications.argoproj.io -o name)" || die "lecture des Application Argo en erreur"
  [[ -n "$apps" ]]
}
refuse_if_argo() { # ÉTAPE
  # Dry-run de --all : l'étape 11 (suppression des Application) n'a pas été jouée ; en --apply elle l'a été,
  # et la garde relit l'état réel.
  if [[ "$APPLY" != 1 && "$MODE" == all ]]; then log "[dry-run] étape $1 : garde Argo évaluée après l'annulation réelle de l'étape 11"; return; fi
  if argo_adopts; then die "étape $1 : Application Argo présente dans lab-argocd (selfHeal recréerait les objets) : uninstall.sh --step 11 d'abord"; fi
}
# refuse_if_components ÉTAPE : des Components OpenChoreo existent => abandon (CLEANUP.md 2 : leurs
# finalizers nettoient dp-* ; supprimer dp-* avant laisserait le contrôleur les recréer). Lecture en erreur
# => abandon. CRD absente => rien à vérifier.
refuse_if_components() {
  local crd comps
  crd="$(kubectl get crd components.openchoreo.dev --ignore-not-found -o name)" || die "lecture des CRD openchoreo en erreur"
  [[ -n "$crd" ]] || return 0
  comps="$(kubectl get components.openchoreo.dev -A -o name)" || die "lecture des Components en erreur"
  [[ -z "$comps" ]] || die "étape $1 : des Components existent encore : CLEANUP.md étape 2 d'abord"
}

CRD_PREFIX=customresourcedefinition.apiextensions.k8s.io

# chart_crds CLÉ : « nom<TAB>groupe » de chaque CRD que l'essai installe pour CLÉ, lus dans le RENDU des
# sources épinglées (mêmes values et options que install.sh). Clé inconnue, rendu en erreur ou vide =>
# code 1 (l'appelant CONSERVE les CRD). Téléchargements locaux seulement (STATE_DIR), aussi en dry-run.
chart_crds() {
  local out tgz V="$INSTALL_DIR/values"
  case "$1" in
    gateway-api)
      tgz="$(fetch_gw_crds)" || return 1
      out="$(cat "$tgz")" || return 1;;
    cert-manager)
      tgz="$(fetch_chart cert-manager "$CERT_MANAGER_CHART" "$CERT_MANAGER_VERSION" "$CERT_MANAGER_TGZ_SHA256")" || return 1
      out="$(helm template cert-manager "$tgz" -n openchoreo-cert-manager --include-crds -f "$V/cert-manager.yaml")" || return 1;;
    external-secrets)
      tgz="$(fetch_chart external-secrets "$ESO_CHART" "$ESO_VERSION" "$ESO_TGZ_SHA256")" || return 1
      out="$(helm template external-secrets "$tgz" -n openchoreo-external-secrets --include-crds -f "$V/external-secrets.yaml")" || return 1;;
    kgateway-crds)
      tgz="$(fetch_chart kgateway-crds "$KGATEWAY_CRDS_CHART" "$KGATEWAY_VERSION" "$KGATEWAY_CRDS_TGZ_SHA256")" || return 1
      out="$(helm template kgateway-crds "$tgz" -n openchoreo-control-plane --include-crds)" || return 1;;
    openchoreo-control-plane)
      tgz="$(fetch_chart openchoreo-control-plane "$OPENCHOREO_CP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_CP_TGZ_SHA256")" || return 1
      out="$(helm template openchoreo-control-plane "$tgz" -n openchoreo-control-plane --include-crds \
        -f "$V/openchoreo-control-plane.yaml" --set backstage.enabled=false)" || return 1;;
    argo-cd)
      tgz="$(fetch_chart argo-cd "$ARGOCD_CHART" "$ARGOCD_VERSION" "$ARGOCD_TGZ_SHA256" "$ARGOCD_REPO")" || return 1
      out="$(helm template argocd "$tgz" -n lab-argocd --include-crds -f "$V/argocd.yaml")" || return 1;;
    *) log "chart_crds : clé inconnue '$1'"; return 1;;
  esac
  out="$(yq -N 'select(.kind == "CustomResourceDefinition") | .metadata.name + "\t" + .spec.group' <<<"$out")" || return 1
  [[ -n "$out" ]] || { log "chart_crds : aucune CRD dans le rendu de $1"; return 1; }
  printf '%s\n' "$out"
}

# crd_in_use_outside GROUPES (un par ligne, issus du rendu) : 0 (= « utilisée hors essai » ou doute, donc
# CONSERVER), 1 (= inutilisée). Objets namespacés : hors openchoreo-*, lab-*, dp-* (et `default` pour
# openchoreo.dev seulement). Objets cluster-scoped : sans label part-of=openchoreo-lab ni annotation de
# release Helm d'un namespace d'essai. Un groupe du cluster VOISIN d'un groupe rendu (l'un suffixe de
# l'autre, ex. x.cert-manager.io) mais absent du rendu est inconnu : CONSERVER (échec fermé, revue PR #8, P2).
crd_in_use_outside() {
  local groups crds crd res scope objs unknown nsre='^(openchoreo-|lab-|dp-)'
  groups="$(jq -Rn '[inputs | select(length > 0)]' <<<"$1")" || { log "groupes illisibles : CRD conservées"; return 0; }
  [[ "$(jq 'length' <<<"$groups")" != 0 ]] || { log "aucun groupe rendu : CRD conservées"; return 0; }
  jq -e 'map(. == "openchoreo.dev") | any' <<<"$groups" >/dev/null && nsre='^(openchoreo-|lab-|dp-|default$)'
  crds="$(kubectl get crd -o json)" || { log "liste des CRD illisible : CRD conservées"; return 0; }
  unknown="$(jq -r --argjson gs "$groups" '[.items[].spec.group] | unique | .[] as $c
      | select(($gs | map(. == $c) | any) | not)
      | select(any($gs[] as $g | ($c | endswith("." + $g)) or ($g | endswith("." + $c)); .))' <<<"$crds")" \
    || { log "groupes du cluster illisibles : CRD conservées"; return 0; }
  if [[ -n "$unknown" ]]; then
    log "groupe(s) de CRD inconnu(s) du rendu épinglé : $(tr '\n' ' ' <<<"$unknown") : CRD conservées"; return 0
  fi
  while IFS=$'\t' read -r crd res scope; do
    [[ -n "$crd" ]] || continue
    objs="$(kubectl get "$res" -A -o json)" || { log "objets $res illisibles : CRD conservées"; return 0; }
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
  done < <(jq -r --argjson gs "$groups" '.items[] | select(.spec.group as $g | $gs | map(. == $g) | any)
             | [.metadata.name, "\(.spec.names.plural).\(.spec.group)", .spec.scope] | @tsv' <<<"$crds")
  return 1
}

# rm_crds CLÉ : supprime les CRD NOMMÉES par le rendu de CLÉ (jamais par suffixe), si toutes les gardes passent.
rm_crds() {
  [[ "$DELETE_CRDS" == 1 ]] || { log "CRD de $1 conservées (--delete-crds absent)"; return; }
  local before="$STATE_DIR/crds-before.txt" rendered crds name keep=()
  [[ -f "$before" ]] || { log "CRD de $1 conservées : $before absent (CRD d'avant l'essai inconnues)"; return; }
  rendered="$(chart_crds "$1")" || { log "CRD de $1 conservées : rendu épinglé indisponible"; return; }
  if crd_in_use_outside "$(cut -f2 <<<"$rendered" | sort -u)"; then return; fi
  crds="$(kubectl get crd -o name)" || { log "liste des CRD illisible : conservées"; return; }
  while IFS=$'\t' read -r name _; do
    grep -qx "$CRD_PREFIX/$name" <<<"$crds" || continue
    if grep -qx "$CRD_PREFIX/$name" "$before"; then log "$name existait avant l'essai : conservée"; else keep+=("$CRD_PREFIX/$name"); fi
  done <<<"$rendered"
  (( ${#keep[@]} == 0 )) || run kubectl delete "${keep[@]}"
}

# rm_lab_o_apps : retire l'ApplicationSet `lab-o` (T-491) puis les Applications `lab-o-<app>` qu'il a générées.
# Appelée APRÈS la suppression de lab-root (sinon selfHeal recréerait l'ApplicationSet). Ordre : l'ApplicationSet
# d'abord (sinon le contrôleur recréerait les Applications). preserveResourcesOnDeletion=true et aucun
# resources-finalizer dans le modèle : supprimer l'ApplicationSet ou une Application CONSERVE les objets
# applicatifs (platform/install/argocd/apps/lab-apps.yaml). Garde : une Application lab-o-* qui porterait un
# resources-finalizer supprimerait ses objets en cascade => abandon. Périmètre : namespace lab-argocd, noms
# `lab-o-*` ET label part-of=openchoreo-lab uniquement (jamais une Application que le labo n'a pas créée).
rm_lab_o_apps() {
  local crd apps casc names
  kd -n lab-argocd applicationsets.argoproj.io lab-o
  crd="$(kubectl get crd applications.argoproj.io --ignore-not-found -o name)" || die "lecture des CRD argoproj en erreur"
  [[ -n "$crd" ]] || return 0
  apps="$(kubectl -n lab-argocd get applications.argoproj.io -o json)" || die "lecture des Application Argo en erreur"
  casc="$(jq -r '.items[] | select((.metadata.name | startswith("lab-o-")) and .metadata.labels["app.kubernetes.io/part-of"] == "openchoreo-lab"
      and ((.metadata.finalizers // []) | any(startswith("resources-finalizer"))))
      | .metadata.name' <<<"$apps")" || die "liste des Application lab-o-* illisible"
  [[ -z "$casc" ]] || die "Application(s) $(tr '\n' ' ' <<<"$casc")avec resources-finalizer : leur suppression effacerait les objets applicatifs (conservation attendue) : abandon"
  names="$(jq -r '.items[] | select((.metadata.name | startswith("lab-o-")) and .metadata.labels["app.kubernetes.io/part-of"] == "openchoreo-lab")
      | .metadata.name' <<<"$apps")" || die "liste des Application lab-o-* illisible"
  [[ -n "$names" ]] || return 0
  # shellcheck disable=SC2046
  kd -n lab-argocd applications.argoproj.io $(printf '%s\n' "$names")
}
undo_12() {
  local cr
  cr="$(kubectl get clusterrole lab-cluster-agent-reduced --ignore-not-found -o name)" || die "lecture du ClusterRole réduit en erreur"
  [[ -n "$cr" ]] || { log "RBAC réduit absent : rien à annuler"; return; }
  local tgz; tgz="$(fetch_chart openchoreo-data-plane "$OPENCHOREO_DP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_DP_TGZ_SHA256")"
  run helm upgrade openchoreo-data-plane "$tgz" -n openchoreo-data-plane -f "$INSTALL_DIR/values/openchoreo-data-plane.yaml" \
    --set clusterAgent.rbac.create=true --wait --timeout 10m
  kd -f "$ROOT/platform/cluster-agent/reduced-clusterrole.yaml"
}
undo_11() {
  # Pas de finalizer resources-finalizer : supprimer les Application conserve les objets (CLEANUP.md 1).
  # lab-k-root (T-495) : supprimer l'Application CONSERVE les ApplicationSets du bras K (aucun finalizer) ;
  # leur retrait et celui des Applications lab-k-* relèvent du nettoyage du banc (T-212), pas de cette étape.
  kd -n lab-argocd applications.argoproj.io lab-root lab-platform lab-authz lab-k-root
  rm_lab_o_apps
  kd -f "$INSTALL_DIR/argocd/project-lab.yaml"
  helm_rm lab-argocd argocd
  local ns
  ns="$(kubectl get ns argocd --ignore-not-found -o name)" || die "lecture du namespace argocd en erreur"
  if [[ -n "$ns" ]]; then log "namespace argocd présent (kube-ops) : CRD argoproj.io conservées"; else rm_crds argo-cd; fi
}
undo_10() {
  refuse_if_argo 10
  # Le PVC lab-pg (block volume OCI de l'essai, reclaim Delete) disparaît avec le Cluster : seul volume
  # OCI que l'essai supprime. Les volumes d'origine d'OKE ne sont liés à aucun PVC d'essai.
  kd -f "$ROOT/platform/data/lab-pg-cluster.yaml" --wait=true
  kd -f "$M/51-lab-pg-oke-overlay.yaml"
  helm_rm lab-cnpg cnpg
}
undo_9() {
  refuse_if_argo 9
  # Les Components (Phase C) doivent être supprimés AVANT (CLEANUP.md 2 : leurs finalizers nettoient dp-*).
  refuse_if_components 9
  kd -f "$ROOT/platform/resource-types/" -f "$ROOT/platform/project-types/" \
    -f "$ROOT/platform/traits/" -f "$ROOT/platform/component-types/"
  kd -f "$M/40-openchoreo-env.yaml"
  run kubectl label namespace default openchoreo.dev/control-plane-
}
undo_8() { kd clusterdataplanes.openchoreo.dev default; }
undo_7() {
  refuse_if_argo 7
  helm_rm openchoreo-data-plane openchoreo-data-plane
  kd -f "$M/12-gateway-parameters.yaml" -f "$M/11-gateway-tls.yaml"
  kd -f "$ROOT/platform/cluster-agent/extra-rbac-quota.yaml"
  kd -f "$ROOT/platform/policies/"
}
undo_6b() { # Portail seul : CP réinstallé sans Backstage ; Secret et CNP du portail supprimés.
  local tgz; tgz="$(fetch_chart openchoreo-control-plane "$OPENCHOREO_CP_CHART" "$OPENCHOREO_VERSION" "$OPENCHOREO_CP_TGZ_SHA256")"
  local rel
  rel="$(helm_releases openchoreo-control-plane)" || die "helm list en erreur"
  if grep -qx openchoreo-control-plane <<<"$rel"; then
    run helm upgrade openchoreo-control-plane "$tgz" -n openchoreo-control-plane \
      -f "$INSTALL_DIR/values/openchoreo-control-plane.yaml" --set backstage.enabled=false --wait --timeout 10m
  fi
  kd -n openchoreo-control-plane secret backstage-secrets
  kd -n openchoreo-control-plane ciliumnetworkpolicies.cilium.io lab-allow-backstage-authentik
}
undo_6() {
  helm_rm openchoreo-control-plane openchoreo-control-plane
  kd -f "$M/03-idp-egress.yaml"
  kd -n openchoreo-control-plane secret backstage-secrets
  rm_crds openchoreo-control-plane
}
undo_5() {
  helm_rm openchoreo-control-plane kgateway
  kd -f "$M/05-kgateway-rbac.yaml"  # RBAC versionné (T-060), après le contrôleur qui l'utilise
  # Le chart kgateway-crds met ses CRD dans templates/ sans option `keep` : `helm uninstall` les
  # supprimerait. Il n'est désinstallé qu'avec --delete-crds ET si les gardes de rm_crds passent.
  local before="$STATE_DIR/crds-before.txt" rendered name
  if [[ "$DELETE_CRDS" != 1 ]]; then log "release kgateway-crds conservée (--delete-crds absent)"; return; fi
  [[ -f "$before" ]] || { log "état d'avant inconnu ($before absent) : release kgateway-crds conservée"; return; }
  # Groupes et noms lus dans le rendu épinglé (gateway.kgateway.dev, revue PR #8, P2), jamais à la main.
  rendered="$(chart_crds kgateway-crds)" || { log "rendu kgateway-crds indisponible : release conservée"; return; }
  while IFS=$'\t' read -r name _; do
    if grep -qx "$CRD_PREFIX/$name" "$before"; then log "CRD $name préexistante : release kgateway-crds conservée"; return; fi
  done <<<"$rendered"
  if crd_in_use_outside "$(cut -f2 <<<"$rendered" | sort -u)"; then log "release kgateway-crds conservée"; return; fi
  # Sans --wait : la suppression d'une CRD qui contient encore des CR d'essai passe par Terminating, que
  # `helm uninstall --wait` (Helm 4) rapporte comme une ERREUR alors que la release est bien supprimée (k3d,
  # tests/uninstall-k3d R5b, 2026-11-17). On attend ensuite la disparition des CRD NOMMÉES par le rendu.
  local rels names=()
  rels="$(helm_releases openchoreo-control-plane)" || die "helm list -n openchoreo-control-plane en erreur"
  grep -qx kgateway-crds <<<"$rels" || { log "release openchoreo-control-plane/kgateway-crds absente"; return; }
  run helm -n openchoreo-control-plane uninstall kgateway-crds
  while IFS=$'\t' read -r name _; do names+=("crd/$name"); done <<<"$rendered"
  run kubectl wait --for=delete "${names[@]}" --timeout=180s
}
undo_4() {
  kd -f "$M/20-eso-lab-store.yaml"
  release_keeps_crds openchoreo-external-secrets external-secrets
  helm_rm openchoreo-external-secrets external-secrets
  rm_crds external-secrets
}
undo_3() {
  release_keeps_crds openchoreo-cert-manager cert-manager
  helm_rm openchoreo-cert-manager cert-manager
  rm_crds cert-manager
}
undo_2() { rm_crds gateway-api; }

# migrate_cnpg_system : suppression de l'ancien namespace vide (revue B3). Conditions, toutes vérifiées
# en lecture, échec fermé : label part-of=openchoreo-lab ; aucune release Helm ; aucun objet namespacé
# hors ceux que l'étape 1 y a posés (ResourceQuota, LimitRange, NP/CNP marqués part-of : ces kinds-là
# seulement) et ceux que Kubernetes crée seul (ConfigMap kube-root-ca.crt, ServiceAccount default, Events).
migrate_cnpg_system() {
  local ns="$LEGACY_CNPG_NS" out part types objs foreign
  out="$(kubectl get namespace "$ns" --ignore-not-found -o name)" || die "lecture du namespace $ns en erreur"
  [[ -n "$out" ]] || { log "$ns absent : migration déjà faite"; return; }
  part="$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/part-of}')" || die "labels de $ns illisibles"
  [[ "$part" == openchoreo-lab ]] || die "$ns sans label part-of=openchoreo-lab : n'appartient pas à l'essai, NON supprimé"
  local rels
  rels="$(helm_releases "$ns")" || die "helm list -n $ns en erreur : NON supprimé"
  [[ -z "$rels" ]] || die "$ns contient une release Helm : NON supprimé"
  types="$(kubectl api-resources --namespaced=true --verbs=list -o name)" || die "api-resources en erreur"
  objs="$(kubectl -n "$ns" get "$(paste -sd, - <<<"$types")" -o json)" || die "inventaire de $ns en erreur : NON supprimé"
  # Objets tolérés : ceux que Kubernetes crée seul, et SEULEMENT les kinds que l'étape 1 posait (quota,
  # LimitRange, NetworkPolicy, CiliumNetworkPolicy) avec part-of. Tout autre objet, même étiqueté (ex. un
  # ConfigMap part-of=openchoreo-lab), fait refuser (preuve k3d tests/uninstall-k3d M02, 2026-11-17).
  foreign="$(jq -r '.items[]
    | select(.kind != "Event")
    | select(.kind != "ConfigMap" or .metadata.name != "kube-root-ca.crt")
    | select(.kind != "ServiceAccount" or .metadata.name != "default")
    | select(((.kind | IN("ResourceQuota", "LimitRange", "NetworkPolicy", "CiliumNetworkPolicy"))
              and (.metadata.labels["app.kubernetes.io/part-of"] // "") == "openchoreo-lab") | not)
    | "\(.kind)/\(.metadata.name)"' <<<"$objs")"
  [[ -z "$foreign" ]] || die "$ns contient des objets hors essai : $(tr '\n' ' ' <<<"$foreign") ; NON supprimé"
  [[ "$(jq '[.items[] | select(.kind == "Pod" or .kind == "PersistentVolumeClaim")] | length' <<<"$objs")" == 0 ]] \
    || die "$ns contient des pods ou PVC : NON supprimé"
  log "$ns vide et marqué essai : suppression (remplacé par lab-cnpg)"
  run kubectl delete namespace "$ns" --wait=true --timeout=120s
}

undo_1() {
  local ns cells part out rels
  # Revue PR #8, P3 : lab-pg (Namespace + Cluster CNPG) est synchronisé par Argo avec selfHeal ; le
  # supprimer sous Argo recréerait un block volume de 50 Go. Et dp-* ne se suppriment qu'une fois les
  # Components partis (sinon le contrôleur OpenChoreo les recrée). Gardes AVANT toute écriture.
  refuse_if_argo 1
  refuse_if_components 1
  # Aucune release Helm ne doit rester dans un namespace d'essai : supprimer le namespace effacerait la
  # release (Secret) et ORPHELINERAIT ses objets cluster-scoped (ClusterRole, webhooks cert-manager à
  # failurePolicy Fail, CRD). Constaté sur k3d (tests/uninstall-k3d/evidence/R1-orphelins-avant-garde.log).
  if [[ "$APPLY" == 1 || "$MODE" != all ]]; then
    for ns in "${TRIAL_NS[@]}"; do
      out="$(kubectl get ns "$ns" --ignore-not-found -o name)" || die "lecture du namespace $ns en erreur"
      [[ -n "$out" ]] || continue
      rels="$(helm_releases "$ns")" || die "helm list -n $ns en erreur"
      [[ -z "$rels" ]] || die "étape 1 : release(s) Helm encore présente(s) dans $ns ($(tr '\n' ' ' <<<"$rels")) : annuler d'abord les étapes 3 à 11"
    done
  fi
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
