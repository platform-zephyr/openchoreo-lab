#!/usr/bin/env bash
# Tests de REFUS du security bundle (docs/SECURITY-BUNDLE.md), SANS cluster et SANS le vrai bundle : FAUX bundles
# construits ici, kubectl et helm FACTICES (PATH) qui journalisent chaque appel ; une écriture = ligne WRITE.
# Seuls `helm pull` (charts épinglés, sha256 vérifié par fetch_chart) et le calcul d'empreintes sont réels.
# Usage : tests/security-bundle/run.sh   (bash, python3, jq, shasum, helm ; réseau au 1er téléchargement des charts
# sauf si SECURITY_BUNDLE_CHART_CACHE désigne un dossier contenant les .tgz OpenChoreo déjà vérifiés)
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/sb-tests.XXXXXX")"
trap '[[ -n "${KEEP:-}" ]] || rm -rf "$WORK"' EXIT
REAL_HELM="$(command -v helm)"
BIN="$WORK/bin" FIX="$WORK/fix" STATE="$WORK/state" LOGF="$WORK/calls.log"
mkdir -p "$BIN" "$FIX" "$STATE/charts" "$WORK/access"
if [[ -n "${SECURITY_BUNDLE_CHART_CACHE:-}" ]]; then cp "$SECURITY_BUNDLE_CHART_CACHE"/openchoreo-*.tgz "$STATE/charts/" 2>/dev/null || true; fi
: > "$WORK/access/kubeconfig"; chmod 600 "$WORK/access/kubeconfig"
# shellcheck source=../../platform/install/versions.env
. "$REPO/platform/install/versions.env"
pass=0 fail=0
FAKE_DIGEST="$(printf 'a%.0s' {1..64})"

cat > "$BIN/kubectl" <<'EOF'
#!/usr/bin/env bash
printf 'kubectl %s\n' "$*" >> "$LOGF"
if [[ "$1" == apply && "$*" == *--dry-run=server* ]]; then   # contrôle de conflit : rien n'est écrit
  in="$(cat)"; while read -r n; do [[ -n "$n" && "$in" == *"\"name\": \"$n\""* ]] && { echo "Apply failed with 1 conflict: conflict with \"kubectl\"" >&2; exit 1; }; done < "$FIX/conflicts"; exit 0
fi
v="$1"; [[ "$1" == -n ]] && v="$3"
case "$v" in delete|apply|label|annotate|patch|create|replace|scale|rollout) printf 'WRITE kubectl %s\n' "$*" >> "$LOGF"; exit 0;; esac
case "$*" in
  "config current-context") echo context-oracle-a1-test;;
  "config view --minify -o jsonpath={.clusters[0].cluster.server}") echo https://127.0.0.1:16443;;
  "config view --minify -o jsonpath={.clusters[0].cluster.tls-server-name}") echo 10.0.2.10;;
  "-n openchoreo-control-plane get secret cluster-gateway-ca -o jsonpath={.data.ca\\.crt}") printf -- '-----BEGIN CERTIFICATE-----\nX\n' | base64;;
  "get nodes -o json") echo '{"items":[{"spec":{"providerID":"ocid1.***MASQUÉ***"},"status":{"nodeInfo":{"architecture":"arm64"}}}]}';;
  *) exit 0;;   # autres lectures : réponse vide
esac
EOF
cat > "$BIN/helm" <<EOF
#!/usr/bin/env bash
printf 'helm %s\n' "\$*" >> "\$LOGF"
case "\$1" in
  pull|version) exec "$REAL_HELM" "\$@";;
  template) cat "\$FIX/template.yaml";;
  plugin)
    case "\$2" in
      install) [[ -f "\$3/plugin.yaml" ]] || exit 1; basename "\$3" >> "\$FIX/plugins";;
      uninstall) [[ -f "\$FIX/plugins" ]] && { grep -vx "\$3" "\$FIX/plugins" > "\$FIX/p2" || true; mv "\$FIX/p2" "\$FIX/plugins"; }; true;;
      list) echo "NAME VERSION"; cat "\$FIX/plugins" 2>/dev/null || true;;
    esac;;
  status) [[ -f "\$FIX/release-exists" ]];;
  get) r=current; for ((i=1; i<=\$#; i++)); do [[ "\${!i}" == --revision ]] && { j=\$((i+1)); r="rev-\${!j}"; }; done
       cat "\$FIX/\$r.yaml";;
  upgrade|install|rollback|uninstall) printf 'WRITE helm %s\n' "\$*" >> "\$LOGF";;
  *) printf 'UNHANDLED helm %s\n' "\$*" >> "\$LOGF"; exit 1;;
