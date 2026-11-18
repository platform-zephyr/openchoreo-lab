#!/usr/bin/env bash
# Banc VAP sur un VRAI API server — k3d JETABLE `k3d-lab-sec-vap` UNIQUEMENT (jamais OKE, jamais k3d-openchoreo).
# Évalue réellement les expressions CEL de platform/policies/*.yaml (VAP-1 lab-cluster-agent-scope, VAP-2
# lab-cell-pod-hardening) et des VAP baseline exportées d'OKE (tests/vap/fixtures/baseline-oke-export.json).
# Identités RÉELLES (ServiceAccounts) liées à cluster-admin : RBAC ne masque jamais la VAP ; tout refus
# observé vient donc de l'admission. Requêtes par impersonation (--as / --as-group).
# Écritures persistées seulement dans les namespaces du banc ; ailleurs `--dry-run=server` (admission
# évaluée, rien n'est écrit). CONNECT (exec/attach/portforward/proxy) : la requête GET sans upgrade passe
# l'admission puis échoue (« Upgrade request required » / pod sans nœud) ; un refus de VAP est un 403
# portant « ValidatingAdmissionPolicy '<nom>' ».
#
# Usage : KUBECONFIG=<kc k3d-lab-sec-vap> tests/vap/run.sh [--label <étiquette>] [--keep]
# Sortie : une ligne PASS/FAIL par test ; preuves tests/vap/evidence/<étiquette>/<id>.txt ; résumé TSV.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL=current KEEP=0
while (($#)); do
  case "$1" in
    --label) LABEL="$2"; shift 2;;
    --keep) KEEP=1; shift;;
    *) echo "argument inconnu : $1" >&2; exit 2;;
  esac
done

# --- Garde : k3d jetable seulement -------------------------------------------------------------------
[[ -n "${KUBECONFIG:-}" && "$KUBECONFIG" != *oke-access* && "$KUBECONFIG" != *:* ]] || { echo "ABANDON : KUBECONFIG" >&2; exit 2; }
ctx="$(kubectl config current-context)"
[[ "$ctx" == k3d-lab-sec-vap ]] || { echo "ABANDON : contexte '$ctx' != k3d-lab-sec-vap" >&2; exit 2; }
server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
[[ "$server" =~ ^https://(0\.0\.0\.0|127\.0\.0\.1):[0-9]+$ && "$server" != *:16443 ]] || { echo "ABANDON : serveur $server" >&2; exit 2; }

EV="$ROOT/tests/vap/evidence/$LABEL"
rm -rf "$EV"; mkdir -p "$EV"
RES="$EV/results.tsv"; : >"$RES"
START="$(date -u +%FT%T)"  # filtre du journal d'audit : événements de CE passage seulement
FAILS=0
source "$ROOT/tests/vap/known-fail.sh"  # classify : B-09 KNOWN_FAIL au niveau du cas (T-457)

AGENT_NS=openchoreo-data-plane AGENT_SA=cluster-agent-dataplane
AGENT=(--as="system:serviceaccount:$AGENT_NS:$AGENT_SA" --as-group=system:serviceaccounts
       --as-group="system:serviceaccounts:$AGENT_NS" --as-group=system:authenticated)
APP=(--as=system:serviceaccount:dp-vap-app:app --as-group=system:serviceaccounts
     --as-group=system:serviceaccounts:dp-vap-app --as-group=system:authenticated)
OTHER=(--as=system:serviceaccount:lab-vap-test:other --as-group=system:serviceaccounts
       --as-group=system:serviceaccounts:lab-vap-test --as-group=system:authenticated)
BUSYBOX="docker.io/rancher/mirrored-library-busybox@sha256:101b4afd76732482eff9b95cae5f94bcf295e521fbec4e01b69c5421f3f3f3e5"
PSQL="ghcr.io/cloudnative-pg/postgresql:17.7-standard-trixie@sha256:e079dae5253fa6ed26fc65fda06d515af764dbec392dd4b46b17ab11eebd8131"
DRY=--dry-run=server

# --- Moteur de test ------------------------------------------------------------------------------------
# t ID ATTENDU POLICE DESCRIPTION -- CMD...
#   ATTENDU : DENY (refus par la VAP POLICE), ALLOW (rc=0), ALLOWC (CONNECT : admission passée, aucune
#   mention de VAP ni de Forbidden ; la requête échoue ensuite pour une raison non liée), WARN (rc=0 et
#   avertissement de la VAP POLICE). Stdin éventuel : manifeste.
t() {
  local id="$1" exp="$2" pol="$3" desc="$4"; shift 5
  local out rc=0 verdict=FAIL
  out="$("$@" 2>&1)" || rc=$?
  case "$exp" in
    DENY)   [[ $rc != 0 ]] && grep -q "ValidatingAdmissionPolicy '$pol'" <<<"$out" && verdict=PASS;;
    ALLOW)  [[ $rc == 0 ]] && ! grep -q "ValidatingAdmissionPolicy" <<<"$out" && verdict=PASS;;
    ALLOWC) ! grep -qiE "ValidatingAdmissionPolicy|forbidden" <<<"$out" && verdict=PASS;;
    WARN)   [[ $rc == 0 ]] && grep -qi "warning.*\(ValidatingAdmissionPolicy '$pol'\|$pol\)" <<<"$out" && verdict=PASS;;
  esac
  verdict="$(classify "$id" "$verdict")"
  [[ $verdict != FAIL ]] || FAILS=$((FAILS + 1))
  [[ $verdict != UNEXPECTED_PASS ]] || echo "ANNONCE : $id passe alors qu'il est KNOWN_FAIL : retirer $id de KNOWN_FAIL_IDS (tests/vap/known-fail.sh)"
  { printf '# %s — %s\n# attendu : %s (%s)\n# date : %s\n$ %s\n' "$id" "$desc" "$exp" "$pol" "$(date -u +%FT%TZ)" "$*"
    printf '%s\n# rc=%s verdict=%s\n' "$out" "$rc" "$verdict"; } >"$EV/$id.txt"
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$verdict" "$exp" "$pol" "$desc" >>"$RES"
  printf '%-8s %-5s %-6s %s\n' "$id" "$verdict" "$exp" "$desc"
}
# Manifeste sur stdin pour t : ti ID ATTENDU POLICE DESC [args kubectl...] <<<"yaml"
ti() { local id="$1" exp="$2" pol="$3" desc="$4"; shift 4; t "$id" "$exp" "$pol" "$desc" -- kubectl "$@" -f -; }

