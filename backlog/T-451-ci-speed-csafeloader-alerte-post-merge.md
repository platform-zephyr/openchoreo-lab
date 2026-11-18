---
id: T-451
title: "CI plus rapide : CSafeLoader dans appgen et argo_guard, alerte des échecs k3d post-merge"
status: todo
phase: P0
adr: [0024]
depends_on: []
class: REVUE
velocity: true
lane: ci
stage: S0
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-451 — CI plus rapide : CSafeLoader dans appgen et argo_guard, alerte des échecs k3d post-merge

## Intention
Finir l'accélération de la CI pré-merge commencée dans `docs/research/CI-SPEED.md`. Deux étapes dominent le chemin critique de `ci-ok` et passent leur temps dans le parseur YAML Python pur. Utiliser `yaml.CSafeLoader` (libyaml, déjà fourni par PyYAML 6.0.2), avec repli sur `SafeLoader`. Le comportement reste le même : constructeurs sûrs, tags inconnus traités comme avant. Décider aussi comment alerter quand `k3d-integration` échoue après le merge, car les issues GitHub sont réservées au lancement d'agents (`backlog/README.md`).

## Périmètre de fichiers
tools/appgen/appgen.py, tools/oke/argo_guard.py (garde du noyau, CODEOWNERS), .github/workflows/k3d-integration.yml, docs/research/CI-SPEED.md, docs/CI-K3D.md

## Critères de fin
- [ ] `load_yaml` et `_PlatformLoader` d'`appgen.py` utilisent `getattr(yaml, "CSafeLoader", yaml.SafeLoader)` ; `python3 -m unittest discover -s tests/appgen` passe et `python3 tools/appgen/appgen.py check` ne montre aucune dérive ; durée locale avant/après notée (référence du 2026-11-18 : 17,7 s → 4,2 s)
- [ ] la classe `Loader` d'`argo_guard.py` hérite de `CSafeLoader` avec repli ; `tests/argo-guard/run.sh` rend 41 PASS, 0 FAIL ; durée avant/après notée (référence : 0,62 s → 0,11 s par appel)
- [ ] un run `ci` réel montre `platform` et `appgen` sous 30 s, et le premier `hit` du cache des charts de `platform-render` (lien du run)
- [ ] le mécanisme d'alerte des échecs k3d post-merge (push `main`, nuit) est décidé par Paul, puis implémenté et documenté dans `docs/CI-K3D.md`
- [ ] `docs/research/CI-SPEED.md` mis à jour avec les durées mesurées après le changement

## Notes
Origine : mission « accélérer la CI pré-merge » du 2026-11-18. Les workflows ont été optimisés à part : coupe de `platform` en `platform` + `platform-render`, cache des charts, k3d filtré sur PR et lancé après le merge. `argo_guard.py` est une garde du noyau : classe REVUE, même en mode dev. Ne pas changer les dumpers YAML (`safe_dump`), car la sortie de `generated/` doit rester identique à l'octet.
