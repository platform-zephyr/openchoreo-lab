---
id: T-345
title: "Agent dans un conteneur durci (devcontainer) : claude, sandbox et réseau limité"
status: todo
phase: P1
adr: [0018, 0022]
depends_on: [T-061, T-330, T-332]
class: AUTONOME
velocity: false
lane: dev-factory
stage: S2
model: claude-sonnet-5-5
effort: high
routing: R3-defaut
github_issue: null
---
# T-345 — Agent dans un conteneur durci (devcontainer) : claude, sandbox et réseau limité

## Intention
Lancer le processus de l'agent (et non seulement ses commandes) dans le conteneur : sandbox activé, filtre de sortie réseau par liste d'hôtes, aucun montage d'identifiants, pas de socket Docker, `--network none` pour les tests statiques. Exécuteur local (Mac puis N100) : même image. Construire l'image enfin et mesurer (`NON EXÉCUTÉ` dans DEV-FACTORY).

## Périmètre de fichiers
.devcontainer/, tools/dev/dev, docs/DEV-FACTORY.md

## Critères de fin
- [ ] image construite et `tools/dev/check --static` passe dans le conteneur (temps et RAM par workspace datés)
- [ ] guard-check.sh PASS dans le conteneur ; cas négatif : une variable KUBECONFIG injectée le fait échouer
- [ ] deux workspaces parallèles tournent sans conflit de cache (essai)

## Notes
Dans un conteneur non privilégié bubblewrap peut échouer ; enableWeakerNestedSandbox seulement si le conteneur isole déjà. Voir T-168 pour le bac d'exécution du code lancé par les agents.

Proposé par la recherche `harness` (clé HAR-15) ; intégration 2 du 2026-11-18.