esac
EOF
chmod +x "$BIN/kubectl" "$BIN/helm"

# fake_bundle NOM [cle=valeur...] : construit $WORK/NOM.tar.gz et le lock $WORK/NOM.lock.
#   chart=VERSION (compat du manifest), image=REF (lock ET manifest), noplugin=1 (plugin DP absent), lockchart=VERSION
fake_bundle() {
  local n="$1"; shift
  local chart="$OPENCHOREO_VERSION" image="ghcr.io/example/controller:v1@sha256:$FAKE_DIGEST" noplugin=0 lockchart="$OPENCHOREO_VERSION" kv
  for kv in "$@"; do case "$kv" in chart=*) chart="${kv#*=}";; image=*) image="${kv#*=}";; noplugin=*) noplugin=1;; lockchart=*) lockchart="${kv#*=}";; esac; done
  local d="$WORK/b-$n/security-bundle-9.9.9"
  mkdir -p "$d/plugins/fake-cp" "$d/plugins/fake-dp" "$d/bin" "$d/rbac"
  printf 'name: fake-cp\n' > "$d/plugins/fake-cp/plugin.yaml"
  [[ "$noplugin" == 1 ]] || printf 'name: fake-dp\n' > "$d/plugins/fake-dp/plugin.yaml"
  printf '#!/usr/bin/env bash\ngrep -q HARDENED\n' > "$d/bin/check-manifest"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$d/bin/verify-bundle"
  chmod +x "$d/bin/"*
  printf 'kind: RoleBinding\n' > "$d/rbac/x.yaml"
  python3 -I - "$d/manifest.json" "$chart" "$OPENCHOREO_CP_TGZ_SHA256" "$OPENCHOREO_DP_TGZ_SHA256" "$image" <<'PY'
import json, sys
p, v, cps, dps, img = sys.argv[1:6]
json.dump({"version": "9.9.9", "controller_image": img,
           "compatible_charts": {"openchoreo-control-plane": {"version": v, "tgz_sha256": cps},
                                 "openchoreo-data-plane": {"version": v, "tgz_sha256": dps}},
           "plugins": {"control-plane": {"name": "fake-cp", "path": "plugins/fake-cp"},
                       "data-plane": {"name": "fake-dp", "path": "plugins/fake-dp"}},
           "extra_manifests": {"lab-pg": "rbac/x.yaml"}, "check": "bin/check-manifest", "verify": "bin/verify-bundle"}, open(p, "w"))
PY
  COPYFILE_DISABLE=1 tar -czf "$WORK/$n.tar.gz" -C "$WORK/b-$n" security-bundle-9.9.9
  cat > "$WORK/$n.lock" <<EOL
BUNDLE_VERSION="9.9.9"
BUNDLE_SHA256="$(shasum -a 256 "$WORK/$n.tar.gz" | awk '{print $1}')"
BUNDLE_REPO="example/none"
BUNDLE_TAG="bundle-v9.9.9"
BUNDLE_ASSET="security-bundle-9.9.9.tar.gz"
BUNDLE_CP_CHART_VERSION="$lockchart"
BUNDLE_DP_CHART_VERSION="$lockchart"
BUNDLE_CONTROLLER_IMAGE="$image"
EOL
}

envrun() { # LOCK ARCHIVE CMD... : exécute avec l'environnement factice (code retour conservé)
  local lock="$1" arc="$2"; shift 2
  : > "$LOGF"; rm -f "$FIX/plugins"
  env PATH="$BIN:$PATH" LOGF="$LOGF" FIX="$FIX" OKE_ACCESS_DIR="$WORK/access" KUBECONFIG="$WORK/access/kubeconfig" \
    OKE_PHASEB_STATE="$STATE" SECURITY_BUNDLE_LOCK="$lock" OPENCHOREO_SECURITY_BUNDLE="$arc" "$@" > "$WORK/out" 2>&1
}
ok()  { pass=$((pass + 1)); printf 'PASS %s\n' "$1"; }
ko()  { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; sed 's/^/    /' "$WORK/out" | tail -n 8; }
no_write() { ! grep -q '^WRITE' "$LOGF"; }
# expect_refusal ID MOTIF CMD... : code ≠ 0, motif dans la sortie, AUCUNE écriture helm/kubectl.
expect_refusal() {
  local id="$1" pat="$2"; shift 2
  if envrun "$@"; then ko "$id (accepté)"; elif ! grep -qiE "$pat" "$WORK/out"; then ko "$id (motif '$pat' absent)"; elif ! no_write; then ko "$id (écriture effectuée)"; else ok "$id"; fi
}
INSTALL="$REPO/tools/oke/install.sh"
printf 'kind: Role\nmetadata: {name: HARDENED}\n' > "$FIX/template.yaml"
cp "$FIX/template.yaml" "$FIX/current.yaml"; : > "$FIX/conflicts"