pod() { # NOM [extra spec yaml indenté de 2] [image] [extra conteneur indenté de 4]
  cat <<EOF
apiVersion: v1
kind: Pod
metadata: {name: $1}
spec:
  automountServiceAccountToken: false
  securityContext: {runAsNonRoot: true, runAsUser: 65534, seccompProfile: {type: RuntimeDefault}}
${2:-}
  containers:
  - name: c
    image: ${3:-$BUSYBOX}
    command: [sleep, "3600"]
    securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}
${4:-}
EOF
}
nsyaml() { # NOM ENFORCE CELL(oui|non)
  printf 'apiVersion: v1\nkind: Namespace\nmetadata:\n  name: %s\n  labels:\n' "$1"
  [[ -z "$2" ]] || printf '    pod-security.kubernetes.io/enforce: %s\n    pod-security.kubernetes.io/enforce-version: latest\n' "$2"
  [[ "$3" != oui ]] || printf '    platform.smadja.dev/cell: restricted\n'
  [[ -n "$2" || "$3" == oui ]] || printf '    {}\n'
}

# --- Mise en place (admin) -----------------------------------------------------------------------------
echo "== mise en place ($LABEL) : VAP du dépôt + baseline OKE, identités, namespaces"
kubectl version -o json | jq -r '"serveur " + .serverVersion.gitVersion' | tee "$EV/00-version.txt"
# VAP_POLICY_DIR : autre jeu de politiques (ex. version d'avant correctif extraite par git show) ; défaut = dépôt.
POLICY_DIR="${VAP_POLICY_DIR:-$ROOT/platform/policies}"
echo "politiques : $POLICY_DIR ($(cat "$POLICY_DIR"/*.yaml | shasum -a 256 | cut -c1-12))" | tee "$EV/00-policy-source.txt"
kubectl apply --server-side --force-conflicts --field-manager=lab-vap-test -f "$POLICY_DIR/" >/dev/null
kubectl apply --server-side --field-manager=lab-vap-test -f "$ROOT/tests/vap/fixtures/baseline-oke-export.json" >/dev/null
# CRD factices (inertes) : Cilium (CCNP, absente de k3d) et deux kinds homonymes dans un groupe étranger.
kubectl apply --server-side --field-manager=lab-vap-test -f - >/dev/null <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata: {name: ciliumclusterwidenetworkpolicies.cilium.io, labels: {lab-vap-test: stub}}
spec:
  group: cilium.io
  scope: Cluster
  names: {plural: ciliumclusterwidenetworkpolicies, singular: ciliumclusterwidenetworkpolicy, kind: CiliumClusterwideNetworkPolicy, shortNames: [ccnp]}
  versions: [{name: v2, served: true, storage: true, schema: {openAPIV3Schema: {type: object, x-kubernetes-preserve-unknown-fields: true}}}]
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata: {name: passwords.evil.lab-vap.test, labels: {lab-vap-test: stub}}
spec:
  group: evil.lab-vap.test
  scope: Namespaced
  names: {plural: passwords, singular: password, kind: Password}
  versions: [{name: v1, served: true, storage: true, schema: {openAPIV3Schema: {type: object, x-kubernetes-preserve-unknown-fields: true}}}]
EOF
# CRD ESO (R6) : si absentes, appliquées depuis le RENDU du chart épinglé (versions.env, sha256 vérifié).
if ! kubectl get crd pushsecrets.external-secrets.io >/dev/null 2>&1; then
  # shellcheck source=../../platform/install/versions.env
  . "$ROOT/platform/install/versions.env"
  CH="${VAP_CHART_DIR:-$(mktemp -d)}"
  tgz="$CH/external-secrets-$ESO_VERSION.tgz"
  [[ -f "$tgz" ]] || helm pull "$ESO_CHART" --version "$ESO_VERSION" -d "$CH" >/dev/null 2>&1
  [[ "$(shasum -a 256 "$tgz" | awk '{print $1}')" == "$ESO_TGZ_SHA256" ]] || { echo "sha256 ESO faux" >&2; exit 2; }
  helm template eso "$tgz" --include-crds -f "$ROOT/platform/install/values/external-secrets.yaml" \
    | yq 'select(.kind == "CustomResourceDefinition") | .metadata.labels["lab-vap-test"] = "eso-crd"' \
    | kubectl apply --server-side --field-manager=lab-vap-test -f - >/dev/null
fi
kubectl wait --for=condition=Established crd/pushsecrets.external-secrets.io crd/passwords.generators.external-secrets.io >/dev/null

