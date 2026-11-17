#!/usr/bin/env bash
# security-bundle.sh : security bundle PRIVÉ et TEMPORAIRE des charts OpenChoreo (docs/SECURITY-BUNDLE.md).
# Durcissement des droits de lecture rendus par les charts control plane et data plane ; détails hors dépôt.
# Sourcé par install.sh (fonctions helm_secure, rollback_secure, sb_require, sb_apply_extra) ou exécuté :
#   tools/oke/security-bundle.sh status            vérifie le bundle (empreinte, versions, digest, plugins), sans cluster
#   tools/oke/security-bundle.sh rollback REL REV  [--apply] rollback refusé si la révision REV n'est pas durcie
# Source de l'archive : $OPENCHOREO_SECURITY_BUNDLE (chemin local du .tar.gz) sinon `gh release download` depuis le
# dépôt privé du lock (accès GitHub de Paul). Cache : $STATE_DIR/security-bundle. ÉCHEC FERMÉ partout (die).
# shellcheck shell=bash

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  # shellcheck source=lib.sh
  . "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
fi

SB_LOCK="${SECURITY_BUNDLE_LOCK:-$ROOT/security/bundle.lock}"
SB_READY=0 SB_DIR="" SB_CP_PLUGIN="" SB_DP_PLUGIN="" SB_IMAGE="" SB_FORCED=() SB_RENDERED=""

sb_sha() { shasum -a 256 "$1" | awk '{print $1}'; }

