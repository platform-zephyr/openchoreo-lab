---
id: T-342
title: "Spike (3 jours) : cluster dev homelab pour agents (vcluster, VM dédiée ou namespaces)"
status: todo
phase: P1
adr: [0003, 0022]
depends_on: [T-061, T-363]
class: AUTONOME + MANDAT
velocity: false
lane: hybride
stage: S2
model: claude-opus-5-5
effort: high
routing: R08-manifestes-k8s-openchoreo
github_issue: null
---
# T-342 — Spike (3 jours) : cluster dev homelab pour agents (vcluster, VM dédiée ou namespaces)

## Intention
Le cluster lab (T-361) existe : comparer sur lui (a) vcluster par PR en nœuds partagés, (c) namespaces `lab-dev-*` seuls, et (b) une VM Talos de dev supplémentaire (défavorisée par le budget T-360). Mesurer démarrage, RAM au repos, nettoyage, isolation entre agents, compatibilité PSA restricted et default-deny ; seuils (≤ 2 previews, TTL 24 h).

## Périmètre de fichiers
docs/research/DEV-CLUSTER-SPIKE.md, tests/dev-cluster/

## Critères de fin
- [ ] tableau de mesures daté par option (démarrage, RAM au repos, RAM sous charge, destruction propre) ; NOT_MEASURED explicite sinon
- [ ] preuve d'isolation : un agent d'un vcluster ne voit pas les objets d'un autre (essai)
- [ ] recommandation unique avec le geste exact demandé à Paul, sans valeur
- [ ] limite écrite : x86_64, donc aucune preuve d'image arm64

## Notes
Périmètre cluster : namespaces openchoreo-* et lab-* seulement ; lecture seule ailleurs (AGENTS.md). Aucune mesure du surcoût de vcluster n'est publiée par le projet [NV].

Proposé par la recherche `harness` (clé HAR-12) ; intégration 2 du 2026-11-18.
