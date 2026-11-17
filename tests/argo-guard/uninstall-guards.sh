#!/usr/bin/env bash
# Tests des gardes de tools/oke/uninstall.sh (revue PR #8, P2 et P3), SANS cluster : kubectl et helm
# FACTICES (PATH) qui journalisent chaque appel ; l'état « cluster » (CRD, objets, Application, Components)
# est un jeu de fichiers dans un répertoire temporaire hors dépôt. `helm template`/`pull` délèguent au vrai
# helm : les groupes de CRD viennent du RENDU des charts épinglés (versions.env, sha256 vérifié).
# Aucun kubeconfig réel : OKE_ACCESS_DIR pointe sur un faux kubeconfig temporaire.
# Usage : tests/argo-guard/uninstall-guards.sh   (helm, jq, yq, python3 ; réseau au 1er téléchargement des
# charts, sauf si ARGO_GUARD_CHART_CACHE désigne un dossier de .tgz déjà vérifiés)
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/uninstall-guards.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
REAL_HELM="$(command -v helm)"
BIN="$WORK/bin" FIX="$WORK/fix" STATE="$WORK/state" LOGF="$WORK/calls.log"
mkdir -p "$BIN" "$FIX" "$STATE/charts" "$WORK/access"
if [[ -n "${ARGO_GUARD_CHART_CACHE:-}" ]]; then cp "$ARGO_GUARD_CHART_CACHE"/*.tgz "$STATE/charts/" 2>/dev/null || true; fi
: > "$WORK/access/kubeconfig"; chmod 600 "$WORK/access/kubeconfig"
pass=0 fail=0

# --- kubectl factice --------------------------------------------------------------------------------
cat > "$BIN/kubectl" <<'EOF'
#!/usr/bin/env bash
printf 'kubectl %s\n' "$*" >> "$LOGF"
a="$*"
case "$1" in delete|apply|label|annotate|patch|create|replace|scale) printf 'WRITE kubectl %s\n' "$a" >> "$LOGF"; exit 0;; esac
case "$a" in
  "config current-context") echo context-oracle-a1-test;;
  "config view --minify -o jsonpath={.clusters[0].cluster.server}") echo https://127.0.0.1:16443;;
  "config view --minify -o jsonpath={.clusters[0].cluster.tls-server-name}") echo 10.0.2.10;;
  "get nodes -o json") echo '{"items":[{"spec":{"providerID":"ocid1.instance.oc1.test"},"status":{"nodeInfo":{"architecture":"arm64"}}}]}';;
  "get crd -o json") cat "$FIX/crds.json";;
  "get crd -o name") jq -r '.items[] | "customresourcedefinition.apiextensions.k8s.io/" + .metadata.name' "$FIX/crds.json";;
  "get crd "*" --ignore-not-found -o name")
    n="${a#get crd }"; n="${n%% *}"
    jq -r --arg n "$n" '.items[] | select(.metadata.name == $n) | "customresourcedefinition.apiextensions.k8s.io/" + .metadata.name' "$FIX/crds.json";;
  "-n lab-argocd get applications.argoproj.io -o name") cat "$FIX/apps.txt" 2>/dev/null || true;;
  "get components.openchoreo.dev -A -o name") cat "$FIX/components.txt" 2>/dev/null || true;;
  "get ns -l platform.smadja.dev/cell=restricted -o name") cat "$FIX/cells.txt" 2>/dev/null || true;;
  "get ns "*" --ignore-not-found -o name"|"get namespace "*" --ignore-not-found -o name")
    n="$(awk '{print $3}' <<<"$a")"; grep -qx "$n" "$FIX/ns.txt" 2>/dev/null && echo "namespace/$n"; true;;
  "get ns "*" -o jsonpath="*|"get namespace "*" -o jsonpath="*) echo openchoreo-lab;;
  "get "*" -A -o json") r="$(awk '{print $2}' <<<"$a")"; if [[ -f "$FIX/objs/$r.json" ]]; then cat "$FIX/objs/$r.json"; else echo '{"items":[]}'; fi;;
  *) printf 'UNHANDLED kubectl %s\n' "$a" >> "$LOGF"; echo "kubectl factice : appel non prévu : $a" >&2; exit 1;;
esac
EOF
# --- helm factice : rendu réel, tout le reste simulé ---------------------------------------------------
cat > "$BIN/helm" <<EOF
#!/usr/bin/env bash
printf 'helm %s\n' "\$*" >> "\$LOGF"
args=("\$@"); [[ "\${args[0]}" == -n ]] && args=("\${args[@]:2}")
case "\${args[0]}" in
  template|pull|version|show) exec "$REAL_HELM" "\$@";;
  list) [[ -n "\${HELM_LIST_EMPTY:-}" ]] || printf '%s\n' kgateway kgateway-crds cert-manager external-secrets;;  # releases présentes (vide si HELM_LIST_EMPTY)
  status|get) exit 1;;
  uninstall|upgrade|install|rollback) printf 'WRITE helm %s\n' "\$*" >> "\$LOGF"; exit 0;;
  *) printf 'UNHANDLED helm %s\n' "\$*" >> "\$LOGF"; exit 1;;
esac
EOF
chmod +x "$BIN/kubectl" "$BIN/helm"

crd() { # NOM GROUPE PLURIEL SCOPE -> objet JSON
  printf '{"metadata":{"name":"%s"},"spec":{"group":"%s","names":{"plural":"%s"},"scope":"%s"}}' "$1" "$2" "$3" "$4"
}
cluster_crds() { printf '{"items":[%s]}\n' "$(IFS=,; echo "$*")" > "$FIX/crds.json"; }
obj() { # RESSOURCE NAMESPACE : un objet de cette ressource dans ce namespace
  printf '{"items":[{"metadata":{"name":"x","namespace":"%s"}}]}\n' "$2" > "$FIX/objs/$1.json"
}
reset() {
  rm -rf "$FIX"; mkdir -p "$FIX/objs"; : > "$LOGF"
  printf 'customresourcedefinition.apiextensions.k8s.io/ciliumnetworkpolicies.cilium.io\n' > "$STATE/crds-before.txt"
}
CM=(
  "$(crd challenges.acme.cert-manager.io acme.cert-manager.io challenges Namespaced)"
  "$(crd orders.acme.cert-manager.io acme.cert-manager.io orders Namespaced)"
  "$(crd certificaterequests.cert-manager.io cert-manager.io certificaterequests Namespaced)"
  "$(crd certificates.cert-manager.io cert-manager.io certificates Namespaced)"
  "$(crd clusterissuers.cert-manager.io cert-manager.io clusterissuers Cluster)"
  "$(crd issuers.cert-manager.io cert-manager.io issuers Namespaced)"
)

run_uninstall() { # ARGS... ; rc dans $RC, sortie dans $OUT
  RC=0
  OUT="$(PATH="$BIN:$PATH" LOGF="$LOGF" FIX="$FIX" OKE_ACCESS_DIR="$WORK/access" KUBECONFIG="$WORK/access/kubeconfig" \
    OKE_PHASEB_STATE="$STATE" "$REPO/tools/oke/uninstall.sh" "$@" 2>&1)" || RC=$?
}
verdict() { # NOM CONDITION_OK(0/1) DÉTAIL
  if [[ "$2" == 0 ]]; then printf 'PASS %-34s %s\n' "$1" "$3"; pass=$((pass + 1))
  else printf 'FAIL %-34s %s\n--- sortie ---\n%s\n--- appels ---\n%s\n' "$1" "$3" "$OUT" "$(cat "$LOGF")"; fail=$((fail + 1)); fi
}
writes() { grep -c '^WRITE' "$LOGF" || true; }
crd_writes() { grep -E '^WRITE (kubectl delete .*customresourcedefinition|helm .*uninstall kgateway-crds)' "$LOGF" || true; }

# P2-a : kgateway-crds, objet GatewayParameters hors essai => release kgateway-crds CONSERVÉE.
reset
cluster_crds "$(crd gatewayparameters.gateway.kgateway.dev gateway.kgateway.dev gatewayparameters Namespaced)" \
  "$(crd backends.gateway.kgateway.dev gateway.kgateway.dev backends Namespaced)"
obj gatewayparameters.gateway.kgateway.dev team-x
run_uninstall --step 5 --apply --delete-crds
c="$(crd_writes)"; if [[ $RC == 0 && -z "$c" ]] && grep -q 'gateway.kgateway.dev utilisée hors essai' <<<"$OUT"; then ok=0; else ok=1; fi; verdict P2a-kgateway-en-usage $ok "rc=$RC, écritures CRD=[${c}]"

# P2-b : cert-manager, Challenge (acme.cert-manager.io) hors essai => CRD CONSERVÉES.
reset; cluster_crds "${CM[@]}"; obj challenges.acme.cert-manager.io team-y
run_uninstall --step 3 --apply --delete-crds
c="$(crd_writes)"; if [[ $RC == 0 && -z "$c" ]] && grep -q 'challenges.acme.cert-manager.io utilisée hors essai' <<<"$OUT"; then ok=0; else ok=1; fi; verdict P2b-acme-en-usage $ok "rc=$RC, écritures CRD=[${c}]"

# P2-c : ESO, Password (generators.external-secrets.io) hors essai => CRD CONSERVÉES.
reset
cluster_crds "$(crd passwords.generators.external-secrets.io generators.external-secrets.io passwords Namespaced)" \
  "$(crd externalsecrets.external-secrets.io external-secrets.io externalsecrets Namespaced)"
obj passwords.generators.external-secrets.io team-z
run_uninstall --step 4 --apply --delete-crds
c="$(crd_writes)"; if [[ $RC == 0 && -z "$c" ]] && grep -q 'passwords.generators.external-secrets.io utilisée hors essai' <<<"$OUT"; then ok=0; else ok=1; fi; verdict P2c-generators-en-usage $ok "rc=$RC, écritures CRD=[${c}]"

# P2-d : groupe voisin inconnu du rendu (extra.cert-manager.io) => échec fermé, CRD CONSERVÉES.
reset; cluster_crds "${CM[@]}" "$(crd widgets.extra.cert-manager.io extra.cert-manager.io widgets Namespaced)"
run_uninstall --step 3 --apply --delete-crds
c="$(crd_writes)"; if [[ $RC == 0 && -z "$c" ]] && grep -q 'inconnu' <<<"$OUT"; then ok=0; else ok=1; fi; verdict P2d-groupe-inconnu $ok "rc=$RC, écritures CRD=[${c}]"

# P2-e (positif) : aucun usage hors essai => suppression des 6 CRD RENDUES seulement (pas la CRD
# legacythings.cert-manager.io du même groupe, absente du rendu, qu'un filtre par suffixe aurait supprimée).
reset; cluster_crds "${CM[@]}" "$(crd legacythings.cert-manager.io cert-manager.io legacythings Namespaced)"
obj certificates.cert-manager.io openchoreo-control-plane
run_uninstall --step 3 --apply --delete-crds
c="$(crd_writes)"; n="$(grep -o 'customresourcedefinition.apiextensions.k8s.io/[a-z.-]*' <<<"$c" | wc -l | tr -d ' ')"
if [[ $RC == 0 && "$n" == 6 ]] && ! grep -q legacythings <<<"$c"; then ok=0; else ok=1; fi; verdict P2e-positif-6-crd-rendues $ok "rc=$RC, CRD supprimées=$n, legacythings épargnée"

# P3-a : undo_1 avec une Application Argo présente => REFUS, aucune écriture.
reset; cluster_crds "$(crd applications.argoproj.io argoproj.io applications Namespaced)"
echo application.argoproj.io/lab-root > "$FIX/apps.txt"
printf 'namespace/dp-default-x\n' > "$FIX/cells.txt"; printf 'lab-pg\nlab-cnpg\n' > "$FIX/ns.txt"
run_uninstall --step 1 --apply
w="$(writes)"; if [[ $RC != 0 && "$w" == 0 ]] && grep -q 'Application Argo présente' <<<"$OUT"; then ok=0; else ok=1; fi; verdict P3a-undo1-argo-present $ok "rc=$RC, écritures=$w"

# P3-b : undo_1 sans Argo mais avec des Components => REFUS, aucune écriture (dp-* intacts).
reset; cluster_crds "$(crd components.openchoreo.dev openchoreo.dev components Namespaced)"
echo component.openchoreo.dev/default/whoami > "$FIX/components.txt"
printf 'namespace/dp-default-x\n' > "$FIX/cells.txt"; printf 'lab-pg\n' > "$FIX/ns.txt"
run_uninstall --step 1 --apply
w="$(writes)"; if [[ $RC != 0 && "$w" == 0 ]] && grep -q 'Components existent encore' <<<"$OUT"; then ok=0; else ok=1; fi; verdict P3b-undo1-components $ok "rc=$RC, écritures=$w"

# P3-c (positif) : ni Application ni Component => suppressions des dp-* marqués et namespaces d'essai.
reset; cluster_crds "$(crd components.openchoreo.dev openchoreo.dev components Namespaced)" \
  "$(crd applications.argoproj.io argoproj.io applications Namespaced)"
printf 'namespace/dp-default-x\n' > "$FIX/cells.txt"; printf 'lab-pg\n' > "$FIX/ns.txt"
# aucune release Helm ne reste dans les namespaces d'essai (nouvelle garde de undo_1, preuve k3d A3)
export HELM_LIST_EMPTY=1
run_uninstall --step 1 --apply
unset HELM_LIST_EMPTY
if [[ $RC == 0 ]] && grep -q '^WRITE kubectl delete namespace dp-default-x' "$LOGF" \
  && grep -q '^WRITE kubectl delete namespace lab-pg' "$LOGF"; then ok=0; else ok=1; fi
verdict P3c-positif-undo1 $ok "rc=$RC, écritures=$(writes)"

# Aucun appel non prévu par les mocks (sinon un chemin de code n'a pas été simulé).
if grep -q UNHANDLED "$LOGF"; then echo "appel non simulé :"; grep UNHANDLED "$LOGF"; fail=$((fail + 1)); fi
echo "uninstall-guards : $pass PASS, $fail FAIL"
(( fail == 0 ))