# sb_require : bundle présent, empreinte = lock, manifest cohérent, charts de versions.env compatibles, image
# épinglée par digest, plugins installés dans le Helm isolé (HELM_DATA_HOME de lib.sh). Lecture et cache local
# seulement : aussi en dry-run. Une seule fois par processus.
sb_require() {
  [[ "$SB_READY" == 1 ]] && return 0
  need python3 shasum helm
  [[ "$SB_LOCK" == "$ROOT/security/bundle.lock" ]] || log "ATTENTION : lock non standard $SB_LOCK (tests uniquement)"
  [[ -f "$SB_LOCK" ]] || die "security bundle : lock absent ($SB_LOCK)"
  local BUNDLE_VERSION="" BUNDLE_SHA256="" BUNDLE_REPO="" BUNDLE_TAG="" BUNDLE_ASSET="" BUNDLE_CONTROLLER_IMAGE="" \
        BUNDLE_CP_CHART_VERSION="" BUNDLE_DP_CHART_VERSION=""
  # shellcheck source=../../security/bundle.lock
  . "$SB_LOCK"
  [[ "$BUNDLE_SHA256" =~ ^[0-9a-f]{64}$ ]] || die "security bundle : empreinte absente ou invalide dans le lock"
  [[ "$BUNDLE_CONTROLLER_IMAGE" =~ ^[a-z0-9][a-z0-9./_:-]*@sha256:[0-9a-f]{64}$ ]] \
    || die "security bundle : image du contrôleur non épinglée par digest dans le lock ('$BUNDLE_CONTROLLER_IMAGE')"
  [[ "$BUNDLE_CP_CHART_VERSION" == "$OPENCHOREO_VERSION" && "$BUNDLE_DP_CHART_VERSION" == "$OPENCHOREO_VERSION" ]] \
    || die "security bundle : charts du lock ($BUNDLE_CP_CHART_VERSION/$BUNDLE_DP_CHART_VERSION) != versions.env ($OPENCHOREO_VERSION)"
  local cache="$STATE_DIR/security-bundle" tgz
  mkdir -p "$cache"
  if [[ -n "${OPENCHOREO_SECURITY_BUNDLE:-}" ]]; then
    tgz="$OPENCHOREO_SECURITY_BUNDLE"
    [[ -f "$tgz" ]] || die "security bundle : OPENCHOREO_SECURITY_BUNDLE=$tgz introuvable"
  else
    tgz="$cache/$BUNDLE_ASSET"
    if [[ ! -f "$tgz" ]]; then
      need gh
      log "security bundle : téléchargement $BUNDLE_REPO@$BUNDLE_TAG ($BUNDLE_ASSET)"
      gh release download "$BUNDLE_TAG" -R "$BUNDLE_REPO" -p "$BUNDLE_ASSET" -D "$cache" >&2 \
        || die "security bundle ABSENT : accès au dépôt privé requis (docs/SECURITY-BUNDLE.md) ou OPENCHOREO_SECURITY_BUNDLE"
    fi
  fi
  [[ "$(sb_sha "$tgz")" == "$BUNDLE_SHA256" ]] || die "security bundle : empreinte de $tgz != lock ($BUNDLE_SHA256)"
  # Extraction NEUVE à chaque exécution (jamais un cache modifiable), filtre `data` (ni chemin absolu, ni ..).
  SB_DIR="$cache/x-$BUNDLE_SHA256"
  rm -rf "$SB_DIR"; mkdir -p "$SB_DIR"
  python3 -I -B -c 'import sys,tarfile; tarfile.open(sys.argv[1]).extractall(sys.argv[2], filter="data")' "$tgz" "$SB_DIR" \
    || die "security bundle : archive illisible"
  local top; top="$(find "$SB_DIR" -mindepth 1 -maxdepth 1)"
  [[ -n "$top" && "$(wc -l <<<"$top")" -eq 1 && -f "$top/manifest.json" ]] || die "security bundle : structure inattendue"
  SB_DIR="$top"
  local out
  out="$(python3 -I -B - "$SB_DIR" "$BUNDLE_VERSION" "$BUNDLE_CONTROLLER_IMAGE" "$OPENCHOREO_VERSION" \
      "$OPENCHOREO_CP_TGZ_SHA256" "$OPENCHOREO_DP_TGZ_SHA256" <<'PY'
import json, os, re, sys
d, ver, img, chart_ver, cp_sha, dp_sha = sys.argv[1:7]
def die(m): sys.stderr.write(f"security bundle : {m}\n"); sys.exit(2)
m = json.load(open(os.path.join(d, "manifest.json")))
if m.get("version") != ver: die(f"version du manifest {m.get('version')} != lock {ver}")
cc = m.get("compatible_charts") or {}
for chart, sha in (("openchoreo-control-plane", cp_sha), ("openchoreo-data-plane", dp_sha)):
    c = cc.get(chart) or {}
    if c.get("version") != chart_ver or c.get("tgz_sha256") != sha:
        die(f"chart {chart} {chart_ver} (versions.env) incompatible avec le bundle ({c.get('version')}, {c.get('tgz_sha256')})")
ci = m.get("controller_image") or ""
if ci != img or not re.match(r"^[^@]+@sha256:[0-9a-f]{64}$", ci): die(f"image du bundle '{ci}' != lock '{img}' ou sans digest")
names = []
for plane in ("control-plane", "data-plane"):
    p = (m.get("plugins") or {}).get(plane) or {}
    if not p.get("name") or not os.path.isfile(os.path.join(d, p.get("path", "-"), "plugin.yaml")): die(f"plugin {plane} absent")
    names.append(p["name"])
for f in [m.get("check"), m.get("verify")] + list((m.get("extra_manifests") or {}).values()):
    if not f or not os.path.isfile(os.path.join(d, f)): die(f"fichier du bundle absent : {f}")
print(names[0], names[1], m["check"], m["verify"])
PY
  )" || die "security bundle : manifest.json refusé"
  local check verify
  read -r SB_CP_PLUGIN SB_DP_PLUGIN check verify <<<"$out"
  [[ "$check" == bin/check-manifest && "$verify" == bin/verify-bundle ]] || die "security bundle : outils inattendus"
  "$SB_DIR/bin/verify-bundle" >&2 || die "security bundle : vérification interne (verify-bundle) en échec"
  python3 -I -c 'import yaml' 2>/dev/null || die "security bundle : python3 sans PyYAML (requis par les post-renderers)"
  mkdir -p "$HELM_DATA_HOME" "$HELM_CONFIG_HOME" "$HELM_CACHE_HOME"
  local p
  for p in "$SB_CP_PLUGIN" "$SB_DP_PLUGIN"; do
    helm plugin uninstall "$p" >/dev/null 2>&1 || true
    helm plugin install "$SB_DIR/plugins/$p" --verify=false >/dev/null 2>&1 || die "security bundle : installation du plugin $p en échec"
    helm plugin list 2>/dev/null | awk '{print $1}' | grep -qx "$p" || die "security bundle : plugin $p non installé"
  done
  SB_IMAGE="$BUNDLE_CONTROLLER_IMAGE" SB_READY=1
  log "security bundle $BUNDLE_VERSION vérifié (sha256 ${BUNDLE_SHA256:0:12}…, charts $OPENCHOREO_VERSION, image @${SB_IMAGE##*@sha256:}, plugins $SB_CP_PLUGIN $SB_DP_PLUGIN)"
}

sb_check() { "$SB_DIR/bin/check-manifest" "$1"; }   # PLAN(cp|dp) < manifest

