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
- [x] MANDAT Paul : App `openchoreo-status` créée avec exactement Checks, Commit statuses (écriture) et Metadata (lecture), installée sur ce dépôt et le bac à sable du bras K ; identifiants déposés dans Doppler sous les noms `OPENCHOREO_STATUS_APP_ID`, `OPENCHOREO_STATUS_INSTALLATION_ID`, `OPENCHOREO_STATUS_PRIVATE_KEY` (noms seulement ici) (fait le 2026-11-18 : App créée vers 23:13Z, installée à 23:15:21Z sur `openchoreo-lab` et `bench-ab-arm-k` seulement ; permissions relevées par `gh api orgs/platform-zephyr/installations` : checks=write, statuses=write, metadata=read, aucun événement ; trois noms présents dans Doppler `identity/openchoreo-status` ; réserve : l'intégrité de la clé stockée n'a pas été relue)
- [x] entrée `statut-app-github` du registre confirmée (date réelle, `created_is_estimate: false`) ; `identities_lint.py` PASS (`created_is_estimate: false`, `identities_lint.py` OK le 2026-11-18)
- [x] Notifications activé dans les valeurs d'Argo CD, secret lu par ESO dans `lab-argocd` seulement, gabarit de check run par app et par révision (`success`, `failure`, `neutral`) ; rendu Helm et `argo_guard.py` PASS en CI (PR #159 fusionnée, `ci-ok` vert ; installé par `install.sh` selon PR #168 ; 4 check runs `success` lus sans identifiant le 2026-11-19, `T-489-checks-github-2026-11-19.md`, `T-497-lecteur-statut-et-quota-argocd-2026-11-19.md`)
- [ ] test négatif : le jeton de l'App est refusé en écriture sur le contenu du dépôt (preuve datée, API GitHub)
- [x] `docs/AGENT-IDENTITY.md` : rôle, permissions, rotation, et pourquoi l'App de l'usine n'est pas réutilisée (section ajoutée le 2026-11-18)

## Notes
Art antérieur : Argo CD Notifications, service `github` (`appID`, `installationID`, `privateKey` ; gabarits `status` et `checkRun`), docs Argo CD lues le 2026-11-18 ; permalien à SHA à citer dans la PR. Contrôleur Notifications : +1 pod sur OKE (budget T-487 ; quota lab-argocd : 6 pods et 100m avec le contrôleur ApplicationSet, juste).
2026-11-18 (branche `claude/t-489-notifications`, STATIC) : values `notifications` (cm et secret non créés par le chart), `platform/install/argocd/notifications/` (ConfigMap, ExternalSecret sur `lab-store`, CiliumNetworkPolicy vers `api.github.com`), condition `^lab-argocd$` de `lab-store`. `tests/argo-notifications/run.sh` : 12 PASS (statique et négatifs, `argo_guard` rc=0, `helm template` + `psa_check`, kubeconform, triggers et gabarits rendus avec expr et sprig). Case 3 NON cochée : « PASS en CI » exige une PR. Runtime NOT_TESTED : clé à déposer dans `lab-secrets`, objets à poser, synchro, check run observé.

### Reprise (2026-11-19, T-510)
- Fait : App `openchoreo-status` et Notifications en place ; 4 check runs `success` lus sans identifiant (RUNTIME OKE, 00:59Z) ; PR #159, #168 fusionnées ; lecteur de statut : T-497 et T-507.
- Reste : case 4, test négatif d'écriture de contenu (NOT_TESTED : clé privée non manipulable par l'agent) ; à jouer par Paul (suivi dans T-515).
- Prochaine action : Paul tente l'écriture de contenu avec un jeton d'installation et consigne le refus (preuve datée).
- Qui : Paul.
- Pièges : un check run `success` prouve la synchro GitOps, pas la santé de l'app (searxng publié `success` pod en échec).
