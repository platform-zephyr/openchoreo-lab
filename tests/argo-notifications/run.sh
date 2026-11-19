#!/usr/bin/env bash
# Tests hors cluster d'Argo CD Notifications (T-489). Aucun cluster, aucun secret.
#   1. test_static.py : ConfigMap, ExternalSecret, CiliumNetworkPolicy, values, condition de lab-store, absence de
#      secret en clair (PEM, jetons GitHub/Doppler, IPv4), cas négatifs par mutation (sans réseau) ;
#   2. tools/oke/argo_guard.py sur le dépôt : rc 0 (les objets de notifications/ ne sont synchronisés par aucune
#      Application ; aucune règle élargie) ;
#   3. helm template du chart argo-cd épinglé (versions.env, sha256 vérifié par fetch_chart) avec
#      platform/install/values/argocd.yaml : contrôleur Notifications rendu (1 pod, image par digest, requests,
#      --secret-name=argocd-notifications-secret), ConfigMap et Secret de notifications NON rendus par le chart,
#      tools/oke/psa_check.py restricted ;
#   4. kubeconform -strict sur notifications/*.yaml (schémas ExternalSecret extraits du chart ESO épinglé,
#      CiliumNetworkPolicy par tools/appgen/fetch-ext-schemas.sh) et sur le Deployment rendu ;
#   5. render/ (Go, si `go` est présent) : triggers évalués par expr-lang/expr et gabarits par text/template + sprig
#      aux versions de notifications-engine d'Argo CD v3.5.1, sur des Application factices.
# Les étapes 3 à 5 téléchargent (charts, schémas, modules Go) : cette suite n'est PAS dans tests/registry.yaml (voie
# libre sans réseau ni PyYAML). En CI, le rendu Helm avec ces values passe par render-check (job platform-render) et
# kubeconform-platform couvre notifications/*.yaml. Usage : tests/argo-notifications/run.sh
set -euo pipefail
# shellcheck source=../../tools/oke/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tools/oke/lib.sh"
need helm kubeconform python3 yq
export PYTHONDONTWRITEBYTECODE=1
HERE="$ROOT/tests/argo-notifications"
NOTIF="$INSTALL_DIR/argocd/notifications"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/argo-notif.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
pass=0 fail=0 nt=0
ok() { printf 'PASS %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }

# 1. Statique
if python3 -I -m unittest discover -s "$HERE" -p 'test_*.py' >"$WORK/unit.log" 2>&1; then ok "statique ($(grep -Eo 'Ran [0-9]+ tests' "$WORK/unit.log"))"
else ko "statique"; cat "$WORK/unit.log"; fi

# 2. argo_guard
if python3 -I "$ROOT/tools/oke/argo_guard.py" "$ROOT" >"$WORK/guard.log" 2>&1; then ok "argo_guard rc=0"
else ko "argo_guard"; cat "$WORK/guard.log"; fi

# 3. Rendu Helm
R="$WORK/argocd.yaml"
helm template argocd "$(fetch_chart argo-cd "$ARGOCD_CHART" "$ARGOCD_VERSION" "$ARGOCD_TGZ_SHA256" "$ARGOCD_REPO")" \
  -n lab-argocd -f "$INSTALL_DIR/values/argocd.yaml" > "$R"
D='select(.kind == "Deployment" and .metadata.name == "argocd-notifications-controller")'
yq -e "$D" "$R" > "$WORK/notif-deploy.yaml" 2>/dev/null || true
chk() { # NOM EXPRESSION_YQ_SUR_LE_DEPLOYMENT VALEUR_ATTENDUE
  local got; got="$(yq -N "$2" "$WORK/notif-deploy.yaml" 2>/dev/null || true)"
  if [[ "$got" == "$3" ]]; then ok "rendu : $1"; else ko "rendu : $1 (obtenu '$got', attendu '$3')"; fi
}
chk "Deployment argocd-notifications-controller" '.metadata.name' argocd-notifications-controller
chk "1 réplica" '.spec.replicas // 1' 1
chk "image par digest" '.spec.template.spec.containers[0].image | test("@sha256:[0-9a-f]{64}$")' true
chk "requests cpu" '.spec.template.spec.containers[0].resources.requests.cpu' 10m
chk "requests mémoire" '.spec.template.spec.containers[0].resources.requests.memory' 32Mi
chk "--secret-name" '[.spec.template.spec.containers[0].args[] | select(. == "--secret-name=argocd-notifications-secret")] | length' 1
n="$(yq -N 'select((.kind == "ConfigMap" and .metadata.name == "argocd-notifications-cm") or (.kind == "Secret" and .metadata.name == "argocd-notifications-secret")) | .kind' "$R")"
if [[ -z "$n" ]]; then ok "rendu : ConfigMap et Secret de notifications absents du chart"; else ko "rendu : objets de notifications rendus par le chart : $n"; fi
if python3 -I "$ROOT/tools/oke/psa_check.py" restricted "$R" >"$WORK/psa.log" 2>&1; then ok "psa_check restricted"
else ko "psa_check restricted"; cat "$WORK/psa.log"; fi

# 4. kubeconform
mkdir -p "$WORK/crds" "$WORK/schemas/cilium.io"
helm template x "$(fetch_chart external-secrets "$ESO_CHART" "$ESO_VERSION" "$ESO_TGZ_SHA256")" --include-crds \
  -f "$INSTALL_DIR/values/external-secrets.yaml" > "$WORK/eso.yaml"
python3 -I - "$WORK/eso.yaml" "$WORK/crds" <<'PY'
import pathlib, sys, yaml
out = pathlib.Path(sys.argv[2])
for d in yaml.safe_load_all(open(sys.argv[1], encoding="utf-8")):
    if isinstance(d, dict) and d.get("kind") == "CustomResourceDefinition" and d["spec"]["group"] == "external-secrets.io":
        (out / f"{d['metadata']['name']}.yaml").write_text(yaml.safe_dump(d), encoding="utf-8")
PY
python3 -I "$ROOT/tools/appgen/crd2schema.py" "$WORK/crds" "$WORK/schemas" >/dev/null
"$ROOT/tools/appgen/fetch-ext-schemas.sh" "$WORK/ext" >/dev/null
cp "$WORK/ext/cilium.io/"*.json "$WORK/schemas/cilium.io/"
if kubeconform -strict -summary -schema-location default \
     -schema-location "$WORK/schemas/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
     "$NOTIF"/*.yaml "$WORK/notif-deploy.yaml" >"$WORK/kc.log" 2>&1; then ok "kubeconform -strict ($(tail -1 "$WORK/kc.log"))"
else ko "kubeconform"; cat "$WORK/kc.log"; fi

# 5. Rendu des triggers et gabarits (Go)
if command -v go >/dev/null 2>&1; then
  if (cd "$HERE/render" && GOFLAGS=-mod=readonly go run . "$NOTIF/argocd-notifications-cm.yaml") >"$WORK/go.log" 2>&1; then
    ok "triggers et gabarits rendus ($(grep -c '^PASS' "$WORK/go.log") cas)"
  else ko "triggers et gabarits"; cat "$WORK/go.log"; fi
else
  printf 'NOT_TESTED rendu Go (go absent)\n'; nt=$((nt + 1))
fi

printf 'argo-notifications : %d PASS, %d FAIL, %d NOT_TESTED\n' "$pass" "$fail" "$nt"
[[ "$fail" == 0 ]]
