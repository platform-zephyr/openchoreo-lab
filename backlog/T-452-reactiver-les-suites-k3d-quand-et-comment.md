---
id: T-452
title: "Réactiver les suites k3d : quand et sous quelle forme (étude)"
status: in-progress
phase: P0
adr: [0024]
depends_on: []
class: AUTONOME
velocity: false
lane: ci
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---

# T-452 — Réactiver les suites k3d : quand et sous quelle forme

## Intention
Les suites k3d (vap, k3d, argo-escalation, gitops-k3d) sont désactivées sur PR, push et nuit (décision de Paul, 2026-11-18) : lancement manuel seulement. Elles ne doivent pas freiner les itérations rapides des agents ; l'environnement de dev permet de ne pas attraper tous les bugs à cette étape. Décider quand et comment les remettre, sans bloquer les agents.

## Périmètre de fichiers
docs/research/K3D-REACTIVATION.md, .github/workflows/k3d-integration.yml, docs/CI-K3D.md

## Critères de fin
- [x] rapport `docs/research/K3D-REACTIVATION.md` : jalon de réactivation (avant FINAL0 ?), forme (nuit seule, label, post-merge non bloquant, suite réduite), coût en minutes, signal d'échec sans bloquer (STATIC, rapport du 2026-11-18 : §3 jalons et coûts mesurés sur les runs 44287620940 et 44288812441, §4 signal)
- [x] état des échecs connus (B-09, T12, durée d'argo-escalation) et plan de correction (STATIC, rapport §2, 2026-11-18 ; ancre gitops-k3d ajoutée ; corrections non faites)
- [ ] workflow mis à jour selon la décision, `ci-ok` inchangé, aucune suite bloquante avant le jalon retenu

## Notes
Étude confiée à un sous-agent Opus. Rapport à arbitrer par Paul.

Étude livrée le 2026-11-18 (`docs/research/K3D-REACTIVATION.md`) ; `docs/CI-K3D.md` aligné sur le dispatch manuel. Critère 3 ouvert : le workflow n'est pas modifié tant que Paul n'a pas tranché D-1 à D-6 (rapport §7).

Décisions de Paul (2026-11-18, « ok D-1 à D-6 », recommandations du rapport) :
- D-1 : ADR-0002 §4 amendé (contrôle k3d suspendu en dev, rétabli à FINAL0). Fait.
- D-2 : T-435 en FINAL0, T-339 réduit à la bibliothèque. Fait.
- D-3 : réactivation nocturne non bloquante à la fin de S1, avant T-364, après les corrections T-456 à T-458.
- D-4 : alerte par lecture du dispatcher (T-314) et ticket de backlog `fix-k3d-<suite>` ; aucune issue GitHub automatique.
- D-5 : B-09 en `KNOWN_FAIL` au niveau du cas (T-457) ; vraie correction dans la baseline de la VM lab (T-363).
- D-6 : déclencheur par label `k3d` autorisé (`pull_request: types: [labeled]`, label seul). Fait.
Reste ouvert : critère 3 (le `schedule` nocturne) à la fin de S1.
