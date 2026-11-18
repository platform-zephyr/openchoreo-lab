---
id: T-493
title: "Essai : exécution cluster OKE dispatchée depuis le cloud, sans la session locale du Mac (lecture seule d'abord)"
status: todo
phase: P1
adr: [0025, 0003]
depends_on: [T-490]
class: REVUE + MANDAT
velocity: true
lane: socle-oke
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-493 — Essai d'exécution cluster depuis le cloud

## Intention
Aujourd'hui, installer ou synchroniser la plateforme sur OKE exige la session locale du Mac avec les identifiants de Paul. Vérifier, par l'essai le moins cher, si un workflow de dispatch côté homelab-infra (runner ARC qui détient déjà l'accès OCI de l'ARC) peut ouvrir une session bastion vers OKE. Rien n'est acquis : NOT_TESTED jusqu'à la preuve (`docs/research/POC-OPENCHOREO-STRATEGY.md` §4bis).

## Périmètre de fichiers
dépôt homelab-infra (hors de ce dépôt) : workflow de dispatch et identité OCI dédiée ; ici : docs/research/POC-OPENCHOREO-STRATEGY.md, docs/research/POC-BRIEF-SESSION-LOCALE.md

## Critères de fin
- [ ] workflow de dispatch (jamais sur PR) qui ouvre une session bastion et lit la version de l'API OKE, en lecture seule ; PASS ou FAIL daté avec lien du run
- [ ] identité OCI du runner bornée au bastion et au cluster OKE, inscrite au registre de homelab-infra, sans valeur affichée
- [ ] verdict écrit : si PASS, proposition d'exécuter `tools/oke/install.sh` par ce chemin (nouvelle étape, revue de Paul) ; si FAIL ou BLOCKED, la session locale reste le chemin d'exécution
- [ ] alternative évaluée sans essai : workflow GitHub de ce dépôt à identité fédérée vers OCI (écartée tant que le dépôt est public, ou justifiée)

## Notes
Exécuté par une session homelab-infra, selon ses règles (ARC sur `main`, autonomie maximale, MANDAT pour un nouvel accès d'administration). Ne bloque pas le banc : la session locale du Mac reste le plan de référence.
