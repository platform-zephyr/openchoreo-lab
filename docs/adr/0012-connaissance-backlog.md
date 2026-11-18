# ADR-0012 — Connaissance, backlog et état pour agents
Statut : PROPOSÉ · Date : 2026-11-18 · Décideur : Paul
Décisions liées : ADR-0001 ; décisions de Paul du 2026-11-18 (`missions/MISSION.md`)

## Contexte
- L'adoption d'OpenChoreo n'est pas tranchée : le backlog Linear décrit surtout l'ancienne architecture.
- Les agents cloud repartent sans mémoire : ils ont besoin d'un contexte versionné, court et à jour.
- `openchoreo.dev` n'est pas joignable depuis les sessions cloud ; la doc a été condensée depuis son dépôt source.

## Décision
1. **Backlog dans le dépôt** : `backlog/` est la source des tâches du labo (un fichier par ticket, en-tête YAML :
   id, statut, dépendances, ADR, classe). Une issue GitHub n'est créée que pour lancer un agent (label `agent:dev`)
   et renvoie au fichier. Linear n'est pas utilisé pour ce labo tant que l'adoption n'est pas décidée.
2. **Référence OpenChoreo condensée** dans `docs/reference/openchoreo/`, épinglée sur la version installée (1.3.x),
   avec URL source par section ; mise à jour à chaque montée de version.
3. **État unique** : `STATE.md` (où on en est) et `missions/MISSION.md` (ce qui est autorisé) ; ADR pour le « pourquoi ».
4. **Atlas est le point d'arrivée** (décision de Paul) : **le hub de connaissance et de routage** : il porte la connaissance transversale stable et route une
   intention vers le bon dépôt et le bon skill (ADR-0013) ; chaque dépôt garde sa connaissance locale. Le contexte
   est conçu en couches (toujours chargé et court / chargé à la demande / référence), avec des checks de taille, de
   liens et de fraîcheur (travail de context engineering : `docs/research/context-engineering/`).

5. **Les agents cloud ont accès aux dépôts** (Atlas compris) en lecture, et en écriture par PR selon ADR-0002.

## Conséquences
- Les issues #49 à #53 sont reprises dans `backlog/` puis fermées avec un lien.
- Un check CI valide l'en-tête des tickets (id unique, dépendances existantes).

## Alternatives écartées
- **Linear** : outil externe, et backlog encore lié à l'ancienne architecture.
- **Issues GitHub seules** : publiques et non versionnées avec le code ; pratiques seulement pour lancer un runner.

## Vérification
- Chaque ticket a un ADR de rattachement et des critères de fin testables ; un agent sans contexte peut prendre le
  prochain ticket « prêt » en lisant `backlog/README.md`.

## Références
`backlog/README.md`, `docs/reference/openchoreo/README.md`, Atlas `repos/catalog.md`.
