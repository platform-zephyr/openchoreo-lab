#!/usr/bin/env bash
# Banc de test Phase A — k3d UNIQUEMENT (jamais OKE).
# Applique les objets de platform/ sur le cluster k3d-openchoreo et exécute le plan de refus
# d'APP-CONTRACT §8 réalisable sans OKE. Sortie : une ligne PASS/FAIL/NOT_TESTED par test,
# preuves brutes dans tests/k3d/evidence/<id>.txt (aucune valeur secrète n'y est écrite).
#
# Usage : tests/k3d/run.sh            # installe/actualise puis teste
#         tests/k3d/run.sh --cleanup  # supprime les objets de test t-* (garde lab-pg et platform/)
# Variables : KUBECONFIG (défaut : kubeconfig du k3d du labo), EXPECTED_CONTEXT (k3d-openchoreo).
# Outils : kubectl, helm, yq v4, bash >= 4 ou bash 3.2 (macOS).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIX="$ROOT/tests/k3d/fixtures"
EV="$ROOT/tests/k3d/evidence"
export KUBECONFIG="${KUBECONFIG:-/private/tmp/claude-501/-Users-paul-Desktop-perso/775067df-86e8-413f-97d7-8573a60947a2/scratchpad/openchoreo/kubeconfig}"
EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-k3d-openchoreo}"
AGENT_SA="system:serviceaccount:openchoreo-data-plane:cluster-agent-dataplane"
DIGEST_IMG="ghcr.io/cloudnative-pg/postgresql:17.7-standard-trixie@sha256:e079dae5253fa6ed26fc65fda06d515af764dbec392dd4b46b17ab11eebd8131"
TAG_IMG="traefik/whoami:v1.10.3"

ctx="$(kubectl config current-context)"
if [[ "$ctx" != "$EXPECTED_CONTEXT" ]]; then
  echo "ABANDON : contexte '$ctx' != '$EXPECTED_CONTEXT' (ce banc ne tourne que sur k3d)" >&2
  exit 2
fi

# --------------------------------------------------------------------------- helpers
RESULTS_FILE="$(mktemp)"
HELM_TMP="$(mktemp -d)"
trap 'rm -rf "$HELM_TMP" "$RESULTS_FILE"' EXIT
FAILS=0
mkdir -p "$EV"

