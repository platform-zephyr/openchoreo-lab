---
id: T-487
title: "Réinitialiser OKE pour le POC : gel d'oracle-a1, installation depuis Git, un Argo, mesure C2-OKE"
status: todo
phase: P1
adr: [0025, 0003, 0017]
depends_on: [T-001]
class: REVUE + MANDAT
velocity: true
lane: socle-oke
stage: S1
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-487 — Réinitialiser OKE pour le POC

## Intention
Donner au banc un OKE propre : pile kube-ops arrêtée pour une fenêtre de 3 semaines, OpenChoreo (bundle 1.0.1 arm64) et un seul Argo CD installés depuis Git, AppProjects `lab-o` et `lab-k`, empreinte mesurée.

## Périmètre de fichiers
tools/oke/install.sh, tools/oke/verify.sh, platform/install/argocd/, docs/state/journal/, dépôts homelab-infra et kube-ops (hors de ce dépôt : retrait de la pile kube-ops d'OKE, décision au journal)

## Critères de fin
- [ ] inventaire en lecture seule de la pile kube-ops sur OKE (côté kube-ops) : seules des données de drill, preuve datée
- [ ] MANDAT Paul : gel d'`oracle-a1` consigné dans le journal de homelab-infra (dates de début et de fin, Hindsight de drill compris)
- [ ] retrait de la pile kube-ops fait côté homelab-infra ou kube-ops ; aucune écriture de ce dépôt hors `openchoreo-*` et `lab-*`
- [ ] installation depuis Git, `verify.sh` PASS par étape, durée totale de reconstruction mesurée
- [ ] un seul Argo CD, AppProjects `lab-o` et `lab-k` bornés à leurs namespaces (test de refus hors périmètre)
- [ ] mesure datée : requests CPU et RAM, pods, IP de pods ; FAIL si > 70 % ou > 33 pods avec un bras actif
- [ ] bloc OCI ≤ 200 Go ; volume CNPG de 50 Go créé seulement avec le MANDAT de Paul (sinon T2 reste sur le Mac)

## Notes
Exécutant unique sur OKE : le coordinateur, par session bastion ouverte par Paul. Coût attendu : 0 € ; tout dépassement est un MANDAT (ADR-0017).
