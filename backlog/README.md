# Backlog de la plateforme

Source des tâches du labo (ADR-0012). Un fichier par ticket : `T-NNN-<slug>.md`. Vue d'ensemble : [INDEX.md](INDEX.md).
Linear n'est pas utilisé pour ce labo. Une issue GitHub n'est créée que pour lancer un agent (label `agent:dev`) et
renvoie au fichier du ticket.

## En-tête d'un ticket

```yaml
---
id: T-NNN                 # unique, jamais réutilisé
title: "…"
status: todo              # todo | ready | in-progress | blocked | done | dropped
phase: P0                 # P0 … P5 (voir INDEX.md)
adr: [0004]               # ADR de rattachement (docs/adr/)
depends_on: [T-003]       # tickets qui doivent être `done` avant
class: AUTONOME           # AUTONOME | REVUE | MANDAT (platform-guardrails), combinables : "AUTONOME + MANDAT"
github_issue: null        # numéro si un agent a été lancé
---
```

Corps : `## Intention`, `## Périmètre de fichiers`, `## Critères de fin` (cases à cocher, chacune vérifiable :
commande, test ou preuve runtime datée), `## Notes` (facultatif).

## Prendre un ticket (agent)

1. Choisir un ticket `todo` dont toutes les dépendances sont `done`, de la phase la plus basse.
2. Passer `status: in-progress` dans la même PR que le travail (pas de PR de statut seule).
3. Livrer selon la classe : AUTONOME = merge après `ci-ok` ; REVUE = PR prête, Paul approuve ; MANDAT = la PR décrit
   le geste exact attendu de Paul (noms, jamais de valeurs).
4. `status: done` seulement quand **tous** les critères de fin sont cochés avec leur preuve (lien ou fichier daté).
5. Un ticket bloqué passe `blocked` avec une ligne `Bloqué par :` dans `## Notes`.

Régénérer l'index : `python3 tools/backlog/index.py` (à écrire, T-008 ; en attendant, le script de génération initial).
