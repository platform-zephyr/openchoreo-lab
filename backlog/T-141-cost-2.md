---
id: T-141
title: "Estimation du budget OKE et contrôle périodique des quotas gratuits (cost-evidence.v1)"
status: todo
phase: P0
adr: [0003, 0004, 0017]
depends_on: [T-001, T-140]
class: AUTONOME + MANDAT
velocity: false
lane: coût
github_issue: null
---
# T-141 — Estimation du budget OKE et contrôle périodique des quotas gratuits (cost-evidence.v1)

## Intention
Reprend T-009 et ajoute un contrôle lecture seule, daté, des volumes (orphelins, boot), IP réservées détachées, backups, quotas réels (2 OCPU, 12 Go, 200 Go, LB 0) ; le MANDAT crée une clé OCI lecture seule dédiée.

## Périmètre de fichiers
tools/oke/ (lecture), tools/cost/, docs/schema/cost-evidence.v1.json, docs/

## Critères de fin
- [ ] mesure datée requests/usage/pods/IP et tableau composant -> cluster recommandé (critères de T-009)
- [ ] sortie JSON cost-evidence.v1 avec PASS/FAIL/NOT_TESTED/BLOCKED et date
- [ ] FAIL si un volume n'est lié à aucun PVC, si le total dépasse 200 Go ou si un LB/IP publique existe
- [ ] exécution périodique (cron CI en lecture ou job planifié) sans écriture cluster

## Notes
T-009 est absorbé : ses 3 critères sont repris et complétés. La clé OCI de lecture seule est une identité (MANDAT, une fois). k3d ne prouve rien sur OKE.

Absorbe : T-009.

Proposé par la recherche `cost` (clé T-141).