say() { printf '\n== %s\n' "$*"; }
record() { # id status message
  printf '%s|%s|%s\n' "$1" "$2" "$3" >> "$RESULTS_FILE"
  if [[ "$2" == FAIL ]]; then FAILS=$((FAILS + 1)); fi
  printf '%-11s %-5s %s\n' "$2" "$1" "$3"
}
# Masque toute URI postgres et tout champ password éventuel avant d'écrire une preuve.
scrub() { sed -E 's#postgres(ql)?://[^ "]*#<uri-masquée>#g; s#([Pp]assword[=:] *)[^ ,"]+#\1<masqué>#g'; }
run_capture() { # id -- cmd... ; stdout+stderr -> OUT, code -> RC, preuve -> evidence/<id>.txt
  local id=$1; shift
  set +e; OUT="$("$@" 2>&1)"; RC=$?; set -e
  { echo "# $(date -u +%FT%TZ) k3d"; echo "\$ $*"; echo "$OUT"; echo "[rc=$RC]"; } | scrub > "$EV/$id.txt"
}
expect_deny() { # id description regex -- cmd...
  local id=$1 desc=$2 re=$3; shift 3
  run_capture "$id" "$@"
  if [[ $RC -ne 0 ]] && grep -qE "$re" <<<"$OUT"; then
    record "$id" PASS "$desc"
  else
    record "$id" FAIL "$desc (rc=$RC : $(head -c 200 <<<"$OUT" | tr '\n' ' '))"
  fi
}
expect_ok() { # id description regex -- cmd...
  local id=$1 desc=$2 re=$3; shift 3
  run_capture "$id" "$@"
  if [[ $RC -eq 0 ]] && grep -qE "$re" <<<"$OUT"; then
    record "$id" PASS "$desc"
  else
    record "$id" FAIL "$desc (rc=$RC : $(head -c 200 <<<"$OUT" | tr '\n' ' '))"
  fi
}
wait_until() { # timeout_s description -- cmd...
  local t=$1 d=$2; shift 2
  local end=$((SECONDS + t))
  until "$@" >/dev/null 2>&1; do
    if (( SECONDS > end )); then echo "  timeout ($t s) : $d" >&2; return 1; fi
    sleep 3
  done
}
cond() { kubectl get "$1" -n default "$2" -o jsonpath="{.status.conditions[?(@.type==\"$3\")].status}" 2>/dev/null; }
cond_msg() { kubectl get "$1" -n default "$2" -o jsonpath="{.status.conditions[?(@.type==\"$3\")].message}"; }
is_true() { [[ "$(cond "$1" "$2" "$3")" == True ]]; }
rb_failed() { [[ "$(cond releasebinding "$1" ReleaseSynced)" == False ]]; }
has_latest() { [[ -n "$(kubectl get "$1" -n default "$2" -o jsonpath='{.status.latestRelease.name}' 2>/dev/null)" ]]; }
cell_ns() { kubectl get prb -n default "$1-development" -o jsonpath='{.status.namespace}'; }
pod_of() { kubectl -n "$1" get pod -l "openchoreo.dev/component=$2" --field-selector=status.phase=Running -o name | head -1; }
tcp() { # ns pod host port -> OPEN|BLOCKED (bash /dev/tcp, 4 s)
  kubectl -n "$1" exec "$2" -- bash -c "timeout 4 bash -c '</dev/tcp/$3/$4' 2>&1 && echo OPEN || echo BLOCKED"
}
expect_tcp() { # id description expected(OPEN|BLOCKED) ns pod host port
  local id=$1 desc=$2 exp=$3; shift 3
  run_capture "$id" tcp "$@"
  if grep -q "^$exp\$" <<<"$OUT"; then record "$id" PASS "$desc"
  else record "$id" FAIL "$desc (attendu $exp : $(tail -1 <<<"$OUT"))"; fi
}
pod_manifest() { # name image mode(restricted|privileged|hostpath|hostnet|none)
  local name=$1 image=$2 mode=$3 podsc="" csc="" extra=""
  case "$mode" in
    restricted) podsc='securityContext: {runAsNonRoot: true, runAsUser: 65532, seccompProfile: {type: RuntimeDefault}}'
                csc='securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}' ;;
    privileged) csc='securityContext: {privileged: true}' ;;
    hostpath)   extra='volumes: [{name: h, hostPath: {path: /etc}}]' ;;
    hostnet)    extra='hostNetwork: true' ;;
    none) ;;
  esac
  cat <<EOF
apiVersion: v1
kind: Pod
metadata: {name: $name}
spec:
  ${podsc}
  ${extra}
  containers:
    - name: c
      image: $image
      command: ["sleep", "1"]
      resources: {requests: {cpu: 10m, memory: 16Mi}, limits: {cpu: 50m, memory: 32Mi}}
      ${csc}
EOF
}
dry_pod() { pod_manifest "$2" "$3" "$4" | kubectl apply -n "$1" --dry-run=server -f -; }
as_agent() { kubectl --as="$AGENT_SA" "$@"; }

# --------------------------------------------------------------------------- cleanup
if [[ "${1:-}" == "--cleanup" ]]; then
  say "Nettoyage des objets de test t-*"
  kubectl delete -f "$FIX/40-negative.yaml" --ignore-not-found --wait=false
  kubectl delete -f "$FIX/20-components.yaml" --ignore-not-found --wait=false
  kubectl delete resourcereleasebinding -n default t-alpha-db-development t-beta-db-development --ignore-not-found
  kubectl delete -f "$FIX/30-resources.yaml" --ignore-not-found
  kubectl delete -f "$FIX/10-projects.yaml" --ignore-not-found
  kubectl delete clustercomponenttype t-service-restricted-probe --ignore-not-found
  kubectl delete namespace dp-t-vapprobe t-vap-control --ignore-not-found
  echo "Bases alpha_development / beta_development conservées dans lab-pg (retainPolicy: Retain)."
  exit 0