# sb_prerender cp|dp RELEASE CHART_TGZ NS [ARGS...] : contrôles SANS écriture (arguments, sha256 du chart, rendu local
# post-rendu puis vérifié). Définit SB_FORCED (values et post-renderer imposés). Appelé en tête d'étape (avant la
# première écriture de l'étape) et par helm_secure.
sb_prerender() {
  local plane="$1" rel="$2" tgz="$3" ns="$4"; shift 4
  sb_require
  local a exp
  for a in "$@"; do
    case "$a" in
      --post-renderer*|*controllerManager.image*|*clusterAgent.rbac*|--no-hooks|--skip-*|--force*|--take-ownership|--reuse-values|--reset-then-reuse-values)
        die "helm_secure : argument refusé ($a)";;
    esac
  done
  case "$plane" in
    cp) exp="$OPENCHOREO_CP_TGZ_SHA256"
        local ref="${SB_IMAGE%@*}"
        SB_FORCED=(--set "controllerManager.image.repository=${ref%:*}" --set "controllerManager.image.tag=${ref##*:}@${SB_IMAGE#*@}"
                   --post-renderer "$SB_CP_PLUGIN");;
    dp) exp="$OPENCHOREO_DP_TGZ_SHA256"
        SB_FORCED=(--set clusterAgent.rbac.create=false --post-renderer "$SB_DP_PLUGIN");;
    *) die "helm_secure : plan inconnu '$plane'";;
  esac
  [[ "$(sb_sha "$tgz")" == "$exp" ]] || die "helm_secure : chart $tgz != sha256 épinglé"
  # Les --set imposés passent APRÈS ceux de l'appelant : ils l'emportent.
  SB_RENDERED="$(mktemp)"
  helm template "$rel" "$tgz" -n "$ns" "$@" "${SB_FORCED[@]}" > "$SB_RENDERED" || die "helm_secure : rendu $rel en échec"
  sb_check "$plane" < "$SB_RENDERED" || die "helm_secure : rendu $rel NON durci, aucune écriture"
  log "rendu $rel vérifié avec le security bundle"
}

# helm_secure cp|dp RELEASE CHART_TGZ NS [ARGS...] : SEUL chemin d'installation/upgrade des charts OpenChoreo.
# Post-renderer et values imposés ; rendu vérifié AVANT l'écriture, manifest stocké vérifié APRÈS.
helm_secure() {
  local plane="$1" rel="$2" tgz="$3" ns="$4"; shift 4
  SB_FORCED=()
  sb_prerender "$plane" "$rel" "$tgz" "$ns" "$@"
  local force=()
  if [[ "$APPLY" == 1 && "$plane" == cp ]] && helm status "$rel" -n "$ns" >/dev/null 2>&1; then
    sb_cp_conflicts "$ns" || die "helm_secure : conflit d'écriture hors ConfigMap/$SB_CA_CM sur $rel, aucune écriture"
    force=(--force-conflicts)
  fi
  rm -f "$SB_RENDERED"
  run helm upgrade --install "$rel" "$tgz" -n "$ns" "$@" "${SB_FORCED[@]}" "${force[@]}"
  # Le chart remet un ConfigMap CA vide : recopie IMMÉDIATE de la CA, puis redémarrage de ses lecteurs.
  [[ "$plane" != cp ]] || sb_cp_ca_refresh
  if [[ "$APPLY" == 1 ]]; then
    helm get manifest "$rel" -n "$ns" | sb_check "$plane" \
      || die "helm_secure : révision stockée de $rel NON durcie : rollback_secure vers la dernière révision durcie"
  fi
}

