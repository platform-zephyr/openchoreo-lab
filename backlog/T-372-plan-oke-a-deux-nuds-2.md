---
id: T-372
title: "Plan OKE à deux nœuds 2/12 (conditionnel) : pool, volumes, IP de pods"
status: blocked
phase: P5
adr: [0003, 0017]
depends_on: [T-061, T-140, T-364]
class: MANDAT
velocity: false
lane: socle-oke
stage: après-porte
model: claude-opus-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: null
---
# T-372 — Plan OKE à deux nœuds 2/12 (conditionnel) : pool, volumes, IP de pods

## Intention
Seulement si Paul demande une app sur OKE ET accepte le coût (≈ 28 USD/mois [estimé]) : second nœud 2/12 par redimensionnement du pool, libération des volumes de drill (D5), nomenclature remesurée, DP OKE et exception de flux OKE → homelab.

## Périmètre de fichiers
dépôt homelab-infra terraform/oracle-a1 (hors de ce dépôt) ; ici : décision et mesures

## Critères de fin
- [ ] second nœud Ready sans remplacement du premier, 2 × 31 IP de pods mesurées
- [ ] bloc : 0 volume orphelin, total ≤ 200 Gio
- [ ] exception de flux écrite par Paul (D13) avant tout agent OKE

## Notes
Différé tant qu'aucune app OKE n'est demandée.

Proposé par la recherche `homelab` (clé HOME-12) ; intégration 2 du 2026-11-18.

Vérification du 2026-11-18 : tout ce qui dépasse 2/12 est facturé, même en PAYG ; pas de nœud de surge.

Bloqué par : aucune app OKE demandée par Paul.
