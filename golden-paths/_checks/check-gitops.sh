#!/usr/bin/env bash
# check-gitops.sh APP ENV : la chaîne Git -> Argo CD -> OpenChoreo est réconciliée (lecture seule).
# Utilisable seul (en-tête + verdict) ou via run-all.sh (GP_NESTED=1).
# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"
APP="${1:?usage: check-gitops.sh APP ENV}"; ENV="${2:?usage: check-gitops.sh APP ENV}"
GEN="$REPO_ROOT/generated/namespaces/$OC_NS/projects/$APP"
header "$APP" "$ENV" gitops

# G1 : le rendu commité est à jour (appgen check, local, sans cluster).
if python3 "$REPO_ROOT/tools/appgen/appgen.py" check >/dev/null 2>&1; then
  record PASS G1 "appgen check : aucune dérive entre apps/ et generated/"
else
  record FAIL G1 "appgen check : dérive ou erreur (lancer 'python3 tools/appgen/appgen.py check')"
fi

# G2 : Argo CD a synchronisé la révision de origin/main.
if has_crd applications.argoproj.io; then
  want="$(git -C "$REPO_ROOT" rev-parse origin/main 2>/dev/null || echo inconnu)"
  for a in lab-crds lab-platform lab-apps; do
    s="$(k get applications.argoproj.io "$a" -n "$ARGOCD_NS" -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)"
    r="$(k get applications.argoproj.io "$a" -n "$ARGOCD_NS" -o jsonpath='{.status.sync.revision}' 2>/dev/null || true)"
    if [ -z "$s" ]; then record BLOCKED G2 "Application Argo '$a' absente de $ARGOCD_NS"; continue; fi
    expect G2 "Argo '$a' sync/health" "$s" "Synced/Healthy"
    expect G2 "Argo '$a' révision = origin/main" "$r" "$want"
  done
else
  record BLOCKED G2 "CRD applications.argoproj.io absente : Argo CD non installé (phase A3)"
fi

# G3 : objets OpenChoreo présents et autoDeploy=false.
if ! has_crd components.openchoreo.dev; then
  record BLOCKED G3 "CRD OpenChoreo absentes"; finish; exit $?
fi
ad="$(k get components.openchoreo.dev "$APP" -n "$OC_NS" -o jsonpath='{.spec.autoDeploy}' 2>/dev/null || echo absent)"
case "$ad" in
  absent) record FAIL G3 "Component '$APP' absent de $OC_NS (PR non mergée ou Argo non synchronisé)"; finish; exit $? ;;
  true)   record FAIL G3 "Component '$APP' : autoDeploy=true (interdit, boucle Argo/contrôleur)" ;;
  *)      record PASS G3 "Component '$APP' présent, autoDeploy=false" ;;
esac

# G4 : la ReleaseBinding du cluster pointe sur la release de Git.
rb="$GEN/components/$APP/release-bindings/$APP-$ENV.yaml"
if [ -f "$rb" ]; then
  git_rel="$(python3 -c 'import sys,yaml;print(yaml.safe_load(open(sys.argv[1]))["spec"]["releaseName"])' "$rb")"
  live_rel="$(k get releasebindings.openchoreo.dev "$APP-$ENV" -n "$OC_NS" -o jsonpath='{.spec.releaseName}' 2>/dev/null || true)"
  expect G4 "ReleaseBinding $APP-$ENV releaseName = Git" "$live_rel" "$git_rel"
  rel_live="$(k get componentreleases.openchoreo.dev "$git_rel" -n "$OC_NS" -o name 2>/dev/null || true)"
  [ -n "$rel_live" ] && record PASS G4 "ComponentRelease $git_rel présente" || record FAIL G4 "ComponentRelease $git_rel absente du cluster"
else
  record FAIL G4 "fichier généré absent : ${rb#"$REPO_ROOT"/}"
fi

# G5 : conditions des bindings (Ready = réconcilié, pas encore « fonctionne »).
for c in ReleaseSynced ResourcesReady Ready; do
  expect G5 "ReleaseBinding $APP-$ENV $c" "$(cond releasebindings.openchoreo.dev "$APP-$ENV" "$OC_NS" "$c")" "True"
done
expect G5 "ProjectReleaseBinding $APP-$ENV Ready" "$(cond projectreleasebindings.openchoreo.dev "$APP-$ENV" "$OC_NS" Ready)" "True"

# G6 : aucun objet applicatif hors Git (orphelins signalés par Argo).
if has_crd applications.argoproj.io; then
  orphans="$(k get applications.argoproj.io lab-apps -n "$ARGOCD_NS" \
     -o jsonpath='{range .status.conditions[?(@.type=="OrphanedResourceWarning")]}{.message}{end}' 2>/dev/null || true)"
  [ -z "$orphans" ] && record PASS G6 "aucun orphelin signalé par Argo lab-apps" || record FAIL G6 "orphelins : $orphans"
fi
finish; exit $?
