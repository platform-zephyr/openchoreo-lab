---
id: T-521
title: "Banc A/B abandonné : tickets du banc gelés, NEXT.md réorienté vers le test d'usage de Paul"
status: todo
phase: P1
adr: []
depends_on: []
class: AUTONOME
velocity: false
lane: docs
stage: S1
model: claude-sonnet-5-5
effort: medium
routing: R3-defaut
github_issue: null
---
# T-521 — Banc A/B abandonné

## Intention
Décision de Paul (chat de l'orchestrateur, 2026-11-19) : le banc A/B (passe 0, campagne comptée, bras K, harnais, seuils, graders) est arrêté. Il est plus long et plus cher qu'un déploiement jetable réel sur OKE et il ne mesure pas l'IDP. Paul fait lui-même un test d'usage sur un déploiement réel d'OpenChoreo (T-520, hors de ce ticket). Ce ticket trace l'arrêt : tickets du banc passés `deferred` avec une ligne de raison datée, historique conservé, NEXT.md mis à jour.

## Périmètre de fichiers
backlog/T-521-banc-abandonne.md, backlog/NEXT.md, backlog/T-486-passe-0-banc-oke.md, backlog/T-501-prerequis-banc-ab-passe-0.md, backlog/T-504-fidelite-bras-k.md, backlog/T-212-backend-plain.md, backlog/T-485-protocole-banc-ab.md, backlog/T-488-banc-ab-compte-porte-1.md, backlog/T-495-appproject-lab-k.md, backlog/T-044-banc-intentions.md, backlog/T-211-porte-openchoreo.md, backlog/T-361-vm-talos-lab-dediee-sur-proxmox.md, backlog/T-366-bundle-multi-arch-installateur-lab.md, backlog/T-492-branchement-argo-kube-ops.md

## Critères de fin
- [x] T-486, T-501, T-504, T-212, T-485, T-488, T-495 en `deferred`, ligne de raison datée, rien supprimé
- [x] dépendances au banc (T-212, T-488) retirées de T-044, T-211, T-361, T-366, T-492 (sinon `check.py` : ACTIF->GELÉ), avec une ligne datée
- [x] NEXT.md : stratégie, chemin critique et gestes de Paul mis à jour
- [x] PR #177 (ADR-0025) notée obsolète ; remplacement par une décision courte « banc A/B abandonné » après le rapport T-520 (ADR non touchés ici)
- [x] `python3 tools/backlog/check.py` sans erreur
- [ ] T-506 (`lab-k`, branche `claude/t-506-lab-k-perimetre`, pas encore sur main) : à passer `deferred` ou `dropped` par son propriétaire ou à sa fusion
- [ ] décision courte « banc A/B abandonné » rédigée après le rapport T-520 (remplace la PR #177)

## Notes
Non touchés : T-511, T-513, T-514, T-517, T-518, T-519, T-520, `tools/appgen/`, `tools/oke/argo_guard*`, ADR. T-502 (`lab-o`) et T-487 (bras O) restent actifs : ils servent le déploiement réel.
