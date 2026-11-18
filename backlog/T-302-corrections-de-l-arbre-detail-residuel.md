---
id: T-302
title: "Corrections de l'arbre : détail résiduel, chemins locaux, structure de secrets"
status: in-progress
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
- [ ] 0 constat CRITIQUE/ÉLEVÉ dans l'arbre selon la garde T-303
- [x] commentaires des manifestes réécrits en durcissement générique (2026-11-18 : `platform/cluster-agent/reduced-clusterrole.yaml`, `platform/policies/vap-cluster-agent-scope.yaml` ; règles RBAC et VAP inchangées, `yaml.safe_load_all` OK, diff limité aux lignes de commentaire)

## Notes
Avancement du 2026-11-18 : scénario résiduel réécrit en durcissement générique dans
`docs/REVIEW-PHASE-B.md` et `docs/REVIEW-PR8.md` ; chemins locaux retirés de `docs/research/KUBE-OPS-REQUIREMENTS.md`
et `docs/research/AGENT-FACTORY-24-7.md` ; noms réels de projet et de config Doppler et inventaire chiffré retirés de
`docs/research/{IDENTITY-SECRETS,HOMELAB-INFRA-REQUIREMENTS,HOMELAB-CAPACITY-DATAPLANE}.md` et
`docs/architecture/TARGET-ARCHITECTURE.md`. Hors périmètre : les preuves `tests/*/evidence` (T-450) et le fichier d'exclusions gitleaks.
Premier critère NOT_TESTED : la garde T-303 n'est pas livrée ; le ticket reste `in-progress` jusqu'à son passage.

Proposé par la recherche `sensitive` (clé SEC-3) ; intégration 2 du 2026-11-18.

En S0 (consensus n°2 et arbitrages de Paul, 2026-11-18).
