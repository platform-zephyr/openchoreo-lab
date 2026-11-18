---
id: T-302
title: "Corrections de l'arbre : détail résiduel, chemins locaux, structure de secrets"
status: done
phase: P0
adr: [0002]
depends_on: [T-303]
class: REVUE
velocity: false
lane: gouvernance
stage: S0
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-302 — Corrections de l'arbre : détail résiduel, chemins locaux, structure de secrets

## Intention
Retirer de l'arbre le scénario d'exploitation résiduel (Paul juge s'il relève du signalement privé), les chemins `/Users/<prénom>`, et la structure révélatrice des clés Doppler.

## Périmètre de fichiers
docs/REVIEW-PHASE-B.md, docs/REVIEW-PR8.md, platform/cluster-agent/, platform/policies/, fichiers contenant des chemins locaux

## Critères de fin
- [x] 0 constat CRITIQUE/ÉLEVÉ dans l'arbre selon la garde T-303 (2026-11-18 : `tools/dev/leak-guard.sh` rejoué ici à 12:55 UTC → `LEAK-GUARD: PASS`, `.gitleaksignore` réduit à 2 lignes par T-450 ; job `leak-guard` vert sur le run CI 44307223494 (PR #55) et sur le push `main` 44308148294 ; STATIC + CI)
- [x] commentaires des manifestes réécrits en durcissement générique (2026-11-18 : `platform/cluster-agent/reduced-clusterrole.yaml`, `platform/policies/vap-cluster-agent-scope.yaml` ; règles RBAC et VAP inchangées, `yaml.safe_load_all` OK, diff limité aux lignes de commentaire)

## Notes
Avancement du 2026-11-18 : scénario résiduel réécrit en durcissement générique dans
`docs/REVIEW-PHASE-B.md` et `docs/REVIEW-PR8.md` ; chemins locaux retirés de `docs/research/KUBE-OPS-REQUIREMENTS.md`
et `docs/research/AGENT-FACTORY-24-7.md` ; noms réels de projet et de config Doppler et inventaire chiffré retirés de
`docs/research/{IDENTITY-SECRETS,HOMELAB-INFRA-REQUIREMENTS,HOMELAB-CAPACITY-DATAPLANE}.md` et
`docs/architecture/TARGET-ARCHITECTURE.md`. Hors périmètre : les preuves `tests/*/evidence` (T-450) et le fichier d'exclusions gitleaks.
Clôture du 2026-11-18 : la garde T-303 est livrée et verte ; les deux critères sont prouvés.

Proposé par la recherche `sensitive` (clé SEC-3) ; intégration 2 du 2026-11-18.

En S0 (consensus n°2 et arbitrages de Paul, 2026-11-18).