fi

# --------------------------------------------------------------------------- 0. installation
say "0. Installation / mise à jour (k3d)"
HELM_CACHE_HOME="$HELM_TMP/c" HELM_CONFIG_HOME="$HELM_TMP/f" HELM_DATA_HOME="$HELM_TMP/d" \
  helm upgrade --install cnpg cloudnative-pg --repo https://cloudnative-pg.github.io/charts \
  --version 0.29.1 --namespace cnpg-system --create-namespace \
  -f "$ROOT/platform/data/cnpg-operator-values.yaml" --wait --timeout 5m >/dev/null
kubectl apply -f "$ROOT/platform/policies/" >/dev/null
kubectl apply -f "$ROOT/platform/cluster-agent/extra-rbac-quota.yaml" >/dev/null
kubectl apply -f "$ROOT/platform/data/lab-pg-namespace.yaml" >/dev/null
kubectl apply -f "$ROOT/platform/data/lab-pg-cluster.yaml" >/dev/null
kubectl apply -f "$ROOT/platform/component-types/" -f "$ROOT/platform/project-types/" \
  -f "$ROOT/platform/resource-types/" >/dev/null
# Copie de test du CCT : nom + allowedTraits seulement (postRenderValidations identiques).
yq '.metadata.name = "t-service-restricted-probe" |
    .spec.allowedTraits += [{"kind":"ClusterTrait","name":"t-break-caps"},
                            {"kind":"ClusterTrait","name":"t-add-crb"},
                            {"kind":"ClusterTrait","name":"t-lb"}]' \
  "$ROOT/platform/component-types/service-restricted.yaml" | kubectl apply -f - >/dev/null
wait_until 300 "lab-pg Ready" kubectl -n lab-pg wait cluster.postgresql.cnpg.io/lab-pg --for=condition=Ready --timeout=5s
echo "  opérateur CNPG + lab-pg Ready ; CCT/CPT/CRT/VAP/RBAC quota appliqués"

say "0b. Cellules, bases, composants"
kubectl apply -f "$FIX/10-projects.yaml" >/dev/null
for p in t-cell-a t-cell-b; do
  # Modifier les paramètres d'un Project crée une ProjectRelease ; le binding garde sa pin (le
  # contrôleur ne la touche plus). En GitOps : PR qui avance la pin. Ici : patch local.
  wait_until 60 "$p latestRelease" has_latest project "$p"
  latest="$(kubectl get project -n default "$p" -o jsonpath='{.status.latestRelease.name}')"
  wait_until 60 "$p pin" bash -c "[[ -n \"\$(kubectl get prb -n default $p-development -o jsonpath='{.spec.projectRelease}')\" ]]"
  pinned="$(kubectl get prb -n default "$p-development" -o jsonpath='{.spec.projectRelease}')"
  if [[ "$pinned" != "$latest" ]]; then
    kubectl patch prb -n default "$p-development" --type merge -p "{\"spec\":{\"projectRelease\":\"$latest\"}}" >/dev/null
    echo "  $p : pin avancée $pinned -> $latest"
  fi
  wait_until 180 "PRB $p Ready" is_true prb "$p-development" Ready
done
NA="$(cell_ns t-cell-a)"; NB="$(cell_ns t-cell-b)"
echo "  cellule A = $NA ; cellule B = $NB"

kubectl apply -f "$FIX/30-resources.yaml" >/dev/null
for r in t-alpha-db t-beta-db; do
  wait_until 120 "$r latestRelease" has_latest resource "$r"
  rel="$(kubectl get resource -n default "$r" -o jsonpath='{.status.latestRelease.name}')"
  # Pin manuel de la ResourceReleaseBinding (APP-CONTRACT §0.6 : 2e PR en GitOps).
  kubectl apply -f - >/dev/null <<EOF
