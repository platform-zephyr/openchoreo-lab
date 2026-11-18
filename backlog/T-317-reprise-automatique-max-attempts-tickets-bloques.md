---
id: T-317
title: "Reprise automatique et escalade de modèle : max_attempts, tickets bloqués, rebase par l'App, disjoncteur de boucle"
status: todo
phase: P0
adr: [0021]
depends_on: [T-061, T-314, T-382]
class: AUTONOME
velocity: true
lane: agents
stage: S1
model: claude-sonnet-5-5
effort: high
routing: R99-defaut
github_issue: null
---
# T-317 — Reprise automatique et escalade de modèle : max_attempts, tickets bloqués, rebase par l'App, disjoncteur de boucle

## Intention
Une tentative échouée relance une fois sur branche neuve avec le journal d'échec ; deux échecs passent le ticket en blocked avec la cause et la demande précise ; verrou abandonné après 3 h sans commentaire ; rebase automatique des PR en conflit ; refus d'une 3e tentative et d'une seconde PR d'agent sur la même (app, env).

## Périmètre de fichiers
tools/factory/recover.py, tests/factory/

## Critères de fin
- [ ] tests : échec simulé, reprise unique, puis blocked ; verrou périmé libéré
- [ ] test de boucle : un bot ne déclenche pas un bot (allowed_bots vide)
- [ ] conflit simulé sur lab-apps.yaml : rebase automatique ou needs-paul
- [ ] (repris de MOD-4) deux échecs CI simulés → relance au cran suivant, une seule fois par cran ; au-delà : issue `needs-human`
- [ ] (repris de MOD-4) l'escalade suit l'échelle de la règle de routage (T-382), étiquette `escalated-from`

## Notes
Proposé par la recherche `factory` (clé FAC-8) ; intégration 2 du 2026-11-18.

Vocabulaire des classes d'échec partagé avec le protocole T-340.
