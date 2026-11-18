---
id: T-489
title: "Identité d'agent pour publier le statut des apps : GitHub App dédiée aux statuts et Argo CD Notifications"
status: todo
phase: P1
adr: [0025, 0011, 0007]
depends_on: [T-072]
class: REVUE + MANDAT
velocity: true
lane: preuve
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-489 — Identité d'agent pour publier le statut des apps

## Intention
Le statut des apps est publié aujourd'hui sous l'identité de Paul. Le publier par une GitHub App dédiée (`openchoreo-status` : Checks et Commit statuses en écriture, Metadata en lecture), utilisée par Argo CD Notifications (service `github` amont), pour que les agents soient autonomes avec ou sans le compte de Paul. La clé de l'App de l'usine (`openchoreo-worker`) n'entre jamais dans un cluster (`docs/research/POC-OPENCHOREO-STRATEGY.md` §4).

## Périmètre de fichiers
docs/state/identities.yaml, docs/AGENT-IDENTITY.md, platform/install/values/argocd.yaml, platform/install/argocd/notifications/, tests/argo-notifications/

## Critères de fin
- [ ] MANDAT Paul : App `openchoreo-status` créée avec exactement Checks, Commit statuses (écriture) et Metadata (lecture), installée sur ce dépôt et le bac à sable du bras K ; identifiants déposés dans Doppler sous les noms `OPENCHOREO_STATUS_APP_ID`, `OPENCHOREO_STATUS_INSTALLATION_ID`, `OPENCHOREO_STATUS_PRIVATE_KEY` (noms seulement ici)
- [ ] entrée `statut-app-github` du registre confirmée (date réelle, `created_is_estimate: false`) ; `identities_lint.py` PASS
- [ ] Notifications activé dans les valeurs d'Argo CD, secret lu par ESO dans `lab-argocd` seulement, gabarit de check run par app et par révision (`success`, `failure`, `neutral`) ; rendu Helm et `argo_guard.py` PASS en CI
- [ ] test négatif : le jeton de l'App est refusé en écriture sur le contenu du dépôt (preuve datée, API GitHub)
- [ ] `docs/AGENT-IDENTITY.md` : rôle, permissions, rotation, et pourquoi l'App de l'usine n'est pas réutilisée

## Notes
Art antérieur : Argo CD Notifications, service `github` (`appID`, `installationID`, `privateKey` ; gabarits `status` et `checkRun`), docs Argo CD lues le 2026-11-18 ; permalien à SHA à citer dans la PR. Contrôleur Notifications : +1 pod sur OKE (budget T-487).