apiVersion: openchoreo.dev/v1alpha1
kind: ResourceReleaseBinding
metadata: {name: $r-development, namespace: default}
spec:
  owner: {projectName: t-cell-a, resourceName: $r}
  environment: development
  resourceRelease: $rel
EOF
  wait_until 300 "RRB $r Ready" is_true resourcereleasebinding "$r-development" Ready
done
echo "  Resources t-alpha-db / t-beta-db Ready"

kubectl apply -f "$FIX/20-components.yaml" >/dev/null
for c in t-whoami-a t-pgclient-a t-whoami-b t-probe-b t-pvc-b; do
  wait_until 300 "RB $c Ready" is_true releasebinding "$c-development" Ready || true
done
kubectl apply -f "$FIX/40-negative.yaml" >/dev/null
for c in t-neg-caps t-neg-crb t-neg-lb t-neg-latest t-neg-public t-neg-pvc; do
  wait_until 180 "RB $c rendu refusé" rb_failed "$c-development" || true
done
PA="$(pod_of "$NA" t-pgclient-a)"; PB="$(pod_of "$NB" t-probe-b)"
echo "  sondes : A=$PA B=$PB"

# --------------------------------------------------------------------------- 1. PSA
say "1. PSA restricted (CPT cell-restricted)"
expect_ok T01a "label PSA enforce=restricted présent malgré namespaceLabels: privileged dans le PRB" \
  '^restricted$' kubectl get ns "$NA" -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/enforce}'
expect_ok T01b "pod conforme (restricted + digest) admis dans la cellule (dry-run serveur)" \
  'created \(server dry run\)' dry_pod "$NA" t-ok "$DIGEST_IMG" restricted
expect_deny T01c "pod digest sans securityContext refusé par PSA" \
  'violates PodSecurity "restricted:latest"' dry_pod "$NA" t-nosc "$DIGEST_IMG" none
expect_deny T01d "pod privileged refusé dans la cellule" \
  'violates PodSecurity|lab-cell-pod-hardening' dry_pod "$NA" t-priv "$DIGEST_IMG" privileged
expect_deny T01e "pod hostPath refusé dans la cellule" \
  'violates PodSecurity|lab-cell-pod-hardening' dry_pod "$NA" t-hostpath "$DIGEST_IMG" hostpath
expect_deny T01f "pod hostNetwork refusé dans la cellule" \
  'violates PodSecurity|lab-cell-pod-hardening' dry_pod "$NA" t-hostnet "$DIGEST_IMG" hostnet
expect_ok T01g "5 pods rendus par service-restricted Running sous PSA restricted (uid 65532, rootfs RO)" \
  '^5$' bash -c "echo \$(( \$(kubectl get pods -n $NA --field-selector=status.phase=Running -o name | wc -l) + \$(kubectl get pods -n $NB --field-selector=status.phase=Running -o name | wc -l) ))"

# --------------------------------------------------------------------------- 2-6. CCT
say "2-6. ClusterComponentType service-restricted (pré/post-rendu)"
expect_ok T02 "trait qui retire capabilities.drop : rendu refusé (postRender)" \
  'securityContext restricted altéré' cond_msg releasebinding t-neg-caps-development ReleaseSynced
expect_ok T03a "trait qui rend une ClusterRoleBinding : rendu refusé (postRender)" \
  'kind interdit : ClusterRoleBinding' cond_msg releasebinding t-neg-crb-development ReleaseSynced
expect_ok T03b "trait hors allowedTraits sur le vrai CCT : Component refusé" \
  'not in the allowed list' cond_msg component t-neg-trait Ready
expect_ok T04a "Workload image :latest sans digest : rendu refusé (preRender)" \
  'image épinglée par digest obligatoire' cond_msg releasebinding t-neg-latest-development ReleaseSynced
expect_ok T05 "endpoint external + publicAuth none : rendu refusé (preRender)" \
  'exposition publique sans authentification interdite' cond_msg releasebinding t-neg-public-development ReleaseSynced