fake_bundle good
fake_bundle badchart chart=1.3.4
fake_bundle lockchart lockchart=1.3.4
fake_bundle mutable image=ghcr.io/example/controller:v1.3.3
fake_bundle noplugin noplugin=1
# Empreinte erronée : archive valide, lock d'une autre archive.
sed "s/^BUNDLE_SHA256=.*/BUNDLE_SHA256=\"$(printf '0%.0s' {1..64})\"/" "$WORK/good.lock" > "$WORK/badsha.lock"

for args in "--step 6" "--step 7" "--from 1 --to 11" "--from 6 --to 7" "--step 10" "--step 6b"; do
  # shellcheck disable=SC2086
  expect_refusal "sans-bundle[$args]" "security bundle" "$WORK/good.lock" "$WORK/absent.tar.gz" "$INSTALL" $args --apply --confirm-storage
done
expect_refusal "sans-bundle[dry-run --step 7]" "security bundle" "$WORK/good.lock" "$WORK/absent.tar.gz" "$INSTALL" --step 7
expect_refusal "empreinte-erronee[--step 7]" "empreinte" "$WORK/badsha.lock" "$WORK/good.tar.gz" "$INSTALL" --step 7 --apply
expect_refusal "chart-incompatible-bundle[--from 6]" "incompatible" "$WORK/badchart.lock" "$WORK/badchart.tar.gz" "$INSTALL" --from 6 --to 7 --apply
expect_refusal "chart-incompatible-lock[--step 6]" "versions.env" "$WORK/lockchart.lock" "$WORK/lockchart.tar.gz" "$INSTALL" --step 6 --apply
expect_refusal "tag-mutable[--step 6]" "digest" "$WORK/mutable.lock" "$WORK/mutable.tar.gz" "$INSTALL" --step 6 --apply
expect_refusal "plugin-manquant[--step 7]" "plugin" "$WORK/noplugin.lock" "$WORK/noplugin.tar.gz" "$INSTALL" --step 7 --apply

# Étapes 1-5 seules : le bundle n'est pas requis (aucune écriture OpenChoreo).
if envrun "$WORK/good.lock" "$WORK/absent.tar.gz" "$INSTALL" --step 1 && grep -q 'dry-run' "$WORK/out"; then ok "etape-1-sans-bundle(dry-run)"; else ko "etape-1-sans-bundle(dry-run)"; fi

LIB=". '$REPO/tools/oke/lib.sh'; . '$REPO/tools/oke/security-bundle.sh'"
# Rendu NON durci (template sans le marqueur du faux check-manifest) : refus avant upgrade.
printf 'kind: ClusterRole\nmetadata: {name: origine}\n' > "$FIX/template.yaml"
expect_refusal "rendu-non-durci[--step 7]" "NON durci" "$WORK/good.lock" "$WORK/good.tar.gz" "$INSTALL" --step 7 --apply
printf 'kind: Role\nmetadata: {name: HARDENED}\n' > "$FIX/template.yaml"
# Arguments de contournement refusés.
expect_refusal "argument-post-renderer" "argument refusé" "$WORK/good.lock" "$WORK/good.tar.gz" \
  bash -c "$LIB; APPLY=1; helm_secure dp openchoreo-data-plane \"\$(fetch_chart openchoreo-data-plane $OPENCHOREO_DP_CHART $OPENCHOREO_VERSION $OPENCHOREO_DP_TGZ_SHA256)\" openchoreo-data-plane --post-renderer autre"
expect_refusal "argument-rbac-create" "argument refusé" "$WORK/good.lock" "$WORK/good.tar.gz" \
  bash -c "$LIB; APPLY=1; helm_secure dp openchoreo-data-plane \"\$(fetch_chart openchoreo-data-plane $OPENCHOREO_DP_CHART $OPENCHOREO_VERSION $OPENCHOREO_DP_TGZ_SHA256)\" openchoreo-data-plane --set clusterAgent.rbac.create=true"

# Rollback vers une révision non durcie : refus, aucun `helm rollback`.
printf 'kind: ClusterRole\nmetadata: {name: origine}\n' > "$FIX/rev-1.yaml"
cp "$FIX/template.yaml" "$FIX/rev-2.yaml"
expect_refusal "rollback-non-durci" "NON durcie" "$WORK/good.lock" "$WORK/good.tar.gz" \
  bash -c "$LIB; APPLY=1; rollback_secure openchoreo-data-plane openchoreo-data-plane 1"