# Upgrade du CP (Helm 4, server-side apply) : le ConfigMap $SB_CA_CM est rendu VIDE par le chart et peuplé hors Helm
# (CA publique du cluster-gateway). Seul conflit d'écriture admis ; tout autre conflit => refus (jamais de
# --force-conflicts aveugle). Contrôle objet par objet en dry-run serveur, avec le gestionnaire de champs de Helm.
SB_CA_CM=cluster-gateway-ca
sb_cp_conflicts() {
  local ns="$1" line name err bad=0
  while IFS=$'\t' read -r name line; do
    if ! err="$(kubectl apply --server-side --dry-run=server --field-manager=helm -n "$ns" -f - <<<"$line" 2>&1 >/dev/null)"; then
      if grep -qi conflict <<<"$err" && [[ "$name" == "ConfigMap/$SB_CA_CM" ]]; then log "conflit attendu : $name (forcé, CA recopiée ensuite)"
      else log "conflit ou erreur NON admis : $name : ${err:0:200}"; bad=1; fi
    fi
  done < <(python3 -I -c '
import json, sys, yaml
for d in yaml.safe_load_all(open(sys.argv[1])):
    if d: print(d["kind"] + "/" + d["metadata"]["name"] + "\t" + json.dumps(d))' "$SB_RENDERED")
  return "$bad"
}

# Recopie la CA PUBLIQUE (ca.crt seul) de secret/$SB_CA_CM vers les ConfigMap des deux plans, puis redémarre
# controller-manager et openchoreo-api (sinon ils gardent une CA vide).
sb_cp_ca_refresh() {
  if [[ "$APPLY" != 1 ]]; then echo "[dry-run] recopie CA $SB_CA_CM (CP, DP) + restart controller-manager, openchoreo-api"; return; fi
  local ns ca d
  kubectl -n openchoreo-control-plane wait --for=condition=Ready --timeout=180s "certificate/$SB_CA_CM" >/dev/null \
    || die "certificat $SB_CA_CM non Ready"
  ca="$(kubectl -n openchoreo-control-plane get secret "$SB_CA_CM" -o jsonpath='{.data.ca\.crt}' | base64 -d)" \
    || die "CA $SB_CA_CM illisible"
  [[ "$ca" == "-----BEGIN CERTIFICATE-----"* ]] || die "CA $SB_CA_CM absente ou invalide : ConfigMap non recopié"
  for ns in openchoreo-control-plane openchoreo-data-plane; do
    kubectl get namespace "$ns" -o name >/dev/null 2>&1 || continue
    kubectl create configmap "$SB_CA_CM" --from-file=ca.crt=/dev/stdin -n "$ns" --dry-run=client -o yaml <<<"$ca" \
      | kubectl apply --server-side --force-conflicts --field-manager=openchoreo-lab -f - >/dev/null || die "recopie CA ($ns) en échec"
  done
  for d in controller-manager openchoreo-api; do
    kubectl -n openchoreo-control-plane rollout restart "deployment/$d" >/dev/null || die "restart $d en échec"
    kubectl -n openchoreo-control-plane rollout status "deployment/$d" --timeout=300s >/dev/null || die "rollout $d en échec"
  done
  log "CA $SB_CA_CM recopiée (CP, DP) ; controller-manager et openchoreo-api redémarrés"
}

# rollback_secure RELEASE NS REVISION : `helm rollback` rejoue le manifest stocké SANS post-renderer ; refus si ce
# manifest ne passe pas les invariants du bundle.
rollback_secure() {
  local rel="$1" ns="$2" rev="$3" plane
  case "$rel" in openchoreo-control-plane) plane="cp";; openchoreo-data-plane) plane="dp";; *) die "rollback_secure : release hors périmètre $rel";; esac
  [[ "$rev" =~ ^[0-9]+$ ]] || die "rollback_secure : révision invalide '$rev'"
  sb_require
  local man
  man="$(helm get manifest "$rel" -n "$ns" --revision "$rev")" || die "rollback_secure : manifest de $rel rév. $rev illisible"
  sb_check "$plane" <<<"$man" || die "rollback_secure : révision $rev de $rel NON durcie : rollback refusé"
  run helm rollback "$rel" "$rev" -n "$ns" --wait --timeout 10m
  [[ "$plane" != cp ]] || sb_cp_ca_refresh
  if [[ "$APPLY" == 1 ]]; then
    helm get manifest "$rel" -n "$ns" | sb_check "$plane" || die "rollback_secure : révision courante de $rel NON durcie"
  fi
}

# sb_apply_extra NOM : manifest complémentaire du bundle (ex. lab-pg, après création du namespace à l'étape 10).
sb_apply_extra() {
  sb_require
  local f
  f="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["extra_manifests"][sys.argv[2]])' "$SB_DIR/manifest.json" "$1")" \
    || die "security bundle : manifest complémentaire '$1' absent"
  run kubectl apply --server-side --field-manager=openchoreo-lab -f "$SB_DIR/$f"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    status) sb_require; echo "OK $SB_DIR";;
    rollback)
      [[ $# -ge 3 ]] || die "usage : $0 rollback RELEASE REVISION [--apply]"
      [[ "${4:-}" != --apply ]] || APPLY=1
      export APPLY
      guard_context
      case "$2" in openchoreo-control-plane) ns=openchoreo-control-plane;; *) ns=openchoreo-data-plane;; esac
      rollback_secure "$2" "$ns" "$3";;
    *) die "usage : $0 status | rollback RELEASE REVISION [--apply]";;
  esac
fi