expect_ok T06a "trait qui passe le Service en LoadBalancer : rendu refusé (postRender)" \
  'Service ClusterIP seulement' cond_msg releasebinding t-neg-lb-development ReleaseSynced
expect_ok T06b "PVC RWO avec strategy RollingUpdate : rendu refusé (postRender)" \
  'PVC RWO : strategy Recreate' cond_msg releasebinding t-neg-pvc-development ReleaseSynced
expect_ok T06c "PVC RWO + Recreate (trait upstream) : déployé, PVC Bound" \
  'Bound' kubectl get pvc -n "$NB" -o 'jsonpath={.items[*].status.phase}'
expect_deny T06d "Service LoadBalancer créé à la main dans la cellule : quota" \
  'exceeded quota: cell-quota' kubectl create service loadbalancer t-lb -n "$NA" --tcp=80:8080
expect_deny T06e "2e PVC dans la cellule B (quota pvcs=1) : quota" \
  'exceeded quota: cell-quota' bash -c "kubectl apply -n $NB -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: t-second-pvc}
spec: {accessModes: [ReadWriteOnce], resources: {requests: {storage: 1Gi}}}
EOF"

# --------------------------------------------------------------------------- VAP
say "VAP lab-cell-pod-hardening et lab-cluster-agent-scope"
expect_deny T04b "pod direct image taguée sans digest (securityContext conforme) : VAP" \
  'lab-cell-pod-hardening: image épinglée par digest' dry_pod "$NA" t-tag "$TAG_IMG" restricted
# Namespace dp-* SANS labels PSA : la VAP est la seule barrière ; témoin hors portée t-vap-control.
kubectl create namespace dp-t-vapprobe --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace t-vap-control --dry-run=client -o yaml | kubectl apply -f - >/dev/null
expect_deny T04c "dp-* sans PSA : pod privileged refusé par la VAP seule" \
  'lab-cell-pod-hardening: conteneur privileged interdit' dry_pod dp-t-vapprobe t-priv "$DIGEST_IMG" privileged
expect_deny T04d "dp-* sans PSA : pod hostPath refusé par la VAP seule" \
  'lab-cell-pod-hardening: volume hostPath interdit' dry_pod dp-t-vapprobe t-hp "$DIGEST_IMG" hostpath
expect_deny T04e "dp-* sans PSA : pod hostNetwork refusé par la VAP seule" \
  'lab-cell-pod-hardening: hostNetwork' dry_pod dp-t-vapprobe t-hn "$DIGEST_IMG" hostnet
expect_ok T04f "témoin hors portée (t-vap-control, sans PSA) : même pod privileged admis" \
  'created \(server dry run\)' dry_pod t-vap-control t-priv "$DIGEST_IMG" privileged
expect_deny T03c "cluster-agent : create ClusterRoleBinding refusé (VAP)" \
  'lab-cluster-agent-scope: objet cluster-scoped interdit' \
  as_agent create clusterrolebinding t-evil --clusterrole=cluster-admin --serviceaccount=default:default --dry-run=server
expect_deny T03d "cluster-agent : create ClusterRole refusé (VAP)" \
  'lab-cluster-agent-scope: objet cluster-scoped interdit' \
  as_agent create clusterrole t-evil --verb=get --resource=pods --dry-run=server
expect_deny T03e "cluster-agent : create Namespace hors dp-* refusé (VAP)" \
  'lab-cluster-agent-scope: objet cluster-scoped interdit' as_agent create namespace t-evil-ns --dry-run=server
# R3 de lab-cluster-agent-scope exige les labels PSA + cell sur tout Namespace dp-* écrit par l'agent (T-469).
ns_dp() {
  as_agent create --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: dp-t-allowed
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    platform.smadja.dev/cell: restricted
EOF
}
expect_ok T03f "cluster-agent : create Namespace dp-* (labels PSA + cell) admis" \
  'created \(server dry run\)' ns_dp
expect_deny T03g "cluster-agent : écriture dans kube-system refusée (VAP)" \
  'lab-cluster-agent-scope: le cluster-agent ne peut pas écrire' \
  as_agent create configmap t-evil -n kube-system --dry-run=server