if envrun "$WORK/good.lock" "$WORK/good.tar.gz" bash -c "$LIB; APPLY=1; rollback_secure openchoreo-data-plane openchoreo-data-plane 2" \
   && grep -q '^WRITE helm rollback openchoreo-data-plane 2' "$LOGF"; then ok "rollback-durci-accepte"; else ko "rollback-durci-accepte"; fi

# Cas positifs : helm appelé avec --post-renderer et les values imposées.
if envrun "$WORK/good.lock" "$WORK/good.tar.gz" bash -c "$LIB; APPLY=1; helm_secure dp openchoreo-data-plane \"\$(fetch_chart openchoreo-data-plane $OPENCHOREO_DP_CHART $OPENCHOREO_VERSION $OPENCHOREO_DP_TGZ_SHA256)\" openchoreo-data-plane --wait" \
   && grep -E '^WRITE helm upgrade --install openchoreo-data-plane .*--set clusterAgent.rbac.create=false --post-renderer fake-dp' "$LOGF" >/dev/null; then
  ok "positif-dp-post-renderer"; else ko "positif-dp-post-renderer"; fi
if envrun "$WORK/good.lock" "$WORK/good.tar.gz" bash -c "$LIB; APPLY=1; helm_secure cp openchoreo-control-plane \"\$(fetch_chart openchoreo-control-plane $OPENCHOREO_CP_CHART $OPENCHOREO_VERSION $OPENCHOREO_CP_TGZ_SHA256)\" openchoreo-control-plane --wait" \
   && grep -E '^WRITE helm upgrade --install openchoreo-control-plane .*controllerManager.image.tag=v1@sha256:a{64} --post-renderer fake-cp' "$LOGF" >/dev/null; then
  ok "positif-cp-image-digest-post-renderer"; else ko "positif-cp-image-digest-post-renderer"; fi
if envrun "$WORK/good.lock" "$WORK/good.tar.gz" "$INSTALL" --step 7 \
   && grep -q 'security bundle 9.9.9 vérifié' "$WORK/out" && grep -qE '^\[dry-run\] helm upgrade --install openchoreo-data-plane .*--post-renderer fake-dp' "$WORK/out" && no_write; then
  ok "positif-install-dry-run[--step 7]"; else ko "positif-install-dry-run[--step 7]"; fi

# Upgrade du CP (release existante) : seul le ConfigMap CA est en conflit => --force-conflicts, recopie de la CA
# (CP et DP) puis redémarrage de controller-manager et openchoreo-api ; tout autre conflit => refus sans écriture.
printf 'kind: ConfigMap\nmetadata: {name: cluster-gateway-ca}\n---\nkind: Role\nmetadata: {name: HARDENED}\n' > "$FIX/template.yaml"
: > "$FIX/release-exists"; printf 'cluster-gateway-ca\n' > "$FIX/conflicts"
CPUP="$LIB; APPLY=1; helm_secure cp openchoreo-control-plane \"\$(fetch_chart openchoreo-control-plane $OPENCHOREO_CP_CHART $OPENCHOREO_VERSION $OPENCHOREO_CP_TGZ_SHA256)\" openchoreo-control-plane --wait"
if envrun "$WORK/good.lock" "$WORK/good.tar.gz" bash -c "$CPUP" \
   && grep -nE '^WRITE helm upgrade --install openchoreo-control-plane .*--force-conflicts' "$LOGF" >/dev/null \
   && [[ "$(awk '/^WRITE helm upgrade .*--force-conflicts/{print "U"} /^WRITE kubectl apply --server-side --force-conflicts --field-manager=openchoreo-lab -f -$/{print "CA"}
              /^WRITE kubectl .*rollout restart deployment\/controller-manager/{print "RC"} /^WRITE kubectl .*rollout restart deployment\/openchoreo-api/{print "RA"}' "$LOGF" | tr '\n' ' ')" == "U CA CA RC RA " ]]; then
  ok "upgrade-cp-conflit-ca-force-recopie-restart"; else ko "upgrade-cp-conflit-ca-force-recopie-restart"; fi
printf 'cluster-gateway-ca\nHARDENED\n' > "$FIX/conflicts"
expect_refusal "upgrade-cp-autre-conflit" "conflit" "$WORK/good.lock" "$WORK/good.tar.gz" bash -c "$CPUP"
rm -f "$FIX/release-exists"; : > "$FIX/conflicts"

printf '%s PASS=%d FAIL=%d\n' "$(date -u +%FT%TZ)" "$pass" "$fail"
(( fail == 0 ))
