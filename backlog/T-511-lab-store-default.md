---
id: T-511
title: "Renommer le ClusterSecretStore `lab-store` en `default` à la prochaine réinstallation OKE"
status: todo
phase: P1
adr: [0014, 0025]
depends_on: []
class: REVUE
velocity: false
lane: socle-oke
stage: S2
model: claude-opus-5-5
effort: high
routing: R1-noyau
github_issue: null
---
# T-511 — Renommer le ClusterSecretStore `lab-store` en `default` à la prochaine réinstallation OKE

## Intention
La documentation OpenChoreo attend un ClusterSecretStore nommé `default`. Le labo l'appelle `lab-store` (fournisseur ESO `kubernetes`, Secrets de `lab-secrets`) et copie son nom dans `clusters/*/capabilities.yaml`. Renommer le store à la prochaine réinstallation OKE, sans migration à chaud, et retirer le nom du store des capacités de cluster pour qu'il ne soit plus une donnée à tenir à jour.

## Périmètre de fichiers
platform/install/manifests/20-eso-lab-store.yaml, platform/install/argocd/notifications/, clusters/oke/capabilities.yaml, clusters/homelab/capabilities.yaml, tools/oke/install.sh, tools/oke/verify.sh, docs/APP-CONTRACT.md

## Critères de fin
- [ ] store `default` (fournisseur `kubernetes`) dans `20-eso-lab-store.yaml` ; ExternalSecret de `platform/install/argocd/notifications/` et `cnpg-lab-db` mis à jour ; `just`/`tools/dev/check --static` PASS
- [ ] `secretStore` retiré de `clusters/*/capabilities.yaml` (ou valeur par défaut documentée) ; `appgen check` sans dérive ; AUCUNE ligne nouvelle dans `tools/appgen/` (GEL, voir NEXT.md)
- [ ] `verify.sh --step 4` contrôle le store `default` ; RUNTIME OKE après la réinstallation : ExternalSecret `argocd-notifications-secret` Ready (preuve datée)

## Notes
Origine : `docs/research/OPENCHOREO-DEMO-NATIVE.md` (écart avec la doc amont) et T-499. À faire seulement avec une réinstallation d'OKE déjà prévue (pas de renommage à chaud : un ExternalSecret en erreur coupe les check runs de T-489). Si le GEL de `tools/appgen/` interdit de retirer le champ du schéma, ne retirer que la valeur dans `clusters/*/capabilities.yaml`.