expect_deny T03h "cluster-agent : Secret dans lab-pg refusé (VAP)" \
  'lab-cluster-agent-scope: le cluster-agent ne peut pas écrire secrets' \
  as_agent create secret generic t-evil -n lab-pg --from-literal=k=v --dry-run=server
# R6 : seul le gabarit du CRT cnpg-lab-db passe (nom -pg-init, sans jeton SA, secretKeyRef lab-pg-superuser).
# Témoin repris de tests/vap/run.sh V1-P08 (T-469).
job_crt() {
  printf '{"apiVersion":"batch/v1","kind":"Job","metadata":{"name":"t-ok-pg-init"},"spec":{"template":{"spec":{"restartPolicy":"OnFailure","automountServiceAccountToken":false,"securityContext":{"runAsNonRoot":true,"runAsUser":26,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"psql","image":"%s","securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}},"env":[{"name":"PGPASSWORD","valueFrom":{"secretKeyRef":{"name":"lab-pg-superuser","key":"password"}}}]}]}}}}' "$DIGEST_IMG" \
    | as_agent -n lab-pg create --dry-run=server -f -
}
expect_ok T03i "cluster-agent : Job conforme au gabarit du CRT dans lab-pg admis" \
  'created \(server dry run\)' job_crt
expect_deny T03j "identité applicative (SA default de la cellule) : create ClusterRole refusé" \
  'forbidden|lab-cluster-agent-scope' \
  kubectl --as="system:serviceaccount:$NA:default" create clusterrole t-evil --verb=get --resource=pods --dry-run=server

# --------------------------------------------------------------------------- 7-8. réseau
say "7-8. NetworkPolicy (kube-router k3s)"
expect_ok T07a "NetworkPolicy default-deny + allow-dns-and-cell présentes dans la cellule A" \
  'allow-dns-and-cell.*default-deny|default-deny.*allow-dns-and-cell' \
  bash -c "kubectl get netpol -n $NA -o name | sort | tr '\n' ' '"
expect_tcp T07b "intra-cellule A -> t-whoami-a:8080 ouvert (témoin)" OPEN "$NA" "$PA" t-whoami-a 8080
expect_tcp T07c "cellule A -> whoami de la cellule B : bloqué" BLOCKED "$NA" "$PA" "t-whoami-b.$NB.svc.cluster.local" 8080
expect_ok T07d "DNS depuis la cellule A (egress none) : résolu" \
  '10\.43\.0\.1' kubectl -n "$NA" exec "$PA" -- getent hosts kubernetes.default.svc.cluster.local
expect_tcp T08a "cellule A (egress none) -> 1.1.1.1:443 bloqué" BLOCKED "$NA" "$PA" 1.1.1.1 443
expect_tcp T08b "cellule B (public-internet) -> 1.1.1.1:443 ouvert (témoin)" OPEN "$NB" "$PB" 1.1.1.1 443
expect_tcp T08c "cellule B (public-internet) -> example.com:443 ouvert" OPEN "$NB" "$PB" example.com 443
expect_tcp T08d "cellule B -> 10.43.0.1:443 (apiserver, RFC1918) bloqué" BLOCKED "$NB" "$PB" 10.43.0.1 443
expect_ok T08e "témoin : 10.43.0.1:443 joignable depuis lab-pg (autorisé)" \
  'OPEN' tcp lab-pg pod/lab-pg-1 10.43.0.1 443
record T08f NOT_TESTED "169.254.169.254 : aucun IMDS sur k3d, un refus n'y prouve rien (test 15, OKE seulement)"

# --------------------------------------------------------------------------- 9-12. données
say "9-12. PostgreSQL lab-pg (CRT cnpg-lab-db)"
expect_ok T09a "rôle alpha -> base alpha_development via DATABASE_URL injectée (TLS)" \
  '^alpha_development\|alpha_development\|t$' kubectl -n "$NA" exec "$PA" -- bash -c \
  'psql "$DATABASE_URL" -XAtc "select current_user, current_database(), ssl from pg_stat_ssl where pid = pg_backend_pid()"'