for ns in openchoreo-data-plane lab-vap-test lab-pg vap-plain auth dp-vap-nopsa dp-vap-nonp dp-vap-allow dp-vap-half; do
  kubectl create ns "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done
nsyaml dp-vap-app restricted oui | kubectl apply -f - >/dev/null
kubectl label ns lab-vap-test lab-pg vap-plain auth dp-vap-nopsa lab-vap-test=bench --overwrite >/dev/null
kubectl -n "$AGENT_NS" create sa "$AGENT_SA" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n dp-vap-app create sa app --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n lab-vap-test create sa other --dry-run=client -o yaml | kubectl apply -f - >/dev/null
for s in "$AGENT_NS:$AGENT_SA" dp-vap-app:app lab-vap-test:other; do
  kubectl create clusterrolebinding "lab-vap-test-${s//:/-}" --clusterrole=cluster-admin --serviceaccount="$s" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
done
# Cibles CONNECT (pods conformes ; sans nœud prêt, ils restent Pending : l'admission CONNECT est la même).
# VAP-3 (T-217) : un Pod de cellule exige la NetworkPolicy default-deny ; dp-vap-app et dp-vap-nopsa la reçoivent.
for ns in dp-vap-app dp-vap-nopsa; do
  kubectl -n "$ns" apply -f - >/dev/null <<EOP
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny}
spec: {podSelector: {}, policyTypes: [Ingress, Egress]}
EOP
done
# Le paramètre de la VAP-3 (NetworkPolicy default-deny) est lu par un informer : juste après sa création, un Pod peut
# encore voir « no params found ». Attente bornée (15 s) avant de conclure ; un refus persistant reste une erreur.
for ns in lab-vap-test dp-vap-app dp-vap-nopsa vap-plain; do
  ok=non
  for _ in $(seq 1 15); do
    if pod target | kubectl -n "$ns" apply -f - >/dev/null 2>&1; then ok=oui; break; fi
    sleep 1
  done
  [[ "$ok" == oui ]] || pod target | kubectl -n "$ns" apply -f - >/dev/null
done
kubectl -n lab-pg create secret generic lab-pg-superuser --from-literal=username=factice --dry-run=client -o yaml \
  | kubectl apply -f - >/dev/null
NODE="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"; NODE="${NODE:-k3d-lab-sec-vap-server-0}"
COREDNS="$(kubectl -n kube-system get pod -l k8s-app=kube-dns -o jsonpath='{.items[0].metadata.name}')"
sleep 2  # propagation des politiques au cache d'admission

