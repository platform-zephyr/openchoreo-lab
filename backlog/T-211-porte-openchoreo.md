---
id: T-211
title: "Porte 2 « exploitation hybride » : mesurer C2, C3, C4, C7 et la règle de routage, décision de Paul"
status: todo
phase: P1
adr: [0020, 0025]
depends_on: [T-031, T-044, T-050, T-061, T-061b, T-212, T-364, T-488]
class: MANDAT
velocity: false
lane: gouvernance
stage: PORTE
model: claude-opus-5-5
effort: high
routing: R1-sensible
github_issue: null
---
# T-211 — Porte 2 « exploitation hybride » : C2, C3, C4, C7, règle de routage et décision de Paul

## Intention
Après une porte 1 positive (T-488, ADR-0025), mesurer ce que la porte 1 ne prouve pas : coût et jour 2 sur la VM lab amd64, couverture du catalogue kube-ops, règle de routage des agents entre OpenChoreo et kube-ops. Décision adopter/abandonner avant toute migration d'app. Seuils proposés par défaut, ajustables par Paul avant la mesure.

## Périmètre de fichiers
docs/review/, docs/adr/0020-porte-adoption-openchoreo.md, docs/adr/0025-validation-en-deux-portes.md

## Critères de fin
- [ ] décision de Paul consignée dans ADR-0020
- [ ] tickets `deferred` dégelés ou `dropped` selon la décision
- [ ] emplacement d'Authentik décidé par Paul (repris de T-213)
- [ ] emplacement du CP confirmé par Paul (D11 par défaut : VM lab) avec la mesure C2 sur OKE de T-487 et celle de la VM lab
- [ ] livraison par l'Argo de kube-ops décidée pour le cluster cible (T-492)
- [ ] C1, C5 et C6 repris du rapport de la porte 1 (T-488), sans nouvelle mesure
- [ ] C2 différentiel : surcoût d'OpenChoreo par rapport au chemin du bras K sur la même VM ≤ 4 Gio de requests et ≤ 25 pods
- [ ] C3 : bundle de sécurité retiré ou reconstruction scriptée amd64 ≤ 2 h par patch (T-366)
- [ ] C4 « jour 2 » : montée d'un patch avec reconstruction du bundle amd64, et CP reconstruit depuis Git sur VM vide, apps Ready (T-031)
- [ ] C7 : part du catalogue kube-ops couverte (T-050), mesurée pour les deux chemins
- [ ] règle de routage « `apps/<app>/app.yaml` existe → OpenChoreo, sinon kube-ops » appliquée sans erreur par un agent sur 10 demandes mêlées
- [ ] part des PR applicatives de kube-ops sur 90 jours qui touchent une app A, B ou C, mesurée (lecture de l'historique)
- [ ] horloge en heures d'agent depuis T-364 `done` ; l'attente d'un MANDAT n'est pas comptée

## Notes
Constats G1-G4 de la revue Fable, acceptés (arbitrage Fable, 2026-11-18) ; T-140 retiré des dépendances.

Recadré par ADR-0025 (2026-11-18) : la porte unique devient deux portes. La règle « jamais de mesure sur OKE » est levée pour la porte 1 ; C1, C5 et C6 viennent du banc A/B (T-488). Le comparateur plain devient le chemin kube-ops reproduit (T-212).

Accéléré (arbitrages de Paul n°3, 2026-11-18) : C1, C5 et C6 viennent du banc minimal (T-488, 4 tâches, 2 runs).