for db in beta_development postgres app; do
  expect_deny "T09-$db" "rôle alpha -> base $db : refus REVOKE CONNECT" \
    "permission denied for database \"$db\"" kubectl -n "$NA" exec "$PA" -- bash -c \
    "u=\"\${DATABASE_URL%%\\?*}\"; psql \"\${u%/*}/$db?sslmode=require\" -XAtc 'select 1'"
done
expect_deny T09b "rôle alpha sans TLS : rejeté par pg_hba" 'no encryption' kubectl -n "$NA" exec "$PA" -- bash -c \
  'psql "${DATABASE_URL/sslmode=require/sslmode=disable}" -XAtc "select 1"'
expect_tcp T10 "cellule B (sans pg-client) -> lab-pg-rw:5432 bloqué" BLOCKED "$NB" "$PB" lab-pg-rw.lab-pg.svc.cluster.local 5432
expect_deny T11a "secret superuser absent de la cellule" 'NotFound' kubectl get secret lab-pg-superuser -n "$NA"
expect_ok T11b "SA de cellule : get secrets -n lab-pg = no" '^no$' \
  bash -c "kubectl auth can-i get secrets -n lab-pg --as=system:serviceaccount:$NA:default || true"
ALPHA_RRN="$(kubectl get resourcereleasebinding -n default t-alpha-db-development -o jsonpath='{.status.conditions[?(@.type=="Synced")].message}' | sed -E 's/.*"(r-[^"]+)".*/\1/')"
expect_ok T12a "mot de passe généré (ESO Password) dans lab-pg : 32 caractères, valeur non affichée" '^32$' \
  bash -c "kubectl get secret -n lab-pg $ALPHA_RRN-pg-role -o jsonpath='{.data.password}' | base64 -d | wc -c | tr -d ' '"
expect_ok T12b "PushSecret vers le store du data plane : Synced" 'Synced' \
  kubectl get pushsecret -n lab-pg "$ALPHA_RRN-pg-role" -o 'jsonpath={.status.conditions[0].reason}'
expect_ok T12e "clé du coffre lab-pg-roles-<nom> (séparateur « - », T-456) dans lab-secrets : clé password (valeur non affichée)" '^password$' \
  bash -c "kubectl get secret -n lab-secrets lab-pg-roles-$ALPHA_RRN -o json | jq -r '.data | keys | join(\" \")'"
expect_ok T12c "secret de la cellule : clés password + uri (valeurs non affichées)" '^password uri$' \
  bash -c "kubectl get secret -n $NA $ALPHA_RRN-pg -o json | jq -r '.data | keys | join(\" \")'"
expect_ok T12d "Job psql idempotent terminé (REVOKE vérifié dans le log)" 'REVOKE CONNECT FROM PUBLIC verified' \
  kubectl logs -n lab-pg "job/$ALPHA_RRN-pg-init"

# --------------------------------------------------------------------------- kgateway RBAC (T-060)
say "13. kgateway : RBAC versionné (rbac.create=false), routage TLS intact"
KGW_SA="system:serviceaccount:openchoreo-control-plane:kgateway"
kgw_no_write() { # aucune écriture de Secret hors create dans openchoreo-control-plane
  local v n out=""
  for v in create update patch delete deletecollection; do
    for n in kube-system default openchoreo-data-plane lab-pg; do
      out+="$v -n $n: $(kubectl auth can-i "$v" secrets -n "$n" --as="$KGW_SA" 2>&1 || true)"$'\n'
    done
  done
  for v in update patch delete deletecollection; do
    out+="$v -n openchoreo-control-plane: $(kubectl auth can-i "$v" secrets -n openchoreo-control-plane --as="$KGW_SA" 2>&1 || true)"$'\n'
  done
  printf '%s' "$out"
  ! grep -q ': yes' <<<"$out" && echo "AUCUNE-ECRITURE"
}
expect_ok T13a "ClusterRole du chart kgateway absent (rbac.create=false)" 'ABSENT' \
  bash -c 'kubectl get clusterrole kgateway-openchoreo-control-plane >/dev/null 2>&1 || echo ABSENT'
expect_ok T13b "SA kgateway : aucune écriture de Secret (4 namespaces + update/patch/delete dans le sien)" 'AUCUNE-ECRITURE' kgw_no_write
expect_ok T13c "SA kgateway : create secrets -n openchoreo-control-plane (bootstrap OAuth2) = yes" '^yes$' \
  kubectl auth can-i create secrets -n openchoreo-control-plane --as="$KGW_SA"
expect_ok T13d "listener HTTPS de gateway-default : ResolvedRefs=True (Secret TLS lu par l'informer)" '^true$' \
  bash -c "kubectl -n openchoreo-data-plane get gateway gateway-default -o json | jq -e '[.spec.listeners[] | select(.protocol == \"HTTPS\") | .name] as \$h | (\$h | length) > 0 and ([.status.listeners[] | select(.name as \$n | \$h | index(\$n)) | .conditions[] | select(.type == \"ResolvedRefs\" and .status == \"True\")] | length) == (\$h | length)'"
expect_ok T13e "HTTPListenerPolicy d'OpenChoreo 1.3.3 présente (CRD gardée par kgateway v2.4.8)" 'httplistenerpolicy' \
  kubectl get httplistenerpolicies.gateway.kgateway.dev -A -o name
expect_ok T13f "journal du contrôleur kgateway : aucun refus RBAC (forbidden)" '^0$' \
  bash -c 'kubectl -n openchoreo-control-plane logs deployment/kgateway --tail=-1 | grep -ci forbidden || true'
expect_ok T13g "Secret oauth2-hmac-secret créé par le bootstrap (Role create)" 'oauth2-hmac-secret' \
  kubectl -n openchoreo-control-plane get secret oauth2-hmac-secret -o name

# --------------------------------------------------------------------------- empreinte
say "Empreinte (kubectl top, k3d, 1 nœud)"
run_capture FOOTPRINT bash -c '
kubectl top pods -A --no-headers | awk "{c[\$1]+=\$3; m[\$1]+=\$4} END {for (n in c) printf \"%-40s %6dm %6dMi\n\", n, c[n], m[n]}" | sort
echo "-- requests déclarées (cpu m / mem Mi) par namespace"
kubectl get pods -A -o json | jq -r ".items[] | select(.status.phase==\"Running\") | .metadata.namespace as \$n | .spec.containers[] | [\$n, (.resources.requests.cpu // \"0\"), (.resources.requests.memory // \"0\")] | @tsv" \
 | awk -F"\t" "function cpu(v){ if (v ~ /m\$/) return v+0; return v*1000 } function mem(v){ if (v ~ /Mi\$/) return v+0; if (v ~ /Gi\$/) return v*1024; if (v ~ /Ki\$/) return v/1024; if (v ~ /M\$/) return v+0; return v/1048576 } {c[\$1]+=cpu(\$2); m[\$1]+=mem(\$3)} END {for (n in c) printf \"%-40s %6dm %6dMi\n\", n, c[n], m[n]}" | sort
kubectl top nodes'
echo "$OUT"
record FOOTPRINT INFO "mesure écrite dans tests/k3d/evidence/FOOTPRINT.txt"

# --------------------------------------------------------------------------- bilan
say "Bilan (k3d, OpenChoreo $(kubectl get deploy -n openchoreo-control-plane controller-manager -o jsonpath='{.spec.template.spec.containers[0].image}' | sed 's/.*://'))"
pass=$(grep -c '|PASS|' "$RESULTS_FILE" || true); nt=$(grep -c '|NOT_TESTED|' "$RESULTS_FILE" || true)
echo "PASS=$pass FAIL=$FAILS NOT_TESTED=$nt"
cp "$RESULTS_FILE" "$EV/results.psv"
[[ $FAILS -eq 0 ]]
