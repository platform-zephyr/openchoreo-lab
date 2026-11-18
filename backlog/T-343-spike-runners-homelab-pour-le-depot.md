---
id: T-343
title: "Runners pour le dépôt public : hébergés par défaut, ARC homelab admis pour push/dispatch de mainteneurs seulement"
status: deferred
phase: P5
adr: [0022]
depends_on: [T-061, T-342]
class: REVUE + MANDAT
velocity: false
lane: hybride
stage: après-porte
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-343 — Runners pour le dépôt public : hébergés par défaut, ARC homelab admis pour push/dispatch de mainteneurs seulement

## Intention
Runners GitHub hébergés par défaut. homelab-infra (privé) a déjà des runners ARC sur le cluster local. Pour ce dépôt public, un scale set ARC homelab n'est admis que pour des workflows déclenchés par push ou workflow_dispatch d'un mainteneur, jamais sur une PR de fork : scale set dédié (pas celui d'OpenTofu), JIT, non privilégié, sans secret, default-deny.

## Périmètre de fichiers
docs/AGENT-RUNNERS.md, platform/ (si le scale set vit ici), PR cross-dépôt vers homelab-infra / kube-ops

## Critères de fin
- [ ] pod runner ARC securityContext restricted, aucun volume hôte, aucun Secret monté
- [ ] coût : frais de plateforme (0,002 USD/min annoncés puis reportés, gratuits en dépôt public) vérifiés à la source à la date de la décision
- [ ] le propriétaire du déploiement (kube-ops ou homelab-infra) est nommé ; aucune écriture hors périmètre
- [ ] liste des workflows admis sur ARC homelab (déclencheurs push et workflow_dispatch de mainteneurs seulement), garde CI qui refuse `runs-on` homelab sur `pull_request`/`pull_request_target`
- [ ] essai daté : une PR de fork ne peut planifier aucun job sur le groupe de runners homelab

## Notes
Frontière de dépôt : homelab-infra possède l'ARC d'OpenTofu ; ne pas mélanger. MANDAT : la création de l'objet côté homelab est un geste de Paul.

Proposé par la recherche `harness` (clé HAR-13) ; intégration 2 du 2026-11-18.

Ajusté (consensus n°2 et arbitrages de Paul, 2026-11-18) (arbitrage 6).

Différé (consensus n°2 et arbitrages de Paul, 2026-11-18) : règle d'usine d'ADR-0021 (décision 10) ; avant la porte, un ticket d'usine n'entre que s'il supprime un geste de Paul mesuré au pilote.
