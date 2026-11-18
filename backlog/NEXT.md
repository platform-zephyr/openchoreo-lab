# Prochaines étapes (tenu à la main par le coordinateur — dernière mise à jour 2026-11-18)

Point d'entrée pour reprendre : lire ce fichier, puis `docs/state/HANDOFF-COORDINATEUR.md`. Ce fichier dit **quoi lancer maintenant** ;
`ROADMAP.md` (généré) donne l'ordre complet ; `python3 tools/backlog/next.py` calcule les tickets prêts (dépendances `done` seulement).
Pendant S0/S1, beaucoup de dépendances sont `in-progress` (implémentées) : lancer à la main les tickets ci-dessous.

## État en une ligne
Exécutant prouvé de bout en bout (T-304) ; il reste à clore les prérequis du pilote 24 h (T-322) puis à paralléliser le développement.

## Prérequis du pilote T-322 encore ouverts (voir la ligne « Reste » dans chaque ticket)
| Ticket | Reste | Qui |
|---|---|---|
| T-303 | hook Stop avec le même script `leak-guard.sh` | T-331 (agent en cours) |
| T-305 | tag `core-baseline` : annoté mais non signé, posé après la vague 1 ; Paul l'accepte ou le repose | Paul |
| T-311 | run avec `factory/PAUSE` posé ; dispatch réel de plusieurs issues | coordinateur (voir « Dispatch multi-issues ») |
| T-313 | `check-trailers` dans `ci.yaml`, coût/tours dans la PR, dispatch multi-issues | agent en cours puis coordinateur |
| T-411 | essai daté sur un ticket `complet` (section « Implémentations publiques consultées » rendue) | coordinateur (dispatch d'un ticket de test) |
Prérequis déjà `done` : T-008, T-302, T-304, T-306, T-326, T-330, T-413. T-322 dépend aussi de T-002 par la liste figée (pas des prérequis).

## Vague A : à lancer tout de suite, en parallèle (aucun conflit de fichiers)
| Ticket | Modèle | Périmètre | Note |
|---|---|---|---|
| T-456 | Opus high | `platform/resource-types/cnpg-lab-db.yaml`, VAP R6, `tests/vap`, `tests/k3d` | défaut réel de l'archétype B (clé ESO avec `/`) ; REVUE sensible |
| T-457 | Sonnet high | `tests/vap/run.sh` | B-09 en KNOWN_FAIL au niveau du cas |
| T-458 | Sonnet high | `tests/gitops-k3d/`, `tools/k3d/` | ancre périmée |
| T-459 | Sonnet high | `.pre-commit-config.yaml`, `tools/dev/setup` | SL-4 |
| T-460 | Sonnet high | `tools/dev/ci-map.tsv`, `ci.yaml` | SL-6 parité CI ↔ check ; attention aux conflits avec T-313 (ci.yaml) : séquentiel |
| T-464 | Sonnet high | `AGENTS.md`, `.agents/skills/` | SL-10 ; conflit possible avec T-041 sur `AGENTS.md` |
| T-463 | Sonnet high | `docs/research/` | spike Kyverno/VAP sans cluster |
Les tickets T-456 à T-458 sont tous dans le couloir `agents` : un à la fois sur `tests/vap/` (T-456 et T-457 se chevauchent : T-457 d'abord).

## Vague B : après la vague A
T-461 (SL-7, dépend de T-460), T-462 (devcontainer), T-465 (nuit k3d, dépend de T-461, T-451, T-452), T-451 (reste : alerte k3d, fin de S1), T-452 (critère 3, fin de S1).

## Dispatch multi-issues (preuve de T-311, T-313 et début du pilote)
1. Créer N issues de tickets réels sans conflit de fichiers (`gh issue create` ou l'outil GitHub) avec le contenu du ticket.
2. Lancer : `gh workflow run claude-agent.yml -f tickets="101,102,103" -f model=claude-sonnet-5-5 -f effort=high` (matrice `max-parallel: 3`).
3. Relever pour chaque issue : branche, PR, coût, tours (artefact `mission-result-<n>`, `permission_denials`), fusion par la file.
4. `factory/PAUSE` : poser le fichier sur `main` par PR puis relancer pour prouver le désarmement (T-311).
Journaux complets : `-f debug=true` (dépôt public : seulement sur une issue sans donnée sensible).

## Après le pilote (ordre, voir ROADMAP.md)
T-322 (pilote 24 h, N=3 puis 6 puis 10, palier décidé par Paul) → porte ADR-0020 (S2/S3 puis PORTE) → FINAL0 → I1-I8 → FINAL.
Backlog des suites k3d : T-452/T-465 (réactivation nocturne à la fin de S1 avant T-364), T-435 (requis) en FINAL0.

## Gestes de Paul encore attendus
- Script de setup de l'environnement cloud des agents : `tools/dev/cloud-setup.sh` (interface), sorties autorisées `get.helm.sh`, `github.com`.
- T-305 : accepter le tag `core-baseline` (annoté, non signé) ou le reposer ; signature avant FINAL0.
- T-434 : réglages d'organisation GitHub (`docs/research/GITHUB-CONFIG.md` §7) ; preuves à relever après.
- Confirmer les dates réelles du registre `docs/state/identities.yaml` (`created_is_estimate`).
- Pause du moteur horaire d'Atlas et homelab-infra pendant le pilote ; relevé `/usage` à 0, 24 et 48 h ; palier N ; Max ou Ultra après le pilote.
- Dire si `lab.internal` est fictif.
- FINAL0 : App(s) définitives (T-215), retrait du contournement admin (T-400), signature du tag.
