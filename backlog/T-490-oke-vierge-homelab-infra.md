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
- [x] PR de homelab-infra : décision « OKE réservé au POC openchoreo-lab jusqu'à la décision de la porte 1 ; pile `oracle-a1` de kube-ops non rejouée ; Colima permis sur le Mac pour openchoreo-lab seulement », journal et résumé dans la même PR, fusionnée par Paul (homelab-infra#620, fusionnée le 2026-11-18T19:04Z : D-2026-11-18-01 et MANDAT 23 ; #621 fenêtre ARC fusionnée le même jour)
- [x] plan ARC montrant la recréation du cluster OKE (ou de son pool de nœuds) sans autre changement, puis apply ARC terminé (plan `oracle-a1` du 2026-11-18T20:55Z, run 44396022672 ; apply run 44397106449 du 2026-11-18T21:01Z : 3 changements, 2 suppressions et 2 remplacements, « Apply completed; fresh state-backed plan has no changes. »)
- [x] cluster OKE joignable par le bastion, aucun Argo CD ni Application présent (preuve datée, lecture seule : `backlog/evidence/T-487-2026-11-18T2206Z-preflight.md`, namespaces default, kube-node-lease, kube-public et kube-system seulement, 2026-11-18T22:06Z)
- [x] kubeconfig distribué par le chemin habituel de homelab-infra, sans valeur affichée (KUBECONFIG dédié utilisé par la session locale pour le préflight du 2026-11-18T22:06Z et l'étape 0 ; aucune valeur dans les preuves ; le chemin exact de distribution n'a pas été revérifié par le coordinateur)

## Notes
Exécuté par une session homelab-infra (agent cloud, ARC), selon les règles de ce dépôt-là. Ce dépôt ne modifie ni homelab-infra ni kube-ops. Débloque T-487.
