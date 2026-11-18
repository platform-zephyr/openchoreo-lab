# Backlog de la plateforme

Source des tâches du labo (ADR-0012). Un fichier par ticket : `T-NNN-<slug>.md`. Vue d'ensemble : [INDEX.md](INDEX.md).
Ordre de travail : [ROADMAP.md](ROADMAP.md) (consensus du 2026-11-18, `docs/review/CONSENSUS.md` ; intégration 2 : [INTEGRATION-2.md](INTEGRATION-2.md) ; consensus n°2 et arbitrages de Paul : [INTEGRATION-3.md](INTEGRATION-3.md) ; arbitrage Fable : [INTEGRATION-4.md](INTEGRATION-4.md)). Linear n'est pas utilisé pour ce labo. Une issue GitHub n'est créée que pour lancer un agent (label `agent:dev`) et
renvoie au fichier du ticket.

## En-tête d'un ticket

```yaml
---
id: T-NNN                 # unique, jamais réutilisé
title: "…"
status: todo              # todo | in-progress | blocked | deferred | done | dropped
phase: P0                 # P0 … P5 (voir INDEX.md)
adr: [0004]               # ADR de rattachement (docs/adr/)
depends_on: [T-003]       # tickets qui doivent être `done` avant
class: AUTONOME           # AUTONOME | REVUE | MANDAT (platform-guardrails), combinables : "AUTONOME + MANDAT"
velocity: false           # true : accélère nettement les suivants
lane: ci                  # couloir de fichiers (parallélisme sans conflit)
stage: S0                 # S0-S3 (MVP), PORTE, FINAL0 (avant la 1re donnée réelle), I1-I8, FINAL (durcissement final), I9, après-porte
model: claude-sonnet-5-5  # claude-haiku-5-5 | claude-sonnet-5-5 | claude-opus-5-5 | human (geste de Paul seul)
effort: high              # low | medium | high | xhigh | max (Sonnet ≤ xhigh) ; `none` avec `human`
routing: R3-defaut        # règle d'ADR-0023 qui a fixé le modèle : R0-geste-humain | R1-noyau | R2-texte | R3-defaut
github_issue: null        # numéro si un agent a été lancé
---
```

`model` et `effort` sont obligatoires sur un ticket `todo` ou `in-progress` (`check.py`). Ils viennent des **3 règles**
d'ADR-0023 (consensus n°2) : périmètre dans le noyau (CODEOWNERS, `docs/adr/`, `docs/review/`) → Opus `high` ; texte hors
noyau → Haiku `medium` + revue Sonnet ; reste → Sonnet `high`. Le dispatcher (T-210) recalcule le modèle depuis les chemins
réellement touchés et ignore un `model:` sous le plancher.

Corps : `## Intention`, `## Périmètre de fichiers`, `## Critères de fin` (cases à cocher, chacune vérifiable :
commande, test ou preuve runtime datée), `## Notes` (facultatif).

## Prendre un ticket (agent)

1. Choisir un ticket `todo` dont toutes les dépendances sont `done`, de l'étape la plus basse (ROADMAP.md) ; `deferred` = gelé jusqu'à la porte OpenChoreo (ADR-0020) ou, pour DeepSeek, après le chantier.
2. Passer `status: in-progress` dans la même PR que le travail (pas de PR de statut seule).
3. Livrer selon la classe : AUTONOME = merge après `ci-ok` ; REVUE = PR prête, Paul approuve ; MANDAT = la PR décrit
   le geste exact attendu de Paul (noms, jamais de valeurs).
   **Mode dev** (arbitrage 7, arbitrage Fable) : la revue des code owners est désactivée ; REVUE = merge après `ci-ok`
   (auto-merge armé par l'exécutant), comme AUTONOME. La revue revient à l'étape FINAL0 (T-400) sur `platform/authz/`,
   `platform/policies/` et `security/`, puis à FINAL.
4. `status: done` seulement quand **tous** les critères de fin sont cochés avec leur preuve (lien ou fichier daté).
5. Un ticket bloqué passe `blocked` avec une ligne `Bloqué par :` dans `## Notes`.

Outils : `tools/backlog/seed.py` (génération initiale, à remplacer par l'édition directe des tickets), `check.py` (graphe), `roadmap.py` (ROADMAP.md).

## Identités et secrets (T-306)

Toute création d'identité ou de secret (jeton, clé, client OIDC, kubeconfig, accès à un coffre) ajoute une entrée dans `docs/state/identities.yaml` **dans la même PR** : nom, rôle, portée, propriétaire, dates, `dev: true|false`, coffre, consommateurs. Jamais de valeur, d'IP, d'hôte interne ni d'e-mail. Le lint `tools/backlog/identities_lint.py` (job `appgen` de la CI) refuse tout champ de valeur et toute chaîne ressemblant à un secret.
