#!/usr/bin/env bash
# Banc de DÉSINSTALLATION — k3d JETABLE `k3d-lab-sec-vap` UNIQUEMENT (jamais OKE, jamais k3d-openchoreo).
# 1. Garde : tools/oke/lib.sh n'accepte ce k3d qu'en MODE TEST explicite (LAB_TEST_CLUSTER=k3d-lab-sec-vap).
# 2. Installe les charts EXACTS épinglés (versions.env, sha256 vérifiés par fetch_chart) avec les values du
#    labo : install.sh --step 1..2 (mode test), puis cert-manager, ESO, kgateway-crds, kgateway, Argo CD
#    (lab-argocd) ; avec nœud prêt : install.sh --from 3 --to 5 ; sans nœud : `helm upgrade --install`
#    identique sans --wait (et --no-hooks pour Argo CD, dont le hook pré-installation est un Job).
# 3. Témoins : PVC factice hors périmètre, CR vivantes hors essai (Issuer, TrafficPolicy, GatewayClass,
#    ExternalSecret avec finalizer), Applications Argo (dont une avec resources-finalizer).
# 4. Prouve : effets de helm uninstall (CRD gardées/supprimées), gardes d'uninstall.sh (CRD utilisées, Argo,
#    release sans keep, --migrate-cnpg-system), invariance PVC/PV, rollback étape par étape.
# Usage : KUBECONFIG=<kc> UNINSTALL_STATE=<dir hors dépôt> tests/uninstall-k3d/run.sh [--charts <dir de .tgz>]
# Preuves : tests/uninstall-k3d/evidence/<id>.txt ; résumé evidence/results.tsv.
set -euo pipefail
# shellcheck disable=SC2016,SC2329  # verdicts évalués par v() (eval), fonctions appelées dans ces chaînes

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHARTS=""
while (($#)); do case "$1" in --charts) CHARTS="$2"; shift 2;; *) echo "argument inconnu : $1" >&2; exit 2;; esac; done

[[ -n "${KUBECONFIG:-}" && "$KUBECONFIG" != *oke-access* && "$KUBECONFIG" != *:* ]] || { echo "ABANDON : KUBECONFIG" >&2; exit 2; }
[[ "$(kubectl config current-context)" == k3d-lab-sec-vap ]] || { echo "ABANDON : contexte != k3d-lab-sec-vap" >&2; exit 2; }
[[ -n "${UNINSTALL_STATE:-}" && "$UNINSTALL_STATE" != "$HOME/.cache/openchoreo-lab-phaseb"* && "$UNINSTALL_STATE" != "$ROOT"* ]] \
  || { echo "ABANDON : UNINSTALL_STATE (répertoire dédié hors dépôt et hors état réel) requis" >&2; exit 2; }

export LAB_TEST_CLUSTER=k3d-lab-sec-vap OKE_PHASEB_STATE="$UNINSTALL_STATE"
mkdir -p "$UNINSTALL_STATE/charts"
[[ -z "$CHARTS" ]] || cp -n "$CHARTS"/*.tgz "$UNINSTALL_STATE/charts/" 2>/dev/null || true
# Noms attendus par fetch_chart : <clé>-<version>.tgz.
UN="$ROOT/tools/oke/uninstall.sh" IN="$ROOT/tools/oke/install.sh"
EV="$ROOT/tests/uninstall-k3d/evidence"; mkdir -p "$EV"
RES="$EV/results.tsv"; : >"$RES"
FAILS=0
V="$ROOT/platform/install/values"
# shellcheck source=../../platform/install/versions.env
. "$ROOT/platform/install/versions.env"
export HELM_CACHE_HOME="$UNINSTALL_STATE/helm/cache" HELM_CONFIG_HOME="$UNINSTALL_STATE/helm/config" HELM_DATA_HOME="$UNINSTALL_STATE/helm/data"

# r ID ATTENDU(OK|KO) DESCRIPTION -- CMD... : exécute, consigne commande/sortie/rc. Le verdict est posé par v.
LAST_OUT="" LAST_RC=0
r() {
  local id="$1" desc="$2"; shift 3
  LAST_RC=0; LAST_OUT="$("$@" 2>&1)" || LAST_RC=$?
  { printf '# %s — %s\n# date : %s\n$ %s\n' "$id" "$desc" "$(date -u +%FT%TZ)" "$*"; printf '%s\n# rc=%s\n' "$LAST_OUT" "$LAST_RC"; } >>"$EV/$id.txt"
}
# v ID VERDICT_BOOL DESCRIPTION : consigne PASS/FAIL (VERDICT_BOOL = commande évaluée).
v() {
  local id="$1" desc="$3" verdict=FAIL
  if eval "$2"; then verdict=PASS; else FAILS=$((FAILS + 1)); fi
  printf '# verdict : %s (%s)\n' "$verdict" "$2" >>"$EV/$id.txt"
  printf '%s\t%s\t%s\n' "$id" "$verdict" "$desc" >>"$RES"; printf '%-10s %-5s %s\n' "$id" "$verdict" "$desc"
}
note() { printf '%s\n' "$*" >>"$EV/$1.txt"; }
crd_has() { kubectl get crd "$1" >/dev/null 2>&1; }
ns_has() { kubectl get ns "$1" >/dev/null 2>&1; }
snap_storage() { # empreinte PVC (uid) + PV : doit rester identique
  { kubectl get pvc -A -o json | jq -r '.items[] | "pvc \(.metadata.namespace)/\(.metadata.name) \(.metadata.uid)"'
    kubectl get pv -o json | jq -r '.items[] | "pv \(.metadata.name) \(.metadata.uid)"'; } | sort
}
rm -f "$EV"/[A-Z0-9]*.txt

NODE_READY=0
if kubectl get nodes -o json | jq -e '.items[0].status.conditions[] | select(.type=="Ready" and .status=="True")' >/dev/null 2>&1; then NODE_READY=1; fi
{ kubectl version -o json | jq -r '"serveur " + .serverVersion.gitVersion'; echo "nœud prêt : $NODE_READY"
  kubectl get nodes -o json | jq -r '.items[] | "nœud \(.metadata.name) providerID=\(.spec.providerID) labels=\(.metadata.labels|tostring)"'; } | tee "$EV/00-env.txt"

echo "== G : garde de contexte (lib.sh, mode test)"
SPK="$UNINSTALL_STATE/kc"; mkdir -p "$SPK"
kubectl config view --raw --minify >"$SPK/ok"; chmod 600 "$SPK/ok"
sed 's/k3d-lab-sec-vap/k3d-autre/g' "$SPK/ok" >"$SPK/autre"; chmod 600 "$SPK/autre"
sed -E 's#server: https://[^ ]+#server: https://127.0.0.1:16443#' "$SPK/ok" >"$SPK/port-oke"; chmod 600 "$SPK/port-oke"
mkdir -p "$SPK/oke-access"; cp "$SPK/ok" "$SPK/oke-access/kubeconfig"
r G01 "LAB_TEST_CLUSTER=k3d-openchoreo refusé" -- env LAB_TEST_CLUSTER=k3d-openchoreo "$UN" --step 2
v G01 '[[ $LAST_RC != 0 ]] && grep -q "refusé : seul" <<<"$LAST_OUT"' "LAB_TEST_CLUSTER autre que k3d-lab-sec-vap : refus"
r G02 "contexte renommé" -- env KUBECONFIG="$SPK/autre" "$UN" --step 2
v G02 '[[ $LAST_RC != 0 ]] && grep -q "contexte" <<<"$LAST_OUT"' "contexte != k3d-lab-sec-vap : refus"
r G03 "serveur 127.0.0.1:16443 (port OKE)" -- env KUBECONFIG="$SPK/port-oke" "$UN" --step 2
v G03 '[[ $LAST_RC != 0 ]] && grep -q "serveur API inattendu" <<<"$LAST_OUT"' "serveur sur le port du tunnel OKE : refus"
r G04 "OKE_PHASEB_STATE absent" -- env -u OKE_PHASEB_STATE "$UN" --step 2
v G04 '[[ $LAST_RC != 0 ]] && grep -q "OKE_PHASEB_STATE dédié" <<<"$LAST_OUT"' "état réel de l'essai OKE : refus"
r G05 "chemin oke-access" -- env KUBECONFIG="$SPK/oke-access/kubeconfig" "$UN" --step 2
v G05 '[[ $LAST_RC != 0 ]] && grep -q "kubeconfig OKE" <<<"$LAST_OUT"' "kubeconfig sous un chemin oke-access : refus"
r G06 "sans LAB_TEST_CLUSTER : garde OKE inchangée" -- env -u LAB_TEST_CLUSTER "$UN" --step 2
v G06 '[[ $LAST_RC != 0 ]] && grep -q "ne pointe pas sur le kubeconfig temporaire" <<<"$LAST_OUT"' "sans mode test, la garde OKE refuse le k3d"
r G07 "mode test accepté" -- "$UN" --step 2
v G07 '[[ $LAST_RC == 0 ]] && grep -q "MODE TEST k3d" <<<"$LAST_OUT"' "mode test sur k3d-lab-sec-vap : accepté (dry-run)"

echo "== I : installation (charts épinglés, values du labo)"
kubectl apply --server-side --field-manager=lab-uninstall-test -f - >/dev/null <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata: {name: ciliumnetworkpolicies.cilium.io, labels: {lab-uninstall-test: stub}}
spec:
  group: cilium.io
  scope: Namespaced
  names: {plural: ciliumnetworkpolicies, singular: ciliumnetworkpolicy, kind: CiliumNetworkPolicy, shortNames: [cnp]}
  versions: [{name: v2, served: true, storage: true, schema: {openAPIV3Schema: {type: object, x-kubernetes-preserve-unknown-fields: true}}}]
EOF
kubectl apply --server-side --force-conflicts --field-manager=lab-uninstall-test -f "$ROOT/tests/vap/fixtures/baseline-oke-export.json" >/dev/null
kubectl wait --for=condition=Established crd/ciliumnetworkpolicies.cilium.io >/dev/null
# crds-before.txt : inventaire d'avant essai (preflight.sh est propre à OKE : Cilium, CCNP kube-ops).
kubectl get crd -o name >"$UNINSTALL_STATE/crds-before.txt"
cp "$UNINSTALL_STATE/crds-before.txt" "$EV/00-crds-before.txt"
install_all() { # SUFFIXE d'identifiant : installe les étapes 1-5 et Argo CD
  r "I01$1" "install.sh --from 1 --to 2 --apply (mode test)" -- "$IN" --from 1 --to 2 --apply
  v "I01$1" '[[ $LAST_RC == 0 ]] && crd_has gateways.gateway.networking.k8s.io && ns_has lab-cnpg' "étapes 1-2 (namespaces, quotas, NP, Gateway API) appliquées"
  if [[ $NODE_READY == 1 ]]; then
    r "I02$1" "install.sh --from 3 --to 5 --apply (mode test, budget_gate compris)" -- "$IN" --from 3 --to 5 --apply
  else
    cm="$UNINSTALL_STATE/charts/cert-manager-$CERT_MANAGER_VERSION.tgz" eso="$UNINSTALL_STATE/charts/external-secrets-$ESO_VERSION.tgz"
    kc="$UNINSTALL_STATE/charts/kgateway-crds-$KGATEWAY_VERSION.tgz" kg="$UNINSTALL_STATE/charts/kgateway-$KGATEWAY_VERSION.tgz"
    for p in "$cm:$CERT_MANAGER_TGZ_SHA256" "$eso:$ESO_TGZ_SHA256" "$kc:$KGATEWAY_CRDS_TGZ_SHA256" "$kg:$KGATEWAY_TGZ_SHA256"; do
      [[ "$(shasum -a 256 "${p%%:*}" | awk '{print $1}')" == "${p##*:}" ]] || { echo "sha256 ${p%%:*}" >&2; exit 2; }
    done
    r "I02$1" "SANS NŒUD : helm upgrade --install des étapes 3-5 (mêmes tgz, values, namespaces ; sans --wait)" -- bash -c "
      helm upgrade --install cert-manager '$cm' -n openchoreo-cert-manager -f '$V/cert-manager.yaml' &&
      helm upgrade --install external-secrets '$eso' -n openchoreo-external-secrets -f '$V/external-secrets.yaml' &&
      kubectl apply --server-side --field-manager=openchoreo-lab -f '$ROOT/platform/install/manifests/20-eso-lab-store.yaml' &&
      helm upgrade --install kgateway-crds '$kc' -n openchoreo-control-plane &&
      helm upgrade --install kgateway '$kg' -n openchoreo-control-plane -f '$V/kgateway.yaml'"
  fi
  v "I02$1" '[[ $LAST_RC == 0 ]] && crd_has certificates.cert-manager.io && crd_has externalsecrets.external-secrets.io && crd_has trafficpolicies.gateway.kgateway.dev' "étapes 3-5 installées (cert-manager, ESO, kgateway-crds, kgateway)"
  argo="$UNINSTALL_STATE/charts/argo-cd-$ARGOCD_VERSION.tgz"
  [[ "$(shasum -a 256 "$argo" | awk '{print $1}')" == "$ARGOCD_TGZ_SHA256" ]] || { echo "sha256 argo" >&2; exit 2; }
  AFLAGS=(--wait --timeout 10m); [[ $NODE_READY == 1 ]] || AFLAGS=(--no-hooks)
  r "I03$1" "Argo CD épinglé dans lab-argocd (${AFLAGS[*]})" -- helm upgrade --install argocd "$argo" -n lab-argocd -f "$V/argocd.yaml" "${AFLAGS[@]}"
  v "I03$1" '[[ $LAST_RC == 0 ]] && crd_has applications.argoproj.io' "Argo CD 10.3.3 installé (lab-argocd)"
}
install_all ""

echo "== T : témoins (PVC hors périmètre, CR hors essai, Applications)"
kubectl create ns lab-pvc-witness --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create ns ext-user --dry-run=client -o yaml | kubectl apply -f - >/dev/null
# Sans nœud, le webhook cert-manager n'a pas de pod : on use du sélecteur prévu par cert-manager
# (namespaceSelector de sa ValidatingWebhookConfiguration) pour ext-user SEULEMENT. Aucune garde du labo touchée.
[[ $NODE_READY == 1 ]] || kubectl label ns ext-user cert-manager.io/disable-validation=true --overwrite >/dev/null
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: witness, namespace: lab-pvc-witness}
spec: {accessModes: [ReadWriteOnce], resources: {requests: {storage: 1Mi}}}
EOF
kubectl apply --server-side --field-manager=lab-uninstall-test -f - >/dev/null <<'EOF'
apiVersion: cert-manager.io/v1
kind: Issuer
metadata: {name: ext-selfsigned, namespace: ext-user}
spec: {selfSigned: {}}
---
apiVersion: gateway.kgateway.dev/v1alpha1
kind: TrafficPolicy
metadata: {name: ext-tp, namespace: ext-user}
spec: {}
---
apiVersion: gateway.kgateway.dev/v1alpha1
kind: GatewayParameters
metadata: {name: lab-gwp, namespace: openchoreo-control-plane}
spec: {kube: {}}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: {name: ext-es, namespace: ext-user, finalizers: [lab-uninstall-test/hold]}
spec: {secretStoreRef: {name: lab-store, kind: ClusterSecretStore}, target: {name: ext-es}, data: [{secretKey: k, remoteRef: {key: x}}]}
---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata: {name: lab-test, namespace: lab-argocd}
spec:
  sourceRepos: ["https://github.com/argoproj/argocd-example-apps.git"]
  destinations: [{server: "https://kubernetes.default.svc", namespace: lab-argo-target}]
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: lab-platform, namespace: lab-argocd}
spec:
  project: lab-test
  source: {repoURL: "https://github.com/argoproj/argocd-example-apps.git", targetRevision: HEAD, path: guestbook}
  destination: {server: "https://kubernetes.default.svc", namespace: lab-argo-target}
  syncPolicy: {automated: {selfHeal: true, prune: true}, syncOptions: [CreateNamespace=true]}
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: lab-probe-finalizer, namespace: lab-argocd, finalizers: [resources-finalizer.argocd.argoproj.io]}
spec:
  project: lab-test
  source: {repoURL: "https://github.com/argoproj/argocd-example-apps.git", targetRevision: HEAD, path: guestbook}
  destination: {server: "https://kubernetes.default.svc", namespace: lab-argo-target}
EOF
STORE0="$(snap_storage)"; printf '%s\n' "$STORE0" >"$EV/00-storage-before.txt"

echo "== H : effets helm observés sur les objets VIVANTS"
for spec in "cert-manager:cert-manager.io" "external-secrets:external-secrets.io" "kgateway-crds:gateway.kgateway.dev" "argocd:argoproj.io"; do
  rel="${spec%%:*}" grp="${spec##*:}"
  r "H-$rel" "CRD vivantes du groupe *$grp : annotation keep et release propriétaire" -- bash -c \
    "kubectl get crd -o json | jq -r '.items[] | select(.spec.group | endswith(\"$grp\")) | [.metadata.name, (.metadata.annotations[\"helm.sh/resource-policy\"] // \"-\"), (.metadata.annotations[\"meta.helm.sh/release-name\"] // \"-\")] | @tsv'"
  case "$rel" in kgateway-crds) want='! grep -q keep <<<"$LAST_OUT"';; *) want='! grep -q "$(printf "\t-\t")" <<<"$LAST_OUT"';; esac
  v "H-$rel" "[[ -n \$LAST_OUT ]] && $want" "CRD vivantes $grp : keep $( [[ $rel == kgateway-crds ]] && echo ABSENT || echo présent ) sur l'objet"
done

echo "== A : refus quand Argo CD gère des objets"
for s in 1 7 9 10; do
  r "A-$s" "--step $s --apply avec Applications présentes" -- "$UN" --step "$s" --apply
  v "A-$s" '[[ $LAST_RC != 0 ]] && grep -q "Application Argo présente" <<<"$LAST_OUT"' "uninstall --step $s refusé (Application Argo dans lab-argocd)"
done
v A-ns 'ns_has lab-cnpg && ns_has openchoreo-cert-manager && ns_has lab-argocd && kubectl get validatingadmissionpolicy baseline-pod-hardening >/dev/null' "aucun namespace supprimé par les refus"

echo "== K : release_keeps_crds (release ESO sans keep)"
r K01 "helm upgrade ESO sans annotation keep" -- helm upgrade external-secrets "$UNINSTALL_STATE/charts/external-secrets-$ESO_VERSION.tgz" -n openchoreo-external-secrets -f "$V/external-secrets.yaml" --set-json 'crds.annotations={}'
r K01 "uninstall --step 4 --apply" -- "$UN" --step 4 --apply
v K01 '[[ $LAST_RC != 0 ]] && grep -q "CRD sans helm.sh/resource-policy=keep" <<<"$LAST_OUT" && helm -n openchoreo-external-secrets status external-secrets >/dev/null' "release ESO sans keep : uninstall refusé, release intacte"
r K02 "remise des values du labo (keep)" -- helm upgrade external-secrets "$UNINSTALL_STATE/charts/external-secrets-$ESO_VERSION.tgz" -n openchoreo-external-secrets -f "$V/external-secrets.yaml"
v K02 '[[ $LAST_RC == 0 ]] && [[ "$(kubectl get crd externalsecrets.external-secrets.io -o jsonpath="{.metadata.annotations.helm\.sh/resource-policy}")" == keep ]]' "keep de retour sur l'objet vivant après upgrade"

echo "== M : --migrate-cnpg-system"
mk_cnpg() { kubectl create ns cnpg-system --dry-run=client -o yaml | kubectl apply -f - >/dev/null; [[ -z "$1" ]] || kubectl label ns cnpg-system app.kubernetes.io/part-of=openchoreo-lab --overwrite >/dev/null; }
# (pas de `kubectl … | grep -q` sous pipefail : grep -q ferme le tube, kubectl reçoit SIGPIPE, faux négatif)
wait_trial_ns_gone() { local _i nsl; for _i in $(seq 1 100); do nsl="$(kubectl get ns -o name)"; grep -qE '/(lab-cnpg|lab-argocd|lab-secrets|lab-pg|openchoreo-)' <<<"$nsl" || return 0; sleep 3; done; return 1; }
wait_gone() { local _i; for _i in $(seq 1 30); do ns_has "$1" || return 0; sleep 2; done; return 1; }
mk_cnpg label
kubectl -n cnpg-system create configmap etranger --dry-run=client -o yaml | kubectl apply -f - >/dev/null
r M01 "cnpg-system étiqueté avec un ConfigMap étranger" -- "$UN" --migrate-cnpg-system --apply
v M01 '[[ $LAST_RC != 0 ]] && ns_has cnpg-system' "ConfigMap étranger : refus, namespace conservé"
kubectl -n cnpg-system label configmap etranger app.kubernetes.io/part-of=openchoreo-lab >/dev/null
r M02 "cnpg-system avec un ConfigMap ÉTIQUETÉ part-of" -- "$UN" --migrate-cnpg-system --apply
v M02 '[[ $LAST_RC != 0 ]] && ns_has cnpg-system' "objet étiqueté mais d'un kind que l'étape 1 n'y pose pas : refus"
kubectl -n cnpg-system delete configmap etranger >/dev/null
kubectl -n cnpg-system apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: p, labels: {app.kubernetes.io/part-of: openchoreo-lab}}
spec: {accessModes: [ReadWriteOnce], resources: {requests: {storage: 1Mi}}}
EOF
r M03 "cnpg-system avec un PVC" -- "$UN" --migrate-cnpg-system --apply
v M03 '[[ $LAST_RC != 0 ]] && ns_has cnpg-system && kubectl -n cnpg-system get pvc p >/dev/null' "PVC présent : refus, PVC intact"
kubectl -n cnpg-system delete pvc p >/dev/null
kubectl label ns cnpg-system app.kubernetes.io/part-of- >/dev/null
r M04 "cnpg-system vide SANS label" -- "$UN" --migrate-cnpg-system --apply
v M04 '[[ $LAST_RC != 0 ]] && ns_has cnpg-system' "sans label part-of : refus"
kubectl label ns cnpg-system app.kubernetes.io/part-of=openchoreo-lab >/dev/null
kubectl -n cnpg-system create quota lab-quota --hard=pods=0 --dry-run=client -o yaml | kubectl label --local -f - app.kubernetes.io/part-of=openchoreo-lab -o yaml | kubectl apply -f - >/dev/null
r M05 "cnpg-system étiqueté, seul un ResourceQuota de l'étape 1" -- "$UN" --migrate-cnpg-system --apply
v M05 '[[ $LAST_RC == 0 ]] && wait_gone cnpg-system' "vide (hors objets de l'étape 1) et étiqueté : supprimé"
# Release Helm dont le seul objet est d'un kind toléré (ResourceQuota part-of) : seule la garde « release »
# peut refuser. Avec `helm list -a` (Helm 4 : flag inconnu), l'erreur était lue comme « aucune release ».
mk_cnpg label
mkdir -p "$UNINSTALL_STATE/mini/templates"
printf 'apiVersion: v2\nname: mini\nversion: 0.0.1\n' >"$UNINSTALL_STATE/mini/Chart.yaml"
printf 'apiVersion: v1\nkind: ResourceQuota\nmetadata: {name: mini, labels: {app.kubernetes.io/part-of: openchoreo-lab}}\nspec: {hard: {pods: "0"}}\n' >"$UNINSTALL_STATE/mini/templates/q.yaml"
helm upgrade --install mini "$UNINSTALL_STATE/mini" -n cnpg-system >/dev/null
r M07 "cnpg-system : release Helm (objet d'un kind toléré)" -- "$UN" --migrate-cnpg-system --apply
v M07 '[[ $LAST_RC != 0 ]] && grep -q "release Helm" <<<"$LAST_OUT" && ns_has cnpg-system' "release Helm présente : refus (helm_releases compatible Helm 4)"
helm uninstall mini -n cnpg-system >/dev/null
r M08 "release retirée : migration" -- "$UN" --migrate-cnpg-system --apply
v M08 '[[ $LAST_RC == 0 ]] && wait_gone cnpg-system' "plus de release : supprimé"
r M06 "rejeu : cnpg-system absent" -- "$UN" --migrate-cnpg-system --apply
v M06 '[[ $LAST_RC == 0 ]] && grep -q "migration déjà faite" <<<"$LAST_OUT"' "idempotent"

echo "== R : rollback étape par étape (12 -> 2), CRD et stockage"
r R12 "--step 12 --apply" -- "$UN" --step 12 --apply
v R12 '[[ $LAST_RC == 0 ]]' "étape 12 (RBAC réduit absent) : rien à annuler"
r R11 "--step 11 --apply" -- "$UN" --step 11 --apply
note R11 "$(kubectl -n lab-argocd get applications.argoproj.io -o json 2>&1 | jq -r '.items[]? | "\(.metadata.name) deletionTimestamp=\(.metadata.deletionTimestamp // "-") finalizers=\(.metadata.finalizers // [])"')"
note R11 "objets laissés dans lab-argocd : $(kubectl -n lab-argocd get all,sa,role,rolebinding,secret,cm -o name 2>&1 | tr '\n' ' ')"
v R11 '[[ $LAST_RC == 0 ]] && ! helm -n lab-argocd status argocd >/dev/null 2>&1 && crd_has applications.argoproj.io' "étape 11 : release argocd supprimée, CRD argoproj.io conservées (keep)"
r R11b "--step 10 --apply après l'étape 11 (Application à finalizer restante)" -- "$UN" --step 10 --apply
v R11b '[[ $LAST_RC != 0 ]] && grep -q "Application Argo présente" <<<"$LAST_OUT"' "Application non nommée par undo_11 (lab-probe-finalizer) : garde Argo toujours active"
r R11c "suppression de lab-probe-finalizer sans contrôleur" -- kubectl -n lab-argocd delete applications.argoproj.io lab-probe-finalizer --wait=false
sleep 3
note R11c "$(kubectl -n lab-argocd get applications.argoproj.io lab-probe-finalizer -o jsonpath='{.metadata.deletionTimestamp} {.metadata.finalizers}' 2>&1)"
v R11c 'kubectl -n lab-argocd get applications.argoproj.io lab-probe-finalizer >/dev/null 2>&1' "Application à resources-finalizer bloquée (Terminating) sans contrôleur Argo"
r R11d "geste opérateur : retrait du finalizer" -- kubectl -n lab-argocd patch applications.argoproj.io lab-probe-finalizer --type=merge -p '{"metadata":{"finalizers":null}}'
v R11d '! kubectl -n lab-argocd get applications.argoproj.io lab-probe-finalizer >/dev/null 2>&1' "Application libérée après retrait manuel du finalizer"
r R1g "--step 1 --apply alors que des releases Helm restent (cert-manager, ESO, kgateway)" -- "$UN" --step 1 --apply
v R1g '[[ $LAST_RC != 0 ]] && grep -q "release(s) Helm encore présente" <<<"$LAST_OUT" && ns_has openchoreo-cert-manager' "étape 1 refusée tant qu'une release reste (sinon objets cluster-scoped orphelins)"
for s in 10 9 8 7 6b 6; do
  r "R$s" "--step $s --apply" -- "$UN" --step "$s" --apply
  v "R$s" '[[ $LAST_RC == 0 ]]' "étape $s annulée sans erreur (objets absents : rien à faire)"
done
r R5a "--step 5 --apply --delete-crds (TrafficPolicy hors essai dans ext-user)" -- "$UN" --step 5 --apply --delete-crds
v R5a '[[ $LAST_RC == 0 ]] && ! helm -n openchoreo-control-plane status kgateway >/dev/null 2>&1 && helm -n openchoreo-control-plane status kgateway-crds >/dev/null && crd_has trafficpolicies.gateway.kgateway.dev && grep -q "utilisée hors essai" <<<"$LAST_OUT"' "kgateway désinstallé ; kgateway-crds CONSERVÉ (CRD gateway.kgateway.dev utilisée hors essai : P2 corrigé)"
kubectl -n ext-user delete trafficpolicies.gateway.kgateway.dev ext-tp >/dev/null
r R5b "--step 5 --apply --delete-crds (plus d'usage hors essai)" -- "$UN" --step 5 --apply --delete-crds
note R5b "GatewayParameters lab-gwp (essai) après : $(kubectl -n openchoreo-control-plane get gatewayparameters.gateway.kgateway.dev lab-gwp 2>&1)"
note R5b "CRD gateway.kgateway.dev restantes : $(kubectl get crd -o name | grep -c gateway.kgateway.dev || true)"
v R5b '[[ $LAST_RC == 0 ]] && ! helm -n openchoreo-control-plane status kgateway-crds >/dev/null 2>&1 && ! crd_has trafficpolicies.gateway.kgateway.dev' "kgateway-crds désinstallé : 8 CRD (templates/, sans keep) SUPPRIMÉES avec leurs CR d'essai"
r R4a "--step 4 --apply --delete-crds (ExternalSecret hors essai à finalizer)" -- "$UN" --step 4 --apply --delete-crds
v R4a '[[ $LAST_RC == 0 ]] && ! helm -n openchoreo-external-secrets status external-secrets >/dev/null 2>&1 && crd_has externalsecrets.external-secrets.io && grep -q "utilisée hors essai" <<<"$LAST_OUT"' "ESO désinstallé ; 23 CRD CONSERVÉES (keep + usage hors essai)"
r R4b "démonstration brute : delete CRD externalsecrets avec CR à finalizer" -- kubectl delete crd externalsecrets.external-secrets.io --wait=false
sleep 3
note R4b "état CRD : $(kubectl get crd externalsecrets.external-secrets.io -o jsonpath='{.metadata.deletionTimestamp} {.status.conditions[?(@.type=="Terminating")].message}' 2>&1)"
v R4b 'crd_has externalsecrets.external-secrets.io && [[ -n "$(kubectl get crd externalsecrets.external-secrets.io -o jsonpath="{.metadata.deletionTimestamp}")" ]]' "CRD bloquée en Terminating tant que la CR à finalizer existe"
kubectl -n ext-user patch externalsecrets.external-secrets.io ext-es --type=merge -p '{"metadata":{"finalizers":null}}' >/dev/null 2>&1 || true
sleep 3
v R4c '! crd_has externalsecrets.external-secrets.io' "CRD supprimée une fois le finalizer retiré"
r R3a "--step 3 --apply --delete-crds (Issuer hors essai)" -- "$UN" --step 3 --apply --delete-crds
v R3a '[[ $LAST_RC == 0 ]] && ! helm -n openchoreo-cert-manager status cert-manager >/dev/null 2>&1 && crd_has issuers.cert-manager.io && kubectl -n ext-user get issuer ext-selfsigned >/dev/null' "cert-manager désinstallé ; CRD conservées (keep + Issuer hors essai intact)"
kubectl -n ext-user delete issuer ext-selfsigned >/dev/null
r R3b "--step 3 --apply --delete-crds (plus d'usage)" -- "$UN" --step 3 --apply --delete-crds
v R3b '[[ $LAST_RC == 0 ]] && ! crd_has issuers.cert-manager.io && ! crd_has challenges.acme.cert-manager.io' "6 CRD cert-manager supprimées (dont acme.cert-manager.io) par nom de rendu"
kubectl apply --server-side --field-manager=lab-uninstall-test -f - >/dev/null <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata: {name: ext-gc}
spec: {controllerName: example.com/x}
EOF
r R2a "--step 2 --apply --delete-crds (GatewayClass sans marque d'essai)" -- "$UN" --step 2 --apply --delete-crds
v R2a '[[ $LAST_RC == 0 ]] && crd_has gatewayclasses.gateway.networking.k8s.io && grep -q "sans marque de l.essai" <<<"$LAST_OUT"' "CRD Gateway API conservées (objet cluster-scoped hors essai)"
r R4d "--step 4 --apply --delete-crds (ESO : CRD restantes, store lab-store marqué essai)" -- "$UN" --step 4 --apply --delete-crds
v R4d '[[ $LAST_RC == 0 ]] && ! crd_has clustersecretstores.external-secrets.io' "CRD ESO restantes supprimées une fois inutilisées"
STORE1="$(snap_storage)"; printf '%s\n' "$STORE1" >"$EV/00-storage-after.txt"
v P01 '[[ "$STORE0" == "$STORE1" ]] && kubectl -n lab-pvc-witness get pvc witness >/dev/null' "PVC témoin et PV : identiques avant/après (aucune création/suppression)"
r R1 "--step 1 --apply" -- "$UN" --step 1 --apply
v R1 '[[ $LAST_RC == 0 ]] && ns_has lab-pvc-witness && ns_has ext-user' "étape 1 : seuls les namespaces d'essai étiquetés sont supprimés ; témoins intacts"
note R1 "namespaces restants : $(kubectl get ns -o name | tr '\n' ' ')"
v P02 '[[ "$(snap_storage)" == "$STORE0" ]]' "PVC/PV identiques après l'étape 1"

r F01 "état final : objets cluster-scoped et CRD restants" -- bash -c "kubectl get clusterrole,clusterrolebinding,validatingwebhookconfiguration,mutatingwebhookconfiguration -o name | grep -E 'cert-manager|external-secrets|kgateway|argocd|openchoreo|lab-' ; kubectl get crd -o name | grep -v -e cattle.io -e cilium.io; true"
v F01 '! grep -qE "clusterrole|webhook" <<<"$LAST_OUT" && ! grep customresourcedefinition <<<"$LAST_OUT" | grep -qvE "argoproj.io|gateway.networking.k8s.io"' "après rollback complet : 0 objet cluster-scoped orphelin ; seules restent les 3 CRD argoproj.io (keep, sans --delete-crds) et les 8 CRD Gateway API (utilisées)"

echo "== ALL : réinstallation puis uninstall.sh --all --apply --delete-crds"
kubectl delete gatewayclass ext-gc --ignore-not-found >/dev/null
wait_trial_ns_gone
install_all -all
r ALL "uninstall.sh --all --apply --delete-crds" -- "$UN" --all --apply --delete-crds
v ALL '[[ $LAST_RC == 0 ]]' "--all de bout en bout sans erreur (étapes 6-12 jamais installées : kinds absents tolérés)"
wait_trial_ns_gone
r F02 "état final après --all" -- bash -c "kubectl get clusterrole,clusterrolebinding,validatingwebhookconfiguration,mutatingwebhookconfiguration -o name | grep -E 'cert-manager|external-secrets|kgateway|argocd|openchoreo|lab-' ; kubectl get crd -o name | grep -v -e cattle.io -e cilium.io; kubectl get ns -o name; true"
v F02 '! grep -qE "clusterrole|webhook|customresourcedefinition|/(lab-cnpg|lab-argocd|lab-secrets|openchoreo-)" <<<"$LAST_OUT" && [[ "$(snap_storage)" == "$STORE0" ]]' "après --all : aucun namespace, CRD ni objet cluster-scoped d'essai ; PVC/PV inchangés"

# Nettoyage du banc (k3d jetable) : rend le cluster rejouable.
{ kubectl get crd -o name | grep -e argoproj.io -e gateway.networking.k8s.io || true; } | xargs -r kubectl delete >/dev/null
kubectl delete ns ext-user lab-pvc-witness --ignore-not-found --wait=false >/dev/null
echo "== bilan : $(grep -c $'\tPASS\t' "$RES") PASS, $(grep -c $'\tFAIL\t' "$RES") FAIL ($RES)"
exit $(( FAILS > 0 ))
