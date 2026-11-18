---
id: T-490
title: "Consigner les arbitrages du POC dans homelab-infra et recréer OKE vierge par ARC"
status: todo
phase: P1
adr: [0025, 0003]
depends_on: []
class: MANDAT
velocity: true
lane: socle-oke
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-490 — Arbitrages du POC dans homelab-infra et OKE vierge

## Intention
Les décisions en vigueur de homelab-infra placent sur OKE un Argo qui réconcilie kube-ops et la mémoire Hindsight de drill. Les arbitrages de Paul du 2026-11-18 (OKE sans donnée importante, réinitialisation sans cérémonie, Colima permis pour ce dépôt) doivent entrer dans le journal de décisions, puis OKE être recréé vierge par ARC, sans qu'aucune session de ce dépôt n'écrive hors `openchoreo-*` et `lab-*`.

## Périmètre de fichiers
dépôt homelab-infra (hors de ce dépôt) : `docs/decisions.md`, `docs/decisions-active.md`, racine OpenTofu d'OKE ; ici : docs/research/POC-OPENCHOREO-STRATEGY.md (lien de la PR)

## Critères de fin
- [ ] PR de homelab-infra : décision « OKE réservé au POC openchoreo-lab jusqu'à la décision de la porte 1 ; pile `oracle-a1` de kube-ops non rejouée ; Colima permis sur le Mac pour openchoreo-lab seulement », journal et résumé dans la même PR, fusionnée par Paul
- [ ] plan ARC montrant la recréation du cluster OKE (ou de son pool de nœuds) sans autre changement, puis apply ARC terminé (lien du run)
- [ ] cluster OKE joignable par le bastion, aucun Argo CD ni Application présent (preuve datée, lecture seule)
- [ ] kubeconfig distribué par le chemin habituel de homelab-infra, sans valeur affichée

## Notes
Exécuté par une session homelab-infra (agent cloud, ARC), selon les règles de ce dépôt-là. Ce dépôt ne modifie ni homelab-infra ni kube-ops. Débloque T-487.
