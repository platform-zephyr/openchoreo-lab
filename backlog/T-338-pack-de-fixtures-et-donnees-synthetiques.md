---
id: T-338
title: "Pack de fixtures et données synthétiques (OIDC factice, ntfy réel, Grafana/Loki rejoués, CRD OpenChoreo)"
status: todo
phase: P0
adr: [0022]
depends_on: [T-002, T-061, T-332]
class: AUTONOME
velocity: true
lane: tests-fixtures
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R99-defaut
github_issue: null
---
# T-338 — Pack de fixtures et données synthétiques (OIDC factice, ntfy réel, Grafana/Loki rejoués, CRD OpenChoreo)

## Intention
Fixtures chacun avec up.sh, health.sh, README : serveur OIDC factice (découverte + jeton), ntfy réel, API Grafana/Loki rejouant des réponses enregistrées, CRD OpenChoreo sans contrôleurs. Générateur déterministe (graine fixe) d'apps, intentions, alertes et incidents, sans donnée personnelle. Choix des images par spike court ; versions et digests épinglés.

## Périmètre de fichiers
tests/fixtures/, tools/fixtures/

## Critères de fin
- [ ] chaque fixture démarre sur k3d jetable et répond à son health.sh (run daté)
- [ ] le générateur produit la même sortie deux fois de suite (hash identique)
- [ ] un test déclare sa dépendance de fixture dans le registre de suites (T-216)
- [ ] aucune valeur secrète : jetons factices générés au démarrage

## Notes
Vrai si léger, factice si lourd. Le plan de contrôle OpenChoreo réel n'est pas simulé : il relève de N2/OKE.

Proposé par la recherche `harness` (clé HAR-8) ; intégration 2 du 2026-11-18.
