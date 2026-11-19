---
id: T-499
title: "remoteRef des secrets d'app conforme au fournisseur ESO kubernetes de lab-store (capacité secretStoreProvider)"
status: in-progress
phase: P1
adr: [0014, 0024]
depends_on: [T-489]
class: REVUE
velocity: true
lane: appgen
stage: S1
model: claude-opus-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-499 — Secrets d'app résolubles par lab-store (fournisseur ESO kubernetes)

## Intention
Sur OKE, `lab-store` est un ClusterSecretStore ESO à fournisseur `kubernetes` (coffre = Secrets de `lab-secrets`).
Le contrat générait `remoteRef.key: SEARXNG_SECRET` (forme Doppler) : un nom de Secret Kubernetes en majuscules est
impossible, l'ExternalSecret reste en `SecretSyncedError` et le pod searxng en `CreateContainerConfigError`
(`backlog/evidence/T-489-checks-github-2026-11-19.md`, section searxng). Correction par la sémantique native du
fournisseur ESO kubernetes : `key` = nom du Secret, `property` = clé dans ce Secret. Le fournisseur est une capacité
du cluster (`secretStoreProvider`, défaut `doppler`), pas un test en dur : k3d (Doppler) et ses fixtures sont inchangés.

## Périmètre de fichiers
docs/schema/capabilities.schema.json, clusters/oke/capabilities.yaml, tools/appgen/appgenlib/ (model, semantic, render_native, render_helm), tests/appgen/test_secret_store.py, generated/namespaces/default/projects/searxng/, docs/APP-CONTRACT.md, backlog/T-499-secrets-lab-store-kubernetes.md

## Critères de fin
- [x] STATIC : capacité `secretStoreProvider` (`doppler` | `kubernetes`, défaut `doppler`) au schéma ; `oke` = `kubernetes` ; `remote_ref()` unique pour SecretReference (natif) et ExternalSecret (helm) ; `generated/…/searxng-secrets.yaml` régénéré par `appgen render` : `{key: searxng-secret, property: SEARXNG_SECRET}` ; seul fichier généré modifié (`appgen check` : aucune dérive, 86 fichiers, 2026-11-19)
- [x] STATIC : cas négatifs à la génération sur store kubernetes : clé dont le nom de Secret dérivé n'est pas RFC 1123 (`SEARXNG_SECRET_` → `searxng-secret-`) refusée avec message ; `property` explicite refusée ; même clé admise sur store Doppler (`tests/appgen/test_secret_store.py`, suite appgen : 217 tests OK le 2026-11-19)
- [ ] CI : suite `k3d-integration` lancée par dispatch sur la branche avant fusion (`tools/appgen/` change ; elle ne tourne pas sur PR)
- [ ] RUNTIME OKE (session cluster) : Secret `searxng-secret` (clé `SEARXNG_SECRET`, valeur aléatoire générée par tube, jamais affichée) posé dans `lab-secrets` ; ExternalSecret `searxng` Ready ; pod `searxng` Ready ; preuve datée

## Notes
- Amont adopté : sémantique `remoteRef.key` / `property` du fournisseur ESO kubernetes (docs/provider/kubernetes.md d'external-secrets) ; aucun code tiers copié.
- Hors périmètre, à trancher : `clusters/homelab/capabilities.yaml` déclare `secretStore: lab-store` sans `secretStoreProvider` (défaut `doppler`). Si le `lab-store` du homelab est celui de `platform/install/manifests/20-eso-lab-store.yaml` (fournisseur kubernetes), y ajouter `secretStoreProvider: kubernetes` par PR plateforme.
- `cnpg-lab-db` (PushSecret/ExternalSecret `lab-pg-roles-<nom>` + `property: password`) suit déjà la forme kubernetes : non touché.