echo "== état des politiques (typeChecking, actions, failurePolicy, paramKind)"
kubectl get validatingadmissionpolicies -o json | jq -r '.items[] | [.metadata.name, .spec.failurePolicy,
  (.spec.paramKind // "aucun" | tostring), (.status.typeChecking // {} | tostring)] | @tsv' | tee "$EV/00-policies.tsv"
kubectl get validatingadmissionpolicybindings -o json | jq -r '.items[] | [.metadata.name, (.spec.validationActions | join(",")),
  (.spec.paramRef // "aucun" | tostring)] | @tsv' | tee "$EV/00-bindings.tsv"

echo "== VAP-1 lab-cluster-agent-scope : CONNECT et sous-ressources (identité cluster-agent)"
P=lab-cluster-agent-scope
t V1-C01 DENY $P "agent pods/exec kube-system/coredns (R2)" -- kubectl "${AGENT[@]}" get --raw "/api/v1/namespaces/kube-system/pods/$COREDNS/exec?command=id&stdout=true"
t V1-C02 DENY $P "agent pods/attach lab-vap-test (R2)" -- kubectl "${AGENT[@]}" get --raw "/api/v1/namespaces/lab-vap-test/pods/target/attach?stdout=true"
t V1-C03 DENY $P "agent pods/portforward lab-vap-test (R2)" -- kubectl "${AGENT[@]}" get --raw "/api/v1/namespaces/lab-vap-test/pods/target/portforward?ports=80"
t V1-C04 DENY $P "agent pods/proxy lab-vap-test (R2)" -- kubectl "${AGENT[@]}" get --raw "/api/v1/namespaces/lab-vap-test/pods/target:80/proxy/"
t V1-C05 DENY $P "agent services/proxy kube-system/kube-dns (R2)" -- kubectl "${AGENT[@]}" get --raw "/api/v1/namespaces/kube-system/services/kube-dns:53/proxy/"
t V1-C06 DENY $P "agent nodes/proxy (R1, cluster-scoped)" -- kubectl "${AGENT[@]}" get --raw "/api/v1/nodes/$NODE/proxy/healthz"
t V1-C07 DENY $P "agent serviceaccounts/token dans dp-vap-app (R5)" -- kubectl "${AGENT[@]}" -n dp-vap-app create token app
t V1-C08 DENY $P "agent serviceaccounts/token kube-system (R2/R5)" -- kubectl "${AGENT[@]}" -n kube-system create token default
t V1-C09 ALLOWC $P "agent pods/exec dans dp-vap-app (témoin : admis)" -- kubectl "${AGENT[@]}" get --raw "/api/v1/namespaces/dp-vap-app/pods/target/exec?command=id&stdout=true"
t V1-C10 DENY $P "agent pods/eviction kube-system/coredns (CREATE sous-ressource)" -- kubectl "${AGENT[@]}" create --raw "/api/v1/namespaces/kube-system/pods/$COREDNS/eviction?dryRun=All" -f - <<<"{\"apiVersion\":\"policy/v1\",\"kind\":\"Eviction\",\"metadata\":{\"name\":\"$COREDNS\",\"namespace\":\"kube-system\"}}"
t V1-C11 DENY $P "agent deployments/scale kube-system (UPDATE sous-ressource)" -- kubectl "${AGENT[@]}" -n kube-system scale deployment coredns --replicas=1 $DRY
eph() { printf '{"spec":{"ephemeralContainers":[{"name":"dbg","image":"%s","stdin":true,"tty":true%s}]}}' "$1" "${2:-}"; }
t V1-C12 DENY $P "agent pods/ephemeralcontainers lab-vap-test (R2)" -- kubectl "${AGENT[@]}" -n lab-vap-test patch pod target --subresource=ephemeralcontainers --type=strategic -p "$(eph "$BUSYBOX")" $DRY
t V1-C13 ALLOWC $P "admin pods/exec kube-system (hors matchConditions, témoin)" -- kubectl get --raw "/api/v1/namespaces/kube-system/pods/$COREDNS/exec?command=id&stdout=true"
t V1-C14 ALLOWC $P "SA d'un autre namespace (lab-vap-test:other) pods/exec kube-system : non visé" -- kubectl "${OTHER[@]}" get --raw "/api/v1/namespaces/kube-system/pods/$COREDNS/exec?command=id&stdout=true"

echo "== VAP-1 : Namespaces (R1, R3)"
ti V1-N01 ALLOW $P "agent CREATE dp-vap-ok conforme (restricted, latest, cell)" "${AGENT[@]}" apply <<<"$(nsyaml dp-vap-ok restricted oui)"
ti V1-N02 DENY $P "agent CREATE dp-vap-bad sans labels (R3)" "${AGENT[@]}" create $DRY <<<"$(nsyaml dp-vap-bad '' non)"
ti V1-N03 DENY $P "agent CREATE lab-evil (non dp-*, R1)" "${AGENT[@]}" create $DRY <<<"$(nsyaml lab-evil restricted oui)"
t V1-N04 DENY $P "agent UPDATE dp-vap-ok restricted->baseline (R3, baisse)" -- kubectl "${AGENT[@]}" label ns dp-vap-ok pod-security.kubernetes.io/enforce=baseline --overwrite $DRY
t V1-N05 DENY $P "agent UPDATE dp-vap-ok ->privileged (R3)" -- kubectl "${AGENT[@]}" label ns dp-vap-ok pod-security.kubernetes.io/enforce=privileged --overwrite $DRY
t V1-N06 DENY $P "agent UPDATE dp-vap-ok retrait label cell (R3)" -- kubectl "${AGENT[@]}" label ns dp-vap-ok platform.smadja.dev/cell- $DRY
t V1-N07 ALLOW $P "agent UPDATE dp-vap-ok annotation (oldObject présent, témoin)" -- kubectl "${AGENT[@]}" annotate ns dp-vap-ok lab-vap-test/touch=1 --overwrite
ti V1-N08 ALLOW $P "agent CREATE dp-vap-base en baseline direct (exception appgen ; m1 connu)" "${AGENT[@]}" create $DRY <<<"$(nsyaml dp-vap-base baseline oui)"
t V1-N09 DENY $P "agent DELETE ns lab-vap-test (R1)" -- kubectl "${AGENT[@]}" delete ns lab-vap-test $DRY
t V1-N10 ALLOW $P "agent DELETE ns dp-vap-ok (oldObject seul, témoin)" -- kubectl "${AGENT[@]}" delete ns dp-vap-ok $DRY
t V1-N11 DENY $P "agent label PSA privileged sur kube-system (R1)" -- kubectl "${AGENT[@]}" label ns kube-system pod-security.kubernetes.io/enforce=privileged --overwrite $DRY
ti V1-N12 DENY $P "identité applicative dp-vap-app:app CREATE ns dp-x (R1)" "${APP[@]}" create $DRY <<<"$(nsyaml dp-x restricted oui)"
# namespaces/status : la stratégie de statut des Namespaces conserve-t-elle les labels du corps ? Si oui, la
# sous-ressource est un contournement de R3. Requête PUT réelle (pas de dry-run sur --raw replace).
cur="$(kubectl get ns dp-vap-ok -o json | jq '.metadata.labels["pod-security.kubernetes.io/enforce"]="privileged" | .metadata.labels["platform.smadja.dev/cell"]="x"')"
t V1-N13 DENY $P "agent PUT namespaces/dp-vap-ok/status avec PSA privileged (R3 sur sous-ressource)" -- kubectl "${AGENT[@]}" replace --raw /api/v1/namespaces/dp-vap-ok/status -f - <<<"$cur"
kubectl get ns dp-vap-ok -o jsonpath='{.metadata.labels}' >"$EV/V1-N13-labels-apres.txt"; echo >>"$EV/V1-N13-labels-apres.txt"
cur="$(kubectl get ns dp-vap-ok -o json | jq '.metadata.labels["pod-security.kubernetes.io/enforce"]="baseline" | .metadata.labels["platform.smadja.dev/cell"]="y"')"
t V1-N14 DENY $P "agent PUT namespaces/dp-vap-ok/finalize avec PSA baseline, cell=y" -- kubectl "${AGENT[@]}" replace --raw /api/v1/namespaces/dp-vap-ok/finalize -f - <<<"$cur"
kubectl get ns dp-vap-ok -o jsonpath='{.metadata.labels}' >>"$EV/V1-N13-labels-apres.txt"

echo "== VAP-1 : objets namespacés (R2)"
t V1-W01 DENY $P "agent ConfigMap kube-system (R2)" -- kubectl "${AGENT[@]}" -n kube-system create configmap x $DRY
t V1-W02 ALLOW $P "agent ConfigMap dp-vap-ok (témoin)" -- kubectl "${AGENT[@]}" -n dp-vap-ok create configmap x $DRY
ti V1-W03 ALLOW $P "agent Event core kube-system (exception events)" "${AGENT[@]}" -n kube-system create $DRY <<<'{"apiVersion":"v1","kind":"Event","metadata":{"name":"lab-vap-ev"},"involvedObject":{"kind":"Pod","name":"x","namespace":"kube-system"},"reason":"T","message":"m","type":"Normal"}'
t V1-W04 DENY $P "agent DELETE secret lab-pg-superuser (R2)" -- kubectl "${AGENT[@]}" -n lab-pg delete secret lab-pg-superuser $DRY
t V1-W05 DENY $P "agent ConfigMap lab-pg (R2, kind hors CRT)" -- kubectl "${AGENT[@]}" -n lab-pg create configmap x $DRY
t V1-W06 DENY $P "agent Deployment dans son propre namespace openchoreo-data-plane (R2)" -- kubectl "${AGENT[@]}" -n openchoreo-data-plane create deployment x --image="$BUSYBOX" $DRY
ti V1-W07 DENY $P "agent Password d'un groupe étranger (evil.lab-vap.test) dans lab-pg (R2 par groupe)" "${AGENT[@]}" -n lab-pg create $DRY <<<'{"apiVersion":"evil.lab-vap.test/v1","kind":"Password","metadata":{"name":"x-pg"}}'

echo "== VAP-1 : RBAC et politiques (R1, R4, R5)"
rb() { printf 'apiVersion: rbac.authorization.k8s.io/v1\nkind: RoleBinding\nmetadata: {name: %s}\nroleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: %s}\nsubjects:\n- {kind: ServiceAccount, name: cluster-agent-dataplane, namespace: openchoreo-data-plane}\n%s\n' "$1" "$2" "${3:-}"; }
ti V1-R01 ALLOW $P "agent RoleBinding amorce conforme dans dp-vap-ok (R4 témoin)" "${AGENT[@]}" -n dp-vap-ok create $DRY <<<"$(rb amorce lab-cluster-agent-cell)"
ti V1-R02 DENY $P "agent RoleBinding -> ClusterRole admin (R4)" "${AGENT[@]}" -n dp-vap-ok create $DRY <<<"$(rb esc admin)"
ti V1-R03 DENY $P "agent RoleBinding conforme + 2e sujet default/default (R4)" "${AGENT[@]}" -n dp-vap-ok create $DRY <<<"$(rb two lab-cluster-agent-cell '- {kind: ServiceAccount, name: default, namespace: default}')"
t V1-R04 DENY $P "agent Role dans dp-vap-ok (R5)" -- kubectl "${AGENT[@]}" -n dp-vap-ok create role x --verb=get --resource=pods $DRY
t V1-R05 DENY $P "agent ClusterRole (R1/R5)" -- kubectl "${AGENT[@]}" create clusterrole lab-vap-x --verb=get --resource=pods $DRY
t V1-R06 DENY $P "agent ClusterRoleBinding cluster-admin (R1/R5)" -- kubectl "${AGENT[@]}" create clusterrolebinding lab-vap-x --clusterrole=cluster-admin --user=x $DRY
ti V1-R07 DENY $P "agent CCNP cilium.io (R1/R5)" "${AGENT[@]}" create $DRY <<<'{"apiVersion":"cilium.io/v2","kind":"CiliumClusterwideNetworkPolicy","metadata":{"name":"lab-vap-x"},"spec":{}}'
t V1-R08 ALLOW $P "LIMITE : agent DELETE du binding lab-cluster-agent-scope (VAP/VAPB hors admission ; RBAC seul)" -- kubectl "${AGENT[@]}" delete validatingadmissionpolicybinding lab-cluster-agent-scope $DRY
t V1-R09 DENY $P "agent ValidatingWebhookConfiguration (R1)" -- kubectl "${AGENT[@]}" create $DRY -f - <<<'{"apiVersion":"admissionregistration.k8s.io/v1","kind":"ValidatingWebhookConfiguration","metadata":{"name":"lab-vap-x"},"webhooks":[]}'
ti V1-R10 ALLOW $P "agent TokenReview (cluster-scoped, reviewOnly)" "${AGENT[@]}" create <<<'{"apiVersion":"authentication.k8s.io/v1","kind":"TokenReview","spec":{"token":"factice"}}'

# Isolement : baseline-pod-hardening (Deny partout sauf kube-system) refuse aussi privileged/hostPath/host*.
# Quand deux VAP refusent, l'API ne nomme qu'une politique (ordre non garanti) : pour prouver R6 et VAP-2
# SEULES, le binding baseline est retiré pendant ces deux blocs, puis réappliqué depuis la fixture.
kubectl delete validatingadmissionpolicybinding baseline-pod-hardening >/dev/null
sleep 2
echo "== VAP-1 : lab-pg, gabarit du CRT cnpg-lab-db (R6)"
GEN='{"sourceRef":{"generatorRef":{"apiVersion":"generators.external-secrets.io/v1alpha1","kind":"Password","name":"app-pg"}}}'
EMPTYDIR='{"name":"tmp","emptyDir":{}}'
es() { printf '{"apiVersion":"external-secrets.io/v1","kind":"ExternalSecret","metadata":{"name":"%s"},"spec":{"refreshInterval":"0","target":{"name":"%s"},"dataFrom":[%s]}}' "$1" "$2" "${3:-$GEN}"; }
ps() { printf '{"apiVersion":"external-secrets.io/v1alpha1","kind":"PushSecret","metadata":{"name":"%s"},"spec":{"secretStoreRefs":[{"name":"lab-store","kind":"ClusterSecretStore"}],"selector":{"secret":{"name":"%s"}},"data":[{"match":{"secretKey":"password","remoteRef":{"remoteKey":"%s","property":"password"}}}]}}' "$1" "$2" "$3"; }
job() { # NOM IMAGE AUTOMOUNT SECRETREF VOLUME_JSON
  printf '{"apiVersion":"batch/v1","kind":"Job","metadata":{"name":"%s"},"spec":{"template":{"spec":{"restartPolicy":"OnFailure","automountServiceAccountToken":%s,"securityContext":{"runAsNonRoot":true,"runAsUser":26,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"psql","image":"%s","securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}},"env":[{"name":"PGPASSWORD","valueFrom":{"secretKeyRef":{"name":"%s","key":"password"}}}]}],"volumes":[%s]}}}}' \
    "$1" "$3" "$2" "$4" "${5:-$EMPTYDIR}"; }
ti V1-P01 ALLOW $P "agent ExternalSecret app-pg-role conforme (générateur Password)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(es app-pg-role app-pg-role)"
ti V1-P02 DENY $P "agent ExternalSecret cible lab-pg-superuser (R6)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(es app-pg-role lab-pg-superuser)"
ti V1-P03 DENY $P "agent ExternalSecret app-pg-role qui extrait une clé du coffre (dataFrom.extract, R6)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(es app-pg-role app-pg-role '{"extract":{"key":"autre-app"},"sourceRef":{"storeRef":{"name":"lab-store","kind":"ClusterSecretStore"}}}')"
ti V1-P03b DENY $P "agent ExternalSecret app-pg-role avec target.template qui lit lab-pg-superuser (R6)" "${AGENT[@]}" -n lab-pg create $DRY <<<'{"apiVersion":"external-secrets.io/v1","kind":"ExternalSecret","metadata":{"name":"app-pg-role"},"spec":{"refreshInterval":"0","target":{"name":"app-pg-role","template":{"templateFrom":[{"secret":{"name":"lab-pg-superuser","items":[{"key":"password","templateAs":"Values"}]}}]}},"dataFrom":[{"sourceRef":{"generatorRef":{"apiVersion":"generators.external-secrets.io/v1alpha1","kind":"Password","name":"app-pg"}}}]}}'
ti V1-P04 ALLOW $P "agent PushSecret app-pg-role -> lab-pg-roles-app (témoin, T-456)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(ps app-pg-role app-pg-role lab-pg-roles-app)"
ti V1-P05 DENY $P "agent PushSecret clé distante hors lab-pg-roles- (R6)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(ps app-pg-role app-pg-role autre-app)"
ti V1-P05b DENY $P "agent PushSecret ancienne clé lab-pg-roles/app (séparateur « / », R6, T-456)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(ps app-pg-role app-pg-role lab-pg-roles/app)"
ti V1-P05c DENY $P "agent PushSecret app-pg-role -> clé d'une autre app lab-pg-roles-autre (R6, T-456)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(ps app-pg-role app-pg-role lab-pg-roles-autre)"
ti V1-P05d DENY $P "agent PushSecret préfixe seul lab-pg-roles- (R6, T-456)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(ps app-pg-role app-pg-role lab-pg-roles-)"
ti V1-P05e DENY $P "agent PushSecret clé suffixée lab-pg-roles-app-x (R6, T-456)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(ps app-pg-role app-pg-role lab-pg-roles-app-x)"
ti V1-P06 DENY $P "agent PushSecret qui sélectionne lab-pg-superuser (R6)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(ps app-pg-role lab-pg-superuser lab-pg-roles-app)"
ti V1-P07 DENY $P "agent PushSecret sans spec.data (R6)" "${AGENT[@]}" -n lab-pg create $DRY <<<'{"apiVersion":"external-secrets.io/v1alpha1","kind":"PushSecret","metadata":{"name":"app-pg-role"},"spec":{"secretStoreRefs":[{"name":"lab-store","kind":"ClusterSecretStore"}],"selector":{"secret":{"name":"app-pg-role"}}}}'
ti V1-P08 ALLOW $P "agent Job app-pg-init conforme (témoin)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(job app-pg-init "$PSQL" false lab-pg-superuser)"
ti V1-P09 DENY $P "agent Job automountServiceAccountToken=true (R6)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(job app-pg-init "$PSQL" true lab-pg-superuser)"
ti V1-P10 DENY $P "agent Job image busybox (R6)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(job app-pg-init "$BUSYBOX" false lab-pg-superuser)"
ti V1-P11 DENY $P "agent Job secretKeyRef vers un autre Secret (R6)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(job app-pg-init "$PSQL" false autre-secret)"
ti V1-P12 DENY $P "agent Job volume hostPath (R6)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(job app-pg-init "$PSQL" false lab-pg-superuser '{"name":"h","hostPath":{"path":"/"}}')"
ti V1-P13 DENY $P "agent Job nom hors -pg-init (R6)" "${AGENT[@]}" -n lab-pg create $DRY <<<"$(job evil "$PSQL" false lab-pg-superuser)"
ti V1-P14 ALLOW $P "agent Password (générateur ESO) app-pg (témoin)" "${AGENT[@]}" -n lab-pg create $DRY <<<'{"apiVersion":"generators.external-secrets.io/v1alpha1","kind":"Password","metadata":{"name":"app-pg"},"spec":{"length":32}}'

echo "== VAP-1 : identité applicative (SA de dp-*)"
t V1-A01 DENY $P "app ClusterRole (R1)" -- kubectl "${APP[@]}" create clusterrole lab-vap-y --verb=get --resource=pods $DRY
t V1-A02 DENY $P "app ConfigMap kube-system (hors de sa cellule)" -- kubectl "${APP[@]}" -n kube-system create configmap x $DRY
t V1-A03 DENY $P "app pods/exec kube-system (hors de sa cellule)" -- kubectl "${APP[@]}" get --raw "/api/v1/namespaces/kube-system/pods/$COREDNS/exec?command=id&stdout=true"
t V1-A04 ALLOW $P "app ConfigMap dans sa cellule dp-vap-app (témoin)" -- kubectl "${APP[@]}" -n dp-vap-app create configmap x $DRY

echo "== VAP-2 lab-cell-pod-hardening (admin ; dp-vap-nopsa sans PSA : la VAP seule)"
P=lab-cell-pod-hardening
ti V2-01 DENY $P "pod image sans digest dans dp-*" -n dp-vap-nopsa create $DRY <<<"$(pod p1 '' docker.io/library/busybox:1.36)"
ti V2-02 DENY $P "pod privileged dans dp-*" -n dp-vap-nopsa create $DRY <<<"$(pod p2 '' "$BUSYBOX" '    securityContext: {privileged: true}' | sed '/allowPrivilegeEscalation/d')"
ti V2-03 DENY $P "pod hostNetwork dans dp-*" -n dp-vap-nopsa create $DRY <<<"$(pod p3 '  hostNetwork: true')"
ti V2-04 DENY $P "pod volume hostPath dans dp-*" -n dp-vap-nopsa create $DRY <<<"$(pod p4 '  volumes: [{name: h, hostPath: {path: /}}]')"
ti V2-05 DENY $P "initContainer sans digest dans dp-*" -n dp-vap-nopsa create $DRY <<<"$(pod p5 '  initContainers: [{name: i, image: "docker.io/library/busybox:1.36"}]')"
ti V2-06 ALLOW $P "pod conforme dans dp-* (témoin)" -n dp-vap-nopsa create $DRY <<<"$(pod p6)"
t V2-07 DENY $P "conteneur éphémère sans digest (pods/ephemeralcontainers) dans dp-*" -- kubectl -n dp-vap-nopsa patch pod target --subresource=ephemeralcontainers --type=strategic -p "$(eph docker.io/library/busybox:1.36)" $DRY
t V2-07b DENY $P "conteneur éphémère privileged (digest) dans dp-*" -- kubectl -n dp-vap-nopsa patch pod target --subresource=ephemeralcontainers --type=strategic -p "$(eph "$BUSYBOX" ',"securityContext":{"privileged":true}')" $DRY
ti V2-08 DENY $P "pod image sans digest dans lab-pg" -n lab-pg create $DRY <<<"$(pod p8 '' docker.io/library/busybox:1.36)"
ti V2-09 ALLOW $P "pod image sans digest hors dp-*/lab-pg (lab-vap-test, hors périmètre)" -n lab-vap-test create $DRY <<<"$(pod p9 '' docker.io/library/busybox:1.36)"
ti V2-10 DENY $P "image « digest » invalide (@sha256:court) dans dp-*" -n dp-vap-nopsa create $DRY <<<"$(pod p10 '' docker.io/library/busybox@sha256:abc)"

kubectl apply --server-side --force-conflicts --field-manager=lab-vap-test -f "$ROOT/tests/vap/fixtures/baseline-oke-export.json" >/dev/null
sleep 2
echo "== VAP-3 lab-cell-default-deny (T-217 : Pod refusé sans NetworkPolicy default-deny conforme dans dp-*)"
P=lab-cell-default-deny
np() { # NS SPEC-JSON : NetworkPolicy default-deny du namespace
  kubectl -n "$1" apply -f - >/dev/null <<<"{\"apiVersion\":\"networking.k8s.io/v1\",\"kind\":\"NetworkPolicy\",\"metadata\":{\"name\":\"default-deny\"},\"spec\":$2}"
}
np dp-vap-allow '{"podSelector":{},"policyTypes":["Ingress","Egress"],"egress":[{}]}'
np dp-vap-half '{"podSelector":{},"policyTypes":["Ingress"]}'
ti V3-01 DENY $P "pod dans dp-* sans NetworkPolicy default-deny" -n dp-vap-nonp create $DRY <<<"$(pod n1)"
ti V3-02 ALLOW $P "pod dans dp-* avec default-deny conforme (témoin)" -n dp-vap-nopsa create $DRY <<<"$(pod n2)"
ti V3-03 DENY $P "pod dans dp-* dont default-deny contient une règle egress" -n dp-vap-allow create $DRY <<<"$(pod n3)"
ti V3-04 DENY $P "pod dans dp-* dont default-deny ne couvre que Ingress" -n dp-vap-half create $DRY <<<"$(pod n4)"
ti V3-05 ALLOW $P "pod hors dp-* sans NetworkPolicy (lab-vap-test, hors périmètre)" -n lab-vap-test create $DRY <<<"$(pod n5)"

echo "== baseline OKE (fixture exportée)"
P=baseline-pod-hardening
ti B-01 DENY $P "pod privileged dans vap-plain" -n vap-plain create $DRY <<<"$(pod b1 '' "$BUSYBOX" '    securityContext: {privileged: true}' | sed '/allowPrivilegeEscalation/d')"
ti B-02 DENY $P "pod hostNetwork" -n vap-plain create $DRY <<<"$(pod b2 '  hostNetwork: true')"
ti B-03 DENY $P "pod hostPID" -n vap-plain create $DRY <<<"$(pod b3 '  hostPID: true')"
ti B-04 DENY $P "pod hostIPC" -n vap-plain create $DRY <<<"$(pod b4 '  hostIPC: true')"
ti B-05 DENY $P "pod hostPath" -n vap-plain create $DRY <<<"$(pod b5 '  volumes: [{name: h, hostPath: {path: /}}]')"
ti B-06 ALLOW $P "pod conforme (témoin)" -n vap-plain create $DRY <<<"$(pod b6)"
ti B-07 ALLOW $P "pod privileged dans kube-system (exclu par le binding)" -n kube-system create $DRY <<<"$(pod b7 '' "$BUSYBOX" '    securityContext: {privileged: true}' | sed '/allowPrivilegeEscalation/d')"
t B-08 DENY $P "Deployment au gabarit privileged" -- kubectl -n vap-plain create $DRY -f - <<<'{"apiVersion":"apps/v1","kind":"Deployment","metadata":{"name":"d"},"spec":{"selector":{"matchLabels":{"a":"b"}},"template":{"metadata":{"labels":{"a":"b"}},"spec":{"containers":[{"name":"c","image":"x@sha256:0","securityContext":{"privileged":true}}]}}}}'
t B-09 DENY $P "ÉCART kube-ops : conteneur éphémère privileged (pods/ephemeralcontainers non couvert) hors dp-*" -- kubectl -n vap-plain patch pod target --subresource=ephemeralcontainers --type=strategic -p "$(eph "$BUSYBOX" ',"securityContext":{"privileged":true}')" $DRY
P=baseline-automount-token
ti B-10 DENY $P "auth : pod sans automountServiceAccountToken=false" -n auth create $DRY <<<"$(pod b10 | sed '/automountServiceAccountToken/d')"
ti B-11 ALLOW $P "auth : pod automount=false (témoin)" -n auth create $DRY <<<"$(pod b11)"
ti B-12 ALLOW $P "auth : pod avec annotation baseline.smadja.dev/automount-token=true" -n auth create $DRY <<<"$(pod b12 | sed '/automountServiceAccountToken/d' | sed 's#metadata: {name: b12}#metadata: {name: b12, annotations: {baseline.smadja.dev/automount-token: "true"}}#')"
P=baseline-image-digest
ti B-13 WARN $P "auth : image sans digest ADMISE avec avertissement (binding Warn,Audit)" -n auth create $DRY <<<"$(pod b13 '' docker.io/library/busybox:1.36)"
t B-14 ALLOW $P "vap-plain : image sans digest, binding non applicable (aucun avertissement)" -- bash -c "kubectl -n vap-plain create $DRY -f - <<<'$(pod b14 '' docker.io/library/busybox:1.36)' 2>&1 | grep -v -i warning; exit \${PIPESTATUS[0]}"

echo "== action Audit : annotations dans le journal d'audit de l'API server"
sleep 3
AUD="$EV/audit-extract.jsonl"
DOCKER_CONTEXT="${DOCKER_CONTEXT:-colima-openchoreo}" docker exec k3d-lab-sec-vap-server-0 cat /var/log/lab-audit.log 2>/dev/null \
  | jq -c --arg s "$START" 'select(.requestReceivedTimestamp >= $s) | select(.annotations != null) | select(.annotations | to_entries | any(.key | startswith("validation.policy.admission.k8s.io")))
           | {ts: .requestReceivedTimestamp, user: .user.username, verb, uri: .requestURI, code: .responseStatus.code, annotations}' \
  | tail -n 200 >"$AUD" || true
for pol in lab-cluster-agent-scope lab-cell-pod-hardening lab-cell-default-deny baseline-image-digest; do
  n="$(grep -c -- "$pol" "$AUD" || true)"
  t "AUD-$pol" ALLOW "$pol" "journal d'audit : $n événement(s) annotés validation_failure pour $pol" -- test "$n" -gt 0
done

# --- Nettoyage ---------------------------------------------------------------------------------------
if [[ $KEEP == 0 ]]; then
  kubectl delete ns dp-vap-ok dp-vap-app dp-vap-nopsa dp-vap-nonp dp-vap-allow dp-vap-half lab-vap-test vap-plain auth lab-pg openchoreo-data-plane --wait=false --ignore-not-found >/dev/null
  kubectl delete clusterrolebinding lab-vap-test-openchoreo-data-plane-cluster-agent-dataplane lab-vap-test-dp-vap-app-app \
    lab-vap-test-lab-vap-test-other --ignore-not-found >/dev/null
  kubectl delete crd -l lab-vap-test --ignore-not-found >/dev/null
fi
echo "== bilan $LABEL : $(grep -c $'\tPASS\t' "$RES") PASS, $(grep -c $'\tFAIL\t' "$RES") FAIL, $(grep -c $'\tKNOWN_FAIL\t' "$RES") KNOWN_FAIL, $(grep -c $'\tUNEXPECTED_PASS\t' "$RES") UNEXPECTED_PASS ($RES)"
exit $(( FAILS > 0 ))
